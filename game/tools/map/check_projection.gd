extends Node
## Projection check: draws the brief's 14 cities and 7 liquor sources with MapProjection as pure
## green dots over country_map.png in an offscreen SubViewport and saves the render.
##   xvfb-run -a godot --rendering-driver opengl3 --path game res://tools/map/check_projection.tscn -- --out=/tmp/check.png
##   python3 game/tools/map/build_map.py --debug                   # python dots (magenta)
##   python3 game/tools/map/build_map.py --check /tmp/check.png    # compares both, worst error in px

const PLACES := [
	["nyc", 40.7128, -74.0060], ["chi", 41.8781, -87.6298], ["det", 42.3314, -83.0458],
	["phl", 39.9526, -75.1652], ["atl", 39.3643, -74.4229], ["bos", 42.3601, -71.0589],
	["cle", 41.4993, -81.6944], ["buf", 42.8864, -78.8784], ["pit", 40.4406, -79.9959],
	["bal", 39.2904, -76.6122], ["kc", 39.0997, -94.5786], ["stl", 38.6270, -90.1994],
	["nola", 29.9511, -90.0715], ["mia", 25.7617, -80.1918],
	["mtl", 45.5017, -73.5673], ["wnd", 42.3149, -83.0364], ["nia", 42.9018, -78.9722],
	["spm", 46.7811, -56.1764], ["rum", 40.25, -73.30], ["nas", 25.0443, -77.3504], ["hav", 23.1136, -82.3666],
]

var out_path := "user://check_projection.png"
var view_size := Vector2(1800, 1125)


class Dots extends Node2D:
	var tex: Texture2D
	var size := Vector2.ZERO

	func _draw() -> void:
		draw_texture_rect(tex, Rect2(Vector2.ZERO, size), false)
		for p in PLACES:
			var q := MapProjection.to_rect(float(p[1]), float(p[2]), Rect2(Vector2.ZERO, size))
			draw_circle(q, 2.5 * size.x / 1800.0, Color(0, 1, 0), true, -1.0, false)


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_path = a.substr(6)
		elif a.begins_with("--width="):
			var w := float(a.substr(8))
			view_size = Vector2(w, round(w * MapProjection.IMAGE_SIZE.y / MapProjection.IMAGE_SIZE.x))
	var vp := SubViewport.new()
	vp.size = Vector2i(view_size)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	vp.msaa_2d = Viewport.MSAA_DISABLED
	add_child(vp)
	var d := Dots.new()
	d.tex = load(MapProjection.TEXTURE_PATH)
	d.size = view_size
	vp.add_child(d)
	for i in 4:
		await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.save_png(out_path)
	for p in PLACES:
		var uv := MapProjection.project(float(p[1]), float(p[2]))
		print("MAPCHECK %s uv=(%.6f, %.6f) px=(%.2f, %.2f)" % [p[0], uv.x, uv.y,
				uv.x * MapProjection.IMAGE_SIZE.x, uv.y * MapProjection.IMAGE_SIZE.y])
	print("MAPCHECK wrote ", out_path, " ", img.get_size())
	get_tree().quit()
