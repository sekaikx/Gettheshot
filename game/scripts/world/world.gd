class_name World
extends Node3D
## The street. Builds the city, spawns everyone, runs the host simulation (brains, crimes,
## witnesses, cops, the smuggler's boat, traffic) and keeps every client in step:
##   host -> clients: Game state (reliable, when it changes) and snapshots (unreliable, 10 Hz)
##   client -> host: its own boss/vehicle pose (15 Hz) and requests (Net.to_host)

const PEDS := 34
const TRAFFIC := 7
const DOCKERS := 5          # longshoremen carrying crates off the piers (+2 waiting at the shape-up)
const STACK_MAX := 64       # crate meshes by a warehouse door (one per 5 crates)
const SNAP_HZ := 10.0
const POSE_HZ := 15.0

var plan: CityPlan
var city: CityBuilder
var env: Environment
var sun: DirectionalLight3D
var cam: CameraRig
var hud: Node
var controller: PlayerController
var actors := {}
var vehicles := {}
var items := {}
var local_actor: Actor
var local_vehicle: Vehicle
var weather := "clear"
var rain: GPUParticles3D
var boat: Node3D
var audio: Node
var arrests := {}        # peer -> cop key (pending)
var _next_item := 1
var _snap_t := 0.0
var _pose_t := 0.0
var _state_t := 0.0
var _sync_t := 0.0
var _shopkeepers := {}
var _shop_t := 0.0
var _last_seen := {}
var _corpses := {}
var _weather_month := -1
var _contra_t := 0.0
var _spotted := {}
var _stacks := {}        # warehouse biz id -> {node, shown, label}
var _crate_mesh: BoxMesh


func _ready() -> void:
	set_process(false)
	if Game.plan == null:
		await Game.state_changed
	set_process(true)
	plan = Game.plan
	_environment()
	city = CityBuilder.new()
	city.name = "City"
	add_child(city)
	city.build(plan)
	city.update_owners()
	_boat()
	_shape_up_board()
	_quay_cargo()
	cam = CameraRig.new()
	add_child(cam)
	audio = preload("res://scripts/world/ambience.gd").new()
	add_child(audio)
	hud = preload("res://scripts/ui/hud.gd").new()
	hud.world = self
	add_child(hud)
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
	if Net.is_host():
		_host_spawn()
	_ensure_local_boss()
	_on_state_changed()
	if "--mptest" in OS.get_cmdline_user_args():
		var mt := Node.new()
		add_child(mt)
		var t := Timer.new()
		t.wait_time = 1.0
		t.autostart = true
		mt.add_child(t)
		var ticks := [0]
		t.timeout.connect(func() -> void:
			ticks[0] += 1
			if ticks[0] == 2 and local_actor:
				controller.auto_move = Vector2(1, 0)
			if ticks[0] == 4:
				controller.auto_move = Vector2.ZERO
				Net.to_host("punch", [])
				var near := {}
				var bd := INF
				for b in Game.biz:
					if b["kind"] in ["club", "precinct", "warehouse"]:
						continue
					var d := Vector3(b["door"][0], 0, b["door"][1]).distance_to(local_actor.position)
					if d < bd:
						bd = d
						near = b
				Net.to_host("nation", ["send", "det", 2, 0, -1])
			if ticks[0] == 9:
				var fam := int(Game.player(Net.my_id()).get("family", -1))
				print("MPTEST %s id=%d players=%d family=%s actors=%d vehicles=%d month=%d local=%s chicago_det=%s" % [
					"HOST" if Net.is_host() else "CLIENT", Net.my_id(), Game.players.size(), Game.fam(fam).get("name", "?"),
					actors.size(), vehicles.size(), Game.month, str(local_actor.position if local_actor else "none"),
					str(Game.nation["cities"]["det"]["influence"])])
			if ticks[0] == 11:
				get_tree().quit())
	if "--autotest" in OS.get_cmdline_user_args():
		var t = preload("res://scripts/world/autotest.gd").new()
		t.world = self
		add_child(t)


# ------------------------------------------------------------------ environment

func _environment() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("10131a")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("8a93a8")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.08
	env.fog_enabled = true
	env.fog_light_color = Color("3a3f4a")
	env.fog_density = 0.004
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.8
	env.adjustment_contrast = 1.14
	env.ssao_enabled = true
	env.ssao_radius = 1.5
	env.ssao_intensity = 1.2
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	sun.shadow_blur = 1.5
	add_child(sun)
	rain = GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(34, 1, 34)
	pm.direction = Vector3(0.1, -1, 0.05)
	pm.spread = 3.0
	pm.initial_velocity_min = 24.0
	pm.initial_velocity_max = 30.0
	pm.gravity = Vector3(0, -10, 0)
	rain.process_material = pm
	var drop := QuadMesh.new()
	drop.size = Vector2(0.03, 0.7)
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0.7, 0.75, 0.85, 0.35)
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	drop.material = dm
	rain.draw_pass_1 = drop
	rain.amount = 2500
	rain.lifetime = 1.2
	rain.visibility_aabb = AABB(Vector3(-40, -40, -40), Vector3(80, 80, 80))
	rain.emitting = false
	add_child(rain)


func _day_light() -> void:
	# one day and night per month: dawn 0.0, noon 0.25, dusk 0.5, midnight 0.75
	var t := Game.clock
	var sun_up := sin(t * TAU)                    # 1 at noon, -1 at midnight
	var night := clampf(0.5 - sun_up * 0.9, 0.0, 1.0)
	var dusk := clampf(1.0 - absf(sun_up) * 3.0, 0.0, 1.0)
	var elev := lerpf(-20.0, -62.0, clampf(sun_up, 0.0, 1.0))
	sun.rotation_degrees = Vector3(elev if sun_up > 0.0 else -35.0, 35.0 + t * 200.0, 0)
	var day_col := Color("fff1dc").lerp(Color("ffb070"), dusk)
	sun.light_color = day_col.lerp(Color("8fa8ff"), night)
	sun.light_energy = lerpf(1.2, 0.32, night)
	env.ambient_light_color = Color("aab0c0").lerp(Color("5a6a90"), night)
	env.ambient_light_energy = lerpf(0.55, 0.5, night)
	env.background_color = Color("9fb0c4").lerp(Color("0b0e16"), night)
	env.fog_light_color = Color("8a8f98").lerp(Color("1c2230"), night)
	var wet := 1.0 if weather == "rain" else 0.0
	env.fog_density = 0.004 + (0.008 if weather == "fog" else 0.0) + wet * 0.003
	city.set_night(night, wet)
	for v in vehicles.values():
		(v as Vehicle).set_night(night)
	if boat:
		boat.visible = _boat_here()
	audio.set_mood(night, weather)


func _boat_here() -> bool:
	return Game.clock > 0.55 and Game.clock < 0.97 and int(Game.boat.get("crates", 0)) > 0


func _boat() -> void:
	boat = Node3D.new()
	var tip: Array = plan.piers[1]["tip"]
	boat.position = Vector3(tip[0] + 8.0, -0.6, tip[1])
	var hull := StandardMaterial3D.new()
	hull.albedo_color = Color("2a2522")
	var deck := StandardMaterial3D.new()
	deck.albedo_texture = load("res://assets/textures/planks_albedo.jpg")
	deck.albedo_color = Color(0.6, 0.5, 0.4)
	var cabin := StandardMaterial3D.new()
	cabin.albedo_color = Color("d8d0bc")
	for part in [[Vector3(4.5, 1.4, 13.0), Vector3(0, 0.3, 0), hull], [Vector3(4.2, 0.1, 12.4), Vector3(0, 1.05, 0), deck],
			[Vector3(2.8, 2.0, 3.6), Vector3(0, 2.1, 2.5), cabin], [Vector3(0.3, 3.0, 0.3), Vector3(0, 3.5, -2.0), hull]]:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = part[0]
		mi.mesh = bm
		mi.position = part[1]
		mi.material_override = part[2]
		boat.add_child(mi)
	var lantern := OmniLight3D.new()
	lantern.light_color = Color("ffb060")
	lantern.omni_range = 9.0
	lantern.light_energy = 2.0
	lantern.position = Vector3(0, 3.4, 0)
	boat.add_child(lantern)
	add_child(boat)


func _on_month(m: int) -> void:
	if not Net.is_host():
		return
	var r := randf()
	weather = "rain" if r < 0.3 else ("fog" if r < 0.4 else "clear")
	Net.to_all("weather", [weather])
	Net.to_all("newspaper", [m])
	if m % 3 == 0:
		Game.save_campaign()


# ------------------------------------------------------------------ the waterfront: the union, the longshoremen, the stock

func quay_warehouses() -> Array:
	var out := Game.biz.filter(func(b: Dictionary) -> bool: return b["kind"] == "warehouse")
	out.sort_custom(func(a, b) -> bool: return float(a["door"][1]) < float(b["door"][1]))
	return out


## Where the hiring boss stands: by the corner of the first warehouse on the quay, facing West St.
func union_spot() -> Array:
	var whs := quay_warehouses()
	if whs.is_empty():
		var q: Array = plan.quay_rect
		return [Vector3(float(q[0]) + 2.0, 0, float(q[1]) + 20.0), -PI * 0.5]
	var b: Dictionary = whs[0]
	var basis := Basis(Vector3.UP, float(b["yaw"]))
	return [_door(b) + basis * Vector3(-7.6, 0, 0.5), float(b["yaw"])]


func _spawn_waterfront() -> void:
	_spawn_union()
	for k in DOCKERS + 2:
		_spawn_docker(k)


func _spawn_union() -> void:
	var spot := union_spot()
	var u := _make_actor("u1")
	u.sim = true
	u.place(spot[0], spot[1])


## Longshoremen 0..DOCKERS-1 carry crates between a pier and a pile on the quay; the last two wait
## at the shape-up by the hiring boss, hoping to be picked.
func _spawn_docker(k: int) -> void:
	var d := _make_actor("d%d" % k)
	if d == null:
		return
	d.sim = true
	if k >= DOCKERS:
		var spot := union_spot()
		var basis := Basis(Vector3.UP, float(spot[1]))
		var j := k - DOCKERS
		d.place(spot[0] + basis * Vector3(1.3 + j * 0.9, 0, 1.4 + j * 0.5), float(spot[1]) + PI + 0.4 - j * 0.8)
		return
	var pier: Dictionary = plan.piers[k % plan.piers.size()]
	var zc := (float(pier["z0"]) + float(pier["z1"])) * 0.5
	var lane := -1.4 if k % 2 == 0 else 1.4
	var wx := plan.water_x
	var a := Vector3(wx + 9.0 + (k % 2) * 6.0, 0, zc + lane)
	var b := Vector3(wx - 2.5, 0, zc + lane * 0.6)
	var c := Vector3(wx - 6.5 - (k % 3), 0, zc + lane * 3.4)
	d.place(a.lerp(c, float(k) / DOCKERS), 0.0)
	d.route = [a, b, c, b]
	d.route_i = 1 if k % 2 == 0 else 3


## The chalkboard at the shape-up (everyone builds it: it's scenery).
func _shape_up_board() -> void:
	var spot := union_spot()
	var basis := Basis(Vector3.UP, float(spot[1]))
	var at: Vector3 = spot[0] + basis * Vector3(-1.3, 0, -1.1)
	var root := Node3D.new()
	root.position = at
	root.rotation.y = float(spot[1])
	add_child(root)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("3a2a1c")
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color("2f4a38")
	paint.roughness = 0.9
	for part in [[Vector3(0.1, 2.3, 0.1), Vector3(-0.72, 1.15, 0), wood], [Vector3(0.1, 2.3, 0.1), Vector3(0.72, 1.15, 0), wood],
			[Vector3(1.7, 0.95, 0.06), Vector3(0, 1.85, 0.03), paint]]:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = part[0]
		mi.mesh = bm
		mi.position = part[1]
		mi.material_override = part[2]
		root.add_child(mi)
	var l := Label3D.new()
	l.text = "LONGSHOREMEN'S\nLOCAL %s\nSHAPE-UP 7 A.M." % Game.UNION_LOCAL
	l.font_size = 40
	l.pixel_size = 0.0045
	l.outline_size = 0
	l.modulate = Color("e9dfc7")
	l.position = Vector3(0, 1.86, 0.07)
	root.add_child(l)


## Scenery for the working quay: a cargo derrick on every pier (mast, boom, a sling of crates on
## the hook) and the piles the longshoremen carry to (burlap sacks, barrels, crates on pallets).
func _quay_cargo() -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("4a3524")
	wood.roughness = 0.95
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color("2a2622")
	iron.metallic = 0.6
	iron.roughness = 0.5
	var burlap := StandardMaterial3D.new()
	burlap.albedo_color = Color("9c8660")
	burlap.roughness = 1.0
	var barrel := StandardMaterial3D.new()
	barrel.albedo_color = Color("6b4a2c")
	barrel.roughness = 0.8
	var rng := RandomNumberGenerator.new()
	rng.seed = 1921
	var wx := plan.water_x
	for pier in plan.piers:
		var zc := (float(pier["z0"]) + float(pier["z1"])) * 0.5
		# the derrick stands on the pier's north edge, boom swung out over the water
		var root := Node3D.new()
		root.position = Vector3(wx + CityPlan.PIER_LEN * 0.58, 0.2, float(pier["z0"]) + 0.8)
		root.rotation.y = rng.randf_range(-0.5, 0.2)
		add_child(root)
		_part(root, Vector3(0.34, 9.0, 0.34), Vector3(0, 4.5, 0), Vector3.ZERO, wood)
		_part(root, Vector3(0.8, 0.5, 0.8), Vector3(0, 0.25, 0), Vector3.ZERO, iron)
		# two back-stays
		_part(root, Vector3(0.12, 8.6, 0.12), Vector3(1.6, 4.3, 1.2), Vector3(-0.2, 0, 0.26), wood)
		_part(root, Vector3(0.12, 8.6, 0.12), Vector3(-1.6, 4.3, 1.2), Vector3(-0.2, 0, -0.26), wood)
		# the boom: pivots at the mast foot, leans out north-west over the slip
		var boom := Node3D.new()
		boom.position = Vector3(0, 1.2, 0)
		boom.rotation = Vector3(-0.85, 0.0, 0.0)
		root.add_child(boom)
		_part(boom, Vector3(0.22, 0.22, 8.5), Vector3(0, 0, -4.25), Vector3.ZERO, wood)
		var tip := Vector3(0, 1.2, 0) + Basis.from_euler(boom.rotation) * Vector3(0, 0, -8.5)
		var hang := 2.6
		_part(root, Vector3(0.04, hang, 0.04), tip + Vector3(0, -hang * 0.5, 0), Vector3.ZERO, iron)
		for k in 4:
			var c := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.7, 0.48, 0.6)
			c.mesh = bm
			c.material_override = Crate.material()
			c.position = tip + Vector3(-0.36 + (k % 2) * 0.72, -hang - 0.3 - (k / 2) * 0.5, 0)
			root.add_child(c)
		# the piles on the quay either side of the pier's foot
		for side in [-1.0, 1.0]:
			var at := Vector3(wx - 8.8, 0, zc + side * 4.8)
			_part(self, Vector3(2.0, 0.14, 1.6), at + Vector3(0, 0.07, 0), Vector3.ZERO, wood)
			if side < 0:
				for k in 9:
					var sack := MeshInstance3D.new()
					var sm := CapsuleMesh.new()
					sm.radius = 0.28
					sm.height = 0.95
					sack.mesh = sm
					sack.material_override = burlap
					sack.position = at + Vector3(-0.6 + (k % 3) * 0.6, 0.38 + (k / 3) * 0.42, rng.randf_range(-0.4, 0.4))
					sack.rotation = Vector3(0, rng.randf_range(-0.2, 0.2), PI * 0.5)
					add_child(sack)
			else:
				for k in 6:
					var bar := MeshInstance3D.new()
					var cm := CylinderMesh.new()
					cm.top_radius = 0.3
					cm.bottom_radius = 0.3
					cm.height = 0.85
					bar.mesh = cm
					bar.material_override = barrel
					bar.position = at + Vector3(-0.66 + (k % 3) * 0.66, 0.57 + (k / 3) * 0.86, -0.32 + (k % 2) * 0.64)
					add_child(bar)


func _part(parent: Node3D, size: Vector3, pos: Vector3, rot: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.rotation = rot
	mi.material_override = mat
	parent.add_child(mi)


## Crates stacked by the door of each warehouse on the quay: one per five in its owner's stock.
func _update_stacks() -> void:
	if _crate_mesh == null:
		_crate_mesh = BoxMesh.new()
		_crate_mesh.size = Vector3(0.72, 0.5, 0.62)
	var me := int(Game.player(Net.my_id()).get("family", -1))
	var seen_owner := {}
	for b in quay_warehouses():
		var owner := int(b["owned_by"])
		var n := 0
		if owner >= 0 and not seen_owner.has(owner):
			seen_owner[owner] = true
			n = Syndicate.stock(Game.nation, "nyc", owner)
		var want := mini(ceili(n / 5.0), STACK_MAX)
		var st: Dictionary = _stacks.get(b["id"], {})
		if st.is_empty():
			st = _make_stack(b)
			_stacks[b["id"]] = st
		if int(st["shown"]) != want:
			var crates: Array = st["crates"]
			for k in crates.size():
				(crates[k] as MeshInstance3D).visible = k < want
			st["shown"] = want
		var lab: Label3D = st["label"]
		lab.visible = owner >= 0 and owner == me
		if lab.visible:
			lab.text = "%s warehouse · %d crates" % [Game.fam(owner).get("name", ""), n]
			lab.modulate = Color(Game.fam(owner).get("color", "#e9dfc7")).lightened(0.35)


func _make_stack(b: Dictionary) -> Dictionary:
	var root := Node3D.new()
	root.position = _door(b)
	root.rotation.y = float(b["yaw"])
	add_child(root)
	var pallet_mat := StandardMaterial3D.new()
	pallet_mat.albedo_color = Color("5a4630")
	pallet_mat.roughness = 1.0
	var rng := RandomNumberGenerator.new()
	rng.seed = int(b["id"]) * 31 + 7
	var crates := []
	# four pallets against the front wall, two either side of the door; each takes 2 x 2 x 4 crates
	for g in 4:
		var side := -1.0 if g % 2 == 0 else 1.0
		var gx := side * (2.9 + (g / 2) * 1.75)
		var pal := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(1.6, 0.14, 1.4)
		pal.mesh = pm
		pal.material_override = pallet_mat
		pal.position = Vector3(gx, 0.07, -1.0)
		root.add_child(pal)
		for lvl in 4:
			for k in 4:
				var c := MeshInstance3D.new()
				c.mesh = _crate_mesh
				c.material_override = Crate.material()
				c.position = Vector3(gx - 0.39 + (k % 2) * 0.78 + rng.randf_range(-0.03, 0.03), 0.39 + lvl * 0.51,
					-1.34 + (k / 2) * 0.68 + rng.randf_range(-0.03, 0.03))
				c.rotation.y = rng.randf_range(-0.07, 0.07)
				c.visible = false
				root.add_child(c)
				crates.append(c)
	var lab := Label3D.new()
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.font_size = 44
	lab.outline_size = 10
	lab.pixel_size = 0.006
	lab.position = Vector3(0, 3.6, -0.8)
	lab.no_depth_test = true
	lab.visible = false
	root.add_child(lab)
	return {"node": root, "crates": crates, "shown": -1, "label": lab}


## The family's truck parked near a door (not being driven), or null.
func parked_truck(family: int, at: Vector3, radius: float = 9.0) -> Vehicle:
	var best: Vehicle = null
	var bd := radius
	for v in vehicles.values():
		var ve := v as Vehicle
		if ve.family != family or ve.driver != 0 or not ve.key.begins_with("t"):
			continue
		var d := Vector2(ve.position.x - at.x, ve.position.z - at.z).length()
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
	var color := Color(0, 0, 0, 0)
	var family := -1
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
		"r":
			kind = "recruit"
			for r in Game.recruits:
				if r["id"] == id:
					look = int(r["look"])
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
	if family >= 0 and not Game.fam(family).is_empty():
		color = Color(Game.fam(family)["color"])
	a.family = family
	a.ref_id = id
	var pk := kind
	if kind in ["smuggler", "dealer", "docker"]:
		pk = "recruit"
	elif kind == "unionboss":
		pk = "crew"
	a.setup(self, key, pk, look, color)
	a.kind = kind
	add_child(a)
	actors[key] = a
	return a


func _host_spawn() -> void:
	for k in PEDS:
		var a := _make_actor("n%d" % k)
		a.sim = true
		a.place(plan.node_pos(randi() % plan.nodes.size()) + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)))
	for c in Game.cops:
		var a := _make_actor("k%d" % c["id"])
		a.sim = true
		var nodes := []
		for n in plan.nodes.size():
			var p := plan.node_pos(n)
			if plan.district_at(p.x, p.z) == c["district"]:
				nodes.append(n)
		a.place(plan.node_pos(nodes[randi() % nodes.size()] if not nodes.is_empty() else 0))
	for b in Game.biz:
		if b["kind"] == "pawnshop":
			var g := _make_actor("g1")
			g.sim = true
			g.place(_near_door(b, -1.8), float(b["yaw"]))
			break
	var tip: Array = plan.piers[1]["tip"]
	var smug := _make_actor("z1")
	smug.sim = true
	smug.place(Vector3(tip[0] + 1.0, 0, tip[1]), PI * 0.5)
	_spawn_waterfront()
	for f in Game.families:
		var hq := Game.biz_by_id(int(f["hq"]))
		var door := _door(hq)
		var out := Basis(Vector3.UP, float(hq["yaw"])) * Vector3(0, 0, 1)
		var street := door + out * 5.5
		var t := Vehicle.new()
		t.setup(self, "t%d" % f["id"], "truck", Color(f["color"]))
		t.family = f["id"]
		add_child(t)
		t.sim = true
		t.place(street + out.cross(Vector3.UP) * 3.0, float(hq["yaw"]) + PI * 0.5)
		vehicles[t.key] = t
	for k in TRAFFIC:
		var v := Vehicle.new()
		var kinds := ["sedan", "sedan", "van", "taxi", "delivery", "sedan", "police"]
		v.setup(self, "v%d" % k, kinds[k % kinds.size()])
		add_child(v)
		v.sim = true
		v.lane = _lane_loop(k)
		v.place(v.lane[0], 0.0)
		vehicles[v.key] = v
	_sync_spawns()


func _lane_loop(k: int) -> Array:
	# clockwise around a rectangle of blocks, in the right-hand lane
	var i0 := k % (CityPlan.NX - 1)
	var j0 := (k * 3) % (CityPlan.NZ - 1)
	var i1 := mini(i0 + 1 + k % 2, CityPlan.NX)
	var j1 := mini(j0 + 1 + (k / 2) % 2, CityPlan.NZ)
	var P := CityPlan.PITCH
	var o := 3.0
	return [Vector3(i0 * P + o, 0, j0 * P - o), Vector3(i1 * P + o, 0, j0 * P - o),
		Vector3(i1 * P + o, 0, j1 * P + o), Vector3(i0 * P - o, 0, j1 * P + o),
		Vector3(i0 * P - o, 0, j0 * P - o)]


func _door(b: Dictionary) -> Vector3:
	return Vector3(b["door"][0], 0, b["door"][1])


func _near_door(b: Dictionary, off: float) -> Vector3:
	var basis := Basis(Vector3.UP, float(b["yaw"]))
	return _door(b) + basis * Vector3(off, 0, 0.6)


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
				var fam := Game.fam(a.family)
				var hq := Game.biz_by_id(int(fam["hq"]))
				a.place(_near_door(hq, randf_range(-1.5, 1.5)) + Basis(Vector3.UP, float(hq["yaw"])) * Vector3(0, 0, 1.4), float(hq["yaw"]))
				a.sim = key == "p%d" % Net.my_id()
				a.is_local_player = a.sim
			"a":
				var hq2 := Game.biz_by_id(int(Game.fam(a.family)["hq"]))
				a.place(_near_door(hq2, 0.0), float(hq2["yaw"]))
				a.sim = true
			"c":
				var hq3 := Game.biz_by_id(int(Game.fam(a.family)["hq"]))
				a.place(_near_door(hq3, randf_range(-3.0, 3.0)) + Basis(Vector3.UP, float(hq3["yaw"])) * Vector3(0, 0, 1.0), float(hq3["yaw"]))
				a.sim = true
			"r":
				for r in Game.recruits:
					if "r%d" % r["id"] == key:
						var ph := Game.biz_by_id(int(r["at"]))
						a.place(_near_door(ph, 1.6 if r["id"] % 2 == 0 else -1.6), float(ph["yaw"]))
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
				var fam := Game.fam(a.family)
				var hq := Game.biz_by_id(int(fam["hq"]))
				a.place(_near_door(hq, randf_range(-1.5, 1.5)) + Basis(Vector3.UP, float(hq["yaw"])) * Vector3(0, 0, 1.4), float(hq["yaw"]))
	local_actor = actor(key)
	if local_actor:
		local_actor.sim = true
		local_actor.is_local_player = true
		cam.target = local_actor
		cam.snap()


# ------------------------------------------------------------------ frame

func _process(delta: float) -> void:
	_day_light()
	rain.emitting = weather == "rain"
	if cam.camera:
		rain.global_position = cam.focus_point() + Vector3(0, 22, 0)
	if local_actor == null or not is_instance_valid(local_actor):
		_ensure_local_boss()
	city.facade_mat.set_shader_parameter("focus", cam.focus_point())
	city.facade_mat.set_shader_parameter("cam_pos", cam.camera.global_position if cam.camera else Vector3.ZERO)
	_shop_t -= delta
	if _shop_t <= 0.0:
		_shop_t = 0.5
		_update_shopkeepers()
	if Net.is_host():
		_host_tick(delta)
	_pose_t -= delta
	if _pose_t <= 0.0 and local_actor:
		_pose_t = 1.0 / POSE_HZ
		if not Net.is_host():
			_send_pose()


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
	# the smuggler only deals at night when the boat is in
	var smug := actor("z1")
	if smug:
		smug.visible = _boat_here()
	# run people over
	for v in vehicles.values():
		var veh := v as Vehicle
		if absf(veh.speed) > 6.0:
			for a in actors.values():
				var ac := a as Actor
				if ac.is_down() or ac.hidden_in_car:
					continue
				if ac.position.distance_to(veh.position + veh.forward() * 1.8) < 1.6:
					ac.hurt(45.0, null)
					ac.knock_down(6.0)
					if veh.driver != 0:
						var drv := actor("p%d" % veh.driver)
						if drv:
							crime(drv, 10.0, ac.position, "hit and run", ac.family)


func _make_snapshot() -> PackedByteArray:
	var a := {}
	for k in actors:
		var ac: Actor = actors[k]
		if ac.hidden_in_car or not ac.visible:
			continue
		a[k] = PackedFloat32Array([ac.position.x, ac.position.z, ac.yaw, ac.state, ac.speed, 1.0 if ac.carrying else 0.0])
	var v := {}
	for k in vehicles:
		var ve: Vehicle = vehicles[k]
		v[k] = PackedFloat32Array([ve.position.x, ve.position.z, ve.yaw, ve.driver, ve.load])
	var it := {}
	for id in items:
		var c: Crate = items[id]
		it[id] = PackedFloat32Array([c.position.x, c.position.z, 0.0 if c.kind == "crate" else 1.0, c.amount])
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
		ac.net_update(Vector3(d[0], 0.16, d[1]), d[2], int(d[3]), d[4], d[5] > 0.5)
		_last_seen[k] = now
	for k in actors.keys():
		if k == me:
			continue
		if now - float(_last_seen.get(k, now)) > 1.5:
			var gone: Actor = actors[k]
			if gone.state == Person.Anim.DEAD and now - float(_last_seen.get(k, now)) < 20.0:
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
			var col := Color(0, 0, 0, 0)
			if k.begins_with("t"):
				var f := Game.fam(int(k.substr(1)))
				col = Color(f.get("color", "#888888"))
			else:
				var kinds := ["sedan", "sedan", "van", "taxi", "delivery", "sedan", "police"]
				kd = kinds[int(k.substr(1)) % kinds.size()]
			ve.setup(self, k, kd, col)
			if k.begins_with("t"):
				ve.family = int(k.substr(1))
			add_child(ve)
			vehicles[k] = ve
		if ve == local_vehicle:
			continue
		ve.net_update(Vector3(d[0], 0, d[1]), d[2], int(d[3]), int(d[4]))
	var seen := {}
	for id in s["i"]:
		seen[id] = true
		var d: PackedFloat32Array = s["i"][id]
		if not items.has(id):
			var c := Crate.new()
			c.setup(id, "crate" if d[2] < 0.5 else "cash", int(d[3]))
			add_child(c)
			items[id] = c
		(items[id] as Crate).position = Vector3(d[0], 0.16, d[1])
	for id in items.keys():
		if not seen.has(id):
			(items[id] as Crate).queue_free()
			items.erase(id)
	if s.get("w", weather) != weather:
		weather = s["w"]


func _send_pose() -> void:
	var a := local_actor
	var v := local_vehicle
	var d := PackedFloat32Array([a.position.x, a.position.z, a.yaw, a.state, a.speed, 1.0 if a.carrying else 0.0,
		1.0 if v else 0.0, v.position.x if v else 0.0, v.position.z if v else 0.0, v.yaw if v else 0.0])
	Net.send_pose(d)


func _on_pose(peer: int, d: PackedFloat32Array) -> void:
	if peer == Net.my_id():
		return
	var a := actor("p%d" % peer)
	if a == null:
		return
	if a.down_t > 0.0:
		return
	a.net_update(Vector3(d[0], 0.16, d[1]), d[2], int(d[3]), d[4], d[5] > 0.5)
	a.position = a.net_pos
	a.hidden_in_car = d[6] > 0.5
	a.visible = not a.hidden_in_car
	if a.hidden_in_car:
		for v in vehicles.values():
			var ve := v as Vehicle
			if ve.driver == peer:
				ve.net_update(Vector3(d[7], 0, d[8]), d[9], peer, ve.load)
				ve.position = ve.net_pos
				ve.rotation.y = d[9]
				ve.yaw = d[9]


# ------------------------------------------------------------------ shopkeepers (local visuals)

func _update_shopkeepers() -> void:
	var focus := cam.focus_point()
	for b in Game.biz:
		if b["kind"] in ["precinct", "warehouse", "club"]:
			continue
		var door := _door(b)
		var near := door.distance_to(focus) < 48.0
		var closed: bool = int(b["closed_until"]) >= Game.month
		if near and not closed and not _shopkeepers.has(b["id"]):
			var p := Person.new()
			add_child(p)
			p.setup("shop", int(b["id"]) * 977 + 3)
			p.position = door + Vector3(0, 0.16, 0) + Basis(Vector3.UP, float(b["yaw"])) * Vector3(1.2, 0, -0.5)
			p.rotation.y = float(b["yaw"])
			p.set_motion(Person.Anim.IDLE, 0.0)
			_shopkeepers[b["id"]] = p
		elif (not near or closed) and _shopkeepers.has(b["id"]):
			(_shopkeepers[b["id"]] as Person).queue_free()
			_shopkeepers.erase(b["id"])


func shopkeeper(biz_id: int) -> Person:
	return _shopkeepers.get(biz_id) as Person


# ------------------------------------------------------------------ helpers for brains

func follow_slot(me: Actor, leader: Actor) -> Vector3:
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
	var offs := [Vector3(-1.1, 0, -1.3), Vector3(1.1, 0, -1.3), Vector3(0, 0, -2.4), Vector3(-1.8, 0, -2.6), Vector3(1.8, 0, -2.6), Vector3(0, 0, -3.6)]
	var o: Vector3 = offs[idx % offs.size()]
	return leader.position + Basis(Vector3.UP, leader.yaw) * o


func guard_offset(id: int) -> Vector3:
	var a := float(id % 7) / 7.0 * TAU
	return Vector3(cos(a), 0, sin(a)) * 1.6


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
		to.y = 0.0
		if to.length() < dist and f.dot(to.normalized()) > 0.8 and not ac.hidden_in_car:
			return true
	for o in vehicles.values():
		if o == v:
			continue
		var to := (o as Vehicle).position - v.position
		to.y = 0.0
		if to.length() < dist + 2.0 and f.dot(to.normalized()) > 0.85:
			return true
	return false


# ------------------------------------------------------------------ violence and the law (host)

func melee(att: Actor, target: Actor) -> void:
	if target == null or target.is_down():
		return
	fx_all("punch", [att.key])
	var dmg := 16.0 + att.tough * 0.12 + randf_range(-3.0, 3.0)
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
	var fwd := Vector3(sin(att.yaw), 0, cos(att.yaw))
	var best: Actor = null
	var bd := 18.0
	for a in actors.values():
		var ac := a as Actor
		if ac == att or ac.is_down() or ac.hidden_in_car or not ac.visible:
			continue
		var to := ac.position - att.position
		to.y = 0.0
		var d := to.length()
		if d < bd and fwd.dot(to / maxf(d, 0.01)) > cos(deg_to_rad(14.0)):
			bd = d
			best = ac
	crime(att, 20.0, att.position, "shots fired", -1, 40.0)
	if best:
		best.hurt(randf_range(55.0, 80.0), att, true)
		if best.family >= 0 and att.family >= 0 and best.family != att.family:
			Game.aggression(att.family, best.family, 15)


## Something illegal happened at `at`. Counts witnesses, adds heat, sends a cop after the
## perpetrator if one saw it and isn't on the family's payroll.
func crime(perp: Actor, severity: float, at: Vector3, what: String, victim_family: int = -1, radius: float = 14.0) -> void:
	if perp == null or perp.family < 0:
		return
	var civ := 0
	for a in actors.values():
		var ac := a as Actor
		if ac == perp or ac.is_down():
			continue
		var d := ac.position.distance_to(at)
		if ac.kind in ["ped", "docker"] and d < radius:
			civ += 1
			ac.scare(at, 6.0)
	for b in Game.biz:
		if b["kind"] not in ["precinct", "warehouse", "club"] and _door(b).distance_to(at) < radius * 0.6 \
				and int(b["closed_until"]) < Game.month:
			civ += 1
	var cop_saw := false
	var cop_id := -1
	var wbiz := -1
	var wd := radius * 0.6
	for b in Game.biz:
		if b["kind"] in ["precinct", "warehouse", "club"] or int(b["closed_until"]) >= Game.month:
			continue
		var dd := _door(b).distance_to(at)
		if dd < wd:
			wd = dd
			wbiz = b["id"]
	for a in actors.values():
		var ac := a as Actor
		if ac.kind != "cop" or ac.is_down():
			continue
		if ac.position.distance_to(at) < radius + 6.0 and not Game.cop_ignores(ac.ref_id, perp.family):
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
	var h := Game.report_crime(perp.family, severity, civ, cop_saw, plan.district_at(at.x, at.z), what, wbiz, cop_id, who)
	var street := plan.street_name_at(at.x, at.z)
	if what == "shots fired" and not Game.news_this_month("SHOTS FIRED"):
		Game._log("SHOTS FIRED ON %s: %d people dive for cover, police hunt a man in a dark overcoat." % [street.to_upper(), civ])
	elif what == "cop killing":
		Game._log("PATROLMAN SLAIN ON %s. The Commissioner vows to clean out the gangs." % street.to_upper())
	if perp.kind == "boss":
		var peer := int(perp.key.substr(1))
		var msg := "%s on %s: %d witness%s%s. Heat +%d." % [what.capitalize(), street, civ, "" if civ == 1 else "es",
			", and a cop saw it" if cop_saw else "", int(round(h))]
		Net.to_peer(peer, "reply", [msg, false])


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
		var at: Vector3 = truck.position if truck else boss.position
		for c in actors.values():
			var cop := c as Actor
			if cop.kind != "cop" or cop.is_down() or cop.chase != null:
				continue
			if cop.position.distance_to(at) > 9.0 or Game.cop_ignores(cop.ref_id, boss.family):
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
				Net.to_peer(peer, "reply", ["A cop blew his whistle at the truck. He's got the plates.", false])
			else:
				cop.chase = boss
				cop.chase_t = 25.0
				Net.to_peer(peer, "reply", ["\"Hey, you! What's in the box?\" A cop is coming for you.", false])
			Game.mark_dirty()


func cop_caught(cop: Actor, target: Actor) -> void:
	match target.kind:
		"boss":
			var peer := int(target.key.substr(1))
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
			drop_item("cash", a.position + Vector3(0.8, 0, 0.3), lost)
			Game.mark_dirty()
		if peer != Net.my_id():
			Net.to_peer(peer, "you_down", [a.down_t])
	fx_all("down", [a.key])


func on_killed(a: Actor, from: Actor) -> void:
	if not Net.is_host():
		return
	fx_all("die", [a.key])
	match a.kind:
		"crew":
			Game.crew_killed(a.ref_id, from.family if from else -1, plan.street_name_at(a.position.x, a.position.z))
		"cop":
			if from:
				crime(from, 70.0, a.position, "cop killing", -1, 50.0)
				for c in actors.values():
					var ac := c as Actor
					if ac.kind == "cop" and not ac.is_down():
						ac.chase = from
						ac.chase_t = 45.0
		"ped", "docker", "unionboss":
			if from:
				Game.report_crime(from.family, 25.0, 3, false, plan.district_at(a.position.x, a.position.z))
				Game._log("A MAN SHOT DEAD ON %s. Neighbours say they heard nothing." % plan.street_name_at(a.position.x, a.position.z).to_upper())
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
				# somebody else walks the streets now
				var n := _make_actor(k + "b")
				if n:
					n.sim = true
					n.place(plan.node_pos(randi() % plan.nodes.size()))
			elif k == "u1":
				_spawn_union()     # the local sends a new hiring boss
			elif k.begins_with("d"):
				_spawn_docker(int(k.substr(1)))


func drop_item(kind: String, at: Vector3, amount: int) -> void:
	if not Net.is_host():
		return
	var c := Crate.new()
	c.setup(_next_item, kind, amount)
	add_child(c)
	c.position = Vector3(at.x + randf_range(-0.3, 0.3), 0.16, at.z + randf_range(-0.3, 0.3))
	items[_next_item] = c
	_next_item += 1


func resolve_order(a: Actor, order: Dictionary) -> void:
	var r := Game.resolve_ai_order(order)
	if order["kind"] == "lean":
		fx_all("smash", [int(order["biz"])])
		crime(a, 10.0, a.position, "vandalism")
	if r.get("ok", false):
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
			var t := _in_front(me, 1.8, 70.0)
			if t:
				melee(me, t)
			else:
				fx_all("punch", [me.key])
		"shoot":
			if not Game.can_shoot(peer):
				r = {"ok": false, "msg": "No gun or no bullets. The arms dealer stands outside the pawnshop."}
			else:
				Game.fired(peer, plan.district_at(me.position.x, me.position.z))
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
				if c.position.distance_to(me.position) < 2.5:
					if c.kind == "cash":
						p["wallet"] += c.amount
						r = {"ok": true, "msg": "Picked up $%d." % c.amount}
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
				drop_item("crate", me.position + Vector3(sin(me.yaw), 0, cos(me.yaw)) * 0.8, 1)
		"truck_load", "truck_unload":
			var v: Vehicle = vehicles.get(String(args[0]))
			if v and v.position.distance_to(me.position) < 4.5:
				if v.family >= 0 and v.family != family and method == "truck_unload":
					# helping yourself to another family's booze
					Game.aggression(family, v.family, 10)
				if method == "truck_load" and me.carrying and v.load < Vehicle.MAX_LOAD:
					me.set_carry(false)
					Net.to_peer(peer, "carry", [false])
					v.set_load(v.load + 1)
				elif method == "truck_unload" and not me.carrying and v.load > 0:
					v.set_load(v.load - 1)
					me.set_carry(true)
					Net.to_peer(peer, "carry", [true])
		"enter":
			var v: Vehicle = vehicles.get(String(args[0]))
			if v and v.driver == 0 and v.lane.is_empty() and v.position.distance_to(me.position) < 4.5 and not me.carrying:
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
					var side := ve.position + Basis(Vector3.UP, ve.yaw) * Vector3(-2.0, 0, 0)
					me.hidden_in_car = false
					me.visible = true
					Net.to_peer(peer, "exit", [side.x, side.z])
		"crew_task":
			r = Game.act_crew_task(peer, int(args[0]), String(args[1]), int(args[2]))
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
				var pre := _precinct_door()
				Net.to_peer(peer, "jailed", [pre.x, pre.z, 40.0])
				r = {"ok": false, "msg": "Booked at the 14th Precinct. 40 seconds in a cell, everything on you confiscated."}
			elif choice == "run" and cop:
				cop.chase = me
				cop.chase_t = 25.0
				Game.report_crime(family, 6.0, 0, true, plan.district_at(me.position.x, me.position.z))
				r = {"ok": false, "msg": "You bolt. He's after you."}
		"toggle":
			r = Game.act_toggle(peer, String(args[0]))
		"silence":
			var ev := Game.evidence_by_id(family, int(args[0]))
			var wb := Game.biz_by_id(int(ev.get("biz", -1)))
			if wb.is_empty() or _door(wb).distance_to(me.position) > 4.0:
				r = {"ok": false, "msg": "You have to see him in person."}
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
			if _door(hq).distance_to(me.position) < 4.0:
				r = Game.act_burn_books(peer)
			else:
				r = {"ok": false, "msg": "The books are at your club."}
		"cleanup":
			r = Game.act_cleanup(peer, int(args[0]))
		"reach":
			r = Game.act_reach_rat(peer, int(args[0]))
		"gun":
			var g := actor("g1")
			if g and g.position.distance_to(me.position) < 4.0:
				r = Game.act_buy_gun(peer, String(args[0]))
			else:
				r = {"ok": false, "msg": "The dealer isn't here."}
		"nation":
			r = _nation(family, args)
		"save":
			if peer == Net.my_id():
				var path := Game.save_campaign()
				r = {"ok": path != "", "msg": "Campaign saved." if path != "" else "Could not save."}
	if not r.is_empty() and String(r.get("msg", "")) != "":
		Net.to_peer(peer, "reply", [r["msg"], r["ok"]])
	Game.mark_dirty()


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
				return {"ok": false, "msg": "The New York local is %s's to give. See him on the West St. quay, in person." % Game.UNION_BOSS}
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


func _near_river(p: Vector3) -> bool:
	for pier in plan.piers:
		var tip: Array = pier["tip"]
		if Vector2(tip[0] + 2.0 - p.x, tip[1] - p.z).length() < 4.0:
			return true
	return p.x > plan.water_x - 2.0 and p.x < plan.water_x + 0.5


func _precinct_door() -> Vector3:
	for b in Game.biz:
		if b["kind"] == "precinct":
			return _door(b)
	return Vector3.ZERO


func _in_front(me: Actor, dist: float, deg: float) -> Actor:
	var fwd := Vector3(sin(me.yaw), 0, cos(me.yaw))
	var best: Actor = null
	var bd := dist
	for a in actors.values():
		var ac := a as Actor
		if ac == me or ac.is_down() or ac.hidden_in_car or not ac.visible or ac.kind == "smuggler":
			continue
		var to := ac.position - me.position
		to.y = 0.0
		var d := to.length()
		if d < bd and fwd.dot(to / maxf(d, 0.01)) > cos(deg_to_rad(deg)):
			bd = d
			best = ac
	return best


## A player's action at a door / on a person. Validates that they are standing there.
func _act(peer: int, me: Actor, family: int, what: String, target: int, extra: Variant) -> Dictionary:
	var b := Game.biz_by_id(target)
	var near_biz := not b.is_empty() and _door(b).distance_to(me.position) < 4.0
	match what:
		"pitch", "lean", "collect", "buy", "speakeasy", "deliver", "bank_in", "bank_out", "captain", "wh_load", "wh_store", "wh_steal":
			if not near_biz:
				return {"ok": false, "msg": "You need to be at the door."}
		"union_pay", "union_drop":
			var u := actor("u1")
			if u == null or u.is_down() or u.position.distance_to(me.position) > 4.5:
				return {"ok": false, "msg": "%s isn't here." % Game.UNION_BOSS}
	match what:
		"pitch":
			var muscle := 0
			for a in actors.values():
				var ac := a as Actor
				if ac.kind == "crew" and ac.family == family and ac.position.distance_to(me.position) < 6.0:
					muscle += 1
			var r := Game.act_pitch(family, target, muscle)
			if r["ok"]:
				fx_all("yes", [])
			return r
		"lean":
			var r := Game.act_lean(family, target)
			fx_all("smash", [target])
			crime(me, 10.0, me.position, "vandalism", b["protector"])
			return r
		"collect":
			return Game.act_collect(peer, target)
		"buy":
			return Game.act_buy(family, target)
		"speakeasy":
			return Game.act_open_speakeasy(peer, target)
		"deliver":
			var n := 0
			if me.carrying:
				me.set_carry(false)
				Net.to_peer(peer, "carry", [false])
				n = 1
			for v in vehicles.values():
				var ve := v as Vehicle
				if ve.family == family and ve.load > 0 and ve.position.distance_to(_door(b)) < 9.0:
					n += ve.load
					ve.set_load(0)
			if n == 0:
				return {"ok": false, "msg": "Bring crates: carry one in, or park the truck at the door."}
			return Game.act_deliver(peer, target, n)
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
			return Game.act_bank(peer, true)
		"bank_out":
			return Game.act_bank(peer, false)
		"captain":
			return Game.act_captain(peer, String(extra))
		"hire":
			var ra := actor("r%d" % target)
			if ra == null or ra.position.distance_to(me.position) > 4.0:
				return {"ok": false, "msg": "He's not here."}
			return Game.act_hire(peer, target)
		"cop":
			var ca := actor("k%d" % target)
			if ca == null or ca.position.distance_to(me.position) > 4.0:
				return {"ok": false, "msg": ""}
			return Game.act_payroll_cop(peer, target)
		"crates":
			var z := actor("z1")
			if z == null or not _boat_here() or z.position.distance_to(me.position) > 4.5:
				return {"ok": false, "msg": "No boat tonight."}
			var r := Game.act_buy_crates(peer, int(extra))
			if r["ok"]:
				var n := int(r["msg"].split(" ")[0])
				for k in n:
					drop_item("crate", z.position + Vector3(-2.0 - (k % 3) * 0.8, 0, -1.2 + (k / 3) * 0.8), 1)
			return r
	return {"ok": false, "msg": ""}


## E at a warehouse door on the quay: load your parked truck from your stock, put the truck's
## crates into the warehouse, or help yourself to a rival's crate.
func _warehouse_act(peer: int, me: Actor, family: int, what: String, b: Dictionary) -> Dictionary:
	if b["kind"] != "warehouse":
		return {"ok": false, "msg": ""}
	var owner := int(b["owned_by"])
	var door := _door(b)
	match what:
		"wh_load", "wh_store":
			if owner != family:
				return {"ok": false, "msg": "This isn't your warehouse."}
			var truck := parked_truck(family, door, 9.0)
			if what == "wh_load":
				if truck == null:
					return {"ok": false, "msg": "Park the family truck at the door first (within a few yards)."}
				var room := Vehicle.MAX_LOAD - truck.load
				if room <= 0:
					return {"ok": false, "msg": "The truck is full: %d crates. Drive them to a speakeasy." % truck.load}
				var got := Syndicate.take_stock(Game.nation, "nyc", family, room)
				if got <= 0:
					return {"ok": false, "msg": "The warehouse is empty. Convoys landing in New York fill it (J, the country)."}
				truck.set_load(truck.load + got)
				Game.mark_dirty()
				fx_all("cheer", [me.key])
				return {"ok": true, "msg": "The boys load %d crates into the truck. %d left in %s." % [got, Syndicate.stock(Game.nation, "nyc", family), b["name"]]}
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
				return {"ok": false, "msg": "Nothing to put away: carry a crate in, or park a loaded truck at the door."}
			Game.mark_dirty()
			return {"ok": true, "msg": "%d crates stacked in %s (%d inside)." % [n, b["name"], Syndicate.stock(Game.nation, "nyc", family)]}
		"wh_steal":
			if owner < 0 or owner == family:
				return {"ok": false, "msg": ""}
			if me.carrying:
				return {"ok": false, "msg": "Your hands are full."}
			if Syndicate.take_stock(Game.nation, "nyc", owner, 1) <= 0:
				return {"ok": false, "msg": "Nothing by the door worth taking."}
			me.set_carry(true)
			Net.to_peer(peer, "carry", [true])
			crime(me, 6.0, me.position, "theft", owner)
			Game.aggression(family, owner, 8)
			Game.notice.emit(owner, "Somebody walked off with a crate from your warehouse on West St. The %s family." % Game.fam(family)["name"], "warn")
			Game.mark_dirty()
			return {"ok": true, "msg": "You lift a crate off the %s family's pallet. Their watchman saw your face." % Game.fam(owner)["name"]}
	return {"ok": false, "msg": ""}


func _seat_late_joiner(peer: int, info: Dictionary) -> void:
	var name := String(info.get("name", "Player"))
	# rejoining: take your old seat back
	for k in Game.players.keys():
		var p: Dictionary = Game.players[k]
		if p["name"] == name and not Net.roster.has(int(k)):
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
	# an AI family's boss steps aside for the new player
	var ab := actor("a%d" % fam)
	if ab:
		actors.erase(ab.key)
		ab.queue_free()
	Game.add_player(peer, name, fam)
	Game.notice.emit(-1, "%s takes over the %s family." % [name, Game.fam(fam)["name"]], "deal")
	_finish_join(peer)


func _finish_join(peer: int) -> void:
	Game.mark_dirty()
	Net.send_state(Game.get_state(), peer)
	Net.start_peer(peer)
	_sync_spawns()


# ------------------------------------------------------------------ events (everyone)

func _on_event(name: String, args: Array) -> void:
	match name:
		"fx":
			_fx(args)
		"reply":
			hud.toast(String(args[0]), "good" if bool(args[1]) else "info")
		"notice":
			var fam := int(args[0])
			var mine := int(Game.player(Net.my_id()).get("family", -2))
			if fam == -1 or fam == mine:
				hud.toast(String(args[1]), String(args[2]))
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
		"exit":
			_leave_vehicle_local(Vector3(float(args[0]), 0, float(args[1])))
		"arrest":
			hud.show_arrest(String(args[0]), int(args[1]))
		"jailed":
			if local_vehicle:
				_leave_vehicle_local()
			if local_actor:
				local_actor.set_carry(false)
				local_actor.place(Vector3(float(args[0]), 0, float(args[1])) + Vector3(0, 0, 1.5))
			hud.jail_until = Time.get_ticks_msec() / 1000.0 + float(args[2])
		"weather":
			weather = String(args[0])
		"newspaper":
			hud.show_newspaper(int(args[0]))
		"over":
			hud.show_final()
		"left":
			var a := actor("p%d" % int(args[0]))
			if a and Net.is_host():
				actors.erase(a.key)
				a.queue_free()


func _leave_vehicle_local(at: Vector3 = Vector3.INF) -> void:
	if local_vehicle == null:
		return
	var v := local_vehicle
	local_vehicle = null
	v.driver = 0
	v.sim = Net.is_host()
	v.speed = 0.0
	if at == Vector3.INF:
		at = v.position + Basis(Vector3.UP, v.yaw) * Vector3(-2.0, 0, 0)
	if local_actor:
		local_actor.hidden_in_car = false
		local_actor.visible = true
		local_actor.place(at, v.yaw)
		cam.target = local_actor
	audio.engine(false)


func _fx(args: Array) -> void:
	var kind := String(args[0])
	match kind:
		"hit", "punch", "shoot", "down", "die", "cheer", "whistle":
			var a := actor(String(args[1]))
			if a == null:
				return
			match kind:
				"hit": a.person.action("hit")
				"punch": a.person.action("punch")
				"shoot": a.person.action("shoot")
				"cheer": a.person.action("yes")
			audio.at(kind, a.position)
		"smash":
			var b := Game.biz_by_id(int(args[1]))
			if not b.is_empty():
				audio.at("smash", _door(b))
				var sk := shopkeeper(int(args[1]))
				if sk:
					sk.action("hit")
		"yes":
			pass


func _on_game_notice(family: int, text: String, kind: String) -> void:
	if Net.is_host():
		Net.to_all("notice", [family, text, kind])


func _on_state_changed() -> void:
	city.update_owners()
	_update_stacks()
	if hud:
		hud.refresh()
	if not Net.is_host():
		# clients: parked trucks and people follow the host
		pass
