class_name MenuWidgets
extends RefCounted
## Hand-drawn controls for the menus: the title-screen items, an on/off switch, colour swatches,
## the big choice cards (Host / Join), and a keyboard key cap.


static func _no_styles(b: Button) -> void:
	var e := StyleBoxEmpty.new()
	for k in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(k, e)


## One line of the title screen's menu: big spaced capitals on the night street, a brass wash
## and a diamond when it has the mouse or the keyboard.
class TitleItem extends Button:
	var label := ""
	var sub := ""
	var _k := 0.0          # 0..1 how "active" it looks (animated)
	var _hover := false

	func _init(text_: String, sub_: String = "") -> void:
		label = text_
		sub = sub_
		focus_mode = Control.FOCUS_ALL
		custom_minimum_size = Vector2(460, 58)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		MenuWidgets._no_styles(self)
		mouse_entered.connect(func() -> void:
			_hover = true
			if not disabled:
				grab_focus())
		mouse_exited.connect(func() -> void: _hover = false)

	func _active() -> bool:
		return not disabled and (has_focus() or _hover)

	func _process(delta: float) -> void:
		var want := 1.0 if _active() else 0.0
		if absf(_k - want) > 0.001:
			_k = move_toward(_k, want, delta * 6.0)
			queue_redraw()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_FOCUS_ENTER or what == NOTIFICATION_FOCUS_EXIT:
			queue_redraw()

	func _draw() -> void:
		var h := size.y
		var ease_k := _k * _k * (3.0 - 2.0 * _k)
		if ease_k > 0.0:
			Draw.hgrad(self, Rect2(0, 4, minf(size.x, 600.0), h - 8), Color(MenuStyle.GOLD, 0.26 * ease_k), Color(MenuStyle.GOLD, 0.0))
			draw_rect(Rect2(0, 4, 4, h - 8), Color(MenuStyle.GOLD2, ease_k))
			var dc := Vector2(22 + 4 * ease_k, h * 0.5)
			var d := 6.0 * ease_k
			Draw.poly(self, PackedVector2Array([dc + Vector2(0, -d), dc + Vector2(d, 0), dc + Vector2(0, d), dc + Vector2(-d, 0)]), Color(MenuStyle.GOLD2, ease_k))
		var f := MenuStyle.spaced("cond", 3)
		var fs := 34
		var x := 44.0 + 10.0 * ease_k
		var base_y := h * 0.5 + (f.get_ascent(fs) - f.get_descent(fs)) * 0.5
		var col := MenuStyle.NIGHT_TEXT.lerp(MenuStyle.GOLD2, ease_k)
		if disabled:
			col = Color(MenuStyle.NIGHT_TEXT, 0.3)
		# soft dark halo so the letters read over the rain
		draw_string_outline(f, Vector2(x, base_y), label.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(0, 0, 0, 0.35))
		draw_string(f, Vector2(x, base_y), label.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		if sub != "":
			var tw := f.get_string_size(label.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var sf := W.ui_font("fell")
			draw_string_outline(sf, Vector2(x + tw + 18, base_y - 1), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 21, 5, Color(0, 0, 0, 0.35))
			draw_string(sf, Vector2(x + tw + 18, base_y - 1), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color(MenuStyle.NIGHT_MUTE.lerp(MenuStyle.NIGHT_TEXT, 0.4 * ease_k), 1.0 if not disabled else 0.3))


## An on/off switch on paper, with the word next to it.
class Switch extends Button:
	var on_text := "On"
	var off_text := "Off"
	var _k := 0.0

	func _init(on: bool = true) -> void:
		toggle_mode = true
		button_pressed = on
		_k = 1.0 if on else 0.0
		focus_mode = Control.FOCUS_ALL
		custom_minimum_size = Vector2(122, 44)
		size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		MenuWidgets._no_styles(self)
		toggled.connect(func(_v: bool) -> void: queue_redraw())
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)

	func _process(delta: float) -> void:
		var want := 1.0 if button_pressed else 0.0
		if absf(_k - want) > 0.001:
			_k = move_toward(_k, want, delta * 7.0)
			queue_redraw()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_FOCUS_ENTER or what == NOTIFICATION_FOCUS_EXIT:
			queue_redraw()

	func _draw() -> void:
		var tr := Rect2(2, (size.y - 30) * 0.5, 62, 30)
		var off_col := Color(MenuStyle.INK, 0.22)
		var track := off_col.lerp(MenuStyle.OXBLOOD, _k)
		if is_hovered():
			track = track.lightened(0.08)
		Draw.rrect(self, tr, 15, track)
		draw_rect(Rect2(tr.position + Vector2(15, 1), Vector2(tr.size.x - 30, 1)), Color(0, 0, 0, 0.12))
		var kx := lerpf(tr.position.x + 15, tr.end.x - 15, _k)
		var kc := Vector2(kx, tr.get_center().y)
		Draw.circle(self, kc + Vector2(0.5, 1.5), 12, Color(0, 0, 0, 0.25))
		Draw.circle(self, kc, 12, MenuStyle.PAPER_HI)
		Draw.circle(self, kc, 8, MenuStyle.BRASS_HI.lerp(MenuStyle.PAPER_HI, 0.5))
		if has_focus():
			var fr := tr.grow(4)
			draw_polyline(_loop(Draw.rrect_points(fr, 19)), MenuStyle.BRASS, 3.0, true)
		var f := W.ui_font("semi")
		var t := on_text if button_pressed else off_text
		var y := size.y * 0.5 + (f.get_ascent(20) - f.get_descent(20)) * 0.5
		draw_string(f, Vector2(tr.end.x + 14, y), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, MenuStyle.INK)

	static func _loop(p: PackedVector2Array) -> PackedVector2Array:
		var q := p.duplicate()
		q.append(p[0])
		return q


## A round colour swatch (family colours).
class Swatch extends Button:
	var color := Color.RED

	func _init(c: Color) -> void:
		color = c
		toggle_mode = true
		focus_mode = Control.FOCUS_ALL
		custom_minimum_size = Vector2(46, 46)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		MenuWidgets._no_styles(self)
		toggled.connect(func(_v: bool) -> void: queue_redraw())
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_FOCUS_ENTER or what == NOTIFICATION_FOCUS_EXIT:
			queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var r := 15.0 + (1.5 if is_hovered() else 0.0)
		if button_pressed:
			Draw.circle(self, c, r + 6, MenuStyle.INK)
			Draw.circle(self, c, r + 3.5, MenuStyle.PAPER_HI)
		Draw.circle(self, c + Vector2(0.8, 1.6), r, Color(0, 0, 0, 0.22))
		Draw.circle(self, c, r, color.darkened(0.25))
		Draw.circle(self, c + Vector2(-1, -1.2), r - 2.2, color)
		Draw.circle(self, c + Vector2(-r * 0.35, -r * 0.4), r * 0.28, Color(1, 1, 1, 0.18))
		if button_pressed:
			var ink := Color.WHITE if color.get_luminance() < 0.6 else MenuStyle.INK
			draw_polyline(PackedVector2Array([c + Vector2(-6, 0), c + Vector2(-2, 5), c + Vector2(7, -5)]), ink, 3.0, true)
		if has_focus():
			draw_arc(c, r + 9, 0, TAU, 40, MenuStyle.BRASS, 3.0, true)


## A big clickable card: an icon, a title, a line or two (Host a game / Join a friend).
class ChoiceCard extends Button:
	var icon_name := ""
	var title := ""
	var lines := ""

	func _init(icon_: String, title_: String, lines_: String) -> void:
		icon_name = icon_
		title = title_
		lines = lines_
		focus_mode = Control.FOCUS_ALL
		custom_minimum_size = Vector2(380, 280)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		MenuWidgets._no_styles(self)
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_FOCUS_ENTER or what == NOTIFICATION_FOCUS_EXIT:
			queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var hot := is_hovered() or has_focus()
		Draw.rrect(self, Rect2(r.position + Vector2(2, 4), r.size), 6, Color(0, 0, 0, 0.12))
		Draw.rrect(self, r, 6, MenuStyle.PAPER_HI if not hot else MenuStyle.PAPER_HI.lerp(MenuStyle.BRASS_HI, 0.22))
		var edge := MenuStyle.OXBLOOD if hot else Color(MenuStyle.INK, 0.35)
		draw_polyline(Switch._loop(Draw.rrect_points(r.grow(-1), 6)), edge, 2.0 if hot else 1.0, true)
		draw_polyline(Switch._loop(Draw.rrect_points(r.grow(-8), 3)), Color(edge, 0.35), 1.0, true)
		if has_focus():
			draw_polyline(Switch._loop(Draw.rrect_points(r.grow(4), 9)), MenuStyle.BRASS, 3.0, true)
		# the icon in an oxblood medallion
		var ic := Vector2(size.x * 0.5, 78)
		Draw.circle(self, ic, 48, MenuStyle.OXBLOOD if hot else MenuStyle.INK)
		draw_arc(ic, 42, 0, TAU, 48, Color(MenuStyle.BRASS_HI, 0.8), 1.5, true)
		var t: Texture2D = UiKit.icon(icon_name, 64)
		if t:
			draw_texture_rect(t, Rect2(ic - Vector2(29, 29), Vector2(58, 58)), false, MenuStyle.PAPER_HI)
		var fd := W.ui_font("deco")
		draw_string(fd, Vector2(0, 170), title.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, size.x, 28, MenuStyle.INK)
		var fb := W.ui_font("sans")
		draw_multiline_string(fb, Vector2(28, 208), lines, HORIZONTAL_ALIGNMENT_CENTER, size.x - 56, 19, -1, MenuStyle.INK_SOFT)


## A typewriter-style key cap with a letter or a short word (drawn, any size).
class KeyCap extends Control:
	var key := "E"
	var dark := true

	func _init(k: String, on_dark: bool = true) -> void:
		key = k
		dark = on_dark
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var f := W.ui_font("cond")
		var w := maxf(30.0, f.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 16.0)
		custom_minimum_size = Vector2(w, 30)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func _draw() -> void:
		MenuWidgets.draw_key(self, Rect2(Vector2.ZERO, size), key, 16)


## A key cap drawn into any CanvasItem (used by the How-to-play art too).
static func draw_key(ci: CanvasItem, r: Rect2, key: String, fs: int = 16) -> void:
	Draw.rrect(ci, Rect2(r.position + Vector2(0, 2), r.size), 6, Color(0, 0, 0, 0.35))
	Draw.rrect(ci, r, 6, Color("c9c2b2"))
	Draw.rrect(ci, r.grow(-2.5), 4.5, Color("1f1c1a"))
	Draw.rrect(ci, Rect2(r.position + Vector2(3, 3), Vector2(r.size.x - 6, r.size.y * 0.4)), 4, Color(1, 1, 1, 0.06))
	var f := W.ui_font("cond")
	var y := r.position.y + r.size.y * 0.5 + (f.get_ascent(fs) - f.get_descent(fs)) * 0.5
	ci.draw_string(f, Vector2(r.position.x, y), key, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, Color("f2ead6"))


## A family's wax seal: a blob of wax in the family colour with its initial pressed in, readable.
class Seal extends Control:
	var seal_color := Color("c42828"):
		set(v):
			seal_color = v
			queue_redraw()
	var letter := "":
		set(v):
			letter = v
			queue_redraw()

	func _init(c: Color = Color("c42828"), l: String = "", d: float = 56.0) -> void:
		seal_color = c
		letter = l
		custom_minimum_size = Vector2(d, d)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 2.0
		var pts := PackedVector2Array()
		for k in 28:
			var a := TAU * k / 28.0
			var rr := r * (0.93 + 0.07 * Draw.hash01(k, int(seal_color.r8), 5))
			pts.append(c + Vector2(cos(a), sin(a)) * rr)
		Draw.shadow(self, pts, Vector2(1.5, 2.5), Color(0, 0, 0, 0.28))
		Draw.poly(self, pts, seal_color.darkened(0.18))
		Draw.circle(self, c, r * 0.74, seal_color.darkened(0.32))
		Draw.circle(self, c + Vector2(-0.8, -0.8), r * 0.7, seal_color)
		draw_arc(c, r * 0.62, 0, TAU, 32, Color(seal_color.lightened(0.35), 0.6), 1.2, true)
		Draw.ellipse(self, c + Vector2(-r * 0.38, -r * 0.45), Vector2(r * 0.22, r * 0.12), Color(1, 1, 1, 0.22), -0.6)
		if letter != "":
			var f := W.ui_font("deco")
			var fs := int(r * 0.95)
			var tw := f.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var p := Vector2(c.x - tw * 0.5, c.y + (f.get_ascent(fs) - f.get_descent(fs)) * 0.5)
			var ink := Color("fbf3df") if seal_color.get_luminance() < 0.62 else Color("2a1a10")
			draw_string(f, p + Vector2(1, 1.5), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.35))
			draw_string(f, p, letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
