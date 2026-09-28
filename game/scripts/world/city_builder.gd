class_name CityBuilder
extends Node3D
## Builds the city you walk in from the CityPlan: asphalt streets, pavements, brick and plaster
## tenements (facade shader), shop fronts with awnings and signs, street lamps, the waterfront
## (quay, piers, warehouses, the river) and a ring of buildings that closes the map.

const LAMP := "res://assets/kenney/roads/light-curved.glb"
const HYDRANT_COLOR := Color("7a2a20")

var plan: CityPlan
var facade_mat: ShaderMaterial
var awning_mat: ShaderMaterial
var water_mat: ShaderMaterial
var asphalt_mat: StandardMaterial3D
var pave_mat: StandardMaterial3D
var awnings := {}     # biz id -> MeshInstance3D
var signs := {}       # biz id -> Label3D
var lamps: Array[OmniLight3D] = []
var lamp_heads: Array[MeshInstance3D] = []
var _unit_box: BoxMesh
var _lamp_head_mat: StandardMaterial3D
var _rng := RandomNumberGenerator.new()


func build(p: CityPlan) -> void:
	plan = p
	_rng.seed = p.seed_value + 5
	_unit_box = BoxMesh.new()
	_make_materials()
	_ground()
	for b in plan.blocks:
		_sidewalk(b)
	for lot in plan.lots:
		_building(lot)
	for b in Game.biz:
		_storefront(b)
	_lamps()
	_waterfront()
	_backdrop()
	_street_props()


func _tex(name: String) -> Texture2D:
	return load("res://assets/textures/%s.jpg" % name) as Texture2D


func _make_materials() -> void:
	facade_mat = ShaderMaterial.new()
	facade_mat.shader = preload("res://scripts/world/facade.gdshader")
	facade_mat.set_shader_parameter("brick_tex", _tex("brick_albedo"))
	facade_mat.set_shader_parameter("plaster_tex", _tex("plaster_albedo"))
	facade_mat.set_shader_parameter("roof_tex", _tex("concrete_wall_albedo"))
	facade_mat.set_shader_parameter("metal_tex", _tex("corrugated_albedo"))
	awning_mat = ShaderMaterial.new()
	awning_mat.shader = preload("res://scripts/world/awning.gdshader")
	water_mat = ShaderMaterial.new()
	water_mat.shader = preload("res://scripts/world/water.gdshader")
	asphalt_mat = StandardMaterial3D.new()
	asphalt_mat.albedo_texture = _tex("asphalt_albedo")
	asphalt_mat.normal_enabled = true
	asphalt_mat.normal_texture = _tex("asphalt_normal")
	asphalt_mat.roughness_texture = _tex("asphalt_rough")
	asphalt_mat.albedo_color = Color(0.55, 0.53, 0.5)
	asphalt_mat.uv1_triplanar = true
	asphalt_mat.uv1_world_triplanar = true
	asphalt_mat.uv1_scale = Vector3(0.18, 0.18, 0.18)
	pave_mat = StandardMaterial3D.new()
	pave_mat.albedo_texture = _tex("pavement_albedo")
	pave_mat.normal_enabled = true
	pave_mat.normal_texture = _tex("pavement_normal")
	pave_mat.albedo_color = Color(0.72, 0.7, 0.66)
	pave_mat.uv1_triplanar = true
	pave_mat.uv1_world_triplanar = true
	pave_mat.uv1_scale = Vector3(0.3, 0.3, 0.3)
	_lamp_head_mat = StandardMaterial3D.new()
	_lamp_head_mat.albedo_color = Color("ffd9a0")
	_lamp_head_mat.emission_enabled = true
	_lamp_head_mat.emission = Color("ffc070")
	_lamp_head_mat.emission_energy_multiplier = 2.0


func set_night(v: float, wet: float) -> void:
	facade_mat.set_shader_parameter("night", v)
	facade_mat.set_shader_parameter("wet", wet)
	for aw in awnings.values():
		((aw as MeshInstance3D).material_override as ShaderMaterial).set_shader_parameter("night", v)
	water_mat.set_shader_parameter("night", v)
	asphalt_mat.roughness = lerpf(1.0, 0.25, wet)
	asphalt_mat.albedo_color = Color(0.55, 0.53, 0.5).darkened(wet * 0.35)
	pave_mat.albedo_color = Color(0.72, 0.7, 0.66).darkened(wet * 0.3)
	var on := clampf((v - 0.25) / 0.4, 0.0, 1.0)
	for l in lamps:
		l.light_energy = on * 3.2
		l.visible = on > 0.01
	_lamp_head_mat.emission_energy_multiplier = 0.2 + on * 3.0


# ------------------------------------------------------------------ pieces

func _box(size: Vector3, pos: Vector3, mat: Material, yaw: float = 0.0, collide: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation.y = yaw
	add_child(mi)
	if collide:
		_collider(size, pos, yaw)
	return mi


func _collider(size: Vector3, pos: Vector3, yaw: float) -> void:
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	sb.add_child(cs)
	sb.position = pos
	sb.rotation.y = yaw
	add_child(sb)


func _ground() -> void:
	var r := plan.bounds
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(plan.water_x - r.position.x, r.size.y)
	mi.mesh = pm
	mi.material_override = asphalt_mat
	mi.position = Vector3((r.position.x + plan.water_x) * 0.5, 0.0, r.position.y + r.size.y * 0.5)
	add_child(mi)
	# faded lane lines down the middle of every street
	var line_mat := StandardMaterial3D.new()
	line_mat.albedo_color = Color(0.62, 0.58, 0.48, 0.55)
	line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	line_mat.roughness = 0.9
	for i in CityPlan.NX + 1:
		var x := i * CityPlan.PITCH
		for j in CityPlan.NZ:
			var z0 := j * CityPlan.PITCH + CityPlan.STREET * 0.5
			var z1 := (j + 1) * CityPlan.PITCH - CityPlan.STREET * 0.5
			var z := z0 + 1.5
			while z < z1 - 1.5:
				_box(Vector3(0.14, 0.01, 1.6), Vector3(x, 0.006, z + 0.8), line_mat)
				z += 3.6
	for j in CityPlan.NZ + 1:
		var z := j * CityPlan.PITCH
		for i in CityPlan.NX:
			var x0 := i * CityPlan.PITCH + CityPlan.STREET * 0.5
			var x1 := (i + 1) * CityPlan.PITCH - CityPlan.STREET * 0.5
			var x := x0 + 1.5
			while x < x1 - 1.5:
				_box(Vector3(1.6, 0.01, 0.14), Vector3(x + 0.8, 0.006, z), line_mat)
				x += 3.6


func _sidewalk(b: Dictionary) -> void:
	var r: Array = b["rect"]
	var size := Vector3(r[2] - r[0], 0.16, r[3] - r[1])
	var pos := Vector3((r[0] + r[2]) * 0.5, 0.08, (r[1] + r[3]) * 0.5)
	_box(size, pos, pave_mat)
	# the kerb
	var kerb := StandardMaterial3D.new()
	kerb.albedo_color = Color(0.5, 0.49, 0.46)
	var k := _box(size + Vector3(0.3, -0.04, 0.3), pos - Vector3(0, 0.02, 0), kerb)
	k.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _building(lot: Dictionary) -> void:
	var kind: String = lot["kind"]
	var w: float = lot["size"][0]
	var d: float = lot["size"][1]
	var floors: int = lot["floors"]
	var h := 4.2 + floors * 3.2 + 0.9
	var style := float(lot["style"])
	if kind == "courtyard":
		h = 4.5
		style = 4.0
	elif kind == "warehouse":
		h = 9.0
		style = 3.0
	elif style > 2.5:
		style = float(_rng.randi_range(0, 2))
	var pos := Vector3(lot["center"][0], h * 0.5, lot["center"][1])
	var yaw: float = lot["yaw"]
	var tints := [Color(0.95, 0.78, 0.68), Color(0.82, 0.62, 0.5), Color(1.0, 0.95, 0.88), Color(0.72, 0.6, 0.55),
		Color(0.9, 0.86, 0.8), Color(0.66, 0.5, 0.42)]
	var mi := _facade(Vector3(w - 0.08, h, d), tints[_rng.randi_range(0, tints.size() - 1)], style,
		float(lot["id"]) * 0.37, lot["shop"] and kind != "tenement")
	mi.position = pos
	mi.rotation.y = yaw
	_collider(Vector3(w, h, d), pos, yaw)
	if kind in ["courtyard", "warehouse"]:
		return
	# rooftops: water towers, bulkheads, chimneys
	var top := h
	var basis := Basis(Vector3.UP, yaw)
	if floors >= 4 and _rng.randf() < 0.35:
		_water_tower(pos + basis * Vector3(_rng.randf_range(-w * 0.2, w * 0.2), 0, _rng.randf_range(-d * 0.2, d * 0.1)) + Vector3(0, top * 0.5, 0))
	if _rng.randf() < 0.5:
		var bulk := StandardMaterial3D.new()
		bulk.albedo_color = Color(0.36, 0.32, 0.3)
		_box(Vector3(2.2, 2.0, 2.2), Vector3(pos.x, top + 1.0, pos.z) + basis * Vector3(w * 0.25, 0, -d * 0.25), bulk, yaw)
	for c in _rng.randi_range(0, 2):
		var ch := StandardMaterial3D.new()
		ch.albedo_color = Color(0.4, 0.26, 0.2)
		_box(Vector3(0.7, 1.4, 0.7), Vector3(pos.x, top + 0.7, pos.z) + basis * Vector3(_rng.randf_range(-w * 0.4, w * 0.4), 0, -d * 0.4), ch, yaw)
	# fire escape on some fronts
	if floors >= 3 and not lot["shop"] and _rng.randf() < 0.5:
		var fe := StandardMaterial3D.new()
		fe.albedo_color = Color(0.12, 0.12, 0.12)
		fe.metallic = 0.6
		var front := basis * Vector3(0, 0, d * 0.5 + 0.5)
		for f in floors:
			var y := 4.2 + f * 3.2 + 0.3
			_box(Vector3(w * 0.45, 0.08, 1.0), Vector3(pos.x, y, pos.z) + front, fe, yaw)


## One building box with its look baked into the vertices (see facade.gdshader). The mesh is
## centred like a BoxMesh; `size` is in metres.
func _facade(size: Vector3, tint: Color, style: float, seed: float, shop: bool) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	var arr := bm.get_mesh_arrays()
	var n: int = (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var cols := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	cols.resize(n)
	uv.resize(n)
	uv2.resize(n)
	var c := Color(tint.r, tint.g, tint.b, style / 8.0)
	var u := Vector2(seed + (1000.0 if shop else 0.0), size.y)
	var u2 := Vector2(size.x, size.z)
	for k in n:
		cols[k] = c
		uv[k] = u
		uv2[k] = u2
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_TEX_UV2] = uv2
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.mesh = am
	mi.material_override = facade_mat
	add_child(mi)
	return mi


func _darken(n: Node, c: Color) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = 0.5
	m.roughness = 0.5
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = m


func _water_tower(at: Vector3) -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_texture = _tex("planks_albedo")
	wood.albedo_color = Color(0.6, 0.45, 0.32)
	var legs := StandardMaterial3D.new()
	legs.albedo_color = Color(0.15, 0.14, 0.13)
	for k in 4:
		var o := Vector3(cos(k * PI * 0.5 + PI * 0.25), 0, sin(k * PI * 0.5 + PI * 0.25)) * 1.0
		_box(Vector3(0.18, 2.4, 0.18), at + o + Vector3(0, 1.2, 0), legs)
	var tank := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.45
	cm.bottom_radius = 1.5
	cm.height = 3.0
	tank.mesh = cm
	tank.material_override = wood
	tank.position = at + Vector3(0, 3.9, 0)
	add_child(tank)
	var roof := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.05
	cone.bottom_radius = 1.6
	cone.height = 1.1
	roof.mesh = cone
	roof.material_override = legs
	roof.position = at + Vector3(0, 5.95, 0)
	add_child(roof)


func _storefront(b: Dictionary) -> void:
	var lot: Dictionary = plan.lots[b["lot"]]
	var yaw: float = lot["yaw"]
	var basis := Basis(Vector3.UP, yaw)
	var c := Vector3(lot["center"][0], 0, lot["center"][1])
	var w: float = lot["size"][0]
	var d: float = lot["size"][1]
	var front := c + basis * Vector3(0, 0, d * 0.5)
	if b["kind"] not in ["precinct", "warehouse"]:
		var aw := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(w - 1.2, 0.08, 1.0)
		aw.mesh = bm
		aw.material_override = awning_mat.duplicate()
		aw.position = front + basis * Vector3(0, 3.7, 0.45)
		aw.rotation = Vector3(0, yaw, 0)
		aw.rotate_object_local(Vector3.RIGHT, 0.32)
		add_child(aw)
		awnings[b["id"]] = aw
	var l := Label3D.new()
	l.text = b["name"]
	l.font_size = 44
	l.pixel_size = 0.01
	l.outline_size = 12
	l.modulate = Color("f1e3c2")
	l.outline_modulate = Color(0.05, 0.03, 0.02, 0.9)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = front + basis * Vector3(0, 4.6, 0.3)
	l.visibility_range_end = 42.0
	l.no_depth_test = false
	if b["kind"] == "precinct":
		l.text = "POLICE · 14th PRECINCT"
		l.modulate = Color("a8c8ff")
		for s in [-1.0, 1.0]:
			var g := OmniLight3D.new()
			g.light_color = Color("60ff90")
			g.omni_range = 5.0
			g.light_energy = 1.5
			g.position = front + basis * Vector3(s * 1.4, 2.6, 0.4)
			add_child(g)
			var bulb := _box(Vector3(0.3, 0.3, 0.3), g.position, _lamp_head_mat)
			bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(l)
	signs[b["id"]] = l


func update_owners() -> void:
	for id in awnings:
		var b := Game.biz_by_id(id)
		if b.is_empty():
			continue
		var p: int = b["owned_by"] if b["owned_by"] >= 0 else b["protector"]
		var col := Color(0.42, 0.42, 0.4)
		if p >= 0:
			col = Color(Game.fam(p)["color"])
		((awnings[id] as MeshInstance3D).material_override as ShaderMaterial).set_shader_parameter("stripe", col)
	for id in signs:
		var b := Game.biz_by_id(id)
		if b.is_empty() or b["kind"] == "precinct":
			continue
		(signs[id] as Label3D).text = b["name"]


func _lamps() -> void:
	var lamp_scene := load(LAMP) as PackedScene
	var k := 0
	for b in plan.blocks:
		var r: Array = b["rect"]
		var corners := [Vector3(r[0] + 0.6, 0.16, r[1] + 0.6), Vector3(r[2] - 0.6, 0.16, r[3] - 0.6)]
		if (b["i"] + b["j"]) % 2 == 0:
			corners = [Vector3(r[2] - 0.6, 0.16, r[1] + 0.6), Vector3(r[0] + 0.6, 0.16, r[3] - 0.6)]
		for c in corners:
			var lamp := lamp_scene.instantiate() as Node3D
			lamp.scale = Vector3.ONE * 7.0
			_darken(lamp, Color("1c1f22"))
			lamp.position = c
			# the arm (local -z) points out over the street
			var out := Vector3(signf(c.x - (r[0] + r[2]) * 0.5), 0, signf(c.z - (r[1] + r[3]) * 0.5))
			lamp.rotation.y = atan2(-out.x, -out.z)
			add_child(lamp)
			var head_pos := lamp.position + Vector3(0, 4.3, 0)
			var light := OmniLight3D.new()
			light.light_color = Color("ffc98a")
			light.omni_range = 17.0
			light.omni_attenuation = 1.0
			light.light_energy = 0.0
			light.position = head_pos + Vector3(out.x, 0, out.z) * 0.6
			light.shadow_enabled = false
			add_child(light)
			lamps.append(light)
			var bulb := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.22
			sm.height = 0.44
			bulb.mesh = sm
			bulb.material_override = _lamp_head_mat
			bulb.position = light.position
			bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(bulb)
			k += 1


func _waterfront() -> void:
	var q: Array = plan.quay_rect
	var concrete := StandardMaterial3D.new()
	concrete.albedo_texture = _tex("concrete_wall_albedo")
	concrete.albedo_color = Color(0.55, 0.53, 0.5)
	concrete.uv1_triplanar = true
	concrete.uv1_world_triplanar = true
	concrete.uv1_scale = Vector3(0.2, 0.2, 0.2)
	_box(Vector3(q[2] - q[0], 0.2, q[3] - q[1]), Vector3((q[0] + q[2]) * 0.5, 0.1, (q[1] + q[3]) * 0.5), concrete)
	# the river
	var water := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(160, plan.bounds.size.y + 80)
	pm.subdivide_width = 40
	pm.subdivide_depth = 40
	water.mesh = pm
	water.material_override = water_mat
	water.position = Vector3(plan.water_x + 80, -0.9, plan.bounds.position.y + plan.bounds.size.y * 0.5)
	add_child(water)
	var planks := StandardMaterial3D.new()
	planks.albedo_texture = _tex("planks_albedo")
	planks.normal_enabled = true
	planks.normal_texture = _tex("planks_normal")
	planks.albedo_color = Color(0.62, 0.5, 0.4)
	planks.uv1_triplanar = true
	planks.uv1_world_triplanar = true
	planks.uv1_scale = Vector3(0.35, 0.35, 0.35)
	var post := StandardMaterial3D.new()
	post.albedo_color = Color(0.2, 0.16, 0.12)
	# quay edge wall with gaps where the piers start
	var zs: Array = []
	for p in plan.piers:
		zs.append([p["z0"], p["z1"]])
	var z := float(q[1])
	for gap in zs:
		_collider(Vector3(0.6, 3, gap[0] - z), Vector3(plan.water_x + 0.3, 1.5, (z + gap[0]) * 0.5), 0.0)
		z = gap[1]
	_collider(Vector3(0.6, 3, q[3] - z), Vector3(plan.water_x + 0.3, 1.5, (z + q[3]) * 0.5), 0.0)
	for p in plan.piers:
		var len: float = p["x1"] - p["x0"]
		var wd: float = p["z1"] - p["z0"]
		var cx: float = (p["x0"] + p["x1"]) * 0.5
		var cz: float = (p["z0"] + p["z1"]) * 0.5
		_box(Vector3(len, 0.3, wd), Vector3(cx, 0.05, cz), planks)
		# rails of the pier: walls you can't walk through
		_collider(Vector3(len, 3, 0.4), Vector3(cx, 1.5, p["z0"] - 0.2), 0.0)
		_collider(Vector3(len, 3, 0.4), Vector3(cx, 1.5, p["z1"] + 0.2), 0.0)
		_collider(Vector3(0.4, 3, wd), Vector3(p["x1"] + 0.2, 1.5, cz), 0.0)
		var x: float = p["x0"] + 2.0
		while x < p["x1"]:
			for s in [p["z0"] + 0.25, p["z1"] - 0.25]:
				_box(Vector3(0.3, 1.4, 0.3), Vector3(x, -0.4, s), post)
				_box(Vector3(0.35, 0.5, 0.35), Vector3(x, 0.35, s), post)
			x += 4.0
	# stacks of crates and barrels on the quay
	var box_scene := load("res://assets/kenney/cars/box.glb") as PackedScene
	for n in 14:
		var bx := _rng.randf_range(q[0] + 5.0, q[2] - 2.0)
		var bz := _rng.randf_range(q[1] + 4.0, q[3] - 4.0)
		var skip := false
		for lot in plan.lots_of_kind("warehouse"):
			if absf(bz - lot["center"][1]) < 9.5 and bx < q[0] + 19:
				skip = true
		if skip:
			continue
		for s in _rng.randi_range(1, 3):
			var bn := box_scene.instantiate() as Node3D
			bn.scale = Vector3.ONE * 1.3
			bn.position = Vector3(bx + _rng.randf_range(-0.5, 0.5), 0.2 + s * 0.92, bz + _rng.randf_range(-0.5, 0.5))
			bn.rotation.y = _rng.randf() * TAU
			add_child(bn)
		_collider(Vector3(1.3, 3, 1.3), Vector3(bx, 1.5, bz), 0.0)
	# bollards
	for n in 10:
		_box(Vector3(0.45, 0.6, 0.45), Vector3(plan.water_x - 0.8, 0.5, lerpf(q[1] + 3, q[3] - 3, n / 9.0)), post)


func _backdrop() -> void:
	# a ring of blocks beyond the outer streets closes the map in
	var half := CityPlan.STREET * 0.5
	var out := []
	for j in range(-1, CityPlan.NZ + 1):
		out.append(Vector2i(-1, j))
	for i in CityPlan.NX:
		out.append(Vector2i(i, -1))
		out.append(Vector2i(i, CityPlan.NZ))
	for c in out:
		var x0: float = c.x * CityPlan.PITCH + half
		var z0: float = c.y * CityPlan.PITCH + half
		var w := CityPlan.PITCH - CityPlan.STREET
		var h := _rng.randf_range(14.0, 24.0)
		var pos := Vector3(x0 + w * 0.5, h * 0.5, z0 + w * 0.5)
		var mi := _facade(Vector3(w, h, w), Color(0.7, 0.6, 0.55), float(_rng.randi_range(0, 2)), float(c.x * 13 + c.y + 20), false)
		mi.position = pos
		_collider(Vector3(w, h, w), pos, 0.0)
		_box(Vector3(w + 1.0, 0.16, w + 1.0), Vector3(pos.x, 0.08, pos.z), pave_mat)
	# the far side of the outer streets: walls
	var r := plan.bounds
	_collider(Vector3(2, 6, r.size.y), Vector3(-half - CityPlan.PITCH * 0.5, 3, r.position.y + r.size.y * 0.5), 0.0)


func _street_props() -> void:
	var red := StandardMaterial3D.new()
	red.albedo_color = HYDRANT_COLOR
	red.metallic = 0.4
	var green := StandardMaterial3D.new()
	green.albedo_color = Color("2f4a38")
	var paper := StandardMaterial3D.new()
	paper.albedo_color = Color("d8cfb8")
	for b in plan.blocks:
		var r: Array = b["rect"]
		# a hydrant and a newsstand or mailbox per block, on the kerb
		var hx: float = lerpf(r[0], r[2], _rng.randf_range(0.2, 0.8))
		_box(Vector3(0.3, 0.7, 0.3), Vector3(hx, 0.5, r[1] + 0.9), red)
		if _rng.randf() < 0.5:
			var nz: float = lerpf(r[1], r[3], _rng.randf_range(0.25, 0.75))
			_box(Vector3(1.2, 1.4, 0.9), Vector3(r[2] - 1.0, 0.85, nz), green, 0.0, true)
			_box(Vector3(1.0, 0.1, 0.7), Vector3(r[2] - 1.0, 1.6, nz), paper)
		else:
			var mz: float = lerpf(r[1], r[3], _rng.randf_range(0.25, 0.75))
			_box(Vector3(0.5, 1.1, 0.45), Vector3(r[0] + 0.9, 0.7, mz), green)
