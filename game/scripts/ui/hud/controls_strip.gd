extends Control
## Bottom-left, tiny: the keys, as typewriter key caps. It fades out after a minute (press H for
## the full "How to play").

const UI := preload("res://scripts/ui/hud/hud_ui.gd")
const KEYS := [["E", "use"], ["F", "punch"], ["G", "shoot"], ["R", "send men"], ["V", "car"],
	["Tab", "family"], ["M", "map"], ["J", "country"], ["H", "help"]]
const SHOW := 60.0

var hold := false
var _t := 0.0
var _a := 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(760, 30)


## Show it again for a while (after "How to play" closes, for example).
func remind() -> void:
	_t = SHOW - 12.0


func strip_height() -> float:
	return 34.0 * _a


func strip_width() -> float:
	var sans := UI.font("sans")
	var x := 10.0
	for k in KEYS:
		x += UI.keycap_w(String(k[0]), 20.0) + 5.0 + UI.tw(sans, String(k[1]), 14) + 13.0
	return x


func _process(delta: float) -> void:
	_t += delta
	var want := 1.0 if (_t < SHOW and not hold) else 0.0
	var old := _a
	_a = move_toward(_a, want, delta * (0.5 if want < 1.0 and not hold else 4.0))
	if absf(_a - old) > 0.0001:
		queue_redraw()


func _draw() -> void:
	if _a <= 0.01:
		return
	var sans := UI.font("sans")
	var x := 10.0
	var widths: Array = []
	for k in KEYS:
		var kw := UI.keycap_w(String(k[0]), 20.0)
		widths.append(kw)
		x += kw + 5.0 + UI.tw(sans, String(k[1]), 14) + 13.0
	var r := Rect2(Vector2.ZERO, Vector2(x, 30))
	Draw.rrect(self, r, 8.0, Color(0.06, 0.045, 0.035, 0.72 * _a))
	UI.rrect_line(self, r, 8.0, UI.with_a(UI.BRASS_DK, 0.8 * _a), 1.0)
	x = 10.0
	for i in KEYS.size():
		var k: Array = KEYS[i]
		var kw: float = widths[i]
		UI.keycap(self, Rect2(Vector2(x, 5), Vector2(20, 20)), String(k[0]), _a)
		x += kw + 5.0
		UI.text(self, Vector2(x, UI.mid(sans, 14, 15.0)), String(k[1]), sans, 14, UI.with_a(UI.INK, 0.9 * _a))
		x += UI.tw(sans, String(k[1]), 14) + 13.0
