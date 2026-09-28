extends Node
## godot res://scenes/main.tscn -- --autotest --shot=/tmp/a
## Plays solo: walks, talks to a shop, shoots, sends men to Chicago, runs a convoy, buys a
## warehouse on the West St. quay (the convoy into New York fills it, the truck loads from it),
## a warehouse and a brewery in Chicago, a freight order by rail, the booze run, talks to the
## union's hiring boss, lets months pass with the AI families acting, and saves screenshots of
## each screen.
##
## godot res://scenes/main.tscn -- --autotest --sim=36 : no test steps, just lets 36 months pass
## fast and prints every family's money each month (balance check).

var world: Node
var _t := 0.0
var _out := "/tmp/famiglia"
var _steps: Array = []
var _log: Array = []
var _sim := 0
var _sim_start := 0
var _checks := {}
var _wh_id := -1
var _speak_id := -1
var _pending := ""
var _pending_frames := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			_out = a.substr(7)
		if a.begins_with("--sim="):
			_sim = int(a.substr(6))
	if _sim > 0:
		_start_sim()
		return
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
			Game.fam(0)["clean"] += 16000
			Net.to_host("shoot", [])
			Net.to_host("nation", ["send", "chi", 4, 1, -1])
			Net.to_host("nation", ["convoy", "champlain", 50])
			Net.to_host("nation", ["ambush", "detroit_river", 3])
			Net.to_host("nation", ["route", "rum_row_atl"])],
		[6.4, func() -> void: _supply_setup()],
		[6.6, func() -> void:
			var cop: Actor = world.actor("k0")
			world.local_actor.set_carry(true)
			world.local_actor.place(cop.position + Vector3(2, 0, 0))],
		[7.0, func() -> void:
			Game.cfg["month_seconds"] = 1.2],
		[13.0, func() -> void:
			Game.cfg["month_seconds"] = 60.0
			Net.to_host("nation", ["hit", "chi", 1])],
		[13.2, func() -> void: _load_truck()],
		[15.0, func() -> void: _shot("dock")],
		[15.2, func() -> void:
			var u: Actor = world.actor("u1")
			world.local_actor.place(u.position + Basis(Vector3.UP, u.yaw) * Vector3(0, 0, 1.2), u.yaw + PI)
			world.cam.snap()],
		[15.8, func() -> void:
			world.controller._find_focus(world.local_actor)
			_checks["union_focus"] = world.controller.focus.get("kind", "") == "unionboss"
			world.controller._use()
			_checks["union_dialog"] = world.hud._modal == "dialog"],
		[16.6, func() -> void: _shot("union")],
		[16.8, func() -> void:
			Game.fam(0)["dirty"] += 3000
			world.hud._choose(0)       # put the local on the payroll
			# the longshoremen at work on the middle pier
			var pier: Dictionary = world.plan.piers[1]
			world.local_actor.place(Vector3(world.plan.water_x + 3.0, 0, (float(pier["z0"]) + float(pier["z1"])) * 0.5 + 1.0), PI * 0.5)
			world.cam.dist_goal = 30.0
			world.cam.snap()],
		[19.0, func() -> void:
			var carrying := 0
			for a in world.actors.values():
				if (a as Actor).kind == "docker" and (a as Actor).carrying:
					carrying += 1
			_checks["dockers_work"] = carrying > 0
			_shot("piers")],
		[19.2, func() -> void: world.cam.dist_goal = 40.0],
		[21.0, func() -> void: _shot("zoom")],
		[21.2, func() -> void:
			Game.clock = 0.74
			world.cam.dist_goal = 18.0],
		[24.0, func() -> void: _shot("night")],
		[24.2, func() -> void:
			world.hud.close_dialog()
			world.hud._modal = ""
			world.hud.toggle_nation()],
		[25.2, func() -> void: _shot("nation")],
		[25.3, func() -> void:
			world.hud._nation._sel = {"type": "rail", "id": "rail_nyc_chi"}
			world.hud._nation.focus_on("buf", 2.4)
			world.hud._nation._fill()],
		[26.0, func() -> void: _shot("nation_rail")],
		[26.2, func() -> void:
			world.hud.toggle_nation()
			world.hud._modal = ""
			world.hud._fam_tab = "case"
			world.hud.toggle_family()],
		[27.0, func() -> void: _shot("case")],
		[27.2, func() -> void:
			world.hud._fam_tab = "supply"
			world.hud._fill_family()],
		[28.0, func() -> void: _shot("supply")],
		[28.2, func() -> void:
			world.hud.toggle_family()
			world.hud.show_newspaper(-1)],
		[29.0, func() -> void: _shot("paper")],
		[29.3, func() -> void: _finish()],
	]
	Game.notice.connect(func(fam: int, text: String, _k: String) -> void:
		if fam == 0 or fam == -1: _log.append("notice: " + text))
	_checks["nyc_stock_filled"] = false
	Game.month_passed.connect(func(_m: int) -> void:
		for l in Game.nation.get("supply", {}).get("0", []):
			if String(l).contains("into the New York warehouse"):
				_checks["nyc_stock_filled"] = true)
	Net.event.connect(func(n: String, args: Array) -> void:
		if n == "reply": _log.append("reply: " + String(args[0])))


## Buy the first warehouse on the quay (in person), a warehouse and the brewery in Chicago, a
## convoy into Chicago, freight New York -> Chicago, a speakeasy and a man on the booze run.
func _supply_setup() -> void:
	var wh: Dictionary = world.quay_warehouses()[0]
	_wh_id = wh["id"]
	world.local_actor.place(Vector3(wh["door"][0], 0, wh["door"][1]) + Basis(Vector3.UP, float(wh["yaw"])) * Vector3(0, 0, 0.8))
	Net.to_host("act", ["buy", _wh_id, 0])
	_checks["nyc_warehouse"] = Syndicate.has_wh(Game.nation, "nyc", 0) and int(Game.biz_by_id(_wh_id)["owned_by"]) == 0
	Net.to_host("nation", ["warehouse", "chi"])
	Net.to_host("nation", ["plant", "chi"])
	Net.to_host("nation", ["convoy", "windsor_chi", 60])
	Net.to_host("nation", ["yard", "chi"])
	Net.to_host("nation", ["freight", "rail_nyc_chi", "nyc", "chi", 20])
	_checks["chi_warehouse"] = Syndicate.has_wh(Game.nation, "chi", 0)
	_checks["chi_brewery"] = int(Game.nation["cities"]["chi"]["plant"]) == 0
	_checks["freight_order"] = (Game.nation["freight"] as Array).any(func(o: Dictionary) -> bool: return int(o["fam"]) == 0 and o["from"] == "nyc")
	# a speakeasy of our own and a man to run the booze to it
	for b in Game.shops_of(0):
		if b["owned_by"] < 0 and b["kind"] not in ["club", "warehouse", "precinct"]:
			Game.act_buy(0, b["id"])
			Game.act_open_speakeasy(1, b["id"])
			_speak_id = b["id"]
			break
	var men := Game.crew_of(0)
	if not men.is_empty():
		Net.to_host("crew_task", [men[men.size() - 1]["id"], "booze", 20])
		_checks["booze_run"] = Game.crew_by_id(men[men.size() - 1]["id"])["task"] == "booze"


## After the months: the truck parked at the warehouse door, E loads it from the stock.
func _load_truck() -> void:
	if world.hud._modal == "arrest":
		Net.to_host("arrest", ["bribe"])       # the cop from the contraband step takes his envelope
	world.hud.close_dialog()
	var wh := Game.biz_by_id(_wh_id)
	var have := Syndicate.stock(Game.nation, "nyc", 0)
	print("  nyc warehouse before loading: ", have, " crates")
	if have < 150:
		Syndicate.put_stock(Game.nation, "nyc", 0, 150 - have)       # a full quay for the picture
		Game.mark_dirty()
	var basis := Basis(Vector3.UP, float(wh["yaw"]))
	var door := Vector3(wh["door"][0], 0, wh["door"][1])
	var truck: Vehicle = world.vehicles["t0"]
	truck.set_load(0)
	truck.place(door + basis * Vector3(0, 0, 5.2), float(wh["yaw"]) + PI * 0.5)
	world.local_actor.set_carry(false)
	world.local_actor.place(door + basis * Vector3(0.6, 0, 0.9), float(wh["yaw"]) + PI)
	world.controller._find_focus(world.local_actor)
	print("  at the warehouse door, E would: ", world.controller.focus.get("label", "(nothing)"))
	_checks["load_prompt"] = world.controller.focus.get("quick", "") == "wh_load"
	var before := Syndicate.stock(Game.nation, "nyc", 0)
	world.controller._use()
	_checks["truck_loaded"] = truck.load > 0 and Syndicate.stock(Game.nation, "nyc", 0) == before - truck.load
	print("  truck loaded ", truck.load, " crates at the warehouse door; ", Syndicate.stock(Game.nation, "nyc", 0), " left")
	world.cam.dist_goal = 21.0
	world.cam.snap()
	Game.mark_dirty()


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


## Screenshots wait a few rendered frames, so what the step before opened is on screen.
func _shot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		print("shot (headless) ", name)
		return
	_pending = name
	_pending_frames = 3


func _finish() -> void:
	for l in _log.slice(0, 50):
		print("  ", l)
	var f: Dictionary = Game.fam(0)
	var n: Dictionary = Game.nation
	print("heat=", f["heat"], " evidence=", f["evidence"].size(), " chicago=", n["cities"]["chi"]["influence"], " cellar=", f.get("cellar", 0))
	print("  supply: nyc stock=%d chi stock=%d chi sold=%s chi plant=%d docks nyc=%d freight=%s speakeasy=%s" % [Syndicate.stock(n, "nyc", 0),
		Syndicate.stock(n, "chi", 0), str(n["cities"]["chi"]["sold"]), int(n["cities"]["chi"]["plant"]), int(n["cities"]["nyc"]["docks"]),
		str((n["freight"] as Array).map(func(o: Dictionary) -> String: return "%s>%s %d (%s)" % [o["from"], o["to"], o["crates"], o["last"]])),
		str(Game.biz_by_id(_speak_id).get("stock", -1)) if _speak_id >= 0 else "none"])
	for l in n.get("supply", {}).get("0", []):
		print("  supply log: ", l)
	for fm in Game.families:
		print("  ", fm["name"], " dirty=", fm["dirty"], " clean=", fm["clean"], " shops=", Game.shops_of(fm["id"]).size(), " legacy=", Game.legacy(fm["id"]),
			" warehouses=", Syndicate.warehouses_of(n, fm["id"]))
	for nw in Game.news.slice(0, 8):
		print("  news: ", nw["text"])
	_checks["union_paid"] = int(n["cities"]["nyc"]["docks"]) == 0
	_checks["street_names"] = world.plan.street_name_at(0.0, 30.0) == "Mulberry St." and world.plan.street_name_at(100.0, 144.0) == "Grand St."
	var bad := _checks.keys().filter(func(k) -> bool: return not _checks[k])
	print("  checks: ", _checks)
	if bad.is_empty():
		print("AUTOTEST OK month=", Game.month, " actors=", world.actors.size())
	else:
		print("AUTOTEST FAIL ", bad)
	get_tree().quit()


func _process(delta: float) -> void:
	if _pending != "":
		_pending_frames -= 1
		if _pending_frames <= 0:
			get_viewport().get_texture().get_image().save_png("%s_%s.png" % [_out, _pending])
			print("shot ", _pending)
			_pending = ""
		return
	_t += delta
	while not _steps.is_empty() and _t >= _steps[0][0]:
		var s: Array = _steps.pop_front()
		(s[1] as Callable).call()
		if _pending != "":
			break          # a slow frame must not run the next step before the shot is taken


# ------------------------------------------------------------------ balance simulation

func _start_sim() -> void:
	if world.hud.is_modal():
		world.hud.toggle_help()
	_sim_start = Game.month
	Game.cfg["month_seconds"] = 0.35
	Game.month_passed.connect(_sim_month)
	# months this short leave no time to walk to a shop: settle the AI families' street orders at once
	Game.ai_order.connect(func(order: Dictionary) -> void:
		var a: Actor = world.actor("c%d" % int(order["crew"]))
		if a:
			a.order = {}
		Game.resolve_ai_order(order))
	# ...and like a human player, a small monthly convoy from Rum Row onto the quay
	Syndicate.set_convoy(Game, 0, "rum_row_nyc", 20)
	print("SIM start ", Game.date_text(), " families=", Game.families.size())


func _sim_month(m: int) -> void:
	var n: Dictionary = Game.nation
	# the player does his rounds: every envelope collected and stashed
	for b in Game.shops_of(0):
		Game.fam(0)["dirty"] += int(b["envelope"])
		b["envelope"] = 0
	# ...and talks one shopkeeper into paying, or tries to
	var home: String = Game.biz_by_id(int(Game.fam(0)["hq"]))["district"]
	for b in Game.biz:
		if b["protector"] < 0 and b["owned_by"] < 0 and b["kind"] not in ["precinct", "club", "warehouse"] and (b["district"] == home or m % 2 == 0):
			Game.act_pitch(0, b["id"], 2)
			break
	var parts := []
	for f in Game.families:
		var sites := []
		for c in Syndicate.CITIES:
			var cs: Dictionary = n["cities"][c["id"]]
			if cs["wh"].has(str(f["id"])):
				sites.append("W:%s(%d)" % [c["id"], int(cs["wh"][str(f["id"])])])
			if int(cs["plant"]) == f["id"]:
				sites.append("B:" + c["id"])
			if int(cs["docks"]) == f["id"]:
				sites.append("D:" + c["id"])
			if int(cs["yard"]) == f["id"]:
				sites.append("Y:" + c["id"])
		var conv := []
		for d in Syndicate.ROUTES:
			var v := int(n["routes"][d["id"]]["convoys"].get(str(f["id"]), 0))
			if v > 0:
				conv.append("%s:%d" % [d["id"], v])
		var fr := (n["freight"] as Array).filter(func(o: Dictionary) -> bool: return int(o["fam"]) == f["id"]).size()
		parts.append("%s d=%d c=%d shops=%d men=%d heat=%d net=%d %s %s fr=%d" % [f["name"], int(f["dirty"]), int(f["clean"]), Game.shops_of(f["id"]).size(), Game.crew_of(f["id"]).size(),
			int(f["heat"]), Syndicate._net_dirty(f), ",".join(conv), " ".join(sites), fr])
	print("SIM %s | %s" % [Game.date_text(m), " | ".join(parts)])
	var wh_price := 999999
	for b in Game.biz:
		if b["kind"] == "warehouse":
			wh_price = mini(wh_price, int(b["value"]))
	if not _checks.has("afford") and int(Game.fam(0)["clean"]) >= wh_price:
		_checks["afford"] = m - _sim_start
		print("SIM player could buy a quay warehouse ($%d) after %d months" % [wh_price, m - _sim_start])
	if m - _sim_start >= _sim:
		print("SIM END")
		get_tree().quit()
