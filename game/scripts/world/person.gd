class_name Person
extends Node3D
## What a person looks like and how they move: one of the owner's low-poly villagers from the
## Woods project (Villager / Woman / Elder, rigged on the KayKit skeleton with the Quaternius UAL
## clips) dressed for 1920s New York: dyed clothes, a fedora or a flat cap, a family hat band and a
## faint ring on the ground in the family colour so you can read the street from above.

enum Anim { IDLE, WALK, RUN, CARRY, TALK, DOWN, DEAD, SIT, ARMS, CHEER }

const MODELS := {
	"man": "res://assets/models/characters/Villager.glb",
	"woman": "res://assets/models/characters/Woman.glb",
	"elder": "res://assets/models/characters/Elder.glb",
}
const LIBS := {
	"man": "res://assets/animations/ual_human.res",
	"woman": "res://assets/animations/ual_human_woman.res",
	"elder": "res://assets/animations/ual_human.res",
}
const CLIPS := {
	Anim.IDLE: &"ual/Idle", Anim.WALK: &"ual/Walk", Anim.RUN: &"ual/Jog", Anim.CARRY: &"ual/Walk_Carry",
	Anim.TALK: &"ual/Idle_Talking", Anim.DOWN: &"Lie_Idle", Anim.DEAD: &"Death_A_Pose",
	Anim.SIT: &"Sit_Chair_Idle", Anim.ARMS: &"ual/Idle_FoldArms", Anim.CHEER: &"Cheer",
}
const SUITS := [Color("2a2a2e"), Color("3b3430"), Color("24292f"), Color("4a4038"), Color("1f1d1c"), Color("3a3f45")]
const SHIRTS := [Color("e8e2d4"), Color("d8d2c0"), Color("c9d3dc"), Color("e6dcc6")]
const PLAIN := [Color("6b5a44"), Color("4f5a4a"), Color("5a4a3f"), Color("705f4d"), Color("48505a"), Color("7a6a55"), Color("5d4636")]
const DRESSES := [Color("6b3a3a"), Color("3f4f6b"), Color("5a6b4f"), Color("7a6a4a"), Color("4a3f5a"), Color("8a7a66")]
const HAIR := [Color("1d1714"), Color("2e2219"), Color("4a3524"), Color("6b6560"), Color("1a1a1a")]

static var _scenes := {}
static var _libs := {}
static var _hat_mats := {}

var anim_state: int = Anim.IDLE
var family_color := Color(0, 0, 0, 0)
var _anim: AnimationPlayer
var _skel: Skeleton3D
var _model: Node3D
var _ring: MeshInstance3D
var _carry: Node3D
var _oneshot := 0.0
var _speed := 0.0
var _gun: Node3D


## kind: boss, crew, cop, ped, shop, recruit, fed. `look` is a seed for the clothes.
func setup(kind: String, look: int, fam_color: Color = Color(0, 0, 0, 0), body: String = "") -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = look
	var b := body
	if b == "":
		b = "man"
		if kind == "ped":
			var r := rng.randf()
			b = "woman" if r < 0.38 else ("elder" if r < 0.55 else "man")
	_model = _instance(b)
	add_child(_model)
	_skel = _model.find_child("Skeleton3D", true, false) as Skeleton3D
	_anim = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim and not _anim.has_animation_library(&"ual"):
		_anim.add_animation_library(&"ual", _lib(b))
	var tints := {}
	var hat := ""
	var hat_col := Color("2b2622")
	var band := Color("1a1a1a")
	var hide := ["Apron"]
	match kind:
		"boss", "crew":
			var suit: Color = SUITS[rng.randi_range(0, SUITS.size() - 1)]
			if kind == "boss":
				suit = Color("1c1b1d")
			tints = {"Shirt": SHIRTS[rng.randi_range(0, SHIRTS.size() - 1)], "Vest": suit,
				"Trousers": suit.darkened(0.1), "Hair": HAIR[rng.randi_range(0, 2)]}
			hat = "fedora"
			hat_col = [Color("2b2622"), Color("3d3a36"), Color("4a3f33"), Color("222222")][rng.randi_range(0, 3)]
			if kind == "boss":
				hat_col = Color("5c5650")
			band = fam_color if fam_color.a > 0 else band
		"cop":
			var navy := Color("1f2a44")
			tints = {"Shirt": navy, "Vest": navy.darkened(0.15), "Trousers": navy.darkened(0.2), "Hair": HAIR[1]}
			hat = "cop"
			hat_col = navy.darkened(0.3)
		"fed":
			tints = {"Shirt": Color("dcdcdc"), "Vest": Color("3a3a3a"), "Trousers": Color("2f2f2f"), "Hair": HAIR[0]}
			hat = "fedora"
			hat_col = Color("4a4a4a")
		"shop":
			tints = {"Shirt": SHIRTS[rng.randi_range(0, 3)], "Vest": PLAIN[rng.randi_range(0, PLAIN.size() - 1)],
				"Trousers": PLAIN[rng.randi_range(0, PLAIN.size() - 1)].darkened(0.2), "Apron": Color("ece8de"),
				"Hair": HAIR[rng.randi_range(0, HAIR.size() - 1)]}
			hide = []
			hat = "cap" if rng.randf() < 0.3 else ""
		"recruit":
			tints = {"Shirt": [Color("b8a888"), Color("8a8474"), Color("c8c0b0")][rng.randi_range(0, 2)],
				"Vest": PLAIN[rng.randi_range(0, PLAIN.size() - 1)], "Trousers": Color("3a342e"),
				"Hair": HAIR[rng.randi_range(0, 2)]}
			hat = "cap"
			hat_col = PLAIN[rng.randi_range(0, PLAIN.size() - 1)].darkened(0.3)
		_:
			if b == "woman":
				var d: Color = DRESSES[rng.randi_range(0, DRESSES.size() - 1)]
				tints = {"Blouse": SHIRTS[rng.randi_range(0, 3)], "Bodice": d.darkened(0.2), "Skirt": d,
					"Hair": HAIR[rng.randi_range(0, HAIR.size() - 1)], "Headscarf": PLAIN[rng.randi_range(0, 6)]}
				hide = ["Apron"] if rng.randf() < 0.7 else []
				if rng.randf() < 0.6:
					hide.append("Headscarf")
			elif b == "elder":
				tints = {"Jumper": PLAIN[rng.randi_range(0, PLAIN.size() - 1)], "Cap": PLAIN[rng.randi_range(0, 6)].darkened(0.3),
					"Trousers": Color("3a342e"), "Hair": HAIR[3]}
			else:
				tints = {"Shirt": SHIRTS[rng.randi_range(0, 3)], "Vest": PLAIN[rng.randi_range(0, PLAIN.size() - 1)],
					"Trousers": PLAIN[rng.randi_range(0, PLAIN.size() - 1)].darkened(0.25), "Hair": HAIR[rng.randi_range(0, HAIR.size() - 1)]}
				var hr := rng.randf()
				hat = "fedora" if hr < 0.4 else ("cap" if hr < 0.75 else "")
				hat_col = PLAIN[rng.randi_range(0, 6)].darkened(0.35)
	for n in hide:
		var node := _model.find_child(n, true, false) as Node3D
		if node:
			node.visible = false
	_dye(tints)
	if hat != "":
		_add_hat(hat, hat_col, band)
	family_color = fam_color
	if fam_color.a > 0.0:
		_add_ring(fam_color)
	for mi in _model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).visibility_range_end = 95.0
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	play(Anim.IDLE)
	if _anim and _anim.current_animation != "":
		_anim.seek(rng.randf() * maxf(0.1, _anim.current_animation_length), true)


static func _instance(b: String) -> Node3D:
	if not _scenes.has(b):
		_scenes[b] = load(MODELS[b])
	return (_scenes[b] as PackedScene).instantiate() as Node3D


static func _lib(b: String) -> AnimationLibrary:
	if not _libs.has(b):
		var lib := load(LIBS[b]) as AnimationLibrary
		for n in lib.get_animation_list():
			var a := lib.get_animation(n)
			if n in [&"Idle", &"Walk", &"Jog", &"Walk_Carry", &"Idle_Talking", &"Idle_FoldArms", &"Stroll", &"Sprint"]:
				a.loop_mode = Animation.LOOP_LINEAR
		_libs[b] = lib
	return _libs[b]


func _dye(tints: Dictionary) -> void:
	var cache := {}
	for node in _model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var src := mi.get_active_material(s) as BaseMaterial3D
			if src == null or not tints.has(src.resource_name):
				continue
			if not cache.has(src):
				var m := src.duplicate() as BaseMaterial3D
				m.albedo_color = tints[src.resource_name]
				cache[src] = m
			mi.set_surface_override_material(s, cache[src])


static func _mat(c: Color, rough: float = 0.85) -> StandardMaterial3D:
	var key := c.to_html() + str(rough)
	if not _hat_mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = rough
		_hat_mats[key] = m
	return _hat_mats[key]


func _add_hat(kind: String, col: Color, band: Color) -> void:
	if _skel == null:
		return
	var head := _skel.find_bone("Head")
	if head < 0:
		return
	var att := BoneAttachment3D.new()
	att.bone_name = "Head"
	_skel.add_child(att)
	var hat := Node3D.new()
	hat.position = Vector3(0.0, 0.265, 0.01)
	att.add_child(hat)
	match kind:
		"fedora":
			hat.add_child(_cyl(0.215, 0.215, 0.018, col, Vector3(0, 0.0, 0)))
			hat.add_child(_cyl(0.118, 0.132, 0.14, col, Vector3(0, 0.075, 0)))
			hat.add_child(_cyl(0.134, 0.134, 0.035, band, Vector3(0, 0.03, 0)))
		"cap":
			hat.add_child(_cyl(0.15, 0.14, 0.06, col, Vector3(0, 0.01, -0.01)))
			var bill := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.2, 0.012, 0.1)
			bill.mesh = bm
			bill.material_override = _mat(col.darkened(0.2))
			bill.position = Vector3(0, -0.01, 0.14)
			bill.rotation.x = 0.15
			hat.add_child(bill)
		"cop":
			hat.add_child(_cyl(0.15, 0.13, 0.1, col, Vector3(0, 0.03, 0)))
			hat.add_child(_cyl(0.165, 0.165, 0.015, col, Vector3(0, 0.085, 0)))
			var visor := MeshInstance3D.new()
			var vm := BoxMesh.new()
			vm.size = Vector3(0.2, 0.012, 0.09)
			visor.mesh = vm
			visor.material_override = _mat(Color("0c0c0c"), 0.3)
			visor.position = Vector3(0, -0.015, 0.14)
			hat.add_child(visor)
			hat.add_child(_cyl(0.02, 0.02, 0.02, Color("c9a54a"), Vector3(0, 0.05, 0.14)))


func _cyl(top: float, bottom: float, h: float, c: Color, at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = top
	cm.bottom_radius = bottom
	cm.height = h
	cm.radial_segments = 14
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = _mat(c)
	mi.position = at
	return mi


func _add_ring(c: Color) -> void:
	_ring = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.3, 1.3)
	q.orientation = PlaneMesh.FACE_Y
	_ring.mesh = q
	var m := ShaderMaterial.new()
	m.shader = preload("res://scripts/world/ring.gdshader")
	m.set_shader_parameter("color", c)
	_ring.material_override = m
	_ring.position.y = 0.04
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)


func set_ring_visible(v: bool) -> void:
	if _ring:
		_ring.visible = v


## Continuous state (walk / run / idle ...). speed in m/s scales the gait.
func set_motion(state: int, speed: float) -> void:
	_speed = speed
	if _oneshot > 0.0:
		return
	if state != anim_state or (_anim and _anim.current_animation == ""):
		play(state)
	if _anim:
		match anim_state:
			Anim.WALK, Anim.CARRY:
				_anim.speed_scale = clampf(speed / 1.35, 0.6, 1.6)
			Anim.RUN:
				_anim.speed_scale = clampf(speed / 3.6, 0.7, 1.5)
			_:
				_anim.speed_scale = 1.0


func play(state: int) -> void:
	anim_state = state
	if _anim == null:
		return
	var clip: StringName = CLIPS.get(state, &"ual/Idle")
	if _anim.has_animation(clip):
		_anim.play(clip, 0.25 if state not in [Anim.DOWN, Anim.DEAD] else 0.4)


## One-shot actions that return to the loop afterwards.
func action(name: String) -> void:
	if _anim == null:
		return
	var clip := &""
	match name:
		"punch": clip = [&"Unarmed_Melee_Attack_Punch_A", &"Unarmed_Melee_Attack_Punch_B"][randi() % 2]
		"kick": clip = &"Unarmed_Melee_Attack_Kick"
		"hit": clip = [&"Hit_A", &"Hit_B"][randi() % 2]
		"shoot": clip = &"1H_Ranged_Shoot"
		"pickup": clip = &"PickUp"
		"interact": clip = &"Interact"
		"yes": clip = &"ual/Yes"
		"no": clip = &"ual/No"
		"wave": clip = &"ual/Wave"
		"cheer": clip = &"Cheer"
		"down": clip = &"Death_A"
		"die": clip = &"Death_B"
	if clip == &"" or not _anim.has_animation(clip):
		return
	_anim.speed_scale = 1.0
	_anim.play(clip, 0.1)
	_oneshot = _anim.get_animation(clip).length / (1.4 if name in ["punch", "kick", "shoot"] else 1.0)
	if name in ["punch", "kick", "shoot"]:
		_anim.speed_scale = 1.4
	if name == "shoot":
		_show_gun(0.6)
	if name in ["down", "die"]:
		anim_state = Anim.DOWN if name == "down" else Anim.DEAD
		_oneshot = _anim.get_animation(clip).length
		_anim.animation_finished.connect(func(_n: StringName) -> void: play(anim_state), CONNECT_ONE_SHOT)


func _process(delta: float) -> void:
	if _oneshot > 0.0:
		_oneshot -= delta
		if _oneshot <= 0.0 and anim_state not in [Anim.DOWN, Anim.DEAD]:
			play(anim_state)


func carry(on: bool) -> void:
	if on and _carry == null and _skel:
		_carry = MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.5, 0.36, 0.4)
		(_carry as MeshInstance3D).mesh = bm
		(_carry as MeshInstance3D).material_override = Crate.material()
		_carry.position = Vector3(0, 1.08, 0.36)
		add_child(_carry)
	elif not on and _carry:
		_carry.queue_free()
		_carry = null


func _show_gun(t: float) -> void:
	if _skel == null:
		return
	if _gun == null:
		var att := BoneAttachment3D.new()
		att.bone_name = "handslot.r"
		_skel.add_child(att)
		_gun = MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.04, 0.1, 0.22)
		(_gun as MeshInstance3D).mesh = bm
		(_gun as MeshInstance3D).material_override = _mat(Color("151515"), 0.35)
		_gun.position = Vector3(0, 0.02, 0.08)
		att.add_child(_gun)
	_gun.visible = true
	get_tree().create_timer(t).timeout.connect(func() -> void: if is_instance_valid(_gun): _gun.visible = false)
