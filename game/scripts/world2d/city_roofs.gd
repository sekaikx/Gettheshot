class_name CityRoofs
extends Node2D
## Every building's roof seen from above, with its drop shadow on the street: tar roofs,
## parapets, chimneys, water towers, skylights, hatches, laundry lines between buildings.
## Lives on its own canvas layer (W.LAYER_ROOFS) above the light layer, so street lamps don't
## light the roofs; night darkens it through set_night(). STUB: the real art replaces this; the
## API is the contract (docs/REBUILD_2D.md, "CityRoofs").

var plan: CityPlan
var night := 0.0
var _inside := -1
var _fade := {}          # lot id -> alpha (1 = solid roof)


func build(p: CityPlan) -> void:
	plan = p
	queue_redraw()


func update_owners() -> void:
	queue_redraw()


func set_night(n: float, _wet: float) -> void:
	if absf(n - night) > 0.02:
		night = n
		modulate = Color(1, 1, 1).lerp(Color(0.32, 0.34, 0.5), night)


## The local player walked into lot `lot_id` (-1 = back outside): fade that roof out so the
## interior shows, and back in when they leave.
func set_inside(lot_id: int) -> void:
	if lot_id != _inside:
		_inside = lot_id
		queue_redraw()


func _draw() -> void:
	if plan == null:
		return
	for lot in plan.lots:
		var r := W.lot_rect(lot)
		var a := 0.1 if int(lot["id"]) == _inside else 1.0
		if lot["kind"] == "courtyard":
			continue
		draw_rect(Rect2(r.position + Vector2(8, 10) * float(lot["floors"]) * 0.5, r.size), Color(0, 0, 0, 0.3 * a))
		draw_rect(r, Color(Pal.TAR, a))
		draw_rect(r, Color(Pal.PARAPET_BRICK, a), false, 4.0)
