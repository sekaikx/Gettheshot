extends Control
## M: the city from above. Every shop in the colour of the family it pays, the clubs, the
## precinct, the piers, your men, and you.

var world: Node
const INK := Color("efe6d2")


func _draw() -> void:
	var plan: CityPlan = Game.plan
	if plan == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.045, 0.04, 0.93))
	var b := plan.bounds
	var area := Rect2(b.position.x + 20, b.position.y + 20, plan.water_x + 40 - b.position.x - 20, b.size.y - 40)
	var sc := minf((size.x - 360.0) / area.size.x, (size.y - 140.0) / area.size.y)
	var off := Vector2(40, 90) - area.position * sc
	var to := func(x: float, z: float) -> Vector2: return Vector2(x, z) * sc + off
	var font := get_theme_default_font()
	draw_string(font, Vector2(40, 60), "Lower Manhattan, %s" % Game.date_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, INK)
	# water, quay, piers
	var wtl: Vector2 = to.call(plan.water_x, b.position.y)
	draw_rect(Rect2(wtl, Vector2(40 * sc, b.size.y * sc)), Color("0f1d26"))
	for p in plan.piers:
		var a: Vector2 = to.call(p["x0"], p["z0"])
		var c: Vector2 = to.call(p["x1"], p["z1"])
		draw_rect(Rect2(a, c - a), Color("5a4a3a"))
	for blk in plan.blocks:
		var r: Array = blk["rect"]
		var a: Vector2 = to.call(r[0], r[1])
		var c: Vector2 = to.call(r[2], r[3])
		draw_rect(Rect2(a, c - a), Color("2a2622"))
	for lot in plan.lots:
		var w: float = lot["size"][0]
		var d: float = lot["size"][1]
		var yaw: float = lot["yaw"]
		var ext := Vector2(w, d) if absf(sin(yaw)) < 0.5 else Vector2(d, w)
		var cpos: Vector2 = to.call(lot["center"][0], lot["center"][1])
		draw_rect(Rect2(cpos - ext * sc * 0.5, ext * sc), Color("3b3530"))
	for bz in Game.biz:
		var owner: int = bz["owned_by"] if bz["owned_by"] >= 0 else bz["protector"]
		var col := Color("5e5850")
		if owner >= 0:
			col = Color(Game.fam(owner)["color"])
		var p: Vector2 = to.call(bz["door"][0], bz["door"][1])
		var rad := 5.0
		if bz["kind"] == "club" and int(bz["hq_of"]) >= 0:
			rad = 9.0
			draw_circle(p, rad + 2, Color.BLACK)
		elif bz["kind"] == "precinct":
			draw_rect(Rect2(p - Vector2(7, 7), Vector2(14, 14)), Color("6f9cff"))
			continue
		draw_circle(p, rad, col)
		if bz["owned_by"] >= 0 and bz["owned_by"] == int(Game.player(Net.my_id()).get("family", -2)) and bz["speak"]:
			draw_circle(p, 2.5, Color.WHITE)
	# district names
	var names := {"Hell's Kitchen": Vector2(1, 1), "Garment District": Vector2(3, 1), "Little Italy": Vector2(1, 3),
		"Lower East Side": Vector2(3, 3), "Waterfront": Vector2(5.5, 2)}
	for n in names:
		var g: Vector2 = names[n] * CityPlan.PITCH
		var p: Vector2 = to.call(g.x, g.y)
		draw_string(font, p - Vector2(60, 0), n.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 120, 14, Color(1, 1, 1, 0.55))
	if world:
		for a in world.actors.values():
			var ac := a as Actor
			if ac.kind == "crew" and ac.family == int(Game.player(Net.my_id()).get("family", -2)):
				draw_circle(to.call(ac.position.x, ac.position.z), 3.0, Color("f0d58a"))
			elif ac.kind == "boss":
				var pc := Color(Game.fam(ac.family).get("color", "#ffffff"))
				var pp: Vector2 = to.call(ac.position.x, ac.position.z)
				draw_circle(pp, 7.0, Color.WHITE if ac == world.local_actor else pc)
				draw_circle(pp, 4.5, pc)
	# boat
	if Game.clock > 0.55 and Game.clock < 0.97 and int(Game.boat.get("crates", 0)) > 0:
		var tip: Array = plan.piers[1]["tip"]
		var bp: Vector2 = to.call(tip[0] + 8.0, tip[1])
		draw_rect(Rect2(bp - Vector2(5, 12), Vector2(10, 24)), Color("d8d0bc"))
		draw_string(font, bp + Vector2(10, 4), "BOAT IN", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("ffc070"))
	# legend
	var lx := size.x - 300
	var ly := 110.0
	draw_string(font, Vector2(lx, ly), "THE FAMILIES", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("f0d58a"))
	for f in Game.families:
		ly += 30
		draw_circle(Vector2(lx + 8, ly - 6), 8, Color(f["color"]))
		draw_string(font, Vector2(lx + 24, ly), "%s · %d shops" % [f["name"], Game.shops_of(f["id"]).size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, INK)
	ly += 50
	for t in [["big dot", "a family's club"], ["blue square", "14th Precinct"], ["white centre", "your speakeasy"], ["yellow dots", "your men"], ["grey", "pays nobody yet"]]:
		draw_string(font, Vector2(lx, ly), "%s: %s" % t, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1, 0.6))
		ly += 22
	draw_string(font, Vector2(lx, size.y - 40), "M to close", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.5))


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()
