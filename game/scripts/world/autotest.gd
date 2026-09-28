extends Node
## Run with: godot res://scenes/main.tscn -- --autotest --shot=/tmp/a.png [--script=walk]
## Plays solo, drives the boss around a bit, saves screenshots and quits.

var world: Node
var _t := 0.0
var _shots: Array = []
var _out := "/tmp/famiglia"
var _done := false


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			_out = a.substr(7)
	_shots = [[5.5, "street"], [7.5, "dialog"], [10.5, "zoom"], [14.5, "night"], [17.0, "map"], [20.0, "family"]]


func _process(delta: float) -> void:
	_t += delta
	if _t < 0.2 and world.hud.is_modal():
		world.hud.toggle_help()
		if OS.get_environment("NOGLOW") != "": world.env.glow_enabled = false
		if OS.get_environment("NOFACADE") != "": world.city.facade_mat.shader = null
	var a: Actor = world.local_actor
	world.controller.auto_move = Vector2(0.3, -1.0) if (_t > 1.5 and _t < 4.5) else Vector2.ZERO
	if _t > 6.2 and _t < 6.3 and world.controller.focus.is_empty() == false:
		world.controller._use()
	if _t > 8.5 and _t < 8.6:
		world.hud.close_dialog()
		world.cam.dist_goal = 42.0
	if _t > 11.0 and _t < 11.1:
		world.cam.dist_goal = 22.0
		Game.clock = 0.72
	if _t > 16.0 and _t < 16.1:
		world.hud.toggle_map()
	if _t > 19.0 and _t < 19.1:
		world.hud.toggle_map()
		world.hud.toggle_family()
	if not _shots.is_empty() and _t >= _shots[0][0]:
		var s: Array = _shots.pop_front()
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s_%s.png" % [_out, s[1]])
		print("shot ", s[1])
	if _shots.is_empty() and not _done:
		_done = true
		print("AUTOTEST OK month=", Game.month, " families=", Game.families.size(), " actors=", world.actors.size())
		get_tree().quit()
