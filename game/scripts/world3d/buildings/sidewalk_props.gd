extends RefCounted
## What a shop puts out on the sidewalk: fruit stands, bread racks, café tables, a barber pole, fish on ice...
## The spots and the type of each come from FrontArt.plan_shop (the 2D art), so the 3D street has the same
## stalls in the same places. Everything is small merged geometry in the lot frame (z = out of the wall).

const MK := preload("res://scripts/world3d/buildings/mesh_kit.gd")

const WOOD := Color("7a5a3c")
const WOOD_DARK := Color("4a3626")
const IRON := Color("25221f")
const CREAM := Color("e6dcc3")
const GALV := Color("9aa0a4")


static func build(B, S) -> void:
	var f: MK = B.props
	var rng := W.rng(int(B.id) * 91 + 17)
	for it in S["items"]:
		var rc: Rect2 = it["rect"]
		var cpx: Vector2 = S["xf"] * rc.get_center()
		var c: Vector3 = B.local_px(cpx, 0.0)
		var sz := rc.size / W.M
		_item(f, String(it["t"]), c, sz, rng, B)
	# a couple of ash cans on some house fronts
	if B.biz.is_empty() and B.fract_seed(3.0) > 0.45:
		var x: float = (1.9 if B.fract_seed(5.0) > 0.5 else -1.9)
		_can(f, Vector3(x, 0, 0.45), Color("6a6e70"))
		if B.fract_seed(9.0) > 0.5:
			_can(f, Vector3(x + signf(x) * 0.5, 0, 0.4), Color("5a5e60"))


static func _item(f: MK, t: String, c: Vector3, sz: Vector2, rng: RandomNumberGenerator, B) -> void:
	match t:
		"produce":
			_stand(f, c, sz, rng)
		"bread_rack":
			_rack(f, c, sz, Color("c8964a"))
		"baguette_barrel":
			_barrel(f, c + Vector3(0, 0, 0.1), Color("7a5a3c"))
			for k in 5:
				var a := rng.randf_range(-0.3, 0.3)
				f.bar("trim", c + Vector3(rng.randf_range(-0.15, 0.15), 0.7, rng.randf_range(-0.1, 0.1)),
					c + Vector3(a + rng.randf_range(-0.15, 0.15), 1.25, a * 0.5), 0.07, Color("d4a860"))
		"meat_rail":
			_hang_rail(f, c, sz, Color("c46a60"))
		"chop_block":
			f.box("trim", c + Vector3(0, 0.42, 0), Vector3(0.7, 0.84, 0.6), WOOD, 8)
			f.box("trim", c + Vector3(0, 0.86, 0), Vector3(0.7, 0.04, 0.6), Color("a85048"), 8)
		"fish_ice":
			f.box("trim", c + Vector3(0, 0.3, 0), Vector3(minf(sz.x, 1.3), 0.6, 0.8), Color("d8dcdc"), 8)
			for k in 7:
				f.box("trim", c + Vector3(rng.randf_range(-0.5, 0.5), 0.63, rng.randf_range(-0.28, 0.28)), Vector3(0.22, 0.06, 0.08), Color("a8b8c4"), 8)
		"oyster_barrel":
			_barrel(f, c, Color("5a4a38"))
			f.cyl("trim", c + Vector3(0.0, 0.76, 0.0), 0.26, 0.04, 8, Color("c8c0b0"))
		"cafe_table":
			_table(f, c, Color("3a2e26"), Color("d8d0bc"))
		"rest_table":
			_table(f, c, Color("5a1f1c"), Color("e8e0d0"))
		"barber_pole":
			f.cyl("trim", c, 0.2, 0.16, 8, IRON)
			for k in 9:
				f.cyl("trim", c + Vector3(0, 0.16 + k * 0.2, 0), 0.085, 0.2, 8, [Color("c0392b"), Color("f0ece0"), Color("2a4a8a")][k % 3])
			f.sphere("trim", c + Vector3(0, 2.02, 0), 0.12, Color("d9b25a"), 6, 4)
		"bench":
			f.box("trim", c + Vector3(0, 0.42, 0), Vector3(minf(sz.x, 1.2), 0.07, 0.4), WOOD, 8)
			f.box("trim", c + Vector3(0, 0.7, -0.18), Vector3(minf(sz.x, 1.2), 0.3, 0.05), WOOD, 8)
			for s in [-1.0, 1.0]:
				f.box("trim", c + Vector3(s * 0.5, 0.2, 0), Vector3(0.06, 0.4, 0.34), IRON, 8)
		"dummy":
			f.bar("trim", c, c + Vector3(0, 0.9, 0), 0.05, IRON)
			f.cyl("trim", c + Vector3(0, 0.88, 0), 0.2, 0.55, 8, Color("2a3040"), 0.14)
			f.sphere("trim", c + Vector3(0, 1.5, 0), 0.07, Color("c8b898"), 6, 4)
		"suit_rack":
			_hang_rail(f, c, sz, Color("3a3d45"))
		"shoeshine":
			f.box("trim", c + Vector3(0, 0.2, 0), Vector3(0.6, 0.4, 0.5), WOOD_DARK, 8)
			f.box("trim", c + Vector3(0, 0.8, -0.2), Vector3(0.5, 0.7, 0.08), Color("5a2e22"), 8)
		"junk_crate", "crates":
			for k in 3:
				f.box("trim", c + Vector3(rng.randf_range(-0.3, 0.3), 0.2 + 0.4 * (k / 2), rng.randf_range(-0.2, 0.2)),
					Vector3(0.5, 0.4, 0.4), WOOD.darkened(rng.randf_range(0.0, 0.3)), 8)
		"laundry_cart":
			f.box("trim", c + Vector3(0, 0.45, 0), Vector3(0.9, 0.5, 0.6), Color("8a7a60"), 8)
			f.box("trim", c + Vector3(0, 0.78, 0), Vector3(0.8, 0.2, 0.5), CREAM, 8)
			for s in [-1.0, 1.0]:
				f.cyl("trim", c + Vector3(s * 0.4, 0.0, 0.0), 0.16, 0.06, 8, IRON)
		"bundles":
			for k in 3:
				f.sphere("trim", c + Vector3(rng.randf_range(-0.3, 0.3), 0.22, rng.randf_range(-0.2, 0.2)), 0.26, Color("d8d0b8").darkened(0.08 * k), 7, 5)
		"news_rack":
			f.box("trim", c + Vector3(0, 0.55, 0), Vector3(0.7, 1.1, 0.3), Color("3a4a5a"), 8)
			for k in 4:
				f.box("trim", c + Vector3(0, 0.35 + k * 0.22, 0.17), Vector3(0.6, 0.18, 0.02), [CREAM, Color("e0c890"), Color("c8d0d8"), Color("e8d8b0")][k], 8)
		"ash_urn":
			f.cyl("trim", c, 0.2, 0.7, 8, Color("2a2c2e"), 0.16)
		"planter":
			f.box("trim", c + Vector3(0, 0.25, 0), Vector3(0.9, 0.5, 0.5), Color("5a4634"), 8)
			for k in 3:
				f.sphere("trim", c + Vector3((k - 1) * 0.3, 0.65, 0), 0.22, Color("3f6a38").lightened(0.08 * k), 6, 4)
		"brooms":
			for k in 4:
				f.bar("trim", c + Vector3(-0.3 + k * 0.2, 0.0, 0.0), c + Vector3(-0.25 + k * 0.2, 1.4, -0.35), 0.04, Color("8a6a40"))
				f.cyl("trim", c + Vector3(-0.3 + k * 0.2, 0.0, 0.0), 0.08, 0.2, 6, Color("c8b070"))
			_barrel(f, c + Vector3(0.45, 0, 0.1), Color("6a6a6a"))
		"pails":
			for k in 3:
				f.cyl("trim", c + Vector3((k - 1) * 0.35, 0.0, rng.randf_range(-0.1, 0.1)), 0.16, 0.3, 8, GALV, 0.2)
		"gumball":
			f.cyl("trim", c, 0.14, 0.7, 8, IRON, 0.1)
			f.sphere("trim", c + Vector3(0, 0.95, 0), 0.26, Color("e8b0a8"), 8, 6)
			f.cyl("trim", c + Vector3(0, 1.2, 0), 0.1, 0.06, 8, Color("c0392b"))
		"soda_crates":
			for k in 2:
				f.box("trim", c + Vector3((k - 0.5) * 0.5, 0.15, 0), Vector3(0.45, 0.3, 0.35), Color("a8322a"), 8)
				for j in 4:
					f.cyl("trim", c + Vector3((k - 0.5) * 0.5 - 0.15 + j * 0.1, 0.3, 0.0), 0.03, 0.14, 5, Color("5a8a4a"))
		"penny_scale":
			f.cyl("trim", c, 0.1, 1.1, 8, IRON, 0.08)
			f.cyl("trim", c + Vector3(0, 1.1, 0), 0.16, 0.12, 8, Color("e8e4d0"))
		_:
			f.box("trim", c + Vector3(0, 0.2, 0), Vector3(0.5, 0.4, 0.4), WOOD, 8)


static func _can(f: MK, p: Vector3, col: Color) -> void:
	f.cyl("trim", p, 0.24, 0.62, 8, col, 0.22)
	f.cyl("trim", p + Vector3(0, 0.62, 0), 0.26, 0.05, 8, col.darkened(0.2), 0.1)


static func _barrel(f: MK, p: Vector3, col: Color) -> void:
	f.cyl("trim", p, 0.28, 0.75, 10, col, 0.28)
	for y in [0.15, 0.6]:
		f.cyl("trim", p + Vector3(0, y, 0), 0.295, 0.05, 10, IRON, -1.0, false)


static func _table(f: MK, p: Vector3, col: Color, top: Color) -> void:
	f.cyl("trim", p, 0.05, 0.72, 6, col)
	f.cyl("trim", p + Vector3(0, 0.72, 0), 0.36, 0.04, 10, top)
	for s in [-1.0, 1.0]:
		var cp := p + Vector3(s * 0.62, 0, 0.0)
		f.box("trim", cp + Vector3(0, 0.4, 0), Vector3(0.36, 0.05, 0.36), col, 8)
		f.box("trim", cp + Vector3(s * 0.16, 0.65, 0), Vector3(0.04, 0.4, 0.36), col, 8)
		for q in [[-1, -1], [1, 1], [-1, 1], [1, -1]]:
			f.bar("trim", cp + Vector3(q[0] * 0.15, 0, q[1] * 0.15), cp + Vector3(q[0] * 0.15, 0.4, q[1] * 0.15), 0.03, col)


static func _stand(f: MK, p: Vector3, sz: Vector2, rng: RandomNumberGenerator) -> void:
	var w := minf(sz.x, 1.6)
	f.box("trim", p + Vector3(0, 0.3, 0), Vector3(w, 0.6, 0.8), WOOD, 8)
	f.box_t("trim", Transform3D(Basis(Vector3.RIGHT, 0.25), p + Vector3(0, 0.7, 0.0)), Vector3(w * 0.5 - 0.02, 0.025, 0.4), WOOD_DARK, 0)
	var cols := [Color("c0392b"), Color("e08a2a"), Color("5a9a3a"), Color("e0c03a"), Color("8a2a5a")]
	var n := int(w / 0.28)
	for i in n:
		for j in 3:
			var col: Color = cols[(i + j * 2 + rng.randi_range(0, 1)) % cols.size()]
			f.sphere("trim", p + Vector3(-w * 0.5 + 0.17 + i * 0.28, 0.78 + j * 0.0, -0.22 + j * 0.22), 0.09, col, 5, 3)


static func _rack(f: MK, p: Vector3, sz: Vector2, goods: Color) -> void:
	var w := minf(sz.x, 1.1)
	for s in [-1.0, 1.0]:
		f.bar("trim", p + Vector3(s * w * 0.5, 0.0, -0.2), p + Vector3(s * w * 0.5, 1.3, -0.2), 0.05, WOOD_DARK)
	for k in 3:
		var y := 0.35 + k * 0.4
		f.box("trim", p + Vector3(0, y, -0.1), Vector3(w, 0.03, 0.4), WOOD, 8)
		for j in 4:
			f.box("trim", p + Vector3(-w * 0.4 + j * w * 0.27, y + 0.07, -0.1), Vector3(0.2, 0.1, 0.28), goods.darkened(0.06 * j), 8)


static func _hang_rail(f: MK, p: Vector3, sz: Vector2, col: Color) -> void:
	var w := minf(sz.x, 1.3)
	for s in [-1.0, 1.0]:
		f.bar("trim", p + Vector3(s * w * 0.5, 0.0, 0.0), p + Vector3(s * w * 0.5, 1.7, 0.0), 0.05, IRON)
	f.bar("trim", p + Vector3(-w * 0.5, 1.7, 0), p + Vector3(w * 0.5, 1.7, 0), 0.04, IRON)
	var n := int(w / 0.22)
	for i in n:
		f.box("trim", p + Vector3(-w * 0.5 + 0.15 + i * 0.22, 1.25, 0.0), Vector3(0.16, 0.8, 0.12), col.darkened(0.08 * (i % 3)), 8)
