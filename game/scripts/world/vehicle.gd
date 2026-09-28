class_name Vehicle
extends CharacterBody3D
## A car on the streets. Family trucks can be driven by a player (the driver's machine moves it
## and sends it to the host with its pose) and carry crates in the back; traffic cars drive the
## lanes on the host. Everyone else interpolates.

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
var _wheels: Array[Node3D] = []       # spinning wheel meshes
var _steer_pivots: Array[Node3D] = []
var _wheel_r := 0.35
var _wheel_ang := 0.0
var _vis_steer := 0.0
var _last_pos := Vector3.ZERO
var _last_yaw := 0.0
var _body: MeshInstance3D


func setup(w: Node, k: String, kd: String, fam_color: Color = Color(0, 0, 0, 0)) -> void:
	world = w
	key = k
	kind = kd
	name = k
	collision_layer = 4
	collision_mask = 1
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var sp := CarModels.spec(kd)
	_body = MeshInstance3D.new()
	_body.name = "Body"
	_body.mesh = CarModels.body(kd)
	add_child(_body)
	# 1920s: most private cars were black; family trucks carry the family colour on the cab
	var tint := Color("1c1d20")
	match kd:
		"sedan":
			var pal := [Color("1c1d20"), Color("1c1d20"), Color("1c1d20"), Color("3a1a18"), Color("1f2a3a"), Color("26382c"),
				Color("3b3226"), Color("4a4f55")]
			tint = pal[randi() % pal.size()]
		"taxi":
			tint = Color("c89a2e")
		"van":
			var vp := [Color("6b2320"), Color("2f4a38"), Color("c9b98f"), Color("2b3a55")]
			tint = vp[randi() % vp.size()]
		"delivery":
			tint = Color("3c4a36")
		"police":
			tint = Color("1e2428")
	if fam_color.a > 0.0:
		tint = fam_color.darkened(0.35)
	var ps := CarModels.paint_surface(kd)
	if ps >= 0:
		_body.set_surface_override_material(ps, CarModels.paint(tint))
	for wh in sp["wheels"]:
		var pivot := Node3D.new()
		pivot.position = wh[0]
		add_child(pivot)
		var wm := MeshInstance3D.new()
		wm.mesh = CarModels.wheel(sp["wheel"], wh[1])
		if (wh[0] as Vector3).x < 0.0:
			wm.rotation.y = PI
		var spin := Node3D.new()
		spin.add_child(wm)
		pivot.add_child(spin)
		_wheels.append(spin)
		if wh[2]:
			_steer_pivots.append(pivot)
		_wheel_r = wh[1]
	if kd == "police":
		for s in [1.0, -1.0]:
			var l := Label3D.new()
			l.text = "POLICE"
			l.font = load("res://assets/fonts/signs/AlfaSlabOne-Regular.ttf")
			l.font_size = 48
			l.pixel_size = 0.0045
			l.outline_size = 0
			l.modulate = Color("e8e0c8")
			l.shaded = true
			l.double_sided = false
			l.position = Vector3(s * 0.85, 1.52, -0.7)
			l.rotation.y = PI * 0.5 * s
			add_child(l)
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(float(sp["width"]) + 0.2, 1.8, float(sp["length"]))
	cs.shape = bx
	cs.position.y = 0.9
	add_child(cs)
	for lp in sp["lamps"]:
		var l := SpotLight3D.new()
		l.light_color = Color("ffe0a8")
		l.spot_range = 16.0
		l.spot_angle = 32.0
		l.light_energy = 0.0
		l.position = lp + Vector3(0, 0, 0.12)
		l.rotation.y = PI
		l.rotation.x = -0.22
		add_child(l)
		_lights.append(l)
	if kd in ["truck", "delivery"]:
		for n in MAX_LOAD:
			var c := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.6, 0.42, 0.5)
			c.mesh = bm
			c.material_override = Crate.material()
			c.position = Vector3(-0.35 + (n % 2) * 0.7, float(sp["bed_y"]) + 0.215 + (n / 6) * 0.44, -0.5 - (n / 2 % 3) * 0.66)
			c.rotation.y = (randf() - 0.5) * 0.12
			c.visible = false
			add_child(c)
			_crates.append(c)


func place(p: Vector3, y: float) -> void:
	position = Vector3(p.x, 0.0, p.z)
	_last_pos = position
	_last_yaw = y
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
		l.visible = v > 0.05
	CarModels.set_night(v)


func _process(delta: float) -> void:
	# wheels turn with the distance actually covered, front wheels follow the turn
	var moved := position - _last_pos
	moved.y = 0.0
	var fwd := Vector3(sin(rotation.y), 0, cos(rotation.y))
	var d := moved.dot(fwd)
	if moved.length() > 6.0:
		d = 0.0
	_wheel_ang = fmod(_wheel_ang + d / _wheel_r, TAU)
	for w in _wheels:
		w.rotation.x = _wheel_ang
	var dyaw := wrapf(rotation.y - _last_yaw, -PI, PI)
	var want := 0.0
	if absf(d) > 0.01:
		want = clampf(dyaw / d * 2.6, -0.5, 0.5)
	elif driver != 0:
		want = steer * 0.45
	_vis_steer = lerpf(_vis_steer, want, clampf(delta * 8.0, 0.0, 1.0))
	for p in _steer_pivots:
		p.rotation.y = _vis_steer
	_last_pos = position
	_last_yaw = rotation.y


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
