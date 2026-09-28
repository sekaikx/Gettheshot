class_name Vehicle
extends CharacterBody2D
## A car on the streets. Family trucks can be driven by a player (the driver's machine moves it
## and sends it to the host with its pose) and carry crates in the back; traffic cars drive the
## lanes on the host. Everyone else interpolates. The node's rotation is its heading (0 = east).

const MAX_SPEED := 15.0 * W.M
const MAX_LOAD := 10

var world: Node
var key := ""
var kind := "truck"
var family := -1
var driver := 0          # peer id driving, 0 = parked / AI
var load := 0
var sim := false
var speed := 0.0         # px/s along the heading
var steer := 0.0
var yaw := 0.0
var lane: Array = []     # traffic: loop of waypoints (px)
var lane_i := 0
var art: CarArt
var net_pos := Vector2.ZERO
var net_yaw := 0.0
var _have := false
var _art_t := 0.0


func setup(w: Node, k: String, kd: String, fam_color: Color = Color(0, 0, 0, 0)) -> void:
	world = w
	key = k
	kind = kd
	name = k
	z_index = W.Z_CARS
	collision_layer = 4
	collision_mask = 1 | 4
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	art = CarArt.new()
	var seed_value := k.hash()
	var body := Color(0, 0, 0, 0)
	if kd in ["sedan", "touring", "van"]:
		var r := W.rng(seed_value)
		body = [Pal.CAR_BLACK, Pal.CAR_BLACK, Pal.CAR_BLACK, Color("2a3a2e"), Color("3a2226"), Color("232a3a"), Color("4a4238")][r.randi_range(0, 6)]
	art.setup(kd, body, fam_color, seed_value)
	add_child(art)
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	var sz := art.size_m() * W.M
	rs.size = sz * Vector2(0.96, 0.92)
	cs.shape = rs
	add_child(cs)


func max_load() -> int:
	if family >= 0 and Rackets.has_ring(family, "tools"):
		return 16
	return MAX_LOAD


func place(p: Vector2, y: float) -> void:
	position = p
	yaw = y
	rotation = y
	net_pos = position
	net_yaw = y


func set_load(n: int) -> void:
	load = n
	art.set_load(mini(n, CarArt.MAX_LOAD))


func set_night(v: float) -> void:
	art.set_lights(v)


func forward() -> Vector2:
	return Vector2.from_angle(yaw)


## The local driver's input (throttle -1..1, turn -1..1: +1 = right, i.e. clockwise on screen).
func drive(delta: float, throttle: float, turn: float, brake: bool) -> void:
	var target := throttle * (MAX_SPEED if throttle > 0 else MAX_SPEED * 0.4)
	var acc := (7.0 if signf(target) == signf(speed) or absf(speed) < 0.5 * W.M else 14.0) * W.M
	if brake:
		speed = move_toward(speed, 0.0, 22.0 * W.M * delta)
	else:
		speed = move_toward(speed, target, acc * delta)
	steer = move_toward(steer, turn, 3.0 * delta)
	var turn_rate := steer * clampf(absf(speed) / (5.0 * W.M), 0.0, 1.0) * 1.7 * signf(speed)
	yaw += turn_rate * delta
	velocity = forward() * speed
	var hit := move_and_slide()
	if hit and get_slide_collision_count() > 0:
		speed *= 0.4
		world.car_bump(self)
	rotation = yaw
	art.set_motion(speed / W.M, steer)


func _physics_process(delta: float) -> void:
	if sim and driver == 0 and not lane.is_empty() and Net.is_host():
		_traffic(delta)
	elif not sim and _have:
		position = position.lerp(net_pos, clampf(delta * 10.0, 0.0, 1.0))
		if position.distance_to(net_pos) > 8.0 * W.M:
			position = net_pos
		rotation = lerp_angle(rotation, net_yaw, clampf(delta * 10.0, 0.0, 1.0))
		yaw = rotation
	elif sim and driver == 0:
		speed = move_toward(speed, 0.0, 10.0 * W.M * delta)
		if absf(speed) > 1.0:
			velocity = forward() * speed
			move_and_slide()


func _traffic(delta: float) -> void:
	var t: Vector2 = lane[lane_i]
	var to := t - position
	if to.length() < 2.5 * W.M:
		lane_i = (lane_i + 1) % lane.size()
		return
	yaw = lerp_angle(yaw, to.angle(), clampf(delta * 2.5, 0.0, 1.0))
	var target := 8.0 * W.M
	if world.something_ahead(self, 7.0 * W.M):
		target = 0.0
	speed = move_toward(speed, target, 6.0 * W.M * delta)
	velocity = forward() * speed
	move_and_slide()
	rotation = yaw
	_art_t -= delta
	if _art_t <= 0.0:
		_art_t = 0.1
		art.set_motion(speed / W.M, clampf(angle_difference(yaw, to.angle()) * 2.0, -1.0, 1.0))


func net_update(p: Vector2, y: float, drv: int, ld: int) -> void:
	net_pos = p
	net_yaw = y
	if not _have:
		position = p
		rotation = y
		_have = true
	driver = drv
	if ld != load:
		set_load(ld)
