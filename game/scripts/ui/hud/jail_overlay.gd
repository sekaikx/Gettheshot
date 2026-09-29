extends Control
## While you're in a cell at the precinct: iron bars across the screen and a plaque with how long
## until you're out on bail. It doesn't block the other panels (the family book still works).

const UI := preload("res://scripts/ui/hud/hud_ui.gd")

var until := 0.0
var _a := 0.0
var _total := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	var left := until - Time.get_ticks_msec() / 1000.0
	if left > _total:
		_total = left
	var want := 1.0 if left > 0.0 else 0.0
	if want == 0.0:
		_total = 0.0
	_a = move_toward(_a, want, delta * 2.5)
	visible = _a > 0.01
	if visible:
		queue_redraw()


func _draw() -> void:
	var a := _a
	var left := maxf(0.0, until - Time.get_ticks_msec() / 1000.0)
	# a cold dark cell
	Draw.rect(self, Rect2(Vector2.ZERO, size), Color(0.03, 0.035, 0.05, 0.45 * a))
	var edge := 180.0
	Draw.hgrad(self, Rect2(Vector2.ZERO, Vector2(edge, size.y)), Color(0, 0, 0, 0.55 * a), Color(0, 0, 0, 0))
	Draw.hgrad(self, Rect2(Vector2(size.x - edge, 0), Vector2(edge, size.y)), Color(0, 0, 0, 0), Color(0, 0, 0, 0.55 * a))
	# the bars
	var step := 118.0
	var n := int(size.x / step) + 1
	var x0 := (size.x - (n - 1) * step) * 0.5
	var iron := Color("22252b")
	for k in n:
		var x := x0 + k * step
		Draw.rect(self, Rect2(Vector2(x - 11 + 6, 0), Vector2(22, size.y)), Color(0, 0, 0, 0.35 * a))
		Draw.hgrad(self, Rect2(Vector2(x - 11, 0), Vector2(11, size.y)), UI.with_a(iron.lightened(0.05), a), UI.with_a(iron.lightened(0.28), a))
		Draw.hgrad(self, Rect2(Vector2(x, 0), Vector2(11, size.y)), UI.with_a(iron.lightened(0.28), a), UI.with_a(iron.darkened(0.3), a))
		Draw.rect(self, Rect2(Vector2(x - 3, 0), Vector2(2, size.y)), Color(1, 1, 1, 0.07 * a))
	for y in [size.y * 0.16, size.y * 0.84]:
		var yy: float = y
		Draw.rect(self, Rect2(Vector2(0, yy - 12 + 6), Vector2(size.x, 26)), Color(0, 0, 0, 0.35 * a))
		Draw.vgrad(self, Rect2(Vector2(0, yy - 13), Vector2(size.x, 26)), UI.with_a(iron.lightened(0.3), a), UI.with_a(iron.darkened(0.25), a))
		for k in n:
			Draw.circle(self, Vector2(x0 + k * step, yy), 5.0, UI.with_a(iron.lightened(0.4), a))
	# the plaque
	var pw := 520.0
	var ph := 170.0
	var r := Rect2((size - Vector2(pw, ph)) * 0.5, Vector2(pw, ph))
	UI.panel(self, r, a, 8.0)
	var cond := UI.font("cond")
	var serif := UI.font("serif")
	var sans := UI.font("sans")
	var cx := r.get_center().x
	UI.text_c(self, cx, r.position.y + 38, "IN A CELL · 14TH PRECINCT", cond, 18, UI.with_a(UI.MUTE, a))
	var secs := ceili(left)
	UI.text_c(self, cx, r.position.y + 96, "%d:%02d" % [secs / 60, secs % 60], serif, 54, UI.with_a(UI.GOLD2, a))
	UI.text_c(self, cx, r.position.y + 128, "Your lawyer is getting you out on bail.", sans, 17, UI.with_a(UI.INK, a))
	var bar := Rect2(Vector2(r.position.x + 40, r.end.y - 26), Vector2(pw - 80, 6))
	Draw.rrect(self, bar, 3.0, UI.with_a(Color(0, 0, 0, 0.6), a))
	var k2 := 1.0 - (left / _total if _total > 0.0 else 0.0)
	Draw.rrect(self, Rect2(bar.position, Vector2(bar.size.x * clampf(k2, 0.0, 1.0), bar.size.y)), 3.0, UI.with_a(UI.GOLD, a))
