class_name Buildings3D
extends Node3D
## Every building of the city in 3D: brick and stone facades with procedural windows (one shared shader),
## stone sills, cornices and parapets, ground-floor shopfronts with fascia signs, awnings in the colour of
## the family that owns the shop, padlock boards, broken glass, fire escapes, roofs with their clutter.
## Built from CityPlan lots plus Game.biz; geometry is merged per lot (see scripts/world3d/buildings/*).
##
##   build(plan)                 once
##   set_night(night, wet)       lit windows, shop lights, neon
##   set_inside(lot_id)          the local player is inside lot (-1 = outside): its roof, upper floors and front
##                               come off (a low shell stays); a tall building to the south that would block
##                               the tilted camera loses its upper floors too
##   update_owners()             a shop changed hands / padlocked / speakeasy / smashed: redo what shows it
##   lot_height(lot_id) -> float
##   light_points: Array         Vector3 positions of shop/door lights View3D uses for its pooled real lights
##
## Per lot: Lot<id> (Node3D in the lot frame: x along the front, y up, z out) with children Base (low shell),
## Upper (walls above, roof, clutter), Front (static shopfront + signs, Dyn = glass/awning/padlock, labels).

const LotBuilder := preload("res://scripts/world3d/buildings/lot_builder.gd")
const Mats := preload("res://scripts/world3d/buildings/bld_mats.gd")
const Shop := preload("res://scripts/world3d/buildings/shop_front.gd")
const RoofArt := preload("res://scripts/world2d/fronts/roof_art.gd")
const FrontArt := preload("res://scripts/world2d/fronts/front_art.gd")

const COURT_H := 2.4
const LABEL_PS := 0.005

var plan: CityPlan
var light_points: Array = []
var _lots := {}          # id -> {root, base, upper, front, dyn, rect, h, xf, lights, biz, key, dyn_lights}
var _heights := {}
var _inside := -1
var _hidden: Array = []  # [{node}] things hidden by set_inside
var _signs: Array = []   # Label3D
var _neons: Array = []   # Label3D
var _night := 0.0
var _wet := 0.0
var _mats: Dictionary


func build(p: CityPlan) -> void:
	plan = p
	_mats = Mats.get_mats()
	Mats.set_light(0.0, 0.0)
	var biz_of := {}
	for b in Game.biz:
		biz_of[int(b["lot"])] = b
	var inner_of := {}
	for blk in plan.blocks:
		var r: Array = blk["rect"]
		var sw := CityPlan.SIDEWALK
		inner_of[Vector2i(int(blk["i"]), int(blk["j"]))] = Rect2(Vector2(r[0] + sw, r[1] + sw) * W.M,
			Vector2(r[2] - r[0] - 2.0 * sw, r[3] - r[1] - 2.0 * sw) * W.M)
	# first pass: footprints, heights, frames
	var by_block := {}
	for lot in plan.lots:
		var id := int(lot["id"])
		var court: bool = lot["kind"] == "courtyard"
		var h := COURT_H if court else V3.lot_height(lot)
		_heights[id] = h
		var rm := V3.rect_m(W.lot_rect(lot))
		var f := W.front_dir(float(lot["yaw"]))
		var out := Vector3(f.x, 0.0, f.y)
		var right := (-out).cross(Vector3.UP)
		var depth := float(lot["size"][1])
		var origin := Vector3(rm.get_center().x, 0.0, rm.get_center().y) + out * depth * 0.5
		var info := {"rect": rm, "h": h, "xf": Transform3D(Basis(right, Vector3.UP, out), origin), "lot": lot, "court": court}
		_lots[id] = info
		var bk := Vector2i(int(lot["block"][0]), int(lot["block"][1]))
		by_block.get_or_add(bk, []).append(id)
	# second pass: build every lot
	var t0 := Time.get_ticks_usec()
	for lot in plan.lots:
		var id := int(lot["id"])
		var info: Dictionary = _lots[id]
		var bk := Vector2i(int(lot["block"][0]), int(lot["block"][1]))
		var b := LotBuilder.new()
		var court: bool = info["court"]
		var covers := [[], [], [], []]
		var roof_plan := {}
		if not court:
			covers = _covers(id, by_block.get(bk, []))
			roof_plan = RoofArt.plan_lot(lot, inner_of.get(bk, Rect2()), biz_of.get(id, {}))
		b.setup(lot, biz_of.get(id, {}), info["xf"], covers, roof_plan)
		if court:
			b.h = COURT_H
			b.build_court()
		else:
			b.build()
		_make_nodes(id, b)
	print("Buildings3D: %d lots in %.0f ms" % [_lots.size(), (Time.get_ticks_usec() - t0) / 1000.0])


# ------------------------------------------------------------------ neighbours: which walls are hidden

## For each face of a lot: pieces [u0, u1, y0] of wall that show (y0 = the neighbour's roof height, or 0).
func _covers(id: int, block_ids: Array) -> Array:
	var A: Dictionary = _lots[id]
	var lot: Dictionary = A["lot"]
	var w := float(lot["size"][0])
	var d := float(lot["size"][1])
	var T: Transform3D = A["xf"]
	var inv := T.affine_inverse()
	var ha: float = A["h"]
	var out := []
	for fi in 4:
		var F := LotBuilder.frame(fi, w, d)
		var o: Vector3 = F["o"]
		var r: Vector3 = F["r"]
		var len: float = F["len"]
		if fi == 0:
			out.append([[0.0, len, 0.0]])
			continue
		var a := T * o
		var b := T * (o + r * len)
		var n3: Vector3 = T.basis * (F["n"] as Vector3)
		var lo := Vector2(minf(a.x, b.x), minf(a.z, b.z))
		var hi := Vector2(maxf(a.x, b.x), maxf(a.z, b.z))
		if n3.x > 0.5:
			hi.x += 0.4; lo.x -= 0.05
		elif n3.x < -0.5:
			lo.x -= 0.4; hi.x += 0.05
		elif n3.z > 0.5:
			hi.y += 0.4; lo.y -= 0.05
		else:
			lo.y -= 0.4; hi.y += 0.05
		var strip := Rect2(lo, hi - lo)
		var ivs := []
		for oid in block_ids:
			if oid == id:
				continue
			var B: Dictionary = _lots[oid]
			var br: Rect2 = B["rect"]
			var ov := br.intersection(strip)
			if ov.size.x < 0.05 or ov.size.y < 0.05:
				continue
			var p0 := inv * Vector3(ov.position.x, 0.0, ov.position.y)
			var p1 := inv * Vector3(ov.end.x, 0.0, ov.end.y)
			var u0 := (p0 - o).dot(r)
			var u1 := (p1 - o).dot(r)
			ivs.append([minf(u0, u1), maxf(u0, u1), float(B["h"])])
		var pts := [0.0, len]
		for iv in ivs:
			pts.append(clampf(float(iv[0]), 0.0, len))
			pts.append(clampf(float(iv[1]), 0.0, len))
		pts.sort()
		var pieces := []
		for k in pts.size() - 1:
			var p: float = pts[k]
			var q: float = pts[k + 1]
			if q - p < 0.03:
				continue
			var m := (p + q) * 0.5
			var cov := 0.0
			for iv in ivs:
				if m >= float(iv[0]) and m <= float(iv[1]):
					cov = maxf(cov, float(iv[2]))
			var y0 := ha if cov >= ha - 0.05 else cov
			if not pieces.is_empty() and absf(float(pieces[-1][2]) - y0) < 0.02 and absf(float(pieces[-1][1]) - p) < 0.04:
				pieces[-1][1] = q
			else:
				pieces.append([p, q, y0])
		out.append(pieces)
	return out


# ------------------------------------------------------------------ nodes

func _make_nodes(id: int, b) -> void:
	var info: Dictionary = _lots[id]
	var root := Node3D.new()
	root.name = "Lot%d" % id
	root.transform = info["xf"]
	add_child(root)
	info["root"] = root
	var ms: Dictionary = b.meshes(_mats)
	for key in ["base", "upper"]:
		var m: ArrayMesh = ms[key]
		if m.get_surface_count() > 0:
			var mi := MeshInstance3D.new()
			mi.name = key.capitalize()
			mi.mesh = m
			root.add_child(mi)
			info[key] = mi
	var pm: ArrayMesh = ms["props"]
	if pm.get_surface_count() > 0:
		var pi := MeshInstance3D.new()
		pi.name = "Props"
		pi.mesh = pm
		root.add_child(pi)
	var fr := Node3D.new()
	fr.name = "Front"
	root.add_child(fr)
	info["front"] = fr
	var fm: ArrayMesh = ms["front"]
	if fm.get_surface_count() > 0:
		var mi := MeshInstance3D.new()
		mi.name = "Static"
		mi.mesh = fm
		fr.add_child(mi)
	_make_dyn(id, b)
	for d in b.labels:
		_make_label(fr if String(d["kind"]) != "roof" else info.get("upper", fr), d, info["xf"])
	var lights: Array = []
	for p in b.lights:
		lights.append(info["xf"] * (p as Vector3))
	info["lights"] = lights
	light_points.append_array(lights)
	if not b.biz.is_empty():
		info["key"] = _key(b.biz)
		info["dyn_lights"] = []


func _make_dyn(id: int, b) -> void:
	var info: Dictionary = _lots[id]
	var dm: ArrayMesh = b.dyn.commit(_mats)
	var old: Node = info.get("dyn")
	if dm.get_surface_count() == 0:
		if old:
			old.queue_free()
			info.erase("dyn")
		return
	if old == null:
		var mi := MeshInstance3D.new()
		mi.name = "Dyn"
		(info["front"] as Node3D).add_child(mi)
		info["dyn"] = mi
		old = mi
	(old as MeshInstance3D).mesh = dm


func _make_label(parent: Node3D, d: Dictionary, xf: Transform3D) -> void:
	var l := Label3D.new()
	var font := W.font(String(d["font"]))
	var text := String(d["text"])
	l.text = text
	l.font = font
	l.pixel_size = LABEL_PS
	l.outline_size = 0
	l.shaded = false
	l.double_sided = false
	l.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS
	l.modulate = d["col"]
	l.font_size = _fit(font, text, float(d["w"]), float(d["h"]))
	var kind := String(d["kind"])
	if kind == "roof":
		var dx := (xf.affine_inverse().basis * Vector3.RIGHT).normalized()
		l.transform = Transform3D(Basis(dx, Vector3.UP.cross(dx), Vector3.UP), d["pos"])
	else:
		l.transform = Transform3D(Basis(Vector3.UP, float(d["ang"])), d["pos"])
	l.set_meta("base_col", d["col"])
	parent.add_child(l)
	if kind == "neon":
		l.visible = false
		_neons.append(l)
	else:
		_signs.append(l)


## The biggest font size at which `text` fits in w x h metres (h = cap height room).
func _fit(font: Font, text: String, w: float, h: float) -> int:
	var sz_h := int(h / (0.74 * LABEL_PS))
	var test := 64
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, test).x * LABEL_PS
	var sz_w := int(test * w / maxf(width, 0.01))
	return clampi(mini(sz_h, sz_w), 14, 200)


# ------------------------------------------------------------------ state

func set_night(night: float, wet: float) -> void:
	_night = night
	_wet = wet
	Mats.set_light(night, wet)
	var on := clampf((night - 0.15) / 0.5, 0.0, 1.0)
	for l in _signs:
		var c: Color = (l as Label3D).get_meta("base_col")
		(l as Label3D).modulate = c.lightened(0.25 * on)
	for l in _neons:
		var lab := l as Label3D
		lab.visible = on > 0.3
		lab.modulate = Color(1.0, 0.45, 0.4).lerp(Color(1.0, 0.7, 0.62), on)


func set_inside(lot_id: int) -> void:
	for n in _hidden:
		if is_instance_valid(n):
			(n as Node3D).visible = true
	_hidden.clear()
	_inside = lot_id
	if not _lots.has(lot_id):
		return
	var info: Dictionary = _lots[lot_id]
	_hide(info.get("upper"))
	_hide(info.get("front"))
	# a tall neighbour to the south would block the camera (it looks north from the south)
	var rect: Rect2 = info["rect"]
	var focus := Vector3(rect.get_center().x, 0.6, rect.get_center().y)
	var cam := focus + Vector3(0.0, sin(V3.CAM_PITCH), cos(V3.CAM_PITCH)) * 20.0
	var samples := [focus, Vector3(rect.position.x + 1.0, 1.0, rect.position.y + 1.0), Vector3(rect.end.x - 1.0, 1.0, rect.position.y + 1.0),
		Vector3(rect.position.x + 1.0, 1.0, rect.end.y - 1.0), Vector3(rect.end.x - 1.0, 1.0, rect.end.y - 1.0)]
	for oid in _lots:
		if oid == lot_id:
			continue
		var o: Dictionary = _lots[oid]
		var orect: Rect2 = o["rect"]
		if orect.position.y < rect.end.y - 0.5 or orect.position.y > rect.end.y + 40.0:
			continue
		var box_min := Vector3(orect.position.x, 0.0, orect.position.y)
		var box_max := Vector3(orect.end.x, float(o["h"]), orect.end.y)
		for s in samples:
			if _seg_box(s, cam, box_min, box_max):
				_hide(o.get("upper"))
				break


func _hide(n: Node) -> void:
	if n is Node3D and (n as Node3D).visible:
		(n as Node3D).visible = false
		_hidden.append(n)


static func _seg_box(a: Vector3, b: Vector3, lo: Vector3, hi: Vector3) -> bool:
	var d := b - a
	var t0 := 0.0
	var t1 := 1.0
	for k in 3:
		var da := d[k]
		if absf(da) < 0.0001:
			if a[k] < lo[k] or a[k] > hi[k]:
				return false
		else:
			var ta := (lo[k] - a[k]) / da
			var tb := (hi[k] - a[k]) / da
			if ta > tb:
				var tmp := ta
				ta = tb
				tb = tmp
			t0 = maxf(t0, ta)
			t1 = minf(t1, tb)
			if t0 > t1:
				return false
	return true


func _key(b: Dictionary) -> String:
	return "%s/%d" % [FrontArt.state_key(b), (b.get("broken", []) as Array).size()]


func update_owners() -> void:
	for b in Game.biz:
		var id := int(b["lot"])
		if not _lots.has(id):
			continue
		var info: Dictionary = _lots[id]
		var key := _key(b)
		if key == String(info.get("key", "")):
			continue
		info["key"] = key
		var lb := LotBuilder.new()
		lb.setup(info["lot"], b, info["xf"], [[], [], [], []], {})
		Shop.build_dynamic(lb)
		_make_dyn(id, lb)


func lot_height(lot_id: int) -> float:
	return float(_heights.get(lot_id, 6.0))
