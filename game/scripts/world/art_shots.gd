extends Node
## Look-development shots for the street art (not part of the game).
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --rendering-driver opengl3 --resolution 1600x900 \
##     --path game res://scripts/world/art_shots.tscn -- --out=/tmp/x [--mode=cars|city] [--only=name,name]
## mode=cars: every vehicle kind lined up on a plain street, seen from the game camera.
## mode=city (default): a solo game on seed 1923; the camera visits named spots at set times.

var _out := "/tmp/art"
var _mode := "city"
var _only: Array = []
var world: Node


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--mode="):
			_mode = a.substr(7)
		elif a.begins_with("--only="):
			_only = a.substr(7).split(",")
	await get_tree().process_frame
	if _mode == "stats":
		for kd in ["truck", "delivery", "sedan", "taxi", "van", "police"]:
			var m := CarModels.body(kd)
			var sp := CarModels.spec(kd)
			var w := CarModels.wheel(sp["wheel"], sp["wheels"][0][1])
			print("STAT %s body %d wheel %d" % [kd, _tris(m), _tris(w)])
		print("STAT freighter %d gantry %d hall %d" % [_tris(Harbour.freighter()), _tris(Harbour.gantry()), _tris(Harbour.union_hall())])
	elif _mode == "cars":
		await _cars()
	else:
		await _city()
	get_tree().quit()


func _tris(m: Mesh) -> int:
	var t := 0
	for si in m.get_surface_count():
		t += (m.surface_get_arrays(si)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return t


func _snap(name: String) -> void:
	if not _only.is_empty() and name not in _only:
		return
	get_viewport().get_texture().get_image().save_png("%s_%s.png" % [_out, name])
	print("shot ", name)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _cars() -> void:
	var root := Node3D.new()
	add_child(root)
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("9fb0c4")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("b0b4c0")
	e.ambient_light_energy = 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = e
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.shadow_enabled = true
	sun.light_color = Color("fff1dc")
	root.add_child(sun)
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 80)
	g.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.42, 0.41, 0.39)
	g.material_override = gm
	root.add_child(g)
	var kinds := ["truck", "delivery", "sedan", "taxi", "van", "police"]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--kinds="):
			kinds = Array(a.substr(8).split(","))
	for i in kinds.size():
		var v: Vehicle = Vehicle.new()
		v.setup(null, "c%d" % i, kinds[i], Color("#c42828") if kinds[i] == "truck" else Color(0, 0, 0, 0))
		root.add_child(v)
		v.place(Vector3((i - (kinds.size() - 1) * 0.5) * 2.6, 0, 0), (0.35 if i % 2 == 0 else -0.35) if kinds.size() > 1 else 0.0)
		if kinds[i] in ["truck", "delivery"]:
			v.set_load(7)
	var cam := Camera3D.new()
	cam.fov = 42
	root.add_child(cam)
	for view in [["cars_game", 17.0, 0.0], ["cars_close", 9.0, 0.6], ["cars_side", 7.0, 1.4], ["cars_front", 6.0, 0.0]]:
		var d: float = view[1]
		var yaw: float = view[2]
		var pitch := deg_to_rad(56.0 if view[0] not in ["cars_side", "cars_front"] else 20.0)
		cam.position = Vector3(sin(yaw), 0, cos(yaw)) * cos(pitch) * d + Vector3(0, sin(pitch) * d, 0)
		cam.look_at(Vector3(0, 0.8, 0))
		await _frames(8)
		_snap(view[0])


func _city() -> void:
	Net.my_info = {"name": "Alex", "family_name": "Vitale", "color": "#c42828", "join": -1}
	Net.solo()
	Game.new_campaign({"seed": 1923, "families": 4, "month_seconds": 3000.0, "start_month": 72, "end_month": Game.REPEAL_MONTH},
		[{"peer": 1, "name": "Alex", "family_name": "Vitale", "color": "#c42828", "join": -1}])
	world = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	await _frames(20)
	if world.hud.is_modal():
		world.hud.toggle_help()
	var plan: CityPlan = world.get("plan")
	var hq: Dictionary = Game.biz_by_id(int(Game.fam(0)["hq"]))
	var door := Vector3(hq["door"][0], 0, hq["door"][1])
	var P := CityPlan.PITCH
	var q: Array = plan.quay_rect
	var spots := [
		# name, focus, dist, yaw, clock, weather
		["hq", door, 17.0, 0.0, 0.3, "clear"],
		["hq_close", door, 11.0, 0.6, 0.3, "clear"],
		["corner", Vector3(2 * P, 0, 2 * P), 24.0, 0.4, 0.28, "clear"],
		["italy", Vector3(1 * P + 20, 0, 3 * P + 2), 20.0, -0.5, 0.33, "clear"],
		["wide", Vector3(2.5 * P, 0, 2 * P), 40.0, 0.0, 0.3, "clear"],
		["trolley", Vector3(3 * P, 0, 1.5 * P), 22.0, 0.8, 0.31, "clear"],
		["el", Vector3(0, 0, 1.5 * P), 24.0, -0.8, 0.29, "clear"],
		["docks", Vector3(q[0] + 16, 0, 60), 34.0, -0.6, 0.3, "clear"],
		["docks_crane", Vector3(q[2] + 10, 0, 160), 30.0, 0.5, 0.32, "clear"],
		["docks_wide", Vector3(q[0] + 14, 0, 70), 45.0, -PI * 0.5, 0.3, "clear"],
		["docks_wide2", Vector3(q[0] + 14, 0, 150), 45.0, -PI * 0.5 - 0.4, 0.3, "clear"],
		["docks_night", Vector3(q[0] + 14, 0, 100), 40.0, -PI * 0.5, 0.74, "clear"],
		["roofs", Vector3(1.5 * P, 0, 1.5 * P), 40.0, 2.4, 0.27, "clear"],
		["dusk", Vector3(2 * P, 0, 2 * P), 22.0, 0.3, 0.5, "clear"],
		["night", door, 18.0, 0.0, 0.74, "clear"],
		["night_docks", Vector3(q[2] + 8, 0, 96), 26.0, -0.4, 0.74, "clear"],
		["rain", Vector3(2 * P, 0, 1 * P), 22.0, 0.2, 0.7, "rain"],
		["fog", Vector3(3 * P, 0, 2 * P), 26.0, -0.2, 0.3, "fog"],
	]
	Game.boat["crates"] = 20
	var shops_s: Array = []
	for b in Game.biz:
		if absf(float(b["yaw"])) < 0.01 and b["kind"] not in ["precinct", "warehouse"]:
			shops_s.append(b)
	for i in mini(2, shops_s.size()):
		var b: Dictionary = shops_s[i * 3 % shops_s.size()]
		spots.append(["shop%d" % i, Vector3(b["door"][0], 0, b["door"][1] + 2.0), 17.0, 0.25, 0.3, "clear"])
		spots.append(["shop%d_night" % i, Vector3(b["door"][0], 0, b["door"][1] + 2.0), 17.0, 0.25, 0.74, "clear"])
	var ys: Array = world.city.yard_spots
	for i in mini(2, ys.size()):
		var yv: Vector3 = ys[i * 2 % ys.size()]
		spots.append(["yard%d" % i, yv + Vector3(18.0, 0, 0.0), 45.0, -0.9, 0.3, "clear"])
	var bs: Array = world.city.billboard_spots
	for i in mini(2, bs.size()):
		var bb: Vector3 = bs[i]
		var fw := Vector3(sin(bb.y), 0, cos(bb.y))
		spots.append(["billboard%d" % i, Vector3(bb.x, 0, bb.z) - fw * 8.0, 45.0, bb.y, 0.3, "clear"])
	var tip: Array = plan.piers[1]["tip"]
	spots.append(["boat", Vector3(tip[0], 0, tip[1]), 15.0, -0.6, 0.72, "clear"])
	spots.append(["boat_day", Vector3(tip[0], 0, tip[1]), 15.0, -0.6, 0.62, "clear"])
	for vk in ["v0", "v2", "v3", "v6"]:
		if world.vehicles.has(vk):
			spots.append(["car_" + vk, world.vehicles[vk], 11.0, 0.5, 0.3, "clear"])
	for s in spots:
		if not _only.is_empty() and s[0] not in _only:
			continue
		var focus: Vector3 = s[1] if s[1] is Vector3 else (s[1] as Node3D).global_position
		world.cam.target = null if s[1] is Vector3 else s[1]
		world.cam._focus = focus
		world.cam.yaw = s[3]
		world.cam.yaw_goal = s[3]
		world.cam.dist = s[2]
		world.cam.dist_goal = s[2]
		Game.clock = s[4]
		world.weather = s[5]
		world.local_actor.place(focus + Vector3(0.5, 0, 0.5) + (Vector3(0, 0, 3.0) if not s[1] is Vector3 else Vector3.ZERO))
		await _frames(10 if s[5] != "rain" else 40)
		_snap(s[0])
		print("perf %s: draw calls %d, objects %d, primitives %d, fps %d" % [s[0],
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), Engine.get_frames_per_second()])
