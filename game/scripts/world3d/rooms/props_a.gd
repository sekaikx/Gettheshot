extends RefCounted
## Prop set A: counters, bars, registers, glass cases, ice beds, bins and every kind of shelf with its trade goods.
## Prop frame: origin on the floor at the item's centre, +Z the front (the customer side), -Z against the wall.
## w = width across the front (x), d = depth (z).

const MB := preload("res://scripts/world3d/rooms/mb.gd")
const P := preload("res://scripts/world3d/rooms/parts.gd")

const TOP_Y := 0.93


static func keep(i: int, j: int, s: int, br: bool) -> bool:
	return not br or P.hf(i, j, s + 500) > 0.55


# ------------------------------------------------------------------ counters

static func counter(mb: MB, w: float, d: float, art: String, goods: String, sd: int, avoid: Array, closed: bool = false) -> void:
	var top := P.WOOD_L
	var body := P.WOOD
	var panel := P.WOOD_D
	var h := 0.9
	match art:
		"marble_counter":
			top = Color("d4cec2")
			body = Color("4a3a2e")
			panel = Color("5e4a3a")
		"butcher_counter":
			top = Color("d6d2c6")
			body = Color("c4beac")
			panel = Color("b8c4be")
		"fish_counter":
			top = Color("b4bec0")
			body = Color("7a8a8e")
			panel = Color("606e72")
		"pawn_counter":
			top = Color("3a2418")
			body = P.MAHOG
			panel = P.MAHOG.darkened(0.25)
		"cutting_counter":
			top = Color("a47b50")
			body = Color("7a5a3e")
			panel = Color("5e4430")
		"tally_desk":
			top = Color("7a5a3e")
			body = Color("4e3a2a")
			panel = Color("3a2a1e")
			h = 1.0
		"high_desk":
			top = Color("5a3a24")
			body = Color("4a2e1e")
			panel = Color("3a2418")
			h = 1.08
	mb.blk(0, 0, w - 0.02, d - 0.04, h - 0.05, body)
	mb.blk(0, 0.02, w + 0.04, d + 0.1, 0.05, top, "s", h - 0.05)
	mb.blk(0, d * 0.5 - 0.01, w - 0.04, 0.02, 0.08, panel.darkened(0.35))
	# front panels
	var n := maxi(1, int(round(w / 0.62)))
	var pw := (w - 0.1) / float(n)
	for k in n:
		var px := -w * 0.5 + 0.05 + pw * (float(k) + 0.5)
		mb.blk(px, d * 0.5 + 0.005, pw - 0.1, 0.02, h - 0.34, panel, "s", 0.14)
		mb.blk(px, d * 0.5 + 0.017, pw - 0.2, 0.01, h - 0.46, body.lightened(0.05), "s", 0.2)
	if art == "high_desk":
		mb.blk(0, -d * 0.5 + 0.03, w, 0.06, 0.18, top.darkened(0.15), "s", h)
	elif art in ["wood_counter", "marble_counter", "pawn_counter", "fish_counter", "cutting_counter"] and w > 1.2:
		mb.rod(Vector3(-w * 0.5 + 0.12, 0.13, d * 0.5 + 0.08), Vector3(w * 0.5 - 0.12, 0.13, d * 0.5 + 0.08), 0.016, P.BRASS, "m", 6)
		for k in 3:
			var fx := lerpf(-w * 0.5 + 0.12, w * 0.5 - 0.12, float(k) / 2.0)
			mb.rod(Vector3(fx, 0.0, d * 0.5 + 0.08), Vector3(fx, 0.13, d * 0.5 + 0.08), 0.012, P.BRASS, "m", 5)
	if closed:
		return
	counter_goods(mb, w, d, h + 0.0, art, goods, sd, avoid)


static func _free(x: float, avoid: Array, pad: float = 0.0) -> bool:
	for a in avoid:
		if x > float(a[0]) - pad and x < float(a[1]) + pad:
			return false
	return true


static func counter_goods(mb: MB, w: float, d: float, y: float, art: String, goods: String, sd: int, avoid: Array) -> void:
	if art == "high_desk":
		P.paper(mb, Vector3(-w * 0.25, y, 0.0), 0.2)
		P.book(mb, Vector3(w * 0.1, y, 0.05), 0.1, P.OXBLOOD, Vector3(0.3, 0.05, 0.22))
		mb.at(Vector3(w * 0.32, y, 0.0))
		mb.cyl(Vector3(0, 0.05, 0), 0.07, 0.1, Color("2a2a2e"), "m", 8)
		mb.sph(Vector3(0, 0.12, 0), 0.035, Color("e0d8b8"), "s", 6, 4)
		mb.pop()
		return
	if art == "tally_desk":
		P.book(mb, Vector3(-w * 0.2, y, 0.0), 0.05, Color("2a3a2a"), Vector3(0.34, 0.04, 0.24))
		P.paper(mb, Vector3(w * 0.15, y, 0.05), -0.2, Vector3(0.22, 0.004, 0.3))
		mb.at(Vector3(w * 0.3, y, -0.1))
		mb.cyl(Vector3(0, 0.1, 0), 0.05, 0.2, Color("2f5a3a"), "s", 8, 0.03)
		mb.pop()
		return
	var slots := maxi(2, int(w / 0.75))
	for k in slots:
		var x := -w * 0.5 + 0.35 + (w - 0.7) * (float(k) + hf_s(k, sd) * 0.3) / float(maxi(slots - 1, 1))
		if not _free(x, avoid, 0.3):
			continue
		var z := (P.hf(k, 7, sd) - 0.5) * (d - 0.3)
		# goods are drawn a little large so they read from the street camera
		mb.atx(Vector3(x, y, z), 0.0, Vector3(1.3, 1.3, 1.3))
		_top_item(mb, goods, art, Vector3.ZERO, k, sd)
		mb.pop()


static func hf_s(k: int, sd: int) -> float:
	return P.hf(k, 11, sd) - 0.5


static func _top_item(mb: MB, goods: String, art: String, p: Vector3, k: int, sd: int) -> void:
	var t := (k + int(P.hf(k, 5, sd) * 3.0)) % 3
	match goods:
		"bakery":
			if t == 0:
				mb.at(p)
				mb.cyl(Vector3(0, 0.05, 0), 0.17, 0.1, Color("b08a50"), "s", 10, 0.2)
				P.loaf(mb, Vector3(-0.05, 0.08, 0), 0.4, 0.26)
				P.baguette(mb, Vector3(0.05, 0.1, 0), 0.9, 0.34)
				P.roll(mb, Vector3(0.08, 0.1, 0.07))
				mb.pop()
			elif t == 1:
				mb.at(p)
				mb.cyl(Vector3(0, 0.05, 0), 0.04, 0.1, P.CREAM, "s", 8, 0.14)
				P.cake(mb, Vector3(0, 0.1, 0), 0.12, Color("f2e0e0"))
				mb.pop()
			else:
				P.boule(mb, p + Vector3(-0.1, 0, 0))
				P.boule(mb, p + Vector3(0.1, 0, 0.03))
		"butcher":
			if t == 0:
				mb.at(p)
				mb.cyl(Vector3(0, 0.02, 0), 0.2, 0.04, P.STEEL, "m", 10)
				mb.cyl(Vector3(0, 0.1, 0), 0.02, 0.2, P.STEEL, "m", 6)
				mb.box(Vector3(0, 0.26, 0), Vector3(0.3, 0.03, 0.2), Color("ece5d2"), "s")
				mb.pop()
			elif t == 1:
				mb.at(p)
				mb.box(Vector3(0, 0.02, 0), Vector3(0.36, 0.04, 0.26), P.ENAMEL, "s")
				P.steak(mb, Vector3(-0.06, 0.04, 0), 0.3)
				P.chop(mb, Vector3(0.08, 0.04, 0.02), 1.0)
				mb.pop()
			else:
				mb.at(p)
				mb.box(Vector3(0, 0.0105, 0), Vector3(0.22, 0.04, 0.05), P.STEEL, "m")
				mb.box(Vector3(0.14, 0.02, 0), Vector3(0.07, 0.04, 0.03), Color("3a2a1e"), "s")
				mb.pop()
		"grocer":
			if t == 0:
				mb.at(p)
				mb.blk(0, 0, 0.3, 0.2, 0.04, P.IRON, "m")
				mb.cyl(Vector3(0, 0.15, 0), 0.025, 0.2, P.IRON, "m", 6)
				mb.cyl(Vector3(0, 0.27, 0), 0.1, 0.03, P.BRASS, "m", 10)
				mb.pop()
			elif t == 1:
				mb.at(p)
				mb.cyl(Vector3(0, 0.07, 0), 0.15, 0.14, Color("e0b84a"), "s", 10)
				mb.box(Vector3(0.08, 0.1, 0.0), Vector3(0.1, 0.17, 0.2), Color("1a1a1a"), "dim")
				mb.pop()
			else:
				P.can(mb, p + Vector3(-0.08, 0, 0), Color("c83a28"))
				P.can(mb, p + Vector3(0.0, 0, 0), Color("3a8a48"))
				P.can(mb, p + Vector3(0.08, 0, 0), Color("d6a032"))
				P.can(mb, p + Vector3(-0.04, 0.12, 0), Color("c83a28"))
		"tailor":
			if t == 0:
				P.bolt(mb, p + Vector3(0, 0, 0), true, P.CLOTHS[(k + sd) % 8], 0.5)
				P.bolt(mb, p + Vector3(0, 0.14, 0), true, P.CLOTHS[(k + sd + 3) % 8], 0.5)
			elif t == 1:
				P.paper(mb, p, 0.4, Vector3(0.3, 0.01, 0.2), P.CLOTHS[(k + sd) % 8])
				mb.at(p + Vector3(0.1, 0.012, 0))
				mb.box(Vector3(0, 0.005, 0), Vector3(0.14, 0.01, 0.025), P.STEEL, "m")
				mb.pop()
			else:
				mb.at(p)
				mb.cyl(Vector3(0, 0.03, 0), 0.04, 0.06, Color("a02a30"), "s", 8)
				mb.cyl(Vector3(0, 0.07, 0), 0.01, 0.04, P.STEEL, "m", 5)
				mb.pop()
		"barber":
			P.label_bottle(mb, p, Color("3a6a8a"), P.CREAM, 0.28)
			P.label_bottle(mb, p + Vector3(0.07, 0, 0), Color("8a5a3a"), P.CREAM, 0.26)
		"cobbler":
			P.shoe(mb, p, 0.4 + k, P.pick(P.CLOTHS, k, 2, sd).darkened(0.1))
			P.shoe(mb, p + Vector3(0.12, 0, 0.05), -0.6, Color("4a2e1e"))
		"pawnshop":
			if t == 0:
				P.pocket_watch(mb, p)
				P.gem_ring(mb, p + Vector3(0.12, 0, 0.03))
			elif t == 1:
				mb.at(p)
				mb.blk(0, 0, 0.2, 0.14, 0.14, Color("2a2a2e"), "m")
				mb.cyl(Vector3(0, 0.17, 0), 0.04, 0.06, P.BRASS, "m", 8)
				mb.pop()
			else:
				P.cash(mb, p, 0.3)
				P.coin(mb, p + Vector3(0.14, 0, 0.0))
		"laundry":
			P.bundle(mb, p, 0.2 * k)
			if t == 0:
				P.towel_stack(mb, p + Vector3(0.3, 0, 0), 3)
		"restaurant", "cafe":
			if t == 0:
				P.cup(mb, p, 0.04)
				P.cup(mb, p + Vector3(0.1, 0, 0.03), 0.04)
			elif t == 1:
				P.cake(mb, p, 0.14, Color("f2e6d0"), k % 2 == 0)
			else:
				mb.at(p)
				mb.cyl(Vector3(0, 0.08, 0), 0.07, 0.16, P.STEEL, "m", 8)
				mb.cyl(Vector3(0, 0.175, 0), 0.04, 0.03, P.BRASS, "m", 6)
				mb.pop()
		"candy":
			P.jar(mb, p, P.pick(P.BRIGHTS, k, 4, sd), 0.28, 0.08)
			P.jar(mb, p + Vector3(0.18, 0, 0.02), P.pick(P.BRIGHTS, k + 3, 4, sd), 0.22, 0.07)
		"hardware":
			if t == 0:
				mb.at(p)
				mb.blk(0, 0, 0.28, 0.18, 0.04, P.IRON, "m")
				mb.cyl(Vector3(0, 0.15, 0), 0.02, 0.2, P.IRON, "m", 6)
				mb.cyl(Vector3(0, 0.26, 0), 0.09, 0.03, P.STEEL, "m", 10)
				mb.pop()
			elif t == 1:
				mb.at(p)
				mb.cyl_dir(Vector3(0, 0.03, 0), Vector3(1, 0, 0.3), 0.012, 0.3, Color("6a4a2a"), "s", 5)
				mb.box(Vector3(0.12, 0.05, 0.03), Vector3(0.08, 0.05, 0.03), P.STEEL, "m")
				mb.pop()
			else:
				P.tin(mb, p, Color("b83a28"))
				P.tin(mb, p + Vector3(0.1, 0, 0), Color("2e6a8a"))
		"drugstore":
			P.label_bottle(mb, p, Color("3a6a9a"), P.CREAM, 0.22)
			P.jar(mb, p + Vector3(0.12, 0, 0), Color("c8d8c0"), 0.18, 0.05)
		"cigar":
			P.cigarbox(mb, p, 0.2 * k, k % 2 == 0)
			if t == 1:
				P.ashtray(mb, p + Vector3(0.22, 0, 0.0), true)
		"fish":
			mb.at(p)
			mb.box(Vector3(0, 0.03, 0), Vector3(0.36, 0.06, 0.25), P.STEEL, "m")
			P.fish(mb, Vector3(0, 0.06, 0), 0.4, P.SILVER)
			mb.pop()
		"club", "poolhall":
			if t == 0:
				P.glass_cup(mb, p, Color("c88a3a"))
				P.glass_cup(mb, p + Vector3(0.08, 0, 0.04), Color("c88a3a"))
			else:
				P.ashtray(mb, p, true)
		_:
			P.box(mb, p, Vector3(0.14, 0.1, 0.1), P.pick(P.BRIGHTS, k, 1, sd))
	var _a := art


# ------------------------------------------------------------------ register

static func register(mb: MB, w: float, d: float, br: bool, sd: int) -> void:
	mb.at(Vector3(0, TOP_Y + 0.0, 0))
	var rw := minf(w, 0.42)
	var rd := minf(d, 0.36)
	if br:
		mb.at(Vector3(0.02, 0.0, 0.0), 0.35)
	mb.blk(0, 0, rw, rd, 0.07, Color("4a3a24"), "s")
	mb.blk(0, 0, rw * 0.92, rd * 0.92, 0.2, P.BRASS.darkened(0.12), "m", 0.07)
	# the sloped key bank
	mb.quad(Vector3(-rw * 0.45, 0.27, -rd * 0.1), Vector3(rw * 0.45, 0.27, -rd * 0.1), Vector3(rw * 0.45, 0.2, rd * 0.44), Vector3(-rw * 0.45, 0.2, rd * 0.44), Color("3a2e20"), "s")
	for i in 5:
		for j in 3:
			mb.sph(Vector3(-rw * 0.34 + i * rw * 0.17, 0.235 - j * 0.006, rd * 0.04 + j * rd * 0.13), 0.014, Color("e8dcc0"), "s", 4, 3)
	# the window of numbers above
	mb.blk(0, -rd * 0.3, rw * 0.7, 0.05, 0.14, P.BRASS, "m", 0.27)
	mb.blk(0, -rd * 0.3 + 0.026, rw * 0.5, 0.004, 0.06, Color("f2e6c0"), "e", 0.31)
	if br:
		mb.blk(0, rd * 0.5 + 0.12, rw * 0.88, 0.3, 0.04, Color("4a3a24"), "s", 0.03)
		mb.pop()
	else:
		mb.blk(0, rd * 0.5 - 0.005, rw * 0.86, 0.02, 0.05, Color("3a2a1c"), "s", 0.03)
	mb.pop()
	var _s := sd


# ------------------------------------------------------------------ cases

const CASE := {
	# art: [body colour, trim, felt colour, goods kind, height]
	"pastry_case": [Color("e8e0cc"), Color("c9a54a"), Color("f2e8d4"), "pastry", 1.15],
	"cake_case": [Color("e8e0cc"), Color("c9a54a"), Color("f2e8d4"), "cake", 1.15],
	"meat_case": [Color("d8d2c0"), Color("9ca0a4"), Color("e8e4d8"), "meat", 1.1],
	"poultry_case": [Color("d8d2c0"), Color("9ca0a4"), Color("e8e4d8"), "poultry", 1.1],
	"watch_case": [Color("4a2a20"), Color("c9a54a"), Color("2a2f4a"), "watch", 1.1],
	"jewel_case": [Color("4a2a20"), Color("c9a54a"), Color("5a1a2a"), "jewel", 1.1],
	"candy_case": [Color("e8dcc0"), Color("b8282a"), Color("f2e8d4"), "candy", 1.15],
	"chocolate_case": [Color("5a3a2a"), Color("c9a54a"), Color("e8dcc0"), "choc", 1.1],
	"cigar_case": [Color("4a2e1e"), Color("c9a54a"), Color("3a2418"), "cigar", 1.1],
	"cosmetic_case": [Color("e0d4c0"), Color("c9a54a"), Color("d8b8c0"), "cosmetic", 1.1],
	"drug_case": [Color("d8cfb8"), Color("c9a54a"), Color("e8e4d8"), "drug", 1.1],
}


static func case(mb: MB, w: float, d: float, art: String, sd: int, br: bool) -> void:
	var cfg: Array = CASE.get(art, [P.WOOD, P.BRASS, P.CREAM, "pastry", 1.1])
	var body: Color = cfg[0]
	var trim: Color = cfg[1]
	var felt: Color = cfg[2]
	var kind: String = cfg[3]
	var top: float = cfg[4]
	var by := 0.58
	mb.blk(0, 0, w, d, by, body)
	mb.blk(0, d * 0.5 - 0.01, w + 0.02, 0.03, 0.06, trim.darkened(0.2), "m")
	mb.blk(0, 0, w + 0.02, d + 0.02, 0.025, trim.darkened(0.3), "s", by)
	mb.blk(0, 0, w - 0.06, d - 0.06, 0.012, felt, "s", by + 0.025)
	# panels on the front
	var n := maxi(1, int(round(w / 0.7)))
	for k in n:
		var px := -w * 0.5 + w * (float(k) + 0.5) / n
		mb.blk(px, d * 0.5 + 0.004, w / n - 0.12, 0.014, by - 0.2, body.darkened(0.12), "s", 0.1)
	# the goods, from above: a grid in the cabinet
	var nx := maxi(2, int((w - 0.1) / 0.17))
	var nz := maxi(1, int((d - 0.08) / 0.17))
	var y := by + 0.037
	for i in nx:
		for j in nz:
			var x := -(w - 0.12) * 0.5 + (w - 0.12) * (float(i) + 0.5) / nx
			var z := -(d - 0.1) * 0.5 + (d - 0.1) * (float(j) + 0.5) / nz
			if not keep(i, j, sd, br):
				continue
			case_cell(mb, kind, Vector3(x, y, z), i, j, sd)
	# glass: front, sides and a sloped lid, thin brass frame
	if not br:
		var gh := top
		var c := Color(0.72, 0.88, 0.94, 0.26)
		mb.quad(Vector3(-w * 0.5, by + 0.03, d * 0.5), Vector3(w * 0.5, by + 0.03, d * 0.5), Vector3(w * 0.5, gh - 0.04, d * 0.5 - 0.1), Vector3(-w * 0.5, gh - 0.04, d * 0.5 - 0.1), c, "g")
		mb.quad(Vector3(-w * 0.5, gh - 0.04, d * 0.5 - 0.1), Vector3(w * 0.5, gh - 0.04, d * 0.5 - 0.1), Vector3(w * 0.5, gh, -d * 0.5), Vector3(-w * 0.5, gh, -d * 0.5), c, "g")
		mb.quad(Vector3(-w * 0.5, by + 0.03, d * 0.5), Vector3(-w * 0.5, gh - 0.04, d * 0.5 - 0.1), Vector3(-w * 0.5, gh, -d * 0.5), Vector3(-w * 0.5, by + 0.03, -d * 0.5), c, "g")
		mb.quad(Vector3(w * 0.5, by + 0.03, -d * 0.5), Vector3(w * 0.5, gh, -d * 0.5), Vector3(w * 0.5, gh - 0.04, d * 0.5 - 0.1), Vector3(w * 0.5, by + 0.03, d * 0.5), c, "g")
	else:
		# a few teeth of glass left in the frame
		for k in 4:
			var gx := -w * 0.5 + w * (float(k) + 0.5) / 4.0
			mb.tri(Vector3(gx - 0.08, by + 0.03, d * 0.5), Vector3(gx + 0.08, by + 0.03, d * 0.5), Vector3(gx + (P.hf(k, 1, sd) - 0.5) * 0.1, by + 0.03 + 0.14 + P.hf(k, 2, sd) * 0.2, d * 0.5), Color(0.8, 0.92, 0.96, 0.4), "g")
	# the frame
	var fh := top - by
	mb.blk(-w * 0.5 + 0.015, d * 0.5 - 0.03, 0.03, 0.03, fh - 0.04, trim, "m", by + 0.025)
	mb.blk(w * 0.5 - 0.015, d * 0.5 - 0.03, 0.03, 0.03, fh - 0.04, trim, "m", by + 0.025)
	mb.blk(-w * 0.5 + 0.015, -d * 0.5 + 0.015, 0.03, 0.03, fh, trim, "m", by + 0.025)
	mb.blk(w * 0.5 - 0.015, -d * 0.5 + 0.015, 0.03, 0.03, fh, trim, "m", by + 0.025)
	if not br:
		mb.rod(Vector3(-w * 0.5, top - 0.04, d * 0.5 - 0.1), Vector3(w * 0.5, top - 0.04, d * 0.5 - 0.1), 0.012, trim, "m", 5)


static func case_cell(mb: MB, kind: String, p: Vector3, i: int, j: int, sd: int) -> void:
	var t := int(P.hf(i, j, sd) * 4.0)
	match kind:
		"pastry":
			match t:
				0: P.croissant(mb, p, 0.3 * i)
				1: P.roll(mb, p, 0.045)
				2:
					mb.at(p)
					P.cannolo(mb, Vector3(-0.03, 0, 0), 0.2)
					P.cannolo(mb, Vector3(0.03, 0, 0.02), -0.2)
					mb.pop()
				_: P.pie(mb, p, 0.07)
		"cake":
			if t % 2 == 0:
				P.cake(mb, p, 0.09, P.pick([Color("f2e0e0"), Color("f2e6d0"), Color("6a3a2a"), Color("e8c8d8")], i, j, sd), t == 2)
			else:
				P.pie(mb, p, 0.08)
		"meat":
			if t < 2:
				P.steak(mb, p, 0.3 * i + j)
			else:
				P.chop(mb, p, 0.5 * j)
			if i % 3 == 0:
				P.links(mb, p + Vector3(-0.06, 0.03, 0), p + Vector3(0.06, 0.03, 0.02), 4)
		"poultry":
			if t < 2:
				P.chicken(mb, p, 0.4 * i)
			else:
				P.ham(mb, p, 0.3 * j)
		"watch":
			if t < 2:
				P.watch(mb, p, 0.4 * i)
			else:
				P.pocket_watch(mb, p)
		"jewel":
			if t < 2:
				P.gem_ring(mb, p, P.pick([Color("e04a6a"), Color("4a7ae0"), Color("48c878"), Color("f0f0f8")], i, j, sd))
			else:
				P.necklace(mb, p)
		"candy":
			P.jar(mb, p, P.pick(P.BRIGHTS, i, j, sd), 0.1, 0.045)
		"choc":
			P.box(mb, p, Vector3(0.12, 0.04, 0.1), P.pick([Color("5a3a2a"), Color("c9a54a"), Color("8a2a2a")], i, j, sd), 0.2 * j)
		"cigar":
			P.cigarbox(mb, p, 0.0, t % 2 == 0)
		"cosmetic":
			P.label_bottle(mb, p, P.pick([Color("d8a8b8"), Color("a8c0d8"), Color("e8d8a8")], i, j, sd), P.CREAM, 0.12, 0.028)
			if t == 0:
				mb.cyl(p + Vector3(0.06, 0.02, 0), 0.03, 0.04, Color("c9a54a"), "m", 8)
		"drug":
			P.label_bottle(mb, p, P.pick([Color("3a6a9a"), Color("7a4a1e"), Color("3a6a3c")], i, j, sd), P.CREAM, 0.14, 0.03)


static func humidor(mb: MB, w: float, d: float, sd: int, br: bool) -> void:
	mb.blk(0, 0, w, d, 1.5, Color("4a2e1e"))
	mb.blk(0, 0, w + 0.04, d + 0.04, 0.05, Color("3a2418"), "s", 1.5)
	for lv in 5:
		var y := 0.2 + lv * 0.27
		mb.blk(0, 0.0, w - 0.06, d - 0.06, 0.02, Color("6a4a2e"), "s", y)
		for k in 3:
			if keep(k, lv, sd, br):
				P.cigarbox(mb, Vector3(-w * 0.28 + k * w * 0.28, y + 0.02, 0.0), 1.57, true)
	if not br:
		mb.quad(Vector3(-w * 0.5, 0.15, d * 0.5 + 0.002), Vector3(w * 0.5, 0.15, d * 0.5 + 0.002), Vector3(w * 0.5, 1.45, d * 0.5 + 0.002), Vector3(-w * 0.5, 1.45, d * 0.5 + 0.002), Color(0.74, 0.88, 0.94, 0.24), "g")
	mb.blk(0, d * 0.5 + 0.01, w - 0.02, 0.02, 0.1, P.BRASS, "m", 0.04)


static func ice_bed(mb: MB, w: float, d: float, art: String, sd: int, br: bool) -> void:
	var fish := art == "fish_ice" or art == "ice_table"
	mb.blk(0, 0, w, d, 0.78, Color("8a969a") if fish else Color("d8d2c0"), "s")
	mb.blk(0, 0, w - 0.1, d - 0.1, 0.03, Color("e4eef0"), "s", 0.78)
	mb.blk(0, d * 0.5 - 0.02, w, 0.04, 0.05, Color("606e72"), "m", 0.76)
	mb.blk(0, -d * 0.5 + 0.02, w, 0.04, 0.05, Color("606e72"), "m", 0.76)
	var nx := maxi(2, int(w / 0.3))
	var nz := maxi(1, int(d / 0.28))
	for i in nx:
		for j in nz:
			if not keep(i, j, sd, br):
				continue
			var x := -w * 0.5 + 0.15 + (w - 0.3) * (float(i) + 0.5 * (j % 2)) / maxi(nx - 1, 1)
			var z := -d * 0.5 + 0.18 + (d - 0.36) * (float(j) + 0.5) / maxi(nz, 1)
			if absf(x) > w * 0.5 - 0.1:
				continue
			var col := P.SILVER.lerp(P.pick([Color("8aa8b8"), Color("c88a7a"), Color("a8b8a0")], i, j, sd), 0.4)
			P.fish(mb, Vector3(x, 0.81, z), 1.57 + (P.hf(i, j, sd) - 0.5) * 0.8, col)
	if kind_has_lemons(fish):
		for i in 4:
			P.fruit(mb, Vector3(-w * 0.5 + 0.2 + i * 0.1, 0.81, d * 0.5 - 0.1), 0.03, Color("e8d048"))


static func kind_has_lemons(fish: bool) -> bool:
	return fish


static func bins(mb: MB, w: float, d: float, sd: int, br: bool, kinds: Array) -> void:
	# a slanted market stall of bins along the length
	var n := maxi(2, int(d / 0.5))
	var bd := d / n
	for k in n:
		var z := -d * 0.5 + bd * (float(k) + 0.5)
		mb.blk(0, z, w, bd - 0.02, 0.5, P.WOOD, "s")
		mb.blk(0, z, w - 0.08, bd - 0.1, 0.02, Color("2a2018"), "s", 0.5)
		var kind: String = kinds[(k + sd) % kinds.size()]
		if br and k % 2 == 0:
			continue
		P.heap(mb, -w * 0.5 + 0.08, z - bd * 0.5 + 0.06, w * 0.5 - 0.08, z + bd * 0.5 - 0.06, 0.52, kind, sd + k)
	mb.blk(w * 0.5 + 0.01, 0, 0.02, d, 0.1, P.WOOD_D, "s", 0.5)
	mb.blk(-w * 0.5 + 0.0, 0, 0.04, d, 0.9, P.WOOD_D, "s")
	# a chalk price board
	mb.blk(-w * 0.5, -d * 0.4, 0.04, 0.3, 0.2, Color("2a3028"), "s", 0.9)


static func nail_bins(mb: MB, w: float, d: float, sd: int, br: bool) -> void:
	var n := maxi(2, int(d / 0.38))
	for k in n:
		var z := -d * 0.5 + d * (float(k) + 0.5) / n
		mb.blk(0, z, w, d / n - 0.03, 0.62, P.WOOD, "s")
		mb.blk(w * 0.18, z, w * 0.55, d / n - 0.1, 0.02, Color("3a3a3e"), "m", 0.62)
		# a slanted scoop face
		mb.quad(Vector3(-w * 0.5, 0.62, z + d / n * 0.4), Vector3(w * 0.5, 0.62, z + d / n * 0.4), Vector3(w * 0.5, 0.7, z + d / n * 0.35), Vector3(-w * 0.5, 0.7, z + d / n * 0.35), Color("5a3a22"), "s")
		if not br or k % 2 == 1:
			mb.sph(Vector3(w * 0.18, 0.64, z), minf(0.14, d / n * 0.4), Color("8a8a90"), "m", 6, 3, 0.4)
	mb.blk(-w * 0.5 + 0.02, 0, 0.04, d, 0.95, P.WOOD_D, "s")


# ------------------------------------------------------------------ shelves

const SHELF_TRADE := {
	"bread_shelf": "bread", "grocery_shelf": "grocery", "cloth_shelf": "cloth", "tonic_shelf": "tonic",
	"shoe_shelf": "shoes", "shoe_rack": "shoes", "pawn_shelf": "pawn", "bundle_shelf": "bundles",
	"wine_shelf": "wine", "coffee_shelf": "coffee", "jar_shelf": "jars", "drawer_shelf": "drawers",
	"bottle_shelf": "pharm", "cigar_shelf": "cigars", "tin_shelf": "tins", "club_backbar": "backbar",
	"beer_backbar": "beer", "towel_shelf": "towels", "leather_shelf": "leather", "crate_shelf": "boxes",
	"stock_shelf": "boxes", "box_shelf": "candyboxes", "sack_shelf": "sacks", "apothecary": "apoth",
	"beer_cases": "cases", "pipe_rack": "pipes",
}


static func shelf(mb: MB, w: float, d_full: float, art: String, sd: int, br: bool, rev: bool, closed: bool = false) -> void:
	var kind: String = SHELF_TRADE.get(art, "boxes")
	var hmax := 1.75
	var wood := P.WOOD.darkened(0.05)
	if kind in ["backbar", "beer"]:
		wood = Color("4a2a1e")
	var levels := [0.16, 0.58, 0.98, 1.36]
	hmax = 1.62
	if kind in ["drawers", "apoth"]:
		levels = [0.12]
	# a deep slot (the storeroom wall) only holds a shelf's depth, set against the wall
	var d := minf(d_full, 0.55)
	var zoff := -(d_full - d) * 0.5
	mb.push(Transform3D(Basis.IDENTITY, Vector3(0, 0, zoff)))
	# the back and the sides
	if not rev:
		mb.blk(0, -d * 0.5 + 0.015, w, 0.03, hmax, wood.darkened(0.25))
	mb.blk(-w * 0.5 + 0.02, 0, 0.04, d, hmax, wood)
	mb.blk(w * 0.5 - 0.02, 0, 0.04, d, hmax, wood)
	mb.blk(0, 0, w, d, 0.1, wood.darkened(0.3))
	if not rev:
		mb.blk(0, 0, w + 0.02, d + 0.02, 0.04, wood.lightened(0.05), "s", hmax)
	if kind == "backbar":
		# the long mirror between the shelves
		if not rev:
			mb.blk(0, -d * 0.5 + 0.035, w - 0.2, 0.008, 1.1, Color("bcd0d6"), "m", 0.5)
			mb.blk(0, -d * 0.5 + 0.03, w - 0.1, 0.012, 0.07, P.BRASS, "m", 1.58)
	if kind in ["drawers", "apoth"]:
		_drawer_wall(mb, w, d, kind, sd, br)
		mb.pop()
		return
	if closed:
		mb.pop()
		return
	for li in levels.size():
		var y: float = levels[li]
		mb.blk(0, 0, w - 0.08, d - 0.02, 0.03, wood.lightened(0.04), "s", y - 0.03)
		shelf_goods(mb, kind, -w * 0.5 + 0.1, w * 0.5 - 0.1, y, d, li, sd, br)
	# stock stacked on top: you see it from above
	var topy := hmax + 0.04
	var nt := int((w - 0.2) / 0.34) if not rev else 0
	for i in nt:
		if not keep(i, 9, sd, br):
			continue
		var tx := -w * 0.5 + 0.2 + (w - 0.4) * (float(i) + 0.5) / nt
		match int(P.hf(i, 4, sd) * 3.0):
			0: P.box(mb, Vector3(tx, topy, 0), Vector3(0.26, 0.16, minf(d * 0.8, 0.34)), P.pick([Color("a88a5a"), Color("b09a74"), Color("8a6a44")], i, 1, sd))
			1: P.sack(mb, Vector3(tx, topy, 0), P.pick([Color("a89068"), Color("b8a078")], i, 2, sd), 0.12)
			_: P.jar(mb, Vector3(tx, topy, 0), P.pick(P.BRIGHTS, i, 3, sd), 0.22, 0.07)
	mb.pop()


static func _drawer_wall(mb: MB, w: float, d: float, kind: String, sd: int, br: bool) -> void:
	var cols := maxi(3, int(w / 0.34))
	var rows := 6
	var cw := (w - 0.08) / cols
	for i in cols:
		for j in rows:
			var y := 0.18 + j * 0.28
			var open := br and P.hf(i, j, sd) > 0.8
			var c := Color("7a5a38").lerp(Color("5a3e26"), P.hf(i, j, sd + 4))
			mb.blk(-w * 0.5 + 0.04 + cw * (float(i) + 0.5), d * 0.5 - 0.02 + (0.12 if open else 0.0), cw - 0.025, 0.04, 0.23, c, "s", y)
			mb.blk(-w * 0.5 + 0.04 + cw * (float(i) + 0.5), d * 0.5 + 0.01 + (0.12 if open else 0.0), 0.06, 0.014, 0.02, P.BRASS, "m", y + 0.11)
			mb.blk(-w * 0.5 + 0.04 + cw * (float(i) + 0.5), d * 0.5 + 0.0 + (0.12 if open else 0.0), 0.06, 0.006, 0.05, P.CREAM, "s", y + 0.15)
	mb.blk(0, 0, w - 0.1, d - 0.06, 1.9, Color("4a3322"))
	if kind == "apoth":
		for i in 5:
			P.jar(mb, Vector3(-w * 0.5 + 0.2 + i * (w - 0.4) / 4.0, 1.91, 0), P.pick([Color("6aa8c8"), Color("c8a86a"), Color("8ac88a")], i, 1, sd), 0.2, 0.06)


static func shelf_goods(mb: MB, kind: String, x0: float, x1: float, y: float, d: float, lv: int, sd: int, br: bool) -> void:
	var span := x1 - x0
	match kind:
		"bread":
			var n := int(span / 0.34)
			for i in n:
				if not keep(i, lv, sd, br):
					continue
				var x := x0 + span * (float(i) + 0.5) / n
				var t := int(P.hf(i, lv, sd) * 3.0)
				if t == 0:
					P.loaf(mb, Vector3(x, y, 0.0), 1.57 * float(i % 2), 0.34)
				elif t == 1:
					for b in 3:
						P.baguette(mb, Vector3(x - 0.07 + b * 0.07, y + 0.02, 0.0), 0.1, 0.4)
				else:
					P.boule(mb, Vector3(x, y, 0.0), 0.1)
					P.roll(mb, Vector3(x + 0.12, y, 0.05))
		"grocery":
			var n2 := int(span / 0.11)
			for i in n2:
				if not keep(i, lv, sd, br):
					continue
				var x2 := x0 + span * (float(i) + 0.5) / n2
				var t2 := int(P.hf(i / 3, lv, sd) * 4.0)
				var col := P.pick([Color("c83a28"), Color("3a8a48"), Color("d6a032"), Color("3a5a96"), Color("e0d2a8")], i / 3, lv, sd)
				if t2 == 0:
					P.box(mb, Vector3(x2, y, 0.0), Vector3(0.09, 0.2, 0.1), col)
				elif t2 == 1:
					P.jar(mb, Vector3(x2, y, 0.0), col, 0.17, 0.045)
				else:
					P.can(mb, Vector3(x2, y, 0.0), col, 0.12)
					P.can(mb, Vector3(x2, y + 0.12, 0.0), col.lightened(0.1), 0.12)
		"cloth":
			var n3 := int(span / 0.25)
			for i in n3:
				var x3 := x0 + span * (float(i) + 0.5) / n3
				P.bolt(mb, Vector3(x3, y, 0.0), false, P.pick(P.CLOTHS, i, lv, sd), d * 0.9, 0.095)
				if lv < 3 and i % 2 == 0:
					P.bolt(mb, Vector3(x3, y + 0.19, 0.0), false, P.pick(P.CLOTHS, i + 5, lv, sd), d * 0.9, 0.09)
		"tonic":
			var n4 := int(span / 0.12)
			for i in n4:
				if not keep(i, lv, sd, br):
					continue
				var x4 := x0 + span * (float(i) + 0.5) / n4
				var col4 := P.pick([Color("3a6a8a"), Color("8a5a3a"), Color("3a8a5a"), Color("a8a0c8")], i, lv, sd)
				if i % 5 == 4:
					P.jar(mb, Vector3(x4, y, 0), Color("6aa8d8"), 0.2, 0.06)
				else:
					P.label_bottle(mb, Vector3(x4, y, 0.0), col4, P.CREAM, 0.26)
		"shoes":
			var n5 := int(span / 0.2)
			for i in n5:
				if not keep(i, lv, sd, br):
					continue
				var x5 := x0 + span * (float(i) + 0.5) / n5
				P.pair(mb, Vector3(x5, y, 0.0), 0.0, P.pick([Color("4a2e1e"), Color("1c1916"), Color("8a5a3a"), Color("6a3a2a")], i, lv, sd))
		"pawn":
			var n6 := int(span / 0.3)
			for i in n6:
				if not keep(i, lv, sd, br):
					continue
				var x6 := x0 + span * (float(i) + 0.5) / n6
				match int(P.hf(i, lv, sd) * 4.0):
					0:
						mb.at(Vector3(x6, y, 0))
						mb.blk(0, 0, 0.2, 0.14, 0.2, Color("3a2418"))
						mb.cyl(Vector3(0, 0.2, 0), 0.07, 0.04, P.BRASS, "m", 8)
						mb.pop()
					1:
						mb.cyl(Vector3(x6, y + 0.12, 0), 0.07, 0.24, Color("4a6a8a"), "s", 8, 0.04)
					2:
						P.box(mb, Vector3(x6, y, 0), Vector3(0.22, 0.14, 0.16), Color("6a4a2e"))
						P.pocket_watch(mb, Vector3(x6, y + 0.14, 0))
					_:
						mb.cyl(Vector3(x6, y + 0.13, 0), 0.09, 0.26, P.BRASS, "m", 8, 0.03)
		"bundles":
			var n7 := int(span / 0.32)
			for i in n7:
				if not keep(i, lv, sd, br):
					continue
				var x7 := x0 + span * (float(i) + 0.5) / n7
				P.bundle(mb, Vector3(x7, y, 0.0), 0.0, Color("c8b898").lerp(Color("e8e0d0"), P.hf(i, lv, sd)))
				if lv % 2 == 0:
					P.bundle(mb, Vector3(x7, y + 0.15, 0.0), 0.1, Color("e8e0d0"))
		"wine":
			var n8 := int(span / 0.1)
			for i in n8:
				if not keep(i, lv, sd, br):
					continue
				var x8 := x0 + span * (float(i) + 0.5) / n8
				mb.cyl_dir(Vector3(x8, y + 0.04, 0.0), Vector3(0, 0, 1), 0.04, d * 0.9, P.pick(P.BOTTLES, i, lv, sd), "s", 6, 0.03)
		"coffee":
			var n9 := int(span / 0.2)
			for i in n9:
				var x9 := x0 + span * (float(i) + 0.5) / n9
				if i % 2 == 0:
					P.tin(mb, Vector3(x9, y, 0), P.pick([Color("8a2a2a"), Color("2a4a6a"), Color("c9a54a")], i, lv, sd))
					P.tin(mb, Vector3(x9, y + 0.1, 0), Color("8a2a2a"))
				else:
					P.sack(mb, Vector3(x9, y, 0), Color("a89068"), 0.12)
		"jars":
			var n10 := int(span / 0.2)
			for i in n10:
				var x10 := x0 + span * (float(i) + 0.5) / n10
				if keep(i, lv, sd, br):
					P.jar(mb, Vector3(x10, y, 0), P.pick(P.BRIGHTS, i, lv, sd), 0.28 if lv == 0 else 0.24, 0.08)
		"pharm":
			var n11 := int(span / 0.1)
			for i in n11:
				if not keep(i, lv, sd, br):
					continue
				var x11 := x0 + span * (float(i) + 0.5) / n11
				P.label_bottle(mb, Vector3(x11, y, 0), P.pick([Color("3a6a9a"), Color("7a4a1e"), Color("3a6a3c"), Color("c8a86a")], i, lv, sd), P.CREAM, 0.2 + 0.06 * P.hf(i, 3, sd), 0.04)
			if lv == 2:
				P.jar(mb, Vector3(x0 + span * 0.2, y, 0), Color("d84a4a"), 0.3, 0.09)
				P.jar(mb, Vector3(x0 + span * 0.8, y, 0), Color("4a8ad8"), 0.3, 0.09)
		"cigars":
			var n12 := int(span / 0.3)
			for i in n12:
				if not keep(i, lv, sd, br):
					continue
				P.cigarbox(mb, Vector3(x0 + span * (float(i) + 0.5) / n12, y, 0), 0.0, lv % 2 == 0)
				P.tin(mb, Vector3(x0 + span * (float(i) + 0.5) / n12 + 0.12, y + 0.0, 0.03), P.pick([Color("8a2a2a"), Color("2a4a3a")], i, lv, sd))
		"tins":
			var n13 := int(span / 0.11)
			for i in n13:
				if not keep(i, lv, sd, br):
					continue
				var x13 := x0 + span * (float(i) + 0.5) / n13
				for s in 2:
					P.can(mb, Vector3(x13, y + s * 0.07, 0), P.pick([Color("c8402e"), Color("3a5a96"), Color("d6a032"), Color("8a9aa0")], i, lv, sd), 0.07, 0.045)
		"backbar":
			var n14 := int(span / 0.11)
			for i in n14:
				if not keep(i, lv, sd, br):
					continue
				var x14 := x0 + span * (float(i) + 0.5) / n14
				if lv == 0:
					P.glass_cup(mb, Vector3(x14, y, 0.0), Color(0, 0, 0, 0), 0.032)
				else:
					P.label_bottle(mb, Vector3(x14, y, 0.0), P.pick(P.BOTTLES, i, lv, sd), P.pick([Color("e8dcc0"), Color("c8402e")], i, 1, sd), 0.3, 0.04)
		"beer":
			var n15 := int(span / 0.12)
			for i in n15:
				if not keep(i, lv, sd, br):
					continue
				var x15 := x0 + span * (float(i) + 0.5) / n15
				if lv == 0:
					mb.cyl(Vector3(x15, y + 0.07, 0), 0.04, 0.14, Color("c8982a"), "s", 7)
					mb.cyl(Vector3(x15, y + 0.07, 0), 0.042, 0.14, Color(0.8, 0.9, 0.95, 0.25), "g", 7, -1.0, false)
				else:
					P.label_bottle(mb, Vector3(x15, y, 0.0), Color("6a4a1e") if i % 2 == 0 else P.pick(P.BOTTLES, i, lv, sd), Color("e8dcc0"), 0.26, 0.036)
		"towels":
			var n16 := int(span / 0.34)
			for i in n16:
				P.towel_stack(mb, Vector3(x0 + span * (float(i) + 0.5) / n16, y, 0), 3 + int(P.hf(i, lv, sd) * 3.0), Color("e8e2d4") if (i + lv) % 3 else Color("c8d8e0"))
		"leather":
			var n17 := int(span / 0.3)
			for i in n17:
				mb.cyl_dir(Vector3(x0 + span * (float(i) + 0.5) / n17, y + 0.09, 0), Vector3(0, 0, 1), 0.09, d * 0.9, P.pick([Color("6a3a22"), Color("3a2418"), Color("9a6a3a")], i, lv, sd), "s", 8)
		"boxes":
			var n18 := int(span / 0.3)
			for i in n18:
				if not keep(i, lv, sd, br):
					continue
				var sz := Vector3(0.24, 0.16 + 0.1 * P.hf(i, lv, sd), minf(d * 0.9, 0.3))
				P.box(mb, Vector3(x0 + span * (float(i) + 0.5) / n18, y, 0), sz, P.pick([Color("a88a5a"), Color("b09a74"), Color("8a6a44")], i, lv, sd))
		"candyboxes":
			var n19 := int(span / 0.22)
			for i in n19:
				if not keep(i, lv, sd, br):
					continue
				P.box(mb, Vector3(x0 + span * (float(i) + 0.5) / n19, y, 0), Vector3(0.18, 0.1, 0.22), P.pick(P.BRIGHTS, i, lv, sd))
				P.box(mb, Vector3(x0 + span * (float(i) + 0.5) / n19, y + 0.1, 0), Vector3(0.18, 0.1, 0.22), P.pick(P.BRIGHTS, i + 2, lv, sd))
		"sacks":
			var n20 := int(span / 0.3)
			for i in n20:
				P.sack(mb, Vector3(x0 + span * (float(i) + 0.5) / n20, y, 0), P.pick([Color("a89068"), Color("b8a078"), Color("8a7a58")], i, lv, sd), 0.13)
		"apoth":
			pass
		"cases":
			var n21 := int(span / 0.34)
			for i in n21:
				if not keep(i, lv, sd, br):
					continue
				var x21 := x0 + span * (float(i) + 0.5) / n21
				mb.blk(x21, 0, 0.3, minf(d * 0.9, 0.34), 0.2, Color("8a6a44"), "s", y)
				for b in 4:
					P.bottle(mb, Vector3(x21 - 0.1 + b * 0.067, y + 0.2, 0.0), Color("6a4a1e"), 0.12, 0.026)
		"pipes":
			var n22 := int(span / 0.12)
			for i in n22:
				mb.cyl_dir(Vector3(x0 + span * (float(i) + 0.5) / n22, y + 0.04, 0), Vector3(0, 0, 1), 0.035, d * 0.95, Color("6a6a6e"), "m", 6)
		_:
			var n23 := int(span / 0.25)
			for i in n23:
				P.box(mb, Vector3(x0 + span * (float(i) + 0.5) / n23, y, 0), Vector3(0.2, 0.14, 0.2), P.pick(P.BRIGHTS, i, lv, sd))


static func meat_hooks(mb: MB, w: float, d: float, sd: int, br: bool, rev: bool) -> void:
	# tiled wall behind, a steel rail with carcasses hanging from hooks
	if not rev:
		mb.blk(0, -d * 0.5 + 0.015, w, 0.03, 1.9, Color("e0dccc"))
		for k in int(w / 0.4):
			mb.blk(-w * 0.5 + 0.2 + k * 0.4, -d * 0.5 + 0.035, 0.38, 0.01, 1.2, Color("d0d4c8") if k % 2 else Color("e4e0d0"), "s", 0.3)
	mb.rod(Vector3(-w * 0.5, 1.78, 0.02), Vector3(w * 0.5, 1.78, 0.02), 0.02, P.STEEL, "m", 6)
	mb.blk(-w * 0.5 + 0.02, 0, 0.04, d, 1.82, P.STEEL.darkened(0.3), "m")
	mb.blk(w * 0.5 - 0.02, 0, 0.04, d, 1.82, P.STEEL.darkened(0.3), "m")
	mb.blk(0, 0.12, w, 0.3, 0.08, Color("606e72"), "m", 0.0)
	var n := int(w / 0.42)
	for i in n:
		var x := -w * 0.5 + w * (float(i) + 0.5) / n
		if br and i % 2 == 0:
			continue
		match i % 4:
			0: P.beef_side(mb, Vector3(x, 1.76, 0.02))
			1:
				P.salami(mb, Vector3(x - 0.08, 1.66, 0.02), 0.34)
				P.salami(mb, Vector3(x + 0.08, 1.64, 0.02), 0.3)
			2:
				P.links(mb, Vector3(x - 0.16, 1.64, 0.02), Vector3(x + 0.16, 1.64, 0.02), 6)
				P.ham(mb, Vector3(x, 1.5, 0.02), 0.0)
			_:
				for c in 3:
					P.chicken(mb, Vector3(x - 0.14 + c * 0.14, 1.52, 0.02), 0.0)
					mb.rod(Vector3(x - 0.14 + c * 0.14, 1.58, 0.02), Vector3(x - 0.14 + c * 0.14, 1.78, 0.02), 0.004, P.STEEL, "m", 4)


static func instruments(mb: MB, w: float, d: float, sd: int, br: bool, rev: bool) -> void:
	if not rev:
		mb.blk(0, -d * 0.5 + 0.015, w, 0.03, 1.9, Color("5a4030"))
	mb.blk(0, 0, w, d, 0.5, Color("4a3322"))
	var n := maxi(2, int(w / 0.5))
	for i in n:
		var x := -w * 0.5 + w * (float(i) + 0.5) / n
		if br and i % 3 == 0:
			continue
		match i % 4:
			0:
				# guitar standing on the shelf, leaning
				mb.at(Vector3(x, 0.5, 0.0))
				mb.atx(Vector3(0, 0.22, 0), 0.0, Vector3(1, 1, 0.3))
				mb.sph(Vector3(0, 0, 0), 0.17, Color("a8662e"), "s", 8, 5)
				mb.pop()
				mb.blk(0, 0, 0.05, 0.03, 0.55, Color("3a2418"), "s", 0.35)
				mb.pop()
			1:
				mb.at(Vector3(x, 0.5, 0.0))
				mb.cyl(Vector3(0, 0.0, 0), 0.0, 0.0, Color.BLACK)
				mb.pop()
				mb.cyl(Vector3(x, 0.5 + 0.1, 0), 0.14, 0.04, Color("e8e0d0"), "s", 10)
				mb.blk(x, 0, 0.04, 0.03, 0.5, Color("3a2418"), "s", 0.6)
			2:
				for k in 3:
					mb.cyl_dir(Vector3(x, 1.1 + k * 0.06, 0.02), Vector3(1, 0, 0), 0.03, 0.34 + k * 0.03, P.BRASS, "m", 6)
				mb.cyl(Vector3(x + 0.2, 1.14, 0.02), 0.07, 0.03, P.BRASS, "m", 8, 0.02)
			_:
				mb.atx(Vector3(x, 1.5, 0.0), 0.0, Vector3(1, 1.2, 0.4))
				mb.sph(Vector3.ZERO, 0.11, Color("8a4a24"), "s", 8, 5)
				mb.pop()
				mb.blk(x, 0.0, 0.025, 0.02, 0.4, Color("3a2418"), "s", 1.55)
	mb.blk(-w * 0.5 + 0.02, 0, 0.04, d, 1.9, Color("4a3322"))
	mb.blk(w * 0.5 - 0.02, 0, 0.04, d, 1.9, Color("4a3322"))


static func tool_wall(mb: MB, w: float, d: float, sd: int, br: bool, rev: bool) -> void:
	if not rev:
		mb.blk(0, -d * 0.5 + 0.015, w, 0.03, 1.9, Color("7a6a50"))
	mb.blk(0, 0, w, d, 0.3, Color("4a3a2a"))
	var n := maxi(3, int(w / 0.22))
	for i in n:
		var x := -w * 0.5 + w * (float(i) + 0.5) / n
		if br and i % 3 == 0:
			continue
		var y := 0.6 + P.hf(i, 1, sd) * 1.0
		mb.blk(x, 0.0, 0.04, 0.04, 0.4 + P.hf(i, 2, sd) * 0.5, P.IRON if i % 2 == 0 else Color("6a4a2a"), "m" if i % 2 == 0 else "s", y)
		mb.blk(x, 0.0, 0.09, 0.04, 0.07, P.STEEL, "m", y + 0.4)
	for lv in 3:
		mb.blk(0, 0.0, w - 0.1, d, 0.025, Color("6a4a2e"), "s", 0.45 + lv * 0.4)
		for i in int(w / 0.3):
			if not br or i % 2:
				P.tin(mb, Vector3(-w * 0.5 + 0.2 + i * 0.3, 0.475 + lv * 0.4, 0.0), P.pick([Color("b83a28"), Color("2e6a8a"), Color("d6a032")], i, lv, sd))
	mb.blk(-w * 0.5 + 0.02, 0, 0.04, d, 1.9, Color("4a3a2a"))
	mb.blk(w * 0.5 - 0.02, 0, 0.04, d, 1.9, Color("4a3a2a"))


static func bread_rack(mb: MB, w: float, d: float, sd: int, br: bool) -> void:
	mb.blk(-w * 0.5 + 0.03, d * 0.5 - 0.03, 0.05, 0.05, 1.6, P.WOOD_D)
	mb.blk(w * 0.5 - 0.03, d * 0.5 - 0.03, 0.05, 0.05, 1.6, P.WOOD_D)
	mb.blk(-w * 0.5 + 0.03, -d * 0.5 + 0.03, 0.05, 0.05, 1.6, P.WOOD_D)
	mb.blk(w * 0.5 - 0.03, -d * 0.5 + 0.03, 0.05, 0.05, 1.6, P.WOOD_D)
	for lv in 4:
		var y := 0.2 + lv * 0.4
		mb.blk(0, 0, w, d, 0.03, P.OAK, "s", y - 0.03)
		var n := maxi(2, int(d / 0.3))
		for i in n:
			if not keep(i, lv, sd, br):
				continue
			var z := -d * 0.5 + d * (float(i) + 0.5) / n
			P.loaf(mb, Vector3(0, y, z), 1.57, minf(w * 0.9, 0.46))


static func suit_rack(mb: MB, w: float, d: float, sd: int, br: bool) -> void:
	mb.blk(0, -d * 0.5 + 0.03, 0.05, 0.05, 1.7, P.WOOD_D)
	mb.blk(0, d * 0.5 - 0.03, 0.05, 0.05, 1.7, P.WOOD_D)
	mb.rod(Vector3(0, 1.62, -d * 0.5 + 0.03), Vector3(0, 1.62, d * 0.5 - 0.03), 0.014, P.BRASS, "m", 6)
	mb.blk(0, 0, w, d, 0.04, P.WOOD_D)
	var n := maxi(3, int(d / 0.13))
	for i in n:
		if br and i % 3 == 0:
			continue
		var z := -d * 0.5 + 0.12 + (d - 0.24) * float(i) / maxi(n - 1, 1)
		var c := P.pick([Color("25262b"), Color("3a3d45"), Color("4a4037"), Color("2a3040"), Color("5a5048"), Color("6a6258")], i, 1, sd)
		# jacket
		mb.blk(0, z, 0.36, 0.09, 0.62, c, "s", 0.98)
		mb.blk(0, z, 0.22, 0.092, 0.16, c.lightened(0.15), "s", 1.36)
		# trousers folded below
		mb.blk(0, z, 0.3, 0.06, 0.5, c.darkened(0.1), "s", 0.5)
		mb.blk(0, z, 0.31, 0.055, 0.02, Color("e0d8c0"), "s", 1.34)
	# hats on the top shelf
	mb.blk(0, 0, w, d, 0.025, P.OAK, "s", 1.75)
	for i in 3:
		var z2 := -d * 0.5 + 0.2 + i * (d - 0.4) * 0.5
		mb.cyl(Vector3(0, 1.8, z2), 0.12, 0.012, Color("5a4a3a"), "s", 8)
		mb.cyl(Vector3(0, 1.85, z2), 0.075, 0.09, Color("6a5a48"), "s", 8)
		mb.cyl(Vector3(0, 1.84, z2), 0.078, 0.02, Color("1c1916"), "s", 8, -1.0, false)


static func news_rack(mb: MB, w: float, d: float, sd: int, br: bool) -> void:
	mb.blk(0, 0, w, d, 0.1, P.WOOD_D)
	for lv in 4:
		var y := 0.3 + lv * 0.38
		mb.blk(0, -d * 0.2, w, 0.02, 0.35, P.WOOD, "s", y - 0.1)
		mb.quad(Vector3(-w * 0.5, y - 0.1, d * 0.45), Vector3(w * 0.5, y - 0.1, d * 0.45), Vector3(w * 0.5, y + 0.18, -d * 0.4), Vector3(-w * 0.5, y + 0.18, -d * 0.4), Color("3a2a1e"), "s")
		var n := maxi(2, int(d / 0.2))
		for i in n:
			if not keep(i, lv, sd, br):
				continue
			var z := -d * 0.5 + d * (float(i) + 0.5) / n
			var col := P.pick([Color("e0d8c0"), Color("c88a5a"), Color("d8c8a0"), Color("a8b8c8"), Color("c8a0a0")], i, lv, sd)
			mb.quad(Vector3(-w * 0.45, y - 0.08, d * 0.4), Vector3(w * 0.45, y - 0.08, d * 0.4), Vector3(w * 0.45, y + 0.17, -d * 0.38), Vector3(-w * 0.45, y + 0.17, -d * 0.38), col, "s")
			break
	mb.blk(-w * 0.5 + 0.02, 0, 0.04, d, 1.5, P.WOOD_D)
	mb.blk(w * 0.5 - 0.02, 0, 0.04, d, 1.5, P.WOOD_D)


static func cue_rack(mb: MB, w: float, d: float, sd: int, br: bool) -> void:
	mb.blk(0, -d * 0.5 + 0.02, w, 0.04, 0.2, P.WOOD_D, "s", 1.0)
	mb.blk(0, -d * 0.5 + 0.03, w, 0.05, 0.05, P.WOOD, "s", 0.55)
	var n := maxi(3, int(d / 0.14))
	for i in n:
		if br and i % 3 == 1:
			continue
		var z := -d * 0.5 + 0.1 + (d - 0.2) * float(i) / maxi(n - 1, 1)
		mb.rod(Vector3(0.0, 0.6, z), Vector3(0.0 + 0.0, 1.55, z + 0.03), 0.011, Color("c8a86a") if i % 2 else Color("8a5a2e"), "s", 5)
	mb.blk(0, 0.0, w, d, 0.04, P.WOOD_D)


static func proving_rack(mb: MB, w: float, d: float, sd: int) -> void:
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			mb.blk(sx * (w * 0.5 - 0.03), sz * (d * 0.5 - 0.03), 0.04, 0.04, 1.6, P.STEEL, "m")
	for lv in 5:
		var y := 0.22 + lv * 0.3
		mb.blk(0, 0, w - 0.04, d - 0.04, 0.02, P.STEEL.darkened(0.15), "m", y)
		mb.blk(0, 0, w - 0.1, d - 0.1, 0.012, Color("e8e0cc"), "s", y + 0.02)
		for i in maxi(2, int(w / 0.18)):
			P.loaf(mb, Vector3(-w * 0.5 + 0.12 + i * 0.16, y + 0.03, 0.0), 1.57, 0.26)
	mb.cyl(Vector3(w * 0.5 - 0.1, 0.05, d * 0.5 - 0.1), 0.05, 0.1, P.IRON, "m", 8)
	mb.cyl(Vector3(-w * 0.5 + 0.1, 0.05, d * 0.5 - 0.1), 0.05, 0.1, P.IRON, "m", 8)


static func tally_board(mb: MB, w: float, d: float, sd: int) -> void:
	mb.blk(0, -d * 0.2, w, 0.06, 1.6, Color("2a3228"), "s", 0.2)
	mb.blk(0, -d * 0.2, w + 0.06, 0.04, 0.05, P.WOOD, "s", 1.8)
	for k in 8:
		mb.blk(-w * 0.4 + (k % 4) * w * 0.22, -d * 0.2 + 0.034, 0.12, 0.004, 0.012, Color("e0dcc8"), "e", 1.5 - (k / 4) * 0.4)
	mb.blk(0, d * 0.2, w, 0.05, 0.2, P.WOOD, "s")
