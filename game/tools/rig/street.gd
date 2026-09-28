extends Node
## The street at the game camera (pitch 56 deg) with a crowd of every kind of Person.
## xvfb-run -a godot --rendering-driver opengl3 --path . res://tools/rig/street.tscn  (env DIST, OUT, NIGHT)
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
	var door := Vector3.ZERO
	for lot in game.plan.lots:   # a south-side shopfront (faces +z, towards the camera)
		if lot["kind"] == "tenement" and lot["side"] == "S" and bool(lot["shop"]):
			door = Vector3(lot["door"][0], 0.16, lot["door"][1])
			break
	var kinds := ["boss", "crew", "crew", "crew", "cop", "cop", "fed", "shop", "shop", "dock", "dock", "dock", "recruit", "recruit", "union", "dealer", "smuggler"]
	for k in 22:
		kinds.append("ped")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for k in kinds.size():
		var p := Person.new()
		w.add_child(p)
		p.setup(kinds[k], k * 131 + 17, Color("#c42828") if kinds[k] in ["boss", "crew"] else Color(0, 0, 0, 0))
		p.position = door + Vector3(rng.randf_range(-9.0, 9.0), 0, rng.randf_range(0.2, 7.0))
		p.rotation.y = rng.randf() * TAU
		var st: int = [Person.Anim.WALK, Person.Anim.IDLE, Person.Anim.TALK, Person.Anim.ARMS, Person.Anim.RUN][k % 5]
		p.set_motion(st, 1.35 if st != Person.Anim.RUN else 3.8)
		if k % 7 == 3:
			p.set_motion(Person.Anim.CARRY, 1.3)
			p.carry(true)
		if k == 11:
			p.action("down")
		if k == 12:
			p.action("punch")
	var cam := Camera3D.new()
	w.add_child(cam)
	var dist := float(OS.get_environment("DIST")) if OS.get_environment("DIST") != "" else 18.0
	cam.fov = 40
	var look := door + Vector3(0, 0, 2.5)
	if OS.get_environment("WIDE") != "":
		look = Vector3(150, 0, 100)
	cam.position = look + Vector3(0, sin(deg_to_rad(56.0)), cos(deg_to_rad(56.0))) * dist
	cam.look_at(look + Vector3(0, 1, 0))
	cam.current = true
	for i in 30:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png(OS.get_environment("OUT") if OS.get_environment("OUT") != "" else "/tmp/city.png")
	print("saved")
	get_tree().quit()
