extends Node
## The whole game in 3D, in a few seconds: starts a solo campaign (seed 1923), builds the World with its
## View3D and HUD, then puts the player at a few spots at chosen hours and weather and saves a
## screenshot of each (HUD included). For checking the 3D street, the night, the rain, buildings in
## the way of the camera and the HUD over it, without playing through the autotest.
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --rendering-driver opengl3 --resolution 1600x900 \
##     --path game res://tools/test3d/street/test_street.tscn
## Env: OUT_DIR=dir (default /tmp/street3d), SHOTS=name,name (default all).

# name, where ("hq_door", "hq_safe", "shop_door", "pier", "behind_hq", or [x, z] metres), clock (0 dawn,
# 0.25 noon, 0.5 dusk, 0.75 midnight), weather, zoom (CameraRig.user_zoom)
var shots := [
	["day", "hq_door", 0.25, "clear", 1.0],
	["dusk", "hq_door", 0.47, "clear", 1.0],
	["night", "hq_door", 0.75, "clear", 1.0],
	["night_rain", "hq_door", 0.75, "rain", 1.0],
	["fog", "hq_door", 0.3, "fog", 1.0],
	["zoom_out", "hq_door", 0.25, "clear", 0.45],
	["behind", "behind_hq", 0.25, "clear", 1.0],
	["behind_far", "behind_hq", 0.25, "clear", 0.6],
	["inside", "hq_safe", 0.25, "clear", 1.0],
	["inside_night", "hq_safe", 0.75, "clear", 1.0],
	["shop", "shop_door", 0.3, "clear", 1.0],
	["pier", "pier", 0.25, "clear", 1.0],
	["pier_night", "pier", 0.78, "clear", 1.0],
]

var world: World
var _out := "/tmp/street3d"
var _only: Array = []


func _ready() -> void:
	if OS.get_environment("OUT_DIR") != "":
		_out = OS.get_environment("OUT_DIR")
	DirAccess.make_dir_recursive_absolute(_out)
	if OS.get_environment("SHOTS") != "":
		_only = Array(OS.get_environment("SHOTS").split(","))
	Net.my_info = {"name": "Alex", "family_name": "Vitale", "color": "#c42828", "join": -1}
	Net.solo()
	Game.new_campaign({"seed": 1923, "families": 4, "month_seconds": 100000.0, "start_month": 72,
		"end_month": Game.REPEAL_MONTH, "tutorial": false},
		[{"peer": 1, "name": "Alex", "family_name": "Vitale", "color": "#c42828", "join": -1}])
	world = (load("res://scenes/world.tscn") as PackedScene).instantiate()
	add_child(world)
	while world.local_actor == null or world.hud == null:
		await get_tree().process_frame
	for i in 30:
		await get_tree().process_frame
	if world.hud.is_modal():
		world.hud.escape()
	for s in shots:
		if not _only.is_empty() and not _only.has(s[0]):
			continue
		await _take(s)
	print("STREET3D DONE")
	get_tree().quit()


func _take(s: Array) -> void:
	var name: String = s[0]
	Game.clock = float(s[2])
	world.weather = String(s[3])
	world.cam.user_zoom = float(s[4])
	world.local_actor.place(_spot(s[1]), 0.0)
	world.cam.snap()
	if world.view3d:
		world.view3d.snap()
	for i in 24:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, name])
	print("shot ", name, " inside=", world.inside_lot)


func _spot(where) -> Vector2:
	if where is Array:
		return Vector2(float(where[0]), float(where[1])) * W.M
	var hq := Game.biz_by_id(int(Game.fam(0)["hq"]))
	match String(where):
		"hq_door":
			return W.door(hq) + W.front_dir(float(hq["yaw"])) * 3.0 * W.M
		"behind_hq":
			# the street behind the club: the club and its neighbours stand between the camera and you
			return W.door(hq) - W.front_dir(float(hq["yaw"])) * 16.0 * W.M
		"hq_safe":
			var lay: Dictionary = world.layout_of_biz(int(hq["id"]))
			return lay["spots"].get("safe", (lay["back"] as Rect2).get_center())
		"shop_door":
			for b in Game.biz:
				if int(b["protector"]) < 0 and int(b["owned_by"]) < 0 and not String(b["kind"]) in ["club", "precinct", "poolhall", "warehouse"]:
					return W.door(b) + W.front_dir(float(b["yaw"])) * 2.5 * W.M
		"pier":
			return Vector2(CityPlan.PITCH * 6 + 30.0, 34.0) * W.M
	return W.door(hq)
