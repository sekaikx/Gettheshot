class_name Portrait
extends RefCounted
## Head-and-shoulders portraits for dialogs, the family book and the tutorial, drawn from the
## same look seed as the Person2D on the street (same skin, hat, clothes). STUB: the real art
## replaces draw(); the signature is the contract.
##
##   Portrait.draw(ci, rect, kind, look, family_color, extra, mood)
##     ci      any CanvasItem, called from inside its _draw()
##     rect    where to draw (square-ish; it fills it, background included)
##     kind    same kinds as Person2D
##     mood    "", "angry", "scared", "happy", "smug"
##
## A Control that shows one: Portrait.control(kind, look, color, extra) -> Control


static func draw(ci: CanvasItem, rect: Rect2, kind: String, look: int, family_color: Color = Color(0, 0, 0, 0),
		extra: Dictionary = {}, mood: String = "") -> void:
	ci.draw_rect(rect, Color(0.25, 0.2, 0.16))
	var c := rect.get_center()
	var s := minf(rect.size.x, rect.size.y)
	Draw.ellipse(ci, c + Vector2(0, s * 0.42), Vector2(s * 0.42, s * 0.3), Color(0.15, 0.15, 0.17))
	Draw.circle(ci, c + Vector2(0, -s * 0.05), s * 0.22, Color(0.9, 0.75, 0.6))
	if family_color.a > 0.0:
		ci.draw_rect(Rect2(rect.position, Vector2(rect.size.x, 4)), family_color)


static func control(kind: String, look: int, family_color: Color = Color(0, 0, 0, 0), extra: Dictionary = {},
		mood: String = "") -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(96, 96)
	c.draw.connect(func() -> void: draw(c, Rect2(Vector2.ZERO, c.size), kind, look, family_color, extra, mood))
	return c
