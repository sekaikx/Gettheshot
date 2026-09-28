extends Node
## godot res://scenes/main.tscn -- --autotest --shot=/tmp/a
## Plays solo: walks, talks to a shop, shoots, sends men to Chicago, runs a convoy, lets months
## pass with the AI families acting, and saves screenshots of each screen.

var world: Node
var _t := 0.0
var _out := "/tmp/famiglia"
var _steps: Array = []
var _log: Array = []


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			_out = a.substr(7)
	_steps = [
		[0.3, func() -> void:
			if world.hud.is_modal(): world.hud.toggle_help()],
		[1.5, func() -> void: world.controller.auto_move = Vector2(0.3, -1.0)],
		[4.5, func() -> void: world.controller.auto_move = Vector2.ZERO],
		[5.0, func() -> void: _shot("street")],
		[5.2, func() -> void:
			var f: Dictionary = world.controller.focus
			if not f.is_empty(): world.controller._use()],
		[6.0, func() -> void: _shot("dialog")],
		[6.2, func() -> void:
			world.hud.close_dialog()
			var me: Actor = world.local_actor
			var b := _nearest_shop(me.position)
			Net.to_host("act", ["pitch", b["id"], 0])
			Net.to_host("act", ["lean", b["id"], 0])
			Game.player(1)["wallet"] += 5000
			Game.fam(0)["dirty"] += 8000
			Game.fam(0)["clean"] += 5000
			Net.to_host("shoot", [])
			Net.to_host("nation", ["send", "chi", 4, 1, -1])
			Net.to_host("nation", ["convoy", "champlain", 50])
			Net.to_host("nation", ["ambush", "detroit_river", 3])
			Net.to_host("nation", ["route", "rum_row_atl"])],
		[6.6, func() -> void:
			var cop: Actor = world.actor("k0")
			world.local_actor.set_carry(true)
			world.local_actor.place(cop.position + Vector3(2, 0, 0))],
		[7.0, func() -> void:
			Game.cfg["month_seconds"] = 1.2],
		[13.0, func() -> void:
			Game.cfg["month_seconds"] = 60.0
			Net.to_host("nation", ["hit", "chi", 1])
			world.cam.dist_goal = 40.0],
		[15.0, func() -> void: _shot("zoom")],
		[15.2, func() -> void:
			Game.clock = 0.74
			world.cam.dist_goal = 18.0],
		[18.0, func() -> void: _shot("night")],
		[18.2, func() -> void:
			world.hud.close_dialog()
			world.hud._modal = ""
			world.hud.toggle_nation()],
		[19.2, func() -> void: _shot("nation")],
		[19.4, func() -> void:
			world.hud.toggle_nation()
			world.hud._modal = ""
			world.hud._fam_tab = "case"
			world.hud.toggle_family()],
		[20.2, func() -> void: _shot("case")],
		[20.4, func() -> void:
			world.hud.toggle_family()
			world.hud.show_newspaper(-1)],
		[21.2, func() -> void: _shot("paper")],
		[21.5, func() -> void: _finish()],
	]
	Game.notice.connect(func(fam: int, text: String, _k: String) -> void:
		if fam == 0 or fam == -1: _log.append("notice: " + text))
	Net.event.connect(func(n: String, args: Array) -> void:
		if n == "reply": _log.append("reply: " + String(args[0])))


func _nearest_shop(p: Vector3) -> Dictionary:
	var best := {}
	var bd := INF
	for b in Game.biz:
		if b["kind"] in ["club", "precinct", "warehouse"]:
			continue
		var d := Vector3(b["door"][0], 0, b["door"][1]).distance_to(p)
		if d < bd:
			bd = d
			best = b
	world.local_actor.place(Vector3(best["door"][0], 0, best["door"][1]) + Vector3(0.5, 0, 0.5))
	return best


func _shot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		print("shot (headless) ", name)
		return
	get_viewport().get_texture().get_image().save_png("%s_%s.png" % [_out, name])
	print("shot ", name)


func _finish() -> void:
	for l in _log.slice(0, 40):
		print("  ", l)
	var f: Dictionary = Game.fam(0)
	print("heat=", f["heat"], " evidence=", f["evidence"].size(), " chicago=", Game.nation["cities"]["chi"]["influence"], " cellar=", f.get("cellar", 0))
	for fm in Game.families:
		print("  ", fm["name"], " dirty=", fm["dirty"], " shops=", Game.shops_of(fm["id"]).size(), " legacy=", Game.legacy(fm["id"]))
	for n in Game.news.slice(0, 8):
		print("  news: ", n["text"])
	print("AUTOTEST OK month=", Game.month, " actors=", world.actors.size())
	get_tree().quit()


func _process(delta: float) -> void:
	_t += delta
	while not _steps.is_empty() and _t >= _steps[0][0]:
		var s: Array = _steps.pop_front()
		(s[1] as Callable).call()
