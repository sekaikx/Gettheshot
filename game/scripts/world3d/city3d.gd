class_name City3D
extends Node3D
## The city in 3D: Ground3D (streets, sidewalks, quay, river, props) + Buildings3D. Thin orchestrator,
## View3D talks only to this class.

var plan: CityPlan
var ground: Ground3D
var buildings: Buildings3D


func build(p: CityPlan) -> void:
	plan = p
	ground = Ground3D.new()
	ground.name = "Ground"
	add_child(ground)
	ground.build(plan)
	buildings = Buildings3D.new()
	buildings.name = "Buildings"
	add_child(buildings)
	buildings.build(plan)


func set_night(night: float, wet: float) -> void:
	ground.set_night(night, wet)
	buildings.set_night(night, wet)


func set_inside(lot_id: int) -> void:
	buildings.set_inside(lot_id)


func update_owners() -> void:
	buildings.update_owners()


func lot_height(lot_id: int) -> float:
	return buildings.lot_height(lot_id)


## Positions of lamps and shop lights for View3D's pooled real lights.
func light_points() -> Array:
	return ground.lamp_points + buildings.light_points
