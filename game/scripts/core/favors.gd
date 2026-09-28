class_name Favors
extends RefCounted
## Favors: shopkeepers with a problem. A shop with a favor to ask shows a "!" over its door. Do it
## and he's grateful: a shop that pays nobody starts paying you (the way in without breaking
## anything), one that already pays you pays more.
##
## Kinds:
##   thugs     a rival family's boys lean on him. Knock them down or run them off.
##   debt      a man owes him money and won't pay. Get it back (talk tough, or knock him down).
##   parcel    take a parcel to another shop, no questions asked.
##
## State: biz["favor"] = {kind, reward, until (month), target_biz, rival} (the offer); a player's
## job is players[peer]["job"] = {kind, biz, reward, until, target_biz, rival, keys: [actor keys]}.

const MAX_OFFERS := 4


static func text(f: Dictionary, b: Dictionary) -> Dictionary:
	var kind := String(f.get("kind", ""))
	var tb: Dictionary = Game.biz_by_id(int(f.get("target_biz", -1)))
	var rival: Dictionary = Game.fam(int(f.get("rival", -1)))
	match kind:
		"thugs":
			return {"ask": "\"Two of the %s boys come in every day. They take what they want and they break things. Make them stop.\"" % rival.get("name", "neighbourhood"),
				"title": "Run off the %s thugs" % rival.get("name", ""), "detail": "Outside %s" % b.get("name", "")}
		"debt":
			return {"ask": "\"A man owes me $%d. He drinks it all away on %s and laughs at me. Get my money back and half is yours.\"" % [int(f["reward"]) * 2, tb.get("address", "the corner")],
				"title": "Collect a debt", "detail": "He hangs around outside %s" % tb.get("name", "")}
		"parcel":
			return {"ask": "\"Take this to %s at %s. Don't open it, don't drop it, don't let a cop see it.\"" % [tb.get("owner_name", ""), tb.get("name", "")],
				"title": "Deliver the parcel", "detail": "%s · %s" % [tb.get("name", ""), tb.get("address", "")]}
	return {}


## Host, every month and at the start: a few shops ask for help. Near your turf, mostly.
static func refresh(game: Node) -> void:
	var offers := 0
	for b in game.biz:
		if b.has("favor") and int(b["favor"].get("until", -1)) >= int(game.month):
			offers += 1
		else:
			b.erase("favor")
	var rng := RandomNumberGenerator.new()
	rng.seed = int(game.cfg["seed"]) * 31 + int(game.month) * 7
	var cands: Array = game.biz.filter(func(b: Dictionary) -> bool:
		return b["kind"] not in ["club", "precinct", "warehouse", "poolhall"] and int(b["owned_by"]) < 0 and not b.has("favor") \
			and int(b["closed_until"]) < int(game.month))
	var tries := 0
	while offers < MAX_OFFERS and not cands.is_empty() and tries < 20:
		tries += 1
		var b: Dictionary = cands[rng.randi_range(0, cands.size() - 1)]
		cands.erase(b)
		var kind: String = ["thugs", "debt", "parcel"][rng.randi_range(0, 2)]
		var f := {"kind": kind, "reward": rng.randi_range(8, 16) * 10, "until": int(game.month) + 1, "target_biz": -1, "rival": -1}
		var others: Array = game.biz.filter(func(o: Dictionary) -> bool: return o["id"] != b["id"] and o["kind"] not in ["club", "precinct", "warehouse"])
		f["target_biz"] = int(others[rng.randi_range(0, others.size() - 1)]["id"])
		if kind == "thugs":
			var rivals: Array = game.families.filter(func(o: Dictionary) -> bool: return bool(o["alive"]) and bool(o["ai"]))
			if rivals.is_empty():
				continue
			f["rival"] = int(rivals[rng.randi_range(0, rivals.size() - 1)]["id"])
			f["target_biz"] = int(b["id"])
		b["favor"] = f
		offers += 1
	game.mark_dirty()


## Host: a player takes the job. Returns {ok, msg, spawn: [...]} (the World spawns the people).
static func accept(game: Node, peer: int, biz_id: int) -> Dictionary:
	var p: Dictionary = game.player(peer)
	var b: Dictionary = game.biz_by_id(biz_id)
	if p.is_empty() or b.is_empty() or not b.has("favor"):
		return {"ok": false, "msg": "He doesn't need anything now."}
	if p.has("job") and not (p["job"] as Dictionary).is_empty():
		return {"ok": false, "msg": "Finish the favor you're doing first."}
	var f: Dictionary = b["favor"]
	var job := f.duplicate()
	job["biz"] = biz_id
	job["keys"] = []
	p["job"] = job
	b.erase("favor")
	game.mark_dirty()
	var t := text(job, b)
	return {"ok": true, "msg": "\"Thank you. I won't forget it.\" %s." % t.get("title", "")}


## Host: the job is done. Pays the player and makes the shop grateful.
static func complete(game: Node, peer: int) -> Dictionary:
	var p: Dictionary = game.player(peer)
	if p.is_empty() or not p.has("job") or (p["job"] as Dictionary).is_empty():
		return {}
	var job: Dictionary = p["job"]
	var b: Dictionary = game.biz_by_id(int(job["biz"]))
	var family := int(p["family"])
	var f: Dictionary = game.fam(family)
	p["wallet"] = int(p["wallet"]) + int(job["reward"])
	f["rep"] = int(f["rep"]) + 2
	var msg := "Favor done: $%d." % int(job["reward"])
	if not b.is_empty():
		if int(b["protector"]) < 0 and int(b["owned_by"]) < 0:
			b["protector"] = family
			b["defiance"] = 0
			msg += " %s is grateful: he pays you $%d a month now." % [b["owner_name"], int(b["rate"])]
		elif int(b["protector"]) == family:
			b["rate"] = int(b["rate"]) + 15
			msg += " %s pays you $15 more a month." % b["owner_name"]
		else:
			b["defiance"] = maxi(0, int(b["defiance"]) - 30)
			b["fear"] = maxf(float(b["fear"]), 40.0)
			msg += " %s owes you. He'll listen next time you make him an offer." % b["owner_name"]
	p["job"] = {}
	game.mark_dirty()
	return {"ok": true, "msg": msg, "keys": job.get("keys", [])}


static func fail(game: Node, peer: int, why: String) -> Dictionary:
	var p: Dictionary = game.player(peer)
	if p.is_empty() or not p.has("job") or (p["job"] as Dictionary).is_empty():
		return {}
	var job: Dictionary = p["job"]
	p["job"] = {}
	game.mark_dirty()
	return {"ok": false, "msg": why, "keys": job.get("keys", [])}
