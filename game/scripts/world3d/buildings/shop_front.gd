extends RefCounted
## The ground floor of a lot, in the lot frame (x along the front, y up, z out of the wall plane z = 0):
## the glass shopfront with its fascia board, door, transoms, awning, hanging sign and sidewalk clutter,
## or the stoop and door of a house, the club's canopy, the precinct's steps and blue lamps, the warehouse
## loading dock. `build` makes the static part (into B.front); `build_dynamic` the part that follows
## Game.biz (glass, awning, padlock boards, speakeasy lamp; into B.dyn). The layout of a business comes from
## FrontArt.plan_shop (the 2D art), so both views agree on awning width, sign side and what stands outside.

const FrontArt := preload("res://scripts/world2d/fronts/front_art.gd")
const MK := preload("res://scripts/world3d/buildings/mesh_kit.gd")
const Items := preload("res://scripts/world3d/buildings/sidewalk_props.gd")

const DOOR_HW := 0.62
const PIER := 0.4
const RISER := 0.64
const WIN_TOP := 2.5
const TRANSOM_TOP := 2.86
const FASCIA_TOP := 3.4

## board colour, lettering, pier/frame colour, glass tint
const KIND := {
	"grocer": ["2f4a36", "efe6c8", "233a2a", "7a9a5a"],
	"bakery": ["e6d9bc", "7a2e2a", "6a4630", "d8b070"],
	"butcher": ["7a2a26", "f0e6d0", "3a1c18", "b05a50"],
	"fish": ["26405a", "e8e4d4", "1c2c3c", "8ab0c0"],
	"cafe": ["1c1916", "d9b25a", "2a221c", "c89a60"],
	"restaurant": ["5a1f1c", "e8c870", "2e1512", "d09a58"],
	"barber": ["e8e4dc", "1c1916", "2a2a30", "9ab0c0"],
	"tailor": ["22304a", "d9b25a", "151c2c", "8a8ab0"],
	"cobbler": ["5a3c26", "f0e0b8", "3a2818", "b08850"],
	"pawnshop": ["1c1916", "d9b25a", "2a2420", "a89060"],
	"laundry": ["a8c0cc", "1c2a3a", "3a5060", "c8d8e0"],
	"cigar": ["3a2618", "d9b25a", "2a1a10", "b88a50"],
	"hardware": ["2c4a3a", "f0e6d0", "20362a", "a8a090"],
	"candy": ["e7b6c0", "5a2a3a", "7a3a4a", "f0c8d0"],
	"drugstore": ["1f3a30", "efe6d0", "16281f", "a8c8b8"],
	"poolhall": ["1c1916", "e8d490", "2a1c18", "6a9a70"],
	"club": ["141414", "d4a532", "1c1c1c", "c89a60"],
	"precinct": ["bdb39c", "1c1916", "a89e88", "8ab0d8"],
	"warehouse": ["6a5a48", "efe6d0", "4a4034", "a89878"],
}
const DOOR_COLORS := ["2a4a38", "6a2a24", "1c1a18", "4a3220", "26344e", "5a4a2a"]
const IRON := Color("25221f")
const BRASS := Color("c9a54a")
const STONE := Color("b4aa96")
const WOOD := Color("7a6448")


static func spec(B) -> Array:
	return KIND.get(B.kind, ["3a2e26", "e8dcc0", "2a2420", "a89070"])


static func C(hex: String) -> Color:
	return Color(hex)


# ------------------------------------------------------------------ static part

static func build(B) -> void:
	var f: MK = B.front
	match B.kind:
		"tenement":
			_house(B)
		"club":
			_club(B)
		"precinct":
			_precinct(B)
		"warehouse":
			_warehouse(B)
		_:
			if B.is_shop:
				_shop(B)
			else:
				_house(B)
	if not B.biz.is_empty():
		build_dynamic(B)


## Pairs [x0, x1] of the two display windows.
static func windows(B) -> Array:
	var hw: float = B.w * 0.5
	var x0 := DOOR_HW + 0.14
	var x1 := hw - PIER
	return [[-x1, -x0], [x0, x1]]


static func _house(B) -> void:
	var f: MK = B.front
	var rng: RandomNumberGenerator = B.rng
	var dc := Color(DOOR_COLORS[rng.randi_range(0, DOOR_COLORS.size() - 1)])
	var st := Color("a39a8a")
	# the stoop: two stone steps
	f.box("trim", Vector3(0, 0.07, 0.5), Vector3(1.9, 0.14, 1.0), st.darkened(0.06), 8 | 32)
	f.box("trim", Vector3(0, 0.15, 0.3), Vector3(1.6, 0.30, 0.6), st, 8 | 32)
	var y0 := 0.3
	# stone surround and door
	var sc := Color("c4b9a2")
	for s in [-1.0, 1.0]:
		f.box("trim", Vector3(s * 0.64, y0 + 1.1, 0.07), Vector3(0.18, 2.2, 0.14), sc, 8)
	f.box("trim", Vector3(0, y0 + 2.62, 0.09), Vector3(1.7, 0.2, 0.18), sc.lightened(0.05), 8)
	f.box("trim", Vector3(0, y0 + 2.76, 0.12), Vector3(1.9, 0.08, 0.26), sc.lightened(0.08), 8)
	f.box("trim", Vector3(0, y0 + 1.0, 0.03), Vector3(1.1, 2.0, 0.05), dc, 8)
	for s in [-1.0, 1.0]:
		for r in [[0.55, 0.7], [1.45, 0.6]]:
			f.box("trim", Vector3(s * 0.25, y0 + float(r[0]), 0.065), Vector3(0.38, float(r[1]), 0.03), dc.lightened(0.12), 8)
	f.box("trim", Vector3(0.0, y0 + 1.0, 0.065), Vector3(0.06, 2.0, 0.03), dc.darkened(0.3), 8)
	f.box("trim", Vector3(0.38, y0 + 1.0, 0.1), Vector3(0.06, 0.06, 0.05), BRASS, 8)
	# fan light
	var g1 := Vector3(-0.5, y0 + 2.08, 0.07)
	f.quad("glass", g1, g1 + Vector3(1.0, 0, 0), g1 + Vector3(1.0, 0.42, 0), g1 + Vector3(0, 0.42, 0), Vector3.BACK,
		Color(0.55, 0.45, 0.3, 0.5), [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)], Vector2(1.0, 0.42))
	# a lamp over the door, and some houses have a little hood
	f.box("lamp", Vector3(0.9, y0 + 2.3, 0.18), Vector3(0.12, 0.16, 0.12), Color(1.0, 0.82, 0.5, 1.0), 8)
	f.box("trim", Vector3(0.9, y0 + 2.3, 0.08), Vector3(0.05, 0.05, 0.14), IRON, 8)
	if B.fract_seed(7.0) > 0.55:
		f.box("trim", Vector3(0, y0 + 2.98, 0.4), Vector3(1.9, 0.07, 0.8), Color("6a7076"), 8)
		for s in [-1.0, 1.0]:
			f.bar("trim", Vector3(s * 0.85, y0 + 2.76, 0.06), Vector3(s * 0.85, y0 + 2.95, 0.75), 0.04, IRON)
	# iron railings either side of the steps
	for s in [-1.0, 1.0]:
		f.bar("trim", Vector3(s * 0.98, 0.3, 0.95), Vector3(s * 0.98, 0.85, 0.12), 0.035, IRON)
		f.bar("trim", Vector3(s * 0.98, 0.0, 0.95), Vector3(s * 0.98, 0.85, 0.95), 0.045, IRON)
		f.bar("trim", Vector3(s * 0.98, 0.3, 0.55), Vector3(s * 0.98, 0.58, 0.55), 0.02, IRON)
	# the belt course above the ground floor
	f.box("trim", Vector3(0, 3.4, 0.07), Vector3(B.w, 0.16, 0.16), B.cornice_col.darkened(0.04), 8)


static func _shop(B) -> void:
	var f: MK = B.front
	var sp := spec(B)
	var board := C(sp[0])
	var text := C(sp[1])
	var pier := C(sp[2]).lightened(0.16)
	var hw: float = B.w * 0.5
	var bw: float = (hw - PIER) * 2.0
	var S := FrontArt.plan_shop(B.biz, B.lot)
	# piers and stall risers
	for s in [-1.0, 1.0]:
		f.box("trim", Vector3(s * (hw - PIER * 0.5), TRANSOM_TOP * 0.5, 0.1), Vector3(PIER, TRANSOM_TOP, 0.2), pier, 8)
		f.box("trim", Vector3(s * (hw - PIER * 0.5), TRANSOM_TOP + 0.05, 0.12), Vector3(PIER + 0.06, 0.1, 0.24), STONE, 8)
	for wn in windows(B):
		var x0: float = wn[0]
		var x1: float = wn[1]
		f.box("trim", Vector3((x0 + x1) * 0.5, RISER * 0.5, 0.05), Vector3(x1 - x0 + 0.1, RISER, 0.1), pier.lightened(0.04), 8)
		f.box("trim", Vector3((x0 + x1) * 0.5, RISER + 0.03, 0.085), Vector3(x1 - x0 + 0.14, 0.06, 0.17), pier.lightened(0.2), 8)
		# head rail and frame bars
		f.box("trim", Vector3((x0 + x1) * 0.5, WIN_TOP + 0.04, 0.07), Vector3(x1 - x0 + 0.1, 0.08, 0.14), pier, 8)
		f.box("trim", Vector3((x0 + x1) * 0.5, TRANSOM_TOP - 0.02, 0.07), Vector3(x1 - x0 + 0.1, 0.07, 0.14), pier, 8)
		var n := maxi(1, ceili((x1 - x0) / 1.45))
		for i in range(1, n):
			var xm := lerpf(x0, x1, float(i) / n)
			f.box("trim", Vector3(xm, (RISER + WIN_TOP) * 0.5, 0.06), Vector3(0.07, WIN_TOP - RISER, 0.1), pier, 8)
			f.box("trim", Vector3(xm, (WIN_TOP + TRANSOM_TOP) * 0.5, 0.06), Vector3(0.05, TRANSOM_TOP - WIN_TOP, 0.08), pier, 8)
		for s in [x0, x1]:
			f.box("trim", Vector3(s, (RISER + WIN_TOP) * 0.5, 0.07), Vector3(0.07, WIN_TOP - RISER, 0.13), pier, 8)
	# the door: jambs, lintel, leaf with a panel below the glass
	var dcol := Color(DOOR_COLORS[B.rng.randi_range(0, DOOR_COLORS.size() - 1)]).lerp(pier, 0.4)
	for s in [-1.0, 1.0]:
		f.box("trim", Vector3(s * (DOOR_HW + 0.06), 1.3, 0.08), Vector3(0.12, 2.6, 0.16), pier, 8)
	f.box("trim", Vector3(0, WIN_TOP + 0.04, 0.08), Vector3(DOOR_HW * 2 + 0.24, 0.1, 0.16), pier, 8)
	f.box("trim", Vector3(0, 0.46, 0.05), Vector3(DOOR_HW * 2, 0.92, 0.07), dcol, 8)
	f.box("trim", Vector3(0, 0.46, 0.09), Vector3(DOOR_HW * 2 - 0.32, 0.62, 0.03), dcol.lightened(0.14), 8)
	for s in [-1.0, 1.0]:
		f.box("trim", Vector3(s * (DOOR_HW - 0.05), 1.7, 0.07), Vector3(0.1, 1.5, 0.08), dcol, 8)
	f.box("trim", Vector3(0, 0.94, 0.07), Vector3(DOOR_HW * 2, 0.07, 0.08), dcol, 8)
	f.box("trim", Vector3(0, 2.42, 0.07), Vector3(DOOR_HW * 2, 0.07, 0.08), dcol, 8)
	f.box("trim", Vector3(DOOR_HW - 0.16, 1.1, 0.12), Vector3(0.05, 0.16, 0.05), BRASS, 8)
	f.box("trim", Vector3(0, 0.05, 0.4), Vector3(DOOR_HW * 2 + 0.3, 0.1, 0.8), Color("8a8478"), 8 | 32)
	# the fascia board with the name; a gold border
	var by := (TRANSOM_TOP + FASCIA_TOP) * 0.5 + 0.02
	var bh := FASCIA_TOP - TRANSOM_TOP - 0.04
	f.box("trim", Vector3(0, by, 0.09), Vector3(bw, bh, 0.16), board, 8)
	var gold := Color("c9a54a") if board.get_luminance() < 0.5 else Color("5a4a30")
	f.box("trim", Vector3(0, by + bh * 0.5 - 0.02, 0.18), Vector3(bw - 0.1, 0.03, 0.03), gold, 8)
	f.box("trim", Vector3(0, by - bh * 0.5 + 0.02, 0.18), Vector3(bw - 0.1, 0.03, 0.03), gold, 8)
	# the shop's cornice shelf
	f.box("trim", Vector3(0, FASCIA_TOP + 0.07, 0.09), Vector3(B.w, 0.14, 0.18), B.cornice_col.darkened(0.05), 8)
	B.labels.append({"text": String(B.biz["name"]), "pos": Vector3(0, by - 0.05, 0.185), "w": bw - 0.45, "h": bh - 0.16,
		"col": text, "font": S["font"], "kind": "sign", "ang": 0.0})
	# a lamp on a gooseneck over the sign
	f.bar("trim", Vector3(0, FASCIA_TOP + 0.12, 0.1), Vector3(0, FASCIA_TOP + 0.32, 0.45), 0.03, IRON)
	f.cyl("trim", Vector3(0, FASCIA_TOP + 0.3, 0.5), 0.05, 0.1, 8, Color("2a3a30"), 0.16, false)
	f.sphere("lamp", Vector3(0, FASCIA_TOP + 0.27, 0.5), 0.05, Color(1.0, 0.86, 0.55, 1.0), 5, 3)
	B.lights.append(Vector3(0, 2.7, 1.4))
	# hanging sign on an iron bracket, beyond the awning
	var side_sign := _sign_side(B, S)
	_bracket(B, S, side_sign, board, text)
	Items.build(B, S)


static func _sign_side(B, S) -> float:
	for it in S["items"]:
		if it["slot"] == "b":
			var c: Vector2 = (it["rect"] as Rect2).get_center() / W.M
			return signf(c.x) * signf((B.local_px_dir(Vector2(S["ax"])) as Vector3).x)
	return 1.0


static func _bracket(B, S, side: float, board: Color, text: Color) -> void:
	var f: MK = B.front
	var hw: float = B.w * 0.5
	var x := side * (hw - 0.62)
	f.bar("trim", Vector3(x, 3.18, 0.05), Vector3(x, 3.18, 1.25), 0.035, IRON)
	f.bar("trim", Vector3(x, 3.18, 0.3), Vector3(x, 2.98, 0.05), 0.025, IRON)
	var over := String(S["over"])
	var neon := String(S["neon"])
	match over:
		"pawn_balls":
			for p in [Vector3(x, 3.0, 0.6), Vector3(x, 3.0, 1.0), Vector3(x, 2.74, 0.8)]:
				f.sphere("trim", p, 0.16, Color("d9b25a"), 8, 5)
			f.bar("trim", Vector3(x, 3.18, 0.6), Vector3(x, 3.05, 0.6), 0.015, IRON)
			f.bar("trim", Vector3(x, 3.18, 1.0), Vector3(x, 3.05, 1.0), 0.015, IRON)
			return
		"boot_sign":
			f.box("trim", Vector3(x, 2.9, 0.75), Vector3(0.1, 0.34, 0.26), Color("4a2e1c"), 8)
			f.box("trim", Vector3(x, 2.76, 0.88), Vector3(0.1, 0.12, 0.5), Color("3a2414"), 8)
			return
		"cigar_sign":
			f.bar("trim", Vector3(x, 2.9, 0.4), Vector3(x, 2.9, 1.15), 0.2, Color("6a4326"))
			f.bar("trim", Vector3(x, 2.9, 0.62), Vector3(x, 2.9, 0.7), 0.22, Color("c9a54a"))
			return
		"mortar_sign":
			f.cyl("trim", Vector3(x, 2.66, 0.75), 0.12, 0.2, 8, Color("e8e4d4"), 0.26, false)
			f.box("trim", Vector3(x, 2.95, 0.75), Vector3(0.05, 0.26, 0.05), Color("e8e4d4"), 8)
			return
	var tint_col := Color("7a2a24") if neon != "" else board.darkened(0.1)
	f.box("trim", Vector3(x, 2.96, 0.8), Vector3(0.1, 0.5, 1.0), tint_col, 8)
	f.box("trim", Vector3(x, 2.96, 0.8), Vector3(0.13, 0.56, 1.06), IRON, 8)
	f.box("trim", Vector3(x, 2.96, 0.8), Vector3(0.14, 0.46, 0.96), tint_col, 8)
	var word := neon if neon != "" else String(S["kind"]).to_upper()
	for sgn in [-1.0, 1.0]:
		B.labels.append({"text": word, "pos": Vector3(x + sgn * 0.075, 2.96, 0.8), "w": 0.86, "h": 0.32,
			"col": Color("ff6a5a") if neon != "" else text, "font": "cond", "kind": "neon" if neon != "" else "sign",
			"ang": sgn * PI * 0.5})
	if neon != "":
		B.lights.append(Vector3(x, 3.0, 1.0))


static func _club(B) -> void:
	_house_door_only(B)
	var f: MK = B.front
	var sp := spec(B)
	var S := FrontArt.plan_shop(B.biz, B.lot)
	var text := C(sp[1])
	# the name board over the door, with a lamp at each end
	f.box("trim", Vector3(0, 3.0, 0.1), Vector3(3.8, 0.62, 0.14), C(sp[0]), 8)
	f.box("trim", Vector3(0, 2.68, 0.19), Vector3(3.9, 0.03, 0.03), BRASS, 8)
	f.box("trim", Vector3(0, 3.31, 0.19), Vector3(3.9, 0.03, 0.03), BRASS, 8)
	B.labels.append({"text": String(B.biz["name"]), "pos": Vector3(0, 3.0, 0.185), "w": 3.5, "h": 0.4,
		"col": text, "font": "deco", "kind": "sign", "ang": 0.0})
	for s in [-1.0, 1.0]:
		f.bar("trim", Vector3(s * 2.15, 3.0, 0.1), Vector3(s * 2.15, 3.25, 0.5), 0.04, BRASS)
		f.cyl("lamp", Vector3(s * 2.15, 3.25, 0.5), 0.12, 0.26, 8, Color(1.0, 0.84, 0.52, 1.0), 0.08, true)
		B.lights.append(Vector3(s * 2.15, 3.0, 1.0))
	f.box("trim", Vector3(0, 3.4, 0.07), Vector3(B.w, 0.16, 0.16), B.cornice_col.darkened(0.04), 8)
	B.lights.append(Vector3(0, 2.6, 1.6))


## A tall double door with a stone surround and steps (the club, the precinct).
static func _house_door_only(B) -> void:
	var f: MK = B.front
	var st := Color("a39a8a")
	f.box("trim", Vector3(0, 0.07, 0.6), Vector3(2.8, 0.14, 1.2), st.darkened(0.06), 8 | 32)
	f.box("trim", Vector3(0, 0.16, 0.35), Vector3(2.4, 0.32, 0.7), st, 8 | 32)
	var y0 := 0.32
	var sc := Color("1c1c1c") if B.kind == "club" else Color("c4b9a2")
	for s in [-1.0, 1.0]:
		f.box("trim", Vector3(s * 0.98, y0 + 1.2, 0.08), Vector3(0.26, 2.4, 0.16), sc, 8)
	f.box("trim", Vector3(0, y0 + 2.4, 0.1), Vector3(2.5, 0.24, 0.2), sc, 8)
	var dc := Color("2a1c14") if B.kind == "club" else Color("3a2a1c")
	for s in [-1.0, 1.0]:
		f.box("trim", Vector3(s * 0.43, y0 + 1.0, 0.04), Vector3(0.84, 2.0, 0.06), dc, 8)
		f.box("trim", Vector3(s * 0.43, y0 + 0.45, 0.075), Vector3(0.6, 0.7, 0.03), dc.lightened(0.14), 8)
		f.box("trim", Vector3(s * 0.12, y0 + 1.05, 0.11), Vector3(0.05, 0.28, 0.05), BRASS, 8)
	var g1 := Vector3(-0.85, y0 + 1.75, 0.075)
	for s in [-1.0, 1.0]:
		var gp := Vector3(s * 0.43 - 0.3, y0 + 1.15, 0.075)
		f.quad("glass", gp, gp + Vector3(0.6, 0, 0), gp + Vector3(0.6, 0.7, 0), gp + Vector3(0, 0.7, 0), Vector3.BACK,
			Color(0.5, 0.4, 0.28, 0.5), [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)], Vector2(0.6, 0.7))


static func _precinct(B) -> void:
	_house_door_only(B)
	var f: MK = B.front
	var sp := spec(B)
	var S := FrontArt.plan_shop(B.biz, B.lot)
	var st := Color("b0a692")
	f.box("trim", Vector3(0, 0.1, 0.9), Vector3(3.6, 0.2, 1.8), st.darkened(0.08), 8 | 32)
	f.box("trim", Vector3(0, 0.22, 0.6), Vector3(3.2, 0.44, 1.2), st, 8 | 32)
	# the stone name plate and the blue lamps either side
	f.box("trim", Vector3(0, 3.02, 0.12), Vector3(4.2, 0.7, 0.2), C(sp[0]), 8)
	f.box("trim", Vector3(0, 3.4, 0.14), Vector3(4.5, 0.12, 0.28), st.lightened(0.1), 8)
	B.labels.append({"text": String(B.biz["name"]).to_upper(), "pos": Vector3(0, 3.02, 0.225), "w": 3.9, "h": 0.42,
		"col": C(sp[1]), "font": "serif", "kind": "sign", "ang": 0.0})
	for s in [-1.0, 1.0]:
		f.cyl("trim", Vector3(s * 2.0, 0.0, 1.28), 0.07, 2.1, 6, IRON)
		f.sphere("lamp", Vector3(s * 2.0, 2.3, 1.28), 0.26, Color(0.62, 0.8, 1.0, 1.0), 8, 6)
		B.lights.append(Vector3(s * 2.0, 2.3, 1.28))
	B.lights.append(Vector3(0, 2.4, 1.0))


static func _warehouse(B) -> void:
	var f: MK = B.front
	var hw: float = B.w * 0.5
	var conc := Color("8a857a")
	f.box("trim", Vector3(0, 0.52, 0.78), Vector3(B.w - 0.4, 1.04, 1.56), conc, 8 | 32)
	f.box("trim", Vector3(0, 1.07, 0.78), Vector3(B.w - 0.3, 0.06, 1.6), conc.lightened(0.1), 8 | 32)
	f.box("trim", Vector3(0, 0.35, 1.58), Vector3(B.w - 0.4, 0.5, 0.1), Color("1c1a18"), 8)
	var dcol := Color("6a7468")
	for xs in [-hw * 0.5, hw * 0.5]:
		var dw := minf(3.0, hw * 0.7)
		f.box("trim", Vector3(xs, 1.07 + 1.2, 0.04), Vector3(dw + 0.3, 2.4, 0.08), Color("2a2622"), 8)
		f.box("trim", Vector3(xs, 1.07 + 1.1, 0.09), Vector3(dw, 2.2, 0.06), dcol, 8)
		for k in 9:
			f.box("trim", Vector3(xs, 1.1 + k * 0.25 + 0.1, 0.125), Vector3(dw, 0.035, 0.03), dcol.darkened(0.25), 8)
		f.box("trim", Vector3(xs, 3.4, 0.1), Vector3(dw + 0.5, 0.18, 0.2), Color("4a4034"), 8)
	# an office door in the middle with a lamp
	f.box("trim", Vector3(0, 1.07 + 1.0, 0.06), Vector3(1.1, 2.0, 0.08), Color("3a2c1e"), 8)
	f.box("lamp", Vector3(0.8, 3.3, 0.2), Vector3(0.14, 0.14, 0.14), Color(1.0, 0.86, 0.55, 1.0), 8)
	# the loading canopy
	f.box("trim", Vector3(0, 3.62, 0.9), Vector3(B.w - 0.2, 0.1, 1.8), Color("3a342e"), 8)
	f.box("trim", Vector3(0, 3.5, 1.8), Vector3(B.w - 0.2, 0.28, 0.08), Color("4a4034"), 8)
	for s in [-1.0, 0.0, 1.0]:
		f.bar("trim", Vector3(s * (hw - 0.4), 3.55, 1.76), Vector3(s * (hw - 0.4), 4.5, 0.2), 0.04, IRON)
	var name := String(B.biz["name"]).to_upper()
	B.labels.append({"text": name, "pos": Vector3(0, 3.5, 1.85), "w": B.w - 1.2, "h": 0.2, "col": Color("efe6d0"),
		"font": "cond", "kind": "sign", "ang": 0.0})
	B.lights.append(Vector3(0, 3.0, 1.0))
	B.lights.append(Vector3(hw * 0.5, 3.0, 1.0))


# ------------------------------------------------------------------ the part that follows Game.biz

static func build_dynamic(B) -> void:
	var S := FrontArt.plan_shop(B.biz, B.lot)
	FrontArt.refresh(S, B.biz, false, 0.0)
	var closed := bool(S["closed"])
	var broken: Array = B.biz.get("broken", [])
	match B.kind:
		"club":
			_canopy(B, S, closed)
		"precinct", "warehouse":
			pass
		_:
			if B.is_shop:
				_shop_dyn(B, S, closed, not broken.is_empty())
	if bool(S["speak"]) and not closed:
		_speak(B, S)


static func _shop_dyn(B, S, closed: bool, broken: bool) -> void:
	var d: MK = B.dyn
	var sp := spec(B)
	var tint := C(sp[3])
	var gm := 0.88 if closed else 0.0
	var wins := windows(B)
	for i in wins.size():
		var x0: float = wins[i][0]
		var x1: float = wins[i][1]
		var mode := gm
		if broken and i == (0 if B.seed > 0.5 else 1):
			mode = 1.0
		var n := maxi(1, ceili((x1 - x0) / 1.45))
		for k in n:
			var a := lerpf(x0, x1, float(k) / n) + 0.04
			var b := lerpf(x0, x1, float(k + 1) / n) - 0.04
			var m := mode
			if mode == 1.0 and n > 1 and k != n / 2:
				m = gm
			_glass(d, a, b, RISER + 0.04, WIN_TOP, 0.045, Color(tint.r, tint.g, tint.b, m))
		_glass(d, x0 + 0.04, x1 - 0.04, WIN_TOP + 0.09, TRANSOM_TOP - 0.06, 0.045, Color(tint.r, tint.g, tint.b, 0.5 if not closed else 0.88))
	# door glass and transom
	_glass(d, -DOOR_HW + 0.1, DOOR_HW - 0.1, 0.99, 2.38, 0.075, Color(tint.r, tint.g, tint.b, gm))
	_glass(d, -DOOR_HW, DOOR_HW, WIN_TOP + 0.09, TRANSOM_TOP - 0.06, 0.07, Color(tint.r, tint.g, tint.b, 0.5 if not closed else 0.88))
	match String(S["awning"]):
		"stripe", "solid":
			if closed:
				_rolled(B, S)
			else:
				_awning(B, S)
	if closed:
		_padlock(B, wins)


static func _glass(d: MK, x0: float, x1: float, y0: float, y1: float, z: float, col: Color) -> void:
	d.quad("glass", Vector3(x0, y0, z), Vector3(x1, y0, z), Vector3(x1, y1, z), Vector3(x0, y1, z), Vector3.BACK, col,
		[Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)], Vector2(x1 - x0, y1 - y0))


static func _awning(B, S) -> void:
	var aw := float(S["aw_half"])
	var col: Color = S["col"]
	var solid := String(S["awning"]) == "solid"
	var sw := float(S["stripe"])
	var n := maxi(3, int(round(aw * 2.0 / sw)))
	if n % 2 == 0:
		n += 1
	sw = aw * 2.0 / n
	_canvas(B, -aw, -GAP, 0.14, 1.26, TRANSOM_TOP - 0.02, 2.32, 1.96, Color(col.r, col.g, col.b, 0.5 if solid else 0.0), sw, aw)
	_canvas(B, GAP, aw, 0.14, 1.26, TRANSOM_TOP - 0.02, 2.32, 1.96, Color(col.r, col.g, col.b, 0.5 if solid else 0.0), sw, aw)


const GAP := 0.95     # the door stays open to the overhead camera

## One sloped canvas panel from x0 to x1 (valance, front bar and arms included). `org` = the x where the
## stripe pattern starts (so both halves of an awning share one pattern).
static func _canvas(B, x0: float, x1: float, z0: float, z1: float, y0: float, y1: float, yv: float, c: Color,
		sw: float, org: float) -> void:
	var d: MK = B.dyn
	var nrm := Vector3(0, z1 - z0, y0 - y1).normalized()
	var ua := x0 + org
	var ub := x1 + org
	d.quad("awn", Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y1, z1), Vector3(x0, y1, z1), nrm, c,
		[Vector2(ua, 0), Vector2(ub, 0), Vector2(ub, 1), Vector2(ua, 1)], Vector2(sw, 0.0))
	d.quad("awn", Vector3(x0, y1, z1), Vector3(x1, y1, z1), Vector3(x1, yv, z1 + 0.03), Vector3(x0, yv, z1 + 0.03), Vector3.BACK, c,
		[Vector2(ua, 0), Vector2(ub, 0), Vector2(ub, 1), Vector2(ua, 1)], Vector2(sw, 1.0))
	d.bar("trim", Vector3(x0, y1 - 0.01, z1), Vector3(x1, y1 - 0.01, z1), 0.05, IRON)
	for xa in [x0 + 0.3, x1 - 0.3]:
		d.bar("trim", Vector3(xa, y0 - 0.1, z0), Vector3(xa, y1 - 0.03, z1 - 0.02), 0.03, IRON)
	# the cut ends of the canvas, closed with a small flap
	for xe in [x0, x1]:
		if absf(xe) < GAP + 0.01:
			d.tri("awn", Vector3(xe, y0, z0), Vector3(xe, y1, z1), Vector3(xe, y1, z0), Vector3(signf(xe), 0, 0), c.darkened(0.25),
				Vector2(ua, 0), Vector2(ua, 1), Vector2(ua, 0), Vector2(sw, 0.0))


static func _rolled(B, S) -> void:
	var d: MK = B.dyn
	var aw := float(S["aw_half"])
	var col: Color = S["col"]
	d.bar("awn", Vector3(-aw, TRANSOM_TOP - 0.06, 0.2), Vector3(aw, TRANSOM_TOP - 0.06, 0.2), 0.2, Color(col.r, col.g, col.b, 0.5))


## Planks across the glass, a chain and padlock on the door, a paper notice.
static func _padlock(B, wins: Array) -> void:
	var d: MK = B.dyn
	var rng := W.rng(B.id * 313 + 7)
	for wn in wins:
		var x0: float = wn[0]
		var x1: float = wn[1]
		var cx := (x0 + x1) * 0.5
		for k in 4:
			var y := 0.85 + k * 0.5 + rng.randf_range(-0.05, 0.05)
			var ang := rng.randf_range(-0.07, 0.07)
			var t := Transform3D(Basis(Vector3.BACK, ang), Vector3(cx + rng.randf_range(-0.05, 0.05), y, 0.12))
			d.box_t("trim", t, Vector3((x1 - x0) * 0.5 + 0.03, 0.095, 0.02), WOOD.darkened(rng.randf_range(0.0, 0.35)), 0)
	# chain across the door
	d.bar("trim", Vector3(-DOOR_HW, 1.1, 0.12), Vector3(DOOR_HW, 1.02, 0.12), 0.035, Color("5a5650"))
	d.bar("trim", Vector3(-DOOR_HW, 1.02, 0.12), Vector3(DOOR_HW, 1.1, 0.12), 0.03, Color("4a4640"))
	d.box("trim", Vector3(0, 1.05, 0.15), Vector3(0.12, 0.14, 0.06), Color("d4a532"), 8)
	# the notice
	d.box("trim", Vector3(0.38, 1.7, 0.095), Vector3(0.3, 0.42, 0.01), Color("e8e0c8"), 8)
	d.box("trim", Vector3(0.38, 1.85, 0.103), Vector3(0.26, 0.07, 0.005), Color("a02820"), 8)
	for k in 3:
		d.box("trim", Vector3(0.38, 1.7 - k * 0.07, 0.103), Vector3(0.2, 0.012, 0.005), Color("3a342c"), 8)


## The club's canopy: two wings either side of the door (so the door stays visible from above), brass poles.
static func _canopy(B, S, closed: bool) -> void:
	var d: MK = B.dyn
	var col: Color = S["col"]
	if closed:
		col = col.darkened(0.3)
	var c := Color(col.r, col.g, col.b, 0.5)
	var aw := 2.5
	_canvas(B, -aw, -GAP, 0.2, 1.7, 2.62, 2.16, 1.8, c, 0.25, aw)
	_canvas(B, GAP, aw, 0.2, 1.7, 2.62, 2.16, 1.8, c, 0.25, aw)
	for s in [-1.0, 1.0]:
		d.cyl("trim", Vector3(s * (aw - 0.1), 0.0, 1.62), 0.045, 2.2, 8, BRASS)
		d.sphere("trim", Vector3(s * (aw - 0.1), 2.22, 1.62), 0.08, BRASS, 6, 4)


static func _speak(B, S) -> void:
	var d: MK = B.dyn
	for it in S["items"]:
		if it["slot"] != "b":
			continue
		var c: Vector3 = B.local_px(S["xf"] * ((it["rect"] as Rect2).get_center()), 0.0)
		# stairs down: a dark hole by the wall with an iron rail, and a red lamp
		d.box("trim", Vector3(c.x, 0.025, c.z), Vector3(0.9, 0.05, 0.9), Color("0a0808"), 8)
		for s in [-1.0, 1.0]:
			d.bar("trim", Vector3(c.x + s * 0.5, 0.0, c.z - 0.45), Vector3(c.x + s * 0.5, 0.9, c.z - 0.45), 0.04, IRON)
			d.bar("trim", Vector3(c.x + s * 0.5, 0.9, c.z - 0.45), Vector3(c.x + s * 0.5, 0.9, c.z + 0.45), 0.04, IRON)
		d.bar("trim", Vector3(c.x, 2.0, c.z - 0.5), Vector3(c.x, 2.0, c.z - 0.1), 0.03, IRON)
		d.sphere("lamp", Vector3(c.x, 1.9, c.z - 0.05), 0.12, Color(1.0, 0.25, 0.2, 1.0), 8, 5)
		B.lights.append(Vector3(c.x, 1.9, c.z))
