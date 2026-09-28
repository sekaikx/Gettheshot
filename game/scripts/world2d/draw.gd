class_name Draw
extends RefCounted
## Drawing helpers for the procedural 2D art. The Compatibility renderer has no 2D MSAA, so
## filled shapes get an anti-aliased outline in their own colour: use these instead of the bare
## CanvasItem calls wherever an edge is visible (rotated shapes especially).
##
##   Draw.poly(ci, pts, color)                       filled polygon, soft edge
##   Draw.rect(ci, rect, color)                      axis-aligned rectangle, soft edge
##   Draw.rrect(ci, rect, radius, color)             rounded rectangle
##   Draw.circle(ci, center, r, color)               filled circle, soft edge
##   Draw.ellipse(ci, center, radii, color, rot)     filled ellipse
##   Draw.capsule(ci, a, b, r, color)                a stroke with round ends (arms, legs, pipes)
##   Draw.shadow(ci, pts, offset)                    a polygon's drop shadow (down-right)
##   Draw.vgrad(ci, rect, top, bottom)               vertical gradient rectangle
##   Draw.text(ci, pos, text, size, color, font, align, width)   text with an optional outline
##   Draw.dashed(ci, a, b, color, width, dash, gap)

const AA := 1.0


static func poly(ci: CanvasItem, pts: PackedVector2Array, color: Color, aa: bool = true) -> void:
	if pts.size() < 3:
		return
	ci.draw_colored_polygon(pts, color)
	if aa and color.a > 0.02:
		var loop := pts.duplicate()
		loop.append(pts[0])
		ci.draw_polyline(loop, color, AA, true)


static func rect(ci: CanvasItem, r: Rect2, color: Color, aa: bool = false) -> void:
	ci.draw_rect(r, color)
	if aa:
		ci.draw_rect(r, color, false, AA, true)


static func rrect_points(r: Rect2, radius: float, seg: int = 4) -> PackedVector2Array:
	var rad := minf(radius, minf(r.size.x, r.size.y) * 0.5)
	var pts := PackedVector2Array()
	var corners := [r.position + Vector2(r.size.x - rad, rad), r.position + Vector2(r.size.x - rad, r.size.y - rad),
		r.position + Vector2(rad, r.size.y - rad), r.position + Vector2(rad, rad)]
	var start := [-PI * 0.5, 0.0, PI * 0.5, PI]
	for c in 4:
		for s in seg + 1:
			var a: float = start[c] + PI * 0.5 * float(s) / seg
			pts.append(corners[c] + Vector2(cos(a), sin(a)) * rad)
	return pts


static func rrect(ci: CanvasItem, r: Rect2, radius: float, color: Color) -> void:
	poly(ci, rrect_points(r, radius), color)


static func circle(ci: CanvasItem, center: Vector2, r: float, color: Color) -> void:
	ci.draw_circle(center, r, color, true, -1.0, true)


static func ellipse_points(center: Vector2, radii: Vector2, rot: float = 0.0, seg: int = 20) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var t := Transform2D(rot, center)
	for k in seg:
		var a := TAU * float(k) / seg
		pts.append(t * Vector2(cos(a) * radii.x, sin(a) * radii.y))
	return pts


static func ellipse(ci: CanvasItem, center: Vector2, radii: Vector2, color: Color, rot: float = 0.0) -> void:
	poly(ci, ellipse_points(center, radii, rot), color)


static func capsule(ci: CanvasItem, a: Vector2, b: Vector2, r: float, color: Color) -> void:
	ci.draw_line(a, b, color, r * 2.0, true)
	ci.draw_circle(a, r, color, true, -1.0, true)
	ci.draw_circle(b, r, color, true, -1.0, true)


## The shadow of a shape lying on the ground, cast down-right (light from the north-west).
static func shadow(ci: CanvasItem, pts: PackedVector2Array, offset: Vector2 = Vector2(4, 5), color: Color = Pal.SHADOW) -> void:
	var s := PackedVector2Array()
	for q in pts:
		s.append(q + offset)
	poly(ci, s, color, false)


static func vgrad(ci: CanvasItem, r: Rect2, top: Color, bottom: Color) -> void:
	var pts := PackedVector2Array([r.position, r.position + Vector2(r.size.x, 0), r.end, r.position + Vector2(0, r.size.y)])
	ci.draw_polygon(pts, PackedColorArray([top, top, bottom, bottom]))


static func hgrad(ci: CanvasItem, r: Rect2, left: Color, right: Color) -> void:
	var pts := PackedVector2Array([r.position, r.position + Vector2(r.size.x, 0), r.end, r.position + Vector2(0, r.size.y)])
	ci.draw_polygon(pts, PackedColorArray([left, right, right, left]))


## Text anchored at `pos` (baseline-left for LEFT, baseline-centre for CENTER with `width`).
static func text(ci: CanvasItem, pos: Vector2, s: String, size: int, color: Color, font: Font = null,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0,
		outline: int = 0, outline_color: Color = Color(0, 0, 0, 0.85)) -> void:
	var f := font if font else W.font("sans")
	var p := pos
	if align == HORIZONTAL_ALIGNMENT_CENTER and width < 0.0:
		p.x -= f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x * 0.5
		align = HORIZONTAL_ALIGNMENT_LEFT
	if outline > 0:
		ci.draw_string_outline(f, p, s, align, width, size, outline, outline_color)
	ci.draw_string(f, p, s, align, width, size, color)


static func dashed(ci: CanvasItem, a: Vector2, b: Vector2, color: Color, width: float = 2.0, dash: float = 10.0, gap: float = 8.0) -> void:
	var l := a.distance_to(b)
	if l <= 0.01:
		return
	var d := (b - a) / l
	var t := 0.0
	while t < l:
		ci.draw_line(a + d * t, a + d * minf(t + dash, l), color, width, true)
		t += dash + gap


## Deterministic noise in 0..1 for a lattice point (cheap texture variation without textures).
static func hash01(x: int, y: int, s: int = 0) -> float:
	var h := (x * 374761393 + y * 668265263 + s * 144665) & 0x7fffffff
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xffff) / 65535.0
