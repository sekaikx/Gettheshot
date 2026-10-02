extends RefCounted
## Shared materials and procedural textures for the 3D interiors (floors, rugs, wallpaper, glass, lamps).
## Everything is cached: one material per key for the whole city, so night/day is one parameter change.

static var _mats := {}
static var _tex := {}
static var _night := 0.0

# metres one texture tile covers (x, z) per floor style
const FLOOR_SIZE := {
	"planks": Vector2(1.6, 1.6), "planks_dark": Vector2(1.6, 1.6), "planks_worn": Vector2(1.6, 1.6),
	"parquet": Vector2(1.68, 1.68), "hex": Vector2(0.42, 0.7275), "checker": Vector2(1.0, 1.0),
	"checker_red": Vector2(1.0, 1.0), "tile": Vector2(1.6, 1.6), "tile_wet": Vector2(1.6, 1.6),
	"tile_dusty": Vector2(1.6, 1.6), "lino": Vector2(1.0, 1.0), "lino_green": Vector2(1.0, 1.0),
	"concrete": Vector2(2.4, 2.4),
}


static func floor_size(style: String) -> Vector2:
	return FLOOR_SIZE.get(style, Vector2(1.6, 1.6))


static func get_mat(key: String) -> Material:
	if _mats.has(key):
		return _mats[key]
	var m := _make(key)
	_mats[key] = m
	return m


static func _base(vc: bool = true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = vc
	m.vertex_color_is_srgb = true
	m.roughness = 0.85
	m.metallic_specular = 0.25
	m.albedo_color = Color(0.72, 0.70, 0.68)
	return m


static func _make(key: String) -> Material:
	var m := _base()
	if key.begins_with("f:"):
		var st := key.substr(2)
		m.albedo_texture = floor_tex(st)
		m.albedo_color = Color(0.82, 0.8, 0.78)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		m.roughness = 0.55 if st in ["tile", "tile_wet", "checker", "checker_red", "hex", "parquet"] else 0.9
		if st == "tile_wet":
			m.roughness = 0.2
		return m
	if key.begins_with("rug:"):
		m.albedo_texture = rug_tex(key.substr(4))
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		m.roughness = 1.0
		return m
	match key:
		"s":
			m.albedo_texture = _grain()
			m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		"m":
			m.metallic = 0.55
			m.roughness = 0.34
			m.metallic_specular = 0.7
		"g":
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.roughness = 0.08
			m.metallic_specular = 0.9
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		"e":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		"bulb":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		"wp":
			m.albedo_texture = _stripes()
			m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		"gw":
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.roughness = 0.08
			m.metallic_specular = 0.9
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.albedo_color = Color(0.72, 0.88, 0.95, 0.22)
			m.emission_enabled = true
			m.emission = Color(0, 0, 0)
		"chk":
			m.albedo_texture = _gingham()
			m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		"pool":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			m.albedo_texture = _glow_tex()
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.no_depth_test = false
			m.disable_receive_shadows = true
			m.render_priority = 2
			m.albedo_color = Color(1, 1, 1, 0.3)
		"dim":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		"dirt":
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.roughness = 1.0
		_:
			pass
	return m


## 0 day .. 1 night: lit bulbs, light pools.
static func set_night(n: float) -> void:
	_night = n
	var b := get_mat("bulb") as StandardMaterial3D
	b.albedo_color = Color(0.9, 0.85, 0.7).lerp(Color(1.0, 0.9, 0.6) * 1.6, n)
	# a warm fill so rooms stay readable at night (the street's ambient is deep blue)
	for k in _mats:
		var m: Material = _mats[k]
		if m is StandardMaterial3D and k not in ["g", "gw", "pool", "dim", "e", "bulb"]:
			var sm := m as StandardMaterial3D
			sm.emission_enabled = n > 0.01
			sm.emission = Color(0.62, 0.46, 0.32) * (0.11 * n)
	var gw := get_mat("gw") as StandardMaterial3D
	gw.albedo_color = Color(0.72, 0.88, 0.95, 0.2).lerp(Color(1.0, 0.82, 0.5, 0.42), n)
	gw.emission = Color(1.0, 0.7, 0.35) * (0.55 * n)
	var p := get_mat("pool") as StandardMaterial3D
	p.albedo_color = Color(1.0, 0.8, 0.5, lerpf(0.2, 0.95, n))


# ------------------------------------------------------------------ textures

static func _h(x: int, y: int, s: int) -> float:
	return Draw.hash01(x, y, s)


static func _img(w: int, h: int, c: Color) -> Image:
	var im := Image.create(w, h, false, Image.FORMAT_RGBA8)
	im.fill(c)
	return im


static func _tex_of(im: Image, mip: bool = true) -> ImageTexture:
	if mip:
		im.generate_mipmaps()
	return ImageTexture.create_from_image(im)


static func _noise(im: Image, amt: float, s: int) -> void:
	for y in im.get_height():
		for x in im.get_width():
			var c := im.get_pixel(x, y)
			var f := 1.0 + (_h(x, y, s) - 0.5) * amt
			im.set_pixel(x, y, Color(c.r * f, c.g * f, c.b * f, c.a))


static func _grain() -> ImageTexture:
	if _tex.has("grain"):
		return _tex["grain"]
	var im := _img(64, 64, Color(0.94, 0.94, 0.94))
	_noise(im, 0.14, 3)
	var t := _tex_of(im)
	_tex["grain"] = t
	return t


static func _stripes() -> ImageTexture:
	if _tex.has("stripes"):
		return _tex["stripes"]
	var im := _img(64, 8, Color(1, 1, 1))
	for x in 64:
		var f := 1.0
		var xm := x % 16
		if xm < 5:
			f = 0.90
		elif xm < 6:
			f = 0.80
		elif xm >= 14:
			f = 0.97
		for y in 8:
			im.set_pixel(x, y, Color(f, f, f))
	var t := _tex_of(im)
	_tex["stripes"] = t
	return t


static func _gingham() -> ImageTexture:
	if _tex.has("gingham"):
		return _tex["gingham"]
	var im := _img(64, 64, Color(0.96, 0.93, 0.88))
	var red := Color(0.72, 0.18, 0.16)
	for y in 64:
		for x in 64:
			var a := (x / 8) % 2 == 0
			var b := (y / 8) % 2 == 0
			if a and b:
				im.set_pixel(x, y, red)
			elif a or b:
				im.set_pixel(x, y, Color(0.96, 0.93, 0.88).lerp(red, 0.38))
	var t := _tex_of(im)
	_tex["gingham"] = t
	return t


static func _glow_tex() -> ImageTexture:
	if _tex.has("glow"):
		return _tex["glow"]
	var n := 64
	var im := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d := Vector2(x - n * 0.5 + 0.5, y - n * 0.5 + 0.5).length() / (n * 0.5)
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a * (3.0 - 2.0 * a)
			im.set_pixel(x, y, Color(1, 1, 1, a))
	var t := ImageTexture.create_from_image(im)
	_tex["glow"] = t
	return t


static func floor_tex(style: String) -> ImageTexture:
	var k := "f:" + style
	if _tex.has(k):
		return _tex[k]
	var im: Image
	match style:
		"planks": im = _planks(Color("84694e"), 11, 0.0)
		"planks_dark": im = _planks(Color("59463a"), 12, 0.0)
		"planks_worn": im = _planks(Color("7c6247"), 13, 1.0)
		"parquet": im = _parquet()
		"hex": im = _hex()
		"checker": im = _checker(Color("ece6d6"), Color("23201d"))
		"checker_red": im = _checker(Color("efe8d8"), Color("9a3a30"))
		"tile": im = _tiles(Color("e6e0d0"), 0)
		"tile_wet": im = _tiles(Color("c4cdca"), 1)
		"tile_dusty": im = _tiles(Color("d4c8b0"), 2)
		"lino": im = _lino(Color("e8dcc0"), Color("6a8a74"))
		"lino_green": im = _lino(Color("5a7a66"), Color("486a56"))
		"concrete": im = _concrete()
		_: im = _planks(Color("84694e"), 11, 0.0)
	var t := _tex_of(im)
	_tex[k] = t
	return t


static func _planks(base: Color, s: int, wear: float) -> Image:
	var n := 256
	var im := _img(n, n, base.darkened(0.4))
	var bw := 32
	for i in 8:
		var y := -int(_h(i, 1, s) * 200.0)
		var j := 0
		while y < n:
			var ln := 100 + int(_h(i, j, s + 1) * 130.0)
			var t := _h(i, j, s + 2)
			var c := base.lightened(0.10 * t) if t > 0.45 else base.darkened(0.12 * (1.0 - t))
			c = c.lerp(Color("a07c52"), 0.0)
			var y0 := maxi(y, 0)
			var y1 := mini(y + ln - 2, n)
			if y1 > y0:
				im.fill_rect(Rect2i(i * bw + 1, y0, bw - 2, y1 - y0), c)
			y += ln
			j += 1
		# grain streaks
		for g in 5:
			var gx := i * bw + 4 + int(_h(i, g, s + 7) * (bw - 8))
			var gy := int(_h(i, g, s + 8) * n)
			var gl := 20 + int(_h(i, g, s + 9) * 70)
			var gc := base.darkened(0.25)
			gc.a = 0.5
			for yy in gl:
				var py := (gy + yy) % n
				var px := gx
				var c0 := im.get_pixel(px, py)
				im.set_pixel(px, py, c0.lerp(gc, 0.35))
	if wear > 0.0:
		for y in n:
			for x in n:
				var w := _h(x / 3, y / 3, s + 20)
				if w > 0.8:
					var c0 := im.get_pixel(x, y)
					im.set_pixel(x, y, c0.lightened(0.07))
	_noise(im, 0.10, s + 30)
	return im


static func _parquet() -> Image:
	var n := 256
	var base := Color("90704a")
	var im := _img(n, n, base.darkened(0.45))
	var q := 64
	for qy in 4:
		for qx in 4:
			var vertical := (qx + qy) % 2 == 0
			for m in 3:
				var t := _h(qx * 3 + m, qy, 40)
				var c := base.lightened(0.1 * t) if vertical else base.darkened(0.1 + 0.08 * t)
				if vertical:
					im.fill_rect(Rect2i(qx * q + m * 21 + 1, qy * q + 1, 19, q - 2), c)
				else:
					im.fill_rect(Rect2i(qx * q + 1, qy * q + m * 21 + 1, q - 2, 19), c)
	_noise(im, 0.10, 41)
	return im


static func _hex() -> Image:
	var w := 192
	var h := 333
	var im := _img(w, h, Color("707070"))
	var sp := 64.0
	var rh := sp * 0.8660254
	for y in h:
		var j0 := int(round(float(y) / rh))
		for x in w:
			var d1 := 1e9
			var d2 := 1e9
			var bi := 0
			var bj := 0
			for dj in range(-1, 2):
				var j := j0 + dj
				var ox := (posmod(j, 2)) * sp * 0.5
				var i0 := int(round((float(x) - ox) / sp))
				for di in range(-1, 2):
					var i := i0 + di
					var cx := i * sp + ox
					var cy := j * rh
					var d := sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy))
					if d < d1:
						d2 = d1
						d1 = d
						bi = i
						bj = j
					elif d < d2:
						d2 = d
			var ci := posmod(bi, 3)
			var cj := posmod(bj, 6)
			var r := _h(ci, cj, 77)
			var col := Color("ece6d8")
			if r < 0.07:
				col = Color("7a756c")
			elif r < 0.30:
				col = Color("cfc8b8")
			col = col.darkened(0.07 * _h(ci, cj, 78))
			if d2 - d1 < 2.6:
				col = Color("8c8578")
			im.set_pixel(x, y, col)
	return im


static func _checker(a: Color, b: Color) -> Image:
	var n := 256
	var im := _img(n, n, a)
	var q := 64
	for qy in 4:
		for qx in 4:
			var c := a if (qx + qy) % 2 == 0 else b
			var t := _h(qx, qy, 50)
			c = c.lightened(0.03 * t) if c.get_luminance() > 0.5 else c.lightened(0.05 * t)
			im.fill_rect(Rect2i(qx * q, qy * q, q, q), c)
			im.fill_rect(Rect2i(qx * q, qy * q, q, 1), Color(0.3, 0.28, 0.25, 1).lerp(c, 0.5))
			im.fill_rect(Rect2i(qx * q, qy * q, 1, q), Color(0.3, 0.28, 0.25, 1).lerp(c, 0.5))
	_noise(im, 0.08, 51)
	return im


static func _tiles(base: Color, variant: int) -> Image:
	var n := 256
	var im := _img(n, n, base.darkened(0.35))
	var q := 32
	for ty in 8:
		for tx in 8:
			var t := _h(tx, ty, 60 + variant)
			var c := base.lightened(0.05 * t) if t > 0.5 else base.darkened(0.06 * (1.0 - t))
			im.fill_rect(Rect2i(tx * q + 1, ty * q + 1, q - 2, q - 2), c)
			if variant == 1:
				im.fill_rect(Rect2i(tx * q + 3, ty * q + 3, 9, 2), Color(1, 1, 1, 1).lerp(c, 0.3))
	if variant == 2:
		for y in n:
			for x in n:
				var d := _h(x / 4, y / 4, 66)
				if d > 0.55:
					var c0 := im.get_pixel(x, y)
					im.set_pixel(x, y, c0.lerp(Color("a89470"), (d - 0.55) * 0.9))
	_noise(im, 0.07, 69)
	return im


static func _lino(a: Color, b: Color) -> Image:
	var n := 256
	var im := _img(n, n, a)
	var q := 128
	for qy in 2:
		for qx in 2:
			var c := a if (qx + qy) % 2 == 0 else b
			im.fill_rect(Rect2i(qx * q, qy * q, q, q), c)
			im.fill_rect(Rect2i(qx * q, qy * q, q, 2), c.darkened(0.25))
			im.fill_rect(Rect2i(qx * q, qy * q, 2, q), c.darkened(0.25))
	_noise(im, 0.10, 81)
	return im


static func _concrete() -> Image:
	var n := 128
	var nz := FastNoiseLite.new()
	nz.seed = 5
	nz.frequency = 0.06
	nz.fractal_octaves = 3
	var src := nz.get_seamless_image(n, n)
	var im := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var v := src.get_pixel(x, y).r
			var g := 0.40 + v * 0.14 + (_h(x, y, 90) - 0.5) * 0.05
			im.set_pixel(x, y, Color(g * 0.98, g, g * 1.0))
	# a few expansion joints
	for i in n:
		im.set_pixel(i, 0, Color(0.26, 0.26, 0.26))
		im.set_pixel(0, i, Color(0.26, 0.26, 0.26))
	return im


static func rug_tex(style: String) -> ImageTexture:
	var k := "rug:" + style
	if _tex.has(k):
		return _tex[k]
	var base: Color
	var border: Color
	var accent: Color
	match style:
		"club":
			base = Color("5a2a22")
			border = Color("3a1a16")
			accent = Color("c9a54a")
		"speak":
			base = Color("6a1f26")
			border = Color("3c1c3a")
			accent = Color("d4a532")
		"persian_blue":
			base = Color("23385a")
			border = Color("7a2e2a")
			accent = Color("e0d2a8")
		_:
			base = Color("84302a")
			border = Color("22304e")
			accent = Color("dccd9c")
	var w := 128
	var h := 192
	var im := _img(w, h, border)
	im.fill_rect(Rect2i(10, 10, w - 20, h - 20), base)
	for i in 2:
		var o := 6 + i * 6
		var c := accent if i == 0 else accent.darkened(0.2)
		im.fill_rect(Rect2i(o, o, w - o * 2, 2), c)
		im.fill_rect(Rect2i(o, h - o - 2, w - o * 2, 2), c)
		im.fill_rect(Rect2i(o, o, 2, h - o * 2), c)
		im.fill_rect(Rect2i(w - o - 2, o, 2, h - o * 2), c)
	# diamond medallion
	var cx := w / 2
	var cy := h / 2
	for y in h:
		for x in w:
			var dx := absi(x - cx) / 44.0
			var dy := absi(y - cy) / 70.0
			var d := dx + dy
			if d < 1.0:
				var c := border.lightened(0.06)
				if d > 0.88:
					c = accent
				elif d < 0.3:
					c = accent.darkened(0.15)
				elif d > 0.5 and d < 0.58:
					c = accent.darkened(0.3)
				im.set_pixel(x, y, c)
	for j in 6:
		for i in 3:
			var px := 24 + i * 40
			var py := 22 + j * 30
			if absf(px - cx) / 44.0 + absf(py - cy) / 70.0 > 1.1:
				im.fill_rect(Rect2i(px - 2, py - 2, 5, 5), Color(accent, 1).darkened(0.1))
	_noise(im, 0.12, 101)
	var t := _tex_of(im)
	_tex[k] = t
	return t
