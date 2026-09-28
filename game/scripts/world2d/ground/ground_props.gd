class_name GroundProps
extends RefCounted
## Draws the street furniture from above: lamp posts (bishop's crook, with street-name blades at
## the corners), hydrants, mailboxes, police call boxes, fire alarm boxes, ash cans, benches,
## newsstands, trees, hitching posts, the horse trough, wire baskets, bicycles and the pushcarts.
## Four passes, each in its own node: shadows, bodies (furniture z), high parts (lamp heads, tree
## crowns, umbrellas: over people) and the night glow.
##
## Each prop is drawn in a local frame: +x runs along the curb, +y points out to the street.

const M := W.M
const IRON := Color("24272a")
const IRON_HI := Color("4c5055")
const HYDRANT := Color("8e3a30")
const MAIL := Color("35523f")
const NAVY := Color("2f3f62")
const ALARM := Color("98382d")
const GALV := Color("8d8f8c")
const WOOD := Color("8a6b4a")
const LEAF := Color("2f5a3a")

var lay: GroundLayout
var grain: Texture2D


func _init(layout: GroundLayout) -> void:
	lay = layout
	grain = GroundTex.grain()


func _begin(ci: CanvasItem, p: Dictionary, off: Vector2 = Vector2.ZERO) -> Vector2:
	ci.draw_set_transform(p["p"] + off, float(p["rot"]), Vector2.ONE)
	return GroundUtil.LIGHT_DIR.rotated(-float(p["rot"]))


func _end(ci: CanvasItem) -> void:
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _out(p: Dictionary) -> Vector2:
	return Vector2(0, 1).rotated(float(p["rot"]))


func _along(p: Dictionary) -> Vector2:
	return Vector2(1, 0).rotated(float(p["rot"]))


static func _c(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	ci.draw_circle(c, r, col, true, -1.0, true)


# ================================================================== passes

func paint_shadows(ci: CanvasItem, props: Array) -> void:
	for p in props:
		match p["t"]:
			"lamp": _lamp_shadow(ci, p)
			"hydrant": _round_shadow(ci, p, 0.16, 0.45)
			"mailbox": _box_shadow(ci, p, Vector2(0.5, 0.42), 0.75)
			"callbox": _post_box_shadow(ci, p, 1.55, Vector2(0.3, 0.26))
			"alarm": _post_box_shadow(ci, p, 1.8, Vector2(0.26, 0.24))
			"ashcans": _cans_shadow(ci, p)
			"bench": _box_shadow(ci, p, Vector2(1.7, 0.5), 0.45)
			"newsstand": _box_shadow(ci, p, Vector2(2.0, 0.9), 1.4)
			"tree": _tree_shadow(ci, p)
			"trough": _box_shadow(ci, p, Vector2(2.25, 0.7), 0.35)
			"hitch": GroundUtil.shadow_pole(ci, p["p"], 1.0, 3.0)
			"basket": _round_shadow(ci, p, 0.2, 0.45)
			"bike": _bike(ci, p, true)
			"pushcart": _cart_shadow(ci, p)
			"sign": _sign_shadow(ci, p)
			"pole":
				GroundUtil.shadow_circle(ci, p["p"], 0.15 * M, GroundUtil.sh(0.2))
				GroundUtil.shadow_pole(ci, p["p"], 6.5, 4.0)


func paint_bodies(ci: CanvasItem, props: Array) -> void:
	for p in props:
		match p["t"]:
			"lamp": _lamp_base(ci, p)
			"hydrant": _hydrant(ci, p)
			"mailbox": _mailbox(ci, p)
			"callbox": _callbox(ci, p)
			"alarm": _alarm(ci, p)
			"ashcans": _ashcans(ci, p)
			"bench": _bench(ci, p)
			"newsstand": _newsstand(ci, p)
			"tree": _tree_guard(ci, p)
			"trough": _trough(ci, p)
			"hitch": _hitch(ci, p)
			"basket": _basket(ci, p)
			"bike": _bike(ci, p, false)
			"pushcart": _pushcart(ci, p)
			"sign":
				_c(ci, p["p"], 0.07 * M, IRON)
				_c(ci, (p["p"] as Vector2) + GroundUtil.LIGHT_DIR, 0.04 * M, IRON_HI)
			"pole": _pole(ci, p)


func paint_high(ci: CanvasItem, props: Array) -> void:
	for p in props:
		match p["t"]:
			"lamp": _lamp_head(ci, p)
			"tree": _canopy(ci, p)
			"pushcart":
				if p["umbrella"]:
					_umbrella(ci, p)
			"sign": _signs(ci, p)


func paint_glow(ci: CanvasItem, props: Array) -> void:
	for p in props:
		match p["t"]:
			"lamp": _lamp_glow(ci, p)
			"alarm":
				var c: Vector2 = p["p"]
				GroundUtil.soft(ci, c, Vector2(0.45, 0.45) * M, Color(1.0, 0.35, 0.25, 0.4), 0.0, 3)
				_c(ci, c, 0.075 * M, Color(1.0, 0.55, 0.45))
			"callbox":
				var c2: Vector2 = p["p"]
				GroundUtil.soft(ci, c2, Vector2(0.3, 0.3) * M, Color(0.7, 0.8, 1.0, 0.3), 0.0, 3)
			"newsstand":
				var b := (p["p"] as Vector2) - _out(p) * 0.3 * M
				GroundUtil.soft(ci, b, Vector2(0.9, 0.9) * M, Color(Pal.WINDOW_WARM, 0.35), 0.0, 4)
				_c(ci, b, 0.06 * M, Color(1.0, 0.95, 0.8))


# ================================================================== shadows

func _round_shadow(ci: CanvasItem, p: Dictionary, r: float, h: float) -> void:
	GroundUtil.shadow_circle(ci, p["p"], r * M, GroundUtil.sh(h))


func _box_shadow(ci: CanvasItem, p: Dictionary, size: Vector2, h: float) -> void:
	var pts := GroundUtil.orect(p["p"], size * M, float(p["rot"]))
	GroundUtil.shadow_poly(ci, pts, GroundUtil.sh(h))


func _post_box_shadow(ci: CanvasItem, p: Dictionary, h: float, box: Vector2) -> void:
	GroundUtil.shadow_pole(ci, p["p"], h - 0.3, 3.5)
	var pts := GroundUtil.orect(p["p"], box * M, float(p["rot"]))
	GroundUtil.shadow_poly(ci, pts, GroundUtil.sh(h - 0.15))


func _lamp_shadow(ci: CanvasItem, p: Dictionary) -> void:
	var base: Vector2 = p["p"]
	var head: Vector2 = p["head"]
	GroundUtil.shadow_circle(ci, base, 0.17 * M, GroundUtil.sh(0.15))
	GroundUtil.shadow_pole(ci, base, 3.9, 3.4)
	var o := GroundUtil.sh(4.1)
	var col := Color(GroundUtil.SH, GroundUtil.SH.a * 1.1)
	ci.draw_line(base + o, head + o, col, 2.6, true)
	GroundUtil.shadow_circle(ci, head, 0.2 * M, GroundUtil.sh(3.85))


func _cans_shadow(ci: CanvasItem, p: Dictionary) -> void:
	var n: int = p.get("n", 1)
	for k in n:
		var c := (p["p"] as Vector2) + _along(p) * (float(k) - float(n - 1) * 0.5) * 0.52 * M
		GroundUtil.shadow_circle(ci, c, 0.24 * M, GroundUtil.sh(0.4))


func _tree_shadow(ci: CanvasItem, p: Dictionary) -> void:
	var base: Vector2 = p["p"]
	GroundUtil.shadow_pole(ci, base, 2.6, 5.0)
	var cc := base + _out(p) * 0.15 * M + GroundUtil.sh(4.6)
	var R := _crown_r(p)
	var s: int = p["s"]
	# dappled: a few overlapping lobes
	ci.draw_colored_polygon(GroundUtil.blob(cc, R * 0.9, s, 14, 0.2), Color(GroundUtil.SH, 0.2))
	for k in 5:
		var a := TAU * float(k) / 5.0 + GroundUtil.r01(s, 3)
		ci.draw_colored_polygon(GroundUtil.blob(cc + Vector2(cos(a), sin(a)) * R * 0.4, R * 0.45, s + k, 10, 0.25), Color(GroundUtil.SH, 0.1))


func _cart_shadow(ci: CanvasItem, p: Dictionary) -> void:
	var rot := float(p["rot"])
	var c: Vector2 = (p["p"] as Vector2) + Vector2(0.45 * M, 0).rotated(rot)
	GroundUtil.shadow_poly(ci, GroundUtil.orect(c, Vector2(1.95, 1.0) * M, rot), GroundUtil.sh(0.55))
	if p["umbrella"]:
		var o := GroundUtil.sh(2.1)
		ci.draw_colored_polygon(Draw.ellipse_points(c + o, Vector2(0.88, 0.88) * M, 0.0, 24), Color(GroundUtil.SH, 0.3))


# ================================================================== lamp

func _lamp_base(ci: CanvasItem, p: Dictionary) -> void:
	var L := _begin(ci, p)
	_c(ci, Vector2.ZERO, 0.17 * M, IRON.darkened(0.2))
	_c(ci, L * 1.2, 0.14 * M, IRON)
	# fluted octagonal base catching the light
	for k in 8:
		var a := TAU * float(k) / 8.0
		var q := Vector2(cos(a), sin(a)) * 0.12 * M
		var lit := Vector2(cos(a), sin(a)).dot(L)
		_c(ci, q, 1.3, Color(0.8, 0.8, 0.85, 0.2 * maxf(lit, 0.0)))
	_c(ci, Vector2.ZERO, 0.075 * M, IRON_HI)
	_c(ci, L * 1.0, 0.04 * M, Color("6a6f75"))
	_end(ci)


func _lamp_head(ci: CanvasItem, p: Dictionary) -> void:
	var L := _begin(ci, p)
	var hy := 1.12 * M
	# the crook: up the post, arching out over the gutter, with a scroll at the post
	var arm := PackedVector2Array()
	for k in 9:
		var t := float(k) / 8.0
		arm.append(Vector2(sin(t * PI) * 0.07 * M, t * (hy - 0.14 * M)))
	ci.draw_polyline(arm, IRON, 3.0, true)
	ci.draw_polyline(_shift(arm, L * 0.9), Color(0.7, 0.72, 0.76, 0.3), 1.0, true)
	ci.draw_arc(Vector2(-0.06 * M, 0.2 * M), 0.07 * M, -PI * 0.5, PI * 1.2, 10, IRON, 2.0, true)
	_c(ci, Vector2.ZERO, 0.06 * M, IRON_HI)
	# the lamp: a milky glass globe, shaded like a ball lit from the north-west, a small finial
	var h := Vector2(0, hy)
	_c(ci, h, 0.25 * M, Color("2a2c2e"))
	_c(ci, h, 0.225 * M, Color("a59d88"))
	_c(ci, h - L * 0.03 * M, 0.2 * M, Color("c4bca6"))
	_c(ci, h + L * 0.06 * M, 0.14 * M, Color("dcd5c2"))
	_c(ci, h + L * 0.1 * M, 0.06 * M, Color(1, 1, 1, 0.7))
	_c(ci, h, 0.045 * M, IRON)
	_end(ci)


## Street-name blades on the corner post: one along each street, reaching in from the corner.
func _signs(ci: CanvasItem, p: Dictionary) -> void:
	var names: Array = p["names"]
	var base: Vector2 = p["p"]
	var inward: Vector2 = p["in"]
	var f := W.font("cond")
	var len := 1.55 * M
	var th := 0.32 * M
	for k in 2:
		var vertical := k == 0          # the north-south street's name runs north-south
		var dir := Vector2(0, inward.y) if vertical else Vector2(inward.x, 0)
		var c := base + dir * (len * 0.5 + 0.02 * M)
		var rot := PI * 0.5 if vertical else 0.0
		ci.draw_set_transform(c, rot, Vector2.ONE)
		var r := Rect2(-len * 0.5, -th * 0.5, len, th)
		Draw.rrect(ci, r, 2.5, Color("1a2533"))
		ci.draw_rect(r.grow(-2.0), Color(Pal.AWNING_CREAM, 0.45), false, 1.0, true)
		var txt: String = names[k]
		var fs := 13
		var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		while tw > len - 10.0 and fs > 8:
			fs -= 1
			tw = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		# vertical blades read bottom to top
		if vertical:
			ci.draw_set_transform(c, -PI * 0.5, Vector2.ONE)
		ci.draw_string(f, Vector2(-tw * 0.5, fs * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Pal.AWNING_CREAM)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_c(ci, base, 0.06 * M, IRON)
	_c(ci, base + GroundUtil.LIGHT_DIR, 0.035 * M, IRON_HI)


func _sign_shadow(ci: CanvasItem, p: Dictionary) -> void:
	var base: Vector2 = p["p"]
	var inward: Vector2 = p["in"]
	var o := GroundUtil.sh(2.5)
	GroundUtil.shadow_pole(ci, base, 2.5, 3.0, 0.8)
	var len := 1.55 * M
	for dir: Vector2 in [Vector2(0, inward.y), Vector2(inward.x, 0)]:
		var c := base + dir * len * 0.5
		var sz := Vector2(len, 0.32 * M) if dir.y == 0.0 else Vector2(0.32 * M, len)
		ci.draw_rect(Rect2(c + o - sz * 0.5, sz), Color(GroundUtil.SH, 0.16))


func _lamp_glow(ci: CanvasItem, p: Dictionary) -> void:
	var h: Vector2 = p["head"]
	GroundUtil.soft(ci, h, Vector2(1.0, 1.0) * M, Color(Pal.LAMP, 0.32), 0.0, 4)
	_c(ci, h, 0.32 * M, Color(Pal.LAMP, 0.45))
	_c(ci, h, 0.24 * M, Color(1.0, 0.86, 0.62))
	_c(ci, h + GroundUtil.LIGHT_DIR * 0.06 * M, 0.16 * M, Color(1.0, 0.96, 0.85))
	_c(ci, h, 0.11 * M, Color("2a2622"))
	_c(ci, h, 0.04 * M, Color("6a5a48"))


## A steel trolley pole at the Bowery curb: a flared base, the tapering pole, a finial.
func _pole(ci: CanvasItem, p: Dictionary) -> void:
	var c: Vector2 = p["p"]
	var L := GroundUtil.LIGHT_DIR
	_c(ci, c, 0.17 * M, Color("1c2420"))
	_c(ci, c + L * 1.2, 0.14 * M, Color("2c3a32"))
	ci.draw_arc(c, 0.12 * M, 0.0, TAU, 16, Color(0, 0, 0, 0.35), 1.2, true)
	_c(ci, c, 0.085 * M, Color("33443a"))
	_c(ci, c + L * 1.0, 0.045 * M, Color("6a7a70"))


# ================================================================== small street furniture

func _hydrant(ci: CanvasItem, p: Dictionary) -> void:
	var L := _begin(ci, p)
	var col := HYDRANT.lightened(GroundUtil.rr(int(p["s"]), 1, -0.05, 0.08))
	# side outlets along the curb, the big pumper outlet toward the street
	for sx: float in [-1.0, 1.0]:
		ci.draw_rect(Rect2(Vector2(sx * 0.13 * M - (0.1 * M if sx < 0.0 else 0.0), -0.045 * M), Vector2(0.1 * M, 0.09 * M)), col.darkened(0.2))
		_c(ci, Vector2(sx * 0.23 * M, 0), 0.05 * M, Color("b8b0a0"))
	ci.draw_rect(Rect2(-0.06 * M, 0.08 * M, 0.12 * M, 0.12 * M), col.darkened(0.2))
	_c(ci, Vector2(0, 0.2 * M), 0.07 * M, Color("b8b0a0"))
	_c(ci, Vector2.ZERO, 0.2 * M, col.darkened(0.35))
	_c(ci, Vector2.ZERO, 0.165 * M, col)
	_c(ci, L * 2.2, 0.1 * M, col.lightened(0.18))
	_c(ci, Vector2.ZERO, 0.055 * M, Color("c9c0ae"))
	_c(ci, L * 0.8, 0.02 * M, Color(1, 1, 1, 0.6))
	_end(ci)


func _mailbox(ci: CanvasItem, p: Dictionary) -> void:
	var L := _begin(ci, p)
	var r := Rect2(-0.25 * M, -0.2 * M, 0.5 * M, 0.4 * M)
	Draw.rrect(ci, r, 0.06 * M, MAIL.darkened(0.2))
	Draw.rrect(ci, r.grow(-1.5), 0.05 * M, MAIL)
	# the rounded top: a highlight running along it, toward the light
	var hy := -0.05 * M if L.y < 0.0 else 0.05 * M
	ci.draw_rect(Rect2(r.position.x + 3.0, hy - 0.05 * M, r.size.x - 6.0, 0.1 * M), MAIL.lightened(0.18))
	ci.draw_rect(Rect2(r.position.x + 3.0, hy - 0.015 * M, r.size.x - 6.0, 0.03 * M), MAIL.lightened(0.35))
	# the pull-down slot on the walking side, a small cream eagle plate
	ci.draw_rect(Rect2(-0.12 * M, -0.2 * M, 0.24 * M, 0.035 * M), Color("1a1c1a"))
	Draw.rrect(ci, Rect2(-0.07 * M, 0.06 * M, 0.14 * M, 0.08 * M), 2.0, Color("d9cfb2"))
	_end(ci)


func _callbox(ci: CanvasItem, p: Dictionary) -> void:
	var L := _begin(ci, p)
	var r := Rect2(-0.15 * M, -0.13 * M, 0.3 * M, 0.26 * M)
	Draw.rrect(ci, r, 2.0, NAVY.darkened(0.25))
	Draw.rrect(ci, r.grow(-1.5), 2.0, NAVY)
	ci.draw_rect(Rect2(r.position + Vector2(2, 2), Vector2(r.size.x - 4, 2.0)), Color(1, 1, 1, 0.18))
	# the little lamp on top, and a brass plate
	_c(ci, Vector2(0, 0), 0.075 * M, Color("1b2233"))
	_c(ci, Vector2(0, 0), 0.058 * M, Color("c8d0d8"))
	_c(ci, L * 1.2, 0.02 * M, Color.WHITE)
	ci.draw_rect(Rect2(-0.06 * M, -0.12 * M, 0.12 * M, 0.03 * M), Pal.BRASS)
	_end(ci)


func _alarm(ci: CanvasItem, p: Dictionary) -> void:
	var L := _begin(ci, p)
	var r := Rect2(-0.13 * M, -0.12 * M, 0.26 * M, 0.24 * M)
	Draw.rrect(ci, r, 2.0, ALARM.darkened(0.3))
	Draw.rrect(ci, r.grow(-1.5), 2.0, ALARM)
	ci.draw_rect(Rect2(r.position + Vector2(2, 2), Vector2(r.size.x - 4, 2.0)), Color(1, 1, 1, 0.16))
	# the red globe on top, and the pull handle
	_c(ci, Vector2.ZERO, 0.08 * M, Color("3a1a16"))
	_c(ci, Vector2.ZERO, 0.062 * M, Color("c24a3c"))
	_c(ci, L * 1.2, 0.022 * M, Color(1, 0.8, 0.7, 0.9))
	ci.draw_rect(Rect2(-0.05 * M, -0.12 * M, 0.1 * M, 0.035 * M), Color("d8cfb8"))
	_end(ci)


func _ashcans(ci: CanvasItem, p: Dictionary) -> void:
	var n: int = p.get("n", 1)
	var s: int = p["s"]
	var L := _begin(ci, p)
	for k in n:
		var c := Vector2((float(k) - float(n - 1) * 0.5) * 0.52 * M, GroundUtil.rr(s, 40 + k, -0.04, 0.04) * M)
		var ks := s + k * 7
		var roll := GroundUtil.r01(ks, 1)
		var g := GALV.darkened(GroundUtil.rr(ks, 2, 0.0, 0.25))
		if roll < 0.12 and k == n - 1:
			# knocked over, ash spilling out toward the street
			var rot := GroundUtil.rr(ks, 3, -0.6, 0.6) + PI * 0.5
			GroundUtil.soft_blob(ci, c + Vector2(0, 0.34 * M).rotated(rot - PI * 0.5), 0.26 * M, Color(0.45, 0.43, 0.4, 0.8), ks)
			ci.draw_colored_polygon(GroundUtil.orect(c, Vector2(0.6 * M, 0.44 * M), rot), g.darkened(0.2))
			ci.draw_colored_polygon(GroundUtil.orect(c, Vector2(0.56 * M, 0.36 * M), rot), g)
			for q in 4:
				ci.draw_line(c + Vector2(-0.25 * M + q * 0.16 * M, -0.18 * M).rotated(rot), c + Vector2(-0.25 * M + q * 0.16 * M, 0.18 * M).rotated(rot), Color(0, 0, 0, 0.2), 1.0, true)
			ci.draw_colored_polygon(Draw.ellipse_points(c + Vector2(0.3 * M, 0).rotated(rot), Vector2(0.05, 0.2) * M, rot, 14), Color("2a2826"))
			continue
		_c(ci, c, 0.25 * M, g.darkened(0.35))
		_c(ci, c, 0.23 * M, g)
		if roll < 0.45:
			# lid off: ash and trash inside, the lid leaning on the can
			_c(ci, c, 0.2 * M, Color("3e3b37"))
			_c(ci, c + Vector2(1, 1), 0.17 * M, Color("6b6760"))
			for q in 5:
				var tq := c + Vector2(GroundUtil.rr(ks, 10 + q, -0.12, 0.12), GroundUtil.rr(ks, 20 + q, -0.12, 0.12)) * M
				GroundStreets.litter_bit(ci, tq, ks + q * 3)
			if GroundUtil.r01(ks, 5) < 0.6:
				var lc := c + Vector2(0, 0.3 * M)
				_c(ci, lc, 0.22 * M, g.darkened(0.25))
				_c(ci, lc, 0.19 * M, g.lightened(0.08))
				ci.draw_line(lc - Vector2(0.07 * M, 0), lc + Vector2(0.07 * M, 0), Color("444"), 2.0, true)
		else:
			_c(ci, c, 0.2 * M, g.lightened(0.12))
			ci.draw_arc(c, 0.14 * M, 0.0, TAU, 18, Color(0, 0, 0, 0.18), 1.2, true)
			ci.draw_line(c - Vector2(0.08 * M, 0), c + Vector2(0.08 * M, 0), Color("3c3d3c"), 2.6, true)
			ci.draw_arc(c, 0.21 * M, PI * 1.0, PI * 1.5, 8, Color(1, 1, 1, 0.3), 1.2, true)
		_c(ci, c + L * 0.12 * M, 0.035 * M, Color(1, 1, 1, 0.15))
	_end(ci)


func _bench(ci: CanvasItem, p: Dictionary) -> void:
	var L := _begin(ci, p)
	var hl := 0.85 * M
	# iron ends and a middle leg
	for x: float in [-0.8, 0.0, 0.8]:
		ci.draw_rect(Rect2(float(x) * M - 2.5, -0.26 * M, 5.0, 0.52 * M), IRON)
	var wood := WOOD.lightened(GroundUtil.rr(int(p["s"]), 1, -0.08, 0.06))
	# seat slats (walking side) and the backrest (street side)
	var ys := [-0.24, -0.13, -0.02, 0.09, 0.19]
	for k in ys.size():
		var y := float(ys[k]) * M
		var sl := Rect2(-hl, y, hl * 2.0, 0.085 * M)
		ci.draw_rect(sl, wood.darkened(0.08 * float(k % 2)) if k < 3 else wood.darkened(0.18))
		ci.draw_rect(Rect2(sl.position, Vector2(sl.size.x, 1.0)), Color(1, 1, 1, 0.14))
		ci.draw_rect(Rect2(sl.position + Vector2(0, sl.size.y - 1.0), Vector2(sl.size.x, 1.0)), Color(0, 0, 0, 0.25))
	for x: float in [-0.8, 0.0, 0.8]:
		_c(ci, Vector2(float(x) * M, 0.24 * M), 2.6, IRON_HI)
	_end(ci)


func _newsstand(ci: CanvasItem, p: Dictionary) -> void:
	var L := _begin(ci, p)
	var s: int = p["s"]
	var w := 1.9 * M
	# the papers laid out on the counter on the walking side
	var shelf := Rect2(-w * 0.5 + 3.0, -0.44 * M, w - 6.0, 0.22 * M)
	ci.draw_rect(shelf, Color("5a4632"))
	var x := shelf.position.x + 2.0
	var k := 0
	while x < shelf.end.x - 10.0:
		k += 1
		var pw := GroundUtil.rr(s, k, 9.0, 12.0)
		var pr := Rect2(x, shelf.position.y + 1.5 + GroundUtil.rr(s, 50 + k, 0.0, 1.5), pw, shelf.size.y - 3.5)
		var magazine := GroundUtil.r01(s, 20 + k) < 0.2
		var pc: Color = Pal.AWNING_COLORS[GroundUtil.ri(s, 30 + k, 0, 5)].lightened(0.2) if magazine else Pal.PAPER.darkened(GroundUtil.rr(s, 40 + k, 0.0, 0.12))
		ci.draw_rect(pr, pc)
		if not magazine:
			ci.draw_rect(Rect2(pr.position + Vector2(1.5, 1.5), Vector2(pr.size.x - 3.0, 1.6)), Color(0.1, 0.08, 0.06, 0.8))
			for q in 3:
				ci.draw_rect(Rect2(pr.position + Vector2(1.5, 4.5 + q * 1.8), Vector2(pr.size.x - 3.0 - q * 1.5, 0.8)), Color(0.2, 0.18, 0.15, 0.4))
		x += pw + 1.5
	# the kiosk roof: tin, two slopes, a ridge, ribs
	var roof := Rect2(-w * 0.5, -0.24 * M, w, 0.68 * M)
	var ridge := roof.position.y + roof.size.y * 0.45
	var tin := Pal.AWNING_COLORS[1]
	ci.draw_rect(roof.grow(1.5), tin.darkened(0.4))
	var front_lit := GroundUtil.lit(Vector2(0, -1).rotated(float(p["rot"])))
	ci.draw_rect(Rect2(roof.position, Vector2(roof.size.x, ridge - roof.position.y)), GroundUtil.shade(tin, 0.12 * front_lit))
	ci.draw_rect(Rect2(Vector2(roof.position.x, ridge), Vector2(roof.size.x, roof.end.y - ridge)), GroundUtil.shade(tin, -0.12 * front_lit))
	var rx := roof.position.x + 5.0
	while rx < roof.end.x - 2.0:
		ci.draw_line(Vector2(rx, roof.position.y), Vector2(rx, roof.end.y), Color(0, 0, 0, 0.14), 1.0, true)
		rx += 7.0
	ci.draw_line(Vector2(roof.position.x, ridge), Vector2(roof.end.x, ridge), tin.lightened(0.3), 2.0, true)
	# NEWS painted on the roof, turned to read from the south
	var f := W.font("cond")
	var up := cos(float(p["rot"])) < -0.1
	var tr := Transform2D(PI if up else 0.0, Vector2(0, ridge + (-0.13 * M if up else 0.16 * M)))
	ci.draw_set_transform_matrix(Transform2D(float(p["rot"]), p["p"]) * tr)
	var tw := f.get_string_size("NEWS", HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	ci.draw_string(f, Vector2(-tw * 0.5, 5.0), "NEWS", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Pal.AWNING_CREAM.darkened(0.05))
	_begin(ci, p)
	# bundles of papers tied with string beside it
	if GroundUtil.r01(s, 90) < 0.7:
		var bc := Vector2(w * 0.5 + 0.24 * M, 0.05 * M)
		ci.draw_rect(Rect2(bc - Vector2(0.18, 0.14) * M, Vector2(0.36, 0.28) * M), Pal.PAPER.darkened(0.1))
		ci.draw_line(bc - Vector2(0.18 * M, 0), bc + Vector2(0.18 * M, 0), Color("6a5a40"), 1.2, true)
		ci.draw_line(bc - Vector2(0, 0.14 * M), bc + Vector2(0, 0.14 * M), Color("6a5a40"), 1.2, true)
	_end(ci)


func _crown_r(p: Dictionary) -> float:
	return GroundUtil.rr(int(p["s"]), 5, 1.65, 2.15) * M


func _tree_guard(ci: CanvasItem, p: Dictionary) -> void:
	var L := _begin(ci, p)
	_c(ci, Vector2.ZERO, 0.13 * M, Color("3a2e22"))
	_c(ci, L * 1.5, 0.1 * M, Color("56463a"))
	# a square iron guard around the trunk
	var g := 0.28 * M
	var sq := PackedVector2Array([Vector2(-g, -g), Vector2(g, -g), Vector2(g, g), Vector2(-g, g)])
	GroundUtil.outline(ci, sq, IRON, 2.0)
	for q in sq:
		_c(ci, q, 2.6, IRON_HI)
	_end(ci)


func _canopy(ci: CanvasItem, p: Dictionary) -> void:
	var s: int = p["s"]
	var c: Vector2 = (p["p"] as Vector2) + _out(p) * 0.15 * M
	var R := _crown_r(p)
	var L := GroundUtil.LIGHT_DIR
	var dark := LEAF.darkened(0.42)
	var mid := LEAF.darkened(0.12)
	var hi := LEAF.lightened(0.12)
	var top := LEAF.lightened(0.3)
	ci.draw_colored_polygon(GroundUtil.blob(c, R * 0.95, s, 18, 0.14), Color(dark, 0.95))
	for k in 9:
		var a := TAU * float(k) / 9.0 + GroundUtil.r01(s, 7)
		var q := c + Vector2(cos(a), sin(a)) * R * 0.52
		var lit := Vector2(cos(a), sin(a)).dot(L)
		ci.draw_colored_polygon(GroundUtil.blob(q, R * GroundUtil.rr(s, 10 + k, 0.38, 0.48), s + k, 12, 0.2), mid.lerp(hi, clampf(lit * 0.6 + 0.2, 0.0, 1.0)))
	for k in 6:
		var q := c + L * R * GroundUtil.rr(s, 30 + k, 0.1, 0.45) + Vector2(GroundUtil.rr(s, 40 + k, -0.3, 0.3), GroundUtil.rr(s, 50 + k, -0.3, 0.3)) * R
		ci.draw_colored_polygon(GroundUtil.blob(q, R * GroundUtil.rr(s, 60 + k, 0.18, 0.28), s + 70 + k, 10, 0.25), hi.lerp(top, GroundUtil.r01(s, 80 + k)))
	# leaf texture
	for k in 36:
		var a := GroundUtil.r01(s, 100 + k) * TAU
		var rr := sqrt(GroundUtil.r01(s, 200 + k)) * R * 0.88
		var q := c + Vector2(cos(a), sin(a)) * rr
		var lit := Vector2(cos(a), sin(a)).dot(L) * rr / R
		_c(ci, q, GroundUtil.rr(s, 300 + k, 1.4, 2.6), Color(top, 0.5) if lit > 0.15 else Color(dark, 0.55))
	# the far edge in the crown's own shade
	ci.draw_arc(c, R * 0.86, PI * -0.1, PI * 0.6, 16, Color(0, 0.03, 0.02, 0.25), R * 0.12, true)


func _trough(ci: CanvasItem, p: Dictionary) -> void:
	var L := _begin(ci, p)
	var r := Rect2(-1.1 * M, -0.33 * M, 2.2 * M, 0.66 * M)
	var stone := Pal.PARAPET_STONE.lightened(0.1)
	Draw.rrect(ci, r, 4.0, stone.darkened(0.2))
	Draw.rrect(ci, r.grow(-1.5), 4.0, stone)
	GroundUtil.tex_rect(ci, r, grain, 1.0, Color(1, 1, 1, 0.6))
	ci.draw_rect(Rect2(r.position + Vector2(3, 2), Vector2(r.size.x - 6, 1.5)), Color(1, 1, 1, 0.2))
	var water := r.grow(-0.1 * M)
	ci.draw_rect(water, Color("26343c"))
	Draw.vgrad(ci, water, Color("3e5360"), Color("1c2a31"))
	ci.draw_line(water.position + Vector2(6, 5), water.position + Vector2(water.size.x * 0.4, 5), Color(0.8, 0.85, 0.9, 0.35), 1.4, true)
	ci.draw_rect(water, Color(0.1, 0.1, 0.1, 0.6), false, 1.5, true)
	# the spout post at one end, a dog's bowl at the foot
	_c(ci, Vector2(1.0 * M, 0), 0.1 * M, stone.darkened(0.3))
	_c(ci, Vector2(1.0 * M, 0) + L * 1.2, 0.07 * M, stone.lightened(0.1))
	_c(ci, Vector2(-1.25 * M, 0.1 * M), 0.12 * M, stone.darkened(0.15))
	_c(ci, Vector2(-1.25 * M, 0.1 * M), 0.08 * M, Color("2c3a42"))
	_end(ci)


func _hitch(ci: CanvasItem, p: Dictionary) -> void:
	var L := _begin(ci, p)
	_c(ci, Vector2.ZERO, 0.075 * M, IRON)
	_c(ci, L * 1.2, 0.05 * M, IRON_HI)
	# the ring for the reins and the little horse's head on top
	ci.draw_arc(Vector2(0, 0.1 * M), 0.06 * M, 0.0, TAU, 12, Color("5a5040"), 1.4, true)
	ci.draw_colored_polygon(GroundUtil.orect(Vector2(0.04 * M, -0.02 * M), Vector2(0.12 * M, 0.05 * M), 0.3), IRON_HI)
	_end(ci)


func _basket(ci: CanvasItem, p: Dictionary) -> void:
	var s: int = p["s"]
	var L := _begin(ci, p)
	var r := 0.19 * M
	_c(ci, Vector2.ZERO, r, Color("2d2e2d"))
	_c(ci, Vector2.ZERO, r - 2.0, Color("4a4845"))
	for k in 5:
		GroundStreets.litter_bit(ci, Vector2(GroundUtil.rr(s, k, -0.1, 0.1), GroundUtil.rr(s, 10 + k, -0.1, 0.1)) * M, s + k * 3)
	# the wire mesh over it
	for k in 10:
		var a := TAU * float(k) / 10.0
		ci.draw_line(Vector2(cos(a), sin(a)) * r * 0.2, Vector2(cos(a), sin(a)) * r, Color(0.15, 0.15, 0.15, 0.7), 1.0, true)
	ci.draw_arc(Vector2.ZERO, r - 0.5, 0.0, TAU, 18, Color("5a5a58"), 1.6, true)
	ci.draw_arc(Vector2.ZERO, r - 0.5, PI, PI * 1.5, 8, Color(1, 1, 1, 0.3), 1.2, true)
	_end(ci)


## A delivery bicycle leaning at the curb (a basket on the front).
func _bike(ci: CanvasItem, p: Dictionary, shadow: bool) -> void:
	var off := GroundUtil.sh(0.35) if shadow else Vector2.ZERO
	var L := _begin(ci, p, off)
	var col := Color(GroundUtil.SH, 0.3) if shadow else Color("1c1d1e")
	var tyre := Color(GroundUtil.SH, 0.3) if shadow else Color("121212")
	var wr := 0.34 * M
	for x: float in [-0.55, 0.55]:
		ci.draw_line(Vector2(float(x) * M - wr, 0), Vector2(float(x) * M + wr, 0), tyre, 3.2, true)
	ci.draw_line(Vector2(-0.55 * M, 0), Vector2(0.55 * M, 0), col, 2.2, true)
	ci.draw_line(Vector2(-0.1 * M, 0), Vector2(0.35 * M, 0), col, 3.0, true)
	ci.draw_line(Vector2(0.5 * M, -0.24 * M), Vector2(0.5 * M, 0.24 * M), col, 2.4, true)
	if not shadow:
		Draw.rrect(ci, Rect2(0.62 * M, -0.17 * M, 0.3 * M, 0.34 * M), 2.0, Color("8a7048"))
		for k in 4:
			ci.draw_line(Vector2(0.64 * M, -0.14 * M + k * 0.09 * M), Vector2(0.9 * M, -0.14 * M + k * 0.09 * M), Color(0.3, 0.22, 0.12, 0.6), 1.0, true)
		Draw.ellipse(ci, Vector2(-0.18 * M, 0), Vector2(0.09, 0.05) * M, Color("3a2a1e"))
		_c(ci, Vector2(0.5 * M, -0.24 * M), 2.0, Color("c8b890"))
		_c(ci, Vector2(0.5 * M, 0.24 * M), 2.0, Color("c8b890"))
	_end(ci)


# ================================================================== pushcarts

const FRUIT := [Color("a8352a"), Color("c8782a"), Color("d9b84a"), Color("7a9a3a"), Color("8a2a3a")]


func _pushcart(ci: CanvasItem, p: Dictionary) -> void:
	var s: int = p["s"]
	var L := _begin(ci, p)
	var wood := Color("7a5a3c").lightened(GroundUtil.rr(s, 1, -0.06, 0.08))
	# handles and the cross bar, the wheels at the sides
	for y: float in [-0.3, 0.3]:
		ci.draw_line(Vector2(-0.5 * M, float(y) * M), Vector2(-1.38 * M, float(y) * 0.9 * M), wood.darkened(0.25), 3.4, true)
	ci.draw_line(Vector2(-1.32 * M, -0.3 * M), Vector2(-1.32 * M, 0.3 * M), wood.darkened(0.2), 3.0, true)
	for y: float in [-0.54, 0.54]:
		ci.draw_rect(Rect2(0.0, y * M - 2.6, 0.9 * M, 5.2), Color("231c16"))
		ci.draw_rect(Rect2(0.0, y * M - 2.6, 0.9 * M, 1.3), Color(1, 1, 1, 0.14))
		for q in 4:
			ci.draw_line(Vector2(0.12 * M + q * 0.22 * M, y * M - 2.0), Vector2(0.12 * M + q * 0.22 * M, y * M + 2.0), Color(0.5, 0.42, 0.3, 0.6), 1.0, true)
		_c(ci, Vector2(0.45 * M, y * M), 3.4, Color("5a4a38"))
	if p.get("basket", false):
		_c(ci, Vector2(-0.95 * M, 0), 0.2 * M, Color("6e5530"))
		_c(ci, Vector2(-0.95 * M, 0), 0.16 * M, Color("8a6c3c"))
		for k in 6:
			var a := TAU * float(k) / 6.0
			ci.draw_line(Vector2(-0.95 * M, 0), Vector2(-0.95 * M, 0) + Vector2(cos(a), sin(a)) * 0.16 * M, Color(0.3, 0.22, 0.1, 0.5), 1.0, true)
		_c(ci, Vector2(-0.95 * M, 0), 0.1 * M, FRUIT[GroundUtil.ri(s, 2, 0, 4)])
	# the bed with its raised rim
	var bed := Rect2(-0.5 * M, -0.47 * M, 1.9 * M, 0.94 * M)
	ci.draw_rect(bed, wood.darkened(0.3))
	ci.draw_rect(bed.grow(-2.5), wood)
	var inner := bed.grow(-0.07 * M)
	ci.draw_rect(inner, wood.darkened(0.18))
	ci.draw_rect(Rect2(bed.position, Vector2(bed.size.x, 1.5)), Color(1, 1, 1, 0.15))
	_goods(ci, inner, p["goods"], s, L)
	# price cards stuck in the goods
	for k in GroundUtil.ri(s, 60, 1, 2):
		var pc := inner.position + Vector2(GroundUtil.rr(s, 61 + k, 0.15, 0.85) * inner.size.x, GroundUtil.rr(s, 63 + k, 0.2, 0.8) * inner.size.y)
		var card := GroundUtil.orect(pc, Vector2(0.15, 0.1) * M, GroundUtil.rr(s, 65 + k, -0.3, 0.3))
		ci.draw_colored_polygon(GroundUtil._shift_pts(card, Vector2(1.5, 2.0)), Color(0, 0, 0, 0.3))
		ci.draw_colored_polygon(card, Color("ece4cc"))
		ci.draw_line(pc - Vector2(2.5, 0.5), pc + Vector2(2.5, -0.5), Color(0.15, 0.1, 0.08, 0.8), 1.2, true)
	_end(ci)


func _goods(ci: CanvasItem, r: Rect2, kind: String, s: int, L: Vector2) -> void:
	match kind:
		"fruit", "veg":
			var sections := 3
			var cols := FRUIT if kind == "fruit" else [Color("5e8a3a"), Color("b89a5a"), Color("7a5a3a"), Color("c8702a"), Color("4a7a3a")]
			for k in sections:
				var sr := Rect2(r.position + Vector2(r.size.x * float(k) / sections, 0), Vector2(r.size.x / sections, r.size.y))
				var col: Color = cols[GroundUtil.ri(s, 10 + k, 0, cols.size() - 1)]
				ci.draw_rect(sr.grow(-1.0), col.darkened(0.35))
				var big := kind == "veg" and col.g > col.r
				var rad := 5.5 if big else 3.2
				var step := rad * 1.75
				var row := 0
				var y := sr.position.y + rad
				while y < sr.end.y - rad * 0.5:
					var x := sr.position.x + rad + (step * 0.5 if row % 2 == 1 else 0.0)
					while x < sr.end.x - rad * 0.5:
						var c := col.lightened(GroundUtil.rr(s, int(x * 7.0 + y), -0.1, 0.12))
						_c(ci, Vector2(x, y), rad, c)
						_c(ci, Vector2(x, y) + L * rad * 0.4, rad * 0.35, c.lightened(0.3))
						if big:
							ci.draw_arc(Vector2(x, y), rad * 0.6, 0.0, PI * 1.3, 8, c.darkened(0.3), 0.8, true)
						x += step
					y += step * 0.86
					row += 1
				ci.draw_line(Vector2(sr.end.x, r.position.y), Vector2(sr.end.x, r.end.y), Color("5a4028"), 2.0, true)
		"pots":
			ci.draw_rect(r, Color("5a4a3a"))
			for k in 7:
				var c := r.position + Vector2(GroundUtil.rr(s, 20 + k, 0.1, 0.9) * r.size.x, GroundUtil.rr(s, 30 + k, 0.25, 0.75) * r.size.y)
				var rad := GroundUtil.rr(s, 40 + k, 4.5, 7.5)
				var metal := Color("8e8e8a") if GroundUtil.r01(s, 50 + k) < 0.6 else Color("a0703a")
				ci.draw_line(c, c + Vector2(rad * 1.7, 0).rotated(GroundUtil.r01(s, 60 + k) * TAU), metal.darkened(0.3), 2.0, true)
				_c(ci, c, rad, metal.darkened(0.25))
				_c(ci, c, rad * 0.8, metal)
				ci.draw_arc(c, rad * 0.8, PI, PI * 1.5, 8, Color(1, 1, 1, 0.5), 1.2, true)
		"cloth":
			var x := r.position.x
			var k := 0
			while x < r.end.x - 4.0:
				k += 1
				var w := GroundUtil.rr(s, 70 + k, 7.0, 11.0)
				var col: Color = [Pal.AWNING_COLORS[0], Pal.AWNING_COLORS[2], Pal.AWNING_CREAM, Pal.AWNING_COLORS[1], Pal.AWNING_COLORS[4], Color("9a8a6a")][GroundUtil.ri(s, 80 + k, 0, 5)]
				col = col.lightened(0.12)
				var bolt := Rect2(x, r.position.y + 1.0, minf(w, r.end.x - x), r.size.y - 2.0)
				ci.draw_rect(bolt, col)
				ci.draw_rect(Rect2(bolt.position, Vector2(2.0, bolt.size.y)), col.lightened(0.2))
				ci.draw_rect(Rect2(bolt.end.x - 1.5, bolt.position.y, 1.5, bolt.size.y), col.darkened(0.3))
				x += w + 1.0
		"hats":
			ci.draw_rect(r, Color("4a3a2a"))
			for k in 8:
				var c := r.position + Vector2((float(k % 4) + 0.5) / 4.0 * r.size.x, (float(k / 4) + 0.5) / 2.0 * r.size.y)
				var col: Color = Pal.SUITS[GroundUtil.ri(s, 90 + k, 0, 6)]
				_c(ci, c, 7.0, col.darkened(0.1))
				_c(ci, c, 4.6, col.lightened(0.12))
				ci.draw_arc(c, 4.8, 0.0, TAU, 12, Color("1a1612"), 1.0, true)
		"shoes":
			ci.draw_rect(r, Color("6a5a44"))
			for k in 10:
				var c := r.position + Vector2((float(k % 5) + 0.5) / 5.0 * r.size.x, (float(k / 5) + 0.5) / 2.0 * r.size.y)
				var col := Color("2a1c14") if GroundUtil.r01(s, 100 + k) < 0.6 else Color("5a3420")
				for sx: float in [-2.5, 2.5]:
					Draw.ellipse(ci, c + Vector2(float(sx), 0), Vector2(2.2, 5.0), col)
					_c(ci, c + Vector2(float(sx), -2.5), 1.0, Color(1, 1, 1, 0.3))
		"fish":
			ci.draw_rect(r, Color("c9d2d4"))
			GroundUtil.tex_rect(ci, r, grain, 1.0, Color(1, 1, 1, 0.8))
			for k in 9:
				var c := r.position + Vector2(GroundUtil.rr(s, 110 + k, 0.12, 0.88) * r.size.x, GroundUtil.rr(s, 120 + k, 0.2, 0.8) * r.size.y)
				var rot := GroundUtil.rr(s, 130 + k, -0.4, 0.4)
				Draw.ellipse(ci, c, Vector2(8.0, 2.6), Color("7d8a90"), rot)
				Draw.ellipse(ci, c + Vector2(-0.6, -0.6), Vector2(6.5, 1.3), Color("b8c4c8"), rot)
				var tail := c + Vector2(-9.0, 0).rotated(rot)
				ci.draw_colored_polygon(PackedVector2Array([tail + Vector2(2.5, 0).rotated(rot), tail + Vector2(-2, -2.5).rotated(rot), tail + Vector2(-2, 2.5).rotated(rot)]), Color("6d7a80"))
		"bread":
			ci.draw_rect(r, Color("d8cdb0"))
			for k in 12:
				var c := r.position + Vector2((float(k % 6) + 0.5) / 6.0 * r.size.x, (float(k / 6) + 0.5) / 2.0 * r.size.y)
				if k % 3 == 0:
					Draw.ellipse(ci, c, Vector2(6.0, 3.6), Color("a8743a"), 0.3)
					ci.draw_line(c - Vector2(3, 1), c + Vector2(3, 1), Color("7a4a1a"), 1.0, true)
				else:
					ci.draw_arc(c, 3.6, 0.0, TAU, 12, Color("b8844a"), 2.8, true)
		_:
			ci.draw_rect(r, Color("5a4a3a"))
			for k in 16:
				var c := r.position + Vector2((float(k % 8) + 0.5) / 8.0 * r.size.x, (float(k / 8) + 0.5) / 2.0 * r.size.y)
				var col: Color = [Pal.AWNING_CREAM, Pal.AWNING_COLORS[0], Pal.AWNING_COLORS[2], Pal.BRASS, Pal.AWNING_COLORS[5]][GroundUtil.ri(s, 140 + k, 0, 4)]
				_c(ci, c, 3.4, col.lightened(0.1))
				_c(ci, c, 1.2, col.darkened(0.4))


func _umbrella(ci: CanvasItem, p: Dictionary) -> void:
	var s: int = p["s"]
	var rot := float(p["rot"])
	var c: Vector2 = (p["p"] as Vector2) + Vector2(0.45 * M, 0).rotated(rot)
	var R := 0.88 * M
	var col: Color = Pal.AWNING_COLORS[GroundUtil.ri(s, 150, 0, 5)]
	var n := 8
	var a0 := GroundUtil.r01(s, 151) * TAU
	for k in n:
		var a := a0 + TAU * float(k) / float(n)
		var b := a + TAU / float(n)
		var mid := (a + b) * 0.5
		var lit := Vector2(cos(mid), sin(mid)).dot(GroundUtil.LIGHT_DIR)
		var base := Pal.AWNING_CREAM if k % 2 == 0 else col
		var pts := PackedVector2Array([c])
		for q in 5:
			var t := lerpf(a, b, float(q) / 4.0)
			pts.append(c + Vector2(cos(t), sin(t)) * R)
		ci.draw_colored_polygon(pts, GroundUtil.shade(base, 0.1 * lit))
	var rim := PackedVector2Array()
	for q in 33:
		var t := a0 + TAU * float(q) / 32.0
		rim.append(c + Vector2(cos(t), sin(t)) * R)
	ci.draw_polyline(rim, Color(0, 0, 0, 0.35), 1.5, true)
	for k in n:
		var a := a0 + TAU * float(k) / float(n)
		ci.draw_line(c, c + Vector2(cos(a), sin(a)) * R, Color(0, 0, 0, 0.18), 1.0, true)
	_c(ci, c, 3.2, Color("3a2e24"))
	_c(ci, c + GroundUtil.LIGHT_DIR, 1.4, Color("b8a080"))


static func _shift(pts: PackedVector2Array, o: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in pts:
		out.append(q + o)
	return out
