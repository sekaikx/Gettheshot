class_name GroundSteam
extends Node2D
## Steam rising from a few manholes at night (thicker in the rain): soft puffs that swell, drift
## with the breeze and fade. Only redraws while it's dark and a vent is on screen.

const M := W.M

var vents: Array = []               # px
var night := 0.0
var wet := 0.0
var _t := 0.0
var _on: Array = []


func _process(delta: float) -> void:
	_t += delta
	var had := not _on.is_empty()
	_on.clear()
	if night > 0.2:
		var vp := get_viewport()
		if vp:
			var view := vp.get_canvas_transform().affine_inverse() * Rect2(Vector2.ZERO, vp.get_visible_rect().size)
			view = view.grow(3.0 * M)
			for v in vents:
				if view.has_point(v):
					_on.append(v)
	if had or not _on.is_empty():
		queue_redraw()


func _draw() -> void:
	var k0 := 0
	var strength := clampf((night - 0.2) / 0.5, 0.0, 1.0) * (0.8 + 0.5 * wet)
	for v in _on:
		var p: Vector2 = v
		k0 += 1
		var s := int(p.x * 0.37 + p.y * 1.3)
		for k in 7:
			var life := 3.2 + Draw.hash01(s, k, 1) * 2.0
			var ph := (_t + Draw.hash01(s, k, 2) * life) / life
			var f := ph - floorf(ph)
			var cyc := int(floorf(ph))
			var drift := Vector2(0.55 + Draw.hash01(s + cyc, k, 3) * 0.5, -0.15 + Draw.hash01(s, k + cyc, 4) * 0.3) * f * 1.6 * M
			var r := (0.25 + f * 0.75) * M
			var a := sin(f * PI) * 0.16 * strength
			var c := p + drift
			draw_circle(c, r, Color(0.86, 0.86, 0.9, a * 0.5), true, -1.0, true)
			draw_circle(c + Vector2(-r * 0.15, -r * 0.15), r * 0.65, Color(0.9, 0.9, 0.94, a * 0.7), true, -1.0, true)
