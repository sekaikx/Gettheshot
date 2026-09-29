extends Node
## Close-ups of every HUD state on the real street: the money and goal, toasts, the prompt and a
## fear meter, three kinds of conversation, the pause menu and settings, How to play, the paper
## (front page and the folded copy), the arrest, the jail, the goal flourish, the final ranking.
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --rendering-driver opengl3 --resolution 1600x900 \
##       --path game res://tools/test/test_hud.tscn -- --out=/tmp/hud
##   --only=street,talk  takes just those shots.

var world: Node
var hud: Node
var out := "/tmp/test_hud"
var only: PackedStringArray = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		if a.begins_with("--only="):
			only = a.substr(7).split(",")
	Game.new_campaign({"seed": 1923, "families": 6, "month_seconds": 600.0}, [{"peer": 1, "name": "Alex", "family_name": "Vitale", "color": "#c42828"}])
	world = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	_run.call_deferred()


func _wait(s: float) -> void:
	await get_tree().create_timer(s, true).timeout


func _want(name: String) -> bool:
	return only.is_empty() or only.has(name)


func _shot(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s_%s.png" % [out, name])
	print("shot ", name)


func _run() -> void:
	await _wait(1.5)
	hud = world.get("hud")
	var me: Actor = world.get("local_actor")
	Game.clock = 0.3
	var f := Game.fam(0)
	f["heat"] = 47.0
	Game.player(1)["wallet"] = 1250
	var shop := {}
	for b in Game.biz:
		if b["kind"] in ["bakery", "grocer", "barber", "butcher"] and int(b["protector"]) < 0 and int(b["owned_by"]) < 0:
			shop = b
			break
	var far: Dictionary = Game.biz[Game.biz.size() - 3]
	Game.deals.append({"id": 900, "from": 1, "to": 0, "terms": {"kind": "alliance", "months": 12, "amount": 500, "against": 2}, "expires": Game.month + 1})
	Game.deals.append({"id": 901, "from": 3, "to": 0, "terms": {"kind": "truce", "months": 6, "amount": -300}, "expires": Game.month + 1})
	Game.news.push_front({"month": Game.month, "text": "Dry agents smash 40 barrels in a Brooklyn cellar.", "big": false})
	Game.news.push_front({"month": Game.month, "text": "Babe Ruth hits two at the Polo Grounds.", "big": false})
	Game.news.push_front({"month": Game.month, "text": "BOOTLEG WAR ON THE BOWERY: two men shot outside a Mott St. café, police say no witnesses.", "big": true})
	shop["favor"] = {"kind": "debt", "reward": 120, "until": Game.month + 1, "target_biz": far["id"], "rival": 1}
	# on the street, near the shop
	me.place(W.door(shop) + W.front_dir(float(shop["yaw"])) * 2.5 * W.M)
	world.get("cam").call("snap")
	hud.refresh()
	hud.set_objective({"title": "Offer protection", "detail": "%s · %s" % [shop["name"], shop["address"]], "target": W.door(far), "step": 3, "of": 10})
	hud.mentor_say("Uncle Carmine", "See that shop? He pays nobody. Go in, stand at his counter, and offer him protection.",
		{"kind": "consigliere", "look": 51177, "color": W.FAMILY_NONE, "extra": {}}, 20.0)
	hud.toast("The O'Hara family wants a sit-down.", "deal")
	hud.toast("You took $500 from the safe.", "money")
	hud.toast("A witness saw you break the window at Mulberry Bakery. Heat +8.", "warn")
	hud.show_place(String(shop["name"]), "Pays nobody")
	await _wait(1.1)
	if _want("street"):
		await _shot("street")
	# the prompt and a fear meter over the owner
	var owner: Actor = world.call("actor", "s%d" % shop["id"])
	me.place(world.call("talk_spot", shop["id"]), 0.0)
	world.get("cam").call("snap")
	await _wait(0.4)
	hud.set_meter("fear_test", owner.position, 0.46, Rackets.FEAR_DEAL / 100.0, "FEAR", Pal.UI_RED)
	hud.set_prompt("Talk to %s" % shop["owner_name"], owner.position, "E")
	await _wait(0.6)
	if _want("meter"):
		await _shot("meter")
	hud.clear_meter("fear_test")
	hud.set_prompt("Carrying a crate  ·  Q to drop it", me.position, "")
	await _wait(0.4)
	if _want("carry"):
		await _shot("carry")
	hud.set_prompt("Pick the lock of the back door", Vector2.INF, "E")
	await _wait(0.4)
	if _want("docked"):
		await _shot("docked")
	hud.set_prompt("")
	# a shopkeeper conversation with the meter
	Talk.world = world
	shop["shake"] = 0
	shop["fear"] = 46.0
	var conv: Dictionary = Talk.shopkeeper(shop, owner)
	hud.converse(conv)
	await _wait(0.9)
	if _want("talk"):
		await _shot("talk")
	# a sit-down: many options, two columns
	var don: Actor = world.call("actor", "a1")
	var sit: Dictionary = Talk._sitdown(1, don if don else owner)
	hud.converse(sit)
	await _wait(0.9)
	if _want("talk2"):
		await _shot("talk2")
	# a thing without a face: the telephone with two offers
	var hq := Game.biz_by_id(int(f["hq"]))
	hud.converse(Talk._object({"biz": hq["id"], "item": "phone"}))
	await _wait(0.9)
	if _want("phone"):
		await _shot("phone")
	hud.close_conversation()
	await _wait(0.4)
	# the pause menu and the settings
	hud.escape()
	await _wait(0.5)
	if _want("menu"):
		await _shot("menu")
	hud.get("_menu").call("open", "settings")
	await _wait(0.3)
	if _want("settings"):
		await _shot("settings")
	hud.escape()
	hud.escape()
	await _wait(0.2)
	hud.toggle_help()
	await _wait(0.8)
	if _want("help"):
		await _shot("help")
	hud.toggle_help()
	hud.show_newspaper(-1)
	await _wait(0.8)
	if _want("paper"):
		await _shot("paper")
	hud.escape()
	hud.show_newspaper(Game.month)
	await _wait(0.8)
	if _want("paper_mini"):
		await _shot("paper_mini")
	# the arrest, then the cell
	hud.show_arrest("k0", 185)
	await _wait(0.9)
	if _want("arrest"):
		await _shot("arrest")
	hud.close_conversation()
	hud.jail_until = Time.get_ticks_msec() / 1000.0 + 45.0
	await _wait(0.9)
	if _want("jail"):
		await _shot("jail")
	hud.jail_until = 0.0
	await _wait(0.5)
	# the goal changes: the old one is ticked off
	hud.set_objective({"title": "Scare him until he pays", "detail": "Break his things (F) · rough him up · watch the FEAR bar", "target": owner.position, "step": 4, "of": 10})
	await _wait(0.45)
	if _want("check"):
		await _shot("check")
	await _wait(1.2)
	if _want("goal2"):
		await _shot("goal2")
	hud.set_objective({"title": "Run off the O'Hara thugs", "detail": "Outside Adler's Provisions  ·  $120", "target": W.door(far)})
	for t in [["You got the envelope: $90.", "money"], ["Tommy Marino is in a cell for 2 months.", "bad"], ["The Kaplan family says no.", "info"],
			["The feds are watching you. Heat is at 70.", "warn"], ["Adler's Provisions pays you now.", "good"], ["The O'Hara family wants a sit-down.", "deal"]]:
		hud.toast(String(t[0]), String(t[1]))
	await _wait(1.0)
	if _want("toasts"):
		await _shot("toasts")
	Game.clock = 0.74
	world.set("weather", "rain")
	await _wait(0.8)
	if _want("night"):
		await _shot("night")
	hud.show_final()
	await _wait(1.3)
	if _want("final"):
		await _shot("final")
	get_tree().quit()
