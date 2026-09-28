class_name Syndicate
extends RefCounted
## The national game: cities across the country and the smuggling routes between them.
## New York is the city you walk; the rest you run through the capos you send there.
##
## Each city: who controls how much of it (influence per family, the rest held by the local
## outfit), the men and guns each family keeps there, whether the local police are bought, its
## liquor market. Each route: a smuggling line from a source (Canada, Rum Row, Havana) to a
## city, with a capacity, a risk and whoever bought the officials along it.
## Every month (host): convoys run, ambushes spring, capos fight for influence, hits land.
##
## State lives in Game.nation (plain dicts, saved and sent with everything else).

const CITIES := [
	# id, name, map position (0..1 on the national map), liquor demand (crates/month), local outfit, flavour
	{"id": "nyc", "name": "New York", "pos": [0.83, 0.37], "demand": 0, "outfit": "the Five Points boys", "note": "Your streets. You walk this city."},
	{"id": "chi", "name": "Chicago", "pos": [0.47, 0.35], "demand": 140, "outfit": "the North Side Gang", "note": "The biggest thirst in America. Breweries, beer wars, Cicero."},
	{"id": "atl", "name": "Atlantic City", "pos": [0.815, 0.46], "demand": 60, "outfit": "Nucky's Boardwalk machine", "note": "Rum Row lands here. The boardwalk, the hotels, the 1929 conference."},
	{"id": "phl", "name": "Philadelphia", "pos": [0.785, 0.42], "demand": 70, "outfit": "the Duke's bootleggers", "note": "Docks and breweries. The Philly cops come cheap."},
	{"id": "bos", "name": "Boston", "pos": [0.9, 0.27], "demand": 55, "outfit": "the Gustin Gang", "note": "Irish wards and the harbour. Rum from the Maritimes."},
	{"id": "det", "name": "Detroit", "pos": [0.56, 0.3], "demand": 80, "outfit": "the Purple Gang", "note": "The Windsor crossing: three quarters of Canada's liquor comes over this river."},
	{"id": "cle", "name": "Cleveland", "pos": [0.62, 0.34], "demand": 50, "outfit": "the Mayfield Road Mob", "note": "Corn sugar and stills. Lake Erie boats."},
	{"id": "kc", "name": "Kansas City", "pos": [0.34, 0.46], "demand": 40, "outfit": "the Pendergast machine", "note": "A wide-open town: the machine owns the police. Pay the machine and nobody sees anything."},
	{"id": "nola", "name": "New Orleans", "pos": [0.43, 0.8], "demand": 45, "outfit": "the Matranga clan", "note": "Gulf rum and slot machines."},
]
const SOURCES := [
	{"id": "mtl", "name": "Montreal", "pos": [0.8, 0.14], "price": 22, "note": "Distilleries across the border."},
	{"id": "wnd", "name": "Windsor", "pos": [0.585, 0.25], "price": 20, "note": "Canadian whisky, a mile across the river from Detroit."},
	{"id": "rum", "name": "Rum Row", "pos": [0.9, 0.5], "price": 28, "note": "Freighters anchored past the three-mile limit."},
	{"id": "hav", "name": "Havana", "pos": [0.66, 0.97], "price": 18, "note": "Cuban rum by the shipload."},
]
const ROUTES := [
	# id, source, city, capacity (crates/month), base risk, border to buy (cost)
	{"id": "champlain", "name": "Lake Champlain run", "from": "mtl", "to": "nyc", "cap": 120, "risk": 0.12, "bribe": 1500},
	{"id": "detroit_river", "name": "Detroit River crossing", "from": "wnd", "to": "det", "cap": 200, "risk": 0.1, "bribe": 1800},
	{"id": "rum_row_nyc", "name": "Rum Row to New York", "from": "rum", "to": "nyc", "cap": 160, "risk": 0.16, "bribe": 2000},
	{"id": "rum_row_atl", "name": "Rum Row to Atlantic City", "from": "rum", "to": "atl", "cap": 150, "risk": 0.1, "bribe": 1200},
	{"id": "maritime", "name": "Maritime schooners", "from": "mtl", "to": "bos", "cap": 90, "risk": 0.14, "bribe": 1200},
	{"id": "lake_erie", "name": "Lake Erie boats", "from": "wnd", "to": "cle", "cap": 90, "risk": 0.12, "bribe": 1000},
	{"id": "windsor_chi", "name": "Windsor to Chicago trucks", "from": "wnd", "to": "chi", "cap": 140, "risk": 0.18, "bribe": 2200},
	{"id": "gulf", "name": "Gulf of Mexico run", "from": "hav", "to": "nola", "cap": 120, "risk": 0.1, "bribe": 900},
	{"id": "gulf_kc", "name": "Gulf rum up the Mississippi", "from": "hav", "to": "kc", "cap": 70, "risk": 0.15, "bribe": 800},
	{"id": "philly_docks", "name": "Delaware River docks", "from": "rum", "to": "phl", "cap": 110, "risk": 0.12, "bribe": 1100},
]
const CITY_PRICE := 70        # what a crate fetches wholesale in another city
const HIT_COST := 1500


static func fresh() -> Dictionary:
	var cities := {}
	for c in CITIES:
		cities[c["id"]] = {"influence": {}, "men": {}, "guns": {}, "capo": {}, "police": -1, "heat": {}}
	var routes := {}
	for r in ROUTES:
		routes[r["id"]] = {"owner": -1, "convoys": {}, "ambush": {}, "last": ""}
	return {"cities": cities, "routes": routes, "log": []}


static func city_def(id: String) -> Dictionary:
	for c in CITIES:
		if c["id"] == id:
			return c
	return {}


static func source_def(id: String) -> Dictionary:
	for s in SOURCES:
		if s["id"] == id:
			return s
	return {}


static func route_def(id: String) -> Dictionary:
	for r in ROUTES:
		if r["id"] == id:
			return r
	return {}


static func place_def(id: String) -> Dictionary:
	var c := city_def(id)
	return c if not c.is_empty() else source_def(id)


static func influence(nation: Dictionary, city: String, family: int) -> float:
	return float(nation["cities"][city]["influence"].get(str(family), 0.0))


static func controller(nation: Dictionary, city: String) -> int:
	var best := -1
	var bv := 50.0
	for k in nation["cities"][city]["influence"]:
		var v := float(nation["cities"][city]["influence"][k])
		if v > bv:
			bv = v
			best = int(k)
	return best


static func men_in(nation: Dictionary, city: String, family: int) -> int:
	return int(nation["cities"][city]["men"].get(str(family), 0))


static func guns_in(nation: Dictionary, city: String, family: int) -> int:
	return int(nation["cities"][city]["guns"].get(str(family), 0))


## Strength of a family's crew in a city: men, their guns, a capo leading them.
static func muscle(nation: Dictionary, city: String, family: int) -> float:
	var men := men_in(nation, city, family)
	var guns := mini(guns_in(nation, city, family), men)
	var capo := 1.4 if nation["cities"][city]["capo"].has(str(family)) else 1.0
	return (men + guns * 1.2) * capo


# ------------------------------------------------------------------ orders (host, via Game)

static func send_men(game: Node, family: int, city: String, men: int, guns: int, capo_id: int) -> Dictionary:
	var n: Dictionary = game.nation
	if not n["cities"].has(city) or city == "nyc":
		return {"ok": false, "msg": "You run New York in person."}
	var f: Dictionary = game.fam(family)
	var cost := men * 250
	if f["dirty"] < cost:
		return {"ok": false, "msg": "Setting up %d men in %s costs $%d." % [men, city_def(city)["name"], cost]}
	var arsenal: Dictionary = f["arsenal"]
	guns = mini(guns, int(arsenal.get("pistol", 0)) + int(arsenal.get("tommy", 0)))
	f["dirty"] -= cost
	_take_guns(arsenal, guns)
	var c: Dictionary = n["cities"][city]
	c["men"][str(family)] = men_in(n, city, family) + men
	c["guns"][str(family)] = guns_in(n, city, family) + guns
	var msg := "%d men%s head for %s." % [men, (" with %d guns" % guns) if guns > 0 else "", city_def(city)["name"]]
	if capo_id >= 0:
		var capo: Dictionary = game.crew_by_id(capo_id)
		if not capo.is_empty() and capo["state"] == "free" and capo["family"] == family:
			capo["state"] = "away"
			capo["rank"] = "capo"
			capo["task"] = "city:" + city
			c["capo"][str(family)] = capo_id
			msg += " %s will run it." % capo["name"]
	if not c["influence"].has(str(family)):
		c["influence"][str(family)] = 3.0
	game.mark_dirty()
	return {"ok": true, "msg": msg}


static func _take_guns(arsenal: Dictionary, n: int) -> void:
	var t := mini(n, int(arsenal.get("tommy", 0)))
	arsenal["tommy"] = int(arsenal.get("tommy", 0)) - t
	arsenal["pistol"] = maxi(0, int(arsenal.get("pistol", 0)) - (n - t))


static func bribe_police(game: Node, family: int, city: String) -> Dictionary:
	var n: Dictionary = game.nation
	var f: Dictionary = game.fam(family)
	var cost := 1200 if city != "kc" else 2500
	if f["dirty"] < cost:
		return {"ok": false, "msg": "The %s police want $%d." % [city_def(city)["name"], cost]}
	f["dirty"] -= cost
	var prev: int = n["cities"][city]["police"]
	n["cities"][city]["police"] = family
	if prev >= 0 and prev != family:
		game.aggression(family, prev, 8)
	game.mark_dirty()
	return {"ok": true, "msg": "The %s police now answer to you. Their raids will find the other families." % city_def(city)["name"]}


static func bribe_route(game: Node, family: int, route: String) -> Dictionary:
	var n: Dictionary = game.nation
	var d := route_def(route)
	var f: Dictionary = game.fam(family)
	var r: Dictionary = n["routes"][route]
	var cost := int(d["bribe"]) + (800 if int(r["owner"]) >= 0 else 0)
	if f["dirty"] < cost:
		return {"ok": false, "msg": "Customs men, sheriffs and Coast Guard skippers along the %s: $%d." % [d["name"], cost]}
	f["dirty"] -= cost
	var prev: int = r["owner"]
	r["owner"] = family
	if prev >= 0 and prev != family:
		game.aggression(family, prev, 12)
		game._notice(prev, "The %s family bought the %s out from under you." % [f["name"], d["name"]], "bad")
	game.mark_dirty()
	return {"ok": true, "msg": "The %s is yours: your convoys pass, everybody else's pay you a toll or get stopped." % d["name"]}


static func set_convoy(game: Node, family: int, route: String, crates: int) -> Dictionary:
	var n: Dictionary = game.nation
	var d := route_def(route)
	crates = clampi(crates, 0, int(d["cap"]))
	n["routes"][route]["convoys"][str(family)] = crates
	game.mark_dirty()
	if crates == 0:
		return {"ok": true, "msg": "No more runs on the %s." % d["name"]}
	return {"ok": true, "msg": "%d crates a month on the %s (paid at the source, $%d a crate)." % [crates, d["name"], source_def(d["from"])["price"]]}


static func set_ambush(game: Node, family: int, route: String, men: int) -> Dictionary:
	var n: Dictionary = game.nation
	var d := route_def(route)
	men = clampi(men, 0, 6)
	n["routes"][route]["ambush"][str(family)] = men
	game.mark_dirty()
	if men == 0:
		return {"ok": true, "msg": "Your hijackers come home from the %s." % d["name"]}
	return {"ok": true, "msg": "%d men wait on the %s for other families' trucks." % [men, d["name"]]}


static func order_hit(game: Node, family: int, city: String, target_family: int) -> Dictionary:
	var n: Dictionary = game.nation
	var f: Dictionary = game.fam(family)
	var c: Dictionary = n["cities"][city]
	if f["dirty"] < HIT_COST:
		return {"ok": false, "msg": "A contract costs $%d." % HIT_COST}
	var capo_id := int(c["capo"].get(str(target_family), -1))
	var target := "the %s family's men" % game.fam(target_family)["name"]
	if capo_id >= 0:
		target = game.crew_by_id(capo_id).get("name", target)
	f["dirty"] -= HIT_COST
	var mine := muscle(n, city, family) + 2.0
	var theirs := muscle(n, city, target_family) * 0.6 + 1.0
	var chance := clampf(0.35 + (mine - theirs) * 0.06 + int(f["arsenal"].get("tommy", 0)) * 0.03, 0.1, 0.85)
	game.aggression(family, target_family, 35)
	if randf() < chance:
		if capo_id >= 0:
			var capo: Dictionary = game.crew_by_id(capo_id)
			capo["state"] = "dead"
			c["capo"].erase(str(target_family))
		c["men"][str(target_family)] = maxi(0, men_in(n, city, target_family) - 2)
		c["influence"][str(target_family)] = influence(n, city, target_family) * 0.6
		game.add_evidence(family, "body", "The body of %s, found in %s" % [target, city_def(city)["name"]], 18.0)
		game._log("GANGLAND SLAYING IN %s: %s gunned down." % [city_def(city)["name"].to_upper(), target])
		game._notice(target_family, "%s was killed in %s. Everyone knows who ordered it." % [target, city_def(city)["name"]], "bad")
		game.mark_dirty()
		return {"ok": true, "msg": "It's done. %s won't be a problem in %s." % [target, city_def(city)["name"]]}
	c["men"][str(family)] = maxi(0, men_in(n, city, family) - 1)
	game.add_evidence(family, "witness", "A shooter who got away in %s: people saw his face" % city_def(city)["name"], 12.0)
	game._notice(target_family, "Someone tried to kill %s in %s. The %s family." % [target, city_def(city)["name"], f["name"]], "bad")
	game.mark_dirty()
	return {"ok": false, "msg": "The hit went wrong. Your shooter is dead and %s knows who sent him." % target}


# ------------------------------------------------------------------ the month (host)

static func tick(game: Node) -> void:
	var n: Dictionary = game.nation
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	n["log"] = []
	_run_routes(game, n, rng)
	_contest_cities(game, n, rng)
	_ai_orders(game, n, rng)


static func _run_routes(game: Node, n: Dictionary, rng: RandomNumberGenerator) -> void:
	for d in ROUTES:
		var r: Dictionary = n["routes"][d["id"]]
		var src := source_def(d["from"])
		var dest: String = d["to"]
		var summary := []
		for k in r["convoys"].keys():
			var fam := int(k)
			var f: Dictionary = game.fam(fam)
			if f.is_empty() or not f["alive"]:
				continue
			var crates := int(r["convoys"][k])
			if crates <= 0:
				continue
			var cost := crates * int(src["price"])
			if f["dirty"] < cost:
				crates = int(f["dirty"]) / int(src["price"])
				cost = crates * int(src["price"])
			if crates <= 0:
				continue
			f["dirty"] -= cost
			var owner: int = r["owner"]
			if owner >= 0 and owner != fam:
				if game.has_truce(owner, fam):
					var toll := int(crates * 5)
					f["dirty"] -= mini(toll, int(f["dirty"]))
					game.fam(owner)["dirty"] += toll
				elif rng.randf() < 0.35:
					game._notice(fam, "Your convoy on the %s was turned back: the %s family owns the officials there." % [d["name"], game.fam(owner)["name"]], "bad")
					game.aggression(owner, fam, 5)
					summary.append("%s turned back" % f["name"])
					continue
			var risk: float = d["risk"] * (0.4 if owner == fam else 1.0) + float(f["heat"]) / 400.0
			if rng.randf() < risk:
				f["heat"] += 6.0
				game._notice(fam, "Prohibition agents seized your convoy on the %s: %d crates lost." % [d["name"], crates], "bad")
				game.add_evidence(fam, "ledger", "Seized trucks on the %s, traced to your people" % d["name"], 6.0)
				summary.append("%s seized" % f["name"])
				continue
			# hijackers from other families
			var hijacked := false
			for a in r["ambush"].keys():
				var af := int(a)
				if af == fam or int(r["ambush"][a]) <= 0 or game.has_truce(af, fam):
					continue
				var ch := 0.12 * int(r["ambush"][a]) - muscle(n, dest, fam) * 0.01
				if rng.randf() < ch:
					var stolen := int(crates * 0.7)
					_deliver(game, n, af, dest, stolen)
					game.aggression(af, fam, 14)
					game._notice(fam, "Hijacked on the %s! %d crates gone. Somebody talked." % [d["name"], stolen], "bad")
					game._notice(af, "Your men hit a %s family convoy on the %s: %d crates." % [f["name"], d["name"], stolen], "good")
					game._log("TRUCKS HIJACKED on the %s: drivers beaten, cargo gone." % d["name"])
					summary.append("%s hijacked by %s" % [f["name"], game.fam(af)["name"]])
					hijacked = true
					break
			if hijacked:
				continue
			_deliver(game, n, fam, dest, crates)
			summary.append("%s %d crates" % [f["name"], crates])
		r["last"] = ", ".join(summary)


## Crates arriving in a city: New York crates go into the family's cellars (speakeasies, then the
## warehouse), elsewhere they are sold wholesale in proportion to your influence there.
static func _deliver(game: Node, n: Dictionary, fam: int, city: String, crates: int) -> void:
	var f: Dictionary = game.fam(fam)
	if city == "nyc":
		var speaks: Array = game.owned_by(fam).filter(func(b: Dictionary) -> bool: return b["speak"])
		if speaks.is_empty():
			f["cellar"] = int(f.get("cellar", 0)) + crates
		else:
			var each := crates / speaks.size()
			for b in speaks:
				b["stock"] += each
			f["cellar"] = int(f.get("cellar", 0)) + crates - each * speaks.size()
		return
	var share := clampf(influence(n, city, fam) / 100.0 + 0.25, 0.25, 1.0)
	var cash := int(crates * CITY_PRICE * share * game.speak_mult)
	f["dirty"] += cash
	f["income"]["speakeasy"] = int(f["income"].get("speakeasy", 0)) + cash


static func _contest_cities(game: Node, n: Dictionary, rng: RandomNumberGenerator) -> void:
	for c in CITIES:
		var id: String = c["id"]
		if id == "nyc":
			continue
		var cs: Dictionary = n["cities"][id]
		var inf: Dictionary = cs["influence"]
		var total := 6.0   # the local outfit
		var mus := {}
		for k in cs["men"]:
			var m := muscle(n, id, int(k))
			if m > 0.0:
				mus[k] = m
				total += m
		for k in mus:
			var fam := int(k)
			var f: Dictionary = game.fam(fam)
			var target: float = mus[k] / total * 100.0
			var police_bonus := 8.0 if int(cs["police"]) == fam else 0.0
			inf[k] = clampf(lerpf(float(inf.get(k, 0.0)), target + police_bonus, 0.25), 0.0, 100.0)
			# upkeep: men abroad are paid from the stash
			var wage := int(cs["men"][k]) * 90
			if f["dirty"] >= wage:
				f["dirty"] -= wage
				f["income"]["wages"] = int(f["income"].get("wages", 0)) + wage
			else:
				cs["men"][k] = maxi(0, int(cs["men"][k]) - 1)
				game._notice(fam, "Unpaid men walked away in %s." % c["name"], "warn")
			# the city's rackets
			var take := int(float(inf[k]) / 100.0 * (c["demand"] * 9.0 + 400.0) * game.econ)
			f["dirty"] += take
			f["income"]["protection"] = int(f["income"].get("protection", 0)) + take
		for k in inf.keys():
			if not mus.has(k):
				inf[k] = maxf(0.0, float(inf[k]) - 6.0)
		# a war in the streets when two families both hold serious ground
		var big := mus.keys().filter(func(k) -> bool: return float(inf.get(k, 0.0)) > 20.0)
		if big.size() >= 2:
			var a := int(big[0])
			var b := int(big[1])
			if not game.has_truce(a, b) and rng.randf() < 0.35:
				var loser := a if mus[str(a)] < mus[str(b)] else b
				cs["men"][str(loser)] = maxi(0, int(cs["men"][str(loser)]) - 1)
				game.aggression(a if loser == b else b, loser, 6)
				game._log("SHOOTOUT IN %s: the %s and %s families fight over the city." % [c["name"].to_upper(), game.fam(a)["name"], game.fam(b)["name"]])
				game._notice(loser, "You lost a man in the fighting in %s." % c["name"], "bad")
		var ctrl := controller(n, id)
		if ctrl >= 0 and cs.get("last_ctrl", -1) != ctrl:
			game._log("THE %s FAMILY NOW RUNS %s." % [game.fam(ctrl)["name"].to_upper(), c["name"].to_upper()])
			game._notice(ctrl, "You run %s now." % c["name"], "good")
		cs["last_ctrl"] = ctrl


static func _ai_orders(game: Node, n: Dictionary, rng: RandomNumberGenerator) -> void:
	for f in game.families:
		if not f["ai"] or not f["alive"]:
			continue
		var id: int = f["id"]
		# pick a home route and a target city once they can afford it
		if f["dirty"] > 2500 and rng.randf() < 0.3:
			var choices := CITIES.filter(func(c: Dictionary) -> bool: return c["id"] != "nyc")
			var c: Dictionary = choices[(id * 3 + game.month) % choices.size()]
			if men_in(n, c["id"], id) < 6:
				var men := 2
				var arsenal: Dictionary = f["arsenal"]
				arsenal["pistol"] = int(arsenal.get("pistol", 0)) + 1
				send_men(game, id, c["id"], men, 1, -1)
		if f["dirty"] > 1500:
			var owned := false
			for d in ROUTES:
				if int(n["routes"][d["id"]]["owner"]) == id or int(n["routes"][d["id"]]["convoys"].get(str(id), 0)) > 0:
					owned = true
			if not owned:
				var d: Dictionary = ROUTES[(id * 5 + 1) % ROUTES.size()]
				set_convoy(game, id, d["id"], 30)
		if f["dirty"] > 4000 and rng.randf() < 0.15:
			var d2: Dictionary = ROUTES[rng.randi_range(0, ROUTES.size() - 1)]
			if int(n["routes"][d2["id"]]["owner"]) != id:
				bribe_route(game, id, d2["id"])
		var enemy: int = game._ai_enemy(id)
		if enemy >= 0 and rng.randf() < 0.2:
			for d3 in ROUTES:
				if int(n["routes"][d3["id"]]["convoys"].get(str(enemy), 0)) > 0:
					set_ambush(game, id, d3["id"], 2)
					break
		if enemy >= 0 and f["dirty"] > 3000 and rng.randf() < 0.08:
			for c2 in CITIES:
				if c2["id"] != "nyc" and men_in(n, c2["id"], id) > 0 and men_in(n, c2["id"], enemy) > 0:
					order_hit(game, id, c2["id"], enemy)
					break
