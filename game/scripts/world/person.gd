class_name Person
extends Node3D
## What a person looks like and how they move. The street cast is assembled from Quaternius'
## Ultimate Modular Men / Women (CC0, "Humanoid Rig" versions): a body, legs, shoes and a head,
## each taken from one of the outfits and hung on one shared skeleton, dyed for 1920s New York
## (suits in charcoal, brown and navy, dockers' overalls, shopkeepers' white bibs, patrolmen in
## navy, women in dresses and skirt suits), plus a procedural fedora, flat cap, bowler, cloche,
## watch cap or patrolman's cap on the head bone, a family-coloured tie or hat band, and a faint
## ring on the ground in the family colour so you can read the street from above.
## The clips are the Quaternius Universal Animation Library retargeted onto that skeleton
## (tools/rig/build_library.gd -> assets/animations/quat_men.res / quat_women.res).
## If those assets are missing the Woods villagers are used as before.

enum Anim { IDLE, WALK, RUN, CARRY, TALK, DOWN, DEAD, SIT, ARMS, CHEER }

const QDIR := "res://assets/models/characters/quaternius/"
const RIGS := {
	"men": {"base": QDIR + "men/Suit.fbx", "lib": "res://assets/animations/quat_men.res"},
	"women": {"base": QDIR + "women/Formal.fbx", "lib": "res://assets/animations/quat_women.res"},
}
const CLIPS := {
	Anim.IDLE: &"q/Idle", Anim.WALK: &"q/Walk", Anim.RUN: &"q/Jog", Anim.CARRY: &"q/Walk_Carry",
	Anim.TALK: &"q/Idle_Talking", Anim.DOWN: &"q/Lie_Down", Anim.DEAD: &"q/Lie_Dead",
	Anim.SIT: &"q/Sitting_Idle", Anim.ARMS: &"q/Idle_FoldArms", Anim.CHEER: &"q/Cheer",
}
const ACTIONS := {
	"punch": [&"q/Punch_Jab", &"q/Punch_Cross", &"q/Melee_Hook"],
	"kick": [&"q/Kick"],
	"hit": [&"q/Hit_Chest", &"q/Hit_Head"],
	"shoot": [&"q/Pistol_Shoot"],
	"pickup": [&"q/PickUp"],
	"interact": [&"q/Interact"],
	"yes": [&"q/Yes"],
	"no": [&"q/No"],
	"wave": [&"q/Wave"],
	"cheer": [&"q/Cheer"],
	"down": [&"q/Fall"],
	"die": [&"q/Death"],
}
## Clips cut short / sped up so a fight reads quickly.
const FAST := {"punch": 1.35, "kick": 1.25, "shoot": 1.2, "hit": 1.1, "yes": 1.3, "no": 1.3, "wave": 1.1, "pickup": 1.2, "interact": 1.4}

# ---- palettes (muted, period) ----
const SKIN := [Color("e3bb98"), Color("d9aa84"), Color("cf9f7a"), Color("e8c4a4"), Color("c48f68"), Color("b98260"), Color("dcb08c"), Color("9c6a48"), Color("7a4e34")]
const SKIN_W := [9, 9, 8, 6, 6, 4, 6, 2, 2]
const SUITS := [Color("2f3035"), Color("3d342c"), Color("252c3d"), Color("47423b"), Color("2a2a2a"), Color("3f4448"), Color("4d3e30"), Color("36392f")]
const SHIRTS := [Color("d9d3c4"), Color("cdc5b2"), Color("bcc6cc"), Color("d6cab2"), Color("e0dbd0")]
const TIES := [Color("5a2320"), Color("2c3442"), Color("4a3b25"), Color("2b2b2b"), Color("5b4a2e")]
const WOOL := [Color("5b4d3d"), Color("4a4f45"), Color("6b5a44"), Color("3f3a35"), Color("56463a"), Color("4b4540"), Color("6a5f4f")]
const DENIM := [Color("3a4656"), Color("2f3a47"), Color("4a5260"), Color("5a4a36")]
const WORK_SHIRT := [Color("b9ad92"), Color("a39a86"), Color("c7bda7"), Color("8f8878"), Color("aeb4b4"), Color("9a8c78")]
const TROUSERS := [Color("3b352f"), Color("2f2e2c"), Color("4a4136"), Color("3a3d40"), Color("4c4538")]
const DRESSES := [Color("6e3434"), Color("3f4d69"), Color("55664a"), Color("7c6b4c"), Color("4c3f5c"), Color("8c7a64"), Color("2f4a44"), Color("7a4f3a"), Color("5a5a5e")]
const HAIR := [Color("1d1714"), Color("2e2219"), Color("4a3524"), Color("6b4a2e"), Color("1a1a1a"), Color("7a5a38")]
const HATS := [Color("2b2622"), Color("3d3a36"), Color("4a3f33"), Color("222222"), Color("5a5048"), Color("3a3530")]
const CLOCHE := [Color("5a3a3a"), Color("3a4458"), Color("4f4638"), Color("2e2e33"), Color("6b5a48"), Color("4a5a48"), Color("7a6a5a")]
const NAVY := Color("1f2940")

static var _scenes := {}
static var _libs := {}
static var _mats := {}
static var _parts := {}
static var _hidden_mat: ShaderMaterial
static var _q_ok := -1

var anim_state: int = Anim.IDLE
var family_color := Color(0, 0, 0, 0)
var kind := ""
var _anim: AnimationPlayer
var _skel: Skeleton3D
var _model: Node3D
var _ring: MeshInstance3D
var _carry: Node3D
var _oneshot := 0.0
var _speed := 0.0
var _gun: Node3D
var _rig := "men"
var _head_scale := 1.0
var _hat_lift := 0.0
## Hats sit higher on the fuller haircuts.
const HAT_LIFT := {"Beach": 0.03, "Casual": 0.012, "Adventurer": 0.01, "King": 0.008}


## kind: boss, crew, cop, fed, ped, shop, recruit, dock, union, dealer, smuggler.
## `look` is a seed for the face, the clothes and the hat. body: "" (by kind), "man", "woman", "elder".
func setup(p_kind: String, look: int, fam_color: Color = Color(0, 0, 0, 0), body: String = "") -> void:
	kind = p_kind
	var rng := RandomNumberGenerator.new()
	rng.seed = look
	var b := body
	if b == "":
		b = "man"
		if kind == "ped":
			var r := rng.randf()
			b = "woman" if r < 0.4 else ("elder" if r < 0.52 else "man")
	family_color = fam_color
	if not _quaternius_ok():
		_setup_woods(kind, rng, fam_color, b)
	else:
		_rig = "women" if b == "woman" else "men"
		var o := _outfit(kind, b, rng, fam_color)
		_build(o)
		if o.get("hat", "") != "":
			var head: Array = o.get("head", [""])
			_hat_lift = HAT_LIFT.get(String(head[0]), 0.0) if _rig == "men" else 0.0
			_add_hat(o["hat"], o.get("hat_col", HATS[0]), o.get("band", Color("1a1a1a")))
		if kind == "shop" and _rig == "men":
			_add_apron(o.get("apron", Color("ece8de")))
	if fam_color.a > 0.0:
		_add_ring(fam_color)
	for mi in find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m == _ring:
			continue
		m.visibility_range_end = 110.0
		m.visibility_range_end_margin = 6.0
		m.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	play(Anim.IDLE)
	if _anim and _anim.current_animation != "":
		_anim.seek(rng.randf() * maxf(0.1, _anim.current_animation_length), true)


static func _quaternius_ok() -> bool:
	if _q_ok < 0:
		_q_ok = 1
		for r: String in RIGS:
			if not ResourceLoader.exists(RIGS[r]["base"]) or not ResourceLoader.exists(RIGS[r]["lib"]):
				_q_ok = 0
	return _q_ok == 1


static func _pick(rng: RandomNumberGenerator, arr: Array) -> Variant:
	return arr[rng.randi_range(0, arr.size() - 1)]


static func _skin(rng: RandomNumberGenerator) -> Color:
	var total := 0
	for w in SKIN_W:
		total += w
	var x := rng.randi_range(0, total - 1)
	for i in SKIN.size():
		x -= SKIN_W[i]
		if x < 0:
			return SKIN[i]
	return SKIN[0]


# ------------------------------------------------------------------ outfits
## An outfit: part -> [source outfit file (in the rig's folder), {material: colour}, [hidden materials]],
## plus hat / hat_col / band / scale.

func _outfit(k: String, b: String, rng: RandomNumberGenerator, fam: Color) -> Dictionary:
	var skin := _skin(rng)
	var hair: Color = _pick(rng, HAIR)
	if b == "elder":
		hair = [Color("b8b2aa"), Color("8f8a84"), Color("d8d4cc")][rng.randi_range(0, 2)]
	var o := {}
	if b == "woman":
		return _outfit_woman(k, rng, skin, hair, fam)
	var head := _man_head(rng, skin, hair, b == "elder")
	var fam_on := fam.a > 0.0
	match k:
		"boss", "crew", "fed", "dealer":
			var suit: Color = _pick(rng, SUITS)
			var shirt: Color = _pick(rng, SHIRTS)
			var tie: Color = fam if fam_on else (_pick(rng, TIES) as Color)
			var hat_col: Color = _pick(rng, HATS)
			if k == "boss":
				suit = [Color("1e1d20"), Color("2a2522"), Color("24242a")][rng.randi_range(0, 2)]
				hat_col = [Color("8a8175"), Color("6e665c"), Color("9a9080")][rng.randi_range(0, 2)]
				shirt = SHIRTS[4]
			elif k == "fed":
				suit = Color("4a4b4e")
				tie = Color("202225")
				hat_col = Color("3c3d40")
				shirt = SHIRTS[0]
			elif k == "dealer":
				suit = [Color("6b5a34"), Color("5a3f4a"), Color("4f5a3a")][rng.randi_range(0, 2)]
				tie = Color("8a2a20")
				hat_col = Color("2a2522")
			o = _suit(skin, suit, shirt, tie)
			o["head"] = head if k != "dealer" else _man_head_of("Adventurer", skin, Color("2a2019"))
			o["hat"] = "bowler" if k == "dealer" else "fedora"
			o["hat_col"] = hat_col
			o["band"] = fam if fam_on else hat_col.darkened(0.45)
			if k == "boss":
				o["scale"] = 1.03
		"cop":
			o = _suit(skin, NAVY, NAVY.lightened(0.06), NAVY.darkened(0.25))
			o["head"] = _man_head(rng, skin, hair, false, true)
			o["hat"] = "cop"
			o["hat_col"] = NAVY.darkened(0.35)
			o["belt"] = true
		"shop":
			var shirt: Color = [Color("8e9aa6"), Color("a39a86"), Color("b9ad92"), Color("7f8a80"), Color("9a7f70")][rng.randi_range(0, 4)]
			o = {
				"body": ["Worker", {"Skin": skin, "Worker_Vest": Color("cdc6b4"), "Worker_Yellow": Color("c4bca8"), "LightBrown": shirt}],
				"legs": ["Suit", {"Suit": _pick(rng, TROUSERS)}],
				"feet": ["Suit", {"Black": Color("2a2420")}],
				"head": head,
				"apron": Color("c9c2b0"),
			}
			var hr := rng.randf()
			o["hat"] = "cap" if hr < 0.25 else ("bowler" if hr < 0.35 else "")
			o["hat_col"] = (_pick(rng, WOOL) as Color).darkened(0.2)
		"dock", "recruit":
			if rng.randf() < 0.55:
				o = {
					"body": ["Farmer", {"Skin": skin, "LightBlue": _pick(rng, DENIM), "Brown": _pick(rng, [Color("6b5a44"), Color("7a6a52"), Color("5a4a3a"), Color("6e6656"), Color("5e5a4c")]), "Beige": Color("8a7e66")}],
					"legs": ["Farmer", {"LightBlue": o.get("x", _pick(rng, DENIM))}],
					"feet": ["Farmer", {"Brown": Color("3f3226"), "Brown2": Color("2e251c")}],
				}
				o["legs"][1]["LightBlue"] = o["body"][1]["LightBlue"]
			else:
				var vest: Color = _pick(rng, WOOL)
				o = {
					"body": ["Worker", {"Skin": skin, "Worker_Vest": vest, "Worker_Yellow": vest.darkened(0.12), "LightBrown": _pick(rng, WORK_SHIRT)}],
					"legs": ["Worker", {"Brown": _pick(rng, TROUSERS), "Brown2": Color("2e2a26")}],
					"feet": ["Worker", {"Grey": Color("3a332c"), "Black": Color("241f1b")}],
				}
			o["head"] = head
			o["hat"] = "cap"
			o["hat_col"] = (_pick(rng, WOOL) as Color).darkened(0.25)
			if k == "recruit" and rng.randf() < 0.3:
				o["hat"] = "fedora"
				o["hat_col"] = _pick(rng, HATS)
		"union":
			var vest := Color("3a3430")
			o = {
				"body": ["Worker", {"Skin": skin, "Worker_Vest": vest, "Worker_Yellow": vest, "LightBrown": Color("e2dccc")}],
				"legs": ["Suit", {"Suit": Color("3b352f")}],
				"feet": ["Suit", {"Black": Color("201c19")}],
				"head": _man_head_of("Worker", skin, Color("3a2a1c")),
				"hat": "bowler", "hat_col": Color("2a2522"), "band": Color("1a1612"),
				"scale": 1.07, "wide": 1.08,
			}
		"smuggler":
			var coat := Color("25293a")
			o = {
				"body": ["Worker", {"Skin": skin, "Worker_Vest": coat, "Worker_Yellow": coat, "LightBrown": Color("5a5550")}],
				"legs": ["Worker", {"Brown": Color("2f3036"), "Brown2": Color("26272b")}],
				"feet": ["Farmer", {"Brown": Color("2e261e"), "Brown2": Color("211b15")}],
				"head": _man_head_of("Adventurer", skin, Color("2a2019")),
				"hat": "watch", "hat_col": Color("3c3c42"),
			}
		_:   # pedestrian man / elder
			var r := rng.randf()
			if r < 0.45 or b == "elder":
				var suit: Color = _pick(rng, SUITS + [Color("5a4a3a"), Color("6a6258"), Color("4e4a40")])
				o = _suit(skin, suit, _pick(rng, SHIRTS), _pick(rng, TIES))
			elif r < 0.8:
				var vest: Color = _pick(rng, WOOL)
				o = {
					"body": ["Worker", {"Skin": skin, "Worker_Vest": vest, "Worker_Yellow": vest.darkened(0.1), "LightBrown": _pick(rng, SHIRTS + WORK_SHIRT)}],
					"legs": ["Suit", {"Suit": _pick(rng, TROUSERS)}],
					"feet": ["Suit", {"Black": Color("2a241f")}],
				}
			else:
				o = {
					"body": ["Casual2", {"Skin": skin, "LightBrown": _pick(rng, WORK_SHIRT + SHIRTS)}],
					"legs": ["Suit", {"Suit": _pick(rng, TROUSERS)}],
					"feet": ["Suit", {"Black": Color("2a241f")}],
				}
			o["head"] = head
			var hr := rng.randf()
			o["hat"] = "fedora" if hr < 0.42 else ("cap" if hr < 0.72 else ("bowler" if hr < 0.82 else ""))
			if b == "elder":
				o["hat"] = "bowler" if hr < 0.5 else "fedora"
				o["scale"] = 0.97
			o["hat_col"] = _pick(rng, HATS) if o["hat"] != "cap" else (_pick(rng, WOOL) as Color).darkened(0.2)
			o["band"] = (o["hat_col"] as Color).darkened(0.45)
	return o


func _suit(skin: Color, suit: Color, shirt: Color, tie: Color) -> Dictionary:
	return {
		"body": ["Suit", {"Skin": skin, "Suit": suit, "White": shirt, "Tie": tie}],
		"legs": ["Suit", {"Suit": suit.darkened(0.06)}],
		"feet": ["Suit", {"Black": Color("1c1916")}],
	}


## Men's heads: the Suit / Casual / Beach haircuts, the Worker moustache (hard hat off), the
## Adventurer beard, the King's white beard (crown off) for the old men.
func _man_head(rng: RandomNumberGenerator, skin: Color, hair: Color, elder: bool, clean: bool = false) -> Array:
	if elder:
		return _man_head_of("King", skin, hair)
	var pool := ["Suit", "Suit", "Casual", "Beach", "Worker", "Adventurer"]
	if clean:
		pool = ["Suit", "Casual", "Beach", "Worker"]
	return _man_head_of(_pick(rng, pool), skin, hair)


func _man_head_of(src: String, skin: Color, hair: Color) -> Array:
	match src:
		"Worker":
			return ["Worker", {"Skin": skin, "Moustache": hair, "Eyebrows": hair.darkened(0.2)}, ["Worker_Yellow"]]
		"Adventurer":
			return ["Adventurer", {"Skin": skin, "Hair": hair, "Beard": hair, "Eyebrows": hair.darkened(0.2)}, []]
		"King":
			return ["King", {"Skin": skin, "Hair_White": hair, "Eyebrows": hair}, ["Gold"]]
		"Beach":
			return ["Beach", {"Skin": skin, "Hair": hair, "Eyebrows": hair.darkened(0.2)}, ["Earrings"]]
		_:
			return [src, {"Skin": skin, "Hair": hair, "Skin_Darker": skin.darkened(0.08), "Eyebrows": hair.darkened(0.2)}, []]


func _outfit_woman(k: String, rng: RandomNumberGenerator, skin: Color, hair: Color, _fam: Color) -> Dictionary:
	var dress: Color = _pick(rng, DRESSES)
	var o := {}
	var r := rng.randf()
	if r < 0.55:
		o["body"] = ["Formal", {"Skin": skin, "LimeGreen": dress, "Gold": dress.darkened(0.35)}]
	elif r < 0.8:
		var jacket: Color = _pick(rng, DRESSES + [Color("3a3632"), Color("4a4540")])
		o["body"] = ["Suit", {"Skin": skin, "Black": jacket, "White": _pick(rng, SHIRTS)}]
		dress = jacket.darkened(0.05)
	else:
		o["body"] = ["Casual", {"Skin": skin, "White": _pick(rng, SHIRTS + [Color("c9b9a0")])}]
	o["legs"] = ["Formal", {"Skin": skin, "LimeGreen": dress}]
	o["feet"] = ["Formal", {"Skin": skin, "Red": [Color("2a1f18"), Color("4a2a1c"), Color("1c1a18"), Color("5a2a24")][rng.randi_range(0, 3)]}]
	var hs: String = ["Formal", "Casual", "Suit"][rng.randi_range(0, 2)]
	o["head"] = [hs, {"Skin": skin, "Hair_Brown": hair, "Hair_Blond": hair, "Red": hair if hs == "Formal" else Color("8a3a34"), "Brown": Color("2c2018")}, []]
	if rng.randf() < 0.75 or k != "ped":
		o["hat"] = "cloche"
		o["hat_col"] = _pick(rng, CLOCHE)
		o["band"] = (o["hat_col"] as Color).darkened(0.4) if rng.randf() < 0.5 else Color("d8d0c0")
	return o


# ------------------------------------------------------------------ assembly

func _build(o: Dictionary) -> void:
	var rig: Dictionary = RIGS[_rig]
	_model = _scene(rig["base"]).instantiate() as Node3D
	add_child(_model)
	_skel = _model.find_child("Skeleton3D", true, false) as Skeleton3D
	for c in _skel.get_children():
		if c is MeshInstance3D:
			_skel.remove_child(c)
			c.free()
	for part in ["body", "legs", "feet", "head"]:
		if not o.has(part):
			continue
		var spec: Array = o[part]
		var src := QDIR + ("women/" if _rig == "women" else "men/") + String(spec[0]) + ".fbx"
		var pm := _part(src, part)
		if pm.is_empty():
			continue
		var mi := MeshInstance3D.new()
		mi.name = part
		mi.mesh = pm["mesh"]
		mi.skin = pm["skin"]
		_skel.add_child(mi)
		mi.skeleton = NodePath("..")
		var tints: Dictionary = spec[1]
		var hide: Array = spec[2] if spec.size() > 2 else []
		for s in mi.mesh.get_surface_count():
			var src_m := mi.mesh.surface_get_material(s) as BaseMaterial3D
			if src_m == null:
				continue
			var mn := src_m.resource_name
			if mn in hide:
				mi.set_surface_override_material(s, _hidden())
			elif tints.has(mn):
				mi.set_surface_override_material(s, _dyed(src_m, tints[mn]))
			else:
				mi.set_surface_override_material(s, _dyed(src_m, src_m.albedo_color))
	var sc: float = o.get("scale", 1.0)
	var wide: float = o.get("wide", 1.0)
	_model.scale = Vector3(sc * wide, sc, sc * wide)
	_anim = AnimationPlayer.new()
	_anim.name = "AnimationPlayer"
	_model.add_child(_anim)
	_anim.root_node = NodePath("..")
	_anim.add_animation_library(&"q", _lib(_rig))
	_head_scale = 1.0 / sc
	if o.get("belt", false):
		_add_belt()


static func _scene(path: String) -> PackedScene:
	if not _scenes.has(path):
		_scenes[path] = load(path)
	return _scenes[path]


## Mesh + skin of one part ("body", "legs" / "pants", "feet", "head") of an outfit file.
static func _part(src: String, part: String) -> Dictionary:
	var key := src + ":" + part
	if not _parts.has(key):
		var root := _scene(src).instantiate()
		var found := {}
		for n in root.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			var suffix := String(mi.name).get_slice("_", String(mi.name).get_slice_count("_") - 1).to_lower()
			if suffix == "pants":
				suffix = "legs"
			found[suffix] = {"mesh": mi.mesh, "skin": mi.skin}
		for p: String in found:
			_parts[src + ":" + p] = found[p]
		root.free()
		if not _parts.has(key):
			_parts[key] = {}
	return _parts[key]


static func _lib(rig: String) -> AnimationLibrary:
	if not _libs.has(rig):
		_libs[rig] = load(RIGS[rig]["lib"])
	return _libs[rig]


## Shared dyed copies: flat, matte cloth (the packs' colours are baked per material).
static func _dyed(src: BaseMaterial3D, c: Color) -> BaseMaterial3D:
	var key := "%d:%s" % [src.get_instance_id(), c.to_html()]
	if not _mats.has(key):
		var m := src.duplicate() as BaseMaterial3D
		m.albedo_color = c
		m.metallic = 0.0
		m.metallic_specular = 0.3
		m.roughness = 0.9 if src.resource_name != "Eye" else 0.4
		_mats[key] = m
	return _mats[key]


## Collapses a surface (a hard hat, a crown) to nothing, shadows included.
static func _hidden() -> ShaderMaterial:
	if _hidden_mat == null:
		var sh := Shader.new()
		sh.code = "shader_type spatial;\nrender_mode unshaded;\nvoid vertex() { VERTEX = vec3(0.0); }\nvoid fragment() { discard; }\n"
		_hidden_mat = ShaderMaterial.new()
		_hidden_mat.shader = sh
	return _hidden_mat


static func _mat(c: Color, rough: float = 0.85) -> StandardMaterial3D:
	var key := c.to_html() + str(rough)
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = rough
		_mats[key] = m
	return _mats[key]


# ------------------------------------------------------------------ hats and props

const HEAD_TOP := {"men": Vector3(0.0, 0.2, 0.012), "women": Vector3(0.0, 0.215, 0.0), "legacy": Vector3(0.0, 0.265, 0.01)}

func _add_hat(hat_kind: String, col: Color, band: Color) -> void:
	if _skel == null or _skel.find_bone("Head") < 0:
		return
	var att := BoneAttachment3D.new()
	att.bone_name = "Head"
	_skel.add_child(att)
	var hat := Node3D.new()
	hat.position = HEAD_TOP.get(_rig, HEAD_TOP["men"]) + Vector3(0, _hat_lift, 0)
	att.add_child(hat)
	var s := 1.0
	match hat_kind:
		"fedora":
			hat.add_child(_cyl(0.2 * s, 0.2 * s, 0.016, col, Vector3(0, 0.0, 0)))
			hat.add_child(_cyl(0.108, 0.125, 0.13, col, Vector3(0, 0.07, -0.004)))
			hat.add_child(_cyl(0.127, 0.127, 0.032, band, Vector3(0, 0.026, -0.004)))
			var dent := _cyl(0.07, 0.09, 0.02, col.darkened(0.15), Vector3(0, 0.132, -0.004))
			hat.add_child(dent)
			hat.rotation.x = deg_to_rad(-6.0)
		"bowler":
			hat.add_child(_cyl(0.16, 0.16, 0.014, col, Vector3(0, 0.0, 0)))
			hat.add_child(_dome(0.118, 0.13, col, Vector3(0, 0.012, -0.002)))
			hat.add_child(_cyl(0.12, 0.12, 0.022, band, Vector3(0, 0.018, -0.002)))
		"cap":   # eight-piece flat cap: a low puffy crown pulled forward over a short peak
			var crown := _dome(0.138, 0.1, col, Vector3(0, -0.03, 0.0))
			crown.scale = Vector3(1.0, 1.0, 1.08)
			hat.add_child(crown)
			var top := _cyl(0.145, 0.14, 0.03, col.lightened(0.05), Vector3(0, 0.045, 0.024))
			top.rotation.x = deg_to_rad(9.0)
			hat.add_child(top)
			hat.add_child(_cyl(0.14, 0.14, 0.022, col.darkened(0.08), Vector3(0, -0.03, 0.0)))
			var bill := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.17, 0.012, 0.075)
			bill.mesh = bm
			bill.material_override = _mat(col.darkened(0.22))
			bill.position = Vector3(0, -0.032, 0.16)
			bill.rotation.x = 0.3
			hat.add_child(bill)
		"cop":
			hat.add_child(_cyl(0.13, 0.12, 0.1, col, Vector3(0, 0.02, 0)))
			hat.add_child(_cyl(0.155, 0.155, 0.016, col, Vector3(0, 0.075, 0.0)))
			hat.add_child(_cyl(0.128, 0.128, 0.026, Color("0d0d10"), Vector3(0, -0.012, 0)))
			var visor := MeshInstance3D.new()
			var vm := BoxMesh.new()
			vm.size = Vector3(0.18, 0.012, 0.085)
			visor.mesh = vm
			visor.material_override = _mat(Color("0c0c0c"), 0.3)
			visor.position = Vector3(0, -0.028, 0.13)
			visor.rotation.x = 0.25
			hat.add_child(visor)
			hat.add_child(_cyl(0.02, 0.02, 0.018, Color("c9a54a"), Vector3(0, 0.035, 0.125)))
			hat.position.y -= 0.02
		"cloche":
			hat.add_child(_dome(0.128, 0.13, col, Vector3(0, 0.0, -0.01)))
			hat.add_child(_cyl(0.15, 0.136, 0.03, col, Vector3(0, -0.004, -0.01)))
			hat.add_child(_cyl(0.131, 0.131, 0.022, band, Vector3(0, 0.022, -0.01)))
			hat.rotation.x = deg_to_rad(8.0)
		"watch":
			hat.add_child(_dome(0.122, 0.12, col, Vector3(0, -0.035, -0.006)))
			hat.add_child(_cyl(0.126, 0.126, 0.05, col.darkened(0.1), Vector3(0, -0.03, -0.006)))
	if _rig == "women":
		hat.scale = Vector3.ONE * 0.96


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


## Upper half of a squashed sphere (crowns of bowlers and cloches).
func _dome(r: float, h: float, c: Color, at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = h
	sm.is_hemisphere = true
	sm.radial_segments = 14
	sm.rings = 4
	mi.mesh = sm
	mi.material_override = _mat(c)
	mi.position = at
	return mi


## Shopkeeper's long white apron below the bib (the Farmer overalls dyed white are the bib).
func _add_apron(c: Color) -> void:
	var att := BoneAttachment3D.new()
	att.bone_name = "Hips"
	_skel.add_child(att)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.36, 0.52, 0.02)
	mi.mesh = bm
	mi.material_override = _mat(c, 0.95)
	mi.position = Vector3(0, -0.2, 0.135)
	mi.rotation.x = deg_to_rad(-4.0)
	att.add_child(mi)


## Patrolman's belt with a brass buckle.
func _add_belt() -> void:
	var att := BoneAttachment3D.new()
	att.bone_name = "Hips"
	_skel.add_child(att)
	var belt := _cyl(0.165, 0.165, 0.05, Color("141414"), Vector3(0, 0.06, 0.0))
	belt.scale = Vector3(1.0, 1.0, 0.78)
	att.add_child(belt)
	var buckle := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.05, 0.04, 0.012)
	buckle.mesh = bm
	buckle.material_override = _mat(Color("b8943e"), 0.4)
	buckle.position = Vector3(0, 0.06, 0.13)
	att.add_child(buckle)


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
	_ring.visibility_range_end = 110.0
	add_child(_ring)


func set_ring_visible(v: bool) -> void:
	if _ring:
		_ring.visible = v


# ------------------------------------------------------------------ animation

## Continuous state (walk / run / idle ...). speed in m/s scales the gait.
func set_motion(state: int, speed: float) -> void:
	_speed = speed
	if _oneshot > 0.0:
		return
	if state != anim_state or (_anim and _anim.current_animation == ""):
		play(state)
	elif state == Anim.RUN and _anim and not _legacy and (_anim.current_animation == "q/Sprint") != (speed > 4.8):
		play(state)
	if _anim:
		match anim_state:
			Anim.WALK, Anim.CARRY:
				_anim.speed_scale = clampf(speed / 1.35, 0.6, 1.6)
			Anim.RUN:
				_anim.speed_scale = clampf(speed / 3.6, 0.75, 1.5)
			_:
				_anim.speed_scale = 1.0


func play(state: int) -> void:
	var was_down := anim_state == Anim.DOWN
	anim_state = state
	if _anim == null:
		return
	if was_down and state not in [Anim.DOWN, Anim.DEAD] and not _legacy and _anim.has_animation(&"q/LayToIdle"):
		_anim.play(&"q/LayToIdle", 0.3)   # getting up off the pavement
		_anim.speed_scale = 1.2
		_oneshot = _anim.get_animation(&"q/LayToIdle").length / 1.2
		return
	var clip: StringName = CLIPS.get(state, &"q/Idle")
	if _legacy:
		clip = LEGACY_CLIPS.get(state, &"ual/Idle")
	elif state == Anim.WALK and kind in ["boss", "fed"]:
		clip = &"q/Walk_Formal"
	elif state == Anim.RUN and _speed > 4.8:
		clip = &"q/Sprint"
	if _anim.has_animation(clip):
		_anim.play(clip, 0.25 if state not in [Anim.DOWN, Anim.DEAD] else 0.4)


## One-shot actions that return to the loop afterwards.
func action(name: String) -> void:
	if _anim == null:
		return
	var clip := &""
	if _legacy:
		clip = _legacy_action(name)
	elif ACTIONS.has(name):
		var opts: Array = ACTIONS[name]
		clip = opts[randi() % opts.size()]
	if clip == &"" or not _anim.has_animation(clip):
		return
	var sp: float = FAST.get(name, 1.0)
	_anim.play(clip, 0.1)
	_anim.speed_scale = sp
	_oneshot = _anim.get_animation(clip).length / sp
	if name == "shoot":
		_show_gun(0.7)
	if name in ["down", "die"]:
		anim_state = Anim.DOWN if name == "down" else Anim.DEAD
		_anim.speed_scale = 1.0
		_oneshot = _anim.get_animation(clip).length
		_anim.animation_finished.connect(func(_n: StringName) -> void: play(anim_state), CONNECT_ONE_SHOT)


func _process(delta: float) -> void:
	if _oneshot > 0.0:
		_oneshot -= delta
		if _oneshot <= 0.0 and anim_state not in [Anim.DOWN, Anim.DEAD]:
			play(anim_state)
			set_motion(anim_state, _speed)


func carry(on: bool) -> void:
	if on and _carry == null and _skel:
		_carry = MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.5, 0.36, 0.4)
		(_carry as MeshInstance3D).mesh = bm
		(_carry as MeshInstance3D).material_override = Crate.material()
		_carry.position = Vector3(0, 1.2, 0.42) if not _legacy else Vector3(0, 1.08, 0.36)
		add_child(_carry)
	elif not on and _carry:
		_carry.queue_free()
		_carry = null


func _show_gun(t: float) -> void:
	if _skel == null:
		return
	if _gun == null:
		var att := BoneAttachment3D.new()
		att.bone_name = "handslot.r" if _legacy else "RightHand"
		_skel.add_child(att)
		_gun = Node3D.new()
		att.add_child(_gun)
		var body := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.035, 0.16, 0.05)
		body.mesh = bm
		body.material_override = _mat(Color("151515"), 0.35)
		body.position = Vector3(0, 0.11, 0.02)
		_gun.add_child(body)
		var grip := MeshInstance3D.new()
		var gm := BoxMesh.new()
		gm.size = Vector3(0.03, 0.04, 0.09)
		grip.mesh = gm
		grip.material_override = _mat(Color("3a2a1c"), 0.6)
		grip.position = Vector3(0, 0.05, -0.01)
		_gun.add_child(grip)
		if _legacy:
			_gun.rotation.x = -PI / 2
	_gun.visible = true
	get_tree().create_timer(t).timeout.connect(func() -> void: if is_instance_valid(_gun): _gun.visible = false)


# ------------------------------------------------------------------ fallback: the Woods villagers

const WOODS := {
	"man": ["res://assets/models/characters/Villager.glb", "res://assets/animations/ual_human.res"],
	"woman": ["res://assets/models/characters/Woman.glb", "res://assets/animations/ual_human_woman.res"],
	"elder": ["res://assets/models/characters/Elder.glb", "res://assets/animations/ual_human.res"],
}
const LEGACY_CLIPS := {
	Anim.IDLE: &"ual/Idle", Anim.WALK: &"ual/Walk", Anim.RUN: &"ual/Jog", Anim.CARRY: &"ual/Walk_Carry",
	Anim.TALK: &"ual/Idle_Talking", Anim.DOWN: &"Lie_Idle", Anim.DEAD: &"Death_A_Pose",
	Anim.SIT: &"Sit_Chair_Idle", Anim.ARMS: &"ual/Idle_FoldArms", Anim.CHEER: &"Cheer",
}
var _legacy := false


func _setup_woods(k: String, rng: RandomNumberGenerator, fam: Color, b: String) -> void:
	_legacy = true
	_model = _scene(WOODS[b][0]).instantiate() as Node3D
	add_child(_model)
	_skel = _model.find_child("Skeleton3D", true, false) as Skeleton3D
	_anim = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim and not _anim.has_animation_library(&"ual"):
		var key := "woods:" + b
		if not _libs.has(key):
			var lib := load(WOODS[b][1]) as AnimationLibrary
			for n in lib.get_animation_list():
				if n in [&"Idle", &"Walk", &"Jog", &"Walk_Carry", &"Idle_Talking", &"Idle_FoldArms"]:
					lib.get_animation(n).loop_mode = Animation.LOOP_LINEAR
			_libs[key] = lib
		_anim.add_animation_library(&"ual", _libs[key])
	var suit: Color = _pick(rng, SUITS)
	var tints := {"Shirt": _pick(rng, SHIRTS), "Vest": suit, "Trousers": suit.darkened(0.1), "Hair": _pick(rng, HAIR)}
	if k == "cop":
		tints = {"Shirt": NAVY, "Vest": NAVY.darkened(0.15), "Trousers": NAVY.darkened(0.2)}
	for n in ["Apron"]:
		var node := _model.find_child(n, true, false) as Node3D
		if node and k != "shop":
			node.visible = false
	for node in _model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var src := mi.get_active_material(s) as BaseMaterial3D
			if src and tints.has(src.resource_name):
				mi.set_surface_override_material(s, _dyed(src, tints[src.resource_name]))
	var hat := "cop" if k == "cop" else ("fedora" if k in ["boss", "crew", "fed", "dealer"] else ("cap" if b == "man" else ""))
	if hat != "" and _skel and _skel.find_bone("Head") >= 0:
		_rig = "legacy"
		_add_hat(hat, NAVY.darkened(0.3) if k == "cop" else HATS[0], fam if fam.a > 0 else Color("1a1a1a"))


func _legacy_action(name: String) -> StringName:
	match name:
		"punch": return [&"Unarmed_Melee_Attack_Punch_A", &"Unarmed_Melee_Attack_Punch_B"][randi() % 2]
		"kick": return &"Unarmed_Melee_Attack_Kick"
		"hit": return [&"Hit_A", &"Hit_B"][randi() % 2]
		"shoot": return &"1H_Ranged_Shoot"
		"pickup": return &"PickUp"
		"interact": return &"Interact"
		"yes": return &"ual/Yes"
		"no": return &"ual/No"
		"wave": return &"ual/Wave"
		"cheer": return &"Cheer"
		"down": return &"Death_A"
		"die": return &"Death_B"
	return &""
