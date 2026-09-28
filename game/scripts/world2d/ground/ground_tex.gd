class_name GroundTex
extends RefCounted
## Procedural tiling textures for the ground, made once per run from fixed seeds (the same on
## every machine): fine grain, soft mottling, Belgian block, granite setts, heavy quay planks.
## They tile seamlessly and carry mipmaps, so they stay calm when the camera zooms out.

static var _cache := {}


## Fine speckle (aggregate, grit): black and white pixels with alpha, to lay over a flat colour.
static func grain() -> Texture2D:
	if _cache.has("grain"):
		return _cache["grain"]
	var n := 256
	var data := PackedByteArray()
	data.resize(n * n * 4)
	for y in n:
		for x in n:
			var h := _h(x, y, 11)
			var h2 := _h(x >> 2, y >> 2, 12)
			var i := (y * n + x) * 4
			var a := 0.0
			var white := false
			if h > 0.975:
				white = true
				a = 0.16 + (h - 0.975) * 5.0
			elif h < 0.06:
				a = 0.26 + (0.06 - h) * 4.0
			else:
				var v := h - 0.5
				white = v > 0.0
				a = absf(v) * 0.13
			# clumps: some 4x4 cells are a touch darker overall
			if h2 > 0.86:
				a = a * 0.6 + (0.08 if not white else 0.0)
				white = false if h2 > 0.93 else white
			var c := 255 if white else 0
			data[i] = c
			data[i + 1] = c
			data[i + 2] = c
			data[i + 3] = int(clampf(a, 0.0, 1.0) * 255.0)
	return _finish("grain", Image.create_from_data(n, n, false, Image.FORMAT_RGBA8, data))


## Soft, large-scale variation (value noise), black/white with alpha. Draw it scaled up.
static func mottle() -> Texture2D:
	if _cache.has("mottle"):
		return _cache["mottle"]
	var n := 64
	var data := PackedByteArray()
	data.resize(n * n * 4)
	for y in n:
		for x in n:
			var v := 0.6 * _vnoise(x / 16.0, y / 16.0, 4, 21) + 0.4 * _vnoise(x / 8.0, y / 8.0, 8, 22)
			v = (v - 0.5) * 2.0
			var i := (y * n + x) * 4
			var c := 255 if v > 0.0 else 0
			data[i] = c
			data[i + 1] = c
			data[i + 2] = c
			data[i + 3] = int(clampf(absf(v) * 0.9, 0.0, 1.0) * 255.0)
	return _finish("mottle", Image.create_from_data(n, n, false, Image.FORMAT_RGBA8, data))


## Belgian block: rows of small rectangular granite blocks laid across the street (rows run along
## x, so use it as is on north-south streets).
static func cobble() -> Texture2D:
	if _cache.has("cobble"):
		return _cache["cobble"]
	var stones: Array[Color] = [Color("58544f"), Color("5e5a54"), Color("54524f"), Color("615b53"),
		Color("5a5752"), Color("524e49")]
	var img := _stones(256, 252, 9, 12, 19, stones, Pal.COBBLE_JOINT, 31, 0.55)
	return _finish("cobble", img)


## Granite setts, larger and paler: the bed of the streetcar tracks, crossing stones.
static func setts() -> Texture2D:
	if _cache.has("setts"):
		return _cache["setts"]
	var stones: Array[Color] = [Color("5f5c57"), Color("66625c"), Color("5b5955"), Color("6a665f"), Color("615e59")]
	var img := _stones(256, 252, 12, 15, 27, stones, Color("34322e"), 47, 0.5)
	return _finish("setts", img)


## Heavy deck planks, running along x, with butt joints, nail heads and weathered grain.
static func planks() -> Texture2D:
	if _cache.has("planks"):
		return _cache["planks"]
	var w := 256
	var rh := 14
	var rows := 18
	var h := rows * rh
	var data := PackedByteArray()
	data.resize(w * h * 4)
	var rng := W.rng(53)
	for r in rows:
		var off := rng.randi_range(0, w - 1)
		var starts: Array[int] = []
		var cols: Array[Color] = []
		var pos := 0
		while pos < w:
			var l := rng.randi_range(84, 170)
			if w - pos - l < 60:
				l = w - pos
			starts.append(pos)
			var c := Pal.PLANKS.lerp(Pal.PLANKS_DARK, rng.randf_range(0.0, 0.55))
			if rng.randf() < 0.3:
				c = c.lerp(Color("6f675c"), rng.randf_range(0.25, 0.6))   # sun-bleached, grey
			c = c.lightened(rng.randf_range(-0.02, 0.1))
			cols.append(c)
			pos += l
		starts.append(w)
		var phase := rng.randf() * TAU
		var k1 := float(rng.randi_range(2, 5))
		for k in cols.size():
			var s0 := starts[k]
			var s1 := starts[k + 1]
			var base := cols[k]
			var knot_x := rng.randi_range(s0 + 10, maxi(s0 + 11, s1 - 10))
			var knot_y := rng.randi_range(3, rh - 5)
			var has_knot := rng.randf() < 0.45
			for px in range(s0, s1):
				for py in rh:
					var x := (px + off) % w
					var y := r * rh + py
					var i := (y * w + x) * 4
					var col := base
					if py == rh - 1:
						col = Color("1b1612")
					elif px == s1 - 1:
						col = Color("241d17")
					else:
						var v := 0.0
						if py == 0:
							v += 0.12
						elif py == rh - 2:
							v -= 0.2
						var g := sin(float(px) / float(w) * TAU * k1 + phase + float(py) * 0.55) * 0.05
						g += sin(float(px) / float(w) * TAU * (k1 * 3.0 + 1.0) + float(py) * 1.7) * 0.035
						v += g + (_h(px, y, 54) - 0.5) * 0.07
						if (px == s0 + 2 or px == s1 - 4) and (py == 3 or py == rh - 5):
							v = -0.55   # nail heads
						if has_knot and absi(px - knot_x) <= 2 and absi(py - knot_y) <= 1:
							v -= 0.28 if absi(px - knot_x) + absi(py - knot_y) <= 2 else 0.12
						col = Color(base.r * (1.0 + v), base.g * (1.0 + v), base.b * (1.0 + v))
					data[i] = int(clampf(col.r, 0.0, 1.0) * 255.0)
					data[i + 1] = int(clampf(col.g, 0.0, 1.0) * 255.0)
					data[i + 2] = int(clampf(col.b, 0.0, 1.0) * 255.0)
					data[i + 3] = 255
	return _finish("planks", Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, data))


# rows of stones for cobble() and setts()
static func _stones(w: int, h: int, rh: int, min_w: int, max_w: int, pal: Array[Color], joint: Color, s: int, relief: float = 1.0) -> Image:
	var data := PackedByteArray()
	data.resize(w * h * 4)
	var rng := W.rng(s)
	var rows := int(float(h) / float(rh))
	for r in rows:
		var off := rng.randi_range(0, w - 1)
		var pos := 0
		while pos < w:
			var sw := rng.randi_range(min_w, max_w)
			if w - pos - sw < min_w:
				sw = w - pos
			var base: Color = pal[rng.randi() % pal.size()]
			base = base.lightened(rng.randf_range(0.0, 0.1)) if rng.randf() < 0.5 else base.darkened(rng.randf_range(0.0, 0.12))
			# some stones warmer (iron-stained), some cooler (blue granite)
			var tint := rng.randf()
			if tint < 0.18:
				base = base.lerp(Color("6a5646"), 0.3)
			elif tint < 0.34:
				base = base.lerp(Color("4c5258"), 0.3)
			var worn := rng.randf() < 0.25
			var cx := float(sw - 2) * 0.5
			for px in sw:
				for py in rh:
					var x := (pos + px + off) % w
					var y := r * rh + py
					var i := (y * w + x) * 4
					var col: Color
					var joint_px := px == sw - 1 or py == rh - 1
					var corner := (px == 0 or px == sw - 2) and (py == 0 or py == rh - 2)
					if joint_px:
						col = joint.lerp(base, 0.3 + _h(x, y, s + 3) * 0.2).lightened((_h(x, y, s + 1) - 0.5) * 0.2)
					else:
						var v := 0.0
						if py == 0:
							v += 0.2 * relief
						elif py == 1:
							v += 0.06 * relief
						if py == rh - 2:
							v -= 0.26 * relief
						if px == 0:
							v += 0.1 * relief
						if px == sw - 2:
							v -= 0.18 * relief
						var dx := (float(px) - cx) / maxf(cx, 1.0)
						var dy := (float(py) - float(rh - 2) * 0.5) / maxf(float(rh - 2) * 0.5, 1.0)
						v -= (dx * dx * 0.06 + dy * dy * 0.05) * relief
						v += (_h(x, y, s + 2) - 0.5) * (0.06 if worn else 0.12)
						if worn:
							v += 0.05
						col = Color(base.r * (1.0 + v), base.g * (1.0 + v), base.b * (1.0 + v))
						if corner:
							col = col.lerp(joint, 0.55)
					data[i] = int(clampf(col.r, 0.0, 1.0) * 255.0)
					data[i + 1] = int(clampf(col.g, 0.0, 1.0) * 255.0)
					data[i + 2] = int(clampf(col.b, 0.0, 1.0) * 255.0)
					data[i + 3] = 255
			pos += sw
	return Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, data)


static func _finish(key: String, img: Image) -> Texture2D:
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_cache[key] = t
	return t


# integer hash -> 0..1 (inlined version of Draw.hash01)
static func _h(x: int, y: int, s: int) -> float:
	var h := (x * 374761393 + y * 668265263 + s * 144665) & 0x7fffffff
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xffff) / 65535.0


# periodic value noise, lattice period `p` cells
static func _vnoise(x: float, y: float, p: int, s: int) -> float:
	var xi := int(floor(x))
	var yi := int(floor(y))
	var fx := x - float(xi)
	var fy := y - float(yi)
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	var x0 := posmod(xi, p)
	var x1 := posmod(xi + 1, p)
	var y0 := posmod(yi, p)
	var y1 := posmod(yi + 1, p)
	var a := _h(x0, y0, s)
	var b := _h(x1, y0, s)
	var c := _h(x0, y1, s)
	var d := _h(x1, y1, s)
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy)
