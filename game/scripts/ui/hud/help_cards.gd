extends Control
## How to play (H, or the pause menu): eight short cards, each with a little drawn scene and a few
## plain lines. No wall of text. Esc, H or a click on "Close" puts it away.

signal closed

const UI := preload("res://scripts/ui/hud/hud_ui.gd")
const CARDS := [
	["walk", "Walk & talk", ["WASD to walk, Shift to run.", "Walk up to anyone and press E to talk.", "Walk into shops: the roof lifts off."]],
	["shake", "Shakedowns", ["Offer a shop protection.", "He says no? Break his things (F) or rough him up.", "Stop at the mark on his FEAR bar. Too far and he runs to the cops.", "Every owner has a weak spot. Ask around."]],
	["money", "Wallet, Stash, Bank", ["Wallet: cash on you. Lost if you're knocked down.", "Stash: dirty money in your club's safe.", "Bank: clean money. Only Bank money buys shops.", "Shops you own wash Stash into Bank each month."]],
	["men", "Your men", ["Hire men at the pool hall.", "Each has a specialty: Bruiser, Shooter, Driver, Talker, Medic or Earner.", "Talk to a man to give him orders.", "R sends your men at the man you face."]],
	["booze", "Booze & speakeasies", ["Open a speakeasy in the back of a shop you own.", "At night a boat ties up at the middle pier.", "Buy crates, load the truck (V to drive) and bring them in."]],
	["heat", "Heat & the law", ["Every crime people see adds Heat.", "Pay cops and captains to look away.", "Silence witnesses. Throw guns in the river.", "Full Heat: the feds raid your club."]],
	["favor", "Favors", ["A gold ! over a door: the owner needs help.", "Do the favor and he pays you. No smashing needed.", "Favors run out at the end of the month."]],
	["rivals", "Rivals & sit-downs", ["Other families want your streets.", "Visit a Don at his club: a truce, tribute, an alliance.", "Their offers ring the phone at your club (or press Tab)."]],
]

var world: Node
var _a := 0.0
var _hover := -1
var _close := Rect2()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false


func open() -> void:
	_a = 0.0
	visible = true
	UI.sound(world, "page_turn", -10.0)
	queue_redraw()


func _process(delta: float) -> void:
	if visible and _a < 1.0:
		_a = move_toward(_a, 1.0, delta * 5.0)
		queue_redraw()


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		var h := 1 if _close.has_point((e as InputEventMouseMotion).position) else -1
		if h != _hover:
			_hover = h
			queue_redraw()
	elif e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
		accept_event()
		if (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and _close.has_point((e as InputEventMouseButton).position):
			closed.emit()


func _draw() -> void:
	var a := _a
	Draw.rect(self, Rect2(Vector2.ZERO, size), Color(0.035, 0.026, 0.02, 0.9 * a))
	var deco := UI.font("deco")
	var sans := UI.font("sans")
	var cond := UI.font("cond")
	var cx := size.x * 0.5
	UI.text_c(self, cx + 2, 64, "HOW TO PLAY", deco, 42, Color(0, 0, 0, 0.5 * a))
	UI.text_c(self, cx, 62, "HOW TO PLAY", deco, 42, UI.with_a(UI.GOLD2, a))
	UI.text_c(self, cx, 94, "Run the family. Take the city one shop at a time. The richest family when Prohibition ends wins.", sans, 17, UI.with_a(UI.INK, a))
	UI.rule(self, Vector2(cx - 260, 110), Vector2(cx + 260, 110), UI.with_a(UI.BRASS, 0.6 * a))
	# close
	var kw := UI.keycap_w("Esc", 24.0)
	var ctext := "CLOSE"
	_close = Rect2(Vector2(size.x - 56 - kw - 16 - UI.tw(cond, ctext, 16) - 18, 36), Vector2(kw + 16 + UI.tw(cond, ctext, 16) + 18, 40))
	UI.grad_rrect(self, _close, 6.0, UI.with_a(Color("5a4226") if _hover == 1 else Color("2a1d15"), a), UI.with_a(Color("150e0a"), a))
	UI.rrect_line(self, _close, 6.0, UI.with_a(UI.BRASS, a), 1.5)
	UI.keycap(self, Rect2(_close.position + Vector2(9, 8), Vector2(24, 24)), "Esc", a)
	UI.text(self, Vector2(_close.position.x + 9 + kw + 10, UI.mid(cond, 16, _close.get_center().y)), ctext, cond, 16, UI.with_a(UI.INK, a))
	# the cards, 4 x 2
	var margin := 56.0
	var gap := 18.0
	var top := 132.0
	var cw := (size.x - margin * 2.0 - gap * 3.0) / 4.0
	var ch := minf(360.0, (size.y - top - 40.0 - gap) / 2.0)
	for i in CARDS.size():
		var col := i % 4
		var row := i / 4
		var k := clampf(a * 1.6 - i * 0.07, 0.0, 1.0)
		var r := Rect2(Vector2(margin + col * (cw + gap), top + row * (ch + gap) + (1.0 - k) * 16.0), Vector2(cw, ch))
		_card(r, i, k * a)


func _card(r: Rect2, i: int, a: float) -> void:
	var card: Array = CARDS[i]
	UI.panel(self, r, a, 8.0)
	var pic := Rect2(r.position + Vector2(14, 14), Vector2(r.size.x - 28, minf(132.0, r.size.y * 0.38)))
	UI.grad_rrect(self, pic, 5.0, UI.with_a(Color("2c2621"), a), UI.with_a(Color("191512"), a))
	_scene(String(card[0]), pic, a)
	UI.rrect_line(self, pic, 5.0, UI.with_a(UI.BRASS_DK, a), 1.5)
	# number and title
	var n := Vector2(r.position.x + 30, pic.end.y + 30)
	Draw.circle(self, n, 13.0, UI.with_a(UI.BRASS_DK, a))
	Draw.circle(self, n, 11.5, UI.with_a(Color("241912"), a))
	var cond := UI.font("cond")
	UI.text_c(self, n.x, UI.mid(cond, 15, n.y), str(i + 1), cond, 15, UI.with_a(UI.GOLD2, a))
	var serif := UI.font("serif")
	UI.text(self, Vector2(r.position.x + 52, n.y + 8), UI.fit(serif, String(card[1]), 21, r.size.x - 66), serif, 21, UI.with_a(UI.GOLD2, a))
	var sans := UI.font("sans")
	var y := n.y + 34.0
	var lw := r.size.x - 48.0
	for line in card[2]:
		var ls := UI.wrap(sans, String(line), 15, lw)
		Draw.poly(self, UI.diamond(Vector2(r.position.x + 22, y - 5), 2.5), UI.with_a(UI.GOLD, a))
		for l in ls:
			if y > r.end.y - 12.0:
				break
			UI.text(self, Vector2(r.position.x + 32, y), l, sans, 15, UI.with_a(UI.INK, a))
			y += 18.0
		y += 5.0


# ------------------------------------------------------------------ the little scenes

func _fedora(c: Vector2, s: float, band: Color, a: float) -> void:
	# a man from above: shoulders in a dark suit, a fedora with a band in the family colour
	Draw.ellipse(self, c + Vector2(3, 4), Vector2(s * 1.45, s * 0.8), Color(0, 0, 0, 0.35 * a))
	Draw.ellipse(self, c + Vector2(0, 1), Vector2(s * 1.45, s * 0.78), UI.with_a(Color("2f2a26"), a))
	Draw.circle(self, c, s * 0.92, UI.with_a(Color("1d1e22"), a))
	Draw.circle(self, c, s * 0.6, UI.with_a(band, a))
	Draw.circle(self, c, s * 0.5, UI.with_a(Color("34363c"), a))
	Draw.ellipse(self, c + Vector2(0, -s * 0.06), Vector2(s * 0.14, s * 0.36), UI.with_a(Color("222327"), a))


func _scene(kind: String, r: Rect2, a: float) -> void:
	var c := r.get_center()
	var mine := UI.fam_col(UI.my_family())
	match kind:
		"walk":
			# a sidewalk, a shop door, you and the owner
			Draw.rect(self, Rect2(Vector2(r.position.x, c.y + 10), Vector2(r.size.x, r.end.y - c.y - 12)), UI.with_a(Pal.SIDEWALK.darkened(0.35), a))
			Draw.rect(self, Rect2(Vector2(r.position.x + r.size.x * 0.52, r.position.y + 4), Vector2(r.size.x * 0.46, c.y + 6 - r.position.y)), UI.with_a(Pal.FLOOR_WOOD.darkened(0.2), a))
			Draw.rect(self, Rect2(Vector2(r.position.x + r.size.x * 0.52, c.y + 4), Vector2(r.size.x * 0.46, 8)), UI.with_a(Pal.AWNING_COLORS[0], a))
			_fedora(Vector2(c.x - 6, c.y + 32), 13.0, mine, a)
			Draw.circle(self, Vector2(c.x + 70, c.y - 26), 12.0, UI.with_a(Color("e9e3d4"), a))
			Draw.circle(self, Vector2(c.x + 70, c.y - 26), 7.0, UI.with_a(Color("5a4436"), a))
			Draw.rrect(self, Rect2(Vector2(c.x + 88, c.y - 58), Vector2(52, 30)), 8.0, UI.with_a(UI.CREAM, a))
			Draw.poly(self, PackedVector2Array([Vector2(c.x + 94, c.y - 30), Vector2(c.x + 86, c.y - 20), Vector2(c.x + 104, c.y - 30)]), UI.with_a(UI.CREAM, a))
			for k in 3:
				Draw.circle(self, Vector2(c.x + 104 + k * 10, c.y - 43), 2.5, UI.with_a(UI.PAPER_INK, a))
			var kx := r.position.x + 18.0
			var ky := r.position.y + 18.0
			UI.keycap(self, Rect2(Vector2(kx + 30, ky), Vector2(26, 26)), "W", a)
			UI.keycap(self, Rect2(Vector2(kx, ky + 30), Vector2(26, 26)), "A", a)
			UI.keycap(self, Rect2(Vector2(kx + 30, ky + 30), Vector2(26, 26)), "S", a)
			UI.keycap(self, Rect2(Vector2(kx + 60, ky + 30), Vector2(26, 26)), "D", a)
			UI.keycap(self, Rect2(Vector2(c.x + 22, c.y - 4), Vector2(26, 26)), "E", a, true)
		"shake":
			Draw.rect(self, Rect2(Vector2(r.position.x + 14, c.y - 6), Vector2(r.size.x * 0.5, 22)), UI.with_a(Pal.COUNTER, a))
			# a smashed jar: glass everywhere, apples rolling off the counter
			var jc := Vector2(r.position.x + r.size.x * 0.42, c.y + 34)
			for k in 6:
				var ang := TAU * k / 6.0 + 0.4
				var d := Vector2.from_angle(ang)
				var p0 := jc + d * (8.0 + Draw.hash01(k, 3, 9) * 14.0)
				Draw.poly(self, PackedVector2Array([p0, p0 + d.rotated(0.9) * 9.0, p0 + d * 12.0 + d.orthogonal() * 3.0, p0 + d.rotated(-0.7) * 6.0]), UI.with_a(Pal.GLASS.lightened(0.25), 0.85 * a))
			for k in 4:
				var ap := Vector2(r.position.x + 40 + k * 26.0, c.y + 30 + (k % 2) * 12.0)
				Draw.circle(self, ap, 6.0, UI.with_a(Color("b0302a"), a))
				Draw.circle(self, ap + Vector2(-2, -2), 2.0, UI.with_a(Color("e07060"), a))
			UI.icon(self, "fist", Vector2(r.position.x + r.size.x * 0.3, c.y - 36), 34.0, UI.with_a(UI.INK, a), Color("2c2621"))
			# the fear bar
			var bar := Rect2(Vector2(r.position.x + r.size.x * 0.58, c.y - 4), Vector2(r.size.x * 0.36, 12))
			var cond := UI.font("cond")
			UI.text(self, bar.position + Vector2(0, -12), "FEAR", cond, 14, UI.with_a(UI.INK, a))
			Draw.rrect(self, bar.grow(2), 4.0, UI.with_a(Color(0, 0, 0, 0.7), a))
			UI.grad_rrect(self, Rect2(bar.position, Vector2(bar.size.x * 0.62, bar.size.y)), 3.0, UI.with_a(Pal.UI_RED.lightened(0.2), a), UI.with_a(Pal.UI_RED.darkened(0.3), a))
			var mx := bar.position.x + bar.size.x * 0.7
			draw_line(Vector2(mx, bar.position.y - 5), Vector2(mx, bar.end.y + 5), UI.with_a(UI.GOLD2, a), 2.0, true)
			UI.text_c(self, mx, bar.end.y + 20, "HE PAYS", cond, 14, UI.with_a(UI.GOLD2, a))
		"money":
			var xs := [r.position.x + r.size.x * 0.17, c.x, r.end.x - r.size.x * 0.17]
			var ics := ["wallet", "safe", "bank"]
			var labs := ["WALLET", "STASH", "BANK"]
			var cond2 := UI.font("cond")
			for k in 3:
				var p := Vector2(float(xs[k]), c.y - 10)
				Draw.circle(self, p, 30.0, UI.with_a(Color(0, 0, 0, 0.35), a))
				UI.icon(self, String(ics[k]), p, 40.0, UI.with_a(UI.GOLD2 if k == 0 else UI.BRASS, a), Color("2c2621"))
				UI.text_c(self, p.x, c.y + 44, String(labs[k]), cond2, 15, UI.with_a(UI.INK, a))
				if k < 2:
					var q0 := Vector2(p.x + 38, c.y - 10)
					var q1 := Vector2(float(xs[k + 1]) - 38, c.y - 10)
					Draw.dashed(self, q0, q1, UI.with_a(UI.MUTE, a), 2.0, 6.0, 5.0)
					Draw.poly(self, PackedVector2Array([q1 + Vector2(6, 0), q1 + Vector2(-2, -5), q1 + Vector2(-2, 5)]), UI.with_a(UI.MUTE, a))
		"men":
			var traits := ["fist", "gun", "car"]
			for k in 3:
				var p := Vector2(c.x + (k - 1) * 84, c.y + 16)
				_fedora(p, 20.0, mine, a)
				Draw.circle(self, p + Vector2(0, -50), 17.0, UI.with_a(Color(0, 0, 0, 0.4), a))
				UI.icon(self, String(traits[k]), p + Vector2(0, -50), 24.0, UI.with_a(UI.GOLD2, a), Color("2c2621"))
		"booze":
			Draw.rect(self, Rect2(Vector2(r.end.x - r.size.x * 0.3, r.position.y + 2), Vector2(r.size.x * 0.3 - 2, r.size.y - 4)), UI.with_a(Pal.WATER, a))
			for k in 5:
				Draw.rect(self, Rect2(Vector2(r.end.x - r.size.x * 0.3 - 60 + k * 12, c.y - 16), Vector2(10, 34)), UI.with_a(Pal.PLANKS.lightened(0.05 * (k % 2)), a))
			UI.icon(self, "boat", Vector2(r.end.x - r.size.x * 0.15, c.y), 46.0, UI.with_a(Color("d8d0bc"), a), Pal.WATER)
			for k in 4:
				Draw.rect(self, Rect2(Vector2(c.x - 30 + (k % 2) * 16, c.y - 6 - (k / 2) * 16), Vector2(14, 14)), UI.with_a(Color("8a6a44"), a), true)
			UI.icon(self, "truck", Vector2(r.position.x + 58, c.y + 8), 60.0, UI.with_a(mine.lightened(0.2), a), Color("2c2621"))
			UI.icon(self, "booze", Vector2(r.position.x + 58, c.y - 40), 30.0, UI.with_a(UI.GOLD2, a), Color("2c2621"))
		"heat":
			UI.icon(self, "badge", Vector2(r.position.x + 62, c.y), 76.0, UI.with_a(Color("f07a3a"), a), Color("2c2621"))
			var x := r.position.x + 120.0
			for k in 5:
				var sr := Rect2(Vector2(x + k * 34, c.y - 8), Vector2(29, 16))
				Draw.rrect(self, sr.grow(1.5), 3.0, UI.with_a(Color(0, 0, 0, 0.6), a))
				var lit := k < 4
				Draw.rrect(self, sr, 3.0, UI.with_a(([Color("e8b04a"), Color("e8b04a"), Color("f07a3a"), Color("f07a3a"), Color("ff4a3a")][k] as Color) if lit else Color(1, 1, 1, 0.08), a))
			var cond3 := UI.font("cond")
			UI.text(self, Vector2(x, c.y - 20), "HEAT · HOT", cond3, 16, UI.with_a(Color("f07a3a"), a))
			UI.text(self, Vector2(x, c.y + 34), "At the end: a federal raid.", UI.font("sans"), 14, UI.with_a(UI.MUTE, a))
		"favor":
			var shop := Rect2(Vector2(c.x - 70, r.position.y + 22), Vector2(140, r.size.y - 44))
			Draw.rect(self, shop, UI.with_a(Pal.BRICK, a))
			Draw.rect(self, Rect2(Vector2(shop.position.x - 8, shop.end.y - 44), Vector2(shop.size.x + 16, 14)), UI.with_a(Pal.AWNING_COLORS[1], a))
			for k in 6:
				Draw.rect(self, Rect2(Vector2(shop.position.x - 8 + k * 26, shop.end.y - 44), Vector2(13, 14)), UI.with_a(Pal.AWNING_CREAM, a))
			Draw.rect(self, Rect2(Vector2(c.x - 14, shop.end.y - 30), Vector2(28, 30)), UI.with_a(Color("2a1a10"), a))
			var bob := sin(Time.get_ticks_msec() / 260.0) * 3.0
			var fp := Vector2(c.x, shop.position.y + 26 + bob)
			Draw.circle(self, fp + Vector2(2, 3), 20.0, Color(0, 0, 0, 0.35 * a))
			Draw.circle(self, fp, 20.0, UI.with_a(UI.GOLD2, a))
			var serif := UI.font("serif")
			UI.text_c(self, fp.x, UI.mid(serif, 28, fp.y), "!", serif, 28, UI.with_a(UI.PAPER_INK, a))
		"rivals":
			var other := UI.fam_col(1 if UI.my_family() != 1 else 0)
			UI.crest(self, Vector2(r.position.x + 64, c.y), 34.0, mine, UI.fam_name(UI.my_family()).left(1), a)
			UI.crest(self, Vector2(r.end.x - 64, c.y), 34.0, other, UI.fam_name(1 if UI.my_family() != 1 else 0).left(1), a)
			UI.icon(self, "deal", Vector2(c.x, c.y - 8), 40.0, UI.with_a(UI.CREAM, a), Color("2c2621"))
			UI.icon(self, "phone", Vector2(c.x, c.y + 42), 22.0, UI.with_a(UI.GOLD2, a), Color("2c2621"))
