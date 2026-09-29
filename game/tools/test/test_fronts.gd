extends Node2D
## Test scene for the shopfronts and the roofs: builds the city (CityGround, InteriorArt,
## Shopfronts, CityRoofs on their own layer), sets up some families' shops, a padlocked one and a
## speakeasy, and saves a series of screenshots.
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --rendering-driver opengl3 --resolution 1600x900 --path game res://tools/test/test_fronts.tscn
## Env: OUT=dir for the PNGs (default /tmp/fronts), SHOTS=comma list of shots (default: all),
##   SUMMER=1 (café parasols). Shots: street, street_n, street08, quay, precinct, roofs, inside,
##   night, gallery, gal1..gal4, gallery_night

const SHOTS := ["street", "street_n", "street08", "quay", "precinct", "roofs", "gallery", "gal1", "gal2",
	"gal3", "gal4", "close1", "close2", "inside", "night", "gallery_night"]
const TRADES := ["grocer", "bakery", "butcher", "fish", "cafe", "restaurant", "barber", "tailor",
	"cobbler", "pawnshop", "laundry", "cigar", "hardware", "candy", "drugstore", "poolhall"]

var fronts: Shopfronts
var roofs: CityRoofs
var ground: CityGround
var inside: InteriorArt
var cam: Camera2D
var lighting: Lighting
var world_mod: CanvasModulate
var out_dir := "/tmp/fronts"


func _ready() -> void:
	Game.new_campaign({"seed": 1923, "families": 4}, [{"peer": 1, "name": "Alex", "family_name": "Vitale", "color": "#c42828"}])
	Game.running = false
	Game.clock = 0.25
	if OS.get_environment("SUMMER") != "":
		Game.month = 6
	var plan: CityPlan = Game.plan
	_setup_owners()
	_gallery_rows()
	ground = CityGround.new()
	add_child(ground)
	ground.build(plan)
	inside = InteriorArt.new()
	add_child(inside)
	inside.build(plan)
	fronts = Shopfronts.new()
	add_child(fronts)
	fronts.build(plan)
	var roofs_layer := CanvasLayer.new()
	roofs_layer.layer = W.LAYER_ROOFS
	roofs_layer.follow_viewport_enabled = true
	add_child(roofs_layer)
	roofs = CityRoofs.new()
	roofs_layer.add_child(roofs)
	roofs.build(plan)
	cam = Camera2D.new()
	add_child(cam)
	cam.make_current()
	if OS.get_environment("OUT") != "":
		out_dir = OS.get_environment("OUT")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var list: Array = SHOTS
	if OS.get_environment("SHOTS") != "":
		list = Array(OS.get_environment("SHOTS").split(","))
	for s in list:
		await _shot(String(s))
	get_tree().quit()


## Broome St. (between the Bowery and Eldridge St.): shops paying families, a padlocked one, a speakeasy.
func _setup_owners() -> void:
	_own(28, 0, -1)          # Brody's Pawn & Loan (south side of the block above) pays the Vitale
	_own(29, 1, -1)          # Byrne's Restaurant pays the Russo, and has a speakeasy in back
	Game.biz[29]["speak"] = true
	Game.biz[30]["closed_until"] = Game.month + 2     # Flanagan's Drug Store: padlocked
	_own(32, 2, 2)           # DeLuca's Drug Store: an O'Hara front
	_own(16, 0, 0)           # Messina's Grocery: a Vitale front
	Game.biz[20]["speak"] = true


func _own(id: int, prot: int, own: int) -> void:
	Game.biz[id]["protector"] = prot
	Game.biz[id]["owned_by"] = own


## Every trade side by side: the homes on both sides of Prince St. (west of Orchard St.)
## become shops for the test.
func _gallery_rows() -> void:
	var plan: CityPlan = Game.plan
	var have := {}
	for b in Game.biz:
		have[int(b["lot"])] = true
	var k := 0
	for lot in plan.lots:
		var blk: Array = lot["block"]
		var row_s: bool = int(blk[0]) <= 3 and int(blk[1]) == 0 and lot["side"] == "S"
		var row_n: bool = int(blk[0]) <= 3 and int(blk[1]) == 1 and lot["side"] == "N"
		if not (row_s or row_n) or have.has(int(lot["id"])):
			continue
		var kind: String = TRADES[k % TRADES.size()]
		lot["kind"] = kind
		lot["shop"] = true
		var id := Game.biz.size()
		Game.biz.append({"id": id, "lot": lot["id"], "name": "%s %s" % [["Greco's", "Levine's", "Quinn's", "Rosen's", "Marino's", "Katz's"][k % 6], kind.capitalize()],
			"kind": kind, "address": "", "district": lot["district"], "door": lot["door"], "yaw": lot["yaw"],
			"owner_name": "Test", "protector": [-1, 0, -1, 1, 2, -1, 3][k % 7], "rate": 50, "owned_by": 0 if k == 4 else -1,
			"value": 1000, "legit": 100, "launder": 100, "fear": 0, "defiance": 30, "envelope": 0,
			"speak": k == 5, "stock": 0, "demand": 0, "closed_until": Game.month + 1 if k == 6 else -1,
			"unpaid": 0, "hq_of": -1, "broken": [], "weak": ""})
		k += 1
	print("gallery shops: ", k)


func _at(x: float, z: float, zoom: float) -> void:
	cam.position = W.p(x, z)
	cam.zoom = Vector2(zoom, zoom)


func _night(n: float) -> void:
	fronts.set_night(n, 0.0)
	roofs.set_night(n, 0.0)
	ground.set_night(n, 0.0)
	inside.set_night(n, 0.0)
	if n > 0.0 and lighting == null:
		lighting = Lighting.new()
		add_child(lighting)
		lighting.setup(self)
		lighting.add_static(ground.lights())
		lighting.add_static(fronts.lights())
		lighting.add_static(inside.lights())
	if lighting:
		lighting.set_level(n, 0.0)


func _shot(name: String) -> void:
	# k_<kind> / n_<kind>: a close-up of the first shop of that kind, by day / by night
	if name.begins_with("k_") or name.begins_with("n_"):
		_night(1.0 if name.begins_with("n_") else 0.0)
		var kind := name.substr(2)
		for b in Game.biz:
			if b["kind"] == kind:
				var d := W.door(b) / W.M
				_at(d.x, d.y, 1.7)
				break
	match name:
		"street":
			_at(113.0, 91.0, 1.0)
		"street_n":
			_at(116.0, 101.0, 1.0)
		"street08":
			_at(114.0, 96.0, 0.8)
		"quay":
			_at(301.0, 48.0, 1.0)
		"precinct":
			_at(185.0, 120.0, 1.3)
		"roofs":
			_at(130.0, 96.0, 0.35)
		"gallery":
			_at(72.0, 48.0, 0.6)
		"gal1":
			_at(24.0, 48.0, 0.95)
		"gal2":
			_at(72.0, 48.0, 0.95)
		"gal3":
			_at(120.0, 48.0, 0.95)
		"gal4":
			_at(168.0, 48.0, 0.95)
		"close1":
			_at(20.0, 41.0, 1.6)
		"close2":
			_at(36.0, 55.0, 1.6)
		"inside":
			roofs.set_inside(int(Game.biz[29]["lot"]))
			_at(111.0, 104.0, 1.2)
		"night":
			roofs.set_inside(-1)
			_night(1.0)
			_at(114.0, 96.0, 0.9)
		"gallery_night":
			_night(1.0)
			_at(72.0, 48.0, 0.7)
	for i in 24:
		await get_tree().process_frame
	var path := "%s/%s.png" % [out_dir, name]
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)
