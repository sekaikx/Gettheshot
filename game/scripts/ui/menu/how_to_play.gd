class_name MenuHowTo
extends VBoxContainer
## How to play: eight short illustrated cards, one at a time. Arrow keys, the numbered tabs or
## Prev / Next flip them. Built for the cream menu panel; the HUD can reuse it as it is.

signal closed

const CARDS := [
	{"id": "walk", "title": "Walk and talk",
		"lines": ["Walk with WASD or the arrow keys. Hold Shift to run.",
			"Walk up to a person or a door and press E.",
			"Listen to people. They tell you who is weak and who pays."],
		"keys": [["E", "Talk, use"], ["Shift", "Run"], ["V", "Car"]]},
	{"id": "shakedown", "title": "Shakedowns",
		"lines": ["Stand at a shop's counter and offer protection.",
			"If he says no, scare him: break his things, rough him up.",
			"Every owner has a weak spot. Hit it and he folds twice as fast.",
			"Watch the fear bar. At the mark he pays. Too far and he runs to the cops."],
		"keys": [["F", "Punch, break"], ["G", "Shoot"]]},
	{"id": "money", "title": "Money",
		"lines": ["Wallet: the cash on you. Get knocked down and you lose it.",
			"Stash: the family's dirty money, in the safe at your club.",
			"Bank: clean money. Only the Bank buys a business.",
			"Fronts (shops you own) wash the Stash into the Bank every month."],
		"keys": []},
	{"id": "men", "title": "Your men",
		"lines": ["Hire men at the pool hall. Each one is good at one thing.",
			"A Bruiser scares owners, a Driver gets the booze through, a Talker makes deals.",
			"Face someone and press R: your men go for him.",
			"Give orders in the family book: guard a shop, collect, run booze."],
		"keys": [["R", "Send your men"], ["Tab", "Family book"]]},
	{"id": "booze", "title": "Booze and speakeasies",
		"lines": ["Open a speakeasy in the back of a shop you own.",
			"At night a boat ties up at the middle pier. Buy crates there.",
			"Load your truck, drive the crates to your speakeasy.",
			"A stocked speakeasy makes money every month."],
		"keys": [["V", "Get in the truck"], ["Q", "Drop a crate"]]},
	{"id": "heat", "title": "Heat and the law",
		"lines": ["What you do in the open adds Heat.",
			"Put a patrolman on the payroll: slip him $100 and he looks away.",
			"At 100 Heat the feds raid you.",
			"The family book shows the case against you, and how to fix it."],
		"keys": [["Tab", "Family book"]]},
	{"id": "favors", "title": "Favors",
		"lines": ["A \"!\" over a door: that shop owner has a problem.",
			"Run off the thugs, get his money back, carry a parcel.",
			"Do him the favor and he pays you. No broken glass."],
		"keys": [["E", "Ask what's wrong"]]},
	{"id": "rivals", "title": "Rivals and sit-downs",
		"lines": ["Other families want the same streets.",
			"Ask for a sit-down: a truce, a tribute or an alliance.",
			"Keep your word. Break it and nobody trusts you again.",
			"Take their shops one by one and they fall."],
		"keys": [["Tab", "Rivals"], ["M", "City map"], ["J", "Country"]]},
]

var page := 0
var _art: MenuCardArt
var _title: Label
var _count: Label
var _lines: VBoxContainer
var _keys: HBoxContainer
var _tabs: HBoxContainer
var _prev: Button
var _next: Button


func _ready() -> void:
	add_theme_constant_override("separation", 18)
	var card := HBoxContainer.new()
	card.add_theme_constant_override("separation", 34)
	add_child(card)
	var art_box := PanelContainer.new()
	var sh := StyleBoxFlat.new()
	sh.bg_color = Color(0, 0, 0, 0)
	sh.shadow_color = Color(0, 0, 0, 0.22)
	sh.shadow_size = 8
	sh.shadow_offset = Vector2(3, 4)
	art_box.add_theme_stylebox_override("panel", sh)
	art_box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_art = MenuCardArt.new()
	art_box.add_child(_art)
	card.add_child(art_box)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 10)
	text.custom_minimum_size = Vector2(470, 330)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_child(text)
	_count = MenuStyle.caption("")
	text.add_child(_count)
	_title = MenuStyle.label("", "deco", 31, MenuStyle.INK)
	text.add_child(_title)
	var rule := ColorRect.new()
	rule.color = MenuStyle.BRASS
	rule.custom_minimum_size = Vector2(80, 3)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	text.add_child(rule)
	_lines = VBoxContainer.new()
	_lines.add_theme_constant_override("separation", 8)
	text.add_child(_lines)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.add_child(sp)
	_keys = HBoxContainer.new()
	_keys.add_theme_constant_override("separation", 18)
	text.add_child(_keys)
	# the page tabs and prev / next
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 10)
	add_child(nav)
	_prev = MenuStyle.button("Previous", "secondary", 150)
	_prev.pressed.connect(func() -> void: flip(-1))
	nav.add_child(_prev)
	var mid := CenterContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.add_child(mid)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 6)
	mid.add_child(_tabs)
	for k in CARDS.size():
		var b := _tab_button(k)
		_tabs.add_child(b)
	_next = MenuStyle.button("Next", "primary", 150)
	_next.pressed.connect(func() -> void: flip(1))
	nav.add_child(_next)
	show_page(0)


func _tab_button(k: int) -> Button:
	var b := Button.new()
	b.text = str(k + 1)
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(40, 40)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", W.ui_font("cond"))
	b.add_theme_font_size_override("font_size", 19)
	var off := StyleBoxFlat.new()
	off.bg_color = Color(MenuStyle.PAPER_HI, 0.6)
	off.border_color = Color(MenuStyle.INK, 0.35)
	off.set_border_width_all(1)
	off.set_corner_radius_all(20)
	var hov := off.duplicate() as StyleBoxFlat
	hov.bg_color = Color(MenuStyle.BRASS, 0.25)
	var on := off.duplicate() as StyleBoxFlat
	on.bg_color = MenuStyle.INK
	on.border_color = MenuStyle.INK
	b.add_theme_stylebox_override("normal", off)
	b.add_theme_stylebox_override("hover", hov)
	b.add_theme_stylebox_override("pressed", on)
	b.add_theme_stylebox_override("hover_pressed", on)
	var ring := MenuStyle.focus_ring(18)
	b.add_theme_stylebox_override("focus", ring)
	b.add_theme_color_override("font_color", MenuStyle.INK)
	b.add_theme_color_override("font_hover_color", MenuStyle.INK)
	b.add_theme_color_override("font_focus_color", MenuStyle.INK)
	b.add_theme_color_override("font_pressed_color", MenuStyle.GOLD2)
	b.add_theme_color_override("font_hover_pressed_color", MenuStyle.GOLD2)
	b.tooltip_text = String(CARDS[k]["title"])
	b.pressed.connect(func() -> void: show_page(k))
	return b


func flip(d: int) -> void:
	if page + d >= CARDS.size():
		closed.emit()
		return
	show_page(clampi(page + d, 0, CARDS.size() - 1))


func show_page(k: int) -> void:
	page = clampi(k, 0, CARDS.size() - 1)
	var c: Dictionary = CARDS[page]
	_art.card = String(c["id"])
	_count.text = "CARD %d OF %d" % [page + 1, CARDS.size()]
	_title.text = String(c["title"]).to_upper()
	for n in _lines.get_children():
		n.queue_free()
	for line in c["lines"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var dot := _Diamond.new()
		row.add_child(dot)
		var l := MenuStyle.body(String(line), 19, MenuStyle.INK)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.custom_minimum_size = Vector2(440, 0)
		row.add_child(l)
		_lines.add_child(row)
	for n in _keys.get_children():
		n.queue_free()
	for kd in c["keys"]:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		h.add_child(MenuWidgets.KeyCap.new(String(kd[0])))
		var kl := MenuStyle.label(String(kd[1]), "semi", 17, MenuStyle.INK_SOFT)
		kl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(kl)
		_keys.add_child(h)
	for i in _tabs.get_child_count():
		(_tabs.get_child(i) as Button).set_pressed_no_signal(i == page)
	_prev.disabled = page == 0
	_next.text = "Done" if page == CARDS.size() - 1 else "Next"


## Arrow keys flip the cards (call from the owner's _input).
func handle_key(k: Key) -> bool:
	if k == KEY_LEFT:
		flip(-1)
		return true
	if k == KEY_RIGHT:
		if page < CARDS.size() - 1:
			flip(1)
		return true
	return false


func first_focus() -> Control:
	return _next


class _Diamond extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(10, 26)
		size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	func _draw() -> void:
		var c := Vector2(5, 13)
		Draw.poly(self, PackedVector2Array([c + Vector2(0, -5), c + Vector2(5, 0), c + Vector2(0, 5), c + Vector2(-5, 0)]), MenuStyle.OXBLOOD)
