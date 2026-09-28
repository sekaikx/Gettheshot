extends Control
## J (or the map table in your club): the country. The 1920s atlas plate (assets/map/country_map.png,
## baked by tools/map/build_map.py) lies on the don's desk; over it, in ink: every city with a ring
## showing who holds it, the smuggling routes in the colour of whoever bought the officials, your
## convoys and freight moving, the sources of the liquor. Click a city, a route, a rail line or a
## source: the card on the right says what it is and what you can do, in plain words.
##
## Everything is placed by latitude/longitude through Syndicate.project() (MapProjection).

const PLATE := "res://assets/map/country_map.jpg"
const DESK := Color("1c1510")
const CARD := Color("ece2c8")
const CARD_EDGE := Color("b9a67e")
const INK := Color("20160c")
const INK_SOFT := Color("5a4a36")
const HALO := Color(0.93, 0.89, 0.78, 0.92)
const OXBLOOD := Color("8b1e1a")
const GOLD := Color("b8862c")
const NOBODY := Color(0.45, 0.4, 0.33, 0.9)

var hud: Node
var _sel := {}
var _card: PanelContainer
var _info: RichTextLabel
var _buttons: VBoxContainer
var _area := Rect2()      # the whole map, on screen (bigger than the frame when zoomed in)
var _frame := Rect2()     # the part of the screen the map is shown in
var _zoom := 1.0
var _center := Vector2(0.5, 0.5)
var _drag := false
var _t := 0.0
var _cache := {}
var _plate: Texture2D
var _hover := {}
var _fell: Font
var _fell_sc: Font
var _serif: Font
var _cond: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if ResourceLoader.exists(PLATE):
		_plate = load(PLATE)
	_fell = W.ui_font("fell")
	_fell_sc = W.ui_font("fell_sc")
	_serif = W.ui_font("serif")
	_cond = W.ui_font("cond")
	_card = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = CARD
	sb.border_color = CARD_EDGE
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(20)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 14
	sb.shadow_offset = Vector2(4, 6)
	_card.add_theme_stylebox_override("panel", sb)
	_card.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_card.offset_left = -440
	_card.offset_top = 70
	_card.offset_bottom = -24
	_card.offset_right = -22
	add_child(_card)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_card.add_child(scroll)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(v)
	_info = RichTextLabel.new()
	_info.bbcode_enabled = true
	_info.fit_content = true
	_info.custom_minimum_size = Vector2(380, 40)
	_info.add_theme_color_override("default_color", INK)
	_info.add_theme_font_override("normal_font", _fell)
	_info.add_theme_font_override("bold_font", _fell_sc)
	_info.add_theme_font_override("italics_font", W.ui_font("fell"))
	_info.add_theme_font_size_override("normal_font_size", 19)
	_info.add_theme_font_size_override("bold_font_size", 19)
	v.add_child(_info)
	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 6)
	v.add_child(_buttons)
	Game.state_changed.connect(func() -> void:
		if visible:
			_fill())


func open() -> void:
	if _sel.is_empty():
		_sel = {"type": "city", "id": "chi"}
		# start on the Northeast and the Great Lakes, where most of the cities are
		_zoom = 1.7
		_center = Syndicate.project(40.6, -79.5)
	_fill()


func _process(delta: float) -> void:
	_t += delta
	if visible:
		queue_redraw()


# ------------------------------------------------------------------ geometry

func _uv(key: String, pts: Array) -> PackedVector2Array:
	if not _cache.has(key):
		var uv := Syndicate.path_uv(pts)
		_cache[key] = MapProjection.smooth(uv, 6) if uv.size() >= 3 else uv
	return _cache[key]


func _pts(key: String, pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for u in _uv(key, pts):
		out.append(_area.position + u * _area.size)
	return out


func _at(id: String) -> Vector2:
	return _area.position + Syndicate.uv(id) * _area.size


func _fam_color(id: int) -> Color:
	var f := Game.fam(id)
	return Color(f.get("color", "#777777")).darkened(0.1) if not f.is_empty() else NOBODY


func _layout() -> void:
	var avail := Rect2(Vector2(28, 70), Vector2(size.x - 500.0, size.y - 128.0))
	var aspect := Syndicate.map_aspect()
	var w := minf(avail.size.x, avail.size.y * aspect)
	_frame = Rect2(avail.position + Vector2((avail.size.x - w) * 0.5, 0), Vector2(w, w / aspect))
	var half := Vector2(0.5, 0.5) / _zoom
	_center = _center.clamp(half, Vector2.ONE - half)
	var sz := _frame.size * _zoom
	_area = Rect2(_frame.get_center() - _center * sz, sz)


# ------------------------------------------------------------------ drawing

func _draw() -> void:
	_layout()
	# the desk
	draw_rect(Rect2(Vector2.ZERO, size), DESK)
	# the plate, with its shadow on the desk
	draw_rect(Rect2(_frame.position + Vector2(8, 10), _frame.size), Color(0, 0, 0, 0.45))
	if _plate:
		var src := Rect2((_frame.position - _area.position) / _area.size * Vector2(_plate.get_size()), _frame.size / _area.size * Vector2(_plate.get_size()))
		draw_texture_rect_region(_plate, _frame, src)
	else:
		draw_rect(_frame, Color("d8cba8"))
	var nation: Dictionary = Game.nation
	if not nation.is_empty():
		_draw_overlays(nation)
	# whatever spilled past the plate when zoomed in: back under the desk
	var f := _frame
	draw_rect(Rect2(0, 0, size.x, f.position.y), DESK)
	draw_rect(Rect2(0, f.end.y, size.x, size.y - f.end.y), DESK)
	draw_rect(Rect2(0, f.position.y, f.position.x, f.size.y), DESK)
	draw_rect(Rect2(f.end.x, f.position.y, size.x - f.end.x, f.size.y), DESK)
	draw_rect(Rect2(f.position + Vector2(f.size.x, 10), Vector2(8, f.size.y)), Color(0, 0, 0, 0.45))
	draw_rect(Rect2(f.position + Vector2(8, f.size.y), Vector2(f.size.x, 10)), Color(0, 0, 0, 0.45))
	draw_rect(_frame, Color("3a2a1a"), false, 3.0)
	# title and legend
	Draw.text(self, Vector2(30, 50), "The Country", 34, Color("efe6d2"), _serif)
	Draw.text(self, Vector2(30 + _serif.get_string_size("The Country", HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x + 18, 50), Game.date_text(), 22, Color("b8a888"), _fell)
	_legend()


func _clip(p: Vector2) -> bool:
	return _frame.grow(-4).has_point(p)


func _draw_overlays(nation: Dictionary) -> void:
	var me := int(Game.player(Net.my_id()).get("family", -1))
	var mine_col := _fam_color(me).lightened(0.15)
	# freight rail lines: only yours and the one you picked
	for r in Syndicate.RAILS:
		var sel: bool = _sel.get("id", "") == r["id"]
		var mine := (nation["freight"] as Array).filter(func(o: Dictionary) -> bool: return int(o["fam"]) == me and o["line"] == r["id"])
		if not sel and mine.is_empty():
			continue
		var pl := _clipped(_pts(r["id"], r["path"]))
		if pl.size() < 2:
			continue
		draw_polyline(pl, Color(GOLD, 0.9) if sel else Color(INK, 0.6), 5.0 if sel else 3.0, true)
		for o in mine:
			for k in 3:
				var tt := fmod(_t * 0.06 + k / 3.0, 1.0)
				var q := _along(pl, tt)
				Draw.rect(self, Rect2(q - Vector2(5, 3.5), Vector2(10, 7)), mine_col, true)
	# smuggling routes: dashed oxblood when nobody's bought them, solid in the owner's colour
	for d in Syndicate.ROUTES:
		var r: Dictionary = nation["routes"][d["id"]]
		var pl := _pts(d["id"], d["path"])
		var owner: int = r["owner"]
		var sel: bool = _sel.get("id", "") == d["id"] or _hover.get("id", "") == d["id"]
		var w := 4.5 if sel else 3.0
		if owner >= 0:
			draw_polyline(pl, Color(0.1, 0.07, 0.04, 0.55), w + 2.5, true)
			draw_polyline(pl, _fam_color(owner), w, true)
		else:
			_dashed_poly(pl, Color(OXBLOOD, 0.85), w - 0.5, 9.0)
		if sel:
			draw_polyline(pl, Color(GOLD, 0.35), w + 8.0, true)
		# your convoys moving along it
		if int(r["convoys"].get(str(me), 0)) > 0:
			for k in 3:
				var t := fmod(_t * 0.1 + k / 3.0, 1.0)
				var q := _along(pl, t)
				var dir := (_along(pl, minf(1.0, t + 0.01)) - q).normalized()
				_convoy(q, dir, Syndicate.is_boat(d["id"]), mine_col)
		if int(r["ambush"].get(str(me), 0)) > 0:
			var q2 := _along(pl, 0.5)
			Draw.circle(self, q2, 9, OXBLOOD)
			Draw.text(self, q2 + Vector2(0, 5), "✕", 14, CARD, _cond, HORIZONTAL_ALIGNMENT_CENTER)
	# sources: crates stamped with the place
	var labels := []
	var blocks: Array[Rect2] = []
	for src in Syndicate.SOURCES:
		var p := _at(src["id"])
		if not _clip(p):
			continue
		var sel: bool = _sel.get("id", "") == src["id"]
		var r2 := Rect2(p - Vector2(7, 7), Vector2(14, 14))
		Draw.rect(self, Rect2(r2.position + Vector2(2, 3), r2.size), Color(0, 0, 0, 0.35))
		Draw.rect(self, r2, Color("a0772e"), true)
		draw_rect(r2, INK, false, 1.5)
		draw_line(r2.position, r2.end, INK, 1.0)
		blocks.append(r2.grow(2))
		labels.append([src["name"], p, 8.0, 19 if sel else 16, OXBLOOD if sel else INK_SOFT, 60 if sel else 5, _fell])
	# cities
	for c in Syndicate.CITIES:
		var p := _at(c["id"])
		if not _clip(p):
			continue
		var cs: Dictionary = nation["cities"][c["id"]]
		var big: bool = c["id"] in ["nyc", "chi"]
		var rad := 12.0 if big else 9.0
		var sel: bool = _sel.get("id", "") == c["id"]
		if sel:
			draw_arc(p, rad + 11.0, 0, TAU, 40, OXBLOOD, 3.0, true)
		Draw.circle(self, p + Vector2(2, 3), rad + 5.0, Color(0, 0, 0, 0.3))
		Draw.circle(self, p, rad + 5.0, HALO)
		# the ring: who holds how much of the city
		var start := -PI * 0.5
		if c["id"] == "nyc":
			var total := maxf(1.0, Game.biz.size())
			for f in Game.families:
				var share := Game.shops_of(f["id"]).size() / total
				if share > 0.0:
					draw_arc(p, rad + 2.5, start, start + share * TAU, 24, _fam_color(f["id"]), 5.0, true)
					start += share * TAU
		else:
			for k in cs["influence"]:
				var share2 := float(cs["influence"][k]) / 100.0
				if share2 > 0.01:
					draw_arc(p, rad + 2.5, start, start + share2 * TAU, 24, _fam_color(int(k)), 5.0, true)
					start += share2 * TAU
		draw_arc(p, rad, 0, TAU, 32, INK, 2.0, true)
		var ctrl := Syndicate.controller(nation, c["id"])
		Draw.circle(self, p, rad - 3.0, _fam_color(ctrl) if ctrl >= 0 else Color("efe6d2"))
		if c["id"] == "nyc":
			_star(p, rad - 4.0, INK if ctrl < 0 else HALO)
		var men := Syndicate.men_in(nation, c["id"], me)
		if men > 0:
			Draw.circle(self, p + Vector2(rad + 4, -rad - 2), 9.0, mine_col)
			Draw.text(self, p + Vector2(rad + 4, -rad + 3), str(men), 13, Color.WHITE, _cond, HORIZONTAL_ALIGNMENT_CENTER)
		blocks.append(Rect2(p - Vector2(rad + 6, rad + 6), Vector2(rad * 2 + 12, rad * 2 + 12)))
		labels.append([String(c["name"]).to_upper(), p, rad + 5.0, 22 if sel else (19 if big else 16), OXBLOOD if sel else INK, 100 if sel else 10 + int(c["demand"]) / 10 + (40 if c["id"] == "nyc" else 0), _fell_sc])
	_draw_labels(labels, blocks)


## A little truck or boat glyph, pointing along the route.
func _convoy(p: Vector2, dir: Vector2, boat: bool, col: Color) -> void:
	var a := dir.angle()
	draw_set_transform(p, a, Vector2.ONE)
	if boat:
		var hull := PackedVector2Array([Vector2(-9, -4), Vector2(6, -4), Vector2(11, 0), Vector2(6, 4), Vector2(-9, 4)])
		Draw.poly(self, hull, col)
		draw_polyline(hull + PackedVector2Array([hull[0]]), INK, 1.2, true)
	else:
		Draw.rect(self, Rect2(-8, -4, 11, 8), col, true)
		Draw.rect(self, Rect2(3, -3.5, 5, 7), col.darkened(0.3), true)
		draw_rect(Rect2(-8, -4, 16, 8), INK, false, 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 10:
		var rr := r if k % 2 == 0 else r * 0.45
		var a := -PI * 0.5 + k * PI / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	Draw.poly(self, pts, col)


func _clipped(pl: PackedVector2Array) -> PackedVector2Array:
	return pl


## Names next to their markers where they don't sit on another name or marker: right, left,
## above, below, then the diagonals. The most important places pick first. Ink on a paper halo.
func _draw_labels(labels: Array, blocks: Array[Rect2]) -> void:
	labels.sort_custom(func(a, b) -> bool: return int(a[5]) > int(b[5]))
	var placed: Array[Rect2] = []
	for l in labels:
		var text: String = l[0]
		var p: Vector2 = l[1]
		var r: float = l[2]
		var fs: int = l[3]
		var font: Font = l[6]
		var ts := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var h := ts.y * 0.72
		var cands := [Vector2(r + 4, -h * 0.5), Vector2(-r - 4 - ts.x, -h * 0.5), Vector2(-ts.x * 0.5, -r - 4 - h),
			Vector2(-ts.x * 0.5, r + 4), Vector2(r, -r - h), Vector2(r, r), Vector2(-r - ts.x, -r - h), Vector2(-r - ts.x, r)]
		var best: Vector2 = cands[0]
		var best_hits := 999
		for c in cands:
			var rect := Rect2(p + c, Vector2(ts.x, h))
			var hits := 0
			for o in placed:
				if o.intersects(rect):
					hits += 2
			for o in blocks:
				if o.intersects(rect) and not o.has_point(p):
					hits += 1
			if hits < best_hits:
				best_hits = hits
				best = c
				if hits == 0:
					break
		var at: Vector2 = p + best
		placed.append(Rect2(at, Vector2(ts.x, h)))
		draw_string_outline(font, at + Vector2(0, h), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, HALO)
		draw_string(font, at + Vector2(0, h), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, l[4])


func _legend() -> void:
	var y := size.y - 34.0
	var x := 30.0
	for f in Game.families:
		if not bool(f["alive"]):
			continue
		Draw.circle(self, Vector2(x + 8, y - 6), 8, _fam_color(f["id"]))
		draw_arc(Vector2(x + 8, y - 6), 8, 0, TAU, 20, Color(0, 0, 0, 0.6), 1.5, true)
		Draw.text(self, Vector2(x + 22, y), String(f["name"]), 18, Color("efe6d2"), _cond)
		x += 30.0 + _cond.get_string_size(String(f["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 18.0
	Draw.text(self, Vector2(x + 10, y), "Ring: who holds a city · solid line: a route someone bought · dashed: nobody's yet · click anything · wheel to zoom · J to close",
		16, Color("a89878"), _cond)


# ------------------------------------------------------------------ helpers

func zoom_at(screen: Vector2, f: float) -> void:
	var uv := (screen - _area.position) / _area.size
	_zoom = clampf(_zoom * f, 1.0, 4.0)
	var sz := _frame.size * _zoom
	_center = uv - (screen - _frame.get_center()) / sz
	queue_redraw()


func focus_on(id: String, zoom: float = 2.5) -> void:
	_zoom = zoom
	_center = Syndicate.uv(id)
	queue_redraw()


func _along(pl: PackedVector2Array, t: float) -> Vector2:
	if pl.size() < 2:
		return pl[0] if pl.size() == 1 else Vector2.ZERO
	var total := 0.0
	for k in range(1, pl.size()):
		total += pl[k - 1].distance_to(pl[k])
	var goal := total * clampf(t, 0.0, 1.0)
	for k in range(1, pl.size()):
		var seg := pl[k - 1].distance_to(pl[k])
		if goal <= seg:
			return pl[k - 1].lerp(pl[k], goal / maxf(seg, 0.001))
		goal -= seg
	return pl[pl.size() - 1]


func _dashed_poly(pl: PackedVector2Array, col: Color, w: float, dash: float) -> void:
	var on := true
	var left := dash
	for k in range(1, pl.size()):
		var a := pl[k - 1]
		var b := pl[k]
		var seg := a.distance_to(b)
		var pos := 0.0
		while pos < seg:
			var step := minf(left, seg - pos)
			if on:
				draw_line(a.lerp(b, pos / seg), a.lerp(b, (pos + step) / seg), col, w, true)
			pos += step
			left -= step
			if left <= 0.0:
				on = not on
				left = dash * (0.6 if not on else 1.0)


func _near_poly(m: Vector2, pl: PackedVector2Array) -> float:
	var bd := INF
	for k in range(1, pl.size()):
		bd = minf(bd, Geometry2D.get_closest_point_to_segment(m, pl[k - 1], pl[k]).distance_to(m))
	return bd


func _pick(m: Vector2) -> Dictionary:
	var best := {}
	var bd := 22.0
	for c in Syndicate.CITIES:
		var d := _at(c["id"]).distance_to(m)
		if d < bd:
			bd = d
			best = {"type": "city", "id": c["id"]}
	if best.is_empty():
		bd = 16.0
		for s in Syndicate.SOURCES:
			var d := _at(s["id"]).distance_to(m)
			if d < bd:
				bd = d
				best = {"type": "source", "id": s["id"]}
	if best.is_empty():
		bd = 10.0
		for r in Syndicate.ROUTES:
			var d2 := _near_poly(m, _pts(r["id"], r["path"]))
			if d2 < bd:
				bd = d2
				best = {"type": "route", "id": r["id"]}
		for r in Syndicate.RAILS:
			var d3 := _near_poly(m, _pts(r["id"], r["path"]))
			if d3 < bd:
				bd = d3
				best = {"type": "rail", "id": r["id"]}
	return best


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		if _frame.has_point(e.position):
			zoom_at(e.position, 1.25 if e.button_index == MOUSE_BUTTON_WHEEL_UP else 0.8)
		accept_event()
		return
	if e is InputEventMouseButton and e.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
		_drag = e.pressed
		accept_event()
		return
	if e is InputEventMouseMotion:
		if _drag:
			_center -= e.relative / _area.size
			queue_redraw()
		else:
			_hover = _pick(e.position) if _frame.has_point(e.position) else {}
		accept_event()
		return
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		if not _frame.has_point(e.position):
			return
		var best := _pick(e.position)
		if not best.is_empty():
			_sel = best
			_fill()
			if hud and hud.world and hud.world.audio:
				hud.world.audio.ui("page_turn", -12.0)
		accept_event()


# ------------------------------------------------------------------ the card

func _btn(text: String, sub: String, args: Array, enabled: bool = true) -> void:
	var b := Button.new()
	b.text = text + (("\n" + sub) if sub != "" else "")
	b.disabled = not enabled
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(380, 0)
	b.add_theme_font_override("font", _cond)
	b.add_theme_font_size_override("font_size", 19)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", OXBLOOD)
	b.add_theme_color_override("font_disabled_color", Color(INK_SOFT, 0.55))
	var n := StyleBoxFlat.new()
	n.bg_color = Color("f6eed8")
	n.border_color = CARD_EDGE
	n.set_border_width_all(1)
	n.set_corner_radius_all(2)
	n.set_content_margin_all(9)
	n.content_margin_left = 14
	var h := n.duplicate() as StyleBoxFlat
	h.border_color = OXBLOOD
	h.bg_color = Color("fbf4e2")
	h.border_width_left = 4
	var d := n.duplicate() as StyleBoxFlat
	d.bg_color = Color("e2d6b8")
	for s in ["normal", "focus"]:
		b.add_theme_stylebox_override(s, n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", h)
	b.add_theme_stylebox_override("disabled", d)
	b.pressed.connect(func() -> void: Net.to_host("nation", args))
	_buttons.add_child(b)


func _heading(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", _fell_sc)
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", OXBLOOD)
	_buttons.add_child(l)


func _owner(id: int, me: int) -> String:
	if id < 0:
		return "nobody"
	if id == me:
		return "[b]you[/b]"
	return "the [color=%s]%s[/color] family" % [_fam_color(id).to_html(false), Game.fam(id).get("name", "?")]


func _money(v: int) -> String:
	return "$" + W.money(v)


func _fill() -> void:
	for c in _buttons.get_children():
		c.queue_free()
	var nation: Dictionary = Game.nation
	if nation.is_empty() or _sel.is_empty():
		return
	var me := int(Game.player(Net.my_id()).get("family", -1))
	var f := Game.fam(me)
	match _sel["type"]:
		"city": _fill_city(nation, me, f)
		"route": _fill_route(nation, me, f)
		"rail": _fill_rail(nation, me, f)
		"source": _fill_source(nation, me)


func _title(name: String, note: String) -> String:
	return "[font_size=34][b]%s[/b][/font_size]\n[i][color=#5a4a36]%s[/color][/i]\n" % [name, note]


func _fill_city(nation: Dictionary, me: int, f: Dictionary) -> void:
	var c := Syndicate.city_def(_sel["id"])
	var id: String = c["id"]
	var cs: Dictionary = nation["cities"][id]
	var stash := int(f.get("dirty", 0))
	var bank := int(f.get("clean", 0))
	var t := _title(String(c["name"]).to_upper(), String(c["note"]))
	if id == "nyc":
		t += "\nYou run New York in person, on the street.\n"
		for fm in Game.families:
			if bool(fm["alive"]):
				t += "  [color=%s]%s[/color]: %d shops pay them\n" % [_fam_color(fm["id"]).to_html(false), fm["name"], Game.shops_of(fm["id"]).size()]
	else:
		var ctrl := Syndicate.controller(nation, id)
		t += "\n[b]Runs the city[/b]  %s\n" % (_owner(ctrl, me) if ctrl >= 0 else String(c["outfit"]) + " (the locals)")
		for k in cs["influence"]:
			var capo_id := int(cs["capo"].get(k, -1))
			t += "  %s: %d%%, %d men%s\n" % [_owner(int(k), me), int(cs["influence"][k]), Syndicate.men_in(nation, id, int(k)),
				(", capo " + String(Game.crew_by_id(capo_id).get("name", ""))) if capo_id >= 0 else ""]
		var pol: int = cs["police"]
		t += "[b]Police[/b]  %s\n" % ("paid by " + _owner(pol, me) if pol >= 0 else "not bought")
		t += "[b]Thirst[/b]  %d crates a month\n" % int(c["demand"])
	_info.text = t
	if id != "nyc":
		_heading("Your people")
		var ars: Dictionary = f.get("arsenal", {})
		var guns := int(ars.get("pistol", 0)) + int(ars.get("tommy", 0))
		var capo_c := -1
		for cm in Game.crew_of(me):
			if cm["rank"] == "soldier":
				capo_c = cm["id"]
				break
		if capo_c < 0 and not Game.crew_of(me).is_empty():
			capo_c = Game.crew_of(me)[0]["id"]
		_btn("Send 2 men", "$500 from the Stash, then $90 a month each", ["send", id, 2, 0, -1], stash >= 500)
		_btn("Send 4 men with guns", "$1,000 · takes %d of your guns" % mini(4, guns), ["send", id, 4, mini(4, guns), -1], stash >= 1000)
		if not cs["capo"].has(str(me)) and capo_c >= 0:
			_btn("Make %s your capo here" % Game.crew_by_id(capo_c)["name"], "he takes 2 men · $500 · a capo wins fights for the city", ["send", id, 2, mini(2, guns), capo_c], stash >= 500)
		if Syndicate.men_in(nation, id, me) > 0:
			_btn("Bring your men home", "", ["recall", id])
		var price := 2500 if id == "kc" else 1200
		if int(cs["police"]) != me:
			_btn("Buy the police", "%s · their raids hit the other families" % _money(price), ["police", id], stash >= price)
		for k in cs["men"]:
			var other := int(k)
			if other != me and int(cs["men"][k]) > 0:
				_btn("Order a hit on the %s men here" % Game.fam(other)["name"], "%s · it can go wrong" % _money(Syndicate.HIT_COST), ["hit", id, other], stash >= Syndicate.HIT_COST)
	_heading("Supply")
	if id == "nyc":
		var wh := Game.nyc_warehouse(me)
		_info.text += "\n[b]Your warehouse[/b]  %s\n" % ("%s, %d crates" % [wh["name"], Syndicate.stock(nation, "nyc", me)] if not wh.is_empty() else "none yet: buy one on the West St. quay, in person")
		_info.text += "[b]The docks[/b]  %s: see Red Mulrooney on the quay\n" % _owner(int(cs["docks"]), me)
	else:
		if Syndicate.has_wh(nation, id, me):
			_info.text += "\n[b]Your warehouse[/b]  %d crates, sells up to %d a month\n" % [Syndicate.stock(nation, id, me), Syndicate.sell_cap(nation, id, me)]
		else:
			var wp := Syndicate.warehouse_price(id)
			_btn("Buy a warehouse", "%s from the Bank · without one, booze landing here sells at half price" % _money(wp), ["warehouse", id], bank >= wp)
		if String(c["port"]) != "" and int(cs["docks"]) != me:
			var up := Syndicate.union_price(nation, id, me)
			_btn("Buy the dock union", "%s, then %s a month · your boats land more, rivals' less" % [_money(up), _money(Syndicate.union_wage(id))], ["union", id], stash >= up)
	if String(c["plant"]) != "" and int(cs["plant"]) < 0:
		var pp := Syndicate.plant_price(id)
		_btn("Buy the %s" % c["plant"], "%s from the Bank · %d crates a month of your own" % [_money(pp), Syndicate.PLANT_OUT[c["plant"]]], ["plant", id], bank >= pp)
	elif String(c["plant"]) != "":
		_info.text += "[b]The %s[/b]  %s\n" % [c["plant"], _owner(int(cs["plant"]), me)]
	if bool(c["yard"]) and int(cs["yard"]) != me:
		var yp := Syndicate.yard_price(nation, id, me)
		_btn("Bribe the yardmaster", "%s · your freight through here is never searched" % _money(yp), ["yard", id], stash >= yp)


func _fill_route(nation: Dictionary, me: int, f: Dictionary) -> void:
	var d := Syndicate.route_def(_sel["id"])
	var r: Dictionary = nation["routes"][d["id"]]
	var src := Syndicate.source_def(d["from"])
	var dest := Syndicate.city_def(d["to"])
	var owner: int = r["owner"]
	var cap := Syndicate.route_cap(nation, d["id"], me)
	var stash := int(f.get("dirty", 0))
	var t := _title(String(d["name"]).to_upper(), "%s to %s, by %s · %d miles" % [src["name"], dest["name"], d["mode"], int(Syndicate.miles(d["path"]))])
	t += "\nCarries up to [b]%d[/b] crates a month at %s a crate. About %d in 100 get caught.\n" % [cap, _money(int(src["price"])), int(d["risk"] * 100)]
	t += "[b]Officials[/b]  bought by %s\n" % _owner(owner, me)
	var mine := int(r["convoys"].get(str(me), 0))
	t += "[b]Your convoys[/b]  %s\n" % ("%d crates a month" % mine if mine > 0 else "none")
	if String(r["last"]) != "":
		t += "[i]Last month: %s[/i]\n" % r["last"]
	if d["to"] != "nyc" and not Syndicate.has_wh(nation, d["to"], me):
		t += "[color=#8b1e1a]No warehouse in %s: your crates sell there at half price.[/color]\n" % dest["name"]
	_info.text = t
	_heading("Run booze")
	for n in [20, 50, cap]:
		if n != mine:
			_btn("Run %d crates a month" % n, "", ["convoy", d["id"], n])
	if mine > 0:
		_btn("Stop the convoys", "", ["convoy", d["id"], 0])
	if owner != me:
		var cost := int(d["bribe"]) + (800 if owner >= 0 else 0)
		_btn("Buy the officials", "%s · your convoys pass, everyone else pays a toll" % _money(cost), ["route", d["id"]], stash >= cost)
	var amb := int(r["ambush"].get(str(me), 0))
	if amb == 0:
		_btn("Hijack the other families here", "3 men wait on the road", ["ambush", d["id"], 3])
	else:
		_btn("Call off the hijackers", "", ["ambush", d["id"], 0])


func _fill_rail(nation: Dictionary, me: int, f: Dictionary) -> void:
	var r := Syndicate.rail_def(_sel["id"])
	var stops: Array = r["stops"]
	var t := _title(String(r["name"]).to_upper(), "%s · %d miles" % [" – ".join(stops.map(func(s: String) -> String: return Syndicate.cname(s))), int(Syndicate.miles(r["path"]))])
	t += "\nShips your crates by train between two of your own warehouses, every month.\n"
	for s in stops:
		t += "  %s: %s\n" % [Syndicate.cname(s), ("your warehouse, %d crates" % Syndicate.stock(nation, s, me)) if Syndicate.has_wh(nation, s, me) else "no warehouse of yours"]
	var risk := Syndicate.freight_risk(nation, r["id"], me, float(f.get("heat", 0.0)))
	t += "[b]Risk[/b]  %s\n" % ("none: your yardmaster sees to it" if risk <= 0.0 else "%d in 100 a month" % int(risk * 100))
	_info.text = t
	_heading("Ship")
	var any := false
	for a in stops:
		for b in stops:
			if a == b or not Syndicate.has_wh(nation, a, me) or not Syndicate.has_wh(nation, b, me):
				continue
			any = true
			var cur := 0
			for o in nation["freight"]:
				if int(o["fam"]) == me and o["line"] == r["id"] and o["from"] == a and o["to"] == b:
					cur = int(o["crates"])
			var per := Syndicate.freight_cost(r["id"], a, b)
			if cur > 0:
				_btn("Stop: %s to %s" % [Syndicate.cname(a), Syndicate.cname(b)], "", ["freight", r["id"], a, b, 0])
			for n in [20, 40]:
				if n != cur:
					_btn("%d crates a month, %s to %s" % [n, Syndicate.cname(a), Syndicate.cname(b)], "%s a crate" % _money(per), ["freight", r["id"], a, b, n])
	if not any:
		_info.text += "[i]You need warehouses in two cities on this line first.[/i]\n"
	for s in stops:
		var cd := Syndicate.city_def(s)
		if bool(cd["yard"]) and int(nation["cities"][s]["yard"]) != me:
			var yp := Syndicate.yard_price(nation, s, me)
			_btn("Bribe the yardmaster in %s" % cd["name"], _money(yp), ["yard", s], int(f.get("dirty", 0)) >= yp)


func _fill_source(nation: Dictionary, me: int) -> void:
	var s := Syndicate.source_def(_sel["id"])
	var t := _title(String(s["name"]).to_upper(), String(s["note"]))
	t += "\nLiquor here costs %s a crate.\n" % _money(int(s["price"]))
	_info.text = t
	_heading("Routes from here")
	for d in Syndicate.ROUTES:
		if d["from"] == s["id"]:
			var dd: Dictionary = d
			var mine := int(nation["routes"][d["id"]]["convoys"].get(str(me), 0))
			var b := Button.new()
			b.text = "%s, to %s%s" % [dd["name"], Syndicate.cname(dd["to"]), ("  ·  you run %d a month" % mine) if mine > 0 else ""]
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.add_theme_font_override("font", _cond)
			b.add_theme_color_override("font_color", INK)
			b.flat = true
			b.pressed.connect(func() -> void:
				_sel = {"type": "route", "id": dd["id"]}
				_fill())
			_buttons.add_child(b)
