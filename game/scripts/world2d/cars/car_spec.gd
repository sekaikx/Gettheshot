class_name CarSpec
extends RefCounted
## The measurements of each vehicle, in metres, in the car's frame: x forward (nose at +x),
## y to the right (+y), centred on the middle of the car. Front end (bumper, lamps, radiator, hood,
## front fenders, running boards) is shared by every kind; the back is what makes each one.
##   fa / ra      front and rear axle x          tr / tw     tyre radius and width
##   track        half the distance between the tyres (dual: the pair's centre)
##   bump         front bumper x, bw its half width     rbump   rear bumper x
##   lamp         [x, y, r] headlamp                   rad     [x0, x1, half width] radiator shell
##   hood         [x0, x1, hw at the cowl, hw at the radiator]
##   cowl         [x0, x1, hw at the back]            ws      [x0, x1, hw] windscreen
##   ff / rf      fender [x0, x1, y in, y out]        rb      running board [x0, x1, y in, y out]
##   tub          body at the belt [x0, x1, hw, rear corner radius]
##   roof         [x0, x1, hw, front radius, back radius]
##   spare        [x, half thickness, radius] (the spare on the back), tail [x, y] (left side = -y)
##   h_low, h_top shadow heights (the body, the tallest part)

const TRADES := {
	"bakery": {"word": "BAKERY", "sub": "FRESH BREAD DAILY", "box": Color("ddcfae"), "ink": Color("6a3a1e"), "cab": Color("4e3424"), "trim": Color("a8742e")},
	"laundry": {"word": "LAUNDRY", "sub": "WASH  ·  IRON  ·  MEND", "box": Color("9eb39a"), "ink": Color("1e3526"), "cab": Color("24392c"), "trim": Color("e6dcc3")},
	"ice": {"word": "ICE", "sub": "PURE CRYSTAL ICE CO.", "box": Color("cddbe0"), "ink": Color("1f3550"), "cab": Color("1f2e44"), "trim": Color("7a9ab0")},
	"coal": {"word": "COAL", "sub": "COAL  &  COKE  ·  EST. 1898", "box": Color("262422"), "ink": Color("d9b25a"), "cab": Color("1c1b1a"), "trim": Color("8a6a2a")},
	"milk": {"word": "MILK", "sub": "GRADE A  ·  FROM THE FARM", "box": Color("e6e1d4"), "ink": Color("2a4674"), "cab": Color("2a3a5a"), "trim": Color("b83a2e")},
	"seltzer": {"word": "SELTZER", "sub": "DELIVERED TO YOUR DOOR", "box": Color("7a2e2a"), "ink": Color("efe3c6"), "cab": Color("3e1c1a"), "trim": Color("d9b25a")},
	"flowers": {"word": "FLOWERS", "sub": "WEDDINGS  ·  FUNERALS", "box": Color("5a3a5a"), "ink": Color("f0dcc0"), "cab": Color("2e2230"), "trim": Color("c9a54a")},
}
const TRADE_ORDER := ["bakery", "laundry", "ice", "coal", "milk", "seltzer", "flowers"]


static func make(kind: String) -> Dictionary:
	var s := {
		"fa": 1.30, "ra": -1.30, "tr": 0.36, "tw": 0.13, "track": 0.72, "dual": false,
		"bump": 2.11, "bw": 0.80, "rbump": -2.11,
		"lamp": [1.95, 0.52, 0.12], "rad": [1.80, 1.94, 0.33],
		"hood": [0.62, 1.80, 0.45, 0.35], "cowl": [0.40, 0.62, 0.64], "ws": [0.33, 0.40, 0.62],
		"ff": [0.55, 2.02, 0.55, 0.89], "rf": [-1.97, -0.60, 0.57, 0.89], "rb": [-0.66, 0.62, 0.64, 0.86],
		"tub": [-1.88, 0.62, 0.66, 0.36], "roof": [-1.30, 0.36, 0.60, 0.14, 0.30],
		"spare": [-2.00, 0.075, 0.36], "tail": [-1.99, -0.76],
		"h_low": 0.85, "h_top": 1.72, "louvres": 12,
	}
	match kind:
		"taxi":
			# a Checker: boxier, a taller roof carried further forward
			s["roof"] = [-1.34, 0.34, 0.62, 0.08, 0.16]
			s["tub"] = [-1.90, 0.62, 0.68, 0.24]
			s["h_top"] = 1.82
		"police":
			s["louvres"] = 12
		"touring":
			# a long-hood phaeton: side-mounted spares, open tub, a trunk on the rack
			s["fa"] = 1.42
			s["ra"] = -1.36
			s["bump"] = 2.21
			s["rbump"] = -2.20
			s["lamp"] = [2.05, 0.52, 0.13]
			s["rad"] = [1.93, 2.06, 0.32]
			s["hood"] = [0.52, 1.93, 0.45, 0.33]
			s["cowl"] = [0.30, 0.52, 0.66]
			s["ws"] = [0.26, 0.31, 0.63]
			s["ff"] = [0.30, 2.12, 0.55, 0.89]
			s["rf"] = [-2.02, -0.66, 0.57, 0.89]
			s["rb"] = [-0.72, 0.36, 0.64, 0.86]
			s["tub"] = [-1.96, 0.52, 0.68, 0.34]
			s["roof"] = []
			s["spare"] = []
			s["tail"] = [-2.02, -0.76]
			s["h_top"] = 1.35
			s["louvres"] = 18
		"van":
			# a panel delivery on the car chassis: one long roof from the windscreen back
			s["fa"] = 1.52
			s["ra"] = -1.26
			s["bump"] = 2.36
			s["rbump"] = -2.38
			s["lamp"] = [2.18, 0.53, 0.12]
			s["rad"] = [2.03, 2.17, 0.34]
			s["hood"] = [0.86, 2.03, 0.46, 0.36]
			s["cowl"] = [0.64, 0.86, 0.70]
			s["ws"] = [0.57, 0.64, 0.70]
			s["ff"] = [0.80, 2.25, 0.57, 0.93]
			s["rf"] = [-1.92, -0.56, 0.60, 0.93]
			s["rb"] = [-0.62, 0.86, 0.68, 0.90]
			s["tub"] = [-2.34, 0.86, 0.84, 0.16]
			s["roof"] = [-2.30, 0.62, 0.80, 0.10, 0.14]
			s["spare"] = []
			s["tail"] = [-2.36, -0.70]
			s["h_top"] = 2.05
		"delivery":
			# a box truck on the ton-and-a-half chassis
			s["fa"] = 1.62
			s["ra"] = -1.30
			s["track"] = 0.74
			s["dual"] = true
			s["tr"] = 0.39
			s["bump"] = 2.46
			s["bw"] = 0.84
			s["rbump"] = -2.50
			s["lamp"] = [2.29, 0.55, 0.13]
			s["rad"] = [2.12, 2.27, 0.37]
			s["hood"] = [0.95, 2.12, 0.46, 0.38]
			s["cowl"] = [0.74, 0.95, 0.72]
			s["ws"] = [0.68, 0.75, 0.72]
			s["ff"] = [0.86, 2.34, 0.58, 0.94]
			s["rf"] = []
			s["rb"] = [0.00, 0.90, 0.70, 0.93]
			s["tub"] = [-0.02, 0.95, 0.78, 0.10]
			s["roof"] = [0.04, 0.70, 0.72, 0.10, 0.06]
			s["box"] = [-2.50, -0.08, 1.0]
			s["spare"] = []
			s["tail"] = [-2.47, -0.93]
			s["h_top"] = 2.45
		"truck":
			# the family's stake-bed ton-and-a-half
			s["fa"] = 1.80
			s["ra"] = -1.72
			s["track"] = 0.76
			s["dual"] = true
			s["tr"] = 0.40
			s["bump"] = 2.65
			s["bw"] = 0.86
			s["rbump"] = -2.70
			s["lamp"] = [2.48, 0.56, 0.135]
			s["rad"] = [2.31, 2.46, 0.38]
			s["hood"] = [1.08, 2.31, 0.47, 0.39]
			s["cowl"] = [0.86, 1.08, 0.74]
			s["ws"] = [0.79, 0.86, 0.74]
			s["ff"] = [0.98, 2.54, 0.59, 0.96]
			s["rf"] = []
			s["rb"] = [-0.02, 1.02, 0.72, 0.95]
			s["tub"] = [-0.04, 1.08, 0.80, 0.10]
			s["roof"] = [0.04, 0.82, 0.74, 0.10, 0.06]
			s["bed"] = [-2.70, -0.14, 1.04]
			s["spare"] = []
			s["tail"] = [-2.68, -0.96]
			s["h_top"] = 2.0
			s["louvres"] = 10
	return s


## The trade painted on a delivery truck, from its seed.
static func trade_for(seed_value: int) -> String:
	return TRADE_ORDER[absi(seed_value) % TRADE_ORDER.size()]
