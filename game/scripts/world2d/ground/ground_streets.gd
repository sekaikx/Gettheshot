class_name GroundStreets
extends RefCounted
## Paints the streets: the asphalt under everything, street segments (asphalt, Belgian block, the
## Bowery's streetcar tracks), intersections, crossings, manholes, wear, stains, litter, and the
## wet-weather overlay (puddles, gloss). Coordinates: segments work in (u along, v across) metres.

const M := W.M
const HALF := CityPlan.STREET * 0.5
const TAR := Color(0.085, 0.085, 0.095, 0.5)
const CRACK := Color(0.09, 0.09, 0.1, 0.5)
const OIL := Color(0.04, 0.04, 0.06, 0.32)
const RAILS := [-2.42, -0.98, 0.98, 2.42]
const BED := 3.15
const PUDDLE := Color(0.46, 0.52, 0.6, 0.62)
const PUDDLE_HI := Color(0.72, 0.76, 0.82, 0.55)
const WIRE_H := 6.5

var lay: GroundLayout
var grain: Texture2D
var mottle: Texture2D
var cobble: Texture2D
var setts: Texture2D


func _init(layout: GroundLayout) -> void:
	lay = layout
	grain = GroundTex.grain()
	mottle = GroundTex.mottle()
	cobble = GroundTex.cobble()
	setts = GroundTex.setts()


# ------------------------------------------------------------------ helpers

func _p(s: Dictionary, u: float, v: float) -> Vector2:
	return GroundLayout.seg_point(s, u, v) * M


func _r(s: Dictionary, u0: float, v0: float, u1: float, v1: float) -> Rect2:
	var r := GroundLayout.seg_rect(s, u0, v0, u1, v1)
	return Rect2(r.position * M, r.size * M)


func _line(ci: CanvasItem, s: Dictionary, u0: float, v0: float, u1: float, v1: float, col: Color, w: float) -> void:
	ci.draw_line(_p(s, u0, v0), _p(s, u1, v1), col, w, true)


# ------------------------------------------------------------------ the base

## Asphalt over the whole area, with soft mottling and grain (one draw each).
func paint_base(ci: CanvasItem) -> void:
	var a := Rect2(lay.area.position * M, lay.area.size * M)
	ci.draw_rect(a, Pal.ASPHALT)
	GroundUtil.tex_rect(ci, a, mottle, 22.0, Color(1, 1, 1, 0.16))
	GroundUtil.tex_rect(ci, a, mottle, 7.0, Color(1, 1, 1, 0.1))
	GroundUtil.tex_rect(ci, a, grain, 1.0, Color(1, 1, 1, 0.6))


# ------------------------------------------------------------------ segments

func paint_segment(ci: CanvasItem, s: Dictionary) -> void:
	var kind: String = s["kind"]
	var sd: int = s["seed"]
	var u0: float = s["u0"]
	var u1: float = s["u1"]
	var busy := _busy(s)
	if kind == "cobble":
		_cobbles(ci, s)
	else:
		_asphalt_wear(ci, s, busy)
	if kind == "bowery":
		_track_bed(ci, s, u0, u1)
	# stains, cracks, patches
	if kind != "cobble":
		_patches(ci, s)
		_seams(ci, s)
		_cracks(ci, s, 4 + GroundUtil.ri(sd, 40, 0, 4))
	else:
		_cobble_repairs(ci, s)
	_oil(ci, s, busy)
	_potholes(ci, s)
	_puddle_marks(ci, s)
	for m in s["manholes"]:
		manhole(ci, _p(s, float(m[0]), float(m[1])), sd + int(float(m[0]) * 10.0))
	if s["cw0"]:
		_crossing(ci, s, u0 + 0.25, u0 + 3.25)
	if s["cw1"]:
		_crossing(ci, s, u1 - 3.25, u1 - 0.25)
	if kind == "bowery":
		_rails(ci, s, u0, u1)
		_wire_shadows(ci, s)
	_litter(ci, s)


## A random v (across) for stains and cracks: anywhere on asphalt, but off the Bowery's track bed.
func _v_free(s: Dictionary, sd: int, k: int, lo: float, hi: float) -> float:
	if s["kind"] == "bowery":
		var side := 1.0 if GroundUtil.r01(sd, k + 7777) < 0.5 else -1.0
		return side * GroundUtil.rr(sd, k, BED + 0.4, HALF - 0.4)
	return GroundUtil.rr(sd, k, lo, hi)


func _busy(s: Dictionary) -> bool:
	if s["ns"]:
		return int(s["idx"]) in [GroundLayout.BOWERY, GroundLayout.ORCHARD, 5, CityPlan.NX]
	return int(s["idx"]) in GroundLayout.BUSY_EW


## Tyre-polished paths and the dark oily stripe between them, broken into pieces.
func _asphalt_wear(ci: CanvasItem, s: Dictionary, busy: bool) -> void:
	var sd: int = s["seed"]
	var lanes := [-2.0, 2.0]
	if s["kind"] == "bowery":
		lanes = [-4.1, 4.1]
	var k := 0
	for lc in lanes:
		for tyre: float in [-0.78, 0.78]:
			var u: float = s["u0"]
			while u < float(s["u1"]):
				k += 1
				var l := GroundUtil.rr(sd, 500 + k, 2.5, 7.0)
				var a := GroundUtil.rr(sd, 600 + k, 0.015, 0.045) * (1.3 if busy else 1.0)
				var v := float(lc) + float(tyre)
				ci.draw_rect(_r(s, u, v - 0.3, minf(u + l, float(s["u1"])), v + 0.3), Color(0.55, 0.56, 0.6, a * 0.7))
				ci.draw_rect(_r(s, u, v - 0.16, minf(u + l, float(s["u1"])), v + 0.16), Color(0.6, 0.61, 0.66, a))
				u += l
		# oil stripe down the middle of the lane
		var u2: float = s["u0"]
		while u2 < float(s["u1"]):
			k += 1
			var l2 := GroundUtil.rr(sd, 700 + k, 3.0, 9.0)
			var a2 := GroundUtil.rr(sd, 800 + k, 0.03, 0.09) * (1.3 if busy else 1.0)
			ci.draw_rect(_r(s, u2, float(lc) - 0.42, minf(u2 + l2, float(s["u1"])), float(lc) + 0.42), Color(0.03, 0.03, 0.05, a2 * 0.6))
			ci.draw_rect(_r(s, u2, float(lc) - 0.2, minf(u2 + l2, float(s["u1"])), float(lc) + 0.2), Color(0.03, 0.03, 0.05, a2))
			u2 += l2


## Belgian block, with gutter flags along the curbs, header rows at the ends and polished tracks.
func _cobbles(ci: CanvasItem, s: Dictionary) -> void:
	var sd: int = s["seed"]
	var u0: float = s["u0"]
	var u1: float = s["u1"]
	var rect := _r(s, u0, -HALF, u1, HALF)
	GroundUtil.tex_rect(ci, rect, cobble, 1.0)
	GroundUtil.tex_rect(ci, rect, mottle, 16.0, Color(1, 1, 1, 0.12))
	# polished, darker wheel ruts and a lighter crown
	for lc: float in [-2.0, 2.0]:
		for tyre: float in [-0.78, 0.78]:
			var v := float(lc) + float(tyre)
			ci.draw_rect(_r(s, u0, v - 0.28, u1, v + 0.28), Color(0.02, 0.02, 0.03, 0.1))
			ci.draw_rect(_r(s, u0, v - 0.12, u1, v + 0.12), Color(0.7, 0.68, 0.64, 0.05))
	ci.draw_rect(_r(s, u0, -0.6, u1, 0.6), Color(1, 1, 1, 0.025))
	# gutter flags: long flat stones along both curbs
	for side: float in [-1.0, 1.0]:
		var va := side * HALF
		var vb := side * (HALF - 0.5)
		var band := _r(s, u0, minf(va, vb), u1, maxf(va, vb))
		GroundUtil.tex_rect(ci, band, setts, 1.0, Color(0.78, 0.76, 0.74))
		var u := u0
		var k := 0
		while u < u1:
			k += 1
			u += GroundUtil.rr(sd, 30 + k + int(side * 50.0), 0.9, 1.6)
			if u < u1:
				_line(ci, s, u, va, u, vb, Color(0.12, 0.11, 0.1, 0.6), 1.5)
		_line(ci, s, u0, vb, u1, vb, Color(0.1, 0.1, 0.09, 0.55), 1.5)
	# header rows at the intersections
	for end: int in [0, 1]:
		if (end == 0 and not s["cw0"]) or (end == 1 and not s["cw1"]):
			continue
		var ua := u0 if end == 0 else u1 - 0.42
		var hr := _r(s, ua, -HALF, ua + 0.42, HALF)
		GroundUtil.tex_rect(ci, hr, setts, 1.0, Color(0.85, 0.83, 0.8))
		var edge := u0 + 0.42 if end == 0 else u1 - 0.42
		_line(ci, s, edge, -HALF, edge, HALF, Color(0.1, 0.1, 0.09, 0.6), 1.5)


func _track_bed(ci: CanvasItem, s: Dictionary, u0: float, u1: float) -> void:
	var bed := _r(s, u0, -BED, u1, BED)
	GroundUtil.tex_rect(ci, bed, setts, 1.0)
	GroundUtil.tex_rect(ci, bed, mottle, 12.0, Color(1, 1, 1, 0.1))
	for side: float in [-1.0, 1.0]:
		_line(ci, s, u0, side * BED, u1, side * BED, Color(0.08, 0.08, 0.09, 0.75), 2.5)
		_line(ci, s, u0, side * (BED - 0.06), u1, side * (BED - 0.06), Color(0.8, 0.78, 0.74, 0.18), 1.0)
	# worn dark strip where the car's wheels run, oil between the rails
	for tc: float in [-1.7, 1.7]:
		ci.draw_rect(_r(s, u0, float(tc) - 0.35, u1, float(tc) + 0.35), Color(0.03, 0.03, 0.04, 0.12))


func _rails(ci: CanvasItem, s: Dictionary, u0: float, u1: float) -> void:
	for v in RAILS:
		var vv := float(v)
		var tc := signf(vv) * 1.7
		var inner := 0.07 * signf(tc - vv)
		# the flangeway groove, the rail head, a bright polished line, rust on the outside
		_line(ci, s, u0, vv + inner, u1, vv + inner, Color(0.04, 0.04, 0.045, 0.95), 2.6)
		_line(ci, s, u0, vv, u1, vv, Color("7d7a75"), 3.2)
		_line(ci, s, u0, vv - 0.015, u1, vv - 0.015, Color("c9c6bf"), 1.3)
		_line(ci, s, u0, vv - inner * 0.6, u1, vv - inner * 0.6, Color(0.36, 0.25, 0.18, 0.45), 1.0)
	# rail joints with fishplates every ~9 m
	var u := u0 + 4.5
	while u < u1:
		for v in RAILS:
			var a := _p(s, u - 0.18, float(v))
			var b := _p(s, u + 0.18, float(v))
			ci.draw_line(a, b, Color(0.25, 0.24, 0.23, 0.9), 4.0, true)
			ci.draw_line(_p(s, u, float(v) - 0.05), _p(s, u, float(v) + 0.05), Color(0.05, 0.05, 0.05, 0.9), 1.2, true)
		u += 9.0


func _wire_shadows(ci: CanvasItem, s: Dictionary) -> void:
	var o := GroundUtil.sh(WIRE_H)
	var col := Color(0.02, 0.02, 0.04, 0.12)
	for v: float in [-1.7, 1.7]:
		ci.draw_line(_p(s, float(s["u0"]), float(v)) + o, _p(s, float(s["u1"]), float(v)) + o, col, 1.6, true)
	for sp in s.get("spans", []):
		ci.draw_line((sp[0] as Vector2) + o, (sp[1] as Vector2) + o, col, 1.2, true)


## Streetcar trolley wires and the span wires that hold them (high layer).
func paint_segment_high(ci: CanvasItem, s: Dictionary) -> void:
	if s["kind"] != "bowery":
		return
	var col := Color(0.07, 0.07, 0.08, 0.8)
	for v: float in [-1.7, 1.7]:
		_line(ci, s, float(s["u0"]), float(v), float(s["u1"]), float(v), col, 1.4)
	for sp in s.get("spans", []):
		var w: Vector2 = sp[0]
		var e: Vector2 = sp[1]
		ci.draw_line(w, e, Color(0.07, 0.07, 0.08, 0.75), 1.3, true)
		# insulators where the span wire holds each trolley wire
		for v: float in [-1.7, 1.7]:
			var x := (float(s["c"]) + v) * M
			var t := clampf((x - w.x) / maxf(e.x - w.x, 1.0), 0.0, 1.0)
			var q := w.lerp(e, t)
			ci.draw_circle(q, 2.6, Color("2c2a28"), true, -1.0, true)
			ci.draw_circle(q + Vector2(-0.6, -0.6), 1.1, Color("8a8378"), true, -1.0, true)


func _patches(ci: CanvasItem, s: Dictionary) -> void:
	var sd: int = s["seed"]
	var n := GroundUtil.ri(sd, 50, 1, 3)
	for k in n:
		var u := GroundUtil.rr(sd, 51 + k, float(s["u0"]) + 4.0, float(s["u1"]) - 6.0)
		var l := GroundUtil.rr(sd, 55 + k, 1.2, 4.2)
		var v := _v_free(s, sd, 58 + k, -5.0, 3.0)
		var wv := GroundUtil.rr(sd, 61 + k, 0.8, 2.4)
		if s["kind"] == "bowery":
			wv = minf(wv, HALF - BED - 0.6)
			v = clampf(v, BED + 0.2, HALF - 0.3 - wv) if v > 0.0 else clampf(v - wv, -HALF + 0.3, -BED - 0.2 - wv)
		var newer := GroundUtil.r01(sd, 64 + k) < 0.55
		var pts := PackedVector2Array()
		var corners := [[u, v], [u + l, v], [u + l, v + wv], [u, v + wv]]
		for c in corners.size():
			var j := Vector2(GroundUtil.rr(sd, 70 + k * 8 + c, -0.12, 0.12), GroundUtil.rr(sd, 71 + k * 8 + c, -0.12, 0.12))
			pts.append(_p(s, float(corners[c][0]) + j.x, float(corners[c][1]) + j.y))
		var col := Color(0.03, 0.03, 0.04, 0.13) if newer else Color(0.62, 0.62, 0.64, 0.05)
		ci.draw_colored_polygon(pts, col)
		GroundUtil.tex_poly(ci, pts, grain, 1.0, Color(1, 1, 1, 0.35 if newer else 0.0))
		# only the edges the rollers left: a faint seam on two sides
		ci.draw_polyline(PackedVector2Array([pts[0], pts[1]]), Color(TAR, 0.3), 1.4, true)
		ci.draw_polyline(PackedVector2Array([pts[2], pts[3]]), Color(TAR, 0.3), 1.4, true)


func _seams(ci: CanvasItem, s: Dictionary) -> void:
	var sd: int = s["seed"]
	var u0: float = s["u0"]
	var u1: float = s["u1"]
	var bowery: bool = s["kind"] == "bowery"
	# the joint down the crown (or, on the Bowery, along the edges of the track bed), in pieces
	var lines := [BED + 0.05, -BED - 0.05] if bowery else [0.05]
	var k := 0
	for lv: float in lines:
		var u := u0 + GroundUtil.rr(sd, 80 + k, 0.0, 3.0)
		while u < u1:
			k += 1
			var l := GroundUtil.rr(sd, 81 + k, 2.0, 7.0)
			if GroundUtil.r01(sd, 90 + k) < 0.55:
				var pts := GroundUtil.wave(_p(s, u, lv), _p(s, minf(u + l, u1), lv), sd + k, 2.5, 90.0)
				ci.draw_polyline(pts, TAR, 1.9, true)
				ci.draw_polyline(_shift(pts, Vector2(-0.8, -0.8)), Color(1, 1, 1, 0.04), 1.0, true)
			u += l + GroundUtil.rr(sd, 95 + k, 1.0, 6.0)
	# a couple of transverse seams, broken, never across the tracks
	var n := GroundUtil.ri(sd, 100, 0, 2)
	for t in n:
		var ut := GroundUtil.rr(sd, 101 + t, u0 + 5.0, u1 - 5.0)
		var spans := [[-HALF + 0.4, -BED - 0.1], [BED + 0.1, HALF - 0.4]] if bowery else [[GroundUtil.rr(sd, 105 + t, -HALF + 0.4, -1.0), GroundUtil.rr(sd, 108 + t, 1.0, HALF - 0.4)]]
		for sp in spans:
			var pts := GroundUtil.wave(_p(s, ut, float(sp[0])), _p(s, ut + GroundUtil.rr(sd, 111 + t, -0.4, 0.4), float(sp[1])), sd + 30 + t, 3.0, 70.0)
			ci.draw_polyline(pts, Color(TAR, TAR.a * 0.8), 1.7, true)


func _shift(pts: PackedVector2Array, o: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(pts.size())
	for k in pts.size():
		out[k] = pts[k] + o
	return out


func _cracks(ci: CanvasItem, s: Dictionary, n: int) -> void:
	var sd: int = s["seed"]
	for k in n:
		var start := _p(s, GroundUtil.rr(sd, 120 + k, float(s["u0"]) + 1.0, float(s["u1"]) - 1.0), _v_free(s, sd, 130 + k, -HALF + 0.5, HALF - 0.5))
		crack(ci, start, sd + k * 7, GroundUtil.rr(sd, 140 + k, 0.8, 2.2) * M, CRACK)


## A branching crack from `start`, about `length` px long.
static func crack(ci: CanvasItem, start: Vector2, s: int, length: float, col: Color) -> void:
	var dir := Vector2.RIGHT.rotated(GroundUtil.r01(s, 1) * TAU)
	var p := start
	var pts := PackedVector2Array([p])
	var steps := 7
	for k in steps:
		dir = dir.rotated(GroundUtil.rr(s, 10 + k, -0.7, 0.7))
		p += dir * length / float(steps)
		pts.append(p)
		if k == 3 and GroundUtil.r01(s, 3) < 0.6:
			var b := p
			var bd := dir.rotated(GroundUtil.rr(s, 4, 0.7, 1.3) * (1.0 if GroundUtil.r01(s, 5) < 0.5 else -1.0))
			var bp := PackedVector2Array([b])
			for q in 3:
				bd = bd.rotated(GroundUtil.rr(s, 20 + q, -0.6, 0.6))
				b += bd * length / float(steps) * 0.8
				bp.append(b)
			ci.draw_polyline(bp, Color(col, col.a * 0.8), 1.0, true)
	ci.draw_polyline(pts, col, 1.3, true)


func _cobble_repairs(ci: CanvasItem, s: Dictionary) -> void:
	var sd: int = s["seed"]
	# asphalt patched into the stones where the street was dug up
	var n := GroundUtil.ri(sd, 150, 0, 2)
	for k in n:
		var c := _p(s, GroundUtil.rr(sd, 151 + k, float(s["u0"]) + 5.0, float(s["u1"]) - 5.0), GroundUtil.rr(sd, 154 + k, -4.0, 4.0))
		var pts := GroundUtil.blob(c, GroundUtil.rr(sd, 157 + k, 0.5, 1.1) * M, sd + k, 20, 0.22, Vector2(1.5, 0.8), GroundUtil.r01(sd, 158 + k) * PI)
		ci.draw_colored_polygon(pts, Pal.ASPHALT.darkened(0.08))
		GroundUtil.tex_poly(ci, pts, grain, 1.0, Color(1, 1, 1, 0.7))
		GroundUtil.outline(ci, pts, TAR, 2.0)
	# sunken patches of stones
	for k in 3:
		var c := _p(s, GroundUtil.rr(sd, 160 + k, float(s["u0"]) + 2.0, float(s["u1"]) - 2.0), GroundUtil.rr(sd, 163 + k, -5.0, 5.0))
		GroundUtil.soft_blob(ci, c, GroundUtil.rr(sd, 166 + k, 0.5, 1.2) * M, Color(0.02, 0.02, 0.03, 0.14), sd + 70 + k, Vector2(1.4, 1.0))


func _oil(ci: CanvasItem, s: Dictionary, busy: bool) -> void:
	var sd: int = s["seed"]
	var n := GroundUtil.ri(sd, 170, 3, 7) + (3 if busy else 0)
	for k in n:
		var side := 1.0 if GroundUtil.r01(sd, 171 + k) < 0.5 else -1.0
		var in_lane := GroundUtil.r01(sd, 200 + k) < 0.3
		var v := side * (GroundUtil.rr(sd, 180 + k, 4.2, 5.1) if not in_lane else GroundUtil.rr(sd, 181 + k, 1.4, 2.6))
		if s["kind"] == "bowery" and absf(v) < BED + 0.3:
			v = side * GroundUtil.rr(sd, 182 + k, BED + 0.4, 4.0)
		var u := GroundUtil.rr(sd, 190 + k, float(s["u0"]) + 1.0, float(s["u1"]) - 1.0)
		var c := _p(s, u, v)
		var rad := GroundUtil.rr(sd, 210 + k, 0.22, 0.55) * M
		var st := Vector2(1.5, 1.0) if not s["ns"] else Vector2(1.0, 1.5)
		GroundUtil.soft_blob(ci, c, rad, OIL, sd + 300 + k, st)
		if GroundUtil.r01(sd, 220 + k) < 0.4:
			GroundUtil.soft_blob(ci, c + (Vector2(0, 1.1 * M) if s["ns"] else Vector2(1.1 * M, 0)), rad * 0.6, OIL, sd + 400 + k, st)


func _potholes(ci: CanvasItem, s: Dictionary) -> void:
	var sd: int = s["seed"]
	if s["kind"] == "cobble" or GroundUtil.r01(sd, 230) > 0.55:
		return
	var c := _p(s, GroundUtil.rr(sd, 231, float(s["u0"]) + 4.0, float(s["u1"]) - 4.0), _v_free(s, sd, 232, -5.0, 5.0))
	pothole(ci, c, GroundUtil.rr(sd, 233, 0.25, 0.45) * M, sd + 1)
	s["pothole"] = c


static func pothole(ci: CanvasItem, c: Vector2, r: float, s: int) -> void:
	# crumbled, paler asphalt around the hole
	ci.draw_colored_polygon(GroundUtil.blob(c, r * 1.35, s, 14, 0.32), Color(0.55, 0.55, 0.57, 0.08))
	ci.draw_colored_polygon(GroundUtil.blob(c, r * 1.12, s + 5, 14, 0.3), Color(0.02, 0.02, 0.03, 0.18))
	var pts := GroundUtil.blob(c, r, s + 1, 13, 0.34)
	ci.draw_colored_polygon(pts, Color("2c2d30"))
	# the floor of the hole: loose gravel, in the shade of the rim toward the light
	ci.draw_colored_polygon(GroundUtil.blob(c + Vector2(r * 0.14, r * 0.16), r * 0.72, s + 2, 11, 0.3), Color("343538"))
	ci.draw_colored_polygon(GroundUtil.blob(c - Vector2(r * 0.2, r * 0.22), r * 0.55, s + 3, 10, 0.3), Color(0.0, 0.0, 0.02, 0.35))
	for k in 9:
		var a := GroundUtil.r01(s, 30 + k) * TAU
		var q := c + Vector2(cos(a), sin(a)) * r * GroundUtil.rr(s, 40 + k, 0.1, 0.75)
		ci.draw_circle(q, GroundUtil.rr(s, 50 + k, 0.8, 1.6), Color(0.42, 0.42, 0.43, 0.55), true, -1.0, true)
	# lit far lip, dark near lip
	var n := pts.size()
	var far := PackedVector2Array()
	var near := PackedVector2Array()
	for k in n + 1:
		var q := pts[k % n]
		if (q - c).dot(Vector2(0.7, 0.7)) > 0.0:
			far.append(q)
		else:
			near.append(q)
	if far.size() > 1:
		ci.draw_polyline(far, Color(0.62, 0.62, 0.64, 0.35), 1.4, true)
	if near.size() > 1:
		ci.draw_polyline(near, Color(0.0, 0.0, 0.02, 0.5), 1.6, true)


func _puddle_marks(ci: CanvasItem, s: Dictionary) -> void:
	for pd in puddles(s):
		ci.draw_colored_polygon(GroundUtil.blob(pd[0], pd[1], pd[2], 14, 0.3, pd[3]), Color(0.02, 0.02, 0.03, 0.12))


## Where puddles form on a segment: [centre px, radius px, seed, stretch].
func puddles(s: Dictionary) -> Array:
	if s.has("_puddles"):
		return s["_puddles"]
	var sd: int = s["seed"]
	var out := []
	var n := GroundUtil.ri(sd, 240, 1, 4)
	var along := Vector2(0, 1) if s["ns"] else Vector2(1, 0)
	for k in n:
		var gutter := GroundUtil.r01(sd, 241 + k) < 0.6
		var side := 1.0 if GroundUtil.r01(sd, 245 + k) < 0.5 else -1.0
		var v := side * (HALF - 0.45) if gutter else _v_free(s, sd, 249 + k, -4.0, 4.0)
		var u := GroundUtil.rr(sd, 253 + k, float(s["u0"]) + 4.5, float(s["u1"]) - 4.5)
		var r := GroundUtil.rr(sd, 257 + k, 0.35, 0.8) * M
		var st := Vector2(1.0, 1.0) + along.abs() * (1.2 if gutter else 0.4)
		out.append([_p(s, u, v), r, sd + 500 + k, st])
	if s.has("pothole"):
		out.append([s["pothole"], 0.45 * M, sd + 777, Vector2(1.1, 1.0)])
	s["_puddles"] = out
	return out


## Painted crossing lines on asphalt (two worn bars), granite crossing stones on Belgian block.
func _crossing(ci: CanvasItem, s: Dictionary, ua: float, ub: float) -> void:
	var sd: int = s["seed"] + int(ua * 3.0)
	var v0 := -HALF + 0.35
	var v1 := HALF - 0.35
	if s["kind"] == "cobble":
		var um := (ua + ub) * 0.5
		for row in 2:
			var ra := um - 0.62 + float(row) * 0.62
			var v := v0
			var k := 0
			while v < v1:
				k += 1
				var l := minf(GroundUtil.rr(sd, 10 + k + row * 40, 0.8, 1.5), v1 - v)
				var r := _r(s, ra, v, ra + 0.6, v + l)
				var c := Pal.PARAPET_STONE.lightened(GroundUtil.rr(sd, 60 + k + row * 40, -0.08, 0.1))
				ci.draw_rect(r.grow(-1.0), c)
				GroundUtil.tex_rect(ci, r.grow(-1.0), grain, 1.0, Color(1, 1, 1, 0.5))
				ci.draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(r.size.x - 2, 1.5)), Color(1, 1, 1, 0.14))
				ci.draw_rect(Rect2(r.position + Vector2(1, r.size.y - 2.5), Vector2(r.size.x - 2, 1.5)), Color(0, 0, 0, 0.18))
				v += l
		return
	# two solid bars, worn by traffic where the tyres run
	for edge: float in [ua, ub - 0.34]:
		var v := v0
		var k := 0
		while v < v1:
			k += 1
			var l := minf(GroundUtil.rr(sd, 100 + k + int(edge), 1.0, 2.6), v1 - v)
			var wear := 1.0
			for t: float in [-2.78, -1.22, 1.22, 2.78, -4.9, -3.3, 3.3, 4.9]:
				if absf(v + l * 0.5 - t) < 0.7:
					wear = 0.72
			var a := GroundUtil.rr(sd, 130 + k + int(edge), 0.78, 0.92) * wear
			ci.draw_rect(_r(s, edge, v, edge + 0.34, v + l), Color(Pal.PAINT, a))
			v += l
		# chips where the asphalt shows through
		for c in 6:
			var q := _p(s, edge + GroundUtil.rr(sd, 160 + c, 0.04, 0.3), GroundUtil.rr(sd, 170 + c + int(edge), v0, v1))
			ci.draw_circle(q, GroundUtil.rr(sd, 180 + c, 1.2, 2.6), Color(Pal.ASPHALT, 0.7), true, -1.0, true)
		ci.draw_rect(_r(s, edge, v0, edge + 0.34, v1), Color(0.3, 0.28, 0.24, 0.12), false, 1.0, true)


func _litter(ci: CanvasItem, s: Dictionary) -> void:
	var sd: int = s["seed"]
	var n := GroundUtil.ri(sd, 260, 5, 12)
	for k in n:
		var side := 1.0 if GroundUtil.r01(sd, 261 + k) < 0.5 else -1.0
		var v := side * GroundUtil.rr(sd, 270 + k, HALF - 0.9, HALF - 0.12)
		var u := GroundUtil.rr(sd, 280 + k, float(s["u0"]) + 0.5, float(s["u1"]) - 0.5)
		litter_bit(ci, _p(s, u, v), sd + k * 11)
	# horse droppings on the old streets
	if s["kind"] != "asphalt" and GroundUtil.r01(sd, 290) < 0.6:
		var c := _p(s, GroundUtil.rr(sd, 291, float(s["u0"]) + 5.0, float(s["u1"]) - 5.0), GroundUtil.rr(sd, 292, -4.5, 4.5))
		for q in 5:
			ci.draw_circle(c + Vector2(GroundUtil.rr(sd, 293 + q, -6, 6), GroundUtil.rr(sd, 298 + q, -5, 5)), GroundUtil.rr(sd, 303 + q, 2.0, 3.6),
				Color(0.26, 0.2, 0.13, 0.9), true, -1.0, true)


## A scrap of paper, a butt, a bottle cap.
static func litter_bit(ci: CanvasItem, p: Vector2, s: int) -> void:
	var roll := GroundUtil.r01(s, 1)
	var rot := GroundUtil.r01(s, 2) * TAU
	if roll < 0.45:
		var sz := Vector2(GroundUtil.rr(s, 3, 5, 10), GroundUtil.rr(s, 4, 4, 8))
		var col := Pal.PAPER.darkened(GroundUtil.rr(s, 5, 0.05, 0.3))
		ci.draw_colored_polygon(GroundUtil.orect(p, sz, rot), Color(col, 0.85))
		if GroundUtil.r01(s, 6) < 0.5:
			ci.draw_line(p - Vector2(sz.x * 0.3, 0).rotated(rot), p + Vector2(sz.x * 0.3, 0).rotated(rot), Color(0.2, 0.18, 0.15, 0.4), 1.0, true)
	elif roll < 0.8:
		var d := Vector2(3.2, 0).rotated(rot)
		ci.draw_line(p - d, p + d, Color(0.85, 0.8, 0.7, 0.9), 1.6, true)
		ci.draw_line(p + d * 0.4, p + d, Color(0.72, 0.5, 0.3, 0.9), 1.6, true)
	else:
		ci.draw_circle(p, 1.8, Color(0.6, 0.55, 0.4, 0.85), true, -1.0, true)


## An iron manhole cover set in its frame.
static func manhole(ci: CanvasItem, c: Vector2, s: int) -> void:
	var r := 0.38 * M
	ci.draw_circle(c, r + 3.0, Color(0.02, 0.02, 0.03, 0.3), true, -1.0, true)
	ci.draw_circle(c, r + 1.2, Color("3b3b3d"), true, -1.0, true)
	ci.draw_circle(c, r - 1.5, Pal.MANHOLE, true, -1.0, true)
	var ring := Color("47474a")
	if GroundUtil.r01(s, 1) < 0.5:
		# radial ribs
		for ring_r in [r * 0.82, r * 0.5]:
			ci.draw_arc(c, ring_r, 0.0, TAU, 28, ring, 1.3, true)
		for k in 12:
			var a := TAU * float(k) / 12.0 + GroundUtil.r01(s, 2)
			ci.draw_line(c + Vector2(cos(a), sin(a)) * r * 0.5, c + Vector2(cos(a), sin(a)) * r * 0.8, ring, 1.2, true)
		ci.draw_circle(c, r * 0.2, ring, true, -1.0, true)
		ci.draw_circle(c, r * 0.12, Pal.MANHOLE, true, -1.0, true)
	else:
		# a waffle grid
		ci.draw_arc(c, r * 0.86, 0.0, TAU, 28, ring, 1.3, true)
		var step := r * 0.3
		for k in range(-2, 3):
			var o := float(k) * step
			var h := sqrt(maxf(0.0, (r * 0.8) * (r * 0.8) - o * o))
			ci.draw_line(c + Vector2(o, -h), c + Vector2(o, h), ring, 1.2, true)
			ci.draw_line(c + Vector2(-h, o), c + Vector2(h, o), ring, 1.2, true)
	# pick holes
	ci.draw_circle(c + Vector2(r * 0.62, 0).rotated(0.7), 1.6, Color(0.02, 0.02, 0.02), true, -1.0, true)
	ci.draw_circle(c + Vector2(-r * 0.62, 0).rotated(0.7), 1.6, Color(0.02, 0.02, 0.02), true, -1.0, true)
	# worn bright rim toward the light, dark on the far side
	ci.draw_arc(c, r - 0.5, PI * 1.0, PI * 1.5, 12, Color(0.75, 0.75, 0.78, 0.35), 1.4, true)
	ci.draw_arc(c, r - 0.5, 0.0, PI * 0.5, 12, Color(0, 0, 0, 0.35), 1.4, true)
	GroundUtil.soft(ci, c + Vector2(r * 0.8, r * 0.6), Vector2(r * 0.7, r * 0.45), Color(0.35, 0.22, 0.12, 0.1), 0.6)


# ------------------------------------------------------------------ intersections

func paint_intersection(ci: CanvasItem, x: Dictionary) -> void:
	var r: Rect2 = x["r"]
	var R := Rect2(r.position * M, r.size * M)
	var sd: int = x["seed"]
	var c := R.get_center()
	# wear from both directions: the crossing tyre tracks darken the middle
	for v: float in [-2.78, -1.22, 1.22, 2.78]:
		ci.draw_rect(Rect2(Vector2(c.x + float(v) * M - 0.2 * M, R.position.y), Vector2(0.4 * M, R.size.y)), Color(0.58, 0.59, 0.63, 0.04))
		ci.draw_rect(Rect2(Vector2(R.position.x, c.y + float(v) * M - 0.2 * M), Vector2(R.size.x, 0.4 * M)), Color(0.58, 0.59, 0.63, 0.04))
	GroundUtil.soft_blob(ci, c, 3.2 * M, Color(0.03, 0.03, 0.05, 0.12), sd, Vector2(1.0, 1.0))
	for k in 4:
		var q := c + Vector2(GroundUtil.rr(sd, 10 + k, -4.0, 4.0), GroundUtil.rr(sd, 20 + k, -4.0, 4.0)) * M
		GroundUtil.soft_blob(ci, q, GroundUtil.rr(sd, 30 + k, 0.2, 0.5) * M, OIL, sd + 40 + k)
	# seams where the crossing meets the streets
	for e in 4:
		var a: Vector2 = [R.position, Vector2(R.end.x, R.position.y), R.end, Vector2(R.position.x, R.end.y)][e]
		var b: Vector2 = [Vector2(R.end.x, R.position.y), R.end, Vector2(R.position.x, R.end.y), R.position][e]
		if GroundUtil.r01(sd, 50 + e) < 0.6:
			ci.draw_polyline(GroundUtil.wave(a, b, sd + e, 2.0, 80.0), Color(TAR, 0.55), 2.0, true)
	for k in 3:
		crack(ci, c + Vector2(GroundUtil.rr(sd, 60 + k, -5, 5), GroundUtil.rr(sd, 70 + k, -5, 5)) * M, sd + 80 + k, GroundUtil.rr(sd, 90 + k, 0.8, 1.8) * M, CRACK)
	if x["bowery"]:
		var s := {"ns": true, "c": float(x["i"]) * CityPlan.PITCH}
		_track_bed(ci, s, r.position.y, r.end.y)
		_rails(ci, s, r.position.y, r.end.y)
		var o := GroundUtil.sh(WIRE_H)
		for v: float in [-1.7, 1.7]:
			ci.draw_line(_p(s, r.position.y, float(v)) + o, _p(s, r.end.y, float(v)) + o, Color(0.02, 0.02, 0.04, 0.12), 1.6, true)
	manhole(ci, (x["manhole"] as Vector2) * M, sd + 5)
	if x.get("dome", false):
		traffic_dome(ci, r.get_center() * M)


## A 1920s "traffic mushroom": a low cast-iron dome in the middle of the crossing, painted in
## bands, with a little lamp on top. Cars drive round it (or over it).
static func traffic_dome(ci: CanvasItem, c: Vector2) -> void:
	var r := 0.42 * M
	ci.draw_circle(c + GroundUtil.sh(0.25), r, Color(0, 0, 0.03, 0.3), true, -1.0, true)
	ci.draw_circle(c, r, Color("2a2a2c"), true, -1.0, true)
	for k in 3:
		var rr := r * (0.92 - float(k) * 0.26)
		ci.draw_circle(c, rr, Pal.GOLD.darkened(0.15) if k % 2 == 0 else Color("222224"), true, -1.0, true)
	ci.draw_circle(c, r * 0.16, Color("e0d8c0"), true, -1.0, true)
	ci.draw_arc(c, r - 1.0, PI, PI * 1.5, 10, Color(1, 1, 1, 0.3), 1.4, true)


func paint_intersection_glow(ci: CanvasItem, x: Dictionary) -> void:
	if not x.get("dome", false):
		return
	var c := (x["r"] as Rect2).get_center() * M
	GroundUtil.soft(ci, c, Vector2(0.5, 0.5) * M, Color(1.0, 0.75, 0.35, 0.4), 0.0, 3)
	ci.draw_circle(c, 0.08 * M, Color(1.0, 0.9, 0.7), true, -1.0, true)


func paint_intersection_high(ci: CanvasItem, x: Dictionary) -> void:
	if not x["bowery"]:
		return
	var r: Rect2 = x["r"]
	var s := {"ns": true, "c": float(x["i"]) * CityPlan.PITCH}
	for v: float in [-1.7, 1.7]:
		_line(ci, s, r.position.y, float(v), r.end.y, float(v), Color(0.07, 0.07, 0.08, 0.8), 1.4)


# ------------------------------------------------------------------ wet weather

## Drawn in its own node, faded in with the rain: darker, glossier asphalt, and puddles.
func paint_segment_wet(ci: CanvasItem, s: Dictionary) -> void:
	var rect := _r(s, float(s["u0"]), -HALF, float(s["u1"]), HALF)
	ci.draw_rect(rect, Color(0.02, 0.03, 0.06, 0.3))
	# a cool sheen along the crown and the tyre paths
	for v: float in [-2.0, 2.0, 0.0]:
		ci.draw_rect(_r(s, float(s["u0"]), float(v) - 0.5, float(s["u1"]), float(v) + 0.5), Color(0.55, 0.62, 0.75, 0.04))
	# water running along both gutters
	for side: float in [-1.0, 1.0]:
		ci.draw_rect(_r(s, float(s["u0"]), side * (HALF - 0.28), float(s["u1"]), side * (HALF - 0.05)), Color(0.5, 0.56, 0.66, 0.16))
	for pd in puddles(s):
		puddle(ci, pd[0], pd[1], pd[2], pd[3])


func paint_intersection_wet(ci: CanvasItem, x: Dictionary) -> void:
	var r: Rect2 = x["r"]
	ci.draw_rect(Rect2(r.position * M, r.size * M), Color(0.02, 0.03, 0.06, 0.3))
	var sd: int = x["seed"]
	if GroundUtil.r01(sd, 99) < 0.5:
		var c := (r.get_center() + Vector2(GroundUtil.rr(sd, 97, -4.0, 4.0), GroundUtil.rr(sd, 98, -4.0, 4.0))) * M
		puddle(ci, c, 0.6 * M, sd + 3, Vector2(1.3, 1.0))


static func puddle(ci: CanvasItem, c: Vector2, r: float, s: int, st: Vector2) -> void:
	# a damp dark rim, then still water reflecting a grey sky, soft at the edges
	ci.draw_colored_polygon(GroundUtil.blob(c, r * 1.14, s, 14, 0.3, st), Color(0.02, 0.03, 0.05, 0.1))
	ci.draw_colored_polygon(GroundUtil.blob(c, r, s, 14, 0.3, st), Color(0.27, 0.29, 0.31, 0.38))
	ci.draw_colored_polygon(GroundUtil.blob(c, r * 0.84, s, 14, 0.3, st), Color(0.34, 0.36, 0.39, 0.38))
	ci.draw_colored_polygon(GroundUtil.blob(c + Vector2(r * 0.12, r * 0.14), r * 0.52, s + 3, 12, 0.3, st), Color(0.46, 0.48, 0.51, 0.18))
	var pts := GroundUtil.blob(c, r * 0.9, s, 14, 0.3, st)
	var hi := PackedVector2Array()
	for k in range(8, 12):
		hi.append(pts[k % pts.size()])
	ci.draw_polyline(hi, Color(0.8, 0.83, 0.88, 0.25), 1.2, true)


## Lamp light reflected on the wet street at night (faded in with wet x night).
func paint_reflections(ci: CanvasItem, heads: Array) -> void:
	for h in heads:
		var p: Vector2 = h
		GroundUtil.soft(ci, p + Vector2(0, 0.35 * M), Vector2(1.1, 1.9) * M, Color(Pal.LAMP, 0.22), 0.0, 4)
		GroundUtil.soft(ci, p + Vector2(0, 0.6 * M), Vector2(0.28, 1.25) * M, Color(Pal.LAMP.lightened(0.2), 0.3), 0.0, 3)
