extends Control
## Things that float over the street, in screen space: the prompt bubble ("[E] Talk to Izzy") over
## what you'd use, the little bars over people (the FEAR meter over a shop owner, with the mark where
## he pays), the bobbing marker over your goal, and an arrow at the screen edge when the goal or the
## waypoint is off screen. Meters always sit above the prompt, so they never cover each other.

const UI := preload("res://scripts/ui/hud/hud_ui.gd")
const EDGE := 58.0

var world: Node
var hidden_prompt := false        # a conversation or a panel is open
var prompt_text := ""
var prompt_key := "E"
var prompt_pos := Vector2.INF
var meters := {}                  # id -> {pos, v, mark, label, color}
var target := Vector2.INF         # the goal
var waypoint := Vector2.INF
var avoid: Array[Rect2] = []      # HUD panels the edge arrows keep clear of

var _pa := 0.0                    # prompt alpha
var _shown_text := ""
var _shown_key := "E"
var _pscreen := Vector2.ZERO
var _pscreen_ok := false
var _mv := {}                     # id -> displayed value
var _mflip := {}                  # id -> drawn under the person
var _pflip := false
var hidden_meters := false        # a panel or a conversation is open
var hidden_goals := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _ct() -> Transform2D:
	if world == null or not is_instance_valid(world) or not world.is_inside_tree():
		return Transform2D.IDENTITY
	return world.get_viewport().get_canvas_transform()


func _process(delta: float) -> void:
	var want := prompt_text != "" and not hidden_prompt
	if want:
		_shown_text = prompt_text
		_shown_key = prompt_key
	_pa = move_toward(_pa, 1.0 if want else 0.0, delta * (7.0 if want else 9.0))
	for id in meters:
		var m: Dictionary = meters[id]
		_mv[id] = lerpf(float(_mv.get(id, m["v"])), float(m["v"]), clampf(delta * 8.0, 0.0, 1.0))
	for id in _mv.keys():
		if not meters.has(id):
			_mv.erase(id)
	queue_redraw()


func _zoom(ct: Transform2D) -> float:
	return ct.get_scale().x


func _draw() -> void:
	var ct := _ct()
	var z := _zoom(ct)
	var area := size
	var lift := 18.0 * z + 10.0
	var me := _local_pos()
	var me_s := ct * me if me != Vector2.INF else Vector2.INF
	_pscreen_ok = false
	# where the prompt is (the marker and the meters make room for it); it flips under the thing
	# when you stand right above it, so it never covers you
	var docked := prompt_pos == Vector2.INF
	if _pa > 0.01 and _shown_text != "":
		if not docked:
			var sp := ct * prompt_pos
			_pflip = _flip(sp, me_s, lift, _pflip)
			_pscreen = sp + Vector2(0, lift if _pflip else -lift)
		else:
			_pscreen = Vector2(area.x * 0.5, area.y - 150.0)
		_pscreen_ok = true
	if not hidden_goals:
		_draw_goal(ct, z, target, false)
		_draw_goal(ct, z, waypoint, true)
	if not hidden_meters:
		for id in meters:
			var m: Dictionary = meters[id]
			var sp2: Vector2 = ct * (m["pos"] as Vector2)
			var fl := _flip(sp2, me_s, lift, bool(_mflip.get(id, false)))
			_mflip[id] = fl
			var c := Vector2(sp2.x, sp2.y + (lift + 70.0 if fl else -lift - 70.0))
			_meter(c, float(_mv.get(id, m["v"])), float(m["mark"]), String(m["label"]), m["color"])
	if _pscreen_ok:
		_prompt(_pscreen, _shown_text, _shown_key, _pa, docked, _pflip and not docked)


## Should the marks over the thing at `sp` go under it instead (you're standing just above it)?
## Hysteresis keeps it from flickering at the edge.
func _flip(sp: Vector2, me_s: Vector2, lift: float, was: bool) -> bool:
	if me_s == Vector2.INF:
		return false
	var m := 14.0 if was else 0.0
	return absf(me_s.x - sp.x) < 110.0 + m and me_s.y < sp.y - 8.0 + m and me_s.y > sp.y - lift - 120.0 - m


# ------------------------------------------------------------------ the prompt bubble

func _prompt(tip: Vector2, text: String, key: String, a: float, docked: bool, below: bool) -> void:
	var semi := UI.font("semi")
	var fs := 18
	var h := 36.0
	var kw := UI.keycap_w(key, 24.0) if key != "" else 0.0
	var tw := UI.tw(semi, text, fs)
	var maxw := minf(size.x - 40.0, 620.0)
	if tw > maxw - kw - 30.0:
		text = UI.fit(semi, text, fs, maxw - kw - 30.0)
		tw = UI.tw(semi, text, fs)
	var w := (kw + 10.0 if key != "" else 0.0) + tw + 26.0
	var rise := (1.0 - a) * 8.0
	var top := tip.y - 9.0 - h + rise
	if below:
		top = tip.y + 9.0 - rise
	if docked:
		top = tip.y - h * 0.5 + rise
	var left := clampf(tip.x - w * 0.5, 12.0, size.x - 12.0 - w)
	top = clampf(top, 12.0, size.y - h - 12.0)
	var r := Rect2(Vector2(left, top), Vector2(w, h))
	UI.soft_shadow(self, r, 9.0, a * 0.9, Vector2(2, 4))
	UI.grad_rrect(self, r, 9.0, UI.with_a(Color("2a1d15"), 0.95 * a), UI.with_a(Color("150e0a"), 0.95 * a))
	UI.rrect_line(self, r, 9.0, UI.with_a(UI.BRASS, 0.8 * a), 1.5)
	if not docked:
		var ax := clampf(tip.x, r.position.x + 14.0, r.end.x - 14.0)
		var tri := PackedVector2Array([Vector2(ax - 8, r.end.y - 1), Vector2(ax + 8, r.end.y - 1), Vector2(ax, r.end.y + 8)])
		if below:
			tri = PackedVector2Array([Vector2(ax - 8, r.position.y + 1), Vector2(ax + 8, r.position.y + 1), Vector2(ax, r.position.y - 8)])
		Draw.poly(self, tri, UI.with_a(Color("150e0a"), 0.95 * a))
		draw_polyline(PackedVector2Array([tri[0], tri[2], tri[1]]), UI.with_a(UI.BRASS, 0.8 * a), 1.5, true)
	var x := r.position.x + 13.0
	if key != "":
		UI.keycap(self, Rect2(Vector2(r.position.x + 7, r.position.y + 6), Vector2(24, 24)), key, a)
		x = r.position.x + 7 + kw + 10.0
	UI.text(self, Vector2(x, UI.mid(semi, fs, r.get_center().y)), text, semi, fs, UI.with_a(UI.INK, a))


# ------------------------------------------------------------------ meters over people

func _meter(c: Vector2, v: float, mark: float, label: String, col: Color) -> void:
	var w := 140.0
	var r := Rect2(Vector2(c.x - w * 0.5, c.y - 20.0), Vector2(w, 40))
	r.position.x = clampf(r.position.x, 8.0, size.x - w - 8.0)
	r.position.y = clampf(r.position.y, 8.0, size.y - 48.0)
	var over := mark >= 0.0 and v >= mark
	UI.soft_shadow(self, r, 6.0, 0.8, Vector2(2, 3))
	UI.grad_rrect(self, r, 6.0, Color("241912", 0.94), Color("120c09", 0.94))
	UI.rrect_line(self, r, 6.0, UI.GREEN.darkened(0.2) if over else UI.BRASS_DK, 1.5)
	var cond := UI.font("cond")
	UI.text(self, r.position + Vector2(9, 15), label, cond, 13, UI.INK)
	var vt := "HE'LL PAY" if over else "%d%%" % int(roundf(clampf(v, 0.0, 1.0) * 100.0))
	UI.text_r(self, r.end.x - 9, r.position.y + 15, vt, cond, 13, UI.GREEN if over else col.lightened(0.3))
	var bar := Rect2(r.position + Vector2(9, 21), Vector2(w - 18, 9))
	Draw.rrect(self, bar.grow(1.0), 3.0, Color(0, 0, 0, 0.7))
	var fw := bar.size.x * clampf(v, 0.0, 1.0)
	if fw > 1.0:
		UI.grad_rrect(self, Rect2(bar.position, Vector2(fw, bar.size.y)), 2.5, col.lightened(0.2), col.darkened(0.25))
	if mark >= 0.0:
		var mx := bar.position.x + bar.size.x * clampf(mark, 0.0, 1.0)
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 150.0) if over else 0.0
		var mc := UI.GOLD2.lerp(Color.WHITE, pulse)
		draw_line(Vector2(mx, bar.position.y - 2), Vector2(mx, bar.end.y + 2), mc, 2.0, true)
		Draw.poly(self, PackedVector2Array([Vector2(mx - 4, bar.end.y + 7), Vector2(mx + 4, bar.end.y + 7), Vector2(mx, bar.end.y + 2)]), mc)


# ------------------------------------------------------------------ the goal and the waypoint

func _local_pos() -> Vector2:
	if world == null:
		return Vector2.INF
	var la: Variant = world.get("local_actor")
	if la is Node2D and is_instance_valid(la):
		return (la as Node2D).position
	return Vector2.INF


func _draw_goal(ct: Transform2D, z: float, tg: Vector2, is_wp: bool) -> void:
	if tg == Vector2.INF:
		return
	var me := _local_pos()
	if me != Vector2.INF and me.distance_to(tg) < 1.4 * W.M:
		return
	var col := UI.CREAM if is_wp else UI.GOLD2
	var sp := ct * tg
	var inner := Rect2(Vector2(EDGE, EDGE), size - Vector2(EDGE, EDGE) * 2.0)
	var t := Time.get_ticks_msec() / 1000.0
	if inner.has_point(sp):
		# a ring on the ground and a bobbing chevron over it
		var pr := 0.5 + 0.5 * sin(t * 3.0)
		var rr := (16.0 + 5.0 * pr) * maxf(z, 0.5)
		draw_arc(sp, rr, 0, TAU, 40, UI.with_a(col, 0.55 - 0.25 * pr), 2.0, true)
		draw_arc(sp, rr * 0.55, 0, TAU, 28, UI.with_a(col, 0.35), 1.5, true)
		var head := sp + Vector2(0, -(18.0 * z + 10.0) - 30.0 + sin(t * 4.0) * 5.0)
		if _pscreen_ok and _pscreen.distance_to(head) < 70.0:
			return
		_chevron(head, col, is_wp)
		return
	# off screen: an arrow at the edge, pointing at it
	var c := size * 0.5
	var d := (sp - c)
	if d.length() < 1.0:
		return
	d = d.normalized()
	var half := inner.size * 0.5
	var k := minf(half.x / maxf(absf(d.x), 0.0001), half.y / maxf(absf(d.y), 0.0001))
	var p := c + d * k
	p = _clear_of_panels(p, inner)
	var dist := me.distance_to(tg) / W.M if me != Vector2.INF else -1.0
	_edge_arrow(p, d, col, dist, is_wp)


func _clear_of_panels(p: Vector2, inner: Rect2) -> Vector2:
	for r0 in avoid:
		var r := r0.grow(26.0)
		if not r.has_point(p):
			continue
		var on_side := absf(p.x - inner.position.x) < 1.0 or absf(p.x - inner.end.x) < 1.0
		if on_side:
			var below := r.end.y
			var above := r.position.y
			p.y = below if (below <= inner.end.y and (absf(below - p.y) < absf(p.y - above) or above < inner.position.y)) else above
		else:
			var right := r.end.x
			var left := r.position.x
			p.x = right if (right <= inner.end.x and (absf(right - p.x) < absf(p.x - left) or left < inner.position.x)) else left
	return p


func _chevron(at: Vector2, col: Color, is_wp: bool) -> void:
	Draw.circle(self, at + Vector2(2, 3), 15.0, Color(0, 0, 0, 0.35))
	Draw.circle(self, at, 15.0, Color("150e0a", 0.92))
	draw_arc(at, 15.0, 0, TAU, 32, col, 2.0, true)
	if is_wp:
		UI.icon(self, "flag", at, 17.0, col)
	else:
		Draw.poly(self, PackedVector2Array([at + Vector2(-7, -4), at + Vector2(7, -4), at + Vector2(0, 6)]), col)
	Draw.poly(self, PackedVector2Array([at + Vector2(-6, 14), at + Vector2(6, 14), at + Vector2(0, 23)]), col)


func _edge_arrow(p: Vector2, d: Vector2, col: Color, dist: float, is_wp: bool) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	p += d * sin(t * 4.0) * 3.0
	var tip := p + d * 36.0
	var side := d.orthogonal() * 9.0
	Draw.poly(self, PackedVector2Array([tip, p + d * 22.0 + side, p + d * 22.0 - side]), Color(0, 0, 0, 0.35))
	Draw.poly(self, PackedVector2Array([tip, p + d * 20.0 + side, p + d * 20.0 - side]), col)
	Draw.circle(self, p + Vector2(2, 3), 22.0, Color(0, 0, 0, 0.35))
	Draw.circle(self, p, 22.0, Color("150e0a", 0.92))
	draw_arc(p, 22.0, 0, TAU, 40, col, 2.0, true)
	var cond := UI.font("cond")
	if is_wp:
		UI.icon(self, "flag", p + Vector2(0, -6), 13.0, col)
	else:
		UI.icon(self, "star", p + Vector2(0, -6), 13.0, col)
	if dist >= 0.0:
		UI.text_c(self, p.x, p.y + 13.0, "%d m" % int(roundf(dist)), cond, 13, UI.INK)
