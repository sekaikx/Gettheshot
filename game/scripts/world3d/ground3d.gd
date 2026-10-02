class_name Ground3D
extends Node3D
## Everything at street level in 3D: asphalt and cobbles, tram tracks, crossings, sidewalks and kerbs,
## courtyards, backyards, the quay, the river, the piers, and street props (lamps, hydrants, trees,
## benches, bins, barrels, pushcarts, laundry lines...). Read the 2D art in scripts/world2d/ground/* and
## scripts/world2d/city_ground.gd for what the street should contain.
## PLACEHOLDER: the ground builder replaces it, keeping this interface.
##
##   build(plan)                 once
##   set_night(night, wet)       lamps glow, wet streets shine
##   lamp_points: Array          Vector3 positions (lamp heads) View3D uses for its pooled real lights

var plan: CityPlan
var lamp_points: Array = []


func build(p: CityPlan) -> void:
	plan = p
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	var pm := PlaneMesh.new()
	pm.size = Vector2(plan.bounds.size.x + 200.0, plan.bounds.size.y + 200.0)
	ground.mesh = pm
	ground.position = Vector3(plan.bounds.get_center().x, -0.02, plan.bounds.get_center().y)
	ground.material_override = V3.mat(Color("3a3d42"), 0.95)
	add_child(ground)
	for blk in plan.blocks:
		var r: Array = blk["rect"]
		var m := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(float(r[2]) - float(r[0]), 0.16, float(r[3]) - float(r[1]))
		m.mesh = bm
		m.position = Vector3((float(r[0]) + float(r[2])) * 0.5, 0.06, (float(r[1]) + float(r[3])) * 0.5)
		m.material_override = V3.mat(Color("8d8a82"), 0.9)
		add_child(m)


func set_night(_night: float, _wet: float) -> void:
	pass
