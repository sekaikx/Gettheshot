class_name MenuStyle
extends RefCounted
## Look and building blocks of the title screen and its panels (and of the Settings / How to play
## panels, which the HUD may reuse). Panels are cream paper in a brass Art Deco frame; the ink is
## dark brown, the accents oxblood and brass. Nothing here is default grey Godot.

# on the night street
const NIGHT_TEXT := Color("efe6d2")        # Pal.INK
const NIGHT_MUTE := Color("a89c86")
const GOLD := Color("d4a532")              # Pal.GOLD
const GOLD2 := Color("f0d58a")             # Pal.GOLD2
# on paper
const INK := Color("1e140a")
const INK_SOFT := Color("54422e")
const INK_FAINT := Color(0.118, 0.078, 0.039, 0.16)
const PAPER := Color("e9dfc7")
const PAPER_HI := Color("f6efdd")
const PAPER_DARK := Color("d6c8a8")
const OXBLOOD := Color("8b1e1a")
const OXBLOOD_HI := Color("a8322a")
const OXBLOOD_DARK := Color("5e1411")
const BRASS := Color("b08d57")
const BRASS_HI := Color("d6b67e")
const BRASS_DARK := Color("7a5e34")
const GREEN := Color("2f4a38")

const PANEL_TEX := "res://assets/ui/panels/deco_frame.png"
const FIELD_TEX := "res://assets/ui/fields/field_normal.png"
const FIELD_FOCUS_TEX := "res://assets/ui/fields/field_focus.png"
const DIVIDER_TEX := "res://assets/ui/rules/deco_divider.png"

static var _grabber: Texture2D
static var _spaced := {}
static var _grabber_hi: Texture2D


static func font(name: String) -> Font:
	return W.ui_font(name)


# ------------------------------------------------------------------ panels

## The cream Art Deco frame every menu panel sits in.
static func frame() -> StyleBox:
	var t: Texture2D = load(PANEL_TEX) if ResourceLoader.exists(PANEL_TEX) else null
	if t == null:
		var f := StyleBoxFlat.new()
		f.bg_color = PAPER
		f.border_color = BRASS
		f.set_border_width_all(6)
		f.set_content_margin_all(48)
		return f
	var sb := StyleBoxTexture.new()
	sb.texture = t
	sb.texture_margin_left = 96
	sb.texture_margin_top = 96
	sb.texture_margin_right = 96
	sb.texture_margin_bottom = 96
	sb.expand_margin_left = 10
	sb.expand_margin_top = 10
	sb.expand_margin_right = 10
	sb.expand_margin_bottom = 10
	sb.content_margin_left = 64
	sb.content_margin_right = 64
	sb.content_margin_top = 50
	sb.content_margin_bottom = 46
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	return sb


## A slightly darker paper inset (roster rows, the address box...).
static func inset(tint: Color = PAPER_DARK, radius: int = 4) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(tint, 0.55)
	sb.border_color = Color(INK, 0.22)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb


# ------------------------------------------------------------------ text

static func label(text: String, font_name: String = "sans", size: int = 20, color: Color = INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(font_name))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


## A panel title in Art Deco capitals.
static func heading(text: String, size: int = 40) -> Label:
	var l := label(text.to_upper(), "deco", size, INK)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## A small spaced caption above a control ("YOUR NAME").
static func caption(text: String, color: Color = INK_SOFT) -> Label:
	var l := label(text.to_upper(), "cond", 15, color)
	l.add_theme_font_override("font", spaced("cond", 2))
	return l


## Body text that wraps.
static func body(text: String, size: int = 19, color: Color = INK_SOFT) -> Label:
	var l := label(text, "sans", size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## A W.ui_font with extra space between letters (for capitals).
static func spaced(name: String, px: int) -> Font:
	var key := "%s@%d" % [name, px]
	if _spaced.has(key):
		return _spaced[key]
	var fv := FontVariation.new()
	fv.base_font = font(name)
	fv.spacing_glyph = px
	_spaced[key] = fv
	return fv


## The Art Deco rule under a heading.
static func divider(width: float = 360.0, color: Color = BRASS_DARK) -> Control:
	var c := CenterContainer.new()
	if ResourceLoader.exists(DIVIDER_TEX):
		var r := TextureRect.new()
		r.texture = load(DIVIDER_TEX)
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_SCALE
		r.custom_minimum_size = Vector2(width, 20.0 * width / 360.0)
		r.modulate = color
		c.add_child(r)
	else:
		var s := ColorRect.new()
		s.color = color
		s.custom_minimum_size = Vector2(width, 2)
		c.add_child(s)
	return c


# ------------------------------------------------------------------ buttons

## A panel button. kind: "primary" (oxblood, cream letters), "secondary" (ink outline).
static func button(text: String, kind: String = "secondary", min_w: float = 170.0) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(min_w, 52)
	b.add_theme_font_override("font", font("cond"))
	b.add_theme_font_size_override("font_size", 23)
	var primary := kind == "primary"
	var base := OXBLOOD if primary else Color(PAPER_HI, 0.0)
	var edge := OXBLOOD_DARK if primary else Color(INK, 0.55)
	var normal := _flat(base, edge, 2 if not primary else 1, 3)
	var hover := _flat(OXBLOOD_HI if primary else Color(BRASS, 0.18), OXBLOOD_DARK if primary else INK, 2, 3)
	var pressed := _flat(OXBLOOD_DARK if primary else Color(BRASS, 0.32), OXBLOOD_DARK if primary else INK, 2, 3)
	var disabled := _flat(Color(INK, 0.08) if primary else Color(0, 0, 0, 0), Color(INK, 0.2), 1, 3)
	if primary:
		normal.shadow_color = Color(0, 0, 0, 0.22)
		normal.shadow_size = 3
		normal.shadow_offset = Vector2(1, 2)
		hover.shadow_color = normal.shadow_color
		hover.shadow_size = 4
		hover.shadow_offset = Vector2(1, 2)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("hover_pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_stylebox_override("focus", focus_ring())
	var fc := PAPER_HI if primary else INK
	b.add_theme_color_override("font_color", fc)
	b.add_theme_color_override("font_hover_color", PAPER_HI if primary else INK)
	b.add_theme_color_override("font_pressed_color", PAPER_HI if primary else INK)
	b.add_theme_color_override("font_hover_pressed_color", PAPER_HI if primary else INK)
	b.add_theme_color_override("font_focus_color", fc)
	b.add_theme_color_override("font_disabled_color", Color(INK, 0.35))
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b


## The keyboard focus mark: a brass ring just outside the control.
static func focus_ring(radius: int = 4) -> StyleBoxFlat:
	var f := StyleBoxFlat.new()
	f.draw_center = false
	f.border_color = BRASS
	f.set_border_width_all(3)
	f.set_corner_radius_all(radius + 2)
	f.set_expand_margin_all(4)
	return f


static func _flat(bg: Color, edge: Color, bw: int, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = edge
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 22
	s.content_margin_right = 22
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	s.anti_aliasing = true
	return s


## A row of choices, one picked (Fast | Normal | Slow). `on_pick(index)` runs on a change.
## Returns the HBox; its buttons share one ButtonGroup.
static func segmented(options: Array, selected: int, on_pick: Callable, min_w: float = 0.0, height: float = 46.0) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var group := ButtonGroup.new()
	for i in options.size():
		var b := Button.new()
		b.text = String(options[i])
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = i == selected
		b.focus_mode = Control.FOCUS_ALL
		b.custom_minimum_size = Vector2(min_w, height)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL if min_w <= 0.0 else Control.SIZE_FILL
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.add_theme_font_override("font", font("semi"))
		b.add_theme_font_size_override("font_size", 19)
		var off := _flat(Color(PAPER_HI, 0.55), Color(INK, 0.35), 1, 3)
		off.content_margin_left = 10
		off.content_margin_right = 10
		var hov := off.duplicate() as StyleBoxFlat
		hov.bg_color = Color(BRASS, 0.2)
		hov.border_color = Color(INK, 0.6)
		var on := off.duplicate() as StyleBoxFlat
		on.bg_color = INK
		on.border_color = INK
		b.add_theme_stylebox_override("normal", off)
		b.add_theme_stylebox_override("hover", hov)
		b.add_theme_stylebox_override("pressed", on)
		b.add_theme_stylebox_override("hover_pressed", on)
		b.add_theme_stylebox_override("focus", focus_ring())
		b.add_theme_color_override("font_color", INK)
		b.add_theme_color_override("font_hover_color", INK)
		b.add_theme_color_override("font_focus_color", INK)
		b.add_theme_color_override("font_pressed_color", GOLD2)
		b.add_theme_color_override("font_hover_pressed_color", GOLD2)
		var k := i
		b.toggled.connect(func(on_now: bool) -> void:
			if on_now:
				on_pick.call(k))
		row.add_child(b)
	return row


## Select option `index` of a row made by segmented() without firing its callback twice.
static func segmented_select(row: HBoxContainer, index: int) -> void:
	if index >= 0 and index < row.get_child_count():
		(row.get_child(index) as Button).button_pressed = true


## A text field on paper.
static func field(placeholder: String, value: String, max_len: int = 16) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.text = value
	e.max_length = max_len
	e.custom_minimum_size = Vector2(0, 50)
	e.add_theme_font_override("font", font("semi"))
	e.add_theme_font_size_override("font_size", 22)
	e.add_theme_color_override("font_color", INK)
	e.add_theme_color_override("font_placeholder_color", Color(INK, 0.38))
	e.add_theme_color_override("caret_color", OXBLOOD)
	e.add_theme_color_override("selection_color", Color(BRASS, 0.45))
	e.add_theme_color_override("font_selected_color", INK)
	e.add_theme_constant_override("caret_width", 2)
	var n := _flat(Color(PAPER_HI, 0.85), Color(INK, 0.35), 1, 3)
	n.border_width_bottom = 2
	n.content_margin_left = 14
	n.content_margin_right = 14
	var f := n.duplicate() as StyleBoxFlat
	f.border_color = OXBLOOD
	f.set_border_width_all(2)
	f.bg_color = PAPER_HI
	e.add_theme_stylebox_override("normal", n)
	e.add_theme_stylebox_override("focus", f)
	e.add_theme_stylebox_override("read_only", n)
	return e


## A labelled block: caption above the control.
static func labeled(cap: String, ctl: Control, hint: String = "") -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.add_child(caption(cap))
	v.add_child(ctl)
	if hint != "":
		var h := body(hint, 16, Color(INK_SOFT, 0.9))
		h.name = "Hint"
		v.add_child(h)
	return v


## A volume-style slider with brass grabber. Returns the HSlider.
static func slider(value: float, lo: float, hi: float, step: float) -> HSlider:
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.focus_mode = Control.FOCUS_ALL
	s.custom_minimum_size = Vector2(260, 34)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var track := StyleBoxFlat.new()
	track.bg_color = Color(INK, 0.18)
	track.set_corner_radius_all(4)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	var fill := track.duplicate() as StyleBoxFlat
	fill.bg_color = OXBLOOD
	var fill_hi := track.duplicate() as StyleBoxFlat
	fill_hi.bg_color = OXBLOOD_HI
	s.add_theme_stylebox_override("slider", track)
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill_hi)
	s.add_theme_stylebox_override("focus", focus_ring(10))
	_make_grabbers()
	s.add_theme_icon_override("grabber", _grabber)
	s.add_theme_icon_override("grabber_highlight", _grabber_hi)
	s.add_theme_icon_override("grabber_disabled", _grabber)
	return s


static func _make_grabbers() -> void:
	if _grabber:
		return
	_grabber = _disc(26, BRASS, BRASS_DARK, PAPER_HI)
	_grabber_hi = _disc(26, BRASS_HI, BRASS_DARK, Color.WHITE)


static func _disc(d: int, fill: Color, edge: Color, dot: Color) -> Texture2D:
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	var c := (d - 1) * 0.5
	for y in d:
		for x in d:
			var r := Vector2(x - c, y - c).length()
			var a := clampf(c - r + 0.5, 0.0, 1.0)
			if a <= 0.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var col := fill
			if r > c - 2.5:
				col = edge
			elif r < 3.0:
				col = dot
			else:
				# a little top-left light on the brass
				var k := clampf((c - x + c - y) / (2.0 * c), -1.0, 1.0)
				col = fill.lerp(Color.WHITE, maxf(0.0, k) * 0.25)
			img.set_pixel(x, y, Color(col, a))
	return ImageTexture.create_from_image(img)
