extends RefCounted
## The things that make a room lived-in but never block you: chairs pulled up, stools, rugs,
## the cat, sacks, a coat rack, a spittoon, the ceiling lamps; and what's left when a shop gets
## smashed (shards, spilled goods). Drawn in the item's object frame (see kit.gd): origin at the
## centre, its front toward +y.

const Kit := preload("res://scripts/world2d/rooms/kit.gd")
const G := preload("res://scripts/world2d/rooms/goods.gd")
const S := preload("res://scripts/world2d/rooms/structure.gd")
const M := W.M

static var WOOD := Pal.COUNTER.lightened(0.1)
static var BENT := Pal.COUNTER.darkened(0.2)
static var CHROME := Pal.SKYLIGHT.lightened(0.35)
static var RED_LEATHER := Pal.FLOOR_TILE_2.darkened(0.05)

## Lies flat on the floor: drawn under the furniture.
const LOW := ["rug", "doormat", "sawdust", "puddle", "hair", "bays", "slips", "leather"]
## Hangs from the ceiling or floats in the air: drawn over everything.
const HIGH := ["lines", "smoke", "steam", "beads", "fan", "hanging"]


static func layer_of(type: String) -> int:
	if type in LOW:
		return 0
	if type in HIGH:
		return 2
	return 1


static func draw(k: Kit, d: Dictionary) -> void:
	var type := String(d["type"])
	var st := String(d.get("style", ""))
	var sd := int(d.get("seed", 0))
	match type:
		"rug":
			S.rug(k, d["lr"], st if st != "" else "persian", sd)
			return
		"doormat":
			S.doormat(k, d["lr"])
			return
	var s := k.obj(d["lr"], d["face"])
	var R := Rect2(-s * 0.5, s)
	match type:
		"chair": _chair(k, R, st, sd)
		"stool": _stool(k, R, st)
		"cat": _cat(k, R, sd)
		"sacks": _sacks(k, R, st, sd)
		"chalkboard": _chalkboard(k, R)
		"sawdust": _sawdust(k, R, sd)
		"scale": _scale(k, R, st)
		"hanging": _hanging(k, R, sd)
		"pedestal": _pedestal(k, R)
		"hatstand", "coat_rack": _coat_rack(k, R, sd)
		"spittoon": _spittoon(k, R)
		"hair": _hair(k, R, sd)
		"newspapers": _newspapers(k, R, sd)
		"leather": _leather(k, R, sd)
		"clutter": _clutter(k, R, st, sd)
		"basket": _basket(k, R, sd)
		"bundles": _bundles(k, R, sd)
		"gumball": _gumball(k, R)
		"brooms": _brooms(k, R)
		"rope": _rope(k, R)
		"puddle": _puddle(k, R, sd)
		"lines": _lines(k, R, sd)
		"steam": _steam(k, R, sd)
		"pots": _pots(k, R)
		"slips": _slips(k, R, sd)
		"palm": _palm(k, R, sd)
		"fan": _fan(k, R)
		"photos": _photos(k, R, sd)
		"portrait": _portrait(k, R)
		"flag": _flag(k, R)
		"board": _board(k, R, sd)
		"cooler": _cooler(k, R)
		"clock": _wall_clock(k, R)
		"bucket": _bucket(k, R)
		"bays": _bays(k, R)
		"pallets": _pallets(k, R, sd)
		"handtruck": _handtruck(k, R)
		"hoist": _hoist(k, R)
		"calendar": _calendar(k, R)
		"smoke": _smoke(k, R, sd)
		"beads": _beads(k, R, sd)
		"chalk": _chalk(k, R)
		_: k.top(R, WOOD, 1.5)
	k.reset()


# ------------------------------------------------------------------ seats

static func _chair(k: Kit, R: Rect2, st: String, sd: int) -> void:
	var w := R.size.x
	var h := R.size.y
	match st:
		"bentwood":
			# round cane seat, a hooped back behind (-y)
			k.shadow_disc(Vector2.ZERO, w * 0.42, 4.0)
			k.disc(Vector2(0, h * 0.04), w * 0.42, BENT)
			k.disc(Vector2(0, h * 0.04), w * 0.33, Pal.ROPE.darkened(0.08))
			k.ring(Vector2(0, h * 0.04), w * 0.22, Color(Pal.ROPE.darkened(0.3), 0.6), 1.0)
			k.ci.draw_arc(Vector2(0, h * 0.02), w * 0.5, PI * 1.12, PI * 1.88, 10, BENT.darkened(0.2), 3.0, true)
		"arm", "leather", "boss":
			var col := Pal.LEATHER if st != "arm" else Pal.AWNING_COLORS[1].darkened(0.1)
			if st == "boss":
				col = Pal.LEATHER.darkened(0.15)
			k.rbox(R.grow(-1.0), 4.0, col.darkened(0.15), 5.0)
			k.rrect(Rect2(-w * 0.32, -h * 0.18, w * 0.64, h * 0.62), 3.0, col.lightened(0.1))
			k.rrect(Rect2(-w * 0.46, -h * 0.47, w * 0.92, h * 0.3), 3.0, col.darkened(0.05))
			for sgn: float in [-1.0, 1.0]:
				k.rrect(Rect2(sgn * w * 0.34 - w * 0.12, -h * 0.25, w * 0.24, h * 0.7), 3.0, col)
			if st == "leather" or st == "boss":
				for j in 3:
					k.disc(Vector2(-w * 0.25 + j * w * 0.25, -h * 0.33), 0.9, Pal.BRASS)
		"crate":
			var c := Pal.PLANKS.lightened(0.18 + 0.1 * Draw.hash01(sd, 1))
			k.box(R.grow(-1.0), c, 4.0, 1.5)
			k.line(R.grow(-3).position, R.grow(-3).end, c.darkened(0.25), 1.5)
		_:
			# a plain wooden chair: square seat, slatted back
			k.box(Rect2(-w * 0.4, -h * 0.3, w * 0.8, h * 0.72), WOOD, 4.0, 1.5)
			k.rect(Rect2(-w * 0.44, -h * 0.47, w * 0.88, h * 0.16), WOOD.darkened(0.2))
			if st == "club":
				k.rrect(Rect2(-w * 0.3, -h * 0.2, w * 0.6, h * 0.52), 2.5, Pal.FLOOR_TILE_2.darkened(0.25))


static func _stool(k: Kit, R: Rect2, st: String) -> void:
	var r := minf(R.size.x, R.size.y) * 0.5
	match st:
		"bar", "fountain":
			k.shadow_disc(Vector2.ZERO, r, 6.0)
			k.ring(Vector2.ZERO, r * 0.95, CHROME.darkened(0.2), 2.0)
			k.disc(Vector2.ZERO, r * 0.78, RED_LEATHER if st == "fountain" else Pal.LEATHER)
			k.disc(Vector2.ZERO + k.lit * r * 0.2, r * 0.5, (RED_LEATHER if st == "fountain" else Pal.LEATHER).lightened(0.15))
			k.ring(Vector2.ZERO, r * 0.78, CHROME, 1.0)
		"crate":
			k.box(R.grow(-1.5), Pal.PLANKS.lightened(0.2), 4.0, 1.5)
		_:
			k.ball(Vector2.ZERO, r * 0.85, WOOD.lightened(0.1), 5.0, 0.12)
			k.ring(Vector2.ZERO, r * 0.5, WOOD.darkened(0.2), 1.0)


# ------------------------------------------------------------------ the cat

static func _cat(k: Kit, R: Rect2, sd: int) -> void:
	var cols := [Pal.ROPE.lerp(Pal.RUST, 0.45), Pal.SIGN_BLACK.lightened(0.12), Pal.QUAY_STONE.lightened(0.05), Pal.AWNING_CREAM.darkened(0.08)]
	var col: Color = cols[sd % cols.size()]
	var w := R.size.x
	var h := R.size.y
	# curled up asleep: an oval body, the head tucked at one end, the tail wrapped round
	k.shadow_disc(Vector2.ZERO, h * 0.5, 3.0)
	k.ellipse(Vector2(-w * 0.05, 0), Vector2(w * 0.38, h * 0.46), col.darkened(0.12))
	k.ellipse(Vector2(-w * 0.07, -h * 0.04) + k.lit * 0.8, Vector2(w * 0.32, h * 0.38), col)
	if sd % cols.size() == 0 or sd % cols.size() == 2:
		for j in 3:
			k.ci.draw_arc(Vector2(-w * 0.1, 0), w * (0.12 + j * 0.08), -0.9, 0.9, 6, col.darkened(0.25), 1.2, true)
	var hc := Vector2(w * 0.3, h * 0.08)
	k.disc(hc, h * 0.3, col)
	k.disc(hc + k.lit * 0.6, h * 0.22, col.lightened(0.08))
	for sgn: float in [-1.0, 1.0]:
		var e := hc + Vector2(h * 0.18, sgn * h * 0.2)
		k.poly(PackedVector2Array([e + Vector2(-2.5, 0), e + Vector2(3.0, sgn * 2.5), e + Vector2(0.5, -sgn * 2.0)]), col.darkened(0.1))
	k.line(hc + Vector2(h * 0.12, -2), hc + Vector2(h * 0.12, -0.5), Pal.SIGN_BLACK, 1.0)
	k.line(hc + Vector2(h * 0.12, 0.5), hc + Vector2(h * 0.12, 2), Pal.SIGN_BLACK, 1.0)
	var tail := PackedVector2Array()
	for j in 8:
		var a := PI * 0.1 + j * 0.2
		tail.append(Vector2(-w * 0.05, 0) + Vector2(cos(a) * w * 0.4, sin(a) * h * 0.52))
	k.pline(tail, col.darkened(0.2), 3.0)


# ------------------------------------------------------------------ the trades' odds and ends

static func _sacks(k: Kit, R: Rect2, st: String, sd: int) -> void:
	var col: Color
	match st:
		"flour": col = Pal.AWNING_CREAM.darkened(0.04)
		"coffee": col = Pal.ROPE.darkened(0.12)
		_: col = Pal.ROPE.darkened(0.25)
	var n := maxi(1, int(R.size.y / 15.0))
	for j in n:
		var c := Vector2((Draw.hash01(j, 1, sd) - 0.5) * R.size.x * 0.2, R.position.y + (j + 0.5) * R.size.y / n)
		G.sack(k, c, Vector2(R.size.x * 0.85, R.size.y / n * 1.1), (Draw.hash01(j, 2, sd) - 0.5) * 0.5, col.darkened(0.05 * (j % 2)))
		if st == "flour":
			k.text_on(c, "FLOUR", 5, Color(Pal.AWNING_COLORS[2], 0.8), "cond")
		elif st == "coffee":
			k.text_on(c, "SANTOS", 5, Color(Pal.SIGN_BLACK, 0.6), "cond")


static func _chalkboard(k: Kit, R: Rect2) -> void:
	k.rect(R.grow(1.0), WOOD)
	k.rect(R, Pal.SIGN_BLACK.lightened(0.15))


static func _sawdust(k: Kit, R: Rect2, sd: int) -> void:
	var col := Color(Pal.ROPE.lightened(0.25), 0.5)
	var n := int(R.size.x * R.size.y / 60.0)
	for j in n:
		var p := R.position + Vector2(Draw.hash01(j, 1, sd), Draw.hash01(j, 2, sd)) * R.size
		k.disc(p, 0.8 + Draw.hash01(j, 3, sd) * 0.9, col)


static func _scale(k: Kit, R: Rect2, st: String) -> void:
	var c := Vector2.ZERO
	var r := minf(R.size.x, R.size.y) * 0.45
	if st == "platform":
		k.box(R.grow(-2), Pal.MANHOLE.lightened(0.15), 3.0, 2.0)
		k.rect(R.grow(-6), Pal.PLANKS.darkened(0.1))
		k.rect(Rect2(R.position.x + 2, R.position.y + 2, 6, R.size.y - 4), Pal.MANHOLE.lightened(0.25))
		k.disc(Vector2(R.position.x + 5, R.position.y + 8), 4.0, Pal.AWNING_CREAM)
		k.ring(Vector2(R.position.x + 5, R.position.y + 8), 4.0, Pal.BRASS, 1.0)
		return
	if st == "penny":
		k.ball(c, r, Pal.FLOOR_TILE_2, 10.0, 0.25)
		k.disc(c, r * 0.6, Pal.AWNING_CREAM)
		k.line(c, c + Vector2(0, -r * 0.5), Pal.SIGN_BLACK, 1.0)
		k.ring(c, r * 0.6, Pal.BRASS, 1.0)
		return
	k.ball(c, r, Pal.AWNING_CREAM.darkened(0.1), 8.0, 0.2)
	k.disc(c, r * 0.72, Pal.BRASS)
	k.disc(c, r * 0.6, Pal.BRASS.lightened(0.2))
	k.line(c, c + Vector2(r * 0.4, -r * 0.3), Pal.SIGN_BLACK, 1.0)


static func _hanging(k: Kit, R: Rect2, sd: int) -> void:
	# salami, provolone and hams hung from a rail over the counter
	k.line(Vector2(R.position.x, 0), Vector2(R.end.x, 0), Pal.MANHOLE.lightened(0.25), 1.5)
	var n := maxi(2, int(R.size.x / 12.0))
	for j in n:
		var x := R.position.x + (j + 0.5) * R.size.x / n
		match (j + sd) % 3:
			0: G.salami(k, Vector2(x, 2), 11.0, PI * 0.5)
			1: k.ball(Vector2(x, 2), 4.0, Pal.GOLD2.darkened(0.1), 6.0, 0.25)
			_: G.ham(k, Vector2(x, 2), 9.0, PI * 0.5)


static func _pedestal(k: Kit, R: Rect2) -> void:
	var r := minf(R.size.x, R.size.y) * 0.45
	k.ball(Vector2.ZERO, r, Pal.MARBLE, 5.0, 0.2)
	k.ring(Vector2.ZERO, r * 0.7, Pal.MARBLE.darkened(0.15), 1.0)
	G.bolt(k, Rect2(-r * 0.6, -r * 0.35, r * 1.2, r * 0.7), G.CLOTHS[3], true)


static func _coat_rack(k: Kit, R: Rect2, sd: int) -> void:
	var r := minf(R.size.x, R.size.y) * 0.5
	k.shadow_disc(Vector2.ZERO, r * 0.8, 16.0, 0.18)
	for j in 4:
		var a := j * PI * 0.5 + 0.4
		k.line(Vector2.ZERO, Vector2.from_angle(a) * r * 0.9, BENT, 2.0)
	# a hat and a coat on the hooks
	var hat_col: Color = Pal.SUITS[sd % Pal.SUITS.size()]
	k.ellipse(Vector2(r * 0.35, -r * 0.3), Vector2(r * 0.5, r * 0.42), hat_col.darkened(0.1))
	k.ellipse(Vector2(r * 0.35, -r * 0.3), Vector2(r * 0.3, r * 0.25), hat_col.lightened(0.08))
	k.ellipse(Vector2(-r * 0.3, r * 0.3), Vector2(r * 0.45, r * 0.6), Pal.SUITS[(sd + 3) % Pal.SUITS.size()], 0.6)
	k.disc(Vector2.ZERO, 2.5, BENT.lightened(0.2))


static func _spittoon(k: Kit, R: Rect2) -> void:
	var r := minf(R.size.x, R.size.y) * 0.45
	k.ball(Vector2.ZERO, r, Pal.BRASS, 4.0, 0.35)
	k.disc(Vector2.ZERO, r * 0.45, Pal.SIGN_BLACK.lightened(0.1))
	k.ring(Vector2.ZERO, r * 0.62, Pal.BRASS.lightened(0.25), 1.0)


static func _hair(k: Kit, R: Rect2, sd: int) -> void:
	var segs := PackedVector2Array()
	for j in 40:
		var p := R.position + Vector2(Draw.hash01(j, 1, sd), Draw.hash01(j, 2, sd)) * R.size
		var d := Vector2.from_angle(Draw.hash01(j, 3, sd) * TAU) * (1.0 + Draw.hash01(j, 4, sd) * 2.0)
		segs.append_array([p, p + d])
	k.lines(segs, Color(Pal.SIGN_BLACK.lightened(0.15), 0.55), 1.0)
	for j in 6:
		var p2 := R.position + Vector2(Draw.hash01(j, 7, sd), Draw.hash01(j, 8, sd)) * R.size
		k.disc(p2, 1.8, Color(Pal.RUST.darkened(0.3), 0.35))


static func _newspapers(k: Kit, R: Rect2, sd: int) -> void:
	G.newspaper(k, R.grow(-1.0), 0.15, 0.7)
	G.newspaper(k, Rect2(R.position + Vector2(2, 3), R.size - Vector2(3, 4)), -0.2, 0.2 + 0.1 * (sd % 3))


static func _leather(k: Kit, R: Rect2, sd: int) -> void:
	for j in 3:
		var r := Rect2(R.position + Vector2(1 + j * 1.5, 2 + j * R.size.y * 0.3), Vector2(R.size.x - 3, R.size.y * 0.32))
		k.rrect(r, 4.0, [Pal.LEATHER, Pal.RUST, Pal.LEATHER.darkened(0.2)][(j + sd) % 3])


static func _clutter(k: Kit, R: Rect2, st: String, sd: int) -> void:
	if st == "gramophone":
		k.box(Rect2(-R.size.x * 0.35, -R.size.y * 0.35, R.size.x * 0.7, R.size.y * 0.7), Pal.COUNTER.lightened(0.15), 6.0)
		k.disc(Vector2(0, 0), R.size.x * 0.25, Pal.SIGN_BLACK)
		k.ring(Vector2(0, 0), R.size.x * 0.15, Pal.SIGN_BLACK.lightened(0.2), 1.0)
		# the horn, a brass flower
		var hc := Vector2(R.size.x * 0.12, -R.size.y * 0.15)
		k.disc(hc, R.size.x * 0.32, Pal.BRASS.darkened(0.1))
		k.disc(hc, R.size.x * 0.24, Pal.BRASS.lightened(0.15))
		k.disc(hc, R.size.x * 0.07, Pal.SIGN_BLACK.lightened(0.2))
		return
	# a bicycle leaned against the wall, and a trunk
	var y := 0.0
	var r := R.size.y * 0.22
	for sgn: float in [-1.0, 1.0]:
		k.ring(Vector2(sgn * R.size.x * 0.28, y), r, Pal.SIGN_BLACK.lightened(0.15), 2.0)
		k.ring(Vector2(sgn * R.size.x * 0.28, y), r * 0.2, Pal.TRACK, 1.0)
	k.pline(PackedVector2Array([Vector2(-R.size.x * 0.28, y), Vector2(-R.size.x * 0.02, y - r * 0.8), Vector2(R.size.x * 0.2, y - r * 0.8), Vector2(R.size.x * 0.28, y)]), Pal.AWNING_COLORS[0].darkened(0.1), 2.0)
	k.line(Vector2(R.size.x * 0.2, y - r * 0.8), Vector2(R.size.x * 0.24, y - r * 1.3), Pal.TRACK, 2.0)
	var _unused := sd


static func _basket(k: Kit, R: Rect2, sd: int) -> void:
	var r := minf(R.size.x, R.size.y) * 0.46
	k.ball(Vector2.ZERO, r, Pal.ROPE.darkened(0.1), 6.0, 0.08)
	k.disc(Vector2.ZERO, r * 0.78, Pal.ROPE.darkened(0.3))
	for j in 5:
		G.towel(k, Rect2(Vector2(-r * 0.6 + j * 2.0, -r * 0.5 + (j % 2) * 3.0), Vector2(r * 0.9, r * 0.5)))
	var _unused := sd


static func _bundles(k: Kit, R: Rect2, sd: int) -> void:
	var n := maxi(1, int(R.size.y / 12.0))
	for j in n:
		var r := Rect2(R.position.x + 1, R.position.y + j * R.size.y / n + 1, R.size.x - 2, R.size.y / n - 2)
		G.bundle(k, r, Draw.hash01(j, 4, sd))


static func _gumball(k: Kit, R: Rect2) -> void:
	var r := minf(R.size.x, R.size.y) * 0.45
	k.ball(Vector2.ZERO, r, Pal.FLOOR_TILE_2, 14.0, 0.2)
	k.disc(Vector2.ZERO, r * 0.78, Color(Pal.GLASS.lightened(0.3), 0.9))
	for j in 9:
		var p := Vector2.from_angle(j * 2.4) * r * (0.2 + 0.45 * Draw.hash01(j, 1, 5))
		k.disc(p, 1.6, G.BRIGHTS[j % G.BRIGHTS.size()])
	k.disc(Vector2.ZERO + k.lit * r * 0.4, r * 0.2, Color(1, 1, 1, 0.55))


static func _brooms(k: Kit, R: Rect2) -> void:
	for j in 3:
		var x := R.position.x + (j + 0.5) * R.size.x / 3.0
		k.line(Vector2(x, R.position.y), Vector2(x + 2, R.end.y - 5), Pal.COUNTER.lightened(0.2), 1.5)
		k.ellipse(Vector2(x + 2, R.end.y - 3), Vector2(3.5, 2.5), Pal.ROPE.lightened(0.1))


static func _rope(k: Kit, R: Rect2) -> void:
	var r := minf(R.size.x, R.size.y) * 0.46
	k.shadow_disc(Vector2.ZERO, r, 3.0)
	for j in 4:
		k.ring(Vector2.ZERO, r * (1.0 - j * 0.2), Pal.ROPE.darkened(0.05 * j), 2.5)


static func _puddle(k: Kit, R: Rect2, sd: int) -> void:
	for j in 3:
		var c := R.get_center() + Vector2(Draw.hash01(j, 1, sd) - 0.5, Draw.hash01(j, 2, sd) - 0.5) * R.size * 0.5
		k.ellipse(c, R.size * (0.22 + 0.1 * Draw.hash01(j, 3, sd)), Color(Pal.GLASS.lightened(0.25), 0.2), Draw.hash01(j, 4, sd))


static func _lines(k: Kit, R: Rect2, sd: int) -> void:
	# washing lines across the back room, sheets and shirts pegged out
	var n := maxi(2, int(R.size.y / (0.9 * M)))
	for j in n:
		var y := R.position.y + (j + 0.5) * R.size.y / n
		k.line(Vector2(R.position.x, y), Vector2(R.end.x, y), Color(Pal.AWNING_CREAM, 0.7), 1.0)
		var x := R.position.x + 6
		var q := 0
		while x < R.end.x - 14:
			var w := 12.0 + Draw.hash01(j, q, sd) * 14.0
			var col: Color = [Pal.AWNING_CREAM.lightened(0.1), Pal.PAPER, Pal.AWNING_COLORS[2].lightened(0.45), Pal.AWNING_CREAM][(j + q) % 4]
			k.rect(Rect2(x + 3, y - 2 + 3, w, 7), Color(Kit.SH_COL, 0.18))
			k.rect(Rect2(x, y - 2, w, 7), col)
			k.line(Vector2(x, y - 2), Vector2(x + w, y - 2), col.darkened(0.15), 1.0)
			x += w + 5.0 + Draw.hash01(q, j, sd) * 8.0
			q += 1


static func _steam(k: Kit, R: Rect2, sd: int) -> void:
	for j in 6:
		var c := R.get_center() + Vector2(Draw.hash01(j, 1, sd) - 0.5, Draw.hash01(j, 2, sd) - 0.5) * R.size * 0.7
		k.disc(c, R.size.x * (0.18 + 0.12 * Draw.hash01(j, 3, sd)), Color(1, 1, 1, 0.1))


static func _pots(k: Kit, R: Rect2) -> void:
	# copper pots hung on the wall rail
	var n := maxi(2, int(R.size.x / 14.0))
	for j in n:
		var c := Vector2(R.position.x + (j + 0.5) * R.size.x / n, 0)
		k.ball(c, 5.0 + (j % 2) * 1.5, Pal.RUST.lightened(0.15), 3.0, 0.3)
		k.line(c, c + Vector2(0, -8), Pal.RUST.darkened(0.1), 2.0)


static func _slips(k: Kit, R: Rect2, sd: int) -> void:
	for j in 10:
		var p := R.position + Vector2(Draw.hash01(j, 1, sd), Draw.hash01(j, 2, sd)) * R.size
		G.paper(k, Rect2(p, Vector2(7, 5)), Draw.hash01(j, 3, sd) * PI, 1)


static func _palm(k: Kit, R: Rect2, sd: int) -> void:
	var r := minf(R.size.x, R.size.y) * 0.5
	k.ball(Vector2.ZERO, r * 0.45, Pal.RUST.lightened(0.1), 6.0, 0.2)
	for j in 7:
		var a := j * TAU / 7.0 + Draw.hash01(j, 1, sd) * 0.4
		var tip := Vector2.from_angle(a) * r * 1.05
		var side := Vector2.from_angle(a + PI * 0.5) * r * 0.16
		k.shadow_poly(PackedVector2Array([Vector2.ZERO, tip * 0.5 + side, tip, tip * 0.5 - side]), 10.0, 0.18)
		k.poly(PackedVector2Array([Vector2.ZERO, tip * 0.5 + side, tip, tip * 0.5 - side]), Pal.AWNING_COLORS[1].lightened(0.15 + 0.08 * (j % 2)))
		k.line(Vector2.ZERO, tip, Pal.AWNING_COLORS[1].darkened(0.1), 1.0)


static func _fan(k: Kit, R: Rect2) -> void:
	# a ceiling fan: four wooden blades round a brass hub
	var r := minf(R.size.x, R.size.y) * 0.5
	for j in 4:
		var a := j * PI * 0.5 + 0.3
		var d := Vector2.from_angle(a)
		var n := Vector2(-d.y, d.x)
		var pts := PackedVector2Array([d * r * 0.15 + n * 3.0, d * r + n * 4.5, d * r - n * 4.5, d * r * 0.15 - n * 3.0])
		k.shadow_poly(pts, 30.0, 0.12)
		k.poly(pts, Pal.COUNTER.lightened(0.12))
		k.line(d * r * 0.2, d * r * 0.95, Pal.COUNTER.lightened(0.3), 1.0)
	k.disc(Vector2.ZERO, 5.0, Pal.BRASS)
	k.disc(Vector2.ZERO + k.lit * 1.5, 2.0, Pal.BRASS.lightened(0.4))


static func _portrait(k: Kit, R: Rect2) -> void:
	# the family portrait in a heavy gilt frame over the desk: the old Don seated, his sons standing
	# behind him, painted dark and varnished. Drawn leaning off the wall so it reads from above.
	var fr := Rect2(R.position.x, R.position.y - 1.0, R.size.x, 0.42 * M)
	k.shadow(fr, 6.0, 0.3)
	k.rect(fr, Pal.SIGN_GOLD.darkened(0.12))
	k.edges(fr, Pal.SIGN_GOLD.darkened(0.12), 2.0, 0.3, 0.35)
	var cv := fr.grow(-4.0)
	k.grad(cv, Pal.LEATHER.darkened(0.35), Pal.LEATHER.darkened(0.6))
	var cx := cv.get_center().x
	var base := cv.end.y
	var skin: Color = Pal.SKIN[1].darkened(0.25)
	for q in 3:
		var x := cx + (q - 1) * cv.size.x * 0.26
		var hy := base - cv.size.y * (0.62 if q != 1 else 0.48)
		k.ellipse(Vector2(x, base - 1.0), Vector2(cv.size.x * 0.12, cv.size.y * 0.3), Pal.SUITS[0].darkened(0.2))
		k.disc(Vector2(x, hy), cv.size.y * 0.13, skin)
		k.disc(Vector2(x, hy - cv.size.y * 0.08), cv.size.y * 0.1, Pal.SIGN_BLACK.lightened(0.05))
	k.ci.draw_rect(cv, Color(Pal.SIGN_GOLD, 0.6), false, 1.0)
	# the brass nameplate
	k.rect(Rect2(cx - 7, fr.end.y - 3.5, 14, 3), Pal.BRASS.lightened(0.15))


static func _photos(k: Kit, R: Rect2, sd: int) -> void:
	# framed photographs along the wall: boxers, a ship, the old country
	var n := maxi(2, int(R.size.x / 18.0))
	for j in n:
		var x := R.position.x + (j + 0.5) * R.size.x / n
		var w := 11.0 + (j % 2) * 3.0
		var h := 9.0 + ((j + 1) % 2) * 3.0
		var fr := Rect2(x - w * 0.5, R.position.y - 1.0, w, h)
		k.shadow(fr, 3.0, 0.25)
		var col := Pal.SIGN_GOLD.darkened(0.25) if (j + sd) % 2 == 0 else Pal.SIGN_BLACK.lightened(0.12)
		k.rect(fr, col)
		k.rect(fr.grow(-2.0), Pal.PAPER.darkened(0.25 + 0.1 * (j % 2)))
		k.disc(fr.get_center() + Vector2(0, 0.5), 2.0, Color(Pal.PAPER_INK, 0.45))


static func _flag(k: Kit, R: Rect2) -> void:
	var r := minf(R.size.x, R.size.y) * 0.5
	k.ball(Vector2.ZERO, r * 0.35, Pal.BRASS, 20.0, 0.3)
	# the furled flag drapes down from the pole top
	var pts := PackedVector2Array([Vector2(-1, -1), Vector2(r * 0.9, r * 0.3), Vector2(r * 0.6, r * 0.9), Vector2(-1, r * 0.4)])
	k.poly(pts, Pal.AWNING_COLORS[2].lightened(0.1))
	k.line(Vector2(r * 0.1, r * 0.1), Vector2(r * 0.7, r * 0.5), Pal.AWNING_CREAM, 1.5)
	k.line(Vector2(r * 0.1, r * 0.35), Vector2(r * 0.55, r * 0.75), Pal.FLOOR_TILE_2.lightened(0.2), 1.5)
	k.disc(Vector2.ZERO, 1.8, Pal.GOLD2)


static func _board(k: Kit, R: Rect2, sd: int) -> void:
	# the notice board: WANTED bills pinned up (seen from above: their top edges)
	k.rect(R.grow(1.0), Pal.COUNTER)
	var n := maxi(2, int(R.size.x / 10.0))
	for j in n:
		k.rect(Rect2(R.position.x + j * R.size.x / n + 1, R.position.y - 1, R.size.x / n - 2, R.size.y + 4), Pal.PAPER.darkened(0.05 * (j % 2)))
	var _unused := sd


static func _cooler(k: Kit, R: Rect2) -> void:
	var r := minf(R.size.x, R.size.y) * 0.45
	k.ball(Vector2.ZERO, r, Pal.AWNING_CREAM.darkened(0.1), 14.0, 0.2)
	k.disc(Vector2.ZERO, r * 0.7, Color(Pal.GLASS.lightened(0.2), 0.85))
	k.disc(Vector2.ZERO + k.lit * r * 0.3, r * 0.2, Color(1, 1, 1, 0.6))


static func _wall_clock(k: Kit, R: Rect2) -> void:
	k.rrect(Rect2(R.position.x, R.position.y - 1, R.size.x, R.size.y + 3), 2.0, Pal.COUNTER.lightened(0.1))
	k.disc(Vector2(0, R.end.y + 1), 2.0, Pal.BRASS)


static func _bucket(k: Kit, R: Rect2) -> void:
	var r := minf(R.size.x, R.size.y) * 0.45
	k.ball(Vector2.ZERO, r, Pal.TRACK, 4.0, 0.2)
	k.disc(Vector2.ZERO, r * 0.72, Pal.TRACK.darkened(0.4))
	k.ci.draw_arc(Vector2.ZERO, r * 1.05, PI * 0.1, PI * 0.9, 8, Pal.MANHOLE, 1.0, true)


static func _bays(k: Kit, R: Rect2) -> void:
	# painted bay lines on the concrete where the pallets go, an empty pallet or two in each
	var c := Color(Pal.SIGN_GOLD.darkened(0.1), 0.55)
	var nb := maxi(1, int(R.size.x / (2.4 * M)))
	for j in nb:
		var bx := R.position.x + j * R.size.x / nb
		var bw := R.size.x / nb
		for q in 2:
			var pr := Rect2(bx + bw * 0.5 - 0.6 * M, R.position.y + 0.9 * M + q * 1.5 * M, 1.2 * M, 1.0 * M)
			if pr.end.y > R.end.y - 0.3 * M:
				continue
			k.shadow(pr, 2.0, 0.2)
			k.rect(pr, Pal.PLANKS.lightened(0.1))
			var segs := PackedVector2Array()
			for m in 5:
				var y := pr.position.y + (m + 0.5) * pr.size.y / 5.0
				segs.append_array([Vector2(pr.position.x + 1, y), Vector2(pr.end.x - 1, y)])
			k.lines(segs, Pal.PLANKS.darkened(0.3), 2.0)
	k.ci.draw_rect(R, c, false, 3.0)
	var n := maxi(1, int(R.size.x / (2.4 * M)))
	var segs := PackedVector2Array()
	for j in range(1, n):
		var x := R.position.x + j * R.size.x / n
		segs.append_array([Vector2(x, R.position.y), Vector2(x, R.end.y)])
	k.lines(segs, c, 2.0)
	for j in n:
		var x2 := R.position.x + (j + 0.5) * R.size.x / n
		k.text_on(Vector2(x2, R.position.y + 12), "BAY %d" % (j + 1), 11, Color(Pal.SIGN_GOLD, 0.5), "cond")


static func _pallets(k: Kit, R: Rect2, sd: int) -> void:
	# empty pallets stacked by the door
	for j in 3:
		var r := R.grow(-2.0 - j * 1.0)
		r.position += Vector2(j * 1.5, -j * 1.5)
		k.box(r, Pal.PLANKS.lightened(0.15 + 0.05 * j), 3.0 + j * 2.0, 1.5)
		var segs := PackedVector2Array()
		for q in 4:
			var y := r.position.y + (q + 0.5) * r.size.y / 4.0
			segs.append_array([Vector2(r.position.x + 1, y), Vector2(r.end.x - 1, y)])
		k.lines(segs, Pal.PLANKS.darkened(0.2), 1.0)
	var _unused := sd


static func _handtruck(k: Kit, R: Rect2) -> void:
	k.shadow(R.grow(-3), 3.0)
	k.line(Vector2(-R.size.x * 0.3, -R.size.y * 0.45), Vector2(-R.size.x * 0.3, R.size.y * 0.4), Pal.FELT.darkened(0.2), 2.5)
	k.line(Vector2(R.size.x * 0.3, -R.size.y * 0.45), Vector2(R.size.x * 0.3, R.size.y * 0.4), Pal.FELT.darkened(0.2), 2.5)
	k.rect(Rect2(-R.size.x * 0.4, R.size.y * 0.3, R.size.x * 0.8, 5), Pal.TRACK)
	for sgn: float in [-1.0, 1.0]:
		k.rect(Rect2(sgn * R.size.x * 0.4 - 3, R.size.y * 0.05, 6, 10), Pal.SIGN_BLACK.lightened(0.1))


static func _hoist(k: Kit, R: Rect2) -> void:
	# a chain hoist from the roof beam: hook and chain seen from above
	k.line(Vector2(R.position.x, 0), Vector2(R.end.x, 0), Pal.RUST.darkened(0.1), 4.0)
	k.rect(Rect2(-6, -5, 12, 10), Pal.AWNING_COLORS[3].darkened(0.1))
	for j in 5:
		k.ring(Vector2(0, 7 + j * 3.0), 1.5, Pal.TRACK, 1.0)
	k.ci.draw_arc(Vector2(0, 24), 3.5, 0.0, PI * 1.4, 8, Pal.TRACK.lightened(0.2), 2.0, true)


static func _calendar(k: Kit, R: Rect2) -> void:
	k.rect(Rect2(R.position.x - 1, R.position.y, R.size.x + 3, R.size.y), Pal.PAPER)
	k.rect(Rect2(R.position.x - 1, R.position.y, R.size.x + 3, 4), Pal.FLOOR_TILE_2)


static func _smoke(k: Kit, R: Rect2, sd: int) -> void:
	for j in 7:
		var c := R.position + Vector2(Draw.hash01(j, 1, sd), Draw.hash01(j, 2, sd)) * R.size
		k.ellipse(c, Vector2(1.0, 0.6) * M * (0.6 + 0.6 * Draw.hash01(j, 3, sd)), Color(Pal.PAPER, 0.05), Draw.hash01(j, 4, sd) * PI)


static func _beads(k: Kit, R: Rect2, sd: int) -> void:
	# the score wire over the tables, a few beads pushed along
	k.line(Vector2(R.position.x, 0), Vector2(R.end.x, 0), Color(Pal.SIGN_BLACK, 0.6), 1.0)
	var n := int(R.size.x / 5.0)
	for j in n:
		if Draw.hash01(j, 1, sd) > 0.4:
			continue
		var x := R.position.x + (j + 0.5) * R.size.x / n
		k.disc(Vector2(x, 0), 1.6, Pal.AWNING_CREAM if j % 3 != 0 else Pal.SIGN_BLACK.lightened(0.2))


static func _chalk(k: Kit, R: Rect2) -> void:
	k.rect(Rect2(-3, -3, 6, 6), Pal.AWNING_COLORS[2].lightened(0.3))
	k.rect(Rect2(3, -1, 5, 5), Pal.AWNING_COLORS[2].lightened(0.2))


# ------------------------------------------------------------------ ceiling lamps

## A lamp seen from above: its shade and, lit, the glow of the bulb. `glow` = 0 (day) .. 1 (night).
static func lamp(k: Kit, l: Dictionary, glow: float) -> void:
	var p: Vector2 = l["p"]
	k.frame(p, 0.0)
	var warm := Pal.LAMP
	match String(l["style"]):
		"shade":
			# a green enamel shade on a cord
			k.shadow_disc(Vector2.ZERO, 8.0, 34.0, 0.14)
			k.disc(Vector2.ZERO, 8.0, Pal.FELT.darkened(0.1))
			k.disc(Vector2.ZERO + k.lit * 2.0, 6.0, Pal.FELT.lightened(0.12))
			k.disc(Vector2.ZERO, 2.5, Pal.AWNING_CREAM.lerp(warm, glow))
		"bulb", "cage":
			k.shadow_disc(Vector2.ZERO, 3.5, 30.0, 0.12)
			if String(l["style"]) == "cage":
				k.ring(Vector2.ZERO, 5.0, Pal.MANHOLE.lightened(0.2), 1.0)
				k.line(Vector2(-5, 0), Vector2(5, 0), Pal.MANHOLE.lightened(0.2), 1.0)
				k.line(Vector2(0, -5), Vector2(0, 5), Pal.MANHOLE.lightened(0.2), 1.0)
			k.disc(Vector2.ZERO, 3.2, Pal.AWNING_CREAM.lerp(warm.lightened(0.3), glow))
			k.disc(Vector2(-0.8, -0.8), 1.2, Color(1, 1, 1, 0.8))
		"industrial":
			k.shadow_disc(Vector2.ZERO, 12.0, 60.0, 0.12)
			k.disc(Vector2.ZERO, 12.0, Pal.FELT.darkened(0.3))
			k.ring(Vector2.ZERO, 11.0, Pal.FELT.lightened(0.1), 1.5)
			k.disc(Vector2.ZERO, 4.0, Pal.AWNING_CREAM.lerp(warm, glow))
		"billiard":
			# the long green shade over the pool table
			# two green enamel shades on a brass bar, hung low over the table
			k.line(Vector2(-20, 0), Vector2(20, 0), Pal.BRASS.darkened(0.1), 2.5)
			k.line(Vector2(-20, -1), Vector2(20, -1), Pal.BRASS.lightened(0.3), 1.0)
			for sgn: float in [-1.0, 1.0]:
				var c := Vector2(sgn * 12.0, 0)
				k.shadow_disc(c, 7.0, 30.0, 0.16)
				k.disc(c, 7.0, Pal.AWNING_COLORS[1].darkened(0.55))
				k.disc(c + k.lit * 1.5, 5.2, Pal.AWNING_COLORS[1].darkened(0.2))
				k.ring(c, 7.0, Pal.BRASS, 1.0)
				k.disc(c, 1.8, Pal.BRASS.lightened(0.2))
		"globe":
			k.shadow_disc(Vector2.ZERO, 7.0, 34.0, 0.12)
			k.disc(Vector2.ZERO, 7.0, Pal.AWNING_CREAM.darkened(0.05).lerp(warm, glow * 0.8))
			k.disc(Vector2.ZERO + k.lit * 2.0, 3.5, Color(1, 1, 1, 0.5))
			k.ring(Vector2.ZERO, 7.0, Pal.BRASS.darkened(0.2), 1.0)
		"chandelier":
			k.shadow_disc(Vector2.ZERO, 12.0, 36.0, 0.12)
			k.ring(Vector2.ZERO, 11.0, Pal.BRASS, 1.5)
			for j in 6:
				var q := Vector2.from_angle(j * TAU / 6.0) * 11.0
				k.line(Vector2.ZERO, q, Pal.BRASS.darkened(0.1), 1.0)
				k.disc(q, 3.0, Pal.AWNING_CREAM.lerp(warm.lightened(0.2), glow))
			k.disc(Vector2.ZERO, 3.5, Pal.BRASS.lightened(0.2))
		"banker":
			# the green glass desk lamp
			k.rrect(Rect2(-7, -3, 14, 6), 3.0, Pal.AWNING_COLORS[1].lightened(0.1))
			k.rect(Rect2(-6, -1, 12, 1.5), Pal.AWNING_COLORS[1].lightened(0.4))
			k.disc(Vector2(0, 4), 2.0, Pal.BRASS)
		"speak":
			# a red silk shade, tasselled
			k.shadow_disc(Vector2.ZERO, 9.0, 30.0, 0.14)
			var pts := PackedVector2Array()
			for j in 8:
				pts.append(Vector2.from_angle(j * TAU / 8.0 + PI / 8.0) * 9.0)
			k.poly(pts, Pal.FLOOR_TILE_2.darkened(0.05))
			k.pline(Kit._closed(pts), Pal.GOLD.darkened(0.1), 1.0)
			for q in pts:
				k.disc(q * 1.15, 1.2, Pal.GOLD)
			k.disc(Vector2.ZERO, 3.0, Pal.AWNING_CREAM.lerp(warm, glow))
		_:
			# pendant: an opal glass bowl on three chains
			k.shadow_disc(Vector2.ZERO, 7.5, 34.0, 0.13)
			k.disc(Vector2.ZERO, 7.5, Pal.BRASS.darkened(0.15))
			k.disc(Vector2.ZERO, 6.0, Pal.AWNING_CREAM.lerp(warm.lightened(0.25), glow))
			k.disc(Vector2.ZERO + k.lit * 2.0, 2.5, Color(1, 1, 1, 0.55))
			k.disc(Vector2.ZERO, 1.8, Pal.BRASS)
	k.reset()


# ------------------------------------------------------------------ what a shakedown leaves

## Glass and goods on the floor in front of a smashed item (object frame: its front is +y).
static func debris(k: Kit, it: Dictionary, trade: String) -> void:
	var s := k.obj(it["lr"], it["face"])
	var R := Rect2(-s * 0.5, s)
	var sd := int(it.get("seed", 0)) + 911
	var type := String(it["type"])
	var front := Rect2(R.position.x - 4, R.end.y, R.size.x + 8, 0.7 * M)
	if type == "window":
		# the glass blew out onto the sidewalk (+y is the street) and a little fell inside
		var out := Rect2(R.position.x - 6, R.end.y + 2, R.size.x + 12, 0.9 * M)
		k.shards(out, int(out.size.x / 5.0), sd)
		k.shards(Rect2(R.position.x, R.position.y - 0.5 * M, R.size.x, 0.5 * M), int(R.size.x / 12.0), sd + 3)
		k.reset()
		return
	if type in ["display", "window", "mirror", "bar"] or String(it["art"]).ends_with("case"):
		k.shards(front, int(front.size.x / 7.0) + 4, sd)
	_spill(k, front, trade, String(it["art"]), sd)
	k.reset()


static func _spill(k: Kit, r: Rect2, trade: String, art: String, sd: int) -> void:
	var n := clampi(int(r.size.x / 12.0), 3, 12)
	for j in n:
		var c := r.position + Vector2(Draw.hash01(j, 1, sd), Draw.hash01(j, 2, sd) * 0.8 + 0.1) * r.size
		var a := Draw.hash01(j, 3, sd) * TAU
		var t := Draw.hash01(j, 4, sd)
		if art in ["register"]:
			if j % 2 == 0:
				G.coin(k, c)
			else:
				G.paper(k, Rect2(c, Vector2(7, 5)), a, 1)
			continue
		if art in ["speak_bar", "club_backbar", "beer_backbar", "wine_shelf", "bottle_shelf", "crate_bar"]:
			G.bottle(k, c, 2.2, [Pal.FELT.lightened(0.1), Pal.RUST, Pal.GLASS][j % 3])
			k.ellipse(c + Vector2(4, 3), Vector2(6, 4), Color(Pal.RUST.darkened(0.3), 0.3), a)
			continue
		match trade:
			"bakery":
				if j % 2 == 0:
					G.roll(k, c, 3.2)
				else:
					G.croissant(k, c, 8.0, a)
			"butcher":
				G.chop(k, c, 7.0, a)
			"grocer":
				G.fruit(k, c, 3.4, [Pal.FLOOR_TILE_2.lightened(0.2), Pal.GOLD.lerp(Pal.RUST, 0.4), Pal.GOLD2][j % 3])
			"tailor":
				G.bolt(k, Rect2(c, Vector2(12, 6)), G.CLOTHS[(j + sd) % G.CLOTHS.size()], true)
			"barber":
				G.bottle(k, c, 2.0, Pal.AWNING_COLORS[2].lightened(0.4))
			"cobbler":
				G.shoe(k, c, 9.0, a, Pal.LEATHER)
			"pawnshop":
				if j % 2 == 0:
					G.watch(k, c, 2.6, a)
				else:
					G.necklace(k, c, 3.5, Pal.GOLD2)
			"laundry":
				G.towel(k, Rect2(c, Vector2(10, 7)))
			"restaurant", "cafe":
				G.plate(k, c, 3.5) if j % 2 == 0 else G.cup(k, c, 2.4)
			"candy":
				G.candy(k, Rect2(c, Vector2(8, 6)), sd + j)
			"hardware":
				k.line(c, c + Vector2.from_angle(a) * 4.0, Pal.TRACK.lightened(0.2), 1.0)
				k.line(c + Vector2(3, 1), c + Vector2(3, 1) + Vector2.from_angle(a + 1.0) * 4.0, Pal.TRACK.lightened(0.2), 1.0)
			"drugstore":
				G.bottle(k, c, 2.2, [Pal.AWNING_COLORS[2].lightened(0.4), Pal.FLOOR_TILE_2.lightened(0.3), Pal.GLASS][j % 3])
			"cigar":
				G.cigarbox(k, Rect2(c, Vector2(10, 7)), true, t)
			"fish":
				G.fish(k, c, 14.0, a, G.SILVER)
			"club", "poolhall":
				G.card(k, c, a, j % 2 == 0)
			_:
				G.box(k, Rect2(c, Vector2(7, 5)), G.BRIGHTS[j % G.BRIGHTS.size()])
