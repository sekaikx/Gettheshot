extends Node2D
## Test sheets for CarArt (1920s vehicles from above). Lays every kind out on a street, points the
## camera at it, saves PNGs and quits.
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --rendering-driver opengl3 --path game res://tools/test/test_cars.tscn
## Env: OUT_DIR=dir (default /tmp), SHOTS=z10,z16,night,close (default: all), bench on request.

const KINDS := ["sedan", "touring", "taxi", "police", "van", "delivery", "truck"]
const FAMILY := Color("#c42828")

var out_dir := "/tmp"
var cam: Camera2D
var night: CanvasModulate


class Ground extends Node2D:
	var rect := Rect2()

	func _draw() -> void:
		Draw.rect(self, rect, Pal.ASPHALT)
		# worn patches and tar seams, so the cars sit on something like the real street
		for i in 70:
			var c := rect.position + Vector2(Draw.hash01(i, 1, 3), Draw.hash01(i, 2, 3)) * rect.size
			Draw.ellipse(self, c, Vector2(40 + 90 * Draw.hash01(i, 3, 3), 20 + 40 * Draw.hash01(i, 4, 3)), Color(Pal.ASPHALT_WORN, 0.5))
		var y := rect.position.y + 160.0
		while y < rect.end.y:
			draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), Color(0.15, 0.15, 0.16, 0.5), 2.0)
			y += 330.0
		var sw := Rect2(rect.position, Vector2(rect.size.x, 70))
		Draw.rect(self, sw, Pal.SIDEWALK)
		Draw.rect(self, Rect2(sw.position + Vector2(0, 64), Vector2(sw.size.x, 7)), Pal.CURB)
		Draw.rect(self, Rect2(sw.position + Vector2(0, 71), Vector2(sw.size.x, 5)), Pal.GUTTER)


class Tag extends Node2D:
	var text := ""
	var size := 11

	func _draw() -> void:
		Draw.text(self, Vector2.ZERO, text, size, Pal.INK, W.font("cond"), HORIZONTAL_ALIGNMENT_CENTER, -1.0, 3, Color(0.05, 0.04, 0.03, 0.9))


func _ready() -> void:
	Game.new_campaign({"seed": 1923, "families": 4}, [{"peer": 1, "name": "Alex", "family_name": "Vitale", "color": "#c42828"}])
	Game.running = false
	if OS.get_environment("OUT_DIR") != "":
		out_dir = OS.get_environment("OUT_DIR")
	var want := OS.get_environment("SHOTS")
	var shots := ["z10", "z16", "night", "close"]
	if want != "":
		shots = Array(want.split(","))
	cam = Camera2D.new()
	add_child(cam)
	night = CanvasModulate.new()
	night.color = Color.WHITE
	add_child(night)
	for s in shots:
		match s:
			"z10": await _sheet(1.0, "cars_z10", false)
			"z16": await _sheet(1.6, "cars_z16", false)
			"night": await _sheet(1.0, "cars_night", true)
			"close": await _close()
			"bench": await _bench()
	get_tree().quit()


func _body_for(k: String, i: int) -> Color:
	if k in ["sedan", "touring", "van"]:
		return [Pal.CAR_BLACK, Color("2a3a2e"), Color("3a2226"), Color("232a3a"), Pal.CAR_BLACK][i % 5]
	return Color(0, 0, 0, 0)


func _car(parent: Node, k: String, pos: Vector2, rot: float, i: int, ld: int = 0, st: float = 0.0, spd: float = 0.0) -> CarArt:
	# the way Vehicle does it: a rotated parent, CarArt set up and then added
	var holder := Node2D.new()
	holder.position = pos
	holder.rotation = rot
	holder.z_index = W.Z_CARS
	var a := CarArt.new()
	a.setup(k, _body_for(k, i), FAMILY if k == "truck" else Color(0, 0, 0, 0), i)
	holder.add_child(a)
	parent.add_child(holder)
	a.set_load(ld)
	a.set_motion(spd, st)
	return a


func _tag(parent: Node, text: String, pos: Vector2, size: int = 11) -> void:
	var t := Tag.new()
	t.text = text
	t.size = size
	t.position = pos
	t.z_index = 50
	parent.add_child(t)


func _group(origin: Vector2, r: Rect2) -> Node2D:
	var g := Node2D.new()
	g.position = origin
	add_child(g)
	var gr := Ground.new()
	gr.rect = r
	gr.z_index = W.Z_GROUND
	g.add_child(gr)
	return g


func _snap(center: Vector2, zoom: float, shot: String) -> void:
	cam.position = center
	cam.zoom = Vector2(zoom, zoom)
	for i in 8:
		await get_tree().process_frame
	var path := out_dir.path_join(shot + ".png")
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)


func _clear(g: Node) -> void:
	g.queue_free()
	await get_tree().process_frame


## Every kind side by side: nose east and turned 35 degrees; trucks with 0, 5 and 10 crates;
## the delivery trucks' trades. At night: lamps lit, wheels steered.
func _sheet(zoom: float, shot: String, dark: bool) -> void:
	var view := Vector2(1600, 900) / zoom
	var g := _group(Vector2.ZERO, Rect2(-view * 0.5 - Vector2(60, 60), view + Vector2(120, 120)))
	var cars: Array = []
	if zoom < 1.3:
		var top := -view.y * 0.5 + 150.0
		# row 1: the cars, nose east
		var row1 := ["sedan", "touring", "taxi", "police", "van"]
		for i in row1.size():
			var x := -620.0 + i * 300.0
			cars.append(_car(g, row1[i], Vector2(x, top), 0.0, i, 0, 0.6 if dark else 0.0, 6.0 if dark else 0.0))
			_tag(g, row1[i], Vector2(x, top + 70))
		# row 2: box trucks with two trades, the family truck empty, half, full
		var y2 := top + 170.0
		var row2 := [["delivery", 0, 0], ["delivery", 3, 0], ["truck", 0, 0], ["truck", 1, 5], ["truck", 2, 10]]
		for i in row2.size():
			var x := -620.0 + i * 300.0
			var it: Array = row2[i]
			cars.append(_car(g, it[0], Vector2(x, y2), 0.0, it[1], it[2], -0.7 if dark else 0.0, 6.0 if dark else 0.0))
			_tag(g, "%s %s" % [it[0], ("x%d" % it[2]) if it[0] == "truck" else CarSpec.trade_for(it[1])], Vector2(x, y2 + 76))
		# row 3: all seven turned 35 degrees
		var y3 := y2 + 230.0
		for i in KINDS.size():
			var x := -660.0 + i * 220.0
			var ld := 10 if KINDS[i] == "truck" else 0
			cars.append(_car(g, KINDS[i], Vector2(x, y3), deg_to_rad(35.0), i + 4, ld, 1.0 if i % 2 == 0 else 0.0, 5.0))
		# row 4: other headings (the light must stay north-west)
		var y4 := y3 + 190.0
		var back := [["truck", 7, 155.0], ["sedan", 1, 200.0], ["taxi", 2, -120.0], ["delivery", 4, -35.0], ["touring", 3, 90.0], ["police", 5, -90.0]]
		for i in back.size():
			var it: Array = back[i]
			cars.append(_car(g, it[0], Vector2(-620.0 + i * 250.0, y4), deg_to_rad(it[2]), it[1], 7 if it[0] == "truck" else 0, -1.0, 4.0))
	else:
		var top := -view.y * 0.5 + 105.0
		var row1 := ["sedan", "touring", "taxi", "police"]
		for i in row1.size():
			var x := -370.0 + i * 245.0
			cars.append(_car(g, row1[i], Vector2(x, top), 0.0, i, 0))
		var y2 := top + 150.0
		cars.append(_car(g, "van", Vector2(-360.0, y2), 0.0, 1, 0))
		cars.append(_car(g, "delivery", Vector2(-50.0, y2), 0.0, 4, 0))
		cars.append(_car(g, "truck", Vector2(290.0, y2), 0.0, 2, 10))
		var y3 := y2 + 180.0
		cars.append(_car(g, "truck", Vector2(-330.0, y3), deg_to_rad(35.0), 3, 5, 1.0, 5.0))
		cars.append(_car(g, "delivery", Vector2(-20.0, y3), deg_to_rad(-35.0), 1, 0, -1.0, 5.0))
		cars.append(_car(g, "touring", Vector2(300.0, y3), deg_to_rad(215.0), 6, 0, 0.5, 5.0))
	if dark:
		night.color = Color(0.3, 0.32, 0.48)
		for c: CarArt in cars:
			c.set_lights(1.0)
	await _snap(Vector2.ZERO, zoom, shot)
	night.color = Color.WHITE
	await _clear(g)


## A few up close to judge the drawing itself.
func _close() -> void:
	var g := _group(Vector2(0, 6000), Rect2(-500, -300, 1000, 600))
	_car(g, "sedan", Vector2(-140, -80), 0.0, 0)
	_car(g, "touring", Vector2(140, -80), 0.0, 3)
	_car(g, "truck", Vector2(-140, 80), 0.0, 2, 10, 1.0)
	_car(g, "taxi", Vector2(140, 80), 0.0, 2, 0, -1.0)
	_car(g, "police", Vector2(380, 0), deg_to_rad(-60.0), 5, 0, 0.8, 4.0)
	await _snap(Vector2(60, 6000), 2.6, "cars_close")
	await _clear(g)


## Frame time with 15 cars turning (redraws of shadow and paint).
func _bench() -> void:
	var g := _group(Vector2(0, 12000), Rect2(-900, -500, 1800, 1000))
	var holders: Array = []
	var n := int(OS.get_environment("BENCH_N")) if OS.get_environment("BENCH_N") != "" else 15
	for i in n:
		var a := _car(g, KINDS[i % KINDS.size()], Vector2(-700 + (i % 5) * 350, -300 + (i / 5) * 300), 0.0, i, i % 11, 0.5, 8.0)
		holders.append(a.get_parent())
	cam.position = Vector2(0, 12000)
	cam.zoom = Vector2.ONE
	for f in 90:
		await get_tree().process_frame
	# standing still: only drawing the cached layers
	var t0 := Time.get_ticks_usec()
	for f in 60:
		await get_tree().process_frame
	var still := (Time.get_ticks_usec() - t0) / 1000.0 / 60.0
	# what each layer costs to show (hidden one at a time)
	var parts := ""
	for layer_name in ["Shadow", "Wheels", "BodySprite"]:
		for h: Node2D in holders:
			(h.get_child(0).get_node(layer_name) as CanvasItem).visible = false
		for f in 5:
			await get_tree().process_frame
		var t1 := Time.get_ticks_usec()
		for f in 40:
			await get_tree().process_frame
		parts += " without %s %.2f ms %d calls %d prims," % [layer_name, (Time.get_ticks_usec() - t1) / 1000.0 / 40.0,
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)]
		for h: Node2D in holders:
			(h.get_child(0).get_node(layer_name) as CanvasItem).visible = true
	print("BENCH parts:", parts, " all: %d calls %d prims" % [RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])
	# all turning and steering at once: shadows, paint and wheels redraw
	t0 = Time.get_ticks_usec()
	var frames := 120
	for f in frames:
		for h: Node2D in holders:
			h.rotation += 0.02
			(h.get_child(0) as CarArt).set_motion(8.0, sin(f * 0.1))
		await get_tree().process_frame
	print("BENCH cars: still %.2f ms/frame, all turning %.2f ms/frame" % [still, (Time.get_ticks_usec() - t0) / 1000.0 / frames])
	await _clear(g)
