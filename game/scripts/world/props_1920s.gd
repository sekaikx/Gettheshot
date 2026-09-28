class_name Props1920s
extends RefCounted
## Street furniture and dock clutter of 1920s New York, modelled in code (metres, y up, the
## prop's front or "out over the street" direction is +z). Each mesh is built once and shared;
## the city places them with MultiMesh. Surfaces are named "base" (vertex colours, matte),
## "iron" (vertex colours, a little metallic) and "glow" (lamp glass, emissive at night).

const IRON := Color("25282b")
const GREEN := Color("2f4a38")
const OXBLOOD := Color("7a2620")
const WOOD := Color("7a5a3a")
const OLD_WOOD := Color("5e4a36")
const BRASS := Color("b08d57")
const STONE := Color("8d877c")
const BROWNSTONE := Color("6a4a3a")
const GALV := Color("8e918d")
const CANVAS := Color("cfc3a5")

static var _cache := {}
static var base_mat: ShaderMaterial
static var iron_mat: ShaderMaterial
static var glow_mat: ShaderMaterial


static func _cut_mat(rough: float, metal: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://scripts/world/prop_cut.gdshader")
	m.set_shader_parameter("rough", rough)
	m.set_shader_parameter("metal", metal)
	return m


## The three shared prop materials (cut-away aware: keep their focus / cam_pos updated).
static func materials() -> Array[ShaderMaterial]:
	if base_mat == null:
		base_mat = _cut_mat(0.85, 0.0)
		iron_mat = _cut_mat(0.45, 0.45)
		glow_mat = _cut_mat(0.2, 0.0)
		glow_mat.set_shader_parameter("glow", Vector3(0.3, 0.3, 0.3))
	return [base_mat, iron_mat, glow_mat]


static func set_night(v: float, wet: float) -> void:
	materials()
	var on := clampf((v - 0.25) / 0.4, 0.0, 1.0)
	glow_mat.set_shader_parameter("glow", Vector3.ONE * (0.25 + on * 3.2))
	base_mat.set_shader_parameter("wet", wet)
	iron_mat.set_shader_parameter("wet", wet)


static func _mk(key: String, build: Callable) -> ArrayMesh:
	if not _cache.has(key):
		materials()
		var k := MeshKit.new()
		build.call(k)
		_cache[key] = k.commit({"base": base_mat, "iron": iron_mat, "glow": glow_mat})
	return _cache[key]


# ------------------------------------------------------------------ street furniture

## The cast-iron bishop's crook lamp post. The lantern hangs at lamp_head() (local).
static func lamp_post() -> ArrayMesh:
	return _mk("lamp", func(k: MeshKit) -> void:
		k.lathe("iron", Vector3.ZERO, [Vector2(0.2, 0.0), Vector2(0.2, 0.1), Vector2(0.16, 0.14), Vector2(0.16, 0.42),
			Vector2(0.18, 0.46), Vector2(0.13, 0.52), Vector2(0.11, 0.62), Vector2(0.085, 0.72), Vector2(0.08, 0.9),
			Vector2(0.095, 0.95), Vector2(0.07, 1.0), Vector2(0.06, 3.3), Vector2(0.085, 3.36), Vector2(0.085, 3.44),
			Vector2(0.055, 3.5), Vector2(0.05, 4.0), Vector2(0.0, 4.02)], 8, IRON)
		# the crook: up, over and down, like a shepherd's staff
		var pts: Array = [Vector3(0, 3.9, 0)]
		for s in 11:
			var a := PI - PI * s / 10.0
			pts.append(Vector3(0, 4.12 + sin(a) * 0.36, 0.36 + cos(a) * 0.36))
		pts.append(Vector3(0, 4.02, 0.72))
		k.tube("iron", pts, 0.035, 6, IRON)
		# the scroll bracket under the arm
		var sc: Array = []
		for s in 13:
			var t := s / 12.0
			var a := t * PI * 1.6
			sc.append(Vector3(0, 3.72 + t * 0.38 + sin(a) * 0.05, 0.04 + t * 0.34 + cos(a) * 0.05 - 0.05))
		k.tube("iron", sc, 0.014, 4, IRON)
		k.lathe("iron", Vector3(0, 3.62, 0.72), [Vector2(0.0, 0.42), Vector2(0.04, 0.4), Vector2(0.17, 0.3), Vector2(0.17, 0.27),
			Vector2(0.13, 0.26)], 8, IRON)
		k.lathe("glow", Vector3(0, 3.62, 0.72), [Vector2(0.13, 0.26), Vector2(0.15, 0.18), Vector2(0.14, 0.05),
			Vector2(0.09, -0.04), Vector2(0.0, -0.07)], 8, Color("fff0d0"))
		k.lathe("iron", Vector3(0, 3.62, 0.72), [Vector2(0.02, -0.06), Vector2(0.025, -0.12), Vector2(0.0, -0.16)], 6, IRON))


static func lamp_head() -> Vector3:
	return Vector3(0, 3.72, 0.72)


static func hydrant() -> ArrayMesh:
	return _mk("hydrant", func(k: MeshKit) -> void:
		k.lathe("iron", Vector3.ZERO, [Vector2(0.17, 0.0), Vector2(0.17, 0.05), Vector2(0.12, 0.08), Vector2(0.105, 0.14),
			Vector2(0.1, 0.46), Vector2(0.125, 0.48), Vector2(0.125, 0.53), Vector2(0.1, 0.56), Vector2(0.08, 0.63),
			Vector2(0.04, 0.68), Vector2(0.0, 0.69)], 10, OXBLOOD)
		k.cyl("iron", Vector3(0, 0.68, 0), Vector3(0, 0.74, 0), 0.03, 0.02, 5, IRON)
		for s in [1.0, -1.0]:
			k.cyl("iron", Vector3(s * 0.08, 0.38, 0), Vector3(s * 0.17, 0.38, 0), 0.045, 0.045, 8, OXBLOOD)
			k.cyl("iron", Vector3(s * 0.17, 0.38, 0), Vector3(s * 0.2, 0.38, 0), 0.05, 0.035, 6, IRON)
		k.cyl("iron", Vector3(0, 0.3, 0.08), Vector3(0, 0.3, 0.19), 0.065, 0.065, 8, OXBLOOD)
		k.cyl("iron", Vector3(0, 0.3, 0.19), Vector3(0, 0.3, 0.23), 0.07, 0.05, 6, IRON))


## The olive-drab letter box on its pedestal.
static func mailbox() -> ArrayMesh:
	return _mk("mailbox", func(k: MeshKit) -> void:
		var col := Color("3f4a33")
		k.cyl("iron", Vector3(0, 0, 0), Vector3(0, 0.62, 0), 0.07, 0.06, 8, col)
		k.box("iron", Vector3(0, 0.03, 0), Vector3(0.3, 0.06, 0.3), col)
		var prof := PackedVector2Array([Vector2(-0.19, 0.62), Vector2(0.19, 0.62), Vector2(0.19, 1.02)])
		for s in 7:
			var a := float(s) / 6.0 * PI
			prof.append(Vector2(cos(a) * 0.19, 1.02 + sin(a) * 0.12))
		prof.append(Vector2(-0.19, 1.02))
		k.extrude_x("iron", prof, -0.22, 0.22, col)
		k.box("base", Vector3(0, 1.0, 0.195), Vector3(0.28, 0.035, 0.01), Color("111111"))   # the slot
		k.box("base", Vector3(0, 0.82, 0.193), Vector3(0.22, 0.1, 0.006), BRASS))


## Galvanised ash can with a lid, dented a little.
static func ash_can() -> ArrayMesh:
	return _mk("ashcan", func(k: MeshKit) -> void:
		k.lathe("iron", Vector3.ZERO, [Vector2(0.2, 0.0), Vector2(0.22, 0.02), Vector2(0.22, 0.1), Vector2(0.235, 0.12),
			Vector2(0.225, 0.14), Vector2(0.235, 0.36), Vector2(0.245, 0.38), Vector2(0.235, 0.4), Vector2(0.245, 0.62),
			Vector2(0.26, 0.64), Vector2(0.24, 0.66), Vector2(0.18, 0.69), Vector2(0.03, 0.7), Vector2(0.0, 0.7)], 12, GALV)
		k.box("iron", Vector3(0, 0.73, 0), Vector3(0.16, 0.03, 0.03), IRON)
		for s in [1.0, -1.0]:
			k.box("iron", Vector3(s * 0.25, 0.55, 0), Vector3(0.03, 0.03, 0.12), IRON))


## Fire-alarm telegraph post: red column, the call box, a red globe on top.
static func call_box() -> ArrayMesh:
	return _mk("callbox", func(k: MeshKit) -> void:
		k.lathe("iron", Vector3.ZERO, [Vector2(0.15, 0.0), Vector2(0.15, 0.08), Vector2(0.1, 0.14), Vector2(0.075, 0.3),
			Vector2(0.06, 2.3), Vector2(0.08, 2.34), Vector2(0.08, 2.4)], 8, Color("8a2018"))
		k.bbox("iron", Vector3(0, 1.3, 0.04), Vector3(0.3, 0.42, 0.2), 0.03, Color("8a2018"))
		k.box("base", Vector3(0, 1.36, 0.145), Vector3(0.22, 0.05, 0.01), Color("e0d6b8"))
		k.box("base", Vector3(0, 1.2, 0.145), Vector3(0.08, 0.1, 0.01), BRASS)
		k.lathe("glow", Vector3(0, 2.4, 0), [Vector2(0.08, 0.0), Vector2(0.12, 0.1), Vector2(0.1, 0.24), Vector2(0.0, 0.28)], 8, Color("ff3a28"))
		k.lathe("iron", Vector3(0, 2.66, 0), [Vector2(0.04, 0.0), Vector2(0.0, 0.1)], 6, IRON))


## A wooden newsstand: counter of papers, magazines on the back wall, a sloped roof.
static func newsstand() -> ArrayMesh:
	return _mk("newsstand", func(k: MeshKit) -> void:
		k.box("base", Vector3(0, 0.45, -0.1), Vector3(1.9, 0.9, 0.8), GREEN)
		k.box("base", Vector3(0, 1.3, -0.45), Vector3(1.9, 1.7, 0.1), GREEN)
		for s in [1.0, -1.0]:
			k.box("base", Vector3(s * 0.93, 1.3, -0.1), Vector3(0.05, 1.7, 0.8), GREEN.darkened(0.1))
		# roof, overhanging the front
		k.box("base", Vector3(0, 2.2, 0.05), Vector3(2.1, 0.08, 1.35), Color("2a2622"), Basis(Vector3.RIGHT, 0.18))
		k.box("base", Vector3(0, 2.1, 0.7), Vector3(2.1, 0.22, 0.04), Color("8b1e1a"))
		# the sloped rack of papers on the counter: stacks with a headline band
		var rack := Basis(Vector3.RIGHT, -0.35)
		for c in 5:
			var x := -0.72 + c * 0.36
			var paper: Color = [Color("e4dcc6"), Color("d9d0b5"), Color("e9e2cf"), Color("ded2b0"), Color("e4dcc6")][c]
			k.box("base", Vector3(x, 0.95, 0.05), Vector3(0.3, 0.06, 0.4), paper, rack)
			k.box("base", Vector3(x, 0.99, 0.12), Vector3(0.26, 0.004, 0.05), Color("1e140a"), rack)
			k.box("base", Vector3(x, 0.99, 0.02), Vector3(0.2, 0.004, 0.02), Color("5a5048"), rack)
		# magazines pinned on the back wall
		var covers := [Color("b8402c"), Color("d9b04a"), Color("2b3a55"), Color("e9dfc7"), Color("6a8a5a"), Color("8b1e1a"), Color("c9a05a"), Color("3a5a7a")]
		for r in 2:
			for c in 4:
				k.box("base", Vector3(-0.6 + c * 0.4, 1.35 + r * 0.42, -0.39), Vector3(0.28, 0.36, 0.01), covers[(r * 4 + c) % covers.size()])
		k.box("base", Vector3(0, 0.92, 0.3), Vector3(1.9, 0.04, 0.02), Color("1f2f24")))


## A pushcart: two big wheels, a sloped bed of produce or goods, handles; variant 1 has an umbrella.
static func pushcart(variant: int) -> ArrayMesh:
	return _mk("cart%d" % variant, func(k: MeshKit) -> void:
		var ax := Basis(Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1))
		for s in [1.0, -1.0]:
			k.lathe("base", Vector3(s * 0.52, 0.45, -0.3), [Vector2(0.45, -0.03), Vector2(0.45, 0.03), Vector2(0.41, 0.03), Vector2(0.41, -0.03), Vector2(0.45, -0.03)], 14, OLD_WOOD, ax)
			for sp in 8:
				var a := TAU * sp / 8.0
				k.box("base", Vector3(s * 0.52, 0.45 + sin(a) * 0.21, -0.3 + cos(a) * 0.21), Vector3(0.03, 0.03, 0.42), OLD_WOOD, Basis(Vector3.RIGHT, -a))
			k.box("base", Vector3(s * 0.36, 0.8, 1.25), Vector3(0.05, 0.05, 1.0), OLD_WOOD)   # handles
		k.cyl("iron", Vector3(-0.55, 0.45, -0.3), Vector3(0.55, 0.45, -0.3), 0.025, 0.025, 5, IRON)
		k.box("base", Vector3(0, 0.78, 0.0), Vector3(0.86, 0.1, 1.7), WOOD)
		for s in [1.0, -1.0]:
			k.box("base", Vector3(s * 0.43, 0.9, 0.0), Vector3(0.04, 0.2, 1.7), OLD_WOOD)
		k.box("base", Vector3(0, 0.9, 0.85), Vector3(0.86, 0.2, 0.04), OLD_WOOD)
		k.box("base", Vector3(0, 0.9, -0.85), Vector3(0.86, 0.2, 0.04), OLD_WOOD)
		k.box("base", Vector3(0, 0.4, 0.6), Vector3(0.04, 0.8, 0.04), OLD_WOOD)   # the prop leg
		# produce heaps in baskets: apples, lemons, greens, potatoes, onions
		var goods: Array = [[Color("a8321f"), Color("c9a326"), Color("5d7d3a"), Color("8a6a44"), Color("c8a877"), Color("b8502a")],
			[Color("d0c7b0"), Color("9a3a30"), Color("2b3a55"), Color("c9b88f"), Color("6a4a3a"), Color("e0d8c0")]][variant % 2]
		for r in 3:
			for c in 2:
				var g: Color = goods[(r * 2 + c + variant) % goods.size()]
				var cz := -0.55 + r * 0.55
				var cx := -0.2 + c * 0.4
				k.bbox("base", Vector3(cx, 0.93, cz), Vector3(0.36, 0.14, 0.48), 0.05, g.darkened(0.25))
				for b in 5:
					var o := Vector3((b % 3 - 1) * 0.1, 0.0, (b / 3 - 0.5) * 0.18)
					k.bbox("base", Vector3(cx, 1.02, cz) + o, Vector3(0.12, 0.08, 0.12), 0.04, g)
		if variant == 1:
			k.cyl("iron", Vector3(0.3, 0.8, -0.6), Vector3(0.3, 2.3, -0.6), 0.02, 0.02, 4, IRON)
			var top := Vector3(0.3, 2.45, -0.6)
			for s in 10:
				var a0 := TAU * s / 10.0
				var a1 := TAU * (s + 1) / 10.0
				var col := Color("cfc3a2") if s % 2 == 0 else Color("7a2a22")
				var rr := 0.8
				k.face("base", [top, top + Vector3(cos(a0) * rr, -0.34, sin(a0) * rr), top + Vector3(cos(a1) * rr, -0.34, sin(a1) * rr)], col, Vector3.UP)
				k.face("base", [top - Vector3(0, 0.02, 0), top + Vector3(cos(a1) * rr, -0.36, sin(a1) * rr), top + Vector3(cos(a0) * rr, -0.36, sin(a0) * rr)], col.darkened(0.3), Vector3.DOWN))


static func horse_trough() -> ArrayMesh:
	return _mk("trough", func(k: MeshKit) -> void:
		var g := Color("6e6a62")
		k.box("base", Vector3(0, 0.3, 0.3), Vector3(2.2, 0.6, 0.1), g)
		k.box("base", Vector3(0, 0.3, -0.3), Vector3(2.2, 0.6, 0.1), g)
		k.box("base", Vector3(1.05, 0.3, 0), Vector3(0.1, 0.6, 0.7), g)
		k.box("base", Vector3(-1.05, 0.3, 0), Vector3(0.1, 0.6, 0.7), g)
		k.box("base", Vector3(0, 0.1, 0), Vector3(2.0, 0.2, 0.5), g.darkened(0.2))
		k.box("iron", Vector3(0, 0.5, 0), Vector3(2.0, 0.02, 0.5), Color("2a3638"))   # water
		k.box("base", Vector3(0, 0.62, 0), Vector3(2.3, 0.05, 0.78), g.lightened(0.08)))


static func manhole() -> ArrayMesh:
	return _mk("manhole", func(k: MeshKit) -> void:
		var rings := [0.37, 0.33, 0.27, 0.2, 0.13, 0.06]
		for i in rings.size():
			var r0: float = rings[i]
			var r1: float = rings[i + 1] if i + 1 < rings.size() else 0.0
			var col := Color("2e2c29") if i % 2 == 0 else Color("3c3935")
			k.lathe("iron", Vector3.ZERO, [Vector2(r0, 0.012), Vector2(r1, 0.012)], 14, col)
		k.lathe("iron", Vector3.ZERO, [Vector2(0.37, 0.0), Vector2(0.37, 0.012)], 14, Color("2a2826")))


static func bollard() -> ArrayMesh:
	return _mk("bollard", func(k: MeshKit) -> void:
		k.lathe("iron", Vector3.ZERO, [Vector2(0.17, 0.0), Vector2(0.17, 0.05), Vector2(0.12, 0.1), Vector2(0.11, 0.42),
			Vector2(0.16, 0.48), Vector2(0.17, 0.54), Vector2(0.12, 0.6), Vector2(0.0, 0.62)], 10, Color("1e1f20")))


## Brownstone stoop: five steps up to a tenement door, iron rails either side. Front = +z.
static func stoop() -> ArrayMesh:
	return _mk("stoop", func(k: MeshKit) -> void:
		for s in 5:
			var d := 1.5 - s * 0.26
			k.box("base", Vector3(0, 0.08 + s * 0.16, -d * 0.5 + 0.0), Vector3(1.7, 0.16, d), BROWNSTONE.lightened(0.05 * (s % 2)))
		for sx in [1.0, -1.0]:
			k.box("base", Vector3(sx * 0.92, 0.45, -0.72), Vector3(0.16, 0.9, 1.5), BROWNSTONE.darkened(0.12))
			var pts: Array = [Vector3(sx * 0.92, 1.0, 0.05), Vector3(sx * 0.92, 1.72, -1.4)]
			k.tube("iron", pts, 0.02, 4, IRON)
			for p in 5:
				var t := p / 4.0
				k.cyl("iron", Vector3(sx * 0.92, 0.9 + t * 0.0 + t * 0.0, lerpf(0.02, -1.35, t)), Vector3(sx * 0.92, lerpf(1.0, 1.72, t), lerpf(0.05, -1.4, t)), 0.012, 0.012, 3, IRON, false, false)
			k.lathe("iron", Vector3(sx * 0.92, 0.9, 0.05), [Vector2(0.04, 0.0), Vector2(0.04, 0.25), Vector2(0.0, 0.32)], 6, IRON))


## Sloping steel cellar doors on the sidewalk against a shop front. Front = +z (towards the kerb).
static func cellar_doors() -> ArrayMesh:
	return _mk("cellar", func(k: MeshKit) -> void:
		var b := Basis(Vector3.RIGHT, 0.32)
		k.box("base", Vector3(0, 0.12, 0.0), Vector3(1.3, 0.26, 1.1), Color("5a5550"))
		for s in [1.0, -1.0]:
			k.box("iron", Vector3(s * 0.32, 0.28, 0.0), Vector3(0.6, 0.03, 1.12), Color("3a3d3a"), b)
			for r in 4:
				k.box("iron", Vector3(s * 0.32, 0.3 + 0.0, -0.4 + r * 0.27), Vector3(0.58, 0.012, 0.03), Color("2c2e2c"), b)
		k.box("iron", Vector3(0.05, 0.36, 0.1), Vector3(0.04, 0.02, 0.1), BRASS))


# ------------------------------------------------------------------ buildings

## One storey of an iron fire escape (platform, railing, the stair down to the storey below)
## for a front `w` metres wide. Origin = platform centre against the wall; +z = out.
## `stair_dir` +1 / -1 picks which way the stair runs; `drop` hangs the drop ladder instead.
static func fire_escape(w: float, stair_dir: int, drop: bool) -> ArrayMesh:
	return _mk("fe_%.1f_%d_%s" % [w, stair_dir, drop], func(k: MeshKit) -> void:
		var d := 1.05
		var col := Color("1c1d1e")
		# grating platform with a slatted look
		k.box("iron", Vector3(0, 0.0, d * 0.5), Vector3(w, 0.04, d), col)
		for g in int(w / 0.12):
			k.box("iron", Vector3(-w * 0.5 + 0.06 + g * 0.12, 0.024, d * 0.5), Vector3(0.02, 0.01, d), Color("2c2d2e"))
		# railing: top rail, a middle rail, balusters
		for side in [[Vector3(-w * 0.5, 0, d), Vector3(w * 0.5, 0, d)], [Vector3(-w * 0.5, 0, 0.02), Vector3(-w * 0.5, 0, d)], [Vector3(w * 0.5, 0, 0.02), Vector3(w * 0.5, 0, d)]]:
			var a: Vector3 = side[0]
			var b: Vector3 = side[1]
			for yy in [0.95, 0.5]:
				k.cyl("iron", a + Vector3(0, yy, 0), b + Vector3(0, yy, 0), 0.018, 0.018, 4, col, false, false)
			var n := int(a.distance_to(b) / 0.14)
			for i in n + 1:
				var p := a.lerp(b, float(i) / maxf(n, 1))
				k.box("iron", p + Vector3(0, 0.475, 0), Vector3(0.014, 0.95, 0.014), col)
		if drop:
			# the counterweighted drop ladder, hauled up
			var x := stair_dir * (w * 0.5 - 0.45)
			for s in [-0.2, 0.2]:
				k.box("iron", Vector3(x + s, -1.1, d - 0.12), Vector3(0.03, 2.2, 0.03), col)
			for r in 9:
				k.box("iron", Vector3(x, -0.1 - r * 0.25, d - 0.12), Vector3(0.4, 0.02, 0.02), col)
		else:
			# the stair from this platform down to the next, inside the railing
			var fh := 3.2
			var x0 := -stair_dir * (w * 0.5 - 0.35)
			var x1 := stair_dir * (w * 0.5 - 0.5)
			var z := 0.45
			for s in [-0.28, 0.28]:
				k.cyl("iron", Vector3(x0, 0.0, z + s), Vector3(x1, -fh, z + s), 0.03, 0.03, 4, col, false, false)
				k.cyl("iron", Vector3(x0, 0.9, z + s), Vector3(x1, -fh + 0.9, z + s), 0.015, 0.015, 4, col, false, false)
			var steps := 14
			for st in steps:
				var t := (st + 0.5) / steps
				k.box("iron", Vector3(lerpf(x0, x1, t), -fh * t, z), Vector3(0.16, 0.02, 0.56), Color("2a2b2c"))
		# brackets into the wall
		for s in [-1.0, 1.0]:
			k.cyl("iron", Vector3(s * w * 0.4, -0.5, 0.02), Vector3(s * w * 0.4, 0.0, d * 0.9), 0.02, 0.02, 4, col, false, false))


static func water_tower() -> ArrayMesh:
	return _mk("watertower", func(k: MeshKit) -> void:
		var steel := Color("2a2b2c")
		# steel stand: legs, girders, a timber platform
		for i in 4:
			var a := i * PI * 0.5 + PI * 0.25
			var o := Vector3(cos(a), 0, sin(a)) * 1.25
			k.box("iron", o + Vector3(0, 1.3, 0), Vector3(0.16, 2.6, 0.16), steel)
			var a2 := (i + 1) * PI * 0.5 + PI * 0.25
			var o2 := Vector3(cos(a2), 0, sin(a2)) * 1.25
			k.cyl("iron", o + Vector3(0, 0.2, 0), o2 + Vector3(0, 2.4, 0), 0.03, 0.03, 4, steel, false, false)
			k.cyl("iron", o2 + Vector3(0, 0.2, 0), o + Vector3(0, 2.4, 0), 0.03, 0.03, 4, steel, false, false)
		k.box("base", Vector3(0, 2.65, 0), Vector3(2.9, 0.12, 2.9), Color("4a3a2c"))
		# the tank: cedar staves (alternating tones), steel hoops, a conical roof
		var segs := 18
		for s in segs:
			var a0 := TAU * s / segs
			var a1 := TAU * (s + 1) / segs
			var col := Color("7a5c3e").lerp(Color("5e4630"), float((s * 7) % 5) / 5.0)
			var r0 := 1.5
			var r1 := 1.44
			var p := [Vector3(cos(a0) * r0, 2.7, sin(a0) * r0), Vector3(cos(a1) * r0, 2.7, sin(a1) * r0),
				Vector3(cos(a1) * r1, 5.6, sin(a1) * r1), Vector3(cos(a0) * r1, 5.6, sin(a0) * r1)]
			var n := Vector3(cos((a0 + a1) * 0.5), 0.02, sin((a0 + a1) * 0.5))
			k.face("base", p, col, n)
		for h in [3.0, 3.6, 4.2, 4.8, 5.35]:
			k.lathe("iron", Vector3(0, h, 0), [Vector2(1.515 - (h - 2.7) * 0.02, 0.0), Vector2(1.515 - (h - 2.7) * 0.02, 0.05)], 18, steel)
		k.lathe("base", Vector3(0, 5.55, 0), [Vector2(1.62, 0.0), Vector2(1.58, 0.08), Vector2(0.1, 1.0), Vector2(0.0, 1.02)], 18, Color("2c2826"))
		k.lathe("iron", Vector3(0, 6.55, 0), [Vector2(0.05, 0.0), Vector2(0.03, 0.25), Vector2(0.0, 0.3)], 6, steel)
		# the ladder up the side
		for s in [-0.18, 0.18]:
			k.box("iron", Vector3(1.56, 4.1, s), Vector3(0.03, 3.0, 0.03), steel)
		for r in 11:
			k.box("iron", Vector3(1.56, 2.8 + r * 0.26, 0), Vector3(0.02, 0.02, 0.36), steel))


static func chimney() -> ArrayMesh:
	return _mk("chimney", func(k: MeshKit) -> void:
		var brick := Color("6e3a2a")
		k.box("base", Vector3(0, 0.7, 0), Vector3(0.8, 1.4, 0.6), brick)
		k.box("base", Vector3(0, 1.45, 0), Vector3(0.92, 0.1, 0.72), Color("8a8074"))
		for s in [-0.18, 0.18]:
			k.cyl("base", Vector3(s, 1.5, 0), Vector3(s, 1.78, 0), 0.1, 0.08, 8, Color("a0603a"))
			k.cyl("base", Vector3(s, 1.779, 0), Vector3(s, 1.78, 0), 0.07, 0.0, 8, Color("151210")))


## Stair bulkhead: the little brick hut over the roof stairs with a door.
static func bulkhead() -> ArrayMesh:
	return _mk("bulkhead", func(k: MeshKit) -> void:
		k.box("base", Vector3(0, 1.1, 0), Vector3(2.2, 2.2, 2.6), Color("6a4d40"))
		k.box("base", Vector3(0, 2.25, 0), Vector3(2.4, 0.1, 2.8), Color("2e2a27"))
		k.box("base", Vector3(0, 0.95, 1.305), Vector3(0.8, 1.9, 0.02), Color("3a2c22"))
		k.box("iron", Vector3(0.28, 0.95, 1.32), Vector3(0.05, 0.05, 0.02), BRASS))


## A glass skylight: a low hipped frame of panes.
static func skylight() -> ArrayMesh:
	return _mk("skylight", func(k: MeshKit) -> void:
		k.box("base", Vector3(0, 0.2, 0), Vector3(1.6, 0.4, 1.2), Color("5a534c"))
		var g := Color("7d9098")
		k.face("iron", [Vector3(-0.8, 0.4, 0.6), Vector3(0.8, 0.4, 0.6), Vector3(0.6, 0.8, 0), Vector3(-0.6, 0.8, 0)], g, Vector3(0, 1, 1))
		k.face("iron", [Vector3(0.8, 0.4, -0.6), Vector3(-0.8, 0.4, -0.6), Vector3(-0.6, 0.8, 0), Vector3(0.6, 0.8, 0)], g.darkened(0.15), Vector3(0, 1, -1))
		k.face("iron", [Vector3(0.8, 0.4, 0.6), Vector3(0.8, 0.4, -0.6), Vector3(0.6, 0.8, 0)], g, Vector3(1, 1, 0))
		k.face("iron", [Vector3(-0.8, 0.4, -0.6), Vector3(-0.8, 0.4, 0.6), Vector3(-0.6, 0.8, 0)], g, Vector3(-1, 1, 0))
		for i in 5:
			var x := -0.6 + i * 0.3
			k.box("base", Vector3(x, 0.61, 0.3), Vector3(0.03, 0.03, 0.66), Color("2a2622"), Basis(Vector3.RIGHT, -0.59))
			k.box("base", Vector3(x, 0.61, -0.3), Vector3(0.03, 0.03, 0.66), Color("2a2622"), Basis(Vector3.RIGHT, 0.59)))


static func vent() -> ArrayMesh:
	return _mk("vent", func(k: MeshKit) -> void:
		k.cyl("iron", Vector3.ZERO, Vector3(0, 0.9, 0), 0.12, 0.12, 8, GALV)
		k.lathe("iron", Vector3(0, 0.9, 0), [Vector2(0.12, 0.0), Vector2(0.26, 0.12), Vector2(0.2, 0.2), Vector2(0.0, 0.3)], 8, GALV.darkened(0.2)))


## A roof-top pigeon coop on legs (the Lower East Side's pastime).
static func pigeon_coop() -> ArrayMesh:
	return _mk("coop", func(k: MeshKit) -> void:
		for s in [Vector3(-0.8, 0, -0.5), Vector3(0.8, 0, -0.5), Vector3(-0.8, 0, 0.5), Vector3(0.8, 0, 0.5)]:
			k.box("base", s + Vector3(0, 0.3, 0), Vector3(0.08, 0.6, 0.08), OLD_WOOD)
		k.box("base", Vector3(0, 1.0, 0), Vector3(1.8, 0.8, 1.2), Color("8a7a60"))
		k.box("base", Vector3(0, 1.0, 0.605), Vector3(1.6, 0.6, 0.01), Color("3a3430"))
		k.box("base", Vector3(0, 1.45, 0), Vector3(2.0, 0.08, 1.4), Color("2e2a27"), Basis(Vector3.RIGHT, 0.12)))


# ------------------------------------------------------------------ docks

## A wooden shipping crate with battens (about 1 m), standing on its base.
static func crate(tone: int) -> ArrayMesh:
	return _mk("crate%d" % tone, func(k: MeshKit) -> void:
		var c: Color = [Color("8a6a45"), Color("9a7a52"), Color("6e5438")][tone % 3]
		var s := Vector3(1.0, 0.8, 0.8)
		k.box("base", Vector3(0, s.y * 0.5, 0), s, c)
		var bt := c.darkened(0.25)
		for ax in [Vector3(1, 0, 0), Vector3(0, 0, 1)]:
			for sg in [-1.0, 1.0]:
				var n: Vector3 = ax * sg
				var off: Vector3 = n * (s * 0.5 + Vector3.ONE * 0.012)
				var along := Vector3(1, 0, 0) if ax.z > 0.0 else Vector3(0, 0, 1)
				var wlen := s.x if ax.z > 0.0 else s.z
				for yy in [0.05, s.y - 0.05]:
					k.box("base", Vector3(off.x * absf(ax.x), yy, off.z * absf(ax.z)), along * wlen + Vector3(0, 0.08, 0) + ax.abs() * 0.025, bt)
				k.box("base", Vector3(off.x * absf(ax.x), s.y * 0.5, off.z * absf(ax.z)), Vector3(0, s.y, 0) + ax.abs() * 0.025 + along * 0.08, bt)
		k.box("base", Vector3(0.18, s.y * 0.62, s.z * 0.5 + 0.014), Vector3(0.36, 0.14, 0.004), Color("2a1e14")))   # stencil


static func barrel() -> ArrayMesh:
	return _mk("barrel", func(k: MeshKit) -> void:
		k.lathe("base", Vector3.ZERO, [Vector2(0.0, 0.0), Vector2(0.27, 0.0), Vector2(0.31, 0.2), Vector2(0.33, 0.45),
			Vector2(0.31, 0.7), Vector2(0.27, 0.9), Vector2(0.0, 0.9)], 12, Color("7a5234"), Basis.IDENTITY, false)
		for h in [0.1, 0.28, 0.62, 0.8]:
			var r := 0.275 + sin(h / 0.9 * PI) * 0.058
			k.lathe("iron", Vector3(0, h, 0), [Vector2(r, -0.03), Vector2(r, 0.03)], 12, Color("2a2622")))


static func sack() -> ArrayMesh:
	return _mk("sack", func(k: MeshKit) -> void:
		k.bbox("base", Vector3(0, 0.14, 0), Vector3(0.9, 0.28, 0.55), 0.11, Color("a8946c"))
		k.bbox("base", Vector3(0.38, 0.16, 0), Vector3(0.18, 0.2, 0.3), 0.07, Color("9a865e")))


## Wooden pallet of four crates, lashed.
static func pallet() -> ArrayMesh:
	return _mk("pallet", func(k: MeshKit) -> void:
		k.box("base", Vector3(0, 0.07, 0), Vector3(1.6, 0.14, 1.3), Color("6a5236"))
		for i in 4:
			var x := -0.4 + (i % 2) * 0.8
			var z := -0.3 + (i / 2) * 0.6
			k.box("base", Vector3(x, 0.14 + 0.3, z), Vector3(0.76, 0.6, 0.56), [Color("8a6a45"), Color("9a7a52")][i % 2])
		k.box("iron", Vector3(0, 0.76, 0), Vector3(1.64, 0.02, 0.06), Color("2a2622")))


## A coil of mooring rope.
static func rope_coil() -> ArrayMesh:
	return _mk("coil", func(k: MeshKit) -> void:
		for r in 3:
			k.lathe("base", Vector3(0, 0.05 + r * 0.06, 0), [Vector2(0.3 - r * 0.04, -0.03), Vector2(0.33 - r * 0.04, 0.0), Vector2(0.3 - r * 0.04, 0.03), Vector2(0.18, 0.03)], 12, Color("b09a70")))
