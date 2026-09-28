class_name Talk
extends RefCounted
## What you can say to whom. Each function builds a conversation for hud.converse(): who's
## talking, their line, a few facts, and the options (each one a request to the host). Short,
## plain words: the player should never need the manual.

static var world: Node


static func _me() -> Dictionary:
	return Game.player(Net.my_id())


static func _fam() -> int:
	return int(_me().get("family", -1))


static func _act(what: String, target: int, extra: Variant = 0) -> Callable:
	return func() -> void: Net.to_host("act", [what, target, extra])


static func _req(method: String, args: Array) -> Callable:
	return func() -> void: Net.to_host(method, args)


static func _leave() -> Dictionary:
	return {"text": "Leave", "icon": "leave", "action": Callable()}


static func _money(v: int) -> String:
	return "$" + W.money(v)


static func _portrait(a: Actor) -> Dictionary:
	if a == null:
		return {}
	return {"kind": a.person.kind, "look": a.person.look, "color": a.person.family_color, "extra": a.person.extra}


static func open(w: Node, focus: Dictionary) -> void:
	world = w
	var conv := {}
	match String(focus.get("type", "")):
		"actor":
			conv = _actor(focus)
		"object":
			conv = _object(focus)
	if not conv.is_empty():
		world.hud.converse(conv)
		world.happened.emit("talked", focus)


# ------------------------------------------------------------------ people

static func _actor(focus: Dictionary) -> Dictionary:
	var a: Actor = world.actor(String(focus["key"]))
	if a == null:
		return {}
	match a.kind:
		"shop": return shopkeeper(Game.biz_by_id(a.ref_id), a)
		"cop": return _cop(a)
		"recruit": return _recruit(a)
		"aiboss", "boss": return _sitdown(a.family, a)
		"crew": return _crew(a)
		"dealer": return _dealer(a)
		"unionboss": return _union(a)
		"smuggler": return _smuggler(a)
		"consigliere":
			var tut: Node = world.get_node_or_null("Tutorial")
			if tut and tut.has_method("mentor_conversation"):
				return tut.call("mentor_conversation")
			return {"name": "Uncle Carmine", "role": "Your father's consigliere", "portrait": _portrait(a),
				"line": "\"Take care of your men and they take care of you. Don't let the Bureau build a case. And never let them see you coming.\"",
				"options": [_leave()]}
		"newsboy":
			return {"name": "The newsboy", "role": "Corner of %s" % world.plan.corner_at(a.position.x / W.M, a.position.y / W.M),
				"portrait": _portrait(a), "line": "\"Extra! Extra! Read all about it! Two cents, mister!\"",
				"options": [{"text": "Buy the Daily Ledger", "sub": "2 cents", "icon": "talk", "action": func() -> void: world.hud.show_newspaper(-1)}, _leave()]}
		"docker":
			return {"name": "A longshoreman", "role": "West St. piers", "portrait": _portrait(a),
				"line": ["\"Talk to Red. He decides who works.\"", "\"Can't talk. Got crates to move.\"", "\"Boats come in at night. Don't tell nobody I said so.\""][absi(a.ref_id) % 3],
				"options": [_leave()]}
		"ped":
			var lines := ["\"Nice day for it.\"", "\"I didn't see nothing.\"", "\"You're one of Vitale's boys, ain't you?\"", "\"Watch yourself. The cops are all over the Bowery.\"",
				"\"The bakery on Mulberry? That old man won't pay nobody.\"", "\"Buy me a drink sometime, handsome.\""]
			return {"name": "Somebody on the street", "portrait": _portrait(a), "line": lines[absi(a.ref_id) % lines.size()], "options": [_leave()]}
	return {}


## The owner behind his counter: this is where rackets start.
static func shopkeeper(b: Dictionary, a: Actor) -> Dictionary:
	if b.is_empty():
		return {}
	var me := _fam()
	var f := Game.fam(me)
	var p := _me()
	if b["kind"] == "precinct":
		return _precinct(b, a)
	if b["kind"] == "club":
		return _bartender(b, a)
	if b["kind"] == "warehouse":
		return _warehouse(b, a)
	var prot := int(b["protector"])
	var own := int(b["owned_by"])
	var info := []
	var mood := ""
	var line := "\"Can I help you?\""
	var fear := float(b.get("fear", 0.0))
	if fear > 60.0:
		mood = "scared"
		line = "\"Please, I don't want trouble!\""
	elif fear > 30.0:
		mood = "scared"
		line = "\"W-what do you want?\""
	elif int(b.get("defiance", 0)) > 60:
		mood = "angry"
		line = "\"What do you want?\""
	var opts := []
	var conv := {"name": String(b["owner_name"]), "role": "%s · %s" % [b["name"], b.get("address", "")], "portrait": _portrait(a), "mood": mood}
	if own == me:
		conv["line"] = "\"Boss. Everything's fine here. Business is good.\""
		info.append("Yours. It turns $%d of your Stash into clean Bank money every month." % int(b["launder"]))
		if b["speak"]:
			info.append("Speakeasy in the back: %d crates in the cellar, sells about %d a month." % [int(b["stock"]), int(b["demand"])])
			var truck_near := false
			for v in world.vehicles.values():
				if (v as Vehicle).family == me and (v as Vehicle).load > 0 and (v as Vehicle).position.distance_to(W.door(b)) < 9.0 * W.M:
					truck_near = true
			var carrying: bool = world.local_actor != null and world.local_actor.carrying
			opts.append({"text": "Unload the booze into the cellar", "icon": "booze", "enabled": carrying or truck_near,
				"sub": "" if carrying or truck_near else "carry a crate in, or park the truck by the door", "action": _act("deliver", b["id"])})
		else:
			opts.append({"text": "Open a speakeasy in the back", "sub": "$%d cash" % Game.SPEAKEASY_COST, "icon": "booze",
				"enabled": int(p["wallet"]) + int(f["dirty"]) >= Game.SPEAKEASY_COST, "action": _act("speakeasy", b["id"])})
	elif prot == me:
		conv["line"] = "\"Your envelope's ready, like always.\"" if int(b["envelope"]) > 0 else line
		info.append("Pays you $%d a month." % int(b["rate"]))
		if int(b["unpaid"]) > 0:
			conv["line"] = "\"I... I don't have it this month. Business is bad.\""
			conv["mood"] = "scared"
			opts.append({"text": "\"You owe me. Pay up.\"", "icon": "fist", "action": _act("collect", b["id"])})
		else:
			opts.append({"text": "Take the envelope", "sub": _money(int(b["envelope"])) if int(b["envelope"]) > 0 else "nothing yet: come back next month",
				"icon": "money", "enabled": int(b["envelope"]) > 0, "action": _act("collect", b["id"])})
		var price := int(b["value"])
		opts.append({"text": "Buy the business from him", "sub": "%s from the Bank" % _money(price), "icon": "buy",
			"enabled": int(f["clean"]) >= price, "action": _act("buy", b["id"])})
	elif own >= 0:
		conv["line"] = "\"This place belongs to the %s family. You want trouble with them?\"" % Game.fam(own)["name"]
		info.append("Owned by the %s family." % Game.fam(own)["name"])
	else:
		conv["line"] = line
		if prot >= 0:
			info.append("Pays the %s family $%d a month." % [Game.fam(prot)["name"], int(b["rate"])])
		else:
			info.append("Pays nobody. Worth $%d a month to you." % int(b["rate"]))
		var weak: Dictionary = Rackets.WEAK.get(String(b.get("weak", "")), {})
		if not weak.is_empty():
			info.append("On the street they say: %s" % weak["hint"])
		var shaking := int(b.get("shake", -1)) == me
		if shaking:
			conv["meter"] = {"label": "FEAR", "value": fear / 100.0, "mark": Rackets.FEAR_DEAL / 100.0}
			info.append("He's scared. Keep going until the bar reaches the mark. Too far and he runs to the cops.")
		var truce := Game.has_truce(me, prot)
		opts.append({"text": "Offer protection" if prot < 0 else "\"You pay me now, not the %s family.\"" % Game.fam(prot)["name"],
			"sub": "$%d a month%s" % [int(b["rate"]), "  ·  breaks your truce!" if truce else ""], "icon": "talk", "action": _act("pitch", b["id"])})
		var price2 := int(b["value"] * 1.25)
		opts.append({"text": "Buy the business", "sub": "%s from the Bank" % _money(price2), "icon": "buy",
			"enabled": int(f["clean"]) >= price2, "action": _act("buy", b["id"])})
		if prot >= 0 and int(b["envelope"]) > 0:
			opts.append({"text": "Take the %s family's envelope" % Game.fam(prot)["name"], "sub": _money(int(b["envelope"])), "icon": "money", "action": _act("collect", b["id"])})
	# a witness against you
	for e in f.get("evidence", []):
		if e["kind"] == "witness" and int(e.get("biz", -1)) == int(b["id"]):
			info.append("He saw something: %s." % e["text"])
			var eid: int = e["id"]
			var price3 := 100 + int(float(e["w"]) * 12.0)
			opts.append({"text": "Pay him to forget", "sub": _money(price3), "icon": "money", "enabled": int(p["wallet"]) >= price3,
				"action": _req("silence", [eid, false])})
			opts.append({"text": "Remind him what happens to people who talk", "sub": "usually works", "icon": "fist", "action": _req("silence", [eid, true])})
	if int(b["closed_until"]) >= Game.month:
		info.append("Padlocked by the feds until next month.")
	opts.append(_leave())
	conv["info"] = info
	conv["options"] = opts
	return conv


static func _bartender(b: Dictionary, a: Actor) -> Dictionary:
	var me := _fam()
	var hq := int(b.get("hq_of", -1))
	if hq == me:
		return {"name": "Your bartender", "role": b["name"], "portrait": _portrait(a),
			"line": "\"Espresso, boss? The safe's in the back office, and the map's on the table.\"",
			"info": ["Your club. The back office has the safe (your Stash), the desk (the family book) and the map."], "options": [_leave()]}
	if hq >= 0:
		return _sitdown(hq, a, "\"The Don will see you. Sit down.\"")
	return {"name": "The bartender", "role": b["name"], "portrait": _portrait(a), "line": "\"Members only, pal.\"", "options": [_leave()]}


static func _precinct(b: Dictionary, a: Actor) -> Dictionary:
	var me := _fam()
	var p := _me()
	var opts := []
	for d in CityPlan.DISTRICTS:
		var cur: int = Game.captains.get(d, -1)
		var price := Game.CAPTAIN_FEE + (400 if cur >= 0 and cur != me else 0)
		var sub := "%s, then $%d a month" % [_money(price), Game.CAPTAIN_WAGE]
		if cur == me:
			sub = "yours already"
		elif cur >= 0:
			sub += "  ·  the %s family pays him now" % Game.fam(cur)["name"]
		opts.append({"text": "Buy the captain for %s" % d, "sub": sub, "icon": "badge", "enabled": cur != me and int(p["wallet"]) + int(Game.fam(me)["dirty"]) >= price,
			"action": _act("captain", b["id"], d)})
	opts.append(_leave())
	return {"name": "The desk sergeant", "role": "14th Precinct", "portrait": _portrait(a),
		"line": "\"The Captain might see you. For the right reasons.\"",
		"info": ["A captain on your payroll means his cops look away, and street talk about you fades fast."], "options": opts}


static func _warehouse(b: Dictionary, a: Actor) -> Dictionary:
	var me := _fam()
	var f := Game.fam(me)
	var own := int(b["owned_by"])
	var opts := []
	var info := []
	var line := ""
	if own == me:
		var have := Syndicate.stock(Game.nation, "nyc", me)
		line = "\"%d crates on the pallets, boss. The truck goes out front.\"" % have
		info.append("Boats and convoys that land in New York fill this warehouse (it holds %d)." % Syndicate.WAREHOUSE_CAP)
		var truck: Vehicle = world.parked_truck(me, W.door(b), 10.0 * W.M)
		info.append("The truck is outside with %d crates." % truck.load if truck else "Park the family truck outside the door to load it.")
		opts.append({"text": "Load the truck", "sub": "up to %d crates" % (truck.max_load() if truck else Vehicle.MAX_LOAD), "icon": "booze",
			"enabled": truck != null and truck.load < truck.max_load() and have > 0, "action": _act("wh_load", b["id"])})
		var carrying: bool = world.local_actor != null and world.local_actor.carrying
		opts.append({"text": "Put crates away", "icon": "booze", "enabled": carrying or (truck != null and truck.load > 0), "action": _act("wh_store", b["id"])})
		var free := Game.crew_of(me).filter(func(c: Dictionary) -> bool: return c["task"] != "booze")
		if not free.is_empty():
			opts.append({"text": "Put %s on the booze run" % free[0]["name"], "sub": "he trucks 20 crates a month to your speakeasies", "icon": "crew",
				"action": _req("crew_task", [free[0]["id"], "booze", 20])})
	elif own >= 0:
		var n := Syndicate.stock(Game.nation, "nyc", own)
		line = "\"This is the %s family's. Beat it.\"" % Game.fam(own)["name"]
		opts.append({"text": "Walk off with a crate", "sub": "the watchman will talk", "icon": "fist", "enabled": n > 0, "action": _act("wh_steal", b["id"])})
	else:
		var price := int(b["value"] * (1.0 if int(b["protector"]) == me else 1.25))
		line = "\"The owners want out. You buying?\""
		info.append("Buy it and boats landing in New York fill it with crates for your speakeasies.")
		opts.append({"text": "Buy the warehouse", "sub": "%s from the Bank" % _money(price), "icon": "buy", "enabled": int(f["clean"]) >= price, "action": _act("buy", b["id"])})
	opts.append(_leave())
	return {"name": "The watchman", "role": "%s · West St." % b["name"], "portrait": _portrait(a), "line": line, "info": info, "options": opts}


static func _cop(a: Actor) -> Dictionary:
	var me := _fam()
	var p := _me()
	var c := Game.cop_by_id(a.ref_id)
	if c.is_empty():
		return {"name": "The desk sergeant", "portrait": _portrait(a), "line": "\"Move along.\"", "options": [_leave()]}
	var info := ["Walks the %s beat." % c.get("district", "")]
	if int(c.get("payroll", -1)) == me:
		return {"name": c["name"], "role": "On your payroll", "portrait": _portrait(a), "mood": "smug",
			"line": "\"Evening. I didn't see you, you didn't see me.\"", "info": info, "options": [_leave()]}
	if int(c.get("payroll", -1)) >= 0:
		info.append("Word is he takes money from the %s family." % Game.fam(int(c["payroll"]))["name"])
	return {"name": c["name"], "role": "Patrolman", "portrait": _portrait(a), "line": "\"Something I can do for you?\"", "info": info,
		"options": [{"text": "Slip him $100 to look the other way", "sub": "then $%d a month · some cops won't take it" % Game.COP_WAGE, "icon": "money",
			"enabled": int(p["wallet"]) >= 100, "action": _act("cop", a.ref_id)}, _leave()]}


static func _recruit(a: Actor) -> Dictionary:
	var p := _me()
	for r in Game.recruits:
		if r["id"] == a.ref_id:
			var t: Dictionary = Rackets.TRAITS.get(String(r.get("trait", "")), {})
			return {"name": String(r["name"]), "role": "Looking for work", "portrait": _portrait(a),
				"line": "\"I hear you're a man who needs men.\"",
				"info": ["%s: %s" % [t.get("name", ""), t.get("does", "")], "Tough: %d out of 100 · wants %s up front, then %s a month." % [int(r["tough"]), _money(int(r["price"])), _money(int(r["wage"]))]],
				"options": [{"text": "Hire him", "sub": _money(int(r["price"])), "icon": "crew", "enabled": int(p["wallet"]) >= int(r["price"]), "action": _act("hire", int(r["id"]))}, _leave()]}
	return {}


static func _crew(a: Actor) -> Dictionary:
	var me := _fam()
	var c := Game.crew_by_id(a.ref_id)
	if c.is_empty():
		return {}
	if int(c["family"]) != me:
		return {"name": String(c["name"]), "role": "The %s family" % Game.fam(int(c["family"]))["name"], "portrait": _portrait(a), "line": "\"Keep walking.\"", "options": [_leave()]}
	var t: Dictionary = Rackets.TRAITS.get(String(c.get("trait", "")), {})
	var task := String(c["task"])
	var doing: String = {"follow": "with you", "guard": "guarding a shop", "collect": "collecting envelopes", "booze": "on the booze run",
		"idle": "at the club", "take": "taking a shop"}.get(task, task)
	var opts := [{"text": "Follow me", "icon": "crew", "action": _req("crew_task", [c["id"], "follow", -1])}]
	var here: Dictionary = world.biz_at_lot(world.local_actor.lot) if world.local_actor else {}
	if here.is_empty() and world.local_actor:
		here = _nearest_biz(world.local_actor.position)
	if not here.is_empty():
		if int(here["protector"]) == me or int(here["owned_by"]) == me:
			opts.append({"text": "Guard %s" % here["name"], "icon": "crew", "action": _req("crew_task", [c["id"], "guard", here["id"]])})
			opts.append({"text": "Collect our envelopes in %s" % here["district"], "icon": "money", "action": _req("crew_task", [c["id"], "collect", here["id"]])})
		elif here["kind"] not in ["precinct", "club", "warehouse"] and int(here["owned_by"]) < 0:
			opts.append({"text": "Take %s for us" % here["name"], "sub": "he leans on the owner", "icon": "fist", "action": _req("crew_task", [c["id"], "take", here["id"]])})
	if not Game.nyc_warehouse(me).is_empty() and task != "booze":
		opts.append({"text": "Run the booze", "sub": "20 crates a month, warehouse to speakeasies", "icon": "booze", "action": _req("crew_task", [c["id"], "booze", 20])})
	opts.append({"text": "Go back to the club", "icon": "leave", "action": _req("crew_task", [c["id"], "idle", -1])})
	opts.append(_leave())
	return {"name": String(c["name"]), "role": "%s · %s" % [String(c["rank"]).capitalize(), t.get("name", "")], "portrait": _portrait(a),
		"line": "\"What do you need, boss?\"",
		"info": ["%s. Loyalty %d, tough %d, $%d a month. Now %s." % [t.get("does", ""), int(c["loyalty"]), int(c["tough"]), int(c["wage"]), doing]],
		"options": opts}


static func _nearest_biz(p: Vector2) -> Dictionary:
	var best := {}
	var bd := 12.0 * W.M
	for b in Game.biz:
		var d := W.door(b).distance_to(p)
		if d < bd:
			bd = d
			best = b
	return best


static func _dealer(a: Actor) -> Dictionary:
	var me := _fam()
	var p := _me()
	var ars: Dictionary = Game.fam(me)["arsenal"]
	var half := Rackets.has_ring(me, "pawn")
	var price := func(k: String) -> int: return int(Game.dealer[k]) / (2 if half else 1)
	return {"name": "Izzy the Gun", "role": "The back room of the pawnshop", "portrait": _portrait(a),
		"line": "\"Don't ask where it comes from, and I won't ask where it's going.\"",
		"info": ["You have %d revolvers, %d Thompsons, %d bullets." % [int(ars["pistol"]), int(ars["tommy"]), int(ars["ammo"])],
			"Every shot you fire is evidence, until the gun is at the bottom of the river." + ("  Half price: you run the pawnshops." if half else "")],
		"options": [
			{"text": "A .38 revolver", "sub": _money(price.call("pistol")), "icon": "gun", "enabled": int(p["wallet"]) >= price.call("pistol"), "action": _req("gun", ["pistol"])},
			{"text": "A box of 25 bullets", "sub": _money(price.call("ammo")), "icon": "gun", "enabled": int(p["wallet"]) >= price.call("ammo"), "action": _req("gun", ["ammo"])},
			{"text": "A Thompson submachine gun", "sub": _money(price.call("tommy")) + ("" if Game.year() >= 1928 else "  ·  not until 1928"), "icon": "gun",
				"enabled": int(p["wallet"]) >= price.call("tommy") and Game.year() >= 1928, "action": _req("gun", ["tommy"])},
			_leave()]}


static func _union(a: Actor) -> Dictionary:
	var me := _fam()
	var f := Game.fam(me)
	var n: Dictionary = Game.nation
	var cur := int(n["cities"]["nyc"]["docks"])
	var price := Syndicate.union_price(n, "nyc", me)
	var wage := Syndicate.union_wage("nyc")
	var line := "\"Nobody looks after the local. Shame, for a man with boats coming in.\""
	if cur == me:
		line = "\"Your boats come off first, boss. Like we agreed.\""
	elif cur >= 0:
		line = "\"The %s family looks after us. You want to look after us better? Let's talk.\"" % Game.fam(cur)["name"]
	var opts := []
	if cur != me:
		opts.append({"text": "Put the union on your payroll", "sub": "%s from the Stash, then $%d a month" % [_money(price), wage], "icon": "money",
			"enabled": int(f["dirty"]) >= price, "action": _act("union_pay", 0)})
	var rp := Syndicate.river_price(n, "nyc", me)
	for o in Game.families:
		if o["id"] == me or not o["alive"]:
			continue
		var pending: bool = n["sabotage"].has(str(o["id"]))
		opts.append({"text": "Drop the %s family's next shipment in the river" % o["name"], "sub": _money(rp) + ("  ·  already arranged" if pending else ""),
			"icon": "fist", "enabled": int(f["dirty"]) >= rp and not pending, "action": _act("union_drop", o["id"])})
	opts.append(_leave())
	return {"name": Game.UNION_BOSS, "role": "Hiring boss, Longshoremen's Local %s" % Game.UNION_LOCAL, "portrait": _portrait(a), "line": line,
		"info": ["He decides whose cargo comes off the boats first. With the union, your boats land more crates and get caught less."], "options": opts}


static func _smuggler(a: Actor) -> Dictionary:
	var p := _me()
	var left := int(Game.boat.get("crates", 0))
	var opts := []
	for n in [1, 5, 10]:
		opts.append({"text": "Buy %d crate%s" % [n, "" if n == 1 else "s"], "sub": _money(Game.CRATE_COST * n), "icon": "booze",
			"enabled": int(p["wallet"]) >= Game.CRATE_COST * n and left >= n, "action": _act("crates", 0, n)})
	opts.append(_leave())
	return {"name": "The man from the boat", "role": "The middle pier, tonight only", "portrait": _portrait(a),
		"line": "\"Canadian whisky, straight off the boat. $%d a crate, cash.\"" % Game.CRATE_COST,
		"info": ["%d crates left tonight. They go on the pier: carry them to your truck, then drive them to your speakeasy." % left], "options": opts}


## A sit-down with another family's boss (at his club, or on the street).
static func _sitdown(other: int, a: Actor, line: String = "") -> Dictionary:
	var me := _fam()
	var o := Game.fam(other)
	if o.is_empty() or other == me:
		return {}
	var r := Game.rel(me, other)
	var status := "At war with you." if r["war"] else ("Truce until %s." % Game.date_text(int(r["truce_until"])) if Game.has_truce(me, other) else "No deal between you.")
	var opts := [
		{"text": "Propose a truce", "sub": "6 months", "icon": "deal", "action": _req("propose", [other, {"kind": "truce", "months": 6, "amount": 0}])},
		{"text": "Pay for a year of peace", "sub": "$500 from the Stash", "icon": "money", "enabled": int(Game.fam(me)["dirty"]) >= 500,
			"action": _req("propose", [other, {"kind": "truce", "months": 12, "amount": 500}])},
		{"text": "Demand $500 tribute", "sub": "or else", "icon": "fist", "action": _req("propose", [other, {"kind": "tribute", "months": 6, "amount": -500}])},
	]
	for f in Game.families:
		if f["id"] != me and f["id"] != other and f["alive"]:
			opts.append({"text": "Team up against the %s family" % f["name"], "icon": "deal",
				"action": _req("propose", [other, {"kind": "alliance", "months": 12, "amount": 0, "against": f["id"]}])})
	opts.append(_leave())
	return {"name": "Don %s" % o["name"], "role": "The %s family%s" % [o["name"], "" if o["ai"] else " (a player)"], "portrait": _portrait(a),
		"mood": "angry" if r["war"] else "", "line": line if line != "" else ("\"You've got some nerve.\"" if r["war"] else "\"Sit. Let's talk business.\""),
		"info": [status, "Kept his word %d times, broke it %d. %d men, %d rackets." % [int(o["kept"]), int(o["broken"]), Game.crew_of(other).size(), Game.shops_of(other).size()]],
		"options": opts}


# ------------------------------------------------------------------ things

static func _object(focus: Dictionary) -> Dictionary:
	var b := Game.biz_by_id(int(focus["biz"]))
	var type := String(focus["item"])
	var me := _fam()
	var f := Game.fam(me)
	var p := _me()
	match type:
		"safe":
			if int(b.get("hq_of", -1)) != me:
				return {"name": "The %s family's safe" % Game.fam(int(b["hq_of"])).get("name", ""), "line": "A heavy Mosler safe. The dial is cold.",
					"options": [{"text": "Crack it", "sub": "they'll know it was you", "icon": "fist", "action": _act("safe_rob", b["id"])}, _leave()]}
			return {"name": "The safe", "role": "Your club, the back office", "line": "Your Stash: the family's dirty money.",
				"info": ["Stash %s · Wallet %s. Money in your wallet can be lost if you're knocked down." % [_money(int(f["dirty"])), _money(int(p["wallet"]))]],
				"options": [{"text": "Put your wallet in the safe", "sub": _money(int(p["wallet"])), "icon": "money", "enabled": int(p["wallet"]) > 0, "action": _act("bank_in", b["id"])},
					{"text": "Take $500", "icon": "money", "enabled": int(f["dirty"]) > 0, "action": _act("bank_out", b["id"])},
					{"text": "Take $2,000", "icon": "money", "enabled": int(f["dirty"]) >= 2000, "action": _act("bank_out_big", b["id"])}, _leave()]}
		"desk":
			var opts := [{"text": "Open the family book", "sub": "your men, rackets, heat, rivals, money (Tab)", "icon": "talk", "action": func() -> void: world.hud.toggle_family()}]
			var books := (f["evidence"] as Array).filter(func(e: Dictionary) -> bool: return e["kind"] == "ledger")
			if not books.is_empty():
				opts.append({"text": "Burn the books", "sub": "$300 from the Bank to start clean ones", "icon": "fist", "enabled": int(f["clean"]) >= 300, "action": _req("burn_books", [])})
			if Game.players.size() == 1:
				opts.append({"text": "Wait until dark" if Game.clock < 0.55 else "Sleep until morning", "sub": "the boat comes in at night" if Game.clock < 0.55 else "the month turns",
					"icon": "talk", "action": _req("wait", [])})
			if Net.is_host():
				opts.append({"text": "Save the game", "icon": "talk", "action": _req("save", [])})
			opts.append(_leave())
			return {"name": "The desk", "role": "Your club, the back office", "line": "The ledgers, a telephone, a photograph of your mother.", "options": opts}
		"map_table":
			return {"name": "The map table", "role": "Your club, the back office", "line": "Pins, string and grease pencil: who pays whom.",
				"options": [{"text": "The city", "sub": "every shop, who pays whom, send your men (M)", "icon": "talk", "action": func() -> void: world.hud.toggle_map()},
					{"text": "The country", "sub": "other cities, smuggling routes, capos (J)", "icon": "talk", "action": func() -> void: world.hud.toggle_nation()}, _leave()]}
		"phone":
			var opts2 := []
			for d in Game.deals:
				if int(d["to"]) == me:
					var t: Dictionary = d["terms"]
					var what := "a truce for %d months" % int(t.get("months", 6))
					if t.get("kind", "") == "alliance":
						what = "an alliance against the %s family" % Game.fam(int(t.get("against", -1))).get("name", "?")
					var amt := int(t.get("amount", 0))
					if amt > 0:
						what += ", and they pay you $%d" % amt
					elif amt < 0:
						what += ", if you pay them $%d" % -amt
					var did: int = d["id"]
					opts2.append({"text": "Accept: the %s family offers %s" % [Game.fam(int(d["from"]))["name"], what], "icon": "deal", "action": _req("respond", [did, true])})
					opts2.append({"text": "Refuse the %s family" % Game.fam(int(d["from"]))["name"], "icon": "leave", "action": _req("respond", [did, false])})
			opts2.append({"text": "Call all your men here", "icon": "crew", "action": func() -> void:
				for c in Game.crew_of(me):
					Net.to_host("crew_task", [c["id"], "follow", -1])})
			opts2.append(_leave())
			return {"name": "The telephone", "role": "Your club", "line": "\"Operator? Get me...\"" if opts2.size() > 2 else "Nobody's called.",
				"options": opts2}
		"register":
			if int(b["owned_by"]) == me:
				return {}
			return {"name": "The till", "role": b["name"], "line": "Brass and glass. The drawer's full of the day's takings.",
				"options": [{"text": "Empty the till", "sub": "a robbery: people will see", "icon": "fist", "action": _act("rob", b["id"])}, _leave()]}
		"cell":
			return {}
	return {}
