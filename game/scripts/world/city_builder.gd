class_name CityBuilder
extends Node3D
## Builds the city you walk in from the CityPlan: Belgian-block side streets and asphalt
## avenues with granite crossings, trolley tracks and the Ninth Avenue El; flagstone pavements;
## brick, stucco and stone tenements and lofts (facade shader) with cornices, parapets, stoops,
## fire escapes, water towers and roof clutter; storefronts with striped awnings and painted
## signboards; bishop's-crook lamps and the street furniture of the 1920s; clotheslines over
## the back yards; the waterfront (quay, piers, freighters, a gantry crane, cargo, the union
## hall) and a ring of buildings that closes the map.
##
## Repeated props go through MultiMesh (see _mm_add / _flush), one draw call per prop kind and
## map chunk. Everything that stands above head height uses a cut-away material (see
## cutaway.gdshaderinc); its focus / cam_pos follow facade_mat, which World sets every frame.
##
## For other systems: dock_spots (named Vector3 positions on the waterfront), dock_paths
## (named PackedVector3Array walking loops), lot_height (lot id -> roof height in metres),
## make_rum_runner() (the night boat).

const SIGN_FONTS := ["Rye-Regular.ttf", "Limelight-Regular.ttf", "AlfaSlabOne-Regular.ttf", "Bevan-Regular.ttf",
	"AbrilFatface-Regular.ttf", "PlayfairDisplay.ttf", "IMFeENsc28P.ttf"]
const CHUNK := 96.0
const EL_X := 0.0                 # the elevated railway runs over the westernmost avenue
const TROLLEY_I := 3              # the avenue with streetcar tracks

var plan: CityPlan
var facade_mat: ShaderMaterial
var awning_mat: ShaderMaterial
var water_mat: ShaderMaterial
var asphalt_mat: StandardMaterial3D
var pave_mat: StandardMaterial3D
var cobble_mat: StandardMaterial3D
var granite_mat: StandardMaterial3D
var rail_mat: StandardMaterial3D
var awnings := {}     # biz id -> MeshInstance3D
var signs := {}       # biz id -> Label3D
var lamps: Array[OmniLight3D] = []
var lamp_heads: Array[MeshInstance3D] = []
var dock_spots := {}  # name -> Vector3 (see _waterfront)
var dock_paths := {}  # name -> PackedVector3Array
var lot_height := {}  # lot id -> metres
var _cut_mats: Array[ShaderMaterial] = []
var _lamp_head_mat: StandardMaterial3D
var _board_kit: MeshKit
var _mm := {}         # key -> {mesh, xf: Array[Transform3D], colors, shadow}
var _rng := RandomNumberGenerator.new()


func build(p: CityPlan) -> void:
	plan = p
	_rng.seed = p.seed_value + 5
	_make_materials()
	_board_kit = MeshKit.new()
	_ground()
	for b in plan.blocks:
		_sidewalk(b)
	for lot in plan.lots:
		_building(lot)
	for b in Game.biz:
		_storefront(b)
	var boards := MeshInstance3D.new()
	boards.name = "Signboards"
	boards.mesh = _board_kit.commit({"base": Props1920s.base_mat, "iron": Props1920s.iron_mat})
	add_child(boards)
	_lamps()
	_street_props()
	_clotheslines()
	_billboards()
	_el()
	_waterfront()
	_backdrop()
	_flush()


func _process(_delta: float) -> void:
	var f: Variant = facade_mat.get_shader_parameter("focus")
	var c: Variant = facade_mat.get_shader_parameter("cam_pos")
	for m in _cut_mats:
		m.set_shader_parameter("focus", f)
		m.set_shader_parameter("cam_pos", c)


func _tex(name: String) -> Texture2D:
	return load("res://assets/textures/%s.jpg" % name) as Texture2D


func _world_mat(albedo: String, normal: String, scale: float, tint: Color, rough: String = "") -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = _tex(albedo)
	if normal != "":
		m.normal_enabled = true
		m.normal_texture = _tex(normal)
	if rough != "":
		m.roughness_texture = _tex(rough)
	m.albedo_color = tint
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * scale
	return m


func _make_materials() -> void:
	facade_mat = ShaderMaterial.new()
	facade_mat.shader = preload("res://scripts/world/facade.gdshader")
	facade_mat.set_shader_parameter("brick_tex", _tex("brick_albedo"))
	facade_mat.set_shader_parameter("plaster_tex", _tex("plaster_albedo"))
	facade_mat.set_shader_parameter("roof_tex", _tex("concrete_wall_albedo"))
	facade_mat.set_shader_parameter("metal_tex", _tex("corrugated_albedo"))
	facade_mat.set_shader_parameter("ads_tex", _tex("wall_ads"))
	awning_mat = ShaderMaterial.new()
	awning_mat.shader = preload("res://scripts/world/awning.gdshader")
	water_mat = ShaderMaterial.new()
	water_mat.shader = preload("res://scripts/world/water.gdshader")
	asphalt_mat = _world_mat("asphalt_albedo", "asphalt_normal", 0.18, Color(0.42, 0.42, 0.41), "asphalt_rough")
	pave_mat = _world_mat("pavement_albedo", "pavement_normal", 0.3, Color(0.6, 0.6, 0.59))
	cobble_mat = _world_mat("belgian_block_albedo", "belgian_block_normal", 0.42, Color(0.55, 0.56, 0.6), "belgian_block_rough")
	granite_mat = _world_mat("pavement_albedo", "", 0.12, Color(0.78, 0.77, 0.74))
	granite_mat.vertex_color_use_as_albedo = true
	rail_mat = StandardMaterial3D.new()
	rail_mat.vertex_color_use_as_albedo = true
	rail_mat.metallic = 0.8
	rail_mat.roughness = 0.35
	_lamp_head_mat = StandardMaterial3D.new()
	_lamp_head_mat.albedo_color = Color("ffd9a0")
	_lamp_head_mat.emission_enabled = true
	_lamp_head_mat.emission = Color("ffc070")
	_lamp_head_mat.emission_energy_multiplier = 2.0
	_cut_mats.append_array(Props1920s.materials())
	_cut_mats.append(Harbour.hull_mat())


func set_night(v: float, wet: float) -> void:
	facade_mat.set_shader_parameter("night", v)
	facade_mat.set_shader_parameter("wet", wet)
	for aw in awnings.values():
		var am := (aw as MeshInstance3D).material_override as ShaderMaterial
		am.set_shader_parameter("night", v)
		am.set_shader_parameter("wet", wet)
	water_mat.set_shader_parameter("night", v)
	water_mat.set_shader_parameter("wet", wet)
	for m: StandardMaterial3D in [asphalt_mat, cobble_mat, granite_mat, pave_mat]:
		m.roughness = lerpf(1.0, 0.2, wet)
		m.metallic_specular = lerpf(0.5, 0.9, wet)
	asphalt_mat.albedo_color = Color(0.42, 0.42, 0.41).darkened(wet * 0.4)
	cobble_mat.albedo_color = Color(0.55, 0.56, 0.6).darkened(wet * 0.35)
	pave_mat.albedo_color = Color(0.6, 0.6, 0.59).darkened(wet * 0.3)
	Props1920s.set_night(v, wet)
	Harbour.set_night(v)
	var on := clampf((v - 0.25) / 0.4, 0.0, 1.0)
	for l in lamps:
		l.light_energy = on * 2.6
		l.visible = on > 0.01
	_lamp_head_mat.emission_energy_multiplier = 0.2 + on * 3.0


# ------------------------------------------------------------------ helpers

func _box(size: Vector3, pos: Vector3, mat: Material, yaw: float = 0.0, collide: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation.y = yaw
	add_child(mi)
	if collide:
		_collider(size, pos, yaw)
	return mi


func _collider(size: Vector3, pos: Vector3, yaw: float) -> void:
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	sb.add_child(cs)
	sb.position = pos
	sb.rotation.y = yaw
	add_child(sb)


## Queue one instance of a shared mesh; everything is turned into MultiMeshes by _flush().
func _mm_add(mesh: Mesh, xf: Transform3D, shadow := true, col := Color.WHITE) -> void:
	var cx := floori(xf.origin.x / CHUNK)
	var cz := floori(xf.origin.z / CHUNK)
	var key := "%d_%d_%d" % [mesh.get_instance_id(), cx, cz]
	if not _mm.has(key):
		_mm[key] = {"mesh": mesh, "xf": [], "col": [], "shadow": shadow}
	_mm[key]["xf"].append(xf)
	_mm[key]["col"].append(col)


func _flush() -> void:
	for key in _mm:
		var e: Dictionary = _mm[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		var colored := false
		for c: Color in e["col"]:
			if c != Color.WHITE:
				colored = true
				break
		mm.use_colors = colored
		mm.mesh = e["mesh"]
		mm.instance_count = e["xf"].size()
		for i in mm.instance_count:
			mm.set_instance_transform(i, e["xf"][i])
			if colored:
				mm.set_instance_color(i, e["col"][i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		if not e["shadow"]:
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
	_mm.clear()


func _xf(pos: Vector3, yaw: float, scale := Vector3.ONE) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw).scaled(scale), pos)


static func _unit_box() -> ArrayMesh:
	var k := MeshKit.new()
	k.box("base", Vector3.ZERO, Vector3.ONE, Color.WHITE)
	return k.commit({"base": Props1920s.base_mat})


# ------------------------------------------------------------------ ground

func _ground() -> void:
	var half := CityPlan.STREET * 0.5
	var P := CityPlan.PITCH
	var r := plan.bounds
	# asphalt everywhere, tiled so each piece gets its own nearby lamps
	var x0 := r.position.x
	while x0 < plan.water_x:
		var x1 := minf(x0 + P, plan.water_x)
		var z0 := r.position.y
		while z0 < r.end.y:
			var z1 := minf(z0 + P, r.end.y)
			var mi := MeshInstance3D.new()
			var pm := PlaneMesh.new()
			pm.size = Vector2(x1 - x0, z1 - z0)
			mi.mesh = pm
			mi.material_override = asphalt_mat
			mi.position = Vector3((x0 + x1) * 0.5, 0.0, (z0 + z1) * 0.5)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi)
			z0 = z1
		x0 = x1
	# Belgian block on the cross streets (the avenues keep their asphalt), one mesh per street
	for j in range(0, CityPlan.NZ + 1):
		var k := MeshKit.new()
		var z := j * P
		for i in range(-1, CityPlan.NX):
			var xa := i * P + half
			var xb := (i + 1) * P - half
			k.box("s", Vector3((xa + xb) * 0.5, 0.004, z), Vector3(xb - xa, 0.008, CityPlan.STREET), Color.WHITE, Basis.IDENTITY, true)
		var cm := MeshInstance3D.new()
		cm.mesh = k.commit({"s": cobble_mat})
		cm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(cm)
	# the trolley avenue: block paving between and around the rails, two tracks, conduit slots
	var tx := TROLLEY_I * P
	var tk := MeshKit.new()
	var rk := MeshKit.new()
	var tz0 := r.position.y
	var tz1 := r.end.y
	tk.box("s", Vector3(tx, 0.006, (tz0 + tz1) * 0.5), Vector3(6.4, 0.008, tz1 - tz0), Color.WHITE, Basis.IDENTITY, true)
	for c in [-1.6, 1.6]:
		for g in [-0.72, 0.72]:
			rk.box("r", Vector3(tx + c + g, 0.014, (tz0 + tz1) * 0.5), Vector3(0.08, 0.02, tz1 - tz0), Color(0.55, 0.53, 0.5))
		rk.box("r", Vector3(tx + c, 0.011, (tz0 + tz1) * 0.5), Vector3(0.05, 0.012, tz1 - tz0), Color(0.06, 0.06, 0.06))
	var tm := MeshInstance3D.new()
	tm.mesh = tk.commit({"s": cobble_mat})
	tm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(tm)
	var rm := MeshInstance3D.new()
	rm.mesh = rk.commit({"r": rail_mat})
	rm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rm)
	# granite crossing stones where the sidewalks meet the street, slab by slab
	var gk := MeshKit.new()
	for b in plan.blocks:
		var br: Array = b["rect"]
		for zc in [br[1] + 1.4, br[3] - 1.4]:
			# across the avenue to the east of this block
			if b["i"] + 1 <= CityPlan.NX:
				_crossing(gk, Vector3(br[2], 0, zc), Vector3(br[2] + CityPlan.STREET, 0, zc))
		for xc in [br[0] + 1.4, br[2] - 1.4]:
			if b["j"] + 1 <= CityPlan.NZ:
				_crossing(gk, Vector3(xc, 0, br[3]), Vector3(xc, 0, br[3] + CityPlan.STREET))
	var gm := MeshInstance3D.new()
	gm.mesh = gk.commit({"g": granite_mat})
	gm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(gm)
	# manholes down the middle of the streets
	for i in range(0, CityPlan.NX + 1):
		for j in CityPlan.NZ:
			if i * P != tx:
				_mm_add(Props1920s.manhole(), _xf(Vector3(i * P + 0.6, 0.0, j * P + P * 0.5 + _rng.randf_range(-8, 8)), 0.0), false)
	for j in range(0, CityPlan.NZ + 1):
		for i in CityPlan.NX:
			_mm_add(Props1920s.manhole(), _xf(Vector3(i * P + P * 0.5 + _rng.randf_range(-10, 10), 0.0, j * P - 0.8), 0.0), false)
			if _rng.randf() < 0.4:
				_mm_add(Props1920s.manhole(), _xf(Vector3(i * P + P * 0.5 + _rng.randf_range(-16, 16), 0.0, j * P + 2.8), 0.0), false)


## A band of granite slabs from a to b (1.2 m wide crossing).
func _crossing(k: MeshKit, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var len := d.length()
	var dir := d / len
	var side := Vector3(-dir.z, 0, dir.x)
	var n := int(len / 1.0)
	var sl := len / n
	for s in n:
		for row in 2:
			var c := a + dir * (sl * (s + 0.5)) + side * ((row - 0.5) * 0.62)
			var tone := 0.82 + _rng.randf() * 0.18
			var size := Vector3(sl - 0.05, 0.02, 0.58) if absf(dir.x) > 0.5 else Vector3(0.58, 0.02, sl - 0.05)
			k.box("g", c + Vector3(0, 0.01, 0), size, Color(tone, tone, tone * 0.98), Basis.IDENTITY, true)


func _sidewalk(b: Dictionary) -> void:
	var r: Array = b["rect"]
	var size := Vector3(r[2] - r[0], 0.16, r[3] - r[1])
	var pos := Vector3((r[0] + r[2]) * 0.5, 0.08, (r[1] + r[3]) * 0.5)
	var s := _box(size, pos, pave_mat)
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# granite kerb stones along the edge
	var kerb := StandardMaterial3D.new()
	kerb.albedo_color = Color(0.56, 0.55, 0.52)
	kerb.roughness = 0.8
	var k := _box(size + Vector3(0.3, -0.03, 0.3), pos - Vector3(0, 0.015, 0), kerb)
	k.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# ------------------------------------------------------------------ buildings

func _style_for(district: String) -> int:
	var opts: Array = [0, 1, 0, 2]
	match district:
		"Hell's Kitchen":
			opts = [0, 0, 1, 1, 2, 5]
		"Garment District":
			opts = [5, 5, 5, 0, 1]
		"Little Italy":
			opts = [2, 2, 2, 0, 1]
		"Lower East Side":
			opts = [0, 1, 1, 0, 2]
		"Waterfront":
			opts = [1, 0, 1, 2]
	return opts[_rng.randi_range(0, opts.size() - 1)]


func _tint_for(style: int) -> Color:
	match style:
		2:
			var st := [Color(0.95, 0.85, 0.7), Color(0.92, 0.75, 0.62), Color(0.85, 0.82, 0.7), Color(0.98, 0.93, 0.82),
				Color(0.82, 0.86, 0.76), Color(0.95, 0.8, 0.72)]
			return st[_rng.randi_range(0, st.size() - 1)]
		5:
			var so := [Color(0.95, 0.9, 0.8), Color(0.85, 0.8, 0.72), Color(0.9, 0.82, 0.7), Color(0.78, 0.74, 0.7)]
			return so[_rng.randi_range(0, so.size() - 1)]
	var br := [Color(0.95, 0.78, 0.68), Color(0.82, 0.62, 0.5), Color(0.72, 0.6, 0.55), Color(0.9, 0.7, 0.58),
		Color(0.66, 0.5, 0.42), Color(0.78, 0.66, 0.6)]
	return br[_rng.randi_range(0, br.size() - 1)]


func _is_corner(lot: Dictionary) -> bool:
	if lot["side"] not in ["N", "S"]:
		return false
	var b: Dictionary = {}
	for bl in plan.blocks:
		if bl["i"] == lot["block"][0] and bl["j"] == lot["block"][1]:
			b = bl
	if b.is_empty():
		return false
	var r: Array = b["rect"]
	var cx: float = lot["center"][0]
	var hw: float = lot["size"][0] * 0.5
	return absf(cx - hw - (r[0] + CityPlan.SIDEWALK)) < 0.3 or absf(cx + hw - (r[2] - CityPlan.SIDEWALK)) < 0.3


func _building(lot: Dictionary) -> void:
	var kind: String = lot["kind"]
	var w: float = lot["size"][0]
	var d: float = lot["size"][1]
	var floors: int = lot["floors"]
	var h := 4.2 + floors * 3.2 + 0.5
	var style := _style_for(lot["district"])
	if kind == "courtyard":
		h = 4.5
		style = 4
	elif kind == "warehouse":
		h = 9.0
		style = 3
	elif kind == "precinct":
		style = 5
	lot_height[lot["id"]] = h
	var pos := Vector3(lot["center"][0], h * 0.5, lot["center"][1])
	var yaw: float = lot["yaw"]
	var shop: bool = lot["shop"] and kind != "tenement"
	var corner := kind == "tenement" and _is_corner(lot)
	var ad := 0
	if kind != "courtyard" and kind != "warehouse" and floors >= 3 and not corner and _rng.randf() < 0.3:
		ad = _rng.randi_range(1, 8)
	var tint: Color = _tint_for(style) if style != 3 else [Color(0.55, 0.6, 0.55), Color(0.62, 0.45, 0.38), Color(0.5, 0.55, 0.62)][_rng.randi_range(0, 2)]
	var mi := _facade(Vector3(w - 0.08, h, d), tint, style, float(lot["id"]) * 0.37, shop, ad, corner,
		style != 4, style != 4)
	mi.position = pos
	mi.rotation.y = yaw
	_collider(Vector3(w, h, d), pos, yaw)
	if kind in ["courtyard", "warehouse"]:
		if kind == "courtyard":
			for s in _rng.randi_range(1, 3):
				_mm_add(Props1920s.skylight(), _xf(Vector3(pos.x + _rng.randf_range(-w * 0.35, w * 0.35), h, pos.z + _rng.randf_range(-d * 0.35, d * 0.35)), _rng.randi_range(0, 1) * PI * 0.5))
		return
	# rooftops: water towers, stair bulkheads, chimneys, skylights, vents, pigeon coops
	var basis := Basis(Vector3.UP, yaw)
	var roof := Vector3(pos.x, h, pos.z)
	var used: Array = []
	var place := func(local: Vector3, rad: float) -> bool:
		for u: Vector4 in used:
			if Vector2(u.x - local.x, u.z - local.z).length() < u.w + rad:
				return false
		used.append(Vector4(local.x, local.y, local.z, rad))
		return true
	if floors >= 4 and _rng.randf() < 0.4:
		var lp := Vector3(_rng.randf_range(-w * 0.2, w * 0.2), 0, _rng.randf_range(-d * 0.25, 0.0))
		if place.call(lp, 1.7):
			_mm_add(Props1920s.water_tower(), _xf(roof + basis * lp, _rng.randf() * TAU))
	if _rng.randf() < 0.6:
		var lp := Vector3(w * 0.28 * (1 if _rng.randf() < 0.5 else -1), 0, -d * 0.22)
		if place.call(lp, 1.6):
			_mm_add(Props1920s.bulkhead(), _xf(roof + basis * lp, yaw))
	for c in _rng.randi_range(1, 3):
		var lp := Vector3(_rng.randf_range(-w * 0.4, w * 0.4), 0, -d * 0.42 + _rng.randf() * 0.3)
		if place.call(lp, 0.5):
			_mm_add(Props1920s.chimney(), _xf(roof + basis * lp, yaw))
	if _rng.randf() < 0.45:
		var lp := Vector3(_rng.randf_range(-w * 0.25, w * 0.25), 0, _rng.randf_range(0.0, d * 0.25))
		if place.call(lp, 1.0):
			_mm_add(Props1920s.skylight(), _xf(roof + basis * lp, yaw))
	for v in _rng.randi_range(0, 2):
		var lp := Vector3(_rng.randf_range(-w * 0.4, w * 0.4), 0, _rng.randf_range(-d * 0.35, d * 0.35))
		if place.call(lp, 0.3):
			_mm_add(Props1920s.vent(), _xf(roof + basis * lp, 0.0))
	if lot["district"] in ["Lower East Side", "Little Italy"] and _rng.randf() < 0.12:
		var lp := Vector3(_rng.randf_range(-w * 0.2, w * 0.2), 0, d * 0.15)
		if place.call(lp, 1.2):
			_mm_add(Props1920s.pigeon_coop(), _xf(roof + basis * lp, yaw + _rng.randf_range(-0.3, 0.3)))
	var front := Vector3(pos.x, 0, pos.z) + basis * Vector3(0, 0, d * 0.5)
	# the stoop of a tenement, with ash cans beside it
	if not shop and kind == "tenement":
		_mm_add(Props1920s.stoop(), _xf(front + basis * Vector3(0, 0.16, 1.5), yaw))
		for c in _rng.randi_range(0, 3):
			var side := 1.0 if c % 2 == 0 else -1.0
			_mm_add(Props1920s.ash_can(), _xf(front + basis * Vector3(side * (1.35 + (c / 2) * 0.55), 0.16, 0.35 + _rng.randf() * 0.2), _rng.randf() * TAU))
	# fire escapes zig-zag down the fronts of the walk-ups
	var fe_chance := 0.8 if lot["district"] == "Lower East Side" else 0.55
	if floors >= 3 and not shop and _rng.randf() < fe_chance:
		var fw := snappedf(minf(w - 2.0, 4.4), 0.5)
		if fw >= 2.5:
			var ox := snappedf(_rng.randf_range(-0.6, 0.6), 0.1) if w - fw > 2.5 else 0.0
			for f in floors:
				var y := 4.2 + f * 3.2 + 0.02
				var dir := 1 if f % 2 == 0 else -1
				_mm_add(Props1920s.fire_escape(fw, dir, f == 0), _xf(front + basis * Vector3(ox, y, 0.01), yaw))


## One building with its look baked into the vertices (see facade.gdshader): the main box,
## a sheet-metal cornice across the front, a parapet round the roof, a storefront cornice.
func _facade(size: Vector3, tint: Color, style: int, seed: float, shop: bool, ad: int, corner: bool,
		cornice: bool, parapet: bool) -> MeshInstance3D:
	var k := MeshKit.new()
	var hy := size.y * 0.5
	k.box("p0", Vector3.ZERO, size, Color.WHITE, Basis.IDENTITY, true)
	if cornice and style != 3:
		k.box("p1", Vector3(0, hy - 0.3, size.z * 0.5 + 0.2), Vector3(size.x - 0.02, 0.6, 0.42), Color.WHITE)
	if shop and style != 3:
		k.box("p1", Vector3(0, -hy + 4.2, size.z * 0.5 + 0.1), Vector3(size.x - 0.06, 0.18, 0.22), Color.WHITE)
	if parapet:
		var ph := 0.7 if style != 3 else 0.5
		var t := 0.25
		k.box("p2", Vector3(0, hy + ph * 0.5, size.z * 0.5 - t * 0.5), Vector3(size.x, ph, t), Color.WHITE)
		k.box("p2", Vector3(0, hy + ph * 0.5, -size.z * 0.5 + t * 0.5), Vector3(size.x, ph, t), Color.WHITE)
		k.box("p2", Vector3(size.x * 0.5 - t * 0.5, hy + ph * 0.5, 0), Vector3(t, ph, size.z - 2.0 * t), Color.WHITE)
		k.box("p2", Vector3(-size.x * 0.5 + t * 0.5, hy + ph * 0.5, 0), Vector3(t, ph, size.z - 2.0 * t), Color.WHITE)
	var code := style + 8 * ad + (128 if corner else 0)
	var c := Color(tint.r, tint.g, tint.b, code / 255.0)
	var v := PackedVector3Array()
	var nn := PackedVector3Array()
	var cols := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var u2 := Vector2(size.x, size.z)
	for part in 3:
		var sname := "p%d" % part
		if not k.has_surface(sname):
			continue
		var s: MeshKit.Surf = k._s(sname)
		var u := Vector2(seed + (1000.0 if shop else 0.0) + part * 10000.0, size.y)
		v.append_array(s.v)
		nn.append_array(s.n)
		for i in s.v.size():
			cols.append(c)
			uv.append(u)
			uv2.append(u2)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = nn
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_TEX_UV2] = uv2
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.mesh = am
	mi.material_override = facade_mat
	add_child(mi)
	return mi


# ------------------------------------------------------------------ storefronts

func _awning_mesh(w: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw := w * 0.5
	var out := 1.45
	var drop := 0.62
	var val := 0.3
	# canvas: from the wall (y 0) out and down; valance hanging from the front edge
	var quads := [
		[Vector3(-hw, 0, 0), Vector3(hw, 0, 0), Vector3(hw, -drop, out), Vector3(-hw, -drop, out), 0.0, 1.0],
		[Vector3(-hw, -drop, out), Vector3(hw, -drop, out), Vector3(hw, -drop - val, out + 0.02), Vector3(-hw, -drop - val, out + 0.02), 1.0, 1.3],
	]
	for q in quads:
		var a: Vector3 = q[0]
		var b: Vector3 = q[1]
		var c: Vector3 = q[2]
		var d: Vector3 = q[3]
		var n := (b - a).cross(d - a).normalized()
		if n.y < 0.0 and q[4] == 0.0:
			n = -n
		var uvs := [Vector2(-hw / 3.2, q[4]), Vector2(hw / 3.2, q[4]), Vector2(hw / 3.2, q[5]), Vector2(-hw / 3.2, q[5])]
		for idx in [0, 2, 1, 0, 3, 2]:
			st.set_normal(n)
			st.set_uv(uvs[idx])
			st.add_vertex([a, b, c, d][idx])
	# side cheeks
	for s in [-1.0, 1.0]:
		var pts := [Vector3(s * hw, 0, 0), Vector3(s * hw, -drop, out), Vector3(s * hw, -drop - val * 0.6, out * 0.5)]
		for p in [pts[0], pts[2], pts[1]] if s > 0.0 else pts:
			st.set_normal(Vector3(s, 0, 0))
			st.set_uv(Vector2(0.0, 0.5))
			st.add_vertex(p)
	return st.commit()


func _storefront(b: Dictionary) -> void:
	var lot: Dictionary = plan.lots[b["lot"]]
	var yaw: float = lot["yaw"]
	var basis := Basis(Vector3.UP, yaw)
	var c := Vector3(lot["center"][0], 0, lot["center"][1])
	var w: float = lot["size"][0]
	var d: float = lot["size"][1]
	var front := c + basis * Vector3(0, 0, d * 0.5)
	var kind: String = b["kind"]
	var h := _rng.randf()
	if kind not in ["precinct", "warehouse"]:
		var aw := MeshInstance3D.new()
		aw.mesh = _awning_mesh(w - 1.3)
		var am := awning_mat.duplicate() as ShaderMaterial
		am.set_shader_parameter("fade", _rng.randf())
		aw.material_override = am
		_cut_mats.append(am)
		aw.position = front + basis * Vector3(0, 3.28, 0.02)
		aw.rotation = Vector3(0, yaw, 0)
		add_child(aw)
		awnings[b["id"]] = aw
		# cellar doors in the sidewalk beside some shops
		if _rng.randf() < 0.4 and w > 7.5:
			var side := 1.0 if _rng.randf() < 0.5 else -1.0
			_mm_add(Props1920s.cellar_doors(), _xf(front + basis * Vector3(side * (w * 0.5 - 1.1), 0.16, 0.6), yaw))
	# the painted signboard over the shop front, lettered in a period face
	var board_w := w - 1.1
	var board_h := 0.72
	var board_y := 3.72
	var board_z := 0.26
	if kind == "warehouse":
		board_w = 12.0
		board_h = 1.2
		board_y = 7.65
		board_z = 0.1
	var board_cols := [Color("1f2f24"), Color("5a1a16"), Color("141312"), Color("24324a"), Color("e3d8bc"), Color("3a2a1c")]
	var bcol: Color = board_cols[_rng.randi_range(0, board_cols.size() - 1)]
	if kind == "precinct":
		bcol = Color("1d2733")
	var light_board := bcol.get_luminance() > 0.5
	var bp := front + basis * Vector3(0, board_y, board_z)
	_board_kit.push(Transform3D(basis, bp))
	_board_kit.box("base", Vector3.ZERO, Vector3(board_w, board_h, 0.07), bcol)
	var trim := Color("b08d57") if not light_board else Color("5a1a16")
	_board_kit.box("base", Vector3(0, board_h * 0.5 - 0.03, 0.04), Vector3(board_w, 0.05, 0.02), trim)
	_board_kit.box("base", Vector3(0, -board_h * 0.5 + 0.03, 0.04), Vector3(board_w, 0.05, 0.02), trim)
	for s in [-1.0, 1.0]:
		_board_kit.box("base", Vector3(s * (board_w * 0.5 - 0.03), 0, 0.04), Vector3(0.05, board_h, 0.02), trim)
	_board_kit.pop()
	var l := Label3D.new()
	var text: String = b["name"]
	if kind == "precinct":
		text = "POLICE · 14th PRECINCT"
	l.text = text
	var fname: String = SIGN_FONTS[_rng.randi_range(0, SIGN_FONTS.size() - 1)]
	if kind == "precinct":
		fname = "IMFeENsc28P.ttf"
	var font := load("res://assets/fonts/signs/" + fname) as Font
	l.font = font
	l.font_size = 64
	l.outline_size = 0
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 64).x
	var th := font.get_height(64)
	l.pixel_size = minf((board_w - 0.4) / maxf(tw, 1.0), (board_h * 0.72) / maxf(th, 1.0))
	var ink: Color = [Color("e8d9b0"), Color("d9b25a"), Color("f0e8d4")][_rng.randi_range(0, 2)]
	if light_board:
		ink = [Color("5a1a16"), Color("1e140a"), Color("24324a")][_rng.randi_range(0, 2)]
	l.modulate = ink
	l.shaded = true
	l.double_sided = false
	l.position = bp + basis * Vector3(0, 0, 0.045)
	l.rotation.y = yaw
	l.visibility_range_end = 70.0
	l.no_depth_test = false
	add_child(l)
	signs[b["id"]] = l
	if kind == "precinct":
		for s in [-1.0, 1.0]:
			var g := OmniLight3D.new()
			g.light_color = Color("60ff90")
			g.omni_range = 5.0
			g.light_energy = 1.5
			g.position = front + basis * Vector3(s * 1.4, 2.6, 0.4)
			add_child(g)
			var bulb := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.16
			sm.height = 0.34
			bulb.mesh = sm
			bulb.material_override = _lamp_head_mat
			bulb.position = g.position
			bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(bulb)


func update_owners() -> void:
	for id in awnings:
		var b := Game.biz_by_id(id)
		if b.is_empty():
			continue
		var p: int = b["owned_by"] if b["owned_by"] >= 0 else b["protector"]
		var col := Color(0.42, 0.42, 0.4)
		if p >= 0:
			col = Color(Game.fam(p)["color"])
		((awnings[id] as MeshInstance3D).material_override as ShaderMaterial).set_shader_parameter("stripe", col)
	for id in signs:
		var b := Game.biz_by_id(id)
		if b.is_empty() or b["kind"] == "precinct":
			continue
		(signs[id] as Label3D).text = b["name"]


# ------------------------------------------------------------------ lamps and furniture

func _lamp_at(pos: Vector3, out: Vector3, lit: bool) -> void:
	var yaw := atan2(out.x, out.z)
	_mm_add(Props1920s.lamp_post(), _xf(pos, yaw))
	if not lit:
		return
	var light := OmniLight3D.new()
	light.light_color = Color("ffc47e")
	light.omni_range = 15.0
	light.omni_attenuation = 1.3
	light.light_energy = 0.0
	light.position = pos + Basis(Vector3.UP, yaw) * Props1920s.lamp_head()
	light.shadow_enabled = false
	add_child(light)
	lamps.append(light)


func _lamps() -> void:
	for b in plan.blocks:
		var r: Array = b["rect"]
		var cx: float = (r[0] + r[2]) * 0.5
		var cz: float = (r[1] + r[3]) * 0.5
		var corners := [Vector3(r[0] + 0.55, 0.16, r[1] + 0.55), Vector3(r[2] - 0.55, 0.16, r[1] + 0.55),
			Vector3(r[2] - 0.55, 0.16, r[3] - 0.55), Vector3(r[0] + 0.55, 0.16, r[3] - 0.55)]
		var lit_pair := [0, 2] if (b["i"] + b["j"]) % 2 == 0 else [1, 3]
		for k in 4:
			var c: Vector3 = corners[k]
			var out := Vector3(signf(c.x - cx), 0, signf(c.z - cz)).normalized()
			if b["i"] == 0 and c.x < cx:
				out = Vector3(0, 0, signf(c.z - cz))   # under the El the crook turns along the street
			_lamp_at(c, out, k in lit_pair)
		# mid-block posts on the long sides
		for z in [r[1] + 0.55, r[3] - 0.55]:
			_lamp_at(Vector3(cx + _rng.randf_range(-3, 3), 0.16, z), Vector3(0, 0, signf(z - cz)), false)


func _street_props() -> void:
	var P := CityPlan.PITCH
	for b in plan.blocks:
		var r: Array = b["rect"]
		var district: String = b["district"]
		var cz: float = (r[1] + r[3]) * 0.5
		# a hydrant near one corner, on the kerb
		var hx: float = r[0] + 2.2 if _rng.randf() < 0.5 else r[2] - 2.2
		var hz: float = r[1] + 0.5 if _rng.randf() < 0.5 else r[3] - 0.5
		_mm_add(Props1920s.hydrant(), _xf(Vector3(hx, 0.16, hz), 0.0 if hz > cz else PI))
		if _rng.randf() < 0.5:
			_mm_add(Props1920s.hydrant(), _xf(Vector3(lerpf(r[0], r[2], _rng.randf_range(0.3, 0.7)), 0.16, r[3] - 0.5 if hz < cz else r[1] + 0.5), 0.0))
		# fire-alarm post at alternate corners
		if (b["i"] + b["j"]) % 2 == 1:
			_mm_add(Props1920s.call_box(), _xf(Vector3(r[0] + 0.6, 0.16, r[1] + 2.0), -PI * 0.5))
		# a newsstand or a letter box
		if _rng.randf() < 0.5:
			var nz: float = lerpf(r[1], r[3], _rng.randf_range(0.25, 0.75))
			var at := Vector3(r[2] - 1.0, 0.16, nz)
			_mm_add(Props1920s.newsstand(), _xf(at, PI * 0.5))
			_collider(Vector3(1.1, 2.2, 2.0), at + Vector3(0, 1.1, 0), 0.0)
		else:
			var mz: float = lerpf(r[1], r[3], _rng.randf_range(0.25, 0.75))
			_mm_add(Props1920s.mailbox(), _xf(Vector3(r[0] + 0.6, 0.16, mz), -PI * 0.5))
		if _rng.randf() < 0.5:
			_mm_add(Props1920s.mailbox(), _xf(Vector3(r[2] - 0.6, 0.16, r[3] - 1.6), PI * 0.5))
		# pushcarts along the kerb in Little Italy and on the Lower East Side
		if district in ["Little Italy", "Lower East Side"]:
			for z in [r[1] - 0.95, r[3] + 0.95]:
				var x: float = r[0] + 5.0
				while x < r[2] - 5.0:
					if _rng.randf() < 0.55:
						var yaw := PI * 0.5 if _rng.randf() < 0.5 else -PI * 0.5
						_mm_add(Props1920s.pushcart(_rng.randi_range(0, 1)), _xf(Vector3(x, 0.0, z + _rng.randf_range(-0.1, 0.1)), yaw + _rng.randf_range(-0.12, 0.12)))
					x += _rng.randf_range(2.6, 4.0)
		# a horse trough here and there
		if district in ["Little Italy", "Lower East Side", "Hell's Kitchen", "Waterfront"] and _rng.randf() < 0.35:
			var tz: float = r[1] + 0.55 if _rng.randf() < 0.5 else r[3] - 0.55
			_mm_add(Props1920s.horse_trough(), _xf(Vector3(lerpf(r[0], r[2], _rng.randf_range(0.3, 0.7)), 0.16, tz), 0.0))


## Washing lines across the back yards of the tenement blocks, hung with laundry.
func _clotheslines() -> void:
	var unit := _unit_box()
	var cloth := [Color("ece6d6"), Color("e0d8c4"), Color("c8d0d8"), Color("9a3a30"), Color("3a5070"), Color("d8c8a0"), Color("f2efe6"), Color("6a7a5a")]
	for lot in plan.lots_of_kind("courtyard"):
		if lot["district"] in ["Garment District", "Waterfront"]:
			continue
		var cx: float = lot["center"][0]
		var cz: float = lot["center"][1]
		var w: float = lot["size"][0]
		var d: float = lot["size"][1]
		var bi: int = lot["block"][0]
		var bj: int = lot["block"][1]
		var x := cx - w * 0.5 + 1.2
		while x < cx + w * 0.5 - 1.2:
			if _rng.randf() < 0.6:
				var hn := _row_height(bi, bj, "N", x)
				var hs := _row_height(bi, bj, "S", x)
				var top := minf(hn, hs) - 1.2
				if top > 6.5:
					var y := _rng.randf_range(6.0, top)
					var z0 := cz - d * 0.5
					var z1 := cz + d * 0.5
					var len := z1 - z0
					_mm_add(unit, Transform3D(Basis().scaled(Vector3(0.015, 0.015, len)), Vector3(x, y - 0.25, (z0 + z1) * 0.5)), false, Color(0.2, 0.2, 0.2))
					var z := z0 + 0.8
					while z < z1 - 0.8:
						if _rng.randf() < 0.7:
							var sw := _rng.randf_range(0.35, 0.8)
							var sh := _rng.randf_range(0.4, 0.9)
							var sag := sin((z - z0) / len * PI) * 0.25
							_mm_add(unit, Transform3D(Basis(Vector3.UP, PI * 0.5).scaled(Vector3(sw, sh, 0.02)), Vector3(x, y - sag - sh * 0.5, z + sw * 0.5)),
								true, cloth[_rng.randi_range(0, cloth.size() - 1)])
							z += sw + 0.1
						else:
							z += 0.6
			x += _rng.randf_range(2.0, 3.2)


func _row_height(i: int, j: int, side: String, x: float) -> float:
	for lot in plan.lots:
		if lot["side"] == side and lot["block"][0] == i and lot["block"][1] == j:
			var cx: float = lot["center"][0]
			if absf(x - cx) <= lot["size"][0] * 0.5:
				return lot_height.get(lot["id"], 0.0)
	return 0.0


## Painted billboards on steel frames atop a few tall corner buildings.
func _billboards() -> void:
	var ads_mat := ShaderMaterial.new()
	ads_mat.shader = preload("res://scripts/world/prop_cut.gdshader")
	ads_mat.set_shader_parameter("tex", _tex("wall_ads"))
	ads_mat.set_shader_parameter("tex_mix", 1.0)
	ads_mat.set_shader_parameter("rough", 0.8)
	_cut_mats.append(ads_mat)
	var frame := MeshKit.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := 0
	for lot in plan.lots:
		if lot["kind"] == "courtyard" or lot["kind"] == "warehouse" or int(lot["floors"]) < 5:
			continue
		if not _is_corner(lot) or _rng.randf() > 0.55 or count >= 7:
			continue
		count += 1
		var h: float = lot_height[lot["id"]]
		var yaw: float = lot["yaw"]
		var basis := Basis(Vector3.UP, yaw)
		var c := Vector3(lot["center"][0], h + 0.7, lot["center"][1])
		var bw := 7.0
		var bh := 3.5
		var at := c + basis * Vector3(0, 1.2, 1.5)
		frame.push(Transform3D(basis, at))
		for s in [-1.0, 1.0]:
			for zz in [0.0, -1.4]:
				frame.box("iron", Vector3(s * 2.6, 0.5 + (bh * 0.5 if zz == 0.0 else 0.2), zz - 0.1), Vector3(0.12, bh + 1.0 if zz == 0.0 else 1.4, 0.12), Color("262728"))
			frame.cyl("iron", Vector3(s * 2.6, 0.9, -1.4), Vector3(s * 2.6, bh, -0.1), 0.04, 0.04, 4, Color("262728"), false, false)
		frame.box("iron", Vector3(0, 1.0 + bh * 0.5, -0.05), Vector3(bw + 0.2, bh + 0.2, 0.08), Color("3a3634"))
		frame.box("base", Vector3(0, 0.95, 0.25), Vector3(bw, 0.05, 0.5), Color("3a3634"))   # the catwalk
		frame.pop()
		var cell := _rng.randi_range(0, 7)
		var u0 := Vector2(float(cell % 2) * 0.5, float(cell / 2) * 0.25)
		var corners := [Vector3(-bw * 0.5, 1.0 + bh, 0.0), Vector3(bw * 0.5, 1.0 + bh, 0.0), Vector3(bw * 0.5, 1.0, 0.0), Vector3(-bw * 0.5, 1.0, 0.0)]
		var uvs := [u0, u0 + Vector2(0.5, 0), u0 + Vector2(0.5, 0.25), u0 + Vector2(0, 0.25)]
		var n := basis * Vector3(0, 0, 1)
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_normal(n)
			st.set_color(Color(0.62, 0.62, 0.62))
			st.set_uv(uvs[idx])
			st.add_vertex(at + basis * (corners[idx] as Vector3))
	var fm := MeshInstance3D.new()
	fm.mesh = frame.commit({"iron": Props1920s.iron_mat, "base": Props1920s.base_mat})
	add_child(fm)
	var sm := MeshInstance3D.new()
	sm.mesh = st.commit()
	sm.material_override = ads_mat
	add_child(sm)


## The elevated railway over the western avenue: columns at the kerbs, plate girders, ties and
## rails for two tracks, in 48 m pieces (one mesh each).
func _el() -> void:
	var P := CityPlan.PITCH
	var r := plan.bounds
	var steel := Color("2c3032")
	var steel2 := Color("3a3e40")
	var deck_y := 7.2
	var z := r.position.y + 10.0
	while z < r.end.y - 10.0:
		var z1 := minf(z + 48.0, r.end.y - 10.0)
		var k := MeshKit.new()
		var len := z1 - z
		var mid := (z + z1) * 0.5
		# longitudinal plate girders under each rail pair and at the edges
		for gx in [-4.2, -1.5, 1.5, 4.2]:
			k.box("iron", Vector3(EL_X + gx, deck_y - 0.6, mid), Vector3(0.35, 1.1, len), steel)
			k.box("iron", Vector3(EL_X + gx, deck_y - 0.05, mid), Vector3(0.5, 0.06, len), steel2)
			k.box("iron", Vector3(EL_X + gx, deck_y - 1.15, mid), Vector3(0.5, 0.06, len), steel2)
		# ties, rails, the guard timbers
		var t := z + 0.3
		while t < z1:
			k.box("base", Vector3(EL_X, deck_y + 0.08, t), Vector3(9.4, 0.14, 0.22), Color("2a231d"))
			t += 0.75
		for tr in [-1.5, 1.5]:
			for g in [-0.72, 0.72]:
				k.box("iron", Vector3(EL_X + tr + g, deck_y + 0.2, mid), Vector3(0.08, 0.1, len), Color("6a6660"))
			k.box("iron", Vector3(EL_X + tr + 1.05, deck_y + 0.22, mid), Vector3(0.1, 0.12, len), Color("4a4a48"))   # third rail
		for s in [-1.0, 1.0]:
			k.box("iron", Vector3(EL_X + s * 4.75, deck_y + 0.6, mid), Vector3(0.06, 0.06, len), steel)
			var pz := z
			while pz < z1:
				k.box("iron", Vector3(EL_X + s * 4.75, deck_y + 0.35, pz), Vector3(0.06, 0.55, 0.06), steel)
				pz += 2.0
		add_child(_mesh_node(k))
		z = z1
	# columns and cross girders, kept clear of the crossings
	var k2 := MeshKit.new()
	for j in range(-1, CityPlan.NZ + 1):
		for off in [12.0, 24.0, 36.0]:
			var cz: float = j * P + off
			if cz < r.position.y + 12.0 or cz > r.end.y - 12.0:
				continue
			for s in [-1.0, 1.0]:
				var cx: float = EL_X + s * 4.9
				k2.box("iron", Vector3(cx, (deck_y - 1.2) * 0.5, cz), Vector3(0.42, deck_y - 1.2, 0.42), steel)
				k2.box("iron", Vector3(cx, 0.25, cz), Vector3(0.7, 0.5, 0.7), Color("3a3634"))
				# knee braces
				k2.cyl("iron", Vector3(cx, deck_y - 2.6, cz), Vector3(cx - s * 1.4, deck_y - 1.2, cz), 0.07, 0.07, 4, steel, false, false)
				_collider(Vector3(0.6, 3.0, 0.6), Vector3(cx, 1.5, cz), 0.0)
			k2.box("iron", Vector3(EL_X, deck_y - 1.5, cz), Vector3(10.2, 0.7, 0.4), steel)
	add_child(_mesh_node(k2))


func _mesh_node(k: MeshKit) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = k.commit({"iron": Props1920s.iron_mat, "base": Props1920s.base_mat, "glow": Props1920s.glow_mat,
		"hull": Harbour.hull_mat()})
	return mi


# ------------------------------------------------------------------ the waterfront

func _waterfront() -> void:
	var q: Array = plan.quay_rect
	var concrete := _world_mat("concrete_wall_albedo", "concrete_wall_normal", 0.2, Color(0.55, 0.53, 0.5))
	var quay := _box(Vector3(q[2] - q[0], 0.2, q[3] - q[1]), Vector3((q[0] + q[2]) * 0.5, 0.1, (q[1] + q[3]) * 0.5), concrete)
	quay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# the river
	var water := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(160, plan.bounds.size.y + 80)
	pm.subdivide_width = 60
	pm.subdivide_depth = 80
	water.mesh = pm
	water.material_override = water_mat
	water.position = Vector3(plan.water_x + 80, -0.9, plan.bounds.position.y + plan.bounds.size.y * 0.5)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)
	var planks := _world_mat("planks_albedo", "planks_normal", 0.35, Color(0.6, 0.5, 0.4))
	var dk := MeshKit.new()        # everything else on the waterfront, merged
	var post := Color("2a2119")
	# the quay's granite edge, with gaps where the piers start
	var zs: Array = []
	for p in plan.piers:
		zs.append([p["z0"], p["z1"]])
	var z := float(q[1])
	for gap in zs:
		_collider(Vector3(0.6, 3, gap[0] - z), Vector3(plan.water_x + 0.3, 1.5, (z + gap[0]) * 0.5), 0.0)
		dk.box("base", Vector3(plan.water_x - 0.3, 0.22, (z + gap[0]) * 0.5), Vector3(0.6, 0.06, gap[0] - z), Color("8a857a"))
		z = gap[1]
	_collider(Vector3(0.6, 3, q[3] - z), Vector3(plan.water_x + 0.3, 1.5, (z + q[3]) * 0.5), 0.0)
	dk.box("base", Vector3(plan.water_x - 0.3, 0.22, (z + q[3]) * 0.5), Vector3(0.6, 0.06, q[3] - z), Color("8a857a"))
	# timber face of the bulkhead down to the water
	dk.box("base", Vector3(plan.water_x + 0.05, -0.4, (q[1] + q[3]) * 0.5), Vector3(0.1, 1.2, q[3] - q[1]), Color("3a2e24"))
	# rails for the gantry crane along the quay
	for rx in [plan.water_x - 1.2, plan.water_x - 6.2]:
		dk.box("iron", Vector3(rx, 0.21, (q[1] + q[3]) * 0.5), Vector3(0.08, 0.03, q[3] - q[1] - 2.0), Color("5a5650"))
	for pi in plan.piers.size():
		var p: Dictionary = plan.piers[pi]
		var len: float = p["x1"] - p["x0"]
		var wd: float = p["z1"] - p["z0"]
		var cx: float = (p["x0"] + p["x1"]) * 0.5
		var cz: float = (p["z0"] + p["z1"]) * 0.5
		var deck := _box(Vector3(len, 0.3, wd), Vector3(cx, 0.05, cz), planks)
		deck.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_collider(Vector3(len, 3, 0.4), Vector3(cx, 1.5, p["z0"] - 0.2), 0.0)
		_collider(Vector3(len, 3, 0.4), Vector3(cx, 1.5, p["z1"] + 0.2), 0.0)
		_collider(Vector3(0.4, 3, wd), Vector3(p["x1"] + 0.2, 1.5, cz), 0.0)
		# pilings in clusters, a stringer, bollards along the edges
		var x: float = p["x0"] + 1.5
		while x < p["x1"]:
			for s in [p["z0"] - 0.1, p["z1"] + 0.1]:
				dk.cyl("base", Vector3(x, -1.6, s), Vector3(x, 0.25, s), 0.17, 0.16, 7, post)
			dk.cyl("base", Vector3(x, -1.6, cz), Vector3(x, -0.1, cz), 0.16, 0.16, 6, post)
			x += 3.0
		dk.box("base", Vector3(cx, -0.15, p["z0"] - 0.05), Vector3(len, 0.25, 0.12), Color("3a2e24"))
		dk.box("base", Vector3(cx, -0.15, p["z1"] + 0.05), Vector3(len, 0.25, 0.12), Color("3a2e24"))
		for bx in [p["x0"] + 4.0, p["x0"] + 12.0, p["x1"] - 3.0]:
			for s in [p["z0"] + 0.35, p["z1"] - 0.35]:
				_mm_add(Props1920s.bollard(), _xf(Vector3(bx, 0.2, s), 0.0))
		# a harbour lamp at the end of every pier
		_lamp_at(Vector3(p["x1"] - 0.6, 0.2, p["z0"] + 0.5), Vector3(0, 0, -1), true)
		# fenders on the ship side
		if pi != 1:
			var fz: float = p["z0"] - 0.25 if pi == 0 else p["z1"] + 0.25
			var fx: float = p["x0"] + 3.0
			while fx < p["x1"] - 1.0:
				dk.cyl("base", Vector3(fx, -0.9, fz), Vector3(fx, 0.35, fz), 0.13, 0.13, 6, Color("2a241e"))
				fx += 2.5
	# bollards along the quay edge between the piers
	var bz := float(q[1]) + 3.0
	while bz < float(q[3]) - 2.0:
		var near_pier := false
		for gap in zs:
			if bz > gap[0] - 1.0 and bz < gap[1] + 1.0:
				near_pier = true
		if not near_pier:
			_mm_add(Props1920s.bollard(), _xf(Vector3(plan.water_x - 0.7, 0.2, bz), 0.0))
		bz += 9.0
	# quay lamps
	var lz := float(q[1]) + 10.0
	while lz < float(q[3]) - 5.0:
		_lamp_at(Vector3(plan.water_x - 1.6, 0.2, lz), Vector3(1, 0, 0), int(lz) % 2 == 0)
		lz += 30.0
	# freighters alongside the outer piers, their derricks swung out over the pier
	var ships := [[plan.piers[0], -1.0, "S.S. MARY DONNELLY", "HOBOKEN"], [plan.piers[2], 1.0, "S.S. CASTELLAMARE", "NAPOLI"]]
	var hull_mesh := Harbour.freighter()
	for si in ships.size():
		var p: Dictionary = ships[si][0]
		var side: float = ships[si][1]
		var zc: float = (p["z0"] - 5.2) if side < 0.0 else (p["z1"] + 5.2)
		var at := Vector3(p["x0"] + 27.5, -0.9, zc)
		var yaw := PI * 0.5 if side < 0.0 else -PI * 0.5
		var ship := MeshInstance3D.new()
		ship.mesh = hull_mesh
		ship.position = at
		ship.rotation.y = yaw
		add_child(ship)
		for lab_side in [-1.0, 1.0]:
			var l := Label3D.new()
			l.text = "%s\n%s" % [ships[si][2], ships[si][3]]
			l.font = load("res://assets/fonts/signs/IMFeENsc28P.ttf")
			l.font_size = 64
			l.pixel_size = 0.006
			l.modulate = Color("e8e0cc")
			l.shaded = true
			l.double_sided = false
			l.outline_size = 0
			var lp := Basis(Vector3.UP, yaw) * Vector3(lab_side * 4.24, 2.9, 10.0)
			l.position = at + lp
			l.rotation.y = yaw + PI * 0.5 * lab_side
			add_child(l)
		dock_spots["freighter_%d" % si] = at + Vector3(0, 3.6, 0)
		# gangway from the deck to the pier
		var gz: float = p["z0"] if side < 0.0 else p["z1"]
		var gx: float = p["x0"] + 19.5
		dk.push(Transform3D(Basis(Vector3.RIGHT, -0.33 * side), Vector3(gx, 1.2, gz + side * -1.4)))
		dk.box("base", Vector3.ZERO, Vector3(0.9, 0.06, 3.0), Color("5a4a38"))
		for s in [-0.45, 0.45]:
			dk.box("iron", Vector3(s, 0.5, 0), Vector3(0.04, 0.04, 3.0), Color("2a2622"))
		dk.pop()
		# mooring lines to the pier bollards
		for mx in [p["x0"] + 4.0, p["x1"] - 3.0]:
			var a := Vector3(mx, 0.6, (p["z0"] + 0.35) if side < 0.0 else (p["z1"] - 0.35))
			var b := Vector3(mx + (-3.0 if mx < p["x0"] + 10.0 else 3.0), 3.3, zc - side * -3.8)
			var pts: Array = []
			for sgi in 9:
				var t := sgi / 8.0
				pts.append(a.lerp(b, t) + Vector3(0, -sin(t * PI) * 0.5, 0))
			dk.tube("base", pts, 0.04, 4, Color("8a7a5a"))
		# a sling of cargo hanging from the forward derrick over the pier
		var hook := Vector3(p["x0"] + 10.0, 5.0, (p["z0"] + p["z1"]) * 0.5 + side * 0.8)
		dk.cyl("iron", hook + Vector3(0, 0.6, 0), hook + Vector3(0, 6.5, side * 3.0), 0.015, 0.015, 3, Color("222222"), false, false)
		_mm_add(Props1920s.pallet(), _xf(hook - Vector3(0, 0.9, 0), 0.3))
	# the gantry crane on the quay by the third pier
	var crane := MeshInstance3D.new()
	crane.mesh = Harbour.gantry()
	crane.position = Vector3(plan.water_x - 3.7, 0.2, plan.piers[2]["z1"] + 14.0)
	add_child(crane)
	_collider(Vector3(6.0, 3.0, 0.8), crane.position + Vector3(0, 1.5, -2.6), 0.0)
	_collider(Vector3(6.0, 3.0, 0.8), crane.position + Vector3(0, 1.5, 2.6), 0.0)
	dock_spots["crane"] = crane.position
	# the longshoremen's hiring hall between the first warehouse and the middle pier
	var hall_z: float = (plan.piers[0]["z1"] + plan.piers[1]["z0"]) * 0.5 + 8.0
	var hall_at := Vector3(q[0] + 13.0, 0.2, hall_z)
	var hall := MeshInstance3D.new()
	hall.mesh = Harbour.union_hall()
	hall.position = hall_at
	hall.rotation.y = -PI * 0.5
	add_child(hall)
	_collider(Vector3(5.2, 4.0, 7.2), hall_at + Vector3(0, 2.0, 0), 0.0)
	var hl := Label3D.new()
	hl.text = "DOCK & PIER WORKERS\nLOCAL 37 · HIRING HALL"
	hl.font = load("res://assets/fonts/signs/AlfaSlabOne-Regular.ttf")
	hl.font_size = 48
	hl.pixel_size = 0.0065
	hl.modulate = Color("e8dcb8")
	hl.shaded = true
	hl.double_sided = false
	hl.outline_size = 0
	hl.position = hall_at + Vector3(-2.66, 3.25, 0)
	hl.rotation.y = -PI * 0.5
	add_child(hl)
	dock_spots["union_hall"] = hall_at + Vector3(-3.4, 0, 0.8)
	dock_spots["union_boss"] = hall_at + Vector3(-3.2, 0, -1.4)
	var hall_lamp := OmniLight3D.new()
	hall_lamp.light_color = Color("ffc47e")
	hall_lamp.omni_range = 8.0
	hall_lamp.light_energy = 0.0
	hall_lamp.position = hall_at + Vector3(-3.0, 3.0, 0)
	add_child(hall_lamp)
	lamps.append(hall_lamp)
	# cargo: stacks of crates, barrels, sacks, a few rope coils; each stack collides as one box
	var stacks: Array = []
	for lot in plan.lots_of_kind("warehouse"):
		var wz: float = lot["center"][1]
		dock_spots["warehouse_%d_stack" % lot["id"]] = Vector3(q[0] + 2.4, 0.2, wz + 5.6)
		dock_spots["warehouse_%d_door" % lot["id"]] = Vector3(lot["door"][0], 0.2, lot["door"][1])
		# behind the warehouse, along the water
		stacks.append([Vector3(plan.water_x - 3.0, 0.2, wz - 5.0), "crates"])
		stacks.append([Vector3(plan.water_x - 3.2, 0.2, wz + 4.0), "barrels"])
	for pi in [0, 2]:
		var p: Dictionary = plan.piers[pi]
		var sz: float = (p["z0"] + p["z1"]) * 0.5 - (1.2 if pi == 0 else -1.2)
		stacks.append([Vector3(p["x0"] + 7.0, 0.2, sz), "crates"])
		stacks.append([Vector3(p["x0"] + 20.0, 0.2, sz), "sacks"])
	stacks.append([Vector3(q[0] + 16.0, 0.2, hall_z + 12.0), "barrels"])
	stacks.append([Vector3(plan.water_x - 3.0, 0.2, hall_z - 2.0), "sacks"])
	for s in stacks:
		_cargo(s[0], s[1])
	_mm_add(Props1920s.rope_coil(), _xf(Vector3(plan.water_x - 1.6, 0.2, hall_z + 4.0), 0.0))
	_mm_add(Props1920s.rope_coil(), _xf(Vector3(plan.piers[2]["x1"] - 2.0, 0.2, plan.piers[2]["z0"] + 1.2), 0.0))
	# longshoremen's walking loops: from each freighter's gangway along the quay to a warehouse
	var wh := plan.lots_of_kind("warehouse")
	for si in 2:
		var p: Dictionary = plan.piers[0 if si == 0 else 2]
		var gz: float = (p["z0"] + 0.9) if si == 0 else (p["z1"] - 0.9)
		var gang := Vector3(p["x0"] + 19.5, 0.2, gz)
		var wlot: Dictionary = wh[si if si < wh.size() else 0]
		var stack: Vector3 = dock_spots["warehouse_%d_stack" % wlot["id"]]
		for n in 3:
			var key := "dock_worker_%d" % (si * 3 + n)
			var jitter := Vector3(0, 0, (n - 1) * 0.8)
			var path := PackedVector3Array([gang + jitter, Vector3(p["x0"] + 2.0, 0.2, gz) + jitter,
				Vector3(plan.water_x - 4.5, 0.2, (gz + stack.z) * 0.5) + jitter, stack + Vector3(1.2, 0, 0) + jitter])
			dock_paths[key] = path
			dock_spots[key] = path[0]
	add_child(_mesh_node(dk))
	water_mat.set_shader_parameter("quay_x", plan.water_x)
	var rects := PackedVector4Array()
	for p in plan.piers:
		rects.append(Vector4(p["x0"], p["z0"] - 0.3, p["x1"] + 0.2, p["z1"] + 0.3))
	for si in 2:
		var fs: Vector3 = dock_spots["freighter_%d" % si]
		rects.append(Vector4(fs.x - 22.0, fs.z - 4.25, fs.x + 22.0, fs.z + 4.25))
	while rects.size() < 6:
		rects.append(Vector4(-1000, -1000, -999, -999))
	water_mat.set_shader_parameter("foam_rects", rects)


func _cargo(at: Vector3, what: String) -> void:
	var size := Vector3(3.2, 2.0, 2.6)
	match what:
		"crates":
			for i in 3:
				for j in 2:
					var layers := _rng.randi_range(1, 3)
					for l in layers:
						var p := at + Vector3((i - 1) * 1.05, l * 0.8, (j - 0.5) * 0.85)
						_mm_add(Props1920s.crate(_rng.randi_range(0, 2)), _xf(p, _rng.randf_range(-0.06, 0.06) + (PI * 0.5 if l % 2 == 1 else 0.0) * 0.0))
		"barrels":
			for i in 4:
				for j in 3:
					var p := at + Vector3((i - 1.5) * 0.7, 0.0, (j - 1) * 0.7)
					_mm_add(Props1920s.barrel(), _xf(p, _rng.randf() * TAU))
					if _rng.randf() < 0.35:
						_mm_add(Props1920s.barrel(), _xf(p + Vector3(0, 0.9, 0), _rng.randf() * TAU))
			size = Vector3(3.0, 1.8, 2.2)
		"sacks":
			for l in 4:
				for i in 3:
					for j in 2:
						if l == 3 and _rng.randf() < 0.5:
							continue
						var p := at + Vector3((i - 1) * 0.95 + (0.2 if l % 2 == 1 else 0.0), l * 0.26, (j - 0.5) * 0.6)
						_mm_add(Props1920s.sack(), _xf(p, (PI * 0.5 if l % 2 == 1 else 0.0) * 0.0 + _rng.randf_range(-0.15, 0.15)))
			size = Vector3(3.2, 1.2, 1.6)
	_collider(size, at + Vector3(0, size.y * 0.5, 0), 0.0)


## The rum-runner that ties up at the middle pier at night (built for World._boat()).
func make_rum_runner() -> Node3D:
	return Harbour.rum_runner()


func _backdrop() -> void:
	# a ring of blocks beyond the outer streets closes the map in
	var half := CityPlan.STREET * 0.5
	var out := []
	for j in range(-1, CityPlan.NZ + 1):
		out.append(Vector2i(-1, j))
	for i in CityPlan.NX:
		out.append(Vector2i(i, -1))
		out.append(Vector2i(i, CityPlan.NZ))
	for c in out:
		var x0: float = c.x * CityPlan.PITCH + half
		var z0: float = c.y * CityPlan.PITCH + half
		var w := CityPlan.PITCH - CityPlan.STREET
		var h := _rng.randf_range(14.0, 24.0)
		var pos := Vector3(x0 + w * 0.5, h * 0.5, z0 + w * 0.5)
		var st: int = [0, 1, 2, 5][_rng.randi_range(0, 3)]
		var mi := _facade(Vector3(w, h, w), _tint_for(st), st, float(c.x * 13 + c.y + 20), false, 0, true, true, true)
		mi.position = pos
		mi.rotation.y = [0.0, PI * 0.5, PI, -PI * 0.5][_rng.randi_range(0, 3)]
		_collider(Vector3(w, h, w), pos, 0.0)
		_box(Vector3(w + 1.0, 0.16, w + 1.0), Vector3(pos.x, 0.08, pos.z), pave_mat)
		var roof := Vector3(pos.x, h, pos.z)
		if _rng.randf() < 0.7:
			_mm_add(Props1920s.water_tower(), _xf(roof + Vector3(_rng.randf_range(-w * 0.3, w * 0.3), 0, _rng.randf_range(-w * 0.3, w * 0.3)), _rng.randf() * TAU))
		for n in 3:
			_mm_add(Props1920s.chimney(), _xf(roof + Vector3(_rng.randf_range(-w * 0.4, w * 0.4), 0, _rng.randf_range(-w * 0.4, w * 0.4)), 0.0))
	# the far side of the outer streets: walls
	var r := plan.bounds
	_collider(Vector3(2, 6, r.size.y), Vector3(-half - CityPlan.PITCH * 0.5, 3, r.position.y + r.size.y * 0.5), 0.0)
