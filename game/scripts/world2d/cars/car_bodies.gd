class_name CarBodies
extends RefCounted
## What makes each kind of vehicle (CarPainter paints the shared chassis): the closed cabin of the
## sedans, taxis and police cars; the open tub of the tourer with its seats, wheel and driver;
## the panel van's long roof; the box truck with its painted trade sign; the stake bed and its
## crates. Pixels in the car's frame (nose +x, left = -y); `L` points toward the sun.

const M := W.M
const WOOD := Color("8a6a48")
const WOOD_DK := Color("5e4630")
const WOOD_LT := Color("a88660")
const PINE := Color("b8925e")
const CANVAS := Color("7c7560")
const STEEL := Color("2a2927")


# ------------------------------------------------------------------ dispatch

static func draw_body(p: CarPainter, ci: CanvasItem, L: Vector2) -> void:
	match p.kind:
		"touring":
			draw_open(p, ci, L)
		"van":
			draw_van(p, ci, L)
		"delivery":
			draw_cab(p, ci, L)
			draw_box(p, ci, L)
		"truck":
			draw_cab(p, ci, L)
			draw_bed(p, ci, L)
		_:
			draw_closed(p, ci, L)


# ------------------------------------------------------------------ shared pieces

## The body at the belt line with its gloss and pinstripe.
static func _belt(p: CarPainter, ci: CanvasItem, L: Vector2) -> PackedVector2Array:
	var s := p.s
	var tub: Array = s["tub"]
	var cowl: Array = s["cowl"]
	var hood: Array = s["hood"]
	var pts := p.tub_pts(float(tub[0]), float(tub[1]), float(tub[2]), float(tub[3]), float(hood[2]), float(cowl[0]))
	CarPaint.panel(ci, pts, p.paint, L, 4.2, 0.2, 0.68)
	CarPaint.rim(ci, pts, L, CarPaint.alpha(CarPaint.SKY, 0.35), 0.9, 0.3, 1.2)
	if p.trim.a > 0.0:
		ci.draw_polyline(CarPaint.closed(CarPaint.inset(pts, 3.2)), CarPaint.alpha(p.trim, 0.85), 0.8, true)
	return pts


## Cowl lamps (little parking lamps on the cowl sides) and the cowl vent.
static func _cowl_bits(p: CarPainter, ci: CanvasItem, L: Vector2) -> void:
	var cowl: Array = p.s["cowl"]
	var x := lerpf(float(cowl[0]), float(cowl[1]), 0.45)
	var hw := float(cowl[2])
	ci.draw_line(p.v(x - 0.05, 0.0), p.v(x + 0.05, 0.0), CarPaint.dk(p.paint, 0.7), 1.4, true)
	if p.kind in ["sedan", "taxi", "police", "touring"]:
		for sg: float in [-1.0, 1.0]:
			CarPaint.chrome_disc(ci, p.v(x - 0.02, (hw - 0.05) * sg), 0.035 * M, L)


## A flat windscreen seen from above: a thin strip of glass in a nickel frame, the wiper.
static func _windscreen(p: CarPainter, ci: CanvasItem, L: Vector2, x0: float, x1: float, hw: float) -> void:
	var r := p.rm(x0, x1, -hw, hw)
	var pts := CarPaint.rpoly(r, 0.015 * M, 2)
	CarPaint.glass(ci, pts, L)
	CarPaint.streak(ci, p.v((x0 + x1) * 0.5, -hw + 0.1), p.v((x0 + x1) * 0.5, hw * 0.2), 1.0, CarPaint.alpha(CarPaint.GLASS_HI, 0.8))
	ci.draw_line(p.v(x1, -hw), p.v(x1, hw), CarPaint.CHROME_DK, 1.2, true)
	ci.draw_line(p.v(x1, -hw) + L * 0.5, p.v(x1, hw) + L * 0.5, CarPaint.CHROME, 0.6, true)
	# the wiper, parked on the driver's side
	ci.draw_line(p.v(x0 + 0.01, -hw * 0.75), p.v(x0 + 0.01, -hw * 0.2), Color("141414"), 1.0, true)


## A closed roof with its side glass round it, pillars, a leathercloth insert and a gloss crown.
static func _roof(p: CarPainter, ci: CanvasItem, L: Vector2, ro: Array, insert: bool, pillars: Array) -> PackedVector2Array:
	var x0 := float(ro[0])
	var x1 := float(ro[1])
	var hw := float(ro[2])
	var fr := float(ro[3]) * M
	var br := float(ro[4]) * M
	# the side glass shows as a dark band between the roof edge and the belt
	var band := CarPaint.rpoly(p.rm(x0 - 0.035, x1 + 0.02, -hw - 0.045, hw + 0.045), Vector4(fr, fr, br, br) + Vector4.ONE * 2.0, 4)
	CarPaint.glass(ci, band, L)
	for px: float in pillars:
		for sg: float in [-1.0, 1.0]:
			ci.draw_line(p.v(px, (hw - 0.02) * sg), p.v(px, (hw + 0.05) * sg), CarPaint.dk(p.roof_col, 0.35), 0.075 * M, true)
	var roof := CarPaint.rpoly(p.rm(x0, x1, -hw, hw), Vector4(fr, fr, br, br), 4)
	# the roof's own soft shadow on the belt (down-right, away from the sun)
	CarPaint.feather(ci, CarPaint.shift(roof, -L * 3.2), 4.0, Color(0, 0, 0, 0.28))
	CarPaint.panel(ci, roof, p.roof_col, L, 4.0, 0.22, 0.6)
	var bright := p.roof_col.get_luminance() > 0.3
	if insert:
		var ir := p.rm(x0 + 0.24, x1 - 0.16, -hw + 0.13, hw - 0.13)
		var ins := CarPaint.rpoly(ir, 0.08 * M, 3)
		CarPaint.flat(ci, ins, p.insert_col, L, 1.4, 0.4)
		ci.draw_polyline(CarPaint.closed(CarPaint.inset(ins, -1.2)), CarPaint.alpha(CarPaint.SKY, 0.18), 0.8, true)
		# the leathercloth's soft grain: a dull sheen, no gloss
		CarPaint.streak(ci, p.v(x0 + 0.34, 0.0) + L * 4.0, p.v(x1 - 0.24, 0.0) + L * 4.0, (hw - 0.2) * M, CarPaint.alpha(CarPaint.SKY, 0.12))
	# the crown catches the sky along the side facing the sun, a hot line along the top
	var sgn := -1.0 if L.y < 0.0 else 1.0
	var sheen := CarPaint.alpha(CarPaint.WARM if bright else CarPaint.SKY, 0.14 if bright else 0.2)
	CarPaint.streak(ci, p.v(x0 + 0.12, sgn * (hw - 0.09)), p.v(x1 - 0.06, sgn * (hw - 0.09)), 3.0, sheen)
	CarPaint.streak(ci, p.v(x0 + 0.2, sgn * (hw - 0.05)), p.v(x1 - 0.1, sgn * (hw - 0.05)), 1.2, CarPaint.alpha(Color.WHITE, 0.3))
	return roof


static func _rear_window(p: CarPainter, ci: CanvasItem, L: Vector2, x: float, hw: float) -> void:
	var pts := CarPaint.rpoly(p.rm(x - 0.07, x, -hw, hw), 0.03 * M, 3)
	CarPaint.glass(ci, pts, L)
	CarPaint.streak(ci, p.v(x - 0.035, -hw + 0.05), p.v(x - 0.035, 0.0), 0.8, CarPaint.alpha(CarPaint.GLASS_HI, 0.7))


static func _door_handles(p: CarPainter, ci: CanvasItem, xs: Array, hw: float) -> void:
	for x: float in xs:
		for sg: float in [-1.0, 1.0]:
			ci.draw_line(p.v(x, (hw - 0.012) * sg), p.v(x - 0.09, (hw - 0.012) * sg), CarPaint.CHROME, 1.3, true)


# ------------------------------------------------------------------ sedan, taxi, police

static func draw_closed(p: CarPainter, ci: CanvasItem, L: Vector2) -> void:
	var s := p.s
	var ro: Array = s["roof"]
	var tub: Array = s["tub"]
	var body := _belt(p, ci, L)
	# the rear deck: a gloss line down the middle of the curved back
	CarPaint.streak(ci, p.v(float(tub[0]) + 0.1, -0.1) + L * 2.0, p.v(float(ro[0]) - 0.1, -0.1) + L * 2.0, 5.0, CarPaint.alpha(CarPaint.SKY, 0.1))
	_cowl_bits(p, ci, L)
	_door_handles(p, ci, [float(ro[1]) - 0.2, float(ro[0]) + 0.45], float(tub[2]))
	_rear_window(p, ci, L, float(ro[0]) - 0.03, 0.26)
	var ws: Array = s["ws"]
	_windscreen(p, ci, L, float(ro[1]) - 0.02, float(ro[1]) + 0.07, float(ws[2]) - 0.05)
	var x0 := float(ro[0])
	var x1 := float(ro[1])
	var roof := _roof(p, ci, L, ro, p.kind != "police", [x1 - 0.02, lerpf(x0, x1, 0.42)])
	if p.kind == "taxi":
		_taxi_roof(p, ci, L, ro)
	elif p.kind == "police":
		_police_roof(p, ci, L, ro)
	# the rear-view mirror on the windscreen frame, driver's side
	var mr := p.v(x1 + 0.08, -float(ro[2]) - 0.02)
	ci.draw_line(mr - p.v(0.0, -0.06), mr, Color("141414"), 1.2, true)
	CarPaint.chrome_disc(ci, mr, 0.03 * M, L)
	var _unused := roof.size() + body.size()


static func _taxi_roof(p: CarPainter, ci: CanvasItem, L: Vector2, ro: Array) -> void:
	var x0 := float(ro[0]) + 0.12
	var x1 := float(ro[1]) - 0.06
	var hw := float(ro[2])
	# the checker band round the roof edge
	var sq := 0.075
	var n := int((x1 - x0) / sq)
	for sg: float in [-1.0, 1.0]:
		for i in n:
			for row in 2:
				if (i + row) % 2 == 0:
					continue
				var y0 := (hw - 0.05 - (row + 1) * sq * 0.8) * sg
				var y1 := y0 + sq * 0.8 * sg
				var r := p.rm(x0 + i * sq, x0 + (i + 1) * sq, minf(y0, y1), maxf(y0, y1))
				ci.draw_rect(r, Color("e2b634"))
		ci.draw_line(p.v(x0, (hw - 0.05) * sg), p.v(x0 + n * sq, (hw - 0.05) * sg), Color("e2b634"), 1.0, true)
		ci.draw_line(p.v(x0, (hw - 0.05 - 2 * sq * 0.8) * sg), p.v(x0 + n * sq, (hw - 0.05 - 2 * sq * 0.8) * sg), Color("e2b634"), 1.0, true)
	# TAXI painted on the roof, and the roof light up front
	var font := W.font("deco")
	CarPaint.sign_text(ci, p.v((x0 + x1) * 0.5 - 0.1, 0.0), "TAXI", 19, Color("e8c040"), font, (x1 - x0 - 0.6) * M)
	var lc := p.v(x1 - 0.1, 0.0)
	var lr := CarPaint.rpoly(Rect2(lc - Vector2(0.07, 0.2) * M, Vector2(0.14, 0.4) * M), 0.05 * M, 3)
	CarPaint.feather(ci, CarPaint.shift(lr, -L * 2.5), 3.0, Color(0, 0, 0, 0.35))
	CarPaint.panel(ci, lr, Color("e9dcb0"), L, 1.6, 0.25, 0.4)
	for sg: float in [-1.0, 1.0]:
		FastDraw.disc(ci, lc + p.v(0.0, 0.1 * sg), 0.035 * M, Color("d08a2a"))


static func _police_roof(p: CarPainter, ci: CanvasItem, L: Vector2, ro: Array) -> void:
	var x0 := float(ro[0])
	var x1 := float(ro[1])
	var hw := float(ro[2])
	# a black band round the white roof, POLICE across it
	var inner := CarPaint.rpoly(p.rm(x0 + 0.12, x1 - 0.1, -hw + 0.1, hw - 0.1), 0.1 * M, 3)
	ci.draw_polyline(CarPaint.closed(inner), Color("1b1b1d"), 2.0, true)
	CarPaint.sign_text(ci, p.v((x0 + x1) * 0.5 - 0.06, 0.0), "POLICE", 17, Color("1b1b1d"), W.font("cond"), (x1 - x0 - 0.5) * M)
	# the red lamp on a nickel base, and the brass bell on the cowl
	var lc := p.v(x1 - 0.12, 0.0)
	FastDraw.disc(ci, lc - L * 2.4, 0.11 * M, Color(0, 0, 0, 0.35))
	CarPaint.chrome_disc(ci, lc, 0.1 * M, L)
	FastDraw.disc(ci, lc, 0.075 * M, Color("8a1810"))
	FastDraw.disc(ci, lc + L * 1.4, 0.04 * M, Color("d8502e"))
	FastDraw.disc(ci, lc + L * 2.0, 0.015 * M, Color(1, 0.9, 0.8, 0.9))
	var cowl: Array = p.s["cowl"]
	var bc := p.v(float(cowl[0]) + 0.06, float(cowl[2]) - 0.14)
	FastDraw.disc(ci, bc - L * 1.8, 0.085 * M, Color(0, 0, 0, 0.35))
	FastDraw.disc(ci, bc, 0.08 * M, Color("6a4a18"))
	FastDraw.disc(ci, bc + L * 0.8, 0.062 * M, Pal.BRASS)
	FastDraw.disc(ci, bc + L * 1.8, 0.025 * M, Color("f4e2a0"))


# ------------------------------------------------------------------ the tourer

static func draw_open(p: CarPainter, ci: CanvasItem, L: Vector2) -> void:
	var s := p.s
	var tub: Array = s["tub"]
	var x0 := float(tub[0])
	var hw := float(tub[2])
	# side-mounted spares in the front fender wells
	var rb: Array = s["rb"]
	for sg: float in [-1.0, 1.0]:
		var sx := float(rb[1]) - 0.02
		var c := p.v(sx, 0.75 * sg)
		CarPaint.tyre(ci, c, 0.68 * M, 0.14 * M, 0.0, L)
		CarPaint.chrome_disc(ci, c + p.v(0.0, -0.075 * sg), 0.06 * M, L)
		ci.draw_line(c + p.v(0.0, -0.05 * sg), c + p.v(0.0, -0.1 * sg), Color("141414"), 2.0, true)
	var body := _belt(p, ci, L)
	# the cockpit: the body's sides are a hand wide, the floor and seats inside
	var cx0 := x0 + 0.2
	var cx1 := 0.2
	var cock := CarPaint.rpoly(p.rm(cx0, cx1, -hw + 0.085, hw - 0.085), Vector4(0.06, 0.06, 0.2, 0.2) * M, 4)
	CarPaint.fill(ci, cock, Color("141212"))
	# the sides throw a shadow into the cockpit, away from the sun
	CarPaint.feather(ci, CarPaint.shift(CarPaint.inset(cock, 1.0), -L * 4.0), 5.0, Color("201c1a"))
	var floor_col := Color("2a2622")
	CarPaint.fill(ci, CarPaint.shift(CarPaint.inset(cock, 5.0), -L * 2.5), floor_col)
	# the rear bench and the front seat, tufted leather
	_bench(p, ci, L, x0 + 0.28, x0 + 0.78, hw - 0.1, true)
	_bench(p, ci, L, -0.38, -0.02, hw - 0.1, false)
	if p.dual_cowl:
		# a second cowl and windscreen for the rear passengers
		var dx := x0 + 0.92
		var dc := CarPaint.rpoly(p.rm(dx - 0.06, dx + 0.12, -hw + 0.05, hw - 0.05), 0.05 * M, 3)
		CarPaint.panel(ci, dc, p.paint, L, 2.4, 0.2, 0.6)
		_windscreen(p, ci, L, dx + 0.12, dx + 0.16, hw - 0.14)
	# the folded top in its boot at the back
	_folded_top(p, ci, L, x0 + 0.04, x0 + 0.26, hw - 0.04)
	# the dashboard, the wheel, the driver
	var dash := CarPaint.rpoly(p.rm(0.12, 0.26, -hw + 0.08, hw - 0.08), 0.03 * M, 2)
	CarPaint.flat(ci, dash, Color("2a1d16"), L, 1.0, 0.4)
	for k in 3:
		FastDraw.disc(ci, p.v(0.19, -0.12 + k * 0.12), 0.022 * M, Color("c8c0a0"))
	var drv_y := -0.3
	var col := p.v(0.18, drv_y)
	var wheel_c := p.v(0.06, drv_y)
	ci.draw_line(col, wheel_c, Color("141414"), 2.0, true)
	var passenger_front := p.passenger == 1
	_person(p, ci, L, p.v(-0.24, drv_y), p.hat_col, p.hat_band, p.coat_col, "fedora", true)
	_wheel(p, ci, L, wheel_c)
	if passenger_front:
		_person(p, ci, L, p.v(-0.22, 0.3), p.pass_col, Color("1c1a18"), p.pass_col.darkened(0.3), p.pass_hat, false)
	elif p.passenger == 2:
		_person(p, ci, L, p.v(x0 + 0.6, 0.28), p.pass_col, Color("1c1a18"), p.pass_col.darkened(0.3), p.pass_hat, false)
	_windscreen(p, ci, L, 0.27, 0.32, float(s["ws"][2]) - 0.02)
	_cowl_bits(p, ci, L)
	# a trunk on the rack at the back
	var tr := CarPaint.rpoly(p.rm(x0 - 0.2, x0 + 0.01, -0.5, 0.5), 0.03 * M, 2)
	CarPaint.feather(ci, CarPaint.shift(tr, -L * 2.0), 3.0, Color(0, 0, 0, 0.3))
	CarPaint.flat(ci, tr, Color("1f1c1a"), L, 1.6, 0.5)
	for sg: float in [-1.0, 1.0]:
		ci.draw_line(p.v(x0 - 0.2, 0.3 * sg), p.v(x0 + 0.01, 0.3 * sg), Color("5a3a22"), 2.2, true)
		FastDraw.disc(ci, p.v(x0 - 0.18, 0.3 * sg), 1.3, CarPaint.CHROME)
	CarPaint.streak(ci, p.v(x0 - 0.1, -0.44) + L, p.v(x0 - 0.1, 0.44) + L, 1.2, CarPaint.alpha(CarPaint.SKY, 0.18))
	var _unused := body.size()


static func _bench(p: CarPainter, ci: CanvasItem, L: Vector2, x0: float, x1: float, hw: float, rear: bool) -> void:
	var seat := p.seat_col
	# the back rest along the back edge, the cushion in front of it
	var back := CarPaint.rpoly(p.rm(x0, x0 + 0.12, -hw, hw), Vector4(0.04, 0.04, 0.06, 0.06) * M, 3)
	var cush := CarPaint.rpoly(p.rm(x0 + 0.1, x1, -hw + 0.03, hw - 0.03), 0.07 * M, 3)
	CarPaint.panel(ci, cush, seat, L, 3.0, 0.12, 0.55)
	CarPaint.panel(ci, back, seat.darkened(0.1), L, 2.4, 0.12, 0.6)
	# pleats
	var n := 6 if rear else 5
	for i in range(1, n):
		var y := lerpf(-hw + 0.05, hw - 0.05, float(i) / n)
		ci.draw_line(p.v(x0 + 0.13, y), p.v(x1 - 0.04, y), CarPaint.dk(seat, 0.45), 1.0, true)
		ci.draw_line(p.v(x0 + 0.13, y) + L * 0.8, p.v(x1 - 0.04, y) + L * 0.8, CarPaint.lit(seat, 0.18), 0.6, true)


static func _folded_top(p: CarPainter, ci: CanvasItem, L: Vector2, x0: float, x1: float, hw: float) -> void:
	var pts := CarPaint.rpoly(p.rm(x0, x1, -hw, hw), 0.08 * M, 3)
	CarPaint.feather(ci, CarPaint.shift(pts, -L * 2.4), 3.0, Color(0, 0, 0, 0.35))
	CarPaint.panel(ci, pts, Color("2a2724"), L, 2.6, 0.1, 0.55)
	for k in 3:
		var x := lerpf(x0 + 0.04, x1 - 0.04, float(k) / 2.0)
		ci.draw_line(p.v(x, -hw + 0.06), p.v(x, hw - 0.06), Color("171514"), 1.0, true)
		ci.draw_line(p.v(x, -hw + 0.06) + L * 0.8, p.v(x, hw - 0.06) + L * 0.8, Color("45413b"), 0.6, true)
	# the bows' ends in nickel at each side
	for sg: float in [-1.0, 1.0]:
		CarPaint.chrome_disc(ci, p.v((x0 + x1) * 0.5, (hw - 0.02) * sg), 0.03 * M, L)


static func _wheel(p: CarPainter, ci: CanvasItem, L: Vector2, c: Vector2) -> void:
	# seen from above, tilted toward the driver: an oval rim, four spokes, the hub
	var rx := 0.06 * M
	var ry := 0.19 * M
	var rim := CarPaint.ellipse(c, Vector2(rx, ry), 20)
	ci.draw_polyline(CarPaint.closed(rim), Color("0f0d0c"), 2.4, true)
	ci.draw_polyline(CarPaint.closed(CarPaint.shift(rim, L * 0.6)), Color("5a3a24"), 1.0, true)
	for k in 4:
		var a := PI * 0.25 + k * PI * 0.5
		ci.draw_line(c, c + Vector2(cos(a) * rx, sin(a) * ry), Color("1a1918"), 1.0, true)
	FastDraw.disc(ci, c, 2.0, Color("1a1918"))
	FastDraw.disc(ci, c + L * 0.4, 0.9, CarPaint.CHROME)


## Someone sitting in an open car, from above: shoulders, arms forward, the hat.
static func _person(p: CarPainter, ci: CanvasItem, L: Vector2, c: Vector2, hat: Color, band: Color, coat: Color,
		style: String, driving: bool) -> void:
	var sh := 0.23 * M
	FastDraw.soft(ci, Transform2D.IDENTITY, c - L * 3.0, Vector2(0.18, 0.28) * M, 0.0, Color(0, 0, 0, 0.45))
	# shoulders and upper arms
	FastDraw.oval(ci, c, Vector2(0.13 * M, sh), CarPaint.dk(coat, 0.35))
	FastDraw.oval(ci, c + L * 0.8, Vector2(0.115 * M, sh - 1.5), coat)
	FastDraw.oval(ci, c + L * 2.0 + Vector2(-1.0, 0.0), Vector2(0.07 * M, sh * 0.6), CarPaint.lit(coat, 0.12))
	if driving:
		for sg: float in [-1.0, 1.0]:
			var a := c + Vector2(0.02 * M, sh * 0.72 * sg)
			var b := c + Vector2(0.25 * M, 0.13 * M * sg)
			FastDraw.capsule(ci, a, b, 0.045 * M, CarPaint.dk(coat, 0.2))
			FastDraw.disc(ci, b + Vector2(0.03 * M, 0.0), 0.035 * M, p.skin)
	else:
		for sg: float in [-1.0, 1.0]:
			FastDraw.capsule(ci, c + Vector2(0.0, sh * 0.72 * sg), c + Vector2(0.16 * M, sh * 0.62 * sg), 0.042 * M, CarPaint.dk(coat, 0.2))
	# the hat (the head is under it)
	var hc := c + Vector2(0.03 * M, 0.0)
	FastDraw.disc(ci, hc + Vector2(0.03 * M, 0.0), 0.075 * M, p.skin.darkened(0.2))
	match style:
		"cloche":
			FastDraw.disc(ci, hc, 0.12 * M, CarPaint.dk(hat, 0.45))
			FastDraw.disc(ci, hc + L * 0.8, 0.105 * M, hat)
			FastDraw.disc(ci, hc + L * 2.0, 0.05 * M, CarPaint.lit(hat, 0.2))
		_:
			var brim := 0.17 * M if style == "fedora" else 0.155 * M
			FastDraw.oval(ci, hc, Vector2(brim * 0.95, brim), CarPaint.dk(hat, 0.5))
			FastDraw.oval(ci, hc + L * 0.5, Vector2(brim * 0.88, brim * 0.93), hat)
			FastDraw.oval(ci, hc + L * 0.8, Vector2(0.095 * M, 0.085 * M), band)
			FastDraw.oval(ci, hc + L * 1.4, Vector2(0.082 * M, 0.072 * M), CarPaint.lit(hat, 0.08))
			if style == "fedora":
				ci.draw_line(hc + Vector2(-0.06 * M, 0.0), hc + Vector2(0.05 * M, 0.0), CarPaint.dk(hat, 0.45), 1.2, true)
			FastDraw.disc(ci, hc + L * 2.6, 0.035 * M, CarPaint.alpha(CarPaint.lit(hat, 0.35), 0.8))


# ------------------------------------------------------------------ the panel van

static func draw_van(p: CarPainter, ci: CanvasItem, L: Vector2) -> void:
	var s := p.s
	var ro: Array = s["roof"]
	var tub: Array = s["tub"]
	var body := _belt(p, ci, L)
	_cowl_bits(p, ci, L)
	var ws: Array = s["ws"]
	_windscreen(p, ci, L, float(ro[1]) - 0.02, float(ro[1]) + 0.07, float(ws[2]) - 0.1)
	var x0 := float(ro[0])
	var x1 := float(ro[1])
	var hw := float(ro[2])
	# only the cab has side glass; the panel sides are steel right up to the roof
	var cab := CarPaint.rpoly(p.rm(x1 - 0.72, x1 + 0.02, -hw - 0.04, hw + 0.04), Vector4(0.1, 0.1, 0.0, 0.0) * M, 3)
	CarPaint.glass(ci, cab, L)
	for sg: float in [-1.0, 1.0]:
		ci.draw_line(p.v(x1 - 0.72, (hw - 0.02) * sg), p.v(x1 - 0.72, (hw + 0.05) * sg), CarPaint.dk(p.paint, 0.4), 0.07 * M, true)
	var roof := CarPaint.rpoly(p.rm(x0, x1, -hw, hw), Vector4(float(ro[3]), float(ro[3]), float(ro[4]), float(ro[4])) * M, 4)
	CarPaint.feather(ci, CarPaint.shift(roof, -L * 3.2), 4.0, Color(0, 0, 0, 0.3))
	CarPaint.panel(ci, roof, p.roof_col, L, 4.4, 0.18, 0.62)
	# the roof is pressed in long panels with a rain gutter round it
	ci.draw_polyline(CarPaint.closed(CarPaint.inset(roof, 3.0)), CarPaint.dk(p.roof_col, 0.5), 0.9, true)
	var nrib := 5
	for i in range(1, nrib):
		var x := lerpf(x0 + 0.1, x1 - 0.1, float(i) / nrib)
		ci.draw_line(p.v(x, -hw + 0.08), p.v(x, hw - 0.08), CarPaint.dk(p.roof_col, 0.45), 1.0, true)
		ci.draw_line(p.v(x, -hw + 0.08) + L * 0.9, p.v(x, hw - 0.08) + L * 0.9, CarPaint.gloss(p.roof_col, 0.22), 0.6, true)
	var sgn := -1.0 if L.y < 0.0 else 1.0
	CarPaint.streak(ci, p.v(x0 + 0.15, sgn * (hw - 0.1)), p.v(x1 - 0.1, sgn * (hw - 0.1)), 3.2, CarPaint.alpha(CarPaint.SKY, 0.2))
	CarPaint.streak(ci, p.v(x0 + 0.25, sgn * (hw - 0.05)), p.v(x1 - 0.15, sgn * (hw - 0.05)), 1.2, CarPaint.alpha(Color.WHITE, 0.28))
	# a ventilator in the roof over the cab
	var vc := p.v(x1 - 0.35, 0.0)
	var vent := CarPaint.rpoly(Rect2(vc - Vector2(0.1, 0.16) * M, Vector2(0.2, 0.32) * M), 0.03 * M, 2)
	CarPaint.feather(ci, CarPaint.shift(vent, -L * 1.6), 2.0, Color(0, 0, 0, 0.35))
	CarPaint.panel(ci, vent, p.roof_col, L, 1.6, 0.2, 0.6)
	# the rear doors' handle and hinges
	var bx := float(tub[0])
	ci.draw_line(p.v(bx + 0.02, -0.12), p.v(bx + 0.02, 0.12), CarPaint.CHROME, 1.6, true)
	for sg: float in [-1.0, 1.0]:
		ci.draw_rect(Rect2(p.v(bx + 0.005, 0.62 * sg) - Vector2(1.0, 2.5), Vector2(3.0, 5.0)), Color("111112"))
	if p.rack == 1:
		_ladder(p, ci, L, x0 + 0.2, x1 - 0.5, 0.42)
	var _unused := body.size()


static func _ladder(p: CarPainter, ci: CanvasItem, L: Vector2, x0: float, x1: float, hw: float) -> void:
	var sh := -L * 3.5
	for sg: float in [-1.0, 1.0]:
		ci.draw_line(p.v(x0, hw * sg) + sh, p.v(x1, hw * sg) + sh, Color(0, 0, 0, 0.3), 3.0, true)
	var hw2 := hw - 0.12
	var x := x0 + 0.12
	while x < x1 - 0.05:
		ci.draw_line(p.v(x, -hw2) + sh, p.v(x, hw2) + sh, Color(0, 0, 0, 0.25), 2.0, true)
		ci.draw_line(p.v(x, -hw2), p.v(x, hw2), WOOD_DK, 2.2, true)
		ci.draw_line(p.v(x, -hw2) + L * 0.5, p.v(x, hw2) + L * 0.5, WOOD_LT, 0.8, true)
		x += 0.3
	for sg: float in [-1.0, 1.0]:
		var y := hw2 * sg
		ci.draw_line(p.v(x0, y), p.v(x1, y), WOOD_DK, 3.4, true)
		ci.draw_line(p.v(x0, y) + L * 0.7, p.v(x1, y) + L * 0.7, WOOD_LT, 1.4, true)
	# the rack's feet
	for rx: float in [x0 + 0.05, x1 - 0.05]:
		for sg: float in [-1.0, 1.0]:
			ci.draw_rect(Rect2(p.v(rx, hw * sg) - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), Color("141414"))


# ------------------------------------------------------------------ trucks: the cab

static func draw_cab(p: CarPainter, ci: CanvasItem, L: Vector2) -> void:
	var s := p.s
	var ro: Array = s["roof"]
	var body := _belt(p, ci, L)
	_cowl_bits(p, ci, L)
	var ws: Array = s["ws"]
	_windscreen(p, ci, L, float(ro[1]) - 0.02, float(ro[1]) + 0.07, float(ws[2]) - 0.08)
	var x1 := float(ro[1])
	var roof := _roof(p, ci, L, ro, true, [x1 - 0.02])
	# the cab's rear window
	_rear_window(p, ci, L, float(ro[0]) + 0.06, 0.3)
	var _unused := roof.size() + body.size()


# ------------------------------------------------------------------ the box truck

static func draw_box(p: CarPainter, ci: CanvasItem, L: Vector2) -> void:
	var bx: Array = p.s["box"]
	var x0 := float(bx[0])
	var x1 := float(bx[1])
	var hw := float(bx[2])
	var t: Dictionary = p.trade
	var col: Color = t.get("box", Color("ddcfae"))
	var ink: Color = t.get("ink", Color("3a2a1a"))
	var trim: Color = t.get("trim", Color("a8742e"))
	var pts := CarPaint.rpoly(p.rm(x0, x1, -hw, hw), 0.06 * M, 3)
	# the box stands tall over the cab: its shadow falls on the cab roof
	CarPaint.feather(ci, CarPaint.shift(pts, -L * 5.0), 6.0, Color(0, 0, 0, 0.32))
	CarPaint.panel(ci, pts, col, L, 3.0, 0.14, 0.5)
	# the roof's edge moulding and the painted border
	ci.draw_polyline(CarPaint.closed(CarPaint.inset(pts, 2.0)), CarPaint.dk(col, 0.3), 1.0, true)
	var br := CarPaint.rpoly(p.rm(x0 + 0.12, x1 - 0.12, -hw + 0.12, hw - 0.12), 0.08 * M, 3)
	ci.draw_polyline(CarPaint.closed(br), CarPaint.alpha(trim, 0.95), 2.2, true)
	ci.draw_polyline(CarPaint.closed(CarPaint.inset(br, 3.2)), CarPaint.alpha(trim, 0.7), 0.8, true)
	# corner flourishes
	for cx: float in [x0 + 0.12, x1 - 0.12]:
		for sg: float in [-1.0, 1.0]:
			FastDraw.disc(ci, p.v(cx, (hw - 0.12) * sg), 2.4, trim)
	# the trade, big enough to read from a rooftop, and a line under it
	var word: String = t.get("word", "BAKERY")
	var sub: String = t.get("sub", "")
	var cx := (x0 + x1) * 0.5
	var wide := (x1 - x0 - 0.42) * M
	CarPaint.sign_text(ci, p.v(cx, -0.14) + Vector2(1.2, 1.2), word, 30, CarPaint.alpha(CarPaint.INK, 0.25), W.font("deco"), wide)
	CarPaint.sign_text(ci, p.v(cx, -0.14), word, 30, ink, W.font("deco"), wide)
	ci.draw_line(p.v(x0 + 0.5, 0.2), p.v(x1 - 0.5, 0.2), CarPaint.alpha(trim, 0.9), 1.2, true)
	if sub != "":
		CarPaint.sign_text(ci, p.v(cx, 0.4), sub, 10, CarPaint.alpha(ink, 0.9), W.font("cond"), wide)
	# rivets along the front and back edges, a light gloss
	for sg: float in [-1.0, 1.0]:
		var y := (hw - 0.05) * sg
		var x := x0 + 0.1
		while x < x1 - 0.05:
			FastDraw.disc(ci, p.v(x, y), 0.9, CarPaint.dk(col, 0.35))
			x += 0.3
	var sgn := -1.0 if L.y < 0.0 else 1.0
	CarPaint.streak(ci, p.v(x0 + 0.2, sgn * (hw - 0.06)), p.v(x1 - 0.2, sgn * (hw - 0.06)), 2.2, CarPaint.alpha(Color.WHITE, 0.22))
	# the rear doors' hinges and the step
	for sg: float in [-1.0, 1.0]:
		ci.draw_rect(Rect2(p.v(x0, 0.7 * sg) - Vector2(2.0, 3.0), Vector2(3.0, 6.0)), Color("141414"))


# ------------------------------------------------------------------ the stake bed

static func draw_bed(p: CarPainter, ci: CanvasItem, L: Vector2) -> void:
	var b: Array = p.s["bed"]
	var x0 := float(b[0])
	var x1 := float(b[1])
	var hw := float(b[2])
	var r := p.rm(x0, x1, -hw, hw)
	var outer := CarPaint.rpoly(r, 0.03 * M, 2)
	CarPaint.flat(ci, outer, WOOD_DK, L, 1.0, 0.5)
	# the floor: boards running lengthways, each a little different
	var bw := 0.13
	var y := -hw + 0.07
	var k := 0
	while y < hw - 0.07 - 0.01:
		var y2 := minf(y + bw, hw - 0.07)
		var tone := WOOD.lerp(WOOD_LT, Draw.hash01(k, p.sd & 0xff, 17) * 0.5).darkened(Draw.hash01(k, 3, 29) * 0.12)
		var br := p.rm(x0 + 0.07, x1 - 0.07, y + 0.004, y2 - 0.004)
		ci.draw_rect(br, tone)
		# grain and the odd butt joint
		ci.draw_line(Vector2(br.position.x, br.get_center().y + 0.8), Vector2(br.end.x, br.get_center().y + 0.8), CarPaint.alpha(WOOD_DK, 0.35), 0.6)
		var j := lerpf(x0 + 0.4, x1 - 0.4, Draw.hash01(k, 7, 41))
		ci.draw_line(p.v(j, y + 0.004), p.v(j, y2 - 0.004), CarPaint.alpha(WOOD_DK, 0.8), 0.8)
		y = y2
		k += 1
	# steel strips over the seams at the cross-members, bolt heads
	for cx: float in [x0 + 0.3, (x0 + x1) * 0.5, x1 - 0.3]:
		ci.draw_line(p.v(cx, -hw + 0.07), p.v(cx, hw - 0.07), Color(0.14, 0.13, 0.12, 0.55), 2.0)
		var yy := -hw + 0.13
		while yy < hw - 0.08:
			FastDraw.disc(ci, p.v(cx, yy), 0.9, Color("3a3632"))
			yy += 0.26
	# the stake sides: a rail along the top of each side, stakes at the pockets
	var sh := -L * 4.0
	var rail_w := 0.075
	var sides := [p.rm(x0, x1, -hw, -hw + rail_w), p.rm(x0, x1, hw - rail_w, hw),
		p.rm(x0, x0 + rail_w, -hw, hw), p.rm(x1 - rail_w * 1.6, x1, -hw, hw)]
	for i in sides.size():
		var sr: Rect2 = sides[i]
		# each side throws its shadow onto the floor
		var sp := CarPaint.rpoly(Rect2(sr.position + sh, sr.size), 1.0, 1)
		var clip := Geometry2D.intersect_polygons(sp, CarPaint.inset(outer, 3.0))
		for c in clip:
			CarPaint.fill(ci, c, Color(0.05, 0.03, 0.02, 0.35), false)
	for i in sides.size():
		var sr: Rect2 = sides[i]
		var sp := CarPaint.rpoly(sr, 1.2, 1)
		CarPaint.flat(ci, sp, WOOD_LT if i < 2 else WOOD, L, 1.0, 0.5)
		# grain
		if i < 2:
			ci.draw_line(Vector2(sr.position.x + 2, sr.get_center().y), Vector2(sr.end.x - 2, sr.get_center().y), CarPaint.alpha(WOOD_DK, 0.4), 0.6)
	var sx := x0 + 0.05
	while sx < x1:
		for sg: float in [-1.0, 1.0]:
			var c := p.v(sx, (hw - rail_w * 0.5) * sg)
			ci.draw_rect(Rect2(c - Vector2(3.2, 3.2), Vector2(6.4, 6.4)), STEEL)
			ci.draw_rect(Rect2(c - Vector2(2.2, 2.2) + L * 0.6, Vector2(3.6, 3.6)), WOOD.darkened(0.1))
		sx += 0.5
	# the headboard behind the cab is taller: a heavier shadow
	var hb := p.rm(x1 - rail_w * 1.6, x1, -hw, hw)
	CarPaint.streak(ci, Vector2(hb.position.x, hb.position.y + 6), Vector2(hb.position.x, hb.end.y - 6), 1.0, CarPaint.alpha(WOOD_LT.lightened(0.3), 0.6))
	# the tarp, folded and roped at the tailboard
	var tp := CarPaint.rpoly(p.rm(x0 + 0.1, x0 + 0.36, -hw + 0.12, hw - 0.12), 0.07 * M, 3)
	CarPaint.feather(ci, CarPaint.shift(tp, -L * 2.2), 3.0, Color(0, 0, 0, 0.35))
	CarPaint.panel(ci, tp, CANVAS, L, 2.6, 0.08, 0.5)
	for k2 in 2:
		var fx := lerpf(x0 + 0.17, x0 + 0.29, float(k2))
		ci.draw_line(p.v(fx, -hw + 0.16), p.v(fx, hw - 0.16), CarPaint.dk(CANVAS, 0.4), 0.9, true)
	for fy: float in [-0.45, 0.45]:
		ci.draw_line(p.v(x0 + 0.09, fy), p.v(x0 + 0.37, fy), Color("b59a6a"), 1.4, true)


## The crates in the bed: rows of two from the headboard back, a second layer when full.
static func draw_load(p: CarPainter, ci: CanvasItem, L: Vector2, n: int) -> void:
	if n <= 0 or not p.s.has("bed"):
		return
	var b: Array = p.s["bed"]
	var fx := float(b[1]) - 0.14
	var cw := 0.6
	var ch := 0.72
	var slots := []
	for i in mini(n, 6):
		var row := i / 2
		var sg := -1.0 if i % 2 == 0 else 1.0
		slots.append([fx - cw * 0.5 - row * 0.64, 0.385 * sg, 0])
	for i in range(6, mini(n, 10)):
		var j := i - 6
		var row := j / 2
		var sg := -1.0 if j % 2 == 0 else 1.0
		slots.append([fx - cw * 0.5 - 0.3 - row * 0.64, 0.37 * sg, 1])
	for i in slots.size():
		var sl: Array = slots[i]
		var up := int(sl[2]) == 1
		var jit := Draw.hash01(i, p.sd & 0xffff, 5) - 0.5
		var c := p.v(float(sl[0]) + jit * 0.03, float(sl[1]))
		var rot := jit * (0.1 if up else 0.05)
		# a crate on top throws a shadow onto the ones below; the bottom ones onto the floor
		var sh_off := -L * (6.0 if up else 3.0)
		var sp := CarPaint.rpoly(Rect2(-cw * 0.5 * M, -ch * 0.5 * M, cw * M, ch * M), 2.0, 1)
		var tr := Transform2D(rot, c + sh_off)
		var shp := PackedVector2Array()
		for q in sp:
			shp.append(tr * q)
		CarPaint.feather(ci, shp, 4.0, Color(0.03, 0.02, 0.01, 0.45))
		_crate(p, ci, L, c, rot, cw * M, ch * M, i, up)
	if n > 6:
		# a rope lashing the top layer down to the stakes
		var rx := fx - 0.62
		for k in 2:
			var x := rx - k * 0.64
			if 6 + k * 2 >= n:
				break
			ci.draw_line(p.v(x, -1.0) - L * 1.5, p.v(x, 1.0) - L * 1.5, Color(0, 0, 0, 0.3), 2.0, true)
			ci.draw_line(p.v(x, -1.0), p.v(x, 1.0), Color("a88a5a"), 1.6, true)
			ci.draw_line(p.v(x, -1.0) + L * 0.4, p.v(x, 1.0) + L * 0.4, Color("d8c090"), 0.6, true)


static func _crate(p: CarPainter, ci: CanvasItem, L: Vector2, c: Vector2, rot: float, w: float, h: float, i: int, up: bool) -> void:
	var t := Transform2D(rot, c)
	var base := PINE.lerp(WOOD_LT, Draw.hash01(i, p.sd & 0xff, 9) * 0.6).darkened(Draw.hash01(i, 11, 3) * 0.1)
	if up:
		base = base.lightened(0.06)
	var outer := _tp(t, CarPaint.rpoly(Rect2(-w * 0.5, -h * 0.5, w, h), 1.6, 1))
	CarPaint.flat(ci, outer, base, L, 1.6, 0.55)
	# the lid: three boards across, two battens
	var nb := 3
	for k in range(1, nb):
		var y := -h * 0.5 + h * float(k) / nb
		ci.draw_line(t * Vector2(-w * 0.5 + 2, y), t * Vector2(w * 0.5 - 2, y), CarPaint.dk(base, 0.55), 1.0, true)
	for bx: float in [-w * 0.5 + 4.5, w * 0.5 - 4.5]:
		var bt := _tp(t, PackedVector2Array([Vector2(bx - 2.2, -h * 0.5 + 1.5), Vector2(bx + 2.2, -h * 0.5 + 1.5), Vector2(bx + 2.2, h * 0.5 - 1.5), Vector2(bx - 2.2, h * 0.5 - 1.5)]))
		CarPaint.flat(ci, bt, base.darkened(0.08), L, 0.8, 0.5)
		for ny: float in [-h * 0.5 + 4, 0.0, h * 0.5 - 4]:
			FastDraw.disc(ci, t * Vector2(bx, ny), 0.7, Color("3a3028"))
	# the stencil: what the manifest says is inside
	var words := ["OLIVE OIL", "TOMATOES", "MACARONI", "CHEESE", "SARDINES", "VINEGAR"]
	var word: String = words[absi(i + p.sd) % words.size()]
	ci.draw_set_transform_matrix(Transform2D(rot + PI * 0.5, c))
	CarPaint.sign_text(ci, Vector2.ZERO, word, 7, CarPaint.alpha(Color("2a1a10"), 0.55), W.font("cond"), h - 12.0)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	# the lit edge
	CarPaint.rim(ci, outer, L, CarPaint.alpha(CarPaint.lit(base, 0.5), 0.8), 1.0, 0.3, 1.0)


static func _tp(t: Transform2D, pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(pts.size())
	for k in pts.size():
		out[k] = t * pts[k]
	return out
