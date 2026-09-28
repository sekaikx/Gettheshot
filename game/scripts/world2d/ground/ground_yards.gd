class_name GroundYards
extends RefCounted
## The backyards in the middle of each block (lots of kind "courtyard"): packed dirt and weeds,
## board fences dividing the yards, a privy, a shed, barrels, a washtub, woodpiles, a vegetable
## patch or a chicken run, laundry strung across between the back walls, and a cat.

const M := W.M
const FENCE_H := 1.8
const LINE_H := 7.0

var lay: GroundLayout
var grain: Texture2D
var mottle: Texture2D
var solids: Array = []


func _init(layout: GroundLayout) -> void:
	lay = layout
	grain = GroundTex.grain()
	mottle = GroundTex.mottle()


static func _c(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	ci.draw_circle(c, r, col, true, -1.0, true)


func plan_yard(b: Dictionary) -> void:
	var lot: Dictionary = b["yard"]
	var r := W.lot_rect(lot)
	var rm := Rect2(r.position / M, r.size / M)
	var s := GroundUtil.hseed(lay.seed_value, int(lot["id"]), 41)
	var yp := {"r": rm, "s": s, "fences": [], "items": [], "lines": [], "yards": [], "paths": []}
	var mid := rm.get_center() + Vector2(GroundUtil.rr(s, 1, -1.0, 1.0), GroundUtil.rr(s, 2, -1.0, 1.0))
	var pattern := GroundUtil.ri(s, 3, 0, 3)
	var yards: Array = []
	match pattern:
		0:
			yp["fences"].append([Vector2(mid.x, rm.position.y), Vector2(mid.x, rm.end.y)])
			yp["fences"].append([Vector2(rm.position.x, mid.y), Vector2(rm.end.x, mid.y)])
			yards = [Rect2(rm.position, mid - rm.position), Rect2(Vector2(mid.x, rm.position.y), Vector2(rm.end.x - mid.x, mid.y - rm.position.y)),
				Rect2(Vector2(rm.position.x, mid.y), Vector2(mid.x - rm.position.x, rm.end.y - mid.y)), Rect2(mid, rm.end - mid)]
		1:
			yp["fences"].append([Vector2(mid.x, rm.position.y), Vector2(mid.x, rm.end.y)])
			yards = [Rect2(rm.position, Vector2(mid.x - rm.position.x, rm.size.y)), Rect2(Vector2(mid.x, rm.position.y), Vector2(rm.end.x - mid.x, rm.size.y))]
		2:
			yp["fences"].append([Vector2(rm.position.x, mid.y), Vector2(rm.end.x, mid.y)])
			yards = [Rect2(rm.position, Vector2(rm.size.x, mid.y - rm.position.y)), Rect2(Vector2(rm.position.x, mid.y), Vector2(rm.size.x, rm.end.y - mid.y))]
		_:
			yp["fences"].append([Vector2(mid.x, rm.position.y), Vector2(mid.x, mid.y)])
			yp["fences"].append([Vector2(rm.position.x, mid.y), Vector2(rm.end.x, mid.y)])
			yards = [Rect2(rm.position, mid - rm.position), Rect2(Vector2(mid.x, rm.position.y), Vector2(rm.end.x - mid.x, mid.y - rm.position.y)),
				Rect2(Vector2(rm.position.x, mid.y), Vector2(rm.size.x, rm.end.y - mid.y))]
	# a gate in each fence
	var fk := 0
	for f in yp["fences"]:
		fk += 1
		f.append(GroundUtil.rr(s, 10 + fk, 0.3, 0.7))
	yp["yards"] = yards
	# things in the yards: big ones against the back walls, in the corners
	var bag := ["privy", "shed", "barrels", "washtub", "woodpile", "crates", "patch", "coop", "cans", "chair"]
	var used := {}
	for yi in yards.size():
		var yr: Rect2 = yards[yi]
		var ys := s + yi * 101
		var corners := [0, 1, 2, 3]
		for q in range(3, 0, -1):
			var j := GroundUtil.ri(ys, 20 + q, 0, q)
			var tmp: int = corners[q]
			corners[q] = corners[j]
			corners[j] = tmp
		var n := GroundUtil.ri(ys, 30, 2, 3)
		for k in n:
			var t: String = bag[GroundUtil.ri(ys, 40 + k, 0, bag.size() - 1)]
			if k == 0 and yi == 0:
				t = "privy"
			elif k == 0 and yi == 1:
				t = "shed"
			if t in ["privy", "shed", "coop", "patch"] and used.has(t):
				t = ["barrels", "crates", "cans", "woodpile"][GroundUtil.ri(ys, 50 + k, 0, 3)]
			used[t] = true
			var size: Vector2 = {"privy": Vector2(1.15, 1.2), "shed": Vector2(1.9, 1.4), "barrels": Vector2(1.3, 0.66),
				"washtub": Vector2(1.0, 0.8), "woodpile": Vector2(1.5, 0.6), "crates": Vector2(1.1, 0.8), "patch": Vector2(1.8, 1.3),
				"coop": Vector2(1.7, 1.2), "cans": Vector2(1.05, 0.55), "chair": Vector2(0.5, 0.5)}[t]
			if size.x > yr.size.x - 0.4 or size.y > yr.size.y - 0.4:
				size = size.min(yr.size - Vector2(0.5, 0.5))
				if size.x < 0.5 or size.y < 0.5:
					continue
			var corner: int = corners[k % 4]
			var pos := Vector2(yr.position.x + 0.2 if corner % 2 == 0 else yr.end.x - 0.2 - size.x,
				yr.position.y + 0.2 if corner < 2 else yr.end.y - 0.2 - size.y)
			var ir := Rect2(pos, size)
			var clash := false
			for it in yp["items"]:
				if (it["r"] as Rect2).grow(0.15).intersects(ir):
					clash = true
			if clash:
				continue
			yp["items"].append({"t": t, "r": ir, "s": ys + k * 7})
			if t != "patch":
				solids.append(Rect2(ir.position * M, ir.size * M))
	# laundry strung across, wall to wall
	var nl := GroundUtil.ri(s, 60, 2, 3)
	var ns := GroundUtil.r01(s, 61) < 0.5
	for k in nl:
		var t := (float(k) + 0.5) / float(nl) + GroundUtil.rr(s, 62 + k, -0.08, 0.08)
		var a: Vector2
		var e: Vector2
		if ns:
			var x := lerpf(rm.position.x, rm.end.x, t)
			a = Vector2(x, rm.position.y - 0.2)
			e = Vector2(x + GroundUtil.rr(s, 66 + k, -1.2, 1.2), rm.end.y + 0.2)
		else:
			var z := lerpf(rm.position.y, rm.end.y, t)
			a = Vector2(rm.position.x - 0.2, z)
			e = Vector2(rm.end.x + 0.2, z + GroundUtil.rr(s, 66 + k, -1.2, 1.2))
		yp["lines"].append([a, e, s + 300 + k * 17])
	# a stone path from a back door into each yard
	for yi in yards.size():
		var yr: Rect2 = yards[yi]
		var ys := s + yi * 77
		yp["paths"].append([yr.get_center() + Vector2(GroundUtil.rr(ys, 1, -0.8, 0.8), GroundUtil.rr(ys, 2, -0.8, 0.8)), ys])
	# the cat: on a shed or privy roof if there is one, else on the ground
	var cat_on := {}
	for it in yp["items"]:
		if it["t"] in ["shed", "privy"]:
			cat_on = it
			break
	var cp: Vector2
	if not cat_on.is_empty():
		cp = (cat_on["r"] as Rect2).get_center() + Vector2(GroundUtil.rr(s, 70, -0.25, 0.25), GroundUtil.rr(s, 71, -0.2, 0.2))
	else:
		var yr0: Rect2 = yards[GroundUtil.ri(s, 72, 0, yards.size() - 1)]
		cp = yr0.get_center() + Vector2(GroundUtil.rr(s, 73, -1.0, 1.0), GroundUtil.rr(s, 74, -1.0, 1.0))
	yp["cat"] = {"p": cp, "rot": GroundUtil.r01(s, 75) * TAU, "col": GroundUtil.ri(s, 76, 0, 3), "curled": GroundUtil.r01(s, 77) < 0.5,
		"roof": not cat_on.is_empty()}
	b["yard_plan"] = yp
	# fences as thin solids
	for f in yp["fences"]:
		var a: Vector2 = f[0]
		var e: Vector2 = f[1]
		var rr := Rect2(Vector2(minf(a.x, e.x), minf(a.y, e.y)) - Vector2(0.05, 0.05), (e - a).abs() + Vector2(0.1, 0.1))
		solids.append(Rect2(rr.position * M, rr.size * M))


# ================================================================== ground

func paint_ground(ci: CanvasItem, b: Dictionary) -> void:
	var yp: Dictionary = b["yard_plan"]
	var rm: Rect2 = yp["r"]
	var r := Rect2(rm.position * M, rm.size * M)
	var s: int = yp["s"]
	var dirt := Color("5d4f3f").lerp(Color("574a3c"), GroundUtil.r01(s, 1))
	ci.draw_rect(r, dirt)
	GroundUtil.tex_rect(ci, r, mottle, 6.0, Color(1, 1, 1, 0.3))
	GroundUtil.tex_rect(ci, r, grain, 1.0, Color(1, 1, 1, 0.95))
	# damp dark soil along the walls, packed paler dirt where people walk
	for e in 4:
		var er: Rect2 = [Rect2(r.position, Vector2(r.size.x, 0.35 * M)), Rect2(r.position, Vector2(0.35 * M, r.size.y)),
			Rect2(Vector2(r.position.x, r.end.y - 0.35 * M), Vector2(r.size.x, 0.35 * M)), Rect2(Vector2(r.end.x - 0.35 * M, r.position.y), Vector2(0.35 * M, r.size.y))][e]
		ci.draw_rect(er, Color(0.08, 0.06, 0.04, 0.22))
	for pth in yp["paths"]:
		var c: Vector2 = (pth[0] as Vector2) * M
		var ps: int = pth[1]
		GroundUtil.soft_blob(ci, c, 1.3 * M, Color(0.8, 0.72, 0.6, 0.12), ps, Vector2(1.2, 1.0))
		# a few flagstones
		var dir := Vector2.RIGHT.rotated(GroundUtil.r01(ps, 5) * TAU)
		for k in 4:
			var q := c + dir * (float(k) - 1.5) * 0.52 * M + Vector2(GroundUtil.rr(ps, 10 + k, -0.08, 0.08), GroundUtil.rr(ps, 20 + k, -0.08, 0.08)) * M
			var st := GroundUtil.orect(q, Vector2(GroundUtil.rr(ps, 30 + k, 0.34, 0.44), GroundUtil.rr(ps, 35 + k, 0.28, 0.36)) * M, dir.angle() + GroundUtil.rr(ps, 40 + k, -0.2, 0.2))
			ci.draw_colored_polygon(st, Color(0.03, 0.02, 0.01, 0.3))
			var inner_st := PackedVector2Array()
			for v in st:
				inner_st.append(q + (v - q) * 0.9 + Vector2(-0.6, -0.6))
			Draw.poly(ci, inner_st, Color("958c7c").darkened(GroundUtil.rr(ps, 50 + k, 0.0, 0.15)))
			GroundUtil.tex_poly(ci, inner_st, grain, 1.0, Color(1, 1, 1, 0.6))
	# odds and ends lying about
	for k in 6:
		var q := r.position + Vector2(GroundUtil.r01(s, 100 + k) * r.size.x, GroundUtil.r01(s, 110 + k) * r.size.y)
		var roll := GroundUtil.r01(s, 120 + k)
		if roll < 0.35:
			ci.draw_colored_polygon(GroundUtil.orect(q, Vector2(0.24, 0.12) * M, GroundUtil.r01(s, 130 + k) * PI), Pal.BRICK.lightened(0.05))
		elif roll < 0.6:
			ci.draw_colored_polygon(GroundUtil.orect(q, Vector2(GroundUtil.rr(s, 140 + k, 0.8, 1.4), 0.14) * M, GroundUtil.r01(s, 150 + k) * PI), Pal.PLANKS.darkened(0.1))
		else:
			GroundStreets.litter_bit(ci, q, s + k * 13)
	# weeds along the fences and in the corners
	for f in yp["fences"]:
		var a: Vector2 = (f[0] as Vector2) * M
		var e: Vector2 = (f[1] as Vector2) * M
		for k in 7:
			var t := GroundUtil.r01(s + int(a.x), 200 + k)
			_weed(ci, a.lerp(e, t) + Vector2(GroundUtil.rr(s, 210 + k, -6, 6), GroundUtil.rr(s, 220 + k, -6, 6)), s + 230 + k)
	for k in 10:
		var q := r.position + Vector2(GroundUtil.r01(s, 300 + k) * r.size.x, GroundUtil.r01(s, 310 + k) * r.size.y)
		# hug the walls
		if k % 2 == 0:
			q.x = r.position.x + 5.0 if q.x - r.position.x < r.end.x - q.x else r.end.x - 5.0
		else:
			q.y = r.position.y + 5.0 if q.y - r.position.y < r.end.y - q.y else r.end.y - 5.0
		_weed(ci, q, s + 320 + k)
	# puddle marks
	for k in 2:
		var q := r.position + Vector2(GroundUtil.rr(s, 400 + k, 0.2, 0.8) * r.size.x, GroundUtil.rr(s, 410 + k, 0.2, 0.8) * r.size.y)
		ci.draw_colored_polygon(GroundUtil.blob(q, 0.45 * M, s + 420 + k, 12, 0.3, Vector2(1.3, 0.9)), Color(0.05, 0.04, 0.02, 0.18))
	for it in yp["items"]:
		if it["t"] == "patch":
			_patch(ci, it)


func _weed(ci: CanvasItem, c: Vector2, s: int) -> void:
	var n := GroundUtil.ri(s, 1, 6, 11)
	var base := Color("6a7a3a").lerp(Color("4a6a32"), GroundUtil.r01(s, 2))
	_c(ci, c + Vector2(1.5, 2.0), 4.0, Color(0.02, 0.02, 0.0, 0.2))
	for k in n:
		var a := GroundUtil.r01(s, 10 + k) * TAU
		var l := GroundUtil.rr(s, 20 + k, 4.0, 9.0)
		var tip := c + Vector2(cos(a), sin(a)) * l
		ci.draw_line(c, tip, base.lightened(GroundUtil.rr(s, 30 + k, -0.1, 0.25)), 2.0, true)
		if k % 3 == 0:
			_c(ci, tip, 1.6, base.lightened(0.3))
	_c(ci, c, 2.4, base.darkened(0.15))


func _patch(ci: CanvasItem, it: Dictionary) -> void:
	var r := Rect2((it["r"] as Rect2).position * M, (it["r"] as Rect2).size * M)
	var s: int = it["s"]
	ci.draw_rect(r, Color("3a2c20"))
	GroundUtil.tex_rect(ci, r, grain, 1.0, Color(1, 1, 1, 0.9))
	ci.draw_rect(r, Color("6a5a40"), false, 2.0, true)
	var rows := int(r.size.y / 12.0)
	for k in rows:
		var y := r.position.y + (float(k) + 0.5) * r.size.y / float(rows)
		ci.draw_line(Vector2(r.position.x + 3, y), Vector2(r.end.x - 3, y), Color(0.1, 0.07, 0.04, 0.5), 2.0, true)
		var x := r.position.x + 6.0
		while x < r.end.x - 4.0:
			var leaf := Color("4f7a3a").lerp(Color("6a8a3a"), GroundUtil.r01(s, int(x) + k * 50))
			_c(ci, Vector2(x, y), GroundUtil.rr(s, int(x) * 3 + k, 2.4, 4.2), leaf)
			_c(ci, Vector2(x - 1, y - 1), 1.3, leaf.lightened(0.25))
			x += 9.0
	# tomato stakes
	for k in 3:
		_c(ci, r.position + Vector2(r.size.x * (0.2 + 0.3 * k), 3.0), 1.6, Color("7a6a50"))


func paint_wet(ci: CanvasItem, b: Dictionary) -> void:
	var yp: Dictionary = b["yard_plan"]
	var rm: Rect2 = yp["r"]
	var r := Rect2(rm.position * M, rm.size * M)
	var s: int = yp["s"]
	ci.draw_rect(r, Color(0.04, 0.03, 0.04, 0.28))
	for k in 3:
		var q := r.position + Vector2(GroundUtil.rr(s, 400 + k, 0.2, 0.8) * r.size.x, GroundUtil.rr(s, 410 + k, 0.2, 0.8) * r.size.y)
		var pts := GroundUtil.blob(q, 0.5 * M, s + 420 + k, 12, 0.3, Vector2(1.3, 0.9))
		ci.draw_colored_polygon(pts, Color(0.3, 0.3, 0.32, 0.55))
		ci.draw_colored_polygon(GroundUtil.blob(q + Vector2(3, 3), 0.25 * M, s + 430 + k, 10, 0.3), Color(0.5, 0.52, 0.56, 0.35))


# ================================================================== raised things

func paint_shadows(ci: CanvasItem, b: Dictionary) -> void:
	var yp: Dictionary = b["yard_plan"]
	var o := GroundUtil.sh(FENCE_H)
	for f in yp["fences"]:
		var a: Vector2 = (f[0] as Vector2) * M
		var e: Vector2 = (f[1] as Vector2) * M
		ci.draw_colored_polygon(PackedVector2Array([a, e, e + o, a + o]), Color(GroundUtil.SH, 0.22))
	for it in yp["items"]:
		var r := Rect2((it["r"] as Rect2).position * M, (it["r"] as Rect2).size * M)
		var h: float = {"privy": 2.2, "shed": 2.0, "barrels": 0.9, "washtub": 0.5, "woodpile": 0.9, "crates": 0.8,
			"patch": 0.0, "coop": 1.0, "cans": 0.7, "chair": 0.8}[it["t"]]
		if h > 0.0:
			GroundUtil.shadow_poly(ci, GroundUtil.rect_pts(r), GroundUtil.sh(h * 0.7))
	for ln in yp["lines"]:
		var a: Vector2 = (ln[0] as Vector2) * M
		var e: Vector2 = (ln[1] as Vector2) * M
		var so := GroundUtil.sh(LINE_H * 0.35)
		ci.draw_line(a + so, e + so, Color(GroundUtil.SH, 0.12), 1.4, true)
		for g in _garments(ln):
			_garment(ci, g, true)


func paint_bodies(ci: CanvasItem, b: Dictionary) -> void:
	var yp: Dictionary = b["yard_plan"]
	for it in yp["items"]:
		match it["t"]:
			"privy": _privy(ci, it)
			"shed": _shed(ci, it)
			"barrels": _barrels(ci, it)
			"washtub": _washtub(ci, it)
			"woodpile": _woodpile(ci, it)
			"crates": _crates(ci, it)
			"coop": _coop(ci, it)
			"cans": _cans(ci, it)
			"chair": _chair(ci, it)
	for f in yp["fences"]:
		_fence(ci, f, yp["s"])
	var cat: Dictionary = yp["cat"]
	_cat(ci, cat)


func paint_high(ci: CanvasItem, b: Dictionary) -> void:
	var yp: Dictionary = b["yard_plan"]
	for ln in yp["lines"]:
		var a: Vector2 = (ln[0] as Vector2) * M
		var e: Vector2 = (ln[1] as Vector2) * M
		ci.draw_line(a, e, Color(0.1, 0.08, 0.06, 0.35), 2.4, true)
		ci.draw_line(a, e, Color(0.86, 0.83, 0.75, 0.95), 1.2, true)
		for g in _garments(ln):
			_garment(ci, g, false)
		_c(ci, a, 2.5, Color("3a3430"))
		_c(ci, e, 2.5, Color("3a3430"))


## One piece of washing, pegged on the line and hanging toward the south-east (flat, so it reads).
func _garment(ci: CanvasItem, g: Dictionary, shadow: bool) -> void:
	var w: float = (g["size"] as Vector2).x
	var h: float = (g["size"] as Vector2).y
	var top: Vector2 = g["top"]
	if shadow:
		top += GroundUtil.sh(LINE_H * 0.3)
	ci.draw_set_transform(top, float(g["rot"]), Vector2.ONE)
	var col: Color = g["col"]
	if shadow:
		col = Color(GroundUtil.SH, 0.2)
	var dark := col.darkened(0.2) if not shadow else col
	match g["t"]:
		"shirt":
			var body := PackedVector2Array([Vector2(-w * 0.3, 0), Vector2(w * 0.3, 0), Vector2(w * 0.3, h), Vector2(-w * 0.3, h)])
			Draw.poly(ci, body, col, not shadow)
			for sx: float in [-1.0, 1.0]:
				ci.draw_colored_polygon(PackedVector2Array([Vector2(sx * w * 0.3, 0), Vector2(sx * w * 0.5, h * 0.08),
					Vector2(sx * w * 0.5, h * 0.5), Vector2(sx * w * 0.3, h * 0.42)]), dark)
			if not shadow:
				ci.draw_line(Vector2(0, h * 0.12), Vector2(0, h), col.darkened(0.25), 1.0, true)
				ci.draw_colored_polygon(PackedVector2Array([Vector2(-w * 0.12, 0), Vector2(w * 0.12, 0), Vector2(0, h * 0.14)]), col.darkened(0.3))
		"trousers":
			ci.draw_rect(Rect2(-w * 0.5, 0, w, h * 0.14), dark)
			ci.draw_rect(Rect2(-w * 0.5, h * 0.12, w * 0.46, h * 0.88), col)
			ci.draw_rect(Rect2(w * 0.04, h * 0.12, w * 0.46, h * 0.88), col)
		"dress":
			Draw.poly(ci, PackedVector2Array([Vector2(-w * 0.24, 0), Vector2(w * 0.24, 0), Vector2(w * 0.5, h), Vector2(-w * 0.5, h)]), col, not shadow)
			if not shadow:
				ci.draw_rect(Rect2(-w * 0.3, h * 0.3, w * 0.6, h * 0.06), col.darkened(0.25))
		"sheet":
			var pts := PackedVector2Array([Vector2(-w * 0.5, 0), Vector2(w * 0.5, 0)])
			for k in 7:
				var t := 1.0 - float(k) / 6.0
				pts.append(Vector2(-w * 0.5 + w * t, h + sin(t * TAU * 1.5) * h * 0.05))
			Draw.poly(ci, pts, col, not shadow)
			if not shadow:
				for k in 3:
					var x := (float(k) - 1.0) * w * 0.28
					ci.draw_line(Vector2(x, h * 0.05), Vector2(x + 2.0, h * 0.95), Color(0, 0, 0, 0.1), 2.0, true)
		_:
			for sx: float in [-1.0, 1.0]:
				ci.draw_rect(Rect2(sx * w * 0.3 - w * 0.18, 0, w * 0.36, h * 0.75), col)
				ci.draw_rect(Rect2(sx * w * 0.3 - w * 0.18, h * 0.62, w * 0.58 * sx, h * 0.3).abs(), col)
	if not shadow:
		# the hem is in its own shade; pegs on the line
		ci.draw_rect(Rect2(-w * 0.5, h * 0.72, w, h * 0.28), Color(0, 0, 0, 0.1))
		for sx: float in [-0.3, 0.3]:
			ci.draw_rect(Rect2(sx * w - 1.2, -2.0, 2.4, 4.5), Color("9a8a6a"))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Garments along a line: [{t, top px, size px, rot, col}]
func _garments(ln: Array) -> Array:
	var a: Vector2 = (ln[0] as Vector2) * M
	var e: Vector2 = (ln[1] as Vector2) * M
	var s: int = ln[2]
	var d := e - a
	var l := d.length()
	var rot := d.angle()
	# local +y (the hanging side) must point down or right on screen
	var hang := Vector2(0, 1).rotated(rot)
	if hang.y < -0.2 or (absf(hang.y) <= 0.2 and hang.x < 0.0):
		rot += PI
	var out := []
	var t := GroundUtil.rr(s, 1, 0.08, 0.16)
	var k := 0
	var cols := [Color("ece6d6"), Color("dcd4c0"), Color("a8b8c8"), Color("c0ae8e"), Color("c89a90"), Color("7f90a8"),
		Color("e4dccb"), Color("a0584a"), Color("8a9a7a"), Color("d8c89a")]
	while t < 0.92:
		k += 1
		var kind: String = ["shirt", "sheet", "trousers", "shirt", "sock", "dress", "sheet", "shirt", "trousers"][GroundUtil.ri(s, 10 + k, 0, 8)]
		var size: Vector2 = {"shirt": Vector2(0.62, 0.62), "sheet": Vector2(1.15, 0.85), "trousers": Vector2(0.42, 0.9),
			"sock": Vector2(0.28, 0.3), "dress": Vector2(0.55, 0.85)}[kind] * M
		var w := size.x / l
		if t + w > 0.95:
			break
		var col: Color = cols[GroundUtil.ri(s, 20 + k, 0, cols.size() - 1)]
		if kind == "sheet":
			col = cols[GroundUtil.ri(s, 20 + k, 0, 1)]
		out.append({"t": kind, "top": a + d * (t + w * 0.5), "size": size, "rot": rot + GroundUtil.rr(s, 30 + k, -0.06, 0.06), "col": col})
		t += w + GroundUtil.rr(s, 40 + k, 0.015, 0.06)
	return out


func _px(it: Dictionary) -> Rect2:
	return Rect2((it["r"] as Rect2).position * M, (it["r"] as Rect2).size * M)


func _fence(ci: CanvasItem, f: Array, s: int) -> void:
	var a: Vector2 = (f[0] as Vector2) * M
	var e: Vector2 = (f[1] as Vector2) * M
	var gate: float = f[2]
	var d := e - a
	var l := d.length()
	var dir := d / l
	var n := Vector2(-dir.y, dir.x)
	var wood := Color("857866")
	var board := 0.16 * M
	var t := 0.0
	var k := 0
	var g0 := gate * l - 0.45 * M
	var g1 := gate * l + 0.45 * M
	while t < l:
		k += 1
		var tl := minf(board, l - t)
		if t + tl > g0 and t < g1:
			t += tl
			continue
		if GroundUtil.r01(s + int(a.x + a.y), k) < 0.05:
			t += tl
			continue      # a missing board
		var p0 := a + dir * t
		var col := wood.lightened(GroundUtil.rr(s + int(a.x), k, -0.14, 0.1))
		ci.draw_line(p0 + dir * 0.5 + n * 0.8, p0 + dir * (tl - 0.5) + n * 0.8, col.darkened(0.45), 4.8, true)
		ci.draw_line(p0 + dir * 0.5, p0 + dir * (tl - 0.5), col, 4.0, true)
		ci.draw_line(p0 + dir * 0.6 - n * 1.3, p0 + dir * (tl - 0.6) - n * 1.3, col.lightened(0.22), 1.0, true)
		t += tl
	# posts
	var pt := 0.0
	while pt <= l + 0.1:
		var q := a + dir * minf(pt, l)
		ci.draw_rect(Rect2(q - Vector2(3.2, 3.2), Vector2(6.4, 6.4)), wood.darkened(0.3))
		ci.draw_rect(Rect2(q - Vector2(3.2, 3.2), Vector2(6.4, 1.5)), Color(1, 1, 1, 0.12))
		pt += 1.8 * M
	# the gate hanging half open
	var gp := a + dir * g0
	ci.draw_line(gp, gp + (dir.rotated(0.9)) * 0.85 * M, wood.darkened(0.1), 3.6, true)


func _roof(ci: CanvasItem, r: Rect2, col: Color, _s: int, ridge_along_x: bool) -> void:
	ci.draw_rect(r.grow(1.5), col.darkened(0.45))
	if ridge_along_x:
		var mid := r.position.y + r.size.y * 0.5
		ci.draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * 0.5)), col.lightened(0.08))
		ci.draw_rect(Rect2(Vector2(r.position.x, mid), Vector2(r.size.x, r.size.y * 0.5)), col.darkened(0.12))
		ci.draw_line(Vector2(r.position.x, mid), Vector2(r.end.x, mid), col.lightened(0.25), 1.6, true)
	else:
		var midx := r.position.x + r.size.x * 0.5
		ci.draw_rect(Rect2(r.position, Vector2(r.size.x * 0.5, r.size.y)), col.lightened(0.08))
		ci.draw_rect(Rect2(Vector2(midx, r.position.y), Vector2(r.size.x * 0.5, r.size.y)), col.darkened(0.12))
		ci.draw_line(Vector2(midx, r.position.y), Vector2(midx, r.end.y), col.lightened(0.25), 1.6, true)
	GroundUtil.tex_rect(ci, r, grain, 1.0, Color(1, 1, 1, 0.4))


func _privy(ci: CanvasItem, it: Dictionary) -> void:
	var r := _px(it)
	var s: int = it["s"]
	# a lean-to of weathered boards, sloping one way
	var wood := Color("6a5a44").lightened(GroundUtil.rr(s, 1, -0.05, 0.08))
	ci.draw_rect(r.grow(1.5), wood.darkened(0.45))
	Draw.hgrad(ci, r, wood.lightened(0.1), wood.darkened(0.15))
	var x := r.position.x + 5.0
	while x < r.end.x - 2.0:
		ci.draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), Color(0, 0, 0, 0.25), 1.0, true)
		x += 7.0
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, 2.0)), Color(1, 1, 1, 0.14))
	# the vent crescent in the door gable
	ci.draw_arc(r.get_center() + Vector2(0, r.size.y * 0.32), 3.0, PI * 0.2, PI * 1.2, 8, Color(0.05, 0.04, 0.03, 0.9), 1.6, true)


func _shed(ci: CanvasItem, it: Dictionary) -> void:
	var r := _px(it)
	var s: int = it["s"]
	_roof(ci, r, Pal.TAR_2.lightened(0.1), s, r.size.x > r.size.y)
	var x := r.position.x + 12.0
	while x < r.end.x - 4.0:
		ci.draw_line(Vector2(x, r.position.y + 1), Vector2(x, r.end.y - 1), Color(0, 0, 0, 0.22), 1.5, true)
		x += 14.0
	# a stovepipe and a patch
	_c(ci, r.position + r.size * Vector2(0.78, 0.3), 3.5, Color("1a1a1a"))
	_c(ci, r.position + r.size * Vector2(0.78, 0.3), 2.2, Color("444"))
	ci.draw_rect(Rect2(r.position + r.size * Vector2(0.2, 0.55), Vector2(12, 8)), Pal.TAR.darkened(0.2))


func _barrels(ci: CanvasItem, it: Dictionary) -> void:
	var r := _px(it)
	var s: int = it["s"]
	var n := maxi(1, int(r.size.x / (0.64 * M)))
	for k in n:
		var c := Vector2(r.position.x + (float(k) + 0.5) * r.size.x / float(n), r.get_center().y)
		if k == 0 and GroundUtil.r01(s, 3) < 0.6:
			# a rain barrel, full
			_c(ci, c, 0.3 * M, Color("2a221a"))
			_c(ci, c, 0.27 * M, Pal.FLOOR_WOOD.darkened(0.1))
			ci.draw_arc(c, 0.24 * M, 0.0, TAU, 18, Color("2c2a28"), 2.0, true)
			_c(ci, c, 0.21 * M, Color("26343c"))
			_c(ci, c + Vector2(-2, -2), 0.08 * M, Color(0.6, 0.66, 0.72, 0.4))
		else:
			GroundQuay.barrel(ci, c, 0.3 * M, s + k)


func _washtub(ci: CanvasItem, it: Dictionary) -> void:
	var r := _px(it)
	var c := r.get_center() + Vector2(-0.1 * M, 0)
	Draw.ellipse(ci, c, Vector2(0.4, 0.32) * M, Color("6a6c6a"))
	Draw.ellipse(ci, c, Vector2(0.36, 0.28) * M, Color("8e908c"))
	Draw.ellipse(ci, c, Vector2(0.31, 0.23) * M, Color("7a8a8e"))
	Draw.ellipse(ci, c + Vector2(-3, -2), Vector2(0.14, 0.08) * M, Color(0.9, 0.92, 0.9, 0.5))
	# the washboard leaning on it
	var wb := Rect2(Vector2(r.end.x - 0.28 * M, r.position.y + 3.0), Vector2(0.24 * M, r.size.y - 6.0))
	ci.draw_rect(wb, Color("8a6a44"))
	var y := wb.position.y + 4.0
	while y < wb.end.y - 3.0:
		ci.draw_line(Vector2(wb.position.x + 2, y), Vector2(wb.end.x - 2, y), Color("b8b4a8"), 1.2, true)
		y += 3.0


func _woodpile(ci: CanvasItem, it: Dictionary) -> void:
	var r := _px(it)
	var s: int = it["s"]
	ci.draw_rect(r, Color("3e3226"))
	var rad := 5.0
	var y := r.position.y + rad + 1.0
	var row := 0
	while y < r.end.y - rad * 0.5:
		var x := r.position.x + rad + 1.0 + (rad if row % 2 == 1 else 0.0)
		while x < r.end.x - rad * 0.5:
			var wood := Color("9a7a52").lerp(Color("7a5a3a"), GroundUtil.r01(s, int(x) * 5 + int(y)))
			_c(ci, Vector2(x, y), rad, Color("4a3a2a"))
			_c(ci, Vector2(x, y), rad - 1.2, wood)
			ci.draw_arc(Vector2(x, y), rad * 0.45, 0.0, TAU, 8, wood.darkened(0.2), 0.8, true)
			x += rad * 2.0
		y += rad * 1.75
		row += 1


func _crates(ci: CanvasItem, it: Dictionary) -> void:
	var r := _px(it)
	var s: int = it["s"]
	var wood := Pal.ROPE.darkened(0.2)
	ci.draw_rect(r, wood.darkened(0.4))
	ci.draw_rect(r.grow(-2.0), wood)
	for k in range(1, 4):
		var x := r.position.x + r.size.x * float(k) / 4.0
		ci.draw_line(Vector2(x, r.position.y + 2), Vector2(x, r.end.y - 2), Color(0, 0, 0, 0.25), 1.0, true)
	ci.draw_line(r.position + Vector2(3, 3), r.end - Vector2(3, 3), wood.darkened(0.25), 2.0, true)
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, 1.5)), Color(1, 1, 1, 0.15))
	if GroundUtil.r01(s, 1) < 0.5:
		var small := Rect2(r.position + r.size * 0.15, r.size * 0.5)
		GroundUtil.shadow_poly(ci, GroundUtil.rect_pts(small), Vector2(4, 5))
		ci.draw_rect(small, wood.lightened(0.1))
		ci.draw_rect(small, wood.darkened(0.35), false, 1.5, true)


func _coop(ci: CanvasItem, it: Dictionary) -> void:
	var r := _px(it)
	var s: int = it["s"]
	# a wire run with a little hut at one end, and a few hens
	var hut := Rect2(r.position, Vector2(r.size.x * 0.4, r.size.y))
	var run := Rect2(Vector2(hut.end.x, r.position.y), Vector2(r.size.x * 0.6, r.size.y))
	ci.draw_rect(run, Color("5a4a36"))
	for k in 4:
		var c := run.position + Vector2(GroundUtil.rr(s, 10 + k, 0.2, 0.8) * run.size.x, GroundUtil.rr(s, 20 + k, 0.2, 0.8) * run.size.y)
		Draw.ellipse(ci, c, Vector2(4.2, 3.0), Color("e8e0cc"), GroundUtil.r01(s, 30 + k) * TAU)
		_c(ci, c + Vector2(3.5, 0).rotated(GroundUtil.r01(s, 30 + k) * TAU), 1.6, Color("c0392b"))
	var x := run.position.x
	while x <= run.end.x:
		ci.draw_line(Vector2(x, run.position.y), Vector2(x, run.end.y), Color(0.75, 0.75, 0.72, 0.35), 0.8, true)
		x += 4.0
	var y := run.position.y
	while y <= run.end.y:
		ci.draw_line(Vector2(run.position.x, y), Vector2(run.end.x, y), Color(0.75, 0.75, 0.72, 0.35), 0.8, true)
		y += 4.0
	ci.draw_rect(run, Color("4a3a2a"), false, 2.0, true)
	_roof(ci, hut, Color("6a5a44"), s, false)


func _cans(ci: CanvasItem, it: Dictionary) -> void:
	var r := _px(it)
	var s: int = it["s"]
	for k in 2:
		var c := Vector2(r.position.x + (float(k) + 0.5) * r.size.x * 0.5, r.get_center().y)
		_c(ci, c, 0.25 * M, Color("5e605e"))
		_c(ci, c, 0.23 * M, Color("7e807c"))
		if GroundUtil.r01(s, k) < 0.5:
			_c(ci, c, 0.19 * M, Color("4a4743"))
			_c(ci, c + Vector2(1, 1), 0.15 * M, Color("6b6760"))
		else:
			_c(ci, c, 0.2 * M, Color("969892"))
			ci.draw_line(c - Vector2(0.08 * M, 0), c + Vector2(0.08 * M, 0), Color("3c3d3c"), 2.4, true)


func _chair(ci: CanvasItem, it: Dictionary) -> void:
	var r := _px(it)
	var wood := Color("7a5a3c")
	ci.draw_rect(r.grow(-3.0), wood)
	ci.draw_rect(Rect2(r.position + Vector2(3, 3), Vector2(r.size.x - 6, 4)), wood.darkened(0.3))
	for q in [r.position + Vector2(3, 3), Vector2(r.end.x - 3, r.position.y + 3)]:
		_c(ci, q, 2.0, wood.darkened(0.35))


func _cat(ci: CanvasItem, cat: Dictionary) -> void:
	var c: Vector2 = (cat["p"] as Vector2) * M
	var rot: float = cat["rot"]
	var col: Color = [Color("1c1a1a"), Color("6a6660"), Color("b8763a"), Color("e8e2d4")][int(cat["col"])]
	var t := Transform2D(rot, c)
	ci.draw_set_transform_matrix(t)
	var so := GroundUtil.sh(0.25 if not cat["roof"] else 0.3).rotated(-rot)
	if cat["curled"]:
		ci.draw_colored_polygon(Draw.ellipse_points(so, Vector2(9, 8), 0.0, 14), Color(GroundUtil.SH, 0.35))
		Draw.ellipse(ci, Vector2.ZERO, Vector2(9, 8), col)
		ci.draw_arc(Vector2.ZERO, 7.5, 0.4, PI * 1.6, 12, col.darkened(0.25), 3.0, true)
		_c(ci, Vector2(5, -3), 3.8, col.lightened(0.05))
		Draw.poly(ci, PackedVector2Array([Vector2(6.5, -6.5), Vector2(8.5, -4.5), Vector2(5.0, -4.2)]), col.darkened(0.1))
		Draw.poly(ci, PackedVector2Array([Vector2(3.0, -6.8), Vector2(5.5, -6.8), Vector2(3.2, -4.0)]), col.darkened(0.1))
	else:
		ci.draw_colored_polygon(Draw.ellipse_points(Vector2(-1, 0) + so, Vector2(8, 5.5), 0.0, 14), Color(GroundUtil.SH, 0.35))
		Draw.ellipse(ci, Vector2(-1, 0), Vector2(8, 5.5), col)
		_c(ci, Vector2(7, 0), 4.2, col.lightened(0.04))
		Draw.poly(ci, PackedVector2Array([Vector2(8.5, -3.8), Vector2(11.5, -3.0), Vector2(9.0, -1.2)]), col.darkened(0.12))
		Draw.poly(ci, PackedVector2Array([Vector2(8.5, 3.8), Vector2(11.5, 3.0), Vector2(9.0, 1.2)]), col.darkened(0.12))
		var tail := PackedVector2Array()
		for k in 7:
			var a := float(k) / 6.0
			tail.append(Vector2(-8.0 - a * 5.0, sin(a * PI) * 5.0))
		ci.draw_polyline(tail, col, 2.4, true)
	if int(cat["col"]) == 1:
		for k in 3:
			ci.draw_line(Vector2(-4 + k * 3, -4), Vector2(-5 + k * 3, 4), col.darkened(0.3), 1.2, true)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
