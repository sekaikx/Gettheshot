extends Node2D
## Interiors close-ups: a dozen business interiors side by side without roofs, the same smashed,
## speakeasies in the back, padlocked, night, and a debug shot with the collision in red. Also
## checks every business in the city is walkable (door -> in front of the counter -> back door).
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --rendering-driver opengl3 --resolution 1600x900 --path game res://tools/test/test_interiors.tscn
## Env: OUT=prefix (default /tmp/interiors), ONLY=name (one shot), ZOOM=1.2

const KINDS := ["bakery", "butcher", "barber", "tailor", "restaurant", "candy", "pawnshop", "cigar",
	"club", "precinct", "poolhall", "grocer", "fish", "drugstore", "cafe", "laundry", "hardware", "cobbler"]

var art: InteriorArt
var cam: Camera2D
var dbg: Node2D
var lots := {}           # kind -> [normal lot, broken lot, speak lot, closed lot]
var rows_z := [0.0, 20.0, 40.0, 60.0]
var col_x := {}          # kind -> x centre
var show_debug := false


func _ready() -> void:
	Game.new_campaign({"seed": 1923, "families": 4}, [{"peer": 1, "name": "Alex", "family_name": "Vitale", "color": "#c42828"}])
	Game.running = false
	var plan: CityPlan = Game.plan
	_walk_check(plan)
	var bg := Node2D.new()
	bg.z_index = -100
	bg.draw.connect(func() -> void:
		bg.draw_rect(Rect2(-40 * W.M, -40 * W.M, 400 * W.M, 200 * W.M), Pal.SIDEWALK))
	add_child(bg)
	art = InteriorArt.new()
	add_child(art)
	art.plan = plan
	art.z_index = W.Z_FLOOR
	var x := 0.0
	var id := 5000
	var kinds: Array = KINDS.duplicate()
	kinds.append("warehouse")
	for kind in kinds:
		var src := {}
		for l in plan.lots:
			if String(l["kind"]) == kind or (kind != "warehouse" and _biz_kind(l) == kind):
				src = l
				break
		if src.is_empty():
			continue
		var w := float(src["size"][0])
		var d := float(src["size"][1])
		var cx := x + w * 0.5
		col_x[kind] = cx
		x += w + 1.5
		var group := []
		for r in 4:
			var lot: Dictionary = src.duplicate(true)
			lot["id"] = id
			lot["yaw"] = 0.0
			lot["center"] = [cx, float(rows_z[r]) - d * 0.5]
			lot["door"] = [cx, float(rows_z[r]) + 1.2]
			id += 1
			var st := {}
			var lay0 := Interiors.layout(lot, kind)
			match r:
				1: st = {"broken": _breakables(lay0)}
				2: st = {"speak": true, "stock": 12}
				3: st = {"closed": true}
			art.add_lot(lot, kind, st)
			group.append(lot)
		lots[kind] = group
	dbg = Node2D.new()
	dbg.z_index = 90
	dbg.draw.connect(_draw_debug)
	add_child(dbg)
	cam = Camera2D.new()
	cam.zoom = Vector2.ONE * float(OS.get_environment("ZOOM") if OS.get_environment("ZOOM") != "" else "1.2")
	add_child(cam)
	cam.make_current()
	_shots()


func _biz_kind(l: Dictionary) -> String:
	for b in Game.biz:
		if int(b["lot"]) == int(l["id"]):
			return String(b["kind"])
	return ""


func _breakables(lay: Dictionary) -> Array:
	var out := []
	for it in lay["items"]:
		if bool(it["breakable"]):
			out.append(int(it["id"]))
	return out


func _shots() -> void:
	var out := OS.get_environment("OUT")
	if out == "":
		out = "/tmp/interiors"
	var only := OS.get_environment("ONLY")
	# [name, kinds (neighbours), row (0 plain, 1 smashed, 2 speakeasy, 3 padlocked), zoom]
	var shots := [
		["a", ["bakery", "butcher", "barber"], 0, 1.0],
		["b", ["tailor", "restaurant", "candy"], 0, 1.0],
		["c", ["pawnshop", "cigar", "club"], 0, 1.0],
		["d", ["precinct", "poolhall", "grocer"], 0, 1.0],
		["e", ["fish", "drugstore", "cafe"], 0, 1.0],
		["f", ["laundry", "hardware", "cobbler"], 0, 1.0],
		["w", ["warehouse"], 0, 1.0],
		["zclub", ["club"], 0, 1.6],
		["zbakery", ["bakery"], 0, 1.6],
		["zpool", ["poolhall"], 0, 1.6],
		["broken1", ["bakery", "butcher", "barber"], 1, 1.0],
		["broken2", ["candy", "pawnshop", "cigar"], 1, 1.0],
		["zbroken", ["pawnshop"], 1, 1.6],
		["speak1", ["restaurant", "candy", "pawnshop"], 2, 1.0],
		["speak2", ["cigar", "club"], 2, 1.2],
		["zspeak", ["bakery"], 2, 1.6],
		["speakw", ["warehouse"], 2, 1.0],
		["closed", ["tailor", "restaurant", "candy"], 3, 1.0],
		["night", ["cigar", "club"], 2, 1.2],
		["debug1", ["bakery", "butcher", "barber"], 0, 1.0],
		["debug2", ["club", "precinct", "poolhall"], 0, 1.0],
		["debugw", ["warehouse"], 2, 1.0],
	]
	for s in shots:
		var name: String = s[0]
		if only != "" and name != only:
			continue
		var ks: Array = s[1]
		var row: int = s[2]
		cam.zoom = Vector2.ONE * float(s[3])
		var have := []
		for kk in ks:
			if col_x.has(kk):
				have.append(kk)
		if have.is_empty():
			continue
		var x0: float = col_x[have[0]]
		var x1: float = col_x[have[have.size() - 1]]
		var dep := float((lots[have[0]][row] as Dictionary)["size"][1])
		cam.position = W.p((x0 + x1) * 0.5, float(rows_z[row]) - dep * 0.5 + 0.6)
		show_debug = name.begins_with("debug")
		dbg.queue_redraw()
		var n := 1.0 if name == "night" else 0.0
		art.set_night(n, 0.0)
		if name == "night":
			modulate = Color(0.55, 0.55, 0.75)
		else:
			modulate = Color.WHITE
		for f in 8:
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s_%s.png" % [out, name])
		print("shot ", name)
	get_tree().quit()


func _draw_debug() -> void:
	if not show_debug:
		return
	var red := Color(1, 0.1, 0.1, 0.9)
	var wt := W.WALL * W.M
	for id in art.layouts:
		var lay: Dictionary = art.layouts[id]
		for seg in lay["walls"]:
			var a: Vector2 = seg[0]
			var b: Vector2 = seg[1]
			var r := Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (a - b).abs()).grow(wt * 0.5)
			dbg.draw_rect(r, Color(1, 0, 0, 0.25))
			dbg.draw_rect(r, red, false, 1.5)
		for it in lay["items"]:
			if bool(it["solid"]):
				dbg.draw_rect(it["rect"], red, false, 2.0)
			elif bool(it["breakable"]):
				dbg.draw_rect(it["rect"], Color(1, 0.8, 0.1), false, 1.5)
		var f: Vector2 = lay["front"]
		dbg.draw_circle(lay["owner_spot"], 6, Color(0.2, 1, 0.3))
		dbg.draw_circle((lay["owner_spot"] as Vector2) + f * 1.6 * W.M, 6, Color(0.2, 0.6, 1))
		for d in lay["doors"]:
			dbg.draw_circle(d["pos"], 5, Color(1, 1, 0))
		for key in lay["spots"]:
			var v = lay["spots"][key]
			if v is Vector2:
				dbg.draw_circle(v, 3.5, Color(1, 0, 1))
			elif v is Array:
				for q in v:
					if q is Vector2:
						dbg.draw_circle(q, 3.0, Color(1, 0.5, 1))


# ------------------------------------------------------------------ walkability

## The same grid the World's people path on: walls and solids grown by a 0.3 m body.
func _walk_check(plan: CityPlan) -> void:
	var bad := 0
	var total := 0
	for b in Game.biz:
		var lot: Dictionary = plan.lots[int(b["lot"])]
		for sp in [false, true]:
			var lay := Interiors.build(lot, String(b["kind"]), sp)
			total += 1
			var msg := _walkable(lot, lay)
			if msg != "":
				bad += 1
				print("WALK FAIL %s lot %d speak=%s: %s" % [b["kind"], lot["id"], sp, msg])
			var lay2 := Interiors.layout(lot, String(b["kind"]))
			if sp:
				# a speakeasy must keep the same solid footprint and ids
				var a: Array = lay["items"]
				var c: Array = lay2["items"]
				if a.size() != c.size():
					print("SPEAK MISMATCH %s lot %d: %d vs %d items" % [b["kind"], lot["id"], a.size(), c.size()])
					bad += 1
				else:
					for i in a.size():
						if bool(a[i]["solid"]) != bool(c[i]["solid"]) or (bool(a[i]["solid"]) and a[i]["rect"] != c[i]["rect"]):
							print("SPEAK MISMATCH %s lot %d item %d" % [b["kind"], lot["id"], i])
							bad += 1
							break
	print("WALK CHECK %d/%d ok" % [total - bad, total])


func _walkable(lot: Dictionary, lay: Dictionary) -> String:
	var r := W.lot_rect(lot)
	var f := W.front_dir(float(lot["yaw"]))
	r = r.merge(Rect2(r.position + f * 2.2 * W.M, r.size))
	var cell := 0.1 * W.M
	var g := AStarGrid2D.new()
	g.region = Rect2i(0, 0, ceili(r.size.x / cell), ceili(r.size.y / cell))
	g.cell_size = Vector2(cell, cell)
	g.offset = r.position + Vector2(cell, cell) * 0.5
	g.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	g.update()
	var grow := 0.3 * W.M
	var wt := W.WALL * W.M
	var solids := []
	for seg in lay["walls"]:
		var a: Vector2 = seg[0]
		var b: Vector2 = seg[1]
		solids.append(Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (a - b).abs()).grow(wt * 0.5 + grow))
	for it in lay["items"]:
		if bool(it["solid"]):
			solids.append((it["rect"] as Rect2).grow(grow))
	for s in solids:
		var x0 := maxi(0, int(floor((s.position.x - g.offset.x) / cell)) + 1)
		var y0 := maxi(0, int(floor((s.position.y - g.offset.y) / cell)) + 1)
		var x1 := mini(g.region.size.x - 1, int(ceil((s.end.x - g.offset.x) / cell)) - 1)
		var y1 := mini(g.region.size.y - 1, int(ceil((s.end.y - g.offset.y) / cell)) - 1)
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				g.set_point_solid(Vector2i(x, y), true)
	var door := W.pa(lot["door"])
	var talk: Vector2 = (lay["owner_spot"] as Vector2) + (lay["front"] as Vector2) * 1.6 * W.M
	var targets := {"talk": talk}
	for d in lay["doors"]:
		if String(d["kind"]) in ["back", "office"]:
			targets["door_" + String(d["kind"])] = (d["pos"] as Vector2) + (d["dir"] as Vector2) * 0.5 * W.M
	# the owner must be able to reach his own spot from the back room door too (he's behind the counter)
	var from := _cell(g, door)
	if g.is_point_solid(from):
		return "the door is blocked"
	for key in targets:
		var c := _cell(g, targets[key])
		if g.is_point_solid(c):
			return "%s spot is inside a solid" % key
		if g.get_id_path(from, c).is_empty():
			return "no path from the door to %s" % key
	# the owner's spot is clear
	var o := _cell(g, lay["owner_spot"])
	if g.is_point_solid(o):
		return "owner spot is inside a solid"
	return ""


func _cell(g: AStarGrid2D, p: Vector2) -> Vector2i:
	return Vector2i(((p - g.offset) / g.cell_size).round()).clamp(Vector2i.ZERO, g.region.size - Vector2i.ONE)
