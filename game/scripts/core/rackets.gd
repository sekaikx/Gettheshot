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
	{"id": "rags", "name": "The Tailors & Barbers", "kinds": ["tailor", "barber", "cobbler"], "perk": "Everybody knows your face: +20 reputation, shakedowns go easier."},
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
