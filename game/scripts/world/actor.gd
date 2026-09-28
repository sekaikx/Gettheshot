class_name Actor
extends CharacterBody3D
## Anyone walking the streets: a player's boss, a crewman, a cop, a pedestrian, a man looking for
## work at the pool hall, an AI family's boss. On the host the AI brains run here (think());
## clients only draw what the host's snapshots say. A player's own boss is moved by its owner
## (PlayerController) and sent to the host as a pose.

const WALK := 1.35
const RUN := 3.9
const SPRINT := 5.6

var world: Node          # World
var key := ""
var kind := ""           # boss, crew, cop, ped, recruit, aiboss
var family := -1
var ref_id := -1
var person: Person
var hp := 100.0
var tough := 60
var down_t := 0.0
var dead := false
var carrying := false
var sim := false         # this machine moves it (host AI, or the local player)
var is_local_player := false
var yaw := 0.0
var speed := 0.0
var state := Person.Anim.IDLE
var hidden_in_car := false

# host brain
var goal := Vector3.ZERO
var path: PackedVector3Array = []
var path_i := 0
var wait_t := 0.0
var chase: Actor = null
var chase_t := 0.0
var attack_target: Actor = null
var attack_t := 0.0
var cooldown := 0.0
var scared_t := 0.0
var scared_from := Vector3.ZERO
var home := Vector3.ZERO
var home_yaw := 0.0
var order: Dictionary = {}
var last_attacker: Actor = null
var last_attacked_t := 0.0
var talk_t := 0.0

# network smoothing
var net_pos := Vector3.ZERO
var net_yaw := 0.0
var _net_have := false


func setup(w: Node, k: String, kd: String, look: int, color: Color, body: String = "") -> void:
	world = w
	key = k
	kind = kd
	name = k
	collision_layer = 2
	collision_mask = 1
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.7
	cs.shape = cap
	cs.position.y = 0.85
	add_child(cs)
	person = Person.new()
	add_child(person)
	var pk := kd
	if kd == "aiboss":
		pk = "boss"
	person.setup(pk, look, color, body)


func place(p: Vector3, y: float = 0.0) -> void:
	position = Vector3(p.x, 0.16 if _on_sidewalk(p) else 0.0, p.z)
	yaw = y
	rotation.y = yaw
	net_pos = position
	net_yaw = yaw
	home = position
	home_yaw = y


func _on_sidewalk(p: Vector3) -> bool:
	if world == null or world.plan == null:
		return false
	for b in world.plan.blocks:
		var r: Array = b["rect"]
		if p.x > r[0] and p.x < r[2] and p.z > r[1] and p.z < r[3]:
			return true
	var q: Array = world.plan.quay_rect
	return p.x > q[0] and p.x < q[2] + 30.0


func _physics_process(delta: float) -> void:
	if dead:
		return
	if down_t > 0.0:
		down_t -= delta
		velocity = Vector3.ZERO
		if down_t <= 0.0:
			_stand_up()
		return
	if sim:
		if not is_local_player and Net.is_host():
			think(delta)
		move_and_slide()
		position.y = move_toward(position.y, 0.16 if _on_sidewalk(position) else 0.0, delta * 2.0)
		var v := Vector2(velocity.x, velocity.z)
		speed = v.length()
		if speed > 0.2:
			var target := atan2(velocity.x, velocity.z)
			yaw = lerp_angle(yaw, target, clampf(delta * 10.0, 0.0, 1.0))
		rotation.y = yaw
		state = _anim_for_speed()
		person.set_motion(state, speed)
	else:
		if _net_have:
			position = position.lerp(net_pos, clampf(delta * 12.0, 0.0, 1.0))
			if position.distance_to(net_pos) > 6.0:
				position = net_pos
			rotation.y = lerp_angle(rotation.y, net_yaw, clampf(delta * 12.0, 0.0, 1.0))
			yaw = rotation.y
		person.set_motion(state, speed)


func _anim_for_speed() -> int:
	if talk_t > 0.0 and speed < 0.2:
		return Person.Anim.TALK
	if carrying:
		return Person.Anim.CARRY
	if speed > 2.6:
		return Person.Anim.RUN
	if speed > 0.2:
		return Person.Anim.WALK
	if kind == "recruit":
		return Person.Anim.ARMS
	if kind == "aiboss":
		return Person.Anim.TALK
	return Person.Anim.IDLE


func net_update(p: Vector3, y: float, st: int, sp: float, carry: bool) -> void:
	net_pos = p
	net_yaw = y
	if not _net_have:
		position = p
		rotation.y = y
		_net_have = true
	speed = sp
	if carry != carrying:
		carrying = carry
		person.carry(carry)
	if st == Person.Anim.DOWN and state != Person.Anim.DOWN:
		person.action("down")
	elif st == Person.Anim.DEAD and state != Person.Anim.DEAD:
		person.action("die")
	elif state in [Person.Anim.DOWN, Person.Anim.DEAD] and st not in [Person.Anim.DOWN, Person.Anim.DEAD]:
		person.play(st)
	state = st


func set_carry(on: bool) -> void:
	carrying = on
	person.carry(on)


func is_down() -> bool:
	return down_t > 0.0 or dead


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
	elif kind == "ped":
		scare(from.position if from else position, 8.0)
	elif kind in ["crew", "cop", "recruit", "aiboss"] and from and from != self and attack_target == null:
		attack_target = from


func knock_down(t: float) -> void:
	down_t = t
	velocity = Vector3.ZERO
	state = Person.Anim.DOWN
	if carrying:
		carrying = false
		person.carry(false)
		world.drop_item("crate", position, 1)
	person.action("down")
	world.on_knocked_down(self)


func _stand_up() -> void:
	hp = 60.0
	state = Person.Anim.IDLE
	person.play(Person.Anim.IDLE)
	attack_target = null
	chase = null


func die(from: Actor) -> void:
	dead = true
	state = Person.Anim.DEAD
	velocity = Vector3.ZERO
	person.action("die")
	collision_layer = 0
	world.on_killed(self, from)


func scare(from: Vector3, t: float) -> void:
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
		"ped": _think_ped(delta)
		"cop": _think_cop(delta)
		"crew": _think_crew(delta)
		"recruit", "aiboss": _think_stand(delta)
		_: velocity = Vector3.ZERO


func _fight(delta: float) -> void:
	var to := attack_target.position - position
	to.y = 0.0
	var d := to.length()
	if d > 25.0:
		attack_target = null
		velocity = Vector3.ZERO
		return
	if d > 1.25:
		velocity = to / d * RUN
	else:
		velocity = Vector3.ZERO
		yaw = atan2(to.x, to.z)
		if cooldown <= 0.0:
			cooldown = randf_range(0.9, 1.4)
			world.melee(self, attack_target)


func _follow_path(spd: float) -> bool:
	if path_i >= path.size():
		velocity = Vector3.ZERO
		return true
	var t := path[path_i]
	var to := Vector3(t.x - position.x, 0, t.z - position.z)
	if to.length() < 0.6:
		path_i += 1
		return path_i >= path.size()
	velocity = to.normalized() * spd
	return false


func go_to(p: Vector3) -> void:
	path = world.plan.path(position, p)
	path_i = 0
	goal = p


func _think_ped(delta: float) -> void:
	if scared_t > 0.0:
		scared_t -= delta
		var away := position - scared_from
		away.y = 0.0
		velocity = (away.normalized() if away.length() > 0.1 else Vector3.FORWARD) * RUN
		path = []
		return
	if wait_t > 0.0:
		wait_t -= delta
		velocity = Vector3.ZERO
		return
	if path_i >= path.size():
		var n = randi() % world.plan.nodes.size()
		go_to(world.plan.node_pos(n) + Vector3(randf_range(-1.0, 1.0), 0, randf_range(-1.0, 1.0)))
		wait_t = randf_range(0.0, 3.0) if randf() < 0.4 else 0.0
		return
	_follow_path(WALK * (0.85 + (ref_id % 5) * 0.06))


func _think_cop(delta: float) -> void:
	if chase and is_instance_valid(chase) and not chase.dead:
		chase_t -= delta
		var to := chase.position - position
		to.y = 0.0
		if chase_t <= 0.0 or to.length() > 45.0 or chase.hidden_in_car:
			world.cop_gave_up(self, chase)
			chase = null
			return
		if to.length() < 1.5:
			velocity = Vector3.ZERO
			world.cop_caught(self, chase)
			chase = null
			wait_t = 4.0
			talk_t = 4.0
			return
		velocity = to.normalized() * (RUN * 1.05)
		return
	chase = null
	if wait_t > 0.0:
		wait_t -= delta
		velocity = Vector3.ZERO
		return
	if path_i >= path.size():
		var cop := Game.cop_by_id(ref_id)
		var tries := 0
		while tries < 12:
			var n = randi() % world.plan.nodes.size()
			var p = world.plan.node_pos(n)
			if cop.is_empty() or world.plan.district_at(p.x, p.z) == cop["district"]:
				go_to(p)
				break
			tries += 1
		wait_t = randf_range(1.0, 5.0)
		return
	_follow_path(WALK * 0.9)


func _think_stand(_delta: float) -> void:
	var to := home - position
	to.y = 0.0
	if to.length() > 0.5:
		velocity = to.normalized() * WALK
	else:
		velocity = Vector3.ZERO
		yaw = lerp_angle(yaw, home_yaw, 0.1)


func _think_crew(delta: float) -> void:
	var c := Game.crew_by_id(ref_id)
	if c.is_empty():
		velocity = Vector3.ZERO
		return
	var f := Game.fam(family)
	# an AI order in progress: walk to the shop, lean on it, come back
	if not order.is_empty():
		var b := Game.biz_by_id(int(order["biz"]))
		var door := Vector3(b["door"][0], 0, b["door"][1])
		if position.distance_to(door) < 1.6:
			velocity = Vector3.ZERO
			if wait_t <= 0.0:
				wait_t = 2.5
				talk_t = 2.5
			else:
				wait_t -= delta
				if wait_t <= 0.0:
					world.resolve_order(self, order)
					order = {}
					path = []
			return
		if path_i >= path.size() or goal.distance_to(door) > 1.0:
			go_to(door)
		_follow_path(WALK * 1.2)
		return
	# defend the family's people
	var threat = world.threat_near(self, 9.0)
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
			var slot = world.follow_slot(self, leader)
			var to = slot - position
			to.y = 0.0
			var d = to.length()
			if d > 1.0:
				velocity = to / d * (RUN if d > 5.0 else WALK * 1.3)
			else:
				velocity = Vector3.ZERO
				yaw = lerp_angle(yaw, leader.yaw, 0.1)
		"guard":
			var b := Game.biz_by_id(int(c["target"]))
			if b.is_empty():
				_go_home_idle()
				return
			_stand_at(Vector3(b["door"][0], 0, b["door"][1]) + world.guard_offset(ref_id), float(b["yaw"]))
		"collect":
			if path_i >= path.size():
				var shops := Game.shops_of(family).filter(func(x: Dictionary) -> bool:
					var t := Game.biz_by_id(int(c["target"]))
					return t.is_empty() or x["district"] == t["district"])
				if shops.is_empty():
					_go_home_idle()
					return
				var s: Dictionary = shops[randi() % shops.size()]
				go_to(Vector3(s["door"][0], 0, s["door"][1]))
				wait_t = 2.0
			elif wait_t > 0.0 and velocity.length() < 0.1 and path_i >= path.size() - 1:
				wait_t -= delta
			else:
				_follow_path(WALK * 1.1)
		_:
			_go_home_idle()
	if f.get("ai", false) and c["task"] == "guard":
		pass


func _go_home_idle() -> void:
	var c := Game.crew_by_id(ref_id)
	var hq := Game.biz_by_id(int(Game.fam(family).get("hq", -1)))
	if hq.is_empty():
		velocity = Vector3.ZERO
		return
	_stand_at(Vector3(hq["door"][0], 0, hq["door"][1]) + world.guard_offset(ref_id), float(hq["yaw"]))


func _stand_at(p: Vector3, face_yaw: float) -> void:
	var to := p - position
	to.y = 0.0
	var d := to.length()
	if d > 12.0:
		if path_i >= path.size() or goal.distance_to(p) > 1.0:
			go_to(p)
		_follow_path(RUN * 0.8)
	elif d > 0.4:
		velocity = to / d * WALK
		path = []
	else:
		velocity = Vector3.ZERO
		yaw = lerp_angle(yaw, face_yaw, 0.08)


## Players point at someone to rough up (R); the crew following them pile in.
var attack_target_hint: Actor = null
