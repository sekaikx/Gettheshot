class_name World
extends Node2D
## The street, top-down 2D. Builds the city from the plan (ground, shop interiors, shopfronts,
## roofs on their own layer, night light, weather), spawns everyone, runs the host simulation
## (brains, crimes and witnesses, cops, shakedowns, the smuggler's boat, traffic) and keeps every
## client in step:
##   host -> clients: Game state (reliable, when it changes) and snapshots (unreliable, 10 Hz)
##   client -> host: its own boss/vehicle pose (15 Hz) and requests (Net.to_host)
## Positions are world pixels (W.M per metre); Game and the plan stay in metres.

signal happened(what: String, data: Dictionary)   # for the tutorial: entered, talked, protected, hired...

const PEDS := 36
const TRAFFIC := 8
const DOCKERS := 5
const SNAP_HZ := 10.0
const POSE_HZ := 15.0
const REACH := 1.1 * W.M          # how close you must be to use something

var plan: CityPlan
var ground: CityGround
var interiors: InteriorArt
var fronts: Shopfronts
var roofs: CityRoofs
var roofs_layer: CanvasLayer
var lighting: Lighting
var weather_fx: Weather
var cam: CameraRig
var hud: Node
var controller: PlayerController
var audio: Node
var actors := {}
var vehicles := {}
var items := {}
var local_actor: Actor
var local_vehicle: Vehicle
var weather := "clear"
var boat: Node2D
var arrests := {}        # peer -> cop key (pending)
var inside_lot := -1     # the lot the local player is in
var _walls: StaticBody2D
var _lot_index := {}     # Vector2i block -> [lot ids]
var _quay_lots: Array = []
var _biz_of_lot := {}    # lot id -> biz id
var _grids := {}         # lot id -> AStarGrid2D
var _next_item := 1
var _snap_t := 0.0
var _pose_t := 0.0
var _state_t := 0.0
var _sync_t := 0.0
var _last_seen := {}
var _corpses := {}
var _contra_t := 0.0
var _spotted := {}
var _stacks := {}
var _shake_t := 0.0
var _night := -1.0
var _decor := {}
var _banner_lot := -2
var _ring_t := 3.0
var _job_t := 0.5
var _obj_t := 0.0
var _my_obj := false
var _adv_t := 0.0
var _marks: Node2D
var floats: FloatText
var _rings_done := {}     # family id -> {ring id: true}


func _ready() -> void:
	set_process(false)
	if Game.plan == null:
		await Game.state_changed
	# a title card while the city is built (the first frames freeze otherwise)
	var card := _loading_card()
	await get_tree().process_frame
	await get_tree().process_frame
	set_process(true)
	var t0 := Time.get_ticks_msec()
	plan = Game.plan
	for b in Game.biz:
		_biz_of_lot[int(b["lot"])] = int(b["id"])
	_index_lots()
	ground = CityGround.new()
	ground.name = "Ground"
	add_child(ground)
	ground.build(plan)
	interiors = InteriorArt.new()
	interiors.name = "Interiors"
	add_child(interiors)
	interiors.build(plan)
	fronts = Shopfronts.new()
	fronts.name = "Shopfronts"
	add_child(fronts)
	fronts.build(plan)
	roofs_layer = CanvasLayer.new()
	roofs_layer.layer = W.LAYER_ROOFS
	roofs_layer.follow_viewport_enabled = true
	add_child(roofs_layer)
	roofs = CityRoofs.new()
	roofs.name = "Roofs"
	roofs_layer.add_child(roofs)
	roofs.build(plan)
	floats = FloatText.new()
	floats.z_index = 60
	roofs_layer.add_child(floats)
	_marks = Node2D.new()
	_marks.name = "Marks"
	_marks.z_index = 50
	_marks.draw.connect(_draw_marks)
	roofs_layer.add_child(_marks)
	_build_walls()
	if "--timing" in OS.get_cmdline_user_args():
		print("TIMING pieces+walls %d ms" % (Time.get_ticks_msec() - t0))
	_boat()
	_shape_up_board()
	cam = CameraRig.new()
	add_child(cam)
	lighting = Lighting.new()
	add_child(lighting)
	lighting.setup(self)
	lighting.add_static(ground.lights())
	lighting.add_static(fronts.lights())
	lighting.add_static(interiors.lights())
	weather_fx = Weather.new()
	add_child(weather_fx)
	weather_fx.setup(self)
	audio = preload("res://scripts/world/ambience.gd").new()
	add_child(audio)
	hud = preload("res://scripts/ui/hud.gd").new()
	hud.world = self
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(hud)
	# playing alone, the city waits while you read a menu, a map or the book
	var pauser := Node.new()
	pauser.name = "Pauser"
	pauser.process_mode = Node.PROCESS_MODE_ALWAYS
	pauser.set_script(preload("res://scripts/world/pauser.gd"))
	pauser.set("world", self)
	add_child(pauser)
	controller = PlayerController.new()
	controller.world = self
	add_child(controller)
	Net.request.connect(_on_request)
	Net.event.connect(_on_event)
	Net.snapshot.connect(_on_snapshot)
	Net.pose.connect(_on_pose)
	Game.state_changed.connect(_on_state_changed)
	Game.notice.connect(_on_game_notice)
	Game.crew_spawn_request.connect(func(_id: int) -> void: _sync_spawns())
	Game.ai_order.connect(_on_ai_order)
	Game.month_passed.connect(_on_month)
	Game.campaign_over.connect(func() -> void: Net.to_all("over", []))
	Game.raided.connect(_on_raid)
	if Net.is_host():
		_host_spawn()
	_ensure_local_boss()
	if "--timing" in OS.get_cmdline_user_args():
		print("TIMING world ready %d ms" % (Time.get_ticks_msec() - t0))
	var fade := create_tween()
	fade.tween_interval(0.25)
	fade.tween_property(card.get_child(0), "modulate:a", 0.0, 0.6)
	fade.tween_callback(card.queue_free)
	_on_state_changed()
	var args := OS.get_cmdline_user_args()
	if (bool(Game.cfg.get("tutorial", false)) and not "--autotest" in args) or "--tuttest" in args:
		var tut = load("res://scripts/ui/tutorial.gd")
		if tut:
			var t: Node = tut.new()
			t.name = "Tutorial"
			t.set("world", self)
			add_child(t)
	if "--mptest" in OS.get_cmdline_user_args():
		_mptest()
	if "--autotest" in OS.get_cmdline_user_args():
		var t = load("res://scripts/world/autotest.gd").new()
		t.world = self
		t.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(t)


func _loading_card() -> CanvasLayer:
	var cl := CanvasLayer.new()
	cl.layer = 100
	add_child(cl)
	var root := ColorRect.new()
	root.color = Color("0c0a08")
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(root)
	var title := Label.new()
	title.text = "New York, %s" % Game.date_text()
	title.add_theme_font_override("font", W.ui_font("deco"))
	title.add_theme_font_size_override("font_size", 54)
	title.add_theme_color_override("font_color", Pal.GOLD)
	title.set_anchors_preset(Control.PRESET_CENTER)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(-500, -60)
	title.size = Vector2(1000, 70)
	root.add_child(title)
	var sub := Label.new()
	sub.text = "The city wakes up. The %s family has work to do." % String(Game.fam(int(Game.player(Net.my_id()).get("family", 0))).get("name", ""))
	sub.add_theme_font_override("font", W.ui_font("fell"))
	sub.add_theme_font_size_override("font_size", 24)
	sub.add_theme_color_override("font_color", Pal.INK)
	sub.set_anchors_preset(Control.PRESET_CENTER)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position = Vector2(-500, 20)
	sub.size = Vector2(1000, 40)
	root.add_child(sub)
	return cl


# ------------------------------------------------------------------ the city: lookup, walls, paths

func _index_lots() -> void:
	for lot in plan.lots:
		if lot["kind"] == "courtyard":
			continue
		var bl: Array = lot["block"]
		if int(bl[0]) >= CityPlan.NX:
			_quay_lots.append(int(lot["id"]))
		else:
			_lot_index.get_or_add(Vector2i(int(bl[0]), int(bl[1])), []).append(int(lot["id"]))


## The lot (building) a point is inside, or -1.
func lot_at(p: Vector2) -> int:
	var i := int(floor(p.x / (CityPlan.PITCH * W.M)))
	var j := int(floor(p.y / (CityPlan.PITCH * W.M)))
	var cands: Array = _lot_index.get(Vector2i(i, j), [])
	for id in cands:
		if W.lot_rect(plan.lots[id]).has_point(p):
			return id
	if i >= CityPlan.NX - 1:
		for id in _quay_lots:
			if W.lot_rect(plan.lots[id]).has_point(p):
				return id
	return -1


## The business in a lot, or {}.
func biz_at_lot(lot_id: int) -> Dictionary:
	return Game.biz_by_id(int(_biz_of_lot.get(lot_id, -1)))


func layout_of_biz(biz_id: int) -> Dictionary:
	var b := Game.biz_by_id(biz_id)
	if b.is_empty():
		return {}
	return interiors.layout_of(int(b["lot"]))


func _build_walls() -> void:
	_walls = StaticBody2D.new()
	_walls.name = "Walls"
	_walls.collision_layer = 1
	_walls.collision_mask = 0
	add_child(_walls)
	var wt := W.WALL * W.M
	for lot in plan.lots:
		if lot["kind"] == "courtyard":
			continue
		var lay := interiors.layout_of(int(lot["id"]))
		if lay.is_empty():
			_add_rect(W.lot_rect(lot))
			continue
		for seg in lay["walls"]:
			var a: Vector2 = seg[0]
			var b: Vector2 = seg[1]
			var cs := CollisionShape2D.new()
			var rs := RectangleShape2D.new()
			rs.size = Vector2(a.distance_to(b) + wt, wt)
			cs.shape = rs
			cs.position = (a + b) * 0.5
			cs.rotation = (b - a).angle()
			_walls.add_child(cs)
		for it in lay["items"]:
			if bool(it.get("solid", false)):
				_add_rect(it["rect"])
	for r in ground.solids():
		_add_rect(r)
	for r in fronts.solids():
		_add_rect(r)
	# the river, except the piers
	var b := plan.bounds
	var wx := plan.water_x * W.M
	var zs := []
	for pier in plan.piers:
		zs.append([float(pier["z0"]) * W.M, float(pier["z1"]) * W.M, float(pier["x1"]) * W.M])
	zs.sort_custom(func(a, c) -> bool: return a[0] < c[0])
	var z := b.position.y * W.M
	var x_end := b.end.x * W.M
	for zz in zs:
		_add_rect(Rect2(Vector2(wx, z), Vector2(x_end - wx, float(zz[0]) - z)))
		_add_rect(Rect2(Vector2(float(zz[2]), float(zz[0])), Vector2(x_end - float(zz[2]), float(zz[1]) - float(zz[0]))))
		z = float(zz[1])
	_add_rect(Rect2(Vector2(wx, z), Vector2(x_end - wx, b.end.y * W.M - z)))
	# the edge of the map
	var br := Rect2(b.position * W.M, b.size * W.M)
	var t := 4.0 * W.M
	_add_rect(Rect2(br.position - Vector2(t, t), Vector2(br.size.x + 2 * t, t)))
	_add_rect(Rect2(Vector2(br.position.x - t, br.end.y), Vector2(br.size.x + 2 * t, t)))
	_add_rect(Rect2(br.position - Vector2(t, 0), Vector2(t, br.size.y)))
	_add_rect(Rect2(Vector2(br.end.x, br.position.y), Vector2(t, br.size.y)))


func _add_rect(r: Rect2) -> void:
	if r.size.x <= 0.5 or r.size.y <= 0.5:
		return
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = r.size
	cs.shape = rs
	cs.position = r.get_center()
	_walls.add_child(cs)


## A walking route between two points (px): through doors, along the sidewalks, across streets.
func route(from: Vector2, to: Vector2) -> PackedVector2Array:
	var fl := lot_at(from)
	var tl := lot_at(to)
	var out := PackedVector2Array()
	if fl >= 0 and fl == tl:
		return _grid_path(fl, from, to)
	var start := from
	if fl >= 0:
		var door_out := _door_out(fl)
		out.append_array(_grid_path(fl, from, door_out))
		start = door_out
	var end := to
	if tl >= 0:
		end = _door_out(tl)
	out.append_array(_street_path(start, end, tl))
	if tl >= 0:
		out.append_array(_grid_path(tl, end, to))
	return out


func _door_out(lot_id: int) -> Vector2:
	return W.pa(plan.lots[lot_id]["door"])


func _street_path(from: Vector2, to: Vector2, to_lot: int = -1) -> PackedVector2Array:
	var a := _nearest_node(from)
	var b := _nearest_node(to)
	var out := PackedVector2Array()
	if from.distance_to(to) < W.pa(plan.nodes[a]).distance_to(from) + W.pa(plan.nodes[b]).distance_to(to):
		out.append(to)
		return out
	var prev := {a: -1}
	var queue := [a]
	while not queue.is_empty():
		var n: int = queue.pop_front()
		if n == b:
			break
		for m in plan.links.get(n, []):
			if not prev.has(m):
				prev[m] = n
				queue.append(m)
	var cur := b
	var nodes := []
	while cur != -1 and prev.has(cur):
		nodes.push_front(cur)
		cur = prev[cur]
	for n in nodes:
		out.append(W.pa(plan.nodes[n]))
	if to_lot >= 0:
		var f := W.front_dir(float(plan.lots[to_lot]["yaw"]))
		out.append(to + f * 0.9 * W.M)
	out.append(to)
	return out


func _nearest_node(p: Vector2) -> int:
	var best := 0
	var bd := INF
	var pm := p / W.M
	for k in plan.nodes.size():
		var d := Vector2(float(plan.nodes[k][0]) - pm.x, float(plan.nodes[k][1]) - pm.y).length_squared()
		if d < bd:
			bd = d
			best = k
	return best


func _grid(lot_id: int) -> AStarGrid2D:
	if _grids.has(lot_id):
		return _grids[lot_id]
	var lay := interiors.layout_of(lot_id)
	var r := W.lot_rect(plan.lots[lot_id])
	var f := W.front_dir(float(plan.lots[lot_id]["yaw"]))
	r = r.merge(Rect2(r.position + f * 2.2 * W.M, r.size))
	var cell := 0.22 * W.M
	var g := AStarGrid2D.new()
	g.region = Rect2i(0, 0, ceili(r.size.x / cell), ceili(r.size.y / cell))
	g.cell_size = Vector2(cell, cell)
	g.offset = r.position + Vector2(cell, cell) * 0.5
	g.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	g.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	g.update()
	var grow := Actor.RADIUS + 0.04 * W.M
	var wt := W.WALL * W.M
	var lr := W.lot_rect(plan.lots[lot_id])
	if lay.is_empty():
		_grid_solid(g, r, lr.grow(grow))
	else:
		for seg in lay["walls"]:
			var a: Vector2 = seg[0]
			var b: Vector2 = seg[1]
			var seg_r := Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (a - b).abs()).grow(wt * 0.5 + grow)
			_grid_solid(g, r, seg_r)
		for it in lay["items"]:
			if bool(it.get("solid", false)):
				_grid_solid(g, r, (it["rect"] as Rect2).grow(grow))
	_grids[lot_id] = g
	return g


func _grid_solid(g: AStarGrid2D, area: Rect2, solid: Rect2) -> void:
	var cell := g.cell_size.x
	var x0 := maxi(0, int(floor((solid.position.x - area.position.x) / cell)))
	var y0 := maxi(0, int(floor((solid.position.y - area.position.y) / cell)))
	var x1 := mini(g.region.size.x - 1, int(floor((solid.end.x - area.position.x) / cell)))
	var y1 := mini(g.region.size.y - 1, int(floor((solid.end.y - area.position.y) / cell)))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			g.set_point_solid(Vector2i(x, y), true)


func _grid_cell(g: AStarGrid2D, p: Vector2) -> Vector2i:
	var c := Vector2i(((p - g.offset) / g.cell_size).round())
	c = c.clamp(Vector2i.ZERO, g.region.size - Vector2i.ONE)
	if not g.is_point_solid(c):
		return c
	for rad in range(1, 6):
		for dy in range(-rad, rad + 1):
			for dx in range(-rad, rad + 1):
				var q := c + Vector2i(dx, dy)
				if g.is_in_boundsv(q) and not g.is_point_solid(q):
					return q
	return c


func _grid_path(lot_id: int, from: Vector2, to: Vector2) -> PackedVector2Array:
	var g := _grid(lot_id)
	var pts := g.get_point_path(_grid_cell(g, from), _grid_cell(g, to), true)
	var out := PackedVector2Array()
	# drop points on straight runs
	for k in pts.size():
		if k > 0 and k < pts.size() - 1:
			var d1 := (pts[k] - pts[k - 1]).normalized()
			var d2 := (pts[k + 1] - pts[k]).normalized()
			if d1.dot(d2) > 0.99:
				continue
		out.append(pts[k])
	out.append(to)
	return out


# ------------------------------------------------------------------ places people stand

func owner_pos(biz_id: int) -> Vector2:
	var a := actor("s%d" % biz_id)
	if a:
		return a.position
	var lay := layout_of_biz(biz_id)
	return lay.get("owner_spot", W.door(Game.biz_by_id(biz_id)))


## A random open shop near a point (for people going shopping), or {}.
func shop_near(p: Vector2, r: float) -> Dictionary:
	var cands := []
	for b in Game.biz:
		if b["kind"] in ["club", "precinct", "warehouse", "poolhall"] or int(b["closed_until"]) >= Game.month:
			continue
		if W.door(b).distance_to(p) < r:
			cands.append(b)
	return cands[randi() % cands.size()] if not cands.is_empty() else {}


## Where to stand to talk to a shop's owner: in front of the counter.
func talk_spot(biz_id: int) -> Vector2:
	var lay := layout_of_biz(biz_id)
	if lay.is_empty():
		return W.door(Game.biz_by_id(biz_id))
	var f: Vector2 = lay["front"]
	return (lay["owner_spot"] as Vector2) + f * 1.6 * W.M


## Where a frightened shopkeeper hides: the back room.
func shop_hide_spot(biz_id: int) -> Vector2:
	var lay := layout_of_biz(biz_id)
	if lay.is_empty() or (lay["back"] as Rect2).size == Vector2.ZERO:
		return Vector2.INF
	return (lay["back"] as Rect2).get_center()


## Where a family's man waits at the club: inside, by the tables, or at the door as a guard.
func club_spot(family: int, crew_id: int) -> Vector2:
	var hq := Game.biz_by_id(int(Game.fam(family).get("hq", -1)))
	var lay := layout_of_biz(int(hq.get("id", -1)))
	if lay.is_empty():
		return W.door(hq)
	var guards: Array = lay["spots"].get("guards", [])
	var k := crew_id % 5
	if k < guards.size():
		return guards[k]
	var shop: Rect2 = lay["shop"]
	var rr := W.rng(crew_id)
	return shop.get_center() + Vector2(rr.randf_range(-0.3, 0.3) * shop.size.x, rr.randf_range(-0.25, 0.25) * shop.size.y)


func follow_slot(me: Actor, leader: Actor) -> Vector2:
	var idx := 0
	var n := 0
	for a in actors.values():
		var ac := a as Actor
		if ac.kind == "crew" and ac.family == me.family and ac.sim:
			var c := Game.crew_by_id(ac.ref_id)
			if c.get("task", "") == "follow" and String(c.get("leader", "")) == leader.key.substr(1):
				if ac == me:
					idx = n
				n += 1
	var offs := [Vector2(-1.2, -0.9), Vector2(-1.2, 0.9), Vector2(-2.3, 0), Vector2(-2.6, -1.6), Vector2(-2.6, 1.6), Vector2(-3.6, 0)]
	var o: Vector2 = offs[idx % offs.size()] * W.M
	if leader.lot >= 0:
		o *= 0.6
	return leader.position + o.rotated(leader.yaw)


func guard_offset(id: int, b: Dictionary) -> Vector2:
	var f := W.front_dir(float(b["yaw"]))
	var side := -1.0 if id % 2 == 0 else 1.0
	return f.orthogonal() * side * (1.2 + (id % 3) * 0.4) * W.M + f * 0.3 * W.M


func threat_near(me: Actor, r: float) -> Actor:
	for a in actors.values():
		var ac := a as Actor
		if ac.family != me.family or ac.last_attacked_t <= 0.0:
			continue
		var att := ac.last_attacker
		if att and is_instance_valid(att) and not att.is_down() and att.family != me.family \
				and att.kind != "cop" and att.position.distance_to(me.position) < r * 1.6:
			return att
	if Game.fam(me.family).get("ai", false):
		for a in actors.values():
			var ac := a as Actor
			if ac.family < 0 or ac.family == me.family or ac.is_down() or ac.hidden_in_car:
				continue
			if ac.kind not in ["crew", "boss"]:
				continue
			if Game.rel(me.family, ac.family)["war"] and not Game.has_truce(me.family, ac.family) \
					and ac.position.distance_to(me.position) < r:
				return ac
	return null


func something_ahead(v: Vehicle, dist: float) -> bool:
	var f := v.forward()
	for a in actors.values():
		var ac := a as Actor
		var to := ac.position - v.position
		if to.length() < dist and f.dot(to.normalized()) > 0.85 and not ac.hidden_in_car and ac.lot < 0:
			if absf(f.orthogonal().dot(to)) < 1.4 * W.M:
				return true
	for o in vehicles.values():
		if o == v:
			continue
		var to := (o as Vehicle).position - v.position
		if to.length() < dist + 2.0 * W.M and f.dot(to.normalized()) > 0.85:
			return true
	return false


func down_time_mult(a: Actor) -> float:
	var m := 1.0
	if a.family >= 0 and Rackets.has_ring(a.family, "drug"):
		m *= 0.5
	if a.family >= 0:
		for o in actors.values():
			var ac := o as Actor
			if ac != a and ac.kind == "crew" and ac.family == a.family and not ac.is_down() and ac.position.distance_to(a.position) < 20.0 * W.M \
					and String(Game.crew_by_id(ac.ref_id).get("trait", "")) == "medic":
				m *= 0.5
				break
	return m


## A crewman with the shooter specialty fires at the man he's fighting (uses the family's bullets).
func crew_shoot(a: Actor, target: Actor) -> void:
	var ars: Dictionary = Game.fam(a.family).get("arsenal", {})
	if int(ars.get("ammo", 0)) <= 0:
		return
	ars["ammo"] = int(ars["ammo"]) - 1
	a.yaw = (target.position - a.position).angle()
	a.person.rotation = a.yaw
	a.person.set_weapon("pistol")
	Game.add_evidence(a.family, "weapon", "Your men's guns: bullets in %s" % plan.district_at(a.position.x / W.M, a.position.y / W.M), 3.0)
	shoot(a)


# ------------------------------------------------------------------ day, night, weather

func _day_light() -> void:
	# one day and night per month: dawn 0.0, noon 0.25, dusk 0.5, midnight 0.75
	var t := Game.clock
	var sun_up := sin(t * TAU)
	var night := clampf(0.5 - sun_up * 1.1, 0.0, 1.0)
	var dusk := clampf(1.0 - absf(sun_up) * 3.0, 0.0, 1.0)
	var wet := 1.0 if weather == "rain" else 0.0
	lighting.set_level(night, dusk)
	weather_fx.set_night(night)
	if absf(night - _night) > 0.01:
		_night = night
		ground.set_night(night, wet)
		fronts.set_night(night, wet)
		interiors.set_night(night, wet)
		roofs.set_night(night, wet)
		for v in vehicles.values():
			(v as Vehicle).set_night(night)
	if boat:
		boat.visible = _boat_here()
	audio.set_mood(night, weather)
	# headlamps
	for v in vehicles.values():
		var ve := v as Vehicle
		if night > 0.3 and (absf(ve.speed) > 1.0 or ve.driver != 0 or not ve.lane.is_empty()):
			lighting.set_dynamic("car_" + ve.key, {"pos": ve.position + ve.forward() * ve.art.size_m().x * 0.45 * W.M,
				"r": 11.0 * W.M, "color": Color(1.0, 0.92, 0.7), "e": 0.9, "shape": "cone", "rot": ve.yaw})
		else:
			lighting.hide_dynamic("car_" + ve.key)


func night_level() -> float:
	return maxf(_night, 0.0)


func _boat_here() -> bool:
	return Game.clock > 0.55 and Game.clock < 0.97 and int(Game.boat.get("crates", 0)) > 0


func _boat() -> void:
	boat = Node2D.new()
	boat.name = "RumBoat"
	var tip: Array = plan.piers[1]["tip"]
	boat.position = W.p(float(tip[0]) + 7.0, float(tip[1]))
	boat.z_index = W.Z_FURNITURE
	boat.draw.connect(func() -> void:
		var m := W.M
		var hull := PackedVector2Array([Vector2(-2.2, -6.5), Vector2(2.2, -6.5), Vector2(2.4, 3.5), Vector2(0.0, 7.0), Vector2(-2.4, 3.5)])
		for k in hull.size():
			hull[k] *= m
		Draw.shadow(boat, hull, Vector2(10, 12), Color(0, 0, 0, 0.3))
		Draw.poly(boat, hull, Color("2a2522"))
		var deck := PackedVector2Array()
		for q in hull:
			deck.append(q * 0.88)
		Draw.poly(boat, deck, Color("6b5642"))
		for k in 9:
			var y := (-5.5 + k * 1.3) * m
			boat.draw_line(Vector2(-2.0 * m, y), Vector2(2.0 * m, y), Color("4e3e30"), 1.0)
		Draw.rrect(boat, Rect2(Vector2(-1.4, -1.0) * m, Vector2(2.8, 3.2) * m), 6.0, Color("d8d0bc"))
		Draw.rect(boat, Rect2(Vector2(-1.2, -0.8) * m, Vector2(2.4, 2.8) * m), Color("b8b09c"))
		for k in 6:
			Draw.rect(boat, Rect2(Vector2(-1.6 + (k % 3) * 1.1, -5.0 + (k / 3) * 0.8) * m, Vector2(0.9, 0.7) * m), Color("8a6a44"), true)
		Draw.circle(boat, Vector2(0, -3.2) * m, 0.18 * m, Color("ffd080")))
	add_child(boat)
	boat.queue_redraw()


## The chalkboard at the shape-up on the quay.
func _shape_up_board() -> void:
	var spot := union_spot()
	var n := Node2D.new()
	n.position = (spot[0] as Vector2) + Vector2(0.4, -1.4) * W.M
	n.z_index = W.Z_FURNITURE
	n.draw.connect(func() -> void:
		var m := W.M
		Draw.rect(n, Rect2(Vector2(-0.95, -0.12) * m + Vector2(4, 5), Vector2(1.9, 0.24) * m), Pal.SHADOW)
		Draw.rect(n, Rect2(Vector2(-0.95, -0.12) * m, Vector2(1.9, 0.24) * m), Color("2f4a38"), true)
		n.draw_rect(Rect2(Vector2(-0.95, -0.12) * m, Vector2(1.9, 0.24) * m), Color("3a2a1c"), false, 3.0)
		Draw.text(n, Vector2(0, -0.2 * m), "LOCAL %s · SHAPE-UP 7 A.M." % Game.UNION_LOCAL, 12, Color("e9dfc7"), W.font("cond"), HORIZONTAL_ALIGNMENT_CENTER, -1, 3))
	add_child(n)
	n.queue_redraw()


func _on_month(m: int) -> void:
	if not Net.is_host():
		return
	var r := randf()
	weather = "rain" if r < 0.3 else ("fog" if r < 0.4 else "clear")
	Net.to_all("weather", [weather])
	Net.to_all("newspaper", [m])
	# favors: old jobs run out, new shops ask for help
	for k in Game.players:
		var job: Dictionary = Game.players[k].get("job", {})
		if not job.is_empty() and int(job.get("until", -1)) < m:
			_end_job(int(k), Favors.fail(Game, int(k), "Too late: %s found somebody else to help him." % Game.biz_by_id(int(job["biz"])).get("owner_name", "he")))
	Favors.refresh(Game)
	# broken things get fixed over the month
	for b in Game.biz:
		if not (b.get("broken", []) as Array).is_empty():
			b["broken"] = []
	Game.mark_dirty()
	if m % 3 == 0:
		Game.save_campaign()


# ------------------------------------------------------------------ the waterfront

func quay_warehouses() -> Array:
	var out := Game.biz.filter(func(b: Dictionary) -> bool: return b["kind"] == "warehouse")
	out.sort_custom(func(a, b) -> bool: return float(a["door"][1]) < float(b["door"][1]))
	return out


## Where the hiring boss stands: on the quay by the first warehouse. [Vector2 px, facing]
func union_spot() -> Array:
	var whs := quay_warehouses()
	if whs.is_empty():
		var q: Array = plan.quay_rect
		return [W.p(float(q[0]) + 2.0, float(q[1]) + 20.0), PI]
	var b: Dictionary = whs[0]
	var f := W.front_dir(float(b["yaw"]))
	return [W.door(b) + f.orthogonal() * 4.2 * W.M + f * 0.8 * W.M, f.angle()]


func _spawn_waterfront() -> void:
	_spawn_union()
	for k in DOCKERS + 2:
		_spawn_docker(k)


func _spawn_union() -> void:
	var spot := union_spot()
	var u := _make_actor("u1")
	u.sim = true
	u.place(spot[0], spot[1])


func _spawn_docker(k: int) -> void:
	var d := _make_actor("d%d" % k)
	if d == null:
		return
	d.sim = true
	if k >= DOCKERS:
		var spot := union_spot()
		var j := k - DOCKERS
		d.place((spot[0] as Vector2) + Vector2(1.3 + j * 0.9, 1.4 + j * 0.5).rotated(float(spot[1])) * W.M, float(spot[1]) + PI + 0.4 - j * 0.8)
		return
	var pier: Dictionary = plan.piers[k % plan.piers.size()]
	var zc := (float(pier["z0"]) + float(pier["z1"])) * 0.5
	var lane := -1.4 if k % 2 == 0 else 1.4
	var wx := plan.water_x
	var a := W.p(wx + 9.0 + (k % 2) * 6.0, zc + lane)
	var b := W.p(wx - 2.5, zc + lane * 0.6)
	var c := W.p(wx - 6.5 - (k % 3), zc + lane * 3.4)
	d.place(a.lerp(c, float(k) / DOCKERS), 0.0)
	d.route = [a, b, c, b]
	d.route_i = 1 if k % 2 == 0 else 3


## Crates stacked on the pallets inside each warehouse: one per five in its owner's stock.
func _update_stacks() -> void:
	var seen_owner := {}
	for b in quay_warehouses():
		var owner := int(b["owned_by"])
		var n := 0
		if owner >= 0 and not seen_owner.has(owner):
			seen_owner[owner] = true
			n = Syndicate.stock(Game.nation, "nyc", owner)
		var st: Node2D = _stacks.get(b["id"])
		if st == null:
			st = Node2D.new()
			st.z_index = W.Z_FURNITURE + 1
			var bid: int = b["id"]
			st.draw.connect(func() -> void: _draw_stack(st, bid))
			add_child(st)
			_stacks[b["id"]] = st
		st.set_meta("n", n)
		st.queue_redraw()


func _draw_stack(st: Node2D, biz_id: int) -> void:
	var n := int(st.get_meta("n", 0))
	var lay := layout_of_biz(biz_id)
	if lay.is_empty():
		return
	var area: Rect2 = lay["spots"].get("stock", (lay["shop"] as Rect2).grow(-1.5 * W.M))
	var cw := 0.66 * W.M
	var ch := 0.56 * W.M
	var cols := maxi(1, int(area.size.x / (cw + 4)))
	var shown := mini(ceili(n / 5.0), 80)
	for k in shown:
		var x := area.position.x + (k % cols) * (cw + 4)
		var y := area.position.y + (k / cols) * (ch + 4)
		if y + ch > area.end.y:
			break
		var r := Rect2(Vector2(x, y), Vector2(cw, ch))
		Draw.rect(st, Rect2(r.position + Vector2(3, 4), r.size), Pal.SHADOW)
		Draw.rect(st, r, Color("8a6a44"))
		st.draw_rect(r, Color("4e3822"), false, 1.5)
		st.draw_line(r.position, r.end, Color("5e4428"), 1.5)


## The family's truck parked near a point (not being driven), or null.
func parked_truck(family: int, at: Vector2, radius: float = 9.0 * W.M) -> Vehicle:
	var best: Vehicle = null
	var bd := radius
	for v in vehicles.values():
		var ve := v as Vehicle
		if ve.family != family or ve.driver != 0 or not ve.key.begins_with("t"):
			continue
		var d := ve.position.distance_to(at)
		if d < bd:
			bd = d
			best = ve
	return best


# ------------------------------------------------------------------ spawning

func actor(key: String) -> Actor:
	return actors.get(key) as Actor


func _make_actor(key: String) -> Actor:
	if actors.has(key):
		return actors[key]
	var prefix := key.substr(0, 1)
	var id := int(key.substr(1))
	var a := Actor.new()
	var kind := ""
	var look := id * 7919 + 13
	var color := W.FAMILY_NONE
	var family := -1
	var extra := {}
	match prefix:
		"p":
			var p := Game.player(id)
			if p.is_empty():
				return null
			kind = "boss"
			family = int(p["family"])
			look = String(p["name"]).hash()
		"a":
			kind = "aiboss"
			family = id
			look = id * 1031 + 7
		"c":
			var c := Game.crew_by_id(id)
			if c.is_empty():
				return null
			kind = "crew"
			family = int(c["family"])
			look = int(c["look"])
			a.tough = int(c["tough"])
		"k":
			kind = "cop"
			look = id * 313 + 1
		"n":
			kind = "ped"
			var r := W.rng(id * 17 + 5)
			var roll := r.randf()
			kind = "woman" if roll < 0.3 else ("kid" if roll < 0.38 else "ped")
		"w":
			kind = "newsboy"
		"h":
			kind = "crew"
			family = id / 1000
			look = id * 131 + 77
		"j":
			kind = "ped"
			look = id * 211 + 5
		"f":
			kind = "fed"
			look = id * 97 + 3
		"s":
			var b := Game.biz_by_id(id)
			if b.is_empty():
				return null
			kind = {"precinct": "cop", "warehouse": "docker", "club": "bartender"}.get(b["kind"], "shop")
			look = int(b["id"]) * 977 + 3
			extra = {"trade": b["kind"]}
		"r":
			kind = "recruit"
			for r2 in Game.recruits:
				if r2["id"] == id:
					look = int(r2["look"])
		"z":
			kind = "smuggler"
		"g":
			kind = "dealer"
		"u":
			kind = "unionboss"
			look = 4471
		"d":
			kind = "docker"
			look = id * 6151 + 29
		_:
			return null
	if family >= 0:
		color = W.fam_color(family)
	a.family = family
	a.ref_id = id
	a.setup(self, key, kind, look, color, extra)
	if prefix == "s":
		a.kind = "shop"
	elif prefix == "h":
		a.kind = "thug"
	elif prefix == "j":
		a.kind = "debtor"
	elif prefix == "f":
		a.kind = "fed"
	elif kind in ["woman", "kid"]:
		a.kind = "ped"
	add_child(a)
	actors[key] = a
	if kind in ["boss", "crew", "aiboss"] and prefix != "h":
		_add_ring(a)
	return a


## A ring under the family's people (so you can tell your men apart at a glance).
func _add_ring(a: Actor) -> void:
	var r := Node2D.new()
	r.z_index = -1
	r.show_behind_parent = true
	var col := W.fam_color(a.family)
	r.draw.connect(func() -> void:
		var me := local_actor != null and a == local_actor
		var mine := local_actor != null and a.family == local_actor.family
		var rad := 0.5 * W.M
		if me:
			r.draw_arc(Vector2.ZERO, rad, 0, TAU, 40, Color(1, 1, 1, 0.85), 3.0, true)
			r.draw_arc(Vector2.ZERO, rad + 4, 0, TAU, 40, Color(col, 0.9), 2.0, true)
		else:
			r.draw_arc(Vector2.ZERO, rad * 0.9, 0, TAU, 32, Color(col, 0.75 if mine else 0.5), 2.5 if mine else 2.0, true))
	a.add_child(r)


func _host_spawn() -> void:
	for k in PEDS:
		var a := _make_actor("n%d" % k)
		a.sim = true
		a.place(W.pa(plan.nodes[randi() % plan.nodes.size()]) + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * W.M)
	# a newsboy at a busy corner in every district
	for k in 3:
		_spawn_newsboy(k)
	for c in Game.cops:
		_spawn_cop(int(c["id"]), false)
	# the people behind the counters
	for b in Game.biz:
		if b["kind"] == "club" and int(b["hq_of"]) >= 0 and false:
			continue
		var lay := interiors.layout_of(int(b["lot"]))
		if lay.is_empty():
			continue
		var s := _make_actor("s%d" % b["id"])
		if s == null:
			continue
		s.sim = true
		var spot: Vector2 = lay["spots"].get("sergeant", lay["owner_spot"])
		s.place(spot, float(lay["owner_rot"]) + PI)
	_spawn_izzy()
	_spawn_smuggler()
	_spawn_waterfront()
	for f in Game.families:
		var hq := Game.biz_by_id(int(f["hq"]))
		var fd := W.front_dir(float(hq["yaw"]))
		var street := W.door(hq) + fd * 5.2 * W.M
		var t := Vehicle.new()
		t.setup(self, "t%d" % f["id"], "truck", Color(f["color"]))
		t.family = f["id"]
		add_child(t)
		t.sim = true
		t.place(street + fd.orthogonal() * 3.0 * W.M, fd.orthogonal().angle())
		vehicles[t.key] = t
	for k in TRAFFIC:
		var v := Vehicle.new()
		var kinds := ["sedan", "sedan", "touring", "taxi", "delivery", "sedan", "police", "van"]
		v.setup(self, "v%d" % k, kinds[k % kinds.size()])
		add_child(v)
		v.sim = true
		v.lane = _lane_loop(k)
		v.place(v.lane[0], (v.lane[1] - v.lane[0]).angle())
		vehicles[v.key] = v
	_sync_spawns()
	Favors.refresh(Game)


## A clockwise loop around a rectangle of blocks, in the right-hand lane.
func _lane_loop(k: int) -> Array:
	var i0 := k % (CityPlan.NX - 1)
	var j0 := (k * 3) % (CityPlan.NZ - 1)
	var i1 := mini(i0 + 1 + k % 2, CityPlan.NX)
	var j1 := mini(j0 + 1 + (k / 2) % 2, CityPlan.NZ)
	var P := CityPlan.PITCH
	var o := 3.0
	return [W.p(i0 * P - o, j0 * P - o), W.p(i1 * P + o, j0 * P - o),
		W.p(i1 * P + o, j1 * P + o), W.p(i0 * P - o, j1 * P + o)]


func _near_door(b: Dictionary, off: float) -> Vector2:
	var f := W.front_dir(float(b["yaw"]))
	return W.door(b) + f.orthogonal() * off * W.M + f * 0.6 * W.M


## Host: make the world's people match Game (hired, jailed, killed, joined).
func _sync_spawns() -> void:
	if not Net.is_host():
		return
	var want := {}
	for k in Game.players:
		want["p" + k] = true
	for f in Game.families:
		if f["ai"] and f["alive"]:
			want["a%d" % f["id"]] = true
	for c in Game.crew:
		if c["state"] == "free":
			want["c%d" % c["id"]] = true
	for r in Game.recruits:
		want["r%d" % r["id"]] = true
	for key in want:
		if actors.has(key):
			continue
		var a := _make_actor(key)
		if a == null:
			continue
		var prefix: String = key.substr(0, 1)
		match prefix:
			"p":
				var hq := Game.biz_by_id(int(Game.fam(a.family)["hq"]))
				a.place(_near_door(hq, randf_range(-1.5, 1.5)), W.facing_out(float(hq["yaw"])))
				a.sim = key == "p%d" % Net.my_id()
				a.is_local_player = a.sim
			"a":
				var hq2 := Game.biz_by_id(int(Game.fam(a.family)["hq"]))
				var lay := layout_of_biz(int(hq2["id"]))
				var at: Vector2 = lay["spots"].get("desk", lay.get("owner_spot", W.door(hq2))) if not lay.is_empty() else W.door(hq2)
				a.place(at, W.facing_out(float(hq2["yaw"])))
				a.sim = true
			"c":
				a.place(club_spot(a.family, a.ref_id), 0.0)
				a.sim = true
			"r":
				for r in Game.recruits:
					if "r%d" % r["id"] == key:
						var ph := Game.biz_by_id(int(r["at"]))
						var lay2 := layout_of_biz(int(ph["id"]))
						var spots: Array = lay2["spots"].get("recruits", []) if not lay2.is_empty() else []
						var at2: Vector2 = spots[int(r["id"]) % spots.size()] if not spots.is_empty() else _near_door(ph, 1.6 if r["id"] % 2 == 0 else -1.6)
						a.place(at2 + Vector2(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3)) * W.M, randf() * TAU)
				a.sim = true
	for key in actors.keys():
		var prefix: String = key.substr(0, 1)
		if prefix in ["p", "a", "c", "r"] and not want.has(key):
			var a: Actor = actors[key]
			if a.dead:
				continue
			actors.erase(key)
			a.queue_free()


func _ensure_local_boss() -> void:
	var key := "p%d" % Net.my_id()
	if not Net.is_host():
		if not actors.has(key):
			var a := _make_actor(key)
			if a:
				var hq := Game.biz_by_id(int(Game.fam(a.family)["hq"]))
				a.place(_near_door(hq, randf_range(-1.5, 1.5)), W.facing_out(float(hq["yaw"])))
	local_actor = actor(key)
	if local_actor:
		local_actor.sim = true
		local_actor.is_local_player = true
		cam.target = local_actor
		cam.snap()


# ------------------------------------------------------------------ frame

func _process(delta: float) -> void:
	_day_light()
	weather_fx.set_kind(weather)
	if local_actor == null or not is_instance_valid(local_actor):
		_ensure_local_boss()
	_track_inside()
	if Net.is_host():
		_host_tick(delta)
	_pose_t -= delta
	if _pose_t <= 0.0 and local_actor:
		_pose_t = 1.0 / POSE_HZ
		if not Net.is_host():
			_send_pose()
	_update_meters()
	_obj_t -= delta
	if _obj_t <= 0.0:
		_obj_t = 0.5
		_show_job()
		_marks.queue_redraw()
		_nightlife()


## Fade the roof of the building the local player is in; tell them where they are.
func _track_inside() -> void:
	var lot := -1
	if local_actor and not local_actor.hidden_in_car:
		lot = local_actor.lot
	if lot != inside_lot:
		inside_lot = lot
		roofs.set_inside(lot)
		cam.inside = lot >= 0
		if lot >= 0:
			var b := biz_at_lot(lot)
			if not b.is_empty():
				audio.at("door", local_actor.position)
				happened.emit("entered", {"biz": b["id"], "kind": b["kind"]})
				_banner(b)


func _banner(b: Dictionary) -> void:
	var me := int(Game.player(Net.my_id()).get("family", -1))
	var who := ""
	if int(b["owned_by"]) == me:
		who = "Yours"
	elif int(b["owned_by"]) >= 0:
		who = "Owned by the %s family" % Game.fam(int(b["owned_by"]))["name"]
	elif int(b["protector"]) == me:
		who = "Pays you $%d a month" % int(b["rate"])
	elif int(b["protector"]) >= 0:
		who = "Pays the %s family" % Game.fam(int(b["protector"]))["name"]
	elif b["kind"] not in ["precinct", "club"]:
		who = "Pays nobody"
	if hud.has_method("show_place"):
		hud.call("show_place", String(b["name"]), who)
	else:
		hud.toast("%s · %s" % [b["name"], who] if who != "" else String(b["name"]), "info")


func _host_tick(delta: float) -> void:
	_snap_t -= delta
	if _snap_t <= 0.0:
		_snap_t = 1.0 / SNAP_HZ
		Net.send_snapshot(_make_snapshot())
	_state_t -= delta
	if _state_t <= 0.0:
		_state_t = 0.25
		if Game.consume_dirty():
			Net.send_state(Game.get_state())
			Game.state_changed.emit()
	_sync_t -= delta
	if _sync_t <= 0.0:
		_sync_t = 2.0
		_sync_spawns()
		_cleanup_corpses()
	_contra_t -= delta
	if _contra_t <= 0.0:
		_contra_t = 0.5
		_watch_contraband()
	_shake_t -= delta
	if _shake_t <= 0.0:
		_shake_t = 0.5
		_shake_tick(0.5)
	_ring_t -= delta
	if _ring_t <= 0.0:
		_ring_t = 3.0
		_check_rings()
	_job_t -= delta
	if _job_t <= 0.0:
		_job_t = 0.5
		_check_jobs()
		_check_victory()
	var smug := actor("z1")
	if smug:
		smug.visible = _boat_here()
	# run people over
	for v in vehicles.values():
		var veh := v as Vehicle
		if absf(veh.speed) > 6.0 * W.M:
			for a in actors.values():
				var ac := a as Actor
				if ac.is_down() or ac.hidden_in_car:
					continue
				if ac.position.distance_to(veh.position + veh.forward() * 1.8 * W.M) < 1.4 * W.M:
					ac.hurt(45.0, null)
					ac.knock_down(6.0)
					if veh.driver != 0:
						var drv := actor("p%d" % veh.driver)
						if drv:
							crime(drv, 10.0, ac.position, "hit and run", ac.family)


## Host: the feds hit a family. G-men pull up outside its club and its speakeasies and go in.
func _on_raid(family: int) -> void:
	if not Net.is_host():
		return
	var places := [Game.biz_by_id(int(Game.fam(family)["hq"]))]
	for b in Game.owned_by(family):
		if b["speak"]:
			places.append(b)
	var n := 0
	for b in places.slice(0, 3):
		var f := W.front_dir(float(b["yaw"]))
		for k in 3:
			var key := "f%d" % (randi_range(1, 99999))
			var g := _make_actor(key)
			if g == null:
				continue
			g.sim = true
			g.place(W.door(b) + f * (3.0 + k * 0.8) * W.M + f.orthogonal() * (k - 1) * 1.2 * W.M, (-f).angle())
			g.home = talk_spot(int(b["id"])) + f.orthogonal() * (k - 1) * 0.9 * W.M
			g.home_yaw = (-f).angle()
			n += 1
			get_tree().create_timer(70.0).timeout.connect(func() -> void:
				if is_instance_valid(g) and not g.dead:
					actors.erase(g.key)
					g.queue_free())
	fx_all("whistle", [])
	Net.to_all("raid", [family])


## Host: every other family finished? The last one standing runs New York.
func _check_victory() -> void:
	if Game.over or not Game.running:
		return
	var alive := Game.families.filter(func(f: Dictionary) -> bool: return bool(f["alive"]))
	if alive.size() == 1 and Game.families.size() > 1:
		Game._headline("THE %s FAMILY RUNS NEW YORK. The last rival don is gone." % String(alive[0]["name"]).to_upper(), true)
		Game.over = true
		Game.mark_dirty()
		Net.to_all("over", [])


## Host: put the people a favor needs on the street.
func _start_job(peer: int) -> void:
	var p := Game.player(peer)
	var job: Dictionary = p.get("job", {})
	var keys := []
	match String(job.get("kind", "")):
		"thugs":
			var b := Game.biz_by_id(int(job["biz"]))
			var f := W.front_dir(float(b["yaw"]))
			for k in 2:
				var key := "h%d" % (int(job["rival"]) * 1000 + randi_range(1, 999))
				var t := _make_actor(key)
				if t:
					t.sim = true
					t.tough = 55
					t.place(W.door(b) + f * (1.4 + k * 0.6) * W.M + f.orthogonal() * (k * 2 - 1) * 1.1 * W.M, (-f).angle())
					keys.append(key)
		"debt":
			var tb := Game.biz_by_id(int(job["target_biz"]))
			var f2 := W.front_dir(float(tb["yaw"]))
			var key2 := "j%d" % randi_range(1, 99999)
			var d := _make_actor(key2)
			if d:
				d.sim = true
				d.place(W.door(tb) + f2 * 2.0 * W.M + f2.orthogonal() * 1.5 * W.M, f2.angle())
				keys.append(key2)
	job["keys"] = keys
	Game.mark_dirty()


func _end_job(peer: int, r: Dictionary) -> void:
	if r.is_empty():
		return
	for key in r.get("keys", []):
		var a := actor(String(key))
		if a and not a.dead:
			get_tree().create_timer(12.0).timeout.connect(func() -> void:
				if is_instance_valid(a) and not a.dead:
					actors.erase(a.key)
					a.queue_free())
	if String(r.get("msg", "")) != "":
		Net.to_peer(peer, "reply", [r["msg"], bool(r.get("ok", false))])
	if bool(r.get("ok", false)):
		Net.to_peer(peer, "job_done", [])


## Host: thugs knocked down, debtors knocked down: favors done.
func _check_jobs() -> void:
	for k in Game.players:
		var job: Dictionary = Game.players[k].get("job", {})
		if job.is_empty():
			continue
		match String(job.get("kind", "")):
			"thugs", "debt":
				var keys: Array = job.get("keys", [])
				if keys.is_empty():
					continue
				var all_down := true
				for key in keys:
					var a := actor(String(key))
					if a and not a.is_down():
						# a thug who walked far from the shop has been run off
						if job["kind"] == "thugs" and a.position.distance_to(a.home) > 20.0 * W.M:
							continue
						all_down = false
				if all_down:
					_end_job(int(k), Favors.complete(Game, int(k)))


## Everyone: the current favor as the goal on screen (when the tutorial isn't showing one).
func _show_job() -> void:
	var tut := get_node_or_null("Tutorial")
	if tut and is_instance_valid(tut) and tut.is_processing():
		return
	var p := Game.player(Net.my_id())
	var job: Dictionary = p.get("job", {})
	if job.is_empty():
		# no favor going: the advisor's best next move
		_adv_t -= 0.5
		if _adv_t <= 0.0:
			_adv_t = 3.0
			var adv := Advisor.next(self)
			if adv.is_empty():
				if _my_obj:
					hud.clear_objective()
					_my_obj = false
			else:
				adv["title"] = "Next: " + String(adv["title"])
				hud.set_objective(adv)
				_my_obj = true
		return
	_adv_t = 0.0
	var b := Game.biz_by_id(int(job["biz"]))
	var t := Favors.text(job, b)
	var target := Vector2.INF
	match String(job["kind"]):
		"parcel":
			target = talk_spot(int(job["target_biz"]))
		_:
			var keys: Array = job.get("keys", [])
			for key in keys:
				var a := actor(String(key))
				if a and not a.is_down():
					target = a.position
					break
			if target == Vector2.INF and not keys.is_empty():
				target = W.door(b)
	hud.set_objective({"title": String(t.get("title", "A favor")), "detail": String(t.get("detail", "")) + "  ·  $%d" % int(job["reward"]), "target": target})
	_my_obj = true


## Speakeasies at night: patrons at the tables, a man on the piano, the bartender. Only drawn on
## this machine (the same everywhere: it's scenery), and only for the joints near you.
func _nightlife() -> void:
	var open := night_level() > 0.45
	var near := cam.focus_point()
	for b in Game.biz:
		var key := int(b["id"])
		var want: bool = open and bool(b["speak"]) and int(b["closed_until"]) < Game.month and W.door(b).distance_to(near) < 40.0 * W.M
		var have: Node2D = _decor.get(key)
		if want and have == null:
			var lay := layout_of_biz(key)
			if lay.is_empty():
				continue
			var root := Node2D.new()
			root.z_index = W.Z_PEOPLE - 1
			add_child(root)
			_decor[key] = root
			var back: Rect2 = lay["back"]
			var spots: Array = lay["spots"].get("patrons", [])
			var rr := W.rng(key * 53 + 11)
			if spots.is_empty():
				for k in 5:
					spots.append(back.position + Vector2(rr.randf_range(0.2, 0.8) * back.size.x, rr.randf_range(0.25, 0.8) * back.size.y))
			for k in spots.size():
				var p := Person2D.new()
				p.setup("patron", key * 100 + k, W.FAMILY_NONE)
				p.position = spots[k]
				p.rotation = rr.randf() * TAU
				p.set_motion(Person2D.Anim.SIT if k % 3 != 0 else Person2D.Anim.TALK, 0.0)
				root.add_child(p)
			var bar: Vector2 = lay["spots"].get("bar", back.position + Vector2(back.size.x * 0.15, back.size.y * 0.5))
			var bt := Person2D.new()
			bt.setup("bartender", key * 7 + 1, W.FAMILY_NONE)
			bt.position = bar
			root.add_child(bt)
		elif not want and have != null:
			have.queue_free()
			_decor.erase(key)
	# music when you're in one
	var in_speak := false
	if inside_lot >= 0 and open:
		var bb := biz_at_lot(inside_lot)
		in_speak = not bb.is_empty() and bool(bb["speak"])
	if audio.has_method("speakeasy"):
		audio.call("speakeasy", in_speak)


## "!" over the door of every shop with a favor to ask.
func _draw_marks() -> void:
	for b in Game.biz:
		if not b.has("favor"):
			continue
		var at := W.door(b) + Vector2(0, -0.2) * W.M
		var bob := sin(Time.get_ticks_msec() / 300.0 + float(b["id"])) * 3.0
		var c := at + Vector2(0, -1.1 * W.M + bob)
		Draw.circle(_marks, c + Vector2(3, 4), 15.0, Color(0, 0, 0, 0.35))
		Draw.circle(_marks, c, 15.0, Pal.GOLD2)
		_marks.draw_arc(c, 15.0, 0, TAU, 32, Color("5a3e1a"), 2.0, true)
		Draw.text(_marks, c + Vector2(0, 8), "!", 24, Color("3a2410"), W.font("serif"), HORIZONTAL_ALIGNMENT_CENTER)


## The cheapest shop that pays a family and could be bought as a front, or {}.
func cheapest_front(family: int) -> Dictionary:
	var best := {}
	for b in Game.shops_of(family):
		if int(b["owned_by"]) < 0 and b["kind"] not in ["club", "warehouse", "precinct"]:
			if best.is_empty() or int(b["value"]) < int(best["value"]):
				best = b
	return best


## A family that just took every shop of a trade gets the ring's perk; one that lost one loses it.
func _check_rings() -> void:
	for f in Game.families:
		if not f["alive"]:
			continue
		var fid: int = f["id"]
		var had: Dictionary = _rings_done.get(fid, {})
		var now := {}
		for r in Rackets.ring_progress(fid):
			if r["done"]:
				now[r["id"]] = true
				if not had.has(r["id"]) and _rings_done.has(fid):
					Game.notice.emit(fid, "You run %s now: %s" % [r["name"].to_lower(), r["perk"]], "good")
					Game._log("THE %s FAMILY NOW CONTROLS %s ACROSS THE LOWER EAST SIDE." % [String(f["name"]).to_upper(), String(r["name"]).to_upper()])
			elif had.has(r["id"]):
				Game.notice.emit(fid, "You lost %s. The perk is gone." % r["name"].to_lower(), "bad")
		_rings_done[fid] = now


func car_bump(_v: Vehicle) -> void:
	cam.shake(0.3)


# ------------------------------------------------------------------ shakedowns (host)

## Every half second: fear fades, your men standing in a shop you're shaking down make the owner
## sweat, and an owner who reaches his limit pays (or snaps).
func _shake_tick(dt: float) -> void:
	for b in Game.biz:
		var fam := int(b.get("shake", -1))
		if fam < 0:
			continue
		var men := 0
		var lot := int(b["lot"])
		for a in actors.values():
			var ac := a as Actor
			if ac.kind == "crew" and ac.family == fam and ac.lot == lot and not ac.is_down():
				men += 1
		if men > 0:
			Rackets.scare(Game, fam, int(b["id"]), "crowd", 1.6 * men * dt, _crew_near(fam, lot))
		Rackets.cool(Game, int(b["id"]), dt)
		var r: Dictionary = Rackets.check(Game, int(b["id"]))
		if not r.is_empty():
			_shake_result(b, r)


func _crew_near(family: int, lot: int) -> Array:
	var out := []
	for a in actors.values():
		var ac := a as Actor
		if ac.kind == "crew" and ac.family == family and (ac.lot == lot or lot < 0) and not ac.is_down():
			out.append(ac.ref_id)
	return out


func _shake_result(b: Dictionary, r: Dictionary) -> void:
	var owner := actor("s%d" % b["id"])
	match String(r.get("kind", "")):
		"deal":
			if owner:
				owner.person.action("yes")
				fx_all("cheer", [owner.key])
			Net.to_all("shake_deal", [int(b["id"]), int(r["family"])])
			happened.emit("protected", {"biz": b["id"], "family": r["family"]})
		"snap":
			if owner:
				owner.scare(owner.position, 10.0)
			fx_all("whistle", [owner.key if owner else ""])
	if String(r.get("msg", "")) != "":
		for k in Game.players:
			if int(Game.players[k]["family"]) == int(r["family"]):
				Net.to_peer(int(k), "reply", [r["msg"], String(r["kind"]) == "deal"])
	Game.mark_dirty()


## The owner of a shop was hit. If someone's shaking him down, it counts.
func shopkeeper_hurt(owner: Actor, from: Actor, down: bool) -> void:
	if from == null or from.family < 0:
		return
	var b := Game.biz_by_id(owner.ref_id)
	if b.is_empty():
		return
	_scare_owner(from, b, "rough", 12.0 + (18.0 if down else 0.0))


## Something that scares a shop owner happened in his shop (a smash, a punch, a shot).
func _scare_owner(perp: Actor, b: Dictionary, how: String, amount: float) -> void:
	var fam := perp.family
	if fam < 0 or int(b["protector"]) == fam or int(b["owned_by"]) >= 0 or b["kind"] in ["precinct", "club", "warehouse"]:
		return
	if int(b.get("shake", -1)) != fam:
		Rackets.start(Game, fam, int(b["id"]))
	var before := float(b["fear"])
	Rackets.scare(Game, fam, int(b["id"]), how, amount, _crew_near(fam, int(b["lot"])))
	var owner := actor("s%d" % b["id"])
	if owner and float(b["fear"]) - before >= 1.0:
		float_all(owner.position, ("FEAR +%d" % int(float(b["fear"]) - before)) + ("  weak spot!" if String(b.get("weak", "")) == how else ""), "fear")
	var r: Dictionary = Rackets.check(Game, int(b["id"]))
	if not r.is_empty():
		_shake_result(b, r)
	Game.mark_dirty()


## Fear meters over the owners the local player's family is shaking down (everyone draws their own).
func _update_meters() -> void:
	var me := int(Game.player(Net.my_id()).get("family", -2))
	for b in Game.biz:
		var id := "fear%d" % b["id"]
		if int(b.get("shake", -1)) == me and me >= 0:
			var a := actor("s%d" % b["id"])
			if a and inside_lot == int(b["lot"]):
				hud.set_meter(id, a.position, float(b["fear"]) / 100.0, Rackets.FEAR_DEAL / 100.0, "FEAR", Pal.UI_RED)
				continue
		hud.clear_meter(id)


# ------------------------------------------------------------------ snapshots and poses

func _make_snapshot() -> PackedByteArray:
	var a := {}
	for k in actors:
		var ac: Actor = actors[k]
		if ac.hidden_in_car or not ac.visible or k.begins_with("m"):
			continue
		a[k] = PackedFloat32Array([ac.position.x, ac.position.y, ac.yaw, ac.state, ac.speed, 1.0 if ac.carrying else 0.0])
	var v := {}
	for k in vehicles:
		var ve: Vehicle = vehicles[k]
		v[k] = PackedFloat32Array([ve.position.x, ve.position.y, ve.yaw, ve.driver, ve.load])
	var it := {}
	for id in items:
		var c: Crate = items[id]
		it[id] = PackedFloat32Array([c.position.x, c.position.y, 0.0 if c.kind == "crate" else 1.0, c.amount])
	return var_to_bytes({"a": a, "v": v, "i": it, "w": weather})


func _on_snapshot(data: PackedByteArray) -> void:
	if Net.is_host():
		return
	var s = bytes_to_var(data)
	if not s is Dictionary:
		return
	var now := Time.get_ticks_msec() / 1000.0
	var me := "p%d" % Net.my_id()
	for k in s["a"]:
		if k == me:
			continue
		var d: PackedFloat32Array = s["a"][k]
		var ac := actor(k)
		if ac == null:
			ac = _make_actor(k)
			if ac == null:
				continue
			ac.sim = false
		ac.visible = true
		ac.net_update(Vector2(d[0], d[1]), d[2], int(d[3]), d[4], d[5] > 0.5)
		_last_seen[k] = now
	for k in actors.keys():
		if k == me:
			continue
		if now - float(_last_seen.get(k, now)) > 1.5:
			var gone: Actor = actors[k]
			if gone.state == Person2D.Anim.DEAD and now - float(_last_seen.get(k, now)) < 20.0:
				continue
			actors.erase(k)
			gone.queue_free()
			_last_seen.erase(k)
	for k in s["v"]:
		var d: PackedFloat32Array = s["v"][k]
		var ve: Vehicle = vehicles.get(k)
		if ve == null:
			ve = Vehicle.new()
			var kd := "truck"
			var col := W.FAMILY_NONE
			if k.begins_with("t"):
				col = W.fam_color(int(k.substr(1)))
			else:
				var kinds := ["sedan", "sedan", "touring", "taxi", "delivery", "sedan", "police", "van"]
				kd = kinds[int(k.substr(1)) % kinds.size()]
			ve.setup(self, k, kd, col)
			if k.begins_with("t"):
				ve.family = int(k.substr(1))
			add_child(ve)
			vehicles[k] = ve
		if ve == local_vehicle:
			continue
		ve.net_update(Vector2(d[0], d[1]), d[2], int(d[3]), int(d[4]))
	var seen := {}
	for id in s["i"]:
		seen[id] = true
		var d: PackedFloat32Array = s["i"][id]
		if not items.has(id):
			var c := Crate.new()
			c.setup(id, "crate" if d[2] < 0.5 else "cash", int(d[3]))
			add_child(c)
			items[id] = c
		(items[id] as Crate).position = Vector2(d[0], d[1])
	for id in items.keys():
		if not seen.has(id):
			(items[id] as Crate).queue_free()
			items.erase(id)
	if s.get("w", weather) != weather:
		weather = s["w"]


func _send_pose() -> void:
	var a := local_actor
	var v := local_vehicle
	var d := PackedFloat32Array([a.position.x, a.position.y, a.yaw, a.state, a.speed, 1.0 if a.carrying else 0.0,
		1.0 if v else 0.0, v.position.x if v else 0.0, v.position.y if v else 0.0, v.yaw if v else 0.0, v.speed if v else 0.0])
	Net.send_pose(d)


func _on_pose(peer: int, d: PackedFloat32Array) -> void:
	if peer == Net.my_id():
		return
	var a := actor("p%d" % peer)
	if a == null or a.down_t > 0.0:
		return
	# the host decides what he carries and whether he's in a car: only take the client's position
	a.net_update(Vector2(d[0], d[1]), d[2], int(d[3]), d[4], a.carrying)
	a.position = a.net_pos
	a.hidden_in_car = d[6] > 0.5 and vehicles.values().any(func(v) -> bool: return (v as Vehicle).driver == peer)
	a.visible = not a.hidden_in_car
	if a.hidden_in_car:
		for v in vehicles.values():
			var ve := v as Vehicle
			if ve.driver == peer:
				ve.net_update(Vector2(d[7], d[8]), d[9], peer, ve.load)
				ve.position = ve.net_pos
				ve.rotation = d[9]
				ve.yaw = d[9]
				if d.size() > 10:
					ve.speed = d[10]  # so the host can tell when he runs somebody over


# ------------------------------------------------------------------ violence and the law (host)

## A punch or a shot goes where the player aimed it on his screen, not where his last pose said.
func _face(me: Actor, args: Array) -> void:
	if not args.is_empty():
		me.yaw = float(args[0])
		me.person.rotation = me.yaw

func melee(att: Actor, target: Actor) -> void:
	if target == null or target.is_down():
		return
	fx_all("punch", [att.key])
	var dmg := 16.0 + att.tough * 0.12 + randf_range(-3.0, 3.0)
	if att.kind == "crew" and String(Game.crew_by_id(att.ref_id).get("trait", "")) == "bruiser":
		dmg *= 2.0
	target.hurt(dmg, att)
	if att.kind in ["boss", "crew"]:
		var sev := 5.0
		if target.kind == "cop":
			sev = 25.0
		elif target.family < 0:
			sev = 8.0
		crime(att, sev, target.position, "assault", target.family)
	if target.family >= 0 and att.family >= 0 and att.family != target.family:
		Game.aggression(att.family, target.family, 4)


func shoot(att: Actor) -> void:
	fx_all("shoot", [att.key])
	var fwd := att.forward()
	var best: Actor = null
	var bd := 18.0 * W.M
	for a in actors.values():
		var ac := a as Actor
		if ac == att or ac.is_down() or ac.hidden_in_car or not ac.visible:
			continue
		var to := ac.position - att.position
		var d := to.length()
		if d < bd and fwd.dot(to / maxf(d, 0.01)) > cos(deg_to_rad(14.0)) and _clear_shot(att.position, ac.position):
			bd = d
			best = ac
	crime(att, 20.0, att.position, "shots fired", -1, 40.0 * W.M)
	if att.lot >= 0:
		var b := biz_at_lot(att.lot)
		if not b.is_empty():
			_scare_owner(att, b, "gun", 28.0)
	if best:
		best.hurt(randf_range(55.0, 80.0), att, true)
		if best.family >= 0 and att.family >= 0 and best.family != att.family:
			Game.aggression(att.family, best.family, 15)


func _clear_shot(a: Vector2, b: Vector2) -> bool:
	var q := PhysicsRayQueryParameters2D.create(a, b, 1)
	return get_world_2d().direct_space_state.intersect_ray(q).is_empty()


## Something illegal happened at `at`. Counts witnesses, adds heat, sends a cop after the
## perpetrator if one saw it and isn't on the family's payroll.
func crime(perp: Actor, severity: float, at: Vector2, what: String, victim_family: int = -1, radius: float = 14.0 * W.M) -> void:
	if perp == null or perp.family < 0:
		return
	var civ := 0
	var perp_lot := lot_at(at)
	for a in actors.values():
		var ac := a as Actor
		if ac == perp or ac.is_down():
			continue
		var d := ac.position.distance_to(at)
		# inside a shop, only the people in the shop see it; on the street, everyone around
		var sees := d < radius and (ac.lot == perp_lot or (perp_lot < 0 and ac.lot < 0) or d < 3.0 * W.M)
		if ac.kind in ["ped", "docker", "shop", "newsboy"] and sees:
			civ += 1
			ac.scare(at, 6.0)
	var cop_saw := false
	var cop_id := -1
	var wbiz := -1
	if perp_lot >= 0:
		var b := biz_at_lot(perp_lot)
		if not b.is_empty() and b["kind"] not in ["precinct", "warehouse", "club"]:
			wbiz = int(b["id"])
	else:
		var wd := radius * 0.5
		for b in Game.biz:
			if b["kind"] in ["precinct", "warehouse", "club"] or int(b["closed_until"]) >= Game.month:
				continue
			var dd := W.door(b).distance_to(at)
			if dd < wd:
				wd = dd
				wbiz = b["id"]
	for a in actors.values():
		var ac := a as Actor
		if ac.kind != "cop" or ac.is_down():
			continue
		var in_view := ac.position.distance_to(at) < radius + 6.0 * W.M and (ac.lot == perp_lot or perp_lot < 0 or ac.position.distance_to(at) < 5.0 * W.M)
		if in_view and not Game.cop_ignores(ac.ref_id, perp.family):
			cop_saw = true
			cop_id = ac.ref_id
			if ac.chase == null and perp.kind in ["boss", "crew"]:
				ac.chase = perp
				ac.chase_t = 30.0
	var who := ""
	if perp.kind == "boss":
		who = String(Game.player(int(perp.key.substr(1))).get("name", ""))
	elif perp.kind == "crew":
		who = String(Game.crew_by_id(perp.ref_id).get("name", ""))
	var h := Game.report_crime(perp.family, severity, civ, cop_saw, plan.district_at(at.x / W.M, at.y / W.M), what, wbiz, cop_id, who)
	var street := plan.street_name_at(at.x / W.M, at.y / W.M)
	if what == "shots fired" and not Game.news_this_month("SHOTS FIRED"):
		Game._log("SHOTS FIRED ON %s: %d people dive for cover, police hunt a man in a dark overcoat." % [street.to_upper(), civ])
	elif what == "cop killing":
		Game._log("PATROLMAN SLAIN ON %s. The Commissioner vows to clean out the gangs." % street.to_upper())
	if perp.kind == "boss":
		var peer := int(perp.key.substr(1))
		var msg := ""
		if civ == 0 and not cop_saw:
			msg = "Nobody saw that."
		else:
			msg = "%d saw it%s. Heat +%d." % [civ, ", and a cop" if cop_saw else "", int(round(h))]
		Net.to_peer(peer, "heat", [msg, h])


## Patrolmen who aren't paid go after anyone carrying a crate, and write up loaded trucks.
func _watch_contraband() -> void:
	for a in actors.values():
		var boss := a as Actor
		if boss.kind != "boss" or boss.family < 0:
			continue
		var truck: Vehicle = null
		if boss.hidden_in_car:
			for v in vehicles.values():
				if (v as Vehicle).driver == int(boss.key.substr(1)) and (v as Vehicle).load > 0:
					truck = v
		if not boss.carrying and truck == null:
			continue
		var at: Vector2 = truck.position if truck else boss.position
		for c in actors.values():
			var cop := c as Actor
			if cop.kind != "cop" or cop.is_down() or cop.chase != null or cop.key.begins_with("s"):
				continue
			if cop.position.distance_to(at) > 9.0 * W.M or Game.cop_ignores(cop.ref_id, boss.family):
				continue
			var key := "%s:%s" % [cop.key, boss.key]
			var now := Time.get_ticks_msec() / 1000.0
			if now - float(_spotted.get(key, -99.0)) < 30.0:
				continue
			_spotted[key] = now
			fx_all("whistle", [cop.key])
			var peer := int(boss.key.substr(1))
			if truck:
				Game.add_evidence(boss.family, "cop", "%s took down the plates of a loaded %s family truck" % [Game.cop_by_id(cop.ref_id).get("name", "A patrolman"), Game.fam(boss.family)["name"]], 8.0, {"cop": cop.ref_id})
				Net.to_peer(peer, "reply", ["A cop blew his whistle at the truck. He's got your plates.", false])
			else:
				cop.chase = boss
				cop.chase_t = 25.0
				Net.to_peer(peer, "reply", ["\"Hey, you! What's in the box?\" A cop is coming for you.", false])
			Game.mark_dirty()


func cop_caught(cop: Actor, target: Actor) -> void:
	match target.kind:
		"boss":
			var peer := int(target.key.substr(1))
			if arrests.has(peer):
				return
			arrests[peer] = cop.key
			Net.to_peer(peer, "arrest", [cop.key, Game.arrest_price(target.family)])
		"crew":
			Game.crew_arrested(target.ref_id)
			Game.notice.emit(target.family, "%s was picked up by the cops." % Game.crew_by_id(target.ref_id).get("name", "One of your men"), "bad")


func cop_gave_up(_cop: Actor, _target: Actor) -> void:
	pass


func on_knocked_down(a: Actor) -> void:
	if not Net.is_host():
		return
	if a.kind == "boss":
		var peer := int(a.key.substr(1))
		var p := Game.player(peer)
		if not p.is_empty() and int(p["wallet"]) > 0:
			var lost := int(p["wallet"]) / 2
			p["wallet"] -= lost
			drop_item("cash", a.position + Vector2(0.8, 0.3) * W.M, lost)
			Game.mark_dirty()
		if peer != Net.my_id():
			Net.to_peer(peer, "you_down", [a.down_t])
	fx_all("down", [a.key])


func on_killed(a: Actor, from: Actor) -> void:
	if not Net.is_host():
		return
	fx_all("die", [a.key])
	var street := plan.street_name_at(a.position.x / W.M, a.position.y / W.M)
	match a.kind:
		"crew":
			Game.crew_killed(a.ref_id, from.family if from else -1, street)
		"cop":
			if from:
				crime(from, 70.0, a.position, "cop killing", -1, 50.0 * W.M)
				for c in actors.values():
					var ac := c as Actor
					if ac.kind == "cop" and not ac.is_down():
						ac.chase = from
						ac.chase_t = 45.0
		"aiboss":
			if from:
				Rackets.don_killed(Game, a.family, from.family, street)
		"ped", "docker", "unionboss", "shop", "newsboy":
			if from:
				Game.report_crime(from.family, 25.0, 3, false, plan.district_at(a.position.x / W.M, a.position.y / W.M))
				Game._log("A MAN SHOT DEAD ON %s. Neighbours say they heard nothing." % street.to_upper())
	_corpses[a.key] = Time.get_ticks_msec() / 1000.0 + 25.0


func _cleanup_corpses() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for k in _corpses.keys():
		if now > float(_corpses[k]):
			_corpses.erase(k)
			var a := actor(k)
			if a:
				actors.erase(k)
				a.queue_free()
			if k.begins_with("n"):
				var n := _make_actor(k + "b")
				if n:
					n.sim = true
					n.place(W.pa(plan.nodes[randi() % plan.nodes.size()]))
			elif k == "u1":
				_spawn_union()
			elif k == "g1":
				_spawn_izzy()  # a cousin takes over the back room
			elif k == "z1":
				_spawn_smuggler()
			elif k.begins_with("k"):
				_spawn_cop(int(k.substr(1)), true)
			elif k.begins_with("w"):
				_spawn_newsboy(int(k.substr(1)))
			elif k.begins_with("d"):
				_spawn_docker(int(k.substr(1)))
			elif k.begins_with("s"):
				var bid := int(k.substr(1))
				var lay := layout_of_biz(bid)
				var s := _make_actor("s%d" % bid)
				if s and not lay.is_empty():
					s.sim = true
					s.place(lay["spots"].get("sergeant", lay["owner_spot"]), float(lay["owner_rot"]) + PI)


func _spawn_newsboy(k: int) -> void:
	var nb := _make_actor("w%d" % k)
	if nb == null:
		return
	nb.sim = true
	var node: Array = plan.nodes[(k * 29 + 7) % plan.nodes.size()]
	nb.place(W.pa(node), 0.0)


## A patrolman on his beat. A new one (after one was killed) walks out of the precinct.
func _spawn_cop(id: int, from_precinct: bool) -> void:
	var c := {}
	for c2 in Game.cops:
		if int(c2["id"]) == id:
			c = c2
	if c.is_empty():
		return
	var a := _make_actor("k%d" % id)
	if a == null:
		return
	a.sim = true
	if from_precinct:
		for b in Game.biz:
			if b["kind"] == "precinct":
				a.place(W.door(b), W.front_dir(float(b["yaw"])).angle())
				return
	var nodes := []
	for n in plan.nodes.size():
		var p: Array = plan.nodes[n]
		if plan.district_at(float(p[0]), float(p[1])) == c["district"]:
			nodes.append(n)
	a.place(W.pa(plan.nodes[nodes[randi() % nodes.size()] if not nodes.is_empty() else 0]))


## Izzy, in the back of the pawnshop.
func _spawn_izzy() -> void:
	for b in Game.biz:
		if b["kind"] == "pawnshop":
			var lay := interiors.layout_of(int(b["lot"]))
			var g := _make_actor("g1")
			if g == null or lay.is_empty():
				return
			g.sim = true
			var at: Vector2 = lay["spots"].get("dealer", (lay["back"] as Rect2).get_center() if (lay["back"] as Rect2).size != Vector2.ZERO else W.door(b))
			g.place(at, (lay["front"] as Vector2).angle())
			return


## The man on the night boat, at the middle pier.
func _spawn_smuggler() -> void:
	var tip: Array = plan.piers[1]["tip"]
	var smug := _make_actor("z1")
	if smug == null:
		return
	smug.sim = true
	smug.place(W.p(float(tip[0]) + 1.0, float(tip[1])), 0.0)

func drop_item(kind: String, at: Vector2, amount: int) -> void:
	if not Net.is_host():
		return
	var c := Crate.new()
	c.setup(_next_item, kind, amount)
	add_child(c)
	c.position = at + Vector2(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3)) * W.M
	items[_next_item] = c
	_next_item += 1


func resolve_order(a: Actor, order: Dictionary) -> void:
	var b := Game.biz_by_id(int(order["biz"]))
	if order.get("kind", "") == "take":
		# a player's man: lean on him, then make the offer
		var r := Rackets.crew_take(Game, a.family, int(order["biz"]), a.ref_id)
		if bool(r.get("smash", false)):
			fx_all("smash", [int(order["biz"])])
			crime(a, 8.0, a.position, "vandalism", int(b.get("protector", -1)))
		if bool(r.get("ok", false)):
			fx_all("cheer", [a.key])
			happened.emit("protected", {"biz": order["biz"], "family": a.family})
		var c := Game.crew_by_id(a.ref_id)
		if not c.is_empty():
			c["task"] = String(order.get("after", "follow"))
		for k in Game.players:
			if int(Game.players[k]["family"]) == a.family:
				Net.to_peer(int(k), "reply", [String(r.get("msg", "")), bool(r.get("ok", false))])
		Game.mark_dirty()
		return
	var r2 := Game.resolve_ai_order(order)
	if order["kind"] == "lean":
		fx_all("smash", [int(order["biz"])])
		crime(a, 10.0, a.position, "vandalism")
	if r2.get("ok", false):
		fx_all("cheer", [a.key])


func _on_ai_order(order: Dictionary) -> void:
	var a := actor("c%d" % int(order["crew"]))
	if a == null or a.is_down():
		Game.resolve_ai_order(order)
		return
	a.order = order
	a.path = []


func fx_all(kind: String, args: Array) -> void:
	Net.to_all("fx", [kind] + args)


## Words floating up over a spot, on every screen ("money" gold, "heat" orange, "fear" red, "info" cream).
func float_all(at: Vector2, text: String, kind: String = "money") -> void:
	fx_all("float", [at.x, at.y, text, kind])


# ------------------------------------------------------------------ requests (host)

func _on_request(peer: int, method: String, args: Array) -> void:
	if not Net.is_host():
		return
	var me := actor("p%d" % peer)
	var p := Game.player(peer)
	match method:
		"join_running":
			_seat_late_joiner(peer, args[0])
			return
	if me == null or p.is_empty():
		return
	if float(p["jailed_until"]) > 0.0 and method not in ["respond", "crew_task", "toggle", "save"]:
		Net.to_peer(peer, "reply", ["You're in a cell.", false])
		return
	var family := int(p["family"])
	var r := {}
	match method:
		"act":
			r = _act(peer, me, family, String(args[0]), int(args[1]), args[2] if args.size() > 2 else 0)
		"punch":
			_face(me, args)
			var t := _in_front(me, 1.4 * W.M, 70.0)
			if t:
				melee(me, t)
			else:
				fx_all("punch", [me.key])
				_smash_near(peer, me, family)
		"smash":
			r = _smash(peer, me, family, int(args[0]), int(args[1]))
		"shoot":
			if not Game.can_shoot(peer):
				r = {"ok": false, "msg": "No gun, or no bullets. Izzy sells both, in the back of the pawnshop."}
			else:
				Game.fired(peer, plan.district_at(me.position.x / W.M, me.position.y / W.M))
				_face(me, args)
				shoot(me)
		"sic":
			var t := actor(String(args[0]))
			me.attack_target_hint = t
			if t:
				get_tree().create_timer(12.0).timeout.connect(func() -> void:
					if is_instance_valid(me) and me.attack_target_hint == t:
						me.attack_target_hint = null)
				r = {"ok": true, "msg": "Your boys go for him."}
		"pickup":
			var id := int(args[0])
			if items.has(id):
				var c: Crate = items[id]
				if c.position.distance_to(me.position) < 2.0 * W.M:
					if c.kind == "cash":
						p["wallet"] += c.amount
						r = {"ok": true, "msg": "Picked up $%d." % c.amount}
						float_all(me.position, "+$%d" % c.amount, "money")
						Game.mark_dirty()
					elif not me.carrying:
						me.set_carry(true)
						Net.to_peer(peer, "carry", [true])
					else:
						return
					items.erase(id)
					c.queue_free()
		"drop":
			if me.carrying:
				me.set_carry(false)
				Net.to_peer(peer, "carry", [false])
				drop_item("crate", me.position + me.forward() * 0.7 * W.M, 1)
		"truck_load", "truck_unload":
			var v: Vehicle = vehicles.get(String(args[0]))
			if v and v.position.distance_to(me.position) < 4.0 * W.M:
				if v.family >= 0 and v.family != family and method == "truck_unload":
					Game.aggression(family, v.family, 10)
				if method == "truck_load" and v.family >= 0 and v.family != family:
					r = {"ok": false, "msg": "That's the %s family's truck. Load your own." % Game.fam(v.family).get("name", "")}
				elif method == "truck_load" and me.carrying and v.load < v.max_load():
					me.set_carry(false)
					Net.to_peer(peer, "carry", [false])
					v.set_load(v.load + 1)
				elif method == "truck_unload" and not me.carrying and v.load > 0:
					v.set_load(v.load - 1)
					me.set_carry(true)
					Net.to_peer(peer, "carry", [true])
		"enter":
			var v: Vehicle = vehicles.get(String(args[0]))
			if v and v.driver == 0 and not v.lane.is_empty() and absf(v.speed) < 4.0 * W.M and v.position.distance_to(me.position) < 4.0 * W.M and not me.carrying:
				# a car from the traffic: pull the driver out and take it
				v.lane = []
				v.speed = 0.0
				var drv := _make_actor("n%dx" % randi_range(100, 99999))
				if drv:
					drv.sim = true
					drv.place(v.position + v.forward().orthogonal() * -1.8 * W.M, v.yaw)
					drv.scare(me.position, 8.0)
				crime(me, 14.0 if v.kind == "police" else 9.0, me.position, "car theft")
				fx_all("punch", [me.key])
			if v and v.driver == 0 and v.lane.is_empty() and v.position.distance_to(me.position) < 4.0 * W.M and not me.carrying:
				if v.family >= 0 and v.family != family:
					crime(me, 8.0, me.position, "car theft", v.family)
					Game.aggression(family, v.family, 8)
				v.driver = peer
				v.sim = peer == Net.my_id()
				Net.to_peer(peer, "drive", [v.key])
		"exit":
			for v in vehicles.values():
				var ve := v as Vehicle
				if ve.driver == peer:
					ve.driver = 0
					ve.sim = true
					ve.speed = 0.0
					var side := ve.position + ve.forward().orthogonal() * -1.8 * W.M
					me.hidden_in_car = false
					me.visible = true
					Net.to_peer(peer, "exit", [side.x, side.y])
		"crew_task":
			r = _crew_task(peer, int(args[0]), String(args[1]), int(args[2]))
		"propose":
			r = Game.propose(family, int(args[0]), args[1])
		"respond":
			r = Game.respond(int(args[0]), family, bool(args[1]))
		"arrest":
			var choice := String(args[0])
			var cop := actor(String(arrests.get(peer, "")))
			arrests.erase(peer)
			if choice == "bribe":
				r = Game.act_bribe(peer)
				if not r["ok"]:
					choice = "quiet"
			if choice == "quiet":
				Game.jail_player(peer, 40.0)
				me.set_carry(false)
				var cell := _cell_spot()
				Net.to_peer(peer, "jailed", [cell.x, cell.y, 40.0])
				r = {"ok": false, "msg": "Booked at the 14th Precinct. 40 seconds in a cell. They took everything in your wallet."}
			elif choice == "run" and cop:
				cop.knock_down(2.5)  # the shove: a head start
				cop.chase = me
				cop.chase_t = 25.0
				Game.report_crime(family, 6.0, 0, true, plan.district_at(me.position.x / W.M, me.position.y / W.M))
				r = {"ok": false, "msg": "You shove him and run. He's after you."}
		"toggle":
			r = Game.act_toggle(peer, String(args[0]))
		"silence":
			var ev := Game.evidence_by_id(family, int(args[0]))
			var wb := Game.biz_by_id(int(ev.get("biz", -1)))
			if wb.is_empty() or me.lot != int(wb["lot"]):
				r = {"ok": false, "msg": "You have to see him in person, in his shop."}
			else:
				r = Game.act_silence(peer, int(args[0]), bool(args[1]))
				if bool(args[1]):
					fx_all("smash", [wb["id"]])
		"dump_gun":
			if _near_river(me.position):
				r = Game.act_dump_gun(peer)
			else:
				r = {"ok": false, "msg": "Walk to the end of a pier."}
		"burn_books":
			var hq := Game.biz_by_id(int(Game.fam(family)["hq"]))
			if me.lot == int(hq["lot"]):
				r = Game.act_burn_books(peer)
			else:
				r = {"ok": false, "msg": "The books are at your club."}
		"cleanup":
			r = Game.act_cleanup(peer, int(args[0]))
		"reach":
			r = Game.act_reach_rat(peer, int(args[0]))
		"gun":
			var g := actor("g1")
			if g and g.position.distance_to(me.position) < 3.0 * W.M:
				r = Game.act_buy_gun(peer, String(args[0]))
			else:
				r = {"ok": false, "msg": "Izzy isn't here."}
		"nation":
			r = _nation(family, args)
		"favor":
			var fb := Game.biz_by_id(int(args[0]))
			if fb.is_empty() or me.lot != int(fb["lot"]):
				r = {"ok": false, "msg": "You have to be in his shop."}
			else:
				r = Favors.accept(Game, peer, int(args[0]))
				if r["ok"]:
					_start_job(peer)
		"favor_deliver":
			var job: Dictionary = p.get("job", {})
			var tb := Game.biz_by_id(int(args[0]))
			if job.get("kind", "") == "parcel" and int(job.get("target_biz", -1)) == int(args[0]) and not tb.is_empty() and me.lot == int(tb["lot"]):
				_end_job(peer, Favors.complete(Game, peer))
		"favor_talk":
			var job2: Dictionary = p.get("job", {})
			var d := actor(String(args[0]))
			if job2.get("kind", "") == "debt" and d and d.position.distance_to(me.position) < 3.0 * W.M:
				var men := 0
				for ac in actors.values():
					if (ac as Actor).kind == "crew" and (ac as Actor).family == family and (ac as Actor).position.distance_to(me.position) < 6.0 * W.M:
						men += 1
				if men > 0 or int(Game.fam(family)["rep"]) >= 30 or randf() < 0.3:
					d.person.action("yes")
					_end_job(peer, Favors.complete(Game, peer))
				else:
					d.person.action("no")
					r = {"ok": false, "msg": "\"Or what?\" He laughs at you. Maybe he needs a slap."}
		"tutorial":
			p["tut"] = int(args[0])
			if args.size() > 1 and String(args[1]) == "gift" and not bool(p.get("tut_gift", false)):
				p["tut_gift"] = true
				# enough for the cheapest shop that pays you, and never less than $2,500
				var gift := 2500
				var cheapest := cheapest_front(family)
				if not cheapest.is_empty():
					gift = maxi(gift, int(cheapest["value"]) - int(Game.fam(family)["clean"]) + 200)
				Game.fam(family)["clean"] += gift
				r = {"ok": true, "msg": "Uncle Carmine put $%s in the Bank for you." % W.money(gift)}
			elif args.size() > 1 and String(args[1]) == "done" and not bool(p.get("tut_done", false)):
				p["tut_done"] = true
				Game.fam(family)["rep"] += 5
		"wait":
			# solo only: skip to nightfall, or to the morning (the month turns)
			if Game.players.size() == 1:
				if Game.clock < 0.55:
					Game.clock = 0.56
					r = {"ok": true, "msg": "You wait at the club until dark."}
				else:
					Game.clock = 0.999
					r = {"ok": true, "msg": "You sleep on the couch in the office. Morning."}
		"save":
			if peer == Net.my_id():
				var path := Game.save_campaign()
				r = {"ok": path != "", "msg": "Game saved." if path != "" else "Couldn't save."}
	if not r.is_empty() and String(r.get("msg", "")) != "":
		Net.to_peer(peer, "reply", [r["msg"], r["ok"]])
	Game.mark_dirty()


func _crew_task(peer: int, crew_id: int, task: String, target: int) -> Dictionary:
	if task != "take":
		return Game.act_crew_task(peer, crew_id, task, target)
	var p := Game.player(peer)
	var c := Game.crew_by_id(crew_id)
	var b := Game.biz_by_id(target)
	if c.is_empty() or b.is_empty() or int(c["family"]) != int(p["family"]) or c["state"] != "free":
		return {"ok": false, "msg": ""}
	if int(b["protector"]) == int(p["family"]) or int(b["owned_by"]) >= 0 or b["kind"] in ["precinct", "club", "warehouse"]:
		return {"ok": false, "msg": "Nothing to take there."}
	var a := actor("c%d" % crew_id)
	if a == null:
		return {"ok": false, "msg": "%s isn't on the street." % c["name"]}
	var after := String(c["task"]) if String(c["task"]) not in ["take"] else "follow"
	c["task"] = "take"
	c["leader"] = str(peer)
	a.order = {"family": int(p["family"]), "crew": crew_id, "kind": "take", "biz": target, "after": after}
	a.path = []
	Game.mark_dirty()
	return {"ok": true, "msg": "%s goes to see %s at %s." % [c["name"], b["owner_name"], b["name"]]}


func _nation(family: int, args: Array) -> Dictionary:
	var op := String(args[0])
	match op:
		"send": return Syndicate.send_men(Game, family, String(args[1]), int(args[2]), int(args[3]), int(args[4]))
		"police": return Syndicate.bribe_police(Game, family, String(args[1]))
		"route": return Syndicate.bribe_route(Game, family, String(args[1]))
		"convoy": return Syndicate.set_convoy(Game, family, String(args[1]), int(args[2]))
		"ambush": return Syndicate.set_ambush(Game, family, String(args[1]), int(args[2]))
		"hit": return Syndicate.order_hit(Game, family, String(args[1]), int(args[2]))
		"warehouse": return Syndicate.buy_warehouse(Game, family, String(args[1]))
		"plant": return Syndicate.buy_plant(Game, family, String(args[1]))
		"union":
			if String(args[1]) == "nyc":
				return {"ok": false, "msg": "The New York docks belong to %s's local. See him on the quay, in person." % Game.UNION_BOSS}
			return Syndicate.pay_union(Game, family, String(args[1]))
		"yard": return Syndicate.bribe_yard(Game, family, String(args[1]))
		"freight": return Syndicate.set_freight(Game, family, String(args[1]), String(args[2]), String(args[3]), int(args[4]))
		"recall":
			var c: Dictionary = Game.nation["cities"][String(args[1])]
			var men := int(c["men"].get(str(family), 0))
			c["men"][str(family)] = 0
			var cap := int(c["capo"].get(str(family), -1))
			if cap >= 0:
				var cm := Game.crew_by_id(cap)
				if not cm.is_empty() and cm["state"] == "away":
					cm["state"] = "free"
					cm["task"] = "idle"
				c["capo"].erase(str(family))
			Game.fam(family)["arsenal"]["pistol"] += int(c["guns"].get(str(family), 0))
			c["guns"][str(family)] = 0
			Game.mark_dirty()
			_sync_spawns()
			return {"ok": true, "msg": "%d men come home from %s." % [men, Syndicate.city_def(String(args[1]))["name"]]}
	return {"ok": false, "msg": ""}


func _near_river(p: Vector2) -> bool:
	for pier in plan.piers:
		var tip: Array = pier["tip"]
		if W.p(float(tip[0]) + 2.0, float(tip[1])).distance_to(p) < 4.0 * W.M:
			return true
	return p.x > (plan.water_x - 1.5) * W.M and p.x < (plan.water_x + 0.5) * W.M


func _precinct() -> Dictionary:
	for b in Game.biz:
		if b["kind"] == "precinct":
			return b
	return {}


## Inside a cell at the precinct, or its door.
func _cell_spot() -> Vector2:
	var pre := _precinct()
	if pre.is_empty():
		return Vector2.ZERO
	var lay := layout_of_biz(int(pre["id"]))
	var cells: Array = lay["spots"].get("cells", []) if not lay.is_empty() else []
	if not cells.is_empty():
		return (cells[0] as Rect2).get_center()
	return W.door(pre)


func _in_front(me: Actor, dist: float, deg: float) -> Actor:
	var fwd := me.forward()
	var best: Actor = null
	var bd := dist
	for a in actors.values():
		var ac := a as Actor
		if ac == me or ac.is_down() or ac.hidden_in_car or not ac.visible or ac.kind == "smuggler":
			continue
		var to := ac.position - me.position
		var d := to.length()
		if d < bd and fwd.dot(to / maxf(d, 0.01)) > cos(deg_to_rad(deg)):
			bd = d
			best = ac
	return best


## F with nobody in front of you, next to something breakable in a shop: smash it.
func _smash_near(peer: int, me: Actor, family: int) -> void:
	if me.lot < 0:
		# the front window, from the sidewalk
		for b in Game.biz:
			if W.door(b).distance_to(me.position) < 1.6 * W.M:
				var lay := layout_of_biz(int(b["id"]))
				if lay.is_empty():
					continue
				for it in lay["items"]:
					if it["type"] == "window" and not (b.get("broken", []) as Array).has(int(it["id"])):
						_smash(peer, me, family, int(b["id"]), int(it["id"]))
						return
		return
	var b := biz_at_lot(me.lot)
	if b.is_empty():
		return
	var lay := layout_of_biz(int(b["id"]))
	var best := -1
	var bd := 1.5 * W.M
	for it in lay["items"]:
		if not bool(it["breakable"]) or (b.get("broken", []) as Array).has(int(it["id"])):
			continue
		var r: Rect2 = it["rect"]
		var d := _dist_to_rect(me.position + me.forward() * 0.3 * W.M, r)
		if d < bd:
			bd = d
			best = int(it["id"])
	if best >= 0:
		_smash(peer, me, family, int(b["id"]), best)


func _dist_to_rect(p: Vector2, r: Rect2) -> float:
	var q := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
	return p.distance_to(q)


func _smash(peer: int, me: Actor, family: int, biz_id: int, item_id: int) -> Dictionary:
	var b := Game.biz_by_id(biz_id)
	var lay := layout_of_biz(biz_id)
	if b.is_empty() or lay.is_empty() or item_id < 0 or item_id >= (lay["items"] as Array).size():
		return {}
	var it: Dictionary = lay["items"][item_id]
	if not bool(it["breakable"]) or _dist_to_rect(me.position, it["rect"]) > 1.8 * W.M:
		return {}
	var broken: Array = b.get("broken", [])
	if broken.has(item_id):
		return {}
	broken.append(item_id)
	b["broken"] = broken
	fx_all("smash", [biz_id, item_id])
	var what := "vandalism"
	crime(me, 6.0 + float(it.get("value", 20)) * 0.15, me.position, what, int(b["protector"]))
	if int(b["protector"]) >= 0 and int(b["protector"]) != family:
		Game.aggression(family, int(b["protector"]), 6)
	_scare_owner(me, b, "glass", float(it.get("value", 20)) * 0.9)
	happened.emit("smashed", {"biz": biz_id, "item": item_id, "peer": peer})
	Game.mark_dirty()
	return {}


## A player's action on a business or a person. Validates that they're standing there.
func _act(peer: int, me: Actor, family: int, what: String, target: int, extra: Variant) -> Dictionary:
	var b := Game.biz_by_id(target)
	var in_shop := not b.is_empty() and (me.lot == int(b["lot"]) or W.door(b).distance_to(me.position) < 2.5 * W.M)
	match what:
		"pitch", "lean", "collect", "buy", "speakeasy", "deliver", "bank_in", "bank_out", "bank_out_big", "captain", "wh_load", "wh_store", "wh_steal", "rob", "safe_rob":
			if not in_shop:
				return {"ok": false, "msg": "You need to be in the shop."}
		"union_pay", "union_drop":
			var u := actor("u1")
			if u == null or u.is_down() or u.position.distance_to(me.position) > 4.0 * W.M:
				return {"ok": false, "msg": "%s isn't here." % Game.UNION_BOSS}
	match what:
		"pitch":
			var ids := _crew_near(family, int(b["lot"]))
			var r := Rackets.pitch(Game, family, target, ids)
			if r["ok"]:
				fx_all("cheer", ["s%d" % target])
				happened.emit("protected", {"biz": target, "family": family})
			else:
				happened.emit("refused", {"biz": target})
			return r
		"lean":
			var r := Game.act_lean(family, target)
			fx_all("smash", [target, -1])
			crime(me, 10.0, me.position, "vandalism", b["protector"])
			return r
		"collect":
			var w0 := int(Game.player(peer)["wallet"])
			var r := Game.act_collect(peer, target)
			if r["ok"]:
				happened.emit("collected", {"biz": target})
				fx_all("cash", [me.key])
				float_all(me.position, "+$%d" % (int(Game.player(peer)["wallet"]) - w0), "money")
			return r
		"buy":
			var r := Game.act_buy(family, target)
			if r["ok"]:
				happened.emit("bought", {"biz": target})
			return r
		"speakeasy":
			var r := Game.act_open_speakeasy(peer, target)
			if r["ok"]:
				happened.emit("speakeasy", {"biz": target})
			return r
		"deliver":
			var n := 0
			if me.carrying:
				me.set_carry(false)
				Net.to_peer(peer, "carry", [false])
				n = 1
			for v in vehicles.values():
				var ve := v as Vehicle
				if (ve.family == family or ve.family < 0) and ve.load > 0 and ve.position.distance_to(W.door(b)) < 9.0 * W.M:
					n += ve.load
					ve.set_load(0)
			if n == 0:
				return {"ok": false, "msg": "Bring crates: carry one in, or park the truck by the door."}
			happened.emit("delivered", {"biz": target, "n": n})
			return Game.act_deliver(peer, target, n)
		"rob":
			var w1 := int(Game.player(peer)["wallet"])
			var rr := Rackets.rob_register(Game, self, peer, me, target)
			if rr["ok"]:
				float_all(me.position, "+$%d" % (int(Game.player(peer)["wallet"]) - w1), "money")
			return rr
		"safe_rob":
			return Rackets.rob_safe(Game, self, peer, me, target)
		"wh_load", "wh_store", "wh_steal":
			return _warehouse_act(peer, me, family, what, b)
		"union_pay":
			var r := Syndicate.pay_union(Game, family, "nyc")
			if r["ok"]:
				fx_all("cheer", ["u1"])
			return r
		"union_drop":
			return Syndicate.sabotage(Game, family, "nyc", target)
		"bank_in":
			var r := Game.act_bank(peer, true)
			fx_all("cash", [me.key])
			return r
		"bank_out":
			return Game.act_bank(peer, false)
		"bank_out_big":
			var f := Game.fam(family)
			var take := mini(2000, int(f["dirty"]))
			f["dirty"] -= take
			p_wallet(peer, take)
			return {"ok": true, "msg": "You take $%s from the safe." % W.money(take)}
		"captain":
			return Game.act_captain(peer, String(extra))
		"hire":
			var ra := actor("r%d" % target)
			if ra == null or ra.position.distance_to(me.position) > 3.0 * W.M:
				return {"ok": false, "msg": "He's not here."}
			var r := Game.act_hire(peer, target)
			if r["ok"]:
				happened.emit("hired", {})
			return r
		"cop":
			var ca := actor("k%d" % target)
			if ca == null or ca.position.distance_to(me.position) > 3.0 * W.M:
				return {"ok": false, "msg": ""}
			var r := Game.act_payroll_cop(peer, target)
			if r["ok"]:
				happened.emit("bribed_cop", {})
			return r
		"crates":
			var z := actor("z1")
			if z == null or not _boat_here() or z.position.distance_to(me.position) > 4.0 * W.M:
				return {"ok": false, "msg": "No boat tonight."}
			var r := Game.act_buy_crates(peer, int(extra))
			if r["ok"]:
				var n := int(String(r["msg"]).split(" ")[0])
				for k in n:
					drop_item("crate", z.position + Vector2(-2.0 - (k % 3) * 0.8, -1.2 + (k / 3) * 0.8) * W.M, 1)
				happened.emit("crates", {"n": n})
			return r
	return {"ok": false, "msg": ""}


func p_wallet(peer: int, amount: int) -> void:
	var p := Game.player(peer)
	if not p.is_empty():
		p["wallet"] = int(p["wallet"]) + amount
		Game.mark_dirty()


## E in a warehouse on the quay: load your parked truck from your stock, put the truck's crates
## into the warehouse, or help yourself to a rival's crate.
func _warehouse_act(peer: int, me: Actor, family: int, what: String, b: Dictionary) -> Dictionary:
	if b["kind"] != "warehouse":
		return {"ok": false, "msg": ""}
	var owner := int(b["owned_by"])
	var door := W.door(b)
	match what:
		"wh_load", "wh_store":
			if owner != family:
				return {"ok": false, "msg": "This isn't your warehouse."}
			var truck := parked_truck(family, door, 10.0 * W.M)
			if what == "wh_load":
				if truck == null:
					return {"ok": false, "msg": "Park the family truck outside the door first."}
				var room := truck.max_load() - truck.load
				if room <= 0:
					return {"ok": false, "msg": "The truck is full: %d crates. Drive them to a speakeasy." % truck.load}
				var got := Syndicate.take_stock(Game.nation, "nyc", family, room)
				if got <= 0:
					return {"ok": false, "msg": "The warehouse is empty. Boats and convoys landing in New York fill it (J: the country)."}
				truck.set_load(truck.load + got)
				Game.mark_dirty()
				fx_all("cheer", [me.key])
				return {"ok": true, "msg": "The boys load %d crates onto the truck. %d left inside." % [got, Syndicate.stock(Game.nation, "nyc", family)]}
			var n := 0
			if me.carrying:
				me.set_carry(false)
				Net.to_peer(peer, "carry", [false])
				n += Syndicate.put_stock(Game.nation, "nyc", family, 1)
			if truck and truck.load > 0:
				var put := Syndicate.put_stock(Game.nation, "nyc", family, truck.load)
				truck.set_load(truck.load - put)
				n += put
			if n == 0:
				return {"ok": false, "msg": "Nothing to put away. Carry a crate in, or park a loaded truck outside."}
			Game.mark_dirty()
			return {"ok": true, "msg": "%d crates stacked inside (%d in all)." % [n, Syndicate.stock(Game.nation, "nyc", family)]}
		"wh_steal":
			if owner < 0 or owner == family:
				return {"ok": false, "msg": ""}
			if me.carrying:
				return {"ok": false, "msg": "Your hands are full."}
			if Syndicate.take_stock(Game.nation, "nyc", owner, 1) <= 0:
				return {"ok": false, "msg": "Nothing here worth taking."}
			me.set_carry(true)
			Net.to_peer(peer, "carry", [true])
			crime(me, 6.0, me.position, "theft", owner)
			Game.aggression(family, owner, 8)
			Game.notice.emit(owner, "Somebody from the %s family walked off with a crate from your warehouse." % Game.fam(family)["name"], "warn")
			Game.mark_dirty()
			return {"ok": true, "msg": "You lift a crate off the %s family's pallet. Their watchman saw your face." % Game.fam(owner)["name"]}
	return {"ok": false, "msg": ""}


func _seat_late_joiner(peer: int, info: Dictionary) -> void:
	var pname := String(info.get("name", "Player"))
	for k in Game.players.keys():
		var p: Dictionary = Game.players[k]
		if p["name"] == pname and not Net.roster.has(int(k)):
			Game.players.erase(k)
			Game.players[str(peer)] = p
			var old := actor("p" + k)
			if old:
				actors.erase("p" + k)
				old.queue_free()
			_finish_join(peer)
			return
	var fam := int(info.get("join", -1))
	if fam < 0 or fam >= Game.families.size():
		for f in Game.families:
			if f["ai"]:
				fam = f["id"]
				break
	if fam < 0:
		fam = 0
	var ab := actor("a%d" % fam)
	if ab:
		actors.erase(ab.key)
		ab.queue_free()
	Game.add_player(peer, pname, fam)
	Game.notice.emit(-1, "%s takes over the %s family." % [pname, Game.fam(fam)["name"]], "deal")
	_finish_join(peer)


func _finish_join(peer: int) -> void:
	Game.mark_dirty()
	Net.send_state(Game.get_state(), peer)
	Net.start_peer(peer)
	_sync_spawns()


# ------------------------------------------------------------------ events (everyone)

func _on_event(ev_name: String, args: Array) -> void:
	match ev_name:
		"fx":
			_fx(args)
		"reply":
			hud.toast(String(args[0]), "good" if bool(args[1]) else "info")
		"heat":
			hud.toast(String(args[0]), "warn" if float(args[1]) > 0.5 else "info")
			if local_actor and float(args[1]) >= 1.0:
				floats.pop(local_actor.position, "Heat +%d" % int(round(float(args[1]))), Color("ff9a4a"), 20)
		"notice":
			var fam := int(args[0])
			var mine := int(Game.player(Net.my_id()).get("family", -2))
			if fam == -1 or fam == mine:
				hud.toast(String(args[1]), String(args[2]))
		"raid":
			var mine3 := int(Game.player(Net.my_id()).get("family", -2))
			if int(args[0]) == mine3:
				cam.shake(0.5)
				audio.ui("whistle", -2.0)
		"job_done":
			audio.ui("coins_pay", -6.0)
			happened.emit("favor_done", {})
		"shake_deal":
			var mine2 := int(Game.player(Net.my_id()).get("family", -2))
			if int(args[1]) == mine2:
				happened.emit("protected", {"biz": int(args[0]), "family": mine2})
		"you_down":
			if local_actor:
				if local_vehicle:
					_leave_vehicle_local()
				local_actor.knock_down(float(args[0]))
		"carry":
			if local_actor:
				local_actor.set_carry(bool(args[0]))
		"drive":
			var v: Vehicle = vehicles.get(String(args[0]))
			if v and local_actor:
				local_vehicle = v
				v.sim = true
				v.driver = Net.my_id()
				local_actor.hidden_in_car = true
				local_actor.visible = false
				cam.target = v
				audio.engine(true)
				happened.emit("drove", {})
		"exit":
			_leave_vehicle_local(Vector2(float(args[0]), float(args[1])))
		"arrest":
			hud.show_arrest(String(args[0]), int(args[1]))
		"jailed":
			if local_vehicle:
				_leave_vehicle_local()
			if local_actor:
				local_actor.set_carry(false)
				local_actor.place(Vector2(float(args[0]), float(args[1])))
			hud.jail_until = Time.get_ticks_msec() / 1000.0 + float(args[2])
		"weather":
			weather = String(args[0])
		"newspaper":
			hud.show_newspaper(int(args[0]))
		"over":
			hud.show_final()
		"left":
			var a := actor("p%d" % int(args[0]))
			if Net.is_host():
				# his car is free again
				for v in vehicles.values():
					var ve := v as Vehicle
					if ve.driver == int(args[0]):
						ve.driver = 0
						ve.speed = 0.0
						ve.sim = true
			if a and Net.is_host():
				actors.erase(a.key)
				a.queue_free()


func _leave_vehicle_local(at: Vector2 = Vector2.INF) -> void:
	if local_vehicle == null:
		return
	var v := local_vehicle
	local_vehicle = null
	v.driver = 0
	v.sim = Net.is_host()
	v.speed = 0.0
	if at == Vector2.INF:
		at = v.position + v.forward().orthogonal() * -1.8 * W.M
	if local_actor:
		local_actor.hidden_in_car = false
		local_actor.visible = true
		local_actor.place(at, v.yaw)
		cam.target = local_actor
	audio.engine(false)


func _fx(args: Array) -> void:
	var kind := String(args[0])
	match kind:
		"hit", "punch", "shoot", "down", "die", "cheer", "whistle", "cash":
			var a := actor(String(args[1])) if args.size() > 1 else null
			if a == null:
				return
			match kind:
				"hit": a.person.action("hit")
				"punch": a.person.action("punch")
				"shoot":
					a.person.action("shoot")
					lighting.flash(a.position + a.forward() * 0.7 * W.M, 5.0 * W.M, Color(1.0, 0.85, 0.5), 0.1)
					if local_actor and a.position.distance_to(local_actor.position) < 25.0 * W.M:
						cam.shake(0.6)
				"cheer": a.person.action("yes")
			audio.at(kind, a.position)
		"smash":
			var b := Game.biz_by_id(int(args[1]))
			if not b.is_empty():
				var lay := layout_of_biz(int(b["id"]))
				var at := W.door(b)
				var item := int(args[2]) if args.size() > 2 else -1
				if not lay.is_empty() and item >= 0 and item < (lay["items"] as Array).size():
					at = (lay["items"][item]["rect"] as Rect2).get_center()
				audio.at("smash", at)
				var sk := actor("s%d" % b["id"])
				if sk:
					sk.person.action("hit")
				if local_actor and at.distance_to(local_actor.position) < 12.0 * W.M:
					cam.shake(0.35)
				interiors.update_from_game()
		"float":
			var col: Color = {"money": Pal.GOLD2, "heat": Color("ff9a4a"), "fear": Pal.UI_RED, "info": Pal.INK, "good": Pal.UI_GREEN}.get(String(args[4]), Pal.INK)
			floats.pop(Vector2(float(args[1]), float(args[2])), String(args[3]), col)
		"yes":
			pass


func _on_game_notice(family: int, text: String, kind: String) -> void:
	if Net.is_host():
		Net.to_all("notice", [family, text, kind])


func _on_state_changed() -> void:
	fronts.update_owners()
	roofs.update_owners()
	interiors.update_from_game()
	_update_stacks()
	if hud:
		hud.refresh()


# ------------------------------------------------------------------ multiplayer smoke test

func _mptest() -> void:
	var t := Timer.new()
	t.wait_time = 1.0
	t.autostart = true
	add_child(t)
	var ticks := [0]
	t.timeout.connect(func() -> void:
		ticks[0] += 1
		if ticks[0] == 2 and local_actor:
			controller.auto_move = Vector2(1, 0)
		if ticks[0] == 4:
			controller.auto_move = Vector2.ZERO
			Net.to_host("punch", [])
			Net.to_host("nation", ["send", "det", 2, 0, -1])
		if ticks[0] == 9:
			var fam := int(Game.player(Net.my_id()).get("family", -1))
			print("MPTEST %s id=%d players=%d family=%s actors=%d vehicles=%d month=%d local=%s chicago_det=%s" % [
				"HOST" if Net.is_host() else "CLIENT", Net.my_id(), Game.players.size(), Game.fam(fam).get("name", "?"),
				actors.size(), vehicles.size(), Game.month, str(local_actor.position if local_actor else "none"),
				str(Game.nation["cities"]["det"]["influence"])])
		if ticks[0] == 11:
			get_tree().quit())
