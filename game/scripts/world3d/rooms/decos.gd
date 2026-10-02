extends RefCounted
## Decoration (rugs, chairs, stools, the cat, coat racks, palms, pictures, pallets...) and the hanging lamps.
## Same prop frame as props_a.gd: origin on the floor at the centre, +Z the front, -Z the back/wall.

const MB := preload("res://scripts/world3d/rooms/mb.gd")
const P := preload("res://scripts/world3d/rooms/parts.gd")
const B := preload("res://scripts/world3d/rooms/props_b.gd")

## Deco types that hang on a wall (placed against it, thin).
const ON_WALL := ["photos", "portrait", "clock", "board", "calendar", "chalkboard"]
## Deco types drawn flat on the floor.
const FLOOR := ["rug", "doormat", "bays", "puddle", "sawdust", "hair", "beads_floor"]


static func draw(mb: MB, d: Dictionary, w: float, dp: float, closed: bool) -> void:
	var t := String(d["type"])
	var st := String(d.get("style", ""))
	var sd := int(d.get("seed", 0))
	match t:
		"chair": chair(mb, st, sd, w, dp)
		"stool": stool(mb, st, w)
		"cat": cat(mb, sd, bool(d.get("on_ledge", false)))
		"sacks": B.sack_pile(mb, w, dp, sd, "flour_sacks" if st == "flour" else ("coffee_sacks" if st == "coffee" else "potato_sacks"))
		"chalkboard": chalkboard(mb, w, dp)
		"scale": scale(mb, st, w)
		"hanging": hanging(mb, w, dp, sd)
		"pedestal": pedestal(mb, w)
		"hatstand", "coat_rack": coat_rack(mb, sd)
		"spittoon": spittoon(mb)
		"newspapers": newspapers(mb, w, dp, sd)
		"leather": leather(mb, w, dp, sd)
		"clutter": clutter(mb, st, w, dp, sd)
		"basket": basket(mb, w, dp, sd)
		"bundles": bundles(mb, w, dp, sd)
		"gumball": gumball(mb)
		"brooms": brooms(mb, w, dp)
		"rope": rope(mb)
		"lines": lines(mb, w, dp, sd)
		"pots": pots(mb, w, dp)
		"slips": slips(mb, w, dp, sd)
		"palm": palm(mb, sd)
		"fan": pass   # the ceiling fan only hides the floor from the tilted camera
		"portrait": portrait(mb, w, dp)
		"photos": photos(mb, w, dp, sd)
		"flag": flag(mb)
		"board": board(mb, st, w, dp, sd)
		"cooler": cooler(mb)
		"clock": wall_clock(mb, w)
		"bucket": bucket(mb)
		"pallets": pallets(mb, w, dp, sd)
		"handtruck": handtruck(mb)
		"hoist": hoist(mb, w, dp)
		"calendar": calendar(mb, w, dp)
		"smoke": smoke(mb, w, dp, sd)
		"beads": beads(mb, w, dp, sd)
		"paint": paint(mb, st, sd)
		"ladder": ladder(mb, w, dp)
		"shoepile": shoepile(mb, w, dp, sd)
		"chalk": chalk(mb)
		"steam": steam(mb, w, dp, sd)
		"puddle": puddle(mb, w, dp)
		"sawdust": sawdust(mb, w, dp, sd)
		"hair": hair(mb, w, dp, sd)
		"bays": bays(mb, w, dp)
		_: pass
	var _c := closed


# ------------------------------------------------------------------ floor things

static func rug(mb: MB, x0: float, z0: float, x1: float, z1: float, style: String, yaw_long_x: bool) -> void:
	var key := "rug:" + ("persian" if style in ["", "persian"] else style)
	# the texture is portrait (long along v); turn it for wide rugs
	var y := 0.014
	if x1 - x0 > z1 - z0:
		mb.quad(Vector3(x0, y, z1), Vector3(x0, y, z0), Vector3(x1, y, z0), Vector3(x1, y, z1), Color(1, 1, 1), key, Vector2(0, 0), Vector2(1, 1))
	else:
		mb.quad(Vector3(x0, y, z1), Vector3(x1, y, z1), Vector3(x1, y, z0), Vector3(x0, y, z0), Color(1, 1, 1), key, Vector2(0, 1), Vector2(1, 0))
	# the rug's edge, a hair thick
	var e := Color("3a2a22")
	mb.box(Vector3((x0 + x1) * 0.5, 0.007, z0), Vector3(x1 - x0, 0.014, 0.012), e, "s", true)
	mb.box(Vector3((x0 + x1) * 0.5, 0.007, z1), Vector3(x1 - x0, 0.014, 0.012), e, "s", true)
	mb.box(Vector3(x0, 0.007, (z0 + z1) * 0.5), Vector3(0.012, 0.014, z1 - z0), e, "s", true)
	mb.box(Vector3(x1, 0.007, (z0 + z1) * 0.5), Vector3(0.012, 0.014, z1 - z0), e, "s", true)
	var _y := yaw_long_x


static func doormat(mb: MB, w: float, dp: float) -> void:
	mb.blk(0, 0, w, dp, 0.018, Color("7a6648"), "s")
	for k in int(w / 0.06):
		mb.blk(-w * 0.5 + 0.03 + k * 0.06, 0, 0.012, dp - 0.04, 0.004, Color("5a4a34"), "s", 0.018)


static func bays(mb: MB, w: float, dp: float) -> void:
	var c := Color("b8962a")
	var t := 0.06
	mb.flat(-w * 0.5, -dp * 0.5, w * 0.5, -dp * 0.5 + t, 0.008, c)
	mb.flat(-w * 0.5, dp * 0.5 - t, w * 0.5, dp * 0.5, 0.008, c)
	mb.flat(-w * 0.5, -dp * 0.5, -w * 0.5 + t, dp * 0.5, 0.008, c)
	mb.flat(w * 0.5 - t, -dp * 0.5, w * 0.5, dp * 0.5, 0.008, c)
	var n := maxi(1, int(w / 2.2))
	for k in range(1, n):
		var x := -w * 0.5 + w * float(k) / n
		mb.flat(x - t * 0.5, -dp * 0.5, x + t * 0.5, dp * 0.5, 0.008, c)


static func puddle(mb: MB, w: float, dp: float) -> void:
	mb.atx(Vector3(0, 0.006, 0), 0.0, Vector3(w * 0.5, 0.01, dp * 0.5))
	mb.cyl(Vector3.ZERO, 1.0, 1.0, Color(0.55, 0.72, 0.8, 0.55), "g", 14)
	mb.pop()


static func sawdust(mb: MB, w: float, dp: float, sd: int) -> void:
	var n := int(w * dp * 14.0)
	for k in mini(n, 70):
		mb.blk((P.hf(k, 1, sd) - 0.5) * w, (P.hf(k, 2, sd) - 0.5) * dp, 0.04 + 0.03 * P.hf(k, 3, sd), 0.03, 0.003, Color("a89468").darkened(0.2 * P.hf(k, 4, sd)), "s")


static func hair(mb: MB, w: float, dp: float, sd: int) -> void:
	for k in 24:
		mb.blk((P.hf(k, 1, sd) - 0.5) * w, (P.hf(k, 2, sd) - 0.5) * dp, 0.05, 0.015, 0.003, Color("1c1814") if k % 3 else Color("5a4030"), "s")


# ------------------------------------------------------------------ seats

static func chair(mb: MB, st: String, sd: int, w: float, dp: float) -> void:
	match st:
		"bentwood":
			var wood := Color("5a3a24")
			for sx: float in [-1.0, 1.0]:
				for sz: float in [-1.0, 1.0]:
					mb.rod(Vector3(sx * 0.16, 0.0, sz * 0.15), Vector3(sx * 0.18, 0.46, sz * 0.17), 0.013, wood, "s", 5)
			mb.cyl(Vector3(0, 0.46, 0), 0.2, 0.035, Color("8a6a44"), "s", 10)
			mb.rod(Vector3(-0.16, 0.46, -0.17), Vector3(-0.15, 0.95, -0.18), 0.012, wood, "s", 5)
			mb.rod(Vector3(0.16, 0.46, -0.17), Vector3(0.15, 0.95, -0.18), 0.012, wood, "s", 5)
			mb.box(Vector3(0, 0.84, -0.18), Vector3(0.34, 0.1, 0.02), wood, "s")
		"club", "leather", "arm":
			var c := Color("5a2418") if st != "arm" else Color("5a4a6a")
			if st == "arm":
				c = P.pick([Color("4a5a4a"), Color("6a3a3a"), Color("5a4a6a")], sd, 3, 5)
			mb.blk(0, 0, 0.54, 0.54, 0.28, c.darkened(0.15), "s")
			mb.blk(0, 0.02, 0.5, 0.46, 0.14, c, "s", 0.28)
			mb.blk(0, -0.22, 0.54, 0.12, 0.62, c, "s", 0.28)
			for s: float in [-1.0, 1.0]:
				mb.blk(s * 0.26, 0.0, 0.1, 0.5, 0.2, c.lightened(0.05), "s", 0.28)
		"boss":
			var c2 := Color("5a1f1c")
			mb.cyl(Vector3(0, 0.03, 0), 0.26, 0.06, Color("2a2a2e"), "m", 8)
			mb.cyl(Vector3(0, 0.25, 0), 0.04, 0.45, Color("3a3a3e"), "m", 6)
			mb.blk(0, 0, 0.5, 0.5, 0.12, c2, "s", 0.46)
			mb.blk(0, -0.24, 0.5, 0.1, 0.62, c2, "s", 0.52)
			mb.blk(0, -0.26, 0.4, 0.08, 0.2, c2.lightened(0.06), "s", 1.1)
			for s: float in [-1.0, 1.0]:
				mb.blk(s * 0.27, -0.02, 0.06, 0.3, 0.05, c2.darkened(0.2), "s", 0.66)
		"wood", "crate":
			var wood2 := Color("a47b50") if st == "wood" else Color("8a6a44")
			for sx: float in [-1.0, 1.0]:
				for sz: float in [-1.0, 1.0]:
					mb.blk(sx * 0.18, sz * 0.18, 0.04, 0.04, 0.44, wood2.darkened(0.2))
			mb.blk(0, 0, 0.42, 0.42, 0.035, wood2, "s", 0.44)
			mb.blk(0, -0.2, 0.4, 0.03, 0.4, wood2, "s", 0.48)
		_:
			mb.blk(0, 0, 0.4, 0.4, 0.44, Color("6a4a30"))
	var _x := w + dp


static func stool(mb: MB, st: String, w: float) -> void:
	match st:
		"bar", "crate":
			var h := 0.7 if st == "bar" else 0.5
			mb.cyl(Vector3(0, h * 0.5, 0), 0.025, h, P.BRASS if st == "bar" else P.WOOD_D, "m", 6)
			mb.cyl(Vector3(0, 0.03, 0), 0.15, 0.04, P.BRASS.darkened(0.3), "m", 8)
			mb.cyl(Vector3(0, h + 0.03, 0), 0.17, 0.06, Color("5a1f1c") if st == "bar" else P.OAK, "s", 10)
			if st == "bar":
				mb.hoop(Vector3(0, h * 0.35, 0), 0.13, 0.012, 0.012, P.BRASS, "m", 8)
		"fountain":
			mb.cyl(Vector3(0, 0.33, 0), 0.03, 0.66, Color("c8ccd0"), "m", 6)
			mb.cyl(Vector3(0, 0.02, 0), 0.16, 0.04, Color("c8ccd0"), "m", 8)
			mb.cyl(Vector3(0, 0.69, 0), 0.17, 0.07, Color("b8282a"), "s", 10)
		_:
			for sx: float in [-1.0, 1.0]:
				for sz: float in [-1.0, 1.0]:
					mb.rod(Vector3(sx * 0.13, 0.0, sz * 0.13), Vector3(sx * 0.1, 0.44, sz * 0.1), 0.014, P.WOOD_D, "s", 5)
			mb.cyl(Vector3(0, 0.45, 0), 0.17, 0.04, P.OAK, "s", 10)
	var _w := w


static func cat(mb: MB, sd: int, on_ledge: bool) -> void:
	var c := P.pick([Color("c88a4a"), Color("6a6a6e"), Color("2a2a2e"), Color("d8d0c0")], sd, 1, 2)
	var y := 0.5 if on_ledge else 0.0
	mb.atx(Vector3(0, y + 0.08, 0), 0.0, Vector3(1.0, 0.6, 1.5))
	mb.sph(Vector3.ZERO, 0.11, c, "s", 8, 5)
	mb.pop()
	mb.sph(Vector3(0, y + 0.1, 0.17), 0.065, c, "s", 6, 4)
	mb.tri(Vector3(-0.04, y + 0.15, 0.17), Vector3(-0.015, y + 0.15, 0.17), Vector3(-0.03, y + 0.2, 0.17), c, "s")
	mb.tri(Vector3(0.04, y + 0.15, 0.17), Vector3(0.015, y + 0.15, 0.17), Vector3(0.03, y + 0.2, 0.17), c, "s")
	mb.cyl_dir(Vector3(0.1, y + 0.04, -0.13), Vector3(1, 0, -1), 0.02, 0.2, c.darkened(0.1), "s", 5)


# ------------------------------------------------------------------ shop odds and ends

static func chalkboard(mb: MB, w: float, dp: float) -> void:
	mb.blk(0, -dp * 0.5 + 0.03, w, 0.04, 0.6, Color("2a3228"), "s", 1.0)
	mb.blk(0, -dp * 0.5 + 0.052, w + 0.04, 0.012, 0.04, P.WOOD, "s", 1.6)
	mb.blk(0, -dp * 0.5 + 0.052, w + 0.04, 0.012, 0.04, P.WOOD, "s", 0.98)
	for k in 5:
		mb.blk(0, -dp * 0.5 + 0.054, w * (0.4 + 0.3 * P.hf(k, 1, 4)), 0.003, 0.012, Color("e0dcc8"), "s", 1.5 - k * 0.1)


static func scale(mb: MB, st: String, w: float) -> void:
	if st == "penny":
		mb.cyl(Vector3(0, 0.55, 0), 0.05, 1.1, Color("2a2a2e"), "m", 8)
		mb.cyl(Vector3(0, 1.15, 0), 0.12, 0.2, Color("e8e2d4"), "s", 12)
		mb.cyl(Vector3(0, 0.03, 0), 0.14, 0.06, Color("2a2a2e"), "m", 8)
		return
	if st == "platform":
		mb.blk(0, 0, w, w, 0.1, Color("3a3e40"), "m")
		mb.blk(0, w * 0.4, 0.5, 0.1, 0.9, Color("3a3e40"), "m", 0.1)
		mb.cyl(Vector3(0, 1.05, w * 0.4), 0.12, 0.05, Color("e8e2d4"), "s", 12)
		return
	mb.blk(0, 0, 0.4, 0.3, 0.12, P.IRON, "m")
	mb.cyl(Vector3(0, 0.5, 0), 0.03, 0.7, P.IRON, "m", 6)
	mb.cyl(Vector3(-0.15, 0.85, 0), 0.12, 0.02, P.BRASS, "m", 10)
	mb.cyl(Vector3(0.15, 0.85, 0), 0.12, 0.02, P.BRASS, "m", 10)


static func hanging(mb: MB, w: float, dp: float, sd: int) -> void:
	mb.rod(Vector3(-w * 0.5, 2.0, 0), Vector3(w * 0.5, 2.0, 0), 0.012, P.IRON, "m", 5)
	var n := maxi(3, int(w / 0.2))
	for k in n:
		var x := -w * 0.5 + w * (float(k) + 0.5) / n
		P.salami(mb, Vector3(x, 1.95, 0.0), 0.28 + 0.1 * P.hf(k, 1, sd))


static func pedestal(mb: MB, w: float) -> void:
	mb.cyl(Vector3(0, 0.4, 0), w * 0.35, 0.8, Color("e8e2d6"), "s", 8, w * 0.28)
	mb.cyl(Vector3(0, 0.82, 0), w * 0.42, 0.04, Color("d8d0c0"), "s", 8)
	mb.cyl(Vector3(0, 0.89, 0), 0.1, 0.1, Color("4a4a4e"), "s", 8, 0.12)


static func coat_rack(mb: MB, sd: int) -> void:
	mb.cyl(Vector3(0, 0.02, 0), 0.2, 0.04, P.WOOD_D, "s", 8)
	mb.cyl(Vector3(0, 0.85, 0), 0.025, 1.7, P.WOOD_D, "s", 6)
	for k in 4:
		var a := k * PI * 0.5 + 0.4
		mb.rod(Vector3(0, 1.62, 0), Vector3(cos(a) * 0.18, 1.74, sin(a) * 0.18), 0.01, P.BRASS, "m", 4)
	# a coat and a hat
	mb.blk(0.0, 0.08, 0.3, 0.1, 0.55, P.pick([Color("3a3d45"), Color("4a4037"), Color("2a2a30")], sd, 1, 1), "s", 0.98)
	mb.cyl(Vector3(0.1, 1.76, -0.14), 0.12, 0.012, Color("5a4a3a"), "s", 8)
	mb.cyl(Vector3(0.1, 1.82, -0.14), 0.07, 0.09, Color("6a5a48"), "s", 8)


static func spittoon(mb: MB) -> void:
	mb.cyl(Vector3(0, 0.07, 0), 0.12, 0.14, P.BRASS.darkened(0.1), "m", 10, 0.09)
	mb.cyl(Vector3(0, 0.16, 0), 0.14, 0.04, P.BRASS, "m", 10, 0.1)


static func newspapers(mb: MB, w: float, dp: float, sd: int) -> void:
	for k in 4:
		P.newspaper(mb, Vector3((P.hf(k, 1, sd) - 0.5) * w * 0.5, 0.005 + k * 0.012, (P.hf(k, 2, sd) - 0.5) * dp * 0.4), (P.hf(k, 3, sd) - 0.5) * 0.6)


static func leather(mb: MB, w: float, dp: float, sd: int) -> void:
	for k in 4:
		mb.blk(0, -dp * 0.35 + k * dp * 0.23, w * 0.9, dp * 0.2, 0.05 + 0.03 * k, P.pick([Color("6a3a22"), Color("3a2418"), Color("9a6a3a"), Color("4a2e1e")], k, 1, sd), "s")


static func clutter(mb: MB, st: String, w: float, dp: float, sd: int) -> void:
	if st == "gramophone":
		mb.blk(0, 0, 0.4, 0.4, 0.45, P.WOOD_D)
		mb.cyl(Vector3(0, 0.47, 0), 0.16, 0.02, Color("1a1a1a"), "s", 10)
		mb.cyl_dir(Vector3(0, 0.78, -0.12), Vector3(0, 0.5, 0.8), 0.14, 0.38, P.BRASS, "m", 10, 0.015)
	elif st == "bicycle":
		for z: float in [-0.45, 0.45]:
			mb.hoop(Vector3(0, 0.33, z), 0.33, 0.02, 0.025, Color("1a1a1a"), "s", 12)
		mb.box(Vector3(0, 0.33, 0.0), Vector3(0.025, 0.025, 0.9), Color("2a2a2e"), "m")
		mb.box(Vector3(0, 0.55, 0.0), Vector3(0.025, 0.025, 0.7), Color("2a4a6a"), "m")
		mb.box(Vector3(0, 0.78, -0.35), Vector3(0.05, 0.03, 0.2), Color("1a1a1a"), "s")
	else:
		B.crate(mb, Vector3(0, 0, 0), Vector3(w * 0.8, 0.4, dp * 0.8), 0.1, sd)


static func basket(mb: MB, w: float, dp: float, sd: int) -> void:
	mb.cyl(Vector3(0, 0.25, 0), minf(w, dp) * 0.45, 0.5, Color("b89a64"), "s", 10, minf(w, dp) * 0.5)
	mb.cyl(Vector3(0, 0.5, 0), minf(w, dp) * 0.4, 0.04, Color("e8e0d0"), "s", 10)
	P.bundle(mb, Vector3(0.0, 0.5, 0.0), 0.3 * sd, Color("e8e0d0"))


static func bundles(mb: MB, w: float, dp: float, sd: int) -> void:
	var n := maxi(2, int(dp / 0.3))
	for k in n:
		P.bundle(mb, Vector3(0, 0, -dp * 0.5 + dp * (float(k) + 0.5) / n), P.hf(k, 1, sd) - 0.5, Color("c8b898").lerp(Color("e8e0d0"), P.hf(k, 2, sd)))
		if k % 2 == 0:
			P.bundle(mb, Vector3(0.02, 0.14, -dp * 0.5 + dp * (float(k) + 0.5) / n), 0.2, Color("e8e0d0"))
	var _w := w


static func gumball(mb: MB) -> void:
	mb.cyl(Vector3(0, 0.3, 0), 0.07, 0.6, Color("b8282a"), "m", 8)
	mb.cyl(Vector3(0, 0.03, 0), 0.14, 0.06, Color("2a2a2e"), "m", 8)
	mb.sph(Vector3(0, 0.78, 0), 0.17, Color(0.8, 0.9, 0.95, 0.3), "g", 10, 6)
	for k in 14:
		mb.sph(Vector3((P.hf(k, 1, 3) - 0.5) * 0.18, 0.68 + P.hf(k, 2, 3) * 0.15, (P.hf(k, 3, 3) - 0.5) * 0.18), 0.03, P.pick(P.BRIGHTS, k, 1, 3), "s", 5, 3)
	mb.cyl(Vector3(0, 0.97, 0), 0.05, 0.05, Color("b8282a"), "m", 8)


static func brooms(mb: MB, w: float, dp: float) -> void:
	for k in 3:
		var x := -w * 0.3 + k * w * 0.3
		mb.rod(Vector3(x, 0.02, dp * 0.3), Vector3(x, 1.5, -dp * 0.4), 0.014, P.WOOD, "s", 5)
		mb.cyl_dir(Vector3(x, 0.15, dp * 0.25), Vector3(0, 1, 0.3), 0.045, 0.28, Color("b09a54"), "s", 6, 0.03)


static func rope(mb: MB) -> void:
	for k in 4:
		mb.hoop(Vector3(0, 0.03 + k * 0.05, 0), 0.16, 0.04, 0.045, Color("b59a6a"), "s", 8)


static func lines(mb: MB, w: float, dp: float, sd: int) -> void:
	# a clothes line across the back room with a few garments
	for k in 2:
		var z := -dp * 0.3 + k * dp * 0.6
		mb.rod(Vector3(-w * 0.5, 2.1, z), Vector3(w * 0.5, 2.1, z), 0.008, Color("b59a6a"), "s", 4)
		for i in int(w / 0.5):
			var x := -w * 0.5 + 0.3 + i * 0.5
			var c := Color("e8e2d4") if P.hf(i, k, sd) > 0.3 else Color("c8d4e0")
			mb.quad2(Vector3(x, 2.1, z), Vector3(x + 0.36, 2.1, z), Vector3(x + 0.34, 1.55, z), Vector3(x + 0.02, 1.55, z), c, "s")


static func pots(mb: MB, w: float, dp: float) -> void:
	mb.blk(0, -dp * 0.5 + 0.03, w, 0.04, 0.05, P.IRON, "m", 1.55)
	mb.rod(Vector3(-w * 0.5, 1.7, -dp * 0.5 + 0.06), Vector3(w * 0.5, 1.7, -dp * 0.5 + 0.06), 0.012, P.IRON, "m", 5)
	for k in 3:
		var x := -w * 0.3 + k * w * 0.3
		mb.cyl(Vector3(x, 1.5, -dp * 0.5 + 0.1), 0.09, 0.14, P.STEEL.darkened(0.15), "m", 8)
		mb.rod(Vector3(x, 1.7, -dp * 0.5 + 0.06), Vector3(x, 1.58, -dp * 0.5 + 0.1), 0.006, P.IRON, "m", 4)


static func slips(mb: MB, w: float, dp: float, sd: int) -> void:
	for k in 8:
		P.paper(mb, Vector3((P.hf(k, 1, sd) - 0.5) * w * 0.8, 0.82 + k * 0.002, (P.hf(k, 2, sd) - 0.5) * dp * 0.6), P.hf(k, 3, sd) * 3.0, Vector3(0.1, 0.002, 0.14))


static func palm(mb: MB, sd: int) -> void:
	mb.cyl(Vector3(0, 0.18, 0), 0.2, 0.36, Color("b8704a"), "m", 10, 0.16)
	mb.cyl(Vector3(0, 0.37, 0), 0.17, 0.02, Color("3a2a1e"), "s", 10)
	mb.cyl(Vector3(0, 0.7, 0), 0.03, 0.7, Color("6a5a3a"), "s", 5)
	for k in 8:
		var a := k * TAU / 8.0 + P.hf(k, 1, sd)
		var dirv := Vector3(cos(a), 0, sin(a))
		var base := Vector3(0, 1.0 + 0.04 * (k % 2), 0)
		var tip := base + dirv * 0.55 + Vector3(0, -0.2 + 0.1 * (k % 3), 0)
		var side := Vector3(-dirv.z, 0, dirv.x) * 0.07
		var c := Color("2f5a3a").lerp(Color("4a7a3a"), P.hf(k, 2, sd))
		mb.quad2(base, base + dirv * 0.28 + side + Vector3(0, 0.1, 0), tip, base + dirv * 0.28 - side + Vector3(0, 0.1, 0), c, "s")


static func fan(mb: MB, w: float, dp: float) -> void:
	mb.cyl(Vector3(0, 2.9, 0), 0.07, 0.1, Color("6a5a3a"), "m", 8)
	mb.rod(Vector3(0, 2.95, 0), Vector3(0, 3.2, 0), 0.012, P.IRON, "m", 4)
	for k in 4:
		mb.at(Vector3(0, 2.86, 0), k * PI * 0.5 + 0.4)
		mb.box(Vector3(0, 0, 0.22), Vector3(0.1, 0.01, 0.36), Color("4a3a2a"), "s", true)
		mb.pop()
	var _x := w + dp


# ------------------------------------------------------------------ on the walls

static func portrait(mb: MB, w: float, dp: float) -> void:
	mb.blk(0, -dp * 0.5 + 0.03, w, 0.05, 0.8, Color("c9a54a"), "m", 1.3)
	mb.blk(0, -dp * 0.5 + 0.058, w - 0.12, 0.012, 0.68, Color("3a3028"), "s", 1.36)
	mb.sph(Vector3(0, 1.82, -dp * 0.5 + 0.07), 0.09, Color("c8a888"), "s", 6, 4)
	mb.blk(0, -dp * 0.5 + 0.07, 0.3, 0.012, 0.3, Color("1c1814"), "s", 1.4)


static func photos(mb: MB, w: float, dp: float, sd: int) -> void:
	var n := maxi(2, int(maxf(w, dp) / 0.4))
	var along_x := w > dp
	for k in n:
		var o := -(w if along_x else dp) * 0.5 + (w if along_x else dp) * (float(k) + 0.5) / n
		var px := o if along_x else 0.0
		var pz := -dp * 0.5 + 0.03 if along_x else o
		var sz := Vector3(0.26, 0.34, 0.03) if along_x else Vector3(0.03, 0.34, 0.26)
		if not along_x:
			pz = o
			px = -w * 0.5 + 0.03
		mb.box(Vector3(px, 1.5 + 0.12 * P.hf(k, 1, sd), pz), sz, Color("3a2418") if k % 2 else P.BRASS.darkened(0.2), "s")
		var sz2 := Vector3(0.2, 0.28, 0.032) if along_x else Vector3(0.032, 0.28, 0.2)
		mb.box(Vector3(px, 1.5 + 0.12 * P.hf(k, 1, sd), pz), sz2, Color("b8a888"), "s")


static func flag(mb: MB) -> void:
	mb.cyl(Vector3(0, 0.9, 0), 0.015, 1.8, P.BRASS, "m", 5)
	mb.cyl(Vector3(0, 0.03, 0), 0.1, 0.06, P.IRON, "m", 8)
	mb.quad2(Vector3(0, 1.8, 0), Vector3(0.0, 1.8, 0.5), Vector3(0.0, 1.35, 0.52), Vector3(0, 1.35, 0.0), Color("a02a2a"), "s")
	mb.quad2(Vector3(0, 1.62, 0.0), Vector3(0.0, 1.62, 0.52), Vector3(0.0, 1.5, 0.52), Vector3(0, 1.5, 0.0), Color("f0ead8"), "s")


static func board(mb: MB, st: String, w: float, dp: float, sd: int) -> void:
	var along_x := w > dp
	var cx := 0.0
	var cz := -dp * 0.5 + 0.03 if along_x else 0.0
	var bw := w if along_x else dp
	mb.blk(0 if along_x else -w * 0.5 + 0.03, 0.0 if along_x else 0.0, bw if along_x else 0.04, 0.04 if along_x else bw, 1.2, Color("5a4030"), "s", 0.9)
	for k in 6:
		var o := -bw * 0.5 + bw * (float(k) + 0.5) / 6.0
		var c := Color("e0d8c0") if st == "wanted" else P.pick(P.BRIGHTS, k, 1, sd)
		if along_x:
			mb.blk(o, cz + 0.03, 0.2, 0.01, 0.28, c, "s", 1.0 + 0.3 * P.hf(k, 2, sd))
		else:
			mb.blk(-w * 0.5 + 0.06, o, 0.01, 0.2, 0.28, c, "s", 1.0 + 0.3 * P.hf(k, 2, sd))
	var _c := cx


static func cooler(mb: MB) -> void:
	mb.blk(0, 0, 0.36, 0.36, 0.7, Color("e0dcc8"))
	mb.cyl(Vector3(0, 0.95, 0), 0.14, 0.4, Color(0.7, 0.88, 0.95, 0.4), "g", 10)
	mb.cyl(Vector3(0, 0.9, 0), 0.12, 0.3, Color(0.5, 0.78, 0.9, 0.5), "s", 10)
	mb.blk(0, 0.2, 0.05, 0.03, 0.04, P.STEEL, "m", 0.5)


static func wall_clock(mb: MB, w: float) -> void:
	mb.cyl_dir(Vector3(0, 1.9, -0.02), Vector3(0, 0, 1), minf(w, 0.4) * 0.5, 0.05, Color("3a2418"), "s", 12)
	mb.cyl_dir(Vector3(0, 1.9, 0.012), Vector3(0, 0, 1), minf(w, 0.4) * 0.42, 0.02, Color("f0ead8"), "s", 12)
	mb.box(Vector3(0, 1.93, 0.026), Vector3(0.012, 0.1, 0.006), Color("1a1a1a"), "s")
	mb.box(Vector3(0.04, 1.9, 0.026), Vector3(0.08, 0.012, 0.006), Color("1a1a1a"), "s")


static func calendar(mb: MB, w: float, dp: float) -> void:
	var along_x := w > dp
	if along_x:
		mb.blk(0, -dp * 0.5 + 0.02, 0.24, 0.015, 0.34, Color("e8dcc0"), "s", 1.3)
		mb.blk(0, -dp * 0.5 + 0.03, 0.2, 0.01, 0.1, Color("a82a2a"), "s", 1.54)
	else:
		mb.blk(-w * 0.5 + 0.02, 0, 0.015, 0.24, 0.34, Color("e8dcc0"), "s", 1.3)
		mb.blk(-w * 0.5 + 0.03, 0, 0.01, 0.2, 0.1, Color("a82a2a"), "s", 1.54)


static func bucket(mb: MB) -> void:
	mb.cyl(Vector3(0, 0.14, 0), 0.12, 0.28, Color("8a8e92"), "m", 8, 0.15)
	mb.cyl(Vector3(0, 0.27, 0), 0.11, 0.01, Color("2a2a2e"), "s", 8)


static func chalk(mb: MB) -> void:
	mb.blk(0, 0, 0.12, 0.12, 0.05, Color("3a6a9a"), "s", 0.0)


static func paint(mb: MB, st: String, sd: int) -> void:
	for k in 3:
		var c := Color("c8c0a8") if st == "polish" else P.pick([Color("a82a2a"), Color("2a6a3a"), Color("d6a032"), Color("e0dcc8")], k, 2, sd)
		mb.cyl(Vector3(-0.1 + k * 0.1, 0.07, (k % 2) * 0.06), 0.045, 0.14, Color("8a8e92"), "m", 8)
		mb.cyl(Vector3(-0.1 + k * 0.1, 0.145, (k % 2) * 0.06), 0.04, 0.008, c, "s", 8)


static func ladder(mb: MB, w: float, dp: float) -> void:
	for s: float in [-1.0, 1.0]:
		mb.rod(Vector3(s * 0.2, 0.02, 0.3), Vector3(s * 0.2, 2.1, -0.15), 0.025, P.WOOD, "s", 5)
	for k in 7:
		var t := float(k + 1) / 8.0
		mb.rod(Vector3(-0.2, 2.1 * t, 0.3 - 0.45 * t), Vector3(0.2, 2.1 * t, 0.3 - 0.45 * t), 0.014, P.WOOD_L, "s", 4)
	var _x := w + dp


static func shoepile(mb: MB, w: float, dp: float, sd: int) -> void:
	for k in 6:
		P.shoe(mb, Vector3((P.hf(k, 1, sd) - 0.5) * w * 0.8, 0.0 + 0.03 * (k % 2), (P.hf(k, 2, sd) - 0.5) * dp * 0.8), P.hf(k, 3, sd) * 6.0, P.pick([Color("4a2e1e"), Color("1c1916"), Color("8a5a3a")], k, 1, sd))


static func steam(mb: MB, w: float, dp: float, sd: int) -> void:
	for k in 4:
		mb.sph(Vector3((P.hf(k, 1, sd) - 0.5) * w, 1.8 + k * 0.2, (P.hf(k, 2, sd) - 0.5) * dp), 0.3 + 0.1 * k, Color(1, 1, 1, 0.1), "g", 8, 5)


static func smoke(mb: MB, w: float, dp: float, sd: int) -> void:
	for k in 5:
		mb.atx(Vector3((P.hf(k, 1, sd) - 0.5) * w * 0.8, 2.0 + 0.08 * k, (P.hf(k, 2, sd) - 0.5) * dp * 0.8), 0.0, Vector3(1.0, 0.18, 1.0))
		mb.sph(Vector3.ZERO, 0.8 + 0.3 * P.hf(k, 3, sd), Color(0.9, 0.82, 0.78, 0.07), "g", 12, 7)
		mb.pop()


static func beads(mb: MB, w: float, dp: float, sd: int) -> void:
	mb.rod(Vector3(-w * 0.5, 1.9, 0), Vector3(w * 0.5, 1.9, 0), 0.008, P.IRON, "m", 4)
	for k in int(w / 0.12):
		mb.cyl(Vector3(-w * 0.5 + 0.06 + k * 0.12, 1.9, 0), 0.025, 0.02, P.pick(P.BRIGHTS, k, 1, sd), "s", 5)
	var _x := dp


static func pallets(mb: MB, w: float, dp: float, sd: int) -> void:
	for k in 2:
		var z := -dp * 0.25 + k * dp * 0.5
		mb.blk(0, z, w - 0.1, dp * 0.4, 0.12, Color("a47b50"), "s")
		B.crate(mb, Vector3(0, 0.12, z), Vector3(w * 0.8, 0.4, dp * 0.34), 0.0, sd + k)


static func handtruck(mb: MB) -> void:
	mb.rod(Vector3(-0.12, 0.2, 0.0), Vector3(-0.1, 1.2, -0.15), 0.014, P.IRON, "m", 5)
	mb.rod(Vector3(0.12, 0.2, 0.0), Vector3(0.1, 1.2, -0.15), 0.014, P.IRON, "m", 5)
	mb.blk(0, 0.1, 0.34, 0.2, 0.012, P.IRON, "m", 0.2)
	for s: float in [-1.0, 1.0]:
		mb.cyl_dir(Vector3(s * 0.18, 0.1, -0.02), Vector3(1, 0, 0), 0.1, 0.03, Color("1a1a1a"), "s", 8)


static func hoist(mb: MB, w: float, dp: float) -> void:
	for s: float in [-1.0, 1.0]:
		mb.rod(Vector3(s * w * 0.4, 0.0, 0.0), Vector3(0, 2.7, 0), 0.04, P.IRON, "m", 5)
	mb.blk(0, 0, 0.2, 0.2, 0.2, P.IRON, "m", 2.5)
	mb.rod(Vector3(0, 2.5, 0), Vector3(0, 1.6, 0), 0.012, P.IRON, "m", 4)
	mb.blk(0, 0, 0.12, 0.08, 0.1, P.IRON, "m", 1.5)
	var _x := dp


# ------------------------------------------------------------------ lamps

## A ceiling lamp at lot-local metres (x, z): returns the pool radius for the light decal.
static func lamp(mb: MB, style: String, x: float, z: float) -> float:
	var ceil_y := 3.2
	var warm := Color("ffe2a8")
	match style:
		"shade":
			mb.rod(Vector3(x, ceil_y, z), Vector3(x, 2.2, z), 0.006, P.IRON, "m", 4)
			mb.cyl(Vector3(x, 2.1, z), 0.2, 0.16, Color("2f6a3c"), "s", 10, 0.06, false)
			mb.cyl(Vector3(x, 2.19, z), 0.07, 0.02, Color("2f6a3c"), "s", 8)
			mb.sph(Vector3(x, 2.03, z), 0.045, warm, "bulb", 6, 4)
			return 2.6
		"bulb":
			mb.rod(Vector3(x, ceil_y, z), Vector3(x, 2.5, z), 0.006, Color("1c1c1c"), "s", 4)
			mb.cyl(Vector3(x, 2.5, z), 0.03, 0.05, P.BRASS, "m", 6)
			mb.sph(Vector3(x, 2.43, z), 0.05, warm, "bulb", 6, 4)
			return 2.8
		"cage":
			mb.rod(Vector3(x, ceil_y, z), Vector3(x, 2.5, z), 0.006, Color("1c1c1c"), "s", 4)
			mb.sph(Vector3(x, 2.4, z), 0.045, warm, "bulb", 6, 4)
			mb.hoop(Vector3(x, 2.4, z), 0.09, 0.008, 0.008, P.IRON, "m", 6)
			mb.hoop(Vector3(x, 2.46, z), 0.07, 0.008, 0.008, P.IRON, "m", 6)
			return 2.6
		"industrial":
			mb.rod(Vector3(x, ceil_y, z), Vector3(x, 2.7, z), 0.008, Color("1c1c1c"), "s", 4)
			mb.cyl(Vector3(x, 2.6, z), 0.36, 0.2, Color("3a4a3a"), "s", 12, 0.06, false)
			mb.cyl(Vector3(x, 2.5, z), 0.34, 0.01, warm, "bulb", 12)
			return 6.0
		"billiard":
			mb.rod(Vector3(x - 0.5, ceil_y, z), Vector3(x - 0.5, 2.15, z), 0.006, P.BRASS, "m", 4)
			mb.rod(Vector3(x + 0.5, ceil_y, z), Vector3(x + 0.5, 2.15, z), 0.006, P.BRASS, "m", 4)
			mb.box(Vector3(x, 2.15, z), Vector3(1.2, 0.03, 0.05), P.BRASS, "m")
			for s: float in [-1.0, 1.0]:
				mb.cyl(Vector3(x + s * 0.42, 2.0, z), 0.22, 0.14, Color("1f5a38"), "s", 10, 0.07, false)
				mb.cyl(Vector3(x + s * 0.42, 1.94, z), 0.2, 0.01, warm, "bulb", 10)
				mb.hoop(Vector3(x + s * 0.42, 1.93, z), 0.22, 0.012, 0.02, P.BRASS, "m", 10)
			return 3.2
		"globe":
			mb.rod(Vector3(x, ceil_y, z), Vector3(x, 2.6, z), 0.008, P.BRASS, "m", 4)
			mb.sph(Vector3(x, 2.45, z), 0.17, Color("fff0d0"), "bulb", 10, 6)
			mb.cyl(Vector3(x, 2.63, z), 0.06, 0.04, P.BRASS, "m", 8)
			return 3.4
		"chandelier":
			mb.rod(Vector3(x, ceil_y, z), Vector3(x, 2.7, z), 0.01, P.BRASS, "m", 4)
			mb.hoop(Vector3(x, 2.6, z), 0.38, 0.03, 0.04, P.BRASS, "m", 12)
			mb.cyl(Vector3(x, 2.55, z), 0.05, 0.2, P.BRASS, "m", 8, 0.02)
			for k in 6:
				var a := k * TAU / 6.0
				mb.sph(Vector3(x + cos(a) * 0.38, 2.68, z + sin(a) * 0.38), 0.05, warm, "bulb", 6, 4)
				mb.rod(Vector3(x, 2.7, z), Vector3(x + cos(a) * 0.38, 2.62, z + sin(a) * 0.38), 0.008, P.BRASS, "m", 4)
			return 4.4
		"banker":
			return 1.4
		"speak":
			mb.rod(Vector3(x, ceil_y, z), Vector3(x, 2.35, z), 0.006, P.IRON, "m", 4)
			mb.cyl(Vector3(x, 2.2, z), 0.3, 0.22, Color("8a1f2a"), "s", 8, 0.07, false)
			mb.hoop(Vector3(x, 2.1, z), 0.3, 0.01, 0.03, P.BRASS, "m", 8)
			mb.sph(Vector3(x, 2.12, z), 0.05, Color("ffb878"), "bulb", 6, 4)
			return 3.8
		_:
			mb.rod(Vector3(x, ceil_y, z), Vector3(x, 2.5, z), 0.006, P.IRON, "m", 4)
			mb.cyl(Vector3(x, 2.4, z), 0.2, 0.1, P.BRASS.darkened(0.15), "m", 10, 0.05, false)
			mb.cyl(Vector3(x, 2.34, z), 0.17, 0.02, warm, "bulb", 10)
			return 3.0
