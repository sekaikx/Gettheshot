class_name G3Props
extends RefCounted
## Street furniture prefabs. Each draws into a G3Bundle.Cell with the origin on the ground at the
## prop's foot, local +z toward the street (the cell already has push_at applied by the caller) and
## local +x along the kerb. Heights are metres above `y0` (the sidewalk top).

const IRON := Color("2b2e2d")
const IRON_HI := Color("4b504c")
const WOOD := Color("6a4a30")
const LEAF := [Color("5a7c44"), Color("668a4a"), Color("4e7040"), Color("72904e")]
const AWN := [Color("7a2e2a"), Color("2e4a3a"), Color("2a3a5a"), Color("8a6a2a"), Color("5a3a5a"), Color("3a5a5a")]


static func r01(s: int, k: int) -> float:
	return GroundUtil.r01(s, k)


static func rr(s: int, k: int, a: float, b: float) -> float:
	return GroundUtil.rr(s, k, a, b)


## Lamp post with an arm over the street and a glowing lantern. Returns the head's local position.
static func lamp(c: G3Bundle.Cell, s: int) -> Vector3:
	var m := c.metal
	m.cyl(Vector3(0, 0, 0), 0.19, 0.12, 0.34, 8, IRON)
	m.cyl(Vector3(0, 0.34, 0), 0.12, 0.075, 0.36, 8, IRON)
	m.cyl(Vector3(0, 0.7, 0), 0.075, 0.062, 3.0, 8, IRON)
	m.cyl(Vector3(0, 1.45, 0), 0.1, 0.1, 0.06, 8, IRON_HI)
	m.cyl(Vector3(0, 3.65, 0), 0.085, 0.06, 0.1, 8, IRON_HI)
	# the arm curls out over the road
	m.rod(Vector3(0, 3.6, 0), Vector3(0, 3.95, 0.5), 0.028, IRON)
	m.rod(Vector3(0, 3.95, 0.5), Vector3(0, 3.98, 1.12), 0.028, IRON)
	var head := Vector3(0, 3.86, 1.12)
	m.cyl(Vector3(head.x, 3.97, head.z), 0.05, 0.05, 0.1, 6, IRON)
	m.cyl(Vector3(head.x, 3.84, head.z), 0.3, 0.02, 0.15, 8, IRON_HI)
	c.glow.cyl(Vector3(head.x, 3.45, head.z), 0.15, 0.2, 0.4, 8, Color(1.0, 0.82, 0.55), false)
	c.glow.disc(Vector3(head.x, 3.45, head.z), 0.15, 8, Color(1.0, 0.82, 0.55))
	m.cyl(Vector3(head.x, 3.42, head.z), 0.1, 0.05, 0.05, 6, IRON)
	# a pasted bill on the shaft on some
	if r01(s, 5) < 0.5:
		c.props.box(Vector3(0, 1.75, 0.075), Vector3(0.2, 0.3, 0.012), Color("d9d1b8").darkened(rr(s, 6, 0.0, 0.2)))
	return head


static func hydrant(c: G3Bundle.Cell, s: int) -> void:
	var col := Color("7b2a22") if r01(s, 1) < 0.7 else Color("3a3d3c")
	var m := c.metal
	m.cyl(Vector3(0, 0, 0), 0.16, 0.14, 0.1, 8, col.darkened(0.3))
	m.cyl(Vector3(0, 0.1, 0), 0.125, 0.11, 0.45, 8, col)
	m.cyl(Vector3(0, 0.55, 0), 0.14, 0.14, 0.05, 8, col.lightened(0.1))
	m.cyl(Vector3(0, 0.6, 0), 0.115, 0.06, 0.12, 8, col)
	m.cyl(Vector3(0, 0.72, 0), 0.04, 0.04, 0.05, 6, col.lightened(0.15))
	for sx in [-1.0, 1.0]:
		m.cyl(Vector3(sx * 0.14, 0.4, 0), 0.06, 0.06, 0.07, 6, col.lightened(0.1))
		c.metal.box(Vector3(sx * 0.2, 0.4, 0), Vector3(0.06, 0.1, 0.1), IRON_HI)
	m.box(Vector3(0, 0.34, 0.16), Vector3(0.14, 0.14, 0.1), col.lightened(0.08))


static func mailbox(c: G3Bundle.Cell, _s: int) -> void:
	var blue := Color("2a4466")
	var m := c.metal
	for sx in [-0.16, 0.16]:
		m.box(Vector3(sx, 0.2, 0), Vector3(0.05, 0.4, 0.05), IRON)
	m.box(Vector3(0, 0.75, 0), Vector3(0.4, 0.55, 0.32), blue)
	m.blob(Vector3(0, 1.03, 0), Vector3(0.21, 0.13, 0.17), blue.lightened(0.06), 2, 8)
	m.box(Vector3(0, 0.9, 0.165), Vector3(0.24, 0.035, 0.012), Color("151a22"))
	m.box(Vector3(0, 0.62, 0.165), Vector3(0.2, 0.1, 0.012), Color("c9b070"))


static func callbox(c: G3Bundle.Cell, _s: int) -> void:
	var blue := Color("24384f")
	c.metal.box(Vector3(0, 0.7, 0), Vector3(0.3, 1.4, 0.28), blue)
	c.metal.box(Vector3(0, 1.45, 0), Vector3(0.36, 0.08, 0.34), blue.darkened(0.2))
	c.metal.box(Vector3(0, 1.05, 0.145), Vector3(0.18, 0.22, 0.012), Color("151a22"))
	c.glow.cyl(Vector3(0, 1.49, 0), 0.08, 0.1, 0.16, 6, Color(0.5, 0.7, 1.0))


static func alarm(c: G3Bundle.Cell, _s: int) -> void:
	var red := Color("8a2a22")
	c.metal.cyl(Vector3(0, 0, 0), 0.07, 0.05, 1.5, 6, IRON)
	c.metal.box(Vector3(0, 1.58, 0), Vector3(0.3, 0.3, 0.26), red)
	c.metal.box(Vector3(0, 1.58, 0.135), Vector3(0.14, 0.12, 0.012), Color("e8dcc0"))
	c.glow.cyl(Vector3(0, 1.74, 0), 0.07, 0.07, 0.12, 6, Color(1.0, 0.35, 0.28))


static func ashcans(c: G3Bundle.Cell, s: int, count: int) -> void:
	for k in count:
		var x := (float(k) - (count - 1) * 0.5) * 0.52
		var z := rr(s, 10 + k, -0.04, 0.04)
		var col := Color("8e9293").darkened(rr(s, 20 + k, 0.0, 0.25))
		c.props.cyl(Vector3(x, 0, z), 0.23, 0.25, 0.7, 10, col, true, col.lightened(0.12))
		c.props.cyl(Vector3(x, 0.7, z), 0.26, 0.18, 0.08, 10, col.darkened(0.1), true, col.lightened(0.2))
		c.props.cyl(Vector3(x, 0.78, z), 0.04, 0.04, 0.05, 6, col.darkened(0.3))
		for ry in [0.2, 0.45]:
			c.props.cyl(Vector3(x, ry, z), 0.248, 0.248, 0.025, 10, col.darkened(0.2), false)
		if r01(s, 30 + k) < 0.4:
			c.props.box(Vector3(x + 0.03, 0.83, z), Vector3(0.22, 0.012, 0.16), Color("d9d1b8"))


static func bench(c: G3Bundle.Cell, s: int) -> void:
	var wood := Color("6b4a2e") if r01(s, 1) < 0.5 else Color("3d5846")
	for sx in [-0.78, 0.78]:
		c.metal.box(Vector3(sx, 0.2, 0), Vector3(0.06, 0.4, 0.44), IRON)
		c.metal.box(Vector3(sx, 0.62, -0.2), Vector3(0.06, 0.45, 0.06), IRON)
		c.metal.box(Vector3(sx, 0.45, 0.0), Vector3(0.1, 0.05, 0.5), IRON_HI)
	for k in 3:
		c.wood.box(Vector3(0, 0.44, -0.16 + float(k) * 0.14), Vector3(1.7, 0.04, 0.1), wood.lightened(rr(s, 3 + k, -0.06, 0.08)))
	for k in 2:
		c.wood.box(Vector3(0, 0.62 + float(k) * 0.14, -0.22), Vector3(1.7, 0.1, 0.035), wood.lightened(rr(s, 8 + k, -0.06, 0.08)))


static func newsstand(c: G3Bundle.Cell, s: int) -> void:
	var green := Color("2e4a3a")
	var body := Color("4a3a2c")
	c.props.box(Vector3(0, 0.55, -0.1), Vector3(1.85, 1.1, 0.6), body)
	# counter shelf on the street side, with papers and magazines fanned out
	c.props.box(Vector3(0, 0.95, 0.28), Vector3(1.9, 0.05, 0.36), Color("5a4632"))
	var x := -0.85
	var k := 0
	while x < 0.85:
		k += 1
		var pw := rr(s, k, 0.14, 0.2)
		var mag := r01(s, 20 + k) < 0.25
		var pc: Color = AWN[GroundUtil.ri(s, 30 + k, 0, 5)].lightened(0.25) if mag else Color("e6dcc3").darkened(rr(s, 40 + k, 0.0, 0.14))
		c.props.box(Vector3(x + pw * 0.5, 1.0, 0.3), Vector3(pw * 0.92, 0.012, 0.3), pc)
		x += pw + 0.02
	# posts and the tin roof, two slopes with a ridge, a hanging bulb
	for sx in [-0.92, 0.92]:
		c.metal.box(Vector3(sx, 1.15, 0.38), Vector3(0.05, 2.3, 0.05), green.darkened(0.2))
		c.metal.box(Vector3(sx, 1.15, -0.4), Vector3(0.05, 2.3, 0.05), green.darkened(0.2))
	c.props.box(Vector3(0, 1.75, -0.4), Vector3(1.85, 0.8, 0.05), body.darkened(0.1))
	c.props.gable(Vector3(0, 2.2, -0.02), 2.1, 1.0, 0.28, green, green.darkened(0.25), true)
	c.props.box(Vector3(0, 2.45, -0.02), Vector3(2.1, 0.03, 0.03), green.lightened(0.3))
	c.glow.blob(Vector3(0, 2.05, 0.34), Vector3(0.07, 0.09, 0.07), Color(1.0, 0.8, 0.5), 2, 6)
	c.props.box(Vector3(1.2, 0.18, 0.1), Vector3(0.4, 0.3, 0.28), Color("d9d1b8").darkened(0.1))
	c.props.box(Vector3(1.2, 0.18, 0.1), Vector3(0.42, 0.02, 0.04), Color("6a5a40"))


static func tree(c: G3Bundle.Cell, s: int) -> void:
	# the pit: dark soil in a stone frame, an iron guard round the trunk
	c.stone.box(Vector3(0, 0.005, 0), Vector3(0.95, 0.03, 0.85), Color("a39a8c"))
	c.props.box(Vector3(0, 0.02, 0), Vector3(0.78, 0.01, 0.68), Color("3a2e22"))
	var g := 0.3
	for sx in [-g, g]:
		for sz in [-g, g]:
			c.metal.box(Vector3(sx, 0.4, sz), Vector3(0.035, 0.8, 0.035), IRON)
	for yy in [0.35, 0.78]:
		c.metal.box(Vector3(0, yy, -g), Vector3(g * 2.0, 0.03, 0.03), IRON)
		c.metal.box(Vector3(0, yy, g), Vector3(g * 2.0, 0.03, 0.03), IRON)
		c.metal.box(Vector3(-g, yy, 0), Vector3(0.03, 0.03, g * 2.0), IRON)
		c.metal.box(Vector3(g, yy, 0), Vector3(0.03, 0.03, g * 2.0), IRON)
	var bark := Color("4a3a2c")
	c.wood.cyl(Vector3(0, 0, 0), 0.15, 0.1, 2.7, 7, bark)
	var lean := Vector3(rr(s, 3, -0.2, 0.2), 0, rr(s, 4, -0.1, 0.25))
	# branches and the crown
	var cr := Vector3(0, 3.7, 0.2) + lean
	for k in 4:
		var a := TAU * float(k) / 4.0 + rr(s, 10, 0.0, 1.0)
		c.wood.rod(Vector3(0, 2.5, 0), cr + Vector3(cos(a) * 0.9, 0.0, sin(a) * 0.9), 0.05, bark)
	var col: Color = LEAF[GroundUtil.ri(s, 7, 0, 3)]
	c.leaf.blob(cr, Vector3(1.85, 1.15, 1.85), col.darkened(0.15), 3, 9, 0.12, s)
	for k in 6:
		var a := TAU * float(k) / 6.0 + rr(s, 20, 0.0, 1.0)
		var rad := rr(s, 30 + k, 0.6, 1.1)
		var o := Vector3(cos(a) * rad, rr(s, 40 + k, -0.2, 0.55), sin(a) * rad)
		c.leaf.blob(cr + o, Vector3(0.95, 0.7, 0.95), col.lightened(rr(s, 50 + k, -0.04, 0.16)), 2, 8, 0.15, s + k)
	c.leaf.blob(cr + Vector3(-0.3, 0.75, -0.3), Vector3(1.1, 0.6, 1.1), col.lightened(0.18), 2, 8, 0.1, s + 99)


static func trough(c: G3Bundle.Cell, _s: int) -> void:
	var stone := Color("7d786f")
	c.stone.box(Vector3(0, 0.3, 0), Vector3(2.2, 0.6, 0.66), stone, stone.lightened(0.1))
	c.props.box(Vector3(0, 0.575, 0), Vector3(1.9, 0.02, 0.42), Color("33505e"))
	c.stone.box(Vector3(0, 0.62, -0.3), Vector3(2.2, 0.06, 0.08), stone.lightened(0.12))
	c.stone.box(Vector3(0, 0.62, 0.3), Vector3(2.2, 0.06, 0.08), stone.lightened(0.12))


static func hitch(c: G3Bundle.Cell, _s: int) -> void:
	c.metal.cyl(Vector3(0, 0, 0), 0.07, 0.055, 0.95, 6, IRON)
	c.metal.blob(Vector3(0, 1.0, 0), Vector3(0.09, 0.07, 0.09), IRON_HI, 2, 6)
	c.metal.rod(Vector3(0, 0.75, 0.03), Vector3(0.0, 0.62, 0.12), 0.012, IRON_HI)


static func basket(c: G3Bundle.Cell, _s: int) -> void:
	c.metal.cyl(Vector3(0, 0, 0), 0.17, 0.2, 0.74, 8, Color("3a3d40"), false)
	c.metal.disc(Vector3(0, 0.74, 0), 0.2, 8, Color("1a1c1e"))
	c.metal.ring_flat(Vector3(0, 0.745, 0), 0.17, 0.21, 8, Color("55585b"))
	c.metal.cyl(Vector3(0, 0, 0), 0.12, 0.12, 0.03, 8, Color("2a2c2e"))
	c.props.box(Vector3(0.02, 0.76, 0.0), Vector3(0.14, 0.02, 0.1), Color("d9d1b8"))


static func bike(c: G3Bundle.Cell, s: int) -> void:
	var col := Color("3a3a3a") if r01(s, 1) < 0.6 else Color("6a2a24")
	var m := c.metal
	for wx in [-0.6, 0.6]:
		var prev := Vector3.ZERO
		for k in 11:
			var a := TAU * float(k) / 10.0
			var q := Vector3(wx + cos(a) * 0.33, 0.35 + sin(a) * 0.33, 0)
			if k > 0:
				m.rod(prev, q, 0.014, Color("1a1a1a"))
			prev = q
		m.box(Vector3(wx, 0.35, 0), Vector3(0.04, 0.04, 0.06), IRON_HI)
	m.rod(Vector3(-0.6, 0.35, 0), Vector3(-0.15, 0.62, 0), 0.016, col)
	m.rod(Vector3(-0.15, 0.62, 0), Vector3(0.45, 0.65, 0), 0.016, col)
	m.rod(Vector3(-0.15, 0.62, 0), Vector3(0.05, 0.35, 0), 0.016, col)
	m.rod(Vector3(0.05, 0.35, 0), Vector3(-0.6, 0.35, 0), 0.016, col)
	m.rod(Vector3(0.45, 0.65, 0), Vector3(0.6, 0.35, 0), 0.016, col)
	m.rod(Vector3(0.45, 0.65, 0), Vector3(0.5, 0.85, 0), 0.016, col)
	m.rod(Vector3(0.5, 0.85, -0.22), Vector3(0.5, 0.85, 0.22), 0.014, IRON_HI)
	m.box(Vector3(-0.2, 0.7, 0), Vector3(0.22, 0.04, 0.09), Color("2a1e18"))


static func pole(c: G3Bundle.Cell, s: int) -> void:
	var steel := Color("4a5249")
	c.metal.cyl(Vector3(0, 0, 0), 0.17, 0.12, 0.7, 8, steel.darkened(0.15))
	c.metal.cyl(Vector3(0, 0.7, 0), 0.1, 0.07, 6.2, 8, steel)
	c.metal.cyl(Vector3(0, 3.0, 0), 0.115, 0.115, 0.05, 8, steel.lightened(0.1))
	c.metal.cyl(Vector3(0, 6.9, 0), 0.075, 0.03, 0.3, 6, steel.lightened(0.1))
	c.metal.rod(Vector3(0, 6.55, 0), Vector3(0, 6.7, 0.4), 0.03, steel)
	if r01(s, 3) < 0.5:
		c.props.box(Vector3(0, 1.7, 0.1), Vector3(0.22, 0.32, 0.012), Color("d9d1b8").darkened(rr(s, 4, 0.0, 0.2)))


## A pushcart: a bed on two big wheels, handles, goods heaped on it and sometimes an umbrella.
## Local +x is the long axis.
static func pushcart(c: G3Bundle.Cell, s: int, goods: String, umbrella: bool, basket_on: bool) -> void:
	var wood := Color("6a4a30").lightened(rr(s, 1, -0.05, 0.1))
	var paint: Color = AWN[GroundUtil.ri(s, 2, 0, 5)].lightened(0.1)
	for sz in [-0.5, 0.5]:
		var prev := Vector3.ZERO
		for k in 13:
			var a := TAU * float(k) / 12.0
			var q := Vector3(0.0, 0.46 + sin(a) * 0.44, sz + cos(a) * 0.0)
			q = Vector3(0.1 + cos(a) * 0.44, 0.46 + sin(a) * 0.44, sz)
			if k > 0:
				c.props.rod(prev, q, 0.03, Color("2a2018"))
			prev = q
		for k in 4:
			var a := PI * float(k) / 4.0
			c.props.rod(Vector3(0.1 - cos(a) * 0.44, 0.46 - sin(a) * 0.44, sz), Vector3(0.1 + cos(a) * 0.44, 0.46 + sin(a) * 0.44, sz), 0.012, Color("3a2e22"))
	c.props.rod(Vector3(0.1, 0.46, -0.58), Vector3(0.1, 0.46, 0.58), 0.025, Color("2a2018"))
	# the bed and its low sides
	c.props.box(Vector3(0.05, 0.78, 0.0), Vector3(1.55, 0.08, 0.84), wood)
	for sz in [-0.4, 0.4]:
		c.props.box(Vector3(0.05, 0.9, sz), Vector3(1.55, 0.2, 0.04), paint)
	c.props.box(Vector3(-0.72, 0.9, 0.0), Vector3(0.04, 0.2, 0.84), paint)
	c.props.box(Vector3(0.82, 0.9, 0.0), Vector3(0.04, 0.2, 0.84), paint)
	# handles
	for sz in [-0.34, 0.34]:
		c.props.rod(Vector3(0.8, 0.8, sz), Vector3(1.45, 0.86, sz * 0.85), 0.025, wood.darkened(0.1))
	c.props.rod(Vector3(1.45, 0.86, -0.29), Vector3(1.45, 0.86, 0.29), 0.025, wood.darkened(0.1))
	c.props.rod(Vector3(-0.7, 0.78, 0.0), Vector3(-0.95, 0.35, 0.0), 0.02, Color("2a2018"))
	# the goods
	var g := rr(s, 5, 0.0, 1.0)
	match goods:
		"fruit":
			var cols := [Color("b83a2a"), Color("d98a2a"), Color("d8c04a"), Color("6a9a3a")]
			var half := 0.0 if g < 0.5 else 1.0
			for k in 16:
				var x := rr(s, 20 + k, -0.65, 0.7)
				var z := rr(s, 40 + k, -0.32, 0.32)
				var col: Color = cols[(k / 4 + int(half)) % 4]
				c.props.blob(Vector3(x, 0.99 + rr(s, 60 + k, 0.0, 0.05), z), Vector3(0.075, 0.07, 0.075), col, 2, 6)
			c.props.box(Vector3(0.05, 0.96, 0.0), Vector3(1.4, 0.04, 0.7), Color("8a6a40"))
		"veg":
			var cols2 := [Color("4e7a3a"), Color("6e8a3a"), Color("a8442e"), Color("c88a30")]
			for k in 10:
				var x := rr(s, 20 + k, -0.6, 0.65)
				var z := rr(s, 40 + k, -0.3, 0.3)
				c.props.blob(Vector3(x, 1.0, z), Vector3(0.14, 0.1, 0.12), cols2[k % 4], 2, 6, 0.1, s + k)
		"pots":
			for k in 7:
				var x := -0.6 + float(k) * 0.2
				var z := rr(s, 40 + k, -0.2, 0.2)
				c.metal.cyl(Vector3(x, 0.82, z), 0.1, 0.12, 0.2 + rr(s, 50 + k, 0.0, 0.08), 8, Color("7a7d80").lightened(rr(s, 60 + k, 0.0, 0.2)))
		"cloth":
			for k in 4:
				var cc: Color = AWN[(k + GroundUtil.ri(s, 3, 0, 5)) % 6].lightened(0.2)
				for l in 3:
					c.props.box(Vector3(-0.45 + float(k) * 0.32, 0.86 + float(l) * 0.05, rr(s, 40 + k, -0.1, 0.1)), Vector3(0.28, 0.045, 0.5), cc.darkened(float(l) * 0.04))
		"hats":
			for k in 6:
				var x := -0.55 + float(k) * 0.22
				c.props.cyl(Vector3(x, 0.83, rr(s, 40 + k, -0.2, 0.2)), 0.16, 0.16, 0.012, 8, Color("2a2a2c"))
				c.props.cyl(Vector3(x, 0.84, 0.0), 0.08, 0.075, 0.1, 8, Color("3a3834"))
		"shoes":
			for k in 8:
				c.props.box(Vector3(-0.6 + float(k) * 0.17, 0.85, rr(s, 40 + k, -0.25, 0.25)), Vector3(0.1, 0.07, 0.22), Color("3a2a1e").lightened(rr(s, 50 + k, 0.0, 0.2)))
		"fish":
			c.props.box(Vector3(0.05, 0.86, 0.0), Vector3(1.4, 0.08, 0.7), Color("c8d4d8"))
			for k in 9:
				c.props.box(Vector3(-0.6 + float(k) * 0.16, 0.92, rr(s, 40 + k, -0.25, 0.25)), Vector3(0.05, 0.03, 0.2), Color("98a8b0"))
		"bread":
			for k in 9:
				c.props.blob(Vector3(-0.62 + float(k) * 0.16, 0.9, rr(s, 40 + k, -0.22, 0.22)), Vector3(0.07, 0.05, 0.18), Color("c0904a").darkened(rr(s, 50 + k, 0.0, 0.2)), 2, 6)
		_:
			for k in 12:
				c.props.box(Vector3(rr(s, 20 + k, -0.6, 0.65), 0.86, rr(s, 40 + k, -0.3, 0.3)), Vector3(0.12, 0.05, 0.1), AWN[k % 6].lightened(0.3))
	if basket_on:
		c.wood.cyl(Vector3(-0.95, 0.0, 0.2), 0.2, 0.24, 0.3, 8, Color("a08040"))
		c.props.blob(Vector3(-0.95, 0.31, 0.2), Vector3(0.2, 0.1, 0.2), Color("b8a060"), 2, 8)
	if umbrella:
		c.props.cyl(Vector3(0.1, 0.8, -0.35), 0.025, 0.02, 1.7, 5, Color("5a4a3a"))
		var top := Vector3(0.1, 2.5, -0.35)
		var rad := 1.25
		var n := 8
		for k in n:
			var a0 := TAU * float(k) / float(n)
			var a1 := TAU * float(k + 1) / float(n)
			var p0 := top + Vector3(cos(a0) * rad, -0.35, sin(a0) * rad)
			var p1 := top + Vector3(cos(a1) * rad, -0.35, sin(a1) * rad)
			c.props.tri_out(top + Vector3(0, 0.05, 0), p0, p1, Vector3(0, 1, 0), Color("e6dcc3") if k % 2 == 0 else paint.darkened(0.1))
			c.props.tri_out(top + Vector3(0, -0.02, 0), p0, p1, Vector3(0, -1, 0), Color("c8bc9f"))


## A street-name post. Returns [[text, local pos, yaw], ...] for Label3D nodes.
static func sign(c: G3Bundle.Cell, names: Array) -> Array:
	var green := Color("1f4a3a")
	c.metal.cyl(Vector3(0, 0, 0), 0.06, 0.05, 3.15, 6, IRON)
	c.metal.blob(Vector3(0, 3.2, 0), Vector3(0.07, 0.06, 0.07), IRON_HI, 2, 6)
	var labels := []
	# plate 0 is along x (reads from north and south), plate 1 along z
	for k in 2:
		var y := 2.95 - float(k) * 0.3
		var along_x := k == 0
		var size := Vector3(0.95, 0.2, 0.03) if along_x else Vector3(0.03, 0.2, 0.95)
		var t := String(names[k]) if k < names.size() else ""
		c.metal.box(Vector3(0, y, 0), size, green, green.lightened(0.1))
		var border := Color("e6e0d0")
		if along_x:
			c.metal.box(Vector3(0, y + 0.092, 0), Vector3(0.93, 0.012, 0.034), border)
			c.metal.box(Vector3(0, y - 0.092, 0), Vector3(0.93, 0.012, 0.034), border)
			labels.append([t, Vector3(0, y, 0.0165), 0.0])
			labels.append([t, Vector3(0, y, -0.0165), PI])
		else:
			c.metal.box(Vector3(0, y + 0.092, 0), Vector3(0.034, 0.012, 0.93), border)
			c.metal.box(Vector3(0, y - 0.092, 0), Vector3(0.034, 0.012, 0.93), border)
			labels.append([t, Vector3(0.0165, y, 0), PI * 0.5])
			labels.append([t, Vector3(-0.0165, y, 0), -PI * 0.5])
	return labels


## A tree-of-heaven growing in a backyard: thin trunk, a ragged crown. `h` is the trunk height.
static func yard_tree(c: G3Bundle.Cell, s: int) -> void:
	var bark := Color("55483a")
	var lean := Vector3(rr(s, 1, -0.3, 0.3), 0, rr(s, 2, -0.3, 0.3))
	c.wood.cyl(Vector3(0, 0, 0), 0.14, 0.08, 3.6, 7, bark)
	var col: Color = LEAF[GroundUtil.ri(s, 3, 0, 3)]
	for k in 5:
		var a := TAU * float(k) / 5.0 + rr(s, 4, 0.0, 1.0)
		var o := Vector3(cos(a) * rr(s, 10 + k, 0.6, 1.2), 4.0 + rr(s, 20 + k, -0.3, 0.9), sin(a) * rr(s, 30 + k, 0.6, 1.2)) + lean
		c.wood.rod(Vector3(0, 3.3, 0), o, 0.04, bark)
		c.leaf.blob(o, Vector3(0.95, 0.5, 0.95), col.lightened(rr(s, 40 + k, -0.06, 0.14)), 2, 8, 0.18, s + k)
	c.leaf.blob(Vector3(0, 4.7, 0) + lean, Vector3(1.0, 0.5, 1.0), col.lightened(0.16), 2, 8, 0.15, s + 9)
