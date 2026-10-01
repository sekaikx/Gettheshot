class_name Puppet3D
extends Node3D
## The 3D body of one Actor. The Actor (2D, the simulation) keeps moving and deciding; its Person2D
## forwards every animation call here (Person2D.mirror), and View3D copies its position and heading
## each frame. Wraps a Person (class Person: the Quaternius cast, scripts/cine/person3d.gd).

## Person2D.Anim -> Person.Anim, by name (the two enums are ordered differently).
const ANIM_MAP := {
	Person2D.Anim.IDLE: Person.Anim.IDLE, Person2D.Anim.WALK: Person.Anim.WALK,
	Person2D.Anim.RUN: Person.Anim.RUN, Person2D.Anim.CARRY: Person.Anim.CARRY,
	Person2D.Anim.TALK: Person.Anim.TALK, Person2D.Anim.ARMS: Person.Anim.ARMS,
	Person2D.Anim.DOWN: Person.Anim.DOWN, Person2D.Anim.DEAD: Person.Anim.DEAD,
	Person2D.Anim.SIT: Person.Anim.SIT,
}
## Person2D kind -> Person kind (+ body). Person knows: boss, crew, cop, fed, ped, shop, recruit,
## dock, union, dealer, smuggler.
const KIND_MAP := {
	"aiboss": "boss", "consigliere": "boss", "docker": "dock", "unionboss": "union", "newsboy": "ped",
	"bartender": "shop", "patron": "ped", "woman": "ped", "kid": "ped", "thug": "crew", "debtor": "ped",
}

var person: Person
var actor: Node          # the Actor this body belongs to (null for cinematic extras)
var kind := ""
var _scale := 1.0


## kind/look/color/extra are what Person2D.setup received.
func setup(k: String, look: int, fam_color: Color = Color(0, 0, 0, 0), extra: Dictionary = {}) -> void:
	kind = k
	var k3: String = KIND_MAP.get(k, k)
	var body := ""
	if k == "woman":
		body = "woman"
	elif k in ["ped", "patron"]:
		body = ""        # Person picks man / woman / elder from the look
	person = Person.new()
	person.setup(k3, look, fam_color, body)
	add_child(person)
	if k == "kid":
		_scale = 0.72
		person.scale = Vector3.ONE * _scale
	set_ring(Color(0, 0, 0, 0))


func set_motion(st: int, spd: float) -> void:
	person.set_motion(ANIM_MAP.get(st, Person.Anim.IDLE), spd)


func play(st: int) -> void:
	person.play(ANIM_MAP.get(st, Person.Anim.IDLE))


## Person2D action names: punch hit shoot yes no interact pickup down die smash threaten talk.
func action(what: String) -> void:
	match what:
		"smash":
			person.action("punch")
		"threaten":
			person.action("interact")
		"talk":
			person.action("yes")
		_:
			person.action(what)


func carry(on: bool) -> void:
	person.carry(on)


func set_weapon(_w: String) -> void:
	pass       # the pistol shows while shooting (Person._show_gun)


func set_ring(c: Color) -> void:
	person.set_ring_visible(c.a > 0.0)
