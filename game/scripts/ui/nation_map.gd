extends Control
## J: the country. Cities with a ring showing who holds how much of each, smuggling routes in
## the colour of whoever bought the officials along them, your convoys moving. Click a city or a
## route to see it and give orders: send men and guns, a capo, buy the police, order a hit, run
## booze, buy a route, ambush a route.

const INK := Color("efe6d2")
const MUTE := Color("9b907c")
const GOLD2 := Color("f0d58a")
const LAND := Color("2b2620")
const WATER := Color("0f171d")

# a rough eastern United States, Great Lakes and Florida, in map units (0..1)
const COAST := [[0.12, 0.2], [0.5, 0.2], [0.55, 0.23], [0.63, 0.27], [0.68, 0.24], [0.76, 0.2], [0.84, 0.17],
	[0.92, 0.16], [0.95, 0.21], [0.93, 0.25], [0.9, 0.3], [0.86, 0.34], [0.85, 0.38], [0.83, 0.43],
	[0.81, 0.48], [0.8, 0.52], [0.77, 0.57], [0.73, 0.62], [0.7, 0.67], [0.69, 0.72], [0.71, 0.8],
	[0.72, 0.88], [0.69, 0.9], [0.66, 0.83], [0.64, 0.76], [0.58, 0.74], [0.5, 0.78], [0.45, 0.82],
	[0.4, 0.8], [0.3, 0.78], [0.2, 0.8], [0.12, 0.78]]
const LAKES := [
	[[0.44, 0.22], [0.5, 0.21], [0.53, 0.25], [0.49, 0.27], [0.45, 0.26]],     # Superior
	[[0.49, 0.28], [0.51, 0.27], [0.52, 0.36], [0.5, 0.37], [0.49, 0.32]],     # Michigan
	[[0.54, 0.25], [0.58, 0.24], [0.59, 0.29], [0.56, 0.3], [0.54, 0.28]],     # Huron
	[[0.58, 0.32], [0.65, 0.3], [0.66, 0.31], [0.6, 0.34]],                    # Erie
	[[0.67, 0.28], [0.72, 0.27], [0.72, 0.29], [0.67, 0.3]],                   # Ontario
]

var hud: Node
var _sel := {}
var _panel: VBoxContainer
var _info: RichTextLabel
var _buttons: VBoxContainer
var _area := Rect2()
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var p := PanelContainer.new()
	p.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	p.offset_left = -440
	p.offset_top = 70
	p.offset_bottom = -20
	p.offset_right = -20
	add_child(p)
	_panel = VBoxContainer.new()
	_panel.add_theme_constant_override("separation", 8)
	p.add_child(_panel)
	_info = RichTextLabel.new()
	_info.bbcode_enabled = true
	_info.fit_content = true
	_info.custom_minimum_size = Vector2(390, 40)
	_panel.add_child(_info)
	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 5)
	_panel.add_child(_buttons)
	Game.state_changed.connect(func() -> void:
		if visible:
			_fill())


func open() -> void:
	if _sel.is_empty():
		_sel = {"type": "city", "id": "chi"}
	_fill()


func _process(delta: float) -> void:
	_t += delta
	if visible:
		queue_redraw()


func _to(p: Array) -> Vector2:
	return _area.position + Vector2(p[0], p[1]) * _area.size


func _fam_color(id: int) -> Color:
	var f := Game.fam(id)
	return Color(f.get("color", "#777777")) if not f.is_empty() else Color("6b6458")


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), WATER)
	var s := minf(size.x - 480.0, size.y - 100.0)
	_area = Rect2(Vector2(30, 70), Vector2(s * 1.25, s))
	var font := get_theme_default_font()
	var land := PackedVector2Array()
	for c in COAST:
		land.append(_to(c))
	draw_colored_polygon(land, LAND)
	draw_polyline(land + PackedVector2Array([land[0]]), Color("4a3d2c"), 2.0)
	for lake in LAKES:
		var pl := PackedVector2Array()
		for c in lake:
			pl.append(_to(c))
		draw_colored_polygon(pl, WATER)
	draw_string(font, _to([0.62, 0.12]), "CANADA", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.3))
	draw_string(font, _to([0.86, 0.62]), "ATLANTIC", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.25))
	draw_string(font, _to([0.5, 0.9]), "GULF OF MEXICO", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.25))
	draw_string(font, Vector2(30, 50), "The country · %s" % Game.date_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, INK)
	var nation: Dictionary = Game.nation
	if nation.is_empty():
		return
	var me := int(Game.player(Net.my_id()).get("family", -1))
	# routes
	for d in Syndicate.ROUTES:
		var r: Dictionary = nation["routes"][d["id"]]
		var a := _to(Syndicate.place_def(d["from"])["pos"])
		var b := _to(Syndicate.place_def(d["to"])["pos"])
		var owner: int = r["owner"]
		var col := _fam_color(owner) if owner >= 0 else Color(0.6, 0.55, 0.45, 0.5)
		var w := 5.0 if _sel.get("id", "") == d["id"] else 3.0
		if owner >= 0:
			draw_line(a, b, col, w)
		else:
			_dashed(a, b, col, w)
		var mine := int(r["convoys"].get(str(me), 0))
		if mine > 0:
			for k in 3:
				var t := fmod(_t * 0.12 + k / 3.0, 1.0)
				draw_circle(a.lerp(b, t), 4.0, Color(Game.fam(me)["color"]).lightened(0.3))
		if int(r["ambush"].get(str(me), 0)) > 0:
			draw_string(font, a.lerp(b, 0.5) + Vector2(6, -6), "✕ ambush", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("ff8a7a"))
	# sources
	for src in Syndicate.SOURCES:
		var p := _to(src["pos"])
		draw_rect(Rect2(p - Vector2(7, 7), Vector2(14, 14)), Color("c9a54a"))
		draw_string(font, p + Vector2(10, 5), src["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, GOLD2)
	# cities
	for c in Syndicate.CITIES:
		var p := _to(c["pos"])
		var cs: Dictionary = nation["cities"][c["id"]]
		var rad := 16.0 if c["id"] in ["nyc", "chi"] else 12.0
		draw_circle(p, rad + 5.0, Color(0, 0, 0, 0.6))
		draw_circle(p, rad, Color("3b3530"))
		if c["id"] == "nyc":
			# New York: shops held on the street
			var total := maxf(1.0, Game.biz.size())
			var start := -PI * 0.5
			for f in Game.families:
				var share := Game.shops_of(f["id"]).size() / total
				if share > 0.0:
					draw_arc(p, rad + 2.5, start, start + share * TAU, 24, Color(f["color"]), 5.0)
					start += share * TAU
		else:
			var start2 := -PI * 0.5
			for k in cs["influence"]:
				var share2 := float(cs["influence"][k]) / 100.0
				if share2 > 0.01:
					draw_arc(p, rad + 2.5, start2, start2 + share2 * TAU, 24, _fam_color(int(k)), 5.0)
					start2 += share2 * TAU
		var ctrl := Syndicate.controller(nation, c["id"])
		if ctrl >= 0:
			draw_circle(p, rad * 0.55, _fam_color(ctrl))
		if Syndicate.men_in(nation, c["id"], me) > 0:
			draw_string(font, p + Vector2(-6, 5), "%d" % Syndicate.men_in(nation, c["id"], me), HORIZONTAL_ALIGNMENT_CENTER, 12, 13, INK)
		var sel: bool = _sel.get("id", "") == c["id"]
		draw_string(font, p + Vector2(rad + 6, 6), c["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 18 if sel else 16, GOLD2 if sel else INK)
		if sel:
			draw_arc(p, rad + 9.0, 0, TAU, 32, GOLD2, 2.0)
	# legend
	var ly := size.y - 70.0
	var lx := 40.0
	for f in Game.families:
		draw_circle(Vector2(lx, ly), 7, Color(f["color"]))
		draw_string(font, Vector2(lx + 12, ly + 6), f["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, INK)
		lx += 150
	draw_string(font, Vector2(40, size.y - 30), "Click a city or a route · ring = who holds the city · filled centre = who runs it · squares = where the liquor comes from · J to close",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, MUTE)


func _dashed(a: Vector2, b: Vector2, col: Color, w: float) -> void:
	var len := a.distance_to(b)
	var n := int(len / 14.0)
	for k in n:
		if k % 2 == 0:
			draw_line(a.lerp(b, float(k) / n), a.lerp(b, float(k + 1) / n), col, w)


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var m: Vector2 = e.position
		var best := {}
		var bd := 26.0
		for c in Syndicate.CITIES:
			var d := _to(c["pos"]).distance_to(m)
			if d < bd:
				bd = d
				best = {"type": "city", "id": c["id"]}
		if best.is_empty():
			bd = 12.0
			for r in Syndicate.ROUTES:
				var a := _to(Syndicate.place_def(r["from"])["pos"])
				var b := _to(Syndicate.place_def(r["to"])["pos"])
				var d2 := Geometry2D.get_closest_point_to_segment(m, a, b).distance_to(m)
				if d2 < bd:
					bd = d2
					best = {"type": "route", "id": r["id"]}
		if not best.is_empty():
			_sel = best
			_fill()
		accept_event()


func _btn(text: String, args: Array, enabled: bool = true) -> void:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(func() -> void: Net.to_host("nation", args))
	_buttons.add_child(b)


func _fill() -> void:
	for c in _buttons.get_children():
		c.queue_free()
	var nation: Dictionary = Game.nation
	if nation.is_empty() or _sel.is_empty():
		return
	var me := int(Game.player(Net.my_id()).get("family", -1))
	var f := Game.fam(me)
	var money := int(f.get("dirty", 0))
	if _sel["type"] == "city":
		var c := Syndicate.city_def(_sel["id"])
		var cs: Dictionary = nation["cities"][c["id"]]
		var t := "[font_size=26]%s[/font_size]\n[color=#9b907c]%s[/color]\n" % [c["name"], c["note"]]
		if c["id"] == "nyc":
			t += "\nYou run New York yourself, on the street. Shops paying each family:\n"
			for fm in Game.families:
				t += "  [color=%s]%s[/color]: %d\n" % [fm["color"], fm["name"], Game.shops_of(fm["id"]).size()]
			_info.text = t
			return
		t += "Thirst: %d crates a month · local outfit: %s\n" % [c["demand"], c["outfit"]]
		var ctrl := Syndicate.controller(nation, c["id"])
		t += "Runs the city: [b]%s[/b]\n" % (Game.fam(ctrl)["name"] if ctrl >= 0 else c["outfit"])
		for k in cs["influence"]:
			var fm := Game.fam(int(k))
			var capo_id := int(cs["capo"].get(k, -1))
			var capo := ("  · capo %s" % Game.crew_by_id(capo_id).get("name", "")) if capo_id >= 0 else ""
			t += "  [color=%s]%s[/color]: %d%% · %d men · %d guns%s\n" % [fm.get("color", "#fff"), fm.get("name", "?"), int(cs["influence"][k]),
				Syndicate.men_in(nation, c["id"], int(k)), Syndicate.guns_in(nation, c["id"], int(k)), capo]
		var pol: int = cs["police"]
		t += "Police: %s" % ("on the %s payroll" % Game.fam(pol)["name"] if pol >= 0 else "not bought")
		_info.text = t
		var ars: Dictionary = f.get("arsenal", {})
		var guns := int(ars.get("pistol", 0)) + int(ars.get("tommy", 0))
		var capo_c := -1
		for cm in Game.crew_of(me):
			if cm["rank"] == "soldier":
				capo_c = cm["id"]
				break
		if capo_c < 0 and not Game.crew_of(me).is_empty():
			capo_c = Game.crew_of(me)[0]["id"]
		_btn("Send 2 men ($500 to set them up, $90 a month each)", ["send", c["id"], 2, 0, -1], money >= 500)
		_btn("Send 4 men with %d guns ($1,000)" % mini(4, guns), ["send", c["id"], 4, mini(4, guns), -1], money >= 1000)
		if not cs["capo"].has(str(me)) and capo_c >= 0:
			_btn("Send %s as capo, with 2 men ($500)" % Game.crew_by_id(capo_c)["name"], ["send", c["id"], 2, mini(2, guns), capo_c], money >= 500)
		_btn("Buy the %s police ($%d)" % [c["name"], 2500 if c["id"] == "kc" else 1200], ["police", c["id"]], pol != me and money >= 1200)
		for k in cs["men"]:
			var other := int(k)
			if other != me and int(cs["men"][k]) > 0:
				_btn("Order a hit on the %s family's people here ($%d)" % [Game.fam(other)["name"], Syndicate.HIT_COST], ["hit", c["id"], other], money >= Syndicate.HIT_COST)
		if Syndicate.men_in(nation, c["id"], me) > 0:
			_btn("Bring your men home", ["recall", c["id"]])
	else:
		var d := Syndicate.route_def(_sel["id"])
		var r: Dictionary = nation["routes"][d["id"]]
		var src := Syndicate.source_def(d["from"])
		var dest := Syndicate.city_def(d["to"])
		var owner: int = r["owner"]
		var t2 := "[font_size=26]%s[/font_size]\n%s → %s\n[color=#9b907c]%s[/color]\n" % [d["name"], src["name"], dest["name"], src["note"]]
		t2 += "Capacity %d crates a month · $%d a crate at the source · risk %d%%\n" % [d["cap"], src["price"], int(d["risk"] * 100)]
		t2 += "Officials bought by: [b]%s[/b]\n" % (Game.fam(owner)["name"] if owner >= 0 else "nobody")
		var mine := int(r["convoys"].get(str(me), 0))
		t2 += "Your convoys: %s\n" % ("%d crates a month" % mine if mine > 0 else "none")
		var amb := int(r["ambush"].get(str(me), 0))
		if amb > 0:
			t2 += "Your hijackers: %d men waiting\n" % amb
		if String(r["last"]) != "":
			t2 += "Last month: %s\n" % r["last"]
		t2 += "[color=#9b907c]New York crates go into your speakeasy cellars; anywhere else they're sold wholesale, better if you hold the city.[/color]"
		_info.text = t2
		for n in [20, 50, d["cap"]]:
			_btn("Run %d crates a month" % n, ["convoy", d["id"], n], n != mine)
		if mine > 0:
			_btn("Stop the convoys", ["convoy", d["id"], 0])
		_btn("Buy the customs men and sheriffs ($%d)" % (int(d["bribe"]) + (800 if owner >= 0 else 0)), ["route", d["id"]], owner != me and money >= int(d["bribe"]))
		_btn("Wait on this road with 3 men and hijack the other families' trucks", ["ambush", d["id"], 3], amb == 0)
		if amb > 0:
			_btn("Call off the hijackers", ["ambush", d["id"], 0])
