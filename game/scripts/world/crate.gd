class_name Crate
extends Node3D
## A crate of bootleg whisky on the ground (or a bundle of dropped cash). Picked up with E.

static var _mat: StandardMaterial3D
static var _cash_mat: StandardMaterial3D

var item_id := 0
var kind := "crate"
var amount := 0


static func material() -> StandardMaterial3D:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.albedo_texture = load("res://assets/textures/planks_albedo.jpg")
		_mat.albedo_color = Color(0.85, 0.7, 0.5)
		_mat.uv1_scale = Vector3(0.6, 0.6, 0.6)
		_mat.roughness = 0.9
	return _mat


func setup(id: int, k: String, amt: int) -> void:
	item_id = id
	kind = k
	amount = amt
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	if kind == "crate":
		bm.size = Vector3(0.62, 0.45, 0.5)
		mi.material_override = material()
		mi.position.y = 0.225
	else:
		bm.size = Vector3(0.22, 0.08, 0.12)
		if _cash_mat == null:
			_cash_mat = StandardMaterial3D.new()
			_cash_mat.albedo_color = Color("5e8a4e")
			_cash_mat.emission_enabled = true
			_cash_mat.emission = Color("2a4a20")
		mi.material_override = _cash_mat
		mi.position.y = 0.05
	mi.mesh = bm
	add_child(mi)
	if kind == "cash":
		var l := Label3D.new()
		l.text = "$%d" % amount
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.font_size = 40
		l.outline_size = 10
		l.modulate = Color("b8e0a0")
		l.position.y = 0.6
		add_child(l)
