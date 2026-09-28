class_name CameraRig
extends Camera2D
## The camera straight above: follows your boss (or the truck you drive, looking ahead). Scroll
## to zoom. Zooms in a little when you're inside a building, out a little when you drive fast.
## Shakes on gunshots and punches nearby.

const ZOOM_MIN := 0.45
const ZOOM_MAX := 1.7

var target: Node2D
var user_zoom := 1.15
var inside := false
var _shake := 0.0
var _focus := Vector2.ZERO


func _ready() -> void:
	position_smoothing_enabled = false
	zoom = Vector2.ONE * user_zoom
	make_current()


func snap() -> void:
	if target:
		_focus = target.global_position
		global_position = _focus


func focus_point() -> Vector2:
	return _focus


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			user_zoom = minf(ZOOM_MAX, user_zoom * 1.1)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			user_zoom = maxf(ZOOM_MIN, user_zoom / 1.1)
	elif e is InputEventKey and (e as InputEventKey).pressed:
		var k := (e as InputEventKey).keycode
		if k == KEY_EQUAL or k == KEY_KP_ADD:
			user_zoom = minf(ZOOM_MAX, user_zoom * 1.1)
		elif k == KEY_MINUS or k == KEY_KP_SUBTRACT:
			user_zoom = maxf(ZOOM_MIN, user_zoom / 1.1)


func _process(delta: float) -> void:
	var want := user_zoom
	if target and is_instance_valid(target):
		var t := target.global_position
		if target is Vehicle:
			var v := target as Vehicle
			t += v.forward() * clampf(v.speed * 0.45, -2.0 * W.M, 7.0 * W.M)
			want *= lerpf(1.0, 0.8, clampf(absf(v.speed) / Vehicle.MAX_SPEED, 0.0, 1.0))
		elif inside:
			want *= 1.2
		_focus = _focus.lerp(t, clampf(delta * 7.0, 0.0, 1.0))
	var z := lerpf(zoom.x, want, clampf(delta * 4.0, 0.0, 1.0))
	zoom = Vector2(z, z)
	var off := Vector2.ZERO
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 3.0)
		off = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake * 10.0
	global_position = _focus + off
