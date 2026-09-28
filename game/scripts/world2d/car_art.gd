class_name CarArt
extends Node2D
## A 1920s car or truck seen from above, drawn procedurally. STUB: the real art replaces _draw;
## the API is the contract (docs/REBUILD_2D.md, "CarArt").
## The node's rotation is the heading (0 = east, +x): draw the car nose-right. Shadows go
## down-right in world space (undo the rotation for them).

const SIZES := {        # length, width in metres
	"truck": Vector2(5.4, 2.1), "sedan": Vector2(4.3, 1.8), "touring": Vector2(4.5, 1.8),
	"taxi": Vector2(4.3, 1.8), "police": Vector2(4.4, 1.8), "van": Vector2(4.8, 1.95),
	"delivery": Vector2(5.0, 2.0),
}
const MAX_LOAD := 10

var kind := "sedan"
var body_color := Pal.CAR_BLACK
var family_color := Color(0, 0, 0, 0)
var load := 0
var night := 0.0
var speed := 0.0
var steer := 0.0


func setup(k: String, body: Color = Color(0, 0, 0, 0), fam_color: Color = Color(0, 0, 0, 0), seed_value: int = 0) -> void:
	kind = k
	family_color = fam_color
	body_color = body if body.a > 0.0 else Pal.CAR_BLACK
	queue_redraw()


## Length and width in metres (for collision shapes).
func size_m() -> Vector2:
	return SIZES.get(kind, Vector2(4.3, 1.8))


func set_load(n: int) -> void:
	load = clampi(n, 0, MAX_LOAD)
	queue_redraw()


## 0 = day, 1 = full night: headlamps and tail lamps glow on the body (the light they throw on
## the street is done by the World's light layer).
func set_lights(v: float) -> void:
	night = v
	queue_redraw()


## Called every frame while it moves: speed in m/s (negative = reversing), steer -1..1.
func set_motion(spd: float, st: float) -> void:
	speed = spd
	steer = st


func _draw() -> void:
	var s := size_m() * W.M
	var r := Rect2(-s * 0.5, s)
	Draw.rrect(self, r, 10.0, body_color)
	if family_color.a > 0.0:
		draw_rect(Rect2(s.x * 0.1, -s.y * 0.5, 8, s.y), family_color)
	for k in load:
		Draw.rect(self, Rect2(-s.x * 0.45 + (k % 5) * 18, -s.y * 0.35 + (k / 5) * 24, 16, 20), Color(0.6, 0.45, 0.3))
