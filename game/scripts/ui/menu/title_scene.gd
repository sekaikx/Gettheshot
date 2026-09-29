class_name MenuTitleScene
extends Control
## The title screen's backdrop, drawn in code: Little Italy on a rainy night in 1929. Tenements
## with lit windows going on and off, fire escapes, a street lamp in the rain, a man smoking in a
## doorway, the neon "CAFFÈ" buzzing, puddles, and now and then a car's headlights sweeping past.
## The view drifts slowly. Everything is drawn in "design units" (900 tall) and scaled to fit.
##
## Static art is drawn once per resize into its own layer and only moved for the drift; the
## windows redraw a few times a second; the lights, rain and the car redraw every frame.

const H := 900.0
const GROUND := 720.0          # the sidewalk's top edge
const CURB := 748.0
const ROAD := 758.0
const SEED := 1929

## Darken the left side so the menu reads over the scene.
@export var left_scrim := 0.9

var t := 0.0
var drift := 0.0
var _s := 1.0                  # design units -> pixels
var _wd := 1600.0              # width in design units
var _root: Node2D
var _sky: _Layer
var _far: _Layer
var _mid: _Layer
var _near: _Layer
var _win: _Layer
var _glow: _Layer
var _fx: _Layer
var _beam: _Layer
var _rain: _Layer
var _front: _Layer
var _tower_x := 800.0
var _blds: Array = []          # {x, w, idx, floors, caffe}
var _windows: Array = []       # {r: Rect2, per, ph, seed, bias, tint}
var _shops: Array = []         # {r: Rect2 window, lit: bool, color}
var _lamp := Vector2.ZERO      # lantern centre
var _neon := Vector2.ZERO      # centre of the neon word
var _smoker := Vector2.ZERO    # the cigarette tip
var _manholes: Array = []
var _neon_font: Font
var _win_t := 0.0
var _glow_tex: GradientTexture2D
var _built_for := Vector2.ZERO


class _Layer extends Node2D:
	var painter: Callable
	var parallax := 1.0

	func _draw() -> void:
		if painter.is_valid():
			painter.call(self)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_neon_font = W.ui_font("deco")
	_glow_tex = GradientTexture2D.new()
	_glow_tex.width = 128
	_glow_tex.height = 128
	_glow_tex.fill = GradientTexture2D.FILL_RADIAL
	_glow_tex.fill_from = Vector2(0.5, 0.5)
	_glow_tex.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.25, Color(1, 1, 1, 0.55))
	g.add_point(0.55, Color(1, 1, 1, 0.16))
	_glow_tex.gradient = g
	_root = Node2D.new()
	add_child(_root)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_sky = _layer(_draw_sky, 0.03)
	_far = _layer(_draw_far, 0.12)
	_mid = _layer(_draw_mid, 0.35)
	_near = _layer(_draw_near, 1.0)
	_win = _layer(_draw_windows, 1.0)
	_glow = _layer(_draw_glow, 1.0)
	_glow.material = add
	_fx = _layer(_draw_fx, 1.0)
	_beam = _layer(_draw_beam, 1.0)
	_beam.material = add
	_rain = _layer(_draw_rain, 0.0)
	_front = _layer(_draw_front, 0.0)
	resized.connect(_rebuild)
	_rebuild()


func _layer(painter: Callable, parallax: float) -> _Layer:
	var l := _Layer.new()
	l.painter = painter
	l.parallax = parallax
	_root.add_child(l)
	return l


func _rebuild() -> void:
	if size.x < 8 or size.y < 8 or size == _built_for:
		return
	_built_for = size
	_s = size.y / H
	_wd = size.x / _s
	_root.scale = Vector2(_s, _s)
	_plan()
	for l in [_sky, _far, _mid, _near, _win, _front]:
		l.queue_redraw()


func _process(delta: float) -> void:
	t += delta
	drift = sin(t * 0.045) * 70.0 + sin(t * 0.017) * 30.0
	for l: _Layer in [_sky, _far, _mid, _near, _win, _glow, _fx, _beam]:
		l.position.x = -drift * l.parallax * _s
	_win_t -= delta
	if _win_t <= 0.0:
		_win_t = 0.25
		_win.queue_redraw()
	_glow.queue_redraw()
	_fx.queue_redraw()
	_beam.queue_redraw()
	_rain.queue_redraw()


# ------------------------------------------------------------------ layout (seeded)

func _plan() -> void:
	_windows.clear()
	_shops.clear()
	_blds.clear()
	_neon = Vector2.ZERO
	var r := W.rng(SEED + 4)
	var x := -300.0
	var idx := 0
	var caffe_x := _wd * 0.78
	var pattern := [3, 2, 4, 3, 2, 3, 4, 2]
	while x < _wd + 300:
		var bw := r.randf_range(270, 380)
		_blds.append({"x": x, "w": bw, "idx": idx, "floors": int(pattern[(idx + r.randi_range(0, 1)) % pattern.size()]),
			"caffe": x <= caffe_x and x + bw > caffe_x})
		x += bw
		idx += 1
	# the lamp hangs in front of the brick between two windows, 60% across (never at the café)
	var best := _wd * 0.6
	var bd := INF
	for b: Dictionary in _blds:
		if bool(b["caffe"]):
			continue
		var bw := float(b["w"])
		var cols := clampi(int((bw - 40) / 72.0), 3, 5)
		var gap := (bw - 40) / cols
		for c in range(1, cols):
			var px := float(b["x"]) + 20 + gap * c
			if absf(px - _wd * 0.6) < bd:
				bd = absf(px - _wd * 0.6)
				best = px
	_lamp = Vector2(best, 462)
	# the Deco tower stands behind a low building, so it shows
	_tower_x = _wd * 0.5
	for b: Dictionary in _blds:
		var c := float(b["x"]) + float(b["w"]) * 0.5
		if int(b["floors"]) == 2 and c > _wd * 0.35 and c < _wd * 0.85 and not bool(b["caffe"]):
			_tower_x = c + 40
			break
	_manholes = [Vector2(_wd * 0.47, 812), Vector2(_wd * 0.9, 842)]


# ------------------------------------------------------------------ sky and the far city

func _draw_sky(ci: CanvasItem) -> void:
	var w := _wd + 400
	var x0 := -200.0
	Draw.vgrad(ci, Rect2(x0, 0, w, 330), Color(0.018, 0.024, 0.055), Color(0.05, 0.06, 0.11))
	Draw.vgrad(ci, Rect2(x0, 330, w, 300), Color(0.05, 0.06, 0.11), Color(0.16, 0.11, 0.12))
	Draw.rect(ci, Rect2(x0, 630, w, 300), Color(0.16, 0.11, 0.12))
	# the moon behind the rain clouds
	var mc := Vector2(_tower_x + 230, 70)
	ci.draw_texture_rect(_glow_tex, Rect2(mc - Vector2(170, 170), Vector2(340, 340)), false, Color(0.55, 0.62, 0.85, 0.22))
	Draw.circle(ci, mc, 30, Color(0.78, 0.8, 0.86, 0.85))
	Draw.circle(ci, mc + Vector2(-7, -5), 7, Color(0.7, 0.72, 0.8, 0.5))
	Draw.circle(ci, mc + Vector2(9, 8), 5, Color(0.7, 0.72, 0.8, 0.45))
	# clouds: long dark banks, lit from underneath by the city
	var r := W.rng(SEED + 1)
	for k in 26:
		var cx := r.randf_range(x0, x0 + w)
		var cy := r.randf_range(40, 330)
		var rx := r.randf_range(160, 420)
		var ry := r.randf_range(18, 46)
		var near_moon := clampf(1.0 - Vector2(cx, cy).distance_to(mc) / 420.0, 0.0, 1.0)
		var body := Color(0.035, 0.04, 0.075, r.randf_range(0.55, 0.85))
		Draw.ellipse(ci, Vector2(cx, cy + ry * 0.35), Vector2(rx, ry), Color(0.2, 0.16, 0.2, 0.18 + near_moon * 0.2))
		Draw.ellipse(ci, Vector2(cx, cy), Vector2(rx, ry), body)
	# haze over the skyline
	Draw.vgrad(ci, Rect2(x0, 420, w, 220), Color(0.3, 0.18, 0.14, 0.0), Color(0.3, 0.18, 0.14, 0.22))


func _draw_far(ci: CanvasItem) -> void:
	var r := W.rng(SEED + 2)
	var col := Color(0.095, 0.1, 0.15)
	var lit := Color(1.0, 0.8, 0.5, 0.45)
	# the glow of the city behind the skyline
	Draw.vgrad(ci, Rect2(-260, 380, _wd + 520, 260), Color(0.32, 0.2, 0.16, 0.0), Color(0.34, 0.2, 0.15, 0.32))
	var x := -260.0
	while x < _wd + 260:
		var bw := r.randf_range(40, 110)
		var top := r.randf_range(360, 500)
		if r.randf() < 0.18:
			top = r.randf_range(250, 340)
		Draw.rect(ci, Rect2(x, top, bw, 640 - top), col)
		if r.randf() < 0.5:
			# stepped set-backs
			Draw.rect(ci, Rect2(x + bw * 0.2, top - 26, bw * 0.6, 27), col)
			if r.randf() < 0.4:
				ci.draw_line(Vector2(x + bw * 0.5, top - 26), Vector2(x + bw * 0.5, top - 60), col, 2.0, true)
		# a few lit windows, far away
		var n := int(bw * (640 - top) / 900.0)
		for k in n:
			if r.randf() < 0.35:
				var wx := x + 5 + floorf(r.randf() * (bw - 10) / 7.0) * 7.0
				var wy := top + 8 + floorf(r.randf() * (640 - top - 16) / 11.0) * 11.0
				Draw.rect(ci, Rect2(wx, wy, 2.5, 4), Color(lit, r.randf_range(0.2, 0.55)))
		x += bw + r.randf_range(-6, 14)
	# two landmark towers: a Deco spire and a gothic one
	_deco_tower(ci, Vector2(_tower_x, 640), col.lightened(0.05))
	_gothic_tower(ci, Vector2(_tower_x - 330, 640), col.lightened(0.03))


func _deco_tower(ci: CanvasItem, base: Vector2, col: Color) -> void:
	var w := 84.0
	Draw.rect(ci, Rect2(base.x - w * 0.5, 250, w, base.y - 250), col)
	Draw.rect(ci, Rect2(base.x - w * 0.7, 380, w * 1.4, base.y - 380), col)
	# the crown: arches stacked and narrowing, with triangle windows
	var y := 250.0
	for k in 5:
		var hw := w * 0.5 * (1.0 - k * 0.17)
		var pts := PackedVector2Array()
		for s in 13:
			var a := PI + PI * float(s) / 12.0
			pts.append(Vector2(base.x + cos(a) * hw, y + sin(a) * hw * 0.9))
		pts.append(Vector2(base.x + hw, y))
		pts.append(Vector2(base.x - hw, y))
		Draw.poly(ci, pts, col)
		for s in 5:
			var a2 := PI + PI * (float(s) + 0.5) / 5.0
			var p := Vector2(base.x + cos(a2) * hw * 0.7, y + sin(a2) * hw * 0.62)
			Draw.poly(ci, PackedVector2Array([p + Vector2(-2.5, 3), p + Vector2(2.5, 3), p + Vector2(0, -4)]), Color(1.0, 0.86, 0.6, 0.55))
		y -= hw * 0.55
	Draw.poly(ci, PackedVector2Array([Vector2(base.x - 5, y + 4), Vector2(base.x + 5, y + 4), Vector2(base.x, y - 95)]), col)
	for k in 14:
		Draw.rect(ci, Rect2(base.x - w * 0.5 + 8 + (k % 7) * 10, 300 + (k / 7) * 60 + (k % 3) * 17, 3, 5), Color(1.0, 0.8, 0.5, 0.4))


func _gothic_tower(ci: CanvasItem, base: Vector2, col: Color) -> void:
	var w := 70.0
	Draw.rect(ci, Rect2(base.x - w * 0.5, 330, w, base.y - 330), col)
	Draw.rect(ci, Rect2(base.x - w * 0.34, 290, w * 0.68, 41), col)
	Draw.poly(ci, PackedVector2Array([Vector2(base.x - w * 0.34, 291), Vector2(base.x + w * 0.34, 291), Vector2(base.x, 205)]), col)
	for sx in [-1.0, 1.0]:
		Draw.poly(ci, PackedVector2Array([Vector2(base.x + sx * w * 0.5, 331), Vector2(base.x + sx * w * 0.36, 331), Vector2(base.x + sx * w * 0.43, 300)]), col)


func _draw_mid(ci: CanvasItem) -> void:
	var r := W.rng(SEED + 3)
	var col := Color(0.055, 0.05, 0.068)
	var x := -320.0
	while x < _wd + 320:
		var bw := r.randf_range(150, 260)
		var top := r.randf_range(330, 430)
		Draw.rect(ci, Rect2(x, top, bw, 700 - top), col)
		# cornice
		Draw.rect(ci, Rect2(x - 4, top - 6, bw + 8, 8), col.lightened(0.03))
		# chimneys
		for k in r.randi_range(1, 3):
			var cx := x + r.randf_range(10, bw - 26)
			Draw.rect(ci, Rect2(cx, top - r.randf_range(18, 34), 14, 34), col)
		# a water tower on some
		if r.randf() < 0.45:
			var tx := x + r.randf_range(30, bw - 70)
			var ty := top - 52
			for lx in [4.0, 22.0, 38.0]:
				ci.draw_line(Vector2(tx + lx, ty + 30), Vector2(tx + lx, top), col, 2.5, true)
			Draw.rect(ci, Rect2(tx, ty, 42, 32), col)
			Draw.poly(ci, PackedVector2Array([Vector2(tx - 3, ty + 1), Vector2(tx + 45, ty + 1), Vector2(tx + 21, ty - 16)]), col)
			for k in 3:
				ci.draw_line(Vector2(tx, ty + 8 + k * 9), Vector2(tx + 42, ty + 8 + k * 9), col.lightened(0.05), 1.0)
		# windows: a few lit ones, dim
		for fy in range(int(top) + 22, 690, 58):
			for wx in range(int(x) + 16, int(x + bw) - 24, 36):
				var h := Draw.hash01(wx, fy, SEED)
				if h < 0.16:
					Draw.rect(ci, Rect2(wx, fy, 14, 22), Color(1.0, 0.72, 0.42, 0.35 + h))
				else:
					Draw.rect(ci, Rect2(wx, fy, 14, 22), Color(0.03, 0.035, 0.06, 0.9))
		x += bw + r.randf_range(0, 20)


# ------------------------------------------------------------------ the street

func _draw_near(ci: CanvasItem) -> void:
	_windows.clear()
	_shops.clear()
	var names := ["SALUMERIA", "BARBIERE", "PASTICCERIA", "LATTERIA", "FERRAMENTA", "SARTORIA", "PANETTERIA", "FIORI"]
	for b: Dictionary in _blds:
		var idx := int(b["idx"])
		_building(ci, int(b["floors"]), Rect2(float(b["x"]), 0, float(b["w"]), GROUND), idx, bool(b["caffe"]), String(names[idx % names.size()]))
	# the sidewalk, the curb, the wet road
	var w := _wd + 800
	var x0 := -400.0
	Draw.vgrad(ci, Rect2(x0, GROUND, w, CURB - GROUND), Color(0.15, 0.14, 0.145), Color(0.2, 0.19, 0.19))
	for sx in range(int(x0), int(x0 + w), 96):
		ci.draw_line(Vector2(sx, GROUND + 1), Vector2(sx - 14, CURB - 1), Color(0, 0, 0, 0.25), 1.0)
	Draw.rect(ci, Rect2(x0, CURB - 2, w, 3), Color(0.42, 0.4, 0.38))
	Draw.vgrad(ci, Rect2(x0, CURB + 1, w, ROAD - CURB), Color(0.13, 0.125, 0.125), Color(0.06, 0.06, 0.07))
	Draw.vgrad(ci, Rect2(x0, ROAD, w, H - ROAD + 10), Color(0.06, 0.065, 0.085), Color(0.03, 0.033, 0.045))
	# Belgian block rows, barely there
	for ry in range(int(ROAD) + 8, int(H), 14):
		var off := 0 if (ry / 14) % 2 == 0 else 13
		var shade := Color(0, 0, 0, 0.18 + (ry - ROAD) / 900.0)
		ci.draw_line(Vector2(x0, ry), Vector2(x0 + w, ry), Color(0.1, 0.105, 0.125, 0.4), 1.0)
		for bx in range(int(x0) + off, int(x0 + w), 26):
			ci.draw_line(Vector2(bx, ry - 13), Vector2(bx, ry), shade, 1.0)
	# manholes
	for m: Vector2 in _manholes:
		Draw.ellipse(ci, m, Vector2(34, 7), Color(0.02, 0.02, 0.025))
		Draw.ellipse(ci, m + Vector2(0, -1), Vector2(30, 5.5), Color(0.09, 0.09, 0.1))
	# the lamp post (bishop's crook) and the street furniture
	_lamp_post(ci)
	_hydrant(ci, Vector2(_lamp.x + 150, CURB - 4))
	_ash_can(ci, Vector2(_wd * 0.36, CURB - 6))
	_alarm_box(ci, Vector2(_wd * 0.93, CURB - 6))
	_smoker_figure(ci)


func _building(ci: CanvasItem, floors: int, box: Rect2, idx: int, caffe: bool, shop_name: String) -> void:
	var x := box.position.x
	var bw := box.size.x
	var gf := 180.0
	var fh := 104.0
	var top := GROUND - gf - floors * fh - 26
	var bricks := [Color(0.15, 0.085, 0.07), Color(0.12, 0.08, 0.075), Color(0.17, 0.1, 0.075), Color(0.1, 0.075, 0.08)]
	var brick: Color = bricks[idx % bricks.size()]
	if caffe:
		brick = Color(0.16, 0.09, 0.07)
	Draw.rect(ci, Rect2(x, top, bw, GROUND - top), brick)
	# brick courses: faint lines
	for by in range(int(top) + 6, int(GROUND - gf), 7):
		ci.draw_line(Vector2(x, by), Vector2(x + bw, by), Color(0, 0, 0, 0.12), 1.0)
	# the party wall shadow between buildings
	Draw.hgrad(ci, Rect2(x, top, 10, GROUND - top), Color(0, 0, 0, 0.35), Color(0, 0, 0, 0))
	# the cornice and its brackets
	var stone := brick.lerp(Color(0.3, 0.27, 0.25), 0.55)
	Draw.rect(ci, Rect2(x - 6, top - 10, bw + 12, 14), stone.darkened(0.25))
	Draw.rect(ci, Rect2(x - 6, top - 12, bw + 12, 4), stone)
	for k in range(int(x) + 8, int(x + bw) - 8, 22):
		Draw.rect(ci, Rect2(k, top + 4, 8, 10), stone.darkened(0.3))
	Draw.rect(ci, Rect2(x, top + 14, bw, 5), stone.darkened(0.35))
	# upper windows
	var cols := clampi(int((bw - 40) / 72.0), 3, 5)
	var gap := (bw - 40) / cols
	for f in floors:
		var fy := GROUND - gf - (f + 1) * fh + 18
		for c in cols:
			var wr := Rect2(x + 20 + gap * c + (gap - 42) * 0.5, fy, 42, 66)
			Draw.rect(ci, Rect2(wr.position + Vector2(-5, -8), Vector2(wr.size.x + 10, 8)), stone)
			Draw.rect(ci, Rect2(wr.position + Vector2(-4, wr.size.y), Vector2(wr.size.x + 8, 5)), stone.darkened(0.1))
			Draw.rect(ci, wr.grow(2), Color(0.03, 0.025, 0.025))
			_windows.append({"r": wr, "per": 5.0 + Draw.hash01(idx, f * 7 + c, 3) * 18.0,
				"ph": Draw.hash01(idx, f * 7 + c, 4) * 10.0, "seed": idx * 131 + f * 17 + c,
				"bias": 0.14 + 0.2 * Draw.hash01(idx, f, 5), "tint": Draw.hash01(idx, c, 6)})
	# fire escapes on some fronts
	if idx % 2 == 0 and not caffe:
		_fire_escape(ci, x + 20 + gap * (1 if cols > 3 else 0), gap * 2.0, floors, gf, fh)
	# the ground floor: sign band, shop window, door
	var gy := GROUND - gf
	Draw.rect(ci, Rect2(x, gy, bw, 8), stone.darkened(0.2))
	var sign_r := Rect2(x + 18, gy + 12, bw - 36, 48)
	Draw.rect(ci, sign_r, Color(0.05, 0.04, 0.035))
	ci.draw_rect(sign_r.grow(-3), Color(0.55, 0.42, 0.2, 0.55), false, 1.5)
	var win_r := Rect2(x + 22, gy + 72, bw * 0.62 - 22, GROUND - gy - 82)
	var door_r := Rect2(win_r.end.x + 20, gy + 70, 58, GROUND - gy - 70)
	var lit := caffe or Draw.hash01(idx, 1, 9) < 0.45
	var shop_col := Color(1.0, 0.72, 0.4) if caffe else Color(1.0, 0.8, 0.52).lerp(Color(1.0, 0.66, 0.42), Draw.hash01(idx, 2, 9))
	Draw.rect(ci, win_r.grow(4), Color(0.08, 0.05, 0.035))
	if lit:
		Draw.vgrad(ci, win_r, shop_col.darkened(0.25), shop_col.darkened(0.55))
		_shop_inside(ci, win_r, caffe, idx)
	else:
		Draw.vgrad(ci, win_r, Color(0.05, 0.06, 0.08), Color(0.03, 0.035, 0.05))
		ci.draw_line(win_r.position + Vector2(10, 10), win_r.position + Vector2(40, 60), Color(1, 1, 1, 0.04), 8.0)
	for k in 1 + int(win_r.size.x / 110.0):
		var mx := win_r.position.x + (k + 1) * win_r.size.x / (2 + int(win_r.size.x / 110.0))
		Draw.rect(ci, Rect2(mx - 2, win_r.position.y, 4, win_r.size.y), Color(0.08, 0.05, 0.035))
	Draw.rect(ci, Rect2(win_r.position.x, win_r.position.y + 22, win_r.size.x, 3), Color(0.08, 0.05, 0.035))
	Draw.rect(ci, Rect2(win_r.position.x - 6, win_r.end.y + 2, win_r.size.x + 12, 8), stone.darkened(0.3))
	_shops.append({"r": win_r, "lit": lit, "color": shop_col, "caffe": caffe})
	# the door with its transom
	Draw.rect(ci, door_r.grow(3), Color(0.07, 0.045, 0.03))
	Draw.rect(ci, door_r, Color(0.2, 0.12, 0.08))
	Draw.rect(ci, Rect2(door_r.position + Vector2(8, 8), Vector2(door_r.size.x - 16, 50)), Color(1.0, 0.75, 0.45, 0.55) if lit else Color(0.04, 0.05, 0.07))
	Draw.rect(ci, Rect2(door_r.position + Vector2(8, 66), Vector2(door_r.size.x - 16, door_r.size.y - 76)), Color(0.15, 0.09, 0.06))
	Draw.circle(ci, door_r.position + Vector2(door_r.size.x - 10, door_r.size.y * 0.58), 2.5, Color(0.75, 0.6, 0.3))
	# the name on the sign
	if caffe:
		_neon = sign_r.get_center()
		# the dark neon tubes (lit in the glow layer)
		var fs := 44
		var tw := _neon_font.get_string_size("CAFFÈ", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		ci.draw_string(_neon_font, Vector2(_neon.x - tw * 0.5, _neon.y + fs * 0.36), "CAFFÈ", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.35, 0.12, 0.1))
		_smoker = Vector2(door_r.end.x + 34, GROUND)
	else:
		var sf := W.ui_font("serif")
		var fs2 := 26
		var tw2 := sf.get_string_size(shop_name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
		var goldc := Color(0.78, 0.62, 0.3, 0.75)
		ci.draw_string(sf, Vector2(sign_r.get_center().x - tw2 * 0.5, sign_r.get_center().y + 9), shop_name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, goldc)
		# an awning on every other shop
		if idx % 3 == 1:
			_awning(ci, Rect2(win_r.position.x - 10, gy + 62, win_r.size.x + 20, 44), idx)


func _shop_inside(ci: CanvasItem, wr: Rect2, caffe: bool, idx: int) -> void:
	var dark := Color(0.12, 0.07, 0.05, 0.85)
	if caffe:
		# the counter, the espresso machine, bottles, a couple at a table
		Draw.rect(ci, Rect2(wr.position.x, wr.end.y - 34, wr.size.x, 34), Color(0.2, 0.1, 0.06, 0.9))
		Draw.rect(ci, Rect2(wr.position.x + 30, wr.end.y - 70, 36, 38), Color(0.45, 0.35, 0.2, 0.95))
		Draw.circle(ci, Vector2(wr.position.x + 48, wr.end.y - 74), 10, Color(0.55, 0.45, 0.25))
		for k in 8:
			Draw.rect(ci, Rect2(wr.position.x + 90 + k * 12, wr.position.y + 30, 6, 16 + (k % 3) * 3), Color(0.2, 0.3, 0.15, 0.8))
		_head(ci, Vector2(wr.end.x - 60, wr.end.y - 44), dark, true)
		_head(ci, Vector2(wr.end.x - 120, wr.end.y - 40), dark, false)
	else:
		# shelves of goods
		for s in 3:
			var sy := wr.position.y + 30 + s * 24
			Draw.rect(ci, Rect2(wr.position.x + 6, sy, wr.size.x - 12, 3), Color(0, 0, 0, 0.35))
			for k in int((wr.size.x - 20) / 16):
				if Draw.hash01(idx * 3 + s, k, 11) < 0.7:
					Draw.rect(ci, Rect2(wr.position.x + 10 + k * 16, sy - 12, 10, 12), Color(0, 0, 0, 0.18 + 0.2 * Draw.hash01(k, s, 12)))
		if Draw.hash01(idx, 3, 9) < 0.5:
			_head(ci, Vector2(wr.position.x + wr.size.x * 0.4, wr.end.y - 20), dark, idx % 2 == 0)


func _head(ci: CanvasItem, p: Vector2, col: Color, hat: bool) -> void:
	Draw.ellipse(ci, p + Vector2(0, 28), Vector2(20, 26), col)
	Draw.circle(ci, p, 11, col)
	if hat:
		Draw.rect(ci, Rect2(p.x - 15, p.y - 8, 30, 4), col)
		Draw.rrect(ci, Rect2(p.x - 10, p.y - 19, 20, 13), 3, col)


func _awning(ci: CanvasItem, r: Rect2, idx: int) -> void:
	var cols := [Color(0.35, 0.1, 0.09), Color(0.1, 0.2, 0.14), Color(0.13, 0.15, 0.25)]
	var c: Color = cols[idx % cols.size()]
	var cream := Color(0.42, 0.38, 0.32)
	var stripes := int(r.size.x / 22.0)
	var sw := r.size.x / stripes
	for k in stripes:
		var sc := c if k % 2 == 0 else cream
		var x0 := r.position.x + k * sw
		Draw.poly(ci, PackedVector2Array([Vector2(x0 + 4, r.position.y), Vector2(x0 + sw + 4, r.position.y),
			Vector2(x0 + sw, r.end.y - 10), Vector2(x0, r.end.y - 10)]), sc, false)
		# scalloped valance
		Draw.ellipse(ci, Vector2(x0 + sw * 0.5, r.end.y - 10), Vector2(sw * 0.5, 9), sc)
	Draw.rect(ci, Rect2(r.position.x, r.position.y - 2, r.size.x + 4, 4), c.darkened(0.4))
	Draw.hgrad(ci, Rect2(r.position.x, r.end.y - 2, r.size.x, 18), Color(0, 0, 0, 0.18), Color(0, 0, 0, 0.18))


func _fire_escape(ci: CanvasItem, x: float, w: float, floors: int, gf: float, fh: float) -> void:
	var iron := Color(0.03, 0.03, 0.035)
	var prev := Vector2.INF
	for f in floors:
		var py := GROUND - gf - f * fh - 16
		# platform and railing
		Draw.rect(ci, Rect2(x - 6, py, w + 12, 5), iron)
		Draw.rect(ci, Rect2(x - 6, py - 32, w + 12, 3), iron)
		for k in range(0, int(w + 12), 9):
			ci.draw_line(Vector2(x - 6 + k, py - 32), Vector2(x - 6 + k, py), Color(iron, 0.85), 1.2)
		# brackets under the platform
		ci.draw_line(Vector2(x, py + 5), Vector2(x + 16, py + 22), iron, 2.0)
		ci.draw_line(Vector2(x + w, py + 5), Vector2(x + w - 16, py + 22), iron, 2.0)
		# stairs up to the next landing
		if f < floors - 1:
			var a := Vector2(x + (w * 0.15 if f % 2 == 0 else w * 0.85), py)
			var b := Vector2(x + (w * 0.85 if f % 2 == 0 else w * 0.15), py - fh)
			ci.draw_line(a, b, iron, 3.0, true)
			ci.draw_line(a + Vector2(0, -8), b + Vector2(0, -8), iron, 1.5, true)
			for s in 9:
				var q := a.lerp(b, (s + 0.5) / 9.0)
				ci.draw_line(q, q + Vector2(0, -8), iron, 1.5)
		prev = Vector2(x, py)
	# the drop ladder, hanging over the sidewalk
	var ly := GROUND - gf - 16
	ci.draw_line(Vector2(x + w * 0.5 - 10, ly), Vector2(x + w * 0.5 - 10, ly + 70), iron, 2.0)
	ci.draw_line(Vector2(x + w * 0.5 + 10, ly), Vector2(x + w * 0.5 + 10, ly + 70), iron, 2.0)
	for k in 7:
		ci.draw_line(Vector2(x + w * 0.5 - 10, ly + 8 + k * 9), Vector2(x + w * 0.5 + 10, ly + 8 + k * 9), iron, 1.5)


func _lamp_post(ci: CanvasItem) -> void:
	var iron := Color(0.05, 0.05, 0.055)
	var base := Vector2(_lamp.x - 70, CURB - 3)
	# fluted post with a heavy base
	Draw.poly(ci, PackedVector2Array([base + Vector2(-13, 0), base + Vector2(13, 0), base + Vector2(8, -30), base + Vector2(-8, -30)]), iron)
	Draw.rect(ci, Rect2(base.x - 5, _lamp.y - 30, 10, base.y - 30 - _lamp.y + 30), iron)
	Draw.rect(ci, Rect2(base.x - 7, base.y - 60, 14, 6), iron)
	# the crook
	var pts := PackedVector2Array()
	for k in 13:
		var a := PI + PI * float(k) / 12.0
		pts.append(Vector2(base.x + 35, _lamp.y - 30) + Vector2(cos(a), sin(a)) * 35.0)
	ci.draw_polyline(pts, iron, 6.0, true)
	ci.draw_line(Vector2(base.x + 70, _lamp.y - 30), Vector2(_lamp.x, _lamp.y - 16), iron, 4.0, true)
	# the lantern: a cap with a finial, four panes of glass, the bottom ring
	var L := _lamp
	Draw.poly(ci, PackedVector2Array([L + Vector2(-27, -18), L + Vector2(27, -18), L + Vector2(12, -34), L + Vector2(-12, -34)]), iron)
	Draw.circle(ci, L + Vector2(0, -37), 4.5, iron)
	Draw.poly(ci, PackedVector2Array([L + Vector2(-21, -18), L + Vector2(21, -18), L + Vector2(14, 22), L + Vector2(-14, 22)]), Color(1.0, 0.86, 0.58))
	Draw.poly(ci, PackedVector2Array([L + Vector2(-9, -12), L + Vector2(9, -12), L + Vector2(6, 16), L + Vector2(-6, 16)]), Color(1.0, 0.97, 0.86))
	ci.draw_line(L + Vector2(-7, -18), L + Vector2(-5, 22), Color(iron, 0.7), 2.0)
	ci.draw_line(L + Vector2(7, -18), L + Vector2(5, 22), Color(iron, 0.7), 2.0)
	Draw.rect(ci, Rect2(L.x - 17, L.y + 21, 34, 5), iron)
	Draw.poly(ci, PackedVector2Array([L + Vector2(-8, 26), L + Vector2(8, 26), L + Vector2(0, 36)]), iron)


func _hydrant(ci: CanvasItem, p: Vector2) -> void:
	var c := Color(0.22, 0.08, 0.07)
	Draw.rect(ci, Rect2(p.x - 9, p.y - 30, 18, 30), c)
	Draw.rrect(ci, Rect2(p.x - 11, p.y - 38, 22, 10), 4, c)
	Draw.rect(ci, Rect2(p.x - 15, p.y - 22, 30, 7), c.darkened(0.2))
	Draw.rect(ci, Rect2(p.x - 12, p.y - 3, 24, 4), c.darkened(0.3))


func _ash_can(ci: CanvasItem, p: Vector2) -> void:
	var c := Color(0.12, 0.12, 0.13)
	Draw.rect(ci, Rect2(p.x - 16, p.y - 42, 32, 42), c)
	Draw.rect(ci, Rect2(p.x - 18, p.y - 44, 36, 5), c.lightened(0.1))
	for k in 3:
		Draw.rect(ci, Rect2(p.x - 16, p.y - 34 + k * 12, 32, 2), c.darkened(0.3))


func _alarm_box(ci: CanvasItem, p: Vector2) -> void:
	var c := Color(0.2, 0.07, 0.06)
	Draw.rect(ci, Rect2(p.x - 3, p.y - 110, 6, 110), Color(0.06, 0.06, 0.07))
	Draw.rrect(ci, Rect2(p.x - 13, p.y - 140, 26, 34), 4, c)
	Draw.circle(ci, Vector2(p.x, p.y - 146), 7, Color(0.9, 0.35, 0.2, 0.9))


## A man in an overcoat and a fedora, leaning by the café door, smoking.
func _smoker_figure(ci: CanvasItem) -> void:
	if _smoker == Vector2.ZERO:
		return
	var f := _smoker
	var c := Color(0.02, 0.02, 0.025)
	# legs and coat
	Draw.poly(ci, PackedVector2Array([f + Vector2(-8, 0), f + Vector2(-3, 0), f + Vector2(-2, -40), f + Vector2(-12, -40)]), c)
	Draw.poly(ci, PackedVector2Array([f + Vector2(3, 0), f + Vector2(8, 0), f + Vector2(6, -40), f + Vector2(-2, -40)]), c)
	Draw.poly(ci, PackedVector2Array([f + Vector2(-17, -34), f + Vector2(12, -34), f + Vector2(10, -96), f + Vector2(-14, -100)]), c)
	# shoulders, arm up to the mouth
	Draw.ellipse(ci, f + Vector2(-2, -98), Vector2(16, 9), c)
	Draw.capsule(ci, f + Vector2(8, -94), f + Vector2(16, -76), 4.5, c)
	Draw.capsule(ci, f + Vector2(16, -76), f + Vector2(9, -108), 4.0, c)
	# head and hat
	Draw.circle(ci, f + Vector2(0, -112), 9, c)
	Draw.ellipse(ci, f + Vector2(0, -118), Vector2(17, 3.5), c)
	Draw.rrect(ci, Rect2(f.x - 9, f.y - 131, 18, 13), 4, c)
	Draw.rect(ci, Rect2(f.x - 9, f.y - 121, 18, 3), Color(0.3, 0.08, 0.06))
	_smoker = f + Vector2(12, -110)


# ------------------------------------------------------------------ windows (4 Hz)

func _window_lit(w: Dictionary) -> bool:
	var cyc := floorf(t / float(w["per"]) + float(w["ph"]))
	return Draw.hash01(int(w["seed"]), int(cyc), 77) < float(w["bias"])


func _draw_windows(ci: CanvasItem) -> void:
	for w: Dictionary in _windows:
		var r: Rect2 = w["r"]
		if _window_lit(w):
			var warm := Color(1.0, 0.76, 0.45).lerp(Color(1.0, 0.88, 0.62), float(w["tint"]))
			Draw.vgrad(ci, r, warm, warm.darkened(0.3))
			# a drawn shade, curtains at the sides
			var shade_h := r.size.y * (0.2 + 0.45 * float(w["tint"]))
			Draw.rect(ci, Rect2(r.position, Vector2(r.size.x, shade_h)), warm.lerp(Color(0.9, 0.7, 0.5), 0.4).darkened(0.12))
			Draw.rect(ci, Rect2(r.position.x, r.position.y + shade_h - 2, r.size.x, 2), Color(0, 0, 0, 0.3))
			Draw.rect(ci, Rect2(r.position, Vector2(7, r.size.y)), Color(0.5, 0.2, 0.12, 0.6))
			Draw.rect(ci, Rect2(r.end.x - 7, r.position.y, 7, r.size.y), Color(0.5, 0.2, 0.12, 0.6))
			if int(w["seed"]) % 5 == 0:
				_head(ci, Vector2(r.get_center().x + 4, r.end.y - 16), Color(0.15, 0.08, 0.05, 0.75), false)
		else:
			Draw.vgrad(ci, r, Color(0.06, 0.07, 0.1), Color(0.03, 0.035, 0.05))
			ci.draw_line(r.position + Vector2(6, 8), r.position + Vector2(18, 30), Color(0.4, 0.45, 0.6, 0.06), 5.0)
		# sash bar and muntin
		Draw.rect(ci, Rect2(r.position.x, r.get_center().y - 2, r.size.x, 3), Color(0.06, 0.04, 0.035))
		Draw.rect(ci, Rect2(r.get_center().x - 1, r.position.y, 2, r.size.y), Color(0.06, 0.04, 0.035))


# ------------------------------------------------------------------ light (additive, per frame)

func _glow_at(ci: CanvasItem, c: Vector2, radii: Vector2, col: Color) -> void:
	ci.draw_texture_rect(_glow_tex, Rect2(c - radii, radii * 2.0), false, col)


func _neon_on() -> float:
	# mostly on; now and then it stutters
	var k := floori(t * 12.0)
	var h := Draw.hash01(k, 3, 91)
	var burst := Draw.hash01(floori(t / 4.0), 1, 92) < 0.35 and fmod(t, 4.0) < 0.6
	if burst and h < 0.55:
		return 0.12
	return 0.92 + 0.08 * sin(t * 90.0)


func _draw_glow(ci: CanvasItem) -> void:
	var flick := 0.96 + 0.04 * sin(t * 13.0) * sin(t * 7.3)
	# the street lamp: a big soft halo, a pool on the sidewalk, light on the wall
	_glow_at(ci, _lamp, Vector2(520, 460), Color(0.55, 0.36, 0.16, 0.5 * flick))
	_glow_at(ci, _lamp, Vector2(190, 190), Color(1.0, 0.74, 0.4, 0.6 * flick))
	_glow_at(ci, _lamp, Vector2(60, 60), Color(1.0, 0.9, 0.7, 0.9))
	# a cone of light down to the sidewalk
	var cone := PackedVector2Array([_lamp + Vector2(-18, 20), _lamp + Vector2(18, 20), Vector2(_lamp.x + 150, GROUND + 26), Vector2(_lamp.x - 150, GROUND + 26)])
	ci.draw_polygon(cone, PackedColorArray([Color(1.0, 0.8, 0.5, 0.2 * flick), Color(1.0, 0.8, 0.5, 0.2 * flick), Color(1.0, 0.8, 0.5, 0.0), Color(1.0, 0.8, 0.5, 0.0)]))
	_glow_at(ci, Vector2(_lamp.x, GROUND + 16), Vector2(280, 36), Color(0.8, 0.55, 0.3, 0.4 * flick))
	# lit shop windows spill onto the sidewalk
	for s: Dictionary in _shops:
		if s["lit"]:
			var r: Rect2 = s["r"]
			var c: Color = s["color"]
			_glow_at(ci, r.get_center(), r.size * 0.75, Color(c, 0.14))
			_glow_at(ci, Vector2(r.get_center().x, GROUND + 14), Vector2(r.size.x * 0.7, 26), Color(c, 0.28))
			_reflect(ci, r.get_center().x, r.size.x * 0.5, Color(c, 0.14), 0.0)
	# lit windows glow a little into the street
	for w: Dictionary in _windows:
		if _window_lit(w):
			var r: Rect2 = w["r"]
			_glow_at(ci, r.get_center(), Vector2(52, 60), Color(0.9, 0.6, 0.3, 0.1))
	# the neon word
	if _neon != Vector2.ZERO:
		var on := _neon_on()
		var red := Color(1.0, 0.22, 0.16)
		_glow_at(ci, _neon, Vector2(260, 120), Color(red, 0.42 * on))
		_glow_at(ci, _neon, Vector2(130, 50), Color(red, 0.5 * on))
		var fs := 44
		var tw := _neon_font.get_string_size("CAFFÈ", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var p := Vector2(_neon.x - tw * 0.5, _neon.y + fs * 0.36)
		ci.draw_string_outline(_neon_font, p, "CAFFÈ", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 10, Color(red, 0.25 * on))
		ci.draw_string_outline(_neon_font, p, "CAFFÈ", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(red, 0.6 * on))
		ci.draw_string(_neon_font, p, "CAFFÈ", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.72, 0.62, on))
		_reflect(ci, _neon.x, tw * 0.45, Color(red, 0.3 * on), 1.3)
	_reflect(ci, _lamp.x, 30, Color(1.0, 0.72, 0.4, 0.5 * flick), 2.1)
	# the man's cigarette: it glows when he draws on it
	if _smoker != Vector2.ZERO:
		var drag := pow(maxf(0.0, sin(t * 0.7)), 8.0)
		_glow_at(ci, _smoker, Vector2(10, 10) * (1.0 + drag), Color(1.0, 0.45, 0.15, 0.5 + 0.5 * drag))
	# the aircraft lamp on the Deco spire, blinking
	var bx := _tower_x
	var blink := 1.0 if fmod(t, 2.4) < 0.5 else 0.15
	var par := Vector2(-drift * (0.12 - 1.0), 0)  # this layer drifts at 1.0; the spire at 0.12
	_glow_at(ci, Vector2(bx, 80) + par, Vector2(16, 16), Color(1.0, 0.2, 0.15, 0.9 * blink))


## A light's wavy reflection in the wet road below it.
func _reflect(ci: CanvasItem, x: float, half_w: float, col: Color, ph: float) -> void:
	var y := ROAD + 4
	var k := 0
	while y < H:
		var fade := 1.0 - (y - ROAD) / (H - ROAD + 40)
		var wob := sin(t * 2.4 + y * 0.09 + ph) * 6.0 + sin(t * 1.3 + y * 0.21) * 3.0
		var w := half_w * (0.6 + 0.4 * sin(y * 0.13 + t * 3.0 + ph))
		ci.draw_line(Vector2(x - w + wob, y), Vector2(x + w + wob, y), Color(col, col.a * fade), 3.0)
		y += 6.0 + k % 3
		k += 1


# ------------------------------------------------------------------ the car, steam, puddles

const CAR_PERIOD := 17.0
const CAR_TIME := 6.5


func _car_state() -> Dictionary:
	var cyc := floorf((t + 9.0) / CAR_PERIOD)
	var u := (fmod(t + 9.0, CAR_PERIOD)) / CAR_TIME
	if u > 1.0:
		return {}
	var dir := 1.0 if Draw.hash01(int(cyc), 0, 55) < 0.5 else -1.0
	var x0 := drift - 420.0
	var x1 := drift + _wd + 420.0
	var x := lerpf(x0, x1, u) if dir > 0 else lerpf(x1, x0, u)
	return {"x": x, "dir": dir, "y": 866.0}


func _draw_fx(ci: CanvasItem) -> void:
	# steam from the manholes
	for m: Vector2 in _manholes:
		for k in 6:
			var age := fmod(t * 0.22 + k / 6.0, 1.0)
			var p := m + Vector2(sin(t * 0.6 + k) * 10.0 + age * 40.0, -age * 150.0)
			var rad := 20.0 + age * 70.0
			ci.draw_texture_rect(_glow_tex, Rect2(p - Vector2(rad, rad * 0.8), Vector2(rad * 2, rad * 1.6)), false, Color(0.55, 0.52, 0.55, 0.12 * sin(age * PI)))
	# rain rings in the puddles
	for k in 46:
		var per := 0.7 + Draw.hash01(k, 1, 31) * 0.9
		var cyc := floori((t + k * 0.37) / per)
		var age := fmod(t + k * 0.37, per) / per
		var on_walk := k % 6 == 0
		var px := Draw.hash01(k, cyc, 32) * (_wd + 300) - 150 + drift
		var py := (GROUND + 6 + Draw.hash01(k, cyc, 33) * 20) if on_walk else (ROAD + 10 + Draw.hash01(k, cyc, 33) * (H - ROAD - 16))
		var rx := 3.0 + age * (16.0 + (py - ROAD) * 0.08)
		var a := (1.0 - age) * 0.3
		var pts := Draw.ellipse_points(Vector2(px, py), Vector2(rx, rx * 0.22), 0.0, 16)
		pts.append(pts[0])
		ci.draw_polyline(pts, Color(0.75, 0.8, 0.9, a), 1.2, true)
	# the car
	var cs := _car_state()
	if not cs.is_empty():
		_car(ci, Vector2(float(cs["x"]), float(cs["y"])), float(cs["dir"]))


func _car(ci: CanvasItem, at: Vector2, dir: float) -> void:
	var sc := 0.62
	ci.draw_set_transform(at, 0.0, Vector2(sc * dir, sc))
	var body := Color(0.05, 0.05, 0.058)
	var edge := Color(0.3, 0.27, 0.25)
	var near_lamp := exp(-pow((at.x - drift - _lamp.x + drift) / 320.0, 2.0))
	var gleam := Color(1.0, 0.8, 0.5, 0.25 + 0.6 * near_lamp)
	# shadow on the road
	Draw.ellipse(ci, Vector2(165, 4), Vector2(190, 12), Color(0, 0, 0, 0.5))
	# spare tyre
	Draw.circle(ci, Vector2(10, -80), 27, Color(0.03, 0.03, 0.035))
	Draw.circle(ci, Vector2(10, -80), 15, Color(0.08, 0.08, 0.09))
	# body: the tub and the long hood
	Draw.poly(ci, PackedVector2Array([Vector2(18, -48), Vector2(20, -94), Vector2(192, -98), Vector2(296, -92),
		Vector2(312, -84), Vector2(314, -52), Vector2(18, -48)]), body)
	# the cabin
	Draw.poly(ci, PackedVector2Array([Vector2(28, -92), Vector2(38, -150), Vector2(64, -160), Vector2(172, -160),
		Vector2(192, -150), Vector2(198, -96)]), body)
	# windows, dark with a warm hint of the street
	Draw.poly(ci, PackedVector2Array([Vector2(50, -104), Vector2(56, -144), Vector2(108, -148), Vector2(108, -104)]), Color(0.1, 0.1, 0.13))
	Draw.poly(ci, PackedVector2Array([Vector2(116, -104), Vector2(116, -148), Vector2(172, -148), Vector2(186, -138), Vector2(188, -104)]), Color(0.1, 0.1, 0.13))
	ci.draw_line(Vector2(60, -140), Vector2(96, -112), Color(1, 0.85, 0.6, 0.08 + 0.2 * near_lamp), 6.0)
	# the driver's hat against the window
	Draw.circle(ci, Vector2(158, -118), 10, Color(0.03, 0.03, 0.035))
	Draw.rect(ci, Rect2(144, -128, 28, 4), Color(0.03, 0.03, 0.035))
	Draw.rrect(ci, Rect2(149, -140, 18, 13), 3, Color(0.03, 0.03, 0.035))
	# hood louvres, the radiator, bumpers
	for k in 6:
		ci.draw_line(Vector2(222 + k * 10, -88), Vector2(222 + k * 10, -66), Color(0.12, 0.12, 0.13), 2.0)
	Draw.rect(ci, Rect2(306, -92, 9, 42), Color(0.35, 0.32, 0.28))
	Draw.rect(ci, Rect2(314, -60, 10, 8), Color(0.3, 0.28, 0.26))
	Draw.rect(ci, Rect2(6, -58, 12, 7), Color(0.3, 0.28, 0.26))
	# fenders over the wheels and the running board
	for wx in [70.0, 262.0]:
		var pts := PackedVector2Array()
		for s in 13:
			var a := PI + PI * float(s) / 12.0
			pts.append(Vector2(wx + cos(a) * 44.0, -36 + sin(a) * 36.0))
		pts.append(Vector2(wx + 44, -30))
		pts.append(Vector2(wx - 44, -30))
		Draw.poly(ci, pts, body)
	Draw.rect(ci, Rect2(110, -42, 112, 7), body)
	# gleam along the roof and the fender tops
	ci.draw_polyline(PackedVector2Array([Vector2(40, -150), Vector2(64, -159), Vector2(172, -159), Vector2(190, -150)]), gleam, 2.0, true)
	ci.draw_line(Vector2(198, -96), Vector2(296, -91), Color(gleam, gleam.a * 0.7), 1.5, true)
	ci.draw_line(Vector2(22, -93), Vector2(190, -97), Color(edge, 0.5), 1.0, true)
	# wheels with turning spokes
	var roll := at.x / (32.0 * sc) * dir
	for wx in [70.0, 262.0]:
		var c := Vector2(wx, -30)
		Draw.circle(ci, c, 30, Color(0.02, 0.02, 0.025))
		Draw.circle(ci, c, 21, Color(0.16, 0.14, 0.13))
		for s in 10:
			var a := roll + TAU * s / 10.0
			ci.draw_line(c, c + Vector2(cos(a), sin(a)) * 20.0, Color(0.32, 0.3, 0.28), 1.5, true)
		Draw.circle(ci, c, 6, Color(0.4, 0.36, 0.3))
	# headlamp on its stalk, tail lamp
	ci.draw_line(Vector2(292, -84), Vector2(298, -100), body, 4.0)
	Draw.circle(ci, Vector2(300, -106), 10, Color(0.2, 0.2, 0.2))
	Draw.circle(ci, Vector2(303, -106), 7, Color(1.0, 0.93, 0.75))
	Draw.circle(ci, Vector2(16, -64), 4, Color(0.9, 0.15, 0.1))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_beam(ci: CanvasItem) -> void:
	var cs := _car_state()
	if cs.is_empty():
		return
	var dir := float(cs["dir"])
	var at := Vector2(float(cs["x"]), float(cs["y"]))
	var sc := 0.62
	var lamp := at + Vector2(303 * sc * dir, -106 * sc)
	var warm := Color(1.0, 0.9, 0.68)
	# the cone of light, down onto the road ahead
	var far_x := lamp.x + 620.0 * dir
	var pts := PackedVector2Array([lamp + Vector2(0, -4), Vector2(far_x, lamp.y - 60), Vector2(far_x, at.y + 10), lamp + Vector2(0, 5)])
	var cols := PackedColorArray([Color(warm, 0.42), Color(warm, 0.0), Color(warm, 0.0), Color(warm, 0.42)])
	ci.draw_polygon(pts, cols)
	_glow_at(ci, Vector2(lamp.x + 260.0 * dir, at.y - 2), Vector2(230, 24), Color(warm, 0.35))
	_glow_at(ci, lamp, Vector2(46, 46), Color(warm, 0.9))
	# its sweep across the shopfronts and the sidewalk
	_glow_at(ci, Vector2(lamp.x + 180.0 * dir, GROUND - 60), Vector2(300, 160), Color(warm, 0.1))
	# the tail lamp
	var tail := at + Vector2(16 * sc * dir, -64 * sc)
	_glow_at(ci, tail, Vector2(22, 16), Color(1.0, 0.2, 0.1, 0.7))
	# the headlamp's reflection in the wet road
	_reflect(ci, lamp.x, 14, Color(warm, 0.35), 0.5)


# ------------------------------------------------------------------ rain and the frame

func _draw_rain(ci: CanvasItem) -> void:
	var wpx := _wd
	var sets := [[240, 0.1, 1.0, 900.0, 16.0], [140, 0.18, 1.2, 1250.0, 26.0], [50, 0.26, 1.8, 1700.0, 44.0]]
	var lamp_scr := _lamp - Vector2(drift, 0)
	for si in sets.size():
		var sp: Array = sets[si]
		var n: int = sp[0]
		var alpha: float = sp[1]
		var width: float = sp[2]
		var speed: float = sp[3]
		var ln: float = sp[4]
		var pts := PackedVector2Array()
		var lit := PackedVector2Array()
		for k in n:
			var x0 := Draw.hash01(k, si, 41) * (wpx + 200)
			var y0 := Draw.hash01(k, si, 42) * (H + 100)
			var sp_k := speed * (0.85 + 0.3 * Draw.hash01(k, si, 43))
			var y := fmod(y0 + t * sp_k, H + 100) - 50
			var x := fmod(x0 - y * 0.16 + 10000.0, wpx + 200) - 100
			var a := Vector2(x, y)
			var b := a + Vector2(-ln * 0.16, ln)
			if a.distance_to(lamp_scr) < 260.0 or (_neon != Vector2.ZERO and a.distance_to(_neon - Vector2(drift, 0)) < 170.0):
				lit.append(a)
				lit.append(b)
			else:
				pts.append(a)
				pts.append(b)
		if pts.size() > 0:
			ci.draw_multiline(pts, Color(0.7, 0.76, 0.9, alpha), width)
		if lit.size() > 0:
			ci.draw_multiline(lit, Color(1.0, 0.86, 0.66, alpha * 2.4), width)


func _draw_front(ci: CanvasItem) -> void:
	var w := _wd
	# the menu side: dark on the left, clearing toward the lamp
	if left_scrim > 0.0:
		var ink := Color(0.012, 0.012, 0.022)
		Draw.hgrad(ci, Rect2(0, 0, w * 0.3, H), Color(ink, left_scrim), Color(ink, left_scrim * 0.85))
		Draw.hgrad(ci, Rect2(w * 0.3, 0, w * 0.28, H), Color(ink, left_scrim * 0.85), Color(ink, 0.0))
	# vignette: top and bottom, soft corners
	Draw.vgrad(ci, Rect2(0, 0, w, 150), Color(0, 0, 0, 0.55), Color(0, 0, 0, 0))
	Draw.vgrad(ci, Rect2(0, H - 110, w, 110), Color(0, 0, 0, 0), Color(0, 0, 0, 0.5))
	Draw.hgrad(ci, Rect2(w - 140, 0, 140, H), Color(0, 0, 0, 0), Color(0, 0, 0, 0.45))
