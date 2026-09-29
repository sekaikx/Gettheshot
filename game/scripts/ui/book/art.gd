extends RefCounted
## The look of the don's desk, shared by the family book and Don's View: lacquered wood, the
## leather cover, cream paper, ink, rubber stamps, brass switches, buttons that look printed on
## the page. Static functions over any CanvasItem, called from inside its _draw().
##
## Text positions are BASELINES (like CanvasItem.draw_string). Fonts come from W.ui_font().

# ink and paper (shades of Pal.PAPER / Pal.PAPER_INK, the same as the country map's card)
const INK := Color("20160c")
const INK_SOFT := Color("5a4a36")
const INK_FAINT := Color(0.353, 0.29, 0.212, 0.55)
const PAPER := Color("ece2c8")
const PAPER_LIGHT := Color("f6eed8")
const PAPER_DARK := Color("d9cba8")
const CARD_EDGE := Color("b9a67e")
const RULE := Color(0.42, 0.5, 0.58, 0.28)     # the faint blue ledger lines
const MARGIN_RED := Color(0.62, 0.2, 0.18, 0.4)
const OXBLOOD := Color("8b1e1a")
const GOLD := Color("b8862c")
const GOLD_LIGHT := Color("e2c26e")
const GREEN_INK := Color("2e5a3a")
const BLUE_INK := Color("2a3a5a")
const MANILA := Color("d8b878")
const MANILA_DARK := Color("b8955a")
const INDEX_CARD := Color("f7f2e4")
const DESK := Color("1c1510")
const DESK_2 := Color("2a1d14")
const LEATHER := Color("4a2016")
const BRASS := Pal.BRASS
const CREAM := Pal.INK

static var _wraps := {}
static var _boxes := {}
static var _glow: Texture2D
static var _shade: Texture2D


static func font(name: String) -> Font:
	return W.ui_font(name)


# ------------------------------------------------------------------ text

static func text_w(s: String, fname: String, size: int) -> float:
	return font(fname).get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


## One line of text. `pos` is the baseline; with align CENTER/RIGHT, `width` is the box from pos.x.
static func text(ci: CanvasItem, pos: Vector2, s: String, fname: String, size: int, color: Color,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	if s == "":
		return
	var f := font(fname)
	var p := pos
	if align != HORIZONTAL_ALIGNMENT_LEFT and width > 0.0:
		var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		p.x += (width - w) * (0.5 if align == HORIZONTAL_ALIGNMENT_CENTER else 1.0)
	ci.draw_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


## Text right-aligned so it ends at x.
static func text_r(ci: CanvasItem, pos: Vector2, s: String, fname: String, size: int, color: Color) -> void:
	text(ci, Vector2(pos.x - text_w(s, fname, size), pos.y), s, fname, size, color)


## Text centred on x.
static func text_c(ci: CanvasItem, pos: Vector2, s: String, fname: String, size: int, color: Color) -> void:
	text(ci, Vector2(pos.x - text_w(s, fname, size) * 0.5, pos.y), s, fname, size, color)


## Shortens a line with an ellipsis so it fits `width`.
static func fit(s: String, fname: String, size: int, width: float) -> String:
	if text_w(s, fname, size) <= width:
		return s
	var t := s
	while t.length() > 1 and text_w(t + "…", fname, size) > width:
		t = t.left(t.length() - 1)
	return t.strip_edges() + "…"


## Word wrap (cached). Returns the lines.
static func lines_of(s: String, fname: String, size: int, width: float) -> PackedStringArray:
	var key := "%s|%d|%d|%s" % [fname, size, int(width), s]
	if _wraps.has(key):
		return _wraps[key]
	var out := PackedStringArray()
	for para in s.split("\n"):
		var line := ""
		for word in para.split(" ", false):
			var t: String = word if line == "" else line + " " + word
			if line != "" and text_w(t, fname, size) > width:
				out.append(line)
				line = word
			else:
				line = t
		out.append(line)
	if _wraps.size() > 3000:
		_wraps.clear()
	_wraps[key] = out
	return out


## A wrapped paragraph from its top-left corner. Returns its height.
static func para(ci: CanvasItem, top_left: Vector2, s: String, fname: String, size: int, color: Color,
		width: float, leading: float = 0.0, max_lines: int = 0) -> float:
	var lines := lines_of(s, fname, size, width)
	var lead := leading if leading > 0.0 else size * 1.3
	var asc := font(fname).get_ascent(size)
	var n := lines.size() if max_lines <= 0 else mini(max_lines, lines.size())
	for i in n:
		var l := lines[i]
		if max_lines > 0 and i == n - 1 and lines.size() > n:
			l = fit(l + " …", fname, size, width)
		text(ci, top_left + Vector2(0, asc + i * lead), l, fname, size, color)
	return n * lead


static func para_h(s: String, fname: String, size: int, width: float, leading: float = 0.0, max_lines: int = 0) -> float:
	var n := lines_of(s, fname, size, width).size()
	if max_lines > 0:
		n = mini(n, max_lines)
	return n * (leading if leading > 0.0 else size * 1.3)


## Typewritten text: each letter a hair off its line, the ink a little uneven.
static func typed(ci: CanvasItem, pos: Vector2, s: String, size: int, color: Color, seed_value: int = 0) -> void:
	var f := font("fell")
	var x := pos.x
	for i in s.length():
		var ch := s[i]
		var j := Draw.hash01(i, seed_value, 7)
		var dy := (j - 0.5) * size * 0.08
		var a := 0.78 + Draw.hash01(i, seed_value, 11) * 0.22
		ci.draw_string(f, Vector2(x, pos.y + dy), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(color, color.a * a))
		x += f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


static func typed_w(s: String, size: int) -> float:
	var f := font("fell")
	var w := 0.0
	for i in s.length():
		w += f.get_string_size(s[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	return w


## "$1,250"
static func money(v: int) -> String:
	return ("-$" if v < 0 else "$") + W.money(absi(v))


# ------------------------------------------------------------------ boxes, glows, shadows

## A rounded box with an anti-aliased edge and an optional soft shadow (StyleBoxFlat, cached).
static func box(ci: CanvasItem, r: Rect2, fill: Color, border: Color = Color(0, 0, 0, 0), bw: int = 0,
		radius: int = 3, shadow: int = 0, shadow_off: Vector2 = Vector2(3, 5), shadow_a: float = 0.4) -> void:
	var key := "%s|%s|%d|%d|%d|%s|%.2f" % [fill.to_html(), border.to_html(), bw, radius, shadow, shadow_off, shadow_a]
	var sb: StyleBoxFlat = _boxes.get(key)
	if sb == null:
		sb = StyleBoxFlat.new()
		sb.bg_color = fill
		sb.border_color = border
		sb.set_border_width_all(bw)
		sb.set_corner_radius_all(radius)
		sb.anti_aliasing = true
		sb.corner_detail = 6
		if shadow > 0:
			sb.shadow_color = Color(0, 0, 0, shadow_a)
			sb.shadow_size = shadow
			sb.shadow_offset = shadow_off
		if _boxes.size() > 400:
			_boxes.clear()
		_boxes[key] = sb
	sb.draw(ci.get_canvas_item(), r)


static func glow_tex() -> Texture2D:
	if _glow == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.45, Color(1, 1, 1, 0.42))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 128
		t.height = 128
		_glow = t
	return _glow


## A soft round pool of light (or shadow, with a dark colour).
static func glow(ci: CanvasItem, center: Vector2, radius: Vector2, color: Color) -> void:
	ci.draw_texture_rect(glow_tex(), Rect2(center - radius, radius * 2.0), false, color)


## A soft shadow under a rectangle lying on the desk (light from the north-west).
static func drop_shadow(ci: CanvasItem, r: Rect2, off: Vector2 = Vector2(8, 12), spread: float = 18.0, alpha: float = 0.55) -> void:
	for k in 6:
		var t := float(k) / 5.0
		var g := spread * (1.0 - t)
		Draw.rrect(ci, Rect2(r.position + off - Vector2(g, g) * 0.5, r.size + Vector2(g, g)), 6.0 + g * 0.5, Color(0, 0, 0, alpha / 6.0))


static func vignette(ci: CanvasItem, r: Rect2, strength: float = 0.6) -> void:
	var e := minf(r.size.x, r.size.y) * 0.22
	var c := Color(0, 0, 0, strength)
	var z := Color(0, 0, 0, 0)
	Draw.vgrad(ci, Rect2(r.position, Vector2(r.size.x, e)), c, z)
	Draw.vgrad(ci, Rect2(Vector2(r.position.x, r.end.y - e), Vector2(r.size.x, e)), z, c)
	Draw.hgrad(ci, Rect2(r.position, Vector2(e, r.size.y)), c, z)
	Draw.hgrad(ci, Rect2(Vector2(r.end.x - e, r.position.y), Vector2(e, r.size.y)), z, c)


# ------------------------------------------------------------------ the desk

## Lacquered walnut: long grain lines, a warm lamp pool from the top-left, dark corners.
static func desk(ci: CanvasItem, r: Rect2, seed_value: int = 3) -> void:
	Draw.vgrad(ci, r, Color("2b1d13"), Color("160f0a"))
	var rng := W.rng(seed_value)
	var rows := int(r.size.y / 7.0)
	for k in rows:
		var y0 := r.position.y + k * 7.0 + rng.randf_range(-2.0, 2.0)
		var pts := PackedVector2Array()
		var amp := rng.randf_range(1.0, 5.0)
		var freq := rng.randf_range(0.002, 0.007)
		var ph := rng.randf() * TAU
		var x := r.position.x
		while x <= r.end.x + 40.0:
			pts.append(Vector2(x, y0 + sin(x * freq + ph) * amp + sin(x * freq * 3.1 + ph * 2.0) * amp * 0.3))
			x += 40.0
		var light := rng.randf() < 0.5
		var col := Color(0.55, 0.36, 0.2, rng.randf_range(0.05, 0.13)) if light else Color(0.03, 0.015, 0.0, rng.randf_range(0.12, 0.28))
		ci.draw_polyline(pts, col, rng.randf_range(1.0, 3.0), true)
	# a few knots
	for k in 3:
		var c := r.position + Vector2(rng.randf() * r.size.x, rng.randf() * r.size.y)
		for ring in 5:
			var rr := Vector2(26.0 - ring * 4.0, 8.0 - ring * 1.2)
			ci.draw_polyline(Draw.ellipse_points(c, rr, 0.0, 24) + PackedVector2Array([c + Vector2(rr.x, 0)]), Color(0.03, 0.015, 0.0, 0.18), 1.2, true)
	glow(ci, r.position + Vector2(r.size.x * 0.22, r.size.y * 0.05), Vector2(r.size.x * 0.75, r.size.y * 0.9), Color(1.0, 0.72, 0.4, 0.16))
	vignette(ci, r, 0.55)


## A brass desk-lamp pool of light (drawn over everything, additive-looking).
static func lamp_light(ci: CanvasItem, r: Rect2) -> void:
	glow(ci, r.position + Vector2(r.size.x * 0.3, -r.size.y * 0.1), Vector2(r.size.x * 0.55, r.size.y * 0.7), Color(1.0, 0.85, 0.6, 0.05))


# ------------------------------------------------------------------ paper

## A sheet of cream paper: a faint fibre texture and darker, foxed edges.
static func paper(ci: CanvasItem, r: Rect2, seed_value: int = 1, base: Color = PAPER) -> void:
	ci.draw_rect(r, base)
	var rng := W.rng(seed_value)
	var n := int(r.size.x * r.size.y / 700.0)
	for k in n:
		var p := r.position + Vector2(rng.randf() * r.size.x, rng.randf() * r.size.y)
		var dark := rng.randf() < 0.6
		var col := Color(0.45, 0.35, 0.2, rng.randf_range(0.03, 0.08)) if dark else Color(1, 1, 1, rng.randf_range(0.05, 0.12))
		ci.draw_rect(Rect2(p, Vector2(rng.randf_range(1.0, 3.5), 1.0)), col)
	# foxing near the edges
	for k in 10:
		var side := rng.randi() % 4
		var p := r.position + Vector2(rng.randf() * r.size.x, rng.randf() * r.size.y)
		match side:
			0: p.y = r.position.y + rng.randf() * 30.0
			1: p.y = r.end.y - rng.randf() * 30.0
			2: p.x = r.position.x + rng.randf() * 30.0
			3: p.x = r.end.x - rng.randf() * 30.0
		glow(ci, p, Vector2.ONE * rng.randf_range(10.0, 34.0), Color(0.55, 0.38, 0.15, 0.07))
	var e := 26.0
	var c := Color(0.45, 0.32, 0.15, 0.16)
	var z := Color(0.45, 0.32, 0.15, 0.0)
	Draw.vgrad(ci, Rect2(r.position, Vector2(r.size.x, e)), c, z)
	Draw.vgrad(ci, Rect2(Vector2(r.position.x, r.end.y - e), Vector2(r.size.x, e)), z, c)
	Draw.hgrad(ci, Rect2(r.position, Vector2(e, r.size.y)), c, z)
	Draw.hgrad(ci, Rect2(Vector2(r.end.x - e, r.position.y), Vector2(e, r.size.y)), z, c)


## Horizontal rule. Double: a thick and a thin line, like a printed ledger.
static func rule(ci: CanvasItem, a: Vector2, b: Vector2, color: Color = INK_SOFT, double: bool = false) -> void:
	ci.draw_line(a, b, color, 1.0 if not double else 2.0)
	if double:
		ci.draw_line(a + Vector2(0, 4), b + Vector2(0, 4), Color(color, color.a * 0.8), 1.0)


## A little printer's ornament: a diamond between two lines, centred at c.
static func ornament(ci: CanvasItem, c: Vector2, half_w: float, color: Color = INK_SOFT) -> void:
	ci.draw_line(c - Vector2(half_w, 0), c - Vector2(9, 0), color, 1.0)
	ci.draw_line(c + Vector2(9, 0), c + Vector2(half_w, 0), color, 1.0)
	Draw.poly(ci, PackedVector2Array([c + Vector2(0, -4), c + Vector2(5, 0), c + Vector2(0, 4), c + Vector2(-5, 0)]), color)


# ------------------------------------------------------------------ bars, meters, switches

## A thin ink-drawn bar: 0..1.
static func bar(ci: CanvasItem, r: Rect2, v: float, fill: Color, back: Color = Color(0.35, 0.27, 0.16, 0.14)) -> void:
	Draw.rrect(ci, r, r.size.y * 0.5, back)
	var w := r.size.x * clampf(v, 0.0, 1.0)
	if w > 1.0:
		Draw.rrect(ci, Rect2(r.position, Vector2(maxf(w, r.size.y), r.size.y)), r.size.y * 0.5, fill)
		ci.draw_line(r.position + Vector2(r.size.y * 0.5, 1.5), r.position + Vector2(maxf(w, r.size.y) - r.size.y * 0.5, 1.5), Color(1, 1, 1, 0.22), 1.0)


## Loyalty colour: green when he's happy, amber, red when he might walk.
static func loyalty_color(v: float) -> Color:
	if v >= 60.0:
		return GREEN_INK
	if v >= 35.0:
		return Color("9a6a1c")
	return OXBLOOD


## A brass toggle switch. Returns nothing; draw it at r (about 54 x 26).
static func switch(ci: CanvasItem, r: Rect2, on: bool, hot: bool) -> void:
	var rad := r.size.y * 0.5
	var track := GREEN_INK if on else Color("8a7d66")
	Draw.rrect(ci, r.grow(1.0), rad + 1.0, Color(0, 0, 0, 0.25))
	Draw.rrect(ci, r, rad, track)
	Draw.rrect(ci, Rect2(r.position + Vector2(2, 2), Vector2(r.size.x - 4, rad - 2)), rad - 2.0, Color(1, 1, 1, 0.1))
	var kx := r.end.x - rad if on else r.position.x + rad
	var c := Vector2(kx, r.position.y + rad)
	Draw.circle(ci, c + Vector2(1, 2), rad - 2.0, Color(0, 0, 0, 0.3))
	Draw.circle(ci, c, rad - 2.5, BRASS.lightened(0.15 if hot else 0.0))
	Draw.circle(ci, c - Vector2(2, 2), rad * 0.45, Color(1, 1, 1, 0.25))
	var t := "ON" if on else "OFF"
	var tx := r.position.x + 7.0 if on else r.end.x - 7.0 - text_w(t, "cond", 13)
	text(ci, Vector2(tx, r.position.y + rad + 5.0), t, "cond", 13, PAPER_LIGHT if on else Color("f1e8d2"))


## A key cap: "Tab", "Esc", "1".
static func keycap(ci: CanvasItem, pos: Vector2, key: String, dark: bool = false, size: int = 14) -> float:
	var w := maxf(text_w(key, "cond", size) + 12.0, size + 8.0)
	var r := Rect2(pos - Vector2(0, size + 3.0), Vector2(w, size + 8.0))
	box(ci, r, Color("2a211a") if dark else PAPER_LIGHT, Color("0d0906") if dark else INK_SOFT, 1, 4)
	ci.draw_line(Vector2(r.position.x + 3, r.end.y - 2), Vector2(r.end.x - 3, r.end.y - 2), Color(0, 0, 0, 0.35), 2.0)
	text(ci, Vector2(r.position.x + (w - text_w(key, "cond", size)) * 0.5, pos.y + 1.0), key, "cond", size, Color("e6d8b8") if dark else INK)
	return w


# ------------------------------------------------------------------ stamps, seals, crests

## A rubber stamp: a double-ruled box with spaced capitals, at an angle, the ink patchy.
static func stamp(ci: CanvasItem, center: Vector2, s: String, color: Color, size: int = 30, rot: float = -0.18, seed_value: int = 5) -> void:
	var f := font("cond")
	var spaced := " ".join(s.split(""))
	var w := f.get_string_size(spaced, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var h := size * 1.25
	ci.draw_set_transform(center, rot, Vector2.ONE)
	var r := Rect2(Vector2(-w * 0.5 - 14.0, -h * 0.5 - 6.0), Vector2(w + 28.0, h + 12.0))
	ci.draw_rect(r, color, false, 3.0)
	ci.draw_rect(r.grow(-5.0), color, false, 1.2)
	ci.draw_string(f, Vector2(-w * 0.5, size * 0.36), spaced, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
	# gaps in the ink
	var rng := W.rng(seed_value)
	var holes := Color("ece2c8") if color.a > 0.0 else color
	for k in 26:
		var p := Vector2(rng.randf_range(r.position.x, r.end.x), rng.randf_range(r.position.y, r.end.y))
		ci.draw_rect(Rect2(p, Vector2(rng.randf_range(1.0, 4.0), rng.randf_range(1.0, 2.0))), Color(holes, 0.55))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A wax seal: a lumpy disc with a ring pressed in, text on it.
static func seal(ci: CanvasItem, c: Vector2, r: float, color: Color, s: String = "") -> void:
	var pts := PackedVector2Array()
	for k in 18:
		var a := TAU * k / 18.0
		var rr := r * (0.92 + 0.1 * Draw.hash01(k, int(r), 3))
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	Draw.shadow(ci, pts, Vector2(2, 3), Color(0, 0, 0, 0.35))
	Draw.poly(ci, pts, color)
	ci.draw_arc(c, r * 0.68, 0.0, TAU, 32, color.darkened(0.3), 1.6, true)
	ci.draw_arc(c + Vector2(-1, -1), r * 0.68, PI * 1.05, PI * 1.6, 12, Color(1, 1, 1, 0.3), 1.2, true)
	glow(ci, c - Vector2(r * 0.3, r * 0.35), Vector2.ONE * r * 0.5, Color(1, 1, 1, 0.18))
	if s != "":
		var sz := int(r * 0.48)
		text_c(ci, Vector2(c.x, c.y + sz * 0.36), s, "cond", sz, color.lightened(0.55))


## The family crest: a shield in the family colour, a gold rim, the initial in Art Deco capitals.
static func shield_points(c: Vector2, w: float, h: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.append(c + Vector2(-0.5 * w, -0.5 * h))
	pts.append(c + Vector2(-0.16 * w, -0.44 * h))
	pts.append(c + Vector2(0.0, -0.52 * h))
	pts.append(c + Vector2(0.16 * w, -0.44 * h))
	pts.append(c + Vector2(0.5 * w, -0.5 * h))
	var a := Vector2(0.5 * w, 0.02 * h)
	var m := Vector2(0.5 * w, 0.36 * h)
	var b := Vector2(0.0, 0.5 * h)
	for k in 9:
		var t := float(k) / 8.0
		pts.append(c + a.lerp(m, t).lerp(m.lerp(b, t), t))
	for k in range(7, -1, -1):
		var t := float(k) / 8.0
		var q := a.lerp(m, t).lerp(m.lerp(b, t), t)
		pts.append(c + Vector2(-q.x, q.y))
	return pts


static func crest(ci: CanvasItem, c: Vector2, h: float, color: Color, letter: String = "", shade: bool = true) -> void:
	var w := h * 0.84
	var outer := shield_points(c, w, h)
	if shade:
		Draw.shadow(ci, outer, Vector2(h * 0.05, h * 0.07), Color(0, 0, 0, 0.35))
	Draw.poly(ci, outer, GOLD)
	var inner := shield_points(c + Vector2(0, -h * 0.01), w * 0.84, h * 0.86)
	Draw.poly(ci, inner, color)
	# light across the top half
	var hl := PackedVector2Array()
	for k in 5:
		hl.append(inner[k])
	hl.append(c + Vector2(0.42 * w, -0.08 * h))
	hl.append(c + Vector2(-0.42 * w, -0.08 * h))
	Draw.poly(ci, hl, Color(1, 1, 1, 0.12), false)
	if letter != "":
		var sz := int(h * 0.46)
		var f := font("deco")
		var lw := f.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
		var at := Vector2(c.x - lw * 0.5, c.y + sz * 0.3)
		ci.draw_string(f, at + Vector2(1, 1), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(0, 0, 0, 0.45))
		ci.draw_string(f, at, letter, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, GOLD_LIGHT)


static func fam_color(id: int) -> Color:
	var f := Game.fam(id)
	return Color(String(f.get("color", "#777777"))) if not f.is_empty() else Color("8a7d66")


## A family colour that reads on cream paper (darker, a touch less saturated).
static func ink_of(id: int) -> Color:
	var c := fam_color(id)
	return c.darkened(0.18) if c.get_luminance() > 0.35 else c


static func initial(id: int) -> String:
	var n := String(Game.fam(id).get("name", "?"))
	return n.substr(0, 1).to_upper() if n != "" else "?"


## A photograph pasted into the book: white border, black photo corners, the portrait inside.
static func photo(ci: CanvasItem, r: Rect2, kind: String, look: int, family_color: Color, extra: Dictionary = {},
		mood: String = "", jailed: bool = false) -> void:
	Draw.rect(ci, Rect2(r.position + Vector2(3, 4), r.size), Color(0, 0, 0, 0.25))
	ci.draw_rect(r, Color("f4efe3"))
	var inner := r.grow(-5.0)
	Portrait.draw(ci, inner, kind, look, family_color, extra, mood)
	# a sepia wash so every portrait sits in the same old photograph
	ci.draw_rect(inner, Color(0.45, 0.3, 0.1, 0.1))
	if jailed:
		for k in 5:
			var x := inner.position.x + inner.size.x * (0.1 + k * 0.2)
			ci.draw_line(Vector2(x, inner.position.y), Vector2(x, inner.end.y), Color("2a2a2c"), 3.0)
		ci.draw_rect(inner, Color(0.1, 0.1, 0.15, 0.25))
	var cs := minf(13.0, r.size.x * 0.14)
	for k in 4:
		var o := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)][k] as Vector2
		var dx := 1.0 if k in [0, 3] else -1.0
		var dy := 1.0 if k in [0, 1] else -1.0
		var tri := PackedVector2Array([o + Vector2(-dx * 1, -dy * 1), o + Vector2(dx * cs, -dy * 1), o + Vector2(-dx * 1, dy * cs)])
		Draw.poly(ci, tri, Color("2a211b"))
		ci.draw_line(o + Vector2(dx * cs, -dy * 1), o + Vector2(-dx * 1, dy * cs), Color(1, 1, 1, 0.12), 1.0, true)


# ------------------------------------------------------------------ buttons

## Button styles:
##   "ink"      printed on the page: paper with an ink border; hover turns it oxblood
##   "active"   the thing that's on now (the task a man is doing): solid ink, cream letters
##   "go"       the main action (Shake hands): bottle green
##   "danger"   an outline in oxblood
##   "row"      a full-width list entry, like the country map's cards (a bar on the left on hover)
##   "brass"    a brass plate on the leather / the desk
##   "tab"      nothing (the caller draws it); only the hit area
static func button(ci: CanvasItem, r: Rect2, label: String, style: String, hot: bool, enabled: bool = true,
		sub: String = "", icon: String = "", size: int = 18) -> void:
	var fill := PAPER_LIGHT
	var edge := Color(INK_SOFT, 0.6)
	var col := INK
	var subc := INK_SOFT
	var bw := 1
	match style:
		"ink":
			if hot and enabled:
				fill = OXBLOOD
				edge = OXBLOOD.darkened(0.3)
				col = PAPER_LIGHT
				subc = Color(PAPER_LIGHT, 0.8)
		"active":
			fill = INK if not hot else Color("3a2a1a")
			edge = INK
			col = PAPER_LIGHT
			subc = Color(PAPER_LIGHT, 0.75)
		"go":
			fill = GREEN_INK.lightened(0.12 if hot else 0.0)
			edge = GREEN_INK.darkened(0.3)
			col = PAPER_LIGHT
			subc = Color(PAPER_LIGHT, 0.8)
		"danger":
			fill = Color(OXBLOOD, 0.1) if hot else PAPER_LIGHT
			edge = OXBLOOD
			col = OXBLOOD
			bw = 2 if hot else 1
		"row":
			fill = Color("fbf4e2") if hot else Color("f6eed8")
			edge = OXBLOOD if hot else CARD_EDGE
			col = OXBLOOD if hot else INK
		"brass":
			fill = BRASS.lightened(0.12) if hot else BRASS.darkened(0.08)
			edge = Color("5a4418")
			col = Color("24180c")
			subc = Color("3a2a14")
	if not enabled:
		fill = Color(PAPER_DARK, 0.6) if style != "brass" else Color("6a5a3a")
		edge = Color(INK_SOFT, 0.25)
		col = Color(INK_SOFT, 0.55)
		subc = Color(INK_SOFT, 0.45)
	if style == "brass":
		box(ci, r, fill, edge, 1, 4, 3, Vector2(1, 2), 0.35)
		ci.draw_line(r.position + Vector2(4, 2), Vector2(r.end.x - 4, r.position.y + 2), Color(1, 1, 1, 0.35), 1.0)
	else:
		box(ci, r, fill, edge, bw, 3 if style != "row" else 2)
	if style == "row" and hot and enabled:
		ci.draw_rect(Rect2(r.position, Vector2(4, r.size.y)), OXBLOOD)
	var x := r.position.x + (14.0 if style == "row" else 10.0)
	var isz := float(size) * 0.95
	var has_sub := sub != ""
	var tw := text_w(label, "cond", size)
	if style != "row":
		var total := tw + (isz + 6.0 if icon != "" else 0.0)
		x = r.position.x + (r.size.x - total) * 0.5
	var base_y := r.position.y + r.size.y * 0.5 + size * 0.34
	if has_sub:
		base_y = r.position.y + 6.0 + size * 0.8
	if icon != "":
		preload("res://scripts/ui/book/icons.gd").draw(ci, icon, Vector2(x + isz * 0.5, base_y - size * 0.34), isz, col, fill)
		x += isz + 6.0
	var maxw := r.end.x - x - 8.0
	text(ci, Vector2(x, base_y), fit(label, "cond", size, maxw), "cond", size, col)
	if has_sub:
		var sx := r.position.x + (14.0 if style == "row" else 10.0)
		if style != "row":
			sx = r.position.x + (r.size.x - minf(text_w(sub, "sans", size - 3), r.size.x - 16.0)) * 0.5
		text(ci, Vector2(sx, base_y + size * 0.95), fit(sub, "sans", size - 3, r.size.x - 20.0), "sans", size - 3, subc)


static func button_w(label: String, size: int = 18, icon: bool = false) -> float:
	return text_w(label, "cond", size) + 26.0 + (size + 6.0 if icon else 0.0)
