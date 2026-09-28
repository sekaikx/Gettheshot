extends SceneTree
## Lists the position tracks (and their range) of one clip:  -- <scene> <clip>

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var root := (load(args[0]) as PackedScene).instantiate()
	var ap := root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var sk := root.find_child("Skeleton3D", true, false) as Skeleton3D
	print("motion_scale ", sk.motion_scale)
	var a := ap.get_animation(args[1])
	for t in a.get_track_count():
		var ty := a.track_get_type(t)
		if ty == Animation.TYPE_POSITION_3D:
			var n := a.track_get_key_count(t)
			print("%s pos keys=%d first=%s last=%s" % [a.track_get_path(t), n, a.position_track_interpolate(t, 0.0), a.position_track_interpolate(t, a.length)])
		elif ty != Animation.TYPE_ROTATION_3D:
			print(a.track_get_path(t), " type ", ty)
	root.free()
	quit()
