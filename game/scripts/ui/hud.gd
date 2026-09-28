extends CanvasLayer
## Everything on screen: the family bar, the prompt, notices, the talk panel (what you say at a
## door or to a person), the family ledger (Tab), the city map (M), the newspaper, arrests, the
## cell, the help card and the end of the campaign.

const GOLD := Color("d4a532")
const GOLD2 := Color("f0d58a")
const INK := Color("efe6d2")
const MUTE := Color("9b907c")
const PANEL := Color(0.075, 0.063, 0.052, 0.94)
const LINE := Color("4a3d2c")
const RED := Color("ff6b5b")
const GREEN := Color("8fd19e")

var world: World
var jail_until := 0.0
var serif: FontVariation
var cond: Font
var sans: Font

var _bar: Control
var _crest: Label
var _crest_bg: Panel
var _fam_label: Label
var _stash: Label
var _clean: Label
var _wallet: Label
var _men: Label
var _guns: Label
var _nation: Control
var _heat: ProgressBar
var _date: Label
var _players: Label
var _prompt: Label
var _toasts: VBoxContainer
var _dialog: PanelContainer
var _dlg_title: Label
var _dlg_body: RichTextLabel
var _dlg_opts: VBoxContainer
var _dlg_actions: Array = []
var _family: PanelContainer
var _fam_body: VBoxContainer
var _fam_tab := "crew"
var _map: Control
var _paper: PanelContainer
var _paper_body: VBoxContainer
var _paper_t := 0.0
var _help: PanelContainer
var _menu: PanelContainer
var _jail: Label
var _final: PanelContainer
var _modal := ""
var _deal_badge: Label


func _ready() -> void:
	layer = 5
	serif = FontVariation.new()
	serif.base_font = load("res://assets/fonts/Fraunces-Variable.ttf")
	serif.variation_opentype = {"wght": 600}
	cond = load("res://assets/fonts/barlow-condensed-latin-700-normal.woff2")
	sans = load("res://assets/fonts/barlow-latin-500-normal.woff2")
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.theme = _theme()
	_build_bar(root)
	_prompt = _label("", 22, INK, cond)
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.position = Vector2(-500, -96)
	_prompt.size = Vector2(1000, 40)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_prompt.add_theme_constant_override("outline_size", 8)
	root.add_child(_prompt)
	_toasts = VBoxContainer.new()
	_toasts.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_toasts.position = Vector2(-470, 76)
	_toasts.size = Vector2(450, 400)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.add_theme_constant_override("separation", 6)
	root.add_child(_toasts)
	_build_dialog(root)
	_build_family(root)
	_build_map(root)
	_nation = preload("res://scripts/ui/nation_map.gd").new()
	_nation.hud = self
	_nation.set_anchors_preset(Control.PRESET_FULL_RECT)
	_nation.visible = false
	root.add_child(_nation)
	_build_paper(root)
	_build_help(root)
	_build_menu(root)
	_jail = _label("", 40, GOLD2, serif)
	_jail.set_anchors_preset(Control.PRESET_CENTER)
	_jail.position = Vector2(-400, -60)
	_jail.size = Vector2(800, 120)
	_jail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_jail.add_theme_color_override("font_outline_color", Color.BLACK)
	_jail.add_theme_constant_override("outline_size", 10)
	root.add_child(_jail)
	_final = _panel(root, Vector2(900, 620))
	_final.visible = false
	_help.visible = not Game.has_meta("seen_help")
	if _help.visible:
		_modal = "help"
		Game.set_meta("seen_help", true)
	refresh()


func _theme() -> Theme:
	var t := Theme.new()
	t.default_font = sans
	t.default_font_size = 18
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL
	sb.border_color = LINE
	sb.set_border_width_all(1)
	sb.set_content_margin_all(16)
	t.set_stylebox("panel", "PanelContainer", sb)
	var btn := StyleBoxFlat.new()
	btn.bg_color = Color("241f1a")
	btn.border_color = LINE
	btn.set_border_width_all(1)
	btn.set_content_margin_all(8)
	btn.content_margin_left = 14
	var hov := btn.duplicate() as StyleBoxFlat
	hov.border_color = GOLD
	hov.bg_color = Color("2e261c")
	var dis := btn.duplicate() as StyleBoxFlat
	dis.bg_color = Color("1a1714")
	t.set_stylebox("normal", "Button", btn)
	t.set_stylebox("hover", "Button", hov)
	t.set_stylebox("pressed", "Button", hov)
	t.set_stylebox("focus", "Button", hov)
	t.set_stylebox("disabled", "Button", dis)
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", GOLD2)
	t.set_color("font_disabled_color", "Button", Color("6b6458"))
	t.set_font("font", "Button", cond)
	t.set_font_size("font_size", "Button", 19)
	t.set_color("font_color", "Label", INK)
	t.set_color("default_color", "RichTextLabel", Color("d8ceb8"))
	t.set_font("normal_font", "RichTextLabel", sans)
	t.set_font("bold_font", "RichTextLabel", cond)
	t.set_font_size("normal_font_size", "RichTextLabel", 18)
	t.set_font_size("bold_font_size", "RichTextLabel", 19)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("2a221c")
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("c4552b")
	t.set_stylebox("background", "ProgressBar", bg)
	t.set_stylebox("fill", "ProgressBar", fill)
	return t


func _label(text: String, size: int, color: Color, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if font:
		l.add_theme_font_override("font", font)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _panel(root: Control, size: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.position = -size * 0.5
	p.size = size
	p.custom_minimum_size = size
	root.add_child(p)
	return p


func _stat(parent: Control, cap: String, color: Color) -> Label:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -4)
	v.add_child(_label(cap, 12, MUTE, cond))
	var l := _label("", 22, color, cond)
	v.add_child(l)
	parent.add_child(v)
	return l


func _build_bar(root: Control) -> void:
	var bar := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.06, 0.05, 0.88)
	sb.border_color = LINE
	sb.border_width_bottom = 1
	sb.set_content_margin_all(8)
	sb.content_margin_left = 14
	bar.add_theme_stylebox_override("panel", sb)
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.size.y = 58
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bar)
	_bar = bar
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 26)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(h)
	_crest_bg = Panel.new()
	_crest_bg.custom_minimum_size = Vector2(38, 38)
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color("c42828")
	cs.set_corner_radius_all(19)
	_crest_bg.add_theme_stylebox_override("panel", cs)
	_crest = _label("V", 22, Color("f3e3c0"), serif)
	_crest.set_anchors_preset(Control.PRESET_FULL_RECT)
	_crest.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_crest.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_crest_bg.add_child(_crest)
	h.add_child(_crest_bg)
	_fam_label = _label("", 22, INK, serif)
	h.add_child(_fam_label)
	_stash = _stat(h, "STASH (DIRTY)", Color("c9b36a"))
	_clean = _stat(h, "CLEAN MONEY", GREEN)
	_wallet = _stat(h, "ON YOU", INK)
	_men = _stat(h, "MEN", INK)
	_guns = _stat(h, "GUNS · AMMO", INK)
	var hv := VBoxContainer.new()
	hv.add_child(_label("HEAT", 12, MUTE, cond))
	_heat = ProgressBar.new()
	_heat.custom_minimum_size = Vector2(130, 10)
	_heat.max_value = 100
	_heat.show_percentage = false
	hv.add_child(_heat)
	h.add_child(hv)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(sp)
	_deal_badge = _label("", 18, GOLD2, cond)
	h.add_child(_deal_badge)
	_players = _label("", 16, MUTE, cond)
	h.add_child(_players)
	_date = _label("", 24, INK, serif)
	h.add_child(_date)


func _build_dialog(root: Control) -> void:
	_dialog = PanelContainer.new()
	_dialog.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_dialog.size = Vector2(640, 10)
	_dialog.position = Vector2(-320, -560)
	_dialog.custom_minimum_size = Vector2(640, 0)
	_dialog.visible = false
	root.add_child(_dialog)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_dialog.add_child(v)
	_dlg_title = _label("", 26, INK, serif)
	v.add_child(_dlg_title)
	_dlg_body = RichTextLabel.new()
	_dlg_body.bbcode_enabled = true
	_dlg_body.fit_content = true
	_dlg_body.custom_minimum_size = Vector2(600, 20)
	v.add_child(_dlg_body)
	_dlg_opts = VBoxContainer.new()
	_dlg_opts.add_theme_constant_override("separation", 5)
	v.add_child(_dlg_opts)


func _build_family(root: Control) -> void:
	_family = _panel(root, Vector2(980, 660))
	_family.visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_family.add_child(v)
	var tabs := HBoxContainer.new()
	for t in [["crew", "THE FAMILY"], ["biz", "BUSINESSES"], ["supply", "SUPPLY"], ["case", "THE CASE"], ["deals", "SIT-DOWNS & RIVALS"], ["books", "THE BOOKS"]]:
		var b := Button.new()
		b.text = t[1]
		var key: String = t[0]
		b.pressed.connect(func() -> void:
			_fam_tab = key
			_fill_family())
		tabs.add_child(b)
	var close := Button.new()
	close.text = "CLOSE (TAB)"
	close.pressed.connect(toggle_family)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_child(sp)
	tabs.add_child(close)
	v.add_child(tabs)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(940, 560)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_fam_body = VBoxContainer.new()
	_fam_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fam_body.add_theme_constant_override("separation", 6)
	scroll.add_child(_fam_body)


func _build_map(root: Control) -> void:
	_map = preload("res://scripts/ui/city_map.gd").new()
	_map.world = world
	_map.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map.visible = false
	root.add_child(_map)


func _build_paper(root: Control) -> void:
	_paper = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("e6dcc3")
	sb.set_content_margin_all(22)
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 18
	_paper.add_theme_stylebox_override("panel", sb)
	_paper.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_paper.position = Vector2(24, -380)
	_paper.custom_minimum_size = Vector2(520, 0)
	_paper.rotation = -0.02
	_paper.visible = false
	root.add_child(_paper)
	_paper_body = VBoxContainer.new()
	_paper_body.add_theme_constant_override("separation", 6)
	_paper.add_child(_paper_body)


func _build_help(root: Control) -> void:
	_help = _panel(root, Vector2(860, 760))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_help.add_child(v)
	v.add_child(_label("How the family business works", 30, INK, serif))
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.custom_minimum_size = Vector2(780, 0)
	r.text = """[b]You are the boss.[/b] Walk the streets of New York and build an empire one door at a time. Prohibition turns every cellar into a gold mine, until December 1933.

[b]Shops[/b]: walk to a door and press [b]E[/b]. Offer [b]protection[/b] (bring your crew: men standing behind you help). If they refuse, [b]lean on them[/b]: the window gets smashed, but witnesses talk. Every month they pay into an envelope: [b]collect it[/b], or put a man on [b]collecting[/b] in that district.
[b]Money is dirty.[/b] The stash pays wages and bribes. To buy a shop you need [b]clean[/b] money, and a shop you own [b]launders[/b] dirty cash every month. A bought shop can hide a [b]speakeasy[/b] in the back.
[b]Booze[/b]: at night a boat ties up at the middle pier on the Waterfront. Buy crates from the man on the pier, carry them to your truck (E), drive (V) to your speakeasy and park at the door. Cops who aren't paid will chase anyone carrying contraband.
[b]Men[/b]: hire muscle at the pool halls. Tab lets you give orders: follow, collect, guard. Press [b]R[/b] to send them at whoever you're facing. Pay them, and look after the families of men in prison, or they talk.
[b]The law[/b]: crimes seen by people add [b]heat[/b]. A cop who sees it chases you: bribe him, go quietly, or run. Put cops on the payroll (E on a cop), or buy the precinct captain. At 100 heat, the feds raid you.
[b]Rivals[/b] (AI families or your friends): press E on their boss or at their club for a [b]sit-down[/b]: truces, tribute, alliances. Nothing is enforced. Breaking your word is remembered.

[b]The country (J)[/b]: send capos with men and guns to take Chicago, Detroit, Atlantic City and more. Buy the officials along a smuggling route, run convoys, ambush rival convoys, order hits.
[b]Supply[/b] (Tab, SUPPLY): convoys unload into your [b]warehouse[/b] in a city (or get dumped at half price). In New York buy a warehouse on the West St. quay: park the truck at its door and press E to load it, or put a man on the [b]booze run[/b]. Pay the longshoremen's local (the hiring boss on the quay), buy breweries and stills, bribe yardmasters, ship crates by rail.
[b]Guns[/b] from Izzy outside the pawnshop. [b]Evidence[/b] (Tab, THE CASE): pay or scare witnesses, dump the gun in the river, burn the books.

[b]Keys[/b]: J country · WASD move · Shift sprint · Alt walk · E talk/use · F punch · G pistol (very loud) · R sic your crew · Q drop crate · V truck · Z/C turn camera · scroll zoom · Tab family · M map · N newspaper · Esc menu"""
	v.add_child(r)
	var ok := Button.new()
	ok.text = "GOT IT  (H to open this again)"
	ok.pressed.connect(toggle_help)
	v.add_child(ok)


func _build_menu(root: Control) -> void:
	_menu = _panel(root, Vector2(420, 330))
	_menu.visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_menu.add_child(v)
	v.add_child(_label("Paused", 30, INK, serif))
	var items := [["RESUME", func() -> void: escape()], ["HELP", func() -> void:
		escape()
		toggle_help()], ["SAVE CAMPAIGN", func() -> void:
		Net.to_host("save", [])
		escape()], ["QUIT TO MENU", func() -> void:
		if Net.is_host() and Game.running:
			Game.save_campaign()
		Net.leave()
		get_tree().change_scene_to_file("res://scenes/main.tscn")]]
	for it in items:
		var b := Button.new()
		b.text = it[0]
		b.pressed.connect(it[1])
		if it[0] == "SAVE CAMPAIGN" and not Net.is_host():
			b.disabled = true
			b.text = "SAVE (HOST ONLY)"
		v.add_child(b)


# ------------------------------------------------------------------ state

func _me() -> Dictionary:
	return Game.player(Net.my_id())


func _my_family() -> int:
	return int(_me().get("family", -1))


func refresh() -> void:
	if _fam_label == null:
		return
	var p := _me()
	var f := Game.fam(int(p.get("family", -1)))
	if f.is_empty():
		return
	(_crest_bg.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = Color(f["color"])
	_crest.text = String(f["name"]).substr(0, 1)
	_fam_label.text = "%s FAMILY" % String(f["name"]).to_upper()
	_stash.text = "$%s" % _money(int(f["dirty"]))
	_clean.text = "$%s" % _money(int(f["clean"]))
	_wallet.text = "$%s" % _money(int(p.get("wallet", 0)))
	_men.text = str(Game.crew_of(f["id"]).size())
	var ars: Dictionary = f.get("arsenal", {})
	_guns.text = "%d · %d" % [int(ars.get("pistol", 0)) + int(ars.get("tommy", 0)), int(ars.get("ammo", 0))]
	_heat.value = float(f["heat"])
	var fill := _heat.get_theme_stylebox("fill") as StyleBoxFlat
	if fill:
		fill.bg_color = Color("ff4a3a") if f["heat"] > 70 else Color("c4552b")
	var tod := "dawn"
	var c := Game.clock
	if c > 0.08 and c < 0.42: tod = "day"
	elif c < 0.58 and c >= 0.42: tod = "dusk"
	elif c >= 0.58: tod = "night"
	_date.text = "%s · %s" % [Game.date_text(), tod]
	var names := []
	for k in Game.players:
		var pl: Dictionary = Game.players[k]
		names.append(pl["name"])
	_players.text = ("  ".join(names)) if names.size() > 1 else ""
	var pending := Game.deals.filter(func(d: Dictionary) -> bool: return int(d["to"]) == f["id"]).size()
	_deal_badge.text = ("✉ %d SIT-DOWN REQUEST%s (TAB)" % [pending, "" if pending == 1 else "S"]) if pending > 0 else ""
	if _family.visible:
		_fill_family()


func _process(delta: float) -> void:
	refresh_clock()
	if _paper.visible and _modal != "paper":
		_paper_t -= delta
		if _paper_t <= 0.0:
			_paper.visible = false
	var left := jail_until - Time.get_ticks_msec() / 1000.0
	if left > 0.0:
		_jail.text = "In a cell at the 14th Precinct\n%d" % ceili(left)
	elif _jail.text != "":
		_jail.text = ""


var _clock_t := 0.0
func _hide_paper_if_busy() -> void:
	if _paper.visible and _modal not in ["", "paper"]:
		_paper.visible = false


func refresh_clock() -> void:
	_hide_paper_if_busy()
	_clock_t -= get_process_delta_time()
	if _clock_t <= 0.0:
		_clock_t = 0.5
		refresh()


func in_jail() -> bool:
	return jail_until > Time.get_ticks_msec() / 1000.0


func is_modal() -> bool:
	return _modal != ""


func _money(v: int) -> String:
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = "," + s.right(3) + out
		s = s.left(s.length() - 3)
	return ("-" if v < 0 else "") + s + out


func set_prompt(t: String) -> void:
	if _prompt.text != t:
		_prompt.text = t


func toast(text: String, kind: String = "info") -> void:
	if text == "":
		return
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.05, 0.04, 0.92)
	sb.border_color = {"bad": Color("a3201b"), "good": Color("3d6b2f"), "warn": Color("c4552b"), "deal": Color("3c6ec8")}.get(kind, LINE)
	sb.border_width_left = 4
	sb.set_content_margin_all(10)
	p.add_theme_stylebox_override("panel", sb)
	var l := _label(text, 17, INK, sans)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(420, 0)
	p.add_child(l)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.add_child(p)
	_toasts.move_child(p, 0)
	while _toasts.get_child_count() > 6:
		var old := _toasts.get_child(_toasts.get_child_count() - 1)
		_toasts.remove_child(old)
		old.queue_free()
	var tw := create_tween()
	tw.tween_interval(6.0)
	tw.tween_property(p, "modulate:a", 0.0, 1.0)
	tw.tween_callback(p.queue_free)
	if world and world.audio:
		world.audio.ui({"bad": "hh_hurt", "good": "coins_pay", "deal": "paper_open"}.get(kind, "tick"), -10.0)


# ------------------------------------------------------------------ modal handling

func escape() -> void:
	match _modal:
		"":
			_menu.visible = true
			_modal = "menu"
		"menu":
			_menu.visible = false
			_modal = ""
		"dialog":
			close_dialog()
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
		"arrest":
			pass
		"final":
			pass


func modal_key(k: int) -> void:
	if _modal == "dialog" or _modal == "arrest":
		var n := k - KEY_1
		if n >= 0 and n < _dlg_actions.size():
			_choose(n)
	elif _modal == "family" and k == KEY_TAB:
		toggle_family()
	elif _modal == "map" and k == KEY_M:
		toggle_map()
	elif _modal == "nation" and k == KEY_J:
		toggle_nation()
	elif _modal == "help" and (k == KEY_H or k == KEY_F1 or k == KEY_ENTER or k == KEY_SPACE):
		toggle_help()
	elif _modal == "paper" and k in [KEY_N, KEY_SPACE, KEY_ENTER]:
		_paper.visible = false
		_modal = ""


func toggle_family() -> void:
	if _modal not in ["", "family"]:
		return
	_family.visible = not _family.visible
	_modal = "family" if _family.visible else ""
	if _family.visible:
		_fill_family()


func toggle_map() -> void:
	if _modal not in ["", "map"]:
		return
	_map.visible = not _map.visible
	_modal = "map" if _map.visible else ""
	_map.queue_redraw()


func toggle_nation() -> void:
	if _modal not in ["", "nation"]:
		return
	_nation.visible = not _nation.visible
	_modal = "nation" if _nation.visible else ""
	if _nation.visible:
		_nation.open()


func toggle_help() -> void:
	if _modal not in ["", "help"]:
		return
	_help.visible = not _help.visible
	_modal = "help" if _help.visible else ""


# ------------------------------------------------------------------ the talk panel

func _open(title: String, body: String, options: Array, modal: String = "dialog") -> void:
	_dlg_title.text = title
	_dlg_body.text = body
	for c in _dlg_opts.get_children():
		c.queue_free()
	_dlg_actions.clear()
	var n := 1
	for o in options:
		var b := Button.new()
		b.text = "%d   %s" % [n, o[0]]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = o.size() > 2 and o[2] == false
		var idx := _dlg_actions.size()
		b.pressed.connect(func() -> void: _choose(idx))
		_dlg_opts.add_child(b)
		_dlg_actions.append(o[1])
		n += 1
	_dialog.visible = true
	_modal = modal
	_place_dialog()
	_place_dialog.call_deferred()
	if world and world.audio:
		world.audio.ui("paper_open", -12.0)


## Centred above the prompt. (`position` is relative to the parent's top-left, not to the
## bottom-centre anchor, so it's computed from the screen size.)
func _place_dialog() -> void:
	_dialog.reset_size()
	var area := _dialog.get_parent_area_size()
	_dialog.position = Vector2((area.x - _dialog.size.x) * 0.5, maxf(70.0, area.y - _dialog.size.y - 130.0))


func _choose(i: int) -> void:
	var act: Callable = _dlg_actions[i]
	var keep_open := false
	if act.is_valid():
		var r = act.call()
		keep_open = r == true
	if not keep_open:
		close_dialog()


func close_dialog() -> void:
	_dialog.visible = false
	if _modal in ["dialog", "arrest"]:
		_modal = ""


func _act(what: String, target: int, extra: Variant = 0) -> Callable:
	return func() -> void: Net.to_host("act", [what, target, extra])


func open_dialog(focus: Dictionary) -> void:
	match focus["type"]:
		"biz": _biz_dialog(Game.biz_by_id(int(focus["id"])))
		"actor": _actor_dialog(focus)


func _biz_dialog(b: Dictionary) -> void:
	if b.is_empty():
		return
	var me := _my_family()
	var f := Game.fam(me)
	var p := _me()
	var opts := []
	var body := ""
	var who := "[color=#9b907c]%s · %s[/color]" % [b.get("address", ""), b["district"]]
	if b["kind"] == "precinct":
		body = "The desk sergeant looks you over. \"The Captain might see you. For the right reasons.\"\n"
		for d in CityPlan.DISTRICTS:
			var cur: int = Game.captains.get(d, -1)
			var owner := " (yours)" if cur == me else (" (the %s family pays)" % Game.fam(cur)["name"] if cur >= 0 else "")
			opts.append(["Put the captain for %s on the payroll ($%d, then $%d/mo)%s" % [d, Game.CAPTAIN_FEE + (400 if cur >= 0 and cur != me else 0), Game.CAPTAIN_WAGE, owner], _act("captain", b["id"], d), cur != me])
		opts.append(["Leave", Callable()])
		_open("14th Precinct", body, opts)
		return
	if b["kind"] == "club" and int(b["hq_of"]) == me:
		body = "Your club. Espresso, cards, and the stash under the floor.\n[b]Stash:[/b] $%s dirty · [b]On you:[/b] $%s · [b]Clean:[/b] $%s\n[b]Laundering:[/b] $%s a month through your fronts." % [
			_money(int(f["dirty"])), _money(int(p["wallet"])), _money(int(f["clean"])), _money(Game.laundering_capacity(me))]
		opts.append(["Put $%s in the stash" % _money(int(p["wallet"])), _act("bank_in", b["id"]), int(p["wallet"]) > 0])
		opts.append(["Take $500 from the stash", _act("bank_out", b["id"]), int(f["dirty"]) > 0])
		var books := (f["evidence"] as Array).filter(func(e: Dictionary) -> bool: return e["kind"] == "ledger")
		if not books.is_empty():
			opts.append(["Burn the books (the feds want them; $300 clean to rebuild)", func() -> void: Net.to_host("burn_books", []), int(f["clean"]) >= 300])
		if int(f.get("cellar", 0)) > 0:
			body += "\n[b]In the cellar:[/b] %d crates waiting for a speakeasy." % int(f["cellar"])
		opts.append(["The country: cities, routes, capos (J)", func() -> void:
			close_dialog()
			toggle_nation()])
		opts.append(["Open the family books (Tab)", func() -> void:
			close_dialog()
			toggle_family()])
		if Net.is_host():
			opts.append(["Save the campaign", func() -> void: Net.to_host("save", [])])
		opts.append(["Leave", Callable()])
		_open(b["name"], body, opts)
		return
	if b["kind"] == "club" and int(b["hq_of"]) >= 0:
		_sitdown(int(b["hq_of"]))
		return
	if b["kind"] == "warehouse":
		_warehouse_dialog(b)
		return
	body = "%s · owner [b]%s[/b]\n" % [who, b["owner_name"]]
	var prot: int = b["protector"]
	var own: int = b["owned_by"]
	if own >= 0:
		body += "Owned by the [b]%s[/b] family." % Game.fam(own)["name"]
	elif prot >= 0:
		body += "Pays the [b]%s[/b] family $%d a month." % [Game.fam(prot)["name"], b["rate"]]
	else:
		body += "Pays nobody. Worth $%d a month to somebody." % b["rate"]
	var mood := "calm"
	if b["fear"] > 55: mood = "terrified"
	elif b["fear"] > 25: mood = "nervous"
	elif b["defiance"] > 60: mood = "defiant"
	body += "\nHe looks [b]%s[/b]." % mood
	if int(b["closed_until"]) >= Game.month:
		body += "\n[color=#ff6b5b]Closed: padlocked by the feds.[/color]"
	var carrying: bool = world.local_actor and world.local_actor.carrying
	for e in f["evidence"]:
		if e["kind"] == "witness" and int(e.get("biz", -1)) == int(b["id"]):
			body += "\n[color=#ff8a7a]He saw something: %s.[/color]" % e["text"]
			var eid: int = e["id"]
			var price := 100 + int(float(e["w"]) * 12.0)
			opts.append(["Pay him to forget what he saw ($%d)" % price, func() -> void: Net.to_host("silence", [eid, false]), int(p["wallet"]) >= price])
			opts.append(["Remind him what happens to people who talk", func() -> void: Net.to_host("silence", [eid, true])])
	if own == me:
		body += "\nLaunders $%d a month. Legit profit $%d." % [b["launder"], b["legit"]]
		if b["speak"]:
			body += "\n[b]Speakeasy in the back:[/b] %d crates in the cellar, sells about %d a month." % [b["stock"], b["demand"]]
			var truck_near := false
			for v in world.vehicles.values():
				if (v as Vehicle).family == me and (v as Vehicle).load > 0 and (v as Vehicle).position.distance_to(Vector3(b["door"][0], 0, b["door"][1])) < 9.0:
					truck_near = true
			opts.append(["Unload the booze into the cellar", _act("deliver", b["id"]), carrying or truck_near])
		elif b["kind"] not in ["warehouse"]:
			opts.append(["Fit out a speakeasy in the back room ($%d cash)" % Game.SPEAKEASY_COST, _act("speakeasy", b["id"])])
	elif prot == me:
		var env: int = b["envelope"]
		var unpaid: int = b["unpaid"]
		opts.append(["Collect the envelope ($%d)" % env if unpaid == 0 else "He owes you. Collect", _act("collect", b["id"]), env > 0 or unpaid > 0])
		if unpaid > 0:
			opts.append(["Remind him who he pays (smash the window)", _act("lean", b["id"])])
		opts.append(["Buy the business ($%s clean)" % _money(int(b["value"])), _act("buy", b["id"]), int(f["clean"]) >= int(b["value"])])
	else:
		var label := "Offer protection ($%d a month)" % b["rate"] if prot < 0 else "Tell him he pays you now, not the %s family" % Game.fam(prot)["name"]
		if Game.has_truce(me, prot):
			label += "  (breaks your truce!)"
		opts.append([label, _act("pitch", b["id"])])
		opts.append(["Lean on him (smash the window)" + ("  (breaks your truce!)" if Game.has_truce(me, prot) else ""), _act("lean", b["id"])])
		if prot >= 0 and b["envelope"] > 0:
			opts.append(["Take the %s family's envelope ($%d)" % [Game.fam(prot)["name"], b["envelope"]], _act("collect", b["id"])])
		if own < 0:
			var price := int(b["value"] * 1.25)
			opts.append(["Buy the business ($%s clean)" % _money(price), _act("buy", b["id"]), int(f["clean"]) >= price])
	opts.append(["Leave", Callable()])
	_open(b["name"], body, opts)


func _actor_dialog(focus: Dictionary) -> void:
	var me := _my_family()
	var p := _me()
	match focus["kind"]:
		"cop":
			var c := Game.cop_by_id(int(focus["id"]))
			var mine: bool = c.get("payroll", -1) == me
			var body := "%s, %s beat." % [c.get("name", "The officer"), c.get("district", "")]
			if mine:
				body += "\nHe's on your payroll. He touches his cap and looks the other way."
				_open(c["name"], body, [["Leave", Callable()]])
			else:
				if c.get("payroll", -1) >= 0:
					body += "\nWord is he takes money from the %s family." % Game.fam(int(c["payroll"]))["name"]
				body += "\nHe watches your hands."
				_open(c["name"], body, [["Slip him $100 to look the other way ($%d a month after)" % Game.COP_WAGE, _act("cop", int(focus["id"])), int(p["wallet"]) >= 100], ["Leave", Callable()]])
		"recruit":
			for r in Game.recruits:
				if r["id"] == int(focus["id"]):
					var body := "[b]%s[/b], hanging around outside the pool hall.\nTough: %d/100 · wants [b]$%d[/b] up front and $%d a month." % [r["name"], r["tough"], r["price"], r["wage"]]
					_open("Looking for work", body, [["Hire him ($%d)" % r["price"], _act("hire", r["id"]), int(p["wallet"]) >= int(r["price"])], ["Leave", Callable()]])
					return
		"aiboss", "boss":
			var a = world.actor(String(focus["key"]))
			if a:
				_sitdown(a.family)
		"crew":
			var c := Game.crew_by_id(int(focus["id"]))
			var near = _nearest_biz(world.local_actor.position)
			var task := String(c["task"])
			if task == "booze":
				task = "on the booze run (%d crates a month)" % int(c.get("booze", 20))
			var body := "[b]%s[/b] · %s · loyalty %d · tough %d · $%d a month\nNow: %s" % [c["name"], c["rank"], c["loyalty"], c["tough"], c["wage"], task]
			var opts := [["Follow me", _crew(c["id"], "follow", -1)]]
			if not near.is_empty():
				opts.append(["Guard %s" % near["name"], _crew(c["id"], "guard", near["id"])])
				opts.append(["Collect our envelopes in %s" % near["district"], _crew(c["id"], "collect", near["id"])])
			if not Game.nyc_warehouse(me).is_empty() and c["task"] != "booze":
				opts.append(["Run the booze: truck 20 crates a month from our warehouse to the speakeasies", _crew(c["id"], "booze", 20)])
			opts.append(["Go back to the club", _crew(c["id"], "idle", -1)])
			opts.append(["Leave", Callable()])
			_open("Your man", body, opts)
		"dealer":
			var ars: Dictionary = Game.fam(me)["arsenal"]
			var body := "Izzy, outside the pawnshop, never says where anything comes from.\nThe family has %d revolvers, %d Thompsons, %d rounds.\n[color=#9b907c]Every shot fired is evidence until the gun is at the bottom of the river.[/color]" % [int(ars["pistol"]), int(ars["tommy"]), int(ars["ammo"])]
			_open("Izzy the Gun", body, [
				["A .38 revolver ($%d)" % Game.dealer["pistol"], func() -> void: Net.to_host("gun", ["pistol"]), int(p["wallet"]) >= int(Game.dealer["pistol"])],
				["A box of 25 rounds ($%d)" % Game.dealer["ammo"], func() -> void: Net.to_host("gun", ["ammo"]), int(p["wallet"]) >= int(Game.dealer["ammo"])],
				["A Thompson submachine gun ($%d)%s" % [Game.dealer["tommy"], "" if Game.year() >= 1928 else ", not until 1928"], func() -> void: Net.to_host("gun", ["tommy"]), int(p["wallet"]) >= int(Game.dealer["tommy"])],
				["Leave", Callable()]])
		"unionboss":
			_union_dialog()
		"smuggler":
			var left := int(Game.boat.get("crates", 0))
			var body := "\"Canadian whisky, straight off the boat. $%d a crate, cash. %d left tonight.\"\nCrates go on the pier. You carry them, the truck waits on the quay." % [Game.CRATE_COST, left]
			_open("The man from the boat", body, [
				["Buy 1 crate ($%d)" % Game.CRATE_COST, _act("crates", 0, 1), int(p["wallet"]) >= Game.CRATE_COST and left > 0],
				["Buy 5 crates ($%d)" % (Game.CRATE_COST * 5), _act("crates", 0, 5), int(p["wallet"]) >= Game.CRATE_COST * 5 and left >= 5],
				["Buy 10 crates ($%d)" % (Game.CRATE_COST * 10), _act("crates", 0, 10), int(p["wallet"]) >= Game.CRATE_COST * 10 and left >= 10],
				["Leave", Callable()]])


## The warehouses on the West St. quay: yours (stock, the truck, the booze run), a rival's, or for sale.
func _warehouse_dialog(b: Dictionary) -> void:
	var me := _my_family()
	var f := Game.fam(me)
	var own := int(b["owned_by"])
	var door := Vector3(b["door"][0], 0, b["door"][1])
	var carrying: bool = world.local_actor != null and world.local_actor.carrying
	var opts := []
	var body := "[color=#9b907c]%s · the Waterfront[/color]\n" % b.get("address", "West St.")
	if own == me:
		var have := Syndicate.stock(Game.nation, "nyc", me)
		body += "[b]Your warehouse.[/b] %d crates on the pallets (it holds %d).\nConvoys landing in New York unload here. Your speakeasies sell what you bring them: park the truck at the door and load it, or put a man on the booze run." % [have, Syndicate.WAREHOUSE_CAP]
		var truck: Vehicle = world.parked_truck(me, door, 9.0)
		if truck:
			body += "\nThe truck is at the door with %d crates in the back." % truck.load
		else:
			body += "\n[color=#9b907c]The truck isn't here. Park it at the door to load it.[/color]"
		var runners := Game.crew.filter(func(c: Dictionary) -> bool: return c["family"] == me and c["state"] == "free" and c["task"] == "booze")
		for c in runners:
			body += "\n%s is on the booze run: %d crates a month to your speakeasies." % [c["name"], int(c.get("booze", 20))]
		opts.append(["Load the truck (up to %d crates)" % Vehicle.MAX_LOAD, _act("wh_load", b["id"]), truck != null and truck.load < Vehicle.MAX_LOAD and have > 0])
		opts.append(["Stack the truck's crates in the warehouse", _act("wh_store", b["id"]), carrying or (truck != null and truck.load > 0)])
		var free := Game.crew_of(me).filter(func(c: Dictionary) -> bool: return c["task"] != "booze")
		if not free.is_empty():
			var c0: Dictionary = free[0]
			opts.append(["Put %s on the booze run (20 crates a month)" % c0["name"], _crew(c0["id"], "booze", 20)])
		for c in runners:
			opts.append(["Take %s off the booze run" % c["name"], _crew(c["id"], "idle", -1)])
		opts.append(["The supply ledger (Tab)", func() -> void:
			close_dialog()
			_fam_tab = "supply"
			toggle_family()])
	elif own >= 0:
		var n := Syndicate.stock(Game.nation, "nyc", own)
		body += "The [b]%s[/b] family's warehouse. A watchman on an upturned crate, %d crates on the pallets by the door." % [Game.fam(own)["name"], n]
		opts.append(["Help yourself to a crate (the watchman will talk)", _act("wh_steal", b["id"]), n > 0 and not carrying])
	else:
		var price := int(b["value"] * (1.0 if int(b["protector"]) == me else 1.25))
		body += "Empty bays, a freight elevator and a watchman who sleeps. %s wants out of the lease.\nBuy it and it's your family's warehouse on the quay: convoys landing in New York fill it (it holds %d crates), and you truck them to your speakeasies." % [String(b["owner_name"]).capitalize(), Syndicate.WAREHOUSE_CAP]
		if Syndicate.has_wh(Game.nation, "nyc", me):
			body += "\n[color=#9b907c]You already have a warehouse on the quay; this would be a second building.[/color]"
		opts.append(["Buy the warehouse ($%s clean)" % _money(price), _act("buy", b["id"]), int(f["clean"]) >= price])
		var prot := int(b["protector"])
		if prot != me:
			opts.append(["Offer the watchman protection ($%d a month)" % b["rate"] if prot < 0 else "Tell the watchman he pays you now, not the %s family" % Game.fam(prot)["name"], _act("pitch", b["id"])])
	opts.append(["Leave", Callable()])
	_open(b["name"], body, opts)


## Red Mulrooney, hiring boss of the longshoremen's local on the West St. piers.
func _union_dialog() -> void:
	var me := _my_family()
	var f := Game.fam(me)
	var n: Dictionary = Game.nation
	var cur := int(n["cities"]["nyc"]["docks"])
	var price := Syndicate.union_price(n, "nyc", me)
	var wage := Syndicate.union_wage("nyc")
	var body := "[b]%s[/b], hiring boss of Longshoremen's Local %s. Every morning at seven he picks who works the West St. piers, and whose cargo comes off the boats first.\n" % [Game.UNION_BOSS, Game.UNION_LOCAL]
	if cur == me:
		body += "The local is on your payroll ($%d a month): your boats unload fast, the inspectors look at the sky, and other families' boats wait their turn, or turn back." % wage
	elif cur >= 0:
		body += "\"The %s family looks after the local. You want to look after us better, that's a conversation.\"" % Game.fam(cur)["name"]
	else:
		body += "\"Nobody looks after the local. That's a shame, for a man with boats coming in.\""
	body += "\n[color=#9b907c]Boats landing at docks you own carry half again as much at half the risk.[/color]"
	var opts := []
	if cur != me:
		opts.append(["Put the local on the payroll ($%s from the stash, then $%d a month)" % [_money(price), wage], _act("union_pay", 0), int(f["dirty"]) >= price])
	var rp := Syndicate.river_price(n, "nyc", me)
	for o in Game.families:
		if o["id"] == me or not o["alive"]:
			continue
		var pending: bool = n["sabotage"].has(str(o["id"]))
		opts.append(["Have the %s family's next shipment \"dropped in the river\" ($%s)%s" % [o["name"], _money(rp), "  (already arranged)" if pending else ""],
			_act("union_drop", o["id"]), int(f["dirty"]) >= rp and not pending])
	opts.append(["Leave", Callable()])
	_open("The shape-up, West St.", body, opts)


func _crew(id: int, task: String, target: int) -> Callable:
	return func() -> void: Net.to_host("crew_task", [id, task, target])


func _nearest_biz(p: Vector3) -> Dictionary:
	var best := {}
	var bd := 12.0
	for b in Game.biz:
		var d := Vector3(b["door"][0], 0, b["door"][1]).distance_to(p)
		if d < bd:
			bd = d
			best = b
	return best


func _sitdown(other: int) -> void:
	var me := _my_family()
	var o := Game.fam(other)
	var r := Game.rel(me, other)
	var body := "[b]Don %s[/b] (%s) · %s\n" % [o["name"], "AI family" if o["ai"] else _player_of(other), "at war with you" if r["war"] else ("truce until %s" % Game.date_text(int(r["truce_until"])) if Game.has_truce(me, other) else "no agreement")]
	body += "Word on him: deals kept %d, broken %d. Men: %d." % [o["kept"], o["broken"], Game.crew_of(other).size()]
	var opts := [
		["Propose a truce for 6 months", _deal(other, {"kind": "truce", "months": 6, "amount": 0})],
		["Offer $500 for a year of peace", _deal(other, {"kind": "truce", "months": 12, "amount": 500}), int(Game.fam(me)["dirty"]) >= 500],
		["Demand $500 tribute, or else", _deal(other, {"kind": "tribute", "months": 6, "amount": -500})],
	]
	for f in Game.families:
		if f["id"] != me and f["id"] != other and f["alive"]:
			opts.append(["Propose an alliance against the %s family" % f["name"], _deal(other, {"kind": "alliance", "months": 12, "amount": 0, "against": f["id"]})])
	opts.append(["Leave", Callable()])
	_open("Sit-down: the %s family" % o["name"], body, opts)


func _player_of(family: int) -> String:
	for k in Game.players:
		if int(Game.players[k]["family"]) == family:
			return String(Game.players[k]["name"])
	return "?"


func _deal(to: int, terms: Dictionary) -> Callable:
	return func() -> void: Net.to_host("propose", [to, terms])


func open_truck(v: Vehicle) -> void:
	_open("The %s truck" % Game.fam(v.family).get("name", ""), "%d crates in the back." % v.load, [
		["Take a crate out", func() -> void: Net.to_host("truck_unload", [v.key])],
		["Drive (V)", func() -> void: Net.to_host("enter", [v.key])],
		["Leave", Callable()]])


func show_arrest(cop_key: String, price: int) -> void:
	if _modal != "":
		_family.visible = false
		_map.visible = false
		_dialog.visible = false
		_menu.visible = false
		_help.visible = false
		_modal = ""
	var p := _me()
	_open("\"You're coming with me.\"", "The officer has you by the collar. Witnesses are watching.\nHe could be persuaded for [b]$%d[/b]. You have $%d on you." % [price, int(p.get("wallet", 0))], [
		["Slip him $%d" % price, func() -> void: Net.to_host("arrest", ["bribe"]), int(p.get("wallet", 0)) >= price],
		["Go quietly (a night in a cell, lose what's on you)", func() -> void: Net.to_host("arrest", ["quiet"])],
		["Shove him and run (more heat)", func() -> void: Net.to_host("arrest", ["run"])]], "arrest")
	if world and world.audio:
		world.audio.ui("whistle", -4.0)


# ------------------------------------------------------------------ the family books

func _fill_family() -> void:
	for c in _fam_body.get_children():
		c.queue_free()
	var me := _my_family()
	var f := Game.fam(me)
	if f.is_empty():
		return
	match _fam_tab:
		"crew":
			_fam_body.add_child(_label("The %s family · %s" % [f["name"], Game.date_text()], 28, INK, serif))
			for c in Game.crew.filter(func(x: Dictionary) -> bool: return x["family"] == me and x["state"] in ["free", "jailed"]):
				var row := HBoxContainer.new()
				row.add_theme_constant_override("separation", 10)
				var task := "booze run, %d/mo" % int(c.get("booze", 20)) if c["task"] == "booze" else String(c["task"])
				var info := _label("%s · %s · loyalty %d · $%d/mo · %s" % [c["name"], c["rank"], c["loyalty"], c["wage"],
					"in prison until %s" % Game.date_text(int(c["jail_until"])) if c["state"] == "jailed" else task], 18,
					RED if c["loyalty"] < 40 or c["state"] == "jailed" else INK, sans)
				info.custom_minimum_size = Vector2(560, 0)
				row.add_child(info)
				if c["state"] == "free":
					for t in [["FOLLOW", "follow"], ["CLUB", "idle"]]:
						var b := Button.new()
						b.text = t[0]
						b.pressed.connect(_crew(c["id"], t[1], -1))
						row.add_child(b)
					var near = _nearest_biz(world.local_actor.position) if world.local_actor else {}
					if not near.is_empty():
						var b2 := Button.new()
						b2.text = "COLLECT HERE"
						b2.pressed.connect(_crew(c["id"], "collect", near["id"]))
						row.add_child(b2)
					if not Game.nyc_warehouse(me).is_empty() and c["task"] != "booze":
						var b3 := Button.new()
						b3.text = "BOOZE RUN"
						b3.tooltip_text = "Truck 20 crates a month from your warehouse on the quay to your speakeasies"
						b3.pressed.connect(_crew(c["id"], "booze", 20))
						row.add_child(b3)
				_fam_body.add_child(row)
			if Game.crew_of(me).is_empty():
				_fam_body.add_child(_label("No men. Hire muscle outside the pool halls.", 18, MUTE))
			var t1 := CheckButton.new()
			t1.text = "Support the families of men in prison ($%d a month each)" % Game.JAIL_SUPPORT
			t1.button_pressed = f["support_jailed"]
			t1.toggled.connect(func(_on: bool) -> void: Net.to_host("toggle", ["support_jailed"]))
			_fam_body.add_child(t1)
		"biz":
			_fam_body.add_child(_label("Who pays you", 28, INK, serif))
			var shops := Game.shops_of(me)
			for b in shops:
				var tag := "OWNED" if b["owned_by"] == me else "PAYS $%d" % b["rate"]
				if b["speak"]:
					tag += " · SPEAKEASY %d crates" % b["stock"]
				if b["envelope"] > 0:
					tag += " · envelope $%d waiting" % b["envelope"]
				if b["unpaid"] > 0:
					tag += " · NOT PAYING"
				_fam_body.add_child(_label("%s · %s · %s" % [b["name"], b["district"], tag], 18, INK, sans))
			if shops.is_empty():
				_fam_body.add_child(_label("Nobody yet. Walk up to a shop door and press E.", 18, MUTE))
			var cops := Game.cops.filter(func(c: Dictionary) -> bool: return c["payroll"] == me)
			_fam_body.add_child(_label("On the payroll: %d patrolmen%s" % [cops.size(),
				", captains in " + ", ".join(Game.captains.keys().filter(func(d) -> bool: return Game.captains[d] == me)) if Game.captains.values().has(me) else ""], 18, MUTE))
		"supply":
			_fill_supply(f, me)
		"case":
			_fam_body.add_child(_label("What the Bureau has on the %s family · heat %d" % [f["name"], int(f["heat"])], 28, INK, serif))
			_fam_body.add_child(_label("At 100 the feds raid you. Everything here fades with time, unless you make it disappear first.", 17, MUTE, sans))
			var how := {"witness": "Visit him (E at his shop): pay or scare him.", "street": "Street talk. It fades fast; a precinct captain on the payroll makes it fade faster.",
				"cop": "Put that patrolman on the payroll and his notebook disappears.", "weapon": "Throw the gun in the river at the end of a pier.",
				"ledger": "Burn the books at your club.", "body": "", "informant": "", "file": "A brewery or still you run. Buying the city's police slows the raids; it fades once the plant is gone."}
			var items: Array = (f["evidence"] as Array).duplicate()
			items.sort_custom(func(a, b) -> bool: return float(a["w"]) > float(b["w"]))
			for e in items:
				var row := HBoxContainer.new()
				row.add_theme_constant_override("separation", 10)
				var l := _label("%s  ·  %s  (%d)" % [String(e["kind"]).to_upper(), e["text"], int(round(float(e["w"])))], 18,
					RED if float(e["w"]) > 15.0 else INK, sans)
				l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				l.custom_minimum_size = Vector2(600, 0)
				row.add_child(l)
				var eid: int = e["id"]
				match e["kind"]:
					"body":
						var b := Button.new()
						b.text = "CLEANUP CREW $400"
						b.pressed.connect(func() -> void: Net.to_host("cleanup", [eid]))
						row.add_child(b)
					"informant":
						var b2 := Button.new()
						b2.text = "REACH HIM $2,000"
						b2.pressed.connect(func() -> void: Net.to_host("reach", [eid]))
						row.add_child(b2)
					_:
						var hint := _label(how.get(e["kind"], ""), 15, MUTE, sans)
						hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
						hint.custom_minimum_size = Vector2(290, 0)
						row.add_child(hint)
				_fam_body.add_child(row)
			if items.is_empty():
				_fam_body.add_child(_label("Nothing. As far as the Bureau knows, you sell bread.", 18, MUTE))
		"deals":
			_fam_body.add_child(_label("Sit-downs", 28, INK, serif))
			var mine := Game.deals.filter(func(d: Dictionary) -> bool: return int(d["to"]) == me)
			for d in mine:
				var t: Dictionary = d["terms"]
				var from := Game.fam(int(d["from"]))
				var what := ""
				match t.get("kind", "truce"):
					"truce": what = "a truce for %d months" % int(t.get("months", 6))
					"tribute": what = "a truce for %d months" % int(t.get("months", 6))
					"alliance": what = "an alliance against the %s family" % Game.fam(int(t.get("against", -1))).get("name", "?")
				var amt := int(t.get("amount", 0))
				if amt > 0:
					what += ", and they pay you $%d" % amt
				elif amt < 0:
					what += ", if you pay them $%d" % -amt
				var row := HBoxContainer.new()
				var l := _label("The %s family offers %s." % [from["name"], what], 18, INK, sans)
				l.custom_minimum_size = Vector2(640, 0)
				l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				row.add_child(l)
				var did: int = d["id"]
				var yes := Button.new()
				yes.text = "SHAKE HANDS"
				yes.pressed.connect(func() -> void: Net.to_host("respond", [did, true]))
				var no := Button.new()
				no.text = "REFUSE"
				no.pressed.connect(func() -> void: Net.to_host("respond", [did, false]))
				row.add_child(yes)
				row.add_child(no)
				_fam_body.add_child(row)
			if mine.is_empty():
				_fam_body.add_child(_label("No offers on the table. Walk up to a rival's boss or club to propose one.", 18, MUTE))
			_fam_body.add_child(_label("The other families", 28, INK, serif))
			for o in Game.families:
				if o["id"] == me:
					continue
				var r := Game.rel(me, o["id"])
				var st := "WAR" if r["war"] else ("TRUCE until %s" % Game.date_text(int(r["truce_until"])) if Game.has_truce(me, o["id"]) else "no agreement")
				_fam_body.add_child(_label("%s (%s) · %s · men %d · shops %d · kept %d / broke %d" % [o["name"], "AI" if o["ai"] else _player_of(o["id"]), st,
					Game.crew_of(o["id"]).size(), Game.shops_of(o["id"]).size(), o["kept"], o["broken"]], 18, Color(o["color"]).lightened(0.3), sans))
		"books":
			_fam_body.add_child(_label("The books · last month", 28, INK, serif))
			var inc: Dictionary = f.get("income", {})
			for k in [["protection", "Protection money (after the collector's cut)"], ["speakeasy", "Speakeasy sales"], ["wholesale", "Wholesale: warehouses and dumped crates"],
					["legit", "Legitimate profit (clean)"], ["laundered", "Laundered through fronts"], ["wages", "Wages paid"], ["payroll", "Cops and captains"],
					["support", "Families of men inside"], ["convoys", "Convoys (paid at the source)"], ["supply", "The union, brewing and freight"]]:
				_fam_body.add_child(_label("%s: $%s" % [k[1], _money(int(inc.get(k[0], 0)))], 19, INK, sans))
			_fam_body.add_child(_label("Laundering capacity: $%s a month · Heat %d · Reputation %d" % [_money(Game.laundering_capacity(me)), int(f["heat"]), int(f["rep"])], 19, MUTE, sans))
			var t2 := CheckButton.new()
			t2.text = "Launder dirty money through our fronts every month (15% fee)"
			t2.button_pressed = f["launder_on"]
			t2.toggled.connect(func(_on: bool) -> void: Net.to_host("toggle", ["launder_on"]))
			_fam_body.add_child(t2)
			_fam_body.add_child(_label("Legacy (the score at the end): %s" % _money(Game.legacy(me)), 22, GOLD2, cond))
			var ranks := Game.families.duplicate()
			ranks.sort_custom(func(a, b) -> bool: return Game.legacy(a["id"]) > Game.legacy(b["id"]))
			for o in ranks:
				_fam_body.add_child(_label("%s  %s" % [o["name"], _money(Game.legacy(o["id"]))], 18, Color(o["color"]).lightened(0.3), sans))


# ------------------------------------------------------------------ the supply ledger

func _nbtn(parent: Control, text: String, args: Array, enabled: bool = true, tip: String = "") -> void:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.tooltip_text = tip
	b.pressed.connect(func() -> void: Net.to_host("nation", args))
	parent.add_child(b)


func _owner_txt(id: int, me: int) -> String:
	if id < 0:
		return "nobody"
	if id == me:
		return "YOURS"
	return "the %s family" % Game.fam(id).get("name", "?")


func _fill_supply(f: Dictionary, me: int) -> void:
	var n: Dictionary = Game.nation
	var clean := int(f["clean"])
	var dirty := int(f["dirty"])
	_fam_body.add_child(_label("Supply · docks, warehouses, breweries, freight", 28, INK, serif))
	var intro := _label("Crates landing in a city go into your warehouse there and sell over the months at $%d, up to your share of the city's thirst. Without a warehouse they're dumped at half price. Freight moves crates by rail between your own warehouses." % int(Syndicate.wholesale(Game)), 16, MUTE, sans)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.custom_minimum_size = Vector2(900, 0)
	_fam_body.add_child(intro)
	# New York, in person
	var wh := Game.nyc_warehouse(me)
	var nyc: Dictionary = n["cities"]["nyc"]
	var t := "NEW YORK  ·  "
	if wh.is_empty():
		t += "no warehouse: buy one of the two on the West St. quay (E at the door)"
	else:
		var speaks := Game.owned_by(me).filter(func(b: Dictionary) -> bool: return b["speak"])
		var in_cellars := 0
		for b in speaks:
			in_cellars += int(b["stock"])
		var runners := Game.crew.filter(func(c: Dictionary) -> bool: return c["family"] == me and c["state"] == "free" and c["task"] == "booze")
		t += "%s, %s: %d crates · %d speakeasy cellar%s hold %d · booze run: %s" % [wh["name"], wh.get("address", "West St."), Syndicate.stock(n, "nyc", me),
			speaks.size(), "" if speaks.size() == 1 else "s", in_cellars, ", ".join(runners.map(func(c: Dictionary) -> String: return "%s %d/mo" % [c["name"], int(c.get("booze", 20))])) if not runners.is_empty() else "nobody"]
	var nl := _label(t, 18, GOLD2, cond)
	nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nl.custom_minimum_size = Vector2(900, 0)
	_fam_body.add_child(nl)
	var nrow := HFlowContainer.new()
	nrow.add_theme_constant_override("h_separation", 6)
	nrow.add_child(_label("Docks (the West St. local): %s%s   " % [_owner_txt(int(nyc["docks"]), me), "" if int(nyc["docks"]) == me else ", see %s on the quay" % Game.UNION_BOSS], 16, INK, sans))
	_site_buttons(nrow, "nyc", me, clean, dirty)
	_fam_body.add_child(nrow)
	if not wh.is_empty():
		var free := Game.crew_of(me).filter(func(c: Dictionary) -> bool: return c["task"] != "booze")
		var brow := HFlowContainer.new()
		brow.add_theme_constant_override("h_separation", 6)
		for c in Game.crew.filter(func(x: Dictionary) -> bool: return x["family"] == me and x["state"] == "free" and x["task"] == "booze"):
			brow.add_child(_label("%s: " % c["name"], 16, INK, sans))
			for amt in [10, 20, 40]:
				var bb := Button.new()
				bb.text = "%d/MO" % amt
				bb.disabled = int(c.get("booze", 20)) == amt
				bb.pressed.connect(_crew(c["id"], "booze", amt))
				brow.add_child(bb)
			var off := Button.new()
			off.text = "OFF THE RUN"
			off.pressed.connect(_crew(c["id"], "idle", -1))
			brow.add_child(off)
		if not free.is_empty():
			var add := Button.new()
			add.text = "PUT %s ON THE BOOZE RUN" % String(free[0]["name"]).to_upper()
			add.pressed.connect(_crew(free[0]["id"], "booze", 20))
			brow.add_child(add)
		_fam_body.add_child(brow)
	# the other cities
	_fam_body.add_child(_label("The other cities", 24, INK, serif))
	for c in Syndicate.CITIES:
		var id: String = c["id"]
		if id == "nyc":
			continue
		var cs: Dictionary = n["cities"][id]
		var line := "%s · thirst %d a month" % [String(c["name"]).to_upper(), int(c["demand"])]
		if Syndicate.has_wh(n, id, me):
			line += " · WAREHOUSE %d crates, sold %d last month (sells up to %d)" % [Syndicate.stock(n, id, me), int(cs["sold"].get(str(me), 0)), Syndicate.sell_cap(n, id, me)]
		else:
			line += " · no warehouse (you'd sell up to %d a month)" % Syndicate.sell_cap(n, id, me)
		var bits := []
		if String(c["plant"]) != "":
			var closed := "" if int(cs["plant_closed"]) < Game.month else " (padlocked)"
			bits.append("%s: %s%s" % [c["plant"], _owner_txt(int(cs["plant"]), me), closed])
		if String(c["port"]) != "":
			bits.append("docks: %s" % _owner_txt(int(cs["docks"]), me))
		if bool(c["yard"]):
			bits.append("rail yard: %s" % _owner_txt(int(cs["yard"]), me))
		var head := _label(line, 17, INK if Syndicate.has_wh(n, id, me) else MUTE, sans)
		head.custom_minimum_size = Vector2(900, 0)
		head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_fam_body.add_child(head)
		var row := HFlowContainer.new()
		row.add_theme_constant_override("h_separation", 6)
		if not bits.is_empty():
			row.add_child(_label("   " + " · ".join(bits) + "   ", 15, MUTE, sans))
		_site_buttons(row, id, me, clean, dirty)
		_fam_body.add_child(row)
	# freight
	_fam_body.add_child(_label("Freight by rail", 24, INK, serif))
	var mine := (n["freight"] as Array).filter(func(o: Dictionary) -> bool: return int(o["fam"]) == me)
	for o in mine:
		var r := Syndicate.rail_def(o["line"])
		var risk := Syndicate.freight_risk(n, o["line"], me, float(f["heat"]))
		var row2 := HFlowContainer.new()
		row2.add_theme_constant_override("h_separation", 6)
		row2.add_child(_label("%s → %s on the %s: %d crates a month · $%d a crate · %s · last month: %s   " % [Syndicate.cname(o["from"]), Syndicate.cname(o["to"]),
			r.get("name", "?"), int(o["crates"]), Syndicate.freight_cost(o["line"], o["from"], o["to"]), "safe (your yard)" if risk <= 0.0 else "%d%% risk" % int(risk * 100),
			o["last"] if String(o["last"]) != "" else "not yet"], 16, INK, sans))
		_nbtn(row2, "+10", ["freight", o["line"], o["from"], o["to"], int(o["crates"]) + 10])
		_nbtn(row2, "-10", ["freight", o["line"], o["from"], o["to"], maxi(0, int(o["crates"]) - 10)])
		_nbtn(row2, "STOP", ["freight", o["line"], o["from"], o["to"], 0])
		_fam_body.add_child(row2)
	var whs := Syndicate.warehouses_of(n, me)
	var offers := HFlowContainer.new()
	offers.add_theme_constant_override("h_separation", 6)
	for r in Syndicate.RAILS:
		for a in whs:
			for b in whs:
				if a == b or a not in r["stops"] or b not in r["stops"]:
					continue
				if mine.any(func(o: Dictionary) -> bool: return o["line"] == r["id"] and o["from"] == a and o["to"] == b):
					continue
				_nbtn(offers, "SHIP 20/MO %s → %s" % [Syndicate.cname(a).to_upper(), Syndicate.cname(b).to_upper()], ["freight", r["id"], a, b, 20], true,
					"%s, $%d a crate" % [r["name"], Syndicate.freight_cost(r["id"], a, b)])
	if offers.get_child_count() > 0:
		_fam_body.add_child(offers)
	elif mine.is_empty():
		_fam_body.add_child(_label("Freight runs between two of your warehouses on the same line (New York Central, Pennsylvania, Illinois Central...). Buy a second warehouse.", 16, MUTE, sans))
	# what happened last month
	var log: Array = n.get("supply", {}).get(str(me), [])
	if not log.is_empty():
		_fam_body.add_child(_label("Last month", 24, INK, serif))
		for l in log.slice(0, 14):
			_fam_body.add_child(_label("·  " + String(l), 16, INK, sans))


## Buttons to take a city's sites: warehouse, brewery/still, union, yard.
func _site_buttons(row: Control, id: String, me: int, clean: int, dirty: int) -> void:
	var n: Dictionary = Game.nation
	var c := Syndicate.city_def(id)
	var cs: Dictionary = n["cities"][id]
	if id != "nyc" and not Syndicate.has_wh(n, id, me):
		var wp := Syndicate.warehouse_price(id)
		_nbtn(row, "WAREHOUSE $%s CLEAN" % _money(wp), ["warehouse", id], clean >= wp)
	if String(c.get("plant", "")) != "" and int(cs["plant"]) < 0:
		var pp := Syndicate.plant_price(id)
		_nbtn(row, "%s $%s CLEAN" % [String(c["plant"]).to_upper(), _money(pp)], ["plant", id], clean >= pp,
			"%d crates a month at $%d each, into your warehouse there" % [Syndicate.PLANT_OUT[c["plant"]], Syndicate.PLANT_COST])
	if id != "nyc" and String(c.get("port", "")) != "" and int(cs["docks"]) != me:
		var up := Syndicate.union_price(n, id, me)
		_nbtn(row, "UNION LOCAL $%s" % _money(up), ["union", id], dirty >= up, "%s: $%d a month after" % [c["port"], Syndicate.union_wage(id)])
	if bool(c.get("yard", false)) and int(cs["yard"]) != me:
		var yp := Syndicate.yard_price(n, id, me)
		_nbtn(row, "YARDMASTER $%s" % _money(yp), ["yard", id], dirty >= yp, "Your freight on lines through %s moves safely" % c["name"])


# ------------------------------------------------------------------ newspaper, end

func show_newspaper(m: int) -> void:
	for c in _paper_body.get_children():
		c.queue_free()
	var ink := Color("16100a")
	var mast := _label("The Daily Ledger", 38, ink, serif)
	mast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_paper_body.add_child(mast)
	var date := _label("%s  ·  TWO CENTS" % Game.date_text().to_upper(), 14, Color("3a2a1a"), cond)
	date.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_paper_body.add_child(date)
	var sep := HSeparator.new()
	_paper_body.add_child(sep)
	var shown := 0
	for n in Game.news:
		if m >= 0 and int(n["month"]) < Game.month - 1:
			break
		var l := _label(String(n["text"]), 26 if shown == 0 or n.get("big", false) else 18, ink, serif if shown == 0 else sans)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(480, 0)
		_paper_body.add_child(l)
		shown += 1
		if shown >= (6 if m >= 0 else 12):
			break
	_paper.visible = shown > 0 and (_modal == "" or m < 0)
	_paper_t = 9.0
	if m < 0 and shown > 0:
		_modal = "paper" if _modal == "" else _modal
	if world and world.audio and shown > 0:
		world.audio.ui("page_turn", -8.0)


func show_final() -> void:
	for c in _final.get_children():
		c.queue_free()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_final.add_child(v)
	v.add_child(_label("December 1933. Prohibition is over.", 34, INK, serif))
	v.add_child(_label("The families are ranked by their legacy: clean money, what they own, who pays them, their name on the street, and how much the Bureau has on them.", 18, MUTE, sans))
	var ranks := Game.families.duplicate()
	ranks.sort_custom(func(a, b) -> bool: return Game.legacy(a["id"]) > Game.legacy(b["id"]))
	var n := 1
	for o in ranks:
		v.add_child(_label("%d.  The %s family (%s)  ·  $%s" % [n, o["name"], "AI" if o["ai"] else _player_of(o["id"]), _money(Game.legacy(o["id"]))], 26 if n == 1 else 20, Color(o["color"]).lightened(0.35), serif if n == 1 else sans))
		n += 1
	var b := Button.new()
	b.text = "BACK TO THE MENU"
	b.pressed.connect(func() -> void:
		Net.leave()
		get_tree().change_scene_to_file("res://scenes/main.tscn"))
	v.add_child(b)
	var keep := Button.new()
	keep.text = "KEEP PLAYING (NO MORE SCORING)"
	keep.pressed.connect(func() -> void:
		_final.visible = false
		_modal = "")
	v.add_child(keep)
	_final.visible = true
	_modal = "final"
