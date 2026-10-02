extends Node3D
## Test scene for Ground3D: builds only the ground (plus the placeholder buildings for context) from
## CityPlan.generate(1923), renders a few shots to PNG and quits.
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --rendering-driver opengl3 --resolution 1600x900 \
##     --path game res://tools/test3d/ground/test_ground3d.tscn
## Env: OUT_DIR=dir (default /tmp/claude-0/out_ground3d), SHOTS=name,name (default all), BUILDINGS=0 to skip them.

const P := CityPlan.PITCH

# name, focus (x, z) metres, camera distance, night, wet, pitch degrees
var shots := [
	["isec", Vector2(1 * P + 4.0, 1 * P + 4.0), 22.0, 0.0, 0.0, 58.0],
	["bowery", Vector2(2 * P + 2.0, 2 * P - 12.0), 24.0, 0.0, 0.0, 58.0],
	["orchard", Vector2(4 * P, 2 * P + 10.0), 24.0, 0.0, 0.0, 58.0],
	["yard", Vector2(2.5 * P, 1.5 * P), 30.0, 0.0, 0.0, 70.0],
	["quay", Vector2(6 * P + 20.0, 2 * P - 6.0), 32.0, 0.0, 0.0, 58.0],
	["piers", Vector2(6 * P + 30.0, 34.0), 30.0, 0.0, 0.0, 50.0],
	["city", Vector2(168.0, 96.0), 190.0, 0.0, 0.0, 62.0],
	["night_isec", Vector2(1 * P + 4.0, 1 * P + 4.0), 22.0, 1.0, 0.0, 58.0],
	["wet_isec", Vector2(3 * P + 4.0, 2 * P + 4.0), 22.0, 0.0, 1.0, 58.0],
	["night_wet", Vector2(2 * P + 2.0, 2 * P - 6.0), 24.0, 1.0, 1.0, 58.0],
	["edge_nw", Vector2(-4.0, -4.0), 30.0, 0.0, 0.0, 58.0],
	["edge_sw", Vector2(40.0, 212.0), 30.0, 0.0, 0.0, 58.0],
	["river", Vector2(6 * P + 40.0, 108.0), 40.0, 0.0, 0.0, 55.0],
	["barge", Vector2(6 * P + 36.0 + 44.0, 112.0), 24.0, 0.0, 0.0, 50.0],
	["night_pier", Vector2(6 * P + 40.0, 36.0), 26.0, 1.0, 0.0, 52.0],
	["night_quay", Vector2(6 * P + 22.0, 2 * P + 2.0), 30.0, 1.0, 0.6, 58.0],
]

var ground: Ground3D
var cam: Camera3D
var sun: DirectionalLight3D
var env: Environment
var lamps: Array[OmniLight3D] = []
var bld: Node3D


func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	var plan := CityPlan.generate(1923)
	ground = Ground3D.new()
	add_child(ground)
	ground.build(plan)
	print("GROUND BUILD ms: ", Time.get_ticks_msec() - t0, " lamps: ", ground.lamp_points.size())
	var stats := {"nodes": 0, "tris": 0}
	_count(ground, stats)
	print("GROUND mesh instances: ", stats["nodes"], " triangles: ", stats["tris"])
	if OS.get_environment("BUILDINGS") != "0":
		var b := Buildings3D.new()
		add_child(b)
		b.build(plan)
		bld = b
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("a9bccb")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c8cdd6")
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	add_child(sun)
	sun.look_at_from_position(Vector3.ZERO, V3.SUN_DIR, Vector3.UP)
	for i in 12:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.8, 0.5)
		l.omni_range = 9.0
		l.omni_attenuation = 1.6
		l.visible = false
		add_child(l)
		lamps.append(l)
	cam = Camera3D.new()
	cam.fov = V3.CAM_FOV
	cam.near = 0.5
	cam.far = 600.0
	add_child(cam)
	cam.current = true
	_run()


func _count(n: Node, st: Dictionary) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		st["nodes"] += 1
		var m := (n as MeshInstance3D).mesh
		for k in m.get_surface_count():
			var arr := m.surface_get_arrays(k)
			st["tris"] += int((arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3)
	for c in n.get_children():
		_count(c, st)


func _set_light(night: float, wet: float) -> void:
	var day_sky := Color("a9bccb")
	if wet > 0.0:
		day_sky = day_sky.lerp(Color("8c9096"), 0.7 * wet)
	env.background_color = day_sky.lerp(Color("0c1220"), night)
	env.ambient_light_color = Color("d0d4dc").lerp(Color("303c5a"), night)
	env.ambient_light_energy = lerpf(0.75, 0.55, night)
	sun.light_energy = lerpf(1.1, 0.12, night) * (1.0 - 0.5 * wet)
	sun.light_color = Color(1, 0.96, 0.9).lerp(Color(0.5, 0.6, 0.9), night)
	ground.set_night(night, wet)


## Close-ups of the first prop of each kind (CLOSE=1), for checking the prefabs.
func _closeups() -> void:
	var want_types := ["newsstand", "tree", "bench", "lamp", "ashcans", "mailbox", "bike", "trough", "hydrant", "callbox", "alarm", "basket", "sign", "pole"]
	var seen := {}
	for b in ground.layout.blocks:
		for p in b["props"]:
			var t: String = p["t"]
			if t in want_types and not seen.has(t) and not b["phantom"]:
				seen[t] = true
				var pm: Vector2 = (p["p"] as Vector2) / W.M
				shots.append(["c_" + t, pm, 7.0, 0.0, 0.0, 52.0])
		for f in b["flats"]:
			var t2: String = f["t"]
			if t2 != "drain" and not seen.has(t2) and not b["phantom"]:
				seen[t2] = true
				shots.append(["c_" + t2, (f["p"] as Vector2) / W.M, 6.0, 0.0, 0.0, 52.0])
	for s in ground.layout.segs:
		for p in s["props"]:
			if not seen.has("pushcart"):
				seen["pushcart"] = true
				shots.append(["c_pushcart", (p["p"] as Vector2) / W.M, 7.0, 0.0, 0.0, 52.0])
	var q := ground.layout.plan.water_x
	shots.append(["c_crane", Vector2(q - 3.0, 76.0), 16.0, 0.0, 0.0, 45.0])
	shots.append(["c_shack", Vector2(q - 3.4, 112.0), 10.0, 0.0, 0.0, 50.0])


func _run() -> void:
	if OS.get_environment("CLOSE") == "1":
		shots.clear()
		_closeups()
	var out := OS.get_environment("OUT_DIR")
	if out == "":
		out = "/tmp/claude-0/out_ground3d"
	DirAccess.make_dir_recursive_absolute(out)
	var want := OS.get_environment("SHOTS")
	var names := want.split(",") if want != "" else PackedStringArray()
	for sh in shots:
		if not names.is_empty() and not (sh[0] in names):
			continue
		var f: Vector2 = sh[1]
		var d: float = sh[2]
		var pitch := deg_to_rad(float(sh[5]))
		var focus := Vector3(f.x, 0.0, f.y)
		cam.position = focus + Vector3(0, sin(pitch) * d, cos(pitch) * d)
		cam.look_at(focus, Vector3.UP)
		_set_light(float(sh[3]), float(sh[4]))
		if bld:
			bld.visible = not String(sh[0]).begins_with("yard")
		# real lights at the nearest lamps at night
		var pts := ground.lamp_points.duplicate()
		pts.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.distance_squared_to(focus) < b.distance_squared_to(focus))
		for i in lamps.size():
			lamps[i].visible = float(sh[3]) > 0.3 and i < pts.size()
			if lamps[i].visible:
				lamps[i].position = pts[i]
				lamps[i].light_energy = 2.0
		for i in 4:
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/%s.png" % [out, sh[0]])
		print("shot ", sh[0])
	get_tree().quit()
