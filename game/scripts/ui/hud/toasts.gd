extends Control
## Messages, top-right under the date: newest on top, at most five, each with an icon and a colour
## by kind (info good bad warn deal money). They slide in, stay about six seconds and fade.
## The same message twice in a row counts up ("×2") instead of stacking.

const UI := preload("res://scripts/ui/hud/hud_ui.gd")
const W_TOAST := 380.0
const LIFE := 6.0
const FADE := 0.8
const MAX := 5
const LINE := 21.0

var _items: Array = []      # {text, kind, age, lines, y, n}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(W_TOAST, 520)


func push(text: String, kind: String) -> void:
	for it in _items:
		if String(it["text"]) == text and String(it["kind"]) == kind and float(it["age"]) < LIFE:
			it["n"] = int(it["n"]) + 1
			it["age"] = minf(float(it["age"]), 0.3)
			queue_redraw()
			return
	var lines := UI.wrap(UI.font("sans"), text, 17, W_TOAST - 58.0, 4)
	_items.push_front({"text": text, "kind": kind, "age": 0.0, "lines": lines, "y": -30.0, "n": 1})
	var alive := 0
	for it in _items:
		if float(it["age"]) < LIFE:
			alive += 1
			if alive > MAX:
				it["age"] = LIFE
	queue_redraw()


func _h(it: Dictionary) -> float:
	return 20.0 + (it["lines"] as PackedStringArray).size() * LINE


func _process(delta: float) -> void:
	if _items.is_empty():
		return
	var y := 0.0
	for it in _items:
		it["age"] = float(it["age"]) + delta
		it["y"] = lerpf(float(it["y"]), y, clampf(delta * 12.0, 0.0, 1.0))
		# a fading toast keeps its place until it's gone, then the rest slide up
		y += _h(it) + 8.0
	_items = _items.filter(func(it: Dictionary) -> bool: return float(it["age"]) < LIFE + FADE)
	queue_redraw()


func _draw() -> void:
	var sans := UI.font("sans")
	var cond := UI.font("cond")
	for it in _items:
		var age := float(it["age"])
		var a := clampf(age / 0.2, 0.0, 1.0) * clampf(1.0 - (age - LIFE) / FADE, 0.0, 1.0)
		if a <= 0.0:
			continue
		var slide := (1.0 - clampf(age / 0.25, 0.0, 1.0))
		slide = slide * slide * 60.0
		var h := _h(it)
		var r := Rect2(Vector2(slide, float(it["y"])), Vector2(W_TOAST, h))
		var kc := UI.kind_color(String(it["kind"]))
		UI.soft_shadow(self, r, 6.0, a * 0.8)
		UI.grad_rrect(self, r, 6.0, UI.with_a(Color("241912"), 0.93 * a), UI.with_a(Color("140e0a"), 0.93 * a))
		UI.rrect_line(self, r, 6.0, UI.with_a(UI.BRASS_DK, 0.9 * a), 1.0)
		Draw.rrect(self, Rect2(r.position, Vector2(5, h)), 3.0, UI.with_a(kc, a))
		var ic := r.position + Vector2(26, 20)
		Draw.circle(self, ic, 12.0, UI.with_a(kc.darkened(0.55), a))
		UI.icon(self, UI.kind_icon(String(it["kind"])), ic, 15.0, UI.with_a(kc, a), Color(kc.darkened(0.55), a))
		var y := r.position.y + 25.0
		var lines: PackedStringArray = it["lines"]
		for k in lines.size():
			UI.text(self, Vector2(r.position.x + 46, y), lines[k], sans, 17, UI.with_a(UI.INK, a))
			y += LINE
		if int(it["n"]) > 1:
			UI.text_r(self, r.end.x - 10, r.position.y + 18, "×%d" % int(it["n"]), cond, 14, UI.with_a(kc, a))
