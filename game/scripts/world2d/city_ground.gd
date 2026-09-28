class_name CityGround
extends Node2D
## The ground of the 2D city: streets, crossings, sidewalks and curbs, street furniture (lamps,
## hydrants, mailboxes, benches, newsstands, ash cans, pushcarts...), the backyards inside the
## blocks, the quay, the piers and the river. STUB: the real art replaces this; the API is the
## contract (docs/REBUILD_2D.md, "CityGround"). Lives on the world canvas (lit by the light layer).

var plan: CityPlan
var night := 0.0
var wet := 0.0
var _lights: Array = []
var _solids: Array = []


func build(p: CityPlan) -> void:
	plan = p
	z_index = W.Z_GROUND
	queue_redraw()
	# lamps at every block corner (placeholder)
	for b in plan.blocks:
		var r: Array = b["rect"]
		for c in [Vector2(r[0], r[1]), Vector2(r[2], r[1]), Vector2(r[2], r[3]), Vector2(r[0], r[3])]:
			_lights.append({"pos": c * W.M, "r": 7.0 * W.M, "color": Pal.LAMP, "e": 1.0, "shape": "round"})


func set_night(n: float, w: float) -> void:
	night = n
	wet = w


## Street lamps and other light sources on the ground: [{pos: Vector2 px, r: radius px, color,
## e: energy 0..1.5, shape: "round"|"rect"|"cone", size: Vector2 (rect), rot: float (cone),
## flicker: bool}]. Constant for the life of the node.
func lights() -> Array:
	return _lights


## Rectangles (px) that block people and cars: newsstands, pushcarts, crate stacks, bollards...
## (not buildings: the World adds those).
func solids() -> Array:
	return _solids


func _draw() -> void:
	if plan == null:
		return
	var b := plan.bounds
	draw_rect(Rect2(b.position * W.M, b.size * W.M), Pal.ASPHALT)
	var water := Rect2(Vector2(plan.water_x, b.position.y) * W.M, Vector2(b.end.x - plan.water_x, b.size.y) * W.M)
	draw_rect(water, Pal.WATER)
	var q: Array = plan.quay_rect
	draw_rect(Rect2(Vector2(q[0], q[1]) * W.M, Vector2(q[2] - q[0], q[3] - q[1]) * W.M), Pal.PLANKS)
	for pier in plan.piers:
		draw_rect(Rect2(Vector2(pier["x0"], pier["z0"]) * W.M, Vector2(pier["x1"] - pier["x0"], pier["z1"] - pier["z0"]) * W.M), Pal.PLANKS_DARK)
	for blk in plan.blocks:
		var r: Array = blk["rect"]
		draw_rect(Rect2(Vector2(r[0], r[1]) * W.M, Vector2(r[2] - r[0], r[3] - r[1]) * W.M), Pal.SIDEWALK)
