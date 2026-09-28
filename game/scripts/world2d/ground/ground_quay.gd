class_name GroundQuay
extends RefCounted
## The waterfront along West St.: the quay's heavy planks between a granite curb and a stone edge,
## bollards and cleats, crate stacks, barrels, sacks under cargo nets, rope coils, a derrick crane,
## twin-globe quay lamps, the piers on their pilings with a lantern at each end, and the river's
## still base (its moving surface is GroundRiver).

const M := W.M
const EDGE := 0.8                  # stone coping at the water's edge (m)
const CURB := 0.35

var lay: GroundLayout
var plan: CityPlan
var grain: Texture2D
var mottle: Texture2D
var planks_tex: Texture2D
var setts: Texture2D
var rect := Rect2()                 # the quay (m), stretched to the drawn area
var water := Rect2()                # the river (m)
var props: Array = []
var lights: Array = []
var solids: Array = []
var lamp_heads: Array = []
var lanterns: Array = []            # px, for the river's reflections
var warehouses: Array = []          # Rect2 (m)


func _init(layout: GroundLayout) -> void:
	lay = layout
	plan = layout.plan
	grain = GroundTex.grain()
	mottle = GroundTex.mottle()
	planks_tex = GroundTex.planks()
	setts = GroundTex.setts()


func plan_quay() -> void:
	var q: Array = plan.quay_rect
	var a := lay.area
	rect = Rect2(float(q[0]), a.position.y, float(q[2]) - float(q[0]), a.size.y)
	water = Rect2(plan.water_x, a.position.y, a.end.x - plan.water_x, a.size.y)
	for lot in plan.lots:
		if lot["kind"] == "warehouse":
			var r := W.lot_rect(lot)
			warehouses.append(Rect2(r.position / M, r.size / M))
	var sd := GroundUtil.hseed(plan.seed_value, 71, 5)
	var x0 := rect.position.x
	var xw := plan.water_x
	var zmin := plan.bounds.position.y + 4.0
	var zmax := plan.bounds.end.y - 4.0
	# bollards along the edge, a pair at each pier root; cleats between
	var z := zmin + 2.0
	var k := 0
	while z < zmax:
		k += 1
		if not _near_pier(z, 1.2):
			_add({"t": "bollard", "m": Vector2(xw - 0.42, z), "s": sd + k, "rope": GroundUtil.r01(sd, k) < 0.25})
		if not _near_pier(z + 3.5, 1.2) and GroundUtil.r01(sd, 100 + k) < 0.6:
			_add({"t": "cleat", "m": Vector2(xw - 0.3, z + 3.5), "s": sd + 200 + k})
		z += GroundUtil.rr(sd, 300 + k, 7.0, 9.0)
	for pr in plan.piers:
		for pz in [float(pr["z0"]) - 0.7, float(pr["z1"]) + 0.7]:
			_add({"t": "bollard", "m": Vector2(xw - 0.45, pz), "s": sd + int(pz * 3.0), "rope": false})
	# twin-globe lamps along the street edge, clear of the warehouse doors
	for lz: float in [8.0, 30.0, 72.0, 96.0, 118.0, 168.0, 190.0]:
		var ok := true
		for wr in warehouses:
			if absf(lz - (wr as Rect2).get_center().y) < 6.0:
				ok = false
		if ok:
			_lamp(Vector2(x0 + 0.75, lz), false)
	# a lamp at each pier root, on the edge
	for pr in plan.piers:
		_lamp(Vector2(xw - 1.1, float(pr["z0"]) - 1.9), true)
	# lanterns at the pier ends
	for pr in plan.piers:
		var lp := Vector2(float(pr["x1"]) - 0.35, float(pr["z0"]) + 0.35)
		_add({"t": "lantern", "m": lp, "s": sd + int(lp.y)})
		var px := lp * M
		lanterns.append(px)
		lights.append({"pos": px, "r": 4.6 * M, "color": Color(1.0, 0.72, 0.45), "e": 0.95, "shape": "round",
			"flicker": int(lp.y) % 2 == 0})
	# the derrick crane between the first warehouse and the middle pier, its boom over the river
	var crane_z := 76.0
	_add({"t": "crane", "m": Vector2(xw - 2.6, crane_z), "s": sd + 9, "boom": -0.38, "len": 11.5})
	solids.append(Rect2(Vector2(xw - 3.6, crane_z - 1.0) * M, Vector2(2.0, 2.0) * M))
	# cargo: stacks of crates, barrels, sacks under nets, rope coils, in the open stretches
	var zones := [Rect2(x0 + 5.5, 4.0, xw - x0 - 7.8, 26.0), Rect2(x0 + 5.5, 60.0, xw - x0 - 11.0, 26.0),
		Rect2(x0 + 5.5, 101.0, xw - x0 - 7.8, 30.0), Rect2(x0 + 5.5, 158.0, xw - x0 - 7.8, 34.0),
		Rect2(xw - 3.6, 40.0, 2.4, 16.0), Rect2(xw - 3.6, 136.0, 2.4, 16.0)]
	var n := 0
	for zi in zones.size():
		var zr: Rect2 = zones[zi]
		var zz := zr.position.y + GroundUtil.rr(sd, 400 + zi, 0.3, 1.5)
		while zz < zr.end.y - 1.2:
			var row_h := 0.0
			var xx := zr.position.x + GroundUtil.rr(sd, 450 + n, 0.0, 1.2)
			while xx < zr.end.x - 0.8:
				n += 1
				var ns := sd + n * 37
				var roll := GroundUtil.r01(ns, 1)
				var t := "crates" if roll < 0.46 else ("barrels" if roll < 0.64 else ("net" if roll < 0.76 else ("sacks" if roll < 0.88 else ("coil" if roll < 0.94 else "gap"))))
				if zi >= 4:
					t = "barrels" if roll < 0.5 else ("net" if roll < 0.8 else "coil")
				var size := Vector2(GroundUtil.ri(ns, 2, 1, 4), GroundUtil.ri(ns, 3, 1, 3))
				var foot := Vector2.ZERO
				match t:
					"crates": foot = Vector2(size.x * 1.05, size.y * 0.75)
					"barrels": foot = Vector2(minf(size.x, 3.0) * 0.66, minf(size.y, 2.0) * 0.66)
					"net": foot = Vector2(2.1, 1.7)
					"sacks": foot = Vector2(1.8, 1.4)
					"coil": foot = Vector2(0.8, 0.8)
					"gap": foot = Vector2(GroundUtil.rr(ns, 6, 1.5, 3.5), 0.5)
				if zi >= 4:
					foot = foot.min(Vector2(2.2, 2.0))
				if xx + foot.x > zr.end.x:
					break
				var c := Vector2(xx + foot.x * 0.5, zz + foot.y * 0.5)
				var blocked := (_near_pier(c.y, 2.5) and c.x + foot.x * 0.5 > xw - 6.0) or (absf(c.y - crane_z) < 3.5 and c.x + foot.x * 0.5 > xw - 6.5)
				if t != "gap" and not blocked:
					_add({"t": t, "m": c, "s": ns, "size": size, "foot": foot})
					if t != "coil":
						solids.append(Rect2((c - foot * 0.5) * M, foot * M))
					row_h = maxf(row_h, foot.y)
				xx += foot.x + GroundUtil.rr(ns, 5, 0.35, 1.3)
			zz += maxf(row_h, 0.8) + GroundUtil.rr(sd, 470 + n, 1.3, 2.6)
	# a watchman's shack by the middle pier, and a hand truck
	_add({"t": "shack", "m": Vector2(xw - 3.4, 112.0), "s": sd + 77})
	solids.append(Rect2(Vector2(xw - 4.4, 111.2) * M, Vector2(2.0, 1.6) * M))
	_add({"t": "handtruck", "m": Vector2(x0 + 3.6, 64.0), "s": sd + 78})
	for p in props:
		if p["t"] == "bollard":
			var c: Vector2 = p["p"]
			solids.append(Rect2(c - Vector2(0.28, 0.28) * M, Vector2(0.56, 0.56) * M))


func _near_pier(z: float, margin: float) -> bool:
	for pr in plan.piers:
		if z > float(pr["z0"]) - margin and z < float(pr["z1"]) + margin:
			return true
	return false


func _add(p: Dictionary) -> void:
	p["p"] = (p["m"] as Vector2) * M
	if not p.has("rot"):
		p["rot"] = 0.0
	props.append(p)


func _lamp(m: Vector2, edge: bool) -> void:
	var p := {"t": "quaylamp", "m": m, "s": int(m.y * 13.0), "edge": edge}
	_add(p)
	lamp_heads.append(m * M)
	lights.append({"pos": m * M, "r": 7.4 * M, "color": Pal.LAMP, "e": 1.1, "shape": "round", "flicker": false})
	solids.append(Rect2((m - Vector2(0.2, 0.2)) * M, Vector2(0.4, 0.4) * M))


static func _c(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	ci.draw_circle(c, r, col, true, -1.0, true)


# ================================================================== the water's still base

func paint_water(ci: CanvasItem) -> void:
	var r := Rect2(water.position * M, water.size * M)
	Draw.hgrad(ci, r, Pal.WATER, Pal.WATER_DEEP)
	GroundUtil.tex_rect(ci, r, mottle, 26.0, Color(1, 1, 1, 0.1))
	GroundUtil.tex_rect(ci, r, mottle, 9.0, Color(1, 1, 1, 0.06))
	# the current: long faint streaks running downstream, and patches of reflected sky
	var ws := GroundUtil.hseed(plan.seed_value, 5, 9)
	for k in 16:
		var c0 := Vector2(GroundUtil.rr(ws, k, water.position.x + 3.0, water.end.x - 2.0), GroundUtil.rr(ws, 20 + k, water.position.y, water.end.y)) * M
		var l := GroundUtil.rr(ws, 30 + k, 14.0, 34.0) * M
		var light := GroundUtil.r01(ws, 40 + k) < 0.5
		var pts := GroundUtil.wave(c0, c0 + Vector2(GroundUtil.rr(ws, 50 + k, -1.0, 1.0) * M, l), ws + k, 1.4 * M, 11.0 * M)
		var sc := Color(0.6, 0.7, 0.8, 0.02) if light else Color(0.0, 0.02, 0.04, 0.035)
		var wd := GroundUtil.rr(ws, 55 + k, 14.0, 34.0)
		for q in 3:
			ci.draw_polyline(pts, sc, wd * (1.0 - float(q) * 0.3), true)
	for k in 10:
		var c := Vector2(GroundUtil.rr(ws, 60 + k, water.position.x + 4.0, water.end.x - 4.0), GroundUtil.rr(ws, 80 + k, water.position.y, water.end.y)) * M
		GroundUtil.soft_blob(ci, c, GroundUtil.rr(ws, 100 + k, 4.0, 9.0) * M, Color(0.55, 0.65, 0.75, 0.06), ws + k, Vector2(0.6, 1.6))
	# the quay wall's shadow on the water, and the scum line along it
	var sh := GroundUtil.sh(2.2)
	Draw.hgrad(ci, Rect2(r.position, Vector2(sh.x * 1.6, r.size.y)), Color(0, 0.01, 0.03, 0.45), Color(0, 0.01, 0.03, 0.0))
	ci.draw_rect(Rect2(r.position, Vector2(3.0, r.size.y)), Color(0.3, 0.32, 0.25, 0.35))
	# the piers' shadows and the pilings standing in the water
	for pr in plan.piers:
		var pr_r := Rect2(Vector2(pr["x0"], pr["z0"]) * M, Vector2(float(pr["x1"]) - float(pr["x0"]), float(pr["z1"]) - float(pr["z0"])) * M)
		var so := GroundUtil.sh(1.8)
		ci.draw_rect(Rect2(pr_r.position + so, pr_r.size), Color(0, 0.01, 0.03, 0.4))
		ci.draw_rect(Rect2(pr_r.position + so * 1.6, pr_r.size), Color(0, 0.01, 0.03, 0.15))
		for pz in _piling_rows(pr):
			var x := float(pr["x0"]) + 1.2
			while x < float(pr["x1"]) - 0.2:
				var c := Vector2(x, pz) * M
				ci.draw_colored_polygon(Draw.ellipse_points(c + Vector2(0.15, 0.55) * M, Vector2(0.14, 0.5) * M, 0.0, 12), Color(0.02, 0.03, 0.04, 0.35))
				ci.draw_arc(c, 0.3 * M, 0.0, TAU, 16, Color(0.6, 0.68, 0.72, 0.18), 2.0, true)
				x += 2.4
	# driftwood and a floating crate
	var sd := GroundUtil.hseed(plan.seed_value, 3, 9)
	for k in 5:
		var c := Vector2(GroundUtil.rr(sd, k, water.position.x + 4.0, water.end.x - 4.0), GroundUtil.rr(sd, 10 + k, plan.bounds.position.y, plan.bounds.end.y)) * M
		var rot := GroundUtil.r01(sd, 20 + k) * PI
		if k == 0:
			ci.draw_colored_polygon(GroundUtil.orect(c, Vector2(0.7, 0.7) * M, rot), Color("5a4630"))
			ci.draw_colored_polygon(GroundUtil.orect(c, Vector2(0.6, 0.6) * M, rot), Color("6e5638"))
		else:
			ci.draw_colored_polygon(GroundUtil.orect(c, Vector2(GroundUtil.rr(sd, 30 + k, 1.0, 2.2), 0.16) * M, rot), Color("4a3a2a"))


func _piling_rows(pr: Dictionary) -> Array:
	return [float(pr["z0"]) - 0.08, float(pr["z1"]) + 0.08]


# ================================================================== quay and pier decks

func paint_quay(ci: CanvasItem) -> void:
	var r := Rect2(rect.position * M, rect.size * M)
	var sd := GroundUtil.hseed(plan.seed_value, 72, 5)
	GroundUtil.tex_rect(ci, r, planks_tex, 1.0)
	GroundUtil.tex_rect(ci, r, mottle, 14.0, Color(1, 1, 1, 0.14))
	GroundUtil.tex_rect(ci, r, grain, 1.0, Color(1, 1, 1, 0.35))
	# wheel ruts of hand trucks and wagons along the quay, stains, the odd hatch
	for lane: float in [3.0, 6.5, 13.0]:
		var lx := (rect.position.x + float(lane)) * M
		ci.draw_rect(Rect2(lx - 0.35 * M, r.position.y, 0.7 * M, r.size.y), Color(0.05, 0.03, 0.02, 0.05))
	for wr in warehouses:
		var w: Rect2 = wr
		var apron := Rect2(Vector2(rect.position.x, w.get_center().y - 3.0) * M, Vector2(w.position.x - rect.position.x, 6.0) * M)
		ci.draw_rect(apron, Color(0.04, 0.03, 0.02, 0.14))
	for k in 26:
		var c := Vector2(GroundUtil.rr(sd, k, rect.position.x + 1.0, rect.end.x - 1.5), GroundUtil.rr(sd, 50 + k, plan.bounds.position.y, plan.bounds.end.y)) * M
		GroundUtil.soft_blob(ci, c, GroundUtil.rr(sd, 100 + k, 0.3, 0.9) * M, Color(0.03, 0.02, 0.02, 0.22), sd + k, Vector2(1.2, 0.9))
	for k in 6:
		var c := Vector2(GroundUtil.rr(sd, 200 + k, rect.position.x + 4.0, rect.end.x - 3.0), GroundUtil.rr(sd, 210 + k, plan.bounds.position.y, plan.bounds.end.y))
		if _near_pier(c.y, 2.0):
			continue
		_hatch(ci, c * M, sd + k)
	# the granite curb on the street side, with the gutter's grime against it
	var curb := Rect2(r.position, Vector2(CURB * M, r.size.y))
	Draw.hgrad(ci, Rect2(r.position - Vector2(0.5 * M, 0), Vector2(0.5 * M, r.size.y)), Color(Pal.GUTTER, 0.0), Color(Pal.GUTTER, 0.45))
	ci.draw_rect(curb, Pal.CURB.darkened(0.06))
	GroundUtil.tex_rect(ci, curb, grain, 1.0, Color(1, 1, 1, 0.6))
	ci.draw_rect(Rect2(r.position, Vector2(1.5, r.size.y)), Color(1, 1, 1, 0.28))
	ci.draw_rect(Rect2(r.position + Vector2(curb.size.x - 1.5, 0), Vector2(1.5, r.size.y)), Color(0, 0, 0, 0.35))
	var z := r.position.y
	var k2 := 0
	while z < r.end.y:
		k2 += 1
		z += GroundUtil.rr(sd, 300 + k2, 1.3, 2.4) * M
		ci.draw_line(Vector2(r.position.x, z), Vector2(r.position.x + curb.size.x, z), Color(0.35, 0.33, 0.3, 0.6), 1.2, true)
	# the stone edge on the water side, broken by the piers
	var ex := (plan.water_x - EDGE) * M
	var edge := Rect2(Vector2(ex, r.position.y), Vector2(EDGE * M, r.size.y))
	ci.draw_rect(Rect2(edge.position - Vector2(3, 0), Vector2(3, edge.size.y)), Color(0, 0, 0, 0.3))
	GroundUtil.tex_rect(ci, edge, setts, 1.0, Color(1.12, 1.1, 1.06))
	var z2 := r.position.y
	var k3 := 0
	while z2 < r.end.y:
		k3 += 1
		var l := GroundUtil.rr(sd, 400 + k3, 1.2, 2.2) * M
		ci.draw_rect(Rect2(Vector2(ex, z2), Vector2(EDGE * M, l)).grow(-1.0), Color(Pal.QUAY_STONE.lightened(GroundUtil.rr(sd, 500 + k3, 0.0, 0.14)), 0.85))
		ci.draw_rect(Rect2(Vector2(ex, z2 + 1.0), Vector2(EDGE * M, 1.5)), Color(1, 1, 1, 0.15))
		ci.draw_line(Vector2(ex, z2), Vector2(ex + EDGE * M, z2), Color(0.12, 0.12, 0.12, 0.8), 1.5, true)
		z2 += l
	ci.draw_rect(Rect2(Vector2(edge.end.x - 2.0, r.position.y), Vector2(2.0, r.size.y)), Color(0.1, 0.1, 0.1, 0.5))
	# mooring rings set in the stone
	var z3 := plan.bounds.position.y + 6.0
	while z3 < plan.bounds.end.y:
		if not _near_pier(z3, 1.0):
			ci.draw_arc(Vector2(ex + EDGE * 0.6 * M, z3 * M), 0.1 * M, 0.0, TAU, 12, Color("2a2826"), 2.0, true)
		z3 += 11.0
	for pr in plan.piers:
		_pier(ci, pr)


func _hatch(ci: CanvasItem, c: Vector2, s: int) -> void:
	var r := Rect2(c - Vector2(0.6, 0.45) * M, Vector2(1.2, 0.9) * M)
	ci.draw_rect(r.grow(1.5), Color(0.05, 0.04, 0.03, 0.8))
	ci.draw_rect(r, Pal.PLANKS_DARK.lightened(0.05))
	for k in 4:
		var y := r.position.y + r.size.y * (float(k) + 0.5) / 4.0
		ci.draw_line(Vector2(r.position.x + 2, y), Vector2(r.end.x - 2, y), Color(0, 0, 0, 0.3), 1.0, true)
	for x in [r.position.x + 5.0, r.end.x - 5.0]:
		ci.draw_line(Vector2(x, r.position.y + 2), Vector2(x, r.end.y - 2), Color("2a2624"), 3.0, true)
	ci.draw_arc(r.get_center(), 3.0, 0.0, TAU, 10, Color("1e1c1a"), 1.5, true)


func _pier(ci: CanvasItem, pr: Dictionary) -> void:
	var x0 := float(pr["x0"]) - EDGE
	var x1 := float(pr["x1"])
	var z0 := float(pr["z0"])
	var z1 := float(pr["z1"])
	var r := Rect2(Vector2(x0, z0) * M, Vector2(x1 - x0, z1 - z0) * M)
	# deck planks run across the pier
	ci.draw_set_transform(r.position, PI * 0.5, Vector2.ONE)
	var lr := Rect2(0, -r.size.x, r.size.y, r.size.x)
	GroundUtil.tex_rect(ci, lr, planks_tex, 1.0, Color(0.95, 0.93, 0.9))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	GroundUtil.tex_rect(ci, r, mottle, 10.0, Color(1, 1, 1, 0.12))
	# the timber stringers along both sides, and the cap log at the end
	for z in [z0, z1 - 0.28]:
		var sr := Rect2(Vector2(x0 + EDGE, z) * M, Vector2(x1 - x0 - EDGE, 0.28) * M)
		ci.draw_rect(sr, Pal.PLANKS_DARK.darkened(0.15))
		ci.draw_rect(Rect2(sr.position, Vector2(sr.size.x, 1.5)), Color(1, 1, 1, 0.12))
	var cap := Rect2(Vector2(x1 - 0.32, z0) * M, Vector2(0.32, z1 - z0) * M)
	ci.draw_rect(cap, Pal.PLANKS_DARK.darkened(0.2))
	ci.draw_rect(Rect2(cap.position, Vector2(1.5, cap.size.y)), Color(1, 1, 1, 0.12))
	ci.draw_rect(Rect2(Vector2(r.end.x - 2.0, r.position.y), Vector2(2.0, r.size.y)), Color(0, 0, 0, 0.4))
	ci.draw_rect(Rect2(Vector2(r.position.x, r.end.y - 2.0), Vector2(r.size.x, 2.0)), Color(0, 0, 0, 0.35))
	# pile heads showing along the edges
	for pz in _piling_rows(pr):
		var x := float(pr["x0"]) + 1.2
		while x < x1 - 0.2:
			var c := Vector2(x, float(pz)) * M
			_c(ci, c, 0.19 * M, Color("2e261e"))
			_c(ci, c, 0.15 * M, Color("5a4a38"))
			ci.draw_arc(c, 0.09 * M, 0.0, TAU, 10, Color(0, 0, 0, 0.3), 1.0, true)
			ci.draw_arc(c, 0.15 * M, PI, PI * 1.5, 6, Color(1, 1, 1, 0.2), 1.2, true)
			x += 2.4
	# a ladder down to the water on the south side
	var lx := x1 - 5.0
	var ly := z1 * M
	for k in 5:
		ci.draw_line(Vector2(lx * M + k * 7.0, ly - 2.0), Vector2(lx * M + k * 7.0, ly + 0.25 * M), Color("3a3028"), 1.6, true)
	ci.draw_line(Vector2(lx * M - 2.0, ly + 0.1 * M), Vector2(lx * M + 30.0, ly + 0.1 * M), Color("3a3028"), 2.0, true)
	# cleats and a coil along the sides
	var sd := int(z0 * 17.0)
	for k in 3:
		var cx := x0 + EDGE + 5.0 + float(k) * 7.5
		_cleat_draw(ci, Vector2(cx, z0 + 0.45) * M, 0.0)
		_cleat_draw(ci, Vector2(cx + 3.0, z1 - 0.45) * M, 0.0)
	_coil_draw(ci, Vector2(x1 - 2.2, z1 - 1.3) * M, 0.36 * M, sd)


func paint_quay_wet(ci: CanvasItem) -> void:
	var r := Rect2(rect.position * M, rect.size * M)
	ci.draw_rect(r, Color(0.03, 0.03, 0.06, 0.3))
	for pr in plan.piers:
		ci.draw_rect(Rect2(Vector2(float(pr["x0"]) - EDGE, float(pr["z0"])) * M, Vector2(float(pr["x1"]) - float(pr["x0"]) + EDGE, float(pr["z1"]) - float(pr["z0"])) * M), Color(0.03, 0.03, 0.06, 0.28))
	var sd := GroundUtil.hseed(plan.seed_value, 73, 5)
	for k in 22:
		var c := Vector2(GroundUtil.rr(sd, k, rect.position.x + 1.0, rect.end.x - 1.5), GroundUtil.rr(sd, 50 + k, plan.bounds.position.y, plan.bounds.end.y)) * M
		GroundStreets.puddle(ci, c, GroundUtil.rr(sd, 100 + k, 0.3, 0.8) * M, sd + k, Vector2(0.9, 1.5))


# ================================================================== props

func paint_shadows(ci: CanvasItem) -> void:
	for p in props:
		var c: Vector2 = p["p"]
		match p["t"]:
			"bollard": GroundUtil.shadow_circle(ci, c, 0.27 * M, GroundUtil.sh(0.55))
			"cleat": GroundUtil.shadow_poly(ci, GroundUtil.orect(c, Vector2(0.14, 0.5) * M, 0.0), GroundUtil.sh(0.15))
			"quaylamp":
				GroundUtil.shadow_pole(ci, c, 4.8, 4.0)
				var o := GroundUtil.sh(4.9)
				for dz: float in [-0.55, 0.55]:
					GroundUtil.shadow_circle(ci, c + Vector2(0, float(dz)) * M, 0.2 * M, o)
				ci.draw_line(c + Vector2(0, -0.55) * M + o, c + Vector2(0, 0.55) * M + o, GroundUtil.SH, 3.0, true)
			"lantern": GroundUtil.shadow_pole(ci, c, 2.2, 3.0)
			"crates", "barrels", "sacks", "net":
				var foot: Vector2 = p["foot"]
				var h := 0.9 * float((p["size"] as Vector2).x) if p["t"] == "crates" else 0.9
				GroundUtil.shadow_poly(ci, GroundUtil.rect_pts(Rect2(c - foot * 0.5 * M, foot * M)), GroundUtil.sh(minf(h, 2.2) * 0.8))
			"coil": GroundUtil.shadow_circle(ci, c, 0.36 * M, GroundUtil.sh(0.12))
			"shack": GroundUtil.shadow_poly(ci, GroundUtil.rect_pts(Rect2(c - Vector2(1.0, 0.8) * M, Vector2(2.0, 1.6) * M)), GroundUtil.sh(2.3))
			"handtruck": GroundUtil.shadow_poly(ci, GroundUtil.orect(c, Vector2(0.55, 1.2) * M, 0.4), GroundUtil.sh(0.4))
			"crane": _crane_shadow(ci, p)


func paint_bodies(ci: CanvasItem) -> void:
	for p in props:
		var c: Vector2 = p["p"]
		var s: int = p["s"]
		match p["t"]:
			"bollard": _bollard(ci, c, s, bool(p.get("rope", false)))
			"cleat": _cleat_draw(ci, c, 0.0)
			"quaylamp": _quaylamp_base(ci, c)
			"lantern":
				_c(ci, c, 0.1 * M, Color("2a2622"))
				_c(ci, c + Vector2(-1, -1), 0.06 * M, Color("5a5048"))
			"crates": _crates(ci, c, p["size"], s)
			"barrels": _barrels(ci, c, p["size"], s)
			"sacks": _sacks(ci, c, s, false)
			"net": _sacks(ci, c, s, true)
			"coil": _coil_draw(ci, c, 0.36 * M, s)
			"shack": _shack(ci, c, s)
			"handtruck": _handtruck(ci, c)
			"crane": _crane_base(ci, p)


func paint_high(ci: CanvasItem) -> void:
	for p in props:
		match p["t"]:
			"quaylamp": _quaylamp_head(ci, p["p"])
			"lantern": _lantern(ci, p["p"])
			"crane": _crane_boom(ci, p)


func paint_glow(ci: CanvasItem) -> void:
	for p in props:
		var c: Vector2 = p["p"]
		match p["t"]:
			"quaylamp":
				for dz: float in [-0.55, 0.55]:
					var g := c + Vector2(0, float(dz)) * M
					GroundUtil.soft(ci, g, Vector2(0.9, 0.9) * M, Color(Pal.LAMP, 0.35), 0.0, 4)
					_c(ci, g, 0.2 * M, Color(1.0, 0.92, 0.75))
			"lantern":
				GroundUtil.soft(ci, c, Vector2(0.7, 0.7) * M, Color(1.0, 0.7, 0.4, 0.4), 0.0, 4)
				_c(ci, c, 0.12 * M, Color(1.0, 0.85, 0.6))


func _bollard(ci: CanvasItem, c: Vector2, s: int, rope: bool) -> void:
	var L := GroundUtil.LIGHT_DIR
	_c(ci, c, 0.28 * M, Color("1a1b1c"))
	_c(ci, c, 0.24 * M, Color("2c2e30"))
	_c(ci, c + L * 2.0, 0.17 * M, Color("3c3f42"))
	ci.draw_arc(c, 0.22 * M, PI * 1.0, PI * 1.5, 10, Color(1, 1, 1, 0.25), 1.6, true)
	_c(ci, c, 0.08 * M, Color("25272a"))
	if rope:
		ci.draw_arc(c, 0.27 * M, 0.0, TAU, 20, Pal.ROPE.darkened(0.15), 3.0, true)
		var end := c + Vector2(1.6, GroundUtil.rr(s, 1, -0.6, 0.6)) * M
		ci.draw_line(c + Vector2(0.26 * M, 0), end, Pal.ROPE.darkened(0.2), 3.0, true)


func _cleat_draw(ci: CanvasItem, c: Vector2, rot: float) -> void:
	ci.draw_colored_polygon(GroundUtil.orect(c, Vector2(0.12, 0.48) * M, rot), Color("202224"))
	ci.draw_colored_polygon(GroundUtil.orect(c, Vector2(0.2, 0.14) * M, rot), Color("2c2e30"))
	ci.draw_line(c + Vector2(-2, -0.2 * M), c + Vector2(-2, 0.2 * M), Color(1, 1, 1, 0.2), 1.0, true)


func _coil_draw(ci: CanvasItem, c: Vector2, r: float, s: int) -> void:
	_c(ci, c, r, Pal.ROPE.darkened(0.35))
	var rr := r - 2.0
	var k := 0
	while rr > 3.0:
		k += 1
		ci.draw_arc(c, rr, 0.0, TAU, 22, Pal.ROPE.lightened(0.08) if k % 2 == 0 else Pal.ROPE.darkened(0.08), 2.4, true)
		rr -= 3.2
	var a := GroundUtil.r01(s, 1) * TAU
	ci.draw_line(c + Vector2(cos(a), sin(a)) * r, c + Vector2(cos(a + 0.6), sin(a + 0.6)) * r * 2.0, Pal.ROPE.darkened(0.1), 2.6, true)
	ci.draw_arc(c, r - 1.0, PI, PI * 1.5, 8, Color(1, 1, 1, 0.2), 1.2, true)


func _quaylamp_base(ci: CanvasItem, c: Vector2) -> void:
	_c(ci, c, 0.22 * M, Color("1e2023"))
	_c(ci, c + Vector2(-1, -1), 0.17 * M, Color("2c2f33"))
	_c(ci, c, 0.08 * M, Color("4a4e53"))


func _quaylamp_head(ci: CanvasItem, c: Vector2) -> void:
	ci.draw_line(c + Vector2(0, -0.58) * M, c + Vector2(0, 0.58) * M, Color("24272a"), 4.0, true)
	_c(ci, c, 0.07 * M, Color("4a4e53"))
	for dz: float in [-0.55, 0.55]:
		var g := c + Vector2(0, float(dz)) * M
		_c(ci, g, 0.21 * M, Color("2b2e31"))
		_c(ci, g, 0.18 * M, Color("d8d0b8"))
		_c(ci, g + Vector2(-1.5, -1.5), 0.08 * M, Color(1, 1, 1, 0.6))
		_c(ci, g, 0.05 * M, Color("24272a"))


func _lantern(ci: CanvasItem, c: Vector2) -> void:
	_c(ci, c, 0.17 * M, Color("2a2622"))
	_c(ci, c, 0.13 * M, Color("c8b890"))
	var cap := GroundUtil.orect(c, Vector2(0.18, 0.18) * M, PI * 0.25)
	Draw.poly(ci, cap, Color("2a2622"))
	_c(ci, c + Vector2(-1, -1), 0.03 * M, Color("7a6a5a"))


func _crates(ci: CanvasItem, c: Vector2, size: Vector2, s: int) -> void:
	var nx := int(size.x)
	var ny := int(size.y)
	var cw := 1.05 * M
	var chh := 0.75 * M
	var origin := c - Vector2(nx * cw, ny * chh) * 0.5
	var heights := {}
	for ix in nx:
		for iy in ny:
			heights[Vector2i(ix, iy)] = GroundUtil.ri(s, ix * 7 + iy, 1, 3)
	for h: int in [1, 2, 3]:
		for key in heights:
			if int(heights[key]) != h:
				continue
			var k2: Vector2i = key
			var r := Rect2(origin + Vector2(k2.x * cw, k2.y * chh), Vector2(cw, chh)).grow(-1.5)
			_crate_top(ci, r, s + k2.x * 13 + k2.y * 5, h)
		for key in heights:
			if int(heights[key]) > h:
				var k3: Vector2i = key
				var r2 := Rect2(origin + Vector2(k3.x * cw, k3.y * chh), Vector2(cw, chh))
				# a taller neighbour's shadow across the lower tops
				var o := GroundUtil.sh(0.9 * float(int(heights[key]) - h))
				ci.draw_colored_polygon(GroundUtil.rect_pts(Rect2(r2.position + o, r2.size)), Color(0, 0, 0.03, 0.2))


func _crate_top(ci: CanvasItem, r: Rect2, s: int, h: int) -> void:
	if h >= 2:
		# the crate below peeks out from under this one, stacked a little askew
		_crate_face(ci, r, s + 101, h - 1)
		var j := Vector2(GroundUtil.rr(s, 7, -3.0, 3.0), GroundUtil.rr(s, 8, -2.5, 2.5))
		r = Rect2(r.position + j, r.size).grow(-1.0)
		ci.draw_colored_polygon(GroundUtil.rect_pts(Rect2(r.position + Vector2(2.5, 3.0), r.size)), Color(0, 0, 0.03, 0.3))
	_crate_face(ci, r, s, h)


func _crate_face(ci: CanvasItem, r: Rect2, s: int, h: int) -> void:
	var fresh := GroundUtil.r01(s, 1) < 0.5
	var wood := (Pal.ROPE.darkened(0.12) if fresh else Pal.PLANKS.lightened(0.1)).lightened(0.05 * float(h - 1) + GroundUtil.rr(s, 2, -0.05, 0.05))
	ci.draw_rect(r, wood.darkened(0.35))
	var inner := r.grow(-2.0)
	ci.draw_rect(inner, wood)
	var n := 4
	for k in range(1, n):
		var x := inner.position.x + inner.size.x * float(k) / float(n)
		ci.draw_line(Vector2(x, inner.position.y), Vector2(x, inner.end.y), Color(0, 0, 0, 0.25), 1.0, true)
	# cleats across the ends, nail heads, a stencil
	for x in [inner.position.x + 3.0, inner.end.x - 3.0]:
		ci.draw_line(Vector2(x, inner.position.y), Vector2(x, inner.end.y), wood.darkened(0.2), 4.0, true)
	ci.draw_rect(Rect2(inner.position, Vector2(inner.size.x, 1.2)), Color(1, 1, 1, 0.15))
	ci.draw_rect(Rect2(inner.position + Vector2(0, inner.size.y - 1.2), Vector2(inner.size.x, 1.2)), Color(0, 0, 0, 0.2))
	var mark := GroundUtil.ri(s, 3, 0, 4)
	var mc := inner.get_center()
	var ink := Color(0.12, 0.08, 0.05, 0.55)
	match mark:
		0:
			ci.draw_line(mc + Vector2(-6, -5), mc + Vector2(6, 5), ink, 1.6, true)
			ci.draw_line(mc + Vector2(-6, 5), mc + Vector2(6, -5), ink, 1.6, true)
		1:
			ci.draw_arc(mc, 5.0, 0.0, TAU, 14, ink, 1.4, true)
		2:
			var f := W.font("cond")
			var word: String = ["OLIVE OIL", "LEMONS", "MACHINERY", "TINNED FISH", "CANNED PEAS", "HARDWARE"][GroundUtil.ri(s, 4, 0, 5)]
			var fs := 8
			var tw := f.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			ci.draw_string(f, mc + Vector2(-tw * 0.5, 3), word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
		_:
			ci.draw_rect(Rect2(mc - Vector2(7, 3), Vector2(14, 6)), Color(ink, 0.3))


func _barrels(ci: CanvasItem, c: Vector2, size: Vector2, s: int) -> void:
	var nx := int(size.x)
	var ny := int(size.y)
	var d := 0.66 * M
	var origin := c - Vector2(nx, ny) * d * 0.5
	for ix in nx:
		for iy in ny:
			var bc := origin + Vector2(ix + 0.5, iy + 0.5) * d
			barrel(ci, bc, 0.3 * M, s + ix * 5 + iy)


static func barrel(ci: CanvasItem, c: Vector2, r: float, s: int) -> void:
	var wood := Pal.FLOOR_WOOD.lightened(GroundUtil.rr(s, 1, -0.1, 0.1))
	_c(ci, c, r, Color("2a221a"))
	_c(ci, c, r - 1.5, wood.darkened(0.15))
	ci.draw_arc(c, r * 0.85, 0.0, TAU, 20, Color("2c2a28"), 2.2, true)
	_c(ci, c, r * 0.7, wood)
	for k in 4:
		var y := (float(k) - 1.5) * r * 0.32
		var h := sqrt(maxf(0.0, r * 0.7 * r * 0.7 - y * y))
		ci.draw_line(c + Vector2(-h, y), c + Vector2(h, y), Color(0, 0, 0, 0.22), 1.0, true)
	_c(ci, c + Vector2(r * 0.3, 0), 1.8, Color("2a1e14"))
	ci.draw_arc(c, r - 1.0, PI, PI * 1.5, 8, Color(1, 1, 1, 0.2), 1.3, true)


func _sacks(ci: CanvasItem, c: Vector2, s: int, net: bool) -> void:
	var n := 7
	var burlap := Pal.ROPE.darkened(0.2)
	var pts_all := []
	for k in n:
		var q := c + Vector2(GroundUtil.rr(s, 10 + k, -0.6, 0.6), GroundUtil.rr(s, 20 + k, -0.45, 0.45)) * M
		var rot := GroundUtil.rr(s, 30 + k, -0.5, 0.5)
		var col := burlap.lightened(GroundUtil.rr(s, 40 + k, -0.08, 0.1))
		var body := GroundUtil.blob(q, 0.3 * M, s + k, 12, 0.12, Vector2(1.3, 0.85), rot)
		ci.draw_colored_polygon(body, col.darkened(0.3))
		ci.draw_colored_polygon(GroundUtil.blob(q + Vector2(-1, -1), 0.26 * M, s + k, 12, 0.12, Vector2(1.3, 0.85), rot), col)
		ci.draw_colored_polygon(GroundUtil.blob(q + Vector2(-3, -3), 0.12 * M, s + k + 50, 10, 0.2, Vector2(1.3, 0.85), rot), col.lightened(0.12))
		var tie := q + Vector2(0.36 * M, 0).rotated(rot)
		_c(ci, tie, 3.0, col.darkened(0.2))
		pts_all.append(q)
	if net:
		# a rope cargo net thrown over the pile, gathered to a ring at the top
		var ring := c + Vector2(-2, -3)
		var R := 0.95 * M
		for k in 12:
			var a := TAU * float(k) / 12.0
			ci.draw_line(ring, c + Vector2(cos(a) * R, sin(a) * R * 0.8), Color(Pal.ROPE.lightened(0.1), 0.85), 1.4, true)
		for rr: float in [0.35, 0.6, 0.85]:
			ci.draw_polyline(_ellipse_loop(c, Vector2(R, R * 0.8) * float(rr)), Color(Pal.ROPE.lightened(0.1), 0.8), 1.3, true)
		_c(ci, ring, 5.0, Color("2a2826"))
		_c(ci, ring, 3.2, Color("5a5550"))


func _ellipse_loop(c: Vector2, r: Vector2) -> PackedVector2Array:
	var pts := Draw.ellipse_points(c, r, 0.0, 20)
	pts.append(pts[0])
	return pts


func _shack(ci: CanvasItem, c: Vector2, s: int) -> void:
	var r := Rect2(c - Vector2(1.0, 0.8) * M, Vector2(2.0, 1.6) * M)
	ci.draw_rect(r.grow(2.0), Color("2a2420"))
	# tar-paper roof in two slopes, battens, a stovepipe
	var mid := r.position.y + r.size.y * 0.5
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * 0.5)), Pal.TAR_2.lightened(0.08))
	ci.draw_rect(Rect2(Vector2(r.position.x, mid), Vector2(r.size.x, r.size.y * 0.5)), Pal.TAR_2.darkened(0.1))
	var x := r.position.x + 10.0
	while x < r.end.x - 4.0:
		ci.draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), Color(0, 0, 0, 0.25), 1.5, true)
		x += 16.0
	ci.draw_line(Vector2(r.position.x, mid), Vector2(r.end.x, mid), Pal.TAR_2.lightened(0.25), 2.0, true)
	_c(ci, r.position + Vector2(r.size.x * 0.75, r.size.y * 0.3), 4.0, Color("1a1a1a"))
	_c(ci, r.position + Vector2(r.size.x * 0.75, r.size.y * 0.3), 2.5, Color("3a3a3a"))


func _handtruck(ci: CanvasItem, c: Vector2) -> void:
	var rot := 0.4
	var t := Transform2D(rot, c)
	ci.draw_set_transform_matrix(t)
	for x: float in [-0.22, 0.22]:
		ci.draw_line(Vector2(float(x) * M, -0.6 * M), Vector2(float(x) * M, 0.5 * M), Color("3a2e24"), 3.0, true)
	for y: float in [-0.3, 0.0, 0.3]:
		ci.draw_line(Vector2(-0.22 * M, float(y) * M), Vector2(0.22 * M, float(y) * M), Color("3a2e24"), 2.0, true)
	ci.draw_rect(Rect2(-0.26 * M, 0.5 * M, 0.52 * M, 0.12 * M), Color("2a2a2a"))
	for x: float in [-0.3, 0.3]:
		ci.draw_rect(Rect2(float(x) * M - 2.0, 0.25 * M, 4.0, 0.4 * M), Color("141414"))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ------------------------------------------------------------------ the crane

func _boom_tip(p: Dictionary) -> Vector2:
	return (p["p"] as Vector2) + Vector2(float(p["len"]) * M, 0).rotated(float(p["boom"]))


func _crane_shadow(ci: CanvasItem, p: Dictionary) -> void:
	var c: Vector2 = p["p"]
	var tip := _boom_tip(p)
	GroundUtil.shadow_poly(ci, GroundUtil.orect(c, Vector2(2.2, 2.2) * M, 0.0), GroundUtil.sh(0.5), 0.8)
	GroundUtil.shadow_pole(ci, c, 9.0, 6.0)
	var col := Color(GroundUtil.SH, 0.22)
	ci.draw_line(c + GroundUtil.sh(3.0), tip + GroundUtil.sh(8.5), col, 8.0, true)
	GroundUtil.shadow_circle(ci, tip, 0.7 * M, GroundUtil.sh(4.5))


func _crane_base(ci: CanvasItem, p: Dictionary) -> void:
	var c: Vector2 = p["p"]
	var timber := Pal.PLANKS_DARK.darkened(0.1)
	for a in [PI * 0.25, -PI * 0.25]:
		var beam := GroundUtil.orect(c, Vector2(4.2, 0.36) * M, float(a))
		ci.draw_colored_polygon(beam, timber)
		GroundUtil.outline(ci, beam, timber.darkened(0.4), 1.2)
		for e: float in [-1.0, 1.0]:
			_c(ci, c + Vector2(2.0 * M * e, 0).rotated(float(a)), 3.0, Color("1c1c1c"))
	# the winch with its drum and crank
	var wr := Rect2(c + Vector2(-1.6, 0.5) * M, Vector2(0.9, 0.7) * M)
	ci.draw_rect(wr, Color("2c2e30"))
	_c(ci, wr.get_center(), 0.26 * M, Color("1a1b1c"))
	_c(ci, wr.get_center(), 0.2 * M, Pal.ROPE.darkened(0.2))
	ci.draw_line(wr.position + Vector2(0, wr.size.y * 0.5), wr.position + Vector2(-0.3 * M, wr.size.y * 0.5 - 0.2 * M), Color("3a3a3a"), 2.5, true)
	_c(ci, c, 0.38 * M, Color("1c1d1e"))
	_c(ci, c + Vector2(-1.5, -1.5), 0.3 * M, Color("34373a"))


func _crane_boom(ci: CanvasItem, p: Dictionary) -> void:
	var c: Vector2 = p["p"]
	var tip := _boom_tip(p)
	var d := (tip - c).normalized()
	var n := Vector2(-d.y, d.x)
	var wood := Pal.PLANKS.darkened(0.05)
	# guy lines from the mast top to the ground, the topping lift to the boom head
	for g in [Vector2(-5.0, -4.5), Vector2(-5.5, 4.0), Vector2(1.5, 6.0)]:
		ci.draw_line(c, c + (g as Vector2) * M, Color(0.1, 0.09, 0.08, 0.7), 1.2, true)
	ci.draw_line(c + n * 2.0, tip, Color(0.12, 0.1, 0.08, 0.7), 1.2, true)
	# the boom: two timbers with cross bracing
	var w0 := 0.22 * M
	var w1 := 0.1 * M
	var a0 := c + d * 0.3 * M
	for e: float in [-1.0, 1.0]:
		ci.draw_line(a0 + n * w0 * e, tip + n * w1 * e, wood.darkened(0.25), 4.0, true)
		ci.draw_line(a0 + n * w0 * e, tip + n * w1 * e, wood, 2.2, true)
	var segs := 10
	for k in segs:
		var t0 := float(k) / float(segs)
		var t1 := float(k + 1) / float(segs)
		var p0 := a0.lerp(tip, t0) + n * lerpf(w0, w1, t0) * (1.0 if k % 2 == 0 else -1.0)
		var p1 := a0.lerp(tip, t1) + n * lerpf(w0, w1, t1) * (-1.0 if k % 2 == 0 else 1.0)
		ci.draw_line(p0, p1, wood.darkened(0.15), 1.6, true)
	# the mast cap, the hook block with a sling of crates hanging over the water
	_c(ci, c, 0.3 * M, Color("24262a"))
	_c(ci, c + Vector2(-1.2, -1.2), 0.18 * M, Color("4a4e53"))
	_c(ci, tip, 0.12 * M, Color("202224"))
	var load := tip + Vector2(0.1, 0.25) * M
	ci.draw_line(tip, load, Color(0.1, 0.09, 0.08, 0.8), 1.4, true)
	var lr := Rect2(load - Vector2(0.55, 0.4) * M, Vector2(1.1, 0.8) * M)
	_crate_top(ci, lr, 5, 2)
	for k in 5:
		var y := lr.position.y + lr.size.y * float(k) / 4.0
		ci.draw_line(Vector2(lr.position.x - 2, y), Vector2(lr.end.x + 2, y), Color(Pal.ROPE, 0.75), 1.2, true)
	for k in 5:
		var x := lr.position.x + lr.size.x * float(k) / 4.0
		ci.draw_line(Vector2(x, lr.position.y - 2), Vector2(x, lr.end.y + 2), Color(Pal.ROPE, 0.75), 1.2, true)
	_c(ci, load, 3.5, Color("2a2826"))
