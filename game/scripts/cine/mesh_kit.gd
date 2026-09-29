class_name MeshKit
extends RefCounted
## A small procedural modelling kit. Primitives (boxes with chamfered edges, cylinders, lathes,
## extruded profiles, tubes along a path, lofts through rings) are appended to named surfaces
## with per-vertex colours, then committed as one ArrayMesh: one draw call per surface, so a
## whole car or lamp post costs one or two. Everything is built in metres.
##
## `xf` is applied to everything added; `push(t)` / `pop()` nest local frames.
## UVs are box-projected from the local position (1 unit = 1 metre), so tiling textures work.

var xf := Transform3D.IDENTITY
var _stack: Array[Transform3D] = []
var _surf := {}          # name -> Surf
var _order: Array[String] = []
var uv_scale := 1.0


func push(t: Transform3D) -> void:
	_stack.append(xf)
	xf = xf * t


func pop() -> void:
	xf = _stack.pop_back()


class Surf:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var uv := PackedVector2Array()


func _s(name: String) -> Surf:
	if not _surf.has(name):
		_surf[name] = Surf.new()
		_order.append(name)
	return _surf[name]


func has_surface(name: String) -> bool:
	return _surf.has(name)


func _uv(p: Vector3, n: Vector3) -> Vector2:
	var a := n.abs()
	if a.y >= a.x and a.y >= a.z:
		return Vector2(p.x, p.z) * uv_scale
	if a.x >= a.z:
		return Vector2(p.z, -p.y) * uv_scale
	return Vector2(p.x, -p.y) * uv_scale


## One triangle in world (kit) space with explicit per-vertex normals.
func _tri_raw(s: Surf, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3, col: Color) -> void:
	# Godot's front faces wind clockwise; make the winding agree with the normals
	var fn := (c - a).cross(b - a)
	if fn.dot(na + nb + nc) < 0.0:
		var t := b
		b = c
		c = t
		var tn := nb
		nb = nc
		nc = tn
	s.v.append(a)
	s.v.append(b)
	s.v.append(c)
	s.n.append(na)
	s.n.append(nb)
	s.n.append(nc)
	s.c.append(col)
	s.c.append(col)
	s.c.append(col)
	s.uv.append(_uv(a, na))
	s.uv.append(_uv(b, nb))
	s.uv.append(_uv(c, nc))


## A flat convex polygon (points in order around it) facing `outward` (local space).
func face(surf: String, pts: Array, col: Color, outward: Vector3) -> void:
	var s := _s(surf)
	var w: Array = []
	for p in pts:
		w.append(xf * (p as Vector3))
	var n := (xf.basis * outward).normalized()
	for k in range(1, w.size() - 1):
		_tri_raw(s, w[0], w[k], w[k + 1], n, n, n, col)


## A quad with smooth normals given per corner (local space).
func quad_smooth(surf: String, p: Array, n: Array, col: Color) -> void:
	var s := _s(surf)
	var w: Array = []
	var wn: Array = []
	for k in 4:
		w.append(xf * (p[k] as Vector3))
		wn.append((xf.basis * (n[k] as Vector3)).normalized())
	_tri_raw(s, w[0], w[1], w[2], wn[0], wn[1], wn[2], col)
	_tri_raw(s, w[0], w[2], w[3], wn[0], wn[2], wn[3], col)


func box(surf: String, center: Vector3, size: Vector3, col: Color, basis := Basis.IDENTITY, skip_bottom := false) -> void:
	var h := size * 0.5
	for ax in 3:
		for sg in [-1.0, 1.0]:
			if skip_bottom and ax == 1 and sg < 0.0:
				continue
			var n := Vector3.ZERO
			n[ax] = sg
			var u := Vector3.ZERO
			var v := Vector3.ZERO
			u[(ax + 1) % 3] = 1.0
			v[(ax + 2) % 3] = 1.0
			var c := n * h[ax]
			var hu := u * h[(ax + 1) % 3]
			var hv := v * h[(ax + 2) % 3]
			var pts := [c - hu - hv, c + hu - hv, c + hu + hv, c - hu + hv]
			for k in 4:
				pts[k] = center + basis * (pts[k] as Vector3)
			face(surf, pts, col, basis * n)


## A box whose twelve edges are chamfered by `bev` metres (reads as rounded from a distance).
func bbox(surf: String, center: Vector3, size: Vector3, bev: float, col: Color, basis := Basis.IDENTITY) -> void:
	var h := size * 0.5
	bev = minf(bev, minf(h.x, minf(h.y, h.z)) * 0.95)
	var inner := h - Vector3.ONE * bev
	# the point of face `ax` at the corner with signs sg
	var fp := func(ax: int, sg: Vector3) -> Vector3:
		var p := inner * sg
		p[ax] = h[ax] * sg[ax]
		return center + basis * p
	for ax in 3:
		var a1 := (ax + 1) % 3
		var a2 := (ax + 2) % 3
		for s0 in [-1.0, 1.0]:
			var pts := []
			for sv in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				var sg := Vector3.ZERO
				sg[ax] = s0
				sg[a1] = sv.x
				sg[a2] = sv.y
				pts.append(fp.call(ax, sg))
			var n := Vector3.ZERO
			n[ax] = s0
			_face_world(surf, pts, col, basis * n)
	# edges: between face a and face b, running along axis k
	for k in 3:
		var a := (k + 1) % 3
		var b := (k + 2) % 3
		for sa in [-1.0, 1.0]:
			for sb in [-1.0, 1.0]:
				var pts := []
				for sk in [-1.0, 1.0]:
					var sg := Vector3.ZERO
					sg[a] = sa
					sg[b] = sb
					sg[k] = sk
					pts.append(fp.call(a, sg))
				var pts2 := []
				for sk in [1.0, -1.0]:
					var sg := Vector3.ZERO
					sg[a] = sa
					sg[b] = sb
					sg[k] = sk
					pts2.append(fp.call(b, sg))
				var n := Vector3.ZERO
				n[a] = sa
				n[b] = sb
				_face_world(surf, pts + pts2, col, basis * n.normalized())
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var sg := Vector3(sx, sy, sz)
				_face_world(surf, [fp.call(0, sg), fp.call(1, sg), fp.call(2, sg)], col, basis * sg.normalized())


func _face_world(surf: String, pts: Array, col: Color, outward: Vector3) -> void:
	face(surf, pts, col, outward)


## A flat strip from a to b, `w` wide, turned to face `toward` (2 triangles; for thin parts
## drawn double-sided, like railings and spokes).
func bar(surf: String, a: Vector3, b: Vector3, w: float, col: Color, toward: Vector3) -> void:
	var d := (b - a).normalized()
	var side := d.cross(toward).normalized() * (w * 0.5)
	if side.length() < 1e-6:
		side = d.cross(Vector3.UP if absf(d.y) < 0.9 else Vector3.RIGHT).normalized() * (w * 0.5)
	var n := side.cross(d).normalized()
	if n.dot(toward) < 0.0:
		n = -n
	face(surf, [a - side, a + side, b + side, b - side], col, n)


## A cylinder (or cone) from a to b.
func cyl(surf: String, a: Vector3, b: Vector3, ra: float, rb: float, segs: int, col: Color, caps := true, smooth := true) -> void:
	var ax := b - a
	var len := ax.length()
	if len < 0.0001:
		return
	var up := ax / len
	var side := up.cross(Vector3.UP if absf(up.y) < 0.95 else Vector3.RIGHT).normalized()
	var fwd := side.cross(up).normalized()
	for k in segs:
		var t0 := TAU * k / segs
		var t1 := TAU * (k + 1) / segs
		var d0 := side * cos(t0) + fwd * sin(t0)
		var d1 := side * cos(t1) + fwd * sin(t1)
		var slope := (ra - rb) / len
		var n0 := (d0 + up * slope).normalized()
		var n1 := (d1 + up * slope).normalized()
		if not smooth:
			n0 = ((d0 + d1) * 0.5 + up * slope).normalized()
			n1 = n0
		quad_smooth(surf, [a + d0 * ra, a + d1 * ra, b + d1 * rb, b + d0 * rb], [n0, n1, n1, n0], col)
		if caps:
			if ra > 0.0:
				face(surf, [a, a + d1 * ra, a + d0 * ra], col, -up)
			if rb > 0.0:
				face(surf, [b, b + d0 * rb, b + d1 * rb], col, up)


## Surface of revolution around `axis` (from `base`): profile points are (radius, height).
func lathe(surf: String, base: Vector3, profile: Array, segs: int, col: Color, basis := Basis.IDENTITY, smooth := true) -> void:
	var up := basis.y.normalized()
	var side := basis.x.normalized()
	var fwd := basis.z.normalized()
	for i in profile.size() - 1:
		var p0: Vector2 = profile[i]
		var p1: Vector2 = profile[i + 1]
		var dr := p1.x - p0.x
		var dh := p1.y - p0.y
		for k in segs:
			var t0 := TAU * k / segs
			var t1 := TAU * (k + 1) / segs
			var d0 := side * cos(t0) + fwd * sin(t0)
			var d1 := side * cos(t1) + fwd * sin(t1)
			var q := [base + d0 * p0.x + up * p0.y, base + d1 * p0.x + up * p0.y,
				base + d1 * p1.x + up * p1.y, base + d0 * p1.x + up * p1.y]
			var n0 := (d0 * dh - up * dr).normalized()
			var n1 := (d1 * dh - up * dr).normalized()
			if not smooth:
				n0 = (((d0 + d1) * 0.5) * dh - up * dr).normalized()
				n1 = n0
			if p0.x < 0.0001 and p1.x < 0.0001:
				continue
			if p0.x < 0.0001:
				face(surf, [q[0], q[2], q[3]], col, (d0 + d1) * dh * 0.5 - up * dr)
			elif p1.x < 0.0001:
				face(surf, [q[0], q[1], q[2]], col, (d0 + d1) * dh * 0.5 - up * dr)
			else:
				quad_smooth(surf, q, [n0, n1, n1, n0], col)


## A polygon in the (z, y) plane (x ignored) extruded along x from x0 to x1. Concave is fine.
func extrude_x(surf: String, poly: PackedVector2Array, x0: float, x1: float, col: Color, caps := true) -> void:
	var n := poly.size()
	# signed area tells which way the outline runs
	var area := 0.0
	for k in n:
		var a := poly[k]
		var b := poly[(k + 1) % n]
		area += a.x * b.y - b.x * a.y
	var cw := area < 0.0
	for k in n:
		var a := poly[k]
		var b := poly[(k + 1) % n]
		var e := b - a
		if e.length() < 0.00001:
			continue
		var out2 := Vector2(e.y, -e.x) if not cw else Vector2(-e.y, e.x)
		var out := Vector3(0, out2.y, out2.x).normalized()
		face(surf, [Vector3(x0, a.y, a.x), Vector3(x1, a.y, a.x), Vector3(x1, b.y, b.x), Vector3(x0, b.y, b.x)], col, out)
	if caps:
		var idx := Geometry2D.triangulate_polygon(poly)
		for t in range(0, idx.size(), 3):
			var p0 := poly[idx[t]]
			var p1 := poly[idx[t + 1]]
			var p2 := poly[idx[t + 2]]
			face(surf, [Vector3(x0, p0.y, p0.x), Vector3(x0, p1.y, p1.x), Vector3(x0, p2.y, p2.x)], col, Vector3.LEFT)
			face(surf, [Vector3(x1, p0.y, p0.x), Vector3(x1, p1.y, p1.x), Vector3(x1, p2.y, p2.x)], col, Vector3.RIGHT)


## A round tube through a polyline.
func tube(surf: String, pts: Array, r: float, segs: int, col: Color) -> void:
	if pts.size() < 2:
		return
	var rings: Array = []
	var ref := Vector3.UP
	for i in pts.size():
		var p: Vector3 = pts[i]
		var t: Vector3
		if i == 0:
			t = (pts[1] as Vector3) - p
		elif i == pts.size() - 1:
			t = p - (pts[i - 1] as Vector3)
		else:
			t = (pts[i + 1] as Vector3) - (pts[i - 1] as Vector3)
		t = t.normalized()
		if absf(t.dot(ref)) > 0.95:
			ref = Vector3.RIGHT if absf(t.x) < 0.9 else Vector3.FORWARD
		var s := t.cross(ref).normalized()
		var f := s.cross(t).normalized()
		ref = f
		var ring: Array = []
		for k in segs:
			var a := TAU * k / segs
			ring.append([p + (s * cos(a) + f * sin(a)) * r, s * cos(a) + f * sin(a)])
		rings.append(ring)
	for i in rings.size() - 1:
		for k in segs:
			var k2 := (k + 1) % segs
			quad_smooth(surf, [rings[i][k][0], rings[i][k2][0], rings[i + 1][k2][0], rings[i + 1][k][0]],
				[rings[i][k][1], rings[i][k2][1], rings[i + 1][k2][1], rings[i + 1][k][1]], col)


## A flat polygon whose normal comes from its own winding, flipped to agree with `hint`.
func face_auto(surf: String, pts: Array, col: Color, hint: Vector3) -> void:
	var a: Vector3 = pts[0]
	var n := Vector3.ZERO
	for i in range(1, pts.size() - 1):
		n += ((pts[i] as Vector3) - a).cross((pts[i + 1] as Vector3) - a)
	if n.length() < 1e-9:
		return
	if n.dot(hint) < 0.0:
		n = -n
	face(surf, pts, col, n.normalized())


## Quads between successive rings of points (every ring the same length). Flat shaded.
func loft(surf: String, rings: Array, col: Color, closed := false, outward_hint := Vector3.ZERO) -> void:
	for i in rings.size() - 1:
		var r0: Array = rings[i]
		var r1: Array = rings[i + 1]
		var m := r0.size() if closed else r0.size() - 1
		for k in m:
			var k2 := (k + 1) % r0.size()
			var a: Vector3 = r0[k]
			var b: Vector3 = r0[k2]
			var c: Vector3 = r1[k2]
			var d: Vector3 = r1[k]
			var n := (b - a).cross(d - a)
			if n.length() < 1e-9:
				n = (c - b).cross(d - b)
			if outward_hint != Vector3.ZERO:
				var mid := (a + b + c + d) * 0.25
				var want := mid - outward_hint
				want.y *= 0.3
				if n.dot(want) < 0.0:
					n = -n
			face(surf, [a, b, c, d], col, n)


func commit(mats: Dictionary = {}, into: ArrayMesh = null) -> ArrayMesh:
	var am := into if into else ArrayMesh.new()
	for name in _order:
		var s: Surf = _surf[name]
		if s.v.is_empty():
			continue
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = s.v
		arr[Mesh.ARRAY_NORMAL] = s.n
		arr[Mesh.ARRAY_COLOR] = s.c
		arr[Mesh.ARRAY_TEX_UV] = s.uv
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		am.surface_set_name(am.get_surface_count() - 1, name)
		if mats.has(name):
			am.surface_set_material(am.get_surface_count() - 1, mats[name])
	return am


## A 2D arc (z, y) around centre c, from angle a0 to a1 (radians, 0 = +z), as points.
static func arc(c: Vector2, r: float, a0: float, a1: float, steps: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in steps + 1:
		var a := lerpf(a0, a1, float(k) / steps)
		out.append(c + Vector2(cos(a), sin(a)) * r)
	return out
