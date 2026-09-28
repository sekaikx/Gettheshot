class_name CityGround
extends Node2D
## The ground of the 2D city: streets, crossings, sidewalks and curbs, street furniture (lamps,
## hydrants, mailboxes, benches, newsstands, ash cans, pushcarts...), the backyards inside the
## blocks, the quay, the piers and the river. Lives on the world canvas (lit by the light layer).
## Contract: docs/REBUILD_2D.md, "CityGround".
##
## Static art is split into chunk nodes (one per block / street segment, and per layer: ground,
## wet overlay, prop shadows, furniture, high props, night glow) so Godot culls them and nothing
## redraws per frame. Night, rain and shadow strength only change the chunks' modulate. The water,
## the manhole steam and a few flickering lamps are the only animated parts.

var plan: CityPlan
var night := 0.0
var wet := 0.0
## Draw the city beyond the map edge (the far sidewalks of the edge streets and plain roofs on
## their own roof layer). Set before build().
var outskirts := true
var layout: GroundLayout

var _lights: Array = []
var _solids: Array = []
var _wet_nodes: Array[CanvasItem] = []
var _wetnight_nodes: Array[CanvasItem] = []
var _glow_nodes: Array[CanvasItem] = []
var _shadow_nodes: Array[CanvasItem] = []
var _flicker: Array = []            # [{node, seed}]
var _river: GroundRiver
var _steam: GroundSteam
var _outskirt_layer: CanvasLayer
var _outskirt_node: GroundChunk
var _streets: GroundStreets
var _walks: GroundWalks
var _props: GroundProps
var _yards: GroundYards
var _quay: GroundQuay
var _outskirts_painter: GroundOutskirts
var _time := 0.0


func build(p: CityPlan) -> void:
	plan = p
	z_index = W.Z_GROUND
	for c in get_children():
		c.queue_free()
	_wet_nodes.clear()
	_wetnight_nodes.clear()
	_glow_nodes.clear()
	_shadow_nodes.clear()
	_flicker.clear()
	layout = GroundLayout.new()
	layout.build(p)
	_streets = GroundStreets.new(layout)
	_walks = GroundWalks.new(layout)
	_props = GroundProps.new(layout)
	_yards = GroundYards.new(layout)
	_quay = GroundQuay.new(layout)
	_quay.plan_quay()
	for b in layout.blocks:
		if not b["phantom"] and not (b["yard"] as Dictionary).is_empty():
			_yards.plan_yard(b)
	_lights = layout.lights.duplicate()
	_lights.append_array(_quay.lights)
	_solids = layout.solids.duplicate()
	_solids.append_array(_quay.solids)
	_solids.append_array(_yards.solids)

	# ground: asphalt everywhere, the water, then streets, crossings, the quay
	_chunk("Base", W.Z_GROUND, _streets.paint_base)
	_chunk("Water", W.Z_GROUND, _quay.paint_water)
	_river = GroundRiver.new()
	_river.name = "River"
	_river.setup(layout, _quay)
	_river.z_as_relative = false
	_river.z_index = W.Z_GROUND + 1
	add_child(_river)
	for s in layout.segs:
		_chunk("Street", W.Z_GROUND, _streets.paint_segment.bind(s))
		_wet_nodes.append(_chunk("StreetWet", W.Z_GROUND + 1, _streets.paint_segment_wet.bind(s)))
		if s["kind"] == "bowery":
			_chunk("Wires", W.Z_PROP_HIGH, _streets.paint_segment_high.bind(s))
		if not (s["props"] as Array).is_empty():
			_shadow_nodes.append(_chunk("CartShadows", W.Z_FURNITURE - 1, _props.paint_shadows.bind(s["props"])))
			_chunk("Carts", W.Z_FURNITURE, _props.paint_bodies.bind(s["props"]))
			_chunk("CartTops", W.Z_PROP_HIGH, _props.paint_high.bind(s["props"]))
	for x in layout.isecs:
		_chunk("Crossing", W.Z_GROUND, _streets.paint_intersection.bind(x))
		_wet_nodes.append(_chunk("CrossingWet", W.Z_GROUND + 1, _streets.paint_intersection_wet.bind(x)))
		if x["bowery"]:
			_chunk("Wires", W.Z_PROP_HIGH, _streets.paint_intersection_high.bind(x))
		if x.get("dome", false):
			_glow_nodes.append(_chunk("DomeGlow", W.Z_PROP_HIGH + 1, _streets.paint_intersection_glow.bind(x)))
	_chunk("Quay", W.Z_GROUND + 2, _quay.paint_quay)
	_wet_nodes.append(_chunk("QuayWet", W.Z_GROUND + 3, _quay.paint_quay_wet))
	_shadow_nodes.append(_chunk("QuayShadows", W.Z_FURNITURE - 1, _quay.paint_shadows))
	_chunk("QuayProps", W.Z_FURNITURE, _quay.paint_bodies)
	_chunk("QuayHigh", W.Z_PROP_HIGH, _quay.paint_high)
	_glow_nodes.append(_chunk("QuayGlow", W.Z_PROP_HIGH + 1, _quay.paint_glow))
	# lamp reflections on the wet street at night, all lamps in a few big chunks
	var heads := []
	for b in layout.blocks:
		for pr in b["props"]:
			if pr["t"] == "lamp":
				heads.append(pr["head"])
	heads.append_array(_quay.lamp_heads)
	_wetnight_nodes.append(_chunk("Reflections", W.Z_GROUND + 3, _streets.paint_reflections.bind(heads)))

	# blocks: sidewalks, their wet overlay, prop shadows, furniture, high parts, night glow
	for b in layout.blocks:
		if b["phantom"] and not outskirts:
			continue
		_chunk("Walk", W.Z_SIDEWALK, _walk_and_yard.bind(b))
		_wet_nodes.append(_chunk("WalkWet", W.Z_SIDEWALK + 1, _walk_wet.bind(b)))
		_shadow_nodes.append(_chunk("Shadows", W.Z_FURNITURE - 1, _block_shadows.bind(b)))
		_chunk("Furniture", W.Z_FURNITURE, _block_bodies.bind(b))
		_chunk("High", W.Z_PROP_HIGH, _block_high.bind(b))
		var steady := []
		for pr in b["props"]:
			if pr.get("flicker", false):
				var n := _chunk("Flicker", W.Z_PROP_HIGH + 1, _props.paint_glow.bind([pr]))
				_flicker.append({"node": n, "seed": int(pr["s"])})
			else:
				steady.append(pr)
		_glow_nodes.append(_chunk("Glow", W.Z_PROP_HIGH + 1, _props.paint_glow.bind(steady)))

	_steam = GroundSteam.new()
	_steam.name = "Steam"
	_steam.vents = layout.vents
	_steam.z_as_relative = false
	_steam.z_index = W.Z_PROP_HIGH + 2
	add_child(_steam)

	if outskirts:
		_outskirt_layer = CanvasLayer.new()
		_outskirt_layer.name = "OutskirtRoofs"
		_outskirt_layer.layer = W.LAYER_ROOFS
		_outskirt_layer.follow_viewport_enabled = true
		add_child(_outskirt_layer)
		_outskirts_painter = GroundOutskirts.new(layout)
		_outskirt_node = GroundChunk.new()
		_outskirt_node.paint = _outskirts_painter.paint
		_outskirt_node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_outskirt_node.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		_outskirt_layer.add_child(_outskirt_node)
	_apply()


func _chunk(n: String, z: int, paint: Callable) -> GroundChunk:
	var c := GroundChunk.new()
	c.name = n
	c.z_as_relative = false
	c.z_index = z
	c.paint = paint
	c.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	c.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	add_child(c)
	return c


func _walk_and_yard(ci: CanvasItem, b: Dictionary) -> void:
	_walks.paint_block(ci, b)
	if b.has("yard_plan"):
		_yards.paint_ground(ci, b)


func _walk_wet(ci: CanvasItem, b: Dictionary) -> void:
	_walks.paint_block_wet(ci, b)
	if b.has("yard_plan"):
		_yards.paint_wet(ci, b)


func _block_shadows(ci: CanvasItem, b: Dictionary) -> void:
	_props.paint_shadows(ci, b["props"])
	if b.has("yard_plan"):
		_yards.paint_shadows(ci, b)


func _block_bodies(ci: CanvasItem, b: Dictionary) -> void:
	_props.paint_bodies(ci, b["props"])
	if b.has("yard_plan"):
		_yards.paint_bodies(ci, b)


func _block_high(ci: CanvasItem, b: Dictionary) -> void:
	_props.paint_high(ci, b["props"])
	if b.has("yard_plan"):
		_yards.paint_high(ci, b)


func set_night(n: float, w: float) -> void:
	if absf(n - night) < 0.004 and absf(w - wet) < 0.004:
		return
	night = clampf(n, 0.0, 1.0)
	wet = clampf(w, 0.0, 1.0)
	_apply()


func _apply() -> void:
	# wet streets reflect a grey sky by day, and go dark and glossy at night
	var k := lerpf(1.0, 0.45, night)
	for c in _wet_nodes:
		c.modulate = Color(k, k, k * (1.0 + 0.08 * night), wet)
		c.visible = wet > 0.01
	for c in _wetnight_nodes:
		c.modulate.a = wet * night
		c.visible = wet * night > 0.01
	for c in _glow_nodes:
		c.modulate.a = night
		c.visible = night > 0.01
	# the sun's shadows fade at night and under rain clouds
	var sa := (1.0 - 0.7 * night) * (1.0 - 0.45 * wet)
	for c in _shadow_nodes:
		c.modulate.a = sa
	for f in _flicker:
		(f["node"] as CanvasItem).visible = night > 0.01
	if _river:
		_river.night = night
		_river.wet = wet
	if _steam:
		_steam.night = night
		_steam.wet = wet
	if _outskirt_node:
		_outskirt_node.modulate = Color(1, 1, 1).lerp(Color(0.32, 0.34, 0.5), night)


func _process(delta: float) -> void:
	_time += delta
	if night <= 0.01:
		return
	for f in _flicker:
		var s: int = f["seed"]
		var t := _time * (7.0 + GroundUtil.r01(s, 1) * 5.0) + GroundUtil.r01(s, 2) * 30.0
		var v := 0.75 + 0.25 * sin(t) * sin(t * 2.3 + 1.0)
		if fmod(_time + GroundUtil.r01(s, 3) * 9.0, 9.0) < 0.35:
			v *= 0.25 + 0.5 * absf(sin(_time * 40.0))
		(f["node"] as CanvasItem).modulate.a = night * v


## Street lamps and other light sources on the ground: [{pos: Vector2 px, r: radius px, color,
## e: energy 0..1.5, shape: "round"|"rect"|"cone", size: Vector2 (rect), rot: float (cone),
## flicker: bool}]. Constant for the life of the node.
func lights() -> Array:
	return _lights


## Rectangles (px) that block people and cars: newsstands, pushcarts, crate stacks, bollards...
## (not buildings: the World adds those).
func solids() -> Array:
	return _solids


## Free spots in the parking lanes along the curbs (not at crossings, not on the market street):
## [{pos: Vector2 px, rot: float (0 = facing east)}]. For parked cars.
func parking_spots() -> Array:
	return layout.parking if layout else []


## All placed street furniture: [{t: type, p: Vector2 px, rot, ...}] (lamps, hydrants, benches...,
## the pushcarts, the quay's stacks). For AI (sit on a bench, lean on a lamp) or the minimap.
func props() -> Array:
	var out := []
	if layout == null:
		return out
	for b in layout.blocks:
		out.append_array(b["props"])
	for s in layout.segs:
		out.append_array(s["props"])
	out.append_array(_quay.props)
	return out
