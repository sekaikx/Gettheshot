extends Node3D
## Every kind of Person side by side, for checking outfits, hats and clips.
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1600x900 --path . res://tools/rig/lineup.tscn -- \
##       --out=/tmp/lineup.png [--view=game|front|close] [--dist=24] [--yaw=0] \
##       [--rows=Idle@0.3,Walk@0.2,Punch_Cross@0.35] [--kinds=boss,crew,...] [--seed=1]
## A row entry is a clip of the q library at a time in seconds, or "anim" to let them play.

const KINDS := ["boss", "crew", "crew", "cop", "fed", "shop", "dock", "recruit", "union", "dealer", "smuggler", "ped:man", "ped:man", "ped:elder", "ped:woman", "ped:woman", "ped:woman"]

var _args := {}


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			_args[a.substr(2, a.find("=") - 2)] = a.substr(a.find("=") + 1)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("141820")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("8a93a8")
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.light_energy = 0.95
	sun.light_color = Color("ffd8a8")
	sun.shadow_enabled = true
	add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 80)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("4a4843")
	gm.roughness = 0.95
	ground.material_override = gm
	add_child(ground)
	var kinds: Array = KINDS
	if _args.has("kinds"):
		kinds = String(_args["kinds"]).split(",")
	var rows: Array = String(_args.get("rows", "Idle@0.4,Walk@0.3,Punch_Cross@0.3")).split(",")
	if _args.has("gallery"):   # one kind per row, one clip per column
		var n := String(_args["gallery"]).split(",").size()
		var ks: Array = []
		for j in n:
			ks.append(kinds[0])
		rows = []
		for k in kinds:
			rows.append(k)
		var per_row := kinds.duplicate()
		kinds = ks
		_args["row_kinds"] = per_row
	var seed0 := int(_args.get("seed", "1"))
	var fam := [Color("c42828"), Color("2f7fc4"), Color("d0a020")]
	var spacing := float(_args.get("spacing", "1.1"))
	for r in rows.size():
		for i in kinds.size():
			var kd: String = kinds[i] if not _args.has("row_kinds") else String(_args["row_kinds"][r])
			var body := ""
			if ":" in kd:
				body = kd.get_slice(":", 1)
				kd = kd.get_slice(":", 0)
			var p := Person.new()
			add_child(p)
			var fc := Color(0, 0, 0, 0)
			if kd in ["boss", "crew"]:
				fc = fam[i % fam.size()]
			p.setup(kd, seed0 * 1000 + i * 77 + 5, fc, body)
			p.position = Vector3((i - kinds.size() * 0.5 + 0.5) * spacing, 0, -r * 2.2)
			var spec: String = rows[r]
			if _args.has("gallery"):
				spec = String(_args["gallery"]).split(",")[i]
			if spec == "anim":
				p.set_motion(Person.Anim.WALK if i % 2 == 0 else Person.Anim.IDLE, 1.35)
				continue
			var clip := spec.get_slice("@", 0)
			var t := float(spec.get_slice("@", 1)) if "@" in spec else 0.0
			var ap := p.find_child("AnimationPlayer", true, false) as AnimationPlayer
			if clip == "hat_check":
				continue
			if ap and ap.has_animation("q/" + clip):
				ap.play("q/" + clip)
				ap.seek(t, true)
				ap.pause()
			if clip == "Walk_Carry":
				p.carry(true)
			if clip == "Pistol_Shoot":
				p._show_gun(100.0)
	var cam := Camera3D.new()
	add_child(cam)
	var view := String(_args.get("view", "game"))
	var mid := Vector3(0, 0.9, -(rows.size() - 1) * 1.1)
	var yaw := deg_to_rad(float(_args.get("yaw", "0")))
	if view == "game":
		var dist := float(_args.get("dist", "24"))
		cam.fov = 40
		var pitch := deg_to_rad(56.0)
		cam.position = mid + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * dist
		cam.look_at(mid)
	elif view == "close":
		cam.fov = 30
		cam.position = mid + Vector3(sin(yaw), 0.35, cos(yaw)) * float(_args.get("dist", "5"))
		cam.look_at(mid + Vector3(0, float(_args.get("lift", "0.5")), 0))
	else:
		cam.fov = 35
		cam.position = mid + Vector3(sin(yaw) * 14.0, 4.0, cos(yaw) * 14.0)
		cam.look_at(mid)
	for k in 8:
		await get_tree().process_frame
	var out := String(_args.get("out", "/tmp/lineup.png"))
	get_viewport().get_texture().get_image().save_png(out)
	print("lineup: saved ", out)
	get_tree().quit()
