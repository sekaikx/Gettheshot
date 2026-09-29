class_name Interiors
extends RefCounted
## Floor plans for every business you can walk into. Pure data, deterministic from the lot, so
## every machine builds the same rooms. The World uses the walls and solid items for collision,
## the spots for where people stand, the breakables for shakedowns; InteriorArt draws it all.
##
## Contract (docs/REBUILD_2D.md, "Interiors"). Everything in WORLD PIXELS.
##   layout(lot, kind) -> {
##     "rect": Rect2               the whole lot
##     "front": Vector2            unit vector out of the front door, toward the street
##     "side": Vector2             unit vector along the front (front.orthogonal())
##     "walls": Array              [[Vector2 a, Vector2 b], ...] wall centre lines, W.WALL thick; door gaps left open
##     "doors": Array              [{"pos": Vector2, "dir": Vector2 (pointing out of the room), "kind": "front"|"back"|"office"|"cell"}]
##     "shop": Rect2               the public room
##     "back": Rect2               the back room (storeroom / kitchen / office / the speakeasy), Rect2() if none
##     "owner_spot": Vector2       where the owner stands (behind the counter)
##     "owner_rot": float          which way he faces (radians, 0 = +x): toward the front door
##     "items": Array              [{"id": int, "type": String, "rect": Rect2, "rot": float, "solid": bool,
##                                   "breakable": bool, "value": int, "room": "shop"|"back"}]
##       types used by the game: "window" (front glass, breakable), "counter", "register" (breakable, can
##       be robbed), "display" (glass case, breakable), "shelf" (breakable), "table", "chair", "safe",
##       "desk", "map_table", "phone", "bar", "stool", "pool_table", "crates", "cell", "bench",
##       "piano", "oven", "rack", "barber_chair", "mirror", "tub", "press", "icebox", "stove", "sink"
##       (art may add more; unknown types are just drawn)
##     "spots": Dictionary         named places: "register", "safe", "desk", "map", "phone", "bar",
##                                  "stools": [..], "tables": [..], "patrons": [..], "guards": [..],
##                                  "recruits": [..], "cells": [Rect2..], "stock": Rect2 (warehouse pallets),
##                                  "sergeant", "captain", "dealer", "mentor"
##   }
##
## Extra keys for the art (the game ignores them): "kind", "speak", "xform" (lot-local px -> world px;
## local x runs along the front, local +y points out of the front door), "size" (local px), "split",
## "lwalls" [{"r": Rect2 local, "style"}], "openings" (glass and loading doors in the walls), "ldoors",
## "floors", "deco" [{"type", "lr", "face", ...}], "lamps" [{"p", "room", "style"}], "seed", "mir".
## Every item also carries "art" (how to draw it), "lr" (its rect in local px) and "face" (local unit
## vector its front looks along).
##
## The back room is built from the same solid footprint whether it's a storeroom or a speakeasy
## ("speak"), so the World's collision (built once at start) stays right when a speakeasy opens:
## item ids and solid rects never change, only what's drawn in them.

const DOOR_W := 1.5          # metres, the front door
const INNER_DOOR := 1.2      # back room, office and cell doors
const WT := W.WALL           # wall thickness, metres
const TRADES := ["bakery", "butcher", "grocer", "tailor", "barber", "cobbler", "pawnshop", "laundry",
	"restaurant", "cafe", "candy", "hardware", "drugstore", "cigar", "fish"]


## Builds one plan in the lot's own frame: u runs along the front (to your right as you walk in),
## v runs from the front wall (0) to the back wall (depth), in metres.
class Plan:
	var lot: Dictionary
	var kind := ""
	var speak := false
	var wd := 0.0              # lot width along the street, m
	var dp := 0.0              # lot depth, m
	var hw := 0.0              # half width
	var iu := 0.0              # clear half width inside the side walls
	var fc := Vector2.ZERO     # front centre, px
	var f := Vector2.ZERO
	var l := Vector2.ZERO
	var mir := 1.0
	var room := "shop"
	var items: Array = []
	var deco: Array = []
	var walls: Array = []
	var lwalls: Array = []
	var openings: Array = []
	var doors: Array = []
	var ldoors: Array = []
	var lamps: Array = []
	var spots := {}
	var floors := {}
	var rng: RandomNumberGenerator
	var seed_value := 0

	func lp(u: float, v: float) -> Vector2:
		return Vector2(u * mir, -v) * W.M

	func wp(u: float, v: float) -> Vector2:
		return fc + l * (u * mir * W.M) - f * (v * W.M)

	func lrect(u0: float, v0: float, u1: float, v1: float) -> Rect2:
		var a := lp(u0, v0)
		var b := lp(u1, v1)
		return Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (a - b).abs())

	func wrect(u0: float, v0: float, u1: float, v1: float) -> Rect2:
		var a := wp(u0, v0)
		var b := wp(u1, v1)
		return Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (a - b).abs())

	## A direction in plan terms (du along the front, dv deeper in) -> local unit vector.
	func lface(du: float, dv: float) -> Vector2:
		return Vector2(du * mir, -dv).normalized()

	func add(type: String, u0: float, v0: float, u1: float, v1: float, solid: bool, breakable: bool,
			value: int, art: String = "", face: Vector2 = Vector2(0, -1), extra: Dictionary = {}) -> Dictionary:
		var lf := lface(face.x, face.y)
		var it := {"id": items.size(), "type": type, "rect": wrect(u0, v0, u1, v1),
			"rot": (l * lf.x + f * lf.y).angle(), "solid": solid, "breakable": breakable, "value": value,
			"room": room, "art": art if art != "" else type, "lr": lrect(u0, v0, u1, v1), "face": lf,
			"seed": seed_value * 31 + items.size() * 7}
		it.merge(extra, true)
		items.append(it)
		return it

	## Decoration only (drawn, never collides): rugs, lamps, chairs pulled up, the cat.
	func dec(type: String, u0: float, v0: float, u1: float, v1: float, face: Vector2 = Vector2(0, -1), extra: Dictionary = {}) -> void:
		var d := {"type": type, "lr": lrect(u0, v0, u1, v1), "face": lface(face.x, face.y), "room": room,
			"seed": seed_value * 17 + deco.size() * 13}
		d.merge(extra, true)
		deco.append(d)

	func pt(u: float, v: float) -> Vector2:
		return wp(u, v)

	## A wall band given by its outer extents (one side is WT thick). Collision = drawing.
	func band(u0: float, v0: float, u1: float, v1: float, style: String = "in") -> void:
		var du := absf(u1 - u0)
		var dv := absf(v1 - v0)
		if maxf(du, dv) < WT * 1.05:
			return
		var a: Vector2
		var b: Vector2
		if du >= dv:
			var vc := (v0 + v1) * 0.5
			a = Vector2(minf(u0, u1) + WT * 0.5, vc)
			b = Vector2(maxf(u0, u1) - WT * 0.5, vc)
		else:
			var uc := (u0 + u1) * 0.5
			a = Vector2(uc, minf(v0, v1) + WT * 0.5)
			b = Vector2(uc, maxf(v0, v1) - WT * 0.5)
		walls.append([wp(a.x, a.y), wp(b.x, b.y)])
		lwalls.append({"r": lrect(u0, v0, u1, v1), "style": style})

	## A wall running along u at depth vc (centre line), from u0 to u1 (outer ends).
	func hwall(vc: float, u0: float, u1: float, style: String = "in") -> void:
		band(u0, vc - WT * 0.5, u1, vc + WT * 0.5, style)

	## A wall running along v at uc (centre line), from v0 to v1.
	func vwall(uc: float, v0: float, v1: float, style: String = "in") -> void:
		band(uc - WT * 0.5, v0, uc + WT * 0.5, v1, style)

	## A wall along u with a door gap centred at `du`, `w` wide.
	func hwall_door(vc: float, u0: float, u1: float, du: float, w: float, kind: String, style: String = "in", out_dv: float = -1.0) -> void:
		hwall(vc, u0, du - w * 0.5, style)
		hwall(vc, du + w * 0.5, u1, style)
		door(du, vc, w, true, kind, out_dv)

	func vwall_door(uc: float, v0: float, v1: float, dv: float, w: float, kind: String, style: String = "in", out_du: float = -1.0) -> void:
		vwall(uc, v0, dv - w * 0.5, style)
		vwall(uc, dv + w * 0.5, v1, style)
		door(uc, dv, w, false, kind, out_du)

	## along_u: the wall runs along u (the door opens toward -v/+v); `out` is the plan direction (sign)
	## that leads out of the room this door belongs to.
	func door(u: float, v: float, w: float, along_u: bool, kind: String, out: float) -> void:
		var dir_uv := Vector2(0, out) if along_u else Vector2(out, 0)
		var lf := lface(dir_uv.x, dir_uv.y)
		doors.append({"pos": wp(u, v), "dir": (l * lf.x + f * lf.y).normalized(), "kind": kind})
		ldoors.append({"p": lp(u, v), "w": w * W.M, "along": Vector2(1, 0) if along_u else Vector2(0, 1),
			"out": lf, "kind": kind})

	func lamp(u: float, v: float, style: String = "pendant", rm: String = "") -> void:
		lamps.append({"p": lp(u, v), "room": rm if rm != "" else room, "style": style, "w": pt(u, v)})

	func spot(name: String, u: float, v: float) -> void:
		spots[name] = wp(u, v)

	func spot_list(name: String, pts: Array) -> void:
		var out := []
		for q in pts:
			out.append(wp(float(q[0]), float(q[1])))
		spots[name] = out


static func layout(lot: Dictionary, kind: String) -> Dictionary:
	return build(lot, kind, false)


## The same plan with the back room turned into a speakeasy (same walls, same solid rects, same ids).
static func speakeasy(lot: Dictionary, kind: String) -> Dictionary:
	return build(lot, kind, true)


static func build(lot: Dictionary, kind: String, speak: bool) -> Dictionary:
	var p := Plan.new()
	p.lot = lot
	p.kind = kind
	p.speak = speak and kind != "precinct"
	var r := W.lot_rect(lot)
	p.f = W.front_dir(float(lot["yaw"]))
	p.l = p.f.orthogonal()
	p.dp = absf(r.size.dot(p.f)) / W.M
	p.wd = absf(r.size.dot(p.l)) / W.M
	p.hw = p.wd * 0.5
	p.iu = p.hw - WT
	p.fc = r.get_center() + p.f * p.dp * W.M * 0.5
	p.seed_value = int(lot.get("id", 0)) * 7919 + 17
	p.rng = W.rng(p.seed_value)
	p.mir = 1.0 if (int(lot.get("id", 0)) * 5 + 3) % 7 < 4 else -1.0
	var split := 0.0
	var owner := Vector2(0, 0)
	match kind:
		"club":
			var res := _club(p)
			split = res.x
			owner = Vector2(res.y, res.z)
		"precinct":
			var res2 := _precinct(p)
			split = res2.x
			owner = Vector2(res2.y, res2.z)
		"poolhall":
			var res3 := _poolhall(p)
			split = res3.x
			owner = Vector2(res3.y, res3.z)
		"warehouse":
			var res4 := _warehouse(p)
			split = res4.x
			owner = Vector2(res4.y, res4.z)
		_:
			var res5 := _trade(p, kind if kind in TRADES else "grocer")
			split = res5.x
			owner = Vector2(res5.y, res5.z)
	var shop_r := p.wrect(-p.hw, 0.0, p.hw, split)
	var back_r := p.wrect(-p.hw, split, p.hw, p.dp)
	if kind == "warehouse":
		shop_r = p.wrect(-p.hw, 0.0, p.hw, p.dp)
		back_r = p.spots.get("_office", Rect2())
		p.spots.erase("_office")
	var lx := Transform2D(p.l, p.f, p.fc)
	return {"rect": r, "front": p.f, "side": p.l, "walls": p.walls, "doors": p.doors,
		"shop": shop_r, "back": back_r, "owner_spot": p.wp(owner.x, owner.y), "owner_rot": p.f.angle(),
		"items": p.items, "spots": p.spots,
		"kind": kind, "speak": p.speak, "xform": lx, "size": Vector2(p.wd, p.dp) * W.M, "split": split,
		"lwalls": p.lwalls, "openings": p.openings, "ldoors": p.ldoors, "floors": p.floors, "deco": p.deco,
		"lamps": p.lamps, "seed": p.seed_value, "mir": p.mir, "lot_id": int(lot.get("id", -1))}


## Is a point (px) inside this layout's walls?
static func contains(lay: Dictionary, p: Vector2) -> bool:
	return (lay["rect"] as Rect2).has_point(p)


# ------------------------------------------------------------------ shared pieces

## Outer walls with the front door in the middle, and the front windows either side of it.
## `ledge` (m) is the depth of the display platform behind the glass (0: none).
static func _shell(p: Plan, ledge: float, win_art: String, front_style: String = "front") -> void:
	var hw := p.hw
	p.room = "shop"
	p.hwall_door(WT * 0.5, -hw, hw, 0.0, DOOR_W, "front", front_style, -1.0)
	p.vwall(-hw + WT * 0.5, 0.0, p.dp, "side")
	p.vwall(hw - WT * 0.5, 0.0, p.dp, "side")
	p.hwall(p.dp - WT * 0.5, -hw, hw, "back")
	var g0 := DOOR_W * 0.5 + 0.2
	var g1 := hw - 0.35
	if g1 - g0 > 0.5:
		for s: float in [-1.0, 1.0]:
			var a := g0 * s
			var b := g1 * s
			p.add("window", minf(a, b), 0.0, maxf(a, b), WT + ledge, ledge > 0.01, true, 20, win_art,
				Vector2(0, -1), {"glass_v": WT, "ledge": ledge, "side_sign": s})
			p.openings.append({"r": p.lrect(minf(a, b), 0.0, maxf(a, b), WT), "style": "glass", "item": p.items.size() - 1})


## The partition between the shop and the back room, with the back door at `bu`.
static func _partition(p: Plan, split: float, bu: float, style: String = "in") -> void:
	p.hwall_door(split, -p.iu, p.iu, bu, INNER_DOOR, "back", style, -1.0)


## The counter across the back of the shop. Returns [counter front v, counter back v, left u, right u].
## The owner stands behind it at (0, back + 0.5): 1.6 m in front of him is where you stand to talk.
static func _counter_line(p: Plan, split: float, shelf_d: float = 0.4, max_len: float = 6.5) -> Array:
	var cb := split - WT * 0.5 - shelf_d - 1.0
	var cf := cb - 0.6
	var cr := p.iu - 1.2
	var cl := maxf(-p.iu, cr - max_len)
	return [cf, cb, cl, cr]


## Slots in a standard back room (storeroom or speakeasy). The back door is on the right (+u).
static func _back_slots(p: Plan, split: float) -> Dictionary:
	var bv0 := split + WT * 0.5
	var bv1 := p.dp - WT
	var iu := p.iu
	var tv := bv0 + (bv1 - bv0 - 0.55) * 0.5 + 0.05
	var ua := -iu + 2.7
	var ub := iu - 0.95
	var n := clampi(1 + int(floor((ub - ua) / 1.9)), 1, 3)
	var tus := []
	if n == 1 or ub <= ua:
		tus.append(clampf((ua + ub) * 0.5, -iu + 2.2, iu - 0.9))
	else:
		for k in n:
			tus.append(lerpf(ua, ub, float(k) / float(n - 1)))
	return {"bv0": bv0, "bv1": bv1, "L": [-iu, bv0 + 0.3, -iu + 1.3, bv1], "B": [iu - 2.45, bv1 - 0.6, iu - 0.85, bv1],
		"P": [iu - 0.72, bv1 - 0.6, iu, bv1], "tv": tv, "tus": tus}


## The back room: storeroom things in normal mode, a speakeasy when `p.speak`. Same solids either way.
## `norm` = {"L": [type, art], "B": [...], "P": [...], "T": [...]} for the storeroom.
static func _back_room(p: Plan, split: float, norm: Dictionary) -> Dictionary:
	var s := _back_slots(p, split)
	p.room = "back"
	var L: Array = s["L"]
	var B: Array = s["B"]
	var P: Array = s["P"]
	var tv: float = s["tv"]
	var bv0: float = s["bv0"]
	var bv1: float = s["bv1"]
	var iu := p.iu
	if p.speak:
		p.add("bar", L[0], L[1], L[2], L[3], true, true, 25, "speak_bar", Vector2(1, 0))
		p.add("piano", B[0], B[1], B[2], B[3], true, false, 0, "piano", Vector2(0, -1))
		p.add("phonograph", P[0], P[1], P[2], P[3], true, false, 0, "phonograph", Vector2(-1, -1))
		var tables := []
		var patrons := []
		for u in s["tus"]:
			var uu := float(u)
			p.add("table", uu - 0.36, tv - 0.36, uu + 0.36, tv + 0.36, true, false, 0, "cocktail_table", Vector2(0, -1))
			tables.append([uu, tv])
			for c in [[-0.62, 0.0, 1.0, 0.0], [0.62, 0.0, -1.0, 0.0], [0.0, -0.6, 0.0, 1.0]]:
				p.dec("chair", uu + c[0] - 0.22, tv + c[1] - 0.22, uu + c[0] + 0.22, tv + c[1] + 0.22, Vector2(c[2], c[3]), {"style": "bentwood"})
				patrons.append([uu + c[0], tv + c[1]])
		var stools := []
		var sv := bv0 + 0.75
		while sv < bv1 - 0.35:
			stools.append([-iu + 1.55, sv])
			p.dec("stool", -iu + 1.36, sv - 0.19, -iu + 1.74, sv + 0.19, Vector2(-1, 0), {"style": "bar"})
			sv += 0.72
		for k in stools.size():
			if k % 2 == 0:
				patrons.append(stools[k])
		p.dec("rug", -iu + 2.0, bv0 + 0.6, iu - 0.6, bv1 - 0.75, Vector2(0, -1), {"style": "speak"})
		p.dec("smoke", -iu + 1.0, bv0 + 0.2, iu - 0.2, bv1 - 0.2)
		p.spot("bar", -iu + 0.62, (bv0 + bv1) * 0.5)
		p.spot_list("stools", stools)
		p.spot_list("tables", tables)
		p.spot_list("patrons", patrons)
		p.lamp(0.0, (bv0 + bv1) * 0.5, "speak")
	else:
		var nl: Array = norm.get("L", ["shelf", "stock_shelf"])
		var nb: Array = norm.get("B", ["crates", "crates"])
		var np: Array = norm.get("P", ["crates", "barrel"])
		var nt: Array = norm.get("T", ["crates", "crates"])
		p.add(nl[0], L[0], L[1], L[2], L[3], true, false, 0, nl[1], Vector2(1, 0))
		p.add(nb[0], B[0], B[1], B[2], B[3], true, false, 0, nb[1], Vector2(0, -1))
		p.add(np[0], P[0], P[1], P[2], P[3], true, false, 0, np[1], Vector2(-1, -1))
		var k := 0
		for u in s["tus"]:
			var uu := float(u)
			var art: String = nt[1] if k % 2 == 0 or nt.size() < 3 else nt[2]
			p.add(nt[0], uu - 0.36, tv - 0.36, uu + 0.36, tv + 0.36, true, false, 0, art, Vector2(0, -1))
			k += 1
		p.lamp(0.0, (bv0 + bv1) * 0.5, "bulb")
	p.room = "shop"
	return s


# ------------------------------------------------------------------ the trades

static func _trade(p: Plan, kind: String) -> Vector3:
	var iu := p.iu
	var split := 6.4
	var ledge := 0.55
	var win := "window_" + kind
	match kind:
		"restaurant", "cafe":
			split = 6.6
			ledge = 0.0
		"barber":
			split = 6.6
			ledge = 0.0
		"laundry":
			split = 6.0
	p.floors = _floors_for(kind)
	_shell(p, ledge, win)
	var bu := iu - 0.75
	_partition(p, split, bu)
	var c := _counter_line(p, split)
	var cf: float = c[0]
	var cb: float = c[1]
	var cl: float = c[2]
	var cr: float = c[3]
	var ov := cb + 0.5
	var sv0 := split - WT * 0.5 - 0.4
	var sv1 := split - WT * 0.5
	var shelf_r := bu - INNER_DOOR * 0.5 - 0.12
	# the counter: most trades split it into a glass case (left) and the till counter (right)
	var case_art: String = {"bakery": "pastry_case", "butcher": "meat_case", "pawnshop": "watch_case",
		"candy": "candy_case", "cafe": "pastry_case", "cigar": "cigar_case", "fish": "fish_ice",
		"drugstore": "drug_case"}.get(kind, "")
	var counter_art: String = {"tailor": "cutting_counter", "cafe": "marble_counter", "drugstore": "marble_counter",
		"candy": "marble_counter", "pawnshop": "pawn_counter", "fish": "fish_counter", "butcher": "butcher_counter"}.get(kind, "wood_counter")
	var reg_u := 0.25
	if case_art != "" and cl < -0.9:
		var split_u := minf(-0.55, cl + (cr - cl) * 0.5)
		p.add("display", cl, cf, split_u, cb, true, true, 30, case_art, Vector2(0, -1))
		p.add("counter", split_u, cf, cr, cb, true, false, 0, counter_art, Vector2(0, -1), {"goods": kind})
	else:
		p.add("counter", cl, cf, cr, cb, true, false, 0, counter_art, Vector2(0, -1), {"goods": kind})
	p.add("register", reg_u, cf + 0.07, reg_u + 0.5, cf + 0.5, false, true, 25, "register", Vector2(0, -1))
	p.spot("register", reg_u + 0.25, cf - 0.4)
	# the wall of goods behind the counter
	var shelf_art: String = {"bakery": "bread_shelf", "butcher": "meat_hooks", "grocer": "grocery_shelf",
		"tailor": "cloth_shelf", "barber": "tonic_shelf", "cobbler": "shoe_shelf", "pawnshop": "pawn_shelf",
		"laundry": "bundle_shelf", "restaurant": "wine_shelf", "cafe": "coffee_shelf", "candy": "jar_shelf",
		"hardware": "drawer_shelf", "drugstore": "bottle_shelf", "cigar": "cigar_shelf", "fish": "tin_shelf"}.get(kind, "grocery_shelf")
	p.add("shelf", -iu, sv0, shelf_r, sv1, true, true, 20, shelf_art, Vector2(0, -1))
	# the customer side: each trade its own
	var dv0 := 1.25
	var dv1 := cf - 0.95
	match kind:
		"bakery":
			p.add("rack", -iu, dv0, -iu + 0.7, dv1, true, true, 15, "bread_rack", Vector2(1, 0))
			p.add("display", iu - 0.7, dv0, iu, dv1 - 0.4, true, true, 25, "cake_case", Vector2(-1, 0))
			p.dec("sacks", iu - 0.75, dv1 - 0.3, iu - 0.05, dv1 + 0.35, Vector2(-1, 0), {"style": "flour"})
			p.dec("chalkboard", -iu, cf + 0.05, -iu + 0.08, cb - 0.05, Vector2(1, 0))
		"butcher":
			p.add("icebox", -iu, dv0, -iu + 0.75, dv0 + 1.2, true, false, 0, "icebox", Vector2(1, 0))
			p.add("display", iu - 0.7, dv0, iu, dv1, true, true, 20, "poultry_case", Vector2(-1, 0))
			p.add("table", -iu, cb + 0.1, -iu + 0.75, cb + 0.85, true, false, 0, "chop_block", Vector2(1, 0))
			p.dec("sawdust", -iu + 0.5, 0.6, iu - 0.5, cf - 0.1)
			p.dec("scale", -iu + 0.05, dv0 + 1.35, -iu + 0.55, dv0 + 1.85, Vector2(1, 0))
		"grocer":
			p.add("display", -iu, dv0, -iu + 0.8, dv1, true, true, 25, "produce_bins", Vector2(1, 0))
			p.add("crates", iu - 0.65, dv0, iu, dv0 + 1.4, true, false, 0, "barrels", Vector2(-1, 0))
			p.dec("sacks", iu - 0.7, dv0 + 1.55, iu - 0.05, dv1, Vector2(-1, 0), {"style": "potato"})
			p.dec("hanging", cl + 0.3, cb + 0.15, cr - 0.3, cb + 0.45, Vector2(0, -1), {"style": "salami"})
		"tailor":
			p.add("rack", -iu, dv0, -iu + 0.6, dv1, true, true, 15, "suit_rack", Vector2(1, 0))
			p.add("mirror", iu - 0.45, dv0 + 0.2, iu, dv0 + 1.3, true, true, 30, "tri_mirror", Vector2(-1, 0))
			p.add("dummy", iu - 1.2, dv0 + 1.5, iu - 0.6, dv0 + 2.1, true, false, 0, "dummy", Vector2(-1, -1))
			p.dec("rug", -iu + 1.0, 1.0, iu - 1.1, cf - 0.35, Vector2(0, -1), {"style": "persian"})
			p.dec("chair", -0.35 - 1.2, 1.5, 0.15 - 1.2, 2.0, Vector2(1, 0), {"style": "arm"})
			p.dec("pedestal", iu - 1.35, dv0 + 0.25, iu - 0.75, dv0 + 0.85)
		"barber":
			# chairs along the left wall facing the mirrors, waiting bench on the right
			p.add("sink", -iu, 0.95, -iu + 0.5, dv1 + 0.3, true, false, 0, "barber_counter", Vector2(1, 0))
			var n := clampi(int((dv1 + 0.3 - 1.1) / 1.2), 1, 3)
			for k in n:
				var v0 := 1.15 + k * 1.2
				p.add("mirror", -iu, v0 - 0.1, -iu + 0.1, v0 + 0.9, false, true, 30, "barber_mirror", Vector2(1, 0))
				p.add("barber_chair", -iu + 0.8, v0, -iu + 1.6, v0 + 0.8, true, false, 0, "barber_chair", Vector2(-1, 0))
			p.add("bench", iu - 0.55, dv0, iu, dv1, true, false, 0, "wait_bench", Vector2(-1, 0))
			p.dec("hatstand", iu - 0.55, 0.45, iu - 0.1, 0.9)
			p.dec("spittoon", iu - 0.95, dv1 + 0.2, iu - 0.65, dv1 + 0.5)
			p.dec("hair", -iu + 1.4, 1.0, -iu + 2.4, dv1 + 0.4)
			p.dec("newspapers", iu - 0.5, dv0 + 0.3, iu - 0.1, dv0 + 0.75, Vector2(-1, 0))
		"cobbler":
			p.add("table", -iu, dv0, -iu + 0.75, dv0 + 1.6, true, false, 0, "cobbler_bench", Vector2(1, 0))
			p.dec("stool", -iu + 0.85, dv0 + 0.6, -iu + 1.25, dv0 + 1.0, Vector2(-1, 0), {"style": "shop"})
			p.add("chair", iu - 0.9, dv0, iu, dv0 + 0.9, true, false, 0, "shine_stand", Vector2(-1, 0))
			p.add("shelf", iu - 0.4, dv0 + 1.1, iu, dv1, true, true, 15, "shoe_rack", Vector2(-1, 0))
			p.dec("leather", -iu + 0.1, dv0 + 1.75, -iu + 0.7, dv1)
		"pawnshop":
			p.add("display", -iu, dv0, -iu + 0.75, dv1, true, true, 35, "jewel_case", Vector2(1, 0))
			p.add("shelf", iu - 0.4, dv0 - 0.3, iu, dv1 + 0.2, true, true, 30, "instruments", Vector2(-1, 0))
			p.dec("clutter", iu - 1.1, dv0, iu - 0.45, dv0 + 0.7, Vector2(-1, 0), {"style": "gramophone"})
			p.dec("clutter", iu - 1.0, dv1 - 0.6, iu - 0.45, dv1, Vector2(-1, 0), {"style": "bicycle"})
		"laundry":
			p.add("table", -iu, dv0, -iu + 0.8, dv1, true, false, 0, "folding_table", Vector2(1, 0))
			p.add("crates", iu - 0.8, dv0, iu, dv0 + 1.1, true, false, 0, "laundry_cart", Vector2(-1, 0))
			p.dec("basket", iu - 0.75, dv0 + 1.3, iu - 0.15, dv0 + 1.9)
			p.dec("bundles", iu - 0.7, dv0 + 2.0, iu - 0.1, dv1)
		"restaurant":
			_dining(p, 0.95, cf - 1.1, "table_checked", 0.78, "bentwood")
			p.dec("coat_rack", -iu + 0.1, 0.35, -iu + 0.55, 0.8)
		"cafe":
			_dining(p, 0.95, cf - 1.1, "table_round", 0.66, "bentwood")
			p.dec("coat_rack", iu - 0.55, 0.35, iu - 0.1, 0.8)
		"candy":
			p.add("bar", -iu, dv0, -iu + 1.05, dv1, true, true, 20, "soda_fountain", Vector2(1, 0))
			var sv := dv0 + 0.4
			while sv < dv1 - 0.2:
				p.dec("stool", -iu + 1.15, sv - 0.19, -iu + 1.53, sv + 0.19, Vector2(-1, 0), {"style": "fountain"})
				sv += 0.7
			p.add("display", iu - 0.7, dv0, iu, dv1 - 0.3, true, true, 20, "chocolate_case", Vector2(-1, 0))
			p.dec("gumball", iu - 0.95, dv1 - 0.05, iu - 0.55, dv1 + 0.35)
		"hardware":
			p.add("shelf", -iu, dv0, -iu + 0.5, dv1, true, true, 20, "tool_wall", Vector2(1, 0))
			p.add("display", iu - 0.75, dv0, iu, dv0 + 1.5, true, true, 20, "nail_bins", Vector2(-1, 0))
			p.add("crates", iu - 0.65, dv0 + 1.65, iu, dv1, true, false, 0, "hardware_barrels", Vector2(-1, 0))
			p.dec("brooms", -iu + 0.55, dv1 - 0.1, -iu + 1.0, dv1 + 0.4)
			p.dec("rope", iu - 1.2, dv1 - 0.15, iu - 0.7, dv1 + 0.35)
		"drugstore":
			p.add("bar", -iu, dv0, -iu + 1.05, dv1, true, true, 20, "soda_fountain", Vector2(1, 0))
			var sv2 := dv0 + 0.4
			while sv2 < dv1 - 0.2:
				p.dec("stool", -iu + 1.15, sv2 - 0.19, -iu + 1.53, sv2 + 0.19, Vector2(-1, 0), {"style": "fountain"})
				sv2 += 0.7
			p.add("display", iu - 0.7, dv0, iu, dv1, true, true, 25, "cosmetic_case", Vector2(-1, 0))
			p.dec("scale", iu - 1.2, 0.55, iu - 0.75, 1.0, Vector2(0, 1), {"style": "penny"})
		"cigar":
			p.add("rack", -iu, dv0, -iu + 0.55, dv1, true, true, 15, "news_rack", Vector2(1, 0))
			p.add("display", iu - 0.75, dv0, iu, dv1, true, true, 30, "humidor", Vector2(-1, 0))
			p.dec("spittoon", -iu + 0.7, dv1 + 0.1, -iu + 1.0, dv1 + 0.4)
			p.dec("chair", iu - 1.4, 1.2, iu - 0.9, 1.7, Vector2(-1, 1), {"style": "arm"})
		"fish":
			p.add("display", -iu, dv0, -iu + 0.8, dv1, true, true, 25, "ice_table", Vector2(1, 0))
			p.add("crates", iu - 0.7, dv0, iu, dv0 + 1.5, true, false, 0, "clam_baskets", Vector2(-1, 0))
			p.add("tub", iu - 0.75, dv0 + 1.7, iu, dv1, true, false, 0, "lobster_tank", Vector2(-1, 0))
			p.dec("puddle", -0.8, 1.2, 0.9, 2.6)
	# the doormat, the lamps, a cat somewhere warm
	p.dec("doormat", -0.6, WT + 0.02, 0.6, WT + 0.62)
	var mid := (WT + cf) * 0.5
	if p.wd > 9.5:
		p.lamp(-p.wd * 0.2, mid)
		p.lamp(p.wd * 0.2, mid)
	else:
		p.lamp(0.0, mid)
	p.lamp(0.0, (cb + sv0) * 0.5 + 0.1, "shade")
	var norm: Dictionary = {
		"bakery": {"L": ["oven", "oven"], "B": ["crates", "flour_sacks"], "P": ["crates", "barrel"], "T": ["rack", "proving_rack"]},
		"butcher": {"L": ["icebox", "cold_room"], "B": ["table", "saw_bench"], "P": ["crates", "bone_barrel"], "T": ["table", "chop_block"]},
		"grocer": {"L": ["shelf", "crate_shelf"], "B": ["crates", "potato_sacks"], "P": ["crates", "barrel"], "T": ["crates", "crates", "produce_crates"]},
		"tailor": {"L": ["table", "sewing_bench"], "B": ["press", "steam_press"], "P": ["crates", "dummy_box"], "T": ["crates", "cloth_bales"]},
		"barber": {"L": ["shelf", "towel_shelf"], "B": ["stove", "boiler"], "P": ["sink", "wash_basin"], "T": ["crates", "crates"]},
		"cobbler": {"L": ["shelf", "leather_shelf"], "B": ["table", "stitcher"], "P": ["crates", "barrel"], "T": ["crates", "shoe_boxes"]},
		"pawnshop": {"L": ["table", "gun_table"], "B": ["crates", "gun_crates"], "P": ["safe", "pawn_safe"], "T": ["crates", "crates", "trunk"]},
		"laundry": {"L": ["tub", "washtubs"], "B": ["press", "mangle"], "P": ["stove", "copper_boiler"], "T": ["crates", "laundry_basket"]},
		"restaurant": {"L": ["stove", "range"], "B": ["sink", "kitchen_sink"], "P": ["icebox", "icebox_small"], "T": ["table", "prep_table"]},
		"cafe": {"L": ["shelf", "sack_shelf"], "B": ["stove", "roaster"], "P": ["crates", "barrel"], "T": ["crates", "coffee_sacks"]},
		"candy": {"L": ["shelf", "box_shelf"], "B": ["stove", "candy_kettle"], "P": ["crates", "sugar_barrel"], "T": ["table", "marble_slab"]},
		"hardware": {"L": ["shelf", "pipe_rack"], "B": ["crates", "crates"], "P": ["crates", "kerosene"], "T": ["crates", "crates", "nail_kegs"]},
		"drugstore": {"L": ["shelf", "apothecary"], "B": ["table", "lab_bench"], "P": ["sink", "wash_basin"], "T": ["crates", "crates"]},
		"cigar": {"L": ["table", "numbers_desk"], "B": ["shelf", "tally_board"], "P": ["crates", "phone_stand"], "T": ["table", "slip_table"]},
		"fish": {"L": ["icebox", "ice_chests"], "B": ["sink", "gutting_table"], "P": ["crates", "barrel"], "T": ["crates", "fish_boxes"]},
	}.get(kind, {})
	_back_room(p, split, norm)
	if kind == "pawnshop":
		p.spot("dealer", -iu + 1.75, split + 1.1)
	if not p.speak:
		match kind:
			"laundry":
				p.room = "back"
				p.dec("lines", -iu + 1.4, split + 0.5, iu - 0.3, p.dp - 0.9)
				p.dec("steam", iu - 0.9, p.dp - 1.2, iu - 0.1, p.dp - 0.3)
				p.room = "shop"
			"restaurant":
				p.room = "back"
				p.dec("pots", -iu + 0.2, split + 0.45, -iu + 1.2, split + 0.9)
				p.room = "shop"
			"cigar":
				p.room = "back"
				p.dec("slips", -iu + 1.4, split + 0.5, iu - 1.2, p.dp - 0.8)
				p.room = "shop"
	_cat(p, kind, split)
	return Vector3(split, 0.0, ov)


## Tables in the dining room (restaurant, café): two columns either side of the aisle, chairs
## either side of each table. The last row stays clear of the way round the counter.
static func _dining(p: Plan, v0: float, v1: float, art: String, ts: float, chair: String) -> void:
	var iu := p.iu
	var h := ts * 0.5
	var cols := [iu - 0.55 - h - 0.46]
	if iu >= 4.4:
		cols.append(float(cols[0]) - ts - 1.3)
	var rows := []
	var v := v0 + h
	while v + h <= v1:
		rows.append(v)
		v += ts + 0.75
	for s: float in [-1.0, 1.0]:
		for cu in cols:
			for rv in rows:
				var u := float(cu) * s
				p.add("table", u - h, rv - h, u + h, rv + h, true, false, 0, art, Vector2(0, -1))
				for c in [[-h - 0.25, 1.0], [h + 0.25, -1.0]]:
					var cu2 := u + float(c[0])
					if absf(cu2) > iu - 0.22:
						continue
					p.dec("chair", cu2 - 0.21, rv - 0.21, cu2 + 0.21, rv + 0.21, Vector2(c[1], 0.0), {"style": chair})


static func _floors_for(kind: String) -> Dictionary:
	match kind:
		"bakery": return {"shop": "hex", "back": "tile_dusty"}
		"butcher": return {"shop": "tile", "back": "tile"}
		"fish": return {"shop": "tile_wet", "back": "concrete"}
		"barber": return {"shop": "checker", "back": "lino"}
		"restaurant": return {"shop": "checker_red", "back": "tile"}
		"cafe": return {"shop": "hex", "back": "planks"}
		"candy": return {"shop": "checker_red", "back": "planks"}
		"drugstore": return {"shop": "hex", "back": "tile"}
		"laundry": return {"shop": "lino", "back": "tile_wet"}
		"pawnshop": return {"shop": "planks_dark", "back": "planks_dark"}
		"cigar": return {"shop": "planks_dark", "back": "planks"}
		"tailor": return {"shop": "parquet", "back": "planks"}
		"hardware": return {"shop": "planks", "back": "concrete"}
	return {"shop": "planks", "back": "planks"}


## A shop cat, asleep somewhere warm: by the oven, in the shop window, or just inside the back door.
static func _cat(p: Plan, kind: String, split: float) -> void:
	var id := int(p.lot.get("id", 0))
	if (id * 13 + 5) % 3 == 0 or kind in ["butcher", "fish", "drugstore"]:
		return
	var iu := p.iu
	var u := iu - 1.9
	var v := split + 0.55
	var rm := "back"
	if kind in ["bakery", "restaurant", "laundry"] and not p.speak:
		u = -iu + 1.65
		v = split + WT * 0.5 + 1.1
	elif id % 2 == 1 and kind not in ["barber", "restaurant", "cafe"]:
		u = -(iu - 0.75)
		v = WT + 0.28
		rm = "shop"
	p.room = rm
	p.dec("cat", u - 0.26, v - 0.17, u + 0.26, v + 0.17, Vector2(1, 0), {"on_ledge": rm == "shop"})
	p.room = "shop"


# ------------------------------------------------------------------ the social club

static func _club(p: Plan) -> Vector3:
	var iu := p.iu
	var split := 5.6
	p.floors = {"shop": "parquet", "back": "planks_dark"}
	_shell(p, 0.0, "window_club")
	var bu := iu - 0.75
	_partition(p, split, bu)
	var c := _counter_line(p, split, 0.4, 5.0)
	var cf: float = c[0]
	var cb: float = c[1]
	var cl: float = c[2]
	var cr: float = c[3]
	var ov := cb + 0.5
	# the espresso bar and the shelf of cups and bottles behind it
	p.add("bar", cl, cf, cr, cb, true, false, 0, "club_bar" if p.speak else "espresso_bar", Vector2(0, -1))
	p.add("shelf", -iu, split - WT * 0.5 - 0.4, bu - INNER_DOOR * 0.5 - 0.12, split - WT * 0.5, true, true, 20, "club_backbar", Vector2(0, -1))
	p.spot("register", 0.0, cf - 0.4)
	for k in 2:
		var su := cl + 0.45 + k * 0.6
		if su < -0.8:
			p.dec("stool", su - 0.19, cf - 0.55, su + 0.19, cf - 0.17, Vector2(0, 1), {"style": "bar"})
	# card tables (cocktail tables when the booze flows)
	var tu := iu - 1.35
	var tables := []
	var patrons := []
	for s: float in [-1.0, 1.0]:
		var u := tu * s
		p.add("table", u - 0.45, 1.35, u + 0.45, 2.25, true, false, 0, "club_table" if p.speak else "card_table", Vector2(0, -1))
		tables.append([u, 1.8])
		for ch in [[-0.72, 0.0, 1.0, 0.0], [0.72, 0.0, -1.0, 0.0], [0.0, 0.7, 0.0, -1.0], [0.0, -0.7, 0.0, 1.0]]:
			var cu := u + float(ch[0])
			if absf(cu) > iu - 0.2:
				continue
			p.dec("chair", cu - 0.22, 1.8 + ch[1] - 0.22, cu + 0.22, 1.8 + ch[1] + 0.22, Vector2(ch[2], ch[3]), {"style": "club"})
			patrons.append([cu, 1.8 + float(ch[1])])
	p.dec("rug", -iu + 0.35, 0.6, iu - 0.35, cf - 0.3, Vector2(0, -1), {"style": "club"})
	p.dec("coat_rack", -iu + 0.1, 0.35, -iu + 0.55, 0.8)
	p.dec("palm", iu - 0.7, 0.3, iu - 0.05, 0.95)
	p.dec("fan", -0.6, 1.2, 0.6, 2.4)
	p.dec("photos", -iu, 1.2, -iu + 0.06, 2.4, Vector2(1, 0))
	p.dec("photos", iu - 0.06, 1.2, iu, 2.4, Vector2(-1, 0))
	p.lamp(-iu * 0.5, 1.8)
	p.lamp(iu * 0.5, 1.8)
	p.lamp(0.0, cb + 0.55, "shade")
	p.spot_list("guards", [[-DOOR_W * 0.5 - 0.5, 0.9], [DOOR_W * 0.5 + 0.5, 0.9]])
	p.spot("mentor", -iu + 0.6, cf - 0.5)
	if p.speak:
		p.spot("bar", cl + 0.6, cb + 0.5)
		p.spot_list("tables", tables)
		p.spot_list("patrons", patrons)
		p.spot_list("stools", [[cl + 0.45, cf - 0.36], [cl + 1.05, cf - 0.36]])
		p.lamp(0.0, cf + 0.3, "speak")
	# the back office
	p.room = "back"
	var bv0 := split + WT * 0.5
	var bv1 := p.dp - WT
	var du := -iu * 0.5
	var dh := 0.85
	p.add("desk", du - dh, 7.3, du + dh, 8.1, true, false, 0, "boss_desk", Vector2(0, -1))
	p.dec("chair", du - 0.3, 8.3, du + 0.3, 8.9, Vector2(0, -1), {"style": "boss"})
	p.spot("desk", du, 8.6)
	p.add("safe", -iu, bv1 - 0.78, -iu + 0.78, bv1, true, false, 0, "safe", Vector2(0, -1))
	p.spot("safe", -iu + 0.4, bv1 - 1.3)
	var mu0 := iu - 2.3
	var mu1 := iu - 0.4
	p.add("map_table", mu0, 7.0, mu1, 8.2, true, false, 0, "map_table", Vector2(0, -1))
	p.spot("map", (mu0 + mu1) * 0.5, 6.5)
	p.add("phone", iu - 0.55, 8.85, iu, 9.45, true, false, 0, "phone_stand", Vector2(-1, 0))
	p.spot("phone", iu - 0.95, 9.15)
	p.add("cabinet", -iu, bv0 + 0.2, -iu + 0.5, bv0 + 1.1, true, false, 0, "file_cabinet", Vector2(1, 0))
	p.add("sideboard", -iu + 0.75, bv0, -iu + 2.15, bv0 + 0.45, true, false, 0, "sideboard", Vector2(0, 1))
	p.dec("rug", du - 1.5, 6.5, du + 1.5, 9.3, Vector2(0, -1), {"style": "persian"})
	p.dec("chair", du - 0.85, 6.45, du - 0.25, 7.05, Vector2(0, 1), {"style": "leather"})
	p.dec("chair", du + 0.25, 6.45, du + 0.85, 7.05, Vector2(0, 1), {"style": "leather"})
	p.dec("portrait", du - 0.7, bv1 - 0.08, du + 0.7, bv1, Vector2(0, -1))
	p.dec("flag", iu - 0.45, bv1 - 0.45, iu - 0.05, bv1 - 0.05)
	p.lamp(0.0, (bv0 + bv1) * 0.5, "chandelier")
	p.lamp(du + 0.5, 7.55, "banker", "back")
	p.room = "shop"
	return Vector3(split, 0.0, ov)


# ------------------------------------------------------------------ the pool hall

static func _poolhall(p: Plan) -> Vector3:
	var iu := p.iu
	var split := clampf(p.dp - 4.4, 7.0, 7.6)
	p.floors = {"shop": "planks_worn", "back": "planks_dark"}
	_shell(p, 0.0, "window_pool")
	var bu := iu - 0.75
	_partition(p, split, bu)
	var c := _counter_line(p, split, 0.4, 4.2)
	var cf: float = c[0]
	var cb: float = c[1]
	var cl: float = c[2]
	var cr: float = c[3]
	var ov := cb + 0.5
	p.add("bar", cl, cf, cr, cb, true, false, 0, "pool_bar", Vector2(0, -1))
	p.add("shelf", cl, split - WT * 0.5 - 0.4, bu - INNER_DOOR * 0.5 - 0.12, split - WT * 0.5, true, true, 20, "beer_backbar", Vector2(0, -1))
	p.spot("register", 0.0, cf - 0.4)
	# the tables: two columns either side of the aisle, two rows
	var tl := clampf(iu - 1.6, 1.5, 1.95)
	var tw := tl * 0.55
	var r0 := 0.85
	var rows := [r0]
	if r0 + 2.0 * tw + 0.85 <= cf - 0.9:
		rows.append(r0 + tw + 0.85)
	var n := 0
	for rv in rows:
		for s: float in [-1.0, 1.0]:
			var u0 := 0.85 * s
			var u1 := (0.85 + tl) * s
			p.add("pool_table", minf(u0, u1), rv, maxf(u0, u1), rv + tw, true, false, 0, "pool_table", Vector2(0, -1))
			p.lamp((u0 + u1) * 0.5, rv + tw * 0.5, "billiard")
			n += 1
	for s: float in [-1.0, 1.0]:
		var wu := (iu - 0.12) * s
		p.add("rack", minf(wu, iu * s), 1.3, maxf(wu, iu * s), 2.9, false, true, 10, "cue_rack", Vector2(-s, 0))
	var bead_v: float = float(rows[rows.size() - 1]) + tw + 0.35
	p.dec("beads", -iu + 0.5, bead_v - 0.05, iu - 0.5, bead_v + 0.05)
	p.dec("spittoon", -iu + 0.3, cf - 0.6, -iu + 0.6, cf - 0.3)
	p.dec("spittoon", iu - 0.6, 0.45, iu - 0.3, 0.75)
	p.dec("chalk", -0.25, r0 + tw + 0.25, 0.25, r0 + tw + 0.55)
	p.dec("stool", cl + 0.25, cf - 0.55, cl + 0.63, cf - 0.17, Vector2(0, 1), {"style": "bar"})
	var gap_v := r0 + tw + 0.4
	p.spot_list("recruits", [[-iu + 0.45, gap_v], [iu - 0.45, gap_v], [0.0, gap_v + 0.2], [-0.35, r0 + 0.4]])
	p.lamp(0.0, cb + 0.55, "shade")
	# the back room: a card game (or the speakeasy)
	_back_room(p, split, {"L": ["shelf", "beer_cases"], "B": ["crates", "crates"], "P": ["stove", "potbelly"], "T": ["table", "card_table"]})
	if not p.speak:
		var s2 := _back_slots(p, split)
		p.room = "back"
		for u in s2["tus"]:
			var uu := float(u)
			var tv: float = s2["tv"]
			for ch in [[-0.62, 0.0, 1.0, 0.0], [0.62, 0.0, -1.0, 0.0], [0.0, -0.58, 0.0, 1.0]]:
				p.dec("chair", uu + ch[0] - 0.21, tv + ch[1] - 0.21, uu + ch[0] + 0.21, tv + ch[1] + 0.21, Vector2(ch[2], ch[3]), {"style": "bentwood"})
		p.room = "shop"
	return Vector3(split, 0.0, ov)


# ------------------------------------------------------------------ the precinct

static func _precinct(p: Plan) -> Vector3:
	var iu := p.iu
	var split := 5.8
	p.floors = {"shop": "lino_green", "back": "concrete"}
	_shell(p, 0.0, "window_precinct")
	var bu := iu - 0.9
	_partition(p, split, bu)
	# the sergeant's high desk
	var dv0 := 3.5
	var dv1 := 4.2
	var dr := bu - INNER_DOOR * 0.5 - 0.45
	var dl := maxf(-iu, dr - 6.0)
	if dl < -iu + 1.1:
		dl = -iu
	p.add("counter", dl, dv0, dr, dv1, true, false, 0, "high_desk", Vector2(0, -1))
	var su := clampf(0.0, dl + 0.8, dr - 0.8)
	var sv := 4.75
	p.spot("sergeant", su, sv)
	p.spot("register", su, dv0 - 0.4)
	p.add("bench", -iu, 0.9, -iu + 0.5, 2.8, true, false, 0, "bench", Vector2(1, 0))
	p.add("bench", iu - 0.5, 0.9, iu, 2.8, true, false, 0, "bench", Vector2(-1, 0))
	p.dec("board", iu - 0.06, 0.6, iu, 3.2, Vector2(-1, 0), {"style": "wanted"})
	p.dec("flag", -iu + 0.05, split - 0.6, -iu + 0.45, split - 0.2)
	p.dec("cooler", -iu + 0.05, 3.0, -iu + 0.45, 3.4)
	p.dec("spittoon", iu - 0.9, 3.1, iu - 0.6, 3.4)
	p.dec("clock", dl + 0.4, split - 0.2, dl + 0.8, split - 0.125, Vector2(0, -1))
	p.lamp(-iu * 0.45, 1.9, "globe")
	p.lamp(iu * 0.45, 1.9, "globe")
	p.lamp(su, dv1 + 0.3, "shade")
	# the back: a corridor, two cells behind bars and the captain's office
	p.room = "back"
	var cv := 7.475
	var bv1 := p.dp - WT
	var ow := clampf(2.0 * iu * 0.45, 2.3, 4.8)
	var ox := -iu + ow           # the office's right wall (u centre)
	var cw := (iu - ox - WT * 0.5) * 0.5
	var mid := ox + WT * 0.5 + cw
	# office front wall with its door
	p.hwall_door(cv, -iu, ox + WT * 0.5, -iu + ow * 0.5, 1.0, "office", "in", -1.0)
	p.vwall(ox, cv - WT * 0.5, p.dp - WT, "in")
	# the bars, each cell with its gate
	var g1 := ox + WT * 0.5 + cw * 0.5
	var g2 := mid + cw * 0.5
	p.hwall(cv, ox + WT * 0.5, g1 - 0.45, "bars")
	p.door(g1, cv, 0.9, true, "cell", -1.0)
	p.hwall(cv, g1 + 0.45, mid, "bars")
	p.hwall(cv, mid, g2 - 0.45, "bars")
	p.door(g2, cv, 0.9, true, "cell", -1.0)
	p.hwall(cv, g2 + 0.45, iu, "bars")
	p.vwall(mid, cv, p.dp - WT, "in")
	var cells := []
	for k in 2:
		var u0 := ox + WT * 0.5 if k == 0 else mid + WT * 0.5
		var u1 := mid - WT * 0.5 if k == 0 else iu
		p.add("cell", u0, cv + WT * 0.5, u1, bv1, false, false, 0, "cell", Vector2(0, -1))
		cells.append(p.wrect(u0, cv + WT * 0.5, u1, bv1))
		p.add("bench", u1 - 0.6, cv + 0.55, u1, bv1, true, false, 0, "cot", Vector2(-1, 0))
		p.dec("bucket", u0 + 0.1, bv1 - 0.45, u0 + 0.45, bv1 - 0.1)
		p.lamp((u0 + u1) * 0.5, (cv + bv1) * 0.5, "cage")
	p.spots["cells"] = cells
	# the captain's office
	var od := -iu + ow * 0.5
	var ou := -iu + ow * 0.42
	p.add("desk", ou - 0.75, 8.2, ou + 0.75, 8.8, true, false, 0, "captain_desk", Vector2(0, -1))
	p.dec("chair", ou - 0.28, 8.88, ou + 0.28, 9.42, Vector2(0, -1), {"style": "boss"})
	p.spot("captain", ou, 9.2)
	p.add("cabinet", ox - WT * 0.5 - 0.5, cv + 0.25, ox - WT * 0.5, cv + 1.05, true, false, 0, "file_cabinet", Vector2(-1, 0))
	p.dec("flag", -iu + 0.05, bv1 - 0.45, -iu + 0.45, bv1 - 0.05)
	p.dec("coat_rack", -iu + 0.08, cv + 0.2, -iu + 0.52, cv + 0.64)
	p.lamp(ou, 8.2, "banker")
	p.lamp(0.0, (split + cv) * 0.5, "cage")
	p.room = "shop"
	return Vector3(split, su, sv)


# ------------------------------------------------------------------ the warehouses on the quay

static func _warehouse(p: Plan) -> Vector3:
	var iu := p.iu
	var hw := p.hw
	var dp := p.dp
	p.floors = {"shop": "concrete", "back": "planks"}
	# front wall: the man door in the middle, a window either side, a loading door on the right
	p.room = "shop"
	var ld0 := minf(4.2, hw - 4.4)
	var ld1 := ld0 + 3.4
	p.hwall_door(WT * 0.5, -hw, hw, 0.0, DOOR_W, "front", "front", -1.0)
	p.vwall(-hw + WT * 0.5, 0.0, dp, "side")
	p.vwall(hw - WT * 0.5, 0.0, dp, "side")
	p.hwall(dp - WT * 0.5, -hw, hw, "back")
	for s: float in [-1.0, 1.0]:
		var a := 1.1 * s
		var b := minf(2.9, ld0 - 0.4) * s
		p.add("window", minf(a, b), 0.0, maxf(a, b), WT, false, true, 15, "window_warehouse", Vector2(0, -1), {"glass_v": WT, "ledge": 0.0})
		p.openings.append({"r": p.lrect(minf(a, b), 0.0, maxf(a, b), WT), "style": "glass", "item": p.items.size() - 1})
	p.openings.append({"r": p.lrect(ld0, 0.0, ld1, WT), "style": "loading"})
	p.openings.append({"r": p.lrect(-2.2, dp - WT, 2.2, dp), "style": "loading"})
	p.openings.append({"r": p.lrect(-hw + 0.9, dp - WT, -hw + 3.2, dp), "style": "glass"})
	p.openings.append({"r": p.lrect(-hw + 1.2, 0.0, -hw + 3.6, WT), "style": "glass"})
	# the office in the front-left corner, glazed partition, door onto the floor
	var ox := -hw + 4.4
	var oy := 4.5
	p.vwall_door(ox, WT, oy + WT * 0.5, 2.9, INNER_DOOR, "office", "glass_wall", 1.0)
	p.hwall(oy, -iu, ox + WT * 0.5, "glass_wall")
	p.spots["_office"] = p.wrect(-iu, WT, ox - WT * 0.5, oy - WT * 0.5)
	p.room = "back"
	p.add("desk", -iu, 1.4, -iu + 0.8, 3.0, true, false, 0, "office_desk", Vector2(1, 0))
	p.dec("chair", -iu + 0.9, 1.95, -iu + 1.4, 2.45, Vector2(-1, 0), {"style": "wood"})
	p.add("phone", -iu + 0.12, 2.45, -iu + 0.45, 2.8, false, false, 0, "desk_phone", Vector2(1, 0))
	p.add("stove", ox - WT * 0.5 - 0.75, oy - WT * 0.5 - 0.75, ox - WT * 0.5 - 0.1, oy - WT * 0.5 - 0.1, true, false, 0, "potbelly", Vector2(-1, -1))
	p.add("cabinet", -iu, oy - 1.2, -iu + 0.5, oy - WT * 0.5, true, false, 0, "file_cabinet", Vector2(1, 0))
	p.add("safe", -iu, WT, -iu + 0.7, WT + 0.7, true, false, 0, "safe", Vector2(1, 0))
	p.dec("calendar", ox - WT * 0.5 - 0.06, 0.8, ox - WT * 0.5, 1.5, Vector2(-1, 0))
	p.lamp(-hw + 2.2, 2.4, "bulb")
	p.room = "shop"
	# the watchman's tally desk just inside the door
	var tu := -2.3
	p.add("counter", tu - 0.9, 2.4, tu + 0.9, 3.0, true, false, 0, "tally_desk", Vector2(0, -1))
	p.spot("register", tu, 2.0)
	var ov := 3.5
	# the freight elevator in the back-right corner
	p.add("elevator", iu - 3.4, dp - WT - 3.2, iu, dp - WT, true, false, 0, "elevator", Vector2(-1, 0))
	# pallets by bay: the World stacks the stock here
	var st0 := Vector2(0.6, 4.6)
	var st1 := Vector2(iu - 0.8, dp - WT - 4.2)
	p.spots["stock"] = p.wrect(st0.x, st0.y, st1.x, st1.y)
	p.dec("bays", st0.x - 0.3, st0.y - 0.3, st1.x + 0.3, st1.y + 0.3)
	# crates, barrels and sacks along the walls (solid), a speakeasy corner when the booze flows
	var ws := []
	ws.append([-iu, 5.4, -iu + 1.4, 7.4, "crate_stack"])
	ws.append([-iu, 8.0, -iu + 1.4, 10.4, "crate_stack"])
	ws.append([-iu, 11.0, -iu + 1.1, dp - WT, "barrel_stack"])
	for w in ws:
		p.add("crates", w[0], w[1], w[2], w[3], true, false, 0, w[4], Vector2(1, 0))
	var bar0 := -iu + 2.2
	var bar1 := -0.8
	p.add("bar" if p.speak else "crates", bar0, dp - WT - 0.9, bar1, dp - WT, true, p.speak, 25 if p.speak else 0,
		"crate_bar" if p.speak else "crate_row", Vector2(0, -1))
	var tvv := dp - WT - 2.4
	var tables := []
	var patrons := []
	for k in 2:
		var tu2 := bar0 + 0.8 + k * 1.9
		p.add("table" if p.speak else "crates", tu2 - 0.38, tvv - 0.38, tu2 + 0.38, tvv + 0.38, true, false, 0,
			"barrel_table" if p.speak else "barrel", Vector2(0, -1))
		tables.append([tu2, tvv])
		if p.speak:
			for ch in [[-0.62, 0.0, 1.0, 0.0], [0.62, 0.0, -1.0, 0.0], [0.0, -0.62, 0.0, 1.0]]:
				p.dec("chair", tu2 + ch[0] - 0.2, tvv + ch[1] - 0.2, tu2 + ch[0] + 0.2, tvv + ch[1] + 0.2, Vector2(ch[2], ch[3]), {"style": "crate"})
				patrons.append([tu2 + ch[0], tvv + ch[1]])
	if p.speak:
		p.spot("bar", (bar0 + bar1) * 0.5, dp - WT - 0.35)
		var stools := []
		var su := bar0 + 0.4
		while su < bar1 - 0.3:
			p.dec("stool", su - 0.19, dp - WT - 1.35, su + 0.19, dp - WT - 0.97, Vector2(0, 1), {"style": "crate"})
			stools.append([su, dp - WT - 1.16])
			su += 0.75
		p.spot_list("stools", stools)
		p.spot_list("tables", tables)
		p.spot_list("patrons", patrons + stools)
		p.lamp((bar0 + bar1) * 0.5, dp - WT - 1.6, "speak")
	p.dec("pallets", iu - 1.6, 0.6, iu - 0.2, 2.2)
	p.dec("handtruck", 0.9, 3.2, 1.5, 3.9, Vector2(1, 0))
	p.dec("hoist", 2.0, 6.0, 3.2, 7.2)
	p.dec("scale", iu - 1.5, 3.0, iu - 0.3, 4.0, Vector2(-1, 0), {"style": "platform"})
	p.dec("sacks", iu - 1.4, dp - WT - 4.0, iu - 0.1, dp - WT - 3.35, Vector2(-1, 0), {"style": "coffee"})
	for k in 3:
		p.lamp(-4.0 + k * 5.0, 6.5, "industrial")
	p.lamp(2.0, 11.0, "industrial")
	p.spot("watch", tu, ov)
	return Vector3(dp, tu, ov)
