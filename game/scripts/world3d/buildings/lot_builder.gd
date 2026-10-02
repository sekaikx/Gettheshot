extends RefCounted
## Builds the geometry of ONE lot in its own frame (x along the front wall, y up, z out of the front,
## the wall plane at z = 0, the body at z in [-depth, 0]); the caller places it with `xf`.
##
## Four meshes come out, so the building can open up when somebody walks in:
##   base   the low shell (front wall to 0.9 m, the other walls to 1.5 m): always there
##   upper  everything above it: walls, cornice, roof, parapet, clutter, fire escapes
##   front  the static shopfront / door: piers, fascia board, awning frame, signs (hidden when inside)
##   dyn    what changes with Game.biz: glass, awning, padlock boards, chain (rebuilt by update_owners)
## Faces are numbered 0 front, 1 right, 2 back, 3 left (seen from outside).

const MK := preload("res://scripts/world3d/buildings/mesh_kit.gd")
const Shop := preload("res://scripts/world3d/buildings/shop_front.gd")
const Props := preload("res://scripts/world3d/buildings/roof_props.gd")
const RoofArt := preload("res://scripts/world2d/fronts/roof_art.gd")

const GROUND_H := 3.4
const FLOOR := 3.0
const CUT_FRONT := 0.9
const CUT_SIDE := 1.5
const DECK_DROP := 0.55

const CORNICE_COLORS := ["b8ae98", "6a5444", "d8ccb0", "5a5e62", "3f6a58", "8c8478"]
const DOORS := ["2a4a38", "6a2a24", "1c1a18", "4a3220", "26344e", "5a4a2a"]

var id := 0
var lot: Dictionary
var biz: Dictionary = {}
var kind := "tenement"
var is_shop := false           # a glass shopfront (not a club / precinct / warehouse townhouse front)
var w := 8.0
var d := 10.0
var h := 6.4
var floors := 2
var style := 0
var seed := 0.0
var tint := 0.0
var xf := Transform3D.IDENTITY          # lot frame -> world
var inv := Transform3D.IDENTITY
var covers: Array = []                  # per face: Array of [u0, u1, y0]
var party: Array = [false, false, false, false]
var rng: RandomNumberGenerator
var roof_plan: Dictionary = {}
var roof_origin := Vector2.ZERO
var deck_y := 5.85
var cornice_col := Color("b8ae98")
var wall_col := Color.WHITE

var base: MK = MK.new()
var upper: MK = MK.new()
var front: MK = MK.new()
var dyn: MK = MK.new()
var props: MK = MK.new()               # sidewalk clutter: stays when somebody goes inside
var labels: Array = []                  # {text, xf (lot frame), size, col, font, kind}
var lights: Array = []                  # lot-frame positions of lamps for View3D's pooled lights


# ------------------------------------------------------------------ frames

func face_frame(fi: int) -> Dictionary:
	return frame(fi, w, d)


static func frame(fi: int, fw: float, fd: float) -> Dictionary:
	match fi:
		0:
			return {"o": Vector3(-fw * 0.5, 0, 0), "r": Vector3(1, 0, 0), "n": Vector3(0, 0, 1), "len": fw}
		1:
			return {"o": Vector3(fw * 0.5, 0, 0), "r": Vector3(0, 0, -1), "n": Vector3(1, 0, 0), "len": fd}
		2:
			return {"o": Vector3(fw * 0.5, 0, -fd), "r": Vector3(-1, 0, 0), "n": Vector3(0, 0, -1), "len": fw}
	return {"o": Vector3(-fw * 0.5, 0, -fd), "r": Vector3(0, 0, 1), "n": Vector3(-1, 0, 0), "len": fd}


static func fr(x: float) -> float:
	return x - floorf(x)


func fract_seed(k: float) -> float:
	return fr(seed * k * 13.7)


func ncols(fi: int) -> int:
	if party[fi]:
		return 0
	var len: float = face_frame(fi)["len"]
	var r := W.rng(id * 131 + fi * 17 + 5)
	return clampi(roundi(len / r.randf_range(2.1, 2.7)), 1, 9)


func win_w(fi: int) -> float:
	var n := ncols(fi)
	if n == 0:
		return 0.0
	var len: float = face_frame(fi)["len"]
	var cw := len / n
	return clampf(lerpf(0.85, 1.1, fr(seed * 5.3 + fi * 0.37)), 0.7, cw * 0.62)


## 0 = no ground windows (glass shopfront), 1 = ground windows with a gap for the door, 2 = windows only,
## 3 = blank party wall (ghost signs)
func ground_mode(fi: int) -> int:
	if party[fi]:
		return 3
	if fi == 0:
		return 0 if (is_shop or kind == "warehouse") else 1
	return 2


func wall_color(fi: int) -> Color:
	var n := ncols(fi)
	var gm := ground_mode(fi)
	return Color(float(n) / 16.0, tint, float(style + 4 * gm) / 16.0, seed)


func cut_y(fi: int) -> float:
	return CUT_FRONT if fi == 0 else CUT_SIDE


## Window sill heights above ground (floor 0 only when the face has ground windows).
func window_rows(fi: int) -> Array:
	var rows := []
	var gm := ground_mode(fi)
	if gm == 1 or gm == 2:
		rows.append(0.95)
	for k in range(1, floors):
		rows.append(GROUND_H + (k - 1) * FLOOR + 0.6)
	return rows


# ------------------------------------------------------------------ build

func setup(p_lot: Dictionary, p_biz: Dictionary, p_xf: Transform3D, p_covers: Array, p_roof: Dictionary) -> void:
	lot = p_lot
	biz = p_biz
	id = int(lot["id"])
	kind = String(lot["kind"])
	w = float(lot["size"][0])
	d = float(lot["size"][1])
	floors = int(lot.get("floors", 2))
	h = V3.lot_height(lot)
	style = int(lot.get("style", 0)) % 4
	xf = p_xf
	inv = p_xf.affine_inverse()
	covers = p_covers
	roof_plan = p_roof
	roof_origin = W.lot_rect(p_lot).position
	rng = W.rng(id * 7919 + 101)
	seed = V3.hash01(float(id), 3.0, 11.0)
	tint = V3.hash01(float(id), 5.0, 29.0)
	deck_y = h - DECK_DROP
	is_shop = not biz.is_empty() and kind not in ["club", "precinct", "warehouse"]
	for fi in 4:
		var any_cover := false
		for pc in covers[fi]:
			if float(pc[2]) > 0.2:
				any_cover = true
		party[fi] = (fi == 1 or fi == 3) and any_cover
	cornice_col = Color(CORNICE_COLORS[rng.randi_range(0, CORNICE_COLORS.size() - 1)])
	if kind == "precinct":
		cornice_col = Color("c9c0aa")
		style = 3
	elif kind == "club":
		style = 1


## The courtyard between the rows: one low tar roof with a parapet and a few vents.
func build_court() -> void:
	h = 2.4
	deck_y = 2.1
	var tone := Color("463e38").lerp(Color("5b534b"), fr(seed * 9.0))
	roof_plan = {"tone": tone, "surf": "tar" if fr(seed * 5.0) < 0.6 else "gravel"}
	_roof()
	var rr := W.rng(id * 31 + 3)
	for k in 3:
		var c := Vector3(rr.randf_range(-w * 0.35, w * 0.35), deck_y, rr.randf_range(-d * 0.8, -d * 0.2))
		upper.cyl("trim", c, 0.2, 0.5, 8, Color("5a5c5e"))
		upper.cyl("trim", c + Vector3(0, 0.5, 0), 0.3, 0.12, 8, Color("3a3c3e"), 0.05)
	upper.box("trim", Vector3(rr.randf_range(-w * 0.3, w * 0.3), deck_y + 0.5, -d * 0.5), Vector3(1.6, 1.0, 1.4), Color("7a5a48"), 8)


func build() -> void:
	for fi in 4:
		_wall(fi)
	_sills()
	_cornice()
	_roof()
	_shop_level()
	if kind != "warehouse":
		_pilasters()
		_pipes_and_belts()
	Props.build(self)


## Wall quads, split at the cut line so the low shell can stay when the roof comes off.
func _wall(fi: int) -> void:
	var F := face_frame(fi)
	var o: Vector3 = F["o"]
	var r: Vector3 = F["r"]
	var n: Vector3 = F["n"]
	var col := wall_color(fi)
	var uv2 := Vector2(win_w(fi), float(F["len"]))
	var cut := cut_y(fi)
	var len: float = F["len"]
	# the low shell: the whole face, even where a neighbour hides it, so the party walls stay when the roof comes off
	var yt := minf(cut, h)
	if fi == 0:
		for pc in covers[fi]:
			_base_piece(o, r, n, float(pc[0]), float(pc[1]), float(pc[2]), yt, col, uv2)
	else:
		_base_piece(o, r, n, 0.0, len, 0.0, yt, col, uv2)
	for pc in covers[fi]:
		var u0: float = pc[0]
		var u1: float = pc[1]
		var y0: float = pc[2]
		if u1 - u0 < 0.02 or y0 >= h - 0.05:
			continue
		upper.face("wall", o, r, n, u0, u1, maxf(y0, cut), h, col, uv2)


func _base_piece(o: Vector3, r: Vector3, n: Vector3, u0: float, u1: float, y0: float, yt: float, col: Color, uv2: Vector2) -> void:
	if u1 - u0 < 0.02 or y0 >= yt:
		return
	base.face("wall", o, r, n, u0, u1, y0, yt, col, uv2)
	# the inside of the low shell and a cap along the cut, so it reads as a cut-away wall
	base.face("trim", o - n * 0.3, r, -n, u0, u1, y0, yt, Color("d6ccb4"))
	var p0 := o + r * u0 + Vector3.UP * yt
	var p1 := o + r * u1 + Vector3.UP * yt
	base.quad("trim", p0, p1, p1 - n * 0.3, p0 - n * 0.3, Vector3.UP, Color("aaa08c"))


func _piece_at(fi: int, u: float, y: float) -> bool:
	for pc in covers[fi]:
		if u >= float(pc[0]) - 0.01 and u <= float(pc[1]) + 0.01 and y >= float(pc[2]) - 0.02:
			return true
	return false


## Stone sills under every window: the relief that catches the sun.
func _sills() -> void:
	var sill_col := Color("c4b9a2")
	if style == 3:
		sill_col = Color("a9a395")
	for fi in 4:
		var n := ncols(fi)
		if n == 0:
			continue
		var F := face_frame(fi)
		var o: Vector3 = F["o"]
		var r: Vector3 = F["r"]
		var nn: Vector3 = F["n"]
		var len: float = F["len"]
		var cw := len / n
		var ww := win_w(fi)
		var rows := window_rows(fi)
		for c in n:
			var cc := (c + 0.5) * cw
			var skip_door := fi == 0 and ground_mode(0) == 1 and absf(cc - len * 0.5) < 1.3
			for ri in rows.size():
				var y: float = rows[ri]
				if ri == 0 and ground_mode(fi) in [1, 2]:
					if skip_door:
						continue
				if not _piece_at(fi, cc, y - 0.1):
					continue
				var pos := o + r * cc + Vector3.UP * (y - 0.05) + nn * 0.09
				var t := Transform3D(Basis(r, Vector3.UP, nn), pos)
				var tgt := base if y < CUT_SIDE - 0.2 and fi != 0 else (base if y < CUT_FRONT - 0.2 else upper)
				tgt.box_t("trim", t, Vector3(ww * 0.5 + 0.11, 0.045, 0.1), sill_col, 8 | 1 | 2)
				if style < 3 and ri > 0 and ri < 3 and kind == "tenement" and V3.hash01(cc + id, y, float(fi)) < 0.09:
					# a window box with geraniums
					var bt := Transform3D(Basis(r, Vector3.UP, nn), o + r * cc + Vector3.UP * (y + 0.07) + nn * 0.2)
					upper.box_t("trim", bt, Vector3(ww * 0.5, 0.08, 0.09), Color("6a4a32"), 8)
					for k in 3:
						var fp := o + r * (cc + (k - 1) * ww * 0.3) + Vector3.UP * (y + 0.22) + nn * 0.2
						upper.sphere("trim", fp, 0.1, Color("3f7a36") if k != 1 else Color("c0392b"), 5, 3)


## The crown of the wall (every exposed face) and, on street fronts, brackets under it.
func _cornice() -> void:
	var fancy: bool = fr(seed * 17.0) > 0.35 or kind in ["club", "precinct"]
	for fi in 4:
		var F := face_frame(fi)
		var o: Vector3 = F["o"]
		var r: Vector3 = F["r"]
		var n: Vector3 = F["n"]
		for pc in covers[fi]:
			var u0: float = pc[0]
			var u1: float = pc[1]
			if float(pc[2]) > h - 0.3 or u1 - u0 < 0.1:
				continue
			var mid := (u0 + u1) * 0.5
			var ln := u1 - u0
			var proj := 0.46 if fi == 0 else 0.3
			# crown moulding
			var t := Transform3D(Basis(r, Vector3.UP, n), o + r * mid + Vector3.UP * (h - 0.12) + n * (proj * 0.5 - 0.04))
			upper.box_t("trim", t, Vector3(ln * 0.5 + (0.06 if u0 <= 0.01 and u1 >= float(F["len"]) - 0.01 else 0.0), 0.11, proj * 0.5), cornice_col, 8)
			# the frieze below it, set out a little
			var t2 := Transform3D(Basis(r, Vector3.UP, n), o + r * mid + Vector3.UP * (h - 0.42) + n * 0.07)
			upper.box_t("trim", t2, Vector3(ln * 0.5, 0.17, 0.07), cornice_col.darkened(0.08), 8)
			# coping on the parapet and its inside face
			var tc := Transform3D(Basis(r, Vector3.UP, n), o + r * mid + Vector3.UP * (h + 0.045) - n * 0.14)
			upper.box_t("trim", tc, Vector3(ln * 0.5, 0.045, 0.19), cornice_col.lightened(0.04), 8)
			upper.face("wall", o - n * 0.3, r, -n, u0, u1, deck_y, h, Color(0.0, tint, float(style) / 16.0, seed), Vector2(0.0, 1.0))
			if fi == 0 and fancy and ln > 3.0:
				var k := int(ln / 0.95)
				for i in k:
					var uu := u0 + (i + 0.5) * ln / k
					var tb := Transform3D(Basis(r, Vector3.UP, n), o + r * uu + Vector3.UP * (h - 0.32) + n * 0.17)
					upper.box_t("trim", tb, Vector3(0.1, 0.13, 0.12), cornice_col.darkened(0.12), 8)


## A downspout up one side of the front, and a stone belt course half way up the tall buildings.
func _pipes_and_belts() -> void:
	var s := 1.0 if fr(seed * 31.0) > 0.5 else -1.0
	if party[1] and s > 0.0 or party[3] and s < 0.0:
		s = -s
	var x := s * (w * 0.5 - 0.16)
	var y0 := 3.5 if (is_shop or kind in ["club", "precinct"]) else 0.35
	if h - 0.7 > y0 + 1.0 and kind != "precinct":
		upper.cyl("trim", Vector3(x, y0, 0.14), 0.04, h - 0.6 - y0, 6, Color("3a3e3c"), -1.0, false)
		var yy := y0 + 0.5
		while yy < h - 0.8:
			upper.box("trim", Vector3(x, yy, 0.1), Vector3(0.11, 0.05, 0.1), Color("2a2c2a"), 8)
			yy += 2.2
	if floors >= 4:
		var k := int((floors - 1) / 2)
		var yb := GROUND_H + k * FLOOR - 0.1
		var bc := cornice_col.darkened(0.06)
		for pc in covers[0]:
			if float(pc[2]) > yb:
				continue
			var ln := float(pc[1]) - float(pc[0])
			upper.box("trim", Vector3(-w * 0.5 + (float(pc[0]) + float(pc[1])) * 0.5, yb, 0.05), Vector3(ln, 0.13, 0.1), bc, 8)


## Pilasters at the corners of the stone and cream buildings; quoins on brick ones.
func _pilasters() -> void:
	if style < 2 and fr(seed * 23.0) < 0.55:
		return
	var col := Color("b4a98f") if style != 3 else Color("c9c0aa")
	for s in [-1.0, 1.0]:
		var t := Transform3D(Basis(Vector3.RIGHT, Vector3.UP, Vector3.BACK), Vector3(s * (w * 0.5 - 0.17), 0, 0.045))
		var top := h - 0.4
		if party[1] and s > 0.0 or party[3] and s < 0.0:
			continue
		# quoins: alternating blocks, from above the shop level
		var y := GROUND_H + 0.1
		var k := 0
		while y < top:
			var bw := 0.5 if k % 2 == 0 else 0.34
			var bh := 0.36 if style >= 2 else 0.3
			var tgt := upper
			t.origin = Vector3(s * (w * 0.5 - bw * 0.5 + 0.02), y + bh * 0.5, 0.045)
			tgt.box_t("trim", t, Vector3(bw * 0.5, bh * 0.5 - 0.01, 0.05), col, 8)
			y += bh
			k += 1


func _roof() -> void:
	var tone: Color = roof_plan.get("tone", Color("3b3532"))
	var surf_name := String(roof_plan.get("surf", "tar"))
	var sidx := {"tar": 0, "gravel": 1, "tar_v": 2, "tin": 3}.get(surf_name, 0)
	tone = tone.lightened(0.16)
	var col := Color(tone.r, tone.g, tone.b, float(sidx) / 4.0)
	var y := deck_y
	var p0 := Vector3(-w * 0.5, y, -d)
	var p1 := Vector3(w * 0.5, y, -d)
	var p2 := Vector3(w * 0.5, y, 0.0)
	var p3 := Vector3(-w * 0.5, y, 0.0)
	upper.quad("roof", p3, p2, p1, p0, Vector3.UP, col,
		[Vector2(0, d), Vector2(w, d), Vector2(w, 0), Vector2(0, 0)], Vector2(w, d))


## Door, stoop, hood and a lamp for a house; the full shopfront for a shop.
func _shop_level() -> void:
	Shop.build(self)


func apply_wall_col(c: Color) -> void:
	wall_col = c


## Lot frame point -> world.
func to_world(p: Vector3) -> Vector3:
	return xf * p


## World pixel point (the 2D art) -> lot frame, at height y.
func local_px(px: Vector2, y: float = 0.0) -> Vector3:
	var p := inv * Vector3(px.x / W.M, 0.0, px.y / W.M)
	p.y = y
	return p


func local_px_dir(v: Vector2) -> Vector3:
	return (inv.basis * Vector3(v.x, 0.0, v.y)).normalized()


func meshes(mats: Dictionary) -> Dictionary:
	return {"base": base.commit(mats), "upper": upper.commit(mats), "front": front.commit(mats), "props": props.commit(mats)}
