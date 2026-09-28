class_name GroundLayout
extends RefCounted
## Where everything on the ground goes, as plain data (metres for geometry, pixels in "p" of props).
## Built once from the CityPlan, deterministic from its seed.
##
## Sidewalk zoning, measured from a building's front wall toward the curb (3.5 m):
##   0 .. 1.6  frontage (Shopfronts' awnings and stands; only low flat things here, and only in
##             front of homes: cellar doors, coal chutes, gratings, stoops)
##   1.6 .. 2.6 walking lane: kept clear
##   2.6 .. 3.5 furniture at the curb: lamps, hydrants, mailboxes, boxes, cans, benches, stands, trees
## Within 4 m of a block corner only lamps and hydrants; the crossing landings stay clear;
## nothing within 1.2 m either side of a door.

const P := CityPlan.PITCH
const HALF := CityPlan.STREET * 0.5
const SW := CityPlan.SIDEWALK
const FRONT := 1.6
const WALK := 2.6
const CORNER := 4.0
const LANDING := 3.8
const DOOR_CLEAR := 1.2
const CURB_R := 1.2                 # rounded curb corners
const GROW := 26.0                  # how far past plan.bounds the ground is drawn (camera margin)

const COBBLE_NS := [0, 1, 3]        # Mulberry, Mott, Eldridge
const BOWERY := 2
const ORCHARD := 4
const BUSY_EW := [0, 3, 4]          # Houston, Grand, Canal: newsstands, more traffic wear

var plan: CityPlan
var seed_value := 0
var area := Rect2()                 # metres: what the ground covers
var segs: Array = []                # street segments
var isecs: Array = []               # intersections
var blocks: Array = []              # real and phantom blocks
var quay := {}                      # quay and piers layout
var lights: Array = []
var solids: Array = []
var vents: Array = []               # manholes that steam at night (px)
var parking: Array = []             # [{pos: px, rot}] free curb-lane spots
var _trough_done := false


func build(p: CityPlan) -> void:
	plan = p
	seed_value = p.seed_value
	area = p.bounds.grow(GROW)
	_streets()
	_blocks()
	for b in blocks:
		_block_flats(b)
		_block_props(b)
	_orchard_market()
	_link_wires()
	_parking()
	_collect()


# ---------------------------------------------------------------- streets

func _streets() -> void:
	var top := area.position.y
	var bottom := area.end.y
	var left := area.position.x
	var quay_x: float = plan.quay_rect[0]
	# north-south streets
	for i in CityPlan.NX + 1:
		var c := i * P
		var spans := [[top, -HALF]]
		for j in CityPlan.NZ:
			spans.append([j * P + HALF, (j + 1) * P - HALF])
		spans.append([CityPlan.NZ * P + HALF, bottom])
		for k in spans.size():
			var u0: float = spans[k][0]
			var u1: float = spans[k][1]
			var kind := "cobble" if i in COBBLE_NS else ("bowery" if i == BOWERY else "asphalt")
			segs.append({"ns": true, "idx": i, "c": c, "u0": u0, "u1": u1, "kind": kind,
				"cw0": k > 0, "cw1": k < spans.size() - 1, "seed": GroundUtil.hseed(seed_value, i * 31 + k, 1),
				"props": [], "manholes": []})
	# east-west streets
	for j in CityPlan.NZ + 1:
		var c := j * P
		var spans := [[left, -HALF]]
		for i in CityPlan.NX:
			spans.append([i * P + HALF, (i + 1) * P - HALF])
		for k in spans.size():
			segs.append({"ns": false, "idx": j, "c": c, "u0": spans[k][0], "u1": spans[k][1], "kind": "asphalt",
				"cw0": k > 0, "cw1": true, "seed": GroundUtil.hseed(seed_value, j * 37 + k, 2),
				"props": [], "manholes": []})
	for i in CityPlan.NX + 1:
		for j in CityPlan.NZ + 1:
			isecs.append({"i": i, "j": j, "r": Rect2(i * P - HALF, j * P - HALF, HALF * 2.0, HALF * 2.0),
				"seed": GroundUtil.hseed(seed_value, i * 13 + j, 3), "bowery": i == BOWERY,
				"quay": i == CityPlan.NX})
	# the north and south ends of the Bowery tracks and the other streets run on off the map;
	# the quay side of West St. has no crossings to a block, but it gets them to the quay
	for s in segs:
		var sd: int = s["seed"]
		# manholes on the centre line, one or two per segment
		var l: float = float(s["u1"]) - float(s["u0"])
		var n := 1 if l < 30.0 else (1 + int(GroundUtil.r01(sd, 5) < 0.6))
		for k in n:
			var u := lerpf(float(s["u0"]) + 7.0, float(s["u1"]) - 7.0, (float(k) + 0.5) / float(n) + GroundUtil.rr(sd, 6 + k, -0.15, 0.15))
			var v := GroundUtil.rr(sd, 9 + k, -1.4, 1.4)
			if s["kind"] == "bowery":
				v = 0.0 if GroundUtil.r01(sd, 12) < 0.5 else GroundUtil.rr(sd, 13, 3.6, 4.6) * (1.0 if GroundUtil.r01(sd, 14) < 0.5 else -1.0)
			s["manholes"].append([u, v])
			var world := seg_point(s, u, v)
			if area.grow(-GROW).has_point(world) and GroundUtil.r01(sd, 20 + k) < 0.42:
				vents.append(world * W.M)
	for x in isecs:
		var r: Rect2 = x["r"]
		var sd: int = x["seed"]
		var off := Vector2(GroundUtil.rr(sd, 1, -2.5, 2.5), GroundUtil.rr(sd, 2, -2.5, 2.5))
		if x["bowery"]:
			off.x = GroundUtil.rr(sd, 1, 3.8, 4.6) * (1.0 if off.x > 0.0 else -1.0)
		x["manhole"] = r.get_center() + off
		if GroundUtil.r01(sd, 3) < 0.3:
			vents.append((r.get_center() + off) * W.M)


## A point of segment `s` at distance u along it and v across (metres, v = 0 on the centre line).
static func seg_point(s: Dictionary, u: float, v: float) -> Vector2:
	if s["ns"]:
		return Vector2(float(s["c"]) + v, u)
	return Vector2(u, float(s["c"]) + v)


static func seg_rect(s: Dictionary, u0: float, v0: float, u1: float, v1: float) -> Rect2:
	var a := seg_point(s, u0, v0)
	var b := seg_point(s, u1, v1)
	return Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (b - a).abs())


# ---------------------------------------------------------------- blocks and sides

func _blocks() -> void:
	var by_block := {}
	for lot in plan.lots:
		var key := Vector2i(int(lot["block"][0]), int(lot["block"][1]))
		by_block.get_or_add(key, []).append(lot)
	for b in plan.blocks:
		var r: Array = b["rect"]
		var rect := Rect2(float(r[0]), float(r[1]), float(r[2]) - float(r[0]), float(r[3]) - float(r[1]))
		var key := Vector2i(int(b["i"]), int(b["j"]))
		blocks.append(_make_block(int(b["i"]), int(b["j"]), rect, by_block.get(key, []), false))
	# phantom blocks around the map: the far side of the edge streets (sidewalks, lamps; the
	# buildings on them are drawn by the outskirts layer)
	var top := area.position.y
	var bottom := area.end.y
	var left := area.position.x
	for j in range(-1, CityPlan.NZ + 1):
		var z0 := top if j == -1 else j * P + HALF
		var z1 := -HALF if j == -1 else (bottom if j == CityPlan.NZ else (j + 1) * P - HALF)
		blocks.append(_make_block(-1, j, Rect2(left, z0, -HALF - left, z1 - z0), [], true))
	for i in CityPlan.NX:
		blocks.append(_make_block(i, -1, Rect2(i * P + HALF, top, P - HALF * 2.0, -HALF - top), [], true))
		blocks.append(_make_block(i, CityPlan.NZ, Rect2(i * P + HALF, CityPlan.NZ * P + HALF, P - HALF * 2.0, bottom - CityPlan.NZ * P - HALF), [], true))


func _make_block(i: int, j: int, rect: Rect2, lots: Array, phantom: bool) -> Dictionary:
	var b := {"i": i, "j": j, "r": rect, "phantom": phantom, "seed": GroundUtil.hseed(seed_value, i + 20, j + 20),
		"lots": [], "yard": {}, "sides": {}, "flats": [], "props": [], "street_ns": [i, i + 1], "street_ew": [j, j + 1]}
	for lot in lots:
		if lot["kind"] == "courtyard":
			b["yard"] = lot
		else:
			b["lots"].append(lot)
	for s: String in ["N", "S", "W", "E"]:
		b["sides"][s] = _make_side(b, s)
	return b


func _make_side(b: Dictionary, s: String) -> Dictionary:
	var r: Rect2 = b["r"]
	var side := {"s": s, "lots": [], "walls": []}
	match s:
		"N":
			side.merge({"a0": r.position.x, "a1": r.end.x, "wall": r.position.y + SW, "curb": r.position.y, "out": Vector2(0, -1)})
		"S":
			side.merge({"a0": r.position.x, "a1": r.end.x, "wall": r.end.y - SW, "curb": r.end.y, "out": Vector2(0, 1)})
		"W":
			side.merge({"a0": r.position.y, "a1": r.end.y, "wall": r.position.x + SW, "curb": r.position.x, "out": Vector2(-1, 0)})
		"E":
			side.merge({"a0": r.position.y, "a1": r.end.y, "wall": r.end.x - SW, "curb": r.end.x, "out": Vector2(1, 0)})
	# lots whose front is on this side, and stretches of wall (front or side wall) with their lot
	for lot in b["lots"]:
		var lr := _lot_m(lot)
		if lot["side"] == s:
			var a := float(lot["center"][0]) if s in ["N", "S"] else float(lot["center"][1])
			var w := float(lot["size"][0])
			side["lots"].append(lot)
			side["walls"].append({"a0": a - w * 0.5, "a1": a + w * 0.5, "lot": lot, "front": true, "door": a})
		else:
			# a corner lot's side wall on this side?
			var on := false
			match s:
				"N": on = absf(lr.position.y - float(side["wall"])) < 0.05
				"S": on = absf(lr.end.y - float(side["wall"])) < 0.05
				"W": on = absf(lr.position.x - float(side["wall"])) < 0.05
				"E": on = absf(lr.end.x - float(side["wall"])) < 0.05
			if on:
				var a0 := lr.position.x if s in ["N", "S"] else lr.position.y
				var a1 := lr.end.x if s in ["N", "S"] else lr.end.y
				side["walls"].append({"a0": a0, "a1": a1, "lot": lot, "front": false, "door": INF})
	return side


static func _lot_m(lot: Dictionary) -> Rect2:
	var r := W.lot_rect(lot)
	return Rect2(r.position / W.M, r.size / W.M)


## A point on a side at `a` along it, `d` metres out from the wall toward the curb.
static func side_point(side: Dictionary, a: float, d: float) -> Vector2:
	var out: Vector2 = side["out"]
	var base := Vector2(a, float(side["wall"])) if side["s"] in ["N", "S"] else Vector2(float(side["wall"]), a)
	return base + out * d


static func side_rot(side: Dictionary) -> float:
	return (side["out"] as Vector2).angle() - PI * 0.5


func _wall_at(side: Dictionary, a: float) -> Dictionary:
	for w in side["walls"]:
		if a >= float(w["a0"]) - 0.01 and a <= float(w["a1"]) + 0.01:
			return w
	return {}


func _doors(side: Dictionary) -> Array:
	var out := []
	for w in side["walls"]:
		if w["front"]:
			out.append(float(w["door"]))
	return out


# ---------------------------------------------------------------- frontage: stoops, cellar doors...

func _block_flats(b: Dictionary) -> void:
	var sd: int = b["seed"]
	var k := 0
	for s: String in ["N", "S", "W", "E"]:
		var side: Dictionary = b["sides"][s]
		var rot := side_rot(side)
		for w in side["walls"]:
			k += 1
			var lot: Dictionary = w["lot"]
			if lot["shop"]:
				continue
			var ls := GroundUtil.hseed(sd, int(lot["id"]), 7)
			var a0: float = float(w["a0"]) + 0.35
			var a1: float = float(w["a1"]) - 0.35
			var taken := []
			if w["front"]:
				var ad: float = w["door"]
				var style := int(lot["style"])
				b["flats"].append({"t": "stoop", "a": ad, "side": s, "p": side_point(side, ad, 0.0) * W.M, "rot": rot,
					"w": 1.9, "d": 1.35, "style": style, "s": ls})
				taken.append([ad - DOOR_CLEAR, ad + DOOR_CLEAR])
				# an areaway (the sunken way down to the basement) beside the stoop
				if GroundUtil.r01(ls, 1) < 0.55:
					var dir := 1.0 if GroundUtil.r01(ls, 2) < 0.5 else -1.0
					var ac := ad + dir * (DOOR_CLEAR + 0.8)
					if ac - 0.75 > a0 and ac + 0.75 < a1:
						b["flats"].append({"t": "areaway", "side": s, "p": side_point(side, ac, 0.0) * W.M, "rot": rot,
							"w": 1.45, "d": 1.25, "s": ls + 1, "flip": dir})
						taken.append([ac - 0.8, ac + 0.8])
			# cellar doors, vault lights, coal chutes, gratings in what is left of the frontage
			var kinds := ["cellar", "vault", "chute", "grating", "cellar", "chute"]
			var tries := 3 if w["front"] else 2
			for t in tries:
				var kind: String = kinds[GroundUtil.ri(ls, 10 + t, 0, kinds.size() - 1)]
				if GroundUtil.r01(ls, 20 + t) > (0.75 if t == 0 else 0.4):
					continue
				var size := {"cellar": Vector2(1.25, 1.05), "vault": Vector2(1.3, 0.75), "chute": Vector2(0.5, 0.5),
					"grating": Vector2(1.1, 0.55)}[kind] as Vector2
				var ac := GroundUtil.rr(ls, 30 + t, a0 + size.x * 0.5, a1 - size.x * 0.5)
				if a1 - a0 < size.x:
					continue
				var ok := true
				for iv in taken:
					if ac + size.x * 0.5 + 0.25 > float(iv[0]) and ac - size.x * 0.5 - 0.25 < float(iv[1]):
						ok = false
						break
				if not ok:
					continue
				taken.append([ac - size.x * 0.5, ac + size.x * 0.5])
				var d := size.y * 0.5 + (0.0 if kind == "cellar" else GroundUtil.rr(ls, 40 + t, 0.1, 0.4))
				b["flats"].append({"t": kind, "side": s, "p": side_point(side, ac, d) * W.M, "rot": rot, "size": size,
					"s": ls + 50 + t})
	# storm drains in the gutter near the corners (on the upstream side of each crossing)
	for s: String in ["N", "S", "W", "E"]:
		var side: Dictionary = b["sides"][s]
		for end in 2:
			if GroundUtil.r01(sd, 60 + k + end) < 0.35:
				continue
			k += 1
			var a := float(side["a0"]) + 5.2 if end == 0 else float(side["a1"]) - 5.2
			var pos := side_point(side, a, SW + 0.28)
			b["flats"].append({"t": "drain", "side": s, "p": pos * W.M, "rot": side_rot(side), "s": sd + k})


# ---------------------------------------------------------------- street furniture

const FOOT := {
	"lamp": Vector2(0.4, 0.4), "hydrant": Vector2(0.55, 0.4), "mailbox": Vector2(0.52, 0.44),
	"callbox": Vector2(0.34, 0.32), "alarm": Vector2(0.32, 0.32), "ashcans": Vector2(0.52, 0.52),
	"bench": Vector2(1.75, 0.58), "newsstand": Vector2(1.95, 0.86), "tree": Vector2(0.95, 0.8),
	"trough": Vector2(2.3, 0.75), "hitch": Vector2(0.25, 0.25), "basket": Vector2(0.42, 0.42),
	"bike": Vector2(1.75, 0.5), "sign": Vector2(0.3, 0.3), "pole": Vector2(0.36, 0.36),
}
const HEIGHT := {"lamp": 4.2, "hydrant": 0.75, "mailbox": 1.1, "callbox": 1.55, "alarm": 1.8, "ashcans": 0.7,
	"bench": 0.8, "newsstand": 2.3, "tree": 5.5, "trough": 0.65, "hitch": 1.0, "basket": 0.8, "bike": 0.9}


func _block_props(b: Dictionary) -> void:
	var sd: int = b["seed"]
	for s: String in ["N", "S", "W", "E"]:
		b["sides"][s]["used"] = []
	# trolley poles along the Bowery, holding up the span wires over the tracks
	var bow_side := "W" if int(b["i"]) == BOWERY else ("E" if int(b["i"]) + 1 == BOWERY else "")
	if bow_side != "":
		var bside: Dictionary = b["sides"][bow_side]
		var u := float(bside["a0"]) + 9.0
		var wk := 0
		while u < float(bside["a1"]) - 5.0:
			for o: float in [0.0, 0.6, -0.6, 1.2, -1.2, 1.8, -1.8, 2.5, -2.5]:
				if _place_at(b, bow_side, "pole", u + o, sd + 900 + wk, {"wire": wk}):
					break
			u += 18.0
			wk += 1
	# lamps at the corners: each corner gets one, on one of its two sides, just past the landing
	var corners := {"NW": ["N", 0, "W", 0], "NE": ["N", 1, "E", 0], "SE": ["S", 1, "E", 1], "SW": ["S", 0, "W", 1]}
	var ck := 0
	for cname in corners:
		ck += 1
		var c: Array = corners[cname]
		var first := GroundUtil.r01(sd, 100 + ck) < 0.5
		var ls: String = c[0] if first else c[2]
		var le: int = c[1] if first else c[3]
		var hs: String = c[2] if first else c[0]
		var he: int = c[3] if first else c[1]
		_try_place(b, ls, "lamp", le, [4.3, 4.7, 5.1, 5.6, 6.2, 6.8], sd + ck)
		# one street-name post per crossing: at the north-west corner of the block south-east of it
		# (and on the last row and column, the corners that have no such block)
		if not b["phantom"]:
			var want: bool = cname == "NW"
			if int(b["i"]) == CityPlan.NX - 1 and cname == "NE":
				want = true
			if int(b["j"]) == CityPlan.NZ - 1 and cname == "SW":
				want = true
			if int(b["i"]) == CityPlan.NX - 1 and int(b["j"]) == CityPlan.NZ - 1 and cname == "SE":
				want = true
			if want:
				_sign_post(b, String(cname))
		# hydrants at two of the four corners, on the other side
		if (ck % 2 == 0) == (GroundUtil.r01(sd, 110) < 0.5):
			_try_place(b, hs, "hydrant", he, [4.2, 4.6, 5.0, 5.5, 6.1], sd + ck + 7)
	# a lamp in the middle of each side, staggered with the one across the street
	for s: String in ["N", "S", "W", "E"]:
		var side: Dictionary = b["sides"][s]
		var mid := (float(side["a0"]) + float(side["a1"])) * 0.5 + (3.0 if s in ["N", "W"] else -3.0)
		var offs := [0.0, 0.8, -0.8, 1.6, -1.6, 2.4, -2.4, 3.2, -3.2, 4.2, -4.2]
		for o in offs:
			if _place_at(b, s, "lamp", mid + float(o), sd + 200):
				break
	if b["phantom"]:
		_fill(b, sd, true)
		return
	_fill(b, sd, false)


func _street_of(b: Dictionary, s: String) -> Dictionary:
	match s:
		"N": return {"ns": false, "idx": int(b["j"])}
		"S": return {"ns": false, "idx": int(b["j"]) + 1}
		"W": return {"ns": true, "idx": int(b["i"])}
	return {"ns": true, "idx": int(b["i"]) + 1}


func _sign_post(b: Dictionary, cname: String) -> void:
	var r: Rect2 = b["r"]
	var east := cname.ends_with("E")
	var south := cname.begins_with("S")
	var corner := Vector2(r.end.x if east else r.position.x, r.end.y if south else r.position.y)
	var inward := Vector2(-1.0 if east else 1.0, -1.0 if south else 1.0)
	var names := _corner_signs(b, cname)
	if names.is_empty():
		return
	b["props"].append({"t": "sign", "p": (corner + inward * 0.78) * W.M, "rot": 0.0, "s": int(b["seed"]) + cname.length(),
		"names": names, "in": inward, "foot": Vector2(0.12, 0.12)})


func _corner_signs(b: Dictionary, cname: String) -> Array:
	var i: int = b["i"] + (1 if cname.ends_with("E") else 0)
	var j: int = b["j"] + (1 if cname.begins_with("S") else 0)
	if i < 0 or i > CityPlan.NX or j < 0 or j > CityPlan.NZ:
		return []
	var ns: String = CityPlan.NS_STREETS[i]
	var ew: String = CityPlan.EW_STREETS[j]
	return [ns.to_upper(), ew.to_upper()]


func _try_place(b: Dictionary, s: String, t: String, end: int, dists: Array, ps: int) -> Dictionary:
	var side: Dictionary = b["sides"][s]
	for d in dists:
		var a := float(side["a0"]) + float(d) if end == 0 else float(side["a1"]) - float(d)
		if _place_at(b, s, t, a, ps):
			return b["props"][b["props"].size() - 1]
	return {}


## Is the furniture zone free at `a` for a thing of type t? Places it if so.
func _place_at(b: Dictionary, s: String, t: String, a: float, ps: int, extra: Dictionary = {}) -> bool:
	var side: Dictionary = b["sides"][s]
	var foot: Vector2 = FOOT.get(t, Vector2(0.5, 0.5))
	if extra.has("len"):
		foot.x = float(extra["len"])
	var lo := a - foot.x * 0.5
	var hi := a + foot.x * 0.5
	var a0: float = side["a0"]
	var a1: float = side["a1"]
	var near_corner := t in ["lamp", "hydrant", "pole"]
	var lim := LANDING if near_corner else CORNER
	if lo < a0 + lim or hi > a1 - lim:
		return false
	for ad in _doors(side):
		if hi > float(ad) - DOOR_CLEAR and lo < float(ad) + DOOR_CLEAR:
			return false
	for iv in side["used"]:
		if hi + 0.45 > float(iv[0]) and lo - 0.45 < float(iv[1]):
			return false
	# stay inside the drawn area
	var pos := side_point(side, a, 3.0)
	if not plan.bounds.grow(2.0).has_point(pos):
		return false
	side["used"].append([lo, hi])
	var d := 3.05 if near_corner else clampf(2.95, WALK + foot.y * 0.5 + 0.02, SW - 0.06 - foot.y * 0.5)
	if t == "tree":
		d = 2.98
	var prop := {"t": t, "p": side_point(side, a, d) * W.M, "rot": side_rot(side), "s": ps, "side": s, "a": a,
		"foot": foot}
	prop.merge(extra)
	b["props"].append(prop)
	return true


func _fill(b: Dictionary, sd: int, phantom: bool) -> void:
	var quota := {"mailbox": 1, "newsstand": 1, "alarm": 1, "callbox": 1 if (int(b["i"]) + int(b["j"])) % 2 == 0 else 0,
		"bench": 2, "tree": 1 if GroundUtil.r01(sd, 300) < 0.45 else 0, "basket": 2, "bike": 1 if GroundUtil.r01(sd, 301) < 0.35 else 0}
	if phantom:
		quota = {"mailbox": 0, "newsstand": 0, "alarm": 0, "callbox": 0, "bench": 0, "tree": 0, "basket": 1, "bike": 0}
	var k := 0
	var order := ["N", "E", "S", "W"]
	var start := GroundUtil.ri(sd, 302, 0, 3)
	for n in 4:
		var s: String = order[(start + n) % 4]
		var side: Dictionary = b["sides"][s]
		var st: Dictionary = _street_of(b, s)
		var busy: bool = (st["ns"] and int(st["idx"]) in [BOWERY, ORCHARD, 5]) or (not st["ns"] and int(st["idx"]) in BUSY_EW)
		var a := float(side["a0"]) + CORNER + GroundUtil.rr(sd, 310 + n, 0.2, 1.6)
		var a1 := float(side["a1"]) - CORNER
		while a < a1:
			k += 1
			var w := _wall_at(side, a)
			var home: bool = not w.is_empty() and not w["lot"]["shop"]
			var pick := _pick(sd + k * 13, quota, home, busy, phantom)
			if pick != "":
				var extra := {}
				if pick == "ashcans":
					var n_cans := GroundUtil.ri(sd, k * 7 + 1, 1, 3)
					extra = {"n": n_cans, "len": 0.52 * n_cans}
				if pick == "trough":
					extra = {}
				var foot: Vector2 = FOOT.get(pick, Vector2(0.5, 0.5))
				var len := float(extra.get("len", foot.x))
				if _place_at(b, s, pick, a + len * 0.5, sd + k * 29, extra):
					if quota.has(pick):
						quota[pick] = int(quota[pick]) - 1
					if pick == "trough":
						_trough_done = true
						_place_at(b, s, "hitch", a + len + 0.7, sd + k * 29 + 1)
					if pick == "newsstand":
						_place_at(b, s, "basket", a + len + 0.9, sd + k * 29 + 2)
					a += len + GroundUtil.rr(sd, k * 5 + 3, 1.6, 4.5)
					continue
			a += GroundUtil.rr(sd, k * 5 + 4, 0.9, 2.2)


func _pick(s: int, quota: Dictionary, home: bool, busy: bool, phantom: bool) -> String:
	var roll := GroundUtil.r01(s, 1)
	if phantom:
		return "ashcans" if roll < 0.28 else ("basket" if roll < 0.33 and int(quota["basket"]) > 0 else "")
	if not _trough_done and GroundUtil.r01(s, 2) < 0.06:
		return "trough"
	var bag := []
	if home:
		bag.append_array(["ashcans", "ashcans", "ashcans", "", ""])
	else:
		bag.append_array(["", "", "basket"])
	if busy:
		bag.append_array(["newsstand", "newsstand", "bench"])
	bag.append_array(["mailbox", "alarm", "callbox", "bench", "tree", "tree", "bike", "hitch"])
	for tries in 4:
		var t: String = bag[GroundUtil.ri(s, 10 + tries, 0, bag.size() - 1)]
		if t == "":
			return ""
		if quota.has(t) and int(quota[t]) <= 0:
			continue
		if t == "hitch" and GroundUtil.r01(s, 30) < 0.6:
			continue
		return t
	return ""


# ---------------------------------------------------------------- Orchard St. pushcart market

var _lamp_heads: Array = []     # metres, filled before the market is laid out


func _orchard_market() -> void:
	for b in blocks:
		for p in b["props"]:
			if p["t"] == "lamp":
				_lamp_heads.append((p["p"] as Vector2) / W.M + Vector2(0, 1).rotated(float(p["rot"])) * 1.12)
	var goods := ["fruit", "fruit", "veg", "veg", "pots", "cloth", "hats", "shoes", "fish", "bread", "notions", "fruit"]
	for s in segs:
		var market: bool = s["ns"] and int(s["idx"]) == ORCHARD
		var few: bool = s["ns"] and int(s["idx"]) == 0
		if not (market or few):
			continue
		if float(s["u0"]) < -1.0 or float(s["u1"]) > CityPlan.NZ * P:
			continue
		var sd: int = s["seed"]
		for side: float in [-1.0, 1.0]:
			var u := float(s["u0"]) + 4.6 + GroundUtil.rr(sd, int(side) + 5, 0.0, 1.5)
			var k := 0
			while u < float(s["u1"]) - 4.6 - 2.8:
				k += 1
				var ks := sd + k * 17 + int(side * 3.0)
				var v := side * (HALF - 0.32 - 0.5)
				var pos := seg_point(s, u + 1.4, v)
				var clear := true
				for h in _lamp_heads:
					if (h as Vector2).distance_to(pos) < 2.2:
						clear = false
				if not clear:
					u += 1.0
					continue
				if market or GroundUtil.r01(ks, 1) < 0.22:
					# carts stand with their handles toward the kerb side's traffic flow
					var rot := PI * 0.5 if s["ns"] else 0.0
					if side < 0.0:
						rot += PI
					var g: String = goods[GroundUtil.ri(ks, 2, 0, goods.size() - 1)]
					s["props"].append({"t": "pushcart", "p": pos * W.M, "rot": rot, "s": ks, "goods": g,
						"umbrella": GroundUtil.r01(ks, 3) < 0.3, "basket": GroundUtil.r01(ks, 4) < 0.5})
					u += 2.9 + GroundUtil.rr(ks, 5, 0.2, 0.9)
					if not market:
						u += 6.0
				else:
					u += 3.0


## Pair the trolley poles across the Bowery into span wires: s["spans"] = [[west px, east px]].
func _link_wires() -> void:
	for s in segs:
		if s["kind"] != "bowery":
			continue
		var pairs := {}
		for b in blocks:
			var bi: int = b["i"]
			if bi != BOWERY and bi + 1 != BOWERY:
				continue
			var side: Dictionary = b["sides"]["W" if bi == BOWERY else "E"]
			if absf(float(side["a0"]) - float(s["u0"])) > 0.5:
				continue
			for p in b["props"]:
				if p["t"] == "pole":
					var k: int = p["wire"]
					var pr: Array = pairs.get_or_add(k, [Vector2.INF, Vector2.INF])
					pr[1 if bi == BOWERY else 0] = p["p"]
		var spans := []
		for k in pairs:
			var pr: Array = pairs[k]
			if pr[0] != Vector2.INF and pr[1] != Vector2.INF:
				spans.append(pr)
		s["spans"] = spans


# ---------------------------------------------------------------- parking spots

func _parking() -> void:
	var inner := plan.bounds
	for s in segs:
		if s["ns"] and int(s["idx"]) in [ORCHARD, CityPlan.NX]:
			continue
		var sd: int = s["seed"]
		for side: float in [-1.0, 1.0]:
			var u := float(s["u0"]) + 6.0
			var k := 0
			while u < float(s["u1"]) - 9.0:
				k += 1
				var pos := seg_point(s, u + 2.2, side * (HALF - 1.1))
				var ok := inner.grow(-2.0).has_point(pos)
				for p in s["props"]:
					if (p["p"] as Vector2).distance_to(pos * W.M) < 3.5 * W.M:
						ok = false
				if ok and GroundUtil.r01(sd, k * 3 + int(side)) < 0.55:
					var rot := PI * 0.5 if s["ns"] else 0.0
					if side < 0.0:
						rot += PI
					parking.append({"pos": pos * W.M, "rot": rot})
				u += 5.6


# ---------------------------------------------------------------- lights and solids

func _collect() -> void:
	for b in blocks:
		for p in b["props"]:
			_collect_prop(p)
	for s in segs:
		for p in s["props"]:
			_collect_prop(p)


func _collect_prop(p: Dictionary) -> void:
	var t: String = p["t"]
	var pos: Vector2 = p["p"]
	var rot: float = p["rot"]
	var out := Vector2(0, 1).rotated(rot)
	match t:
		"lamp":
			var head := pos + out * 1.12 * W.M
			p["head"] = head
			var fl := GroundUtil.r01(int(p["s"]), 77) < 0.07
			p["flicker"] = fl
			lights.append({"pos": head, "r": 6.6 * W.M, "color": Pal.LAMP, "e": 1.0, "shape": "round", "flicker": fl})
			solids.append(Rect2(pos - Vector2(0.16, 0.16) * W.M, Vector2(0.32, 0.32) * W.M))
		"alarm":
			lights.append({"pos": pos, "r": 1.5 * W.M, "color": Color(1.0, 0.35, 0.28), "e": 0.55, "shape": "round", "flicker": false})
			solids.append(_foot_rect(pos, Vector2(0.28, 0.28), rot))
		"newsstand":
			var bulb := pos + out * -0.18 * W.M
			lights.append({"pos": bulb, "r": 2.4 * W.M, "color": Pal.WINDOW_WARM, "e": 0.6, "shape": "round", "flicker": false})
			solids.append(_foot_rect(pos, p["foot"], rot))
		"hydrant", "mailbox", "callbox", "ashcans", "bench", "trough", "basket":
			var f: Vector2 = p["foot"]
			solids.append(_foot_rect(pos, f * 0.9, rot))
		"tree":
			solids.append(Rect2(pos - Vector2(0.2, 0.2) * W.M, Vector2(0.4, 0.4) * W.M))
		"pole":
			solids.append(Rect2(pos - Vector2(0.15, 0.15) * W.M, Vector2(0.3, 0.3) * W.M))
		"pushcart":
			solids.append(_foot_rect(pos, Vector2(2.9, 1.1), rot))


static func _foot_rect(pos: Vector2, foot_m: Vector2, rot: float) -> Rect2:
	var f := foot_m * W.M
	var ext := f if absf(sin(rot)) < 0.5 else Vector2(f.y, f.x)
	return Rect2(pos - ext * 0.5, ext)
