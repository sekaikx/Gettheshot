extends RefCounted
## The things each trade puts out on the sidewalk, seen from straight above: fruit stands, bread
## racks, fish on ice, café tables, a barber pole, a tailor's dummy... Drawn by FrontArt in a
## shop's local frame (px): +x along the street, +y out toward the curb. `S` is the shop layout
## (FrontArt.plan_shop): S["lsh"] turns a height in metres into this frame's shadow offset.
## Every painter fits itself into the Rect2 it gets. Nothing here keeps state.

const FX := preload("res://scripts/world2d/fronts/fx.gd")

const IRON := Color("25221f")
const IRON_HI := Color("56504a")
const WOOD := Color("7a5a3e")
const WOOD_LT := Color("a07a52")
const WOOD_DK := Color("4e3a2a")
const CRATE := Color("b08a5a")
const CRATE_DK := Color("7e6040")
const ZINC := Color("9aa0a2")
const STRAW := Color("c9a55e")
const LOAF := Color("c0823a")
const WHITE := Color("f2ede0")

const FRUIT := [
	[Color("b8322a"), 0.052],   # apples
	[Color("e0892a"), 0.05],    # oranges
	[Color("e6c73a"), 0.045],   # lemons
	[Color("6f9a3e"), 0.085],   # cabbages
	[Color("9a7448"), 0.048],   # potatoes
	[Color("c9442e"), 0.045],   # tomatoes
	[Color("5a3a5e"), 0.03],    # grapes
	[Color("8fb04a"), 0.05],    # pears
	[Color("d9b04a"), 0.06],    # onions
]


static func M(v: float) -> float:
	return v * W.M


static func sh(S: Dictionary, h: float) -> Vector2:
	var w := FX.sh(h)
	return Vector2(w.dot(S["ax"]), w.dot(S["f"]))


## Unit vector toward the light (north-west) in the local frame.
static func lit(S: Dictionary) -> Vector2:
	return -sh(S, 1.0).normalized()


static func shadow_rect(ci: CanvasItem, S: Dictionary, r: Rect2, h: float, a: float = 0.28) -> void:
	FX.soft_poly(ci, FX.hull_shift(FX.rect_pts(r), sh(S, h)), a, 2.0)


static func shadow_circle(ci: CanvasItem, S: Dictionary, c: Vector2, rad: float, h: float, a: float = 0.28) -> void:
	var o := sh(S, h)
	var pts := PackedVector2Array()
	for k in 16:
		var d := Vector2.from_angle(TAU * k / 16.0) * rad
		pts.append(c + d)
		pts.append(c + d + o)
	FX.soft_poly(ci, Geometry2D.convex_hull(pts), a, 2.0)


## A tall thin thing (a pole, a leg): its shadow is a long soft stroke on the ground.
static func shadow_pole(ci: CanvasItem, S: Dictionary, base: Vector2, h: float, width: float, a: float = 0.26) -> void:
	var o := sh(S, h)
	ci.draw_line(base, base + o, Color(FX.SHADE, a * 0.5), width + 2.0, true)
	ci.draw_line(base, base + o, Color(FX.SHADE, a), width, true)


## A ball with a highlight toward the light.
static func ball(ci: CanvasItem, S: Dictionary, c: Vector2, r: float, col: Color, shine: float = 0.35) -> void:
	var L := lit(S)
	Draw.circle(ci, c, r, col.darkened(0.25))
	Draw.circle(ci, c + L * r * 0.18, r * 0.82, col)
	if r > 1.6:
		Draw.circle(ci, c + L * r * 0.42, r * 0.34, col.lightened(shine))


static func crate(ci: CanvasItem, S: Dictionary, r: Rect2, col: Color = CRATE) -> void:
	Draw.rect(ci, r, col.darkened(0.3))
	Draw.rect(ci, r.grow(-1.2), col)
	var n := maxi(2, int(r.size.x / M(0.14)))
	for k in range(1, n):
		var x := r.position.x + r.size.x * k / n
		ci.draw_line(Vector2(x, r.position.y + 1.5), Vector2(x, r.end.y - 1.5), col.darkened(0.18), 1.0)
	var L := lit(S)
	var edge_a := r.position if L.y < 0.0 else Vector2(r.position.x, r.end.y)
	ci.draw_line(edge_a, edge_a + Vector2(r.size.x, 0), col.lightened(0.22), 1.2)


## A crate of fruit: a wooden rim, rows of round things.
static func fruit_crate(ci: CanvasItem, S: Dictionary, r: Rect2, fruit: Array, seed_v: int) -> void:
	var col: Color = fruit[0]
	var rad := M(float(fruit[1]))
	Draw.rect(ci, r, CRATE_DK)
	Draw.rect(ci, r.grow(-1.5), Color("3a2c20"))
	var inner := r.grow(-2.5)
	var step := rad * 1.8
	var rows := maxi(1, int(inner.size.y / step))
	var cols := maxi(1, int(inner.size.x / step))
	var dx := inner.size.x / cols
	var dy := inner.size.y / rows
	for j in rows:
		for i in cols + (1 if j % 2 == 1 else 0):
			var x := inner.position.x + dx * (i + (0.0 if j % 2 == 1 else 0.5))
			if x < inner.position.x + rad * 0.6 or x > inner.end.x - rad * 0.6:
				continue
			var y := inner.position.y + dy * (j + 0.5)
			var h := Draw.hash01(int(x), int(y), seed_v)
			var c := col.lightened(h * 0.12) if h > 0.5 else col.darkened((0.5 - h) * 0.3)
			ball(ci, S, Vector2(x, y) + Vector2(h - 0.5, Draw.hash01(int(y), int(x), seed_v) - 0.5) * rad * 0.5, rad * (0.92 + h * 0.16), c)
	# the rim over the top
	ci.draw_rect(r.grow(-0.75), CRATE.lightened(0.05), false, 1.5)


static func price_card(ci: CanvasItem, S: Dictionary, at: Vector2) -> void:
	var r := Rect2(at - Vector2(M(0.08), M(0.05)), Vector2(M(0.16), M(0.1)))
	Draw.rect(ci, r.grow(0.6), Color(0, 0, 0, 0.25))
	Draw.rect(ci, r, WHITE)
	ci.draw_line(r.position + Vector2(2, r.size.y * 0.5), r.end - Vector2(2, r.size.y * 0.5), Color("2a2a2a"), 1.2)


# ------------------------------------------------------------------ the trades

## Grocer: a tiered wooden stand of fruit and vegetable crates, price cards on the front.
static func produce(ci: CanvasItem, S: Dictionary, r: Rect2, rng: RandomNumberGenerator) -> void:
	shadow_rect(ci, S, r, 0.9)
	Draw.rect(ci, r.grow(1.0), WOOD_DK)
	Draw.rect(ci, r, WOOD)
	var rows := 2
	var cols := maxi(2, int(round(r.size.x / M(0.5))))
	var pad := 2.0
	var cw := (r.size.x - pad * (cols + 1)) / cols
	var chh := (r.size.y - pad * (rows + 1)) / rows
	var picks := []
	for k in rows * cols:
		picks.append(FRUIT[rng.randi_range(0, FRUIT.size() - 1)])
	for j in rows:
		for i in cols:
			var cr := Rect2(r.position + Vector2(pad + i * (cw + pad), pad + j * (chh + pad)), Vector2(cw, chh))
			fruit_crate(ci, S, cr, picks[j * cols + i], rng.randi())
		# the tier step: the back row sits higher, it shades the front row a little
		if j == 0:
			var y := r.position.y + pad + chh + pad * 0.5
			ci.draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(0, 0, 0, 0.35), 2.0)
	for i in cols:
		if rng.randf() < 0.7:
			price_card(ci, S, Vector2(r.position.x + pad + i * (cw + pad) + cw * 0.5, r.end.y - 2.0))


## Bakery: an open wooden rack, two shelves of big loaves.
static func bread_rack(ci: CanvasItem, S: Dictionary, r: Rect2, rng: RandomNumberGenerator) -> void:
	var rack := r.grow(-2.0)
	shadow_rect(ci, S, rack, 1.3)
	Draw.rect(ci, rack.grow(1.5), WOOD_DK)
	Draw.rect(ci, rack, Color("5e452e"))
	var shelves := 2
	var sh_h := rack.size.y / shelves
	for s in shelves:
		var y0 := rack.position.y + s * sh_h
		Draw.rect(ci, Rect2(Vector2(rack.position.x, y0 + 2.0), Vector2(rack.size.x, sh_h - 4.0)), WOOD_LT.darkened(0.05 + s * 0.1))
		for k in 3:
			var ly := y0 + 2.0 + (sh_h - 4.0) * (k + 0.5) / 3.0
			ci.draw_line(Vector2(rack.position.x, ly), Vector2(rack.end.x, ly), WOOD.darkened(0.1), 1.0)
		var x := rack.position.x + M(0.05)
		while x < rack.end.x - M(0.28):
			var c := LOAF.lightened(rng.randf_range(-0.12, 0.1))
			var cy := y0 + sh_h * 0.5
			if rng.randf() < 0.4:
				var rad := minf(M(0.15), sh_h * 0.42)
				var cc := Vector2(x + rad, cy)
				shadow_circle(ci, S, cc, rad, 0.15, 0.25)
				ball(ci, S, cc, rad, c, 0.28)
				ci.draw_line(cc - Vector2(rad * 0.55, rad * 0.1), cc + Vector2(rad * 0.55, -rad * 0.1), c.darkened(0.4), 1.5, true)
				ci.draw_line(cc - Vector2(rad * 0.1, rad * 0.55), cc + Vector2(-rad * 0.1, rad * 0.55), c.darkened(0.4), 1.5, true)
				x += rad * 2.0 + 3.0
			else:
				var len := M(rng.randf_range(0.36, 0.46))
				var hw := minf(M(0.1), sh_h * 0.36)
				var a := Vector2(x + hw, cy)
				var b := a + Vector2(len - hw * 2.0, 0)
				Draw.capsule(ci, a + sh(S, 0.12), b + sh(S, 0.12), hw, Color(FX.SHADE, 0.25))
				Draw.capsule(ci, a, b, hw, c.darkened(0.25))
				Draw.capsule(ci, a + lit(S) * 1.5, b + lit(S) * 1.5, hw * 0.72, c)
				for k in 4:
					var sx := a.x + (b.x - a.x) * (0.1 + k * 0.27)
					ci.draw_line(Vector2(sx - hw * 0.4, cy - hw * 0.45), Vector2(sx + hw * 0.4, cy + hw * 0.45), c.lightened(0.28), 1.5, true)
				x += len + 3.0


## A wicker basket of long loaves laid across it.
static func baguette_barrel(ci: CanvasItem, S: Dictionary, r: Rect2, rng: RandomNumberGenerator) -> void:
	var w := minf(r.size.x - 4.0, M(0.95))
	var bk := Rect2(Vector2(r.get_center().x - w * 0.5, r.position.y + r.size.y * 0.1), Vector2(w, r.size.y * 0.72))
	shadow_rect(ci, S, bk, 0.7)
	Draw.rrect(ci, bk, 6.0, STRAW.darkened(0.4))
	Draw.rrect(ci, bk.grow(-2.5), 5.0, STRAW.darkened(0.1))
	for k in int(bk.size.x / 4.0):
		var x := bk.position.x + 3.0 + k * 4.0
		ci.draw_line(Vector2(x, bk.position.y + 3.0), Vector2(x, bk.end.y - 3.0), STRAW.darkened(0.3), 1.0)
	Draw.rect(ci, bk.grow(-5.0), Color("e8dcc0"))
	# a cloth under the bread, then five long loaves on the diagonal
	var n := 5
	for k in n:
		var t := (k + 0.5) / n
		var a := Vector2(bk.position.x + bk.size.x * (t - 0.18), bk.end.y - 6.0)
		var b := Vector2(bk.position.x + bk.size.x * (t + 0.18), bk.position.y + 6.0)
		var c := LOAF.lightened(rng.randf_range(-0.08, 0.12))
		Draw.capsule(ci, a + sh(S, 0.1), b + sh(S, 0.1), M(0.07), Color(FX.SHADE, 0.3))
		Draw.capsule(ci, a, b, M(0.07), c.darkened(0.25))
		Draw.capsule(ci, a + lit(S), b + lit(S), M(0.05), c)
		for s in 4:
			var p := a.lerp(b, 0.18 + s * 0.22)
			var d := (b - a).normalized()
			ci.draw_line(p - d * 3.0 + d.orthogonal() * 2.0, p + d * 3.0 - d.orthogonal() * 2.0, c.lightened(0.3), 1.2, true)


## Butcher: an iron rail of hams and sausages, on two posts.
static func meat_rail(ci: CanvasItem, S: Dictionary, r: Rect2, rng: RandomNumberGenerator) -> void:
	var y := r.position.y + r.size.y * 0.28
	var a := Vector2(r.position.x + 3.0, y)
	var b := Vector2(r.end.x - 3.0, y)
	shadow_pole(ci, S, a, 2.0, 3.0)
	shadow_pole(ci, S, b, 2.0, 3.0)
	var o := sh(S, 1.9)
	ci.draw_line(a + o, b + o, Color(FX.SHADE, 0.2), 3.0, true)
	# sawdust on the slabs underneath
	for k in 40:
		var p := r.position + Vector2(rng.randf() * r.size.x, rng.randf() * r.size.y)
		Draw.circle(ci, p, rng.randf_range(0.6, 1.3), Color("d8c8a0", 0.7))
	var n := maxi(2, int((b.x - a.x) / M(0.34)))
	for k in n:
		var x := a.x + (b.x - a.x) * (k + 0.5) / n
		var p := Vector2(x, y + M(0.06))
		if k % 3 == 1:
			# a string of sausages
			for s in 5:
				var q := p + Vector2(0, s * M(0.085))
				Draw.capsule(ci, q, q + Vector2(0, M(0.06)), M(0.04), Color("8a3a2a").lightened(rng.randf() * 0.12))
		else:
			# a ham: dark red, a cream rim of fat, the bone knuckle
			var hc := p + Vector2(0, M(0.16))
			Draw.ellipse(ci, hc + sh(S, 1.2) * 0.5, Vector2(M(0.13), M(0.2)), Color(FX.SHADE, 0.25))
			Draw.ellipse(ci, hc, Vector2(M(0.13), M(0.2)), Color("e0cfae"))
			Draw.ellipse(ci, hc + Vector2(0, M(0.015)), Vector2(M(0.105), M(0.17)), Color("8e3a30").lightened(rng.randf() * 0.1))
			Draw.ellipse(ci, hc + lit(S) * 2.0, Vector2(M(0.05), M(0.1)), Color("b0564a"))
			ci.draw_line(p, hc - Vector2(0, M(0.18)), IRON, 1.5)
			Draw.circle(ci, hc - Vector2(0, M(0.17)), M(0.035), Color("efe4cc"))
	ci.draw_line(a, b, IRON, 3.0, true)
	ci.draw_line(a + Vector2(0, -1), b + Vector2(0, -1), IRON_HI, 1.0, true)
	Draw.circle(ci, a, 3.5, IRON)
	Draw.circle(ci, b, 3.5, IRON)


static func chop_block(ci: CanvasItem, S: Dictionary, r: Rect2, rng: RandomNumberGenerator) -> void:
	var c := r.get_center()
	var rad := minf(r.size.x, r.size.y) * 0.3
	shadow_circle(ci, S, c, rad, 0.8)
	Draw.circle(ci, c, rad, Color("6a4a30"))
	Draw.circle(ci, c, rad - 1.5, Color("b89468"))
	for k in 4:
		ci.draw_arc(c + Vector2(1, 1), rad * (0.25 + k * 0.18), 0.0, TAU, 24, Color("9a7650"), 1.0, true)
	# a cleaver stuck in the top
	var blade := Rect2(c + Vector2(-M(0.1), -M(0.03)), Vector2(M(0.16), M(0.07)))
	Draw.rect(ci, blade, Color("b8bcbe"))
	ci.draw_line(blade.position, blade.position + Vector2(blade.size.x, 0), Color("e4e8ea"), 1.0)
	Draw.capsule(ci, Vector2(blade.end.x, c.y), Vector2(blade.end.x + M(0.1), c.y), M(0.02), Color("3a2418"))
	# a crate of ice beside it
	var ice := Rect2(r.position + Vector2(r.size.x * 0.05, r.size.y * 0.62), Vector2(r.size.x * 0.4, r.size.y * 0.32))
	shadow_rect(ci, S, ice, 0.4)
	crate(ci, S, ice)
	Draw.rect(ci, ice.grow(-3.0), Color("dfe8ea"))
	for k in 6:
		Draw.rect(ci, Rect2(ice.position + Vector2(3 + rng.randf() * (ice.size.x - 10), 3 + rng.randf() * (ice.size.y - 10)), Vector2(4, 3)), Color(1, 1, 1, 0.8))


## Fish market: a sloped table of crushed ice with rows of fish, lemons and parsley.
static func fish_ice(ci: CanvasItem, S: Dictionary, r: Rect2, rng: RandomNumberGenerator) -> void:
	shadow_rect(ci, S, r, 0.9)
	Draw.rect(ci, r.grow(1.5), ZINC.darkened(0.35))
	Draw.rect(ci, r, ZINC)
	var ice := r.grow(-2.5)
	Draw.vgrad(ci, ice, Color("cfdde2"), Color("eef4f5"))
	for k in int(ice.get_area() / 30.0):
		var p := ice.position + Vector2(rng.randf() * ice.size.x, rng.randf() * ice.size.y)
		Draw.rect(ci, Rect2(p, Vector2(2, 2)), Color(1, 1, 1, 0.75) if rng.randf() < 0.6 else Color("b8ccd2"))
	var rows := maxi(2, int(ice.size.y / M(0.2)))
	var dy := ice.size.y / rows
	for j in rows:
		var y := ice.position.y + dy * (j + 0.5)
		var x := ice.position.x + M(0.05)
		var kind := rng.randi_range(0, 3)
		while x < ice.end.x - M(0.28):
			var len := M(0.24) if kind != 2 else M(0.32)
			var flip := (int(x / 7.0) + j) % 2 == 0
			_fish(ci, Vector2(x + len * 0.5, y), len, flip, kind)
			x += len * 0.62
		if rng.randf() < 0.5:
			Draw.circle(ci, Vector2(ice.end.x - M(0.12), y), M(0.04), Color("e6c73a"))
			Draw.circle(ci, Vector2(ice.end.x - M(0.06), y + 3), 2.5, Color("4f8a3a"))


static func _fish(ci: CanvasItem, c: Vector2, len: float, flip: bool, kind: int) -> void:
	var d := -1.0 if flip else 1.0
	var body: Color = [Color("9aa6ae"), Color("b8b2a8"), Color("c05a44"), Color("7a8a90")][kind]
	var back := body.darkened(0.45)
	var hw := len * (0.16 if kind != 2 else 0.19)
	var tail := c + Vector2(-d * len * 0.5, 0)
	Draw.poly(ci, PackedVector2Array([tail, tail + Vector2(-d * len * 0.16, -hw * 0.9), tail + Vector2(-d * len * 0.16, hw * 0.9)]), back)
	Draw.ellipse(ci, c, Vector2(len * 0.46, hw), body)
	ci.draw_line(c + Vector2(-d * len * 0.38, -hw * 0.35), c + Vector2(d * len * 0.35, -hw * 0.35), back, 1.5, true)
	ci.draw_line(c + Vector2(-d * len * 0.3, hw * 0.35), c + Vector2(d * len * 0.3, hw * 0.35), body.lightened(0.35), 1.0, true)
	Draw.circle(ci, c + Vector2(d * len * 0.32, -hw * 0.1), 1.2, Color("1a1a1a"))


static func oyster_barrel(ci: CanvasItem, S: Dictionary, r: Rect2, rng: RandomNumberGenerator) -> void:
	var c := r.get_center() + Vector2(0, -r.size.y * 0.05)
	var rad := minf(r.size.x * 0.32, r.size.y * 0.38)
	barrel(ci, S, c, rad)
	Draw.circle(ci, c, rad * 0.8, Color("dfe8ea"))
	for k in 14:
		var p := c + Vector2.from_angle(rng.randf() * TAU) * rad * sqrt(rng.randf()) * 0.7
		Draw.ellipse(ci, p, Vector2(M(0.05), M(0.035)), Color("7e7a70"), rng.randf() * PI)
		Draw.ellipse(ci, p + Vector2(-0.6, -0.6), Vector2(M(0.035), M(0.022)), Color("b8b2a4"), rng.randf() * PI)
	# a lobster crate beside it
	var cr := Rect2(Vector2(r.position.x + r.size.x * 0.06, r.end.y - M(0.36)), Vector2(r.size.x * 0.88, M(0.3)))
	if cr.size.x > M(0.5):
		cr.size.x = M(0.5)
		shadow_rect(ci, S, cr, 0.35)
		crate(ci, S, cr)
		for k in 2:
			var p := cr.position + Vector2(cr.size.x * (0.3 + k * 0.4), cr.size.y * 0.5)
			Draw.ellipse(ci, p, Vector2(M(0.09), M(0.04)), Color("8a2a22"))
			Draw.circle(ci, p + Vector2(M(0.09), -3), 2.5, Color("8a2a22"))
			Draw.circle(ci, p + Vector2(M(0.09), 3), 2.5, Color("8a2a22"))


static func barrel(ci: CanvasItem, S: Dictionary, c: Vector2, rad: float) -> void:
	shadow_circle(ci, S, c, rad, 0.9)
	Draw.circle(ci, c, rad, WOOD_DK)
	Draw.circle(ci, c, rad - 1.2, WOOD)
	for k in 12:
		var a := TAU * k / 12.0
		ci.draw_line(c + Vector2.from_angle(a) * (rad - 3.0), c + Vector2.from_angle(a) * (rad - 1.2), WOOD_DK, 1.0)
	ci.draw_arc(c, rad - 0.8, 0.0, TAU, 32, IRON, 1.8, true)
	ci.draw_arc(c + lit(S) * 0.6, rad - 1.2, PI * 0.9, PI * 1.6, 12, Color(1, 1, 1, 0.18), 1.0, true)


## Café: a small round marble table, coffee cups, two bentwood chairs set at an angle.
static func cafe_table(ci: CanvasItem, S: Dictionary, r: Rect2, rng: RandomNumberGenerator) -> void:
	var c := r.get_center()
	var rad := minf(M(0.34), minf(r.size.x, r.size.y) * 0.3)
	var off := Vector2(minf(r.size.x * 0.5 - M(0.2), rad + M(0.2)), minf(r.size.y * 0.5 - M(0.2), M(0.2)))
	chair(ci, S, c + Vector2(-off.x, -off.y), Vector2(1, 0.5), Color("5a3622"))
	chair(ci, S, c + Vector2(off.x, off.y), Vector2(-1, -0.5), Color("5a3622"))
	shadow_circle(ci, S, c, rad, 0.75)
	Draw.circle(ci, c, rad + 1.5, Color("6a665e"))
	Draw.circle(ci, c, rad, Pal.MARBLE)
	ci.draw_arc(c, rad - 2.0, PI * 1.0, PI * 1.5, 10, Color(1, 1, 1, 0.6), 1.5, true)
	ci.draw_line(c + Vector2(-rad * 0.5, -rad * 0.2), c + Vector2(rad * 0.3, rad * 0.35), Color("b8b2a6"), 0.8, true)
	for k in (2 if rng.randf() < 0.6 else 1):
		var cup := c + Vector2(rad * 0.35, -rad * 0.2) * (1.0 if k == 0 else -1.0)
		Draw.circle(ci, cup, M(0.075), Color(0, 0, 0, 0.12))
		Draw.circle(ci, cup, M(0.07), WHITE)
		Draw.circle(ci, cup, M(0.04), Color("f8f4ea"))
		Draw.circle(ci, cup, M(0.028), Color("3a2418"))
		ci.draw_line(cup + Vector2(M(0.04), 0), cup + Vector2(M(0.065), 0), WHITE, 2.0)


## Restaurant: a square table with a checked cloth, plates and a bottle, two chairs.
static func rest_table(ci: CanvasItem, S: Dictionary, r: Rect2, rng: RandomNumberGenerator) -> void:
	var c := r.get_center()
	var hs := minf(M(0.36), minf(r.size.x, r.size.y) * 0.32)
	var off := minf(r.size.x * 0.5 - M(0.2), hs + M(0.2))
	chair(ci, S, c + Vector2(-off, 0), Vector2(1, 0), Color("4a2e1c"))
	chair(ci, S, c + Vector2(off, 0), Vector2(-1, 0), Color("4a2e1c"))
	var t := Rect2(c - Vector2(hs, hs), Vector2(hs, hs) * 2.0)
	shadow_rect(ci, S, t, 0.75)
	# the cloth hangs a little past the table
	Draw.rect(ci, t.grow(2.0), Color("d8d0c0"))
	Draw.rect(ci, t, WHITE)
	var n := 6
	var q := t.size.x / n
	for j in n:
		for i in n:
			if (i + j) % 2 == 0:
				Draw.rect(ci, Rect2(t.position + Vector2(i * q, j * q), Vector2(q, q)), Color("b0302a", 0.85))
			elif i % 2 == 0:
				Draw.rect(ci, Rect2(t.position + Vector2(i * q, j * q), Vector2(q, q)), Color("d89a92", 0.5))
	for s: float in [-1.0, 1.0]:
		var p := c + Vector2(s * hs * 0.5, 0)
		Draw.circle(ci, p, M(0.12), Color(0, 0, 0, 0.14))
		Draw.circle(ci, p, M(0.115), WHITE)
		Draw.circle(ci, p, M(0.075), Color("ebe4d4"))
		ci.draw_arc(p, M(0.1), 0.0, TAU, 16, Color("3a6a8a", 0.6), 1.0, true)
	var bottle := c + Vector2(0, -hs * 0.5)
	Draw.circle(ci, bottle, M(0.055), Color("1e3a24"))
	Draw.circle(ci, bottle + Vector2(-1, -1), M(0.02), Color("6a9a6a"))
	if rng.randf() < 0.7:
		Draw.circle(ci, c + Vector2(0, hs * 0.5), M(0.035), Color("f4ecc8"))
		Draw.circle(ci, c + Vector2(0, hs * 0.5), M(0.012), Color("ffcc66"))


## A bentwood chair from above: a caned round seat, the bent back hoop away from `facing`.
static func chair(ci: CanvasItem, S: Dictionary, c: Vector2, facing: Vector2, col: Color) -> void:
	var rad := M(0.17)
	var back := -facing.normalized()
	shadow_circle(ci, S, c, rad, 0.5, 0.24)
	ci.draw_arc(c + back * rad * 0.2 + sh(S, 0.9) * 0.6, rad * 1.02, back.angle() - 1.2, back.angle() + 1.2, 12, Color(FX.SHADE, 0.2), 3.0, true)
	Draw.circle(ci, c, rad, col)
	Draw.circle(ci, c, rad - 2.0, Color("c8a870"))
	for k in 3:
		ci.draw_line(c + Vector2(-rad * 0.6, (k - 1) * rad * 0.4), c + Vector2(rad * 0.6, (k - 1) * rad * 0.4), Color("a88a58"), 1.0)
	ci.draw_arc(c + back * rad * 0.2, rad * 1.02, back.angle() - 1.2, back.angle() + 1.2, 12, col.darkened(0.3), 3.5, true)
	ci.draw_arc(c + back * rad * 0.2, rad * 1.02, back.angle() - 1.2, back.angle() + 1.2, 12, col.lightened(0.3), 1.0, true)


## Barber: the striped pole on its iron foot. From above: the glass globe on top, the red,
## white and blue spiral wound round it, and its long thin shadow.
static func barber_pole(ci: CanvasItem, S: Dictionary, r: Rect2, _rng: RandomNumberGenerator) -> void:
	var c := Vector2(r.get_center().x, r.position.y + r.size.y * 0.5)
	var rad := M(0.19)
	shadow_pole(ci, S, c, 2.2, rad * 1.8)
	Draw.circle(ci, c + sh(S, 2.2), rad * 1.1, Color(FX.SHADE, 0.2))
	Draw.circle(ci, c, rad * 1.55, IRON)
	Draw.circle(ci, c + lit(S), rad * 1.35, IRON_HI.darkened(0.1))
	Draw.circle(ci, c, rad, WHITE)
	for k in 3:
		var a := TAU * k / 3.0
		ci.draw_arc(c, rad * 0.64, a, a + 1.25, 10, Color("c02a2a"), rad * 0.55, true)
		ci.draw_arc(c, rad * 0.64, a + 1.25, a + 1.75, 6, Color("2a4a9a"), rad * 0.55, true)
	ci.draw_arc(c, rad, 0.0, TAU, 24, Pal.BRASS.darkened(0.25), 2.5, true)
	Draw.circle(ci, c, rad * 0.32, Pal.BRASS)
	Draw.circle(ci, c + lit(S) * rad * 0.12, rad * 0.16, Pal.GOLD2)
	ci.draw_arc(c + lit(S) * 1.5, rad * 0.8, PI * 1.05, PI * 1.45, 8, Color(1, 1, 1, 0.55), 2.0, true)


## A wooden slat bench along the wall, iron ends.
static func bench(ci: CanvasItem, S: Dictionary, r: Rect2, _rng: RandomNumberGenerator) -> void:
	var len := minf(r.size.x - 4.0, M(1.4))
	var b := Rect2(Vector2(r.get_center().x - len * 0.5, r.position.y + r.size.y * 0.35), Vector2(len, M(0.42)))
	shadow_rect(ci, S, b, 0.45)
	for k in 4:
		var y := b.position.y + b.size.y * (k + 0.5) / 4.0
		Draw.rect(ci, Rect2(Vector2(b.position.x, y - M(0.04)), Vector2(b.size.x, M(0.08))), WOOD_LT.darkened(0.05 * k))
		ci.draw_line(Vector2(b.position.x, y - M(0.04)), Vector2(b.end.x, y - M(0.04)), WOOD_LT.lightened(0.15), 0.8)
	for x in [b.position.x + 2.0, b.end.x - 2.0]:
		Draw.rect(ci, Rect2(Vector2(x - 2.0, b.position.y - 1.0), Vector2(4.0, b.size.y + 2.0)), IRON)


## Tailor: a dress form on a tripod, a half-made jacket pinned on, a tape over the shoulder.
static func dummy(ci: CanvasItem, S: Dictionary, r: Rect2, rng: RandomNumberGenerator) -> void:
	var c := r.get_center()
	shadow_pole(ci, S, c, 1.6, M(0.06))
	Draw.ellipse(ci, c + sh(S, 1.6), Vector2(M(0.3), M(0.18)), Color(FX.SHADE, 0.22))
	for k in 3:
		var a := TAU * k / 3.0 + 0.5
		ci.draw_line(c, c + Vector2.from_angle(a) * M(0.38), WOOD_DK, 3.0, true)
		Draw.circle(ci, c + Vector2.from_angle(a) * M(0.38), 2.5, Pal.BRASS)
	var cloth := Color("d8cdb4") if rng.randf() < 0.6 else Color("3a3a42")
	var sz := Vector2(M(0.32), M(0.19))
	Draw.ellipse(ci, c, sz, cloth.darkened(0.3))
	Draw.ellipse(ci, c + lit(S) * 1.5, sz * 0.9, cloth)
	var jacket := Pal.SUITS[rng.randi_range(0, Pal.SUITS.size() - 1)] as Color
	var jp := PackedVector2Array([c + Vector2(-sz.x * 0.95, -sz.y * 0.1), c + Vector2(-sz.x * 0.25, -sz.y * 0.85),
		c + Vector2(-sz.x * 0.08, sz.y * 0.9), c + Vector2(-sz.x * 0.8, sz.y * 0.55)])
	Draw.poly(ci, jp, jacket)
	ci.draw_line(c + Vector2(-sz.x * 0.25, -sz.y * 0.85), c + Vector2(-sz.x * 0.08, sz.y * 0.9), jacket.lightened(0.25), 1.2, true)
	for k in 3:
		Draw.circle(ci, c + Vector2(-sz.x * 0.12, -sz.y * 0.4 + k * sz.y * 0.4), 1.2, Color("c8c0b0"))
	Draw.circle(ci, c, M(0.07), WOOD)
	Draw.circle(ci, c + lit(S) * 1.5, M(0.045), WOOD_LT)
	ci.draw_polyline(PackedVector2Array([c + Vector2(M(0.03), -sz.y), c + Vector2(M(0.1), -sz.y * 0.2), c + Vector2(M(0.13), sz.y * 0.9), c + Vector2(M(0.18), sz.y * 1.4)]), Color("e0c24a"), 2.5, true)


## A rail of suits on hangers: from above, a row of thin slabs across the rail.
static func suit_rack(ci: CanvasItem, S: Dictionary, r: Rect2, rng: RandomNumberGenerator) -> void:
	var y := r.get_center().y
	var a := Vector2(r.position.x + 4.0, y)
	var b := Vector2(r.end.x - 4.0, y)
	var d := M(0.26)
	shadow_rect(ci, S, Rect2(Vector2(a.x, y - d), Vector2(b.x - a.x, d * 2.0)), 1.5, 0.22)
	var x := a.x + 4.0
	while x < b.x - 3.0:
		var col := Pal.SUITS[rng.randi_range(0, Pal.SUITS.size() - 1)] as Color
		var w := M(0.07)
		Draw.rect(ci, Rect2(Vector2(x, y - d), Vector2(w, d * 2.0)), col.darkened(0.2))
		Draw.rect(ci, Rect2(Vector2(x + 1.0, y - d + 1.0), Vector2(w - 2.0, d * 2.0 - 2.0)), col.lightened(0.08))
		x += w + 1.0
	ci.draw_line(a, b, Color("b8b0a0"), 2.0, true)
	for p in [a, b]:
		Draw.circle(ci, p, 3.0, IRON)
		Draw.circle(ci, p + Vector2(0, -d - 3.0), 2.0, IRON)
		Draw.circle(ci, p + Vector2(0, d + 3.0), 2.0, IRON)


## Cobbler: the shoeshine stand, a raised chair with two brass footrests.
static func shoeshine(ci: CanvasItem, S: Dictionary, r: Rect2, _rng: RandomNumberGenerator) -> void:
	var w := minf(r.size.x - 6.0, M(0.8))
	var base := Rect2(Vector2(r.get_center().x - w * 0.5, r.position.y + M(0.08)), Vector2(w, minf(r.size.y - M(0.1), M(0.95))))
	shadow_rect(ci, S, base, 0.5)
	Draw.rect(ci, base, WOOD_DK)
	Draw.rect(ci, base.grow(-1.5), WOOD)
	var seat := Rect2(base.position + Vector2(w * 0.15, M(0.08)), Vector2(w * 0.7, M(0.42)))
	shadow_rect(ci, S, seat, 0.6, 0.25)
	Draw.rrect(ci, seat, 4.0, Color("5a2e22"))
	Draw.rrect(ci, seat.grow(-2.5), 3.0, Color("7a3e2c"))
	Draw.rect(ci, Rect2(seat.position - Vector2(3, 0), Vector2(4, seat.size.y)), WOOD_DK)
	Draw.rect(ci, Rect2(Vector2(seat.end.x - 1, seat.position.y), Vector2(4, seat.size.y)), WOOD_DK)
	for s: float in [-1.0, 1.0]:
		var p := Vector2(base.get_center().x + s * w * 0.18, base.end.y - M(0.18))
		Draw.poly(ci, PackedVector2Array([p + Vector2(-M(0.05), -M(0.1)), p + Vector2(M(0.05), -M(0.1)), p + Vector2(M(0.06), M(0.1)), p + Vector2(-M(0.06), M(0.1))]), Pal.BRASS)
		ci.draw_line(p + Vector2(-M(0.04), -M(0.08)), p + Vector2(-M(0.04), M(0.08)), Pal.GOLD2, 1.0)
	for k in 3:
		Draw.circle(ci, Vector2(base.position.x + M(0.08) + k * M(0.08), base.end.y - M(0.05)), M(0.03), [Color("2a1a10"), Color("6a3a20"), Color("1a1a1a")][k])


## Pawnshop: a crate of odds and ends and a gramophone on top.
static func junk_crate(ci: CanvasItem, S: Dictionary, r: Rect2, rng: RandomNumberGenerator) -> void:
	var cr := Rect2(r.position + Vector2(r.size.x * 0.08, r.size.y * 0.12), Vector2(minf(r.size.x * 0.84, M(0.9)), r.size.y * 0.7))
	shadow_rect(ci, S, cr, 0.55)
	crate(ci, S, cr)
	# a gramophone: the brass horn flaring out, the box under it
	var box := Rect2(cr.position + Vector2(M(0.08), M(0.1)), Vector2(M(0.32), M(0.32)))
	shadow_rect(ci, S, box, 0.35, 0.3)
	Draw.rect(ci, box, Color("5a3624"))
	Draw.rect(ci, box.grow(-2.0), Color("7a4a30"))
	var hub := box.get_center()
	var mouth := hub + Vector2(M(0.24), M(0.08))
	Draw.poly(ci, PackedVector2Array([hub + Vector2(0, -2), hub + Vector2(0, 2), mouth + Vector2(-M(0.02), M(0.14)), mouth + Vector2(-M(0.02), -M(0.14))]), Pal.BRASS.darkened(0.1))
	Draw.ellipse(ci, mouth, Vector2(M(0.06), M(0.15)), Pal.BRASS)
	Draw.ellipse(ci, mouth + Vector2(1, 0), Vector2(M(0.04), M(0.11)), Color("3a2a14"))
	# a violin case and a clock
	var vc := cr.position + Vector2(cr.size.x * 0.72, cr.size.y * 0.3)
	Draw.capsule(ci, vc, vc + Vector2(0, cr.size.y * 0.5), M(0.07), Color("2a1e18"))
	Draw.circle(ci, cr.position + Vector2(cr.size.x * 0.35, cr.size.y * 0.78), M(0.06), Color("d9d0b8"))
	ci.draw_arc(cr.position + Vector2(cr.size.x * 0.35, cr.size.y * 0.78), M(0.06), 0.0, TAU, 16, Pal.BRASS, 1.5, true)
	if rng.randf() < 0.5:
		Draw.circle(ci, cr.position + Vector2(cr.size.x * 0.5, cr.size.y * 0.25), M(0.05), Color("7a8a90"))


## Laundry: a wicker cart heaped with sheets, and paper-wrapped bundles tied with string.
static func laundry_cart(ci: CanvasItem, S: Dictionary, r: Rect2, rng: RandomNumberGenerator) -> void:
	var w := minf(r.size.x - 6.0, M(1.0))
	var cart := Rect2(Vector2(r.get_center().x - w * 0.5, r.position.y + r.size.y * 0.12), Vector2(w, r.size.y * 0.72))
	shadow_rect(ci, S, cart, 0.8)
	for p in [cart.position, Vector2(cart.end.x, cart.position.y), cart.end, Vector2(cart.position.x, cart.end.y)]:
		Draw.rect(ci, Rect2(p - Vector2(2.5, 4.0), Vector2(5, 8)), IRON)
	Draw.rrect(ci, cart, 4.0, STRAW.darkened(0.35))
	Draw.rrect(ci, cart.grow(-2.0), 3.0, STRAW)
	for k in int(cart.size.x / 4.0):
		var x := cart.position.x + 2.0 + k * 4.0
		ci.draw_line(Vector2(x, cart.position.y + 2), Vector2(x, cart.end.y - 2), STRAW.darkened(0.2), 1.0)
	var inner := cart.grow(-4.0)
	for k in 7:
		var p := inner.position + Vector2(rng.randf() * inner.size.x, rng.randf() * inner.size.y)
		var rr := Vector2(rng.randf_range(0.14, 0.24), rng.randf_range(0.1, 0.16)) * W.M
		rr = rr.min(inner.size * 0.5)
		Draw.ellipse(ci, p, rr, Color("d8d2c4"), rng.randf() * PI)
		Draw.ellipse(ci, p + lit(S) * 1.5, rr * 0.75, WHITE if k % 3 != 0 else Color("c8d4e0"), rng.randf() * PI)


static func bundles(ci: CanvasItem, S: Dictionary, r: Rect2, rng: RandomNumberGenerator) -> void:
	var x := r.position.x + 3.0
	var y := r.position.y + r.size.y * 0.15
	var n := 0
	while n < 5:
		var bw := M(rng.randf_range(0.32, 0.44))
		var bh := M(rng.randf_range(0.24, 0.32))
		if x + bw > r.end.x - 2.0:
			x = r.position.x + 3.0 + M(0.1)
			y += M(0.36)
			if y + bh > r.end.y:
				break
		var b := Rect2(Vector2(x, y), Vector2(bw, bh))
		shadow_rect(ci, S, b, 0.3, 0.26)
		var paper := Color("b89a6a").lightened(rng.randf_range(-0.08, 0.1))
		Draw.rrect(ci, b, 3.0, paper.darkened(0.2))
		Draw.rrect(ci, b.grow(-1.2), 2.0, paper)
		ci.draw_line(Vector2(b.get_center().x, b.position.y), Vector2(b.get_center().x, b.end.y), Color("e8e0cc"), 1.0)
		ci.draw_line(Vector2(b.position.x, b.get_center().y), Vector2(b.end.x, b.get_center().y), Color("e8e0cc"), 1.0)
		Draw.rect(ci, Rect2(b.get_center() + Vector2(2, 2), Vector2(5, 3)), WHITE)
		x += bw + 3.0
		n += 1


## Cigar store: a wooden rack of the day's papers.
static func news_rack(ci: CanvasItem, S: Dictionary, r: Rect2, rng: RandomNumberGenerator) -> void:
	var w := minf(r.size.x - 4.0, M(1.1))
	var rack := Rect2(Vector2(r.get_center().x - w * 0.5, r.position.y + r.size.y * 0.1), Vector2(w, minf(r.size.y * 0.8, M(0.8))))
	shadow_rect(ci, S, rack, 0.9)
	Draw.rect(ci, rack.grow(1.0), WOOD_DK)
	Draw.rect(ci, rack, WOOD)
	var cols := maxi(2, int(rack.size.x / M(0.34)))
	var pw := (rack.size.x - 3.0 * (cols + 1)) / cols
	var ph := (rack.size.y - 9.0) / 2.0
	for j in 2:
		for i in cols:
			var p := Rect2(rack.position + Vector2(3.0 + i * (pw + 3.0), 3.0 + j * (ph + 3.0)), Vector2(pw, ph))
			Draw.rect(ci, p.grow(0.8), Color(0, 0, 0, 0.3))
			Draw.rect(ci, p, Color("e6dcc3").darkened(rng.randf() * 0.08))
			Draw.rect(ci, Rect2(p.position + Vector2(2, 2), Vector2(p.size.x - 4, 3.5)), Color("1c140c"))
			for k in 4:
				var ly := p.position.y + 8.0 + k * 3.0
				if ly < p.end.y - 2.0:
					ci.draw_line(Vector2(p.position.x + 2, ly), Vector2(p.end.x - 2 - (k % 2) * 4, ly), Color(0.2, 0.18, 0.15, 0.55), 1.0)
			if rng.randf() < 0.5:
				Draw.rect(ci, Rect2(p.position + Vector2(p.size.x * 0.55, 8), Vector2(p.size.x * 0.35, p.size.y * 0.35)), Color(0.35, 0.33, 0.3, 0.7))
	# a stone on each pile against the wind
	Draw.circle(ci, rack.position + Vector2(pw * 0.5 + 3, ph * 0.6), 2.5, Color("6a6660"))


## Hardware: brooms leaning in a barrel, straw heads fanned out; a keg of nails.
static func brooms(ci: CanvasItem, S: Dictionary, r: Rect2, rng: RandomNumberGenerator) -> void:
	var c := Vector2(r.position.x + r.size.x * 0.34, r.position.y + r.size.y * 0.38)
	var rad := minf(r.size.x * 0.24, M(0.25))
	barrel(ci, S, c, rad)
	Draw.circle(ci, c, rad - 3.0, Color("2a2018"))
	# brooms lean out toward the street, heads up
	for k in 5:
		var a := PI * 0.5 + (k - 2) * 0.42 + rng.randf_range(-0.08, 0.08)
		var n := Vector2.from_angle(a)
		var root := c + n * rad * 0.3
		var tip := c + n * (rad + M(0.34))
		ci.draw_line(root + sh(S, 1.2) * 0.5, tip + sh(S, 1.2) * 0.8, Color(FX.SHADE, 0.2), 3.0, true)
		ci.draw_line(root, tip, WOOD_LT, 2.5, true)
		var t := n.orthogonal()
		var hd := M(0.13)
		var head := PackedVector2Array([tip - t * 3.0, tip + t * 3.0, tip + n * hd * 1.5 + t * hd, tip + n * hd * 1.5 - t * hd])
		Draw.poly(ci, head, STRAW.darkened(0.2))
		Draw.poly(ci, PackedVector2Array([tip - t * 2.0, tip + t * 2.0, tip + n * hd * 1.2 + t * hd * 0.6, tip + n * hd * 1.2 - t * hd * 0.6]), STRAW.lightened(0.1))
		ci.draw_line(tip + t * 3.0 + n * 2.0, tip - t * 3.0 + n * 2.0, Color("b8282a"), 1.5, true)
	var keg := Vector2(r.end.x - r.size.x * 0.24, r.position.y + r.size.y * 0.32)
	var kr := minf(r.size.x * 0.2, M(0.22))
	barrel(ci, S, keg, kr)
	Draw.circle(ci, keg, kr - 2.5, Color("5a5856"))
	for k in 18:
		var p := keg + Vector2.from_angle(rng.randf() * TAU) * (kr - 4.0) * sqrt(rng.randf())
		ci.draw_line(p, p + Vector2.from_angle(rng.randf() * TAU) * 3.5, Color("b8b6b2"), 1.0)
	# a watering can and a coil of rope in front
	var can := Vector2(r.end.x - r.size.x * 0.28, r.end.y - M(0.24))
	shadow_circle(ci, S, can, M(0.13), 0.4, 0.24)
	Draw.circle(ci, can, M(0.13), ZINC.darkened(0.2))
	Draw.circle(ci, can + lit(S) * 1.5, M(0.1), ZINC)
	ci.draw_line(can, can + Vector2(-M(0.26), -M(0.05)), ZINC.darkened(0.3), 3.0, true)
	Draw.circle(ci, can + Vector2(-M(0.27), -M(0.05)), 3.0, ZINC.darkened(0.1))


static func pails(ci: CanvasItem, S: Dictionary, r: Rect2, rng: RandomNumberGenerator) -> void:
	var n := clampi(int(r.size.x / M(0.4)), 1, 3)
	for k in n:
		var c := Vector2(r.position.x + r.size.x * (k + 0.5) / n, r.position.y + r.size.y * (0.38 if k % 2 == 0 else 0.62))
		var rad := M(0.16)
		shadow_circle(ci, S, c, rad, 0.8 + k * 0.2)
		for s in 3:
			Draw.circle(ci, c + lit(S) * s * 0.8, rad - s * 1.5, ZINC.darkened(0.25 - s * 0.1))
			ci.draw_arc(c + lit(S) * s * 0.8, rad - s * 1.5, 0.0, TAU, 20, ZINC.lightened(0.2), 1.0, true)
		Draw.circle(ci, c + lit(S) * 3.0, rad * 0.6, Color("6a6e70"))
		ci.draw_arc(c, rad * 0.95, -0.4, PI + 0.4, 12, IRON, 1.0, true)
	if rng.randf() < 0.7 and r.size.y > M(0.9):
		# a coil of rope
		var c2 := Vector2(r.get_center().x, r.end.y - M(0.2))
		for s in 4:
			ci.draw_arc(c2, M(0.16) - s * 2.0, 0.0, TAU, 20, Pal.ROPE.darkened(s * 0.08), 2.0, true)


## Candy store: the gumball machine, a globe of coloured balls on a red stand.
static func gumball(ci: CanvasItem, S: Dictionary, r: Rect2, rng: RandomNumberGenerator) -> void:
	var c := Vector2(r.get_center().x - r.size.x * 0.12, r.position.y + r.size.y * 0.42)
	var rad := M(0.22)
	shadow_pole(ci, S, c, 1.3, M(0.1))
	Draw.circle(ci, c + sh(S, 1.3), rad, Color(FX.SHADE, 0.22))
	Draw.rrect(ci, Rect2(c - Vector2(rad, rad) * 1.18, Vector2(rad, rad) * 2.36), 5.0, Color("7a1a16"))
	Draw.rrect(ci, Rect2(c - Vector2(rad, rad) * 1.1, Vector2(rad, rad) * 2.2), 4.0, Color("b82a22"))
	Draw.circle(ci, c, rad, Color("b8ccd2"))
	var cols := [Color("d83a2a"), Color("e8c83a"), Color("3a8ad8"), Color("4ab04a"), Color("f0f0e8"), Color("e87ab0"), Color("f08a2a")]
	for k in 22:
		var p := c + Vector2.from_angle(rng.randf() * TAU) * (rad - 3.5) * sqrt(rng.randf())
		Draw.circle(ci, p, 2.8, (cols[k % cols.size()] as Color).darkened(0.2))
		Draw.circle(ci, p + lit(S) * 0.7, 2.0, cols[k % cols.size()])
	Draw.circle(ci, c, rad * 0.3, Color("a8acae"))
	Draw.circle(ci, c + lit(S) * 1.0, rad * 0.18, Color("e8ecee"))
	ci.draw_arc(c, rad - 2.0, PI * 1.05, PI * 1.5, 8, Color(1, 1, 1, 0.85), 2.5, true)
	ci.draw_arc(c, rad, 0.0, TAU, 24, Color("8a9a9e"), 1.0, true)
	# a sign card propped against it
	var card := Rect2(c + Vector2(-M(0.14), rad * 1.25), Vector2(M(0.28), M(0.12)))
	Draw.rect(ci, card, WHITE)
	ci.draw_line(card.position + Vector2(3, card.size.y * 0.5), card.end - Vector2(3, card.size.y * 0.5), Color("b82a22"), 2.0)
	# a smaller peanut machine beside it
	var c2 := Vector2(r.get_center().x + r.size.x * 0.28, r.position.y + r.size.y * 0.38)
	if r.size.x > M(0.95):
		shadow_pole(ci, S, c2, 1.1, M(0.07))
		Draw.rrect(ci, Rect2(c2 - Vector2(M(0.14), M(0.14)), Vector2(M(0.28), M(0.28))), 3.0, Color("2a4a6a"))
		Draw.circle(ci, c2, M(0.115), Color("c8d8dc"))
		for k in 10:
			Draw.circle(ci, c2 + Vector2.from_angle(k * 0.7) * M(0.06) * (0.5 + (k % 2) * 0.5), 2.0, Color("b88a4a"))
		Draw.circle(ci, c2, M(0.04), Color("b8bcbe"))


## Wooden crates of soda bottles: a grid of caps.
static func soda_crates(ci: CanvasItem, S: Dictionary, r: Rect2, rng: RandomNumberGenerator) -> void:
	var cw := minf(r.size.x - 6.0, M(0.5))
	var ch := M(0.34)
	var n := clampi(int(r.size.y / (ch + 3.0)), 1, 3)
	for k in n:
		var cr := Rect2(Vector2(r.get_center().x - cw * 0.5 + (k % 2) * 3.0, r.position.y + 3.0 + k * (ch + 3.0)), Vector2(cw, ch))
		shadow_rect(ci, S, cr, 0.3 * (n - k), 0.25)
		crate(ci, S, cr, Color("c8a060") if k % 2 == 0 else Color("a8c060").darkened(0.3))
		var gx := 5
		var gy := 3
		var glass := [Color("2a5a3a"), Color("6a3a1a"), Color("8ab0b8")][rng.randi_range(0, 2)] as Color
		for j in gy:
			for i in gx:
				var p := cr.position + Vector2(cr.size.x * (i + 0.5) / gx, cr.size.y * (j + 0.5) / gy)
				Draw.circle(ci, p, 2.6, glass)
				Draw.circle(ci, p, 1.6, Color("d8c050") if (i + j) % 3 != 0 else Color("c83a2a"))


## Drugstore: the penny scale ("weigh yourself"), red enamel with a round dial.
static func penny_scale(ci: CanvasItem, S: Dictionary, r: Rect2, _rng: RandomNumberGenerator) -> void:
	var c := Vector2(r.get_center().x, r.position.y + r.size.y * 0.4)
	var plat := Rect2(c + Vector2(-M(0.3), -M(0.08)), Vector2(M(0.6), M(0.56)))
	shadow_rect(ci, S, plat, 0.12, 0.25)
	Draw.rrect(ci, plat, 5.0, Color("2a2624"))
	for k in 5:
		ci.draw_line(Vector2(plat.position.x + 5, plat.position.y + 7 + k * 5.5), Vector2(plat.end.x - 5, plat.position.y + 7 + k * 5.5), Color("423e3a"), 2.0)
	var rad := M(0.25)
	shadow_pole(ci, S, c, 1.8, M(0.14))
	Draw.circle(ci, c + sh(S, 1.8), rad, Color(FX.SHADE, 0.2))
	Draw.circle(ci, c, rad, Color("6a1612"))
	Draw.circle(ci, c + lit(S) * 1.5, rad - 2.0, Color("b02a22"))
	Draw.circle(ci, c, rad * 0.68, Color("efe8d4"))
	for k in 16:
		var a := TAU * k / 16.0
		ci.draw_line(c + Vector2.from_angle(a) * rad * 0.52, c + Vector2.from_angle(a) * rad * 0.64, Color("2a2a2a"), 1.0)
	ci.draw_line(c, c + Vector2.from_angle(-0.7) * rad * 0.55, Color("b8201a"), 1.5, true)
	Draw.circle(ci, c, 2.0, Color("2a2a2a"))
	ci.draw_arc(c, rad * 0.68, 0.0, TAU, 24, Pal.BRASS, 2.0, true)
	ci.draw_arc(c + lit(S) * 1.0, rad - 1.5, PI * 1.05, PI * 1.45, 8, Color(1, 1, 1, 0.35), 1.5, true)


## A standing ash urn, sand on top.
static func ash_urn(ci: CanvasItem, S: Dictionary, r: Rect2, rng: RandomNumberGenerator) -> void:
	var c := r.get_center()
	var rad := M(0.17)
	shadow_circle(ci, S, c, rad, 0.8)
	Draw.circle(ci, c, rad, IRON)
	Draw.circle(ci, c, rad - 2.0, Color("c8b890"))
	for k in 5:
		var p := c + Vector2.from_angle(rng.randf() * TAU) * (rad - 5.0) * rng.randf()
		var d := Vector2.from_angle(rng.randf() * TAU) * 3.0
		ci.draw_line(p, p + d, WHITE, 1.5, true)
		Draw.circle(ci, p, 0.8, Color("6a4a30"))


## A wooden tub with a clipped bay tree.
static func planter(ci: CanvasItem, S: Dictionary, r: Rect2, rng: RandomNumberGenerator) -> void:
	var c := r.get_center()
	var hs := minf(M(0.26), minf(r.size.x, r.size.y) * 0.4)
	var tub := Rect2(c - Vector2(hs, hs), Vector2(hs, hs) * 2.0)
	shadow_rect(ci, S, tub, 0.5)
	Draw.rect(ci, tub, WOOD_DK)
	Draw.rect(ci, tub.grow(-1.5), Color("2e4a3a").darkened(0.2))
	ci.draw_rect(tub.grow(-0.5), IRON, false, 1.0)
	var tree := Color("3e6a3a")
	shadow_circle(ci, S, c, hs * 1.15, 1.4, 0.22)
	for k in 7:
		var p := c + Vector2.from_angle(TAU * k / 7.0 + rng.randf() * 0.5) * hs * 0.55
		Draw.circle(ci, p, hs * 0.55, tree.darkened(0.2))
	for k in 7:
		var p := c + Vector2.from_angle(TAU * k / 7.0 + rng.randf() * 0.5) * hs * 0.45 + lit(S) * 2.0
		Draw.circle(ci, p, hs * 0.42, tree.lightened(rng.randf() * 0.12))
	Draw.circle(ci, c + lit(S) * hs * 0.3, hs * 0.3, tree.lightened(0.25))


## A stack of crates and a sack or two.
static func crates(ci: CanvasItem, S: Dictionary, r: Rect2, rng: RandomNumberGenerator) -> void:
	var cw := minf(r.size.x * 0.5, M(0.55))
	var a := Rect2(r.position + Vector2(r.size.x * 0.12, r.size.y * 0.12), Vector2(cw, cw * 0.75))
	var b := Rect2(a.position + Vector2(cw * 0.5, cw * 0.62), Vector2(cw, cw * 0.75))
	shadow_rect(ci, S, a, 0.9)
	shadow_rect(ci, S, b, 0.45)
	crate(ci, S, b)
	crate(ci, S, a)
	if rng.randf() < 0.6:
		var p := Vector2(r.end.x - M(0.2), r.position.y + M(0.3))
		Draw.ellipse(ci, p + sh(S, 0.3) * 0.5, Vector2(M(0.18), M(0.13)), Color(FX.SHADE, 0.25))
		Draw.ellipse(ci, p, Vector2(M(0.17), M(0.12)), Color("a8906a"))
		Draw.ellipse(ci, p + lit(S) * 2.0, Vector2(M(0.12), M(0.08)), Color("c0a87e"))


## The discreet way into a speakeasy: stairs down to a cellar door, an iron railing, a red bulb.
static func cellar_stairs(ci: CanvasItem, S: Dictionary, r: Rect2, night_on: bool) -> void:
	var w := minf(r.size.x - 4.0, M(1.0))
	var st := Rect2(Vector2(r.get_center().x - w * 0.5, r.position.y), Vector2(w, r.size.y - M(0.1)))
	Draw.rect(ci, st.grow(2.0), Color("5a544c"))
	var n := 6
	for k in n:
		# deeper toward the wall: darker
		var t := float(k) / (n - 1)
		var y0 := st.position.y + st.size.y * k / n
		var col := Color("1a1614").lerp(Color("6a645a"), t)
		Draw.rect(ci, Rect2(Vector2(st.position.x, y0), Vector2(st.size.x, st.size.y / n)), col)
		ci.draw_line(Vector2(st.position.x, y0 + st.size.y / n - 1), Vector2(st.end.x, y0 + st.size.y / n - 1), col.lightened(0.18), 1.0)
	# the door at the bottom, and its bulb
	var door := Rect2(Vector2(st.get_center().x - M(0.3), st.position.y), Vector2(M(0.6), M(0.08)))
	Draw.rect(ci, door, Color("3a2418"))
	var bulb := Vector2(st.get_center().x + M(0.36), st.position.y + M(0.06))
	if night_on:
		Draw.circle(ci, bulb, M(0.12), Color(1.0, 0.3, 0.2, 0.25))
		Draw.circle(ci, bulb, M(0.05), Color("ffb080"))
	else:
		Draw.circle(ci, bulb, M(0.04), Color("7a2a22"))
	# the railing: posts and a rail on three sides (open toward the street)
	var rail := st.grow(3.0)
	var pts := PackedVector2Array([Vector2(rail.position.x, rail.end.y), rail.position, Vector2(rail.end.x, rail.position.y), rail.end])
	var o := sh(S, 0.9)
	var shp := PackedVector2Array()
	for q in pts:
		shp.append(q + o)
	ci.draw_polyline(shp, Color(FX.SHADE, 0.22), 2.0, true)
	ci.draw_polyline(pts, IRON, 2.5, true)
	ci.draw_polyline(pts, IRON_HI, 0.8, true)
	for q in pts:
		Draw.circle(ci, q, 2.5, IRON)
	for k in range(1, 4):
		Draw.circle(ci, pts[0].lerp(pts[1], k / 4.0), 1.5, IRON)
		Draw.circle(ci, pts[2].lerp(pts[3], k / 4.0), 1.5, IRON)


## Paint one item by name.
static func paint(ci: CanvasItem, S: Dictionary, t: String, r: Rect2, rng: RandomNumberGenerator) -> void:
	match t:
		"produce": produce(ci, S, r, rng)
		"bread_rack": bread_rack(ci, S, r, rng)
		"baguette_barrel": baguette_barrel(ci, S, r, rng)
		"meat_rail": meat_rail(ci, S, r, rng)
		"chop_block": chop_block(ci, S, r, rng)
		"fish_ice": fish_ice(ci, S, r, rng)
		"oyster_barrel": oyster_barrel(ci, S, r, rng)
		"cafe_table": cafe_table(ci, S, r, rng)
		"rest_table": rest_table(ci, S, r, rng)
		"barber_pole": barber_pole(ci, S, r, rng)
		"bench": bench(ci, S, r, rng)
		"dummy": dummy(ci, S, r, rng)
		"suit_rack": suit_rack(ci, S, r, rng)
		"shoeshine": shoeshine(ci, S, r, rng)
		"junk_crate": junk_crate(ci, S, r, rng)
		"laundry_cart": laundry_cart(ci, S, r, rng)
		"bundles": bundles(ci, S, r, rng)
		"news_rack": news_rack(ci, S, r, rng)
		"brooms": brooms(ci, S, r, rng)
		"pails": pails(ci, S, r, rng)
		"gumball": gumball(ci, S, r, rng)
		"soda_crates": soda_crates(ci, S, r, rng)
		"penny_scale": penny_scale(ci, S, r, rng)
		"ash_urn": ash_urn(ci, S, r, rng)
		"planter": planter(ci, S, r, rng)
		"crates": crates(ci, S, r, rng)
