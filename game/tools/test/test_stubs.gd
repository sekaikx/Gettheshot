extends Node2D
## Smoke test for the 2D pieces: builds the city from the stubs, a few people and cars, renders a
## screenshot and quits. Template for the per-piece test scenes.
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --rendering-driver opengl3 --path game res://tools/test/test_stubs.tscn
## Env: OUT=path.png (default /tmp/test_stubs.png), ZOOM=1.0, NIGHT=0..1

func _ready() -> void:
	Game.new_campaign({"seed": 1923, "families": 4}, [{"peer": 1, "name": "Alex", "family_name": "Vitale", "color": "#c42828"}])
	Game.running = false
	var plan: CityPlan = Game.plan
	var ground := CityGround.new()
	add_child(ground)
	ground.build(plan)
	var inside := InteriorArt.new()
	add_child(inside)
	inside.build(plan)
	var fronts := Shopfronts.new()
	add_child(fronts)
	fronts.build(plan)
	var roofs_layer := CanvasLayer.new()
	roofs_layer.layer = W.LAYER_ROOFS
	roofs_layer.follow_viewport_enabled = true
	add_child(roofs_layer)
	var roofs := CityRoofs.new()
	roofs_layer.add_child(roofs)
	roofs.build(plan)
	var hq: Dictionary = Game.biz[Game.families[0]["hq"]]
	var at := W.door(hq)
	var kinds := ["boss", "crew", "crew", "cop", "ped", "woman", "shop", "recruit", "kid"]
	for k in kinds.size():
		var p := Person2D.new()
		add_child(p)
		p.setup(kinds[k], k * 77 + 5, Color("#c42828") if kinds[k] in ["boss", "crew"] else W.FAMILY_NONE)
		p.position = at + Vector2((k - 4) * 40, 60)
		p.rotation = k * 0.7
	var car := CarArt.new()
	add_child(car)
	car.setup("truck", Color(0, 0, 0, 0), Color("#c42828"))
	car.set_load(6)
	car.position = at + Vector2(0, 200)
	car.z_index = W.Z_CARS
	var cam := Camera2D.new()
	cam.position = at + Vector2(0, 80)
	var z := float(OS.get_environment("ZOOM")) if OS.get_environment("ZOOM") != "" else 1.0
	cam.zoom = Vector2(z, z)
	add_child(cam)
	for i in 20:
		await get_tree().process_frame
	var out := OS.get_environment("OUT") if OS.get_environment("OUT") != "" else "/tmp/test_stubs.png"
	get_viewport().get_texture().get_image().save_png(out)
	print("saved ", out)
	get_tree().quit()
