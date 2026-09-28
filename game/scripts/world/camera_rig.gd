class_name CameraRig
extends Node3D
## The top-down camera: follows your boss (or the truck you drive) at a fixed tilt. Scroll to zoom,
## Z / C to turn it 45 degrees, hold the middle mouse button and drag to turn it freely.

var camera: Camera3D
var target: Node3D
var yaw := 0.0
var yaw_goal := 0.0
var dist := 17.0
var dist_goal := 17.0
var pitch := deg_to_rad(56.0)
var _focus := Vector3.ZERO
var _drag := false


func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = 42.0
	camera.far = 400.0
	add_child(camera)
	camera.current = true


func snap() -> void:
	if target:
		_focus = target.global_position
	_place()


func focus_point() -> Vector3:
	return _focus


func turn(steps: int) -> void:
	yaw_goal += steps * PI * 0.25


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			dist_goal = maxf(10.0, dist_goal * 0.88)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			dist_goal = minf(75.0, dist_goal * 1.13)
		elif mb.button_index == MOUSE_BUTTON_MIDDLE or mb.button_index == MOUSE_BUTTON_RIGHT:
			_drag = mb.pressed
	elif e is InputEventMouseMotion and _drag:
		yaw_goal -= (e as InputEventMouseMotion).relative.x * 0.006
		yaw = yaw_goal


func _process(delta: float) -> void:
	if target and is_instance_valid(target):
		var t := target.global_position
		if target is Vehicle:
			t += (target as Vehicle).forward() * clampf((target as Vehicle).speed * 0.35, 0.0, 6.0)
		_focus = _focus.lerp(t, clampf(delta * 6.0, 0.0, 1.0))
	yaw = lerp_angle(yaw, yaw_goal, clampf(delta * 8.0, 0.0, 1.0))
	dist = lerpf(dist, dist_goal, clampf(delta * 6.0, 0.0, 1.0))
	_place()


func _place() -> void:
	var off := Vector3(sin(yaw), 0, cos(yaw)) * cos(pitch) * dist + Vector3(0, sin(pitch) * dist, 0)
	camera.global_position = _focus + off
	camera.look_at(_focus + Vector3(0, 1.0, 0), Vector3.UP)


## Screen-relative movement: forward on the stick = away from the camera.
func flat_basis() -> Basis:
	return Basis(Vector3.UP, yaw + PI)
