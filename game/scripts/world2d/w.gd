class_name W
extends RefCounted
## Shared constants and helpers for the 2D street. Everything drawn in the world uses these, so
## the pieces built by different people line up.
##
## Units: the city plan (CityPlan, Game.biz doors) is in METRES, x east, z south. The 2D world is
## in PIXELS: world = Vector2(x, z) * M. North is up on screen, east is right.
## Light comes from the north-west: shadows fall to the south-east (down-right).

const M := 48.0                    # pixels per metre

# z_index inside the world canvas (CanvasLayer 0). Roofs live on their own layer (see World).
const Z_GROUND := -100             # asphalt, water, quay
const Z_ROAD_MARK := -96           # tracks, crossings, manholes
const Z_SIDEWALK := -92            # sidewalk slabs, curbs
const Z_FLOOR := -80               # shop interior floors
const Z_WALL := -70                # interior walls
const Z_PROP_LOW := -60            # things you walk over or past: gratings, puddles, rugs
const Z_FURNITURE := -50           # counters, shelves, tables, crates on the ground, street furniture
const Z_ITEMS := -30               # crates and cash dropped on the ground
const Z_PEOPLE := 0
const Z_CARS := 10
const Z_PROP_HIGH := 20            # lamp heads, sign brackets: above people and cars
const Z_AWNING := 30               # shop awnings over the sidewalk

# Canvas layers (World sets these up)
const LAYER_WORLD := 0             # everything above, lit by the light overlay at night
const LAYER_LIGHT := 1             # the lightmap, multiplied onto the world
const LAYER_ROOFS := 2             # roof shadows, roofs, roof props (tinted separately at night)
const LAYER_WEATHER := 3           # rain, fog (screen space)
const LAYER_HUD := 5

const WALL := 0.25                 # interior wall thickness, metres
const FAMILY_NONE := Color(0, 0, 0, 0)

static var _fonts := {}


## Plan metres -> world pixels.
static func p(x: float, z: float) -> Vector2:
	return Vector2(x, z) * M


## A plan [x, z] pair (as stored in dictionaries) -> world pixels.
static func pa(v: Array) -> Vector2:
	return Vector2(float(v[0]), float(v[1])) * M


## World pixels -> plan metres (x, z) as a Vector2.
static func to_m(v: Vector2) -> Vector2:
	return v / M


## The spot on the sidewalk just outside a business's front door, in pixels.
static func door(b: Dictionary) -> Vector2:
	return pa(b["door"])


## Unit vector pointing out of a building's front, toward its street.
## yaw 0 faces south (+y), PI north (-y), -PI/2 west (-x), PI/2 east (+x).
static func front_dir(yaw: float) -> Vector2:
	var v := Vector2(sin(yaw), cos(yaw))
	return Vector2(roundf(v.x), roundf(v.y))


## A lot's footprint in pixels (lots are axis-aligned; "size" is [width along the street, depth]).
static func lot_rect(lot: Dictionary) -> Rect2:
	var w := float(lot["size"][0])
	var d := float(lot["size"][1])
	var ext := Vector2(w, d) if absf(sin(float(lot["yaw"]))) < 0.5 else Vector2(d, w)
	var c := pa(lot["center"])
	return Rect2(c - ext * M * 0.5, ext * M)


## Rotation (radians, 0 = facing +x) for something standing in a doorway looking out.
static func facing_out(yaw: float) -> float:
	return front_dir(yaw).angle()


## A family's colour, or FAMILY_NONE.
static func fam_color(id: int) -> Color:
	var f := Game.fam(id)
	return Color(f["color"]) if not f.is_empty() else FAMILY_NONE


## Fonts for drawing in the world (multichannel SDF, so they stay sharp when the camera zooms).
##   "serif" Fraunces · "cond" Barlow Condensed bold · "sans" Barlow · "semi" Barlow semibold
##   "deco" Limelight (Art Deco signs, titles) · "fell" IM Fell (old newsprint) · "fell_sc" IM Fell small caps
static func font(name: String) -> Font:
	if _fonts.has(name):
		return _fonts[name]
	var path: String = {"serif": "res://assets/fonts/Fraunces-Variable.ttf",
		"cond": "res://assets/fonts/barlow-condensed-latin-700-normal.woff2",
		"sans": "res://assets/fonts/barlow-latin-500-normal.woff2",
		"semi": "res://assets/fonts/barlow-latin-600-normal.woff2",
		"deco": "res://assets/map/fonts/Limelight-Regular.ttf",
		"fell": "res://assets/map/fonts/IMFeENrm28P.ttf",
		"fell_sc": "res://assets/map/fonts/IMFeENsc28P.ttf"}.get(name, "res://assets/fonts/barlow-latin-500-normal.woff2")
	var base := load(path) as FontFile
	var f := base.duplicate() as FontFile
	f.multichannel_signed_distance_field = true
	f.msdf_pixel_range = 12
	f.msdf_size = 64
	_fonts[name] = f
	return f


## The same fonts for UI (normal rasterised fonts; use these in Controls).
static func ui_font(name: String) -> Font:
	var key := "ui_" + name
	if _fonts.has(key):
		return _fonts[key]
	var f: Font
	match name:
		"serif":
			var fv := FontVariation.new()
			fv.base_font = load("res://assets/fonts/Fraunces-Variable.ttf")
			fv.variation_opentype = {"wght": 650}
			f = fv
		"cond": f = load("res://assets/fonts/barlow-condensed-latin-700-normal.woff2")
		"semi": f = load("res://assets/fonts/barlow-latin-600-normal.woff2")
		"deco": f = load("res://assets/map/fonts/Limelight-Regular.ttf")
		"fell": f = load("res://assets/map/fonts/IMFeENrm28P.ttf")
		"fell_sc": f = load("res://assets/map/fonts/IMFeENsc28P.ttf")
		_: f = load("res://assets/fonts/barlow-latin-500-normal.woff2")
	_fonts[key] = f
	return f


## Deterministic random numbers for decoration (same on every machine).
static func rng(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r


## "1,250"
static func money(v: int) -> String:
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = "," + s.right(3) + out
		s = s.left(s.length() - 3)
	return ("-" if v < 0 else "") + s + out
