class_name Weather3D
extends Node3D
## Rain streaks, puddle splashes, drifting fog and mist around the camera focus. Follows the focus so the
## particles are always where you look. The lightning flash stays in the 2D overlay (Weather).
##   set_kind(kind, night)   "clear" | "rain" | "fog"
##   follow(focus)           call every frame with the camera's focus point

var rain: GPUParticles3D
var splash: GPUParticles3D
var mist: GPUParticles3D
var _kind := "clear"
var _night := 0.0


func _ready() -> void:
	rain = _make_rain()
	splash = _make_splash()
	mist = _make_mist()
	for p in [rain, splash, mist]:
		p.emitting = false
		add_child(p)


func set_kind(kind: String, night: float) -> void:
	_kind = kind
	_night = night
	rain.emitting = kind == "rain"
	splash.emitting = kind == "rain"
	mist.emitting = kind == "fog" or kind == "rain"
	var tone := Color(0.74, 0.80, 0.90).lerp(Color(0.45, 0.52, 0.68), night)
	(rain.material_override as StandardMaterial3D).albedo_color = Color(tone.r, tone.g, tone.b, 0.55)
	var mc := Color(0.80, 0.82, 0.86).lerp(Color(0.18, 0.22, 0.32), night)
	(mist.material_override as StandardMaterial3D).albedo_color = Color(mc.r, mc.g, mc.b, 0.10 if kind == "rain" else 0.16)


func follow(focus: Vector3) -> void:
	global_position = Vector3(focus.x, 0.0, focus.z)


func _make_rain() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 2200
	p.lifetime = 0.55
	p.visibility_aabb = AABB(Vector3(-40, -2, -40), Vector3(80, 40, 80))
	p.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(30, 0.5, 30)
	pm.direction = Vector3(0.12, -1, 0.05)
	pm.spread = 2.0
	pm.initial_velocity_min = 22.0
	pm.initial_velocity_max = 28.0
	pm.gravity = Vector3.ZERO
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.012, 0.7)
	p.draw_pass_1 = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	p.material_override = m
	p.position = Vector3(0, 13, 0)
	return p


func _make_splash() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 500
	p.lifetime = 0.35
	p.visibility_aabb = AABB(Vector3(-40, -1, -40), Vector3(80, 4, 80))
	p.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(26, 0.0, 22)
	pm.direction = Vector3.UP
	pm.spread = 25.0
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.6
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(1, 1.8))
	var ct := CurveTexture.new()
	ct.curve = curve
	pm.scale_curve = ct
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.18, 0.18)
	q.orientation = PlaneMesh.FACE_Y
	p.draw_pass_1 = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = _ring_tex()
	m.albedo_color = Color(0.85, 0.9, 1.0, 0.45)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	p.material_override = m
	p.position = Vector3(0, 0.05, 0)
	return p


func _make_mist() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 40
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.visibility_aabb = AABB(Vector3(-50, -1, -50), Vector3(100, 10, 100))
	p.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(34, 0.6, 34)
	pm.direction = Vector3(1, 0, 0.3)
	pm.spread = 20.0
	pm.initial_velocity_min = 0.3
	pm.initial_velocity_max = 0.8
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.8
	pm.scale_max = 1.6
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(16, 5)
	p.draw_pass_1 = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = _soft_tex()
	m.albedo_color = Color(0.8, 0.82, 0.86, 0.14)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	p.material_override = m
	p.position = Vector3(0, 1.6, 0)
	return p


static func _ring_tex() -> Texture2D:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var d := Vector2(x - 15.5, y - 15.5).length() / 15.5
			var a := clampf(1.0 - absf(d - 0.7) * 5.0, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


static func _soft_tex() -> Texture2D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var d := Vector2(x - 31.5, y - 31.5).length() / 31.5
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	return ImageTexture.create_from_image(img)
