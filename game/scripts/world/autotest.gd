extends Node
## godot res://scenes/main.tscn -- --autotest --shot=/tmp/a
## Plays solo in the 2D street: walks, goes into a shop, talks to the owner, shakes him down
## (smashes his things until the fear meter tips), shoots, sends men to Chicago, buys a warehouse on
## the quay and loads the truck from it, talks to the union boss, lets months pass, and saves
## screenshots of each screen (street, inside a shop, the talk box, the shakedown, the quay, night,
## rain, the club's office, the maps, the family book, the paper).
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
var _shop_id := -1
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
	if "--tuttest" in OS.get_cmdline_user_args():
		_tuttest.call_deferred()
		return
	if "--favortest" in OS.get_cmdline_user_args():
		_favortest.call_deferred()
		return
	Game.clock = 0.2
	_steps = [
		[0.3, func() -> void:
			if world.hud.is_modal(): world.hud.escape()],
		[0.5, func() -> void: world.controller.auto_move = Vector2(0.4, 1.0)],
		[2.5, func() -> void: world.controller.auto_move = Vector2.ZERO],
		[3.0, func() -> void: _shot("street")],
		[3.2, func() -> void: _enter_shop()],
		[4.2, func() -> void: _shot("inside")],
		[4.4, func() -> void:
			world.controller._find_focus(world.local_actor)
			_checks["owner_focus"] = world.controller.focus.get("kind", "") == "shop"
			world.controller._use()
			_checks["talk_open"] = world.hud.is_modal()],
		[5.2, func() -> void: _shot("talk")],
		[5.4, func() -> void: _shakedown()],
		[7.0, func() -> void: _shot("shakedown")],
		[7.2, func() -> void: _smash_more()],
		[8.0, func() -> void:
			var b := Game.biz_by_id(_shop_id)
			_checks["shakedown_result"] = int(b["protector"]) == 0 or int(b.get("snapped_until", -1)) >= Game.month
			print("  shakedown: protector=%d fear=%d snapped=%d broken=%s" % [int(b["protector"]), int(b["fear"]), int(b.get("snapped_until", -1)), str(b.get("broken", []))])
			Game.player(1)["wallet"] += 5000
			Game.fam(0)["dirty"] += 8000
			Game.fam(0)["clean"] += 16000
			Game.fam(0)["arsenal"]["pistol"] += 1
			Net.to_host("shoot", [])
			Net.to_host("nation", ["send", "chi", 4, 1, -1])
			Net.to_host("nation", ["convoy", "champlain", 50])
			Net.to_host("nation", ["ambush", "detroit_river", 3])
			Net.to_host("nation", ["route", "rum_row_atl"])],
		[8.2, func() -> void: _supply_setup()],
		[8.4, func() -> void:
			var cop: Actor = world.actor("k0")
			world.local_actor.set_carry(true)
			world.local_actor.place(cop.position + Vector2(2, 0) * W.M)],
		[8.8, func() -> void:
			world.local_actor.set_carry(false)
			Game.cfg["month_seconds"] = 1.2],
		[14.0, func() -> void:
			Game.cfg["month_seconds"] = 60.0
			Game.clock = 0.2
			Net.to_host("nation", ["hit", "chi", 1])],
		[14.2, func() -> void: _load_truck()],
		[15.4, func() -> void: _shot("warehouse")],
		[15.6, func() -> void:
			world.hud.close_conversation()
			var u: Actor = world.actor("u1")
			world.local_actor.place(u.position + Vector2.from_angle(u.yaw) * 0.9 * W.M, u.yaw + PI)
			world.cam.snap()],
		[16.2, func() -> void:
			world.controller._find_focus(world.local_actor)
			_checks["union_focus"] = world.controller.focus.get("kind", "") == "unionboss"
			world.controller._use()
			_checks["union_talk"] = world.hud.is_modal()],
		[17.0, func() -> void: _shot("union")],
		[17.2, func() -> void:
			Game.fam(0)["dirty"] += 3000
			Net.to_host("act", ["union_pay", 0, 0])
			var pier: Dictionary = world.plan.piers[1]
			world.local_actor.place(W.p(world.plan.water_x - 4.0, (float(pier["z0"]) + float(pier["z1"])) * 0.5 + 4.0), 0.0)
			world.cam.user_zoom = 0.7
			world.cam.snap()],
		[19.5, func() -> void:
			var carrying := 0
			for a in world.actors.values():
				if (a as Actor).kind == "docker" and (a as Actor).carrying:
					carrying += 1
			_checks["dockers_work"] = carrying > 0
			_shot("piers")],
		[19.7, func() -> void:
			world.cam.user_zoom = 0.45
			var hq := Game.biz_by_id(int(Game.fam(0)["hq"]))
			world.local_actor.place(W.door(hq) + W.front_dir(float(hq["yaw"])) * 3.0 * W.M)
			world.cam.snap()],
		[21.5, func() -> void: _shot("zoom")],
		[21.7, func() -> void:
			world.cam.user_zoom = 1.0
			Game.clock = 0.74],
		[24.0, func() -> void: _shot("night")],
		[24.2, func() -> void:
			world.weather = "rain"],
		[25.5, func() -> void: _shot("rain")],
		[25.7, func() -> void:
			world.weather = "clear"
			Game.clock = 0.25
			_to_office()],
		[27.0, func() -> void: _shot("office")],
		[27.2, func() -> void:
			world.controller._find_focus(world.local_actor)
			_checks["office_focus"] = world.controller.focus.get("type", "") == "object"
			print("  in the office, E would: ", world.controller.focus.get("label", "(nothing)"))
			world.controller._use()],
		[27.8, func() -> void: _shot("office_talk")],
		[28.0, func() -> void:
			world.hud.close_conversation()
			world.hud.toggle_nation()],
		[29.0, func() -> void: _shot("nation")],
		[29.2, func() -> void:
			world.hud.toggle_nation()
			world.hud.toggle_family()],
		[30.0, func() -> void: _shot("book")],
		[30.2, func() -> void:
			world.hud.toggle_family()
			world.hud.toggle_map()],
		[31.0, func() -> void: _shot("dons_view")],
		[31.2, func() -> void:
			world.hud.toggle_map()
			world.hud.show_newspaper(-1)],
		[32.0, func() -> void: _shot("paper")],
		[32.3, func() -> void: _finish()],
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


## Into the nearest shop that pays nobody, in front of the counter.
func _enter_shop() -> void:
	var me: Actor = world.local_actor
	var best := {}
	var bd := INF
	for b in Game.biz:
		if b["kind"] in ["club", "precinct", "warehouse", "poolhall"] or int(b["protector"]) >= 0 or int(b["owned_by"]) >= 0:
			continue
		var d := W.door(b).distance_to(me.position)
		if d < bd:
			bd = d
			best = b
	_shop_id = best["id"]
	var spot: Vector2 = world.talk_spot(_shop_id)
	var f := W.front_dir(float(best["yaw"]))
	me.place(spot, (-f).angle())
	world.cam.snap()
	_checks["inside"] = true


## Offer protection; when he says no, break his things.
func _shakedown() -> void:
	world.hud.close_conversation()
	Net.to_host("act", ["pitch", _shop_id, 0])
	var lay: Dictionary = world.layout_of_biz(_shop_id)
	for it in lay["items"]:
		if bool(it["breakable"]) and it["type"] != "window":
			var me: Actor = world.local_actor
			me.place((it["rect"] as Rect2).get_center() + (lay["front"] as Vector2) * 0.9 * W.M, (-(lay["front"] as Vector2)).angle())
			Net.to_host("smash", [_shop_id, it["id"]])
			break
	var b := Game.biz_by_id(_shop_id)
	_checks["shakedown_started"] = int(b.get("shake", -1)) == 0 or int(b["protector"]) == 0
	print("  after the first smash: fear=%d shake=%d weak=%s" % [int(b["fear"]), int(b.get("shake", -1)), b.get("weak", "")])


func _smash_more() -> void:
	var lay: Dictionary = world.layout_of_biz(_shop_id)
	var b := Game.biz_by_id(_shop_id)
	for it in lay["items"]:
		if int(b["protector"]) == 0 or int(b.get("shake", -1)) != 0:
			break
		if bool(it["breakable"]) and not (b["broken"] as Array).has(int(it["id"])):
			world.local_actor.place((it["rect"] as Rect2).get_center() + (lay["front"] as Vector2) * 0.9 * W.M, 0.0)
			Net.to_host("smash", [_shop_id, it["id"]])


## Buy the first warehouse on the quay (in person), a warehouse and the brewery in Chicago, a
## convoy into Chicago, freight New York -> Chicago, a speakeasy and a man on the booze run.
func _supply_setup() -> void:
	var wh: Dictionary = world.quay_warehouses()[0]
	_wh_id = wh["id"]
	world.local_actor.place(W.door(wh) - W.front_dir(float(wh["yaw"])) * 1.5 * W.M)
	Net.to_host("act", ["buy", _wh_id, 0])
	_checks["nyc_warehouse"] = Syndicate.has_wh(Game.nation, "nyc", 0) and int(Game.biz_by_id(_wh_id)["owned_by"]) == 0
	Net.to_host("nation", ["warehouse", "chi"])
	Net.to_host("nation", ["plant", "chi"])
	Net.to_host("nation", ["convoy", "windsor_chi", 60])
	Net.to_host("nation", ["yard", "chi"])
	Net.to_host("nation", ["freight", "rail_nyc_chi", "nyc", "chi", 20])
	_checks["chi_warehouse"] = Syndicate.has_wh(Game.nation, "chi", 0)
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


## The truck parked outside the warehouse, the watchman loads it.
func _load_truck() -> void:
	var wh := Game.biz_by_id(_wh_id)
	var have := Syndicate.stock(Game.nation, "nyc", 0)
	if have < 150:
		Syndicate.put_stock(Game.nation, "nyc", 0, 150 - have)
		Game.mark_dirty()
	var f := W.front_dir(float(wh["yaw"]))
	var truck: Vehicle = world.vehicles["t0"]
	truck.set_load(0)
	truck.place(W.door(wh) + f * 4.5 * W.M, f.orthogonal().angle())
	var lay: Dictionary = world.layout_of_biz(_wh_id)
	world.local_actor.place(world.talk_spot(_wh_id), (-f).angle())
	world.cam.snap()
	var before := Syndicate.stock(Game.nation, "nyc", 0)
	Net.to_host("act", ["wh_load", _wh_id, 0])
	_checks["truck_loaded"] = truck.load > 0 and Syndicate.stock(Game.nation, "nyc", 0) == before - truck.load
	print("  truck loaded ", truck.load, " crates; ", Syndicate.stock(Game.nation, "nyc", 0), " left; layout ok: ", not lay.is_empty())
	Game.mark_dirty()


func _to_office() -> void:
	var hq := Game.biz_by_id(int(Game.fam(0)["hq"]))
	var lay: Dictionary = world.layout_of_biz(int(hq["id"]))
	var at: Vector2 = lay["spots"].get("safe", (lay["back"] as Rect2).get_center())
	world.local_actor.place(at, 0.0)
	world.cam.snap()


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
	for fm in Game.families:
		print("  ", fm["name"], " dirty=", fm["dirty"], " clean=", fm["clean"], " shops=", Game.shops_of(fm["id"]).size(), " legacy=", Game.legacy(fm["id"]))
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


# ------------------------------------------------------------------ the tutorial, start to finish

func _tut() -> Node:
	return world.get_node_or_null("Tutorial")


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _tuttest() -> void:
	await _wait(0.6)
	var t := _tut()
	if t == null:
		print("TUTTEST FAIL no tutorial")
		get_tree().quit()
		return
	var me: Actor = world.local_actor
	var hq := Game.biz_by_id(int(Game.fam(0)["hq"]))
	var lay: Dictionary = world.layout_of_biz(int(hq["id"]))
	print("  step ", t.step, " ", t.STEPS[t.step][0])
	me.place((lay["back"] as Rect2).get_center())
	await _wait(1.2)
	print("  step ", t.step, " ", t.STEPS[t.step][0])
	Net.to_host("act", ["bank_out", hq["id"], 0])
	await _wait(1.2)
	print("  step ", t.step, " ", t.STEPS[t.step][0], " shop=", t._shop)
	var shop: int = t._shop
	me.place(world.talk_spot(shop))
	await _wait(0.5)
	Net.to_host("act", ["pitch", shop, 0])
	await _wait(1.2)
	print("  step ", t.step, " ", t.STEPS[t.step][0])
	for k in 12:
		var b := Game.biz_by_id(t._shop)
		if int(b["protector"]) == 0:
			break
		var sl: Dictionary = world.layout_of_biz(t._shop)
		if t._shop != shop:
			shop = t._shop
			me.place(world.talk_spot(shop))
			await _wait(0.4)
			Net.to_host("act", ["pitch", shop, 0])
			await _wait(0.6)
			continue
		var hit := false
		for it in sl["items"]:
			if bool(it["breakable"]) and not (b["broken"] as Array).has(int(it["id"])):
				me.place((it["rect"] as Rect2).get_center() + (sl["front"] as Vector2) * 0.9 * W.M)
				Net.to_host("smash", [shop, it["id"]])
				hit = true
				break
		if not hit:
			var owner: Actor = world.actor("s%d" % shop)
			if owner:
				world.shopkeeper_hurt(owner, me, false)
		await _wait(0.7)
	await _wait(1.0)
	print("  step ", t.step, " ", t.STEPS[t.step][0], " protector=", Game.biz_by_id(t._shop)["protector"])
	Game.player(1)["wallet"] += 3000
	for a in world.actors.values():
		if (a as Actor).kind == "recruit":
			me.place((a as Actor).position + Vector2(0.8, 0) * W.M)
			await _wait(0.3)
			Net.to_host("act", ["hire", (a as Actor).ref_id, 0])
			break
	await _wait(1.2)
	print("  step ", t.step, " ", t.STEPS[t.step][0])
	for c in Game.cops:
		if int(c["payroll"]) == 0:
			break
		var ca: Actor = world.actor("k%d" % c["id"])
		if ca:
			me.place(ca.position + Vector2(0.8, 0) * W.M)
			await _wait(0.2)
			Net.to_host("act", ["cop", c["id"], 0])
	await _wait(1.2)
	print("  step ", t.step, " ", t.STEPS[t.step][0], " bank=", Game.fam(0)["clean"])
	var front := -1
	for b in Game.shops_of(0):
		if int(b["owned_by"]) < 0 and b["kind"] not in ["club", "warehouse", "precinct"]:
			front = int(b["id"])
			break
	me.place(world.talk_spot(front))
	await _wait(0.3)
	Net.to_host("act", ["buy", front, 0])
	await _wait(1.2)
	print("  step ", t.step, " ", t.STEPS[t.step][0])
	Net.to_host("act", ["speakeasy", front, 0])
	await _wait(1.2)
	print("  step ", t.step, " ", t.STEPS[t.step][0])
	me.set_carry(true)
	Net.to_host("act", ["deliver", front, 0])
	await _wait(1.2)
	print("  step ", t.step, " ", t.STEPS[t.step][0])
	var ev := InputEventKey.new()
	ev.keycode = KEY_TAB
	ev.pressed = true
	t._input(ev)
	await _wait(1.2)
	var ok: bool = String(t.STEPS[mini(t.step, t.STEPS.size() - 1)][0]) == "done"
	print("  step ", t.step, " tut=", Game.player(1).get("tut", -1), " gift=", Game.player(1).get("tut_gift", false))
	print("TUTTEST %s" % ("OK" if ok else "FAIL"))
	get_tree().quit()


# ------------------------------------------------------------------ favors: one of each kind

func _favortest() -> void:
	await _wait(0.6)
	var me: Actor = world.local_actor
	var done := {}
	for round in 6:
		for b in Game.biz:
			if not b.has("favor") or done.has(String(b["favor"]["kind"])):
				continue
			var kind := String(b["favor"]["kind"])
			me.place(world.talk_spot(int(b["id"])))
			await _wait(0.4)
			Net.to_host("favor", [b["id"]])
			await _wait(0.4)
			var job: Dictionary = Game.player(1).get("job", {})
			print("  took favor ", kind, " at ", b["name"], ": ", Favors.text(job, b).get("title", "?"))
			match kind:
				"thugs":
					for key in job.get("keys", []):
						var t: Actor = world.actor(String(key))
						if t:
							t.hurt(200.0, me)
				"debt":
					Game.fam(0)["rep"] = 40
					var d: Actor = world.actor(String(job["keys"][0]))
					me.place(d.position + Vector2(0.8, 0) * W.M)
					await _wait(0.3)
					Net.to_host("favor_talk", [d.key])
				"parcel":
					me.place(world.talk_spot(int(job["target_biz"])))
					await _wait(0.4)
					Net.to_host("favor_deliver", [job["target_biz"]])
			await _wait(1.2)
			var after: Dictionary = Game.player(1).get("job", {})
			done[kind] = after.is_empty()
			print("  favor ", kind, " done: ", after.is_empty(), " wallet=", Game.player(1)["wallet"])
			break
		if done.size() >= 3:
			break
		Favors.refresh(Game)
		for b in Game.biz:
			if b.has("favor") and done.has(String(b["favor"]["kind"])):
				b.erase("favor")
		Favors.refresh(Game)
	var ok := done.size() == 3 and done.values().all(func(v) -> bool: return v)
	print("FAVORTEST %s %s" % ["OK" if ok else "FAIL", str(done)])
	get_tree().quit()


# ------------------------------------------------------------------ balance simulation

func _start_sim() -> void:
	if world.hud.is_modal():
		world.hud.escape()
	_sim_start = Game.month
	Game.cfg["month_seconds"] = 0.35
	Game.month_passed.connect(_sim_month)
	Game.ai_order.connect(func(order: Dictionary) -> void:
		var a: Actor = world.actor("c%d" % int(order["crew"]))
		if a:
			a.order = {}
		Game.resolve_ai_order(order))
	print("SIM start ", Game.date_text(), " families=", Game.families.size())


func _sim_month(m: int) -> void:
	for b in Game.shops_of(0):
		Game.fam(0)["dirty"] += int(b["envelope"])
		b["envelope"] = 0
	var home: String = Game.biz_by_id(int(Game.fam(0)["hq"]))["district"]
	for b in Game.biz:
		if b["protector"] < 0 and b["owned_by"] < 0 and b["kind"] not in ["precinct", "club", "warehouse"] and (b["district"] == home or m % 2 == 0):
			Game.act_pitch(0, b["id"], 2)
			break
	var parts := []
	for f in Game.families:
		parts.append("%s d=%d c=%d shops=%d men=%d heat=%d" % [f["name"], int(f["dirty"]), int(f["clean"]), Game.shops_of(f["id"]).size(), Game.crew_of(f["id"]).size(), int(f["heat"])])
	print("SIM %s | %s" % [Game.date_text(m), " | ".join(parts)])
	if m - _sim_start >= _sim:
		print("SIM END")
		get_tree().quit()
