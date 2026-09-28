class_name Portrait
extends RefCounted
## Head-and-shoulders portraits for dialogs, the family book and the tutorial, drawn from the
## same look seed as the Person2D on the street (same skin, hat, clothes: both read PersonLook).
## Painted style: soft gradients lit from the upper left, a warm lamp-lit wall behind.
##
##   Portrait.draw(ci, rect, kind, look, family_color, extra, mood)
##     ci      any CanvasItem, called from inside its _draw()
##     rect    where to draw (square-ish; it fills it, background included)
##     kind    same kinds as Person2D
##     mood    "", "angry", "scared", "happy", "smug"
##
## A Control that shows one: Portrait.control(kind, look, color, extra, mood) -> Control
## Looks right from 64 px (the family book) to 240 px; below ~90 px fine detail is left out.

const NONE := Color(0, 0, 0, 0)
const LIGHT := Vector2(-0.55, -0.83)          # the lamp is up and to the left
const WARM := Color(1.0, 0.88, 0.66)
const INK := Color(0.07, 0.05, 0.05)


## Maps the 100 x 100 portrait space into the rect and paints soft shapes.
class Painter extends RefCounted:
	var ci: CanvasItem
	var o := Vector2.ZERO
	var k := 1.0
	var fs := 1.0
	var anchor := Vector2(50.0, 100.0)
	var light := Vector2(-0.55, -0.83)
	var small := false

	func _init(c: CanvasItem, r: Rect2) -> void:
		ci = c
		var s := minf(r.size.x, r.size.y)
		k = s / 100.0
		o = r.position + (r.size - Vector2(s, s)) * 0.5
		small = s < 90.0

	func m(p: Vector2) -> Vector2:
		return o + ((p - anchor) * fs + anchor) * k

	func mp(pts: PackedVector2Array) -> PackedVector2Array:
		var q := PackedVector2Array()
		q.resize(pts.size())
		for i in pts.size():
			q[i] = m(pts[i])
		return q

	## A line width in screen pixels, never thinner than a pixel.
	func lw(units: float) -> float:
		return maxf(units * k * fs, 1.0)

	func _edge(q: PackedVector2Array, col: Color) -> void:
		var loop := q.duplicate()
		loop.append(q[0])
		ci.draw_polyline(loop, col, 1.0, true)

	func poly(pts: PackedVector2Array, col: Color, edge: Color = Color(0, 0, 0, 0)) -> void:
		if pts.size() < 3:
			return
		var q := mp(pts)
		if OS.get_environment("PORTRAIT_DEBUG") == "1" and Geometry2D.triangulate_polygon(q).is_empty():
			print("BAD poly ", pts.size(), " ", pts[0], " ", pts[pts.size() / 2], " col ", col)
		ci.draw_colored_polygon(q, col)
		_edge(q, edge if edge.a > 0.0 else col)

	## A polygon shaded across the light: `lit` toward the lamp, `dark` away from it.
	func shade(pts: PackedVector2Array, base: Color, lit: Color, dark: Color, c: Vector2, r: float, edge: Color = Color(0, 0, 0, 0)) -> void:
		if pts.size() < 3:
			return
		var q := mp(pts)
		if OS.get_environment("PORTRAIT_DEBUG") == "1" and Geometry2D.triangulate_polygon(q).is_empty():
			print("BAD shade ", pts.size(), " ", pts[0], " ", pts[pts.size() / 2], " base ", base)
		var cols := PackedColorArray()
		cols.resize(pts.size())
		for i in pts.size():
			var d := clampf(((pts[i] - c) / r).dot(light), -1.0, 1.0)
			cols[i] = base.lerp(lit, d) if d > 0.0 else base.lerp(dark, -d)
		ci.draw_polygon(q, cols)
		_edge(q, edge if edge.a > 0.0 else base.lerp(dark, 0.7))

	## A soft radial blob: `inner` at the centre fading to `outer` at the rim.
	func fan(c: Vector2, radii: Vector2, inner: Color, outer: Color, rot: float = 0.0, seg: int = 28) -> void:
		var pts := PackedVector2Array([m(c)])
		var cols := PackedColorArray([inner])
		var idx := PackedInt32Array()
		var t := Transform2D(rot, Vector2.ZERO)
		for i in seg:
			var a := TAU * i / seg
			pts.append(m(c + t * Vector2(cos(a) * radii.x, sin(a) * radii.y)))
			cols.append(outer)
		for i in seg:
			idx.append(0)
			idx.append(1 + i)
			idx.append(1 + (i + 1) % seg)
		RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), idx, pts, cols)

	## `a` clipped to `b` (both in portrait units): always valid polygons.
	func clip(a: PackedVector2Array, b: PackedVector2Array) -> Array:
		return Geometry2D.intersect_polygons(a, b)

	func shade_all(polys: Array, base: Color, lit: Color, dark: Color, c: Vector2, r: float, edge: Color = Color(0, 0, 0, 0)) -> void:
		for q in polys:
			shade(q, base, lit, dark, c, r, edge)

	func poly_all(polys: Array, col: Color, edge: Color = Color(0, 0, 0, 0)) -> void:
		for q in polys:
			poly(q, col, edge)

	## A radial glow that stays inside `r` (a grid of vertex colours, no overdraw past the frame).
	func glow(r: Rect2, c: Vector2, radii: Vector2, col: Color, n: int = 10) -> void:
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		for j in n + 1:
			for i in n + 1:
				var q := r.position + Vector2(r.size.x * i / n, r.size.y * j / n)
				var d := ((q - c) / radii).length()
				var f := clampf(1.0 - d, 0.0, 1.0)
				pts.append(m(q))
				cols.append(Color(col, col.a * f * f * (3.0 - 2.0 * f)))
		var idx := PackedInt32Array()
		for j in n:
			for i in n:
				var a := j * (n + 1) + i
				idx.append_array([a, a + 1, a + n + 1, a + 1, a + n + 2, a + n + 1])
		RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), idx, pts, cols)

	func ellipse_pts(c: Vector2, radii: Vector2, rot: float = 0.0, seg: int = 24) -> PackedVector2Array:
		var pts := PackedVector2Array()
		var t := Transform2D(rot, c)
		for i in seg:
			var a := TAU * i / seg
			pts.append(t * Vector2(cos(a) * radii.x, sin(a) * radii.y))
		return pts

	func ellipse(c: Vector2, radii: Vector2, col: Color, rot: float = 0.0) -> void:
		poly(ellipse_pts(c, radii, rot), col)

	func circle(c: Vector2, r: float, col: Color) -> void:
		ci.draw_circle(m(c), r * k * fs, col, true, -1.0, true)

	func line(a: Vector2, b: Vector2, col: Color, w: float) -> void:
		ci.draw_line(m(a), m(b), col, lw(w), true)

	func pline(pts: PackedVector2Array, col: Color, w: float) -> void:
		ci.draw_polyline(mp(pts), col, lw(w), true)

	func arc(c: Vector2, r: float, a0: float, a1: float, col: Color, w: float, seg: int = 16) -> void:
		ci.draw_arc(m(c), r * k * fs, a0, a1, seg, col, lw(w), true)

	func rect(r: Rect2, col: Color) -> void:
		ci.draw_rect(Rect2(m(r.position), r.size * k * fs), col)

	func vgrad(r: Rect2, top: Color, bottom: Color) -> void:
		var a := m(r.position)
		var b := m(r.end)
		ci.draw_polygon(PackedVector2Array([a, Vector2(b.x, a.y), b, Vector2(a.x, b.y)]), PackedColorArray([top, top, bottom, bottom]))


static func draw(ci: CanvasItem, rect: Rect2, kind: String, look: int, family_color: Color = Color(0, 0, 0, 0),
		extra: Dictionary = {}, mood: String = "") -> void:
	var lk := PersonLook.decode(kind, look, family_color, extra)
	var p := Painter.new(ci, rect)
	_backdrop(p, rect, lk)
	var kid := kind in ["kid", "newsboy"]
	if kid:
		p.fs = 0.84
	var female: bool = lk["female"]
	var face := _face_geo(lk, kid, female)
	_hair_back(p, lk, face)
	_body(p, lk, face)
	_neck(p, lk, face)
	_collar(p, lk, face)
	_ears(p, lk, face)
	_face(p, lk, face, mood)
	_hair_front(p, lk, face)
	_hat(p, lk, face)
	_face_props(p, lk, face, mood)
	p.fs = 1.0
	_vignette(p)


static func control(kind: String, look: int, family_color: Color = Color(0, 0, 0, 0), extra: Dictionary = {},
		mood: String = "") -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(96, 96)
	c.draw.connect(func() -> void: draw(c, Rect2(Vector2.ZERO, c.size), kind, look, family_color, extra, mood))
	c.resized.connect(c.queue_redraw)
	return c


# ------------------------------------------------------------------ geometry of the face

static func _face_geo(lk: Dictionary, kid: bool, female: bool) -> Dictionary:
	var fw: float = lk["face_w"]
	var bw: float = lk["w"]
	var rx := 14.6 + 1.1 * fw + clampf((bw - 1.0) * 10.0, -1.0, 2.2)
	var jaw := 0.74 + 0.07 * fw + clampf((bw - 1.0) * 0.5, -0.04, 0.1)
	var up := 18.0
	var low := 19.6
	var cy := 43.0
	if female:
		rx -= 1.4
		jaw = 0.66
		low = 18.6
	if kid:
		rx += 0.6
		jaw = 0.8
		low = 17.2
		up = 18.4
	if lk["kind"] in ["aiboss", "unionboss"]:
		jaw += 0.08
	return {"c": Vector2(50.0, cy), "rx": rx, "up": up, "low": low, "jaw": jaw, "eye_y": cy + 1.2,
		"brow_y": cy - 4.4, "nose_y": cy + 8.4, "mouth_y": cy + 13.8, "chin": cy + low, "kid": kid, "female": female}


static func _face_pts(f: Dictionary) -> PackedVector2Array:
	var c: Vector2 = f["c"]
	var rx: float = f["rx"]
	var jaw: float = f["jaw"]
	var pts := PackedVector2Array()
	for i in 40:
		var a := TAU * i / 40.0
		var s := sin(a)
		var cx := cos(a)
		var ry: float = f["low"] if s > 0.0 else f["up"]
		var wx := rx
		if s > 0.0:
			# cheeks to jaw to chin
			var t := pow(s, 1.6)
			wx = rx * lerpf(1.0, jaw, t)
			if s > 0.92:
				wx *= lerpf(1.0, 0.8, (s - 0.92) / 0.08)
		pts.append(c + Vector2(cx * wx, s * ry))
	return pts


# ------------------------------------------------------------------ backdrop

static func _backdrop(p: Painter, rect: Rect2, lk: Dictionary) -> void:
	var kind: String = lk["kind"]
	var wall := Color("40251c")
	var glow := Color("c8904e")
	var pattern := "damask"
	if kind in ["ped", "woman", "kid", "newsboy", "recruit", "docker", "smuggler", "unionboss"]:
		wall = Color("46302a"); glow = Color("d09a58"); pattern = "brick"
	elif kind == "shop":
		wall = Color("5a4630"); glow = Color("e0b068"); pattern = "shelves"
	elif kind in ["cop", "fed"]:
		wall = Color("343a30"); glow = Color("c49a5a"); pattern = "panels"
	elif kind in ["bartender", "patron", "dealer"]:
		wall = Color("3a2226"); glow = Color("d09050"); pattern = "bar"
	p.ci.draw_rect(rect, wall.darkened(0.45))
	var full := Rect2(0, 0, 100, 100)
	p.vgrad(full, wall.darkened(0.2), wall.darkened(0.55))
	# the pattern on the wall, faint
	var line := wall.darkened(0.35)
	line.a = 0.5
	match pattern:
		"damask":
			for i in 8:
				var x := 6.0 + i * 12.5
				p.line(Vector2(x, 0), Vector2(x, 100), Color(wall.lightened(0.12), 0.25), 0.8)
				for j in 5:
					var y := 8.0 + j * 20.0 + (10.0 if i % 2 == 1 else 0.0)
					p.poly(PackedVector2Array([Vector2(x + 6.2, y - 3.0), Vector2(x + 8.4, y), Vector2(x + 6.2, y + 3.0), Vector2(x + 4.0, y)]), Color(wall.lightened(0.14), 0.25))
		"brick":
			for j in 16:
				var y := j * 6.5
				p.line(Vector2(0, y), Vector2(100, y), line, 0.6)
				for i in 8:
					var x := i * 14.0 + (7.0 if j % 2 == 1 else 0.0)
					p.line(Vector2(x, y), Vector2(x, y + 6.5), line, 0.6)
		"shelves":
			for j in 3:
				var y := 22.0 + j * 26.0
				p.rect(Rect2(0, y, 100, 2.2), Color(wall.darkened(0.4), 0.8))
				for i in 9:
					var x := 3.0 + i * 11.0 + Draw.hash01(i, j, 5) * 3.0
					var h := 7.0 + Draw.hash01(i, j, 6) * 8.0
					var col := Color(wall.lerp(Pal.GLASS if (i + j) % 3 == 0 else Pal.AWNING_COLORS[(i * 3 + j) % 6], 0.35), 0.55)
					p.rect(Rect2(x, y - h, 6.0, h), col)
		"panels":
			p.rect(Rect2(0, 62, 100, 38), Color(wall.darkened(0.25), 0.8))
			for i in 4:
				p.rect(Rect2(4.0 + i * 25.0, 66, 20, 30), Color(wall.darkened(0.4), 0.5))
			p.rect(Rect2(64, 12, 18, 23), Color(Pal.PAPER.darkened(0.35), 0.4))
		"bar":
			for i in 7:
				var x := 6.0 + i * 14.0
				var h := 12.0 + Draw.hash01(i, 2, 9) * 6.0
				p.rect(Rect2(x, 44.0 - h, 4.0, h), Color(Color("5a3a1e").lerp(Color("2e4a3a"), Draw.hash01(i, 1, 9)), 0.55))
				p.rect(Rect2(x + 1.2, 44.0 - h - 3.0, 1.6, 3.0), Color(Color("5a3a1e"), 0.55))
			p.rect(Rect2(0, 44, 100, 2.0), Color(wall.darkened(0.5), 0.8))
	# the lamp: a warm pool of light from the upper left, a halo behind the head
	p.glow(full, Vector2(16.0, 10.0), Vector2(96.0, 88.0), Color(glow, 0.6))
	p.glow(full, Vector2(10.0, 4.0), Vector2(26.0, 22.0), Color(WARM, 0.3), 6)
	p.glow(full, Vector2(52.0, 40.0), Vector2(46.0, 46.0), Color(glow.lightened(0.2), 0.18), 8)


static func _vignette(p: Painter) -> void:
	var d := Color(0.04, 0.03, 0.03, 0.55)
	var z := Color(0.04, 0.03, 0.03, 0.0)
	p.vgrad(Rect2(0, 0, 100, 10), Color(d, 0.3), z)
	p.vgrad(Rect2(0, 86, 100, 14), z, Color(d, 0.5))
	var a := p.m(Vector2(0, 0))
	var b := p.m(Vector2(100, 100))
	var w := 9.0 * p.k
	p.ci.draw_polygon(PackedVector2Array([a, Vector2(a.x + w, a.y), Vector2(a.x + w, b.y), Vector2(a.x, b.y)]), PackedColorArray([d, z, z, d]))
	p.ci.draw_polygon(PackedVector2Array([Vector2(b.x - w, a.y), Vector2(b.x, a.y), b, Vector2(b.x - w, b.y)]), PackedColorArray([z, d, d, z]))
	p.ci.draw_rect(Rect2(a, b - a), Color(0.02, 0.015, 0.01, 0.9), false, 1.0)


# ------------------------------------------------------------------ the body and the clothes

static func _shoulders(bw: float, female: bool, kid: bool) -> PackedVector2Array:
	var w := clampf(bw, 0.86, 1.2)
	var half := minf(45.5 * w, 49.5)
	var neck := 7.6 if not female else 6.0
	if female:
		half = 38.0
	if kid:
		half = minf(40.0 * w, 44.0)
	var sh_y := 76.0 if not female else 78.0
	var left := PackedVector2Array([Vector2(50.0 - half - 0.5, 101.0), Vector2(50.0 - half, 92.0), Vector2(50.0 - half * 0.93, 84.0),
		Vector2(50.0 - half * 0.8, sh_y + 1.0), Vector2(50.0 - half * 0.6, sh_y - 2.6), Vector2(50.0 - half * 0.36, sh_y - 5.8),
		Vector2(50.0 - neck - 3.0, 67.0), Vector2(50.0 - neck, 64.0)])
	var pts := PackedVector2Array(left)
	for i in range(left.size() - 1, -1, -1):
		pts.append(Vector2(100.0 - left[i].x, left[i].y))
	return pts


static func _body(p: Painter, lk: Dictionary, f: Dictionary) -> void:
	var coat: String = lk["coat"]
	var female: bool = f["female"]
	var sh := _shoulders(float(lk["w"]), female, f["kid"])
	var base: Color = lk["coat_col"]
	var shirt: Color = lk["shirt"]
	var skin: Color = lk["skin"]
	if coat in ["shirt", "vest"]:
		base = shirt
	var c := Vector2(50.0, 84.0)
	if coat == "flapper":
		p.shade(sh, skin, skin.lightened(0.18), skin.darkened(0.3), c, 40.0)
		_flapper(p, lk, base)
		return
	p.shade(sh, base, _lit(base, 0.24), _dk(base, 0.5), c, 40.0)
	# folds in the cloth where the arm meets the chest
	for sgn: float in [-1.0, 1.0]:
		p.line(Vector2(50.0 + sgn * 31.0, 86.0), Vector2(50.0 + sgn * 33.0, 100.0), Color(_dk(base, 0.4), 0.55), 1.2)
	if String(lk["pattern"]) == "check":
		var col2: Color = lk["coat_col2"]
		for i in 9:
			var x := 10.0 + i * 10.0
			p.line(Vector2(x, 72.0 + absf(x - 50.0) * 0.12), Vector2(x, 100.0), Color(col2, 0.55), 0.9)
		for j in 4:
			var y := 78.0 + j * 7.0
			p.line(Vector2(8.0, y), Vector2(92.0, y), Color(col2, 0.5), 0.9)
	match coat:
		"suit", "three", "tux":
			_jacket_front(p, lk, base, coat == "three", coat == "tux")
		"overcoat":
			_jacket_front(p, lk, base, false, false, 1.25)
			var fur: Color = lk["fur"]
			if fur.a > 0.0:
				_fur(p, fur, 64.0, 16.0)
		"tunic":
			_tunic(p, lk, base)
		"trench":
			_jacket_front(p, lk, base, false, false, 1.35)
			for sgn: float in [-1.0, 1.0]:
				p.line(Vector2(50.0 + sgn * 18.0, 72.5), Vector2(50.0 + sgn * 34.0, 77.0), _dk(base, 0.35), 2.2)
				p.circle(Vector2(50.0 + sgn * 20.0, 73.2), 1.0, Color("3a2a1c"))
				p.circle(Vector2(50.0 + sgn * 10.5, 90.0), 1.3, Color("3a2a1c"))
				p.circle(Vector2(50.0 + sgn * 10.5, 98.0), 1.3, Color("3a2a1c"))
		"peacoat":
			_jacket_front(p, lk, base, false, false, 1.5)
			for sgn: float in [-1.0, 1.0]:
				for j in 2:
					var bp := Vector2(50.0 + sgn * 9.0, 88.0 + j * 8.0)
					p.circle(bp, 1.8, Color("14161a"))
					p.circle(bp + Vector2(-0.4, -0.4), 1.0, Color("4a4e58"))
		"jacket", "sweater", "cardigan":
			if coat == "jacket":
				for i in 40:
					var q := Vector2(8.0 + Draw.hash01(i, 1, int(lk["w"] * 10)) * 84.0, 72.0 + Draw.hash01(i, 2, 3) * 28.0)
					p.circle(q, 0.5, Color(base.lightened(0.18) if i % 2 == 0 else base.darkened(0.2), 0.7))
			if coat == "sweater" or coat == "cardigan":
				for i in 12:
					var x := 8.0 + i * 7.6
					p.line(Vector2(x, 76.0 + absf(x - 50.0) * 0.05), Vector2(x, 100.0), Color(_dk(base, 0.25), 0.5), 0.7)
			_jacket_front(p, lk, base, false, false, 0.8 if coat == "jacket" else 0.55)
			if coat == "cardigan":
				for j in 3:
					p.circle(Vector2(50.0, 86.0 + j * 5.5), 1.0, _dk(base, 0.5))
		"whitejacket":
			p.poly(PackedVector2Array([Vector2(43.0, 64.5), Vector2(57.0, 64.5), Vector2(57.5, 70.5), Vector2(42.5, 70.5)]), _dk(base, 0.08), _dk(base, 0.3))
			p.line(Vector2(57.0, 70.5), Vector2(62.0, 100.0), _dk(base, 0.25), 0.9)
			for j in 4:
				p.circle(Vector2(58.6 + j * 0.9, 76.0 + j * 6.5), 0.9, _dk(base, 0.35))
			if "comb" in lk["props"]:
				p.rect(Rect2(66.0, 80.0, 1.3, 6.5), Color("2a2622"))
				p.rect(Rect2(62.0, 85.0, 10.0, 1.2), _dk(base, 0.3))
		"dress", "coat_w":
			_dress_front(p, lk, base, coat == "coat_w")
		"shirt", "vest":
			_shirt_front(p, lk)
	var apron: String = lk["apron"]
	if apron != "":
		_apron(p, apron, lk)
	var band: Color = lk["armband"]
	if band.a > 0.0:
		var half := minf(45.5 * clampf(float(lk["w"]), 0.86, 1.2), 49.5)
		var bpts := PackedVector2Array([Vector2(50.0 - half + 0.2, 88.0), Vector2(50.0 - half * 0.82, 86.5), Vector2(50.0 - half * 0.8, 93.0), Vector2(50.0 - half + 0.4, 94.5)])
		p.shade(bpts, band, band.lightened(0.2), band.darkened(0.35), Vector2(50.0 - half * 0.9, 90.0), 5.0)
	if "tape" in lk["props"]:
		for sgn: float in [-1.0, 1.0]:
			var pts := PackedVector2Array([Vector2(50.0 + sgn * 8.5, 64.0), Vector2(50.0 + sgn * 11.0, 64.5), Vector2(50.0 + sgn * 13.5, 100.0), Vector2(50.0 + sgn * 9.5, 100.0)])
			p.shade(pts, Color("e0c04a"), Color("f4dc7a"), Color("8a7424"), Vector2(50.0, 80.0), 20.0)
			for j in 7:
				var y := 70.0 + j * 4.5
				var x := 50.0 + sgn * lerpf(9.5, 12.5, (y - 64.0) / 36.0)
				p.line(Vector2(x - 1.2, y), Vector2(x + 1.2, y), Color(0.2, 0.16, 0.06, 0.6), 0.5)
	if "papers" in lk["props"]:
		p.line(Vector2(34.0, 70.0), Vector2(70.0, 100.0), Color("3a2c1e"), 4.2)
		p.line(Vector2(34.0, 70.0), Vector2(70.0, 100.0), Color("6a5236"), 3.0)
	var scarf: Color = lk["scarf"]
	if scarf.a > 0.0:
		for sgn: float in [-1.0, 1.0]:
			var pts := PackedVector2Array([Vector2(50.0 + sgn * 6.0, 63.5), Vector2(50.0 + sgn * 12.5, 64.5), Vector2(50.0 + sgn * 15.5, 76.0),
				Vector2(50.0 + sgn * 13.5, 100.0), Vector2(50.0 + sgn * 6.5, 100.0), Vector2(50.0 + sgn * 7.5, 78.0)])
			p.shade(pts, scarf, Color(1, 1, 1), scarf.darkened(0.3), Vector2(50.0 + sgn * 10.0, 80.0), 16.0)
			p.line(Vector2(50.0 + sgn * 10.5, 70.0), Vector2(50.0 + sgn * 10.0, 98.0), Color(scarf.darkened(0.2), 0.6), 0.6)
	var flower: Color = lk["flower"]
	if flower.a > 0.0 and scarf.a == 0.0:
		var fp := Vector2(66.5, 81.0)
		for i in 6:
			var a := TAU * i / 6.0
			p.circle(fp + Vector2(cos(a), sin(a)) * 1.7, 1.7, flower.darkened(0.15) if i % 2 == 0 else flower)
		p.circle(fp, 1.3, flower.lightened(0.2))
		p.line(fp + Vector2(0.5, 2.0), fp + Vector2(1.5, 5.5), Color("3a5a2a"), 0.8)


## Lapels, a shirt and tie in the V, buttons: the front of a suit coat.
static func _jacket_front(p: Painter, lk: Dictionary, base: Color, vest: bool, tux: bool, wide: float = 1.0) -> void:
	var shirt: Color = lk["shirt"]
	var tie: String = lk["tie"]
	var tie_col: Color = lk["tie_col"]
	var vb := 88.0 if not tux else 92.0
	# the V: shirt (and waistcoat)
	var v := PackedVector2Array([Vector2(41.5, 64.5), Vector2(58.5, 64.5), Vector2(50.0, vb)])
	if vest:
		var vv := PackedVector2Array([Vector2(39.0, 66.0), Vector2(61.0, 66.0), Vector2(56.0, 100.0), Vector2(44.0, 100.0)])
		var vc := _dk(base, 0.2)
		p.shade(vv, vc, _lit(vc, 0.15), _dk(vc, 0.45), Vector2(50, 80), 20.0)
		v = PackedVector2Array([Vector2(43.0, 64.5), Vector2(57.0, 64.5), Vector2(50.0, 82.0)])
		for j in 3:
			p.circle(Vector2(50.0, 85.5 + j * 5.0), 0.9, _dk(vc, 0.6))
	p.shade(v, shirt, shirt.lightened(0.1), shirt.darkened(0.25), Vector2(50, 70), 12.0)
	if tie == "tie":
		var tp := PackedVector2Array([Vector2(47.8, 67.5), Vector2(52.2, 67.5), Vector2(53.4, vb - 2.0), Vector2(50.0, vb + 1.5), Vector2(46.6, vb - 2.0)])
		p.shade(tp, tie_col, tie_col.lightened(0.2), tie_col.darkened(0.4), Vector2(50, 76), 10.0)
		p.poly(PackedVector2Array([Vector2(47.3, 64.8), Vector2(52.7, 64.8), Vector2(51.8, 68.4), Vector2(48.2, 68.4)]), tie_col.darkened(0.1))
		if not p.small:
			p.line(Vector2(49.2, 70.0), Vector2(49.4, vb - 3.0), Color(tie_col.lightened(0.3), 0.5), 0.6)
	elif tie == "bow":
		_bow(p, Vector2(50.0, 66.4), tie_col, 1.0)
	# the lapels
	var lap := _lit(base, 0.1) if not tux else Color("2c2c32")
	for sgn: float in [-1.0, 1.0]:
		var x := func(dx: float) -> float: return 50.0 + sgn * dx
		var w1 := maxf(13.5 * wide, 10.5)
		var w2 := maxf(16.5 * wide, 12.5)
		var w3 := minf(maxf(12.0 * wide + 2.0, 9.5), w2 - 1.5)
		var pts := PackedVector2Array([Vector2(x.call(8.2), 64.0), Vector2(x.call(w1), 66.5), Vector2(x.call(w2), 77.0),
			Vector2(x.call(w3), 79.0), Vector2(x.call(1.5), vb)])
		if sgn > 0.0:
			pts.reverse()
		var lit_side := lap.lightened(0.16) if sgn < 0.0 else lap
		p.shade(pts, lap, lit_side, _dk(lap, 0.35), Vector2(x.call(10.0), 74.0), 12.0, _dk(base, 0.55))
		# the notch
		p.line(Vector2(x.call(w2), 77.0), Vector2(x.call(w3), 79.0), _dk(base, 0.6), 0.8)
	# the buttons of the coat, a pocket square
	if not vest:
		p.circle(Vector2(50.0, vb + 4.0), 1.2, _dk(base, 0.55))
	if tux:
		p.shade(PackedVector2Array([Vector2(44.0, 80.0), Vector2(56.0, 80.0), Vector2(55.0, 92.0), Vector2(45.0, 92.0)]), shirt, shirt.lightened(0.1), shirt.darkened(0.2), Vector2(50, 86), 8.0)
		for j in 2:
			p.circle(Vector2(50.0, 83.0 + j * 4.5), 0.7, Color("1a1a1c"))
	elif lk["kind"] != "dealer" and Draw.hash01(int(lk["w"] * 100), 7, 1) < 0.5 and lk["flower"] == NONE:
		p.poly(PackedVector2Array([Vector2(63.0, 84.5), Vector2(66.0, 82.0), Vector2(69.0, 84.8), Vector2(68.8, 86.0), Vector2(63.0, 86.0)]), Pal.PAPER)


static func _bow(p: Painter, c: Vector2, col: Color, s: float) -> void:
	p.shade(PackedVector2Array([c, c + Vector2(-6.0, -3.2) * s, c + Vector2(-6.5, 3.2) * s]), col, col.lightened(0.25), col.darkened(0.3), c, 6.0)
	p.shade(PackedVector2Array([c, c + Vector2(6.5, -3.2) * s, c + Vector2(6.0, 3.2) * s]), col, col.lightened(0.25), col.darkened(0.3), c, 6.0)
	p.ellipse(c, Vector2(1.6, 1.8) * s, col.lightened(0.1))


static func _tunic(p: Painter, lk: Dictionary, base: Color) -> void:
	# the standing collar is drawn with the neck; here: buttons, the shield, a belt
	p.line(Vector2(50.0, 70.0), Vector2(50.0, 100.0), _dk(base, 0.5), 0.9)
	for j in 4:
		var bp := Vector2(52.6, 74.0 + j * 7.4)
		p.circle(bp, 1.6, Pal.BRASS.darkened(0.4))
		p.circle(bp + Vector2(-0.35, -0.35), 1.1, Pal.BRASS.lightened(0.2))
	# pocket flaps
	for sgn: float in [-1.0, 1.0]:
		p.poly(PackedVector2Array([Vector2(50.0 + sgn * 12.0, 80.0), Vector2(50.0 + sgn * 25.0, 80.0), Vector2(50.0 + sgn * 24.5, 84.0), Vector2(50.0 + sgn * 12.5, 84.0)]), _dk(base, 0.2), _dk(base, 0.5))
		p.circle(Vector2(50.0 + sgn * 18.5, 82.5), 0.9, Pal.BRASS.darkened(0.2))
		# shoulder straps
		p.line(Vector2(50.0 + sgn * 18.0, 70.5), Vector2(50.0 + sgn * 36.0, 76.0), _dk(base, 0.3), 2.2)
		p.circle(Vector2(50.0 + sgn * 19.5, 71.2), 1.0, Pal.BRASS)
	# the shield on the left breast
	var bp := Vector2(68.0, 76.5)
	var shield := PackedVector2Array([bp + Vector2(-3.4, -3.6), bp + Vector2(3.4, -3.6), bp + Vector2(3.6, 0.4), bp + Vector2(0.0, 4.4), bp + Vector2(-3.6, 0.4)])
	p.shade(shield, Pal.BRASS, Pal.BRASS.lightened(0.4), Pal.BRASS.darkened(0.45), bp, 4.0, Pal.BRASS.darkened(0.5))
	p.circle(bp + Vector2(0.0, -0.4), 1.4, Pal.BRASS.darkened(0.25))
	p.circle(bp + Vector2(-1.4, -2.0), 0.7, Color(1, 0.97, 0.85, 0.9))


static func _shirt_front(p: Painter, lk: Dictionary) -> void:
	var shirt: Color = lk["shirt"]
	var vest: Color = lk["vest"]
	var braces: Color = lk["braces"]
	var tie: String = lk["tie"]
	var tie_col: Color = lk["tie_col"]
	# placket and creases
	p.line(Vector2(50.0, 70.0), Vector2(50.0, 100.0), Color(shirt.darkened(0.25), 0.8), 0.8)
	for j in 3:
		p.circle(Vector2(50.8, 76.0 + j * 8.0), 0.7, shirt.darkened(0.3))
	for sgn: float in [-1.0, 1.0]:
		p.line(Vector2(50.0 + sgn * 20.0, 80.0), Vector2(50.0 + sgn * 26.0, 96.0), Color(shirt.darkened(0.2), 0.5), 0.8)
	if vest.a > 0.0:
		var vv := PackedVector2Array([Vector2(36.0, 70.0), Vector2(44.0, 67.0), Vector2(50.0, 84.0), Vector2(56.0, 67.0), Vector2(64.0, 70.0),
			Vector2(66.0, 100.0), Vector2(34.0, 100.0)])
		p.shade(vv, vest, _lit(vest, 0.18), _dk(vest, 0.45), Vector2(50, 86), 18.0)
		for j in 3:
			p.circle(Vector2(50.0, 88.0 + j * 4.5), 0.9, _dk(vest, 0.6))
		for sgn: float in [-1.0, 1.0]:
			p.line(Vector2(50.0 + sgn * 9.0, 90.0), Vector2(50.0 + sgn * 14.0, 90.0), _dk(vest, 0.5), 0.8)
	elif braces.a > 0.0:
		for sgn: float in [-1.0, 1.0]:
			p.line(Vector2(50.0 + sgn * 17.0, 70.0), Vector2(50.0 + sgn * 13.0, 100.0), braces.darkened(0.3), 3.4)
			p.line(Vector2(50.0 + sgn * 16.8, 70.0), Vector2(50.0 + sgn * 12.8, 100.0), braces, 2.4)
			p.rect(Rect2(50.0 + sgn * 13.6 - 1.8, 90.0, 3.6, 2.4), Color("8a7a58"))
	match tie:
		"tie":
			var tp := PackedVector2Array([Vector2(47.8, 68.0), Vector2(52.2, 68.0), Vector2(53.6, 94.0), Vector2(50.0, 97.5), Vector2(46.4, 94.0)])
			p.shade(tp, tie_col, tie_col.lightened(0.2), tie_col.darkened(0.4), Vector2(50, 80), 12.0)
			p.poly(PackedVector2Array([Vector2(47.2, 65.0), Vector2(52.8, 65.0), Vector2(51.8, 68.8), Vector2(48.2, 68.8)]), tie_col.darkened(0.1))
		"bow":
			_bow(p, Vector2(50.0, 66.6), tie_col, 1.0)
		"neckerchief":
			var np := PackedVector2Array([Vector2(40.0, 64.0), Vector2(60.0, 64.0), Vector2(56.0, 70.0), Vector2(50.0, 78.0), Vector2(44.0, 70.0)])
			p.shade(np, tie_col, tie_col.lightened(0.2), tie_col.darkened(0.4), Vector2(50, 68), 10.0)
			p.circle(Vector2(50.0, 69.0), 1.8, tie_col.darkened(0.2))


static func _dress_front(p: Painter, lk: Dictionary, base: Color, coat: bool) -> void:
	var skin: Color = lk["skin"]
	# the neckline: skin in a soft V or scoop
	var neck := PackedVector2Array([Vector2(41.5, 65.0), Vector2(58.5, 65.0), Vector2(56.0, 74.0), Vector2(50.0, 80.0 if not coat else 76.0), Vector2(44.0, 74.0)])
	p.shade(neck, skin, skin.lightened(0.1), skin.darkened(0.25), Vector2(50, 70), 10.0)
	if coat:
		for sgn: float in [-1.0, 1.0]:
			var pts := PackedVector2Array([Vector2(50.0 + sgn * 8.0, 64.0), Vector2(50.0 + sgn * 17.0, 67.0), Vector2(50.0 + sgn * 18.0, 80.0), Vector2(50.0 + sgn * 2.0, 90.0)])
			if sgn > 0.0:
				pts.reverse()
			p.shade(pts, _lit(base, 0.1), _lit(base, 0.24), _dk(base, 0.3), Vector2(50.0 + sgn * 12.0, 74.0), 10.0, _dk(base, 0.5))
		p.circle(Vector2(52.5, 92.0), 1.6, _dk(base, 0.5))
		var fur: Color = lk["fur"]
		if fur.a > 0.0:
			_fur(p, fur, 66.0, 15.0)
	else:
		p.line(Vector2(41.5, 65.0), Vector2(50.0, 80.0), _dk(base, 0.4), 1.0)
		p.line(Vector2(58.5, 65.0), Vector2(50.0, 80.0), _dk(base, 0.4), 1.0)
		for j in 4:
			p.line(Vector2(30.0 + j * 12.0, 84.0), Vector2(28.0 + j * 13.0, 100.0), Color(_dk(base, 0.3), 0.5), 0.8)
	if lk["pearls"]:
		_pearl_string(p, 67.0, 12.0, 11.5)


static func _flapper(p: Painter, lk: Dictionary, base: Color) -> void:
	var top := PackedVector2Array([Vector2(26.0, 84.0), Vector2(38.0, 78.0), Vector2(50.0, 82.0), Vector2(62.0, 78.0), Vector2(74.0, 84.0), Vector2(76.0, 101.0), Vector2(24.0, 101.0)])
	p.shade(top, base, _lit(base, 0.25), _dk(base, 0.5), Vector2(50, 90), 20.0)
	for sgn: float in [-1.0, 1.0]:
		p.line(Vector2(50.0 + sgn * 12.0, 79.0), Vector2(50.0 + sgn * 17.0, 67.0), _dk(base, 0.2), 1.0)
	for i in 36:
		var q := Vector2(26.0 + Draw.hash01(i, 3, 1) * 48.0, 84.0 + Draw.hash01(i, 4, 1) * 16.0)
		p.circle(q, 0.55, Color(base.lightened(0.5), 0.8))
	for j in 8:
		var x := 27.0 + j * 6.6
		p.line(Vector2(x, 96.0), Vector2(x + 0.5, 101.0), Color(_dk(base, 0.3), 0.8), 0.7)
	if lk["pearls"]:
		_pearl_string(p, 66.0, 11.0, 18.0)


static func _pearl_string(p: Painter, y0: float, rx: float, drop: float) -> void:
	var n := 15
	for i in n:
		var t := float(i) / (n - 1)
		var a := lerpf(PI * 0.1, PI * 0.9, t)
		var q := Vector2(50.0 + cos(a) * rx, y0 + sin(a) * drop)
		p.circle(q, 1.1, Color("c8c0b0"))
		p.circle(q + Vector2(-0.3, -0.3), 0.6, Color("fbf8f0"))


static func _fur(p: Painter, fur: Color, y: float, half: float) -> void:
	# a thick fluffy stole round the neck and over the shoulders, tufted at the edges
	var outer := PackedVector2Array()
	var n := 26
	for i in n + 1:
		var t := float(i) / n
		var x := 50.0 + lerpf(-half - 16.0, half + 16.0, t)
		var dx := (x - 50.0) / (half + 16.0)
		var yy := y + 6.0 + dx * dx * 12.0 + (1.3 if i % 2 == 0 else -0.4)
		outer.append(Vector2(x, yy))
	for i in n + 1:
		var t := 1.0 - float(i) / n
		var x := 50.0 + lerpf(-half - 9.0, half + 9.0, t)
		var dx := (x - 50.0) / (half + 9.0)
		var yy := y - 3.0 + dx * dx * 9.0 - (1.0 if i % 2 == 0 else 0.0)
		outer.append(Vector2(x, yy))
	p.shade(outer, fur, _lit(fur, 0.3), _dk(fur, 0.55), Vector2(50.0, y + 2.0), 18.0, _dk(fur, 0.6))
	if not p.small:
		for i in 22:
			var t := float(i) / 21.0
			var x := 50.0 + lerpf(-half - 12.0, half + 12.0, t)
			var dx := (x - 50.0) / (half + 12.0)
			var yy := y + 1.5 + dx * dx * 10.0
			p.line(Vector2(x, yy - 2.0), Vector2(x + 0.8, yy + 2.6), Color(_lit(fur, 0.35), 0.55), 0.6)


static func _apron(p: Painter, apron: String, lk: Dictionary) -> void:
	var col := PersonLook.WHITE
	match apron:
		"leather": col = PersonLook.LEATHER
		"canvas": col = PersonLook.CANVAS
		"rubber": col = PersonLook.RUBBER
	for sgn: float in [-1.0, 1.0]:
		p.line(Vector2(50.0 + sgn * 13.0, 82.0), Vector2(50.0 + sgn * 8.0, 64.0), col.darkened(0.2), 1.6)
	var bib := PackedVector2Array([Vector2(37.0, 82.0), Vector2(63.0, 82.0), Vector2(64.5, 101.0), Vector2(35.5, 101.0)])
	p.shade(bib, col, col.lightened(0.12), col.darkened(0.3), Vector2(50, 90), 14.0)
	match apron:
		"striped":
			for i in 6:
				var x := 39.5 + i * 4.3
				p.line(Vector2(x, 82.5), Vector2(x - 0.2, 100.5), Color("3a4a6e"), 1.2)
		"leather":
			p.pline(PackedVector2Array([Vector2(38.5, 83.5), Vector2(61.5, 83.5), Vector2(62.8, 100.0)]), Color(col.lightened(0.25), 0.7), 0.5)
		"rubber":
			p.line(Vector2(41.0, 84.0), Vector2(40.0, 100.0), Color(1, 1, 1, 0.18), 1.8)
	p.line(Vector2(37.0, 82.0), Vector2(63.0, 82.0), col.darkened(0.25), 0.8)


# ------------------------------------------------------------------ neck, collar, ears, face

static func _neck(p: Painter, lk: Dictionary, f: Dictionary) -> void:
	var skin: Color = lk["skin"]
	var w := 8.2 if not f["female"] else 5.8
	if float(lk["w"]) > 1.1:
		w += 1.5
	var pts := PackedVector2Array([Vector2(50.0 - w, 52.0), Vector2(50.0 + w, 52.0), Vector2(50.0 + w + 0.6, 70.0), Vector2(50.0 - w - 0.6, 70.0)])
	p.shade(pts, skin.darkened(0.12), skin, skin.darkened(0.4), Vector2(50, 60), 10.0)
	# the shadow under the jaw
	p.fan(Vector2(50.0, float(f["chin"]) + 1.0), Vector2(w + 2.0, 4.5), Color(0.1, 0.05, 0.04, 0.4), Color(0.1, 0.05, 0.04, 0.0))


static func _collar(p: Painter, lk: Dictionary, f: Dictionary) -> void:
	var coat: String = lk["coat"]
	var shirt: Color = lk["shirt"]
	var base: Color = lk["coat_col"]
	if coat == "tunic":
		var col := PackedVector2Array([Vector2(40.5, 61.0), Vector2(59.5, 61.0), Vector2(60.5, 69.0), Vector2(50.0, 70.5), Vector2(39.5, 69.0)])
		p.shade(col, base, _lit(base, 0.2), _dk(base, 0.45), Vector2(50, 64), 10.0, _dk(base, 0.6))
		for sgn: float in [-1.0, 1.0]:
			p.rect(Rect2(50.0 + sgn * 6.5 - 1.5, 63.5, 3.0, 2.4), Pal.BRASS.darkened(0.1))
		return
	if coat in ["flapper", "dress", "coat_w"]:
		return
	if coat == "whitejacket":
		return
	if lk["tie"] == "neckerchief":
		return
	# shirt collar points
	for sgn: float in [-1.0, 1.0]:
		var pts := PackedVector2Array([Vector2(50.0 + sgn * 8.6, 60.5), Vector2(50.0 + sgn * 1.2, 65.8), Vector2(50.0 + sgn * 6.5, 70.0), Vector2(50.0 + sgn * 9.8, 66.0)])
		if sgn > 0.0:
			pts.reverse()
		p.shade(pts, shirt, shirt.lightened(0.12), shirt.darkened(0.3), Vector2(50.0 + sgn * 6.0, 65.0), 6.0, shirt.darkened(0.4))
	if coat == "peacoat" or coat == "trench":
		for sgn: float in [-1.0, 1.0]:
			var pts := PackedVector2Array([Vector2(50.0 + sgn * 9.0, 57.0), Vector2(50.0 + sgn * 17.0, 60.0), Vector2(50.0 + sgn * 17.5, 67.0), Vector2(50.0 + sgn * 10.0, 66.0)])
			if sgn > 0.0:
				pts.reverse()
			p.shade(pts, _lit(base, 0.08), _lit(base, 0.2), _dk(base, 0.4), Vector2(50.0 + sgn * 13.0, 62.0), 6.0, _dk(base, 0.55))


static func _ears(p: Painter, lk: Dictionary, f: Dictionary) -> void:
	var skin: Color = lk["skin"]
	var c: Vector2 = f["c"]
	var rx: float = f["rx"]
	for sgn: float in [-1.0, 1.0]:
		var ec := Vector2(c.x + sgn * (rx + 0.2), c.y + 3.4)
		var e := p.ellipse_pts(ec, Vector2(2.7, 4.8), sgn * 0.12, 18)
		p.shade(e, skin.darkened(0.1), skin.lightened(0.02), skin.darkened(0.4), ec, 5.0, skin.darkened(0.42))
		p.ellipse(ec + Vector2(sgn * 0.6, 0.3), Vector2(1.1, 2.8), Color(skin.darkened(0.3), 0.8), sgn * 0.12)
		if lk["earrings"]:
			p.circle(ec + Vector2(0.0, 5.8), 1.2, Color("f0ece0"))


static func _face(p: Painter, lk: Dictionary, f: Dictionary, mood: String) -> void:
	var skin: Color = lk["skin"]
	var c: Vector2 = f["c"]
	var rx: float = f["rx"]
	var age: int = lk["age"]
	var female: bool = f["female"]
	var pts := _face_pts(f)
	var lit := skin.lightened(0.16)
	var dark := skin.darkened(0.32)
	if age == 2:
		lit = lit.lerp(Color(0.9, 0.85, 0.8), 0.15)
	p.shade(pts, skin, lit, dark, c + Vector2(0, 4), 22.0, skin.darkened(0.42))
	# soft modelling: the lit cheek, the shaded side, cheekbones, the chin
	p.fan(c + Vector2(-6.0, -2.0), Vector2(9.0, 10.0), Color(skin.lightened(0.22), 0.35), Color(skin, 0.0))
	p.fan(c + Vector2(rx - 3.0, 6.0), Vector2(7.0, 14.0), Color(skin.darkened(0.45), 0.38), Color(skin, 0.0))
	p.fan(c + Vector2(rx * 0.55, 11.0), Vector2(4.5, 3.5), Color(skin.darkened(0.4), 0.25), Color(skin, 0.0))
	p.fan(c + Vector2(-rx * 0.35, -9.0), Vector2(7.0, 4.0), Color(skin.lightened(0.25), 0.3), Color(skin, 0.0))
	var blush := Color(0.85, 0.35, 0.3, 0.14 if not female else 0.24)
	if mood == "angry":
		blush.a += 0.1
	for sgn: float in [-1.0, 1.0]:
		p.fan(c + Vector2(sgn * 8.5, 9.0), Vector2(5.0, 3.6), blush, Color(blush, 0.0))
	p.fan(c + Vector2(0, float(f["low"]) - 3.5), Vector2(5.0, 2.6), Color(skin.lightened(0.15), 0.3), Color(skin, 0.0))
	# stubble on the jaw and the lip
	if lk["stubble"]:
		var st := Color(0.18, 0.15, 0.18, 0.24)
		p.fan(c + Vector2(0, 14.0), Vector2(rx * 0.85, 7.5), st, Color(st, 0.0))
		p.fan(c + Vector2(0, 11.2), Vector2(5.5, 1.8), st, Color(st, 0.0))
	_eyes(p, lk, f, mood)
	_brows(p, lk, f, mood)
	_nose(p, lk, f)
	_mouth(p, lk, f, mood)
	if age == 2 and not p.small:
		var wr := Color(skin.darkened(0.4), 0.5)
		for sgn: float in [-1.0, 1.0]:
			p.pline(PackedVector2Array([c + Vector2(sgn * 4.5, 8.8), c + Vector2(sgn * 6.4, 12.6), c + Vector2(sgn * 6.8, 15.5)]), wr, 0.7)
			p.line(c + Vector2(sgn * 10.8, 0.4), c + Vector2(sgn * 12.8, -0.8), wr, 0.6)
			p.line(c + Vector2(sgn * 10.8, 1.8), c + Vector2(sgn * 12.6, 2.4), wr, 0.6)
			p.arc(c + Vector2(sgn * 6.8, 3.5), 2.6, 0.3, PI - 0.3, wr, 0.5, 8)
	if lk["freckles"] and not p.small:
		for i in 12:
			var q := c + Vector2(lerpf(-10.0, 10.0, Draw.hash01(i, 5, 7)), 5.0 + Draw.hash01(i, 6, 7) * 5.0)
			if absf(q.x - c.x) < 2.0:
				continue
			p.circle(q, 0.45, Color(0.55, 0.3, 0.15, 0.5))
	if lk["scar"]:
		p.line(c + Vector2(-10.5, 1.5), c + Vector2(-7.0, 9.5), Color(skin.lightened(0.25), 0.9), 0.9)
		p.line(c + Vector2(-10.5, 1.5), c + Vector2(-7.0, 9.5), Color(skin.darkened(0.3), 0.4), 0.4)
		if not p.small:
			for j in 3:
				var q := (c + Vector2(-10.5, 1.5)).lerp(c + Vector2(-7.0, 9.5), 0.25 + j * 0.25)
				p.line(q + Vector2(-1.1, 0.4), q + Vector2(1.1, -0.4), Color(skin.darkened(0.3), 0.5), 0.4)


static func _mood_shape(mood: String) -> Dictionary:
	# brow ends (+ is down), eye opening, mouth
	match mood:
		"angry": return {"in": 2.6, "out": -1.3, "lift": 0.4, "open": 0.72, "mouth": "frown", "lid": 0.35}
		"scared": return {"in": -2.2, "out": 1.0, "lift": -1.6, "open": 1.3, "mouth": "o", "lid": 0.0}
		"happy": return {"in": -0.4, "out": 0.2, "lift": -1.0, "open": 0.62, "mouth": "smile", "lid": 0.0}
		"smug": return {"in": 0.6, "out": -0.2, "lift": 0.0, "open": 0.68, "mouth": "smirk", "lid": 0.45}
	return {"in": 0.35, "out": 0.0, "lift": 0.0, "open": 1.0, "mouth": "line", "lid": 0.15}


static func _eyes(p: Painter, lk: Dictionary, f: Dictionary, mood: String) -> void:
	var skin: Color = lk["skin"]
	var ms := _mood_shape(mood)
	var c: Vector2 = f["c"]
	var ey: float = f["eye_y"]
	var kid: bool = f["kid"]
	var female: bool = f["female"]
	var open: float = ms["open"]
	var eye_col: Color = lk["eye"]
	var ew := 3.3 if not kid else 3.6
	var eh := 1.9 * open if not kid else 2.3 * open
	var line := Color(0.12, 0.07, 0.06)
	for sgn: float in [-1.0, 1.0]:
		var ec := Vector2(c.x + sgn * 6.9, ey)
		# the socket shadow under the brow
		p.fan(ec + Vector2(0.0, -0.8), Vector2(5.8, 3.8), Color(skin.darkened(0.45), 0.4), Color(skin, 0.0))
		if p.small:
			p.ellipse(ec, Vector2(ew * 0.8, maxf(eh * 0.75, 0.9)), Color(0.14, 0.09, 0.07))
			p.circle(ec + Vector2(-0.6, -0.4), 0.55, Color(1, 1, 1, 0.8))
			continue
		var white := p.ellipse_pts(ec, Vector2(ew, eh), 0.0, 20)
		p.poly(white, Color("e9e1d2"), Color(0.4, 0.3, 0.26, 0.6))
		var ir := minf(1.55 if not kid else 1.75, eh * 0.95 + 0.2)
		p.circle(ec + Vector2(0.2, 0.15), ir, eye_col)
		p.circle(ec + Vector2(0.2, 0.15), ir * 0.5, Color(0.05, 0.03, 0.03))
		p.circle(ec + Vector2(-0.35, -0.45), ir * 0.32, Color(1, 1, 1, 0.9))
		# the upper lid: lowered for anger and smugness
		var lid: float = ms["lid"]
		if lid > 0.0:
			var cut := -eh + eh * 2.0 * lid
			var tilt := (0.16 * sgn if mood == "angry" else -0.05 * sgn)
			var t := Transform2D(tilt, ec)
			var above := PackedVector2Array([t * Vector2(-ew - 2.0, cut), t * Vector2(ew + 2.0, cut), t * Vector2(ew + 2.0, -eh - 3.0), t * Vector2(-ew - 2.0, -eh - 3.0)])
			p.poly_all(p.clip(p.ellipse_pts(ec, Vector2(ew + 0.3, eh + 0.3), 0.0, 20), above), skin.darkened(0.1))
			var half := sqrt(maxf(0.0, 1.0 - pow(cut / (eh + 0.3), 2.0))) * (ew + 0.3)
			p.line(t * Vector2(-half, cut), t * Vector2(half, cut), line, 0.9)
		else:
			p.arc(ec, ew, PI + 0.2, TAU - 0.2, line, 0.9 if not female else 1.1, 12)
		if female and not p.small:
			p.line(ec + Vector2(sgn * (ew - 0.3), -0.4), ec + Vector2(sgn * (ew + 0.7), -1.0), line, 0.6)
		if mood == "happy":
			p.arc(ec + Vector2(0.0, 2.6), ew + 0.2, PI + 0.5, TAU - 0.5, Color(skin.darkened(0.3), 0.7), 0.7, 10)
		else:
			p.arc(ec + Vector2(0.0, 0.6), ew * 0.9, 0.35, PI - 0.35, Color(skin.darkened(0.35), 0.45), 0.5, 10)


static func _brows(p: Painter, lk: Dictionary, f: Dictionary, mood: String) -> void:
	var ms := _mood_shape(mood)
	var c: Vector2 = f["c"]
	var hair: Color = lk["hair"]
	var col := hair.darkened(0.25)
	if lk["hair_style"] == "red":
		col = hair.darkened(0.1)
	var by: float = f["brow_y"] + float(lk["brow_h"]) * 0.5 + float(ms["lift"])
	var thick := 1.6 if not f["female"] else 0.95
	if lk["age"] == 2:
		thick += 0.3
	for sgn: float in [-1.0, 1.0]:
		var inner := Vector2(c.x + sgn * 2.8, by + float(ms["in"]))
		var outer := Vector2(c.x + sgn * 10.8, by + 0.6 + float(ms["out"]))
		if mood == "smug":
			if sgn < 0.0:
				inner.y -= 1.2
				outer.y -= 2.2
			else:
				inner.y += 0.6
		var mid := inner.lerp(outer, 0.45) + Vector2(0.0, -1.3 if mood != "angry" else -0.4)
		p.pline(PackedVector2Array([inner, mid, outer]), col, thick)
		if not p.small:
			p.pline(PackedVector2Array([inner + Vector2(0, -0.5), mid + Vector2(0, -0.6)]), Color(col.lightened(0.2), 0.5), thick * 0.4)
	if mood == "angry" and not p.small:
		p.line(Vector2(c.x - 1.0, by + 0.6), Vector2(c.x - 0.4, by + 3.0), Color(0.2, 0.1, 0.08, 0.35), 0.6)
		p.line(Vector2(c.x + 1.0, by + 0.6), Vector2(c.x + 0.4, by + 3.0), Color(0.2, 0.1, 0.08, 0.35), 0.6)


static func _nose(p: Painter, lk: Dictionary, f: Dictionary) -> void:
	var skin: Color = lk["skin"]
	var c: Vector2 = f["c"]
	var ny: float = f["nose_y"]
	var nw := 1.0 + float(lk["nose"]) * 0.18
	if f["kid"]:
		nw = 0.8
	if f["female"]:
		nw *= 0.85
	# the shaded side of the nose and the lit bridge
	p.shade(PackedVector2Array([Vector2(c.x + 0.8, ny - 8.5), Vector2(c.x + 3.2 * nw, ny - 0.5), Vector2(c.x + 1.2, ny + 1.4), Vector2(c.x + 0.2, ny - 6.0)]),
		Color(skin.darkened(0.25), 0.6), Color(skin.darkened(0.1), 0.3), Color(skin.darkened(0.45), 0.7), Vector2(c.x + 2.0, ny - 3.0), 5.0, Color(0, 0, 0, 0.0))
	p.line(Vector2(c.x - 0.9, ny - 8.0), Vector2(c.x - 1.3, ny - 1.5), Color(skin.lightened(0.25), 0.55), 0.9)
	p.fan(Vector2(c.x - 0.3, ny - 0.5), Vector2(2.6 * nw, 2.2), Color(skin.lightened(0.14), 0.7), Color(skin, 0.0))
	for sgn: float in [-1.0, 1.0]:
		p.ellipse(Vector2(c.x + sgn * 1.7 * nw, ny + 0.9), Vector2(1.0 * nw, 0.55), Color(skin.darkened(0.55), 0.9))
	p.fan(Vector2(c.x + 0.4, ny + 2.4), Vector2(3.6 * nw, 1.1), Color(skin.darkened(0.35), 0.5), Color(skin, 0.0))


static func _mouth(p: Painter, lk: Dictionary, f: Dictionary, mood: String) -> void:
	var skin: Color = lk["skin"]
	var c: Vector2 = f["c"]
	var my: float = f["mouth_y"]
	var ms := _mood_shape(mood)
	var shape: String = ms["mouth"]
	var lip: Color = lk["lipstick"]
	var line := skin.darkened(0.55)
	var hw := 4.8 if not f["kid"] else 3.8
	if f["female"]:
		hw = 4.2
	var mus: String = lk["mustache"]
	match shape:
		"smile":
			var up := PackedVector2Array([Vector2(c.x - hw - 0.4, my - 1.2), Vector2(c.x, my + 0.4), Vector2(c.x + hw + 0.4, my - 1.2)])
			var low := PackedVector2Array([Vector2(c.x + hw, my - 0.9), Vector2(c.x, my + 3.4), Vector2(c.x - hw, my - 0.9)])
			var m := PackedVector2Array(up)
			m.append_array(low)
			p.poly(m, Color(0.28, 0.08, 0.07))
			if not p.small:
				p.poly(PackedVector2Array([Vector2(c.x - hw + 0.8, my - 0.6), Vector2(c.x, my + 0.7), Vector2(c.x + hw - 0.8, my - 0.6), Vector2(c.x, my + 1.8)]), Color("ece4d4"))
			p.pline(up, line, 0.9)
			if lip.a > 0.0:
				p.pline(low, lip, 1.3)
			p.arc(Vector2(c.x - hw - 1.2, my - 1.8), 1.4, 0.2, 1.6, Color(skin.darkened(0.35), 0.6), 0.6, 6)
			p.arc(Vector2(c.x + hw + 1.2, my - 1.8), 1.4, PI - 1.6, PI - 0.2, Color(skin.darkened(0.35), 0.6), 0.6, 6)
		"o":
			p.ellipse(Vector2(c.x, my + 0.5), Vector2(2.2, 2.7), Color(0.22, 0.06, 0.06))
			p.arc(Vector2(c.x, my + 0.5), 2.4, 0.2, PI - 0.2, lip if lip.a > 0.0 else skin.darkened(0.3), 1.0, 10)
		"frown":
			var ml := PackedVector2Array([Vector2(c.x - hw, my + 1.4), Vector2(c.x - hw * 0.4, my - 0.2), Vector2(c.x + hw * 0.4, my - 0.2), Vector2(c.x + hw, my + 1.4)])
			if lip.a > 0.0:
				p.pline(ml, lip, 1.6)
			p.pline(ml, line, 1.0)
			p.line(Vector2(c.x - hw * 0.4, my - 0.4), Vector2(c.x + hw * 0.4, my - 0.4), Color("e0d6c6"), 0.5)
		"smirk":
			var ml := PackedVector2Array([Vector2(c.x - hw, my + 0.4), Vector2(c.x, my + 0.5), Vector2(c.x + hw * 0.7, my - 0.3), Vector2(c.x + hw + 0.6, my - 1.6)])
			if lip.a > 0.0:
				p.pline(ml, lip, 1.6)
			p.pline(ml, line, 1.0)
			p.arc(Vector2(c.x + hw + 1.6, my - 1.8), 1.3, PI - 1.4, PI - 0.1, Color(skin.darkened(0.35), 0.7), 0.6, 6)
		_:
			var ml := PackedVector2Array([Vector2(c.x - hw, my + 0.2), Vector2(c.x, my + 0.7), Vector2(c.x + hw, my + 0.2)])
			if lip.a > 0.0:
				p.poly(PackedVector2Array([Vector2(c.x - hw, my + 0.2), Vector2(c.x - 1.5, my - 1.0), Vector2(c.x, my - 0.4), Vector2(c.x + 1.5, my - 1.0), Vector2(c.x + hw, my + 0.2), Vector2(c.x, my + 2.4)]), lip)
			p.pline(ml, line, 0.9)
	if shape != "smile" and shape != "o":
		# the lower lip catches the light
		p.fan(Vector2(c.x - 0.4, my + 2.3), Vector2(3.4, 1.2), Color(skin.lightened(0.12), 0.55) if lip.a == 0.0 else Color(lip.lightened(0.2), 0.5), Color(skin, 0.0))
		p.fan(Vector2(c.x, my + 3.8), Vector2(3.0, 1.0), Color(skin.darkened(0.3), 0.4), Color(skin, 0.0))
	var hair: Color = lk["hair"]
	var mc := hair.darkened(0.15)
	match mus:
		"full":
			var mp := PackedVector2Array([Vector2(c.x - 5.6, my - 0.2), Vector2(c.x - 3.8, my - 3.0), Vector2(c.x, my - 2.6), Vector2(c.x + 3.8, my - 3.0), Vector2(c.x + 5.6, my - 0.2), Vector2(c.x, my - 1.0)])
			p.shade(mp, mc, mc.lightened(0.2), mc.darkened(0.3), Vector2(c.x, my - 1.5), 5.0)
		"pencil":
			p.line(Vector2(c.x - 4.4, my - 1.6), Vector2(c.x - 0.8, my - 2.1), mc, 0.8)
			p.line(Vector2(c.x + 0.8, my - 2.1), Vector2(c.x + 4.4, my - 1.6), mc, 0.8)
		"walrus":
			var mp := PackedVector2Array([Vector2(c.x - 7.8, my + 2.4), Vector2(c.x - 5.0, my - 3.2), Vector2(c.x, my - 2.8), Vector2(c.x + 5.0, my - 3.2), Vector2(c.x + 7.8, my + 2.4), Vector2(c.x + 3.0, my + 0.4), Vector2(c.x, my + 0.8), Vector2(c.x - 3.0, my + 0.4)])
			p.shade(mp, mc, mc.lightened(0.25), mc.darkened(0.3), Vector2(c.x, my - 1.0), 7.0)
			if not p.small:
				for i in 6:
					var x := c.x - 6.0 + i * 2.4
					p.line(Vector2(x, my - 2.2), Vector2(x + (x - c.x) * 0.15, my + 1.0), Color(mc.lightened(0.25), 0.5), 0.4)


# ------------------------------------------------------------------ hair

static func _hair_back(p: Painter, lk: Dictionary, f: Dictionary) -> void:
	var style: String = lk["hair_style"]
	if style not in ["bob", "curly"]:
		return
	var hair: Color = lk["hair"]
	var c: Vector2 = f["c"]
	var rx: float = f["rx"]
	var pts := PackedVector2Array()
	for i in 30:
		var a := PI + PI * i / 29.0
		pts.append(c + Vector2(cos(a) * (rx + 4.6), sin(a) * 21.5 - 1.0))
	pts.append(c + Vector2(rx + 4.6, 14.0))
	pts.append(c + Vector2(rx + 1.0, 16.5))
	pts.append(c + Vector2(-rx - 1.0, 16.5))
	pts.append(c + Vector2(-rx - 4.6, 14.0))
	p.shade(pts, hair, _lit(hair, 0.22), _dk(hair, 0.5), c, 20.0)


static func _hair_front(p: Painter, lk: Dictionary, f: Dictionary) -> void:
	var style: String = lk["hair_style"]
	var hat: String = lk["hat"]
	var hair: Color = lk["hair"]
	var c: Vector2 = f["c"]
	var rx: float = f["rx"]
	var lit := _lit(hair, 0.25)
	var dark := _dk(hair, 0.5)
	var covered := hat in ["fedora", "homburg", "bowler", "boater", "police", "watch", "newsboy", "flat", "cloche", "toque", "top"]
	if covered:
		# only the sides show under a hat: temples and sideburns
		if style in ["bob", "curly"]:
			for sgn: float in [-1.0, 1.0]:
				var sp := PackedVector2Array([Vector2(c.x + sgn * (rx - 1.0), c.y - 14.0), Vector2(c.x + sgn * (rx + 4.0), c.y - 10.0),
					Vector2(c.x + sgn * (rx + 4.2), c.y + 13.0), Vector2(c.x + sgn * (rx - 1.5), c.y + 10.0), Vector2(c.x + sgn * (rx - 3.0), c.y - 6.0)])
				if sgn > 0.0:
					sp.reverse()
				p.shade(sp, hair, lit, dark, c + Vector2(sgn * rx, 0.0), 14.0)
			return
		for sgn: float in [-1.0, 1.0]:
			var sp := PackedVector2Array([Vector2(c.x + sgn * (rx - 2.8), c.y - 14.5), Vector2(c.x + sgn * (rx + 0.6), c.y - 13.0),
				Vector2(c.x + sgn * (rx + 0.4), c.y + 1.5), Vector2(c.x + sgn * (rx - 1.2), c.y + 2.0), Vector2(c.x + sgn * (rx - 1.6), c.y - 8.0)])
			if sgn > 0.0:
				sp.reverse()
			p.shade(sp, hair, lit, dark, c + Vector2(sgn * rx, -6.0), 10.0)
		return
	match style:
		"bald":
			var dome := PackedVector2Array()
			for i in 21:
				var a := PI + PI * i / 20.0
				dome.append(c + Vector2(cos(a) * (rx + 0.2), sin(a) * 18.6 - 0.2))
			var sk: Color = lk["skin"]
			p.shade(dome, sk, sk.lightened(0.22), sk.darkened(0.3), c + Vector2(0, -8), 16.0)
			p.fan(c + Vector2(-5.0, -14.0), Vector2(5.0, 2.8), Color(1, 0.96, 0.9, 0.35), Color(1, 1, 1, 0.0), -0.3)
			# a soft grey fringe above the ears
			var skull := PackedVector2Array()
			for i in 44:
				var a := TAU * i / 44.0
				skull.append(c + Vector2(0, 0.5) + Vector2(cos(a) * (rx + 2.4), sin(a) * 20.0) * (1.0 + 0.045 * sin(a * 11.0)))
			for sgn: float in [-1.0, 1.0]:
				var side := PackedVector2Array([Vector2(c.x + sgn * (rx - 4.5), c.y - 7.0), Vector2(c.x + sgn * (rx + 6.0), c.y - 12.5),
					Vector2(c.x + sgn * (rx + 6.0), c.y + 3.0), Vector2(c.x + sgn * (rx - 2.0), c.y + 3.0)])
				if sgn > 0.0:
					side.reverse()
				p.shade_all(p.clip(skull, side), hair, _lit(hair, 0.3), _dk(hair, 0.4), c + Vector2(sgn * rx, -4.0), 10.0)
			if not p.small:
				for sgn: float in [-1.0, 1.0]:
					for j in 3:
						p.line(c + Vector2(sgn * (rx - 1.0 + j * 0.8), -9.0 + j * 2.5), c + Vector2(sgn * (rx + 1.2 + j * 0.3), -5.5 + j * 2.5), Color(_lit(hair, 0.4), 0.6), 0.5)
				var wr := Color((lk["skin"] as Color).darkened(0.35), 0.5)
				for j in 2:
					p.arc(c + Vector2(0, 2.0 + j * 2.5), 12.0, PI + 1.1, TAU - 1.1, wr, 0.5, 10)
		"bob", "curly":
			# a fringe across the forehead, the bob framing the face down to the jaw
			var skull := PackedVector2Array()
			for i in 40:
				var a := TAU * i / 40.0
				var rr := 1.0 + (0.035 * sin(a * 9.0) if style == "curly" else 0.0)
				skull.append(c + Vector2(0, 2.0) + Vector2(cos(a) * (rx + 3.0), sin(a) * 22.5) * rr)
			var region := PackedVector2Array()
			for i in 15:
				var t := float(i) / 14.0
				var x := lerpf(c.x - rx - 7.0, c.x + rx + 7.0, t)
				var dx := absf(x - c.x)
				var y := c.y - 9.2 + (0.8 if i % 2 == 0 else 0.0)
				if dx > rx - 3.0:
					y = lerpf(c.y - 9.0, c.y + 13.0, clampf((dx - rx + 3.0) / 4.0, 0.0, 1.0))
				region.append(Vector2(x, y))
			region.append(Vector2(c.x + rx + 7.0, c.y - 40.0))
			region.append(Vector2(c.x - rx - 7.0, c.y - 40.0))
			p.shade_all(p.clip(skull, region), hair, lit, dark, c + Vector2(0, -10), 18.0)
			p.arc(c + Vector2(-3.0, -6.0), 13.0, PI + 0.5, PI + 1.5, Color(lit.lightened(0.2), 0.6), 1.2, 10)
		_:
			# short, parted, slicked, cropped or red: the hair cap above a hairline
			var red := style == "red"
			var skull := PackedVector2Array()
			for i in 40:
				var a := TAU * i / 40.0
				var rr := 1.0 + (0.03 * sin(a * 7.0 + 1.0) if red else 0.0)
				skull.append(c + Vector2(0, 0.5) + Vector2(cos(a) * (rx + (1.6 if red else 1.1)), sin(a) * (21.6 if red else 20.6)) * rr)
			var hl := 11.5
			if style == "crop":
				hl = 9.5
			elif red:
				hl = 12.0
			var region := PackedVector2Array()
			for i in 17:
				var t := float(i) / 16.0
				var x := lerpf(c.x - rx - 6.0, c.x + rx + 6.0, t)
				var dx := (x - c.x) / rx
				var y := c.y - hl - (1.0 - dx * dx) * 1.4
				if absf(dx) > 0.78:
					y = lerpf(y, c.y - 1.0, clampf((absf(dx) - 0.78) / 0.2, 0.0, 1.0))
				if style == "part" and dx < -0.25 and dx > -0.5:
					y -= 1.5
				if style == "crop" or red:
					y += (0.9 if i % 2 == 0 else 0.0)
				region.append(Vector2(x, y))
			region.append(Vector2(c.x + rx + 6.0, c.y - 40.0))
			region.append(Vector2(c.x - rx - 6.0, c.y - 40.0))
			var polys := p.clip(skull, region)
			p.shade_all(polys, hair, _lit(hair, 0.3 if red else 0.25), dark, c + Vector2(0, -12), 16.0)
			if style == "slick":
				p.arc(c + Vector2(-2.0, -8.0), 12.0, PI + 0.55, PI + 1.55, Color(1, 1, 1, 0.3), 1.6, 12)
				p.arc(c + Vector2(-2.0, -8.0), 9.0, PI + 0.6, PI + 1.4, Color(1, 1, 1, 0.18), 1.0, 10)
			elif style == "part" and not p.small:
				p.line(c + Vector2(-rx * 0.38, -hl - 2.4), c + Vector2(-rx * 0.3, -20.0), dark, 0.8)
				p.arc(c + Vector2(-2.0, -8.0), 11.0, PI + 0.6, PI + 1.4, Color(lit.lightened(0.15), 0.5), 1.0, 10)
			elif red and not p.small:
				for i in 7:
					var x := c.x - 10.0 + i * 3.4
					p.pline(PackedVector2Array([Vector2(x, c.y - 19.5), Vector2(x + 1.5, c.y - 16.0), Vector2(x + 0.5, c.y - hl - 0.5)]), Color(_lit(hair, 0.35), 0.6), 0.6)
			else:
				p.arc(c + Vector2(-2.0, -8.0), 11.0, PI + 0.6, PI + 1.4, Color(lit.lightened(0.1), 0.45), 1.0, 10)


# ------------------------------------------------------------------ hats

static func _hat(p: Painter, lk: Dictionary, f: Dictionary) -> void:
	var hat: String = lk["hat"]
	if hat == "":
		return
	var col: Color = lk["hat_col"]
	var band: Color = lk["band"]
	var c: Vector2 = f["c"]
	var rx: float = f["rx"]
	var lit := _lit(col, 0.28)
	var dark := _dk(col, 0.55)
	var by := c.y - 14.5          # where the brim meets the forehead
	match hat:
		"fedora", "homburg":
			var hw := rx + 3.2
			# the brim's shadow falls across the forehead and the eyes
			p.fan(Vector2(c.x + 1.0, by + 5.5), Vector2(rx + 2.0, 7.0), Color(0.05, 0.03, 0.03, 0.5), Color(0.05, 0.03, 0.03, 0.0))
			var crown := PackedVector2Array([Vector2(c.x - hw + 1.0, by), Vector2(c.x - hw + 2.4, by - 13.5), Vector2(c.x - hw + 5.0, by - 18.8),
				Vector2(c.x - 3.0, by - 19.8), Vector2(c.x, by - 17.6 if hat == "fedora" else by - 19.4), Vector2(c.x + 3.0, by - 19.8),
				Vector2(c.x + hw - 5.0, by - 18.8), Vector2(c.x + hw - 2.4, by - 13.5), Vector2(c.x + hw - 1.0, by)])
			p.shade(crown, col, lit, dark, Vector2(c.x, by - 10.0), 16.0, _dk(col, 0.7))
			if hat == "fedora":
				# the pinches at the front
				for sgn: float in [-1.0, 1.0]:
					p.fan(Vector2(c.x + sgn * 6.0, by - 11.0), Vector2(2.4, 5.0), Color(_dk(col, 0.5), 0.5), Color(col, 0.0), sgn * 0.25)
				p.line(Vector2(c.x, by - 17.2), Vector2(c.x, by - 10.0), Color(_dk(col, 0.5), 0.6), 1.0)
			else:
				p.line(Vector2(c.x, by - 19.0), Vector2(c.x, by - 12.0), Color(_dk(col, 0.6), 0.7), 1.2)
			p.fan(Vector2(c.x - 6.0, by - 13.0), Vector2(4.0, 5.0), Color(_lit(col, 0.4), 0.35), Color(col, 0.0))
			# the band, a little bow on his left
			var bh := 4.2 if hat == "fedora" else 5.0
			var bp := PackedVector2Array([Vector2(c.x - hw + 1.05, by - bh), Vector2(c.x + hw - 1.05, by - bh), Vector2(c.x + hw - 1.0, by + 0.2), Vector2(c.x - hw + 1.0, by + 0.2)])
			p.shade(bp, band, _lit(band, 0.25), _dk(band, 0.5), Vector2(c.x, by - 2.0), 12.0, _dk(band, 0.6))
			p.ellipse(Vector2(c.x + hw - 4.5, by - bh * 0.5), Vector2(1.8, bh * 0.55), _dk(band, 0.25))
			# the brim: snapped down at the front
			var bw := rx + 13.5 if hat == "fedora" else rx + 11.5
			var brim := PackedVector2Array()
			for i in 17:
				var t := float(i) / 16.0
				var x := lerpf(c.x - bw, c.x + bw, t)
				var y := by - 1.6 - sin(t * PI) * 0.6 + (0.9 if hat == "homburg" else 0.0) * (1.0 - sin(t * PI)) * -2.0
				brim.append(Vector2(x, y))
			for i in 17:
				var t := 1.0 - float(i) / 16.0
				var x := lerpf(c.x - bw, c.x + bw, t)
				var dip := sin(t * PI)
				var y := by + 1.4 + dip * (3.2 if hat == "fedora" else 2.2) - (1.0 - dip) * (1.8 if hat == "homburg" else 0.4)
				brim.append(Vector2(x, y))
			p.shade(brim, col, _lit(col, 0.34), _dk(col, 0.5), Vector2(c.x, by), bw, _dk(col, 0.7))
			if hat == "homburg":
				p.pline(brim.slice(17, 34), Color(_dk(band, 0.2), 0.9), 1.1)
			p.pline(brim.slice(0, 17), Color(_lit(col, 0.4), 0.7), 0.8)
		"bowler":
			var hw := rx + 2.2
			p.fan(Vector2(c.x + 1.0, by + 5.0), Vector2(rx + 1.0, 6.0), Color(0.05, 0.03, 0.03, 0.45), Color(0.05, 0.03, 0.03, 0.0))
			var dome := PackedVector2Array()
			for i in 19:
				var a := PI + PI * i / 18.0
				dome.append(Vector2(c.x + cos(a) * hw, by - 1.0 + sin(a) * 17.0))
			p.shade(dome, col, _lit(col, 0.4), dark, Vector2(c.x, by - 9.0), 14.0, _dk(col, 0.7))
			p.fan(Vector2(c.x - 6.0, by - 11.0), Vector2(3.5, 6.0), Color(1, 1, 1, 0.3), Color(1, 1, 1, 0.0), 0.35)
			p.rect(Rect2(c.x - hw + 0.3, by - 3.4, hw * 2.0 - 0.6, 3.0), band)
			var brim := PackedVector2Array()
			var bw := rx + 7.0
			for i in 13:
				var t := float(i) / 12.0
				brim.append(Vector2(lerpf(c.x - bw, c.x + bw, t), by - 0.8 - (1.0 - sin(t * PI)) * 2.4))
			for i in 13:
				var t := 1.0 - float(i) / 12.0
				brim.append(Vector2(lerpf(c.x - bw, c.x + bw, t), by + 1.8 + sin(t * PI) * 1.6 - (1.0 - sin(t * PI)) * 2.0))
			p.shade(brim, col, _lit(col, 0.35), dark, Vector2(c.x, by), bw, _dk(col, 0.7))
		"boater":
			var hw := rx + 3.0
			p.fan(Vector2(c.x + 1.0, by + 5.0), Vector2(rx + 3.0, 6.0), Color(0.05, 0.03, 0.03, 0.4), Color(0.05, 0.03, 0.03, 0.0))
			var crown := PackedVector2Array([Vector2(c.x - hw, by), Vector2(c.x - hw, by - 11.0), Vector2(c.x + hw, by - 11.0), Vector2(c.x + hw, by)])
			p.shade(crown, col, _lit(col, 0.3), _dk(col, 0.35), Vector2(c.x, by - 6.0), 14.0, _dk(col, 0.5))
			p.ellipse(Vector2(c.x, by - 11.0), Vector2(hw, 2.0), _lit(col, 0.12))
			var bp := Rect2(c.x - hw, by - 5.5, hw * 2.0, 5.2)
			p.rect(bp, band)
			p.rect(Rect2(bp.position + Vector2(0, 1.8), Vector2(bp.size.x, 1.2)), Color(Pal.PAPER, 0.9))
			if not p.small:
				for j in 3:
					p.line(Vector2(c.x - hw, by - 7.0 - j * 1.4), Vector2(c.x + hw, by - 7.0 - j * 1.4), Color(_dk(col, 0.2), 0.5), 0.5)
			var bw := rx + 14.5
			var brim := PackedVector2Array()
			for i in 17:
				var t := float(i) / 16.0
				brim.append(Vector2(lerpf(c.x - bw, c.x + bw, t), by - 1.0 - sin(t * PI) * 0.8))
			for i in 17:
				var t := 1.0 - float(i) / 16.0
				brim.append(Vector2(lerpf(c.x - bw, c.x + bw, t), by + 1.6 + sin(t * PI) * 2.2))
			p.shade(brim, col, _lit(col, 0.3), _dk(col, 0.35), Vector2(c.x, by), bw, _dk(col, 0.55))
		"cloche":
			var hw := rx + 3.6
			var bell := PackedVector2Array()
			for i in 21:
				var a := PI + PI * i / 20.0
				bell.append(Vector2(c.x + cos(a) * hw, by + 4.0 + sin(a) * 22.0))
			bell.append(Vector2(c.x + hw + 1.8, by + 7.5))
			bell.append(Vector2(c.x - hw - 1.8, by + 7.5))
			p.shade(bell, col, _lit(col, 0.32), dark, Vector2(c.x, by - 6.0), 16.0, _dk(col, 0.7))
			var bp := PackedVector2Array([Vector2(c.x - hw - 0.2, by - 0.5), Vector2(c.x + hw + 0.2, by - 0.5), Vector2(c.x + hw + 0.8, by + 3.5), Vector2(c.x - hw - 0.8, by + 3.5)])
			p.shade(bp, band, _lit(band, 0.25), _dk(band, 0.4), Vector2(c.x, by + 1.5), 10.0)
			var fp := Vector2(c.x + hw - 3.0, by + 1.5)
			for i in 5:
				var a := TAU * i / 5.0
				p.circle(fp + Vector2(cos(a), sin(a)) * 1.9, 1.7, _lit(band, 0.2) if i % 2 == 0 else band)
			p.circle(fp, 1.1, Pal.BRASS)
			p.fan(Vector2(c.x + 1.0, by + 9.5), Vector2(rx, 4.0), Color(0.05, 0.03, 0.03, 0.4), Color(0.05, 0.03, 0.03, 0.0))
		"police":
			var hw := rx + 1.5
			var tw := rx + 6.0
			var crown := PackedVector2Array([Vector2(c.x - hw, by + 1.0), Vector2(c.x - tw, by - 9.0), Vector2(c.x - tw + 1.5, by - 12.0),
				Vector2(c.x + tw - 1.5, by - 12.0), Vector2(c.x + tw, by - 9.0), Vector2(c.x + hw, by + 1.0)])
			p.shade(crown, col, _lit(col, 0.2), _dk(col, 0.5), Vector2(c.x, by - 6.0), 14.0, _dk(col, 0.7))
			p.rect(Rect2(c.x - hw, by - 4.0, hw * 2.0, 5.0), Color("101014"))
			p.line(Vector2(c.x - hw, by - 1.4), Vector2(c.x + hw, by - 1.4), Color(Pal.BRASS, 0.6), 0.6)
			var shield := PackedVector2Array([Vector2(c.x - 3.2, by - 10.6), Vector2(c.x + 3.2, by - 10.6), Vector2(c.x + 3.4, by - 6.6), Vector2(c.x, by - 3.2), Vector2(c.x - 3.4, by - 6.6)])
			p.shade(shield, Pal.BRASS, Pal.BRASS.lightened(0.4), Pal.BRASS.darkened(0.45), Vector2(c.x, by - 7.0), 4.0, Pal.BRASS.darkened(0.5))
			p.circle(Vector2(c.x - 1.2, by - 8.8), 0.7, Color(1, 0.97, 0.85, 0.95))
			var visor := PackedVector2Array()
			for i in 13:
				var t := float(i) / 12.0
				visor.append(Vector2(lerpf(c.x - hw - 0.5, c.x + hw + 0.5, t), by + 0.6))
			for i in 13:
				var t := 1.0 - float(i) / 12.0
				visor.append(Vector2(lerpf(c.x - hw - 0.5, c.x + hw + 0.5, t), by + 1.4 + sin(t * PI) * 4.4))
			p.shade(visor, Color("121216"), Color("3a3a44"), Color("060608"), Vector2(c.x, by + 3.0), 8.0)
			p.arc(Vector2(c.x - 1.0, by - 2.0), 7.0, PI * 0.25, PI * 0.62, Color(1, 1, 1, 0.35), 0.8, 8)
			p.fan(Vector2(c.x + 1.0, by + 8.0), Vector2(rx, 4.5), Color(0.05, 0.03, 0.03, 0.4), Color(0.05, 0.03, 0.03, 0.0))
		"watch":
			var hw := rx + 1.8
			var dome := PackedVector2Array()
			for i in 19:
				var a := PI + PI * i / 18.0
				dome.append(Vector2(c.x + cos(a) * hw, by + 3.0 + sin(a) * 16.5))
			p.shade(dome, col, _lit(col, 0.24), dark, Vector2(c.x, by - 6.0), 14.0, _dk(col, 0.6))
			if not p.small:
				for i in 11:
					var x := c.x - hw + 2.0 + i * (hw * 2.0 - 4.0) / 10.0
					p.line(Vector2(x, by - 8.0 + absf(x - c.x) * 0.3), Vector2(x, by - 3.0), Color(_dk(col, 0.35), 0.6), 0.6)
			var cuff := PackedVector2Array([Vector2(c.x - hw - 0.6, by - 3.5), Vector2(c.x + hw + 0.6, by - 3.5), Vector2(c.x + hw + 0.4, by + 3.4), Vector2(c.x - hw - 0.4, by + 3.4)])
			p.shade(cuff, col.lightened(0.05), _lit(col, 0.3), _dk(col, 0.45), Vector2(c.x, by), 12.0, _dk(col, 0.6))
			for i in 14:
				var x := c.x - hw + 0.5 + i * (hw * 2.0 - 1.0) / 13.0
				p.line(Vector2(x, by - 3.0), Vector2(x, by + 3.0), Color(_dk(col, 0.3), 0.55), 0.55)
		"newsboy":
			var hw := rx + 4.5
			p.fan(Vector2(c.x + 1.0, by + 5.5), Vector2(rx + 1.0, 6.0), Color(0.05, 0.03, 0.03, 0.45), Color(0.05, 0.03, 0.03, 0.0))
			var crown := PackedVector2Array()
			for i in 21:
				var a := PI + PI * i / 20.0
				crown.append(Vector2(c.x + 1.0 + cos(a) * hw, by + 0.5 + sin(a) * 12.5))
			p.shade(crown, col, lit, dark, Vector2(c.x - 2.0, by - 6.0), 14.0, _dk(col, 0.7))
			if not p.small:
				for i in 5:
					var x := c.x + 1.0 + (i - 2) * hw * 0.42
					p.pline(PackedVector2Array([Vector2(c.x + 1.0, by - 11.6), Vector2(x * 0.5 + (c.x + 1.0) * 0.5, by - 7.0), Vector2(x, by - 0.5)]), Color(_dk(col, 0.4), 0.6), 0.6)
			p.circle(Vector2(c.x + 1.0, by - 11.8), 1.3, _dk(col, 0.2))
			var peak := PackedVector2Array()
			for i in 11:
				var t := float(i) / 10.0
				peak.append(Vector2(lerpf(c.x - rx + 1.0, c.x + rx - 1.0, t), by + 0.3))
			for i in 11:
				var t := 1.0 - float(i) / 10.0
				peak.append(Vector2(lerpf(c.x - rx + 1.0, c.x + rx - 1.0, t), by + 1.0 + sin(t * PI) * 3.6))
			p.shade(peak, _dk(col, 0.25), col, _dk(col, 0.6), Vector2(c.x, by + 2.0), 10.0)
		"flat":
			var hw := rx + 2.6
			p.fan(Vector2(c.x + 1.0, by + 5.5), Vector2(rx + 1.0, 6.0), Color(0.05, 0.03, 0.03, 0.45), Color(0.05, 0.03, 0.03, 0.0))
			var crown := PackedVector2Array([Vector2(c.x - hw, by + 0.5), Vector2(c.x - hw + 1.5, by - 6.0), Vector2(c.x - 4.0, by - 9.5), Vector2(c.x + 5.0, by - 9.0),
				Vector2(c.x + hw - 0.5, by - 5.0), Vector2(c.x + hw, by + 0.5)])
			p.shade(crown, col, lit, dark, Vector2(c.x - 2.0, by - 5.0), 12.0, _dk(col, 0.7))
			if not p.small:
				for i in 18:
					var q := Vector2(c.x - hw + 2.0 + Draw.hash01(i, 1, 4) * (hw * 2.0 - 4.0), by - 7.0 + Draw.hash01(i, 2, 4) * 6.5)
					p.circle(q, 0.4, Color(_dk(col, 0.3), 0.6))
			var peak := PackedVector2Array()
			for i in 11:
				var t := float(i) / 10.0
				peak.append(Vector2(lerpf(c.x - rx + 0.5, c.x + rx - 0.5, t), by + 0.2))
			for i in 11:
				var t := 1.0 - float(i) / 10.0
				peak.append(Vector2(lerpf(c.x - rx + 0.5, c.x + rx - 0.5, t), by + 1.0 + sin(t * PI) * 3.0))
			p.shade(peak, _dk(col, 0.2), col, _dk(col, 0.6), Vector2(c.x, by + 2.0), 10.0)
			p.circle(Vector2(c.x, by - 0.8), 0.8, _dk(col, 0.5))
		"toque":
			var hw := rx + 3.0
			var puff := PackedVector2Array()
			for i in 25:
				var a := PI + PI * i / 24.0
				var bump := 1.0 + 0.05 * sin(i * 1.7)
				puff.append(Vector2(c.x + cos(a) * (hw + 3.5) * bump, by - 7.0 + sin(a) * 17.0 * bump))
			puff.append(Vector2(c.x + hw, by - 5.0))
			puff.append(Vector2(c.x - hw, by - 5.0))
			p.shade(puff, col, Color(1, 1, 1), col.darkened(0.25), Vector2(c.x, by - 14.0), 16.0, col.darkened(0.35))
			if not p.small:
				for i in 6:
					var x := c.x - hw + 3.0 + i * (hw * 2.0 - 6.0) / 5.0
					p.line(Vector2(x, by - 18.0 + absf(x - c.x) * 0.3), Vector2(x, by - 6.0), Color(col.darkened(0.18), 0.7), 0.7)
			var bp := PackedVector2Array([Vector2(c.x - hw, by - 6.0), Vector2(c.x + hw, by - 6.0), Vector2(c.x + hw, by + 1.0), Vector2(c.x - hw, by + 1.0)])
			p.shade(bp, col.darkened(0.04), Color(1, 1, 1), col.darkened(0.25), Vector2(c.x, by - 2.0), 12.0, col.darkened(0.35))
		"top":
			var hw := rx + 0.6
			var crown := PackedVector2Array([Vector2(c.x - hw, by), Vector2(c.x - hw - 0.6, by - 26.0), Vector2(c.x + hw + 0.6, by - 26.0), Vector2(c.x + hw, by)])
			p.shade(crown, col, _lit(col, 0.2), _dk(col, 0.4), Vector2(c.x, by - 13.0), 16.0, _dk(col, 0.7))
			p.line(Vector2(c.x - 6.0, by - 24.0), Vector2(c.x - 5.0, by - 2.0), Color(1, 1, 1, 0.22), 2.0)
			p.rect(Rect2(c.x - hw, by - 5.0, hw * 2.0, 4.4), band)
			var brim := PackedVector2Array()
			var bw := rx + 6.0
			for i in 13:
				var t := float(i) / 12.0
				brim.append(Vector2(lerpf(c.x - bw, c.x + bw, t), by - 0.6 - (1.0 - sin(t * PI)) * 2.8))
			for i in 13:
				var t := 1.0 - float(i) / 12.0
				brim.append(Vector2(lerpf(c.x - bw, c.x + bw, t), by + 1.6 + sin(t * PI) * 1.4 - (1.0 - sin(t * PI)) * 2.2))
			p.shade(brim, col, _lit(col, 0.3), _dk(col, 0.4), Vector2(c.x, by), bw, _dk(col, 0.7))
		"paper":
			var pts := PackedVector2Array([Vector2(c.x - rx - 1.0, by + 1.0), Vector2(c.x - rx + 3.0, by - 7.5), Vector2(c.x + rx - 3.0, by - 7.5), Vector2(c.x + rx + 1.0, by + 1.0)])
			p.shade(pts, col, Color(1, 1, 1), col.darkened(0.25), Vector2(c.x, by - 3.0), 12.0, col.darkened(0.35))
			p.line(Vector2(c.x - rx + 1.0, by - 2.0), Vector2(c.x + rx - 1.0, by - 2.0), col.darkened(0.2), 0.7)
		"visor":
			p.fan(Vector2(c.x, by + 5.0), Vector2(rx + 1.0, 6.0), Color(0.2, 0.5, 0.3, 0.35), Color(0.2, 0.5, 0.3, 0.0))
			var vp := PackedVector2Array()
			for i in 13:
				var t := float(i) / 12.0
				vp.append(Vector2(lerpf(c.x - rx - 1.0, c.x + rx + 1.0, t), by - 1.0 - sin(t * PI) * 1.0))
			for i in 13:
				var t := 1.0 - float(i) / 12.0
				vp.append(Vector2(lerpf(c.x - rx - 1.0, c.x + rx + 1.0, t), by + 2.0 + sin(t * PI) * 5.0))
			p.shade(vp, Color(col, 0.85), Color(col.lightened(0.3), 0.85), Color(col.darkened(0.4), 0.9), Vector2(c.x, by + 2.0), 10.0)
			p.line(Vector2(c.x - rx - 1.0, by - 1.0), Vector2(c.x + rx + 1.0, by - 1.0), Color("1e2a22"), 1.2)
		"headband":
			p.pline(PackedVector2Array([Vector2(c.x - rx - 2.4, by + 2.5), Vector2(c.x - 6.0, by - 0.6), Vector2(c.x + 6.0, by - 0.6), Vector2(c.x + rx + 2.4, by + 2.5)]), col, 2.0)
			var feather: Color = lk["feather"]
			if feather.a > 0.0:
				var a := Vector2(c.x + rx - 1.0, by + 0.5)
				var fpts := PackedVector2Array([a, a + Vector2(5.0, -10.0), a + Vector2(9.0, -24.0), a + Vector2(3.0, -12.0)])
				p.shade(fpts, feather, feather.lightened(0.3), feather.darkened(0.3), a + Vector2(5, -12), 8.0)
				p.line(a, a + Vector2(8.5, -23.0), feather.darkened(0.3), 0.6)
			p.circle(Vector2(c.x + rx - 1.0, by + 1.0), 1.8, Pal.BRASS.lightened(0.2))
			p.circle(Vector2(c.x + rx - 1.4, by + 0.5), 0.7, Color(1, 1, 1, 0.9))


# ------------------------------------------------------------------ glasses, cigars

static func _face_props(p: Painter, lk: Dictionary, f: Dictionary, mood: String) -> void:
	var c: Vector2 = f["c"]
	var ey: float = f["eye_y"]
	if lk["glasses"]:
		var rim := Color("b8a060") if lk["age"] == 2 else Color("2a2622")
		for sgn: float in [-1.0, 1.0]:
			var ec := Vector2(c.x + sgn * 6.9, ey)
			p.arc(ec, 4.4, 0.0, TAU, rim, 0.7, 20)
			p.arc(ec, 3.6, PI + 0.5, PI + 1.4, Color(1, 1, 1, 0.45), 0.6, 8)
			p.line(ec + Vector2(sgn * 4.4, -0.8), Vector2(c.x + sgn * (float(f["rx"]) + 0.5), ey - 1.5), rim, 0.6)
		p.arc(Vector2(c.x, ey - 0.2), 2.5, PI + 0.6, TAU - 0.6, rim, 0.7, 8)
	if "cigar" in lk["props"]:
		var a := Vector2(c.x + 3.0, float(f["mouth_y"]) + 0.8)
		var b := a + Vector2(11.0, 3.4)
		p.line(a, b, Color("2e1c10"), 3.2)
		p.line(a, b, Color("7a4e2c"), 2.4)
		p.line(a + Vector2(0.3, -0.5), b + Vector2(-0.4, -0.7), Color(Color("a87a4a"), 0.7), 0.7)
		p.line(a + (b - a) * 0.22, a + (b - a) * 0.3, Color("c9a54a"), 2.6)
		p.circle(b, 1.5, Color("8a8580"))
		p.circle(b + Vector2(0.8, 0.2), 0.9, Color(1.0, 0.45, 0.15))
		p.fan(b + Vector2(0.8, 0.2), Vector2(3.0, 3.0), Color(1.0, 0.5, 0.2, 0.35), Color(1.0, 0.5, 0.2, 0.0))
		if not p.small:
			p.pline(PackedVector2Array([b + Vector2(1.0, -1.5), b + Vector2(3.0, -5.0), b + Vector2(1.5, -9.0), b + Vector2(3.5, -13.0)]), Color(0.85, 0.82, 0.78, 0.25), 1.2)
	if "pencil" in lk["props"] and lk["hat"] == "":
		var e := Vector2(c.x - float(f["rx"]) - 1.0, c.y - 1.0)
		p.line(e + Vector2(-2.0, -3.0), e + Vector2(3.0, 5.0), Color("c9a54a"), 1.4)
		p.line(e + Vector2(2.4, 4.0), e + Vector2(3.0, 5.0), Color("2a2622"), 1.0)
	if mood == "scared" and not p.small:
		var sd := Vector2(c.x + float(f["rx"]) - 2.5, c.y - 6.0)
		p.poly(PackedVector2Array([sd + Vector2(0, -2.2), sd + Vector2(1.2, 0.4), sd + Vector2(0, 1.4), sd + Vector2(-1.2, 0.4)]), Color(0.8, 0.9, 1.0, 0.75))


static func _lit(c: Color, a: float) -> Color:
	return c.lerp(Color(1.0, 0.93, 0.8), a)


static func _dk(c: Color, a: float) -> Color:
	return c.lerp(Color(0.05, 0.035, 0.04), a)
