class_name Person2D
extends Node2D
## A person seen from straight above, drawn procedurally (docs/REBUILD_2D.md, "Person2D").
##
## The node's rotation is where the person faces (0 = east, +x). Everything is drawn facing +x;
## the person's right hand is on +y. Light comes from the north-west in WORLD space, so the
## shadow (down-right) and the highlights on hats and shoulders are turned back by the node's
## rotation every time it draws.
## Size: shoulders about 0.55 m (26-28 px at W.M = 48, arms included).
##
## What they look like comes from PersonLook.decode(kind, look, family_color, extra), which
## Portrait uses too: the same seed gives the same man on the street and in the dialog.
##
## Drawing is split into cached layers so dozens of people stay cheap: the torso and the head
## (hat, hair) are child canvas items that redraw only when the look changes or the person turns
## more than ~7 degrees (the light on them moves); breathing, the shoulder twist of the walk, nods
## and the fall are just their transforms. Only the shadow, legs and arms redraw per frame, and only
## while walking or acting. An idle person costs no drawing at all; a dead one redraws the spreading
## pool a few times a second and then stops.
##
## The contract: setup(), set_motion(), action(), play(), carry(), set_weapon(). Added:
##   set_ring(color)     a soft ring on the ground (mark the player or your men); Color(0,0,0,0) = off
##   is_busy()           true while a one-shot action plays
##   lights()            the muzzle flash as a light dict for the World's lightmap ([] otherwise)
##   pose_at(st, act, t, stride, phase)   freeze on one frame (tests, the family book, cut-scenes)
## extra keys: "trade" (shopkeepers), "summer" (straw hats; default: June-August by Game.month),
##   "hat" / "hat_col" (pin a hat for a story character).
## While DOWN or DEAD, set_motion() with another state is ignored: call play(Anim.IDLE) to get up.

enum Anim {IDLE, WALK, RUN, CARRY, TALK, ARMS, DOWN, DEAD, SIT}

const ACT_LEN := {"punch": 0.34, "hit": 0.42, "shoot": 0.34, "yes": 0.72, "no": 0.8, "interact": 0.5,
	"pickup": 0.62, "smash": 0.56, "threaten": 1.3, "talk": 1.1}
const LIGHT := Vector2(-0.7071, -0.7071)     # toward the sun (north-west), world space
const SHADOW_OFF := Vector2(3.0, 4.0)        # people cast a small soft shadow down-right
const STEEL := Color("2b2d31")
const STEEL_HI := Color("6a6e76")
const WOOD := Color("6e4a30")
const BAT := Color("c9a46c")
const CRATE := Color("9c7c52")
const BLOOD := Color(0.2, 0.02, 0.025, 0.94)
const FLASH := Color(1.0, 0.92, 0.62)
const NONE := Color(0, 0, 0, 0)
const HEAD := Vector2(-0.3, 0.0)             # the head sits over the spine, behind the chest

var kind := "ped"          # boss, aiboss, crew, cop, ped, shop, recruit, smuggler, dealer, docker,
						   # unionboss, consigliere, bartender, patron, fed, newsboy, woman, kid
var look := 0              # seed: skin, clothes, hat, build all come from this
var family_color := Color(0, 0, 0, 0)
var extra := {}            # {"trade": "bakery"}, {"summer": true}, {"hat": "bowler"}: see above
var state: int = Anim.IDLE
var speed := 0.0           # metres a second, for the walk cycle
var carrying := false
var weapon := ""           # "", "pistol", "tommy", "bat"
var ring_color := Color(0, 0, 0, 0)   # optional ring on the ground (your men, the player)
var frozen := false        # stop animating (tests, posed figures)
var _t := 0.0
var _action := ""
var _action_t := 0.0

var _lk: Dictionary = {}
var _w := 1.0              # build: width and depth factors
var _dd := 1.0
var _hw := 10.0            # half shoulder width, px
var _front := 7.2
var _back := 6.4
var _k := 1.0              # overall scale (kids)
var _hs := 1.0             # head scale
var _skin := Color()
var _coat := Color()
var _sleeve := Color()
var _hat := ""
var _female := false
var _torso := PackedVector2Array()
var _seed_f := 0.0
var _variant := 0
var _phase := 0.0
var _stride := 0.0
var _down_t := 9.0
var _dead_t := 0.0
var _pool := PackedFloat32Array()
var _p_papers := false     # props, looked up once
var _p_hook := false
var _p_stick := false
var _p_garters := false
var _band := Color(0, 0, 0, 0)

# the pose, worked out before each draw
var _foot_l := Vector2.ZERO
var _foot_r := Vector2.ZERO
var _hand_l := Vector2.ZERO
var _hand_r := Vector2.ZERO
var _elbow_l := Vector2.INF
var _elbow_r := Vector2.INF
var _twist := 0.0
var _off := Vector2.ZERO
var _head_off := Vector2.ZERO
var _head_rot := 0.0
var _breath := 1.0
var _grip_r := ""          # "", "fist", "point", "open"
var _grip_l := ""
var _aim := false
var _flash := 0.0
var _smoke := 0.0
var _bat_ang := 0.0        # bat direction (radians) when swinging
var _bat_swing := false
var _impact := 0.0
var _crate := false
var _right_top := true     # which forearm is drawn on top (crossed arms)

# cached layers (children drawn after this node: torso, limbs, head)
enum {PART_BODY, PART_LIMBS, PART_HEAD}
var _ci: CanvasItem = self # where the draw calls go right now
var _parts: Array[Part] = []
var _cache_rot := INF      # the rotation the torso and head were drawn at
var _dirty := true
var _pool_t := 0.0         # time since the pool was last redrawn
var _stars_t := 0.0


## One cached layer of the person. Person2D decides when it redraws.
class Part extends Node2D:
	var person: Person2D
	var which := 0

	func _draw() -> void:
		person._draw_part(self, which)


func setup(k: String, lk: int, fam_color: Color = Color(0, 0, 0, 0), ex: Dictionary = {}) -> void:
	kind = k
	look = lk
	family_color = fam_color
	extra = ex
	_apply_look()
	_refresh()


## Called every frame by the Actor: the looping state and how fast it's moving.
## While down or dead, only play() (or set_motion with DOWN/DEAD) changes the state.
func set_motion(st: int, spd: float) -> void:
	speed = spd
	if st == state:
		return
	if state in [Anim.DOWN, Anim.DEAD] and st not in [Anim.DOWN, Anim.DEAD]:
		return
	if st == Anim.DOWN or st == Anim.DEAD:
		_enter_down(st)
	else:
		state = st
		_refresh(false)


## One-shot animations: "punch", "hit" (got hit), "shoot", "yes" (nod / cheer), "no" (head shake),
## "interact" (reach forward), "pickup", "down" (knocked down), "die", "smash" (swing at an object),
## "threaten" (point / grab), "talk" (gesture).
func action(what: String) -> void:
	if what == "down":
		if state != Anim.DOWN and state != Anim.DEAD:
			_enter_down(Anim.DOWN)
		return
	if what == "die":
		if state != Anim.DEAD:
			_enter_down(Anim.DEAD)
		return
	if state in [Anim.DOWN, Anim.DEAD] and what != "hit":
		return
	_action = what
	_action_t = 0.0
	_refresh(false)


## Return to a looping state after being down.
func play(st: int) -> void:
	if st == Anim.DOWN or st == Anim.DEAD:
		_enter_down(st)
		return
	var was_down := state in [Anim.DOWN, Anim.DEAD]
	state = st
	_action = ""
	_refresh(was_down)


func carry(on: bool) -> void:
	carrying = on
	_refresh(false)


func set_weapon(w: String) -> void:
	weapon = w
	_refresh(false)


## A soft ring on the ground under the person (the World can mark your men, or the player).
func set_ring(c: Color) -> void:
	ring_color = c
	queue_redraw()


## True while a one-shot action is playing.
func is_busy() -> bool:
	return _action != ""


## The muzzle flash as a light for the World's lightmap (empty when not firing).
func lights() -> Array:
	if _flash <= 0.0 or state in [Anim.DOWN, Anim.DEAD]:
		return []
	var muzzle := _muzzle_local()
	return [{"pos": to_global(muzzle * _k), "r": 110.0, "color": Color(1.0, 0.78, 0.45), "e": 1.3 * _flash,
		"shape": "round", "flicker": false}]


## Freeze on one frame: a state, optionally an action `t` seconds in, a stride phase (walking).
## For tests and posed figures (the family book, cut-scenes).
func pose_at(st: int, act: String = "", t: float = 0.0, stride: float = 0.0, phase: float = 0.0) -> void:
	frozen = true
	if _lk.is_empty():
		_apply_look()
	state = st
	_action = act
	_action_t = t
	_stride = stride
	_phase = phase
	if st == Anim.DOWN or st == Anim.DEAD:
		_down_t = t if act in ["down", "die"] else 9.0
		_dead_t = t if act == "die" else 30.0
		if act in ["down", "die"]:
			_action = ""
	_refresh()


func _enter_down(st: int) -> void:
	if state != Anim.DOWN and state != Anim.DEAD:
		_down_t = 0.0
	state = st
	_action = ""
	if st == Anim.DEAD:
		_dead_t = 0.0
	_refresh()


func _apply_look() -> void:
	_lk = PersonLook.decode(kind, look, family_color, extra)
	_w = float(_lk["w"])
	_dd = float(_lk["d"])
	_k = float(_lk["scale"])
	_hs = float(_lk["head"]) * 0.9
	_hw = 10.5 * _w
	_front = 8.2 * _dd
	_back = 6.3 * _dd
	_skin = _lk["skin"]
	_female = bool(_lk["female"])
	_hat = String(_lk["hat"])
	var coat: String = _lk["coat"]
	_coat = _lk["coat_col"]
	if coat in ["shirt", "vest"]:
		_coat = _lk["shirt"]
	elif coat == "flapper":
		_coat = _lk["coat_col"]
	_sleeve = _coat.darkened(0.06)
	if coat == "overcoat" or coat == "trench" or coat == "peacoat":
		_front += 0.8 * _dd
		_back += 1.0 * _dd
		_hw += 0.6
	_torso = _superellipse(_hw, _front, _back, 2.5, 28)
	_seed_f = float(absi(look) % 997) * 0.37
	_variant = (absi(look) >> 3) % 2
	var props: Array = _lk["props"]
	_p_papers = "papers" in props
	_p_hook = "hook" in props
	_p_stick = "nightstick" in props
	_p_garters = "garters" in props
	_band = _lk["armband"]
	_dirty = true
	_pool = PackedFloat32Array()
	for i in 4:
		_pool.append(Draw.hash01(look & 0xffff, i, 31) * TAU)


func _process(delta: float) -> void:
	if frozen:
		return
	_t += delta
	var target := 0.0
	if speed > 0.05 and state not in [Anim.DOWN, Anim.DEAD, Anim.SIT]:
		target = clampf(3.5 + speed * 4.4, 0.0, 17.0)
		if carrying or state == Anim.CARRY:
			target = minf(target, 8.0)
	var was_moving := _stride > 0.05
	_stride = move_toward(_stride, target, delta * 45.0)
	if _stride > 0.01 and speed > 0.05:
		# the phase moves with the distance travelled, so the planted foot stays put
		_phase = fmod(_phase + speed * W.M * delta / maxf(_stride, 3.0), TAU)
	var acting := _action != ""
	if _action != "":
		_action_t += delta
		if _action_t >= float(ACT_LEN.get(_action, 0.6)) + (0.2 if (_action == "shoot" and weapon == "tommy") else 0.0):
			_action = ""
	var lying := state == Anim.DOWN or state == Anim.DEAD
	if lying:
		_down_t += delta
		if state == Anim.DEAD:
			_dead_t += delta
	_ensure_parts()
	if absf(angle_difference(_grot(), _cache_rot)) > 0.12:
		_dirty = true
	var moving := _stride > 0.05
	var animating := moving or acting or was_moving or state == Anim.TALK or _dirty
	if lying:
		if _down_t < 0.5 or acting or _dirty:
			_place_parts()
	elif animating:
		_pose()
		_place_parts()
	else:
		_breath = 1.0 + 0.016 * sin(_t * 2.1 + _seed_f)
		_parts[PART_BODY].scale.y = _k * _breath
	if _dirty:
		_redraw_all()
		return
	if lying:
		_pool_t += delta
		_stars_t += delta
		if _down_t < 0.5 or acting:
			queue_redraw()
		elif state == Anim.DEAD and _dead_t < 14.0 and _pool_t >= 0.25:
			_pool_t = 0.0
			queue_redraw()
		if state == Anim.DOWN and _stars_t >= 0.08:
			_stars_t = 0.0
			_parts[PART_LIMBS].queue_redraw()
		return
	if moving or acting or was_moving:
		queue_redraw()
		_parts[PART_LIMBS].queue_redraw()
	elif state == Anim.TALK:
		_parts[PART_LIMBS].queue_redraw()


func _ensure_parts() -> void:
	if _parts.size() == 3:
		return
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for w in 3:
		var part := Part.new()
		part.person = self
		part.which = w
		part.name = ["Body", "Limbs", "Head"][w]
		add_child(part, false, Node.INTERNAL_MODE_FRONT)
		_parts.append(part)


## The facing in world space (works before the node is in the tree too).
func _grot() -> float:
	return global_rotation if is_inside_tree() else rotation


## Something changed: redraw every layer now (look, state), or only the moving ones.
func _refresh(all: bool = true) -> void:
	if _lk.is_empty():
		_apply_look()
	_ensure_parts()
	if all:
		_dirty = true
	if state != Anim.DOWN and state != Anim.DEAD:
		_pose()
	_place_parts()
	if _dirty:
		_redraw_all()
	else:
		queue_redraw()
		_parts[PART_LIMBS].queue_redraw()


func _redraw_all() -> void:
	_dirty = false
	_cache_rot = _grot()
	queue_redraw()
	for part in _parts:
		part.queue_redraw()


## The cached layers follow the pose through their transforms (no redraw).
func _place_parts() -> void:
	if _parts.size() != 3:
		return
	var k := _k
	var body: Part = _parts[PART_BODY]
	var head: Part = _parts[PART_HEAD]
	var limbs: Part = _parts[PART_LIMBS]
	limbs.scale = Vector2(k, k)
	if state == Anim.DOWN or state == Anim.DEAD:
		var f := maxf(smoothstep(0.0, 1.0, clampf(_down_t / 0.32, 0.0, 1.0)), 0.05)
		var fy := lerpf(0.65, 1.0, f)
		var jolt := Vector2.ZERO
		if _action == "hit":
			jolt = Vector2(-2.5, 1.0) * _bump(_action_t, 0.42, 0.2)
		body.position = jolt * k
		body.rotation = 0.0
		body.scale = Vector2(f * k, fy * k)
		head.visible = _hat != ""
		var fh := smoothstep(0.0, 1.0, clampf(_down_t / 0.45, 0.0, 1.0))
		var rest := Vector2(-36.0, 15.0) if _variant == 0 else Vector2(-33.0, -16.0)
		var rest_rot := 0.7 if _variant == 0 else -1.1
		head.position = (Vector2(1.0, 0.0).lerp(rest, fh) + Vector2(0.0, -6.0 * sin(fh * PI)) + jolt * 0.3) * k
		head.rotation = lerpf(0.0, rest_rot + (TAU if _variant == 0 else -TAU), fh)
		var hs := 1.0 + 0.25 * sin(fh * PI)
		head.scale = Vector2(hs * k, hs * k)
		return
	head.visible = true
	body.position = _off * k
	body.rotation = _twist
	body.scale = Vector2(k, k * _breath)
	head.position = (Transform2D(_twist, _off) * HEAD + _head_off) * k
	head.rotation = _twist * 0.5 + _head_rot
	head.scale = Vector2(k, k)


# ------------------------------------------------------------------ pose

func _ease_out(x: float) -> float:
	var c := clampf(x, 0.0, 1.0)
	return 1.0 - (1.0 - c) * (1.0 - c)


## 0 -> 1 -> 0 over the action: fast out over `rise` of the time, then back.
func _bump(t: float, dur: float, rise: float = 0.3) -> float:
	var x := clampf(t / dur, 0.0, 1.0)
	if x < rise:
		return _ease_out(x / rise)
	return 1.0 - smoothstep(rise, 1.0, x)


## A hold: eases in over `a` seconds, holds, eases out over the last `b` seconds.
func _hold(t: float, dur: float, a: float, b: float) -> float:
	return smoothstep(0.0, a, t) * (1.0 - smoothstep(dur - b, dur, t))


func _pose() -> void:
	var hw := _hw
	var s := sin(_phase)
	var a := _stride
	_foot_l = Vector2(1.0 + a * s, -4.4 * _w)
	_foot_r = Vector2(1.0 - a * s, 4.4 * _w)
	var run := state == Anim.RUN or speed > 3.2
	var arm := a * (0.72 if run else 0.55)
	var inward := 1.4 if run else 0.0
	_hand_l = Vector2(2.6 - arm * s, -(hw + 0.9 - inward))
	_hand_r = Vector2(2.6 + arm * s, hw + 0.9 - inward)
	_elbow_l = Vector2.INF
	_elbow_r = Vector2.INF
	_twist = -0.055 * s * a / 10.0
	_off = Vector2(1.2 if run else 0.0, 0.0)
	_head_off = Vector2(0.6 if run else 0.0, 0.0)
	_head_rot = 0.0
	_breath = 1.0 + 0.016 * sin(_t * 2.1 + _seed_f)
	_grip_r = ""
	_grip_l = ""
	_aim = false
	_flash = 0.0
	_smoke = 0.0
	_bat_swing = false
	_bat_ang = 0.0
	_impact = 0.0
	_crate = false
	_right_top = true
	var st := state
	if carrying:
		st = Anim.CARRY
	match st:
		Anim.CARRY:
			_crate = true
			_hand_l = Vector2(13.0, -9.6)
			_hand_r = Vector2(13.0, 9.6)
			_elbow_l = Vector2(4.5, -(hw + 0.6))
			_elbow_r = Vector2(4.5, hw + 0.6)
			_off.x += 0.4 * absf(s) * a / 10.0
		Anim.TALK:
			var g := 0.5 + 0.5 * sin(_t * 2.4 + _seed_f)
			var g2 := sin(_t * 5.1 + _seed_f * 1.7)
			_hand_r = Vector2(1.4, hw + 1.2).lerp(Vector2(9.5 + g2, hw - 1.5), g)
			_elbow_r = Vector2(3.0, hw + 1.4)
			_grip_r = "open"
			if int(_seed_f) % 2 == 0:
				var g3 := 0.5 + 0.5 * sin(_t * 1.7 + _seed_f + 2.0)
				_hand_l = Vector2(1.4, -(hw + 1.2)).lerp(Vector2(7.5, -(hw - 2.0)), g3 * 0.7)
				_grip_l = "open"
			_head_rot = 0.12 * sin(_t * 1.3 + _seed_f)
		Anim.ARMS:
			# forearms folded across the front of the chest, clear of the hat brim
			_elbow_r = Vector2(5.2, hw - 0.2)
			_hand_r = Vector2(10.6, -5.2 * _w)
			_elbow_l = Vector2(5.4, -(hw - 0.2))
			_hand_l = Vector2(10.2, 5.2 * _w)
			_right_top = _variant == 0
		Anim.SIT:
			_off = Vector2(-3.0, 0.0)
			_foot_l = Vector2(14.0, -4.8 * _w)
			_foot_r = Vector2(14.0, 4.8 * _w)
			_hand_l = Vector2(7.5, -6.6 * _w)
			_hand_r = Vector2(7.5, 6.6 * _w)
			_elbow_l = Vector2(2.0, -(hw + 0.8))
			_elbow_r = Vector2(2.0, hw + 0.8)
	# a cop swings his nightstick
	if weapon == "" and not _crate and st in [Anim.IDLE, Anim.WALK, Anim.RUN] and _p_stick:
		_hand_r = Vector2(3.0 + (_hand_r.x - 1.4) * 0.5, hw + 1.4)
		_grip_r = "fist"
	# weapons in hand when not busy with a crate
	if not _crate:
		match weapon:
			"pistol":
				_hand_r = Vector2(3.4 + (_hand_r.x - 1.4) * 0.6, hw + 1.0)
				_grip_r = "fist"
			"tommy":
				_hand_r = Vector2(3.0, 6.6)
				_hand_l = Vector2(12.5, 3.2)
				_elbow_r = Vector2(-0.5, hw + 1.8)
				_elbow_l = Vector2(5.0, -(hw - 1.0))
				_grip_r = "fist"
				_grip_l = "fist"
			"bat":
				_hand_r = Vector2(5.2, hw - 4.0)
				_hand_l = Vector2(6.8, hw - 7.0)
				_elbow_r = Vector2(2.0, hw + 1.6)
				_elbow_l = Vector2(4.0, -2.0)
				_grip_r = "fist"
				_grip_l = "fist"
				_bat_ang = PI - 0.32
	if _action == "":
		return
	var t := _action_t
	var dur: float = ACT_LEN.get(_action, 0.6)
	match _action:
		"punch":
			if weapon == "bat":
				_swing_bat(t, dur)
			else:
				var e := _bump(t, dur, 0.3)
				_hand_r = Vector2(6.0, hw - 2.0).lerp(Vector2(22.0, 2.4), e)
				_elbow_r = Vector2(2.0, hw + 1.0).lerp(Vector2(11.0, 5.5), e)
				_hand_l = Vector2(8.0, -5.2)
				_elbow_l = Vector2(3.0, -(hw + 0.6))
				_grip_r = "fist"
				_grip_l = "fist"
				_twist = -0.3 * e
				_off.x += 1.8 * e
				_head_off.x += 1.0 * e
		"hit":
			var e := _bump(t, dur, 0.18)
			var side := 1.0 if _variant == 0 else -1.0
			_off += Vector2(-5.0 * e, 1.5 * side * e)
			_head_off += Vector2(-2.4 * e, 1.0 * side * e)
			_twist = 0.22 * side * e
			_hand_l += Vector2(-3.5 * e, -2.0 * e)
			_hand_r += Vector2(-3.5 * e, 2.0 * e)
			_impact = 1.0 - clampf(t / 0.14, 0.0, 1.0)
		"shoot":
			_aim = true
			if weapon == "tommy":
				var burst := t / 0.09
				var k := fmod(burst, 1.0)
				_flash = (1.0 - k / 0.5) if (k < 0.5 and t < 0.46) else 0.0
				var kick := (1.0 - k) * (1.0 if t < 0.46 else 0.0)
				_hand_r = Vector2(3.6 - kick * 1.4, 6.0)
				_hand_l = Vector2(13.0 - kick * 1.4, 2.6 + 0.6 * sin(t * 40.0))
				_off.x -= kick * 0.8
				_smoke = clampf((t - 0.1) / 0.4, 0.0, 1.0)
			elif weapon == "bat":
				_swing_bat(t, dur)
			else:
				var e := _ease_out(t / 0.07)
				var kick := _bump(t - 0.02, 0.2, 0.25) if t > 0.02 else 0.0
				_hand_r = Vector2(4.0, hw).lerp(Vector2(20.0 - kick * 3.0, 1.6), e)
				_elbow_r = Vector2(2.0, hw + 1.0).lerp(Vector2(10.5 - kick * 2.0, 5.2), e)
				_grip_r = "fist"
				_twist = -0.24 * e
				_flash = 1.0 - clampf(t / 0.07, 0.0, 1.0) if t < 0.07 else 0.0
				_smoke = clampf(t / dur, 0.0, 1.0)
				_head_off.x -= kick * 0.6
		"yes":
			var n := sin(t / dur * TAU * 2.0)
			_head_off.x += 2.2 * maxf(n, 0.0)
		"no":
			_head_rot = 0.38 * sin(t / dur * TAU * 2.2) * (1.0 - t / dur)
		"interact":
			var e := _hold(t, dur, 0.16, 0.2)
			_hand_r = _hand_r.lerp(Vector2(17.0, 3.2), e)
			_elbow_r = Vector2(2.0, hw + 1.0).lerp(Vector2(9.0, 6.5), e)
			_grip_r = "open"
			_twist = -0.15 * e
		"pickup":
			var e := _bump(t, dur, 0.45)
			_off.x += 3.2 * e
			_head_off.x += 4.2 * e
			_hand_l = _hand_l.lerp(Vector2(15.0, -4.5), e)
			_hand_r = _hand_r.lerp(Vector2(15.0, 4.5), e)
			_elbow_l = Vector2(1.0, -(hw + 1.0)).lerp(Vector2(7.0, -(hw - 0.5)), e)
			_elbow_r = Vector2(1.0, hw + 1.0).lerp(Vector2(7.0, hw - 0.5), e)
			_grip_l = "open"
			_grip_r = "open"
		"smash":
			if weapon == "bat":
				_swing_bat(t, dur)
			else:
				# a hammer-fist: wind up behind, then down and across the front
				var x := clampf(t / dur, 0.0, 1.0)
				var ang: float
				if x < 0.3:
					ang = lerpf(1.2, 2.3, smoothstep(0.0, 0.3, x))
				elif x < 0.55:
					ang = lerpf(2.3, -0.45, smoothstep(0.3, 0.55, x))
				else:
					ang = lerpf(-0.45, 1.2, smoothstep(0.55, 1.0, x))
				_hand_r = Vector2(1.0, hw * 0.55) + Vector2(cos(ang), sin(ang)) * 13.0
				_elbow_r = Vector2(0.5, hw * 0.8) + Vector2(cos(ang), sin(ang)) * 6.5
				_grip_r = "fist"
				_twist = -0.3 * sin(clampf((x - 0.3) / 0.3, 0.0, 1.0) * PI) + 0.15 * (1.0 - smoothstep(0.0, 0.3, x)) * smoothstep(0.0, 0.1, x)
		"threaten":
			var e := _hold(t, dur, 0.14, 0.22)
			if weapon == "tommy":
				_aim = true
				_hand_r = Vector2(3.6, 6.0)
				_hand_l = Vector2(13.0, 2.6)
			elif weapon == "bat":
				_hand_r = _hand_r.lerp(Vector2(10.0, 4.5), e)
				_hand_l = _hand_l.lerp(Vector2(8.0, 2.0), e)
				_bat_ang = lerp_angle(PI - 0.32, 0.08, e)
				_bat_swing = true
			else:
				_hand_r = _hand_r.lerp(Vector2(21.0, 2.8), e)
				_elbow_r = Vector2(2.0, hw + 1.0).lerp(Vector2(10.0, 6.0), e)
				_grip_r = "fist" if weapon == "pistol" else "point"
				_aim = weapon == "pistol" and e > 0.5
				_hand_l = _hand_l.lerp(Vector2(-0.5, -(hw + 2.2)), e)
				_elbow_l = Vector2.INF
				_twist = -0.2 * e
				_off.x += 1.5 * e
				_head_off.x += 1.2 * e
		"talk":
			var e := _hold(t, dur, 0.2, 0.3)
			var g := sin(t * 9.0)
			_hand_r = _hand_r.lerp(Vector2(10.0 + g * 1.5, hw - 2.5 + g), e)
			_elbow_r = Vector2(3.0, hw + 1.4)
			_grip_r = "open"
			_head_rot = 0.1 * sin(t * 6.0) * e


func _swing_bat(t: float, dur: float) -> void:
	var x := clampf(t / dur, 0.0, 1.0)
	var ang: float
	if x < 0.22:
		ang = lerpf(PI - 0.32, PI - 0.05, smoothstep(0.0, 0.22, x))       # wind up
	elif x < 0.5:
		ang = lerpf(PI - 0.05, -1.05, smoothstep(0.22, 0.5, x))           # the swing, across the front
	else:
		ang = lerpf(-1.05, PI - 0.32, smoothstep(0.55, 1.0, x))           # back onto the shoulder
	_bat_ang = ang
	_bat_swing = x > 0.22 and x < 0.52
	var c := Vector2(2.0, 0.0)
	var hand := c + Vector2(cos(ang), sin(ang)) * 7.5
	_hand_r = hand + Vector2(cos(ang + PI * 0.5), sin(ang + PI * 0.5)) * 0.5
	_hand_l = hand - Vector2(cos(ang), sin(ang)) * 2.6
	_elbow_r = Vector2(1.0, _hw + 1.0)
	_elbow_l = Vector2(2.5, -(_hw - 1.0))
	_twist = -0.35 * sin(clampf((x - 0.2) / 0.35, 0.0, 1.0) * PI)
	_grip_r = "fist"
	_grip_l = "fist"


# ------------------------------------------------------------------ drawing

func _draw() -> void:
	_ci = self
	if _lk.is_empty():
		_apply_look()
	var base := Transform2D(0.0, Vector2(_k, _k), 0.0, Vector2.ZERO)
	var L := LIGHT.rotated(-global_rotation)
	var S := SHADOW_OFF.rotated(-global_rotation) / _k
	_ci.draw_set_transform_matrix(base)
	if state == Anim.DOWN or state == Anim.DEAD:
		_draw_lying_ground(L, S)
	else:
		_draw_ground(L, S)
	_ci.draw_set_transform_matrix(Transform2D.IDENTITY)


## A cached layer draws itself through here.
func _draw_part(part: CanvasItem, which: int) -> void:
	_ci = part
	if _lk.is_empty():
		_apply_look()
	var L := LIGHT.rotated(-(part as Node2D).global_rotation)
	var lying := state == Anim.DOWN or state == Anim.DEAD
	match which:
		PART_BODY:
			if lying:
				_draw_lying_body(L)
			else:
				_draw_torso(L)
		PART_LIMBS:
			if lying:
				_draw_stars()
			else:
				_draw_limbs(L)
		PART_HEAD:
			if lying:
				_draw_fallen_hat(L)
			else:
				_draw_head(Vector2.ZERO, L, true)
	_ci = self


func _soft_shadow(c: Vector2, radii: Vector2, rot: float, strength: float = 1.0) -> void:
	var base := Transform2D(0.0, Vector2(_k, _k), 0.0, Vector2.ZERO)
	FastDraw.soft(_ci, base, c, radii * 1.25, rot, Color(0.02, 0.02, 0.05, 0.4 * strength))


## On the ground, drawn by this node: the ring, the shadow, the legs.
func _draw_ground(L: Vector2, S: Vector2) -> void:
	var hw := _hw
	if ring_color.a > 0.0:
		var rc := ring_color
		FastDraw.disc(_ci, Vector2.ZERO, 17.0, Color(rc.r, rc.g, rc.b, 0.13))
		_ci.draw_arc(Vector2.ZERO, 17.0, 0.0, TAU, 32, Color(rc.r, rc.g, rc.b, 0.75), 1.6, true)
	# the body's footprint, pushed down-right in world space
	_soft_shadow(S + _off * 0.6 + Vector2(0.5, 0.0), Vector2(_front + 1.5, hw + 2.0), _twist)
	if _crate:
		_soft_shadow(S * 1.25 + Vector2(14.0, 0.0), Vector2(8.0, 11.0), 0.0, 0.8)
	_draw_legs(L)


## Arms, hands and what they hold (the limbs layer, per frame while moving).
func _draw_limbs(L: Vector2) -> void:
	var hw := _hw
	var tx := Transform2D(_twist, _off)
	# the newsboy's bundle, under his left arm
	if _p_papers and not _crate:
		_ci.draw_set_transform_matrix(tx)
		_draw_papers(Vector2(1.5, -(hw + 2.2)), L)
		_ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	var sh_l := tx * Vector2(-1.8, -(hw - 0.7))
	var sh_r := tx * Vector2(-1.8, hw - 0.7)
	var band := _band
	var garter := _p_garters
	if _right_top:
		_arm(sh_l, _elbow_l, _hand_l, L, band, garter, _grip_l, false)
		_arm(sh_r, _elbow_r, _hand_r, L, NONE, garter, _grip_r, true)
	else:
		_arm(sh_r, _elbow_r, _hand_r, L, NONE, garter, _grip_r, true)
		_arm(sh_l, _elbow_l, _hand_l, L, band, garter, _grip_l, false)
	if _crate:
		_draw_crate(Vector2(14.0, 0.0), L)
		_hand(_hand_l, L, "")
		_hand(_hand_r, L, "")
	elif weapon == "pistol":
		_draw_pistol(_hand_r, L)
	elif weapon == "tommy":
		_draw_tommy(L)
	elif weapon == "bat":
		_draw_bat(L)
	elif _p_hook:
		_draw_hook(_hand_r, L)
	if _p_stick and weapon == "" and not _crate and _grip_r == "fist":
		_draw_nightstick(_hand_r, L)
	if _flash > 0.0 or _smoke > 0.0:
		_draw_muzzle(_muzzle_local())
	if _impact > 0.0:
		_draw_impact(Vector2(10.0, 0.0) + _off, _impact)


func _draw_legs(L: Vector2) -> void:
	var trousers: Color = _lk["trousers"]
	var shoes: Color = _lk["shoes"]
	var legs_skin := _female or kind in ["kid", "newsboy"]
	var lr := 3.0 * sqrt(_w)
	var col := trousers
	if _female:
		col = _skin.darkened(0.18)
		lr = 2.2
	elif kind in ["kid", "newsboy"]:
		col = trousers
	var hips := [Vector2(0.6, -4.0 * _w), Vector2(0.6, 4.0 * _w)]
	var feet := [_foot_l, _foot_r]
	for i in 2:
		var hip: Vector2 = hips[i]
		var f: Vector2 = feet[i]
		var ankle := f - Vector2(1.2, 0.0)
		if state == Anim.SIT:
			# thighs forward, knees, the shins go down out of sight
			var knee := f - Vector2(1.5, 0.0)
			FastDraw.capsule(_ci, hip, knee, lr + 0.6, col.darkened(0.4))
			FastDraw.capsule(_ci, hip, knee, lr, col)
			_ci.draw_line(hip + L * 1.2, knee + L * 1.2, col.lightened(0.14), lr * 0.7, true)
			_shoe(f + Vector2(1.6, 0.0), shoes, L)
			continue
		if hip.distance_to(ankle) > 1.0:
			FastDraw.capsule(_ci, hip, ankle, lr + 0.6, col.darkened(0.4))
			FastDraw.capsule(_ci, hip, ankle, lr, col)
			if legs_skin and not _female:
				# kids: bare shins below the knickers
				var knee := hip.lerp(ankle, 0.5)
				FastDraw.capsule(_ci, knee, ankle, lr * 0.75, _skin.darkened(0.08))
		_shoe(f, shoes, L)


func _shoe(f: Vector2, shoes: Color, L: Vector2) -> void:
	var sr := Vector2(3.4, 2.2) if not _female else Vector2(2.7, 1.6)
	var a := f + Vector2(0.3 - sr.x + sr.y, 0.0)
	var b := f + Vector2(0.3 + sr.x - sr.y, 0.0)
	FastDraw.capsule(_ci, a, b, sr.y + 0.5, shoes.darkened(0.5))
	FastDraw.capsule(_ci, a, b, sr.y, shoes)
	FastDraw.disc(_ci, f + Vector2(sr.x * 0.55, 0.0) + L * 0.6, 0.9, shoes.lightened(0.3))


func _arm(sh: Vector2, el: Vector2, hand: Vector2, L: Vector2, band: Color, garter: bool, grip: String, _right: bool) -> void:
	var coat: String = _lk["coat"]
	var sleeves: String = _lk["sleeves"]
	var r := 2.9 * sqrt(_w)
	var fill := _sleeve
	if coat == "flapper" or sleeves == "bare":
		fill = _skin
		r = 2.2 * sqrt(_w)
	var mid := el if el != Vector2.INF else sh.lerp(hand, 0.55)
	var wrist := hand - (hand - mid).normalized() * 1.4 if hand.distance_to(mid) > 1.5 else hand
	var edge := fill.darkened(0.42)
	var hi := fill.lightened(0.16)
	var rolled := sleeves == "rolled" and coat in ["shirt", "vest"]
	# a hand hanging straight down is under the sleeve, seen from above
	var tucked := hand.distance_to(sh) < 5.0
	if tucked:
		_hand(hand, L, grip)
	# upper arm
	FastDraw.capsule(_ci, sh, mid, r + 0.6, edge)
	# forearm edge
	FastDraw.capsule(_ci, mid, wrist, (r * 0.82 if rolled else r * 0.92) + 0.6, (_skin.darkened(0.4) if rolled else edge))
	FastDraw.capsule(_ci, sh, mid, r, fill)
	if rolled:
		FastDraw.capsule(_ci, mid, wrist, r * 0.82, _skin)
		# the rolled cuff above the elbow
		FastDraw.disc(_ci, mid, r * 1.0, fill.darkened(0.25))
		FastDraw.disc(_ci, mid, r * 0.85, fill.lightened(0.05))
	else:
		FastDraw.capsule(_ci, mid, wrist, r * 0.92, fill)
	_ci.draw_line(sh + L * r * 0.45, mid + L * r * 0.45, hi, r * 0.6, true)
	if wrist.distance_squared_to(mid) > 4.0:
		var fhi := (_skin.lightened(0.16) if rolled else hi)
		_ci.draw_line(mid + L * r * 0.4, wrist + L * r * 0.4, fhi, r * 0.5, true)
	if band.a > 0.0:
		if hand.distance_to(sh) < 5.0:
			var cap := sh.lerp(hand, 0.4)
			FastDraw.disc(_ci, cap, r * 0.62 + 1.0, band.darkened(0.3))
			FastDraw.disc(_ci, cap, r * 0.62 + 0.6, band)
			FastDraw.disc(_ci, cap, r * 0.62 - 0.6, _sleeve)
		else:
			var m := sh.lerp(mid, 0.5)
			var perp := (mid - sh).normalized().orthogonal()
			_ci.draw_line(m - perp * (r + 0.2), m + perp * (r + 0.2), band.darkened(0.3), 2.4, true)
			_ci.draw_line(m - perp * r, m + perp * r, band, 1.7, true)
	elif garter:
		var g := sh.lerp(mid, 0.55)
		FastDraw.disc(_ci, g, r + 0.25, Color("2a1e1a"))
		FastDraw.disc(_ci, g, r - 0.4, fill)
	if not rolled and coat in ["suit", "three", "tux", "overcoat", "trench", "peacoat", "tunic"] and hand.distance_to(mid) > 3.0:
		# a white shirt cuff at the wrist
		FastDraw.disc(_ci, wrist, r * 0.7, (_lk["shirt"] as Color))
	if not tucked:
		_hand(hand, L, grip)


func _hand(p: Vector2, L: Vector2, grip: String) -> void:
	var r := 2.2 * sqrt(_w)
	if _female:
		r = 1.8
	var sk := _skin
	FastDraw.disc(_ci, p, r + 0.5, sk.darkened(0.38))
	match grip:
		"open":
			FastDraw.oval(_ci, p + Vector2(0.6, 0.0), Vector2(r * 1.25, r * 0.95), sk)
			FastDraw.capsule(_ci, p + Vector2(0.3, -r * 0.7), p + Vector2(1.6, -r * 1.2), 0.65, sk.darkened(0.08))
		"point":
			FastDraw.disc(_ci, p, r, sk)
			FastDraw.capsule(_ci, p + Vector2(r * 0.5, 0.0), p + Vector2(r * 0.5 + 3.4, -0.3), 0.75, sk.darkened(0.3))
			FastDraw.capsule(_ci, p + Vector2(r * 0.5, 0.0), p + Vector2(r * 0.5 + 3.4, -0.3), 0.55, sk)
		_:
			FastDraw.disc(_ci, p, r, sk)
	FastDraw.disc(_ci, p + L * r * 0.4, r * 0.4, sk.lightened(0.18))


# ------------------------------------------------------------------ the torso (coat, shirt, apron)

static func _superellipse(hw: float, front: float, back: float, n: float, seg: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in seg:
		var a := TAU * float(i) / seg
		var c := cos(a)
		var s := sin(a)
		var x := (front if c > 0.0 else back) * signf(c) * pow(absf(c), 2.0 / n)
		var y := hw * signf(s) * pow(absf(s), 2.0 / n)
		pts.append(Vector2(x, y))
	return pts


## Warm sunlight on a colour / shade toward night blue. Lifts dark cloth more than lightened().
static func _lit(c: Color, a: float) -> Color:
	return c.lerp(Color(1.0, 0.95, 0.86), a)


static func _dk(c: Color, a: float) -> Color:
	return c.lerp(Color(0.035, 0.03, 0.05), a)


## A thin sunlit line along the part of a closed shape that faces the light (north-west).
func _rim(pts: PackedVector2Array, center: Vector2, L: Vector2, col: Color, width: float, inset: float = 0.94, cut: float = 0.3) -> void:
	var n := pts.size()
	var facing := PackedByteArray()
	facing.resize(n)
	var any := false
	for i in n:
		var f := (pts[i] - center).normalized().dot(L) > cut
		facing[i] = 1 if f else 0
		any = any or f
	if not any:
		return
	var start := 0
	for i in n:
		if facing[i] == 1 and facing[(i - 1 + n) % n] == 0:
			start = i
			break
	var run := PackedVector2Array()
	for k in n:
		var i := (start + k) % n
		if facing[i] == 0:
			break
		run.append(center + (pts[i] - center) * inset)
	if run.size() >= 2:
		_ci.draw_polyline(run, col, width, true)


func _shape(pts: PackedVector2Array, sc: float, off: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(pts.size())
	for i in pts.size():
		out[i] = pts[i] * sc + off
	return out


func _draw_torso(L: Vector2) -> void:
	var coat: String = _lk["coat"]
	var hw := _hw
	var fr := _front
	var bk := _back
	var base := _coat
	var shirt: Color = _lk["shirt"]
	var skin := _skin
	if coat == "flapper":
		# bare shoulders, a beaded shift below them
		Draw.poly(_ci, _torso, skin.darkened(0.35))
		Draw.poly(_ci, _shape(_torso, 0.9, L * 0.5), skin)
		var dress := _superellipse(hw * 0.7, fr, bk, 2.4, 22)
		Draw.poly(_ci, dress, base.darkened(0.3))
		Draw.poly(_ci, _shape(dress, 0.9, L * 0.4), base)
		for i in 14:
			var p := Vector2(lerpf(-bk * 0.8, fr * 0.8, Draw.hash01(look & 0xfff, i, 3)), lerpf(-hw * 0.6, hw * 0.6, Draw.hash01(look & 0xfff, i, 4)))
			FastDraw.disc(_ci, p, 0.45, base.lightened(0.45))
		for sgn: float in [-1.0, 1.0]:
			_ci.draw_line(Vector2(-bk * 0.6, sgn * hw * 0.52), Vector2(fr * 0.6, sgn * hw * 0.5), base.darkened(0.2), 0.9, true)
		FastDraw.oval(_ci, L * 3.0, Vector2(fr * 0.45, hw * 0.35), Color(1, 1, 1, 0.1))
		if bool(_lk["pearls"]):
			_pearls(HEAD)
		return
	# the coat's body: dark edge, the cloth pushed toward the light, sun on the shoulders
	Draw.poly(_ci, _torso, _dk(base, 0.55))
	Draw.poly(_ci, _shape(_torso, 0.9, L * 0.7), base)
	FastDraw.oval(_ci, L * 2.6, Vector2(fr * 0.66, hw * 0.7), Color(1.0, 0.95, 0.86, 0.09))
	FastDraw.oval(_ci, L * 3.6, Vector2(fr * 0.42, hw * 0.46), Color(1.0, 0.95, 0.86, 0.09))
	_rim(_torso, Vector2.ZERO, L, _lit(base, 0.32), 1.1, 0.93)
	if kind == "boss" and coat == "three":
		for k in 5:
			var y := (k - 2) * hw * 0.3
			_ci.draw_line(Vector2(-bk * 0.8, y), Vector2(fr * 0.8, y * 0.95), Color(1, 1, 1, 0.07), 0.5, true)
	if String(_lk["pattern"]) == "check":
		_checks(base)
	match coat:
		"suit", "three", "tux":
			_collar_back(base, 5.8, 1.5)
			var vest: Color = base.darkened(0.2) if coat == "three" else NONE
			_vneck(shirt, vest, base, coat == "tux")
			if coat != "tux" and Draw.hash01(look & 0xfff, 7, 1) < 0.35 and kind != "dealer":
				Draw.poly(_ci, PackedVector2Array([Vector2(3.8, -hw * 0.62), Vector2(5.4, -hw * 0.66), Vector2(4.8, -hw * 0.5)]), Pal.PAPER)
			_ci.draw_line(Vector2(-bk + 0.8, 0.0), Vector2(-bk * 0.45, 0.0), base.darkened(0.3), 0.8, true)
		"overcoat":
			var fur: Color = _lk["fur"]
			if fur.a > 0.0:
				_fur_collar(fur, 6.6)
			else:
				_collar_back(base.darkened(0.08), 6.2, 2.6)
			_vneck(shirt, NONE, base, false)
			for sgn: float in [-1.0, 1.0]:
				FastDraw.disc(_ci, Vector2(fr - 1.2, sgn * 4.4), 0.8, base.darkened(0.45))
				FastDraw.disc(_ci, Vector2(fr - 2.6, sgn * 6.4), 0.8, base.darkened(0.45))
		"tunic":
			_collar_back(base.darkened(0.1), 5.6, 1.4)
			for sgn: float in [-1.0, 1.0]:
				# shoulder straps with a brass button
				_ci.draw_line(Vector2(-3.8, sgn * (hw - 2.3)), Vector2(2.4, sgn * (hw - 2.6)), _dk(base, 0.4), 1.7, true)
				_ci.draw_line(Vector2(-3.8, sgn * (hw - 2.5)), Vector2(2.4, sgn * (hw - 2.8)), _lit(base, 0.12), 1.0, true)
				FastDraw.disc(_ci, Vector2(2.2, sgn * (hw - 2.6)), 0.7, Pal.BRASS)
				for k in 2:
					var bp := Vector2(fr - 0.9 - k * 1.9, sgn * (3.9 + k * 1.9))
					FastDraw.disc(_ci, bp, 0.85, Pal.BRASS.darkened(0.35))
					FastDraw.disc(_ci, bp - Vector2(0.15, 0.15), 0.55, Pal.BRASS.lightened(0.2))
			# the shield on the left breast
			var bp := Vector2(3.6, -hw * 0.66)
			Draw.poly(_ci, PackedVector2Array([bp + Vector2(-1.2, -1.1), bp + Vector2(1.3, -1.1), bp + Vector2(1.4, 0.3), bp + Vector2(0.1, 1.4), bp + Vector2(-1.3, 0.3)]), Pal.BRASS)
			FastDraw.disc(_ci, bp + L * 0.5, 0.45, Color(1.0, 0.95, 0.75))
		"trench":
			_collar_back(base.lightened(0.06), 6.4, 2.8)
			# the storm flap over the right shoulder, epaulettes
			Draw.poly(_ci, PackedVector2Array([Vector2(-1.0, 3.0), Vector2(fr - 1.0, 3.6), Vector2(fr - 1.8, hw - 1.4), Vector2(-1.5, hw - 1.2)]), base.lightened(0.05))
			_ci.draw_line(Vector2(-1.0, 3.0), Vector2(-1.5, hw - 1.2), base.darkened(0.25), 0.8, true)
			for sgn: float in [-1.0, 1.0]:
				FastDraw.capsule(_ci, Vector2(-3.8, sgn * (hw - 2.2)), Vector2(2.4, sgn * (hw - 2.5)), 1.05, base.darkened(0.08))
				FastDraw.disc(_ci, Vector2(2.0, sgn * (hw - 2.5)), 0.7, Color("3a2a1c"))
				FastDraw.disc(_ci, Vector2(fr - 1.4, sgn * 4.6), 0.8, Color("3a2a1c"))
			_vneck(shirt, NONE, base, false)
			_ci.draw_arc(Vector2(-1.0, 0.0), bk * 0.9, PI * 0.72, PI * 1.28, 10, base.darkened(0.22), 0.8, true)
		"peacoat":
			_collar_back(base.lightened(0.05), 6.6, 3.2)
			for sgn: float in [-1.0, 1.0]:
				Draw.poly(_ci, PackedVector2Array([Vector2(2.2, sgn * 3.0), Vector2(fr - 0.5, sgn * 2.4), Vector2(fr - 1.6, sgn * 7.4), Vector2(1.0, sgn * 6.4)]), base.lightened(0.07))
				for k in 2:
					var bp := Vector2(fr - 1.3 - k * 2.2, sgn * (4.2 + k * 2.3))
					FastDraw.disc(_ci, bp, 1.0, Color("16181c"))
					FastDraw.disc(_ci, bp + L * 0.3, 0.55, Color("4a4e58"))
		"jacket":
			_collar_back(base.darkened(0.1), 5.8, 1.8)
			_tweed(base)
			_vneck(shirt, NONE, base, false)
			_ci.draw_line(Vector2(-bk * 0.55, -hw * 0.7), Vector2(-bk * 0.55, hw * 0.7), base.darkened(0.2), 0.7, true)
		"sweater":
			for k in 4:
				var x := lerpf(-bk * 0.7, fr * 0.7, k / 3.0)
				_ci.draw_line(Vector2(x, -hw * 0.75), Vector2(x, hw * 0.75), base.darkened(0.12), 0.6, true)
			Draw.poly(_ci, PackedVector2Array([Vector2(3.6, -2.6), Vector2(fr + 0.2, -1.6), Vector2(4.4, 0.0), Vector2(fr + 0.2, 1.6), Vector2(3.6, 2.6)]), shirt)
		"cardigan":
			for k in 5:
				var y := lerpf(-hw * 0.8, hw * 0.8, k / 4.0)
				_ci.draw_line(Vector2(-bk * 0.75, y), Vector2(fr * 0.75, y), base.darkened(0.1), 0.55, true)
			_collar_back(base.lightened(0.08), 6.0, 2.4)
			_vneck(shirt, NONE, base.lightened(0.08), false)
			for k in 2:
				FastDraw.disc(_ci, Vector2(fr - 0.8, (k - 0.5) * 2.6), 0.6, base.darkened(0.45))
		"dress":
			FastDraw.oval(_ci, Vector2(3.8, 0.0), Vector2(2.6, 4.2), skin.darkened(0.08))
			_ci.draw_arc(Vector2(3.8, 0.0), 4.1, -PI * 0.45, PI * 0.45, 10, base.darkened(0.25), 0.8, true)
			if bool(_lk["pearls"]):
				_pearls(HEAD)
		"coat_w":
			var fur: Color = _lk["fur"]
			_ci.draw_line(Vector2(2.0, -2.0), Vector2(fr - 0.4, 5.0), base.darkened(0.3), 0.9, true)
			FastDraw.disc(_ci, Vector2(fr - 1.6, -3.8), 0.9, base.darkened(0.45))
			if fur.a > 0.0:
				_fur_collar(fur, 6.4)
			else:
				_collar_back(base.lightened(0.06), 6.0, 2.2)
		"whitejacket":
			_collar_back(base.darkened(0.06), 5.4, 1.2)
			_ci.draw_line(Vector2(3.0, 3.0), Vector2(fr - 0.3, 5.2), base.darkened(0.2), 0.8, true)
			for k in 3:
				FastDraw.disc(_ci, Vector2(3.4 + k * 1.2, 3.8 + k * 0.6), 0.5, base.darkened(0.3))
			if "comb" in _lk["props"]:
				_ci.draw_line(Vector2(3.4, -hw * 0.62), Vector2(5.6, -hw * 0.6), Color("2a2622"), 1.0, true)
		"shirt", "vest":
			_shirt_body(L)
	# aprons over everything
	var apron: String = _lk["apron"]
	if apron != "":
		_apron(apron, L)
	# scarf, flower, tape measure
	var scarf: Color = _lk["scarf"]
	if scarf.a > 0.0:
		_scarf(scarf, L)
	var flower: Color = _lk["flower"]
	if flower.a > 0.0:
		var fp := Vector2(4.4, -hw * 0.66)
		FastDraw.disc(_ci, fp, 1.55, flower.darkened(0.35))
		FastDraw.disc(_ci, fp + Vector2(-0.3, -0.2), 1.2, flower)
		FastDraw.disc(_ci, fp + Vector2(0.4, 0.4), 0.8, flower.lightened(0.15))
		FastDraw.disc(_ci, fp + Vector2(-1.3, 0.8), 0.6, Color("3a5a2a"))
	if "tape" in _lk["props"]:
		for sgn: float in [-1.0, 1.0]:
			var a := Vector2(-2.6, sgn * 3.6)
			var b := Vector2(fr + 0.4, sgn * 3.2)
			_ci.draw_line(a, b, Color("8a7424"), 1.9, true)
			_ci.draw_line(a, b, Color("e0c04a"), 1.3, true)
			for k in 5:
				var p := a.lerp(b, (k + 0.5) / 5.0)
				_ci.draw_line(p + Vector2(0, -0.6), p + Vector2(0, 0.6), Color("3a3020"), 0.4)
		_ci.draw_arc(HEAD, 4.6, PI * 0.62, PI * 1.38, 12, Color("e0c04a"), 1.3, true)
	if "papers" in _lk["props"]:
		# the satchel strap across the chest
		_ci.draw_line(Vector2(-4.5, -hw * 0.75), Vector2(4.5, hw * 0.75), Color("5a4630"), 1.4, true)


func _collar_back(col: Color, r: float, width: float) -> void:
	var c := HEAD
	_ci.draw_arc(c, r, PI * 0.58, PI * 1.42, 14, col.darkened(0.35), width + 0.8, true)
	_ci.draw_arc(c, r, PI * 0.6, PI * 1.4, 14, col, width, true)


## The front of a jacket: the shirt and tie in the V at the chest, and broad lapels on the front of
## the shoulders (they show past a hat brim, so a suit reads as a suit from above).
func _vneck(shirt: Color, vest: Color, lapel_base: Color, tux: bool) -> void:
	var fr := _front
	var tie: String = _lk["tie"]
	var tie_col: Color = _lk["tie_col"]
	var scarf: Color = _lk["scarf"]
	var vw := 3.4 if not tux else 4.0
	if vest.a > 0.0:
		Draw.poly(_ci, PackedVector2Array([Vector2(1.4, -vw - 0.4), Vector2(fr - 0.3, -2.0), Vector2(fr - 0.3, 2.0), Vector2(1.4, vw + 0.4)]), vest)
		vw -= 1.1
	Draw.poly(_ci, PackedVector2Array([Vector2(1.6, -vw), Vector2(fr - 0.3, -1.1), Vector2(fr - 0.3, 1.1), Vector2(1.6, vw)]), shirt)
	if tie == "tie" and scarf.a == 0.0:
		Draw.poly(_ci, PackedVector2Array([Vector2(2.4, -0.95), Vector2(fr - 0.4, -0.75), Vector2(fr + 0.3, 0.0), Vector2(fr - 0.4, 0.75), Vector2(2.4, 0.95)]), tie_col)
		_ci.draw_line(Vector2(2.8, -0.35), Vector2(fr - 0.8, -0.25), tie_col.lightened(0.25), 0.5, true)
	elif tie == "bow":
		_bow_tie(Vector2(3.4, 0.0), tie_col)
	var lap := _lit(lapel_base, 0.12) if not tux else Color("3a3a42")
	var crease := _dk(lapel_base, 0.6)
	for sgn: float in [-1.0, 1.0]:
		var a := Vector2(0.4, sgn * (vw + 0.3))
		var b := Vector2(fr - 2.2, sgn * 7.8 * _w)
		var c := Vector2(fr - 0.3, sgn * 1.3)
		Draw.poly(_ci, PackedVector2Array([a, b, c]), lap)
		_ci.draw_line(a, b, crease, 0.9, true)
		_ci.draw_line(b, c, _lit(lapel_base, 0.35), 0.6, true)


func _bow_tie(p: Vector2, col: Color) -> void:
	Draw.poly(_ci, PackedVector2Array([p, p + Vector2(-0.9, -2.1), p + Vector2(0.9, -2.1)]), col)
	Draw.poly(_ci, PackedVector2Array([p, p + Vector2(-0.9, 2.1), p + Vector2(0.9, 2.1)]), col)
	FastDraw.disc(_ci, p, 0.7, col.lightened(0.15))


func _shirt_body(L: Vector2) -> void:
	var fr := _front
	var bk := _back
	var hw := _hw
	var shirt: Color = _lk["shirt"]
	var vest: Color = _lk["vest"]
	var braces: Color = _lk["braces"]
	var tie: String = _lk["tie"]
	var tie_col: Color = _lk["tie_col"]
	# creases in the cloth
	_ci.draw_line(Vector2(-bk * 0.6, -hw * 0.35), Vector2(-bk * 0.1, -hw * 0.5), shirt.darkened(0.1), 0.7, true)
	_ci.draw_line(Vector2(-bk * 0.5, hw * 0.4), Vector2(0.0, hw * 0.55), shirt.darkened(0.1), 0.7, true)
	if vest.a > 0.0:
		var vp := _superellipse(hw * 0.74, fr - 0.4, bk - 0.5, 2.3, 24)
		Draw.poly(_ci, vp, _dk(vest, 0.5))
		Draw.poly(_ci, _shape(vp, 0.9, L * 0.5), vest)
		FastDraw.oval(_ci, L * 2.4, Vector2(fr * 0.45, hw * 0.42), Color(1.0, 0.95, 0.86, 0.1))
		_rim(vp, Vector2.ZERO, L, _lit(vest, 0.3), 0.8, 0.9)
		Draw.poly(_ci, PackedVector2Array([Vector2(2.6, -3.0), Vector2(fr, -1.6), Vector2(fr, 1.6), Vector2(2.6, 3.0)]), shirt)
		for k in 2:
			FastDraw.disc(_ci, Vector2(fr - 1.2, (k - 0.5) * 3.4), 0.5, vest.darkened(0.45))
		# the vest's back strap and buckle
		Draw.rect(_ci, Rect2(-bk + 0.8, -1.2, 1.2, 2.4), vest.darkened(0.3))
	elif braces.a > 0.0:
		for sgn: float in [-1.0, 1.0]:
			_ci.draw_line(Vector2(fr - 0.3, sgn * 4.2 * _w), Vector2(-1.5, sgn * 4.4 * _w), braces, 1.3, true)
			_ci.draw_line(Vector2(-1.5, sgn * 4.4 * _w), Vector2(-bk + 0.6, sgn * 1.2), braces, 1.3, true)
		FastDraw.disc(_ci, Vector2(-bk + 1.0, 0.0), 0.9, braces.darkened(0.2))
	# collar points at the front
	for sgn: float in [-1.0, 1.0]:
		Draw.poly(_ci, PackedVector2Array([Vector2(3.6, sgn * 3.2), Vector2(fr - 0.6, sgn * 2.6), Vector2(4.2, sgn * 0.6)]), shirt.lightened(0.08))
		_ci.draw_line(Vector2(3.6, sgn * 3.2), Vector2(fr - 0.6, sgn * 2.6), shirt.darkened(0.25), 0.6, true)
	match tie:
		"tie":
			Draw.poly(_ci, PackedVector2Array([Vector2(4.2, -0.9), Vector2(fr + 0.2, -0.7), Vector2(fr + 0.6, 0.0), Vector2(fr + 0.2, 0.7), Vector2(4.2, 0.9)]), tie_col)
		"bow":
			_bow_tie(Vector2(4.8, 0.0), tie_col)
		"neckerchief":
			_ci.draw_arc(HEAD, 5.4, -PI * 0.5, PI * 0.5, 12, tie_col, 1.6, true)
			Draw.poly(_ci, PackedVector2Array([Vector2(5.0, -1.4), Vector2(fr + 0.8, 0.0), Vector2(5.0, 1.4)]), tie_col)
	_collar_back(shirt.darkened(0.04), 5.0, 1.1)


func _apron(apron: String, L: Vector2) -> void:
	var fr := _front
	var bk := _back
	var hw := _hw
	var col := PersonLook.WHITE
	match apron:
		"leather": col = PersonLook.LEATHER
		"canvas": col = PersonLook.CANVAS
		"rubber": col = PersonLook.RUBBER
	var edge := col.darkened(0.3)
	# the ties around the waist to a bow at the back
	for sgn: float in [-1.0, 1.0]:
		_ci.draw_line(Vector2(0.4, sgn * hw * 0.86), Vector2(-bk + 0.9, sgn * 0.9), edge, 1.0, true)
		_ci.draw_line(Vector2(0.4, sgn * hw * 0.86), Vector2(-bk + 0.9, sgn * 0.9), col, 0.6, true)
	var bw := Vector2(-bk + 0.7, 0.0)
	FastDraw.oval_rot(_ci, Transform2D.IDENTITY, bw + Vector2(0.2, -1.4), Vector2(1.0, 1.4), 0.3, col)
	FastDraw.oval_rot(_ci, Transform2D.IDENTITY, bw + Vector2(0.2, 1.4), Vector2(1.0, 1.4), -0.3, col)
	_ci.draw_line(bw, bw + Vector2(-2.2, -1.1), col, 0.7, true)
	_ci.draw_line(bw, bw + Vector2(-2.0, 1.3), col, 0.7, true)
	FastDraw.disc(_ci, bw, 0.75, edge)
	# the neck strap
	_ci.draw_arc(HEAD, 5.7, PI * 0.55, PI * 1.45, 14, col, 0.9, true)
	# the bib, bulging past the belly
	var r := Rect2(Vector2(3.0 * _dd, -6.4 * _w), Vector2(fr + 1.3 - 3.0 * _dd, 12.8 * _w))
	Draw.rrect(_ci, r.grow(0.5), 2.6, edge)
	Draw.rrect(_ci, r, 2.6, col)
	match apron:
		"striped":
			var n := 5
			for k in n:
				var y := lerpf(r.position.y + 1.4, r.end.y - 1.4, k / float(n - 1))
				_ci.draw_line(Vector2(r.position.x + 0.6, y), Vector2(r.end.x - 0.9, y), Color("3a4a6e"), 0.9, true)
		"rubber":
			_ci.draw_line(Vector2(r.position.x + 1.0, -2.0) + L, Vector2(r.end.x - 1.2, -2.6) + L, Color(1, 1, 1, 0.2), 1.0, true)
		"leather":
			_ci.draw_rect(r.grow(-0.9), col.lightened(0.18), false, 0.5, true)
	_ci.draw_line(Vector2(r.position.x + 0.8, r.position.y + 1.0), Vector2(r.position.x + 0.8, r.end.y - 1.0), edge, 0.6, true)


func _scarf(col: Color, L: Vector2) -> void:
	var fr := _front
	var edge := col.darkened(0.28)
	_ci.draw_arc(HEAD, 5.9, PI * 0.56, PI * 1.44, 14, edge, 3.1, true)
	_ci.draw_arc(HEAD, 5.9, PI * 0.58, PI * 1.42, 14, col, 2.4, true)
	for sgn: float in [-1.0, 1.0]:
		var pts := PackedVector2Array([Vector2(-3.6, sgn * 5.0), Vector2(-1.2, sgn * 8.3 * _w), Vector2(fr - 0.5, sgn * 7.0 * _w),
			Vector2(fr + 0.2, sgn * 4.3), Vector2(0.8, sgn * 4.2)])
		Draw.poly(_ci, pts, edge)
		Draw.poly(_ci, _shape(pts, 0.93, Vector2(0.2, 0.0) + L * 0.25), col)
		_ci.draw_line(Vector2(-0.6, sgn * 6.4 * _w) + L * 0.4, Vector2(fr - 1.2, sgn * 5.7 * _w) + L * 0.4, col.lightened(0.4), 0.6, true)


func _fur_collar(col: Color, r: float) -> void:
	var c := HEAD
	for i in 13:
		var a := PI * 0.3 + PI * 1.4 * i / 12.0
		var p := c + Vector2(cos(a), sin(a)) * r
		FastDraw.disc(_ci, p, 2.1, col.darkened(0.3))
	for i in 13:
		var a := PI * 0.3 + PI * 1.4 * i / 12.0
		var p := c + Vector2(cos(a), sin(a)) * r
		FastDraw.disc(_ci, p - Vector2(0.3, 0.3), 1.6, col)
		FastDraw.disc(_ci, p - Vector2(0.7, 0.6), 0.6, col.lightened(0.25))


func _pearls(c: Vector2) -> void:
	for i in 11:
		var a := -PI * 0.46 + PI * 0.92 * i / 10.0
		var p := c + Vector2(cos(a) * 6.6, sin(a) * 5.4)
		FastDraw.disc(_ci, p, 0.62, Color("f4efe4"))
	for i in 7:
		var a := -PI * 0.4 + PI * 0.8 * i / 6.0
		var p := c + Vector2(3.0, 0.0) + Vector2(cos(a) * 4.8, sin(a) * 3.4)
		FastDraw.disc(_ci, p, 0.55, Color("efe8da"))


func _checks(_base: Color) -> void:
	var line := (_lk["coat_col2"] as Color)
	line.a = 0.85
	var hw := _hw
	for k in 5:
		var x := lerpf(-_back * 0.72, _front * 0.72, k / 4.0)
		var hh := hw * 0.8 * sqrt(maxf(0.0, 1.0 - pow(x / (_front if x > 0.0 else _back), 2.0)) + 0.1)
		_ci.draw_line(Vector2(x, -minf(hh, hw * 0.85)), Vector2(x, minf(hh, hw * 0.85)), line, 0.9, true)
	for k in 7:
		var y := lerpf(-hw * 0.78, hw * 0.78, k / 6.0)
		_ci.draw_line(Vector2(-_back * 0.75, y), Vector2(_front * 0.75, y), line, 0.9, true)


func _tweed(base: Color) -> void:
	for i in 16:
		var p := Vector2(lerpf(-_back * 0.8, _front * 0.8, Draw.hash01(look & 0xfff, i, 11)), lerpf(-_hw * 0.8, _hw * 0.8, Draw.hash01(look & 0xfff, i, 12)))
		Draw.rect(_ci, Rect2(p, Vector2(0.8, 0.8)), base.lightened(0.12) if i % 2 == 0 else base.darkened(0.14))


# ------------------------------------------------------------------ head, hair, hats

func _draw_head(c: Vector2, L: Vector2, standing: bool) -> void:
	var s := _hs
	var brim := _brim_radius()
	# the hat's shadow on the shoulders (it sits higher than everything else)
	if standing:
		FastDraw.oval(_ci, c - L * 2.2, Vector2(brim, brim * 0.94) * s, Color(0, 0, 0, 0.2))
	var covered := _hat in ["fedora", "homburg", "bowler", "boater", "police", "toque", "top"]
	if "cigar" in _lk["props"]:
		_cigar(c + Vector2(4.8, 1.2) * s, s)
	if not covered:
		_head_skin(c, s, L)
		_hair(c, s, L)
		if bool(_lk["glasses"]):
			_glasses(c, s, L)
	_draw_hat(_hat, c, s, L)


func _brim_radius() -> float:
	match _hat:
		"fedora": return 7.9
		"homburg": return 7.3
		"bowler": return 6.5
		"boater": return 8.3
		"police": return 6.4
		"toque": return 6.9
		"top": return 6.8
		"cloche": return 6.5
		"newsboy": return 6.3
		"flat": return 5.8
		"watch": return 5.5
	return 5.2


func _head_skin(c: Vector2, s: float, L: Vector2) -> void:
	var sk := _skin
	for sgn: float in [-1.0, 1.0]:
		FastDraw.oval(_ci, c + Vector2(0.4, sgn * 4.9) * s, Vector2(1.5, 1.1) * s, sk.darkened(0.12))
	FastDraw.disc(_ci, c, 5.2 * s, sk.darkened(0.3))
	FastDraw.disc(_ci, c + L * 0.4 * s, 4.7 * s, sk)
	# the nose, just past the forehead
	FastDraw.oval(_ci, c + Vector2(5.2, 0.0) * s, Vector2(1.4, 1.05) * s, sk.darkened(0.12))
	FastDraw.disc(_ci, c + Vector2(5.3, 0.0) * s + L * 0.3, 0.6 * s, sk.lightened(0.12))
	var mus: String = _lk["mustache"]
	if mus != "" and _hat in ["", "headband", "visor", "paper"]:
		var hc: Color = (_lk["hair"] as Color).darkened(0.1)
		FastDraw.oval(_ci, c + Vector2(5.9, 0.0) * s, Vector2(0.6, 1.6 if mus != "pencil" else 1.2) * s, hc)


func _hair(c: Vector2, s: float, L: Vector2) -> void:
	var hc: Color = _lk["hair"]
	var style: String = _lk["hair_style"]
	var edge := hc.darkened(0.35)
	var hi := hc.lightened(0.28)
	hi.a = 0.75
	var small_hat := _hat in ["newsboy", "flat", "watch", "cloche"]
	match style:
		"bald":
			# the crown shines; a grey fringe round the back and sides
			var shine := _skin.lightened(0.3)
			shine.a = 0.8
			FastDraw.oval_rot(_ci, Transform2D.IDENTITY, c + L * 1.8 * s, Vector2(1.6, 1.0) * s, L.angle(), shine)
			var ring := PackedVector2Array()
			for i in 13:
				var a := PI * 0.42 + PI * 1.16 * i / 12.0
				ring.append(c + Vector2(cos(a), sin(a)) * 5.4 * s)
			for i in 13:
				var a := PI * 1.58 - PI * 1.16 * i / 12.0
				ring.append(c + Vector2(0.9, 0.0) * s + Vector2(cos(a) * 3.6, sin(a) * 3.9) * s)
			Draw.poly(_ci, ring, hc)
		"bob", "curly", "bun":
			var r := 5.9 if style != "bun" else 5.3
			var pts := PackedVector2Array()
			for i in 22:
				var a := TAU * i / 22.0
				var rr := r * (1.0 + (0.06 * sin(a * 7.0) if style == "curly" else 0.0))
				var front := cos(a) > 0.55
				if front and not small_hat:
					rr *= 0.86
				pts.append(c + Vector2(-0.5, 0.0) * s + Vector2(cos(a) * rr * 0.96, sin(a) * rr) * s)
			Draw.poly(_ci, pts, edge)
			Draw.poly(_ci, _shape_about(pts, c, 0.9, L * 0.4 * s), hc)
			if style == "bun":
				FastDraw.disc(_ci, c + Vector2(-5.2, 0.0) * s, 2.3 * s, edge)
				FastDraw.disc(_ci, c + Vector2(-5.2, 0.0) * s + L * 0.3, 1.9 * s, hc)
			if not small_hat:
				_ci.draw_arc(c, 3.6 * s, L.angle() - 0.8, L.angle() + 0.8, 10, hi, 1.1 * s, true)
				_ci.draw_line(c + Vector2(3.5, -1.6) * s, c + Vector2(-3.0, -1.8) * s, edge, 0.6, true)
		"red":
			var ph := float(look & 0xff) * 0.1
			var pts := PackedVector2Array()
			for i in 28:
				var a := TAU * i / 28.0
				var rr := 5.4 + 0.22 * sin(a * 7.0 + ph)
				rr *= lerpf(1.0, 0.78, smoothstep(0.3, 0.9, cos(a)))
				pts.append(c + Vector2(-0.6, 0.0) * s + Vector2(cos(a), sin(a)) * rr * s)
			Draw.poly(_ci, pts, _dk(hc, 0.4))
			Draw.poly(_ci, _shape_about(pts, c, 0.88, L * 0.45 * s), hc)
			for k in 5:
				var y := (k - 2) * 1.5
				_ci.draw_line(c + Vector2(3.0, y * 0.8) * s, c + Vector2(-4.2, y * 1.15) * s, _dk(hc, 0.25), 0.55, true)
			_ci.draw_arc(c + Vector2(-0.6, 0.0) * s, 3.4 * s, L.angle() - 0.7, L.angle() + 0.7, 10, _lit(hc, 0.35), 1.1 * s, true)
		"crop":
			FastDraw.oval(_ci, c + Vector2(-0.8, 0.0) * s, Vector2(4.5, 5.0) * s, edge)
			FastDraw.oval(_ci, c + Vector2(-0.8, 0.0) * s + L * 0.3, Vector2(4.0, 4.5) * s, hc)
		_:
			# short / part / slick
			FastDraw.oval(_ci, c + Vector2(-0.7, 0.0) * s, Vector2(4.7, 5.15) * s, edge)
			FastDraw.oval(_ci, c + Vector2(-0.7, 0.0) * s + L * 0.35 * s, Vector2(4.2, 4.65) * s, hc)
			if style == "slick":
				_ci.draw_arc(c + Vector2(-0.7, 0.0) * s, 3.2 * s, L.angle() - 0.7, L.angle() + 0.7, 10, hi, 1.2 * s, true)
				for k in 3:
					var y := (k - 1) * 1.6 * s
					_ci.draw_line(c + Vector2(3.0 * s, y), c + Vector2(-4.2 * s, y * 1.2), hc.lightened(0.14), 0.5, true)
			elif style == "part":
				_ci.draw_line(c + Vector2(3.4, -1.9) * s, c + Vector2(-2.6, -2.3) * s, edge.darkened(0.2), 0.8, true)
				_ci.draw_arc(c + Vector2(-0.7, 0.4) * s, 2.8 * s, L.angle() - 0.6, L.angle() + 0.6, 8, hi, 0.9 * s, true)
			else:
				_ci.draw_arc(c + Vector2(-0.7, 0.0) * s, 3.0 * s, L.angle() - 0.7, L.angle() + 0.7, 8, hi, 0.9 * s, true)


func _shape_about(pts: PackedVector2Array, c: Vector2, sc: float, off: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(pts.size())
	for i in pts.size():
		out[i] = c + (pts[i] - c) * sc + off
	return out


func _glasses(c: Vector2, s: float, _L: Vector2) -> void:
	var rim := Color("2a2622")
	for sgn: float in [-1.0, 1.0]:
		_ci.draw_line(c + Vector2(5.0, sgn * 2.6) * s, c + Vector2(0.4, sgn * 5.0) * s, rim, 0.6, true)
		FastDraw.oval(_ci, c + Vector2(5.6, sgn * 1.9) * s, Vector2(0.7, 1.3) * s, rim)
		FastDraw.disc(_ci, c + Vector2(5.8, sgn * 1.7) * s, 0.35 * s, Color(1, 1, 1, 0.7))


func _cigar(p: Vector2, s: float) -> void:
	var tip := p + Vector2(6.8, 0.7) * s
	FastDraw.capsule(_ci, p, tip, 0.95 * s, Color("3a2416"))
	FastDraw.capsule(_ci, p, tip, 0.7 * s, Color("7a4e2c"))
	FastDraw.disc(_ci, tip, 0.8 * s, Color("8a8580"))
	FastDraw.disc(_ci, tip + Vector2(0.4, 0.05) * s, 0.45 * s, Color(1.0, 0.45, 0.15))


func _felt(c: Vector2, radii: Vector2, col: Color, L: Vector2, rot: float = 0.0) -> void:
	FastDraw.oval_rot(_ci, Transform2D.IDENTITY, c, radii + Vector2(0.55, 0.55), rot, _dk(col, 0.55))
	FastDraw.oval_rot(_ci, Transform2D.IDENTITY, c + L * 0.35, radii - Vector2(0.35, 0.35), rot, col)
	var r := (radii.x + radii.y) * 0.5
	_ci.draw_arc(c, r - 0.55, L.angle() - 1.15, L.angle() + 1.15, 16, _lit(col, 0.34), 1.0, true)


func _draw_hat(h: String, c: Vector2, s: float, L: Vector2) -> void:
	var col: Color = _lk["hat_col"]
	var band: Color = _lk["band"]
	var la := L.angle()
	match h:
		"fedora":
			var bc := c + Vector2(0.4, 0.0) * s
			_felt(bc, Vector2(7.9, 7.3) * s, col, L)
			_ci.draw_arc(bc, 6.5 * s, la + PI - 1.0, la + PI + 1.0, 14, _dk(col, 0.25), 1.0 * s, true)
			# the band: a ring round the crown's base, a small bow on the left
			FastDraw.oval(_ci, c + Vector2(-0.2, 0.0) * s, Vector2(5.25, 4.7) * s, band.darkened(0.35))
			FastDraw.oval(_ci, c + Vector2(-0.2, 0.0) * s, Vector2(4.95, 4.4) * s, band)
			FastDraw.oval(_ci, c + Vector2(-1.2, -4.45) * s, Vector2(1.1, 0.75) * s, band.darkened(0.2))
			# the crown: pinched at the front, a dent down the middle
			var crown := PackedVector2Array()
			for i in 22:
				var a := TAU * i / 22.0
				var cx := cos(a)
				var sy := sin(a)
				var y := 3.95 * sy * (1.0 - 0.34 * maxf(0.0, cx) * maxf(0.0, cx))
				crown.append(c + Vector2(-0.2 + (4.2 if cx > 0.0 else 4.3) * cx, y) * s)
			var top := _lit(col, 0.17)
			Draw.poly(_ci, crown, _dk(col, 0.5))
			Draw.poly(_ci, _shape_about(crown, c, 0.88, L * 0.4 * s), top)
			# the crease and the two pinches at the front, soft
			FastDraw.oval(_ci, c + Vector2(-0.7, 0.0) * s, Vector2(2.5, 0.8) * s, top.darkened(0.12))
			for sgn: float in [-1.0, 1.0]:
				FastDraw.oval_rot(_ci, Transform2D.IDENTITY, c + Vector2(2.0, sgn * 1.45) * s, Vector2(0.8, 0.4) * s, sgn * 0.7, top.darkened(0.2))
			FastDraw.oval_rot(_ci, Transform2D.IDENTITY, c + L * 1.9 * s, Vector2(1.3, 0.8) * s, L.angle() + PI * 0.5, Color(1.0, 0.95, 0.86, 0.22))
		"homburg":
			var bc := c + Vector2(0.2, 0.0) * s
			_felt(bc, Vector2(7.3, 6.8) * s, col, L)
			# the curled, bound edge
			_ci.draw_arc(bc, 6.55 * s, 0.0, TAU, 28, band.darkened(0.1), 0.9 * s, true)
			_ci.draw_arc(bc, 5.9 * s, la - 1.3, la + 1.3, 14, col.lightened(0.26), 1.1 * s, true)
			FastDraw.oval(_ci, c + Vector2(-0.2, 0.0) * s, Vector2(5.1, 4.6) * s, band.darkened(0.3))
			FastDraw.oval(_ci, c + Vector2(-0.2, 0.0) * s, Vector2(4.85, 4.35) * s, band)
			_felt(c + Vector2(-0.2, 0.0) * s, Vector2(4.0, 3.65) * s, _lit(col, 0.15), L)
			var nrm := Vector2(0.0, -1.0) if L.y < 0.0 else Vector2(0.0, 1.0)
			FastDraw.oval(_ci, c + Vector2(-0.2, 0.0) * s - nrm * 0.2 * s, Vector2(3.0, 0.6) * s, _lit(col, 0.15).darkened(0.16))
		"bowler":
			var bc := c + Vector2(0.2, 0.0) * s
			_felt(bc, Vector2(6.5, 6.0) * s, col, L)
			_ci.draw_arc(bc, 5.9 * s, 0.0, TAU, 24, col.lightened(0.12), 0.8 * s, true)
			FastDraw.disc(_ci, c, 5.0 * s, band)
			FastDraw.disc(_ci, c, 4.55 * s, col.darkened(0.35))
			FastDraw.disc(_ci, c + L * 0.5 * s, 4.0 * s, col.lightened(0.06))
			var shine := col.lightened(0.5)
			shine.a = 0.75
			FastDraw.oval_rot(_ci, Transform2D.IDENTITY, c + L * 2.0 * s, Vector2(1.1, 2.2) * s, la, shine)
			FastDraw.disc(_ci, c + L * 2.4 * s, 0.5 * s, Color(1, 1, 1, 0.7))
		"boater":
			var bc := c + Vector2(0.2, 0.0) * s
			_felt(bc, Vector2(8.3, 8.0) * s, col, L)
			for rr: float in [7.3, 6.5]:
				_ci.draw_arc(bc, rr * s, 0.0, TAU, 30, col.darkened(0.14), 0.5, true)
			_ci.draw_arc(bc, 7.0 * s, la - 1.0, la + 1.0, 14, col.lightened(0.25), 1.0 * s, true)
			FastDraw.disc(_ci, c, 5.4 * s, band.darkened(0.3))
			FastDraw.disc(_ci, c, 5.1 * s, band)
			_ci.draw_arc(c, 4.8 * s, 0.0, TAU, 22, Pal.PAPER.darkened(0.1), 0.45 * s, true)
			FastDraw.disc(_ci, c, 4.4 * s, col.darkened(0.2))
			FastDraw.disc(_ci, c + L * 0.3 * s, 4.0 * s, col.lightened(0.06))
			_ci.draw_arc(c, 2.6 * s, 0.0, TAU, 18, col.darkened(0.1), 0.45, true)
			_ci.draw_arc(c, 1.2 * s, 0.0, TAU, 12, col.darkened(0.1), 0.45, true)
		"cloche":
			_felt(c + Vector2(-0.2, 0.0) * s, Vector2(6.5, 6.3) * s, col.darkened(0.08), L)
			_felt(c + Vector2(-0.4, 0.0) * s, Vector2(5.5, 5.3) * s, col, L)
			_ci.draw_arc(c + Vector2(-0.4, 0.0) * s, 5.3 * s, 0.0, TAU, 26, band, 1.0 * s, true)
			var glow := col.lightened(0.28)
			glow.a = 0.55
			FastDraw.oval_rot(_ci, Transform2D.IDENTITY, c + L * 2.0 * s, Vector2(2.4, 1.7) * s, la, glow)
			_ci.draw_line(c + Vector2(-4.0, 0.0) * s, c + Vector2(3.2, 0.0) * s, col.darkened(0.2), 0.6, true)
			# a little flower or brooch on the left side
			var fp := c + Vector2(0.8, -5.2) * s
			FastDraw.disc(_ci, fp, 1.2 * s, band.lightened(0.15))
			FastDraw.disc(_ci, fp, 0.55 * s, band.darkened(0.3))
		"police":
			# the black patent peak, then the flat navy top with the shield
			var peak := PackedVector2Array()
			for i in 13:
				var a := -1.35 + 2.7 * i / 12.0
				peak.append(c + Vector2(0.6 + cos(a) * 8.3, sin(a) * 5.9) * s)
			peak.append(c + Vector2(1.5, 3.0) * s)
			peak.append(c + Vector2(1.5, -3.0) * s)
			Draw.poly(_ci, peak, Color("0b0b0d"))
			_ci.draw_arc(c + Vector2(0.6, 0.0) * s, 7.5 * s, -1.0 if L.y < 0.0 else -0.2, 0.2 if L.y < 0.0 else 1.0, 12, Color(1, 1, 1, 0.45), 0.8, true)
			var top := _lit(col, 0.08)
			_felt(c, Vector2(6.4, 6.3) * s, top, L)
			_ci.draw_arc(c, 5.2 * s, 0.0, TAU, 26, _dk(col, 0.35), 0.6, true)
			FastDraw.oval_rot(_ci, Transform2D.IDENTITY, c + L * 2.2 * s, Vector2(2.6, 1.9) * s, la, Color(1, 0.95, 0.86, 0.1))
			var bp := c + Vector2(4.9, 0.0) * s
			var shield := PackedVector2Array([bp + Vector2(-1.2, -1.6) * s, bp + Vector2(1.0, -1.4) * s, bp + Vector2(1.6, 0.0) * s,
				bp + Vector2(1.0, 1.4) * s, bp + Vector2(-1.2, 1.6) * s, bp + Vector2(-0.7, 0.0) * s])
			Draw.poly(_ci, shield, Pal.BRASS.darkened(0.3))
			Draw.poly(_ci, _shape_about(shield, bp, 0.7, Vector2(-0.1, -0.1)), Pal.BRASS.lightened(0.15))
			var glint := 0.5 + 0.5 * sin(_t * 1.3 + _seed_f)
			FastDraw.disc(_ci, bp + Vector2(0.1, -0.3) * s, 0.55 * s, Color(1.0, 0.97, 0.82, 0.55 + 0.45 * glint))
			if glint > 0.9:
				_ci.draw_line(bp + Vector2(-1.8, -0.3) * s, bp + Vector2(2.2, -0.3) * s, Color(1, 1, 0.9, 0.85), 0.5, true)
				_ci.draw_line(bp + Vector2(0.1, -2.3) * s, bp + Vector2(0.1, 1.7) * s, Color(1, 1, 0.9, 0.85), 0.5, true)
		"watch":
			_felt(c + Vector2(-0.3, 0.0) * s, Vector2(5.5, 5.4) * s, col, L)
			for i in 10:
				var a := TAU * i / 10.0
				_ci.draw_line(c + Vector2(-0.3, 0.0) * s + Vector2(cos(a), sin(a)) * 1.2 * s, c + Vector2(-0.3, 0.0) * s + Vector2(cos(a), sin(a)) * 4.1 * s, col.darkened(0.22), 0.55, true)
			_ci.draw_arc(c + Vector2(-0.3, 0.0) * s, 4.7 * s, 0.0, TAU, 26, col.darkened(0.2), 1.3 * s, true)
			_ci.draw_arc(c + Vector2(-0.3, 0.0) * s, 4.7 * s, la - 0.9, la + 0.9, 10, col.lightened(0.18), 0.9 * s, true)
			FastDraw.disc(_ci, c + Vector2(-0.3, 0.0) * s, 1.0 * s, col.darkened(0.15))
		"newsboy":
			var pk := c + Vector2(3.6, 0.0) * s
			var peak := PackedVector2Array()
			for i in 11:
				var a := -1.45 + 2.9 * i / 10.0
				peak.append(pk + Vector2(cos(a) * 4.9, sin(a) * 4.6) * s)
			Draw.poly(_ci, peak, col.darkened(0.4))
			Draw.poly(_ci, _shape_about(peak, pk, 0.86, Vector2(-0.3, 0.0)), col.darkened(0.12))
			var cc := c + Vector2(-0.6, 0.0) * s
			var r := 6.2 * s
			FastDraw.disc(_ci, cc, r + 0.5, col.darkened(0.45))
			for i in 8:
				var a0 := TAU * i / 8.0 + 0.2
				var a1 := TAU * (i + 1) / 8.0 + 0.2
				var pcol := col if i % 2 == 0 else col.lightened(0.07)
				var lit := Vector2(cos((a0 + a1) * 0.5), sin((a0 + a1) * 0.5)).dot(L)
				pcol = pcol.lightened(0.12 * maxf(lit, 0.0)) if lit > 0.0 else pcol.darkened(0.15 * -lit)
				var wedge := PackedVector2Array([cc])
				for q in 4:
					var a := lerpf(a0, a1, q / 3.0)
					wedge.append(cc + Vector2(cos(a), sin(a)) * r)
				Draw.poly(_ci, wedge, pcol)
				_ci.draw_line(cc, cc + Vector2(cos(a0), sin(a0)) * r, col.darkened(0.3), 0.5, true)
			FastDraw.disc(_ci, cc, 1.0 * s, col.darkened(0.3))
			FastDraw.disc(_ci, cc + L * 0.3, 0.6 * s, col.lightened(0.15))
		"flat":
			var pts := PackedVector2Array()
			for i in 22:
				var a := TAU * i / 22.0
				var cx := cos(a)
				var rx := 7.7 if cx > 0.0 else 4.9
				var ry := 5.4 * (1.0 - 0.28 * maxf(0.0, cx))
				pts.append(c + Vector2(-0.4 + cx * rx, sin(a) * ry) * s)
			Draw.poly(_ci, pts, col.darkened(0.45))
			Draw.poly(_ci, _shape_about(pts, c, 0.9, L * 0.4 * s), col)
			_ci.draw_arc(c + Vector2(-1.0, 0.0) * s, 5.6 * s, -0.8, 0.8, 10, col.darkened(0.3), 0.7, true)
			var glow := col.lightened(0.18)
			glow.a = 0.6
			FastDraw.oval(_ci, c + L * 1.8 * s + Vector2(-0.8, 0.0) * s, Vector2(2.2, 1.6) * s, glow)
			for i in 6:
				var p := c + Vector2(lerpf(-4.0, 4.5, Draw.hash01(i, look & 0xff, 5)), lerpf(-3.5, 3.5, Draw.hash01(i, look & 0xff, 6))) * s
				Draw.rect(_ci, Rect2(p, Vector2(0.7, 0.7)), col.darkened(0.2))
		"toque":
			FastDraw.disc(_ci, c, 7.0 * s, col.darkened(0.25))
			FastDraw.disc(_ci, c + L * 0.4 * s, 6.5 * s, col)
			for i in 10:
				var a := TAU * i / 10.0
				_ci.draw_line(c + Vector2(cos(a), sin(a)) * 2.4 * s, c + Vector2(cos(a), sin(a)) * 6.4 * s, col.darkened(0.12), 0.8, true)
			var puff := col.lightened(0.5)
			puff.a = 0.7
			FastDraw.disc(_ci, c + L * 2.0 * s, 2.6 * s, puff)
			FastDraw.disc(_ci, c, 2.0 * s, col.darkened(0.06))
		"top":
			var bc := c + Vector2(0.2, 0.0) * s
			_felt(bc, Vector2(6.8, 5.9) * s, col, L)
			_ci.draw_arc(bc, 5.8 * s, la - 1.0, la + 1.0, 12, col.lightened(0.3), 0.9 * s, true)
			FastDraw.disc(_ci, c, 4.9 * s, band)
			FastDraw.disc(_ci, c, 4.6 * s, col.darkened(0.2))
			FastDraw.disc(_ci, c + L * 0.3 * s, 4.2 * s, col.lightened(0.08))
			var shine := Color(1, 1, 1, 0.35)
			_ci.draw_arc(c, 3.0 * s, la - 0.8, la + 0.8, 12, shine, 1.2 * s, true)
		"paper":
			var pts := Draw.ellipse_points(c + Vector2(-0.2, 0.0) * s, Vector2(6.3, 2.6) * s, 0.0, 18)
			Draw.poly(_ci, pts, col.darkened(0.3))
			Draw.poly(_ci, _shape_about(pts, c, 0.88, L * 0.3 * s), col)
			_ci.draw_line(c + Vector2(-5.6, 0.0) * s, c + Vector2(5.6, 0.0) * s, col.darkened(0.25), 0.7, true)
		"visor":
			var pts := PackedVector2Array()
			for i in 11:
				var a := -1.3 + 2.6 * i / 10.0
				pts.append(c + Vector2(cos(a) * 8.6, sin(a) * 5.4) * s)
			for i in 11:
				var a := 1.3 - 2.6 * i / 10.0
				pts.append(c + Vector2(cos(a) * 4.4, sin(a) * 4.8) * s)
			var vc := col
			vc.a = 0.82
			Draw.poly(_ci, pts, vc)
			_ci.draw_arc(c, 5.0 * s, 0.0, TAU, 24, Color("1e2a22"), 0.8, true)
			_ci.draw_arc(c + Vector2(1.0, 0.0) * s, 7.2 * s, -0.9, 0.9, 10, Color(1, 1, 1, 0.25), 0.7, true)
		"headband":
			_ci.draw_arc(c + Vector2(-0.4, 0.0) * s, 4.9 * s, PI * 0.35, PI * 1.65, 20, col, 1.1 * s, true)
			_ci.draw_line(c + Vector2(1.2, -4.7) * s, c + Vector2(1.2, 4.7) * s, col, 1.0 * s, true)
			var feather: Color = _lk["feather"]
			if feather.a > 0.0:
				var a := c + Vector2(0.8, -4.6) * s
				var b := c + Vector2(-7.0, -8.6) * s
				var mid := a.lerp(b, 0.5) + Vector2(-0.5, 1.2) * s
				var nrm := (b - a).normalized().orthogonal()
				Draw.poly(_ci, PackedVector2Array([a, mid + nrm * 1.6 * s, b, mid - nrm * 1.3 * s]), feather.darkened(0.1))
				_ci.draw_line(a, b, feather.darkened(0.35), 0.5, true)
			FastDraw.disc(_ci, c + Vector2(1.2, -4.7) * s, 1.0 * s, Pal.BRASS.lightened(0.2))


# ------------------------------------------------------------------ things people hold

func _draw_crate(c: Vector2, _L: Vector2) -> void:
	var r := Rect2(c - Vector2(7.0, 10.0), Vector2(14.0, 20.0))
	_ci.draw_rect(r.grow(0.7), CRATE.darkened(0.5))
	Draw.rect(_ci, r, CRATE)
	for k in 3:
		var y := r.position.y + 1.2 + k * 6.4
		Draw.rect(_ci, Rect2(Vector2(r.position.x + 1.0, y), Vector2(r.size.x - 2.0, 5.0)), CRATE.lightened(0.06 if k % 2 == 0 else 0.0))
		_ci.draw_line(Vector2(r.position.x + 1.0, y + 5.0), Vector2(r.end.x - 1.0, y + 5.0), CRATE.darkened(0.45), 0.8)
	_ci.draw_line(r.position + Vector2(1.0, 1.0), r.end - Vector2(1.0, 1.0), CRATE.darkened(0.2), 1.4, true)
	Draw.rect(_ci, Rect2(r.position, Vector2(r.size.x, 1.3)), CRATE.darkened(0.2))
	Draw.rect(_ci, Rect2(Vector2(r.position.x, r.end.y - 1.3), Vector2(r.size.x, 1.3)), CRATE.darkened(0.2))
	var hi := CRATE.lightened(0.3)
	hi.a = 0.6
	_ci.draw_line(r.position + Vector2(0.6, 0.6), Vector2(r.end.x - 0.6, r.position.y + 0.6), hi, 0.7)
	var mark := Color(0.15, 0.1, 0.06, 0.5)
	for k in 3:
		var mc := r.get_center() + Vector2(0.0, (k - 1) * 3.0)
		_ci.draw_line(mc + Vector2(-1.1, -1.1), mc + Vector2(1.1, 1.1), mark, 0.6, true)
		_ci.draw_line(mc + Vector2(-1.1, 1.1), mc + Vector2(1.1, -1.1), mark, 0.6, true)


func _draw_pistol(hand: Vector2, L: Vector2) -> void:
	var p := hand + Vector2(0.4, -0.2)
	var ang := 0.0 if _aim else 0.06
	var d := Vector2(cos(ang), sin(ang))
	var n := d.orthogonal()
	var tip := p + d * 9.4
	_ci.draw_line(p - d * 0.6, tip, Color("121316"), 3.0, true)
	_ci.draw_line(p, tip - d * 0.4, STEEL, 1.8, true)
	_ci.draw_line(p + d * 1.2 + n * 0.45 * signf(n.dot(L)), tip - d * 0.8 + n * 0.45 * signf(n.dot(L)), STEEL_HI, 0.6, true)
	_hand(hand, L, "fist")


func _gun_axis() -> Array:
	var rear := _hand_r + Vector2(-6.5, 0.9)
	var fwd := (_hand_l - _hand_r).normalized()
	if fwd.length() < 0.1:
		fwd = Vector2.RIGHT
	return [rear, fwd]


func _draw_tommy(L: Vector2) -> void:
	var ax := _gun_axis()
	var rear: Vector2 = ax[0]
	var d: Vector2 = ax[1]
	var n := d.orthogonal()
	var lit := signf(n.dot(L))
	var recv0 := rear + d * 6.5
	var recv1 := rear + d * 16.0
	var muzzle := rear + d * 28.5
	var dark := Color("121316")
	# the wooden stock
	FastDraw.taper(_ci, rear, recv0, 2.3, 1.3, WOOD.darkened(0.45))
	FastDraw.taper(_ci, rear + d * 0.5, recv0, 1.7, 0.8, WOOD)
	_ci.draw_line(rear + d * 1.0 + n * 0.9 * lit, recv0 + n * 0.5 * lit, WOOD.lightened(0.3), 0.6, true)
	# the finned barrel and the receiver
	FastDraw.capsule(_ci, recv1, muzzle, 1.55, dark)
	FastDraw.capsule(_ci, recv1, muzzle, 1.1, STEEL)
	for k in 6:
		var q := recv1 + d * (1.0 + k * 1.2)
		_ci.draw_line(q - n * 1.6, q + n * 1.6, dark, 0.7, true)
	FastDraw.capsule(_ci, recv0, recv1, 2.3, dark)
	FastDraw.capsule(_ci, recv0, recv1, 1.8, STEEL)
	_ci.draw_line(recv0 + d * 0.5 + n * 0.9 * lit, recv1 + n * 0.9 * lit, STEEL_HI, 0.6, true)
	# the drum magazine, the foregrip
	var drum := rear + d * 11.5 + n * 2.6
	FastDraw.disc(_ci, drum, 4.6, dark)
	FastDraw.disc(_ci, drum + L * 0.3, 4.0, STEEL)
	FastDraw.disc(_ci, drum, 2.9, dark)
	FastDraw.disc(_ci, drum, 2.3, STEEL)
	FastDraw.disc(_ci, drum, 0.9, dark)
	FastDraw.disc(_ci, drum + L * 2.6, 0.9, STEEL_HI)
	FastDraw.disc(_ci, rear + d * 18.0 + n * 0.6, 1.6, WOOD.darkened(0.2))
	_hand(_hand_r, L, "fist")
	_hand(_hand_l, L, "fist")


func _draw_bat(L: Vector2) -> void:
	var hand := _hand_r
	var d := Vector2(cos(_bat_ang), sin(_bat_ang))
	var n := d.orthogonal()
	var knob := hand - d * 2.4
	var end := hand + d * 26.0
	if _bat_swing:
		# a quick swoosh behind the bat
		for k in 3:
			var a2 := _bat_ang + (k + 1) * 0.18
			var d2 := Vector2(cos(a2), sin(a2))
			_ci.draw_line(hand + d2 * 10.0, hand + d2 * 26.0, Color(1, 1, 1, 0.16 - k * 0.04), 3.4 - k * 0.6, true)
	FastDraw.taper(_ci, knob, end, 0.95, 2.3, BAT.darkened(0.35))
	FastDraw.taper(_ci, knob + d * 0.3, end - d * 0.3, 0.6, 1.8, BAT)
	FastDraw.disc(_ci, end - d * 0.2, 2.2, BAT.darkened(0.2))
	FastDraw.disc(_ci, end - d * 0.2 + L * 0.3, 1.8, BAT.lightened(0.05))
	_ci.draw_line(hand + d * 3.0 + n * 0.3 * signf(n.dot(L)), end - d * 2.0 + n * 1.0 * signf(n.dot(L)), BAT.lightened(0.3), 0.7, true)
	FastDraw.disc(_ci, knob, 1.3, BAT.darkened(0.3))
	_hand(_hand_l, L, "fist")
	_hand(_hand_r, L, "fist")


func _draw_hook(hand: Vector2, L: Vector2) -> void:
	var c := hand + Vector2(3.4, 0.4)
	FastDraw.capsule(_ci, hand + Vector2(-0.4, -1.8), hand + Vector2(-0.4, 1.8), 0.9, WOOD)
	_ci.draw_line(hand, c + Vector2(-0.6, 0.0), STEEL_HI.darkened(0.2), 1.1, true)
	var hc := c + Vector2(1.6, 0.0)
	var prev := hc + Vector2(cos(PI * 0.95), sin(PI * 0.95)) * 2.2
	for k in 5:
		var a := lerpf(PI * 0.95, TAU * 0.95, (k + 1) / 5.0)
		var q := hc + Vector2(cos(a), sin(a)) * 2.2
		_ci.draw_line(prev, q, STEEL_HI.darkened(0.25), 1.1, true)
		prev = q
	_hand(hand, L, "fist")


func _draw_nightstick(hand: Vector2, L: Vector2) -> void:
	var d := Vector2(0.93, 0.36)
	var a := hand - d * 2.6
	var b := hand + d * 11.0
	FastDraw.capsule(_ci, a, b, 1.35, Color("1a120c"))
	FastDraw.capsule(_ci, a, b, 0.95, Color("5a3a24"))
	_ci.draw_line(a + L * 0.45, b + L * 0.45, Color("8a6a48"), 0.5, true)
	FastDraw.disc(_ci, a, 1.3, Color("1a120c"))
	_hand(hand, L, "fist")


func _draw_papers(c: Vector2, _L: Vector2) -> void:
	for k in 3:
		var r := Rect2(c + Vector2(-4.2 + k * 0.5, -3.0 + k * 0.4), Vector2(9.0, 5.6))
		_ci.draw_rect(r.grow(0.5), Color("5a5448"))
		_ci.draw_rect(r, Color("dcd4c0").darkened(0.04 * (2 - k)))
	var top := Rect2(c + Vector2(-3.2, -2.2), Vector2(9.0, 5.6))
	_ci.draw_rect(Rect2(top.position + Vector2(0.8, 0.8), Vector2(4.0, 1.2)), Color(0.15, 0.12, 0.1, 0.7))
	for k in 3:
		_ci.draw_line(top.position + Vector2(0.8, 2.6 + k * 0.9), top.position + Vector2(top.size.x - 0.8, 2.6 + k * 0.9), Color(0.2, 0.18, 0.15, 0.35), 0.5)
	_ci.draw_line(top.get_center() + Vector2(0, -3.2), top.get_center() + Vector2(0, 3.2), Color("7a5a36"), 0.6)


func _muzzle_local() -> Vector2:
	if weapon == "tommy":
		var ax := _gun_axis()
		return (ax[0] as Vector2) + (ax[1] as Vector2) * 29.5
	return _hand_r + Vector2(10.6, -0.2)


func _draw_muzzle(p: Vector2) -> void:
	if _smoke > 0.0:
		var a := (1.0 - _smoke) * 0.35
		FastDraw.disc(_ci, p + Vector2(2.0 + _smoke * 5.0, -_smoke * 2.0), 2.0 + _smoke * 4.0, Color(0.75, 0.73, 0.7, a))
		FastDraw.disc(_ci, p + Vector2(0.5 + _smoke * 2.5, _smoke * 1.5), 1.5 + _smoke * 2.5, Color(0.7, 0.68, 0.66, a * 0.8))
	if _flash <= 0.0:
		return
	var f := _flash
	var rot := Draw.hash01(int(_action_t * 100.0), look & 0xff, 3) * 1.2
	var pts := PackedVector2Array()
	for i in 10:
		var a := TAU * i / 10.0 + rot
		var rr := (7.5 if i % 2 == 0 else 2.2) * (0.7 + 0.3 * f)
		if i == 0:
			rr *= 1.5
		pts.append(p + Vector2(cos(a) * rr * 1.3, sin(a) * rr))
	FastDraw.disc(_ci, p, 8.0 * f, Color(1.0, 0.6, 0.2, 0.28 * f))
	Draw.poly(_ci, pts, Color(1.0, 0.7, 0.3, 0.9 * f))
	FastDraw.disc(_ci, p, 2.6 * f, FLASH)
	FastDraw.disc(_ci, p, 1.4 * f, Color(1, 1, 1, f))


func _draw_impact(p: Vector2, f: float) -> void:
	for i in 5:
		var a := -1.0 + i * 0.5
		var d := Vector2(cos(a), sin(a))
		_ci.draw_line(p + d * (2.0 + (1.0 - f) * 3.0), p + d * (5.0 + (1.0 - f) * 4.0), Color(1, 0.96, 0.86, f), 1.2, true)


# ------------------------------------------------------------------ lying on the ground

## Lying: the pool and the shadow on the ground (this node).
func _draw_lying_ground(L: Vector2, S: Vector2) -> void:
	var f := maxf(smoothstep(0.0, 1.0, clampf(_down_t / 0.32, 0.0, 1.0)), 0.05)
	var fy := lerpf(0.65, 1.0, f)
	var hw := _hw
	# the pool of blood spreads from under him
	if state == Anim.DEAD and _dead_t > 0.4:
		var g := 1.0 - exp(-(_dead_t - 0.4) / 2.6)
		var pc := Vector2(-13.0, 1.5)
		var pts := PackedVector2Array()
		for i in 34:
			var a := TAU * i / 34.0
			var rr := 23.0 * g * (1.0 + 0.16 * sin(a * 3.0 + _pool[0]) + 0.09 * sin(a * 5.0 + _pool[1]) + 0.05 * sin(a * 8.0 + _pool[2]))
			pts.append(pc + Vector2(cos(a) * rr * 1.25, sin(a) * rr))
		Draw.poly(_ci, pts, BLOOD)
		Draw.poly(_ci, _shape_about(pts, pc, 0.74, Vector2(0.5, 0.3)), Color(0.27, 0.025, 0.03, 0.92))
		_ci.draw_arc(pc, 15.0 * g, L.angle() - 0.45, L.angle() + 0.45, 10, Color(1, 0.75, 0.75, 0.2), 1.2, true)
	_soft_shadow(S * 0.45 + Vector2(-2.0 * f, 0.0), Vector2(31.0 * f + 2.0, (hw + 3.0) * fy), 0.0, 0.8)


## Lying: the body itself, drawn once at full length (the fall is the layer's scale).
func _draw_lying_body(L: Vector2) -> void:
	var hw := _hw
	var dead := state == Anim.DEAD
	var coat: String = _lk["coat"]
	var long_coat := coat in ["overcoat", "trench", "peacoat", "coat_w"]
	var dress := coat in ["dress", "flapper"]
	var trousers: Color = _lk["trousers"]
	var shoes: Color = _lk["shoes"]
	var skin := _skin
	# legs
	var leg_col := trousers if not (_female and coat != "tux") else skin.darkened(0.18)
	var lr := 3.1 * sqrt(_w) if not _female else 2.3
	var knees := [Vector2(14.0, -5.0 * _w), Vector2(13.0, 7.6 * _w) if _variant == 0 else Vector2(14.5, 5.2 * _w)]
	var ankles := [Vector2(25.0, -6.2 * _w), Vector2(23.0, 5.4 * _w) if _variant == 0 else Vector2(25.5, 6.4 * _w)]
	for i in 2:
		var hip := Vector2(3.0, (-4.0 if i == 0 else 4.0) * _w)
		var kn: Vector2 = knees[i]
		var an: Vector2 = ankles[i]
		FastDraw.capsule(_ci, hip, kn, lr + 0.6, leg_col.darkened(0.4))
		FastDraw.capsule(_ci, kn, an, lr * 0.92 + 0.6, leg_col.darkened(0.4))
		FastDraw.capsule(_ci, hip, kn, lr, leg_col)
		FastDraw.capsule(_ci, kn, an, lr * 0.92, leg_col)
		if kind in ["kid", "newsboy"]:
			FastDraw.capsule(_ci, kn, an, lr * 0.7, skin.darkened(0.08))
		var toe := an + Vector2(2.2, (-1.0 if i == 0 else 1.0) * 0.8)
		var srad := Vector2(2.6, 2.1) if not _female else Vector2(2.0, 1.5)
		FastDraw.oval_rot(_ci, Transform2D.IDENTITY, toe, srad + Vector2(0.5, 0.5), (-0.5 if i == 0 else 0.5), shoes.darkened(0.5))
		FastDraw.oval_rot(_ci, Transform2D.IDENTITY, toe, srad, (-0.5 if i == 0 else 0.5), shoes)
		FastDraw.disc(_ci, toe + L * 0.8, 0.8, shoes.lightened(0.3))
	# the body, face up
	var hem := 3.5
	if long_coat:
		hem = 13.0
	elif dress:
		hem = 12.5
	elif String(_lk["apron"]) != "":
		hem = 4.0
	var body := PackedVector2Array([Vector2(-21.0, -hw * 0.5), Vector2(-20.2, -hw * 0.92), Vector2(-17.5, -hw * 1.02),
		Vector2(-6.0, -hw * 0.86), Vector2(hem - 1.0, -hw * (0.8 if long_coat or dress else 0.72)), Vector2(hem, -hw * 0.4),
		Vector2(hem, hw * 0.4), Vector2(hem - 1.0, hw * (0.8 if long_coat or dress else 0.72)), Vector2(-6.0, hw * 0.86),
		Vector2(-17.5, hw * 1.02), Vector2(-20.2, hw * 0.92), Vector2(-21.0, hw * 0.5)])
	var bcol := _coat
	var shirt: Color = _lk["shirt"]
	if coat == "flapper":
		Draw.poly(_ci, body, skin.darkened(0.35))
		Draw.poly(_ci, _shape_about(body, Vector2(-8.0, 0.0), 0.93, L * 0.4), skin)
		var dr := PackedVector2Array([Vector2(-16.5, -hw * 0.62), Vector2(hem, -hw * 0.78), Vector2(hem, hw * 0.78), Vector2(-16.5, hw * 0.62)])
		Draw.poly(_ci, dr, bcol.darkened(0.3))
		Draw.poly(_ci, _shape_about(dr, Vector2(-3.0, 0.0), 0.94, L * 0.3), bcol)
		for sgn: float in [-1.0, 1.0]:
			_ci.draw_line(Vector2(-16.5, sgn * hw * 0.5), Vector2(-20.0, sgn * hw * 0.5), bcol.darkened(0.2), 0.8, true)
		for i in 16:
			var p := Vector2(lerpf(-15.0, hem - 1.5, Draw.hash01(look & 0xfff, i, 3)), lerpf(-hw * 0.6, hw * 0.6, Draw.hash01(look & 0xfff, i, 4)))
			FastDraw.disc(_ci, p, 0.45, bcol.lightened(0.45))
		if bool(_lk["pearls"]):
			for i in 12:
				var a := -PI * 0.5 + PI * i / 11.0
				FastDraw.disc(_ci, Vector2(-20.0, 0.0) + Vector2(cos(a) * 9.0, sin(a) * 3.8), 0.6, Color("f4efe4"))
	else:
		Draw.poly(_ci, body, bcol.darkened(0.42))
		Draw.poly(_ci, _shape_about(body, Vector2(-8.0, 0.0), 0.92, L * 0.5), bcol)
		var sheen := bcol.lightened(0.14)
		sheen.a = 0.5
		FastDraw.oval(_ci, Vector2(-12.0, 0.0) + L * 3.0, Vector2(6.0, hw * 0.55), sheen)
		_lying_front(coat, bcol, shirt, hem, L)
	var apron: String = _lk["apron"]
	if apron != "":
		var acol := PersonLook.WHITE
		match apron:
			"leather": acol = PersonLook.LEATHER
			"canvas": acol = PersonLook.CANVAS
			"rubber": acol = PersonLook.RUBBER
		var ar := Rect2(Vector2(-16.0, -hw * 0.62), Vector2(27.0, hw * 1.24))
		Draw.rrect(_ci, ar.grow(0.5), 2.0, acol.darkened(0.3))
		Draw.rrect(_ci, ar, 2.0, acol)
		if apron == "striped":
			for k in 5:
				var y := lerpf(ar.position.y + 1.4, ar.end.y - 1.4, k / 4.0)
				_ci.draw_line(Vector2(ar.position.x + 0.8, y), Vector2(ar.end.x - 0.8, y), Color("3a4a6e"), 0.9, true)
		for sgn: float in [-1.0, 1.0]:
			_ci.draw_line(Vector2(-16.0, sgn * hw * 0.5), Vector2(-21.0, sgn * 2.8), acol.darkened(0.1), 0.9, true)
		_ci.draw_line(Vector2(-5.0, -hw * 0.62), Vector2(-5.0, -hw * 0.9), acol.darkened(0.2), 0.8, true)
	# arms
	var sh_l := Vector2(-18.0, -(hw - 0.6))
	var sh_r := Vector2(-18.0, hw - 0.6)
	if _variant == 0:
		_arm(sh_l, Vector2(-11.0, -(hw + 5.0)), Vector2(-3.5, -(hw + 6.5)), L, _lk["armband"], _p_garters, "open", false)
		_arm(sh_r, Vector2(-26.0, hw + 4.5), Vector2(-32.0, hw + 1.0), L, NONE, _p_garters, "open", true)
	else:
		_arm(sh_l, Vector2(-9.0, -(hw + 3.5)), Vector2(-0.5, -(hw + 1.0)), L, _lk["armband"], _p_garters, "", false)
		_arm(sh_r, Vector2(-10.0, hw + 4.0), Vector2(-1.5, hw + 5.0), L, NONE, _p_garters, "open", true)
	if weapon != "" and dead:
		# the gun slid out of his hand
		var gp := Vector2(-4.0, hw + 12.0)
		Draw.poly(_ci, PackedVector2Array([gp + Vector2(-3.0, -1.0), gp + Vector2(5.0, -1.4), gp + Vector2(5.0, 0.4), gp + Vector2(-3.0, 1.0)]), STEEL)
	# the head, face up
	_face_up(Vector2(-26.5, 0.0), L, dead)


## Lying: the hat that flew off (the head layer, placed by _place_parts).
func _draw_fallen_hat(L: Vector2) -> void:
	if _hat == "":
		return
	FastDraw.oval(_ci, -L * 1.2, Vector2(_brim_radius(), _brim_radius() * 0.94) * _hs, Color(0, 0, 0, 0.22))
	_draw_hat(_hat, Vector2.ZERO, _hs, L)


## Dazed: little stars turning over his head.
func _draw_stars() -> void:
	if state != Anim.DOWN or _down_t < 0.32:
		return
	for i in 3:
		var a := _t * 3.2 + i * TAU / 3.0
		var p := Vector2(-26.5, 0.0) + Vector2(cos(a) * 7.5, sin(a) * 6.0)
		_star(p, 2.4, Pal.GOLD2)


func _lying_front(coat: String, bcol: Color, shirt: Color, hem: float, L: Vector2) -> void:
	var hw := _hw
	var tie: String = _lk["tie"]
	var tie_col: Color = _lk["tie_col"]
	var edge := bcol.darkened(0.42)
	match coat:
		"suit", "three", "tux", "overcoat", "trench", "peacoat", "jacket", "cardigan":
			var vx := -9.0 if coat != "tux" else -7.0
			if coat == "three":
				Draw.poly(_ci, PackedVector2Array([Vector2(-20.8, -4.6), Vector2(-2.0, -3.2), Vector2(-2.0, 3.2), Vector2(-20.8, 4.6)]), bcol.darkened(0.22))
			Draw.poly(_ci, PackedVector2Array([Vector2(-20.8, -3.6), Vector2(vx, 0.0), Vector2(-20.8, 3.6)]), shirt)
			if tie == "tie":
				Draw.poly(_ci, PackedVector2Array([Vector2(-20.6, -0.9), Vector2(vx + 1.5, -0.8), Vector2(vx + 0.5, 0.0), Vector2(vx + 1.5, 0.8), Vector2(-20.6, 0.9)]), tie_col)
			elif tie == "bow":
				_bow_tie(Vector2(-19.4, 0.0), tie_col)
			var lap := bcol.lightened(0.1) if coat != "tux" else Color("2a2a30")
			var wide := 3.0 if coat in ["peacoat", "overcoat", "trench"] else 2.0
			for sgn: float in [-1.0, 1.0]:
				Draw.poly(_ci, PackedVector2Array([Vector2(-20.8, sgn * 3.6), Vector2(-20.4, sgn * (3.6 + wide + 1.5)), Vector2(vx - 1.0, sgn * 1.4), Vector2(vx, 0.0)]), lap)
				_ci.draw_line(Vector2(-20.4, sgn * (3.6 + wide + 1.5)), Vector2(vx - 1.0, sgn * 1.4), edge, 0.7, true)
			_ci.draw_line(Vector2(vx, 0.0), Vector2(hem - 0.5, 0.0), edge, 0.8, true)
			var nb := 3 if coat == "peacoat" else 2
			for k in nb:
				var x := vx + 2.5 + k * 3.6
				if coat in ["peacoat", "trench", "overcoat"]:
					FastDraw.disc(_ci, Vector2(x, -2.4), 0.8, edge)
					FastDraw.disc(_ci, Vector2(x, 2.4), 0.8, edge)
				else:
					FastDraw.disc(_ci, Vector2(x, 0.9), 0.65, edge)
			for sgn: float in [-1.0, 1.0]:
				_ci.draw_line(Vector2(-3.0, sgn * hw * 0.52), Vector2(1.0, sgn * hw * 0.5), edge, 0.7, true)
			var flower: Color = _lk["flower"]
			if flower.a > 0.0:
				FastDraw.disc(_ci, Vector2(-16.5, -6.0), 1.5, flower.darkened(0.3))
				FastDraw.disc(_ci, Vector2(-16.7, -6.2), 1.1, flower)
			var fur: Color = _lk["fur"]
			if fur.a > 0.0:
				for i in 9:
					var y := lerpf(-hw * 0.9, hw * 0.9, i / 8.0)
					FastDraw.disc(_ci, Vector2(-20.2 + absf(y) * 0.12, y), 1.9, fur.darkened(0.25))
					FastDraw.disc(_ci, Vector2(-20.5 + absf(y) * 0.12, y - 0.3), 1.3, fur)
			var scarf: Color = _lk["scarf"]
			if scarf.a > 0.0:
				for sgn: float in [-1.0, 1.0]:
					Draw.poly(_ci, PackedVector2Array([Vector2(-21.0, sgn * 2.6), Vector2(-21.0, sgn * 5.4), Vector2(-8.0, sgn * 4.6), Vector2(-8.5, sgn * 2.4)]), scarf)
		"tunic":
			_ci.draw_line(Vector2(-20.5, 0.0), Vector2(hem - 0.5, 0.0), edge, 0.8, true)
			for k in 4:
				var x := -18.0 + k * 4.6
				for sgn: float in [-1.0, 1.0]:
					FastDraw.disc(_ci, Vector2(x, sgn * 2.8), 0.8, Pal.BRASS.darkened(0.3))
					FastDraw.disc(_ci, Vector2(x - 0.15, sgn * 2.8 - 0.15), 0.5, Pal.BRASS.lightened(0.15))
			Draw.rect(_ci, Rect2(-1.5, -hw * 0.74, 2.4, hw * 1.48), Color("141210"))
			Draw.rect(_ci, Rect2(-1.2, -1.2, 1.8, 2.4), Pal.BRASS)
			var bp := Vector2(-14.5, -5.6)
			Draw.poly(_ci, PackedVector2Array([bp + Vector2(-1.2, -1.1), bp + Vector2(1.3, -1.1), bp + Vector2(1.4, 0.3), bp + Vector2(0.1, 1.4), bp + Vector2(-1.3, 0.3)]), Pal.BRASS)
			Draw.rect(_ci, Rect2(-21.0, -2.8, 1.6, 5.6), bcol.darkened(0.15))
		"shirt", "vest", "sweater", "whitejacket":
			var vest: Color = _lk["vest"]
			var braces: Color = _lk["braces"]
			if coat == "vest" or vest.a > 0.0:
				var v := PackedVector2Array([Vector2(-17.0, -hw * 0.66), Vector2(-20.0, -3.2), Vector2(-9.0, 0.0), Vector2(-20.0, 3.2), Vector2(-17.0, hw * 0.66), Vector2(2.0, hw * 0.6), Vector2(3.5, 0.0), Vector2(2.0, -hw * 0.6)])
				Draw.poly(_ci, v, vest.darkened(0.35))
				Draw.poly(_ci, _shape_about(v, Vector2(-7.0, 0.0), 0.92, L * 0.3), vest)
				for k in 3:
					FastDraw.disc(_ci, Vector2(-7.0 + k * 3.0, 0.0), 0.55, vest.darkened(0.5))
			elif braces.a > 0.0:
				for sgn: float in [-1.0, 1.0]:
					_ci.draw_line(Vector2(-20.5, sgn * 4.0), Vector2(3.0, sgn * 4.2), braces, 1.3, true)
			for sgn: float in [-1.0, 1.0]:
				Draw.poly(_ci, PackedVector2Array([Vector2(-21.0, sgn * 3.4), Vector2(-18.4, sgn * 3.6), Vector2(-20.2, sgn * 0.6)]), shirt.lightened(0.08))
			if tie == "tie":
				Draw.poly(_ci, PackedVector2Array([Vector2(-20.5, -0.9), Vector2(-9.0, -0.8), Vector2(-8.0, 0.0), Vector2(-9.0, 0.8), Vector2(-20.5, 0.9)]), tie_col)
			elif tie == "bow":
				_bow_tie(Vector2(-19.6, 0.0), tie_col)
			elif tie == "neckerchief":
				Draw.poly(_ci, PackedVector2Array([Vector2(-21.0, -3.0), Vector2(-15.0, 0.0), Vector2(-21.0, 3.0)]), tie_col)
			if coat == "whitejacket":
				for k in 3:
					FastDraw.disc(_ci, Vector2(-16.0 + k * 5.0, 3.0), 0.55, bcol.darkened(0.3))
			_ci.draw_line(Vector2(0.0, -hw * 0.7), Vector2(0.0, hw * 0.7), bcol.darkened(0.3), 0.8, true)
		"dress", "coat_w":
			FastDraw.oval(_ci, Vector2(-19.8, 0.0), Vector2(1.8, 3.4), _skin.darkened(0.06))
			if bool(_lk["pearls"]):
				for i in 10:
					var a := -PI * 0.5 + PI * i / 9.0
					FastDraw.disc(_ci, Vector2(-19.5, 0.0) + Vector2(cos(a) * 5.5, sin(a) * 3.6), 0.55, Color("f4efe4"))
			_ci.draw_line(Vector2(-4.0, -hw * 0.8), Vector2(-4.0, hw * 0.8), bcol.darkened(0.25), 0.9, true)
			var fur: Color = _lk["fur"]
			if fur.a > 0.0:
				for i in 9:
					var y := lerpf(-hw * 0.9, hw * 0.9, i / 8.0)
					FastDraw.disc(_ci, Vector2(-20.2 + absf(y) * 0.12, y), 1.9, fur.darkened(0.25))
					FastDraw.disc(_ci, Vector2(-20.5 + absf(y) * 0.12, y - 0.3), 1.3, fur)


## A face seen from above while he lies on his back: the crown of the head points to -x.
func _face_up(c: Vector2, L: Vector2, dead: bool) -> void:
	var sk := _skin
	var s := _hs
	var hair: Color = _lk["hair"]
	var style: String = _lk["hair_style"]
	Draw.rect(_ci, Rect2(c + Vector2(2.5, -2.0) * s, Vector2(3.0, 4.0) * s), sk.darkened(0.12))
	for sgn: float in [-1.0, 1.0]:
		FastDraw.oval(_ci, c + Vector2(-0.2, sgn * 5.0) * s, Vector2(1.3, 1.0) * s, sk.darkened(0.15))
	# hair spreading on the ground behind the head
	if _female:
		var pts := PackedVector2Array([c + Vector2(1.5, -5.8) * s])
		for i in 18:
			var a := PI * 1.5 - PI * i / 17.0
			pts.append(c + Vector2(cos(a) * 7.2, sin(a) * 6.6) * s)
		pts.append(c + Vector2(1.5, 5.8) * s)
		Draw.poly(_ci, pts, hair.darkened(0.2))
	FastDraw.oval(_ci, c, Vector2(5.4, 4.9) * s, sk.darkened(0.3))
	FastDraw.oval(_ci, c + L * 0.4, Vector2(4.9, 4.4) * s, sk)
	var hp := PackedVector2Array()
	var back := 5.6 if style != "bald" else 5.0
	var front := -1.2 if style != "bald" else -3.4
	for i in 13:
		var a := PI * 0.5 + PI * i / 12.0
		hp.append(c + Vector2(cos(a) * back, sin(a) * 5.0) * s)
	for i in 7:
		var y := lerpf(-4.6, 4.6, i / 6.0)
		hp.append(c + Vector2(front + 0.6 * (1.0 - pow(y / 4.6, 2.0)), y) * s)
	Draw.poly(_ci, hp, hair)
	if style == "bald":
		FastDraw.oval(_ci, c + Vector2(-2.0, -1.0) * s, Vector2(1.2, 1.6) * s, sk.lightened(0.25))
	# brows, closed eyes, nose, mouth
	var line := sk.darkened(0.55)
	for sgn: float in [-1.0, 1.0]:
		_ci.draw_line(c + Vector2(-0.2, sgn * 1.2) * s, c + Vector2(-0.2, sgn * 3.2) * s, hair.darkened(0.2), 0.8, true)
		_ci.draw_arc(c + Vector2(0.9, sgn * 2.1) * s, 0.9 * s, -PI * 0.5 + 0.3, PI * 0.5 - 0.3, 6, line, 0.6, true)
	FastDraw.oval(_ci, c + Vector2(2.2, 0.0) * s, Vector2(1.0, 0.7) * s, sk.darkened(0.1))
	FastDraw.disc(_ci, c + Vector2(2.1, -0.2) * s + L * 0.3, 0.4 * s, sk.lightened(0.2))
	var lip: Color = _lk["lipstick"]
	var mouth_col := lip if lip.a > 0.0 else sk.darkened(0.4)
	_ci.draw_line(c + Vector2(3.7, -1.2) * s, c + Vector2(3.7, 1.2) * s, mouth_col, 0.8 if lip.a == 0.0 else 1.1, true)
	var mus: String = _lk["mustache"]
	if mus != "":
		FastDraw.oval(_ci, c + Vector2(3.0, 0.0) * s, Vector2(0.6, 1.8 if mus != "pencil" else 1.3) * s, hair.darkened(0.1))
	if bool(_lk["glasses"]):
		for sgn: float in [-1.0, 1.0]:
			_ci.draw_arc(c + Vector2(0.9, sgn * 2.1) * s, 1.3 * s, 0.0, TAU, 10, Color("2a2622"), 0.55, true)
	if dead:
		FastDraw.oval(_ci, c + Vector2(4.4, 0.8) * s, Vector2(0.6, 0.9) * s, Color(0.3, 0.02, 0.03, 0.8))


func _star(p: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		var a := TAU * i / 8.0 + _t * 2.0
		var rr := r if i % 2 == 0 else r * 0.38
		pts.append(p + Vector2(cos(a), sin(a)) * rr)
	Draw.poly(_ci, pts, col.darkened(0.2))
	FastDraw.disc(_ci, p, r * 0.35, Color(1, 1, 0.9))
