extends Node
## The city's sound: street murmur by day, rain, thunder, night music, a waltz from the clubs,
## punches, shots and breaking glass where they happen, the truck's engine.
## Rain, murmur, music, UI and fight sounds are the owner's own Woods / Keep Rolling audio;
## the gunshot, glass, engine and whistle are synthesised (tools/synth_audio.py).

const DIR := "res://assets/audio/"

var _murmur: AudioStreamPlayer
var _rain: AudioStreamPlayer
var _music: AudioStreamPlayer
var _engine: AudioStreamPlayer
var _thunder_t := 20.0
var _weather := "clear"
var _music_night := -1
var _cache := {}


func _ready() -> void:
	_murmur = _bed("murmur_loop", -14.0)
	_rain = _bed("rain_loop", -80.0)
	_music = AudioStreamPlayer.new()
	_music.volume_db = -20.0
	_music.bus = _music_bus()
	add_child(_music)
	_engine = _bed("engine", -80.0)


func _stream(name: String, loop: bool = false) -> AudioStream:
	var key := name + str(loop)
	if not _cache.has(key):
		var s := load(DIR + name + ".ogg") as AudioStream
		if s is AudioStreamOggVorbis and loop:
			s = s.duplicate()
			(s as AudioStreamOggVorbis).loop = true
		_cache[key] = s
	return _cache[key]


func _bed(name: String, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = _stream(name, true)
	p.volume_db = db
	p.bus = _sfx_bus()
	add_child(p)
	p.play()
	return p


func set_mood(night: float, weather: String) -> void:
	_murmur.volume_db = lerpf(-12.0, -30.0, night)
	_rain.volume_db = -8.0 if weather == "rain" else -80.0
	_weather = weather
	var want := 1 if night > 0.6 else 0
	if want != _music_night:
		_music_night = want
		_music.stream = _stream("night" if want == 1 else "evening", true)
		_music.volume_db = -19.0 if want == 1 else -24.0
		_music.play()


func _process(delta: float) -> void:
	if _weather == "rain":
		_thunder_t -= delta
		if _thunder_t <= 0.0:
			_thunder_t = randf_range(25.0, 60.0)
			ui("thunder_0%d" % (1 + randi() % 2), -6.0)


func engine(on: bool) -> void:
	_engine.volume_db = -10.0 if on else -80.0


func ui(name: String, db: float = -6.0) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = _stream(name)
	p.volume_db = db
	p.bus = _sfx_bus()
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


func at(kind: String, pos: Vector2) -> void:
	var name := ""
	var db := 0.0
	var dist := 30.0
	match kind:
		"hit": name = ["hh_hit_1", "hh_hit_2"][randi() % 2]
		"punch": name = ["hh_swish_1", "hh_swish_2"][randi() % 2]; db = -6.0
		"shoot": name = "gunshot"; db = 6.0; dist = 90.0
		"smash": name = "glass"; db = 0.0; dist = 45.0
		"down", "die": name = "hh_hurt"
		"cheer": name = "coin"; db = -8.0
		"whistle": name = "whistle"; dist = 60.0
		"door": name = "click_wood"; db = -10.0; dist = 20.0
		"cash": name = "coins_pay"; db = -6.0; dist = 20.0
	if name == "":
		return
	var p := AudioStreamPlayer2D.new()
	p.stream = _stream(name)
	p.volume_db = db
	p.max_distance = dist * W.M
	p.attenuation = 1.6
	p.bus = _sfx_bus()
	add_child(p)
	p.global_position = pos
	p.play()
	p.finished.connect(p.queue_free)


func _sfx_bus() -> StringName:
	return &"SFX" if AudioServer.get_bus_index(&"SFX") >= 0 else &"Master"


func _music_bus() -> StringName:
	return &"Music" if AudioServer.get_bus_index(&"Music") >= 0 else &"Master"
