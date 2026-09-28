class_name Vehicle
extends CharacterBody3D
## A car on the streets. Family trucks can be driven by a player (the driver's machine moves it
## and sends it to the host with its pose) and carry crates in the back; traffic cars drive the
## lanes on the host. Everyone else interpolates.

const MODELS := {
	"truck": "res://assets/kenney/cars/truck.glb",
	"delivery": "res://assets/kenney/cars/delivery.glb",
	"sedan": "res://assets/kenney/cars/sedan.glb",
	"van": "res://assets/kenney/cars/van.glb",
	"taxi": "res://assets/kenney/cars/taxi.glb",
	"police": "res://assets/kenney/cars/police.glb",
}
const SCALE := 1.55
const MAX_SPEED := 15.0
const MAX_LOAD := 10

var world: Node
var key := ""
var kind := "truck"
var family := -1
var driver := 0          # peer id driving, 0 = parked / AI
var load := 0
var sim := false
var speed := 0.0
var steer := 0.0
var yaw := 0.0
var lane: Array = []     # traffic: loop of waypoints
var lane_i := 0
var net_pos := Vector3.ZERO
var net_yaw := 0.0
var _have := false
var _crates: Array[MeshInstance3D] = []
var _body_mat_color := Color(0, 0, 0, 0)
var _lights: Array[SpotLight3D] = []
var _engine: AudioStreamPlayer3D


func setup(w: Node, k: String, kd: String, fam_color: Color = Color(0, 0, 0, 0)) -> void:
	world = w
	key = k
	kind = kd
	name = k
	collision_layer = 4
	collision_mask = 1
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var model := (load(MODELS[kd]) as PackedScene).instantiate() as Node3D
	model.scale = Vector3.ONE * SCALE
	add_child(model)
	# 1920s: most cars were black; family trucks carry the family colour on the cab
	var tint := Color("1b1a19") if kd in ["sedan", "taxi", "van"] and randf() < 0.7 else Color(0, 0, 0, 0)
	if fam_color.a > 0.0:
		tint = fam_color.darkened(0.45)
	if tint.a > 0.0:
		for mi in model.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			for s in m.mesh.get_surface_count():
				var src := m.get_active_material(s) as BaseMaterial3D
				if src:
					var mat := src.duplicate() as BaseMaterial3D
					mat.albedo_color = tint.lerp(Color.WHITE, 0.15)
					m.set_surface_override_material(s, mat)
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(2.2, 1.8, 4.6)
	cs.shape = bx
	cs.position.y = 0.9
	add_child(cs)
	for s in [-0.55, 0.55]:
		var l := SpotLight3D.new()
		l.light_color = Color("ffe0a8")
		l.spot_range = 16.0
		l.spot_angle = 32.0
		l.light_energy = 0.0
		l.position = Vector3(s, 0.9, 2.3)
		l.rotation.x = -0.25
		l.rotation.y = PI
		add_child(l)
		_lights.append(l)
	if kd in ["truck", "delivery"]:
		for n in MAX_LOAD:
			var c := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.6, 0.42, 0.5)
			c.mesh = bm
			c.material_override = Crate.material()
			c.position = Vector3(-0.35 + (n % 2) * 0.7, 1.35 + (n / 6) * 0.44, -0.3 - (n / 2 % 3) * 0.6)
			c.visible = false
			add_child(c)
			_crates.append(c)


func place(p: Vector3, y: float) -> void:
	position = Vector3(p.x, 0.0, p.z)
	yaw = y
	rotation.y = y
	net_pos = position
	net_yaw = y


func set_load(n: int) -> void:
	load = n
	for k in _crates.size():
		_crates[k].visible = k < n


func set_night(v: float) -> void:
	for l in _lights:
		l.light_energy = v * 3.0


func forward() -> Vector3:
	return Vector3(sin(yaw), 0, cos(yaw))


## The local driver's input (throttle -1..1, turn -1..1).
func drive(delta: float, throttle: float, turn: float, brake: bool) -> void:
	var target := throttle * (MAX_SPEED if throttle > 0 else MAX_SPEED * 0.4)
	var acc := 7.0 if signf(target) == signf(speed) or absf(speed) < 0.5 else 14.0
	if brake:
		speed = move_toward(speed, 0.0, 22.0 * delta)
	else:
		speed = move_toward(speed, target, acc * delta)
	steer = move_toward(steer, turn, 3.0 * delta)
	var turn_rate := steer * clampf(absf(speed) / 5.0, 0.0, 1.0) * 1.7 * signf(speed)
	yaw += turn_rate * delta
	velocity = forward() * speed
	var hit := move_and_slide()
	if hit and get_slide_collision_count() > 0:
		speed *= 0.4
	rotation.y = yaw
	position.y = 0.0


func _physics_process(delta: float) -> void:
	if sim and driver == 0 and not lane.is_empty() and Net.is_host():
		_traffic(delta)
	elif not sim and _have:
		position = position.lerp(net_pos, clampf(delta * 10.0, 0.0, 1.0))
		if position.distance_to(net_pos) > 8.0:
			position = net_pos
		rotation.y = lerp_angle(rotation.y, net_yaw, clampf(delta * 10.0, 0.0, 1.0))
		yaw = rotation.y
	elif sim and driver == 0:
		speed = move_toward(speed, 0.0, 10.0 * delta)


func _traffic(delta: float) -> void:
	var t: Vector3 = lane[lane_i]
	var to := t - position
	to.y = 0.0
	if to.length() < 2.5:
		lane_i = (lane_i + 1) % lane.size()
		return
	var want := atan2(to.x, to.z)
	yaw = lerp_angle(yaw, want, clampf(delta * 2.5, 0.0, 1.0))
	var target := 8.0
	if world.something_ahead(self, 7.0):
		target = 0.0
	speed = move_toward(speed, target, 6.0 * delta)
	velocity = forward() * speed
	move_and_slide()
	rotation.y = yaw
	position.y = 0.0


func net_update(p: Vector3, y: float, drv: int, ld: int) -> void:
	net_pos = p
	net_yaw = y
	if not _have:
		position = p
		rotation.y = y
		_have = true
	driver = drv
	if ld != load:
		set_load(ld)
