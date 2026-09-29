class_name Advisor
extends RefCounted
## When the tutorial is over and you're not doing a favor, the goal box still says something
## useful: the most pressing thing to do next, with an arrow to it. Most urgent first: the law,
## unpaid men, money waiting, a favor, a dry speakeasy, then the next shop to take.


static func next(world: Node) -> Dictionary:
	var p := Game.player(Net.my_id())
	var me := int(p.get("family", -1))
	var f := Game.fam(me)
	var a: Actor = world.local_actor
	if f.is_empty() or a == null:
		return {}
	var at := a.position
	# 1. the law is closing in
	if float(f["heat"]) >= 65.0:
		var best := {}
		var bd := INF
		for e in f["evidence"]:
			var where := Vector2.INF
			var what := ""
			match String(e["kind"]):
				"witness":
					var b := Game.biz_by_id(int(e.get("biz", -1)))
					if not b.is_empty():
						where = world.talk_spot(int(b["id"]))
						what = "Pay or scare the witness at %s" % b["name"]
				"weapon":
					var tip: Array = world.plan.piers[0]["tip"]
					where = W.p(float(tip[0]) + 1.5, float(tip[1]))
					what = "Throw your gun in the river, at the end of a pier"
			if where != Vector2.INF and float(e["w"]) > 2.0 and at.distance_to(where) < bd:
				bd = at.distance_to(where)
				best = {"title": "Heat %d: the feds raid at 100" % int(f["heat"]), "detail": what, "target": where}
		if not best.is_empty():
			return best
		return {"title": "Heat %d: the feds raid at 100" % int(f["heat"]), "detail": "Lie low, or open the family book (Tab, Heat) to see what they have", "target": Vector2.INF}
	# 2. men who won't get paid
	var wages := 0
	for c in Game.crew_of(me):
		wages += int(c["wage"])
	var hq := Game.biz_by_id(int(f["hq"]))
	var lay: Dictionary = world.layout_of_biz(int(hq.get("id", -1)))
	if wages > 0 and int(f["dirty"]) < wages and int(p.get("wallet", 0)) > 0:
		return {"title": "Your men need paying", "detail": "Put your wallet in the safe at your club: wages come from the Stash",
			"target": lay["spots"].get("safe", W.door(hq)) if not lay.is_empty() else W.door(hq)}
	# 3. envelopes waiting
	var waiting := []
	for b in Game.shops_of(me):
		if int(b["envelope"]) > 0 and int(b["owned_by"]) != me:
			waiting.append(b)
	if waiting.size() >= 2:
		waiting.sort_custom(func(x, y) -> bool: return W.door(x).distance_to(at) < W.door(y).distance_to(at))
		var total := 0
		for b in waiting:
			total += int(b["envelope"])
		return {"title": "Collect your envelopes: $%s waiting" % W.money(total), "detail": "%d shops · nearest: %s" % [waiting.size(), waiting[0]["name"]],
			"target": world.talk_spot(int(waiting[0]["id"]))}
	# 4. somebody needs a favor, close by
	var fav := {}
	var fd := 60.0 * W.M
	for b in Game.biz:
		if b.has("favor") and W.door(b).distance_to(at) < fd:
			fd = W.door(b).distance_to(at)
			fav = b
	if not fav.is_empty():
		return {"title": "%s needs a favor" % fav["owner_name"], "detail": "%s · look for the \"!\"" % fav["name"], "target": W.door(fav)}
	# 5. a speakeasy running dry at night
	if world.night_level() > 0.4:
		for b in Game.owned_by(me):
			if b["speak"] and int(b["stock"]) < 5:
				var tip2: Array = world.plan.piers[1]["tip"]
				return {"title": "%s is running dry" % b["name"], "detail": "The boat is in at the middle pier: buy crates, truck them over",
					"target": W.p(float(tip2[0]), float(tip2[1]))}
	# 6. the next shop to take
	var best2 := {}
	var bd2 := INF
	for b in Game.biz:
		if b["kind"] in ["club", "precinct", "warehouse"] or int(b["protector"]) >= 0 or int(b["owned_by"]) >= 0:
			continue
		if int(b.get("snapped_until", -1)) >= Game.month:
			continue
		var d := W.door(b).distance_to(at)
		if d < bd2:
			bd2 = d
			best2 = b
	if not best2.is_empty():
		var weak: Dictionary = Rackets.WEAK.get(String(best2.get("weak", "")), {})
		return {"title": "Take %s" % best2["name"], "detail": "Pays nobody · $%d a month · %s" % [int(best2["rate"]), weak.get("does", "")],
			"target": world.talk_spot(int(best2["id"]))}
	return {}
