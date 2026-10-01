class_name Item3D
extends Node3D
## A crate or a bundle of cash on the ground (the 3D look of a Crate). View3D makes one per item.

var kind := "crate"
var _t := 0.0
var _cash: Node3D


func setup(k: String, amount: int, seed_value: int) -> void:
	kind = k
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	if kind == "crate":
		bm.size = Vector3(0.62, 0.45, 0.5)
		mi.material_override = V3.mat(Color("8a6a44"), 0.9)
		mi.position.y = 0.225
		var lab := Label3D.new()
		lab.text = "XXX"
		lab.font_size = 36
		lab.pixel_size = 0.004
		lab.modulate = Color("2a1c10")
		lab.rotation.x = -PI * 0.5
		lab.position = Vector3(0, 0.455, 0)
		add_child(lab)
	else:
		bm.size = Vector3(0.22, 0.08, 0.12)
		mi.material_override = V3.glow(Color("5e8a4e"), 0.4)
		mi.position.y = 0.05
		var l := Label3D.new()
		l.text = "$%d" % amount
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.font_size = 40
		l.pixel_size = 0.006
		l.outline_size = 10
		l.modulate = Color("b8e0a0")
		l.position.y = 0.6
		add_child(l)
		_cash = mi
	mi.mesh = bm
	add_child(mi)
	rotation.y = (W.rng(seed_value).randf() - 0.5) * 0.6


func _process(delta: float) -> void:
	if _cash:
		_t += delta
		_cash.position.y = 0.08 + sin(_t * 3.0) * 0.03
