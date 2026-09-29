extends RefCounted
## Settings the pause menu changes: master, music and effects volume (0..1), full screen.
## If the game has a Settings class (res://scripts/core/settings.gd, the main menu's) with
## get_value(key) / set_value(key, value), it is used, so both menus share one file. Otherwise
## this keeps them itself in user://settings.cfg ([audio] master music sfx, [video] fullscreen).

const PATH := "user://settings.cfg"
const SETTINGS := "res://scripts/core/settings.gd"
const BUSES := {"master": &"Master", "music": &"Music", "sfx": &"SFX"}

static var _cfg: ConfigFile


static func _ext() -> Script:
	if not ResourceLoader.exists(SETTINGS):
		return null
	var s := load(SETTINGS) as Script
	if s == null:
		return null
	var names := []
	for m in s.get_script_method_list():
		names.append(String(m["name"]))
	return s if names.has("get_value") and names.has("set_value") else null


static func _file() -> ConfigFile:
	if _cfg == null:
		_cfg = ConfigFile.new()
		_cfg.load(PATH)
	return _cfg


static func _section(key: String) -> String:
	return "video" if key == "fullscreen" else "audio"


static func get_value(key: String, fallback: Variant) -> Variant:
	var ext := _ext()
	if ext:
		var v: Variant = ext.call("get_value", key)
		return fallback if v == null else v
	return _file().get_value(_section(key), key, fallback)


static func set_value(key: String, v: Variant) -> void:
	var ext := _ext()
	if ext:
		ext.call("set_value", key, v)
		for m in ["save", "apply"]:
			for info in ext.get_script_method_list():
				if String(info["name"]) == m:
					ext.call(m)
					break
	else:
		_file().set_value(_section(key), key, v)
		_file().save(PATH)
	apply(key)


static func has_bus(key: String) -> bool:
	return AudioServer.get_bus_index(BUSES.get(key, &"Master")) >= 0


static func volume(key: String) -> float:
	return clampf(float(get_value(key, 1.0 if key == "master" else 0.8)), 0.0, 1.0)


static func fullscreen() -> bool:
	var m := DisplayServer.window_get_mode()
	return m == DisplayServer.WINDOW_MODE_FULLSCREEN or m == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


static func apply(key: String) -> void:
	if key == "fullscreen":
		var on := bool(get_value("fullscreen", false))
		if DisplayServer.get_name() != "headless" and on != fullscreen():
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)
		return
	var idx := AudioServer.get_bus_index(BUSES.get(key, &"Master"))
	if idx < 0:
		return
	var v := volume(key)
	AudioServer.set_bus_mute(idx, v <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.001)))


## At the start of a game, when there is no shared Settings class: the saved volumes.
static func apply_saved_audio() -> void:
	if _ext() != null:
		return
	for k in BUSES:
		if _file().has_section_key("audio", k):
			apply(k)
