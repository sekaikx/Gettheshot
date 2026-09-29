extends RefCounted
## Shared helpers for the street-face art (Shopfronts) and the roofs (CityRoofs): the sun
## direction, box shadows, lettering that fits, small procedural textures.
## Preload it: `const FX := preload("res://scripts/world2d/fronts/fx.gd")`.

## Direction shadows fall in (light from the north-west), the same as Draw.shadow's default offset.
const SUN := Vector2(0.6247, 0.7809)
## Shadow length per metre of height (a 3 m storey throws ~0.9 m).
const K := 0.3
## The colour of shade (alpha is set per use).
const SHADE := Color(0.03, 0.03, 0.06, 1.0)
## Cap height of the display fonts, as a fraction of the font size.
const CAP := 0.7

static var _tex := {}


## Offset (px, world axes) of the shadow of something `h` metres above the ground.
static func sh(h: float) -> Vector2:
	return SUN * h * K * W.M


## The convex hull of a polygon and the same polygon moved by `off`: the shadow of a prism.
static func hull_shift(pts: PackedVector2Array, off: Vector2) -> PackedVector2Array:
	var all := pts.duplicate()
	for q in pts:
		all.append(q + off)
	var h := Geometry2D.convex_hull(all)
	if h.size() > 1 and h[0].is_equal_approx(h[h.size() - 1]):
		h.remove_at(h.size() - 1)
	return h


static func rect_pts(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])


## Shadow of a box standing on the drawing plane (rect r, `off` = sh(height) in this frame).
static func box_shadow(ci: CanvasItem, r: Rect2, off: Vector2, a: float = 0.3) -> void:
	Draw.poly(ci, hull_shift(rect_pts(r), off), Color(SHADE, a))


## A soft shadow: a wider faint pass under a tighter one.
static func soft_poly(ci: CanvasItem, pts: PackedVector2Array, a: float, grow: float = 2.0) -> void:
	if pts.size() < 3:
		return
	for g in Geometry2D.offset_polygon(pts, grow, Geometry2D.JOIN_ROUND):
		Draw.poly(ci, g, Color(SHADE, a * 0.45), false)
	for g in Geometry2D.offset_polygon(pts, -grow * 0.5, Geometry2D.JOIN_ROUND):
		Draw.poly(ci, g, Color(SHADE, a * 0.6), false)


static func soft_circle(ci: CanvasItem, c: Vector2, r: float, a: float) -> void:
	ci.draw_circle(c, r + 1.5, Color(SHADE, a * 0.45), true, -1.0, true)
	ci.draw_circle(c, maxf(0.5, r - 0.8), Color(SHADE, a * 0.6), true, -1.0, true)


## The biggest font size (<= max_size) at which `s` fits in `max_w` px; 0 if not even min_size fits.
static func fit(font: Font, s: String, max_w: float, max_size: int, min_size: int = 9) -> int:
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, max_size).x
	if w <= max_w:
		return max_size
	var size := int(floor(float(max_size) * max_w / maxf(w, 1.0)))
	while size >= min_size and font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > max_w:
		size -= 1
	return size if size >= min_size else 0


## Text centred on `center` (caps centred vertically), turned by `rot` around it.
static func text_c(ci: CanvasItem, center: Vector2, s: String, size: int, color: Color, font: Font,
		rot: float = 0.0, drop: Color = Color(0, 0, 0, 0), outline: int = 0, outline_col: Color = Color(0, 0, 0, 0)) -> void:
	if size <= 0 or s == "":
		return
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var at := Vector2(-w * 0.5, float(size) * CAP * 0.5)
	ci.draw_set_transform(center, rot, Vector2.ONE)
	if outline > 0:
		ci.draw_string_outline(font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, outline_col)
	if drop.a > 0.0:
		ci.draw_string(font, at + Vector2(0.0, maxf(1.0, size * 0.06)), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, drop)
	ci.draw_string(font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Per-vertex coloured quad (a gradient along any direction).
static func quad(ci: CanvasItem, a: Vector2, b: Vector2, c: Vector2, d: Vector2, ca: Color, cb: Color, cc: Color, cd: Color) -> void:
	ci.draw_polygon(PackedVector2Array([a, b, c, d]), PackedColorArray([ca, cb, cc, cd]))


## Brightness factor for a surface tilted toward `n` (unit, world axes): lit when it faces the sun.
static func facing(n: Vector2, k: float = 0.12) -> float:
	return 1.0 - n.dot(SUN) * k


static func hashc(c: Color, x: int, y: int, s: int, amount: float) -> Color:
	var h := Draw.hash01(x, y, s) - 0.5
	return c.lightened(h * amount * 2.0) if h > 0.0 else c.darkened(-h * amount * 2.0)


# ------------------------------------------------------------------ tiling textures

## A 128 px tiling grain texture, mostly 0.8..1.0 grey, to be tinted with draw_texture_rect's
## modulate: "tar" (rolled felt: fine grain, faint streaks), "gravel" (pebbles), "tin" (seams).
static func tex(name: String) -> Texture2D:
	if _tex.has(name):
		return _tex[name]
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var v := PackedFloat32Array()
	v.resize(n * n)
	match name:
		"gravel":
			for i in n * n:
				v[i] = 0.78 + 0.08 * Draw.hash01(i % n, i / n, 11)
			var r := W.rng(4242)
			for k in 900:
				var cx := r.randi_range(0, n - 1)
				var cy := r.randi_range(0, n - 1)
				var rad := r.randf_range(0.8, 2.1)
				var val := r.randf_range(0.66, 1.0)
				var ir := int(ceil(rad))
				for dy in range(-ir, ir + 1):
					for dx in range(-ir, ir + 1):
						var d := Vector2(dx, dy).length()
						if d <= rad:
							var x := (cx + dx + n) % n
							var y := (cy + dy + n) % n
							# lit on the north-west side of each pebble
							var lit := clampf(1.0 - (dx + dy) * 0.12 / rad, 0.85, 1.12)
							v[y * n + x] = clampf(val * lit, 0.0, 1.0)
		"tin":
			for y in n:
				for x in n:
					var seam := x % 32
					var s := 0.9 + 0.03 * Draw.hash01(x / 3, y, 5)
					if seam == 0:
						s = 1.0
					elif seam == 1:
						s = 0.72
					elif seam < 5:
						s -= 0.05
					v[y * n + x] = s
		_:
			# tar paper: fine grain plus faint streaks along x (the roll direction)
			for y in n:
				var streak := 0.03 * Draw.hash01(0, y / 2, 31)
				for x in n:
					var g := 0.84 + 0.07 * Draw.hash01(x, y, 3) + streak
					if Draw.hash01(x, y, 77) > 0.985:
						g += 0.08
					v[y * n + x] = clampf(g, 0.0, 1.0)
	for y in n:
		for x in n:
			var g := v[y * n + x]
			img.set_pixel(x, y, Color(g, g, g, 1.0))
	if name == "tar_v":
		img.rotate_90(CLOCKWISE)
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex[name] = t
	return t
