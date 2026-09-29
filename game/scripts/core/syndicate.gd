class_name Syndicate
extends RefCounted
## The national game: cities across the country, the smuggling routes that feed them and the
## supply infrastructure in each city. New York is the city you walk; the rest you run through
## the capos you send there.
##
## Each city: who controls how much of it (influence per family, the rest held by the local
## outfit), the men and guns each family keeps there, whether the local police are bought, its
## liquor market, and its SITES:
##   docks      the longshoremen's union local (dirty $, a monthly payroll). Boats landing at
##              your docks carry half again as much at half the risk; rivals' boats get turned
##              back (or pay you a toll under a truce).
##   warehouse  one per family per city (clean $). Crates landing in a city go into your
##              warehouse there and sell over the following months at full wholesale price, up to
##              your share of the city's thirst. Without one they're dumped on arrival at half
##              price. In New York the warehouse is physical: one of the two on the West St. quay,
##              and its crates go to your speakeasies by truck.
##   plant      a brewery or distillery ("near beer" licence, clean $): brews crates monthly into
##              your warehouse there, but it thickens the file and the dry agents can raid it.
##   yard       the freight yard (bribe the yardmaster, dirty $): your freight on any rail line
##              through that yard moves safely.
## Freight orders move crates every month along a rail line between two of your warehouses.
## Each route: a smuggling line from a source (Canada, Saint-Pierre, Rum Row, the Bahamas,
## Havana) to a city, with a capacity, a risk, a mode (truck, boat, ship, barge) and whoever
## bought the officials along it. All places carry real latitude/longitude; paths follow the
## real water and roads.
## Every month (host): convoys run, sites work, freight rolls, warehouses sell, ambushes spring,
## capos fight for influence, hits land.
##
## State lives in Game.nation (plain dicts, saved and sent with everything else).

const CITIES := [
	# id, name, lat/lon, port (dock name, "" = none), liquor demand (crates/month), local outfit,
	# plant ("brewery"/"distillery"/""), rail yard, flavour
	{"id": "nyc", "name": "New York", "lat": 40.7128, "lon": -74.0060, "port": "the West Street piers & Red Hook", "demand": 0,
		"outfit": "the Five Points boys", "plant": "brewery", "yard": true, "note": "Your streets. You walk this city."},
	{"id": "chi", "name": "Chicago", "lat": 41.8781, "lon": -87.6298, "port": "the Calumet River docks", "demand": 140,
		"outfit": "the North Side Gang", "plant": "brewery", "yard": true, "note": "The biggest thirst in America. Breweries, beer wars, Cicero."},
	{"id": "det", "name": "Detroit", "lat": 42.3314, "lon": -83.0458, "port": "the Detroit River boathouses", "demand": 80,
		"outfit": "the Purple Gang", "plant": "brewery", "yard": false, "note": "The Windsor crossing: three quarters of Canada's liquor comes over this river."},
	{"id": "phl", "name": "Philadelphia", "lat": 39.9526, "lon": -75.1652, "port": "the Delaware River piers", "demand": 70,
		"outfit": "the Duke's bootleggers", "plant": "brewery", "yard": false, "note": "Docks and breweries. The Philly cops come cheap."},
	{"id": "atl", "name": "Atlantic City", "lat": 39.3643, "lon": -74.4229, "port": "Absecon Inlet", "demand": 60,
		"outfit": "the Boardwalk machine", "plant": "", "yard": false, "note": "Rum Row lands here. The boardwalk, the hotels, the 1929 conference."},
	{"id": "bos", "name": "Boston", "lat": 42.3601, "lon": -71.0589, "port": "T Wharf", "demand": 55,
		"outfit": "the Gustin Gang", "plant": "", "yard": false, "note": "Irish wards and the harbour. Schooners from Saint-Pierre."},
	{"id": "cle", "name": "Cleveland", "lat": 41.4993, "lon": -81.6944, "port": "the Flats", "demand": 50,
		"outfit": "the Mayfield Road Mob", "plant": "distillery", "yard": false, "note": "Corn sugar and stills. Lake Erie boats."},
	{"id": "buf", "name": "Buffalo", "lat": 42.8864, "lon": -78.8784, "port": "Black Rock harbor", "demand": 45,
		"outfit": "the Black Rock rum ring", "plant": "", "yard": true, "note": "Across the Niagara from Fort Erie. Rowboats at night, the New York Central in the morning."},
	{"id": "pit", "name": "Pittsburgh", "lat": 40.4406, "lon": -79.9959, "port": "the Monongahela wharf", "demand": 55,
		"outfit": "the Hill District combine", "plant": "distillery", "yard": true, "note": "Steel-mill thirst. Stills in every hollow and the Pennsylvania Railroad through the middle."},
	{"id": "bal", "name": "Baltimore", "lat": 39.2904, "lon": -76.6122, "port": "Fells Point", "demand": 50,
		"outfit": "the Fells Point syndicate", "plant": "brewery", "yard": true, "note": "The wettest city in a dry country. The oyster boats carry more than oysters."},
	{"id": "kc", "name": "Kansas City", "lat": 39.0997, "lon": -94.5786, "port": "", "demand": 40,
		"outfit": "the Pendergast machine", "plant": "distillery", "yard": true, "note": "A wide-open town: the machine owns the police. Pay the machine and nobody sees anything."},
	{"id": "stl", "name": "St. Louis", "lat": 38.6270, "lon": -90.1994, "port": "the Mississippi levee", "demand": 60,
		"outfit": "Egan's Rats", "plant": "brewery", "yard": true, "note": "A brewery town gone dry. The levee, the rail yards, and a gang that fights over both."},
	{"id": "nola", "name": "New Orleans", "lat": 29.9511, "lon": -90.0715, "port": "the French Market wharves", "demand": 45,
		"outfit": "the Matranga clan", "plant": "distillery", "yard": true, "note": "Gulf rum and slot machines."},
	{"id": "mia", "name": "Miami", "lat": 25.7617, "lon": -80.1918, "port": "Biscayne Bay", "demand": 35,
		"outfit": "the Biscayne rum fleet", "plant": "", "yard": false, "note": "Speedboats from Bimini and Nassau. Hotels full of tourists with money."},
]
const SOURCES := [
	{"id": "mtl", "name": "Montreal", "lat": 45.5017, "lon": -73.5673, "price": 22, "note": "Distilleries across the border. The trucks come down the Champlain valley."},
	{"id": "wnd", "name": "Windsor", "lat": 42.3149, "lon": -83.0364, "price": 20, "note": "Canadian whisky, a mile across the river from Detroit."},
	{"id": "nia", "name": "Fort Erie", "lat": 42.9018, "lon": -78.9722, "price": 21, "note": "Ontario export houses on the Niagara frontier, a rowboat's pull from Buffalo."},
	{"id": "spm", "name": "Saint-Pierre", "lat": 46.7811, "lon": -56.1764, "price": 24, "note": "A French island off Newfoundland: legal liquor by the shipload."},
	{"id": "rum", "name": "Rum Row", "lat": 40.25, "lon": -73.30, "price": 28, "note": "Freighters anchored beyond the twelve-mile limit, selling to anyone with a fast boat."},
	{"id": "nas", "name": "Nassau", "lat": 25.0443, "lon": -77.3504, "price": 24, "note": "The Bahamas: British liquor, American buyers."},
	{"id": "hav", "name": "Havana", "lat": 23.1136, "lon": -82.3666, "price": 18, "note": "Cuban rum by the shipload."},
]
const ROUTES := [
	# id, source, city, mode, capacity (crates/month), base risk, officials to buy (cost), path [lat, lon]
	{"id": "champlain", "name": "Lake Champlain run", "from": "mtl", "to": "nyc", "mode": "truck", "cap": 120, "risk": 0.12, "bribe": 1500,
		"path": [[45.50, -73.57], [45.00, -73.35], [44.47, -73.21], [43.55, -73.40], [42.65, -73.75], [41.93, -73.96], [41.27, -73.94], [40.71, -74.01]]},
	{"id": "rum_row_nyc", "name": "Rum Row to New York", "from": "rum", "to": "nyc", "mode": "boat", "cap": 160, "risk": 0.16, "bribe": 2000,
		"path": [[40.25, -73.30], [40.46, -73.83], [40.60, -74.03], [40.71, -74.01]]},
	{"id": "rum_row_atl", "name": "Rum Row to Atlantic City", "from": "rum", "to": "atl", "mode": "boat", "cap": 150, "risk": 0.10, "bribe": 1200,
		"path": [[40.25, -73.30], [39.90, -73.75], [39.50, -74.10], [39.36, -74.42]]},
	{"id": "philly_docks", "name": "Delaware Bay run", "from": "rum", "to": "phl", "mode": "boat", "cap": 110, "risk": 0.12, "bribe": 1100,
		"path": [[40.25, -73.30], [39.30, -74.20], [38.93, -74.90], [39.30, -75.35], [39.73, -75.50], [39.95, -75.14]]},
	{"id": "chesapeake", "name": "Chesapeake Bay run", "from": "rum", "to": "bal", "mode": "boat", "cap": 100, "risk": 0.13, "bribe": 1000,
		"path": [[40.25, -73.30], [38.50, -74.50], [37.00, -75.90], [37.50, -76.20], [38.50, -76.40], [39.28, -76.58]]},
	{"id": "maritime", "name": "Saint-Pierre schooners", "from": "spm", "to": "bos", "mode": "ship", "cap": 90, "risk": 0.14, "bribe": 1200,
		"path": [[46.78, -56.18], [45.20, -59.50], [43.60, -65.00], [42.60, -69.00], [42.36, -71.06]]},
	{"id": "detroit_river", "name": "Detroit River crossing", "from": "wnd", "to": "det", "mode": "boat", "cap": 200, "risk": 0.10, "bribe": 1800,
		"path": [[42.31, -83.04], [42.33, -83.05]]},
	{"id": "lake_erie", "name": "Lake Erie boats", "from": "wnd", "to": "cle", "mode": "boat", "cap": 90, "risk": 0.12, "bribe": 1000,
		"path": [[42.31, -83.04], [42.10, -83.11], [41.90, -82.90], [41.60, -82.30], [41.50, -81.69]]},
	{"id": "windsor_chi", "name": "Windsor to Chicago trucks", "from": "wnd", "to": "chi", "mode": "truck", "cap": 140, "risk": 0.18, "bribe": 2200,
		"path": [[42.31, -83.04], [42.28, -83.74], [42.29, -85.59], [41.68, -86.25], [41.59, -87.35], [41.88, -87.63]]},
	{"id": "niagara", "name": "Niagara River crossing", "from": "nia", "to": "buf", "mode": "boat", "cap": 110, "risk": 0.12, "bribe": 1100,
		"path": [[42.90, -78.97], [42.89, -78.88]]},
	{"id": "nassau_mia", "name": "Nassau to Miami", "from": "nas", "to": "mia", "mode": "boat", "cap": 150, "risk": 0.10, "bribe": 900,
		"path": [[25.04, -77.35], [25.50, -78.70], [25.76, -80.19]]},
	{"id": "gulf", "name": "Havana to New Orleans", "from": "hav", "to": "nola", "mode": "ship", "cap": 120, "risk": 0.10, "bribe": 900,
		"path": [[23.11, -82.37], [24.50, -85.00], [27.50, -88.50], [29.00, -89.40], [29.95, -90.07]]},
	{"id": "gulf_kc", "name": "Up the Mississippi", "from": "hav", "to": "kc", "mode": "barge", "cap": 70, "risk": 0.15, "bribe": 800,
		"path": [[23.11, -82.37], [29.00, -89.40], [29.95, -90.07], [32.30, -90.90], [35.15, -90.05], [38.63, -90.20], [38.80, -91.50], [38.58, -92.17], [39.10, -94.58]]},
]
const RAILS := [
	# freight lines for moving crates between your own warehouses: stops (city ids, in order) and path
	{"id": "rail_nyc_chi", "name": "New York Central (Water Level Route)", "stops": ["nyc", "buf", "cle", "chi"],
		"path": [[40.71, -74.01], [42.65, -73.75], [43.05, -76.15], [43.16, -77.61], [42.89, -78.88], [41.50, -81.69], [41.65, -83.54], [41.59, -87.35], [41.88, -87.63]]},
	{"id": "rail_penn", "name": "Pennsylvania Railroad", "stops": ["nyc", "phl", "pit", "chi"],
		"path": [[40.71, -74.01], [40.22, -74.76], [39.95, -75.17], [40.04, -76.31], [40.27, -76.88], [40.52, -78.39], [40.44, -80.00], [40.80, -81.40], [41.08, -85.14], [41.88, -87.63]]},
	{"id": "rail_south", "name": "Pennsylvania & Atlantic Coast Line", "stops": ["phl", "bal", "mia"],
		"path": [[39.95, -75.17], [39.74, -75.55], [39.29, -76.61], [38.90, -77.04], [37.54, -77.44], [34.00, -81.03], [32.08, -81.09], [30.33, -81.66], [25.76, -80.19]]},
	{"id": "rail_new_haven", "name": "New Haven Railroad", "stops": ["nyc", "bos"],
		"path": [[40.71, -74.01], [41.31, -72.92], [41.82, -71.41], [42.36, -71.06]]},
	{"id": "rail_ac", "name": "Atlantic City Railroad", "stops": ["phl", "atl"],
		"path": [[39.95, -75.17], [39.60, -74.80], [39.36, -74.42]]},
	{"id": "rail_mich", "name": "Michigan Central", "stops": ["det", "chi"],
		"path": [[42.33, -83.05], [42.28, -83.74], [42.29, -85.59], [41.68, -86.25], [41.88, -87.63]]},
	{"id": "rail_alton", "name": "Chicago & Alton", "stops": ["chi", "stl"],
		"path": [[41.88, -87.63], [40.69, -89.59], [39.80, -89.64], [38.63, -90.20]]},
	{"id": "rail_mopac", "name": "Missouri Pacific", "stops": ["stl", "kc"],
		"path": [[38.63, -90.20], [38.58, -92.17], [39.10, -94.58]]},
	{"id": "rail_ic", "name": "Illinois Central", "stops": ["chi", "nola"],
		"path": [[41.88, -87.63], [40.12, -88.24], [37.00, -89.18], [35.15, -90.05], [32.30, -90.18], [29.95, -90.07]]},
]
## Mother-ship lanes, decoration for the map: the supply ships that keep Rum Row stocked.
const LANES := [
	{"from": "spm", "to": "rum", "path": [[46.78, -56.18], [44.00, -62.00], [41.50, -68.00], [40.25, -73.30]]},
	{"from": "nas", "to": "rum", "path": [[25.04, -77.35], [27.50, -77.00], [32.00, -76.50], [35.50, -74.50], [38.50, -73.50], [40.25, -73.30]]},
]

const CITY_PRICE := 70        # what a crate fetches wholesale in another city
const HIT_COST := 1500
const WAREHOUSE_CAP := 400    # crates one warehouse holds
const SPEAK_CAP := 40         # crates a speakeasy cellar takes before it's full
const PLANT_OUT := {"brewery": 30, "distillery": 20}   # crates a month
const PLANT_COST := 6         # dirty $ per crate brewed: malt, sugar, coal, drivers
const UNION_WAGE := 150       # the union local's monthly envelope (New York: 200)
const DOCK_TOLL := 4          # $ a crate a rival pays at your docks under a truce
const RIVER_COST := 500       # the longshoremen drop a rival's next shipment in the river (x2.4 without the local)

# Map projection (fallback until scripts/core/map_projection.gd exists): Lambert Conformal Conic,
# standard parallels 33N & 45N, origin 39N, central meridian 83W, window lon -100..-52, lat 20.5..49.
const PROJ_PATH := "res://scripts/core/map_projection.gd"
static var _proj: Script = null
static var _proj_checked := false
static var _lcc_box := Rect2()


static func fresh() -> Dictionary:
	var n := {"cities": {}, "routes": {}, "log": [], "freight": [], "sabotage": {}, "supply": {}, "next_order": 1}
	upgrade(n)
	return n


## Fill in anything an older save (or an older version of the data) doesn't have.
static func upgrade(n: Dictionary) -> Dictionary:
	for k in ["cities", "routes", "sabotage", "supply"]:
		if not n.has(k) or typeof(n[k]) != TYPE_DICTIONARY:
			n[k] = {}
	for k in ["log", "freight"]:
		if not n.has(k) or typeof(n[k]) != TYPE_ARRAY:
			n[k] = []
	if not n.has("next_order"):
		n["next_order"] = 1
	for c in CITIES:
		if not n["cities"].has(c["id"]):
			n["cities"][c["id"]] = {}
		var cs: Dictionary = n["cities"][c["id"]]
		for k in ["influence", "men", "guns", "capo", "heat", "wh", "sold"]:
			if not cs.has(k):
				cs[k] = {}
		for k in ["police", "docks", "yard", "plant"]:
			if not cs.has(k):
				cs[k] = -1
		if not cs.has("plant_closed"):
			cs["plant_closed"] = -1
	for r in ROUTES:
		if not n["routes"].has(r["id"]):
			n["routes"][r["id"]] = {"owner": -1, "convoys": {}, "ambush": {}, "last": ""}
	return n


static func city_def(id: String) -> Dictionary:
	for c in CITIES:
		if c["id"] == id:
			return c
	return {}


static func source_def(id: String) -> Dictionary:
	for s in SOURCES:
		if s["id"] == id:
			return s
	return {}


static func route_def(id: String) -> Dictionary:
	for r in ROUTES:
		if r["id"] == id:
			return r
	return {}


static func rail_def(id: String) -> Dictionary:
	for r in RAILS:
		if r["id"] == id:
			return r
	return {}


static func place_def(id: String) -> Dictionary:
	var c := city_def(id)
	return c if not c.is_empty() else source_def(id)


static func cname(id: String) -> String:
	return String(place_def(id).get("name", id))


# ------------------------------------------------------------------ the map

## Latitude/longitude to 0..1 map UV (x right, y down). Uses MapProjection when it's there, so
## overlays land on the baked map art; otherwise the same projection computed here.
static func project(lat: float, lon: float) -> Vector2:
	if not _proj_checked:
		_proj_checked = true
		if ResourceLoader.exists(PROJ_PATH):
			_proj = load(PROJ_PATH) as Script
	if _proj != null:
		var v = _proj.call("project", lat, lon)
		if v is Vector2:
			return v
	return _lcc_uv(lat, lon)


## Width / height of the map image the UVs refer to.
static func map_aspect() -> float:
	project(40.0, -80.0)
	if _proj != null:
		var cm: Dictionary = _proj.get_script_constant_map()
		if cm.has("ASPECT"):
			return float(cm["ASPECT"])
		if cm.has("IMAGE_SIZE"):
			var s = cm["IMAGE_SIZE"]
			if s is Vector2 or s is Vector2i:
				return float(s.x) / float(s.y)
		if cm.has("IMAGE_W") and cm.has("IMAGE_H"):
			return float(cm["IMAGE_W"]) / float(cm["IMAGE_H"])
	_lcc_bounds()
	return _lcc_box.size.x / _lcc_box.size.y


static func uv(id: String) -> Vector2:
	var p := place_def(id)
	if p.is_empty():
		return Vector2(0.5, 0.5)
	return project(float(p["lat"]), float(p["lon"]))


static func path_uv(path: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for ll in path:
		out.append(project(float(ll[0]), float(ll[1])))
	return out


static func _lcc_xy(lat: float, lon: float) -> Vector2:
	var p1 := deg_to_rad(33.0)
	var p2 := deg_to_rad(45.0)
	var n := log(cos(p1) / cos(p2)) / log(tan(PI / 4.0 + p2 / 2.0) / tan(PI / 4.0 + p1 / 2.0))
	var f := cos(p1) * pow(tan(PI / 4.0 + p1 / 2.0), n) / n
	var rho := f / pow(tan(PI / 4.0 + deg_to_rad(lat) / 2.0), n)
	var rho0 := f / pow(tan(PI / 4.0 + deg_to_rad(39.0) / 2.0), n)
	var th := n * deg_to_rad(lon + 83.0)
	return Vector2(rho * sin(th), rho0 - rho * cos(th))


static func _lcc_bounds() -> void:
	if _lcc_box.size.x > 0.0:
		return
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for k in 41:
		var t := k / 40.0
		for p in [_lcc_xy(lerpf(20.5, 49.0, t), -100.0), _lcc_xy(lerpf(20.5, 49.0, t), -52.0),
				_lcc_xy(20.5, lerpf(-100.0, -52.0, t)), _lcc_xy(49.0, lerpf(-100.0, -52.0, t))]:
			lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
			hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	var m := (hi - lo) * 0.02
	_lcc_box = Rect2(lo - m, hi - lo + m * 2.0)


static func _lcc_uv(lat: float, lon: float) -> Vector2:
	_lcc_bounds()
	var p := _lcc_xy(lat, lon)
	return Vector2((p.x - _lcc_box.position.x) / _lcc_box.size.x, 1.0 - (p.y - _lcc_box.position.y) / _lcc_box.size.y)


static func miles(path: Array) -> float:
	var d := 0.0
	for k in range(1, path.size()):
		d += _haversine(path[k - 1], path[k])
	return d


static func _haversine(a: Array, b: Array) -> float:
	var la1 := deg_to_rad(float(a[0]))
	var la2 := deg_to_rad(float(b[0]))
	var dla := la2 - la1
	var dlo := deg_to_rad(float(b[1]) - float(a[1]))
	var h := sin(dla / 2.0) * sin(dla / 2.0) + cos(la1) * cos(la2) * sin(dlo / 2.0) * sin(dlo / 2.0)
	return 3959.0 * 2.0 * asin(sqrt(minf(1.0, h)))


# ------------------------------------------------------------------ queries

static func influence(nation: Dictionary, city: String, family: int) -> float:
	return float(nation["cities"][city]["influence"].get(str(family), 0.0))


static func controller(nation: Dictionary, city: String) -> int:
	var best := -1
	var bv := 50.0
	for k in nation["cities"][city]["influence"]:
		var v := float(nation["cities"][city]["influence"][k])
		if v > bv:
			bv = v
			best = int(k)
	return best


static func men_in(nation: Dictionary, city: String, family: int) -> int:
	return int(nation["cities"][city]["men"].get(str(family), 0))


static func guns_in(nation: Dictionary, city: String, family: int) -> int:
	return int(nation["cities"][city]["guns"].get(str(family), 0))


## Strength of a family's crew in a city: men, their guns, a capo leading them.
static func muscle(nation: Dictionary, city: String, family: int) -> float:
	var men := men_in(nation, city, family)
	var guns := mini(guns_in(nation, city, family), men)
	var capo := 1.4 if nation["cities"][city]["capo"].has(str(family)) else 1.0
	return (men + guns * 1.2) * capo


static func has_wh(nation: Dictionary, city: String, family: int) -> bool:
	return nation["cities"].has(city) and nation["cities"][city]["wh"].has(str(family))


static func stock(nation: Dictionary, city: String, family: int) -> int:
	if not nation["cities"].has(city):
		return 0
	return int(nation["cities"][city]["wh"].get(str(family), 0))


static func warehouses_of(nation: Dictionary, family: int) -> Array:
	var out := []
	for c in CITIES:
		if has_wh(nation, c["id"], family):
			out.append(c["id"])
	return out


static func is_boat(route_id: String) -> bool:
	return String(route_def(route_id).get("mode", "truck")) != "truck"


## What a route can carry for a family: half again as much if it lands at that family's docks.
static func route_cap(nation: Dictionary, route_id: String, family: int) -> int:
	var d := route_def(route_id)
	var cap := int(d["cap"])
	if is_boat(route_id) and int(nation["cities"][d["to"]]["docks"]) == family and family >= 0:
		cap = int(cap * 1.5)
	return cap


## Crates a month a family's warehouse can sell in a city: its share of the thirst.
static func sell_cap(nation: Dictionary, city: String, family: int) -> int:
	var dem := int(city_def(city).get("demand", 0))
	var share := clampf(0.25 + influence(nation, city, family) / 100.0 * 0.75, 0.25, 1.0)
	return int(round(dem * share))


static func wholesale(game: Node) -> float:
	return CITY_PRICE * float(game.speak_mult) * (0.75 + 0.25 * float(game.econ))


static func warehouse_price(city: String) -> int:
	return int(snappedf(1000.0 + int(city_def(city).get("demand", 0)) * 8.0, 50.0))


static func plant_price(city: String) -> int:
	var c := city_def(city)
	var dem := int(c.get("demand", 60))
	if city == "nyc":
		dem = 120
	if c.get("plant", "") == "distillery":
		return int(snappedf(1800.0 + dem * 8.0, 50.0))
	return int(snappedf(2400.0 + dem * 10.0, 50.0))


static func union_price(nation: Dictionary, city: String, family: int) -> int:
	var base := 1500 if city == "nyc" else int(snappedf(900.0 + int(city_def(city).get("demand", 0)) * 6.0, 50.0))
	var cur := int(nation["cities"][city]["docks"])
	return int(base * 1.5) if cur >= 0 and cur != family else base


static func union_wage(city: String) -> int:
	return 200 if city == "nyc" else UNION_WAGE


static func yard_price(nation: Dictionary, city: String, family: int) -> int:
	var cur := int(nation["cities"][city]["yard"])
	return 900 + (600 if cur >= 0 and cur != family else 0)


static func rails_through(city: String) -> Array:
	return RAILS.filter(func(r: Dictionary) -> bool: return city in r["stops"])


## Rail miles between two stops of a line, measured along its path.
static func rail_miles(line: String, a: String, b: String) -> float:
	var r := rail_def(line)
	if r.is_empty():
		return 0.0
	var pa := _nearest_pt(r["path"], place_def(a))
	var pb := _nearest_pt(r["path"], place_def(b))
	var lo := mini(pa, pb)
	var hi := maxi(pa, pb)
	return miles((r["path"] as Array).slice(lo, hi + 1))


static func _nearest_pt(path: Array, p: Dictionary) -> int:
	var best := 0
	var bd := INF
	for k in path.size():
		var d := Vector2(float(path[k][0]) - float(p.get("lat", 0.0)), float(path[k][1]) - float(p.get("lon", 0.0))).length()
		if d < bd:
			bd = d
			best = k
	return best


static func freight_cost(line: String, a: String, b: String) -> int:
	return 1 + int(rail_miles(line, a, b) / 200.0)


## Chance a month's freight on a line is found: none if you own a yard on it, more for each
## rival's yardmaster along it (they tip off the dry agents).
static func freight_risk(nation: Dictionary, line: String, family: int, heat: float) -> float:
	var rivals := 0
	for s in rail_def(line).get("stops", []):
		var y := int(nation["cities"][s]["yard"])
		if y == family:
			return 0.0
		if y >= 0:
			rivals += 1
	return 0.05 + rivals * 0.05 + heat / 600.0


static func _report(nation: Dictionary, family: int, text: String) -> void:
	var s: Dictionary = nation["supply"]
	if not s.has(str(family)):
		s[str(family)] = []
	(s[str(family)] as Array).append(text)


static func _inc(f: Dictionary, key: String, amount: int) -> void:
	f["income"][key] = int(f["income"].get(key, 0)) + amount


# ------------------------------------------------------------------ orders (host, via Game)

static func send_men(game: Node, family: int, city: String, men: int, guns: int, capo_id: int) -> Dictionary:
	var n: Dictionary = game.nation
	if not n["cities"].has(city) or city == "nyc":
		return {"ok": false, "msg": "You run New York in person."}
	var f: Dictionary = game.fam(family)
	var cost := men * 250
	if f["dirty"] < cost:
		return {"ok": false, "msg": "Setting up %d men in %s costs $%d." % [men, city_def(city)["name"], cost]}
	var arsenal: Dictionary = f["arsenal"]
	guns = mini(guns, int(arsenal.get("pistol", 0)) + int(arsenal.get("tommy", 0)))
	f["dirty"] -= cost
	_take_guns(arsenal, guns)
	var c: Dictionary = n["cities"][city]
	c["men"][str(family)] = men_in(n, city, family) + men
	c["guns"][str(family)] = guns_in(n, city, family) + guns
	var msg := "%d men%s head for %s." % [men, (" with %d guns" % guns) if guns > 0 else "", city_def(city)["name"]]
	if capo_id >= 0:
		var capo: Dictionary = game.crew_by_id(capo_id)
		if not capo.is_empty() and capo["state"] == "free" and capo["family"] == family:
			capo["state"] = "away"
			capo["rank"] = "capo"
			capo["task"] = "city:" + city
			c["capo"][str(family)] = capo_id
			msg += " %s will run it." % capo["name"]
	if not c["influence"].has(str(family)):
		c["influence"][str(family)] = 3.0
	game.mark_dirty()
	return {"ok": true, "msg": msg}


static func _take_guns(arsenal: Dictionary, n: int) -> void:
	var t := mini(n, int(arsenal.get("tommy", 0)))
	arsenal["tommy"] = int(arsenal.get("tommy", 0)) - t
	arsenal["pistol"] = maxi(0, int(arsenal.get("pistol", 0)) - (n - t))


static func bribe_police(game: Node, family: int, city: String) -> Dictionary:
	var n: Dictionary = game.nation
	var f: Dictionary = game.fam(family)
	var cost := 1200 if city != "kc" else 2500
	if f["dirty"] < cost:
		return {"ok": false, "msg": "The %s police want $%d." % [city_def(city)["name"], cost]}
	f["dirty"] -= cost
	var prev: int = n["cities"][city]["police"]
	n["cities"][city]["police"] = family
	if prev >= 0 and prev != family:
		game.aggression(family, prev, 8)
	game.mark_dirty()
	return {"ok": true, "msg": "The %s police work for you now. When they raid, they raid the other families." % city_def(city)["name"]}


static func bribe_route(game: Node, family: int, route: String) -> Dictionary:
	var n: Dictionary = game.nation
	var d := route_def(route)
	var f: Dictionary = game.fam(family)
	var r: Dictionary = n["routes"][route]
	var cost := int(d["bribe"]) + (800 if int(r["owner"]) >= 0 else 0)
	if f["dirty"] < cost:
		return {"ok": false, "msg": "Buying the customs men and sheriffs along the %s costs $%d." % [d["name"], cost]}
	f["dirty"] -= cost
	var prev: int = r["owner"]
	r["owner"] = family
	if prev >= 0 and prev != family:
		game.aggression(family, prev, 12)
		game._notice(prev, "The %s family bought the %s out from under you." % [f["name"], d["name"]], "bad")
	game.mark_dirty()
	return {"ok": true, "msg": "The %s is yours. Your convoys get through. Other families pay you a toll or get stopped." % d["name"]}


static func set_convoy(game: Node, family: int, route: String, crates: int) -> Dictionary:
	var n: Dictionary = game.nation
	var d := route_def(route)
	crates = clampi(crates, 0, route_cap(n, route, family))
	n["routes"][route]["convoys"][str(family)] = crates
	game.mark_dirty()
	if crates == 0:
		return {"ok": true, "msg": "No more runs on the %s." % d["name"]}
	var where := "into your warehouse" if has_wh(n, d["to"], family) else "dumped at half price on arrival (no warehouse there)"
	if d["to"] == "nyc" and not has_wh(n, "nyc", family):
		where = "into your speakeasy cellars, the rest dumped (no warehouse on the quay)"
	return {"ok": true, "msg": "%d crates a month on the %s ($%d a crate at the source), %s." % [crates, d["name"], source_def(d["from"])["price"], where]}


static func set_ambush(game: Node, family: int, route: String, men: int) -> Dictionary:
	var n: Dictionary = game.nation
	var d := route_def(route)
	men = clampi(men, 0, 6)
	n["routes"][route]["ambush"][str(family)] = men
	game.mark_dirty()
	if men == 0:
		return {"ok": true, "msg": "Your hijackers come home from the %s." % d["name"]}
	return {"ok": true, "msg": "%d men wait on the %s for other families' trucks." % [men, d["name"]]}


static func order_hit(game: Node, family: int, city: String, target_family: int) -> Dictionary:
	var n: Dictionary = game.nation
	var f: Dictionary = game.fam(family)
	var c: Dictionary = n["cities"][city]
	if f["dirty"] < HIT_COST:
		return {"ok": false, "msg": "A contract costs $%d." % HIT_COST}
	var capo_id := int(c["capo"].get(str(target_family), -1))
	var target := "the %s family's men" % game.fam(target_family)["name"]
	if capo_id >= 0:
		target = game.crew_by_id(capo_id).get("name", target)
	f["dirty"] -= HIT_COST
	var mine := muscle(n, city, family) + 2.0
	var theirs := muscle(n, city, target_family) * 0.6 + 1.0
	var chance := clampf(0.35 + (mine - theirs) * 0.06 + int(f["arsenal"].get("tommy", 0)) * 0.03, 0.1, 0.85)
	game.aggression(family, target_family, 35)
	if randf() < chance:
		if capo_id >= 0:
			var capo: Dictionary = game.crew_by_id(capo_id)
			capo["state"] = "dead"
			c["capo"].erase(str(target_family))
		c["men"][str(target_family)] = maxi(0, men_in(n, city, target_family) - 2)
		c["influence"][str(target_family)] = influence(n, city, target_family) * 0.6
		game.add_evidence(family, "body", "The body of %s, found in %s" % [target, city_def(city)["name"]], 18.0)
		game._log("GANGLAND SLAYING IN %s: %s gunned down." % [city_def(city)["name"].to_upper(), target])
		game._notice(target_family, "%s was killed in %s. Everyone knows who ordered it." % [target, city_def(city)["name"]], "bad")
		game.mark_dirty()
		return {"ok": true, "msg": "It's done. %s won't be a problem in %s." % [target, city_def(city)["name"]]}
	c["men"][str(family)] = maxi(0, men_in(n, city, family) - 1)
	game.add_evidence(family, "witness", "A shooter who got away in %s: people saw his face" % city_def(city)["name"], 12.0)
	game._notice(target_family, "Someone tried to kill %s in %s. The %s family." % [target, city_def(city)["name"], f["name"]], "bad")
	game.mark_dirty()
	return {"ok": false, "msg": "The hit went wrong. Your shooter is dead and %s knows who sent him." % target}


# ------------------------------------------------------------------ supply sites (host, via Game)

## A warehouse in another city (New York's are bought in person on the West St. quay).
static func buy_warehouse(game: Node, family: int, city: String) -> Dictionary:
	var n: Dictionary = game.nation
	var f: Dictionary = game.fam(family)
	if city == "nyc":
		return {"ok": false, "msg": "In New York you buy one of the two warehouses on the West St. quay, in person (E at the door)."}
	if not n["cities"].has(city) or f.is_empty():
		return {"ok": false, "msg": ""}
	if has_wh(n, city, family):
		return {"ok": false, "msg": "You already have a warehouse in %s." % cname(city)}
	var price := warehouse_price(city)
	if int(f["clean"]) < price:
		return {"ok": false, "msg": "A warehouse by the %s costs $%d from your Bank (clean money)." % [_where(city), price]}
	f["clean"] -= price
	n["cities"][city]["wh"][str(family)] = 0
	game._log("The %s family's trucking company leases a warehouse in %s." % [f["name"], cname(city)])
	game.mark_dirty()
	return {"ok": true, "msg": "You own a warehouse in %s. Crates that land there now keep until they sell: about %d a month, at $%d each." % [
		cname(city), sell_cap(n, city, family), int(wholesale(game))]}


static func _where(city: String) -> String:
	var p := String(city_def(city).get("port", ""))
	return p if p != "" else "rail yards of %s" % cname(city)


static func buy_plant(game: Node, family: int, city: String) -> Dictionary:
	var n: Dictionary = game.nation
	var f: Dictionary = game.fam(family)
	var c := city_def(city)
	var kind := String(c.get("plant", ""))
	if kind == "" or f.is_empty():
		return {"ok": false, "msg": "There's no brewery or distillery to buy in %s." % cname(city)}
	var cs: Dictionary = n["cities"][city]
	var cur := int(cs["plant"])
	if cur == family:
		return {"ok": false, "msg": "The %s is already yours." % kind}
	if cur >= 0:
		return {"ok": false, "msg": "The %s family owns the %s in %s. It isn't for sale." % [game.fam(cur)["name"], kind, cname(city)]}
	var price := plant_price(city)
	if int(f["clean"]) < price:
		return {"ok": false, "msg": "The %s, with its \"near beer\" licence, costs $%d clean." % [kind, price]}
	f["clean"] -= price
	cs["plant"] = family
	cs["plant_closed"] = -1
	game._log("A %s in %s changes hands. The new owners say they'll make near beer." % [kind, cname(city)])
	game.mark_dirty()
	var into := "into your warehouse there" if has_wh(n, city, family) else "dumped at half price until you have a warehouse there"
	return {"ok": true, "msg": "The %s in %s is yours: %d crates a month (costs $%d a crate), %s. It adds heat." % [
		kind, cname(city), PLANT_OUT[kind], PLANT_COST, into]}


## Put the longshoremen's local on the payroll.
static func pay_union(game: Node, family: int, city: String) -> Dictionary:
	var n: Dictionary = game.nation
	var f: Dictionary = game.fam(family)
	var c := city_def(city)
	if String(c.get("port", "")) == "" or f.is_empty():
		return {"ok": false, "msg": "%s has no docks." % cname(city)}
	var cs: Dictionary = n["cities"][city]
	var cur := int(cs["docks"])
	if cur == family:
		return {"ok": false, "msg": "The dockworkers at %s already work for you." % c["port"]}
	var price := union_price(n, city, family)
	if int(f["dirty"]) < price:
		return {"ok": false, "msg": "The dockworkers at %s want $%d now, then $%d a month." % [c["port"], price, union_wage(city)]}
	f["dirty"] -= price
	cs["docks"] = family
	if cur >= 0:
		game.aggression(family, cur, 12)
		game._notice(cur, "The dockworkers at %s work for the %s family now, not you." % [c["port"], f["name"]], "bad")
	game.mark_dirty()
	return {"ok": true, "msg": "The dockworkers at %s work for you now ($%d a month). Your boats unload fast. Other families' boats wait, or turn back." % [
		c["port"], union_wage(city)]}


static func bribe_yard(game: Node, family: int, city: String) -> Dictionary:
	var n: Dictionary = game.nation
	var f: Dictionary = game.fam(family)
	var c := city_def(city)
	if not bool(c.get("yard", false)) or f.is_empty():
		return {"ok": false, "msg": "%s has no freight yard worth buying." % cname(city)}
	var cs: Dictionary = n["cities"][city]
	var cur := int(cs["yard"])
	if cur == family:
		return {"ok": false, "msg": "The yardmaster in %s is already yours." % cname(city)}
	var price := yard_price(n, city, family)
	if int(f["dirty"]) < price:
		return {"ok": false, "msg": "The yardmaster in %s wants $%d." % [cname(city), price]}
	f["dirty"] -= price
	cs["yard"] = family
	if cur >= 0:
		game.aggression(family, cur, 8)
		game._notice(cur, "The yardmaster in %s now takes the %s family's money." % [cname(city), f["name"]], "bad")
	game.mark_dirty()
	var lines := rails_through(city).map(func(r: Dictionary) -> String: return r["name"])
	return {"ok": true, "msg": "The %s yardmaster is yours: nobody checks your freight on the %s." % [cname(city), ", ".join(lines)]}


## Move `crates` a month from your warehouse in `from` to your warehouse in `to` along `line`
## (0 stops the order).
static func set_freight(game: Node, family: int, line: String, from: String, to: String, crates: int) -> Dictionary:
	var n: Dictionary = game.nation
	var r := rail_def(line)
	if r.is_empty() or from == to or from not in r["stops"] or to not in r["stops"]:
		return {"ok": false, "msg": "That line doesn't run there."}
	var orders: Array = n["freight"]
	var existing := {}
	for o in orders:
		if int(o["fam"]) == family and o["line"] == line and o["from"] == from and o["to"] == to:
			existing = o
	crates = clampi(crates, 0, 120)
	if crates == 0:
		if not existing.is_empty():
			orders.erase(existing)
		game.mark_dirty()
		return {"ok": true, "msg": "No more freight from %s to %s." % [cname(from), cname(to)]}
	if not has_wh(n, from, family) or not has_wh(n, to, family):
		return {"ok": false, "msg": "Freight runs between your own warehouses: you need one in %s and one in %s." % [cname(from), cname(to)]}
	if existing.is_empty():
		existing = {"id": int(n["next_order"]), "fam": family, "line": line, "from": from, "to": to, "crates": crates, "last": ""}
		n["next_order"] = int(n["next_order"]) + 1
		orders.append(existing)
	existing["crates"] = crates
	game.mark_dirty()
	var risk := freight_risk(n, line, family, float(game.fam(family)["heat"]))
	return {"ok": true, "msg": "%d crates a month from %s to %s on the %s, $%d a crate in freight%s." % [crates, cname(from), cname(to), r["name"],
		freight_cost(line, from, to), (" (a %d%% chance the cars get opened: buy a yardmaster on the line)" % int(risk * 100)) if risk > 0.0 else ", through your own yard"]}


## The longshoremen "drop" a rival's next shipment landing at these docks in the river.
static func sabotage(game: Node, family: int, city: String, target: int) -> Dictionary:
	var n: Dictionary = game.nation
	var f: Dictionary = game.fam(family)
	var t: Dictionary = game.fam(target)
	if t.is_empty() or target == family:
		return {"ok": false, "msg": ""}
	var cost := river_price(n, city, family)
	if int(f["dirty"]) < cost:
		return {"ok": false, "msg": "The dockworkers want $%d to 'drop' that cargo." % cost}
	f["dirty"] -= cost
	n["sabotage"][str(target)] = {"by": family, "city": city, "month": int(game.month)}
	if game.has_truce(family, target):
		game.aggression(family, target, 10)
	game.mark_dirty()
	return {"ok": true, "msg": "\"A shame about the %s family's cargo. Slings break. The river's deep.\" Their next boat at %s won't be unloaded." % [t["name"], city_def(city)["port"]]}


static func river_price(nation: Dictionary, city: String, family: int) -> int:
	return RIVER_COST if int(nation["cities"][city]["docks"]) == family else int(RIVER_COST * 2.4)


# ------------------------------------------------------------------ stock movement

## Crates arriving in a city. Into the family's warehouse if it has one there (overflow dumped);
## New York without a warehouse: straight into the speakeasy cellars as far as they take it;
## anything else is dumped on arrival at half price.
static func deliver(game: Node, fam: int, city: String, crates: int, what: String = "") -> void:
	var n: Dictionary = game.nation
	if crates <= 0:
		return
	var label := (what + ": ") if what != "" else ""
	if has_wh(n, city, fam):
		var room := maxi(0, WAREHOUSE_CAP - stock(n, city, fam))
		var into := mini(room, crates)
		n["cities"][city]["wh"][str(fam)] = stock(n, city, fam) + into
		_report(n, fam, "%s%d crates into the %s warehouse" % [label, into, cname(city)])
		if crates > into:
			_dump(game, fam, city, crates - into, "the warehouse is full")
		return
	if city == "nyc":
		var left := crates
		var speaks: Array = game.owned_by(fam).filter(func(b: Dictionary) -> bool:
			return b["speak"] and int(b["closed_until"]) < int(game.month))
		for b in speaks:
			var mv := mini(left, maxi(0, SPEAK_CAP - int(b["stock"])))
			b["stock"] = int(b["stock"]) + mv
			left -= mv
		if crates > left:
			_report(n, fam, "%s%d crates straight into the speakeasy cellars" % [label, crates - left])
		if left > 0:
			_dump(game, fam, city, left, "no warehouse on the quay")
		return
	_dump(game, fam, city, crates, "no warehouse there")


static func _dump(game: Node, fam: int, city: String, crates: int, why: String) -> void:
	var f: Dictionary = game.fam(fam)
	var cash := int(crates * wholesale(game) * 0.5)
	f["dirty"] += cash
	_inc(f, "wholesale", cash)
	_report(game.nation, fam, "%d crates dumped in %s at half price, $%d (%s)" % [crates, cname(city), cash, why])


static func take_stock(nation: Dictionary, city: String, fam: int, crates: int) -> int:
	var have := stock(nation, city, fam)
	var t := clampi(crates, 0, have)
	if has_wh(nation, city, fam):
		nation["cities"][city]["wh"][str(fam)] = have - t
	return t


static func put_stock(nation: Dictionary, city: String, fam: int, crates: int) -> int:
	if not has_wh(nation, city, fam):
		return 0
	var room := maxi(0, WAREHOUSE_CAP - stock(nation, city, fam))
	var t := clampi(crates, 0, room)
	nation["cities"][city]["wh"][str(fam)] = stock(nation, city, fam) + t
	return t


# ------------------------------------------------------------------ the month (host)

static func tick(game: Node) -> void:
	var n: Dictionary = game.nation
	upgrade(n)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	n["log"] = []
	n["supply"] = {}
	_run_routes(game, n, rng)
	_run_sites(game, n, rng)
	_run_freight(game, n, rng)
	_sell(game, n)
	_contest_cities(game, n, rng)
	_ai_orders(game, n, rng)
	# an accident nobody paid off in three months is forgotten
	for k in n["sabotage"].keys():
		if int(game.month) - int(n["sabotage"][k]["month"]) > 3:
			n["sabotage"].erase(k)


static func _run_routes(game: Node, n: Dictionary, rng: RandomNumberGenerator) -> void:
	for d in ROUTES:
		var r: Dictionary = n["routes"][d["id"]]
		var src := source_def(d["from"])
		var dest: String = d["to"]
		var boat := is_boat(d["id"])
		var docks := int(n["cities"][dest]["docks"]) if boat else -1
		var summary := []
		for k in r["convoys"].keys():
			var fam := int(k)
			var f: Dictionary = game.fam(fam)
			if f.is_empty() or not f["alive"]:
				continue
			var crates := mini(int(r["convoys"][k]), route_cap(n, d["id"], fam))
			if crates <= 0:
				continue
			var cost := crates * int(src["price"])
			if f["dirty"] < cost:
				crates = int(f["dirty"]) / int(src["price"])
				cost = crates * int(src["price"])
			if crates <= 0:
				continue
			f["dirty"] -= cost
			_inc(f, "convoys", cost)
			var owner: int = r["owner"]
			if owner >= 0 and owner != fam:
				if game.has_truce(owner, fam):
					var toll := int(crates * 5)
					f["dirty"] -= mini(toll, int(f["dirty"]))
					game.fam(owner)["dirty"] += toll
				elif rng.randf() < 0.35:
					game._notice(fam, "Your convoy on the %s was turned back: the %s family owns the officials there." % [d["name"], game.fam(owner)["name"]], "bad")
					game.aggression(owner, fam, 5)
					summary.append("%s turned back" % f["name"])
					continue
			# the longshoremen at the landing
			if docks >= 0 and docks != fam:
				if game.has_truce(docks, fam):
					var dt := crates * DOCK_TOLL
					f["dirty"] -= mini(dt, int(f["dirty"]))
					game.fam(docks)["dirty"] += dt
				elif rng.randf() < 0.3:
					game._notice(fam, "Your boat on the %s couldn't land: the %s family owns the union at %s." % [d["name"], game.fam(docks)["name"], city_def(dest)["port"]], "bad")
					game.aggression(docks, fam, 4)
					summary.append("%s kept off the docks" % f["name"])
					continue
			var sab: Dictionary = n["sabotage"].get(str(fam), {})
			if boat and not sab.is_empty() and sab["city"] == dest:
				n["sabotage"].erase(str(fam))
				var by := int(sab["by"])
				game._notice(fam, "Your boat at %s never got unloaded: %d crates 'fell' into the river." % [city_def(dest)["port"], crates], "bad")
				game._notice(by, "The longshoremen dropped the %s family's shipment in the river: %d crates." % [f["name"], crates], "good")
				if rng.randf() < 0.4:
					game.aggression(by, fam, 18)
					game._notice(fam, "Word on the waterfront: the %s family paid for it." % game.fam(by)["name"], "warn")
				game._log("CARGO LOST AT %s: a sling breaks, a %s family shipment sinks." % [String(city_def(dest)["port"]).to_upper(), f["name"]])
				summary.append("%s dropped in the river" % f["name"])
				continue
			var risk: float = d["risk"] * (0.4 if owner == fam else 1.0) * (0.5 if docks == fam else 1.0) + float(f["heat"]) / 400.0
			if rng.randf() < risk:
				f["heat"] += 6.0
				game._notice(fam, "Prohibition agents seized your convoy on the %s: %d crates lost." % [d["name"], crates], "bad")
				game.add_evidence(fam, "ledger", "Seized trucks on the %s, traced to your people" % d["name"], 6.0)
				summary.append("%s seized" % f["name"])
				continue
			# hijackers from other families
			var hijacked := false
			for a in r["ambush"].keys():
				var af := int(a)
				if af == fam or int(r["ambush"][a]) <= 0 or game.has_truce(af, fam):
					continue
				var ch := 0.12 * int(r["ambush"][a]) - muscle(n, dest, fam) * 0.01
				if rng.randf() < ch:
					var stolen := int(crates * 0.7)
					deliver(game, af, dest, stolen, "hijacked on the %s" % d["name"])
					game.aggression(af, fam, 14)
					game._notice(fam, "Hijacked on the %s! %d crates gone. Somebody talked." % [d["name"], stolen], "bad")
					game._notice(af, "Your men hit a %s family convoy on the %s: %d crates." % [f["name"], d["name"], stolen], "good")
					game._log("TRUCKS HIJACKED on the %s: drivers beaten, cargo gone." % d["name"])
					summary.append("%s hijacked by %s" % [f["name"], game.fam(af)["name"]])
					hijacked = true
					break
			if hijacked:
				continue
			deliver(game, fam, dest, crates, d["name"])
			summary.append("%s %d crates" % [f["name"], crates])
		r["last"] = ", ".join(summary)


static func _run_sites(game: Node, n: Dictionary, rng: RandomNumberGenerator) -> void:
	for c in CITIES:
		var id: String = c["id"]
		var cs: Dictionary = n["cities"][id]
		# the union local's envelope
		var dk := int(cs["docks"])
		if dk >= 0:
			var f: Dictionary = game.fam(dk)
			var wage := union_wage(id)
			if f.is_empty() or not f["alive"] or int(f["dirty"]) < wage:
				cs["docks"] = -1
				game._notice(dk, "The dockworkers at %s quit working for you: you didn't pay them." % c["port"], "warn")
			else:
				f["dirty"] -= wage
				_inc(f, "supply", wage)
		# the brewery or the still
		var po := int(cs["plant"])
		if po >= 0:
			var pf: Dictionary = game.fam(po)
			var kind := String(c["plant"])
			if pf.is_empty() or not pf["alive"]:
				cs["plant"] = -1
				continue
			if int(cs["plant_closed"]) >= int(game.month):
				_report(n, po, "The %s %s is padlocked until %s" % [c["name"], kind, game.date_text(int(cs["plant_closed"]) + 1)])
				continue
			var out: int = PLANT_OUT.get(kind, 20)
			out = mini(out, int(pf["dirty"]) / PLANT_COST)
			if out <= 0:
				_report(n, po, "The %s %s stood idle: no cash for malt and coal" % [c["name"], kind])
				continue
			pf["dirty"] -= out * PLANT_COST
			_inc(pf, "supply", out * PLANT_COST)
			game.add_evidence(po, "file", "The %s %s runs day and night on a near-beer licence" % [c["name"], kind], 2.0)
			var chance := (0.05 + float(pf["heat"]) / 500.0) * (0.35 if int(cs["police"]) == po else 1.0)
			if id == "kc" and int(cs["police"]) == po:
				chance *= 0.5
			if rng.randf() < chance:
				cs["plant_closed"] = int(game.month) + 2
				var seized := take_stock(n, id, po, stock(n, id, po) / 2)
				game.add_evidence(po, "ledger", "Books seized in the raid on the %s %s" % [c["name"], kind], 8.0)
				pf["heat"] = float(pf["heat"]) + 4.0
				game._log("DRY AGENTS RAID A %s %s: vats smashed, %d crates poured into the gutter." % [c["name"].to_upper(), kind.to_upper(), out + seized])
				game._notice(po, "Prohibition agents raided your %s in %s: padlocked for three months, %d crates lost." % [kind, c["name"], out + seized], "bad")
				continue
			deliver(game, po, id, out, "the %s %s" % [c["name"], kind])


static func _run_freight(game: Node, n: Dictionary, rng: RandomNumberGenerator) -> void:
	for o in (n["freight"] as Array).duplicate():
		var fam := int(o["fam"])
		var f: Dictionary = game.fam(fam)
		if f.is_empty() or not f["alive"]:
			(n["freight"] as Array).erase(o)
			continue
		var from: String = o["from"]
		var to: String = o["to"]
		if not has_wh(n, from, fam) or not has_wh(n, to, fam):
			o["last"] = "no warehouse at one end"
			continue
		var mv := mini(int(o["crates"]), stock(n, from, fam))
		mv = mini(mv, WAREHOUSE_CAP - stock(n, to, fam))
		var per := freight_cost(o["line"], from, to)
		mv = mini(mv, int(f["dirty"]) / maxi(1, per))
		if mv <= 0:
			o["last"] = "nothing to ship" if stock(n, from, fam) <= 0 else "no room or no cash"
			continue
		take_stock(n, from, fam, mv)
		f["dirty"] -= mv * per
		_inc(f, "supply", mv * per)
		if rng.randf() < freight_risk(n, o["line"], fam, float(f["heat"])):
			game.add_evidence(fam, "ledger", "Freight cars of 'machine parts' opened on the %s" % rail_def(o["line"])["name"], 5.0)
			game._notice(fam, "Dry agents opened your freight cars on the %s: %d crates seized." % [rail_def(o["line"])["name"], mv], "bad")
			o["last"] = "%d crates seized" % mv
			continue
		put_stock(n, to, fam, mv)
		o["last"] = "%d crates arrived" % mv
		_report(n, fam, "Freight %s to %s: %d crates" % [cname(from), cname(to), mv])


## Warehouses sell to the city's speakeasies and blind pigs, up to the family's share of its thirst.
## (New York's go to your own speakeasies by truck instead.)
static func _sell(game: Node, n: Dictionary) -> void:
	var price := wholesale(game)
	for c in CITIES:
		var id: String = c["id"]
		if id == "nyc":
			continue
		var cs: Dictionary = n["cities"][id]
		for k in cs["wh"].keys():
			var fam := int(k)
			var f: Dictionary = game.fam(fam)
			if f.is_empty():
				continue
			var sold := mini(int(cs["wh"][k]), sell_cap(n, id, fam))
			cs["sold"][k] = sold
			if sold <= 0:
				continue
			cs["wh"][k] = int(cs["wh"][k]) - sold
			var cash := int(sold * price)
			f["dirty"] += cash
			_inc(f, "wholesale", cash)
			_report(n, fam, "%s warehouse sold %d crates, $%d" % [c["name"], sold, cash])


static func _contest_cities(game: Node, n: Dictionary, rng: RandomNumberGenerator) -> void:
	for c in CITIES:
		var id: String = c["id"]
		if id == "nyc":
			continue
		var cs: Dictionary = n["cities"][id]
		var inf: Dictionary = cs["influence"]
		var total := 6.0   # the local outfit
		var mus := {}
		for k in cs["men"]:
			var m := muscle(n, id, int(k))
			if m > 0.0:
				mus[k] = m
				total += m
		for k in mus:
			var fam := int(k)
			var f: Dictionary = game.fam(fam)
			var target: float = mus[k] / total * 100.0
			var police_bonus := 8.0 if int(cs["police"]) == fam else 0.0
			inf[k] = clampf(lerpf(float(inf.get(k, 0.0)), target + police_bonus, 0.25), 0.0, 100.0)
			# upkeep: men abroad are paid from the stash
			var wage := int(cs["men"][k]) * 90
			if f["dirty"] >= wage:
				f["dirty"] -= wage
				f["income"]["wages"] = int(f["income"].get("wages", 0)) + wage
			else:
				cs["men"][k] = maxi(0, int(cs["men"][k]) - 1)
				game._notice(fam, "Unpaid men walked away in %s." % c["name"], "warn")
			# the city's rackets
			var take := int(float(inf[k]) / 100.0 * (c["demand"] * 9.0 + 400.0) * game.econ)
			f["dirty"] += take
			f["income"]["protection"] = int(f["income"].get("protection", 0)) + take
		for k in inf.keys():
			if not mus.has(k):
				inf[k] = maxf(0.0, float(inf[k]) - 6.0)
		# a war in the streets when two families both hold serious ground
		var big := mus.keys().filter(func(k) -> bool: return float(inf.get(k, 0.0)) > 20.0)
		if big.size() >= 2:
			var a := int(big[0])
			var b := int(big[1])
			if not game.has_truce(a, b) and rng.randf() < 0.35:
				var loser := a if mus[str(a)] < mus[str(b)] else b
				cs["men"][str(loser)] = maxi(0, int(cs["men"][str(loser)]) - 1)
				game.aggression(a if loser == b else b, loser, 6)
				game._log("SHOOTOUT IN %s: the %s and %s families fight over the city." % [c["name"].to_upper(), game.fam(a)["name"], game.fam(b)["name"]])
				game._notice(loser, "You lost a man in the fighting in %s." % c["name"], "bad")
		var ctrl := controller(n, id)
		if ctrl >= 0 and cs.get("last_ctrl", -1) != ctrl:
			game._log("THE %s FAMILY NOW RUNS %s." % [game.fam(ctrl)["name"].to_upper(), c["name"].to_upper()])
			game._notice(ctrl, "You run %s now." % c["name"], "good")
		cs["last_ctrl"] = ctrl


# ------------------------------------------------------------------ AI families

static func _ai_orders(game: Node, n: Dictionary, rng: RandomNumberGenerator) -> void:
	for f in game.families:
		if not f["ai"] or not f["alive"]:
			continue
		var id: int = f["id"]
		var net := _net_dirty(f)
		# a crew in another city once the stash can carry their wages
		if f["dirty"] > 2600 and net > 250 and rng.randf() < 0.3:
			var choices := CITIES.filter(func(c: Dictionary) -> bool: return c["id"] != "nyc")
			var home := _ai_home_route(game, n, id)
			var c: Dictionary = city_def(home["to"]) if not home.is_empty() and home["to"] != "nyc" else choices[(id * 3 + game.month) % choices.size()]
			if men_in(n, c["id"], id) < 6:
				var arsenal: Dictionary = f["arsenal"]
				arsenal["pistol"] = int(arsenal.get("pistol", 0)) + 1
				send_men(game, id, c["id"], 2, 1, -1)
		_ai_supply(game, n, rng, f)
		if f["dirty"] > 4500 and net > 400 and rng.randf() < 0.12:
			var home2 := _ai_home_route(game, n, id)
			var d2: Dictionary = home2 if not home2.is_empty() and int(n["routes"][home2["id"]]["owner"]) != id else ROUTES[rng.randi_range(0, ROUTES.size() - 1)]
			if int(n["routes"][d2["id"]]["owner"]) != id:
				bribe_route(game, id, d2["id"])
		var enemy: int = game._ai_enemy(id)
		if enemy >= 0 and rng.randf() < 0.2:
			for d3 in ROUTES:
				if int(n["routes"][d3["id"]]["convoys"].get(str(enemy), 0)) > 0:
					set_ambush(game, id, d3["id"], 2)
					break
		if enemy >= 0 and f["dirty"] > 3000 and rng.randf() < 0.08:
			for c2 in CITIES:
				if c2["id"] != "nyc" and men_in(n, c2["id"], id) > 0 and men_in(n, c2["id"], enemy) > 0:
					order_hit(game, id, c2["id"], enemy)
					break


## Last month's dirty cash flow, from the books.
static func _net_dirty(f: Dictionary) -> int:
	var inc: Dictionary = f.get("income", {})
	var plus := int(inc.get("protection", 0)) + int(inc.get("speakeasy", 0)) + int(inc.get("wholesale", 0))
	var minus := int(inc.get("wages", 0)) + int(inc.get("payroll", 0)) + int(inc.get("support", 0)) \
		+ int(inc.get("convoys", 0)) + int(inc.get("supply", 0))
	return plus - minus


## The route a family's convoys use most, out of town (nyc=false) or into New York (nyc=true).
static func _ai_home_route(_game: Node, n: Dictionary, id: int, nyc: bool = false) -> Dictionary:
	var best := {}
	var bv := 0
	for d in ROUTES:
		if (d["to"] == "nyc") != nyc:
			continue
		var v := int(n["routes"][d["id"]]["convoys"].get(str(id), 0))
		if v > bv:
			bv = v
			best = d
	return best


## Size a family's run on a route to what it can sell there, and what it can pay for.
static func _ai_size_convoy(game: Node, n: Dictionary, f: Dictionary, d: Dictionary, want: int) -> void:
	var id: int = f["id"]
	var src_price := int(source_def(d["from"])["price"])
	want = clampi(want, 0, route_cap(n, d["id"], id))
	if int(f["dirty"]) < want * src_price * 1.6:
		want = maxi(0, int(f["dirty"]) / (src_price * 2))
	if want > 0 and want < 8:
		want = 0
	var cur := int(n["routes"][d["id"]]["convoys"].get(str(id), 0))
	if absi(cur - want) >= 5 or (want == 0 and cur > 0):
		set_convoy(game, id, d["id"], want)


## AI families run their supply like a business: one home route, a warehouse where it lands,
## a plant where there's one to buy, the docks when rich, freight between their warehouses.
static func _ai_supply(game: Node, n: Dictionary, rng: RandomNumberGenerator, f: Dictionary) -> void:
	var id: int = f["id"]
	var home := _ai_home_route(game, n, id)
	if home.is_empty() and f["dirty"] > 900:
		# an out-of-town landing nobody else owns; spread the families around
		var cands := ROUTES.filter(func(d: Dictionary) -> bool:
			return d["to"] != "nyc" and (int(n["routes"][d["id"]]["owner"]) < 0 or int(n["routes"][d["id"]]["owner"]) == id))
		if cands.is_empty():
			cands = ROUTES.filter(func(d: Dictionary) -> bool: return d["to"] != "nyc")
		home = cands[(id * 5 + 1) % cands.size()]
		set_convoy(game, id, home["id"], 20)
	if not home.is_empty():
		var dest: String = home["to"]
		var want := 20
		if has_wh(n, dest, id):
			var plant := int(PLANT_OUT.get(city_def(dest)["plant"], 0)) if int(n["cities"][dest]["plant"]) == id else 0
			want = maxi(10, int(sell_cap(n, dest, id) * 1.1) - plant)
			if stock(n, dest, id) > sell_cap(n, dest, id) * 3:
				want = 0          # the warehouse is full: let it sell down (or ship it by rail)
			elif stock(n, dest, id) > sell_cap(n, dest, id) * 2:
				want = int(want * 0.5)
		_ai_size_convoy(game, n, f, home, want)
		# a warehouse where the boats land
		if not has_wh(n, dest, id) and int(f["clean"]) >= warehouse_price(dest) + 400:
			buy_warehouse(game, id, dest)
	# New York: the speakeasies need more than the night boat brings
	var speaks: Array = game.owned_by(id).filter(func(b: Dictionary) -> bool: return b["speak"])
	var thirst := 0
	for b in speaks:
		thirst += int(b["demand"])
	var nyc_route := _ai_home_route(game, n, id, true)
	if thirst > 14:
		if nyc_route.is_empty():
			var best := {}
			var bv := -INF
			for d in ROUTES:
				if d["to"] != "nyc":
					continue
				var o := int(n["routes"][d["id"]]["owner"])
				var v: float = -float(d["risk"]) * 10.0 - (3.0 if o >= 0 and o != id else 0.0) - float(source_def(d["from"])["price"]) * 0.05
				if v > bv:
					bv = v
					best = d
			nyc_route = best
		var have := stock(n, "nyc", id)
		var want_nyc := thirst - 14 - (have / 3)
		if int(n["cities"]["nyc"]["plant"]) == id:
			want_nyc -= int(PLANT_OUT["brewery"])
		_ai_size_convoy(game, n, f, nyc_route, maxi(0, want_nyc))
		if not has_wh(n, "nyc", id) and int(f["clean"]) >= 2600:
			for b in game.biz:
				if b["kind"] == "warehouse" and int(b["owned_by"]) < 0:
					game.act_buy(id, b["id"])
					break
	elif not nyc_route.is_empty():
		set_convoy(game, id, nyc_route["id"], 0)
	# a brewery or still where they have a warehouse
	for city in warehouses_of(n, id):
		var cs: Dictionary = n["cities"][city]
		if String(city_def(city).get("plant", "")) != "" and int(cs["plant"]) < 0 \
				and int(f["clean"]) >= plant_price(city) + 800 and rng.randf() < 0.25:
			buy_plant(game, id, city)
			break
	# the docks where its boats land, once the stash is fat
	for d in [home, nyc_route]:
		if d.is_empty() or not is_boat(d["id"]):
			continue
		var dc: String = d["to"]
		if int(n["cities"][dc]["docks"]) != id and int(f["dirty"]) >= union_price(n, dc, id) + 2000 \
				and _net_dirty(f) > union_wage(dc) + 200 and rng.randf() < 0.2:
			pay_union(game, id, dc)
			break
	# freight: move surplus from a full warehouse to one that sells faster
	var mine := warehouses_of(n, id)
	for line in RAILS:
		var on: Array = mine.filter(func(c: String) -> bool: return c in line["stops"])
		if on.size() < 2:
			continue
		for a in on:
			for b in on:
				if a == b:
					continue
				var has_order := (n["freight"] as Array).any(func(o: Dictionary) -> bool:
					return int(o["fam"]) == id and o["line"] == line["id"] and o["from"] == a and o["to"] == b)
				var surplus: int = stock(n, a, id) - (sell_cap(n, a, id) * 2 if a != "nyc" else 40)
				var hungry: bool = b == "nyc" or stock(n, b, id) < sell_cap(n, b, id)
				if not has_order and surplus > 20 and hungry:
					set_freight(game, id, line["id"], a, b, 20)
				elif has_order and surplus < 0:
					set_freight(game, id, line["id"], a, b, 0)
		# and buy a yardmaster on a line they ship on
		var ships := (n["freight"] as Array).any(func(o: Dictionary) -> bool: return int(o["fam"]) == id and o["line"] == line["id"])
		if ships and freight_risk(n, line["id"], id, 0.0) > 0.0 and int(f["dirty"]) > 2600 and rng.randf() < 0.3:
			for s in line["stops"]:
				if bool(city_def(s).get("yard", false)) and int(n["cities"][s]["yard"]) < 0:
					bribe_yard(game, id, s)
					break
