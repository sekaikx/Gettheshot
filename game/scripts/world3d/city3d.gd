class_name City3D
extends Node3D
## The streets and buildings of Lower Manhattan in 3D, built from the CityPlan: ground, sidewalks,
## quay and river, every building (facade, shopfront, awning, sign, roof), street props, lamps.
## THIS IS A PLACEHOLDER (flat colours): the city builder replaces it, keeping this interface.
##
## Interface (View3D calls these):
##   build(plan)                 once, builds everything
##   set_night(night, wet)       0..1 each: lamps and lit windows come on, wet streets shine
##   set_inside(lot_id)          the local player went into a building (-1 = outside): hide its roof,
##                               upper floors and the front wall so the camera sees in
##   update_owners()             a shop changed hands / got padlocked / opened a speakeasy: redo signs,
##                               awnings, family colours, windows
##   lot_height(lot_id) -> float metres

var plan: CityPlan
var _lots := {}          # lot id -> Node3D (the whole building)
var _heights := {}
var _inside := -1


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
		m.position = Vector3((float(r[0]) + float(r[2])) * 0.5, 0.08 - 0.02, (float(r[1]) + float(r[3])) * 0.5)
		m.material_override = V3.mat(Color("8d8a82"), 0.9)
		add_child(m)
	for lot in plan.lots:
		if lot["kind"] == "courtyard":
			continue
		var id := int(lot["id"])
		var h := V3.lot_height(lot)
		_heights[id] = h
		var rm := V3.rect_m(W.lot_rect(lot))
		var n := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(rm.size.x, h, rm.size.y)
		n.mesh = bm
		n.position = Vector3(rm.get_center().x, h * 0.5, rm.get_center().y)
		var tint := Color("7a4a3a").lerp(Color("a88a6a"), V3.hash01(rm.position.x, rm.position.y))
		n.material_override = V3.mat(tint, 0.9)
		add_child(n)
		_lots[id] = n


func set_night(_night: float, _wet: float) -> void:
	pass


func set_inside(lot_id: int) -> void:
	if _lots.has(_inside):
		(_lots[_inside] as Node3D).visible = true
	_inside = lot_id
	if _lots.has(lot_id):
		(_lots[lot_id] as Node3D).visible = false


func update_owners() -> void:
	pass


func lot_height(lot_id: int) -> float:
	return float(_heights.get(lot_id, 6.0))
