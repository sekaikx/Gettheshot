extends Control
## The family book (Tab, or the desk in your club): a leather-bound ledger open on the don's desk,
## with index tabs down the side: Family, Rackets, Heat, Rivals, Money. Every page is drawn by
## hand (book/book_pages.gd builds them); buttons send requests to the host (Net.to_host).
##
## The HUD hosts it full-screen and toggles `visible`; it calls open() when it shows it and
## refresh() while it's up. refresh() rebuilds only when the family's data changed.
## Mouse: click tabs and buttons, the wheel turns pages. Keyboard: 1-5 or Q/E tabs, arrows choose,
## Enter does it, PageUp/PageDown turn pages. Tab / Esc (the HUD) close it.

const Art := preload("res://scripts/ui/book/art.gd")
const Icons := preload("res://scripts/ui/book/icons.gd")
const Hits := preload("res://scripts/ui/book/hits.gd")
const Pages := preload("res://scripts/ui/book/book_pages.gd")

const TABS := [
	{"id": "family", "name": "Family", "icon": "men", "color": Color("7a2e2a")},
	{"id": "rackets", "name": "Rackets", "icon": "shop", "color": Color("2e4a3a")},
	{"id": "heat", "name": "Heat", "icon": "heat", "color": Color("2a3a5a")},
	{"id": "rivals", "name": "Rivals", "icon": "crown", "color": Color("5a3a5a")},
	{"id": "money", "name": "Money", "icon": "money", "color": Color("8a6a2a")},
]
const L_CHROME := 0
const L_PAGES := 1
const L_POP := 2

var hud: Node
var world: Node

var tab := 0
var hits: Hits = Hits.new()
var lay := {}                 # rects: book, cover, left, right, content_l, content_r, tabs: [Rect2]
var flow := {}                # {mode, left: [[block]], right: [[block]], bg_l, bg_r}
var page_l := 0
var page_r := 0
var picker := {}              # {title, sub, items: [{text, sub, icon, cb, on, id}], near: Rect2}
var pages: Pages

var _desk: Control
var _pages: Control
var _chrome: Control
var _pop: Control
var _sig := 0
var _built_for := Vector2.ZERO
var _note := ""
var _note_ok := true
var _note_t := 0.0
var _press := ""
var _mouse := Vector2.ZERO
var _fade := 1.0
var _open_t := 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	clip_contents = true
	pages = Pages.new(self)
	_desk = _layer(_draw_desk)
	_pages = _layer(_draw_pages)
	_chrome = _layer(_draw_chrome)
	_pop = _layer(_draw_pop)
	resized.connect(_on_resized)
	visibility_changed.connect(func() -> void:
		if not visible:
			_close_picker()
		set_process(visible))
	Game.state_changed.connect(func() -> void:
		if visible:
			refresh())
	Net.event.connect(_on_net_event)
	set_process(visible)
	_on_resized()


func _layer(fn: Callable) -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.focus_mode = Control.FOCUS_NONE
	c.draw.connect(fn)
	add_child(c)
	return c


# ------------------------------------------------------------------ the contract

func open() -> void:
	if world == null and hud != null:
		world = hud.get("world")
	_close_picker()
	hits.focus = ""
	hits.keys = false
	_sig = 0
	refresh()
	_open_t = 0.0
	modulate.a = 0.0
	_sound("paper_open", -8.0)


func refresh() -> void:
	if not is_inside_tree():
		return
	if world == null and hud != null:
		world = hud.get("world")
	var s := pages.signature(tab)
	if s == _sig and _built_for == size:
		return
	_sig = s
	_rebuild()


# ------------------------------------------------------------------ layout

func _on_resized() -> void:
	var S := size if size.x > 10.0 else Vector2(1600, 900)
	var tabs_w := 112.0
	var bw := minf(S.x - 60.0 - tabs_w, 1420.0)
	var bh := minf(S.y - 104.0, 840.0)
	var bx := floorf((S.x - tabs_w - bw) * 0.5) + 6.0
	var by := floorf((S.y - 34.0 - bh) * 0.5) + 6.0
	var book := Rect2(bx, by, bw, bh)
	var pagesr := book.grow(-14.0)
	var half := floorf(pagesr.size.x * 0.5)
	var left := Rect2(pagesr.position, Vector2(half, pagesr.size.y))
	var right := Rect2(pagesr.position + Vector2(half, 0), Vector2(pagesr.size.x - half, pagesr.size.y))
	var top := 62.0
	var bottom := 58.0
	var outer := 46.0
	var inner := 40.0
	var cl := Rect2(left.position + Vector2(outer, top), Vector2(left.size.x - outer - inner, left.size.y - top - bottom))
	var cr := Rect2(right.position + Vector2(inner, top), Vector2(right.size.x - outer - inner, right.size.y - top - bottom))
	var tabs: Array = []
	var th := minf(104.0, (bh - 120.0) / TABS.size() - 8.0)
	for k in TABS.size():
		tabs.append(Rect2(book.end.x - 4.0, book.position.y + 64.0 + k * (th + 8.0), tabs_w - 4.0, th))
	lay = {"S": S, "book": book, "pages": pagesr, "left": left, "right": right, "content_l": cl, "content_r": cr,
		"tabs": tabs, "close": Rect2(book.end.x - 4.0, book.position.y + 6.0, tabs_w - 4.0, 44.0)}
	_desk.queue_redraw()
	if visible:
		refresh()


func content_width() -> float:
	return (lay["content_l"] as Rect2).size.x


func content_height() -> float:
	return (lay["content_l"] as Rect2).size.y


func _rebuild() -> void:
	_built_for = size
	var cw := content_width()
	var ch := content_height()
	var built: Dictionary = pages.build(String(TABS[tab]["id"]), cw)
	var mode := String(built.get("mode", "split"))
	flow = {"mode": mode, "bg_l": built.get("bg_l", Callable()), "bg_r": built.get("bg_r", Callable())}
	if mode == "spread":
		var all := _paginate(built.get("blocks", []), ch)
		var l: Array = []
		var r: Array = []
		for k in all.size():
			(l if k % 2 == 0 else r).append(all[k])
		if r.size() < l.size():
			r.append([])
		flow["left"] = l
		flow["right"] = r
	else:
		flow["left"] = _paginate(built.get("left", []), ch)
		flow["right"] = _paginate(built.get("right", []), ch)
	page_l = clampi(page_l, 0, (flow["left"] as Array).size() - 1)
	page_r = clampi(page_r, 0, (flow["right"] as Array).size() - 1)
	if mode == "spread":
		page_r = page_l
	_pages.queue_redraw()
	_chrome.queue_redraw()
	_pop.queue_redraw()


## Blocks -> pages. A block may ask for a new page ("brk"); a heading stays with what follows ("keep").
func _paginate(blocks: Array, h: float) -> Array:
	var out: Array = []
	var cur: Array = []
	var y := 0.0
	for k in blocks.size():
		var b: Dictionary = blocks[k]
		var bh := float(b["h"])
		var need := bh
		if bool(b.get("keep", false)) and k + 1 < blocks.size():
			need += float((blocks[k + 1] as Dictionary)["h"])
		if not cur.is_empty() and (bool(b.get("brk", false)) or y + need > h + 0.5):
			out.append(cur)
			cur = []
			y = 0.0
		cur.append(b)
		y += bh
	out.append(cur)
	return out


func _pages_of(side: String) -> Array:
	return flow.get(side, [[]])


# ------------------------------------------------------------------ drawing: the desk and the book

func _draw_desk() -> void:
	var ci := _desk
	var S: Vector2 = lay["S"]
	var book: Rect2 = lay["book"]
	Art.desk(ci, Rect2(Vector2.ZERO, S), 11)
	_props(ci, book)
	Art.drop_shadow(ci, Rect2(book.position, book.size + Vector2(20, 0)), Vector2(10, 16), 26.0, 0.7)
	# the cover: oxblood leather, gold tooling, brass corners
	var cover := book.grow(4.0)
	Art.box(ci, cover, Art.LEATHER, Color("2a100a"), 1, 10)
	var rng := W.rng(77)
	for k in int(cover.size.x * cover.size.y / 260.0):
		var p := cover.position + Vector2(rng.randf() * cover.size.x, rng.randf() * cover.size.y)
		ci.draw_rect(Rect2(p, Vector2(2, 1)), Color(0, 0, 0, 0.12) if rng.randf() < 0.5 else Color(1, 0.8, 0.6, 0.04))
	ci.draw_rect(cover.grow(-6.0), Color(Art.GOLD, 0.45), false, 1.0)
	for k in 4:
		var o: Vector2 = [cover.position, Vector2(cover.end.x, cover.position.y), cover.end, Vector2(cover.position.x, cover.end.y)][k]
		var dx := 1.0 if k in [0, 3] else -1.0
		var dy := 1.0 if k in [0, 1] else -1.0
		var tri := PackedVector2Array([o, o + Vector2(dx * 34, 0), o + Vector2(0, dy * 34)])
		Draw.poly(ci, tri, Art.BRASS.darkened(0.15))
		ci.draw_line(o + Vector2(dx * 30, dy * 2), o + Vector2(dx * 2, dy * 30), Color(1, 1, 1, 0.3), 1.0, true)
	# the page block: a few page edges peeking out under each page
	var pr: Rect2 = lay["pages"]
	for k in range(4, 0, -1):
		var e := float(k) * 1.6
		ci.draw_rect(Rect2(pr.position + Vector2(-e, e * 0.6), pr.size + Vector2(e * 2.0, e * 0.4)), Color("d9ccaa").darkened(0.05 * k))
	var L: Rect2 = lay["left"]
	var R: Rect2 = lay["right"]
	Art.paper(ci, L, 21)
	Art.paper(ci, R, 22)
	# the gutter: pages curve down into the spine
	var g := 70.0
	Draw.hgrad(ci, Rect2(Vector2(L.end.x - g, L.position.y), Vector2(g, L.size.y)), Color(0.3, 0.2, 0.1, 0.0), Color(0.3, 0.2, 0.1, 0.3))
	Draw.hgrad(ci, Rect2(R.position, Vector2(g * 0.8, R.size.y)), Color(0.3, 0.2, 0.1, 0.34), Color(0.3, 0.2, 0.1, 0.0))
	ci.draw_line(Vector2(L.end.x, L.position.y), Vector2(L.end.x, L.end.y), Color(0.2, 0.12, 0.05, 0.45), 1.5)
	# the silk ribbon, hanging out at the bottom
	var rx := L.end.x - 26.0
	var rib := PackedVector2Array([Vector2(rx, L.end.y - 30), Vector2(rx + 14, L.end.y - 30), Vector2(rx + 18, book.end.y + 48),
		Vector2(rx + 10, book.end.y + 40), Vector2(rx + 3, book.end.y + 50)])
	Draw.shadow(ci, rib, Vector2(3, 4), Color(0, 0, 0, 0.3))
	Draw.poly(ci, rib, Color("8b1e1a"))
	ci.draw_line(Vector2(rx + 4, L.end.y - 30), Vector2(rx + 8, book.end.y + 44), Color(1, 1, 1, 0.12), 1.0)


## Things on the desk around the book: the fountain pen, a whisky glass ring, the ashtray.
func _props(ci: Control, book: Rect2) -> void:
	var S: Vector2 = lay["S"]
	# a wet ring where a glass stood, and the glass of rye itself, right of the book under the tabs
	ci.draw_arc(Vector2(book.position.x + 150, book.end.y + 30), 27.0, 0.4, TAU - 0.3, 40, Color(0, 0, 0, 0.2), 2.5, true)
	var g := Vector2(minf(book.end.x + 60.0, S.x - 44.0), book.end.y - 116.0)
	Art.glow(ci, g + Vector2(12, 16), Vector2(44, 44), Color(0, 0, 0, 0.55))
	Draw.circle(ci, g, 31.0, Color(0.8, 0.84, 0.86, 0.35))
	Draw.circle(ci, g, 26.0, Color("4a2408"))
	Draw.circle(ci, g + Vector2(2, 2), 22.0, Color("7a4212"))
	Art.glow(ci, g + Vector2(6, 7), Vector2(16, 16), Color(1.0, 0.7, 0.3, 0.35))
	Draw.rrect(ci, Rect2(g + Vector2(-15, -14), Vector2(14, 14)), 3.0, Color(0.9, 0.85, 0.75, 0.35))
	Draw.rrect(ci, Rect2(g + Vector2(1, -5), Vector2(12, 12)), 3.0, Color(0.9, 0.85, 0.75, 0.28))
	ci.draw_arc(g, 29.0, PI * 1.0, PI * 1.6, 14, Color(1, 1, 1, 0.55), 2.0, true)
	ci.draw_arc(g, 31.0, 0.0, TAU, 40, Color(1, 1, 1, 0.18), 1.0, true)
	# the fountain pen, lower right, under the tabs
	var p0 := Vector2(minf(book.end.x + 100, S.x - 10), book.end.y - 24)
	var p1 := p0 + Vector2(-96, 60)
	Draw.capsule(ci, p0 + Vector2(3, 5), p1 + Vector2(3, 5), 7.0, Color(0, 0, 0, 0.35))
	Draw.capsule(ci, p0, p1, 7.0, Color("15120f"))
	ci.draw_line(p0.lerp(p1, 0.3), p0.lerp(p1, 0.34), Art.BRASS, 14.0)
	Draw.poly(ci, PackedVector2Array([p1 + Vector2(2, -6), p1 + Vector2(-26, -2), p1 + Vector2(2, 6)]), Art.BRASS)
	ci.draw_line(p0.lerp(p1, 0.05) + Vector2(0, -3), p0.lerp(p1, 0.9) + Vector2(0, -4), Color(1, 1, 1, 0.16), 1.5, true)


# ------------------------------------------------------------------ drawing: pages

func _draw_pages() -> void:
	hits.clear(L_PAGES)
	if flow.is_empty():
		return
	var pl := _pages_of("left")
	var pr := _pages_of("right")
	var cl: Rect2 = lay["content_l"]
	var cr: Rect2 = lay["content_r"]
	var bgl: Callable = flow.get("bg_l", Callable())
	var bgr: Callable = flow.get("bg_r", Callable())
	if bgl.is_valid():
		bgl.call(_pages, cl)
	if bgr.is_valid():
		bgr.call(_pages, cr)
	_draw_stream(pl[clampi(page_l, 0, pl.size() - 1)] if not pl.is_empty() else [], cl)
	_draw_stream(pr[clampi(page_r, 0, pr.size() - 1)] if not pr.is_empty() else [], cr)


func _draw_stream(blocks: Array, r: Rect2) -> void:
	var y := r.position.y
	for b in blocks:
		var bh := float(b["h"])
		var fn: Callable = b["draw"]
		if fn.is_valid():
			fn.call(_pages, Rect2(Vector2(r.position.x, y), Vector2(r.size.x, bh)))
		y += bh


## A button on a page (or on the chrome/picker layer). Draws it and makes it clickable.
func btn(ci: CanvasItem, layer: int, id: String, r: Rect2, label: String, cb: Callable, style: String = "ink",
		on: bool = true, tip: String = "", icon: String = "", sub: String = "", fsize: int = 17) -> void:
	hits.add(layer, id, r, cb, on, tip)
	var hot: bool = hits.hot(id)
	Art.button(ci, r, label, style, hot, on, sub, icon, fsize)
	if hits.keys and hits.focus == id:
		ci.draw_rect(r.grow(3.0), Color(Art.GOLD, 0.9), false, 2.0)


# ------------------------------------------------------------------ drawing: tabs, heads, footer

func _draw_chrome() -> void:
	var ci := _chrome
	hits.clear(L_CHROME)
	var book: Rect2 = lay["book"]
	var L: Rect2 = lay["left"]
	var R: Rect2 = lay["right"]
	var cl: Rect2 = lay["content_l"]
	var cr: Rect2 = lay["content_r"]
	var me := pages.me()
	var f := Game.fam(me)
	# running heads
	var head_y := L.position.y + 36.0
	if not f.is_empty():
		Art.crest(ci, Vector2(cl.position.x + 11, head_y - 6), 24.0, Art.fam_color(me), "", false)
		Art.text(ci, Vector2(cl.position.x + 30, head_y), "THE %s FAMILY" % String(f["name"]).to_upper(), "fell_sc", 16, Art.INK_SOFT)
	Art.text_r(ci, Vector2(cr.end.x, head_y), Game.date_text().to_upper(), "fell_sc", 16, Art.INK_SOFT)
	Art.text_c(ci, Vector2(R.get_center().x, head_y), String(TABS[tab]["name"]).to_upper(), "fell_sc", 16, TABS[tab]["color"])
	ci.draw_line(Vector2(cl.position.x, head_y + 10), Vector2(cl.end.x, head_y + 10), Color(Art.INK_SOFT, 0.35), 1.0)
	ci.draw_line(Vector2(cr.position.x, head_y + 10), Vector2(cr.end.x, head_y + 10), Color(Art.INK_SOFT, 0.35), 1.0)
	# page numbers and turning
	var pl := _pages_of("left")
	var pr := _pages_of("right")
	var foot_y := L.end.y - 24.0
	var spread := String(flow.get("mode", "")) == "spread"
	var nl := page_l * 2 + 1 if spread else page_l + 1
	var nr := page_l * 2 + 2 if spread else page_r + 1
	var total_l := pl.size() * 2 if spread else pl.size()
	_folio(ci, Vector2(cl.get_center().x, foot_y), nl, total_l if not spread else -1)
	_folio(ci, Vector2(cr.get_center().x, foot_y), nr, pr.size() if not spread else -1)
	if spread:
		if page_l > 0:
			_turn(ci, "turn_prev", Rect2(cl.position.x - 6, foot_y - 22, 130, 32), "Back", "left", func() -> void: turn(-1, "left"))
		if page_l < pl.size() - 1:
			_turn(ci, "turn_next", Rect2(cr.end.x - 124, foot_y - 22, 130, 32), "Next page", "right", func() -> void: turn(1, "left"))
	else:
		if page_l > 0:
			_turn(ci, "turn_lp", Rect2(cl.position.x - 6, foot_y - 22, 110, 32), "Back", "left", func() -> void: turn(-1, "left"))
		if page_l < pl.size() - 1:
			_turn(ci, "turn_ln", Rect2(cl.end.x - 104, foot_y - 22, 110, 32), "More", "right", func() -> void: turn(1, "left"))
		if page_r > 0:
			_turn(ci, "turn_rp", Rect2(cr.position.x - 6, foot_y - 22, 110, 32), "Back", "left", func() -> void: turn(-1, "right"))
		if page_r < pr.size() - 1:
			_turn(ci, "turn_rn", Rect2(cr.end.x - 104, foot_y - 22, 110, 32), "More", "right", func() -> void: turn(1, "right"))
	# index tabs down the side
	var tabs: Array = lay["tabs"]
	for k in TABS.size():
		_tab(ci, k, tabs[k])
	# close
	var cr2: Rect2 = lay["close"]
	var cid := "close"
	hits.add(L_CHROME, cid, cr2, func() -> void: _close(), true, "")
	var hot: bool = hits.hot(cid)
	Art.box(ci, cr2, Color("2a211a") if not hot else Color("3a2e22"), Color("0d0906"), 1, 5, 4, Vector2(2, 3), 0.4)
	Icons.draw(ci, "x", cr2.position + Vector2(20, cr2.size.y * 0.5), 14.0, Art.GOLD_LIGHT if hot else Color("d8c9a6"))
	Art.text(ci, Vector2(cr2.position.x + 32, cr2.position.y + 28), "Close", "cond", 18, Art.GOLD_LIGHT if hot else Color("e6d8b8"))
	Art.keycap(ci, Vector2(cr2.position.x + 32 + Art.text_w("Close", "cond", 18) + 8, cr2.position.y + 28), "Tab", true, 12)
	# footer: keys, and the last word from the host
	var S: Vector2 = lay["S"]
	var fy := minf(S.y - 12.0, book.end.y + 30.0)
	var x := book.position.x + 40.0
	x = _hint(ci, x, fy, "1–5", "tabs")
	x = _hint(ci, x, fy, "↑↓←→", "choose")
	x = _hint(ci, x, fy, "Enter", "do it")
	x = _hint(ci, x, fy, "PgDn", "next page")
	x = _hint(ci, x, fy, "Tab", "close")
	if _note != "" and _note_t > 0.0:
		var a := clampf(_note_t, 0.0, 1.0)
		var w := minf(Art.text_w(_note, "semi", 17) + 44.0, 760.0)
		var nr2 := Rect2(Vector2(book.end.x - w - 24.0, fy - 26.0), Vector2(w, 36))
		Art.box(ci, nr2, Color(Art.PAPER_LIGHT, a), Color(Art.OXBLOOD if not _note_ok else Art.GREEN_INK, a), 1, 3, 6, Vector2(2, 4), 0.4 * a)
		Icons.draw(ci, "check" if _note_ok else "bang", nr2.position + Vector2(18, 18), 14.0, Color(Art.GREEN_INK if _note_ok else Art.OXBLOOD, a))
		Art.text(ci, nr2.position + Vector2(32, 24), Art.fit(_note, "semi", 17, w - 44.0), "semi", 17, Color(Art.INK, a))


func _hint(ci: CanvasItem, x: float, y: float, key: String, what: String) -> float:
	var w := Art.keycap(ci, Vector2(x, y), key, true, 13)
	Art.text(ci, Vector2(x + w + 6, y), what, "sans", 15, Color("b8a888"))
	return x + w + 6 + Art.text_w(what, "sans", 15) + 22.0


func _folio(ci: CanvasItem, c: Vector2, n: int, total: int) -> void:
	var s := "— %d —" % n if total <= 1 else "%d of %d" % [n, total]
	Art.text_c(ci, c + Vector2(0, 4), s, "fell", 17, Art.INK_SOFT)


func _turn(ci: CanvasItem, id: String, r: Rect2, label: String, dir: String, cb: Callable) -> void:
	hits.add(L_CHROME, id, r, cb, true, "")
	var hot: bool = hits.hot(id)
	var col := Art.OXBLOOD if hot else Art.INK_SOFT
	var left := dir == "left"
	var ix := r.position.x + 14.0 if left else r.end.x - 14.0
	Icons.draw(ci, dir, Vector2(ix, r.position.y + 16), 14.0, col)
	if left:
		Art.text(ci, Vector2(ix + 14, r.position.y + 22), label, "cond", 18, col)
	else:
		Art.text_r(ci, Vector2(ix - 14, r.position.y + 22), label, "cond", 18, col)
	if hot:
		var tw := Art.text_w(label, "cond", 18)
		var ux := ix + 14 if left else ix - 14 - tw
		ci.draw_line(Vector2(ux, r.position.y + 26), Vector2(ux + tw, r.position.y + 26), col, 1.0)


func _tab(ci: CanvasItem, k: int, r: Rect2) -> void:
	var t: Dictionary = TABS[k]
	var id := "tab_%d" % k
	var active := k == tab
	hits.add(L_CHROME, id, r, func() -> void: set_tab(k), true, "")
	var hot: bool = hits.hot(id)
	var col: Color = t["color"]
	var rr := Rect2(r.position, Vector2(r.size.x - (0.0 if active or hot else 10.0), r.size.y))
	# the tab is glued under the right page: only its outer part shows
	Art.box(ci, Rect2(rr.position + Vector2(3, 3), rr.size), Color(0, 0, 0, 0.35), Color(0, 0, 0, 0), 0, 7)
	var fill := col.lightened(0.12) if hot and not active else col
	if active:
		fill = Art.PAPER
	Art.box(ci, rr, fill, col.darkened(0.35) if not active else Art.CARD_EDGE, 1, 7)
	if active:
		ci.draw_rect(Rect2(rr.position, Vector2(10, rr.size.y)), Art.PAPER)
		ci.draw_rect(Rect2(rr.end.x - 7, rr.position.y + 8, 3, rr.size.y - 16), col)
	else:
		ci.draw_line(rr.position + Vector2(12, 3), Vector2(rr.end.x - 8, rr.position.y + 3), Color(1, 1, 1, 0.14), 1.0)
	var ink := col if active else Color("efe4c8")
	var cx := rr.position.x + 12.0 + (rr.size.x - 12.0) * 0.5
	Icons.draw(ci, String(t["icon"]), Vector2(cx, rr.position.y + rr.size.y * 0.36), minf(28.0, rr.size.y * 0.3), ink, fill)
	Art.text_c(ci, Vector2(cx, rr.position.y + rr.size.y * 0.36 + 34.0), String(t["name"]), "cond", 19, ink)
	Art.text(ci, rr.position + Vector2(rr.size.x - 18.0, 18.0), str(k + 1), "cond", 13, Color(ink, 0.6))
	if hits.keys and hits.focus == id:
		ci.draw_rect(rr.grow(2.0), Color(Art.GOLD, 0.9), false, 2.0)


# ------------------------------------------------------------------ the picker (a slip of paper over the book)

## Shows a list to choose from: "Guard which shop?". items: [{text, sub, icon, cb, on}]
func pick(title: String, sub: String, items: Array, near: Rect2) -> void:
	picker = {"title": title, "sub": sub, "items": items, "near": near, "scroll": 0}
	hits.modal = L_POP
	hits.focus = "pick_0" if not items.is_empty() else "pick_cancel"
	_pop.queue_redraw()
	_pages.queue_redraw()
	_sound("page_turn", -16.0)


func _close_picker() -> void:
	if picker.is_empty():
		return
	picker = {}
	hits.modal = -1
	hits.clear(L_POP)
	hits.focus = ""
	if _pop:
		_pop.queue_redraw()


func _draw_pop() -> void:
	var ci := _pop
	hits.clear(L_POP)
	if picker.is_empty():
		_draw_tip(ci)
		return
	var S: Vector2 = lay["S"]
	ci.draw_rect(Rect2(Vector2.ZERO, S), Color(0.05, 0.03, 0.02, 0.35))
	var items: Array = picker["items"]
	var w := 440.0
	var row := 52.0
	var max_rows := clampi(int((S.y - 300.0) / row), 3, 12)
	var shown := mini(items.size(), max_rows)
	var scroll := clampi(int(picker.get("scroll", 0)), 0, maxi(0, items.size() - shown))
	picker["scroll"] = scroll
	picker["rows"] = shown
	var h := 104.0 + maxf(1, shown) * row + 56.0
	var near: Rect2 = picker["near"]
	var x := clampf(near.get_center().x - w * 0.5, 20.0, S.x - w - 20.0)
	var y := clampf(near.end.y + 8.0, 20.0, S.y - h - 20.0)
	if near.end.y + 8.0 + h > S.y - 20.0:
		y = clampf(near.position.y - h - 8.0, 20.0, S.y - h - 20.0)
	var r := Rect2(x, y, w, h)
	Art.drop_shadow(ci, r, Vector2(6, 10), 16.0, 0.6)
	Art.box(ci, r, Art.PAPER_LIGHT, Art.CARD_EDGE, 1, 3)
	ci.draw_rect(Rect2(r.position, Vector2(w, 5)), Art.OXBLOOD)
	Art.text(ci, r.position + Vector2(22, 44), String(picker["title"]), "serif", 24, Art.INK)
	Art.text(ci, r.position + Vector2(22, 72), Art.fit(String(picker["sub"]), "fell", 17, w - 44.0), "fell", 17, Art.INK_SOFT)
	var yy := r.position.y + 90.0
	if items.is_empty():
		Art.text(ci, Vector2(r.position.x + 22, yy + 30), "Nothing to choose from.", "fell", 18, Art.INK_SOFT)
	picker["rect"] = r
	for k in range(scroll, scroll + shown):
		var it: Dictionary = items[k]
		var br := Rect2(r.position.x + 16, yy, w - 32, row - 6)
		var cb: Callable = it.get("cb", Callable())
		var pid := "pick_%d" % k
		var pcb := func() -> void:
			_close_picker()
			if cb.is_valid():
				cb.call()
		hits.add(L_POP, pid, br, pcb, bool(it.get("on", true)), String(it.get("tip", "")))
		var hot: bool = hits.hot(pid)
		Art.button(ci, br, "", "row", hot, bool(it.get("on", true)))
		var tx := br.position.x + 16.0
		if String(it.get("icon", "")) != "":
			Icons.badge(ci, String(it["icon"]), Vector2(tx + 14, br.get_center().y), 14.0, it.get("color", Art.INK_SOFT), Color(0, 0, 0, 0.35), Color("f4ecd6"), false)
			tx += 38.0
		var ink := Art.OXBLOOD if hot else Art.INK
		if not bool(it.get("on", true)):
			ink = Color(Art.INK_SOFT, 0.6)
		Art.text(ci, Vector2(tx, br.position.y + 21), Art.fit(String(it.get("text", "")), "semi", 18, br.end.x - tx - 10), "semi", 18, ink)
		Art.text(ci, Vector2(tx, br.position.y + 40), Art.fit(String(it.get("sub", "")), "sans", 15, br.end.x - tx - 10), "sans", 15, Art.INK_SOFT)
		if hits.keys and hits.focus == pid:
			ci.draw_rect(br.grow(2.0), Color(Art.GOLD, 0.9), false, 2.0)
		yy += row
	var cbr := Rect2(r.end.x - 136, r.end.y - 48, 120, 34)
	hits.add(L_POP, "pick_cancel", cbr, func() -> void: _close_picker(), true, "")
	Art.button(ci, cbr, "Never mind", "ink", hits.hot("pick_cancel"), true, "", "", 17)
	if hits.keys and hits.focus == "pick_cancel":
		ci.draw_rect(cbr.grow(2.0), Color(Art.GOLD, 0.9), false, 2.0)
	var more := ""
	if items.size() > shown:
		more = "%d–%d of %d · wheel for more" % [scroll + 1, scroll + shown, items.size()]
		if scroll > 0:
			Icons.draw(ci, "up", Vector2(r.get_center().x, r.position.y + 86), 12.0, Art.INK_SOFT)
		if scroll + shown < items.size():
			Icons.draw(ci, "down", Vector2(r.get_center().x, yy + 2), 12.0, Art.INK_SOFT)
	Art.text(ci, Vector2(r.position.x + 22, r.end.y - 25), more if more != "" else "Esc: never mind", "sans", 15, Color(Art.INK_SOFT, 0.85))


## A small note under the button the mouse (or the keyboard) is on, when it has something to say.
func _draw_tip(ci: CanvasItem) -> void:
	var id: String = hits.hover if hits.hover != "" else (hits.focus if hits.keys else "")
	if id == "":
		return
	var h: Dictionary = hits.find(id)
	if h.is_empty() or String(h.get("tip", "")) == "":
		return
	var tip := String(h["tip"])
	var S: Vector2 = lay["S"]
	var br: Rect2 = h["rect"]
	var w := minf(Art.text_w(tip, "sans", 16) + 28.0, 380.0)
	var lines := Art.lines_of(tip, "sans", 16, w - 28.0)
	var th := 16.0 + lines.size() * 21.0
	var x := clampf(br.get_center().x - w * 0.5, 10.0, S.x - w - 10.0)
	var y := br.end.y + 8.0
	if y + th > S.y - 10.0:
		y = br.position.y - th - 8.0
	var r := Rect2(x, y, w, th)
	Art.box(ci, r, Color("2a211a"), Color("0d0906"), 1, 4, 6, Vector2(2, 4), 0.45)
	Art.para(ci, r.position + Vector2(14, 7), tip, "sans", 16, Color("efe4c8"), w - 28.0, 21.0)


# ------------------------------------------------------------------ actions

func set_tab(k: int) -> void:
	k = wrapi(k, 0, TABS.size())
	if k == tab:
		return
	tab = k
	page_l = 0
	page_r = 0
	hits.focus = ""
	_close_picker()
	_sig = 0
	refresh()
	_fade = 0.25
	_sound("page_turn", -10.0)


func turn(d: int, side: String) -> void:
	var spread := String(flow.get("mode", "")) == "spread"
	var n := _pages_of("left").size() if side == "left" or spread else _pages_of("right").size()
	var cur := page_l if side == "left" or spread else page_r
	var nxt := clampi(cur + d, 0, n - 1)
	if nxt == cur:
		return
	if side == "left" or spread:
		page_l = nxt
		if spread:
			page_r = nxt
	else:
		page_r = nxt
	hits.focus = ""
	_fade = 0.25
	_pages.queue_redraw()
	_chrome.queue_redraw()
	_sound("page_turn", -10.0)


## Sends a request to the host, and redraws once the answer is in.
func ask(method: String, args: Array) -> void:
	Net.to_host(method, args)
	_sound("click_wood", -10.0)
	call_deferred("refresh")


func _close() -> void:
	if hud and hud.has_method("toggle_family"):
		hud.call("toggle_family")
	else:
		visible = false


func _sound(name: String, db: float) -> void:
	if world == null and hud != null:
		world = hud.get("world")
	if world and world.get("audio") and world.audio.has_method("ui"):
		world.audio.ui(name, db)


func _on_net_event(n: String, args: Array) -> void:
	if not visible or n != "reply" or args.is_empty():
		return
	var msg := String(args[0])
	if msg == "":
		return
	_note = msg
	_note_ok = bool(args[1]) if args.size() > 1 else true
	_note_t = 6.0
	_chrome.queue_redraw()
	call_deferred("refresh")


func _process(delta: float) -> void:
	if _note_t > 0.0:
		_note_t -= delta
		if _note_t < 1.0:
			_chrome.queue_redraw()
	if _fade < 1.0:
		_fade = minf(1.0, _fade + delta * 5.0)
		_pages.modulate.a = 0.35 + 0.65 * _fade
	if _open_t < 1.0:
		_open_t = minf(1.0, _open_t + delta * 7.0)
		modulate.a = _open_t


# ------------------------------------------------------------------ input

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		_mouse = (e as InputEventMouseMotion).position
		_hover(_mouse)
		return
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			var h: Dictionary = hits.at(mb.position)
			if mb.pressed:
				_press = String(h.get("id", ""))
				if h.is_empty() and not picker.is_empty():
					_close_picker()
					_redraw_all()
			else:
				if _press != "" and String(h.get("id", "")) == _press:
					hits.keys = false
					if hits.press(_press):
						_redraw_all()
				_press = ""
			accept_event()
		elif mb.pressed and mb.button_index in [MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_UP]:
			var d := 1 if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1
			if not picker.is_empty():
				picker["scroll"] = int(picker.get("scroll", 0)) + d
				_pop.queue_redraw()
				_hover(mb.position)
			else:
				var side := "left" if mb.position.x < (lay["right"] as Rect2).position.x else "right"
				turn(d, side)
			accept_event()


func _hover(p: Vector2) -> void:
	var h: Dictionary = hits.at(p)
	var id := String(h.get("id", ""))
	var was_keys: bool = hits.keys
	hits.keys = false
	if id != hits.hover or was_keys:
		hits.hover = id
		_redraw_all()
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if id != "" and bool(h.get("on", true)) else Control.CURSOR_ARROW


func _redraw_all() -> void:
	_pages.queue_redraw()
	_chrome.queue_redraw()
	_pop.queue_redraw()


func _input(e: InputEvent) -> void:
	if not is_visible_in_tree() or not (e is InputEventKey) or not e.pressed:
		return
	var k := (e as InputEventKey).keycode
	if not picker.is_empty() and _picker_key(k):
		hits.keys = true
		_pop.queue_redraw()
		get_viewport().set_input_as_handled()
		return
	var used := true
	match k:
		KEY_ESCAPE:
			if picker.is_empty():
				return
			_close_picker()
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
			if picker.is_empty():
				set_tab(k - KEY_1)
		KEY_Q:
			if picker.is_empty():
				set_tab(tab - 1)
		KEY_E:
			if picker.is_empty():
				set_tab(tab + 1)
		KEY_UP, KEY_W:
			hits.nav(Vector2.UP)
		KEY_DOWN, KEY_S:
			hits.nav(Vector2.DOWN)
		KEY_LEFT, KEY_A:
			if not hits.nav(Vector2.LEFT) and picker.is_empty():
				turn(-1, "left" if _focus_side() == "left" else "right")
		KEY_RIGHT, KEY_D:
			if not hits.nav(Vector2.RIGHT) and picker.is_empty():
				turn(1, "left" if _focus_side() == "left" else "right")
		KEY_PAGEDOWN:
			turn(1, _focus_side())
		KEY_PAGEUP:
			turn(-1, _focus_side())
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			if hits.focus == "":
				hits.nav(Vector2.DOWN)
			else:
				hits.press(hits.focus)
		_:
			used = false
	if used:
		hits.keys = true
		_redraw_all()
		get_viewport().set_input_as_handled()


## Keys while the picker is open: up and down go through the list (it scrolls), Enter picks.
func _picker_key(k: int) -> bool:
	var items: Array = picker["items"]
	var n := items.size()
	var sel := n
	if hits.focus.begins_with("pick_") and hits.focus != "pick_cancel":
		sel = int(hits.focus.substr(5))
	match k:
		KEY_UP, KEY_W, KEY_DOWN, KEY_S:
			var up := k in [KEY_UP, KEY_W]
			sel = wrapi(sel + (-1 if up else 1), 0, n + 1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			if sel >= n:
				_close_picker()
			else:
				var it: Dictionary = items[sel]
				if bool(it.get("on", true)):
					var cb: Callable = it.get("cb", Callable())
					_close_picker()
					if cb.is_valid():
						cb.call()
			_redraw_all()
			return true
		KEY_ESCAPE:
			_close_picker()
			_redraw_all()
			return true
		_:
			return false
	hits.focus = "pick_cancel" if sel >= n else "pick_%d" % sel
	if sel < n:
		var rows := int(picker.get("rows", 8))
		var sc := int(picker.get("scroll", 0))
		if sel < sc:
			picker["scroll"] = sel
		elif sel >= sc + rows:
			picker["scroll"] = sel - rows + 1
	return true


func _focus_side() -> String:
	var h: Dictionary = hits.find(hits.focus)
	if h.is_empty():
		return "left"
	return "left" if (h["rect"] as Rect2).get_center().x < (lay["right"] as Rect2).position.x else "right"
