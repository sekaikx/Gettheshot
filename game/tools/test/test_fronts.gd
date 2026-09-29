extends Node2D
## Test scene for the shopfronts and the roofs: builds the city (CityGround + InteriorArt stubs,
## Shopfronts, CityRoofs on their own layer), sets up some families' shops and a padlocked one,
## and saves a series of screenshots.
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --rendering-driver opengl3 --path game res://tools/test/test_fronts.tscn
## Env: OUT=dir for the PNGs (default /tmp/fronts), SHOTS=comma list of shots (default: all):
##   street, street15, street06, quay, roofs, inside, night, gallery, gallery_night

const SHOTS := ["street", "street15", "street06", "quay", "roofs", "gallery", "inside", "night", "gallery_night"]

var fronts: Shopfronts
var roofs: CityRoofs
var ground: CityGround
var inside: InteriorArt
var cam: Camera2D
var world_mod: CanvasModulate
var lighting: Lighting
var out_dir := "/tmp/fronts"


func _ready() -> void:
	Game.new_campaign({"seed": 1923, "families": 4}, [{"peer": 1, "name": "Alex", "family_name": "Vitale", "color": "#c42828"}])
	Game.running = false
	Game.clock = 0.25
	var plan: CityPlan = Game.plan
	_setup_owners()
	if OS.get_environment("SHOTS").contains("gallery"):
		_gallery_kinds()
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


## Shops near the Vitale club pay families; one is padlocked; one runs a speakeasy.
func _setup_owners() -> void:
	# Broome St. between Bowery and Eldridge: the pawnshop, the restaurant and the drugstore
	_set(28, 0, -1)          # Brody's Pawn & Loan pays the Vitale
	_set(29, 1, -1)          # Byrne's Restaurant pays the Russo
	_set(30, -1, -1)
	_set(32, 2, 2)           # DeLuca's Drug Store: an O'Hara front
	Game.biz[30]["closed_until"] = Game.month + 2     # Flanagan's Drug Store: padlocked
	Game.biz[29]["speak"] = true
	Game.biz[16]["owned_by"] = 0                        # Messina's Grocery: a Vitale front
	Game.biz[20]["speak"] = true


func _set(id: int, prot: int, own: int) -> void:
	Game.biz[id]["protector"] = prot
	Game.biz[id]["owned_by"] = own


## Every trade on one stretch of street, for a side-by-side look.
func _gallery_kinds() -> void:
	var trades := ["grocer", "bakery", "butcher", "fish", "cafe", "restaurant", "barber", "tailor",
		"cobbler", "pawnshop", "laundry", "cigar", "hardware", "candy", "drugstore", "poolhall"]
	var k := 0
	for id in [21, 22, 23, 24, 25, 26, 36, 37, 38, 49, 50, 60, 61, 62, 9, 10]:
		if k < trades.size():
			Game.biz[id]["kind"] = trades[k]
			Game.plan.lots[int(Game.biz[id]["lot"])]["kind"] = trades[k]
			k += 1


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
	match name:
		"street":
			_at(116.0, 96.0, 1.0)
		"street15":
			_at(112.0, 92.0, 1.5)
		"street06":
			_at(90.0, 120.0, 0.6)
		"quay":
			_at(292.0, 48.0, 0.8)
		"roofs":
			_at(130.0, 96.0, 0.35)
		"gallery":
			_at(150.0, 22.0, 0.6)
		"inside":
			roofs.set_inside(int(Game.biz[29]["lot"]))
			_at(111.0, 100.0, 1.2)
		"night":
			roofs.set_inside(-1)
			_night(1.0)
			_at(116.0, 96.0, 0.9)
		"gallery_night":
			_night(1.0)
			_at(150.0, 22.0, 0.6)
	for i in 24:
		await get_tree().process_frame
	var path := "%s/%s.png" % [out_dir, name]
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)
