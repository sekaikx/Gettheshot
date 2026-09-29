class_name MenuLogo
extends Control
## FAMIGLIA in Art Deco capitals: brass letters with a dark lip, a rule with a diamond, the
## "NEW YORK · 1929" line above and the tagline under it.

var tagline := "New York, 1929. Build a family. Take the city."
var title := "FAMIGLIA"
var title_size := 124


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fd := MenuStyle.spaced("deco", 5)
	var tw := fd.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x
	custom_minimum_size = Vector2(maxf(560.0, tw + 20), 34 + 22 + fd.get_ascent(title_size) * 0.86 + 26 + 50 + 18)


func _draw() -> void:
	var fd := MenuStyle.spaced("deco", 5)
	var fs := title_size
	var tw := fd.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var x := 6.0
	# the small line above: rules either side of NEW YORK · 1929
	var top_y := 34.0
	var fc := MenuStyle.spaced("cond", 5)
	var cap := "LITTLE ITALY  ·  NEW YORK"
	var cw := fc.get_string_size(cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
	var gold := MenuStyle.GOLD
	draw_string(fc, Vector2(x + 2, top_y), cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(gold, 0.9))
	draw_line(Vector2(x + cw + 16, top_y - 6), Vector2(x + tw, top_y - 6), Color(gold, 0.6), 1.0, true)
	# the title
	var base := Vector2(x, top_y + 22 + fd.get_ascent(fs) * 0.86)
	draw_string(fd, base + Vector2(3, 5), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.55))
	draw_string_outline(fd, base, title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, MenuStyle.BRASS_DARK.darkened(0.3))
	draw_string(fd, base, title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, gold)
	# the rule with a diamond
	var ry := base.y + 26
	var mid := x + tw * 0.5
	draw_line(Vector2(x, ry), Vector2(mid - 16, ry), gold, 2.0, true)
	draw_line(Vector2(mid + 16, ry), Vector2(x + tw, ry), gold, 2.0, true)
	draw_line(Vector2(x + 40, ry + 6), Vector2(mid - 22, ry + 6), Color(gold, 0.5), 1.0, true)
	draw_line(Vector2(mid + 22, ry + 6), Vector2(x + tw - 40, ry + 6), Color(gold, 0.5), 1.0, true)
	var dc := Vector2(mid, ry + 2)
	Draw.poly(self, PackedVector2Array([dc + Vector2(0, -9), dc + Vector2(9, 0), dc + Vector2(0, 9), dc + Vector2(-9, 0)]), gold)
	Draw.poly(self, PackedVector2Array([dc + Vector2(0, -4), dc + Vector2(4, 0), dc + Vector2(0, 4), dc + Vector2(-4, 0)]), MenuStyle.BRASS_DARK.darkened(0.4))
	# the tagline
	var ft := W.ui_font("fell")
	var ty := ry + 50
	draw_string_outline(ft, Vector2(x + 2, ty), tagline, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, 8, Color(0, 0, 0, 0.4))
	draw_string(ft, Vector2(x + 2, ty), tagline, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, MenuStyle.NIGHT_TEXT)

