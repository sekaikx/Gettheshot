class_name Lighting
extends Node
## Night light for the street. A small SubViewport renders a lightmap (the ambient colour plus a
## soft glow for every lamp, lit window and headlight), and a full-screen overlay on its own
## canvas layer multiplies it onto the world (W.LAYER_LIGHT). Roofs sit on a layer above, so the
## street lamps light the street and not the roofs. In daylight the overlay switches off.
##
## Lights are data: {"pos", "r", "color", "e", "shape": "round"|"rect"|"cone", "size", "rot", "flicker"}
## (see docs/REBUILD_2D.md). Static ones come from the city pieces' lights(); dynamic ones (cars'
## headlamps, muzzle flashes) are added and moved by the World.

const SCALE := 0.5       # lightmap resolution relative to the screen

static var _tex := {}

var world: Node2D
var svp: SubViewport
var lm_cam: Camera2D
var ambient: Polygon2D
var layer: CanvasLayer
var overlay: TextureRect
var night := 0.0
var _root: Node2D
var _flicker: Array = []
var _dyn := {}
var _flash: Array = []
var _t := 0.0
var _active := true
var disabled := false     # the 3D view does the night light: this one stays off


func setup(w: Node2D) -> void:
	world = w
	svp = SubViewport.new()
	svp.world_2d = World2D.new()
	svp.transparent_bg = false
	svp.disable_3d = true
	svp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	svp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
	add_child(svp)
	ambient = Polygon2D.new()
	var big := 1.0e6
	ambient.polygon = PackedVector2Array([Vector2(-big, -big), Vector2(big, -big), Vector2(big, big), Vector2(-big, big)])
	ambient.color = Color.WHITE
	svp.add_child(ambient)
	_root = Node2D.new()
	svp.add_child(_root)
	lm_cam = Camera2D.new()
	svp.add_child(lm_cam)
	lm_cam.make_current()
	layer = CanvasLayer.new()
	layer.layer = W.LAYER_LIGHT
	add_child(layer)
	overlay = TextureRect.new()
	overlay.texture = svp.get_texture()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.stretch_mode = TextureRect.STRETCH_SCALE
	overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mul := CanvasItemMaterial.new()
	mul.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	overlay.material = mul
	layer.add_child(overlay)
	_resize()
	w.get_viewport().size_changed.connect(_resize)


func _resize() -> void:
	var vs := world.get_viewport().get_visible_rect().size
	svp.size = Vector2i(maxi(64, int(vs.x * SCALE)), maxi(64, int(vs.y * SCALE)))


## Add a batch of static lights (from CityGround / Shopfronts / InteriorArt .lights()).
func add_static(lights: Array) -> void:
	for l in lights:
		var s := _sprite(l)
		_root.add_child(s)
		if bool(l.get("flicker", false)):
			_flicker.append([s, s.modulate, Draw.hash01(int(s.position.x), int(s.position.y)) * TAU])


func clear_static() -> void:
	var keep := {}
	for s in _dyn.values():
		keep[s] = true
	for c in _root.get_children():
		if not keep.has(c):
			c.queue_free()
	_flicker.clear()


## A light that moves or changes (headlamps, a lantern): create or update it by id.
func set_dynamic(id: String, l: Dictionary) -> void:
	var s: Sprite2D = _dyn.get(id)
	if s == null:
		s = _sprite(l)
		_root.add_child(s)
		_dyn[id] = s
	else:
		s.position = l["pos"]
		s.rotation = float(l.get("rot", 0.0))
		s.modulate = _mod(l)
		s.visible = true


func hide_dynamic(id: String) -> void:
	if _dyn.has(id):
		(_dyn[id] as Sprite2D).visible = false


func remove_dynamic(id: String) -> void:
	if _dyn.has(id):
		(_dyn[id] as Sprite2D).queue_free()
		_dyn.erase(id)


## A brief flash (a gunshot): lights up even in daylight shade, fades in `t` seconds.
func flash(pos: Vector2, r: float, color: Color, t: float = 0.12) -> void:
	if disabled:
		return
	var s := _sprite({"pos": pos, "r": r, "color": color, "e": 1.5})
	_root.add_child(s)
	_flash.append([s, t, t])


## The 3D view lights the street itself: switch the 2D lightmap off for good.
func disable() -> void:
	disabled = true
	_active = false
	layer.visible = false
	svp.render_target_update_mode = SubViewport.UPDATE_DISABLED


## night 0..1, dusk 0..1 (the orange hour either side of night).
func set_level(n: float, dusk: float) -> void:
	night = n
	if disabled:
		return
	var amb := Color.WHITE.lerp(Color(1.0, 0.8, 0.64), dusk * (1.0 - n)).lerp(Pal.NIGHT_AMBIENT, n)
	ambient.color = amb
	_root.modulate = Color(1, 1, 1, clampf(n * 1.2, 0.0, 1.0))
	var want := n > 0.02 or dusk > 0.05 or not _flash.is_empty()
	if want != _active:
		_active = want
		layer.visible = want
		svp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if want else SubViewport.UPDATE_DISABLED


func _process(delta: float) -> void:
	if disabled:
		return
	_t += delta
	var cam := world.get_viewport().get_camera_2d()
	if cam:
		var vs := world.get_viewport().get_visible_rect().size
		lm_cam.global_position = cam.get_screen_center_position()
		lm_cam.zoom = cam.zoom * (float(svp.size.x) / vs.x)
	for f in _flicker:
		var s: Sprite2D = f[0]
		var base: Color = f[1]
		var k := 0.82 + 0.18 * sin(_t * 9.0 + float(f[2])) * sin(_t * 23.0 + float(f[2]) * 2.0)
		if Draw.hash01(int(_t * 6.0), int(f[2] * 100.0)) > 0.97:
			k = 0.3
		s.modulate = Color(base.r * k, base.g * k, base.b * k, 1.0)
	for i in range(_flash.size() - 1, -1, -1):
		var fl: Array = _flash[i]
		fl[1] = float(fl[1]) - delta
		var sp: Sprite2D = fl[0]
		if float(fl[1]) <= 0.0:
			sp.queue_free()
			_flash.remove_at(i)
		else:
			sp.modulate.a = float(fl[1]) / float(fl[2])
	if not _flash.is_empty() and not _active:
		set_level(night, 0.0)


func _sprite(l: Dictionary) -> Sprite2D:
	var s := Sprite2D.new()
	var shape := String(l.get("shape", "round"))
	var r := float(l.get("r", 5.0 * W.M))
	var tex := _texture(shape)
	s.texture = tex
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	s.material = add
	s.position = l["pos"]
	match shape:
		"rect":
			var sz: Vector2 = l.get("size", Vector2(r, r))
			s.scale = sz / Vector2(tex.get_size())
		"cone":
			s.centered = false
			s.offset = Vector2(0, -tex.get_height() * 0.5)
			s.scale = Vector2.ONE * (r / tex.get_width())
			s.rotation = float(l.get("rot", 0.0))
		_:
			s.scale = Vector2.ONE * (r * 2.0 / tex.get_width())
	s.modulate = _mod(l)
	return s


static func _mod(l: Dictionary) -> Color:
	var c: Color = l.get("color", Pal.LAMP)
	var e := float(l.get("e", 1.0))
	return Color(c.r * e, c.g * e, c.b * e, 1.0)


static func _texture(shape: String) -> Texture2D:
	if _tex.has(shape):
		return _tex[shape]
	var t: Texture2D
	match shape:
		"rect":
			var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
			for y in 64:
				for x in 64:
					var dx := minf(x + 0.5, 64.0 - x - 0.5) / 20.0
					var dy := minf(y + 0.5, 64.0 - y - 0.5) / 20.0
					var a := clampf(minf(dx, dy), 0.0, 1.0)
					a = a * a * (3.0 - 2.0 * a)
					img.set_pixel(x, y, Color(1, 1, 1, a))
			t = ImageTexture.create_from_image(img)
		"cone":
			var img := Image.create(128, 96, false, Image.FORMAT_RGBA8)
			for y in 96:
				for x in 128:
					var p := Vector2(x + 0.5, y + 0.5 - 48.0)
					var d := p.length() / 128.0
					var ang := absf(p.angle())
					var edge := clampf((0.42 - ang) / 0.18, 0.0, 1.0)
					var a := clampf(1.0 - d, 0.0, 1.0) * edge * clampf(p.x / 10.0, 0.0, 1.0)
					img.set_pixel(x, y, Color(1, 1, 1, a * a))
			t = ImageTexture.create_from_image(img)
		_:
			var g := Gradient.new()
			g.offsets = PackedFloat32Array([0.0, 0.25, 0.6, 1.0])
			g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.72), Color(1, 1, 1, 0.22), Color(1, 1, 1, 0)])
			var gt := GradientTexture2D.new()
			gt.gradient = g
			gt.fill = GradientTexture2D.FILL_RADIAL
			gt.fill_from = Vector2(0.5, 0.5)
			gt.fill_to = Vector2(1.0, 0.5)
			gt.width = 128
			gt.height = 128
			t = gt
	_tex[shape] = t
	return t
