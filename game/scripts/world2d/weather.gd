class_name Weather
extends CanvasLayer
## Rain, fog and lightning over the street (screen space, W.LAYER_WEATHER). Splashes on the
## ground are drawn in the world, around the camera.

var world: Node2D
var kind := "clear"      # clear, rain, fog
var night := 0.0
var _rain: Node2D
var _fog: TextureRect
var _flash: ColorRect
var _drops: Array = []
var _splashes: Node2D
var _t := 0.0
var _flash_t := 0.0


func setup(w: Node2D) -> void:
	world = w
	layer = W.LAYER_WEATHER
	_fog = TextureRect.new()
	var noise := FastNoiseLite.new()
	noise.frequency = 0.004
	noise.fractal_octaves = 3
	var nt := NoiseTexture2D.new()
	nt.noise = noise
	nt.width = 512
	nt.height = 512
	nt.seamless = true
	_fog.texture = nt
	_fog.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fog.stretch_mode = TextureRect.STRETCH_TILE
	_fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fog.modulate = Color(0.8, 0.82, 0.88, 0.0)
	add_child(_fog)
	_rain = Node2D.new()
	_rain.draw.connect(_draw_rain)
	add_child(_rain)
	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(0.85, 0.9, 1.0, 0.0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	_splashes = Node2D.new()
	_splashes.z_index = W.Z_ITEMS
	_splashes.draw.connect(_draw_splashes)
	w.add_child(_splashes)
	var r := W.rng(4242)
	for k in 420:
		_drops.append([r.randf(), r.randf(), r.randf_range(0.7, 1.3)])


func set_kind(k: String) -> void:
	kind = k


func set_night(n: float) -> void:
	night = n


func lightning() -> void:
	_flash_t = 0.35


func _process(delta: float) -> void:
	_t += delta
	var fog_a := 0.0
	if kind == "fog":
		fog_a = 0.32
	elif kind == "rain":
		fog_a = 0.1
	_fog.modulate.a = lerpf(_fog.modulate.a, fog_a * lerpf(1.0, 0.7, night), clampf(delta, 0.0, 1.0))
	_fog.modulate = Color(Color(0.82, 0.84, 0.9).lerp(Color(0.25, 0.28, 0.4), night), _fog.modulate.a)
	if _fog.modulate.a > 0.01:
		var cam := world.get_viewport().get_camera_2d()
		if cam:
			_fog.position = -Vector2(fposmod(cam.get_screen_center_position().x * 0.5 + _t * 12.0, 512.0), fposmod(cam.get_screen_center_position().y * 0.5 + _t * 5.0, 512.0))
			_fog.size = world.get_viewport().get_visible_rect().size + Vector2(1024, 1024)
	if _flash_t > 0.0:
		_flash_t -= delta
		var k := _flash_t / 0.35
		_flash.color.a = 0.55 * k * (1.0 if fmod(_flash_t, 0.12) > 0.05 else 0.4)
	else:
		_flash.color.a = 0.0
	if kind == "rain":
		_rain.queue_redraw()
		_splashes.queue_redraw()
	elif _rain.visible:
		_rain.queue_redraw()
		_splashes.queue_redraw()
	_rain.visible = kind == "rain"


func _draw_rain() -> void:
	if kind != "rain":
		return
	var vs := world.get_viewport().get_visible_rect().size
	var col := Color(0.75, 0.8, 0.9, 0.35).lerp(Color(0.6, 0.68, 0.85, 0.3), night)
	var fall := Vector2(0.18, 1.0).normalized()
	for d in _drops:
		var sp: float = d[2]
		var y := fposmod(float(d[1]) * vs.y + _t * 1100.0 * sp, vs.y + 60.0) - 30.0
		var x := fposmod(float(d[0]) * vs.x + y * 0.18, vs.x)
		var p := Vector2(x, y)
		_rain.draw_line(p, p + fall * 22.0 * sp, col, 1.2)


func _draw_splashes() -> void:
	if kind != "rain":
		return
	var cam := world.get_viewport().get_camera_2d()
	if cam == null:
		return
	var c := cam.get_screen_center_position()
	var half := world.get_viewport().get_visible_rect().size * 0.5 / cam.zoom
	var col := Color(0.8, 0.85, 0.95, 0.35)
	for k in 90:
		var seed_t := int(_t * 4.0) + k * 13
		var ph := fposmod(_t * 4.0 + k * 0.37, 1.0)
		var p := c + Vector2((Draw.hash01(seed_t, k, 1) - 0.5) * 2.0 * half.x, (Draw.hash01(seed_t, k, 2) - 0.5) * 2.0 * half.y)
		_splashes.draw_arc(p, 2.0 + ph * 7.0, 0, TAU, 12, Color(col, col.a * (1.0 - ph)), 1.0)
