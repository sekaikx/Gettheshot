class_name InteriorArt
extends Node2D
## Draws the inside of every business: floors, walls, doors, counters, shelves, the owner's
## trade goods, broken glass, the speakeasy in the back room, the club's office. Hidden under the
## roofs until the local player walks in (the roof fades). Lives on the world canvas.
##
## One child Node2D per lot, placed and turned into the lot's own frame (x along the front, +y out
## of the front door), so each draws once and Godot culls the ones off screen. update_from_game()
## redraws only the lots whose state changed. A second, tiny child per lot holds the lit bulbs:
## it fades in at night by its modulate alone (no redraw).

const Kit := preload("res://scripts/world2d/rooms/kit.gd")
const S := preload("res://scripts/world2d/rooms/structure.gd")
const F := preload("res://scripts/world2d/rooms/furnish.gd")
const D := preload("res://scripts/world2d/rooms/decor.gd")

## Deco that hangs on a wall: drawn after the walls so it sits on them.
const ON_WALL := ["photos", "portrait", "clock", "board", "calendar", "chalkboard"]
const SEATS := ["chair", "stool"]

var plan: CityPlan
var layouts := {}        # lot id -> Interiors.layout(...)
var night := 0.0

var _lots := {}          # lot id -> {"lot", "kind", "node", "glow", "state"}
var _speak_lit := {}     # lot id -> true when its speakeasy glow is on (dynamic light)
var _lights_synced := false


func build(p: CityPlan) -> void:
	plan = p
	z_index = W.Z_FLOOR
	for b in Game.biz:
		var lot: Dictionary = plan.lots[int(b["lot"])]
		add_lot(lot, String(b["kind"]), _state_of(b))


func layout_of(lot_id: int) -> Dictionary:
	return layouts.get(lot_id, {})


## Lay out and draw one lot. `state` = {"broken": [ids], "speak": bool, "closed": bool, "stock": int}.
## (build() does this for every business; test scenes call it for lots of their own.)
func add_lot(lot: Dictionary, kind: String, state: Dictionary = {}) -> void:
	var id := int(lot["id"])
	var st := _norm(state)
	var lay := Interiors.build(lot, kind, bool(st["speak"]))
	layouts[id] = lay
	var node := Node2D.new()
	node.name = "Lot%d" % id
	node.transform = lay["xform"]
	node.z_as_relative = false
	node.z_index = W.Z_FURNITURE
	add_child(node)
	var glow := Node2D.new()
	glow.name = "Bulbs"
	glow.z_index = 1
	glow.modulate = Color(1, 1, 1, night)
	glow.visible = night > 0.02
	node.add_child(glow)
	var rec := {"lot": lot, "kind": kind, "node": node, "glow": glow, "state": st}
	_lots[id] = rec
	node.draw.connect(_draw_lot.bind(id))
	glow.draw.connect(_draw_bulbs.bind(id))
	node.queue_redraw()
	glow.queue_redraw()


## Change one lot's state by hand (test scenes); the game uses update_from_game().
func set_lot_state(lot_id: int, state: Dictionary) -> void:
	if _lots.has(lot_id):
		_apply(lot_id, _norm(state))


## Re-read Game.biz: broken items ("broken": [item ids]), speakeasy in the back ("speak"), padlocked
## by the feds ("closed_until" >= Game.month), stock in the cellar ("stock").
func update_from_game() -> void:
	for b in Game.biz:
		var id := int(b["lot"])
		if _lots.has(id):
			_apply(id, _state_of(b))


func set_night(n: float, _wet: float) -> void:
	night = n
	for id in _lots:
		var g: Node2D = _lots[id]["glow"]
		g.modulate = Color(1, 1, 1, clampf(n * 1.3, 0.0, 1.0))
		g.visible = n > 0.02
	if not _lights_synced:
		_lights_synced = true
		for id in _lots:
			_sync_speak_light(id)


## Lamps inside (same format as CityGround.lights()): a warm pool under each ceiling lamp.
func lights() -> Array:
	var out := []
	for id in layouts:
		var lay: Dictionary = layouts[id]
		var n := 0
		for l in lay.get("lamps", []):
			var style := String(l["style"])
			if style in ["banker", "speak"]:
				continue
			var r := 3.4
			var e := 0.55
			match style:
				"industrial": r = 6.0
				"billiard": r = 2.6
				"shade": r = 2.4
				"chandelier": r = 4.2
				"cage", "bulb": r = 2.8
			out.append({"pos": l["w"], "r": r * W.M, "color": Pal.WINDOW_WARM, "e": e, "shape": "round"})
			n += 1
			if n >= 4:
				break
	return out


# ------------------------------------------------------------------ state

static func _norm(state: Dictionary) -> Dictionary:
	var br: Array = []
	for x in state.get("broken", []):
		br.append(int(x))
	br.sort()
	return {"broken": br, "speak": bool(state.get("speak", false)), "closed": bool(state.get("closed", false)),
		"stock": int(state.get("stock", 0))}


static func _state_of(b: Dictionary) -> Dictionary:
	return _norm({"broken": b.get("broken", []), "speak": bool(b.get("speak", false)),
		"closed": int(b.get("closed_until", -1)) >= int(Game.month), "stock": int(b.get("stock", 0))})


func _apply(id: int, st: Dictionary) -> void:
	var rec: Dictionary = _lots[id]
	var old: Dictionary = rec["state"]
	# the bar's bottles only show a handful of stock levels, so small changes don't redraw
	var same: bool = old["broken"] == st["broken"] and old["speak"] == st["speak"] and old["closed"] == st["closed"] \
		and mini(int(old["stock"]), 12) / 3 == mini(int(st["stock"]), 12) / 3
	rec["state"] = st
	if same:
		return
	if old["speak"] != st["speak"]:
		# the same walls and solid rects, the back room furnished as a bar (and its spots added)
		layouts[id] = Interiors.build(rec["lot"], String(rec["kind"]), bool(st["speak"]))
		_sync_speak_light(id)
	(rec["node"] as Node2D).queue_redraw()
	(rec["glow"] as Node2D).queue_redraw()


## The speakeasy's warm glow is a dynamic light in the World's lightmap (it comes and goes).
func _sync_speak_light(id: int) -> void:
	var w := get_parent()
	if w == null or not ("lighting" in w) or w.get("lighting") == null:
		return
	var lighting: Object = w.get("lighting")
	var lay: Dictionary = layouts.get(id, {})
	var on := bool(_lots[id]["state"]["speak"]) and not bool(_lots[id]["state"]["closed"]) and not lay.is_empty()
	var key := "speak_%d" % id
	if on:
		var back: Rect2 = lay["back"]
		var at: Vector2 = back.get_center() if back.size != Vector2.ZERO else (lay["rect"] as Rect2).get_center()
		if (lay["spots"] as Dictionary).has("bar"):
			at = at.lerp(lay["spots"]["bar"], 0.35)
		lighting.call("set_dynamic", key, {"pos": at, "r": 4.2 * W.M, "color": Pal.LAMP.lerp(Pal.NEON_RED, 0.18), "e": 0.9, "shape": "round"})
		_speak_lit[id] = true
	elif _speak_lit.has(id):
		lighting.call("hide_dynamic", key)
		_speak_lit.erase(id)


# ------------------------------------------------------------------ drawing

func _local_rect(lay: Dictionary, r: Rect2) -> Rect2:
	var inv: Transform2D = (lay["xform"] as Transform2D).affine_inverse()
	var a := inv * r.position
	var b := inv * r.end
	return Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (a - b).abs())


func _draw_lot(id: int) -> void:
	var rec: Dictionary = _lots[id]
	var node: Node2D = rec["node"]
	var lay: Dictionary = layouts[id]
	var st: Dictionary = rec["state"]
	var kind := String(rec["kind"])
	var sd := int(lay["seed"])
	var k := Kit.new(node, (lay["xform"] as Transform2D).get_rotation(), sd)
	var size: Vector2 = lay["size"]
	var hw := size.x * 0.5
	var split := float(lay["split"]) * W.M
	var broken: Array = st["broken"]
	var closed := bool(st["closed"])
	var whole := Rect2(-hw, -size.y, size.x, size.y)
	var floors: Dictionary = lay["floors"]
	# 1. floors
	if kind == "warehouse":
		S.floor(k, whole, String(floors.get("shop", "concrete")), sd)
		var office := _local_rect(lay, lay["back"])
		if office.size.x > 1.0:
			S.floor(k, office, String(floors.get("back", "planks")), sd + 5)
	else:
		S.floor(k, Rect2(-hw, -split, size.x, split), String(floors.get("shop", "planks")), sd)
		S.floor(k, Rect2(-hw, -size.y, size.x, size.y - split), String(floors.get("back", "planks")), sd + 5)
	var deco: Array = lay["deco"]
	for d in deco:
		if D.layer_of(String(d["type"])) == 0:
			D.draw(k, d)
			k.reset()
	S.wall_ao(k, lay["lwalls"], whole)
	S.wall_shadows(k, lay["lwalls"])
	# 2. furniture: shadows first so nothing's shadow falls across its neighbour's top
	var items: Array = lay["items"]
	for it in items:
		F.shadow(k, it)
	for d in deco:
		if String(d["type"]) in SEATS:
			D.draw(k, d)
	for it in items:
		F.draw(k, it, {"broken": broken.has(int(it["id"])), "closed": closed, "stock": int(st["stock"]), "night": night})
	for d in deco:
		var t := String(d["type"])
		if D.layer_of(t) == 1 and t not in SEATS and t not in ON_WALL:
			D.draw(k, d)
	# 3. what a shakedown leaves on the floor
	for it in items:
		if broken.has(int(it["id"])):
			D.debris(k, it, kind)
	# 4. walls, glass, doors
	S.walls(k, lay["lwalls"], sd)
	S.openings(k, lay["openings"], broken, sd)
	S.doors(k, lay["ldoors"], W.WALL * W.M)
	for d in deco:
		if String(d["type"]) in ON_WALL:
			D.draw(k, d)
	# 5. under the ceiling
	for d in deco:
		if D.layer_of(String(d["type"])) == 2 and not closed:
			D.draw(k, d)
	for l in lay["lamps"]:
		D.lamp(k, l, 0.0)
	if bool(lay.get("speak", false)) and kind != "warehouse" and not closed:
		# low warm light in the speakeasy
		var br := Rect2(-hw, -size.y, size.x, size.y - split)
		node.draw_rect(br.grow(-W.WALL * W.M), Color(Pal.LAMP.lerp(Pal.NEON_RED, 0.25), 0.07))
	if closed:
		_draw_closed(k, lay, whole)
	k.reset()


## Padlocked by the feds: dark inside, dust sheets (drawn by the furniture), the door chained.
func _draw_closed(k: Kit, lay: Dictionary, whole: Rect2) -> void:
	var node: CanvasItem = k.ci
	node.draw_rect(whole.grow(-W.WALL * W.M), Color(Pal.SIGN_BLACK, 0.55))
	for d in lay["ldoors"]:
		if String(d["kind"]) != "front":
			continue
		var p: Vector2 = d["p"]
		var w := float(d["w"])
		# two planks nailed across the door, a chain and a padlock
		for j in 2:
			var y := p.y - 3.0 + j * 7.0
			var a := Vector2(p.x - w * 0.6, y - 3.0 + j * 6.0)
			var b := Vector2(p.x + w * 0.6, y + 3.0 - j * 6.0)
			k.line(a + Vector2(2, 3), b + Vector2(2, 3), Color(Kit.SH_COL, 0.35), 6.0)
			k.line(a, b, Pal.PLANKS.lightened(0.15), 5.0)
			k.disc(a + (b - a) * 0.08, 1.2, Pal.TRACK)
			k.disc(a + (b - a) * 0.92, 1.2, Pal.TRACK)
		k.disc(p + Vector2(0, 2), 4.5, Pal.BRASS.darkened(0.1))
		k.ring(p + Vector2(0, -2), 3.0, Pal.TRACK.lightened(0.2), 1.5)
		k.disc(p + Vector2(0, 2.5), 1.2, Pal.SIGN_BLACK)


## The lit bulbs (only seen at night: the node's modulate fades them in).
func _draw_bulbs(id: int) -> void:
	var rec: Dictionary = _lots[id]
	if bool(rec["state"]["closed"]):
		return
	var g: Node2D = rec["glow"]
	var lay: Dictionary = layouts[id]
	for l in lay["lamps"]:
		var p: Vector2 = l["p"]
		var style := String(l["style"])
		var warm := Pal.LAMP
		var r := 6.0
		match style:
			"industrial": r = 9.0
			"chandelier": r = 10.0
			"speak": warm = Pal.LAMP.lerp(Pal.NEON_RED, 0.3)
			"banker": r = 4.0
			"billiard": r = 9.0
		for j in 3:
			g.draw_circle(p, r * (2.2 - j * 0.6), Color(warm, 0.08 + j * 0.06), true, -1.0, true)
		if style == "billiard":
			for sgn: float in [-1.0, 1.0]:
				g.draw_circle(p + Vector2(sgn * 12.0, 0), 3.0, Color(1.0, 0.95, 0.8), true, -1.0, true)
		else:
			g.draw_circle(p, r * 0.42, Color(1.0, 0.95, 0.8), true, -1.0, true)
