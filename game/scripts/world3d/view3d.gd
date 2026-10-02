class_name View3D
extends Node3D
## The 3D picture of the street. The World (2D) is still the simulation: positions, AI, networking,
## physics, shakedowns. View3D mirrors it every frame: a Puppet3D for every Actor, a Car3D for every
## Vehicle, an Item3D for every crate on the ground, plus the city, the rooms, the sky, the camera.
## Contract: docs/REBUILD_3D.md.
##
## Coordinates: V3.pos(px) turns a 2D world point into 3D (metres, x east, z south, y up).
## The camera: a tilted, perspective view from the south that follows the 2D CameraRig's focus and
## zoom (so shake, driving zoom and "inside" zoom all carry over).
##   to_screen(px, height) -> Vector2    where a 2D world point appears on screen (INF when behind)
##   to_world(screen) -> Vector2         the 2D world point (px) under a screen position (the ground)

var world: Node                       # World
var cam: Camera3D
var sun: DirectionalLight3D
var env: Environment
var city: City3D
var rooms: Interiors3D
var weather_fx: Node3D                # Weather3D (rain, splashes, lightning), may be null
var puppets := {}                     # actor key -> Puppet3D
var cars := {}                        # vehicle key -> Car3D
var items := {}                       # item id -> Item3D
var yaw := 0.0                        # turn the camera (radians); 0 = looking north
var pitch := V3.CAM_PITCH
var cinematic_cam: Camera3D           # while a cinematic runs, it owns the picture
var night := 0.0
var wet := 0.0
var _focus := Vector3.ZERO
var _dist := 20.0
var _fog_density := 0.0


func setup(w: Node) -> void:
	world = w
	name = "View3D"
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("9fb4c4")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c8cdd6")
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_energy = 1.1
	sun.light_color = Color("fff0d8")
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.0
	add_child(sun)
	sun.look_at_from_position(Vector3.ZERO, V3.SUN_DIR, Vector3.UP)
	cam = Camera3D.new()
	cam.name = "Camera"
	cam.fov = V3.CAM_FOV
	cam.near = 0.5
	cam.far = 600.0
	add_child(cam)
	cam.current = true
	city = City3D.new()
	city.name = "City"
	add_child(city)
	city.build(world.plan)
	rooms = Interiors3D.new()
	rooms.name = "Rooms"
	add_child(rooms)
	rooms.build(world.interiors.layouts)
	snap()


## Put the camera on the focus at once (a teleport, the start, a cinematic ending).
func snap() -> void:
	_focus = _target_focus()
	_dist = _target_dist()
	_place()


func _target_focus() -> Vector3:
	var c: Camera2D = world.cam
	return V3.pos(c.global_position)


func _target_dist() -> float:
	var c: Camera2D = world.cam
	return V3.CAM_DIST / maxf(0.2, c.zoom.x)


func _process(delta: float) -> void:
	_sync_people(delta)
	_sync_cars(delta)
	_sync_items()
	if cinematic_cam == null:
		_focus = _target_focus()
		_dist = lerpf(_dist, _target_dist(), clampf(delta * 8.0, 0.0, 1.0))
		_place()


func _place() -> void:
	var off := Vector3(sin(yaw), 0.0, cos(yaw)) * cos(pitch) * _dist + Vector3(0, sin(pitch) * _dist, 0)
	cam.global_position = _focus + off
	cam.look_at(_focus + Vector3(0, 0.6, 0), Vector3.UP)


# ------------------------------------------------------------------ projection

## Where a 2D world point (pixels), at `height` metres, appears on screen. Vector2.INF when it is
## behind the camera.
func to_screen(px: Vector2, height: float = 0.0) -> Vector2:
	var p := V3.pos(px, height)
	if cam.is_position_behind(p):
		return Vector2.INF
	return cam.unproject_position(p)


## The 2D world point (pixels) on the ground under a screen position.
func to_world(screen: Vector2) -> Vector2:
	var o := cam.project_ray_origin(screen)
	var d := cam.project_ray_normal(screen)
	if absf(d.y) < 0.0001:
		return V3.flat(_focus)
	var t := -o.y / d.y
	return V3.flat(o + d * maxf(t, 0.0))


## Pixels of screen one metre of ground covers at a 2D world point: for sizing HUD marks.
func metre_px(px: Vector2) -> float:
	var a := to_screen(px)
	var b := to_screen(px + Vector2(W.M, 0))
	if a == Vector2.INF or b == Vector2.INF:
		return 40.0
	return a.distance_to(b)


# ------------------------------------------------------------------ cinematics

## A cinematic takes the picture: returns its camera (the game camera stops following).
func begin_cinematic() -> Camera3D:
	if cinematic_cam == null:
		cinematic_cam = Camera3D.new()
		cinematic_cam.name = "CinematicCamera"
		cinematic_cam.fov = V3.CAM_FOV
		cinematic_cam.near = 0.2
		cinematic_cam.far = 600.0
		add_child(cinematic_cam)
	cinematic_cam.current = true
	return cinematic_cam


func end_cinematic() -> void:
	if cinematic_cam:
		cinematic_cam.queue_free()
		cinematic_cam = null
	cam.current = true
	snap()


# ------------------------------------------------------------------ sky, weather, inside

## Called by the World when the light changes: night 0..1, dusk 0..1 (the orange hour), wet 0/1.
func set_light(n: float, dusk: float, w: float, kind: String) -> void:
	night = n
	wet = w
	var day_sky := Color("a9bccb")
	var dusk_sky := Color("c98a5a")
	var night_sky := Color("0c1220")
	var sky := day_sky.lerp(dusk_sky, dusk * (1.0 - n)).lerp(night_sky, n)
	if kind == "rain":
		sky = sky.lerp(Color("5a6470").lerp(Color("10141c"), n), 0.6)
	elif kind == "fog":
		sky = sky.lerp(Color("8c9096").lerp(Color("14181e"), n), 0.7)
	env.background_color = sky
	env.ambient_light_color = Color("d0d4dc").lerp(Color("e0b090"), dusk * (1.0 - n)).lerp(Color("303c5a"), n)
	env.ambient_light_energy = lerpf(0.75, 0.55, n)
	sun.light_energy = lerpf(1.15, 0.0, clampf(n * 1.3, 0.0, 1.0)) * (0.45 if kind != "clear" else 1.0)
	sun.light_color = Color("fff0d8").lerp(Color("ffb070"), dusk)
	env.fog_enabled = kind != "clear" or n > 0.4
	env.fog_light_color = sky
	_fog_density = {"clear": 0.002, "rain": 0.012, "fog": 0.03}.get(kind, 0.002)
	env.fog_density = _fog_density
	city.set_night(n, w)
	rooms.set_night(n, w)
	for c in cars.values():
		(c as Car3D).set_night(n)
	if weather_fx and weather_fx.has_method("set_kind"):
		weather_fx.call("set_kind", kind, n)


## The local player went into a building (-1 = outside).
func set_inside(lot: int) -> void:
	city.set_inside(lot)
	rooms.set_inside(lot)


## Shops changed hands, got padlocked, opened a speakeasy, had things broken.
func state_changed() -> void:
	city.update_owners()
	rooms.update_from_game()


# ------------------------------------------------------------------ mirroring the simulation

func _sync_people(_delta: float) -> void:
	var live := {}
	for key in world.actors:
		var a = world.actors[key]
		if a == null or not is_instance_valid(a):
			continue
		live[key] = true
		var pp: Puppet3D = puppets.get(key)
		if pp == null:
			pp = _make_puppet(a)
			puppets[key] = pp
		pp.visible = not a.hidden_in_car
		if pp.visible:
			pp.global_position = V3.pos(a.position)
			pp.rotation.y = V3.yaw_y(a.person.rotation)
	if puppets.size() > live.size():
		for key in puppets.keys():
			if not live.has(key):
				(puppets[key] as Puppet3D).queue_free()
				puppets.erase(key)


func _make_puppet(a) -> Puppet3D:
	var pp := Puppet3D.new()
	pp.name = "p_" + String(a.key).replace(":", "_")
	pp.actor = a
	var per: Person2D = a.person
	pp.setup(per.kind, per.look, per.family_color, per.extra)
	add_child(pp)
	per.mirror = pp
	a.modulate.a = 0.0        # the 2D body keeps simulating (and stays `visible` for the game rules), just isn't drawn
	pp.carry(a.carrying)
	pp.set_motion(a.state, a.speed / W.M)
	return pp


func _sync_cars(delta: float) -> void:
	var live := {}
	for key in world.vehicles:
		var v = world.vehicles[key]
		if v == null or not is_instance_valid(v):
			continue
		live[key] = true
		var c: Car3D = cars.get(key)
		if c == null:
			c = Car3D.new()
			c.vehicle = v
			c.setup(v.kind, String(v.key), W.fam_color(v.family) if v.family >= 0 else W.FAMILY_NONE)
			add_child(c)
			c.global_position = V3.pos(v.position)
			c.set_night(night)
			cars[key] = c
			v.modulate.a = 0.0
			c.set_load(v.load)
		c.sync_from(v, delta)
		c.set_load(v.load)
	if cars.size() > live.size():
		for key in cars.keys():
			if not live.has(key):
				(cars[key] as Car3D).queue_free()
				cars.erase(key)


func _sync_items() -> void:
	var live := {}
	for id in world.items:
		var it = world.items[id]
		if it == null or not is_instance_valid(it):
			continue
		live[id] = true
		var n: Item3D = items.get(id)
		if n == null:
			n = Item3D.new()
			n.setup(it.kind, it.amount, int(id))
			add_child(n)
			items[id] = n
			it.modulate.a = 0.0
		n.global_position = V3.pos(it.position)
	if items.size() > live.size():
		for id in items.keys():
			if not live.has(id):
				(items[id] as Item3D).queue_free()
				items.erase(id)
