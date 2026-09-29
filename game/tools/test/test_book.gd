extends Node
## Close-ups of the family book and Don's View with a busy campaign: many shops, men on every
## task, men in prison, a case at the Bureau, offers waiting, a family at war, one finished.
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --rendering-driver opengl3 --resolution 1600x900 \
##     --path game res://tools/test/test_book.tscn -- --out=/tmp/book [--only=book|map] [--empty]
## Saves <out>_<name>.png for every tab and a few map views.

class FakeActor extends Node2D:
	var kind := ""
	var family := -1
	var dead := false
	var ref_id := -1
	var key := ""


class FakeAudio extends Node:
	func ui(_n: String, _db: float = -6.0) -> void:
		pass


class FakeWorld extends Node2D:
	var actors := {}
	var local_actor: Node2D
	var plan: CityPlan
	var boat: Node2D
	var audio: Node
	var hud: Node


class FakeHud extends Node:
	var world: Node
	var book: Control
	var map: Control
	var waypoint := Vector2.INF
	func toggle_family() -> void:
		book.visible = not book.visible
	func toggle_map() -> void:
		map.visible = not map.visible
	func set_waypoint(px: Vector2) -> void:
		waypoint = px


var out := "/tmp/book"
var only := ""
var empty := false


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--only="):
			only = a.substr(7)
		elif a == "--empty":
			empty = true
	Game.new_campaign({"seed": 1923, "families": 5}, [{"peer": 1, "name": "Alex", "family_name": "Vitale", "color": "#c42828"}])
	Game.running = false
	Game.month = 76
	if not empty:
		_fill()
	var world := FakeWorld.new()
	world.plan = Game.plan
	world.audio = FakeAudio.new()
	world.add_child(world.audio)
	add_child(world)
	_actors(world)
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)
	var hud := FakeHud.new()
	hud.world = world
	world.hud = hud
	add_child(hud)
	var book: Control = load("res://scripts/ui/family_book.gd").new()
	book.set("hud", hud)
	book.set_anchors_preset(Control.PRESET_FULL_RECT)
	book.visible = false
	root.add_child(book)
	var map: Control = load("res://scripts/ui/city_map.gd").new()
	map.set("hud", hud)
	map.set("world", world)
	map.set_anchors_preset(Control.PRESET_FULL_RECT)
	map.visible = false
	root.add_child(map)
	hud.book = book
	hud.map = map
	await _frames(3)
	print("biz: ", Game.biz.size(), " mine: ", Game.shops_of(0).size())
	if only in ["", "book"]:
		book.visible = true
		book.call("open")
		for k in 5:
			book.call("set_tab", k)
			await _frames(12)
			_shot("book_%s" % ["family", "rackets", "heat", "rivals", "money"][k])
		# a picker open over the family page
		book.call("set_tab", 0)
		await _frames(4)
		var c: Dictionary = Game.crew_of(0)[0]
		book.pages.call("_pick_guard", c, Rect2(400, 300, 100, 30))
		await _frames(6)
		_shot("book_picker")
		book.call("_close_picker")
		# hover on a button, keyboard selection on another
		book.hits.hover = "o_%d_collect" % int(c["id"])
		book.call("_redraw_all")
		await _frames(6)
		_shot("book_hover")
		# the keyboard: 3 (Heat), down twice, then the mouse clicks the Rivals tab
		book.hits.hover = ""
		_key(KEY_3)
		await _frames(3)
		_key(KEY_DOWN)
		_key(KEY_DOWN)
		await _frames(6)
		_shot("book_keys")
		print("book tab after keys: ", book.get("tab"), " focus: ", book.hits.focus)
		var tabs: Array = book.lay["tabs"]
		await _click((tabs[3] as Rect2).get_center())
		await _frames(6)
		print("book tab after click: ", book.get("tab"))
		_key(KEY_PAGEDOWN)
		_key(KEY_E)
		await _frames(4)
		_key(KEY_1)
		await _frames(4)
		# open a picker with the keyboard: find a Guard button, press Enter, go down, Esc
		book.hits.focus = "o_%d_guard" % int(c["id"])
		book.hits.keys = true
		_key(KEY_ENTER)
		await _frames(3)
		_key(KEY_DOWN)
		_key(KEY_DOWN)
		await _frames(4)
		_shot("book_picker_keys")
		_key(KEY_ESCAPE)
		await _frames(3)
		print("picker closed: ", (book.get("picker") as Dictionary).is_empty())
		book.visible = false
	if only in ["", "map"]:
		map.visible = true
		map.call("open")
		await _frames(12)
		_shot("map")
		# the keyboard: filter 2 (mine), E (next shop), then the mouse wheel and a drag
		_key(KEY_2)
		_key(KEY_E)
		_key(KEY_E)
		await _frames(6)
		_shot("map_keys")
		var fr: Rect2 = map.get("frame")
		_wheel(fr.get_center(), true)
		await _frames(2)
		await _drag(fr.get_center(), fr.get_center() + Vector2(-120, 40))
		_key(KEY_1)
		_key(KEY_BACKSPACE)
		map.call("_fit")
		await _frames(4)
		print("map filter: ", map.get("filter"), " sel: ", map.get("sel"), " zoom: ", map.get("zoom"))
		if map.has_method("test_select"):
			map.call("test_select")
			await _frames(10)
			_shot("map_selected")
			map.call("test_zoom")
			await _frames(10)
			_shot("map_zoom")
	get_tree().quit()


func _key(k: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = k
	e.pressed = true
	Input.parse_input_event(e)
	var u := InputEventKey.new()
	u.keycode = k
	u.pressed = false
	Input.parse_input_event(u)
	Input.flush_buffered_events()


func _click(p: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.position = p
	m.global_position = p
	Input.parse_input_event(m)
	for pressed in [true, false]:
		var b := InputEventMouseButton.new()
		b.button_index = MOUSE_BUTTON_LEFT
		b.pressed = pressed
		b.position = p
		b.global_position = p
		Input.parse_input_event(b)
		Input.flush_buffered_events()
		await get_tree().process_frame


func _wheel(p: Vector2, up: bool) -> void:
	var b := InputEventMouseButton.new()
	b.button_index = MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN
	b.pressed = true
	b.position = p
	b.global_position = p
	Input.parse_input_event(b)
	Input.flush_buffered_events()


func _drag(a: Vector2, b: Vector2) -> void:
	var d := InputEventMouseButton.new()
	d.button_index = MOUSE_BUTTON_LEFT
	d.pressed = true
	d.position = a
	d.global_position = a
	Input.parse_input_event(d)
	for k in 6:
		var m := InputEventMouseMotion.new()
		var p := a.lerp(b, float(k + 1) / 6.0)
		m.position = p
		m.global_position = p
		m.relative = (b - a) / 6.0
		m.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(m)
		Input.flush_buffered_events()
		await get_tree().process_frame
	var u := InputEventMouseButton.new()
	u.button_index = MOUSE_BUTTON_LEFT
	u.pressed = false
	u.position = b
	u.global_position = b
	Input.parse_input_event(u)
	Input.flush_buffered_events()
	await get_tree().process_frame


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	var path := "%s_%s.png" % [out, name]
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)


## A campaign six years in: the Vitale family (0) is doing well.
func _fill() -> void:
	var me := 0
	var f: Dictionary = Game.fam(me)
	f["dirty"] = 4820
	f["clean"] = 9350
	f["rep"] = 44
	f["income"] = {"protection": 1340, "speakeasy": 920, "legit": 410, "laundered": 1350, "wages": 960,
		"payroll": 470, "support": 100, "wholesale": 260, "convoys": 180, "supply": 90}
	# shops: every laundry and pawnshop (two rings done), and a spread of others
	var n := 0
	for b in Game.biz:
		var kind := String(b["kind"])
		if kind in ["club", "precinct", "warehouse", "poolhall"]:
			continue
		if int(b["protector"]) >= 0 and int(b["protector"]) != me:
			if kind in ["laundry", "pawnshop"]:
				b["protector"] = me
			continue
		if kind in ["laundry", "pawnshop"] or (n % 3 == 0 and n < 60):
			b["protector"] = me
		n += 1
	var mine := Game.shops_of(me).filter(func(b: Dictionary) -> bool: return String(b["kind"]) != "club")
	for k in mine.size():
		var b: Dictionary = mine[k]
		if k % 4 == 1:
			b["envelope"] = int(b["rate"]) * (1 + k % 3)
		if k == 5:
			b["unpaid"] = 1
	for k in 3:
		var b: Dictionary = mine[k * 5 + 2]
		b["owned_by"] = me
		if k < 2:
			b["speak"] = true
			b["stock"] = 12 + k * 9
	mine[9]["closed_until"] = Game.month + 1
	# a warehouse on the quay
	for b in Game.biz:
		if String(b["kind"]) == "warehouse":
			b["owned_by"] = me
			b["protector"] = me
			break
	# men: every specialty, every task
	var tasks := [["follow", -1], ["guard", int(mine[0]["id"])], ["collect", int(mine[3]["id"])], ["booze", 20], ["idle", -1], ["take", int(Game.biz[40]["id"])]]
	var crew := Game.crew_of(me)
	while crew.size() < 7:
		Game._add_crew(me, "soldier" if crew.size() % 2 == 0 else "associate")
		crew = Game.crew_of(me)
	for k in crew.size():
		var c: Dictionary = crew[k]
		c["trait"] = Rackets.TRAIT_ORDER[k % Rackets.TRAIT_ORDER.size()]
		c["loyalty"] = [82, 64, 45, 91, 28, 70, 55][k % 7]
		var t: Array = tasks[k % tasks.size()]
		c["task"] = t[0]
		c["target"] = t[1]
		if t[0] == "booze":
			c["booze"] = 20
			c["target"] = int(Game.nyc_warehouse(me).get("id", -1))
		if k == 0:
			c["rank"] = "capo"
	crew[6]["state"] = "jailed"
	crew[6]["jail_until"] = Game.month + 5
	var rat := Game._add_crew(me, "associate")
	rat["state"] = "rat"
	rat["loyalty"] = 12
	var capo := Game._add_crew(me, "capo")
	capo["state"] = "away"
	capo["task"] = "city:chi"
	# the Bureau's file
	Game.add_evidence(me, "witness", "Sal Esposito (Mulberry Bakery) saw you break his counter", 14.0, {"biz": 3})
	Game.add_evidence(me, "weapon", "Your gun: bullets from it in Little Italy", 12.0)
	Game.add_evidence(me, "body", "A Russo soldier found in an alley off Mott St.", 18.0)
	Game.add_evidence(me, "informant", "%s is talking to the District Attorney" % rat["name"], 35.0, {"crew": rat["id"]})
	Game.add_evidence(me, "street", "People on Grand St. talk about the Vitale boys", 5.0)
	Game.add_evidence(me, "ledger", "The accountant's books show money from speakeasies", 8.0)
	# rivals: war with 1, truce with 2, 4 finished
	Game.rel(me, 1)["war"] = true
	Game.rel(me, 2)["truce_until"] = Game.month + 7
	Game.fam(2)["kept"] = 3
	Game.fam(1)["broken"] = 2
	Game.fam(1)["kept"] = 1
	Game.fam(4)["alive"] = false
	for c in Game.crew:
		if int(c["family"]) == 4:
			c["state"] = "gone"
	for b in Game.biz:
		if int(b["protector"]) == 4 and int(b["owned_by"]) != 4:
			b["protector"] = -1
	Game.deals.append({"id": 9001, "from": 2, "to": me, "terms": {"kind": "alliance", "months": 12, "amount": 0, "against": 1}, "expires": Game.month + 1})
	Game.deals.append({"id": 9002, "from": 3, "to": me, "terms": {"kind": "truce", "months": 6, "amount": -500}, "expires": Game.month + 1})
	for c in Game.cops.slice(0, 2):
		c["payroll"] = me
	Game.captains["Little Italy"] = me
	# favors on a few shops
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var cands := Game.biz.filter(func(b: Dictionary) -> bool: return int(b["protector"]) < 0 and String(b["kind"]) not in ["club", "precinct", "warehouse", "poolhall"])
	for k in 3:
		Favors.make(Game, cands[k * 7], ["thugs", "debt", "parcel"][k], rng)


func _actors(world: FakeWorld) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var hq: Dictionary = Game.biz_by_id(int(Game.fam(0)["hq"]))
	var me := FakeActor.new()
	me.kind = "boss"
	me.family = 0
	me.position = W.door(hq) + Vector2(3, 2) * W.M
	world.add_child(me)
	world.local_actor = me
	world.actors["p1"] = me
	var n := 0
	for c in Game.crew:
		if String(c["state"]) != "free":
			continue
		var a := FakeActor.new()
		a.kind = "crew"
		a.family = int(c["family"])
		a.ref_id = int(c["id"])
		var home: Dictionary = Game.biz_by_id(int(Game.fam(a.family)["hq"]))
		a.position = W.door(home) + Vector2(rng.randf_range(-14, 14), rng.randf_range(-14, 14)) * W.M
		world.add_child(a)
		world.actors["c%d" % c["id"]] = a
		n += 1
	for k in 6:
		var a := FakeActor.new()
		a.kind = "cop"
		a.position = W.p(rng.randf_range(20, 280), rng.randf_range(0, 190))
		world.add_child(a)
		world.actors["k%d" % k] = a
	var boat := Node2D.new()
	var pier: Dictionary = Game.plan.piers[1]
	boat.position = W.p(float(pier["tip"][0]) + 7.0, float(pier["tip"][1]))
	boat.visible = true
	world.add_child(boat)
	world.boat = boat
