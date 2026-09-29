class_name MenuSettings
extends VBoxContainer
## The Settings page: volumes, full screen, text size, the controls strip. Every change is
## applied and saved at once (Settings.set_value). Built for the cream menu panel; the HUD's pause
## menu can reuse it as it is.

var _sliders := {}
var _values := {}
var _switches := {}
var _ui_scale: HSlider
var _ui_label: Label
var _ui_dragging := false
var _tick: AudioStreamPlayer


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	_tick = AudioStreamPlayer.new()
	_tick.stream = load("res://assets/audio/tick.ogg") if ResourceLoader.exists("res://assets/audio/tick.ogg") else null
	_tick.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") >= 0 else &"Master"
	add_child(_tick)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 14)
	add_child(grid)
	_section(grid, "Sound")
	_volume_row(grid, "master", "Everything")
	_volume_row(grid, "music", "Music")
	_volume_row(grid, "sfx", "Sound effects")
	_section(grid, "Screen")
	_switch_row(grid, "fullscreen", "Full screen", "")
	_scale_row(grid)
	_switch_row(grid, "show_controls", "Show the keys", "A strip of keys, bottom left, in the street.")


func _section(grid: GridContainer, title: String) -> void:
	var l := MenuStyle.caption(title, MenuStyle.OXBLOOD)
	l.add_theme_font_size_override("font_size", 16)
	var top := MarginContainer.new()
	top.add_theme_constant_override("margin_top", 6 if grid.get_child_count() > 0 else 0)
	top.add_child(l)
	grid.add_child(top)
	for k in 2:
		var s := Control.new()
		grid.add_child(s)


func _name_label(text: String) -> Label:
	var l := MenuStyle.label(text, "semi", 21, MenuStyle.INK)
	l.custom_minimum_size = Vector2(230, 0)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l


func _value_label() -> Label:
	var l := MenuStyle.label("", "cond", 21, MenuStyle.INK_SOFT)
	l.custom_minimum_size = Vector2(64, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l


func _volume_row(grid: GridContainer, key: String, text: String) -> void:
	grid.add_child(_name_label(text))
	var s := MenuStyle.slider(float(Settings.get_value(key)) * 100.0, 0, 100, 5)
	s.custom_minimum_size.x = 340
	var v := _value_label()
	s.value_changed.connect(func(x: float) -> void:
		Settings.set_value(key, x / 100.0)
		v.text = _pct(x)
		if key != "music" and _tick.stream and is_visible_in_tree():
			_tick.play())
	grid.add_child(s)
	v.text = _pct(s.value)
	grid.add_child(v)
	_sliders[key] = s
	_values[key] = v


func _pct(x: float) -> String:
	return "Off" if x <= 0.5 else "%d%%" % int(round(x))


func _switch_row(grid: GridContainer, key: String, text: String, hint: String) -> void:
	var name_box := VBoxContainer.new()
	name_box.add_theme_constant_override("separation", 0)
	name_box.alignment = BoxContainer.ALIGNMENT_CENTER
	name_box.add_child(_name_label(text))
	if hint != "":
		var h := MenuStyle.body(hint, 15, MenuStyle.INK_SOFT)
		h.custom_minimum_size = Vector2(230, 0)
		name_box.add_child(h)
	grid.add_child(name_box)
	var sw := MenuWidgets.Switch.new(bool(Settings.get_value(key)))
	sw.toggled.connect(func(on: bool) -> void: Settings.set_value(key, on))
	grid.add_child(sw)
	grid.add_child(Control.new())
	_switches[key] = sw


func _scale_row(grid: GridContainer) -> void:
	grid.add_child(_name_label("Text and menu size"))
	var s := MenuStyle.slider(float(Settings.get_value("ui_scale")) * 100.0, Settings.UI_SCALE_MIN * 100.0, Settings.UI_SCALE_MAX * 100.0, 10)
	s.custom_minimum_size.x = 340
	var v := _value_label()
	# apply when the drag ends (the whole screen changes size); keys apply at once
	s.drag_started.connect(func() -> void: _ui_dragging = true)
	s.drag_ended.connect(func(_changed: bool) -> void:
		_ui_dragging = false
		Settings.set_value("ui_scale", s.value / 100.0))
	s.value_changed.connect(func(x: float) -> void:
		v.text = "%d%%" % int(round(x))
		if not _ui_dragging:
			Settings.set_value("ui_scale", x / 100.0))
	grid.add_child(s)
	v.text = "%d%%" % int(round(s.value))
	grid.add_child(v)
	_ui_scale = s
	_ui_label = v


## Put everything back to the defaults and show it.
func reset() -> void:
	Settings.reset()
	refresh()


## Re-read every control from Settings (without re-saving).
func refresh() -> void:
	for k in _sliders:
		(_sliders[k] as HSlider).set_value_no_signal(float(Settings.get_value(k)) * 100.0)
		(_values[k] as Label).text = _pct((_sliders[k] as HSlider).value)
	for k in _switches:
		(_switches[k] as Button).set_pressed_no_signal(bool(Settings.get_value(k)))
		(_switches[k] as Button).queue_redraw()
	if _ui_scale:
		_ui_scale.set_value_no_signal(float(Settings.get_value("ui_scale")) * 100.0)
		_ui_label.text = "%d%%" % int(round(_ui_scale.value))


func first_focus() -> Control:
	return _sliders.get("master")
