class_name Shopfronts
extends Node2D
## The street face of every business: awnings over the sidewalk (striped in the colour of the
## family the shop pays, the shop's name on the valance), the trade's clutter in front (fruit
## stands, a barber pole, café tables, fish on ice, the pawnbroker's three balls...), clubs'
## canopies, the precinct's steps and blue lamps, the warehouses' loading docks, padlocked
## shops' notices, the speakeasy stairs with a man by them at night. API: docs/REBUILD_2D.md,
## "Shopfronts". The art is in scripts/world2d/fronts/front_art.gd and front_items.gd.
##
## Three nodes per shop, each drawn once and redrawn only when that shop changes:
## the sidewalk (W.Z_FURNITURE), what hangs overhead (W.Z_AWNING), and a lit sign (animated
## at night, only while on screen). When you stand under an awning it turns see-through.

const FrontArt := preload("res://scripts/world2d/fronts/front_art.gd")
const PaintNode := preload("res://scripts/world2d/fronts/paint_node.gd")

const NIGHT_ON := 0.45          # shop lamps, neon and the doorman come on past this
const UNDER_ALPHA := 0.32       # an awning you're standing under
const FADE_TIME := 0.2
const ANIM_HZ := 12.0

var plan: CityPlan
var night := 0.0
var wet := 0.0

var _shops := {}          # biz id -> layout (FrontArt.plan_shop)
var _ground := {}         # biz id -> node
var _over := {}           # biz id -> node
var _lit := {}            # biz id -> node (only shops with a lit sign)
var _keys := {}           # biz id -> state key last drawn
var _aw_world := {}       # biz id -> Rect2 of its awning / canopy (world px)
var _under := -1          # the awning the local player stands under
var _doormen := {}        # biz id -> Person2D
var _kids := {}           # biz id -> Array of Person2D
var _night_on := false
var _wet_on := false
var _t := 0.0
var _acc := 0.0


func build(p: CityPlan) -> void:
	plan = p
	for c in get_children():
		c.queue_free()
	_shops.clear(); _ground.clear(); _over.clear(); _lit.clear(); _keys.clear(); _aw_world.clear()
	_doormen.clear(); _kids.clear()
	_under = -1
	for b in Game.biz:
		var lot: Dictionary = plan.lots[int(b["lot"])]
		var S := FrontArt.plan_shop(b, lot)
		FrontArt.refresh(S, b, _night_on, wet)
		var id := int(b["id"])
		_shops[id] = S
		var xf: Transform2D = S["xf"]
		var g := PaintNode.new()
		g.name = "Front%d" % id
		g.transform = xf
		g.z_index = W.Z_FURNITURE
		g.painter = FrontArt.paint_ground.bind(S)
		add_child(g)
		_ground[id] = g
		var o := PaintNode.new()
		o.name = "Over%d" % id
		o.transform = xf
		o.z_index = W.Z_AWNING
		o.painter = FrontArt.paint_over.bind(S)
		add_child(o)
		_over[id] = o
		if String(S["neon"]) != "" or String(S["marquee"]) != "":
			var l := PaintNode.new()
			l.name = "Sign%d" % id
			l.transform = xf
			l.z_index = W.Z_AWNING + 1
			l.painter = _paint_lit.bind(S)
			add_child(l)
			_lit[id] = l
		_aw_world[id] = FrontArt.awning_world(S)
		_keys[id] = FrontArt.state_key(b)
		_people(id, b)


## Re-read Game.biz: who protects / owns each shop (awning colour), closed shops (shutters down),
## speakeasies. Only the shops that changed are redrawn.
func update_owners() -> void:
	for b in Game.biz:
		var id := int(b["id"])
		if not _shops.has(id):
			continue
		var key := FrontArt.state_key(b)
		if key == String(_keys.get(id, "")):
			continue
		_keys[id] = key
		_redraw(id, b)


func set_night(n: float, w: float) -> void:
	night = n
	wet = w
	var on := n > NIGHT_ON
	var wet_on := w > 0.5
	if on == _night_on and wet_on == _wet_on:
		return
	_night_on = on
	_wet_on = wet_on
	for b in Game.biz:
		var id := int(b["id"])
		if _shops.has(id):
			_redraw(id, b)


## Light from shop windows onto the sidewalk at night, lit signs: same format as CityGround.lights().
func lights() -> Array:
	var out := []
	for id in _shops:
		out.append_array(FrontArt.lights(_shops[id]))
	return out


## Rectangles (px) that block walking: sidewalk displays, café tables, barber poles...
func solids() -> Array:
	var out := []
	for id in _shops:
		out.append_array(FrontArt.solids_world(_shops[id]))
	return out


## The awning over a spot on the sidewalk (biz id), or -1.
func awning_at(pos: Vector2) -> int:
	for id in _aw_world:
		var r: Rect2 = _aw_world[id]
		if r.size != Vector2.ZERO and r.grow(6.0).has_point(pos):
			return int(id)
	return -1


func _redraw(id: int, b: Dictionary) -> void:
	var S: Dictionary = _shops[id]
	FrontArt.refresh(S, b, _night_on, wet)
	(_ground[id] as Node2D).queue_redraw()
	(_over[id] as Node2D).queue_redraw()
	if _lit.has(id):
		(_lit[id] as Node2D).queue_redraw()
	_people(id, b)


func _paint_lit(ci: CanvasItem, S: Dictionary) -> void:
	FrontArt.paint_lit(ci, S, _t)


# ------------------------------------------------------------------ people at the door

## The speakeasy's man at the stairs (at night), kids at the candy store's gumball machine (by day).
func _people(id: int, b: Dictionary) -> void:
	var S: Dictionary = _shops[id]
	var xf: Transform2D = S["xf"]
	var slot_a: Rect2
	var slot_b: Rect2
	for it in S["items"]:
		if it["slot"] == "a":
			slot_a = it["rect"]
		else:
			slot_b = it["rect"]
	var want_door := bool(S["speak"]) and not bool(S["closed"]) and _night_on and slot_b.size != Vector2.ZERO
	var dm: Person2D = _doormen.get(id)
	if want_door and dm == null:
		dm = Person2D.new()
		var fam := int(S["fam"])
		dm.setup("crew", id * 31 + 7, W.fam_color(fam) if fam >= 0 else W.FAMILY_NONE)
		dm.z_as_relative = false
		dm.z_index = W.Z_PEOPLE
		var toward_door := -signf(slot_b.get_center().x)
		dm.position = xf * Vector2(slot_b.get_center().x + toward_door * slot_b.size.x * 0.42, W.M * 1.82)
		dm.rotation = (xf.basis_xform(Vector2(0, 1))).angle()
		add_child(dm)
		dm.set_motion(Person2D.Anim.ARMS, 0.0)
		_doormen[id] = dm
	elif dm != null:
		dm.visible = want_door
	if String(S["kind"]) == "candy":
		var want_kids := not _night_on and not bool(S["closed"])
		var kids: Array = _kids.get(id, [])
		if want_kids and kids.is_empty():
			var c := slot_a.get_center()
			var spots := [c + Vector2(-W.M * 0.2, W.M * 0.62), c + Vector2(W.M * 0.35, W.M * 0.7)]
			for k in (2 if id % 2 == 0 else 1):
				var kid := Person2D.new()
				kid.setup("kid", id * 17 + k, W.FAMILY_NONE)
				kid.z_as_relative = false
				kid.z_index = W.Z_PEOPLE
				kid.position = xf * spots[k]
				kid.rotation = (xf * c - kid.position).angle()
				add_child(kid)
				kids.append(kid)
			_kids[id] = kids
		for kid in kids:
			(kid as Node2D).visible = want_kids


# ------------------------------------------------------------------ per frame

func _process(delta: float) -> void:
	_t += delta
	_acc += delta
	if _acc < 1.0 / ANIM_HZ:
		return
	_acc = 0.0
	_fade_awning()
	if _night_on and not _lit.is_empty():
		var view := _view_rect()
		for id in _lit:
			var r: Rect2 = _aw_world[id]
			if r.intersects(view):
				(_lit[id] as Node2D).queue_redraw()


## See-through awning over the local player, so you can see yourself at the door.
func _fade_awning() -> void:
	var w := get_parent()
	var me: Variant = w.get("local_actor") if w else null
	var under := -1
	if me is Node2D and is_instance_valid(me):
		under = awning_at((me as Node2D).global_position)
	if under == _under:
		return
	for id in [_under, under]:
		if id < 0 or not _over.has(id):
			continue
		var target := UNDER_ALPHA if id == under else 1.0
		for node in [_over[id], _lit.get(id)]:
			if node == null:
				continue
			var tw := (node as Node2D).create_tween()
			tw.tween_property(node, "modulate:a", target, FADE_TIME)
	_under = under


func _view_rect() -> Rect2:
	var vp := get_viewport()
	if vp == null:
		return Rect2()
	return get_canvas_transform().affine_inverse() * Rect2(Vector2.ZERO, vp.get_visible_rect().size)
