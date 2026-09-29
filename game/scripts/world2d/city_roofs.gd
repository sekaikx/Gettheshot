class_name CityRoofs
extends Node2D
## Every building's roof seen from above, with its drop shadow on the street: tar roofs,
## parapets, chimneys, water towers, skylights, hatches, laundry lines between buildings.
## Lives on its own canvas layer (W.LAYER_ROOFS) above the light layer, so street lamps don't
## light the roofs; night darkens it through set_night(). API: docs/REBUILD_2D.md, "CityRoofs".
##
## How it's built:
## - one child node per lot (the roof and everything on it, fire escapes and cornice included),
##   drawn once; taller buildings are drawn after lower ones so their overhangs sit on top;
## - a child of that node with the shadows taller neighbours throw onto this roof (fades at night);
## - the shadows on the ground: rendered once into a small mask texture (a SubViewport, one texel
##   per 8 px) and multiplied onto the street by a shader, so overlapping shadows never double up
##   and their edges come out soft. Walking into a lot re-renders the mask without that lot and
##   cross-fades to it;
## - small animated bits (chimney smoke, flags) redraw only when on screen.

const FX := preload("res://scripts/world2d/fronts/fx.gd")
const RoofArt := preload("res://scripts/world2d/fronts/roof_art.gd")
const PaintNode := preload("res://scripts/world2d/fronts/paint_node.gd")

const MASK_SCALE := 8.0           # world px per shadow-mask texel
const SHADOW_DAY := 0.3           # ground shadow strength in full sun
const FADE_TO := 0.1              # a roof you're under
const FADE_TIME := 0.25
const NIGHT_TINT := Color(0.3, 0.32, 0.47)
const WIND := Vector2(0.86, 0.5)
const ANIM_HZ := 15.0

const SHADOW_SHADER := """
shader_type canvas_item;
render_mode blend_mul, unshaded;
uniform sampler2D mask_b : filter_linear;
uniform float mixv = 0.0;
uniform float strength = 0.3;
void fragment() {
	float a = texture(TEXTURE, UV).r;
	float b = texture(mask_b, UV).r;
	float s = mix(a, b, mixv) * strength;
	COLOR = vec4(vec3(1.0 - s), 1.0);
}
"""

var plan: CityPlan
var night := 0.0
var wet := 0.0
var _inside := -1
var _fade := {}          # lot id -> alpha (1 = solid roof)

var _lots := {}          # lot id -> roof layout (RoofArt.plan_lot)
var _nodes := {}         # lot id -> roof node
var _glows := {}         # lot id -> night glow node
var _recv_nodes: Array = []
var _ground := {}        # lot id -> ground shadow polygon (world px)
var _tint: Node2D
var _glow_root: Node2D
var _shadow: Sprite2D
var _shadow_mat: ShaderMaterial
var _vps: Array = []     # [SubViewport, SubViewport]
var _mask_nodes: Array = []
var _mask_exclude := [-1, -1]
var _cur := 0
var _mask_gen := 0
var _mix_tween: Tween
var _region := Rect2()
var _smoke: Array = []   # [{node, list: [[pos, phase], ...], rect}]
var _flags: Array = []   # [{node, lot, kind, key}]
var _t := 0.0
var _anim_acc := 0.0


func build(p: CityPlan) -> void:
	plan = p
	for c in get_children():
		c.queue_free()
	_lots.clear(); _nodes.clear(); _glows.clear(); _recv_nodes.clear(); _ground.clear()
	_smoke.clear(); _flags.clear(); _fade.clear(); _vps.clear(); _mask_nodes.clear()
	var biz_of := {}
	for b in Game.biz:
		biz_of[int(b["lot"])] = b
	var inner_of := {}
	for blk in plan.blocks:
		var r: Array = blk["rect"]
		var sw := CityPlan.SIDEWALK
		inner_of[Vector2i(int(blk["i"]), int(blk["j"]))] = Rect2(Vector2(r[0] + sw, r[1] + sw) * W.M,
			Vector2(r[2] - r[0] - 2.0 * sw, r[3] - r[1] - 2.0 * sw) * W.M)
	var by_block := {}
	for lot in plan.lots:
		if lot["kind"] == "courtyard":
			continue
		var bk := Vector2i(int(lot["block"][0]), int(lot["block"][1]))
		var L := RoofArt.plan_lot(lot, inner_of.get(bk, Rect2()), biz_of.get(int(lot["id"]), {}))
		_lots[int(lot["id"])] = L
		by_block.get_or_add(bk, []).append(L)
		var h := float(L["floors"]) * 3.0
		_ground[int(L["id"])] = FX.hull_shift(FX.rect_pts(L["rect"]), FX.sh(h))
	for bk in by_block:
		_neighbours(by_block[bk])
	_build_shadow_mask()
	_tint = Node2D.new()
	_tint.name = "Roofs"
	add_child(_tint)
	_glow_root = Node2D.new()
	_glow_root.name = "Glow"
	_glow_root.modulate = Color(1, 1, 1, 0)
	_glow_root.visible = false
	add_child(_glow_root)
	var order: Array = _lots.values()
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["floors"]) < int(b["floors"]) or (int(a["floors"]) == int(b["floors"]) and int(a["id"]) < int(b["id"])))
	for L in order:
		var id := int(L["id"])
		var n := PaintNode.new()
		n.name = "Roof%d" % id
		n.position = (L["rect"] as Rect2).position
		n.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		n.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		n.painter = RoofArt.paint.bind(L)
		_tint.add_child(n)
		_nodes[id] = n
		_fade[id] = 1.0
		if not (L["recv"] as Array).is_empty():
			var rs := PaintNode.new()
			rs.painter = RoofArt.paint_recv.bind(L)
			n.add_child(rs)
			_recv_nodes.append(rs)
		var glows := false
		for pr in L["props"]:
			if (pr["t"] == "skylight" and pr.get("lit", false)) or pr["t"] == "monitor":
				glows = true
		if glows:
			var g := PaintNode.new()
			g.position = n.position
			g.painter = RoofArt.paint_glow.bind(L)
			_glow_root.add_child(g)
			_glows[id] = g
		if L.has("flag"):
			var fl := PaintNode.new()
			fl.position = n.position
			fl.painter = _paint_flag.bind(L)
			_tint.add_child(fl)
			_flags.append({"node": fl, "lot": id, "kind": String(L["kind"]), "key": "", "rect": (L["rect"] as Rect2).grow(3.0 * W.M)})
	# chimney smoke, one animated node per block
	for bk in by_block:
		var list := []
		var area := Rect2()
		for L in by_block[bk]:
			for pr in L["props"]:
				if pr["t"] == "chimney" and pr.get("smoke", false):
					var c: Vector2 = (pr["r"] as Rect2).get_center() + (L["rect"] as Rect2).position
					list.append([c, Draw.hash01(int(c.x), int(c.y), 3)])
			area = (L["rect"] as Rect2) if area.size == Vector2.ZERO else area.merge(L["rect"])
		if list.is_empty():
			continue
		var s := PaintNode.new()
		s.painter = _paint_smoke.bind(list)
		_tint.add_child(s)
		_smoke.append({"node": s, "rect": area.grow(6.0 * W.M)})
	update_owners()
	_apply_night()


## Re-read Game.biz: the family flag over each social club.
func update_owners() -> void:
	for fl in _flags:
		var key := _flag_key(int(fl["lot"]), String(fl["kind"]))
		if key != String(fl["key"]):
			fl["key"] = key
			(fl["node"] as Node2D).visible = key != ""
			(fl["node"] as Node2D).queue_redraw()


func set_night(n: float, w: float) -> void:
	if absf(n - night) > 0.02 or absf(w - wet) > 0.05 or (n == 0.0) != (night == 0.0):
		night = n
		wet = w
		_apply_night()


## The local player walked into lot `lot_id` (-1 = back outside): fade that roof out so the
## interior shows, and back in when they leave.
func set_inside(lot_id: int) -> void:
	if lot_id == _inside:
		return
	var prev := _inside
	_inside = lot_id
	for id in [prev, lot_id]:
		if not _nodes.has(id):
			continue
		var target := FADE_TO if id == _inside else 1.0
		_fade[id] = target
		for node in [_nodes[id], _glows.get(id)]:
			if node == null:
				continue
			var tw := (node as Node2D).create_tween()
			tw.tween_property(node, "modulate:a", target, FADE_TIME)
	_crossfade_shadow(lot_id if _nodes.has(lot_id) else -1)


## The roof's current opacity (1 solid, FADE_TO when you're inside).
func roof_alpha(lot_id: int) -> float:
	return float(_fade.get(lot_id, 1.0))


func _apply_night() -> void:
	if _tint == null:
		return
	var tint := Color.WHITE.lerp(NIGHT_TINT, night)
	tint = tint.lerp(tint * Color(0.82, 0.85, 0.92), wet * (1.0 - night * 0.5))
	tint.a = 1.0
	_tint.modulate = tint
	var glow := clampf((night - 0.25) / 0.5, 0.0, 1.0)
	_glow_root.visible = glow > 0.0
	_glow_root.modulate = Color(1, 1, 1, glow)
	var sun := (1.0 - night * 0.8) * (1.0 - wet * 0.55)
	for rs in _recv_nodes:
		(rs as Node2D).modulate = Color(1, 1, 1, sun)
	if _shadow_mat:
		_shadow_mat.set_shader_parameter("strength", SHADOW_DAY * sun)


# ------------------------------------------------------------------ neighbours

func _neighbours(list: Array) -> void:
	for A in list:
		var ra: Rect2 = A["rect"]
		for B in list:
			if A == B:
				continue
			var rb: Rect2 = B["rect"]
			if not ra.grow(2.0).intersects(rb):
				continue
			var fa := int(A["floors"])
			var fb := int(B["floors"])
			if fa > fb:
				var poly := FX.hull_shift(FX.rect_pts(ra), FX.sh(float(fa - fb) * 3.0))
				for piece in Geometry2D.intersect_polygons(poly, FX.rect_pts(rb)):
					var local := PackedVector2Array()
					for q in piece:
						local.append(q - rb.position)
					(B["recv"] as Array).append(local)
			# a washing line across the party wall, strung from the lower roof to the taller one
			var same_row: bool = (A["f"] as Vector2) == (B["f"] as Vector2)
			if same_row and int(A["id"]) < int(B["id"]) and absi(fa - fb) <= 1 and mini(fa, fb) >= 3:
				var r := W.rng(int(A["id"]) * 977 + int(B["id"]))
				if r.randf() < 0.45:
					_line_between(A, B, r)


func _line_between(A: Dictionary, B: Dictionary, r: RandomNumberGenerator) -> void:
	var ra: Rect2 = A["rect"]
	var rb: Rect2 = B["rect"]
	var f: Vector2 = A["f"]
	var inward := -f
	var along := f.orthogonal().abs()
	# the shared wall and a spot toward the back of both roofs
	var ca := ra.get_center()
	var cb := rb.get_center()
	var depth := absf(ra.size.dot(f))
	var back := inward * depth * r.randf_range(0.1, 0.32)
	var ta := ca + back + (cb - ca).project(along) * r.randf_range(0.2, 0.4)
	var tb := cb + back - (cb - ca).project(along) * r.randf_range(0.2, 0.4)
	tb += inward.abs() * 0.0 + (inward * depth * r.randf_range(-0.08, 0.08))
	# drawn by whichever of the two comes later (the taller), so it hangs over both
	var owner: Dictionary = B if int(B["floors"]) >= int(A["floors"]) else A
	var o: Vector2 = (owner["rect"] as Rect2).position
	(owner["lines"] as Array).append({"a": ta - o, "b": tb - o, "seed": int(A["id"]) * 131 + int(B["id"]), "pa": true, "pb": true})


# ------------------------------------------------------------------ ground shadows

func _build_shadow_mask() -> void:
	var bb := Rect2()
	for id in _ground:
		for q in _ground[id]:
			bb = Rect2(q, Vector2.ZERO) if bb.size == Vector2.ZERO and bb.position == Vector2.ZERO else bb.expand(q)
	bb = bb.grow(MASK_SCALE * 3.0)
	bb.position = (bb.position / MASK_SCALE).floor() * MASK_SCALE
	_region = bb
	var tex_size := Vector2i(int(ceil(bb.size.x / MASK_SCALE)), int(ceil(bb.size.y / MASK_SCALE)))
	for k in 2:
		var vp := SubViewport.new()
		vp.name = "ShadowMask%d" % k
		vp.world_2d = World2D.new()
		vp.disable_3d = true
		vp.transparent_bg = false
		vp.size = tex_size
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
		add_child(vp)
		var mn := PaintNode.new()
		mn.scale = Vector2.ONE / MASK_SCALE
		mn.position = -bb.position / MASK_SCALE
		mn.painter = _paint_mask.bind(k)
		vp.add_child(mn)
		_vps.append(vp)
		_mask_nodes.append(mn)
	_shadow = Sprite2D.new()
	_shadow.name = "GroundShadows"
	_shadow.centered = false
	_shadow.position = bb.position
	_shadow.scale = Vector2(MASK_SCALE, MASK_SCALE)
	_shadow.texture = (_vps[0] as SubViewport).get_texture()
	_shadow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var sh := Shader.new()
	sh.code = SHADOW_SHADER
	_shadow_mat = ShaderMaterial.new()
	_shadow_mat.shader = sh
	_shadow_mat.set_shader_parameter("mask_b", (_vps[1] as SubViewport).get_texture())
	_shadow_mat.set_shader_parameter("mixv", 0.0)
	_shadow_mat.set_shader_parameter("strength", SHADOW_DAY)
	_shadow.material = _shadow_mat
	add_child(_shadow)


func _paint_mask(ci: CanvasItem, k: int) -> void:
	var ex: int = _mask_exclude[k]
	ci.draw_rect(_region.grow(64.0), Color.BLACK)
	var soft := Color(0.5, 0.5, 0.5)
	for id in _ground:
		if id == ex:
			continue
		for g in Geometry2D.offset_polygon(_ground[id], MASK_SCALE * 1.2, Geometry2D.JOIN_ROUND):
			ci.draw_colored_polygon(g, soft)
	for id in _ground:
		if id == ex:
			continue
		ci.draw_colored_polygon(_ground[id], Color.WHITE)
	# no ground shadow under the buildings themselves (their roofs cover it; when one fades out,
	# the shop inside shouldn't sit in its neighbour's shade)
	for id in _lots:
		ci.draw_rect((_lots[id]["rect"] as Rect2).grow(-MASK_SCALE * 0.75), Color.BLACK)


func _crossfade_shadow(exclude: int) -> void:
	if _vps.size() < 2:
		return
	_mask_gen += 1
	var gen := _mask_gen
	if _mix_tween and _mix_tween.is_valid():
		_mix_tween.kill()
		_finish_mix(1 - _cur)
	var nxt := 1 - _cur
	_mask_exclude[nxt] = exclude
	(_mask_nodes[nxt] as Node2D).queue_redraw()
	(_vps[nxt] as SubViewport).render_target_update_mode = SubViewport.UPDATE_ONCE
	_shadow_mat.set_shader_parameter("mask_b", (_vps[nxt] as SubViewport).get_texture())
	_shadow_mat.set_shader_parameter("mixv", 0.0)
	await RenderingServer.frame_post_draw
	if gen != _mask_gen or not is_inside_tree():
		return
	_mix_tween = create_tween()
	_mix_tween.tween_method(func(v: float) -> void: _shadow_mat.set_shader_parameter("mixv", v), 0.0, 1.0, FADE_TIME)
	_mix_tween.tween_callback(_finish_mix.bind(nxt))


func _finish_mix(nxt: int) -> void:
	_cur = nxt
	_shadow.texture = (_vps[_cur] as SubViewport).get_texture()
	_shadow_mat.set_shader_parameter("mask_b", (_vps[1 - _cur] as SubViewport).get_texture())
	_shadow_mat.set_shader_parameter("mixv", 0.0)


# ------------------------------------------------------------------ animated bits

func _process(delta: float) -> void:
	_t += delta
	_anim_acc += delta
	if _anim_acc < 1.0 / ANIM_HZ:
		return
	_anim_acc = 0.0
	var view := _view_rect()
	for s in _smoke:
		if (s["rect"] as Rect2).intersects(view):
			(s["node"] as Node2D).queue_redraw()
	for fl in _flags:
		if String(fl["key"]) != "" and (fl["rect"] as Rect2).intersects(view):
			(fl["node"] as Node2D).queue_redraw()


func _view_rect() -> Rect2:
	var vp := get_viewport()
	if vp == null:
		return Rect2()
	var xf := get_canvas_transform()
	return xf.affine_inverse() * Rect2(Vector2.ZERO, vp.get_visible_rect().size)


func _paint_smoke(ci: CanvasItem, list: Array) -> void:
	var wind := WIND.normalized()
	var winter := 1.0
	var m := Game.month % 12
	if m >= 4 and m <= 8:
		winter = 0.55
	for s in list:
		var p: Vector2 = s[0]
		var ph: float = s[1]
		for k in 5:
			var u := fmod(_t * 0.16 + ph + k * 0.2, 1.0)
			var pos := p + wind * u * 3.2 * W.M + wind.orthogonal() * sin(_t * 0.9 + ph * 20.0 + k * 1.7) * 5.0 * u
			var r := 4.0 + u * 20.0
			var a := 0.22 * winter * (1.0 - u) * clampf(u * 8.0, 0.0, 1.0)
			ci.draw_circle(pos, r, Color(0.66, 0.66, 0.68, a), true, -1.0, true)
			ci.draw_circle(pos + Vector2(-r * 0.25, -r * 0.25), r * 0.55, Color(0.8, 0.8, 0.82, a * 0.6), true, -1.0, true)


func _flag_key(lot_id: int, kind: String) -> String:
	if kind == "precinct":
		return "usa"
	for b in Game.biz:
		if int(b["lot"]) == lot_id:
			var fam := int(b["hq_of"])
			if fam < 0:
				return ""
			return "fam%d:%s" % [fam, W.fam_color(fam).to_html()]
	return ""


func _paint_flag(ci: CanvasItem, L: Dictionary) -> void:
	var fl: Dictionary = L["flag"]
	var base: Vector2 = fl["base"]
	var f: Vector2 = fl["dir"]
	var kind := String(L["kind"])
	var col := Color.WHITE
	if kind != "precinct":
		var key := _flag_key(int(L["id"]), kind)
		if key == "":
			return
		col = W.fam_color(int(key.substr(3).split(":")[0]))
	# the pole leans out over the street from the cornice
	var tip := base + f * 1.3 * W.M + Vector2(-0.2, -0.2) * W.M
	ci.draw_line(base + FX.sh(14.0) * 0.25, tip + FX.sh(14.0) * 0.25, Color(FX.SHADE, 0.2), 2.0, true)
	ci.draw_line(base, tip, Color("2e2a26"), 2.4, true)
	ci.draw_line(base + Vector2(-0.6, -0.6), tip + Vector2(-0.6, -0.6), Color("9a948a"), 0.8, true)
	Draw.circle(ci, tip, 2.2, Pal.BRASS)
	# the cloth, streaming downwind and rippling
	var wind := WIND.normalized()
	var length := 1.35 * W.M
	var width := 0.8 * W.M
	var seg := 8
	var top := PackedVector2Array()
	var bot := PackedVector2Array()
	var across := wind.orthogonal()
	var p0 := tip.lerp(base, 0.08)
	for k in seg + 1:
		var u := float(k) / seg
		var wave := sin(_t * 5.0 - u * 6.0 + float(L["id"])) * 4.0 * u
		var c := p0 + wind * length * u + across * wave
		top.append(c)
		bot.append(c + (base - tip).normalized() * width * (1.0 - 0.1 * u) + across * wave * 0.3)
	var shadow_pts := PackedVector2Array()
	for q in top:
		shadow_pts.append(q + FX.sh(10.0) * 0.3)
	for i in range(bot.size() - 1, -1, -1):
		shadow_pts.append(bot[i] + FX.sh(10.0) * 0.3)
	Draw.poly(ci, shadow_pts, Color(FX.SHADE, 0.16), false)
	for k in seg:
		var u := (float(k) + 0.5) / seg
		var lit := 0.88 + 0.16 * sin(_t * 5.0 - u * 6.0 + float(L["id"]) + 1.2)
		var quad := PackedVector2Array([top[k], top[k + 1], bot[k + 1], bot[k]])
		if kind == "precinct":
			_us_flag_piece(ci, top[k], top[k + 1], bot[k + 1], bot[k], k, seg, lit)
		else:
			var c := col * lit
			c.a = 1.0
			Draw.poly(ci, quad, c)
	if kind != "precinct":
		# a cream border stripe near the hoist, like a club banner
		ci.draw_line(top[0], bot[0], Pal.AWNING_CREAM, 2.0, true)
		ci.draw_line(top[1].lerp(top[0], 0.5), bot[1].lerp(bot[0], 0.5), Color(Pal.AWNING_CREAM, 0.8), 1.5, true)


func _us_flag_piece(ci: CanvasItem, a: Vector2, b: Vector2, c: Vector2, d: Vector2, k: int, seg: int, lit: float) -> void:
	var stripes := 7
	for s in stripes:
		var t0 := float(s) / stripes
		var t1 := float(s + 1) / stripes
		var col := Color("b22234") if s % 2 == 0 else Color("f0ece0")
		col = col * lit
		col.a = 1.0
		Draw.poly(ci, PackedVector2Array([a.lerp(d, t0), b.lerp(c, t0), b.lerp(c, t1), a.lerp(d, t1)]), col, false)
	if k < seg * 0.45:
		var cc := Color("2a3a6a") * lit
		cc.a = 1.0
		Draw.poly(ci, PackedVector2Array([a, b, b.lerp(c, 0.54), a.lerp(d, 0.54)]), cc, false)
		Draw.circle(ci, a.lerp(b, 0.5).lerp(d.lerp(c, 0.5), 0.27), 1.0, Color(1, 1, 1, 0.8))
