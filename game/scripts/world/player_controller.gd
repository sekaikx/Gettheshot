class_name PlayerController
extends Node
## Your hands on the street. Walks your boss (or drives the truck), finds what you're next to,
## shows the prompt over it, and asks the host to act.
##   WASD / arrows move (screen directions) · Shift run · Alt walk slowly
##   E talk / use · F or left click punch (or smash what's in front of you) · G or right click shoot
##   R send your men at who you face · V get in / out of the truck · Q drop a crate
##   Tab family · M the city · J the country · N the paper · H how to play · Esc pause
## With the mouse, you face the pointer while you stand still (aim).

var world: World
var focus := {}          # what E would use: {type, id, key, label, pos}
var auto_move := Vector2.ZERO   # autotest: pretend the stick is held
var _punch_cd := 0.0
var _shoot_cd := 0.0
var _mouse_t := 0.0
var _last_mouse := Vector2.ZERO


func _physics_process(delta: float) -> void:
	_punch_cd = maxf(0.0, _punch_cd - delta)
	_shoot_cd = maxf(0.0, _shoot_cd - delta)
	_mouse_t = maxf(0.0, _mouse_t - delta)
	var a := world.local_actor
	if a == null:
		return
	var busy: bool = world.hud.is_modal() or world.hud.in_jail()
	if world.local_vehicle:
		var v := world.local_vehicle
		var th := 0.0
		var tu := 0.0
		if not busy:
			th = float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)) - float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN))
			tu = float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT))
		v.drive(delta, th, tu, Input.is_key_pressed(KEY_SPACE) and not busy)
		a.position = v.position
		focus = {}
		world.hud.set_prompt("Get out" + ("  ·  %d crates in the back" % v.load if v.load > 0 else ""), v.position, "V")
		return
	if a.is_down() or busy:
		a.velocity = Vector2.ZERO
		if a.is_down():
			world.hud.set_prompt("")
		return
	var inp := Vector2(float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)),
		float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)))
	if auto_move != Vector2.ZERO:
		inp = auto_move
	if inp.length() > 1.0:
		inp = inp.normalized()
	var spd := Actor.RUN * 0.72
	if Input.is_key_pressed(KEY_SHIFT):
		spd = Actor.SPRINT
	if Input.is_key_pressed(KEY_ALT):
		spd = Actor.WALK
	if a.lot >= 0 and not Input.is_key_pressed(KEY_SHIFT):
		spd = minf(spd, Actor.WALK * 1.4)
	if a.carrying:
		spd = minf(spd, 2.1 * W.M)
	a.velocity = inp * spd
	# aim at the mouse while standing still
	if inp == Vector2.ZERO and _mouse_t > 0.0:
		var m := world.get_global_mouse_position()
		a.yaw = lerp_angle(a.yaw, (m - a.position).angle(), clampf(delta * 14.0, 0.0, 1.0))
	_find_focus(a)


func _unhandled_input(e: InputEvent) -> void:
	var hud = world.hud
	if e is InputEventMouseMotion:
		if (e as InputEventMouseMotion).relative.length() > 2.0:
			_mouse_t = 2.5
		return
	if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and not hud.is_modal():
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_mouse_t = 2.5
			_punch()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_mouse_t = 2.5
			_face_mouse()
			_shoot()
		return
	if not (e is InputEventKey) or not e.pressed or e.echo:
		return
	var k := (e as InputEventKey).keycode
	if k == KEY_ESCAPE:
		hud.escape()
		return
	if hud.is_modal():
		hud.modal_key(k)
		return
	match k:
		KEY_TAB: hud.toggle_family()
		KEY_M: hud.toggle_map()
		KEY_J: hud.toggle_nation()
		KEY_N: hud.show_newspaper(-1)
		KEY_H, KEY_F1: hud.toggle_help()
	var a := world.local_actor
	if a == null or a.is_down() or hud.in_jail():
		return
	if world.local_vehicle:
		if k == KEY_V or k == KEY_E:
			Net.to_host("exit", [])
		return
	match k:
		KEY_E: _use()
		KEY_F: _punch()
		KEY_G:
			if _mouse_t > 0.0:
				_face_mouse()
			_shoot()
		KEY_R:
			var t := _target_in_front(a, 12.0 * W.M)
			if t:
				Net.to_host("sic", [t.key])
			else:
				hud.toast("Face someone first, then press R to send your men at him.", "info")
		KEY_V:
			var v := _near_vehicle(a)
			if v:
				Net.to_host("enter", [v.key])
		KEY_Q:
			if a.carrying:
				Net.to_host("drop", [])


func _face_mouse() -> void:
	var a := world.local_actor
	if a:
		a.yaw = (world.get_global_mouse_position() - a.position).angle()
		a.person.rotation = a.yaw


func _punch() -> void:
	var a := world.local_actor
	if a == null or a.is_down() or world.local_vehicle or _punch_cd > 0.0:
		return
	_punch_cd = 0.5
	if _mouse_t > 0.0 and a.velocity == Vector2.ZERO:
		_face_mouse()
	a.person.action("punch")
	Net.to_host("punch", [])


func _shoot() -> void:
	var a := world.local_actor
	if a == null or a.is_down() or world.local_vehicle or _shoot_cd > 0.0:
		return
	_shoot_cd = 0.8
	a.person.action("shoot")
	Net.to_host("shoot", [])


func _use() -> void:
	var a := world.local_actor
	if focus.is_empty():
		return
	a.person.action("interact")
	match focus["type"]:
		"river":
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
				Net.to_host("truck_unload", [v.key])
			else:
				Net.to_host("enter", [v.key])
		"quick":
			Net.to_host("act", [focus["what"], focus["id"], 0])
		_:
			Talk.open(world, focus)


func _near_vehicle(a: Actor) -> Vehicle:
	var best: Vehicle = null
	var bd := 3.2 * W.M
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
	var fwd := a.forward()
	var best: Actor = null
	var bd := dist
	for o in world.actors.values():
		var ac := o as Actor
		if ac == a or ac.is_down() or not ac.visible or ac.family == a.family:
			continue
		var to := ac.position - a.position
		var d := to.length()
		if d < bd and fwd.dot(to / maxf(d, 0.01)) > 0.8:
			bd = d
			best = ac
	return best


## What E would act on: the nearest thing in reach. People first, then things in the room, then
## the truck, then the river.
func _find_focus(a: Actor) -> void:
	var best := {}
	var bd := 99999.0
	var p := a.position
	var reach := World.REACH
	for id in world.items:
		var c: Crate = world.items[id]
		var d := c.position.distance_to(p)
		if d < reach and d < bd:
			bd = d
			best = {"type": "item", "id": id, "pos": c.position, "label": ("Pick up the crate" if c.kind == "crate" else "Pick up $%d" % c.amount)}
	if best.is_empty():
		for o in world.actors.values():
			var ac := o as Actor
			if ac == a or ac.is_down() or not ac.visible or ac.hidden_in_car:
				continue
			var own := ac.kind == "crew" and ac.family == a.family
			var r := reach * (2.2 if ac.kind == "shop" else 1.3)
			if own:
				r = reach * 1.6
			# only people in the same room (or both outside)
			if ac.lot != a.lot:
				continue
			var d := ac.position.distance_to(p) + (0.6 * W.M if own else 0.0)
			if d < r and d < bd:
				var lab := _actor_label(ac)
				if lab != "":
					bd = d
					best = {"type": "actor", "key": ac.key, "kind": ac.kind, "id": ac.ref_id, "pos": ac.position, "label": lab}
	if best.is_empty() and a.lot >= 0:
		var b: Dictionary = world.biz_at_lot(a.lot)
		var lay: Dictionary = world.layout_of_biz(int(b.get("id", -1)))
		if not lay.is_empty():
			for it in lay["items"]:
				var lab2 := _object_label(b, it)
				if lab2 == "":
					continue
				var r2: Rect2 = it["rect"]
				var q := Vector2(clampf(p.x, r2.position.x, r2.end.x), clampf(p.y, r2.position.y, r2.end.y))
				var d2 := q.distance_to(p)
				if d2 < reach and d2 < bd:
					bd = d2
					best = {"type": "object", "biz": b["id"], "item": it["type"], "id": it["id"], "pos": r2.get_center(), "label": lab2}
	if best.is_empty():
		for v in world.vehicles.values():
			var ve := v as Vehicle
			if not ve.key.begins_with("t") or ve.driver != 0:
				continue
			var d3 := ve.position.distance_to(p)
			if d3 < 3.0 * W.M and d3 < bd:
				bd = d3
				var mine := ve.family == a.family
				var lab3 := "Put the crate on the truck" if a.carrying else ("Take a crate off the truck (%d)" % ve.load if ve.load > 0 and mine else "Drive the %s truck" % ("family" if mine else Game.fam(ve.family).get("name", "") + " family's"))
				best = {"type": "truck", "key": ve.key, "pos": ve.position, "label": lab3}
	if best.is_empty() and world._near_river(p):
		var guns: Array = Game.fam(a.family).get("evidence", []).filter(func(e: Dictionary) -> bool: return e["kind"] == "weapon")
		if not guns.is_empty():
			best = {"type": "river", "pos": p, "label": "Throw the gun in the river (it's evidence)"}
	focus = best
	if a.carrying and best.is_empty():
		world.hud.set_prompt("Carrying a crate  ·  Q to drop it", a.position, "")
	elif best.is_empty():
		world.hud.set_prompt("")
	else:
		world.hud.set_prompt(String(best["label"]), best.get("pos", Vector2.INF), "E")


func _object_label(b: Dictionary, it: Dictionary) -> String:
	var me := world.local_actor.family
	match String(it["type"]):
		"safe":
			if int(b.get("hq_of", -1)) == me:
				return "Open the safe"
			if int(b.get("hq_of", -1)) >= 0:
				return "Crack the %s family's safe" % Game.fam(int(b["hq_of"])).get("name", "")
		"desk":
			if int(b.get("hq_of", -1)) == me:
				return "Sit at your desk"
		"map_table":
			if int(b.get("hq_of", -1)) == me:
				return "Look at the map"
		"phone":
			if int(b.get("hq_of", -1)) == me:
				var n := Game.deals.filter(func(d: Dictionary) -> bool: return int(d["to"]) == me).size()
				return "Use the telephone" + ("  ·  %d call%s waiting" % [n, "" if n == 1 else "s"] if n > 0 else "")
		"register":
			if int(b["owned_by"]) != me and b["kind"] not in ["precinct", "club", "warehouse"] and not (b.get("broken", []) as Array).has(int(it["id"])):
				return "Empty the till"
	return ""


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
		"shop":
			var b := Game.biz_by_id(ac.ref_id)
			if b.is_empty():
				return ""
			if b["kind"] == "precinct":
				return "Talk to the desk sergeant"
			if b["kind"] == "club":
				return "Talk to the bartender"
			if b["kind"] == "warehouse":
				return "Talk to the watchman"
			if int(b["protector"]) == world.local_actor.family and int(b["envelope"]) > 0:
				return "Collect from %s  ·  $%d" % [b["owner_name"], int(b["envelope"])]
			return "Talk to %s" % b["owner_name"]
		"smuggler":
			return "Talk to the man from the boat" if ac.visible else ""
		"dealer":
			return "Talk to Izzy (he sells guns)"
		"unionboss":
			return "Talk to %s, the union boss" % Game.UNION_BOSS
		"newsboy":
			return "Buy a paper"
		"docker":
			return "Talk to the longshoreman"
		"ped":
			return "Talk"
	return ""
