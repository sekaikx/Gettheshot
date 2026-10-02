extends Node3D
## 3D interiors close-ups: every trade, the club, the speakeasy, a pool hall, a warehouse, smashed glass,
## padlocked, day and night, seen from the game's tilted camera. Builds the layouts the way World does
## (Interiors.build), then Interiors3D, snaps PNGs and quits.
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --rendering-driver opengl3 --resolution 1600x900 \
##     --path game res://tools/test3d/rooms/test_rooms.tscn
## Env: OUT=prefix (default /tmp/rooms3d), ONLY=name[,name] (a few shots), LIST=1 prints the specimen names,
##      DIST=metres overrides the camera distance, YAW=radians turns the camera, PITCH=degrees.

const KINDS := ["bakery", "butcher", "grocer", "tailor", "barber", "cobbler", "pawnshop", "laundry", "restaurant",
	"cafe", "candy", "hardware", "drugstore", "cigar", "fish", "club", "poolhall", "precinct", "warehouse"]

var rooms: Interiors3D
var cam: Camera3D
var sun: DirectionalLight3D
var env: Environment
var specimens := {}      # name -> {"id","lot","lay","center","size","variant"}
var layouts := {}


func _ready() -> void:
	Game.new_campaign({"seed": 1923, "families": 4}, [{"peer": 1, "name": "Alex", "family_name": "Vitale", "color": "#c42828"}])
	Game.running = false
	_setup_view()
	_make_specimens()
	rooms = Interiors3D.new()
	add_child(rooms)
	rooms.set_process(false)
	rooms.build(layouts)
	for name in specimens:
		var sp: Dictionary = specimens[name]
		var st := {}
		match String(sp["variant"]):
			"broken": st = {"broken": _breakables(sp["lay"])}
			"closed": st = {"closed": true}
			"speak": st = {"stock": 12}
		if not st.is_empty():
			rooms.set_lot_state(int(sp["id"]), st)
	var t0 := Time.get_ticks_msec()
	rooms.build_all_now()
	print("built %d rooms in %d ms: %s" % [layouts.size(), Time.get_ticks_msec() - t0, str(rooms.stats())])
	var big := []
	for name in specimens:
		big.append([rooms.room_verts(int(specimens[name]["id"])), name])
	big.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	print("heaviest rooms (vertices): ", str(big.slice(0, 8)))
	_shots.call_deferred()


func _setup_view() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("a9bccb")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d0d4dc")
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.light_energy = 1.15
	sun.light_color = Color("fff0d8")
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.0
	add_child(sun)
	sun.look_at_from_position(Vector3.ZERO, V3.SUN_DIR, Vector3.UP)
	# a street-grey ground under everything
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(400, 400)
	g.mesh = pm
	g.position = Vector3(100, 0, 100)
	g.material_override = V3.mat(Color("6e6a64"), 0.95)
	add_child(g)
	cam = Camera3D.new()
	cam.fov = V3.CAM_FOV
	cam.near = 0.5
	cam.far = 600.0
	add_child(cam)
	cam.current = true


func _biz_kind(l: Dictionary) -> String:
	for b in Game.biz:
		if int(b["lot"]) == int(l["id"]):
			return String(b["kind"])
	return ""


func _breakables(lay: Dictionary) -> Array:
	var out := []
	for it in lay["items"]:
		if bool(it["breakable"]):
			out.append(int(it["id"]))
	return out


func _src_lot(kind: String) -> Dictionary:
	var plan: CityPlan = Game.plan
	for l in plan.lots:
		if String(l["kind"]) == kind or (kind != "warehouse" and _biz_kind(l) == kind):
			return l
	return {}


## [name, kind, yaw, variant]: variant "" / "broken" / "speak" / "closed"
func _specs() -> Array:
	var out := []
	for k in KINDS:
		out.append([k, k, 0.0, ""])
	for k in ["bakery", "pawnshop", "candy", "tailor", "cigar", "restaurant", "barber", "butcher", "poolhall", "club", "grocer", "drugstore"]:
		out.append([k + "_broken", k, 0.0, "broken"])
	for k in ["bakery", "pawnshop", "poolhall", "club", "warehouse", "cigar"]:
		out.append([k + "_speak", k, 0.0, "speak"])
	for k in ["tailor", "restaurant"]:
		out.append([k + "_closed", k, 0.0, "closed"])
	# the same rooms turned to face north, east and west
	for k in ["bakery", "butcher", "poolhall", "club"]:
		out.append([k + "_n", k, PI, ""])
		out.append([k + "_e", k, PI * 0.5, ""])
		out.append([k + "_w", k, -PI * 0.5, ""])
	return out


func _make_specimens() -> void:
	var n := 0
	var id := 5000
	for sp in _specs():
		var src := _src_lot(String(sp[1]))
		if src.is_empty():
			continue
		var lot: Dictionary = src.duplicate(true)
		lot["id"] = id
		lot["yaw"] = float(sp[2])
		var col := n % 6
		var row := n / 6
		var cx := 14.0 + col * 24.0
		var cz := 14.0 + row * 24.0
		lot["center"] = [cx, cz]
		lot["door"] = [cx, cz + 8.0]
		var lay := Interiors.build(lot, String(sp[1]), String(sp[3]) == "speak")
		layouts[id] = lay
		var r := V3.rect_m(lay["rect"])
		specimens[String(sp[0])] = {"id": id, "lot": lot, "lay": lay, "center": r.get_center(), "size": r.size, "variant": sp[3]}
		id += 1
		n += 1


func _shots() -> void:
	var out := OS.get_environment("OUT")
	if out == "":
		out = "/tmp/rooms3d"
	if OS.get_environment("LIST") != "":
		print("specimens: ", specimens.keys())
	var only: PackedStringArray = OS.get_environment("ONLY").split(",", false)
	var shots := []
	for k in specimens:
		shots.append([k, k, false])
	var night_list := ["bakery", "poolhall", "club", "club_speak", "pawnshop_speak", "warehouse_speak", "cigar", "tailor_closed", "restaurant", "butcher"]
	for k in night_list:
		shots.append([k + "_night", k, true])
	var cam_yaw := float(OS.get_environment("YAW")) if OS.get_environment("YAW") != "" else 0.0
	var pitch := deg_to_rad(float(OS.get_environment("PITCH"))) if OS.get_environment("PITCH") != "" else V3.CAM_PITCH
	for s in shots:
		var name: String = s[0]
		if not only.is_empty() and name not in only:
			continue
		if not specimens.has(s[1]):
			continue
		var sp: Dictionary = specimens[s[1]]
		var night: bool = s[2]
		_light(night)
		rooms.set_night(1.0 if night else 0.0, 0.0)
		rooms.set_inside(int(sp["id"]))
		# only this room on screen: the others would just cost fill time in software GL
		for other in specimens:
			rooms.room_node(int(specimens[other]["id"])).visible = (other == s[1])
		var size: Vector2 = sp["size"]
		var dist := maxf(size.x * 1.25, size.y * 0.95) + 4.0
		if OS.get_environment("DIST") != "":
			dist = float(OS.get_environment("DIST"))
		var focus := Vector3((sp["center"] as Vector2).x, 0.0, (sp["center"] as Vector2).y)
		var off := Vector3(sin(cam_yaw), 0.0, cos(cam_yaw)) * cos(pitch) * dist + Vector3(0, sin(pitch) * dist, 0)
		cam.global_position = focus + off
		cam.look_at(focus + Vector3(0, 0.6, 0), Vector3.UP)
		for f in 6:
			await get_tree().process_frame
		if OS.get_environment("DEBUG") != "":
			var rn := rooms.room_node(int(sp["id"]))
			var mi := rn.get_node("Mesh") as MeshInstance3D
			print("cam ", cam.global_position, " focus ", focus, " room ", rn.global_transform, " vis ", rn.visible, " aabb ", mi.get_aabb(), " lights ", rooms._lights[0].global_position)
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s_%s.png" % [out, name])
		print("shot ", name)
	get_tree().quit()


func _light(night: bool) -> void:
	var n := 1.0 if night else 0.0
	env.background_color = Color("a9bccb").lerp(Color("0c1220"), n)
	env.ambient_light_color = Color("d0d4dc").lerp(Color("303c5a"), n)
	env.ambient_light_energy = lerpf(0.75, 0.55, n)
	sun.light_energy = lerpf(1.15, 0.0, n)
