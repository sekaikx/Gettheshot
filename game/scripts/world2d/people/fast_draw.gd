class_name FastDraw
extends RefCounted
## Cheap shapes for art that redraws every frame (legs, arms, hands, guns of walking people).
## Circles and ellipses are one quad textured with an anti-aliased disc: about 40x cheaper than
## draw_circle(antialiased) and 90x cheaper than a generated ellipse polygon with an AA outline.
## Capsules are an AA line plus two discs. `soft()` is a blurred blob for shadows.
## Draw these with texture_filter = LINEAR_WITH_MIPMAPS so small discs stay smooth.

const N := 64

static var _disc: Texture2D
static var _soft: Texture2D


static func disc_tex() -> Texture2D:
	if _disc == null:
		var img := Image.create_empty(N, N, true, Image.FORMAT_RGBA8)
		var h := N * 0.5
		for y in N:
			for x in N:
				var d := Vector2(x + 0.5 - h, y + 0.5 - h).length()
				img.set_pixel(x, y, Color(1, 1, 1, clampf(h - 0.5 - d, 0.0, 1.0)))
		img.generate_mipmaps()
		_disc = ImageTexture.create_from_image(img)
	return _disc


static func soft_tex() -> Texture2D:
	if _soft == null:
		var img := Image.create_empty(N, N, true, Image.FORMAT_RGBA8)
		var h := N * 0.5
		for y in N:
			for x in N:
				var d := Vector2(x + 0.5 - h, y + 0.5 - h).length() / (h - 0.5)
				img.set_pixel(x, y, Color(1, 1, 1, 1.0 - smoothstep(0.3, 1.0, d)))
		img.generate_mipmaps()
		_soft = ImageTexture.create_from_image(img)
	return _soft


static func disc(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	ci.draw_texture_rect(disc_tex(), Rect2(c.x - r, c.y - r, r * 2.0, r * 2.0), false, col)


## An axis-aligned ellipse.
static func oval(ci: CanvasItem, c: Vector2, radii: Vector2, col: Color) -> void:
	ci.draw_texture_rect(disc_tex(), Rect2(c - radii, radii * 2.0), false, col)


## A turned ellipse. `base` is the transform the caller draws with (restored afterwards).
static func oval_rot(ci: CanvasItem, base: Transform2D, c: Vector2, radii: Vector2, rot: float, col: Color) -> void:
	ci.draw_set_transform_matrix(base * Transform2D(rot, c))
	ci.draw_texture_rect(disc_tex(), Rect2(-radii, radii * 2.0), false, col)
	ci.draw_set_transform_matrix(base)


## A soft blob (shadows), turned, in the caller's `base` transform.
static func soft(ci: CanvasItem, base: Transform2D, c: Vector2, radii: Vector2, rot: float, col: Color) -> void:
	ci.draw_set_transform_matrix(base * Transform2D(rot, c))
	ci.draw_texture_rect(soft_tex(), Rect2(-radii, radii * 2.0), false, col)
	ci.draw_set_transform_matrix(base)


## A stroke with round ends.
static func capsule(ci: CanvasItem, a: Vector2, b: Vector2, r: float, col: Color) -> void:
	if a.distance_squared_to(b) > 0.01:
		ci.draw_line(a, b, col, maxf(r * 2.0 - 0.7, 0.5), true)
	disc(ci, a, r, col)
	disc(ci, b, r, col)


## A stroke with round ends that thins from `ra` at `a` to `rb` at `b` (bats, fingers).
static func taper(ci: CanvasItem, a: Vector2, b: Vector2, ra: float, rb: float, col: Color) -> void:
	var m := a.lerp(b, 0.5)
	ci.draw_line(a, m, col, maxf((ra * 0.75 + rb * 0.25) * 2.0 - 0.7, 0.5), true)
	ci.draw_line(m, b, col, maxf((ra * 0.25 + rb * 0.75) * 2.0 - 0.7, 0.5), true)
	disc(ci, a, ra, col)
	disc(ci, m, (ra + rb) * 0.5, col)
	disc(ci, b, rb, col)
