class_name Car3D
extends Node3D
## The 3D body of one Vehicle: the period car mesh (scripts/cine/car_models.gd), turning wheels, a
## stake bed with crates, headlamps. View3D copies the Vehicle's pose each frame (sync_from).
## Models face +Z; the node's rotation.y comes from V3.yaw_y(vehicle.yaw).

const MAX_CRATES := 16

var vehicle: Node        # the Vehicle (2D simulation)
var kind := "truck"
var _body: MeshInstance3D
var _wheels: Array[Node3D] = []
var _steer_pivots: Array[Node3D] = []
var _wheel_r := 0.35
var _wheel_ang := 0.0
var _vis_steer := 0.0
var _last := Vector3.ZERO
var _last_yaw := 0.0
var _crates: Array[MeshInstance3D] = []
var _lights: Array[SpotLight3D] = []
var _night := 0.0
var _light_t := 0.0


func setup(kd: String, key: String, fam_color: Color = Color(0, 0, 0, 0)) -> void:
	kind = kd
	name = "car_" + key
	var sp := CarModels.spec(kd)
	_body = MeshInstance3D.new()
	_body.name = "Body"
	_body.mesh = CarModels.body(kd)
	add_child(_body)
	var tint := Color("1c1d20")
	var r := W.rng(key.hash())
	match kd:
		"sedan", "touring":
			var pal := [Color("1c1d20"), Color("1c1d20"), Color("1c1d20"), Color("3a1a18"), Color("1f2a3a"),
				Color("26382c"), Color("3b3226"), Color("4a4f55")]
			tint = pal[r.randi_range(0, pal.size() - 1)]
		"taxi":
			tint = Color("c89a2e")
		"van":
			var vp := [Color("6b2320"), Color("2f4a38"), Color("c9b98f"), Color("2b3a55")]
			tint = vp[r.randi_range(0, vp.size() - 1)]
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
	for lp in sp["lamps"]:
		var l := SpotLight3D.new()
		l.light_color = Color("ffe0a8")
		l.spot_range = 16.0
		l.spot_angle = 32.0
		l.light_energy = 0.0
		l.position = lp + Vector3(0, 0, 0.12)
		l.rotation.x = -0.22
		l.visible = false
		add_child(l)
		_lights.append(l)
	if kd in ["truck", "delivery"]:
		var crate_mat := V3.mat(Color("8a6a44"), 0.9)
		for n in MAX_CRATES:
			var c := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.6, 0.42, 0.5)
			c.mesh = bm
			c.material_override = crate_mat
			c.position = Vector3(-0.35 + (n % 2) * 0.7, float(sp["bed_y"]) + 0.215 + (n / 6) * 0.44, -0.5 - (n / 2 % 3) * 0.66)
			c.rotation.y = (W.rng(n + key.hash()).randf() - 0.5) * 0.12
			c.visible = false
			add_child(c)
			_crates.append(c)
	if kd == "police":
		for s in [1.0, -1.0]:
			var l := Label3D.new()
			l.text = "POLICE"
			l.font = load("res://assets/fonts/signs/AlfaSlabOne-Regular.ttf")
			l.font_size = 48
			l.pixel_size = 0.0045
			l.outline_size = 0
			l.modulate = Color("e8e0c8")
			l.double_sided = false
			l.position = Vector3(s * 0.85, 1.52, -0.7)
			l.rotation.y = PI * 0.5 * s
			add_child(l)


func set_load(n: int) -> void:
	for k in _crates.size():
		_crates[k].visible = k < n


func set_night(v: float) -> void:
	_night = v
	for l in _lights:
		l.light_energy = v * 3.0
	CarModels.set_night(v)


## Copy the simulation's pose. Called every frame by View3D.
func sync_from(v: Node, delta: float) -> void:
	var p := V3.pos(v.position)
	global_position = p
	rotation.y = V3.yaw_y(v.rotation)
	# headlamps are real lights only near the camera (the renderer has a light budget)
	_light_t -= delta
	if _light_t <= 0.0:
		_light_t = 0.4
		var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
		var near := cam != null and cam.global_position.distance_squared_to(global_position) < 45.0 * 45.0
		var on: bool = _night > 0.05 and near and (absf(v.speed) > 1.0 or v.driver != 0 or not v.lane.is_empty())
		for l in _lights:
			l.visible = on
	# wheels turn with the distance covered, the front wheels follow the turn
	var moved := p - _last
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
	elif v.driver != 0:
		want = -float(v.steer) * 0.45
	_vis_steer = lerpf(_vis_steer, want, clampf(delta * 8.0, 0.0, 1.0))
	for pv in _steer_pivots:
		pv.rotation.y = _vis_steer
	_last = p
	_last_yaw = rotation.y
