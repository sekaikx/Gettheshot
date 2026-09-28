extends Node2D
## Test sheets for Person2D (people from above) and Portrait (busts for dialogs). Builds a few
## groups far apart in the world, points the camera at each, saves a PNG and quits.
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --rendering-driver opengl3 --path game res://tools/test/test_people.tscn
## Env: OUT_DIR=dir (default /tmp), SHOTS=kinds,shops,anims,actions,z10,z06,night,portraits,portraits_small (default all)

const KINDS := ["boss", "aiboss", "crew", "cop", "fed", "ped", "woman", "kid", "newsboy", "shop", "recruit",
	"smuggler", "dealer", "docker", "unionboss", "consigliere", "bartender", "patron"]
const TRADES := ["bakery", "butcher", "grocer", "tailor", "barber", "cobbler", "pawnshop", "laundry",
	"restaurant", "cafe", "candy", "hardware", "drugstore", "cigar", "fish"]
const RED := Color("#c42828")
const BLUE := Color("#3c6ec8")

var out_dir := "/tmp"
var cam: Camera2D
var night: CanvasModulate


class Ground extends Node2D:
	var rect := Rect2()
	var street := false

	func _draw() -> void:
		Draw.rect(self, rect, Pal.SIDEWALK)
		var slab := 72.0
		var x := rect.position.x
		while x < rect.end.x:
			draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), Pal.SLAB_JOINT, 1.0)
			x += slab
		var y := rect.position.y
		while y < rect.end.y:
			draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), Pal.SLAB_JOINT, 1.0)
			y += slab
		if street:
			var s := Rect2(rect.position + Vector2(0, rect.size.y * 0.55), Vector2(rect.size.x, rect.size.y * 0.45))
			Draw.rect(self, s, Pal.ASPHALT)
			Draw.rect(self, Rect2(s.position, Vector2(s.size.x, 6)), Pal.CURB)


class Tag extends Node2D:
	var text := ""
	var size := 11

	func _draw() -> void:
		Draw.text(self, Vector2.ZERO, text, size, Pal.INK, W.font("cond"), HORIZONTAL_ALIGNMENT_CENTER, -1.0, 3, Color(0.05, 0.04, 0.03, 0.9))


class Sheet extends Control:
	var items: Array = []     # [{rect, kind, look, color, extra, mood, label}]

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("171210"))
		for it in items:
			var r: Rect2 = it["rect"]
			Portrait.draw(self, r, it["kind"], it["look"], it["color"], it["extra"], it["mood"])
			if it["label"] != "":
				var f := W.ui_font("cond")
				var fs := 13 if r.size.x > 100 else 10
				var tw := f.get_string_size(it["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				draw_string(f, Vector2(r.get_center().x - tw * 0.5, r.end.y + fs + 2), it["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Pal.INK)


func _ready() -> void:
	Game.new_campaign({"seed": 1923, "families": 4}, [{"peer": 1, "name": "Alex", "family_name": "Vitale", "color": "#c42828"}])
	Game.running = false
	if OS.get_environment("OUT_DIR") != "":
		out_dir = OS.get_environment("OUT_DIR")
	var want := OS.get_environment("SHOTS")
	var shots := ["kinds", "shops", "anims", "actions", "z10", "z06", "night", "portraits", "portraits_small"]
	if want != "":
		shots = Array(want.split(","))
	cam = Camera2D.new()
	add_child(cam)
	night = CanvasModulate.new()
	night.color = Color.WHITE
	add_child(night)
	for s in shots:
		match s:
			"kinds": await _shot_kinds(1.6, "kinds_z16")
			"z10": await _shot_kinds(1.0, "kinds_z10", true)
			"z06": await _shot_crowd(0.6, "crowd_z06", false)
			"night": await _shot_crowd(1.0, "crowd_night", true)
			"shops": await _shot_shops()
			"anims": await _shot_anims()
			"actions": await _shot_actions()
			"portraits": await _shot_portraits()
			"portraits_small": await _shot_portraits_small()
			"close": await _shot_close()
			"portraits_big": await _shot_portraits_big()
			"perf": await _perf()
			"bench": await _bench()
	get_tree().quit()


func _fam(k: String) -> Color:
	return RED if k in ["boss", "crew", "consigliere"] else (BLUE if k == "aiboss" else W.FAMILY_NONE)


func _person(parent: Node, k: String, lk: int, pos: Vector2, rot: float = 0.0, ex: Dictionary = {}) -> Person2D:
	# set up before it enters the tree, the way an Actor may do it
	var p := Person2D.new()
	p.position = pos
	p.rotation = rot
	p.setup(k, lk, _fam(k), ex)
	parent.add_child(p)
	return p


func _tag(parent: Node, text: String, pos: Vector2, size: int = 11) -> void:
	var t := Tag.new()
	t.text = text
	t.size = size
	t.position = pos
	t.z_index = 50
	parent.add_child(t)


func _group(origin: Vector2, rect: Rect2, street: bool = false) -> Node2D:
	var g := Node2D.new()
	g.position = origin
	add_child(g)
	var gr := Ground.new()
	gr.rect = rect
	gr.street = street
	gr.z_index = -100
	g.add_child(gr)
	return g


func _snap(center: Vector2, zoom: float, shot: String) -> void:
	cam.position = center
	cam.zoom = Vector2(zoom, zoom)
	for i in 6:
		await get_tree().process_frame
	var path := out_dir.path_join(shot + ".png")
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("saved ", path)
	# magnified quarters (nearest neighbour) to judge the real pixels
	if OS.get_environment("CROPS") == "1":
		var sz := img.get_size()
		for q in 4:
			var half := Vector2i(sz.x >> 1, sz.y >> 1)
			var r := Rect2i(Vector2i((q % 2) * half.x, (q >> 1) * half.y), half)
			var part := img.get_region(r)
			part.resize(sz.x, sz.y, Image.INTERPOLATE_NEAREST)
			part.save_png(out_dir.path_join("%s_q%d.png" % [shot, q]))


func _clear(g: Node) -> void:
	g.queue_free()
	await get_tree().process_frame


## Every kind x 3 looks, idle. At zoom 1.0 the three looks face different ways (light check).
func _shot_kinds(zoom: float, shot: String, turned: bool = false) -> void:
	var origin := Vector2(0, 0)
	var view := Vector2(1600, 900) / zoom
	var g := _group(origin, Rect2(-view * 0.5 - Vector2(40, 40), view + Vector2(80, 80)))
	var cols := 6
	var cell := Vector2(view.x / cols, view.y / 3.2)
	for i in KINDS.size():
		var cx := (i % cols) - (cols - 1) * 0.5
		var cy := floorf(i / float(cols)) - 1.0
		var c := Vector2(cx * cell.x, cy * cell.y)
		for n in 3:
			var rot := 0.0
			if turned:
				rot = [0.0, PI * 0.5, -PI * 0.75][n]
			_person(g, KINDS[i], 1000 + n * 7919 + i * 31, c + Vector2((n - 1) * 44.0, -6.0), rot, {"trade": TRADES[(i + n) % TRADES.size()]})
		_tag(g, KINDS[i], c + Vector2(0, 42), 12 if zoom < 1.3 else 10)
	await _snap(origin, zoom, shot)
	await _clear(g)


func _shot_shops() -> void:
	var origin := Vector2(0, 4000)
	var g := _group(origin, Rect2(-560, -320, 1120, 640))
	var cols := 5
	for i in TRADES.size():
		var cx := (i % cols) - (cols - 1) * 0.5
		var cy := floorf(i / float(cols)) - 1.0
		var c := Vector2(cx * 200.0, cy * 175.0)
		for n in 2:
			_person(g, "shop", 500 + n * 104729 + i * 17, c + Vector2((n - 0.5) * 50.0, -10.0), [0.0, PI * 0.5][n], {"trade": TRADES[i]})
		_tag(g, TRADES[i], c + Vector2(0, 40), 10)
	await _snap(origin, 1.6, "shops_z16")
	await _clear(g)


## Each looping state, and weapons at rest, for three kinds.
func _shot_anims() -> void:
	var origin := Vector2(0, 8000)
	var g := _group(origin, Rect2(-560, -320, 1120, 640))
	var states := [["IDLE", Person2D.Anim.IDLE, 0.0], ["WALK", Person2D.Anim.WALK, 1.0], ["RUN", Person2D.Anim.RUN, 2.0],
		["CARRY", Person2D.Anim.CARRY, 1.0], ["TALK", Person2D.Anim.TALK, 0.0], ["ARMS", Person2D.Anim.ARMS, 0.0],
		["SIT", Person2D.Anim.SIT, 0.0], ["DOWN", Person2D.Anim.DOWN, 0.0], ["DEAD", Person2D.Anim.DEAD, 0.0]]
	var who := [["boss", 11], ["cop", 12], ["woman", 13]]
	for row in who.size():
		for i in states.size():
			var c := Vector2(-440.0 + i * 110.0, -215.0 + row * 125.0)
			var st: Array = states[i]
			var p := _person(g, who[row][0], who[row][1], c, 0.0)
			var stride := 0.0
			if st[2] == 1.0:
				stride = 10.0
			elif st[2] == 2.0:
				stride = 16.0
			if st[1] == Person2D.Anim.CARRY:
				p.carry(true)
			if st[1] == Person2D.Anim.DEAD:
				p.pose_at(st[1], "die", 7.0)
			elif st[1] == Person2D.Anim.DOWN:
				p.pose_at(st[1], "down", 2.0)
			else:
				p.pose_at(st[1], "", 0.0, stride, PI * 0.5)
			if row == 0:
				_tag(g, st[0], c + Vector2(0, -44), 10)
	# weapons at rest and walking
	var wy := 170.0
	var wx := -440.0
	for wpn in ["pistol", "tommy", "bat"]:
		for n in 2:
			var p := _person(g, "crew", 21 + n, Vector2(wx, wy), 0.0)
			p.set_weapon(wpn)
			p.pose_at(Person2D.Anim.WALK if n == 1 else Person2D.Anim.IDLE, "", 0.0, 10.0 * n, PI * 0.5)
			wx += 110.0
		_tag(g, wpn, Vector2(wx - 165.0, wy + 42.0), 10)
	var ringed := _person(g, "boss", 5, Vector2(wx + 40.0, wy), -PI * 0.5)
	ringed.set_ring(RED)
	ringed.pose_at(Person2D.Anim.IDLE)
	_tag(g, "ring", Vector2(wx + 40.0, wy + 42.0), 10)
	await _snap(origin, 1.6, "anims_z16")
	await _clear(g)


## One-shot actions caught mid-way.
func _shot_actions() -> void:
	var origin := Vector2(0, 12000)
	var g := _group(origin, Rect2(-560, -320, 1120, 640))
	var acts := [["punch", "", 0.1], ["hit", "", 0.07], ["shoot", "pistol", 0.02], ["shoot", "tommy", 0.02],
		["yes", "", 0.18], ["no", "", 0.2], ["interact", "", 0.25], ["pickup", "", 0.28],
		["smash", "", 0.25], ["smash", "bat", 0.36], ["punch", "bat", 0.2], ["threaten", "", 0.5],
		["threaten", "pistol", 0.5], ["threaten", "tommy", 0.5], ["threaten", "bat", 0.5], ["talk", "", 0.4],
		["down", "", 0.16], ["die", "", 0.5], ["die", "", 2.5], ["shoot", "pistol", 0.12]]
	var cols := 7
	for i in acts.size():
		var a: Array = acts[i]
		var cx := (i % cols) - (cols - 1) * 0.5
		var cy := floorf(i / float(cols)) - 1.0
		var c := Vector2(cx * 145.0, cy * 175.0)
		var p := _person(g, "crew" if i % 2 == 0 else "recruit", 40 + i, c + Vector2(-14.0, -6.0), 0.0)
		p.set_weapon(a[1])
		if a[0] in ["down", "die"]:
			p.pose_at(Person2D.Anim.DEAD if a[0] == "die" else Person2D.Anim.DOWN, a[0], a[2])
		else:
			p.pose_at(Person2D.Anim.IDLE, a[0], a[2])
		var label: String = a[0] + ("" if a[1] == "" else " " + a[1]) + " %.2fs" % a[2]
		_tag(g, label, c + Vector2(0, 50), 10)
	await _snap(origin, 1.6, "actions_z16")
	await _clear(g)


## A crowd on a sidewalk and street: mixed kinds, walking in all directions.
func _shot_crowd(zoom: float, shot: String, dark: bool) -> void:
	var origin := Vector2(0, 16000)
	var view := Vector2(1600, 900) / zoom
	var g := _group(origin, Rect2(-view * 0.5 - Vector2(40, 40), view + Vector2(80, 80)), true)
	var r := W.rng(77)
	var n := 70 if zoom < 0.8 else 40
	for i in n:
		var k: String = KINDS[r.randi() % KINDS.size()]
		var pos := Vector2(r.randf_range(-view.x * 0.46, view.x * 0.46), r.randf_range(-view.y * 0.44, view.y * 0.44))
		var p := _person(g, k, r.randi(), pos, r.randf_range(-PI, PI), {"trade": TRADES[r.randi() % TRADES.size()]})
		var roll := r.randf()
		if roll < 0.45:
			p.pose_at(Person2D.Anim.WALK, "", 0.0, r.randf_range(6.0, 11.0), r.randf_range(0.0, TAU))
		elif roll < 0.55:
			p.carry(true)
			p.pose_at(Person2D.Anim.CARRY, "", 0.0, 7.0, r.randf_range(0.0, TAU))
		elif roll < 0.62:
			p.pose_at(Person2D.Anim.ARMS)
		elif roll < 0.68:
			p.pose_at(Person2D.Anim.TALK)
		else:
			p.pose_at(Person2D.Anim.IDLE)
	if dark:
		night.color = Color(0.3, 0.33, 0.52)
	await _snap(origin, zoom, shot)
	night.color = Color.WHITE
	await _clear(g)


func _shot_portraits() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var sheet := Sheet.new()
	sheet.size = Vector2(1600, 900)
	layer.add_child(sheet)
	var sz := 160.0
	for i in KINDS.size():
		var col := i % 9
		var row := int(i / 9.0)
		var r := Rect2(Vector2(22 + col * 175, 20 + row * 200), Vector2(sz, sz))
		sheet.items.append({"rect": r, "kind": KINDS[i], "look": 1000 + i * 31, "color": _fam(KINDS[i]),
			"extra": {"trade": "bakery"}, "mood": "", "label": KINDS[i]})
	var moods := ["", "angry", "scared", "happy", "smug"]
	for m in moods.size():
		for n in 2:
			var k := "boss" if n == 0 else "shop"
			var r := Rect2(Vector2(22 + (m * 2 + n) * 157, 430), Vector2(140, 140))
			sheet.items.append({"rect": r, "kind": k, "look": 1000 if n == 0 else 1000 + 9 * 31, "color": _fam(k),
				"extra": {"trade": "bakery"}, "mood": moods[m], "label": (moods[m] if moods[m] != "" else "neutral")})
	for i in 12:
		var k: String = ["crew", "cop", "woman", "consigliere", "dealer", "unionboss"][i % 6]
		var r := Rect2(Vector2(22 + i * 130, 630), Vector2(120, 120))
		sheet.items.append({"rect": r, "kind": k, "look": 3000 + i * 977, "color": _fam(k), "extra": {},
			"mood": moods[i % 5], "label": k})
	sheet.queue_redraw()
	await _snap(cam.position, 1.0, "portraits_160")
	layer.queue_free()
	await get_tree().process_frame


func _shot_portraits_small() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var sheet := Sheet.new()
	sheet.size = Vector2(1600, 900)
	layer.add_child(sheet)
	# every kind x 3 looks at 64 px, then shopkeepers of every trade at 96 px
	for i in KINDS.size():
		for n in 3:
			var r := Rect2(Vector2(20 + (i % 9) * 176 + n * 56, 20 + int(i / 9.0) * 100), Vector2(52, 52))
			sheet.items.append({"rect": r, "kind": KINDS[i], "look": 1000 + i * 31 + n * 7919, "color": _fam(KINDS[i]),
				"extra": {"trade": TRADES[(i + n) % TRADES.size()]}, "mood": "", "label": KINDS[i] if n == 1 else ""})
	for i in TRADES.size():
		var r := Rect2(Vector2(20 + (i % 8) * 196, 240 + int(i / 8.0) * 130), Vector2(96, 96))
		sheet.items.append({"rect": r, "kind": "shop", "look": 500 + i * 17, "color": W.FAMILY_NONE,
			"extra": {"trade": TRADES[i]}, "mood": "", "label": TRADES[i]})
	for i in 10:
		var r := Rect2(Vector2(20 + i * 158, 520), Vector2(64, 64))
		var k: String = KINDS[(i * 5) % KINDS.size()]
		sheet.items.append({"rect": r, "kind": k, "look": 77 + i * 131, "color": _fam(k), "extra": {},
			"mood": ["", "angry", "scared", "happy", "smug"][i % 5], "label": k})
	var big := Rect2(Vector2(20, 640), Vector2(240, 240))
	sheet.items.append({"rect": big, "kind": "boss", "look": 1000, "color": RED, "extra": {}, "mood": "smug", "label": ""})
	var big2 := Rect2(Vector2(280, 640), Vector2(240, 240))
	sheet.items.append({"rect": big2, "kind": "consigliere", "look": 1465, "color": RED, "extra": {}, "mood": "", "label": ""})
	var big3 := Rect2(Vector2(540, 640), Vector2(240, 240))
	sheet.items.append({"rect": big3, "kind": "woman", "look": 1198, "color": W.FAMILY_NONE, "extra": {}, "mood": "happy", "label": ""})
	var ctl := Portrait.control("cop", 4242, W.FAMILY_NONE, {}, "angry")
	ctl.position = Vector2(820, 640)
	ctl.size = Vector2(120, 120)
	layer.add_child(ctl)
	sheet.queue_redraw()
	await _snap(cam.position, 1.0, "portraits_64")
	layer.queue_free()
	await get_tree().process_frame


## A few people up close (zoom 5), to check the drawing itself.
func _shot_close() -> void:
	var origin := Vector2(0, 20000)
	var g := _group(origin, Rect2(-200, -120, 400, 240))
	var ks := ["boss", "crew", "cop", "woman", "aiboss", "shop", "docker", "unionboss"]
	var env := OS.get_environment("CLOSE")
	if env != "":
		ks = Array(env.split(","))
	for i in ks.size():
		var p := _person(g, ks[i], 1000 + i * 31, Vector2(-140.0 + (i % 4) * 93.0, -40.0 + floorf(i / 4.0) * 80.0), 0.0, {"trade": "butcher"})
		var anim := OS.get_environment("CLOSE_ANIM")
		if anim != "":
			p.pose_at(Person2D.Anim.keys().find(anim), OS.get_environment("CLOSE_ACT"), float(OS.get_environment("CLOSE_T")) if OS.get_environment("CLOSE_T") != "" else 0.0)
		else:
			p.pose_at(Person2D.Anim.WALK if i % 2 == 1 else Person2D.Anim.IDLE, "", 0.0, 9.0 if i % 2 == 1 else 0.0, PI * 0.5)
	await _snap(origin + Vector2(0, 0), 2.6, "close")
	await _clear(g)


## Four big portraits (400 px) to check the painting itself. Env BIG=kind:look:mood,...
func _shot_portraits_big() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var sheet := Sheet.new()
	sheet.size = Vector2(1600, 900)
	layer.add_child(sheet)
	var spec := "consigliere:1465:,woman:1198:happy,aiboss:1031:angry,cop:4242:smug"
	if OS.get_environment("BIG") != "":
		spec = OS.get_environment("BIG")
	var items := spec.split(",")
	for i in items.size():
		var parts := items[i].split(":")
		var k := parts[0]
		var r := Rect2(Vector2(10 + i * 397, 200), Vector2(390, 390))
		sheet.items.append({"rect": r, "kind": k, "look": int(parts[1]), "color": _fam(k), "extra": {"trade": parts[3] if parts.size() > 3 else "bakery"},
			"mood": parts[2] if parts.size() > 2 else "", "label": k})
	sheet.queue_redraw()
	await _snap(cam.position, 1.0, "portraits_big")
	layer.queue_free()
	await get_tree().process_frame


## Frame time with 80 people walking, turning and acting (not frozen), against an empty frame.
func _perf() -> void:
	var g := _group(Vector2(0, 30000), Rect2(-900, -500, 1800, 1000))
	cam.position = Vector2(0, 30000)
	cam.zoom = Vector2.ONE
	for i in 30:
		await get_tree().process_frame
	var t0 := Time.get_ticks_usec()
	for i in 60:
		await get_tree().process_frame
	var empty := (Time.get_ticks_usec() - t0) / 60.0
	var people: Array = []
	var r := W.rng(5)
	for i in 80:
		var p := _person(g, KINDS[i % KINDS.size()], r.randi(), Vector2(r.randf_range(-750, 750), r.randf_range(-400, 400)), r.randf_range(-PI, PI))
		people.append(p)
	for i in 30:
		await get_tree().process_frame
	t0 = Time.get_ticks_usec()
	for f in 120:
		for k in people.size():
			var p: Person2D = people[k]
			if k % 3 == 0:
				p.set_motion(Person2D.Anim.WALK, 1.4)
				p.rotation += 0.01
			elif k % 3 == 1:
				p.set_motion(Person2D.Anim.IDLE, 0.0)
			else:
				p.set_motion(Person2D.Anim.RUN, 4.0)
			if f % 40 == k % 40:
				p.action(["punch", "shoot", "talk", "hit"][k % 4])
		await get_tree().process_frame
	var busy := (Time.get_ticks_usec() - t0) / 120.0
	print("PERF empty frame %.2f ms, 80 people %.2f ms (+%.2f ms)" % [empty / 1000.0, busy / 1000.0, (busy - empty) / 1000.0])
	await _clear(g)


class Bench extends Node2D:
	func _draw() -> void:
		var n := 2000
		var pts := Draw.ellipse_points(Vector2.ZERO, Vector2(5, 3), 0.0, 16)
		var idx := PackedInt32Array()
		for i in 14:
			idx.append_array([0, i + 1, i + 2])
		var cols := PackedColorArray()
		cols.resize(16)
		cols.fill(Color.RED)
		var img := Image.create(64, 64, true, Image.FORMAT_RGBA8)
		for y in 64:
			for x in 64:
				var d := Vector2(x + 0.5 - 32.0, y + 0.5 - 32.0).length()
				img.set_pixel(x, y, Color(1, 1, 1, clampf(31.0 - d, 0.0, 1.0)))
		img.generate_mipmaps()
		var tex := ImageTexture.create_from_image(img)
		var tests := {
			"texture_rect disc": func() -> void: draw_texture_rect(tex, Rect2(Vector2(7, 7), Vector2(6, 6)), false, Color.RED),
			"xform+texture ellipse": func() -> void:
				draw_set_transform_matrix(Transform2D(0.3, Vector2(2, 2)))
				draw_texture_rect(tex, Rect2(Vector2(-5, -3), Vector2(10, 6)), false, Color.RED),
			"draw_circle aa": func() -> void: draw_circle(Vector2(10, 10), 3.0, Color.RED, true, -1.0, true),
			"draw_circle": func() -> void: draw_circle(Vector2(10, 10), 3.0, Color.RED),
			"draw_line aa w6": func() -> void: draw_line(Vector2(0, 0), Vector2(10, 3), Color.RED, 6.0, true),
			"draw_line w6": func() -> void: draw_line(Vector2(0, 0), Vector2(10, 3), Color.RED, 6.0),
			"colored_polygon16": func() -> void: draw_colored_polygon(pts, Color.RED),
			"triangle_array16": func() -> void: RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), idx, pts, cols),
			"polyline aa 17": func() -> void: draw_polyline(pts, Color.RED, 1.0, true),
			"Draw.capsule": func() -> void: Draw.capsule(self, Vector2(0, 0), Vector2(10, 3), 3.0, Color.RED),
			"Draw.ellipse": func() -> void: Draw.ellipse(self, Vector2(0, 0), Vector2(5, 3), Color.RED),
			"set_transform": func() -> void: draw_set_transform_matrix(Transform2D(0.3, Vector2(2, 2))),
		}
		for k in tests:
			var f: Callable = tests[k]
			var t0 := Time.get_ticks_usec()
			for i in n:
				f.call()
			print("BENCH %-20s %.2f us" % [k, float(Time.get_ticks_usec() - t0) / n])
		var t1 := Time.get_ticks_usec()
		for i in n:
			pass
		print("BENCH %-20s %.2f us" % ["empty call loop", float(Time.get_ticks_usec() - t1) / n])


func _bench() -> void:
	var b := Bench.new()
	add_child(b)
	for i in 3:
		await get_tree().process_frame
	b.queue_free()
