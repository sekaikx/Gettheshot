class_name Settings
extends RefCounted
## The player's settings, kept in user://settings.cfg (not in the campaign save).
##
##   Settings.load_and_apply()          once at start (the main menu does it)
##   Settings.get_value("music", 0.6)   read one
##   Settings.set_value("music", 0.4)   change one: applies it right away and saves the file
##
## Keys: master, music, sfx (volume 0..1), fullscreen (bool), ui_scale (0.8..1.4),
## show_controls (bool: the controls strip at the bottom of the street screen).
## Creates the "Music" and "SFX" audio buses (sent to Master) when they don't exist yet.

const PATH := "user://settings.cfg"
const SECTION := "settings"
const DEFAULTS := {"master": 0.8, "music": 0.6, "sfx": 0.8, "fullscreen": false, "ui_scale": 1.0,
	"show_controls": true}
const UI_SCALE_MIN := 0.8
const UI_SCALE_MAX := 1.4

static var _values: Dictionary = {}
static var _loaded := false


## Read the file (if any), create the audio buses and apply everything.
static func load_and_apply() -> void:
	_load()
	ensure_buses()
	apply_all()


static func get_value(key: String, default: Variant = null) -> Variant:
	_load()
	if _values.has(key):
		return _values[key]
	if default != null:
		return default
	return DEFAULTS.get(key)


## Change one setting: applied at once and saved.
static func set_value(key: String, value: Variant) -> void:
	_load()
	_values[key] = value
	_apply(key)
	save()


## Put every setting back to its default (and save).
static func reset() -> void:
	_load()
	_values = DEFAULTS.duplicate()
	apply_all()
	save()


static func save() -> void:
	var cf := ConfigFile.new()
	for k in _values:
		cf.set_value(SECTION, k, _values[k])
	cf.save(PATH)


static func apply_all() -> void:
	for k in DEFAULTS:
		_apply(k)


## "Music" and "SFX" buses feeding Master, created once.
static func ensure_buses() -> void:
	for bus_name in [&"Music", &"SFX"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, &"Master")


## Linear volume 0..1 -> decibels (0 is silent).
static func volume_db(v: float) -> float:
	return -80.0 if v <= 0.001 else linear_to_db(clampf(v, 0.0, 1.0))


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	_values = DEFAULTS.duplicate()
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return
	for k in DEFAULTS:
		var v: Variant = cf.get_value(SECTION, k, DEFAULTS[k])
		if typeof(v) == typeof(DEFAULTS[k]) or (typeof(v) in [TYPE_INT, TYPE_FLOAT] and typeof(DEFAULTS[k]) == TYPE_FLOAT):
			_values[k] = v


static func _apply(key: String) -> void:
	match key:
		"master": _bus_volume(&"Master", float(_values.get(key, 0.8)))
		"music": _bus_volume(&"Music", float(_values.get(key, 0.6)))
		"sfx": _bus_volume(&"SFX", float(_values.get(key, 0.8)))
		"fullscreen":
			if DisplayServer.get_name() == "headless":
				return
			var want := bool(_values.get(key, false))
			var mode := DisplayServer.window_get_mode()
			var is_full := mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
			if want and not is_full:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			elif not want and is_full:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		"ui_scale":
			var tree := Engine.get_main_loop() as SceneTree
			if tree and tree.root:
				tree.root.content_scale_factor = clampf(float(_values.get(key, 1.0)), UI_SCALE_MIN, UI_SCALE_MAX)


static func _bus_volume(bus_name: StringName, v: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, volume_db(v))
	AudioServer.set_bus_mute(idx, v <= 0.001)
