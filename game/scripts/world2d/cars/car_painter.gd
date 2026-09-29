class_name CarPainter
extends RefCounted
## Paints one vehicle from above, nose to +x (CarArt owns the layers and decides when each one
## redraws). The shared chassis lives here: tyres, fenders, running boards, hood with louvres,
## radiator shell, headlamps on their bar, bumpers, the spare, the tail lamp, the shadow. What
## makes each kind (the cabin, the open tub, the stake bed, the box) is in CarBodies.
## Pixels, local frame; `L` points toward the sun (north-west) in this frame.

const M := W.M
const UNDER := Color("121110")
const BOARD := Color("1e1d1c")
const ALU := Color("8e9398")
const FENDER := Color("16161a")
const LENS := Color("d6d9cc")
const RED_LENS := Color("7a1712")
const AMBER := Color("e0a040")
const SHADOW_K := 0.8            # car shadows: this share of GroundUtil.SV per metre of height

var kind := "sedan"
var s: Dictionary
var sd := 0
var paint := Pal.CAR_BLACK       # the body colour (hood, cowl, tub, roof edges)
var fender := FENDER             # fenders, running boards, aprons: black enamel on nearly everything
var roof_col := Pal.CAR_BLACK
var insert_col := Color("1d1b1a")
var trim := Color(0, 0, 0, 0)    # the pinstripe along the belt
var family := Color(0, 0, 0, 0)
var trade: Dictionary = {}
var chrome_shell := true         # nickel radiator shell (trucks: black enamel)
var spare_cover := false
var rack := 0                    # vans: 0 plain, 1 ladder on a rack
var passenger := 0               # tourers: 0 none, 1 beside the driver, 2 in the back
var dual_cowl := false
var horn := true
var hat_col := Color("3a3d45")
var hat_band := Color("1c1a18")
var coat_col := Color("25262b")
var seat_col := Pal.LEATHER
var skin := Color("e0b088")
var pass_hat := ""
var pass_col := Color("5a3a5a")


func _init(k: String, body: Color, fam: Color, seed_value: int) -> void:
	kind = k if CarSpec.make(k).size() > 0 else "sedan"
	sd = seed_value
	s = CarSpec.make(kind)
	family = fam
	var r := W.rng(seed_value ^ 0x2545F491)
	paint = body if body.a > 0.0 else Pal.CAR_BLACK
	roof_col = paint
	var dark := paint.get_luminance() < 0.08
	trim = [Color("c9b98a"), Color("8a2a24"), Color("b89a4a"), Color(0, 0, 0, 0)][r.randi_range(0, 3)] if dark else Color("d8cfb4")
	if not dark and r.randf() < 0.4:
		trim = Color(0, 0, 0, 0)
	spare_cover = r.randf() < 0.45
	horn = r.randf() < 0.7
	match kind:
		"taxi":
			paint = Color("d6a62c")
			roof_col = Color("1a1918")
			trim = Color(0, 0, 0, 0)
			spare_cover = true
		"police":
			paint = Pal.CAR_BLACK
			roof_col = Color("e4e0d6")
			trim = Color(0, 0, 0, 0)
			spare_cover = false
		"truck":
			var base := fam if fam.a > 0.0 else Color("5a5048")
			paint = base.darkened(0.3).lerp(Color("2a2522"), 0.12)
			roof_col = paint
			chrome_shell = false
			trim = Color(0, 0, 0, 0)
		"delivery":
			trade = CarSpec.TRADES[CarSpec.trade_for(seed_value)]
			paint = trade["cab"]
			roof_col = paint
			chrome_shell = false
			trim = Color(0, 0, 0, 0)
		"van":
			rack = 1 if r.randf() < 0.45 else 0
			chrome_shell = r.randf() < 0.5
		"touring":
			seat_col = [Pal.LEATHER, Color("6a4a30"), Color("2a2624"), Color("5a2a2a")][r.randi_range(0, 3)]
			passenger = r.randi_range(0, 2)
			dual_cowl = r.randf() < 0.5
			if paint.get_luminance() < 0.08 and r.randf() < 0.5:
				# a rich man's tourer: two-tone, bright paint above the black fenders
				paint = [Color("4a1e22"), Color("1f3a2c"), Color("2a3450"), Color("5a4a36")][r.randi_range(0, 3)]
				roof_col = paint
	hat_col = Pal.SUITS[r.randi_range(0, Pal.SUITS.size() - 1)].lightened(0.08)
	hat_band = [Color("1c1a18"), Color("3a2a22"), Color("2a2a38")][r.randi_range(0, 2)]
	coat_col = Pal.SUITS[r.randi_range(0, Pal.SUITS.size() - 1)]
	skin = Pal.SKIN[r.randi_range(0, 3)]
	pass_hat = ["cloche", "fedora", "homburg"][r.randi_range(0, 2)]
	pass_col = [Color("5a3a5a"), Color("7a2e2a"), Color("2e4a5a"), Color("4a4037")][r.randi_range(0, 3)]


func v(x: float, y: float) -> Vector2:
	return Vector2(x * M, y * M)


func rm(x0: float, x1: float, y0: float, y1: float) -> Rect2:
	return Rect2(x0 * M, y0 * M, (x1 - x0) * M, (y1 - y0) * M)


func length_px() -> float:
	return (float(s["bump"]) - float(s["rbump"])) * M


# ------------------------------------------------------------------ outlines

## A fender over a wheel at `wx`, seen from above: `tip` is its free end (front tip, or rear
## tip), `join` where it sweeps down into the running board. Right side (+y).
func fender_pts(tip: float, join: float, yi: float, yo: float, wx: float) -> PackedVector2Array:
	var d := signf(tip - join)
	var rb: Array = s["rb"]
	var bi := float(rb[2])
	var bo := float(rb[3])
	var mid := (yi + yo) * 0.5
	var c := PackedVector2Array([
		v(tip, mid + 0.015), v(tip - d * 0.11, yo - 0.04), v(wx + d * 0.24, yo), v(wx - d * 0.3, yo - 0.004),
		v(join + d * 0.3, bo + 0.01), v(join + d * 0.02, bo), v(join + d * 0.02, bi + 0.01),
		v(join + d * 0.32, bi - 0.01), v(wx - d * 0.32, yi + 0.012), v(wx + d * 0.26, yi), v(tip - d * 0.13, yi + 0.05)])
	return CarPaint.spline(c, 5)


## The body at the belt line: rounded at the back, tapering at the front into the cowl.
func tub_pts(x0: float, x1: float, hw: float, rr: float, front_hw: float, taper_from: float) -> PackedVector2Array:
	var right := PackedVector2Array()
	var n := 10
	for i in n + 1:
		var x := lerpf(x1, taper_from, float(i) / n)
		var t := smoothstep(0.0, 1.0, (x - taper_from) / maxf(0.01, x1 - taper_from))
		right.append(v(x, lerpf(hw, front_hw, t)))
	var seg := 6
	for i in seg + 1:
		var a := lerpf(PI * 0.5, PI, float(i) / seg)
		right.append(v(x0 + rr + rr * cos(a), hw - rr + rr * sin(a)))
	var pts := PackedVector2Array()
	pts.append_array(right)
	for i in range(right.size() - 1, -1, -1):
		pts.append(Vector2(right[i].x, -right[i].y))
	return pts


## A tapered, round-cornered hood.
func hood_pts() -> PackedVector2Array:
	var h: Array = s["hood"]
	var x0 := float(h[0])
	var x1 := float(h[1])
	var hw0 := float(h[2])
	var hw1 := float(h[3])
	var pts := CarPaint.rpoly(rm(x0, x1, -hw0, hw0), Vector4(0.07 * M, 0.07 * M, 0.02 * M, 0.02 * M), 4)
	for i in pts.size():
		var t := clampf((pts[i].x / M - x0) / (x1 - x0), 0.0, 1.0)
		pts[i].y *= lerpf(1.0, hw1 / hw0, t)
	return pts


# ------------------------------------------------------------------ shadow

## The outlines that cast the shadow, with their height (metres): the whole car low down, and
## its tallest parts.
func footprints(load_n: int) -> Array:
	var low := PackedVector2Array()
	var bw := float(s["bw"])
	low.append(v(float(s["bump"]), -bw))
	low.append(v(float(s["bump"]), bw))
	var ff: Array = s["ff"]
	var yo := float(ff[3])
	low.append(v(float(ff[1]) - 0.1, yo - 0.03))
	low.append(v(float(ff[1]) - 0.1, -yo + 0.03))
	low.append(v(float(s["fa"]), yo))
	low.append(v(float(s["fa"]), -yo))
	var rear := float(s["rbump"])
	var rf: Array = s["rf"]
	if not rf.is_empty():
		low.append(v(float(s["ra"]), float(rf[3])))
		low.append(v(float(s["ra"]), -float(rf[3])))
		low.append(v(float(rf[0]) + 0.1, float(rf[3]) - 0.05))
		low.append(v(float(rf[0]) + 0.1, -float(rf[3]) + 0.05))
	var tub: Array = s["tub"]
	low.append(v(float(tub[0]), float(tub[2]) - float(tub[3])))
	low.append(v(float(tub[0]), -float(tub[2]) + float(tub[3])))
	low.append(v(rear, 0.4))
	low.append(v(rear, -0.4))
	var parts := []
	if s.has("bed"):
		var b: Array = s["bed"]
		var bed := CarPaint.rpoly(rm(float(b[0]), float(b[1]), -float(b[2]), float(b[2])), 3.0, 2)
		low.append_array(bed)
		parts.append([bed, 1.25])
		if load_n > 0:
			var rows := ceili(minf(load_n, 6) / 2.0)
			var x1 := float(b[1]) - 0.1
			var stack := rm(x1 - rows * 0.64, x1, -0.78, 0.78)
			parts.append([CarPaint.rpoly(stack, 2.0, 1), 1.0 + (0.9 if load_n > 6 else 0.45)])
	if s.has("box"):
		var bx: Array = s["box"]
		var box := CarPaint.rpoly(rm(float(bx[0]), float(bx[1]), -float(bx[2]), float(bx[2])), 3.0, 2)
		low.append_array(box)
		parts.append([box, float(s["h_top"])])
	var ro: Array = s["roof"]
	if not ro.is_empty():
		var roof := CarPaint.rpoly(rm(float(ro[0]), float(ro[1]), -float(ro[2]), float(ro[2])), float(ro[4]) * M, 3)
		parts.append([roof, 2.0 if s.has("box") or s.has("bed") else float(s["h_top"])])
	elif kind == "touring":
		parts.append([tub_pts(float(tub[0]), float(tub[1]) - 0.2, float(tub[2]), float(tub[3]), 0.5, 0.2), 1.1])
	var hull := Geometry2D.convex_hull(low)
	hull.remove_at(hull.size() - 1)
	return [[hull, float(s["h_low"])]] + parts


## The drop shadow: the union of every footprint swept toward `off` (px per metre of height,
## already turned into the car's frame), with a soft edge; and the dark contact right under it.
func draw_shadow(ci: CanvasItem, off: Vector2, strength: float, load_n: int) -> void:
	var fps := footprints(load_n)
	var shape := PackedVector2Array()
	for fp in fps:
		var pts: PackedVector2Array = fp[0]
		var o: Vector2 = off * float(fp[1]) * SHADOW_K
		var sweep := PackedVector2Array()
		sweep.append_array(pts)
		sweep.append_array(CarPaint.shift(pts, o))
		var h := Geometry2D.convex_hull(sweep)
		h.remove_at(h.size() - 1)
		if shape.is_empty():
			shape = h
		else:
			var merged := Geometry2D.merge_polygons(shape, h)
			var best := shape
			var best_a := 0.0
			for m in merged:
				var a := absf(CarPaint.signed_area(m))
				if a > best_a and not Geometry2D.is_polygon_clockwise(m) == Geometry2D.is_polygon_clockwise(shape) or a > best_a:
					best_a = a
					best = m
			shape = best
	var sh := Color(0.02, 0.02, 0.05, 0.36 * strength)
	CarPaint.feather(ci, shape, 7.0, sh)
	# right under the car: the ground it hides from the sky
	var under: PackedVector2Array = fps[0][0]
	CarPaint.feather(ci, CarPaint.inset(under, 3.0), 8.0, Color(0.01, 0.01, 0.03, 0.42))
	# tyres on the ground
	for w in wheels():
		var c: Vector2 = w["c"]
		FastDraw.soft(ci, Transform2D.IDENTITY, c + off * 0.12, Vector2(float(w["len"]) * 0.6, float(w["wid"]) * 1.1), 0.0, Color(0, 0, 0, 0.45))


# ------------------------------------------------------------------ wheels

func wheels() -> Array:
	var out := []
	var tr := float(s["tr"]) * 2.0 * M
	var tw := float(s["tw"]) * M
	var track := float(s["track"])
	for sg: float in [-1.0, 1.0]:
		out.append({"c": v(float(s["fa"]), track * sg), "len": tr, "wid": tw, "front": true})
		if bool(s["dual"]):
			for k: float in [-0.085, 0.085]:
				out.append({"c": v(float(s["ra"]), (track + k) * sg), "len": tr, "wid": tw * 1.05, "front": false})
		else:
			out.append({"c": v(float(s["ra"]), track * sg), "len": tr, "wid": tw, "front": false})
	return out


func draw_wheels(ci: CanvasItem, steer_angle: float, L: Vector2) -> void:
	# the front axle and the drag link show through the gaps beside the hood
	var fa := float(s["fa"])
	var track := float(s["track"])
	ci.draw_line(v(fa, -track + 0.05), v(fa, track - 0.05), Color("1c1b1a"), 0.07 * M, true)
	ci.draw_line(v(fa - 0.02, -track + 0.1), v(fa - 0.02, track - 0.1), Color("2a2927"), 0.02 * M, true)
	for w in wheels():
		var rot := steer_angle if bool(w["front"]) else 0.0
		CarPaint.tyre(ci, w["c"], float(w["len"]), float(w["wid"]), rot, L)


# ------------------------------------------------------------------ chassis parts

func draw_underbody(ci: CanvasItem) -> void:
	var rad: Array = s["rad"]
	var x0 := float(s["ra"]) - 0.5
	var x1 := float(rad[0]) + 0.04
	var hw := float(s["track"]) - 0.02
	CarPaint.fill(ci, CarPaint.rpoly(rm(x0, x1, -hw, hw), 0.12 * M, 3), UNDER)
	# the frame rails and the front spring
	for sg: float in [-1.0, 1.0]:
		ci.draw_line(v(x0 + 0.1, 0.36 * sg), v(x1 - 0.05, 0.3 * sg), Color("1a1918"), 0.06 * M, true)
	ci.draw_line(v(float(s["fa"]) + 0.08, -0.42), v(float(s["fa"]) + 0.08, 0.42), Color("201f1d"), 0.05 * M, true)


func draw_running_boards(ci: CanvasItem, L: Vector2) -> void:
	var rb: Array = s["rb"]
	var x0 := float(rb[0])
	var x1 := float(rb[1])
	var yi := float(rb[2])
	var yo := float(rb[3])
	for sg: float in [-1.0, 1.0]:
		var r := rm(x0, x1, yi, yo) if sg > 0.0 else rm(x0, x1, -yo, -yi)
		var pts := CarPaint.rpoly(r, 0.025 * M, 2)
		CarPaint.flat(ci, pts, BOARD, L, 1.2, 0.5)
		# ribbed rubber mat
		var ribs := 5
		for k in range(1, ribs):
			var y := lerpf(yi, yo, float(k) / ribs) * sg
			ci.draw_line(v(x0 + 0.05, y), v(x1 - 0.05, y), Color("0f0f0e"), 0.9, true)
			ci.draw_line(v(x0 + 0.05, y) + L * 0.8, v(x1 - 0.05, y) + L * 0.8, Color("2e2d2b"), 0.6, true)
		# the aluminium edge strip
		var edge_y := (yo - 0.012) * sg
		var bright := sg * L.y < -0.2
		ci.draw_line(v(x0 + 0.02, edge_y), v(x1 - 0.02, edge_y), ALU.lightened(0.25) if bright else ALU.darkened(0.2), 1.3, true)
		# the body's shadow falls across the board on the side away from the sun
		var away := maxf(0.0, sg * L.y)
		if away > 0.1:
			var w := (0.05 + 0.12 * away) * M
			var yin := yi * sg * M
			var q := PackedVector2Array([Vector2(x0 * M, yin), Vector2(x1 * M, yin), Vector2(x1 * M, yin + w * sg), Vector2(x0 * M, yin + w * sg)])
			var sc := Color(0, 0, 0, 0.45 * away)
			ci.draw_polygon(q, PackedColorArray([sc, sc, Color(0, 0, 0, 0), Color(0, 0, 0, 0)]))


func draw_fender(ci: CanvasItem, front: bool, L: Vector2) -> void:
	var f: Array = s["ff"] if front else s["rf"]
	if f.is_empty():
		return
	var tip := float(f[1]) if front else float(f[0])
	var join := float(f[0]) if front else float(f[1])
	var wx := float(s["fa"]) if front else float(s["ra"])
	var yi := float(f[2])
	var yo := float(f[3])
	var right := fender_pts(tip, join, yi, yo, wx)
	for sg: float in [-1.0, 1.0]:
		var pts := right if sg > 0.0 else CarPaint.mirror_y(right)
		CarPaint.panel(ci, pts, fender, L, 3.4, 0.2, 0.66)
		# the crown over the wheel catches the sky
		var mid := (yi + yo) * 0.5 * sg
		var d := signf(tip - join)
		CarPaint.streak(ci, v(wx + d * 0.42, mid) + L * 2.2, v(wx - d * 0.5, mid) + L * 2.2, 2.4, CarPaint.alpha(CarPaint.SKY, 0.32))
		CarPaint.streak(ci, v(tip - d * 0.1, mid) + L * 1.2, v(wx + d * 0.1, mid) + L * 1.2, 1.4, CarPaint.alpha(CarPaint.SKY, 0.16))
		CarPaint.rim(ci, pts, L, CarPaint.alpha(CarPaint.SKY, 0.45), 0.9, 0.35, 1.0)


func draw_hood(ci: CanvasItem, L: Vector2) -> void:
	var h: Array = s["hood"]
	var x0 := float(h[0])
	var x1 := float(h[1])
	var hw0 := float(h[2])
	var hw1 := float(h[3])
	var pts := hood_pts()
	CarPaint.panel(ci, pts, paint, L, 3.6, 0.18, 0.64)
	var sgn := -1.0 if L.y < 0.0 else 1.0
	var bright := paint.get_luminance() > 0.3
	var sheen := CarPaint.alpha(CarPaint.WARM if bright else CarPaint.SKY, 0.16 if bright else 0.2)
	# the panel on the sunny side of the hinge is brighter; a hot line runs along its crown
	CarPaint.streak(ci, v(x0 + 0.12, sgn * hw0 * 0.48), v(x1 - 0.08, sgn * hw1 * 0.48), hw1 * 0.36 * M, sheen)
	CarPaint.streak(ci, v(x0 + 0.2, sgn * 0.07), v(x1 - 0.15, sgn * 0.06), 1.6, CarPaint.alpha(Color.WHITE, 0.3 if bright else 0.26))
	# louvres on the side panels, toward the cowl
	var n := int(s["louvres"])
	var lc := CarPaint.dk(paint, 0.75)
	var lip := CarPaint.lit(paint, 0.3) if bright else CarPaint.gloss(paint, 0.3)
	for i in n:
		var x := x0 + 0.13 + i * 0.052
		if x > x1 - 0.3:
			break
		var t := (x - x0) / (x1 - x0)
		var hw := lerpf(hw0, hw1, t)
		for sg: float in [-1.0, 1.0]:
			var a := v(x, (hw - 0.045) * sg)
			var b := v(x, (hw - 0.16) * sg)
			ci.draw_line(a, b, lc, 1.3, true)
			ci.draw_line(a + L * 0.9, b + L * 0.9, lip, 0.6, true)
	# the centre hinge
	ci.draw_line(v(x0 + 0.02, 0.0), v(x1 - 0.02, 0.0), CarPaint.dk(paint, 0.7), 1.3, true)
	ci.draw_line(v(x0 + 0.02, 0.0) + L * 0.7, v(x1 - 0.02, 0.0) + L * 0.7, CarPaint.CHROME.darkened(0.1) if chrome_shell else lip, 0.7, true)
	# the seam against the cowl
	ci.draw_line(v(x0, -hw0 + 0.02), v(x0, hw0 - 0.02), CarPaint.dk(paint, 0.7), 1.0, true)


func draw_radiator(ci: CanvasItem, L: Vector2) -> void:
	var r: Array = s["rad"]
	var x0 := float(r[0])
	var x1 := float(r[1])
	var hw := float(r[2])
	var pts := CarPaint.rpoly(rm(x0, x1, -hw, hw), Vector4(0.05 * M, 0.05 * M, 0.02 * M, 0.02 * M), 3)
	if chrome_shell:
		CarPaint.chrome_poly(ci, pts, L, 1.3)
	else:
		CarPaint.panel(ci, pts, Color("141416"), L, 1.6, 0.25, 0.6)
		ci.draw_line(v(x1 - 0.02, -hw + 0.04), v(x1 - 0.02, hw - 0.04), CarPaint.CHROME.darkened(0.2), 0.8, true)
	# the filler cap (a motometer on the cars)
	var cap := v((x0 + x1) * 0.5 + 0.005, 0.0)
	if kind in ["sedan", "touring", "taxi", "police", "van"]:
		FastDraw.disc(ci, cap, 0.055 * M, CarPaint.CHROME_DK)
		FastDraw.disc(ci, cap, 0.042 * M, Color("c8c0a0"))
		ci.draw_arc(cap, 0.042 * M, 0.0, TAU, 14, CarPaint.CHROME_DK, 0.7, true)
		FastDraw.disc(ci, cap + L * 0.8, 0.012 * M, Color(1, 1, 1, 0.9))
		if kind == "touring":
			# the mascot: a winged figure leaning into the wind
			var m0 := cap + v(0.02, 0.0)
			var m1 := cap + v(0.16, 0.0)
			ci.draw_line(m0, m1, CarPaint.CHROME_DK, 2.4, true)
			ci.draw_line(m0 + L * 0.4, m1 + L * 0.4, CarPaint.CHROME_HI, 1.0, true)
			for sg: float in [-1.0, 1.0]:
				ci.draw_line(cap + v(0.06, 0.0), cap + v(0.02, 0.07 * sg), CarPaint.CHROME, 1.2, true)
	else:
		CarPaint.chrome_disc(ci, cap, 0.045 * M, L)


func draw_headlamps(ci: CanvasItem, L: Vector2) -> void:
	var lp: Array = s["lamp"]
	var lx := float(lp[0])
	var ly := float(lp[1])
	var lr := float(lp[2]) * M
	var ff: Array = s["ff"]
	var fin := float(ff[2])
	# the tie bar between the lamps, in front of the radiator
	CarPaint.chrome_bar(ci, v(lx - 0.02, -ly), v(lx - 0.02, ly), 0.035 * M, L)
	for sg: float in [-1.0, 1.0]:
		var c := v(lx, ly * sg)
		# the stalk down to the fender
		ci.draw_line(c, v(lx - 0.1, (fin + 0.06) * sg), Color("1a1a1c"), 0.04 * M, true)
		# the bowl
		FastDraw.disc(ci, c + Vector2(1.0, 1.4), lr * 1.05, Color(0, 0, 0, 0.35))
		CarPaint.chrome_disc(ci, c, lr, L)
		# the lens looks forward: a pale crescent on the front of the bowl
		ci.draw_arc(c, lr * 0.8, -1.15, 1.15, 12, LENS.darkened(0.25), lr * 0.34, true)
		ci.draw_arc(c + Vector2(0.4, 0), lr * 0.8, -0.8, 0.8, 10, LENS, lr * 0.16, true)
		ci.draw_arc(c, lr * 0.98, -1.2, 1.2, 12, CarPaint.CHROME_DK, 0.8, true)
	if horn and kind in ["sedan", "police", "taxi", "van", "touring"]:
		# the horn on the left, under the lamp
		var hc := v(lx - 0.28, -(ly - 0.03))
		ci.draw_line(hc, hc + v(0.1, 0.0), Color("1a1a1c"), 0.06 * M, true)
		CarPaint.chrome_disc(ci, hc + v(0.11, 0.0), 0.045 * M, L)


func draw_front_bumper(ci: CanvasItem, L: Vector2) -> void:
	var bx := float(s["bump"])
	var bw := float(s["bw"])
	var heavy := kind in ["truck", "delivery"]
	# brackets back to the frame
	for sg: float in [-1.0, 1.0]:
		ci.draw_line(v(bx - 0.02, 0.32 * sg), v(float(s["rad"][1]) - 0.02, 0.28 * sg), Color("1a1a1c"), 0.04 * M, true)
	if heavy:
		var pts := CarPaint.rpoly(rm(bx - 0.05, bx + 0.04, -bw, bw), 0.03 * M, 2)
		CarPaint.panel(ci, pts, Color("1a1a1c"), L, 1.2, 0.3, 0.6)
		CarPaint.streak(ci, v(bx, -bw + 0.1) + L, v(bx, bw - 0.1) + L, 1.0, CarPaint.alpha(CarPaint.SKY, 0.4))
		return
	for k: float in [-0.028, 0.028]:
		var x := bx + k
		var pts := PackedVector2Array()
		# the bar, its ends curling back
		for i in 17:
			var t := float(i) / 16.0
			var y := lerpf(-bw, bw, t)
			var curl := pow(absf(t * 2.0 - 1.0), 6.0) * 0.07
			pts.append(v(x - curl, y))
		ci.draw_polyline(pts, CarPaint.CHROME_DK, 0.034 * M, true)
		ci.draw_polyline(CarPaint.shift(pts, L * 0.3), CarPaint.CHROME, 0.02 * M, true)
		ci.draw_polyline(CarPaint.shift(pts, L * 0.6), CarPaint.CHROME_HI, 0.7, true)
	for sg: float in [-1.0, 1.0]:
		var cl := v(bx, 0.3 * sg)
		ci.draw_rect(Rect2(cl - Vector2(1.6, 2.4), Vector2(3.2, 4.8)), CarPaint.CHROME_DK)


func draw_rear_bumper(ci: CanvasItem, L: Vector2) -> void:
	var bx := float(s["rbump"])
	if kind in ["truck", "delivery", "van"]:
		var hw := 0.84 if kind == "van" else 0.92
		var pts := CarPaint.rpoly(rm(bx - 0.03, bx + 0.05, -hw, hw), 0.02 * M, 2)
		CarPaint.panel(ci, pts, Color("1a1a1c"), L, 1.0, 0.25, 0.6)
		return
	# two bumperettes guarding the corners
	for sg: float in [-1.0, 1.0]:
		var pts := PackedVector2Array()
		for i in 9:
			var t := float(i) / 8.0
			var y := lerpf(0.36, 0.8, t) * sg
			var curl := pow(t, 5.0) * 0.07
			pts.append(v(bx + curl, y))
		ci.draw_polyline(pts, CarPaint.CHROME_DK, 0.036 * M, true)
		ci.draw_polyline(CarPaint.shift(pts, L * 0.3), CarPaint.CHROME, 0.02 * M, true)
		ci.draw_polyline(CarPaint.shift(pts, L * 0.6), CarPaint.CHROME_HI, 0.7, true)
		ci.draw_line(v(bx + 0.02, 0.5 * sg), v(bx + 0.14, 0.5 * sg), Color("1a1a1c"), 0.03 * M, true)


## The spare on the back: a tyre standing on its carrier, sometimes in a painted cover.
func draw_rear_spare(ci: CanvasItem, L: Vector2) -> void:
	var sp: Array = s["spare"]
	if sp.is_empty():
		return
	var x := float(sp[0])
	var ht := float(sp[1])
	var r := float(sp[2])
	var tub: Array = s["tub"]
	for sg: float in [-1.0, 1.0]:
		ci.draw_line(v(x + ht, 0.18 * sg), v(float(tub[0]) + 0.05, 0.22 * sg), Color("1a1a1c"), 0.035 * M, true)
	var pts := CarPaint.rpoly(rm(x - ht, x + ht, -r, r), ht * 0.9 * M, 4)
	if spare_cover:
		var cov := roof_col if kind == "taxi" else Color("1c1b1a")
		CarPaint.panel(ci, pts, cov, L, 1.6, 0.18, 0.6)
		# the chrome band round the cover
		ci.draw_polyline(CarPaint.closed(CarPaint.inset(pts, 0.6)), CarPaint.CHROME, 0.9, true)
	else:
		CarPaint.rings(ci, [pts, CarPaint.shift(CarPaint.inset(pts, ht * 0.35 * M), L * 0.6)], [CarPaint.RUBBER.darkened(0.5), CarPaint.RUBBER_HI])
		ci.draw_polyline(CarPaint.closed(pts), CarPaint.RUBBER.darkened(0.5), 1.0, true)
		var k := -r + 0.05
		while k < r - 0.04:
			ci.draw_line(v(x - ht * 0.6, k), v(x + ht * 0.6, k), CarPaint.RUBBER.darkened(0.55), 0.8, true)
			k += 0.065
	# the hub and its lock, on the back face
	CarPaint.chrome_disc(ci, v(x - ht - 0.02, 0.0), 0.06 * M, L)


func draw_tail_lamp(ci: CanvasItem, L: Vector2) -> void:
	var t: Array = s["tail"]
	var x := float(t[0])
	var y := float(t[1])
	ci.draw_line(v(x + 0.14, y + 0.02), v(x + 0.02, y), Color("1a1a1c"), 0.03 * M, true)
	var pts := CarPaint.rpoly(rm(x - 0.05, x + 0.05, y - 0.045, y + 0.045), 0.03 * M, 3)
	CarPaint.chrome_poly(ci, pts, L, 0.9)
	CarPaint.fill(ci, CarPaint.rpoly(rm(x - 0.06, x - 0.03, y - 0.035, y + 0.035), 0.012 * M, 2), RED_LENS)


## Where the lamps are (px, local): headlamp lenses, tail lamps, and roof lamps with colours.
func lamp_spots() -> Dictionary:
	var lp: Array = s["lamp"]
	var lx := float(lp[0]) + float(lp[2]) * 0.6
	var ly := float(lp[1])
	var t: Array = s["tail"]
	var tails := [v(float(t[0]) - 0.05, float(t[1]))]
	if kind in ["truck", "delivery"]:
		tails.append(v(float(t[0]) - 0.05, -float(t[1])))
	var extra := []
	var ro: Array = s["roof"]
	if kind == "taxi":
		extra.append({"p": v(float(ro[1]) - 0.2, 0.0), "c": AMBER, "r": 0.34 * M})
	elif kind == "police":
		extra.append({"p": v(float(ro[1]) - 0.12, 0.0), "c": Color(1.0, 0.18, 0.12), "r": 0.3 * M})
	return {"head": [v(lx, -ly), v(lx, ly)], "tail": tails, "extra": extra, "lr": float(lp[2]) * M}


## The lamps lit (drawn additive, on top of the body): `level` 0..1, `head` = headlamps on.
func draw_lamps(ci: CanvasItem, level: float, head: bool) -> void:
	if level <= 0.01:
		return
	var sp := lamp_spots()
	var lr: float = sp["lr"]
	var warm := Color(1.0, 0.9, 0.66)
	for p: Vector2 in sp["head"]:
		var c := p - Vector2(lr * 0.6, 0.0)
		if head:
			CarPaint.glow(ci, p + Vector2(lr * 0.9, 0.0), Vector2(lr * 3.4, lr * 2.2), CarPaint.alpha(warm, 0.5 * level))
			ci.draw_arc(c, lr * 0.8, -1.1, 1.1, 12, CarPaint.alpha(Color(1.0, 0.96, 0.84), level), lr * 0.34, true)
			FastDraw.disc(ci, c + Vector2(lr * 0.55, 0.0), lr * 0.42, CarPaint.alpha(Color(1, 1, 0.94), 0.9 * level))
		else:
			# parking: a dim glow behind the lens
			ci.draw_arc(c, lr * 0.8, -1.0, 1.0, 10, CarPaint.alpha(warm, 0.45 * level), lr * 0.3, true)
	for p: Vector2 in sp["tail"]:
		CarPaint.glow(ci, p, Vector2(0.22, 0.2) * M, CarPaint.alpha(Color(1.0, 0.16, 0.08), 0.75 * level))
		FastDraw.disc(ci, p, 0.035 * M, CarPaint.alpha(Color(1.0, 0.45, 0.3), level))
	for e in sp["extra"]:
		var col: Color = e["c"]
		CarPaint.glow(ci, e["p"], Vector2.ONE * float(e["r"]), CarPaint.alpha(col, 0.55 * level))
		FastDraw.disc(ci, e["p"], float(e["r"]) * 0.22, CarPaint.alpha(col.lightened(0.4), 0.8 * level))
