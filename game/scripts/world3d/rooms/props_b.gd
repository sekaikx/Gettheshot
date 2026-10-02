extends RefCounted
## Prop set B: tables, seats, the office, the pool hall, the speakeasy, the trades' own fixtures
## (ovens, presses, tubs, tanks, stoves), crates, barrels and sacks. Same frame as props_a.gd.

const MB := preload("res://scripts/world3d/rooms/mb.gd")
const P := preload("res://scripts/world3d/rooms/parts.gd")
const A := preload("res://scripts/world3d/rooms/props_a.gd")


# ------------------------------------------------------------------ tables

static func _glasses(mb: MB, x: float, y: float, z: float, sd: int, n: int = 2) -> void:
	for k in n:
		P.glass_cup(mb, Vector3(x + (k - 0.5) * 0.09, y, z + (P.hf(k, 1, sd) - 0.5) * 0.1), Color("c8982a") if k % 2 == 0 else Color("e8dcc0"), 0.027)


static func table_checked(mb: MB, w: float, d: float, sd: int, closed: bool) -> void:
	mb.blk(0, 0, 0.1, 0.1, 0.74, P.WOOD_D)
	mb.blk(0, 0, w * 0.55, 0.06, 0.04, P.WOOD_D, "s", 0.02)
	mb.blk(0, 0, 0.06, d * 0.55, 0.04, P.WOOD_D, "s", 0.02)
	mb.blk(0, 0, w, d, 0.04, P.WOOD, "s", 0.72)
	# the gingham cloth, hanging a little over the edge
	mb.blk(0, 0, w + 0.04, d + 0.04, 0.012, Color(1, 1, 1), "chk", 0.762)
	mb.quad(Vector3(-w * 0.5 - 0.02, 0.77, d * 0.5 + 0.02), Vector3(w * 0.5 + 0.02, 0.77, d * 0.5 + 0.02), Vector3(w * 0.5 + 0.02, 0.62, d * 0.5 + 0.02), Vector3(-w * 0.5 - 0.02, 0.62, d * 0.5 + 0.02), Color(1, 1, 1), "chk")
	mb.quad(Vector3(-w * 0.5 - 0.02, 0.62, -d * 0.5 - 0.02), Vector3(w * 0.5 + 0.02, 0.62, -d * 0.5 - 0.02), Vector3(w * 0.5 + 0.02, 0.77, -d * 0.5 - 0.02), Vector3(-w * 0.5 - 0.02, 0.77, -d * 0.5 - 0.02), Color(1, 1, 1), "chk")
	mb.quad(Vector3(w * 0.5 + 0.02, 0.77, d * 0.5 + 0.02), Vector3(w * 0.5 + 0.02, 0.77, -d * 0.5 - 0.02), Vector3(w * 0.5 + 0.02, 0.62, -d * 0.5 - 0.02), Vector3(w * 0.5 + 0.02, 0.62, d * 0.5 + 0.02), Color(1, 1, 1), "chk")
	mb.quad(Vector3(-w * 0.5 - 0.02, 0.77, -d * 0.5 - 0.02), Vector3(-w * 0.5 - 0.02, 0.77, d * 0.5 + 0.02), Vector3(-w * 0.5 - 0.02, 0.62, d * 0.5 + 0.02), Vector3(-w * 0.5 - 0.02, 0.62, -d * 0.5 - 0.02), Color(1, 1, 1), "chk")
	if closed:
		return
	# a setting each side, a candle bottle in the middle
	for s: float in [-1.0, 1.0]:
		var fill := Color(0, 0, 0, 0)
		if P.hf(int(s) + 2, 1, sd) > 0.4:
			fill = P.pick([Color("c88a4a"), Color("a83a2a"), Color("d8c880")], int(s) + 2, 2, sd)
		P.plate(mb, Vector3(s * (w * 0.5 - 0.2), 0.774, 0.0), 0.1, fill)
	mb.cyl(Vector3(0, 0.84, 0), 0.03, 0.14, Color("3a6a3c"), "s", 7, 0.018)
	mb.sph(Vector3(0, 0.935, 0), 0.012, Color("ffb050"), "e", 4, 3)


static func table_round(mb: MB, w: float, d: float, sd: int, cafe: bool = true) -> void:
	var r := minf(w, d) * 0.5
	mb.cyl(Vector3(0, 0.37, 0), 0.035, 0.74, Color("2a2a2e"), "m", 6)
	mb.cyl(Vector3(0, 0.02, 0), r * 0.55, 0.04, Color("2a2a2e"), "m", 8)
	mb.cyl(Vector3(0, 0.745, 0), r, 0.035, Color("e8e2d6"), "s", 14)
	mb.cyl(Vector3(0, 0.76, 0), r * 0.96, 0.004, Color("d8d0c0"), "s", 14)
	P.cup(mb, Vector3(-r * 0.4, 0.763, 0.0), 0.035)
	P.cup(mb, Vector3(r * 0.35, 0.763, r * 0.2), 0.035)
	if P.hf(1, 2, sd) > 0.5:
		P.plate(mb, Vector3(r * 0.1, 0.763, -r * 0.4), 0.07, Color("c88a4a"))


static func card_table(mb: MB, w: float, d: float, sd: int, booze: bool, closed: bool) -> void:
	var r := minf(w, d) * 0.5
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			mb.blk(sx * (r - 0.08), sz * (r - 0.08), 0.05, 0.05, 0.72, P.WOOD_D)
	mb.blk(0, 0, w, d, 0.05, P.WOOD_D, "s", 0.7)
	mb.blk(0, 0, w - 0.1, d - 0.1, 0.012, Color("2c6a40"), "s", 0.752)
	if closed:
		return
	for k in 4:
		var a := k * PI * 0.5 + 0.3
		P.card(mb, Vector3(cos(a) * r * 0.45, 0.766, sin(a) * r * 0.45), a + 1.0, k % 2 == 0)
		P.card(mb, Vector3(cos(a) * r * 0.45 + 0.03, 0.768, sin(a) * r * 0.45 + 0.02), a + 0.7, k % 2 == 1)
	P.chips(mb, Vector3(0.0, 0.752, 0.0), Color("b8282a"), 5)
	P.chips(mb, Vector3(0.06, 0.752, 0.02), Color("2a4a96"), 3)
	P.chips(mb, Vector3(-r * 0.5, 0.752, r * 0.3), Color("e8dcc0"), 4)
	P.ashtray(mb, Vector3(r * 0.55, 0.752, -r * 0.2), true)
	if booze:
		_glasses(mb, -r * 0.4, 0.752, -r * 0.45, sd)
		P.bottle(mb, Vector3(r * 0.2, 0.752, r * 0.5), Color("5a3a1e"), 0.26)
	P.cash(mb, Vector3(-r * 0.2, 0.752, r * 0.5), 0.5)


static func cocktail_table(mb: MB, w: float, d: float, sd: int, closed: bool) -> void:
	var r := minf(w, d) * 0.5
	mb.cyl(Vector3(0, 0.34, 0), 0.03, 0.68, P.BRASS, "m", 6)
	mb.cyl(Vector3(0, 0.02, 0), r * 0.6, 0.04, P.BRASS.darkened(0.3), "m", 8)
	mb.cyl(Vector3(0, 0.7, 0), r, 0.03, Color("2a2a2e"), "s", 12)
	mb.cyl(Vector3(0, 0.717, 0), r * 0.9, 0.006, Color("7a2a2a"), "s", 12)
	if closed:
		return
	P.glass_cup(mb, Vector3(-0.12, 0.72, 0.05), Color("e8c88a"), 0.03)
	P.glass_cup(mb, Vector3(0.1, 0.72, -0.08), Color("c8982a"), 0.03)
	mb.cyl(Vector3(0.0, 0.74, 0.1), 0.018, 0.05, Color("a82a2a"), "s", 6)
	mb.sph(Vector3(0.0, 0.775, 0.1), 0.008, Color("ffb050"), "e", 4, 3)


static func barrel_table(mb: MB, w: float, d: float, sd: int) -> void:
	barrel(mb, w, d, sd, "barrel_table", 0.78)
	mb.cyl(Vector3(0, 0.8, 0), minf(w, d) * 0.56, 0.03, P.WOOD_L, "s", 10)
	_glasses(mb, 0.0, 0.815, 0.0, sd)
	P.bottle(mb, Vector3(0.12, 0.815, 0.1), Color("5a3a1e"), 0.24)


static func bench(mb: MB, w: float, d: float, cushion: bool) -> void:
	for s: float in [-1.0, 1.0]:
		mb.blk(s * (w * 0.5 - 0.06), 0, 0.06, d - 0.1, 0.42, P.WOOD_D)
	mb.blk(0, 0, w, d, 0.05, P.WOOD, "s", 0.42)
	if cushion:
		mb.blk(0, 0.0, w - 0.06, d - 0.06, 0.07, Color("5a2a22"), "s", 0.47)
	# a back rail along the back side
	mb.blk(0, -d * 0.5 + 0.03, w, 0.05, 0.3, P.WOOD, "s", 0.5)


static func cot(mb: MB, w: float, d: float, sd: int) -> void:
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			mb.blk(sx * (w * 0.5 - 0.04), sz * (d * 0.5 - 0.04), 0.04, 0.04, 0.36, P.IRON, "m")
	mb.blk(0, 0, w, d, 0.04, P.IRON, "m", 0.34)
	mb.blk(0, 0, w - 0.06, d - 0.06, 0.08, Color("6a6a60"), "s", 0.38)
	mb.blk(0, -d * 0.4, w - 0.1, 0.2, 0.05, Color("d8d0b8"), "s", 0.46)


static func barber_chair(mb: MB, w: float, d: float) -> void:
	var leather := Color("6a1f1c")
	mb.cyl(Vector3(0, 0.03, 0), 0.26, 0.06, Color("d8d8d2"), "m", 10, 0.2)
	mb.cyl(Vector3(0, 0.3, 0), 0.07, 0.5, Color("e8e8e2"), "m", 8)
	mb.blk(0, 0.02, 0.5, 0.5, 0.14, leather, "s", 0.53)
	mb.blk(0, 0.0, 0.58, 0.54, 0.05, Color("e8e8e2"), "m", 0.5)
	mb.blk(0, -0.24, 0.5, 0.1, 0.62, leather, "s", 0.55)
	mb.blk(0, -0.26, 0.26, 0.1, 0.18, leather.lightened(0.05), "s", 1.15)
	for s: float in [-1.0, 1.0]:
		mb.blk(s * 0.3, 0.0, 0.06, 0.5, 0.05, leather.darkened(0.1), "s", 0.7)
		mb.blk(s * 0.3, 0.0, 0.04, 0.04, 0.2, Color("e8e8e2"), "m", 0.5)
	mb.blk(0, 0.34, 0.3, 0.26, 0.04, Color("e8e8e2"), "m", 0.3)
	mb.quad(Vector3(-0.14, 0.34, 0.2), Vector3(0.14, 0.34, 0.2), Vector3(0.14, 0.5, 0.0), Vector3(-0.14, 0.5, 0.0), Color("d8d8d2"), "m")
	var _w := w
	var _d := d


static func shine_stand(mb: MB, w: float, d: float) -> void:
	mb.blk(0, -d * 0.15, w - 0.1, d * 0.7, 0.3, P.WOOD_D)
	mb.blk(0, -d * 0.2, w - 0.1, d * 0.5, 0.05, P.OAK, "s", 0.3)
	mb.blk(0, -d * 0.4, w - 0.16, 0.1, 0.7, Color("5a2a22"), "s", 0.35)
	mb.blk(0, -d * 0.2, w - 0.2, d * 0.45, 0.08, Color("5a2a22"), "s", 0.35)
	for s: float in [-1.0, 1.0]:
		mb.blk(s * 0.14, d * 0.2, 0.12, 0.2, 0.03, P.BRASS, "m", 0.4)
		mb.blk(s * 0.14, d * 0.15, 0.04, 0.04, 0.12, P.BRASS, "m", 0.3)
	mb.blk(0.3, d * 0.3, 0.2, 0.14, 0.12, Color("2a1c14"), "s")


# ------------------------------------------------------------------ the office

static func desk(mb: MB, w: float, d: float, style: String, sd: int) -> void:
	var wood := Color("5a2e22") if style != "office" else Color("8a6a44")
	var top := Color("2a3a2a") if style == "boss" else Color("7a5a3a")
	var h := 0.76
	# two pedestals and a kneehole
	for s: float in [-1.0, 1.0]:
		mb.blk(s * (w * 0.5 - 0.22), 0, 0.42, d - 0.04, h - 0.04, wood)
		for k in 3:
			mb.blk(s * (w * 0.5 - 0.22), d * 0.5 - 0.005, 0.36, 0.02, 0.17, wood.lightened(0.06), "s", 0.06 + k * 0.2)
			mb.blk(s * (w * 0.5 - 0.22), d * 0.5 + 0.012, 0.08, 0.012, 0.018, P.BRASS, "m", 0.14 + k * 0.2)
	mb.blk(0, -d * 0.5 + 0.03, w - 0.8, 0.04, 0.5, wood.darkened(0.2), "s", 0.1)
	mb.blk(0, 0, w + 0.04, d + 0.04, 0.045, wood.darkened(0.1), "s", h - 0.045)
	mb.blk(0, 0, w - 0.16, d - 0.14, 0.006, top, "s", h)
	# the things on it
	var y := h + 0.006
	P.paper(mb, Vector3(-w * 0.2, y, 0.02), 0.1, Vector3(0.28, 0.006, 0.36))
	P.book(mb, Vector3(w * 0.1, y, -0.05), -0.2, P.OXBLOOD, Vector3(0.3, 0.05, 0.22))
	P.cash(mb, Vector3(w * 0.28, y, 0.1), 0.5)
	if style != "office":
		# the green banker's lamp
		mb.cyl(Vector3(-w * 0.38, y + 0.02, -d * 0.25), 0.05, 0.04, P.BRASS, "m", 8)
		mb.cyl(Vector3(-w * 0.38, y + 0.14, -d * 0.25), 0.012, 0.24, P.BRASS, "m", 5)
		mb.box(Vector3(-w * 0.38, y + 0.27, -d * 0.2), Vector3(0.28, 0.08, 0.12), Color("2f6a3c"), "s")
		mb.box(Vector3(-w * 0.38, y + 0.255, -d * 0.2), Vector3(0.24, 0.01, 0.1), Color("ffe0a0"), "bulb")
		P.cigarbox(mb, Vector3(w * 0.38, y, -d * 0.2), 0.2, true)
		P.ashtray(mb, Vector3(w * 0.12, y, d * 0.28), true)
	else:
		typewriter(mb, Vector3(-w * 0.05, y, 0.0))
	P.glass_cup(mb, Vector3(w * 0.05, y, d * 0.3), Color("c8982a"))
	var _s := sd


static func typewriter(mb: MB, p: Vector3) -> void:
	mb.blk(p.x, p.z, 0.28, 0.26, 0.09, Color("2a2a2e"), "m", p.y)
	mb.blk(p.x, p.z - 0.1, 0.3, 0.05, 0.1, Color("2a2a2e"), "m", p.y + 0.08)
	mb.blk(p.x, p.z - 0.14, 0.2, 0.004, 0.1, Color("e9e1c8"), "s", p.y + 0.14)
	for r in 3:
		for k in 6:
			mb.sph(Vector3(p.x - 0.1 + k * 0.04, p.y + 0.1 - r * 0.01, p.z + r * 0.04), 0.008, Color("e8dcc0"), "s", 4, 3)


static func phone(mb: MB, p: Vector3, yaw: float = 0.0) -> void:
	mb.at(p, yaw)
	mb.cyl(Vector3(0, 0.02, 0), 0.07, 0.04, Color("1c1c20"), "m", 10)
	mb.cyl(Vector3(0, 0.12, 0), 0.012, 0.16, Color("1c1c20"), "m", 6)
	mb.cyl(Vector3(0, 0.215, 0), 0.03, 0.03, Color("1c1c20"), "m", 8)
	mb.box(Vector3(0.07, 0.15, 0.0), Vector3(0.04, 0.03, 0.1), Color("1c1c20"), "m")
	mb.cyl(Vector3(0, 0.044, 0.0), 0.034, 0.004, P.BRASS, "m", 10)
	mb.pop()


static func safe(mb: MB, w: float, d: float, sd: int) -> void:
	var iron := Color("26282c")
	mb.blk(0, 0, w, d, 0.92, iron, "m")
	mb.blk(0, 0, w + 0.03, d + 0.03, 0.04, iron.lightened(0.1), "m", 0.92)
	mb.blk(0, 0, w + 0.03, d + 0.03, 0.04, iron.lightened(0.1), "m", 0.0)
	mb.blk(0, d * 0.5 + 0.01, w * 0.8, 0.02, 0.72, iron.lightened(0.08), "m", 0.1)
	mb.blk(0, d * 0.5 + 0.022, w * 0.8, 0.004, 0.05, P.BRASS, "m", 0.7)
	mb.cyl_dir(Vector3(0, 0.5, d * 0.5 + 0.04), Vector3(0, 0, 1), 0.07, 0.04, P.BRASS, "m", 12)
	mb.cyl_dir(Vector3(0, 0.5, d * 0.5 + 0.065), Vector3(0, 0, 1), 0.04, 0.02, P.BRASS.darkened(0.3), "m", 10)
	mb.blk(w * 0.28, d * 0.5 + 0.045, 0.16, 0.025, 0.04, P.BRASS, "m", 0.48)
	for k in 3:
		mb.sph(Vector3(-w * 0.35, 0.2 + k * 0.1, d * 0.5 + 0.02), 0.012, Color("505058"), "m", 4, 3)
	var _s := sd


static func map_table(mb: MB, w: float, d: float, sd: int) -> void:
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			mb.blk(sx * (w * 0.5 - 0.1), sz * (d * 0.5 - 0.1), 0.1, 0.1, 0.74, Color("4a2418"))
	mb.blk(0, 0, w, d, 0.06, Color("5a2e22"), "s", 0.72)
	mb.blk(0, 0, w - 0.14, d - 0.14, 0.01, Color("d8c898"), "s", 0.78)
	# the city on it: blocks, a river, family pins
	mb.blk(w * 0.3, 0, w * 0.22, d - 0.16, 0.004, Color("7a98a0"), "s", 0.79)
	for i in 5:
		for j in 3:
			if P.hf(i, j, sd) > 0.3:
				mb.blk(-w * 0.4 + i * w * 0.14, -d * 0.3 + j * d * 0.25, w * 0.1, d * 0.15, 0.01 + 0.008 * P.hf(i, j, sd + 1), Color("b8a888").lerp(Color("9a7a5a"), P.hf(i, j, sd + 2)), "s", 0.79)
	for k in 7:
		var c := P.pick([Color("c42828"), Color("2a5ac4"), Color("2ac45a"), Color("c4a428"), Color("a02ac4")], k, 3, sd)
		mb.cyl(Vector3(-w * 0.35 + P.hf(k, 1, sd) * w * 0.7, 0.83, -d * 0.35 + P.hf(k, 2, sd) * d * 0.7), 0.012, 0.05, c, "s", 5)
		mb.sph(Vector3(-w * 0.35 + P.hf(k, 1, sd) * w * 0.7, 0.86, -d * 0.35 + P.hf(k, 2, sd) * d * 0.7), 0.018, c, "s", 5, 3)
	mb.cyl(Vector3(-w * 0.45, 0.8, d * 0.4), 0.04, 0.04, P.BRASS, "m", 8)
	P.ashtray(mb, Vector3(w * 0.45, 0.78, d * 0.4), true)


static func phone_stand(mb: MB, w: float, d: float) -> void:
	mb.blk(0, 0, 0.36, 0.36, 0.04, P.WOOD_D, "s", 0.0)
	mb.cyl(Vector3(0, 0.35, 0), 0.025, 0.7, P.WOOD_D, "s", 6)
	mb.cyl(Vector3(0, 0.72, 0), 0.22, 0.04, P.WOOD, "s", 12)
	phone(mb, Vector3(0, 0.74, 0), 0.0)
	P.book(mb, Vector3(0.1, 0.74, 0.1), 0.4, Color("2a3a2a"), Vector3(0.14, 0.02, 0.1))
	var _w := w + d


static func file_cabinet(mb: MB, w: float, d: float) -> void:
	var c := Color("5a6a58")
	mb.blk(0, 0, w, d, 1.3, c, "m")
	for k in 4:
		mb.blk(0, d * 0.5 + 0.004, w - 0.06, 0.012, 0.28, c.lightened(0.08), "m", 0.04 + k * 0.31)
		mb.blk(0, d * 0.5 + 0.014, 0.14, 0.014, 0.025, P.BRASS, "m", 0.16 + k * 0.31)
		mb.blk(0, d * 0.5 + 0.012, 0.1, 0.006, 0.05, P.CREAM, "s", 0.23 + k * 0.31)


static func sideboard(mb: MB, w: float, d: float, sd: int) -> void:
	mb.blk(0, 0, w, d, 0.82, Color("4a2418"))
	mb.blk(0, 0.0, w + 0.04, d + 0.04, 0.04, Color("3a1a12"), "s", 0.82)
	for k in 3:
		mb.blk(-w * 0.33 + k * w * 0.33, d * 0.5 + 0.004, w * 0.3, 0.012, 0.6, Color("5e3224"), "s", 0.12)
		mb.blk(-w * 0.33 + k * w * 0.33, d * 0.5 + 0.014, 0.04, 0.014, 0.1, P.BRASS, "m", 0.4)
	mb.cyl(Vector3(-w * 0.3, 0.97, 0), 0.06, 0.2, Color("a88a3a"), "g", 8, 0.03)
	for k in 3:
		P.glass_cup(mb, Vector3(0.0 + k * 0.08, 0.86, 0.0), Color("c8982a"), 0.03)
	P.bottle(mb, Vector3(w * 0.3, 0.86, 0.0), Color("3a6a3c"), 0.3)
	var _s := sd


# ------------------------------------------------------------------ pool hall, speakeasy

static func pool_table(mb: MB, w: float, d: float, sd: int) -> void:
	var wood := Color("4a2418")
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			mb.blk(sx * (w * 0.5 - 0.1), sz * (d * 0.5 - 0.1), 0.15, 0.15, 0.7, wood)
	mb.blk(0, 0, w - 0.1, d - 0.1, 0.16, wood.darkened(0.1), "s", 0.62)
	var rw := 0.1
	mb.blk(0, d * 0.5 - rw * 0.5, w, rw, 0.09, wood.lightened(0.04), "s", 0.78)
	mb.blk(0, -d * 0.5 + rw * 0.5, w, rw, 0.09, wood.lightened(0.04), "s", 0.78)
	mb.blk(w * 0.5 - rw * 0.5, 0, rw, d - rw * 2.0, 0.09, wood.lightened(0.04), "s", 0.78)
	mb.blk(-w * 0.5 + rw * 0.5, 0, rw, d - rw * 2.0, 0.09, wood.lightened(0.04), "s", 0.78)
	mb.blk(0, 0, w - rw * 2.0, d - rw * 2.0, 0.012, Color("2c6a40"), "s", 0.775)
	# cushions
	mb.blk(0, d * 0.5 - rw - 0.02, w - 0.3, 0.04, 0.03, Color("245a38"), "s", 0.787)
	mb.blk(0, -d * 0.5 + rw + 0.02, w - 0.3, 0.04, 0.03, Color("245a38"), "s", 0.787)
	for s: float in [-1.0, 1.0]:
		mb.blk(s * (w * 0.5 - rw - 0.02), 0, 0.04, d - 0.3, 0.03, Color("245a38"), "s", 0.787)
	# pockets and diamonds
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			mb.cyl(Vector3(sx * (w * 0.5 - rw), 0.792, sz * (d * 0.5 - rw)), 0.05, 0.004, Color("0a0a0a"), "s", 8)
		mb.cyl(Vector3(0.0, 0.792, sx * (d * 0.5 - rw * 0.7)), 0.045, 0.004, Color("0a0a0a"), "s", 8)
	for k in 3:
		for s: float in [-1.0, 1.0]:
			mb.sph(Vector3(-w * 0.25 + k * w * 0.25, 0.872, s * (d * 0.5 - rw * 0.5)), 0.01, P.BRASS, "m", 4, 3)
	# the rack of balls and the cue ball
	var bx := -w * 0.22
	var n := 0
	for row in 4:
		for k in row + 1:
			P.ball(mb, Vector3(bx - row * 0.052, 0.787, (k - row * 0.5) * 0.058), P.pick(P.BRIGHTS, n, 2, sd) if n != 3 else Color("1a1a1a"))
			n += 1
	P.ball(mb, Vector3(w * 0.25, 0.787, 0.04), Color("f2ecdc"))
	mb.rod(Vector3(w * 0.1, 0.9, d * 0.5 + 0.12), Vector3(w * 0.5, 0.78, d * 0.5 - 0.02), 0.012, Color("c8a86a"), "s", 5)


static func piano(mb: MB, w: float, d: float) -> void:
	var wood := Color("2a1a14")
	mb.blk(0, -d * 0.12, w, d * 0.76, 1.3, wood)
	mb.blk(0, -d * 0.12, w + 0.04, d * 0.78, 0.04, wood.lightened(0.05), "s", 1.3)
	mb.blk(0, d * 0.3, w - 0.04, d * 0.4, 0.07, wood.lightened(0.03), "s", 0.72)
	mb.blk(0, d * 0.28, w - 0.12, d * 0.3, 0.025, Color("f0ead8"), "s", 0.79)
	for k in int((w - 0.12) / 0.07):
		if k % 7 not in [2, 6]:
			mb.blk(-w * 0.5 + 0.1 + k * 0.07, d * 0.34, 0.004, d * 0.2, 0.012, Color("1a1a1a"), "s", 0.805)
	mb.blk(0, d * 0.3, w - 0.04, 0.05, 0.4, wood.lightened(0.04), "s", 0.5)
	mb.blk(-w * 0.5 + 0.1, d * 0.4, 0.06, 0.3, 0.74, wood)
	mb.blk(w * 0.5 - 0.1, d * 0.4, 0.06, 0.3, 0.74, wood)
	mb.blk(0, -d * 0.1, w - 0.2, 0.01, 0.34, Color("3a2a20"), "s", 0.9)
	mb.blk(0, d * 0.45, 0.06, 0.01, 0.12, P.BRASS, "m", 0.0)
	mb.cyl(Vector3(0, 0.2, d * 0.7), 0.17, 0.04, wood.lightened(0.1), "s", 10)
	mb.cyl(Vector3(0, 0.1, d * 0.7), 0.03, 0.2, P.BRASS, "m", 6)


static func phonograph(mb: MB, w: float, d: float) -> void:
	var wood := Color("5a3a22")
	mb.blk(0, 0, w, d, 0.8, wood)
	mb.blk(0, 0, w + 0.03, d + 0.03, 0.04, wood.lightened(0.05), "s", 0.8)
	mb.cyl(Vector3(0, 0.846, 0.04), 0.16, 0.012, Color("1a1a1a"), "s", 14)
	mb.cyl(Vector3(0, 0.86, 0.04), 0.04, 0.012, P.OXBLOOD, "s", 8)
	mb.rod(Vector3(0.14, 0.88, -0.1), Vector3(0.0, 0.9, 0.04), 0.008, P.BRASS, "m", 4)
	# the great horn
	mb.cyl_dir(Vector3(-0.1, 1.15, -0.12), Vector3(-0.3, 0.55, 0.75), 0.13, 0.5, P.BRASS, "m", 12, 0.015)
	mb.cyl(Vector3(0, 0.84, -0.12), 0.02, 0.2, P.BRASS, "m", 6)
	mb.blk(0, d * 0.5 + 0.005, w * 0.7, 0.012, 0.4, Color("3a2416"), "s", 0.1)


# ------------------------------------------------------------------ jail and warehouse

static func cell(mb: MB, w: float, d: float, sd: int) -> void:
	mb.blk(0, 0, w - 0.08, d - 0.08, 0.012, Color("5a5a58"), "s", 0.0)
	var _s := sd


static func elevator(mb: MB, w: float, d: float, sd: int) -> void:
	var iron := Color("3a3e40")
	mb.blk(0, 0, w, d, 0.12, Color("5a5448"), "s")
	for k in 8:
		mb.blk(-w * 0.5 + 0.1 + k * (w - 0.2) / 7.0, d * 0.5 - 0.04, 0.2, 0.06, 0.005, Color("d6b032") if k % 2 == 0 else Color("1a1a1a"), "s", 0.12)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			mb.blk(sx * (w * 0.5 - 0.04), sz * (d * 0.5 - 0.04), 0.07, 0.07, 2.4, iron, "m")
	mb.blk(0, -d * 0.5 + 0.04, w, 0.06, 0.08, iron, "m", 2.35)
	mb.blk(0, d * 0.5 - 0.04, w, 0.06, 0.08, iron, "m", 2.35)
	for s: float in [-1.0, 1.0]:
		mb.blk(s * (w * 0.5 - 0.04), 0, 0.06, d, 0.08, iron, "m", 2.35)
	# the collapsible gate across the front
	for k in 10:
		var x := -w * 0.5 + 0.1 + (w - 0.2) * float(k) / 9.0
		mb.rod(Vector3(x, 0.14, d * 0.5 - 0.05), Vector3(x + (w - 0.2) / 18.0, 1.3, d * 0.5 - 0.05), 0.012, iron.lightened(0.1), "m", 4)
		mb.rod(Vector3(x + (w - 0.2) / 18.0, 1.3, d * 0.5 - 0.05), Vector3(x + (w - 0.2) / 9.0, 0.14, d * 0.5 - 0.05), 0.012, iron.lightened(0.1), "m", 4)
	mb.blk(0, 0, 0.1, 0.1, 0.3, iron, "m", 2.4)
	mb.rod(Vector3(0, 2.5, 0), Vector3(0, 3.4, 0), 0.012, iron, "m", 4)
	mb.blk(w * 0.5 - 0.04, d * 0.5 - 0.05, 0.12, 0.05, 0.25, P.BRASS.darkened(0.2), "m", 1.0)
	var _s := sd


# ------------------------------------------------------------------ crates, barrels, sacks

static func crate(mb: MB, p: Vector3, sz: Vector3, yaw: float, sd: int, booze: bool = false, tint: Color = Color(0, 0, 0, 0)) -> void:
	var wood := P.OAK.darkened(0.06 + 0.1 * P.hf(int(p.x * 10.0), int(p.y * 10.0), sd))
	if tint.a > 0.0:
		wood = tint
	mb.at(p, yaw)
	mb.box(Vector3(0, sz.y * 0.5, 0), sz, wood, "s")
	# slats and corner posts
	for k in 3:
		mb.box(Vector3(0, sz.y * (0.2 + 0.3 * k), 0), sz + Vector3(0.012, -sz.y * 0.8 + 0.01, 0.012), wood.darkened(0.15), "s")
	for sx: float in [-1.0, 1.0]:
		for sz2: float in [-1.0, 1.0]:
			mb.box(Vector3(sx * (sz.x * 0.5 - 0.02), sz.y * 0.5, sz2 * (sz.z * 0.5 - 0.02)), Vector3(0.05, sz.y + 0.01, 0.05), wood.darkened(0.3), "s")
	if booze:
		for k in 3:
			P.bottle(mb, Vector3((k - 1) * sz.x * 0.28, sz.y, 0.0), Color("6a4a1e"), 0.2, 0.03)
	mb.pop()


static func crates(mb: MB, w: float, d: float, art: String, sd: int, closed: bool = false) -> void:
	var unit := 0.5
	var nx := maxi(1, int(round(w / unit)))
	var nz := maxi(1, int(round(d / unit)))
	var cw := w / nx
	var cd := d / nz
	var tall := art in ["crate_stack", "gun_crates", "cloth_bales", "trunk"]
	var tints := {"gun_crates": Color("4a4a30"), "shoe_boxes": Color("b8a078"), "fish_boxes": Color("b0a890")}
	for i in nx:
		for j in nz:
			var hseed := P.hf(i, j, sd)
			var levels := 1 + (int(hseed * 3.0) if tall else int(hseed * 2.0))
			if art == "crate_row":
				levels = 1
			var x := -w * 0.5 + cw * (float(i) + 0.5)
			var z := -d * 0.5 + cd * (float(j) + 0.5)
			for lv in levels:
				var h := 0.42 if art != "trunk" else 0.5
				var tint: Color = tints.get(art, Color(0, 0, 0, 0))
				var ysz := Vector3(cw - 0.04 - lv * 0.02, h, cd - 0.04 - lv * 0.02)
				if art == "cloth_bales":
					bale(mb, Vector3(x, lv * h, z), ysz, sd + i + j, lv)
				elif art == "trunk":
					trunk(mb, Vector3(x, lv * h, z), ysz, 0.0, sd + i)
				else:
					crate(mb, Vector3(x, lv * h, z), ysz, (P.hf(i, lv, sd + 3) - 0.5) * 0.12, sd + lv * 3 + i, art == "produce_crates" and false, tint)
				if lv == levels - 1 and not closed:
					var ty := (lv + 1) * h
					if art == "produce_crates":
						P.heap(mb, x - ysz.x * 0.4, z - ysz.z * 0.4, x + ysz.x * 0.4, z + ysz.z * 0.4, ty, ["apple", "orange", "tomato", "pear"][(i + j + sd) % 4], sd + i)
					elif art == "fish_boxes":
						P.fish(mb, Vector3(x, ty, z), 1.57, P.SILVER)
					elif art == "gun_crates" and i == 0 and j == 0:
						P.tommy(mb, Vector3(x, ty, z), 0.4)
					elif art == "shoe_boxes":
						P.pair(mb, Vector3(x, ty, z), 0.5 * i, Color("4a2e1e"))
					elif art == "crates" and P.hf(i, j, sd + 9) > 0.7:
						P.bottle(mb, Vector3(x, ty, z), Color("6a4a1e"), 0.22)


static func bale(mb: MB, p: Vector3, sz: Vector3, sd: int, lv: int) -> void:
	var c := P.pick(P.CLOTHS, lv, sd, 3).lerp(Color("a89068"), 0.4)
	mb.at(p)
	mb.atx(Vector3(0, sz.y * 0.5, 0), 0.0, Vector3(sz.x * 0.52, sz.y * 0.54, sz.z * 0.52))
	mb.sph(Vector3.ZERO, 1.0, c, "s", 8, 5)
	mb.pop()
	mb.box(Vector3(0, sz.y * 0.5, 0), Vector3(sz.x * 1.0, 0.02, sz.z * 0.5), Color("5a4a32"), "s")
	mb.pop()


static func trunk(mb: MB, p: Vector3, sz: Vector3, yaw: float, sd: int) -> void:
	mb.at(p, yaw)
	mb.box(Vector3(0, sz.y * 0.5, 0), sz, Color("4a3322"), "s")
	mb.box(Vector3(0, sz.y * 0.5 + sz.y * 0.5, 0), Vector3(sz.x * 0.99, 0.03, sz.z * 0.99), Color("5a4030"), "s")
	for s: float in [-1.0, 1.0]:
		mb.box(Vector3(s * sz.x * 0.34, sz.y * 0.5, 0), Vector3(0.025, sz.y + 0.02, sz.z + 0.01), P.BRASS.darkened(0.2), "m")
	mb.box(Vector3(0, sz.y * 0.65, sz.z * 0.5 + 0.01), Vector3(0.05, 0.06, 0.02), P.BRASS, "m")
	mb.pop()
	var _s := sd


static func barrel(mb: MB, w: float, d: float, sd: int, art: String = "barrel", h: float = 0.85) -> void:
	var r := minf(w, d) * 0.5
	var drum := art in ["kerosene"]
	var wood := P.OAK.darkened(0.12)
	if art == "sugar_barrel":
		wood = Color("c8b898")
	elif art == "bone_barrel":
		wood = Color("5a4a3a")
	if drum:
		mb.cyl(Vector3(0, h * 0.5, 0), r, h, Color("8a2a24"), "m", 10)
		for k in 3:
			mb.hoop(Vector3(0, 0.05 + k * h * 0.45, 0), r * 1.01, 0.012, 0.03, Color("6a1a16"), "m", 10)
		return
	mb.cyl(Vector3(0, h * 0.5, 0), r * 0.96, h, wood, "s", 10, r * 0.96)
	mb.cyl(Vector3(0, h * 0.5, 0), r, h * 0.5, wood.lightened(0.04), "s", 10, r, false)
	for k in 3:
		var y := 0.1 + k * (h - 0.2) * 0.5
		mb.hoop(Vector3(0, y, 0), r * 1.0, 0.016, 0.035, Color("3a3a3e"), "m", 10)
	mb.cyl(Vector3(0, h + 0.002, 0), r * 0.9, 0.006, wood.darkened(0.2), "s", 10)
	if art == "sugar_barrel":
		mb.cyl(Vector3(0, h + 0.01, 0), r * 0.84, 0.02, Color("f0eadc"), "s", 10)
	var _s := sd


static func barrel_row(mb: MB, w: float, d: float, sd: int, art: String) -> void:
	var r := 0.3
	var n := maxi(1, int(round(d / (r * 2.0)))) if d > w else maxi(1, int(round(w / (r * 2.0))))
	for i in n:
		var z := -d * 0.5 + (float(i) + 0.5) * d / n if d > w else 0.0
		var x := 0.0 if d > w else -w * 0.5 + (float(i) + 0.5) * w / n
		mb.at(Vector3(x, 0, z))
		barrel(mb, minf(w, 0.6), minf(d / (n if d > w else 1.0), 0.6), sd + i, "barrel" if art == "barrels" else "barrel", 0.82)
		if art == "barrels" and i % 2 == 0:
			P.heap(mb, -0.15, -0.15, 0.15, 0.15, 0.8, "apple", sd + i)
		mb.pop()


static func barrel_stack(mb: MB, w: float, d: float, sd: int) -> void:
	var r := minf(w, 0.62) * 0.5
	var n := maxi(1, int(round(d / (r * 2.0))))
	for i in n:
		var z := -d * 0.5 + (float(i) + 0.5) * d / n
		mb.at(Vector3(0, 0, z))
		barrel(mb, r * 2.0, r * 2.0, sd + i, "barrel", 0.85)
		if i % 2 == 0:
			mb.at(Vector3(0, 0.85, 0))
			barrel(mb, r * 1.9, r * 1.9, sd + i + 4, "barrel", 0.8)
			mb.pop()
		mb.pop()


static func sack_pile(mb: MB, w: float, d: float, sd: int, art: String) -> void:
	var col := {"flour_sacks": Color("e0d8c0"), "potato_sacks": Color("b09064"), "coffee_sacks": Color("a8885a")}.get(art, Color("b8a078"))
	var nx := maxi(1, int(w / 0.34))
	var nz := maxi(1, int(d / 0.4))
	for i in nx:
		for j in nz:
			var x := -w * 0.5 + w * (float(i) + 0.5) / nx
			var z := -d * 0.5 + d * (float(j) + 0.5) / nz
			P.sack(mb, Vector3(x, 0, z), col.darkened(0.06 * P.hf(i, j, sd)), 0.17, P.hf(i, j, sd + 1) * 3.0)
			if P.hf(i, j, sd + 2) > 0.45:
				P.sack(mb, Vector3(x + 0.02, 0.22, z), col.lightened(0.05), 0.15, P.hf(i, j, sd + 3) * 3.0)


# ------------------------------------------------------------------ the trades' fixtures

static func oven(mb: MB, w: float, d: float, sd: int, closed: bool) -> void:
	var brick := Color("8a4a36")
	mb.blk(0, 0, w, d, 0.9, brick.darkened(0.15))
	# the domed oven body with an arched mouth
	mb.atx(Vector3(0, 0.9, 0), 0.0, Vector3(w * 0.5, 0.62, d * 0.5))
	mb.sph(Vector3.ZERO, 1.0, brick, "s", 10, 5, 1.0)
	mb.pop()
	mb.blk(0, d * 0.5 - 0.02, w * 0.55, 0.06, 0.5, Color("1a1410"), "s", 0.28)
	mb.blk(0, d * 0.5 + 0.0, w * 0.55, 0.04, 0.05, Color("3a3a3e"), "m", 0.78)
	if not closed:
		mb.blk(0, d * 0.5 - 0.01, w * 0.42, 0.02, 0.28, Color("ff8a2a"), "e", 0.32)
	mb.blk(0, d * 0.5 + 0.005, w * 0.55, 0.03, 0.03, Color("3a3a3e"), "m", 0.26)
	mb.cyl(Vector3(0, 1.9, -d * 0.2), 0.1, 1.0, Color("6a6a6e"), "m", 8)
	# peel leaning on the side
	mb.rod(Vector3(w * 0.5 - 0.05, 0.1, d * 0.5 - 0.1), Vector3(w * 0.5 - 0.05, 1.5, d * 0.3), 0.015, P.WOOD, "s", 5)
	mb.blk(w * 0.5 - 0.05, d * 0.5 - 0.1, 0.22, 0.2, 0.012, P.OAK, "s", 0.02)


static func cold_room(mb: MB, w: float, d: float, sd: int) -> void:
	mb.blk(0, 0, w, d, 1.7, Color("dcd8c8"))
	mb.blk(0, 0, w + 0.03, d + 0.03, 0.05, Color("b8bcb0"), "s", 1.7)
	mb.blk(0, d * 0.5 + 0.02, w * 0.75, 0.05, 1.55, Color("c8c4b4"), "s", 0.05)
	mb.blk(0, d * 0.5 + 0.05, w * 0.6, 0.02, 1.3, Color("e8e4d4"), "s", 0.15)
	mb.blk(w * 0.28, d * 0.5 + 0.07, 0.04, 0.04, 0.3, P.STEEL, "m", 0.9)
	mb.blk(-w * 0.28, d * 0.5 + 0.07, 0.08, 0.02, 0.12, P.STEEL, "m", 0.4)
	mb.blk(0, d * 0.5 + 0.06, 0.06, 0.012, 0.14, Color("ece6d0"), "s", 1.4)
	var _s := sd


static func icebox(mb: MB, w: float, d: float) -> void:
	mb.blk(0, 0, w, d, 1.3, Color("7a5a38"))
	mb.blk(0, 0, w + 0.02, d + 0.02, 0.04, Color("5e4430"), "s", 1.3)
	mb.blk(0, d * 0.5 + 0.004, w - 0.1, 0.014, 0.5, Color("8a6a46"), "s", 0.7)
	mb.blk(0, d * 0.5 + 0.004, w - 0.1, 0.014, 0.5, Color("8a6a46"), "s", 0.12)
	for k in 2:
		mb.blk(0, d * 0.5 + 0.02, 0.05, 0.02, 0.1, P.STEEL, "m", 0.35 + k * 0.7 + 0.1)
		mb.blk(w * 0.5 - 0.1, d * 0.5 + 0.02, 0.05, 0.03, 0.06, P.BRASS, "m", 0.4 + k * 0.6)


static func ice_chests(mb: MB, w: float, d: float, sd: int) -> void:
	var n := maxi(1, int(d / 0.7))
	for k in n:
		var z := -d * 0.5 + d * (float(k) + 0.5) / n
		mb.blk(0, z, w, d / n - 0.06, 0.55, Color("8a969a"), "m")
		mb.blk(0, z, w - 0.08, d / n - 0.14, 0.02, Color("d8e8ee"), "s", 0.55)
		for i in 4:
			mb.box(Vector3(-w * 0.3 + i * w * 0.2, 0.62, z + (P.hf(i, k, sd) - 0.5) * 0.1), Vector3(0.12, 0.1, 0.12), Color(0.82, 0.92, 0.96, 0.8), "s")


static func chop_block(mb: MB, w: float, d: float, sd: int) -> void:
	var r := minf(w, d) * 0.5
	mb.cyl(Vector3(0, 0.4, 0), r * 0.95, 0.8, Color("a47b50"), "s", 12)
	mb.cyl(Vector3(0, 0.81, 0), r * 0.95, 0.01, Color("c8a070"), "s", 12)
	mb.box(Vector3(0.0, 0.88, 0.0), Vector3(0.22, 0.09, 0.02), P.STEEL, "m")
	mb.box(Vector3(0.0, 0.84, 0.0), Vector3(0.22, 0.04, 0.02), P.STEEL.darkened(0.2), "m")
	mb.box(Vector3(0.18, 0.83, 0.0), Vector3(0.1, 0.03, 0.025), Color("3a2418"), "s")
	var _s := sd


static func bench_top(mb: MB, w: float, d: float, art: String, sd: int, closed: bool) -> void:
	var wood := P.WOOD_L
	var h := 0.82
	var top := Color("a98a62")
	match art:
		"marble_slab":
			top = Color("e8e2d6")
		"gutting_table":
			top = Color("a8b0a8")
		"lab_bench":
			top = Color("2a2a2c")
		"prep_table":
			top = Color("c8c0a8")
		"folding_table":
			top = Color("d0b88a")
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			mb.blk(sx * (w * 0.5 - 0.05), sz * (d * 0.5 - 0.05), 0.07, 0.07, h - 0.05, wood.darkened(0.2))
	mb.blk(0, 0, w - 0.08, 0.05, 0.05, wood.darkened(0.2), "s", 0.3)
	mb.blk(0, 0, w, d, 0.05, top, "s", h - 0.05)
	if closed:
		return
	var y := h
	match art:
		"saw_bench":
			mb.box(Vector3(-w * 0.2, y + 0.02, 0), Vector3(0.5, 0.03, 0.08), P.STEEL, "m")
			mb.box(Vector3(-w * 0.2 - 0.3, y + 0.04, 0), Vector3(0.1, 0.05, 0.03), Color("3a2418"), "s")
			P.bundle(mb, Vector3(w * 0.15, y, 0.0), 0.3, Color("c88a7a"))
		"gutting_table":
			P.fish(mb, Vector3(-w * 0.2, y, 0.0), 0.3, P.SILVER)
			P.fish(mb, Vector3(w * 0.1, y, 0.1), 1.2, Color("aab8b0"))
			mb.box(Vector3(w * 0.3, y + 0.01, 0), Vector3(0.18, 0.02, 0.03), P.STEEL, "m")
		"lab_bench":
			for k in 4:
				P.label_bottle(mb, Vector3(-w * 0.35 + k * w * 0.2, y, 0.0), P.pick([Color("6aa8c8"), Color("c8a86a"), Color("8ac88a")], k, 1, sd), P.CREAM, 0.2, 0.03)
			mb.cyl(Vector3(w * 0.3, y + 0.05, 0), 0.05, 0.1, Color("c9a54a"), "m", 8)
		"stitcher", "sewing_bench":
			mb.blk(0.0, 0.0, 0.4, 0.2, 0.05, Color("1c1c20"), "m", y)
			mb.blk(-0.12, 0.0, 0.14, 0.14, 0.26, Color("1c1c20"), "m", y + 0.05)
			mb.blk(0.0, 0.0, 0.2, 0.05, 0.05, Color("1c1c20"), "m", y + 0.26)
			mb.cyl_dir(Vector3(-0.17, y + 0.2, 0.0), Vector3(0, 0, 1), 0.06, 0.02, P.BRASS, "m", 10)
			P.paper(mb, Vector3(w * 0.3, y, 0.0), 0.2, Vector3(0.3, 0.015, 0.2), P.pick(P.CLOTHS, 1, 1, sd))
		"cobbler_bench":
			for k in 3:
				P.shoe(mb, Vector3(-w * 0.3 + k * 0.2, y, (k - 1) * 0.1), 0.3 + k, Color("5a3a22"))
			mb.box(Vector3(w * 0.3, y + 0.02, 0.0), Vector3(0.14, 0.04, 0.05), P.STEEL, "m")
			mb.cyl(Vector3(w * 0.25, y + 0.03, 0.15), 0.04, 0.06, Color("2a1c14"), "s", 6)
		"folding_table":
			P.towel_stack(mb, Vector3(-w * 0.25, y, 0.0), 5, Color("e8e2d4"))
			P.towel_stack(mb, Vector3(w * 0.1, y, 0.1), 3, Color("c8d8e0"))
			mb.blk(w * 0.3, 0.0, 0.2, 0.1, 0.09, Color("2a2a2e"), "m", y)
		"gun_table":
			P.pistol(mb, Vector3(-w * 0.2, y, 0.0), 0.5)
			P.pistol(mb, Vector3(0.0, y, 0.12), 2.0)
			P.tommy(mb, Vector3(w * 0.2, y, -0.1), 0.2)
		"numbers_desk", "slip_table":
			P.paper(mb, Vector3(-w * 0.25, y, 0.0), 0.2)
			P.paper(mb, Vector3(0.0, y, 0.05), -0.3)
			P.book(mb, Vector3(w * 0.25, y, 0.0), 0.1, Color("2a3a2a"), Vector3(0.28, 0.04, 0.2))
			typewriter(mb, Vector3(w * 0.1, y, -0.12))
		"marble_slab", "prep_table":
			if art == "prep_table":
				P.heap(mb, -w * 0.3, -d * 0.2, -w * 0.05, d * 0.2, y, "onion", sd)
				mb.box(Vector3(w * 0.2, y + 0.01, 0.0), Vector3(0.22, 0.02, 0.04), P.STEEL, "m")
			else:
				P.candy(mb, -w * 0.3, -d * 0.3, w * 0.3, d * 0.3, y, sd)
		_:
			P.paper(mb, Vector3(0, y, 0), 0.0)


static func washtubs(mb: MB, w: float, d: float, sd: int) -> void:
	var n := maxi(1, int(d / 0.6))
	for k in n:
		var z := -d * 0.5 + d * (float(k) + 0.5) / n
		mb.blk(0, z, w - 0.1, d / n - 0.06, 0.8, Color("8a969a"), "m")
		mb.blk(0, z, w - 0.2, d / n - 0.16, 0.01, Color("5a7a8a"), "s", 0.8)
		mb.blk(0, z, w - 0.2, d / n - 0.16, 0.02, Color("c8dce4"), "g", 0.78)
		mb.blk(0, z + d / n * 0.25, w - 0.24, 0.03, 0.2, Color("a47b50"), "s", 0.8)
		for sx: float in [-1.0, 1.0]:
			mb.blk(sx * (w * 0.5 - 0.1), z, 0.06, 0.06, 0.1, P.WOOD_D)
	var _s := sd


static func mangle(mb: MB, w: float, d: float) -> void:
	var iron := Color("3a3e40")
	mb.blk(0, 0, w, d, 0.9, iron, "m")
	mb.blk(0, 0, w - 0.1, d - 0.1, 0.2, Color("e0dac8"), "s", 0.9)
	mb.cyl_dir(Vector3(0, 1.05, 0), Vector3(1, 0, 0), 0.1, w - 0.1, Color("c8c0a8"), "s", 10)
	mb.cyl_dir(Vector3(0, 1.0, 0.0), Vector3(1, 0, 0), 0.02, w + 0.1, iron, "m", 6)
	mb.cyl(Vector3(w * 0.5, 1.0, d * 0.4), 0.14, 0.04, iron.lightened(0.1), "m", 10)
	mb.cyl_dir(Vector3(w * 0.5, 1.0, d * 0.4), Vector3(1, 0, 0), 0.14, 0.04, iron.lightened(0.1), "m", 10)


static func boiler(mb: MB, w: float, d: float, copper: bool) -> void:
	var c := Color("b8704a") if copper else Color("6a6e72")
	var r := minf(w, d) * 0.5
	mb.blk(0, 0, r * 2.0, r * 2.0, 0.3, Color("3a3a3e"), "m")
	mb.cyl(Vector3(0, 0.95, 0), r * 0.9, 1.3, c, "m", 12)
	mb.sph(Vector3(0, 1.58, 0), r * 0.9, c, "m", 12, 4, 0.5)
	for k in 3:
		mb.hoop(Vector3(0, 0.5 + k * 0.45, 0), r * 0.91, 0.014, 0.04, c.darkened(0.25), "m", 12)
	mb.cyl(Vector3(0, 2.0, 0), 0.07, 0.7, Color("4a4a4e"), "m", 8)
	mb.cyl(Vector3(r * 0.55, 0.9, r * 0.5), 0.05, 0.09, P.BRASS, "m", 8)
	if copper:
		mb.blk(0, r * 0.88, 0.12, 0.02, 0.2, P.BRASS, "m", 0.4)


static func steam_press(mb: MB, w: float, d: float) -> void:
	var iron := Color("3a3e40")
	mb.blk(0, -d * 0.2, w - 0.1, d * 0.5, 0.9, iron, "m")
	mb.blk(0, -d * 0.2, w - 0.04, d * 0.54, 0.08, Color("e0dac8"), "s", 0.9)
	mb.blk(0, -d * 0.35, 0.14, 0.14, 1.3, iron, "m")
	mb.blk(0, -d * 0.05, w * 0.7, d * 0.4, 0.07, iron.lightened(0.15), "m", 1.05)
	mb.rod(Vector3(w * 0.4, 1.0, -d * 0.2), Vector3(w * 0.45, 1.8, d * 0.1), 0.02, P.IRON, "m", 5)
	mb.sph(Vector3(w * 0.45, 1.82, d * 0.1), 0.05, Color("3a2a1e"), "s", 6, 4)
	mb.cyl(Vector3(-w * 0.35, 0.3, d * 0.3), 0.15, 0.6, Color("5a5a5e"), "m", 8)


static func range_stove(mb: MB, w: float, d: float, sd: int, closed: bool) -> void:
	var iron := Color("1e1e22")
	mb.blk(0, 0, w, d, 0.88, iron, "m")
	mb.blk(0, 0, w + 0.02, d + 0.02, 0.04, iron.lightened(0.1), "m", 0.88)
	mb.blk(0, d * 0.5 + 0.006, w * 0.6, 0.012, 0.4, iron.lightened(0.2), "m", 0.2)
	mb.blk(0, d * 0.5 + 0.02, w * 0.5, 0.02, 0.024, P.BRASS, "m", 0.52)
	for k in 4:
		var bx := -w * 0.3 + (k % 2) * w * 0.6
		var bz := -d * 0.2 + (k / 2) * d * 0.4
		mb.cyl(Vector3(bx, 0.93, bz), 0.1, 0.01, Color("0a0a0a"), "s", 10)
	mb.blk(0, -d * 0.45, w, 0.06, 0.5, iron, "m", 0.92)
	if not closed:
		# a pot of something on the back burner and a skillet
		mb.cyl(Vector3(-w * 0.3, 1.06, -d * 0.2), 0.12, 0.22, P.STEEL, "m", 10)
		mb.cyl(Vector3(w * 0.3, 0.97, -d * 0.2), 0.14, 0.05, Color("2a2a2e"), "m", 10)
		mb.rod(Vector3(w * 0.3 + 0.14, 0.97, -d * 0.2), Vector3(w * 0.3 + 0.36, 0.99, -d * 0.2), 0.012, Color("2a2a2e"), "m", 5)
	mb.cyl(Vector3(0, 2.0, -d * 0.4), 0.09, 1.1, Color("2a2a2e"), "m", 8)
	var _s := sd


static func sink(mb: MB, w: float, d: float, dishes: bool, sd: int) -> void:
	mb.blk(0, 0, w, d, 0.8, Color("e8e2d4"))
	mb.blk(0, 0, w + 0.04, d + 0.04, 0.05, Color("f0eadc"), "s", 0.8)
	mb.blk(0, 0.0, w - 0.14, d - 0.14, 0.01, Color("a8b8bc"), "s", 0.85)
	mb.blk(0, 0, w - 0.14, d - 0.14, 0.02, Color(0.7, 0.85, 0.95, 0.5), "g", 0.83)
	mb.cyl(Vector3(0, 1.0, -d * 0.4), 0.018, 0.34, P.BRASS, "m", 6)
	mb.rod(Vector3(0, 1.17, -d * 0.4), Vector3(0, 1.1, -d * 0.2), 0.016, P.BRASS, "m", 5)
	if dishes:
		for k in 4:
			P.plate(mb, Vector3(0.0, 0.855 + k * 0.016, 0.0), 0.12)
	mb.blk(0, -d * 0.5 + 0.03, w, 0.05, 0.22, Color("f0eadc"), "s", 0.85)
	var _s := sd


static func basin(mb: MB, w: float, d: float) -> void:
	var r := minf(w, d) * 0.5
	mb.cyl(Vector3(0, 0.4, 0), 0.07, 0.8, Color("e8e2d4"), "s", 8)
	mb.cyl(Vector3(0, 0.78, 0), r, 0.1, Color("f0eadc"), "s", 12, r * 0.7)
	mb.cyl(Vector3(0, 0.84, 0), r * 0.86, 0.005, Color(0.7, 0.85, 0.95, 0.5), "g", 12)
	mb.cyl(Vector3(0, 1.0, -r * 0.8), 0.016, 0.3, P.BRASS, "m", 6)


static func kettle(mb: MB, w: float, d: float, roaster: bool) -> void:
	var r := minf(w, d) * 0.5
	mb.blk(0, 0, r * 2.0, r * 2.0, 0.7, Color("3a3a3e"), "m")
	if roaster:
		mb.cyl_dir(Vector3(0, 1.0, 0), Vector3(1, 0, 0), r * 0.7, r * 1.8, Color("4a4a4e"), "m", 12)
		mb.cyl(Vector3(r * 0.5, 1.5, 0), 0.05, 0.6, Color("4a4a4e"), "m", 6)
		mb.box(Vector3(0, 0.45, r * 0.9), Vector3(0.3, 0.2, 0.15), Color("a8885a"), "s")
	else:
		mb.sph(Vector3(0, 0.95, 0), r * 0.95, Color("c07848"), "m", 12, 6, 0.7)
		mb.cyl(Vector3(0, 1.12, 0), r * 0.7, 0.03, Color("8a4a2a"), "m", 12)
		mb.blk(r * 0.9, 0, 0.2, 0.05, 0.05, Color("c07848"), "m", 0.95)


static func potbelly(mb: MB, w: float, d: float) -> void:
	var r := minf(w, d) * 0.5
	mb.cyl(Vector3(0, 0.1, 0), r * 0.6, 0.2, Color("1e1e22"), "m", 8, r * 0.8)
	mb.sph(Vector3(0, 0.55, 0), r * 0.85, Color("26262a"), "m", 10, 6, 1.2)
	mb.cyl(Vector3(0, 1.1, 0), r * 0.25, 0.15, Color("1e1e22"), "m", 8)
	mb.cyl(Vector3(0, 2.0, 0), 0.05, 1.9, Color("2a2a2e"), "m", 6)
	mb.blk(0, r * 0.8, 0.14, 0.02, 0.12, Color("ff8a2a"), "e", 0.2)


static func laundry_cart(mb: MB, w: float, d: float, sd: int, basket: bool) -> void:
	mb.blk(0, 0, w - 0.06, d - 0.06, 0.55, Color("b89a64"), "s", 0.12)
	mb.blk(0, 0, w - 0.14, d - 0.14, 0.02, Color("e8e0d0"), "s", 0.66)
	for k in 4:
		P.bundle(mb, Vector3(-w * 0.25 + (k % 2) * w * 0.5, 0.64, -d * 0.2 + (k / 2) * d * 0.4), P.hf(k, 1, sd) * 3.0, Color("e8e0d0").darkened(0.05 * k))
	if not basket:
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				mb.cyl(Vector3(sx * (w * 0.5 - 0.08), 0.06, sz * (d * 0.5 - 0.08)), 0.06, 0.12, Color("2a2a2e"), "m", 8)


static func clam_baskets(mb: MB, w: float, d: float, sd: int) -> void:
	var n := maxi(1, int(d / 0.5))
	for k in n:
		var z := -d * 0.5 + d * (float(k) + 0.5) / n
		mb.cyl(Vector3(0, 0.2, z), minf(w, d / n) * 0.48, 0.4, Color("b89a64"), "s", 10, minf(w, d / n) * 0.52)
		for i in 7:
			mb.sph(Vector3((P.hf(i, k, sd) - 0.5) * 0.3, 0.42, z + (P.hf(k, i, sd) - 0.5) * 0.3), 0.04, Color("8a8a90"), "s", 5, 3, 0.5)


static func tank(mb: MB, w: float, d: float, sd: int) -> void:
	mb.blk(0, 0, w, d, 0.55, Color("4a3322"))
	mb.blk(0, 0, w - 0.04, d - 0.04, 0.4, Color("3a7a8a"), "s", 0.55)
	mb.blk(0, 0, w - 0.02, d - 0.02, 0.42, Color(0.55, 0.8, 0.9, 0.3), "g", 0.55)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			mb.blk(sx * (w * 0.5 - 0.015), sz * (d * 0.5 - 0.015), 0.03, 0.03, 0.44, Color("3a2418"), "s", 0.55)
	for k in 5:
		mb.atx(Vector3((P.hf(k, 1, sd) - 0.5) * (w - 0.3), 0.6, (P.hf(k, 2, sd) - 0.5) * (d - 0.3)), P.hf(k, 3, sd) * 6.0, Vector3(0.5, 0.3, 1.0))
		mb.sph(Vector3.ZERO, 0.12, Color("a02a24"), "s", 6, 4)
		mb.pop()


static func barber_counter(mb: MB, w: float, d: float, sd: int) -> void:
	mb.blk(0, 0, w, d, 0.86, Color("e0d8c0"))
	mb.blk(0, 0, w + 0.03, d + 0.03, 0.04, Color("f0eadc"), "s", 0.86)
	mb.blk(0, d * 0.5 + 0.004, w - 0.08, 0.012, 0.6, Color("c8d0c4"), "s", 0.1)
	var n := maxi(1, int(w / 0.5)) if w > d else maxi(1, int(d / 0.5))
	for k in n:
		var along := (w if w > d else d)
		var o := -along * 0.5 + along * (float(k) + 0.5) / n
		var px := o if w > d else 0.0
		var pz := 0.0 if w > d else o
		if k % 2 == 0:
			mb.cyl(Vector3(px, 0.92, pz), 0.12, 0.05, Color("f0eadc"), "s", 10, 0.09)
			mb.cyl(Vector3(px, 1.0, pz - 0.05 if w > d else pz), 0.012, 0.16, P.BRASS, "m", 5)
		else:
			P.label_bottle(mb, Vector3(px - 0.04, 0.9, pz), Color("3a6a8a"), P.CREAM, 0.26)
			P.label_bottle(mb, Vector3(px + 0.04, 0.9, pz + 0.04), Color("8a5a3a"), P.CREAM, 0.22)
	var _s := sd


static func mirror(mb: MB, w: float, d: float, br: bool, sd: int, tri: bool) -> void:
	# wall mirrors are thin: the item's depth axis is the wall normal
	if tri:
		var fr := P.BRASS.darkened(0.2)
		mb.blk(0, 0, w * 0.5, 0.05, 1.9, Color("3a2418"))
		mb.blk(0, 0.04, w * 0.45, 0.012, 1.7, Color("bcd0d6"), "m", 0.1)
		for s: float in [-1.0, 1.0]:
			mb.at(Vector3(s * w * 0.3, 0, -d * 0.05), s * 0.5)
			mb.blk(0, 0, w * 0.3, 0.04, 1.8, Color("3a2418"))
			mb.blk(0, 0.03, w * 0.26, 0.012, 1.6, Color("bcd0d6"), "m", 0.1)
			mb.pop()
		mb.blk(0, d * 0.35, w * 0.4, d * 0.3, 0.04, Color("4a3322"))
		var _f := fr
		return
	mb.blk(0, -d * 0.35, w, 0.06, 1.2, Color("3a2418"), "s", 0.85)
	if not br:
		mb.blk(0, -d * 0.35 + 0.035, w - 0.1, 0.008, 1.05, Color("bcd0d6"), "m", 0.92)
	else:
		for k in 5:
			var x := -w * 0.4 + P.hf(k, 1, sd) * w * 0.8
			mb.tri(Vector3(x - 0.08, 1.9, -d * 0.35 + 0.035), Vector3(x + 0.08, 1.9, -d * 0.35 + 0.035), Vector3(x + (P.hf(k, 2, sd) - 0.5) * 0.1, 1.9 - 0.15 - P.hf(k, 3, sd) * 0.5, -d * 0.35 + 0.035), Color("bcd0d6"), "m")
	mb.blk(0, -d * 0.35, w + 0.06, 0.08, 0.06, P.BRASS.darkened(0.2), "m", 2.05)


static func dummy(mb: MB, w: float, d: float, sd: int) -> void:
	mb.cyl(Vector3(0, 0.03, 0), 0.2, 0.06, Color("2a2a2e"), "m", 8)
	mb.cyl(Vector3(0, 0.55, 0), 0.025, 1.0, Color("2a2a2e"), "m", 6)
	var c := P.pick(P.CLOTHS, 2, sd, 4)
	mb.atx(Vector3(0, 1.2, 0), 0.0, Vector3(0.9, 1.0, 0.55))
	mb.sph(Vector3.ZERO, 0.25, c, "s", 8, 5, 1.1)
	mb.pop()
	mb.cyl(Vector3(0, 1.0, 0), 0.19, 0.35, c.darkened(0.1), "s", 8, 0.14)
	mb.cyl(Vector3(0, 1.58, 0), 0.04, 0.12, Color("c8b898"), "s", 6)
	mb.sph(Vector3(0, 1.7, 0), 0.09, Color("c8b898"), "s", 6, 4)
	var _x := w + d


# ------------------------------------------------------------------ bars

static func soda_fountain(mb: MB, w: float, d: float, sd: int, br: bool) -> void:
	# a long counter (the item is oriented with its front toward the stools)
	mb.blk(0, 0, w, d, 0.92, Color("4a3322"))
	mb.blk(0, 0.0, w + 0.04, d + 0.06, 0.05, Color("e8e2d6"), "s", 0.92)
	mb.blk(0, d * 0.5 + 0.004, w - 0.1, 0.016, 0.7, Color("5a4030"), "s", 0.12)
	mb.rod(Vector3(-w * 0.5 + 0.1, 0.14, d * 0.5 + 0.08), Vector3(w * 0.5 - 0.1, 0.14, d * 0.5 + 0.08), 0.016, P.BRASS, "m", 6)
	# taps and syrup pumps
	for k in 3:
		var x := -w * 0.3 + k * w * 0.3
		mb.cyl(Vector3(x, 1.12, -d * 0.2), 0.04, 0.4, P.STEEL, "m", 8)
		mb.cyl(Vector3(x, 1.34, -d * 0.2), 0.06, 0.04, P.BRASS, "m", 8)
		mb.rod(Vector3(x, 1.2, -d * 0.2), Vector3(x, 1.2, 0.0), 0.012, P.BRASS, "m", 5)
	if not br:
		for k in 4:
			P.glass_cup(mb, Vector3(-w * 0.4 + k * w * 0.2, 0.97, d * 0.25), Color("e8d8c0") if k % 2 else Color(0, 0, 0, 0), 0.035)
		P.cake(mb, Vector3(w * 0.3, 0.97, d * 0.1), 0.1, Color("f2e0e0"))
	var _s := sd


static func bar_counter(mb: MB, w: float, d: float, art: String, sd: int, br: bool, stock: int, closed: bool) -> void:
	var speak := art in ["speak_bar", "club_bar", "crate_bar"]
	var body := Color("3a2418")
	var top := Color("5a2e22")
	var rail := P.BRASS
	match art:
		"espresso_bar":
			body = Color("5e4a3a")
			top = Color("e8e2d6")
		"pool_bar":
			body = Color("4a3322")
			top = Color("6a4630")
		"crate_bar":
			body = Color("8a6a44")
			top = Color("a47b50")
		"speak_bar":
			body = Color("2a1a18")
			top = Color("5a2e22")
	mb.blk(0, 0, w, d, 0.96, body)
	# panelled front
	var n := maxi(1, int(round(w / 0.6)))
	for k in n:
		var px := -w * 0.5 + w * (float(k) + 0.5) / n
		mb.blk(px, d * 0.5 + 0.004, w / n - 0.1, 0.016, 0.7, body.lightened(0.07), "s", 0.12)
	mb.blk(0, 0.03, w + 0.06, d + 0.14, 0.06, top, "s", 0.94)
	mb.blk(0, d * 0.5 + 0.03, w + 0.04, 0.04, 0.04, top.darkened(0.2), "s", 0.9)
	if art != "crate_bar":
		mb.rod(Vector3(-w * 0.5 + 0.1, 0.16, d * 0.5 + 0.1), Vector3(w * 0.5 - 0.1, 0.16, d * 0.5 + 0.1), 0.02, rail, "m", 6)
	if closed:
		return
	var y := 1.0
	if art == "espresso_bar":
		# the big brass espresso machine
		mb.blk(-w * 0.2, 0.0, 0.5, 0.36, 0.34, P.BRASS.darkened(0.1), "m", y)
		mb.cyl(Vector3(-w * 0.2, y + 0.46, 0.0), 0.15, 0.24, P.BRASS, "m", 10)
		mb.sph(Vector3(-w * 0.2, y + 0.64, 0.0), 0.09, P.BRASS.lightened(0.2), "m", 8, 4)
		for s: float in [-1.0, 1.0]:
			mb.cyl(Vector3(-w * 0.2 + s * 0.17, y + 0.2, 0.2), 0.02, 0.08, P.IRON, "m", 6)
		for k in 4:
			P.cup(mb, Vector3(w * 0.05 + k * 0.1, y, 0.12), 0.035)
	if speak or art == "pool_bar":
		var nb := int(w / 0.14)
		for k in nb:
			if br and k % 2 == 0:
				continue
			var x := -w * 0.5 + 0.12 + (w - 0.24) * float(k) / maxi(nb - 1, 1)
			var t := int(P.hf(k, 1, sd) * 4.0)
			if t == 0:
				P.glass_cup(mb, Vector3(x, y, 0.1), Color("c8982a"), 0.03)
			elif t == 1 and stock > 3:
				P.label_bottle(mb, Vector3(x, y, -0.05), P.pick(P.BOTTLES, k, 2, sd), P.CREAM, 0.3, 0.036)
			elif t == 2:
				P.glass_cup(mb, Vector3(x, y, 0.15), Color(0, 0, 0, 0), 0.03)
		# beer taps
		if art in ["speak_bar", "club_bar", "pool_bar"]:
			mb.cyl(Vector3(w * 0.3, y + 0.14, -d * 0.2), 0.03, 0.28, P.STEEL, "m", 8)
			for k in 3:
				mb.cyl(Vector3(w * 0.3 - 0.1 + k * 0.1, y + 0.12, -d * 0.1), 0.012, 0.16, P.BRASS, "m", 5)
	elif art != "espresso_bar":
		for k in 6:
			P.glass_cup(mb, Vector3(-w * 0.4 + k * w * 0.16, y, 0.1), Color("c8982a") if k % 2 else Color(0, 0, 0, 0), 0.03)


## The window ledge: the display behind the glass (the wall and glass are drawn by the shell).
static func window_display(mb: MB, w: float, d: float, wall: float, art: String, sd: int, ledge: float) -> void:
	if ledge < 0.1:
		return
	var z0 := -d * 0.5
	var zc0 := z0 + ledge * 0.5
	var zl := ledge
	mb.blk(0, zc0, w - 0.02, zl - 0.02, 0.5, Color("4a3322"))
	mb.blk(0, zc0, w - 0.02, zl - 0.02, 0.03, Color("6a3a34"), "s", 0.5)
	var y0 := 0.53
	var kind := art.trim_prefix("window_")
	var nx := maxi(2, int(w / 0.5))
	for i in nx:
		var xw := -w * 0.5 + w * (float(i) + 0.5) / nx
		var t := (i + int(P.hf(i, 1, sd) * 3.0)) % 3
		var sc := 1.45 if kind not in ["tailor", "club"] else 1.0
		mb.atx(Vector3(xw, y0, zc0), 0.0, Vector3(sc, sc, sc))
		var x := 0.0
		var y := 0.0
		var zc := 0.0
		match kind:
			"bakery":
				if t == 0:
					mb.cyl(Vector3(x, y + 0.05, zc), 0.05, 0.1, P.CREAM, "s", 8, 0.12)
					P.cake(mb, Vector3(x, y + 0.1, zc), 0.12, Color("f2e0e0"))
				else:
					P.loaf(mb, Vector3(x, y, zc), 1.57, 0.3)
					P.baguette(mb, Vector3(x + 0.14, y, zc), 0.2, 0.36)
			"butcher":
				P.links(mb, Vector3(x - 0.15, y + 0.5, zc), Vector3(x + 0.15, y + 0.5, zc), 5)
				P.ham(mb, Vector3(x, y, zc), 0.0)
			"grocer":
				mb.blk(x, zc, 0.36, minf(zl - 0.1, 0.3), 0.14, P.WOOD, "s", y)
				P.heap(mb, x - 0.15, zc - 0.12, x + 0.15, zc + 0.12, y + 0.14, ["apple", "orange", "pear"][t], sd + i)
			"tailor":
				if t != 1:
					mb.at(Vector3(x, y, zc))
					dummy(mb, 0.4, 0.4, sd + i)
					mb.pop()
			"barber":
				P.label_bottle(mb, Vector3(x, y, zc), Color("3a6a8a"), P.CREAM, 0.3)
				mb.cyl(Vector3(x + 0.12, y + 0.04, zc), 0.045, 0.08, Color("f0eadc"), "s", 8)
			"cobbler":
				mb.blk(x, zc, 0.3, 0.2, 0.08 + 0.08 * (i % 2), P.WOOD_L, "s", y)
				P.pair(mb, Vector3(x, y + 0.08 + 0.08 * (i % 2), zc), 0.0, P.pick([Color("4a2e1e"), Color("1c1916"), Color("8a5a3a")], i, 1, sd))
			"pawnshop":
				if t == 0:
					mb.atx(Vector3(x, y + 0.3, zc), 0.0, Vector3(1, 1, 0.3))
					mb.sph(Vector3.ZERO, 0.17, Color("a8662e"), "s", 8, 5)
					mb.pop()
				elif t == 1:
					P.pocket_watch(mb, Vector3(x, y, zc))
					mb.cyl(Vector3(x + 0.15, y + 0.12, zc), 0.07, 0.24, P.BRASS, "m", 8, 0.03)
				else:
					P.cash(mb, Vector3(x, y, zc), 0.3)
					mb.cyl(Vector3(x, y + 0.08, zc + 0.1), 0.05, 0.16, Color("4a6a8a"), "s", 8)
			"laundry":
				P.bundle(mb, Vector3(x, y, zc), 0.3)
				P.towel_stack(mb, Vector3(x + 0.25, y, zc), 3)
			"restaurant", "cafe":
				P.plate(mb, Vector3(x, y, zc), 0.1, Color("c88a4a") if t == 0 else Color(0, 0, 0, 0))
				P.cup(mb, Vector3(x + 0.12, y, zc + 0.04), 0.04)
				if t == 1:
					mb.blk(x, zc - 0.1, 0.22, 0.02, 0.3, Color("2a3228"), "s", y)
			"candy":
				P.jar(mb, Vector3(x, y, zc), P.pick(P.BRIGHTS, i, 4, sd), 0.28, 0.08)
				P.jar(mb, Vector3(x + 0.18, y, zc - 0.03), P.pick(P.BRIGHTS, i + 3, 4, sd), 0.2, 0.06)
			"hardware":
				P.tin(mb, Vector3(x, y, zc), P.pick([Color("b83a28"), Color("2e6a8a"), Color("d6a032")], i, 1, sd))
				mb.rod(Vector3(x + 0.1, y, zc), Vector3(x + 0.3, y + 0.5, zc - 0.05), 0.012, Color("6a4a2a"), "s", 5)
			"drugstore":
				# the great coloured carboys of the druggist
				var c := P.pick([Color("d84a4a"), Color("4a8ad8"), Color("4ac86a")], i, 1, sd)
				mb.sph(Vector3(x, y + 0.2, zc), 0.17, Color(c, 0.75), "g", 10, 6)
				mb.sph(Vector3(x, y + 0.2, zc), 0.12, c, "e", 8, 4)
				mb.cyl(Vector3(x, y + 0.42, zc), 0.04, 0.14, Color(c, 0.75), "g", 8)
			"cigar":
				P.cigarbox(mb, Vector3(x, y, zc), 0.0, true)
				P.cigarbox(mb, Vector3(x, y + 0.06, zc), 0.0, false)
			"fish":
				mb.blk(x, zc, 0.4, 0.3, 0.06, Color("a8b0a8"), "m", y)
				P.fish(mb, Vector3(x, y + 0.06, zc), 1.57, P.SILVER)
			"club":
				mb.cyl(Vector3(x, y + 0.2, zc), 0.015, 0.4, P.BRASS, "m", 5)
				mb.cyl(Vector3(x, y + 0.45, zc), 0.1, 0.1, Color("c9a54a"), "bulb", 8, 0.04)
			"pool":
				P.ball(mb, Vector3(x, y, zc), P.pick(P.BRIGHTS, i, 1, sd), 0.05)
			"precinct":
				mb.blk(x, zc, 0.3, 0.02, 0.4, Color("2a3228"), "s", y)
			_:
				P.box(mb, Vector3(x, y, zc), Vector3(0.2, 0.2, 0.2), P.pick(P.BRIGHTS, i, 1, sd))
		mb.pop()
	var _w := wall
