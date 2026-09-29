extends RefCounted
## The roofs of the 2D city, seen from straight above. `plan_lot()` lays out one building's roof
## (deterministic from the lot id), `paint()` draws it into a node positioned at the lot's
## top-left corner (all coordinates here are lot-local pixels, world axes: +x east, +y south).
## Used by CityRoofs; nothing here keeps state.

const FX := preload("res://scripts/world2d/fronts/fx.gd")

const PARAPET := 0.34          # coping width, metres
const CORNICE := 0.42          # how far the front cornice sticks out over the sidewalk
const FE_DEPTH := 1.0          # fire escape platforms stick out this far
const IRON := Color("25221f")
const IRON_HI := Color("4a4540")

const LAUNDRY := [Color("ece6d6"), Color("e4e0d2"), Color("9fb0c0"), Color("b8413a"), Color("d9c9a0"),
	Color("6f7f94"), Color("c9b6a0"), Color("ffffff"), Color("8a9a6a"), Color("d58a7a")]
const CORNICE_COLORS := [Color("4a4f48"), Color("5c4a3c"), Color("a89878"), Color("5a5e62"), Color("6a5a48"), Color("3f4640")]


static func M(v: float) -> float:
	return v * W.M


# ------------------------------------------------------------------ layout

## Everything needed to draw one roof. `inner`: the block's building area (px, world), to know
## which faces front a street; `biz`: the business in this lot ({} for homes).
static func plan_lot(lot: Dictionary, inner: Rect2, biz: Dictionary) -> Dictionary:
	var r := W.lot_rect(lot)
	var id := int(lot["id"])
	var rng := W.rng(id * 7919 + 17)
	var kind := String(lot["kind"])
	var floors := int(lot["floors"])
	var style := int(lot["style"])
	var f := W.front_dir(float(lot["yaw"]))
	var l := f.orthogonal()
	var size := r.size
	var wl := absf(size.dot(l)) / W.M           # along the front, metres
	var dl := absf(size.dot(f)) / W.M           # depth, metres
	var fr := Transform2D(l, -f, size * 0.5 + f * size.dot(f.abs()) * 0.5 - l * size.dot(l.abs()) * 0.5)
	var L := {"id": id, "rect": r, "size": size, "kind": kind, "floors": floors, "style": style,
		"f": f, "fr": fr, "wl": wl, "dl": dl, "props": [], "fe": [], "lines": [], "recv": [],
		"biz_name": String(biz.get("name", "")), "is_biz": not biz.is_empty(), "glow": []}
	# which faces front a street (outward normals)
	var faces: Array = []
	if kind == "warehouse":
		faces = [f]
	else:
		if absf(r.position.x - inner.position.x) < 2.0: faces.append(Vector2.LEFT)
		if absf(r.end.x - inner.end.x) < 2.0: faces.append(Vector2.RIGHT)
		if absf(r.position.y - inner.position.y) < 2.0: faces.append(Vector2.UP)
		if absf(r.end.y - inner.end.y) < 2.0: faces.append(Vector2.DOWN)
	L["faces"] = faces
	# surface and colours
	var tones := [Pal.TAR, Pal.TAR_2, Pal.TAR_3, Pal.GRAVEL]
	var surf := "tar"
	var tone: Color = tones[style]
	match style:
		1:
			surf = "gravel"
		2:
			surf = "tar_v"
		3:
			surf = "gravel" if floors >= 4 else "tin"
	if kind == "warehouse":
		surf = "tar"
		tone = Pal.TAR_2
	if surf == "tin":
		tone = [Color("5e4a3c"), Color("56585a"), Color("4e5548")][id % 3]
	tone = FX.hashc(tone, id, 3, 1, 0.06)
	L["surf"] = surf
	L["tone"] = tone
	L["tex_off"] = Vector2(rng.randf_range(0, 128), rng.randf_range(0, 128))
	var pk := rng.randi_range(0, 5)
	if kind == "precinct":
		pk = 1
	var cop: Color
	var par: Color
	match pk:
		0, 1:
			par = Pal.PARAPET_STONE
			cop = Pal.PARAPET_STONE.lightened(0.08 + 0.05 * rng.randf())
		2, 3:
			par = Pal.PARAPET_BRICK
			cop = Pal.PARAPET_BRICK.lerp(Color("b0603c"), 0.35).lightened(0.05 * rng.randf())
		_:
			par = Pal.BRICK
			cop = Pal.BRICK.lightened(0.04 + 0.06 * rng.randf())
	if kind == "precinct":
		cop = Pal.PARAPET_STONE.lightened(0.2)
	L["coping"] = FX.hashc(cop, id, 5, 2, 0.05)
	L["coping_kind"] = pk
	L["parapet"] = par
	L["cornice"] = CORNICE_COLORS[rng.randi_range(0, CORNICE_COLORS.size() - 1)] if kind != "precinct" else Pal.PARAPET_STONE.lightened(0.12)
	L["cornice_front"] = faces.has(f) and kind != "warehouse"
	if kind == "warehouse":
		_plan_warehouse(L, rng, biz)
		return L
	# ----- props, in (along, depth) metres from the front-left corner
	var occ: Array = []
	var p0 := PARAPET + 0.08
	var a_max := wl - p0
	var d_min := p0 + (0.3 if L["cornice_front"] else 0.0)
	var d_max := dl - p0
	# water tower
	if floors >= 4 and (floors >= 6 or rng.randf() < 0.6):
		var rad := rng.randf_range(1.05, 1.4) if wl > 7.5 else rng.randf_range(0.95, 1.15)
		var ta := rng.randf_range(p0 + rad + 0.3, a_max - rad - 0.3)
		var td := rng.randf_range(dl * 0.5, d_max - rad - 0.25)
		occ.append(Rect2(ta - rad - 0.2, td - rad - 0.2, rad * 2 + 0.4, rad * 2 + 0.4))
		_add(L, {"t": "tower", "c": _pt(fr, ta, td), "r": M(rad), "seed": id})
	# stair bulkhead (or a hatch on low buildings)
	if floors >= 3 or kind in ["club", "precinct", "poolhall"]:
		var bw := 1.45
		var bd := 2.3
		for tries in 12:
			var ba := rng.randf_range(p0 + 0.6, a_max - bw - 0.6)
			var bdp := rng.randf_range(dl * 0.35, d_max - bd - 0.2)
			var rr := Rect2(ba, bdp, bw, bd)
			if _free(occ, rr):
				occ.append(rr.grow(0.3))
				_add(L, {"t": "bulkhead", "r": _rect(fr, ba, bdp, ba + bw, bdp + bd), "door": -f, "seed": id})
				break
	else:
		var hr := _find(occ, rng, 0.8, 0.8, p0 + 0.4, a_max - 0.4, dl * 0.4, d_max - 0.3)
		if hr.size.x > 0.0:
			_add(L, {"t": "hatch", "r": _rect(fr, hr.position.x, hr.position.y, hr.end.x, hr.end.y)})
	# skylights
	var n_sky := 1 + (1 if wl > 8.5 and rng.randf() < 0.6 else 0)
	if kind == "poolhall":
		var sr := _find(occ, rng, minf(wl - 2.2, 4.2), 1.3, p0 + 0.5, a_max - 0.5, d_min + 1.2, d_max - 1.0)
		if sr.size.x > 0.0:
			_add(L, {"t": "skylight", "r": _rect(fr, sr.position.x, sr.position.y, sr.end.x, sr.end.y), "along": l, "lit": true, "seed": id})
		n_sky = 0
	for k in n_sky:
		var sw := rng.randf_range(0.85, 1.05)
		var sd := rng.randf_range(1.2, 1.6)
		var sr := _find(occ, rng, sw, sd, p0 + 0.5, a_max - 0.5, d_min + 0.8, d_max - 0.4)
		if sr.size.x > 0.0:
			_add(L, {"t": "skylight", "r": _rect(fr, sr.position.x, sr.position.y, sr.end.x, sr.end.y), "along": -f, "lit": rng.randf() < 0.55, "seed": id * 3 + k})
	# chimneys on the party walls (the sides that aren't streets)
	var sides := []
	if not faces.has(-l): sides.append(0)
	if not faces.has(l): sides.append(1)
	if sides.is_empty():
		sides = [0]
	var n_ch := rng.randi_range(1, 3)
	for k in n_ch:
		var side: int = sides[k % sides.size()]
		var cw := rng.randf_range(0.5, 0.62)
		var cd := rng.randf_range(0.8, 1.3)
		var ca := PARAPET - 0.05 if side == 0 else wl - PARAPET + 0.05 - cw
		for tries in 8:
			var cdp := rng.randf_range(d_min + 0.6, d_max - cd - 0.1)
			var rr := Rect2(ca, cdp, cw, cd)
			if _free(occ, rr):
				occ.append(rr.grow(0.25))
				_add(L, {"t": "chimney", "r": _rect(fr, ca, cdp, ca + cw, cdp + cd), "pots": rng.randi_range(1, 3),
					"long": -f, "smoke": rng.randf() < 0.4, "seed": id * 5 + k})
				break
	# vents and soil pipes
	for k in rng.randi_range(1, 3):
		var vr := rng.randf_range(0.2, 0.3)
		var rr := _find(occ, rng, vr * 2, vr * 2, p0 + 0.3, a_max - 0.3, d_min + 0.3, d_max - 0.3)
		if rr.size.x > 0.0:
			_add(L, {"t": "vent", "c": _pt(fr, rr.get_center().x, rr.get_center().y), "r": M(vr), "turbine": rng.randf() < 0.3})
	for k in rng.randi_range(1, 3):
		var rr := _find(occ, rng, 0.2, 0.2, p0 + 0.2, a_max - 0.2, d_min + 0.2, d_max - 0.2)
		if rr.size.x > 0.0:
			_add(L, {"t": "pipe", "c": _pt(fr, rr.get_center().x, rr.get_center().y)})
	# the life on the roof: pigeons, tomatoes, a deck chair, a radio aerial, the washing
	var life := rng.randf()
	if life < 0.14 and wl > 6.5:
		var rr := _find(occ, rng, 2.4, 1.5, p0 + 0.3, a_max - 0.3, d_min + 0.3, d_max - 0.3)
		if rr.size.x > 0.0:
			_add(L, {"t": "coop", "r": _rect(fr, rr.position.x, rr.position.y, rr.end.x, rr.end.y), "long": l, "seed": id})
	elif life < 0.3 and String(lot["district"]) in ["Little Italy", "Lower East Side", "Hell's Kitchen"]:
		var n_box := rng.randi_range(2, 4)
		var rr := _find(occ, rng, 0.55 * n_box + 0.2, 1.1, p0 + 0.3, a_max - 0.3, d_min + 0.4, d_max - 0.3)
		if rr.size.x > 0.0:
			_add(L, {"t": "garden", "r": _rect(fr, rr.position.x, rr.position.y, rr.end.x, rr.end.y), "n": n_box, "along": l, "seed": id})
	elif life < 0.42:
		var rr := _find(occ, rng, 1.9, 1.3, p0 + 0.3, a_max - 0.3, d_min + 0.4, d_max - 0.3)
		if rr.size.x > 0.0:
			_add(L, {"t": "lounge", "r": _rect(fr, rr.position.x, rr.position.y, rr.end.x, rr.end.y), "seed": id})
	if rng.randf() < 0.22 and wl > 7.0:
		var aa := rng.randf_range(p0 + 0.3, p0 + 1.2)
		var ab := rng.randf_range(a_max - 1.2, a_max - 0.3)
		var ad := rng.randf_range(d_min + 1.0, d_max - 0.8)
		_add(L, {"t": "aerial", "a": _pt(fr, aa, ad), "b": _pt(fr, ab, ad + rng.randf_range(-1.0, 1.0))})
	if rng.randf() < 0.4 and floors >= 3:
		# a washing line across this roof, between two posts
		var ld := rng.randf_range(d_min + 1.2, d_max - 1.2)
		var la := rng.randf_range(p0 + 0.4, p0 + 1.2)
		var lb := rng.randf_range(a_max - 1.4, a_max - 0.4)
		var seg := Rect2(la, ld - 0.25, lb - la, 0.5)
		if _free(occ, seg):
			occ.append(seg)
			_add_line(L, _pt(fr, la, ld), _pt(fr, lb, ld + rng.randf_range(-0.4, 0.4)), id * 13, true, true)
	# grit: a drain, loose bricks, a bucket
	_add(L, {"t": "drain", "c": _pt(fr, rng.randf_range(p0 + 0.3, a_max - 0.3), d_max - 0.15), "seed": id})
	for k in rng.randi_range(0, 3):
		var rr := _find(occ, rng, 0.3, 0.3, p0 + 0.2, a_max - 0.2, d_min + 0.2, d_max - 0.2)
		if rr.size.x > 0.0:
			_add(L, {"t": "junk", "c": _pt(fr, rr.get_center().x, rr.get_center().y), "k": rng.randi_range(0, 3), "rot": rng.randf() * TAU})
	# patches of newer tar
	var patches := []
	for k in rng.randi_range(1, 3):
		var pw := rng.randf_range(0.7, 2.4)
		var pd := rng.randf_range(0.5, 1.6)
		var pa := rng.randf_range(p0, maxf(p0, wl - p0 - pw))
		var pdd := rng.randf_range(p0, maxf(p0, dl - p0 - pd))
		patches.append({"r": _rect(fr, pa, pdd, pa + pw, pdd + pd), "d": rng.randf_range(-0.07, 0.06)})
	L["patches"] = patches
	# fire escapes on street faces (not over a shop's awning)
	for n in faces:
		if n == f and (L["is_biz"] or kind != "tenement"):
			continue
		_plan_fire_escape(L, n, n == f, rng)
	# the sign on the precinct roof, the club's flag
	if kind == "precinct" or (kind == "club"):
		var fa := wl - p0 - 0.6 if rng.randf() < 0.5 else p0 + 0.6
		L["flag"] = {"base": _pt(fr, fa, d_min + 0.15), "dir": f}
	return L


static func _plan_warehouse(L: Dictionary, rng: RandomNumberGenerator, biz: Dictionary) -> void:
	var fr: Transform2D = L["fr"]
	var wl: float = L["wl"]
	var dl: float = L["dl"]
	# a long raised monitor with windows along it, parallel to the front, at the back
	_add(L, {"t": "monitor", "r": _rect(fr, 1.4, dl - 4.6, wl - 1.4, dl - 1.6), "along": (fr.x as Vector2)})
	for k in 4:
		var a := 1.6 + k * (wl - 3.2) / 3.0
		_add(L, {"t": "vent", "c": _pt(fr, a, dl - 0.9), "r": M(0.3), "turbine": true})
	_add(L, {"t": "vent", "c": _pt(fr, 1.2, 1.3), "r": M(0.28), "turbine": false})
	_add(L, {"t": "hatch", "r": _rect(fr, wl - 2.2, 1.0, wl - 1.3, 1.9)})
	_add(L, {"t": "drain", "c": _pt(fr, wl * 0.5, dl - 0.3), "seed": int(L["id"])})
	_add(L, {"t": "hoist", "a": _pt(fr, wl * 0.5 - 3.2, 0.0), "f": L["f"]})
	_add(L, {"t": "hoist", "a": _pt(fr, wl * 0.5 + 3.2, 0.0), "f": L["f"]})
	var name := String(biz.get("name", "Storage Co.")).to_upper()
	L["paint_name"] = name
	L["paint_rect"] = _rect(fr, 1.2, 1.2, wl - 1.2, dl - 5.2)
	L["patches"] = [{"r": _rect(fr, 2.0, 0.8, 5.0, 2.0), "d": 0.05}, {"r": _rect(fr, wl - 6.0, dl - 7.0, wl - 3.0, dl - 5.8), "d": -0.05}]
	L["fe"] = []


static func _plan_fire_escape(L: Dictionary, n: Vector2, is_front: bool, rng: RandomNumberGenerator) -> void:
	var size: Vector2 = L["size"]
	var along := n.orthogonal()
	var flen := absf(size.dot(along)) / W.M
	if flen < 5.0:
		return
	var width := clampf(flen * 0.42, 2.6, 4.0)
	var s0: float
	if is_front:
		# beside the door (it's in the middle), never over it
		if rng.randf() < 0.5:
			s0 = flen * 0.5 + 1.1
		else:
			s0 = flen * 0.5 - 1.1 - width
	else:
		s0 = rng.randf_range(1.0, flen - width - 1.0)
	s0 = clampf(s0, 0.45, flen - width - 0.45)
	var c := size * 0.5
	var o := c + n * absf(size.dot(n)) * 0.5 - along * flen * W.M * 0.5
	var ff := Transform2D(along, n, o)
	L["fe"].append({"fr": ff, "s0": M(s0), "s1": M(s0 + width), "stair_left": rng.randf() < 0.5,
		"floors": int(L["floors"]), "seed": int(L["id"]) * 31 + int(n.x * 3 + n.y * 7)})


static func _add(L: Dictionary, p: Dictionary) -> void:
	L["props"].append(p)


static func _add_line(L: Dictionary, a: Vector2, b: Vector2, seed_value: int, post_a: bool, post_b: bool) -> void:
	L["lines"].append({"a": a, "b": b, "seed": seed_value, "pa": post_a, "pb": post_b})


static func _pt(fr: Transform2D, a: float, d: float) -> Vector2:
	return fr * (Vector2(a, d) * W.M)


static func _rect(fr: Transform2D, a0: float, d0: float, a1: float, d1: float) -> Rect2:
	var p := fr * (Vector2(a0, d0) * W.M)
	var q := fr * (Vector2(a1, d1) * W.M)
	return Rect2(p.min(q), (p - q).abs())


static func _free(occ: Array, r: Rect2) -> bool:
	for o in occ:
		if (o as Rect2).intersects(r):
			return false
	return true


## A free spot w x d (metres, along x depth) inside [a0, a1] x [d0, d1], or an empty Rect2.
static func _find(occ: Array, rng: RandomNumberGenerator, w: float, d: float, a0: float, a1: float, d0: float, d1: float) -> Rect2:
	if a1 - a0 < w or d1 - d0 < d:
		return Rect2()
	for tries in 14:
		var rr := Rect2(rng.randf_range(a0, a1 - w), rng.randf_range(d0, d1 - d), w, d)
		if _free(occ, rr):
			occ.append(rr.grow(0.2))
			return rr
	return Rect2()


# ------------------------------------------------------------------ painting

static func paint(ci: CanvasItem, L: Dictionary) -> void:
	var size: Vector2 = L["size"]
	var full := Rect2(Vector2.ZERO, size)
	var p := M(PARAPET)
	var tone: Color = L["tone"]
	# the roof surface
	var surf := String(L["surf"])
	ci.draw_texture_rect_region(FX.tex(surf), full, Rect2(L["tex_off"], size), tone * (1.0 / 0.86))
	if surf.begins_with("tar"):
		_tar_strips(ci, L, full, p)
	elif surf == "gravel":
		# a path of concrete pavers from the hatch to the front, and a darker rim of washed gravel
		ci.draw_rect(full.grow(-p), Color(0, 0, 0, 0.06), false, M(0.25))
	for pt in L.get("patches", []):
		var pr: Rect2 = pt["r"]
		var d := float(pt["d"])
		var pc := Color(0, 0, 0, -d * 1.6) if d < 0.0 else Color(1, 1, 1, d)
		ci.draw_rect(pr, pc)
		ci.draw_rect(pr, Color(0, 0, 0, 0.18), false, 1.0)
	# flashing: a band of roofing cement along the foot of the parapet
	ci.draw_rect(full.grow(-p - 1.0), Color(Pal.TAR_3.darkened(0.3), 0.55), false, 3.0)
	# the parapet's shade on the roof (light from the north-west: the north and west parapets)
	var sw := M(0.3)
	FX.quad(ci, Vector2(p, p), Vector2(size.x - p, p), Vector2(size.x - p, p + sw), Vector2(p, p + sw),
		Color(FX.SHADE, 0.34), Color(FX.SHADE, 0.34), Color(FX.SHADE, 0.0), Color(FX.SHADE, 0.0))
	FX.quad(ci, Vector2(p, p), Vector2(p + sw, p), Vector2(p + sw, size.y - p), Vector2(p, size.y - p),
		Color(FX.SHADE, 0.34), Color(FX.SHADE, 0.0), Color(FX.SHADE, 0.0), Color(FX.SHADE, 0.34))
	if L["kind"] == "warehouse":
		_paint_name(ci, L)
	# props: shadows first, then the things themselves
	for pr in L["props"]:
		_prop_shadow(ci, pr)
	for ln in L["lines"]:
		_line_shadow(ci, ln)
	for pr in L["props"]:
		_prop(ci, pr)
	_parapet(ci, L, full, p)
	for fe in L["fe"]:
		_fire_escape(ci, fe, false)
	if L["cornice_front"]:
		_cornice(ci, L)
	for fe in L["fe"]:
		_fire_escape(ci, fe, true)
	for ln in L["lines"]:
		_line(ci, ln)
	# the seam between neighbours
	ci.draw_rect(full, Color(0.05, 0.04, 0.04, 0.8), false, 1.2)


## Shadows cast onto this roof by taller neighbours (drawn in a child so night can fade them).
static func paint_recv(ci: CanvasItem, L: Dictionary) -> void:
	for poly in L["recv"]:
		Draw.poly(ci, poly, Color(FX.SHADE, 0.3), false)
		# a slightly softer rim
		for g in Geometry2D.offset_polygon(poly, -3.0):
			Draw.poly(ci, g, Color(FX.SHADE, 0.06), false)


## Night glow: lit skylights and the warehouse's monitor windows.
static func paint_glow(ci: CanvasItem, L: Dictionary) -> void:
	for pr in L["props"]:
		match String(pr["t"]):
			"skylight":
				if pr.get("lit", false):
					var r: Rect2 = pr["r"]
					var g := r.grow(-M(0.08))
					ci.draw_rect(g.grow(M(0.35)), Color(Pal.WINDOW_WARM, 0.08))
					ci.draw_rect(g.grow(M(0.15)), Color(Pal.WINDOW_WARM, 0.12))
					ci.draw_rect(g, Color(Pal.WINDOW_WARM.lightened(0.1), 0.85))
					_skylight_bars(ci, pr, Color(0.25, 0.16, 0.08, 0.9))
			"monitor":
				var r: Rect2 = pr["r"]
				var along: Vector2 = pr["along"]
				var horiz := absf(along.x) > 0.5
				var wv := M(0.35)
				var a := Rect2(r.position, Vector2(r.size.x, wv)) if horiz else Rect2(r.position, Vector2(wv, r.size.y))
				var b := Rect2(Vector2(r.position.x, r.end.y - wv), Vector2(r.size.x, wv)) if horiz else Rect2(Vector2(r.end.x - wv, r.position.y), Vector2(wv, r.size.y))
				for w in [a, b]:
					ci.draw_rect((w as Rect2).grow(M(0.2)), Color(Pal.WINDOW_WARM, 0.1))
					ci.draw_rect(w, Color(Pal.WINDOW_WARM, 0.55))


# ----- surface

static func _tar_strips(ci: CanvasItem, L: Dictionary, full: Rect2, p: float) -> void:
	var id := int(L["id"])
	var vertical := String(L["surf"]) == "tar_v"
	var step := M(0.9)
	var length := full.size.x if not vertical else full.size.y
	var across := full.size.y if not vertical else full.size.x
	var k := 0
	var t := p + step * Draw.hash01(id, 1, 9)
	while t < across - p:
		var t1 := minf(t + step, across - p)
		var shade := (Draw.hash01(id, k, 21) - 0.5) * 0.09
		var band := Rect2(p, t, length - 2.0 * p, t1 - t) if not vertical else Rect2(t, p, t1 - t, length - 2.0 * p)
		ci.draw_rect(band, Color(1, 1, 1, shade) if shade > 0.0 else Color(0, 0, 0, -shade))
		# the lap: a light edge where one strip overlaps the next, a dark line under it
		if not vertical:
			ci.draw_line(Vector2(p, t1), Vector2(full.size.x - p, t1), Color(1, 1, 1, 0.07), 1.0)
			ci.draw_line(Vector2(p, t1 + 1.0), Vector2(full.size.x - p, t1 + 1.0), Color(0, 0, 0, 0.22), 1.0)
		else:
			ci.draw_line(Vector2(t1, p), Vector2(t1, full.size.y - p), Color(1, 1, 1, 0.07), 1.0)
			ci.draw_line(Vector2(t1 + 1.0, p), Vector2(t1 + 1.0, full.size.y - p), Color(0, 0, 0, 0.22), 1.0)
		t = t1
		k += 1
	# blisters and a crack or two
	var r := W.rng(id * 71 + 5)
	for i in r.randi_range(2, 6):
		var c := Vector2(r.randf_range(p * 2, full.size.x - p * 2), r.randf_range(p * 2, full.size.y - p * 2))
		Draw.ellipse(ci, c, Vector2(r.randf_range(4, 12), r.randf_range(3, 8)), Color(0, 0, 0, 0.1), r.randf() * PI)
	for i in r.randi_range(0, 2):
		var a := Vector2(r.randf_range(p * 2, full.size.x - p * 2), r.randf_range(p * 2, full.size.y - p * 2))
		var pts := PackedVector2Array([a])
		for s in 4:
			a += Vector2(r.randf_range(-14, 14), r.randf_range(-14, 14))
			pts.append(a.clamp(Vector2(p, p), full.size - Vector2(p, p)))
		ci.draw_polyline(pts, Color(0, 0, 0, 0.3), 1.0, true)


static func _parapet(ci: CanvasItem, L: Dictionary, full: Rect2, p: float) -> void:
	var cop: Color = L["coping"]
	var size := full.size
	var bands := [Rect2(0, 0, size.x, p), Rect2(0, size.y - p, size.x, p), Rect2(0, p, p, size.y - 2 * p), Rect2(size.x - p, p, p, size.y - 2 * p)]
	for b in bands:
		ci.draw_rect(b, cop)
	# joints between the coping stones (or the brick courses)
	var pk := int(L["coping_kind"])
	var joint := M(0.6) if pk <= 1 else (M(0.3) if pk <= 3 else M(0.11))
	var jc := Color(0, 0, 0, 0.22 if pk <= 3 else 0.12)
	var x := joint
	while x < size.x - 1.0:
		ci.draw_line(Vector2(x, 0), Vector2(x, p), jc, 1.0)
		ci.draw_line(Vector2(x, size.y - p), Vector2(x, size.y), jc, 1.0)
		x += joint
	var y := joint
	while y < size.y - 1.0:
		ci.draw_line(Vector2(0, y), Vector2(p, y), jc, 1.0)
		ci.draw_line(Vector2(size.x - p, y), Vector2(size.x, y), jc, 1.0)
		y += joint
	# the top of the coping catches the light on its north-west edges
	ci.draw_line(Vector2(0.5, 0.5), Vector2(size.x - 0.5, 0.5), Color(1, 1, 1, 0.22), 1.0)
	ci.draw_line(Vector2(0.5, 0.5), Vector2(0.5, size.y - 0.5), Color(1, 1, 1, 0.22), 1.0)
	ci.draw_line(Vector2(p, p), Vector2(size.x - p, p), Color(0, 0, 0, 0.35), 1.0)
	ci.draw_line(Vector2(p, p), Vector2(p, size.y - p), Color(0, 0, 0, 0.35), 1.0)
	ci.draw_line(Vector2(p, size.y - p), Vector2(size.x - p, size.y - p), Color(1, 1, 1, 0.12), 1.0)
	ci.draw_line(Vector2(size.x - p, p), Vector2(size.x - p, size.y - p), Color(1, 1, 1, 0.12), 1.0)


static func _cornice(ci: CanvasItem, L: Dictionary) -> void:
	var fr: Transform2D = L["fr"]
	var wl: float = L["wl"]
	var f: Vector2 = L["f"]
	var col: Color = L["cornice"]
	col = col * FX.facing(f, 0.25)
	col.a = 1.0
	var over := CORNICE if L["kind"] != "precinct" else 0.55
	# band from inside the parapet out over the sidewalk; returns at both ends
	var band := _rect(fr, -0.12, -over, wl + 0.12, PARAPET + 0.04)
	ci.draw_rect(band, col.darkened(0.12))
	var crown := _rect(fr, -0.12, -over, wl + 0.12, -over + M(0.0) / W.M + 0.16)
	ci.draw_rect(crown, col.lightened(0.14))
	var mid := _rect(fr, -0.05, -over + 0.2, wl + 0.05, PARAPET - 0.02)
	ci.draw_rect(mid, col)
	# dentils along the lip
	var a := 0.12
	while a < wl - 0.1:
		ci.draw_rect(_rect(fr, a, -over + 0.02, a + 0.1, -over + 0.1), col.darkened(0.3))
		a += 0.26
	# the lip itself, and the brackets at the ends
	var lip0 := _pt(fr, -0.12, -over)
	var lip1 := _pt(fr, wl + 0.12, -over)
	ci.draw_line(lip0, lip1, col.darkened(0.45), 1.5, true)
	ci.draw_rect(_rect(fr, -0.12, -over, 0.2, PARAPET), col.lightened(0.05))
	ci.draw_rect(_rect(fr, wl - 0.2, -over, wl + 0.12, PARAPET), col.lightened(0.05))
	ci.draw_line(_pt(fr, -0.12, -over), _pt(fr, -0.12, 0.0), col.darkened(0.4), 1.0, true)
	ci.draw_line(_pt(fr, wl + 0.12, -over), _pt(fr, wl + 0.12, 0.0), col.darkened(0.4), 1.0, true)


static func _paint_name(ci: CanvasItem, L: Dictionary) -> void:
	var r: Rect2 = L["paint_rect"]
	var name := String(L["paint_name"])
	var words := name.split(" ")
	var lines: Array[String] = []
	# two lines: the place name and the business ("HUDSON" / "COLD STORAGE")
	if words.size() >= 3:
		var cut := 1 if words.size() == 3 else 2
		if words.size() >= 4 and words[words.size() - 1].length() <= 3:
			cut = words.size() - 2
		lines.append(" ".join(words.slice(0, cut)))
		lines.append(" ".join(words.slice(cut)))
	else:
		lines.append(name)
	var font := W.font("cond")
	var paint := Color(Pal.PAPER, 0.8)
	var lh := r.size.y / float(lines.size() + 0.6)
	for i in lines.size():
		var size := FX.fit(font, lines[i], r.size.x * 0.94, int(lh / FX.CAP * 0.72), 20)
		var c := Vector2(r.get_center().x, r.position.y + lh * (i + 0.8))
		FX.text_c(ci, c, lines[i], size, paint, font)
	# the paint is worn: tar showing through in streaks
	var rr := W.rng(int(L["id"]) * 3 + 1)
	for k in 26:
		var p := Vector2(rr.randf_range(r.position.x, r.end.x), rr.randf_range(r.position.y, r.end.y))
		ci.draw_line(p, p + Vector2(rr.randf_range(8, 30), 0), Color(Pal.TAR_2, 0.55), rr.randf_range(1.0, 2.5))


# ----- props

static func _prop_shadow(ci: CanvasItem, pr: Dictionary) -> void:
	match String(pr["t"]):
		"tower":
			var c: Vector2 = pr["c"]
			var rad: float = pr["r"]
			var legs := rad * 0.86
			for s in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				var base: Vector2 = c + s * legs
				ci.draw_line(base, base + FX.sh(3.0), Color(FX.SHADE, 0.28), 3.0, true)
			var tank := Draw.ellipse_points(c + FX.sh(3.0), Vector2(rad, rad), 0.0, 24)
			FX.soft_poly(ci, FX.hull_shift(tank, FX.sh(4.6)), 0.34, 3.0)
		"bulkhead":
			FX.box_shadow(ci, pr["r"], FX.sh(2.4), 0.3)
		"chimney":
			FX.box_shadow(ci, pr["r"], FX.sh(1.5), 0.3)
		"skylight", "hatch":
			FX.box_shadow(ci, pr["r"], FX.sh(0.6), 0.25)
		"coop":
			FX.box_shadow(ci, pr["r"], FX.sh(1.5), 0.26)
		"vent":
			FX.soft_circle(ci, pr["c"] + FX.sh(0.7), pr["r"], 0.26)
		"monitor":
			FX.box_shadow(ci, pr["r"], FX.sh(1.6), 0.3)
		"garden":
			FX.box_shadow(ci, pr["r"], FX.sh(0.5), 0.2)


static func _prop(ci: CanvasItem, pr: Dictionary) -> void:
	match String(pr["t"]):
		"tower": _tower(ci, pr)
		"bulkhead": _bulkhead(ci, pr)
		"hatch": _hatch(ci, pr)
		"skylight": _skylight(ci, pr)
		"chimney": _chimney(ci, pr)
		"vent": _vent(ci, pr)
		"pipe":
			var c: Vector2 = pr["c"]
			Draw.circle(ci, c + FX.sh(0.4), 4.0, Color(FX.SHADE, 0.25))
			Draw.circle(ci, c, 4.2, Color("5a5550"))
			Draw.circle(ci, c, 2.6, Color("1a1817"))
		"coop": _coop(ci, pr)
		"garden": _garden(ci, pr)
		"lounge": _lounge(ci, pr)
		"aerial":
			var a: Vector2 = pr["a"]
			var b: Vector2 = pr["b"]
			ci.draw_line(a + FX.sh(3.0), b + FX.sh(3.0), Color(FX.SHADE, 0.18), 1.0, true)
			ci.draw_line(a, b, Color(0.1, 0.1, 0.1, 0.85), 1.0, true)
			for q in [a, b]:
				ci.draw_line(q, q + FX.sh(3.0), Color(FX.SHADE, 0.25), 2.0, true)
				Draw.circle(ci, q, 2.5, Color("3a3632"))
				Draw.circle(ci, q + Vector2(-0.6, -0.6), 1.0, Color("8a847c"))
		"drain":
			var c: Vector2 = pr["c"]
			Draw.ellipse(ci, c + Vector2(-6, -10), Vector2(16, 11), Color(0, 0, 0, 0.14))
			Draw.circle(ci, c, 4.5, Color("1e1c1b"))
			for k in 3:
				ci.draw_line(c + Vector2(-3.5, -2 + k * 2), c + Vector2(3.5, -2 + k * 2), Color("5a5550"), 1.0)
		"junk": _junk(ci, pr)
		"monitor": _monitor(ci, pr)
		"hoist":
			var a: Vector2 = pr["a"]
			var f: Vector2 = pr["f"]
			var tip := a + f * M(1.1)
			ci.draw_line(a + FX.sh(8.0), tip + FX.sh(8.0), Color(FX.SHADE, 0.22), 6.0)
			ci.draw_line(a - f * M(0.6), tip, Color("4e3e30"), 7.0)
			ci.draw_line(a - f * M(0.6) + Vector2(-1, -1), tip + Vector2(-1, -1), Color("6b5642"), 2.0)
			Draw.circle(ci, tip - f * 5.0, 4.0, Color("2a2622"))
			Draw.circle(ci, tip - f * 5.0, 1.6, Color("8a8680"))


static func _tower(ci: CanvasItem, pr: Dictionary) -> void:
	var c: Vector2 = pr["c"]
	var rad: float = pr["r"]
	var legs := rad * 0.86
	var steel := Color("3a3430")
	# the steel frame: legs and bracing peek out at the corners
	var corners := [c + Vector2(-legs, -legs), c + Vector2(legs, -legs), c + Vector2(legs, legs), c + Vector2(-legs, legs)]
	for k in 4:
		ci.draw_line(corners[k], corners[(k + 1) % 4], steel, 2.0, true)
		ci.draw_line(corners[k], corners[(k + 2) % 4], Color(steel, 0.8), 1.2, true)
	for q in corners:
		ci.draw_rect(Rect2(q - Vector2(3.5, 3.5), Vector2(7, 7)), steel.darkened(0.2))
		ci.draw_rect(Rect2(q - Vector2(3.5, 3.5), Vector2(7, 2)), steel.lightened(0.25))
	# the catwalk ring around the foot of the tank
	ci.draw_circle(c, rad + 5.0, Color("4a3e32"), true, -1.0, true)
	ci.draw_arc(c, rad + 5.0, 0.0, TAU, 40, Color("2a2420"), 1.2, true)
	# the staves (their tops show as a ring under the roof's edge)
	ci.draw_circle(c, rad + 1.0, Pal.WATER_TOWER.darkened(0.15), true, -1.0, true)
	# the conical roof: sectors lit toward the north-west
	var seg := 28
	var base := Pal.WATER_TOWER.lerp(Color("5a4a3c"), 0.35)
	for k in seg:
		var a0 := TAU * k / seg
		var a1 := TAU * (k + 1) / seg
		var am := (a0 + a1) * 0.5
		var n := Vector2(cos(am), sin(am))
		var lit := 1.0 - n.dot(FX.SUN) * 0.28
		var col := base * lit
		col.a = 1.0
		ci.draw_colored_polygon(PackedVector2Array([c, c + Vector2(cos(a0), sin(a0)) * rad, c + Vector2(cos(a1), sin(a1)) * rad]), col)
	# shingle courses
	for ring in [0.35, 0.62, 0.86]:
		ci.draw_arc(c, rad * ring, 0.0, TAU, 32, Color(0, 0, 0, 0.14), 1.0, true)
	for k in 8:
		var a := TAU * k / 8.0 + 0.2
		ci.draw_line(c + Vector2(cos(a), sin(a)) * 3.0, c + Vector2(cos(a), sin(a)) * rad, Color(0, 0, 0, 0.12), 1.0, true)
	ci.draw_arc(c, rad, 0.0, TAU, 40, Color("2a1f18"), 1.5, true)
	# a steel hoop just below the eaves
	ci.draw_arc(c, rad + 2.5, PI * 0.1, PI * 0.9, 16, Color("24201c", 0.9), 1.0, true)
	# finial, roof hatch, ladder
	Draw.circle(ci, c, 3.2, Color("2a2420"))
	Draw.circle(ci, c + Vector2(-0.8, -0.8), 1.2, Color("8a7a6a"))
	var ha := 0.9 + Draw.hash01(int(pr["seed"]), 2, 3) * 1.4
	var hp := c + Vector2(cos(ha), sin(ha)) * rad * 0.62
	ci.draw_set_transform(hp, ha, Vector2.ONE)
	ci.draw_rect(Rect2(-5, -4, 10, 8), Color("3a2e24"))
	ci.draw_rect(Rect2(-5, -4, 10, 1.5), Color("7a6650"))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var la := ha + 0.25
	var l0 := c + Vector2(cos(la), sin(la)) * (rad - 2.0)
	var l1 := c + Vector2(cos(la), sin(la)) * (rad + 12.0)
	var side := Vector2(cos(la), sin(la)).orthogonal() * 3.0
	ci.draw_line(l0 + side, l1 + side, steel, 1.2, true)
	ci.draw_line(l0 - side, l1 - side, steel, 1.2, true)


static func _bulkhead(ci: CanvasItem, pr: Dictionary) -> void:
	var r: Rect2 = pr["r"]
	var door: Vector2 = pr["door"]
	var wall := Color("6a4a3a") if int(pr["seed"]) % 3 != 0 else Color("7a746a")
	ci.draw_rect(r, wall.darkened(0.25))
	# a tin shed roof falling away from the door side
	var roof := r.grow(-2.0)
	var hi := Color("6e6a64")
	var lo := Color("4e4a46")
	var tl := roof.position
	var tr := Vector2(roof.end.x, roof.position.y)
	var br := roof.end
	var bl := Vector2(roof.position.x, roof.end.y)
	var hv := hi if door.y < 0.0 or door.x < 0.0 else lo
	var lv := lo if hv == hi else hi
	if absf(door.y) > 0.5:
		FX.quad(ci, tl, tr, br, bl, hv, hv, lv, lv)
	else:
		FX.quad(ci, tl, tr, br, bl, hv, lv, lv, hv)
	# standing seams
	var horiz := absf(door.y) > 0.5
	var n := 5
	for k in range(1, n):
		if horiz:
			var x := roof.position.x + roof.size.x * k / n
			ci.draw_line(Vector2(x, roof.position.y), Vector2(x, roof.end.y), Color(1, 1, 1, 0.12), 1.0)
		else:
			var y := roof.position.y + roof.size.y * k / n
			ci.draw_line(Vector2(roof.position.x, y), Vector2(roof.end.x, y), Color(1, 1, 1, 0.12), 1.0)
	Draw.rect(ci, r, Color(0, 0, 0, 0), true)
	ci.draw_rect(r, Color(0.08, 0.06, 0.05, 0.9), false, 1.0)
	# the door's step
	var mid := r.get_center() + door * (r.size * 0.5).dot(door.abs())
	var along := door.orthogonal().abs()
	var step := Rect2(mid - along * M(0.4), Vector2.ZERO).expand(mid + along * M(0.4) + door * M(0.3))
	ci.draw_rect(step, Color("8c8478"))
	ci.draw_rect(step, Color(0, 0, 0, 0.3), false, 1.0)
	# a vent stack through the roof
	var vs := r.get_center() - door * M(0.35)
	Draw.circle(ci, vs + FX.sh(0.6), 3.5, Color(FX.SHADE, 0.3))
	Draw.circle(ci, vs, 3.6, Color("5a5550"))
	Draw.circle(ci, vs, 2.0, Color("1a1817"))


static func _hatch(ci: CanvasItem, pr: Dictionary) -> void:
	var r: Rect2 = pr["r"]
	ci.draw_rect(r, Color("4a4540"))
	ci.draw_rect(r.grow(-3.0), Color("6a6560"))
	ci.draw_line(r.position + Vector2(3, 3), Vector2(r.end.x - 3, r.position.y + 3), Color(1, 1, 1, 0.2), 1.0)
	ci.draw_line(Vector2(r.get_center().x, r.position.y + 3), Vector2(r.get_center().x, r.end.y - 3), Color(0, 0, 0, 0.25), 1.0)
	Draw.circle(ci, Vector2(r.end.x - 7, r.get_center().y), 1.8, Color("2a2622"))
	ci.draw_rect(r, Color(0.05, 0.05, 0.05, 0.8), false, 1.0)


static func _skylight(ci: CanvasItem, pr: Dictionary) -> void:
	var r: Rect2 = pr["r"]
	# the curb, then two slopes of glass either side of the ridge
	ci.draw_rect(r, Color("3e3a36"))
	var g := r.grow(-M(0.08))
	var along: Vector2 = pr["along"]
	var ridge_h := absf(along.x) > 0.5
	var lit := Pal.SKYLIGHT.lightened(0.18)
	var dark := Pal.SKYLIGHT.darkened(0.25)
	if ridge_h:
		var mid := g.position.y + g.size.y * 0.5
		ci.draw_rect(Rect2(g.position, Vector2(g.size.x, mid - g.position.y)), lit)
		ci.draw_rect(Rect2(Vector2(g.position.x, mid), Vector2(g.size.x, g.end.y - mid)), dark)
	else:
		var mid := g.position.x + g.size.x * 0.5
		ci.draw_rect(Rect2(g.position, Vector2(mid - g.position.x, g.size.y)), lit)
		ci.draw_rect(Rect2(Vector2(mid, g.position.y), Vector2(g.end.x - mid, g.size.y)), dark)
	# a sky reflection streak, a tarred-over pane
	var rr := W.rng(int(pr["seed"]))
	ci.draw_line(g.position + Vector2(2, 2), g.position + Vector2(g.size.x * 0.4, g.size.y * 0.3), Color(1, 1, 1, 0.3), 1.5, true)
	if rr.randf() < 0.5:
		var pane := Rect2(g.position + Vector2(g.size.x * 0.5, g.size.y * rr.randf_range(0.0, 0.6)), Vector2(g.size.x * 0.5, g.size.y * 0.3))
		ci.draw_rect(pane, Color(Pal.TAR, 0.85))
	_skylight_bars(ci, pr, Color("2e2a26"))
	ci.draw_rect(r, Color(0.05, 0.05, 0.05, 0.8), false, 1.0)


static func _skylight_bars(ci: CanvasItem, pr: Dictionary, col: Color) -> void:
	var r: Rect2 = pr["r"]
	var g := r.grow(-M(0.08))
	var along: Vector2 = pr["along"]
	if absf(along.x) > 0.5:
		ci.draw_line(Vector2(g.position.x, g.get_center().y), Vector2(g.end.x, g.get_center().y), col.lightened(0.2), 1.5)
		var n := maxi(2, int(g.size.x / M(0.32)))
		for k in range(1, n):
			var x := g.position.x + g.size.x * k / n
			ci.draw_line(Vector2(x, g.position.y), Vector2(x, g.end.y), col, 1.0)
	else:
		ci.draw_line(Vector2(g.get_center().x, g.position.y), Vector2(g.get_center().x, g.end.y), col.lightened(0.2), 1.5)
		var n := maxi(2, int(g.size.y / M(0.32)))
		for k in range(1, n):
			var y := g.position.y + g.size.y * k / n
			ci.draw_line(Vector2(g.position.x, y), Vector2(g.end.x, y), col, 1.0)


static func _chimney(ci: CanvasItem, pr: Dictionary) -> void:
	var r: Rect2 = pr["r"]
	var seed_value := int(pr["seed"])
	var brick := FX.hashc(Pal.CHIMNEY, seed_value, 1, 4, 0.08)
	ci.draw_rect(r, brick)
	# brick courses on the sides that show
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, 2.0)), brick.lightened(0.18))
	ci.draw_rect(Rect2(r.position, Vector2(2.0, r.size.y)), brick.lightened(0.12))
	# the cap stone
	var cap := r.grow(-2.5)
	ci.draw_rect(cap, Color("8a8078"))
	ci.draw_rect(cap.grow(-2.0), Color("7a7068"))
	# soot around and downwind of the flues
	var long: Vector2 = pr["long"]
	var n := int(pr["pots"])
	var axis := Vector2(0, 1) if absf(long.y) > 0.5 else Vector2(1, 0)
	if cap.size.x > cap.size.y:
		axis = Vector2(1, 0)
	elif cap.size.y > cap.size.x:
		axis = Vector2(0, 1)
	var span := cap.size.dot(axis)
	for k in n:
		var t := (float(k) + 0.5) / n - 0.5
		var pc := cap.get_center() + axis * span * t * 0.85
		Draw.ellipse(ci, pc + Vector2(3, 4), Vector2(7, 5), Color(0.05, 0.04, 0.04, 0.35), 0.7)
		Draw.circle(ci, pc, 4.6, Color("9a5a3a"))
		Draw.circle(ci, pc + Vector2(-0.8, -0.8), 3.4, Color("b06a44"))
		Draw.circle(ci, pc, 2.4, Color("120e0c"))
	ci.draw_rect(r, Color(0.08, 0.05, 0.04, 0.9), false, 1.0)


static func _vent(ci: CanvasItem, pr: Dictionary) -> void:
	var c: Vector2 = pr["c"]
	var rad: float = pr["r"]
	var metal := Color("7a7670")
	Draw.circle(ci, c, rad, metal.darkened(0.3))
	if pr.get("turbine", false):
		# a whirlybird: curved vanes
		Draw.circle(ci, c, rad - 1.0, metal)
		for k in 10:
			var a := TAU * k / 10.0
			var p0 := c + Vector2(cos(a), sin(a)) * rad * 0.25
			var p1 := c + Vector2(cos(a + 0.6), sin(a + 0.6)) * (rad - 1.0)
			ci.draw_line(p0, p1, metal.darkened(0.35), 1.0, true)
		Draw.circle(ci, c, rad * 0.25, metal.lightened(0.2))
	else:
		# a mushroom cap, lit from the north-west
		Draw.circle(ci, c, rad - 1.0, metal)
		Draw.circle(ci, c + Vector2(-rad, -rad) * 0.18, rad * 0.62, metal.lightened(0.15))
		Draw.circle(ci, c, 1.5, metal.darkened(0.4))
	ci.draw_arc(c, rad, 0.0, TAU, 20, Color(0.1, 0.1, 0.1, 0.7), 1.0, true)


static func _coop(ci: CanvasItem, pr: Dictionary) -> void:
	var r: Rect2 = pr["r"]
	var long: Vector2 = pr["long"]
	var horiz := absf(long.x) > 0.5
	var rr := W.rng(int(pr["seed"]) * 17)
	# the loft (half) and the wire run (the other half)
	var loft := Rect2(r.position, Vector2(r.size.x * 0.45, r.size.y)) if horiz else Rect2(r.position, Vector2(r.size.x, r.size.y * 0.45))
	var run := Rect2(Vector2(loft.end.x, r.position.y), Vector2(r.end.x - loft.end.x, r.size.y)) if horiz else Rect2(Vector2(r.position.x, loft.end.y), Vector2(r.size.x, r.end.y - loft.end.y))
	ci.draw_rect(run, Color(0, 0, 0, 0.12))
	var mesh := Color(0.75, 0.75, 0.72, 0.35)
	var x := run.position.x
	while x <= run.end.x:
		ci.draw_line(Vector2(x, run.position.y), Vector2(x, run.end.y), mesh, 1.0)
		x += 5.0
	var y := run.position.y
	while y <= run.end.y:
		ci.draw_line(Vector2(run.position.x, y), Vector2(run.end.x, y), mesh, 1.0)
		y += 5.0
	ci.draw_rect(run, Color("5a4632"), false, 2.0)
	var wood := Color("7a6248")
	ci.draw_rect(loft, wood.darkened(0.2))
	var lroof := loft.grow(-2.0)
	FX.quad(ci, lroof.position, Vector2(lroof.end.x, lroof.position.y), lroof.end, Vector2(lroof.position.x, lroof.end.y),
		wood.lightened(0.1), wood.lightened(0.1) if horiz else wood.darkened(0.1), wood.darkened(0.1), wood.darkened(0.1) if horiz else wood.lightened(0.1))
	for k in 5:
		if horiz:
			var yy := lroof.position.y + lroof.size.y * (k + 0.5) / 5.0
			ci.draw_line(Vector2(lroof.position.x, yy), Vector2(lroof.end.x, yy), Color(0, 0, 0, 0.18), 1.0)
		else:
			var xx := lroof.position.x + lroof.size.x * (k + 0.5) / 5.0
			ci.draw_line(Vector2(xx, lroof.position.y), Vector2(xx, lroof.end.y), Color(0, 0, 0, 0.18), 1.0)
	ci.draw_rect(loft, Color(0.1, 0.07, 0.05, 0.9), false, 1.0)
	# pigeons: on the loft, in the run, on the parapet nearby
	for k in rr.randi_range(5, 9):
		var inside := rr.randf() < 0.6
		var area := run if inside else loft
		var p := Vector2(rr.randf_range(area.position.x + 3, area.end.x - 3), rr.randf_range(area.position.y + 3, area.end.y - 3))
		_pigeon(ci, p, rr.randf() * TAU, rr.randf() < 0.2)


static func _pigeon(ci: CanvasItem, p: Vector2, rot: float, white: bool) -> void:
	var body := Color("8c9096") if not white else Color("e6e4de")
	ci.draw_set_transform(p, rot, Vector2.ONE)
	Draw.ellipse(ci, Vector2(1.5, 1.5), Vector2(4.2, 2.6), Color(FX.SHADE, 0.25))
	Draw.ellipse(ci, Vector2.ZERO, Vector2(4.2, 2.5), body)
	ci.draw_line(Vector2(-1, -1.6), Vector2(-1, 1.6), body.darkened(0.3), 1.0)
	Draw.circle(ci, Vector2(3.6, 0), 1.5, body.darkened(0.15) if not white else body)
	ci.draw_line(Vector2(-4, 0), Vector2(-6, 0), body.darkened(0.35), 1.8)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _garden(ci: CanvasItem, pr: Dictionary) -> void:
	var r: Rect2 = pr["r"]
	var n := int(pr["n"])
	var along: Vector2 = pr["along"]
	var horiz := absf(along.x) > 0.5
	var rr := W.rng(int(pr["seed"]) * 23)
	for k in n:
		var box: Rect2
		if horiz:
			var w := (r.size.x - 4.0) / n
			box = Rect2(r.position.x + k * w + 2, r.position.y, w - 4, r.size.y)
		else:
			var h := (r.size.y - 4.0) / n
			box = Rect2(r.position.x, r.position.y + k * h + 2, r.size.x, h - 4)
		ci.draw_rect(box, Color("6b5238"))
		ci.draw_rect(box.grow(-2.5), Color("3a2a1e"))
		ci.draw_line(box.position, Vector2(box.end.x, box.position.y), Color("8a6a48"), 1.0)
		# tomato plants: leafy clumps with red fruit, on stakes
		var c := box.get_center()
		var m := maxi(2, int(box.size.y / 16.0)) if horiz else maxi(2, int(box.size.x / 16.0))
		for j in m:
			var t := (j + 0.5) / m
			var pc := Vector2(c.x, box.position.y + box.size.y * t) if horiz else Vector2(box.position.x + box.size.x * t, c.y)
			Draw.circle(ci, pc + Vector2(2, 2), 6.5, Color(FX.SHADE, 0.25))
			Draw.circle(ci, pc, 6.5, Color("3e5a2e"))
			Draw.circle(ci, pc + Vector2(-1.5, -1.5), 4.2, Color("5a7a3a"))
			for q in rr.randi_range(1, 3):
				Draw.circle(ci, pc + Vector2(rr.randf_range(-4, 4), rr.randf_range(-4, 4)), 1.6, Color("c43a28"))
	# a watering can
	var wc := r.end + Vector2(6, -6)
	Draw.circle(ci, wc, 3.5, Color("8a8680"))
	ci.draw_line(wc, wc + Vector2(6, -3), Color("8a8680"), 1.5)


static func _lounge(ci: CanvasItem, pr: Dictionary) -> void:
	var r: Rect2 = pr["r"]
	var rr := W.rng(int(pr["seed"]) * 29)
	# "tar beach": a blanket, a deck chair, a crate for a table
	var blanket := Rect2(r.position, Vector2(r.size.x * 0.55, r.size.y))
	var bc: Color = [Color("8a2e2a"), Color("2e4a6a"), Color("6a6a3a")][rr.randi_range(0, 2)]
	ci.draw_rect(blanket, bc)
	var sq := 6.0
	var x := blanket.position.x
	while x < blanket.end.x:
		ci.draw_line(Vector2(x, blanket.position.y), Vector2(x, blanket.end.y), Color(1, 1, 1, 0.14), 2.0)
		x += sq * 2
	var y := blanket.position.y
	while y < blanket.end.y:
		ci.draw_line(Vector2(blanket.position.x, y), Vector2(blanket.end.x, y), Color(1, 1, 1, 0.14), 2.0)
		y += sq * 2
	# deck chair: a frame with a striped canvas sling
	var chair := Rect2(Vector2(blanket.end.x + 6, r.position.y + 2), Vector2(r.size.x * 0.3, r.size.y - 4))
	FX.box_shadow(ci, chair, FX.sh(0.6), 0.22)
	ci.draw_rect(chair, Color("7a6248"))
	var sling := chair.grow(-2.0)
	var stripes := 5
	for k in stripes:
		var sx := sling.position.x + sling.size.x * k / stripes
		ci.draw_rect(Rect2(sx, sling.position.y, sling.size.x / stripes, sling.size.y), Pal.AWNING_CREAM if k % 2 == 0 else Color("3a6a8a"))
	FX.quad(ci, sling.position, Vector2(sling.end.x, sling.position.y), Vector2(sling.end.x, sling.get_center().y), Vector2(sling.position.x, sling.get_center().y),
		Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.18), Color(0, 0, 0, 0.18))
	# a bottle and a cap on the blanket
	Draw.circle(ci, blanket.position + Vector2(8, 8), 2.6, Color("2a4a2a"))
	Draw.circle(ci, blanket.end - Vector2(9, 9), 4.0, Color("5a4a3a"))


static func _junk(ci: CanvasItem, pr: Dictionary) -> void:
	var c: Vector2 = pr["c"]
	var rot: float = pr["rot"]
	match int(pr["k"]):
		0:
			# loose bricks
			for k in 3:
				ci.draw_set_transform(c + Vector2(k * 5 - 5, (k % 2) * 4), rot + k * 0.4, Vector2.ONE)
				ci.draw_rect(Rect2(-5.5, -2.7, 11, 5.4), Pal.BRICK.lightened(0.05))
				ci.draw_rect(Rect2(-5.5, -2.7, 11, 1.5), Pal.BRICK.lightened(0.2))
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		1:
			# a tar bucket
			Draw.circle(ci, c + FX.sh(0.5), 6.0, Color(FX.SHADE, 0.3))
			Draw.circle(ci, c, 6.0, Color("5a5550"))
			Draw.circle(ci, c, 4.8, Color("141210"))
			ci.draw_arc(c, 7.0, rot, rot + PI, 10, Color("3a3632"), 1.0, true)
		2:
			# a broken chair
			ci.draw_set_transform(c, rot, Vector2.ONE)
			ci.draw_rect(Rect2(-7, -7, 14, 14), Color("5a4232"))
			ci.draw_rect(Rect2(-7, -7, 14, 3), Color("7a5a42"))
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_:
			# a crate
			ci.draw_set_transform(c, rot, Vector2.ONE)
			ci.draw_rect(Rect2(-9 + 2, -9 + 3, 18, 18), Color(FX.SHADE, 0.3))
			ci.draw_rect(Rect2(-9, -9, 18, 18), Color("8a6a48"))
			ci.draw_rect(Rect2(-9, -9, 18, 18), Color("4a3828"), false, 1.5)
			ci.draw_line(Vector2(-9, -9), Vector2(9, 9), Color("4a3828"), 1.2)
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _monitor(ci: CanvasItem, pr: Dictionary) -> void:
	var r: Rect2 = pr["r"]
	var along: Vector2 = pr["along"]
	var horiz := absf(along.x) > 0.5
	var wv := M(0.35)
	ci.draw_rect(r, Color("3a3430"))
	# clerestory windows along both long sides
	var glass := Pal.SKYLIGHT.darkened(0.1)
	var a := Rect2(r.position, Vector2(r.size.x, wv)) if horiz else Rect2(r.position, Vector2(wv, r.size.y))
	var b := Rect2(Vector2(r.position.x, r.end.y - wv), Vector2(r.size.x, wv)) if horiz else Rect2(Vector2(r.end.x - wv, r.position.y), Vector2(wv, r.size.y))
	ci.draw_rect(a, glass.lightened(0.15))
	ci.draw_rect(b, glass.darkened(0.15))
	for w in [a, b]:
		var wr := w as Rect2
		var n := int((wr.size.x if horiz else wr.size.y) / M(0.5))
		for k in range(1, n):
			if horiz:
				var x := wr.position.x + wr.size.x * k / n
				ci.draw_line(Vector2(x, wr.position.y), Vector2(x, wr.end.y), Color("2a2622"), 1.0)
			else:
				var y := wr.position.y + wr.size.y * k / n
				ci.draw_line(Vector2(wr.position.x, y), Vector2(wr.end.x, y), Color("2a2622"), 1.0)
	# its tar roof, with a ridge
	var roof := Rect2(a.end.x if not horiz else r.position.x, a.end.y if horiz else r.position.y, 0, 0)
	if horiz:
		roof = Rect2(Vector2(r.position.x, a.end.y), Vector2(r.size.x, b.position.y - a.end.y))
		FX.quad(ci, roof.position, Vector2(roof.end.x, roof.position.y), Vector2(roof.end.x, roof.get_center().y), Vector2(roof.position.x, roof.get_center().y),
			Pal.TAR_2.lightened(0.12), Pal.TAR_2.lightened(0.12), Pal.TAR_2.lightened(0.04), Pal.TAR_2.lightened(0.04))
		FX.quad(ci, Vector2(roof.position.x, roof.get_center().y), Vector2(roof.end.x, roof.get_center().y), roof.end, Vector2(roof.position.x, roof.end.y),
			Pal.TAR_2.darkened(0.1), Pal.TAR_2.darkened(0.1), Pal.TAR_2.darkened(0.2), Pal.TAR_2.darkened(0.2))
		ci.draw_line(Vector2(roof.position.x, roof.get_center().y), Vector2(roof.end.x, roof.get_center().y), Color(1, 1, 1, 0.15), 1.5)
	else:
		roof = Rect2(Vector2(a.end.x, r.position.y), Vector2(b.position.x - a.end.x, r.size.y))
		FX.quad(ci, roof.position, Vector2(roof.get_center().x, roof.position.y), Vector2(roof.get_center().x, roof.end.y), Vector2(roof.position.x, roof.end.y),
			Pal.TAR_2.lightened(0.12), Pal.TAR_2.lightened(0.04), Pal.TAR_2.lightened(0.04), Pal.TAR_2.lightened(0.12))
		FX.quad(ci, Vector2(roof.get_center().x, roof.position.y), Vector2(roof.end.x, roof.position.y), roof.end, Vector2(roof.get_center().x, roof.end.y),
			Pal.TAR_2.darkened(0.1), Pal.TAR_2.darkened(0.2), Pal.TAR_2.darkened(0.2), Pal.TAR_2.darkened(0.1))
		ci.draw_line(Vector2(roof.get_center().x, roof.position.y), Vector2(roof.get_center().x, roof.end.y), Color(1, 1, 1, 0.15), 1.5)
	ci.draw_rect(r, Color(0.06, 0.05, 0.05, 0.9), false, 1.5)


# ----- fire escapes

static func _fire_escape(ci: CanvasItem, fe: Dictionary, top: bool) -> void:
	var ff: Transform2D = fe["fr"]
	var s0: float = fe["s0"]
	var s1: float = fe["s1"]
	var d := M(FE_DEPTH)
	var pr := func(a: float, b: float) -> Vector2: return ff * Vector2(a, b)
	if top:
		# the gooseneck ladder over the parapet to the roof
		var gs: float = (s0 + M(0.35)) if not fe["stair_left"] else (s1 - M(0.35))
		for side in [-4.0, 4.0]:
			ci.draw_line(pr.call(gs + side, d * 0.55), pr.call(gs + side, -M(0.75)), IRON, 1.6, true)
			ci.draw_line(pr.call(gs + side - 0.8, d * 0.55), pr.call(gs + side - 0.8, -M(0.75)), IRON_HI, 0.8, true)
		var t := d * 0.5
		while t > -M(0.7):
			ci.draw_line(pr.call(gs - 4.0, t), pr.call(gs + 4.0, t), IRON, 1.2, true)
			t -= 6.0
		return
	# the shadow of the lowest platform on the sidewalk, far below
	var shadow_off := FX.sh(4.2)
	var sp := PackedVector2Array([pr.call(s0, 0.0) + shadow_off, pr.call(s1, 0.0) + shadow_off, pr.call(s1, d) + shadow_off, pr.call(s0, d) + shadow_off])
	Draw.poly(ci, sp, Color(FX.SHADE, 0.13), false)
	# grated deck: slats you can see the street through
	var deck := PackedVector2Array([pr.call(s0, 0.0), pr.call(s1, 0.0), pr.call(s1, d), pr.call(s0, d)])
	Draw.poly(ci, deck, Color(IRON, 0.42), false)
	var t := 3.0
	while t < d:
		ci.draw_line(pr.call(s0, t), pr.call(s1, t), Color(IRON, 0.85), 1.0)
		t += 4.0
	# the stairwell opening down to the next landing, with its treads
	var st0: float = (s1 - M(1.5)) if fe["stair_left"] else (s0 + M(0.3))
	var st1 := st0 + M(1.2)
	var hole := PackedVector2Array([pr.call(st0, M(0.3)), pr.call(st1, M(0.3)), pr.call(st1, d - M(0.15)), pr.call(st0, d - M(0.15))])
	Draw.poly(ci, hole, Color(0.05, 0.05, 0.06, 0.55), false)
	var s := st0 + 4.0
	while s < st1 - 1.0:
		ci.draw_line(pr.call(s, M(0.32)), pr.call(s, d - M(0.17)), Color(IRON_HI, 0.9), 1.5)
		s += 7.0
	ci.draw_line(pr.call(st0, M(0.3)), pr.call(st1, d - M(0.15)), IRON, 2.0, true)
	# the railing round the outside, lit on its north-west sides
	var rail := PackedVector2Array([pr.call(s0, 0.0), pr.call(s0, d), pr.call(s1, d), pr.call(s1, 0.0)])
	ci.draw_polyline(rail, IRON, 3.0, true)
	var rail_hi := rail.duplicate()
	for i in rail_hi.size():
		rail_hi[i] += Vector2(-0.8, -0.8)
	ci.draw_polyline(rail_hi, Color(IRON_HI, 0.8), 1.0, true)
	# balusters
	var b := s0 + 8.0
	while b < s1 - 2.0:
		Draw.circle(ci, pr.call(b, d), 1.4, IRON_HI)
		b += 9.0
	# the drop ladder, hooked up at the far end
	var la: float = (s0 + M(0.12)) if fe["stair_left"] else (s1 - M(0.5))
	var lb := la + M(0.38)
	ci.draw_line(pr.call(la, d - 2.0), pr.call(la, d + M(0.28)), IRON, 1.5, true)
	ci.draw_line(pr.call(lb, d - 2.0), pr.call(lb, d + M(0.28)), IRON, 1.5, true)
	var q := d + 2.0
	while q < d + M(0.28):
		ci.draw_line(pr.call(la, q), pr.call(lb, q), IRON, 1.0)
		q += 4.0
	# a pot of geraniums, a mop: someone lives here
	var r := W.rng(int(fe["seed"]))
	if r.randf() < 0.55:
		var pp: Vector2 = pr.call(lerpf(s0, s1, r.randf_range(0.35, 0.65)), d * 0.45)
		Draw.circle(ci, pp, 5.0, Color("9a5a3a"))
		Draw.circle(ci, pp + Vector2(-0.5, -0.5), 3.6, Color("4a6a32"))
		for k in 3:
			Draw.circle(ci, pp + Vector2(r.randf_range(-3, 3), r.randf_range(-3, 3)), 1.4, Color("d0404a"))


# ----- washing lines

static func _line_shadow(ci: CanvasItem, ln: Dictionary) -> void:
	var a: Vector2 = ln["a"]
	var b: Vector2 = ln["b"]
	var off := FX.sh(1.6)
	ci.draw_line(a + off, b + off, Color(FX.SHADE, 0.16), 1.0, true)
	for it in _laundry(ln):
		var poly: PackedVector2Array = it[0]
		var sp := PackedVector2Array()
		for q in poly:
			sp.append(q + off)
		Draw.poly(ci, sp, Color(FX.SHADE, 0.2), false)


static func _line(ci: CanvasItem, ln: Dictionary) -> void:
	var a: Vector2 = ln["a"]
	var b: Vector2 = ln["b"]
	for pair in [[a, ln["pa"]], [b, ln["pb"]]]:
		if pair[1]:
			var q: Vector2 = pair[0]
			ci.draw_line(q, q + FX.sh(2.0), Color(FX.SHADE, 0.25), 2.5, true)
			ci.draw_rect(Rect2(q - Vector2(2.5, 2.5), Vector2(5, 5)), Color("4e3e30"))
			ci.draw_rect(Rect2(q - Vector2(2.5, 2.5), Vector2(5, 1.5)), Color("7a6248"))
	ci.draw_line(a, b, Color("d8d0c0", 0.8), 1.0, true)
	for it in _laundry(ln):
		var poly: PackedVector2Array = it[0]
		var col: Color = it[1]
		Draw.poly(ci, poly, col)
		# a fold: the lower half a little darker
		var c := (poly[0] + poly[1] + poly[2] + poly[3]) * 0.25
		ci.draw_line((poly[0] + poly[3]) * 0.5, (poly[1] + poly[2]) * 0.5, col.darkened(0.14), 1.0)
		Draw.circle(ci, poly[0].lerp(poly[1], 0.12), 1.2, Color("6b5642"))
		Draw.circle(ci, poly[0].lerp(poly[1], 0.88), 1.2, Color("6b5642"))
		ci.draw_line(poly[3], poly[2], col.darkened(0.3), 1.0)
		var _u := c


## The washing on a line: [[quad, colour], ...], deterministic, hanging "down" the screen a little.
static func _laundry(ln: Dictionary) -> Array:
	var a: Vector2 = ln["a"]
	var b: Vector2 = ln["b"]
	var out := []
	var len := a.distance_to(b)
	if len < 30.0:
		return out
	var dir := (b - a) / len
	var down := dir.orthogonal()
	if down.y < 0.0:
		down = -down
	var r := W.rng(int(ln["seed"]))
	var t := r.randf_range(10.0, 22.0)
	while t < len - 16.0:
		var w := r.randf_range(10.0, 30.0)
		if t + w > len - 8.0:
			break
		var h := r.randf_range(5.0, 11.0)
		var p0 := a + dir * t
		var p1 := a + dir * (t + w)
		var col: Color = LAUNDRY[r.randi_range(0, LAUNDRY.size() - 1)]
		out.append([PackedVector2Array([p0, p1, p1 + down * h, p0 + down * h]), col])
		t += w + r.randf_range(3.0, 14.0)
	return out
