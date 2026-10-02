class_name G3Yards
extends RefCounted
## The backyards in the middle of each block: dirt, board fences with gates, privies, sheds, barrels,
## tubs, woodpiles, vegetable patches, coops, laundry lines with the wash on them, a cat.

const Y := 0.014
const WOOD := Color("857866")
const GARMENT_COLS := [Color("ece6d6"), Color("dcd4c0"), Color("a8b8c8"), Color("c0ae8e"), Color("c89a90"), Color("7f90a8"),
	Color("e4dccb"), Color("a0584a"), Color("8a9a7a"), Color("d8c89a")]

var lay: GroundLayout
var B: G3Bundle
var yards: GroundYards


func _init(layout: GroundLayout, bundle: G3Bundle) -> void:
	lay = layout
	B = bundle
	yards = GroundYards.new(layout)


func build() -> void:
	for b in lay.blocks:
		if b["phantom"] or (b["yard"] as Dictionary).is_empty():
			continue
		yards.plan_yard(b)
		_yard(b)


func _yard(b: Dictionary) -> void:
	var yp: Dictionary = b["yard_plan"]
	var rm: Rect2 = yp["r"]
	var s: int = yp["s"]
	var cell := B.at(rm.get_center())
	# packed dirt, trampled paths, flagstones, weeds
	cell.dirt.flat(rm.position.x, rm.position.y, rm.end.x, rm.end.y, Y, Color(1.0, 0.96, 0.9))
	for yr: Rect2 in yp["yards"]:
		# darker worn ground where people walk
		cell.paint.poly_flat(G3Mesh.blob_pts(yr.get_center(), yr.size.x * 0.34, yr.size.y * 0.3, s + int(yr.position.x * 3.0), 12, 0.25), Y + 0.003, Color(0.15, 0.1, 0.07, 0.22))
	for pth in yp["paths"]:
		var c: Vector2 = pth[0]
		var ps: int = pth[1]
		for k in 6:
			var o := Vector2(GroundUtil.rr(ps, 10 + k, -0.8, 0.8), GroundUtil.rr(ps, 20 + k, -0.8, 0.8))
			cell.stone.box(Vector3(c.x + o.x, Y + 0.012, c.y + o.y), Vector3(GroundUtil.rr(ps, 30 + k, 0.35, 0.6), 0.024, GroundUtil.rr(ps, 40 + k, 0.3, 0.5)), Color("8a8478").darkened(GroundUtil.rr(ps, 50 + k, 0.0, 0.15)))
	for k in 14:
		var wp := Vector2(GroundUtil.rr(s, 700 + k, rm.position.x + 0.3, rm.end.x - 0.3), GroundUtil.rr(s, 720 + k, rm.position.y + 0.3, rm.end.y - 0.3))
		for q in 3:
			var a := GroundUtil.rr(s, 740 + k * 3 + q, 0.0, TAU)
			cell.props.rod(Vector3(wp.x, Y, wp.y), Vector3(wp.x + cos(a) * 0.08, Y + GroundUtil.rr(s, 760 + k + q, 0.1, 0.22), wp.y + sin(a) * 0.08), 0.008, Color("5a7a3a").darkened(GroundUtil.rr(s, 780 + k, 0.0, 0.25)))
	for f in yp["fences"]:
		_fence(cell, f, s)
	for it in yp["items"]:
		_item(cell, it)
	if GroundUtil.r01(s, 801) < 0.4:
		var tp := Vector2(GroundUtil.rr(s, 802, rm.position.x + 1.2, rm.end.x - 1.2), GroundUtil.rr(s, 803, rm.position.y + 1.2, rm.end.y - 1.2))
		var clash := false
		for it in yp["items"]:
			if (it["r"] as Rect2).grow(0.5).has_point(tp):
				clash = true
		if not clash:
			cell.push_at(Vector3(tp.x, Y, tp.y), 0.0)
			G3Props.yard_tree(cell, s)
			cell.pop()
	for k in yp["lines"].size():
		_line(cell, yp["lines"][k])
	_cat(cell, yp["cat"])


func _fence(cell: G3Bundle.Cell, f: Array, s: int) -> void:
	var a: Vector2 = f[0]
	var e: Vector2 = f[1]
	var gate: float = f[2]
	var d := e - a
	var l := d.length()
	var dir := d / l
	var fh := 1.55
	var g0 := gate * l - 0.45
	var g1 := gate * l + 0.45
	var t := 0.0
	var k := 0
	cell.push_at(Vector3(a.x, 0, a.y), -atan2(dir.y, dir.x))
	var board := 0.16
	while t < l - 0.02:
		k += 1
		var tl := minf(board, l - t)
		if (t + tl > g0 and t < g1) or GroundUtil.r01(s + int(a.x + a.y), k) < 0.05:
			t += tl
			continue
		var h := fh + GroundUtil.rr(s + int(a.x), k, -0.12, 0.1)
		var col := WOOD.lightened(GroundUtil.rr(s + int(a.x), k, -0.14, 0.1))
		cell.wood.box(Vector3(t + tl * 0.5, Y + h * 0.5, 0.0), Vector3(tl - 0.012, h, 0.035), col, col.lightened(0.15))
		t += tl
	# bills pasted on the boards
	for q in 2:
		if GroundUtil.r01(s + int(a.x), 900 + q) < 0.6:
			var bx := GroundUtil.rr(s + int(a.y), 910 + q, 0.5, maxf(l - 0.6, 0.6))
			if bx > g0 - 0.5 and bx < g1 + 0.5:
				continue
			var bc: Color = G3Props.AWN[GroundUtil.ri(s, 920 + q, 0, 5)].lightened(0.35) if GroundUtil.r01(s, 930 + q) < 0.5 else Color("d9d1b8")
			cell.props.box(Vector3(bx, Y + 0.95, 0.025), Vector3(0.5, 0.7, 0.01), bc)
			cell.props.box(Vector3(bx, Y + 1.15, 0.032), Vector3(0.4, 0.12, 0.004), Color("1c1410"))
	# rails and posts
	for ry in [0.35, 1.15]:
		cell.wood.box(Vector3(l * 0.5, Y + ry, 0.05), Vector3(l, 0.07, 0.04), WOOD.darkened(0.25))
	var pt := 0.0
	while pt <= l + 0.1:
		cell.wood.box(Vector3(minf(pt, l), Y + (fh + 0.1) * 0.5, 0.0), Vector3(0.1, fh + 0.1, 0.1), WOOD.darkened(0.3), WOOD.darkened(0.1))
		pt += 1.8
	# the gate hangs half open
	cell.wood.push_at(Vector3(g0, 0, 0), 0.9)
	for q in 5:
		cell.wood.box(Vector3(0.09 + float(q) * 0.17, Y + 0.75, 0.0), Vector3(0.15, 1.45, 0.03), WOOD.darkened(0.1))
	cell.wood.box(Vector3(0.45, Y + 0.5, 0.03), Vector3(0.9, 0.06, 0.03), WOOD.darkened(0.3))
	cell.wood.pop()
	cell.pop()


func _item(cell: G3Bundle.Cell, it: Dictionary) -> void:
	var r: Rect2 = it["r"]
	var c := r.get_center()
	var s: int = it["s"]
	var t: String = it["t"]
	cell.push_at(Vector3(c.x, Y, c.y), 0.0)
	var sx := r.size.x
	var sz := r.size.y
	match t:
		"privy":
			cell.wood.box(Vector3(0, 1.05, 0), Vector3(sx, 2.1, sz), Color("6a5a48"), Color("5a4c3c"))
			cell.props.gable(Vector3(0, 2.1, 0), sx + 0.2, sz + 0.2, 0.28, Color("3a3532"), Color("6a5a48"), true)
			cell.wood.box(Vector3(0, 0.95, sz * 0.5 + 0.01), Vector3(0.55, 1.7, 0.03), Color("4a3a2c"))
			cell.metal.box(Vector3(0.18, 0.95, sz * 0.5 + 0.03), Vector3(0.04, 0.1, 0.03), Color("8a8a8a"))
		"shed":
			cell.wood.box(Vector3(0, 1.1, 0), Vector3(sx, 2.2, sz), Color("7a6850"), Color("6a5a46"))
			cell.props.gable(Vector3(0, 2.2, 0), sx + 0.25, sz + 0.25, 0.4, Color("4a4038"), Color("7a6850"), true)
			cell.wood.box(Vector3(-sx * 0.2, 0.95, sz * 0.5 + 0.01), Vector3(0.8, 1.8, 0.03), Color("52422f"))
			cell.glow.box(Vector3(sx * 0.25, 1.4, sz * 0.5 + 0.015), Vector3(0.4, 0.4, 0.02), Color(0.9, 0.7, 0.4, 0.5))
		"barrels":
			var nx := maxi(1, int(sx / 0.62))
			var nz := maxi(1, int(sz / 0.62))
			for ix in nx:
				for iz in nz:
					var bx := (float(ix) + 0.5 - float(nx) * 0.5) * 0.62
					var bz := (float(iz) + 0.5 - float(nz) * 0.5) * 0.62
					_barrel(cell, Vector3(bx, 0, bz), s + ix * 5 + iz)
		"washtub":
			cell.metal.cyl(Vector3(0, 0, 0), 0.38, 0.45, 0.32, 10, Color("8f9498"), false)
			cell.props.disc(Vector3(0, 0.3, 0), 0.43, 10, Color("4a5a64"))
			cell.metal.ring_flat(Vector3(0, 0.325, 0), 0.4, 0.46, 10, Color("a9aeb2"))
			cell.wood.box(Vector3(0.5, 0.35, 0.1), Vector3(0.28, 0.6, 0.03), Color("a08a60"))
		"woodpile":
			for layer in 4:
				var n := int(sx / 0.15)
				for k in n:
					var lx := -sx * 0.5 + 0.08 + float(k) * 0.15 + (0.07 if layer % 2 == 1 else 0.0)
					if lx > sx * 0.5 - 0.05:
						continue
					cell.wood.box(Vector3(lx, 0.07 + float(layer) * 0.14, 0), Vector3(0.13, 0.13, sz * 0.85), Color("6a4a30").lightened(GroundUtil.rr(s, k + layer * 20, -0.1, 0.12)), Color("8a6a44"))
		"crates":
			for ix in 2:
				var h := 2 if GroundUtil.r01(s, ix) < 0.5 else 1
				for ly in h:
					_crate(cell, Vector3((float(ix) - 0.5) * (sx * 0.5 + 0.02), float(ly) * 0.42, 0.0), minf(sx * 0.5, 0.5), s + ix + ly)
		"patch":
			var rows := 3
			for ir in rows:
				var zz := (float(ir) + 0.5 - float(rows) * 0.5) * (sz / float(rows))
				cell.dirt.box(Vector3(0, 0.05, zz), Vector3(sx, 0.1, 0.32), Color(0.55, 0.45, 0.38))
				var n := int(sx / 0.4)
				for k in n:
					var gx := -sx * 0.5 + 0.2 + float(k) * 0.4
					cell.leaf.blob(Vector3(gx, 0.17, zz), Vector3(0.14, 0.1, 0.14), Color("5e8a3e").lightened(GroundUtil.rr(s, k + ir * 9, -0.1, 0.12)), 2, 6, 0.1, s + k)
			for sxs in [-sx * 0.5, sx * 0.5]:
				cell.wood.box(Vector3(sxs, 0.35, sz * 0.5), Vector3(0.03, 0.7, 0.03), Color("6a5a40"))
		"coop":
			for lx in [-0.5, 0.5]:
				for lz in [-0.3, 0.3]:
					cell.wood.box(Vector3(lx, 0.25, lz), Vector3(0.06, 0.5, 0.06), Color("5a4a38"))
			cell.wood.box(Vector3(-0.1, 0.78, 0), Vector3(1.1, 0.55, 0.8), Color("8a7a60"))
			cell.props.gable(Vector3(-0.1, 1.05, 0), 1.25, 0.95, 0.28, Color("4a4038"), Color("8a7a60"), true)
			cell.wood.box(Vector3(-0.1, 0.7, 0.41), Vector3(0.25, 0.3, 0.02), Color("2a2018"))
			# the wire run
			for k in 6:
				cell.metal.box(Vector3(0.5 + float(k) * 0.1, 0.3, 0), Vector3(0.012, 0.6, sz * 0.9), Color("8a8e90"))
			cell.props.blob(Vector3(0.8, 0.07, 0.2), Vector3(0.1, 0.08, 0.07), Color("a0522d"), 2, 6)
			cell.props.blob(Vector3(0.6, 0.07, -0.2), Vector3(0.1, 0.08, 0.07), Color("e6dcc3"), 2, 6)
		"cans":
			cell.pop()
			cell.push_at(Vector3(c.x, Y, c.y), 0.0)
			G3Props.ashcans(cell, s, 2)
		"chair":
			cell.wood.box(Vector3(0, 0.42, 0), Vector3(0.38, 0.04, 0.38), Color("8a6a44"))
			for lx in [-0.16, 0.16]:
				for lz in [-0.16, 0.16]:
					cell.wood.box(Vector3(lx, 0.2, lz), Vector3(0.035, 0.4, 0.035), Color("6a4a30"))
			cell.wood.box(Vector3(0, 0.7, -0.18), Vector3(0.38, 0.5, 0.03), Color("8a6a44"))
	cell.pop()


func _barrel(cell: G3Bundle.Cell, p: Vector3, s: int) -> void:
	var col := Color("6a4a30").lightened(GroundUtil.rr(s, 1, -0.08, 0.1))
	cell.wood.cyl(p, 0.27, 0.3, 0.45, 9, col, false)
	cell.wood.cyl(p + Vector3(0, 0.45, 0), 0.3, 0.26, 0.4, 9, col, true, col.lightened(0.15))
	for hy in [0.1, 0.45, 0.8]:
		cell.metal.cyl(p + Vector3(0, hy, 0), 0.305, 0.305, 0.025, 9, Color("2a2a2c"), false)


func _crate(cell: G3Bundle.Cell, p: Vector3, size: float, s: int) -> void:
	var col := Color("a08358").darkened(GroundUtil.rr(s, 1, 0.0, 0.25))
	cell.wood.box(p + Vector3(0, 0.2, 0), Vector3(size, 0.4, size * 0.9), col, col.lightened(0.1))
	for k in 3:
		cell.wood.box(p + Vector3(0, 0.07 + float(k) * 0.13, 0), Vector3(size + 0.012, 0.025, size * 0.9 + 0.012), col.darkened(0.3))


func _line(cell: G3Bundle.Cell, ln: Array) -> void:
	var a: Vector2 = ln[0]
	var e: Vector2 = ln[1]
	var s: int = ln[2]
	var h0 := 4.6
	var d := e - a
	var l := d.length()
	var dir := d / l
	var prev := Vector3(a.x, h0, a.y)
	var pts := [prev]
	for k in 8:
		var t := float(k + 1) / 8.0
		var q := a.lerp(e, t)
		var nxt := Vector3(q.x, h0 - 0.28 * sin(t * PI), q.y)
		cell.props.rod(prev, nxt, 0.008, Color("6a5a48"))
		pts.append(nxt)
		prev = nxt
	# the wash: shirts, sheets, trousers, socks, dresses
	var t := GroundUtil.rr(s, 1, 0.08, 0.16)
	var k := 0
	while t < 0.92:
		k += 1
		var kind: String = ["shirt", "sheet", "trousers", "shirt", "sock", "dress", "sheet", "shirt", "trousers"][GroundUtil.ri(s, 10 + k, 0, 8)]
		var size: Vector2 = {"shirt": Vector2(0.62, 0.62), "sheet": Vector2(1.15, 0.85), "trousers": Vector2(0.42, 0.9),
			"sock": Vector2(0.28, 0.3), "dress": Vector2(0.55, 0.85)}[kind]
		var w := size.x / l
		if t + w > 0.95:
			break
		var col: Color = GARMENT_COLS[GroundUtil.ri(s, 20 + k, 0, GARMENT_COLS.size() - 1)]
		if kind == "sheet":
			col = GARMENT_COLS[GroundUtil.ri(s, 20 + k, 0, 1)]
		var q := a.lerp(e, t + w * 0.5)
		var sag := -0.28 * sin((t + w * 0.5) * PI)
		var sway := GroundUtil.rr(s, 30 + k, -0.18, 0.18)
		var yaw := -atan2(dir.y, dir.x)
		cell.props.push_at(Vector3(q.x, h0 + sag, q.y), yaw)
		cell.props.push(Transform3D(Basis(Vector3.RIGHT, sway), Vector3.ZERO))
		match kind:
			"trousers":
				for lx in [-0.1, 0.1]:
					cell.props.box(Vector3(lx, -size.y * 0.5, 0), Vector3(0.18, size.y, 0.015), col.darkened(0.15))
				cell.props.box(Vector3(0, -0.07, 0), Vector3(0.4, 0.14, 0.015), col.darkened(0.15))
			"dress":
				cell.props.box(Vector3(0, -0.15, 0), Vector3(0.3, 0.3, 0.015), col)
				cell.props.quad_out(Vector3(-0.15, -0.3, 0.0), Vector3(0.15, -0.3, 0.0), Vector3(0.27, -size.y, 0.0), Vector3(-0.27, -size.y, 0.0), Vector3(0, 0, 1), col)
				cell.props.quad_out(Vector3(-0.15, -0.3, 0.0), Vector3(0.15, -0.3, 0.0), Vector3(0.27, -size.y, 0.0), Vector3(-0.27, -size.y, 0.0), Vector3(0, 0, -1), col.darkened(0.1))
			"shirt":
				cell.props.box(Vector3(0, -size.y * 0.4, 0), Vector3(size.x * 0.6, size.y * 0.8, 0.015), col)
				cell.props.box(Vector3(0, -0.12, 0), Vector3(size.x, 0.2, 0.015), col.darkened(0.06))
			_:
				cell.props.box(Vector3(0, -size.y * 0.5, 0), Vector3(size.x, size.y, 0.012), col)
		cell.props.pop()
		cell.props.pop()
		t += w + GroundUtil.rr(s, 40 + k, 0.015, 0.06)


func _cat(cell: G3Bundle.Cell, cat: Dictionary) -> void:
	var p: Vector2 = cat["p"]
	var cols := [Color("2a2a2a"), Color("a8744a"), Color("8a8a8a"), Color("d9d1c0")]
	var col: Color = cols[int(cat["col"])]
	var y := Y + (2.2 if cat["roof"] else 0.0)
	cell.props.push_at(Vector3(p.x, y, p.y), float(cat["rot"]))
	if cat["curled"]:
		cell.props.blob(Vector3(0, 0.1, 0), Vector3(0.18, 0.09, 0.14), col, 2, 8)
		cell.props.blob(Vector3(0.12, 0.12, 0.06), Vector3(0.07, 0.065, 0.065), col.lightened(0.06), 2, 6)
	else:
		cell.props.blob(Vector3(0, 0.12, 0), Vector3(0.1, 0.1, 0.2), col, 2, 8)
		cell.props.blob(Vector3(0, 0.2, 0.2), Vector3(0.075, 0.07, 0.075), col.lightened(0.06), 2, 6)
		cell.props.rod(Vector3(0, 0.12, -0.2), Vector3(0.0, 0.25, -0.34), 0.018, col)
	cell.props.pop()
