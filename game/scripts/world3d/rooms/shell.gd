extends RefCounted
## Floors, walls (with wainscot and wallpaper), glass, doors and door frames of an interior, in the room frame
## (lot-local metres: x along the front, +z out of the front door, y up). See interiors3d.gd.

const MB := preload("res://scripts/world3d/rooms/mb.gd")
const P := preload("res://scripts/world3d/rooms/parts.gd")
const Mats := preload("res://scripts/world3d/rooms/mats.gd")

const M := 48.0
const H_LOW := 1.2         # walls seen across (east-west in the world): cut low so the camera sees over them
const H_SIDE := 1.9        # walls seen edge-on (north-south in the world)
const H_NORTH := 2.7       # the far wall of a room (north in the world): a proper backdrop
const WT := 0.25

## Wall themes by trade: [wainscot colour, wainscot height, upper colour, wallpaper (striped) or plain]
const THEMES := {
	"bakery": [Color("ece4d2"), 1.3, Color("e8dcc0"), false],
	"butcher": [Color("e4e0d2"), 1.7, Color("e4e0d2"), false],
	"fish": [Color("5a8a7a"), 1.5, Color("dcd8c6"), false],
	"grocer": [Color("6a4a30"), 0.95, Color("d8c8a0"), true],
	"tailor": [Color("5a2e22"), 1.0, Color("7a3a3e"), true],
	"barber": [Color("3a6a58"), 1.1, Color("e0d8c0"), false],
	"cobbler": [Color("6a4a30"), 0.95, Color("c8b690"), false],
	"pawnshop": [Color("3a2a20"), 1.0, Color("a88c64"), true],
	"laundry": [Color("e0e4de"), 1.4, Color("d8e0dc"), false],
	"restaurant": [Color("4a2a20"), 1.0, Color("a83a34"), true],
	"cafe": [Color("6a4a30"), 1.0, Color("d8c8a4"), true],
	"candy": [Color("e8c8c8"), 1.1, Color("f0e4d8"), true],
	"hardware": [Color("7a5a3a"), 0.9, Color("b8a478"), false],
	"drugstore": [Color("3a2a22"), 1.0, Color("a8b8a0"), true],
	"cigar": [Color("3a2418"), 1.1, Color("7a5a3a"), true],
	"club": [Color("4a2218"), 1.1, Color("7a2a2e"), true],
	"poolhall": [Color("2a4a38"), 1.0, Color("b0a078"), false],
	"precinct": [Color("4a6a58"), 1.2, Color("d8d4be"), false],
	"warehouse": [Color("7a4a3a"), 3.0, Color("7a4a3a"), false],
}


static func theme(kind: String) -> Array:
	return THEMES.get(kind, [Color("6a4a30"), 1.0, Color("d9ccb0"), false])


# ------------------------------------------------------------------ floors

static func floor_quad(mb: MB, x0: float, z0: float, x1: float, z1: float, style: String) -> void:
	var sz := Mats.floor_size(style)
	mb.flat(x0, z0, x1, z1, 0.0, Color(1, 1, 1), "f:" + style, Vector2(x0 / sz.x, z1 / sz.y), Vector2(x1 / sz.x, z0 / sz.y))


# ------------------------------------------------------------------ walls

static func wall_height(world_ew: bool, north: bool) -> float:
	if world_ew:
		return H_NORTH if north else H_LOW
	return H_SIDE


## One wall piece from (x0,z0) to (x1,z1) (metres), given its theme, height and orientation.
static func slab(mb: MB, x0: float, z0: float, x1: float, z1: float, y0: float, y1: float, th: Array, style: String, cap: bool = true) -> void:
	var cx := (x0 + x1) * 0.5
	var cz := (z0 + z1) * 0.5
	var sx := x1 - x0
	var sz := z1 - z0
	if sx < 0.01 or sz < 0.01 or y1 - y0 < 0.01:
		return
	var wain: Color = th[0]
	var wh: float = minf(float(th[1]), y1)
	var upper: Color = th[2]
	var papered: bool = th[3]
	var outer := style in ["front", "side", "back"]
	if outer and th[1] >= 3.0:
		# warehouse: bare brick inside
		mb.box(Vector3(cx, (y0 + y1) * 0.5, cz), Vector3(sx - 0.02, y1 - y0, sz - 0.02), wain.lightened(0.04 * (cx - floorf(cx))), "s", true)
		mb.box(Vector3(cx, y1 + 0.02, cz), Vector3(sx, 0.05, sz), wain.darkened(0.3), "s", true)
		return
	var tx := sx - 0.02 if sx < sz else sx
	var tz := sz - 0.02 if sz <= sx else sz
	if y0 >= wh - 0.001:
		mb.box(Vector3(cx, (y0 + y1) * 0.5, cz), Vector3(tx, y1 - y0, tz), upper, "wp" if papered else "s", true)
	else:
		mb.box(Vector3(cx, (y0 + wh) * 0.5, cz), Vector3(tx, wh - y0, tz), wain, "s", true)
		if y1 > wh:
			mb.box(Vector3(cx, (wh + y1) * 0.5, cz), Vector3(tx - (0.012 if sx < sz else 0.0), y1 - wh, tz - (0.0 if sx < sz else 0.012)), upper, "wp" if papered else "s", true)
			# chair rail
			mb.box(Vector3(cx, wh, cz), Vector3(tx + (0.035 if sx < sz else 0.0), 0.05, tz + (0.0 if sx < sz else 0.035)), wain.darkened(0.25), "s", true)
	if y0 < 0.01:
		mb.box(Vector3(cx, 0.06, cz), Vector3(tx + (0.03 if sx < sz else 0.0), 0.12, tz + (0.0 if sx < sz else 0.03)), wain.darkened(0.45), "s", true)
	if cap:
		mb.box(Vector3(cx, y1 + 0.02, cz), Vector3(sx, 0.045, sz), Color("4a3a30") if not outer else Color("3a302a"), "s", true)


## Iron bars (jail cell fronts).
static func bars(mb: MB, x0: float, z0: float, x1: float, z1: float) -> void:
	var horiz := (x1 - x0) >= (z1 - z0)
	var iron := Color("26282c")
	var h := 1.7
	var cx := (x0 + x1) * 0.5
	var cz := (z0 + z1) * 0.5
	if horiz:
		mb.box(Vector3(cx, 0.08, cz), Vector3(x1 - x0, 0.14, 0.07), iron, "m", true)
		mb.box(Vector3(cx, h, cz), Vector3(x1 - x0, 0.07, 0.08), iron, "m", true)
		var x := x0 + 0.06
		while x < x1 - 0.03:
			mb.cyl(Vector3(x, h * 0.5, cz), 0.014, h, iron, "m", 5)
			x += 0.115
	else:
		mb.box(Vector3(cx, 0.08, cz), Vector3(0.07, 0.14, z1 - z0), iron, "m", true)
		mb.box(Vector3(cx, h, cz), Vector3(0.08, 0.07, z1 - z0), iron, "m", true)
		var z := z0 + 0.06
		while z < z1 - 0.03:
			mb.cyl(Vector3(cx, h * 0.5, z), 0.014, h, iron, "m", 5)
			z += 0.115


## A glazed partition (the warehouse office).
static func glass_wall(mb: MB, x0: float, z0: float, x1: float, z1: float) -> void:
	var horiz := (x1 - x0) >= (z1 - z0)
	var wood := Color("8a6a44")
	var cx := (x0 + x1) * 0.5
	var cz := (z0 + z1) * 0.5
	var len := (x1 - x0) if horiz else (z1 - z0)
	mb.box(Vector3(cx, 0.45, cz), Vector3((x1 - x0) if horiz else 0.1, 0.9, 0.1 if horiz else (z1 - z0)), wood, "s", true)
	mb.box(Vector3(cx, 1.8, cz), Vector3((x1 - x0) if horiz else 0.1, 0.07, 0.1 if horiz else (z1 - z0)), wood, "s", true)
	var gc := Color(1, 1, 1, 1)
	if horiz:
		mb.quad2(Vector3(x0, 0.9, cz), Vector3(x1, 0.9, cz), Vector3(x1, 1.8, cz), Vector3(x0, 1.8, cz), gc, "gw")
	else:
		mb.quad2(Vector3(cx, 0.9, z0), Vector3(cx, 0.9, z1), Vector3(cx, 1.8, z1), Vector3(cx, 1.8, z0), gc, "gw")
	var t := 0.9
	while t < len - 0.2:
		if horiz:
			mb.box(Vector3(x0 + t, 1.35, cz), Vector3(0.05, 0.9, 0.08), wood, "s", true)
		else:
			mb.box(Vector3(cx, 1.35, z0 + t), Vector3(0.08, 0.9, 0.05), wood, "s", true)
		t += 0.9


## A window set into a wall: sill, glass (or its broken teeth), mullions and a header.
static func window(mb: MB, x0: float, z0: float, x1: float, z1: float, wall_h: float, th: Array, broken: bool, sd: int, outer: bool) -> void:
	var horiz := (x1 - x0) >= (z1 - z0)
	var low := wall_h < 2.0
	var sill := 0.5 if low else 0.9
	var head := wall_h if low else minf(2.35, wall_h - 0.2)
	var cx := (x0 + x1) * 0.5
	var cz := (z0 + z1) * 0.5
	var frame := Color("3a2a1e")
	slab(mb, x0, z0, x1, z1, 0.0, sill, th, "front", false)
	if not low and wall_h - head > 0.05:
		slab(mb, x0, z0, x1, z1, head, wall_h, th, "front", false)
	mb.box(Vector3(cx, sill + 0.015, cz), Vector3((x1 - x0) + 0.0 if horiz else (x1 - x0) + 0.05, 0.03, (z1 - z0) + 0.05 if horiz else (z1 - z0)), Color("a47b50"), "s", true)
	mb.box(Vector3(cx, head, cz), Vector3((x1 - x0) if horiz else 0.1, 0.04, 0.1 if horiz else (z1 - z0)), frame, "s", true)
	var len := (x1 - x0) if horiz else (z1 - z0)
	var gh := head - sill - 0.03
	if not broken:
		var gc := Color(1, 1, 1, 1)
		if horiz:
			mb.quad2(Vector3(x0, sill + 0.03, cz), Vector3(x1, sill + 0.03, cz), Vector3(x1, head, cz), Vector3(x0, head, cz), gc, "gw")
		else:
			mb.quad2(Vector3(cx, sill + 0.03, z0), Vector3(cx, sill + 0.03, z1), Vector3(cx, head, z1), Vector3(cx, head, z0), gc, "gw")
	else:
		# a few teeth of glass left standing in the frame
		var n := maxi(3, int(len / 0.3))
		for j in n:
			var a := len * float(j) / n
			var b := len * float(j + 1) / n
			var tip := 0.1 + P.hf(j, 1, sd) * gh * 0.5
			var bottom := j % 2 == 0
			var y_a := sill + 0.03 if bottom else head
			var y_t := y_a + (tip if bottom else -tip)
			var mid := (a + b) * 0.5 + (P.hf(j, 2, sd) - 0.5) * 0.08
			var gc2 := Color(0.85, 0.94, 1.0, 0.55)
			if horiz:
				mb.quad2(Vector3(x0 + a, y_a, cz), Vector3(x0 + b, y_a, cz), Vector3(x0 + mid, y_t, cz), Vector3(x0 + mid, y_t, cz), gc2, "g")
			else:
				mb.quad2(Vector3(cx, y_a, z0 + a), Vector3(cx, y_a, z0 + b), Vector3(cx, y_t, z0 + mid), Vector3(cx, y_t, z0 + mid), gc2, "g")
	# mullions
	var step := 0.8
	var t := step
	while t < len - 0.3:
		if horiz:
			mb.box(Vector3(x0 + t, (sill + head) * 0.5, cz), Vector3(0.04, head - sill, 0.07), frame, "s", true)
		else:
			mb.box(Vector3(cx, (sill + head) * 0.5, z0 + t), Vector3(0.07, head - sill, 0.04), frame, "s", true)
		t += step
	# the side posts
	if horiz:
		mb.box(Vector3(x0 + 0.02, (sill + head) * 0.5, cz), Vector3(0.05, head - sill, 0.09), frame, "s", true)
		mb.box(Vector3(x1 - 0.02, (sill + head) * 0.5, cz), Vector3(0.05, head - sill, 0.09), frame, "s", true)
	else:
		mb.box(Vector3(cx, (sill + head) * 0.5, z0 + 0.02), Vector3(0.09, head - sill, 0.05), frame, "s", true)
		mb.box(Vector3(cx, (sill + head) * 0.5, z1 - 0.02), Vector3(0.09, head - sill, 0.05), frame, "s", true)
	var _o := outer


## A loading door: corrugated steel, closed.
static func loading_door(mb: MB, x0: float, z0: float, x1: float, z1: float, h: float) -> void:
	var horiz := (x1 - x0) >= (z1 - z0)
	var steel := Color("6a5448")
	var hh := minf(h, 2.9)
	var cx := (x0 + x1) * 0.5
	var cz := (z0 + z1) * 0.5
	mb.box(Vector3(cx, hh * 0.5, cz), Vector3((x1 - x0) - 0.02 if horiz else 0.08, hh, 0.08 if horiz else (z1 - z0) - 0.02), steel, "s", true)
	var len := (x1 - x0) if horiz else (z1 - z0)
	var t := 0.15
	while t < len:
		if horiz:
			mb.box(Vector3(x0 + t, hh * 0.5, cz + 0.04), Vector3(0.03, hh - 0.1, 0.02), steel.darkened(0.25), "s", true)
		else:
			mb.box(Vector3(cx + 0.04, hh * 0.5, z0 + t), Vector3(0.02, hh - 0.1, 0.03), steel.darkened(0.25), "s", true)
		t += 0.3
	mb.box(Vector3(cx, hh + 0.04, cz), Vector3((x1 - x0) if horiz else 0.12, 0.08, 0.12 if horiz else (z1 - z0)), Color("3a3e40"), "m", true)


# ------------------------------------------------------------------ doors

## Frame, threshold and the leaf of a door. `p` is the doorway centre, `w` its width (metres), `along` the way
## the wall runs (local x = (1,0), local z = (0,1)), `out` the unit vector out of the room.
static func door(mb: MB, p: Vector2, w: float, along: Vector2, out: Vector2, kind: String, wall_h: float, closed: bool, sd: int) -> void:
	var horiz := absf(along.x) > 0.5
	var across := Vector2(0, 1) if horiz else Vector2(1, 0)
	var th := WT
	var frame := Color("3a2a1e") if kind != "cell" else Color("26282c")
	var h := minf(2.1, wall_h + 0.1) if wall_h < 2.0 else 2.1
	var tall := wall_h > 2.2
	var half := w * 0.5
	# the threshold
	mb.box(Vector3(p.x, 0.012, p.y), Vector3(w if horiz else th + 0.04, 0.024, th + 0.04 if horiz else w), Color("8a6a44") if kind != "cell" else Color("3a3e40"), "s", true)
	for s: float in [-1.0, 1.0]:
		var pc := p + along * (half + 0.035) * s
		mb.box(Vector3(pc.x, h * 0.5, pc.y), Vector3(0.07 if horiz else th + 0.04, h, th + 0.04 if horiz else 0.07), frame, "s", true)
	if tall:
		mb.box(Vector3(p.x, h + 0.04, p.y), Vector3(w + 0.14 if horiz else th + 0.04, 0.08, th + 0.04 if horiz else w + 0.14), frame, "s", true)
	if closed and kind == "front":
		# boards nailed across, a chain and a padlock
		var o3 := Vector3(out.x, 0, out.y)
		for j in 2:
			var yy := 0.55 + j * 0.85
			var ang := 0.3 if j == 0 else -0.3
			var dirv := Vector3(along.x, ang * 1.5, along.y).normalized()
			mb.cyl_dir(Vector3(p.x, yy, p.y) + o3 * 0.1, dirv, 0.04, w * 1.2, Color("7a6040"), "s", 4)
		mb.sph(Vector3(p.x, 0.95, p.y) + o3 * 0.14, 0.05, Color("c9a54a"), "m", 6, 4)
		mb.cyl(Vector3(p.x, 1.05, p.y) + o3 * 0.14, 0.012, 0.1, Color("8a8e92"), "m", 5)
		return
	# the leaf stands open against the wall on the room side (away from `out`)
	var inward := -out
	if kind == "cell":
		# a barred gate swung open outward along the wall
		var hinge := p + along * (half - 0.04) + out * 0.12
		var tip := hinge + out * (w - 0.1)
		mb.rod(Vector3(hinge.x, 0.1, hinge.y), Vector3(tip.x, 0.1, tip.y), 0.02, frame, "m", 5)
		mb.rod(Vector3(hinge.x, 1.6, hinge.y), Vector3(tip.x, 1.6, tip.y), 0.02, frame, "m", 5)
		for k in 7:
			var q := hinge.lerp(tip, float(k) / 6.0)
			mb.rod(Vector3(q.x, 0.1, q.y), Vector3(q.x, 1.6, q.y), 0.012, frame, "m", 4)
		return
	var leaf_h := minf(2.0, h - 0.06)
	var wood := Color("6a4630")
	if kind == "front":
		for s: float in [-1.0, 1.0]:
			var hinge2 := p + along * (half - 0.03) * s + inward * 0.08
			var tip2 := hinge2 + inward * (half - 0.06)
			_leaf(mb, hinge2, tip2, leaf_h, wood, true)
	else:
		var hinge3 := p - along * (half - 0.04) + inward * 0.08
		var tip3 := hinge3 + inward * (w - 0.1)
		_leaf(mb, hinge3, tip3, leaf_h, wood, false)
	var _s := sd


static func _leaf(mb: MB, a: Vector2, b: Vector2, h: float, wood: Color, glazed: bool) -> void:
	var mid := (a + b) * 0.5
	var dv := b - a
	var ln := dv.length()
	mb.push(Transform3D(Basis(Vector3.UP, atan2(dv.x, dv.y)), Vector3(mid.x, 0, mid.y)))
	mb.box(Vector3(0, h * 0.5, 0), Vector3(0.045, h, ln), wood, "s", true)
	mb.box(Vector3(0.0, h * 0.5, 0), Vector3(0.05, h * 0.55, ln * 0.7), wood.lightened(0.07), "s", true)
	if glazed:
		mb.box(Vector3(0.0, h * 0.72, 0), Vector3(0.05, h * 0.3, ln * 0.62), Color(0.6, 0.78, 0.86, 0.5), "g", true)
	mb.box(Vector3(0.04, h * 0.5, ln * 0.4), Vector3(0.03, 0.03, 0.08), Color("d2aa4a"), "m", true)
	mb.pop()
