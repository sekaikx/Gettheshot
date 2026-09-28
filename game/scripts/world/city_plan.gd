class_name CityPlan
extends RefCounted
## The city layout as plain data, generated from a seed. The host and every client build the
## same plan, so buildings never need to be sent over the network; only who owns what does.
##
## Coordinates: metres, x east, z south, y up. Street centre lines run at x = i * PITCH and
## z = j * PITCH. Block (i, j) sits between street lines i and i + 1, j and j + 1.

const NX := 6
const NZ := 4
const PITCH := 48.0
const STREET := 12.0
const SIDEWALK := 3.5
const LOT_DEPTH := 10.0
const QUAY := 22.0          # quay strip east of the last street
const PIER_LEN := 26.0

const DISTRICTS := ["Hell's Kitchen", "Garment District", "Little Italy", "Lower East Side",
	"Waterfront"]

## Street names, Lower Manhattan style. N-S streets run along x = i * PITCH (west to east, the
## last one is West St. on the waterfront); E-W streets along z = j * PITCH (north to south).
const NS_STREETS := ["Mulberry St.", "Mott St.", "Bowery", "Eldridge St.", "Orchard St.", "Essex St.", "West St."]
const EW_STREETS := ["Houston St.", "Prince St.", "Broome St.", "Grand St.", "Canal St."]

const SHOP_KINDS := ["bakery", "butcher", "grocer", "tailor", "barber", "cobbler", "pawnshop",
	"laundry", "restaurant", "cafe", "candy", "hardware", "drugstore", "cigar"]

var seed_value := 0
var lots: Array = []        # every building footprint (Dictionary)
var blocks: Array = []      # {i, j, rect: [x0, z0, x1, z1], district}
var piers: Array = []       # {x0, x1, z0, z1, tip: [x, z]}
var quay_rect := [0.0, 0.0, 0.0, 0.0]
var water_x := 0.0
var bounds := Rect2()
var nodes: Array = []       # sidewalk corner waypoints [x, z]
var links: Dictionary = {}  # node index -> Array of node indices


static func generate(seed_in: int) -> CityPlan:
	var p := CityPlan.new()
	p.seed_value = seed_in
	p._build()
	return p


static func district_of(i: int, j: int) -> String:
	if i >= NX - 1:
		return "Waterfront"
	if j < NZ / 2:
		return "Hell's Kitchen" if i < 2 else "Garment District"
	return "Little Italy" if i < 2 else "Lower East Side"


func district_at(x: float, z: float) -> String:
	if x > NX * PITCH:
		return "Waterfront"
	var i := clampi(int(floor(x / PITCH)), 0, NX - 1)
	var j := clampi(int(floor(z / PITCH)), 0, NZ - 1)
	return district_of(i, j)


## The street nearest a point (x east, z south): the N-S or E-W line it's closest to. The quay
## and the piers are West St.
func street_name_at(x: float, z: float) -> String:
	if x > NX * PITCH + STREET * 0.5:
		return NS_STREETS[NX]
	var i := clampi(roundi(x / PITCH), 0, NX)
	var j := clampi(roundi(z / PITCH), 0, NZ)
	if absf(x - i * PITCH) <= absf(z - j * PITCH):
		return NS_STREETS[i]
	return EW_STREETS[j]


## "Mulberry St. & Grand St." for the crossing nearest a point.
func corner_at(x: float, z: float) -> String:
	var i := clampi(roundi(x / PITCH), 0, NX)
	var j := clampi(roundi(z / PITCH), 0, NZ)
	return "%s & %s" % [NS_STREETS[i].replace(" St.", ""), EW_STREETS[j]]


## A street address for a door: house numbers climb away from Houston St. and from Mulberry St.,
## odd on one side of the street, even on the other.
func address_at(x: float, z: float) -> String:
	var i := clampi(roundi(x / PITCH), 0, NX)
	var j := clampi(roundi(z / PITCH), 0, NZ)
	var dx := x - i * PITCH
	var dz := z - j * PITCH
	var ns := x > NX * PITCH + STREET * 0.5 or absf(dx) <= absf(dz)
	var along := z if ns else x
	var num := 2 + int(maxf(0.0, along + STREET) / 2.4) * 2
	if (dx if ns else dz) > 0.0:
		num += 1
	return "%d %s" % [num, street_name_at(x, z)]


func _build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var half := STREET * 0.5
	for i in NX:
		for j in NZ:
			var x0 := i * PITCH + half
			var z0 := j * PITCH + half
			var x1 := (i + 1) * PITCH - half
			var z1 := (j + 1) * PITCH - half
			blocks.append({"i": i, "j": j, "rect": [x0, z0, x1, z1], "district": district_of(i, j)})
			var b0 := Vector2(x0 + SIDEWALK, z0 + SIDEWALK)
			var b1 := Vector2(x1 - SIDEWALK, z1 - SIDEWALK)
			# north and south sides run the full width; east and west fit between them
			_side(rng, i, j, "N", b0.x, b1.x, b0.y)
			_side(rng, i, j, "S", b0.x, b1.x, b1.y)
			_side(rng, i, j, "W", b0.y + LOT_DEPTH, b1.y - LOT_DEPTH, b0.x)
			_side(rng, i, j, "E", b0.y + LOT_DEPTH, b1.y - LOT_DEPTH, b1.x)
			# the courtyard between the rows: one low roof
			var c0 := b0 + Vector2(LOT_DEPTH, LOT_DEPTH)
			var c1 := b1 - Vector2(LOT_DEPTH, LOT_DEPTH)
			lots.append({"id": lots.size(), "kind": "courtyard", "block": [i, j], "side": "C",
				"center": [(c0.x + c1.x) * 0.5, (c0.y + c1.y) * 0.5], "size": [c1.x - c0.x, c1.y - c0.y],
				"yaw": 0.0, "floors": 1, "style": 0, "door": [0.0, 0.0], "shop": false,
				"district": district_of(i, j)})
	# waterfront: a quay east of the last street, piers into the river
	var qx0 := NX * PITCH + half
	quay_rect = [qx0, -half, qx0 + QUAY, NZ * PITCH + half]
	water_x = qx0 + QUAY
	for k in 3:
		var zc := PITCH * (0.7 + k * 1.3)
		piers.append({"x0": water_x, "x1": water_x + PIER_LEN, "z0": zc - 3.0, "z1": zc + 3.0,
			"tip": [water_x + PIER_LEN - 3.0, zc]})
	# two warehouses on the quay, facing the street
	for k in 2:
		var zc := PITCH * (1.0 + k * 2.0)
		var w := 18.0
		lots.append({"id": lots.size(), "kind": "warehouse", "block": [NX, k], "side": "Q",
			"center": [qx0 + 4.0 + 7.0, zc], "size": [w, 14.0], "yaw": -PI * 0.5, "floors": 2,
			"style": 3, "door": [qx0 + 2.2, zc], "shop": true, "district": "Waterfront"})
	bounds = Rect2(-half - 30.0, -half - 30.0, water_x + PIER_LEN + 60.0 + half, NZ * PITCH + STREET + 60.0)
	_assign_specials(rng)
	_build_graph()


## One row of lots along a block side. For N/S sides a..b run along x at depth line `at` (z);
## for E/W sides a..b run along z at `at` (x).
func _side(rng: RandomNumberGenerator, i: int, j: int, side: String, a: float, b: float, at: float) -> void:
	var pos := a
	while b - pos > 5.5:
		var w := rng.randf_range(7.0, 11.0)
		if b - pos - w < 6.0:
			w = b - pos
		var mid := pos + w * 0.5
		var c := Vector2.ZERO
		var door := Vector2.ZERO
		var yaw := 0.0
		match side:
			"N":
				c = Vector2(mid, at + LOT_DEPTH * 0.5)
				door = Vector2(mid, at - 1.2)
				yaw = PI          # front faces -z (north)
			"S":
				c = Vector2(mid, at - LOT_DEPTH * 0.5)
				door = Vector2(mid, at + 1.2)
				yaw = 0.0         # front faces +z
			"W":
				c = Vector2(at + LOT_DEPTH * 0.5, mid)
				door = Vector2(at - 1.2, mid)
				yaw = -PI * 0.5   # front faces -x
			"E":
				c = Vector2(at - LOT_DEPTH * 0.5, mid)
				door = Vector2(at + 1.2, mid)
				yaw = PI * 0.5    # front faces +x
		lots.append({"id": lots.size(), "kind": "tenement", "block": [i, j], "side": side,
			"center": [c.x, c.y], "size": [w, LOT_DEPTH], "yaw": yaw,
			"floors": rng.randi_range(2, 6), "style": rng.randi_range(0, 3),
			"door": [door.x, door.y], "shop": rng.randf() < 0.42, "district": district_of(i, j)})
		pos += w


func _assign_specials(rng: RandomNumberGenerator) -> void:
	# every district gets a pool hall (where muscle hangs around) and a social club (a family
	# headquarters); one police precinct for the city; the rest of the shops get a trade
	var by_district := {}
	for lot in lots:
		if lot["kind"] == "tenement" and lot["shop"]:
			by_district.get_or_add(lot["district"], []).append(lot)
	var precinct_done := false
	for d in DISTRICTS:
		var list: Array = by_district.get(d, [])
		_shuffle(rng, list)
		var idx := 0
		for special in ["club", "club", "poolhall"]:
			if idx < list.size():
				list[idx]["kind"] = special
				idx += 1
		if not precinct_done and d == "Lower East Side" and idx < list.size():
			list[idx]["kind"] = "precinct"
			list[idx]["floors"] = 3
			precinct_done = true
			idx += 1
		for k in range(idx, list.size()):
			list[k]["kind"] = "fish" if d == "Waterfront" and rng.randf() < 0.3 else Names.pick(rng, SHOP_KINDS)
	# non-shop tenements stay homes


func _shuffle(rng: RandomNumberGenerator, arr: Array) -> void:
	for k in range(arr.size() - 1, 0, -1):
		var r := rng.randi_range(0, k)
		var t = arr[k]
		arr[k] = arr[r]
		arr[r] = t


## Sidewalk waypoints: the four outer corners of every block's sidewalk, linked along the block
## and across the street to the facing corner of the next block.
func _build_graph() -> void:
	var idx := {}
	var inset := 1.4
	for b in blocks:
		var r: Array = b["rect"]
		var corners := [Vector2(r[0] + inset, r[1] + inset), Vector2(r[2] - inset, r[1] + inset),
			Vector2(r[2] - inset, r[3] - inset), Vector2(r[0] + inset, r[3] - inset)]
		for c in 4:
			idx[Vector3i(b["i"], b["j"], c)] = nodes.size()
			nodes.append([corners[c].x, corners[c].y])
	for b in blocks:
		var i: int = b["i"]
		var j: int = b["j"]
		for c in 4:
			_link(idx[Vector3i(i, j, c)], idx[Vector3i(i, j, (c + 1) % 4)])
		# crossings: NE corner (1) to the next block's NW (0), SE (2) to its SW (3), SW (3) to the
		# block below's NW (0), SE (2) to its NE (1)
		if i + 1 < NX:
			_link(idx[Vector3i(i, j, 1)], idx[Vector3i(i + 1, j, 0)])
			_link(idx[Vector3i(i, j, 2)], idx[Vector3i(i + 1, j, 3)])
		if j + 1 < NZ:
			_link(idx[Vector3i(i, j, 3)], idx[Vector3i(i, j + 1, 0)])
			_link(idx[Vector3i(i, j, 2)], idx[Vector3i(i, j + 1, 1)])


func _link(a: int, b: int) -> void:
	links.get_or_add(a, []).append(b)
	links.get_or_add(b, []).append(a)


func node_pos(k: int) -> Vector3:
	return Vector3(nodes[k][0], 0.0, nodes[k][1])


func nearest_node(p: Vector3) -> int:
	var best := 0
	var bd := INF
	for k in nodes.size():
		var d := Vector2(nodes[k][0] - p.x, nodes[k][1] - p.z).length_squared()
		if d < bd:
			bd = d
			best = k
	return best


## Breadth-first path over the sidewalk graph, as world positions (y = 0).
func path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var a := nearest_node(from)
	var b := nearest_node(to)
	var prev := {a: -1}
	var queue := [a]
	while not queue.is_empty():
		var n: int = queue.pop_front()
		if n == b:
			break
		for m in links.get(n, []):
			if not prev.has(m):
				prev[m] = n
				queue.append(m)
	var out := PackedVector3Array()
	var cur := b
	while cur != -1 and prev.has(cur):
		out.insert(0, node_pos(cur))
		cur = prev[cur]
	out.append(to)
	return out


func lots_of_kind(kind: String) -> Array:
	return lots.filter(func(l: Dictionary) -> bool: return l["kind"] == kind)
