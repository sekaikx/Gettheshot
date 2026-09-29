extends RefCounted
## Counters, cases, shelves, tables and every trade's fixtures, drawn in their object frame
## (origin at the centre, the front toward +y, the back against -y). See kit.gd.

const Kit := preload("res://scripts/world2d/rooms/kit.gd")
const G := preload("res://scripts/world2d/rooms/goods.gd")
const M := W.M

static var WOOD := Pal.COUNTER.lightened(0.1)
static var WOOD_D := Pal.COUNTER.darkened(0.12)
static var OAK := Pal.FLOOR_WOOD.lightened(0.14)
static var MAHOG := Pal.LEATHER.lerp(Pal.COUNTER, 0.45)
static var IRON := Pal.MANHOLE.lightened(0.08)
static var STEEL := Pal.TRACK.darkened(0.05)
static var ZINC := Pal.SKYLIGHT.lightened(0.25)
static var ENAMEL := Pal.AWNING_CREAM.lightened(0.12)
static var ICE := Pal.GLASS.lightened(0.42)


## Height (px) of an item for its shadow.
static func height(it: Dictionary) -> float:
	var art := String(it.get("art", it["type"]))
	match art:
		"oven", "cold_room", "elevator", "boiler", "copper_boiler", "humidor": return 18.0
		"bread_rack", "suit_rack", "tri_mirror", "instruments", "tool_wall", "drawer_shelf", "proving_rack", "crate_stack", "barrel_stack", "icebox", "steam_press": return 15.0
		"high_desk", "piano", "phonograph", "safe", "pawn_safe", "file_cabinet", "range", "tally_board", "lobster_tank", "shine_stand", "dummy", "dummy_box", "gun_crates": return 12.0
		"register", "desk_phone": return 4.0
		"cell": return 0.0
		"barber_mirror", "cue_rack": return 3.0
	match String(it["type"]):
		"window": return 3.0
		"shelf", "rack": return 14.0
		"counter", "display", "bar": return 9.0
		"table", "desk", "map_table", "pool_table", "bench": return 7.0
		"crates": return 10.0
		"chair", "stool": return 4.0
	return 8.0


static func round_art(art: String) -> bool:
	return art in ["table_round", "cocktail_table", "barrel", "barrel_table", "bone_barrel", "sugar_barrel", "kerosene", "dummy", "chop_block", "potbelly", "wash_basin"]


static func shadow(k: Kit, it: Dictionary) -> void:
	var ht := height(it)
	if ht <= 0.0 or String(it["type"]) == "window":
		return
	var s := k.obj(it["lr"], it["face"])
	var art := String(it["art"])
	if round_art(art):
		k.shadow_disc(Vector2.ZERO, minf(s.x, s.y) * 0.5, ht)
	elif art == "pool_table":
		k.shadow(Rect2(-s * 0.5, s).grow(-2), ht)
	else:
		k.shadow(Rect2(-s * 0.5, s), ht)
	k.reset()


## Draw an item. `st` = {"broken": bool, "closed": bool, "stock": int, "night": float}.
static func draw(k: Kit, it: Dictionary, st: Dictionary) -> void:
	var s := k.obj(it["lr"], it["face"])
	var R := Rect2(-s * 0.5, s)
	var sd := int(it.get("seed", 0))
	var br := bool(st.get("broken", false))
	var art := String(it["art"])
	if bool(st.get("closed", false)) and bool(it.get("solid", false)) and art not in ["cell", "elevator"] and String(it["type"]) != "window":
		_dust_sheet(k, R, sd)
		k.reset()
		return
	match art:
		# ---- counters
		"wood_counter": _counter(k, R, WOOD, String(it.get("goods", "")), sd)
		"marble_counter": _counter(k, R, Pal.MARBLE, String(it.get("goods", "")), sd, true)
		"butcher_counter": _counter(k, R, ENAMEL, "butcher", sd, true)
		"fish_counter": _counter(k, R, ZINC, "fish", sd, true)
		"pawn_counter": _pawn_counter(k, R, sd)
		"cutting_counter": _cutting_table(k, R, sd)
		"tally_desk": _tally_desk(k, R, sd)
		"high_desk": _high_desk(k, R, sd)
		"espresso_bar": _club_bar(k, R, sd, false)
		"club_bar": _club_bar(k, R, sd, true)
		"pool_bar": _pool_bar(k, R, sd)
		"speak_bar": _speak_bar(k, R, sd, br, int(st.get("stock", 0)))
		"crate_bar": _crate_bar(k, R, sd, br)
		"soda_fountain": _soda_fountain(k, R, sd, br)
		"register": _register(k, R, br, sd)
		# ---- glass cases
		"pastry_case", "cake_case", "meat_case", "poultry_case", "watch_case", "jewel_case", "candy_case", \
		"chocolate_case", "cigar_case", "cosmetic_case", "drug_case", "humidor":
			_case(k, R, art, sd, br)
		"fish_ice", "ice_table": _ice_bed(k, R, art, sd, br)
		"produce_bins": _bins(k, R, sd, br, ["apple", "orange", "lemon", "cabbage", "potato", "onion", "tomato", "pear"])
		"nail_bins": _nail_bins(k, R, sd, br)
		# ---- shelves and racks
		"bread_shelf", "grocery_shelf", "cloth_shelf", "tonic_shelf", "shoe_shelf", "shoe_rack", "pawn_shelf", \
		"bundle_shelf", "wine_shelf", "coffee_shelf", "jar_shelf", "drawer_shelf", "bottle_shelf", "cigar_shelf", \
		"tin_shelf", "club_backbar", "beer_backbar", "towel_shelf", "leather_shelf", "crate_shelf", "stock_shelf", \
		"box_shelf", "sack_shelf", "apothecary", "beer_cases", "pipe_rack":
			_shelf(k, R, art, sd, br)
		"meat_hooks": _meat_hooks(k, R, sd, br)
		"instruments": _instruments(k, R, sd, br)
		"tool_wall": _tool_wall(k, R, sd, br)
		"bread_rack": _bread_rack(k, R, sd, br)
		"suit_rack": _suit_rack(k, R, sd, br)
		"news_rack": _news_rack(k, R, sd, br)
		"cue_rack": _cue_rack(k, R, sd, br)
		"proving_rack": _proving_rack(k, R, sd)
		"tally_board": _tally_board(k, R, sd)
		# ---- tables and seats
		"table_checked": _table_checked(k, R, sd)
		"table_round": _table_round(k, R, sd)
		"card_table": _card_table(k, R, sd, false)
		"club_table": _card_table(k, R, sd, true)
		"cocktail_table": _cocktail_table(k, R, sd)
		"barrel_table": _barrel(k, R, sd, "table")
		"bench", "wait_bench": _bench(k, R, art == "wait_bench")
		"cot": _cot(k, R, sd)
		"barber_chair": _barber_chair(k, R)
		"shine_stand": _shine_stand(k, R)
		# ---- the office
		"boss_desk": _desk(k, R, sd, "boss")
		"captain_desk": _desk(k, R, sd, "captain")
		"office_desk": _desk(k, R, sd, "office")
		"safe", "pawn_safe": _safe(k, R)
		"map_table": _map_table(k, R, sd)
		"phone_stand": _phone_stand(k, R)
		"desk_phone": _phone(k, Vector2.ZERO, 1.0)
		"file_cabinet": _file_cabinet(k, R)
		"sideboard": _sideboard(k, R, sd)
		# ---- the pool hall, the speakeasy
		"pool_table": _pool_table(k, R, sd)
		"piano": _piano(k, R)
		"phonograph": _phonograph(k, R)
		# ---- the precinct, the warehouse
		"cell": _cell(k, R, sd)
		"elevator": _elevator(k, R, sd)
		"crate_stack", "crate_row", "crates", "produce_crates", "gun_crates", "shoe_boxes", "fish_boxes", "cloth_bales", "dummy_box", "trunk":
			_crates(k, R, art, sd)
		"barrel_stack": _barrel_stack(k, R, sd)
		"barrel", "bone_barrel", "sugar_barrel", "kerosene": _barrel(k, R, sd, art)
		"barrels", "hardware_barrels": _barrel_row(k, R, sd, art)
		"flour_sacks", "potato_sacks", "coffee_sacks": _sack_pile(k, R, sd, art)
		# ---- the trades' own fixtures
		"oven": _oven(k, R, sd, float(st.get("night", 0.0)))
		"cold_room": _cold_room(k, R, sd)
		"icebox", "icebox_small": _icebox(k, R)
		"ice_chests": _ice_chests(k, R, sd)
		"chop_block": _chop_block(k, R, sd)
		"saw_bench", "gutting_table", "lab_bench", "stitcher", "prep_table", "marble_slab", "slip_table", \
		"sewing_bench", "cobbler_bench", "folding_table", "gun_table", "numbers_desk":
			_bench_top(k, R, art, sd)
		"washtubs": _washtubs(k, R, sd)
		"mangle": _mangle(k, R)
		"copper_boiler", "boiler": _boiler(k, R, art == "copper_boiler")
		"steam_press": _steam_press(k, R)
		"range": _range(k, R, sd)
		"kitchen_sink", "wash_basin": _sink(k, R, art == "kitchen_sink", sd)
		"roaster", "candy_kettle": _kettle(k, R, art == "roaster")
		"potbelly": _potbelly(k, R)
		"laundry_cart", "laundry_basket": _laundry_cart(k, R, sd, art == "laundry_basket")
		"clam_baskets": _clam_baskets(k, R, sd)
		"lobster_tank": _tank(k, R, sd)
		"barber_counter": _barber_counter(k, R, sd)
		"barber_mirror": _mirror(k, R, br, sd, false)
		"tri_mirror": _mirror(k, R, br, sd, true)
		"dummy": _dummy(k, R, sd)
		"phone_stand_small": _phone_stand(k, R)
		_:
			if String(it["type"]) == "window":
				_window_ledge(k, R, art, sd, br, it)
			else:
				k.top(R, WOOD, 2.0)
	k.reset()


# ------------------------------------------------------------------ helpers

static func _dust_sheet(k: Kit, R: Rect2, sd: int) -> void:
	var c := Pal.AWNING_CREAM.darkened(0.12)
	var g := R.grow(2.0)
	k.rrect(g, 4.0, c)
	var segs := PackedVector2Array()
	for j in 4:
		var x := g.position.x + g.size.x * (0.15 + 0.23 * j) + (k.h(j, 1, sd) - 0.5) * 6.0
		segs.append_array([Vector2(x, g.position.y + 2), Vector2(x + (k.h(j, 2, sd) - 0.5) * 8.0, g.end.y - 2)])
	k.lines(segs, c.darkened(0.14), 1.5)
	k.ci.draw_rect(g, Color(1, 1, 1, 0.08), false, 1.0)


## The front edge of a counter: a darker lip on the customer side, a polished line.
static func _lip(k: Kit, R: Rect2, c: Color) -> void:
	k.rect(Rect2(R.position.x, R.end.y - 3.0, R.size.x, 3.0), c.darkened(0.35))
	k.line(Vector2(R.position.x + 1, R.end.y - 3.5), Vector2(R.end.x - 1, R.end.y - 3.5), c.lightened(0.25), 1.0)


static func _marble(k: Kit, R: Rect2, sd: int) -> void:
	k.rect(R, Pal.MARBLE)
	for j in 4:
		var y := R.position.y + R.size.y * (0.2 + k.h(j, 1, sd) * 0.6)
		var pts := PackedVector2Array()
		var x := R.position.x
		while x < R.end.x:
			pts.append(Vector2(x, y + sin(x * 0.07 + j) * 2.0 + (k.h(int(x), j, sd) - 0.5) * 1.5))
			x += 6.0
		pts.append(Vector2(R.end.x, y))
		k.pline(pts, Color(Pal.QUAY_STONE, 0.28), 1.0)


# ------------------------------------------------------------------ counters

static func _counter(k: Kit, R: Rect2, top: Color, goods: String, sd: int, stone: bool = false) -> void:
	if stone:
		k.rect(R, top.darkened(0.2))
		var t := R.grow(-1.5)
		if top == Pal.MARBLE:
			_marble(k, t, sd)
		else:
			k.rect(t, top)
		k.edges(t, top, 1.5)
	else:
		k.top(R, top, 2.0)
		k.grain(R.grow(-2), top.darkened(0.3), true, 0, sd)
	_lip(k, R, top if not stone else WOOD)
	var w := R.size.x
	var y := R.position.y + R.size.y * 0.42
	var x0 := R.position.x
	# the goods of the trade on top, leaving the till area (right of centre) clear
	match goods:
		"bakery":
			for j in 3:
				G.box(k, Rect2(x0 + 8 + j * 12, y - 5, 9, 11), Pal.AWNING_CREAM.darkened(0.05), false)
			G.boule(k, Vector2(R.end.x - 18, y), 7.0, 0.4)
			G.roll(k, Vector2(R.end.x - 30, y + 3), 3.5)
			_bell(k, Vector2(R.end.x - 8, y - 4))
		"butcher":
			_scale(k, Vector2(x0 + 14, y), 1.0)
			k.rect(Rect2(R.end.x - 30, R.position.y + 3, 22, R.size.y - 10), Pal.PAPER.darkened(0.08))
			k.disc(Vector2(R.end.x - 19, R.position.y + 5), 3.0, Pal.PAPER.darkened(0.2))
			_cleaver(k, Vector2(R.end.x - 44, y + 2), 0.3)
		"fish":
			_scale(k, Vector2(x0 + 14, y), 1.0)
			G.newspaper(k, Rect2(R.end.x - 32, y - 7, 20, 14), 0.2, 0.2)
			G.fish(k, Vector2(R.end.x - 22, y), 18.0, 0.1, G.SILVER)
		"grocer":
			_scale(k, Vector2(x0 + 14, y), 1.0)
			k.disc(Vector2(R.end.x - 16, y), 8.0, Pal.GOLD.darkened(0.05))
			k.disc(Vector2(R.end.x - 16, y), 6.5, Pal.GOLD2.darkened(0.08))
			k.poly(PackedVector2Array([Vector2(R.end.x - 16, y), Vector2(R.end.x - 8, y - 3), Vector2(R.end.x - 9, y + 4)]), Pal.GOLD2.lightened(0.15))
			G.jar(k, Vector2(R.end.x - 32, y), 5.0, Pal.AWNING_COLORS[1].lightened(0.3))
		"hardware":
			_scale(k, Vector2(x0 + 14, y), 1.0)
			G.box(k, Rect2(R.end.x - 26, y - 5, 16, 10), Pal.RUST.lightened(0.1))
			k.ring(Vector2(R.end.x - 40, y), 6.0, Pal.ROPE, 3.0)
		"cobbler":
			for j in 3:
				G.pair(k, Vector2(x0 + 12 + j * 16, y), 11.0, PI * 0.5, [Pal.LEATHER, Pal.SIGN_BLACK.lightened(0.1), Pal.RUST][j])
				k.rect(Rect2(x0 + 8 + j * 16, y + 7, 6, 4), Pal.AWNING_CREAM)
			_bell(k, Vector2(R.end.x - 8, y - 4))
		"laundry":
			for j in 3:
				G.bundle(k, Rect2(x0 + 6 + j * 16, y - 6, 14, 11), k.h(j, 1, sd))
			_bell(k, Vector2(R.end.x - 8, y - 4))
		"restaurant":
			G.cake(k, Vector2(x0 + 16, y), 8.0, Pal.AWNING_CREAM, true)
			k.ring(Vector2(x0 + 16, y), 10.0, Color(Pal.GLASS, 0.7), 1.5)
			_urn(k, Vector2(R.end.x - 16, y))
		"cigar":
			_lighter(k, Vector2(x0 + 12, y))
			G.cigarbox(k, Rect2(x0 + 22, y - 6, 18, 12), true, 0.4)
			for j in 4:
				k.rect(Rect2(R.end.x - 28 + j * 5, y - 4, 4, 6), BRIGHTS_OF(j))
		"cafe":
			_espresso_machine(k, Vector2(x0 + 22, R.position.y + R.size.y * 0.45), 0.9)
			for j in 3:
				G.cup(k, Vector2(R.end.x - 12 - j * 11, y + 2), 2.5)
		"drugstore":
			for j in 3:
				G.jar(k, Vector2(x0 + 10 + j * 13, y), 5.0, [Pal.AWNING_COLORS[2].lightened(0.3), Pal.FLOOR_TILE_2.lightened(0.2), Pal.GOLD][j])
			_scale(k, Vector2(R.end.x - 16, y), 0.8)
		"candy":
			for j in 4:
				G.jar(k, Vector2(x0 + 9 + j * 12, y), 5.0, G.BRIGHTS[(j * 3 + sd) % G.BRIGHTS.size()])
		"tailor", "pawnshop":
			pass
		_:
			G.paper(k, Rect2(x0 + 8, y - 5, 12, 9), 0.1)
			_bell(k, Vector2(R.end.x - 8, y - 4))
	var _unused := w


static func BRIGHTS_OF(j: int) -> Color:
	return G.BRIGHTS[j % G.BRIGHTS.size()]


static func _bell(k: Kit, c: Vector2) -> void:
	k.ball(c, 2.6, Pal.BRASS, 2.0, 0.4)


static func _scale(k: Kit, c: Vector2, sz: float) -> void:
	var col := ENAMEL
	k.rrect(Rect2(c - Vector2(9, 6) * sz + k.sh * 2.0, Vector2(18, 12) * sz), 3.0, Color(Kit.SH_COL, 0.25))
	k.rrect(Rect2(c - Vector2(9, 6) * sz, Vector2(18, 12) * sz), 3.0, col.darkened(0.08))
	k.disc(c + Vector2(-3, 0) * sz, 4.5 * sz, col)
	k.disc(c + Vector2(-3, 0) * sz, 3.6 * sz, Pal.AWNING_CREAM.lightened(0.2))
	k.line(c + Vector2(-3, 0) * sz, c + Vector2(-3, 0) * sz + Vector2(2.2, -2.0) * sz, Pal.FLOOR_TILE_2, 1.0)
	k.disc(c + Vector2(5, 0) * sz, 4.0 * sz, Pal.BRASS)
	k.disc(c + Vector2(5, 0) * sz, 3.0 * sz, Pal.BRASS.lightened(0.15))


static func _cleaver(k: Kit, c: Vector2, a: float) -> void:
	var d := Vector2.from_angle(a)
	var n := Vector2(-d.y, d.x)
	k.poly(PackedVector2Array([c - n * 4.0, c + d * 10.0 - n * 4.0, c + d * 10.0 + n * 2.0, c + n * 2.0]), STEEL.lightened(0.3))
	k.line(c - d * 7.0 - n * 1.0, c - n * 1.0, Pal.COUNTER.darkened(0.1), 2.5)


static func _urn(k: Kit, c: Vector2) -> void:
	k.ball(c, 7.5, Pal.BRASS.darkened(0.05), 5.0, 0.35)
	k.disc(c, 3.0, Pal.BRASS.lightened(0.2))
	k.line(c + Vector2(7, 0), c + Vector2(11, 0), Pal.BRASS.darkened(0.2), 2.0)


static func _lighter(k: Kit, c: Vector2) -> void:
	k.ball(c, 3.5, Pal.BRASS, 3.0, 0.3)
	k.disc(c, 1.2, Pal.NEON_RED.darkened(0.2))


static func _espresso_machine(k: Kit, c: Vector2, sz: float) -> void:
	# the brass Pavoni-style boiler with the eagle, group heads to the front
	k.shadow_disc(c, 11.0 * sz, 10.0)
	k.rrect(Rect2(c + Vector2(-14, 3) * sz, Vector2(28, 8) * sz), 2.0, STEEL.lightened(0.15))
	k.disc(c, 10.5 * sz, Pal.BRASS.darkened(0.2))
	k.disc(c + k.lit * 1.2, 9.0 * sz, Pal.BRASS)
	k.disc(c + k.lit * 3.5 * sz, 3.5 * sz, Pal.BRASS.lightened(0.35))
	k.disc(c, 3.2 * sz, Pal.BRASS.darkened(0.25))
	for sgn: float in [-1.0, 1.0]:
		k.disc(c + Vector2(sgn * 8.0, 8.0) * sz, 2.6 * sz, IRON)
		k.line(c + Vector2(sgn * 8.0, 8.0) * sz, c + Vector2(sgn * 12.0, 12.5) * sz, Pal.SIGN_BLACK, 2.0)
	# the eagle on top
	k.poly(PackedVector2Array([c + Vector2(-4, -1) * sz, c + Vector2(0, -3.5) * sz, c + Vector2(4, -1) * sz, c + Vector2(0, 1.5) * sz]), Pal.GOLD2)


static func _pawn_counter(k: Kit, R: Rect2, sd: int) -> void:
	_counter(k, R, WOOD_D, "pawnshop", sd)
	# the brass grille along the front
	var y := R.end.y - 5.0
	k.line(Vector2(R.position.x + 4, y), Vector2(R.end.x - 4, y), Pal.BRASS.darkened(0.1), 1.5)
	var x := R.position.x + 6.0
	while x < R.end.x - 4.0:
		k.disc(Vector2(x, y), 1.3, Pal.BRASS)
		x += 5.0
	# the ledger and the loupe
	var lr := Rect2(R.position.x + 10, R.position.y + 4, 24, 14)
	k.rect(Rect2(lr.position + k.sh * 1.5, lr.size), Color(Kit.SH_COL, 0.2))
	k.rect(lr, Pal.PAPER)
	k.line(Vector2(lr.get_center().x, lr.position.y), Vector2(lr.get_center().x, lr.end.y), Pal.PAPER.darkened(0.25), 1.0)
	for j in 4:
		k.line(Vector2(lr.position.x + 2, lr.position.y + 3 + j * 3), Vector2(lr.get_center().x - 2, lr.position.y + 3 + j * 3), Color(Pal.PAPER_INK, 0.4), 1.0)
	k.ring(Vector2(R.position.x + 42, R.position.y + 10), 3.0, IRON, 1.5)
	G.pocket_watch(k, Vector2(R.position.x + 54, R.position.y + 12), 4.0)


static func _cutting_table(k: Kit, R: Rect2, sd: int) -> void:
	k.top(R, OAK, 2.0)
	k.grain(R.grow(-2), OAK.darkened(0.3), true, 0, sd)
	_lip(k, R, OAK)
	# a length of cloth laid out with chalk lines, shears and the yardstick
	var cloth := Rect2(R.position.x + R.size.x * 0.08, R.position.y + 4, R.size.x * 0.5, R.size.y - 12)
	var col: Color = G.CLOTHS[sd % 3 + 3]
	k.rect(cloth, col)
	k.rect(Rect2(cloth.position + Vector2(0, cloth.size.y - 3), Vector2(cloth.size.x, 3)), col.darkened(0.2))
	k.pline(PackedVector2Array([cloth.position + Vector2(8, 5), cloth.position + Vector2(cloth.size.x * 0.4, 3), cloth.position + Vector2(cloth.size.x * 0.55, cloth.size.y * 0.6), cloth.position + Vector2(10, cloth.size.y - 5)]), Color(1, 1, 1, 0.7), 1.0)
	k.line(Vector2(R.position.x + 6, R.end.y - 7), Vector2(R.position.x + R.size.x * 0.7, R.end.y - 7), Pal.SIGN_GOLD, 2.5)
	var sc := cloth.end + Vector2(8, -8)
	k.line(sc, sc + Vector2(12, -6), STEEL.lightened(0.3), 2.0)
	k.line(sc, sc + Vector2(12, -2), STEEL.lightened(0.2), 2.0)
	k.ring(sc - Vector2(2, -1), 2.0, IRON, 1.2)
	k.ring(sc - Vector2(2, 3), 2.0, IRON, 1.2)
	k.disc(Vector2(R.end.x - 12, R.position.y + 8), 4.0, Pal.FLOOR_TILE_2)


static func _tally_desk(k: Kit, R: Rect2, sd: int) -> void:
	k.top(R, OAK.darkened(0.1), 2.0)
	_lip(k, R, OAK)
	var lr := Rect2(R.position.x + 8, R.position.y + 4, 26, R.size.y - 11)
	k.rect(lr, Pal.PAPER)
	k.line(Vector2(lr.get_center().x, lr.position.y), Vector2(lr.get_center().x, lr.end.y), Pal.PAPER.darkened(0.3), 1.0)
	for j in 5:
		k.line(Vector2(lr.position.x + 2, lr.position.y + 3 + j * 3), Vector2(lr.end.x - 2, lr.position.y + 3 + j * 3), Color(Pal.PAPER_INK, 0.35), 1.0)
	G.paper(k, Rect2(R.end.x - 30, R.position.y + 5, 14, 18), -0.2, 4)
	k.line(Vector2(R.end.x - 14, R.position.y + 6), Vector2(R.end.x - 8, R.position.y + 18), Pal.SIGN_GOLD, 1.5)
	var _unused := sd


static func _high_desk(k: Kit, R: Rect2, sd: int) -> void:
	# a raised oak desk, a brass rail at the front, the blotter and the big book
	var wood := MAHOG.lightened(0.05)
	k.top(R, wood, 3.0)
	k.grain(R.grow(-3), wood.darkened(0.35), true, 0, sd)
	k.rect(Rect2(R.position.x, R.end.y - 5, R.size.x, 5), wood.darkened(0.3))
	k.line(Vector2(R.position.x + 3, R.end.y - 2.5), Vector2(R.end.x - 3, R.end.y - 2.5), Pal.BRASS, 2.0)
	var c := Vector2(0, R.position.y + R.size.y * 0.45)
	var book := Rect2(c - Vector2(16, 8), Vector2(32, 16))
	k.rect(Rect2(book.position + k.sh * 2, book.size), Color(Kit.SH_COL, 0.25))
	k.rect(book, Pal.PAPER)
	k.rect(Rect2(book.position.x + 15.5, book.position.y, 1, book.size.y), Pal.PAPER.darkened(0.3))
	for j in 4:
		k.line(Vector2(book.position.x + 2, book.position.y + 3 + j * 3.2), Vector2(book.position.x + 14, book.position.y + 3 + j * 3.2), Color(Pal.PAPER_INK, 0.45), 1.0)
		k.line(Vector2(book.position.x + 18, book.position.y + 3 + j * 3.2), Vector2(book.end.x - 2, book.position.y + 3 + j * 3.2), Color(Pal.PAPER_INK, 0.45), 1.0)
	_phone(k, Vector2(R.position.x + 20, c.y), 1.0)
	k.ball(Vector2(R.end.x - 22, c.y - 2), 4.0, Pal.FELT.lightened(0.1), 6.0, 0.3)
	k.disc(Vector2(R.end.x - 22, c.y - 2), 1.5, Pal.GOLD2)
	k.rect(Rect2(R.end.x - 44, c.y - 4, 10, 8), Pal.SIGN_BLACK)
	k.disc(Vector2(R.end.x - 39, c.y), 2.0, Pal.PAPER_INK)
	# the nameplate
	k.rect(Rect2(-12, R.end.y - 11, 24, 5), Pal.BRASS.darkened(0.1))
	for j in 4:
		G.paper(k, Rect2(R.position.x + 36 + j * 2, R.position.y + 5 + j, 12, 15), 0.05 * j, 3)


static func _club_bar(k: Kit, R: Rect2, sd: int, booze: bool) -> void:
	var t := R.grow(-1.5)
	k.rect(R, WOOD_D)
	_marble(k, t, sd)
	k.edges(t, Pal.MARBLE, 1.5)
	_lip(k, R, WOOD)
	_espresso_machine(k, Vector2(R.end.x - 22, R.position.y + R.size.y * 0.45), 1.0)
	var y := R.position.y + R.size.y * 0.5
	for j in 3:
		G.cup(k, Vector2(R.end.x - 44 - j * 10, y + 3), 2.4)
	k.disc(Vector2(R.position.x + 16, y), 4.5, Pal.AWNING_CREAM.lightened(0.1))
	k.disc(Vector2(R.position.x + 16, y), 3.0, Pal.AWNING_CREAM.darkened(0.1))
	G.cigarbox(k, Rect2(R.position.x + 26, y - 6, 18, 12), true, 0.6)
	if booze:
		for j in 5:
			G.bottle(k, Vector2(R.position.x + 54 + j * 9, y - 2 + (j % 2) * 4), 3.2, G.BOTTLES[(j + sd) % G.BOTTLES.size()])
		for j in 3:
			G.glass_cup(k, Vector2(R.position.x + 100 + j * 8, y + 4), 2.4, Color(Pal.GOLD, 0.7))


static func _pool_bar(k: Kit, R: Rect2, sd: int) -> void:
	k.top(R, WOOD, 2.0)
	k.grain(R.grow(-2), WOOD.darkened(0.3), true, 0, sd)
	_lip(k, R, WOOD)
	var y := R.position.y + R.size.y * 0.45
	# beer taps, glasses, the jar of pickled eggs, a bowl of peanuts
	for j in 3:
		var tp := Vector2(R.position.x + 12 + j * 7, R.position.y + 6)
		k.disc(tp, 2.5, Pal.BRASS)
		k.line(tp, tp + Vector2(0, 5), Pal.SIGN_BLACK, 2.0)
	for j in 4:
		G.glass_cup(k, Vector2(R.position.x + 42 + j * 8, y + 3), 2.6, Color(Pal.GOLD, 0.75))
	G.jar(k, Vector2(R.end.x - 18, y), 6.0, Pal.AWNING_CREAM)
	k.disc(Vector2(R.end.x - 34, y + 2), 5.0, Pal.COUNTER.darkened(0.2))
	G.pile(k, Rect2(R.end.x - 38, y - 2, 8, 8), "potato", sd)


static func _speak_bar(k: Kit, R: Rect2, sd: int, br: bool, stock: int) -> void:
	# the slot holds the back-bar against the wall (-y), the bartender's aisle and the counter (+y)
	var back := Rect2(R.position.x, R.position.y, R.size.x, R.size.y * 0.27)
	var ctr := Rect2(R.position.x, R.end.y - R.size.y * 0.4, R.size.x, R.size.y * 0.4)
	var aisle := Rect2(R.position.x, back.end.y, R.size.x, ctr.position.y - back.end.y)
	k.rect(aisle, Pal.FLOOR_WOOD.darkened(0.3))
	k.shadow(back, 12.0, 0.3)
	k.top(back, MAHOG, 2.0)
	# rows of bottles on the back-bar, a mirror strip behind them
	k.rect(Rect2(back.position.x + 2, back.position.y + 1, back.size.x - 4, 3), Color(Pal.GLASS.lightened(0.3), 0.7))
	var n := int(back.size.x / 7.5)
	for j in n:
		var c := Vector2(back.position.x + 5 + j * 7.5, back.position.y + back.size.y * 0.58 + (j % 2) * 2.5)
		if br and k.h(j, 3, sd) > 0.45:
			continue
		G.bottle(k, c, 3.0, G.BOTTLES[(j * 7 + sd) % G.BOTTLES.size()])
	# the counter with its brass foot rail
	k.shadow(ctr, 9.0, 0.28)
	k.top(ctr, WOOD, 2.0)
	k.grain(ctr.grow(-2), WOOD.darkened(0.3), true, 0, sd)
	k.line(Vector2(ctr.position.x + 2, ctr.end.y + 3), Vector2(ctr.end.x - 2, ctr.end.y + 3), Pal.BRASS, 2.0)
	var y := ctr.get_center().y
	var m := int(ctr.size.x / 16.0)
	for j in m:
		var x := ctr.position.x + 8 + j * 16.0
		if k.h(j, 5, sd) > 0.4:
			G.glass_cup(k, Vector2(x, y), 2.6, Color(Pal.GOLD, 0.7) if j % 2 == 0 else Color(Pal.FLOOR_TILE_2, 0.6))
	G.bottle(k, Vector2(ctr.position.x + 20, y - 2), 3.4, G.BOTTLES[sd % G.BOTTLES.size()])
	k.disc(Vector2(ctr.end.x - 14, y), 4.0, STEEL.lightened(0.3))
	# crates of booze from the cellar, stacked at the back end
	var crates := clampi(int(ceil(stock / 6.0)), 0, 4)
	for j in crates:
		var cr := Rect2(aisle.position.x + 2 + j * 12, aisle.position.y + 1, 11, aisle.size.y - 2)
		_crate(k, cr, sd + j, true)
	if br:
		for j in 6:
			var p := Vector2(ctr.position.x + k.h(j, 7, sd) * ctr.size.x, ctr.position.y + k.h(j, 8, sd) * ctr.size.y)
			k.ellipse(p, Vector2(6, 3), Color(Pal.GOLD.darkened(0.3), 0.45), k.h(j, 9, sd) * PI)
		k.shards(Rect2(aisle.position, aisle.size), 14, sd, Color(Pal.FELT.lightened(0.4), 0.9))


static func _crate_bar(k: Kit, R: Rect2, sd: int, br: bool) -> void:
	var n := maxi(2, int(R.size.x / 30.0))
	for j in n:
		var cr := Rect2(R.position.x + j * R.size.x / n + 1, R.position.y + 2, R.size.x / n - 2, R.size.y - 4)
		_crate(k, cr, sd + j, false)
	var top := Rect2(R.position.x, R.end.y - 14, R.size.x, 12)
	k.shadow(top, 4.0)
	k.top(top, Pal.PLANKS.lightened(0.1), 1.5)
	var m := int(R.size.x / 14.0)
	for j in m:
		if br and j % 2 == 0:
			continue
		G.bottle(k, Vector2(R.position.x + 7 + j * 14, top.get_center().y), 3.0, G.BOTTLES[(j + sd) % G.BOTTLES.size()])


static func _soda_fountain(k: Kit, R: Rect2, sd: int, br: bool) -> void:
	# back-bar with syrup pumps against the wall, marble counter to the room
	var back := Rect2(R.position.x, R.position.y, R.size.x, R.size.y * 0.3)
	var ctr := Rect2(R.position.x, R.end.y - R.size.y * 0.5, R.size.x, R.size.y * 0.5)
	k.rect(Rect2(R.position.x, back.end.y, R.size.x, ctr.position.y - back.end.y), Pal.FLOOR_WOOD.darkened(0.25))
	k.shadow(back, 12.0)
	k.top(back, MAHOG, 2.0)
	var n := int(back.size.x / 9.0)
	for j in n:
		var c := Vector2(back.position.x + 5 + j * 9.0, back.get_center().y)
		if j % 3 == 1:
			G.glass_cup(k, c, 2.8)
		else:
			G.jar(k, c, 3.3, G.BRIGHTS[(j + sd) % G.BRIGHTS.size()])
	k.shadow(ctr, 9.0)
	k.rect(ctr, WOOD_D)
	_marble(k, ctr.grow(-1.5), sd)
	k.edges(ctr.grow(-1.5), Pal.MARBLE, 1.5)
	# the pumps and the ice-cream lids along the counter
	var m := int(ctr.size.x / 13.0)
	for j in m:
		var x := ctr.position.x + 8 + j * 13.0
		if j % 2 == 0:
			k.disc(Vector2(x, ctr.position.y + 4), 2.2, STEEL.lightened(0.35))
			k.line(Vector2(x, ctr.position.y + 4), Vector2(x, ctr.position.y + 9), STEEL, 1.5)
		else:
			k.disc(Vector2(x, ctr.get_center().y + 1), 4.0, STEEL.lightened(0.2))
			k.disc(Vector2(x, ctr.get_center().y + 1), 2.5, STEEL.lightened(0.45))
	if not br:
		G.glass_cup(k, Vector2(ctr.end.x - 10, ctr.end.y - 5), 3.0, Color(Pal.FLOOR_TILE_2.lightened(0.4), 0.9))
		k.disc(Vector2(ctr.end.x - 10, ctr.end.y - 7), 1.2, Pal.NEON_RED)
	else:
		k.shards(ctr, 10, sd)
		k.ellipse(ctr.get_center() + Vector2(10, 2), Vector2(9, 4), Color(Pal.FLOOR_TILE_2.lightened(0.4), 0.5))
	k.line(Vector2(ctr.position.x + 2, ctr.end.y + 3), Vector2(ctr.end.x - 2, ctr.end.y + 3), STEEL.lightened(0.4), 1.5)


static func _register(k: Kit, R: Rect2, br: bool, sd: int) -> void:
	var r := Rect2(-R.size * 0.5, R.size)
	if br:
		k.frame(k.org, k.ang + 0.22)
	var brass := Pal.BRASS
	k.rrect(Rect2(r.position + k.sh * 3.0, r.size), 3.0, Color(Kit.SH_COL, 0.3))
	k.rrect(r, 3.0, brass.darkened(0.25))
	k.rrect(r.grow(-1.5), 2.5, brass)
	# the ornate top, the price flags at the back, the keys at the front
	k.rect(Rect2(r.position.x + 3, r.position.y + 2, r.size.x - 6, r.size.y * 0.25), brass.darkened(0.15))
	for j in 4:
		k.rect(Rect2(r.position.x + 4 + j * (r.size.x - 8) / 4.0, r.position.y + 2.5, (r.size.x - 8) / 4.0 - 1.0, r.size.y * 0.2), Pal.AWNING_CREAM)
	for row in 3:
		for j in 5:
			k.disc(Vector2(r.position.x + 4 + j * (r.size.x - 8) / 4.0, r.position.y + r.size.y * (0.45 + row * 0.13)), 1.3, Pal.AWNING_CREAM.lightened(0.2))
	k.disc(r.position + Vector2(r.size.x - 3, r.size.y * 0.5), 2.0, brass.lightened(0.3))
	k.line(r.position + Vector2(3, 3), r.position + Vector2(r.size.x * 0.5, 3), brass.lightened(0.4), 1.0)
	if br:
		# the drawer hangs open, emptied
		var dr := Rect2(r.position.x + 2, r.end.y - 2, r.size.x - 4, 8)
		k.rect(dr, WOOD_D)
		k.rect(dr.grow(-1.5), WOOD.darkened(0.3))
		for j in 3:
			k.rect(Rect2(dr.position.x + 2 + j * (dr.size.x - 4) / 3.0, dr.position.y + 1.5, 1.0, dr.size.y - 3), WOOD_D)
		k.reset()
	var _unused := sd


# ------------------------------------------------------------------ glass cases

static func _case(k: Kit, R: Rect2, art: String, sd: int, br: bool) -> void:
	var frame := WOOD_D if art not in ["watch_case", "jewel_case"] else MAHOG
	k.rect(R, frame)
	var inner := R.grow(-3.0)
	var bed: Color
	match art:
		"meat_case", "poultry_case": bed = ENAMEL
		"watch_case", "jewel_case": bed = Pal.FLOOR_TILE_2.darkened(0.35)
		"cigar_case", "humidor": bed = MAHOG.darkened(0.1)
		"cosmetic_case", "drug_case": bed = Pal.AWNING_CREAM.darkened(0.05)
		_: bed = Pal.AWNING_CREAM.lightened(0.05)
	k.rect(inner, bed)
	var sp := br
	match art:
		"cake_case":
			var n := maxi(1, int(inner.size.y / 20.0))
			for j in n:
				var c := Vector2(0, inner.position.y + (j + 0.5) * inner.size.y / n)
				if sp and j % 2 == 1:
					continue
				G.cake(k, c, minf(inner.size.x, inner.size.y / n) * 0.36, [Pal.AWNING_CREAM, Pal.FLOOR_TILE_2.lightened(0.45), Pal.COUNTER.lightened(0.15)][j % 3], j == 0)
		_:
			var step: float = {"pastry_case": 11.0, "meat_case": 13.0, "poultry_case": 14.0, "watch_case": 10.0, "jewel_case": 10.0,
				"candy_case": 11.0, "chocolate_case": 11.0, "cigar_case": 13.0, "humidor": 13.0, "cosmetic_case": 8.0, "drug_case": 8.0}.get(art, 11.0)
			var nx := maxi(1, int(inner.size.x / step))
			var ny := maxi(1, int(inner.size.y / step))
			for j in ny:
				for i in nx:
					if sp and k.h(i, j, sd + 77) > 0.55:
						continue
					var c2 := inner.position + Vector2((i + 0.5) * inner.size.x / nx, (j + 0.5) * inner.size.y / ny)
					_case_cell(k, art, c2, i, j, sd)
	# the glass top
	if br:
		k.rect(inner, Color(Pal.SIGN_BLACK, 0.12))
		k.cracks(inner.get_center() + Vector2(0, -inner.size.y * 0.15), minf(inner.size.x, inner.size.y) * 0.9, sd)
		k.shards(inner, 12, sd)
	else:
		k.glass(inner, Pal.GLASS.lightened(0.2), 0.32)
	k.ci.draw_rect(R, frame.darkened(0.35), false, 1.0)
	k.edges(R, frame, 1.5)


static func _case_cell(k: Kit, art: String, c: Vector2, i: int, j: int, sd: int) -> void:
	match art:
		"pastry_case":
			match (i + j * 2) % 4:
				0: G.croissant(k, c, 9.0, 0.3)
				1: G.cannolo(k, c, 0.2 + j)
				2: G.cookie(k, c, 3.5, k.h(i, j, sd))
				_: G.cookie(k, c, 4.2, 0.9)
		"meat_case":
			k.rect(Rect2(c - Vector2(6, 5), Vector2(12, 10)), ENAMEL.darkened(0.08))
			match (i + j) % 4:
				0: G.steak(k, c, 10.0, 0.2, k.h(i, j, sd))
				1: G.chop(k, c, 8.0, -0.4)
				2: G.sausage_coil(k, c, 4.5)
				_: G.links(k, c - Vector2(5, 0), c + Vector2(5, 0), 3)
		"poultry_case":
			G.chicken(k, c, 12.0, PI * 0.5 if i % 2 == 0 else -PI * 0.5)
		"watch_case":
			if (i + j) % 3 == 0:
				G.pocket_watch(k, c, 3.2)
			else:
				G.watch(k, c, 2.8, PI * 0.5)
		"jewel_case":
			if (i + j) % 2 == 0:
				G.gem_ring(k, c, G.BRIGHTS[(i + j * 3) % G.BRIGHTS.size()])
			else:
				G.necklace(k, c, 4.0, Pal.GOLD2)
		"candy_case":
			var tr := Rect2(c - Vector2(5, 4), Vector2(10, 8))
			k.rect(tr, Pal.AWNING_CREAM.lightened(0.1))
			G.candy(k, tr.grow(-1.0), sd + i * 7 + j)
		"chocolate_case":
			var tr2 := Rect2(c - Vector2(5, 4), Vector2(10, 8))
			k.rect(tr2, Pal.COUNTER.darkened(0.1))
			_bonbons(k, tr2, i + j)
		"cigar_case", "humidor":
			G.cigarbox(k, Rect2(c - Vector2(6, 4.5), Vector2(12, 9)), (i + j) % 2 == 0, k.h(i, j, sd))
		"cosmetic_case", "drug_case":
			if (i + j) % 3 == 0:
				G.box(k, Rect2(c - Vector2(3.5, 2.5), Vector2(7, 5)), G.BRIGHTS[(i * 2 + j) % G.BRIGHTS.size()])
			else:
				G.bottle(k, c, 2.4, [Pal.AWNING_COLORS[2].lightened(0.4), Pal.FLOOR_TILE_2.lightened(0.3), Pal.GLASS, Pal.RUST.lightened(0.2)][(i + j) % 4])


static func _bonbons(k: Kit, r: Rect2, i: int) -> void:
	for j in 4:
		k.disc(r.position + Vector2(2.5 + (j % 2) * 5.0, 2.2 + (j / 2) * 3.8), 1.8, Pal.COUNTER.darkened(0.3).lightened(0.1 * ((i + j) % 3)))


## Fill a case in a grid, `step` px apart. When spilled (broken), skip some.
static func _rows(k: Kit, r: Rect2, sd: int, f: Callable, step: float, spilled: bool) -> void:
	var nx := maxi(1, int(r.size.x / step))
	var ny := maxi(1, int(r.size.y / step))
	for j in ny:
		for i in nx:
			if spilled and k.h(i, j, sd + 77) > 0.55:
				continue
			var c := r.position + Vector2((i + 0.5) * r.size.x / nx, (j + 0.5) * r.size.y / ny)
			f.call(c, i, j)


static func _ice_bed(k: Kit, R: Rect2, art: String, sd: int, br: bool) -> void:
	k.rect(R, ZINC.darkened(0.2))
	var inner := R.grow(-2.5)
	k.rect(inner, ICE)
	for j in int(inner.size.x * inner.size.y / 40.0):
		var p := inner.position + Vector2(k.h(j, 1, sd), k.h(j, 2, sd)) * inner.size
		k.disc(p, 1.0 + k.h(j, 3, sd) * 1.5, Color(1, 1, 1, 0.5))
	var along_y := inner.size.y > inner.size.x
	var len := minf(inner.size.x if not along_y else inner.size.y, 30.0)
	var n := int((inner.size.y if along_y else inner.size.x) / 9.0)
	for j in n:
		if br and k.h(j, 4, sd) > 0.5:
			continue
		var t := (j + 0.5) / n
		var c := inner.position + (Vector2(inner.size.x * 0.5, inner.size.y * t) if along_y else Vector2(inner.size.x * t, inner.size.y * 0.5))
		var a := (0.0 if along_y else PI * 0.5) + (k.h(j, 5, sd) - 0.5) * 0.3 + (PI if j % 2 == 0 else 0.0)
		var col: Color = [G.SILVER, G.SILVER.darkened(0.1), Pal.FLOOR_TILE_2.lightened(0.35), Pal.SKYLIGHT.darkened(0.1), G.SILVER.lerp(Pal.GOLD, 0.2)][int(k.h(j, 6, sd) * 5.0) % 5]
		G.fish(k, c, len * (0.75 + k.h(j, 7, sd) * 0.25), a, col)
		if j % 4 == 2:
			G.fruit(k, c + Vector2(len * 0.35, 3).rotated(a), 2.4, Pal.GOLD2)
	if art == "fish_ice":
		for j in 3:
			k.rect(Rect2(inner.position.x + 4 + j * inner.size.x / 3.0, inner.end.y - 6, 8, 4), Pal.AWNING_CREAM.lightened(0.2))
	if br:
		k.shards(R.grow(4.0), 10, sd, Color(1, 1, 1, 0.8))
	_lip(k, R, ZINC)


static func _bins(k: Kit, R: Rect2, sd: int, br: bool, kinds: Array) -> void:
	k.rect(R, WOOD_D)
	var n := maxi(2, int(R.size.x / 22.0))
	var m := 2
	var cw := (R.size.x - 4.0) / n
	var ch := (R.size.y - 4.0) / m
	var idx := 0
	for j in m:
		for i in n:
			var cr := Rect2(R.position.x + 2 + i * cw, R.position.y + 2 + j * ch, cw - 2, ch - 2)
			k.rect(cr, WOOD.darkened(0.25))
			var what: String = kinds[(idx + sd) % kinds.size()]
			idx += 1
			if br and (i + j) % 2 == 0:
				continue
			G.pile(k, cr.grow(-1.5), what, sd + idx * 11)
			k.rect(Rect2(cr.position.x + 2, cr.end.y - 5, 8, 4), Pal.AWNING_CREAM.lightened(0.2))
	k.edges(R, WOOD, 1.5)


static func _nail_bins(k: Kit, R: Rect2, sd: int, br: bool) -> void:
	k.rect(R, WOOD_D)
	var n := maxi(2, int(R.size.x / 12.0))
	var m := maxi(2, int(R.size.y / 12.0))
	for j in m:
		for i in n:
			var cr := Rect2(R.position.x + 2 + i * (R.size.x - 4) / n, R.position.y + 2 + j * (R.size.y - 4) / m, (R.size.x - 4) / n - 1.5, (R.size.y - 4) / m - 1.5)
			k.rect(cr, WOOD.darkened(0.3))
			if br and k.h(i, j, sd) > 0.5:
				continue
			var col := STEEL.lightened(0.2) if (i + j) % 3 != 0 else Pal.BRASS.darkened(0.1)
			var segs := PackedVector2Array()
			for q in 10:
				var p := cr.position + Vector2(k.h(q, i + j * 9, sd), k.h(q, i * 3 + j, sd)) * cr.size
				var d := Vector2.from_angle(k.h(q, 7, sd + i + j) * TAU) * 2.5
				segs.append_array([p - d, p + d])
			k.lines(segs, col, 1.0)
	k.edges(R, WOOD, 1.5)


# ------------------------------------------------------------------ shelves

static func _shelf(k: Kit, R: Rect2, art: String, sd: int, br: bool) -> void:
	if br:
		# the shelf is toppled: it lies tipped forward, its goods thrown to the floor
		k.frame(k.org + Vector2(0, R.size.y * 0.35).rotated(k.ang), k.ang + (0.12 if sd % 2 == 0 else -0.12))
	var wood := WOOD if art not in ["club_backbar", "beer_backbar", "apothecary", "drawer_shelf", "bottle_shelf"] else MAHOG
	k.rect(R, wood.darkened(0.25))
	var inner := R.grow(-2.0)
	k.rect(inner, wood.darkened(0.45))
	# uprights every ~0.9 m
	var bays := maxi(1, int(round(R.size.x / (0.9 * M))))
	var bw := R.size.x / bays
	for b in bays:
		var bay := Rect2(R.position.x + b * bw + 2.0, R.position.y + 2.0, bw - 4.0, R.size.y - 4.0)
		_shelf_goods(k, bay, art, sd + b * 13, br)
	for b in bays + 1:
		k.rect(Rect2(R.position.x + b * bw - 1.5, R.position.y, 3.0, R.size.y), wood)
	# the front board, lit
	k.rect(Rect2(R.position.x, R.end.y - 2.5, R.size.x, 2.5), wood.lightened(0.12))
	k.rect(Rect2(R.position.x, R.position.y, R.size.x, 1.5), wood.darkened(0.4))
	if br:
		k.reset()


static func _shelf_goods(k: Kit, r: Rect2, art: String, sd: int, br: bool) -> void:
	var y := r.get_center().y
	match art:
		"bread_shelf":
			var n := int(r.size.x / 12.0)
			for j in n:
				var c := Vector2(r.position.x + 6 + j * 12.0, y + (j % 2) * 1.5 - 1.0)
				if br and j % 2 == 0:
					continue
				if j % 3 == 2:
					G.boule(k, c, 5.0, k.h(j, 1, sd))
				else:
					G.loaf(k, c, 11.0, 7.0, PI * 0.5 + (k.h(j, 2, sd) - 0.5) * 0.4, k.h(j, 3, sd))
		"grocery_shelf", "tin_shelf":
			var x := r.position.x + 2.0
			var j := 0
			while x < r.end.x - 4:
				var t := k.h(j, 1, sd)
				if br and t > 0.5:
					x += 6
					j += 1
					continue
				if t < 0.45:
					G.can(k, Vector2(x + 3.0, y), 2.8, G.BRIGHTS[j % G.BRIGHTS.size()] if art == "grocery_shelf" else Pal.AWNING_COLORS[j % 6].lightened(0.2))
					x += 6.5
				elif t < 0.75:
					G.box(k, Rect2(x, y - 4.0, 6.0, 8.0), [Pal.FLOOR_TILE_2, Pal.GOLD, Pal.AWNING_COLORS[2].lightened(0.2), Pal.AWNING_CREAM][j % 4])
					x += 7.0
				else:
					G.jar(k, Vector2(x + 3.5, y), 3.3, [Pal.FLOOR_TILE_2.lightened(0.2), Pal.GOLD, Pal.AWNING_COLORS[1].lightened(0.3)][j % 3])
					x += 7.5
				j += 1
		"cloth_shelf":
			var n2 := int(r.size.x / 7.0)
			for j in n2:
				if br and k.h(j, 2, sd) > 0.5:
					continue
				G.bolt(k, Rect2(r.position.x + 1 + j * 7.0, r.position.y + 1, 6.0, r.size.y - 2), G.CLOTHS[(j + sd) % G.CLOTHS.size()], false)
		"tonic_shelf", "bottle_shelf", "apothecary":
			var n3 := int(r.size.x / 6.0)
			for j in n3:
				if br and k.h(j, 3, sd) > 0.4:
					continue
				var col: Color = [Pal.AWNING_COLORS[2].lightened(0.3), Pal.RUST, Pal.GLASS, Pal.FELT.lightened(0.2), Pal.AWNING_CREAM][int(k.h(j, 1, sd) * 5.0) % 5]
				if art == "apothecary" and j % 4 == 0:
					G.box(k, Rect2(r.position.x + j * 6.0, y - 3, 5.0, 6.0), Pal.COUNTER.lightened(0.25), false)
					k.disc(Vector2(r.position.x + j * 6.0 + 2.5, y), 0.8, Pal.BRASS)
				else:
					G.bottle(k, Vector2(r.position.x + 3 + j * 6.0, y + (j % 2) * 2.0 - 1.0), 2.4, col)
		"shoe_shelf", "shoe_rack":
			var n4 := int(r.size.x / 11.0)
			for j in n4:
				if br and j % 2 == 1:
					continue
				G.pair(k, Vector2(r.position.x + 5.5 + j * 11.0, y), 9.0, PI * 0.5, [Pal.LEATHER, Pal.SIGN_BLACK.lightened(0.12), Pal.RUST.darkened(0.1), Pal.AWNING_CREAM.darkened(0.2)][(j + sd) % 4])
		"pawn_shelf":
			var x2 := r.position.x + 2.0
			var j2 := 0
			while x2 < r.end.x - 6:
				var t2 := k.h(j2, 1, sd)
				if not (br and t2 > 0.5):
					if t2 < 0.3:
						G.clock(k, Vector2(x2 + 4, y), 3.5)
					elif t2 < 0.55:
						G.box(k, Rect2(x2, y - 4, 10, 8), Pal.COUNTER.lightened(0.2))
						k.disc(Vector2(x2 + 3, y), 1.5, Pal.GOLD)
						k.disc(Vector2(x2 + 7, y), 1.5, Pal.GOLD)
					elif t2 < 0.8:
						k.disc(Vector2(x2 + 5, y), 4.0, Pal.BRASS.darkened(0.1))
						k.disc(Vector2(x2 + 5, y), 2.0, Pal.AWNING_CREAM)
					else:
						G.box(k, Rect2(x2, y - 3.5, 11, 7), IRON, false)
						for q in 3:
							k.disc(Vector2(x2 + 2 + q * 3.5, y), 0.9, Pal.AWNING_CREAM)
				x2 += 11.0
				j2 += 1
		"bundle_shelf":
			var n5 := int(r.size.x / 9.0)
			for j in n5:
				if br and j % 2 == 0:
					continue
				G.bundle(k, Rect2(r.position.x + 1 + j * 9.0, r.position.y + 1.5, 8.0, r.size.y - 3), k.h(j, 1, sd))
		"wine_shelf", "club_backbar", "beer_backbar":
			var n6 := int(r.size.x / 6.0)
			for j in n6:
				if br and k.h(j, 4, sd) > 0.4:
					continue
				var c := Vector2(r.position.x + 3 + j * 6.0, y + ((j % 2) * 3.0 - 1.5))
				if art == "club_backbar" and j % 3 == 0:
					G.cup(k, c, 1.9)
				elif art == "beer_backbar" and j % 3 == 0:
					G.glass_cup(k, c, 2.4)
				else:
					G.bottle(k, c, 2.5, G.BOTTLES[(j + sd) % G.BOTTLES.size()])
		"coffee_shelf":
			var n7 := int(r.size.x / 8.0)
			for j in n7:
				if br and j % 2 == 0:
					continue
				var c2 := Vector2(r.position.x + 4 + j * 8.0, y)
				if j % 3 == 0:
					G.bottle(k, c2, 2.6, G.BOTTLES[j % G.BOTTLES.size()])
				else:
					G.can(k, c2, 3.4, [Pal.FLOOR_TILE_2, Pal.GOLD.darkened(0.1), Pal.AWNING_COLORS[2]][j % 3])
		"jar_shelf":
			var n8 := int(r.size.x / 8.0)
			for j in n8:
				if br and k.h(j, 5, sd) > 0.45:
					continue
				G.jar(k, Vector2(r.position.x + 4 + j * 8.0, y), 3.4, G.BRIGHTS[(j * 5 + sd) % G.BRIGHTS.size()])
		"drawer_shelf":
			var cols := int(r.size.x / 7.0)
			var rows := maxi(1, int(r.size.y / 6.0))
			for j in rows:
				for i in cols:
					var dr := Rect2(r.position.x + i * 7.0 + 0.5, r.position.y + j * r.size.y / rows + 0.5, 6.0, r.size.y / rows - 1.0)
					if br and k.h(i, j, sd) > 0.7:
						k.rect(dr, Pal.SIGN_BLACK.lightened(0.1))
						continue
					k.rect(dr, MAHOG.lightened(0.12))
					k.disc(dr.get_center(), 0.8, Pal.BRASS)
		"cigar_shelf":
			var n9 := int(r.size.x / 11.0)
			for j in n9:
				if br and j % 2 == 1:
					continue
				G.cigarbox(k, Rect2(r.position.x + 1 + j * 11.0, r.position.y + 1.5, 10.0, r.size.y - 3), false, k.h(j, 1, sd))
		"towel_shelf":
			var n10 := int(r.size.x / 12.0)
			for j in n10:
				G.towel(k, Rect2(r.position.x + 1 + j * 12.0, r.position.y + 1.5, 11.0, r.size.y - 3))
		"leather_shelf":
			var n11 := int(r.size.y / 9.0)
			for j in n11:
				G.bolt(k, Rect2(r.position.x + 1, r.position.y + 1 + j * 9.0, r.size.x - 2, 8.0), [Pal.LEATHER, Pal.RUST.darkened(0.1), Pal.COUNTER.lightened(0.2)][j % 3], false)
		"crate_shelf", "stock_shelf", "box_shelf", "beer_cases":
			var n12 := maxi(1, int(r.size.y / 15.0))
			for j in n12:
				var cr := Rect2(r.position.x + 1, r.position.y + 1 + j * r.size.y / n12, r.size.x - 2, r.size.y / n12 - 2)
				if art == "crate_shelf":
					k.rect(cr, Pal.PLANKS.lightened(0.15))
					G.pile(k, cr.grow(-2.0), ["apple", "onion", "potato", "orange"][(j + sd) % 4], sd + j)
				elif art == "box_shelf":
					G.box(k, cr, [Pal.FLOOR_TILE_2.lightened(0.3), Pal.AWNING_CREAM, Pal.GOLD2.darkened(0.1)][j % 3])
				elif art == "beer_cases":
					_crate(k, cr, sd + j, true)
				else:
					G.box(k, cr, Pal.ROPE.darkened(0.2), true)
		"sack_shelf":
			var n13 := maxi(1, int(r.size.y / 14.0))
			for j in n13:
				G.sack(k, Vector2(r.get_center().x, r.position.y + (j + 0.5) * r.size.y / n13), Vector2(r.size.x - 3, r.size.y / n13 - 2), 0.0, Pal.ROPE.darkened(0.15 + 0.05 * (j % 2)))
		"pipe_rack":
			var segs := PackedVector2Array()
			var n14 := int(r.size.x / 3.0)
			for j in n14:
				var x3 := r.position.x + 1.5 + j * 3.0
				segs.append_array([Vector2(x3, r.position.y + 1), Vector2(x3, r.end.y - 1)])
			k.lines(segs, STEEL.lightened(0.15), 2.0)
			for j in int(r.size.x / 18.0):
				k.rect(Rect2(r.position.x + 2 + j * 18.0, r.position.y + 1, 14.0, r.size.y - 2), Pal.FLOOR_WOOD.lightened(0.25))


static func _meat_hooks(k: Kit, R: Rect2, sd: int, br: bool) -> void:
	# a rail on the wall with sausages, hams and salami hanging from it
	k.rect(Rect2(R.position.x, R.position.y, R.size.x, 4.0), WOOD_D)
	k.line(Vector2(R.position.x + 2, R.position.y + 6), Vector2(R.end.x - 2, R.position.y + 6), STEEL.lightened(0.3), 2.0)
	var n := int(R.size.x / 10.0)
	for j in n:
		var x := R.position.x + 5 + j * 10.0
		if br and j % 2 == 0:
			continue
		k.line(Vector2(x, R.position.y + 6), Vector2(x, R.position.y + 9), STEEL, 1.0)
		match (j + sd) % 4:
			0: G.ham(k, Vector2(x, R.position.y + 13), 11.0, PI * -0.5)
			1: G.links(k, Vector2(x, R.position.y + 8), Vector2(x, R.end.y - 1), 3)
			2: G.salami(k, Vector2(x, R.position.y + 13), 12.0, PI * 0.5)
			_: G.links(k, Vector2(x - 2, R.position.y + 8), Vector2(x + 2, R.end.y - 2), 3)


static func _instruments(k: Kit, R: Rect2, sd: int, br: bool) -> void:
	# hung flat against the wall: guitars, a violin, a trumpet, a banjo
	k.rect(Rect2(R.position.x, R.position.y, R.size.x, 3.0), WOOD_D)
	var n := int(R.size.x / 26.0)
	for j in n:
		var c := Vector2(R.position.x + 13 + j * 26.0, R.get_center().y + 1)
		if br and j % 2 == 0:
			_guitar(k, c + Vector2(0, R.size.y * 0.6), (PI * 0.5 + 0.6) * (1.0 if j % 4 == 0 else -1.0), Pal.COUNTER.lightened(0.3), true)
			continue
		match (j + sd) % 4:
			0: _guitar(k, c, 0.0, Pal.FLOOR_WOOD.lightened(0.3), false)
			1: _violin(k, c)
			2: _trumpet(k, c)
			_: _banjo(k, c)


static func _guitar(k: Kit, c: Vector2, a: float, col: Color, broken: bool) -> void:
	var d := Vector2(0, 1).rotated(a)
	var n := Vector2(-d.y, d.x)
	k.disc(c + d * 3.0 + k.sh * 2.0, 6.5, Color(Kit.SH_COL, 0.25))
	k.disc(c + d * 4.0, 6.5, col)
	k.disc(c - d * 3.0, 5.0, col)
	k.disc(c + d * 2.0, 2.0, Pal.SIGN_BLACK)
	k.line(c - d * 6.0, c - d * (14.0 if not broken else 9.0), Pal.COUNTER.darkened(0.1), 2.5)
	k.line(c - d * 14.0 - n * 0.0, c - d * 17.0, Pal.COUNTER.darkened(0.2), 3.5)
	if broken:
		k.line(c - d * 9.0 + n * 3.0, c - d * 13.0 + n * 6.0, Pal.COUNTER.darkened(0.1), 2.5)


static func _violin(k: Kit, c: Vector2) -> void:
	k.disc(c + Vector2(0, 3) + k.sh * 2.0, 4.5, Color(Kit.SH_COL, 0.25))
	k.disc(c + Vector2(0, 3), 4.5, Pal.RUST.lightened(0.1))
	k.disc(c - Vector2(0, 2), 3.5, Pal.RUST.lightened(0.1))
	k.line(c - Vector2(0, 5), c - Vector2(0, 13), Pal.SIGN_BLACK, 2.0)
	k.disc(c - Vector2(0, 13), 1.5, Pal.SIGN_BLACK)


static func _trumpet(k: Kit, c: Vector2) -> void:
	k.line(c + Vector2(-9, -2), c + Vector2(6, -2), Pal.BRASS, 2.0)
	k.line(c + Vector2(-9, 2), c + Vector2(4, 2), Pal.BRASS, 2.0)
	k.disc(c + Vector2(8, 0), 5.0, Pal.BRASS.lightened(0.1))
	k.disc(c + Vector2(8, 0), 3.0, Pal.BRASS.darkened(0.3))
	for q in 3:
		k.disc(c + Vector2(-3 + q * 3, 0), 1.2, Pal.BRASS.lightened(0.3))


static func _banjo(k: Kit, c: Vector2) -> void:
	k.disc(c + Vector2(0, 4), 6.5, STEEL.lightened(0.2))
	k.disc(c + Vector2(0, 4), 5.2, Pal.AWNING_CREAM.lightened(0.1))
	k.line(c - Vector2(0, 2), c - Vector2(0, 14), Pal.COUNTER.darkened(0.1), 2.0)


static func _tool_wall(k: Kit, R: Rect2, sd: int, br: bool) -> void:
	k.rect(R, Pal.FLOOR_WOOD.lightened(0.3))
	var dots := PackedVector2Array()
	var x := R.position.x + 3
	while x < R.end.x:
		var y := R.position.y + 3
		while y < R.end.y:
			dots.append_array([Vector2(x, y), Vector2(x + 0.8, y)])
			y += 5
		x += 5
	k.lines(dots, Pal.FLOOR_WOOD.darkened(0.2), 1.0)
	var n := int(R.size.y / 14.0)
	for j in n:
		if br and j % 2 == 0:
			continue
		var y2 := R.position.y + 7 + j * 14.0
		match (j + sd) % 5:
			0:
				k.poly(PackedVector2Array([Vector2(R.position.x + 3, y2 - 4), Vector2(R.end.x - 4, y2 - 2), Vector2(R.end.x - 4, y2 + 2), Vector2(R.position.x + 3, y2 + 4)]), STEEL.lightened(0.35))
				k.rect(Rect2(R.position.x + 1, y2 - 3, 6, 6), Pal.COUNTER)
			1:
				k.line(Vector2(R.position.x + 4, y2), Vector2(R.end.x - 6, y2), Pal.FLOOR_WOOD.lightened(0.1), 2.0)
				k.rect(Rect2(R.end.x - 8, y2 - 3.5, 6, 7), IRON)
			2:
				k.line(Vector2(R.position.x + 2, y2), Vector2(R.end.x - 9, y2), Pal.FLOOR_WOOD.lightened(0.1), 2.0)
				k.poly(PackedVector2Array([Vector2(R.end.x - 10, y2 - 4), Vector2(R.end.x - 2, y2 - 3), Vector2(R.end.x - 2, y2 + 3), Vector2(R.end.x - 10, y2 + 4)]), STEEL)
			3:
				k.ball(Vector2(R.get_center().x, y2), 4.0, Pal.FLOOR_TILE_2, 3.0)
				k.ring(Vector2(R.get_center().x, y2), 4.5, STEEL, 1.0)
			_:
				for q in 3:
					G.can(k, Vector2(R.position.x + 5 + q * 7.0, y2), 3.0, [Pal.FLOOR_TILE_2, Pal.AWNING_COLORS[2].lightened(0.3), Pal.AWNING_CREAM][q])


static func _bread_rack(k: Kit, R: Rect2, sd: int, br: bool) -> void:
	k.rect(R, WOOD.darkened(0.1))
	var n := maxi(1, int(R.size.x / 26.0))
	for b in n:
		var bay := Rect2(R.position.x + 2 + b * (R.size.x - 4) / n, R.position.y + 2, (R.size.x - 4) / n - 2, R.size.y - 4)
		k.rect(bay, Pal.ROPE.darkened(0.3))
		# a wicker basket of baguettes and a row of round loaves
		var bs := Rect2(bay.position + Vector2(1, 1), Vector2(bay.size.x * 0.45, bay.size.y - 2))
		k.rrect(bs, 3.0, Pal.ROPE.darkened(0.05))
		if not (br and b % 2 == 0):
			for q in 4:
				G.baguette(k, Vector2(bs.get_center().x - 3 + q * 2.2, bs.get_center().y), bs.size.y * 0.8, PI * 0.5 + (q - 1.5) * 0.12)
			for q in maxi(1, int(bay.size.y / 12.0)):
				G.boule(k, Vector2(bay.position.x + bay.size.x * 0.75, bay.position.y + 6 + q * 12.0), 5.0, k.h(b, q, sd))
	for b in n + 1:
		k.rect(Rect2(R.position.x + b * (R.size.x - 2) / n, R.position.y, 2.0, R.size.y), WOOD)
	k.edges(R, WOOD, 1.5)


static func _suit_rack(k: Kit, R: Rect2, sd: int, br: bool) -> void:
	# a rail with jackets on hangers, seen from above: shoulders and collars in a row
	var rail_y := R.get_center().y
	k.line(Vector2(R.position.x + 2, rail_y), Vector2(R.end.x - 2, rail_y), STEEL.lightened(0.3), 2.0)
	var n := int(R.size.x / 6.0)
	for j in n:
		var x := R.position.x + 4 + j * 6.0
		if br and k.h(j, 1, sd) > 0.6:
			continue
		var col: Color = Pal.SUITS[(j * 3 + sd) % Pal.SUITS.size()]
		var sh := Rect2(x - 2.5, R.position.y + 2, 5.0, R.size.y - 4)
		k.rect(Rect2(sh.position + k.sh * 2.0, sh.size), Color(Kit.SH_COL, 0.2))
		k.rrect(sh, 2.0, col)
		k.line(Vector2(x, R.position.y + 3), Vector2(x, R.end.y - 3), col.lightened(0.15), 1.0)
		k.disc(Vector2(x, rail_y), 1.0, Pal.BRASS)
	if br:
		for j in 3:
			var c := R.get_center() + Vector2((j - 1) * 16.0, R.size.y * 0.9)
			k.rrect(Rect2(c - Vector2(8, 5), Vector2(16, 10)), 3.0, Pal.SUITS[j + 1])


static func _news_rack(k: Kit, R: Rect2, sd: int, br: bool) -> void:
	k.rect(R, WOOD_D)
	var n := int(R.size.y / 11.0)
	for j in n:
		if br and j % 2 == 0:
			continue
		var r := Rect2(R.position.x + 2, R.position.y + 1 + j * 11.0, R.size.x - 4, 10.0)
		if j % 3 == 2:
			k.rect(r, G.BRIGHTS[(j + sd) % G.BRIGHTS.size()].darkened(0.1))
			k.rect(Rect2(r.position + Vector2(2, 2), Vector2(r.size.x - 4, 2.5)), Pal.AWNING_CREAM)
		else:
			G.newspaper(k, r, 0.0, k.h(j, 1, sd))
	k.edges(R, WOOD, 1.5)
	if br:
		for j in 5:
			G.newspaper(k, Rect2(R.get_center() + Vector2(R.size.x * 0.8 + k.h(j, 2, sd) * 18.0, (k.h(j, 3, sd) - 0.5) * R.size.y), Vector2(14, 11)), k.h(j, 4, sd) * 2.0, k.h(j, 5, sd))


static func _cue_rack(k: Kit, R: Rect2, sd: int, br: bool) -> void:
	k.rect(R, WOOD_D)
	var n := int(R.size.x / 4.0)
	for j in n:
		if br and j % 3 != 0:
			continue
		var x := R.position.x + 2 + j * 4.0
		k.disc(Vector2(x, R.get_center().y), 1.6, Pal.AWNING_CREAM.darkened(0.1) if j % 2 == 0 else Pal.COUNTER.lightened(0.3))
	if br:
		for j in 3:
			var c := R.get_center() + Vector2((k.h(j, 1, sd) - 0.5) * R.size.x, R.size.y * 2.0 + j * 6.0)
			k.line(c - Vector2(30, 2 - j * 3), c + Vector2(30, 2 - j), Pal.FLOOR_WOOD.lightened(0.35), 2.0)


static func _proving_rack(k: Kit, R: Rect2, sd: int) -> void:
	k.rect(R, STEEL.darkened(0.2))
	var tr := R.grow(-2.0)
	k.rect(tr, Pal.PLANKS.lightened(0.2))
	for j in 3:
		for i in 3:
			k.ball(tr.position + Vector2((i + 0.5) * tr.size.x / 3.0, (j + 0.5) * tr.size.y / 3.0), 4.0, G.CRUMB, 1.5, 0.15)
	k.edges(R, STEEL, 1.5)
	var _unused := sd


static func _tally_board(k: Kit, R: Rect2, sd: int) -> void:
	k.rect(R, WOOD_D)
	var b := R.grow(-2.0)
	k.rect(b, Pal.FELT.darkened(0.55))
	for j in 3:
		k.line(Vector2(b.position.x + 2, b.position.y + 3 + j * 4.5), Vector2(b.end.x - 2 - k.h(j, 1, sd) * 12.0, b.position.y + 3 + j * 4.5), Color(1, 1, 1, 0.55), 1.0)
	k.text_on(Vector2(0, 1), "7 · 3 · 9", 10, Color(1, 1, 1, 0.8), "cond")


# ------------------------------------------------------------------ tables and seats

static func _table_checked(k: Kit, R: Rect2, sd: int) -> void:
	var cloth := R.grow(3.0)
	k.rect(cloth, Pal.AWNING_CREAM.lightened(0.1))
	var q := cloth.size.x / 6.0
	for j in 6:
		for i in 6:
			if (i + j) % 2 == 0:
				k.rect(Rect2(cloth.position + Vector2(i * q, j * cloth.size.y / 6.0), Vector2(q, cloth.size.y / 6.0)), Pal.FLOOR_TILE_2.lightened(0.05))
	k.edges(cloth, Pal.AWNING_CREAM, 1.5, 0.1, 0.2)
	var c := Vector2.ZERO
	# the chianti bottle with its candle, two places laid
	k.disc(c + k.sh * 3.0, 4.0, Color(Kit.SH_COL, 0.3))
	k.disc(c, 4.5, Pal.ROPE)
	k.disc(c, 3.0, Pal.FELT.darkened(0.1))
	k.disc(c, 1.4, Pal.AWNING_CREAM)
	k.disc(c, 0.7, Pal.GOLD2)
	G.plate(k, Vector2(-R.size.x * 0.28, 0), 5.0, Pal.FLOOR_TILE_2.lightened(0.15) if sd % 2 == 0 else Color(0, 0, 0, 0))
	G.plate(k, Vector2(R.size.x * 0.28, 0), 5.0, Pal.GOLD.darkened(0.1) if sd % 3 == 0 else Color(0, 0, 0, 0))
	G.glass_cup(k, Vector2(-R.size.x * 0.2, -R.size.y * 0.3), 2.0, Color(Pal.FLOOR_TILE_2, 0.7))
	G.glass_cup(k, Vector2(R.size.x * 0.22, R.size.y * 0.3), 2.0)
	k.rrect(Rect2(Vector2(-4, R.size.y * 0.2), Vector2(8, 5)), 2.0, Pal.ROPE.darkened(0.1))


static func _table_round(k: Kit, R: Rect2, sd: int) -> void:
	var r := minf(R.size.x, R.size.y) * 0.5
	k.disc(Vector2.ZERO, r, Pal.MARBLE.darkened(0.12))
	k.disc(k.lit * 0.8, r - 1.5, Pal.MARBLE)
	k.ring(Vector2.ZERO, r - 1.0, Pal.BRASS.darkened(0.2), 1.0)
	G.cup(k, Vector2(-r * 0.35, r * 0.1), 2.3)
	if sd % 2 == 0:
		G.cup(k, Vector2(r * 0.35, -r * 0.15), 2.3)
	k.disc(Vector2(r * 0.1, -r * 0.45), 2.0, Pal.GLASS.lightened(0.2))


static func _card_table(k: Kit, R: Rect2, sd: int, booze: bool) -> void:
	var wood := MAHOG
	k.rect(R, wood)
	var f := R.grow(-3.0)
	k.rect(f, Pal.FELT)
	k.edges(R, wood, 1.5)
	k.ring(Vector2.ZERO, minf(f.size.x, f.size.y) * 0.3, Color(Pal.FELT.lightened(0.15), 0.6), 1.0)
	# a game in progress: a hand at each place, the pot in the middle
	for j in 4:
		var d := Vector2.from_angle(j * PI * 0.5 + 0.2)
		for q in 3:
			G.card(k, d * f.size.x * 0.32 + Vector2(-d.y, d.x) * (q - 1) * 3.0, d.angle() + PI * 0.5 + (q - 1) * 0.2, (q + j + sd) % 3 == 0)
	for q in 3:
		G.chips(k, Vector2((q - 1) * 5.0, 2.0), [Pal.FLOOR_TILE_2, Pal.AWNING_CREAM, Pal.AWNING_COLORS[2].lightened(0.2)][q], 2)
	G.cash(k, Vector2(-3, -5), 0.3)
	G.ashtray(k, Vector2(f.size.x * 0.32, -f.size.y * 0.32), true)
	if booze:
		G.bottle(k, Vector2(-f.size.x * 0.3, -f.size.y * 0.3), 3.2, G.BOTTLES[sd % G.BOTTLES.size()])
		G.glass_cup(k, Vector2(-f.size.x * 0.3, f.size.y * 0.3), 2.3, Color(Pal.GOLD, 0.8))
	else:
		G.cup(k, Vector2(-f.size.x * 0.32, f.size.y * 0.3), 2.0)


static func _cocktail_table(k: Kit, R: Rect2, sd: int) -> void:
	var r := minf(R.size.x, R.size.y) * 0.5
	k.disc(Vector2.ZERO, r + 1.5, Pal.AWNING_CREAM.darkened(0.08))
	k.disc(k.lit * 0.8, r, Pal.AWNING_CREAM.lightened(0.08))
	k.ring(Vector2.ZERO, r - 2.0, Pal.AWNING_CREAM.darkened(0.15), 1.0)
	# a little shaded lamp, cocktails, an ashtray
	k.disc(Vector2(0, -r * 0.2), 4.0, Pal.FLOOR_TILE_2.lightened(0.1))
	k.disc(Vector2(0, -r * 0.2), 1.6, Pal.GOLD2)
	G.glass_cup(k, Vector2(-r * 0.45, r * 0.25), 2.4, Color(Pal.GOLD, 0.8))
	G.glass_cup(k, Vector2(r * 0.45, r * 0.3), 2.4, Color(Pal.FLOOR_TILE_2.lightened(0.3), 0.8))
	G.ashtray(k, Vector2(r * 0.1, r * 0.55), sd % 2 == 0)


static func _bench(k: Kit, R: Rect2, cushion: bool) -> void:
	var wood := WOOD if not cushion else MAHOG
	k.rect(R, wood.darkened(0.2))
	var n := 3
	for j in n:
		var sl := Rect2(R.position.x + 1, R.position.y + 1 + j * (R.size.y - 2) / n, R.size.x - 2, (R.size.y - 2) / n - 1.5)
		k.rect(sl, wood.lightened(0.06 * j))
	if cushion:
		var cc := Rect2(R.position.x + 3, R.position.y + R.size.y * 0.35, R.size.x - 6, R.size.y * 0.55)
		var m := maxi(1, int(cc.size.x / 22.0))
		for j in m:
			k.rrect(Rect2(cc.position.x + j * cc.size.x / m + 1, cc.position.y, cc.size.x / m - 2, cc.size.y), 3.0, Pal.LEATHER.lightened(0.15))
	# the back rail against the wall
	k.rect(Rect2(R.position.x, R.position.y, R.size.x, 3.0), wood.darkened(0.35))
	k.edges(R, wood, 1.0)


static func _cot(k: Kit, R: Rect2, sd: int) -> void:
	k.rect(R, IRON)
	var m := R.grow(-2.0)
	k.rect(m, Pal.QUAY_STONE.darkened(0.1))
	k.rect(Rect2(m.position.x, m.position.y, m.size.x, m.size.y * 0.7), Pal.SUITS[4].lightened(0.1))
	k.line(Vector2(m.position.x, m.position.y + m.size.y * 0.7), Vector2(m.end.x, m.position.y + m.size.y * 0.7), Pal.SUITS[4].darkened(0.2), 1.5)
	k.rrect(Rect2(m.position.x + 3, m.end.y - m.size.y * 0.22, m.size.x - 6, m.size.y * 0.18), 3.0, Pal.AWNING_CREAM.darkened(0.15))
	var _unused := sd


static func _barber_chair(k: Kit, R: Rect2) -> void:
	# the porcelain base, the red leather seat and back, the footrest toward the mirror (+y)
	var c := Vector2(0, -R.size.y * 0.05)
	k.ball(c, R.size.x * 0.34, ENAMEL, 10.0, 0.3)
	var back := Rect2(-R.size.x * 0.33, -R.size.y * 0.5, R.size.x * 0.66, R.size.y * 0.3)
	k.rrect(back, 4.0, Pal.FLOOR_TILE_2.darkened(0.1))
	k.rrect(back.grow(-2.0), 3.0, Pal.FLOOR_TILE_2.lightened(0.1))
	k.disc(Vector2(0, -R.size.y * 0.52), 3.5, Pal.AWNING_CREAM)
	var seat := Rect2(-R.size.x * 0.3, -R.size.y * 0.2, R.size.x * 0.6, R.size.y * 0.38)
	k.rrect(seat, 4.0, Pal.FLOOR_TILE_2.lightened(0.05))
	k.line(Vector2(seat.position.x + 3, seat.get_center().y), Vector2(seat.end.x - 3, seat.get_center().y), Pal.FLOOR_TILE_2.darkened(0.2), 1.0)
	for sgn: float in [-1.0, 1.0]:
		k.rrect(Rect2(Vector2(sgn * R.size.x * 0.36 - 2.5, -R.size.y * 0.25), Vector2(5, R.size.y * 0.42)), 2.0, STEEL.lightened(0.4))
	k.rrect(Rect2(-R.size.x * 0.22, R.size.y * 0.25, R.size.x * 0.44, R.size.y * 0.2), 2.0, STEEL.lightened(0.3))
	k.line(Vector2(0, R.size.y * 0.18), Vector2(0, R.size.y * 0.25), STEEL, 3.0)


static func _shine_stand(k: Kit, R: Rect2) -> void:
	k.top(R, MAHOG, 2.0)
	k.rrect(Rect2(-R.size.x * 0.32, -R.size.y * 0.42, R.size.x * 0.64, R.size.y * 0.5), 4.0, Pal.LEATHER.lightened(0.2))
	for sgn: float in [-1.0, 1.0]:
		k.rect(Rect2(Vector2(sgn * R.size.x * 0.18 - 3, R.size.y * 0.22), Vector2(6, 9)), Pal.BRASS)
	k.rect(Rect2(-R.size.x * 0.45, R.size.y * 0.1, R.size.x * 0.9, 3), Pal.BRASS.darkened(0.2))


# ------------------------------------------------------------------ the office

static func _desk(k: Kit, R: Rect2, sd: int, style: String) -> void:
	var wood := MAHOG if style == "boss" else (WOOD if style == "captain" else OAK.darkened(0.08))
	k.top(R, wood, 2.5)
	k.grain(R.grow(-3), wood.darkened(0.35), true, 0, sd)
	k.rect(Rect2(R.position.x, R.end.y - 3.0, R.size.x, 3.0), wood.darkened(0.3))
	var bl := Rect2(-R.size.x * 0.22, -R.size.y * 0.25, R.size.x * 0.44, R.size.y * 0.55)
	if style == "boss":
		k.rect(bl, Pal.FELT.darkened(0.25))
		k.ci.draw_rect(bl, Pal.LEATHER, false, 2.0)
		G.paper(k, Rect2(bl.get_center() + Vector2(-6, -6), Vector2(14, 16)), 0.1, 4)
		k.line(bl.get_center() + Vector2(10, -4), bl.get_center() + Vector2(14, 8), Pal.SIGN_BLACK, 1.5)
		k.disc(bl.get_center() + Vector2(14, 8), 1.0, Pal.GOLD)
		G.ashtray(k, Vector2(R.size.x * 0.34, R.size.y * 0.05), true)
		G.glass_cup(k, Vector2(-R.size.x * 0.34, R.size.y * 0.15), 2.8, Color(Pal.FLOOR_TILE_2.darkened(0.2), 0.9))
		# the photograph of the family in a silver frame
		k.rect(Rect2(Vector2(-R.size.x * 0.4, -R.size.y * 0.35), Vector2(10, 8)), STEEL.lightened(0.4))
		k.rect(Rect2(Vector2(-R.size.x * 0.4 + 1.5, -R.size.y * 0.35 + 1.5), Vector2(7, 5)), Pal.PAPER.darkened(0.3))
		_phone(k, Vector2(R.size.x * 0.34, -R.size.y * 0.25), 0.9)
	elif style == "captain":
		G.paper(k, Rect2(bl.position, Vector2(16, 20)), -0.1, 5)
		G.paper(k, Rect2(bl.position + Vector2(12, 3), Vector2(16, 20)), 0.15, 5)
		_typewriter(k, Vector2(R.size.x * 0.3, -R.size.y * 0.05))
		k.disc(Vector2(-R.size.x * 0.38, -R.size.y * 0.2), 3.0, IRON)
		_phone(k, Vector2(-R.size.x * 0.36, R.size.y * 0.18), 0.85)
	else:
		G.paper(k, Rect2(bl.position, Vector2(14, 18)), 0.05, 4)
		G.paper(k, Rect2(bl.position + Vector2(16, 2), Vector2(14, 18)), -0.12, 4)
		G.cup(k, Vector2(R.size.x * 0.34, R.size.y * 0.1), 2.5)
		for q in 3:
			G.paper(k, Rect2(Vector2(-R.size.x * 0.4 + q, -R.size.y * 0.3 + q), Vector2(12, 14)), 0.0, 2)


static func _typewriter(k: Kit, c: Vector2) -> void:
	k.rrect(Rect2(c - Vector2(9, 6) + k.sh * 3.0, Vector2(18, 13)), 2.0, Color(Kit.SH_COL, 0.3))
	k.rrect(Rect2(c - Vector2(9, 6), Vector2(18, 13)), 2.0, IRON.lightened(0.05))
	k.rect(Rect2(c - Vector2(10, 7), Vector2(20, 3)), IRON.lightened(0.2))
	k.rect(Rect2(c - Vector2(6, 9), Vector2(12, 3)), Pal.PAPER)
	for row in 3:
		for q in 5:
			k.disc(c + Vector2(-6 + q * 3.0, -1.0 + row * 2.6), 0.9, Pal.AWNING_CREAM)


static func _phone(k: Kit, c: Vector2, sz: float) -> void:
	# a candlestick telephone: round base, the stem, the earpiece on its hook
	k.shadow_disc(c, 4.0 * sz, 6.0)
	k.disc(c, 4.0 * sz, Pal.SIGN_BLACK.lightened(0.12))
	k.disc(c, 2.2 * sz, Pal.SIGN_BLACK.lightened(0.25))
	k.disc(c + k.lit * sz, 1.2 * sz, Pal.SIGN_BLACK.lightened(0.45))
	k.line(c + Vector2(3, -1) * sz, c + Vector2(7, -4) * sz, Pal.SIGN_BLACK.lightened(0.1), 1.5)
	k.rrect(Rect2(c + Vector2(5.5, -6.5) * sz, Vector2(3.5, 5.5) * sz), 1.5, Pal.SIGN_BLACK.lightened(0.2))
	var pts := PackedVector2Array()
	for j in 6:
		pts.append(c + Vector2(-2 - j * 1.8, 2.0 + sin(j * 1.4) * 1.5) * sz)
	k.pline(pts, Pal.SIGN_BLACK.lightened(0.15), 1.0)


static func _safe(k: Kit, R: Rect2) -> void:
	var col := Pal.FELT.darkened(0.45)
	k.top(R, col, 3.0)
	k.ci.draw_rect(R.grow(-3.0), Pal.SIGN_GOLD.darkened(0.2), false, 1.0)
	# the door on the front (+y): dial and handle
	var d := Rect2(R.position.x + 3, R.end.y - 6, R.size.x - 6, 4)
	k.rect(d, col.darkened(0.3))
	k.disc(Vector2(-R.size.x * 0.15, R.end.y - 4), 3.5, STEEL.lightened(0.4))
	k.disc(Vector2(-R.size.x * 0.15, R.end.y - 4), 1.5, IRON)
	k.line(Vector2(R.size.x * 0.12, R.end.y - 4), Vector2(R.size.x * 0.3, R.end.y - 4), Pal.BRASS, 2.0)
	k.text_on(Vector2(0, -R.size.y * 0.1), "HALL", 7, Pal.SIGN_GOLD, "cond")


static func _map_table(k: Kit, R: Rect2, sd: int) -> void:
	k.top(R, MAHOG, 2.5)
	var m := R.grow(-5.0)
	k.rect(m, Pal.PAPER.darkened(0.05))
	# a planning map of the district: blocks, streets, the river, pins in family colours
	var nx := 4
	var ny := 3
	var bw := m.size.x / nx
	var bh := m.size.y / ny
	for j in ny:
		for i in nx:
			var b := Rect2(m.position + Vector2(i * bw + 2.5, j * bh + 2.5), Vector2(bw - 5, bh - 5))
			k.rect(b, Pal.PAPER.darkened(0.14 + 0.05 * k.h(i, j, sd)))
			k.ci.draw_rect(b, Color(Pal.PAPER_INK, 0.35), false, 1.0)
	k.rect(Rect2(m.end.x - 7, m.position.y, 7, m.size.y), Pal.GLASS.darkened(0.1))
	var pins := [Pal.FLOOR_TILE_2.lightened(0.2), Pal.AWNING_COLORS[2].lightened(0.3), Pal.GOLD, Pal.AWNING_COLORS[1].lightened(0.3)]
	for j in 9:
		var p := m.position + Vector2(k.h(j, 1, sd), k.h(j, 2, sd)) * (m.size - Vector2(10, 4)) + Vector2(2, 2)
		k.disc(p + k.sh * 1.5, 2.0, Color(Kit.SH_COL, 0.3))
		k.disc(p, 2.0, pins[j % pins.size()])
		k.disc(p + Vector2(-0.6, -0.6), 0.7, Color(1, 1, 1, 0.7))
	# a magnifying glass and a pencil
	k.ring(m.position + Vector2(m.size.x * 0.3, m.size.y * 0.7), 5.0, Pal.BRASS, 2.0)
	k.line(m.position + Vector2(m.size.x * 0.3 + 4, m.size.y * 0.7 + 4), m.position + Vector2(m.size.x * 0.3 + 10, m.size.y * 0.7 + 9), Pal.COUNTER, 2.5)
	k.line(m.position + Vector2(m.size.x * 0.6, m.size.y * 0.2), m.position + Vector2(m.size.x * 0.75, m.size.y * 0.3), Pal.GOLD, 1.5)


static func _phone_stand(k: Kit, R: Rect2) -> void:
	k.top(R, MAHOG, 2.0)
	_phone(k, Vector2(0, -R.size.y * 0.1), 1.0)
	G.paper(k, Rect2(Vector2(-R.size.x * 0.4, R.size.y * 0.12), Vector2(R.size.x * 0.4, R.size.y * 0.3)), 0.1, 2)


static func _file_cabinet(k: Kit, R: Rect2) -> void:
	var col := Pal.FELT.lerp(Pal.QUAY_STONE, 0.6)
	k.top(R, col, 2.0)
	var n := 3
	for j in n:
		var y := R.position.y + (j + 1) * R.size.y / (n + 1)
		k.line(Vector2(R.position.x + 2, y), Vector2(R.end.x - 2, y), col.darkened(0.25), 1.0)
	G.paper(k, Rect2(Vector2(-6, -R.size.y * 0.3), Vector2(12, 14)), 0.2, 3)
	k.rect(Rect2(R.end.x - 4, R.position.y + 4, 2, R.size.y - 8), STEEL.lightened(0.3))


static func _sideboard(k: Kit, R: Rect2, sd: int) -> void:
	k.top(R, MAHOG, 2.0)
	k.grain(R.grow(-2), MAHOG.darkened(0.4), true, 0, sd)
	# decanters and glasses on a silver tray, a vase
	var tray := Rect2(-R.size.x * 0.35, -R.size.y * 0.3, R.size.x * 0.4, R.size.y * 0.6)
	k.rrect(tray, 3.0, STEEL.lightened(0.45))
	G.bottle(k, tray.get_center() + Vector2(-5, 0), 3.8, Pal.FLOOR_TILE_2.darkened(0.2))
	G.bottle(k, tray.get_center() + Vector2(6, -1), 3.5, Pal.GOLD.darkened(0.2))
	G.glass_cup(k, tray.get_center() + Vector2(0, 5), 2.0)
	k.ball(Vector2(R.size.x * 0.3, 0), 4.5, Pal.AWNING_COLORS[2].lightened(0.1), 6.0)
	for j in 5:
		k.disc(Vector2(R.size.x * 0.3, 0) + Vector2.from_angle(j * 1.3) * 3.0, 1.8, Pal.FLOOR_TILE_2.lightened(0.3 + j * 0.05))


# ------------------------------------------------------------------ pool, piano, phonograph

static func _pool_table(k: Kit, R: Rect2, sd: int) -> void:
	var rail := Pal.COUNTER.lightened(0.08)
	k.rrect(R, 4.0, rail.darkened(0.2))
	k.rrect(R.grow(-1.5), 3.5, rail)
	var cush := R.grow(-5.0)
	k.rect(cush, Pal.FELT.darkened(0.25))
	var felt := R.grow(-7.5)
	k.rect(felt, Pal.FELT)
	k.grad(Rect2(felt.position, Vector2(felt.size.x, felt.size.y * 0.5)), Color(1, 1, 1, 0.05), Color(1, 1, 1, 0.0))
	# diamonds on the rails
	for j in 3:
		var x := R.position.x + R.size.x * (j + 1) / 4.0
		k.disc(Vector2(x, R.position.y + 2.5), 0.9, Pal.AWNING_CREAM)
		k.disc(Vector2(x, R.end.y - 2.5), 0.9, Pal.AWNING_CREAM)
	k.disc(Vector2(R.position.x + 2.5, 0), 0.9, Pal.AWNING_CREAM)
	k.disc(Vector2(R.end.x - 2.5, 0), 0.9, Pal.AWNING_CREAM)
	# the six pockets
	var pk := [felt.position, Vector2(0, felt.position.y), Vector2(felt.end.x, felt.position.y), Vector2(felt.position.x, felt.end.y), Vector2(0, felt.end.y), felt.end]
	for p in pk:
		k.disc(p, 3.8, Pal.SIGN_BLACK)
		k.ring(p, 3.8, Pal.LEATHER.darkened(0.2), 1.0)
	# the head spot and a game: racked or scattered
	var cols := [Pal.GOLD, Pal.AWNING_COLORS[2].lightened(0.25), Pal.FLOOR_TILE_2.lightened(0.15), Pal.AWNING_COLORS[4].lightened(0.2),
		Pal.RUST.lightened(0.25), Pal.AWNING_COLORS[1].lightened(0.25), Pal.LEATHER.lightened(0.1), Pal.SIGN_BLACK.lightened(0.05)]
	var br := 2.1
	var along_x := felt.size.x >= felt.size.y
	if sd % 3 == 0:
		# racked
		var apex := Vector2(felt.size.x * 0.22, 0) if along_x else Vector2(0, felt.size.y * 0.22)
		var dir := Vector2(1, 0) if along_x else Vector2(0, 1)
		var nrm := Vector2(0, 1) if along_x else Vector2(1, 0)
		var idx := 0
		for row in 5:
			for q in row + 1:
				var p2: Vector2 = apex + dir * row * br * 1.75 + nrm * (q - row * 0.5) * br * 2.02
				G.ball(k, p2, br, cols[idx % 8], idx >= 8)
				idx += 1
		G.ball(k, -dir * felt.size.x * 0.28 if along_x else -dir * felt.size.y * 0.28, br, Pal.AWNING_CREAM.lightened(0.2), false)
	else:
		for j in 9:
			var p3 := felt.position + Vector2(k.h(j, 1, sd), k.h(j, 2, sd)) * (felt.size - Vector2(8, 8)) + Vector2(4, 4)
			G.ball(k, p3, br, cols[(j * 3) % 8], j % 3 == 1)
		var cue := felt.position + Vector2(k.h(21, 1, sd), k.h(21, 2, sd)) * (felt.size - Vector2(8, 8)) + Vector2(4, 4)
		G.ball(k, cue, br, Pal.AWNING_CREAM.lightened(0.2), false)
		# a cue lying across the table
		if sd % 2 == 0:
			var a := cue + Vector2(4, 2)
			k.line(a + k.sh * 3.0, a + Vector2(46, 16) + k.sh * 3.0, Color(Kit.SH_COL, 0.3), 2.0)
			k.line(a, a + Vector2(46, 16), Pal.FLOOR_WOOD.lightened(0.35), 1.8)
			k.line(a + Vector2(30, 10.4), a + Vector2(46, 16), Pal.COUNTER.darkened(0.2), 2.4)


static func _piano(k: Kit, R: Rect2) -> void:
	var body := Rect2(R.position, Vector2(R.size.x, R.size.y * 0.7))
	k.top(body, Pal.SIGN_BLACK.lightened(0.12), 2.0)
	k.line(body.position + Vector2(3, 3), Vector2(body.end.x - 3, body.position.y + 3), Color(1, 1, 1, 0.18), 1.0)
	var keys := Rect2(R.position.x + 3, body.end.y, R.size.x - 6, R.size.y * 0.3 - 1)
	k.rect(keys, Pal.AWNING_CREAM.lightened(0.15))
	var n := int(keys.size.x / 3.0)
	for j in n:
		var x := keys.position.x + j * 3.0
		k.line(Vector2(x, keys.position.y), Vector2(x, keys.end.y), Pal.AWNING_CREAM.darkened(0.2), 1.0)
		if j % 7 not in [2, 6]:
			k.rect(Rect2(x + 1.8, keys.position.y, 1.8, keys.size.y * 0.6), Pal.SIGN_BLACK)
	# sheet music and a vase of flowers on top, the stool in front
	G.paper(k, Rect2(Vector2(-10, body.get_center().y - 5), Vector2(20, 9)), 0.0, 3)
	k.ball(Vector2(body.end.x - 10, body.get_center().y), 3.5, Pal.GLASS, 3.0)
	for j in 4:
		k.disc(Vector2(body.end.x - 10, body.get_center().y) + Vector2.from_angle(j * 1.6) * 2.5, 1.6, Pal.FLOOR_TILE_2.lightened(0.3))
	var st := Rect2(Vector2(-10, R.end.y + 3), Vector2(20, 9))
	k.shadow(st, 3.0)
	k.rrect(st, 2.0, Pal.LEATHER.lightened(0.05))


static func _phonograph(k: Kit, R: Rect2) -> void:
	var s := minf(R.size.x, R.size.y)
	var cab := Rect2(-s * 0.45, -s * 0.45, s * 0.9, s * 0.9)
	k.top(cab, MAHOG, 2.0)
	k.disc(Vector2(-s * 0.08, s * 0.08), s * 0.3, Pal.SIGN_BLACK.lightened(0.05))
	k.ring(Vector2(-s * 0.08, s * 0.08), s * 0.2, Pal.SIGN_BLACK.lightened(0.2), 1.0)
	k.disc(Vector2(-s * 0.08, s * 0.08), s * 0.07, Pal.FLOOR_TILE_2)
	# the brass horn, its bell toward the room
	var base := Vector2(s * 0.22, -s * 0.22)
	k.line(base, base + Vector2(-s * 0.05, s * 0.25), Pal.BRASS.darkened(0.2), 2.0)
	k.shadow_disc(base + Vector2(-s * 0.1, s * 0.3), s * 0.28, 10.0)
	k.disc(base + Vector2(-s * 0.1, s * 0.3), s * 0.28, Pal.BRASS.darkened(0.15))
	k.disc(base + Vector2(-s * 0.1, s * 0.3), s * 0.2, Pal.BRASS.lightened(0.1))
	k.disc(base + Vector2(-s * 0.1, s * 0.3), s * 0.06, Pal.BRASS.darkened(0.4))


# ------------------------------------------------------------------ the precinct, the quay

static func _cell(k: Kit, R: Rect2, sd: int) -> void:
	k.rect(R, Color(Pal.SIGN_BLACK, 0.1))
	k.disc(Vector2(R.size.x * 0.05, R.size.y * 0.1), 3.0, IRON)
	k.ring(Vector2(R.size.x * 0.05, R.size.y * 0.1), 3.0, IRON.lightened(0.2), 1.0)
	# scratched tally marks and a stain
	for j in 5:
		k.line(Vector2(-R.size.x * 0.4 + j * 2.5, -R.size.y * 0.42), Vector2(-R.size.x * 0.4 + j * 2.5, -R.size.y * 0.36), Color(1, 1, 1, 0.25), 1.0)
	k.ellipse(Vector2(-R.size.x * 0.15, R.size.y * 0.2), Vector2(10, 6), Color(Pal.RUST, 0.12), 0.3)
	var _unused := sd


static func _elevator(k: Kit, R: Rect2, sd: int) -> void:
	# a steel platform in a mesh cage, the gate folded open toward the floor (+y)
	var pl := R.grow(-5.0)
	k.rect(pl, STEEL.darkened(0.15))
	var segs := PackedVector2Array()
	var x := pl.position.x + 4.0
	while x < pl.end.x:
		var y := pl.position.y + 4.0
		while y < pl.end.y:
			segs.append_array([Vector2(x - 2, y - 1), Vector2(x + 2, y + 1)])
			y += 7.0
		x += 7.0
	k.lines(segs, STEEL.lightened(0.15), 1.0)
	k.ci.draw_rect(pl, Pal.GOLD.darkened(0.25), false, 3.0)
	# the cage
	var iron := IRON.lightened(0.1)
	k.ci.draw_rect(R.grow(-1.5), iron, false, 3.0)
	var mesh := PackedVector2Array()
	var t := 0.0
	while t < R.size.x:
		mesh.append_array([Vector2(R.position.x + t, R.position.y + 0.5), Vector2(R.position.x + t, R.position.y + 3.5)])
		t += 4.0
	t = 0.0
	while t < R.size.y:
		mesh.append_array([Vector2(R.position.x + 0.5, R.position.y + t), Vector2(R.position.x + 3.5, R.position.y + t)])
		mesh.append_array([Vector2(R.end.x - 0.5, R.position.y + t), Vector2(R.end.x - 3.5, R.position.y + t)])
		t += 4.0
	k.lines(mesh, iron.lightened(0.25), 1.0)
	# gate folded at the front, cables and the lever
	for j in 6:
		k.line(Vector2(R.position.x + 4 + j * 3.0, R.end.y - 1), Vector2(R.position.x + 4 + j * 3.0, R.end.y - 7), iron.lightened(0.2), 1.5)
	k.disc(Vector2(0, 0), 3.0, IRON)
	k.disc(Vector2(-6, -3), 1.5, STEEL.lightened(0.4))
	k.disc(Vector2(6, -3), 1.5, STEEL.lightened(0.4))
	k.rect(Rect2(R.end.x - 12, R.end.y - 16, 7, 7), Pal.FLOOR_TILE_2)
	k.line(Vector2(R.end.x - 8.5, R.end.y - 12.5), Vector2(R.end.x - 8.5, R.end.y - 20), STEEL.lightened(0.3), 2.0)
	k.text_on(Vector2(0, R.size.y * 0.18), "2 TONS", 9, Pal.GOLD.darkened(0.15), "cond")
	var _unused := sd


static func _crate(k: Kit, r: Rect2, sd: int, booze: bool) -> void:
	var wood := Pal.PLANKS.lightened(0.2 + 0.08 * Draw.hash01(sd, 3))
	k.rect(r, wood)
	k.edges(r, wood, 1.5, 0.2, 0.3)
	var n := maxi(2, int(r.size.x / 6.0))
	var segs := PackedVector2Array()
	for j in range(1, n):
		var x := r.position.x + j * r.size.x / n
		segs.append_array([Vector2(x, r.position.y + 1), Vector2(x, r.end.y - 1)])
	k.lines(segs, wood.darkened(0.3), 1.0)
	k.line(r.position + Vector2(1.5, 1.5), r.end - Vector2(1.5, 1.5), wood.darkened(0.2), 1.5)
	if booze:
		for j in 2:
			for i in 2:
				k.disc(r.position + Vector2((i + 0.5) * r.size.x / 2, (j + 0.5) * r.size.y / 2), minf(r.size.x, r.size.y) * 0.16, Pal.FELT.darkened(0.2))


static func _crates(k: Kit, R: Rect2, art: String, sd: int) -> void:
	match art:
		"trunk":
			k.top(R, Pal.LEATHER.lightened(0.1), 2.0)
			for j in 2:
				k.rect(Rect2(R.position.x + R.size.x * (0.25 + j * 0.45), R.position.y, 3, R.size.y), Pal.BRASS.darkened(0.2))
			return
		"dummy_box", "cloth_bales":
			for j in 2:
				var b := Rect2(R.position.x + 1, R.position.y + 1 + j * R.size.y * 0.5, R.size.x - 2, R.size.y * 0.5 - 2)
				G.bolt(k, b, G.CLOTHS[(j + sd) % G.CLOTHS.size()], true)
			return
		"shoe_boxes":
			for j in 3:
				for i in 2:
					G.box(k, Rect2(R.position.x + 1 + i * R.size.x * 0.5, R.position.y + 1 + j * R.size.y / 3.0, R.size.x * 0.5 - 2, R.size.y / 3.0 - 2), [Pal.AWNING_CREAM.darkened(0.1), Pal.ROPE, Pal.AWNING_COLORS[2].lightened(0.3)][(i + j) % 3])
			return
	# stacks of crates of a few heights, stencilled
	var cols := maxi(1, int(round(R.size.x / (0.7 * M))))
	var rows := maxi(1, int(round(R.size.y / (0.7 * M))))
	var cw := R.size.x / cols
	var ch := R.size.y / rows
	for j in rows:
		for i in cols:
			var r := Rect2(R.position.x + i * cw + 1, R.position.y + j * ch + 1, cw - 2, ch - 2)
			var tall := k.h(i, j, sd) > 0.5
			if tall:
				k.shadow(r, 7.0, 0.25)
			match art:
				"produce_crates":
					k.rect(r, Pal.PLANKS.lightened(0.18))
					G.pile(k, r.grow(-2.0), ["apple", "orange", "onion", "cabbage"][(i + j + sd) % 4], sd + i + j * 5)
					k.ci.draw_rect(r, Pal.PLANKS.darkened(0.2), false, 1.5)
				"fish_boxes":
					k.rect(r, Pal.PLANKS.lightened(0.1))
					k.rect(r.grow(-2.0), ICE)
					for q in 3:
						G.fish(k, r.position + Vector2(r.size.x * 0.5, (q + 0.5) * r.size.y / 3.0), r.size.x * 0.8, PI * (q % 2), G.SILVER)
				"gun_crates":
					_crate(k, r, sd + i + j, false)
					if (i + j) % 2 == 0:
						k.rect(r.grow(-2.5), Pal.PLANKS.darkened(0.25))
						for q in 3:
							G.gun(k, r.get_center() + Vector2(0, (q - 1) * r.size.y * 0.25), r.size.x * 0.85, 0.0, false)
				_:
					_crate(k, r, sd + i * 3 + j, false)
					if tall:
						k.text_on(r.get_center(), ["MACHINE PARTS", "CANNED GOODS", "HAVANA", "TEA"][(i + j + sd) % 4].substr(0, 6), 7, Color(Pal.SIGN_BLACK, 0.55), "cond")


static func _barrel(k: Kit, R: Rect2, sd: int, art: String) -> void:
	var r := minf(R.size.x, R.size.y) * 0.46
	var col := Pal.PLANKS.lightened(0.15)
	if art == "kerosene":
		col = Pal.FLOOR_TILE_2.darkened(0.1)
	k.disc(Vector2.ZERO, r, col.darkened(0.25))
	k.disc(k.lit * 0.8, r * 0.9, col)
	k.ring(Vector2.ZERO, r * 0.95, IRON.lightened(0.2), 2.0)
	k.ring(Vector2.ZERO, r * 0.7, IRON.lightened(0.15), 1.5)
	match art:
		"bone_barrel":
			for j in 5:
				k.line(Vector2.from_angle(j * 1.3) * r * 0.2, Vector2.from_angle(j * 1.3 + 0.5) * r * 0.6, G.FAT, 2.5)
		"sugar_barrel":
			k.disc(Vector2.ZERO, r * 0.62, Pal.AWNING_CREAM.lightened(0.2))
			k.disc(Vector2(2, 1), r * 0.15, STEEL.lightened(0.4))
		"table":
			k.disc(Vector2.ZERO, r * 0.62, col.lightened(0.08))
			G.glass_cup(k, Vector2(-r * 0.3, -r * 0.2), 2.4, Color(Pal.GOLD, 0.8))
			G.bottle(k, Vector2(r * 0.3, r * 0.1), 2.8, G.BOTTLES[sd % G.BOTTLES.size()])
		"kerosene":
			k.disc(Vector2(r * 0.4, 0), 1.8, IRON)
			k.text_on(Vector2(-r * 0.1, 0), "OIL", 7, Pal.AWNING_CREAM, "cond")
		_:
			var segs := PackedVector2Array()
			for j in 4:
				var x := -r * 0.6 + j * r * 0.4
				segs.append_array([Vector2(x, -r * 0.6), Vector2(x, r * 0.6)])
			k.lines(segs, col.darkened(0.3), 1.0)


static func _barrel_stack(k: Kit, R: Rect2, sd: int) -> void:
	var r := minf(R.size.x, 0.62 * M) * 0.48
	var cols := maxi(1, int(R.size.x / (r * 2.1)))
	var rows := maxi(1, int(R.size.y / (r * 2.1)))
	for j in rows:
		for i in cols:
			var c := R.position + Vector2((i + 0.5) * R.size.x / cols, (j + 0.5) * R.size.y / rows)
			k.shadow_disc(c, r, 6.0)
			k.frame(k.org + c.rotated(k.ang), k.ang)
			_barrel(k, Rect2(-Vector2(r, r) / 0.46 * 0.5, Vector2(r, r) / 0.46), sd + i + j, "barrel")
			k.frame(k.org - c.rotated(k.ang), k.ang)


static func _barrel_row(k: Kit, R: Rect2, sd: int, art: String) -> void:
	var n := maxi(1, int(R.size.y / (0.6 * M)))
	var fills := ["pickles", "crackers", "flour"] if art == "barrels" else ["nails", "nails", "shovels"]
	for j in n:
		var c := Vector2(0, R.position.y + (j + 0.5) * R.size.y / n)
		var r := minf(R.size.x, R.size.y / n) * 0.46
		k.ball(c, r, Pal.PLANKS.lightened(0.15), 6.0, 0.0)
		k.ring(c, r * 0.92, IRON.lightened(0.2), 2.0)
		var f: String = fills[(j + sd) % fills.size()]
		match f:
			"pickles":
				k.disc(c, r * 0.72, Pal.FELT.lightened(0.15))
				for q in 6:
					k.ellipse(c + Vector2.from_angle(q * 1.1) * r * 0.4, Vector2(3.0, 1.6), Pal.FELT.lightened(0.35), q * 1.1)
			"crackers":
				k.disc(c, r * 0.72, Pal.ROPE.lightened(0.1))
				for q in 7:
					k.disc(c + Vector2.from_angle(q * 0.9) * r * 0.45, 2.2, Pal.AWNING_CREAM.darkened(0.05))
			"flour":
				k.disc(c, r * 0.72, Pal.AWNING_CREAM.lightened(0.2))
				k.ellipse(c + Vector2(2, 0), Vector2(r * 0.3, r * 0.2), STEEL.lightened(0.4))
			"nails":
				k.disc(c, r * 0.72, STEEL.lightened(0.05))
				G.pile(k, Rect2(c - Vector2(r, r) * 0.5, Vector2(r, r)), "nail", sd + j)
			_:
				k.disc(c, r * 0.72, Pal.PLANKS.darkened(0.2))
				for q in 4:
					k.line(c, c + Vector2.from_angle(q * 1.5 + 0.3) * r * 1.3, Pal.FLOOR_WOOD.lightened(0.3), 2.0)


static func _sack_pile(k: Kit, R: Rect2, sd: int, art: String) -> void:
	var col := Pal.ROPE.darkened(0.12)
	if art == "flour_sacks":
		col = Pal.AWNING_CREAM.darkened(0.08)
	elif art == "coffee_sacks":
		col = Pal.ROPE.darkened(0.25)
	var n := maxi(1, int(R.size.x / 22.0))
	for j in n:
		var c := Vector2(R.position.x + (j + 0.5) * R.size.x / n, (k.h(j, 1, sd) - 0.5) * 4.0)
		G.sack(k, c, Vector2(R.size.x / n - 1.0, R.size.y - 2), (k.h(j, 2, sd) - 0.5) * 0.25, col.darkened(0.06 * (j % 2)))
		if art == "flour_sacks":
			k.text_on(c, "FLOUR", 6, Color(Pal.AWNING_COLORS[2], 0.7), "cond")


# ------------------------------------------------------------------ the trades' own fixtures

static func _oven(k: Kit, R: Rect2, sd: int, night: float) -> void:
	# a brick oven along the wall: the crown, two iron doors toward the room, a peel
	k.rect(R, Pal.BRICK.darkened(0.15))
	var segs := PackedVector2Array()
	var y := R.position.y + 3.0
	var row := 0
	while y < R.end.y:
		segs.append_array([Vector2(R.position.x, y), Vector2(R.end.x, y)])
		var x := R.position.x + (5.0 if row % 2 == 0 else 0.0)
		while x < R.end.x:
			segs.append_array([Vector2(x, y), Vector2(x, y + 5.0)])
			x += 10.0
		y += 5.0
		row += 1
	k.lines(segs, Pal.BRICK_DARK.darkened(0.2), 1.0)
	var crown := Rect2(R.position.x + R.size.x * 0.12, R.position.y + R.size.y * 0.12, R.size.x * 0.76, R.size.y * 0.55)
	k.rrect(crown, crown.size.y * 0.45, Pal.BRICK.lightened(0.05))
	k.rrect(crown.grow(-4.0), crown.size.y * 0.4, Pal.BRICK_DARK)
	k.disc(Vector2(0, crown.get_center().y), 6.0, IRON)
	k.disc(Vector2(0, crown.get_center().y), 3.5, IRON.lightened(0.2))
	for sgn: float in [-1.0, 1.0]:
		var d := Rect2(Vector2(sgn * R.size.x * 0.2 - 10, R.end.y - 10), Vector2(20, 9))
		k.rect(d, IRON)
		k.rect(d.grow(-2.0), IRON.lightened(0.12))
		k.line(Vector2(d.position.x + 3, d.position.y + 1), Vector2(d.end.x - 3, d.position.y + 1), Color(Pal.LAMP, 0.35 + night * 0.5), 1.5)
		k.line(Vector2(d.get_center().x - 5, d.end.y + 1), Vector2(d.get_center().x + 5, d.end.y + 1), STEEL.lightened(0.3), 1.5)
	# the peel leaning on the side, a heap of coal
	var pe := Vector2(R.end.x - 8, R.position.y + 6)
	k.line(pe, pe + Vector2(0, R.size.y * 0.6), OAK, 2.0)
	k.rrect(Rect2(pe + Vector2(-5, R.size.y * 0.6), Vector2(10, 12)), 3.0, OAK.lightened(0.1))
	for j in 7:
		k.disc(Vector2(R.position.x + 8 + k.h(j, 1, sd) * 12.0, R.end.y - 4 - k.h(j, 2, sd) * 6.0), 2.0, Pal.SIGN_BLACK.lightened(0.1))


static func _cold_room(k: Kit, R: Rect2, sd: int) -> void:
	# a walk-in cooler: thick oak walls, sawdust, sides of beef on the rail
	var wall := OAK.darkened(0.05)
	k.rect(R, wall)
	var inner := R.grow(-5.0)
	k.rect(inner, Pal.FLOOR_TILE.lightened(0.18))
	var dust := PackedVector2Array()
	for j in 60:
		var p := inner.position + Vector2(k.h(j, 1, sd), k.h(j, 2, sd)) * inner.size
		dust.append_array([p, p + Vector2(1.2, 0.6)])
	k.lines(dust, Pal.ROPE, 1.0)
	k.line(Vector2(inner.position.x + 4, inner.get_center().y), Vector2(inner.end.x - 4, inner.get_center().y), STEEL.lightened(0.3), 2.0)
	var n := maxi(1, int(inner.size.x / 26.0))
	for j in n:
		G.beef_side(k, Vector2(inner.position.x + (j + 0.5) * inner.size.x / n, inner.get_center().y), inner.size.y * 0.8, minf(20.0, inner.size.x / n - 3.0))
	# the heavy door, latch and hinges on the front
	var d := Rect2(Vector2(inner.size.x * 0.05 - 14, R.end.y - 5), Vector2(28, 5))
	k.rect(d, wall.lightened(0.12))
	k.rect(Rect2(d.end.x - 6, d.position.y + 1, 5, 3), STEEL.lightened(0.4))
	k.edges(R, wall, 2.0)


static func _icebox(k: Kit, R: Rect2) -> void:
	k.top(R, OAK, 2.0)
	k.ci.draw_rect(R.grow(-3.0), OAK.darkened(0.2), false, 1.0)
	k.line(Vector2(R.position.x + 3, 0), Vector2(R.end.x - 3, 0), OAK.darkened(0.25), 1.0)
	for sgn: float in [-1.0, 1.0]:
		k.rect(Rect2(Vector2(R.size.x * 0.25 - 3, sgn * R.size.y * 0.25 - 1), Vector2(6, 3)), Pal.BRASS)
	k.rect(Rect2(R.position.x + 2, R.end.y - 4, R.size.x - 4, 2), Pal.BRASS.darkened(0.2))


static func _ice_chests(k: Kit, R: Rect2, sd: int) -> void:
	k.rect(R, ZINC.darkened(0.25))
	var n := maxi(1, int(R.size.y / 24.0))
	for j in n:
		var r := Rect2(R.position.x + 3, R.position.y + 3 + j * (R.size.y - 6) / n, R.size.x - 6, (R.size.y - 6) / n - 3)
		if j % 2 == 0:
			k.rect(r, ICE.darkened(0.08))
			for q in 3:
				k.rect(Rect2(r.position.x + 2 + q * r.size.x / 3.0, r.position.y + 2, r.size.x / 3.0 - 3, r.size.y - 4), ICE.lightened(0.1))
		else:
			k.rect(r, ICE)
			for q in 4:
				G.fish(k, r.position + Vector2(r.size.x * 0.5, (q + 0.5) * r.size.y / 4.0), r.size.x * 0.7, PI * (q % 2), G.SILVER)
	k.edges(R, ZINC, 1.5)
	var _unused := sd


static func _chop_block(k: Kit, R: Rect2, sd: int) -> void:
	var r := minf(R.size.x, R.size.y) * 0.47
	k.disc(Vector2.ZERO, r, OAK.darkened(0.15))
	k.disc(k.lit * 0.6, r * 0.9, OAK.lightened(0.1))
	for j in 4:
		k.ring(Vector2(1, 1), r * (0.2 + j * 0.18), Color(OAK.darkened(0.3), 0.5), 1.0)
	for j in 5:
		var a := k.h(j, 1, sd) * TAU
		k.line(Vector2.from_angle(a) * r * 0.1, Vector2.from_angle(a + 0.3) * r * 0.8, Color(OAK.darkened(0.4), 0.5), 1.0)
	_cleaver(k, Vector2(-r * 0.3, -r * 0.1), 0.5)
	k.ellipse(Vector2(r * 0.25, r * 0.3), Vector2(4, 2.5), Color(Pal.FLOOR_TILE_2, 0.35))


static func _bench_top(k: Kit, R: Rect2, art: String, sd: int) -> void:
	var top := OAK
	match art:
		"marble_slab": top = Pal.MARBLE
		"gutting_table", "lab_bench": top = ZINC
		"numbers_desk", "slip_table": top = WOOD
		"gun_table": top = Pal.PLANKS.lightened(0.05)
	k.top(R, top, 2.0)
	if top == OAK or top == WOOD:
		k.grain(R.grow(-2), top.darkened(0.3), true, 0, sd)
	var c := Vector2.ZERO
	var w := R.size.x
	var d := R.size.y
	match art:
		"saw_bench":
			k.rrect(Rect2(Vector2(-w * 0.35, -d * 0.3), Vector2(w * 0.3, d * 0.6)), 3.0, Pal.AWNING_CREAM.darkened(0.1))
			k.disc(Vector2(-w * 0.2, 0), d * 0.18, IRON)
			k.line(Vector2(-w * 0.2, -d * 0.3), Vector2(-w * 0.2, d * 0.3), STEEL.lightened(0.4), 1.5)
			G.steak(k, Vector2(w * 0.15, 0), 12.0, 0.2, 0.5)
			_cleaver(k, Vector2(w * 0.3, -d * 0.1), 1.2)
		"gutting_table":
			for j in 3:
				G.fish(k, Vector2(-w * 0.25 + j * w * 0.25, 0), minf(d * 0.9, 24.0), PI * 0.5 * (1 + j % 2 * 2), G.SILVER)
			k.line(Vector2(w * 0.35, -d * 0.2), Vector2(w * 0.35, d * 0.2), STEEL.lightened(0.4), 2.0)
			k.ellipse(Vector2(w * 0.1, d * 0.2), Vector2(6, 3), Color(Pal.FLOOR_TILE_2, 0.3))
		"lab_bench":
			k.ball(Vector2(-w * 0.3, 0), 5.0, Pal.MARBLE, 4.0, 0.2)
			k.line(Vector2(-w * 0.3, 0), Vector2(-w * 0.3 + 7, -5), Pal.MARBLE.darkened(0.2), 2.0)
			for j in 4:
				G.bottle(k, Vector2(-w * 0.05 + j * 7.0, -d * 0.2 + (j % 2) * 5.0), 2.6, [Pal.AWNING_COLORS[2].lightened(0.3), Pal.RUST, Pal.GLASS, Pal.FELT][j])
			_scale(k, Vector2(w * 0.32, 0), 0.8)
		"stitcher", "sewing_bench":
			var n := 1 if art == "stitcher" else maxi(1, int(w / 36.0))
			for j in n:
				var mc := Vector2(-w * 0.5 + (j + 0.5) * w / n, -d * 0.05)
				k.rrect(Rect2(mc + Vector2(-9, -5) + k.sh * 3.0, Vector2(18, 10)), 3.0, Color(Kit.SH_COL, 0.3))
				k.rrect(Rect2(mc + Vector2(-9, -5), Vector2(18, 10)), 3.0, Pal.SIGN_BLACK.lightened(0.12))
				k.line(mc + Vector2(-6, -3), mc + Vector2(5, -3), Pal.SIGN_GOLD, 1.0)
				k.disc(mc + Vector2(8, 0), 2.5, STEEL.lightened(0.3))
				k.rect(Rect2(mc + Vector2(-12, 5), Vector2(10, 6)), G.CLOTHS[(j + sd) % G.CLOTHS.size()])
				k.disc(mc + Vector2(12, 6), 2.0, G.BRIGHTS[j % G.BRIGHTS.size()])
		"prep_table":
			k.rect(Rect2(Vector2(-w * 0.35, -d * 0.3), Vector2(w * 0.45, d * 0.6)), OAK.lightened(0.15))
			G.fruit(k, Vector2(w * 0.2, -d * 0.15), 3.2, Pal.NEON_RED.darkened(0.3))
			G.fruit(k, Vector2(w * 0.28, d * 0.12), 3.0, Pal.AWNING_CREAM)
			G.cabbage(k, Vector2(-w * 0.15, 0), 4.5)
			k.line(Vector2(-w * 0.05, d * 0.25), Vector2(w * 0.2, d * 0.3), STEEL.lightened(0.4), 1.5)
		"marble_slab":
			for j in 3:
				k.rrect(Rect2(Vector2(-w * 0.35, -d * 0.3 + j * d * 0.22), Vector2(w * 0.7, d * 0.14)), 2.0, G.BRIGHTS[(j + sd) % G.BRIGHTS.size()])
		"slip_table", "numbers_desk":
			for j in (4 if art == "slip_table" else 10):
				G.paper(k, Rect2(Vector2(-w * 0.4 + k.h(j, 1, sd) * w * 0.7, -d * 0.35 + k.h(j, 2, sd) * d * 0.6), Vector2(7, 9)), (k.h(j, 3, sd) - 0.5) * 1.2, 2)
			var nm := 1 if art == "slip_table" else maxi(1, int(d / 34.0))
			for j in nm:
				var ac := Vector2(-w * 0.1, -d * 0.5 + (j + 0.5) * d / nm)
				k.rrect(Rect2(ac + Vector2(-7, -6) + k.sh * 3.0, Vector2(14, 12)), 2.0, Color(Kit.SH_COL, 0.3))
				k.rrect(Rect2(ac + Vector2(-7, -6), Vector2(14, 12)), 2.0, IRON)
				for q in 9:
					k.disc(ac + Vector2(-4 + (q % 3) * 4.0, -3 + (q / 3) * 3.0), 0.9, Pal.AWNING_CREAM)
				k.rect(Rect2(ac + Vector2(7, -3), Vector2(4, 1.5)), STEEL.lightened(0.3))
			if art == "numbers_desk":
				_phone(k, Vector2(w * 0.25, -d * 0.3), 0.9)
				G.cigarbox(k, Rect2(Vector2(w * 0.1, d * 0.2), Vector2(14, 10)), false, 0.3)
				for q in 3:
					G.cash(k, Vector2(w * 0.25 + q * 2.0, d * 0.05 + q * 2.5), 0.2)
		"cobbler_bench":
			for j in 3:
				var lc := Vector2(-w * 0.2 + j * w * 0.2, -d * 0.1)
				G.shoe(k, lc, 11.0, PI * 0.5 + j * 0.3, [Pal.LEATHER, Pal.SIGN_BLACK.lightened(0.15), Pal.RUST][j])
			k.line(Vector2(w * 0.3, -d * 0.25), Vector2(w * 0.3, d * 0.05), OAK.darkened(0.4), 2.0)
			k.rect(Rect2(Vector2(w * 0.27, -d * 0.3), Vector2(7, 4)), STEEL.lightened(0.2))
			for q in 8:
				k.disc(Vector2(w * 0.1 + k.h(q, 1, sd) * w * 0.3, d * 0.2 + k.h(q, 2, sd) * d * 0.2), 0.8, STEEL.lightened(0.3))
			k.rrect(Rect2(Vector2(-w * 0.45, d * 0.1), Vector2(w * 0.3, d * 0.3)), 3.0, Pal.LEATHER.lightened(0.15))
		"folding_table":
			var n2 := maxi(1, int(d / 22.0))
			for j in n2:
				for i in 2:
					var fr := Rect2(Vector2(-w * 0.4 + i * w * 0.45, -d * 0.5 + 3 + j * d / n2), Vector2(w * 0.35, d / n2 - 5))
					for q in 3:
						G.towel(k, Rect2(fr.position - Vector2(q, q) * 0.8, fr.size))
		"gun_table":
			G.gun(k, Vector2(0, -d * 0.3), minf(w * 0.8, 44.0), 0.0, false)
			G.gun(k, Vector2(0, -d * 0.1), minf(w * 0.8, 44.0), PI, false)
			G.gun(k, Vector2(-w * 0.05, d * 0.12), minf(w * 0.6, 34.0), 0.0, true)
			for j in 3:
				G.pistol(k, Vector2(-w * 0.3 + j * 12.0, d * 0.32), 0.3 * j)
			for j in 2:
				G.box(k, Rect2(Vector2(w * 0.2 + j * 10.0, d * 0.25), Vector2(8, 6)), Pal.FELT.darkened(0.1))
	var _u := c


static func _washtubs(k: Kit, R: Rect2, sd: int) -> void:
	var n := maxi(1, int(R.size.y / (0.95 * M)))
	for j in n:
		var c := Vector2(0, R.position.y + (j + 0.5) * R.size.y / n)
		var r := minf(R.size.x, R.size.y / n) * 0.44
		k.ball(c, r, STEEL.lightened(0.28), 7.0, 0.0)
		k.disc(c, r * 0.84, Pal.GLASS.lerp(Pal.AWNING_CREAM, 0.4))
		for q in 6:
			k.disc(c + Vector2(k.h(q, j, sd) - 0.5, k.h(j, q, sd) - 0.5) * r, 1.5 + k.h(q, 3, sd) * 2.0, Color(1, 1, 1, 0.7))
		# the washboard leaning in
		var wb := Rect2(c + Vector2(r * 0.2, -r * 0.5), Vector2(r * 0.55, r * 0.9))
		k.rect(wb, OAK)
		var segs := PackedVector2Array()
		var y := wb.position.y + 3
		while y < wb.end.y - 2:
			segs.append_array([Vector2(wb.position.x + 2, y), Vector2(wb.end.x - 2, y)])
			y += 2.0
		k.lines(segs, STEEL.lightened(0.3), 1.0)


static func _mangle(k: Kit, R: Rect2) -> void:
	k.top(R, IRON.lightened(0.05), 2.0)
	for j in 2:
		var y := -R.size.y * 0.12 + j * R.size.y * 0.24
		k.rect(Rect2(R.position.x + 6, y - 4, R.size.x - 12, 8), OAK.lightened(0.15))
		k.line(Vector2(R.position.x + 6, y - 3), Vector2(R.end.x - 6, y - 3), OAK.lightened(0.35), 1.0)
	k.disc(Vector2(R.end.x - 6, 0), 7.0, IRON.lightened(0.15))
	k.ring(Vector2(R.end.x - 6, 0), 5.0, IRON.lightened(0.35), 1.5)
	k.line(Vector2(R.end.x - 6, 0), Vector2(R.end.x - 6, 9), STEEL, 2.0)
	k.rect(Rect2(R.position.x + 6, R.end.y - 7, R.size.x * 0.5, 5), Pal.AWNING_CREAM)


static func _boiler(k: Kit, R: Rect2, copper: bool) -> void:
	var r := minf(R.size.x, R.size.y) * 0.45
	var col := Pal.RUST.lightened(0.3) if copper else STEEL
	k.rect(Rect2(-r - 2, -r - 2, r * 2 + 4, r * 2 + 4), IRON)
	k.disc(Vector2.ZERO, r, col.darkened(0.2))
	k.disc(k.lit, r * 0.86, col)
	k.disc(k.lit * r * 0.4, r * 0.3, col.lightened(0.3))
	k.disc(Vector2.ZERO, r * 0.25, col.darkened(0.3))
	k.line(Vector2(r * 0.6, -r * 0.6), Vector2(r * 1.2, -r * 1.2), STEEL.lightened(0.2), 3.0)
	k.disc(Vector2(-r * 0.9, r * 0.9), 2.5, Pal.FLOOR_TILE_2)


static func _steam_press(k: Kit, R: Rect2) -> void:
	k.top(R, IRON.lightened(0.08), 2.0)
	var board := Rect2(R.position.x + 4, -R.size.y * 0.2, R.size.x - 8, R.size.y * 0.5)
	k.rrect(board, 6.0, Pal.AWNING_CREAM.darkened(0.1))
	k.rrect(board.grow(-3.0), 5.0, Pal.AWNING_CREAM.lightened(0.1))
	k.rect(Rect2(R.position.x + 4, R.position.y + 3, R.size.x - 8, 6), STEEL.lightened(0.2))
	k.line(Vector2(R.end.x - 8, R.position.y + 6), Vector2(R.end.x - 8, R.end.y - 4), STEEL.lightened(0.35), 2.0)
	k.disc(Vector2(R.end.x - 8, R.end.y - 4), 2.5, Pal.SIGN_BLACK)


static func _range(k: Kit, R: Rect2, sd: int) -> void:
	# the cast-iron range: burners, pots and a pan, the hood shelf against the wall
	var hood := Rect2(R.position.x, R.position.y, R.size.x, R.size.y * 0.25)
	var top := Rect2(R.position.x, hood.end.y, R.size.x, R.size.y * 0.62)
	k.top(hood, STEEL.lightened(0.1), 1.5)
	for j in 4:
		G.jar(k, Vector2(hood.position.x + 8 + j * 10.0, hood.get_center().y), 3.0, [Pal.FLOOR_TILE_2, Pal.GOLD, Pal.AWNING_CREAM, Pal.FELT.lightened(0.3)][j])
	k.top(top, IRON.lightened(0.02), 2.0)
	var n := maxi(2, int(top.size.x / 22.0))
	for j in n:
		for q in 2:
			var c := top.position + Vector2((j + 0.5) * top.size.x / n, (q + 0.5) * top.size.y * 0.5)
			k.ring(c, 6.0, IRON.lightened(0.25), 1.5)
			k.ring(c, 3.0, IRON.lightened(0.25), 1.0)
			var t := k.h(j, q, sd)
			if t > 0.45:
				k.ball(c, 7.0 if t > 0.7 else 5.5, STEEL.lightened(0.25) if t > 0.7 else IRON.lightened(0.15), 4.0, 0.2)
				k.disc(c, 4.5 if t > 0.7 else 3.5, Pal.FLOOR_TILE_2.darkened(0.1) if q == 0 else Pal.AWNING_CREAM.darkened(0.2))
	k.rect(Rect2(R.position.x, R.end.y - R.size.y * 0.13, R.size.x, R.size.y * 0.13), STEEL.lightened(0.3))
	k.line(Vector2(R.position.x + 4, R.end.y - 2), Vector2(R.end.x - 4, R.end.y - 2), Pal.BRASS, 1.5)


static func _sink(k: Kit, R: Rect2, dishes: bool, sd: int) -> void:
	k.top(R, ENAMEL, 2.0)
	var b := Rect2(R.position.x + R.size.x * 0.1, R.position.y + 4, R.size.x * (0.5 if dishes else 0.8), R.size.y - 9)
	k.rrect(b, 4.0, ENAMEL.darkened(0.12))
	k.rrect(b.grow(-2.0), 3.0, Pal.GLASS.lerp(ENAMEL, 0.5))
	k.disc(b.get_center(), 1.5, IRON)
	k.line(Vector2(b.get_center().x, R.position.y + 1), Vector2(b.get_center().x, R.position.y + 6), STEEL.lightened(0.4), 2.0)
	if dishes:
		for j in 4:
			G.plate(k, Vector2(R.position.x + R.size.x * 0.75 + (j % 2) * 3.0, R.position.y + 6 + j * 3.0), 5.0)
	var _unused := sd


static func _kettle(k: Kit, R: Rect2, roaster: bool) -> void:
	k.top(R, IRON.lightened(0.06), 2.0)
	var c := Vector2(-R.size.x * 0.12, 0)
	var r := minf(R.size.x, R.size.y) * 0.36
	if roaster:
		k.rrect(Rect2(c - Vector2(r * 1.2, r * 0.8), Vector2(r * 2.4, r * 1.6)), r * 0.7, Pal.RUST.darkened(0.2))
		k.rrect(Rect2(c - Vector2(r * 1.1, r * 0.6), Vector2(r * 2.2, r * 1.2)), r * 0.5, Pal.RUST.lightened(0.05))
		for j in 5:
			k.line(c + Vector2(-r + j * r * 0.5, -r * 0.55), c + Vector2(-r + j * r * 0.5, r * 0.55), Pal.RUST.darkened(0.3), 1.0)
		k.disc(c + Vector2(r * 1.3, 0), 3.5, Pal.BRASS)
	else:
		k.ball(c, r, Pal.RUST.lightened(0.3), 6.0, 0.35)
		k.disc(c, r * 0.72, Pal.FLOOR_TILE_2.lightened(0.35))
		k.line(c, c + Vector2(r * 0.6, -r * 0.5), OAK, 2.0)
	k.rect(Rect2(R.end.x - 12, R.position.y + 3, 8, R.size.y - 6), OAK.darkened(0.1))


static func _potbelly(k: Kit, R: Rect2) -> void:
	var r := minf(R.size.x, R.size.y) * 0.4
	k.rect(Rect2(-r - 3, -r - 3, r * 2 + 6, r * 2 + 6), Pal.QUAY_STONE.darkened(0.2))
	k.disc(Vector2.ZERO, r, IRON)
	k.disc(k.lit, r * 0.82, IRON.lightened(0.08))
	k.disc(Vector2.ZERO, r * 0.4, IRON.lightened(0.2))
	k.disc(Vector2.ZERO, r * 0.25, Pal.SIGN_BLACK)
	k.line(Vector2(r * 0.7, 0), Vector2(r * 1.6, 0), Color(Pal.LAMP, 0.5), 1.0)


static func _laundry_cart(k: Kit, R: Rect2, sd: int, basket: bool) -> void:
	if basket:
		k.rrect(R.grow(-2), 6.0, Pal.ROPE.darkened(0.05))
	else:
		k.rect(R, IRON.lightened(0.1))
		k.rrect(R.grow(-2), 3.0, Pal.ROPE.lerp(Pal.AWNING_CREAM, 0.4))
	var inner := R.grow(-5.0)
	for j in 9:
		var p := inner.position + Vector2(k.h(j, 1, sd), k.h(j, 2, sd)) * inner.size
		k.ellipse(p, Vector2(5.0 + k.h(j, 3, sd) * 4.0, 3.0 + k.h(j, 4, sd) * 2.5), [Pal.AWNING_CREAM.lightened(0.15), Pal.AWNING_COLORS[2].lightened(0.45), Pal.AWNING_CREAM, Pal.FLOOR_TILE_2.lightened(0.45)][j % 4], k.h(j, 5, sd) * PI)


static func _clam_baskets(k: Kit, R: Rect2, sd: int) -> void:
	var n := maxi(1, int(R.size.y / (0.5 * M)))
	for j in n:
		var c := Vector2(0, R.position.y + (j + 0.5) * R.size.y / n)
		var r := minf(R.size.x, R.size.y / n) * 0.46
		k.ball(c, r, Pal.ROPE.darkened(0.1), 5.0, 0.0)
		G.pile(k, Rect2(c - Vector2(r, r) * 0.68, Vector2(r, r) * 1.36), "clam" if j % 2 == 0 else "oyster", sd + j)


static func _tank(k: Kit, R: Rect2, sd: int) -> void:
	k.rect(R, ZINC.darkened(0.3))
	var w := R.grow(-3.0)
	k.rect(w, Pal.WATER.lightened(0.25))
	k.grad(Rect2(w.position, Vector2(w.size.x, w.size.y * 0.4)), Color(1, 1, 1, 0.12), Color(1, 1, 1, 0))
	for j in 3:
		var c := w.position + Vector2(k.h(j, 1, sd), k.h(j, 2, sd)) * w.size * 0.7 + w.size * 0.15
		var col := Pal.RUST.darkened(0.25)
		var a := k.h(j, 3, sd) * TAU
		var d := Vector2.from_angle(a)
		k.ellipse(c, Vector2(6, 3), col, a)
		k.disc(c + d * 6.0 + Vector2(-d.y, d.x) * 3.0, 2.0, col)
		k.disc(c + d * 6.0 - Vector2(-d.y, d.x) * 3.0, 2.0, col)
	k.glass(w, Pal.GLASS, 0.2)


static func _barber_counter(k: Kit, R: Rect2, sd: int) -> void:
	# a marble shelf under the mirrors: basins, tonics, the strop, razors, a shaving mug
	k.rect(R, WOOD_D)
	var t := R.grow(-1.5)
	_marble(k, t, sd)
	k.edges(t, Pal.MARBLE, 1.5)
	var n := maxi(1, int(R.size.x / (1.2 * M)))
	for j in n:
		var x := R.position.x + (j + 0.5) * R.size.x / n
		var b := Rect2(x - 9, -R.size.y * 0.3, 18, R.size.y * 0.6)
		k.rrect(b, 5.0, ENAMEL.darkened(0.12))
		k.rrect(b.grow(-2.0), 4.0, Pal.GLASS.lerp(ENAMEL, 0.6))
		k.disc(b.get_center(), 1.2, STEEL)
		for q in 3:
			G.bottle(k, Vector2(x + 14 + q * 5.0, -R.size.y * 0.15 + (q % 2) * 4.0), 1.9, [Pal.AWNING_COLORS[2].lightened(0.3), Pal.FELT.lightened(0.3), Pal.RUST.lightened(0.2)][q])
		k.disc(Vector2(x - 16, 0), 3.0, Pal.AWNING_CREAM.lightened(0.2))
		k.disc(Vector2(x - 16, 0), 2.0, Pal.AWNING_CREAM.darkened(0.1))
		k.line(Vector2(x + 10, R.size.y * 0.25), Vector2(x + 18, R.size.y * 0.25), STEEL.lightened(0.45), 1.5)


static func _mirror(k: Kit, R: Rect2, br: bool, sd: int, tri: bool) -> void:
	var frame := Pal.SIGN_GOLD.darkened(0.2) if not tri else OAK
	if tri:
		# three panels angled toward the customer
		var pw := R.size.x / 3.0
		for j in 3:
			var a := (j - 1) * 0.35
			var c := Vector2((j - 1) * pw * 0.95, -R.size.y * 0.25 + absf(j - 1) * 5.0)
			k.frame(k.org + c.rotated(k.ang), k.ang + a)
			var pr := Rect2(-pw * 0.5, -3, pw, 6)
			k.rect(pr, frame)
			k.rect(pr.grow(-1.5), Pal.GLASS.lightened(0.25) if not br else Pal.SIGN_BLACK.lightened(0.1))
			k.frame(k.org - c.rotated(k.ang - a) , k.ang - a)
		k.reset()
		return
	k.rect(R, frame)
	var g := R.grow(-1.5)
	k.rect(g, Pal.GLASS.lightened(0.3))
	k.rect(Rect2(g.position.x + g.size.x * 0.2, g.position.y, 2.0, g.size.y), Color(1, 1, 1, 0.5))
	if br:
		k.rect(g, Color(Pal.SIGN_BLACK, 0.25))
		k.cracks(Vector2(0, 0), maxf(R.size.x, R.size.y) * 0.6, sd, Color(1, 1, 1, 0.9))


static func _dummy(k: Kit, R: Rect2, sd: int) -> void:
	# a tailor's dummy in a half-made jacket, the tape measure round its neck
	var r := minf(R.size.x, R.size.y) * 0.42
	k.disc(Vector2(0, r * 0.2), r * 0.4, IRON)
	var col: Color = Pal.SUITS[sd % Pal.SUITS.size()]
	k.ellipse(Vector2.ZERO, Vector2(r, r * 0.55), col.darkened(0.1))
	k.ellipse(k.lit * 0.8, Vector2(r * 0.85, r * 0.45), col)
	k.line(Vector2(0, -r * 0.4), Vector2(0, r * 0.4), col.darkened(0.3), 1.0)
	k.disc(Vector2.ZERO, r * 0.22, Pal.AWNING_CREAM.darkened(0.1))
	k.disc(Vector2.ZERO, r * 0.12, OAK)
	k.ci.draw_arc(Vector2.ZERO, r * 0.3, 0.3, PI - 0.3, 8, Pal.GOLD2, 1.5, true)
	for j in 3:
		k.disc(Vector2(r * 0.6, -r * 0.3 + j * r * 0.3), 0.8, Pal.AWNING_CREAM)


## The display behind the front glass (a ledge with the trade's best goods), from inside.
static func _window_ledge(k: Kit, R: Rect2, art: String, sd: int, br: bool, it: Dictionary) -> void:
	var ledge := float(it.get("ledge", 0.0)) * M
	if ledge < 1.0:
		return
	# the ledge sits at the room side (-y in the object frame is the street... the window faces the
	# street, so +y is the glass). Leave the glass band for the wall pass.
	var gv := float(it.get("glass_v", W.WALL)) * M
	var lr := Rect2(R.position.x, R.position.y, R.size.x, R.size.y - gv)
	k.top(lr, OAK.darkened(0.05), 1.5)
	k.rect(Rect2(lr.position.x, lr.position.y, lr.size.x, 2.0), OAK.darkened(0.35))
	var inner := lr.grow(-3.0)
	var trade := art.replace("window_", "")
	var n := maxi(1, int(inner.size.x / 18.0))
	for j in n:
		var c := Vector2(inner.position.x + (j + 0.5) * inner.size.x / n, inner.get_center().y + ((j % 2) * 3.0 - 1.5))
		if br and k.h(j, 9, sd) > 0.4:
			continue
		match trade:
			"bakery":
				if j % 2 == 0:
					G.cake(k, c, 6.5, [Pal.AWNING_CREAM, Pal.FLOOR_TILE_2.lightened(0.45)][j % 2], false)
				else:
					G.loaf(k, c, 13.0, 7.0, 0.3, 0.4)
			"butcher":
				k.rect(Rect2(c - Vector2(7, 5), Vector2(14, 10)), ENAMEL)
				G.steak(k, c, 10.0, 0.3, 0.4) if j % 2 == 0 else G.ham(k, c, 11.0, 0.5)
			"grocer":
				G.pile(k, Rect2(c - Vector2(8, 6), Vector2(16, 12)), ["apple", "orange", "lemon", "pear"][j % 4], sd + j)
			"tailor":
				if j % 2 == 0:
					_dummy_small(k, c, Pal.SUITS[j % Pal.SUITS.size()])
				else:
					G.bolt(k, Rect2(c - Vector2(7, 4), Vector2(14, 8)), G.CLOTHS[(j + sd) % G.CLOTHS.size()], true)
			"cobbler":
				G.pair(k, c, 10.0, 0.0, [Pal.LEATHER, Pal.SIGN_BLACK.lightened(0.15), Pal.RUST][j % 3])
			"pawnshop":
				match j % 4:
					0: G.clock(k, c, 4.5)
					1: _banjo(k, c)
					2: _trumpet(k, c)
					_: G.pocket_watch(k, c, 3.5)
			"laundry":
				for q in 3:
					G.towel(k, Rect2(c - Vector2(6, 4) - Vector2(q, q) * 0.8, Vector2(12, 8)))
			"candy":
				G.jar(k, c, 5.5, G.BRIGHTS[(j + sd) % G.BRIGHTS.size()])
			"hardware":
				match j % 3:
					0: G.can(k, c, 4.0, Pal.FLOOR_TILE_2)
					1: G.box(k, Rect2(c - Vector2(6, 4), Vector2(12, 8)), Pal.AWNING_COLORS[2].lightened(0.2))
					_: k.ball(c, 4.0, Pal.RUST, 3.0)
			"drugstore":
				k.ball(c, 5.5, [Pal.AWNING_COLORS[2].lightened(0.3), Pal.FLOOR_TILE_2.lightened(0.25), Pal.AWNING_COLORS[1].lightened(0.35)][j % 3], 6.0, 0.45)
			"cigar":
				G.cigarbox(k, Rect2(c - Vector2(7, 5), Vector2(14, 10)), j % 2 == 0, k.h(j, 1, sd))
			"fish":
				k.rect(Rect2(c - Vector2(8, 5), Vector2(16, 10)), ICE)
				G.fish(k, c, 15.0, 0.0, G.SILVER)
			_:
				G.box(k, Rect2(c - Vector2(5, 4), Vector2(10, 8)), G.BRIGHTS[j % G.BRIGHTS.size()])
	if br:
		k.shards(lr, 12, sd)


static func _dummy_small(k: Kit, c: Vector2, col: Color) -> void:
	k.ellipse(c, Vector2(6.5, 3.8), col.darkened(0.1))
	k.ellipse(c + k.lit * 0.5, Vector2(5.5, 3.0), col)
	k.disc(c, 1.5, OAK)
