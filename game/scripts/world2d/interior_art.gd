class_name InteriorArt
extends Node2D
## Draws the inside of every business: floors, walls, doors, counters, shelves, the owner's
## trade goods, broken glass, the speakeasy in the back room, the club's office. Hidden under the
## roofs until the local player walks in (the roof fades). Lives on the world canvas.
## STUB: the real art replaces this; the API is the contract (docs/REBUILD_2D.md, "InteriorArt").

var plan: CityPlan
var layouts := {}        # lot id -> Interiors.layout(...)
var night := 0.0


func build(p: CityPlan) -> void:
	plan = p
	z_index = W.Z_FLOOR
	for b in Game.biz:
		var lot: Dictionary = plan.lots[int(b["lot"])]
		layouts[int(lot["id"])] = Interiors.layout(lot, String(b["kind"]))
	queue_redraw()


func layout_of(lot_id: int) -> Dictionary:
	return layouts.get(lot_id, {})


## Re-read Game.biz: broken items ("broken": [item ids]), speakeasy in the back ("speak"), padlocked
## by the feds ("closed_until" >= Game.month), stock in the cellar ("stock").
func update_from_game() -> void:
	queue_redraw()


func set_night(n: float, _wet: float) -> void:
	night = n


## Lamps inside (same format as CityGround.lights()).
func lights() -> Array:
	var out := []
	for id in layouts:
		out.append({"pos": (layouts[id]["rect"] as Rect2).get_center(), "r": 4.0 * W.M, "color": Pal.WINDOW_WARM, "e": 0.8, "shape": "round"})
	return out


func _draw() -> void:
	for id in layouts:
		var lay: Dictionary = layouts[id]
		draw_rect(lay["rect"], Pal.FLOOR_WOOD)
		for it in lay["items"]:
			draw_rect(it["rect"], Pal.COUNTER if not it["breakable"] else Pal.GLASS)
		for wseg in lay["walls"]:
			draw_line(wseg[0], wseg[1], Pal.BRICK_DARK, W.WALL * W.M)
