extends Control
## Bottom-right: the streets around you, north up, about 50 m each way, in a rounded brass frame.
## Blocks and buildings from the plan; every business a dot in the colour of the family it pays or
## belongs to (a square when a family owns it), a gold "!" where a shopkeeper needs a favor; you
## (an arrow), your men, other families' men, cops close by, the family truck, your goal and your
## waypoint (pinned to the rim when they're further), and the rum boat at the pier at night.
## The street you're on is written above it. Click it for the city map.

signal clicked

const UI := preload("res://scripts/ui/hud/hud_ui.gd")
const SIZE := 236.0
const RADIUS_M := 50.0
const FRAME := 8.0
const PLATE := 28.0
const GAP := 16.0

var world: Node
var target := Vector2.INF
var waypoint := Vector2.INF
var hold := false
var _a := 1.0
var _hover := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	size = Vector2(SIZE, SIZE + PLATE + GAP)
	mouse_entered.connect(func() -> void: _hover = true)
	mouse_exited.connect(func() -> void: _hover = false)


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		clicked.emit()


func _process(delta: float) -> void:
	_a = move_toward(_a, 0.0 if hold else 1.0, delta * 5.0)
	visible = _a > 0.01
	if visible:
		queue_redraw()


func _map_rect() -> Rect2:
	return Rect2(Vector2(FRAME, PLATE + GAP + FRAME), Vector2(SIZE - FRAME * 2.0, SIZE - FRAME * 2.0))


func _me() -> Node2D:
	if world == null or not is_instance_valid(world):
		return null
	var lv: Variant = world.get("local_vehicle")
	if lv is Node2D and is_instance_valid(lv):
		return lv as Node2D
	var la: Variant = world.get("local_actor")
	if la is Node2D and is_instance_valid(la):
		return la as Node2D
	return null


func _draw() -> void:
	var plan: CityPlan = Game.plan
	var me := _me()
	var mr := _map_rect()
	var outer := Rect2(Vector2(0, PLATE + GAP), Vector2(SIZE, SIZE))
	var a := _a
	UI.soft_shadow(self, outer, 18.0, a)
	if plan == null or me == null:
		UI.grad_rrect(self, outer, 18.0, UI.with_a(UI.BRASS, a), UI.with_a(UI.BRASS_DK, a))
		return
	var center_m := me.position / W.M
	var sc := mr.size.x * 0.5 / RADIUS_M        # px per metre
	var c := mr.get_center()
	var night := clampf(float(world.call("night_level")) if world.has_method("night_level") else 0.0, 0.0, 1.0)
	# beyond the edge of the plan: dark, cross-hatched; inside it: the streets
	Draw.rect(self, mr, UI.with_a(Color("18171a"), a))
	var br0 := plan.bounds
	var inside_r := _clip(Rect2(c + (br0.position - center_m) * sc, br0.size * sc), mr)
	if inside_r.size.x < mr.size.x - 1.0 or inside_r.size.y < mr.size.y - 1.0:
		# diagonal hatching, each line clipped to the map square
		var hx := mr.position.x - fmod(center_m.x * sc, 12.0)
		var hh := mr.size.y
		while hx < mr.end.x + hh:
			var t0 := maxf(0.0, hx - mr.end.x)
			var t1 := minf(hh, hx - mr.position.x)
			if t1 > t0:
				draw_line(Vector2(hx - t0, mr.position.y + t0), Vector2(hx - t1, mr.position.y + t1), UI.with_a(Color("2a282c"), a), 1.0)
			hx += 12.0
	if inside_r.size.x > 0.0:
		Draw.rect(self, inside_r, UI.with_a(Color("34363b").lerp(Color("1c2030"), night * 0.5), a))
	# the river
	if plan.water_x > 0.0:
		var wx := c.x + (plan.water_x - center_m.x) * sc
		if wx < mr.end.x:
			Draw.rect(self, _clip(Rect2(Vector2(wx, mr.position.y), Vector2(mr.end.x - wx, mr.size.y)), mr), UI.with_a(Color("1f3a4c").lerp(Color("0f1a26"), night * 0.6), a))
	# the quay and piers
	var q: Array = plan.quay_rect
	_rect_m(Rect2(Vector2(float(q[0]), float(q[1])), Vector2(float(q[2]) - float(q[0]), float(q[3]) - float(q[1]))), center_m, sc, c, mr, UI.with_a(Color("5a4a3a"), a))
	for pier in plan.piers:
		var pd: Dictionary = pier
		_rect_m(Rect2(Vector2(float(pd["x0"]), float(pd["z0"])), Vector2(float(pd["x1"]) - float(pd["x0"]), float(pd["z1"]) - float(pd["z0"]))), center_m, sc, c, mr, UI.with_a(Color("6b5642"), a))
	# blocks (sidewalks) and the buildings on them
	var view := Rect2(center_m - Vector2(RADIUS_M, RADIUS_M) * 1.1, Vector2(RADIUS_M, RADIUS_M) * 2.2)
	for blk in plan.blocks:
		var br: Array = blk["rect"]
		var rm := Rect2(Vector2(float(br[0]), float(br[1])), Vector2(float(br[2]) - float(br[0]), float(br[3]) - float(br[1])))
		if rm.intersects(view):
			_rect_m(rm, center_m, sc, c, mr, UI.with_a(Color("8f877a").darkened(0.35 + night * 0.25), a))
	var inside := int(world.get("inside_lot")) if world.get("inside_lot") != null else -1
	for lot in plan.lots:
		var ld: Dictionary = lot
		var lr_px := W.lot_rect(ld)
		var lr := Rect2(lr_px.position / W.M, lr_px.size / W.M)
		if not lr.intersects(view):
			continue
		var kind := String(ld["kind"])
		var col := Color("4a403a")
		if kind == "courtyard":
			col = Color("4c4a38")
		elif bool(ld.get("shop", false)) or kind in ["club", "poolhall", "precinct", "warehouse"]:
			col = Color("5a4a40")
		if int(ld["id"]) == inside:
			col = Color("7a6450")
		_rect_m(lr.grow(-0.4), center_m, sc, c, mr, UI.with_a(col.darkened(night * 0.3), a))
	# businesses: who they pay
	var mine := UI.my_family()
	for b in Game.biz:
		var bd: Dictionary = b
		var p := c + (W.door(bd) / W.M - center_m) * sc
		if not mr.grow(-4.0).has_point(p):
			continue
		var own := int(bd.get("owned_by", -1))
		var prot := int(bd.get("protector", -1))
		var kind2 := String(bd["kind"])
		if kind2 == "precinct":
			Draw.circle(self, p, 5.5, UI.with_a(Color("0e1426"), a))
			UI.icon(self, "star", p, 10.0, UI.with_a(Color("8ab0ff"), a))
			continue
		var fid := own if own >= 0 else prot
		if fid >= 0:
			var fc := UI.fam_col(fid)
			if kind2 == "club":
				Draw.circle(self, p, 6.5, UI.with_a(Color(0, 0, 0, 0.6), a))
				UI.icon(self, "star", p, 12.0, UI.with_a(fc.lightened(0.2), a))
			elif own >= 0:
				Draw.rect(self, Rect2(p - Vector2(4.5, 4.5), Vector2(9, 9)), UI.with_a(Color(0, 0, 0, 0.6), a))
				Draw.rect(self, Rect2(p - Vector2(3.5, 3.5), Vector2(7, 7)), UI.with_a(fc.lightened(0.15), a))
			else:
				Draw.circle(self, p, 4.8, UI.with_a(Color(0, 0, 0, 0.6), a))
				Draw.circle(self, p, 3.6, UI.with_a(fc.lightened(0.15), a))
			if fid == mine:
				draw_arc(p, 6.0, 0, TAU, 16, UI.with_a(Color.WHITE, 0.7 * a), 1.0, true)
		else:
			Draw.circle(self, p, 4.0, UI.with_a(Color(0, 0, 0, 0.5), a))
			draw_arc(p, 3.0, 0, TAU, 14, UI.with_a(UI.CREAM, 0.75 * a), 1.3, true)
	# favors: a gold "!" (after the dots, so it sits on top)
	var bob := sin(Time.get_ticks_msec() / 260.0) * 1.5
	for b in Game.biz:
		var bd2: Dictionary = b
		if not bd2.has("favor"):
			continue
		var p2 := c + (W.door(bd2) / W.M - center_m) * sc + Vector2(0, -9.0 + bob)
		if not mr.grow(-8.0).has_point(p2):
			continue
		Draw.circle(self, p2 + Vector2(1, 1.5), 7.0, UI.with_a(Color(0, 0, 0, 0.5), a))
		Draw.circle(self, p2, 7.0, UI.with_a(UI.GOLD2, a))
		var cond := UI.font("cond")
		UI.text_c(self, p2.x, UI.mid(cond, 12, p2.y), "!", cond, 12, UI.with_a(UI.PAPER_INK, a))
	# the boat, at night
	if Game.clock > 0.55 and Game.clock < 0.97 and int(Game.boat.get("crates", 0)) > 0 and plan.piers.size() > 1:
		var tip: Array = plan.piers[1]["tip"]
		var bp := c + (Vector2(float(tip[0]) + 7.0, float(tip[1])) - center_m) * sc
		_pin(bp, mr, "boat", Color("9fd0ff"), a)
	# the family truck
	var vehicles: Variant = world.get("vehicles")
	if vehicles is Dictionary and mine >= 0:
		var tr: Variant = (vehicles as Dictionary).get("t%d" % mine)
		if tr is Node2D and is_instance_valid(tr) and tr != me:
			var tp := c + ((tr as Node2D).position / W.M - center_m) * sc
			if mr.grow(-5.0).has_point(tp):
				Draw.circle(self, tp, 6.0, UI.with_a(Color(0, 0, 0, 0.55), a))
				UI.icon(self, "truck", tp, 11.0, UI.with_a(UI.fam_col(mine).lightened(0.35), a))
	# people
	var acts: Variant = world.get("actors")
	if acts is Dictionary:
		for v in (acts as Dictionary).values():
			if not (v is Actor) or not is_instance_valid(v):
				continue
			var ac := v as Actor
			if ac == me or ac.dead or ac.hidden_in_car or not ac.visible:
				continue
			var ap := c + (ac.position / W.M - center_m) * sc
			if not mr.grow(-3.0).has_point(ap):
				continue
			var k := ac.kind
			var down := ac.is_down()
			var fa := a * (0.5 if down else 1.0)
			if k == "cop" and not ac.key.begins_with("s"):
				Draw.circle(self, ap, 3.8, UI.with_a(Color("0c1020"), fa))
				Draw.circle(self, ap, 2.8, UI.with_a(Color("6f9cff"), fa))
			elif k == "fed":
				Draw.circle(self, ap, 3.8, UI.with_a(Color("0c1020"), fa))
				Draw.circle(self, ap, 2.8, UI.with_a(Color("c0c4cc"), fa))
			elif k in ["crew", "boss", "aiboss", "thug"] and ac.family >= 0:
				var fc2 := UI.fam_col(ac.family)
				if ac.family == mine:
					Draw.circle(self, ap, 4.2, UI.with_a(Color.WHITE, fa))
					Draw.circle(self, ap, 3.0, UI.with_a(fc2.lightened(0.1), fa))
				else:
					Draw.circle(self, ap, 3.9, UI.with_a(Color(0, 0, 0, 0.8), fa))
					Draw.circle(self, ap, 2.9, UI.with_a(fc2.lightened(0.1), fa))
	# the goal and the waypoint
	if waypoint != Vector2.INF:
		_pin(c + (waypoint / W.M - center_m) * sc, mr, "flag", UI.CREAM, a)
	if target != Vector2.INF:
		_pin(c + (target / W.M - center_m) * sc, mr, "star", UI.GOLD2, a)
	# you: an arrow by the way you face
	var yaw := float(me.get("yaw")) if me.get("yaw") != null else 0.0
	var d := Vector2.from_angle(yaw)
	var s := d.orthogonal()
	var arrow := PackedVector2Array([c + d * 9.0, c - d * 6.0 + s * 6.0, c - d * 3.0, c - d * 6.0 - s * 6.0])
	Draw.shadow(self, arrow, Vector2(1.5, 2.0), Color(0, 0, 0, 0.6 * a))
	Draw.poly(self, arrow, UI.with_a(Color.WHITE, a))
	draw_polyline(PackedVector2Array([arrow[0], arrow[1], arrow[2], arrow[3], arrow[0]]), UI.with_a(UI.fam_col(mine), a), 1.2, true)
	_frame(outer, mr, a)
	_plate(me, a)


## A plan rectangle (metres) drawn clipped to the map.
func _rect_m(rm: Rect2, center_m: Vector2, sc: float, c: Vector2, mr: Rect2, col: Color) -> void:
	var r := Rect2(c + (rm.position - center_m) * sc, rm.size * sc)
	var cr := _clip(r, mr)
	if cr.size.x > 0.0 and cr.size.y > 0.0:
		Draw.rect(self, cr, col)


func _clip(r: Rect2, to: Rect2) -> Rect2:
	return r.intersection(to) if r.intersects(to) else Rect2()


## A marker, pinned to the rim with a pointer when it's outside the map.
func _pin(p: Vector2, mr: Rect2, ic: String, col: Color, a: float) -> void:
	var inner := mr.grow(-11.0)
	var edge := not inner.has_point(p)
	var q := p
	if edge:
		var c := mr.get_center()
		var dv := (p - c)
		var k := minf(inner.size.x * 0.5 / maxf(absf(dv.x), 0.001), inner.size.y * 0.5 / maxf(absf(dv.y), 0.001))
		q = c + dv * k
		var dn := dv.normalized()
		Draw.poly(self, PackedVector2Array([q + dn * 12.0, q + dn * 5.0 + dn.orthogonal() * 5.0, q + dn * 5.0 - dn.orthogonal() * 5.0]), UI.with_a(col, a))
	Draw.circle(self, q + Vector2(1, 1.5), 8.0, UI.with_a(Color(0, 0, 0, 0.55), a))
	Draw.circle(self, q, 8.0, UI.with_a(Color("150e0a"), a))
	draw_arc(q, 8.0, 0, TAU, 20, UI.with_a(col, a), 1.5, true)
	UI.icon(self, ic, q, 11.0, UI.with_a(col, a))


func _frame(outer: Rect2, mr: Rect2, a: float) -> void:
	var rad := 18.0
	var inner_rad := 11.0
	# cover the square map's corners so it reads as rounded
	var bg := UI.with_a(UI.BRASS_DK, a)
	for k in 4:
		var corner: Vector2 = [mr.position, Vector2(mr.end.x, mr.position.y), mr.end, Vector2(mr.position.x, mr.end.y)][k]
		var dir: Vector2 = [Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1), Vector2(1, -1)][k]
		var cc := corner + dir * inner_rad
		var pts := PackedVector2Array([corner])
		var start: float = [PI, -PI * 0.5, 0.0, PI * 0.5][k]
		for s in 9:
			var ang := start + PI * 0.5 * float(s) / 8.0
			pts.append(cc + Vector2(cos(ang), sin(ang)) * inner_rad)
		Draw.poly(self, pts, bg)
	# the brass ring
	var ring_o := Draw.rrect_points(outer, rad, 6)
	var ring_i := Draw.rrect_points(mr, inner_rad, 6)
	var loop_o := ring_o.duplicate()
	loop_o.append(ring_o[0])
	var loop_i := ring_i.duplicate()
	loop_i.append(ring_i[0])
	# thick band: draw the outer rounded rect as a thick outline
	var mid_r := Rect2(outer.position + Vector2(FRAME, FRAME) * 0.5, outer.size - Vector2(FRAME, FRAME))
	var mid_pts := Draw.rrect_points(mid_r, (rad + inner_rad) * 0.5, 6)
	mid_pts.append(mid_pts[0])
	draw_polyline(mid_pts, UI.with_a(UI.BRASS, a), FRAME + 1.0, true)
	draw_polyline(loop_o, UI.with_a(UI.BRASS_DK, a), 2.0, true)
	draw_polyline(loop_i, UI.with_a(Color("2a1d10"), a), 2.0, true)
	var hi := Draw.rrect_points(Rect2(outer.position + Vector2(2.5, 2.5), outer.size - Vector2(5, 5)), rad - 2.5, 6)
	hi.append(hi[0])
	draw_polyline(hi, UI.with_a(UI.BRASS_HI, 0.45 * a), 1.0, true)
	# north
	var n := Vector2(outer.get_center().x, outer.position.y + 1.0)
	Draw.circle(self, n + Vector2(1, 2), 11.0, Color(0, 0, 0, 0.45 * a))
	Draw.circle(self, n, 11.0, UI.with_a(UI.BRASS_DK, a))
	Draw.circle(self, n, 9.5, UI.with_a(Color("241912"), a))
	var cond := UI.font("cond")
	UI.text_c(self, n.x, UI.mid(cond, 14, n.y), "N", cond, 14, UI.with_a(UI.GOLD2, a))
	if _hover:
		UI.text_c(self, outer.get_center().x, outer.end.y - 14.0, "CLICK: THE CITY MAP (M)", cond, 12, UI.with_a(UI.INK, 0.9 * a))


## The street (or the shop) you're in, on a plate above the map.
func _plate(me: Node2D, a: float) -> void:
	var plan: CityPlan = Game.plan
	var m := me.position / W.M
	var where := plan.street_name_at(m.x, m.y)
	var dist := plan.district_at(m.x, m.y)
	var inside := int(world.get("inside_lot")) if world.get("inside_lot") != null else -1
	if inside >= 0 and world.has_method("biz_at_lot"):
		var b: Dictionary = world.call("biz_at_lot", inside)
		if not b.is_empty():
			where = String(b["name"])
	var cond := UI.font("cond")
	var txt := UI.fit(cond, "%s  ·  %s" % [where.to_upper(), dist.to_upper()], 14, SIZE - 24.0)
	var w := minf(SIZE, UI.tw(cond, txt, 14) + 28.0)
	var r := Rect2(Vector2(SIZE - w, 0), Vector2(w, PLATE))
	UI.soft_shadow(self, r, 6.0, a * 0.8)
	UI.grad_rrect(self, r, 6.0, UI.with_a(Color("2a1d15"), 0.95 * a), UI.with_a(Color("150e0a"), 0.95 * a))
	UI.rrect_line(self, r, 6.0, UI.with_a(UI.BRASS_DK, a), 1.5)
	UI.text_c(self, r.get_center().x, UI.mid(cond, 14, r.get_center().y), txt, cond, 14, UI.with_a(UI.INK, a))
