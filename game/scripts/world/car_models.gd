class_name CarModels
extends RefCounted
## Period motor vehicles, modelled in code (metres, +z forward, ground at y = 0):
##   truck    - a Model TT style one-ton stake truck (the family truck: cab in the family colour)
##   delivery - the same chassis with a closed cab and tall slatted express sides
##   sedan    - a Model A style two-door sedan
##   taxi     - a sedan in cab livery: two-tone, checker belt, roof lamp, meter flag
##   van      - a panel delivery van with a rounded roof
##   police   - a paddy wagon: panel body, barred rear windows, roof lamp and bell
## Meshes are built once per kind and shared. Surfaces: paint (tinted per vehicle), trim
## (vertex colours), metal (nickel and brass), glass, lamp (emissive, switched on at night).

const BLACK := Color("17181a")
const TYRE := Color("1b1a19")
const NICKEL := Color("c8c3b6")
const BRASS := Color("b08d57")
const WOOD := Color("8a6a45")
const DARK_WOOD := Color("5a432e")
const LEATHER := Color("3b2a20")
const RED_LAMP := Color("b0201a")

static var _bodies := {}
static var _wheels := {}
static var trim_mat: StandardMaterial3D
static var metal_mat: StandardMaterial3D
static var glass_mat: StandardMaterial3D
static var lamp_mat: StandardMaterial3D
static var tail_mat: StandardMaterial3D


## Everything a Vehicle needs to assemble one: mesh, wheel layout, lamp positions, bed height.
static func spec(kind: String) -> Dictionary:
	match kind:
		"truck", "delivery":
			return {"wheels": [[Vector3(0.72, 0.38, 1.55), 0.38, true], [Vector3(-0.72, 0.38, 1.55), 0.38, true],
				[Vector3(0.74, 0.40, -1.45), 0.40, false], [Vector3(-0.74, 0.40, -1.45), 0.40, false]],
				"wheel": "spoke", "lamps": [Vector3(0.45, 1.15, 2.15), Vector3(-0.45, 1.15, 2.15)],
				"bed_y": 1.03, "length": 4.7, "width": 1.9}
		"van", "police":
			return {"wheels": [[Vector3(0.70, 0.36, 1.45), 0.36, true], [Vector3(-0.70, 0.36, 1.45), 0.36, true],
				[Vector3(0.72, 0.37, -1.35), 0.37, false], [Vector3(-0.72, 0.37, -1.35), 0.37, false]],
				"wheel": "disc" if kind == "police" else "spoke",
				"lamps": [Vector3(0.44, 1.12, 2.05), Vector3(-0.44, 1.12, 2.05)], "bed_y": 0.9,
				"length": 4.5, "width": 1.8}
		_:
			return {"wheels": [[Vector3(0.70, 0.34, 1.30), 0.34, true], [Vector3(-0.70, 0.34, 1.30), 0.34, true],
				[Vector3(0.70, 0.34, -1.30), 0.34, false], [Vector3(-0.70, 0.34, -1.30), 0.34, false]],
				"wheel": "wire", "lamps": [Vector3(0.42, 1.0, 1.86), Vector3(-0.42, 1.0, 1.86)], "bed_y": 0.9,
				"length": 4.2, "width": 1.72}


static func _materials() -> void:
	if trim_mat:
		return
	trim_mat = StandardMaterial3D.new()
	trim_mat.vertex_color_use_as_albedo = true
	trim_mat.roughness = 0.7
	metal_mat = StandardMaterial3D.new()
	metal_mat.vertex_color_use_as_albedo = true
	metal_mat.metallic = 0.85
	metal_mat.roughness = 0.3
	glass_mat = StandardMaterial3D.new()
	glass_mat.albedo_color = Color(0.16, 0.19, 0.21)
	glass_mat.metallic = 0.55
	glass_mat.roughness = 0.06
	lamp_mat = StandardMaterial3D.new()
	lamp_mat.albedo_color = Color("d8d0bc")
	lamp_mat.emission_enabled = true
	lamp_mat.emission = Color("ffd89a")
	lamp_mat.emission_energy_multiplier = 0.1
	tail_mat = StandardMaterial3D.new()
	tail_mat.albedo_color = RED_LAMP
	tail_mat.emission_enabled = true
	tail_mat.emission = Color("ff3020")
	tail_mat.emission_energy_multiplier = 0.1


static func set_night(v: float) -> void:
	_materials()
	lamp_mat.emission_energy_multiplier = 0.1 + v * 4.0
	tail_mat.emission_energy_multiplier = 0.1 + v * 2.5


## The paint material for one vehicle (vertex colour x tint, a little lacquer sheen).
static func paint(tint: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.albedo_color = tint
	m.roughness = 0.32
	m.metallic = 0.15
	return m


static func body(kind: String) -> ArrayMesh:
	_materials()
	if _bodies.has(kind):
		return _bodies[kind]
	var k := MeshKit.new()
	match kind:
		"truck":
			_tt_chassis(k)
			_tt_cab(k, true)
			_stake_bed(k, 0.55)
		"delivery":
			_tt_chassis(k)
			_tt_cab(k, true)
			_stake_bed(k, 0.95)
		"van":
			_tt_chassis(k, 0.36, 1.45, -1.35)
			_panel_body(k, false)
		"police":
			_tt_chassis(k, 0.36, 1.45, -1.35)
			_panel_body(k, true)
		"taxi":
			_sedan(k, true)
		_:
			_sedan(k, false)
	var am := k.commit({"paint": paint(Color.WHITE), "trim": trim_mat, "metal": metal_mat, "glass": glass_mat,
		"lamp": lamp_mat, "tail": tail_mat})
	_bodies[kind] = am
	return am


## Index of the paint surface in body(kind) (-1 if none).
static func paint_surface(kind: String) -> int:
	var am := body(kind)
	for s in am.get_surface_count():
		if am.surface_get_name(s) == "paint":
			return s
	return -1


# ------------------------------------------------------------------ wheels

## A wheel centred at the origin, axle along x.
static func wheel(style: String, r: float) -> ArrayMesh:
	_materials()
	var key := "%s_%.2f" % [style, r]
	if _wheels.has(key):
		return _wheels[key]
	var k := MeshKit.new()
	var ax := Basis(Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1))   # lathe axis = +x
	var w := 0.075
	var tyre := [Vector2(r - 0.12, -w * 0.7), Vector2(r - 0.07, -w), Vector2(r - 0.02, -w * 0.85), Vector2(r, -w * 0.4),
		Vector2(r, w * 0.4), Vector2(r - 0.02, w * 0.85), Vector2(r - 0.07, w), Vector2(r - 0.12, w * 0.7)]
	k.lathe("trim", Vector3.ZERO, tyre, 18, TYRE, ax)
	var rim_r := r - 0.12
	match style:
		"spoke":
			# wooden artillery wheel: felloe, twelve spokes, a big hub
			k.lathe("trim", Vector3.ZERO, [Vector2(rim_r, -0.035), Vector2(rim_r - 0.035, -0.035), Vector2(rim_r - 0.035, 0.035), Vector2(rim_r, 0.035)], 16, DARK_WOOD, ax)
			for s in 12:
				var a := TAU * s / 12.0
				var d := Vector3(0, cos(a), sin(a))
				k.box("trim", d * (0.07 + (rim_r - 0.1) * 0.5), Vector3(0.04, rim_r - 0.08, 0.035), Color("a88a5e"),
					Basis(Vector3.RIGHT, a - PI * 0.5))
			k.cyl("metal", Vector3(-0.07, 0, 0), Vector3(0.07, 0, 0), 0.075, 0.075, 10, BLACK)
			k.cyl("metal", Vector3(0.07, 0, 0), Vector3(0.1, 0, 0), 0.045, 0.03, 8, NICKEL)
		"wire":
			k.lathe("trim", Vector3.ZERO, [Vector2(rim_r, -0.04), Vector2(rim_r - 0.03, -0.04), Vector2(rim_r - 0.03, 0.04), Vector2(rim_r, 0.04)], 16, BLACK, ax)
			for s in 20:
				var a := TAU * s / 20.0
				var d := Vector3(0, cos(a), sin(a))
				var side := -0.035 if s % 2 == 0 else 0.035
				k.cyl("metal", Vector3(side, 0, 0) + d * 0.05, d * (rim_r - 0.02), 0.006, 0.006, 3, NICKEL, false, false)
			k.lathe("metal", Vector3.ZERO, [Vector2(0.09, 0.03), Vector2(0.07, 0.07), Vector2(0.0, 0.09)], 12, NICKEL, ax)
		_:
			# a pressed-steel disc with a nickel hub cap
			k.lathe("trim", Vector3.ZERO, [Vector2(rim_r, -0.03), Vector2(rim_r * 0.7, 0.01), Vector2(0.1, 0.035), Vector2(0.0, 0.035)], 16, Color("2a2c2e"), ax)
			k.lathe("trim", Vector3.ZERO, [Vector2(rim_r, 0.03), Vector2(0.0, 0.03)], 16, Color("2a2c2e"), Basis(Vector3(0, 1, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1)))
			k.lathe("metal", Vector3.ZERO, [Vector2(0.09, 0.035), Vector2(0.06, 0.08), Vector2(0.0, 0.09)], 12, NICKEL, ax)
			for s in 5:
				var a := TAU * s / 5.0
				k.cyl("metal", Vector3(0.036, cos(a) * 0.14, sin(a) * 0.14), Vector3(0.05, cos(a) * 0.14, sin(a) * 0.14), 0.014, 0.014, 5, NICKEL)
	var am := k.commit({"trim": trim_mat, "metal": metal_mat})
	_wheels[key] = am
	return am


# ------------------------------------------------------------------ shared pieces

## A fender: a curved sheet over the wheel at (z, y) = c, running back or forward into the
## running board at height `board_y` and z = `board_z`; x from xa to xb.
static func _fender(k: MeshKit, c: Vector2, r: float, a0: float, a1: float, board_z: float, board_y: float,
		xa: float, xb: float, col: Color, surf := "trim") -> void:
	var pts: Array = []
	var ins: Array = []
	var board := Vector2(board_z, board_y + 0.035)
	if board_z > c.x:
		pts.append(board)
		ins.append(Vector2(0, -1))
	for p in MeshKit.arc(c, r, a0, a1, 10):
		pts.append(p)
		ins.append((c - p).normalized())
	if board_z <= c.x:
		pts.append(board)
		ins.append(Vector2(0, -1))
	var band := PackedVector2Array()
	for p in pts:
		band.append(p)
	for i in range(pts.size() - 1, -1, -1):
		band.append((pts[i] as Vector2) + (ins[i] as Vector2) * 0.035)
	k.extrude_x(surf, band, xa, xb, col)


static func _headlamp(k: MeshKit, at: Vector3, r: float, col: Color) -> void:
	var fwd := Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0))   # lathe axis = +z
	k.lathe("metal", at, [Vector2(0.0, -r * 0.9), Vector2(r * 0.55, -r * 0.8), Vector2(r * 0.92, -r * 0.4), Vector2(r, 0.0), Vector2(r * 0.9, 0.01)], 12, col, fwd)
	k.lathe("lamp", at, [Vector2(r * 0.9, 0.0), Vector2(r * 0.5, 0.025), Vector2(0.0, 0.03)], 12, Color.WHITE, fwd)


static func _tail_lamp(k: MeshKit, at: Vector3) -> void:
	k.box("tail", at, Vector3(0.1, 0.08, 0.05), Color.WHITE)
	k.box("trim", at + Vector3(0, -0.12, 0.01), Vector3(0.03, 0.18, 0.03), BLACK)


# ------------------------------------------------------------------ Model TT

static func _tt_chassis(k: MeshKit, fr := 0.38, fz := 1.55, rz := -1.45) -> void:
	# frame rails and axles
	for s in [0.42, -0.42]:
		k.box("trim", Vector3(s, 0.5, (fz + rz) * 0.5 - 0.2), Vector3(0.07, 0.12, fz - rz + 1.2), BLACK)
	k.box("trim", Vector3(0, fr, fz), Vector3(1.3, 0.06, 0.06), BLACK)
	k.box("trim", Vector3(0, 0.4, rz), Vector3(1.3, 0.1, 0.1), BLACK)
	k.cyl("trim", Vector3(0, 0.4, rz), Vector3(0, 0.38, rz + 0.35), 0.13, 0.08, 8, BLACK)   # differential
	# radiator: black shell, honeycomb core, cap
	var rz0 := fz + 0.58
	k.bbox("trim", Vector3(0, 1.0, rz0), Vector3(0.58, 0.66, 0.12), 0.03, BLACK)
	k.box("trim", Vector3(0, 0.98, rz0 + 0.062), Vector3(0.46, 0.52, 0.01), Color("2a2622"))
	for g in 7:
		k.box("trim", Vector3(0, 0.76 + g * 0.074, rz0 + 0.068), Vector3(0.46, 0.012, 0.004), Color("3c3630"))
	k.cyl("metal", Vector3(0, 1.33, rz0), Vector3(0, 1.39, rz0), 0.04, 0.035, 8, NICKEL)
	k.box("trim", Vector3(0, 0.62, rz0 - 0.02), Vector3(0.5, 0.1, 0.16), BLACK)   # apron
	# hood: flat top with rounded shoulders, louvres
	var hz0 := fz - 0.12
	var hz1 := rz0 - 0.06
	k.bbox("paint", Vector3(0, 1.02, (hz0 + hz1) * 0.5), Vector3(0.62, 0.48, hz1 - hz0), 0.08, Color(0.92, 0.92, 0.92))
	k.box("metal", Vector3(0, 1.265, (hz0 + hz1) * 0.5), Vector3(0.03, 0.01, hz1 - hz0), NICKEL)
	for s in [1.0, -1.0]:
		for l in 6:
			k.box("trim", Vector3(s * 0.312, 1.02, hz0 + 0.12 + l * 0.08), Vector3(0.004, 0.18, 0.02), Color("111111"))
	# drum headlamps on stalks
	for s in [1.0, -1.0]:
		k.cyl("trim", Vector3(s * 0.45, 0.72, fz + 0.5), Vector3(s * 0.45, 1.05, fz + 0.52), 0.015, 0.015, 5, BLACK)
		k.cyl("trim", Vector3(s * 0.45, 1.15, fz + 0.4), Vector3(s * 0.45, 1.15, fz + 0.58), 0.11, 0.11, 12, BLACK)
		_headlamp(k, Vector3(s * 0.45, 1.15, fz + 0.58), 0.1, NICKEL)
	# front fenders (flat Model T style) and running boards
	for s in [1.0, -1.0]:
		var xa := 0.6 if s > 0 else -0.88
		_fender(k, Vector2(fz, fr), fr + 0.08, 0.35, 2.75, fz - 0.62, 0.52, xa, xa + 0.28, BLACK)
		k.box("trim", Vector3(s * 0.74, 0.52, fz - 0.95), Vector3(0.28, 0.035, 0.7), Color("26241f"))
		k.box("metal", Vector3(s * 0.87, 0.54, fz - 0.95), Vector3(0.015, 0.01, 0.7), NICKEL)
	# crank handle
	k.cyl("trim", Vector3(0, 0.62, rz0 + 0.06), Vector3(0, 0.62, rz0 + 0.2), 0.012, 0.012, 4, BLACK)


static func _tt_cab(k: MeshKit, closed: bool) -> void:
	var z0 := 0.12
	var z1 := 1.4
	# cowl and dash
	k.bbox("paint", Vector3(0, 1.08, z1 - 0.08), Vector3(0.9, 0.62, 0.22), 0.06, Color(0.9, 0.9, 0.9))
	# lower cab sides and back
	k.bbox("paint", Vector3(0, 1.15, (z0 + z1) * 0.5 - 0.05), Vector3(1.36, 0.72, z1 - z0 - 0.1), 0.05, Color.WHITE)
	# seat backs and cushion (seen through the side openings)
	k.box("trim", Vector3(0, 1.62, z0 + 0.25), Vector3(1.2, 0.5, 0.2), LEATHER)
	# windscreen frame + glass
	var wz := z1 - 0.2
	k.box("glass", Vector3(0, 1.8, wz), Vector3(1.2, 0.56, 0.03), Color.WHITE)
	k.box("trim", Vector3(0, 2.09, wz), Vector3(1.28, 0.04, 0.05), BLACK)
	k.box("trim", Vector3(0, 1.52, wz), Vector3(1.28, 0.04, 0.05), BLACK)
	for s in [1.0, -1.0]:
		k.box("paint", Vector3(s * 0.66, 1.84, wz), Vector3(0.05, 0.62, 0.06), Color(0.85, 0.85, 0.85))
		k.box("paint", Vector3(s * 0.66, 1.84, z0 + 0.03), Vector3(0.06, 0.62, 0.06), Color(0.85, 0.85, 0.85))
		if closed:
			k.box("glass", Vector3(s * 0.675, 1.82, (z0 + wz) * 0.5), Vector3(0.02, 0.5, wz - z0 - 0.12), Color.WHITE)
			k.box("paint", Vector3(s * 0.675, 1.84, (z0 + wz) * 0.5), Vector3(0.03, 0.06, wz - z0), Color(0.85, 0.85, 0.85))
	# back wall with a small window
	k.box("paint", Vector3(0, 1.84, z0), Vector3(1.36, 0.62, 0.05), Color(0.88, 0.88, 0.88))
	k.box("glass", Vector3(0, 1.88, z0 - 0.03), Vector3(0.5, 0.26, 0.02), Color.WHITE)
	# the roof, slightly crowned, overhanging at the front as a visor
	k.bbox("paint", Vector3(0, 2.15, (z0 + z1) * 0.5 - 0.05), Vector3(1.46, 0.08, z1 - z0 + 0.12), 0.035, Color(0.8, 0.8, 0.8))
	k.box("trim", Vector3(0, 2.2, (z0 + z1) * 0.5 - 0.05), Vector3(1.3, 0.02, z1 - z0 - 0.1), Color("24221f"))
	# door line and handles
	for s in [1.0, -1.0]:
		k.box("trim", Vector3(s * 0.685, 1.15, z0 + 0.62), Vector3(0.004, 0.66, 0.012), Color("101010"))
		k.box("metal", Vector3(s * 0.69, 1.35, z0 + 0.55), Vector3(0.02, 0.02, 0.1), NICKEL)
		# small cowl lamps
		k.cyl("metal", Vector3(s * 0.5, 1.42, z1 + 0.0), Vector3(s * 0.5, 1.52, z1 + 0.0), 0.04, 0.035, 8, NICKEL)


## A flat stake bed from the cab back to the tail, stake sides `h` metres tall.
static func _stake_bed(k: MeshKit, h: float) -> void:
	var z0 := -2.35
	var z1 := 0.06
	var y := 1.03
	k.box("trim", Vector3(0, y - 0.04, (z0 + z1) * 0.5), Vector3(1.84, 0.08, z1 - z0), WOOD)
	# planks
	for p in 7:
		k.box("trim", Vector3(-0.79 + p * 0.263, y + 0.002, (z0 + z1) * 0.5), Vector3(0.008, 0.004, z1 - z0), DARK_WOOD)
	k.box("trim", Vector3(0, y - 0.16, (z0 + z1) * 0.5), Vector3(1.7, 0.14, z1 - z0 - 0.1), BLACK)   # sills
	var stakes := int((z1 - z0) / 0.6) + 1
	for s in [1.0, -1.0]:
		for i in stakes:
			var z := z0 + 0.06 + i * ((z1 - z0 - 0.12) / (stakes - 1))
			k.box("trim", Vector3(s * 0.9, y + h * 0.5, z), Vector3(0.06, h, 0.07), Color("4a3a2a"))
			k.box("metal", Vector3(s * 0.92, y + 0.06, z), Vector3(0.02, 0.12, 0.08), Color("2a2a2a"))
		for r in 3 if h > 0.7 else 2:
			var ry := y + 0.12 + r * (h - 0.16) / (2.0 if h > 0.7 else 1.0)
			k.box("trim", Vector3(s * 0.905, ry, (z0 + z1) * 0.5), Vector3(0.035, 0.1, z1 - z0), WOOD)
	# front board behind the cab and a low tailboard
	k.box("trim", Vector3(0, y + h * 0.5 + 0.05, z1 - 0.03), Vector3(1.84, h + 0.1, 0.05), WOOD)
	k.box("trim", Vector3(0, y + 0.12, z0 + 0.03), Vector3(1.84, 0.22, 0.05), WOOD)
	# rear fenders under the bed
	for s in [1.0, -1.0]:
		var xa := 0.56 if s > 0 else -0.92
		k.extrude_x("trim", MeshKit.arc(Vector2(-1.45, 0.4), 0.5, 0.25, 2.9, 8) + MeshKit.arc(Vector2(-1.45, 0.4), 0.46, 2.9, 0.25, 8), xa, xa + 0.36, BLACK)
	_tail_lamp(k, Vector3(-0.8, y - 0.15, z0 - 0.02))


# ------------------------------------------------------------------ Model A

static func _sedan(k: MeshKit, taxi: bool) -> void:
	var fz := 1.30
	var rz := -1.30
	var r := 0.34
	var lower := Color.WHITE
	var upper := Color("1a1a1c") if taxi else Color(0.82, 0.82, 0.82)
	var upper_surf := "trim" if taxi else "paint"
	# frame
	for s in [0.4, -0.4]:
		k.box("trim", Vector3(s, 0.44, -0.1), Vector3(0.07, 0.1, 3.9), BLACK)
	# radiator shell (nickel) with a black grille
	k.bbox("metal", Vector3(0, 0.94, 1.76), Vector3(0.62, 0.66, 0.1), 0.05, NICKEL)
	k.box("trim", Vector3(0, 0.93, 1.815), Vector3(0.5, 0.54, 0.01), Color("1c1b1a"))
	for g in 11:
		k.box("metal", Vector3(-0.22 + g * 0.044, 0.93, 1.822), Vector3(0.008, 0.52, 0.004), Color("6a655c"))
	k.cyl("metal", Vector3(0, 1.26, 1.76), Vector3(0, 1.33, 1.76), 0.035, 0.03, 8, NICKEL)
	# hood with a nickel centre strip; louvres along the side panels
	k.bbox("paint", Vector3(0, 1.0, 1.2), Vector3(0.74, 0.46, 1.04), 0.09, lower)
	k.box("metal", Vector3(0, 1.235, 1.2), Vector3(0.025, 0.008, 1.02), NICKEL)
	for s in [1.0, -1.0]:
		for l in 9:
			k.box("trim", Vector3(s * 0.373, 1.0, 0.9 + l * 0.075), Vector3(0.004, 0.2, 0.025), Color("0e0e0e"))
	# cowl blending the narrow hood into the wider body
	k.bbox("paint", Vector3(0, 1.0, 0.56), Vector3(1.1, 0.62, 0.34), 0.1, lower)
	k.bbox("paint", Vector3(0, 0.98, 0.5), Vector3(1.4, 0.8, 0.2), 0.1, lower)
	# the body tub, bevelled; a black belt moulding
	k.bbox("paint", Vector3(0, 0.93, -0.58), Vector3(1.46, 0.84, 2.1), 0.1, lower)
	k.box("trim" if not taxi else "trim", Vector3(0, 1.3, -0.58), Vector3(1.475, 0.035, 2.08), Color("141414"))
	if taxi:
		# the checker band along the belt line
		for s in [1.0, -1.0]:
			for c in 18:
				for row in 2:
					if (c + row) % 2 == 0:
						k.box("trim", Vector3(s * 0.736, 1.22 + row * 0.045, -1.52 + c * 0.1 + 0.05), Vector3(0.004, 0.045, 0.1), Color("111111"))
	# greenhouse: glass all round between pillars, then the roof with a front visor
	k.box("glass", Vector3(0, 1.55, -0.62), Vector3(1.34, 0.42, 1.76), Color.WHITE)
	for s in [1.0, -1.0]:
		for z in [0.26, -0.28, -1.48]:
			k.box(upper_surf, Vector3(s * 0.675, 1.55, z), Vector3(0.03, 0.44, 0.07 if z != -0.28 else 0.1), upper)
	k.box(upper_surf, Vector3(0, 1.345, 0.27), Vector3(1.36, 0.03, 0.05), upper)
	k.box(upper_surf, Vector3(0, 1.55, -1.5), Vector3(0.5, 0.44, 0.03), upper)
	k.bbox(upper_surf, Vector3(0, 1.8, -0.6), Vector3(1.44, 0.1, 1.96), 0.045, upper)
	k.box("trim", Vector3(0, 1.848, -0.62), Vector3(1.2, 0.012, 1.6), Color("202022") if not taxi else Color("151515"))
	k.box(upper_surf, Vector3(0, 1.76, 0.42), Vector3(1.36, 0.03, 0.14), upper)   # visor
	# doors: seams and nickel handles
	for s in [1.0, -1.0]:
		k.box("trim", Vector3(s * 0.733, 0.95, 0.24), Vector3(0.004, 0.8, 0.012), Color("0f0f0f"))
		k.box("trim", Vector3(s * 0.733, 0.95, -0.52), Vector3(0.004, 0.8, 0.012), Color("0f0f0f"))
		k.box("metal", Vector3(s * 0.74, 1.18, -0.42), Vector3(0.02, 0.02, 0.1), NICKEL)
	# fenders, running boards, the headlamp bar and bumpers
	for s in [1.0, -1.0]:
		var xa := 0.56 if s > 0 else -0.86
		_fender(k, Vector2(fz, r), r + 0.1, 0.25, 2.8, 0.45, 0.44, xa, xa + 0.3, BLACK)
		_fender(k, Vector2(rz, r), r + 0.1, 0.35, 2.85, -0.85, 0.44, xa, xa + 0.3, BLACK)
		k.box("trim", Vector3(s * 0.71, 0.44, -0.2), Vector3(0.3, 0.035, 1.3), Color("26241f"))
		k.box("metal", Vector3(s * 0.86, 0.455, -0.2), Vector3(0.012, 0.012, 1.3), NICKEL)
	k.cyl("metal", Vector3(-0.44, 0.98, 1.84), Vector3(0.44, 0.98, 1.84), 0.018, 0.018, 6, NICKEL)
	for s in [1.0, -1.0]:
		_headlamp(k, Vector3(s * 0.42, 1.02, 1.9), 0.12, NICKEL)
		k.cyl("metal", Vector3(s * 0.5, 1.42, 0.62), Vector3(s * 0.5, 1.5, 0.62), 0.035, 0.03, 8, NICKEL)   # cowl lamp
	for z in [2.08, -2.1]:
		for dy in [0.0, 0.1]:
			k.box("metal", Vector3(0, 0.46 + dy, z), Vector3(1.6, 0.045, 0.035), NICKEL)
		for s in [0.5, -0.5]:
			k.box("trim", Vector3(s, 0.5, z - signf(z) * 0.14), Vector3(0.04, 0.04, 0.3), BLACK)
	# spare tyre on the back, tail lamp
	var ax := Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))
	k.lathe("trim", Vector3(0, 0.88, -1.8), [Vector2(0.2, -0.07), Vector2(0.3, -0.075), Vector2(0.34, -0.04), Vector2(0.34, 0.04), Vector2(0.3, 0.075), Vector2(0.2, 0.07)], 16, TYRE, ax)
	k.lathe("paint", Vector3(0, 0.88, -1.8), [Vector2(0.21, 0.07), Vector2(0.0, 0.08)], 16, lower, ax)
	_tail_lamp(k, Vector3(-0.62, 0.95, -1.66))
	if taxi:
		# roof lamp and meter flag
		k.bbox("trim", Vector3(0, 1.94, 0.1), Vector3(0.46, 0.18, 0.14), 0.02, Color("1a1a1a"))
		k.box("lamp", Vector3(0, 1.94, 0.172), Vector3(0.38, 0.1, 0.01), Color.WHITE)
		k.box("lamp", Vector3(0, 1.94, 0.028), Vector3(0.38, 0.1, 0.01), Color.WHITE)
		k.box("metal", Vector3(0.62, 1.3, 0.55), Vector3(0.02, 0.2, 0.02), NICKEL)
		k.box("trim", Vector3(0.62, 1.42, 0.62), Vector3(0.015, 0.1, 0.16), Color("b02020"))


# ------------------------------------------------------------------ panel van / paddy wagon

static func _panel_body(k: MeshKit, police: bool) -> void:
	var z0 := -2.1
	var z1 := 0.95
	var dark := Color("1e2428") if police else Color.WHITE
	var surf := "trim" if police else "paint"
	# cab + body in one long box with a rounded roof: extruded outline along z
	var outline := PackedVector2Array()
	var hw := 0.84
	outline.append(Vector2(-hw, 0.62))
	outline.append(Vector2(hw, 0.62))
	outline.append(Vector2(hw, 1.9))
	for a in 7:
		var t := float(a + 1) / 8.0
		outline.append(Vector2(cos(t * PI) * hw, 1.9 + sin(t * PI) * 0.28))
	outline.append(Vector2(-hw, 1.9))
	k.push(Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3.ZERO))
	# after the turn, kit x runs along world +z and kit z along world -x
	var flipped := PackedVector2Array()
	for p in outline:
		flipped.append(Vector2(-p.x, p.y))
	k.extrude_x(surf, flipped, z0, z1, dark)
	k.pop()
	# the cab front: windscreen, door windows
	k.box("glass", Vector3(0, 1.62, z1 + 0.005), Vector3(1.4, 0.5, 0.02), Color.WHITE)
	for s in [1.0, -1.0]:
		k.box("glass", Vector3(s * (hw + 0.005), 1.6, z1 - 0.4), Vector3(0.02, 0.44, 0.6), Color.WHITE)
		k.box("trim", Vector3(s * (hw + 0.006), 1.1, z1 - 0.72), Vector3(0.004, 0.9, 0.012), Color("0e0e0e"))
		k.box("metal", Vector3(s * (hw + 0.01), 1.3, z1 - 0.62), Vector3(0.02, 0.02, 0.1), NICKEL)
		# a moulding line along the panel side
		k.box("trim", Vector3(s * (hw + 0.004), 1.3, (z0 + z1 - 0.8) * 0.5), Vector3(0.006, 0.03, z1 - z0 - 0.8), Color("111111") if not police else Color("c8c0a8"))
	k.box("trim", Vector3(0, 1.97, z1 + 0.1), Vector3(1.5, 0.03, 0.22), Color("1a1a1a"))   # visor
	# rear doors and windows
	k.box("trim", Vector3(0, 1.2, z0 - 0.005), Vector3(0.006, 1.2, 0.01), Color("0e0e0e"))
	for s in [1.0, -1.0]:
		k.box("glass", Vector3(s * 0.36, 1.55, z0 - 0.008), Vector3(0.44, 0.34, 0.01), Color.WHITE)
		if police:
			for b in 5:
				k.box("metal", Vector3(s * 0.36 - 0.18 + b * 0.09, 1.55, z0 - 0.02), Vector3(0.018, 0.4, 0.018), Color("3a3a3a"))
			# barred side windows at the back
			k.box("glass", Vector3(s * (hw + 0.005), 1.6, -1.2), Vector3(0.02, 0.3, 0.9), Color.WHITE)
			for b in 7:
				k.box("metal", Vector3(s * (hw + 0.02), 1.6, -1.6 + b * 0.13), Vector3(0.018, 0.36, 0.018), Color("3a3a3a"))
	k.box("trim", Vector3(0, 0.66, z0 - 0.12), Vector3(1.3, 0.05, 0.22), Color("2a2622"))   # rear step
	_tail_lamp(k, Vector3(-0.7, 0.9, z0 - 0.03))
	# rear fenders
	for s in [1.0, -1.0]:
		var xa := 0.56 if s > 0 else -0.9
		_fender(k, Vector2(-1.35, 0.37), 0.47, 0.35, 2.8, -0.8, 0.52, xa, xa + 0.34, BLACK)
	if police:
		# roof lamp, gong, and a white waist band
		k.cyl("trim", Vector3(0, 2.18, 0.55), Vector3(0, 2.26, 0.55), 0.09, 0.09, 10, Color("202020"))
		k.lathe("tail", Vector3(0, 2.26, 0.55), [Vector2(0.08, 0.0), Vector2(0.08, 0.1), Vector2(0.0, 0.16)], 10, Color.WHITE)
		k.lathe("metal", Vector3(0.45, 2.18, 0.7), [Vector2(0.0, 0.0), Vector2(0.1, 0.02), Vector2(0.12, 0.08), Vector2(0.0, 0.1)], 10, BRASS)
		for s in [1.0, -1.0]:
			k.box("trim", Vector3(s * (hw + 0.004), 1.06, -0.55), Vector3(0.006, 0.07, 2.9), Color("d8d0b8"))
