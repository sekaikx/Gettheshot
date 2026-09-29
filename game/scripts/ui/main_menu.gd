extends Control
## The title screen: a rainy Little Italy night, FAMIGLIA, and six big choices. New game (solo
## against AI families), Continue the saved campaign, Play with friends (host a table or join
## one), How to play, Settings, Quit. Any number of players works: every player founds a family
## (or joins a friend's as underboss), AI families fill the rest of the city.
##
## Command line (tests and tools/dev/mptest.sh depend on these):
##   --autotest            start a solo game at once (short months, no tutorial)
##   --autohost            host at once; start when --players=N (default 2) are in
##   --autojoin=IP         join that host at once
##   --name=X --family=Y   your name and family name
## The profile (name, family, colour, address) is never saved during those runs.

const PAGES := ["new", "friends", "join", "lobby", "settings", "howto"]
const PACES := [90.0, 150.0, 240.0]

var _name: LineEdit
var _fam: LineEdit
var _color := 0
var _swatches: Array[Button] = []
var _rivals_n := 3
var _length := 0             # 0: 1929 to 1933, 1: 1923 to 1933
var _pace := 1               # Fast / Normal / Slow
var _tutorial := true
var _ip: LineEdit
var _port: LineEdit
var _join_mode := 0          # 0: found my own family, 1: join the host's
var _status: Label
var _status_box: PanelContainer
var _lobby: VBoxContainer     # the roster rows
var _start_btn: Button
var _leave_btn: Button
var _main: Control            # the title and its menu
var _host_mode := false
var _page := ""

var _scene: MenuTitleScene
var _scrim: ColorRect
var _items: VBoxContainer
var _home_col: VBoxContainer
var _frame: PanelContainer
var _pages := {}
var _page_first := {}
var _identity: VBoxContainer
var _seal: Control
var _fam_line: Label
var _don_line: Label
var _new_title: Label
var _new_start: Button
var _length_hint: Label
var _pace_hint: Label
var _lobby_title: Label
var _lobby_side_host: Control
var _lobby_side_client: Control
var _lobby_addr: Label
var _lobby_rules: Label
var _wait_label: Label
var _settings: MenuSettings
var _howto: MenuHowTo
var _music: AudioStreamPlayer
var _rain: AudioStreamPlayer
var _ui_tick: AudioStreamPlayer
var _ui_click: AudioStreamPlayer
var _tick_cd := 0.0
var _t := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Settings.load_and_apply()
	var bg := ColorRect.new()
	bg.color = Color("07080d")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_scene = MenuTitleScene.new()
	_scene.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_scene)
	_scrim = ColorRect.new()
	_scrim.color = Color(0.01, 0.01, 0.02, 0.0)
	_scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_scrim)
	_build_identity()
	_build_home()
	_build_panels()
	_build_status()
	_build_audio()
	_wire_sounds(self)
	get_viewport().gui_focus_changed.connect(_on_focus_changed)
	Net.roster_changed.connect(_on_roster)
	Net.connection_failed.connect(_on_net_failed)
	Net.left_lobby.connect(_on_net_left)
	Net.joined_lobby.connect(_on_joined)
	Net.game_started.connect(_go_world)
	_show_main()
	var args := OS.get_cmdline_user_args()
	if "--autotest" in args:
		call_deferred("_play_solo")
	for a in args:
		if a.begins_with("--name="):
			_name.text = a.substr(7)
		if a.begins_with("--family="):
			_fam.text = a.substr(9)
	_update_identity()
	if "--autohost" in args:
		call_deferred("_host")
		Net.roster_changed.connect(_on_autohost_roster)
	for a in args:
		if a.begins_with("--autojoin="):
			_ip.text = a.substr(11)
			call_deferred("_join")


func _process(delta: float) -> void:
	_t += delta
	_tick_cd = maxf(0.0, _tick_cd - delta)
	var want := 0.5 if _page != "" else 0.0
	_scrim.color.a = move_toward(_scrim.color.a, want, delta * 2.5)
	_fit(_frame, Vector2(48, 40))
	_fit(_main, Vector2(0, 0))
	if _wait_label and _wait_label.is_visible_in_tree():
		_wait_label.text = "Waiting for the host to start" + ".".repeat(1 + int(_t * 2.0) % 3)


## Scale a centred panel down when the window (or a big UI size) leaves too little room.
func _fit(c: Control, margin: Vector2) -> void:
	if c == null or not c.visible:
		return
	if c == _main:
		# the title column: left side, centred vertically, shrunk to fit
		var need_h := _home_col.get_combined_minimum_size()
		var s_h := minf(1.0, minf((size.y - 70.0) / need_h.y, (size.x - 60.0) / (need_h.x + 112.0)))
		_home_col.size = need_h
		_home_col.scale = Vector2(s_h, s_h)
		_home_col.position = Vector2(roundf(112.0 * minf(1.0, size.x / 1600.0)), roundf((size.y - need_h.y * s_h) * 0.5))
		return
	var need := c.get_combined_minimum_size()
	var avail := size - margin * 2.0
	if need.x <= 0 or need.y <= 0:
		return
	var s := minf(1.0, minf(avail.x / need.x, avail.y / need.y))
	c.pivot_offset = c.size * 0.5
	c.scale = Vector2(s, s)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		if _page == "howto" and _howto.handle_key(k):
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_back()


func _input(event: InputEvent) -> void:
	# the card pager takes the arrow keys even when a button has the focus
	if _page == "howto" and event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		if k == KEY_LEFT or k == KEY_RIGHT:
			if _howto.handle_key(k):
				get_viewport().set_input_as_handled()


func _back() -> void:
	match _page:
		"":
			pass
		"join":
			_show_page("friends")
		"new":
			_show_page("friends" if _host_mode else "")
		"lobby":
			Net.leave()
			_show_main()
		_:
			_show_main()


# ------------------------------------------------------------------ building: the title

func _build_home() -> void:
	_main = Control.new()
	_main.set_anchors_preset(Control.PRESET_FULL_RECT)
	_main.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_main)
	_home_col = VBoxContainer.new()
	var col := _home_col
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_main.add_child(col)
	col.add_child(MenuLogo.new())
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 40)
	col.add_child(gap)
	_items = VBoxContainer.new()
	_items.add_theme_constant_override("separation", 4)
	col.add_child(_items)
	_add_item("New game", "", func() -> void:
		_host_mode = false
		_show_page("new"))
	var cont := _add_item("Continue", _save_blurb(), _continue)
	cont.visible = Game.has_save()
	_add_item("Play with friends", "", func() -> void: _show_page("friends"))
	_add_item("How to play", "", func() -> void: _show_page("howto"))
	_add_item("Settings", "", func() -> void: _show_page("settings"))
	_add_item("Quit", "", func() -> void: get_tree().quit())
	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(0, 34)
	col.add_child(gap2)
	col.add_child(_key_hints([["Up", ""], ["Down", "Choose"], ["Enter", "Select"], ["Esc", "Back"]], true))
	# the version, bottom right
	var ver := MenuStyle.label("v%s" % String(ProjectSettings.get_setting("application/config/version", "0.1")), "cond", 16, Color(MenuStyle.NIGHT_MUTE, 0.7))
	ver.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ver.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	ver.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ver.position = Vector2(-24, -34)
	ver.offset_left = -120
	ver.offset_top = -40
	ver.offset_right = -26
	ver.offset_bottom = -16
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(ver)


func _add_item(text: String, sub: String, cb: Callable) -> Button:
	var b := MenuWidgets.TitleItem.new(text, sub)
	b.pressed.connect(cb)
	_items.add_child(b)
	return b


func _key_hints(keys: Array, on_dark: bool) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(38, 0)
	h.add_child(pad)
	for kd in keys:
		h.add_child(MenuWidgets.KeyCap.new(String(kd[0]), on_dark))
		if String(kd[1]) != "":
			var l := MenuStyle.label(String(kd[1]), "semi", 17, MenuStyle.NIGHT_MUTE if on_dark else MenuStyle.INK_SOFT)
			l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h.add_child(l)
			var sp := Control.new()
			sp.custom_minimum_size = Vector2(12, 0)
			h.add_child(sp)
	return h


## "March 1931 · the Vitale family" from the save file, or "".
func _save_blurb() -> String:
	if not Game.has_save():
		return ""
	var txt := FileAccess.get_file_as_string("user://saves/campaign.json")
	var data = JSON.parse_string(txt) if txt != "" else null
	if typeof(data) != TYPE_DICTIONARY or not data.has("month"):
		return ""
	var out := Game.date_text(int(data["month"]))
	var players = data.get("players", {})
	var fams = data.get("families", [])
	if typeof(players) == TYPE_DICTIONARY and typeof(fams) == TYPE_ARRAY and not players.is_empty():
		var p = players.get("1", players.values()[0])
		if typeof(p) == TYPE_DICTIONARY:
			var fi := int(p.get("family", -1))
			if fi >= 0 and fi < fams.size() and typeof(fams[fi]) == TYPE_DICTIONARY:
				out += "  ·  the %s family" % String(fams[fi].get("name", ""))
	return out


# ------------------------------------------------------------------ building: the panels

func _build_panels() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_frame = PanelContainer.new()
	_frame.add_theme_stylebox_override("panel", MenuStyle.frame())
	center.add_child(_frame)
	_pages["new"] = _build_new()
	_pages["friends"] = _build_friends()
	_pages["join"] = _build_join()
	_pages["lobby"] = _build_lobby()
	_pages["settings"] = _build_settings()
	_pages["howto"] = _build_howto()
	for k in _pages:
		_frame.add_child(_pages[k])
		(_pages[k] as Control).visible = false
	(_pages["new"] as Node).find_child("IdentitySlot", true, false).add_child(_identity)


## A page: heading, rule, body, a footer of buttons. Returns [page, body, footer].
func _page_shell(title: String) -> Array:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	var h := MenuStyle.heading(title, 42)
	v.add_child(h)
	v.add_child(MenuStyle.divider(420))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	v.add_child(gap)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)
	var rule := ColorRect.new()
	rule.color = Color(MenuStyle.INK, 0.14)
	rule.custom_minimum_size = Vector2(0, 1)
	v.add_child(rule)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 14)
	v.add_child(foot)
	return [v, body, foot, h]


func _spacer_h() -> Control:
	var s := Control.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return s


func _build_identity() -> void:
	_identity = VBoxContainer.new()
	_identity.add_theme_constant_override("separation", 16)
	_identity.custom_minimum_size = Vector2(410, 0)
	_name = MenuStyle.field("Your name", _saved("name", "Alex"))
	_fam = MenuStyle.field("Family name", _saved("family", Names.FAMILY_NAMES[0]))
	_name.text_changed.connect(func(_s: String) -> void: _update_identity())
	_fam.text_changed.connect(func(_s: String) -> void: _update_identity())
	_identity.add_child(MenuStyle.labeled("Your name", _name))
	_identity.add_child(MenuStyle.labeled("Family name", _fam))
	var sw := HBoxContainer.new()
	sw.add_theme_constant_override("separation", 2)
	_color = clampi(int(_saved("color", "0")), 0, Names.FAMILY_COLORS.size() - 1)
	for k in Names.FAMILY_COLORS.size():
		var b := MenuWidgets.Swatch.new(Color(Names.FAMILY_COLORS[k]))
		b.button_pressed = k == _color
		b.tooltip_text = "Family colour"
		var kk := k
		b.pressed.connect(func() -> void:
			_color = kk
			for s in _swatches:
				s.set_pressed_no_signal(s == _swatches[kk])
				s.queue_redraw()
			_update_identity())
		_swatches.append(b)
		sw.add_child(b)
	_identity.add_child(MenuStyle.labeled("Family colour", sw))
	# how your family will look: a wax seal and the name
	var prev := PanelContainer.new()
	prev.add_theme_stylebox_override("panel", MenuStyle.inset())
	var ph := HBoxContainer.new()
	ph.add_theme_constant_override("separation", 16)
	prev.add_child(ph)
	_seal = MenuWidgets.Seal.new(Color(Names.FAMILY_COLORS[_color]), "V", 60)
	ph.add_child(_seal)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 0)
	pv.alignment = BoxContainer.ALIGNMENT_CENTER
	_fam_line = MenuStyle.label("", "deco", 24, MenuStyle.INK)
	_don_line = MenuStyle.label("", "sans", 17, MenuStyle.INK_SOFT)
	pv.add_child(_fam_line)
	pv.add_child(_don_line)
	ph.add_child(pv)
	_identity.add_child(prev)


func _update_identity() -> void:
	if _seal == null:
		return
	var fam := _fam.text.strip_edges() if _fam.text.strip_edges() != "" else "Vitale"
	var nm := _name.text.strip_edges() if _name.text.strip_edges() != "" else "Player"
	_seal.set("seal_color", Color(Names.FAMILY_COLORS[_color]))
	_seal.set("letter", fam.left(1).to_upper())
	_fam_line.text = "The %s family" % fam
	_don_line.text = "Don %s %s" % [nm, fam] if _join_mode == 0 or _page != "join" else "%s, underboss" % nm


func _build_new() -> Control:
	var sh := _page_shell("New game")
	var body: VBoxContainer = sh[1]
	var foot: HBoxContainer = sh[2]
	_new_title = sh[3]
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 56)
	body.add_child(cols)
	var left := VBoxContainer.new()
	left.name = "IdentitySlot"
	cols.add_child(left)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 16)
	right.custom_minimum_size = Vector2(470, 0)
	cols.add_child(right)
	var rv := MenuStyle.segmented(["1", "2", "3", "4", "5", "6", "7"], _rivals_n - 1, func(i: int) -> void: _rivals_n = i + 1)
	right.add_child(MenuStyle.labeled("Rival families", rv, "Run by the computer. More rivals, more trouble."))
	var lv := MenuStyle.segmented(["Short: 1929 to 1933", "Long: 1923 to 1933"], _length, func(i: int) -> void:
		_length = i
		_update_hints())
	var lb := MenuStyle.labeled("Length", lv, " ")
	_length_hint = lb.get_node("Hint")
	right.add_child(lb)
	var pv := MenuStyle.segmented(["Fast", "Normal", "Slow"], _pace, func(i: int) -> void:
		_pace = i
		_update_hints())
	var pb := MenuStyle.labeled("Pace", pv, " ")
	_pace_hint = pb.get_node("Hint")
	right.add_child(pb)
	var tut := HBoxContainer.new()
	tut.add_theme_constant_override("separation", 14)
	var sw := MenuWidgets.Switch.new(_tutorial)
	sw.toggled.connect(func(on: bool) -> void: _tutorial = on)
	tut.add_child(sw)
	var tl := MenuStyle.body("Uncle Carmine shows you the ropes, one step at a time.", 16, MenuStyle.INK_SOFT)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tut.add_child(tl)
	right.add_child(MenuStyle.labeled("Tutorial", tut))
	_update_hints()
	var back := MenuStyle.button("Back")
	back.pressed.connect(_back)
	foot.add_child(back)
	foot.add_child(_spacer_h())
	_new_start = MenuStyle.button("Start", "primary", 240)
	_new_start.pressed.connect(func() -> void:
		if _host_mode:
			_host()
		else:
			_play_solo())
	foot.add_child(_new_start)
	_page_first["new"] = _new_start
	return sh[0]


func _update_hints() -> void:
	var months := Game.REPEAL_MONTH - (72 if _length == 0 else 0)
	var mins := int(months * PACES[_pace] / 60.0)
	_length_hint.text = "The Crash, then the end of Prohibition. About %s." % _hours(mins) if _length == 0 \
		else "All of Prohibition, from the start. About %s." % _hours(mins)
	var per: String = ["1 min 30 s", "2 min 30 s", "4 minutes"][_pace]
	_pace_hint.text = "A month in the game lasts %s." % per


func _hours(mins: int) -> String:
	var h := mins / 60
	var m := int(round((mins % 60) / 15.0)) * 15
	if m == 60:
		h += 1
		m = 0
	if h == 0:
		return "%d minutes" % m
	return "%d hours" % h if m == 0 else "%d h %02d min" % [h, m]


func _build_friends() -> Control:
	var sh := _page_shell("Play with friends")
	var body: VBoxContainer = sh[1]
	var foot: HBoxContainer = sh[2]
	var intro := MenuStyle.body("Up to 8 players. Each of you runs a family, or you run one together.", 20, MenuStyle.INK_SOFT)
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(intro)
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 36)
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(cards)
	var host := MenuWidgets.ChoiceCard.new("handshake", "Host a game", "You pick the rules.\nFriends join you.")
	host.pressed.connect(func() -> void:
		_host_mode = true
		_show_page("new"))
	cards.add_child(host)
	var join := MenuWidgets.ChoiceCard.new("telephone", "Join a friend", "Your friend hosts.\nYou need their address.")
	join.pressed.connect(func() -> void: _show_page("join"))
	cards.add_child(join)
	var back := MenuStyle.button("Back")
	back.pressed.connect(_back)
	foot.add_child(back)
	_page_first["friends"] = host
	return sh[0]


func _build_join() -> Control:
	var sh := _page_shell("Join a friend")
	var body: VBoxContainer = sh[1]
	var foot: HBoxContainer = sh[2]
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 56)
	body.add_child(cols)
	var left := VBoxContainer.new()
	left.name = "IdentitySlot"
	cols.add_child(left)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 16)
	right.custom_minimum_size = Vector2(470, 0)
	cols.add_child(right)
	_ip = MenuStyle.field("For example 192.168.1.20", _saved("ip", "127.0.0.1"), 64)
	right.add_child(MenuStyle.labeled("Your friend's address", _ip, "Your friend sees it on screen when they host."))
	_port = MenuStyle.field("24880", str(Net.DEFAULT_PORT), 5)
	_port.custom_minimum_size.x = 160
	_port.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_port.text_changed.connect(func(s: String) -> void:
		var digits := ""
		for ch in s:
			if ch >= "0" and ch <= "9":
				digits += ch
		if digits != s:
			_port.text = digits
			_port.caret_column = digits.length())
	right.add_child(MenuStyle.labeled("Port", _port, "Leave it at %d unless your friend changed it." % Net.DEFAULT_PORT))
	var jm := MenuStyle.segmented(["Found my own family", "Join the host's family"], _join_mode, func(i: int) -> void:
		_join_mode = i
		_update_identity())
	right.add_child(MenuStyle.labeled("When you get there", jm))
	var back := MenuStyle.button("Back")
	back.pressed.connect(_back)
	foot.add_child(back)
	foot.add_child(_spacer_h())
	var go := MenuStyle.button("Join", "primary", 240)
	go.pressed.connect(_join)
	foot.add_child(go)
	_ip.text_submitted.connect(func(_s: String) -> void: _join())
	_page_first["join"] = _ip
	return sh[0]


func _build_lobby() -> Control:
	var sh := _page_shell("The table")
	var body: VBoxContainer = sh[1]
	var foot: HBoxContainer = sh[2]
	_lobby_title = sh[3]
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 48)
	body.add_child(cols)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	left.custom_minimum_size = Vector2(470, 330)
	cols.add_child(left)
	left.add_child(MenuStyle.caption("At the table"))
	_lobby = VBoxContainer.new()
	_lobby.add_theme_constant_override("separation", 8)
	left.add_child(_lobby)
	# the host's side: the address friends need
	var hs := VBoxContainer.new()
	hs.add_theme_constant_override("separation", 12)
	hs.custom_minimum_size = Vector2(420, 0)
	cols.add_child(hs)
	hs.add_child(MenuStyle.caption("Friends join with"))
	var addr_box := PanelContainer.new()
	addr_box.add_theme_stylebox_override("panel", MenuStyle.inset(MenuStyle.PAPER_DARK, 4))
	var av := VBoxContainer.new()
	av.add_theme_constant_override("separation", 2)
	addr_box.add_child(av)
	_lobby_addr = MenuStyle.label("", "cond", 38, MenuStyle.INK)
	av.add_child(_lobby_addr)
	av.add_child(MenuStyle.label("Port %d" % Net.DEFAULT_PORT, "semi", 19, MenuStyle.INK_SOFT))
	hs.add_child(addr_box)
	hs.add_child(MenuStyle.body("Same house or office: that's all they need. Over the internet: forward port %d on your router and give them your public address." % Net.DEFAULT_PORT, 16, MenuStyle.INK_SOFT))
	var rg := Control.new()
	rg.custom_minimum_size = Vector2(0, 8)
	hs.add_child(rg)
	hs.add_child(MenuStyle.caption("The rules"))
	_lobby_rules = MenuStyle.body("", 18, MenuStyle.INK)
	hs.add_child(_lobby_rules)
	_lobby_side_host = hs
	# a client's side: waiting
	var cs := VBoxContainer.new()
	cs.add_theme_constant_override("separation", 12)
	cs.custom_minimum_size = Vector2(420, 0)
	cols.add_child(cs)
	cs.add_child(MenuStyle.caption("You're in"))
	_wait_label = MenuStyle.label("Waiting for the host to start...", "semi", 22, MenuStyle.INK)
	cs.add_child(_wait_label)
	cs.add_child(MenuStyle.body("The host starts the game when everyone is here. The game opens by itself.", 17, MenuStyle.INK_SOFT))
	_lobby_side_client = cs
	_leave_btn = MenuStyle.button("Leave")
	_leave_btn.pressed.connect(func() -> void:
		Net.leave()
		_show_main())
	foot.add_child(_leave_btn)
	foot.add_child(_spacer_h())
	_start_btn = MenuStyle.button("Start the game", "primary", 260)
	_start_btn.pressed.connect(_start_hosted)
	foot.add_child(_start_btn)
	return sh[0]


func _build_settings() -> Control:
	var sh := _page_shell("Settings")
	var body: VBoxContainer = sh[1]
	var foot: HBoxContainer = sh[2]
	_settings = MenuSettings.new()
	body.add_child(_settings)
	var back := MenuStyle.button("Back")
	back.pressed.connect(_back)
	foot.add_child(back)
	foot.add_child(_spacer_h())
	var def := MenuStyle.button("Reset to defaults")
	def.pressed.connect(func() -> void: _settings.reset())
	foot.add_child(def)
	return sh[0]


func _build_howto() -> Control:
	var sh := _page_shell("How to play")
	var body: VBoxContainer = sh[1]
	var foot: HBoxContainer = sh[2]
	_howto = MenuHowTo.new()
	_howto.closed.connect(_show_main)
	body.add_child(_howto)
	var back := MenuStyle.button("Back to the menu")
	back.pressed.connect(_back)
	foot.add_child(back)
	foot.add_child(_spacer_h())
	var keys := _key_hints([["Left", ""], ["Right", "Turn the cards"]], false)
	keys.get_child(0).custom_minimum_size.x = 0
	foot.add_child(keys)
	return sh[0]


func _build_status() -> void:
	_status_box = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.03, 0.025, 0.94)
	sb.border_color = Color(MenuStyle.OXBLOOD_HI, 0.9)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 10
	sb.content_margin_bottom = 12
	_status_box.add_theme_stylebox_override("panel", sb)
	_status_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_status_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_status_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_status_box.offset_bottom = -26
	_status_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_status_box)
	_status = MenuStyle.label("", "semi", 19, Color("ffd9cc"))
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_box.add_child(_status)
	_status_box.visible = false


func _set_status(t: String) -> void:
	_status.text = t
	_status_box.visible = t != ""
	_status_box.reset_size()
	_status_box.offset_left = -_status_box.size.x * 0.5
	_status_box.offset_right = _status_box.size.x * 0.5
	_status_box.offset_top = -26 - _status_box.size.y


# ------------------------------------------------------------------ sound

func _build_audio() -> void:
	_music = _player("res://assets/audio/night.ogg", &"Music", -9.0, true)
	_rain = _player("res://assets/audio/rain_loop.ogg", &"SFX", -17.0, true)
	_ui_tick = _player("res://assets/audio/tick.ogg", &"SFX", -12.0, false)
	_ui_click = _player("res://assets/audio/click_wood.ogg", &"SFX", -6.0, false)
	if _music.stream:
		_music.volume_db = -40.0
		_music.play()
		create_tween().tween_property(_music, "volume_db", -9.0, 3.0)
	if _rain.stream:
		_rain.play()


func _player(path: String, bus: StringName, db: float, loop: bool) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = load(path) if ResourceLoader.exists(path) else null
	p.bus = bus if AudioServer.get_bus_index(bus) >= 0 else &"Master"
	p.volume_db = db
	if loop:
		p.finished.connect(p.play)
	add_child(p)
	return p


func _wire_sounds(n: Node) -> void:
	if n is BaseButton:
		(n as BaseButton).pressed.connect(_click)
	for c in n.get_children():
		_wire_sounds(c)


func _click() -> void:
	if _ui_click and _ui_click.stream:
		_ui_click.play()
	_tick_cd = 0.15


func _on_focus_changed(_c: Control) -> void:
	if _tick_cd <= 0.0 and _ui_tick and _ui_tick.stream and _t > 0.3:
		_ui_tick.play()
		_tick_cd = 0.06


# ------------------------------------------------------------------ pages

func _show_page(p: String) -> void:
	_page = p
	_set_status("")
	_main.visible = p == ""
	_frame.get_parent().visible = p != ""
	for k in _pages:
		(_pages[k] as Control).visible = k == p
	if p == "":
		_items.get_child(0).grab_focus.call_deferred()
		return
	if p == "new" or p == "join":
		var slot: Node = (_pages[p] as Node).find_child("IdentitySlot", true, false)
		if slot and _identity.get_parent() != slot:
			if _identity.get_parent():
				_identity.reparent(slot, false)
			else:
				slot.add_child(_identity)
		_update_identity()
	if p == "new":
		_new_title.text = ("Host a game" if _host_mode else "New game").to_upper()
		_new_start.text = "Open the table" if _host_mode else "Start"
	var first: Control = _page_first.get(p)
	if p == "settings":
		_settings.refresh()
		first = _settings.first_focus()
	elif p == "howto":
		_howto.show_page(0)
		first = _howto.first_focus()
	if first:
		first.grab_focus.call_deferred()
	_frame.reset_size()


func _show_main() -> void:
	_show_page("")


# ------------------------------------------------------------------ the profile

func _is_test_run() -> bool:
	for a in OS.get_cmdline_user_args():
		if a == "--autotest" or a == "--autohost" or a.begins_with("--autojoin") or a == "--mptest":
			return true
	return false


func _saved(key: String, def: String) -> String:
	var cf := ConfigFile.new()
	if cf.load("user://profile.cfg") == OK:
		return String(cf.get_value("profile", key, def))
	return def


func _save_profile() -> void:
	if _is_test_run():
		return
	var cf := ConfigFile.new()
	cf.set_value("profile", "name", _name.text)
	cf.set_value("profile", "family", _fam.text)
	cf.set_value("profile", "color", str(_color))
	cf.set_value("profile", "ip", _ip.text)
	cf.save("user://profile.cfg")


func _port_value() -> int:
	var p := int(_port.text) if _port.text.is_valid_int() else Net.DEFAULT_PORT
	return p if p >= 1024 and p <= 65535 else Net.DEFAULT_PORT


# ------------------------------------------------------------------ the flows

func _info() -> Dictionary:
	_save_profile()
	return {"name": _name.text.strip_edges() if _name.text.strip_edges() != "" else "Player",
		"family_name": _fam.text.strip_edges() if _fam.text.strip_edges() != "" else "Vitale",
		"color": Names.FAMILY_COLORS[_color], "join": -1 if _join_mode == 0 else 0}


func _cfg() -> Dictionary:
	var month_s: float = PACES[_pace]
	if "--autotest" in OS.get_cmdline_user_args():
		month_s = 40.0
	return {"seed": randi() % 100000, "families": 0, "month_seconds": month_s,
		"start_month": 72 if _length == 0 else 0, "end_month": Game.REPEAL_MONTH,
		"tutorial": _tutorial and not _is_test_run()}


func _humans() -> Array:
	var out := []
	for id in Net.roster:
		var r: Dictionary = Net.roster[id]
		out.append({"peer": id, "name": r["name"], "family_name": _unique_family(r["family_name"], out),
			"color": _unique_color(r["color"], out), "join": int(r.get("join", -1))})
	return out


func _unique_family(n: String, taken: Array) -> String:
	for t in taken:
		if t["family_name"] == n:
			for f in Names.FAMILY_NAMES:
				if taken.all(func(x: Dictionary) -> bool: return x["family_name"] != f):
					return f
	return n


func _unique_color(c: String, taken: Array) -> String:
	for t in taken:
		if t["color"] == c:
			for f in Names.FAMILY_COLORS:
				if taken.all(func(x: Dictionary) -> bool: return x["color"] != f):
					return f
	return c


func _play_solo() -> void:
	_join_mode = 0
	Net.my_info = _info()
	Net.solo()
	var cfg := _cfg()
	var humans := _humans()
	cfg["families"] = humans.size() + _rivals_n
	Game.new_campaign(cfg, humans)
	Net.start_game()


func _continue() -> void:
	Net.my_info = _info()
	var err := Net.host_lan(_port_value())
	if err != OK:
		Net.solo()
	if not Game.load_campaign():
		_set_status("Could not read the saved game.")
		return
	# the host keeps their seat (peer 1); friends reclaim theirs by joining with the same name
	var mine := ""
	for k in Game.players:
		if Game.players[k]["name"] == Net.my_info["name"]:
			mine = k
	if mine == "":
		mine = Game.players.keys()[0] if not Game.players.is_empty() else ""
	if mine != "" and mine != "1":
		var p = Game.players[mine]
		Game.players.erase(mine)
		Game.players["1"] = p
	Net.start_game()


func _host() -> void:
	_join_mode = 0
	Net.my_info = _info()
	if Net.host_lan(_port_value()) == OK:
		_show_lobby(true)


func _join() -> void:
	Net.my_info = _info()
	_set_status("Calling %s..." % _ip.text)
	Net.join_lan(_ip.text, _port_value())


func _on_joined() -> void:
	if not Net.is_host():
		_show_lobby(false)
		_set_status("")


func _on_net_failed(reason: String) -> void:
	_set_status(_plain_net(reason))
	if _page == "lobby":
		_show_page("join")
		_set_status(_plain_net(reason))


func _on_net_left(reason: String) -> void:
	if _page == "lobby":
		_show_main()
	if reason != "":
		_set_status(_plain_net(reason))


func _plain_net(reason: String) -> String:
	if reason.begins_with("Could not open port"):
		return "Can't open the table: port %d is busy. Is another game open?" % _port_value()
	return reason


func _on_autohost_roster() -> void:
	var want := 2
	for a2 in OS.get_cmdline_user_args():
		if a2.begins_with("--players="):
			want = int(a2.substr(10))
	if Net.roster.size() >= want and not Net.in_game:
		get_tree().create_timer(1.0).timeout.connect(_start_hosted)


func _show_lobby(host: bool) -> void:
	_show_page("lobby")
	_start_btn.visible = host
	_lobby_side_host.visible = host
	_lobby_side_client.visible = not host
	_lobby_title.text = "YOUR TABLE" if host else "THE TABLE"
	_lobby_addr.text = _local_address()
	var rules: Array[String] = ["%d rival famil%s" % [_rivals_n, "y" if _rivals_n == 1 else "ies"],
		"1929 to 1933" if _length == 0 else "1923 to 1933", ["Fast", "Normal", "Slow"][_pace] + " pace",
		"Tutorial on" if _tutorial else "No tutorial"]
	_lobby_rules.text = "%s  ·  %s\n%s  ·  %s" % rules
	_on_roster()
	(_start_btn if host else _leave_btn).grab_focus.call_deferred()


## This computer's address on the local network (the one friends type in).
func _local_address() -> String:
	var best := ""
	for a in IP.get_local_addresses():
		if a.count(".") != 3 or a.begins_with("127.") or a.begins_with("169.254."):
			continue
		if best == "" or (a.begins_with("192.168.") and not best.begins_with("192.168.")):
			best = a
	return best if best != "" else "127.0.0.1"


func _on_roster() -> void:
	if _lobby == null:
		return
	for c in _lobby.get_children():
		c.queue_free()
	var host_color := Color(Names.FAMILY_COLORS[0])
	if Net.roster.has(1):
		host_color = Color(String(Net.roster[1].get("color", Names.FAMILY_COLORS[0])))
	for id in Net.roster:
		var r: Dictionary = Net.roster[id]
		var joins: bool = int(r.get("join", -1)) >= 0 and int(id) != 1
		var col := host_color if joins else Color(String(r.get("color", Names.FAMILY_COLORS[0])))
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", MenuStyle.inset(MenuStyle.PAPER_HI, 4))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 14)
		row.add_child(h)
		var fam_name := String(r.get("family_name", ""))
		h.add_child(MenuWidgets.Seal.new(col, fam_name.left(1).to_upper() if not joins else "", 46))
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", -2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_child(MenuStyle.label(String(r.get("name", "Player")), "semi", 21, MenuStyle.INK))
		v.add_child(MenuStyle.label("Joins the host's family" if joins else "The %s family" % fam_name, "sans", 16, MenuStyle.INK_SOFT))
		h.add_child(v)
		if id == 1:
			h.add_child(_tag("HOST", MenuStyle.OXBLOOD))
		if id == Net.my_id():
			h.add_child(_tag("YOU", MenuStyle.INK))
		_lobby.add_child(row)
	if _start_btn:
		var n := Net.roster.size()
		_start_btn.text = "Start the game" if n <= 1 else "Start: %d players" % n


func _tag(text: String, col: Color) -> Control:
	var c := CenterContainer.new()
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 2
	sb.content_margin_bottom = 3
	p.add_theme_stylebox_override("panel", sb)
	p.add_child(MenuStyle.label(text, "cond", 15, MenuStyle.PAPER_HI))
	c.add_child(p)
	return c


func _start_hosted() -> void:
	if Net.in_game:
		return
	var cfg := _cfg()
	var humans := _humans()
	cfg["families"] = humans.filter(func(h: Dictionary) -> bool: return int(h["join"]) < 0).size() + _rivals_n
	Game.new_campaign(cfg, humans)
	Net.send_state(Game.get_state())
	Net.start_game()


func _go_world() -> void:
	if is_inside_tree():
		get_tree().change_scene_to_file("res://scenes/world.tscn")
