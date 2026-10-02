extends RefCounted
## Roof clutter and fire escapes for one lot, from the same plan the 2D roofs use (RoofArt.plan_lot), so the
## 3D picture has the chimneys, tanks, skylights, laundry lines and fire escapes the 2D one has. Everything is
## added to B.upper in the lot frame (it hides with the roof when somebody goes inside).

const RoofArt := preload("res://scripts/world2d/fronts/roof_art.gd")
const MK := preload("res://scripts/world3d/buildings/mesh_kit.gd")

const IRON := Color("25221f")
const IRON_HI := Color("4a4540")
const BRICK := Color("7a4a3a")
const METAL := Color("8c9094")
const POT := Color("a85a38")
const WOOD := Color("6b5238")


## A world rect (px) as a lot-frame centre and size on the deck.
static func _rc(B, r: Rect2) -> Array:
	var a: Vector3 = B.local_px(r.position + B.roof_origin)
	var b: Vector3 = B.local_px(r.end + B.roof_origin)
	var c := (a + b) * 0.5
	return [Vector3(c.x, B.deck_y, c.z), Vector3(absf(a.x - b.x), 0.0, absf(a.z - b.z))]


static func _pt(B, p: Vector2, y: float = -1.0) -> Vector3:
	return B.local_px(p + B.roof_origin, B.deck_y if y < 0.0 else y)


static func build(B) -> void:
	var L: Dictionary = B.roof_plan
	if L.is_empty():
		return
	var u: MK = B.upper
	var y0: float = B.deck_y
	for pr in L.get("props", []):
		var t := String(pr["t"])
		match t:
			"chimney":
				_chimney(B, pr)
			"tower":
				_tower(B, pr)
			"bulkhead":
				_bulkhead(B, pr)
			"hatch":
				_hatch(B, pr)
			"skylight":
				_skylight(B, pr)
			"vent":
				_vent(B, pr)
			"pipe":
				var c := _pt(B, pr["c"])
				u.cyl("trim", c, 0.05, 1.1, 6, Color("5a5c5e"))
				u.box("trim", c + Vector3(0, 1.12, 0), Vector3(0.14, 0.05, 0.14), Color("5a5c5e"), 8)
			"coop":
				_coop(B, pr)
			"garden":
				_garden(B, pr)
			"lounge":
				_lounge(B, pr)
			"aerial":
				var a := _pt(B, pr["a"])
				var b := _pt(B, pr["b"])
				u.bar("trim", a, a + Vector3(0, 2.6, 0), 0.04, IRON_HI)
				u.bar("trim", b, b + Vector3(0, 2.2, 0), 0.04, IRON_HI)
				u.bar("trim", a + Vector3(0, 2.55, 0), b + Vector3(0, 2.15, 0), 0.015, IRON)
			"drain":
				u.cyl("trim", _pt(B, pr["c"]) + Vector3(0, 0.0, 0), 0.16, 0.03, 8, Color("1c1a18"))
			"junk":
				_junk(B, pr)
			"monitor":
				_monitor(B, pr)
			"hoist":
				_hoist(B, pr)
	for ln in L.get("lines", []):
		_line(B, ln)
	for fe in L.get("fe", []):
		_fire_escape(B, fe)
	if L.has("flag"):
		_flag(B, L["flag"])
	if L.has("paint_name"):
		var rr := _rc(B, L["paint_rect"])
		var c: Vector3 = rr[0]
		var s: Vector3 = rr[1]
		B.labels.append({"text": String(L["paint_name"]), "pos": Vector3(c.x, B.deck_y + 0.03, c.z), "w": (L["paint_rect"] as Rect2).size.x / W.M * 0.92,
			"h": minf((L["paint_rect"] as Rect2).size.y / W.M * 0.45, 1.6), "col": Color("d8cdb0"), "font": "cond", "kind": "roof", "ang": 0.0})


static func _chimney(B, pr: Dictionary) -> void:
	var u: MK = B.upper
	var rc := _rc(B, pr["r"])
	var c: Vector3 = rc[0]
	var s: Vector3 = rc[1]
	var ht := 1.6 + 0.9 * V3.hash01(c.x, c.z, 4.0)
	var col := BRICK.lerp(Color("6a4234"), V3.hash01(c.z, c.x, 8.0))
	u.box("trim", c + Vector3(0, ht * 0.5, 0), Vector3(s.x, ht, s.z), col, 8)
	u.box("trim", c + Vector3(0, ht + 0.05, 0), Vector3(s.x + 0.12, 0.1, s.z + 0.12), Color("9a948a"), 8)
	var pots := int(pr.get("pots", 2))
	var long_x := s.x > s.z
	for k in pots:
		var f := (k + 0.5) / pots - 0.5
		var off := Vector3(f * (s.x - 0.2), 0, 0) if long_x else Vector3(0, 0, f * (s.z - 0.2))
		u.cyl("trim", c + off + Vector3(0, ht + 0.1, 0), 0.1, 0.3, 6, POT, 0.085)


static func _tower(B, pr: Dictionary) -> void:
	var u: MK = B.upper
	var c := _pt(B, pr["c"])
	var r: float = float(pr["r"]) / W.M
	var leg := 1.15
	for k in 4:
		var a := k * PI * 0.5 + PI * 0.25
		var p := c + Vector3(cos(a), 0, sin(a)) * r * 0.82
		u.bar("trim", p, p + Vector3(0, leg, 0), 0.07, IRON)
	for k in 4:
		var a0 := k * PI * 0.5 + PI * 0.25
		var a1 := (k + 1) * PI * 0.5 + PI * 0.25
		var pa := c + Vector3(cos(a0), 0, sin(a0)) * r * 0.82
		var pb := c + Vector3(cos(a1), 0, sin(a1)) * r * 0.82
		u.bar("trim", pa + Vector3(0, 0.1, 0), pb + Vector3(0, leg - 0.1, 0), 0.03, IRON_HI)
	u.cyl("trim", c + Vector3(0, leg, 0), r * 1.04, 0.1, 10, IRON_HI)
	var tank_h := 2.0
	u.cyl("trim", c + Vector3(0, leg + 0.1, 0), r, tank_h, 12, WOOD)
	for k in 3:
		u.cyl("trim", c + Vector3(0, leg + 0.35 + k * 0.7, 0), r + 0.03, 0.06, 12, IRON, -1.0, false)
	u.cyl("trim", c + Vector3(0, leg + 0.1 + tank_h, 0), r + 0.08, 0.65, 12, Color("5a4630"), 0.03)


static func _bulkhead(B, pr: Dictionary) -> void:
	var u: MK = B.upper
	var rc := _rc(B, pr["r"])
	var c: Vector3 = rc[0]
	var s: Vector3 = rc[1]
	var ht := 2.4
	var col := Color("9a7458").lerp(BRICK, V3.hash01(c.x, c.z, 2.0))
	u.box("trim", c + Vector3(0, ht * 0.5, 0), Vector3(s.x, ht, s.z), col, 8)
	u.box("trim", c + Vector3(0, ht + 0.06, 0), Vector3(s.x + 0.2, 0.12, s.z + 0.2), Color("4a4540"), 8)
	var dir: Vector3 = B.local_px_dir(Vector2(pr.get("door", Vector2.ZERO)))
	if dir.length() > 0.5:
		dir = Vector3(roundf(dir.x), 0, roundf(dir.z)).normalized()
		var ext := absf(dir.x) * s.x * 0.5 + absf(dir.z) * s.z * 0.5
		var t := Transform3D(Basis(Vector3.UP.cross(dir), Vector3.UP, dir), c + dir * (ext + 0.02) + Vector3(0, 0.95, 0))
		u.box_t("trim", t, Vector3(0.42, 0.95, 0.03), Color("2a2c2a"), 8)


static func _hatch(B, pr: Dictionary) -> void:
	var u: MK = B.upper
	var rc := _rc(B, pr["r"])
	var c: Vector3 = rc[0]
	var s: Vector3 = rc[1]
	u.box("trim", c + Vector3(0, 0.2, 0), Vector3(s.x, 0.4, s.z), Color("6a5e52"), 8)
	u.box("trim", c + Vector3(0, 0.43, 0), Vector3(s.x + 0.08, 0.06, s.z + 0.08), Color("3a3e40"), 8)


static func _skylight(B, pr: Dictionary) -> void:
	var u: MK = B.upper
	var rc := _rc(B, pr["r"])
	var c: Vector3 = rc[0]
	var s: Vector3 = rc[1]
	var lit := bool(pr.get("lit", false))
	u.box("trim", c + Vector3(0, 0.15, 0), Vector3(s.x + 0.12, 0.3, s.z + 0.12), Color("5a5e60"), 8)
	var key := "lamp" if lit else "trim"
	var gcol := Color(1.0, 0.82, 0.55, 0.25) if lit else Color("7f8f96")
	var rid := 0.32
	var y1 := c.y + 0.3
	var y2 := y1 + rid
	if s.x >= s.z:
		var x0 := c.x - s.x * 0.5
		var x1 := c.x + s.x * 0.5
		var z0 := c.z - s.z * 0.5
		var z1 := c.z + s.z * 0.5
		var zm := c.z
		u.quad(key, Vector3(x0, y1, z1), Vector3(x1, y1, z1), Vector3(x1, y2, zm), Vector3(x0, y2, zm), Vector3(0, 1, 1).normalized(), gcol)
		u.quad(key, Vector3(x1, y1, z0), Vector3(x0, y1, z0), Vector3(x0, y2, zm), Vector3(x1, y2, zm), Vector3(0, 1, -1).normalized(), gcol)
		u.tri("trim", Vector3(x0, y1, z0), Vector3(x0, y1, z1), Vector3(x0, y2, zm), Vector3.LEFT, Color("5a5e60"))
		u.tri("trim", Vector3(x1, y1, z1), Vector3(x1, y1, z0), Vector3(x1, y2, zm), Vector3.RIGHT, Color("5a5e60"))
	else:
		var x0 := c.x - s.x * 0.5
		var x1 := c.x + s.x * 0.5
		var z0 := c.z - s.z * 0.5
		var z1 := c.z + s.z * 0.5
		var xm := c.x
		u.quad(key, Vector3(x1, y1, z0), Vector3(x1, y1, z1), Vector3(xm, y2, z1), Vector3(xm, y2, z0), Vector3(1, 1, 0).normalized(), gcol)
		u.quad(key, Vector3(x0, y1, z1), Vector3(x0, y1, z0), Vector3(xm, y2, z0), Vector3(xm, y2, z1), Vector3(-1, 1, 0).normalized(), gcol)
		u.tri("trim", Vector3(x0, y1, z0), Vector3(x1, y1, z0), Vector3(xm, y2, z0), Vector3.FORWARD, Color("5a5e60"))
		u.tri("trim", Vector3(x1, y1, z1), Vector3(x0, y1, z1), Vector3(xm, y2, z1), Vector3.BACK, Color("5a5e60"))


static func _vent(B, pr: Dictionary) -> void:
	var u: MK = B.upper
	var c := _pt(B, pr["c"])
	var r: float = float(pr["r"]) / W.M
	u.cyl("trim", c, r * 0.8, 0.25, 8, Color("5a5c5e"))
	if bool(pr.get("turbine", false)):
		u.cyl("trim", c + Vector3(0, 0.25, 0), r * 1.1, 0.4, 10, METAL, r * 0.7, true)
		u.cyl("trim", c + Vector3(0, 0.65, 0), r * 0.7, 0.14, 10, METAL.lightened(0.1), 0.02, true)
	else:
		u.cyl("trim", c + Vector3(0, 0.25, 0), r * 0.8, 0.3, 8, Color("6a6c6e"))
		u.cyl("trim", c + Vector3(0, 0.55, 0), r * 1.5, 0.1, 8, Color("3a3c3e"), 0.05)


static func _coop(B, pr: Dictionary) -> void:
	var u: MK = B.upper
	var rc := _rc(B, pr["r"])
	var c: Vector3 = rc[0]
	var s: Vector3 = rc[1]
	u.box("trim", c + Vector3(0, 0.5, 0), Vector3(s.x * 0.9, 0.7, s.z * 0.8), Color("8a7458"), 8)
	u.box("trim", c + Vector3(0, 0.9, 0), Vector3(s.x * 0.96, 0.08, s.z * 0.9), Color("4a4036"), 8)
	for k in 4:
		var f := V3.hash01(c.x + k, c.z, 2.0)
		u.sphere("trim", c + Vector3((f - 0.5) * s.x * 0.8, 1.0, (V3.hash01(c.z, c.x + k, 5.0) - 0.5) * s.z * 0.6), 0.07,
			Color("d8d4cc") if k % 2 == 0 else Color("7a7a82"), 6, 4)


static func _garden(B, pr: Dictionary) -> void:
	var u: MK = B.upper
	var rc := _rc(B, pr["r"])
	var c: Vector3 = rc[0]
	var s: Vector3 = rc[1]
	var n := int(pr.get("n", 3))
	var long_x := s.x >= s.z
	for k in n:
		var f := (k + 0.5) / n - 0.5
		var off := Vector3(f * s.x, 0, 0) if long_x else Vector3(0, 0, f * s.z)
		var bsz := Vector3(0.5, 0.3, 0.9) if not long_x else Vector3(0.9, 0.3, 0.5)
		bsz = Vector3(minf(bsz.x, s.x * 0.95), 0.3, minf(bsz.z, s.z * 0.95)) if n == 1 else bsz
		u.box("trim", c + off + Vector3(0, 0.15, 0), bsz, Color("6a4a30"), 8)
		u.sphere("trim", c + off + Vector3(0, 0.45, 0), 0.22, Color("4a7a3a"), 6, 4)
		u.sphere("trim", c + off + Vector3(0.1, 0.5, 0.06), 0.05, Color("c0392b"), 5, 3)


static func _lounge(B, pr: Dictionary) -> void:
	var u: MK = B.upper
	var rc := _rc(B, pr["r"])
	var c: Vector3 = rc[0]
	var s: Vector3 = rc[1]
	var col: Color = [Color("3a5a7a"), Color("7a3a3a"), Color("c8b070")][int(pr.get("seed", 0)) % 3]
	u.box("trim", c + Vector3(0, 0.18, 0), Vector3(s.x * 0.4, 0.05, s.z * 0.55), col, 8)
	u.box_t("trim", Transform3D(Basis(Vector3.RIGHT, -0.7), c + Vector3(0, 0.38, -s.z * 0.28)), Vector3(s.x * 0.2, 0.28, 0.025), col.lightened(0.1), 0)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			u.bar("trim", c + Vector3(sx * s.x * 0.18, 0, sz * s.z * 0.24), c + Vector3(sx * s.x * 0.18, 0.18, sz * s.z * 0.24), 0.03, IRON)


static func _junk(B, pr: Dictionary) -> void:
	var u: MK = B.upper
	var c := _pt(B, pr["c"])
	match int(pr.get("k", 0)):
		0:
			u.cyl("trim", c, 0.14, 0.28, 8, Color("7a7e80"), 0.12)
		1:
			u.box("trim", c + Vector3(0, 0.1, 0), Vector3(0.35, 0.2, 0.22), Color("6a5640"), 8)
		2:
			u.box("trim", c + Vector3(0, 0.05, 0), Vector3(0.3, 0.1, 0.3), Color("8a4a38"), 8)
			u.box("trim", c + Vector3(0.1, 0.12, 0.05), Vector3(0.2, 0.08, 0.2), Color("7a3e30"), 8)
		_:
			u.cyl("trim", c, 0.2, 0.4, 8, Color("3a4a5a"))


static func _monitor(B, pr: Dictionary) -> void:
	var u: MK = B.upper
	var rc := _rc(B, pr["r"])
	var c: Vector3 = rc[0]
	var s: Vector3 = rc[1]
	var ht := 1.5
	u.box("trim", c + Vector3(0, ht * 0.5, 0), Vector3(s.x, ht, s.z), Color("7a5a48"), 8)
	var along_x := s.x >= s.z
	# the clerestory glass on both long faces
	for sg: float in [-1.0, 1.0]:
		if along_x:
			var z := c.z + sg * (s.z * 0.5 + 0.01)
			u.quad("lamp", Vector3(c.x - s.x * 0.5 + 0.2, c.y + 0.35, z), Vector3(c.x + s.x * 0.5 - 0.2, c.y + 0.35, z),
				Vector3(c.x + s.x * 0.5 - 0.2, c.y + ht - 0.2, z), Vector3(c.x - s.x * 0.5 + 0.2, c.y + ht - 0.2, z), Vector3(0, 0, sg), Color(0.95, 0.85, 0.6, 0.25))
		else:
			var x := c.x + sg * (s.x * 0.5 + 0.01)
			u.quad("lamp", Vector3(x, c.y + 0.35, c.z - s.z * 0.5 + 0.2), Vector3(x, c.y + 0.35, c.z + s.z * 0.5 - 0.2),
				Vector3(x, c.y + ht - 0.2, c.z + s.z * 0.5 - 0.2), Vector3(x, c.y + ht - 0.2, c.z - s.z * 0.5 + 0.2), Vector3(sg, 0, 0), Color(0.95, 0.85, 0.6, 0.25))
	u.box("trim", c + Vector3(0, ht + 0.08, 0), Vector3(s.x + 0.3, 0.16, s.z + 0.3), Color("3a3532"), 8)


static func _hoist(B, pr: Dictionary) -> void:
	var u: MK = B.upper
	var a := _pt(B, pr["a"], B.h + 0.05)
	var out := Vector3(0, 0, 1)
	var post := a + Vector3(0, 0, -0.6)
	u.bar("trim", Vector3(post.x, B.deck_y, post.z), Vector3(post.x, B.h + 1.3, post.z), 0.12, IRON)
	u.bar("trim", Vector3(post.x, B.h + 1.3, post.z), Vector3(post.x, B.h + 1.3, 1.6), 0.1, IRON)
	u.bar("trim", Vector3(post.x, B.h + 0.5, post.z), Vector3(post.x, B.h + 1.25, 0.6), 0.05, IRON_HI)
	u.bar("trim", Vector3(post.x, B.h + 1.25, 1.45), Vector3(post.x, B.h - 1.0, 1.45), 0.02, Color("b59a6a"))
	u.box("trim", Vector3(post.x, B.h - 1.1, 1.45), Vector3(0.2, 0.18, 0.14), IRON_HI, 8)


static func _line(B, ln: Dictionary) -> void:
	var u: MK = B.upper
	var a := _pt(B, ln["a"])
	var b := _pt(B, ln["b"])
	var h := 1.7
	u.bar("trim", a, a + Vector3(0, h, 0), 0.05, IRON_HI)
	u.bar("trim", b, b + Vector3(0, h, 0), 0.05, IRON_HI)
	u.bar("trim", a + Vector3(0, h, 0), b + Vector3(0, h - 0.06, 0), 0.012, Color("c8c0b0"))
	var dir := (b - a)
	var len := dir.length()
	if len < 0.5:
		return
	dir = dir / len
	var rng := W.rng(int(ln.get("seed", 1)))
	var n := int(len / 0.55)
	var basis := Basis(dir, Vector3.UP, dir.cross(Vector3.UP))
	for k in n:
		var f := (k + 0.5) / n
		var p := a.lerp(b, f) + Vector3(0, h - 0.06 * f - 0.25, 0)
		var col: Color = RoofArt.LAUNDRY[rng.randi_range(0, RoofArt.LAUNDRY.size() - 1)]
		u.box_t("trim", Transform3D(basis, p), Vector3(rng.randf_range(0.14, 0.24), rng.randf_range(0.18, 0.34), 0.012), col, 0)


static func _flag(B, fl: Dictionary) -> void:
	var u: MK = B.upper
	var base: Vector3 = _pt(B, fl["base"])
	u.bar("trim", base, base + Vector3(0, 3.2, 0), 0.05, Color("c8c0a8"))
	u.sphere("trim", base + Vector3(0, 3.25, 0), 0.06, Color("d4a532"), 6, 4)
	var col := Color("9a2a24") if B.kind == "club" else Color("2a3a6a")
	var top := base + Vector3(0, 3.05, 0)
	for k in 3:
		var y := top.y - k * 0.16
		u.box("trim", Vector3(top.x + 0.42, y, top.z), Vector3(0.84, 0.15, 0.015), col if k != 1 else Color("e8e0cc"), 8)


# ------------------------------------------------------------------ fire escapes

static func _fire_escape(B, fe: Dictionary) -> void:
	var u: MK = B.upper
	var fr: Transform2D = fe["fr"]
	var s0: float = float(fe["s0"]) / W.M
	var s1: float = float(fe["s1"]) / W.M
	var floors: int = int(fe["floors"])
	if floors < 2:
		return
	var depth := 1.0
	var along: Vector3 = B.local_px_dir(fr.x)
	var out: Vector3 = B.local_px_dir(fr.y)
	var org: Vector3 = B.local_px(fr.origin + B.roof_origin)
	var wid := s1 - s0
	var left := bool(fe.get("stair_left", false))
	var ys := []
	for k in range(1, floors):
		ys.append(3.4 + (k - 1) * 3.0 + 0.5)
	var basis := Basis(along, Vector3.UP, out)
	var cmid: Vector3 = org + along * (s0 + wid * 0.5) + out * (depth * 0.5)
	for i in ys.size():
		var y: float = ys[i]
		var c := Vector3(cmid.x, y, cmid.z)
		# the grating, with a dark underside line
		# an open grating: two edge bars along the wall and slats running out
		for sd in [0.04, depth - 0.04]:
			var ce: Vector3 = org + along * (s0 + wid * 0.5) + out * sd
			u.box_t("trim", Transform3D(basis, Vector3(ce.x, y, ce.z)), Vector3(wid * 0.5, 0.04, 0.04), IRON, 8)
		var nsl := maxi(3, int(wid / 0.28))
		for k in nsl + 1:
			var cs: Vector3 = org + along * (s0 + wid * float(k) / nsl) + out * (depth * 0.5)
			u.box_t("trim", Transform3D(basis, Vector3(cs.x, y, cs.z)), Vector3(0.025, 0.02, depth * 0.5), IRON_HI, 8)
		# railing: front and two sides, plus posts
		var rail_h := 0.95
		var fo: Vector3 = org + along * (s0 + wid * 0.5) + out * depth
		u.bar("trim", Vector3(fo.x, y + rail_h, fo.z) - along * (wid * 0.5), Vector3(fo.x, y + rail_h, fo.z) + along * (wid * 0.5), 0.035, IRON)
		u.bar("trim", Vector3(fo.x, y + 0.5, fo.z) - along * (wid * 0.5), Vector3(fo.x, y + 0.5, fo.z) + along * (wid * 0.5), 0.02, IRON)
		for sgn: float in [-1.0, 1.0]:
			var e1: Vector3 = org + along * (s0 + wid * 0.5 + sgn * wid * 0.5)
			var e2: Vector3 = e1 + out * depth
			u.bar("trim", Vector3(e1.x, y + rail_h, e1.z), Vector3(e2.x, y + rail_h, e2.z), 0.03, IRON)
			u.bar("trim", Vector3(e2.x, y, e2.z), Vector3(e2.x, y + rail_h, e2.z), 0.035, IRON)
		var mid := Vector3(fo.x, y, fo.z)
		u.bar("trim", mid, mid + Vector3(0, rail_h, 0), 0.03, IRON)
		# the stairs to the platform above: a pair of stringers and a plank run
		if i + 1 < ys.size():
			var y2: float = ys[i + 1]
			var xs0 := s0 + (0.15 if left else wid - 0.9)
			var xs1 := xs0 + 0.75
			var oo := depth * 0.5
			var pa: Vector3 = org + along * xs0 + out * oo
			var pb: Vector3 = org + along * xs1 + out * oo
			var lo := Vector3(pa.x, y, pa.z)
			var hi := Vector3(pb.x, y2, pb.z)
			if not left:
				lo = Vector3(pb.x, y, pb.z)
				hi = Vector3(pa.x, y2, pa.z)
			for sg: float in [-0.28, 0.28]:
				u.bar("trim", lo + out * sg, hi + out * sg, 0.035, IRON)
			u.bar("trim", lo, hi, 0.1, IRON_HI)
	# a drop ladder from the lowest platform
	if ys.size() > 0:
		var y := float(ys[0])
		var lx: Vector3 = org + along * (s0 + (wid - 0.6 if left else 0.6)) + out * (depth - 0.1)
		for sg: float in [-0.2, 0.2]:
			var top: Vector3 = lx + along * sg
			u.bar("trim", Vector3(top.x, y, top.z), Vector3(top.x, 2.3, top.z + 0.2), 0.03, IRON)
