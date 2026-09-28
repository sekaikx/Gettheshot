extends Control
## Don's View (M, or the map table in your club): the whole city from above.
## STUB: the Don's View piece replaces this (docs/REBUILD_2D.md, "Don's View").

var hud: Node
var world: Node


func open() -> void:
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.045, 0.04, 0.93))
	var plan: CityPlan = Game.plan
	if plan == null:
		return
	var b := plan.bounds
	var sc := minf(size.x / b.size.x, size.y / b.size.y) * 0.9
	var off := size * 0.5 - b.get_center() * sc
	for blk in plan.blocks:
		var r: Array = blk["rect"]
		draw_rect(Rect2(Vector2(r[0], r[1]) * sc + off, Vector2(r[2] - r[0], r[3] - r[1]) * sc), Color("2a2622"))
	for bz in Game.biz:
		var owner: int = bz["owned_by"] if int(bz["owned_by"]) >= 0 else int(bz["protector"])
		var col := W.fam_color(owner) if owner >= 0 else Color("5e5850")
		draw_circle(Vector2(bz["door"][0], bz["door"][1]) * sc + off, 4.0, col)
	if world and world.local_actor:
		draw_circle(W.to_m(world.local_actor.position) * sc + off, 6.0, Color.WHITE)


func _process(_d: float) -> void:
	if visible:
		queue_redraw()
