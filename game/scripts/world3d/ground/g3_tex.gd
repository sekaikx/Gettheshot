class_name G3Tex
extends RefCounted
## Procedural, seamless ground textures for the 3D street (asphalt, Belgian block, granite setts,
## sidewalk flags, quay planks, dirt, water noise), each with an optional normal map built from a bump
## map. Made once per run from fixed seeds. All are 256 x 256 and carry mipmaps.

const N := 256
static var _cache := {}


static func _h(x: int, y: int, s: int) -> float:
	return Draw.hash01(x, y, s)


static func _noise(seed_v: int, freq: float, octaves: int = 3) -> Image:
	var fn := FastNoiseLite.new()
	fn.seed = seed_v
	fn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	fn.frequency = freq
	fn.fractal_octaves = octaves
	return fn.get_seamless_image(N, N, false, false, 0.1, true)


static func _finish(img: Image) -> ImageTexture:
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func _normal(bump: Image, strength: float) -> ImageTexture:
	var b := bump.duplicate() as Image
	b.bump_map_to_normal_map(strength)
	b.generate_mipmaps()
	return ImageTexture.create_from_image(b)


static func _entry(key: String) -> Dictionary:
	if _cache.has(key):
		return _cache[key]
	var d: Dictionary
	match key:
		"asphalt": d = _asphalt()
		"cobble": d = _cobble()
		"setts": d = _setts()
		"slab": d = _slab()
		"planks": d = _planks()
		"dirt": d = _dirt()
		"water": d = _water()
		_: d = {}
	_cache[key] = d
	return d


static func albedo(key: String) -> ImageTexture:
	return _entry(key)["albedo"]


static func normal(key: String) -> ImageTexture:
	return _entry(key).get("normal", null)


static func _asphalt() -> Dictionary:
	var n1 := _noise(7, 0.012, 3)
	var n2 := _noise(8, 0.05, 2)
	var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
	var bump := Image.create(N, N, false, Image.FORMAT_L8)
	for y in N:
		for x in N:
			var a := n1.get_pixel(x, y).r
			var b := n2.get_pixel(x, y).r
			var v := 0.27 + (a - 0.5) * 0.07 + (b - 0.5) * 0.035
			var g := _h(x, y, 11)
			var bp := 0.5
			if g > 0.965:
				v += 0.05 + (g - 0.965) * 2.0
				bp = 0.8
			elif g < 0.07:
				v -= 0.05
				bp = 0.3
			else:
				v += (g - 0.5) * 0.03
				bp = 0.5 + (g - 0.5) * 0.2
			img.set_pixel(x, y, Color(v * 0.99, v, v * 1.04, 1.0))
			bump.set_pixel(x, y, Color(bp, bp, bp, 1.0))
	return {"albedo": _finish(img), "normal": _normal(bump, 3.0)}


static func _blocks(rows: int, widths: Array, stagger: bool, seed_v: int, base: Color, spread: float, joint: float, dome: float) -> Dictionary:
	var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
	var bump := Image.create(N, N, false, Image.FORMAT_L8)
	var mott := _noise(seed_v + 3, 0.03, 2)
	for r in rows:
		var y0 := int(floor(float(r) * N / rows))
		var y1 := int(floor(float(r + 1) * N / rows))
		# column breaks for this row, summing exactly to N (tiles seamlessly)
		var cuts: Array = []
		var x := int(_h(r, 1, seed_v) * 20.0) if stagger else 0
		var pos := x
		while pos < N + x:
			var w := int(lerpf(float(widths[0]), float(widths[1]), _h(r, pos, seed_v + 5)))
			cuts.append(pos)
			pos += w
		var last: int = cuts[cuts.size() - 1]
		if pos - (N + x) > 0 and cuts.size() > 1:
			# squeeze the last block so the row closes at exactly N + x
			pass
		cuts.append(N + x)
		for k in cuts.size() - 1:
			var c0: int = cuts[k]
			var c1: int = cuts[k + 1]
			if last < 0:
				pass
			var tone := (_h(r, c0, seed_v + 9) - 0.5) * spread
			var warm := (_h(r, c0, seed_v + 13) - 0.5) * 0.018
			for yy in range(y0, y1):
				for xx in range(c0, c1):
					var px := xx % N
					var u := (float(xx - c0) + 0.5) / float(c1 - c0)
					var w2 := (float(yy - y0) + 0.5) / float(y1 - y0)
					var edge := minf(minf(u, 1.0 - u) * float(c1 - c0), minf(w2, 1.0 - w2) * float(y1 - y0))
					var m := mott.get_pixel(px, yy).r - 0.5
					var v := base.r + tone + m * spread * 0.6 + (_h(px, yy, seed_v + 21) - 0.5) * 0.04
					var col := Color(v + warm + 0.01, v, v - warm * 0.8 - 0.01, 1.0)
					var hgt := 0.0
					if edge < 1.6:
						col = col.darkened(joint * (1.0 - edge / 1.6))
						hgt = edge / 1.6
					else:
						hgt = 1.0
					var du := absf(u - 0.5) * 2.0
					var dw := absf(w2 - 0.5) * 2.0
					var bump_v := clampf(hgt * (1.0 - dome * (du * du + dw * dw) * 0.5), 0.0, 1.0)
					# light catching the top-left lip
					if edge >= 1.6 and edge < 3.0 and (u < 0.5 or w2 < 0.5):
						col = col.lightened(0.05)
					img.set_pixel(px, yy, col)
					bump.set_pixel(px, yy, Color(bump_v, bump_v, bump_v, 1.0))
	return {"albedo": _finish(img), "normal": _normal(bump, 5.0)}


static func _cobble() -> Dictionary:
	return _blocks(16, [20, 30], true, 31, Color(0.27, 0.265, 0.26), 0.05, 0.55, 0.7)


static func _setts() -> Dictionary:
	return _blocks(12, [46, 62], true, 41, Color(0.36, 0.35, 0.335), 0.04, 0.5, 0.25)


static func _slab() -> Dictionary:
	var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
	var bump := Image.create(N, N, false, Image.FORMAT_L8)
	var mott := _noise(51, 0.025, 3)
	var fine := _noise(52, 0.12, 2)
	for sy in 2:
		for sx in 2:
			var tone := (_h(sx, sy, 61) - 0.5) * 0.05
			var wx := _h(sx, sy, 62) * 2.0
			for y in range(sy * 128, sy * 128 + 128):
				for x in range(sx * 128, sx * 128 + 128):
					var ex := minf(float(x - sx * 128), float(sx * 128 + 127 - x))
					var ey := minf(float(y - sy * 128), float(sy * 128 + 127 - y))
					var e := minf(ex, ey)
					var m := mott.get_pixel(x, y).r - 0.5
					var f := fine.get_pixel(x, y).r - 0.5
					var v := 0.45 + tone + m * 0.05 + f * 0.03 + (_h(x, y, 63) - 0.5) * 0.045
					var col := Color(v * 1.0, v * 0.955, v * 0.88, 1.0)
					var hgt := 1.0
					if e < 2.0:
						var k := 1.0 - e / 2.0
						col = col.darkened(0.42 * k)
						hgt = 1.0 - k
					elif e < 5.0:
						col = col.darkened(0.04 * (1.0 - (e - 2.0) / 3.0))
					# a worn trowelled diagonal edge on some slabs
					if _h(sx, sy, 64) < 0.3 and absf(float(x - sx * 128) - float(y - sy * 128) - 20.0 * wx) < 1.0:
						col = col.darkened(0.12)
					img.set_pixel(x, y, col)
					bump.set_pixel(x, y, Color(hgt, hgt, hgt, 1.0))
	return {"albedo": _finish(img), "normal": _normal(bump, 2.0)}


static func _planks() -> Dictionary:
	var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
	var bump := Image.create(N, N, false, Image.FORMAT_L8)
	var rows := 6
	var mott := _noise(71, 0.02, 3)
	for r in rows:
		var y0 := int(floor(float(r) * N / rows))
		var y1 := int(floor(float(r + 1) * N / rows))
		var tone := (_h(r, 3, 72) - 0.5) * 0.09
		var phases: Array = []
		for k in 6:
			phases.append(_h(r, k, 73) * TAU)
		var joints: Array = [int(_h(r, 5, 74) * N)]
		if _h(r, 6, 74) < 0.5:
			joints.append((joints[0] + 100 + int(_h(r, 7, 74) * 60.0)) % N)
		for y in range(y0, y1):
			for x in N:
				var g := 0.0
				for k in 6:
					g += cos(TAU * float(k + 1) * float(x) / float(N) + phases[k] + float(y) * 0.35 * float(k % 3 + 1)) / float(k + 2)
				var edge := minf(float(y - y0), float(y1 - 1 - y))
				var m := mott.get_pixel(x, y).r - 0.5
				var v := 0.34 + tone + g * 0.03 + m * 0.07 + (_h(x, y, 75) - 0.5) * 0.03
				var col := Color(v * 1.06, v * 0.95, v * 0.84, 1.0)
				var hgt := 1.0
				if edge < 1.5:
					col = col.darkened(0.55 * (1.0 - edge / 1.5))
					hgt = edge / 1.5
				for j in joints:
					var dj := absi(x - int(j))
					if dj < 2:
						col = col.darkened(0.5)
						hgt = 0.2
				# nails near the joints and along the plank ends
				for j2 in joints:
					for nx in [int(j2) + 7, int(j2) - 7]:
						if absi(x - (nx + N) % N) < 2 and absi(y - (y0 + 5)) < 2 or absi(x - (nx + N) % N) < 2 and absi(y - (y1 - 6)) < 2:
							col = col.darkened(0.45)
				img.set_pixel(x, y, col)
				bump.set_pixel(x, y, Color(hgt, hgt, hgt, 1.0))
	return {"albedo": _finish(img), "normal": _normal(bump, 3.0)}


static func _dirt() -> Dictionary:
	var n1 := _noise(81, 0.018, 3)
	var n2 := _noise(82, 0.09, 2)
	var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
	var bump := Image.create(N, N, false, Image.FORMAT_L8)
	for y in N:
		for x in N:
			var a := n1.get_pixel(x, y).r - 0.5
			var b := n2.get_pixel(x, y).r - 0.5
			var v := 0.36 + a * 0.12 + b * 0.05
			var g := _h(x, y, 83)
			var col := Color(v * 1.06, v * 0.95, v * 0.8, 1.0)
			var bp := 0.5 + b * 0.5
			if g > 0.985:
				col = Color(0.5, 0.48, 0.44, 1.0)
				bp = 0.9
			elif g < 0.03:
				col = col.darkened(0.3)
				bp = 0.2
			img.set_pixel(x, y, col)
			bump.set_pixel(x, y, Color(bp, bp, bp, 1.0))
	return {"albedo": _finish(img), "normal": _normal(bump, 2.0)}


## Water: two seamless noise bumps the shader scrolls (only the normal is used).
static func _water() -> Dictionary:
	var n1 := _noise(91, 0.02, 4)
	var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
	for y in N:
		for x in N:
			var a := n1.get_pixel(x, y).r
			img.set_pixel(x, y, Color(a, a, a, 1.0))
	var tex := _finish(img)
	var nm := _normal(img, 6.0)
	return {"albedo": tex, "normal": nm}
