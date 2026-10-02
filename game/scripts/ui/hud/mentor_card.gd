extends Control
## Bottom-left: Uncle Carmine (the tutorial mentor) talks to you while you play. His portrait,
## his name and his line typed out; it doesn't stop you, and it fades after a few seconds. It steps
## aside while a conversation is open and comes back after.

const UI := preload("res://scripts/ui/hud/hud_ui.gd")
const W_CARD := 560.0
const H_AREA := 200.0
const PORT := 96.0

var who := ""
var line := ""
var portrait := {}
var hold := false                 # a conversation is open: hide, and pause the clock
var _lines := PackedStringArray()
var _total := 0
var _chars := 0.0
var _cps := 60.0
var _left := 0.0
var _secs := 8.0
var _a := 0.0
var _h := 130.0
var _pview: Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(W_CARD, H_AREA)
	modulate.a = 0.0
	_pview = Control.new()
	_pview.clip_contents = true
	_pview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pview.size = Vector2(PORT, PORT)
	_pview.draw.connect(_draw_portrait)
	add_child(_pview)


func say(name: String, text: String, p: Dictionary, seconds: float) -> void:
	who = name
	line = text if text.begins_with("\"") else "\"%s\"" % text
	portrait = p
	_lines = UI.wrap(UI.font("sans"), line, 18, W_CARD - PORT - 60.0, 5)
	_total = 0
	for l in _lines:
		_total += l.length()
	_cps = maxf(55.0, _total / 1.6)
	_chars = 0.0
	_secs = maxf(seconds, 2.0)
	_left = _secs
	_h = maxf(PORT + 32.0, 58.0 + _lines.size() * 23.0 + 16.0)
	_pview.queue_redraw()
	queue_redraw()


func is_showing() -> bool:
	return _a > 0.01


func _process(delta: float) -> void:
	var want := _left > 0.0 and not hold
	if want:
		_left -= delta
		_chars = minf(float(_total), _chars + _cps * delta)
	var old := _a
	_a = move_toward(_a, 1.0 if want else 0.0, delta * (4.0 if want else 2.5))
	modulate.a = _a
	visible = _a > 0.0
	if want or _a != old:
		queue_redraw()
	var off := (1.0 - _a) * 20.0
	_pview.position = Vector2(-off + 16.0, H_AREA - _h + 16.0)


## Where the card is on screen (the edge arrows keep clear of it).
func card_rect() -> Rect2:
	return Rect2(position + _card().position, _card().size)


func _card() -> Rect2:
	return Rect2(Vector2(-(1.0 - _a) * 20.0, H_AREA - _h), Vector2(W_CARD, _h))


func _draw() -> void:
	if who == "":
		return
	var r := _card()
	UI.panel(self, r, 1.0, 8.0)
	# the brass frame (the portrait is drawn clipped inside it by _pview)
	var pr := Rect2(r.position + Vector2(16, 16), Vector2(PORT, PORT))
	Draw.rect(self, pr.grow(4.0), UI.BRASS_DK)
	UI.grad_rrect(self, pr.grow(3.0), 1.0, UI.BRASS_HI, UI.BRASS)
	Draw.rect(self, pr.grow(1.0), Color("120c09"))
	var x := pr.end.x + 20.0
	var serif := UI.font("serif")
	var sans := UI.font("sans")
	var cond := UI.font("cond")
	UI.text(self, Vector2(x, r.position.y + 40), who, serif, 21, UI.GOLD2)
	if String(portrait.get("kind", "")) == "consigliere":
		UI.text(self, Vector2(x + UI.tw(serif, who, 21) + 12, r.position.y + 39), "YOUR FATHER'S CONSIGLIERE", cond, 15, UI.with_a(UI.MUTE, 0.85))
	var left := int(_chars)
	var y := r.position.y + 66.0
	for l in _lines:
		if left <= 0:
			break
		UI.text(self, Vector2(x, y), l.left(left), sans, 18, UI.INK)
		left -= l.length()
		y += 23.0
	# how long it stays: a thin gold line that runs out
	var k := clampf(_left / _secs, 0.0, 1.0)
	Draw.rect(self, Rect2(Vector2(x, r.end.y - 12), Vector2((r.end.x - 20 - x) * k, 2)), UI.with_a(UI.GOLD, 0.6))


func _draw_portrait() -> void:
	var pr := Rect2(Vector2.ZERO, _pview.size)
	if portrait.is_empty():
		Draw.rect(_pview, pr, Color("241912"))
		return
	var col: Color = portrait.get("color") if portrait.get("color") is Color else Color(0, 0, 0, 0)
	var ex: Dictionary = portrait.get("extra") if portrait.get("extra") is Dictionary else {}
	Portrait.draw(_pview, pr, String(portrait.get("kind", "consigliere")), int(portrait.get("look", 0)), col, ex, "")
