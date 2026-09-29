extends RefCounted
## The HUD's look, shared by every piece in scripts/ui/hud/: 1929 New York. Lacquered wood panels
## with a double brass rule and Art Deco corners, cream key caps, drawn icons, Pal colours and the
## W.ui_font() faces. Everything is drawn in code (no textures), so it stays crisp at any size.
##
##   UI.panel(ci, rect)                    wood panel, brass rule, deco corners, soft shadow
##   UI.keycap(ci, rect, "E")              a cream typewriter key
##   UI.icon(ci, "money", center, size, colour)   see ICONS
##   UI.text / text_c / text_r             baseline text, left / centred / right
##   UI.wrap(font, text, size, width)      word wrap into lines (no layout jumps while typing)

const INK := Pal.INK
const MUTE := Pal.MUTE
const GOLD := Pal.GOLD
const GOLD2 := Pal.GOLD2
const BRASS := Pal.BRASS
const BRASS_DK := Color("6e5424")
const BRASS_HI := Color("f6e2a4")
const WOOD_TOP := Color("2e2017")
const WOOD_BOT := Color("150e0a")
const WOOD_HI := Color("4a3222")
const RED := Pal.UI_RED
const GREEN := Pal.UI_GREEN
const OXBLOOD := Color("8b2a24")
const PAPER := Pal.PAPER
const PAPER_INK := Pal.PAPER_INK
const CREAM := Color("efe4c8")
const NAVY := Color("24365c")
const SHADE := Color(0, 0, 0, 0.5)

## Every icon UI.icon() draws.
const ICONS := ["talk", "money", "fist", "gun", "leave", "crew", "buy", "booze", "badge", "deal", "info", "good",
	"bad", "warn", "safe", "bank", "wallet", "ammo", "phone", "car", "cross", "flag", "star", "sun", "moon",
	"rain", "fog", "boat", "map", "book", "gear", "help", "door", "check", "truck", "clock", "news"]


static func font(name: String) -> Font:
	return W.ui_font(name)


static func tw(f: Font, s: String, size: int) -> float:
	return f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


## Baseline for text of this size centred on y = cy.
static func mid(f: Font, size: int, cy: float) -> float:
	return cy + (f.get_ascent(size) - f.get_descent(size)) * 0.5


static func text(ci: CanvasItem, pos: Vector2, s: String, f: Font, size: int, col: Color) -> void:
	ci.draw_string(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


static func text_c(ci: CanvasItem, cx: float, baseline: float, s: String, f: Font, size: int, col: Color) -> void:
	ci.draw_string(f, Vector2(cx - tw(f, s, size) * 0.5, baseline), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


static func text_r(ci: CanvasItem, rx: float, baseline: float, s: String, f: Font, size: int, col: Color) -> void:
	ci.draw_string(f, Vector2(rx - tw(f, s, size), baseline), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


## Text with a soft dark drop shadow (for text straight over the street).
static func text_sh(ci: CanvasItem, pos: Vector2, s: String, f: Font, size: int, col: Color, sh: float = 0.75) -> void:
	ci.draw_string_outline(f, pos + Vector2(0, 1.5), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, Color(0, 0, 0, sh * col.a * 0.6))
	ci.draw_string(f, pos + Vector2(1, 2), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, sh * col.a))
	ci.draw_string(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


## The string cut to fit `width`, with an ellipsis.
static func fit(f: Font, s: String, size: int, width: float) -> String:
	if tw(f, s, size) <= width:
		return s
	var lo := 0
	var hi := s.length()
	while lo < hi:
		var m := (lo + hi + 1) / 2
		if tw(f, s.left(m).strip_edges() + "…", size) <= width:
			lo = m
		else:
			hi = m - 1
	return s.left(lo).strip_edges() + "…"


## Greedy word wrap. Lines never change while a typewriter reveals them.
static func wrap(f: Font, s: String, size: int, width: float, max_lines: int = 0) -> PackedStringArray:
	var out := PackedStringArray()
	for para in s.split("\n"):
		var line := ""
		for word in para.split(" ", false):
			var cand := word if line == "" else line + " " + word
			if tw(f, cand, size) <= width or line == "":
				line = cand
			else:
				out.append(line)
				line = word
		out.append(line)
	if max_lines > 0 and out.size() > max_lines:
		var cut := out.slice(0, max_lines)
		cut[max_lines - 1] = fit(f, cut[max_lines - 1] + " " + out[max_lines], size, width)
		if not cut[max_lines - 1].ends_with("…"):
			cut[max_lines - 1] = fit(f, cut[max_lines - 1] + "…", size, width)
		return cut
	return out


static func with_a(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, c.a * a)


# ------------------------------------------------------------------ shapes

## A rounded rectangle filled with a vertical gradient.
static func grad_rrect(ci: CanvasItem, r: Rect2, radius: float, top: Color, bottom: Color) -> void:
	var pts := Draw.rrect_points(r, radius, 5)
	var cols := PackedColorArray()
	cols.resize(pts.size())
	for k in pts.size():
		cols[k] = top.lerp(bottom, clampf((pts[k].y - r.position.y) / maxf(r.size.y, 1.0), 0.0, 1.0))
	ci.draw_polygon(pts, cols)


static func rrect_line(ci: CanvasItem, r: Rect2, radius: float, col: Color, width: float = 1.0) -> void:
	var pts := Draw.rrect_points(r, radius, 5)
	pts.append(pts[0])
	ci.draw_polyline(pts, col, width, true)


## A soft drop shadow under a rounded rectangle (light from the upper left).
static func soft_shadow(ci: CanvasItem, r: Rect2, radius: float, a: float = 1.0, off: Vector2 = Vector2(3, 6)) -> void:
	for k in 5:
		var g := 1.0 + k * 2.6
		Draw.rrect(ci, Rect2(r.position + off, r.size).grow(g), radius + g, Color(0, 0, 0, 0.09 * a))


## The standard HUD panel: soft shadow, lacquered wood, a double brass rule, deco corners.
static func panel(ci: CanvasItem, r: Rect2, a: float = 1.0, radius: float = 7.0, corners: bool = true) -> void:
	soft_shadow(ci, r, radius, a)
	grad_rrect(ci, r, radius, with_a(WOOD_TOP, 0.97 * a), with_a(WOOD_BOT, 0.97 * a))
	# a faint lacquer sheen along the top
	grad_rrect(ci, Rect2(r.position + Vector2(3, 2), Vector2(r.size.x - 6, minf(r.size.y * 0.4, 26.0))), radius - 2,
		Color(1, 0.9, 0.7, 0.06 * a), Color(1, 0.9, 0.7, 0.0))
	rrect_line(ci, r, radius, with_a(BRASS_DK, a), 2.0)
	rrect_line(ci, r.grow(-4.0), maxf(radius - 3.0, 2.0), with_a(BRASS, 0.42 * a), 1.0)
	if corners:
		deco_corners(ci, r.grow(-4.0), with_a(BRASS, 0.9 * a))


## Stepped Art Deco corner marks and a small diamond at each corner of `r`.
static func deco_corners(ci: CanvasItem, r: Rect2, col: Color, l: float = 13.0) -> void:
	var pts := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	var dirs := [Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1), Vector2(1, -1)]
	for k in 4:
		var p: Vector2 = pts[k]
		var d: Vector2 = dirs[k]
		var q := p + d * 3.0
		ci.draw_polyline(PackedVector2Array([q + Vector2(0, l * d.y), q, q + Vector2(l * d.x, 0)]), col, 1.5, true)
		var q2 := p + d * 6.5
		ci.draw_polyline(PackedVector2Array([q2 + Vector2(0, (l - 7.0) * d.y), q2, q2 + Vector2((l - 7.0) * d.x, 0)]), with_a(col, 0.6), 1.0, true)
		Draw.poly(ci, diamond(p + d * 10.5, 2.0), col)


static func diamond(c: Vector2, r: float) -> PackedVector2Array:
	return PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])


## A horizontal brass rule with a diamond in the middle.
static func rule(ci: CanvasItem, a: Vector2, b: Vector2, col: Color, gem: bool = true) -> void:
	ci.draw_line(a, b, col, 1.0, true)
	if gem:
		var m := (a + b) * 0.5
		Draw.poly(ci, diamond(m, 3.5), col)


## A cream typewriter key with a label. Returns its width (it grows to fit the label).
static func keycap(ci: CanvasItem, r: Rect2, label: String, a: float = 1.0, lit: bool = false) -> float:
	var f := font("cond")
	var fs := int(clampf(r.size.y * 0.56, 10.0, 26.0))
	var w := maxf(r.size.x, tw(f, label, fs) + r.size.y * 0.55)
	var rr := Rect2(r.position, Vector2(w, r.size.y))
	var rad := minf(5.0, r.size.y * 0.22)
	Draw.rrect(ci, Rect2(rr.position + Vector2(0, 2.0), rr.size), rad, Color(0, 0, 0, 0.45 * a))
	Draw.rrect(ci, Rect2(rr.position + Vector2(0, 1.0), rr.size), rad, with_a(Color("9a8a68"), a))
	var top := Rect2(rr.position, rr.size - Vector2(0, 2.0))
	grad_rrect(ci, top, rad, with_a(Color("fbf3dc") if not lit else BRASS_HI, a), with_a(Color("d9cba6") if not lit else GOLD, a))
	rrect_line(ci, top, rad, with_a(Color("6b5a3c"), 0.8 * a), 1.0)
	text_c(ci, top.get_center().x, mid(f, fs, top.get_center().y), label, f, fs, with_a(PAPER_INK, a))
	return w


static func keycap_w(label: String, h: float) -> float:
	var f := font("cond")
	var fs := int(clampf(h * 0.56, 10.0, 26.0))
	return maxf(h, tw(f, label, fs) + h * 0.55)


## A family crest: the initial in a disc of the family colour, a brass ring and a deco sunburst.
static func crest(ci: CanvasItem, c: Vector2, r: float, col: Color, initial: String, a: float = 1.0) -> void:
	for k in 24:
		var ang := TAU * k / 24.0 - PI * 0.5
		var long := k % 2 == 0
		var d := Vector2.from_angle(ang)
		ci.draw_line(c + d * (r + 1.0), c + d * (r + (7.0 if long else 4.0) * r / 40.0), with_a(BRASS, (0.9 if long else 0.55) * a), 1.5 if long else 1.0, true)
	Draw.circle(ci, c + Vector2(2, 3), r, Color(0, 0, 0, 0.4 * a))
	Draw.circle(ci, c, r, with_a(BRASS_DK, a))
	Draw.circle(ci, c, r - 1.5, with_a(BRASS, a))
	Draw.circle(ci, c, r - 4.0, with_a(BRASS_DK, a))
	var fc := col if col.a > 0.0 else Color("5e5850")
	Draw.circle(ci, c, r - 5.5, with_a(fc.darkened(0.25), a))
	Draw.circle(ci, c + Vector2(-r * 0.12, -r * 0.14), r - 9.0, with_a(fc, a))
	ci.draw_arc(c, r - 8.0, 0, TAU, 48, with_a(BRASS_HI, 0.35 * a), 1.0, true)
	var f := font("deco")
	var fs := int(r * 1.05)
	var base := mid(f, fs, c.y)
	text_c(ci, c.x + 1.0, base + 2.0, initial, f, fs, Color(0, 0, 0, 0.45 * a))
	text_c(ci, c.x, base, initial, f, fs, with_a(CREAM, a))


# ------------------------------------------------------------------ icons

static func _pts(c: Vector2, u: float, xy: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	var k := 0
	while k + 1 < xy.size():
		out.append(c + Vector2(float(xy[k]), float(xy[k + 1])) * u)
		k += 2
	return out


static func _r(c: Vector2, u: float, x: float, y: float, w: float, h: float) -> Rect2:
	return Rect2(c + Vector2(x, y) * u, Vector2(w, h) * u)


## A drawn icon, `s` pixels across, centred on `c`. `bg` fills the cut-outs (dots, bands, holes).
static func icon(ci: CanvasItem, name: String, c: Vector2, s: float, col: Color, bg: Color = Color(0.08, 0.06, 0.05, 0.9)) -> void:
	var u := s / 24.0
	var lw := maxf(1.2, 2.0 * u)
	bg = Color(bg.r, bg.g, bg.b, bg.a * col.a)
	match name:
		"talk":
			Draw.rrect(ci, _r(c, u, -10, -9, 20, 14), 4.5 * u, col)
			Draw.poly(ci, _pts(c, u, [-6, 4, -8, 10, 1, 4]), col)
			for k in 3:
				Draw.circle(ci, c + Vector2(-5.0 + k * 5.0, -2.0) * u, 1.7 * u, bg)
		"money":
			Draw.circle(ci, c, 10.5 * u, col)
			ci.draw_arc(c, 8.0 * u, 0, TAU, 32, bg, maxf(1.0, 1.2 * u), true)
			var f := font("cond")
			var fs := int(maxf(8.0, 13.0 * u))
			text_c(ci, c.x, mid(f, fs, c.y), "$", f, fs, bg)
		"fist":
			Draw.rrect(ci, _r(c, u, -8, -8, 16, 12), 3.5 * u, col)
			Draw.rrect(ci, _r(c, u, -9, 1, 12, 5), 2.5 * u, col)
			Draw.rrect(ci, _r(c, u, -5, 4, 11, 8), 2.0 * u, col)
			for k in 3:
				var x := -4.0 + k * 4.0
				ci.draw_line(c + Vector2(x, -8) * u, c + Vector2(x, -2) * u, bg, maxf(1.0, 1.3 * u), true)
			ci.draw_line(c + Vector2(-9, 1) * u, c + Vector2(2, 1) * u, bg, maxf(1.0, 1.2 * u), true)
		"gun":
			Draw.rect(ci, _r(c, u, -3, -6.5, 14, 4), col, true)
			Draw.rrect(ci, _r(c, u, -7, -7.5, 7, 7), 1.5 * u, col)
			Draw.poly(ci, _pts(c, u, [-8, -1, -2, -1, -3, 9, -9.5, 9]), col)
			Draw.poly(ci, _pts(c, u, [-9, -8, -6, -9.5, -5, -7]), col)
			ci.draw_arc(c + Vector2(-0.5, -0.5) * u, 3.0 * u, 0.1, PI * 0.9, 10, col, lw * 0.7, true)
			Draw.circle(ci, c + Vector2(-3.5, -4) * u, 1.2 * u, bg)
		"leave", "door":
			var fr := _r(c, u, -9, -10, 12, 20)
			ci.draw_rect(fr, col, false, lw, true)
			Draw.poly(ci, _pts(c, u, [-9, -10, -3, -8, -3, 12, -9, 10]), col)
			if name == "leave":
				ci.draw_line(c + Vector2(0, 0) * u, c + Vector2(9, 0) * u, col, lw, true)
				Draw.poly(ci, _pts(c, u, [11, 0, 6, -4.5, 6, 4.5]), col)
			else:
				Draw.circle(ci, c + Vector2(-4.5, 1) * u, 1.0 * u, bg)
		"crew":
			Draw.ellipse(ci, c + Vector2(0, 4) * u, Vector2(11.5, 3.6) * u, col)
			Draw.poly(ci, _pts(c, u, [-6.5, 4, -5.5, -5, -2, -8, 0, -6.5, 2, -8, 5.5, -5, 6.5, 4]), col)
			Draw.rect(ci, _r(c, u, -6.3, 0, 12.6, 2.4), bg)
		"buy":
			Draw.rect(ci, _r(c, u, -9, -1, 18, 11), col, true)
			Draw.poly(ci, _pts(c, u, [-11, -1, 11, -1, 9, -8, -9, -8]), col)
			for k in 4:
				ci.draw_line(c + Vector2(-7.5 + k * 5.0, -8) * u, c + Vector2(-8.0 + k * 5.3, -1) * u, bg, maxf(1.0, 1.2 * u), true)
			Draw.rect(ci, _r(c, u, -2.5, 3, 5, 7), bg)
			Draw.rect(ci, _r(c, u, -7.5, 2, 3.5, 3.5), bg)
			Draw.rect(ci, _r(c, u, 4, 2, 3.5, 3.5), bg)
		"booze":
			Draw.rrect(ci, _r(c, u, -4.5, -3, 9, 14), 2.0 * u, col)
			Draw.poly(ci, _pts(c, u, [-4.5, -2, 4.5, -2, 2, -6.5, -2, -6.5]), col)
			Draw.rect(ci, _r(c, u, -1.6, -11, 3.2, 5), col, true)
			Draw.rect(ci, _r(c, u, -4.5, 1.5, 9, 4.5), bg)
		"badge":
			var sh := _pts(c, u, [0, -11, 3, -9, 8, -9.5, 9, -4, 7, 3, 0, 11, -7, 3, -9, -4, -8, -9.5, -3, -9])
			Draw.poly(ci, sh, col)
			_star(ci, c + Vector2(0, -0.5) * u, 5.0 * u, bg)
		"deal":
			Draw.poly(ci, _pts(c, u, [-8, -11, 6, -11, 8, -9, 8, 10, -8, 10]), col)
			for k in 4:
				ci.draw_line(c + Vector2(-5, -6 + k * 3.2) * u, c + Vector2(5.0 - (2.0 if k == 3 else 0.0), -6 + k * 3.2) * u, bg, maxf(1.0, 1.1 * u), true)
			Draw.circle(ci, c + Vector2(4.5, 6.5) * u, 4.2 * u, OXBLOOD if col.a > 0.5 else bg)
			ci.draw_arc(c + Vector2(4.5, 6.5) * u, 4.2 * u, 0, TAU, 20, bg, maxf(1.0, 0.9 * u), true)
		"info":
			Draw.circle(ci, c, 10.5 * u, col)
			Draw.circle(ci, c + Vector2(0, -5) * u, 1.6 * u, bg)
			Draw.rect(ci, _r(c, u, -1.4, -2, 2.8, 8.5), bg)
		"good", "check":
			ci.draw_polyline(_pts(c, u, [-9, 0, -3, 7, 10, -8]), col, maxf(2.0, 3.2 * u), true)
		"bad":
			ci.draw_line(c + Vector2(-8, -8) * u, c + Vector2(8, 8) * u, col, maxf(2.0, 3.2 * u), true)
			ci.draw_line(c + Vector2(8, -8) * u, c + Vector2(-8, 8) * u, col, maxf(2.0, 3.2 * u), true)
		"warn":
			Draw.poly(ci, _pts(c, u, [0, -11, 11, 9, -11, 9]), col)
			Draw.rect(ci, _r(c, u, -1.3, -4, 2.6, 7.5), bg)
			Draw.circle(ci, c + Vector2(0, 6) * u, 1.5 * u, bg)
		"safe":
			Draw.rrect(ci, _r(c, u, -9.5, -9.5, 19, 17), 2.0 * u, col)
			Draw.rect(ci, _r(c, u, -8, 7.5, 3, 2.5), col)
			Draw.rect(ci, _r(c, u, 5, 7.5, 3, 2.5), col)
			ci.draw_arc(c + Vector2(1.5, -1) * u, 4.5 * u, 0, TAU, 20, bg, maxf(1.0, 1.4 * u), true)
			ci.draw_line(c + Vector2(1.5, -1) * u, c + Vector2(1.5, -4.5) * u, bg, maxf(1.0, 1.3 * u), true)
			Draw.rect(ci, _r(c, u, -8, -6, 1.6, 3), bg)
			Draw.rect(ci, _r(c, u, -8, 1, 1.6, 3), bg)
		"bank":
			Draw.poly(ci, _pts(c, u, [-11.5, -4, 0, -10.5, 11.5, -4]), col)
			Draw.rect(ci, _r(c, u, -11, 7, 22, 3), col)
			Draw.rect(ci, _r(c, u, -10, -3.5, 20, 1.8), col)
			for k in 4:
				Draw.rect(ci, _r(c, u, -8.5 + k * 5.2, -1.5, 2.6, 8.5), col)
		"wallet":
			Draw.rrect(ci, _r(c, u, -10.5, -6, 21, 14), 3.0 * u, col)
			Draw.rect(ci, _r(c, u, -7, -9, 12, 4), col.darkened(0.25))
			ci.draw_line(c + Vector2(-10.5, -2) * u, c + Vector2(10.5, -2) * u, bg, maxf(1.0, 1.1 * u), true)
			Draw.rrect(ci, _r(c, u, 4, 0, 6.5, 5), 1.5 * u, bg)
			Draw.circle(ci, c + Vector2(7, 2.5) * u, 1.2 * u, col)
		"ammo":
			for k in 3:
				var x := -6.5 + k * 6.5
				Draw.poly(ci, _pts(c, u, [x - 2.2, 10, x - 2.2, -3, x, -9, x + 2.2, -3, x + 2.2, 10]), col)
				ci.draw_line(c + Vector2(x - 2.2, 5) * u, c + Vector2(x + 2.2, 5) * u, bg, maxf(1.0, u), true)
		"phone":
			Draw.ellipse(ci, c + Vector2(0, 9) * u, Vector2(7, 2.6) * u, col)
			Draw.rect(ci, _r(c, u, -1.6, -5, 3.2, 14), col)
			Draw.circle(ci, c + Vector2(0, -7) * u, 3.4 * u, col)
			ci.draw_line(c + Vector2(6, -9) * u, c + Vector2(7, 3) * u, col, maxf(1.5, 2.6 * u), true)
			Draw.circle(ci, c + Vector2(6, -9) * u, 2.2 * u, col)
			ci.draw_line(c + Vector2(1.5, -4) * u, c + Vector2(6, -6) * u, col, maxf(1.0, 1.2 * u), true)
		"car":
			Draw.rrect(ci, _r(c, u, -11, -3, 22, 8), 2.5 * u, col)
			Draw.poly(ci, _pts(c, u, [-6, -3, -4, -9, 5, -9, 7, -3]), col)
			Draw.rect(ci, _r(c, u, -3, -7.5, 3.4, 3.8), bg)
			Draw.rect(ci, _r(c, u, 1.4, -7.5, 3.4, 3.8), bg)
			Draw.circle(ci, c + Vector2(-6, 6) * u, 3.4 * u, col)
			Draw.circle(ci, c + Vector2(6, 6) * u, 3.4 * u, col)
			Draw.circle(ci, c + Vector2(-6, 6) * u, 1.3 * u, bg)
			Draw.circle(ci, c + Vector2(6, 6) * u, 1.3 * u, bg)
		"truck":
			Draw.rect(ci, _r(c, u, -11, -6, 13, 10), col)
			Draw.poly(ci, _pts(c, u, [3, -2, 8, -2, 11, 2, 11, 4, 3, 4]), col)
			Draw.rect(ci, _r(c, u, 4.5, -0.5, 3, 2), bg)
			Draw.circle(ci, c + Vector2(-6, 6) * u, 3.0 * u, col)
			Draw.circle(ci, c + Vector2(7, 6) * u, 3.0 * u, col)
			Draw.circle(ci, c + Vector2(-6, 6) * u, 1.1 * u, bg)
			Draw.circle(ci, c + Vector2(7, 6) * u, 1.1 * u, bg)
		"cross":
			Draw.rect(ci, _r(c, u, -3.5, -10, 7, 20), col)
			Draw.rect(ci, _r(c, u, -10, -3.5, 20, 7), col)
		"flag":
			ci.draw_line(c + Vector2(-7, -11) * u, c + Vector2(-7, 11) * u, col, maxf(1.5, 2.2 * u), true)
			Draw.poly(ci, _pts(c, u, [-6, -10, 9, -7, -6, -1]), col)
			Draw.ellipse(ci, c + Vector2(-7, 11) * u, Vector2(4, 1.3) * u, col)
		"star":
			_star(ci, c, 11.0 * u, col)
		"sun":
			Draw.circle(ci, c, 5.5 * u, col)
			for k in 8:
				var d := Vector2.from_angle(TAU * k / 8.0)
				ci.draw_line(c + d * 8.0 * u, c + d * 11.0 * u, col, maxf(1.2, 2.0 * u), true)
		"moon":
			Draw.circle(ci, c, 9.0 * u, col)
			Draw.circle(ci, c + Vector2(4.5, -3.0) * u, 7.5 * u, bg)
		"rain":
			_cloud(ci, c + Vector2(0, -3) * u, u, col)
			for k in 3:
				var x := -5.0 + k * 5.0
				ci.draw_line(c + Vector2(x, 5) * u, c + Vector2(x - 2.5, 11) * u, col, maxf(1.2, 1.8 * u), true)
		"fog":
			_cloud(ci, c + Vector2(0, -5) * u, u, col)
			for k in 3:
				var y := 3.0 + k * 3.6
				ci.draw_line(c + Vector2(-10 + k * 2, y) * u, c + Vector2(10 - (2 - k) * 2, y) * u, with_a(col, 0.85), maxf(1.2, 1.8 * u), true)
		"boat":
			Draw.poly(ci, _pts(c, u, [-11, 1, 11, 1, 7, 8, -8, 8]), col)
			Draw.rect(ci, _r(c, u, -4, -5, 8, 6), col)
			Draw.rect(ci, _r(c, u, -2.6, -3.6, 2.2, 2.2), bg)
			Draw.rect(ci, _r(c, u, 0.8, -3.6, 2.2, 2.2), bg)
			ci.draw_line(c + Vector2(2, -5) * u, c + Vector2(2, -10) * u, col, maxf(1.2, 1.6 * u), true)
		"map":
			Draw.poly(ci, _pts(c, u, [-11, -8, -4, -10, 4, -8, 11, -10, 11, 8, 4, 10, -4, 8, -11, 10]), col)
			ci.draw_line(c + Vector2(-4, -10) * u, c + Vector2(-4, 8) * u, bg, maxf(1.0, u), true)
			ci.draw_line(c + Vector2(4, -8) * u, c + Vector2(4, 10) * u, bg, maxf(1.0, u), true)
			Draw.circle(ci, c + Vector2(0.5, -1) * u, 2.0 * u, bg)
		"book":
			Draw.rrect(ci, _r(c, u, -9, -11, 18, 22), 1.5 * u, col)
			Draw.rect(ci, _r(c, u, -9, -11, 3, 22), col.darkened(0.3))
			Draw.rect(ci, _r(c, u, -3, -6, 9, 1.8), bg)
			Draw.rect(ci, _r(c, u, -3, -2.5, 9, 1.8), bg)
		"gear":
			for k in 8:
				var d := Vector2.from_angle(TAU * k / 8.0)
				ci.draw_line(c + d * 6.0 * u, c + d * 10.5 * u, col, maxf(2.0, 4.0 * u), false)
			Draw.circle(ci, c, 7.5 * u, col)
			Draw.circle(ci, c, 3.0 * u, bg)
		"help":
			Draw.circle(ci, c, 10.5 * u, col)
			var f2 := font("cond")
			var fs2 := int(maxf(8.0, 16.0 * u))
			text_c(ci, c.x, mid(f2, fs2, c.y), "?", f2, fs2, bg)
		"clock":
			Draw.circle(ci, c, 10.5 * u, col)
			Draw.circle(ci, c, 8.5 * u, bg)
			ci.draw_line(c, c + Vector2(0, -6) * u, col, maxf(1.2, 1.8 * u), true)
			ci.draw_line(c, c + Vector2(4, 1) * u, col, maxf(1.2, 1.8 * u), true)
		"news":
			Draw.rect(ci, _r(c, u, -10, -9, 20, 18), col)
			Draw.rect(ci, _r(c, u, -8, -7, 16, 3), bg)
			Draw.rect(ci, _r(c, u, -8, -2, 7, 7), bg)
			for k in 3:
				Draw.rect(ci, _r(c, u, 1, -2 + k * 2.6, 7, 1.2), bg)
		_:
			Draw.circle(ci, c, 4.0 * u, col)


static func _star(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 10:
		var rr := r if k % 2 == 0 else r * 0.45
		pts.append(c + Vector2.from_angle(-PI * 0.5 + PI * k / 5.0) * rr)
	Draw.poly(ci, pts, col)


static func _cloud(ci: CanvasItem, c: Vector2, u: float, col: Color) -> void:
	Draw.circle(ci, c + Vector2(-4, 1) * u, 4.5 * u, col)
	Draw.circle(ci, c + Vector2(1.5, -2) * u, 6.0 * u, col)
	Draw.circle(ci, c + Vector2(6.5, 1.5) * u, 4.0 * u, col)
	Draw.rrect(ci, Rect2(c + Vector2(-8.5, 0) * u, Vector2(19, 5.5) * u), 2.5 * u, col)


## The colour for a toast / event kind.
static func kind_color(kind: String) -> Color:
	match kind:
		"good": return GREEN
		"bad": return RED
		"warn": return Color("f0a060")
		"deal": return Color("8ab0ff")
		"money": return GOLD2
	return Color("c8bca4")


static func kind_icon(kind: String) -> String:
	match kind:
		"good": return "good"
		"bad": return "bad"
		"warn": return "warn"
		"deal": return "deal"
		"money": return "money"
	return "info"


## Plays a UI sound through the World's audio, if there is one.
static func sound(world: Node, name: String, db: float = -12.0) -> void:
	if world == null or not is_instance_valid(world):
		return
	var au: Variant = world.get("audio")
	if au is Node and (au as Node).has_method("ui"):
		(au as Node).call("ui", name, db)


## The local player's family id (or -1).
static func my_family() -> int:
	return int(Game.player(Net.my_id()).get("family", -1))


## A family's name with "the ... family" wording.
static func fam_name(id: int) -> String:
	return String(Game.fam(id).get("name", ""))


static func fam_col(id: int) -> Color:
	var f := Game.fam(id)
	return Color(String(f["color"])) if not f.is_empty() else Color("7a7266")
