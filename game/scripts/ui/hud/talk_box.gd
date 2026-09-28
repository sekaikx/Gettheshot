extends Control
## The conversation, cinematic, at the bottom of the screen: the portrait standing out of a lacquered
## panel on the left, the name and role, the line typed out quickly (any key or click finishes it),
## a few facts, an optional meter (the FEAR bar with the mark where he pays), and numbered options
## with drawn icons, the cost or effect in grey, unavailable ones greyed out.
## Keys 1-9 (0 for a tenth) pick, arrows + Enter too, the mouse too. Esc is the HUD's (it closes).
##
## conv = {name, role, portrait {kind, look, color, extra}, mood, line, info [String],
##         meter {label, value 0..1, mark 0..1}, options [{text, sub, icon, enabled, action, keep_open}],
##         stamp (optional, e.g. "ARRESTED"), icon (optional, for things without a face)}

signal picked(index: int)

const UI := preload("res://scripts/ui/hud/hud_ui.gd")
const PORTRAIT := 164.0
const LINE_FS := 25
const OPT_FS := 18
const SUB_FS := 16

var world: Node
var conv := {}
var _opts: Array = []
var _lines := PackedStringArray()
var _info_lines: Array = []       # [String, bool first line of a fact]
var _chars := 0.0
var _total := 0
var _cps := 80.0
var _t := 0.0
var _hover := -1
var _sel := -1
var _shake := {}                  # option index -> time left
var _box := Rect2()
var _rows: Array = []             # Rect2 per option
var _row_text: Array = []         # PackedStringArray per option (1 or 2 lines)
var _row_sub_below: Array = []    # bool per option
var _content_x := 0.0
var _content_w := 0.0
var _y_line := 0.0
var _y_info := 0.0
var _y_meter := 0.0
var _ncol := 1
var _fade := 0.0
var _closing := false
var _lift := 0.0
var _pview: Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_pview = Control.new()
	_pview.clip_contents = true
	_pview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pview.draw.connect(_draw_portrait)
	add_child(_pview)
	resized.connect(func() -> void:
		if visible:
			_layout())


func open(c: Dictionary) -> void:
	var was_open := visible and not _closing
	conv = c
	_opts = c.get("options", [])
	_hover = -1
	_sel = -1
	_shake.clear()
	_t = 0.0
	_chars = 0.0
	_closing = false
	visible = true
	if not was_open:
		_fade = 0.0
	_layout()
	queue_redraw()
	_pview.queue_redraw()


func close() -> void:
	if visible:
		_closing = true


func is_typing() -> bool:
	return _chars < float(_total)


func finish_typing() -> void:
	_chars = float(_total)


## A key while the talk box is open. Returns true if it was used.
func key(k: int) -> bool:
	if k >= KEY_1 and k <= KEY_9:
		_pick(k - KEY_1)
		return true
	if k == KEY_0:
		_pick(9)
		return true
	if k >= KEY_KP_1 and k <= KEY_KP_9:
		_pick(k - KEY_KP_1)
		return true
	match k:
		KEY_UP, KEY_W:
			_move_sel(-1)
			return true
		KEY_DOWN, KEY_S:
			_move_sel(1)
			return true
		KEY_LEFT, KEY_A:
			if _ncol > 1:
				_move_sel(-_rows_per_col())
			return true
		KEY_RIGHT, KEY_D:
			if _ncol > 1:
				_move_sel(_rows_per_col())
			return true
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_E:
			if is_typing():
				finish_typing()
			elif _sel >= 0:
				_pick(_sel)
			return true
	if is_typing():
		finish_typing()
	return false


func _rows_per_col() -> int:
	return ceili(_opts.size() / float(_ncol))


func _move_sel(d: int) -> void:
	if _opts.is_empty():
		return
	if _sel < 0:
		_sel = 0 if d > 0 else _opts.size() - 1
	else:
		_sel = clampi(_sel + d, 0, _opts.size() - 1)
	UI.sound(world, "tick", -20.0)
	queue_redraw()


func _enabled(i: int) -> bool:
	return bool((_opts[i] as Dictionary).get("enabled", true))


func _pick(i: int) -> void:
	if i < 0 or i >= _opts.size() or _closing:
		return
	if not _enabled(i):
		_shake[i] = 0.35
		UI.sound(world, "tick", -14.0)
		return
	finish_typing()
	picked.emit(i)


# ------------------------------------------------------------------ layout

func _icon_for(o: Dictionary) -> String:
	var ic := String(o.get("icon", ""))
	if ic != "":
		return ic
	return "leave" if String(o.get("text", "")) == "Leave" else "talk"


## Straight double quotes become curly ones (the old newsprint face has proper glyphs).
static func smart_quotes(s: String) -> String:
	var out := ""
	for i in s.length():
		var ch := s[i]
		if ch == "\"":
			var prev := s[i - 1] if i > 0 else " "
			out += "“" if prev in [" ", "(", "[", "—", "\n", "‘"] else "”"
		else:
			out += ch
	return out


func _layout() -> void:
	var area := size
	if area.x < 10.0:
		area = get_viewport_rect().size
	var fell := UI.font("fell")
	var sans := UI.font("sans")
	var semi := UI.font("semi")
	var serif := UI.font("serif")
	var cond := UI.font("cond")
	var maxw := minf(1180.0, area.x - 56.0)
	var left_pad := 26.0 + PORTRAIT + 30.0
	# how wide it wants to be
	_ncol = 2 if _opts.size() > 5 else 1
	var line := smart_quotes(String(conv.get("line", "")))
	var need := maxf(UI.tw(serif, String(conv.get("name", "")), 29), UI.tw(cond, String(conv.get("role", "")).to_upper(), 16))
	need = maxf(need, minf(UI.tw(fell, line, LINE_FS), 760.0))
	for fact in conv.get("info", []):
		need = maxf(need, minf(UI.tw(sans, String(fact), 17) + 16.0, 760.0))
	var opt_need := 0.0
	for o in _opts:
		var od: Dictionary = o
		var sub := String(od.get("sub", ""))
		opt_need = maxf(opt_need, UI.tw(semi, String(od.get("text", "")), OPT_FS) + (UI.tw(sans, sub, SUB_FS) + 30.0 if sub != "" else 0.0) + 78.0)
	need = maxf(need, opt_need * _ncol + 18.0 * (_ncol - 1))
	if conv.has("meter"):
		need = maxf(need, 520.0)
	var bw := clampf(need + left_pad + 30.0, minf(860.0, maxw), maxw)
	var bx := (area.x - bw) * 0.5
	_content_x = bx + left_pad
	_content_w = bw - left_pad - 30.0
	# the line
	_lines = UI.wrap(fell, line, LINE_FS, _content_w, 5)
	_total = 0
	for l in _lines:
		_total += l.length()
	_cps = maxf(70.0, _total / 0.6)
	# facts
	_info_lines.clear()
	for fact in conv.get("info", []):
		var ls := UI.wrap(sans, String(fact), 17, _content_w - 16.0, 3)
		for k in ls.size():
			_info_lines.append([ls[k], k == 0])
	# options: one column up to five, then two; long ones wrap to two lines
	var gap := 18.0
	var cw := (_content_w - gap * (_ncol - 1)) / _ncol
	var avail := cw - 70.0
	var per := _rows_per_col()
	_row_text.clear()
	_row_sub_below.clear()
	var heights: Array = []
	for o in _opts:
		var od2: Dictionary = o
		var text := String(od2.get("text", ""))
		var sub := String(od2.get("sub", ""))
		var tl := UI.wrap(semi, text, OPT_FS, avail, 2)
		var below := sub != "" and (tl.size() > 1 or UI.tw(semi, text, OPT_FS) + UI.tw(sans, sub, SUB_FS) + 24.0 > avail)
		_row_text.append(tl)
		_row_sub_below.append(below)
		heights.append(38.0 + (tl.size() - 1) * 22.0 + (19.0 if below else 0.0))
	var row_h: Array = []
	for r in per:
		var h := 38.0
		for c in _ncol:
			var i: int = c * per + r
			if i < _opts.size():
				h = maxf(h, float(heights[i]))
		row_h.append(h)
	var header := 76.0
	var h_line := _lines.size() * 31.0
	var h_info := _info_lines.size() * 22.0 + (8.0 if not _info_lines.is_empty() else 0.0)
	var h_meter := 42.0 if conv.has("meter") else 0.0
	var h_opts := 0.0
	for h in row_h:
		h_opts += float(h)
	var bh := 26.0 + header + h_line + 10.0 + h_info + h_meter + 14.0 + h_opts + 18.0
	bh = maxf(bh, PORTRAIT + 30.0)
	var by := area.y - 26.0 - bh
	_box = Rect2(Vector2(bx, by), Vector2(bw, bh))
	var y := by + 26.0 + header
	_y_line = y
	y += h_line + 10.0
	_y_info = y
	y += h_info
	_y_meter = y
	y += h_meter + 14.0
	_rows.clear()
	for i in _opts.size():
		var c: int = i / per
		var r: int = i % per
		var yy := y
		for k in r:
			yy += float(row_h[k])
		_rows.append(Rect2(Vector2(_content_x + c * (cw + gap), yy), Vector2(cw, float(row_h[r]) - 4.0)))
	_pview.position = _portrait_rect().position
	_pview.size = _portrait_rect().size


func _portrait_rect() -> Rect2:
	return Rect2(Vector2(_box.position.x + 26.0, _box.position.y - 38.0), Vector2(PORTRAIT, PORTRAIT))


# ------------------------------------------------------------------ frame

func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	if _closing:
		_fade = move_toward(_fade, 0.0, delta * 7.0)
		if _fade <= 0.0:
			visible = false
			_closing = false
			conv = {}
			return
	else:
		_fade = move_toward(_fade, 1.0, delta * 6.0)
	var e := 1.0 - (1.0 - _fade) * (1.0 - _fade)
	modulate.a = e
	_lift = (1.0 - e) * 24.0
	_pview.position = _portrait_rect().position + Vector2(0, _lift)
	if _chars < _total:
		_chars = minf(float(_total), _chars + _cps * delta)
	for k in _shake.keys():
		_shake[k] = float(_shake[k]) - delta
		if float(_shake[k]) <= 0.0:
			_shake.erase(k)
	queue_redraw()


func _gui_input(e: InputEvent) -> void:
	if _closing:
		return
	if e is InputEventMouseMotion:
		var p := (e as InputEventMouseMotion).position - Vector2(0, _lift)
		var h := -1
		for i in _rows.size():
			if (_rows[i] as Rect2).grow_individual(8, 0, 0, 0).has_point(p):
				h = i
		if h != _hover:
			_hover = h
			if h >= 0:
				_sel = h
				if _enabled(h):
					UI.sound(world, "tick", -22.0)
			queue_redraw()
	elif e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
		var mb := e as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		accept_event()
		var p2 := mb.position - Vector2(0, _lift)
		for i in _rows.size():
			if (_rows[i] as Rect2).grow_individual(8, 0, 0, 0).has_point(p2):
				_pick(i)
				return
		if is_typing():
			finish_typing()


func _draw() -> void:
	if not visible or conv.is_empty():
		return
	var area := size
	# darken the bottom of the street so the box reads like a film still
	var g0 := _box.position.y - 170.0
	Draw.vgrad(self, Rect2(Vector2(0, g0), Vector2(area.x, area.y - g0)), Color(0, 0, 0, 0), Color(0, 0, 0, 0.72))
	draw_set_transform(Vector2(0, _lift))
	UI.panel(self, _box, 1.0, 9.0)
	_frame()
	_header()
	_line()
	_facts()
	if conv.has("meter"):
		_meter()
	_options()
	draw_set_transform(Vector2.ZERO)


## The brass frame the portrait sits in (the portrait itself is drawn by _pview, clipped).
func _frame() -> void:
	var pr := _portrait_rect()
	UI.soft_shadow(self, pr.grow(6.0), 4.0, 1.0, Vector2(4, 7))
	Draw.rect(self, pr.grow(7.0), UI.BRASS_DK)
	UI.grad_rrect(self, pr.grow(5.5), 2.0, UI.BRASS_HI, UI.BRASS)
	Draw.rect(self, pr.grow(2.0), Color("120c09"))
	# how he feels, at a glance
	var mood := String(conv.get("mood", ""))
	var moods := {"scared": ["SCARED", Color("a9c1d9")], "angry": ["ANGRY", UI.RED], "happy": ["PLEASED", UI.GREEN], "smug": ["SMUG", UI.GOLD2]}
	if moods.has(mood) and String(conv.get("stamp", "")) == "":
		var cond := UI.font("cond")
		var txt := String(moods[mood][0])
		var col: Color = moods[mood][1]
		var w := UI.tw(cond, txt, 14) + 30.0
		var tag := Rect2(Vector2(pr.get_center().x - w * 0.5, pr.end.y + 16.0), Vector2(w, 24))
		UI.grad_rrect(self, tag, 4.0, Color("2a1d15"), Color("150e0a"))
		UI.rrect_line(self, tag, 4.0, UI.with_a(col, 0.7), 1.0)
		Draw.circle(self, Vector2(tag.position.x + 11, tag.get_center().y), 3.0, col)
		UI.text(self, Vector2(tag.position.x + 19, UI.mid(cond, 14, tag.get_center().y)), txt, cond, 14, col)


func _draw_portrait() -> void:
	if conv.is_empty():
		return
	var pr := Rect2(Vector2.ZERO, _pview.size)
	var p: Dictionary = conv.get("portrait", {}) if conv.get("portrait") is Dictionary else {}
	if not p.is_empty() and String(p.get("kind", "")) != "":
		var col: Color = p.get("color") if p.get("color") is Color else Color(0, 0, 0, 0)
		var ex: Dictionary = p.get("extra") if p.get("extra") is Dictionary else {}
		Portrait.draw(_pview, pr, String(p.get("kind", "ped")), int(p.get("look", 0)), col, ex, String(conv.get("mood", "")))
	else:
		# a thing, not a person: a brass medallion with its icon on dark wood
		UI.grad_rrect(_pview, pr, 1.0, Color("3a2a1e"), Color("1a120d"))
		for k in 8:
			var y := 10.0 + k * 21.0
			_pview.draw_line(Vector2(4, y), Vector2(pr.size.x - 4, y + 3.0), Color(0, 0, 0, 0.16), 2.0)
		var c := pr.get_center()
		Draw.circle(_pview, c + Vector2(2, 3), 52.0, Color(0, 0, 0, 0.35))
		Draw.circle(_pview, c, 50.0, UI.BRASS_DK)
		Draw.circle(_pview, c, 47.0, UI.BRASS)
		Draw.circle(_pview, c, 44.0, Color("241912"))
		UI.icon(_pview, _thing_icon(), c, 58.0, UI.GOLD2, Color("241912"))
	var stamp := String(conv.get("stamp", ""))
	if stamp != "":
		_stamp(pr.get_center() + Vector2(0, 34), stamp)


func _thing_icon() -> String:
	var ic := String(conv.get("icon", ""))
	if ic != "":
		return ic
	var n := String(conv.get("name", "")).to_lower()
	for pair in [["safe", "safe"], ["desk", "book"], ["map", "map"], ["phone", "phone"], ["till", "money"], ["truck", "truck"], ["paper", "news"]]:
		if n.contains(String(pair[0])):
			return String(pair[1])
	return "info"


func _stamp(c: Vector2, s: String) -> void:
	var f := UI.font("fell_sc")
	var fs := 25
	var w := UI.tw(f, s, fs) + 22.0
	_pview.draw_set_transform(c, -0.2, Vector2.ONE)
	var r := Rect2(Vector2(-w * 0.5, -19), Vector2(w, 38))
	var red := Color("c8322a")
	Draw.rect(_pview, r, Color(1, 0.95, 0.9, 0.12))
	_pview.draw_rect(r, UI.with_a(red, 0.95), false, 3.0, true)
	_pview.draw_rect(r.grow(-4.5), UI.with_a(red, 0.7), false, 1.5, true)
	UI.text_c(_pview, 0.0, UI.mid(f, fs, 1.0), s, f, fs, UI.with_a(red, 0.95))
	_pview.draw_set_transform(Vector2.ZERO)


func _header() -> void:
	var serif := UI.font("serif")
	var cond := UI.font("cond")
	var x := _content_x
	var y := _box.position.y + 56.0
	UI.text(self, Vector2(x, y), UI.fit(serif, String(conv.get("name", "")), 29, _content_w), serif, 29, UI.GOLD2)
	var role := String(conv.get("role", "")).to_upper()
	if role != "":
		UI.text(self, Vector2(x, y + 25.0), UI.fit(cond, role, 16, _content_w), cond, 16, UI.MUTE)
	var ry := _box.position.y + 90.0
	draw_line(Vector2(x, ry), Vector2(x + _content_w, ry), UI.with_a(UI.BRASS, 0.35), 1.0, true)
	Draw.poly(self, UI.diamond(Vector2(x, ry), 3.0), UI.with_a(UI.BRASS, 0.8))


func _line() -> void:
	var fell := UI.font("fell")
	var left := int(_chars)
	var y := _y_line + 20.0
	var last_end := Vector2.ZERO
	for l in _lines:
		if left <= 0:
			break
		var part := l.left(left)
		UI.text(self, Vector2(_content_x, y), part, fell, LINE_FS, UI.INK)
		last_end = Vector2(_content_x + UI.tw(fell, part, LINE_FS), y)
		left -= l.length()
		y += 31.0
	if is_typing() and last_end != Vector2.ZERO:
		var blink := 0.5 + 0.5 * sin(_t * 18.0)
		Draw.rect(self, Rect2(last_end + Vector2(3, -18), Vector2(2, 20)), UI.with_a(UI.GOLD2, blink))


func _facts() -> void:
	if _info_lines.is_empty():
		return
	var k := clampf((_chars / maxf(float(_total), 1.0)) * 1.4 - 0.2, 0.0, 1.0) if _total > 0 else 1.0
	var sans := UI.font("sans")
	var y := _y_info + 16.0
	var col := Color("c2b69c")
	for it in _info_lines:
		var row: Array = it
		if bool(row[1]):
			Draw.poly(self, UI.diamond(Vector2(_content_x + 4, y - 5), 3.0), UI.with_a(UI.GOLD, k))
		UI.text(self, Vector2(_content_x + 16, y), String(row[0]), sans, 17, UI.with_a(col, k))
		y += 22.0


func _meter() -> void:
	var m: Dictionary = conv["meter"]
	var v := clampf(float(m.get("value", 0.0)), 0.0, 1.0)
	var mark := float(m.get("mark", -1.0))
	var cond := UI.font("cond")
	var y := _y_meter + 8.0
	var label := String(m.get("label", "")).to_upper()
	UI.text(self, Vector2(_content_x, y + 15), label, cond, 16, UI.GOLD2)
	var bx := _content_x + maxf(64.0, UI.tw(cond, label, 16) + 14.0)
	var bar := Rect2(Vector2(bx, y + 3), Vector2(minf(380.0, _content_w - (bx - _content_x) - 70.0), 14))
	Draw.rrect(self, bar.grow(2.0), 4.0, Color(0, 0, 0, 0.7))
	var col := Pal.UI_RED
	if v > 0.0:
		UI.grad_rrect(self, Rect2(bar.position, Vector2(bar.size.x * v, bar.size.y)), 3.0, col.lightened(0.2), col.darkened(0.3))
	var over := mark >= 0.0 and v >= mark
	if mark >= 0.0:
		var mx := bar.position.x + bar.size.x * mark
		draw_line(Vector2(mx, bar.position.y - 5), Vector2(mx, bar.end.y + 5), UI.GOLD2, 2.0, true)
		UI.text_c(self, mx, bar.position.y - 8, "HE PAYS", cond, 11, UI.GOLD2)
	UI.text(self, Vector2(bar.end.x + 12, y + 15), "%d%%" % int(roundf(v * 100.0)), cond, 16, UI.GREEN if over else UI.INK)


func _options() -> void:
	var semi := UI.font("semi")
	var sans := UI.font("sans")
	var appear := clampf(_t / 0.22, 0.0, 1.0)
	for i in _opts.size():
		var o: Dictionary = _opts[i]
		var r: Rect2 = _rows[i]
		var on := _enabled(i)
		var oa := appear * (1.0 if on else 0.42)
		var dx := 0.0
		if _shake.has(i):
			dx = sin(float(_shake[i]) * 60.0) * 5.0 * (float(_shake[i]) / 0.35)
		var rr := Rect2(r.position + Vector2(dx - 8.0, 0), r.size + Vector2(8.0, 0))
		var hl := i == _sel or i == _hover
		if hl and on:
			UI.grad_rrect(self, rr, 5.0, Color("5a4226", 0.75), Color("3a2a1a", 0.75))
			UI.rrect_line(self, rr, 5.0, UI.with_a(UI.BRASS, 0.7), 1.0)
		elif hl:
			UI.rrect_line(self, rr, 5.0, UI.with_a(UI.MUTE, 0.35), 1.0)
		var cy := r.position.y + 17.0
		var num := str(i + 1) if i < 9 else ("0" if i == 9 else "")
		if num != "":
			UI.keycap(self, Rect2(Vector2(r.position.x + dx, cy - 12), Vector2(24, 24)), num, oa, hl and on)
		var icol := UI.GOLD2 if on else UI.MUTE
		UI.icon(self, _icon_for(o), Vector2(r.position.x + dx + 44, cy), 20.0, UI.with_a(icol, oa), Color("1a120d"))
		var tx := r.position.x + dx + 62.0
		var avail := r.size.x - 70.0
		var tl: PackedStringArray = _row_text[i]
		var sub := String(o.get("sub", ""))
		var below := bool(_row_sub_below[i])
		var tcol := Color("fff4dc") if hl and on else (UI.INK if on else UI.MUTE)
		var y := UI.mid(semi, OPT_FS, cy)
		for l in tl:
			UI.text(self, Vector2(tx, y), l, semi, OPT_FS, UI.with_a(tcol, oa))
			y += 22.0
		if sub != "":
			var scol := UI.with_a(Color("a89c84"), oa)
			if below:
				UI.text(self, Vector2(tx, y - 3.0), UI.fit(sans, sub, SUB_FS, avail), sans, SUB_FS, scol)
			else:
				UI.text_r(self, r.end.x - 6.0, UI.mid(sans, SUB_FS, cy), sub, sans, SUB_FS, scol)
