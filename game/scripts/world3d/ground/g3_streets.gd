class_name G3Streets
extends RefCounted
## Streets, crossings, tram tracks, kerbs, sidewalk rings and the rubble of the lot interiors, as merged
## meshes in the bundle. Layout comes from GroundLayout (the same data the 2D art and the collision use).

const Y_WALK := 0.07          # sidewalk top
const HALF := CityPlan.STREET * 0.5
const SW := CityPlan.SIDEWALK
const BED := 3.15
const RAILS := [-2.42, -0.98, 0.98, 2.42]
const PAINT := Color("d8d2c2")
const KERB := Color("9d968a")
const CURB_R := 1.2

var lay: GroundLayout
var B: G3Bundle
var plan: CityPlan
var noise: FastNoiseLite


func _init(layout: GroundLayout, bundle: G3Bundle) -> void:
	lay = layout
	B = bundle
	plan = layout.plan
	noise = FastNoiseLite.new()
	noise.seed = 1923
	noise.frequency = 0.035
	noise.fractal_octaves = 3


static func r01(s: int, k: int) -> float:
	return GroundUtil.r01(s, k)


static func rr(s: int, k: int, a: float, b: float) -> float:
	return GroundUtil.rr(s, k, a, b)


func build() -> void:
	_base()
	for s in lay.segs:
		_segment(s)
	for x in lay.isecs:
		_intersection(x)
	for b in lay.blocks:
		_block_ground(b)


# ------------------------------------------------------------------ the asphalt under everything

func _base() -> void:
	var a := lay.area
	var step := 8.0
	var x_end := plan.water_x + 0.2
	var nx := int(ceil((minf(a.end.x, x_end) - a.position.x) / step))
	var nz := int(ceil(a.size.y / step))
	for iz in nz:
		for ix in nx:
			var x0 := a.position.x + ix * step
			var z0 := a.position.y + iz * step
			var x1 := minf(x0 + step, x_end)
			var z1 := z0 + step
			var cl: Array = []
			for q in [[x0, z0], [x1, z0], [x1, z1], [x0, z1]]:
				var nv := noise.get_noise_2d(float(q[0]), float(q[1]))
				var v := 0.88 + nv * 0.14
				cl.append(Color(v, v, v * 1.02))
			var cell := B.at(Vector2((x0 + x1) * 0.5, (z0 + z1) * 0.5))
			cell.road.quad4(Vector3(x0, 0, z0), Vector3(x1, 0, z0), Vector3(x1, 0, z1), Vector3(x0, 0, z1), cl[0], cl[1], cl[2], cl[3])


# ------------------------------------------------------------------ helpers (u along, v across)

func _p(s: Dictionary, u: float, v: float) -> Vector2:
	return GroundLayout.seg_point(s, u, v)


func _cell(s: Dictionary) -> G3Bundle.Cell:
	return B.at(_p(s, (float(s["u0"]) + float(s["u1"])) * 0.5, 0.0))


func _rect(m: G3Mesh, s: Dictionary, u0: float, v0: float, u1: float, v1: float, y: float, col: Color) -> void:
	var r := GroundLayout.seg_rect(s, u0, v0, u1, v1)
	m.flat(r.position.x, r.position.y, r.end.x, r.end.y, y, col)


func _ln(m: G3Mesh, s: Dictionary, u0: float, v0: float, u1: float, v1: float, w: float, y: float, col: Color) -> void:
	m.strip(_p(s, u0, v0), _p(s, u1, v1), w, y, col)


func _busy(s: Dictionary) -> bool:
	if s["ns"]:
		return int(s["idx"]) in [GroundLayout.BOWERY, GroundLayout.ORCHARD, 5, CityPlan.NX]
	return int(s["idx"]) in GroundLayout.BUSY_EW


# ------------------------------------------------------------------ segments

func _segment(s: Dictionary) -> void:
	var cell := _cell(s)
	var kind: String = s["kind"]
	var sd: int = s["seed"]
	var u0: float = s["u0"]
	var u1: float = s["u1"]
	var busy := _busy(s)
	if kind == "cobble":
		_cobbles(cell, s)
	else:
		_wear(cell, s, busy)
	if kind == "bowery":
		_bed(cell, s, u0, u1)
		_rails(cell, s, u0, u1)
	# seams, patches, cracks, oil
	if kind != "cobble":
		_marks(cell, s, busy)
	_stains(cell, s, busy)
	for m in s["manholes"]:
		_manhole(cell, _p(s, float(m[0]), float(m[1])), sd + int(float(m[0]) * 10.0))
	if s["cw0"]:
		_crossing(cell, s, u0 + 0.25)
	if s["cw1"]:
		_crossing(cell, s, u1 - 3.25 + 0.0)
	_puddles(cell, s)
	if kind == "bowery":
		_wires(cell, s)


func _wear(cell: G3Bundle.Cell, s: Dictionary, busy: bool) -> void:
	var sd: int = s["seed"]
	var lanes := [-2.0, 2.0]
	if s["kind"] == "bowery":
		lanes = [-4.45, 4.45]
	var k := 0
	for lc in lanes:
		for tyre: float in [-0.78, 0.78]:
			var u: float = float(s["u0"]) + 2.0
			while u < float(s["u1"]) - 2.0:
				k += 1
				var l := rr(sd, 500 + k, 3.0, 8.0)
				var a := rr(sd, 600 + k, 0.012, 0.03) * (1.4 if busy else 1.0)
				var uu1 := minf(u + l, float(s["u1"]) - 2.0)
				_ln(cell.paint, s, u, float(lc) + tyre, uu1, float(lc) + tyre, 0.5, 0.008, Color(0.62, 0.63, 0.67, a))
				u += l + rr(sd, 700 + k, 0.5, 3.0)
		# the oily stripe down the middle of the lane
		var u2: float = float(s["u0"]) + 2.0
		while u2 < float(s["u1"]) - 2.0:
			k += 1
			var l2 := rr(sd, 800 + k, 3.0, 9.0)
			var a2 := rr(sd, 850 + k, 0.05, 0.12) * (1.3 if busy else 1.0)
			_ln(cell.paint, s, u2, float(lc), minf(u2 + l2, float(s["u1"]) - 2.0), float(lc), 0.7, 0.0085, Color(0.02, 0.02, 0.04, a2))
			u2 += l2 + rr(sd, 900 + k, 0.5, 3.0)


func _cobbles(cell: G3Bundle.Cell, s: Dictionary) -> void:
	var sd: int = s["seed"]
	var u0: float = s["u0"]
	var u1: float = s["u1"]
	_rect(cell.cobble, s, u0, -HALF, u1, HALF, 0.004, Color(1, 1, 1))
	# polished wheel ruts and a worn crown
	for lc: float in [-2.0, 2.0]:
		for tyre: float in [-0.78, 0.78]:
			_ln(cell.paint, s, u0 + 0.5, lc + tyre, u1 - 0.5, lc + tyre, 0.5, 0.0085, Color(0.02, 0.02, 0.03, 0.12))
			_ln(cell.paint, s, u0 + 0.5, lc + tyre, u1 - 0.5, lc + tyre, 0.2, 0.009, Color(0.75, 0.72, 0.68, 0.02))
	# gutter flags: long flat granite along both kerbs
	for side: float in [-1.0, 1.0]:
		_rect(cell.setts, s, u0, minf(side * HALF, side * (HALF - 0.5)), u1, maxf(side * HALF, side * (HALF - 0.5)), 0.007, Color(0.82, 0.8, 0.77))
	# header rows at the crossings
	for end in 2:
		if (end == 0 and not s["cw0"]) or (end == 1 and not s["cw1"]):
			continue
		var ua := u0 if end == 0 else u1 - 0.42
		_rect(cell.setts, s, ua, -HALF, ua + 0.42, HALF, 0.007, Color(0.88, 0.86, 0.83))
	# asphalt patched into the stones where the street was dug up
	var n := GroundUtil.ri(sd, 150, 0, 2)
	for k in n:
		var c := _p(s, rr(sd, 151 + k, float(s["u0"]) + 5.0, float(s["u1"]) - 5.0), rr(sd, 154 + k, -4.0, 4.0))
		var pts := G3Mesh.blob_pts(c, rr(sd, 157 + k, 0.7, 1.4), rr(sd, 158 + k, 0.5, 0.9), sd + k, 14, 0.22, r01(sd, 159 + k) * PI)
		cell.road.push_at(Vector3.ZERO)
		cell.road.poly_flat(pts, 0.0105, Color(0.8, 0.8, 0.84))
		cell.road.pop()
		# the patch is lit with the asphalt texture; a dark seam round it
		cell.paint.poly_flat(pts, 0.0108, Color(0.03, 0.03, 0.04, 0.12))


func _bed(cell: G3Bundle.Cell, s: Dictionary, u0: float, u1: float) -> void:
	_rect(cell.setts, s, u0, -BED, u1, BED, 0.006, Color(0.95, 0.94, 0.92))
	for side: float in [-1.0, 1.0]:
		_ln(cell.paint, s, u0, side * BED, u1, side * BED, 0.12, 0.0095, Color(0.05, 0.05, 0.06, 0.7))
	for tc: float in [-1.7, 1.7]:
		_ln(cell.paint, s, u0, tc, u1, tc, 0.9, 0.0095, Color(0.03, 0.03, 0.04, 0.14))


func _rails(cell: G3Bundle.Cell, s: Dictionary, u0: float, u1: float) -> void:
	_rails_pts(cell, _p(s, u0, 0.0), _p(s, u1, 0.0), s["ns"])


## Four rails (two tracks) along the street from a to b.
func _rails_pts(cell: G3Bundle.Cell, a: Vector2, b: Vector2, ns: bool) -> void:
	for v: float in RAILS:
		var off := Vector2(v, 0.0) if ns else Vector2(0.0, v)
		var pa := a + off
		var pb := b + off
		var tc := signf(v) * 1.7
		var inner := 0.075 * signf(tc - v)
		var ioff := Vector2(inner, 0.0) if ns else Vector2(0.0, inner)
		cell.paint.strip(pa + ioff, pb + ioff, 0.07, 0.0102, Color(0.02, 0.02, 0.03, 0.95))
		# the rail: head and web as a low box, a bright polished line on top
		var mid := (pa + pb) * 0.5
		var len := (pb - pa).length()
		var size := Vector3(0.075, 0.06, len) if ns else Vector3(len, 0.06, 0.075)
		cell.metal.box(Vector3(mid.x, 0.036, mid.y), size, Color("7d7a75"), Color("a9a6a0"))
		# fishplates every ~9 m
		var u := 4.5
		while u < len:
			var jp := pa + ((pb - pa).normalized() * u)
			var js := Vector3(0.1, 0.07, 0.5) if ns else Vector3(0.5, 0.07, 0.1)
			cell.metal.box(Vector3(jp.x, 0.04, jp.y), js, Color("55524e"))
			u += 9.0


func _wires(cell: G3Bundle.Cell, s: Dictionary) -> void:
	var u0: float = s["u0"]
	var u1: float = s["u1"]
	_wire_lines(cell, _p(s, u0, 0.0), _p(s, u1, 0.0), true)
	# span wires between the paired trolley poles
	for sp in s.get("spans", []):
		var w: Vector2 = (sp[0] as Vector2) / W.M
		var e: Vector2 = (sp[1] as Vector2) / W.M
		cell.props.rod(Vector3(w.x, 6.6, w.y), Vector3(e.x, 6.6, e.y), 0.012, Color("1c1c1e"))
		for v: float in [-1.7, 1.7]:
			var x := float(s["c"]) + v
			var t := clampf((x - w.x) / maxf(e.x - w.x, 0.5), 0.0, 1.0)
			var q := w.lerp(e, t)
			cell.props.box(Vector3(q.x, 6.55, q.y), Vector3(0.07, 0.1, 0.07), Color("55504a"))


func _wire_lines(cell: G3Bundle.Cell, a: Vector2, b: Vector2, ns: bool) -> void:
	for v: float in [-1.7, 1.7]:
		var off := Vector2(v, 0.0) if ns else Vector2(0.0, v)
		var pa := a + off
		var pb := b + off
		# the wire sags a little between hangers: three pieces
		var prev := Vector3(pa.x, 6.5, pa.y)
		for k in 6:
			var t := float(k + 1) / 6.0
			var q := pa.lerp(pb, t)
			var sag := -0.05 * sin(t * PI) - 0.0
			var nxt := Vector3(q.x, 6.5 + sag, q.y)
			cell.props.rod(prev, nxt, 0.01, Color("17171a"))
			prev = nxt


# ------------------------------------------------------------------ patches, cracks, seams, oil

func _marks(cell: G3Bundle.Cell, s: Dictionary, busy: bool) -> void:
	var sd: int = s["seed"]
	var u0: float = s["u0"]
	var u1: float = s["u1"]
	var bowery: bool = s["kind"] == "bowery"
	# a worn, dashed white centre line (not on the tram street) and stop lines at the crossings
	if not bowery and (u1 - u0) > 18.0:
		var u := u0 + 6.0 + rr(sd, 1100, 0.0, 1.5)
		var k := 0
		while u + 1.8 < u1 - 6.0:
			k += 1
			var a := rr(sd, 1110 + k, 0.4, 0.85)
			if r01(sd, 1130 + k) > 0.12:
				_ln(cell.paint, s, u, 0.0, u + 1.8, 0.0, 0.14, 0.0092, Color(PAINT, a * 0.8))
			u += 5.0
		for end in 2:
			var has: bool = s["cw0"] if end == 0 else s["cw1"]
			if has and busy:
				var ua := u0 + 4.2 if end == 0 else u1 - 4.2
				var vs := 1.0 if end == 0 else -1.0
				_ln(cell.paint, s, ua, vs * 0.3, ua, vs * (HALF - 0.5), 0.3, 0.0092, Color(PAINT, 0.7))
	# patches: newer, darker asphalt
	var np := GroundUtil.ri(sd, 50, 1, 3)
	for k in np:
		var u := rr(sd, 51 + k, u0 + 4.0, u1 - 6.0)
		var l := rr(sd, 55 + k, 1.2, 4.2)
		var v := _v_free(s, sd, 58 + k, -5.0, 3.0)
		var wv := rr(sd, 61 + k, 0.8, 2.4)
		if bowery:
			wv = minf(wv, HALF - BED - 0.6)
			v = clampf(v, BED + 0.2, HALF - 0.3 - wv) if v > 0.0 else clampf(v - wv, -HALF + 0.3, -BED - 0.2 - wv)
		var newer := r01(sd, 64 + k) < 0.6
		var col := Color(0.02, 0.02, 0.03, 0.2) if newer else Color(0.7, 0.7, 0.72, 0.05)
		_rect(cell.paint, s, u, v, u + l, v + wv, 0.0088, col)
	# hairline cracks
	for k in 3 + GroundUtil.ri(sd, 40, 0, 3):
		var c := _p(s, rr(sd, 120 + k, u0 + 1.0, u1 - 1.0), _v_free(s, sd, 130 + k, -HALF + 0.5, HALF - 0.5))
		_crack(cell.paint, c, sd + k * 7, rr(sd, 140 + k, 0.8, 2.4))
	# a pothole or two
	if r01(sd, 230) < 0.5:
		var pc := _p(s, rr(sd, 231, u0 + 4.0, u1 - 4.0), _v_free(s, sd, 232, -5.0, 5.0))
		var rad := rr(sd, 233, 0.22, 0.42)
		cell.paint.poly_flat(G3Mesh.blob_pts(pc, rad * 1.3, rad * 1.2, sd + 1, 12, 0.3), 0.0089, Color(0.6, 0.6, 0.62, 0.1))
		cell.paint.poly_flat(G3Mesh.blob_pts(pc, rad, rad * 0.9, sd + 2, 12, 0.3), 0.0094, Color(0.03, 0.03, 0.035, 0.85))


func _v_free(s: Dictionary, sd: int, k: int, lo: float, hi: float) -> float:
	if s["kind"] == "bowery":
		var side := 1.0 if r01(sd, k + 7777) < 0.5 else -1.0
		return side * rr(sd, k, BED + 0.4, HALF - 0.4)
	return rr(sd, k, lo, hi)


func _crack(m: G3Mesh, start: Vector2, sd: int, length: float) -> void:
	var dir := Vector2.RIGHT.rotated(r01(sd, 1) * TAU)
	var p := start
	var steps := 6
	for k in steps:
		dir = dir.rotated(rr(sd, 10 + k, -0.7, 0.7))
		var q := p + dir * length / float(steps)
		m.strip(p, q, 0.035, 0.0093, Color(0.02, 0.02, 0.03, 0.55))
		p = q


func _stains(cell: G3Bundle.Cell, s: Dictionary, busy: bool) -> void:
	var sd: int = s["seed"]
	var n := GroundUtil.ri(sd, 170, 3, 7) + (3 if busy else 0)
	for k in n:
		var side := 1.0 if r01(sd, 171 + k) < 0.5 else -1.0
		var in_lane := r01(sd, 200 + k) < 0.3
		var v := side * (rr(sd, 180 + k, 4.2, 5.1) if not in_lane else rr(sd, 181 + k, 1.4, 2.6))
		if s["kind"] == "bowery" and absf(v) < BED + 0.3:
			v = side * rr(sd, 182 + k, BED + 0.4, 4.0)
		var u := rr(sd, 190 + k, float(s["u0"]) + 1.0, float(s["u1"]) - 1.0)
		var c := _p(s, u, v)
		var rad := rr(sd, 210 + k, 0.25, 0.6)
		cell.paint.poly_flat(G3Mesh.blob_pts(c, rad * 1.4, rad, sd + 300 + k, 12, 0.3, 0.0 if not s["ns"] else PI * 0.5), 0.0087, Color(0.03, 0.03, 0.05, 0.22))


func _puddles(cell: G3Bundle.Cell, s: Dictionary) -> void:
	var sd: int = s["seed"]
	var n := GroundUtil.ri(sd, 240, 1, 4)
	for k in n:
		var gutter := r01(sd, 241 + k) < 0.6
		var side := 1.0 if r01(sd, 245 + k) < 0.5 else -1.0
		var v := side * (HALF - 0.55) if gutter else _v_free(s, sd, 249 + k, -4.0, 4.0)
		var u := rr(sd, 253 + k, float(s["u0"]) + 4.5, float(s["u1"]) - 4.5)
		var r := rr(sd, 257 + k, 0.4, 0.95)
		var c := _p(s, u, v)
		var rot := 0.0 if not s["ns"] else PI * 0.5
		cell.puddle.poly_flat(G3Mesh.blob_pts(c, r * 1.7, r, sd + 400 + k, 16, 0.28, rot), 0.0115, Color(0.2, 0.22, 0.27))


func _manhole(cell: G3Bundle.Cell, c: Vector2, sd: int) -> void:
	var y := 0.0105
	var m := cell.metal
	m.cyl(Vector3(c.x, y, c.y), 0.52, 0.52, 0.012, 14, Color("232325"), true, Color("2d2d30"))
	m.ring_flat(Vector3(c.x, y + 0.013, c.y), 0.40, 0.46, 14, Color("3a3a3e"))
	for k in 4:
		var a := TAU * (float(k) / 4.0) + r01(sd, 3) * 0.5
		m.strip(c + Vector2(cos(a), sin(a)) * 0.05, c + Vector2(cos(a), sin(a)) * 0.38, 0.05, y + 0.0135, Color("39393d"))
	m.ring_flat(Vector3(c.x, y + 0.013, c.y), 0.2, 0.25, 12, Color("3a3a3e"))
	cell.paint.ring_flat(Vector3(c.x, 0.0099, c.y), 0.52, 0.66, 14, Color(0.02, 0.02, 0.03, 0.4))


## Zebra crossing: two bars across the street (stone rows on the cobbled streets).
func _crossing(cell: G3Bundle.Cell, s: Dictionary, ua: float) -> void:
	var sd: int = int(s["seed"]) + int(ua * 3.0)
	var v0 := -HALF + 0.35
	var v1 := HALF - 0.35
	var ub := ua + 3.0
	if s["kind"] == "cobble":
		var um := (ua + ub) * 0.5
		for row in 2:
			var ra := um - 0.62 + float(row) * 0.62
			var v := v0
			var k := 0
			while v < v1:
				k += 1
				var l := minf(rr(sd, 10 + k + row * 40, 0.8, 1.5), v1 - v)
				var t := rr(sd, 60 + k + row * 40, 0.78, 0.95)
				_rect(cell.setts, s, ra + 0.03, v + 0.03, ra + 0.57, v + l - 0.03, 0.0075, Color(t, t, t * 0.97))
				v += l
		return
	for edge: float in [ua, ub - 0.34]:
		var v := v0
		var k := 0
		while v < v1:
			k += 1
			var l := minf(rr(sd, 100 + k + int(edge), 1.0, 2.6), v1 - v)
			var wear := 1.0
			for t: float in [-2.78, -1.22, 1.22, 2.78, -4.9, -3.3, 3.3, 4.9]:
				if absf(v + l * 0.5 - t) < 0.7:
					wear = 0.72
			var a := rr(sd, 130 + k + int(edge), 0.7, 0.9) * wear
			_rect(cell.paint, s, edge, v, edge + 0.34, v + l, 0.0092, Color(PAINT, a))
			v += l


# ------------------------------------------------------------------ intersections

func _intersection(x: Dictionary) -> void:
	var r: Rect2 = x["r"]
	var sd: int = x["seed"]
	var cell := B.at(r.get_center())
	if x["bowery"]:
		cell.setts.flat(r.position.x + HALF - BED, r.position.y, r.position.x + HALF + BED, r.end.y, 0.006, Color(0.95, 0.94, 0.92))
		_rails_pts(cell, Vector2(r.get_center().x, r.position.y), Vector2(r.get_center().x, r.end.y), true)
		_wire_lines(cell, Vector2(r.get_center().x, r.position.y), Vector2(r.get_center().x, r.end.y), true)
	_manhole(cell, x["manhole"], sd)
	if x.get("dome", false):
		var c := r.get_center()
		# traffic domes: a ring of brass buttons round an amber lamp
		cell.metal.cyl(Vector3(c.x, 0.012, c.y), 0.55, 0.45, 0.07, 12, Color("a98a45"), true, Color("c9a860"))
		cell.glow.cyl(Vector3(c.x, 0.08, c.y), 0.3, 0.12, 0.2, 10, Color(1.0, 0.75, 0.35))
		for k in 8:
			var a := TAU * float(k) / 8.0
			cell.metal.cyl(Vector3(c.x + cos(a) * 0.95, 0.011, c.y + sin(a) * 0.95), 0.1, 0.07, 0.04, 6, Color("b89b50"))
		cell.pools.glow_disc(Vector3(c.x, 0.1, c.y), 3.0, Color(1.0, 0.72, 0.32, 0.5))
	# a faint wear patch where the turning traffic polishes the middle
	cell.paint.poly_flat(G3Mesh.blob_pts(r.get_center(), 3.6, 3.4, sd, 16, 0.18), 0.0086, Color(0.6, 0.6, 0.64, 0.04))


# ------------------------------------------------------------------ blocks: sidewalk rings, kerbs, lot rubble

func _round_rect(r: Rect2, rad: float) -> PackedVector2Array:
	# clockwise on screen (x right, z down)
	var pts := PackedVector2Array()
	var corners := [[r.position.x + rad, r.position.y + rad, PI, 1.5 * PI], [r.end.x - rad, r.position.y + rad, 1.5 * PI, 2.0 * PI],
		[r.end.x - rad, r.end.y - rad, 0.0, 0.5 * PI], [r.position.x + rad, r.end.y - rad, 0.5 * PI, PI]]
	for c in corners:
		for k in 6:
			var a: float = lerpf(float(c[2]), float(c[3]), float(k) / 5.0)
			pts.append(Vector2(float(c[0]) + cos(a) * rad, float(c[1]) + sin(a) * rad))
	return pts


func _block_ground(b: Dictionary) -> void:
	var r: Rect2 = b["r"]
	var cell := B.at(r.get_center())
	var outer := _round_rect(r, CURB_R)
	# sidewalk top: the four strips, clipped by the rounded outline
	var strips := [Rect2(r.position.x - 1.0, r.position.y - 1.0, r.size.x + 2.0, SW + 1.0),
		Rect2(r.position.x - 1.0, r.end.y - SW, r.size.x + 2.0, SW + 1.0),
		Rect2(r.position.x - 1.0, r.position.y + SW - 0.01, SW + 1.0, r.size.y - 2.0 * SW + 0.02),
		Rect2(r.end.x - SW, r.position.y + SW - 0.01, SW + 1.0, r.size.y - 2.0 * SW + 0.02)]
	for st: Rect2 in strips:
		var poly := PackedVector2Array([st.position, Vector2(st.end.x, st.position.y), st.end, Vector2(st.position.x, st.end.y)])
		for piece in Geometry2D.intersect_polygons(outer, poly):
			cell.walk.poly_flat(piece, Y_WALK, Color(1, 1, 1))
	# kerb faces and the kerb stone's lit lip
	var n := outer.size()
	for k in n:
		var p0 := outer[k]
		var p1 := outer[(k + 1) % n]
		if p0.distance_to(p1) < 0.01:
			continue
		cell.stone.wall(p0, p1, 0.0, Y_WALK, KERB.darkened(0.08))
		var dirv := (p1 - p0).normalized()
		var inward := Vector2(-dirv.y, dirv.x)
		var mid := (p0 + p1) * 0.5
		if not Geometry2D.is_point_in_polygon(mid + inward * 0.05, outer):
			inward = -inward
		cell.stone.strip(p0 + inward * 0.12, p1 + inward * 0.12, 0.24, Y_WALK + 0.004, KERB)
		# gutter grime on the road beside the kerb
		cell.paint.strip(p0 - inward * 0.22, p1 - inward * 0.22, 0.44, 0.0082, Color(0.02, 0.02, 0.03, 0.3))
	# the lot interiors: rough ground under the buildings and the yards
	var inner := r.grow(-SW)
	var fill := Color(0.85, 0.85, 0.85) if not b["phantom"] else Color(0.3, 0.29, 0.28)
	cell.dirt.flat(inner.position.x, inner.position.y, inner.end.x, inner.end.y, 0.012, fill)
