extends RefCounted
## Mesh builder for one room: boxes, cylinders, spheres and quads merged into one ArrayMesh with one
## surface per material key (see mats.gd). Everything is drawn in the current transform `xf`, so a prop
## is written once in its own frame (origin on the floor at its centre, +Z its front, -Z its back).

const Mats := preload("res://scripts/world3d/rooms/mats.gd")

var surf := {}
var xf := Transform3D.IDENTITY
var _stack: Array = []
var verts := 0
var tint := Color(1, 1, 1, 1)   # multiplies every lit colour (a padlocked room is dim)


class Surf:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var uv := PackedVector2Array()
	var i := PackedInt32Array()


func _t(col: Color, key: String) -> Color:
	if tint == Color(1, 1, 1, 1) or key in ["e", "bulb", "pool", "dim", "gw"]:
		return col
	return Color(col.r * tint.r, col.g * tint.g, col.b * tint.b, col.a)


func _s(key: String) -> Surf:
	if not surf.has(key):
		surf[key] = Surf.new()
	return surf[key]


# ------------------------------------------------------------------ transforms

func push(t: Transform3D) -> void:
	_stack.append(xf)
	xf = xf * t


func pop() -> void:
	xf = _stack.pop_back()


## Enter a frame scaled by `sc` (loaves, sacks: squashed and stretched spheres).
func atx(pos: Vector3, yaw: float, sc: Vector3) -> void:
	push(Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(sc), pos))


## Enter a frame at `pos`, turned by `yaw` about Y (0 = +Z stays +Z), flattened in Y by `sy`.
func at(pos: Vector3, yaw: float = 0.0, sy: float = 1.0) -> void:
	var b := Basis(Vector3.UP, yaw)
	if sy != 1.0:
		b = b * Basis.from_scale(Vector3(1, sy, 1))
	push(Transform3D(b, pos))


# ------------------------------------------------------------------ primitives

## A quad given counter-clockwise seen from its visible side.
func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, key: String = "s", uv_a := Vector2(0, 0), uv_c := Vector2(1, 1)) -> void:
	var s := _s(key)
	var wa := xf * a
	var wb := xf * b
	var wc := xf * c
	var wd := xf * d
	col = _t(col, key)
	var n := (wb - wa).cross(wc - wa)
	if n.length_squared() < 1e-12:
		n = (wc - wa).cross(wd - wa)
	n = n.normalized()
	var base := s.v.size()
	s.v.append_array(PackedVector3Array([wa, wb, wc, wd]))
	s.n.append_array(PackedVector3Array([n, n, n, n]))
	s.c.append_array(PackedColorArray([col, col, col, col]))
	s.uv.append_array(PackedVector2Array([uv_a, Vector2(uv_c.x, uv_a.y), uv_c, Vector2(uv_a.x, uv_c.y)]))
	s.i.append_array(PackedInt32Array([base, base + 2, base + 1, base, base + 3, base + 2]))
	verts += 4


## A quad seen from both sides (glass, cloth, paper).
func quad2(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, key: String = "s") -> void:
	quad(a, b, c, d, col, key)
	quad(d, c, b, a, col, key)


func tri(a: Vector3, b: Vector3, c: Vector3, col: Color, key: String = "s") -> void:
	quad(a, b, c, c, col, key)
	quad(c, b, a, a, col, key)


## A flat rectangle lying on the floor-parallel plane at height y (visible from above).
func flat(x0: float, z0: float, x1: float, z1: float, y: float, col: Color, key: String = "s", uv_a := Vector2(0, 0), uv_c := Vector2(1, 1)) -> void:
	quad(Vector3(x0, y, z1), Vector3(x1, y, z1), Vector3(x1, y, z0), Vector3(x0, y, z0), col, key, uv_a, uv_c)


## An axis-aligned box (in the current frame). The bottom is left out when it sits on the floor.
func box(c: Vector3, sz: Vector3, col: Color, key: String = "s", bottom: bool = false) -> void:
	var h := sz * 0.5
	var x0 := c.x - h.x
	var x1 := c.x + h.x
	var y0 := c.y - h.y
	var y1 := c.y + h.y
	var z0 := c.z - h.z
	var z1 := c.z + h.z
	quad(Vector3(x0, y1, z1), Vector3(x1, y1, z1), Vector3(x1, y1, z0), Vector3(x0, y1, z0), col, key, Vector2(x0, z0), Vector2(x1, z1))
	quad(Vector3(x0, y0, z1), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x0, y1, z1), col, key, Vector2(x0, y0), Vector2(x1, y1))
	quad(Vector3(x1, y0, z0), Vector3(x0, y0, z0), Vector3(x0, y1, z0), Vector3(x1, y1, z0), col, key, Vector2(x0, y0), Vector2(x1, y1))
	quad(Vector3(x1, y0, z1), Vector3(x1, y0, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), col, key, Vector2(z0, y0), Vector2(z1, y1))
	quad(Vector3(x0, y0, z0), Vector3(x0, y0, z1), Vector3(x0, y1, z1), Vector3(x0, y1, z0), col, key, Vector2(z0, y0), Vector2(z1, y1))
	if bottom or y0 > 0.02:
		quad(Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x0, y0, z1), col, key, Vector2(x0, z0), Vector2(x1, z1))


## A box from corner a to corner b.
func boxc(a: Vector3, b: Vector3, col: Color, key: String = "s") -> void:
	box((a + b) * 0.5, (b - a).abs(), col, key)


## A box standing on the floor: centre x/z, width, depth, height.
func blk(x: float, z: float, w: float, d: float, h: float, col: Color, key: String = "s", y0: float = 0.0) -> void:
	box(Vector3(x, y0 + h * 0.5, z), Vector3(w, h, d), col, key)


## A vertical cylinder (frustum when r_top >= 0), centred at `c`, `h` tall.
func cyl(c: Vector3, r: float, h: float, col: Color, key: String = "s", seg: int = 10, r_top: float = -1.0, caps: bool = true) -> void:
	var rt := r if r_top < 0.0 else r_top
	col = _t(col, key)
	var s := _s(key)
	var y0 := c.y - h * 0.5
	var y1 := c.y + h * 0.5
	var slope := r - rt
	var vv := s.v
	var nn := s.n
	var cc := s.c
	var uu := s.uv
	var ii := s.i
	var base := vv.size()
	var lin := xf.basis
	for i in seg + 1:
		var a := TAU * float(i) / float(seg)
		var ca := cos(a)
		var sa := sin(a)
		var nrm := (lin * Vector3(ca * h, slope, sa * h)).normalized()
		vv.append(xf * Vector3(c.x + ca * r, y0, c.z + sa * r))
		vv.append(xf * Vector3(c.x + ca * rt, y1, c.z + sa * rt))
		nn.append(nrm)
		nn.append(nrm)
		cc.append(col)
		cc.append(col)
		uu.append(Vector2(float(i) / float(seg) * r * TAU, y0))
		uu.append(Vector2(float(i) / float(seg) * r * TAU, y1))
	for i in seg:
		var k := base + i * 2
		ii.append_array(PackedInt32Array([k, k + 2, k + 1, k + 1, k + 2, k + 3]))
	verts += (seg + 1) * 2
	if caps and rt > 0.001:
		_disc(s, Vector3(c.x, y1, c.z), rt, col, seg, true)
	if caps and r > 0.001 and y0 > 0.02:
		_disc(s, Vector3(c.x, y0, c.z), r, col, seg, false)


func _disc(s: Surf, c: Vector3, r: float, col: Color, seg: int, up: bool) -> void:
	var vv := s.v
	var nn := s.n
	var cc := s.c
	var uu := s.uv
	var ii := s.i
	var base := vv.size()
	var n := (xf.basis * Vector3(0, 1.0 if up else -1.0, 0)).normalized()
	vv.append(xf * c)
	nn.append(n)
	cc.append(col)
	uu.append(Vector2(c.x, c.z))
	for i in seg + 1:
		var a := TAU * float(i) / float(seg)
		vv.append(xf * Vector3(c.x + cos(a) * r, c.y, c.z + sin(a) * r))
		nn.append(n)
		cc.append(col)
		uu.append(Vector2(c.x + cos(a) * r, c.z + sin(a) * r))
	for i in seg:
		if up:
			ii.append_array(PackedInt32Array([base, base + 1 + i, base + 2 + i]))
		else:
			ii.append_array(PackedInt32Array([base, base + 2 + i, base + 1 + i]))
	verts += seg + 2


## A cylinder along an arbitrary axis (barrels on their side, pipes, bolts of cloth).
func cyl_dir(c: Vector3, dir: Vector3, r: float, len: float, col: Color, key: String = "s", seg: int = 8, r_end: float = -1.0) -> void:
	var d := dir.normalized()
	var b := Basis(Quaternion(Vector3.UP, d))
	push(Transform3D(b, c))
	cyl(Vector3.ZERO, r, len, col, key, seg, r_end)
	pop()


## A thin cylinder between two points.
func rod(a: Vector3, b: Vector3, r: float, col: Color, key: String = "s", seg: int = 6) -> void:
	var d := b - a
	if d.length() < 0.001:
		return
	cyl_dir((a + b) * 0.5, d, r, d.length(), col, key, seg)


## A (squashed) sphere: loaves, cabbages, bulbs, hats.
func sph(c: Vector3, r: float, col: Color, key: String = "s", seg: int = 8, rings: int = 5, sy: float = 1.0) -> void:
	col = _t(col, key)
	var s := _s(key)
	var vv := s.v
	var nn := s.n
	var cc := s.c
	var uu := s.uv
	var ii := s.i
	var base := vv.size()
	for j in rings + 1:
		var pa := PI * float(j) / float(rings)
		var y := cos(pa)
		var rr := sin(pa)
		for i in seg + 1:
			var a := TAU * float(i) / float(seg)
			var p := Vector3(cos(a) * rr, y * sy, sin(a) * rr)
			vv.append(xf * (c + p * r))
			nn.append((xf.basis * Vector3(cos(a) * rr, y / maxf(sy, 0.05), sin(a) * rr)).normalized())
			cc.append(col)
			uu.append(Vector2(float(i) / float(seg), float(j) / float(rings)))
	for j in rings:
		for i in seg:
			var k := base + j * (seg + 1) + i
			ii.append_array(PackedInt32Array([k, k + seg + 1, k + 1, k + 1, k + seg + 1, k + seg + 2]))
	verts += (rings + 1) * (seg + 1)


## A horizontal hoop of thin box segments (barrel bands, wheels, rims).
func hoop(c: Vector3, r: float, th: float, h: float, col: Color, key: String = "m", seg: int = 10) -> void:
	for i in seg:
		var a0 := TAU * float(i) / float(seg)
		var a1 := TAU * float(i + 1) / float(seg)
		var p0 := c + Vector3(cos(a0) * r, 0, sin(a0) * r)
		var p1 := c + Vector3(cos(a1) * r, 0, sin(a1) * r)
		var ln := p0.distance_to(p1)
		push(Transform3D(Basis(Vector3.UP, atan2(p1.x - p0.x, p1.z - p0.z)), (p0 + p1) * 0.5))
		box(Vector3.ZERO, Vector3(th, h, ln * 1.05), col, key, true)
		pop()


# ------------------------------------------------------------------ output

const ORDER := ["s", "wp", "chk", "m", "e", "bulb", "dirt", "g", "gw", "pool", "dim"]


func finish() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var keys := surf.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return _rank(a) < _rank(b))
	for key in keys:
		var s: Surf = surf[key]
		if s.v.is_empty():
			continue
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = s.v
		arr[Mesh.ARRAY_NORMAL] = s.n
		arr[Mesh.ARRAY_COLOR] = s.c
		arr[Mesh.ARRAY_TEX_UV] = s.uv
		arr[Mesh.ARRAY_INDEX] = s.i
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		mesh.surface_set_material(mesh.get_surface_count() - 1, Mats.get_mat(String(key)))
	return mesh


static func _rank(k: String) -> int:
	if k.begins_with("f:") or k.begins_with("rug:"):
		return 0
	var i := ORDER.find(k)
	return 1 + (i if i >= 0 else 0)
