extends Node
## Close-ups of the main menu's screens:
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --rendering-driver opengl3 --resolution 1600x900 --path game res://tools/test/test_menu.tscn -- --shot=/tmp/menu
## Saves <shot>_title.png, _new.png, _host.png, _friends.png, _join.png, _lobby.png, _client.png,
## _settings.png, _howto_1.png ... _howto_8.png. --only=title,new limits the list.
## Nothing is saved to the player's profile or settings.

var menu: Control
var prefix := "/tmp/menu"
var only: PackedStringArray = []


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			prefix = a.substr(7)
		if a.begins_with("--only="):
			only = a.substr(7).split(",")
	menu = load("res://scenes/main.tscn").instantiate()
	add_child(menu)
	_run.call_deferred()


func _wait(n: int) -> void:
	for k in n:
		await get_tree().process_frame


func _shot(shot_name: String) -> void:
	await _wait(8)
	get_viewport().get_texture().get_image().save_png("%s_%s.png" % [prefix, shot_name])
	print("SHOT ", shot_name)


func _want(shot_name: String) -> bool:
	return only.is_empty() or shot_name in only


func _run() -> void:
	await _wait(30)
	var scene: MenuTitleScene = menu.get("_scene")
	if _want("title"):
		scene.t = 10.4
		await _shot("title")
	if _want("title2"):
		scene.t = 30.0
		(menu.get("_items") as Control).get_child(2).grab_focus()
		await _shot("title2")
	if _want("new"):
		menu.set("_host_mode", false)
		menu.call("_show_page", "new")
		await _shot("new")
	if _want("host"):
		menu.set("_host_mode", true)
		menu.call("_show_page", "new")
		await _shot("host")
	if _want("friends"):
		menu.call("_show_page", "friends")
		await _shot("friends")
	if _want("join"):
		menu.call("_show_page", "join")
		await _shot("join")
	if _want("lobby"):
		Net.roster = {1: {"name": "Alex", "family_name": "Vitale", "color": "#c42828", "join": -1},
			2: {"name": "Jess", "family_name": "O'Hara", "color": "#3ca05a", "join": -1},
			3: {"name": "Marco", "family_name": "Russo", "color": "#3c6ec8", "join": 0}}
		menu.call("_show_lobby", true)
		await _shot("lobby")
	if _want("client"):
		menu.call("_show_lobby", false)
		await _shot("client")
	Net.roster = {}
	if _want("settings"):
		menu.call("_show_page", "settings")
		await _shot("settings")
	if _want("howto"):
		menu.call("_show_page", "howto")
		var howto: MenuHowTo = menu.get("_howto")
		for k in MenuHowTo.CARDS.size():
			howto.show_page(k)
			await _shot("howto_%d" % (k + 1))
	print("MENUTEST OK")
	get_tree().quit()
