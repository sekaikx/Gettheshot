extends RefCounted
## Turns a layout item (by its `art`) into 3D props, plus dust sheets (padlocked) and the mess a shakedown leaves.

const MB := preload("res://scripts/world3d/rooms/mb.gd")
const P := preload("res://scripts/world3d/rooms/parts.gd")
const A := preload("res://scripts/world3d/rooms/props_a.gd")
const B := preload("res://scripts/world3d/rooms/props_b.gd")

## Items that stand tall: lowered when they face away from the camera so they don't hide the floor.
const TALL := ["oven", "cold_room", "icebox", "humidor", "file_cabinet", "piano", "suit_rack", "tool_wall",
	"instruments", "proving_rack", "bread_rack", "boiler", "copper_boiler", "steam_press", "news_rack",
	"lobster_tank", "meat_hooks", "tri_mirror", "barber_mirror", "tally_board", "safe", "dummy_box", "crate_stack",
	"barrel_stack", "cue_rack", "icebox_small", "ice_chests", "range", "potbelly"]


static func is_tall(it: Dictionary) -> bool:
	var art := String(it["art"])
	return art in TALL or String(it["type"]) == "shelf" or String(it["type"]) == "rack" or art.ends_with("_shelf") or art.ends_with("backbar")


static func sheet_height(it: Dictionary) -> float:
	var art := String(it["art"])
	match art:
		"oven", "cold_room", "humidor", "boiler", "copper_boiler": return 1.5
		"bread_rack", "suit_rack", "tool_wall", "instruments", "proving_rack", "crate_stack", "barrel_stack": return 1.5
		"piano", "safe", "file_cabinet", "range", "lobster_tank": return 1.05
	match String(it["type"]):
		"shelf", "rack": return 1.6
		"counter", "display", "bar": return 1.0
		"table", "desk", "map_table", "pool_table", "bench": return 0.8
		"crates": return 0.9
	return 0.8


static func sheet(mb: MB, w: float, d: float, h: float, sd: int) -> void:
	var c := Color("dcd4bc")
	mb.box(Vector3(0, h * 0.42, 0), Vector3(w + 0.06, h * 0.84, d + 0.06), c.darkened(0.04 * P.hf(1, 2, sd)), "s")
	mb.box(Vector3(0, h * 0.9, 0), Vector3(w * 0.8, h * 0.2, d * 0.8), c.lightened(0.02), "s")
	mb.box(Vector3(w * 0.5 + 0.02, 0.12, d * 0.2), Vector3(0.06, 0.24, 0.3), c.darkened(0.12), "s")


# ------------------------------------------------------------------ dispatch

## Draw the item in its own frame. `ctx`: {"broken": bool, "closed": bool, "stock": int, "rev": bool, "avoid": Array, "kind": String}
static func draw(mb: MB, it: Dictionary, w: float, d: float, ctx: Dictionary) -> void:
	var art := String(it["art"])
	var type := String(it["type"])
	var sd := int(it.get("seed", 0))
	var br: bool = ctx.get("broken", false)
	var closed: bool = ctx.get("closed", false)
	var rev: bool = ctx.get("rev", false)
	var kind := String(ctx.get("kind", ""))
	if closed and bool(it.get("solid", false)) and art not in ["cell", "elevator"] and type != "window":
		sheet(mb, w, d, sheet_height(it), sd)
		return
	match art:
		# counters
		"wood_counter", "marble_counter", "butcher_counter", "fish_counter", "pawn_counter", "cutting_counter", "tally_desk", "high_desk":
			A.counter(mb, w, d, art, String(it.get("goods", kind)), sd, ctx.get("avoid", []), closed)
		"espresso_bar", "club_bar", "pool_bar", "speak_bar", "crate_bar":
			B.bar_counter(mb, w, d, art, sd, br, int(ctx.get("stock", 0)), closed)
		"soda_fountain": B.soda_fountain(mb, w, d, sd, br)
		"register": A.register(mb, w, d, br, sd)
		"pastry_case", "cake_case", "meat_case", "poultry_case", "watch_case", "jewel_case", "candy_case", "chocolate_case", "cigar_case", "cosmetic_case", "drug_case":
			A.case(mb, w, d, art, sd, br)
		"humidor": A.humidor(mb, w, d, sd, br)
		"fish_ice", "ice_table": A.ice_bed(mb, w, d, art, sd, br)
		"produce_bins": A.bins(mb, w, d, sd, br, ["apple", "orange", "lemon", "cabbage", "potato", "onion", "tomato", "pear"])
		"nail_bins": A.nail_bins(mb, w, d, sd, br)
		"meat_hooks": A.meat_hooks(mb, w, d, sd, br, rev)
		"instruments": A.instruments(mb, w, d, sd, br, rev)
		"tool_wall": A.tool_wall(mb, w, d, sd, br, rev)
		"bread_rack": A.bread_rack(mb, w, d, sd, br)
		"suit_rack": A.suit_rack(mb, w, d, sd, br)
		"news_rack": A.news_rack(mb, w, d, sd, br)
		"cue_rack": A.cue_rack(mb, w, d, sd, br)
		"proving_rack": A.proving_rack(mb, w, d, sd)
		"tally_board": A.tally_board(mb, w, d, sd)
		# tables and seats
		"table_checked": B.table_checked(mb, w, d, sd, closed)
		"table_round": B.table_round(mb, w, d, sd)
		"card_table": B.card_table(mb, w, d, sd, false, closed)
		"club_table": B.card_table(mb, w, d, sd, true, closed)
		"cocktail_table": B.cocktail_table(mb, w, d, sd, closed)
		"barrel_table": B.barrel_table(mb, w, d, sd)
		"bench": B.bench(mb, w, d, false)
		"wait_bench": B.bench(mb, w, d, true)
		"cot": B.cot(mb, w, d, sd)
		"barber_chair": B.barber_chair(mb, w, d)
		"shine_stand": B.shine_stand(mb, w, d)
		# the office
		"boss_desk": B.desk(mb, w, d, "boss", sd)
		"captain_desk": B.desk(mb, w, d, "captain", sd)
		"office_desk": B.desk(mb, w, d, "office", sd)
		"safe", "pawn_safe": B.safe(mb, w, d, sd)
		"map_table": B.map_table(mb, w, d, sd)
		"phone_stand", "phone_stand_small": B.phone_stand(mb, w, d)
		"desk_phone":
			mb.at(Vector3(0, 0.0, 0))
			B.phone(mb, Vector3(0, 0.0, 0), 0.0)
			mb.pop()
		"file_cabinet": B.file_cabinet(mb, w, d)
		"sideboard": B.sideboard(mb, w, d, sd)
		# pool hall, speakeasy, jail, warehouse
		"pool_table": B.pool_table(mb, w, d, sd)
		"piano": B.piano(mb, w, d)
		"phonograph": B.phonograph(mb, w, d)
		"cell": B.cell(mb, w, d, sd)
		"elevator": B.elevator(mb, w, d, sd)
		"crate_stack", "crate_row", "crates", "produce_crates", "gun_crates", "shoe_boxes", "fish_boxes", "cloth_bales", "dummy_box", "trunk":
			B.crates(mb, w, d, art, sd, closed)
		"barrel_stack": B.barrel_stack(mb, w, d, sd)
		"barrel", "bone_barrel", "sugar_barrel", "kerosene": B.barrel(mb, w, d, sd, art)
		"barrels", "hardware_barrels": B.barrel_row(mb, w, d, sd, art)
		"flour_sacks", "potato_sacks", "coffee_sacks": B.sack_pile(mb, w, d, sd, art)
		# the trades' fixtures
		"oven": B.oven(mb, w, d, sd, closed)
		"cold_room": B.cold_room(mb, w, d, sd)
		"icebox", "icebox_small": B.icebox(mb, w, d)
		"ice_chests": B.ice_chests(mb, w, d, sd)
		"chop_block": B.chop_block(mb, w, d, sd)
		"saw_bench", "gutting_table", "lab_bench", "stitcher", "prep_table", "marble_slab", "slip_table", "sewing_bench", "cobbler_bench", "folding_table", "gun_table", "numbers_desk":
			B.bench_top(mb, w, d, art, sd, closed)
		"washtubs": B.washtubs(mb, w, d, sd)
		"mangle": B.mangle(mb, w, d)
		"copper_boiler", "boiler": B.boiler(mb, w, d, art == "copper_boiler")
		"steam_press": B.steam_press(mb, w, d)
		"range": B.range_stove(mb, w, d, sd, closed)
		"kitchen_sink", "wash_basin":
			if art == "wash_basin":
				B.basin(mb, w, d)
			else:
				B.sink(mb, w, d, true, sd)
		"roaster", "candy_kettle": B.kettle(mb, w, d, art == "roaster")
		"potbelly": B.potbelly(mb, w, d)
		"laundry_cart", "laundry_basket": B.laundry_cart(mb, w, d, sd, art == "laundry_basket")
		"clam_baskets": B.clam_baskets(mb, w, d, sd)
		"lobster_tank": B.tank(mb, w, d, sd)
		"barber_counter": B.barber_counter(mb, w, d, sd)
		"barber_mirror": B.mirror(mb, w, d, br, sd, false)
		"tri_mirror": B.mirror(mb, w, d, br, sd, true)
		"dummy": B.dummy(mb, w, d, sd)
		_:
			if type == "window":
				B.window_display(mb, w, d, 0.25, art, sd, float(it.get("ledge", 0.0)))
			elif art in A.SHELF_TRADE:
				A.shelf(mb, w, d, art, sd, br, rev, closed)
			else:
				match type:
					"shelf", "rack": A.shelf(mb, w, d, art, sd, br, rev, closed)
					"counter": A.counter(mb, w, d, "wood_counter", kind, sd, [], closed)
					"table": B.card_table(mb, w, d, sd, false, closed)
					"crates": B.crates(mb, w, d, "crates", sd, closed)
					"bar": B.bar_counter(mb, w, d, "pool_bar", sd, br, 0, closed)
					_: mb.blk(0, 0, w, d, 0.8, P.WOOD)


# ------------------------------------------------------------------ the mess a shakedown leaves

## Glass and goods on the floor in front of a smashed item (item frame: front is +z).
static func debris(mb: MB, it: Dictionary, w: float, d: float, kind: String) -> void:
	var sd := int(it.get("seed", 0)) + 911
	var type := String(it["type"])
	var art := String(it["art"])
	var z0 := d * 0.5
	if type == "window":
		# the glass blew out onto the sidewalk and a little fell inside
		_shards(mb, -w * 0.5, z0 + 0.05, w * 0.5, z0 + 0.7, int(w * 14.0), sd)
		_shards(mb, -w * 0.5, z0 - 0.62, w * 0.5, z0 - 0.3, int(w * 5.0), sd + 3)
		return
	var glassy := type in ["display", "mirror", "bar"] or art.ends_with("case")
	if glassy:
		_shards(mb, -w * 0.5, z0 + 0.05, w * 0.5, z0 + 0.65, int(w * 12.0) + 5, sd)
	var n := clampi(int(w / 0.25), 3, 11)
	for j in n:
		var x := (P.hf(j, 1, sd) - 0.5) * (w + 0.4)
		var z := z0 + 0.15 + P.hf(j, 2, sd) * 0.5
		var a := P.hf(j, 3, sd) * TAU
		var p := Vector3(x, 0.0, z)
		if art == "register":
			if j % 2 == 0:
				P.coin(mb, p)
			else:
				P.paper(mb, p, a, Vector3(0.12, 0.003, 0.08), Color("8aaa7a"))
			continue
		if art in ["speak_bar", "club_bar", "pool_bar", "club_backbar", "beer_backbar", "wine_shelf", "bottle_shelf", "crate_bar", "tonic_shelf"]:
			mb.at(p + Vector3(0, 0.03, 0), a)
			mb.cyl_dir(Vector3.ZERO, Vector3(1, 0, 0), 0.032, 0.24, P.pick(P.BOTTLES, j, 1, sd), "s", 6)
			mb.pop()
			mb.flat(x - 0.1, z - 0.07, x + 0.1, z + 0.07, 0.004, Color(0.35, 0.2, 0.1, 0.5), "dirt")
			continue
		_spill(mb, kind, p, a, j, sd)


static func _spill(mb: MB, kind: String, p: Vector3, a: float, j: int, sd: int) -> void:
	match kind:
		"bakery":
			if j % 2 == 0:
				P.roll(mb, p, 0.045)
			else:
				P.croissant(mb, p, a)
		"butcher": P.chop(mb, p, a)
		"grocer": P.fruit(mb, p, 0.04, P.pick([Color("b8282a"), Color("e08a28"), Color("e8d048")], j, 1, sd))
		"tailor": P.bolt(mb, p, true, P.pick(P.CLOTHS, j, 2, sd), 0.4, 0.06)
		"barber": P.bottle(mb, p, Color("3a6a8a"), 0.2)
		"cobbler": P.shoe(mb, p, a, Color("4a2e1e"))
		"pawnshop":
			if j % 2 == 0:
				P.watch(mb, p, a)
			else:
				P.necklace(mb, p)
		"laundry": P.towel_stack(mb, p, 1)
		"restaurant", "cafe":
			if j % 2 == 0:
				P.plate(mb, p, 0.09)
			else:
				P.cup(mb, p, 0.035)
		"candy": P.candy(mb, p.x - 0.1, p.z - 0.06, p.x + 0.1, p.z + 0.06, 0.0, sd + j)
		"hardware": P.tin(mb, p, Color("8a8a90"))
		"drugstore": P.bottle(mb, p, Color("3a6a9a"), 0.16)
		"cigar": P.cigarbox(mb, p, a, true)
		"fish": P.fish(mb, p, a)
		"club", "poolhall": P.card(mb, p, a, j % 2 == 0)
		_: P.box(mb, p, Vector3(0.14, 0.1, 0.1), P.pick(P.BRIGHTS, j, 1, sd), a)


static func _shards(mb: MB, x0: float, z0: float, x1: float, z1: float, n: int, sd: int) -> void:
	for j in mini(n, 40):
		var x := lerpf(x0, x1, P.hf(j, 1, sd))
		var z := lerpf(z0, z1, P.hf(j, 2, sd))
		var a := P.hf(j, 3, sd) * TAU
		var s := 0.03 + 0.05 * P.hf(j, 4, sd)
		var c := Color(0.82, 0.94, 1.0, 0.7)
		mb.tri(Vector3(x, 0.006, z) + Vector3(cos(a), 0, sin(a)) * s, Vector3(x, 0.006, z) + Vector3(cos(a + 2.2), 0, sin(a + 2.2)) * s * 0.7, Vector3(x, 0.006, z) + Vector3(cos(a + 4.1), 0, sin(a + 4.1)) * s * 0.5, c, "g")
		if j % 4 == 0:
			mb.sph(Vector3(x, 0.01, z), 0.008, Color(1, 1, 1, 1), "e", 4, 3)
