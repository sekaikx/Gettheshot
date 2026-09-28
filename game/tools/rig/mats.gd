extends Node3D
## Shows which material is which: every surface of the given outfit files painted a loud colour,
## with a legend printed to stdout.   ... res://tools/rig/mats.tscn -- --out=/tmp/m.png --files=men/Farmer,men/Worker

const LOUD := [Color.RED, Color.GREEN, Color.BLUE, Color.YELLOW, Color.MAGENTA, Color.CYAN, Color.ORANGE, Color.WHITE]

func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			args[a.substr(2, a.find("=") - 2)] = a.substr(a.find("=") + 1)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("333333")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color.WHITE
	e.ambient_light_energy = 0.8
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-30, 20, 0)
	add_child(sun)
	var files := String(args.get("files", "men/Farmer")).split(",")
	for i in files.size():
		var n := (load("res://assets/models/characters/quaternius/%s.fbx" % files[i]) as PackedScene).instantiate() as Node3D
		add_child(n)
		n.position = Vector3((i - files.size() * 0.5 + 0.5) * 2.0, 0, 0)
		var names := {}
		for m in n.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			for s in mi.mesh.get_surface_count():
				var src := mi.mesh.surface_get_material(s)
				var nm := src.resource_name
				if not names.has(nm):
					names[nm] = LOUD[names.size() % LOUD.size()]
				var mat := StandardMaterial3D.new()
				mat.albedo_color = names[nm]
				mi.set_surface_override_material(s, mat)
		var legend := []
		for nm: String in names:
			legend.append("%s=%s" % [nm, (names[nm] as Color).to_html(false)])
		print(files[i], ": ", ", ".join(legend))
	var cam := Camera3D.new()
	add_child(cam)
	cam.fov = 40
	cam.position = Vector3(0, 1.3, 4.5 + files.size())
	cam.look_at(Vector3(0, 1.1, 0))
	for k in 5:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(String(args.get("out", "/tmp/m.png")))
	get_tree().quit()
