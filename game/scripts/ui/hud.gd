extends CanvasLayer
## Everything on screen over the street. STUB (working, plain): the HUD piece replaces the look;
## the functions below are the contract the World calls (docs/REBUILD_2D.md, "HUD").

var world: Node
var jail_until := 0.0

var _root: Control
var _top: Label
var _date: Label
var _prompt: Label
var _toasts: VBoxContainer
var _obj: Label
var _mentor: Label
var _mentor_t := 0.0
var _talk: PanelContainer
var _talk_title: Label
var _talk_body: RichTextLabel
var _talk_opts: VBoxContainer
var _talk_actions: Array = []
var _meters := {}
var _meter_layer: Control
var _modal := ""
var _objective := {}
var _paper: PanelContainer
var _paper_body: VBoxContainer
var _paper_t := 0.0
var _menu: PanelContainer
var _help: PanelContainer
var _final: PanelContainer
var _book: Control
var _map: Control
var _nation: Control
var _jail: Label
var _waypoint := Vector2.INF


func _ready() -> void:
	layer = W.LAYER_HUD
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = _theme()
	add_child(_root)
	_meter_layer = Control.new()
	_meter_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_meter_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_meter_layer.draw.connect(_draw_world_marks)
	_root.add_child(_meter_layer)
	_top = _label("", 22)
	_top.position = Vector2(16, 10)
	_root.add_child(_top)
	_date = _label("", 22)
	_date.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_date.position = Vector2(-420, 10)
	_date.size = Vector2(400, 30)
	_date.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_root.add_child(_date)
	_obj = _label("", 18, Pal.GOLD2)
	_obj.position = Vector2(16, 48)
	_root.add_child(_obj)
	_prompt = _label("", 20)
	_prompt.add_theme_constant_override("outline_size", 8)
	_prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	_root.add_child(_prompt)
	_toasts = VBoxContainer.new()
	_toasts.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_toasts.position = Vector2(-440, 50)
	_toasts.size = Vector2(420, 300)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_toasts)
	_mentor = _label("", 18, Pal.INK)
	_mentor.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_mentor.position = Vector2(16, -120)
	_mentor.size = Vector2(700, 100)
	_mentor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_root.add_child(_mentor)
	_build_talk()
	_paper = _panel(Vector2(560, 420))
	_paper_body = VBoxContainer.new()
	_paper.add_child(_paper_body)
	_paper.visible = false
	_menu = _panel(Vector2(360, 300))
	var mv := VBoxContainer.new()
	_menu.add_child(mv)
	mv.add_child(_label("Paused", 28))
	for it in [["Resume", func() -> void: escape()], ["How to play", func() -> void:
			escape()
			toggle_help()], ["Save", func() -> void:
			Net.to_host("save", [])
			escape()], ["Quit to menu", func() -> void:
			if Net.is_host() and Game.running:
				Game.save_campaign()
			Net.leave()
			get_tree().change_scene_to_file("res://scenes/main.tscn")]]:
		var b := Button.new()
		b.text = it[0]
		b.pressed.connect(it[1])
		mv.add_child(b)
	_menu.visible = false
	_help = _panel(Vector2(700, 460))
	var hl := _label("WASD walk · Shift run · E talk / use · F punch · G shoot · R send your men · V car\nTab the family · M the city · J the country · N the paper · Esc pause", 18)
	hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_help.add_child(hl)
	_help.visible = false
	_final = _panel(Vector2(800, 560))
	_final.visible = false
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
	_jail = _label("", 36, Pal.GOLD2)
	_jail.set_anchors_preset(Control.PRESET_CENTER)
	_jail.position = Vector2(-300, -40)
	_jail.size = Vector2(600, 80)
	_jail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_jail)
	refresh()


func _theme() -> Theme:
	var t := Theme.new()
	t.default_font = W.ui_font("sans")
	t.default_font_size = 18
	var sb := StyleBoxFlat.new()
	sb.bg_color = Pal.PANEL
	sb.border_color = Pal.PANEL_LINE
	sb.set_border_width_all(1)
	sb.set_content_margin_all(14)
	t.set_stylebox("panel", "PanelContainer", sb)
	t.set_color("font_color", "Label", Pal.INK)
	t.set_font("font", "Button", W.ui_font("cond"))
	t.set_font_size("font_size", "Button", 19)
	return t


func _label(text: String, size: int, color: Color = Pal.INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _panel(size: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.position = -size * 0.5
	p.custom_minimum_size = size
	_root.add_child(p)
	return p


func _build_talk() -> void:
	_talk = PanelContainer.new()
	_talk.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_talk.custom_minimum_size = Vector2(760, 0)
	_talk.visible = false
	_root.add_child(_talk)
	var v := VBoxContainer.new()
	_talk.add_child(v)
	_talk_title = _label("", 24, Pal.GOLD2)
	v.add_child(_talk_title)
	_talk_body = RichTextLabel.new()
	_talk_body.bbcode_enabled = true
	_talk_body.fit_content = true
	_talk_body.custom_minimum_size = Vector2(720, 20)
	v.add_child(_talk_body)
	_talk_opts = VBoxContainer.new()
	v.add_child(_talk_opts)


# ------------------------------------------------------------------ the contract

func _me() -> Dictionary:
	return Game.player(Net.my_id())


func refresh() -> void:
	if _top == null:
		return
	var p := _me()
	var f := Game.fam(int(p.get("family", -1)))
	if f.is_empty():
		return
	var ars: Dictionary = f.get("arsenal", {})
	_top.text = "%s FAMILY   Wallet $%s   Stash $%s   Bank $%s   Men %d   Guns %d · %d   Heat %d" % [String(f["name"]).to_upper(),
		W.money(int(p.get("wallet", 0))), W.money(int(f["dirty"])), W.money(int(f["clean"])), Game.crew_of(f["id"]).size(),
		int(ars.get("pistol", 0)) + int(ars.get("tommy", 0)), int(ars.get("ammo", 0)), int(f["heat"])]
	var c := Game.clock
	var tod := "night" if c >= 0.58 else ("dusk" if c >= 0.42 else ("day" if c > 0.08 else "dawn"))
	_date.text = "%s · %s" % [Game.date_text(), tod]
	if _book.visible and _book.has_method("refresh"):
		_book.call("refresh")


func toast(text: String, kind: String = "info") -> void:
	if text == "":
		return
	var l := _label(text, 17, {"bad": Pal.UI_RED, "good": Pal.UI_GREEN, "warn": Color("f0a060"), "deal": Color("8ab0ff"), "money": Pal.GOLD2}.get(kind, Pal.INK))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(420, 0)
	_toasts.add_child(l)
	_toasts.move_child(l, 0)
	while _toasts.get_child_count() > 6:
		var old := _toasts.get_child(_toasts.get_child_count() - 1)
		_toasts.remove_child(old)
		old.queue_free()
	var tw := create_tween()
	tw.tween_interval(6.0)
	tw.tween_property(l, "modulate:a", 0.0, 1.0)
	tw.tween_callback(l.queue_free)


var _prompt_pos := Vector2.INF
func set_prompt(text: String, world_pos: Vector2 = Vector2.INF, key: String = "E") -> void:
	_prompt.text = ("[%s] %s" % [key, text]) if text != "" and key != "" else text
	_prompt_pos = world_pos


func converse(conv: Dictionary) -> void:
	_talk_title.text = "%s%s" % [conv.get("name", ""), ("  ·  " + String(conv["role"])) if conv.get("role", "") != "" else ""]
	var body := String(conv.get("line", ""))
	for i in conv.get("info", []):
		body += "\n[color=#9b907c]%s[/color]" % i
	if conv.has("meter"):
		var m: Dictionary = conv["meter"]
		body += "\n%s %d%%" % [m.get("label", ""), int(float(m.get("value", 0)) * 100)]
	_talk_body.text = body
	for c in _talk_opts.get_children():
		c.queue_free()
	_talk_actions.clear()
	var n := 1
	for o in conv.get("options", []):
		var b := Button.new()
		b.text = "%d  %s%s" % [n, o.get("text", ""), ("   (%s)" % o["sub"]) if o.get("sub", "") != "" else ""]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = not bool(o.get("enabled", true))
		var idx := _talk_actions.size()
		b.pressed.connect(func() -> void: _choose(idx))
		_talk_opts.add_child(b)
		_talk_actions.append(o)
		n += 1
	_talk.visible = true
	_modal = "talk"
	_talk.reset_size()
	var area := _root.size
	_talk.position = Vector2((area.x - _talk.size.x) * 0.5, area.y - _talk.size.y - 40)


func _choose(i: int) -> void:
	if i < 0 or i >= _talk_actions.size():
		return
	var o: Dictionary = _talk_actions[i]
	if not bool(o.get("enabled", true)):
		return
	var keep := bool(o.get("keep_open", false))
	if not keep:
		close_conversation()
	var act: Callable = o.get("action", Callable())
	if act.is_valid():
		act.call()


func close_conversation() -> void:
	_talk.visible = false
	if _modal in ["talk", "arrest"]:
		_modal = ""


func set_meter(id: String, world_pos: Vector2, value: float, mark: float = -1.0, label: String = "", color: Color = Pal.UI_RED) -> void:
	_meters[id] = {"pos": world_pos, "v": value, "mark": mark, "label": label, "color": color}


func clear_meter(id: String) -> void:
	_meters.erase(id)


func set_objective(obj: Dictionary) -> void:
	_objective = obj
	_obj.text = ("%s\n%s" % [obj.get("title", ""), obj.get("detail", "")]) if not obj.is_empty() else ""


func clear_objective() -> void:
	set_objective({})


func get_objective() -> Dictionary:
	return _objective.duplicate()


## A banner when you walk into a place: its name, and who it pays (World calls it on entering).
func show_place(title: String, sub: String) -> void:
	toast("%s · %s" % [title, sub] if sub != "" else title, "info")


func set_waypoint(px: Vector2) -> void:
	_waypoint = px
	toast("Waypoint set.", "info")


func mentor_say(name: String, text: String, _portrait: Dictionary = {}, seconds: float = 8.0) -> void:
	_mentor.text = "%s: \"%s\"" % [name, text]
	_mentor_t = seconds


func is_modal() -> bool:
	return _modal != ""


func in_jail() -> bool:
	return jail_until > Time.get_ticks_msec() / 1000.0


func escape() -> void:
	match _modal:
		"":
			_menu.visible = true
			_modal = "menu"
		"menu":
			_menu.visible = false
			_modal = ""
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
			_paper.visible = false
			_modal = ""


func modal_key(k: int) -> void:
	if _modal in ["talk", "arrest"]:
		_choose(k - KEY_1)
	elif _modal == "family" and k == KEY_TAB:
		toggle_family()
	elif _modal == "map" and k == KEY_M:
		toggle_map()
	elif _modal == "nation" and k == KEY_J:
		toggle_nation()
	elif _modal == "help" and k in [KEY_H, KEY_F1, KEY_ENTER, KEY_SPACE]:
		toggle_help()
	elif _modal == "paper" and k in [KEY_N, KEY_SPACE, KEY_ENTER]:
		_paper.visible = false
		_modal = ""


func _toggle(node: Control, name: String) -> void:
	if _modal not in ["", name]:
		return
	node.visible = not node.visible
	_modal = name if node.visible else ""
	if node.visible and node.has_method("open"):
		node.call("open")


func toggle_family() -> void:
	_toggle(_book, "family")


func toggle_map() -> void:
	_toggle(_map, "map")


func toggle_nation() -> void:
	_toggle(_nation, "nation")


func toggle_help() -> void:
	_toggle(_help, "help")


func show_newspaper(m: int) -> void:
	for c in _paper_body.get_children():
		c.queue_free()
	_paper_body.add_child(_label("The Daily Ledger · %s" % Game.date_text(), 26, Pal.GOLD2))
	var shown := 0
	for n in Game.news:
		if m >= 0 and int(n["month"]) < Game.month - 1:
			break
		var l := _label(String(n["text"]), 18)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(520, 0)
		_paper_body.add_child(l)
		shown += 1
		if shown >= 6:
			break
	if shown == 0:
		return
	_paper.visible = true
	_paper_t = 9.0
	if m < 0:
		_modal = "paper" if _modal == "" else _modal


func show_arrest(_cop_key: String, price: int) -> void:
	for n in [_book, _map, _nation, _menu, _help]:
		n.visible = false
	_modal = ""
	var p := _me()
	converse({"name": "\"You're coming with me.\"", "line": "The cop has you by the collar. He could be persuaded: $%d." % price,
		"options": [{"text": "Slip him $%d" % price, "icon": "money", "enabled": int(p.get("wallet", 0)) >= price, "action": func() -> void: Net.to_host("arrest", ["bribe"])},
			{"text": "Go quietly", "sub": "a night in a cell, lose your wallet", "action": func() -> void: Net.to_host("arrest", ["quiet"])},
			{"text": "Shove him and run", "sub": "more heat", "icon": "fist", "action": func() -> void: Net.to_host("arrest", ["run"])}]})
	_modal = "arrest"


func show_final() -> void:
	for c in _final.get_children():
		c.queue_free()
	var v := VBoxContainer.new()
	_final.add_child(v)
	v.add_child(_label("December 1933. Prohibition is over.", 30, Pal.GOLD2))
	var ranks := Game.families.duplicate()
	ranks.sort_custom(func(a, b) -> bool: return Game.legacy(a["id"]) > Game.legacy(b["id"]))
	var n := 1
	for o in ranks:
		v.add_child(_label("%d.  The %s family  ·  $%s" % [n, o["name"], W.money(Game.legacy(o["id"]))], 22, Color(o["color"]).lightened(0.3)))
		n += 1
	var b := Button.new()
	b.text = "Back to the menu"
	b.pressed.connect(func() -> void:
		Net.leave()
		get_tree().change_scene_to_file("res://scenes/main.tscn"))
	v.add_child(b)
	var k := Button.new()
	k.text = "Keep playing"
	k.pressed.connect(func() -> void:
		_final.visible = false
		_modal = "")
	v.add_child(k)
	_final.visible = true
	_modal = "final"


# ------------------------------------------------------------------ frame

func _process(delta: float) -> void:
	if _paper.visible and _modal != "paper":
		_paper_t -= delta
		if _paper_t <= 0.0:
			_paper.visible = false
	if _mentor_t > 0.0:
		_mentor_t -= delta
		if _mentor_t <= 0.0:
			_mentor.text = ""
	var left := jail_until - Time.get_ticks_msec() / 1000.0
	_jail.text = ("In a cell at the 14th Precinct  %d" % ceili(left)) if left > 0.0 else ""
	if world:
		var ct: Transform2D = world.get_viewport().get_canvas_transform()
		if _prompt_pos != Vector2.INF:
			var sp := ct * _prompt_pos
			_prompt.position = sp + Vector2(-_prompt.size.x * 0.5, -60)
		else:
			_prompt.position = Vector2((_root.size.x - _prompt.size.x) * 0.5, _root.size.y - 110)
	_meter_layer.queue_redraw()
	_clock_t -= delta
	if _clock_t <= 0.0:
		_clock_t = 0.5
		refresh()


var _clock_t := 0.0


func _draw_world_marks() -> void:
	if world == null:
		return
	var ct: Transform2D = world.get_viewport().get_canvas_transform()
	for id in _meters:
		var m: Dictionary = _meters[id]
		var sp: Vector2 = ct * (m["pos"] as Vector2) + Vector2(-40, -56)
		_meter_layer.draw_rect(Rect2(sp, Vector2(80, 8)), Color(0, 0, 0, 0.7))
		_meter_layer.draw_rect(Rect2(sp, Vector2(80 * clampf(float(m["v"]), 0.0, 1.0), 8)), m["color"])
		if float(m["mark"]) >= 0.0:
			_meter_layer.draw_line(sp + Vector2(80 * float(m["mark"]), -2), sp + Vector2(80 * float(m["mark"]), 10), Color.WHITE, 2.0)
	var tgt: Vector2 = _objective.get("target", Vector2.INF) if not _objective.is_empty() else _waypoint
	if tgt != Vector2.INF:
		var sp2: Vector2 = ct * tgt
		var r := Rect2(Vector2(30, 30), _root.size - Vector2(60, 60))
		if r.has_point(sp2):
			Draw.circle(_meter_layer, sp2 + Vector2(0, -30), 7, Pal.GOLD2)
		else:
			var c := _root.size * 0.5
			var d := (sp2 - c).normalized()
			var edge := c + d * minf(r.size.x * 0.5 / maxf(absf(d.x), 0.001), r.size.y * 0.5 / maxf(absf(d.y), 0.001))
			Draw.poly(_meter_layer, PackedVector2Array([edge + d * 14, edge + d.orthogonal() * 9, edge - d.orthogonal() * 9]), Pal.GOLD2)
