extends Control
## Don's View (M, or the map table in your club): the city as a planning map on the don's desk.
## A surveyor's sheet in the style of the old fire-insurance maps: blocks and lots, the streets
## named along them, the districts, the river, the quay and its piers. Over it, in ink: every
## business as a trade pictogram in the colour of the family it pays (a crest for the clubs, the
## badge for the precinct, a "!" where a shopkeeper needs a favor), and the people who matter:
## your men, rival crews, cops, you, the rum boat at night.
##
## Hover a business: who runs it, who it pays. Click it: the card on the right, with what you can
## do there (set a waypoint, send a man to take it, guard it, collect). Filters on top, the wheel
## zooms, dragging moves the sheet. Keys: 1-5 filters, Q/E next shop, WASD move, +/- zoom,
## arrows and Enter for the card's buttons. M / Esc (the HUD) close it.
##
## Positions: the plan is in metres (Game.biz door [x, z]); world.actors are in pixels (/ W.M).

const Art := preload("res://scripts/ui/book/art.gd")
const Icons := preload("res://scripts/ui/book/icons.gd")
const Hits := preload("res://scripts/ui/book/hits.gd")

const FILTERS := [["all", "All"], ["mine", "Mine"], ["rivals", "Rivals"], ["free", "Nobody's"], ["favor", "Favors"]]
const L_UI := 0
const L_PANEL := 1
const NOBODY := Color("8a7d66")
const MAP_PAPER := Color("ebe0c4")
const LOT_BRICK := Color("dcbfa8")
const LOT_FREE := Color("e6d8b2")
const YARD := Color("d3d3b2")
const WATER := Color("b7c6c2")
const WATER_INK := Color(0.23, 0.36, 0.4, 0.35)
const QUAY := Color("c7b18a")
const PRECINCT_BLUE := Color("2a3a5a")

var hud: Node
var world: Node

var hits: Hits = Hits.new()
var filter := 0
var sel := -1                 # the business on the card (biz id), -1: the city overview
var mode := ""                # "take" | "guard" | "collect": the card lists your men to pick one
var zoom := 1.0
var center := Vector2.ZERO    # plan metres at the middle of the sheet
var frame := Rect2()          # the sheet on screen
var panel := Rect2()

var _desk: Control
var _clip: Control
var _geo: Control
var _marks: Control
var _ui: Control
var _sig := 0
var _t := 0.0
var _tick := 0.0
var _hover := -1
var _drag := false
var _drag_btn := -1
var _moved := 0.0
var _mouse := Vector2.ZERO
var _press := ""
var _waypoint := Vector2.INF  # plan metres
var _note := ""
var _note_ok := true
var _note_t := 0.0
var _spots: Array = []        # [{id, pos (local px), r}] for picking businesses
var _open_t := 1.0
var _started := false
var _rehover := 0             # the sheet moved under the mouse: find the shop under it again


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	clip_contents = true
	_desk = _layer(self, _draw_desk)
	_clip = Control.new()
	_clip.clip_contents = true
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_clip)
	_geo = _layer(_clip, _draw_geo)
	_marks = _layer(_clip, _draw_marks)
	_ui = _layer(self, _draw_ui)
	resized.connect(_on_resized)
	visibility_changed.connect(func() -> void: set_process(is_visible_in_tree()))
	Game.state_changed.connect(func() -> void:
		if visible:
			refresh())
	Net.event.connect(_on_net_event)
	set_process(visible)
	_on_resized()


func _layer(parent: Control, fn: Callable) -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.focus_mode = Control.FOCUS_NONE
	c.draw.connect(fn)
	parent.add_child(c)
	return c


# ------------------------------------------------------------------ the contract

func open() -> void:
	if world == null and hud != null:
		world = hud.get("world")
	mode = ""
	hits.focus = ""
	hits.keys = false
	if not _started or Game.plan == null:
		_started = Game.plan != null
		_fit()
	_sig = 0
	refresh()
	_open_t = 0.0
	modulate.a = 0.0
	_sound("paper_open", -8.0)


## Re-reads Game; redraws the sheet only when something on it changed.
func refresh() -> void:
	if not is_inside_tree():
		return
	var s := _signature()
	if s != _sig:
		_sig = s
		if sel >= 0 and Game.biz_by_id(sel).is_empty():
			sel = -1
		_geo.queue_redraw()
		_marks.queue_redraw()
		_ui.queue_redraw()


func _signature() -> int:
	var parts: Array = [filter, sel, mode, Game.month, int(Game.clock * 20.0), me(), Game.families.size()]
	for b in Game.biz:
		parts.append([b["protector"], b["owned_by"], b["speak"], b["stock"], b["envelope"], b["closed_until"], b.has("favor")])
	for c in Game.crew:
		if int(c["family"]) == me():
			parts.append([c["id"], c["state"], c["task"], c["target"]])
	for f in Game.families:
		parts.append(f["alive"])
	return hash(parts)


func me() -> int:
	return int(Game.player(Net.my_id()).get("family", -1))


# ------------------------------------------------------------------ layout and the sheet's transform

func _on_resized() -> void:
	var S := size if size.x > 10.0 else Vector2(1600, 900)
	var pw := clampf(S.x * 0.27, 380.0, 440.0)
	panel = Rect2(S.x - pw - 22.0, 70.0, pw, S.y - 94.0)
	frame = Rect2(28.0, 70.0, panel.position.x - 28.0 - 30.0, S.y - 128.0)
	_clip.position = frame.position
	_clip.size = frame.size
	_desk.queue_redraw()
	_geo.queue_redraw()
	_marks.queue_redraw()
	_ui.queue_redraw()


## The part of the plan the sheet shows: the blocks, the quay, the piers, a margin for the
## district names above and below.
func _bounds() -> Rect2:
	var plan: CityPlan = Game.plan
	if plan == null:
		return Rect2(0, 0, 400, 260)
	var x1 := plan.water_x + CityPlan.PIER_LEN + 16.0
	var z1 := CityPlan.NZ * CityPlan.PITCH + 32.0
	return Rect2(-16.0, -32.0, x1 + 16.0, z1 + 32.0)


func _base() -> float:
	var b := _bounds()
	return minf(frame.size.x / b.size.x, frame.size.y / b.size.y)


func _scale() -> float:
	return _base() * zoom


func _fit() -> void:
	zoom = 1.0
	center = _bounds().get_center()


func _clamp_center() -> void:
	var b := _bounds()
	var half := frame.size * 0.5 / _scale()
	var lo := b.position + half
	var hi := b.end - half
	center.x = b.get_center().x if lo.x > hi.x else clampf(center.x, lo.x, hi.x)
	center.y = b.get_center().y if lo.y > hi.y else clampf(center.y, lo.y, hi.y)


## Plan metres -> the sheet's local pixels.
func _l(m: Vector2) -> Vector2:
	return frame.size * 0.5 + (m - center) * _scale()


func _lr(x0: float, z0: float, x1: float, z1: float) -> Rect2:
	var a := _l(Vector2(x0, z0))
	return Rect2(a, Vector2(x1 - x0, z1 - z0) * _scale())


## Screen pixels -> plan metres.
func _m(screen: Vector2) -> Vector2:
	return center + (screen - frame.position - frame.size * 0.5) / _scale()


func zoom_at(screen: Vector2, f: float) -> void:
	var before := _m(screen)
	zoom = clampf(zoom * f, 1.0, 5.0)
	center += before - _m(screen)
	_clamp_center()
	_moved_sheet()


func _moved_sheet() -> void:
	_rehover = 3
	_geo.queue_redraw()
	_marks.queue_redraw()
	_ui.queue_redraw()


func focus_biz(id: int, z: float = -1.0) -> void:
	var b := Game.biz_by_id(id)
	if b.is_empty():
		return
	if z > 0.0:
		zoom = maxf(zoom, z)
	center = _lot_center(b)
	_clamp_center()
	_moved_sheet()


func _lot_center(b: Dictionary) -> Vector2:
	var plan: CityPlan = Game.plan
	var lid := int(b["lot"])
	if plan and lid >= 0 and lid < plan.lots.size():
		var c: Array = plan.lots[lid]["center"]
		return Vector2(float(c[0]), float(c[1]))
	return Vector2(float(b["door"][0]), float(b["door"][1]))


# ------------------------------------------------------------------ who's who

func _owner(b: Dictionary) -> int:
	return int(b["owned_by"]) if int(b["owned_by"]) >= 0 else int(b["protector"])


func _passes(b: Dictionary) -> bool:
	var fid := me()
	var o := _owner(b)
	match String(FILTERS[filter][0]):
		"mine": return o == fid
		"rivals": return o >= 0 and o != fid
		"free": return o < 0 and String(b["kind"]) != "precinct"
		"favor": return b.has("favor")
	return true


func _count(key: String) -> int:
	var fid := me()
	var n := 0
	for b in Game.biz:
		var o := _owner(b)
		match key:
			"all": n += 1
			"mine": n += 1 if o == fid else 0
			"rivals": n += 1 if o >= 0 and o != fid else 0
			"free": n += 1 if o < 0 and String(b["kind"]) != "precinct" else 0
			"favor": n += 1 if b.has("favor") else 0
	return n


func _takeable(b: Dictionary) -> bool:
	return int(b["protector"]) != me() and int(b["owned_by"]) < 0 and String(b["kind"]) not in ["precinct", "club", "warehouse"]


func _mine(b: Dictionary) -> bool:
	return int(b["protector"]) == me() or int(b["owned_by"]) == me()


# ------------------------------------------------------------------ drawing: desk and sheet

func _draw_desk() -> void:
	var ci := _desk
	var S := size
	Art.desk(ci, Rect2(Vector2.ZERO, S), 5)
	# the sheet, pinned down on the desk
	Art.drop_shadow(ci, frame, Vector2(8, 12), 22.0, 0.65)
	Art.paper(ci, frame.grow(10.0), 41, MAP_PAPER)
	ci.draw_rect(frame.grow(4.0), Color(Art.INK, 0.7), false, 2.0)
	ci.draw_rect(frame.grow(7.0), Color(Art.INK, 0.45), false, 1.0)
	for p in [frame.position + Vector2(-4, -4), Vector2(frame.end.x + 4, frame.position.y - 4), frame.end + Vector2(4, 4), Vector2(frame.position.x - 4, frame.end.y + 4)]:
		Draw.circle(ci, p + Vector2(2, 3), 7.0, Color(0, 0, 0, 0.35))
		Draw.circle(ci, p, 7.0, Art.BRASS.darkened(0.1))
		Draw.circle(ci, p - Vector2(2, 2), 2.5, Color(1, 1, 1, 0.4))
	# the card on the right
	Art.drop_shadow(ci, panel, Vector2(6, 10), 16.0, 0.6)
	Art.box(ci, panel, Art.PAPER, Art.CARD_EDGE, 2, 3)


func _draw_geo() -> void:
	var ci := _geo
	var plan: CityPlan = Game.plan
	if plan == null:
		return
	var sc := _scale()
	var b := _bounds()
	# the river
	var wr := _lr(plan.water_x, b.position.y - 50.0, b.end.x + 80.0, b.end.y + 50.0)
	ci.draw_rect(wr, WATER)
	var step := 7.0
	var z := b.position.y - 40.0
	var k := 0
	while z < b.end.y + 40.0:
		var pts := PackedVector2Array()
		var x := plan.water_x + 2.0 + fmod(k * 3.7, 9.0)
		while x < b.end.x + 60.0:
			pts.append(_l(Vector2(x, z + sin(x * 0.35 + k) * 0.6)))
			x += 3.0
			if pts.size() >= 4:
				ci.draw_polyline(pts, WATER_INK, 1.0, true)
				pts = PackedVector2Array()
				x += 5.0 + fmod(k * 1.3 + x, 6.0)
		z += step
		k += 1
	ci.draw_line(_l(Vector2(plan.water_x, b.position.y - 50.0)), _l(Vector2(plan.water_x, b.end.y + 50.0)), Color(0.2, 0.32, 0.36, 0.6), 1.5)
	# the quay and the piers
	var q: Array = plan.quay_rect
	var qr := _lr(float(q[0]), float(q[1]), float(q[2]), float(q[3]))
	ci.draw_rect(qr, QUAY)
	var px := float(q[0]) + 2.0
	while px < float(q[2]):
		ci.draw_line(_l(Vector2(px, float(q[1]))), _l(Vector2(px, float(q[3]))), Color(0.35, 0.25, 0.12, 0.18), 1.0)
		px += 2.0
	ci.draw_rect(qr, Color(Art.INK, 0.5), false, 1.0)
	var pn := 1
	for p in plan.piers:
		var pr := _lr(float(p["x0"]), float(p["z0"]), float(p["x1"]), float(p["z1"]))
		ci.draw_rect(pr, QUAY.darkened(0.06))
		var xx := float(p["x0"]) + 1.5
		while xx < float(p["x1"]):
			ci.draw_line(_l(Vector2(xx, float(p["z0"]))), _l(Vector2(xx, float(p["z1"]))), Color(0.35, 0.25, 0.12, 0.2), 1.0)
			xx += 1.5
		ci.draw_rect(pr, Color(Art.INK, 0.55), false, 1.0)
		var fs := clampi(int(sc * 3.0), 11, 17)
		var pl := "PIER %d" % pn
		var pw := Art.text_w(pl, "fell_sc", fs)
		var pc := pr.get_center() - Vector2(pr.size.x * 0.12, 0)
		ci.draw_rect(Rect2(pc - Vector2(pw * 0.5 + 3, fs * 0.5), Vector2(pw + 6, fs)), QUAY.darkened(0.06))
		Art.text(ci, pc + Vector2(-pw * 0.5, fs * 0.36), pl, "fell_sc", fs, Color(Art.INK, 0.8))
		pn += 1
	# blocks and lots
	var fid := me()
	var biz_of := {}
	for bz in Game.biz:
		biz_of[int(bz["lot"])] = bz
	for blk in plan.blocks:
		var r: Array = blk["rect"]
		var br := _lr(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
		ci.draw_rect(br, Color("e2d5b6"))
		ci.draw_rect(br, Color(Art.INK, 0.35), false, 1.0)
	for lot in plan.lots:
		var lr := W.lot_rect(lot)
		var rr := Rect2(_l(lr.position / W.M), lr.size / W.M * sc)
		var kind := String(lot["kind"])
		var col := LOT_BRICK
		if kind == "courtyard":
			col = YARD
		elif biz_of.has(int(lot["id"])):
			var bz: Dictionary = biz_of[int(lot["id"])]
			var o := _owner(bz)
			if kind == "precinct":
				col = Color("b4bcc6")
			elif o >= 0:
				col = LOT_FREE.lerp(Art.fam_color(o), 0.42 if kind != "club" else 0.6)
			else:
				col = LOT_FREE
			if not _passes(bz):
				col = col.lerp(Color("e2d5b6"), 0.55)
			elif o == fid and filter == 1:
				col = LOT_FREE.lerp(Art.fam_color(o), 0.55)
		ci.draw_rect(rr, col)
		if kind == "courtyard":
			var rng := W.rng(int(lot["id"]))
			for t in 3:
				var tp := rr.position + Vector2(rng.randf_range(0.2, 0.8) * rr.size.x, rng.randf_range(0.2, 0.8) * rr.size.y)
				ci.draw_circle(tp, maxf(1.5, sc * 0.9), Color(0.35, 0.45, 0.3, 0.35))
		ci.draw_rect(rr, Color(Art.INK, 0.4), false, 1.0)
	# the streetcar tracks down the Bowery
	var bx := 2.0 * CityPlan.PITCH
	for off in [-1.2, 1.2]:
		Draw.dashed(ci, _l(Vector2(bx + off, b.position.y + 20.0)), _l(Vector2(bx + off, b.end.y - 20.0)), Color(Art.INK, 0.35), 1.0, 5.0, 3.0)
	var wp2 := CityPlan.PITCH
	var wzb := CityPlan.NZ * wp2
	var ward := Color(Art.OXBLOOD, 0.5)
	_ward(ci, _l(Vector2(2.0 * wp2, -8.0)), _l(Vector2(2.0 * wp2, wzb + 8.0)), ward)
	_ward(ci, _l(Vector2(-8.0, 2.0 * wp2)), _l(Vector2(CityPlan.NX * wp2 + 8.0, 2.0 * wp2)), ward)
	# street names along the streets
	_street_names(ci, plan, sc)
	# the districts: their names in the margins, a ward line between them
	var dfs := clampi(int(sc * 6.0), 18, 40)
	var dcol := Color(Art.OXBLOOD, 0.62)
	var p2 := CityPlan.PITCH
	var zb := CityPlan.NZ * p2
	_spaced(ci, _l(Vector2(p2, -19.0)), "HELL'S KITCHEN", dfs, dcol)
	_spaced(ci, _l(Vector2(p2 * 4.0, -19.0)), "GARMENT DISTRICT", dfs, dcol)
	_spaced(ci, _l(Vector2(p2, zb + 20.0)), "LITTLE ITALY", dfs, dcol)
	_spaced(ci, _l(Vector2(p2 * 4.0, zb + 20.0)), "LOWER EAST SIDE", dfs, dcol)
	var qx := (float(q[0]) + float(q[2])) * 0.5
	ci.draw_set_transform(_l(Vector2(qx, p2 * 2.0)), -PI * 0.5, Vector2.ONE)
	_spaced(ci, Vector2.ZERO, "WATERFRONT", clampi(int(sc * 4.6), 14, 30), dcol)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	ci.draw_set_transform(_l(Vector2(plan.water_x + CityPlan.PIER_LEN + 8.0, p2 * 3.2)), -PI * 0.5, Vector2.ONE)
	_spaced(ci, Vector2.ZERO, "NORTH  RIVER", clampi(int(sc * 5.0), 16, 34), Color(0.16, 0.28, 0.34, 0.62), "fell")
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A ward boundary: dash, dot, dash, the way the old city maps drew them.
func _ward(ci: CanvasItem, a: Vector2, b: Vector2, col: Color) -> void:
	var l := a.distance_to(b)
	var d := (b - a) / maxf(l, 0.001)
	var t := 0.0
	while t < l:
		ci.draw_line(a + d * t, a + d * minf(t + 14.0, l), col, 2.0, true)
		var dot := t + 19.0
		if dot < l:
			ci.draw_circle(a + d * dot, 1.6, col)
		t += 24.0


func _spaced(ci: CanvasItem, c: Vector2, s: String, size: int, col: Color, fname: String = "fell_sc") -> void:
	var t := " ".join(s.split(""))
	Art.text_c(ci, c + Vector2(0, size * 0.35), t, fname, size, col)


func _street_names(ci: CanvasItem, plan: CityPlan, sc: float) -> void:
	var fs := clampi(int(sc * 3.6), 11, 20)
	var col := Color(Art.INK, 0.72)
	var p := CityPlan.PITCH
	for i in CityPlan.NS_STREETS.size():
		var name := String(CityPlan.NS_STREETS[i]).to_upper()
		var w := Art.text_w(name, "fell_sc", fs)
		var x := i * p
		if i == CityPlan.NX:
			x = float(plan.quay_rect[0]) - CityPlan.STREET * 0.5
		for j in CityPlan.NZ:
			var room := (p - CityPlan.STREET) * sc
			if w > room - 8.0:
				if j % 2 == 1:
					continue
			var at := _l(Vector2(x, j * p + p * 0.5))
			ci.draw_set_transform(at, -PI * 0.5, Vector2.ONE)
			ci.draw_rect(Rect2(-w * 0.5 - 4.0, -fs * 0.55, w + 8.0, fs * 1.1), MAP_PAPER)
			Art.text(ci, Vector2(-w * 0.5, fs * 0.36), name, "fell_sc", fs, col)
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for j in CityPlan.EW_STREETS.size():
		var name := String(CityPlan.EW_STREETS[j]).to_upper()
		var w := Art.text_w(name, "fell_sc", fs)
		for i in CityPlan.NX:
			var room := (p - CityPlan.STREET) * sc
			if w > room - 8.0 and i % 2 == 1:
				continue
			var at := _l(Vector2(i * p + p * 0.5, j * p))
			ci.draw_rect(Rect2(at + Vector2(-w * 0.5 - 4.0, -fs * 0.55), Vector2(w + 8.0, fs * 1.1)), MAP_PAPER)
			Art.text(ci, at + Vector2(-w * 0.5, fs * 0.36), name, "fell_sc", fs, col)


# ------------------------------------------------------------------ drawing: pins and people

func _badge_r() -> float:
	return clampf(_scale() * 3.1, 9.0, 17.0)


func _draw_marks() -> void:
	var ci := _marks
	_spots.clear()
	var plan: CityPlan = Game.plan
	if plan == null:
		return
	var fid := me()
	var rb := _badge_r()
	var pulse := 0.5 + 0.5 * sin(_t * 4.0)
	# the waypoint
	var wp := _current_waypoint()
	if wp != Vector2.INF:
		var p := _l(wp)
		Draw.ellipse(ci, p + Vector2(3, 3), Vector2(6, 3), Color(0, 0, 0, 0.3))
		Icons.draw(ci, "pin", p + Vector2(0, -rb * 0.9), rb * 1.8, Art.OXBLOOD, Color("f4ecd6"))
	for b in Game.biz:
		var id := int(b["id"])
		var c := _l(_lot_center(b))
		if c.x < -40 or c.y < -40 or c.x > frame.size.x + 40 or c.y > frame.size.y + 40:
			continue
		var o := _owner(b)
		var kind := String(b["kind"])
		var on := _passes(b)
		var hot := id == _hover or id == sel
		var r := rb * (1.22 if hot else 1.0)
		var fill := Art.ink_of(o) if o >= 0 else NOBODY
		if kind == "precinct":
			fill = PRECINCT_BLUE
		var rim := fill.darkened(0.4)
		if o == fid:
			rim = Art.GOLD
		if not on:
			fill = fill.lerp(MAP_PAPER, 0.72)
			rim = rim.lerp(MAP_PAPER, 0.72)
		if id == sel:
			ci.draw_arc(c, r + 7.0 + pulse * 3.0, 0.0, TAU, 32, Color(Art.OXBLOOD, 0.9), 2.5, true)
		elif id == _hover:
			ci.draw_arc(c, r + 5.0, 0.0, TAU, 28, Color(Art.GOLD, 0.95), 2.0, true)
		if kind == "club" and o >= 0:
			Art.crest(ci, c, r * 2.5, fill if on else fill, Art.initial(o) if r > 10.0 or hot else "", on)
		else:
			var fg := Color("f4ecd6") if on else Color("f4ecd6").lerp(MAP_PAPER, 0.5)
			Icons.badge(ci, kind, c, r, fill, rim, fg, on)
			if o == fid and on:
				ci.draw_arc(c, r + 1.0, 0.0, TAU, 24, Art.GOLD, 1.6, true)
		if b.has("favor") and on:
			var fp := c + Vector2(r * 0.8, -r * 0.95)
			Draw.circle(ci, fp + Vector2(1, 1.5), r * 0.52, Color(0, 0, 0, 0.3))
			Draw.circle(ci, fp, r * 0.52, Art.GOLD_LIGHT)
			ci.draw_arc(fp, r * 0.52, 0.0, TAU, 16, Color("6a4a10"), 1.2, true)
			Icons.draw(ci, "bang", fp, r * 0.62, Color("4a1a10"))
		if bool(b["speak"]) and on and r > 11.0:
			Icons.draw(ci, "bottle", c + Vector2(-r * 0.95, -r * 0.8), r * 0.7, Color("3a2a18"))
		if int(b["closed_until"]) >= Game.month and on:
			Icons.draw(ci, "lock", c + Vector2(-r * 0.9, r * 0.8), r * 0.7, Art.OXBLOOD)
		_spots.append({"id": id, "pos": c, "r": r + 3.0})
	# people
	if world:
		var actors: Dictionary = world.get("actors") if world.get("actors") != null else {}
		var you: Node2D = world.get("local_actor")
		var dr := clampf(_scale() * 1.4, 4.0, 7.0)
		for a in actors.values():
			var n := a as Node2D
			if n == null or not is_instance_valid(n) or n == you or not n.visible or bool(n.get("dead")):
				continue
			var kind := String(n.get("kind"))
			var fam := int(n.get("family"))
			var p := _l(n.position / W.M)
			if p.x < -10 or p.y < -10 or p.x > frame.size.x + 10 or p.y > frame.size.y + 10:
				continue
			match kind:
				"crew":
					var col := Art.fam_color(fam)
					Draw.circle(ci, p + Vector2(1, 1.5), dr + 1.5, Color(0, 0, 0, 0.3))
					Draw.circle(ci, p, dr + 1.5, Color("f4ecd6") if fam == fid else Color("1c140c"))
					Draw.circle(ci, p, dr, col)
				"cop":
					Draw.circle(ci, p + Vector2(1, 1.5), dr + 1.0, Color(0, 0, 0, 0.3))
					Draw.circle(ci, p, dr + 1.0, Color("f4ecd6"))
					Draw.circle(ci, p, dr, PRECINCT_BLUE)
					Draw.circle(ci, p, dr * 0.35, Art.GOLD_LIGHT)
				"fed":
					Draw.circle(ci, p, dr + 1.0, Color("f4ecd6"))
					Draw.circle(ci, p, dr, Color("5a5a5e"))
				"aiboss", "boss":
					Icons.draw(ci, "crown", p + Vector2(1, 1.5), dr * 3.0, Color(0, 0, 0, 0.3))
					Icons.draw(ci, "crown", p, dr * 3.0, Art.fam_color(fam))
		# the rum boat, when it's in
		var boat: Node2D = world.get("boat")
		if boat and is_instance_valid(boat) and boat.visible:
			var bp := _l(boat.position / W.M)
			Icons.draw(ci, "boat", bp + Vector2(2, 3), rb * 2.2, Color(0, 0, 0, 0.3))
			Icons.draw(ci, "boat", bp, rb * 2.2, Color("3a2a18"))
			Art.text_c(ci, bp + Vector2(0, rb * 1.3 + 12.0), "the boat", "fell", clampi(int(rb * 1.1), 13, 18), Color("3a2a18"))
		# you
		if you and is_instance_valid(you):
			var yp := _l(you.position / W.M)
			ci.draw_arc(yp, dr * 2.2 + pulse * 5.0, 0.0, TAU, 28, Color(Art.GOLD, 0.8 - pulse * 0.5), 2.0, true)
			Icons.star(ci, yp + Vector2(1.5, 2), dr * 2.1, Color(0, 0, 0, 0.35))
			Icons.star(ci, yp, dr * 2.1, Color("1c140c"))
			Icons.star(ci, yp, dr * 1.6, Art.GOLD_LIGHT)


func _current_waypoint() -> Vector2:
	if hud:
		var v: Variant = hud.get("_waypoint")
		if v is Vector2:
			var px := v as Vector2
			return px / W.M if px != Vector2.INF else Vector2.INF
	return _waypoint


# ------------------------------------------------------------------ drawing: header, filters, legend, card

func _draw_ui() -> void:
	var ci := _ui
	hits.clear(L_UI)
	hits.clear(L_PANEL)
	var S := size
	var fid := me()
	Art.text(ci, Vector2(30, 52), "Don's View", "serif", 38, Color("efe6d2"))
	Art.text(ci, Vector2(30 + Art.text_w("Don's View", "serif", 38) + 18, 52), "The city · %s" % Game.date_text(), "fell", 22, Color("b8a888"))
	# filters, right-aligned over the sheet
	var x := frame.end.x
	for k in range(FILTERS.size() - 1, -1, -1):
		var f: Array = FILTERS[k]
		var label := "%s  %d" % [f[1], _count(String(f[0]))]
		var w := Art.text_w(label, "cond", 18) + 30.0 + (16.0 if k == 4 else 0.0)
		x -= w
		var r := Rect2(x, 22, w, 34)
		var id := "f_%d" % k
		hits.add(L_UI, id, r, func() -> void: set_filter(k), true, "")
		var hot: bool = hits.hot(id)
		var active := k == filter
		Art.box(ci, r, Art.PAPER if active else (Color("3a2e22") if hot else Color("2a211a")), Art.GOLD if active else Color("0d0906"), 1, 17)
		var tx := r.position.x + 15.0
		if k == 4:
			Draw.circle(ci, Vector2(tx + 6, r.get_center().y), 7.0, Art.GOLD_LIGHT)
			Icons.draw(ci, "bang", Vector2(tx + 6, r.get_center().y), 9.0, Color("4a1a10"))
			tx += 16.0
		Art.text(ci, Vector2(tx, r.position.y + 24), label, "cond", 18, Art.INK if active else (Art.GOLD_LIGHT if hot else Color("e6d8b8")))
		if hits.keys and hits.focus == id:
			ci.draw_rect(r.grow(3.0), Color(Art.GOLD, 0.9), false, 2.0)
		x -= 8.0
	# zoom buttons and the compass, inside the sheet's top-right corner
	var zr := Rect2(frame.end.x - 50, frame.position.y + 12, 38, 34)
	_zbtn(ci, "z_in", zr, "+", func() -> void: zoom_at(frame.get_center(), 1.4))
	_zbtn(ci, "z_out", Rect2(zr.position + Vector2(0, 40), zr.size), "−", func() -> void: zoom_at(frame.get_center(), 1.0 / 1.4))
	_zbtn(ci, "z_fit", Rect2(zr.position + Vector2(0, 80), zr.size), "fit", func() -> void:
		_fit()
		_moved_sheet())
	_compass(ci, Vector2(frame.end.x - 46, frame.end.y - 74))
	_scale_bar(ci, Vector2(frame.end.x - 46, frame.end.y - 18))
	_legend(ci, Vector2(frame.position.x, S.y - 22))
	_panel(ci, fid)
	# the close button, over the card
	var cw := 32.0 + Art.text_w("Close", "cond", 18) + 12.0 + 24.0 + 12.0
	var cr := Rect2(panel.end.x - cw, 18, cw, 40)
	hits.add(L_UI, "close", cr, func() -> void: _close(), true, "")
	var hot2: bool = hits.hot("close")
	Art.box(ci, cr, Color("3a2e22") if hot2 else Color("2a211a"), Color("0d0906"), 1, 5, 4, Vector2(2, 3), 0.4)
	Icons.draw(ci, "x", cr.position + Vector2(18, 20), 13.0, Art.GOLD_LIGHT if hot2 else Color("d8c9a6"))
	Art.text(ci, cr.position + Vector2(32, 27), "Close", "cond", 18, Art.GOLD_LIGHT if hot2 else Color("e6d8b8"))
	Art.keycap(ci, Vector2(cr.end.x - 36, cr.position.y + 28), "M", true, 13)
	# the hover card
	if _hover >= 0 and _hover != sel and frame.has_point(_mouse):
		_hover_card(ci, Game.biz_by_id(_hover))
	if _note != "" and _note_t > 0.0:
		var a := clampf(_note_t, 0.0, 1.0)
		var w2 := minf(Art.text_w(_note, "semi", 17) + 46.0, frame.size.x - 40.0)
		var nr := Rect2(Vector2(frame.get_center().x - w2 * 0.5, frame.end.y - 52), Vector2(w2, 36))
		Art.box(ci, nr, Color(Art.PAPER_LIGHT, a), Color(Art.GREEN_INK if _note_ok else Art.OXBLOOD, a), 1, 3, 6, Vector2(2, 4), 0.4 * a)
		Icons.draw(ci, "check" if _note_ok else "bang", nr.position + Vector2(18, 18), 14.0, Color(Art.GREEN_INK if _note_ok else Art.OXBLOOD, a))
		Art.text(ci, nr.position + Vector2(34, 24), Art.fit(_note, "semi", 17, w2 - 46.0), "semi", 17, Color(Art.INK, a))
	_draw_tip(ci)


func _zbtn(ci: CanvasItem, id: String, r: Rect2, label: String, cb: Callable) -> void:
	hits.add(L_UI, id, r, cb, true, {"z_in": "Zoom in (+ or the wheel)", "z_out": "Zoom out (−)", "z_fit": "The whole city"}.get(id, ""))
	var hot: bool = hits.hot(id)
	Art.box(ci, r, Art.PAPER_LIGHT if not hot else Color("fbf4e2"), Art.OXBLOOD if hot else Color(Art.INK, 0.5), 1, 4, 3, Vector2(1, 2), 0.3)
	Art.text_c(ci, Vector2(r.get_center().x, r.position.y + (25 if label != "fit" else 23)), label, "cond", 22 if label != "fit" else 16, Art.OXBLOOD if hot else Art.INK)
	if hits.keys and hits.focus == id:
		ci.draw_rect(r.grow(3.0), Color(Art.GOLD, 0.9), false, 2.0)


func _compass(ci: CanvasItem, c: Vector2) -> void:
	var r := 26.0
	Draw.circle(ci, c, r + 6.0, Color(MAP_PAPER, 0.85))
	ci.draw_arc(c, r + 4.0, 0.0, TAU, 40, Color(Art.INK, 0.6), 1.0, true)
	ci.draw_arc(c, r - 2.0, 0.0, TAU, 40, Color(Art.INK, 0.3), 1.0, true)
	for k in 4:
		var a := -PI * 0.5 + k * PI * 0.5
		var d := Vector2(cos(a), sin(a))
		var o := d.orthogonal()
		var tip := c + d * r
		Draw.poly(ci, PackedVector2Array([tip, c + o * 5.0, c]), Art.INK if k == 0 else Color(Art.INK, 0.7))
		Draw.poly(ci, PackedVector2Array([tip, c - o * 5.0, c]), Art.OXBLOOD if k == 0 else Color(MAP_PAPER.darkened(0.2)))
	Art.text_c(ci, c + Vector2(0, -r - 8.0), "N", "fell_sc", 16, Art.INK)


## A scale bar, centred on c: a round number of feet that stays about 60-110 px long.
func _scale_bar(ci: CanvasItem, c: Vector2) -> void:
	var feet := 25
	for f in [25, 50, 100, 200, 500]:
		feet = f
		if f * 0.3048 * _scale() >= 60.0:
			break
	var w := feet * 0.3048 * _scale()
	c.x = minf(c.x, frame.end.x - 12.0 - w * 0.5 - 12.0)
	var r := Rect2(c - Vector2(w * 0.5 + 12, 24), Vector2(w + 24, 36))
	Art.box(ci, r, Color(MAP_PAPER, 0.92), Color(Art.INK, 0.4), 1, 2)
	var bx := c.x - w * 0.5
	var by := c.y + 1.0
	for k in 4:
		ci.draw_rect(Rect2(bx + k * w / 4.0, by, w / 4.0, 5), Art.INK if k % 2 == 0 else MAP_PAPER)
	ci.draw_rect(Rect2(bx, by, w, 5), Art.INK, false, 1.0)
	Art.text_c(ci, Vector2(c.x, by - 8.0), "%d feet" % feet, "fell", 14, Art.INK_SOFT)


func _legend(ci: CanvasItem, at: Vector2) -> void:
	var x := at.x
	var y := at.y
	var fid := me()
	var ink := Color("d8c9a6")
	var items := [["you", "You"], ["men", "Your men"], ["rival", "Rival men"], ["cop", "Police"], ["club", "A family's club"], ["favor", "Needs a favor"], ["boat", "The rum boat"]]
	for it in items:
		var c := Vector2(x + 8, y - 6)
		match String(it[0]):
			"you":
				Icons.star(ci, c, 9.0, Art.GOLD_LIGHT)
			"men":
				Draw.circle(ci, c, 6.5, Color("f4ecd6"))
				Draw.circle(ci, c, 5.0, Art.fam_color(fid))
			"rival":
				Draw.circle(ci, c, 6.5, Color("1c140c"))
				Draw.circle(ci, c, 5.0, Color("5a7ab0"))
			"cop":
				Draw.circle(ci, c, 6.0, Color("f4ecd6"))
				Draw.circle(ci, c, 5.0, PRECINCT_BLUE)
				Draw.circle(ci, c, 1.8, Art.GOLD_LIGHT)
			"club":
				Art.crest(ci, c, 17.0, Art.fam_color(fid), "", false)
			"favor":
				Draw.circle(ci, c, 7.0, Art.GOLD_LIGHT)
				Icons.draw(ci, "bang", c, 9.0, Color("4a1a10"))
			"boat":
				Icons.draw(ci, "boat", c, 18.0, ink)
		Art.text(ci, Vector2(x + 22, y), String(it[1]), "cond", 17, ink)
		x += 22.0 + Art.text_w(String(it[1]), "cond", 17) + 20.0
	var hint := "Click a shop  ·  wheel to zoom  ·  drag to move"
	Art.text_r(ci, Vector2(frame.end.x, y), hint, "cond", 17, Color("b8a888"))


func _hover_card(ci: CanvasItem, b: Dictionary) -> void:
	if b.is_empty():
		return
	var lines := _facts(b, true)
	var w := 330.0
	var h := 70.0 + lines.size() * 23.0
	var p := _mouse + Vector2(22, 18)
	if p.x + w > size.x - 10.0:
		p.x = _mouse.x - w - 22.0
	if p.y + h > size.y - 10.0:
		p.y = _mouse.y - h - 18.0
	var r := Rect2(p, Vector2(w, h))
	Art.box(ci, r, Art.PAPER_LIGHT, Art.CARD_EDGE, 1, 3, 10, Vector2(3, 6), 0.45)
	var o := _owner(b)
	ci.draw_rect(Rect2(r.position, Vector2(5, r.size.y)), Art.ink_of(o) if o >= 0 else NOBODY)
	Art.text(ci, r.position + Vector2(18, 30), Art.fit(_title(b), "semi", 20, w - 30.0), "semi", 20, Art.INK)
	Art.text(ci, r.position + Vector2(18, 52), Art.fit("%s · %s" % [Icons.trade_name(String(b["kind"])), b["address"]], "fell", 16, w - 30.0), "fell", 16, Art.INK_SOFT)
	var y := r.position.y + 78.0
	for l in lines:
		var col: Color = l[1]
		Art.text(ci, Vector2(r.position.x + 18, y), Art.fit(String(l[0]), "sans", 16, w - 30.0), "sans", 16, col)
		y += 23.0


func _title(b: Dictionary) -> String:
	if String(b["kind"]) == "club" and int(b.get("hq_of", -1)) >= 0:
		return "The %s Social Club" % Game.fam(int(b["hq_of"])).get("name", "")
	return String(b["name"])


## What you'd want to know about a business, as [text, colour] lines.
func _facts(b: Dictionary, short: bool) -> Array:
	var fid := me()
	var out: Array = []
	var kind := String(b["kind"])
	var rate := int(float(b["rate"]) * Game.econ)
	var owned := int(b["owned_by"])
	var prot := int(b["protector"])
	var hq := int(b.get("hq_of", -1))
	if kind == "precinct":
		out.append(["The police. Mind your step around here.", Art.INK])
		var paid := Game.cops.filter(func(c: Dictionary) -> bool: return int(c["payroll"]) == fid).size()
		if paid > 0:
			out.append(["%d patrolmen are on your payroll." % paid, Art.GREEN_INK])
		return out
	if hq == fid:
		out.append(["Your club: the safe, the desk, the map table.", Art.GREEN_INK])
	elif hq >= 0:
		out.append(["The %s family's club." % Game.fam(hq).get("name", ""), Art.ink_of(hq)])
	elif owned == fid:
		out.append(["Your front: %s a month, clean." % Art.money(int(float(b["legit"]) * Game.econ)), Art.GREEN_INK])
	elif owned >= 0:
		out.append(["The %s family owns it." % Game.fam(owned).get("name", ""), Art.ink_of(owned)])
	elif prot == fid:
		out.append(["Pays you %s a month." % Art.money(rate), Art.GREEN_INK])
	elif prot >= 0:
		out.append(["Pays the %s family %s a month." % [Game.fam(prot).get("name", ""), Art.money(rate)], Art.ink_of(prot)])
	elif kind == "warehouse":
		out.append(["Nobody's. Buy it to store booze off the boat.", Art.INK])
	else:
		out.append(["Pays nobody. It could pay you %s a month." % Art.money(rate), Art.INK])
	if hq < 0 and kind not in ["warehouse"]:
		out.append(["Run by %s." % b["owner_name"], Art.INK_SOFT])
	if bool(b["speak"]):
		out.append(["A speakeasy in the back: %d crates." % int(b["stock"]), Art.INK])
	if prot == fid and owned != fid and int(b["envelope"]) > 0:
		out.append(["An envelope waits for you: %s." % Art.money(int(b["envelope"])), Color("8a6414")])
	if prot == fid and owned != fid and int(b["unpaid"]) > 0:
		out.append(["He didn't pay last month.", Art.OXBLOOD])
	if int(b["closed_until"]) >= Game.month:
		out.append(["Padlocked by the feds until %s." % Game.date_text(int(b["closed_until"]) + 1), Art.OXBLOOD])
	if b.has("favor"):
		var t := Favors.text(b["favor"], b)
		var ft := String(t.get("title", "a favor"))
		out.append(["He needs a favor: %s. %s for you." % [ft.substr(0, 1).to_lower() + ft.substr(1), Art.money(int(b["favor"].get("reward", 0)))], Color("8a5a10")])
	if kind == "poolhall" and not short:
		out.append(["Men looking for work hang around the door.", Art.INK_SOFT])
	return out


func _panel(ci: CanvasItem, fid: int) -> void:
	var r := panel.grow(-22.0)
	var y := r.position.y
	if sel < 0 or Game.biz_by_id(sel).is_empty():
		_overview(ci, r, fid)
		return
	var b := Game.biz_by_id(sel)
	var o := _owner(b)
	var kind := String(b["kind"])
	# back to the city
	var back := Rect2(r.end.x - 34, y - 6, 34, 34)
	_pbtn_icon(ci, "p_back", back, "x", func() -> void: select(-1), "Back to the whole city (Backspace)")
	var fill := Art.ink_of(o) if o >= 0 else NOBODY
	if kind == "precinct":
		fill = PRECINCT_BLUE
	if kind == "club" and o >= 0:
		Art.crest(ci, Vector2(r.position.x + 24, y + 28), 50.0, Art.fam_color(o), Art.initial(o))
	else:
		Icons.badge(ci, kind, Vector2(r.position.x + 24, y + 26), 24.0, fill, fill.darkened(0.4) if o != fid else Art.GOLD)
	var tx := r.position.x + 62.0
	var tw := r.end.x - tx - 40.0
	var th := Art.para(ci, Vector2(tx, y - 2), _title(b), "serif", 26, Art.INK, tw, 30.0, 2)
	y += maxf(th, 30.0) + 4.0
	Art.text(ci, Vector2(tx, y + 16), Art.fit("%s · %s" % [Icons.trade_name(kind), b["address"]], "fell", 17, r.end.x - tx), "fell", 17, Art.INK_SOFT)
	Art.text(ci, Vector2(tx, y + 38), String(b["district"]), "fell", 17, Art.INK_SOFT)
	y += 58.0
	ci.draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(Art.INK_SOFT, 0.4), 1.0)
	y += 12.0
	for l in _facts(b, false):
		var col: Color = l[1]
		y += Art.para(ci, Vector2(r.position.x, y), String(l[0]), "sans", 17, col, r.size.x, 22.0) + 4.0
	y += 10.0
	ci.draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(Art.INK_SOFT, 0.4), 1.0)
	y += 14.0
	Art.text(ci, Vector2(r.position.x, y + 14), "WHAT YOU CAN DO", "fell_sc", 17, Art.OXBLOOD)
	y += 26.0
	var bh := 54.0
	var bid := sel
	_pbtn(ci, "a_way", Rect2(r.position.x, y, r.size.x, bh), "Set waypoint", "An arrow on your screen points the way", "pin",
		func() -> void: _set_waypoint(bid), true, "")
	y += bh + 8.0
	var free := Game.crew_of(fid)
	var no_men := "You have no free men. Hire muscle at a pool hall."
	if _takeable(b):
		var tip := "" if not free.is_empty() else no_men
		_pbtn(ci, "a_take", Rect2(r.position.x, y, r.size.x, bh), "Send a man to take it", "He leans on the owner until he pays you", "fist",
			func() -> void: _set_mode("take"), not free.is_empty(), tip, mode == "take")
		y += bh + 8.0
		if mode == "take":
			y = _men_list(ci, r, y, free, "take", bid)
	if _mine(b) and kind != "precinct":
		var tip2 := "" if not free.is_empty() else no_men
		_pbtn(ci, "a_guard", Rect2(r.position.x, y, r.size.x, bh), "Guard it", "A man stands outside and keeps rivals off", "men",
			func() -> void: _set_mode("guard"), not free.is_empty(), tip2, mode == "guard")
		y += bh + 8.0
		if mode == "guard":
			y = _men_list(ci, r, y, free, "guard", bid)
		if int(b["owned_by"]) != fid or int(b["protector"]) == fid:
			_pbtn(ci, "a_collect", Rect2(r.position.x, y, r.size.x, bh), "Collect here", "A man picks up the envelopes in %s" % b["district"], "envelope",
				func() -> void: _set_mode("collect"), not free.is_empty(), tip2, mode == "collect")
			y += bh + 8.0
			if mode == "collect":
				y = _men_list(ci, r, y, free, "collect", bid)
	if int(b["owned_by"]) >= 0 and int(b["owned_by"]) != fid and kind != "club":
		Art.para(ci, Vector2(r.position.x, y + 4), "The %s family owns it outright. You can't lean on the owner: it's theirs." % Game.fam(int(b["owned_by"])).get("name", ""), "sans", 16, Art.INK_SOFT, r.size.x, 21.0)


func _men_list(ci: CanvasItem, r: Rect2, y: float, men: Array, task: String, bid: int) -> float:
	var row := 50.0
	var room := int((panel.end.y - 24.0 - y) / (row + 4.0))
	var shown := mini(men.size(), maxi(1, room))
	for k in shown:
		var c: Dictionary = men[k]
		var cid := int(c["id"])
		var tr: Dictionary = Rackets.TRAITS.get(String(c.get("trait", "")), {})
		var br := Rect2(r.position.x + 18, y, r.size.x - 18, row)
		var id := "m_%d" % cid
		var good := (task == "take" and String(c.get("trait", "")) in ["talker", "bruiser"]) or (task == "collect" and String(c.get("trait", "")) == "earner")
		hits.add(L_PANEL, id, br, func() -> void: _send(cid, task, bid), true, String(tr.get("does", "")))
		var hot: bool = hits.hot(id)
		Art.button(ci, br, "", "row", hot, true)
		Portrait.draw(ci, Rect2(br.position + Vector2(8, 5), Vector2(40, 40)), "crew", int(c.get("look", cid)), Art.fam_color(me()))
		ci.draw_rect(Rect2(br.position + Vector2(8, 5), Vector2(40, 40)), Color(Art.INK, 0.5), false, 1.0)
		var tx := br.position.x + 58.0
		Art.text(ci, Vector2(tx, br.position.y + 21), Art.fit(String(c["name"]), "semi", 17, br.end.x - tx - 8.0), "semi", 17, Art.OXBLOOD if hot else Art.INK)
		if not tr.is_empty():
			Icons.draw(ci, String(tr["icon"]), Vector2(tx + 8, br.position.y + 36), 14.0, Art.OXBLOOD if good else Art.INK_SOFT, Color("f6eed8"))
			var sub := "%s · %s" % [tr["name"], String(_doing_short(c))]
			if good:
				sub = "%s · %s" % [tr["name"], "good for this"]
			Art.text(ci, Vector2(tx + 20, br.position.y + 41), Art.fit(sub, "sans", 15, br.end.x - tx - 28.0), "sans", 15, Art.OXBLOOD if good else Art.INK_SOFT)
		if hits.keys and hits.focus == id:
			ci.draw_rect(br.grow(2.0), Color(Art.GOLD, 0.9), false, 2.0)
		y += row + 4.0
	if men.size() > shown:
		Art.text(ci, Vector2(r.position.x + 18, y + 14), "and %d more: open the family book (Tab)" % (men.size() - shown), "fell", 15, Art.INK_SOFT)
		y += 22.0
	return y + 6.0


func _doing_short(c: Dictionary) -> String:
	match String(c["task"]):
		"follow": return "with you"
		"guard": return "on guard"
		"collect": return "collecting"
		"booze": return "booze run"
		"idle": return "at the club"
		"take": return "on a job"
	return String(c["task"])


func _overview(ci: CanvasItem, r: Rect2, fid: int) -> void:
	var y := r.position.y
	Art.text(ci, Vector2(r.position.x, y + 26), "Your City", "serif", 30, Art.INK)
	Art.text(ci, Vector2(r.position.x, y + 52), "Who pays whom, on every block.", "fell", 18, Art.INK_SOFT)
	y += 70.0
	ci.draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(Art.INK_SOFT, 0.4), 1.0)
	y += 16.0
	var pay := 0
	for b in Game.shops_of(fid):
		if int(b["owned_by"]) != fid:
			pay += int(float(b["rate"]) * Game.econ)
	var rows := [["mine", "%d pay you" % _count("mine"), "%s a month" % Art.money(pay), Art.fam_color(fid)],
		["rivals", "%d pay other families" % _count("rivals"), "take them from the rivals", Color("5a7ab0")],
		["free", "%d pay nobody" % _count("free"), "yours for the asking", NOBODY],
		["favor", "%d need a favor" % _count("favor"), "the way in without breaking things", Art.GOLD_LIGHT]]
	for k in rows.size():
		var it: Array = rows[k]
		var br := Rect2(r.position.x, y, r.size.x, 50)
		var id := "ov_%d" % k
		hits.add(L_PANEL, id, br, func() -> void: set_filter(k + 1), true, "Show only these on the map (%d)" % (k + 2))
		var hot: bool = hits.hot(id)
		Art.button(ci, br, "", "row", hot, true)
		if String(it[0]) == "favor":
			Draw.circle(ci, br.position + Vector2(24, 25), 12.0, Art.GOLD_LIGHT)
			Icons.draw(ci, "bang", br.position + Vector2(24, 25), 14.0, Color("4a1a10"))
		else:
			Icons.badge(ci, "shop", br.position + Vector2(24, 25), 13.0, it[3], (it[3] as Color).darkened(0.4), Color("f4ecd6"), false)
		Art.text(ci, br.position + Vector2(48, 22), String(it[1]), "semi", 18, Art.OXBLOOD if hot else Art.INK)
		Art.text(ci, br.position + Vector2(48, 41), String(it[2]), "sans", 15, Art.INK_SOFT)
		if hits.keys and hits.focus == id:
			ci.draw_rect(br.grow(2.0), Color(Art.GOLD, 0.9), false, 2.0)
		y += 56.0
	y += 10.0
	Art.text(ci, Vector2(r.position.x, y + 14), "YOUR MEN", "fell_sc", 17, Art.OXBLOOD)
	y += 26.0
	var men := Game.crew_of(fid)
	if men.is_empty():
		Art.para(ci, Vector2(r.position.x, y), "Nobody's on the street for you. Hire muscle at a pool hall.", "sans", 16, Art.INK_SOFT, r.size.x, 21.0)
		y += 44.0
	# the families' colours, under your men, when there's room for both
	var fams: Array = Game.families.filter(func(f: Dictionary) -> bool: return bool(f["alive"]) and int(f["id"]) != fid)
	var fh := 34.0 + ceilf(fams.size() / 2.0) * 28.0
	var show_fams := not fams.is_empty() and y + men.size() * 44.0 + fh <= r.end.y - 50.0
	var room := int((r.end.y - 70.0 - y) / 44.0)
	for k in mini(men.size(), maxi(0, room)):
		var c: Dictionary = men[k]
		var cid := int(c["id"])
		var br := Rect2(r.position.x, y, r.size.x, 40)
		var id := "man_%d" % cid
		hits.add(L_PANEL, id, br, func() -> void: _find_man(cid), true, "Show him on the map")
		var hot: bool = hits.hot(id)
		if hot:
			Art.box(ci, br, Color("fbf4e2"), Art.OXBLOOD, 1, 2)
		Draw.circle(ci, br.position + Vector2(14, 20), 7.0, Color("f4ecd6"))
		Draw.circle(ci, br.position + Vector2(14, 20), 5.5, Art.fam_color(fid))
		Art.text(ci, br.position + Vector2(30, 26), Art.fit(String(c["name"]), "semi", 17, r.size.x * 0.55), "semi", 17, Art.OXBLOOD if hot else Art.INK)
		var ds := _doing_short(c)
		Art.text_r(ci, Vector2(br.end.x - 8, br.position.y + 26), ds.substr(0, 1).to_upper() + ds.substr(1), "sans", 15, Art.INK_SOFT)
		if hits.keys and hits.focus == id:
			ci.draw_rect(br.grow(2.0), Color(Art.GOLD, 0.9), false, 2.0)
		y += 44.0
	if men.size() > room and room >= 0:
		Art.text(ci, Vector2(r.position.x, y + 14), "and %d more (Tab: the family book)" % (men.size() - maxi(0, room)), "fell", 15, Art.INK_SOFT)
	if show_fams:
		y += 8.0
		Art.text(ci, Vector2(r.position.x, y + 14), "THE OTHER FAMILIES", "fell_sc", 17, Art.OXBLOOD)
		y += 26.0
		var colw := floorf(r.size.x * 0.5)
		for k in fams.size():
			var f: Dictionary = fams[k]
			var oid := int(f["id"])
			var at := Vector2(r.position.x + (k % 2) * colw, y + floorf(k / 2.0) * 28.0)
			Art.crest(ci, at + Vector2(10, 12), 22.0, Art.fam_color(oid), "", false)
			Art.text(ci, at + Vector2(28, 19), Art.fit(String(f["name"]), "semi", 16, colw - 70.0), "semi", 16, Art.INK)
			Art.text_r(ci, Vector2(at.x + colw - 14.0, at.y + 19), "%d shops" % Game.shops_of(oid).size(), "sans", 14, Art.INK_SOFT)
	Art.para(ci, Vector2(r.position.x, r.end.y - 44), "Click a shop to see who runs it, and to send your men.", "fell", 17, Art.INK_SOFT, r.size.x, 22.0)


func _pbtn(ci: CanvasItem, id: String, r: Rect2, label: String, sub: String, icon: String, cb: Callable, on: bool = true,
		tip: String = "", open_now: bool = false) -> void:
	hits.add(L_PANEL, id, r, cb, on, tip)
	var hot: bool = hits.hot(id)
	Art.button(ci, r, "", "row", hot or open_now, on)
	var col := Art.OXBLOOD if (hot or open_now) and on else (Art.INK if on else Color(Art.INK_SOFT, 0.55))
	Icons.draw(ci, icon, r.position + Vector2(26, r.size.y * 0.5), 22.0, col, Color("fbf4e2"))
	Art.text(ci, r.position + Vector2(50, 23), label, "cond", 20, col)
	Art.text(ci, r.position + Vector2(50, 43), Art.fit(sub, "sans", 15, r.size.x - 60.0), "sans", 15, Art.INK_SOFT if on else Color(Art.INK_SOFT, 0.5))
	if open_now:
		Icons.draw(ci, "down", Vector2(r.end.x - 20, r.get_center().y), 12.0, Art.OXBLOOD)
	if hits.keys and hits.focus == id:
		ci.draw_rect(r.grow(2.0), Color(Art.GOLD, 0.9), false, 2.0)


func _pbtn_icon(ci: CanvasItem, id: String, r: Rect2, icon: String, cb: Callable, tip: String) -> void:
	hits.add(L_PANEL, id, r, cb, true, tip)
	var hot: bool = hits.hot(id)
	if hot:
		Draw.circle(ci, r.get_center(), r.size.x * 0.5, Color(Art.OXBLOOD, 0.12))
	Icons.draw(ci, icon, r.get_center(), 14.0, Art.OXBLOOD if hot else Art.INK_SOFT)
	if hits.keys and hits.focus == id:
		ci.draw_rect(r.grow(2.0), Color(Art.GOLD, 0.9), false, 2.0)


func _draw_tip(ci: CanvasItem) -> void:
	var id: String = hits.hover if hits.hover != "" else (hits.focus if hits.keys else "")
	if id == "":
		return
	var h: Dictionary = hits.find(id)
	if h.is_empty() or String(h.get("tip", "")) == "":
		return
	var tip := String(h["tip"])
	var br: Rect2 = h["rect"]
	var w := minf(Art.text_w(tip, "sans", 16) + 28.0, 360.0)
	var lines := Art.lines_of(tip, "sans", 16, w - 28.0)
	var th := 16.0 + lines.size() * 21.0
	var x := clampf(br.get_center().x - w * 0.5, 10.0, size.x - w - 10.0)
	var y := br.end.y + 6.0
	if y + th > size.y - 10.0:
		y = br.position.y - th - 6.0
	var r := Rect2(x, y, w, th)
	Art.box(ci, r, Color("2a211a"), Color("0d0906"), 1, 4, 6, Vector2(2, 4), 0.45)
	Art.para(ci, r.position + Vector2(14, 7), tip, "sans", 16, Color("efe4c8"), w - 28.0, 21.0)


# ------------------------------------------------------------------ actions

func select(id: int) -> void:
	sel = id
	mode = ""
	hits.focus = ""
	_marks.queue_redraw()
	_ui.queue_redraw()
	if id >= 0:
		_sound("page_turn", -14.0)


func set_filter(k: int) -> void:
	filter = clampi(k, 0, FILTERS.size() - 1)
	_sig = 0
	refresh()


func _set_mode(m: String) -> void:
	mode = "" if mode == m else m
	_ui.queue_redraw()


func _send(cid: int, task: String, bid: int) -> void:
	Net.to_host("crew_task", [cid, task, bid])
	mode = ""
	_sound("click_wood", -10.0)
	call_deferred("refresh")
	_ui.queue_redraw()


func _set_waypoint(bid: int) -> void:
	var b := Game.biz_by_id(bid)
	if b.is_empty():
		return
	_waypoint = Vector2(float(b["door"][0]), float(b["door"][1]))
	if hud and hud.has_method("set_waypoint"):
		hud.call("set_waypoint", W.door(b))
	_note = "Waypoint set: %s. Follow the arrow." % _title(b)
	_note_ok = true
	_note_t = 4.0
	_sound("tick", -8.0)
	_moved_sheet()


func _find_man(cid: int) -> void:
	if world == null:
		return
	var actors: Variant = world.get("actors")
	if not (actors is Dictionary):
		return
	var a: Node2D = (actors as Dictionary).get("c%d" % cid)
	if a and is_instance_valid(a):
		zoom = maxf(zoom, 2.2)
		center = a.position / W.M
		_clamp_center()
		_moved_sheet()


func _cycle(d: int) -> void:
	var list: Array = []
	for b in Game.biz:
		if _passes(b):
			list.append(b)
	if list.is_empty():
		return
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var pa := _lot_center(a)
		var pb := _lot_center(b)
		var ra := int(pa.y / 24.0)
		var rb := int(pb.y / 24.0)
		return pa.x < pb.x if ra == rb else ra < rb)
	var idx := -1
	for k in list.size():
		if int(list[k]["id"]) == sel:
			idx = k
	idx = wrapi(idx + d, 0, list.size()) if idx >= 0 else (0 if d > 0 else list.size() - 1)
	select(int(list[idx]["id"]))
	focus_biz(sel, 1.8)


func _close() -> void:
	if hud and hud.has_method("toggle_map"):
		hud.call("toggle_map")
	else:
		visible = false


func _sound(name: String, db: float) -> void:
	if world == null and hud != null:
		world = hud.get("world")
	if world and world.get("audio") and world.audio.has_method("ui"):
		world.audio.ui(name, db)


func _on_net_event(n: String, args: Array) -> void:
	if not visible or n != "reply" or args.is_empty() or String(args[0]) == "":
		return
	_note = String(args[0])
	_note_ok = bool(args[1]) if args.size() > 1 else true
	_note_t = 6.0
	_ui.queue_redraw()
	call_deferred("refresh")


func _process(delta: float) -> void:
	_t += delta
	_tick -= delta
	if _open_t < 1.0:
		_open_t = minf(1.0, _open_t + delta * 7.0)
		modulate.a = _open_t
	if _note_t > 0.0:
		_note_t -= delta
		if _note_t < 1.0:
			_ui.queue_redraw()
	# pan with the keyboard
	var pan := Vector2(float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
		float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W)))
	if pan != Vector2.ZERO:
		center += pan.normalized() * delta * 420.0 / _scale()
		_clamp_center()
		_moved_sheet()
	# the sheet moved under a still mouse: the shop under it changed
	if _rehover > 0:
		_rehover -= 1
	if _rehover == 1:
		var nb := _pick(_mouse) if frame.has_point(_mouse) and hits.at(_mouse).is_empty() else -1
		if nb != _hover:
			_hover = nb
			_marks.queue_redraw()
			_ui.queue_redraw()
	# people move: redraw the pins a few times a second (and the pulse on the selection)
	if _tick <= 0.0:
		_tick = 0.1
		_marks.queue_redraw()


# ------------------------------------------------------------------ input

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		var mm := e as InputEventMouseMotion
		_mouse = mm.position
		if _drag_btn >= 0:
			_moved += mm.relative.length()
			if _moved > 4.0:
				_drag = true
			if _drag:
				center -= mm.relative / _scale()
				_clamp_center()
				_moved_sheet()
				return
		_update_hover()
		return
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		_mouse = mb.position
		if mb.pressed and mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			if frame.has_point(mb.position):
				zoom_at(mb.position, 1.2 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.2)
			accept_event()
			return
		if mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			if mb.pressed:
				var h: Dictionary = hits.at(mb.position)
				_press = String(h.get("id", ""))
				if _press == "" and frame.has_point(mb.position):
					_drag_btn = mb.button_index
					_moved = 0.0
					_drag = false
			else:
				if _press != "":
					var h2: Dictionary = hits.at(mb.position)
					if String(h2.get("id", "")) == _press and mb.button_index == MOUSE_BUTTON_LEFT:
						hits.keys = false
						hits.press(_press)
						_ui.queue_redraw()
				elif _drag_btn == MOUSE_BUTTON_LEFT and not _drag and frame.has_point(mb.position):
					var id := _pick(mb.position)
					if id != sel:
						select(id)
				_press = ""
				_drag_btn = -1
				_drag = false
			accept_event()


func _pick(screen: Vector2) -> int:
	var p := screen - frame.position
	var best := -1
	var bd := INF
	for s in _spots:
		var d := (s["pos"] as Vector2).distance_to(p)
		if d <= float(s["r"]) and d < bd:
			bd = d
			best = int(s["id"])
	return best


func _update_hover() -> void:
	var h: Dictionary = hits.at(_mouse)
	var id := String(h.get("id", ""))
	var biz := -1
	if id == "" and frame.has_point(_mouse):
		biz = _pick(_mouse)
	var was_keys: bool = hits.keys
	hits.keys = false
	if id != hits.hover or biz != _hover or was_keys or biz >= 0:
		hits.hover = id
		var changed := biz != _hover
		_hover = biz
		if changed:
			_marks.queue_redraw()
		_ui.queue_redraw()
	var point := (id != "" and bool(h.get("on", true))) or biz >= 0
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if point else (Control.CURSOR_DRAG if _drag else Control.CURSOR_ARROW)


func _input(e: InputEvent) -> void:
	if not is_visible_in_tree() or not (e is InputEventKey) or not e.pressed:
		return
	var k := (e as InputEventKey).keycode
	var used := true
	match k:
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
			set_filter(k - KEY_1)
		KEY_Q, KEY_LEFT:
			_cycle(-1)
		KEY_E, KEY_RIGHT:
			_cycle(1)
		KEY_UP:
			hits.nav(Vector2.UP)
		KEY_DOWN:
			hits.nav(Vector2.DOWN)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			if hits.focus == "":
				hits.nav(Vector2.DOWN)
			else:
				hits.press(hits.focus)
		KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
			zoom_at(frame.get_center(), 1.3)
		KEY_MINUS, KEY_KP_SUBTRACT:
			zoom_at(frame.get_center(), 1.0 / 1.3)
		KEY_BACKSPACE:
			select(-1)
		KEY_W, KEY_A, KEY_S, KEY_D:
			pass
		_:
			used = false
	if used:
		if k not in [KEY_W, KEY_A, KEY_S, KEY_D]:
			hits.keys = true
		_ui.queue_redraw()
		_marks.queue_redraw()
		get_viewport().set_input_as_handled()


# ------------------------------------------------------------------ for the test scene

func test_select() -> void:
	var pick := -1
	for b in Game.biz:
		if b.has("favor"):
			pick = int(b["id"])
			break
	if pick < 0:
		pick = int(Game.biz[10]["id"])
	select(pick)
	mode = "take"
	_hover = int(Game.shops_of(me())[1]["id"]) if Game.shops_of(me()).size() > 1 else -1
	var hb := Game.biz_by_id(_hover)
	if not hb.is_empty():
		_mouse = frame.position + _l(_lot_center(hb))
	_ui.queue_redraw()


func test_zoom() -> void:
	mode = ""
	var hq := Game.biz_by_id(int(Game.fam(me()).get("hq", 0)))
	zoom = 2.6
	center = _lot_center(hq)
	_clamp_center()
	select(int(hq["id"]))
	_moved_sheet()
