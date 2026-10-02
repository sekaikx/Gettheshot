extends CanvasLayer
## Everything on screen over the street (docs/REBUILD_2D.md, "HUD"). The World creates it
## (hud.world = self) and calls the functions below; the pieces live in scripts/ui/hud/:
##   money_panel   top-left: crest, family, Wallet, Stash, Bank, men, guns, the Heat badge
##   objective     under it: the current goal, ticked off when it changes
##   clock_panel   top-right: date, sun-and-moon dial, weather, sit-down offers waiting
##   toasts        under the date: messages with icons, five at most
##   world_marks   over the street: the "[E] ..." prompt, meters over people, goal markers, edge arrows
##   talk_box      the conversation at the bottom (portrait, typed line, facts, meter, options)
##   mentor_card   bottom-left: Uncle Carmine's advice (not modal)
##   minimap       bottom-right, north up
##   place_banner  top-centre, when you walk into a place
##   controls      bottom-left, tiny: the keys (fades after a minute)
##   pause_menu    Esc: Resume, How to play, Settings, Save, Quit (the city stops when you play alone)
##   help_cards    How to play: eight illustrated cards
##   newspaper     The Daily Ledger (N), and the folded copy every month
##   jail_overlay  bars and a countdown while you're in a cell
##   final_card    December 1933: who ran New York
## It also hosts the family book (Tab), Don's View (M) and the country map (J).

const UI := preload("res://scripts/ui/hud/hud_ui.gd")
const Store := preload("res://scripts/ui/hud/settings_store.gd")
const MoneyPanel := preload("res://scripts/ui/hud/money_panel.gd")
const ObjectiveCard := preload("res://scripts/ui/hud/objective_card.gd")
const ClockPanel := preload("res://scripts/ui/hud/clock_panel.gd")
const Toasts := preload("res://scripts/ui/hud/toasts.gd")
const WorldMarks := preload("res://scripts/ui/hud/world_marks.gd")
const TalkBox := preload("res://scripts/ui/hud/talk_box.gd")
const MentorCard := preload("res://scripts/ui/hud/mentor_card.gd")
const Minimap := preload("res://scripts/ui/hud/minimap.gd")
const PlaceBanner := preload("res://scripts/ui/hud/place_banner.gd")
const ControlsStrip := preload("res://scripts/ui/hud/controls_strip.gd")
const PauseMenu := preload("res://scripts/ui/hud/pause_menu.gd")
const HelpCards := preload("res://scripts/ui/hud/help_cards.gd")
const Newspaper := preload("res://scripts/ui/hud/newspaper.gd")
const JailOverlay := preload("res://scripts/ui/hud/jail_overlay.gd")
const FinalCard := preload("res://scripts/ui/hud/final_card.gd")

const FULL_MODALS := ["family", "map", "nation", "help", "paper", "final"]

var world: Node
var jail_until := 0.0

var _root: Control
var _base: Control
var _marks: WorldMarks
var _money: MoneyPanel
var _obj: ObjectiveCard
var _clock: ClockPanel
var _toasts: Toasts
var _talk: TalkBox
var _mentor: MentorCard
var _minimap: Minimap
var _place: PlaceBanner
var _controls: ControlsStrip
var _menu: PauseMenu
var _help: HelpCards
var _paper: Newspaper
var _jail: JailOverlay
var _final: FinalCard
var _book: Control
var _map: Control
var _nation: Control

var _modal := ""
var _objective := {}
var _waypoint := Vector2.INF
var _meters := {}
var _talk_actions: Array = []
var _help_from_menu := false
var _paused := false
var _clock_t := 0.0
var _last_size := Vector2.ZERO


func _ready() -> void:
	layer = W.LAYER_HUD
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.name = "HUD"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = _theme()
	add_child(_root)
	_marks = _add(WorldMarks.new(), _root)
	_jail = _add(JailOverlay.new(), _root)
	_base = Control.new()
	_base.name = "Base"
	_base.set_anchors_preset(Control.PRESET_FULL_RECT)
	_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_base)
	_money = _add(MoneyPanel.new(), _base)
	_obj = _add(ObjectiveCard.new(), _base)
	_clock = _add(ClockPanel.new(), _base)
	_minimap = _add(Minimap.new(), _base)
	_controls = _add(ControlsStrip.new(), _base)
	_controls.marks = _marks
	_mentor = _add(MentorCard.new(), _base)
	_place = _add(PlaceBanner.new(), _base)
	_book = preload("res://scripts/ui/family_book.gd").new()
	_book.set("hud", self)
	_book.set_anchors_preset(Control.PRESET_FULL_RECT)
	_book.visible = false
	_root.add_child(_book)
	_map = preload("res://scripts/ui/city_map.gd").new()
	_map.set("hud", self)
	_map.set("world", world)
	_map.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map.visible = false
	_root.add_child(_map)
	_nation = preload("res://scripts/ui/nation_map.gd").new()
	_nation.set("hud", self)
	_nation.set_anchors_preset(Control.PRESET_FULL_RECT)
	_nation.visible = false
	_root.add_child(_nation)
	# the talk box sits above the hosted panels, so a panel can ask something too
	_talk = _add(TalkBox.new(), _root)
	_paper = _add(Newspaper.new(), _root)
	_paper.visible = false
	_help = _add(HelpCards.new(), _root)
	_menu = _add(PauseMenu.new(), _root)
	_final = _add(FinalCard.new(), _root)
	_toasts = _add(Toasts.new(), _root)
	_marks.meters = _meters
	_talk.picked.connect(_choose)
	_menu.action.connect(_menu_action)
	_help.closed.connect(func() -> void:
		if _modal == "help":
			toggle_help())
	_paper.closed.connect(func() -> void:
		if _modal == "paper":
			_modal = "")
	_paper.open_full.connect(func() -> void:
		if _modal == "":
			show_newspaper(-1))
	_final.action.connect(_final_action)
	_minimap.clicked.connect(func() -> void:
		if _modal == "":
			toggle_map())
	_clock.badge_clicked.connect(func() -> void:
		if _modal == "":
			toggle_family())
	_obj.completed.connect(func() -> void: UI.sound(world, "discover", -12.0))
	Store.apply_saved_audio()
	_layout()
	refresh()


func _add(node: Control, parent: Control) -> Variant:
	node.set("world", world)
	parent.add_child(node)
	return node


func _theme() -> Theme:
	var t := Theme.new()
	t.default_font = W.ui_font("sans")
	t.default_font_size = 17
	var panel := _box(Color("1c140f", 0.96), UI.BRASS_DK, 2, 6, 14)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)
	t.set_color("font_color", "Label", Pal.INK)
	t.set_color("default_color", "RichTextLabel", Pal.INK)
	for cls in ["Button", "OptionButton", "CheckBox", "CheckButton", "MenuButton"]:
		t.set_font("font", cls, W.ui_font("cond"))
		t.set_font_size("font_size", cls, 19)
		t.set_color("font_color", cls, Pal.INK)
		t.set_color("font_hover_color", cls, Color("fff4dc"))
		t.set_color("font_pressed_color", cls, Pal.GOLD2)
		t.set_color("font_focus_color", cls, Color("fff4dc"))
		t.set_color("font_disabled_color", cls, Color(Pal.MUTE, 0.7))
		t.set_color("icon_normal_color", cls, Pal.GOLD2)
	var normal := _box(Color("2a1d15"), UI.BRASS_DK, 2, 5, 12)
	var hover := _box(Color("4a3622"), UI.BRASS, 2, 5, 12)
	var pressed := _box(Color("1a120d"), Pal.GOLD, 2, 5, 12)
	var disabled := _box(Color("1e1712"), Color("3a2e22"), 1, 5, 12)
	for cls in ["Button", "OptionButton", "MenuButton"]:
		t.set_stylebox("normal", cls, normal)
		t.set_stylebox("hover", cls, hover)
		t.set_stylebox("pressed", cls, pressed)
		t.set_stylebox("hover_pressed", cls, pressed)
		t.set_stylebox("disabled", cls, disabled)
		t.set_stylebox("focus", cls, StyleBoxEmpty.new())
	for cls in ["CheckBox", "CheckButton"]:
		t.set_stylebox("normal", cls, StyleBoxEmpty.new())
		t.set_stylebox("hover", cls, StyleBoxEmpty.new())
		t.set_stylebox("pressed", cls, StyleBoxEmpty.new())
		t.set_stylebox("focus", cls, StyleBoxEmpty.new())
	var edit := _box(Color("120c09"), UI.BRASS_DK, 1, 4, 8)
	t.set_stylebox("normal", "LineEdit", edit)
	t.set_stylebox("focus", "LineEdit", _box(Color("120c09"), UI.BRASS, 1, 4, 8))
	t.set_color("font_color", "LineEdit", Pal.INK)
	t.set_color("caret_color", "LineEdit", Pal.GOLD2)
	var bar := _box(Color(0, 0, 0, 0.35), Color(0, 0, 0, 0), 0, 4, 0)
	var grab := _box(Color(UI.BRASS, 0.7), Color(0, 0, 0, 0), 0, 4, 0)
	var grab_hi := _box(UI.BRASS, Color(0, 0, 0, 0), 0, 4, 0)
	for cls in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", cls, bar)
		t.set_stylebox("grabber", cls, grab)
		t.set_stylebox("grabber_highlight", cls, grab_hi)
		t.set_stylebox("grabber_pressed", cls, grab_hi)
	t.set_stylebox("slider", "HSlider", _box(Color(0, 0, 0, 0.5), UI.BRASS_DK, 1, 4, 3))
	t.set_stylebox("grabber_area", "HSlider", _box(Pal.GOLD, Color(0, 0, 0, 0), 0, 4, 3))
	t.set_stylebox("grabber_area_highlight", "HSlider", _box(Pal.GOLD2, Color(0, 0, 0, 0), 0, 4, 3))
	var tab := _box(Color("2a1d15"), UI.BRASS_DK, 1, 4, 10)
	t.set_stylebox("tab_selected", "TabBar", _box(Color("4a3622"), UI.BRASS, 1, 4, 10))
	t.set_stylebox("tab_unselected", "TabBar", tab)
	t.set_stylebox("tab_hovered", "TabBar", _box(Color("3a2a1a"), UI.BRASS, 1, 4, 10))
	t.set_stylebox("tab_selected", "TabContainer", _box(Color("4a3622"), UI.BRASS, 1, 4, 10))
	t.set_stylebox("tab_unselected", "TabContainer", tab)
	t.set_stylebox("panel", "TabContainer", panel)
	t.set_stylebox("panel", "TooltipPanel", _box(Color("1c140f", 0.97), UI.BRASS, 1, 4, 8))
	t.set_color("font_color", "TooltipLabel", Pal.INK)
	t.set_stylebox("panel", "PopupMenu", panel)
	t.set_stylebox("hover", "PopupMenu", _box(Color("4a3622"), Color(0, 0, 0, 0), 0, 3, 6))
	t.set_color("font_color", "PopupMenu", Pal.INK)
	t.set_color("font_hover_color", "PopupMenu", Color("fff4dc"))
	t.set_stylebox("panel", "ItemList", edit)
	t.set_color("font_color", "ItemList", Pal.INK)
	return t


static func _box(bg: Color, border: Color, bw: int, radius: int, margin: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	sb.content_margin_top = maxf(margin * 0.5, 4.0) if margin > 0 else 0.0
	sb.content_margin_bottom = maxf(margin * 0.5, 4.0) if margin > 0 else 0.0
	sb.anti_aliasing = true
	return sb


func _layout() -> void:
	var area := _root.size
	if area.x < 10.0:
		area = get_viewport().get_visible_rect().size
	_last_size = area
	_money.position = Vector2(16, 14)
	_obj.position = Vector2(16, 14 + MoneyPanel.H_PANEL + 10)
	_clock.position = Vector2(area.x - 16 - ClockPanel.W_PANEL, 14)
	_minimap.position = Vector2(area.x - 16 - Minimap.SIZE, area.y - 16 - _minimap.size.y)
	_controls.position = Vector2(16, area.y - 16 - ControlsStrip.H)
	_place.position = Vector2.ZERO
	_place.size = Vector2(area.x, 130)
	_place.max_w = clampf(area.x - 2.0 * (MoneyPanel.W_PANEL + 40.0), 360.0, 720.0)
	_paper.mini_bottom = _minimap.position.y - 40.0
	_avoid()


## The HUD panels the edge arrows keep clear of.
func _avoid() -> void:
	var av: Array[Rect2] = [Rect2(Vector2(0, 0), Vector2(MoneyPanel.W_PANEL + 30, 14 + MoneyPanel.H_PANEL + 10 + 110)),
		Rect2(_clock.position, Vector2(ClockPanel.W_PANEL, _clock.used_height())), Rect2(_minimap.position, _minimap.size + Vector2(16, 16))]
	if _paper.mini_showing():
		av.append(Rect2(Vector2(_last_size.x - 400, _paper.mini_bottom - 190), Vector2(400, 210)))
	if _controls.strip_height() > 4.0:
		av.append(Rect2(_controls.position, Vector2(_controls.strip_width(), ControlsStrip.H)))
	if _mentor.is_showing():
		av.append(_mentor.card_rect())
	if _place.is_showing():
		av.append(_place.banner_rect())
	_marks.avoid = av


# ------------------------------------------------------------------ the contract

func _me() -> Dictionary:
	return Game.player(Net.my_id())


func refresh() -> void:
	if _money == null:
		return
	_money.read_game()
	_clock.read_game()
	if _book.visible and _book.has_method("refresh"):
		_book.call("refresh")


func toast(text: String, kind: String = "info") -> void:
	if text == "" or _toasts == null:
		return
	_toasts.push(text, kind)
	if kind == "money":
		UI.sound(world, "coin", -16.0)


func set_prompt(text: String, world_pos: Vector2 = Vector2.INF, key: String = "E") -> void:
	if _marks == null:
		return
	_marks.prompt_text = text
	_marks.prompt_pos = world_pos
	_marks.prompt_key = key


func converse(conv: Dictionary) -> void:
	var was := _talk.visible and _modal in ["talk", "arrest"]
	_talk_actions = conv.get("options", [])
	_talk.open(conv)
	_modal = "talk"
	if not was:
		UI.sound(world, "tick", -14.0)


func _choose(i: int) -> void:
	if i < 0 or i >= _talk_actions.size():
		return
	var o: Dictionary = _talk_actions[i]
	if not bool(o.get("enabled", true)):
		return
	var keep := bool(o.get("keep_open", false))
	UI.sound(world, "click_wood", -14.0)
	if not keep:
		close_conversation()
	var act: Callable = o.get("action", Callable())
	if act.is_valid():
		act.call()


func close_conversation() -> void:
	_talk.close()
	if _modal in ["talk", "arrest"]:
		_modal = ""
		# a panel that asked the question is still open underneath
		for pair in [[_book, "family"], [_map, "map"], [_nation, "nation"]]:
			if (pair[0] as Control).visible:
				_modal = String(pair[1])


func set_meter(id: String, world_pos: Vector2, value: float, mark: float = -1.0, label: String = "", color: Color = Pal.UI_RED) -> void:
	_meters[id] = {"pos": world_pos, "v": value, "mark": mark, "label": label, "color": color}


func clear_meter(id: String) -> void:
	_meters.erase(id)


func set_objective(obj: Dictionary) -> void:
	_objective = obj
	if _obj:
		_obj.set_goal(obj)


func clear_objective() -> void:
	set_objective({})


func get_objective() -> Dictionary:
	return _objective.duplicate()


## A banner when you walk into a place: its name, and who it pays (World calls it on entering).
func show_place(title: String, sub: String) -> void:
	_place.show_place(title, sub)


## A waypoint on the street (Don's View sets it); Vector2.INF clears it.
func set_waypoint(px: Vector2) -> void:
	_waypoint = px
	# Don's View says so itself while it's open
	if px != Vector2.INF and not _map.visible:
		toast("Waypoint set. Follow the flag.", "info")


func mentor_say(name: String, text: String, _portrait: Dictionary = {}, seconds: float = 8.0) -> void:
	_mentor.say(name, text, _portrait, seconds)


func is_modal() -> bool:
	return _modal != ""


func in_jail() -> bool:
	return jail_until > Time.get_ticks_msec() / 1000.0


func escape() -> void:
	match _modal:
		"":
			_open_menu()
		"menu":
			if not _menu.back():
				_close_menu()
		"talk":
			close_conversation()
		"family":
			toggle_family()
		"map":
			toggle_map()
		"nation":
			toggle_nation()
		"help":
			toggle_help()
		"paper":
			_close_paper()


func modal_key(k: int) -> void:
	match _modal:
		"talk", "arrest":
			_talk.key(k)
		"family":
			if k == KEY_TAB:
				toggle_family()
			elif _book.has_method("modal_key"):
				_book.call("modal_key", k)
		"map":
			if k == KEY_M:
				toggle_map()
			elif _map.has_method("modal_key"):
				_map.call("modal_key", k)
		"nation":
			if k == KEY_J:
				toggle_nation()
			elif _nation.has_method("modal_key"):
				_nation.call("modal_key", k)
		"help":
			if k in [KEY_H, KEY_F1, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
				toggle_help()
		"paper":
			if k in [KEY_N, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_E]:
				_close_paper()
		"menu":
			_menu.key(k)
		"final":
			_final.key(k)


func _toggle(node: Control, name: String) -> void:
	if _modal not in ["", name]:
		return
	node.visible = not node.visible
	_modal = name if node.visible else ""
	if node.visible and node.has_method("open"):
		node.call("open")
	UI.sound(world, "page_turn" if node.visible else "click_wood", -12.0)


func toggle_family() -> void:
	_toggle(_book, "family")
	if _book.visible and world and world.has_signal("happened"):
		world.emit_signal("happened", "book", {})


func toggle_map() -> void:
	_toggle(_map, "map")


func toggle_nation() -> void:
	_toggle(_nation, "nation")


func toggle_help() -> void:
	if _modal == "help":
		_help.visible = false
		_modal = ""
		if _help_from_menu:
			_help_from_menu = false
			_open_menu()
		else:
			_set_paused(false)
			_controls.remind()
		return
	if _modal == "menu":
		_help_from_menu = true
		_menu.close()
		_modal = ""
	if _modal != "":
		return
	if not _help_from_menu:
		_set_paused(_solo())
	_help.open()
	_modal = "help"


func show_newspaper(m: int) -> void:
	var stories := Newspaper.pick_stories(m)
	if m >= 0:
		if stories.is_empty() or _modal == "paper":
			return
		_paper.show_mini(stories)
		UI.sound(world, "paper_open", -16.0)
		return
	if _modal not in ["", "paper"]:
		return
	_paper.open_paper(stories)
	_modal = "paper"


func _close_paper() -> void:
	_paper.close_paper()
	if _modal == "paper":
		_modal = ""


func show_arrest(cop_key: String, price: int) -> void:
	for n in [_book, _map, _nation, _help]:
		(n as Control).visible = false
	_menu.close()
	_paper.close_paper()
	_set_paused(false)
	_modal = ""
	var p := _me()
	var portrait := {"kind": "cop", "look": 313, "color": W.FAMILY_NONE, "extra": {}}
	var who := "The patrolman"
	if world and world.has_method("actor"):
		var a: Variant = world.call("actor", cop_key)
		if a is Actor and is_instance_valid(a):
			var ac := a as Actor
			if ac.person:
				portrait = {"kind": ac.person.kind, "look": ac.person.look, "color": ac.person.family_color, "extra": ac.person.extra}
			var c := Game.cop_by_id(ac.ref_id)
			if not c.is_empty() and not cop_key.begins_with("f"):
				who = String(c["name"])
			elif cop_key.begins_with("f"):
				who = "A federal agent"
	var wallet := int(p.get("wallet", 0))
	converse({"name": who, "role": "You're under arrest", "portrait": portrait, "mood": "angry", "stamp": "ARRESTED",
		"line": "\"You're coming with me, pal.\"",
		"info": ["He has you by the collar.", "He could be persuaded: $%s." % W.money(price)],
		"options": [{"text": "Slip him $%s" % W.money(price), "sub": "from your wallet · he lets you go" if wallet >= price else "you only have $%s on you" % W.money(wallet),
				"icon": "money", "enabled": wallet >= price, "action": func() -> void: Net.to_host("arrest", ["bribe"])},
			{"text": "Go quietly", "sub": "a night in a cell · you lose your wallet", "icon": "leave", "action": func() -> void: Net.to_host("arrest", ["quiet"])},
			{"text": "Shove him and run", "sub": "more Heat · he may catch you", "icon": "fist", "action": func() -> void: Net.to_host("arrest", ["run"])}]})
	_modal = "arrest"


func show_final() -> void:
	for n in [_book, _map, _nation, _help]:
		(n as Control).visible = false
	_menu.close()
	_paper.close_paper()
	_talk.close()
	_set_paused(false)
	_final.open()
	_modal = "final"


# ------------------------------------------------------------------ the pause menu

func _open_menu() -> void:
	if _modal != "":
		return
	_set_paused(_solo())
	_menu.paused_game = _paused
	_menu.open("main")
	_modal = "menu"
	UI.sound(world, "click_wood", -12.0)


func _close_menu() -> void:
	_menu.close()
	if _modal == "menu":
		_modal = ""
	_set_paused(false)


## Playing alone, the city stops while the menu or How to play is open. The World's Pauser does
## the stopping (for every panel); this only remembers it, for the menu's "PAUSED" line.
func _set_paused(on: bool) -> void:
	_paused = on


func _solo() -> bool:
	return Net.is_solo and Game.players.size() <= 1


func _leave_to_menu() -> void:
	_set_paused(false)
	if is_inside_tree():
		get_tree().paused = false
	Net.leave()
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _menu_action(id: String) -> void:
	match id:
		"resume":
			_close_menu()
		"help":
			toggle_help()
		"save":
			Net.to_host("save", [])
		"quit":
			if Net.is_host() and Game.running:
				Game.save_campaign()
			_leave_to_menu()


func _final_action(id: String) -> void:
	match id:
		"keep":
			_final.visible = false
			if _modal == "final":
				_modal = ""
		"menu":
			_leave_to_menu()


## While the city is paused (solo, a panel open) the World's controller doesn't run, so the HUD
## reads the keys itself.
func _unhandled_input(e: InputEvent) -> void:
	if not is_inside_tree() or not get_tree().paused or not (e is InputEventKey) or not e.pressed or e.echo:
		return
	var k := (e as InputEventKey).keycode
	get_viewport().set_input_as_handled()
	if k == KEY_ESCAPE:
		escape()
	else:
		modal_key(k)


# ------------------------------------------------------------------ frame

func _process(delta: float) -> void:
	if _root.size != _last_size:
		_layout()
	var talking := _talk.visible and _modal in ["talk", "arrest"]
	var full := _modal in FULL_MODALS
	_base.visible = not full
	_marks.visible = not full
	_mentor.hold = talking or _paused
	_paper.hold = _modal != "" and _modal != "paper"
	_controls.hold = talking
	_minimap.hold = talking
	_marks.hidden_prompt = _modal != "" or in_jail()
	_marks.hidden_meters = _modal != "" or in_jail()
	_marks.hidden_goals = _modal != "" or in_jail()
	_avoid()
	var tg: Variant = _objective.get("target", Vector2.INF)
	_marks.target = tg if tg is Vector2 else Vector2.INF
	_minimap.target = _marks.target
	# a waypoint you've reached goes away
	if _waypoint != Vector2.INF and world:
		var la: Variant = world.get("local_actor")
		if la is Node2D and is_instance_valid(la) and (la as Node2D).position.distance_to(_waypoint) < 3.0 * W.M:
			_waypoint = Vector2.INF
	_marks.waypoint = _waypoint
	_minimap.waypoint = _waypoint
	_jail.until = jail_until
	# the toasts sit under the date (and the sit-down badge)
	var ty := 14 + _clock.used_height() + 10
	_toasts.position = Vector2(_last_size.x - 16 - Toasts.W_TOAST, lerpf(_toasts.position.y, ty, clampf(delta * 10.0, 0.0, 1.0)) if absf(_toasts.position.y - ty) < 200.0 else ty)
	# ...and stop above whatever sits under them: the talk box, the folded paper, the minimap
	var floor_y := _minimap.position.y - 12.0
	if talking:
		floor_y = minf(floor_y, _talk.top_y() - 12.0)
	if _paper.mini_showing() and not _paper.hold:
		floor_y = minf(floor_y, _paper.mini_top() - 14.0)
	_toasts.max_bottom = floor_y - _toasts.position.y
	_toasts.hold = _modal in ["help", "paper", "final", "menu"]
	_mentor.position = Vector2(16, _last_size.y - 16 - 200 - _controls.strip_height() - 8)
	if _paused and _modal not in ["menu", "help"]:
		_set_paused(false)
	_clock_t -= delta
	if _clock_t <= 0.0:
		_clock_t = 0.5
		refresh()
