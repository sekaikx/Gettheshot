extends RefCounted
## Floors, walls, windows and doors of an interior (lot-local frame, see kit.gd).

const Kit := preload("res://scripts/world2d/rooms/kit.gd")
const M := W.M

const CAP_OUT := Color("2c2320")        # outer brick walls from above (Pal.BRICK_DARK, deep shade)
const CAP_IN := Color("3e3530")         # plaster partitions from above


static func _cap_out() -> Color:
	return Pal.BRICK_DARK.darkened(0.42)


static func _cap_in() -> Color:
	return Pal.TAR.lerp(Pal.PLASTER, 0.12)


# ------------------------------------------------------------------ floors

static func floor(k: Kit, r: Rect2, style: String, s: int) -> void:
	match style:
		"planks": _planks(k, r, Pal.FLOOR_WOOD, s, 0.0)
		"planks_dark": _planks(k, r, Pal.FLOOR_WOOD.darkened(0.22), s, 0.0)
		"planks_worn": _planks(k, r, Pal.FLOOR_WOOD.lerp(Pal.PLANKS, 0.5), s, 0.35)
		"parquet": _parquet(k, r, s)
		"hex": _hex(k, r, s)
		"checker": _checker(k, r, Pal.FLOOR_TILE.lightened(0.28), Pal.SIGN_BLACK.lightened(0.14), s)
		"checker_red": _checker(k, r, Pal.FLOOR_TILE.lightened(0.24), Pal.FLOOR_TILE_2, s)
		"tile": _tile(k, r, Pal.FLOOR_TILE.lightened(0.3), s, false, false)
		"tile_wet": _tile(k, r, Pal.FLOOR_TILE.lightened(0.12).lerp(Pal.GLASS, 0.15), s, true, false)
		"tile_dusty": _tile(k, r, Pal.FLOOR_TILE.lightened(0.22), s, false, true)
		"lino": _lino(k, r, Pal.PLASTER.lightened(0.22), Pal.AWNING_COLORS[1].lightened(0.28), s)
		"lino_green": _lino(k, r, Pal.FELT.lerp(Pal.FLOOR_TILE, 0.55), Pal.FELT.lerp(Pal.FLOOR_TILE, 0.3), s)
		"concrete": _concrete(k, r, s)
		_: _planks(k, r, Pal.FLOOR_WOOD, s, 0.0)


## Boards running front to back, staggered joints, each board its own shade.
static func _planks(k: Kit, r: Rect2, base: Color, s: int, wear: float) -> void:
	k.rect(r, base)
	var bw := 0.2 * M
	var n := ceili(r.size.x / bw)
	var joints := PackedVector2Array()
	var gaps := PackedVector2Array()
	for i in n:
		var x0 := r.position.x + i * bw
		var x1 := minf(x0 + bw, r.end.x)
		var y := r.position.y - k.h(i, 1, s) * 2.0 * M
		var j := 0
		while y < r.end.y:
			var len := (1.3 + k.h(i, j, s + 1) * 1.6) * M
			var y0 := maxf(y, r.position.y)
			var y1 := minf(y + len, r.end.y)
			var t := k.h(i, j, s + 2)
			var c := base.lightened(0.07 * t) if t > 0.5 else base.darkened(0.09 * (1.0 - t))
			if k.h(i, j, s + 9) > 0.93:
				c = c.darkened(0.08)
			if y1 > y0:
				k.rect(Rect2(x0, y0, x1 - x0, y1 - y0), c)
			if y + len < r.end.y and y + len > r.position.y:
				joints.append(Vector2(x0, y + len))
				joints.append(Vector2(x1, y + len))
			# a couple of nail heads at the joint
			y += len
			j += 1
		gaps.append(Vector2(x0, r.position.y))
		gaps.append(Vector2(x0, r.end.y))
	k.lines(gaps, base.darkened(0.42), 1.0)
	k.lines(joints, base.darkened(0.36), 1.0)
	# faint grain
	var grain := PackedVector2Array()
	for i in n:
		for g in 2:
			var x := r.position.x + i * bw + bw * (0.3 + 0.4 * g) + (k.h(i, g, s + 4) - 0.5) * 2.0
			var ya := r.position.y + k.h(i, g, s + 5) * r.size.y * 0.6
			grain.append(Vector2(x, ya))
			grain.append(Vector2(x, minf(r.end.y, ya + (0.8 + k.h(i, g, s + 6) * 1.8) * M)))
	k.lines(grain, Color(base.darkened(0.2), 0.45), 1.0)
	if wear > 0.0:
		# a worn path down the middle, lighter and scuffed
		var wr := Rect2(r.position.x + r.size.x * 0.32, r.position.y, r.size.x * 0.36, r.size.y)
		k.ci.draw_rect(wr, Color(Pal.PLANKS.lightened(0.25), wear * 0.25))


static func _parquet(k: Kit, r: Rect2, s: int) -> void:
	var base := Pal.FLOOR_WOOD.lightened(0.04)
	k.rect(r, base)
	var q := 0.42 * M
	var nx := ceili(r.size.x / q)
	var ny := ceili(r.size.y / q)
	var segs := PackedVector2Array()
	var grid := PackedVector2Array()
	for iy in ny:
		for ix in nx:
			var p := r.position + Vector2(ix, iy) * q
			var sz := Vector2(minf(q, r.end.x - p.x), minf(q, r.end.y - p.y))
			var t := k.h(ix, iy, s)
			var c := base.lightened(0.06 * t) if (ix + iy) % 2 == 0 else base.darkened(0.12 + 0.05 * t)
			k.rect(Rect2(p, sz), c)
			var vertical := (ix + iy) % 2 == 0
			for m: int in [1, 2]:
				if vertical:
					var x := p.x + q * m / 3.0
					if x < p.x + sz.x:
						segs.append(Vector2(x, p.y))
						segs.append(Vector2(x, p.y + sz.y))
				else:
					var y := p.y + q * m / 3.0
					if y < p.y + sz.y:
						segs.append(Vector2(p.x, y))
						segs.append(Vector2(p.x + sz.x, y))
	for ix in nx + 1:
		grid.append(Vector2(r.position.x + ix * q, r.position.y))
		grid.append(Vector2(r.position.x + ix * q, r.end.y))
	for iy in ny + 1:
		grid.append(Vector2(r.position.x, r.position.y + iy * q))
		grid.append(Vector2(r.end.x, r.position.y + iy * q))
	k.lines(segs, base.darkened(0.3), 1.0)
	k.lines(grid, base.darkened(0.42), 1.0)
	# a dark border band
	var b := 0.22 * M
	var bc := base.darkened(0.3)
	k.ci.draw_rect(r.grow(-b * 0.5), Color(bc, 0.9), false, b * 0.5)


## Small white hexagonal tiles, the 1920s bathroom-and-soda-fountain floor, with a black border
## and a scatter of black "flowers".
static func _hex(k: Kit, r: Rect2, s: int) -> void:
	var white := Pal.FLOOR_TILE.lightened(0.34)
	var black := Pal.SIGN_BLACK.lightened(0.16)
	var grout := Pal.FLOOR_TILE.darkened(0.12)
	k.rect(r, white)
	var rad := 0.085 * M
	var hx := rad * sqrt(3.0)
	var hy := rad * 1.5
	var ny := ceili(r.size.y / hy) + 1
	var nx := ceili(r.size.x / hx) + 1
	var segs := PackedVector2Array()
	var fills: Array = []
	for iy in ny:
		for ix in nx:
			var c := r.position + Vector2(ix * hx + (hx * 0.5 if iy % 2 == 1 else 0.0), iy * hy)
			# three edges per hexagon (the others belong to neighbours)
			var p0 := c + Vector2(0, -rad)
			var p1 := c + Vector2(hx * 0.5, -rad * 0.5)
			var p2 := c + Vector2(hx * 0.5, rad * 0.5)
			var p5 := c + Vector2(-hx * 0.5, -rad * 0.5)
			segs.append_array([_cl(p5, r), _cl(p0, r), _cl(p0, r), _cl(p1, r), _cl(p1, r), _cl(p2, r)])
			var border := c.x < r.position.x + 0.32 * M or c.x > r.end.x - 0.32 * M or c.y < r.position.y + 0.32 * M or c.y > r.end.y - 0.32 * M
			var inner_border := c.x < r.position.x + 0.5 * M or c.x > r.end.x - 0.5 * M or c.y < r.position.y + 0.5 * M or c.y > r.end.y - 0.5 * M
			var flower := ((ix % 6 == 3 and iy % 8 == 4) or (ix % 6 == 0 and iy % 8 == 0)) and not inner_border
			if (inner_border and not border) or flower:
				fills.append(c)
	for c in fills:
		var pts := PackedVector2Array()
		for j in 6:
			var a := PI / 6.0 + j * PI / 3.0
			pts.append(c + Vector2(cos(a), sin(a)) * rad * 0.97)
		k.ci.draw_colored_polygon(pts, black)
	k.lines(segs, grout, 1.0)


static func _cl(p: Vector2, r: Rect2) -> Vector2:
	return Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))


## A point for a blotch of radius `rad` px that stays inside the room.
static func _inside(k: Kit, r: Rect2, j: int, s: int, rad: float) -> Vector2:
	var q := r.grow(-rad)
	if q.size.x <= 1.0 or q.size.y <= 1.0:
		return r.get_center()
	return q.position + Vector2(k.h(j, 1, s), k.h(j, 2, s)) * q.size


static func _checker(k: Kit, r: Rect2, a: Color, b: Color, s: int) -> void:
	k.rect(r, a)
	var q := 0.3 * M
	var nx := ceili(r.size.x / q)
	var ny := ceili(r.size.y / q)
	for iy in ny:
		for ix in nx:
			var p := r.position + Vector2(ix, iy) * q
			var sz := Vector2(minf(q, r.end.x - p.x), minf(q, r.end.y - p.y))
			var t := k.h(ix, iy, s)
			if (ix + iy) % 2 == 1:
				k.rect(Rect2(p, sz), b.lightened(0.05 * t))
			elif t > 0.8:
				k.rect(Rect2(p, sz), a.darkened(0.05))
	var segs := PackedVector2Array()
	for ix in nx + 1:
		segs.append(Vector2(r.position.x + ix * q, r.position.y))
		segs.append(Vector2(r.position.x + ix * q, r.end.y))
	for iy in ny + 1:
		segs.append(Vector2(r.position.x, r.position.y + iy * q))
		segs.append(Vector2(r.end.x, r.position.y + iy * q))
	k.lines(segs, Color(a.darkened(0.35), 0.5), 1.0)


static func _tile(k: Kit, r: Rect2, base: Color, s: int, wet: bool, dusty: bool) -> void:
	k.rect(r, base)
	var q := 0.25 * M
	var nx := ceili(r.size.x / q)
	var ny := ceili(r.size.y / q)
	for iy in ny:
		for ix in nx:
			var t := k.h(ix, iy, s)
			if t > 0.78:
				var p := r.position + Vector2(ix, iy) * q
				k.rect(Rect2(p, Vector2(minf(q, r.end.x - p.x), minf(q, r.end.y - p.y))), base.darkened(0.05 + 0.04 * (t - 0.78) * 5.0))
	var segs := PackedVector2Array()
	for ix in nx + 1:
		segs.append(Vector2(r.position.x + ix * q, r.position.y))
		segs.append(Vector2(r.position.x + ix * q, r.end.y))
	for iy in ny + 1:
		segs.append(Vector2(r.position.x, r.position.y + iy * q))
		segs.append(Vector2(r.end.x, r.position.y + iy * q))
	k.lines(segs, base.darkened(0.2), 1.0)
	if wet:
		for j in 5:
			var rad := Vector2(0.5 + k.h(j, 3, s) * 0.7, 0.3 + k.h(j, 4, s) * 0.4) * M
			var c := _inside(k, r, j, s + 7, rad.x)
			k.ellipse(c, rad, Color(Pal.GLASS.lightened(0.2), 0.22), k.h(j, 5, s) * PI)
	if dusty:
		for j in 7:
			var rad2 := Vector2(0.4 + k.h(j, 3, s + 9) * 0.8, 0.3 + k.h(j, 4, s + 9) * 0.5) * M
			var c2 := _inside(k, r, j, s + 9, rad2.x)
			k.ellipse(c2, rad2, Color(1, 1, 1, 0.13), k.h(j, 5, s + 9) * PI)


static func _lino(k: Kit, r: Rect2, a: Color, b: Color, s: int) -> void:
	k.rect(r, a)
	var q := 0.6 * M
	var nx := ceili(r.size.x / q)
	var ny := ceili(r.size.y / q)
	for iy in ny:
		for ix in nx:
			if (ix + iy) % 2 == 0:
				var p := r.position + Vector2(ix, iy) * q
				k.rect(Rect2(p, Vector2(minf(q, r.end.x - p.x), minf(q, r.end.y - p.y))), a.lerp(b, 0.28 + 0.08 * k.h(ix, iy, s)))
	# a border in the darker colour
	var bw := 0.18 * M
	k.ci.draw_rect(r.grow(-bw * 0.5 - 0.1 * M), b, false, bw)
	# mottling
	for j in 9:
		var rad := Vector2(0.7, 0.45) * M * (0.6 + k.h(j, 3, s + 3))
		var c := _inside(k, r, j, s + 3, rad.x)
		k.ellipse(c, rad, Color(b.darkened(0.2), 0.08), k.h(j, 4, s + 3) * PI)
	var segs := PackedVector2Array()
	for ix in nx + 1:
		segs.append(Vector2(r.position.x + ix * q, r.position.y))
		segs.append(Vector2(r.position.x + ix * q, r.end.y))
	for iy in ny + 1:
		segs.append(Vector2(r.position.x, r.position.y + iy * q))
		segs.append(Vector2(r.end.x, r.position.y + iy * q))
	k.lines(segs, Color(b.darkened(0.3), 0.35), 1.0)


static func _concrete(k: Kit, r: Rect2, s: int) -> void:
	var base := Pal.SIDEWALK_DARK.lerp(Pal.QUAY_STONE, 0.4)
	k.rect(r, base)
	for j in 14:
		var t := k.h(j, 3, s)
		var rad := Vector2(0.8 + t * 1.6, 0.5 + t) * M
		var c := _inside(k, r, j, s, rad.x)
		k.ellipse(c, rad, Color(base.lightened(0.05) if t > 0.5 else base.darkened(0.05), 0.22), k.h(j, 4, s) * PI)
	# expansion joints every 3 m
	var q := 3.0 * M
	var segs := PackedVector2Array()
	var x := r.position.x + q
	while x < r.end.x - 4:
		segs.append(Vector2(x, r.position.y))
		segs.append(Vector2(x, r.end.y))
		x += q
	var y := r.position.y + q
	while y < r.end.y - 4:
		segs.append(Vector2(r.position.x, y))
		segs.append(Vector2(r.end.x, y))
		y += q
	k.lines(segs, Color(base.darkened(0.25), 0.6), 1.0)
	# oil stains and a crack or two
	for j in 5:
		var rad2 := Vector2(0.25 + k.h(j, 7, s) * 0.35, 0.18 + k.h(j, 8, s) * 0.2) * M
		var c2 := _inside(k, r, j, s + 40, rad2.x)
		k.ellipse(c2, rad2, Color(Pal.SIGN_BLACK, 0.16), k.h(j, 9, s) * PI)
	for j in 3:
		var p := _inside(k, r, j, s + 60, 1.4 * M)
		var pts := PackedVector2Array([p])
		var d := Vector2.from_angle(k.h(j, 12, s) * TAU)
		for m in 5:
			d = d.rotated((k.h(j, 13 + m, s) - 0.5) * 1.2)
			p += d * (0.2 + k.h(j, 20 + m, s) * 0.25) * M
			pts.append(p)
		k.pline(pts, Color(base.darkened(0.35), 0.7), 1.0)


## Soft darkening along the foot of every wall (ambient occlusion), inside the room.
static func wall_ao(k: Kit, walls: Array, room: Rect2) -> void:
	var d := 0.32 * M
	var c0 := Color(0, 0, 0, 0.2)
	var c1 := Color(0, 0, 0, 0)
	for w in walls:
		var r: Rect2 = w["r"]
		if String(w["style"]) == "bars":
			continue
		# only the sides that face into the building (never out onto the sidewalk)
		var inside := room.grow(1.0)
		if r.size.x >= r.size.y:
			var a := Rect2(r.position.x, r.end.y, r.size.x, d)
			var b := Rect2(r.position.x, r.position.y - d, r.size.x, d)
			if inside.encloses(a):
				k.grad(a, c0, c1, true)
			if inside.encloses(b):
				k.grad(b, c1, c0, true)
		else:
			var a2 := Rect2(r.end.x, r.position.y, d, r.size.y)
			var b2 := Rect2(r.position.x - d, r.position.y, d, r.size.y)
			if inside.encloses(a2):
				k.grad(a2, c0, c1, false)
			if inside.encloses(b2):
				k.grad(b2, c1, c0, false)


static func wall_shadows(k: Kit, walls: Array) -> void:
	for w in walls:
		var r: Rect2 = w["r"]
		if String(w["style"]) == "bars":
			k.shadow(r.grow(-2), 5.0, 0.18)
		else:
			k.shadow(r, 9.0, 0.3)


# ------------------------------------------------------------------ walls

static func walls(k: Kit, list: Array, s: int) -> void:
	for w in list:
		var r: Rect2 = w["r"]
		match String(w["style"]):
			"bars": _bars(k, r)
			"glass_wall": _glass_wall(k, r)
			"in": _wall(k, r, _cap_in(), Pal.PLASTER, s)
			_: _wall(k, r, _cap_out(), Pal.BRICK, s)


static func _wall(k: Kit, r: Rect2, cap: Color, face: Color, s: int) -> void:
	k.rect(r, cap)
	var horiz := r.size.x >= r.size.y
	# the plaster faces either side (a thin light line), a darker core line on top
	var e := 1.5
	if horiz:
		k.rect(Rect2(r.position.x, r.position.y, r.size.x, e), face.darkened(0.1) if k.lit.y > 0 else face.lightened(0.05))
		k.rect(Rect2(r.position.x, r.end.y - e, r.size.x, e), face.darkened(0.1) if k.lit.y < 0 else face.lightened(0.05))
		k.rect(Rect2(r.position.x, r.position.y + r.size.y * 0.42, r.size.x, 1.0), cap.darkened(0.3))
	else:
		k.rect(Rect2(r.position.x, r.position.y, e, r.size.y), face.darkened(0.1) if k.lit.x > 0 else face.lightened(0.05))
		k.rect(Rect2(r.end.x - e, r.position.y, e, r.size.y), face.darkened(0.1) if k.lit.x < 0 else face.lightened(0.05))
		k.rect(Rect2(r.position.x + r.size.x * 0.42, r.position.y, 1.0, r.size.y), cap.darkened(0.3))
	# a hint of brick coursing on the outer walls
	if cap == _cap_out():
		var segs := PackedVector2Array()
		var step := 0.24 * M
		var t := 0.0
		var len := r.size.x if horiz else r.size.y
		var n := 0
		while t < len:
			var off := (step * 0.5) if n % 2 == 0 else 0.0
			if horiz:
				segs.append(Vector2(r.position.x + t + off, r.position.y + 2))
				segs.append(Vector2(r.position.x + t + off, r.end.y - 2))
			else:
				segs.append(Vector2(r.position.x + 2, r.position.y + t + off))
				segs.append(Vector2(r.end.x - 2, r.position.y + t + off))
			t += step
			n += 1
		k.lines(segs, Color(cap.lightened(0.12), 0.5), 1.0)
	var _unused := s


static func _bars(k: Kit, r: Rect2) -> void:
	var horiz := r.size.x >= r.size.y
	var iron := Pal.MANHOLE.lightened(0.12)
	var len := r.size.x if horiz else r.size.y
	# top and bottom rails, a bar every 11 cm
	if horiz:
		var yc := r.get_center().y
		k.rect(Rect2(r.position.x, yc - 2.5, r.size.x, 5.0), Color(iron, 0.5))
		k.line(Vector2(r.position.x, yc - 3.5), Vector2(r.end.x, yc - 3.5), iron.lightened(0.15), 2.0)
		k.line(Vector2(r.position.x, yc + 3.5), Vector2(r.end.x, yc + 3.5), iron.darkened(0.2), 2.0)
		var t := 3.0
		while t < len - 2.0:
			k.disc(Vector2(r.position.x + t, yc), 2.1, iron)
			k.disc(Vector2(r.position.x + t - 0.6, yc - 0.6), 0.9, iron.lightened(0.4))
			t += 0.11 * M
	else:
		var xc := r.get_center().x
		k.rect(Rect2(xc - 2.5, r.position.y, 5.0, r.size.y), Color(iron, 0.5))
		k.line(Vector2(xc - 3.5, r.position.y), Vector2(xc - 3.5, r.end.y), iron.lightened(0.15), 2.0)
		k.line(Vector2(xc + 3.5, r.position.y), Vector2(xc + 3.5, r.end.y), iron.darkened(0.2), 2.0)
		var t2 := 3.0
		while t2 < len - 2.0:
			k.disc(Vector2(xc, r.position.y + t2), 2.1, iron)
			k.disc(Vector2(xc - 0.6, r.position.y + t2 - 0.6), 0.9, iron.lightened(0.4))
			t2 += 0.11 * M


static func _glass_wall(k: Kit, r: Rect2) -> void:
	var wood := Pal.COUNTER.lightened(0.12)
	k.rect(r, wood)
	var horiz := r.size.x >= r.size.y
	var inner := r.grow(-3.0)
	k.glass(inner, Pal.GLASS, 0.7)
	# mullions every 0.9 m
	var len := r.size.x if horiz else r.size.y
	var t := 0.9 * M
	while t < len - 6:
		if horiz:
			k.rect(Rect2(r.position.x + t - 1.5, r.position.y, 3.0, r.size.y), wood)
		else:
			k.rect(Rect2(r.position.x, r.position.y + t - 1.5, r.size.x, 3.0), wood)
		t += 0.9 * M
	k.ci.draw_rect(r, wood.darkened(0.35), false, 1.0)


## Glass and loading doors set into the outer walls. `broken` has the item ids smashed.
static func openings(k: Kit, list: Array, broken: Array, s: int) -> void:
	for o in list:
		var r: Rect2 = o["r"]
		match String(o["style"]):
			"loading": _loading_door(k, r)
			_:
				var smashed: bool = o.has("item") and broken.has(int(o["item"]))
				_window(k, r, smashed, s + int(o.get("item", 0)) * 17)


static func _window(k: Kit, r: Rect2, smashed: bool, s: int) -> void:
	var frame := Pal.COUNTER.darkened(0.1)
	var horiz := r.size.x >= r.size.y
	k.rect(r, frame)
	var g := r.grow(-2.5) if horiz else r.grow(-2.5)
	if not smashed:
		k.rect(g, Pal.GLASS.darkened(0.08))
		# the glint and the sash bars
		var len := r.size.x if horiz else r.size.y
		var step := 0.75 * M
		var t := step
		while t < len - 8.0:
			if horiz:
				k.rect(Rect2(r.position.x + t - 1.0, r.position.y, 2.0, r.size.y), frame)
			else:
				k.rect(Rect2(r.position.x, r.position.y + t - 1.0, r.size.x, 2.0), frame)
			t += step
		if horiz:
			k.rect(Rect2(g.position.x, g.position.y + g.size.y * 0.35, g.size.x, 1.5), Color(1, 1, 1, 0.45))
		else:
			k.rect(Rect2(g.position.x + g.size.x * 0.35, g.position.y, 1.5, g.size.y), Color(1, 1, 1, 0.45))
	else:
		k.rect(g, Pal.SIGN_BLACK.lightened(0.05))
		# jagged teeth of glass left in the frame
		var len2 := r.size.x if horiz else r.size.y
		var n := int(len2 / 7.0)
		for j in n:
			var a := j * len2 / n
			var b := (j + 1) * len2 / n
			var tip := 2.5 + k.h(j, 1, s) * (g.size.y if horiz else g.size.x) * 0.8
			var pts: PackedVector2Array
			if horiz:
				var edge := g.position.y if j % 2 == 0 else g.end.y
				var dir := 1.0 if j % 2 == 0 else -1.0
				pts = PackedVector2Array([Vector2(r.position.x + a, edge), Vector2(r.position.x + b, edge), Vector2(r.position.x + (a + b) * 0.5 + (k.h(j, 2, s) - 0.5) * 4.0, edge + dir * tip)])
			else:
				var edge2 := g.position.x if j % 2 == 0 else g.end.x
				var dir2 := 1.0 if j % 2 == 0 else -1.0
				pts = PackedVector2Array([Vector2(edge2, r.position.y + a), Vector2(edge2, r.position.y + b), Vector2(edge2 + dir2 * tip, r.position.y + (a + b) * 0.5)])
			k.ci.draw_colored_polygon(pts, Color(Pal.GLASS.lightened(0.25), 0.8))
	k.ci.draw_rect(r, frame.darkened(0.4), false, 1.0)


static func _loading_door(k: Kit, r: Rect2) -> void:
	var steel := Pal.RUST.lerp(Pal.ASPHALT, 0.55)
	k.rect(r, steel)
	var horiz := r.size.x >= r.size.y
	var len := r.size.x if horiz else r.size.y
	var segs := PackedVector2Array()
	var t := 3.0
	while t < len:
		if horiz:
			segs.append(Vector2(r.position.x + t, r.position.y + 1))
			segs.append(Vector2(r.position.x + t, r.end.y - 1))
		else:
			segs.append(Vector2(r.position.x + 1, r.position.y + t))
			segs.append(Vector2(r.end.x - 1, r.position.y + t))
		t += 4.0
	k.lines(segs, steel.darkened(0.3), 1.0)
	k.ci.draw_rect(r, Pal.SIGN_GOLD.darkened(0.3), false, 1.5)


## Door frames, thresholds and the door leaves standing open.
static func doors(k: Kit, list: Array, wt: float) -> void:
	for d in list:
		var p: Vector2 = d["p"]
		var w := float(d["w"])
		var along: Vector2 = d["along"]
		var out: Vector2 = d["out"]
		var kind := String(d["kind"])
		var across := Vector2(-along.y, along.x)
		var half := along * w * 0.5
		var jamb := Pal.COUNTER.darkened(0.15)
		# threshold across the gap
		var th := PackedVector2Array([p - half - across * wt * 0.5, p + half - across * wt * 0.5, p + half + across * wt * 0.5, p - half + across * wt * 0.5])
		k.poly(th, Pal.COUNTER.lightened(0.18) if kind != "cell" else Pal.MANHOLE.lightened(0.25))
		# jambs: small posts at both ends
		for sgn: float in [-1.0, 1.0]:
			var c: Vector2 = p + along * (w * 0.5 + 2.0) * sgn
			var jr := PackedVector2Array([c - along * 3.0 - across * wt * 0.62, c + along * 3.0 - across * wt * 0.62, c + along * 3.0 + across * wt * 0.62, c - along * 3.0 + across * wt * 0.62])
			k.poly(jr, jamb if kind != "cell" else Pal.MANHOLE)
		# the leaf, open against the frame, on the room side (away from `out`)
		var inward := -out
		if kind == "front":
			for sgn2: float in [-1.0, 1.0]:
				var hinge: Vector2 = p + along * (w * 0.5 - 1.5) * sgn2 + inward * wt * 0.5
				var leaf_len := w * 0.5 - 1.0
				_leaf(k, hinge, inward, leaf_len, along * -sgn2, false)
		elif kind == "cell":
			var hinge2 := p + along * (w * 0.5 - 1.0) + out * wt * 0.5
			_leaf(k, hinge2, out, w - 2.0, -along, true)
		else:
			var hinge3 := p - along * (w * 0.5 - 1.5) + inward * wt * 0.5
			_leaf(k, hinge3, inward, w - 3.0, along, false)


static func _leaf(k: Kit, hinge: Vector2, dir: Vector2, len: float, _side: Vector2, bars: bool) -> void:
	var th := 4.0
	var side := Vector2(-dir.y, dir.x)
	var a := hinge
	var b := hinge + dir * len
	var pts := PackedVector2Array([a - side * th * 0.5, b - side * th * 0.5, b + side * th * 0.5, a + side * th * 0.5])
	k.shadow_poly(pts, 3.0, 0.3)
	if bars:
		var iron := Pal.MANHOLE.lightened(0.12)
		k.line(a, b, iron, 3.0)
		var t := 4.0
		while t < len:
			k.disc(a + dir * t, 1.8, iron.lightened(0.1))
			t += 0.11 * M
	else:
		var wood := Pal.COUNTER.lightened(0.05)
		k.poly(pts, wood)
		k.line(a + side * th * 0.3, b + side * th * 0.3, wood.lightened(0.2), 1.0)
		k.disc(b - dir * 5.0 + side * 3.0, 1.4, Pal.BRASS)


# ------------------------------------------------------------------ rugs and mats

static func rug(k: Kit, r: Rect2, style: String, s: int) -> void:
	var base: Color
	var border: Color
	var accent: Color
	match style:
		"club":
			base = Pal.LEATHER.darkened(0.05)
			border = Pal.FLOOR_TILE_2.darkened(0.25)
			accent = Pal.SIGN_GOLD.darkened(0.2)
		"speak":
			base = Pal.FLOOR_TILE_2.darkened(0.2)
			border = Pal.AWNING_COLORS[4].darkened(0.1)
			accent = Pal.GOLD.darkened(0.15)
		_:
			base = Pal.FLOOR_TILE_2.darkened(0.08)
			border = Pal.AWNING_COLORS[2].darkened(0.1)
			accent = Pal.AWNING_CREAM.darkened(0.15)
	k.shadow(r, 1.5, 0.18)
	k.rect(r, border)
	var inner := r.grow(-0.14 * M)
	k.rect(inner, base)
	k.ci.draw_rect(r.grow(-0.07 * M), accent, false, 1.5)
	k.ci.draw_rect(inner.grow(-0.08 * M), Color(accent, 0.7), false, 1.0)
	# the medallion and a scatter of motifs
	var c := inner.get_center()
	var md := minf(inner.size.x, inner.size.y) * 0.28
	var dia := PackedVector2Array([c + Vector2(0, -md), c + Vector2(md * 1.3, 0), c + Vector2(0, md), c + Vector2(-md * 1.3, 0)])
	k.poly(dia, border.lightened(0.05))
	k.pline(Kit._closed(dia), accent, 1.0)
	k.disc(c, md * 0.3, accent.darkened(0.1))
	var n := int(inner.size.x / (0.45 * M))
	for j in n:
		for i in 2:
			var q := Vector2(inner.position.x + (j + 0.5) * inner.size.x / n, inner.position.y + inner.size.y * (0.18 if i == 0 else 0.82))
			k.disc(q, 2.0, Color(accent, 0.6))
	# fringe on the short ends
	var fr := PackedVector2Array()
	var horiz := r.size.x >= r.size.y
	var len := r.size.y if horiz else r.size.x
	var t := 1.5
	while t < len:
		if horiz:
			fr.append_array([Vector2(r.position.x, r.position.y + t), Vector2(r.position.x - 4, r.position.y + t), Vector2(r.end.x, r.position.y + t), Vector2(r.end.x + 4, r.position.y + t)])
		else:
			fr.append_array([Vector2(r.position.x + t, r.position.y), Vector2(r.position.x + t, r.position.y - 4), Vector2(r.position.x + t, r.end.y), Vector2(r.position.x + t, r.end.y + 4)])
		t += 3.0
	k.lines(fr, Pal.AWNING_CREAM.darkened(0.1), 1.0)
	var _unused := s


static func doormat(k: Kit, r: Rect2) -> void:
	var c := Pal.ROPE.darkened(0.25)
	k.rect(r, c)
	var segs := PackedVector2Array()
	var t := 2.0
	while t < r.size.x:
		segs.append(Vector2(r.position.x + t, r.position.y + 2))
		segs.append(Vector2(r.position.x + t, r.end.y - 2))
		t += 3.0
	k.lines(segs, c.darkened(0.25), 1.0)
	k.ci.draw_rect(r, c.darkened(0.4), false, 1.5)
