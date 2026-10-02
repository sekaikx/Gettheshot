class_name G3Bundle
extends RefCounted
## Spatial batching for the ground: the world is cut into 48 m cells; each cell owns one G3Mesh per
## material kind, so a whole district is a handful of MeshInstance3Ds that Godot can cull per cell.

const CELL := 48.0
const KEYS := ["road", "cobble", "setts", "walk", "planks", "planks_z", "dirt", "stone", "props", "metal",
	"leaf", "wood", "paint", "puddle", "glow", "pools"]
const SHADOWLESS := ["paint", "puddle", "glow", "pools", "road", "cobble", "setts", "walk", "planks", "planks_z", "dirt"]

var cells := {}
var mats: G3Mats


class Cell:
	extends RefCounted
	var g := {}
	var props: G3Mesh
	var metal: G3Mesh
	var stone: G3Mesh
	var wood: G3Mesh
	var leaf: G3Mesh
	var paint: G3Mesh
	var glow: G3Mesh
	var pools: G3Mesh
	var puddle: G3Mesh
	var dirt: G3Mesh
	var road: G3Mesh
	var cobble: G3Mesh
	var setts: G3Mesh
	var walk: G3Mesh
	var planks: G3Mesh
	var planks_z: G3Mesh

	func _init() -> void:
		for k in G3Bundle.KEYS:
			var m := G3Mesh.new()
			if G3Mats.TILE.has(k):
				m.uvk = 1.0 / float(G3Mats.TILE[k])
			if k == "planks_z":
				m.swap_uv = true
			g[k] = m
			set(k, m)

	func push_at(pos: Vector3, yaw: float = 0.0, scale: float = 1.0) -> void:
		for k in G3Bundle.KEYS:
			(g[k] as G3Mesh).push_at(pos, yaw, scale)

	func pop() -> void:
		for k in G3Bundle.KEYS:
			(g[k] as G3Mesh).pop()


func _init(m: G3Mats) -> void:
	mats = m


func at(p: Vector2) -> Cell:
	var key := Vector2i(int(floor(p.x / CELL)), int(floor(p.y / CELL)))
	if not cells.has(key):
		cells[key] = Cell.new()
	return cells[key]


## Build the MeshInstance3Ds under `parent`.
func flush(parent: Node3D) -> void:
	var keys := cells.keys()
	keys.sort()
	for ck in keys:
		var cell: Cell = cells[ck]
		var holder := Node3D.new()
		holder.name = "Cell_%d_%d" % [ck.x, ck.y]
		parent.add_child(holder)
		for k in G3Bundle.KEYS:
			var m: G3Mesh = cell.g[k]
			var mi := m.instance(k, mats.material(k), not (k in G3Bundle.SHADOWLESS))
			if mi != null:
				if k == "pools" or k == "puddle" or k == "paint" or k == "glow":
					mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				holder.add_child(mi)
