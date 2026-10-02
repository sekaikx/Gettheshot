class_name Ground3D
extends Node3D
## Everything at street level in 3D: asphalt and Belgian-block streets with markings and tram tracks,
## crossings, sidewalks and kerbs, courtyards and backyards, the plank quay, the river, the piers, and
## the street props (lamps, hydrants, trees, benches, bins, pushcarts, laundry lines...).
## The layout is the same GroundLayout / GroundQuay / GroundYards data the 2D art and the collision use,
## so what you see matches what blocks you. The pieces live in scripts/world3d/ground/ (g3_*.gd).
##
##   build(plan)                 once
##   set_night(night, wet)       lamp heads glow, light pools show, wet streets shine, river reflects lamps
##   lamp_points: Array          Vector3 positions (lamp heads) View3D uses for its pooled real lights

var plan: CityPlan
var lamp_points: Array = []

var mats: G3Mats
var layout: GroundLayout
var _night := 0.0
var _wet := 0.0


func build(p: CityPlan) -> void:
	plan = p
	for c in get_children():
		c.queue_free()
	lamp_points.clear()
	var prof := OS.get_environment("GROUND_PROFILE") == "1"
	var t := Time.get_ticks_msec()
	mats = G3Mats.new()
	var bundle := G3Bundle.new(mats)
	if prof:
		print("  ground: textures+materials ", Time.get_ticks_msec() - t)
		t = Time.get_ticks_msec()
	layout = GroundLayout.new()
	layout.build(p)
	if prof:
		print("  ground: layout ", Time.get_ticks_msec() - t)
		t = Time.get_ticks_msec()
	var streets := G3Streets.new(layout, bundle)
	streets.build()
	if prof:
		print("  ground: streets ", Time.get_ticks_msec() - t)
		t = Time.get_ticks_msec()
	var blocks := G3Blocks.new(layout, bundle)
	blocks.build()
	if prof:
		print("  ground: blocks ", Time.get_ticks_msec() - t)
		t = Time.get_ticks_msec()
	var yards := G3Yards.new(layout, bundle)
	yards.build()
	if prof:
		print("  ground: yards ", Time.get_ticks_msec() - t)
		t = Time.get_ticks_msec()
	var quay := G3Quay.new(layout, bundle)
	quay.build()
	if prof:
		print("  ground: quay ", Time.get_ticks_msec() - t)
		t = Time.get_ticks_msec()
	var root := Node3D.new()
	root.name = "Cells"
	add_child(root)
	bundle.flush(root)
	if prof:
		print("  ground: flush ", Time.get_ticks_msec() - t)
	lamp_points = blocks.lamp_points.duplicate()
	lamp_points.append_array(quay.lamp_points)
	_far_ground()
	_river(quay.water_lamps)
	_steam()
	_labels(blocks.labels)
	mats.apply(_night, _wet)


## Dark rubble beyond the drawn streets so the camera never sees the void at the map edge.
func _far_ground() -> void:
	var m := G3Mesh.new()
	var a := layout.area.grow(160.0)
	m.flat(a.position.x, a.position.y, plan.water_x + 0.3, a.end.y, -0.03, Color(0.2, 0.2, 0.21))
	var mi := m.instance("FarGround", mats.material("stone"), false)
	add_child(mi)


func _river(lamps: Array) -> void:
	var a := layout.area
	var m := G3Mesh.new()
	m.flat(plan.water_x - 0.05, a.position.y - 160.0, a.end.x + 220.0, a.end.y + 160.0, G3Quay.WATER_Y, Color.WHITE)
	var mi := m.instance("River", mats.water, false)
	add_child(mi)
	mats.water.set_shader_parameter("edge_x", plan.water_x)
	var arr := PackedVector3Array()
	arr.resize(16)
	var n := mini(lamps.size(), 16)
	for k in n:
		arr[k] = lamps[k]
	mats.water.set_shader_parameter("lamps", arr)
	mats.water.set_shader_parameter("lamp_count", n)


## Puffs of steam from the manholes that vent (three staggered puffs each).
func _steam() -> void:
	if layout.vents.is_empty():
		return
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = quad
	mm.instance_count = layout.vents.size() * 3
	var i := 0
	for v in layout.vents:
		var pm: Vector2 = (v as Vector2) / W.M
		for k in 3:
			var seed_v := Draw.hash01(int(pm.x * 3.0), int(pm.y * 3.0), k + 5)
			mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(pm.x, 0.02, pm.y)))
			mm.set_instance_custom_data(i, Color(float(k) / 3.0 + seed_v * 0.1, seed_v, 0, 0))
			i += 1
	mm.custom_aabb = AABB(Vector3(layout.area.position.x, 0, layout.area.position.y), Vector3(layout.area.size.x, 8, layout.area.size.y))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Steam"
	mmi.multimesh = mm
	mmi.material_override = mats.steam
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


func _labels(list: Array) -> void:
	var root := Node3D.new()
	root.name = "StreetSigns"
	add_child(root)
	for l in list:
		var lb := Label3D.new()
		lb.text = String(l[0])
		lb.font_size = 56
		lb.pixel_size = 0.0034
		lb.outline_size = 0
		lb.modulate = Color("f0ead8")
		lb.shaded = false
		lb.double_sided = false
		lb.position = l[1]
		lb.rotation.y = float(l[2])
		lb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(lb)


func set_night(night: float, wet: float) -> void:
	_night = night
	_wet = wet
	if mats:
		mats.apply(night, wet)
