class_name PlayerController
extends Node
## Your hands on the street. Walks your boss (or drives the truck), finds what you're standing
## next to and asks the host to act on it.
##   WASD move · Shift sprint · Alt walk · E talk / use · F punch · G pistol · R send your crew at
##   the person in front of you · V get in / out of the truck · Space brake (driving)
##   Z / C turn the camera · scroll zoom · Tab family · M map · N newspaper · Esc menu

var world: World
var focus := {}          # what E would use: {type, id, key, label}
var auto_move := Vector2.ZERO   # autotest: pretend the stick is held
var _punch_cd := 0.0
var _shoot_cd := 0.0


func _physics_process(delta: float) -> void:
	_punch_cd = maxf(0.0, _punch_cd - delta)
	_shoot_cd = maxf(0.0, _shoot_cd - delta)
	var a = world.local_actor
	if a == null:
		return
	var busy: bool = world.hud.is_modal() or world.hud.in_jail()
	if world.local_vehicle:
		var v = world.local_vehicle
		var th := 0.0
		var tu := 0.0
		if not busy:
			th = float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)) - float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN))
			tu = float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)) - float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT))
		v.drive(delta, th, tu, Input.is_key_pressed(KEY_SPACE) and not busy)
		a.position = v.position
		focus = {}
		world.hud.set_prompt("V  Get out" + ("   ·   %d crates in the back" % v.load if v.load > 0 else ""))
		return
	if a.is_down() or busy:
		a.velocity = Vector3.ZERO
		if a.is_down():
			world.hud.set_prompt("")
		return
	var inp := Vector2(float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)),
		float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)) - float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)))
	if auto_move != Vector2.ZERO:
		inp = auto_move
	if inp.length() > 1.0:
		inp = inp.normalized()
	var spd := Actor.RUN
	if Input.is_key_pressed(KEY_SHIFT):
		spd = Actor.SPRINT
	if Input.is_key_pressed(KEY_ALT):
		spd = Actor.WALK
	if a.carrying:
		spd = minf(spd, 2.1)
	var dir = world.cam.flat_basis() * Vector3(-inp.x, 0, inp.y)
	a.velocity = dir * spd
	_find_focus(a)


func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.pressed or e.echo:
		return
	var k := (e as InputEventKey).keycode
	var hud = world.hud
	if k == KEY_ESCAPE:
		hud.escape()
		return
	if hud.is_modal():
		hud.modal_key(k)
		return
	match k:
		KEY_Z: world.cam.turn(1)
		KEY_C: world.cam.turn(-1)
		KEY_TAB: hud.toggle_family()
		KEY_M: hud.toggle_map()
		KEY_J: hud.toggle_nation()
		KEY_N: hud.show_newspaper(-1)
		KEY_H, KEY_F1: hud.toggle_help()
	var a = world.local_actor
	if a == null or a.is_down() or hud.in_jail():
		return
	if world.local_vehicle:
		if k == KEY_V or k == KEY_E:
			Net.to_host("exit", [])
		return
	match k:
		KEY_E: _use()
		KEY_F:
			if _punch_cd <= 0.0:
				_punch_cd = 0.55
				a.person.action("punch")
				Net.to_host("punch", [])
		KEY_G:
			if _shoot_cd <= 0.0:
				_shoot_cd = 0.9
				a.person.action("shoot")
				Net.to_host("shoot", [])
		KEY_R:
			var t := _target_in_front(a, 12.0)
			if t:
				Net.to_host("sic", [t.key])
			else:
				hud.toast("Face someone to send your boys after them.", "info")
		KEY_V:
			var v := _near_vehicle(a)
			if v:
				Net.to_host("enter", [v.key])
		KEY_Q:
			if a.carrying:
				Net.to_host("drop", [])


func _use() -> void:
	var a = world.local_actor
	if focus.is_empty():
		return
	if focus.get("quick", "") != "":
		# E at your warehouse door with the truck parked there: load it straight away
		a.person.action("interact")
		Net.to_host("act", [focus["quick"], focus["id"], 0])
		return
	match focus["type"]:
		"river":
			a.person.action("interact")
			Net.to_host("dump_gun", [])
		"item":
			a.person.action("pickup")
			Net.to_host("pickup", [focus["id"]])
		"truck":
			var v: Vehicle = world.vehicles.get(focus["key"])
			if v == null:
				return
			if a.carrying:
				Net.to_host("truck_load", [v.key])
			elif v.load > 0 and v.family == a.family:
				world.hud.open_truck(v)
			else:
				Net.to_host("enter", [v.key])
		_:
			world.hud.open_dialog(focus)


func _near_vehicle(a: Actor) -> Vehicle:
	var best: Vehicle = null
	var bd := 4.0
	for v in world.vehicles.values():
		var ve := v as Vehicle
		if not ve.lane.is_empty() or ve.driver != 0 or not ve.key.begins_with("t"):
			continue
		var d := ve.position.distance_to(a.position)
		if d < bd:
			bd = d
			best = ve
	return best


func _target_in_front(a: Actor, dist: float) -> Actor:
	var fwd := Vector3(sin(a.yaw), 0, cos(a.yaw))
	var best: Actor = null
	var bd := dist
	for o in world.actors.values():
		var ac := o as Actor
		if ac == a or ac.is_down() or not ac.visible or ac.family == a.family:
			continue
		var to := ac.position - a.position
		to.y = 0.0
		var d := to.length()
		if d < bd and fwd.dot(to / maxf(d, 0.01)) > 0.8:
			bd = d
			best = ac
	return best


## What E would act on: the nearest thing in reach, with your own men (who follow at your heels)
## and the parked truck ranked behind a door you're standing at.
func _find_focus(a: Actor) -> void:
	var best := {}
	var bd := 99.0
	var p := a.position
	for id in world.items:
		var c: Crate = world.items[id]
		var d := c.position.distance_to(p)
		if d < 1.7 and d < bd:
			bd = d
			best = {"type": "item", "id": id, "label": ("Pick up the crate" if c.kind == "crate" else "Pick up $%d" % c.amount)}
	if best.is_empty():
		for o in world.actors.values():
			var ac := o as Actor
			if ac == a or ac.is_down() or not ac.visible:
				continue
			if ac.kind in ["ped"]:
				continue
			var own := ac.kind == "crew" and ac.family == a.family
			var d := ac.position.distance_to(p) + (1.2 if own else 0.0)
			if d < (3.5 if own else 2.3) and d < bd:
				var lab := _actor_label(ac)
				if lab != "":
					bd = d
					best = {"type": "actor", "key": ac.key, "kind": ac.kind, "id": ac.ref_id, "label": lab}
	# standing at a warehouse door on the quay, the door wins over the truck parked beside it
	var at_wh := false
	for b in Game.biz:
		if b["kind"] == "warehouse" and Vector2(float(b["door"][0]) - p.x, float(b["door"][1]) - p.z).length() < 2.2:
			at_wh = true
	if best.get("type", "") in ["", "actor"] and not at_wh:
		for v in world.vehicles.values():
			var ve := v as Vehicle
			if not ve.key.begins_with("t") or ve.driver != 0:
				continue
			var d := ve.position.distance_to(p) + 0.3
			if d < 3.9 and d < bd:
				bd = d
				var mine := ve.family == a.family
				var lab := "Load the crate into the truck" if a.carrying else ("Truck: %d crates  (E unload / V drive)" % ve.load if ve.load > 0 else "Drive the %s truck (V)" % ("family" if mine else Game.fam(ve.family).get("name", "") + " family's"))
				best = {"type": "truck", "key": ve.key, "label": lab}
	if best.is_empty() and world._near_river(p):
		var guns: Array = Game.fam(a.family).get("evidence", []).filter(func(e: Dictionary) -> bool: return e["kind"] == "weapon")
		if not guns.is_empty():
			best = {"type": "river", "label": "Throw the gun in the river (it's evidence)"}
	if best.get("type", "") in ["", "actor", "truck"]:
		for b in Game.biz:
			var door := Vector3(b["door"][0], 0.16, b["door"][1])
			var d := door.distance_to(Vector3(p.x, 0.16, p.z))
			if d < 2.8 and d < bd:
				bd = d
				best = {"type": "biz", "id": b["id"], "label": _biz_label(b)}
				if b["kind"] == "warehouse" and int(b["owned_by"]) == a.family:
					var truck: Vehicle = world.parked_truck(a.family, door, 9.0)
					var have := Syndicate.stock(Game.nation, "nyc", a.family)
					if truck and truck.load < Vehicle.MAX_LOAD and have > 0 and not a.carrying:
						best["quick"] = "wh_load"
						best["label"] = "Load %d crates into the truck  (%d in the warehouse)" % [mini(have, Vehicle.MAX_LOAD - truck.load), have]
	focus = best
	if a.carrying and best.is_empty():
		world.hud.set_prompt("Carrying a crate  ·  Q drop it")
	else:
		world.hud.set_prompt(("E  " + String(best["label"])) if not best.is_empty() else "")


func _actor_label(ac: Actor) -> String:
	match ac.kind:
		"cop":
			var c := Game.cop_by_id(ac.ref_id)
			return "Talk to %s" % c.get("name", "the officer")
		"recruit":
			for r in Game.recruits:
				if r["id"] == ac.ref_id:
					return "Talk to %s (looking for work)" % r["name"]
			return ""
		"aiboss":
			return "Sit down with Don %s" % Game.fam(ac.family).get("name", "")
		"boss":
			if ac.family == world.local_actor.family:
				return ""
			return "Sit down with the %s family" % Game.fam(ac.family).get("name", "")
		"crew":
			var c := Game.crew_by_id(ac.ref_id)
			if ac.family == world.local_actor.family:
				return "Give %s an order" % c.get("name", "your man")
			return ""
		"smuggler":
			return "Talk to the man from the boat" if ac.visible else ""
		"dealer":
			return "Talk to Izzy (he sells things that go bang)"
		"unionboss":
			return "Talk to %s, hiring boss of Local %s" % [Game.UNION_BOSS, Game.UNION_LOCAL]
	return ""


func _biz_label(b: Dictionary) -> String:
	var me = world.local_actor.family
	if b["kind"] == "precinct":
		return "The desk sergeant, 14th Precinct"
	if b["kind"] == "warehouse":
		var own := int(b["owned_by"])
		if own == me:
			return "Your warehouse: %d crates  ·  park the truck here to load it" % Syndicate.stock(Game.nation, "nyc", me)
		if own >= 0:
			return "%s (the %s family's warehouse)" % [b["name"], Game.fam(own)["name"]]
		return "%s  ·  a warehouse on the quay, for sale" % b["name"]
	if b["kind"] == "club":
		if int(b["hq_of"]) == me:
			return "Your club: the stash, the books"
		if int(b["hq_of"]) >= 0:
			return "%s (the %s family)" % [b["name"], Game.fam(int(b["hq_of"]))["name"]]
	return "%s  ·  %s" % [b["name"], b["owner_name"]]
