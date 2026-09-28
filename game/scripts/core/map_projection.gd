class_name MapProjection
extends RefCounted
## The country map's projection. Mirrors tools/map/mapproj.py exactly, so everything drawn over
## assets/map/country_map.png (cities, routes, convoys) lands where the plate shows it.
##
## Lambert Conformal Conic on a sphere (R = 1), standard parallels 33N and 45N, origin 39N 83W.
## The map window lon -100..-52, lat 20.5..49 is sampled along its edges every FIT_STEP degrees,
## its projected bounding box is fitted into the image (uniform scale, FIT_MARGIN pixels on the
## limiting axis) and centred. UV = pixel / image size (edge convention).

const STD_PARALLEL_1 := 33.0
const STD_PARALLEL_2 := 45.0
const ORIGIN_LAT := 39.0
const CENTRAL_LON := -83.0
const WIN_LON_MIN := -100.0
const WIN_LON_MAX := -52.0
const WIN_LAT_MIN := 20.5
const WIN_LAT_MAX := 49.0
const IMAGE_W := 3600
const IMAGE_H := 2250
const ASPECT := 1.6
const FIT_MARGIN := 120.0
const FIT_STEP := 0.25
const EARTH_RADIUS_MILES := 3958.8

static var _inited := false
static var _n := 0.0
static var _f := 0.0
static var _rho0 := 0.0
static var _scale := 0.0
static var _cx := 0.0
static var _cy := 0.0


static func _init_proj() -> void:
	if _inited:
		return
	_inited = true
	var p1 := deg_to_rad(STD_PARALLEL_1)
	var p2 := deg_to_rad(STD_PARALLEL_2)
	var p0 := deg_to_rad(ORIGIN_LAT)
	_n = log(cos(p1) / cos(p2)) / log(tan(PI / 4.0 + p2 / 2.0) / tan(PI / 4.0 + p1 / 2.0))
	_f = cos(p1) * pow(tan(PI / 4.0 + p1 / 2.0), _n) / _n
	_rho0 = _f / pow(tan(PI / 4.0 + p0 / 2.0), _n)
	var xs := PackedFloat64Array()
	var ys := PackedFloat64Array()
	var steps := roundi((WIN_LON_MAX - WIN_LON_MIN) / FIT_STEP)
	for i in steps + 1:
		var lon := WIN_LON_MIN + i * FIT_STEP
		for lat in [WIN_LAT_MIN, WIN_LAT_MAX]:
			var v := lcc(lat, lon)
			xs.append(v.x)
			ys.append(v.y)
	steps = roundi((WIN_LAT_MAX - WIN_LAT_MIN) / FIT_STEP)
	for i in steps + 1:
		var lat := WIN_LAT_MIN + i * FIT_STEP
		for lon in [WIN_LON_MIN, WIN_LON_MAX]:
			var v := lcc(lat, lon)
			xs.append(v.x)
			ys.append(v.y)
	var minx := INF
	var maxx := -INF
	var miny := INF
	var maxy := -INF
	for k in xs.size():
		minx = minf(minx, xs[k])
		maxx = maxf(maxx, xs[k])
		miny = minf(miny, ys[k])
		maxy = maxf(maxy, ys[k])
	_scale = minf((IMAGE_W - 2.0 * FIT_MARGIN) / (maxx - minx), (IMAGE_H - 2.0 * FIT_MARGIN) / (maxy - miny))
	_cx = (minx + maxx) * 0.5
	_cy = (miny + maxy) * 0.5


## Unit-sphere LCC, y up.
static func lcc(lat: float, lon: float) -> Vector2:
	if not _inited:
		_init_proj()
	var rho := _f / pow(tan(PI / 4.0 + deg_to_rad(lat) / 2.0), _n)
	var th := _n * (deg_to_rad(lon) - deg_to_rad(CENTRAL_LON))
	return Vector2(rho * sin(th), _rho0 - rho * cos(th))


## Pixel on the full-size plate.
static func to_px(lat: float, lon: float) -> Vector2:
	_init_proj()
	var v := lcc(lat, lon)
	return Vector2(IMAGE_W / 2.0 + (v.x - _cx) * _scale, IMAGE_H / 2.0 - (v.y - _cy) * _scale)


## 0..1 UV on the plate (x right, y down): what Syndicate.project() returns.
static func project(lat: float, lon: float) -> Vector2:
	var p := to_px(lat, lon)
	return Vector2(p.x / IMAGE_W, p.y / IMAGE_H)


## Uniform Catmull-Rom through points (same as mapproj.catmull_rom), for smooth route lines.
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
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	out.append(points[n - 1])
	return out
