class_name Interiors3D
extends Node3D
## The inside of every business in 3D: floor, walls, doors, counters, shelves, tables, the owner's
## trade goods, broken glass, the speakeasy in the back, the club's office. Built from the same layout
## data as the 2D rooms (Interiors.build(...) -> InteriorArt.layouts, see scripts/world2d/interiors.gd).
## THIS IS A PLACEHOLDER: the interiors builder replaces it, keeping this interface.
##
## Interface (View3D calls these):
##   build(layouts: Dictionary)       lot id -> layout dict (pixels, see Interiors); builds every room
##   update_from_game()               redo what changed: broken items, speakeasy, padlocked, stock
##   set_night(night, wet)            bulbs and window glow
##   set_inside(lot_id)               the local player's building (-1 = none): rooms are always built
##                                    but the City3D hides the roof/front wall over it

var layouts := {}


func build(p_layouts: Dictionary) -> void:
	layouts = p_layouts
	for id in layouts:
		var lay: Dictionary = layouts[id]
		var fl := MeshInstance3D.new()
		var bm := BoxMesh.new()
		var r := V3.rect_m(lay["rect"])
		bm.size = Vector3(r.size.x - 0.4, 0.05, r.size.y - 0.4)
		fl.mesh = bm
		fl.position = Vector3(r.get_center().x, 0.03, r.get_center().y)
		fl.material_override = V3.mat(Color("9b7d57"), 0.8)
		add_child(fl)
		for it in lay.get("items", []):
			var ir := V3.rect_m(it["rect"])
			var b := MeshInstance3D.new()
			var im := BoxMesh.new()
			im.size = Vector3(ir.size.x, 0.9, ir.size.y)
			b.mesh = im
			b.position = Vector3(ir.get_center().x, 0.45, ir.get_center().y)
			b.material_override = V3.mat(Color("6a4a30"), 0.85)
			add_child(b)


func update_from_game() -> void:
	pass


func set_night(_night: float, _wet: float) -> void:
	pass


func set_inside(_lot_id: int) -> void:
	pass
