class_name Interiors3D
extends Node3D
## The inside of every business in 3D: floor, walls, doors, counters, shelves, tables, the owner's
## trade goods, broken glass, the speakeasy in the back, the club's office. Built from the same layout
## data as the 2D rooms (Interiors.build(...) -> InteriorArt.layouts, see scripts/world2d/interiors.gd).
##
## Interface (View3D calls these):
##   build(layouts: Dictionary)       lot id -> layout dict (pixels, see Interiors); registers every room
##   update_from_game()               redo what changed: broken items, speakeasy, padlocked, stock
##   set_night(night, wet)            bulbs, light pools and window glow
##   set_inside(lot_id)               the local player's building (-1 = none)
##
## How it works: every room is one MeshInstance3D (one ArrayMesh, one surface per material, see rooms/mb.gd)
## in the lot's own frame, built lazily the first time the camera comes near (one room per frame), so the
## whole city of interiors costs nothing until you walk there. Props live in rooms/props_a.gd, props_b.gd,
## decos.gd; walls, glass and doors in rooms/shell.gd; floors and materials in rooms/mats.gd.
## Light: warm emissive bulbs and additive light pools (cheap, no lights) in every room, plus a pool of two real
## OmniLight3Ds that follow the player's room.

const MB := preload("res://scripts/world3d/rooms/mb.gd")
const Mats := preload("res://scripts/world3d/rooms/mats.gd")
const Shell := preload("res://scripts/world3d/rooms/shell.gd")
const Items := preload("res://scripts/world3d/rooms/items.gd")
const Decos := preload("res://scripts/world3d/rooms/decos.gd")
const P := preload("res://scripts/world3d/rooms/parts.gd")

const M := 48.0
const RANGE := 48.0           # rooms this close to the camera focus are built and shown
const FLOOR_Y := 0.16         # the room frame sits at sidewalk level (just above the street blocks): no z-fighting

var layouts := {}
var always_visible := false   # test scenes: show every room

var _rooms := {}              # lot id -> {"node","mi","center","state","override","built"}
var _night := 0.0
var _wet := 0.0
var _inside := -1
var _lights: Array[OmniLight3D] = []
var _timer := 0.0
var _verts := 0


func _ready() -> void:
	for i in 2:
		var l := OmniLight3D.new()
		l.name = "RoomLight%d" % i
		l.light_color = Color(1.0, 0.84, 0.62)
		l.omni_range = 8.0
		l.omni_attenuation = 1.1
		l.shadow_enabled = false
		l.visible = false
		add_child(l)
		_lights.append(l)
	set_process(true)


# ------------------------------------------------------------------ interface

func build(p_layouts: Dictionary) -> void:
	layouts = p_layouts
	for id in layouts:
		_add_room(int(id))
	update_from_game()


func update_from_game() -> void:
	for id in _rooms:
		var rec: Dictionary = _rooms[id]
		if rec.has("override"):
			continue
		var st := _state_of(int(id))
		if st != rec["state"]:
			rec["state"] = st
			rec["built"] = false
			_touch(int(id))


func set_night(night: float, wet: float) -> void:
	_night = night
	_wet = wet
	Mats.set_night(night)
	_update_lights()


func set_inside(lot_id: int) -> void:
	var old := _inside
	_inside = lot_id
	if _rooms.has(lot_id):
		_ensure(lot_id)
		(_rooms[lot_id]["node"] as Node3D).visible = true
	for id in [old, lot_id]:
		if _rooms.has(id) and _rooms[id]["mi"] != null:
			var mi: MeshInstance3D = _rooms[id]["mi"]
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if id == lot_id else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_update_lights()


## Test scenes: set one room's state by hand ({"broken": [ids], "closed": bool, "stock": int}); the layout in
## `layouts` may be swapped first (a speakeasy) and decides "speak".
func set_lot_state(lot_id: int, st: Dictionary) -> void:
	if not _rooms.has(lot_id):
		return
	var rec: Dictionary = _rooms[lot_id]
	rec["override"] = st
	rec["state"] = _norm(lot_id, st)
	rec["built"] = false
	_touch(lot_id)


func room_verts(lot_id: int) -> int:
	return int(_rooms[lot_id].get("verts", 0)) if _rooms.has(lot_id) else 0


func room_node(lot_id: int) -> Node3D:
	return _rooms[lot_id]["node"] if _rooms.has(lot_id) else null


## Build every room now (test scenes).
func build_all_now() -> void:
	for id in _rooms:
		_ensure(int(id))
		(_rooms[id]["node"] as Node3D).visible = true


func stats() -> Dictionary:
	var built := 0
	for id in _rooms:
		if _rooms[id]["mi"] != null:
			built += 1
	return {"rooms": _rooms.size(), "built": built, "verts": _verts}


# ------------------------------------------------------------------ rooms

func _add_room(id: int) -> void:
	var lay: Dictionary = layouts[id]
	var xf2: Transform2D = lay["xform"]
	var node := Node3D.new()
	node.name = "Room%d" % id
	node.transform = Transform3D(Basis(Vector3(xf2.x.x, 0, xf2.x.y), Vector3.UP, Vector3(xf2.y.x, 0, xf2.y.y)),
		Vector3(xf2.origin.x / M, FLOOR_Y, xf2.origin.y / M))
	node.visible = false
	add_child(node)
	var r: Rect2 = lay["rect"]
	_rooms[id] = {"node": node, "mi": null, "center": Vector3(r.get_center().x / M, 0, r.get_center().y / M),
		"state": _state_of(id), "built": false}


static func _norm(id: int, st: Dictionary) -> Dictionary:
	var br: Array = []
	for x in st.get("broken", []):
		br.append(int(x))
	br.sort()
	return {"broken": br, "closed": bool(st.get("closed", false)), "stock": mini(int(st.get("stock", 0)), 12) / 3, "speak": false}


func _state_of(id: int) -> Dictionary:
	var out := {"broken": [], "closed": false, "stock": 0}
	for b in Game.biz:
		if int(b["lot"]) == id:
			out = {"broken": b.get("broken", []), "closed": int(b.get("closed_until", -1)) >= int(Game.month), "stock": int(b.get("stock", 0))}
			break
	var st := _norm(id, out)
	st["speak"] = bool((layouts.get(id, {}) as Dictionary).get("speak", false))
	return st


## A room's state or layout changed: rebuild it now if it is on screen, else when the camera gets near.
func _touch(id: int) -> void:
	var rec: Dictionary = _rooms[id]
	if (rec["node"] as Node3D).visible or id == _inside:
		_ensure(id)


func _ensure(id: int) -> void:
	var rec: Dictionary = _rooms[id]
	var st := _state_of(id) if not rec.has("override") else _norm(id, rec["override"])
	st["speak"] = bool((layouts.get(id, {}) as Dictionary).get("speak", false))
	if rec["built"] and st == rec["state"]:
		return
	rec["state"] = st
	_build_room(id)
	rec["built"] = true


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 0.12
	var cam := get_viewport().get_camera_3d()
	if cam == null and not always_visible:
		return
	var focus := Vector3.ZERO
	if cam != null:
		var dir := -cam.global_transform.basis.z
		var pos := cam.global_position
		focus = pos
		if dir.y < -0.05:
			focus = pos + dir * (-pos.y / dir.y)
	var best := -1
	var best_d := 1e9
	for id in _rooms:
		var rec: Dictionary = _rooms[id]
		var node: Node3D = rec["node"]
		var c: Vector3 = rec["center"]
		var d := Vector2(c.x - focus.x, c.z - focus.z).length()
		var vis: bool = always_visible or d < RANGE or id == _inside
		if vis != node.visible:
			node.visible = vis
		if vis and not rec["built"] and d < best_d:
			best = int(id)
			best_d = d
	if best >= 0:
		_ensure(best)
		_timer = 0.0


# ------------------------------------------------------------------ lights

func _update_lights() -> void:
	if _lights.size() < 2:
		return
	var energy := lerpf(0.28, 2.0, _night)
	for l in _lights:
		l.visible = false
	if not layouts.has(_inside):
		return
	var lay: Dictionary = layouts[_inside]
	var shop: Rect2 = lay["shop"]
	var back: Rect2 = lay["back"]
	_lights[0].global_position = V3.pos(shop.get_center(), 2.7)
	_lights[0].omni_range = clampf(maxf(shop.size.x, shop.size.y) / M * 0.75, 6.0, 12.0)
	_lights[0].light_energy = energy
	_lights[0].visible = true
	if back.size != Vector2.ZERO:
		_lights[1].global_position = V3.pos(back.get_center(), 2.7)
		_lights[1].omni_range = clampf(maxf(back.size.x, back.size.y) / M * 0.8, 5.0, 10.0)
		_lights[1].light_energy = energy * (1.1 if bool(lay.get("speak", false)) else 0.9)
		_lights[1].light_color = Color(1.0, 0.62, 0.46) if bool(lay.get("speak", false)) else Color(1.0, 0.84, 0.62)
		_lights[1].visible = true


# ------------------------------------------------------------------ building one room

func _build_room(id: int) -> void:
	var rec: Dictionary = _rooms[id]
	var lay: Dictionary = layouts[id]
	var st: Dictionary = rec["state"]
	var kind := String(lay.get("kind", ""))
	var broken: Array = st["broken"]
	var closed: bool = st["closed"]
	var sd := int(lay.get("seed", 0))
	var xf2: Transform2D = lay["xform"]
	var size: Vector2 = lay["size"]
	var hw := size.x * 0.5 / M
	var dp := size.y / M
	var split := float(lay["split"])
	var mb := MB.new()
	if closed:
		mb.tint = Color(0.5, 0.5, 0.58, 1.0)
	var th := Shell.theme(kind)
	var floors: Dictionary = lay["floors"]
	var lot_rect: Rect2 = lay["rect"]

	# 1. floors
	if kind == "warehouse":
		Shell.floor_quad(mb, -hw, -dp, hw, 0.0, String(floors.get("shop", "concrete")))
		var office := _local_rect(xf2, lay["back"])
		if office.size.x > 0.1:
			var o := Rect2(office.position / M, office.size / M)
			Shell.floor_quad(mb, o.position.x, o.position.y, o.end.x, o.end.y, String(floors.get("back", "planks")))
	else:
		Shell.floor_quad(mb, -hw, -split, hw, 0.0, String(floors.get("shop", "planks")))
		Shell.floor_quad(mb, -hw, -dp, hw, -split, String(floors.get("back", "planks")))

	# 2. decoration that lies on the floor
	for d in lay["deco"]:
		var t := String(d["type"])
		var lr: Rect2 = d["lr"]
		var r := Rect2(lr.position / M, lr.size / M)
		match t:
			"rug":
				Decos.rug(mb, r.position.x, r.position.y, r.end.x, r.end.y, String(d.get("style", "")), false)
			"doormat", "bays", "puddle", "sawdust", "hair":
				_place_deco(mb, d, lr, closed)

	# 3. walls, glass and doors
	var walls: Array = lay["lwalls"]
	var openings: Array = lay["openings"]
	var items: Array = lay["items"]
	var wall_hs: Array = []
	for w in walls:
		var wr: Rect2 = w["r"]
		var x0 := wr.position.x / M
		var z0 := wr.position.y / M
		var x1 := wr.end.x / M
		var z1 := wr.end.y / M
		var horiz := (x1 - x0) >= (z1 - z0)
		var wh := _wall_h(xf2, lot_rect, wr.get_center(), horiz)
		wall_hs.append(wh)
		var style := String(w["style"])
		match style:
			"bars":
				Shell.bars(mb, x0, z0, x1, z1)
			"glass_wall":
				Shell.glass_wall(mb, x0, z0, x1, z1)
			_:
				_wall(mb, x0, z0, x1, z1, horiz, wh, th, style, openings, broken, sd)
	for dr in lay["ldoors"]:
		var p: Vector2 = dr["p"]
		var horiz2 := absf((dr["along"] as Vector2).x) > 0.5
		var dh := _wall_h(xf2, lot_rect, p, horiz2)
		Shell.door(mb, p / M, float(dr["w"]) / M, dr["along"], dr["out"], String(dr["kind"]), dh, closed, sd)
	# openings that are not inside a wall piece we split (loading doors in wall gaps etc.) are drawn by _wall

	# 4. furniture
	var regs: Array = []
	for it in items:
		if String(it["art"]) == "register":
			regs.append(it)
	for it in items:
		var lr2: Rect2 = it["lr"]
		var face: Vector2 = it["face"]
		var art := String(it["art"])
		var type := String(it["type"])
		var c := Vector3((lr2.position.x + lr2.size.x * 0.5) / M, 0, (lr2.position.y + lr2.size.y * 0.5) / M)
		var yaw := atan2(face.x, face.y)
		var diag := absf(face.x) > 0.2 and absf(face.y) > 0.2
		var w2 := lr2.size.x / M
		var d2 := lr2.size.y / M
		if diag:
			w2 = minf(lr2.size.x, lr2.size.y) / M
			d2 = w2
		elif absf(face.y) < absf(face.x):
			w2 = lr2.size.y / M
			d2 = lr2.size.x / M
		# which way does the front look in the world? (north = away from the camera)
		var fw: Vector2 = xf2.basis_xform(face).normalized()
		var rev := fw.y < -0.55
		var hs := 1.0
		if rev and Items.is_tall(it):
			hs = 0.62
		var is_broken := broken.has(int(it["id"]))
		var ctx := {"broken": is_broken, "closed": closed, "stock": int(st["stock"]) * 3, "rev": rev, "kind": kind, "avoid": []}
		if art in ["wood_counter", "marble_counter", "butcher_counter", "fish_counter", "pawn_counter", "cutting_counter"]:
			var av: Array = []
			var axis := Vector2(cos(yaw), -sin(yaw))
			for rg in regs:
				var rl: Rect2 = rg["lr"]
				var rc := Vector2((rl.position.x + rl.size.x * 0.5) / M, (rl.position.y + rl.size.y * 0.5) / M)
				var off := rc - Vector2(c.x, c.z)
				if absf(off.dot(Vector2(sin(yaw), cos(yaw)))) < d2 * 0.5 + 0.35:
					var pr := off.dot(axis)
					av.append([pr - 0.4, pr + 0.4])
			ctx["avoid"] = av
		mb.at(c, yaw, hs)
		Items.draw(mb, it, w2, d2, ctx)
		mb.pop()
		if is_broken:
			mb.at(c, yaw, 1.0)
			Items.debris(mb, it, w2, d2, kind)
			mb.pop()
		var _t := type

	# 5. the rest of the decoration
	for d in lay["deco"]:
		var t2 := String(d["type"])
		if t2 in ["rug", "doormat", "bays", "puddle", "sawdust", "hair"]:
			continue
		if closed and t2 in ["smoke", "steam", "lines", "fan", "hanging"]:
			continue
		_place_deco(mb, d, d["lr"], closed)

	# 6. lamps, light pools, the speakeasy's glow, the dust of a padlocked room
	var speak := bool(lay.get("speak", false))
	for l in lay["lamps"]:
		var lp: Vector2 = l["p"]
		var style2 := String(l["style"])
		if closed:
			continue
		var rad := Decos.lamp(mb, style2, lp.x / M, lp.y / M)
		if style2 == "banker":
			continue
		var col := Color(1.0, 0.8, 0.5, 1.0)
		if style2 == "speak":
			col = Color(1.0, 0.45, 0.35, 1.0)
		elif style2 in ["globe", "cage"]:
			col = Color(0.95, 0.95, 0.8, 1.0)
		var px := lp.x / M
		var pz := lp.y / M
		mb.flat(px - rad * 0.5, pz - rad * 0.5, px + rad * 0.5, pz + rad * 0.5, 0.02, col, "pool")
	if speak and not closed and kind != "warehouse":
		var bx0 := -hw + 0.3
		var bx1 := hw - 0.3
		mb.flat(bx0, -dp + 0.3, bx1, -split - 0.2, 0.025, Color(0.9, 0.25, 0.3, 0.8), "pool")

	var mesh := mb.finish()
	_verts += mb.verts - int(rec.get("verts", 0))
	rec["verts"] = mb.verts
	if rec["mi"] != null:
		(rec["mi"] as MeshInstance3D).queue_free()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.name = "Mesh"
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if id == _inside else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(rec["node"] as Node3D).add_child(mi)
	rec["mi"] = mi


func _place_deco(mb: MB, d: Dictionary, lr: Rect2, closed: bool) -> void:
	var face: Vector2 = d["face"]
	var c := Vector3((lr.position.x + lr.size.x * 0.5) / M, 0, (lr.position.y + lr.size.y * 0.5) / M)
	var yaw := atan2(face.x, face.y)
	var diag := absf(face.x) > 0.2 and absf(face.y) > 0.2
	var w := lr.size.x / M
	var dp := lr.size.y / M
	if diag:
		w = minf(lr.size.x, lr.size.y) / M
		dp = w
	elif absf(face.y) < absf(face.x):
		w = lr.size.y / M
		dp = lr.size.x / M
	mb.at(c, yaw)
	Decos.draw(mb, d, w, dp, closed)
	mb.pop()


## Height of a wall piece at a local point: low across the view, a backdrop at the far side.
func _wall_h(xf2: Transform2D, lot_rect: Rect2, local_px: Vector2, horiz: bool) -> float:
	var axis := xf2.x if horiz else xf2.y
	var ew := absf(axis.x) > absf(axis.y)
	var wc := xf2 * local_px
	var north := (wc.y - lot_rect.position.y) / M < 0.7
	return Shell.wall_height(ew, north)


func _local_rect(xf2: Transform2D, r: Rect2) -> Rect2:
	var inv := xf2.affine_inverse()
	var a := inv * r.position
	var b := inv * r.end
	return Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (a - b).abs())


## A wall band, cut by the glass and loading doors set into it.
func _wall(mb: MB, x0: float, z0: float, x1: float, z1: float, horiz: bool, wh: float, th: Array, style: String, openings: Array, broken: Array, sd: int) -> void:
	var cuts: Array = []
	for o in openings:
		var orc: Rect2 = o["r"]
		var ox0 := orc.position.x / M
		var oz0 := orc.position.y / M
		var ox1 := orc.end.x / M
		var oz1 := orc.end.y / M
		if ox0 >= x0 - 0.02 and ox1 <= x1 + 0.02 and oz0 >= z0 - 0.02 and oz1 <= z1 + 0.02:
			cuts.append(o)
	if cuts.is_empty():
		Shell.slab(mb, x0, z0, x1, z1, 0.0, wh, th, style)
		return
	cuts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ra: Rect2 = a["r"]
		var rb: Rect2 = b["r"]
		return (ra.position.x < rb.position.x) if horiz else (ra.position.y < rb.position.y))
	var cur := x0 if horiz else z0
	for o in cuts:
		var orc2: Rect2 = o["r"]
		var a := orc2.position.x / M if horiz else orc2.position.y / M
		var b := orc2.end.x / M if horiz else orc2.end.y / M
		if a > cur + 0.01:
			if horiz:
				Shell.slab(mb, cur, z0, a, z1, 0.0, wh, th, style)
			else:
				Shell.slab(mb, x0, cur, x1, a, 0.0, wh, th, style)
		var o_style := String(o["style"])
		var smashed: bool = o.has("item") and broken.has(int(o["item"]))
		if o_style == "loading":
			Shell.loading_door(mb, a if horiz else x0, z0 if horiz else a, b if horiz else x1, z1 if horiz else b, wh)
		else:
			Shell.window(mb, a if horiz else x0, z0 if horiz else a, b if horiz else x1, z1 if horiz else b, wh, th, smashed, sd + int(o.get("item", 0)) * 17, style in ["front", "side", "back"])
		cur = maxf(cur, b)
	var end := x1 if horiz else z1
	if end > cur + 0.01:
		if horiz:
			Shell.slab(mb, cur, z0, x1, z1, 0.0, wh, th, style)
		else:
			Shell.slab(mb, x0, cur, x1, z1, 0.0, wh, th, style)
