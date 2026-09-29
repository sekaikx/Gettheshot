class_name Rackets
extends RefCounted
## Street mechanics in the spirit of The Godfather II: every shopkeeper has a weak spot, every man
## has a specialty, and owning a whole trade across the city (a crime ring) gives the family a
## perk. Pure data and pure functions over Game's dictionaries; Game and World call these.

## Crew specialties. One per man, shown on his card; the effect lives where the thing happens.
const TRAITS := {
	"bruiser": {"name": "Bruiser", "icon": "fist", "does": "Hits twice as hard. Shopkeepers fold faster when he's in the room."},
	"shooter": {"name": "Shooter", "icon": "gun", "does": "Deadly aim. Carries his own piece."},
	"driver": {"name": "Driver", "icon": "car", "does": "Booze runs get stopped half as often."},
	"talker": {"name": "Talker", "icon": "talk", "does": "Owners agree to pay sooner when he's with you."},
	"medic": {"name": "Medic", "icon": "cross", "does": "Gets downed men back on their feet in half the time."},
	"earner": {"name": "Earner", "icon": "money", "does": "Collecting, he brings in the whole envelope: no cut."},
}
const TRAIT_ORDER := ["bruiser", "shooter", "driver", "talker", "medic", "earner"]

## What scares a shopkeeper most. The one you hit fills his fear twice as fast; the rest work less.
## "hint" is what people on the street say about him.
const WEAK := {
	"glass": {"name": "his shop", "hint": "He'd die if anything happened to that shop of his.", "does": "Breaking his things scares him most."},
	"rough": {"name": "a beating", "hint": "Soft hands. Never been in a fight in his life.", "does": "Roughing him up scares him most."},
	"gun": {"name": "guns", "hint": "His brother was shot in '19. He shakes when he sees a piece.", "does": "Showing a gun scares him most."},
	"crowd": {"name": "your men", "hint": "He's brave one-on-one. Bring friends.", "does": "Coming with your men scares him most."},
}
const WEAK_ORDER := ["glass", "rough", "gun", "crowd"]

## Fear the owner must reach before he agrees to pay (0..100). Past BREAK he snaps: he runs
## to the cops and won't deal with you for a while.
const FEAR_DEAL := 70.0
const FEAR_BREAK := 100.0

## Crime rings: protect or own every shop of these trades in the city.
const RINGS := [
	{"id": "pawn", "name": "The Pawnbrokers", "kinds": ["pawnshop"], "perk": "Izzy sells you guns and ammo at half price."},
	{"id": "laundry", "name": "The Laundries", "kinds": ["laundry"], "perk": "Laundering costs 5% instead of 15%."},
	{"id": "eats", "name": "The Restaurants", "kinds": ["restaurant", "cafe"], "perk": "Your men eat free: wages cost 20% less."},
	{"id": "drug", "name": "The Drugstores", "kinds": ["drugstore"], "perk": "You and your men get back up twice as fast."},
	{"id": "numbers", "name": "The Numbers", "kinds": ["cigar", "candy"], "perk": "Each of those shops runs a numbers game: +$60 a month each."},
	{"id": "meat", "name": "The Butchers", "kinds": ["butcher", "fish"], "perk": "Bodies disappear: cleanup crews cost half and bodies fade fast."},
	{"id": "food", "name": "The Grocers & Bakers", "kinds": ["grocer", "bakery"], "perk": "Speakeasies sell 25% more (people eat when they drink)."},
	{"id": "rags", "name": "The Tailors & Barbers", "kinds": ["tailor", "barber", "cobbler"], "perk": "Everybody knows your face: shakedowns go 20% faster."},
	{"id": "tools", "name": "The Hardware Stores", "kinds": ["hardware"], "perk": "The family truck carries 16 crates instead of 10."},
]


## Deterministic pick for a new crewman or recruit.
static func trait_for(seed_value: int) -> String:
	return TRAIT_ORDER[absi(seed_value) % TRAIT_ORDER.size()]


static func weak_for(biz_id: int, seed_value: int) -> String:
	return WEAK_ORDER[absi(biz_id * 7 + seed_value * 13) % WEAK_ORDER.size()]


## For each ring: {id, name, kinds, perk, have, total, done}. "have" counts shops of those trades that
## pay the family or it owns.
static func ring_progress(family: int) -> Array:
	var out := []
	for r in RINGS:
		var have := 0
		var total := 0
		for b in Game.biz:
			if b["kind"] in r["kinds"]:
				total += 1
				if int(b["protector"]) == family or int(b["owned_by"]) == family:
					have += 1
		out.append({"id": r["id"], "name": r["name"], "kinds": r["kinds"], "perk": r["perk"],
			"have": have, "total": total, "done": total > 0 and have >= total})
	return out


static func has_ring(family: int, ring_id: String) -> bool:
	for r in RINGS:
		if r["id"] != ring_id:
			continue
		var total := 0
		for b in Game.biz:
			if b["kind"] in r["kinds"]:
				total += 1
				if int(b["protector"]) != family and int(b["owned_by"]) != family:
					return false
		return total > 0
	return false


## Men of a family with a given specialty who are free (on the street).
static func has_trait_near(family: int, trait_id: String, crew_ids: Array) -> bool:
	for id in crew_ids:
		var c := Game.crew_by_id(int(id))
		if not c.is_empty() and int(c["family"]) == family and String(c.get("trait", "")) == trait_id:
			return true
	return false


# ------------------------------------------------------------------ shakedowns (host)
# A shop owner who won't pay gets scared into it. Fear (biz.fear, 0..100) rises with what you do in
# his shop, fastest with his weak spot; at FEAR_DEAL he pays, past FEAR_BREAK he snaps and runs to
# the cops. biz.shake is the family leaning on him (-1: nobody), biz.shake_t when it last happened.

static func _mult(game: Node, family: int, b: Dictionary, how: String, crew_ids: Array) -> float:
	var m := 1.9 if String(b.get("weak", "")) == how else 0.75
	if has_trait_near(family, "talker", crew_ids):
		m *= 1.25
	if has_trait_near(family, "bruiser", crew_ids) and how in ["rough", "glass"]:
		m *= 1.25
	if has_ring(family, "rags"):
		m *= 1.2
	return m


## Start leaning on a shop (his fear starts where it is). Not a man who just went to the cops.
static func start(game: Node, family: int, biz_id: int) -> void:
	var b: Dictionary = game.biz_by_id(biz_id)
	if b.is_empty() or int(b.get("snapped_until", -1)) >= int(game.month):
		return
	b["shake"] = family
	b["shake_t"] = game.host_time()


static func scare(game: Node, family: int, biz_id: int, how: String, amount: float, crew_ids: Array = []) -> void:
	var b: Dictionary = game.biz_by_id(biz_id)
	if b.is_empty() or int(b.get("shake", -1)) != family:
		return
	b["fear"] = minf(120.0, float(b["fear"]) + amount * _mult(game, family, b, how, crew_ids))
	b["shake_t"] = game.host_time()
	game.mark_dirty()


## Fear fades once you stop (after a few seconds of calm), down to what he started with.
static func cool(game: Node, biz_id: int, dt: float) -> void:
	var b: Dictionary = game.biz_by_id(biz_id)
	if b.is_empty():
		return
	if game.host_time() - float(b.get("shake_t", 0.0)) > 4.0:
		b["fear"] = maxf(0.0, float(b["fear"]) - 2.5 * dt)
		if game.host_time() - float(b.get("shake_t", 0.0)) > 60.0:
			b["shake"] = -1
		game.mark_dirty()


## Did he just give in, or snap? {} if nothing happened.
static func check(game: Node, biz_id: int) -> Dictionary:
	var b: Dictionary = game.biz_by_id(biz_id)
	var family := int(b.get("shake", -1))
	if b.is_empty() or family < 0:
		return {}
	var fear := float(b["fear"])
	if fear >= FEAR_BREAK:
		b["shake"] = -1
		b["fear"] = 45.0
		b["snapped_until"] = int(game.month) + 2
		game.add_evidence(family, "witness", "%s (%s) went to the police about the %s family" % [b["owner_name"], b["name"], game.fam(family)["name"]], 14.0, {"biz": b["id"]})
		game.mark_dirty()
		return {"kind": "snap", "family": family, "msg": "%s has had enough. He runs for the cops. He won't deal with you for a while." % b["owner_name"]}
	if fear >= FEAR_DEAL:
		var prev := int(b["protector"])
		b["protector"] = family
		b["shake"] = -1
		b["defiance"] = maxi(0, int(b["defiance"]) - 20)
		b["unpaid"] = 0
		b["envelope"] = 0
		b["fear"] = 35.0  # he calms down once he pays: a rival has to scare him all over again
		var f: Dictionary = game.fam(family)
		f["rep"] = int(f["rep"]) + 2
		if prev >= 0 and prev != family:
			game.aggression(family, prev, 12)
			game.notice.emit(prev, "%s pays the %s family now." % [b["name"], f["name"]], "bad")
			game._log("%s switches sides: now pays the %s family." % [b["name"], f["name"]])
		game.mark_dirty()
		return {"kind": "deal", "family": family, "msg": "\"Okay! Okay! $%d a month. Just stop!\" %s pays you now." % [int(b["rate"]), b["name"]]}
	return {}


## "Offer protection", face to face. Scared enough, he says yes. Otherwise he says no, and the
## shakedown starts: now scare him.
static func pitch(game: Node, family: int, biz_id: int, crew_ids: Array) -> Dictionary:
	var b: Dictionary = game.biz_by_id(biz_id)
	var f: Dictionary = game.fam(family)
	if b.is_empty() or f.is_empty():
		return {"ok": false, "msg": ""}
	if int(b["protector"]) == family:
		return {"ok": false, "msg": "%s already pays you." % b["owner_name"]}
	if int(b["owned_by"]) >= 0:
		return {"ok": false, "msg": "This place belongs to the %s family." % game.fam(int(b["owned_by"]))["name"]}
	if int(b.get("snapped_until", -1)) >= int(game.month):
		return {"ok": false, "msg": "\"Get out of my shop. I already talked to the police about you.\""}
	var fear := float(b["fear"])
	var prev := int(b["protector"])
	# a man who's scared already, or impressed by your reputation, may just say yes
	var chance := 0.12 + fear * 0.006 + float(f["rep"]) * 0.004 + crew_ids.size() * 0.05 - float(b["defiance"]) * 0.003
	if prev >= 0:
		chance -= 0.15 + game.strength(prev) * 0.02
	if fear >= FEAR_DEAL or randf() < clampf(chance, 0.02, 0.6):
		b["fear"] = maxf(fear, FEAR_DEAL)
		b["shake"] = family
		var r := check(game, biz_id)
		return {"ok": true, "msg": "%s nods. \"$%d a month. Fine.\"" % [b["owner_name"], int(b["rate"])] if r.is_empty() else String(r["msg"])}
	start(game, family, biz_id)
	var w: Dictionary = WEAK.get(String(b.get("weak", "")), {})
	var line: String = ["\"I don't need your kind of protection.\"", "\"I already pay somebody. Get out.\"" if prev >= 0 else "\"I pay nobody. Never have.\"",
		"\"You think I'm scared of you?\""][randi() % 3]
	return {"ok": false, "msg": "%s He won't pay. Scare him: break his things, rough him up, show a gun. %s" % [line, String(w.get("does", ""))]}


## One of your men goes into a shop to take it: he leans on the owner (breaks something), then
## makes the offer. His specialty and your reputation count.
static func crew_take(game: Node, family: int, biz_id: int, crew_id: int) -> Dictionary:
	var b: Dictionary = game.biz_by_id(biz_id)
	var c: Dictionary = game.crew_by_id(crew_id)
	if b.is_empty() or c.is_empty():
		return {"ok": false, "msg": ""}
	if int(b["protector"]) == family:
		return {"ok": true, "msg": "%s already pays you." % b["name"]}
	if int(b.get("snapped_until", -1)) >= int(game.month):
		return {"ok": false, "msg": "%s won't deal with you: he went to the police. Try again in a month or two." % b["owner_name"]}
	start(game, family, biz_id)
	var ids := [crew_id]
	scare(game, family, biz_id, "crowd", 18.0, ids)
	scare(game, family, biz_id, "glass", 16.0, ids)
	var tough := float(c.get("tough", 60)) / 100.0
	scare(game, family, biz_id, "rough", 10.0 + tough * 14.0, ids)
	var r := check(game, biz_id)
	if not r.is_empty():
		return {"ok": String(r["kind"]) == "deal", "smash": true, "msg": "%s: %s" % [c["name"], r["msg"]]}
	return {"ok": false, "smash": true, "msg": "%s leaned on %s at %s, but he still won't pay. Go and finish it yourself." % [c["name"], b["owner_name"], b["name"]]}


## E at the till of a shop that isn't yours.
static func rob_register(game: Node, world: Node, peer: int, me: Node, biz_id: int) -> Dictionary:
	var b: Dictionary = game.biz_by_id(biz_id)
	var p: Dictionary = game.player(peer)
	if b.is_empty() or p.is_empty():
		return {"ok": false, "msg": ""}
	var family := int(p["family"])
	if int(b["owned_by"]) == family:
		return {"ok": false, "msg": "It's your own till."}
	if int(b.get("robbed", -1)) >= int(game.month):
		return {"ok": false, "msg": "The till is empty. Somebody got here first."}
	var take := int(float(b["legit"]) * 1.4) + randi_range(20, 90)
	b["robbed"] = int(game.month)
	p["wallet"] = int(p["wallet"]) + take
	world.crime(me, 12.0, me.position, "robbery", int(b["protector"]))
	if int(b["protector"]) >= 0 and int(b["protector"]) != family:
		game.aggression(family, int(b["protector"]), 10)
	b["fear"] = minf(100.0, float(b["fear"]) + 20.0)
	game.mark_dirty()
	return {"ok": true, "msg": "You empty the till: $%d." % take}


## E at a rival family's safe, in the back office of their club.
static func rob_safe(game: Node, world: Node, peer: int, me: Node, biz_id: int) -> Dictionary:
	var b: Dictionary = game.biz_by_id(biz_id)
	var p: Dictionary = game.player(peer)
	var owner := int(b.get("hq_of", -1))
	if b.is_empty() or p.is_empty() or owner < 0 or owner == int(p["family"]):
		return {"ok": false, "msg": ""}
	var f: Dictionary = game.fam(owner)
	if int(b.get("safe_robbed", -1)) >= int(game.month):
		return {"ok": false, "msg": "The safe hangs open. Empty."}
	var take := mini(2500, int(float(f["dirty"]) * 0.35))
	f["dirty"] = int(f["dirty"]) - take
	p["wallet"] = int(p["wallet"]) + take
	b["safe_robbed"] = int(game.month)
	game.aggression(int(p["family"]), owner, 40)
	world.crime(me, 18.0, me.position, "robbery", owner)
	game.notice.emit(owner, "Somebody cracked the safe at your club! The %s family." % game.fam(int(p["family"]))["name"], "bad")
	game._log("THIEVES CRACK A SAFE AT THE %s SOCIAL CLUB." % String(f["name"]).to_upper())
	game.mark_dirty()
	return {"ok": true, "msg": "You crack the %s family's safe: $%s." % [f["name"], W.money(take)]}


## A rival don was shot dead. If his family is weak (few rackets left), it's finished: its shops
## pay nobody, its men scatter, its club closes. Otherwise a new boss takes over, weaker.
static func don_killed(game: Node, family: int, by_family: int, street: String) -> void:
	var f: Dictionary = game.fam(family)
	if f.is_empty() or not bool(f["alive"]):
		return
	var shops: int = game.shops_of(family).size()
	if by_family >= 0 and by_family != family:
		game.aggression(by_family, family, 60)
		var k: Dictionary = game.fam(by_family)
		k["rep"] = int(k["rep"]) + 15
	game.add_evidence(by_family, "body", "Don %s found shot dead near %s" % [f["name"], street], 30.0)
	if shops <= 6:
		f["alive"] = false
		for b in game.biz:
			if b["kind"] == "club":
				continue
			if int(b["owned_by"]) == family:
				# the family's own fronts go back to their managers: up for sale again
				b["owned_by"] = -1
				b["speak"] = false
			if int(b["protector"]) == family:
				b["protector"] = -1
				b["fear"] = 10.0
		for c in game.crew:
			if int(c["family"]) == family and c["state"] in ["free", "away"]:
				c["state"] = "gone"
		game._log("DON %s SHOT DEAD. THE %s FAMILY IS FINISHED." % [String(f["name"]).to_upper(), String(f["name"]).to_upper()])
		game.notice.emit(-1, "The %s family is finished. Their rackets are up for grabs." % f["name"], "deal")
	else:
		f["rep"] = maxi(0, int(f["rep"]) - 20)
		for c in game.crew:
			if int(c["family"]) == family and c["state"] == "free":
				c["loyalty"] = int(c["loyalty"]) - 15
		game._log("DON %s SHOT DEAD ON %s. A new boss takes over the family." % [String(f["name"]).to_upper(), street.to_upper()])
		game.notice.emit(-1, "Don %s was killed. His family is still standing: it still holds %d rackets." % [f["name"], shops], "deal")
	game.mark_dirty()
