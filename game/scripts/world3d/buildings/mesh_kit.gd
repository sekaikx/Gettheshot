extends RefCounted
## A small merged-geometry builder for the buildings: collect quads, boxes, cylinders and spheres
## into one surface per material key, then commit() into a single ArrayMesh. Nothing here knows about
## buildings; it only makes triangles. Every shape takes an optional Transform3D (`xf`) so a lot can be
## built in its own frame (x along the front, y up, z out of the front) and placed with one node transform.
##
## Winding does not matter to the caller: faces are given with their outward normal and flipped to
## Godot's clockwise front faces here.

var _s := {}          # key -> {"v","n","uv","uv2","c","i"}
var xf := Transform3D.IDENTITY


func is_empty() -> bool:
	return _s.is_empty()


func surf(key: String) -> Dictionary:
	if not _s.has(key):
		_s[key] = {"v": PackedVector3Array(), "n": PackedVector3Array(), "uv": PackedVector2Array(),
			"uv2": PackedVector2Array(), "c": PackedColorArray(), "i": PackedInt32Array()}
	return _s[key]


func _vert(S: Dictionary, p: Vector3, n: Vector3, uv: Vector2, uv2: Vector2, c: Color) -> int:
	var va: PackedVector3Array = S["v"]
	var na: PackedVector3Array = S["n"]
	var ua: PackedVector2Array = S["uv"]
	var ub: PackedVector2Array = S["uv2"]
	var ca: PackedColorArray = S["c"]
	va.append(xf * p)
	na.append((xf.basis * n).normalized())
	ua.append(uv)
	ub.append(uv2)
	ca.append(c)
	return va.size() - 1


## One triangle with explicit outward normal.
func tri(key: String, a: Vector3, b: Vector3, c: Vector3, n: Vector3, col: Color, uva := Vector2.ZERO,
		uvb := Vector2.ZERO, uvc := Vector2.ZERO, uv2 := Vector2.ZERO) -> void:
	var S := surf(key)
	var g := (b - a).cross(c - a)
	var ia := _vert(S, a, n, uva, uv2, col)
	var ib := _vert(S, b, n, uvb, uv2, col)
	var ic := _vert(S, c, n, uvc, uv2, col)
	var idx: PackedInt32Array = S["i"]
	if g.dot(n) > 0.0:
		idx.append_array([ia, ic, ib])
	else:
		idx.append_array([ia, ib, ic])


## A quad p0..p3 (in order around the outline), outward normal n. uv: 4 Vector2 (optional).
## cols: 4 Colors for gradients (optional); otherwise `col`.
func quad(key: String, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, n: Vector3, col: Color,
		uv: Array = [], uv2 := Vector2.ZERO, cols: Array = []) -> void:
	var S := surf(key)
	var u0 := Vector2.ZERO
	var u1 := Vector2.ZERO
	var u2 := Vector2.ZERO
	var u3 := Vector2.ZERO
	if uv.size() == 4:
		u0 = uv[0]; u1 = uv[1]; u2 = uv[2]; u3 = uv[3]
	var c0 := col
	var c1 := col
	var c2 := col
	var c3 := col
	if cols.size() == 4:
		c0 = cols[0]; c1 = cols[1]; c2 = cols[2]; c3 = cols[3]
	var a := _vert(S, p0, n, u0, uv2, c0)
	var b := _vert(S, p1, n, u1, uv2, c1)
	var c := _vert(S, p2, n, u2, uv2, c2)
	var d := _vert(S, p3, n, u3, uv2, c3)
	var idx: PackedInt32Array = S["i"]
	var g := (p1 - p0).cross(p2 - p0)
	if g.dot(n) > 0.0:
		idx.append_array([a, c, b, a, d, c])
	else:
		idx.append_array([a, b, c, a, c, d])


## A vertical rectangle of a face frame: origin + right * u + up * v, spanning [u0,u1] x [v0,v1].
## UV = (u, v) in metres (so textures in the shader are metric), uv2 passed through.
func face(key: String, origin: Vector3, right: Vector3, out: Vector3, u0: float, u1: float, v0: float,
		v1: float, col: Color, uv2 := Vector2.ZERO) -> void:
	var up := Vector3.UP
	quad(key, origin + right * u0 + up * v0, origin + right * u1 + up * v0, origin + right * u1 + up * v1,
		origin + right * u0 + up * v1, out, col, [Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1)], uv2)


const FACE_MASK_ALL := 63   # +x -x +y -y +z -z

## An axis-aligned (in the current frame) box. skip: bit mask of faces to leave out (1 +x, 2 -x, 4 +y,
## 8 -y, 16 +z, 32 -z).
func box(key: String, center: Vector3, size: Vector3, col: Color, skip := 8, uv2 := Vector2.ZERO) -> void:
	var h := size * 0.5
	var c := center
	var x0 := c.x - h.x
	var x1 := c.x + h.x
	var y0 := c.y - h.y
	var y1 := c.y + h.y
	var z0 := c.z - h.z
	var z1 := c.z + h.z
	var t := col
	if not (skip & 1):
		quad(key, Vector3(x1, y0, z1), Vector3(x1, y0, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), Vector3.RIGHT, t.darkened(0.04),
			[Vector2(z1, y0), Vector2(z0, y0), Vector2(z0, y1), Vector2(z1, y1)], uv2)
	if not (skip & 2):
		quad(key, Vector3(x0, y0, z0), Vector3(x0, y0, z1), Vector3(x0, y1, z1), Vector3(x0, y1, z0), Vector3.LEFT, t.darkened(0.04),
			[Vector2(z0, y0), Vector2(z1, y0), Vector2(z1, y1), Vector2(z0, y1)], uv2)
	if not (skip & 4):
		quad(key, Vector3(x0, y1, z1), Vector3(x1, y1, z1), Vector3(x1, y1, z0), Vector3(x0, y1, z0), Vector3.UP, t.lightened(0.06),
			[Vector2(x0, z1), Vector2(x1, z1), Vector2(x1, z0), Vector2(x0, z0)], uv2)
	if not (skip & 8):
		quad(key, Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x0, y0, z1), Vector3.DOWN, t.darkened(0.25),
			[Vector2(x0, z0), Vector2(x1, z0), Vector2(x1, z1), Vector2(x0, z1)], uv2)
	if not (skip & 16):
		quad(key, Vector3(x0, y0, z1), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x0, y1, z1), Vector3.BACK, t,
			[Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)], uv2)
	if not (skip & 32):
		quad(key, Vector3(x1, y0, z0), Vector3(x0, y0, z0), Vector3(x0, y1, z0), Vector3(x1, y1, z0), Vector3.FORWARD, t,
			[Vector2(x1, y0), Vector2(x0, y0), Vector2(x0, y1), Vector2(x1, y1)], uv2)


## A box with an arbitrary orientation: `t` places its centre and axes; half = half extents.
func box_t(key: String, t: Transform3D, half: Vector3, col: Color, skip := 8) -> void:
	var old := xf
	xf = old * t
	box(key, Vector3.ZERO, half * 2.0, col, skip)
	xf = old


## A box between two points with a thickness (a rail, a strut).
func bar(key: String, a: Vector3, b: Vector3, thick: float, col: Color) -> void:
	var d := b - a
	var l := d.length()
	if l < 0.001:
		return
	var z := d / l
	var ref := Vector3.UP if absf(z.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	var x := ref.cross(z).normalized()
	var y := z.cross(x)
	box_t(key, Transform3D(Basis(x, y, z), (a + b) * 0.5), Vector3(thick * 0.5, thick * 0.5, l * 0.5), col, 0)


## A vertical cylinder (or truncated cone) with smooth sides. r1 = top radius (default = r0).
func cyl(key: String, base: Vector3, r0: float, height: float, segs: int, col: Color, r1 := -1.0,
		cap := true, uv2 := Vector2.ZERO) -> void:
	var rt := r0 if r1 < 0.0 else r1
	var step := TAU / segs
	for i in segs:
		var a0 := i * step
		var a1 := (i + 1) * step
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var slope := (r0 - rt) / maxf(height, 0.001)
		var n0 := (d0 + Vector3.UP * slope).normalized()
		var n1 := (d1 + Vector3.UP * slope).normalized()
		var sh0 := col.darkened(0.14 * (0.5 - 0.5 * cos(a0 - 0.8)))
		var sh1 := col.darkened(0.14 * (0.5 - 0.5 * cos(a1 - 0.8)))
		var S := surf(key)
		var ia := _vert(S, base + d0 * r0, n0, Vector2(i, 0), uv2, sh0)
		var ib := _vert(S, base + d1 * r0, n1, Vector2(i + 1, 0), uv2, sh1)
		var ic := _vert(S, base + d1 * rt + Vector3.UP * height, n1, Vector2(i + 1, height), uv2, sh1)
		var id := _vert(S, base + d0 * rt + Vector3.UP * height, n0, Vector2(i, height), uv2, sh0)
		var idx: PackedInt32Array = S["i"]
		var g := ((base + d1 * r0) - (base + d0 * r0)).cross((base + d1 * rt + Vector3.UP * height) - (base + d0 * r0))
		if g.dot(n0 + n1) > 0.0:
			idx.append_array([ia, ic, ib, ia, id, ic])
		else:
			idx.append_array([ia, ib, ic, ia, ic, id])
		if cap and rt > 0.001:
			tri(key, base + Vector3.UP * height, base + d0 * rt + Vector3.UP * height, base + d1 * rt + Vector3.UP * height,
				Vector3.UP, col.lightened(0.08))


## A low-poly sphere.
func sphere(key: String, c: Vector3, r: float, col: Color, segs := 8, rings := 5) -> void:
	for j in rings:
		var p0 := PI * j / rings
		var p1 := PI * (j + 1) / rings
		for i in segs:
			var a0 := TAU * i / segs
			var a1 := TAU * (i + 1) / segs
			var q := [Vector3(sin(p0) * cos(a0), cos(p0), sin(p0) * sin(a0)), Vector3(sin(p0) * cos(a1), cos(p0), sin(p0) * sin(a1)),
				Vector3(sin(p1) * cos(a1), cos(p1), sin(p1) * sin(a1)), Vector3(sin(p1) * cos(a0), cos(p1), sin(p1) * sin(a0))]
			var n: Vector3 = (q[0] + q[1] + q[2] + q[3]).normalized()
			quad(key, c + q[0] * r, c + q[1] * r, c + q[2] * r, c + q[3] * r, n, col.lightened(0.18 * maxf(n.y, 0.0)).darkened(0.18 * maxf(-n.y, 0.0)))


## Commit to a mesh: mats maps key -> Material. Unknown keys fall back to mats["trim"].
func commit(mats: Dictionary) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for key in _s:
		var S: Dictionary = _s[key]
		if (S["i"] as PackedInt32Array).is_empty():
			continue
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = S["v"]
		arr[Mesh.ARRAY_NORMAL] = S["n"]
		arr[Mesh.ARRAY_TEX_UV] = S["uv"]
		arr[Mesh.ARRAY_TEX_UV2] = S["uv2"]
		arr[Mesh.ARRAY_COLOR] = S["c"]
		arr[Mesh.ARRAY_INDEX] = S["i"]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		mesh.surface_set_material(mesh.get_surface_count() - 1, mats.get(key, mats["trim"]))
	return mesh
