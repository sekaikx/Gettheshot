extends RefCounted
## Drawing kit for one interior, used by InteriorArt. Draws in the lot's LOCAL frame (x along the
## front, +y out of the front door; the lot node is rotated into the world), but keeps the light
## coming from the world's north-west: shadows always fall down-right on screen, highlights sit on
## the up-left edges, text stays upright.
##
## Objects are drawn in an "object frame" (see obj()): origin at the object's centre, its front
## facing +y, its back against -y. So a counter, a shelf or a piano is drawn once and turns to face
## whichever way the plan says.

const M := W.M
const SH_COL := Color(0.03, 0.02, 0.04)

var ci: CanvasItem
var base_rot := 0.0
var ang := 0.0
var org := Vector2.ZERO
var sh := Vector2(0.5, 0.62)   # shadow offset per pixel of height, current frame
var lit := Vector2(-1, -1)     # toward the light (signs), current frame
var aa := false                # current frame is rotated off the 90-degree grid
var seed := 0


func _init(c: CanvasItem, lot_rot: float, s: int) -> void:
	ci = c
	base_rot = lot_rot
	seed = s
	frame(Vector2.ZERO, 0.0)


## Draw from here on around `p` (lot-local), rotated by `a`.
func frame(p: Vector2, a: float) -> void:
	org = p
	ang = a
	ci.draw_set_transform(p, a)
	var t := -(base_rot + a)
	sh = Vector2(0.5, 0.62).rotated(t)
	var lv := Vector2(-1, -1).rotated(t)
	lit = Vector2(_sgn(lv.x), _sgn(lv.y))
	var q := fposmod(a, PI * 0.5)
	aa = q > 0.01 and q < PI * 0.5 - 0.01


func reset() -> void:
	frame(Vector2.ZERO, 0.0)


static func _sgn(x: float) -> float:
	return 0.0 if absf(x) < 0.2 else signf(x)


## Enter an item's object frame. Returns its size in that frame: x across its front, y front-to-back.
func obj(lr: Rect2, face: Vector2) -> Vector2:
	var diag := absf(face.x) > 0.2 and absf(face.y) > 0.2
	var a := face.angle() - PI * 0.5
	frame(lr.get_center(), a)
	if diag:
		var s := minf(lr.size.x, lr.size.y)
		return Vector2(s, s)
	if absf(face.y) >= absf(face.x):
		return lr.size
	return Vector2(lr.size.y, lr.size.x)


## The screen-up direction in the current frame (for things that must read upright).
func up() -> Vector2:
	return Vector2(0, -1).rotated(-(base_rot + ang))


func h(x: int, y: int, s: int = 0) -> float:
	return Draw.hash01(x, y, seed + s)


# ------------------------------------------------------------------ shapes

func rect(r: Rect2, c: Color) -> void:
	if aa:
		Draw.poly(ci, _rpts(r), c)
	else:
		ci.draw_rect(r, c)


func _rpts(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])


## A soft shadow of a rectangle raised `ht` px, cast down-right.
func shadow(r: Rect2, ht: float, a: float = 0.26) -> void:
	var o := sh * ht
	var g := minf(ht * 0.35, 5.0)
	ci.draw_rect(Rect2(r.position + o - Vector2(g, g) * 0.5, r.size + Vector2(g, g)), Color(SH_COL, a * 0.45))
	ci.draw_rect(Rect2(r.position + o * 0.8, r.size), Color(SH_COL, a * 0.55))


func shadow_disc(c: Vector2, r: float, ht: float, a: float = 0.26) -> void:
	var o := sh * ht
	ci.draw_circle(c + o, r + minf(ht * 0.2, 3.0), Color(SH_COL, a * 0.45), true, -1.0, true)
	ci.draw_circle(c + o * 0.8, r, Color(SH_COL, a * 0.55), true, -1.0, true)


func shadow_poly(pts: PackedVector2Array, ht: float, a: float = 0.26) -> void:
	var o := sh * ht
	var s := PackedVector2Array()
	for q in pts:
		s.append(q + o)
	ci.draw_colored_polygon(s, Color(SH_COL, a * 0.8))


## The up-left edges lit, the down-right edges dark (in whatever frame we're in).
func edges(r: Rect2, c: Color, e: float = 2.0, hi: float = 0.16, lo: float = 0.3) -> void:
	var cl := c.lightened(hi)
	var cd := c.darkened(lo)
	var top := Rect2(r.position, Vector2(r.size.x, e))
	var bot := Rect2(Vector2(r.position.x, r.end.y - e), Vector2(r.size.x, e))
	var lef := Rect2(r.position, Vector2(e, r.size.y))
	var rig := Rect2(Vector2(r.end.x - e, r.position.y), Vector2(e, r.size.y))
	if lit.y < 0:
		rect(top, cl)
		rect(bot, cd)
	elif lit.y > 0:
		rect(top, cd)
		rect(bot, cl)
	if lit.x < 0:
		rect(lef, cl)
		rect(rig, cd)
	elif lit.x > 0:
		rect(lef, cd)
		rect(rig, cl)


## A solid block seen from above: shadow, body, lit and shaded edges.
func box(r: Rect2, c: Color, ht: float = 8.0, e: float = 2.0, shade: bool = true) -> void:
	if shade:
		shadow(r, ht)
	rect(r, c)
	edges(r, c, e)


## A block without its shadow (the shadow pass drew it already).
func top(r: Rect2, c: Color, e: float = 2.0) -> void:
	rect(r, c)
	edges(r, c, e)


func rrect(r: Rect2, rad: float, c: Color) -> void:
	Draw.poly(ci, Draw.rrect_points(r, rad, 3), c)


func rbox(r: Rect2, rad: float, c: Color, ht: float = 6.0) -> void:
	shadow_poly(Draw.rrect_points(r, rad, 3), ht)
	Draw.poly(ci, Draw.rrect_points(r, rad, 3), c)
	var hl := Draw.rrect_points(Rect2(r.position + Vector2(1.5, 1.5) * -lit * -1.0, r.size - Vector2(3, 3)), rad, 3)
	ci.draw_polyline(_closed(hl), c.lightened(0.12), 1.0, true)


static func _closed(p: PackedVector2Array) -> PackedVector2Array:
	var q := p.duplicate()
	if q.size() > 0:
		q.append(q[0])
	return q


func disc(c: Vector2, r: float, col: Color) -> void:
	ci.draw_circle(c, r, col, true, -1.0, true)


## A round thing (a pot, a stool, a barrel) lit from the north-west: shadow, body, a highlight.
func ball(c: Vector2, r: float, col: Color, ht: float = 5.0, gloss: float = 0.22) -> void:
	shadow_disc(c, r, ht)
	disc(c, r, col.darkened(0.18))
	disc(c + lit * r * 0.12, r * 0.86, col)
	if gloss > 0.0:
		disc(c + lit * r * 0.38, r * 0.34, col.lightened(gloss))


func ring(c: Vector2, r: float, col: Color, w: float = 1.5) -> void:
	ci.draw_arc(c, r, 0.0, TAU, maxi(12, int(r * 1.2)), col, w, true)


func ellipse(c: Vector2, rad: Vector2, col: Color, a: float = 0.0) -> void:
	Draw.poly(ci, Draw.ellipse_points(c, rad, a, 18), col)


func line(a: Vector2, b: Vector2, c: Color, w: float = 1.5) -> void:
	ci.draw_line(a, b, c, w, true)


func poly(pts: PackedVector2Array, c: Color) -> void:
	Draw.poly(ci, pts, c)


func pline(pts: PackedVector2Array, c: Color, w: float = 1.5) -> void:
	ci.draw_polyline(pts, c, w, true)


## Many thin lines at once (grout, planks, grain): one draw call.
func lines(segs: PackedVector2Array, c: Color, w: float = 1.0) -> void:
	if segs.size() >= 2:
		ci.draw_multiline(segs, c, w)


func grad(r: Rect2, a: Color, b: Color, vertical: bool = true) -> void:
	if vertical:
		Draw.vgrad(ci, r, a, b)
	else:
		Draw.hgrad(ci, r, a, b)


## Text that reads upright on screen, centred on `p` (in the current frame).
func text(p: Vector2, s: String, size: int, c: Color, font: String = "cond", outline: int = 0) -> void:
	var f := W.font(font)
	var saved_org := org
	var saved_ang := ang
	var world_ang := base_rot + ang
	# the point p in lot-local coords
	var lp := saved_org + p.rotated(saved_ang)
	ci.draw_set_transform(lp, -base_rot)
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var asc := f.get_ascent(size) - f.get_descent(size)
	if outline > 0:
		ci.draw_string_outline(f, Vector2(-w * 0.5, asc * 0.5), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, Color(0, 0, 0, 0.7))
	ci.draw_string(f, Vector2(-w * 0.5, asc * 0.5), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)
	ci.draw_set_transform(saved_org, saved_ang)
	if world_ang != base_rot + ang:
		frame(saved_org, saved_ang)


## Text laid along the current frame's x axis (painted on a thing), flipped so it's never upside down.
func text_on(p: Vector2, s: String, size: int, c: Color, font: String = "cond") -> void:
	var f := W.font(font)
	var world_ang := wrapf(base_rot + ang, -PI, PI)
	var flip := absf(world_ang) > PI * 0.5 + 0.01
	var saved_org := org
	var saved_ang := ang
	var lp := saved_org + p.rotated(saved_ang)
	ci.draw_set_transform(lp, saved_ang + (PI if flip else 0.0))
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var asc := f.get_ascent(size) - f.get_descent(size)
	ci.draw_string(f, Vector2(-w * 0.5, asc * 0.5), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)
	ci.draw_set_transform(saved_org, saved_ang)


# ------------------------------------------------------------------ materials

## Wood grain on a rectangle: a few long streaks along x (or y).
func grain(r: Rect2, c: Color, along_x: bool = true, n: int = 0, s: int = 0) -> void:
	var segs := PackedVector2Array()
	var cnt := n if n > 0 else maxi(2, int((r.size.y if along_x else r.size.x) / 5.0))
	for k in cnt:
		var t := (k + 0.5) / cnt + (h(k, s, 3) - 0.5) * 0.4 / cnt
		var a0 := h(k, s, 5) * 0.3
		var a1 := 0.7 + h(k, s, 7) * 0.3
		if along_x:
			var y := r.position.y + r.size.y * t
			segs.append(Vector2(r.position.x + r.size.x * a0, y))
			segs.append(Vector2(r.position.x + r.size.x * a1, y))
		else:
			var x := r.position.x + r.size.x * t
			segs.append(Vector2(x, r.position.y + r.size.y * a0))
			segs.append(Vector2(x, r.position.y + r.size.y * a1))
	lines(segs, Color(c, 0.35), 1.0)


## Glass seen from above: pale, a diagonal glint.
func glass(r: Rect2, tint: Color = Pal.GLASS, a: float = 0.55) -> void:
	rect(r, Color(tint, a))
	var g0 := r.position + Vector2(r.size.x * 0.15, 0)
	var len := minf(r.size.y, r.size.x * 0.4)
	for k in 2:
		var x := r.position.x + r.size.x * (0.18 + k * 0.1)
		line(Vector2(x, r.position.y + 1), Vector2(x + len * 0.35, r.position.y + minf(len, r.size.y) - 1), Color(1, 1, 1, 0.28 - k * 0.1), 1.5 - k * 0.5)
	ci.draw_rect(r, Color(tint.darkened(0.3), 0.6), false, 1.0)
	var _unused := g0


## A star of cracks across a pane.
func cracks(c: Vector2, r: float, s: int, col: Color = Color(1, 1, 1, 0.75)) -> void:
	var n := 7
	for k in n:
		var a := TAU * (k + h(k, s, 1) * 0.6) / n
		var p0 := c
		var d := r * (0.55 + h(k, s, 2) * 0.45)
		var mid := c + Vector2.from_angle(a + (h(k, s, 3) - 0.5) * 0.5) * d * 0.5
		var end := c + Vector2.from_angle(a) * d
		pline(PackedVector2Array([p0, mid, end]), col, 1.0)
		if k % 2 == 0:
			var br := mid + Vector2.from_angle(a + 0.9) * d * 0.3
			line(mid, br, Color(col, col.a * 0.7), 1.0)
	ring(c, r * 0.28, Color(col, col.a * 0.6), 1.0)


## Shards of glass scattered in a rect (bright slivers with a dark edge).
func shards(r: Rect2, n: int, s: int, col: Color = Color(0.85, 0.93, 0.96, 0.85)) -> void:
	for k in n:
		var p := r.position + Vector2(h(k, s, 11), h(k, s, 12)) * r.size
		var a := h(k, s, 13) * TAU
		var sz := 2.0 + h(k, s, 14) * 4.5
		var pts := PackedVector2Array([p + Vector2.from_angle(a) * sz, p + Vector2.from_angle(a + 2.3) * sz * 0.5,
			p + Vector2.from_angle(a + 3.6) * sz * 0.7])
		ci.draw_colored_polygon(pts, col)
		ci.draw_polyline(_closed(pts), Color(0.3, 0.4, 0.45, 0.5), 1.0, true)
