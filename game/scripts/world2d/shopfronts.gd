class_name Shopfronts
extends Node2D
## The street face of every business: awnings over the sidewalk (striped in the colour of the
## family the shop pays), the painted sign with the shop's name, the display windows, and the
## trade's clutter on the sidewalk (fruit stands, a barber pole, café tables, fish on ice, the
## pawnbroker's three balls...). Lives on the world canvas, above people (W.Z_AWNING for awnings).
## STUB: the real art replaces this; the API is the contract (docs/REBUILD_2D.md, "Shopfronts").

var plan: CityPlan
var night := 0.0


func build(p: CityPlan) -> void:
	plan = p
	z_index = W.Z_AWNING
	queue_redraw()


## Re-read Game.biz: who protects / owns each shop (awning colour), closed shops (shutters down).
func update_owners() -> void:
	queue_redraw()


func set_night(n: float, _wet: float) -> void:
	night = n


## Light from shop windows onto the sidewalk at night, lit signs: same format as CityGround.lights().
func lights() -> Array:
	var out := []
	for b in Game.biz:
		out.append({"pos": W.door(b), "r": 3.0 * W.M, "color": Pal.WINDOW_WARM, "e": 0.7, "shape": "round"})
	return out


## Rectangles (px) that block walking: sidewalk displays, café tables, barber poles...
func solids() -> Array:
	return []


func _draw() -> void:
	if plan == null:
		return
	for b in Game.biz:
		var lot: Dictionary = plan.lots[int(b["lot"])]
		var r := W.lot_rect(lot)
		var f := W.front_dir(float(lot["yaw"]))
		var col := W.fam_color(int(b["owned_by"]) if int(b["owned_by"]) >= 0 else int(b["protector"]))
		if col.a <= 0.0:
			col = Pal.AWNING_CREAM
		# a strip along the front edge, 1.5 m deep
		var front := r.get_center() + f * (r.size * 0.5).dot(f.abs())
		var along := Vector2(absf(f.y), absf(f.x)) * (r.size.dot(Vector2(absf(f.y), absf(f.x))) - 0.8 * W.M)
		var depth := f * 1.5 * W.M
		var pts := PackedVector2Array([front - along * 0.5, front + along * 0.5, front + along * 0.5 + depth, front - along * 0.5 + depth])
		Draw.poly(self, pts, col.darkened(0.2))
