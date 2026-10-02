extends Control
## Esc: the pause menu. Resume, How to play, Settings (volumes, full screen), Save (the host),
## Quit to the menu. Big brass rows; arrows or the mouse to choose, Enter or a click to pick,
## Left/Right to move a slider. Playing alone, the city stops while it's open.

signal action(id: String)

const UI := preload("res://scripts/ui/hud/hud_ui.gd")
const Store := preload("res://scripts/ui/hud/settings_store.gd")
const W_CARD := 480.0
const ROW := 56.0

var world: Node
var page := "main"
var paused_game := false
var _rows: Array = []        # {id, text, sub, icon, kind ("button" | "slider" | "toggle"), key}
var _sel := 0
var _hover := -1
var _drag := -1
var _a := 0.0
var _card := Rect2()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false


func open(p: String = "main") -> void:
	page = p
	if not visible:
		_a = 0.0
	visible = true
	_build()
	_sel = 0
	_hover = -1
	queue_redraw()


func close() -> void:
	visible = false
	_drag = -1


func _build() -> void:
	_rows.clear()
	if page == "main":
		_rows.append({"id": "resume", "text": "Resume", "sub": "", "icon": "play", "kind": "button", "key": "Esc"})
		_rows.append({"id": "help", "text": "How to play", "sub": "the rules on eight cards", "icon": "help", "kind": "button", "key": "H"})
		_rows.append({"id": "settings", "text": "Settings", "sub": "sound and screen", "icon": "gear", "kind": "button", "key": ""})
		if Net.is_host():
			_rows.append({"id": "save", "text": "Save the game", "sub": "", "icon": "book", "kind": "button", "key": ""})
		_rows.append({"id": "quit", "text": "Quit to the menu", "sub": "the game is saved first" if Net.is_host() else "you leave the game", "icon": "door", "kind": "button", "key": ""})
	else:
		_rows.append({"id": "master", "text": "Volume", "sub": "", "icon": "", "kind": "slider", "key": ""})
		if Store.has_bus("music"):
			_rows.append({"id": "music", "text": "Music", "sub": "", "icon": "", "kind": "slider", "key": ""})
		if Store.has_bus("sfx"):
			_rows.append({"id": "sfx", "text": "Sound effects", "sub": "", "icon": "", "kind": "slider", "key": ""})
		_rows.append({"id": "fullscreen", "text": "Full screen", "sub": "", "icon": "", "kind": "toggle", "key": ""})
		_rows.append({"id": "show_controls", "text": "Show key hints", "sub": "", "icon": "", "kind": "toggle", "key": ""})
		_rows.append({"id": "back", "text": "Back", "sub": "", "icon": "leave", "kind": "button", "key": "Esc"})
	var h := 140.0 + _rows.size() * ROW + 20.0
	_card = Rect2((size - Vector2(W_CARD, h)) * 0.5, Vector2(W_CARD, h))


## Esc inside the menu: the settings page goes back to the main page. Returns true if it did.
func back() -> bool:
	if page != "main":
		open("main")
		return true
	return false


func key(k: int) -> void:
	match k:
		KEY_UP, KEY_W:
			_sel = posmod(_sel - 1, _rows.size())
			UI.sound(world, "tick", -20.0)
		KEY_DOWN, KEY_S:
			_sel = posmod(_sel + 1, _rows.size())
			UI.sound(world, "tick", -20.0)
		KEY_LEFT, KEY_A:
			_nudge(-0.1)
		KEY_RIGHT, KEY_D:
			_nudge(0.1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_E:
			_activate(_sel)
		KEY_H:
			if page == "main":
				action.emit("help")
	if k >= KEY_1 and k <= KEY_9 and k - KEY_1 < _rows.size():
		_sel = k - KEY_1
		_activate(_sel)
	queue_redraw()


func _nudge(d: float) -> void:
	if _sel < 0 or _sel >= _rows.size():
		return
	var row: Dictionary = _rows[_sel]
	if row["kind"] == "slider":
		var id := String(row["id"])
		Store.set_value(id, clampf(snappedf(Store.volume(id) + d, 0.05), 0.0, 1.0))
		UI.sound(world, "tick", -14.0)
	elif row["kind"] == "toggle":
		_activate(_sel)


func _activate(i: int) -> void:
	if i < 0 or i >= _rows.size():
		return
	var row: Dictionary = _rows[i]
	var id := String(row["id"])
	match String(row["kind"]):
		"toggle":
			Store.set_value(id, not bool(Store.get_value(id, false)))
			UI.sound(world, "click_wood", -12.0)
		"slider":
			pass
		_:
			UI.sound(world, "click_wood", -12.0)
			if id == "settings":
				open("settings")
			elif id == "back":
				open("main")
			else:
				action.emit(id)
	queue_redraw()


func _row_rect(i: int) -> Rect2:
	return Rect2(Vector2(_card.position.x + 28, _card.position.y + 140 + i * ROW), Vector2(W_CARD - 56, ROW - 8))


func _slider_rect(i: int) -> Rect2:
	var r := _row_rect(i)
	return Rect2(Vector2(r.position.x + 180, r.get_center().y - 5), Vector2(r.size.x - 180 - 92, 10))


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		var p := (e as InputEventMouseMotion).position
		if _drag >= 0:
			_set_from_mouse(_drag, p)
			return
		var h := -1
		for i in _rows.size():
			if _row_rect(i).has_point(p):
				h = i
		if h != _hover:
			_hover = h
			if h >= 0:
				_sel = h
				UI.sound(world, "tick", -22.0)
			queue_redraw()
	elif e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		accept_event()
		if not mb.pressed:
			_drag = -1
			return
		for i in _rows.size():
			if _row_rect(i).has_point(mb.position):
				_sel = i
				var row: Dictionary = _rows[i]
				if row["kind"] == "slider":
					_drag = i
					_set_from_mouse(i, mb.position)
				else:
					_activate(i)
				return


func _set_from_mouse(i: int, p: Vector2) -> void:
	var sr := _slider_rect(i)
	var v := clampf((p.x - sr.position.x) / sr.size.x, 0.0, 1.0)
	Store.set_value(String(_rows[i]["id"]), snappedf(v, 0.05))
	queue_redraw()


func _process(delta: float) -> void:
	if not visible:
		return
	_a = move_toward(_a, 1.0, delta * 6.0)
	if _card.size.x <= 0.0 or not _card.get_center().is_equal_approx(size * 0.5):
		_build()
	queue_redraw()


func _draw() -> void:
	var a := _a
	Draw.rect(self, Rect2(Vector2.ZERO, size), Color(0.02, 0.015, 0.01, 0.62 * a))
	var lift := (1.0 - a) * 18.0
	var r := Rect2(_card.position + Vector2(0, lift), _card.size)
	UI.panel(self, r, a, 10.0)
	var deco := UI.font("deco")
	var cond := UI.font("cond")
	UI.text_c(self, r.get_center().x + 2, r.position.y + 72, "FAMIGLIA", deco, 52, Color(0, 0, 0, 0.5 * a))
	UI.text_c(self, r.get_center().x, r.position.y + 70, "FAMIGLIA", deco, 52, UI.with_a(UI.GOLD2, a))
	var sub := "SETTINGS" if page != "main" else ("PAUSED" if paused_game else "ONLINE · THE CITY KEEPS MOVING")
	UI.text_c(self, r.get_center().x, r.position.y + 104, sub, cond, 16, UI.with_a(UI.MUTE, a))
	UI.rule(self, Vector2(r.position.x + 60, r.position.y + 122), Vector2(r.end.x - 60, r.position.y + 122), UI.with_a(UI.BRASS, 0.6 * a))
	for i in _rows.size():
		_row(i, a, lift)


func _row(i: int, a: float, lift: float) -> void:
	var row: Dictionary = _rows[i]
	var rr := _row_rect(i)
	rr.position.y += lift
	var on := i == _sel
	if on:
		UI.grad_rrect(self, rr, 6.0, UI.with_a(Color("6a4e2a"), 0.8 * a), UI.with_a(Color("3a2a1a"), 0.8 * a))
		UI.rrect_line(self, rr, 6.0, UI.with_a(UI.BRASS, a), 1.5)
	else:
		UI.rrect_line(self, rr, 6.0, UI.with_a(UI.BRASS_DK, 0.6 * a), 1.0)
	var semi := UI.font("semi")
	var sans := UI.font("sans")
	var cy := rr.get_center().y
	var x := rr.position.x + 18.0
	var ic := String(row["icon"])
	var kind := String(row["kind"])
	if ic != "":
		if ic == "play":
			Draw.poly(self, PackedVector2Array([Vector2(x + 4, cy - 9), Vector2(x + 18, cy), Vector2(x + 4, cy + 9)]), UI.with_a(UI.GOLD2, a))
		else:
			UI.icon(self, ic, Vector2(x + 11, cy), 22.0, UI.with_a(UI.GOLD2, a), Color("241912"))
		x += 36.0
	var sub := String(row["sub"])
	var ty := UI.mid(semi, 21, cy) if sub == "" else cy + 1.0
	UI.text(self, Vector2(x, ty), String(row["text"]), semi, 21, UI.with_a(Color("fff4dc") if on else UI.INK, a))
	if sub != "":
		UI.text(self, Vector2(x, cy + 19.0), sub, sans, 16, UI.with_a(UI.MUTE, a))
	var k := String(row["key"])
	if k != "":
		var kw := UI.keycap_w(k, 24.0)
		UI.keycap(self, Rect2(Vector2(rr.end.x - 14 - kw, cy - 12), Vector2(24, 24)), k, a, on)
	if kind == "slider":
		var sr := _slider_rect(i)
		sr.position.y += lift
		var v := Store.volume(String(row["id"]))
		Draw.rrect(self, sr.grow(2.0), 5.0, UI.with_a(Color(0, 0, 0, 0.6), a))
		if v > 0.0:
			UI.grad_rrect(self, Rect2(sr.position, Vector2(sr.size.x * v, sr.size.y)), 4.0, UI.with_a(UI.GOLD2, a), UI.with_a(UI.GOLD, a))
		var knob := Vector2(sr.position.x + sr.size.x * v, sr.get_center().y)
		Draw.circle(self, knob + Vector2(1, 2), 10.0, Color(0, 0, 0, 0.45 * a))
		Draw.circle(self, knob, 10.0, UI.with_a(UI.BRASS_DK, a))
		Draw.circle(self, knob, 8.5, UI.with_a(UI.BRASS_HI if on else UI.BRASS, a))
		UI.text_r(self, rr.end.x - 14, UI.mid(semi, 17, cy), "%d%%" % int(roundf(v * 100.0)), semi, 17, UI.with_a(UI.INK, a))
	elif kind == "toggle":
		var onv := bool(Store.get_value(String(row["id"]), false)) or (String(row["id"]) == "fullscreen" and Store.fullscreen())
		var tr := Rect2(Vector2(rr.end.x - 76, cy - 13), Vector2(58, 26))
		UI.grad_rrect(self, tr, 13.0, UI.with_a(UI.GREEN.darkened(0.45) if onv else Color("2a221c"), a), UI.with_a(UI.GREEN.darkened(0.2) if onv else Color("171210"), a))
		UI.rrect_line(self, tr, 13.0, UI.with_a(UI.BRASS_DK, a), 1.5)
		var kx := tr.end.x - 13.0 if onv else tr.position.x + 13.0
		Draw.circle(self, Vector2(kx, cy), 10.0, UI.with_a(UI.BRASS_HI if on else UI.BRASS, a))
		var cond := UI.font("cond")
		UI.text_r(self, tr.position.x - 12, UI.mid(cond, 15, cy), "ON" if onv else "OFF", cond, 15, UI.with_a(UI.GREEN if onv else UI.MUTE, a))
