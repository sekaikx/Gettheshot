extends Node3D
## Source mannequin vs retargeted Person, same clip and time, side by side.
##   ... res://tools/rig/compare.tscn -- --out=/tmp/c.png --clip=Idle --src=Idle --t=0.5 [--srcfile=ual1]

func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			args[a.substr(2, a.find("=") - 2)] = a.substr(a.find("=") + 1)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("50505a")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("9098a8")
	e.ambient_light_energy = 0.6
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 25, 0)
	add_child(sun)
	var t := float(args.get("t", "0.5"))
	var files := {"ual1": "res://tools/rig/ual_src/UAL1_Standard.glb", "ual2": "res://tools/rig/ual_src/UAL2_Standard.glb", "qw": "res://tools/rig/ual_src/QuatWoman_Anims.fbx"}
	var src := (load(files[args.get("srcfile", "ual1")]) as PackedScene).instantiate() as Node3D
	add_child(src)
	src.position = Vector3(-0.9, 0, 0)
	var ap := src.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var sclip := String(args.get("src", "Idle"))
	if ap.has_animation(sclip):
		ap.play(sclip)
		ap.seek(t, true)
		ap.pause()
	var kinds := String(args.get("kinds", "boss,ped:woman")).split(",")
	for i in kinds.size():
		var p := Person.new()
		add_child(p)
		var kd := kinds[i]
		p.setup(kd.get_slice(":", 0), 7 + i, Color(0, 0, 0, 0), kd.get_slice(":", 1) if ":" in kd else "")
		p.position = Vector3(0.9 * i, 0, 0)
		var pap := p.find_child("AnimationPlayer", true, false) as AnimationPlayer
		var c := "q/" + String(args.get("clip", "Idle"))
		if c == "q/REST":
			pap.stop()
			(p.find_child("Skeleton3D", true, false) as Skeleton3D).reset_bone_poses()
		elif pap.has_animation(c):
			pap.play(c)
			pap.seek(t, true)
			pap.pause()
	var cam := Camera3D.new()
	add_child(cam)
	cam.fov = 35
	var yaw := deg_to_rad(float(args.get("yaw", "0")))
	cam.position = Vector3(sin(yaw) * 5.5, 1.3, cos(yaw) * 5.5)
	cam.look_at(Vector3(0, 0.9, 0))
	for k in 6:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(String(args.get("out", "/tmp/c.png")))
	get_tree().quit()
