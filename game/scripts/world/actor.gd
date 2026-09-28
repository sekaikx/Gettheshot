class_name Actor
extends CharacterBody2D
## Anyone on the street or in a shop: a player's boss, a crewman, a cop, a pedestrian, a
## shopkeeper, a man looking for work at the pool hall, an AI family's boss, the arms dealer, the
## smuggler, a longshoreman. On the host the brains run here (think()); clients only draw what the
## host's snapshots say. A player's own boss is moved by its owner (PlayerController) and sent to
## the host as a pose.
##
## Positions are world pixels (W.M per metre). yaw 0 = facing east (+x).

const WALK := 1.35 * W.M
const RUN := 3.9 * W.M
const SPRINT := 5.6 * W.M
const RADIUS := 0.28 * W.M

var world: Node          # World
var key := ""
var kind := ""           # boss, aiboss, crew, cop, ped, shop, recruit, smuggler, dealer, unionboss, docker, newsboy
var family := -1
var ref_id := -1
var person: Person2D
var hp := 100.0
var tough := 60
var down_t := 0.0
var dead := false
var carrying := false
var sim := false         # this machine moves it (host AI, or the local player)
var is_local_player := false
var yaw := 0.0
var speed := 0.0         # px/s
var state: int = Person2D.Anim.IDLE
var hidden_in_car := false
var lot := -1            # the lot it's standing in (-1 = outside)

# host brain
var goal := Vector2.INF
var path: PackedVector2Array = []
var path_i := 0
var wait_t := 0.0
var chase: Actor = null
var chase_t := 0.0
var attack_target: Actor = null
var cooldown := 0.0
var scared_t := 0.0
var scared_from := Vector2.ZERO
var home := Vector2.ZERO
var home_yaw := 0.0
var order: Dictionary = {}
var last_attacker: Actor = null
var last_attacked_t := 0.0
var talk_t := 0.0
var route: Array = []    # longshoremen: a loop of points (pier, quay edge, the pile, quay edge)
var route_i := 0
var attack_target_hint: Actor = null   # players point at someone (R); the crew following them pile in
var _stuck_t := 0.0
var _stuck_at := Vector2.ZERO
var _lot_t := 0.0
var _dwell := 0.0

# network smoothing
var net_pos := Vector2.ZERO
var net_yaw := 0.0
var _net_have := false


func setup(w: Node, k: String, kd: String, look: int, color: Color, extra: Dictionary = {}) -> void:
	world = w
	key = k
	kind = kd
	name = k
	z_index = W.Z_PEOPLE
	collision_layer = 2
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = RADIUS
	cs.shape = c
	add_child(cs)
	person = Person2D.new()
	add_child(person)
	person.setup(kd, look, color, extra)


func place(p: Vector2, y: float = 0.0) -> void:
	position = p
	yaw = y
	person.rotation = yaw
	net_pos = position
	net_yaw = yaw
	home = position
	home_yaw = y
	velocity = Vector2.ZERO
	path = []
	lot = world.lot_at(position) if world else -1


func _physics_process(delta: float) -> void:
	if dead:
		return
	if down_t > 0.0:
		down_t -= delta
		velocity = Vector2.ZERO
		if down_t <= 0.0:
			_stand_up()
		return
	if sim:
		if not is_local_player and Net.is_host():
			think(delta)
		move_and_slide()
		speed = velocity.length()
		if speed > 8.0:
			yaw = lerp_angle(yaw, velocity.angle(), clampf(delta * 12.0, 0.0, 1.0))
		person.rotation = yaw
		state = _anim_for_speed()
		person.set_motion(state, speed / W.M)
	else:
		if _net_have:
			position = position.lerp(net_pos, clampf(delta * 12.0, 0.0, 1.0))
			if position.distance_to(net_pos) > 6.0 * W.M:
				position = net_pos
			yaw = lerp_angle(yaw, net_yaw, clampf(delta * 12.0, 0.0, 1.0))
			person.rotation = yaw
		person.set_motion(state, speed / W.M)
	_lot_t -= delta
	if _lot_t <= 0.0:
		_lot_t = 0.2
		lot = world.lot_at(position)


func _anim_for_speed() -> int:
	if talk_t > 0.0 and speed < 10.0:
		return Person2D.Anim.TALK
	if carrying:
		return Person2D.Anim.CARRY
	if speed > 2.6 * W.M:
		return Person2D.Anim.RUN
	if speed > 10.0:
		return Person2D.Anim.WALK
	if kind in ["recruit", "unionboss"] or (kind == "docker" and route.is_empty()):
		return Person2D.Anim.ARMS
	if kind == "aiboss":
		return Person2D.Anim.TALK
	return Person2D.Anim.IDLE


func net_update(p: Vector2, y: float, st: int, sp: float, carry: bool) -> void:
	net_pos = p
	net_yaw = y
	if not _net_have:
		position = p
		yaw = y
		person.rotation = y
		_net_have = true
	speed = sp
	if carry != carrying:
		carrying = carry
		person.carry(carry)
	if st == Person2D.Anim.DOWN and state != Person2D.Anim.DOWN:
		person.action("down")
	elif st == Person2D.Anim.DEAD and state != Person2D.Anim.DEAD:
		person.action("die")
	elif state in [Person2D.Anim.DOWN, Person2D.Anim.DEAD] and st not in [Person2D.Anim.DOWN, Person2D.Anim.DEAD]:
		person.play(st)
	state = st


func set_carry(on: bool) -> void:
	carrying = on
	person.carry(on)


func is_down() -> bool:
	return down_t > 0.0 or dead


func forward() -> Vector2:
	return Vector2.from_angle(yaw)


# ------------------------------------------------------------------ combat (host)

func hurt(dmg: float, from: Actor, lethal: bool = false) -> void:
	if dead or down_t > 0.0:
		return
	hp -= dmg
	last_attacker = from
	last_attacked_t = 2.0
	world.fx_all("hit", [key])
	if hp <= 0.0:
		if lethal and kind != "boss":
			die(from)
		else:
			knock_down(12.0 if lethal else 9.0)
	elif kind in ["ped", "shop", "newsboy"]:
		scare(from.position if from else position, 8.0)
	elif kind == "debtor":
		scare(from.position if from else position, 4.0)
	elif kind in ["crew", "cop", "recruit", "aiboss", "docker", "unionboss", "thug"] and from and from != self and attack_target == null:
		attack_target = from
	if kind == "shop" and from:
		world.shopkeeper_hurt(self, from, hp <= 0.0)


func knock_down(t: float) -> void:
	down_t = t * world.down_time_mult(self)
	velocity = Vector2.ZERO
	state = Person2D.Anim.DOWN
	if carrying:
		carrying = false
		person.carry(false)
		world.drop_item("crate", position, 1)
	person.action("down")
	world.on_knocked_down(self)


func _stand_up() -> void:
	hp = 60.0
	state = Person2D.Anim.IDLE
	person.play(Person2D.Anim.IDLE)
	attack_target = null
	chase = null


func die(from: Actor) -> void:
	dead = true
	state = Person2D.Anim.DEAD
	velocity = Vector2.ZERO
	person.action("die")
	collision_layer = 0
	world.on_killed(self, from)


func scare(from: Vector2, t: float) -> void:
	scared_t = t
	scared_from = from


# ------------------------------------------------------------------ brains (host)

func think(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	last_attacked_t = maxf(0.0, last_attacked_t - delta)
	talk_t = maxf(0.0, talk_t - delta)
	if attack_target and (not is_instance_valid(attack_target) or attack_target.is_down() or attack_target.hidden_in_car):
		attack_target = null
	if attack_target:
		_fight(delta)
		return
	match kind:
		"ped", "newsboy": _think_ped(delta)
		"cop": _think_cop(delta)
		"crew": _think_crew(delta)
		"shop": _think_shop(delta)
		"thug": _think_thug(delta)
		"debtor": _think_debtor(delta)
		"recruit", "aiboss", "unionboss", "dealer": _think_stand(delta)
		"docker": _think_docker(delta)
		_: velocity = Vector2.ZERO


func _fight(_delta: float) -> void:
	var to := attack_target.position - position
	var d := to.length()
	if d > 25.0 * W.M:
		attack_target = null
		velocity = Vector2.ZERO
		return
	if kind == "crew" and d > 2.5 * W.M and d < 12.0 * W.M and cooldown <= 0.0 and randf() < 0.5 \
			and String(Game.crew_by_id(ref_id).get("trait", "")) == "shooter":
		cooldown = randf_range(1.4, 2.2)
		velocity = Vector2.ZERO
		world.crew_shoot(self, attack_target)
		return
	if d > 1.05 * W.M:
		_steer_to(attack_target.position, RUN)
	else:
		velocity = Vector2.ZERO
		yaw = to.angle()
		if cooldown <= 0.0:
			cooldown = randf_range(0.9, 1.4)
			person.action("punch")
			world.melee(self, attack_target)


## Walk the current path. Returns true when it's done.
func _follow_path(spd: float) -> bool:
	if path_i >= path.size():
		velocity = Vector2.ZERO
		return true
	var t := path[path_i]
	var to := t - position
	if to.length() < 0.35 * W.M:
		path_i += 1
		return path_i >= path.size()
	velocity = to.normalized() * spd
	_unstick(0.0)
	return false


## Head for a point directly (short distances, same room), re-planning if something is in the way.
func _steer_to(p: Vector2, spd: float) -> void:
	if world.lot_at(p) != lot or position.distance_to(p) > 10.0 * W.M:
		if goal.distance_to(p) > 1.0 * W.M or path_i >= path.size():
			go_to(p)
		_follow_path(spd)
		return
	velocity = (p - position).normalized() * spd


func go_to(p: Vector2) -> void:
	path = world.route(position, p)
	path_i = 0
	goal = p


## Stuck against something for a while: skip a waypoint.
func _unstick(delta: float) -> void:
	_stuck_t += get_physics_process_delta_time() if delta == 0.0 else delta
	if _stuck_t > 2.0:
		if position.distance_to(_stuck_at) < 0.3 * W.M and path_i < path.size():
			path_i += 1
		_stuck_t = 0.0
		_stuck_at = position


func _run_from(from: Vector2) -> void:
	var away := position - from
	velocity = (away.normalized() if away.length() > 1.0 else Vector2.RIGHT) * RUN
	path = []


func _think_ped(delta: float) -> void:
	if scared_t > 0.0:
		scared_t -= delta
		_run_from(scared_from)
		return
	if wait_t > 0.0:
		wait_t -= delta
		velocity = Vector2.ZERO
		return
	if path_i >= path.size():
		if lot >= 0:
			if _dwell > 0.0:
				# in the shop: look around, chat at the counter
				wait_t = _dwell
				talk_t = _dwell * 0.6
				_dwell = 0.0
				return
			# done shopping: back out to the street
			var n2: int = randi() % world.plan.nodes.size()
			go_to(W.pa(world.plan.nodes[n2]))
			return
		if kind == "ped" and randf() < 0.3:
			var b: Dictionary = world.shop_near(position, 30.0 * W.M)
			if not b.is_empty():
				var lay: Dictionary = world.layout_of_biz(int(b["id"]))
				var room: Rect2 = (lay["shop"] as Rect2).grow(-0.8 * W.M)
				go_to(world.talk_spot(int(b["id"])).lerp(room.get_center(), randf_range(0.2, 0.8)))
				_dwell = randf_range(4.0, 9.0)
				return
		var n: int = randi() % world.plan.nodes.size()
		go_to(W.pa(world.plan.nodes[n]) + Vector2(randf_range(-0.6, 0.6), randf_range(-0.6, 0.6)) * W.M)
		wait_t = randf_range(0.0, 3.0) if randf() < 0.4 else 0.0
		return
	_follow_path(WALK * (0.85 + (ref_id % 5) * 0.06))


func _think_cop(delta: float) -> void:
	if chase and is_instance_valid(chase) and not chase.dead:
		chase_t -= delta
		var to := chase.position - position
		if chase_t <= 0.0 or to.length() > 45.0 * W.M or chase.hidden_in_car:
			world.cop_gave_up(self, chase)
			chase = null
			return
		if to.length() < 1.1 * W.M:
			velocity = Vector2.ZERO
			world.cop_caught(self, chase)
			chase = null
			wait_t = 4.0
			talk_t = 4.0
			return
		_steer_to(chase.position, RUN * 1.05)
		return
	chase = null
	if wait_t > 0.0:
		wait_t -= delta
		velocity = Vector2.ZERO
		return
	if path_i >= path.size():
		var cop := Game.cop_by_id(ref_id)
		for tries in 12:
			var n: int = randi() % world.plan.nodes.size()
			var p: Vector2 = W.pa(world.plan.nodes[n])
			if cop.is_empty() or world.plan.district_at(p.x / W.M, p.y / W.M) == cop["district"]:
				go_to(p)
				break
		wait_t = randf_range(1.0, 5.0)
		return
	_follow_path(WALK * 0.9)


## Behind the counter. Scared people back away toward the back room; a hurt one cowers.
func _think_shop(delta: float) -> void:
	var b := Game.biz_by_id(ref_id)
	var fear := float(b.get("fear", 0.0))
	if scared_t > 0.0:
		scared_t -= delta
		var hide: Vector2 = world.shop_hide_spot(ref_id)
		if hide != Vector2.INF and position.distance_to(hide) > 0.4 * W.M:
			_steer_to(hide, RUN * 0.8)
		else:
			velocity = Vector2.ZERO
		return
	var dist := position.distance_to(home)
	if dist > 0.35 * W.M:
		_steer_to(home, WALK)
	else:
		velocity = Vector2.ZERO
		yaw = lerp_angle(yaw, home_yaw, 0.1)
	talk_t = 0.5 if fear > 60.0 else talk_t


## A longshoreman's day: take a crate off the boat at the pier, carry it to the pile on the quay,
## go back for the next one. The two at the shape-up just wait to be picked.
func _think_docker(delta: float) -> void:
	if scared_t > 0.0:
		scared_t -= delta
		_run_from(scared_from)
		return
	if route.is_empty():
		_think_stand(delta)
		return
	if wait_t > 0.0:
		wait_t -= delta
		velocity = Vector2.ZERO
		return
	var t: Vector2 = route[route_i % route.size()]
	var to := t - position
	if to.length() < 0.5 * W.M:
		velocity = Vector2.ZERO
		if route_i % route.size() == 0 and not carrying:
			set_carry(true)
			wait_t = randf_range(1.2, 2.6)
		elif route_i % route.size() == 2 and carrying:
			set_carry(false)
			wait_t = randf_range(0.8, 2.0)
			talk_t = wait_t if randf() < 0.3 else 0.0
		route_i = (route_i + 1) % route.size()
		_stuck_t = 0.0
		return
	velocity = to.normalized() * (WALK * 0.95 if carrying else WALK * 1.15)
	_stuck_t += delta
	if _stuck_t > 2.5:
		if position.distance_to(_stuck_at) < 0.5 * W.M:
			route_i = (route_i + 1) % route.size()
		_stuck_t = 0.0
		_stuck_at = position


## A rival's thug leaning on a shop for a favor: loiters by the door, fights anyone who comes close.
func _think_thug(delta: float) -> void:
	for a in world.actors.values():
		var ac := a as Actor
		if ac.kind in ["boss", "crew"] and ac.family != family and not ac.is_down() and not ac.hidden_in_car \
				and ac.position.distance_to(position) < 2.2 * W.M:
			attack_target = ac
			return
	_think_stand(delta)


## A man who owes money: stands around; runs when hit.
func _think_debtor(delta: float) -> void:
	if scared_t > 0.0:
		scared_t -= delta
		_run_from(scared_from)
		return
	_think_stand(delta)


func _think_stand(_delta: float) -> void:
	var to := home - position
	if to.length() > 0.4 * W.M:
		_steer_to(home, WALK)
	else:
		velocity = Vector2.ZERO
		yaw = lerp_angle(yaw, home_yaw, 0.1)


func _think_crew(delta: float) -> void:
	var c := Game.crew_by_id(ref_id)
	if c.is_empty():
		velocity = Vector2.ZERO
		return
	# an order in progress (an AI family's, or "take" from a player): walk to the owner, lean on him
	if not order.is_empty():
		var spot: Vector2 = world.talk_spot(int(order["biz"]))
		if position.distance_to(spot) < 0.7 * W.M:
			velocity = Vector2.ZERO
			yaw = (world.owner_pos(int(order["biz"])) - position).angle()
			if wait_t <= 0.0:
				wait_t = 3.0
				talk_t = 3.0
				person.action("threaten")
			else:
				wait_t -= delta
				if wait_t <= 0.0:
					world.resolve_order(self, order)
					order = {}
					path = []
			return
		if goal.distance_to(spot) > 0.8 * W.M or path_i >= path.size():
			go_to(spot)
		_follow_path(WALK * 1.3)
		return
	# defend the family's people
	var threat = world.threat_near(self, 9.0 * W.M)
	if threat:
		attack_target = threat
		return
	match c["task"]:
		"follow":
			var leader: Actor = world.actor("p" + String(c["leader"]))
			if leader == null or leader.hidden_in_car:
				_go_home_idle()
				return
			if leader.attack_target_hint and is_instance_valid(leader.attack_target_hint) and not leader.attack_target_hint.is_down():
				attack_target = leader.attack_target_hint
				return
			var slot: Vector2 = world.follow_slot(self, leader)
			var d := position.distance_to(slot)
			if d > 0.6 * W.M:
				_steer_to(slot, RUN if d > 5.0 * W.M else WALK * 1.3)
			else:
				velocity = Vector2.ZERO
				yaw = lerp_angle(yaw, leader.yaw, 0.1)
		"guard":
			var b := Game.biz_by_id(int(c["target"]))
			if b.is_empty():
				_go_home_idle()
				return
			_stand_at(W.door(b) + world.guard_offset(ref_id, b), W.facing_out(float(b["yaw"])))
		"booze":
			var wh := Game.nyc_warehouse(family)
			if wh.is_empty():
				_go_home_idle()
				return
			var f := W.front_dir(float(wh["yaw"]))
			_stand_at(W.door(wh) + f.orthogonal() * (1.6 + (ref_id % 3) * 0.7) * W.M, f.angle())
		"collect":
			if path_i >= path.size():
				if wait_t > 0.0:
					wait_t -= delta
					velocity = Vector2.ZERO
					return
				var t := Game.biz_by_id(int(c["target"]))
				var shops := Game.shops_of(family).filter(func(x: Dictionary) -> bool:
					return t.is_empty() or x["district"] == t["district"])
				if shops.is_empty():
					_go_home_idle()
					return
				var s: Dictionary = shops[randi() % shops.size()]
				go_to(W.door(s))
				wait_t = 2.5
			else:
				_follow_path(WALK * 1.1)
		_:
			_go_home_idle()


func _go_home_idle() -> void:
	var hq := Game.biz_by_id(int(Game.fam(family).get("hq", -1)))
	if hq.is_empty():
		velocity = Vector2.ZERO
		return
	var spot: Vector2 = world.club_spot(family, ref_id)
	_stand_at(spot, W.facing_out(float(hq["yaw"])))


func _stand_at(p: Vector2, face_yaw: float) -> void:
	var d := position.distance_to(p)
	if d > 0.35 * W.M:
		_steer_to(p, RUN * 0.8 if d > 12.0 * W.M else WALK)
	else:
		velocity = Vector2.ZERO
		path = []
		yaw = lerp_angle(yaw, face_yaw, 0.08)
