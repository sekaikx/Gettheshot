extends Control
## Top-left, under the money: what to do now. "STEP 3 OF 10", the goal, a line of detail and how
## far it is. When the goal changes to the next one, the old card is ticked and struck through
## (a short flourish), then the new one slides in.

signal completed

const UI := preload("res://scripts/ui/hud/hud_ui.gd")
const W_CARD := 470.0

var world: Node
var _cur := {}
var _next := {}
var _has_next := false
var _phase := ""          # "", "in", "done", "out", "fade"
var _t := 0.0
var _h := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(W_CARD + 20, 120)


func set_goal(obj: Dictionary) -> void:
	if obj.is_empty():
		_has_next = false
		if not _cur.is_empty() and _phase != "fade":
			_phase = "fade"
			_t = 0.0
		return
	if _cur.is_empty() or _phase == "fade":
		_cur = obj.duplicate()
		_phase = "in"
		_t = 0.0
		_has_next = false
	elif String(obj.get("title", "")) != String(_cur.get("title", "")):
		if _phase == "done" or _phase == "out":
			_next = obj.duplicate()
			_has_next = true
		else:
			_next = obj.duplicate()
			_has_next = true
			_phase = "done"
			_t = 0.0
			completed.emit()
	elif _has_next:
		_next = obj.duplicate()
	else:
		# the same goal again (a moving target, a new detail): update quietly
		_cur = obj.duplicate()
	queue_redraw()


func height() -> float:
	return _h if not _cur.is_empty() else 0.0


func _process(delta: float) -> void:
	_t += delta
	match _phase:
		"in":
			if _t >= 0.35:
				_phase = ""
		"done":
			if _t >= 1.05:
				_phase = "out"
				_t = 0.0
		"out":
			if _t >= 0.25:
				_cur = _next if _has_next else {}
				_has_next = false
				_phase = "in" if not _cur.is_empty() else ""
				_t = 0.0
		"fade":
			if _t >= 0.45:
				_cur = {}
				_phase = ""
	if not _cur.is_empty():
		queue_redraw()


## Where the goal is from you: unit vector on the (north-up) screen, or ZERO.
func _dir() -> Vector2:
	var tg: Variant = _cur.get("target", Vector2.INF)
	if not (tg is Vector2) or (tg as Vector2) == Vector2.INF or world == null:
		return Vector2.ZERO
	var la: Variant = world.get("local_actor")
	if not (la is Node2D) or not is_instance_valid(la):
		return Vector2.ZERO
	return ((tg as Vector2) - (la as Node2D).position).normalized()


func _dist_m() -> float:
	var tg: Variant = _cur.get("target", Vector2.INF)
	if not (tg is Vector2) or (tg as Vector2) == Vector2.INF or world == null:
		return -1.0
	var la: Variant = world.get("local_actor")
	if not (la is Node2D) or not is_instance_valid(la):
		return -1.0
	return (la as Node2D).position.distance_to(tg as Vector2) / W.M


func _draw() -> void:
	if _cur.is_empty():
		return
	var a := 1.0
	var dx := 0.0
	match _phase:
		"in":
			var k := clampf(_t / 0.35, 0.0, 1.0)
			a = k
			dx = -30.0 * (1.0 - k) * (1.0 - k)
		"out":
			var k2 := clampf(_t / 0.25, 0.0, 1.0)
			a = 1.0 - k2
			dx = -40.0 * k2
		"fade":
			a = 1.0 - clampf(_t / 0.45, 0.0, 1.0)
	var done := _phase == "done" or _phase == "out"
	var cond := UI.font("cond")
	var semi := UI.font("semi")
	var sans := UI.font("sans")
	var title := String(_cur.get("title", ""))
	var detail := String(_cur.get("detail", ""))
	var step := int(_cur.get("step", 0))
	var of := int(_cur.get("of", 0))
	var head := "STEP %d OF %d" % [step, of] if step > 0 and of > 0 else "YOUR GOAL"
	var x0 := 46.0
	var dm := _dist_m()
	var show_dir := dm >= 0.0 and not done
	var tw := W_CARD - x0 - 14.0 - (64.0 if show_dir else 0.0)
	var lines := UI.wrap(sans, detail, 16, tw, 2) if detail != "" else PackedStringArray()
	var h := 66.0 + lines.size() * 21.0 + (14.0 if show_dir and lines.size() < 2 else 0.0)
	_h = h
	var r := Rect2(Vector2(dx, 0), Vector2(W_CARD, h))
	UI.soft_shadow(self, r, 6.0, a)
	UI.grad_rrect(self, r, 6.0, UI.with_a(Color("241912"), 0.94 * a), UI.with_a(Color("120c09"), 0.94 * a))
	UI.rrect_line(self, r, 6.0, UI.with_a(UI.BRASS_DK, a), 1.5)
	# the gold spine on the left
	var glow := 0.0
	if _phase == "done":
		glow = clampf(1.0 - absf(_t - 0.4) / 0.6, 0.0, 1.0)
	Draw.rrect(self, Rect2(r.position + Vector2(0, 0), Vector2(5, h)), 3.0, UI.with_a(UI.GOLD.lerp(UI.GREEN, glow), a))
	# the checkbox
	var box := Rect2(r.position + Vector2(17, 16), Vector2(18, 18))
	Draw.rrect(self, box, 3.0, UI.with_a(Color(0, 0, 0, 0.5), a))
	UI.rrect_line(self, box, 3.0, UI.with_a(UI.BRASS, a), 1.5)
	if done:
		var k3 := clampf(_t / 0.35, 0.0, 1.0) if _phase == "done" else 1.0
		var p0 := box.position + Vector2(3, 9)
		var p1 := box.position + Vector2(7.5, 14)
		var p2 := box.position + Vector2(18, 0)
		var pts := PackedVector2Array([p0])
		if k3 < 0.4:
			pts.append(p0.lerp(p1, k3 / 0.4))
		else:
			pts.append(p1)
			pts.append(p1.lerp(p2, (k3 - 0.4) / 0.6))
		draw_polyline(pts, UI.with_a(UI.GREEN, a), 3.0, true)
		if glow > 0.0:
			Draw.circle(self, box.get_center(), 14.0 + glow * 10.0, UI.with_a(UI.GREEN, 0.18 * glow * a))
	# header: step, and how far
	var hc := UI.GREEN if done else UI.GOLD
	UI.text(self, r.position + Vector2(x0, 22), "DONE" if done else head, cond, 16, UI.with_a(hc, a))
	if show_dir:
		# a compass disc: the arrow points to the goal, the distance under it
		var c := Vector2(r.end.x - 38, r.position.y + h * 0.5 - 8)
		Draw.circle(self, c, 22.0, UI.with_a(Color(0, 0, 0, 0.45), a))
		var here := dm < 1.5
		if here:
			Draw.circle(self, c, 9.0, UI.with_a(UI.GREEN, a))
		else:
			var d := _dir()
			var n := Vector2(-d.y, d.x)
			var pts := PackedVector2Array([c + d * 16.0, c - d * 9.0 + n * 11.0, c - d * 4.0, c - d * 9.0 - n * 11.0])
			Draw.poly(self, pts, UI.with_a(UI.GOLD2, a))
		var dtxt := "here" if here else "%d m" % int(roundf(dm))
		UI.text_c(self, c.x, c.y + 40.0, dtxt, cond, 16, UI.with_a(UI.INK, a))
	# the goal
	var ttxt := UI.fit(semi, title, 21, tw)
	var tcol := UI.MUTE if done else UI.INK
	UI.text(self, r.position + Vector2(x0, 47), ttxt, semi, 21, UI.with_a(tcol, a))
	if done:
		var k4 := clampf((_t - 0.15) / 0.4, 0.0, 1.0) if _phase == "done" else 1.0
		var ww := UI.tw(semi, ttxt, 21) * k4
		draw_line(r.position + Vector2(x0 - 2, 40), r.position + Vector2(x0 + ww + 2, 37), UI.with_a(UI.GREEN, a), 2.0, true)
	var y := 70.0
	for l in lines:
		UI.text(self, r.position + Vector2(x0, y), l, sans, 16, UI.with_a(Color("d8cdb0"), a))
		y += 21.0
