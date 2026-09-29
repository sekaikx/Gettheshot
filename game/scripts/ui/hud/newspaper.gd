extends Control
## The Daily Ledger. N (or the newsboy) opens the front page: the masthead, the date line, the
## lead story as a big headline, a drawn picture, the rest of the news in columns. Every new month
## a folded copy slides in at the right for a few seconds; click it (or press N) to read it.

signal closed
signal open_full

const UI := preload("res://scripts/ui/hud/hud_ui.gd")
const MINI_LIFE := 9.0
const ADS := [["MARINO BROS.", "Fine tailoring since 1908", "Suits made to measure · Mulberry St."],
	["DR. PARKER'S TONIC", "For the nerves", "Sold at every good drugstore"],
	["EMPIRE RADIO", "Hear the ball game at home", "Easy terms · Essex St."],
	["THE BOWERY SAVINGS", "Put your money to work", "Safe as the Rock of Gibraltar"]]

var world: Node
var full := false
var _stories: Array = []      # [{text, big}]
var _t := 0.0
var _mini_t := MINI_LIFE
var _pic := "skyline"
var _sheet := Rect2()
var _mini := Rect2()
var mini_bottom := 600.0
var hold := false             # something else is open: the folded copy waits


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## The stories to print: this month's and last month's for the monthly paper, else the latest.
static func pick_stories(m: int) -> Array:
	var out: Array = []
	for n in Game.news:
		var nd: Dictionary = n
		if m >= 0 and int(nd.get("month", 0)) < Game.month - 1:
			break
		out.append({"text": String(nd.get("text", "")), "big": bool(nd.get("big", false))})
		if out.size() >= 7:
			break
	# the big story leads
	for k in out.size():
		if bool(out[k]["big"]) and k > 0:
			var s: Dictionary = out[k]
			out.remove_at(k)
			out.push_front(s)
			break
	return out


func open_paper(stories: Array) -> void:
	_stories = stories
	if _stories.is_empty():
		_stories = [{"text": "All quiet in Lower Manhattan: the city waits to see who moves first.", "big": false}]
	_pic = _picture_for(String(_stories[0]["text"]))
	full = true
	_mini_t = MINI_LIFE
	_t = 0.0
	visible = true
	UI.sound(world, "paper_open", -8.0)
	queue_redraw()


func show_mini(stories: Array) -> void:
	if stories.is_empty() or full:
		return
	_stories = stories
	_pic = _picture_for(String(_stories[0]["text"]))
	_mini_t = 0.0
	visible = true
	queue_redraw()


func close_paper() -> void:
	if full:
		UI.sound(world, "paper_close", -8.0)
	full = false
	_mini_t = MINI_LIFE
	visible = false
	closed.emit()


func mini_showing() -> bool:
	return not full and _mini_t < MINI_LIFE


## The top of the folded copy on screen (the toasts stop above it).
func mini_top() -> float:
	return _mini.position.y if _mini.size.y > 0.0 else mini_bottom - 190.0


func _has_point(p: Vector2) -> bool:
	if full:
		return true
	return mini_showing() and not hold and _mini.has_point(p)


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
		accept_event()
		if full:
			close_paper()
		elif mini_showing():
			open_full.emit()


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	if not full:
		if not hold:
			_mini_t += delta
		if _mini_t >= MINI_LIFE:
			visible = false
			return
	if full and _t > 0.6:
		return
	queue_redraw()


static func _picture_for(s: String) -> String:
	var t := s.to_lower()
	for w in ["crash", "stock", "wall street", "bank", "rent"]:
		if t.contains(w):
			return "bank"
	for w in ["shot", "killed", "garage", "murder", "war ", "war:", "gun", "dead", "body", "found"]:
		if t.contains(w):
			return "street"
	for w in ["raid", "federal", "dry agent", "police", "cop", "arrest", "precinct", "commissioner", "jail"]:
		if t.contains(w):
			return "police"
	for w in ["prohibition", "beer", "barrel", "speakeas", "whisky", "rum", "booze", "cellar", "coast guard", "crates", "bootleg"]:
		if t.contains(w):
			return "booze"
	return "skyline"


## "BIG NEWS: the rest" -> ["BIG NEWS", "the rest"].
static func _split(s: String) -> PackedStringArray:
	var k := s.find(":")
	if k > 6 and k < s.length() - 4:
		return PackedStringArray([s.left(k).strip_edges(), _cap(s.substr(k + 1).strip_edges())])
	var d := s.find(" — ")
	if d > 6:
		return PackedStringArray([s.left(d).strip_edges(), _cap(s.substr(d + 3).strip_edges())])
	return PackedStringArray([s.strip_edges().trim_suffix("."), ""])


func _draw() -> void:
	if full:
		_draw_full()
	elif mini_showing() and not hold:
		_draw_mini()


# ------------------------------------------------------------------ the front page

func _draw_full() -> void:
	var a := clampf(_t / 0.3, 0.0, 1.0)
	Draw.rect(self, Rect2(Vector2.ZERO, size), Color(0.02, 0.015, 0.01, 0.66 * a))
	var pw := minf(920.0, size.x - 120.0)
	var ph := minf(760.0, size.y - 70.0)
	var k := 1.0 - (1.0 - a) * (1.0 - a)
	var c := size * 0.5 + Vector2(0, (1.0 - k) * 60.0)
	var rot := -0.014 + (1.0 - k) * -0.05
	_sheet = Rect2(c - Vector2(pw, ph) * 0.5, Vector2(pw, ph))
	draw_set_transform(c, rot, Vector2.ONE * lerpf(0.94, 1.0, k))
	var r := Rect2(-Vector2(pw, ph) * 0.5, Vector2(pw, ph))
	# shadow and paper
	for g in 5:
		Draw.rect(self, Rect2(r.position + Vector2(6, 10), r.size).grow(2.0 + g * 3.0), Color(0, 0, 0, 0.08))
	Draw.vgrad(self, r, Color("ece3cb"), Color("ddd1b3"))
	_paper_grain(r)
	var ink := UI.PAPER_INK
	var fell := UI.font("fell")
	var sc := UI.font("fell_sc")
	var x0 := r.position.x + 34.0
	var x1 := r.end.x - 34.0
	var w := x1 - x0
	var y := r.position.y + 24.0
	# the ears
	_ear(Rect2(Vector2(x0, y), Vector2(150, 44)), "LATE CITY", "EDITION")
	_ear(Rect2(Vector2(x1 - 150, y), Vector2(150, 44)), "TWO CENTS", "IN GREATER NEW YORK")
	# masthead
	UI.text_c(self, r.get_center().x, y + 58.0, "The Daily Ledger", fell, 68, ink)
	y += 80.0
	draw_line(Vector2(x0, y), Vector2(x1, y), ink, 2.0, true)
	draw_line(Vector2(x0, y + 4), Vector2(x1, y + 4), ink, 1.0, true)
	var wx := "RAIN" if world and String(world.get("weather")) == "rain" else ("FOG" if world and String(world.get("weather")) == "fog" else "FAIR")
	var dl := "VOL. %s   ·   NEW YORK, %s   ·   WEATHER: %s" % [_roman(Game.year() - 1915), Game.date_text().to_upper(), wx]
	UI.text_c(self, r.get_center().x, y + 22.0, dl, sc, 15, ink)
	y += 32.0
	draw_line(Vector2(x0, y), Vector2(x1, y), ink, 1.0, true)
	draw_line(Vector2(x0, y + 4), Vector2(x1, y + 4), ink, 2.0, true)
	y += 14.0
	# the lead story
	var lead := _split(String(_stories[0]["text"]))
	var head := lead[0].to_upper()
	var fs := 46
	var hl := UI.wrap(sc, head, fs, w)
	while fs > 26 and hl.size() > 2:
		fs -= 4
		hl = UI.wrap(sc, head, fs, w)
	for l in hl:
		y += fs * 0.98
		UI.text_c(self, r.get_center().x, y, l, sc, fs, ink)
	y += 10.0
	if lead[1] != "":
		for l in UI.wrap(fell, lead[1], 21, w - 80.0, 2):
			y += 24.0
			UI.text_c(self, r.get_center().x, y, l, fell, 21, ink.lightened(0.15))
		y += 6.0
	y += 10.0
	draw_line(Vector2(x0, y), Vector2(x1, y), ink, 1.0, true)
	y += 14.0
	# the picture on the left, the other stories in two columns
	var bottom := r.end.y - 40.0
	var pic_w := w * 0.4
	var pic := Rect2(Vector2(x0, y), Vector2(pic_w, minf(230.0, bottom - y - 40.0)))
	_picture(pic, _pic)
	UI.text(self, Vector2(x0, pic.end.y + 20.0), UI.fit(fell, _caption(_pic), 15, pic_w), fell, 15, ink.lightened(0.2))
	var gx := x0 + pic_w + 22.0
	var cw := (x1 - gx - 22.0) * 0.5
	draw_line(Vector2(gx - 11.0, y), Vector2(gx - 11.0, bottom), UI.with_a(ink, 0.6), 1.0, true)
	draw_line(Vector2(gx + cw + 11.0, y), Vector2(gx + cw + 11.0, bottom), UI.with_a(ink, 0.6), 1.0, true)
	# the stories flow down the two columns, then under the picture; ads fill what's left
	var cols := [[gx, y, cw], [gx + cw + 22.0, y, cw], [x0, pic.end.y + 44.0, pic_w]]
	var rest := _stories.slice(1)
	for ci in cols.size():
		var col: Array = cols[ci]
		var cx0: float = col[0]
		var yy: float = col[1]
		var w0: float = col[2]
		while not rest.is_empty():
			var st: Dictionary = rest[0]
			var sp := _split(String(st["text"]))
			var hh := UI.wrap(sc, sp[0].to_upper(), 19, w0, 3)
			var body := UI.wrap(fell, sp[1], 16, w0, 3) if sp[1] != "" else PackedStringArray()
			var need := hh.size() * 21.0 + body.size() * 19.0 + 22.0
			if yy + need > bottom:
				break
			rest.pop_front()
			for l in hh:
				yy += 21.0
				UI.text(self, Vector2(cx0, yy), l, sc, 19, ink)
			for l in body:
				yy += 19.0
				UI.text(self, Vector2(cx0, yy), l, fell, 16, ink.lightened(0.18))
			yy += 12.0
			draw_line(Vector2(cx0 + w0 * 0.3, yy), Vector2(cx0 + w0 * 0.7, yy), UI.with_a(ink, 0.7), 1.0, true)
			yy += 10.0
		col[1] = yy
	# ads: one per column first (under the picture before the others), then fill what's left
	var ad := 0
	for rnd in 2:
		for ci2 in [2, 0, 1]:
			var ca: Array = cols[ci2]
			var yy2: float = ca[1]
			while yy2 + 118.0 <= bottom and ad < ADS.size():
				var hgt := minf(130.0, bottom - yy2 - 6.0)
				_ad(Rect2(Vector2(float(ca[0]), yy2 + 4.0), Vector2(float(ca[2]), hgt)), ADS[(Game.month + ad) % ADS.size()])
				ad += 1
				yy2 += hgt + 14.0
				ca[1] = yy2
				if rnd == 0:
					break
	# the fold and the page number
	draw_line(Vector2(r.position.x, r.get_center().y + 60.0), Vector2(r.end.x, r.get_center().y + 60.0), Color(0, 0, 0, 0.05), 3.0)
	UI.text_c(self, r.get_center().x, r.end.y - 16.0, "— 1 —", fell, 14, ink.lightened(0.3))
	draw_set_transform(Vector2.ZERO)
	# how to close it
	var cond := UI.font("cond")
	var hint_y := minf(_sheet.end.y + 30.0, size.y - 14.0)
	var kw := UI.keycap_w("N", 22.0)
	var hx := size.x * 0.5 - (kw + 8.0 + UI.tw(cond, "OR CLICK TO PUT THE PAPER DOWN", 14)) * 0.5
	UI.keycap(self, Rect2(Vector2(hx, hint_y - 16), Vector2(22, 22)), "N", a)
	UI.text(self, Vector2(hx + kw + 8.0, hint_y), "OR CLICK TO PUT THE PAPER DOWN", cond, 14, UI.with_a(UI.INK, 0.8 * a))


func _paper_grain(r: Rect2) -> void:
	for k in 60:
		var p := r.position + Vector2(Draw.hash01(k, 1, 5) * r.size.x, Draw.hash01(k, 2, 5) * r.size.y)
		Draw.circle(self, p, 1.0 + Draw.hash01(k, 3, 5) * 5.0, Color(0.45, 0.33, 0.15, 0.035 + Draw.hash01(k, 4, 5) * 0.04))
	# darker edges
	for g in 6:
		draw_rect(r.grow(-g * 2.0), Color(0.4, 0.3, 0.15, 0.05 - g * 0.007), false, 2.0)


func _ear(r: Rect2, a: String, b: String) -> void:
	var sc := UI.font("fell_sc")
	draw_rect(r, UI.PAPER_INK, false, 1.0, true)
	UI.text_c(self, r.get_center().x, r.position.y + 20.0, a, sc, 16, UI.PAPER_INK)
	UI.text_c(self, r.get_center().x, r.position.y + 36.0, b, sc, 11, UI.PAPER_INK)


func _ad(r: Rect2, adv: Array) -> void:
	var ink := UI.PAPER_INK
	draw_rect(r, ink, false, 2.0, true)
	draw_rect(r.grow(-4.0), ink, false, 1.0, true)
	var sc := UI.font("fell_sc")
	var fell := UI.font("fell")
	var fs := 22
	while fs > 14 and UI.tw(sc, String(adv[0]), fs) > r.size.x - 20.0:
		fs -= 1
	UI.text_c(self, r.get_center().x, r.position.y + 34.0, UI.fit(sc, String(adv[0]), fs, r.size.x - 20), sc, fs, ink)
	UI.text_c(self, r.get_center().x, r.position.y + 60.0, UI.fit(fell, String(adv[1]), 17, r.size.x - 20), fell, 17, ink)
	draw_line(Vector2(r.position.x + 30, r.position.y + 72), Vector2(r.end.x - 30, r.position.y + 72), ink, 1.0, true)
	UI.text_c(self, r.get_center().x, r.position.y + 94.0, UI.fit(fell, String(adv[2]), 14, r.size.x - 20), fell, 14, ink.lightened(0.2))


static func _cap(s: String) -> String:
	return s.left(1).to_upper() + s.substr(1) if s != "" else s


static func _roman(n: int) -> String:
	var vals := [10, 9, 5, 4, 1]
	var syms := ["X", "IX", "V", "IV", "I"]
	var out := ""
	var v := maxi(n, 1)
	for k in vals.size():
		while v >= int(vals[k]):
			out += String(syms[k])
			v -= int(vals[k])
	return out


static func _caption(kind: String) -> String:
	match kind:
		"bank": return "Crowds outside a bank downtown. — Ledger photo."
		"booze": return "Barrels seized in a cellar on the Lower East Side."
		"police": return "Police wagons on the Bowery last night."
		"street": return "The corner where it happened. — Ledger photo."
	return "Lower Manhattan from the river, at dusk."


# ------------------------------------------------------------------ the picture (ink and halftone)

func _picture(r: Rect2, kind: String) -> void:
	var ink := UI.PAPER_INK
	Draw.rect(self, r, Color("d8ccad"))
	# halftone sky: dots grow toward the top
	var step := 6.0
	var ny := int(r.size.y / step)
	var nx := int(r.size.x / step)
	for j in ny:
		var t := 1.0 - float(j) / ny
		for i in nx:
			var rad := step * 0.5 * clampf(t * 0.9 + 0.08 * Draw.hash01(i, j, 3), 0.0, 1.0) * 0.8
			if rad > 0.5:
				draw_circle(r.position + Vector2(i + 0.5 + (j % 2) * 0.5, j + 0.5) * step, rad, UI.with_a(ink, 0.55))
	var base := r.end.y - r.size.y * 0.18
	match kind:
		"bank":
			var b := Rect2(Vector2(r.position.x + r.size.x * 0.15, base - r.size.y * 0.55), Vector2(r.size.x * 0.7, r.size.y * 0.55))
			Draw.rect(self, b, Color("d8ccad"))
			Draw.poly(self, PackedVector2Array([Vector2(b.position.x - 10, b.position.y), Vector2(b.get_center().x, b.position.y - r.size.y * 0.16), Vector2(b.end.x + 10, b.position.y)]), ink)
			Draw.rect(self, Rect2(Vector2(b.position.x - 10, b.position.y), Vector2(b.size.x + 20, 8)), ink)
			for k in 6:
				Draw.rect(self, Rect2(Vector2(b.position.x + 8 + k * (b.size.x - 16) / 5.5, b.position.y + 12), Vector2(9, b.size.y - 20)), ink)
			Draw.rect(self, Rect2(Vector2(b.position.x - 14, b.end.y - 8), Vector2(b.size.x + 28, 8)), ink)
			for k in 14:
				var hx := r.position.x + 8 + k * (r.size.x - 16) / 13.0
				Draw.circle(self, Vector2(hx, base + 10 + (k % 3) * 3), 5.0, ink)
				Draw.rect(self, Rect2(Vector2(hx - 5, base + 13 + (k % 3) * 3), Vector2(10, 20)), ink)
		"booze":
			for k in 5:
				var bc := Vector2(r.position.x + 30 + k * (r.size.x - 60) / 4.0, base - 6 - (k % 2) * 14)
				Draw.rrect(self, Rect2(bc - Vector2(20, 26), Vector2(40, 52)), 10.0, ink)
				draw_line(bc + Vector2(-20, -12), bc + Vector2(20, -12), Color("d8ccad"), 2.0)
				draw_line(bc + Vector2(-20, 12), bc + Vector2(20, 12), Color("d8ccad"), 2.0)
			for k in 3:
				var bx := r.position.x + r.size.x * 0.12 + k * 16
				Draw.rect(self, Rect2(Vector2(bx, base - 44), Vector2(9, 40)), ink)
				Draw.rect(self, Rect2(Vector2(bx + 3, base - 54), Vector2(3, 12)), ink)
		"police":
			var v := Rect2(Vector2(r.position.x + r.size.x * 0.12, base - 58), Vector2(r.size.x * 0.62, 50))
			Draw.rrect(self, v, 5.0, ink)
			Draw.rect(self, Rect2(v.position + Vector2(v.size.x - 6, 18), Vector2(40, 32)), ink)
			Draw.rect(self, Rect2(v.position + Vector2(v.size.x + 4, 22), Vector2(20, 12)), Color("d8ccad"))
			for k in 3:
				Draw.rect(self, Rect2(v.position + Vector2(14 + k * 30, 10), Vector2(18, 14)), Color("d8ccad"))
			var fnt := UI.font("fell_sc")
			UI.text(self, v.position + Vector2(10, 44), "POLICE", fnt, 14, Color("d8ccad"))
			Draw.circle(self, Vector2(v.position.x + 26, v.end.y + 2), 12.0, ink)
			Draw.circle(self, Vector2(v.end.x + 12, v.end.y + 2), 12.0, ink)
			Draw.circle(self, Vector2(v.position.x + 26, v.end.y + 2), 5.0, Color("d8ccad"))
			Draw.circle(self, Vector2(v.end.x + 12, v.end.y + 2), 5.0, Color("d8ccad"))
			_lamp(Vector2(r.end.x - 26, base + 16), r.size.y * 0.7)
		"street":
			_lamp(Vector2(r.position.x + 40, base + 16), r.size.y * 0.72)
			var car := Rect2(Vector2(r.position.x + r.size.x * 0.32, base - 34), Vector2(r.size.x * 0.56, 30))
			Draw.rrect(self, car, 6.0, ink)
			Draw.poly(self, PackedVector2Array([car.position + Vector2(car.size.x * 0.28, 0), car.position + Vector2(car.size.x * 0.36, -24), car.position + Vector2(car.size.x * 0.72, -24), car.position + Vector2(car.size.x * 0.8, 0)]), ink)
			Draw.circle(self, car.position + Vector2(car.size.x * 0.2, car.size.y), 11.0, ink)
			Draw.circle(self, car.position + Vector2(car.size.x * 0.82, car.size.y), 11.0, ink)
			Draw.ellipse(self, Vector2(r.position.x + r.size.x * 0.22, base + 20), Vector2(16, 4), ink)
			Draw.poly(self, PackedVector2Array([Vector2(r.position.x + r.size.x * 0.22 - 9, base + 20), Vector2(r.position.x + r.size.x * 0.22 - 7, base + 11), Vector2(r.position.x + r.size.x * 0.22 + 7, base + 11), Vector2(r.position.x + r.size.x * 0.22 + 9, base + 20)]), ink)
		_:
			var x := r.position.x
			var widths := [22, 16, 30, 18, 26, 14, 34, 20, 24, 18, 28]
			var heights := [0.3, 0.45, 0.62, 0.38, 0.8, 0.5, 0.55, 0.7, 0.35, 0.48, 0.3]
			for k in widths.size():
				var bw: float = float(widths[k]) * r.size.x / 260.0
				var bh: float = float(heights[k]) * r.size.y * 0.75
				Draw.rect(self, Rect2(Vector2(x, base - bh), Vector2(bw, bh + 2)), ink)
				if k == 4:
					Draw.poly(self, PackedVector2Array([Vector2(x + bw * 0.2, base - bh), Vector2(x + bw * 0.5, base - bh - 26), Vector2(x + bw * 0.8, base - bh)]), ink)
				for wy in int(bh / 9.0):
					for wxk in int(bw / 7.0):
						if Draw.hash01(k * 31 + wxk, wy, 9) > 0.55:
							Draw.rect(self, Rect2(Vector2(x + 2 + wxk * 7, base - bh + 5 + wy * 9), Vector2(2.5, 3)), Color("d8ccad"))
				x += bw + 2.0
				if x > r.end.x:
					break
	# the ground and the frame
	Draw.rect(self, Rect2(Vector2(r.position.x, base), Vector2(r.size.x, r.end.y - base)), UI.with_a(ink, 0.85))
	for k in 6:
		draw_line(Vector2(r.position.x, base + 5 + k * 6), Vector2(r.end.x, base + 5 + k * 6), UI.with_a(Color("d8ccad"), 0.12), 1.0)
	draw_rect(r, ink, false, 2.0, true)


func _lamp(foot: Vector2, h: float) -> void:
	var ink := UI.PAPER_INK
	Draw.rect(self, Rect2(foot - Vector2(2.5, h), Vector2(5, h)), ink)
	Draw.rect(self, Rect2(foot - Vector2(7, 6), Vector2(14, 6)), ink)
	Draw.poly(self, PackedVector2Array([foot + Vector2(-9, -h), foot + Vector2(9, -h), foot + Vector2(6, -h - 16), foot + Vector2(-6, -h - 16)]), ink)
	Draw.circle(self, foot + Vector2(0, -h - 8), 3.0, Color("d8ccad"))


# ------------------------------------------------------------------ the folded copy (monthly)

func _draw_mini() -> void:
	var t := _mini_t
	var a := clampf(t / 0.3, 0.0, 1.0) * clampf((MINI_LIFE - t) / 0.6, 0.0, 1.0)
	var slide := (1.0 - clampf(t / 0.35, 0.0, 1.0))
	slide = slide * slide * 420.0
	var w := 360.0
	var sp0 := _split(String(_stories[0]["text"]))
	var hl := UI.wrap(UI.font("fell_sc"), sp0[0].to_upper(), 20, w - 30.0, 3)
	var dl := UI.wrap(UI.font("fell"), sp0[1], 15, w - 40.0, 2) if sp0[1] != "" else PackedStringArray()
	var h := 82.0 + hl.size() * 22.0 + dl.size() * 18.0 + 30.0
	_mini = Rect2(Vector2(size.x - 16.0 - w + slide, mini_bottom - h), Vector2(w, h))
	var c := _mini.get_center()
	draw_set_transform(c, 0.02, Vector2.ONE)
	var r := Rect2(-_mini.size * 0.5, _mini.size)
	for g in 4:
		Draw.rect(self, Rect2(r.position + Vector2(4, 7), r.size).grow(1.0 + g * 2.5), Color(0, 0, 0, 0.1 * a))
	Draw.vgrad(self, r, UI.with_a(Color("ece3cb"), a), UI.with_a(Color("d9cdb0"), a))
	var ink := UI.with_a(UI.PAPER_INK, a)
	var fell := UI.font("fell")
	var sc := UI.font("fell_sc")
	UI.text_c(self, 0.0, r.position.y + 34.0, "The Daily Ledger", fell, 30, ink)
	draw_line(Vector2(r.position.x + 14, r.position.y + 44), Vector2(r.end.x - 14, r.position.y + 44), ink, 1.5, true)
	UI.text_c(self, 0.0, r.position.y + 58.0, "NEW YORK, %s  ·  TWO CENTS" % Game.date_text().to_upper(), sc, 12, ink)
	draw_line(Vector2(r.position.x + 14, r.position.y + 64), Vector2(r.end.x - 14, r.position.y + 64), ink, 1.0, true)
	var y := r.position.y + 70.0
	for l in hl:
		y += 22.0
		UI.text_c(self, 0.0, y, l, sc, 20, ink)
	y += 4.0
	for l in dl:
		y += 18.0
		UI.text_c(self, 0.0, y, l, fell, 15, UI.with_a(UI.PAPER_INK.lightened(0.2), a))
	draw_set_transform(Vector2.ZERO)
	# "N to read"
	var cond := UI.font("cond")
	var tag := Rect2(Vector2(_mini.position.x + 16, _mini.end.y - 10), Vector2(150, 28))
	Draw.rrect(self, tag, 6.0, Color(0.08, 0.06, 0.05, 0.92 * a))
	UI.rrect_line(self, tag, 6.0, UI.with_a(UI.BRASS, a), 1.0)
	UI.keycap(self, Rect2(tag.position + Vector2(6, 4), Vector2(20, 20)), "N", a)
	UI.text(self, Vector2(tag.position.x + 34, UI.mid(cond, 14, tag.get_center().y)), "READ THE PAPER", cond, 14, UI.with_a(UI.INK, a))
