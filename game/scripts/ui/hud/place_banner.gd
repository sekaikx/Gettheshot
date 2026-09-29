extends Control
## Top-centre, when you walk into a place: its name in Art Deco letters between two brass rules,
## and one line under it ("Pays nobody", "Pays you $90 a month"). Stays 2.5 seconds.

const UI := preload("res://scripts/ui/hud/hud_ui.gd")
const LIFE := 2.5

var _title := ""
var _sub := ""
var _t := LIFE
var max_w := 640.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_place(title: String, sub: String) -> void:
	_title = title
	_sub = sub
	_t = 0.0
	queue_redraw()


func _process(delta: float) -> void:
	if _t < LIFE:
		_t += delta
		queue_redraw()


func _draw() -> void:
	if _t >= LIFE or _title == "":
		return
	var a := clampf(_t / 0.3, 0.0, 1.0) * clampf((LIFE - _t) / 0.6, 0.0, 1.0)
	var drop := (1.0 - clampf(_t / 0.35, 0.0, 1.0)) * -10.0
	var deco := UI.font("deco")
	var cond := UI.font("cond")
	var fs := 36
	var title := _title
	while fs > 22 and UI.tw(deco, title, fs) > max_w - 150.0:
		fs -= 2
	title = UI.fit(deco, title, fs, max_w - 150.0)
	var tw := UI.tw(deco, title, fs)
	var cx := size.x * 0.5
	var y := 50.0 + drop
	# a soft dark band behind, fading out at both ends
	var bw := tw + 260.0
	var band := Rect2(Vector2(cx - bw * 0.5, y - 40.0), Vector2(bw, 78.0))
	Draw.hgrad(self, Rect2(band.position, Vector2(bw * 0.5, band.size.y)), Color(0.05, 0.035, 0.025, 0.0), Color(0.05, 0.035, 0.025, 0.78 * a))
	Draw.hgrad(self, Rect2(band.position + Vector2(bw * 0.5, 0), Vector2(bw * 0.5, band.size.y)), Color(0.05, 0.035, 0.025, 0.78 * a), Color(0.05, 0.035, 0.025, 0.0))
	# the name
	UI.text_c(self, cx + 2.0, y + 2.5, title, deco, fs, Color(0, 0, 0, 0.6 * a))
	UI.text_c(self, cx, y, title, deco, fs, UI.with_a(UI.GOLD2, a))
	# brass rules either side, with a diamond at the outer end
	var ry := y - fs * 0.33
	var reach := 70.0 * clampf(_t / 0.45, 0.0, 1.0)
	for s in [-1.0, 1.0]:
		var x0: float = cx + s * (tw * 0.5 + 14.0)
		var x1: float = x0 + s * reach
		draw_line(Vector2(x0, ry), Vector2(x1, ry), UI.with_a(UI.BRASS, a), 1.5, true)
		draw_line(Vector2(x0, ry + 4.0), Vector2(x0 + s * reach * 0.7, ry + 4.0), UI.with_a(UI.BRASS, 0.5 * a), 1.0, true)
		Draw.poly(self, UI.diamond(Vector2(x1 + s * 4.0, ry + 1.0), 3.5), UI.with_a(UI.GOLD2, a))
	if _sub != "":
		var sub := UI.fit(cond, _sub.to_upper(), 17, max_w)
		UI.text_c(self, cx + 1.0, y + 27.0, sub, cond, 17, Color(0, 0, 0, 0.6 * a))
		UI.text_c(self, cx, y + 26.0, sub, cond, 17, UI.with_a(UI.INK, a))
