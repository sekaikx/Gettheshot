extends RefCounted
## Trade goods seen from above, drawn small and with care: loaves, cuts of meat, bolts of cloth,
## jars, bottles, fish, fruit, shoes, watches... All in the current Kit frame, sizes in px.

const Kit := preload("res://scripts/world2d/rooms/kit.gd")
const M := W.M

# colours of the goods, all shades of the city's palette
static var CRUST := Pal.ROPE.darkened(0.12)
static var CRUST_D := Pal.RUST.lightened(0.08)
static var CRUMB := Pal.AWNING_CREAM.darkened(0.04)
static var MEAT := Pal.FLOOR_TILE_2.lightened(0.12)
static var FAT := Pal.AWNING_CREAM.lightened(0.05)
static var SILVER := Pal.SKYLIGHT.lightened(0.18)
static var PAPER := Pal.PAPER
static var LEAF := Pal.AWNING_COLORS[1].lightened(0.28)
static var CLOTHS := [Pal.AWNING_COLORS[0], Pal.AWNING_COLORS[2], Pal.AWNING_COLORS[1], Pal.SUITS[1], Pal.SUITS[3],
	Pal.AWNING_COLORS[3], Pal.SUITS[2], Pal.AWNING_CREAM.darkened(0.1), Pal.AWNING_COLORS[5], Pal.AWNING_COLORS[4]]
static var BRIGHTS := [Pal.FLOOR_TILE_2.lightened(0.25), Pal.GOLD, Pal.AWNING_COLORS[1].lightened(0.35), Pal.AWNING_COLORS[2].lightened(0.35),
	Pal.GOLD2, Pal.AWNING_COLORS[4].lightened(0.35), Pal.NEON_RED.darkened(0.15), Pal.AWNING_CREAM]
static var BOTTLES := [Pal.FELT.darkened(0.15), Pal.RUST.darkened(0.1), Pal.GLASS.darkened(0.1), Pal.AWNING_COLORS[2].lightened(0.1), Pal.FELT.lightened(0.15), Pal.RUST.lightened(0.15)]


static func pick(arr: Array, k: Kit, i: int, j: int, s: int = 0) -> Color:
	return arr[int(k.h(i, j, s) * arr.size()) % arr.size()]


# ------------------------------------------------------------------ bakery

static func loaf(k: Kit, c: Vector2, len: float, wid: float, a: float, t: float = 0.5) -> void:
	var col := CRUST.lerp(CRUST_D, t * 0.6)
	k.ellipse(c + k.sh * 2.0, Vector2(len, wid) * 0.5, Color(Kit.SH_COL, 0.22), a)
	k.ellipse(c, Vector2(len, wid) * 0.5, col.darkened(0.15), a)
	k.ellipse(c + k.lit * 0.6, Vector2(len, wid) * 0.42, col, a)
	var d := Vector2.from_angle(a)
	var n := Vector2(-d.y, d.x)
	for j in 3:
		var m := c + d * (j - 1) * len * 0.24
		k.line(m - n * wid * 0.22 - d * 2.0, m + n * wid * 0.22 + d * 2.0, CRUMB.darkened(0.08), 1.2)


static func baguette(k: Kit, c: Vector2, len: float, a: float) -> void:
	loaf(k, c, len, 5.5, a, 0.2)


static func boule(k: Kit, c: Vector2, r: float, t: float = 0.5) -> void:
	var col := CRUST.lerp(CRUST_D, t * 0.7)
	k.ball(c, r, col, 2.5, 0.12)
	k.line(c + Vector2(-r * 0.5, 0), c + Vector2(r * 0.5, 0), CRUMB.darkened(0.1), 1.2)
	k.line(c + Vector2(0, -r * 0.5), c + Vector2(0, r * 0.5), CRUMB.darkened(0.1), 1.2)


static func roll(k: Kit, c: Vector2, r: float) -> void:
	k.ball(c, r, CRUST.lightened(0.05), 1.5, 0.15)


static func croissant(k: Kit, c: Vector2, sz: float, a: float) -> void:
	var col := CRUST.lightened(0.08)
	for j in 5:
		var t := (j - 2) / 2.0
		var p := c + Vector2(t * sz * 0.45, absf(t) * sz * 0.22).rotated(a)
		k.disc(p, sz * (0.2 - absf(t) * 0.06), col.darkened(0.08 * absf(t)))
	k.disc(c + k.lit * 0.5, sz * 0.12, col.lightened(0.15))


static func cannolo(k: Kit, c: Vector2, a: float) -> void:
	var d := Vector2.from_angle(a) * 5.0
	k.line(c - d, c + d, CRUST.lightened(0.1), 4.5)
	k.disc(c - d, 2.3, CRUMB)
	k.disc(c + d, 2.3, CRUMB)
	k.disc(c - d * 1.15, 0.9, Pal.FELT.lightened(0.3))


static func cookie(k: Kit, c: Vector2, r: float, t: float) -> void:
	k.disc(c, r, CRUST.lerp(CRUMB, t))
	k.disc(c + Vector2(r * 0.3, -r * 0.2), r * 0.22, Pal.RUST.darkened(0.3))


static func cake(k: Kit, c: Vector2, r: float, icing: Color, cut: bool) -> void:
	k.shadow_disc(c, r, 3.0)
	k.disc(c, r + 2.0, Pal.MARBLE.lightened(0.1))
	k.disc(c, r, icing.darkened(0.08))
	k.disc(c + k.lit * 0.8, r * 0.86, icing)
	var n := int(r * 1.2)
	for j in n:
		k.disc(c + Vector2.from_angle(TAU * j / n) * r * 0.78, 1.2, icing.lightened(0.3))
	k.disc(c, 2.0, Pal.FLOOR_TILE_2.lightened(0.2))
	if cut:
		k.poly(PackedVector2Array([c, c + Vector2(r + 0.5, -1.0), c + Vector2(r * 0.8, r * 0.62)]), CRUMB.darkened(0.05))
		k.line(c, c + Vector2(r, -1.0), Pal.FLOOR_TILE_2.lightened(0.1), 1.0)


# ------------------------------------------------------------------ butcher

static func steak(k: Kit, c: Vector2, sz: float, a: float, t: float) -> void:
	var rad := Vector2(sz * 0.6, sz * 0.42)
	k.ellipse(c, rad + Vector2(1.5, 1.5), FAT, a)
	k.ellipse(c + Vector2(0.8, 0.4).rotated(a), rad, MEAT.darkened(0.08 * t), a)
	for j in 3:
		var p := c + Vector2((j - 1) * sz * 0.25, (j % 2) * 2.0 - 1.0).rotated(a)
		k.line(p - Vector2(2, 1).rotated(a), p + Vector2(2, 1).rotated(a), Color(FAT, 0.6), 1.0)


static func chop(k: Kit, c: Vector2, sz: float, a: float) -> void:
	steak(k, c, sz, a, 0.3)
	var d := Vector2.from_angle(a)
	k.line(c + d * sz * 0.4, c + d * sz * 0.85, FAT.lightened(0.1), 2.5)


static func sausage_coil(k: Kit, c: Vector2, r: float) -> void:
	var col := Pal.RUST.lightened(0.18)
	var pts := PackedVector2Array()
	for j in 28:
		var t := j / 27.0
		pts.append(c + Vector2.from_angle(t * TAU * 2.4) * r * (0.2 + 0.8 * t))
	k.pline(pts, col.darkened(0.2), 4.5)
	k.pline(pts, col, 3.0)


static func links(k: Kit, a: Vector2, b: Vector2, n: int) -> void:
	var col := Pal.RUST.lightened(0.12)
	for j in n:
		var p := a.lerp(b, (j + 0.5) / n)
		k.ellipse(p, Vector2(a.distance_to(b) / n * 0.5, 2.3), col, (b - a).angle())
		k.disc(p + k.lit * 0.6, 1.0, col.lightened(0.25))


static func chicken(k: Kit, c: Vector2, sz: float, a: float) -> void:
	var col := Pal.AWNING_CREAM.lerp(Pal.ROPE, 0.25)
	var d := Vector2.from_angle(a)
	var n := Vector2(-d.y, d.x)
	k.ellipse(c + k.sh * 2.0, Vector2(sz * 0.55, sz * 0.4), Color(Kit.SH_COL, 0.2), a)
	k.disc(c + d * sz * 0.45 + n * sz * 0.2, sz * 0.14, col.darkened(0.1))
	k.disc(c + d * sz * 0.45 - n * sz * 0.2, sz * 0.14, col.darkened(0.1))
	k.ellipse(c, Vector2(sz * 0.5, sz * 0.36), col.darkened(0.06), a)
	k.ellipse(c + k.lit * 0.8, Vector2(sz * 0.38, sz * 0.26), col.lightened(0.08), a)


static func ham(k: Kit, c: Vector2, sz: float, a: float) -> void:
	var d := Vector2.from_angle(a)
	k.ellipse(c, Vector2(sz * 0.55, sz * 0.4), Pal.RUST.darkened(0.05), a)
	k.ellipse(c - d * sz * 0.08 + k.lit * 0.6, Vector2(sz * 0.4, sz * 0.28), Pal.RUST.lightened(0.12), a)
	k.line(c + d * sz * 0.45, c + d * sz * 0.72, FAT, 3.0)
	k.disc(c + d * sz * 0.74, 2.0, FAT.lightened(0.1))


static func salami(k: Kit, c: Vector2, len: float, a: float) -> void:
	var d := Vector2.from_angle(a) * len * 0.5
	k.line(c - d, c + d, Pal.FLOOR_TILE_2.darkened(0.35), 5.5)
	k.line(c - d * 0.9, c + d * 0.9, Pal.FLOOR_TILE_2.darkened(0.15), 3.5)
	k.line(c - d * 0.8 + k.lit, c + d * 0.3 + k.lit, Color(1, 1, 1, 0.18), 1.0)
	k.disc(c - d, 1.2, Pal.ROPE)


static func beef_side(k: Kit, c: Vector2, len: float, wid: float) -> void:
	# a hanging side of beef: long, deep red, fat cap and ribs
	var pts := PackedVector2Array()
	for j in 16:
		var t := j / 15.0
		var w := wid * (0.55 + 0.45 * sin(t * PI)) * (1.0 - 0.25 * t)
		pts.append(c + Vector2(-w * 0.5, (t - 0.5) * len))
	for j in 16:
		var t := 1.0 - j / 15.0
		var w := wid * (0.55 + 0.45 * sin(t * PI)) * (1.0 - 0.25 * t)
		pts.append(c + Vector2(w * 0.5, (t - 0.5) * len))
	k.shadow_poly(pts, 6.0, 0.3)
	k.poly(pts, MEAT.darkened(0.12))
	k.line(c + Vector2(-wid * 0.36, -len * 0.4), c + Vector2(-wid * 0.3, len * 0.35), FAT.darkened(0.05), 4.0)
	for j in 5:
		var y := c.y - len * 0.25 + j * len * 0.11
		k.line(Vector2(c.x - wid * 0.2, y), Vector2(c.x + wid * 0.35, y + 2.0), Color(FAT, 0.55), 1.5)
	k.disc(c + Vector2(0, -len * 0.5), 2.0, Pal.TRACK)


# ------------------------------------------------------------------ fish and produce

static func fish(k: Kit, c: Vector2, len: float, a: float, col: Color) -> void:
	var d := Vector2.from_angle(a)
	var n := Vector2(-d.y, d.x)
	var w := len * 0.2
	var body := PackedVector2Array()
	for j in 12:
		var t := j / 11.0
		body.append(c + d * (t - 0.5) * len * 0.8 + n * w * sin(t * PI) * (1.0 - t * 0.35))
	for j in 12:
		var t := 1.0 - j / 11.0
		body.append(c + d * (t - 0.5) * len * 0.8 - n * w * sin(t * PI) * (1.0 - t * 0.35))
	k.poly(body, col.darkened(0.1))
	k.line(c - d * len * 0.35, c + d * len * 0.3, col.darkened(0.35), 1.5)
	k.line(c - d * len * 0.3 + n * w * 0.35, c + d * len * 0.25 + n * w * 0.3, col.lightened(0.3), 1.0)
	var tail := c - d * len * 0.4
	k.poly(PackedVector2Array([tail, tail - d * len * 0.18 + n * w * 0.9, tail - d * len * 0.14, tail - d * len * 0.18 - n * w * 0.9]), col.darkened(0.2))
	k.disc(c + d * len * 0.3 + n * w * 0.25, 1.1, Pal.SIGN_BLACK)


static func fruit(k: Kit, c: Vector2, r: float, col: Color, leaf: bool = false) -> void:
	k.disc(c + k.sh * 1.2, r, Color(Kit.SH_COL, 0.25))
	k.disc(c, r, col.darkened(0.15))
	k.disc(c + k.lit * r * 0.15, r * 0.82, col)
	k.disc(c + k.lit * r * 0.42, r * 0.3, col.lightened(0.35))
	if leaf:
		k.line(c, c + Vector2(r * 0.6, -r * 0.5), LEAF, 1.5)


static func cabbage(k: Kit, c: Vector2, r: float) -> void:
	fruit(k, c, r, LEAF.lightened(0.1))
	for j in 4:
		k.ci.draw_arc(c, r * (0.35 + j * 0.15), j * 1.3, j * 1.3 + 2.2, 6, LEAF.darkened(0.2), 1.0, true)


static func pile(k: Kit, r: Rect2, what: String, s: int) -> void:
	# a heap of fruit or vegetables filling a bin, packed in a staggered grid
	var sz: float = {"apple": 3.6, "orange": 3.8, "lemon": 3.2, "potato": 3.4, "onion": 3.1, "cabbage": 6.0,
		"tomato": 3.4, "pear": 3.3, "clam": 2.8, "oyster": 3.2, "nail": 1.4}.get(what, 3.5)
	var step := sz * 1.9
	var nx := int(r.size.x / step)
	var ny := int(r.size.y / step)
	for j in ny:
		for i in nx:
			var c := r.position + Vector2((i + 0.5 + (0.5 if j % 2 == 1 else 0.0)) * step, (j + 0.5) * step)
			if c.x > r.end.x - sz * 0.8:
				continue
			c += Vector2(k.h(i, j, s) - 0.5, k.h(j, i, s) - 0.5) * sz * 0.5
			var t := k.h(i, j, s + 3)
			match what:
				"apple": fruit(k, c, sz, Pal.FLOOR_TILE_2.lightened(0.18 + t * 0.12), t > 0.7)
				"orange": fruit(k, c, sz, Pal.GOLD.lerp(Pal.RUST, 0.35 + t * 0.2))
				"lemon": fruit(k, c, sz, Pal.GOLD2.darkened(0.05 * t))
				"tomato": fruit(k, c, sz, Pal.NEON_RED.darkened(0.3 + t * 0.1), true)
				"pear": fruit(k, c, sz, Pal.AWNING_COLORS[1].lightened(0.45).lerp(Pal.GOLD2, 0.3))
				"potato": fruit(k, c, sz, Pal.ROPE.darkened(0.2 + t * 0.1))
				"onion": fruit(k, c, sz, Pal.ROPE.lerp(Pal.GOLD, 0.3).lightened(0.05))
				"cabbage": cabbage(k, c, sz)
				"clam": fruit(k, c, sz, Pal.QUAY_STONE.lightened(0.25 + t * 0.1))
				"oyster": fruit(k, c, sz, Pal.QUAY_STONE.lightened(0.05 + t * 0.2))
				"nail": k.disc(c, sz, Pal.TRACK.lightened(0.1 + t * 0.2))
				_: fruit(k, c, sz, Pal.GOLD)


# ------------------------------------------------------------------ packaged goods

static func can(k: Kit, c: Vector2, r: float, label: Color) -> void:
	k.disc(c + k.sh * 1.2, r, Color(Kit.SH_COL, 0.22))
	k.disc(c, r, label.darkened(0.12))
	k.disc(c, r * 0.72, Pal.TRACK.lightened(0.2))
	k.disc(c + k.lit * r * 0.2, r * 0.3, Color(1, 1, 1, 0.45))


static func box(k: Kit, r: Rect2, col: Color, label: bool = true) -> void:
	k.rect(Rect2(r.position + k.sh * 1.5, r.size), Color(Kit.SH_COL, 0.2))
	k.rect(r, col)
	k.edges(r, col, 1.0, 0.18, 0.25)
	if label and r.size.x > 5 and r.size.y > 4:
		k.rect(Rect2(r.position.x + r.size.x * 0.2, r.position.y + r.size.y * 0.35, r.size.x * 0.6, r.size.y * 0.3), Pal.AWNING_CREAM)


static func jar(k: Kit, c: Vector2, r: float, fill: Color) -> void:
	k.disc(c + k.sh * 1.5, r, Color(Kit.SH_COL, 0.22))
	k.disc(c, r, Color(Pal.GLASS.lightened(0.1), 0.9))
	k.disc(c, r * 0.82, fill)
	var n := 5
	for j in n:
		k.disc(c + Vector2.from_angle(j * TAU / n + r) * r * 0.5, r * 0.18, fill.lightened(0.25))
	k.disc(c, r * 0.5, Pal.BRASS if r > 4.0 else Pal.TRACK)
	k.disc(c + k.lit * r * 0.2, r * 0.18, Color(1, 1, 1, 0.5))


static func bottle(k: Kit, c: Vector2, r: float, col: Color) -> void:
	k.disc(c + k.sh * 1.4, r, Color(Kit.SH_COL, 0.25))
	k.disc(c, r, col.darkened(0.2))
	k.disc(c + k.lit * r * 0.12, r * 0.8, col)
	k.disc(c, r * 0.36, col.darkened(0.35))
	k.disc(c, r * 0.22, Pal.ROPE if col.v < 0.5 else Pal.TRACK)
	k.disc(c + k.lit * r * 0.5, r * 0.18, Color(1, 1, 1, 0.55))


static func glass_cup(k: Kit, c: Vector2, r: float, drink: Color = Color(0, 0, 0, 0)) -> void:
	k.disc(c + k.sh, r, Color(Kit.SH_COL, 0.18))
	k.disc(c, r, Color(Pal.GLASS.lightened(0.3), 0.8))
	if drink.a > 0.0:
		k.disc(c, r * 0.7, drink)
	k.ring(c, r, Color(1, 1, 1, 0.7), 1.0)


static func cup(k: Kit, c: Vector2, r: float) -> void:
	k.disc(c + k.sh, r * 1.5, Color(Kit.SH_COL, 0.18))
	k.disc(c, r * 1.5, Pal.AWNING_CREAM.lightened(0.1))
	k.disc(c, r, Pal.AWNING_CREAM.lightened(0.2))
	k.disc(c, r * 0.72, Pal.COUNTER.darkened(0.3))
	k.line(c + Vector2(r * 0.9, 0), c + Vector2(r * 1.4, 0), Pal.AWNING_CREAM, 1.5)


static func plate(k: Kit, c: Vector2, r: float, food: Color = Color(0, 0, 0, 0)) -> void:
	k.disc(c + k.sh, r, Color(Kit.SH_COL, 0.16))
	k.disc(c, r, Pal.AWNING_CREAM.lightened(0.15))
	k.ring(c, r * 0.7, Pal.AWNING_CREAM.darkened(0.08), 1.0)
	if food.a > 0.0:
		k.disc(c + Vector2(0.5, 0), r * 0.45, food)


static func bolt(k: Kit, r: Rect2, col: Color, along_x: bool) -> void:
	k.rect(Rect2(r.position + k.sh * 1.5, r.size), Color(Kit.SH_COL, 0.22))
	k.rect(r, col)
	k.edges(r, col, 1.5, 0.2, 0.3)
	var segs := PackedVector2Array()
	if along_x:
		var t := 3.0
		while t < r.size.x - 1.0:
			segs.append_array([Vector2(r.position.x + t, r.position.y + 1), Vector2(r.position.x + t, r.end.y - 1)])
			t += 3.0
	else:
		var t2 := 3.0
		while t2 < r.size.y - 1.0:
			segs.append_array([Vector2(r.position.x + 1, r.position.y + t2), Vector2(r.end.x - 1, r.position.y + t2)])
			t2 += 3.0
	k.lines(segs, Color(col.darkened(0.25), 0.6), 1.0)


static func shoe(k: Kit, c: Vector2, len: float, a: float, col: Color) -> void:
	var d := Vector2.from_angle(a)
	k.ellipse(c + k.sh * 1.2, Vector2(len * 0.5, len * 0.2), Color(Kit.SH_COL, 0.22), a)
	k.ellipse(c + d * len * 0.12, Vector2(len * 0.38, len * 0.19), col, a)
	k.ellipse(c - d * len * 0.3, Vector2(len * 0.17, len * 0.15), col.darkened(0.15), a)
	k.ellipse(c + d * len * 0.02, Vector2(len * 0.16, len * 0.1), col.darkened(0.45), a)
	k.disc(c + d * len * 0.3 + k.lit, len * 0.06, col.lightened(0.3))


static func pair(k: Kit, c: Vector2, len: float, a: float, col: Color) -> void:
	var n := Vector2(-sin(a), cos(a))
	shoe(k, c - n * len * 0.22, len, a, col)
	shoe(k, c + n * len * 0.22, len, a, col)


static func bundle(k: Kit, r: Rect2, t: float) -> void:
	var col := Pal.ROPE.lerp(Pal.PAPER, 0.35 + t * 0.3)
	k.rect(Rect2(r.position + k.sh * 1.5, r.size), Color(Kit.SH_COL, 0.2))
	k.rect(r, col)
	k.edges(r, col, 1.0)
	var c := r.get_center()
	k.line(Vector2(r.position.x, c.y), Vector2(r.end.x, c.y), Pal.FLOOR_TILE_2.darkened(0.1), 1.0)
	k.line(Vector2(c.x, r.position.y), Vector2(c.x, r.end.y), Pal.FLOOR_TILE_2.darkened(0.1), 1.0)
	k.rect(Rect2(c + Vector2(1, 1), Vector2(3, 2)), Pal.AWNING_CREAM.lightened(0.2))


static func tin(k: Kit, r: Rect2, col: Color) -> void:
	k.rrect(Rect2(r.position + k.sh, r.size), 1.5, Color(Kit.SH_COL, 0.2))
	k.rrect(r, 1.5, col)
	k.rrect(r.grow(-1.2), 1.0, col.lightened(0.15))
	k.line(r.position + Vector2(2, r.size.y * 0.5), Vector2(r.end.x - 2, r.position.y + r.size.y * 0.5), Pal.SIGN_GOLD, 1.0)


static func cigarbox(k: Kit, r: Rect2, open: bool, t: float) -> void:
	var wood := Pal.COUNTER.lightened(0.15 + t * 0.1)
	box(k, r, wood, false)
	if open:
		var inner := r.grow(-1.5)
		k.rect(inner, wood.darkened(0.3))
		var n := int(inner.size.x / 3.5)
		for j in n:
			var x := inner.position.x + (j + 0.5) * inner.size.x / n
			k.line(Vector2(x, inner.position.y + 1), Vector2(x, inner.end.y - 1), Pal.RUST.lerp(Pal.COUNTER, 0.3), 2.6)
			k.line(Vector2(x, inner.position.y + inner.size.y * 0.3), Vector2(x, inner.position.y + inner.size.y * 0.45), Pal.SIGN_GOLD, 2.6)
	else:
		k.rect(Rect2(r.position.x + r.size.x * 0.25, r.position.y + r.size.y * 0.25, r.size.x * 0.5, r.size.y * 0.5), Pal.FLOOR_TILE_2.lightened(0.1))
		k.ring(r.get_center(), minf(r.size.x, r.size.y) * 0.18, Pal.SIGN_GOLD, 1.0)


static func watch(k: Kit, c: Vector2, r: float, a: float) -> void:
	var d := Vector2.from_angle(a)
	k.line(c - d * r * 2.4, c + d * r * 2.4, Pal.LEATHER.lightened(0.1), r * 0.9)
	k.disc(c, r + 0.8, Pal.BRASS.darkened(0.1))
	k.disc(c, r, Pal.AWNING_CREAM.lightened(0.2))
	k.line(c, c + Vector2(0, -r * 0.7), Pal.SIGN_BLACK, 1.0)
	k.line(c, c + Vector2(r * 0.5, 0.2), Pal.SIGN_BLACK, 1.0)


static func pocket_watch(k: Kit, c: Vector2, r: float) -> void:
	k.disc(c, r + 1.0, Pal.GOLD)
	k.disc(c, r, Pal.AWNING_CREAM.lightened(0.2))
	k.disc(c + Vector2(0, -r - 1.5), 1.2, Pal.GOLD)
	k.line(c, c + Vector2(0, -r * 0.7), Pal.SIGN_BLACK, 1.0)
	k.line(c, c + Vector2(r * 0.45, r * 0.2), Pal.SIGN_BLACK, 1.0)
	var pts := PackedVector2Array()
	for j in 8:
		pts.append(c + Vector2(r + 1.5 + j * 1.2, -r - 1.5 + sin(j) * 1.5))
	k.pline(pts, Pal.GOLD.darkened(0.1), 1.0)


static func gem_ring(k: Kit, c: Vector2, col: Color) -> void:
	k.ring(c, 2.3, Pal.GOLD, 1.2)
	k.disc(c + Vector2(0, -2.3), 1.3, col)
	k.disc(c + Vector2(-0.4, -2.7), 0.5, Color(1, 1, 1, 0.8))


static func necklace(k: Kit, c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for j in 17:
		var t := PI * 0.15 + j / 16.0 * PI * 0.7
		pts.append(c + Vector2(cos(t) * r, sin(t) * r * 0.8))
	for q in pts:
		k.disc(q, 1.0, col)
	k.disc(pts[8] + Vector2(0, 1.8), 1.8, Pal.FLOOR_TILE_2.lightened(0.2))


static func clock(k: Kit, c: Vector2, r: float) -> void:
	k.ball(c, r + 1.5, Pal.COUNTER.lightened(0.2), 3.0, 0.1)
	k.disc(c, r, Pal.AWNING_CREAM.lightened(0.15))
	for j in 12:
		k.disc(c + Vector2.from_angle(j * TAU / 12.0) * r * 0.8, 0.5, Pal.SIGN_BLACK)
	k.line(c, c + Vector2(0, -r * 0.65), Pal.SIGN_BLACK, 1.2)
	k.line(c, c + Vector2(r * 0.45, r * 0.15), Pal.SIGN_BLACK, 1.2)


static func towel(k: Kit, r: Rect2) -> void:
	k.rrect(Rect2(r.position + k.sh * 1.2, r.size), 2.0, Color(Kit.SH_COL, 0.2))
	k.rrect(r, 2.0, Pal.AWNING_CREAM.lightened(0.15))
	k.line(Vector2(r.position.x + 2, r.position.y + r.size.y * 0.33), Vector2(r.end.x - 2, r.position.y + r.size.y * 0.33), Pal.AWNING_CREAM.darkened(0.1), 1.0)
	k.line(Vector2(r.position.x + 2, r.position.y + r.size.y * 0.66), Vector2(r.end.x - 2, r.position.y + r.size.y * 0.66), Pal.AWNING_CREAM.darkened(0.1), 1.0)


static func sack(k: Kit, c: Vector2, sz: Vector2, a: float, col: Color) -> void:
	var r := Rect2(-sz * 0.5, sz)
	var pts := Draw.rrect_points(r, minf(sz.x, sz.y) * 0.35, 3)
	var t := Transform2D(a, c)
	var q := PackedVector2Array()
	for p in pts:
		q.append(t * p)
	k.shadow_poly(q, 4.0, 0.25)
	k.poly(q, col)
	var q2 := PackedVector2Array()
	for p in Draw.rrect_points(r.grow(-2.5), minf(sz.x, sz.y) * 0.3, 3):
		q2.append(t * (p + k.lit.rotated(-a) * 0.8))
	k.poly(q2, col.lightened(0.08))
	k.line(t * Vector2(-sz.x * 0.25, 0), t * Vector2(sz.x * 0.25, 0), col.darkened(0.25), 1.0)
	k.line(t * Vector2(sz.x * 0.38, -sz.y * 0.3), t * Vector2(sz.x * 0.5, -sz.y * 0.38), col.darkened(0.3), 2.0)


static func paper(k: Kit, r: Rect2, a: float = 0.0, lines_n: int = 3) -> void:
	var t := Transform2D(a, r.get_center())
	var h := r.size * 0.5
	var pts := PackedVector2Array([t * Vector2(-h.x, -h.y), t * Vector2(h.x, -h.y), t * Vector2(h.x, h.y), t * Vector2(-h.x, h.y)])
	k.shadow_poly(pts, 1.0, 0.18)
	k.poly(pts, Pal.PAPER.lightened(0.08))
	for j in lines_n:
		var y := -h.y + (j + 1.0) * r.size.y / (lines_n + 1.0)
		k.line(t * Vector2(-h.x * 0.75, y), t * Vector2(h.x * (0.75 if j < lines_n - 1 else 0.3), y), Color(Pal.PAPER_INK, 0.45), 1.0)


static func newspaper(k: Kit, r: Rect2, a: float, t: float) -> void:
	paper(k, r, a, 0)
	var tr := Transform2D(a, r.get_center())
	var h := r.size * 0.5
	k.line(tr * Vector2(-h.x * 0.8, -h.y * 0.62), tr * Vector2(h.x * 0.8, -h.y * 0.62), Pal.PAPER_INK, 2.0)
	for j in 4:
		var x := -h.x * 0.8 + j * h.x * 0.42
		k.line(tr * Vector2(x, -h.y * 0.3), tr * Vector2(x, h.y * 0.8), Color(Pal.PAPER_INK, 0.35), 1.0)
	if t > 0.5:
		k.rect(Rect2(tr * Vector2(h.x * 0.1, -h.y * 0.35), Vector2(h.x * 0.55, h.y * 0.5)), Color(Pal.PAPER_INK, 0.35))


static func card(k: Kit, c: Vector2, a: float, red: bool) -> void:
	var t := Transform2D(a, c)
	var pts := PackedVector2Array([t * Vector2(-2.4, -3.4), t * Vector2(2.4, -3.4), t * Vector2(2.4, 3.4), t * Vector2(-2.4, 3.4)])
	k.poly(pts, Pal.AWNING_CREAM.lightened(0.2))
	k.disc(c, 1.0, Pal.FLOOR_TILE_2.lightened(0.1) if red else Pal.SIGN_BLACK)


static func chips(k: Kit, c: Vector2, col: Color, n: int) -> void:
	k.disc(c + k.sh * 1.0 * n * 0.5, 3.0, Color(Kit.SH_COL, 0.25))
	k.disc(c, 3.0, col)
	k.ring(c, 2.0, Pal.AWNING_CREAM, 1.0)
	k.disc(c + k.lit * 0.8, 1.0, col.lightened(0.3))


static func cash(k: Kit, c: Vector2, a: float) -> void:
	var t := Transform2D(a, c)
	var pts := PackedVector2Array([t * Vector2(-5, -2.5), t * Vector2(5, -2.5), t * Vector2(5, 2.5), t * Vector2(-5, 2.5)])
	k.poly(pts, Pal.AWNING_COLORS[1].lightened(0.45))
	k.disc(c, 1.2, Pal.AWNING_COLORS[1].darkened(0.1))


static func coin(k: Kit, c: Vector2) -> void:
	k.disc(c, 1.6, Pal.TRACK.lightened(0.3))
	k.disc(c + Vector2(-0.4, -0.4), 0.6, Color(1, 1, 1, 0.6))


static func candy(k: Kit, r: Rect2, s: int) -> void:
	var n := int(r.size.x * r.size.y / 14.0)
	for j in n:
		var p := r.position + Vector2(k.h(j, 1, s), k.h(j, 2, s)) * r.size
		var col: Color = BRIGHTS[j % BRIGHTS.size()]
		if j % 3 == 0:
			k.ellipse(p, Vector2(2.2, 1.3), col, k.h(j, 3, s) * PI)
			k.disc(p + Vector2(2.4, 0).rotated(k.h(j, 3, s) * PI), 0.8, col.lightened(0.3))
		else:
			k.disc(p, 1.3, col)


static func ashtray(k: Kit, c: Vector2, cigar: bool) -> void:
	k.disc(c + k.sh, 3.5, Color(Kit.SH_COL, 0.2))
	k.disc(c, 3.5, Pal.GLASS.darkened(0.15))
	k.disc(c, 2.3, Pal.QUAY_STONE.darkened(0.2))
	if cigar:
		k.line(c, c + Vector2(6, -2), Pal.RUST.darkened(0.25), 2.4)
		k.disc(c + Vector2(6, -2), 1.0, Pal.QUAY_STONE.lightened(0.2))


static func gun(k: Kit, c: Vector2, len: float, a: float, tommy: bool) -> void:
	var d := Vector2.from_angle(a)
	var n := Vector2(-d.y, d.x)
	var steel := Pal.MANHOLE.lightened(0.1)
	var wood := Pal.COUNTER.lightened(0.18)
	k.line(c - d * len * 0.5 + k.sh * 2.0, c + d * len * 0.5 + k.sh * 2.0, Color(Kit.SH_COL, 0.25), 4.0)
	k.line(c - d * len * 0.5, c - d * len * 0.1, wood, 4.0)
	k.line(c - d * len * 0.12, c + d * len * 0.5, steel, 2.2)
	if tommy:
		k.disc(c + d * len * 0.05 + n * 3.0, 4.5, steel.lightened(0.05))
		k.ring(c + d * len * 0.05 + n * 3.0, 3.0, steel.lightened(0.25), 1.0)
		k.line(c + d * len * 0.25, c + d * len * 0.25 - n * 3.0, wood, 2.5)
	k.line(c + d * len * 0.1, c + d * len * 0.45, steel.lightened(0.3), 0.8)


static func pistol(k: Kit, c: Vector2, a: float) -> void:
	var d := Vector2.from_angle(a)
	var n := Vector2(-d.y, d.x)
	k.line(c - d * 3.0, c + d * 6.0, Pal.MANHOLE.lightened(0.1), 2.6)
	k.line(c - d * 2.5, c - d * 2.5 + n * 4.5, Pal.COUNTER.lightened(0.15), 2.6)


static func ball(k: Kit, c: Vector2, r: float, col: Color, stripe: bool) -> void:
	k.disc(c + k.sh * 1.2, r, Color(Kit.SH_COL, 0.3))
	k.disc(c, r, col if not stripe else Pal.AWNING_CREAM.lightened(0.2))
	if stripe:
		k.rect(Rect2(c.x - r, c.y - r * 0.45, r * 2.0, r * 0.9), col)
	k.disc(c + k.lit * r * 0.4, r * 0.32, Color(1, 1, 1, 0.55))
