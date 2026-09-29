class_name CarArt
extends Node2D
## A 1920s car or truck seen from above (docs/REBUILD_2D.md, "CarArt"). The node's rotation is the
## heading (0 = east, +x): everything is drawn nose-right in the car's frame. The Vehicle rotates
## this node's parent; CarArt undoes the global rotation for the shadow (down-right in world space)
## and for the side the paint catches the sun on (north-west).
##
## Drawn procedurally into cached layers (children), each redrawn only when what it shows changes:
##   shadow   on the ground: when the heading moves more than ~2 degrees, the night or the load changes
##   wheels   the chassis underneath and the tyres (the front pair turns with the steering)
##   body     fenders, running boards, hood, cabin, bed or box, and the crates on the bed. Hundreds of
##            shapes, so they are baked into a texture (a small SubViewport per car, redrawn when the
##            heading moves ~8 degrees or the load changes) and shown as one sprite
##   lamps    lit lenses, on their own canvas layer above the night lightmap so they glow
## The painting is in scripts/world2d/cars/ (CarSpec measurements, CarPaint shading,
## CarPainter chassis, CarBodies per-kind bodies).

const SIZES := {        # length, width in metres
	"truck": Vector2(5.4, 2.1), "sedan": Vector2(4.3, 1.8), "touring": Vector2(4.5, 1.8),
	"taxi": Vector2(4.3, 1.8), "police": Vector2(4.4, 1.8), "van": Vector2(4.8, 1.95),
	"delivery": Vector2(5.0, 2.0),
}
const MAX_LOAD := 10
const MAX_STEER := 0.52          # front wheel angle at full lock (radians)
const SHADOW_STEP := 0.035       # redraw the shadow when the heading moves this much (~2 degrees)
const BODY_STEP := 0.14          # re-bake the paint's highlights (~8 degrees)
const BAKE_SCALE := 2.0          # texels per pixel in the baked body (sharp up to zoom 2)

var kind := "sedan"
var body_color := Pal.CAR_BLACK
var family_color := Color(0, 0, 0, 0)
var load := 0
var night := 0.0
var speed := 0.0
var steer := 0.0
var seed_value := 0

var painter: CarPainter
var _shadow: _Layer
var _wheels: _Layer
var _body: _Layer            # draws the body (inside the bake viewport)
var _bake: SubViewport
var _sprite: Sprite2D        # shows the baked body
var _bake_rect := Rect2()    # the baked area in the car's frame, px
var _lamp_layer: CanvasLayer
var _lamps: _Layer
var _shadow_rot := INF
var _body_rot := INF
var _wheel_steer := INF
var _lamp_level := -1.0
var _lamp_head := false
var _shadow_night := -1.0
var _moving_t := 0.0             # seconds since it last moved (headlamps stay on a while)
var _t := 0.0


## One cached drawing: calls `fn(layer)` when it redraws.
class _Layer extends Node2D:
	var fn: Callable

	func _draw() -> void:
		if fn.is_valid():
			fn.call(self)


func setup(k: String, body: Color = Color(0, 0, 0, 0), fam_color: Color = Color(0, 0, 0, 0), seed_v: int = 0) -> void:
	kind = k if SIZES.has(k) else "sedan"
	family_color = fam_color
	body_color = body if body.a > 0.0 else Pal.CAR_BLACK
	seed_value = seed_v
	painter = CarPainter.new(kind, body_color, family_color, seed_value)
	_build()
	_fit_bake()
	_redraw_all()


## Length and width in metres (for collision shapes).
func size_m() -> Vector2:
	return SIZES.get(kind, Vector2(4.3, 1.8))


func set_load(n: int) -> void:
	var v := clampi(n, 0, MAX_LOAD)
	if v == load:
		return
	load = v
	if _body:
		_rebake()
		_shadow.queue_redraw()


## 0 = day, 1 = full night: headlamps and tail lamps glow on the body (the light they throw on
## the street is done by the World's light layer).
func set_lights(v: float) -> void:
	night = clampf(v, 0.0, 1.0)
	_update_lamps()
	if absf(_shadow_night - night) > 0.04 and _shadow:
		_shadow.queue_redraw()


## Called every frame while it moves: speed in m/s (negative = reversing), steer -1..1.
func set_motion(spd: float, st: float) -> void:
	speed = spd
	steer = clampf(st, -1.0, 1.0)
	if absf(speed) > 0.3:
		_moving_t = 0.0
	if _wheels and absf(steer - _wheel_steer) > 0.04:
		_wheels.queue_redraw()
	_update_lamps()


# ------------------------------------------------------------------ nodes

func _ready() -> void:
	if painter == null:
		setup(kind, body_color, family_color, seed_value)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func _build() -> void:
	if _body != null:
		return
	_shadow = _layer("Shadow", _draw_shadow)
	_wheels = _layer("Wheels", _draw_wheels)
	add_child(_shadow)
	add_child(_wheels)
	_bake = SubViewport.new()
	_bake.name = "Bake"
	_bake.transparent_bg = true
	_bake.disable_3d = true
	_bake.render_target_update_mode = SubViewport.UPDATE_ONCE
	_bake.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	_bake.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(_bake)
	_body = _layer("Body", _draw_body)
	_bake.add_child(_body)
	_sprite = Sprite2D.new()
	_sprite.name = "BodySprite"
	_sprite.centered = false
	_sprite.texture = _bake.get_texture()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	# the baked colours are already multiplied by their alpha
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	_sprite.material = mat
	add_child(_sprite)


## Size the bake to this kind: bumper to bumper, the widest fender, a margin for the soft edges.
func _fit_bake() -> void:
	var s := painter.s
	var x0 := (float(s["rbump"]) - 0.2) * W.M
	var x1 := (float(s["bump"]) + 0.2) * W.M
	var hw := 1.2 * W.M
	_bake_rect = Rect2(x0, -hw, x1 - x0, hw * 2.0)
	_bake.size = Vector2i(ceili(_bake_rect.size.x * BAKE_SCALE), ceili(_bake_rect.size.y * BAKE_SCALE))
	_body.transform = Transform2D(0.0, Vector2(BAKE_SCALE, BAKE_SCALE), 0.0, -_bake_rect.position * BAKE_SCALE)
	_sprite.scale = Vector2.ONE / BAKE_SCALE
	_sprite.position = _bake_rect.position


func _layer(n: String, f: Callable) -> _Layer:
	var l := _Layer.new()
	l.name = n
	l.fn = f
	return l


func _redraw_all() -> void:
	for l: _Layer in [_shadow, _wheels, _lamps]:
		if l:
			l.queue_redraw()
	_rebake()


func _rebake() -> void:
	_body.queue_redraw()
	_bake.render_target_update_mode = SubViewport.UPDATE_ONCE


func _grot() -> float:
	return get_global_transform().get_rotation() if is_inside_tree() else rotation


## Toward the sun (north-west) in the car's frame.
func _light(rot: float) -> Vector2:
	return GroundUtil.LIGHT_DIR.rotated(-rot)


func _process(delta: float) -> void:
	if painter == null:
		return
	var g := _grot()
	if absf(angle_difference(g, _shadow_rot)) > SHADOW_STEP:
		_shadow.queue_redraw()
	if absf(angle_difference(g, _body_rot)) > BODY_STEP:
		_body_rot = g
		_rebake()
	# the body sits on its springs: it leans out of a turn, squats a touch, hums at speed
	_t += delta
	_moving_t += delta
	var sp := absf(speed)
	var lean := clampf(steer * sp / 9.0, -1.0, 1.0) * 1.4
	var hum := 0.0
	if sp > 0.5:
		hum = sin(_t * 41.0) * 0.18 + sin(_t * 23.0) * 0.12
	var off := Vector2(-clampf(speed / 15.0, -1.0, 1.0) * 0.6 + hum, -lean + hum * 0.5)
	_sprite.position = _bake_rect.position + off
	if _lamps and _lamp_level > 0.0:
		_lamp_layer.visible = is_visible_in_tree()
		_lamps.transform = get_global_transform() * Transform2D(0.0, off)
		if _lamp_head != _head_on():
			_update_lamps()
	elif _lamps == null and night > 0.15:
		_update_lamps()


# ------------------------------------------------------------------ drawing

func _draw_shadow(ci: CanvasItem) -> void:
	_shadow_rot = _grot()
	_shadow_night = night
	var off := GroundUtil.SV.rotated(-_shadow_rot) * W.M
	painter.draw_shadow(ci, off, lerpf(1.0, 0.4, night), load)


func _draw_wheels(ci: CanvasItem) -> void:
	_wheel_steer = steer
	var L := _light(_body_rot if _body_rot != INF else _grot())
	painter.draw_wheels(ci, steer * MAX_STEER, L)


func _draw_body(ci: CanvasItem) -> void:
	if _body_rot == INF:
		_body_rot = _grot()
	var L := _light(_body_rot)
	var p := painter
	p.draw_running_boards(ci, L)
	p.draw_rear_bumper(ci, L)
	p.draw_rear_spare(ci, L)
	p.draw_fender(ci, false, L)
	p.draw_fender(ci, true, L)
	p.draw_tail_lamp(ci, L)
	CarBodies.draw_body(p, ci, L)
	p.draw_hood(ci, L)
	p.draw_radiator(ci, L)
	p.draw_headlamps(ci, L)
	p.draw_front_bumper(ci, L)
	if load > 0:
		CarBodies.draw_load(p, ci, L, load)


func _draw_lamps(ci: CanvasItem) -> void:
	painter.draw_lamps(ci, _lamp_level, _lamp_head)


# ------------------------------------------------------------------ lamps

func _head_on() -> bool:
	return night > 0.3 and _moving_t < 30.0


func _update_lamps() -> void:
	var level := clampf((night - 0.15) / 0.5, 0.0, 1.0)
	var head := _head_on()
	if level <= 0.0:
		if _lamp_layer:
			_lamp_layer.visible = false
		_lamp_level = 0.0
		return
	if _lamp_layer == null:
		if not is_inside_tree():
			return
		# above the lightmap (it would darken the lit lenses) and below the weather
		_lamp_layer = CanvasLayer.new()
		_lamp_layer.name = "Lamps"
		_lamp_layer.layer = W.LAYER_ROOFS
		_lamp_layer.follow_viewport_enabled = true
		add_child(_lamp_layer)
		_lamps = _layer("LampGlow", _draw_lamps)
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_lamps.material = mat
		_lamps.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_lamp_layer.add_child(_lamps)
	_lamp_layer.visible = is_visible_in_tree()
	_lamps.transform = get_global_transform()
	if absf(level - _lamp_level) > 0.03 or head != _lamp_head:
		_lamp_level = level
		_lamp_head = head
		_lamps.queue_redraw()
