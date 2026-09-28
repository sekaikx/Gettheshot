extends Node
## The first night: Uncle Carmine, your late father's consigliere, walks you through the family
## business, one real step at a time: the safe, your first shakedown, hiring muscle, a cop on the
## payroll, a front that launders your money, a speakeasy, the booze boat. Each step shows a goal
## (with an arrow to it) and finishes when you actually do the thing; steps you do early are skipped.
## Progress is saved with the campaign (Game.players[you]["tut"]). Talk to Carmine in the club to
## hear the current step again, or to skip the rest.

const MENTOR := "Uncle Carmine"

var world: Node
var step := 0
var _mentor: Actor
var _shop := -1          # the shop the tutorial points you at
var _t := 0.0
var _said := -1
var _snapped := {}
var _book_seen := false

## [id, title, detail, line]
const STEPS := [
	["office", "Go to the back office", "Your club · the door at the back", "Your father built this family on respect. Now it's yours. Come, the office is in the back."],
	["cash", "Take $500 from the safe", "The safe · back office", "Money in your pocket can be taken off you on the street. The rest stays in the safe: that's your Stash. Take $500 for tonight."],
	["pitch", "Offer protection", "", "See that shop? He pays nobody. Go in, stand at his counter, and offer him protection."],
	["scare", "Scare him until he pays", "Break his things (F) · rough him up · watch the FEAR bar", "He said no. Now you show him. Break something, give him a slap. Watch his fear: when it reaches the mark, he pays. Too far and he runs to the cops."],
	["hire", "Hire a man", "The pool hall", "Good. One shop is a start. Now you need men. The pool hall is full of boys looking for work."],
	["cop", "Put a cop on the payroll", "Find a patrolman · $100", "The law sees everything you do. That's heat. A cop on the payroll looks the other way. Find a patrolman and slip him a hundred."],
	["buy", "Buy a front", "A shop that pays you · with Bank money", "Dirty money can't buy anything legal. A shop you own washes your Stash into clean Bank money every month. I put $2,500 in the Bank for you. Buy one of your shops."],
	["speak", "Open a speakeasy", "In the back of your shop · $600", "Now the real money. Open a speakeasy in the back of your shop. Prohibition makes every cellar a gold mine."],
	["booze", "Bring booze to your speakeasy", "At night · the middle pier on the Waterfront", "A speakeasy needs whisky. At night a boat ties up at the middle pier. Buy crates, load them on your truck, drive them to your speakeasy."],
	["book", "Open the family book", "Press Tab", "Press Tab any time: your men, your rackets, the heat on you, your rivals. M shows the whole city, J the country."],
	["done", "", "", "That's the business. Take the city one door at a time. The other families want it too. Don't let them have it."],
]


func _ready() -> void:
	var p := Game.player(Net.my_id())
	step = int(p.get("tut", 0))
	if step >= STEPS.size() - 1:
		queue_free()
		return
	world.happened.connect(_on_happened)
	_spawn_mentor.call_deferred()
	_pick_shop()
	_enter(step)


func _spawn_mentor() -> void:
	var me := int(Game.player(Net.my_id()).get("family", -1))
	var hq := Game.biz_by_id(int(Game.fam(me).get("hq", -1)))
	var lay: Dictionary = world.layout_of_biz(int(hq.get("id", -1)))
	if lay.is_empty():
		return
	_mentor = Actor.new()
	_mentor.family = -1
	_mentor.ref_id = Net.my_id()
	_mentor.setup(world, "m%d" % Net.my_id(), "consigliere", 51177, W.FAMILY_NONE)
	_mentor.kind = "consigliere"
	world.add_child(_mentor)
	world.actors[_mentor.key] = _mentor
	_mentor.sim = false
	var at: Vector2 = lay["spots"].get("mentor", (lay["shop"] as Rect2).get_center())
	_mentor.place(at, (lay["front"] as Vector2).angle())


## The nearest shop to the club that pays nobody (a bakery if there's one close).
func _pick_shop() -> void:
	var me := int(Game.player(Net.my_id()).get("family", -1))
	var hq := Game.biz_by_id(int(Game.fam(me).get("hq", -1)))
	var best := -1
	var bd := INF
	for b in Game.biz:
		if b["kind"] in ["club", "precinct", "warehouse", "poolhall"] or int(b["protector"]) >= 0 or int(b["owned_by"]) >= 0:
			continue
		if _snapped.has(int(b["id"])) or int(b.get("snapped_until", -1)) >= Game.month:
			continue
		var d := W.door(b).distance_to(W.door(hq)) * (0.8 if b["kind"] == "bakery" else 1.0)
		if d < bd:
			bd = d
			best = int(b["id"])
	_shop = best


func _save() -> void:
	var p := Game.player(Net.my_id())
	if not p.is_empty():
		p["tut"] = step
	Net.to_host("tutorial", [step])


func _enter(n: int) -> void:
	step = n
	_save()
	if step >= STEPS.size():
		return
	var s: Array = STEPS[step]
	var id := String(s[0])
	if id == "done":
		world.hud.clear_objective()
		_say(String(s[3]), 12.0)
		Net.to_host("tutorial", [step, "done"])
		world.hud.toast("Tutorial done. The city is yours to take.", "good")
		set_process(false)
		return
	if id == "buy":
		Net.to_host("tutorial", [step, "gift"])
	var detail := String(s[2])
	if id in ["pitch", "scare"]:
		var b := Game.biz_by_id(_shop)
		if not b.is_empty():
			detail = "%s · %s" % [b["name"], b.get("address", "")] if id == "pitch" else detail
	world.hud.set_objective({"title": String(s[1]), "detail": detail, "target": _target(id), "step": step + 1, "of": STEPS.size() - 1})
	_say(String(s[3]))


func _say(text: String, seconds: float = 10.0) -> void:
	world.hud.mentor_say(MENTOR, text, {"kind": "consigliere", "look": 51177, "color": W.FAMILY_NONE, "extra": {}}, seconds)


func _target(id: String) -> Vector2:
	var me := int(Game.player(Net.my_id()).get("family", -1))
	var hq := Game.biz_by_id(int(Game.fam(me).get("hq", -1)))
	var lay: Dictionary = world.layout_of_biz(int(hq.get("id", -1)))
	match id:
		"office":
			return (lay["back"] as Rect2).get_center() if not lay.is_empty() else Vector2.INF
		"cash":
			return lay["spots"].get("safe", Vector2.INF) if not lay.is_empty() else Vector2.INF
		"pitch", "scare":
			return world.talk_spot(_shop) if _shop >= 0 else Vector2.INF
		"hire":
			var best := Vector2.INF
			var bd := INF
			for a in world.actors.values():
				if (a as Actor).kind == "recruit" and world.local_actor:
					var d := (a as Actor).position.distance_to(world.local_actor.position)
					if d < bd:
						bd = d
						best = (a as Actor).position
			return best
		"cop":
			var best2 := Vector2.INF
			var bd2 := INF
			for a in world.actors.values():
				var ac := a as Actor
				if ac.kind == "cop" and not ac.key.begins_with("s") and world.local_actor:
					var c := Game.cop_by_id(ac.ref_id)
					if int(c.get("payroll", -1)) == me:
						continue
					var d2 := ac.position.distance_to(world.local_actor.position)
					if d2 < bd2:
						bd2 = d2
						best2 = ac.position
			return best2
		"buy":
			for b in Game.shops_of(me):
				if int(b["owned_by"]) < 0 and b["kind"] not in ["club", "warehouse", "precinct"]:
					return world.talk_spot(int(b["id"]))
		"speak":
			for b in Game.owned_by(me):
				if b["kind"] not in ["club", "warehouse"] and not b["speak"]:
					return world.talk_spot(int(b["id"]))
		"booze":
			if world.local_actor and world.local_actor.carrying or _truck_loaded():
				for b in Game.owned_by(me):
					if b["speak"]:
						return W.door(b)
			var tip: Array = world.plan.piers[1]["tip"]
			return W.p(float(tip[0]), float(tip[1]))
	return Vector2.INF


func _truck_loaded() -> bool:
	var me := int(Game.player(Net.my_id()).get("family", -1))
	var t: Vehicle = world.vehicles.get("t%d" % me)
	return t != null and t.load > 0


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.5
	if step >= STEPS.size():
		return
	var id := String(STEPS[step][0])
	# moving targets (people) and shops that changed
	if id in ["hire", "cop", "booze", "pitch", "scare"]:
		var o: Dictionary = world.hud.get("_objective") if world.hud.get("_objective") is Dictionary else {}
		if not o.is_empty():
			o["target"] = _target(id)
			world.hud.set_objective(o)
	if _done(id):
		_enter(step + 1)


## Has the step been done (maybe before we got to it)?
func _done(id: String) -> bool:
	var me := int(Game.player(Net.my_id()).get("family", -1))
	var p := Game.player(Net.my_id())
	var a: Actor = world.local_actor
	match id:
		"office":
			var hq := Game.biz_by_id(int(Game.fam(me).get("hq", -1)))
			var lay: Dictionary = world.layout_of_biz(int(hq.get("id", -1)))
			return a != null and not lay.is_empty() and (lay["back"] as Rect2).has_point(a.position)
		"cash":
			return int(p.get("wallet", 0)) >= 500
		"pitch":
			var b := Game.biz_by_id(_shop)
			return not b.is_empty() and (int(b.get("shake", -1)) == me or int(b["protector"]) == me)
		"scare":
			var b2 := Game.biz_by_id(_shop)
			if b2.is_empty():
				return true
			if int(b2.get("snapped_until", -1)) >= Game.month and int(b2["protector"]) != me:
				_snapped[_shop] = true
				_say("Too far. He ran to the cops: that's heat on you. It happens. Try another shop.", 9.0)
				_pick_shop()
				step -= 1
				_enter(step)
				return false
			return int(b2["protector"]) == me
		"hire":
			return Game.crew_of(me).size() >= 3
		"cop":
			return Game.cops.any(func(c: Dictionary) -> bool: return int(c["payroll"]) == me) or Game.captains.values().has(me)
		"buy":
			return Game.owned_by(me).any(func(b: Dictionary) -> bool: return b["kind"] not in ["club", "warehouse"])
		"speak":
			return Game.owned_by(me).any(func(b: Dictionary) -> bool: return b["speak"])
		"booze":
			return Game.owned_by(me).any(func(b: Dictionary) -> bool: return b["speak"] and int(b["stock"]) > 0)
		"book":
			return _book_seen
	return false


func _input(e: InputEvent) -> void:
	if e is InputEventKey and (e as InputEventKey).pressed and (e as InputEventKey).keycode == KEY_TAB:
		_book_seen = true


func _on_happened(what: String, data: Dictionary) -> void:
	if what == "refused" and step < STEPS.size() and String(STEPS[step][0]) == "pitch":
		_shop = int(data.get("biz", _shop))
	if what == "talked" and String(data.get("kind", "")) == "consigliere":
		pass
	if what == "book":
		_book_seen = true


## What Carmine says when you talk to him.
func mentor_conversation() -> Dictionary:
	var s: Array = STEPS[mini(step, STEPS.size() - 1)]
	return {"name": MENTOR, "role": "Your father's consigliere", "portrait": {"kind": "consigliere", "look": 51177, "color": W.FAMILY_NONE, "extra": {}},
		"line": "\"%s\"" % s[3],
		"info": ["Now: %s." % s[1]] if String(s[1]) != "" else [],
		"options": [{"text": "Thanks, Uncle", "icon": "talk", "action": Callable()},
			{"text": "I know the business. Skip the rest", "sub": "you keep the $2,500", "icon": "leave", "action": func() -> void: skip()}]}


func skip() -> void:
	if step < 6:
		Net.to_host("tutorial", [step, "gift"])
	_enter(STEPS.size() - 1)
