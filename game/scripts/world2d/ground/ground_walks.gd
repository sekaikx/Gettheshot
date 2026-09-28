class_name GroundWalks
extends RefCounted
## Paints the sidewalks of a block: gutter, granite curb with rounded corners, concrete slabs with
## joints, wear and litter, and the low things set into them: stoops, areaways, cellar doors,
## vault lights, coal chutes, gratings, storm drains, tree pits. Plus the wet overlay.

const M := W.M
const SW := CityPlan.SIDEWALK
const CR := GroundLayout.CURB_R
const CURB_W := 0.3
const JOINT := Color(Pal.SLAB_JOINT, 0.9)

var lay: GroundLayout
var grain: Texture2D
var mottle: Texture2D


func _init(layout: GroundLayout) -> void:
	lay = layout
	grain = GroundTex.grain()
	mottle = GroundTex.mottle()


static func _px(r: Rect2) -> Rect2:
	return Rect2(r.position * M, r.size * M)


func paint_block(ci: CanvasItem, b: Dictionary) -> void:
	var r: Rect2 = b["r"]
	var R := _px(r)
	var sd: int = b["seed"]
	# the gutter: grime collecting along the curb, darkest right against it
	ci.draw_colored_polygon(Draw.rrect_points(R.grow(0.55 * M), (CR + 0.55) * M, 5), Color(Pal.GUTTER, 0.16))
	ci.draw_colored_polygon(Draw.rrect_points(R.grow(0.28 * M), (CR + 0.28) * M, 5), Color(Pal.GUTTER, 0.28))
	ci.draw_colored_polygon(Draw.rrect_points(R.grow(0.1 * M), (CR + 0.1) * M, 5), Color(Pal.GUTTER, 0.4))
	# the curb's own shadow, cast down-right
	ci.draw_colored_polygon(Draw.rrect_points(Rect2(R.position + Vector2(3, 4), R.size), CR * M, 5), Color(0, 0, 0.02, 0.4))
	# granite curb
	var outer := Draw.rrect_points(R, CR * M, 6)
	ci.draw_colored_polygon(outer, Pal.CURB.darkened(0.06))
	GroundUtil.tex_poly(ci, outer, grain, 1.0, Color(1, 1, 1, 0.6))
	# its outer edge catches the light on the north and west sides
	var cols := PackedColorArray()
	var edge := PackedVector2Array()
	var cen := R.get_center()
	for k in outer.size() + 1:
		var q := outer[k % outer.size()]
		var n := _edge_normal(q, R)
		var l := GroundUtil.lit(n)
		edge.append(q + (cen - q).normalized() * 1.0)
		cols.append(Color(1, 1, 1, 0.3 * l) if l > 0.0 else Color(0, 0, 0, -0.35 * l))
	ci.draw_polyline_colors(edge, cols, 2.0, true)
	# the sidewalk itself
	var inner_r := R.grow(-CURB_W * M)
	var inner := Draw.rrect_points(inner_r, (CR - CURB_W) * M, 6)
	ci.draw_colored_polygon(inner, Pal.SIDEWALK)
	GroundUtil.tex_poly(ci, inner, mottle, 11.0, Color(1, 1, 1, 0.22))
	GroundUtil.tex_poly(ci, inner, grain, 1.0, Color(1, 1, 1, 0.75))
	# slabs
	for s: String in ["N", "S", "W", "E"]:
		_slabs(ci, b, b["sides"][s], sd)
	_corner_slabs(ci, r, sd)
	# the inner edge of the curb, and the joints between curb stones
	GroundUtil.outline(ci, inner, Color(Pal.SLAB_JOINT.darkened(0.2), 0.75), 1.4)
	for s: String in ["N", "S", "W", "E"]:
		_curb_joints(ci, b["sides"][s], sd)
	# grime at the foot of the walls (they meet the roofs' edge)
	for s: String in ["N", "S", "W", "E"]:
		_wall_grime(ci, b, b["sides"][s])
	for s: String in ["N", "S", "W", "E"]:
		_wear(ci, b["sides"][s], sd)
	# the low things
	for f in b["flats"]:
		match f["t"]:
			"stoop": stoop(ci, f)
			"areaway": areaway(ci, f)
			"cellar": cellar(ci, f)
			"vault": vault(ci, f)
			"chute": chute(ci, f)
			"grating": grating(ci, f)
			"drain": drain(ci, f)
	for p in b["props"]:
		if p["t"] == "tree":
			tree_pit(ci, p)


func _edge_normal(q: Vector2, R: Rect2) -> Vector2:
	var cr := CR * M
	var cx := clampf(q.x, R.position.x + cr, R.end.x - cr)
	var cy := clampf(q.y, R.position.y + cr, R.end.y - cr)
	var n := q - Vector2(cx, cy)
	if n.length() < 0.01:
		return Vector2(0, -1)
	return n.normalized()


## Two rows of concrete slabs along one side (between the corner squares).
func _slabs(ci: CanvasItem, b: Dictionary, side: Dictionary, sd: int) -> void:
	var a0 := float(side["a0"]) + SW
	var a1 := float(side["a1"]) - SW
	if a1 - a0 < 1.0:
		return
	var ss := sd + (["N", "S", "W", "E"].find(side["s"]) + 1) * 1000
	var rows := [[0.0, 1.6], [1.6, SW - CURB_W]]
	# joint between the rows (frontage / walking) runs the whole side
	ci.draw_line(GroundLayout.side_point(side, a0, 1.6) * M, GroundLayout.side_point(side, a1, 1.6) * M, JOINT, 1.5, true)
	for ri in rows.size():
		var d0: float = rows[ri][0]
		var d1: float = rows[ri][1]
		var a := a0
		var k := 0
		var first := GroundUtil.rr(ss, 7 + ri, 0.4, 1.6)
		while a < a1 - 0.05:
			k += 1
			var l := first if k == 1 else GroundUtil.rr(ss, k * 5 + ri * 777, 1.45, 1.85)
			var b_ := minf(a + l, a1)
			if a1 - b_ < 0.5:
				b_ = a1
			var p0 := GroundLayout.side_point(side, a, d0) * M
			var p1 := GroundLayout.side_point(side, b_, d1) * M
			var rect := Rect2(Vector2(minf(p0.x, p1.x), minf(p0.y, p1.y)), (p1 - p0).abs())
			_slab(ci, rect, ss + k * 31 + ri * 7)
			if b_ < a1:
				ci.draw_line(GroundLayout.side_point(side, b_, d0) * M, GroundLayout.side_point(side, b_, d1) * M, JOINT, 1.5, true)
			a = b_


func _corner_slabs(ci: CanvasItem, r: Rect2, sd: int) -> void:
	var x0 := r.position.x
	var z0 := r.position.y
	var x1 := r.end.x
	var z1 := r.end.y
	var c := CURB_W
	var e := SW - c
	var sq := [
		[Rect2(x0 + c, z0 + c, e, e), Vector2(x0 + 1.9, z0 + 1.9), 0],
		[Rect2(x1 - SW, z0 + c, e, e), Vector2(x1 - 1.9, z0 + 1.9), 1],
		[Rect2(x1 - SW, z1 - SW, e, e), Vector2(x1 - 1.9, z1 - 1.9), 3],
		[Rect2(x0 + c, z1 - SW, e, e), Vector2(x0 + 1.9, z1 - 1.9), 2],
	]
	for k in 4:
		var rg: Rect2 = sq[k][0]
		var sp: Vector2 = sq[k][1]
		var outer: int = sq[k][2]
		ci.draw_line(Vector2(sp.x, rg.position.y) * M, Vector2(sp.x, rg.end.y) * M, JOINT, 1.5, true)
		ci.draw_line(Vector2(rg.position.x, sp.y) * M, Vector2(rg.end.x, sp.y) * M, JOINT, 1.5, true)
		var quads := [Rect2(rg.position, sp - rg.position), Rect2(Vector2(sp.x, rg.position.y), Vector2(rg.end.x - sp.x, sp.y - rg.position.y)),
			Rect2(Vector2(rg.position.x, sp.y), Vector2(sp.x - rg.position.x, rg.end.y - sp.y)), Rect2(sp, rg.end - sp)]
		for n in 4:
			if n != outer:
				_slab(ci, _px(quads[n]), sd + k * 91 + n * 13)


func _slab(ci: CanvasItem, rect: Rect2, s: int) -> void:
	if rect.size.x < 3.0 or rect.size.y < 3.0:
		return
	var v := GroundUtil.rr(s, 1, -0.08, 0.07)
	var inner := rect.grow(-0.75)
	if GroundUtil.r01(s, 2) < 0.06:
		# an old bluestone flag among the concrete
		ci.draw_rect(inner, Color("80827f", 0.5))
		GroundUtil.tex_rect(ci, inner, mottle, 5.0, Color(1, 1, 1, 0.12))
	elif v > 0.0:
		ci.draw_rect(inner, Color(1, 1, 1, v * 0.9))
	else:
		ci.draw_rect(inner, Color(0.05, 0.04, 0.03, -v * 0.9))
	# a bevel: the light catches the north and west edges
	ci.draw_rect(Rect2(inner.position, Vector2(inner.size.x, 1.2)), Color(1, 1, 1, 0.1))
	ci.draw_rect(Rect2(inner.position, Vector2(1.2, inner.size.y)), Color(1, 1, 1, 0.08))
	ci.draw_rect(Rect2(Vector2(inner.position.x, inner.end.y - 1.2), Vector2(inner.size.x, 1.2)), Color(0, 0, 0, 0.1))
	ci.draw_rect(Rect2(Vector2(inner.end.x - 1.2, inner.position.y), Vector2(1.2, inner.size.y)), Color(0, 0, 0, 0.08))
	var roll := GroundUtil.r01(s, 3)
	if roll < 0.14:
		var a := inner.position + Vector2(GroundUtil.r01(s, 4) * inner.size.x, 0)
		var b := inner.position + Vector2(GroundUtil.r01(s, 5) * inner.size.x, inner.size.y)
		if GroundUtil.r01(s, 6) < 0.5:
			a = inner.position + Vector2(0, GroundUtil.r01(s, 4) * inner.size.y)
			b = inner.position + Vector2(inner.size.x, GroundUtil.r01(s, 5) * inner.size.y)
		ci.draw_polyline(GroundUtil.jag(a, b, s, 3.0, 7), Color(Pal.SLAB_JOINT.darkened(0.3), 0.7), 1.1, true)
	elif roll < 0.2:
		# a sunken slab: its far edge dips into shadow
		Draw.vgrad(ci, Rect2(inner.position, Vector2(inner.size.x, inner.size.y * 0.5)), Color(0, 0, 0, 0.12), Color(0, 0, 0, 0))
	elif roll < 0.26:
		GroundUtil.soft_blob(ci, inner.get_center(), minf(inner.size.x, inner.size.y) * 0.3, Color(0.2, 0.17, 0.12, 0.12), s + 9)


func _curb_joints(ci: CanvasItem, side: Dictionary, sd: int) -> void:
	var a := float(side["a0"]) + CR
	var a1 := float(side["a1"]) - CR
	var k := 0
	while true:
		k += 1
		a += GroundUtil.rr(sd, k * 3 + String(side["s"]).unicode_at(0), 1.3, 2.6)
		if a > a1 - 0.4:
			break
		ci.draw_line(GroundLayout.side_point(side, a, SW - CURB_W) * M, GroundLayout.side_point(side, a, SW) * M, Color(0.35, 0.33, 0.3, 0.6), 1.2, true)
		if GroundUtil.r01(sd, k * 7 + 3) < 0.12:
			# a chipped curb stone
			var c := GroundLayout.side_point(side, a + 0.5, SW - 0.04) * M
			ci.draw_circle(c, 3.0, Color(Pal.GUTTER, 0.8), true, -1.0, true)


func _wall_grime(ci: CanvasItem, b: Dictionary, side: Dictionary) -> void:
	var a0 := float(side["a0"]) + SW
	var a1 := float(side["a1"]) - SW
	if b["phantom"]:
		a0 = float(side["a0"]) + SW
	var p0 := GroundLayout.side_point(side, a0, 0.0) * M
	var p1 := GroundLayout.side_point(side, a1, 0.22) * M
	var rect := Rect2(Vector2(minf(p0.x, p1.x), minf(p0.y, p1.y)), (p1 - p0).abs())
	ci.draw_rect(rect, Color(0.05, 0.04, 0.03, 0.12))
	var p2 := GroundLayout.side_point(side, a1, 0.08) * M
	var rect2 := Rect2(Vector2(minf(p0.x, p2.x), minf(p0.y, p2.y)), (p2 - p0).abs())
	ci.draw_rect(rect2, Color(0.05, 0.04, 0.03, 0.14))


## Foot traffic polish and dirt, gum, butts and scraps.
func _wear(ci: CanvasItem, side: Dictionary, sd: int) -> void:
	var ss := sd + String(side["s"]).unicode_at(0) * 131
	var a0 := float(side["a0"]) + 1.0
	var a1 := float(side["a1"]) - 1.0
	var a := a0
	var k := 0
	while a < a1:
		k += 1
		var l := GroundUtil.rr(ss, k, 2.0, 6.0)
		var p0 := GroundLayout.side_point(side, a, 1.75) * M
		var p1 := GroundLayout.side_point(side, minf(a + l, a1), 2.45) * M
		ci.draw_rect(Rect2(Vector2(minf(p0.x, p1.x), minf(p0.y, p1.y)), (p1 - p0).abs()), Color(0.1, 0.08, 0.05, GroundUtil.rr(ss, 100 + k, 0.0, 0.05)))
		a += l
	for n in 26:
		var q := GroundLayout.side_point(side, GroundUtil.rr(ss, 200 + n, a0, a1), GroundUtil.rr(ss, 300 + n, 0.3, SW - 0.35)) * M
		if n < 16:
			ci.draw_circle(q, GroundUtil.rr(ss, 400 + n, 1.0, 2.1), Color(0.16, 0.14, 0.12, GroundUtil.rr(ss, 450 + n, 0.25, 0.5)), true, -1.0, true)
		else:
			GroundStreets.litter_bit(ci, q, ss + n * 17)


# ------------------------------------------------------------------ frontage details (local frames)

func _begin(ci: CanvasItem, f: Dictionary) -> Vector2:
	ci.draw_set_transform(f["p"], float(f["rot"]), Vector2.ONE)
	return GroundUtil.LIGHT_DIR.rotated(-float(f["rot"]))


func _end(ci: CanvasItem) -> void:
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _local_shadow(f: Dictionary, h: float) -> Vector2:
	return GroundUtil.sh(h).rotated(-float(f["rot"]))


## A tenement stoop: a few stone steps up to the door, with cheek walls or an iron rail.
func stoop(ci: CanvasItem, f: Dictionary) -> void:
	var w := float(f["w"]) * M
	var d := float(f["d"]) * M
	var s: int = f["s"]
	var style: int = f["style"]
	var stone := Color("7a5645") if style < 2 else Pal.PARAPET_STONE.darkened(0.05)
	stone = stone.lightened(GroundUtil.rr(s, 1, -0.05, 0.06))
	_begin(ci, f)
	var so := _local_shadow(f, 0.7)
	var body := GroundUtil.rect_pts(Rect2(-w * 0.5, 0, w, d))
	GroundUtil.shadow_poly(ci, body, so, 1.1)
	ci.draw_colored_polygon(body, stone.darkened(0.12))
	var cheek := 0.2 * M
	var steps := 4
	var land := 0.35 * M
	var tread := (d - land) / float(steps)
	# landing and treads, each a touch darker going down
	ci.draw_rect(Rect2(-w * 0.5 + cheek, 0, w - cheek * 2.0, land), stone.lightened(0.04))
	for k in steps:
		var y := land + float(k) * tread
		var tr := Rect2(-w * 0.5 + cheek, y, w - cheek * 2.0, tread)
		ci.draw_rect(tr, stone.darkened(0.03 * float(k)))
		ci.draw_rect(Rect2(tr.position, Vector2(tr.size.x, 1.6)), Color(0, 0, 0, 0.28))       # riser shadow line
		ci.draw_rect(Rect2(tr.position + Vector2(0, 1.6), Vector2(tr.size.x, 1.2)), Color(1, 1, 1, 0.1))
		GroundUtil.soft(ci, tr.get_center(), Vector2(tr.size.x * 0.25, tr.size.y * 0.35), Color(0, 0, 0, 0.08))
	GroundUtil.tex_rect(ci, Rect2(-w * 0.5, 0, w, d), grain, 1.0, Color(1, 1, 1, 0.5))
	# the door sill at the wall
	ci.draw_rect(Rect2(-0.55 * M, 0, 1.1 * M, 0.07 * M), Color(0.08, 0.06, 0.05, 0.9))
	if style % 2 == 0:
		# stone cheek walls with newel blocks at the bottom
		for sx: float in [-1.0, 1.0]:
			var x0 := -w * 0.5 if sx < 0.0 else w * 0.5 - cheek
			ci.draw_rect(Rect2(x0, 0, cheek, d), stone.lightened(0.08))
			ci.draw_rect(Rect2(x0, 0, 1.4, d), Color(1, 1, 1, 0.12))
			ci.draw_rect(Rect2(x0 + cheek - 1.4, 0, 1.4, d), Color(0, 0, 0, 0.18))
			Draw.rrect(ci, Rect2(x0 - 1.5, d - cheek - 3.0, cheek + 3.0, cheek + 3.0), 2.0, stone.lightened(0.12))
	else:
		# iron railings
		for sx: float in [-1.0, 1.0]:
			var x := sx * (w * 0.5 - cheek * 0.5)
			ci.draw_line(Vector2(x, 0), Vector2(x, d), Color("1d1d1f"), 2.2, true)
			ci.draw_line(Vector2(x - 0.6, 0), Vector2(x - 0.6, d), Color(0.6, 0.6, 0.62, 0.3), 0.8, true)
			for k in 4:
				ci.draw_circle(Vector2(x, d * float(k) / 3.0), 1.8, Color("1d1d1f"), true, -1.0, true)
			ci.draw_arc(Vector2(x + sx * 3.0, d), 3.0, 0.0, TAU, 10, Color("1d1d1f"), 1.6, true)
	_end(ci)


## An areaway: the sunken, railed way down to a basement door.
func areaway(ci: CanvasItem, f: Dictionary) -> void:
	var w := float(f["w"]) * M
	var d := float(f["d"]) * M
	var s: int = f["s"]
	var L := _begin(ci, f)
	var pit := Rect2(-w * 0.5, 0, w, d)
	ci.draw_rect(pit, Color("2b2824"))
	GroundUtil.tex_rect(ci, pit, grain, 1.0, Color(1, 1, 1, 0.5))
	# inner walls: lit where they face the light, shadow falling in from the rim toward it
	var walls := [[Rect2(-w * 0.5, d - 5.0, w, 5.0), Vector2(0, -1)], [Rect2(-w * 0.5, 0, 5.0, d), Vector2(1, 0)], [Rect2(w * 0.5 - 5.0, 0, 5.0, d), Vector2(-1, 0)]]
	for wl in walls:
		var n: Vector2 = wl[1]
		var l := n.dot(L)
		ci.draw_rect(wl[0], Color(1, 1, 1, 0.16 * l) if l > 0.0 else Color(0, 0, 0, -0.3 * l))
	var flip := float(f.get("flip", 1.0))
	# steps down along one end
	for k in 5:
		var x := (-w * 0.5 + 6.0 + float(k) * 7.0) * flip
		ci.draw_line(Vector2(x, 5.0), Vector2(x, d - 5.0), Color(0.55, 0.5, 0.45, 0.35), 1.2, true)
	if GroundUtil.r01(s, 3) < 0.4:
		ci.draw_circle(Vector2(w * 0.25 * flip, d * 0.4), 0.2 * M, Color("6f7171"), true, -1.0, true)
		ci.draw_circle(Vector2(w * 0.25 * flip, d * 0.4), 0.16 * M, Color("8a8c8c"), true, -1.0, true)
	# the railing on the three open sides
	var rail := PackedVector2Array([Vector2(-w * 0.5, 0), Vector2(-w * 0.5, d), Vector2(w * 0.5, d), Vector2(w * 0.5, 0)])
	var so := _local_shadow(f, 0.9)
	ci.draw_polyline(_shift(rail, so), Color(0, 0, 0.03, 0.2), 1.6, true)
	ci.draw_polyline(rail, Color("1c1c1e"), 2.4, true)
	ci.draw_polyline(_shift(rail, L * 0.8), Color(0.65, 0.65, 0.68, 0.25), 0.8, true)
	for k in 7:
		var t := float(k) / 6.0
		var q := rail[0].lerp(rail[1], t) if t < 0.5 else rail[2].lerp(rail[3], (t - 0.5) * 2.0)
		ci.draw_circle(q, 1.9, Color("1c1c1e"), true, -1.0, true)
	for k in 5:
		ci.draw_circle(rail[1].lerp(rail[2], float(k) / 4.0), 1.9, Color("1c1c1e"), true, -1.0, true)
	_end(ci)


static func _shift(pts: PackedVector2Array, o: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in pts:
		out.append(q + o)
	return out


## Steel cellar doors (a pair), or old wooden ones with iron straps.
func cellar(ci: CanvasItem, f: Dictionary) -> void:
	var sz: Vector2 = f["size"] * M
	var s: int = f["s"]
	var L := _begin(ci, f)
	var r := Rect2(-sz * 0.5, sz)
	GroundUtil.shadow_poly(ci, GroundUtil.rect_pts(r), _local_shadow(f, 0.1), 0.8)
	var wood := GroundUtil.r01(s, 1) < 0.35
	var base := Pal.PLANKS_DARK.lightened(0.05) if wood else Color("4a4c4a")
	ci.draw_rect(r, base.darkened(0.3))
	for leaf in 2:
		var lr := Rect2(r.position + Vector2(float(leaf) * sz.x * 0.5 + 1.5, 1.5), Vector2(sz.x * 0.5 - 3.0, sz.y - 3.0))
		ci.draw_rect(lr, base.lightened(GroundUtil.rr(s, 2 + leaf, -0.04, 0.05)))
		if wood:
			for k in range(1, 5):
				var x := lr.position.x + lr.size.x * float(k) / 5.0
				ci.draw_line(Vector2(x, lr.position.y), Vector2(x, lr.end.y), Color(0, 0, 0, 0.3), 1.0, true)
			for y in [lr.position.y + 5.0, lr.end.y - 5.0]:
				ci.draw_line(Vector2(lr.position.x, y), Vector2(lr.end.x, y), Color("2a2624"), 2.5, true)
		else:
			# diamond plate
			var step := 5.0
			var x := lr.position.x + 2.0
			var row := 0
			while x < lr.end.x - 1.0:
				var y := lr.position.y + 2.0 + (2.5 if row % 2 == 0 else 0.0)
				while y < lr.end.y - 1.0:
					ci.draw_line(Vector2(x - 1.2, y + 1.2), Vector2(x + 1.2, y - 1.2), Color(0.75, 0.75, 0.75, 0.16), 1.0, true)
					y += step
				x += step * 0.6
				row += 1
			GroundUtil.soft(ci, lr.get_center() + Vector2(lr.size.x * 0.2, 0), Vector2(lr.size.x * 0.3, lr.size.y * 0.25), Color(0.42, 0.25, 0.14, 0.18))
		# bevel toward the light
		ci.draw_rect(Rect2(lr.position, Vector2(lr.size.x, 1.2)), Color(1, 1, 1, 0.12 * maxf(0.0, -L.y) + 0.04))
		# the handle
		var hx := lr.end.x - 5.0 if leaf == 0 else lr.position.x + 5.0
		ci.draw_arc(Vector2(hx, lr.get_center().y), 2.4, 0.0, TAU, 10, Color("1c1b1a"), 1.3, true)
	ci.draw_line(Vector2(0, r.position.y), Vector2(0, r.end.y), Color(0.05, 0.05, 0.05, 0.9), 1.5, true)
	for y in [r.position.y + 0.2 * sz.y, r.end.y - 0.2 * sz.y]:
		ci.draw_rect(Rect2(r.position.x - 1.0, y - 2.0, 4.0, 4.0), Color("222"))
		ci.draw_rect(Rect2(r.end.x - 3.0, y - 2.0, 4.0, 4.0), Color("222"))
	_end(ci)


## Vault lights: glass prisms set in an iron plate, lighting the cellar below (gone violet with age).
func vault(ci: CanvasItem, f: Dictionary) -> void:
	var sz: Vector2 = f["size"] * M
	var s: int = f["s"]
	_begin(ci, f)
	var r := Rect2(-sz * 0.5, sz)
	ci.draw_rect(r, Color("3c3d3c"))
	GroundUtil.tex_rect(ci, r, grain, 1.0, Color(1, 1, 1, 0.5))
	var nx := int(r.size.x / 7.0)
	var ny := int(r.size.y / 7.0)
	for ix in nx:
		for iy in ny:
			var c := r.position + Vector2((float(ix) + 0.5) * r.size.x / float(nx), (float(iy) + 0.5) * r.size.y / float(ny))
			var h := GroundUtil.r01(s, ix * 31 + iy)
			var g := Color("8e9e9c") if h < 0.55 else (Color("8a7c98") if h < 0.85 else Color("2b3030"))
			ci.draw_circle(c, 2.3, g.darkened(0.25), true, -1.0, true)
			ci.draw_circle(c + Vector2(-0.6, -0.6), 1.0, g.lightened(0.3), true, -1.0, true)
	ci.draw_rect(r, Color(0.1, 0.1, 0.1, 0.9), false, 1.5, true)
	_end(ci)


## A round coal-chute cover.
func chute(ci: CanvasItem, f: Dictionary) -> void:
	var s: int = f["s"]
	_begin(ci, f)
	var r := 0.23 * M
	ci.draw_circle(Vector2.ZERO, r + 2.0, Color(0.1, 0.1, 0.1, 0.45), true, -1.0, true)
	ci.draw_circle(Vector2.ZERO, r, Color("3d3a37"), true, -1.0, true)
	ci.draw_arc(Vector2.ZERO, r * 0.72, 0.0, TAU, 20, Color("54504b"), 1.3, true)
	var n := 6 + GroundUtil.ri(s, 1, 0, 1) * 2
	for k in n:
		var a := TAU * float(k) / float(n)
		ci.draw_line(Vector2(cos(a), sin(a)) * r * 0.25, Vector2(cos(a), sin(a)) * r * 0.72, Color("54504b"), 1.3, true)
	ci.draw_circle(Vector2.ZERO, r * 0.22, Color("54504b"), true, -1.0, true)
	GroundUtil.soft(ci, Vector2(r * 0.4, r * 0.3), Vector2(r * 0.6, r * 0.5), Color(0.45, 0.26, 0.14, 0.2))
	ci.draw_arc(Vector2.ZERO, r - 0.8, PI, PI * 1.5, 8, Color(1, 1, 1, 0.22), 1.2, true)
	_end(ci)


## An iron grating over a cellar window well.
func grating(ci: CanvasItem, f: Dictionary) -> void:
	var sz: Vector2 = f["size"] * M
	_begin(ci, f)
	var r := Rect2(-sz * 0.5, sz)
	ci.draw_rect(r, Color("141414"))
	var x := r.position.x + 3.0
	while x < r.end.x - 2.0:
		ci.draw_rect(Rect2(x, r.position.y + 2.0, 2.2, r.size.y - 4.0), Color("4a4845"))
		ci.draw_rect(Rect2(x, r.position.y + 2.0, 0.8, r.size.y - 4.0), Color(1, 1, 1, 0.12))
		x += 5.0
	ci.draw_rect(r, Color("3a3835"), false, 2.5, true)
	_end(ci)


## A storm drain grate in the gutter, with the inlet slot in the curb behind it.
func drain(ci: CanvasItem, f: Dictionary) -> void:
	_begin(ci, f)
	var w := 0.95 * M
	var d := 0.42 * M
	var r := Rect2(-w * 0.5, -d * 0.5, w, d)
	ci.draw_rect(r.grow(2.0), Color(0.05, 0.05, 0.06, 0.35))
	ci.draw_rect(r, Color("1a1b1d"))
	var x := r.position.x + 3.0
	while x < r.end.x - 2.0:
		ci.draw_rect(Rect2(x, r.position.y + 2.0, 3.0, r.size.y - 4.0), Color("55575a"))
		ci.draw_rect(Rect2(x, r.position.y + 2.0, 1.0, r.size.y - 4.0), Color(1, 1, 1, 0.14))
		x += 6.0
	ci.draw_rect(r, Color("4d4f52"), false, 2.5, true)
	# the inlet mouth under the curb
	var cy := -0.28 * M
	ci.draw_rect(Rect2(-w * 0.55, cy - 3.0, w * 1.1, 4.0), Color(0.03, 0.03, 0.04, 0.95))
	ci.draw_rect(Rect2(-w * 0.55, cy - 0.3 * M, w * 1.1, 0.3 * M - 3.0), Color(0.55, 0.52, 0.48, 0.25))
	_end(ci)


## A square tree pit with its low edging and dirt (the tree itself is a prop).
func tree_pit(ci: CanvasItem, p: Dictionary) -> void:
	ci.draw_set_transform(p["p"], float(p["rot"]), Vector2.ONE)
	var r := Rect2(-0.45 * M, -0.38 * M, 0.9 * M, 0.76 * M)
	ci.draw_rect(r, Color("8d8578"))
	var dirt := r.grow(-3.0)
	ci.draw_rect(dirt, Color("3e3226"))
	GroundUtil.tex_rect(ci, dirt, grain, 1.0, Color(1, 1, 1, 0.9))
	var s: int = p["s"]
	for k in 7:
		var q := dirt.position + Vector2(GroundUtil.r01(s, 40 + k) * dirt.size.x, GroundUtil.r01(s, 50 + k) * dirt.size.y)
		ci.draw_colored_polygon(Draw.ellipse_points(q, Vector2(2.6, 1.5), GroundUtil.r01(s, 60 + k) * PI, 8), Color("7a6a3a").lerp(Color("5a4a2a"), GroundUtil.r01(s, 70 + k)))
	ci.draw_rect(r, Color(0, 0, 0, 0.25), false, 1.2, true)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ------------------------------------------------------------------ wet

func paint_block_wet(ci: CanvasItem, b: Dictionary) -> void:
	var R := _px(b["r"])
	var sd: int = b["seed"]
	var inner := Draw.rrect_points(R, CR * M, 6)
	ci.draw_colored_polygon(inner, Color(0.04, 0.05, 0.09, 0.26))
	# a sheen of water along the gutter
	GroundUtil.outline(ci, Draw.rrect_points(R.grow(0.16 * M), (CR + 0.16) * M, 6), Color(0.55, 0.6, 0.7, 0.22), 5.0)
	# puddles in the dips of the slabs, and at the curb
	for s: String in ["N", "S", "W", "E"]:
		var side: Dictionary = b["sides"][s]
		var ss := sd + s.unicode_at(0) * 71
		for k in 3:
			if GroundUtil.r01(ss, k) < 0.35:
				continue
			var a := GroundUtil.rr(ss, 10 + k, float(side["a0"]) + 4.0, float(side["a1"]) - 4.0)
			var d := GroundUtil.rr(ss, 20 + k, 1.8, 3.0)
			var c := GroundLayout.side_point(side, a, d) * M
			var st := Vector2(1.5, 0.8) if s in ["N", "S"] else Vector2(0.8, 1.5)
			GroundStreets.puddle(ci, c, GroundUtil.rr(ss, 30 + k, 0.25, 0.5) * M, ss + k, st)


# ------------------------------------------------------------------ outskirts: plain sidewalk only

func paint_phantom(ci: CanvasItem, b: Dictionary) -> void:
	paint_block(ci, b)
