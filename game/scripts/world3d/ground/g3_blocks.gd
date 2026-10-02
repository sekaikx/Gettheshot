class_name G3Blocks
extends RefCounted
## Puts the layout's street furniture, sidewalk frontage features (stoops, cellar doors, vault lights,
## gratings, areaways, drains), pushcarts and sidewalk litter into the bundle.

const Y := G3Streets.Y_WALK
const IRON := Color("2b2e2d")

var lay: GroundLayout
var B: G3Bundle
var lamp_points: Array = []      # Vector3 lamp heads
var labels: Array = []           # [text, Vector3 world, yaw]
var glow_spots: Array = []       # [Vector3, Color, radius] extra light pools already added


func _init(layout: GroundLayout, bundle: G3Bundle) -> void:
	lay = layout
	B = bundle


func build() -> void:
	for b in lay.blocks:
		_block(b)
	for s in lay.segs:
		for p in s["props"]:
			_cart(p)


static func _yaw(rot: float) -> float:
	return -rot


func _block(b: Dictionary) -> void:
	var r: Rect2 = b["r"]
	var cell := B.at(r.get_center())
	for p in b["props"]:
		_prop(b, p)
	for f in b["flats"]:
		_flat(cell, f)
	_litter(b, cell)


func _prop(b: Dictionary, p: Dictionary) -> void:
	var pm: Vector2 = (p["p"] as Vector2) / W.M
	var rot: float = p["rot"]
	var cell := B.at(pm)
	var s: int = int(p["s"])
	var t: String = p["t"]
	var yaw := _yaw(rot)
	cell.push_at(Vector3(pm.x, Y, pm.y), yaw)
	match t:
		"lamp":
			var head := G3Props.lamp(cell, s)
			var hw := Vector3(pm.x, Y + head.y, pm.y) + Vector3(sin(yaw), 0, cos(yaw)) * head.z
			lamp_points.append(hw)
			# the pool of light the lamp throws on the street
			cell.pop()
			cell.pools.glow_disc(Vector3(hw.x, 0.1, hw.z), 6.2, Color(1.0, 0.8, 0.5, 0.62), 5, 20)
			cell.push_at(Vector3(pm.x, Y, pm.y), yaw)
		"hydrant":
			G3Props.hydrant(cell, s)
		"mailbox":
			G3Props.mailbox(cell, s)
		"callbox":
			G3Props.callbox(cell, s)
			cell.pop()
			cell.pools.glow_disc(Vector3(pm.x, 0.1, pm.y), 1.6, Color(0.5, 0.65, 1.0, 0.35), 3, 12)
			cell.push_at(Vector3.ZERO)
		"alarm":
			G3Props.alarm(cell, s)
			cell.pop()
			cell.pools.glow_disc(Vector3(pm.x, 0.1, pm.y), 1.6, Color(1.0, 0.35, 0.28, 0.4), 3, 12)
			cell.push_at(Vector3.ZERO)
		"ashcans":
			G3Props.ashcans(cell, s, int(p.get("n", 1)))
		"bench":
			G3Props.bench(cell, s)
		"newsstand":
			G3Props.newsstand(cell, s)
			cell.pop()
			cell.pools.glow_disc(Vector3(pm.x + sin(yaw) * 0.9, 0.1, pm.y + cos(yaw) * 0.9), 2.6, Color(1.0, 0.78, 0.45, 0.4), 4, 14)
			cell.push_at(Vector3.ZERO)
		"tree":
			G3Props.tree(cell, s)
		"trough":
			G3Props.trough(cell, s)
		"hitch":
			G3Props.hitch(cell, s)
		"basket":
			G3Props.basket(cell, s)
		"bike":
			G3Props.bike(cell, s)
		"pole":
			G3Props.pole(cell, s)
		"sign":
			var lb := G3Props.sign(cell, p["names"])
			for l in lb:
				var lp: Vector3 = l[1]
				labels.append([l[0], Vector3(pm.x, Y, pm.y) + Basis(Vector3.UP, yaw) * lp, yaw + float(l[2])])
	cell.pop()


func _cart(p: Dictionary) -> void:
	var pm: Vector2 = (p["p"] as Vector2) / W.M
	var cell := B.at(pm)
	cell.push_at(Vector3(pm.x, 0.0, pm.y), _yaw(float(p["rot"])))
	G3Props.pushcart(cell, int(p["s"]), String(p["goods"]), bool(p["umbrella"]), bool(p["basket"]))
	cell.pop()


# ------------------------------------------------------------------ frontage: stoops, cellar doors, gratings

func _flat(cell: G3Bundle.Cell, f: Dictionary) -> void:
	var pm: Vector2 = (f["p"] as Vector2) / W.M
	var yaw := _yaw(float(f["rot"]))
	var t: String = f["t"]
	var s: int = int(f["s"])
	var c := B.at(pm)
	if t == "drain":
		c.push_at(Vector3(pm.x, 0.0, pm.y), yaw)
		c.metal.box(Vector3(0, 0.012, 0), Vector3(0.7, 0.014, 0.3), Color("1b1b1d"))
		for k in 6:
			c.metal.box(Vector3(-0.3 + float(k) * 0.12, 0.02, 0), Vector3(0.04, 0.012, 0.26), Color("45474a"))
		c.pop()
		return
	c.push_at(Vector3(pm.x, Y, pm.y), yaw)
	match t:
		"stoop":
			_stoop(c, f)
		"areaway":
			_areaway(c, f)
		"cellar":
			_cellar(c, f)
		"vault":
			_vault(c, f)
		"chute":
			c.metal.cyl(Vector3(0, 0, 0), 0.25, 0.25, 0.015, 10, Color("34363a"), true, Color("4a4c50"))
			c.metal.ring_flat(Vector3(0, 0.017, 0), 0.12, 0.17, 10, Color("2a2c2f"))
			c.metal.cyl(Vector3(0.12, 0.016, 0.0), 0.03, 0.03, 0.012, 6, Color("6a6c70"))
		"grating":
			var sz: Vector2 = f["size"]
			c.metal.box(Vector3(0, 0.006, 0), Vector3(sz.x, 0.012, sz.y), Color("18181a"))
			var n := int(sz.x / 0.1)
			for k in n:
				c.metal.box(Vector3(-sz.x * 0.5 + 0.05 + float(k) * 0.1, 0.016, 0), Vector3(0.035, 0.014, sz.y - 0.04), Color("4a4c50"))
			c.metal.box(Vector3(0, 0.016, 0), Vector3(sz.x, 0.014, 0.03), Color("4a4c50"))
	c.pop()


func _stoop(c: G3Bundle.Cell, f: Dictionary) -> void:
	var w: float = f["w"]
	var d: float = f["d"]
	var style: int = int(f["style"])
	var stone: Color = [Color("a89e90"), Color("8a6a58"), Color("9a9488"), Color("7a5a48")][style % 4]
	# three steps rising toward the door (local -z is the wall)
	var depths := [d, d * 0.72, d * 0.42]
	var hs := [0.17, 0.36, 0.55]
	for k in 3:
		var dd: float = depths[k]
		var h: float = hs[k]
		c.stone.box(Vector3(0, h * 0.5, dd * 0.5), Vector3(w, h, dd), stone.darkened(0.05 * float(2 - k)), stone.lightened(0.08))
	# the landing and its door mat, iron rails running down both sides
	c.props.box(Vector3(0, 0.555, 0.12), Vector3(0.9, 0.012, 0.3), Color("3a2e22"))
	for sx in [-w * 0.5 + 0.04, w * 0.5 - 0.04]:
		c.metal.rod(Vector3(sx, 1.0, 0.15), Vector3(sx, 0.65, d - 0.1), 0.02, IRON)
		c.metal.rod(Vector3(sx, 0.55, 0.15), Vector3(sx, 0.2, d - 0.1), 0.012, IRON)
		c.metal.box(Vector3(sx, 0.78, 0.15), Vector3(0.04, 0.46, 0.04), IRON)
		c.metal.box(Vector3(sx, 0.4, d - 0.1), Vector3(0.04, 0.45, 0.04), IRON)


func _areaway(c: G3Bundle.Cell, f: Dictionary) -> void:
	var w: float = f["w"]
	var d: float = f["d"]
	# a dark well in front of the basement window, with steps going down, an iron rail round it
	c.props.box(Vector3(0, 0.009, d * 0.5), Vector3(w, 0.014, d), Color("0c0c0e"))
	for k in 4:
		c.props.box(Vector3(0, 0.017, d * 0.5 - d * 0.3 + float(k) * 0.14), Vector3(w * 0.5, 0.01, 0.1), Color("2a2a2d"))
	c.stone.box(Vector3(0, 0.02, d + 0.04), Vector3(w + 0.16, 0.04, 0.08), Color("a89e90"))
	c.stone.box(Vector3(-w * 0.5 - 0.04, 0.02, d * 0.5), Vector3(0.08, 0.04, d), Color("a89e90"))
	c.stone.box(Vector3(w * 0.5 + 0.04, 0.02, d * 0.5), Vector3(0.08, 0.04, d), Color("a89e90"))
	var y1 := 0.85
	c.metal.rod(Vector3(-w * 0.5 - 0.04, y1, 0.0), Vector3(-w * 0.5 - 0.04, y1, d + 0.04), 0.014, IRON)
	c.metal.rod(Vector3(w * 0.5 + 0.04, y1, 0.0), Vector3(w * 0.5 + 0.04, y1, d + 0.04), 0.014, IRON)
	c.metal.rod(Vector3(-w * 0.5 - 0.04, y1, d + 0.04), Vector3(w * 0.5 + 0.04, y1, d + 0.04), 0.014, IRON)
	var n := int(w / 0.14)
	for k in n + 1:
		var x := -w * 0.5 - 0.04 + (w + 0.08) * float(k) / float(n)
		c.metal.box(Vector3(x, 0.45, d + 0.04), Vector3(0.018, 0.82, 0.018), IRON)
	var m := int(d / 0.16)
	for k in m + 1:
		var z := d * float(k) / float(m)
		for sx in [-w * 0.5 - 0.04, w * 0.5 + 0.04]:
			c.metal.box(Vector3(sx, 0.45, z), Vector3(0.018, 0.82, 0.018), IRON)


func _cellar(c: G3Bundle.Cell, f: Dictionary) -> void:
	var sz: Vector2 = f["size"]
	var hw := sz.x * 0.5
	var hd := sz.y * 0.5
	var wood := Color("4a3a30")
	c.stone.box(Vector3(0, 0.02, 0), Vector3(sz.x + 0.14, 0.04, sz.y + 0.14), Color("8f8678"))
	# two sloping leaves, high at the wall (local -z), flush at the street side
	for h in 2:
		var x0 := -hw if h == 0 else 0.0
		var x1 := 0.0 if h == 0 else hw
		c.metal.quad_out(Vector3(x0 + 0.015, 0.34, -hd), Vector3(x1 - 0.015, 0.34, -hd), Vector3(x1 - 0.015, 0.045, hd), Vector3(x0 + 0.015, 0.045, hd), Vector3(0, 1, 0.3), wood)
		for k in 3:
			var z := lerpf(-hd + 0.1, hd - 0.1, float(k) / 2.0)
			var yy := lerpf(0.34, 0.045, (z + hd) / sz.y) + 0.008
			c.metal.quad_out(Vector3(x0 + 0.03, yy, z - 0.02), Vector3(x1 - 0.03, yy, z - 0.02), Vector3(x1 - 0.03, yy - 0.006, z + 0.02), Vector3(x0 + 0.03, yy - 0.006, z + 0.02), Vector3(0, 1, 0.3), Color("1e1e20"))
	c.metal.box(Vector3(0, 0.2, hd - 0.12), Vector3(0.12, 0.04, 0.05), Color("5a5a5e"))


func _vault(c: G3Bundle.Cell, f: Dictionary) -> void:
	var sz: Vector2 = f["size"]
	c.metal.box(Vector3(0, 0.008, 0), Vector3(sz.x, 0.016, sz.y), Color("2a2a2d"))
	var cols := int(sz.x / 0.16)
	var rows := maxi(1, int(sz.y / 0.16))
	var gw := (sz.x - 0.06) / float(cols)
	var gh := (sz.y - 0.06) / float(rows)
	for iy in rows:
		for ix in cols:
			var x := -sz.x * 0.5 + 0.03 + (float(ix) + 0.5) * gw
			var z := -sz.y * 0.5 + 0.03 + (float(iy) + 0.5) * gh
			var g := 0.5 + GroundUtil.rr(int(f["s"]), ix * 7 + iy, -0.08, 0.08)
			c.metal.box(Vector3(x, 0.02, z), Vector3(gw - 0.03, 0.01, gh - 0.03), Color(g * 0.8, g * 0.68, g * 0.95))


# ------------------------------------------------------------------ litter and grime on the sidewalks

func _litter(b: Dictionary, cell: G3Bundle.Cell) -> void:
	var sd: int = b["seed"]
	var phantom: bool = b["phantom"]
	var k := 0
	for s: String in ["N", "S", "W", "E"]:
		var side: Dictionary = b["sides"][s]
		var n := 5 if phantom else 9
		for q in n:
			k += 1
			var a := GroundUtil.rr(sd, 2000 + k, float(side["a0"]) + 3.0, float(side["a1"]) - 3.0)
			var d := GroundUtil.rr(sd, 2100 + k, 0.4, 3.4)
			var pm := GroundLayout.side_point(side, a, d)
			var rot := GroundUtil.r01(sd, 2200 + k) * PI
			var kind := GroundUtil.r01(sd, 2300 + k)
			if kind < 0.45:
				# a newspaper page or a scrap
				var w := GroundUtil.rr(sd, 2400 + k, 0.14, 0.3)
				var h := GroundUtil.rr(sd, 2500 + k, 0.1, 0.22)
				cell.paint.push_at(Vector3(pm.x, 0, pm.y), rot)
				cell.paint.box(Vector3(0, Y + 0.005, 0), Vector3(w, 0.004, h), Color(0.86, 0.83, 0.76, 0.9))
				cell.paint.pop()
			elif kind < 0.8:
				var rad := GroundUtil.rr(sd, 2600 + k, 0.25, 0.7)
				cell.paint.poly_flat(G3Mesh.blob_pts(pm, rad * 1.3, rad, sd + k, 10, 0.3, rot), Y + 0.004, Color(0.1, 0.09, 0.08, 0.12))
			else:
				# a leaf or scrap of straw, a bottle cap
				cell.paint.disc(Vector3(pm.x, Y + 0.005, pm.y), 0.045, 6, Color(0.5, 0.4, 0.22, 0.9))
