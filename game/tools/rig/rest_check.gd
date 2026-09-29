extends SceneTree
## Prints, per profile bone, the angle between its direction (to its first profile child) in two
## skeletons' rests:  godot --headless --script res://tools/rig/rest_check.gd -- <a.glb> <b.fbx>

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var ra := (load(args[0]) as PackedScene).instantiate()
	var rb := (load(args[1]) as PackedScene).instantiate()
	var a := ra.find_child("Skeleton3D", true, false) as Skeleton3D
	var b := rb.find_child("Skeleton3D", true, false) as Skeleton3D
	var prof := SkeletonProfileHumanoid.new()
	for i in prof.bone_size:
		var n := prof.get_bone_name(i)
		var ba := a.find_bone(n)
		var bb := b.find_bone(n)
		if ba < 0 or bb < 0:
			continue
		var da := _dir(a, ba, prof, i)
		var db := _dir(b, bb, prof, i)
		var qa := a.get_bone_global_rest(ba).basis.get_rotation_quaternion()
		var qb := b.get_bone_global_rest(bb).basis.get_rotation_quaternion()
		print("%-22s dir %6.1f deg   rot %6.1f deg   a=%s b=%s" % [n, rad_to_deg(da.angle_to(db)) if da != Vector3.ZERO and db != Vector3.ZERO else -1.0, rad_to_deg(qa.angle_to(qb)), da, db])
	quit()


func _dir(sk: Skeleton3D, bone: int, prof: SkeletonProfile, pi: int) -> Vector3:
	for j in prof.bone_size:
		if prof.get_bone_parent(j) == prof.get_bone_name(pi):
			var c := sk.find_bone(prof.get_bone_name(j))
			if c >= 0:
				return (sk.get_bone_global_rest(c).origin - sk.get_bone_global_rest(bone).origin).normalized()
	for c in sk.get_bone_children(bone):
		return (sk.get_bone_global_rest(c).origin - sk.get_bone_global_rest(bone).origin).normalized()
	return Vector3.ZERO
