extends Control
## December 1933, Prohibition is over: who ran New York. The winning family big, with its crest,
## then every family ranked by legacy (Game.legacy) with a bar. Keep playing, or back to the menu.

signal action(id: String)

const UI := preload("res://scripts/ui/hud/hud_ui.gd")

var world: Node
var _ranks: Array = []
var _a := 0.0
var _sel := 0
var _buttons: Array = []   # [Rect2, id, text]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false


func open() -> void:
	_ranks = Game.families.duplicate()
	_ranks.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return Game.legacy(int(a["id"])) > Game.legacy(int(b["id"])))
	_a = 0.0
	_sel = 0
	visible = true
	UI.sound(world, "discover", -6.0)
	queue_redraw()


func key(k: int) -> void:
	match k:
		KEY_LEFT, KEY_A, KEY_UP, KEY_W:
			_sel = 0
		KEY_RIGHT, KEY_D, KEY_DOWN, KEY_S:
			_sel = 1
		KEY_1:
			action.emit("keep")
		KEY_2:
			action.emit("menu")
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			action.emit("keep" if _sel == 0 else "menu")
	queue_redraw()


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		for b in _buttons:
			if (b[0] as Rect2).has_point((e as InputEventMouseMotion).position):
				var s := 0 if String(b[1]) == "keep" else 1
				if s != _sel:
					_sel = s
					queue_redraw()
	elif e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		for b in _buttons:
			if (b[0] as Rect2).has_point((e as InputEventMouseButton).position):
				action.emit(String(b[1]))


func _process(delta: float) -> void:
	if visible and _a < 1.0:
		_a = move_toward(_a, 1.0, delta * 2.0)
		queue_redraw()


func _draw() -> void:
	if _ranks.is_empty():
		return
	var a := _a
	Draw.rect(self, Rect2(Vector2.ZERO, size), Color(0.02, 0.015, 0.01, 0.82 * a))
	var n := _ranks.size()
	var pw := minf(860.0, size.x - 100.0)
	var ph := minf(size.y - 60.0, 330.0 + n * 46.0 + 90.0)
	var r := Rect2((size - Vector2(pw, ph)) * 0.5 + Vector2(0, (1.0 - a) * 30.0), Vector2(pw, ph))
	UI.panel(self, r, a, 10.0)
	var deco := UI.font("deco")
	var cond := UI.font("cond")
	var serif := UI.font("serif")
	var sans := UI.font("sans")
	var semi := UI.font("semi")
	var cx := r.get_center().x
	UI.text_c(self, cx, r.position.y + 44, "DECEMBER 1933 · PROHIBITION IS OVER", cond, 18, UI.with_a(UI.MUTE, a))
	var win: Dictionary = _ranks[0]
	var wc := Color(String(win["color"]))
	UI.crest(self, Vector2(cx, r.position.y + 118), 50.0, wc, String(win["name"]).left(1).to_upper(), a)
	var me := UI.my_family()
	var wtitle := "The %s family runs New York" % win["name"]
	UI.text_c(self, cx + 2, r.position.y + 218, wtitle, deco, 40, Color(0, 0, 0, 0.5 * a))
	UI.text_c(self, cx, r.position.y + 216, wtitle, deco, 40, UI.with_a(UI.GOLD2, a))
	var sub := "That's you. Your father would be proud." if int(win["id"]) == me else "Your family came in %s." % _ordinal(_rank_of(me) + 1)
	UI.text_c(self, cx, r.position.y + 248, sub, sans, 18, UI.with_a(UI.INK, a))
	UI.rule(self, Vector2(r.position.x + 60, r.position.y + 272), Vector2(r.end.x - 60, r.position.y + 272), UI.with_a(UI.BRASS, 0.6 * a))
	var top := float(maxi(Game.legacy(int(win["id"])), 1))
	var y := r.position.y + 300.0
	for k in n:
		var f: Dictionary = _ranks[k]
		var fid := int(f["id"])
		var col := Color(String(f["color"]))
		var lg := Game.legacy(fid)
		var row := Rect2(Vector2(r.position.x + 50, y), Vector2(pw - 100, 38))
		if fid == me:
			UI.grad_rrect(self, row, 5.0, UI.with_a(Color("4a3622"), 0.7 * a), UI.with_a(Color("2a1d12"), 0.7 * a))
		UI.text(self, Vector2(row.position.x + 12, UI.mid(serif, 22, row.get_center().y)), "%d." % (k + 1), serif, 22, UI.with_a(UI.GOLD2 if k == 0 else UI.MUTE, a))
		Draw.circle(self, Vector2(row.position.x + 58, row.get_center().y), 9.0, UI.with_a(col, a))
		draw_arc(Vector2(row.position.x + 58, row.get_center().y), 9.0, 0, TAU, 20, UI.with_a(UI.BRASS, a), 1.5, true)
		var label := "The %s family%s" % [f["name"], "  (you)" if fid == me else ""]
		UI.text(self, Vector2(row.position.x + 78, UI.mid(semi, 19, row.get_center().y)), label, semi, 19, UI.with_a(UI.INK, a))
		var bx := row.position.x + 330.0
		var bw := row.end.x - bx - 110.0
		var br := Rect2(Vector2(bx, row.get_center().y - 6), Vector2(bw, 12))
		Draw.rrect(self, br, 4.0, UI.with_a(Color(0, 0, 0, 0.5), a))
		var k2 := clampf(float(maxi(lg, 0)) / top, 0.0, 1.0) * clampf(a * 1.5 - 0.3, 0.0, 1.0)
		if k2 > 0.0:
			UI.grad_rrect(self, Rect2(br.position, Vector2(bw * k2, 12)), 4.0, UI.with_a(col.lightened(0.25), a), UI.with_a(col.darkened(0.2), a))
		UI.text_r(self, row.end.x - 10, UI.mid(semi, 18, row.get_center().y), "$" + W.money(lg), semi, 18, UI.with_a(UI.INK, a))
		y += 46.0
	# buttons
	_buttons.clear()
	var bw2 := 250.0
	var by := r.end.y - 70.0
	var items := [["keep", "Keep playing", "1"], ["menu", "Back to the menu", "2"]]
	for i in 2:
		var br2 := Rect2(Vector2(cx - bw2 - 10 + i * (bw2 + 20), by), Vector2(bw2, 48))
		var on := i == _sel
		UI.grad_rrect(self, br2, 6.0, UI.with_a(Color("6a4e2a") if on else Color("2a1d15"), a), UI.with_a(Color("3a2a1a") if on else Color("150e0a"), a))
		UI.rrect_line(self, br2, 6.0, UI.with_a(UI.BRASS if on else UI.BRASS_DK, a), 1.5)
		UI.keycap(self, Rect2(br2.position + Vector2(12, 12), Vector2(24, 24)), String(items[i][2]), a, on)
		UI.text(self, Vector2(br2.position.x + 48, UI.mid(semi, 19, br2.get_center().y)), String(items[i][1]), semi, 19, UI.with_a(UI.INK, a))
		_buttons.append([br2, String(items[i][0]), String(items[i][1])])


func _rank_of(fid: int) -> int:
	for k in _ranks.size():
		if int(_ranks[k]["id"]) == fid:
			return k
	return 0


static func _ordinal(n: int) -> String:
	var suf := "th"
	if n % 100 < 11 or n % 100 > 13:
		suf = {1: "st", 2: "nd", 3: "rd"}.get(n % 10, "th")
	return "%d%s" % [n, suf]
