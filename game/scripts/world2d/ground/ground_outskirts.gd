class_name GroundOutskirts
extends RefCounted
## The city past the map's edge: plain rows of tar roofs on the far side of the edge streets (so
## Houston, Canal and Mulberry have buildings on both sides). Drawn on the roof layer by
## CityGround, in the same muted style as the real roofs, with their shadows on the sidewalk.

const M := W.M
const SW := CityPlan.SIDEWALK

var lay: GroundLayout
var grain: Texture2D


func _init(layout: GroundLayout) -> void:
	lay = layout
	grain = GroundTex.grain()


func paint(ci: CanvasItem) -> void:
	for b in lay.blocks:
		if b["phantom"]:
			_block(ci, b)


func _block(ci: CanvasItem, b: Dictionary) -> void:
	var r: Rect2 = b["r"]
	var inner := r.grow(-SW)
	var s: int = b["seed"]
	# lots along each side that faces the city (deep enough to fill the block)
	var lots := []
	var depth := 10.0
	# rows along the north and south faces, then the east and west faces between them
	for side: String in ["N", "S"]:
		var z0 := inner.position.y if side == "N" else inner.end.y - depth
		var x := inner.position.x
		var k := 0
		while x < inner.end.x - 0.5:
			k += 1
			var w := GroundUtil.rr(s, k + (0 if side == "N" else 100), 7.0, 11.0)
			if inner.end.x - x - w < 5.0:
				w = inner.end.x - x
			lots.append([Rect2(x, z0, w, depth), GroundUtil.ri(s, 200 + k + (0 if side == "N" else 100), 2, 6), s + k * 7 + (0 if side == "N" else 1000)])
			x += w
	var zmid0 := inner.position.y + depth
	var zmid1 := inner.end.y - depth
	for side: String in ["W", "E"]:
		var x0 := inner.position.x if side == "W" else inner.end.x - depth
		var z := zmid0
		var k := 0
		while z < zmid1 - 0.5:
			k += 1
			var h := GroundUtil.rr(s, 300 + k + (0 if side == "W" else 100), 7.0, 11.0)
			if zmid1 - z - h < 5.0:
				h = zmid1 - z
			lots.append([Rect2(x0, z, depth, h), GroundUtil.ri(s, 400 + k, 2, 6), s + 5000 + k * 7 + (0 if side == "W" else 1000)])
			z += h
	# the middle of the block (backyards, more roofs) is just dark tar
	var core := Rect2(inner.position + Vector2(depth, depth), inner.size - Vector2(depth, depth) * 2.0)
	if core.has_area():
		ci.draw_rect(Rect2(core.position * M, core.size * M), Pal.TAR_3)
	# shadows first, then roofs
	for l in lots:
		var lr := Rect2((l[0] as Rect2).position * M, (l[0] as Rect2).size * M)
		var o := GroundUtil.sh(float(l[1]) * 3.2 * 0.45)
		ci.draw_rect(Rect2(lr.position + o, lr.size), Color(0.02, 0.02, 0.05, 0.3))
	for l in lots:
		_roof(ci, l[0], int(l[1]), int(l[2]))


func _roof(ci: CanvasItem, rm: Rect2, floors: int, s: int) -> void:
	var r := Rect2(rm.position * M, rm.size * M)
	var tar: Color = [Pal.TAR, Pal.TAR_2, Pal.TAR_3, Pal.GRAVEL.darkened(0.2)][GroundUtil.ri(s, 1, 0, 3)]
	tar = tar.lightened(0.02 * float(floors)).darkened(0.08)
	var par := Pal.PARAPET_BRICK if GroundUtil.r01(s, 2) < 0.7 else Pal.PARAPET_STONE.darkened(0.2)
	ci.draw_rect(r, par.darkened(0.15))
	var inner := r.grow(-0.3 * M)
	ci.draw_rect(inner, tar)
	GroundUtil.tex_rect(ci, inner, grain, 1.0, Color(1, 1, 1, 0.5))
	# tar-paper strips
	var horiz := rm.size.x > rm.size.y
	var step := 0.9 * M
	if horiz:
		var y := inner.position.y + step
		while y < inner.end.y:
			ci.draw_line(Vector2(inner.position.x, y), Vector2(inner.end.x, y), Color(0, 0, 0, 0.12), 1.0, true)
			y += step
	else:
		var x := inner.position.x + step
		while x < inner.end.x:
			ci.draw_line(Vector2(x, inner.position.y), Vector2(x, inner.end.y), Color(0, 0, 0, 0.12), 1.0, true)
			x += step
	# parapet light and shade
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, 2.0)), Color(1, 1, 1, 0.14))
	ci.draw_rect(Rect2(r.position, Vector2(2.0, r.size.y)), Color(1, 1, 1, 0.1))
	ci.draw_rect(Rect2(inner.position, Vector2(inner.size.x, 3.0)), Color(0, 0, 0, 0.2))
	ci.draw_rect(Rect2(inner.position, Vector2(3.0, inner.size.y)), Color(0, 0, 0, 0.16))
	# a chimney or two, a hatch, a vent
	var n := GroundUtil.ri(s, 3, 1, 2)
	for k in n:
		var c := inner.position + Vector2(GroundUtil.rr(s, 10 + k, 0.15, 0.85) * inner.size.x, GroundUtil.rr(s, 20 + k, 0.15, 0.85) * inner.size.y)
		var cs := Vector2(0.7, 0.5) * M
		ci.draw_rect(Rect2(c + GroundUtil.sh(1.2) - cs * 0.5, cs), Color(0, 0, 0, 0.28))
		ci.draw_rect(Rect2(c - cs * 0.5, cs), Pal.CHIMNEY)
		ci.draw_rect(Rect2(c - cs * 0.5, Vector2(cs.x, 2.0)), Color(1, 1, 1, 0.15))
		ci.draw_rect(Rect2(c - cs * 0.5 + Vector2(4, 4), cs - Vector2(8, 8)), Color("1a1512"))
	if GroundUtil.r01(s, 30) < 0.6:
		var hc := inner.position + inner.size * Vector2(GroundUtil.rr(s, 31, 0.3, 0.7), GroundUtil.rr(s, 32, 0.3, 0.7))
		var hr := Rect2(hc - Vector2(0.45, 0.45) * M, Vector2(0.9, 0.9) * M)
		ci.draw_rect(hr, Pal.TAR.lightened(0.12))
		ci.draw_rect(hr, Color(0, 0, 0, 0.35), false, 1.5, true)
	if floors >= 5 and GroundUtil.r01(s, 40) < 0.5:
		# a water tower on the taller ones
		var wc := inner.position + inner.size * Vector2(GroundUtil.rr(s, 41, 0.3, 0.7), GroundUtil.rr(s, 42, 0.3, 0.7))
		var wr := 1.3 * M
		ci.draw_circle(wc + GroundUtil.sh(4.0), wr, Color(0, 0, 0, 0.25), true, -1.0, true)
		ci.draw_circle(wc, wr, Pal.WATER_TOWER.darkened(0.25), true, -1.0, true)
		ci.draw_circle(wc, wr - 2.0, Pal.WATER_TOWER, true, -1.0, true)
		var cone := PackedVector2Array()
		for k in 12:
			var a := TAU * float(k) / 12.0
			cone.append(wc + Vector2(cos(a), sin(a)) * wr * 0.75)
		ci.draw_colored_polygon(cone, Pal.WATER_TOWER.darkened(0.1))
		ci.draw_circle(wc + Vector2(-2, -2), 3.0, Pal.WATER_TOWER.lightened(0.25), true, -1.0, true)
