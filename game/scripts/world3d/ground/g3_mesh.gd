class_name G3Mesh
extends RefCounted
## A tiny geometry accumulator for the ground: flat-shaded boxes, cylinders, cones, ellipsoids, quads and
## tubes with vertex colours, merged into one ArrayMesh. A transform stack (push/pop) places prefabs.
## Windings: Godot's front face is clockwise seen from outside; quad() takes its corners that way and
## computes the normal itself, so callers only have to list the corners in a consistent loop.
## UV: planar, from the final world x/z (times uvk) on top faces, and (along, y) on side faces.

var v := PackedVector3Array()
var n := PackedVector3Array()
var c := PackedColorArray()
var uv := PackedVector2Array()
var idx := PackedInt32Array()
var xf := Transform3D.IDENTITY
var uvk := 0.25
var swap_uv := false
var _stack: Array[Transform3D] = []


func push(t: Transform3D) -> void:
	_stack.append(xf)
	xf = xf * t


func push_at(pos: Vector3, yaw: float = 0.0, scale: float = 1.0) -> void:
	var b := Basis(Vector3.UP, yaw)
	if scale != 1.0:
		b = b.scaled(Vector3(scale, scale, scale))
	push(Transform3D(b, pos))


func pop() -> void:
	xf = _stack.pop_back()


func is_empty() -> bool:
	return v.is_empty()


func count() -> int:
	return v.size()


## One flat triangle (corners clockwise seen from outside).
func tri(a: Vector3, b: Vector3, cc: Vector3, col: Color) -> void:
	var pa := xf * a
	var pb := xf * b
	var pc := xf * cc
	var nn := (pc - pa).cross(pb - pa)
	if nn.length_squared() < 1e-12:
		return
	nn = nn.normalized()
	var base := v.size()
	v.append(pa)
	v.append(pb)
	v.append(pc)
	for k in 3:
		n.append(nn)
		c.append(col)
	if absf(nn.y) > 0.5:
		if swap_uv:
			uv.append(Vector2(pa.z, pa.x) * uvk)
			uv.append(Vector2(pb.z, pb.x) * uvk)
			uv.append(Vector2(pc.z, pc.x) * uvk)
		else:
			uv.append(Vector2(pa.x, pa.z) * uvk)
			uv.append(Vector2(pb.x, pb.z) * uvk)
			uv.append(Vector2(pc.x, pc.z) * uvk)
	else:
		uv.append(Vector2(pa.x + pa.z, pa.y) * uvk)
		uv.append(Vector2(pb.x + pb.z, pb.y) * uvk)
		uv.append(Vector2(pc.x + pc.z, pc.y) * uvk)
	idx.append(base)
	idx.append(base + 1)
	idx.append(base + 2)


func quad(a: Vector3, b: Vector3, cc: Vector3, d: Vector3, col: Color) -> void:
	tri(a, b, cc, col)
	tri(a, cc, d, col)


## A quad whose normal is flipped, if needed, to face the same way as `hint` (local space).
func quad_out(a: Vector3, b: Vector3, cc: Vector3, d: Vector3, hint: Vector3, col: Color) -> void:
	var nn := (xf.basis * (cc - a)).cross(xf.basis * (b - a))
	if nn.dot(xf.basis * hint) >= 0.0:
		quad(a, b, cc, d, col)
	else:
		quad(a, d, cc, b, col)


## A triangle facing `hint` (local space).
func tri_out(a: Vector3, b: Vector3, cc: Vector3, hint: Vector3, col: Color) -> void:
	var nn := (xf.basis * (cc - a)).cross(xf.basis * (b - a))
	if nn.dot(xf.basis * hint) >= 0.0:
		tri(a, b, cc, col)
	else:
		tri(a, cc, b, col)


## A gabled roof sitting on y = ctr.y: footprint sx (x) by sz (z), ridge `rise` above, running along x
## (or along z). Slopes get `col`, the gable ends `end_col`.
func gable(ctr: Vector3, sx: float, sz: float, rise: float, col: Color, end_col: Color, along_x: bool = true) -> void:
	if not along_x:
		push(Transform3D(Basis(Vector3.UP, PI * 0.5), ctr))
		gable(Vector3.ZERO, sz, sx, rise, col, end_col, true)
		pop()
		return
	var hx := sx * 0.5
	var hz := sz * 0.5
	var y := ctr.y
	var cx := ctr.x
	var cz := ctr.z
	quad_out(Vector3(cx - hx, y, cz - hz), Vector3(cx + hx, y, cz - hz), Vector3(cx + hx, y + rise, cz), Vector3(cx - hx, y + rise, cz), Vector3(0, 1, -1), col.darkened(0.06))
	quad_out(Vector3(cx - hx, y, cz + hz), Vector3(cx + hx, y, cz + hz), Vector3(cx + hx, y + rise, cz), Vector3(cx - hx, y + rise, cz), Vector3(0, 1, 1), col.lightened(0.06))
	tri_out(Vector3(cx - hx, y, cz - hz), Vector3(cx - hx, y, cz + hz), Vector3(cx - hx, y + rise, cz), Vector3(-1, 0, 0), end_col)
	tri_out(Vector3(cx + hx, y, cz - hz), Vector3(cx + hx, y, cz + hz), Vector3(cx + hx, y + rise, cz), Vector3(1, 0, 0), end_col.darkened(0.1))


## A quad with per-corner colours (soft gradients).
func quad4(a: Vector3, b: Vector3, cc: Vector3, d: Vector3, ca: Color, cb: Color, ccc: Color, cd: Color) -> void:
	var s0 := v.size()
	quad(a, b, cc, d, ca)
	if v.size() - s0 == 6:
		c[s0] = ca
		c[s0 + 1] = cb
		c[s0 + 2] = ccc
		c[s0 + 3] = ca
		c[s0 + 4] = ccc
		c[s0 + 5] = cd


## A rectangle facing `nrm`, centred at `ctr`, spanned by unit axes u and w (half sizes hu, hw).
func face(ctr: Vector3, nrm: Vector3, u: Vector3, w: Vector3, hu: float, hw: float, col: Color) -> void:
	var a := ctr - u * hu - w * hw
	var b := ctr + u * hu - w * hw
	var cc := ctr + u * hu + w * hw
	var d := ctr - u * hu + w * hw
	var test := (xf.basis * (cc - a)).cross(xf.basis * (b - a))
	if test.dot(xf.basis * nrm) < 0.0:
		quad(a, d, cc, b, col)
	else:
		quad(a, b, cc, d, col)


## A horizontal rectangle (top face up) from x0,z0 to x1,z1 at height y.
func flat(x0: float, z0: float, x1: float, z1: float, y: float, col: Color) -> void:
	quad(Vector3(x0, y, z0), Vector3(x1, y, z0), Vector3(x1, y, z1), Vector3(x0, y, z1), col)


## A vertical wall between two points of the x/z plane from y0 up to y1; it faces to the left of the
## direction a->b seen from above (screen: x right, z down), i.e. outward for a loop listed clockwise.
func wall(a: Vector2, b: Vector2, y0: float, y1: float, col: Color) -> void:
	quad(Vector3(b.x, y1, b.y), Vector3(a.x, y1, a.y), Vector3(a.x, y0, a.y), Vector3(b.x, y0, b.y), col)


## A flat strip of width w centred on the line a->b at height y.
func strip(a: Vector2, b: Vector2, w: float, y: float, col: Color) -> void:
	var d := (b - a)
	if d.length() < 1e-4:
		return
	var nrm := Vector2(-d.y, d.x).normalized() * w * 0.5
	var p0 := Vector3(a.x - nrm.x, y, a.y - nrm.y)
	var p1 := Vector3(a.x + nrm.x, y, a.y + nrm.y)
	var p2 := Vector3(b.x + nrm.x, y, b.y + nrm.y)
	var p3 := Vector3(b.x - nrm.x, y, b.y - nrm.y)
	if (p2 - p0).cross(p1 - p0).y > 0.0:
		quad(p0, p1, p2, p3, col)
	else:
		quad(p0, p3, p2, p1, col)


## A box centred at `ctr` (no bottom face). Optional different top colour.
func box(ctr: Vector3, size: Vector3, col: Color, top: Color = Color(0, 0, 0, -1), bottom: bool = false) -> void:
	var h := size * 0.5
	var tc := col if top.a < 0.0 else top
	face(ctr + Vector3(0, h.y, 0), Vector3.UP, Vector3.RIGHT, Vector3.BACK, h.x, h.z, tc)
	face(ctr + Vector3(h.x, 0, 0), Vector3.RIGHT, Vector3.BACK, Vector3.UP, h.z, h.y, col.darkened(0.12))
	face(ctr - Vector3(h.x, 0, 0), Vector3.LEFT, Vector3.BACK, Vector3.UP, h.z, h.y, col.darkened(0.04))
	face(ctr + Vector3(0, 0, h.z), Vector3.BACK, Vector3.RIGHT, Vector3.UP, h.x, h.y, col.darkened(0.08))
	face(ctr - Vector3(0, 0, h.z), Vector3.FORWARD, Vector3.RIGHT, Vector3.UP, h.x, h.y, col)
	if bottom:
		face(ctr - Vector3(0, h.y, 0), Vector3.DOWN, Vector3.RIGHT, Vector3.BACK, h.x, h.z, col.darkened(0.3))


## A box standing on y = base (x,z centre).
func pillar(x: float, z: float, base: float, sx: float, h: float, sz: float, col: Color, top: Color = Color(0, 0, 0, -1)) -> void:
	box(Vector3(x, base + h * 0.5, z), Vector3(sx, h, sz), col, top)


## A flat soft pool of light/stain: concentric rings fading from `col` at the centre to nothing.
func glow_disc(ctr: Vector3, r: float, col: Color, steps: int = 4, segs: int = 18) -> void:
	for k in steps:
		var r0 := r * float(k) / float(steps)
		var r1 := r * float(k + 1) / float(steps)
		var f0 := pow(1.0 - float(k) / float(steps), 2.0)
		var f1 := pow(1.0 - float(k + 1) / float(steps), 2.0)
		var c0 := Color(col.r, col.g, col.b, col.a * f0)
		var c1 := Color(col.r, col.g, col.b, col.a * f1)
		for s in segs:
			var a0 := TAU * float(s) / float(segs)
			var a1 := TAU * float(s + 1) / float(segs)
			var d0 := Vector3(cos(a0), 0, sin(a0))
			var d1 := Vector3(cos(a1), 0, sin(a1))
			if k == 0:
				_tri_c(ctr, ctr + d0 * r1, ctr + d1 * r1, c0, c1, c1)
			else:
				_tri_c(ctr + d0 * r0, ctr + d0 * r1, ctr + d1 * r1, c0, c1, c1)
				_tri_c(ctr + d0 * r0, ctr + d1 * r1, ctr + d1 * r0, c0, c1, c0)


func _tri_c(a: Vector3, b: Vector3, cc: Vector3, ca: Color, cb: Color, ccc: Color) -> void:
	var s0 := v.size()
	tri(a, b, cc, ca)
	if v.size() - s0 == 3:
		c[s0] = ca
		c[s0 + 1] = cb
		c[s0 + 2] = ccc


## A (truncated) cone / cylinder standing on `base`, radii r0 (bottom) and r1 (top).
func cyl(base: Vector3, r0: float, r1: float, h: float, segs: int, col: Color, cap: bool = true, top_col: Color = Color(0, 0, 0, -1)) -> void:
	var tc := col if top_col.a < 0.0 else top_col
	for k in segs:
		var a0 := TAU * float(k) / float(segs)
		var a1 := TAU * float(k + 1) / float(segs)
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var shade := 0.5 + 0.5 * (-(d0 + d1).normalized().dot(Vector3(0.62, 0, 0.62).normalized()))
		var sc := col.lightened(0.1 * (1.0 - shade)).darkened(0.16 * shade)
		var b0 := base + d0 * r0
		var b1 := base + d1 * r0
		var t0 := base + Vector3(0, h, 0) + d0 * r1
		var t1 := base + Vector3(0, h, 0) + d1 * r1
		quad(b0, b1, t1, t0, sc)
		if cap and r1 > 0.001:
			tri(base + Vector3(0, h, 0), t0, t1, tc)
	if r1 <= 0.001:
		pass


## An ellipsoid (foliage, sacks, bushes, lamp globes), low poly.
func blob(ctr: Vector3, radii: Vector3, col: Color, rings: int = 3, segs: int = 8, jitter: float = 0.0, seed_v: int = 0) -> void:
	var pts: Array = []
	for r in rings + 1:
		var ph := PI * float(r) / float(rings)
		var row := []
		for s in segs:
			var th := TAU * float(s) / float(segs)
			var j := 1.0
			if jitter > 0.0:
				j = 1.0 + (Draw.hash01(seed_v + r * 7, s * 5 + 3, 17) - 0.5) * 2.0 * jitter
			if r == 0 or r == rings:
				j = 1.0
			row.append(ctr + Vector3(sin(ph) * cos(th) * radii.x * j, cos(ph) * radii.y * j, sin(ph) * sin(th) * radii.z * j))
		pts.append(row)
	for r in rings:
		for s in segs:
			var s2 := (s + 1) % segs
			var a: Vector3 = pts[r][s]
			var b: Vector3 = pts[r][s2]
			var cc: Vector3 = pts[r + 1][s2]
			var d: Vector3 = pts[r + 1][s]
			var mid := (a + b + cc + d) * 0.25 - ctr
			var shade := clampf(0.5 - mid.normalized().dot(Vector3(0.5, -0.8, 0.5).normalized()) * 0.5, 0.0, 1.0)
			var col2 := col.lightened(0.18 * (1.0 - shade)).darkened(0.22 * shade)
			if r == 0:
				tri(a, d, cc, col2)
			elif r == rings - 1:
				tri(a, cc, b, col2)
			else:
				quad(a, d, cc, b, col2)


## A thin square-section tube between two points (wires, rails, rods, boards on edge).
func rod(a: Vector3, b: Vector3, r: float, col: Color, up: Vector3 = Vector3.UP) -> void:
	var d := b - a
	var l := d.length()
	if l < 1e-5:
		return
	var f := d / l
	var s := f.cross(up)
	if s.length() < 1e-3:
		s = f.cross(Vector3.RIGHT)
	s = s.normalized()
	var u := s.cross(f).normalized()
	var mid := (a + b) * 0.5
	var bs := Basis(s, u, f)
	push(Transform3D(bs, mid))
	box(Vector3.ZERO, Vector3(r * 2.0, r * 2.0, l), col)
	pop()


func ring_flat(ctr: Vector3, r0: float, r1: float, segs: int, col: Color) -> void:
	for k in segs:
		var a0 := TAU * float(k) / float(segs)
		var a1 := TAU * float(k + 1) / float(segs)
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		quad(ctr + d0 * r1, ctr + d1 * r1, ctr + d1 * r0, ctr + d0 * r0, col)


func disc(ctr: Vector3, r: float, segs: int, col: Color) -> void:
	for k in segs:
		var a0 := TAU * float(k) / float(segs)
		var a1 := TAU * float(k + 1) / float(segs)
		tri(ctr, ctr + Vector3(cos(a0), 0, sin(a0)) * r, ctr + Vector3(cos(a1), 0, sin(a1)) * r, col)


## A flat polygon (CCW or CW in the x/z plane) at height y, triangulated.
func poly_flat(pts: PackedVector2Array, y: float, col: Color) -> void:
	var tris := Geometry2D.triangulate_polygon(pts)
	var k := 0
	while k + 2 < tris.size():
		var a := pts[tris[k]]
		var b := pts[tris[k + 1]]
		var cc := pts[tris[k + 2]]
		var va := Vector3(a.x, y, a.y)
		var vb := Vector3(b.x, y, b.y)
		var vc := Vector3(cc.x, y, cc.y)
		var nn := (xf.basis * (vc - va)).cross(xf.basis * (vb - va))
		if nn.y >= 0.0:
			tri(va, vb, vc, col)
		else:
			tri(va, vc, vb, col)
		k += 3


## An irregular blob outline in x/z (stains, puddles): n points around a centre with seeded wobble.
static func blob_pts(ctr: Vector2, rx: float, rz: float, seed_v: int, n: int = 14, rough: float = 0.25, rot: float = 0.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in n:
		var a := TAU * float(k) / float(n)
		var w := 1.0 + (Draw.hash01(seed_v, k * 3 + 1, 5) - 0.5) * 2.0 * rough
		var p := Vector2(cos(a) * rx * w, sin(a) * rz * w).rotated(rot)
		out.append(ctr + p)
	return out


func to_mesh() -> ArrayMesh:
	var am := ArrayMesh.new()
	if v.is_empty():
		return am
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = n
	arr[Mesh.ARRAY_COLOR] = c
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_INDEX] = idx
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return am


## A MeshInstance3D for this geometry, or null when empty.
func instance(nm: String, material: Material, shadows: bool = true) -> MeshInstance3D:
	if v.is_empty():
		return null
	var mi := MeshInstance3D.new()
	mi.name = nm
	mi.mesh = to_mesh()
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
