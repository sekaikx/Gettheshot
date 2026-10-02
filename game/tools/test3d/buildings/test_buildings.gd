extends Node3D
## Test scene for Buildings3D: new campaign, builds only the buildings (with a plain ground), snaps PNGs of
## streets by day, night, rain, a padlocked shop, a smashed window and inside mode, then quits.
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --rendering-driver opengl3 --resolution 1600x900 --path game res://tools/test3d/buildings/test_buildings.tscn
## Env: OUT_DIR=dir (default /tmp/claude-0/out_bld/t), SHOTS=name,name (default all)

const P := CityPlan.PITCH

var buildings: Buildings3D
var cam: Camera3D
var sun: DirectionalLight3D
var env: Environment
var plan: CityPlan

# name, focus (x, z) metres, dist, night, wet, inside lot (-1 = none, -3 = the club), pitch deg
var shots := [
	["street_day", Vector2(72.0, 88.5), 22.0, 0.0, 0.0, -1, 58.0],
	["street_day2", Vector2(118.0, 88.5), 22.0, 0.0, 0.0, -1, 58.0],
	["street_ns", Vector2(96.0, 70.0), 22.0, 0.0, 0.0, -1, 58.0],
	["street_close", Vector2(72.0, 88.5), 11.0, 0.0, 0.0, -1, 58.0],
	["roofs", Vector2(72.0, 70.0), 38.0, 0.0, 0.0, -1, 58.0],
	["city", Vector2(3 * P, 2 * P), 120.0, 0.0, 0.0, -1, 58.0],
	["quay", Vector2(300.0, 52.0), 26.0, 0.0, 0.0, -1, 58.0],
	["night", Vector2(72.0, 88.5), 22.0, 1.0, 0.0, -1, 58.0],
	["night_rain", Vector2(118.0, 88.5), 22.0, 1.0, 1.0, -1, 58.0],
	["rain_day", Vector2(72.0, 88.5), 22.0, 0.0, 1.0, -1, 58.0],
	["club", "club:0", 12.0, 0.0, 0.0, -1, 58.0],
	["precinct", "precinct:0", 12.0, 0.0, 0.0, -1, 58.0],
	["warehouse", "warehouse:0", 14.0, 0.0, 0.0, -1, 58.0],
	["bakery", "bakery:0", 12.0, 0.0, 0.0, -1, 58.0],
	["pawn", "pawnshop:0", 12.0, 0.0, 0.0, -1, 58.0],
	["barber", "barber:0", 12.0, 0.0, 0.0, -1, 58.0],
	["club_night", "club:0", 12.0, 1.0, 0.0, -1, 58.0],
	["shops_night", "bakery:0", 12.0, 1.0, 1.0, -1, 58.0],
	["neon", "neon", 12.0, 1.0, 0.0, -1, 58.0],
	["padlock", Vector2(0, 0), 10.0, 0.0, 0.0, -1, 58.0],
	["broken", Vector2(0, 0), 10.0, 0.0, 0.0, -1, 58.0],
	["inside", Vector2(0, 0), 16.0, 0.0, 0.0, -3, 58.0],
]


func _ready() -> void:
	Game.new_campaign({"seed": 1923, "families": 4}, [{"peer": 1, "name": "Alex", "family_name": "Vitale", "color": "#c42828"}])
	Game.running = false
	plan = Game.plan
	_scene()
	var t0 := Time.get_ticks_usec()
	buildings = Buildings3D.new()
	add_child(buildings)
	buildings.build(plan)
	print("buildings build: %.0f ms, %d children, %d light points" % [(Time.get_ticks_usec() - t0) / 1000.0, buildings.get_child_count(), buildings.light_points.size()])
	_run()


func _scene() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.0
	add_child(sun)
	sun.look_at_from_position(Vector3.ZERO, V3.SUN_DIR, Vector3.UP)
	cam = Camera3D.new()
	cam.fov = V3.CAM_FOV
	cam.near = 0.5
	cam.far = 600.0
	add_child(cam)
	cam.current = true
	# plain ground: asphalt, sidewalk slabs per block
	var asphalt := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(plan.bounds.size.x + 100.0, plan.bounds.size.y + 100.0)
	asphalt.mesh = pm
	asphalt.position = Vector3(plan.bounds.get_center().x, 0.0, plan.bounds.get_center().y)
	asphalt.material_override = V3.mat(Color("2c2e32"), 0.9)
	add_child(asphalt)
	var sw := V3.mat(Color("7d7568"), 0.9)
	for blk in plan.blocks:
		var r: Array = blk["rect"]
		var m := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(r[2] - r[0], 0.15, r[3] - r[1])
		m.mesh = bm
		m.position = Vector3((r[0] + r[2]) * 0.5, 0.075, (r[1] + r[3]) * 0.5)
		m.material_override = sw
		add_child(m)
	var q := plan.quay_rect
	var qm := MeshInstance3D.new()
	var qb := BoxMesh.new()
	qb.size = Vector3(q[2] - q[0], 0.15, q[3] - q[1])
	qm.mesh = qb
	qm.position = Vector3((q[0] + q[2]) * 0.5, 0.075, (q[1] + q[3]) * 0.5)
	qm.material_override = V3.mat(Color("57534e"), 0.9)
	add_child(qm)


func _light(night: float, wet: float) -> void:
	var day_sky := Color("a9bccb")
	var night_sky := Color("0c1220")
	var sky := day_sky.lerp(night_sky, night)
	if wet > 0.5:
		sky = sky.lerp(Color("5a6470").lerp(Color("10141c"), night), 0.6)
	env.background_color = sky
	env.ambient_light_color = Color("d0d4dc").lerp(Color("303c5a"), night)
	env.ambient_light_energy = lerpf(0.75, 0.55, night)
	sun.light_energy = lerpf(1.15, 0.0, clampf(night * 1.3, 0.0, 1.0)) * (0.45 if wet > 0.5 else 1.0)
	env.fog_enabled = wet > 0.5 or night > 0.4
	env.fog_light_color = sky
	env.fog_density = 0.012 if wet > 0.5 else 0.002
	buildings.set_night(night, wet)
	if OS.get_environment("DBG") != "":
		var wm: ShaderMaterial = preload("res://scripts/world3d/buildings/bld_mats.gd").get_mats()["wall"]
		wm.set_shader_parameter("dbg", int(OS.get_environment("DBG")))


func _place(focus: Vector2, dist: float, pitch_deg: float) -> void:
	var pitch := deg_to_rad(pitch_deg)
	var f := Vector3(focus.x, 0.0, focus.y)
	cam.global_position = f + Vector3(0, sin(pitch) * dist, cos(pitch) * dist)
	cam.look_at(f + Vector3(0, 0.6, 0), Vector3.UP)


func _biz_of_kind(kind: String, nth: int = 0) -> Dictionary:
	var k := 0
	for b in Game.biz:
		if b["kind"] == kind:
			if k == nth:
				return b
			k += 1
	return {}


func _biz_south(kinds: Array) -> Dictionary:
	for b in Game.biz:
		if b["kind"] in kinds and plan.lots[int(b["lot"])]["side"] == "S":
			return b
	return {}


func _lot_focus(lot_id: int) -> Vector2:
	var lot: Dictionary = plan.lots[lot_id]
	return Vector2(lot["door"][0], lot["door"][1])


func _run() -> void:
	var out_dir := OS.get_environment("OUT_DIR")
	if out_dir == "":
		out_dir = "/tmp/claude-0/out_bld/t"
	DirAccess.make_dir_recursive_absolute(out_dir)
	var want := OS.get_environment("SHOTS").split(",", false)
	await get_tree().process_frame
	await get_tree().process_frame
	for s in shots:
		var name: String = s[0]
		if not want.is_empty() and not want.has(name):
			continue
		var focus: Vector2 = Vector2.ZERO
		if s[1] is String and s[1] == "neon":
			var nb := _biz_south(["restaurant", "cigar", "candy", "drugstore"])
			focus = _lot_focus(int(nb["lot"]))
		elif s[1] is String:
			var parts: PackedStringArray = (s[1] as String).split(":")
			var bb := _biz_of_kind(parts[0], int(parts[1]))
			if bb.is_empty():
				print("no business of kind ", parts[0])
				continue
			focus = _lot_focus(int(bb["lot"]))
		else:
			focus = s[1]
		var inside: int = s[5]
		if name == "padlock":
			var b := _biz_south(["bakery", "grocer", "tailor", "laundry", "cobbler"])
			b["closed_until"] = Game.month + 6
			b["protector"] = 0
			buildings.update_owners()
			focus = _lot_focus(int(b["lot"]))
		elif name == "broken":
			var b := _biz_south(["butcher", "cafe", "hardware", "candy", "fish", "barber"])
			b["broken"] = [1, 2]
			b["owned_by"] = 1 if Game.families.size() > 1 else 0
			buildings.update_owners()
			focus = _lot_focus(int(b["lot"]))
		elif inside == -3:
			var b := _biz_of_kind("club")
			inside = int(b["lot"])
			focus = V3.rect_m(W.lot_rect(plan.lots[inside])).get_center()
		_light(float(s[3]), float(s[4]))
		buildings.set_inside(inside)
		_place(focus, float(s[2]), float(s[6]))
		for i in 4:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var path := "%s/%s.png" % [out_dir, name]
		img.save_png(path)
		var crop := OS.get_environment("CROP").split(",", false)
		if crop.size() == 5:
			var c := img.get_region(Rect2i(int(crop[0]), int(crop[1]), int(crop[2]), int(crop[3])))
			c.resize(int(crop[2]) * int(crop[4]), int(crop[3]) * int(crop[4]), Image.INTERPOLATE_NEAREST)
			c.save_png("%s/%s_crop.png" % [out_dir, name])
		print("shot %s  draw calls %d, primitives %d, objects %d" % [path, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)])
	get_tree().quit()
