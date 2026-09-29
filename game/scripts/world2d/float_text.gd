class_name FloatText
extends Node2D
## Little words that float up from the world and fade: "+$90", "Heat +4", "FEAR", "Smash!".
## Lives on the roofs layer so it shows over everything, inside or out.

var _items: Array = []   # [pos, text, color, t, size]


func pop(pos: Vector2, text: String, color: Color = Pal.GOLD2, size: int = 22) -> void:
	_items.append([pos, text, color, 0.0, size])
	queue_redraw()


func _process(delta: float) -> void:
	if _items.is_empty():
		return
	for it in _items:
		it[3] = float(it[3]) + delta
	_items = _items.filter(func(it: Array) -> bool: return float(it[3]) < 1.6)
	queue_redraw()


func _draw() -> void:
	var f := W.font("cond")
	for it in _items:
		var t := float(it[3])
		var a := clampf(1.6 - t, 0.0, 1.0)
		var rise := t * 44.0 + (1.0 - clampf(t * 5.0, 0.0, 1.0)) * 10.0
		var col: Color = it[2]
		var p: Vector2 = (it[0] as Vector2) + Vector2(0, -40.0 - rise)
		var s := int(it[4]) + int(maxf(0.0, 0.25 - t) * 24.0)
		Draw.text(self, p, String(it[1]), s, Color(col, a), f, HORIZONTAL_ALIGNMENT_CENTER, -1, 6, Color(0.05, 0.03, 0.02, a * 0.9))
