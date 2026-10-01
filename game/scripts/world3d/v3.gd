class_name V3
extends RefCounted
## Shared constants and helpers for the 3D view (docs/REBUILD_3D.md). The simulation stays in the 2D
## World (world pixels, W.M per metre, x east, y south); the 3D view mirrors it. One metre in 3D is
## one plan metre: x east, z south, y up. So a 2D point (px, py) is the 3D point (px/M, 0, py/M).

const M := W.M
const CAM_PITCH := deg_to_rad(58.0)    # the camera looks down at this angle (90 = straight down)
const CAM_FOV := 40.0
const CAM_DIST := 22.0                 # metres from the focus at 2D zoom 1.0
const FLOOR_H := 3.0                   # metres per floor
const SUN_DIR := Vector3(0.62, -1.0, 0.62)   # light travels toward the south-east (shadows fall down-right)

# physics / render layers
const LAYER_WORLD := 1                 # everything you look at
const LAYER_ROOFS := 2                 # roofs and upper floors that hide when you go inside


## A 2D world point (pixels) -> the 3D point at height y.
static func pos(px: Vector2, y: float = 0.0) -> Vector3:
	return Vector3(px.x / M, y, px.y / M)


## A 3D point -> the 2D world point (pixels).
static func flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z) * M


## A plan point [x, z] (metres) -> 3D.
static func plan_pos(v: Array, y: float = 0.0) -> Vector3:
	return Vector3(float(v[0]), y, float(v[1]))


## A 2D rotation (0 = east, clockwise on screen) -> the Node3D rotation.y of a model that faces +Z.
static func yaw_y(yaw2d: float) -> float:
	return PI * 0.5 - yaw2d


## The reverse: Node3D rotation.y of a +Z-facing model -> 2D rotation.
static func yaw_2d(rot_y: float) -> float:
	return PI * 0.5 - rot_y


## A 2D rect in pixels -> a rect in metres (position = x, z).
static func rect_m(r: Rect2) -> Rect2:
	return Rect2(r.position / M, r.size / M)


## Building height of a lot in metres (ground floor a bit taller than the rest).
static func lot_height(lot: Dictionary) -> float:
	var fl := int(lot.get("floors", 1))
	return 3.4 + maxf(0.0, fl - 1.0) * FLOOR_H


## A plain lit material.
static func mat(c: Color, rough: float = 0.85, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


## An emissive material (lamps, lit windows).
static func glow(c: Color, energy: float = 1.5) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m


## Deterministic 0..1 hash (the same city on every machine); same as Draw.hash01.
static func hash01(x: float, y: float, s: float = 0.0) -> float:
	return Draw.hash01(int(x * 7.0), int(y * 13.0), int(s))
