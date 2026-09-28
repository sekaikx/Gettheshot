class_name GroundRiver
extends Node2D
## The river's moving surface: slow wave crests drifting downstream, sun (or moon) glints, the
## pier lanterns' light shivering on the water at night, and rain rings when it's wet. Redraws
## every frame, but only the part of the river on screen, with fewer strokes when zoomed out.

const M := W.M

var night := 0.0
var wet := 0.0
var water := Rect2()                # px
var _lanterns: Array = []
var _lamps: Array = []
var _t := 0.0
var _vis := Rect2()


func setup(_layout: GroundLayout, quay: GroundQuay) -> void:
	water = Rect2(quay.water.position * M, quay.water.size * M)
	_lanterns = quay.lanterns
	for h in quay.lamp_heads:
		if (h as Vector2).x > water.position.x - 3.0 * M:
			_lamps.append(h)


func _process(delta: float) -> void:
	_t += delta
	var vp := get_viewport()
	if vp == null:
		return
	var inv := vp.get_canvas_transform().affine_inverse()
	var view := inv * Rect2(Vector2.ZERO, vp.get_visible_rect().size)
	var v := view.intersection(water)
	if v.has_area() or _vis.has_area():
		_vis = v
		queue_redraw()


func _draw() -> void:
	if not _vis.has_area():
		return
	var zoom := get_viewport().get_canvas_transform().get_scale().x
	var lod := clampf(0.7 / maxf(zoom, 0.05), 1.0, 5.0)
	var cell := 1.7 * M * lod
	var ix0 := int(floor(_vis.position.x / cell))
	var iy0 := int(floor(_vis.position.y / cell)) - 1
	var ix1 := int(ceil(_vis.end.x / cell))
	var iy1 := int(ceil(_vis.end.y / cell))
	var crest := Pal.WATER.lightened(0.28).lerp(Color(0.3, 0.38, 0.5), night)
	var trough := Pal.WATER_DEEP.darkened(0.25)
	var glint := Color(0.92, 0.95, 1.0).lerp(Color(0.62, 0.7, 0.92), night)
	var ca := 0.55 * (1.0 - 0.45 * night) * (1.0 - 0.4 * wet)
	var w := maxf(1.2, 1.4 * lod * 0.8)
	for ix in range(ix0, ix1 + 1):
		for iy in range(iy0, iy1 + 1):
			var h1 := Draw.hash01(ix, iy, 71)
			var h2 := Draw.hash01(ix, iy, 72)
			# a crest: born, drifts downstream (south) and fades
			var life := 4.0 + h1 * 3.0
			var ph := (_t + h2 * life) / life
			var cyc := int(floorf(ph))
			var f := ph - float(cyc)
			var hx := Draw.hash01(ix * 7 + cyc, iy, 73)
			var hy := Draw.hash01(ix, iy * 7 + cyc, 74)
			var c := Vector2((float(ix) + hx) * cell, (float(iy) + hy) * cell + f * 0.9 * M)
			if c.x < water.position.x + 0.6 * M:
				continue
			var a := sin(f * PI) * ca
			var l := (0.45 + h1 * 0.6) * M * (1.0 + (lod - 1.0) * 0.5)
			var bend := 0.07 * M
			var pts := PackedVector2Array([c + Vector2(-l, bend), c + Vector2(-l * 0.4, -bend * 0.3), c + Vector2(l * 0.4, -bend * 0.3), c + Vector2(l, bend)])
			draw_polyline(pts, Color(trough, a * 0.6), w + 1.5, true)
			draw_polyline(_up(pts, -1.6), Color(crest, a), w, true)
			# glints: brief sparkles
			if h2 > 0.62:
				var g := pow(maxf(0.0, sin(_t * (1.3 + h1 * 2.1) + h2 * 40.0)), 14.0) * (1.0 - 0.6 * night) * (1.0 - 0.7 * wet)
				if g > 0.02:
					var gc := c + Vector2((h2 - 0.8) * cell, (h1 - 0.5) * cell * 0.6)
					draw_line(gc - Vector2(3.5, 0), gc + Vector2(3.5, 0), Color(glint, g * 0.9), 1.6, true)
					draw_line(gc - Vector2(0, 1.5), gc + Vector2(0, 1.5), Color(glint, g * 0.6), 1.0, true)
	if night > 0.05:
		_reflections()
	if wet > 0.05:
		_rain(lod)


func _up(pts: PackedVector2Array, dy: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in pts:
		out.append(q + Vector2(0, dy))
	return out


## Lamplight on the water: a column of broken, shivering dashes below each light.
func _reflections() -> void:
	var srcs := []
	for l in _lanterns:
		srcs.append([l, 0.9, Color(1.0, 0.72, 0.45)])
	for l in _lamps:
		srcs.append([l, 0.6, Pal.LAMP])
	for sv in srcs:
		var p: Vector2 = sv[0]
		if not _vis.grow(4.0 * M).has_point(p):
			continue
		var strength: float = sv[1]
		var col: Color = sv[2]
		var base := Vector2(maxf(p.x, water.position.x + 0.8 * M), p.y)
		var ps := int(p.y)
		for k in 12:
			var h1 := Draw.hash01(ps, k, 91)
			var h2 := Draw.hash01(ps, k, 92)
			var dy := (0.4 + float(k) * 0.3 + h1 * 0.2) * M
			var wob := sin(_t * (1.6 + h2 * 1.8) + float(k) * 1.9 + h1 * 6.0)
			var jx := wob * 0.22 * M + (h2 - 0.5) * 0.3 * M
			var half := (0.18 + h1 * 0.35) * M * (1.0 - float(k) / 16.0) * (0.75 + 0.25 * sin(_t * 2.7 + h2 * 9.0))
			var a := night * strength * (1.0 - float(k) / 12.0) * (0.35 + 0.35 * h2)
			draw_line(base + Vector2(jx - half, dy), base + Vector2(jx + half, dy + (h1 - 0.5) * 2.0), Color(col, a), 2.2 + h1 * 1.6, true)
		GroundUtil.soft(self, base + Vector2(0, 1.4 * M), Vector2(1.0, 2.4) * M, Color(col, 0.1 * night * strength), 0.0, 3)


## Rain dimpling the water: little rings that open and fade.
func _rain(lod: float) -> void:
	var cell := 1.1 * M * lod
	var ix0 := int(floor(_vis.position.x / cell))
	var iy0 := int(floor(_vis.position.y / cell))
	var ix1 := int(ceil(_vis.end.x / cell))
	var iy1 := int(ceil(_vis.end.y / cell))
	var col := Color(0.75, 0.8, 0.88).lerp(Color(0.5, 0.56, 0.7), night)
	for ix in range(ix0, ix1 + 1):
		for iy in range(iy0, iy1 + 1):
			for n in 2:
				var h := Draw.hash01(ix, iy, 81 + n)
				if h > wet:
					continue
				var life := 0.7 + h * 0.5
				var ph := (_t + Draw.hash01(ix, iy, 83 + n) * life) / life
				var cyc := int(floorf(ph))
				var f := ph - float(cyc)
				var c := Vector2((float(ix) + Draw.hash01(ix * 5 + cyc, iy, 85 + n)) * cell, (float(iy) + Draw.hash01(ix, iy * 5 + cyc, 86 + n)) * cell)
				if not water.has_point(c):
					continue
				var r := (0.04 + f * 0.2) * M
				draw_arc(c, r, 0.0, TAU, 12, Color(col, (1.0 - f) * 0.45 * wet), 1.2, true)
