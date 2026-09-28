class_name Person2D
extends Node2D
## A person seen from above, drawn procedurally. STUB: the real art replaces the _draw below;
## the API is the contract (docs/REBUILD_2D.md, "Person2D").
##
## The node's rotation is where the person faces (0 = east, +x). Draw facing +x. Shadows are
## cast down-right in WORLD space, so undo the node rotation when drawing them.
## Size: shoulders about 0.55 m (26 px at W.M = 48).

enum Anim {IDLE, WALK, RUN, CARRY, TALK, ARMS, DOWN, DEAD, SIT}

var kind := "ped"          # boss, aiboss, crew, cop, ped, shop, recruit, smuggler, dealer, docker,
						   # unionboss, consigliere, bartender, patron, fed, newsboy, woman, kid
var look := 0              # seed: skin, clothes, hat, build all come from this
var family_color := Color(0, 0, 0, 0)
var extra := {}            # e.g. {"trade": "bakery"} for a shopkeeper's apron and hat
var state: int = Anim.IDLE
var speed := 0.0           # metres a second, for the walk cycle
var carrying := false
var weapon := ""           # "", "pistol", "tommy", "bat"
var _t := 0.0
var _action := ""
var _action_t := 0.0


func setup(k: String, lk: int, fam_color: Color = Color(0, 0, 0, 0), ex: Dictionary = {}) -> void:
	kind = k
	look = lk
	family_color = fam_color
	extra = ex
	queue_redraw()


## Called every frame by the Actor: the looping state and how fast it's moving.
func set_motion(st: int, spd: float) -> void:
	state = st
	speed = spd


## One-shot animations: "punch", "hit" (got hit), "shoot", "yes" (nod / cheer), "no" (head shake),
## "interact" (reach forward), "pickup", "down" (knocked down), "die", "smash" (swing at an object),
## "threaten" (point / grab), "talk" (gesture).
func action(name: String) -> void:
	_action = name
	_action_t = 0.0
	if name == "down":
		state = Anim.DOWN
	elif name == "die":
		state = Anim.DEAD


## Return to a looping state after being down.
func play(st: int) -> void:
	state = st
	_action = ""


func carry(on: bool) -> void:
	carrying = on


func set_weapon(w: String) -> void:
	weapon = w


func _process(delta: float) -> void:
	_t += delta
	if _action != "":
		_action_t += delta
		if _action_t > 0.6 and _action not in ["down", "die"]:
			_action = ""
	queue_redraw()


func _draw() -> void:
	# placeholder: body, head, a facing tick
	var down := state in [Anim.DOWN, Anim.DEAD]
	var body := Color(0.2, 0.2, 0.22) if kind != "cop" else Color(0.15, 0.2, 0.4)
	if family_color.a > 0.0 and kind in ["boss", "crew", "aiboss"]:
		body = family_color.darkened(0.5)
	if down:
		Draw.ellipse(self, Vector2.ZERO, Vector2(22, 10), body)
		return
	Draw.ellipse(self, Vector2.ZERO, Vector2(9, 13), body)
	Draw.circle(self, Vector2(1, 0), 6.0, Color(0.9, 0.75, 0.6))
	draw_line(Vector2(4, 0), Vector2(14, 0), Color.WHITE, 2.0)
	if carrying:
		Draw.rect(self, Rect2(8, -8, 12, 16), Color(0.6, 0.45, 0.3))
