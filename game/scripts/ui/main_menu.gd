extends Control
## Title screen: play solo against AI families, host a game for friends, join one, or continue
## the saved campaign. Any number of players works: every player founds a family (or joins a
## friend's as underboss), AI families fill the rest of the city.

const GOLD2 := Color("f0d58a")
const INK := Color("efe6d2")
const MUTE := Color("9b907c")

var serif: FontVariation
var cond: Font
var _name: LineEdit
var _fam: LineEdit
var _color := 0
var _swatches: Array[Button] = []
var _rivals: SpinBox
var _length: OptionButton
var _pace: OptionButton
var _ip: LineEdit
var _port: SpinBox
var _join_mode: OptionButton
var _status: Label
var _lobby: VBoxContainer
var _lobby_list: Label
var _start_btn: Button
var _main: VBoxContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	serif = FontVariation.new()
	serif.base_font = load("res://assets/fonts/Fraunces-Variable.ttf")
	serif.variation_opentype = {"wght": 700}
	cond = load("res://assets/fonts/barlow-condensed-latin-700-normal.woff2")
	theme = _theme()
	var bg := ColorRect.new()
	bg.color = Color("0b0907")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var art := TextureRect.new()
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.modulate = Color(1, 1, 1, 0.35)
	if ResourceLoader.exists("res://assets/ui/title.png"):
		art.texture = load("res://assets/ui/title.png")
	add_child(art)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.custom_minimum_size = Vector2(620, 0)
	center.add_child(col)
	var title := Label.new()
	title.text = "FAMIGLIA"
	title.add_theme_font_override("font", serif)
	title.add_theme_font_size_override("font_size", 96)
	title.add_theme_color_override("font_color", Color("d4a532"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var sub := _label("New York, 1923. Build your empire. Betray your friends.", 22, INK)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	_main = VBoxContainer.new()
	_main.add_theme_constant_override("separation", 10)
	col.add_child(_main)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_name = _edit("Your name", _saved("name", "Alex"))
	_fam = _edit("Family name", _saved("family", Names.FAMILY_NAMES[0]))
	row.add_child(_labeled("YOUR NAME", _name))
	row.add_child(_labeled("YOUR FAMILY", _fam))
	_main.add_child(row)
	var sw := HBoxContainer.new()
	sw.add_theme_constant_override("separation", 6)
	sw.add_child(_label("COLOURS", 14, MUTE))
	_color = int(_saved("color", "0"))
	for k in Names.FAMILY_COLORS.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(40, 30)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(Names.FAMILY_COLORS[k])
		b.add_theme_stylebox_override("normal", sb)
		var sbh := sb.duplicate() as StyleBoxFlat
		sbh.set_border_width_all(3)
		sbh.border_color = Color.WHITE
		b.add_theme_stylebox_override("hover", sbh)
		b.add_theme_stylebox_override("pressed", sbh)
		b.toggle_mode = true
		b.button_pressed = k == _color
		var kk := k
		b.pressed.connect(func() -> void:
			_color = kk
			for s in _swatches: s.button_pressed = s == _swatches[kk])
		_swatches.append(b)
		sw.add_child(b)
	_main.add_child(sw)
	var setup := HBoxContainer.new()
	setup.add_theme_constant_override("separation", 10)
	_rivals = SpinBox.new()
	_rivals.min_value = 1
	_rivals.max_value = 7
	_rivals.value = 3
	setup.add_child(_labeled("AI FAMILIES", _rivals))
	_length = OptionButton.new()
	_length.add_item("1929 to 1933: the Crash and Repeal")
	_length.add_item("1923 to 1933: all of Prohibition")
	setup.add_child(_labeled("CAMPAIGN", _length))
	_pace = OptionButton.new()
	for t in ["A month is 1.5 minutes", "A month is 2.5 minutes", "A month is 4 minutes"]:
		_pace.add_item(t)
	_pace.select(1)
	setup.add_child(_labeled("PACE", _pace))
	_main.add_child(setup)
	var solo := _button("PLAY SOLO", _play_solo)
	_main.add_child(solo)
	var cont := _button("CONTINUE THE SAVED CAMPAIGN", _continue)
	cont.disabled = not Game.has_save()
	_main.add_child(cont)
	var host := _button("HOST A GAME FOR FRIENDS", _host)
	_main.add_child(host)
	var jrow := HBoxContainer.new()
	jrow.add_theme_constant_override("separation", 8)
	_ip = _edit("Host's IP address", _saved("ip", "127.0.0.1"))
	_port = SpinBox.new()
	_port.min_value = 1024
	_port.max_value = 65535
	_port.value = Net.DEFAULT_PORT
	_join_mode = OptionButton.new()
	_join_mode.add_item("Found my own family")
	_join_mode.add_item("Join the host's family")
	jrow.add_child(_labeled("IP", _ip))
	jrow.add_child(_labeled("PORT", _port))
	jrow.add_child(_labeled("ON ARRIVAL", _join_mode))
	_main.add_child(jrow)
	_main.add_child(_button("JOIN A FRIEND'S GAME", _join))
	_main.add_child(_button("QUIT", func() -> void: get_tree().quit()))
	_lobby = VBoxContainer.new()
	_lobby.visible = false
	_lobby.add_theme_constant_override("separation", 10)
	col.add_child(_lobby)
	_lobby.add_child(_label("THE TABLE", 22, GOLD2))
	_lobby_list = _label("", 20, INK)
	_lobby.add_child(_lobby_list)
	var lobby_hint := _label("Friends join with your IP address and port %d (forward the port for play over the internet). Everyone who joins founds a family; AI families fill the rest." % Net.DEFAULT_PORT, 16, MUTE)
	lobby_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lobby.add_child(lobby_hint)
	_start_btn = _button("START THE CAMPAIGN", _start_hosted)
	_lobby.add_child(_start_btn)
	_lobby.add_child(_button("LEAVE", func() -> void:
		Net.leave()
		_show_main()))
	_status = _label("", 18, Color("ff8a7a"))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_status)
	var credit := _label("A prototype. People and sound from Woods; city from Kenney (CC0); textures from Poly Haven (CC0).", 13, MUTE)
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(credit)
	Net.roster_changed.connect(_on_roster)
	Net.connection_failed.connect(func(r: String) -> void:
		_status.text = r
		_show_main())
	Net.left_lobby.connect(func(r: String) -> void:
		_status.text = r
		_show_main())
	Net.joined_lobby.connect(_on_joined)
	Net.game_started.connect(_go_world)
	var args := OS.get_cmdline_user_args()
	if "--autotest" in args:
		call_deferred("_play_solo")
	for a in args:
		if a.begins_with("--name="):
			_name.text = a.substr(7)
		if a.begins_with("--family="):
			_fam.text = a.substr(9)
	if "--autohost" in args:
		call_deferred("_host")
		Net.roster_changed.connect(func() -> void:
			var want := 2
			for a2 in OS.get_cmdline_user_args():
				if a2.begins_with("--players="):
					want = int(a2.substr(10))
			if Net.roster.size() >= want and not Net.in_game:
				get_tree().create_timer(1.0).timeout.connect(_start_hosted))
	for a in args:
		if a.begins_with("--autojoin="):
			_ip.text = a.substr(11)
			call_deferred("_join")


func _theme() -> Theme:
	var t := Theme.new()
	t.default_font = load("res://assets/fonts/barlow-latin-500-normal.woff2")
	t.default_font_size = 19
	var btn := StyleBoxFlat.new()
	btn.bg_color = Color("241f1a")
	btn.border_color = Color("4a3d2c")
	btn.set_border_width_all(1)
	btn.set_content_margin_all(10)
	var hov := btn.duplicate() as StyleBoxFlat
	hov.border_color = Color("d4a532")
	hov.bg_color = Color("2e261c")
	t.set_stylebox("normal", "Button", btn)
	t.set_stylebox("hover", "Button", hov)
	t.set_stylebox("pressed", "Button", hov)
	t.set_stylebox("focus", "Button", hov)
	t.set_font("font", "Button", cond)
	t.set_font_size("font_size", "Button", 22)
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", GOLD2)
	var le := StyleBoxFlat.new()
	le.bg_color = Color("1a1612")
	le.border_color = Color("4a3d2c")
	le.set_border_width_all(1)
	le.set_content_margin_all(8)
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("normal", "OptionButton", btn)
	t.set_stylebox("hover", "OptionButton", hov)
	t.set_font("font", "OptionButton", load("res://assets/fonts/barlow-latin-500-normal.woff2"))
	t.set_font_size("font_size", "OptionButton", 17)
	return t


func _label(t: String, s: int, c: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", s)
	l.add_theme_color_override("font_color", c)
	return l


func _labeled(cap: String, ctl: Control) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var l := _label(cap, 13, MUTE)
	l.add_theme_font_override("font", cond)
	v.add_child(l)
	ctl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(ctl)
	return v


func _edit(ph: String, val: String) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = ph
	e.text = val
	e.max_length = 16
	return e


func _button(t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.pressed.connect(cb)
	return b


func _saved(key: String, def: String) -> String:
	var cf := ConfigFile.new()
	if cf.load("user://profile.cfg") == OK:
		return String(cf.get_value("profile", key, def))
	return def


func _save_profile() -> void:
	var cf := ConfigFile.new()
	cf.set_value("profile", "name", _name.text)
	cf.set_value("profile", "family", _fam.text)
	cf.set_value("profile", "color", str(_color))
	cf.set_value("profile", "ip", _ip.text)
	cf.save("user://profile.cfg")


func _info() -> Dictionary:
	_save_profile()
	return {"name": _name.text.strip_edges() if _name.text.strip_edges() != "" else "Player",
		"family_name": _fam.text.strip_edges() if _fam.text.strip_edges() != "" else "Vitale",
		"color": Names.FAMILY_COLORS[_color], "join": -1 if _join_mode.selected == 0 else 0}


func _cfg() -> Dictionary:
	var month_s: float = [90.0, 150.0, 240.0][_pace.selected]
	if "--autotest" in OS.get_cmdline_user_args():
		month_s = 40.0
	return {"seed": randi() % 100000, "families": 0, "month_seconds": month_s,
		"start_month": 72 if _length.selected == 0 else 0, "end_month": Game.REPEAL_MONTH}


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
	Net.my_info = _info()
	Net.solo()
	var cfg := _cfg()
	var humans := _humans()
	cfg["families"] = humans.size() + int(_rivals.value)
	Game.new_campaign(cfg, humans)
	Net.start_game()


func _continue() -> void:
	Net.my_info = _info()
	var err := Net.host_lan(int(_port.value))
	if err != OK:
		Net.solo()
	if not Game.load_campaign():
		_status.text = "Could not read the saved campaign."
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
	Net.my_info = _info()
	if Net.host_lan(int(_port.value)) == OK:
		_show_lobby(true)


func _join() -> void:
	Net.my_info = _info()
	_status.text = "Calling %s..." % _ip.text
	Net.join_lan(_ip.text, int(_port.value))


func _on_joined() -> void:
	if not Net.is_host():
		_show_lobby(false)
		_status.text = ""


func _show_lobby(host: bool) -> void:
	_main.visible = false
	_lobby.visible = true
	_start_btn.visible = host
	_on_roster()


func _show_main() -> void:
	_main.visible = true
	_lobby.visible = false


func _on_roster() -> void:
	var lines := []
	for id in Net.roster:
		var r: Dictionary = Net.roster[id]
		lines.append("%s  ·  the %s family%s" % [r["name"], r["family_name"], "  (host)" if id == 1 else ""])
	_lobby_list.text = "\n".join(lines)


func _start_hosted() -> void:
	if Net.in_game:
		return
	var cfg := _cfg()
	var humans := _humans()
	cfg["families"] = humans.filter(func(h: Dictionary) -> bool: return int(h["join"]) < 0).size() + int(_rivals.value)
	Game.new_campaign(cfg, humans)
	Net.send_state(Game.get_state())
	Net.start_game()


func _go_world() -> void:
	if is_inside_tree():
		get_tree().change_scene_to_file("res://scenes/world.tscn")
