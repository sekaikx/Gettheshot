extends Node
## Campaign state and rules (autoload "Game").
##
## The host owns the truth and runs every rule here. Clients receive a copy through
## Net (apply_state) and only ever *ask* the host to act (World sends requests; the host calls
## the act_* functions after checking distances in the world).
##
## Everything is plain Dictionaries / Arrays so a save file is just JSON and a network state
## packet is just var_to_bytes.

signal state_changed
signal month_passed(month: int)
signal notice(family: int, text: String, kind: String)   # family -1 = everyone
signal crew_spawn_request(crew_id: int)
signal ai_order(order: Dictionary)
signal campaign_over
signal raided(family: int)      # the feds hit a family: the World shows it on the street

const START_YEAR := 1923
const MONTHS := ["January", "February", "March", "April", "May", "June", "July", "August",
	"September", "October", "November", "December"]
const CRASH_MONTH := 81        # October 1929
const REPEAL_MONTH := 131      # December 1933

# economy (1920s dollars, per month)
const CRATE_COST := 40
const CRATE_PRICE := 115
const LAUNDER_FEE := 0.15
const SPEAKEASY_COST := 600
const COP_WAGE := 60
const CAPTAIN_WAGE := 350
const CAPTAIN_FEE := 500
const JAIL_SUPPORT := 50
const COLLECTOR_CUT := 0.1
const UNION_BOSS := "Red Mulrooney"      # the hiring boss on the West St. quay
const UNION_LOCAL := "915"

const SHOP_ECON := {
	# kind: [protection rate, value (clean $), legit profit, laundering capacity]
	"bakery": [90, 2200, 70, 450], "butcher": [110, 2600, 80, 500], "grocer": [100, 2400, 75, 500],
	"tailor": [120, 2800, 90, 550], "barber": [70, 1600, 50, 350], "cobbler": [60, 1400, 40, 300],
	"pawnshop": [140, 3200, 110, 800], "laundry": [100, 2600, 70, 900], "restaurant": [160, 4200, 140, 900],
	"cafe": [90, 2000, 60, 450], "candy": [60, 1300, 40, 300], "hardware": [100, 2500, 80, 500],
	"drugstore": [120, 3000, 100, 600], "cigar": [80, 1800, 60, 500], "fish": [110, 2400, 90, 500],
	"warehouse": [150, 1800, 90, 500], "poolhall": [130, 3000, 90, 600], "club": [0, 3500, 40, 400],
}

var cfg := {"seed": 1923, "families": 4, "month_seconds": 150.0, "start_month": 0,
	"end_month": REPEAL_MONTH, "name": "New York, 1923"}
var plan: CityPlan
var month := 0
var clock := 0.0            # 0..1 through the current month (one day-night per month)
var running := false
var over := false
var families: Array = []
var biz: Array = []
var crew: Array = []
var cops: Array = []
var recruits: Array = []
var players: Dictionary = {}   # "peer id" -> {name, family, wallet, crates, jailed_until, role}
var deals: Array = []
var relations: Dictionary = {}  # "a:b" (a < b) -> {truce_until, war, grudge_a, grudge_b}
var captains: Dictionary = {}   # district -> family id
var news: Array = []            # [{month, text}]
var boat := {"crates": 0, "month": -1}
var nation: Dictionary = {}     # Syndicate: cities, routes (see syndicate.gd)
var dealer := {"pistol": 60, "tommy": 250, "ammo": 15}
var econ := 1.0
var speak_mult := 1.0
var next_id := 1
var _month_log: Array = []
var _rng := RandomNumberGenerator.new()
var _dirty := false
var _time := 0.0               # host seconds since start, for jail timers


# ------------------------------------------------------------------ setup

## Host only: start a new campaign. `humans` is [{peer, name, family_name, color, join}] where
## join >= 0 puts the player into an existing family instead of founding one.
func new_campaign(config: Dictionary, humans: Array) -> void:
	cfg.merge(config, true)
	_rng.seed = int(cfg["seed"])
	plan = CityPlan.generate(int(cfg["seed"]))
	month = int(cfg["start_month"])
	clock = 0.18
	over = false
	families.clear(); biz.clear(); crew.clear(); cops.clear(); recruits.clear(); players.clear()
	deals.clear(); relations.clear(); captains.clear(); news.clear()
	econ = 1.0 if month < CRASH_MONTH else 0.75
	speak_mult = 1.0
	next_id = 1
	nation = Syndicate.fresh()
	boat = {"crates": 12, "month": month}
	_make_businesses()
	var count: int = clampi(maxi(int(cfg["families"]), _family_slots_needed(humans)), 1, 8)
	var hqs := biz.filter(func(b: Dictionary) -> bool: return b["kind"] == "club")
	_order_hqs(hqs)
	var human_families := []
	for h in humans:
		if int(h.get("join", -1)) < 0:
			human_families.append(h)
	for k in count:
		var human: Dictionary = human_families[k] if k < human_families.size() else {}
		var fname: String = human.get("family_name", Names.FAMILY_NAMES[k % Names.FAMILY_NAMES.size()])
		var color: String = human.get("color", Names.FAMILY_COLORS[k % Names.FAMILY_COLORS.size()])
		_add_family(fname, color, human.is_empty(), hqs[k % hqs.size()])
	var slot := 0
	for h in humans:
		var fam := int(h.get("join", -1))
		if fam < 0:
			fam = slot
			slot += 1
		add_player(int(h["peer"]), String(h["name"]), clampi(fam, 0, families.size() - 1))
	for f in families:
		_starting_turf(f)
	_make_cops()
	_refresh_recruits()
	for f in families:
		for n in 2:
			_add_crew(f["id"], "soldier" if n == 0 else "associate")
	_headline("A new decade on the Lower East Side: Prohibition turns every cellar into a gold mine.")
	running = true
	_dirty = true


## Every family starts with a few shops near its club already paying.
func _starting_turf(f: Dictionary) -> void:
	var hq := biz_by_id(int(f["hq"]))
	var door := Vector2(hq["door"][0], hq["door"][1])
	var cands := biz.filter(func(b: Dictionary) -> bool:
		return b["protector"] < 0 and b["kind"] not in ["club", "precinct", "poolhall", "warehouse"])
	cands.sort_custom(func(a, b) -> bool:
		return Vector2(a["door"][0], a["door"][1]).distance_to(door) < Vector2(b["door"][0], b["door"][1]).distance_to(door))
	for b in cands.slice(0, 3):
		b["protector"] = f["id"]
		b["fear"] = 30.0
		b["defiance"] = 20


func _family_slots_needed(humans: Array) -> int:
	return humans.filter(func(h: Dictionary) -> bool: return int(h.get("join", -1)) < 0).size()


func _order_hqs(hqs: Array) -> void:
	# spread families across districts: one club per district first
	var seen := {}
	var first := []
	var rest := []
	for h in hqs:
		if seen.has(h["district"]):
			rest.append(h)
		else:
			seen[h["district"]] = true
			first.append(h)
	var order := ["Little Italy", "Garment District", "Hell's Kitchen", "Lower East Side", "Waterfront"]
	first.sort_custom(func(a, b) -> bool: return order.find(a["district"]) < order.find(b["district"]))
	hqs.clear()
	hqs.append_array(first + rest)


func _make_businesses() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(cfg["seed"]) * 7 + 3
	for lot in plan.lots:
		var kind: String = lot["kind"]
		if not SHOP_ECON.has(kind) and kind != "precinct":
			continue
		var eth: String = Names.pick(rng, ["it", "it", "je", "ir", "je"])
		var owner := Names.person(rng, eth)
		var e: Array = SHOP_ECON.get(kind, [0, 0, 0, 0])
		var name := "14th Precinct" if kind == "precinct" else Names.shop(rng, kind, owner)
		if kind == "club":
			name = "%s Social Club" % Names.pick(rng, ["Ravenite", "Palma Boys", "Bergin", "Hester St.", "Mulberry", "Knights of"]).replace("Knights of", "Knights of Columbus")
		if kind == "warehouse":
			name = "%s %s" % [Names.pick(rng, ["Hudson", "North River", "Gansevoort", "Pier Nine", "Bowling Green", "Harborside"]),
				Names.pick(rng, ["Storage Co.", "Cold Storage", "Bonded Stores", "Freight & Storage"])]
			owner = "the %s Line" % Names.pick(rng, ["Hesperus", "Coastwise Mercantile", "Gull Island", "Pilot Rock", "Tidewater"])
		biz.append({"id": biz.size(), "lot": lot["id"], "name": name, "kind": kind,
			"address": plan.address_at(float(lot["door"][0]), float(lot["door"][1])),
			"district": lot["district"], "door": lot["door"], "yaw": lot["yaw"], "owner_name": owner,
			"protector": -1, "rate": int(e[0]), "owned_by": -1, "value": int(e[1]),
			"legit": int(e[2]), "launder": int(e[3]), "fear": rng.randi_range(0, 30),
			"defiance": rng.randi_range(10, 70), "envelope": 0, "speak": false, "stock": 0,
			"demand": 0, "closed_until": -1, "unpaid": 0, "hq_of": -1, "broken": [],
			"weak": Rackets.weak_for(biz.size(), int(cfg["seed"]))})


func _add_family(fname: String, color: String, ai: bool, hq: Dictionary) -> Dictionary:
	var f := {"id": families.size(), "name": fname, "color": color, "ai": ai, "hq": hq["id"],
		"dirty": 1200, "clean": 600, "heat": 0.0, "rep": 10, "fear": {}, "kept": 0, "broken": 0,
		"alive": true, "support_jailed": true, "launder_on": true, "income": {}, "score": 0,
		"arsenal": {"pistol": 1, "tommy": 0, "ammo": 12}, "evidence": [], "cellar": 0,
		"ethnic": "ir" if fname in ["O'Hara", "Doyle"] else ("je" if fname in ["Kaplan"] else "it")}
	hq["owned_by"] = f["id"]
	hq["protector"] = f["id"]
	hq["hq_of"] = f["id"]
	hq["rate"] = 0
	hq["name"] = "%s Social Club" % fname
	families.append(f)
	return f


func add_player(peer: int, pname: String, family: int) -> void:
	players[str(peer)] = {"name": pname, "family": family, "wallet": 300, "crates": 0,
		"jailed_until": 0.0, "role": "boss" if _family_has_no_boss(family) else "underboss"}
	families[family]["ai"] = false
	_dirty = true


func _family_has_no_boss(family: int) -> bool:
	for p in players.values():
		if int(p["family"]) == family and p["role"] == "boss":
			return false
	return true


func _make_cops() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(cfg["seed"]) + 99
	for d in CityPlan.DISTRICTS:
		for n in 2:
			cops.append({"id": cops.size(), "name": "Ptl. " + Names.person(rng, "ir").split(" ")[1],
				"district": d, "payroll": -1, "honesty": rng.randf_range(0.0, 1.0)})


func _refresh_recruits() -> void:
	# two men looking for work at every pool hall
	recruits.clear()
	for b in biz:
		if b["kind"] != "poolhall":
			continue
		for n in 2:
			var eth: String = Names.pick(_rng, ["it", "it", "ir", "je"])
			recruits.append({"id": next_id, "name": Names.hood(_rng, eth), "at": b["id"],
				"price": _rng.randi_range(150, 350), "wage": _rng.randi_range(80, 160),
				"tough": _rng.randi_range(40, 95), "look": _rng.randi(), "trait": Rackets.trait_for(next_id * 31 + int(cfg["seed"]))})
			next_id += 1


func _add_crew(family: int, rank: String, from_recruit: Dictionary = {}) -> Dictionary:
	var f: Dictionary = families[family]
	var c := {"id": next_id, "name": from_recruit.get("name", Names.hood(_rng, f["ethnic"])),
		"family": family, "rank": rank, "loyalty": _rng.randi_range(55, 80),
		"wage": int(from_recruit.get("wage", 120 if rank == "associate" else 200)),
		"tough": int(from_recruit.get("tough", _rng.randi_range(45, 85))),
		"task": "follow", "target": -1, "leader": _family_leader(family), "state": "free",
		"jail_until": -1, "look": int(from_recruit.get("look", _rng.randi())), "months": 0,
		"trait": String(from_recruit.get("trait", Rackets.trait_for(next_id * 31 + int(cfg["seed"]))))}
	if f["ai"]:
		c["task"] = "guard"
		c["target"] = f["hq"]
	next_id += 1
	crew.append(c)
	crew_spawn_request.emit(c["id"])
	return c


func _family_leader(family: int) -> String:
	for k in players:
		if int(players[k]["family"]) == family and players[k]["role"] == "boss":
			return k
	for k in players:
		if int(players[k]["family"]) == family:
			return k
	return ""


# ------------------------------------------------------------------ queries

func date_text(m: int = -1) -> String:
	var mm := month if m < 0 else m
	return "%s %d" % [MONTHS[mm % 12], START_YEAR + mm / 12]


func year() -> int:
	return START_YEAR + month / 12


func player(peer: int) -> Dictionary:
	return players.get(str(peer), {})


func fam(id: int) -> Dictionary:
	return families[id] if id >= 0 and id < families.size() else {}


func biz_by_id(id: int) -> Dictionary:
	return biz[id] if id >= 0 and id < biz.size() else {}


func crew_by_id(id: int) -> Dictionary:
	for c in crew:
		if c["id"] == id:
			return c
	return {}


func cop_by_id(id: int) -> Dictionary:
	return cops[id] if id >= 0 and id < cops.size() else {}


func crew_of(family: int, only_free: bool = true) -> Array:
	return crew.filter(func(c: Dictionary) -> bool:
		return c["family"] == family and (not only_free or c["state"] == "free"))


func shops_of(family: int) -> Array:
	return biz.filter(func(b: Dictionary) -> bool: return b["protector"] == family)


func owned_by(family: int) -> Array:
	return biz.filter(func(b: Dictionary) -> bool: return b["owned_by"] == family)


func fear_in(family: int, district: String) -> float:
	return float(fam(family).get("fear", {}).get(district, 0.0))


func rel(a: int, b: int) -> Dictionary:
	var key := "%d:%d" % [mini(a, b), maxi(a, b)]
	if not relations.has(key):
		relations[key] = {"truce_until": -1, "war": false, "grudge": {}}
	return relations[key]


func has_truce(a: int, b: int) -> bool:
	return a != b and int(rel(a, b)["truce_until"]) >= month


func strength(family: int) -> float:
	var s := 0.0
	for c in crew_of(family):
		s += 1.0 + c["tough"] / 100.0
	return s + fam(family).get("rep", 0) / 25.0


func laundering_capacity(family: int) -> int:
	var cap := 0
	for b in owned_by(family):
		if b["closed_until"] < month:
			cap += int(b["launder"])
	return cap


## Dirty cash the family keeps back from laundering: a month of wages and envelopes, plus a cushion.
func payroll_reserve(family: int) -> int:
	var r := 400
	for c in crew_of(family):
		r += int(c["wage"])
	for cop in cops:
		if cop["payroll"] == family:
			r += COP_WAGE
	for d in captains:
		if captains[d] == family:
			r += CAPTAIN_WAGE
	if not nation.is_empty():
		for c in Syndicate.CITIES:
			var cs: Dictionary = nation["cities"].get(c["id"], {})
			if cs.is_empty():
				continue
			r += int(cs["men"].get(str(family), 0)) * 90
			if int(cs["docks"]) == family:
				r += Syndicate.union_wage(c["id"])
	return r


func legacy(family: int) -> int:
	var f := fam(family)
	var v := float(f["clean"]) + float(f["dirty"]) * 0.5
	for b in owned_by(family):
		v += b["value"]
		if b["speak"]:
			v += 800
	v += shops_of(family).size() * 300.0
	v += f["rep"] * 15.0 - f["heat"] * 25.0
	if not nation.is_empty():
		for c in nation["cities"]:
			v += float(nation["cities"][c]["influence"].get(str(family), 0.0)) * 60.0
		for r in nation["routes"]:
			if int(nation["routes"][r]["owner"]) == family:
				v += 1500.0
		for c in Syndicate.CITIES:
			var cs: Dictionary = nation["cities"].get(c["id"], {})
			if cs.is_empty():
				continue
			if cs["wh"].has(str(family)):
				v += (Syndicate.warehouse_price(c["id"]) * 0.6 if c["id"] != "nyc" else 0.0) + int(cs["wh"][str(family)]) * 20.0
			if int(cs["plant"]) == family:
				v += Syndicate.plant_price(c["id"]) * 0.6
			if int(cs["docks"]) == family:
				v += 1000.0
			if int(cs["yard"]) == family:
				v += 500.0
	for p in players.values():
		if int(p["family"]) == family:
			v += float(p["wallet"]) * 0.5
	return int(v)


func arrest_price(family: int) -> int:
	return 150 + int(fam(family).get("heat", 0.0) * 5.0)


# ------------------------------------------------------------------ time

func _process(delta: float) -> void:
	if not running or over or not Net.is_host():
		return
	_time += delta
	clock += delta / float(cfg["month_seconds"])
	if clock >= 1.0:
		clock -= 1.0
		_advance_month()
	# jailed players come back
	for k in players:
		var p: Dictionary = players[k]
		if float(p["jailed_until"]) > 0.0 and _time >= float(p["jailed_until"]):
			p["jailed_until"] = 0.0
			_dirty = true
			notice.emit(int(p["family"]), "%s is out on bail." % p["name"], "good")


func host_time() -> float:
	return _time


func consume_dirty() -> bool:
	var d := _dirty
	_dirty = false
	return d


func mark_dirty() -> void:
	_dirty = true


func _advance_month() -> void:
	month += 1
	_month_log.clear()
	boat = {"crates": _rng.randi_range(10, 16), "month": month}
	if month == CRASH_MONTH:
		econ = 0.7
		for b in biz:
			b["value"] = int(b["value"] * 0.6)
		_headline("WALL STREET LAYS AN EGG: stocks crash, shops across the city can't make rent.", true)
	if month == CRASH_MONTH + 30:
		econ = 0.85
	if month == REPEAL_MONTH:
		speak_mult = 0.15
		_headline("PROHIBITION ENDS! Beer is legal again. Bootleggers ruined overnight.", true)
	for f in families:
		f["income"] = {"protection": 0, "speakeasy": 0, "legit": 0, "laundered": 0, "wages": 0,
			"payroll": 0, "support": 0, "wholesale": 0, "convoys": 0, "supply": 0}
	_tick_businesses()
	_tick_families()
	_tick_crew()
	Syndicate.tick(self)
	_tick_booze()
	_tick_evidence()
	for f in families:
		if f["ai"] and f["alive"]:
			_ai_month(f)
	if month % 6 == 0:
		_refresh_recruits()
	# deals expire after one month unanswered
	deals = deals.filter(func(d: Dictionary) -> bool: return int(d["expires"]) >= month)
	for f in families:
		f["score"] = legacy(f["id"])
	if not _month_log.is_empty():
		for t in _month_log.slice(0, 4):
			_headline(t)
	elif _rng.randf() < 0.6:
		var filler: String = Names.pick(_rng, ["Reformer promises to 'clean up the ward' at Tammany rally.",
			"Dry agents smash 40 barrels in a Brooklyn cellar.", "Longshoremen threaten strike on West St.",
			"Babe Ruth hits two at the Polo Grounds.", "Fire on Orchard St. — tenants blame the landlord.",
			"Police commissioner: 'There is no Mafia in New York.'", "Coast Guard cutter fires on a rum boat off Montauk.",
			"Mayor Walker opens a new casino in Central Park. The Tammany boys cheer.", "Speakeasies outnumber churches, says the Anti-Saloon League.",
			"A Ziegfeld girl marries a bootlegger. Society gasps.", "Chicago: seven men shot in a garage on North Clark Street."])
		if news.slice(0, 8).all(func(n: Dictionary) -> bool: return n["text"] != filler):
			_headline(filler)
	month_passed.emit(month)
	if month >= int(cfg["end_month"]) and not over:
		over = true
		campaign_over.emit()
	_dirty = true


func _tick_businesses() -> void:
	for b in biz:
		if b["kind"] == "precinct":
			continue
		var closed: bool = b["closed_until"] >= month
		var p: int = b["protector"]
		if p >= 0 and b["owned_by"] != p and not closed:
			var pay := int(b["rate"] * econ)
			if b["fear"] < 15 and b["defiance"] > 75 and _rng.randf() < 0.3:
				# he stops paying; somebody has to go and have a word
				b["unpaid"] += 1
				_notice(p, "%s didn't pay this month." % b["name"], "warn")
			else:
				var f: Dictionary = families[p]
				var collector := _collector_in(p, b["district"])
				if collector.is_empty() and not f["ai"]:
					b["envelope"] = mini(b["envelope"] + pay, pay * 3)
				else:
					var cut := 0.0 if String(collector.get("trait", "")) == "earner" else COLLECTOR_CUT
					var net := int(pay * (1.0 - cut))
					f["dirty"] += net
					f["income"]["protection"] += net
		if b["owned_by"] >= 0 and not closed:
			var f: Dictionary = families[b["owned_by"]]
			var legit := int(b["legit"] * econ)
			f["clean"] += legit
			f["income"]["legit"] += legit
			if b["speak"] and b["stock"] > 0:
				var food := 1.25 if Rackets.has_ring(int(b["owned_by"]), "food") else 1.0
				var sold := mini(b["stock"], int(round(b["demand"] * speak_mult * food)))
				b["stock"] -= sold
				var cash := int(sold * CRATE_PRICE * (0.6 + 0.4 * econ))
				f["dirty"] += cash
				f["income"]["speakeasy"] += cash
		# the numbers game in the back of the cigar and candy stores
		if p >= 0 and not closed and b["kind"] in ["cigar", "candy"] and Rackets.has_ring(p, "numbers"):
			families[p]["dirty"] += 60
			families[p]["income"]["protection"] += 60
		b["fear"] = maxf(0.0, b["fear"] - 3.0)


func _collector_in(family: int, district: String) -> Dictionary:
	for c in crew:
		if c["family"] == family and c["state"] == "free" and c["task"] == "collect":
			var target := biz_by_id(int(c["target"]))
			if target.is_empty() or target["district"] == district:
				return c
	return {}


func _tick_families() -> void:
	for f in families:
		if not f["alive"]:
			continue
		# laundering through fronts; the accountant keeps back enough cash for this month's payroll
		if f["launder_on"]:
			var keep := payroll_reserve(f["id"]) + (1200 if f["ai"] else 0)   # AI families keep working capital for convoys
			var amt := clampi(int(f["dirty"]) - keep, 0, laundering_capacity(f["id"]))
			if amt > 0:
				f["dirty"] -= amt
				f["clean"] += int(amt * (1.0 - (0.05 if Rackets.has_ring(f["id"], "laundry") else LAUNDER_FEE)))
				f["income"]["laundered"] += amt
		# wages (the family eats free if it runs the restaurants)
		var wage_mult := 0.8 if Rackets.has_ring(f["id"], "eats") else 1.0
		for c in crew_of(f["id"]):
			var wage := int(c["wage"] * wage_mult)
			if f["dirty"] >= wage:
				f["dirty"] -= wage
				f["income"]["wages"] += wage
				c["loyalty"] = mini(100, c["loyalty"] + 1)
			else:
				c["loyalty"] -= 12
				_notice(f["id"], "%s wasn't paid this month." % c["name"], "warn")
		# jailed men's families
		for c in crew.filter(func(x: Dictionary) -> bool: return x["family"] == f["id"] and x["state"] == "jailed"):
			if f["support_jailed"] and f["dirty"] >= JAIL_SUPPORT:
				f["dirty"] -= JAIL_SUPPORT
				f["income"]["support"] += JAIL_SUPPORT
			else:
				c["loyalty"] -= 15
		# cops on the payroll
		for cop in cops:
			if cop["payroll"] == f["id"]:
				if f["dirty"] >= COP_WAGE:
					f["dirty"] -= COP_WAGE
					f["income"]["payroll"] += COP_WAGE
				else:
					cop["payroll"] = -1
					_notice(f["id"], "%s is off the payroll: you couldn't pay him." % cop["name"], "warn")
		for d in captains.keys():
			if captains[d] == f["id"]:
				if f["dirty"] >= CAPTAIN_WAGE:
					f["dirty"] -= CAPTAIN_WAGE
					f["income"]["payroll"] += CAPTAIN_WAGE
				else:
					captains.erase(d)
		# heat cools, fear fades
		# cellar stock flows into speakeasies
		if int(f.get("cellar", 0)) > 0:
			for b in owned_by(f["id"]):
				if b["speak"] and f["cellar"] > 0:
					var mv := mini(int(f["cellar"]), maxi(0, 30 - int(b["stock"])))
					b["stock"] += mv
					f["cellar"] -= mv
		var fear: Dictionary = f["fear"]
		for d in fear.keys():
			fear[d] = maxf(0.0, fear[d] - 4.0)
		if f["heat"] >= 100.0:
			_federal_raid(f)
		elif f["heat"] >= 70.0:
			_notice(f["id"], "Your heat is high: the Bureau is building a case. Lie low, or make the evidence go away (Tab, Heat).", "bad")


## The family's warehouse on the West St. quay (a business it bought), or {}.
func nyc_warehouse(family: int) -> Dictionary:
	for b in biz:
		if b["kind"] == "warehouse" and int(b["owned_by"]) == family:
			return b
	return {}


## Men on the booze run truck crates from the quay warehouse to the family's speakeasies.
func _tick_booze() -> void:
	for c in crew:
		if c["state"] != "free" or c["task"] != "booze":
			continue
		var fid: int = c["family"]
		var f := fam(fid)
		var have := Syndicate.stock(nation, "nyc", fid)
		var speaks := owned_by(fid).filter(func(b: Dictionary) -> bool: return b["speak"] and int(b["closed_until"]) < month)
		if speaks.is_empty() or have <= 0 or not Syndicate.has_wh(nation, "nyc", fid):
			Syndicate._report(nation, fid, "Booze run: %s sat in the truck (%s)" % [c["name"], "no speakeasies" if speaks.is_empty() else "the warehouse is empty"])
			continue
		var room := 0
		for b in speaks:
			room += maxi(0, Syndicate.SPEAK_CAP - int(b["stock"]))
		var n := mini(mini(int(c.get("booze", 20)), have), room)
		if n <= 0:
			continue
		Syndicate.take_stock(nation, "nyc", fid, n)
		var risk := 0.06 + float(f["heat"]) / 300.0
		if String(c.get("trait", "")) == "driver":
			risk *= 0.5
		if captains.get("Waterfront", -1) == fid:
			risk *= 0.5
		var paid := cops.filter(func(k: Dictionary) -> bool: return k["payroll"] == fid).size()
		risk *= maxf(0.4, 1.0 - paid * 0.12)
		var b0: Dictionary = speaks[_rng.randi_range(0, speaks.size() - 1)]
		var street := plan.street_name_at(float(b0["door"][0]), float(b0["door"][1]))
		if _rng.randf() < risk:
			add_evidence(fid, "cop", "A patrolman stopped a loaded %s family truck on %s" % [f["name"], street], 6.0)
			_notice(fid, "Dry agents stopped your booze run on %s: %d crates seized." % [street, n], "bad")
			Syndicate._report(nation, fid, "Booze run stopped on %s: %d crates seized" % [street, n])
			if _rng.randf() < 0.25:
				_jail_crew(c, _rng.randi_range(2, 5))
			continue
		var left := n
		for b in speaks:
			var mv := mini(left, maxi(0, Syndicate.SPEAK_CAP - int(b["stock"])))
			b["stock"] = int(b["stock"]) + mv
			left -= mv
		Syndicate._report(nation, fid, "Booze run: %s trucked %d crates from the quay to %s" % [c["name"], n,
			speaks[0]["name"] if speaks.size() == 1 else "%d speakeasies" % speaks.size()])


func _federal_raid(f: Dictionary) -> void:
	var lost := int(f["dirty"] * 0.5)
	f["dirty"] -= lost
	var seized := 0
	for b in owned_by(f["id"]):
		if b["speak"]:
			seized += b["stock"]
			b["stock"] = 0
			b["closed_until"] = month + 1
	# the warehouse on the quay gets turned over too
	seized += Syndicate.take_stock(nation, "nyc", f["id"], Syndicate.stock(nation, "nyc", f["id"]) * 2 / 3)
	var men := crew_of(f["id"])
	if not men.is_empty():
		var c: Dictionary = men[_rng.randi_range(0, men.size() - 1)]
		_jail_crew(c, 6)
	# the raid uses up what the feds had: they keep a smaller file
	for e in f["evidence"]:
		e["w"] = float(e["w"]) * 0.45
	_recalc_heat(f)
	f["rep"] = maxi(0, f["rep"] - 5)
	_log("FEDS RAID %s FAMILY: $%d cash and %d crates seized." % [f["name"].to_upper(), lost, seized])
	_notice(f["id"], "Federal raid! They took $%d from your Stash and %d crates." % [lost, seized], "bad")
	raided.emit(int(f["id"]))


func _tick_crew() -> void:
	for c in crew:
		if c["state"] == "jailed":
			if month >= int(c["jail_until"]):
				c["state"] = "free"
				_notice(c["family"], "%s is out of prison." % c["name"], "good")
				crew_spawn_request.emit(c["id"])
			else:
				var flip := 0.03 + maxf(0.0, 70.0 - c["loyalty"]) * 0.006
				if _rng.randf() < flip:
					c["state"] = "rat"
					var f: Dictionary = families[c["family"]]
					add_evidence(f["id"], "informant", "%s is talking to the District Attorney" % c["name"], 35.0, {"crew": c["id"]})
					_log("%s TURNS STATE'S EVIDENCE against the %s family." % [c["name"].to_upper(), f["name"]])
					_notice(c["family"], "%s flipped. He's talking to the DA." % c["name"], "bad")
		elif c["state"] == "free":
			c["months"] += 1
			if c["loyalty"] < 20 and _rng.randf() < 0.25:
				c["state"] = "gone"
				_notice(c["family"], "%s walked out on the family." % c["name"], "bad")


func _jail_crew(c: Dictionary, months: int) -> void:
	c["state"] = "jailed"
	c["jail_until"] = month + months
	_notice(c["family"], "%s was arrested: %d months." % [c["name"], months], "bad")


# ------------------------------------------------------------------ crimes and the law

## A crime happened in the world. `civ` witnesses add evidence; a cop who saw it and is not
## bought chases (World handles the chase). Returns the heat added.
func report_crime(family: int, severity: float, civ: int, cop_saw: bool, district: String,
		what: String = "crime", witness_biz: int = -1, cop_id: int = -1, who: String = "") -> float:
	var f := fam(family)
	if f.is_empty():
		return 0.0
	var mult := 0.4 if captains.get(district, -1) == family else 1.0
	var h := 0.0
	var by := (" by %s" % who) if who != "" else ""
	if civ > 0:
		var w := severity * (0.25 + minf(civ, 6) * 0.2) * mult
		h += w
		var wb := biz_by_id(witness_biz)
		if not wb.is_empty():
			add_evidence(family, "witness", "%s (%s) saw the %s%s" % [wb["owner_name"], wb["name"], what, by], w * 0.7, {"biz": witness_biz})
			if civ > 1:
				add_evidence(family, "street", "%d people on the street saw the %s in %s" % [civ - 1, what, district], w * 0.3)
		else:
			add_evidence(family, "street", "%d people saw the %s in %s%s" % [civ, what, district, by], w)
	else:
		add_evidence(family, "street", "Talk in %s about a %s" % [district, what], severity * 0.15 * mult)
		h += severity * 0.15 * mult
	if cop_saw:
		var c := cop_by_id(cop_id)
		var cw := severity * 0.8 * mult
		h += cw
		add_evidence(family, "cop", "%s saw the %s%s and wrote it up" % [c.get("name", "A patrolman"), what, by], cw, {"cop": cop_id})
	var fear: Dictionary = f["fear"]
	fear[district] = minf(100.0, float(fear.get(district, 0.0)) + severity * 0.6)
	_dirty = true
	return h


func cop_ignores(cop_id: int, family: int) -> bool:
	var c := cop_by_id(cop_id)
	if c.is_empty():
		return true
	return c["payroll"] == family or captains.get(c["district"], -1) == family


func jail_player(peer: int, seconds: float) -> void:
	var p := player(peer)
	if p.is_empty():
		return
	p["jailed_until"] = _time + seconds
	p["wallet"] = 0
	p["crates"] = 0
	var f := fam(int(p["family"]))
	# the time served clears the street talk about him
	for e in f["evidence"]:
		if e["kind"] == "street":
			e["w"] = float(e["w"]) * 0.5
	_recalc_heat(f)
	f["rep"] = maxi(0, f["rep"] - 3)
	_log("%s of the %s family pinched by the 14th Precinct." % [p["name"].to_upper(), f["name"]])
	_dirty = true


func crew_arrested(crew_id: int) -> void:
	var c := crew_by_id(crew_id)
	if not c.is_empty() and c["state"] == "free":
		_jail_crew(c, _rng.randi_range(3, 8))
		_dirty = true


func crew_killed(crew_id: int, by_family: int, street: String = "") -> void:
	var c := crew_by_id(crew_id)
	if c.is_empty() or c["state"] != "free":
		return
	c["state"] = "dead"
	var victim: int = c["family"]
	if street != "":
		_log("GANGLAND KILLING ON %s: %s found dead on the sidewalk." % [street.to_upper(), c["name"]])
	else:
		_log("GANGLAND KILLING: %s found dead on the sidewalk." % c["name"])
	_notice(victim, "%s was killed." % c["name"], "bad")
	if by_family >= 0 and by_family != victim:
		aggression(by_family, victim, 30)
	_dirty = true


## Someone from family `a` hurt family `b`. Breaks truces, starts wars, AI remembers.
func aggression(a: int, b: int, weight: int) -> void:
	if a < 0 or b < 0 or a == b:
		return
	var r := rel(a, b)
	if int(r["truce_until"]) >= month:
		r["truce_until"] = -1
		families[a]["broken"] += 1
		families[a]["rep"] = maxi(0, families[a]["rep"] - 8)
		_log("THE %s FAMILY BREAKS ITS WORD with the %s family." % [families[a]["name"].to_upper(), families[b]["name"]])
		_notice(b, "The %s family broke the truce!" % families[a]["name"], "bad")
	var g: Dictionary = r["grudge"]
	g[str(b)] = int(g.get(str(b), 0)) + weight   # b holds a grudge
	if int(g[str(b)]) >= 30:
		r["war"] = true
	_dirty = true


# ------------------------------------------------------------------ player actions (host)
# World checks the player is standing in the right place, then calls these. Each returns
# {"ok": bool, "msg": String}.

func act_pitch(family: int, biz_id: int, muscle: int) -> Dictionary:
	var b := biz_by_id(biz_id)
	var f := fam(family)
	if b.is_empty() or f.is_empty():
		return _r(false, "")
	if b["protector"] == family:
		return _r(false, "%s already pays you." % b["owner_name"])
	if b["owned_by"] >= 0:
		return _r(false, "This place belongs to the %s family." % families[b["owned_by"]]["name"])
	var chance: float = 0.3 + fear_in(family, b["district"]) * 0.004 + b["fear"] * 0.006 + muscle * 0.1 \
		+ f["rep"] * 0.004 - b["defiance"] * 0.004
	var prev: int = b["protector"]
	if prev >= 0:
		chance -= 0.1 + strength(prev) * 0.03
	chance = clampf(chance, 0.05, 0.95)
	if _rng.randf() < chance:
		b["protector"] = family
		b["defiance"] = maxi(0, b["defiance"] - 15)
		b["unpaid"] = 0
		b["envelope"] = 0
		f["rep"] += 1
		if prev >= 0:
			aggression(family, prev, 12)
			_notice(prev, "%s now pays the %s family." % [b["name"], f["name"]], "bad")
			_log("%s switches sides: now pays the %s family." % [b["name"], f["name"]])
		_dirty = true
		return _r(true, "%s agrees to pay $%d a month." % [b["owner_name"], b["rate"]])
	b["defiance"] = mini(100, b["defiance"] + 8)
	_dirty = true
	return _r(false, Names.pick(_rng, ["\"I don't need your kind of protection.\"",
		"\"I already pay somebody. Get out of my shop.\"", "\"You think I'm scared of you?\"",
		"\"Come back when you've got real friends.\""]))


func act_lean(family: int, biz_id: int) -> Dictionary:
	var b := biz_by_id(biz_id)
	if b.is_empty():
		return _r(false, "")
	b["fear"] = minf(100.0, b["fear"] + 40.0)
	b["defiance"] = maxi(0, b["defiance"] - 25)
	if b["protector"] >= 0 and b["protector"] != family:
		aggression(family, b["protector"], 10)
	_dirty = true
	return _r(true, "You smash the window. %s is shaking." % b["owner_name"])


func act_collect(peer: int, biz_id: int) -> Dictionary:
	var p := player(peer)
	var b := biz_by_id(biz_id)
	if p.is_empty() or b.is_empty():
		return _r(false, "")
	var family := int(p["family"])
	if b["protector"] != family:
		if b["envelope"] > 0 and b["protector"] >= 0:
			# muscling in on another family's money
			var amt: int = b["envelope"]
			b["envelope"] = 0
			p["wallet"] += amt
			aggression(family, b["protector"], 15)
			_dirty = true
			return _r(true, "You take the %s family's envelope: $%d." % [families[b["protector"]]["name"], amt])
		return _r(false, "Nothing for you here.")
	if b["unpaid"] > 0:
		if b["fear"] >= 25 or _rng.randf() < 0.5:
			b["unpaid"] = 0
			var owed := int(b["rate"] * econ)
			p["wallet"] += owed
			_dirty = true
			return _r(true, "He pays what he owes: $%d." % owed)
		return _r(false, "\"I told you, I can't pay.\" He needs convincing.")
	if b["envelope"] <= 0:
		return _r(false, "Nothing to collect yet. Come back next month.")
	var amt2: int = b["envelope"]
	b["envelope"] = 0
	p["wallet"] += amt2
	_dirty = true
	return _r(true, "Collected $%d." % amt2)


func act_buy(family: int, biz_id: int) -> Dictionary:
	var b := biz_by_id(biz_id)
	var f := fam(family)
	if b.is_empty() or f.is_empty():
		return _r(false, "")
	if b["owned_by"] >= 0:
		return _r(false, "Not for sale.")
	var price := int(b["value"] * (1.0 if b["protector"] == family else 1.25))
	if f["clean"] < price:
		return _r(false, "You need $%d in the Bank. Pay with Stash money and the Treasury comes asking where it came from." % price)
	f["clean"] -= price
	var prev: int = b["protector"]
	b["owned_by"] = family
	b["protector"] = family
	b["rate"] = 0
	if prev >= 0 and prev != family:
		aggression(family, prev, 8)
	_log("The %s family quietly buys %s." % [f["name"], b["name"]])
	_dirty = true
	if b["kind"] == "warehouse":
		var nyc: Dictionary = nation["cities"]["nyc"]
		if not nyc["wh"].has(str(family)):
			nyc["wh"][str(family)] = 0
		return _r(true, "%s is your warehouse now. Boats and convoys landing in New York fill it: load the truck here, or put a man on the booze run." % b["name"])
	return _r(true, "You own %s. Every month it turns $%d of your Stash into Bank money." % [b["name"], b["launder"]])


func act_open_speakeasy(peer: int, biz_id: int) -> Dictionary:
	var p := player(peer)
	var b := biz_by_id(biz_id)
	if p.is_empty() or b.is_empty() or b["owned_by"] != int(p["family"]):
		return _r(false, "You have to own the place first.")
	if b["speak"]:
		return _r(false, "It's already a speakeasy.")
	var f := fam(int(p["family"]))
	var pay := _pay_dirty(p, f, SPEAKEASY_COST)
	if not pay:
		return _r(false, "A speakeasy costs $%d cash." % SPEAKEASY_COST)
	b["speak"] = true
	b["demand"] = {"Little Italy": 16, "Lower East Side": 20, "Garment District": 22,
		"Hell's Kitchen": 18, "Waterfront": 14}.get(b["district"], 16)
	_dirty = true
	return _r(true, "The speakeasy in the back of %s is open. Now bring it booze." % b["name"])


## Pay from the wallet first, then from the stash (the family's accountant handles it).
func _pay_dirty(p: Dictionary, f: Dictionary, amount: int) -> bool:
	if p["wallet"] >= amount:
		p["wallet"] -= amount
		return true
	if p["wallet"] + f["dirty"] >= amount:
		f["dirty"] -= amount - p["wallet"]
		p["wallet"] = 0
		return true
	return false


func act_hire(peer: int, recruit_id: int) -> Dictionary:
	var p := player(peer)
	if p.is_empty():
		return _r(false, "")
	for r in recruits:
		if r["id"] == recruit_id:
			if p["wallet"] < r["price"]:
				return _r(false, "He wants $%d up front." % r["price"])
			p["wallet"] -= r["price"]
			recruits.erase(r)
			var c := _add_crew(int(p["family"]), "associate", r)
			c["leader"] = str(peer)
			_dirty = true
			return _r(true, "%s is with you now. $%d a month." % [c["name"], c["wage"]])
	return _r(false, "He's gone.")


func act_payroll_cop(peer: int, cop_id: int) -> Dictionary:
	var p := player(peer)
	var c := cop_by_id(cop_id)
	if p.is_empty() or c.is_empty():
		return _r(false, "")
	var family := int(p["family"])
	if c["payroll"] == family:
		return _r(false, "He's already yours.")
	if p["wallet"] < 100:
		return _r(false, "You need $100 in your wallet.")
	p["wallet"] -= 100
	if c["honesty"] > 0.85:
		add_evidence(family, "cop", "%s reported a bribe attempt" % c["name"], 12.0, {"cop": cop_id})
		_dirty = true
		return _r(false, "\"Are you trying to bribe an officer?\" He takes your name. That's heat.")
	c["payroll"] = family
	# a bought cop loses his notebook
	var fe: Dictionary = fam(family)
	fe["evidence"] = fe["evidence"].filter(func(e: Dictionary) -> bool: return int(e.get("cop", -1)) != cop_id)
	_recalc_heat(fe)
	c["honesty"] = maxf(0.0, c["honesty"] - 0.2)
	_dirty = true
	return _r(true, "%s pockets the money. He'll look the other way: $%d a month." % [c["name"], COP_WAGE])


func act_captain(peer: int, district: String) -> Dictionary:
	var p := player(peer)
	if p.is_empty():
		return _r(false, "")
	var family := int(p["family"])
	var f := fam(family)
	if captains.get(district, -1) == family:
		return _r(false, "The captain already takes your money for %s." % district)
	var price := CAPTAIN_FEE + (400 if captains.has(district) else 0)
	if not _pay_dirty(p, f, price):
		return _r(false, "The captain wants $%d to start, $%d a month after." % [price, CAPTAIN_WAGE])
	var prev: int = captains.get(district, -1)
	captains[district] = family
	if prev >= 0:
		_notice(prev, "The precinct captain for %s took a better offer." % district, "bad")
	_dirty = true
	return _r(true, "The captain for %s is yours. His cops look the other way." % district)


func act_buy_crates(peer: int, n: int) -> Dictionary:
	var p := player(peer)
	if p.is_empty():
		return _r(false, "")
	n = mini(n, boat["crates"])
	if n <= 0:
		return _r(false, "The boat's empty. The next one comes next month, at night.")
	var cost := n * CRATE_COST
	if p["wallet"] < cost:
		n = int(p["wallet"]) / CRATE_COST
		cost = n * CRATE_COST
		if n <= 0:
			return _r(false, "Cash only: $%d a crate." % CRATE_COST)
	p["wallet"] -= cost
	boat["crates"] -= n
	_dirty = true
	return _r(true, "%d crates of Canadian whisky, $%d. Get them off the pier before the harbour patrol." % [n, cost])


func act_deliver(peer: int, biz_id: int, n: int) -> Dictionary:
	var p := player(peer)
	var b := biz_by_id(biz_id)
	if p.is_empty() or b.is_empty() or not b["speak"] or b["owned_by"] != int(p["family"]):
		return _r(false, "")
	b["stock"] += n
	_dirty = true
	return _r(true, "%d crates into the cellar of %s (%d in stock)." % [n, b["name"], b["stock"]])


func act_bank(peer: int, deposit: bool) -> Dictionary:
	var p := player(peer)
	if p.is_empty():
		return _r(false, "")
	var f := fam(int(p["family"]))
	if deposit:
		var amt: int = p["wallet"]
		f["dirty"] += amt
		p["wallet"] = 0
		_dirty = true
		return _r(true, "$%d into the safe." % amt)
	var take := mini(500, int(f["dirty"]))
	f["dirty"] -= take
	p["wallet"] += take
	_dirty = true
	return _r(true, "You take $%d from the safe." % take)


func act_bribe(peer: int) -> Dictionary:
	var p := player(peer)
	if p.is_empty():
		return _r(false, "")
	var family := int(p["family"])
	var price := arrest_price(family)
	if p["wallet"] < price:
		return _r(false, "You don't have $%d on you." % price)
	p["wallet"] -= price
	add_evidence(family, "cop", "A patrolman took money from your people", 4.0)
	_dirty = true
	return _r(true, "The cop counts the money and walks away.")


func act_crew_task(peer: int, crew_id: int, task: String, target: int) -> Dictionary:
	var p := player(peer)
	var c := crew_by_id(crew_id)
	if p.is_empty() or c.is_empty() or c["family"] != int(p["family"]) or c["state"] != "free":
		return _r(false, "")
	if task == "booze":
		var wh := nyc_warehouse(int(p["family"]))
		if wh.is_empty():
			return _r(false, "First you need a warehouse on the West St. quay.")
		c["booze"] = clampi(target if target > 0 else 20, 5, 60)
		target = wh["id"]
	c["task"] = task
	c["target"] = target
	c["leader"] = str(peer)
	_dirty = true
	if task == "booze":
		return _r(true, "%s takes the truck keys: %d crates a month from the warehouse to your speakeasies." % [c["name"], int(c["booze"])])
	var what: String = {"follow": "is with you", "guard": "is guarding", "collect": "is collecting in",
		"idle": "is taking it easy at the club"}.get(task, task)
	var where := ""
	if task == "guard" or task == "collect":
		var b := biz_by_id(target)
		where = " " + (b["district"] if task == "collect" else b["name"]) if not b.is_empty() else ""
	return _r(true, "%s %s%s." % [c["name"], what, where])


func act_toggle(peer: int, key: String) -> Dictionary:
	var p := player(peer)
	if p.is_empty():
		return _r(false, "")
	var f := fam(int(p["family"]))
	f[key] = not f[key]
	_dirty = true
	return _r(true, "")


# ------------------------------------------------------------------ evidence

## Something the Bureau could use: a witness, a cop's notebook, the gun, the books, a body, a
## man talking to the DA. Heat is the weight of everything in the file.
func add_evidence(family: int, kind: String, text: String, weight: float, extra: Dictionary = {}) -> void:
	var f := fam(family)
	if f.is_empty() or weight <= 0.05:
		return
	var e := {"id": next_id, "kind": kind, "text": text, "w": snappedf(weight, 0.1), "month": month}
	e.merge(extra)
	next_id += 1
	# the same witness or the same gun just gets heavier
	for o in f["evidence"]:
		if o["kind"] == kind and kind in ["weapon", "street", "witness", "cop", "file"] and o["text"] == text:
			o["w"] = float(o["w"]) + weight
			_recalc_heat(f)
			return
	f["evidence"].append(e)
	_recalc_heat(f)
	_dirty = true


func _recalc_heat(f: Dictionary) -> void:
	var h := 0.0
	for e in f["evidence"]:
		h += float(e["w"])
	f["heat"] = minf(150.0, h)


func _tick_evidence() -> void:
	# memories fade, some files go cold; bodies and informants don't
	var fade := {"street": 0.75, "witness": 0.88, "cop": 0.9, "weapon": 0.97, "ledger": 0.95, "body": 0.99,
		"informant": 1.0, "file": 0.85}
	for f in families:
		var meat := Rackets.has_ring(f["id"], "meat")
		for e in f["evidence"]:
			e["w"] = float(e["w"]) * float(fade.get(e["kind"], 0.9))
			if meat and e["kind"] == "body":
				e["w"] = float(e["w"]) * 0.7
			if captains.values().has(f["id"]) and e["kind"] in ["street", "cop"]:
				e["w"] = float(e["w"]) * 0.85
		f["evidence"] = f["evidence"].filter(func(e: Dictionary) -> bool: return float(e["w"]) >= 0.8)
		_recalc_heat(f)


func evidence_by_id(family: int, ev_id: int) -> Dictionary:
	for e in fam(family).get("evidence", []):
		if e["id"] == ev_id:
			return e
	return {}


func _drop_evidence(family: int, ev_id: int) -> void:
	var f := fam(family)
	f["evidence"] = f["evidence"].filter(func(e: Dictionary) -> bool: return e["id"] != ev_id)
	_recalc_heat(f)
	_dirty = true


## Pay a witness to forget, or remind him what happens to people who talk.
func act_silence(peer: int, ev_id: int, threaten: bool) -> Dictionary:
	var p := player(peer)
	var family := int(p.get("family", -1))
	var e := evidence_by_id(family, ev_id)
	if e.is_empty():
		return _r(false, "")
	var b := biz_by_id(int(e.get("biz", -1)))
	if threaten:
		if not b.is_empty():
			b["fear"] = minf(100.0, b["fear"] + 30.0)
		if _rng.randf() < 0.75:
			_drop_evidence(family, ev_id)
			return _r(true, "\"I didn't see nothing. I swear on my mother.\"")
		e["w"] = float(e["w"]) * 1.4
		_recalc_heat(fam(family))
		return _r(false, "He goes straight to the precinct. That made it worse.")
	var price := 100 + int(float(e["w"]) * 12.0)
	if p["wallet"] < price:
		return _r(false, "He wants $%d to have a bad memory." % price)
	p["wallet"] -= price
	_drop_evidence(family, ev_id)
	return _r(true, "$%d, and he never saw a thing." % price)


func act_dump_gun(peer: int) -> Dictionary:
	var p := player(peer)
	var family := int(p.get("family", -1))
	var f := fam(family)
	var guns := (f["evidence"] as Array).filter(func(e: Dictionary) -> bool: return e["kind"] == "weapon")
	if guns.is_empty():
		return _r(false, "Nothing to get rid of.")
	for e in guns:
		_drop_evidence(family, e["id"])
	var ars: Dictionary = f["arsenal"]
	ars["pistol"] = maxi(0, int(ars["pistol"]) - 1)
	return _r(true, "The gun goes into the East River. No gun, no case. You'll need a new piece.")


func act_burn_books(peer: int) -> Dictionary:
	var p := player(peer)
	var family := int(p.get("family", -1))
	var f := fam(family)
	var books := (f["evidence"] as Array).filter(func(e: Dictionary) -> bool: return e["kind"] == "ledger")
	if books.is_empty():
		return _r(false, "The books are clean. Your accountant is proud.")
	if f["clean"] < 300:
		return _r(false, "Clean books cost $300 from the Bank.")
	f["clean"] -= 300
	for e in books:
		_drop_evidence(family, e["id"])
	return _r(true, "The ledgers go in the stove. The accountant starts a new set, with nothing in it.")


func act_cleanup(peer: int, ev_id: int) -> Dictionary:
	var p := player(peer)
	var family := int(p.get("family", -1))
	var f := fam(family)
	var e := evidence_by_id(family, ev_id)
	if e.is_empty() or e["kind"] != "body":
		return _r(false, "")
	if month - int(e["month"]) > 2:
		return _r(false, "Too late: the police already have the body.")
	var cost := 200 if Rackets.has_ring(family, "meat") else 400
	if f["dirty"] < cost:
		return _r(false, "The cleanup crew wants $%d." % cost)
	f["dirty"] -= cost
	_drop_evidence(family, ev_id)
	return _r(true, "Lime, a car trunk and the Jersey marshes. There never was a body.")


func act_reach_rat(peer: int, ev_id: int) -> Dictionary:
	var p := player(peer)
	var family := int(p.get("family", -1))
	var f := fam(family)
	var e := evidence_by_id(family, ev_id)
	if e.is_empty() or e["kind"] != "informant":
		return _r(false, "")
	if f["dirty"] < 2000:
		return _r(false, "Getting to a man in protective custody costs $2,000: a guard, a cook, a cellmate.")
	f["dirty"] -= 2000
	if _rng.randf() < 0.6:
		_drop_evidence(family, ev_id)
		add_evidence(family, "body", "A state's witness found hanged in his cell", 10.0)
		_log("STATE'S WITNESS FOUND DEAD IN HIS CELL. The DA's case collapses.")
		return _r(true, "He never makes it to the trial. The DA's case falls apart.")
	e["w"] = float(e["w"]) + 15.0
	_recalc_heat(f)
	return _r(false, "The guard talked. They moved the rat, and now the DA knows you tried.")


# ------------------------------------------------------------------ guns

func act_buy_gun(peer: int, kind: String) -> Dictionary:
	var p := player(peer)
	var f := fam(int(p.get("family", -1)))
	if kind == "tommy" and year() < 1928:
		return _r(false, "\"The Thompson? Not yet. Army's still got 'em all. Ask me again in '28.\"")
	var price := int(dealer.get(kind, 0))
	if Rackets.has_ring(int(p.get("family", -1)), "pawn"):
		price /= 2
	if p["wallet"] < price:
		return _r(false, "$%d, cash." % price)
	p["wallet"] -= price
	var ars: Dictionary = f["arsenal"]
	match kind:
		"ammo": ars["ammo"] = int(ars["ammo"]) + 25
		_: ars[kind] = int(ars.get(kind, 0)) + 1
	_dirty = true
	var what := {"pistol": "A .38 revolver, serial number filed off.", "tommy": "A Thompson submachine gun in a violin case.",
		"ammo": "A box of cartridges (25)."}
	return _r(true, what.get(kind, ""))


func can_shoot(peer: int) -> bool:
	var ars: Dictionary = fam(int(player(peer).get("family", -1))).get("arsenal", {})
	return (int(ars.get("pistol", 0)) > 0 or int(ars.get("tommy", 0)) > 0) and int(ars.get("ammo", 0)) > 0


func fired(peer: int, district: String) -> void:
	var family := int(player(peer).get("family", -1))
	var ars: Dictionary = fam(family)["arsenal"]
	ars["ammo"] = maxi(0, int(ars["ammo"]) - 1)
	add_evidence(family, "weapon", "Your gun: bullets from it in %s" % district, 6.0)


# ------------------------------------------------------------------ deals

## terms: {kind: "truce"|"tribute"|"alliance", months, amount (paid by `from` to `to`;
## negative = demanded from `to`), against}
func propose(from_family: int, to_family: int, terms: Dictionary) -> Dictionary:
	if from_family == to_family:
		return _r(false, "")
	var d := {"id": next_id, "from": from_family, "to": to_family, "terms": terms, "expires": month + 1}
	next_id += 1
	var target := fam(to_family)
	if target["ai"]:
		var yes := _ai_consider(target, from_family, terms)
		_settle(d, yes)
		return _r(yes, ("The %s family accepts." if yes else "The %s family says no.") % target["name"])
	deals.append(d)
	_notice(to_family, "The %s family wants a sit-down." % fam(from_family)["name"], "deal")
	_dirty = true
	return _r(true, "Offer sent to the %s family." % target["name"])


func respond(deal_id: int, family: int, accept: bool) -> Dictionary:
	for d in deals:
		if d["id"] == deal_id and d["to"] == family:
			deals.erase(d)
			var ok := _settle(d, accept)
			return _r(ok, "Deal done." if ok else "Refused.")
	return _r(false, "That offer is gone.")


func _settle(d: Dictionary, accept: bool) -> bool:
	var a: int = d["from"]
	var b: int = d["to"]
	var t: Dictionary = d["terms"]
	if not accept:
		_notice(a, "The %s family turned down your offer." % families[b]["name"], "warn")
		_dirty = true
		return false
	var amt := int(t.get("amount", 0))
	var payer: Dictionary = families[a] if amt >= 0 else families[b]
	var payee: Dictionary = families[b] if amt >= 0 else families[a]
	if absi(amt) > 0:
		if payer["dirty"] < absi(amt):
			_notice(a, "The deal fell through: not enough cash.", "warn")
			return false
		payer["dirty"] -= absi(amt)
		payee["dirty"] += absi(amt)
	var r := rel(a, b)
	var months := int(t.get("months", 6))
	if t.get("kind", "truce") in ["truce", "alliance", "tribute"]:
		r["truce_until"] = month + months
		r["war"] = false
		r["grudge"] = {}
		families[a]["kept"] += 1
		families[b]["kept"] += 1
	if t.get("kind", "") == "alliance" and int(t.get("against", -1)) >= 0:
		var enemy := int(t["against"])
		rel(a, enemy)["war"] = true
		rel(b, enemy)["war"] = true
		_log("The %s and %s families shake hands. Somebody should worry." % [families[a]["name"], families[b]["name"]])
	else:
		_log("Sit-down at Umberto's: the %s and %s families agree to peace." % [families[a]["name"], families[b]["name"]])
	_notice(a, "The %s family shook on it." % families[b]["name"], "good")
	_notice(b, "You shook hands with the %s family." % families[a]["name"], "good")
	_dirty = true
	return true


func _ai_consider(me: Dictionary, other: int, terms: Dictionary) -> bool:
	var mine := strength(me["id"])
	var theirs := strength(other)
	var r := rel(me["id"], other)
	var grudge := int(r["grudge"].get(str(me["id"]), 0))
	var score: float = 0.2 + (theirs - mine) * 0.08 - grudge * 0.01 + families[other]["kept"] * 0.03 \
		- families[other]["broken"] * 0.15
	var amt := int(terms.get("amount", 0))
	score += amt / 2000.0
	if terms.get("kind", "") == "alliance":
		var enemy := int(terms.get("against", -1))
		if enemy >= 0 and rel(me["id"], enemy)["war"]:
			score += 0.35
		else:
			score -= 0.2
	return _rng.randf() < clampf(score, 0.05, 0.9)


# ------------------------------------------------------------------ AI families

func _ai_month(f: Dictionary) -> void:
	var id: int = f["id"]
	var men := crew_of(id)
	var want_men := mini(8, 2 + (month - int(cfg["start_month"])) / 5)
	if men.size() < want_men and f["dirty"] > 900 and (men.size() < 2 or Syndicate._net_dirty(f) > 200):
		f["dirty"] -= 250
		_add_crew(id, "associate")
	# with men to spare, post guards outside the best shops (two stay at the club)
	var at_club := men.filter(func(c: Dictionary) -> bool: return c["task"] == "guard" and int(c["target"]) == int(f["hq"]))
	if at_club.size() > 2:
		var mine := shops_of(id).filter(func(b: Dictionary) -> bool: return int(b["id"]) != int(f["hq"]))
		mine.sort_custom(func(a, b) -> bool: return int(a["rate"]) + int(a["value"]) / 20 > int(b["rate"]) + int(b["value"]) / 20)
		for b in mine.slice(0, at_club.size() - 2):
			if not men.any(func(c: Dictionary) -> bool: return c["task"] == "guard" and int(c["target"]) == int(b["id"])):
				var g: Dictionary = at_club.pop_back()
				g["task"] = "guard"
				g["target"] = b["id"]
	# booze: from its warehouse on the quay if it has one, else abstract runs from the docks
	for b in owned_by(id):
		if b["speak"] and b["stock"] < 10 and Syndicate.stock(nation, "nyc", id) > 0:
			var got := Syndicate.take_stock(nation, "nyc", id, Syndicate.SPEAK_CAP - int(b["stock"]))
			if _rng.randf() < 0.05 + f["heat"] / 300.0:
				add_evidence(f["id"], "cop", "A loaded %s family truck stopped on West St." % f["name"], 5.0)
			else:
				b["stock"] += got
	# the night boat only has so much: past that, the speakeasies need a real supply line
	var boat_left := 14
	for b in owned_by(id):
		if b["speak"] and b["stock"] < 10 and f["dirty"] > 400 and boat_left > 0:
			var n := mini(mini(16, boat_left), int(f["dirty"] / CRATE_COST / 2))
			boat_left -= n
			f["dirty"] -= n * CRATE_COST
			if _rng.randf() < f["heat"] / 250.0:
				add_evidence(f["id"], "ledger", "A seized truck traced to the %s family" % f["name"], 6.0)
				_log("Dry agents seize a %s family truck on the West Side Highway." % f["name"])
			else:
				b["stock"] += n
	# buy fronts, open a speakeasy
	if f["clean"] > 3000:
		var cands := biz.filter(func(b: Dictionary) -> bool:
			return b["owned_by"] < 0 and b["kind"] != "precinct" and (b["protector"] == id or b["protector"] < 0) and b["value"] * 1.1 < f["clean"])
		if not cands.is_empty():
			var b: Dictionary = cands[_rng.randi_range(0, cands.size() - 1)]
			act_buy(id, b["id"])
	for b in owned_by(id):
		if not b["speak"] and b["kind"] not in ["club", "warehouse"] and f["dirty"] > SPEAKEASY_COST * 2:
			f["dirty"] -= SPEAKEASY_COST
			b["speak"] = true
			b["demand"] = 16
			break
	# payroll when hot
	if f["heat"] > 35 and f["dirty"] > 600:
		for cop in cops:
			if cop["payroll"] < 0 and cop["honesty"] < 0.7 and cop["district"] == biz[f["hq"]]["district"]:
				cop["payroll"] = id
				f["dirty"] -= 100
				break
	# expansion or revenge: give orders to the crew in the world
	var orders := 1 + (1 if men.size() > 3 else 0)
	for n in orders:
		if men.is_empty():
			break
		var c: Dictionary = men[_rng.randi_range(0, men.size() - 1)]
		var enemy := _ai_enemy(id)
		var target := {}
		if enemy >= 0 and _rng.randf() < 0.6:
			var theirs := shops_of(enemy).filter(func(b: Dictionary) -> bool: return b["owned_by"] < 0)
			if not theirs.is_empty():
				target = theirs[_rng.randi_range(0, theirs.size() - 1)]
		if target.is_empty():
			target = _ai_pick_shop(id)
		if target.is_empty():
			continue
		var kind := "pitch"
		if target["protector"] >= 0 and target["protector"] != id:
			kind = "lean" if _rng.randf() < 0.5 else "pitch"
		if has_truce(id, int(target["protector"])):
			continue
		ai_order.emit({"family": id, "crew": c["id"], "kind": kind, "biz": target["id"]})
	# offers to human families
	for other in families:
		if other["ai"] or not other["alive"] or other["id"] == id:
			continue
		var r := rel(id, other["id"])
		if r["war"] and strength(id) < strength(other["id"]) and _rng.randf() < 0.25 \
				and not deals.any(func(d: Dictionary) -> bool: return d["from"] == id):
			deals.append({"id": next_id, "from": id, "to": other["id"], "expires": month + 1,
				"terms": {"kind": "truce", "months": 6, "amount": 300}})
			next_id += 1
			_notice(other["id"], "The %s family wants a sit-down." % f["name"], "deal")
		elif strength(id) > strength(other["id"]) * 1.8 and _rng.randf() < 0.15 \
				and not has_truce(id, other["id"]) and not deals.any(func(d: Dictionary) -> bool: return d["from"] == id):
			deals.append({"id": next_id, "from": id, "to": other["id"], "expires": month + 1,
				"terms": {"kind": "tribute", "months": 6, "amount": -500}})
			next_id += 1
			_notice(other["id"], "The %s family demands tribute." % f["name"], "deal")


func _ai_enemy(id: int) -> int:
	var best := -1
	var worst := 0
	for other in families:
		if other["id"] == id or not other["alive"] or has_truce(id, other["id"]):
			continue
		var r := rel(id, other["id"])
		var g := int(r["grudge"].get(str(id), 0)) + (40 if r["war"] else 0)
		if g > worst:
			worst = g
			best = other["id"]
	return best


func _ai_pick_shop(id: int) -> Dictionary:
	var home: String = biz[fam(id)["hq"]]["district"]
	var best := {}
	var bs := -INF
	for b in biz:
		if b["protector"] == id or b["owned_by"] >= 0 or b["kind"] in ["precinct", "club"]:
			continue
		var s: float = b["rate"] * 0.01 - b["defiance"] * 0.01 + (2.0 if b["district"] == home else 0.0) \
			+ _rng.randf() * 1.5 - (1.5 if b["protector"] >= 0 else 0.0)
		if s > bs:
			bs = s
			best = b
	return best


## World calls this when an AI crewman reaches the shop (or directly if there is no body).
func resolve_ai_order(order: Dictionary) -> Dictionary:
	var c := crew_by_id(int(order["crew"]))
	if c.is_empty() or c["state"] != "free":
		return _r(false, "")
	var family := int(order["family"])
	match order["kind"]:
		"pitch":
			return act_pitch(family, int(order["biz"]), 1)
		"lean":
			var r := act_lean(family, int(order["biz"]))
			act_pitch(family, int(order["biz"]), 2)
			return r
	return _r(false, "")


# ------------------------------------------------------------------ news, notices, save

func _log(text: String) -> void:
	_month_log.append(text)


## Already a story like this in this month's paper?
func news_this_month(prefix: String) -> bool:
	return _month_log.any(func(t: String) -> bool: return t.begins_with(prefix))


func _headline(text: String, big: bool = false) -> void:
	news.push_front({"month": month, "text": text, "big": big})
	if news.size() > 40:
		news.resize(40)


func _notice(family: int, text: String, kind: String) -> void:
	notice.emit(family, text, kind)


func _r(ok: bool, msg: String) -> Dictionary:
	return {"ok": ok, "msg": msg}


func get_state() -> Dictionary:
	return {"cfg": cfg, "month": month, "clock": clock, "families": families, "biz": biz,
		"crew": crew, "cops": cops, "recruits": recruits, "players": players, "deals": deals,
		"relations": relations, "captains": captains, "news": news, "boat": boat, "econ": econ,
		"speak_mult": speak_mult, "next_id": next_id, "over": over, "running": running, "nation": nation}


func apply_state(s: Dictionary) -> void:
	var seed_changed: bool = plan == null or int(s["cfg"]["seed"]) != int(cfg["seed"])
	cfg = s["cfg"]
	if seed_changed:
		plan = CityPlan.generate(int(cfg["seed"]))
	month = s["month"]; clock = s["clock"]; families = s["families"]; biz = s["biz"]
	crew = s["crew"]; cops = s["cops"]; recruits = s["recruits"]; players = s["players"]
	deals = s["deals"]; relations = s["relations"]; captains = s["captains"]; news = s["news"]
	boat = s["boat"]; econ = s["econ"]; speak_mult = s["speak_mult"]; next_id = s["next_id"]
	over = s["over"]; running = s["running"]
	nation = Syndicate.upgrade(s.get("nation", Syndicate.fresh()))
	for b in biz:
		if not b.has("address") and plan != null:
			b["address"] = plan.address_at(float(b["door"][0]), float(b["door"][1]))
		# fields added by the 2D rebuild: older saves don't have them
		if not b.has("broken"):
			b["broken"] = []
		if not b.has("weak"):
			b["weak"] = Rackets.weak_for(int(b["id"]), int(cfg["seed"]))
	for c in crew:
		if not c.has("trait"):
			c["trait"] = Rackets.trait_for(int(c["id"]) * 31 + int(cfg["seed"]))
	for r in recruits:
		if not r.has("trait"):
			r["trait"] = Rackets.trait_for(int(r["id"]) * 31 + int(cfg["seed"]))
	state_changed.emit()


func save_campaign(slot: String = "campaign") -> String:
	DirAccess.make_dir_recursive_absolute("user://saves")
	var path := "user://saves/%s.json" % slot
	var fh := FileAccess.open(path, FileAccess.WRITE)
	if fh == null:
		return ""
	var s := get_state()
	s["time"] = _time
	fh.store_string(JSON.stringify(s))
	return path


func load_campaign(slot: String = "campaign") -> bool:
	var path := "user://saves/%s.json" % slot
	if not FileAccess.file_exists(path):
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		return false
	_fix_json_ints(data)
	plan = null
	apply_state(data)
	_time = float(data.get("time", 0.0))
	_rng.seed = int(cfg["seed"]) + month
	# jail timers are host seconds: release everyone on load
	for p in players.values():
		p["jailed_until"] = 0.0
	running = true
	return true


static func has_save(slot: String = "campaign") -> bool:
	return FileAccess.file_exists("user://saves/%s.json" % slot)


## JSON turns every number into a float; turn whole numbers back into ints so ids compare.
func _fix_json_ints(v: Variant) -> Variant:
	if v is Dictionary:
		for k in v.keys():
			v[k] = _fix_json_ints(v[k])
	elif v is Array:
		for k in v.size():
			v[k] = _fix_json_ints(v[k])
	elif v is float and v == floor(v) and absf(v) < 1e12:
		return int(v)
	return v
