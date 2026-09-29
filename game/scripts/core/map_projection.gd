class_name MapProjection
extends RefCounted
## Runtime twin of game/tools/map/mapproj.py: the projection the country map plate
## (res://assets/map/country_map.png) was baked with. Same math, same constants, so anything drawn
## live over the texture (cities, routes, convoys) lands exactly on the engraved art.
##
## Lambert Conformal Conic on a sphere (R = 1), standard parallels 33N and 45N, origin 39N 83W.
## The window lon -100..-52, lat 20.5..49 is sampled along its edges every FIT_STEP degrees, its
## projected bounding box is fitted into IMAGE_SIZE with FIT_MARGIN px on the limiting axis and
## centred. UVs use the edge convention (pixel i spans [i, i+1)), i.e. the way Godot maps a texture
## onto a rect: point = rect.position + uv * rect.size.
##
## Usage:
##   var uv := MapProjection.project(40.7128, -74.0060)          # Vector2 in 0..1
##   var p := MapProjection.to_rect(lat, lon, map_rect)           # point inside a drawn rect
##   var line := MapProjection.project_list(route["waypoints"], map_rect.size)  # [[lat, lon], ...]
##   draw_polyline(MapProjection.smooth(line), color)            # same curve the plate uses

const STD_PARALLEL_1 := 33.0
const STD_PARALLEL_2 := 45.0
const ORIGIN_LAT := 39.0
const CENTRAL_LON := -83.0
const WIN_LON_MIN := -100.0
const WIN_LON_MAX := -52.0
const WIN_LAT_MIN := 20.5
const WIN_LAT_MAX := 49.0
const IMAGE_SIZE := Vector2i(3600, 2250)
const FIT_MARGIN := 120.0
const FIT_STEP := 0.25
const EARTH_RADIUS_MILES := 3958.8

const TEXTURE_PATH := "res://assets/map/country_map.jpg"
const TEXTURE_SMALL_PATH := "res://assets/map/country_map_small.png"   # 1800x1125, same UVs
## Rails, mother-ship lanes, the 12-mile limit and river-following route geometry as lat/lon lists.
const LINES_PATH := "res://assets/map/map_lines.json"

static var _ready := false
static var _n := 0.0
static var _f := 0.0
static var _rho0 := 0.0
static var _scale := 0.0
static var _cx := 0.0
static var _cy := 0.0


static func _setup() -> void:
	if _ready:
		return
	var p1 := deg_to_rad(STD_PARALLEL_1)
	var p2 := deg_to_rad(STD_PARALLEL_2)
	var p0 := deg_to_rad(ORIGIN_LAT)
	_n = log(cos(p1) / cos(p2)) / log(tan(PI / 4.0 + p2 / 2.0) / tan(PI / 4.0 + p1 / 2.0))
	_f = cos(p1) * pow(tan(PI / 4.0 + p1 / 2.0), _n) / _n
	_rho0 = _f / pow(tan(PI / 4.0 + p0 / 2.0), _n)
	var minx := INF
	var maxx := -INF
	var miny := INF
	var maxy := -INF
	var pts: Array[Array] = []
	var steps := int(round((WIN_LON_MAX - WIN_LON_MIN) / FIT_STEP))
	for i in steps + 1:
		var lon := WIN_LON_MIN + i * FIT_STEP
		pts.append([WIN_LAT_MIN, lon])
		pts.append([WIN_LAT_MAX, lon])
	steps = int(round((WIN_LAT_MAX - WIN_LAT_MIN) / FIT_STEP))
	for i in steps + 1:
		var lat := WIN_LAT_MIN + i * FIT_STEP
		pts.append([lat, WIN_LON_MIN])
		pts.append([lat, WIN_LON_MAX])
	for q in pts:
		var xy := _lcc(float(q[0]), float(q[1]))
		minx = minf(minx, xy[0])
		maxx = maxf(maxx, xy[0])
		miny = minf(miny, xy[1])
		maxy = maxf(maxy, xy[1])
	_scale = minf((IMAGE_SIZE.x - 2.0 * FIT_MARGIN) / (maxx - minx), (IMAGE_SIZE.y - 2.0 * FIT_MARGIN) / (maxy - miny))
	_cx = (minx + maxx) / 2.0
	_cy = (miny + maxy) / 2.0
	_ready = true


## Unit-sphere LCC in double precision: [x, y] with y up.
static func _lcc(lat: float, lon: float) -> PackedFloat64Array:
	var rho := _f / pow(tan(PI / 4.0 + deg_to_rad(lat) / 2.0), _n)
	var th := _n * (deg_to_rad(lon) - deg_to_rad(CENTRAL_LON))
	return PackedFloat64Array([rho * sin(th), _rho0 - rho * cos(th)])


## Pixel position on the full-size country_map.png (3600x2250), edge convention.
static func project_px(lat: float, lon: float) -> Vector2:
	_setup()
	var xy := _lcc(lat, lon)
	return Vector2(IMAGE_SIZE.x / 2.0 + (xy[0] - _cx) * _scale, IMAGE_SIZE.y / 2.0 - (xy[1] - _cy) * _scale)


## Normalized image UV (0..1) of a lat/lon on the country map texture (any of its sizes).
static func project(lat: float, lon: float) -> Vector2:
	_setup()
	var xy := _lcc(lat, lon)
	var px := IMAGE_SIZE.x / 2.0 + (xy[0] - _cx) * _scale
	var py := IMAGE_SIZE.y / 2.0 - (xy[1] - _cy) * _scale
	return Vector2(px / IMAGE_SIZE.x, py / IMAGE_SIZE.y)


## Point inside a rect the texture is drawn into (e.g. the map Control's draw rect).
static func to_rect(lat: float, lon: float, rect: Rect2) -> Vector2:
	return rect.position + project(lat, lon) * rect.size


## Project a waypoint list ([[lat, lon], ...] or [Vector2(lat, lon), ...]) and scale it:
## size = Vector2.ONE gives UVs, the texture's draw size gives local pixels.
static func project_list(waypoints: Array, size: Vector2 = Vector2.ONE, offset: Vector2 = Vector2.ZERO) -> PackedVector2Array:
	var out := PackedVector2Array()
	for w in waypoints:
		var lat: float
		var lon: float
		if w is Vector2:
			lat = w.x
			lon = w.y
		else:
			lat = float(w[0])
			lon = float(w[1])
		out.append(offset + project(lat, lon) * size)
	return out


## Inverse: UV -> Vector2(lat, lon) in degrees.
static func unproject(uv: Vector2) -> Vector2:
	_setup()
	var x := (uv.x * IMAGE_SIZE.x - IMAGE_SIZE.x / 2.0) / _scale + _cx
	var y := -(uv.y * IMAGE_SIZE.y - IMAGE_SIZE.y / 2.0) / _scale + _cy
	var rho := signf(_n) * sqrt(x * x + (_rho0 - y) * (_rho0 - y))
	var th := atan2(x, _rho0 - y)
	var lat := 2.0 * atan(pow(_f / rho, 1.0 / _n)) - PI / 2.0
	return Vector2(rad_to_deg(lat), CENTRAL_LON + rad_to_deg(th / _n))


## Projection point scale k at a latitude (1.0 on the standard parallels).
static func scale_factor(lat: float) -> float:
	_setup()
	var phi := deg_to_rad(lat)
	var rho := _f / pow(tan(PI / 4.0 + phi / 2.0), _n)
	return rho * _n / cos(phi)


## Pixels per statute mile on the full-size image at a latitude (0.899 at 39N).
## Multiply by draw_size.x / IMAGE_SIZE.x for a scaled texture.
static func px_per_mile(lat: float = 39.0) -> float:
	_setup()
	return _scale * scale_factor(lat) / EARTH_RADIUS_MILES


## Great-circle-free rough distance in miles between two lat/lons along the map (for UI text).
static func map_miles(lat_a: float, lon_a: float, lat_b: float, lon_b: float) -> float:
	var d := project_px(lat_a, lon_a).distance_to(project_px(lat_b, lon_b))
	return d / px_per_mile((lat_a + lat_b) / 2.0)


## Angle (degrees, + = clockwise) between image up and true north at a longitude.
static func convergence_deg(lon: float) -> float:
	_setup()
	return _n * (lon - CENTRAL_LON)


## Uniform Catmull-Rom through projected points, identical to mapproj.catmull_rom (the plate's
## rail and lane curves use samples = 8 and 16).
static func smooth(points: PackedVector2Array, samples: int = 8) -> PackedVector2Array:
	var n := points.size()
	if n < 3:
		return points
	var out := PackedVector2Array()
	for i in n - 1:
		var p0 := points[i - 1] if i > 0 else points[i]
		var p1 := points[i]
		var p2 := points[i + 1]
		var p3 := points[i + 2] if i + 2 < n else points[i + 1]
		for s in samples:
			var t := float(s) / samples
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
					+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	out.append(points[n - 1])
	return out


## map_lines.json as a Dictionary: {rails: {id: [[lat, lon]...]}, routes: {...}, lanes: {...},
## limit_12mi: [[[lat, lon]...]...], meta: {...}}. Empty if missing.
static func load_lines() -> Dictionary:
	if not FileAccess.file_exists(LINES_PATH):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(LINES_PATH))
	return d if d is Dictionary else {}
