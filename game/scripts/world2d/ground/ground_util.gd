class_name GroundUtil
extends RefCounted
## Small drawing helpers shared by the ground painters (CityGround and scripts/world2d/ground/*).
## Positions are in pixels unless a name says metres. Light comes from the north-west.

const SV := Vector2(0.22, 0.28)          # shadow offset on the ground per metre of height
const SH := Color(0.03, 0.03, 0.07, 0.24) # prop shadow (drawn twice: soft rim + core)
const LIGHT_DIR := Vector2(-0.7071, -0.7071)  # toward the light


## Shadow offset in pixels for something `h_m` metres tall.
static func sh(h_m: float) -> Vector2:
	return SV * h_m * W.M


## Deterministic 0..1 from a seed and an index.
static func r01(s: int, k: int) -> float:
	return Draw.hash01(s, k, 911)


static func rr(s: int, k: int, a: float, b: float) -> float:
	return lerpf(a, b, Draw.hash01(s, k, 911))


static func ri(s: int, k: int, a: int, b: int) -> int:
	if b <= a:
		return a
	return mini(b, a + int(Draw.hash01(s, k, 911) * float(b - a + 1)))


static func hseed(a: int, b: int = 0, c: int = 0) -> int:
	return int(Draw.hash01(a, b, c) * 65535.0) * 7919 + a * 31 + b * 17 + c


## How much a surface whose outward (horizontal) normal is `n` faces the light: -1..1.
static func lit(n: Vector2) -> float:
	return n.normalized().dot(LIGHT_DIR)


## A tiled texture over a rectangle, anchored to the world (so neighbouring rects line up).
## `scale` = screen pixels per texel.
static func tex_rect(ci: CanvasItem, r: Rect2, tex: Texture2D, scale: float = 1.0, mod: Color = Color.WHITE) -> void:
	ci.draw_texture_rect_region(tex, r, Rect2(r.position / scale, r.size / scale), mod)


## A tiled texture over any polygon (world anchored).
static func tex_poly(ci: CanvasItem, pts: PackedVector2Array, tex: Texture2D, scale: float = 1.0, mod: Color = Color.WHITE) -> void:
	var ts := tex.get_size() * scale
	var uvs := PackedVector2Array()
	uvs.resize(pts.size())
	for k in pts.size():
		uvs[k] = Vector2(pts[k].x / ts.x, pts[k].y / ts.y)
	ci.draw_colored_polygon(pts, mod, uvs, tex)


## An irregular closed shape (puddles, stains, potholes, heaps).
static func blob(c: Vector2, radius: float, s: int, n: int = 12, rough: float = 0.3,
		stretch: Vector2 = Vector2.ONE, rot: float = 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var t := Transform2D(rot, c)
	var ph := r01(s, 99) * TAU
	for k in n:
		var a := TAU * float(k) / float(n)
		var wob := 1.0 + rough * (0.6 * sin(a * 2.0 + ph) + 0.4 * (r01(s, k) * 2.0 - 1.0))
		pts.append(t * (Vector2(cos(a) * stretch.x, sin(a) * stretch.y) * radius * wob))
	return pts


## A few stacked translucent ellipses: a stain or glow with a soft edge.
static func soft(ci: CanvasItem, c: Vector2, radii: Vector2, col: Color, rot: float = 0.0, layers: int = 3) -> void:
	for k in layers:
		var f := 1.0 - float(k) / float(layers) * 0.55
		var cc := col
		cc.a = col.a / float(layers) * (1.0 + float(k) * 0.35)
		ci.draw_colored_polygon(Draw.ellipse_points(c, radii * f, rot, 18), cc)


## A soft blob (irregular) in layers.
static func soft_blob(ci: CanvasItem, c: Vector2, radius: float, col: Color, s: int, stretch: Vector2 = Vector2.ONE, rot: float = 0.0) -> void:
	for k in 3:
		var f := 1.0 - float(k) * 0.22
		var cc := col
		cc.a = col.a * (0.35 + float(k) * 0.2)
		ci.draw_colored_polygon(blob(c, radius * f, s + k, 12, 0.28, stretch, rot), cc)


## A jagged polyline from a toward b (cracks, tar seams).
static func jag(a: Vector2, b: Vector2, s: int, amp: float, steps: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var d := b - a
	var n := Vector2(-d.y, d.x).normalized()
	for k in steps + 1:
		var t := float(k) / float(steps)
		var off := 0.0 if k == 0 or k == steps else (r01(s, k) * 2.0 - 1.0) * amp
		pts.append(a + d * t + n * off)
	return pts


## A wobbly line (a sealed tar seam): smooth, not jagged.
static func wave(a: Vector2, b: Vector2, s: int, amp: float, wavelength: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var d := b - a
	var l := d.length()
	if l < 0.5:
		return PackedVector2Array([a, b])
	var n := Vector2(-d.y, d.x) / l
	var steps := maxi(2, int(l / (wavelength * 0.25)))
	var p1 := r01(s, 1) * TAU
	var p2 := r01(s, 2) * TAU
	for k in steps + 1:
		var t := float(k) / float(steps)
		var x := t * l
		var off := amp * (0.65 * sin(x / wavelength * TAU + p1) + 0.35 * sin(x / wavelength * 2.7 + p2))
		pts.append(a + d * t + n * off)
	return pts


## Soft drop shadow of a polygon (two layers), offset `o` px.
static func shadow_poly(ci: CanvasItem, pts: PackedVector2Array, o: Vector2, strength: float = 1.0) -> void:
	var s := PackedVector2Array()
	s.resize(pts.size())
	for k in pts.size():
		s[k] = pts[k] + o
	var c := SH
	c.a *= strength
	ci.draw_colored_polygon(s, c)
	ci.draw_polyline(_closed(s), Color(c, c.a * 0.6), 2.5, true)


static func shadow_circle(ci: CanvasItem, c: Vector2, r: float, o: Vector2, strength: float = 1.0) -> void:
	var col := SH
	col.a *= strength
	ci.draw_circle(c + o, r + 1.2, Color(col, col.a * 0.5), true, -1.0, true)
	ci.draw_circle(c + o, r, col, true, -1.0, true)


## The shadow of a vertical pole of height h (px offset per metre from `sh`), width w px.
static func shadow_pole(ci: CanvasItem, base: Vector2, h_m: float, w: float, strength: float = 1.0) -> void:
	var col := SH
	col.a *= strength
	ci.draw_line(base, base + sh(h_m), col, w, true)


static func _shift_pts(pts: PackedVector2Array, o: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(pts.size())
	for k in pts.size():
		out[k] = pts[k] + o
	return out


static func _closed(pts: PackedVector2Array) -> PackedVector2Array:
	var out := pts.duplicate()
	if pts.size() > 0:
		out.append(pts[0])
	return out


## Closed outline of a polygon.
static func outline(ci: CanvasItem, pts: PackedVector2Array, col: Color, w: float = 1.0) -> void:
	ci.draw_polyline(_closed(pts), col, w, true)


## Rectangle corners (for polygons built from rects).
static func rect_pts(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])


## A rotated rectangle centred at c, size s (px), angle rot.
static func orect(c: Vector2, s: Vector2, rot: float) -> PackedVector2Array:
	var t := Transform2D(rot, c)
	var h := s * 0.5
	return PackedVector2Array([t * Vector2(-h.x, -h.y), t * Vector2(h.x, -h.y), t * Vector2(h.x, h.y), t * Vector2(-h.x, h.y)])


## Colour helpers
static func shade(c: Color, v: float) -> Color:
	return c.lightened(v) if v >= 0.0 else c.darkened(-v)


static func alpha(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, a)
