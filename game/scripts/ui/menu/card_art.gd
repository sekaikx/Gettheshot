class_name MenuCardArt
extends Control
## The picture on a How-to-play card, drawn in code like a coloured print on cream paper.
## Set `card` to one of: walk, shakedown, money, men, booze, heat, favors, rivals.

const INK := Color("1e140a")
const INK_SOFT := Color("54422e")
const PAPER := Color("efe6cf")
const OX := Color("8b1e1a")
const BRASS := Color("b08d57")
const FAMS := [Color("c42828"), Color("3c6ec8"), Color("3ca05a"), Color("d4a532")]

var card := "walk":
	set(v):
		card = v
		queue_redraw()


func _init() -> void:
	custom_minimum_size = Vector2(440, 330)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	Draw.rect(self, r, PAPER)
	# faint paper grain
	for k in 90:
		var p := Vector2(Draw.hash01(k, 1, 7) * size.x, Draw.hash01(k, 2, 7) * size.y)
		Draw.rect(self, Rect2(p, Vector2(2, 1)), Color(INK, 0.05))
	match card:
		"walk": _walk()
		"shakedown": _shakedown()
		"money": _money()
		"men": _men()
		"booze": _booze()
		"heat": _heat()
		"favors": _favors()
		"rivals": _rivals()
	# the printed frame
	draw_rect(r.grow(-1), INK, false, 2.0)
	draw_rect(r.grow(-6), Color(INK, 0.4), false, 1.0)


# ------------------------------------------------------------------ helpers

func _c() -> Vector2:
	return size * 0.5


## A person from above (the same idea as the street: shoulders, a hat).
func _person(p: Vector2, facing: float, suit: Color, hat: String, band: Color = Color(0, 0, 0, 0), s: float = 1.0) -> void:
	var t := Transform2D(facing, p)
	Draw.ellipse(self, p + Vector2(4, 5) * s, Vector2(15, 19) * s, Color(0, 0, 0, 0.18), facing)
	Draw.ellipse(self, p, Vector2(12, 18) * s, suit, facing)
	Draw.ellipse(self, t * (Vector2(4, 0) * s), Vector2(6, 8) * s, suit.lightened(0.08), facing)
	match hat:
		"fedora":
			Draw.circle(self, p, 11 * s, Color("2a2622"))
			draw_arc(p, 7.5 * s, 0, TAU, 24, band if band.a > 0 else Color("111"), 2.5 * s, true)
			Draw.circle(self, p, 6 * s, Color("3a342e"))
		"cap":
			Draw.circle(self, p, 8 * s, Color("5a4a3a"))
			Draw.ellipse(self, t * (Vector2(8, 0) * s), Vector2(5, 7) * s, Color("4a3a2e"), facing)
		"police":
			Draw.circle(self, p, 9.5 * s, Color("1c2638"))
			Draw.ellipse(self, t * (Vector2(8, 0) * s), Vector2(4, 7) * s, Color("0e1420"), facing)
			Draw.circle(self, p, 3 * s, Color("c9a54a"))
		_:
			Draw.circle(self, p, 7.5 * s, Color("e0b088"))
			Draw.circle(self, t * (Vector2(-2, 0) * s), 6.5 * s, Color("3a2a20"))


func _arrow(a: Vector2, b: Vector2, col: Color = INK, w: float = 3.0) -> void:
	draw_line(a, b, col, w, true)
	var d := (b - a).normalized()
	var n := Vector2(-d.y, d.x)
	Draw.poly(self, PackedVector2Array([b + d * 4, b - d * 12 + n * 8, b - d * 12 - n * 8]), col)


func _icon(name: String, c: Vector2, s: float, col: Color = INK) -> void:
	var t: Texture2D = UiKit.icon(name, 64 if s <= 64 else 128)
	if t:
		draw_texture_rect(t, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), false, col)


func _medal(c: Vector2, r: float, fill: Color, icon: String) -> void:
	Draw.circle(self, c + Vector2(2, 3), r, Color(0, 0, 0, 0.15))
	Draw.circle(self, c, r, fill)
	draw_arc(c, r - 5, 0, TAU, 40, Color(BRASS, 0.9), 1.5, true)
	_icon(icon, c, r * 1.15, PAPER)


func _text(p: Vector2, s: String, fs: int, col: Color = INK, font_name: String = "cond", width: float = -1.0) -> void:
	var f := W.ui_font(font_name)
	if width > 0:
		draw_string(f, Vector2(p.x - width * 0.5, p.y), s, HORIZONTAL_ALIGNMENT_CENTER, width, fs, col)
	else:
		draw_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _bubble_key(anchor: Vector2, key: String, words: String) -> void:
	var f := W.ui_font("semi")
	var tw := f.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
	var r := Rect2(anchor + Vector2(-(tw + 54) * 0.5, -52), Vector2(tw + 54, 40))
	Draw.rrect(self, Rect2(r.position + Vector2(2, 3), r.size), 8, Color(0, 0, 0, 0.18))
	Draw.rrect(self, r, 8, Color("fbf6ea"))
	draw_polyline(_loop(Draw.rrect_points(r, 8)), INK, 1.5, true)
	Draw.poly(self, PackedVector2Array([anchor + Vector2(-8, -13), anchor + Vector2(8, -13), anchor + Vector2(0, -3)]), Color("fbf6ea"))
	MenuWidgets.draw_key(self, Rect2(r.position + Vector2(7, 6), Vector2(28, 28)), key, 16)
	draw_string(f, r.position + Vector2(43, 26), words, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, INK)


func _loop(p: PackedVector2Array) -> PackedVector2Array:
	var q := p.duplicate()
	q.append(p[0])
	return q


func _sidewalk(y0: float, y1: float) -> void:
	Draw.rect(self, Rect2(8, y0, size.x - 16, y1 - y0), Color("c9bfae"))
	for x in range(8, int(size.x) - 8, 44):
		draw_line(Vector2(x, y0), Vector2(x, y1), Color(INK, 0.1), 1.0)
	draw_line(Vector2(8, (y0 + y1) * 0.5), Vector2(size.x - 8, (y0 + y1) * 0.5), Color(INK, 0.06), 1.0)
	Draw.rect(self, Rect2(8, y1 - 5, size.x - 16, 5), Color("ddd4c4"))
	draw_line(Vector2(8, y1), Vector2(size.x - 8, y1), Color(INK, 0.4), 2.0)


func _road(y0: float) -> void:
	Draw.rect(self, Rect2(8, y0, size.x - 16, size.y - 8 - y0), Color("4a4c52"))
	for x in range(30, int(size.x) - 20, 70):
		Draw.rect(self, Rect2(x, y0 + (size.y - 8 - y0) * 0.5 - 2, 34, 4), Color("d8d2c2", 0.5))


## A shop from above: tar roof with a parapet, a chimney and a skylight, and its striped
## awning over the sidewalk with the name on the valance.
func _shopfront(x: float, w: float, y: float, stripe: Color, sign_text: String) -> void:
	var roof := Rect2(x, 8, w, y - 22)
	Draw.rect(self, roof, Color("6e4636"))
	Draw.rect(self, roof.grow(-6), Color("3b3532"))
	for k in range(int(roof.position.y) + 14, int(roof.end.y) - 6, 12):
		draw_line(Vector2(roof.position.x + 6, k), Vector2(roof.end.x - 6, k), Color(0, 0, 0, 0.18), 1.0)
	Draw.rect(self, Rect2(x + w - 44, 20, 22, 18), Color("7a5242"))
	Draw.rect(self, Rect2(x + w - 40, 24, 14, 10), Color("2a2220"))
	Draw.rect(self, Rect2(x + 18, 24, 40, 28), Color("7f8f96"))
	draw_rect(Rect2(x + 18, 24, 40, 28), Color("4a3a30"), false, 2.0)
	draw_line(Vector2(x + 38, 24), Vector2(x + 38, 52), Color("4a3a30"), 1.5)
	# awning
	var ay := y - 14
	var n := maxi(4, int(w / 20))
	for k in n:
		Draw.rect(self, Rect2(x + k * w / n, ay, w / n + 0.5, 22), stripe if k % 2 == 0 else Color("efe6cf"))
	Draw.rect(self, Rect2(x, ay + 22, w, 14), stripe.darkened(0.2))
	_text(Vector2(x + w * 0.5, ay + 34), sign_text, 13, Color("f3e9d2"), "cond", w)
	Draw.rect(self, Rect2(x, ay + 36, w, 4), Color(0, 0, 0, 0.18))


# ------------------------------------------------------------------ the cards

func _walk() -> void:
	_shopfront(24, 230, 116, Color("7a2e2a"), "MULBERRY BAKERY")
	_shopfront(262, 154, 116, Color("2e4a3a"), "BARBER")
	_sidewalk(156, 250)
	_road(250)
	# the owner in his doorway, you walking up, your footsteps behind you
	_person(Vector2(130, 206), PI * 0.3, Color("e8e0d0"), "", Color(0, 0, 0, 0), 1.25)
	for k in 5:
		var fp := Vector2(370 - k * 34, 236 - k * 2)
		Draw.ellipse(self, fp + Vector2(0, -4), Vector2(5, 3), Color(INK, 0.2 - k * 0.03))
		Draw.ellipse(self, fp + Vector2(10, 4), Vector2(5, 3), Color(INK, 0.2 - k * 0.03))
	_person(Vector2(196, 226), -2.9, Color("25262b"), "fedora", Color("c42828"), 1.25)
	_bubble_key(Vector2(130, 194), "E", "Talk to the baker")
	# WASD
	var k0 := Vector2(size.x - 124, size.y - 50)
	MenuWidgets.draw_key(self, Rect2(k0 + Vector2(36, -34), Vector2(32, 30)), "W", 15)
	MenuWidgets.draw_key(self, Rect2(k0 + Vector2(0, 0), Vector2(32, 30)), "A", 15)
	MenuWidgets.draw_key(self, Rect2(k0 + Vector2(36, 0), Vector2(32, 30)), "S", 15)
	MenuWidgets.draw_key(self, Rect2(k0 + Vector2(72, 0), Vector2(32, 30)), "D", 15)
	_text(Vector2(24, size.y - 26), "Walk up and press E", 17, Color("efe6cf"), "semi")


func _shakedown() -> void:
	# the owner, scared
	var pr := Rect2(22, 22, 132, 164)
	Portrait.draw(self, pr, "shop", 4711, Color(0, 0, 0, 0), {"trade": "bakery"}, "scared")
	draw_rect(pr, INK, false, 2.0)
	# the fear bar with the mark
	var bx := 178.0
	_text(Vector2(bx, 50), "FEAR", 22, INK, "deco")
	var bar := Rect2(bx, 62, 238, 24)
	Draw.rect(self, bar, Color(INK, 0.1))
	Draw.hgrad(self, Rect2(bar.position, Vector2(bar.size.x * 0.6, bar.size.y)), Color("c07a3a"), OX)
	var mx := bar.position.x + bar.size.x * 0.7
	draw_line(Vector2(mx, bar.position.y - 7), Vector2(mx, bar.end.y + 7), INK, 3.0)
	draw_rect(bar, INK, false, 1.5)
	_arrow(Vector2(mx, bar.end.y + 34), Vector2(mx, bar.end.y + 12), INK, 2.0)
	_text(Vector2(mx, bar.end.y + 52), "HE PAYS", 15, INK, "cond", 80)
	_text(Vector2(bar.end.x - 22, bar.position.y - 8), "TOO FAR", 13, OX, "cond", 60)
	_text(Vector2(bx, 162), "“All right, all right!", 18, INK_SOFT, "fell")
	_text(Vector2(bx, 184), "I’ll pay. Just stop.”", 18, INK_SOFT, "fell")
	# his weak spot: one of these four
	draw_line(Vector2(22, 204), Vector2(size.x - 22, 204), Color(INK, 0.2), 1.0)
	_text(Vector2(size.x * 0.5, 226), "HIS WEAK SPOT IS ONE OF THESE", 15, INK_SOFT, "cond", size.x)
	var spots := [["crate", "His shop"], ["fedora", "A beating"], ["pistol", "Guns"], ["handshake", "Your men"]]
	var cw := (size.x - 40) / 4.0
	for k in 4:
		var c := Vector2(20 + cw * (k + 0.5), 262)
		_medal(c, 22, OX if k == 0 else INK, String(spots[k][0]))
		_text(Vector2(c.x, 306), String(spots[k][1]), 16, INK, "semi", cw)


func _money() -> void:
	var y := 140.0
	var xs := [76.0, size.x * 0.5, size.x - 76.0]
	var names := ["WALLET", "STASH", "BANK"]
	var subs := ["cash on you", "dirty, in your safe", "clean money"]
	var icons := ["banknotes", "money_bag", "ledger"]
	var cols := [Color("54422e"), OX, Color("2f4a38")]
	_text(Vector2(size.x * 0.5, 48), "THREE KINDS OF MONEY", 16, INK_SOFT, "cond", size.x)
	for k in 3:
		_medal(Vector2(xs[k], y), 42, cols[k], icons[k])
		_text(Vector2(xs[k], y + 76), names[k], 24, INK, "deco", 150)
		_text(Vector2(xs[k], y + 100), subs[k], 16, INK_SOFT, "sans", 150)
	_arrow(Vector2(xs[0] + 50, y), Vector2(xs[1] - 52, y), INK_SOFT, 2.5)
	_arrow(Vector2(xs[1] + 50, y), Vector2(xs[2] - 52, y), INK_SOFT, 2.5)
	draw_line(Vector2(40, size.y - 50), Vector2(size.x - 40, size.y - 50), Color(INK, 0.25), 1.0)
	_text(Vector2(size.x * 0.5, size.y - 22), "Only Bank money buys a business.", 18, INK, "semi", size.x)


func _men() -> void:
	var looks := [2201, 5310, 7702]
	var tags := ["BRUISER", "DRIVER", "TALKER"]
	for k in 3:
		var pr := Rect2(24 + k * 136, 26, 120, 160)
		Portrait.draw(self, pr, "crew", looks[k], FAMS[0], {}, "" if k != 0 else "smug")
		draw_rect(pr, INK, false, 2.0)
		var tr := Rect2(pr.position.x + 6, pr.end.y + 10, pr.size.x - 12, 30)
		Draw.rect(self, tr, INK)
		_text(Vector2(tr.get_center().x, tr.position.y + 21), String(tags[k]), 16, Color("efe6cf"), "cond", tr.size.x)
	_text(Vector2(size.x * 0.5, size.y - 50), "Every man is good at one thing.", 18, INK, "semi", size.x)
	_text(Vector2(size.x * 0.5, size.y - 24), "Bruiser · Shooter · Driver · Talker · Medic · Earner", 15, INK_SOFT, "sans", size.x)


func _booze() -> void:
	# the night route: the boat at the pier -> your truck -> your speakeasy
	Draw.vgrad(self, Rect2(8, 8, size.x - 16, size.y - 16), Color("1c2438"), Color("2e3a52"))
	for k in 34:
		var p := Vector2(8 + Draw.hash01(k, 3, 8) * (size.x - 16), 12 + Draw.hash01(k, 4, 8) * size.y * 0.4)
		Draw.circle(self, p, 1.1, Color(1, 1, 1, 0.35 + 0.3 * Draw.hash01(k, 5, 8)))
	Draw.circle(self, Vector2(size.x - 58, 50), 20, Color("e6e0cc"))
	Draw.circle(self, Vector2(size.x - 50, 44), 17, Color("1e2740"))
	# the river along the bottom
	Draw.rect(self, Rect2(8, size.y - 60, size.x - 16, 52), Color("142033"))
	for k in 12:
		var wy := size.y - 50 + (k % 3) * 14
		var wx := 20 + k * 36 + (k % 2) * 10
		draw_line(Vector2(wx, wy), Vector2(wx + 18, wy), Color(1, 1, 1, 0.18), 1.5)
	var pts := [Vector2(80, 170), Vector2(220, 170), Vector2(360, 170)]
	var icons := ["ship", "truck", "barrel"]
	var names := ["THE BOAT", "YOUR TRUCK", "YOUR SPEAKEASY"]
	for k in 2:
		Draw.dashed(self, pts[k] + Vector2(46, 0), pts[k + 1] - Vector2(50, 0), Color("f0d58a"), 3.0, 10, 7)
	for k in 3:
		_medal(pts[k], 40, OX if k == 2 else Color("1e140a"), icons[k])
		_text(Vector2(pts[k].x, pts[k].y + 66), names[k], 17, Color("f0d58a"), "cond", 140)
	_text(Vector2(size.x * 0.5, 64), "AT NIGHT  ·  THE MIDDLE PIER", 17, Color("efe6cf"), "cond", size.x)


func _heat() -> void:
	var pr := Rect2(22, 22, 140, 180)
	Portrait.draw(self, pr, "cop", 3131, Color(0, 0, 0, 0), {}, "")
	draw_rect(pr, INK, false, 2.0)
	_text(Vector2(pr.get_center().x, pr.end.y + 26), "ON THE PAYROLL", 15, INK, "cond", pr.size.x + 20)
	var bx := 190.0
	_text(Vector2(bx, 56), "HEAT", 22, INK, "deco")
	var bar := Rect2(bx, 70, 226, 26)
	Draw.rect(self, bar, Color(INK, 0.1))
	Draw.hgrad(self, Rect2(bar.position, Vector2(bar.size.x * 0.8, bar.size.y)), Color("d4a532"), OX)
	for k in 11:
		var x := bar.position.x + bar.size.x * k / 10.0
		draw_line(Vector2(x, bar.end.y), Vector2(x, bar.end.y + (8 if k % 5 == 0 else 4)), INK, 1.5)
	draw_rect(bar, INK, false, 1.5)
	_text(Vector2(bx, bar.end.y + 28), "0", 14, INK_SOFT)
	_text(Vector2(bar.end.x - 24, bar.end.y + 28), "100", 14, INK_SOFT)
	_medal(Vector2(bx + 34, 204), 32, OX, "badge")
	_text(Vector2(bx + 80, 198), "At 100 the feds", 19, INK, "semi")
	_text(Vector2(bx + 80, 222), "raid you.", 19, INK, "semi")
	draw_line(Vector2(22, 262), Vector2(size.x - 22, 262), Color(INK, 0.2), 1.0)
	_text(Vector2(size.x * 0.5, 296), "A cop on the payroll looks the other way.", 17, INK_SOFT, "semi", size.x)


func _favors() -> void:
	_shopfront(24, 220, 116, Color("8a6a2a"), "ROSSI TAILOR")
	_shopfront(252, 164, 116, Color("2a3a5a"), "CAFE")
	_sidewalk(156, 250)
	_road(250)
	# the "!" over the tailor's door
	var m := Vector2(134, 70)
	Draw.circle(self, m + Vector2(2, 3), 22, Color(0, 0, 0, 0.3))
	Draw.circle(self, m, 22, Color("d4a532"))
	draw_arc(m, 22, 0, TAU, 32, INK, 2.0, true)
	_text(Vector2(m.x, m.y + 12), "!", 32, INK, "deco", 40)
	_person(Vector2(134, 180), PI * 0.5, Color("e8e0d0"), "", Color(0, 0, 0, 0), 1.25)
	_person(Vector2(184, 218), -2.3, Color("25262b"), "fedora", Color("c42828"), 1.25)
	# two thugs from another family, leaning on him
	_person(Vector2(80, 214), -0.6, Color("3a3d45"), "cap", Color(0, 0, 0, 0), 1.2)
	_person(Vector2(52, 186), -0.2, Color("3a3d45"), "cap", Color(0, 0, 0, 0), 1.2)
	_text(Vector2(24, size.y - 24), "A shop with a problem", 17, Color("efe6cf"), "semi")
	_medal(Vector2(size.x - 50, size.y - 40), 24, OX, "handshake")


func _rivals() -> void:
	# the city in the families' colours, and a table for the sit-down
	var cols := 4
	var rows := 4
	var cw := 50.0
	var ch := 46.0
	var o := Vector2(26, 30)
	Draw.rect(self, Rect2(o - Vector2(6, 6), Vector2(cols * cw + 12, rows * ch + 12)), Color("5a5c62"))
	var own := [[0, 0, 1, 1], [0, -1, 1, 1], [3, 3, -1, 2], [3, 3, 2, 2]]
	for j in rows:
		for i in cols:
			var f: int = own[j][i]
			var c := Color("c9bfae") if f < 0 else (FAMS[f] as Color).lerp(Color("efe6cf"), 0.2)
			Draw.rect(self, Rect2(o + Vector2(i * cw + 5, j * ch + 5), Vector2(cw - 10, ch - 10)), c)
	_text(Vector2(o.x + cols * cw * 0.5, o.y + rows * ch + 30), "WHO HOLDS WHAT", 15, INK_SOFT, "cond", cols * cw)
	# the table: two dons, two glasses
	var tc := Vector2(size.x - 104, 118)
	Draw.circle(self, tc + Vector2(3, 4), 42, Color(0, 0, 0, 0.18))
	Draw.circle(self, tc, 42, Color("6a4a30"))
	draw_arc(tc, 37, 0, TAU, 40, Color("8a6a48"), 2.0, true)
	_person(tc + Vector2(-60, 0), 0.0, Color("25262b"), "fedora", FAMS[0], 1.3)
	_person(tc + Vector2(60, 0), PI, Color("2a3040"), "fedora", FAMS[1], 1.3)
	Draw.circle(self, tc + Vector2(-14, -8), 5, Color("e8dcc0"))
	Draw.circle(self, tc + Vector2(14, 8), 5, Color("e8dcc0"))
	_text(Vector2(tc.x, tc.y + 76), "THE SIT-DOWN", 16, INK, "cond", 170)
	draw_line(Vector2(22, 262), Vector2(size.x - 22, 262), Color(INK, 0.2), 1.0)
	_text(Vector2(size.x * 0.5, 292), "Truce  ·  Tribute  ·  Alliance", 19, INK, "semi", size.x)
	_text(Vector2(size.x * 0.5, 314), "or war", 15, OX, "cond", size.x)
