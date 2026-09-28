extends Control
## J: the country. Cities with a ring showing who holds how much of each and marks for the
## supply sites (docks, warehouse, brewery/still, rail yard); smuggling routes along their real
## water and roads, in the colour of whoever bought the officials along them; freight rail lines;
## your convoys and freight moving. Click a city, a source, a route or a rail line to see it and
## give orders: send men and guns, a capo, buy the police, order a hit, take the city's sites,
## run booze, buy a route, ambush a route, ship crates by rail.
##
## Everything is placed by latitude/longitude through Syndicate.project() (MapProjection when the
## baked map exists). The coastline below is a rough outline to draw on until then.

const INK := Color("efe6d2")
const MUTE := Color("9b907c")
const GOLD2 := Color("f0d58a")
const LAND := Color("2b2620")
const LAND_EDGE := Color("4a3d2c")
const WATER := Color("0f171d")
const RIVER := Color("1c2a33")
const RAIL := Color("8a7f6c")

# rough outlines, [lat, lon]
const COAST := [[52.0, -104.0], [52.0, -56.0], [51.4, -56.8], [50.2, -60.0], [50.2, -66.4], [49.3, -67.5], [48.6, -69.3],
	[47.9, -69.9], [47.0, -70.9], [47.2, -70.3], [48.0, -69.2], [48.6, -68.0], [49.1, -66.5], [48.8, -64.3], [47.8, -65.0],
	[46.3, -64.6], [45.8, -62.6], [47.0, -60.5], [46.1, -59.8], [45.3, -61.0], [44.5, -63.5], [43.5, -65.7], [44.6, -66.2],
	[45.3, -64.3], [45.1, -66.1], [44.9, -66.9], [44.4, -68.2], [43.9, -69.5], [43.6, -70.3], [42.6, -70.7], [42.35, -71.0],
	[42.0, -70.7], [41.7, -70.0], [41.55, -70.6], [41.5, -71.4], [41.3, -72.1], [41.07, -71.86], [40.75, -72.8], [40.6, -73.6],
	[40.57, -74.0], [40.45, -74.0], [40.0, -74.05], [39.36, -74.42], [38.93, -74.92], [39.25, -75.1], [39.6, -75.55],
	[39.2, -75.35], [38.78, -75.1], [38.3, -75.1], [37.9, -75.4], [37.1, -75.95], [37.6, -76.0], [38.3, -76.05], [39.0, -76.2],
	[39.35, -76.4], [39.2, -76.55], [38.4, -76.4], [37.9, -76.25], [37.0, -76.3], [36.9, -75.98], [36.2, -75.75], [35.25, -75.5],
	[34.6, -76.5], [34.65, -77.1], [33.85, -77.95], [33.7, -78.9], [32.75, -79.9], [32.1, -80.8], [31.2, -81.4], [30.35, -81.4],
	[29.9, -81.3], [28.4, -80.6], [27.2, -80.2], [26.7, -80.03], [25.77, -80.13], [25.25, -80.35], [25.15, -80.95], [25.9, -81.7],
	[26.5, -82.1], [27.3, -82.55], [27.95, -82.8], [28.9, -82.7], [29.8, -83.6], [30.05, -84.3], [29.7, -85.35], [30.25, -86.4],
	[30.4, -87.2], [30.25, -88.05], [30.35, -88.9], [30.2, -89.6], [29.5, -89.5], [29.1, -89.1], [28.95, -89.4], [29.1, -90.5],
	[29.5, -91.4], [29.6, -92.4], [29.75, -93.8], [29.3, -94.8], [28.4, -96.4], [27.6, -97.2], [26.0, -97.15], [24.0, -97.7],
	[22.3, -97.8], [21.2, -97.4], [19.5, -96.4], [19.5, -104.0]]
const ISLANDS := [
	# Newfoundland
	[[47.6, -59.3], [48.6, -59.0], [49.6, -57.8], [50.6, -57.0], [51.6, -55.5], [49.8, -55.5], [49.2, -53.6], [47.6, -52.7],
		[46.6, -53.2], [47.0, -55.2], [47.1, -56.3], [47.6, -59.3]],
	# Cuba
	[[21.8, -84.9], [22.9, -83.0], [23.15, -82.0], [23.2, -80.5], [22.4, -78.4], [21.5, -76.5], [20.9, -75.7], [20.2, -74.2],
		[19.9, -77.7], [20.7, -77.2], [21.6, -79.0], [22.0, -81.5], [21.9, -83.0], [21.8, -84.9]],
	# Yucatan
	[[19.5, -90.6], [21.2, -90.3], [21.55, -88.0], [21.5, -87.0], [19.5, -87.4]],
	# the Bahamas: Andros, Grand Bahama, Abaco, Eleuthera
	[[24.9, -78.1], [24.6, -77.7], [24.0, -77.6], [24.1, -78.2]],
	[[26.75, -79.0], [26.7, -78.0], [26.5, -78.1], [26.55, -78.9]],
	[[27.0, -77.3], [26.5, -76.95], [26.2, -77.2], [26.6, -77.6]],
	[[25.6, -76.7], [25.1, -76.1], [24.7, -76.1], [25.3, -76.6]],
	# Nova Scotia's Cape Breton is on the mainland outline; Prince Edward Island
	[[46.95, -64.1], [46.45, -62.0], [46.2, -62.4], [46.4, -63.8]],
]
const LAKES := [
	[[46.7, -92.1], [46.9, -90.5], [46.5, -87.4], [46.5, -84.6], [47.2, -84.7], [48.0, -85.0], [48.8, -87.3], [48.4, -89.2], [47.4, -91.3]],   # Superior
	[[41.62, -87.3], [42.1, -86.5], [43.2, -86.3], [44.8, -86.1], [45.8, -85.0], [45.9, -86.8], [44.6, -87.6], [43.0, -87.9], [41.88, -87.6]],   # Michigan
	[[43.0, -82.4], [44.0, -82.6], [45.0, -83.4], [45.8, -84.5], [46.1, -83.5], [45.9, -81.5], [45.3, -80.1], [44.5, -81.4], [43.3, -81.7]],   # Huron
	[[41.7, -83.4], [41.4, -82.6], [41.5, -81.7], [42.1, -80.1], [42.85, -78.9], [42.8, -79.8], [42.6, -81.4], [42.1, -82.5], [42.0, -83.1]],   # Erie
	[[43.2, -79.8], [43.3, -79.0], [43.3, -77.6], [43.5, -76.2], [44.1, -76.4], [44.0, -77.6], [43.9, -78.9], [43.6, -79.5]],                  # Ontario
	[[30.35, -90.45], [30.2, -89.75], [30.02, -89.85], [30.05, -90.4]],                                                                        # Pontchartrain
]
const RIVERS := [
	[[44.1, -76.3], [45.0, -74.8], [45.5, -73.6], [46.3, -72.6], [46.8, -71.2], [47.5, -70.0], [48.3, -69.1]],      # St. Lawrence
	[[40.7, -74.0], [41.3, -73.95], [42.65, -73.75], [43.3, -73.6]],                                                   # Hudson
	[[45.0, -73.35], [44.5, -73.3], [43.6, -73.4]],                                                                    # Lake Champlain
	[[29.0, -89.2], [29.95, -90.07], [31.0, -91.6], [32.3, -90.9], [35.15, -90.05], [37.0, -89.18], [38.63, -90.2], [40.0, -91.4], [41.5, -90.6], [43.0, -91.2], [44.9, -93.1]],  # Mississippi
	[[37.0, -89.18], [37.8, -87.6], [38.2, -85.8], [39.1, -84.5], [38.4, -82.6], [39.3, -81.5], [40.44, -80.0]],     # Ohio
	[[38.8, -90.1], [38.6, -92.2], [39.1, -94.6], [40.0, -95.3], [41.3, -95.9], [42.5, -96.4]],                       # Missouri
	[[42.33, -83.05], [42.9, -82.45]], [[42.9, -78.95], [43.25, -79.05]],                                              # Detroit / St. Clair, Niagara
]
const BORDER := [[49.0, -104.0], [49.0, -95.2], [48.6, -93.4], [48.0, -89.6], [46.5, -84.4], [45.9, -83.5], [43.0, -82.4], [42.3, -83.1],
	[41.7, -82.6], [42.6, -79.2], [43.2, -79.05], [43.6, -78.7], [44.1, -76.4], [45.0, -74.7], [45.0, -71.5], [45.3, -70.8],
	[46.4, -70.0], [47.4, -69.2], [47.3, -68.3], [47.1, -67.8], [45.9, -67.8], [45.2, -67.3], [44.8, -67.0]]

var hud: Node
var _sel := {}
var _panel: VBoxContainer
var _info: RichTextLabel
var _buttons: VBoxContainer
var _area := Rect2()      # the whole map, on screen (bigger than the frame when zoomed in)
var _frame := Rect2()     # the part of the screen the map is shown in
var _zoom := 1.0
var _center := Vector2(0.5, 0.5)   # map UV at the middle of the frame
var _drag := false
var _t := 0.0
var _cache := {}          # path key -> PackedVector2Array in UV


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var p := PanelContainer.new()
	p.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	p.offset_left = -440
	p.offset_top = 70
	p.offset_bottom = -20
	p.offset_right = -20
	add_child(p)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(scroll)
	_panel = VBoxContainer.new()
	_panel.add_theme_constant_override("separation", 8)
	_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_panel)
	_info = RichTextLabel.new()
	_info.bbcode_enabled = true
	_info.fit_content = true
	_info.custom_minimum_size = Vector2(380, 40)
	_panel.add_child(_info)
	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 5)
	_panel.add_child(_buttons)
	Game.state_changed.connect(func() -> void:
		if visible:
			_fill())


func open() -> void:
	if _sel.is_empty():
		_sel = {"type": "city", "id": "chi"}
	_fill()


func _process(delta: float) -> void:
	_t += delta
	if visible:
		queue_redraw()


func _uv(key: String, pts: Array) -> PackedVector2Array:
	if not _cache.has(key):
		_cache[key] = Syndicate.path_uv(pts)
	return _cache[key]


func _pts(key: String, pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for u in _uv(key, pts):
		out.append(_area.position + u * _area.size)
	return out


func _at(id: String) -> Vector2:
	return _area.position + Syndicate.uv(id) * _area.size


func _fam_color(id: int) -> Color:
	var f := Game.fam(id)
	return Color(f.get("color", "#777777")) if not f.is_empty() else Color("6b6458")


func _layout() -> void:
	var avail := Rect2(Vector2(24, 66), Vector2(size.x - 490.0, size.y - 112.0))
	var aspect := Syndicate.map_aspect()
	var w := minf(avail.size.x, avail.size.y * aspect)
	_frame = Rect2(avail.position, Vector2(w, w / aspect))
	var half := Vector2(0.5, 0.5) / _zoom
	_center = _center.clamp(half, Vector2.ONE - half)
	var sz := _frame.size * _zoom
	_area = Rect2(_frame.get_center() - _center * sz, sz)


func _draw() -> void:
	_layout()
	var bg := Color("15120f")
	draw_rect(Rect2(Vector2.ZERO, size), bg)
	draw_rect(_frame, WATER)
	var font := get_theme_default_font()
	var land := _pts("coast", COAST)
	draw_colored_polygon(land, LAND)
	draw_polyline(land, LAND_EDGE, 1.5)
	for k in ISLANDS.size():
		var isl := _pts("isl%d" % k, ISLANDS[k])
		draw_colored_polygon(isl, LAND)
		draw_polyline(isl + PackedVector2Array([isl[0]]), LAND_EDGE, 1.2)
	for k in LAKES.size():
		var lake := _pts("lake%d" % k, LAKES[k])
		draw_colored_polygon(lake, WATER)
		draw_polyline(lake + PackedVector2Array([lake[0]]), LAND_EDGE, 1.0)
	for k in RIVERS.size():
		draw_polyline(_pts("riv%d" % k, RIVERS[k]), RIVER, 2.5 if k == 0 else 1.6, true)
	_dashed_poly(_pts("border", BORDER), Color(0.62, 0.56, 0.46, 0.45), 1.2, 7.0)
	var nation: Dictionary = Game.nation
	for lab in [["CANADA", 48.2, -84.0], ["UNITED STATES", 37.5, -86.0], ["ATLANTIC OCEAN", 33.5, -70.5], ["GULF OF MEXICO", 25.8, -91.0], ["CUBA", 22.2, -80.5]]:
		var at := _area.position + Syndicate.project(lab[1], lab[2]) * _area.size
		draw_string(font, at, lab[0], HORIZONTAL_ALIGNMENT_CENTER, -1, 15, Color(1, 1, 1, 0.22))
	if nation.is_empty():
		_mask(bg, font)
		return
	var me := int(Game.player(Net.my_id()).get("family", -1))
	# mother-ship lanes
	for k in Syndicate.LANES.size():
		_dashed_poly(_pts("lane%d" % k, Syndicate.LANES[k]["path"]), Color(0.75, 0.68, 0.5, 0.35), 1.0, 3.0)
	# freight rail lines: a line with cross-ties
	for r in Syndicate.RAILS:
		var pl := _pts(r["id"], r["path"])
		var sel: bool = _sel.get("id", "") == r["id"]
		draw_polyline(pl, RAIL.lightened(0.3) if sel else RAIL, 3.0 if sel else 1.6, true)
		_ties(pl, RAIL, 9.0)
		for o in nation["freight"]:
			if int(o["fam"]) == me and o["line"] == r["id"]:
				for k in 2:
					var tt := fmod(_t * 0.08 + k * 0.5, 1.0)
					draw_rect(Rect2(_along(pl, tt) - Vector2(3, 3), Vector2(6, 6)), Color(Game.fam(me)["color"]).lightened(0.4))
	# smuggling routes
	for d in Syndicate.ROUTES:
		var r: Dictionary = nation["routes"][d["id"]]
		var pl := _pts(d["id"], d["path"])
		var owner: int = r["owner"]
		var col := _fam_color(owner) if owner >= 0 else Color(0.75, 0.68, 0.52, 0.7)
		var w := 4.0 if _sel.get("id", "") == d["id"] else 2.4
		if owner >= 0:
			draw_polyline(pl, col, w, true)
		else:
			_dashed_poly(pl, col, w, 8.0)
		var mine := int(r["convoys"].get(str(me), 0))
		if mine > 0:
			for k in 3:
				var t := fmod(_t * 0.12 + k / 3.0, 1.0)
				draw_circle(_along(pl, t), 3.6, Color(Game.fam(me)["color"]).lightened(0.3))
		if int(r["ambush"].get(str(me), 0)) > 0:
			draw_string(font, _along(pl, 0.5) + Vector2(6, -6), "✕ ambush", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("ff8a7a"))
	# sources
	var blocks: Array[Rect2] = []
	var labels := []     # [text, anchor point, marker radius, size, colour, priority]
	for src in Syndicate.SOURCES:
		var p := _at(src["id"])
		var sel: bool = _sel.get("id", "") == src["id"]
		draw_rect(Rect2(p - Vector2(6, 6), Vector2(12, 12)), Color("c9a54a"))
		draw_rect(Rect2(p - Vector2(6, 6), Vector2(12, 12)), Color(0, 0, 0, 0.7), false, 1.0)
		blocks.append(Rect2(p - Vector2(7, 7), Vector2(14, 14)))
		labels.append([src["name"], p, 7.0, 15 if sel else 13, GOLD2, 50 if sel else 1])
	# cities
	for c in Syndicate.CITIES:
		var p := _at(c["id"])
		var cs: Dictionary = nation["cities"][c["id"]]
		var rad := 11.0 if c["id"] in ["nyc", "chi"] else 8.0
		draw_circle(p, rad + 4.0, Color(0, 0, 0, 0.6))
		draw_circle(p, rad, Color("3b3530"))
		if c["id"] == "nyc":
			var total := maxf(1.0, Game.biz.size())
			var start := -PI * 0.5
			for f in Game.families:
				var share := Game.shops_of(f["id"]).size() / total
				if share > 0.0:
					draw_arc(p, rad + 2.0, start, start + share * TAU, 24, Color(f["color"]), 4.0)
					start += share * TAU
		else:
			var start2 := -PI * 0.5
			for k in cs["influence"]:
				var share2 := float(cs["influence"][k]) / 100.0
				if share2 > 0.01:
					draw_arc(p, rad + 2.0, start2, start2 + share2 * TAU, 24, _fam_color(int(k)), 4.0)
					start2 += share2 * TAU
		var ctrl := Syndicate.controller(nation, c["id"])
		if ctrl >= 0:
			draw_circle(p, rad * 0.55, _fam_color(ctrl))
		if Syndicate.men_in(nation, c["id"], me) > 0:
			draw_string(font, p + Vector2(-6, 5), "%d" % Syndicate.men_in(nation, c["id"], me), HORIZONTAL_ALIGNMENT_CENTER, 12, 12, INK)
		# the sites: D docks, W your warehouse, B/S brewery or still, Y rail yard, in their owners' colours
		var marks := []
		if String(c["port"]) != "":
			marks.append(["D", int(cs["docks"])])
		if cs["wh"].has(str(me)):
			marks.append(["W", me])
		if String(c["plant"]) != "":
			marks.append(["B" if c["plant"] == "brewery" else "S", int(cs["plant"])])
		if bool(c["yard"]):
			marks.append(["Y", int(cs["yard"])])
		var mx := p.x - marks.size() * 6.0
		blocks.append(Rect2(p - Vector2(rad + 4, rad + 4), Vector2(rad * 2 + 8, rad * 2 + 8)))
		if not marks.is_empty():
			blocks.append(Rect2(Vector2(mx, p.y + rad + 5.0), Vector2(marks.size() * 12.0, 11)))
		for m in marks:
			var mc := _fam_color(m[1]) if int(m[1]) >= 0 else Color(0.3, 0.27, 0.23)
			draw_rect(Rect2(Vector2(mx, p.y + rad + 5.0), Vector2(11, 11)), mc)
			draw_string(font, Vector2(mx + 1.5, p.y + rad + 14.5), m[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, INK if int(m[1]) >= 0 else MUTE)
			mx += 12.0
		var sel: bool = _sel.get("id", "") == c["id"]
		labels.append([c["name"], p, rad + 3.0, 16 if sel else 14, GOLD2 if sel else INK, 100 if sel else 10 + int(c["demand"]) / 10 + (40 if c["id"] == "nyc" else 0)])
		if sel:
			draw_arc(p, rad + 8.0, 0, TAU, 32, GOLD2, 2.0)
	_draw_labels(font, labels, blocks)
	_mask(bg, font)
	# legend
	_legend(font)


## Everything outside the frame is covered (the map spills when zoomed), then the title.
func _mask(bg: Color, font: Font) -> void:
	draw_rect(Rect2(0, 0, size.x, _frame.position.y), bg)
	draw_rect(Rect2(0, _frame.end.y, size.x, size.y - _frame.end.y), bg)
	draw_rect(Rect2(0, 0, _frame.position.x, size.y), bg)
	draw_rect(Rect2(_frame.end.x, 0, size.x - _frame.end.x, size.y), bg)
	draw_rect(_frame, LAND_EDGE, false, 2.0)
	draw_string(font, Vector2(24, 48), "The country · %s" % Game.date_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, INK)
	if _zoom > 1.01:
		draw_string(font, Vector2(_frame.end.x - 260, 48), "zoom x%.1f · wheel / right-drag" % _zoom, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, MUTE)


## Names next to their markers, each where it doesn't sit on another name or marker: right,
## left, above, below, then the diagonals. The most important places pick first.
func _draw_labels(font: Font, labels: Array, blocks: Array[Rect2]) -> void:
	labels.sort_custom(func(a, b) -> bool: return int(a[5]) > int(b[5]))
	var placed: Array[Rect2] = []
	for l in labels:
		var text: String = l[0]
		var p: Vector2 = l[1]
		var r: float = l[2]
		var fs: int = l[3]
		var ts := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var h := ts.y * 0.8
		var cands := [Vector2(r + 3, -h * 0.5), Vector2(-r - 3 - ts.x, -h * 0.5), Vector2(-ts.x * 0.5, -r - 3 - h),
			Vector2(-ts.x * 0.5, r + 16), Vector2(r, -r - h), Vector2(r, r), Vector2(-r - ts.x, -r - h), Vector2(-r - ts.x, r)]
		var best: Vector2 = cands[0]
		var best_hits := 999
		for c in cands:
			var rect := Rect2(p + c, Vector2(ts.x, h))
			var hits := 0
			for o in placed:
				if o.intersects(rect):
					hits += 2
			for o in blocks:
				if o.intersects(rect) and not o.has_point(p):
					hits += 1
			if hits < best_hits:
				best_hits = hits
				best = c
				if hits == 0:
					break
		var at: Vector2 = p + best
		placed.append(Rect2(at, Vector2(ts.x, h)))
		draw_string_outline(font, at + Vector2(0, h), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0.05, 0.04, 0.03, 0.85))
		draw_string(font, at + Vector2(0, h), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, l[4])


func _legend(font: Font) -> void:
	var ly := size.y - 58.0
	var lx := 30.0
	for f in Game.families:
		draw_circle(Vector2(lx, ly), 7, Color(f["color"]))
		draw_string(font, Vector2(lx + 12, ly + 6), f["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, INK)
		lx += 130
	draw_string(font, Vector2(30, size.y - 22), "Click a city, a source, a route or a rail line · ring = who holds the city · marks: D docks, W your warehouse, B brewery, S still, Y rail yard · J to close",
		HORIZONTAL_ALIGNMENT_LEFT, size.x - 500.0, 14, MUTE)


## Zoom by `f` keeping the map point under `screen` where it is.
func zoom_at(screen: Vector2, f: float) -> void:
	var uv := (screen - _area.position) / _area.size
	_zoom = clampf(_zoom * f, 1.0, 4.0)
	var sz := _frame.size * _zoom
	_center = uv - (screen - _frame.get_center()) / sz
	queue_redraw()


## Show a place: centre on it and zoom in.
func focus_on(id: String, zoom: float = 2.5) -> void:
	_zoom = zoom
	_center = Syndicate.uv(id)
	queue_redraw()


## A point `t` (0..1) of the way along a polyline, by length.
func _along(pl: PackedVector2Array, t: float) -> Vector2:
	if pl.size() < 2:
		return pl[0] if pl.size() == 1 else Vector2.ZERO
	var total := 0.0
	for k in range(1, pl.size()):
		total += pl[k - 1].distance_to(pl[k])
	var goal := total * clampf(t, 0.0, 1.0)
	for k in range(1, pl.size()):
		var seg := pl[k - 1].distance_to(pl[k])
		if goal <= seg:
			return pl[k - 1].lerp(pl[k], goal / maxf(seg, 0.001))
		goal -= seg
	return pl[pl.size() - 1]


func _dashed_poly(pl: PackedVector2Array, col: Color, w: float, dash: float) -> void:
	var on := true
	var left := dash
	for k in range(1, pl.size()):
		var a := pl[k - 1]
		var b := pl[k]
		var seg := a.distance_to(b)
		var pos := 0.0
		while pos < seg:
			var step := minf(left, seg - pos)
			if on:
				draw_line(a.lerp(b, pos / seg), a.lerp(b, (pos + step) / seg), col, w)
			pos += step
			left -= step
			if left <= 0.0:
				on = not on
				left = dash
	return


func _ties(pl: PackedVector2Array, col: Color, every: float) -> void:
	var left := every * 0.5
	for k in range(1, pl.size()):
		var a := pl[k - 1]
		var b := pl[k]
		var seg := a.distance_to(b)
		if seg < 0.01:
			continue
		var dir := (b - a) / seg
		var nrm := Vector2(-dir.y, dir.x) * 3.0
		var pos := left
		while pos < seg:
			var p := a + dir * pos
			draw_line(p - nrm, p + nrm, col, 1.0)
			pos += every
		left = pos - seg


func _near_poly(m: Vector2, pl: PackedVector2Array) -> float:
	var bd := INF
	for k in range(1, pl.size()):
		bd = minf(bd, Geometry2D.get_closest_point_to_segment(m, pl[k - 1], pl[k]).distance_to(m))
	return bd


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		if _frame.has_point(e.position):
			zoom_at(e.position, 1.25 if e.button_index == MOUSE_BUTTON_WHEEL_UP else 0.8)
		accept_event()
		return
	if e is InputEventMouseButton and e.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
		_drag = e.pressed
		accept_event()
		return
	if e is InputEventMouseMotion and _drag:
		_center -= e.relative / _area.size
		queue_redraw()
		accept_event()
		return
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var m: Vector2 = e.position
		var best := {}
		var bd := 20.0
		for c in Syndicate.CITIES:
			var d := _at(c["id"]).distance_to(m)
			if d < bd:
				bd = d
				best = {"type": "city", "id": c["id"]}
		if best.is_empty():
			bd = 14.0
			for s in Syndicate.SOURCES:
				var d := _at(s["id"]).distance_to(m)
				if d < bd:
					bd = d
					best = {"type": "source", "id": s["id"]}
		if best.is_empty():
			bd = 10.0
			for r in Syndicate.ROUTES:
				var d2 := _near_poly(m, _pts(r["id"], r["path"]))
				if d2 < bd:
					bd = d2
					best = {"type": "route", "id": r["id"]}
			for r in Syndicate.RAILS:
				var d3 := _near_poly(m, _pts(r["id"], r["path"]))
				if d3 < bd:
					bd = d3
					best = {"type": "rail", "id": r["id"]}
		if not best.is_empty():
			_sel = best
			_fill()
		accept_event()


func _btn(text: String, args: Array, enabled: bool = true) -> void:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(380, 0)
	b.pressed.connect(func() -> void: Net.to_host("nation", args))
	_buttons.add_child(b)


func _owner(id: int, me: int) -> String:
	if id < 0:
		return "nobody"
	if id == me:
		return "[color=#f0d58a]yours[/color]"
	return "[color=%s]the %s family[/color]" % [Game.fam(id).get("color", "#fff"), Game.fam(id).get("name", "?")]


func _fill() -> void:
	for c in _buttons.get_children():
		c.queue_free()
	var nation: Dictionary = Game.nation
	if nation.is_empty() or _sel.is_empty():
		return
	var me := int(Game.player(Net.my_id()).get("family", -1))
	var f := Game.fam(me)
	var money := int(f.get("dirty", 0))
	var clean := int(f.get("clean", 0))
	match _sel["type"]:
		"city": _fill_city(nation, me, f, money, clean)
		"route": _fill_route(nation, me, money)
		"rail": _fill_rail(nation, me, f)
		"source": _fill_source(nation, me)


func _fill_city(nation: Dictionary, me: int, f: Dictionary, money: int, clean: int) -> void:
	var c := Syndicate.city_def(_sel["id"])
	var id: String = c["id"]
	var cs: Dictionary = nation["cities"][id]
	var t := "[font_size=26]%s[/font_size]\n[color=#9b907c]%s[/color]\n" % [c["name"], c["note"]]
	if id == "nyc":
		t += "\nYou run New York yourself, on the street. Shops paying each family:\n"
		for fm in Game.families:
			t += "  [color=%s]%s[/color]: %d\n" % [fm["color"], fm["name"], Game.shops_of(fm["id"]).size()]
	else:
		t += "Thirst: %d crates a month · local outfit: %s\n" % [c["demand"], c["outfit"]]
		var ctrl := Syndicate.controller(nation, id)
		t += "Runs the city: [b]%s[/b]\n" % (Game.fam(ctrl)["name"] if ctrl >= 0 else c["outfit"])
		for k in cs["influence"]:
			var fm := Game.fam(int(k))
			var capo_id := int(cs["capo"].get(k, -1))
			var capo := ("  · capo %s" % Game.crew_by_id(capo_id).get("name", "")) if capo_id >= 0 else ""
			t += "  [color=%s]%s[/color]: %d%% · %d men · %d guns%s\n" % [fm.get("color", "#fff"), fm.get("name", "?"), int(cs["influence"][k]),
				Syndicate.men_in(nation, id, int(k)), Syndicate.guns_in(nation, id, int(k)), capo]
		var pol: int = cs["police"]
		t += "Police: %s\n" % ("on the %s payroll" % Game.fam(pol)["name"] if pol >= 0 else "not bought")
	# the sites
	t += "\n[b]Supply[/b]\n"
	if String(c["port"]) != "":
		t += "Docks, %s: %s\n" % [c["port"], _owner(int(cs["docks"]), me)]
	if id == "nyc":
		var wh := Game.nyc_warehouse(me)
		t += "Your warehouse: %s\n" % ("%s, %d crates" % [wh["name"], Syndicate.stock(nation, "nyc", me)] if not wh.is_empty() else "none (buy one on the West St. quay)")
	elif Syndicate.has_wh(nation, id, me):
		t += "Your warehouse: %d crates, sells up to %d a month at $%d\n" % [Syndicate.stock(nation, id, me), Syndicate.sell_cap(nation, id, me), int(Syndicate.wholesale(Game))]
	else:
		t += "Your warehouse: none (crates landing here are dumped at half price)\n"
	var others := []
	for k in cs["wh"]:
		if int(k) != me:
			others.append(Game.fam(int(k)).get("name", "?"))
	if not others.is_empty():
		t += "Other warehouses: %s\n" % ", ".join(others)
	if String(c["plant"]) != "":
		t += "The %s: %s%s\n" % [c["plant"], _owner(int(cs["plant"]), me), " (padlocked)" if int(cs["plant_closed"]) >= Game.month else ""]
	if bool(c["yard"]):
		t += "Rail yard: %s\n" % _owner(int(cs["yard"]), me)
	var lines := Syndicate.rails_through(id).map(func(r: Dictionary) -> String: return r["name"])
	if not lines.is_empty():
		t += "[color=#9b907c]Freight: %s[/color]\n" % ", ".join(lines)
	_info.text = t
	if id != "nyc":
		var ars: Dictionary = f.get("arsenal", {})
		var guns := int(ars.get("pistol", 0)) + int(ars.get("tommy", 0))
		var capo_c := -1
		for cm in Game.crew_of(me):
			if cm["rank"] == "soldier":
				capo_c = cm["id"]
				break
		if capo_c < 0 and not Game.crew_of(me).is_empty():
			capo_c = Game.crew_of(me)[0]["id"]
		_btn("Send 2 men ($500 to set them up, $90 a month each)", ["send", id, 2, 0, -1], money >= 500)
		_btn("Send 4 men with %d guns ($1,000)" % mini(4, guns), ["send", id, 4, mini(4, guns), -1], money >= 1000)
		if not cs["capo"].has(str(me)) and capo_c >= 0:
			_btn("Send %s as capo, with 2 men ($500)" % Game.crew_by_id(capo_c)["name"], ["send", id, 2, mini(2, guns), capo_c], money >= 500)
		var pol2: int = cs["police"]
		_btn("Buy the %s police ($%d)" % [c["name"], 2500 if id == "kc" else 1200], ["police", id], pol2 != me and money >= (2500 if id == "kc" else 1200))
		for k in cs["men"]:
			var other := int(k)
			if other != me and int(cs["men"][k]) > 0:
				_btn("Order a hit on the %s family's people here ($%d)" % [Game.fam(other)["name"], Syndicate.HIT_COST], ["hit", id, other], money >= Syndicate.HIT_COST)
		if Syndicate.men_in(nation, id, me) > 0:
			_btn("Bring your men home", ["recall", id])
		if not Syndicate.has_wh(nation, id, me):
			var wp := Syndicate.warehouse_price(id)
			_btn("Buy a warehouse ($%d clean): sell up to %d crates a month here" % [wp, Syndicate.sell_cap(nation, id, me)], ["warehouse", id], clean >= wp)
		if String(c["port"]) != "" and int(cs["docks"]) != me:
			var up := Syndicate.union_price(nation, id, me)
			_btn("Put the longshoremen's local on the payroll ($%d, then $%d a month)" % [up, Syndicate.union_wage(id)], ["union", id], money >= up)
	if String(c["plant"]) != "" and int(cs["plant"]) < 0:
		var pp := Syndicate.plant_price(id)
		_btn("Buy the %s ($%d clean): %d crates a month" % [c["plant"], pp, Syndicate.PLANT_OUT[c["plant"]]], ["plant", id], clean >= pp)
	if bool(c["yard"]) and int(cs["yard"]) != me:
		var yp := Syndicate.yard_price(nation, id, me)
		_btn("Bribe the yardmaster ($%d): safe freight through %s" % [yp, c["name"]], ["yard", id], money >= yp)


func _fill_route(nation: Dictionary, me: int, money: int) -> void:
	var d := Syndicate.route_def(_sel["id"])
	var r: Dictionary = nation["routes"][d["id"]]
	var src := Syndicate.source_def(d["from"])
	var dest := Syndicate.city_def(d["to"])
	var owner: int = r["owner"]
	var cap := Syndicate.route_cap(nation, d["id"], me)
	var t2 := "[font_size=26]%s[/font_size]\n%s → %s · by %s, %d miles\n[color=#9b907c]%s[/color]\n" % [d["name"], src["name"], dest["name"], d["mode"], int(Syndicate.miles(d["path"])), src["note"]]
	t2 += "Capacity %d crates a month%s · $%d a crate at the source · risk %d%%\n" % [cap, " (your docks)" if cap > int(d["cap"]) else "", src["price"], int(d["risk"] * 100)]
	t2 += "Officials bought by: [b]%s[/b]\n" % (Game.fam(owner)["name"] if owner >= 0 else "nobody")
	if Syndicate.is_boat(d["id"]) and String(dest["port"]) != "":
		t2 += "Lands at %s: the union is %s\n" % [dest["port"], _owner(int(nation["cities"][d["to"]]["docks"]), me)]
	var mine := int(r["convoys"].get(str(me), 0))
	t2 += "Your convoys: %s\n" % ("%d crates a month" % mine if mine > 0 else "none")
	var amb := int(r["ambush"].get(str(me), 0))
	if amb > 0:
		t2 += "Your hijackers: %d men waiting\n" % amb
	if String(r["last"]) != "":
		t2 += "Last month: %s\n" % r["last"]
	if Syndicate.has_wh(nation, d["to"], me):
		t2 += "[color=#9b907c]Crates go into your warehouse in %s.[/color]" % dest["name"]
	elif d["to"] == "nyc":
		t2 += "[color=#ff8a7a]No warehouse on the West St. quay: crates go straight into your speakeasy cellars and the rest are dumped at half price.[/color]"
	else:
		t2 += "[color=#ff8a7a]No warehouse in %s: crates are dumped on arrival at half price.[/color]" % dest["name"]
	_info.text = t2
	for n in [20, 50, cap]:
		_btn("Run %d crates a month" % n, ["convoy", d["id"], n], n != mine)
	if mine > 0:
		_btn("Stop the convoys", ["convoy", d["id"], 0])
	_btn("Buy the customs men and sheriffs ($%d)" % (int(d["bribe"]) + (800 if owner >= 0 else 0)), ["route", d["id"]], owner != me and money >= int(d["bribe"]))
	_btn("Wait on this road with 3 men and hijack the other families' trucks", ["ambush", d["id"], 3], amb == 0)
	if amb > 0:
		_btn("Call off the hijackers", ["ambush", d["id"], 0])


func _fill_rail(nation: Dictionary, me: int, f: Dictionary) -> void:
	var r := Syndicate.rail_def(_sel["id"])
	var stops: Array = r["stops"]
	var t := "[font_size=26]%s[/font_size]\n%s · %d miles\n" % [r["name"], " – ".join(stops.map(func(s: String) -> String: return Syndicate.cname(s))), int(Syndicate.miles(r["path"]))]
	t += "[color=#9b907c]Freight between two of your own warehouses on the line, every month. Crates in boxcars marked 'machine parts'.[/color]\n"
	for s in stops:
		var cd := Syndicate.city_def(s)
		var cs: Dictionary = nation["cities"][s]
		t += "  %s: warehouse %s%s\n" % [cd["name"], ("%d crates" % Syndicate.stock(nation, s, me)) if Syndicate.has_wh(nation, s, me) else "none",
			(" · yard %s" % _owner(int(cs["yard"]), me)) if bool(cd["yard"]) else ""]
	var risk := Syndicate.freight_risk(nation, r["id"], me, float(f.get("heat", 0.0)))
	t += "Risk: %s\n" % ("none, your yardmaster sees to it" if risk <= 0.0 else "%d%% a month (a yard of yours on the line makes it safe)" % int(risk * 100))
	for o in nation["freight"]:
		if int(o["fam"]) == me and o["line"] == r["id"]:
			t += "Your order: %d crates a month %s → %s · %s\n" % [int(o["crates"]), Syndicate.cname(o["from"]), Syndicate.cname(o["to"]), o["last"] if String(o["last"]) != "" else "starts next month"]
	_info.text = t
	for a in stops:
		for b in stops:
			if a == b or not Syndicate.has_wh(nation, a, me) or not Syndicate.has_wh(nation, b, me):
				continue
			var cur := 0
			for o in nation["freight"]:
				if int(o["fam"]) == me and o["line"] == r["id"] and o["from"] == a and o["to"] == b:
					cur = int(o["crates"])
			var per := Syndicate.freight_cost(r["id"], a, b)
			if cur > 0:
				_btn("Stop the freight %s → %s" % [Syndicate.cname(a), Syndicate.cname(b)], ["freight", r["id"], a, b, 0])
			for n in [20, 40]:
				if n != cur:
					_btn("Ship %d crates a month %s → %s ($%d a crate)" % [n, Syndicate.cname(a), Syndicate.cname(b), per], ["freight", r["id"], a, b, n])
	for s in stops:
		var cd2 := Syndicate.city_def(s)
		if bool(cd2["yard"]) and int(nation["cities"][s]["yard"]) != me:
			var yp := Syndicate.yard_price(nation, s, me)
			_btn("Bribe the yardmaster in %s ($%d)" % [cd2["name"], yp], ["yard", s], int(f.get("dirty", 0)) >= yp)


func _fill_source(nation: Dictionary, me: int) -> void:
	var s := Syndicate.source_def(_sel["id"])
	var t := "[font_size=26]%s[/font_size]\n[color=#9b907c]%s[/color]\n$%d a crate here.\n\nRoutes from %s:\n" % [s["name"], s["note"], s["price"], s["name"]]
	for d in Syndicate.ROUTES:
		if d["from"] == s["id"]:
			var mine := int(nation["routes"][d["id"]]["convoys"].get(str(me), 0))
			t += "  %s, to %s (%s)%s\n" % [d["name"], Syndicate.cname(d["to"]), d["mode"], (" · you run %d a month" % mine) if mine > 0 else ""]
	_info.text = t
	for d in Syndicate.ROUTES:
		if d["from"] == s["id"]:
			var dd: Dictionary = d
			var b := Button.new()
			b.text = "The %s" % dd["name"]
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.pressed.connect(func() -> void:
				_sel = {"type": "route", "id": dd["id"]}
				_fill())
			_buttons.add_child(b)
