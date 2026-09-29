class_name CarPaint
extends RefCounted
## Shading primitives for the cars (CarArt). Everything is pixels in the car's local frame (nose
## to +x). `L` is the direction toward the sun (north-west) turned into that frame, so highlights
## and rims sit on the side that faces the light whichever way the car points.
##
##   panel(ci, pts, base, L, bevel, gloss)   a glossy pressed-steel panel: dark edge, the colour, a lit crown
##   rings(ci, rings, colors)                smooth gradient between concentric rings (one triangle batch)
##   feather(ci, pts, width, color)          a polygon with a soft edge (shadows)
##   streak(ci, a, b, w, color)              a soft highlight line that fades at both ends and sides
##   rim(ci, pts, L, color, width)           a thin line along the part of an outline facing the light
##   chrome_bar / chrome_disc / glass        bright metal and glass
##   spline(pts) / rpoly(rect, r)            smooth outlines

const SKY := Color(0.76, 0.82, 0.9)          # what glossy paint reflects from above
const WARM := Color(1.0, 0.95, 0.86)         # sunlight
const INK := Color(0.035, 0.03, 0.05)        # the darkest shade (matches Person2D._dk)
const CHROME_DK := Color("34383d")
const CHROME := Color("9aa1a8")
const CHROME_HI := Color("eef2f4")
const RUBBER := Color("151414")
const RUBBER_HI := Color("2c2b2a")
const GLASS := Color("222c36")
const GLASS_HI := Color("7f93a6")


static func lit(c: Color, a: float) -> Color:
	return c.lerp(WARM, a)


static func dk(c: Color, a: float) -> Color:
	return c.lerp(INK, a)


static func gloss(c: Color, a: float) -> Color:
	return c.lerp(SKY, a)


static func alpha(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, c.a * a)


# ------------------------------------------------------------------ geometry

static func signed_area(pts: PackedVector2Array) -> float:
	var a := 0.0
	var n := pts.size()
	for i in n:
		var p := pts[i]
		var q := pts[(i + 1) % n]
		a += p.x * q.y - q.x * p.y
	return a * 0.5


## The outline moved inward by `d` pixels (negative: outward). Keeps the vertex count, so rings
## made from one outline line up for gradients.
static func inset(pts: PackedVector2Array, d: float) -> PackedVector2Array:
	var n := pts.size()
	var out := PackedVector2Array()
	out.resize(n)
	var s := 1.0 if signed_area(pts) > 0.0 else -1.0
	for i in n:
		var p0 := pts[(i - 1 + n) % n]
		var p1 := pts[i]
		var p2 := pts[(i + 1) % n]
		var e0 := (p1 - p0).normalized()
		var e1 := (p2 - p1).normalized()
		var n0 := Vector2(-e0.y, e0.x) * s
		var n1 := Vector2(-e1.y, e1.x) * s
		var nv := n0 + n1
		if nv.length_squared() < 1e-6:
			nv = n0
		else:
			nv = nv.normalized()
		var c := maxf(nv.dot(n0), 0.45)
		out[i] = p1 + nv * (d / c)
	return out


## The outline pushed out by `d` along each vertex's averaged normal, without mitring (for soft
## skirts round busy outlines: no spikes at the concave corners).
static func grow(pts: PackedVector2Array, d: float) -> PackedVector2Array:
	var n := pts.size()
	var out := PackedVector2Array()
	out.resize(n)
	var s := 1.0 if signed_area(pts) > 0.0 else -1.0
	for i in n:
		# the direction along the outline, from neighbours at least a couple of px away (clipped
		# outlines have runs of near-duplicate points that would throw the normal about)
		var a := pts[i]
		var b := pts[i]
		for k in range(1, mini(16, n / 2)):
			a = pts[(i - k + n) % n]
			if a.distance_squared_to(pts[i]) > 4.0:
				break
		for k in range(1, mini(16, n / 2)):
			b = pts[(i + k) % n]
			if b.distance_squared_to(pts[i]) > 4.0:
				break
		var e := (b - a).normalized()
		out[i] = pts[i] - Vector2(-e.y, e.x) * s * d
	return out


static func shift(pts: PackedVector2Array, off: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(pts.size())
	for i in pts.size():
		out[i] = pts[i] + off
	return out


## Scale an outline about a point (non-uniform).
static func scale_about(pts: PackedVector2Array, c: Vector2, k: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(pts.size())
	for i in pts.size():
		out[i] = c + (pts[i] - c) * k
	return out


static func mirror_y(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(pts.size())
	var n := pts.size()
	for i in n:
		var p := pts[n - 1 - i]
		out[i] = Vector2(p.x, -p.y)
	return out


static func centroid(pts: PackedVector2Array) -> Vector2:
	var c := Vector2.ZERO
	for p in pts:
		c += p
	return c / maxf(1.0, float(pts.size()))


## A closed Catmull-Rom curve through the control points.
static func spline(ctrl: PackedVector2Array, per: int = 6) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := ctrl.size()
	for i in n:
		var p0 := ctrl[(i - 1 + n) % n]
		var p1 := ctrl[i]
		var p2 := ctrl[(i + 1) % n]
		var p3 := ctrl[(i + 2) % n]
		for k in per:
			var t := float(k) / per
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	return out


## A rounded rectangle; `r` may be a float or a Vector4 (radius per corner: front-left,
## front-right, back-right, back-left, where front = +x and left = -y).
static func rpoly(r: Rect2, rad: Variant, seg: int = 5) -> PackedVector2Array:
	var rv: Vector4 = rad if rad is Vector4 else Vector4(float(rad), float(rad), float(rad), float(rad))
	var m := minf(r.size.x, r.size.y) * 0.5
	var fl := minf(rv.x, m)
	var fr := minf(rv.y, m)
	var br := minf(rv.z, m)
	var bl := minf(rv.w, m)
	var pts := PackedVector2Array()
	# clockwise on screen, starting at the front-left corner
	_arc(pts, Vector2(r.end.x - fl, r.position.y + fl), fl, -PI * 0.5, 0.0, seg)
	_arc(pts, Vector2(r.end.x - fr, r.end.y - fr), fr, 0.0, PI * 0.5, seg)
	_arc(pts, Vector2(r.position.x + br, r.end.y - br), br, PI * 0.5, PI, seg)
	_arc(pts, Vector2(r.position.x + bl, r.position.y + bl), bl, PI, PI * 1.5, seg)
	return pts


static func _arc(pts: PackedVector2Array, c: Vector2, r: float, a0: float, a1: float, seg: int) -> void:
	if r <= 0.01:
		pts.append(c)
		return
	for s in seg + 1:
		var a := lerpf(a0, a1, float(s) / seg)
		pts.append(c + Vector2(cos(a), sin(a)) * r)


static func ellipse(c: Vector2, radii: Vector2, seg: int = 24, rot: float = 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var t := Transform2D(rot, c)
	for k in seg:
		var a := TAU * float(k) / seg
		pts.append(t * Vector2(cos(a) * radii.x, sin(a) * radii.y))
	return pts


static func closed(pts: PackedVector2Array) -> PackedVector2Array:
	var loop := pts.duplicate()
	if pts.size() > 0:
		loop.append(pts[0])
	return loop


# ------------------------------------------------------------------ fills

## Gradient between concentric rings (same vertex count), the last ring filled flat.
static func rings(ci: CanvasItem, rs: Array, cs: Array, fill_last: bool = true) -> void:
	var b := Batch.new()
	b.rings(rs, cs, fill_last)
	b.flush(ci)


## Triangles collected from many shapes and sent as one draw call (each polygon command is a
## draw call of its own in the 2D renderer; the layers that redraw often use this).
class Batch extends RefCounted:
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()

	func rings(rs: Array, cs: Array, fill_last: bool = true) -> void:
		var n: int = (rs[0] as PackedVector2Array).size()
		if n < 3:
			return
		var o := pts.size()
		for k in rs.size():
			pts.append_array(rs[k])
			var c: Color = cs[k]
			for i in n:
				cols.append(c)
		for k in rs.size() - 1:
			var a := o + k * n
			var b := o + (k + 1) * n
			for i in n:
				var j := (i + 1) % n
				idx.append_array(PackedInt32Array([a + i, a + j, b + j, a + i, b + j, b + i]))
		if fill_last:
			var last: PackedVector2Array = rs[rs.size() - 1]
			var base := o + (rs.size() - 1) * n
			var tri := Geometry2D.triangulate_polygon(last)
			if tri.is_empty():
				# fan from the centre (a ring pinched by a deep inset)
				pts.append(CarPaint.centroid(last))
				cols.append(cs[cs.size() - 1])
				var ctr := pts.size() - 1
				for i in n:
					idx.append_array(PackedInt32Array([ctr, base + i, base + (i + 1) % n]))
			else:
				for t in tri:
					idx.append(base + t)

	func poly(p: PackedVector2Array, col: Color) -> void:
		if p.size() < 3:
			return
		var tri := Geometry2D.triangulate_polygon(p)
		if tri.is_empty():
			return
		var o := pts.size()
		pts.append_array(p)
		for i in p.size():
			cols.append(col)
		for t in tri:
			idx.append(o + t)

	## A straight stroke with square ends.
	func line(a: Vector2, b: Vector2, w: float, col: Color) -> void:
		var d := b - a
		if d.length_squared() < 0.0001:
			return
		var nv := Vector2(-d.y, d.x).normalized() * w * 0.5
		var o := pts.size()
		pts.append_array(PackedVector2Array([a - nv, b - nv, b + nv, a + nv]))
		for i in 4:
			cols.append(col)
		idx.append_array(PackedInt32Array([o, o + 1, o + 2, o, o + 2, o + 3]))

	func flush(ci: CanvasItem) -> void:
		if idx.is_empty():
			return
		RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), idx, pts, cols)
		pts = PackedVector2Array()
		cols = PackedColorArray()
		idx = PackedInt32Array()


## A flat polygon with an anti-aliased edge.
static func fill(ci: CanvasItem, pts: PackedVector2Array, col: Color, aa: bool = true) -> void:
	if pts.size() < 3:
		return
	var tri := Geometry2D.triangulate_polygon(pts)
	if not tri.is_empty():
		var cols := PackedColorArray()
		cols.resize(pts.size())
		cols.fill(col)
		RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), tri, pts, cols)
	if aa and col.a > 0.02:
		ci.draw_polyline(closed(pts), col, 1.0, true)


## A glossy pressed-steel panel: the dark edge where it turns down, the paint, and a crown that
## catches the sky, pushed a little toward the light. `bevel` = how wide the rounded shoulder is.
static func panel(ci: CanvasItem, pts: PackedVector2Array, base: Color, L: Vector2, bevel: float = 3.0,
		shine: float = 0.16, edge_k: float = 0.62) -> void:
	var edge := dk(base, edge_k)
	var top := gloss(base, shine) if base.get_luminance() < 0.35 else lit(base, shine * 0.8)
	var r1 := shift(inset(pts, bevel), L * bevel * 0.35)
	var r2 := shift(inset(pts, bevel * 2.3), L * bevel * 0.8)
	rings(ci, [pts, r1, r2], [edge, base, top])
	ci.draw_polyline(closed(pts), edge, 1.0, true)


## A flatter panel (wood, canvas, rubber): an edge and the colour, no gloss.
static func flat(ci: CanvasItem, pts: PackedVector2Array, base: Color, L: Vector2, bevel: float = 1.6, edge_k: float = 0.45) -> void:
	var edge := dk(base, edge_k)
	var r1 := shift(inset(pts, bevel), L * bevel * 0.3)
	rings(ci, [pts, r1], [edge, base])
	ci.draw_polyline(closed(pts), edge, 1.0, true)


## A soft-edged polygon (shadows): full colour inside, fading to nothing over `width` px.
static func feather(ci: CanvasItem, pts: PackedVector2Array, width: float, col: Color) -> void:
	if pts.size() < 3:
		return
	var outer := inset(pts, -width * 0.5)
	var inner := inset(pts, width * 0.5)
	rings(ci, [outer, inner], [alpha(col, 0.0), col])


## A soft highlight along a line: strongest in the middle, fading to both ends and both sides.
static func streak(ci: CanvasItem, a: Vector2, b: Vector2, w: float, col: Color, seg: int = 6) -> void:
	var d := b - a
	if d.length_squared() < 0.01:
		return
	var nv := Vector2(-d.y, d.x).normalized() * w
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var clear := alpha(col, 0.0)
	for i in seg + 1:
		var t := float(i) / seg
		var p := a + d * t
		var k := sin(PI * t)
		k = sqrt(k)
		pts.append(p - nv)
		pts.append(p)
		pts.append(p + nv)
		cols.append(clear)
		cols.append(alpha(col, k))
		cols.append(clear)
	for i in seg:
		var r0 := i * 3
		var r1 := (i + 1) * 3
		for j in 2:
			idx.append(r0 + j)
			idx.append(r0 + j + 1)
			idx.append(r1 + j + 1)
			idx.append(r0 + j)
			idx.append(r1 + j + 1)
			idx.append(r1 + j)
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), idx, pts, cols)


## A soft round blob (radial fade).
static func glow(ci: CanvasItem, c: Vector2, radii: Vector2, col: Color, rot: float = 0.0, seg: int = 18) -> void:
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	pts.append(c)
	cols.append(col)
	var t := Transform2D(rot, c)
	var clear := alpha(col, 0.0)
	var mid := alpha(col, 0.42)
	for k in seg:
		var a := TAU * float(k) / seg
		pts.append(t * Vector2(cos(a) * radii.x * 0.45, sin(a) * radii.y * 0.45))
		cols.append(mid)
	for k in seg:
		var a := TAU * float(k) / seg
		pts.append(t * Vector2(cos(a) * radii.x, sin(a) * radii.y))
		cols.append(clear)
	for k in seg:
		var j := (k + 1) % seg
		idx.append_array(PackedInt32Array([0, 1 + k, 1 + j]))
		idx.append_array(PackedInt32Array([1 + k, 1 + seg + k, 1 + seg + j, 1 + k, 1 + seg + j, 1 + j]))
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), idx, pts, cols)


## A thin line along the stretch of an outline that faces the light.
static func rim(ci: CanvasItem, pts: PackedVector2Array, L: Vector2, col: Color, width: float = 1.0,
		cut: float = 0.25, inset_px: float = 0.8) -> void:
	var n := pts.size()
	if n < 3:
		return
	var inner := inset(pts, inset_px)
	var s := 1.0 if signed_area(pts) > 0.0 else -1.0
	var facing := PackedByteArray()
	facing.resize(n)
	var any := false
	var all := true
	for i in n:
		var e := (pts[(i + 1) % n] - pts[(i - 1 + n) % n]).normalized()
		var outward := -Vector2(-e.y, e.x) * s
		var f := outward.dot(L) > cut
		facing[i] = 1 if f else 0
		any = any or f
		all = all and f
	if not any:
		return
	if all:
		ci.draw_polyline(closed(inner), col, width, true)
		return
	var start := 0
	for i in n:
		if facing[i] == 1 and facing[(i - 1 + n) % n] == 0:
			start = i
			break
	var run := PackedVector2Array()
	for k in n:
		var i := (start + k) % n
		if facing[i] == 0:
			if run.size() >= 2:
				ci.draw_polyline(run, col, width, true)
			run = PackedVector2Array()
			continue
		run.append(inner[i])
	if run.size() >= 2:
		ci.draw_polyline(run, col, width, true)


# ------------------------------------------------------------------ metal, glass, rubber

## A round chrome bar seen from above: dark edges, a bright core, a hot line toward the light.
static func chrome_bar(ci: CanvasItem, a: Vector2, b: Vector2, w: float, L: Vector2) -> void:
	var d := (b - a).normalized()
	var nv := Vector2(-d.y, d.x)
	var side := signf(nv.dot(L))
	ci.draw_line(a, b, CHROME_DK, w, true)
	ci.draw_line(a + nv * side * w * 0.08, b + nv * side * w * 0.08, CHROME, w * 0.62, true)
	ci.draw_line(a + nv * side * w * 0.2, b + nv * side * w * 0.2, CHROME_HI, maxf(0.7, w * 0.22), true)


static func chrome_poly(ci: CanvasItem, pts: PackedVector2Array, L: Vector2, bevel: float = 1.2) -> void:
	var r1 := shift(inset(pts, bevel), L * bevel * 0.4)
	var r2 := shift(inset(pts, bevel * 2.2), L * bevel * 1.0)
	rings(ci, [pts, r1, r2], [CHROME_DK, CHROME, CHROME_HI])
	ci.draw_polyline(closed(pts), CHROME_DK, 1.0, true)


## A chrome dome (lamp bowl, hub cap): dark rim, bright body, a white spot toward the light.
static func chrome_disc(ci: CanvasItem, c: Vector2, r: float, L: Vector2) -> void:
	FastDraw.disc(ci, c, r, CHROME_DK)
	FastDraw.disc(ci, c + L * r * 0.12, r * 0.84, CHROME)
	FastDraw.disc(ci, c + L * r * 0.3, r * 0.52, CHROME.lerp(CHROME_HI, 0.6))
	FastDraw.disc(ci, c + L * r * 0.45, maxf(0.6, r * 0.2), Color(1, 1, 1, 0.95))


## Glass seen at a steep angle: dark, with the sky sliding across it.
static func glass(ci: CanvasItem, pts: PackedVector2Array, L: Vector2) -> void:
	var r1 := shift(inset(pts, 1.0), L * 0.8)
	rings(ci, [pts, r1], [GLASS.darkened(0.35), GLASS])
	ci.draw_polyline(closed(pts), GLASS.darkened(0.35), 1.0, true)


## A tyre seen from above, into a batch: the dark shoulder, the tread's crown, a line down it.
static func tyre(bt: Batch, c: Vector2, length: float, width: float, rot: float, L: Vector2) -> void:
	var r := Rect2(-length * 0.5, -width * 0.5, length, width)
	var pts := rpoly(r, width * 0.42, 3)
	var t := Transform2D(rot, c)
	var p := PackedVector2Array()
	p.resize(pts.size())
	for i in pts.size():
		p[i] = t * pts[i]
	var edge := RUBBER.darkened(0.4)
	bt.rings([inset(p, -0.5), p, shift(inset(p, width * 0.22), L * 0.4)], [alpha(edge, 0.0), edge, RUBBER_HI])
	var ax := Vector2.from_angle(rot)
	bt.line(c - ax * length * 0.38, c + ax * length * 0.38, maxf(1.0, width * 0.22), RUBBER.darkened(0.5))


## Text painted on a panel, centred at `c`, running along +x.
static func sign_text(ci: CanvasItem, c: Vector2, s: String, size: int, col: Color, font: Font, max_w: float = -1.0) -> void:
	var fs := size
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if max_w > 0.0 and w > max_w:
		fs = maxi(6, int(floor(fs * max_w / w)))
		w = font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var asc := font.get_ascent(fs)
	var desc := font.get_descent(fs)
	ci.draw_string(font, c + Vector2(-w * 0.5, (asc - desc) * 0.5), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
