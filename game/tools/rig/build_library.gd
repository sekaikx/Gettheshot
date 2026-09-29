extends SceneTree
## Builds assets/animations/quat_men.res and quat_women.res: the animation clips the street people
## play, retargeted onto the Quaternius "Humanoid Rig" skeletons of Ultimate Modular Men / Women.
##
## Sources (CC0, Quaternius; not committed, see tools/rig/README.md for where they come from):
##   tools/rig/ual_src/UAL1_Standard.glb, UAL2_Standard.glb   Universal Animation Library 1 + 2
##   tools/rig/ual_src/QuatWoman_Anims.fbx                    Modular Women "Casual" (own rig + clips:
##                                                             the kick, the wave, the fall)
## Every rig is imported with a BoneMap to SkeletonProfileHumanoid and the rest fixer (see
## tools/rig/patch_imports.py), so all skeletons share bone names and a T-pose rest. The clips are
## then re-solved in world space: every target bone takes the world rotation delta (pose * rest^-1)
## of the same-named source bone and applies it to its own rest. That survives different bone
## rolls and hierarchies (the Women rig hangs its legs from Root, the animated rig its feet).
## Hips translation is copied relative to rest in normalised units (Skeleton3D.motion_scale).
## A few clips are synthesised (Cheer, the lying poses).
##
##   godot --headless --import
##   godot --headless --script res://tools/rig/build_library.gd

const SOURCES := {
	"ual1": "res://tools/rig/ual_src/UAL1_Standard.glb",
	"ual2": "res://tools/rig/ual_src/UAL2_Standard.glb",
	"qw": "res://tools/rig/ual_src/QuatWoman_Anims.fbx",
}
const TARGETS := {
	"men": ["res://assets/models/characters/quaternius/men/Suit.fbx", "res://assets/animations/quat_men.res"],
	"women": ["res://assets/models/characters/quaternius/women/Formal.fbx", "res://assets/animations/quat_women.res"],
}
const FPS := 30.0

## out clip -> [source, clip, loop]
const CLIPS := {
	&"Idle": ["ual1", &"Idle", true],
	&"Walk": ["ual1", &"Walk", true],
	&"Walk_Formal": ["ual1", &"Walk_Formal", true],
	&"Jog": ["ual1", &"Jog_Fwd", true],
	&"Sprint": ["ual1", &"Sprint", true],
	&"Walk_Carry": ["ual2", &"Walk_Carry", true],
	&"Idle_Talking": ["ual1", &"Idle_Talking", true],
	&"Idle_FoldArms": ["ual2", &"Idle_FoldArms", true],
	&"Idle_Rail": ["ual2", &"Idle_Rail", true],
	&"Sitting_Idle": ["ual1", &"Sitting_Idle", true],
	&"Pistol_Idle": ["ual1", &"Pistol_Idle", true],
	&"Punch_Jab": ["ual1", &"Punch_Jab", false],
	&"Punch_Cross": ["ual1", &"Punch_Cross", false],
	&"Melee_Hook": ["ual2", &"Melee_Hook", false],
	&"Kick": ["qw", &"CharacterArmature|Kick_Right", false],
	&"Hit_Chest": ["ual1", &"Hit_Chest", false],
	&"Hit_Head": ["ual1", &"Hit_Head", false],
	&"Hit_Knockback": ["ual2", &"Hit_Knockback", false],
	&"PickUp": ["ual1", &"PickUp_Table", false],
	&"Interact": ["ual1", &"Interact", false],
	&"Pistol_Shoot": ["ual1", &"Pistol_Shoot", false],
	&"Yes": ["ual2", &"Yes", false],
	&"No": ["ual2", &"Idle_No", false],
	&"Wave": ["qw", &"CharacterArmature|Wave", false],
	&"Consume": ["ual2", &"Consume", false],
	&"Death": ["ual1", &"Death01", false],
	&"Fall": ["qw", &"CharacterArmature|Death", false],
	&"LayToIdle": ["ual2", &"LayToIdle", false],
}
## Static loops made from the last frame of a clip: lying knocked out / dead.
const HOLDS := {&"Lie_Down": &"Fall", &"Lie_Dead": &"Death"}
## Clips whose source has finger tracks worth keeping (others get the fingers at rest -> relaxed).
const NO_FINGERS_FROM := ["qw"]


func _initialize() -> void:
	var srcs := {}
	for k: String in SOURCES:
		if not ResourceLoader.exists(SOURCES[k]):
			push_error("build_library: missing %s (see tools/rig/README.md)" % SOURCES[k])
			quit(1)
			return
		var root := (load(SOURCES[k]) as PackedScene).instantiate()
		srcs[k] = [root, root.find_child("Skeleton3D", true, false), root.find_child("AnimationPlayer", true, false)]
	for tk: String in TARGETS:
		var troot := (load(TARGETS[tk][0]) as PackedScene).instantiate()
		var tsk := troot.find_child("Skeleton3D", true, false) as Skeleton3D
		var lib := AnimationLibrary.new()
		for out: StringName in CLIPS:
			var spec: Array = CLIPS[out]
			var s: Array = srcs[spec[0]]
			var ap := s[2] as AnimationPlayer
			if not ap.has_animation(spec[1]):
				push_warning("no clip %s in %s" % [spec[1], spec[0]])
				continue
			if _bias.is_empty() and spec[0] != "qw":
				_bias = _posture_bias(srcs["ual1"][2].get_animation(&"Idle"), srcs["ual1"][1])
			var anim := _retarget(ap.get_animation(spec[1]), s[1], tsk, spec[0] not in NO_FINGERS_FROM, _bias if spec[0] != "qw" else {})
			anim.loop_mode = Animation.LOOP_LINEAR if spec[2] else Animation.LOOP_NONE
			lib.add_animation(out, anim)
		for out: StringName in HOLDS:
			lib.add_animation(out, _hold(lib.get_animation(HOLDS[out])))
		lib.add_animation(&"Cheer", _cheer(lib.get_animation(&"Idle"), tsk))
		for n in lib.get_animation_list():
			var a := lib.get_animation(n)
			print("  %-5s %-14s %.2fs %3d tracks%s" % [tk, n, a.length, a.get_track_count(), "  loop" if a.loop_mode != Animation.LOOP_NONE else ""])
		var err := ResourceSaver.save(lib, TARGETS[tk][1], ResourceSaver.FLAG_COMPRESS)
		print("build_library: %s -> %s (%d clips, %s)" % [tk, TARGETS[tk][1], lib.get_animation_list().size(), error_string(err)])
		troot.free()
	for k: String in srcs:
		(srcs[k][0] as Node).free()
	quit()


func _rot_tracks(anim: Animation, sk: Skeleton3D) -> Dictionary:
	var out := {}
	for t in anim.get_track_count():
		if anim.track_get_type(t) != Animation.TYPE_ROTATION_3D:
			continue
		var b := sk.find_bone(String(anim.track_get_path(t).get_concatenated_subnames()))
		if b >= 0:
			out[b] = t
	return out


func _pos_track(anim: Animation, bone: String) -> int:
	for t in anim.get_track_count():
		if anim.track_get_type(t) == Animation.TYPE_POSITION_3D and String(anim.track_get_path(t).get_concatenated_subnames()) == bone:
			return t
	return -1


static func _is_finger(n: String) -> bool:
	for f in ["Thumb", "Index", "Middle", "Ring", "Little"]:
		if n.begins_with("Left" + f) or n.begins_with("Right" + f):
			return true
	return false


## Bones whose rest direction is matched to the source's before copying (not Hips / Head / Hand:
## there the difference is where the rigger put the joint, not the pose).
const CALIBRATE := ["Spine", "Chest", "UpperChest", "Neck", "Shoulder", "UpperArm", "LowerArm", "UpperLeg", "LowerLeg", "Foot"]


## Rest direction of a bone towards its first profile child (skeleton space).
func _dir(sk: Skeleton3D, bone: int) -> Vector3:
	var n := sk.get_bone_name(bone)
	var pi := _profile.find_bone(n)
	for j in _profile.bone_size:
		if pi >= 0 and _profile.get_bone_parent(j) == StringName(n):
			var c := sk.find_bone(_profile.get_bone_name(j))
			if c >= 0:
				return (sk.get_bone_global_rest(c).origin - sk.get_bone_global_rest(bone).origin).normalized()
	return Vector3.ZERO


## Profile parent of a profile bone ("" when not a profile bone).
var _profile := SkeletonProfileHumanoid.new()

func _profile_parent(n: String) -> String:
	var i := _profile.find_bone(n)
	if i < 0:
		return ""
	return String(_profile.get_bone_parent(i))


## The UAL mannequin idles with its chest rounded and its head hung ~25 deg; on a man in a suit
## and hat that reads as staring at his shoes. That share of its idle stance (world rotation per
## bone, by name) is taken out of every UAL clip; the motion stays.
const POSTURE := {"Spine": 0.4, "Chest": 0.5, "UpperChest": 0.6, "Neck": 0.7, "Head": 0.75}
var _bias := {}

func _posture_bias(idle: Animation, ssk: Skeleton3D) -> Dictionary:
	var rot := _rot_tracks(idle, ssk)
	var g := {}
	var out := {}
	for b in _ordered(ssk):
		var loc: Quaternion = idle.rotation_track_interpolate(rot[b], 0.0) if rot.has(b) else ssk.get_bone_rest(b).basis.get_rotation_quaternion()
		var p := ssk.get_bone_parent(b)
		g[b] = (g[p] as Quaternion) * loc if p >= 0 else loc
		var n := ssk.get_bone_name(b)
		if POSTURE.has(n):
			var d: Quaternion = (g[b] as Quaternion) * ssk.get_bone_global_rest(b).basis.get_rotation_quaternion().inverse()
			out[n] = Quaternion.IDENTITY.slerp(d, POSTURE[n])
	return out


func _retarget(src: Animation, ssk: Skeleton3D, tsk: Skeleton3D, fingers: bool, bias: Dictionary = {}) -> Animation:
	var s_rot := _rot_tracks(src, ssk)
	var s_hips_pos := _pos_track(src, "Hips")
	var s_order := _ordered(ssk)
	var t_order := _ordered(tsk)
	var s_rest_g := {}
	for b in ssk.get_bone_count():
		s_rest_g[b] = ssk.get_bone_global_rest(b).basis.get_rotation_quaternion()
	var t_rest_g := {}
	for b in tsk.get_bone_count():
		t_rest_g[b] = tsk.get_bone_global_rest(b)
	# where the rigs' bones point differently at rest (the mannequin's spine leans back, its
	# forearms straighter), swing the target's rest onto the source's direction first
	var swing := {}
	for b in tsk.get_bone_count():
		var n := tsk.get_bone_name(b)
		var sb := ssk.find_bone(n)
		if sb < 0 or not n.trim_prefix("Left").trim_prefix("Right") in CALIBRATE:
			continue
		var dt := _dir(tsk, b)
		var ds := _dir(ssk, sb)
		if dt != Vector3.ZERO and ds != Vector3.ZERO:
			swing[b] = Quaternion(dt, ds)
	# target bone -> source bone
	var driven := {}
	for b in tsk.get_bone_count():
		var n := tsk.get_bone_name(b)
		if n == "Root" or _profile.find_bone(n) < 0:
			continue
		if _is_finger(n) and not fingers:
			continue
		var sb := ssk.find_bone(n)
		if sb >= 0:
			driven[b] = sb
	# bones hung from a different parent than the profile says (Women: legs from Root) get a
	# position track that keeps them where the profile parent carries them
	var vparent := {}
	for b in tsk.get_bone_count():
		var pp := _profile_parent(tsk.get_bone_name(b))
		var par := tsk.get_bone_parent(b)
		if pp != "" and par >= 0 and tsk.get_bone_name(par) != pp and tsk.find_bone(pp) >= 0:
			vparent[b] = tsk.find_bone(pp)
	if not vparent.is_empty():   # solve those subtrees after their profile parents
		var first := PackedInt32Array()
		var last := PackedInt32Array()
		for b in t_order:
			var x := b
			var late := false
			while x >= 0:
				if vparent.has(x):
					late = true
					break
				x = tsk.get_bone_parent(x)
			if late:
				last.append(b)
			else:
				first.append(b)
		t_order = first + last
	var anim := Animation.new()
	anim.length = src.length
	var rtr := {}
	for b in tsk.get_bone_count():
		var tr := anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(tr, NodePath("%%Skeleton3D:%s" % tsk.get_bone_name(b)))
		rtr[b] = tr
	var ptr := {}
	for b: int in vparent:
		var tr := anim.add_track(Animation.TYPE_POSITION_3D)
		anim.track_set_path(tr, NodePath("%%Skeleton3D:%s" % tsk.get_bone_name(b)))
		ptr[b] = tr
	var t_hips := tsk.find_bone("Hips")
	var s_hips := ssk.find_bone("Hips")
	var hips_tr := anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(hips_tr, NodePath("%Skeleton3D:Hips"))
	# the hips follow the source hips' world position (whichever bone of the chain moves them:
	# the UAL moves Hips, the Quaternius rig its Body bone), relative to rest, normalised
	var s_pos := {}
	for t in src.get_track_count():
		if src.track_get_type(t) == Animation.TYPE_POSITION_3D:
			var pb := ssk.find_bone(String(src.track_get_path(t).get_concatenated_subnames()))
			if pb >= 0:
				s_pos[pb] = t
	var s_chain: Array[int] = []
	var x := s_hips
	while x >= 0:
		s_chain.push_front(x)
		x = ssk.get_bone_parent(x)
	var s_rest_hips_g := ssk.get_bone_global_rest(s_hips).origin
	var t_rest_hips_g := tsk.get_bone_global_rest(t_hips).origin
	var frames := maxi(1, ceili(src.length * FPS))
	for f in frames + 1:
		var time := minf(f / FPS, src.length)
		# source pose, world rotations
		var sg := {}
		for b in s_order:
			var loc: Quaternion = src.rotation_track_interpolate(s_rot[b], time) if s_rot.has(b) else ssk.get_bone_rest(b).basis.get_rotation_quaternion()
			var p := ssk.get_bone_parent(b)
			sg[b] = (sg[p] as Quaternion) * loc if p >= 0 else loc
		var ht := Transform3D.IDENTITY
		for cb in s_chain:
			var o := ssk.get_bone_rest(cb).origin
			if s_pos.has(cb):
				o = src.position_track_interpolate(s_pos[cb], time) * ssk.motion_scale
			var r: Quaternion = src.rotation_track_interpolate(s_rot[cb], time) if s_rot.has(cb) else ssk.get_bone_rest(cb).basis.get_rotation_quaternion()
			ht = ht * Transform3D(Basis(r), o)
		var hips_off := (ht.origin - s_rest_hips_g) / ssk.motion_scale
		# target pose, world transforms (skeleton space, un-normalised)
		var tg := {}
		for b in t_order:
			var p := tsk.get_bone_parent(b)
			var pg: Transform3D = tg[p] if p >= 0 else Transform3D.IDENTITY
			var local_rest := tsk.get_bone_rest(b)
			var g := pg * local_rest
			if b == t_hips:
				g.origin = t_rest_hips_g + hips_off * tsk.motion_scale
			if driven.has(b):
				var sb: int = driven[b]
				var delta: Quaternion = (sg[sb] as Quaternion) * (s_rest_g[sb] as Quaternion).inverse()
				if bias.has(tsk.get_bone_name(b)):
					delta = delta * (bias[tsk.get_bone_name(b)] as Quaternion).inverse()
				g.basis = Basis(delta * (swing.get(b, Quaternion.IDENTITY) as Quaternion) * (t_rest_g[b] as Transform3D).basis.get_rotation_quaternion())
			if vparent.has(b):
				var vp: int = vparent[b]
				var rel := (t_rest_g[vp] as Transform3D).affine_inverse() * (t_rest_g[b] as Transform3D)
				g.origin = (tg[vp] as Transform3D) * rel.origin
			tg[b] = g
			var local := pg.affine_inverse() * g
			anim.rotation_track_insert_key(rtr[b], time, local.basis.get_rotation_quaternion().normalized())
			if ptr.has(b):
				anim.position_track_insert_key(ptr[b], time, local.origin / tsk.motion_scale)
		var hp := tsk.get_bone_parent(t_hips)
		var hpg: Transform3D = tg[hp] if hp >= 0 else Transform3D.IDENTITY
		anim.position_track_insert_key(hips_tr, time, (hpg.affine_inverse() * (tg[t_hips] as Transform3D).origin) / tsk.motion_scale)
	return anim


## One-second loop of a clip's last frame.
func _hold(src: Animation) -> Animation:
	var a := Animation.new()
	a.length = 1.0
	a.loop_mode = Animation.LOOP_LINEAR
	for t in src.get_track_count():
		var tr := a.add_track(src.track_get_type(t))
		a.track_set_path(tr, src.track_get_path(t))
		var v: Variant
		if src.track_get_type(t) == Animation.TYPE_ROTATION_3D:
			v = src.rotation_track_interpolate(t, src.length)
			a.rotation_track_insert_key(tr, 0.0, v)
		elif src.track_get_type(t) == Animation.TYPE_POSITION_3D:
			v = src.position_track_interpolate(t, src.length)
			a.position_track_insert_key(tr, 0.0, v)
	return a


## Both fists up, pumped twice, over the idle (the libraries have no cheer).
func _cheer(idle: Animation, tsk: Skeleton3D) -> Animation:
	var a := Animation.new()
	a.length = 1.6
	var order := _ordered(tsk)
	var tracks := {}
	for t in idle.get_track_count():
		var tr := a.add_track(idle.track_get_type(t))
		a.track_set_path(tr, idle.track_get_path(t))
		var bn := String(idle.track_get_path(t).get_concatenated_subnames())
		if idle.track_get_type(t) == Animation.TYPE_ROTATION_3D:
			tracks[tsk.find_bone(bn)] = [t, tr]
		else:
			for f in 17:
				a.position_track_insert_key(tr, f * 0.1, idle.position_track_interpolate(t, fmod(f * 0.1, idle.length)))
	var ups := {}
	for side in ["Left", "Right"]:
		ups[tsk.find_bone(side + "UpperArm")] = [side, "up"]
		ups[tsk.find_bone(side + "LowerArm")] = [side, "fore"]
		ups[tsk.find_bone(side + "Hand")] = [side, "hand"]
	for f in 17:
		var time := f * 0.1
		var raise := clampf(time / 0.25, 0.0, 1.0) * clampf((1.6 - time) / 0.3, 0.0, 1.0)
		var pump := 0.5 + 0.5 * cos(time / 1.6 * TAU * 2.0)
		var g := {}
		for b in order:
			var p := tsk.get_bone_parent(b)
			var loc: Quaternion = idle.rotation_track_interpolate(tracks[b][0], fmod(time, idle.length)) if tracks.has(b) else tsk.get_bone_rest(b).basis.get_rotation_quaternion()
			var pg: Quaternion = g[p] if p >= 0 else Quaternion.IDENTITY
			var gb: Quaternion = pg * loc
			if ups.has(b) and raise > 0.0:
				var side: float = 1.0 if ups[b][0] == "Left" else -1.0
				var rest_g := tsk.get_bone_global_rest(b).basis.get_rotation_quaternion()
				var target: Quaternion
				match ups[b][1]:
					"up":   # T-pose arm -> up and a little forward, pumping
						target = Quaternion(Vector3.FORWARD, -side * deg_to_rad(lerpf(55.0, 80.0, pump))) * Quaternion(Vector3.UP, side * deg_to_rad(-15.0))
						target = target * rest_g
					"fore":
						target = (g[p] as Quaternion) * (tsk.get_bone_global_rest(p).basis.get_rotation_quaternion().inverse() * rest_g)
						target = Quaternion(Vector3.FORWARD, -side * deg_to_rad(lerpf(35.0, 10.0, pump))) * target
					_:
						target = (g[p] as Quaternion) * (tsk.get_bone_global_rest(p).basis.get_rotation_quaternion().inverse() * rest_g)
				gb = gb.slerp(target, raise)
			g[b] = gb
			if tracks.has(b):
				a.rotation_track_insert_key(tracks[b][1], time, (pg.inverse() * gb).normalized())
	return a


var _order_cache := {}

func _ordered(sk: Skeleton3D) -> PackedInt32Array:
	if _order_cache.has(sk):
		return _order_cache[sk]
	var order := PackedInt32Array()
	var stack: Array[int] = []
	for b in sk.get_parentless_bones():
		stack.append(b)
	while not stack.is_empty():
		var b: int = stack.pop_back()
		order.append(b)
		for c in sk.get_bone_children(b):
			stack.append(c)
	_order_cache[sk] = order
	return order
