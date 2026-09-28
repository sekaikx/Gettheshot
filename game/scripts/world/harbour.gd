class_name Harbour
extends RefCounted
## The big pieces of the West Street waterfront, modelled in code (metres):
##   freighter()  - a three-island tramp steamer, 44 m, bow toward local +z, the pier on local -x,
##                  origin on the waterline amidships; derricks swung out over the pier
##   gantry()     - a portal crane on quay rails, jib out over the river (+x)
##   union_hall() - the longshoremen's clapboard hiring hall, door on local +z
##   rum_runner() - the night boat: a long, low, grey launch loaded with sacks of bottles
## Surfaces use the shared cut-away prop materials, so tall parts clear out of the camera's way.

const HULL := Color("1c1c1e")
const BOOT := Color("6a2a20")
const CREAM := Color("d6cdb6")
const RUST := Color("6e3526")
const MAST := Color("b8a47a")
const DECK := Color("4e463c")
const TARP := Color("33402f")

static var _hull_mat: ShaderMaterial
static var _cache := {}


static func hull_mat() -> ShaderMaterial:
	if _hull_mat == null:
		_hull_mat = ShaderMaterial.new()
		_hull_mat.shader = preload("res://scripts/world/prop_cut.gdshader")
		_hull_mat.set_shader_parameter("rough", 0.5)
		_hull_mat.set_shader_parameter("metal", 0.15)
	return _hull_mat


static func set_night(_v: float) -> void:
	pass


static func _mats() -> Dictionary:
	Props1920s.materials()
	return {"base": Props1920s.base_mat, "iron": Props1920s.iron_mat, "glow": Props1920s.glow_mat, "hull": hull_mat()}


## Lofted hull: stations along z, half-beam b(z), deck line d(z); bands coloured by height.
static func _hull(k: MeshKit, z0: float, z1: float, steps: int, bfn: Callable, dfn: Callable, keel: float,
		bands: Array, deck_col: Color, bulwark: float, inner_col: Color) -> void:
	var zs: Array = []
	for i in steps + 1:
		zs.append(lerpf(z0, z1, float(i) / steps))
	for side in [1.0, -1.0]:
		for bi in bands.size():
			var y_lo: float = bands[bi][0]
			var col: Color = bands[bi][2]
			for i in steps:
				var za: float = zs[i]
				var zb: float = zs[i + 1]
				var ba: float = bfn.call(za)
				var bb: float = bfn.call(zb)
				var top_a: float = dfn.call(za) + bulwark
				var top_b: float = dfn.call(zb) + bulwark
				var hi_a: float = minf(bands[bi][1], top_a) if bi == bands.size() - 1 else bands[bi][1]
				var hi_b: float = minf(bands[bi][1], top_b) if bi == bands.size() - 1 else bands[bi][1]
				if bi == bands.size() - 1:
					hi_a = top_a
					hi_b = top_b
				var wa_lo := _wscale(y_lo, keel)
				var wb_lo := _wscale(y_lo, keel)
				var wa_hi := _wscale(hi_a, keel)
				var wb_hi := _wscale(hi_b, keel)
				var pts := [Vector3(side * ba * wa_lo, y_lo, za), Vector3(side * bb * wb_lo, y_lo, zb),
					Vector3(side * bb * wb_hi, hi_b, zb), Vector3(side * ba * wa_hi, hi_a, za)]
				k.face_auto("hull", pts, col, Vector3(side, 0, 0))
		# bulwark inside face, rail cap, deck
		for i in steps:
			var za: float = zs[i]
			var zb: float = zs[i + 1]
			var ba: float = bfn.call(za)
			var bb: float = bfn.call(zb)
			var da: float = dfn.call(za)
			var db: float = dfn.call(zb)
			if bulwark > 0.0:
				var ia := maxf(ba - 0.18, 0.0)
				var ib := maxf(bb - 0.18, 0.0)
				k.face_auto("hull", [Vector3(side * ia, da, za), Vector3(side * ib, db, zb), Vector3(side * ib, db + bulwark, zb), Vector3(side * ia, da + bulwark, za)], inner_col, Vector3(-side, 0, 0))
				k.face_auto("hull", [Vector3(side * ia, da + bulwark, za), Vector3(side * ib, db + bulwark, zb), Vector3(side * bb, db + bulwark, zb), Vector3(side * ba, da + bulwark, za)], CREAM.darkened(0.2), Vector3.UP)
			var ia2 := maxf(ba - (0.18 if bulwark > 0.0 else 0.0), 0.0)
			var ib2 := maxf(bb - (0.18 if bulwark > 0.0 else 0.0), 0.0)
			k.face_auto("base", [Vector3(0, da, za), Vector3(0, db, zb), Vector3(side * ib2, db, zb), Vector3(side * ia2, da, za)], deck_col, Vector3.UP)
	# the transom
	var bs: float = bfn.call(z0)
	var ds: float = dfn.call(z0) + bulwark
	k.face_auto("hull", [Vector3(-bs * _wscale(keel, keel), keel, z0), Vector3(bs * _wscale(keel, keel), keel, z0), Vector3(bs, ds, z0), Vector3(-bs, ds, z0)], (bands[bands.size() - 1][2] as Color), Vector3.BACK)


static func _wscale(y: float, keel: float) -> float:
	# sections narrow towards the keel
	if y >= 0.0:
		return 1.0
	var t := clampf(y / keel, 0.0, 1.0)
	return lerpf(1.0, 0.55, t * t)


# ------------------------------------------------------------------ the freighter

static func freighter() -> ArrayMesh:
	if _cache.has("freighter"):
		return _cache["freighter"]
	var k := MeshKit.new()
	var L := 22.0
	var B := 4.2
	var bfn := func(z: float) -> float:
		var t := z / L
		if t > 0.5:
			return B * maxf(0.0, 1.0 - pow((t - 0.5) / 0.5, 1.7))
		if t < -0.82:
			return B * (0.62 + 0.38 * sqrt(maxf(0.0, 1.0 - pow((-t - 0.82) / 0.18, 2.0))))
		return B
	var dfn := func(z: float) -> float:
		var t := z / L
		var d := 3.4 + 0.7 * t * t
		if z > 13.5:
			d += 1.9
		elif z < -15.0:
			d += 1.5
		return d
	_hull(k, -L, L, 44, bfn, dfn, -2.6, [[-2.6, 0.25, BOOT], [0.25, 0.4, Color("d8d0bc")], [0.4, 99.0, HULL]], DECK, 0.95, Color("5e4a3c"))
	# forecastle and poop fronts (bulkheads across the deck)
	var fz := 13.5
	k.face("hull", [Vector3(-B * 0.97, 3.4 + 0.7 * 0.38, fz), Vector3(B * 0.97, 3.4 + 0.7 * 0.38, fz), Vector3(B * 0.97, 5.6, fz), Vector3(-B * 0.97, 5.6, fz)], Color("c8bfa8"), Vector3.BACK)
	k.face("hull", [Vector3(-B * 0.97, 3.4 + 0.7 * 0.46, -15.0), Vector3(B * 0.97, 3.4 + 0.7 * 0.46, -15.0), Vector3(B * 0.97, 5.3, -15.0), Vector3(-B * 0.97, 5.3, -15.0)], Color("c8bfa8"), Vector3.FORWARD)
	# hatches with tarpaulins and battens
	for hz in [10.0, 4.6, -8.2, -12.2]:
		var d: float = dfn.call(hz)
		k.box("iron", Vector3(0, d + 0.45, hz), Vector3(4.2, 0.9, 3.2), Color("4a4640"))
		k.bbox("base", Vector3(0, d + 0.95, hz), Vector3(4.3, 0.18, 3.3), 0.06, TARP)
		for b in 3:
			k.box("iron", Vector3(0, d + 1.05, hz - 1.1 + b * 1.1), Vector3(4.4, 0.05, 0.08), Color("2a2622"))
	# bridge house amidships: three tiers, wings, wheelhouse windows, portholes
	var d0: float = dfn.call(-1.0)
	k.box("hull", Vector3(0, d0 + 1.25, -1.5), Vector3(6.4, 2.5, 5.2), CREAM)
	k.box("hull", Vector3(0, d0 + 3.3, -1.2), Vector3(5.4, 1.6, 4.0), CREAM)
	k.box("hull", Vector3(0, d0 + 4.6, -0.3), Vector3(4.0, 1.0, 2.0), CREAM.darkened(0.05))
	k.box("base", Vector3(0, d0 + 5.15, -0.3), Vector3(4.4, 0.1, 2.4), Color("3a3430"))
	k.box("base", Vector3(0, d0 + 4.15, -1.2), Vector3(8.2, 0.08, 1.3), Color("8a7a60"))   # bridge wings
	for s in [-1.0, 1.0]:
		k.box("iron", Vector3(s * 4.05, d0 + 4.6, -1.2), Vector3(0.05, 0.9, 1.3), CREAM)
	for wx in 5:
		k.box("glow", Vector3(-1.6 + wx * 0.8, d0 + 4.7, 0.71), Vector3(0.55, 0.45, 0.02), Color("ffd9a0"))
	for s in [-1.0, 1.0]:
		for pz in 5:
			k.box("glow", Vector3(s * 3.21, d0 + 1.5, -3.5 + pz * 1.0), Vector3(0.02, 0.28, 0.28), Color("ffd090"))
		k.box("base", Vector3(s * 3.21, d0 + 1.0, -0.5), Vector3(0.03, 1.8, 0.8), Color("3a2c22"))
	# the funnel, raked, in the line's colours
	var fb := Vector3(0, d0 + 4.0, -3.4)
	var ft := Vector3(0, d0 + 10.0, -4.0)
	k.cyl("hull", fb, fb.lerp(ft, 0.72), 1.05, 1.02, 14, Color("c2a878"))
	k.cyl("hull", fb.lerp(ft, 0.72), fb.lerp(ft, 0.84), 1.02, 1.01, 14, Color("8b1e1a"))
	k.cyl("hull", fb.lerp(ft, 0.84), ft, 1.01, 1.0, 14, Color("141414"))
	k.cyl("base", ft - Vector3(0, 0.05, 0), ft, 0.9, 0.0, 14, Color("0a0a0a"))
	for s in [-1.0, 1.0]:
		k.cyl("iron", Vector3(s * 1.6, d0 + 3.8, -4.6), Vector3(s * 1.6, d0 + 5.4, -4.6), 0.18, 0.2, 8, CREAM)   # ventilators
		k.lathe("iron", Vector3(s * 1.6, d0 + 5.4, -4.6), [Vector2(0.2, 0.0), Vector2(0.42, 0.3), Vector2(0.38, 0.6), Vector2(0.0, 0.62)], 8, CREAM)
	# lifeboats in davits on the boat deck
	for s in [-1.0, 1.0]:
		k.bbox("hull", Vector3(s * 2.3, d0 + 4.5, -2.8), Vector3(1.2, 0.6, 4.2), 0.3, Color("e8e2d2"))
		k.box("base", Vector3(s * 2.3, d0 + 4.78, -2.8), Vector3(1.0, 0.04, 3.8), Color("3a4a3a"))
		for dz in [-4.6, -1.0]:
			k.tube("iron", [Vector3(s * 2.9, d0 + 4.1, dz), Vector3(s * 2.9, d0 + 5.4, dz), Vector3(s * 2.4, d0 + 5.6, dz)], 0.05, 4, Color("2a2a2a"))
	# masts with crosstrees, derrick booms swung out over the pier (local -x), rigging
	for mz in [7.4, -10.2]:
		var d: float = dfn.call(mz)
		var base := Vector3(0, d, mz)
		var top := base + Vector3(0, 15.0, 0)
		k.cyl("iron", base, top, 0.28, 0.14, 10, MAST)
		k.box("iron", base + Vector3(0, 11.0, 0), Vector3(3.2, 0.14, 0.2), MAST.darkened(0.2))
		k.box("glow", top + Vector3(0, 0.15, 0), Vector3(0.18, 0.28, 0.18), Color("fff0d0"))
		k.box("iron", base + Vector3(0, 1.2, 0), Vector3(1.4, 2.4, 1.4), Color("4a4640"))   # winch house
		var heel := base + Vector3(0, 2.6, mz * 0.0 + (-1.2 if mz > 0.0 else 1.2))
		var tip := Vector3(-7.4, d + 7.5, mz + (-2.0 if mz > 0.0 else 2.0))
		k.cyl("iron", heel, tip, 0.16, 0.1, 8, MAST.darkened(0.1))
		k.cyl("iron", top - Vector3(0, 1.0, 0), tip, 0.025, 0.025, 3, Color("222222"), false, false)
		var heel2 := base + Vector3(0, 2.6, (1.2 if mz > 0.0 else -1.2))
		k.cyl("iron", heel2, heel2 + Vector3(0.6, 8.0, (4.0 if mz > 0.0 else -4.0)), 0.14, 0.09, 8, MAST.darkened(0.1))   # the idle boom, topped up
		for s in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				k.cyl("iron", top - Vector3(0, 3.5, 0), Vector3(s * 3.9, d + 0.9, mz + sz * 1.5), 0.02, 0.02, 3, Color("262626"), false, false)
	# stays from bow to foremast to mainmast to stern
	k.cyl("iron", Vector3(0, 6.2, 21.5), Vector3(0, dfn.call(7.4) + 15.0, 7.4), 0.02, 0.02, 3, Color("262626"), false, false)
	k.cyl("iron", Vector3(0, dfn.call(7.4) + 14.5, 7.4), Vector3(0, dfn.call(-10.2) + 14.5, -10.2), 0.02, 0.02, 3, Color("262626"), false, false)
	k.cyl("iron", Vector3(0, dfn.call(-10.2) + 15.0, -10.2), Vector3(0, 5.8, -21.0), 0.02, 0.02, 3, Color("262626"), false, false)
	# anchors and hawse pipes at the bow, a stern flagstaff
	for s in [-1.0, 1.0]:
		k.box("base", Vector3(s * 2.5, 4.4, 17.4), Vector3(0.05, 0.6, 0.6), Color("0c0c0c"))
	k.cyl("iron", Vector3(0, 5.2, -21.6), Vector3(0, 8.0, -22.4), 0.04, 0.03, 4, MAST)
	# capstans and bitts on the forecastle
	for s in [-1.0, 1.0]:
		k.cyl("iron", Vector3(s * 1.3, dfn.call(18.0), 18.0), Vector3(s * 1.3, dfn.call(18.0) + 0.5, 18.0), 0.28, 0.24, 8, Color("2a2a2a"))
	var am := k.commit(_mats())
	_cache["freighter"] = am
	return am


# ------------------------------------------------------------------ the gantry crane

static func gantry() -> ArrayMesh:
	if _cache.has("gantry"):
		return _cache["gantry"]
	var k := MeshKit.new()
	var steel := Color("5a2e22")
	var dark := Color("2a2220")
	# portal: four legs on bogies straddling the quay rails
	for sx in [-2.5, 2.5]:
		for sz in [-2.6, 2.6]:
			k.box("iron", Vector3(sx, 0.35, sz), Vector3(0.7, 0.7, 1.4), dark)
			k.cyl("iron", Vector3(sx, 0.7, sz), Vector3(sx * 0.7, 7.2, sz * 0.7), 0.2, 0.16, 6, steel)
		k.cyl("iron", Vector3(sx, 0.9, -2.6), Vector3(sx * 0.7, 6.0, 1.8), 0.07, 0.07, 4, steel, false, false)
		k.cyl("iron", Vector3(sx, 0.9, 2.6), Vector3(sx * 0.7, 6.0, -1.8), 0.07, 0.07, 4, steel, false, false)
	for sz in [-1.85, 1.85]:
		k.box("iron", Vector3(0, 7.2, sz), Vector3(4.2, 0.5, 0.4), steel)
	for sx in [-1.75, 1.75]:
		k.box("iron", Vector3(sx, 7.2, 0), Vector3(0.4, 0.5, 4.1), steel)
	# the slewing machinery house with its cab, A-frame and counterweight
	k.cyl("iron", Vector3(0, 7.45, 0), Vector3(0, 7.8, 0), 1.6, 1.6, 12, dark)
	k.box("hull", Vector3(-0.6, 9.1, 0), Vector3(4.2, 2.6, 2.8), Color("4a4a44"))
	k.box("base", Vector3(-0.6, 10.45, 0), Vector3(4.4, 0.12, 3.0), Color("2a2622"))
	k.box("glow", Vector3(1.52, 9.4, 0.7), Vector3(0.02, 0.7, 0.9), Color("ffd9a0"))
	k.box("hull", Vector3(1.8, 8.9, 0.8), Vector3(0.9, 1.6, 1.0), Color("4a4a44"))
	k.box("iron", Vector3(-3.2, 8.5, 0), Vector3(1.2, 1.6, 2.4), Color("3a3a36"))   # counterweight
	for sz in [-1.1, 1.1]:
		k.cyl("iron", Vector3(-1.8, 10.5, sz), Vector3(-0.2, 14.5, sz * 0.3), 0.12, 0.1, 6, steel)
		k.cyl("iron", Vector3(1.0, 10.5, sz), Vector3(-0.2, 14.5, sz * 0.3), 0.12, 0.1, 6, steel)
	# the luffing jib, a lattice of two chords and diagonals, out over the water
	var j0 := Vector3(1.6, 8.6, 0)
	var j1 := Vector3(17.0, 15.5, 0)
	var n := 12
	for sz in [-0.6, 0.6]:
		k.cyl("iron", j0 + Vector3(0, 0, sz), j1 + Vector3(0, 0, sz * 0.4), 0.1, 0.07, 5, steel)
		k.cyl("iron", j0 + Vector3(0, 0.9, sz), j1 + Vector3(0, 0.2, sz * 0.4), 0.08, 0.06, 5, steel)
		for i in n:
			var a := j0.lerp(j1, float(i) / n) + Vector3(0, 0.9 * (1.0 - float(i) / n) + 0.2 * float(i) / n, sz * lerpf(1.0, 0.4, float(i) / n))
			var b := j0.lerp(j1, float(i + 1) / n) + Vector3(0, 0, sz * lerpf(1.0, 0.4, float(i + 1) / n))
			k.cyl("iron", a, b, 0.04, 0.04, 3, steel, false, false)
	k.cyl("iron", Vector3(-0.2, 14.5, 0), j1 + Vector3(0, 0.3, 0), 0.03, 0.03, 3, Color("222222"), false, false)
	# hook block and fall
	k.cyl("iron", j1, j1 - Vector3(0, 9.5, 0), 0.02, 0.02, 3, Color("222222"), false, false)
	k.box("iron", j1 - Vector3(0, 9.8, 0), Vector3(0.35, 0.5, 0.25), Color("c09a30"))
	var am := k.commit(_mats())
	_cache["gantry"] = am
	return am


# ------------------------------------------------------------------ the hiring hall

static func union_hall() -> ArrayMesh:
	if _cache.has("hall"):
		return _cache["hall"]
	var k := MeshKit.new()
	var w := 7.2
	var d := 5.2
	var clap := Color("7a8270")
	# clapboard walls: stacked boards with a shadow line
	var boards := 16
	for i in boards:
		var y0 := i * 0.225
		var col := clap.darkened(0.08 * float(i % 2))
		k.box("base", Vector3(0, y0 + 0.11, d * 0.5 - 0.01 * float(i % 2)), Vector3(w, 0.225, 0.04), col)
		k.box("base", Vector3(0, y0 + 0.11, -d * 0.5), Vector3(w, 0.225, 0.04), col)
		k.box("base", Vector3(w * 0.5, y0 + 0.11, 0), Vector3(0.04, 0.225, d), col)
		k.box("base", Vector3(-w * 0.5, y0 + 0.11, 0), Vector3(0.04, 0.225, d), col)
	k.box("base", Vector3(0, 1.8, 0), Vector3(w - 0.1, 3.6, d - 0.1), Color("3a342c"))
	for s in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			k.box("base", Vector3(s * w * 0.5, 1.8, z * d * 0.5), Vector3(0.14, 3.6, 0.14), Color("d8d0bc"))
	# the gable roof, tar paper, with a ridge along the length
	var rh := 1.5
	for s in [-1.0, 1.0]:
		var a := Vector3(-w * 0.5 - 0.3, 3.6, s * (d * 0.5 + 0.35))
		var b := Vector3(w * 0.5 + 0.3, 3.6, s * (d * 0.5 + 0.35))
		var c := Vector3(w * 0.5 + 0.3, 3.6 + rh, 0)
		var e := Vector3(-w * 0.5 - 0.3, 3.6 + rh, 0)
		k.face_auto("base", [a, b, c, e], Color("2c2826"), Vector3(0, 1, s))
		k.face_auto("base", [a - Vector3(0, 0.05, 0), b - Vector3(0, 0.05, 0), c - Vector3(0, 0.05, 0), e - Vector3(0, 0.05, 0)], Color("2c2826"), Vector3(0, -1, -s))
	for s in [-1.0, 1.0]:
		k.face_auto("base", [Vector3(s * w * 0.5, 3.6, -d * 0.5), Vector3(s * w * 0.5, 3.6, d * 0.5), Vector3(s * w * 0.5, 3.6 + rh * 0.95, 0)], clap, Vector3(s, 0, 0))
	# the door, windows, a notice board, the stovepipe, a lamp over the door, the sign board
	k.box("base", Vector3(0, 1.1, d * 0.5 + 0.03), Vector3(1.1, 2.2, 0.05), Color("3a2a1e"))
	k.box("base", Vector3(0, 2.3, d * 0.5 + 0.04), Vector3(1.3, 0.1, 0.06), Color("d8d0bc"))
	for s in [-1.0, 1.0]:
		k.box("glow", Vector3(s * 2.2, 1.7, d * 0.5 + 0.03), Vector3(1.1, 1.0, 0.03), Color("e0b070"))
		k.box("base", Vector3(s * 2.2, 1.7, d * 0.5 + 0.05), Vector3(0.05, 1.0, 0.03), Color("d8d0bc"))
		k.box("base", Vector3(s * 2.2, 1.7, d * 0.5 + 0.05), Vector3(1.1, 0.05, 0.03), Color("d8d0bc"))
		k.box("base", Vector3(s * 2.2, 1.14, d * 0.5 + 0.08), Vector3(1.3, 0.08, 0.12), Color("d8d0bc"))
	k.box("base", Vector3(3.0, 1.4, d * 0.5 + 0.05), Vector3(0.7, 0.9, 0.04), Color("5a4a36"))
	for i in 4:
		k.box("base", Vector3(2.85 + (i % 2) * 0.28, 1.2 + (i / 2) * 0.4, d * 0.5 + 0.075), Vector3(0.22, 0.3, 0.01), Color("e9dfc7"))
	k.box("base", Vector3(0, 3.25, d * 0.5 + 0.06), Vector3(5.2, 0.75, 0.06), Color("2b3a55"))
	k.cyl("iron", Vector3(-2.4, 4.0, -1.0), Vector3(-2.4, 5.8, -1.0), 0.12, 0.12, 8, Color("222222"))
	k.lathe("iron", Vector3(-2.4, 5.8, -1.0), [Vector2(0.0, 0.25), Vector2(0.3, 0.1), Vector2(0.28, 0.06)], 8, Color("222222"))
	k.lathe("glow", Vector3(0, 2.62, d * 0.5 + 0.35), [Vector2(0.0, -0.18), Vector2(0.14, -0.1), Vector2(0.14, 0.05), Vector2(0.0, 0.1)], 8, Color("ffe0b0"))
	k.box("iron", Vector3(0, 2.72, d * 0.5 + 0.18), Vector3(0.04, 0.04, 0.36), Color("222222"))
	# a bench by the door
	k.box("base", Vector3(-2.2, 0.45, d * 0.5 + 0.45), Vector3(1.8, 0.08, 0.4), Color("5a4a36"))
	for s in [-0.8, 0.8]:
		k.box("base", Vector3(-2.2 + s, 0.22, d * 0.5 + 0.45), Vector3(0.08, 0.44, 0.36), Color("4a3a2a"))
	var am := k.commit(_mats())
	_cache["hall"] = am
	return am


# ------------------------------------------------------------------ the rum-runner

## A Node3D ready for World: the hull along local z, deck about 1.1 m above its origin, a
## masthead lantern (OmniLight3D) left for the caller to keep.
static func rum_runner() -> Node3D:
	var root := Node3D.new()
	var k := MeshKit.new()
	var L := 6.4
	var B := 1.6
	var bfn := func(z: float) -> float:
		var t := z / L
		if t > 0.35:
			return B * maxf(0.0, 1.0 - pow((t - 0.35) / 0.65, 1.6))
		if t < -0.9:
			return B * 0.86
		return B * (0.92 + 0.08 * (1.0 - absf(t)))
	var dfn := func(z: float) -> float:
		var t := z / L
		return 1.05 + 0.35 * maxf(t, 0.0) * maxf(t, 0.0) * 2.0
	_hull(k, -L, L, 26, bfn, dfn, -1.0, [[-1.0, 0.05, Color("5a2420")], [0.05, 0.12, Color("d8d0bc")], [0.12, 99.0, Color("5a5e60")]], Color("6a3a22"), 0.12, Color("6a3a22"))
	# varnished mahogany foredeck planking lines
	for i in 7:
		var x := -1.2 + i * 0.4
		k.box("base", Vector3(x, dfn.call(3.0) + 0.012, 3.0), Vector3(0.015, 0.01, 6.0), Color("3a1e10"))
	# the deckhouse with a raked windscreen, cockpit coaming, engine hatch
	k.bbox("hull", Vector3(0, 1.55, 0.6), Vector3(2.2, 0.9, 3.0), 0.12, Color("6e3a1e"))
	k.box("base", Vector3(0, 2.02, 0.6), Vector3(2.3, 0.06, 3.1), Color("d8d0bc"))
	k.box("glow", Vector3(0, 1.62, 2.12), Vector3(1.9, 0.45, 0.03), Color("403830"))
	for s in [-1.0, 1.0]:
		for pz in 3:
			k.box("glow", Vector3(s * 1.11, 1.62, -0.3 + pz * 0.8), Vector3(0.02, 0.3, 0.4), Color("5a4a38"))
	k.box("base", Vector3(0, 1.3, -3.4), Vector3(2.5, 0.25, 4.6), Color("3a2418"))
	# cargo: burlap "hams" of bottles and crates stowed in the open cockpit
	for i in 4:
		for j in 3:
			var p := Vector3(-0.8 + j * 0.8, 1.35, -1.6 - i * 0.9)
			if (i + j) % 3 == 0:
				k.box("base", p + Vector3(0, 0.22, 0), Vector3(0.7, 0.44, 0.55), Color("8a6a45"))
			else:
				k.bbox("base", p + Vector3(0, 0.2, 0), Vector3(0.6, 0.4, 0.6), 0.16, Color("a8946c"))
				k.bbox("base", p + Vector3(0.05, 0.55, 0.05), Vector3(0.5, 0.35, 0.5), 0.14, Color("9a865e"))
	k.box("base", Vector3(0.0, 1.8, -5.6), Vector3(0.2, 0.6, 0.2), Color("222222"))   # exhaust stack
	k.cyl("iron", Vector3(0, 2.05, 1.8), Vector3(0, 4.2, 1.8), 0.05, 0.035, 6, Color("2a2a2a"))
	for s in [-1.0, 1.0]:
		k.cyl("iron", Vector3(s * 1.45, 1.2, 4.5), Vector3(s * 1.3, 1.45, 2.6), 0.02, 0.02, 3, Color("b0a890"), false, false)
	# tyre fenders hung over the pier side
	for z in [-3.0, 0.0, 3.0]:
		k.lathe("base", Vector3(1.62, 0.6, z), [Vector2(0.12, -0.08), Vector2(0.2, -0.06), Vector2(0.2, 0.06), Vector2(0.12, 0.08)], 8, Color("1a1a1a"), Basis(Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)))
	var mi := MeshInstance3D.new()
	mi.mesh = k.commit(_mats())
	root.add_child(mi)
	var lantern := OmniLight3D.new()
	lantern.name = "Lantern"
	lantern.light_color = Color("ffb060")
	lantern.omni_range = 9.0
	lantern.light_energy = 1.6
	lantern.position = Vector3(0, 4.3, 1.8)
	root.add_child(lantern)
	var lamp := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.12
	sm.height = 0.24
	lamp.mesh = sm
	var lm := StandardMaterial3D.new()
	lm.albedo_color = Color("ffd090")
	lm.emission_enabled = true
	lm.emission = Color("ffb060")
	lm.emission_energy_multiplier = 3.0
	lamp.material_override = lm
	lamp.position = lantern.position
	root.add_child(lamp)
	return root
