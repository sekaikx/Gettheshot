extends RefCounted
## Small things: the goods on shelves and counters, bottles, jars, loaves, cigars, bolts of cloth...
## Every function draws into an MB (mb.gd) at `p` in the current frame.

const MB := preload("res://scripts/world3d/rooms/mb.gd")

const WOOD := Color("6a4630")
const WOOD_L := Color("7e5c3c")
const WOOD_D := Color("45291c")
const OAK := Color("9a7a56")
const MAHOG := Color("5e2c22")
const BRASS := Color("d2aa4a")
const IRON := Color("3a3a3e")
const STEEL := Color("9ca0a4")
const ENAMEL := Color("ece5d2")
const CREAM := Color("e9dfc7")
const GREEN := Color("2f5a3a")
const FELT := Color("2c6a40")
const OXBLOOD := Color("6a1f1c")
const GLASS := Color(0.72, 0.86, 0.9, 0.3)
const SILVER := Color("b8c2c8")
const CLOTHS := [Color("7a2e2a"), Color("2e4a3a"), Color("2a3a5a"), Color("8a6a2a"), Color("5a3a5a"), Color("3a5a5a"), Color("b09a74"), Color("4a4a4e")]
const BRIGHTS := [Color("c8402e"), Color("2e7a58"), Color("d6a032"), Color("3a5a96"), Color("a0407a"), Color("e0d2a8")]
const BOTTLES := [Color("3a6a3c"), Color("7a4a1e"), Color("c9a54a"), Color("5a2a2a"), Color("2a4a6a"), Color("8aa890")]


static func hf(i: int, j: int, s: int) -> float:
	return Draw.hash01(i, j, s)


static func pick(arr: Array, i: int, j: int, s: int) -> Color:
	return arr[int(hf(i, j, s) * arr.size()) % arr.size()]


# ------------------------------------------------------------------ vessels

static func bottle(mb: MB, p: Vector3, col: Color, h: float = 0.26, r: float = 0.034) -> void:
	mb.cyl(p + Vector3(0, h * 0.32, 0), r, h * 0.64, col, "s", 7, r)
	mb.cyl(p + Vector3(0, h * 0.64 + h * 0.18, 0), r * 0.42, h * 0.36, col, "s", 6, r * 0.34)
	mb.cyl(p + Vector3(0, h * 0.97, 0), r * 0.4, h * 0.05, BRASS, "m", 6)


static func label_bottle(mb: MB, p: Vector3, col: Color, lab: Color, h: float = 0.28, r: float = 0.036) -> void:
	bottle(mb, p, col, h, r)
	mb.cyl(p + Vector3(0, h * 0.32, 0), r * 1.03, h * 0.2, lab, "s", 7, r * 1.03, false)


static func jar(mb: MB, p: Vector3, fill: Color, h: float = 0.2, r: float = 0.06) -> void:
	mb.cyl(p + Vector3(0, h * 0.5, 0), r * 0.92, h * 0.84, fill, "s", 8)
	mb.cyl(p + Vector3(0, h * 0.5, 0), r, h * 0.9, GLASS, "g", 8, -1.0, false)
	mb.cyl(p + Vector3(0, h * 0.96, 0), r * 0.9, h * 0.08, BRASS, "m", 8)


static func glass_cup(mb: MB, p: Vector3, drink: Color = Color(0, 0, 0, 0), r: float = 0.03) -> void:
	mb.cyl(p + Vector3(0, 0.04, 0), r, 0.08, GLASS, "g", 7, r * 1.25, false)
	if drink.a > 0.0:
		mb.cyl(p + Vector3(0, 0.025, 0), r * 0.85, 0.05, drink, "s", 7)


static func cup(mb: MB, p: Vector3, r: float = 0.035, col: Color = ENAMEL) -> void:
	mb.cyl(p + Vector3(0, 0.03, 0), r, 0.06, col, "s", 8, r * 1.15)
	mb.cyl(p + Vector3(0, 0.058, 0), r * 0.8, 0.004, Color("3a2216"), "s", 8)


static func plate(mb: MB, p: Vector3, r: float = 0.11, food: Color = Color(0, 0, 0, 0)) -> void:
	mb.cyl(p + Vector3(0, 0.008, 0), r, 0.016, ENAMEL, "s", 10, r * 0.85)
	if food.a > 0.0:
		mb.sph(p + Vector3(0, 0.02, 0), r * 0.55, food, "s", 6, 3, 0.45)


static func can(mb: MB, p: Vector3, col: Color, h: float = 0.12, r: float = 0.035) -> void:
	mb.cyl(p + Vector3(0, h * 0.5, 0), r, h, col, "s", 7)
	mb.cyl(p + Vector3(0, h * 0.5, 0), r * 1.02, h * 0.25, CREAM, "s", 7, -1.0, false)


static func box(mb: MB, p: Vector3, sz: Vector3, col: Color, yaw: float = 0.0) -> void:
	mb.at(p, yaw)
	mb.box(Vector3(0, sz.y * 0.5, 0), sz, col, "s")
	mb.box(Vector3(0, sz.y * 0.5, 0), sz * Vector3(1.01, 0.28, 1.01), CREAM.darkened(0.05), "s")
	mb.pop()


static func tin(mb: MB, p: Vector3, col: Color) -> void:
	mb.cyl(p + Vector3(0, 0.05, 0), 0.05, 0.1, col, "m", 8)
	mb.cyl(p + Vector3(0, 0.05, 0), 0.052, 0.04, CREAM, "s", 8, -1.0, false)


static func book(mb: MB, p: Vector3, yaw: float, col: Color, sz := Vector3(0.18, 0.025, 0.12)) -> void:
	mb.at(p, yaw)
	mb.box(Vector3(0, sz.y * 0.5, 0), sz, col, "s")
	mb.box(Vector3(0, sz.y * 0.5, sz.z * 0.0), Vector3(sz.x * 0.94, sz.y * 0.8, sz.z * 1.02), CREAM, "s")
	mb.pop()


static func paper(mb: MB, p: Vector3, yaw: float, sz := Vector3(0.2, 0.004, 0.27), col: Color = Color("e9e1c8")) -> void:
	mb.at(p, yaw)
	mb.box(Vector3(0, sz.y * 0.5, 0), sz, col, "s")
	mb.pop()


static func ashtray(mb: MB, p: Vector3, cigar: bool = false) -> void:
	mb.cyl(p + Vector3(0, 0.012, 0), 0.05, 0.024, Color("5a6a6a"), "s", 8)
	if cigar:
		mb.rod(p + Vector3(-0.03, 0.03, 0.0), p + Vector3(0.05, 0.034, 0.02), 0.009, Color("5a3a1e"), "s", 5)
		mb.sph(p + Vector3(-0.03, 0.03, 0.0), 0.008, Color("ff7a30"), "e", 4, 3)


# ------------------------------------------------------------------ bakery

static func loaf(mb: MB, p: Vector3, yaw: float = 0.0, ln: float = 0.34) -> void:
	mb.atx(p + Vector3(0, 0.045, 0), yaw, Vector3(0.5, 0.55, 1.0))
	mb.sph(Vector3.ZERO, ln * 0.5, Color("c88a44"), "s", 8, 5, 0.75)
	mb.pop()
	mb.at(p + Vector3(0, 0.08, 0), yaw)
	for k in 3:
		mb.box(Vector3(0, 0, (k - 1) * ln * 0.25), Vector3(0.05, 0.006, 0.012), Color("e8c88a"), "s")
	mb.pop()


static func baguette(mb: MB, p: Vector3, yaw: float, ln: float = 0.5) -> void:
	var d := Vector3(sin(yaw), 0, cos(yaw))
	mb.cyl_dir(p + Vector3(0, 0.03, 0), d, 0.028, ln, Color("c48a46"), "s", 6)


static func boule(mb: MB, p: Vector3, r: float = 0.09) -> void:
	mb.sph(p + Vector3(0, r * 0.55, 0), r, Color("b87a3c"), "s", 8, 5, 0.7)
	mb.box(p + Vector3(0, r * 1.1, 0), Vector3(r * 0.9, 0.006, 0.012), Color("e6c488"), "s")


static func roll(mb: MB, p: Vector3, r: float = 0.05) -> void:
	mb.sph(p + Vector3(0, r * 0.6, 0), r, Color("c48a46"), "s", 6, 4, 0.75)


static func croissant(mb: MB, p: Vector3, yaw: float = 0.0) -> void:
	mb.at(p, yaw)
	mb.sph(Vector3(0, 0.03, 0), 0.04, Color("d09a4a"), "s", 6, 4, 0.8)
	mb.sph(Vector3(-0.045, 0.026, 0.02), 0.03, Color("c48a3c"), "s", 6, 4, 0.8)
	mb.sph(Vector3(0.045, 0.026, 0.02), 0.03, Color("c48a3c"), "s", 6, 4, 0.8)
	mb.pop()


static func cake(mb: MB, p: Vector3, r: float = 0.13, icing: Color = Color("f2e6d0"), cut: bool = false) -> void:
	mb.cyl(p + Vector3(0, 0.05, 0), r, 0.1, Color("8a5a34"), "s", 12)
	mb.cyl(p + Vector3(0, 0.105, 0), r * 1.02, 0.02, icing, "s", 12)
	mb.sph(p + Vector3(0, 0.13, 0), 0.022, Color("b8282a"), "s", 6, 4)
	if cut:
		mb.box(p + Vector3(r * 0.5, 0.06, 0), Vector3(r * 1.0, 0.13, 0.05), Color("1a1a1a"), "dim")


static func pie(mb: MB, p: Vector3, r: float = 0.11) -> void:
	mb.cyl(p + Vector3(0, 0.025, 0), r, 0.05, Color("c8944c"), "s", 12, r * 0.9)
	mb.cyl(p + Vector3(0, 0.05, 0), r * 0.75, 0.01, Color("a8643a"), "s", 12)


static func cannolo(mb: MB, p: Vector3, yaw: float) -> void:
	var d := Vector3(sin(yaw), 0, cos(yaw))
	mb.cyl_dir(p + Vector3(0, 0.025, 0), d, 0.024, 0.13, Color("c8944c"), "s", 6)
	mb.cyl_dir(p + Vector3(0, 0.025, 0) + d * 0.066, d, 0.02, 0.01, Color("f4ecd8"), "s", 6)


# ------------------------------------------------------------------ butcher, fish, grocer

static func steak(mb: MB, p: Vector3, yaw: float = 0.0) -> void:
	mb.at(p, yaw)
	mb.box(Vector3(0, 0.014, 0), Vector3(0.15, 0.028, 0.1), Color("a8282a"), "s")
	mb.box(Vector3(0.04, 0.03, 0.0), Vector3(0.05, 0.006, 0.09), Color("f0e6d6"), "s")
	mb.pop()


static func chop(mb: MB, p: Vector3, yaw: float = 0.0) -> void:
	mb.at(p, yaw)
	mb.box(Vector3(0, 0.016, 0), Vector3(0.1, 0.032, 0.08), Color("c0585a"), "s")
	mb.box(Vector3(0.0, 0.034, -0.03), Vector3(0.1, 0.01, 0.014), Color("f0e6d6"), "s")
	mb.pop()


static func links(mb: MB, a: Vector3, b: Vector3, n: int) -> void:
	for k in n:
		var t := (float(k) + 0.5) / float(n)
		var p := a.lerp(b, t) + Vector3(0, -0.04 * sin(t * PI), 0)
		mb.sph(p, 0.034, Color("a8442e"), "s", 6, 4, 1.4)


static func chicken(mb: MB, p: Vector3, yaw: float = 0.0) -> void:
	mb.at(p, yaw)
	mb.atx(Vector3(0, 0.05, 0), 0.0, Vector3(1.0, 0.7, 1.2))
	mb.sph(Vector3.ZERO, 0.07, Color("e0b48a"), "s", 7, 4)
	mb.pop()
	mb.sph(Vector3(0, 0.07, 0.07), 0.025, Color("d89a6a"), "s", 5, 3)
	mb.pop()


static func ham(mb: MB, p: Vector3, yaw: float = 0.0) -> void:
	mb.at(p, yaw)
	mb.atx(Vector3(0, 0.06, 0), 0.0, Vector3(1.0, 0.8, 1.35))
	mb.sph(Vector3.ZERO, 0.075, Color("c46a60"), "s", 8, 5)
	mb.pop()
	mb.cyl(Vector3(0, 0.05, -0.1), 0.014, 0.05, Color("e8dcc0"), "s", 5)
	mb.pop()


static func salami(mb: MB, p: Vector3, ln: float = 0.34) -> void:
	mb.cyl_dir(p, Vector3(0, -1, 0), 0.034, ln, Color("7a3a2a"), "s", 7)
	mb.cyl(p + Vector3(0, ln * 0.5 + 0.1, 0), 0.004, 0.2, Color("b09a74"), "s", 4)
	mb.cyl(p + Vector3(0, ln * 0.5 + 0.015, 0), 0.016, 0.03, Color("b09a74"), "s", 5)


static func beef_side(mb: MB, p: Vector3, yaw: float = 0.0) -> void:
	mb.at(p, yaw)
	mb.box(Vector3(0, -0.45, 0), Vector3(0.3, 0.9, 0.12), Color("a82a2c"), "s")
	mb.box(Vector3(0.0, -0.45, 0.062), Vector3(0.08, 0.84, 0.01), Color("f0e6d6"), "s")
	mb.box(Vector3(0.1, -0.2, 0.062), Vector3(0.06, 0.4, 0.01), Color("f0e6d6"), "s")
	mb.box(Vector3(0, 0.0, 0), Vector3(0.34, 0.03, 0.14), IRON, "m")
	mb.pop()


static func fish(mb: MB, p: Vector3, yaw: float = 0.0, col: Color = SILVER) -> void:
	mb.at(p, yaw)
	mb.atx(Vector3(0, 0.03, 0), 0.0, Vector3(0.45, 0.4, 1.0))
	mb.sph(Vector3.ZERO, 0.11, col, "m", 7, 4)
	mb.pop()
	mb.tri(Vector3(0, 0.03, -0.11), Vector3(0.05, 0.03, -0.17), Vector3(-0.05, 0.03, -0.17), col.darkened(0.2), "s")
	mb.tri(Vector3(0, 0.03, -0.11), Vector3(-0.05, 0.03, -0.17), Vector3(0.05, 0.03, -0.17), col.darkened(0.2), "s")
	mb.sph(Vector3(0, 0.045, 0.08), 0.01, Color("101010"), "s", 4, 3)
	mb.pop()


static func fruit(mb: MB, p: Vector3, r: float, col: Color) -> void:
	mb.sph(p + Vector3(0, r * 0.9, 0), r, col, "s", 6, 4)


static func cabbage(mb: MB, p: Vector3, r: float = 0.1) -> void:
	mb.sph(p + Vector3(0, r * 0.8, 0), r, Color("8aa860"), "s", 7, 4, 0.9)
	mb.sph(p + Vector3(0, r * 0.95, 0), r * 0.7, Color("a8c07a"), "s", 6, 3, 0.85)


## A heap of produce filling a rect (x0..x1, z0..z1) on top of height y.
static func heap(mb: MB, x0: float, z0: float, x1: float, z1: float, y: float, what: String, s: int) -> void:
	var cols := {"apple": Color("b8282a"), "orange": Color("e08a28"), "lemon": Color("e8d048"), "pear": Color("a8b848"),
		"tomato": Color("c83a28"), "potato": Color("b09064"), "onion": Color("c8a064"), "cabbage": Color("8aa860"),
		"carrot": Color("e07a28")}
	var col: Color = cols.get(what, Color("b8282a"))
	var nx := maxi(2, int((x1 - x0) / 0.1))
	var nz := maxi(2, int((z1 - z0) / 0.1))
	for i in nx:
		for j in nz:
			var px := x0 + (float(i) + 0.5 + (hf(i, j, s) - 0.5) * 0.4) * (x1 - x0) / nx
			var pz := z0 + (float(j) + 0.5 + (hf(j, i, s + 1) - 0.5) * 0.4) * (z1 - z0) / nz
			var r := 0.04 + hf(i, j, s + 2) * 0.012
			if what == "cabbage":
				cabbage(mb, Vector3(px, y, pz), 0.07)
			else:
				mb.sph(Vector3(px, y + r * 0.8, pz), r, col.lightened(0.08 * hf(i, j, s + 3)), "s", 5, 3)


# ------------------------------------------------------------------ cloth, leather, laundry

static func bolt(mb: MB, p: Vector3, along_x: bool, col: Color, ln: float = 0.4, r: float = 0.07) -> void:
	var d := Vector3(1, 0, 0) if along_x else Vector3(0, 0, 1)
	mb.cyl_dir(p + Vector3(0, r, 0), d, r, ln, col, "s", 8)
	mb.cyl_dir(p + Vector3(0, r, 0), d, r * 0.4, ln * 1.04, Color("e8dcc0"), "s", 5)


static func shoe(mb: MB, p: Vector3, yaw: float, col: Color) -> void:
	mb.at(p, yaw)
	mb.box(Vector3(0, 0.012, 0.0), Vector3(0.075, 0.024, 0.22), col.darkened(0.45), "s")
	mb.box(Vector3(0, 0.045, 0.03), Vector3(0.07, 0.05, 0.14), col, "s")
	mb.box(Vector3(0, 0.07, -0.05), Vector3(0.065, 0.08, 0.07), col, "s")
	mb.box(Vector3(0, 0.012, -0.095), Vector3(0.07, 0.03, 0.04), col.darkened(0.55), "s")
	mb.pop()


static func pair(mb: MB, p: Vector3, yaw: float, col: Color) -> void:
	var s := Vector3(cos(yaw), 0, -sin(yaw)) * 0.05
	shoe(mb, p - s, yaw, col)
	shoe(mb, p + s, yaw, col)


static func bundle(mb: MB, p: Vector3, yaw: float = 0.0, col: Color = Color("e8e0d0")) -> void:
	mb.at(p, yaw)
	mb.box(Vector3(0, 0.07, 0), Vector3(0.28, 0.14, 0.2), col, "s")
	mb.box(Vector3(0, 0.07, 0), Vector3(0.02, 0.15, 0.21), Color("b09a74"), "s")
	mb.box(Vector3(0, 0.07, 0), Vector3(0.29, 0.15, 0.02), Color("b09a74"), "s")
	mb.pop()


static func towel_stack(mb: MB, p: Vector3, n: int = 3, col: Color = Color("e8e2d4")) -> void:
	for k in n:
		mb.box(p + Vector3(0, 0.02 + k * 0.04, 0), Vector3(0.28, 0.036, 0.2), col.darkened(0.04 * (k % 2)), "s")


static func sack(mb: MB, p: Vector3, col: Color, r: float = 0.17, yaw: float = 0.0) -> void:
	mb.at(p, yaw)
	mb.atx(Vector3(0, r * 0.62, 0), 0.0, Vector3(1.0, 0.8, 1.3))
	mb.sph(Vector3.ZERO, r, col, "s", 8, 5)
	mb.pop()
	mb.cyl(Vector3(0, r * 1.3, 0), r * 0.35, r * 0.28, col.darkened(0.12), "s", 6, r * 0.2)
	mb.pop()


# ------------------------------------------------------------------ jewellery, tobacco, candy

static func watch(mb: MB, p: Vector3, yaw: float = 0.0) -> void:
	mb.at(p, yaw)
	mb.cyl(Vector3(0, 0.008, 0), 0.025, 0.016, BRASS, "m", 8)
	mb.cyl(Vector3(0, 0.017, 0), 0.02, 0.003, ENAMEL, "s", 8)
	mb.pop()


static func gem_ring(mb: MB, p: Vector3, col: Color = Color("e04a6a")) -> void:
	mb.hoop(p + Vector3(0, 0.012, 0), 0.014, 0.004, 0.02, BRASS, "m", 6)
	mb.sph(p + Vector3(0, 0.028, 0), 0.008, col, "e", 4, 3)


static func necklace(mb: MB, p: Vector3, col: Color = Color("e8d58a")) -> void:
	mb.hoop(p + Vector3(0, 0.004, 0), 0.05, 0.006, 0.006, col, "m", 10)
	mb.sph(p + Vector3(0, 0.01, 0.05), 0.009, Color("c83a5a"), "e", 4, 3)


static func pocket_watch(mb: MB, p: Vector3) -> void:
	mb.cyl(p + Vector3(0, 0.008, 0), 0.03, 0.016, BRASS, "m", 8)
	mb.cyl(p + Vector3(0, 0.017, 0), 0.025, 0.003, ENAMEL, "s", 8)
	mb.box(p + Vector3(0, 0.008, 0.06), Vector3(0.004, 0.004, 0.09), BRASS, "m")


static func cigarbox(mb: MB, p: Vector3, yaw: float = 0.0, open: bool = true, col: Color = Color("6a3a1e")) -> void:
	mb.at(p, yaw)
	mb.box(Vector3(0, 0.03, 0), Vector3(0.26, 0.06, 0.16), col, "s")
	if open:
		for k in 8:
			mb.cyl_dir(Vector3(-0.1 + k * 0.028, 0.065, 0), Vector3(0, 0, 1), 0.011, 0.14, Color("8a5a2a").lerp(Color("5a3a1e"), hf(k, 1, 4)), "s", 5)
		mb.box(Vector3(0, 0.07, 0.0), Vector3(0.25, 0.004, 0.04), Color("c9a54a"), "m")
	mb.pop()


static func candy(mb: MB, x0: float, z0: float, x1: float, z1: float, y: float, s: int) -> void:
	var n := maxi(3, int((x1 - x0) / 0.04))
	for i in n:
		var px := x0 + hf(i, 1, s) * (x1 - x0)
		var pz := z0 + hf(i, 2, s) * (z1 - z0)
		mb.sph(Vector3(px, y + 0.014, pz), 0.014, pick(BRIGHTS, i, 3, s), "s", 5, 3)


static func ball(mb: MB, p: Vector3, col: Color, r: float = 0.028) -> void:
	mb.sph(p + Vector3(0, r, 0), r, col, "s", 6, 4)


static func cash(mb: MB, p: Vector3, yaw: float = 0.0) -> void:
	mb.at(p, yaw)
	mb.box(Vector3(0, 0.012, 0), Vector3(0.16, 0.024, 0.07), Color("7a9a6a"), "s")
	mb.box(Vector3(0, 0.012, 0), Vector3(0.03, 0.026, 0.072), Color("e0d8b8"), "s")
	mb.pop()


static func coin(mb: MB, p: Vector3) -> void:
	mb.cyl(p + Vector3(0, 0.004, 0), 0.014, 0.008, Color("d8c070"), "m", 6)


static func chips(mb: MB, p: Vector3, col: Color, n: int = 4) -> void:
	for k in n:
		mb.cyl(p + Vector3(0, 0.005 + k * 0.01, 0), 0.02, 0.01, col, "s", 7)


static func card(mb: MB, p: Vector3, yaw: float, red: bool) -> void:
	paper(mb, p, yaw, Vector3(0.045, 0.002, 0.065), Color("f2ecdc"))
	mb.at(p, yaw)
	mb.box(Vector3(0, 0.0025, 0), Vector3(0.016, 0.001, 0.02), Color("b8282a") if red else Color("1a1a1a"), "s")
	mb.pop()


static func pistol(mb: MB, p: Vector3, yaw: float = 0.0) -> void:
	mb.at(p, yaw)
	mb.box(Vector3(0, 0.02, 0.0), Vector3(0.025, 0.03, 0.14), Color("1e1e22"), "m")
	mb.box(Vector3(0, 0.0, -0.05), Vector3(0.024, 0.05, 0.035), Color("3a2a1e"), "s")
	mb.pop()


static func tommy(mb: MB, p: Vector3, yaw: float = 0.0) -> void:
	mb.at(p, yaw)
	mb.box(Vector3(0, 0.04, 0.0), Vector3(0.05, 0.06, 0.34), Color("2a2a2e"), "m")
	mb.cyl(Vector3(0, 0.0, 0.0), 0.06, 0.07, Color("2a2a2e"), "m", 8)
	mb.box(Vector3(0, 0.03, -0.24), Vector3(0.04, 0.05, 0.14), Color("5a3a22"), "s")
	mb.pop()


static func newspaper(mb: MB, p: Vector3, yaw: float, t: float = 0.5) -> void:
	paper(mb, p, yaw, Vector3(0.32, 0.01, 0.24), Color("d8d0b8").lerp(Color("c8c0a0"), t))
	mb.at(p, yaw)
	mb.box(Vector3(0, 0.0105, -0.07), Vector3(0.26, 0.002, 0.03), Color("1c1916"), "s")
	mb.pop()


static func lantern(mb: MB, p: Vector3) -> void:
	mb.cyl(p + Vector3(0, 0.1, 0), 0.05, 0.2, GLASS, "g", 6)
	mb.cyl(p + Vector3(0, 0.03, 0), 0.06, 0.06, IRON, "m", 6)
	mb.sph(p + Vector3(0, 0.1, 0), 0.02, Color("ffc060"), "e", 4, 3)
