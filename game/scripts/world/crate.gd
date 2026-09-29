class_name Crate
extends Node2D
## A crate of bootleg whisky on the ground, or a bundle of dropped cash. Picked up with E.

var item_id := 0
var kind := "crate"
var amount := 0
var _t := 0.0


func setup(id: int, k: String, amt: int) -> void:
	item_id = id
	kind = k
	amount = amt
	z_index = W.Z_ITEMS
	rotation = Draw.hash01(id, 7) * 0.6 - 0.3
	queue_redraw()


func _process(delta: float) -> void:
	if kind == "cash":
		_t += delta
		queue_redraw()


func _draw() -> void:
	var s := W.M
	if kind == "crate":
		var r := Rect2(Vector2(-0.31, -0.25) * s, Vector2(0.62, 0.5) * s)
		Draw.rect(self, Rect2(r.position + Vector2(4, 5), r.size), Pal.SHADOW)
		Draw.rect(self, r, Color("8a6a44"), true)
		for k in 4:
			var y := r.position.y + (k + 0.5) * r.size.y / 4.0
			draw_line(Vector2(r.position.x + 2, y), Vector2(r.end.x - 2, y), Color("6a4e30"), 1.0)
		draw_rect(r, Color("4e3822"), false, 2.0)
		draw_line(r.position, r.end, Color("5e4428"), 2.0)
		Draw.text(self, Vector2(0, 4), "XXX", 11, Color("2a1c10"), W.font("cond"), HORIZONTAL_ALIGNMENT_CENTER)
	else:
		var bob := sin(_t * 3.0) * 1.5
		var r := Rect2(Vector2(-0.16, -0.08) * s + Vector2(0, bob), Vector2(0.32, 0.16) * s)
		Draw.rect(self, Rect2(r.position + Vector2(3, 4 - bob), r.size), Pal.SHADOW)
		Draw.rect(self, r, Color("6e9a5a"), true)
		draw_rect(r.grow(-2.5), Color("4e7a40"), false, 1.0)
		draw_line(Vector2(0, r.position.y), Vector2(0, r.end.y), Color("c9b36a"), 2.0)
		Draw.text(self, Vector2(0, r.position.y - 6), "$%d" % amount, 16, Color("d8f0c0"), W.font("cond"), HORIZONTAL_ALIGNMENT_CENTER, -1, 5)
