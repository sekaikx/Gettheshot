class_name G3Quay
extends RefCounted
## The waterfront east of West St.: plank quay with granite kerb and coping, the stone wall down to the
## river, the piers on pilings, bollards, cargo, cranes, lamps and lanterns. Layout from GroundQuay.

const Y := G3Streets.Y_WALK
const WATER_Y := -0.55
const EDGE := 0.8
const IRON := Color("2b2e2d")

var lay: GroundLayout
var B: G3Bundle
var plan: CityPlan
var q: GroundQuay
var lamp_points: Array = []
var water_lamps: Array = []         # Vector3, lamps and lanterns that reflect in the river


func _init(layout: GroundLayout, bundle: G3Bundle) -> void:
	lay = layout
	B = bundle
	plan = layout.plan
	q = GroundQuay.new(layout)
	q.plan_quay()


func build() -> void:
	_deck()
	_edge()
	for pr in plan.piers:
		_pier(pr)
	for p in q.props:
		_prop(p)


func _near_pier(z: float, margin: float) -> bool:
	return q._near_pier(z, margin)


func _deck() -> void:
	var r: Rect2 = q.rect
	var step := 24.0
	var z := r.position.y
	while z < r.end.y:
		var z1 := minf(z + step, r.end.y)
		var cell := B.at(Vector2(r.position.x + 4.0, (z + z1) * 0.5))
		cell.planks.flat(r.position.x, z, plan.water_x, z1, Y, Color(1, 1, 1))
		z = z1
	var sd := GroundUtil.hseed(plan.seed_value, 72, 5)
	var cellw := B.at(Vector2(r.position.x + 4.0, (r.position.y + r.end.y) * 0.5))
	# the granite kerb on the street side
	var zk := r.position.y
	var k := 0
	while zk < r.end.y:
		k += 1
		var l := minf(GroundUtil.rr(sd, 300 + k, 1.4, 2.6), r.end.y - zk)
		var c := B.at(Vector2(r.position.x, zk + l * 0.5))
		var t := GroundUtil.rr(sd, 310 + k, -0.04, 0.05)
		c.stone.box(Vector3(r.position.x + 0.18, 0.05, zk + l * 0.5), Vector3(0.36, 0.1, l - 0.02), Color("b4ada0").lightened(t), Color("c4bdb0").lightened(t))
		zk += l
	# gutter grime, wheel ruts of hand trucks and wagons, stains, hatches
	cellw.paint.strip(Vector2(r.position.x - 0.3, r.position.y), Vector2(r.position.x - 0.3, r.end.y), 0.6, 0.0082, Color(0.02, 0.02, 0.03, 0.3))
	for lane: float in [3.0, 6.5, 13.0]:
		var zz := r.position.y
		while zz < r.end.y:
			var c2 := B.at(Vector2(r.position.x + lane, zz + 12.0))
			c2.paint.strip(Vector2(r.position.x + lane, zz), Vector2(r.position.x + lane, minf(zz + 24.0, r.end.y)), 0.7, Y + 0.004, Color(0.05, 0.03, 0.02, 0.07))
			zz += 24.0
	for wr in q.warehouses:
		var w: Rect2 = wr
		var c3 := B.at(w.get_center())
		c3.paint.flat(r.position.x, w.get_center().y - 3.0, w.position.x, w.get_center().y + 3.0, Y + 0.004, Color(0.04, 0.03, 0.02, 0.16))
	for i in 26:
		var p := Vector2(GroundUtil.rr(sd, i, r.position.x + 1.0, r.end.x - 1.5), GroundUtil.rr(sd, 50 + i, plan.bounds.position.y, plan.bounds.end.y))
		var rad := GroundUtil.rr(sd, 100 + i, 0.3, 0.9)
		B.at(p).paint.poly_flat(G3Mesh.blob_pts(p, rad * 1.2, rad, sd + i, 10, 0.3), Y + 0.005, Color(0.03, 0.02, 0.02, 0.26))
	for i in 6:
		var hp := Vector2(GroundUtil.rr(sd, 200 + i, r.position.x + 4.0, r.end.x - 3.0), GroundUtil.rr(sd, 210 + i, plan.bounds.position.y, plan.bounds.end.y))
		if _near_pier(hp.y, 2.0):
			continue
		var c4 := B.at(hp)
		c4.metal.box(Vector3(hp.x, Y + 0.012, hp.y), Vector3(1.2, 0.024, 0.9), Color("3a3028"), Color("4e4034"))
		for b in 4:
			c4.metal.box(Vector3(hp.x, Y + 0.026, hp.y - 0.34 + float(b) * 0.226), Vector3(1.14, 0.006, 0.02), Color("1e1a16"))
		c4.metal.ring_flat(Vector3(hp.x, Y + 0.03, hp.y), 0.05, 0.09, 8, Color("1e1c1a"))


func _edge() -> void:
	var xw := plan.water_x
	var r: Rect2 = q.rect
	var sd := GroundUtil.hseed(plan.seed_value, 72, 5)
	# runs of edge between the piers
	var runs := []
	var z := r.position.y
	for pr in plan.piers:
		runs.append([z, float(pr["z0"])])
		z = float(pr["z1"])
	runs.append([z, r.end.y])
	for rn in runs:
		var z0: float = rn[0]
		var z1: float = rn[1]
		# the stone wall down to the water, dark with river damp
		var zz := z0
		while zz < z1:
			var c := B.at(Vector2(xw, zz + 12.0))
			var ze := minf(zz + 24.0, z1)
			c.setts.wall(Vector2(xw, zz), Vector2(xw, ze), WATER_Y, Y + 0.03, Color(0.58, 0.6, 0.6))
			zz = ze
		# the coping stones along the top
		var zc := z0
		var k := 0
		while zc < z1:
			k += 1
			var l := minf(GroundUtil.rr(sd, 400 + k + int(z0), 1.2, 2.2), z1 - zc)
			var c2 := B.at(Vector2(xw, zc + l * 0.5))
			var t := GroundUtil.rr(sd, 500 + k + int(z0), 0.0, 0.12)
			c2.stone.box(Vector3(xw - EDGE * 0.5, Y + 0.015, zc + l * 0.5), Vector3(EDGE, 0.06, l - 0.03), Color("6e6a64").lightened(t), Color("857f76").lightened(t))
			zc += l
		# fender piles against the wall and foam rings round them
		var fz := z0 + 1.0
		while fz < z1 - 0.5:
			var c3 := B.at(Vector2(xw, fz))
			c3.wood.cyl(Vector3(xw + 0.14, WATER_Y - 0.4, fz), 0.16, 0.15, 0.55 + Y + 0.55, 7, Color("2e261e"), true, Color("4a3c2e"))
			c3.paint.ring_flat(Vector3(xw + 0.14, WATER_Y + 0.012, fz), 0.16, 0.4, 10, Color(0.9, 0.95, 1.0, 0.22))
			fz += 2.6
		var mz := z0 + 6.0
		while mz < z1 - 1.0:
			var c4 := B.at(Vector2(xw, mz))
			c4.metal.ring_flat(Vector3(xw - EDGE * 0.6, Y + 0.05, mz), 0.07, 0.11, 8, Color("2a2826"))
			mz += 11.0


func _pier(pr: Dictionary) -> void:
	var x0 := float(pr["x0"]) - EDGE
	var x1 := float(pr["x1"])
	var z0 := float(pr["z0"])
	var z1 := float(pr["z1"])
	var xm := (x0 + x1) * 0.5
	var cell := B.at(Vector2(xm, (z0 + z1) * 0.5))
	var wood := Color("5a4634")
	cell.planks_z.flat(x0, z0, x1, z1, Y, Color(0.95, 0.93, 0.9))
	# timber stringers along both sides and the cap log at the end
	for zz in [z0 + 0.14, z1 - 0.14]:
		cell.wood.box(Vector3((x0 + EDGE + x1) * 0.5, Y + 0.06, zz), Vector3(x1 - x0 - EDGE, 0.12, 0.28), wood.darkened(0.15), wood.lightened(0.04))
	cell.wood.box(Vector3(x1 - 0.16, Y + 0.07, (z0 + z1) * 0.5), Vector3(0.32, 0.14, z1 - z0), wood.darkened(0.2), wood.lightened(0.02))
	# the sides and end of the deck, dark timber over the water
	var sidecol := Color("2c241c")
	cell.wood.wall(Vector2(x0, z0), Vector2(x1, z0), WATER_Y, Y, sidecol)
	cell.wood.wall(Vector2(x1, z1), Vector2(x0, z1), WATER_Y, Y, sidecol)
	cell.wood.wall(Vector2(x1, z0), Vector2(x1, z1), WATER_Y, Y, sidecol.lightened(0.04))
	# pilings standing in the water on both sides, with foam round them
	for pz in [z0 - 0.08, z1 + 0.08]:
		var x := float(pr["x0"]) + 1.2
		while x < x1 - 0.2:
			cell.wood.cyl(Vector3(x, WATER_Y - 0.5, pz), 0.17, 0.15, Y + 0.5 + 0.55 + 0.02, 7, Color("3a2f24"), true, Color("5a4a3a"))
			cell.paint.ring_flat(Vector3(x, WATER_Y + 0.012, pz), 0.17, 0.42, 10, Color(0.9, 0.95, 1.0, 0.2))
			x += 2.4
	# deck planks' butt lines: a few darker boards
	var s := int(z0 * 7.0)
	for k in 5:
		var bx := GroundUtil.rr(s, k, x0 + 2.0, x1 - 2.0)
		cell.paint.box(Vector3(bx, Y + 0.003, (z0 + z1) * 0.5), Vector3(0.3, 0.003, z1 - z0 - 0.6), Color(0.0, 0.0, 0.0, 0.08))


func _prop(p: Dictionary) -> void:
	var m: Vector2 = p["m"]
	var t: String = p["t"]
	var s: int = int(p["s"])
	var cell := B.at(m)
	cell.push_at(Vector3(m.x, Y, m.y), 0.0)
	match t:
		"bollard":
			cell.metal.cyl(Vector3(0, 0, 0), 0.22, 0.17, 0.32, 8, IRON)
			cell.metal.cyl(Vector3(0, 0.3, 0), 0.17, 0.23, 0.12, 8, IRON, true, Color("45494a"))
			if p.get("rope", false):
				cell.props.ring_flat(Vector3(0, 0.2, 0), 0.19, 0.26, 8, Color("b59a6a"))
				cell.props.cyl(Vector3(0, 0.15, 0), 0.26, 0.26, 0.08, 8, Color("b59a6a"), false)
		"cleat":
			cell.metal.box(Vector3(0, 0.05, 0), Vector3(0.5, 0.1, 0.1), IRON)
			cell.metal.box(Vector3(0, 0.11, 0), Vector3(0.1, 0.07, 0.07), IRON)
			cell.metal.box(Vector3(-0.17, 0.12, 0), Vector3(0.14, 0.05, 0.08), IRON)
			cell.metal.box(Vector3(0.17, 0.12, 0), Vector3(0.14, 0.05, 0.08), IRON)
		"quaylamp":
			cell.metal.cyl(Vector3(0, 0, 0), 0.2, 0.12, 0.4, 8, IRON)
			cell.metal.cyl(Vector3(0, 0.4, 0), 0.1, 0.07, 3.6, 8, IRON)
			cell.metal.box(Vector3(0, 3.95, 0), Vector3(1.1, 0.06, 0.06), IRON)
			for sx in [-0.5, 0.5]:
				cell.metal.cyl(Vector3(sx, 3.95, 0), 0.07, 0.07, 0.16, 6, IRON)
				cell.glow.blob(Vector3(sx, 4.2, 0), Vector3(0.2, 0.22, 0.2), Color(1.0, 0.82, 0.55), 3, 8)
				cell.metal.cyl(Vector3(sx, 4.38, 0), 0.14, 0.02, 0.1, 8, IRON)
			var head := Vector3(m.x, Y + 4.1, m.y)
			lamp_points.append(head)
			if bool(p.get("edge", false)):
				water_lamps.append(head)
			cell.pop()
			cell.pools.glow_disc(Vector3(m.x, 0.1, m.y), 7.2, Color(1.0, 0.8, 0.5, 0.6), 5, 20)
			cell.push_at(Vector3.ZERO)
		"buoy":
			cell.metal.cyl(Vector3(0, 0, 0), 0.07, 0.05, 1.5, 6, Color("5a4a3a"))
			var n := 12
			for k in n:
				var a0 := TAU * float(k) / float(n)
				var a1 := TAU * float(k + 1) / float(n)
				var cc := Color("c8c4b8") if k % 2 == 0 else Color("b8362a")
				cell.metal.rod(Vector3(0.0, 1.1 + sin(a0) * 0.32, 0.12 + cos(a0) * 0.32), Vector3(0.0, 1.1 + sin(a1) * 0.32, 0.12 + cos(a1) * 0.32), 0.06, cc)
		"lantern":
			cell.metal.cyl(Vector3(0, 0, 0), 0.1, 0.08, 1.4, 6, IRON)
			cell.metal.box(Vector3(0, 1.45, 0), Vector3(0.28, 0.06, 0.28), IRON)
			cell.glow.box(Vector3(0, 1.62, 0), Vector3(0.2, 0.28, 0.2), Color(1.0, 0.72, 0.45))
			cell.metal.box(Vector3(0, 1.8, 0), Vector3(0.28, 0.05, 0.28), IRON)
			var head2 := Vector3(m.x, Y + 1.6, m.y)
			lamp_points.append(head2)
			water_lamps.append(head2)
			cell.pop()
			cell.pools.glow_disc(Vector3(m.x, 0.1, m.y), 4.6, Color(1.0, 0.72, 0.42, 0.55), 5, 18)
			cell.push_at(Vector3.ZERO)
		"crane":
			_crane(cell, p)
		"crates":
			_crates(cell, p, s)
		"barrels":
			var sz: Vector2 = p["size"]
			var nx := mini(int(sz.x), 3)
			var nz := mini(int(sz.y), 2)
			for ix in nx:
				for iz in nz:
					_barrel(cell, Vector3((float(ix) - float(nx - 1) * 0.5) * 0.66, 0, (float(iz) - float(nz - 1) * 0.5) * 0.66), s + ix * 3 + iz, false)
		"drums":
			var sz2: Vector2 = p["size"]
			var nx2 := mini(int(sz2.x), 3)
			var nz2 := mini(int(sz2.y), 2)
			for ix in nx2:
				for iz in nz2:
					_barrel(cell, Vector3((float(ix) - float(nx2 - 1) * 0.5) * 0.62, 0, (float(iz) - float(nz2 - 1) * 0.5) * 0.62), s + ix * 3 + iz, true)
		"net":
			cell.props.blob(Vector3(0, 0.25, 0), Vector3(1.0, 0.65, 0.8), Color("a8905a"), 3, 9, 0.12, s)
			for k in 5:
				var a := float(k) * 0.35 - 0.7
				cell.props.rod(Vector3(-0.8, 0.12, a * 0.8), Vector3(0.8, 0.12, a * 0.8 + 0.1), 0.02, Color("4a3e2a"))
			for k in 4:
				var xx := -0.6 + float(k) * 0.4
				cell.props.rod(Vector3(xx, 0.8, -0.2), Vector3(xx + 0.1, 0.2, 0.7), 0.014, Color("3a2e1e"))
				cell.props.rod(Vector3(xx, 0.8, -0.2), Vector3(xx + 0.1, 0.2, -0.7), 0.014, Color("3a2e1e"))
		"sacks":
			for k in 10:
				var layer := k / 5
				var o := Vector3(GroundUtil.rr(s, k, -0.6, 0.6) * (1.0 - 0.3 * layer), 0.14 + 0.2 * layer, GroundUtil.rr(s, 20 + k, -0.4, 0.4))
				cell.props.blob(o, Vector3(0.28, 0.14, 0.17), Color("b49a68").darkened(GroundUtil.rr(s, 40 + k, 0.0, 0.25)), 2, 7, 0.08, s + k)
		"tarp":
			var f: Vector2 = p["foot"]
			cell.props.blob(Vector3(0, 0.15, 0), Vector3(f.x * 0.5, 0.5, f.y * 0.5), Color("5a6a78"), 4, 12, 0.14, s)
			for k in 3:
				var a := TAU * float(k) / 3.0
				cell.props.rod(Vector3(0, 0.7, 0), Vector3(cos(a) * f.x * 0.45, 0.0, sin(a) * f.y * 0.45), 0.012, Color("3a2e1e"))
		"timber":
			for ly in 4:
				for ix in 3:
					cell.wood.box(Vector3(0, 0.07 + float(ly) * 0.18, (float(ix) - 1.0) * 0.4), Vector3(3.3 - float(ly) * 0.15, 0.1, 0.36), Color("a0845a").darkened(GroundUtil.rr(s, ly * 3 + ix, 0.0, 0.2)), Color("b89868"))
				for sx in [-1.2, 0.0, 1.2]:
					cell.wood.box(Vector3(sx, 0.02 + float(ly) * 0.18, 0), Vector3(0.08, 0.04, 1.2), Color("6a5030"))
		"coil":
			for ly in 3:
				cell.props.ring_flat(Vector3(0, 0.06 + float(ly) * 0.08, 0), 0.12, 0.4 - float(ly) * 0.03, 10, Color("b59a6a").darkened(float(ly) * 0.05))
			cell.props.cyl(Vector3(0, 0.02, 0), 0.4, 0.4, 0.22, 10, Color("a08858"), false)
		"shack":
			cell.wood.box(Vector3(0, 1.15, 0), Vector3(2.0, 2.3, 1.6), Color("6a5a46"), Color("4a4038"))
			cell.props.box(Vector3(0, 2.34, 0), Vector3(2.3, 0.1, 1.9), Color("3a3532"))
			cell.wood.box(Vector3(-0.55, 0.95, -0.81), Vector3(0.7, 1.85, 0.03), Color("4a3a2c"))
			cell.glow.box(Vector3(0.5, 1.4, -0.81), Vector3(0.55, 0.5, 0.02), Color(1.0, 0.78, 0.45))
			cell.metal.cyl(Vector3(0.7, 2.39, 0.4), 0.1, 0.08, 0.5, 6, IRON)
		"handtruck":
			for sx in [-0.18, 0.18]:
				cell.metal.rod(Vector3(sx, 0.1, 0), Vector3(sx, 1.15, 0), 0.015, IRON_HI())
			cell.metal.box(Vector3(0, 0.12, 0.12), Vector3(0.42, 0.02, 0.24), IRON_HI())
			for sx in [-0.25, 0.25]:
				cell.metal.cyl(Vector3(sx, 0.0, 0.0), 0.1, 0.1, 0.03, 8, IRON)
	cell.pop()


static func IRON_HI() -> Color:
	return Color("4b504c")


func _barrel(cell: G3Bundle.Cell, p: Vector3, s: int, drum: bool) -> void:
	if drum:
		var cols := [Color("2e4a5a"), Color("5a3a2a"), Color("3a5a3a"), Color("6a6a6e")]
		var col: Color = cols[GroundUtil.ri(s, 1, 0, 3)]
		cell.metal.cyl(p, 0.29, 0.29, 0.88, 10, col, true, col.lightened(0.12))
		for hy in [0.08, 0.44, 0.8]:
			cell.metal.cyl(p + Vector3(0, hy, 0), 0.298, 0.298, 0.03, 10, col.darkened(0.25), false)
	else:
		var col2 := Color("6a4a30").lightened(GroundUtil.rr(s, 1, -0.1, 0.12))
		cell.wood.cyl(p, 0.28, 0.33, 0.45, 9, col2, false)
		cell.wood.cyl(p + Vector3(0, 0.45, 0), 0.33, 0.28, 0.45, 9, col2, true, col2.lightened(0.15))
		for hy in [0.08, 0.38, 0.52, 0.82]:
			cell.metal.cyl(p + Vector3(0, hy, 0), 0.335, 0.335, 0.025, 9, Color("2a2a2c"), false)


func _crates(cell: G3Bundle.Cell, p: Dictionary, s: int) -> void:
	var sz: Vector2 = p["size"]
	var nx := int(sz.x)
	var nz := int(sz.y)
	for ix in nx:
		for iz in nz:
			var h := 1 + GroundUtil.ri(s, ix * 7 + iz, 0, 2)
			var o := Vector3((float(ix) - float(nx - 1) * 0.5) * 1.05, 0, (float(iz) - float(nz - 1) * 0.5) * 0.75)
			for ly in h:
				var col := Color("a08358").darkened(GroundUtil.rr(s, ix * 11 + iz * 3 + ly, 0.0, 0.3))
				var yy := float(ly) * 0.7
				cell.wood.box(o + Vector3(0, yy + 0.35, 0), Vector3(1.0, 0.7, 0.72), col, col.lightened(0.1))
				for sl in 3:
					cell.wood.box(o + Vector3(0, yy + 0.12 + float(sl) * 0.23, 0), Vector3(1.012, 0.04, 0.732), col.darkened(0.35))
				cell.wood.box(o + Vector3(0, yy + 0.35, 0.37), Vector3(0.3, 0.14, 0.01), Color("d9d1b8").darkened(0.1))


func _crane(cell: G3Bundle.Cell, p: Dictionary) -> void:
	var boom: float = p["boom"]
	var len: float = p["len"]
	var dir := Vector3(cos(boom), 0, sin(boom))
	cell.stone.box(Vector3(0, 0.25, 0), Vector3(2.4, 0.5, 2.4), Color("6e6a64"), Color("847e74"))
	cell.metal.box(Vector3(-0.3, 1.5, 0), Vector3(1.5, 2.0, 1.5), Color("3e4a44"), Color("4e5a54"))
	cell.metal.box(Vector3(-0.3, 1.5, 0.76), Vector3(0.5, 0.6, 0.02), Color(1.0, 0.75, 0.45))
	cell.metal.cyl(Vector3(0.1, 0.5, 0), 0.22, 0.14, 9.4, 8, Color("4a5249"))
	cell.metal.cyl(Vector3(0.1, 9.8, 0), 0.14, 0.05, 0.4, 6, Color("5a625a"))
	# boom up and out over the river, a guy line back to the mast head, the hook on a rope
	var pivot := Vector3(0.1, 2.4, 0)
	var tip := dir * len + Vector3(0.1, 8.6, 0)
	cell.metal.rod(pivot, tip, 0.12, Color("4a5249"))
	cell.metal.rod(pivot + Vector3(0, 0, 0.18), tip + Vector3(0, 0, 0.0), 0.05, Color("3a423b"))
	cell.metal.rod(Vector3(0.1, 9.9, 0), tip, 0.025, Color("1c1c1e"))
	cell.metal.rod(Vector3(0.1, 9.9, 0), pivot - dir * 1.4 + Vector3(0, 0.2, 0), 0.025, Color("1c1c1e"))
	cell.metal.rod(tip, tip + Vector3(0, -5.2, 0), 0.015, Color("1c1c1e"))
	cell.metal.box(tip + Vector3(0, -5.35, 0), Vector3(0.2, 0.3, 0.2), IRON)
	cell.metal.box(Vector3(-1.4, 0.9, 0.0), Vector3(0.7, 0.8, 1.2), Color("6a6a6e"))
