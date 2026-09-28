extends Node2D
## Test scene for CityGround: builds the whole city's ground from a new campaign (with the stub
## roofs and shopfronts for context), then renders a set of shots to PNG and quits.
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --rendering-driver opengl3 --path game res://tools/test/test_ground.tscn
## Env: OUT_DIR=dir (default user://), SHOTS=name,name (default all), ROOFS=0 to hide the stub
## roofs, FRONTS=0 to hide the stub shopfronts.

const P := CityPlan.PITCH

var ground: CityGround
var roofs: CityRoofs
var fronts: Shopfronts
var cam: Camera2D
var night_mod: CanvasModulate
var light_nodes: Array = []
var light_tex: Texture2D

# name, centre (metres), zoom, night, wet
var shots := [
	["corner", Vector2(1 * P + 3.0, 1 * P + 2.0), 1.0, 0.0, 0.0],
	["corner_z15", Vector2(1 * P + 7.0, 1 * P + 3.0), 1.5, 0.0, 0.0],
	["corner_z06", Vector2(1 * P + 6.0, 1 * P + 6.0), 0.6, 0.0, 0.0],
	["bowery", Vector2(2 * P + 2.0, 2 * P - 16.0), 1.0, 0.0, 0.0],
	["orchard", Vector2(4 * P, 2 * P + 14.0), 1.0, 0.0, 0.0],
	["yard", Vector2(2.5 * P, 1.5 * P), 1.5, 0.0, 0.0],
	["quay", Vector2(6 * P + 26.0, 2 * P - 4.0), 0.6, 0.0, 0.0],
	["city", Vector2(168.0, 96.0), 0.15, 0.0, 0.0],
	["city_full", Vector2(168.0, 96.0), 0.085, 0.0, 0.0],
	["night_wet", Vector2(1 * P + 3.0, 1 * P + 2.0), 1.0, 1.0, 1.0],
	["night_quay", Vector2(6 * P + 22.0, 2 * P + 2.0), 0.8, 1.0, 1.0],
	["night_bowery", Vector2(2 * P + 2.0, 3 * P - 10.0), 0.6, 1.0, 0.0],
	["wet_day", Vector2(4 * P + 2.0, 1 * P + 2.0), 1.0, 0.0, 1.0],
]


func _ready() -> void:
	Game.new_campaign({"seed": 1923, "families": 4}, [{"peer": 1, "name": "Alex", "family_name": "Vitale", "color": "#c42828"}])
	Game.running = false
	var plan: CityPlan = Game.plan
	var t0 := Time.get_ticks_usec()
	ground = CityGround.new()
	add_child(ground)
	ground.build(plan)
	print("ground build: %.1f ms, %d nodes, %d lights, %d solids" % [(Time.get_ticks_usec() - t0) / 1000.0,
		ground.get_child_count(), ground.lights().size(), ground.solids().size()])
	if OS.get_environment("FRONTS") != "0":
		fronts = Shopfronts.new()
		add_child(fronts)
		fronts.build(plan)
	if OS.get_environment("ROOFS") != "0":
		var roofs_layer := CanvasLayer.new()
		roofs_layer.layer = W.LAYER_ROOFS
		roofs_layer.follow_viewport_enabled = true
		add_child(roofs_layer)
		roofs = CityRoofs.new()
		roofs_layer.add_child(roofs)
		roofs.build(plan)
	cam = Camera2D.new()
	add_child(cam)
	cam.make_current()
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 256
	gt.height = 256
	light_tex = gt
	var out_dir := OS.get_environment("OUT_DIR")
	if out_dir == "":
		out_dir = "user://"
	var only := OS.get_environment("SHOTS").split(",", false)
	var first := true
	for s in shots:
		if not only.is_empty() and not (s[0] in only):
			continue
		await _shot(s, out_dir, first)
		first = false
	get_tree().quit()


func _shot(s: Array, out_dir: String, first: bool) -> void:
	var centre: Vector2 = s[1] * W.M
	var z: float = s[2]
	var n: float = s[3]
	var w: float = s[4]
	cam.position = centre
	cam.zoom = Vector2(z, z)
	ground.set_night(n, w)
	if roofs:
		roofs.set_night(n, w)
	_night(n, centre, z)
	var t0 := Time.get_ticks_msec()
	for i in (14 if first else 5):
		await get_tree().process_frame
	var path := out_dir.path_join("ground_%s.png" % s[0])
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path, " (%d ms)" % (Time.get_ticks_msec() - t0))


## Emulates the World's night lighting: a dark ambient, plus a 2D light for each lamp near the view.
func _night(n: float, centre: Vector2, z: float) -> void:
	for l in light_nodes:
		l.queue_free()
	light_nodes.clear()
	if night_mod:
		night_mod.queue_free()
		night_mod = null
	if n <= 0.0:
		return
	night_mod = CanvasModulate.new()
	night_mod.color = Color(1, 1, 1).lerp(Pal.NIGHT_AMBIENT * 1.35, n)
	add_child(night_mod)
	var view := Rect2(centre - Vector2(800, 450) / z, Vector2(1600, 900) / z).grow(8.0 * W.M)
	var all: Array = ground.lights().duplicate()
	if fronts:
		all.append_array(fronts.lights())
	for l in all:
		var p: Vector2 = l["pos"]
		if not view.has_point(p):
			continue
		var pl := PointLight2D.new()
		pl.texture = light_tex
		pl.position = p
		pl.color = l["color"]
		pl.energy = float(l["e"]) * n * 1.8
		pl.texture_scale = float(l["r"]) * 2.0 / 256.0
		add_child(pl)
		light_nodes.append(pl)
