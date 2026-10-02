class_name Buildings3D
extends Node3D
## Every building of the city in 3D: facade, windows, shopfront (glass, door, awning, sign, family colour),
## cornice, roof with its clutter (tanks, chimneys, antennas). Built from CityPlan lots plus Game.biz.
## Read scripts/world2d/shopfronts.gd, fronts/*, city_roofs.gd for what each building looks like.
## PLACEHOLDER: the buildings builder replaces it, keeping this interface.
##
##   build(plan)                 once
##   set_night(night, wet)       lit windows, shop lights, neon
##   set_inside(lot_id)          the local player is inside lot (-1 = outside): hide its roof, upper floors
##                               and the front wall so the camera can see in (keep the sidewalk side readable)
##   update_owners()             a shop changed hands / padlocked / speakeasy: redo awnings, signs, colours
##   lot_height(lot_id) -> float
##   light_points: Array         Vector3 positions of shop/door lights View3D uses for its pooled real lights

var plan: CityPlan
var light_points: Array = []
var _lots := {}
var _heights := {}
var _inside := -1


func build(p: CityPlan) -> void:
	plan = p
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
