extends Node
## xvfb-run -a godot --rendering-driver opengl3 --path . res://tools/shot_city.tscn
func _ready() -> void:
	await get_tree().process_frame
	var game = Game
	game.new_campaign({"seed": 1923, "families": 4}, [{"peer": 1, "name": "Alex", "family_name": "Vitale", "color": "#c42828"}])
	var w := Node3D.new()
	add_child(w)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("141820")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("8a93a8")
	e.ambient_light_energy = 0.5
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = true
	env.environment = e
	w.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.light_energy = 0.9
	sun.light_color = Color("ffd8a8")
	sun.shadow_enabled = true
	w.add_child(sun)
	var city := CityBuilder.new()
	w.add_child(city)
	city.build(game.plan)
	city.update_owners()
	var night := float(OS.get_environment("NIGHT")) if OS.get_environment("NIGHT") != "" else 0.0
	city.set_night(night, 0.0)
	if night > 0.5:
		sun.light_energy = 0.15
		sun.light_color = Color("8ea8ff")
		e.ambient_light_energy = 0.25
	var hq: Dictionary = game.biz[game.families[0]["hq"]]
	var door := Vector3(hq["door"][0], 0.16, hq["door"][1])
	var kinds := ["boss", "crew", "crew", "cop", "ped", "ped", "shop", "recruit", "ped"]
	for k in kinds.size():
		var p := Person.new()
		w.add_child(p)
		p.setup(kinds[k], k * 77 + 5, Color("#c42828") if kinds[k] in ["boss", "crew"] else Color(0,0,0,0))
		p.position = door + Vector3((k - 4) * 1.3, 0, 1.5 + (k % 2) * 0.8)
		p.set_motion(Person.Anim.WALK if k % 3 == 0 else Person.Anim.IDLE, 1.3)
	var cam := Camera3D.new()
	w.add_child(cam)
	var dist := float(OS.get_environment("DIST")) if OS.get_environment("DIST") != "" else 18.0
	cam.fov = 40
	var look := door
	if OS.get_environment("WIDE") != "":
		look = Vector3(150, 0, 100)
	cam.position = look + Vector3(0, dist * 0.85, dist * 0.55)
	cam.look_at(look + Vector3(0, 1, 0))
	cam.current = true
	for i in 30:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png(OS.get_environment("OUT") if OS.get_environment("OUT") != "" else "/tmp/city.png")
	print("saved")
	get_tree().quit()
