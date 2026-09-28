extends SceneTree
func _initialize() -> void:
	for p in OS.get_cmdline_user_args():
		var sc := load(p) as PackedScene
		var r := sc.instantiate()
		print("==== ", p)
		_walk(r, 0)
		var sk := r.find_child("*", true, false)
		for s in r.find_children("*", "Skeleton3D", true, false):
			var k := s as Skeleton3D
			var names := []
			for b in k.get_bone_count():
				names.append("%s<%s" % [k.get_bone_name(b), k.get_bone_name(k.get_bone_parent(b)) if k.get_bone_parent(b) >= 0 else "-"])
			print("bones(%d) ms=%.3f: %s" % [k.get_bone_count(), k.motion_scale, ", ".join(names)])
			var h := k.find_bone("Head")
			if h >= 0: print("head global rest ", k.get_bone_global_rest(h).origin)
		for a in r.find_children("*", "AnimationPlayer", true, false):
			var ap := a as AnimationPlayer
			print("anims: ", ap.get_animation_list())
		r.free()
	quit()
func _walk(n: Node, d: int) -> void:
	var extra := ""
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		var tris := 0
		var mats := []
		for s in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s)
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			tris += idx.size() / 3 if idx.size() > 0 else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
			var m := mi.get_active_material(s)
			mats.append((m.resource_name + ":" + (m as BaseMaterial3D).albedo_color.to_html(false) + (":T" if (m as BaseMaterial3D).albedo_texture else "")) if m else "null")
		extra = " tris=%d mats=%s aabb=%s" % [tris, mats, mi.get_aabb()]
	if d < 6:
		print("  ".repeat(d), n.name, " [", n.get_class(), "]", extra)
	for c in n.get_children():
		_walk(c, d + 1)
