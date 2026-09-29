extends RefCounted
## Small flat pictograms for the book and Don's View, drawn in one colour (with `bg` for the cut-outs).
##   Icons.draw(ci, name, center, size, color, bg)
## Trades: bakery butcher grocer tailor barber cobbler pawnshop laundry restaurant cafe candy hardware
##   drugstore cigar fish club poolhall precinct warehouse
## Specialties (Rackets.TRAITS icons): fist gun car talk cross money
## Other: envelope bottle lock star bang eye book notebook skull rat barrel men shop check x pin boat
##   heat crown deal left right up down

const TRADE_NAMES := {"bakery": "Bakery", "butcher": "Butcher", "grocer": "Grocer", "tailor": "Tailor",
	"barber": "Barber", "cobbler": "Cobbler", "pawnshop": "Pawnshop", "laundry": "Laundry",
	"restaurant": "Restaurant", "cafe": "Café", "candy": "Candy store", "hardware": "Hardware store",
	"drugstore": "Drugstore", "cigar": "Cigar store", "fish": "Fish market", "club": "Social club",
	"poolhall": "Pool hall", "precinct": "Police precinct", "warehouse": "Warehouse"}

## Which icon stands for each kind of evidence in the Bureau's file.
const EVIDENCE := {"witness": "eye", "street": "talk", "cop": "notebook", "weapon": "gun", "ledger": "book",
	"body": "skull", "informant": "rat", "file": "barrel"}


static func trade_name(kind: String) -> String:
	return String(TRADE_NAMES.get(kind, kind.capitalize()))


static func _p(c: Vector2, h: float, x: float, y: float) -> Vector2:
	return c + Vector2(x, y) * h


static func _pts(c: Vector2, h: float, arr: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(0, arr.size(), 2):
		out.append(c + Vector2(float(arr[i]), float(arr[i + 1])) * h)
	return out


static func _cap(ci: CanvasItem, c: Vector2, h: float, x0: float, y0: float, x1: float, y1: float, r: float, col: Color) -> void:
	Draw.capsule(ci, _p(c, h, x0, y0), _p(c, h, x1, y1), r * h, col)


static func _rr(ci: CanvasItem, c: Vector2, h: float, x0: float, y0: float, x1: float, y1: float, rad: float, col: Color) -> void:
	Draw.rrect(ci, Rect2(_p(c, h, x0, y0), Vector2(x1 - x0, y1 - y0) * h), rad * h, col)


static func _circ(ci: CanvasItem, c: Vector2, h: float, x: float, y: float, r: float, col: Color) -> void:
	Draw.circle(ci, _p(c, h, x, y), r * h, col)


static func _line(ci: CanvasItem, c: Vector2, h: float, x0: float, y0: float, x1: float, y1: float, w: float, col: Color) -> void:
	ci.draw_line(_p(c, h, x0, y0), _p(c, h, x1, y1), col, maxf(1.0, w * h), true)


## A round badge: filled disc (the owner's colour), a thin rim, the pictogram in cream.
static func badge(ci: CanvasItem, name: String, c: Vector2, r: float, fill: Color, rim: Color, fg: Color = Color("f4ecd6"), shadow: bool = true) -> void:
	if shadow:
		Draw.circle(ci, c + Vector2(r * 0.12, r * 0.18), r * 1.02, Color(0, 0, 0, 0.3))
	Draw.circle(ci, c, r, rim)
	Draw.circle(ci, c, r - maxf(1.2, r * 0.13), fill)
	draw(ci, name, c, r * 1.22, fg, fill)


static func draw(ci: CanvasItem, name: String, c: Vector2, size: float, col: Color, bg: Color = Color(0, 0, 0, 0)) -> void:
	var h := size * 0.5
	match name:
		"bakery":
			Draw.ellipse(ci, _p(c, h, 0, 0.12), Vector2(0.88, 0.5) * h, col)
			for k in 3:
				var x := -0.42 + k * 0.36
				_line(ci, c, h, x - 0.1, 0.28, x + 0.12, -0.18, 0.11, bg)
		"butcher":
			Draw.poly(ci, _pts(c, h, [-0.85, -0.6, 0.35, -0.6, 0.35, 0.3, -0.62, 0.3, -0.85, 0.1]), col)
			_cap(ci, c, h, 0.35, -0.3, 0.88, -0.3, 0.13, col)
			_circ(ci, c, h, -0.55, -0.34, 0.1, bg)
		"grocer":
			_circ(ci, c, h, -0.2, 0.15, 0.5, col)
			_circ(ci, c, h, 0.2, 0.15, 0.5, col)
			_circ(ci, c, h, 0.0, 0.35, 0.45, col)
			_line(ci, c, h, 0.0, -0.3, 0.1, -0.78, 0.12, col)
			Draw.ellipse(ci, _p(c, h, 0.36, -0.62), Vector2(0.26, 0.12) * h, col, -0.5)
		"tailor":
			_cap(ci, c, h, -0.25, 0.25, 0.4, -0.85, 0.09, col)
			_cap(ci, c, h, 0.25, 0.25, -0.4, -0.85, 0.09, col)
			for sx in [-1.0, 1.0]:
				_circ(ci, c, h, 0.42 * sx, 0.52, 0.3, col)
				_circ(ci, c, h, 0.42 * sx, 0.52, 0.15, bg)
			_circ(ci, c, h, 0.0, -0.08, 0.08, bg)
		"barber":
			_rr(ci, c, h, -0.28, -0.72, 0.28, 0.72, 0.1, col)
			for k in 4:
				var y := -0.55 + k * 0.38
				_line(ci, c, h, -0.26, y + 0.12, 0.26, y - 0.14, 0.12, bg)
			_circ(ci, c, h, 0.0, -0.84, 0.17, col)
			_rr(ci, c, h, -0.36, 0.72, 0.36, 0.9, 0.05, col)
		"cobbler":
			Draw.poly(ci, _pts(c, h, [-0.45, -0.85, 0.12, -0.85, 0.14, 0.12, 0.62, 0.26, 0.86, 0.46, 0.86, 0.72, -0.45, 0.72]), col)
			_line(ci, c, h, -0.45, 0.52, 0.86, 0.52, 0.08, bg)
		"pawnshop":
			_line(ci, c, h, -0.85, -0.82, 0.85, -0.82, 0.12, col)
			for b in [[-0.52, 0.02], [0.52, 0.02], [0.0, 0.5]]:
				_line(ci, c, h, float(b[0]), -0.82, float(b[0]), float(b[1]), 0.07, col)
				_circ(ci, c, h, float(b[0]), float(b[1]), 0.3, col)
		"laundry":
			Draw.poly(ci, _pts(c, h, [-0.3, -0.78, 0.3, -0.78, 0.88, -0.46, 0.66, -0.04, 0.44, -0.18, 0.44, 0.82, -0.44, 0.82, -0.44, -0.18, -0.66, -0.04, -0.88, -0.46]), col)
			Draw.poly(ci, _pts(c, h, [-0.2, -0.79, 0.0, -0.5, 0.2, -0.79]), bg)
		"restaurant":
			_cap(ci, c, h, -0.38, -0.2, -0.38, 0.86, 0.1, col)
			for k in 3:
				_line(ci, c, h, -0.6 + k * 0.22, -0.88, -0.6 + k * 0.22, -0.4, 0.08, col)
			_rr(ci, c, h, -0.66, -0.46, -0.1, -0.2, 0.12, col)
			Draw.poly(ci, _pts(c, h, [0.28, -0.88, 0.56, -0.66, 0.54, 0.08, 0.28, 0.08]), col)
			_cap(ci, c, h, 0.4, 0.06, 0.4, 0.86, 0.11, col)
		"cafe":
			Draw.poly(ci, _pts(c, h, [-0.62, -0.18, 0.42, -0.18, 0.32, 0.5, 0.18, 0.62, -0.38, 0.62, -0.52, 0.5]), col)
			_circ(ci, c, h, 0.5, 0.14, 0.24, col)
			_circ(ci, c, h, 0.5, 0.14, 0.11, bg)
			Draw.ellipse(ci, _p(c, h, -0.08, 0.74), Vector2(0.82, 0.12) * h, col)
			for k in 2:
				var x := -0.3 + k * 0.34
				ci.draw_polyline(_pts(c, h, [x, -0.3, x + 0.1, -0.5, x, -0.68, x + 0.1, -0.88]), col, maxf(1.0, 0.08 * h), true)
		"candy":
			_circ(ci, c, h, 0.0, -0.3, 0.52, col)
			ci.draw_arc(_p(c, h, 0.0, -0.3), 0.3 * h, 0.0, TAU * 0.8, 16, bg, maxf(1.0, 0.09 * h), true)
			_circ(ci, c, h, 0.0, -0.3, 0.08, bg)
			_line(ci, c, h, 0.0, 0.2, 0.0, 0.9, 0.13, col)
		"hardware":
			_cap(ci, c, h, 0.0, -0.35, 0.0, 0.86, 0.13, col)
			Draw.poly(ci, _pts(c, h, [-0.72, -0.82, 0.42, -0.82, 0.72, -0.62, 0.42, -0.36, -0.72, -0.36]), col)
		"drugstore":
			_cap(ci, c, h, 0.08, -0.1, 0.58, -0.86, 0.12, col)
			Draw.poly(ci, _pts(c, h, [-0.8, -0.1, 0.8, -0.1, 0.62, 0.34, 0.3, 0.56, -0.3, 0.56, -0.62, 0.34]), col)
			_rr(ci, c, h, -0.36, 0.56, 0.36, 0.84, 0.06, col)
		"cigar":
			_cap(ci, c, h, -0.84, 0.3, 0.6, 0.3, 0.17, col)
			_line(ci, c, h, -0.36, 0.14, -0.36, 0.46, 0.1, bg)
			_circ(ci, c, h, 0.72, 0.3, 0.12, col.lerp(Color("e0703a"), 0.6))
			ci.draw_polyline(_pts(c, h, [0.62, 0.02, 0.74, -0.22, 0.58, -0.46, 0.72, -0.72]), col, maxf(1.0, 0.08 * h), true)
		"fish":
			Draw.ellipse(ci, _p(c, h, -0.14, 0.0), Vector2(0.6, 0.34) * h, col)
			Draw.poly(ci, _pts(c, h, [0.36, 0.0, 0.9, -0.42, 0.82, 0.0, 0.9, 0.42]), col)
			_circ(ci, c, h, -0.48, -0.07, 0.08, bg)
		"club":
			Draw.poly(ci, _pts(c, h, [-0.6, -0.8, 0.6, -0.8, 0.1, -0.1, -0.1, -0.1]), col)
			_line(ci, c, h, 0.0, -0.15, 0.0, 0.62, 0.1, col)
			Draw.ellipse(ci, _p(c, h, 0.0, 0.72), Vector2(0.46, 0.13) * h, col)
		"poolhall":
			_circ(ci, c, h, 0.0, 0.0, 0.82, col)
			_circ(ci, c, h, -0.12, -0.14, 0.38, bg)
			var f := W.ui_font("cond")
			var fs := int(maxf(6.0, h * 0.62))
			var w := f.get_string_size("8", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			ci.draw_string(f, _p(c, h, -0.12, -0.14) + Vector2(-w * 0.5, fs * 0.36), "8", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		"precinct":
			Draw.poly(ci, _pts(c, h, [-0.72, -0.68, 0.0, -0.9, 0.72, -0.68, 0.64, 0.16, 0.0, 0.88, -0.64, 0.16]), col)
			star(ci, _p(c, h, 0.0, -0.02), h * 0.38, bg)
		"warehouse":
			_rr(ci, c, h, -0.78, -0.78, 0.78, 0.78, 0.06, col)
			ci.draw_rect(Rect2(_p(c, h, -0.6, -0.6), Vector2(1.2, 1.2) * h), bg, false, maxf(1.0, 0.09 * h))
			_line(ci, c, h, -0.6, -0.6, 0.6, 0.6, 0.1, bg)
		# ---------------------------------------------------------- specialties
		"fist":
			_rr(ci, c, h, -0.7, -0.62, 0.62, 0.2, 0.26, col)
			for k in 3:
				_line(ci, c, h, -0.28 + k * 0.3, -0.62, -0.28 + k * 0.3, -0.18, 0.07, bg)
			_cap(ci, c, h, -0.6, 0.02, 0.1, 0.02, 0.14, col)
			_line(ci, c, h, -0.5, -0.1, 0.08, -0.1, 0.06, bg)
			_rr(ci, c, h, -0.42, 0.2, 0.42, 0.86, 0.08, col)
		"gun":
			_rr(ci, c, h, -0.92, -0.5, 0.3, -0.22, 0.05, col)
			_rr(ci, c, h, -0.02, -0.6, 0.46, -0.02, 0.1, col)
			Draw.poly(ci, _pts(c, h, [0.26, -0.12, 0.62, -0.2, 0.86, 0.72, 0.46, 0.8]), col)
			ci.draw_arc(_p(c, h, 0.16, 0.08), 0.2 * h, 0.2, PI, 10, col, maxf(1.0, 0.07 * h), true)
			_rr(ci, c, h, -0.9, -0.62, -0.78, -0.5, 0.02, col)
		"car":
			Draw.poly(ci, _pts(c, h, [-0.92, 0.2, -0.88, -0.08, -0.48, -0.12, -0.32, -0.55, 0.34, -0.55, 0.46, -0.12, 0.9, -0.04, 0.92, 0.22]), col)
			_rr(ci, c, h, -0.22, -0.46, 0.06, -0.16, 0.04, bg)
			_rr(ci, c, h, 0.12, -0.46, 0.3, -0.16, 0.04, bg)
			for x in [-0.5, 0.56]:
				_circ(ci, c, h, x, 0.32, 0.27, col)
				_circ(ci, c, h, x, 0.32, 0.11, bg)
		"talk":
			_rr(ci, c, h, -0.86, -0.72, 0.86, 0.34, 0.32, col)
			Draw.poly(ci, _pts(c, h, [-0.36, 0.28, -0.62, 0.84, 0.06, 0.3]), col)
			for k in 3:
				_circ(ci, c, h, -0.42 + k * 0.42, -0.19, 0.1, bg)
		"cross":
			_rr(ci, c, h, -0.26, -0.82, 0.26, 0.82, 0.06, col)
			_rr(ci, c, h, -0.82, -0.26, 0.82, 0.26, 0.06, col)
		"money":
			_circ(ci, c, h, 0.0, 0.0, 0.84, col)
			ci.draw_arc(c, 0.68 * h, 0.0, TAU, 24, bg, maxf(1.0, 0.05 * h), true)
			var f2 := W.ui_font("cond")
			var fs2 := int(maxf(7.0, h * 1.15))
			var w2 := f2.get_string_size("$", HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
			ci.draw_string(f2, c + Vector2(-w2 * 0.5, fs2 * 0.36), "$", HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, bg)
		# ---------------------------------------------------------- other
		"envelope":
			_rr(ci, c, h, -0.88, -0.56, 0.88, 0.56, 0.06, col)
			ci.draw_polyline(_pts(c, h, [-0.8, -0.48, 0.0, 0.1, 0.8, -0.48]), bg, maxf(1.0, 0.09 * h), true)
		"bottle":
			Draw.poly(ci, _pts(c, h, [-0.14, -0.9, 0.14, -0.9, 0.14, -0.44, 0.36, -0.18, 0.36, 0.84, -0.36, 0.84, -0.36, -0.18, -0.14, -0.44]), col)
			_rr(ci, c, h, -0.28, 0.1, 0.28, 0.5, 0.04, bg)
		"lock":
			ci.draw_arc(_p(c, h, 0.0, -0.22), 0.4 * h, PI, TAU, 14, col, maxf(1.5, 0.16 * h), true)
			_line(ci, c, h, -0.4, -0.22, -0.4, 0.0, 0.16, col)
			_line(ci, c, h, 0.4, -0.22, 0.4, 0.0, 0.16, col)
			_rr(ci, c, h, -0.66, -0.06, 0.66, 0.86, 0.12, col)
			_circ(ci, c, h, 0.0, 0.32, 0.12, bg)
		"star":
			star(ci, c, h * 0.92, col)
		"bang":
			Draw.poly(ci, _pts(c, h, [-0.2, -0.86, 0.2, -0.86, 0.12, 0.34, -0.12, 0.34]), col)
			_circ(ci, c, h, 0.0, 0.66, 0.17, col)
		"eye":
			Draw.poly(ci, _pts(c, h, [-0.9, 0.0, -0.5, -0.42, 0.0, -0.56, 0.5, -0.42, 0.9, 0.0, 0.5, 0.42, 0.0, 0.56, -0.5, 0.42]), col)
			_circ(ci, c, h, 0.0, 0.0, 0.36, bg)
			_circ(ci, c, h, 0.0, 0.0, 0.2, col)
		"book":
			_rr(ci, c, h, -0.72, -0.84, 0.72, 0.84, 0.08, col)
			_line(ci, c, h, -0.5, -0.84, -0.5, 0.84, 0.08, bg)
			_rr(ci, c, h, -0.26, -0.5, 0.5, -0.24, 0.02, bg)
		"notebook":
			_rr(ci, c, h, -0.62, -0.84, 0.66, 0.84, 0.06, col)
			for k in 5:
				_circ(ci, c, h, -0.62, -0.62 + k * 0.31, 0.1, bg)
			for k in 3:
				_line(ci, c, h, -0.32, -0.4 + k * 0.34, 0.46, -0.4 + k * 0.34, 0.07, bg)
		"skull":
			_circ(ci, c, h, 0.0, -0.18, 0.7, col)
			_rr(ci, c, h, -0.4, 0.24, 0.4, 0.8, 0.12, col)
			_circ(ci, c, h, -0.28, -0.12, 0.2, bg)
			_circ(ci, c, h, 0.28, -0.12, 0.2, bg)
			Draw.poly(ci, _pts(c, h, [0.0, 0.1, 0.1, 0.3, -0.1, 0.3]), bg)
			for k in 3:
				_line(ci, c, h, -0.2 + k * 0.2, 0.5, -0.2 + k * 0.2, 0.8, 0.06, bg)
		"rat":
			Draw.ellipse(ci, _p(c, h, 0.05, 0.18), Vector2(0.56, 0.36) * h, col)
			Draw.poly(ci, _pts(c, h, [-0.4, -0.02, -0.92, 0.22, -0.4, 0.42]), col)
			_circ(ci, c, h, -0.3, -0.1, 0.16, col)
			_circ(ci, c, h, -0.62, 0.14, 0.05, bg)
			ci.draw_polyline(_pts(c, h, [0.58, 0.3, 0.82, 0.1, 0.9, -0.3, 0.74, -0.6]), col, maxf(1.0, 0.08 * h), true)
		"barrel":
			Draw.poly(ci, _pts(c, h, [-0.5, -0.86, 0.5, -0.86, 0.7, -0.3, 0.7, 0.3, 0.5, 0.86, -0.5, 0.86, -0.7, 0.3, -0.7, -0.3]), col)
			_line(ci, c, h, -0.66, -0.42, 0.66, -0.42, 0.08, bg)
			_line(ci, c, h, -0.66, 0.42, 0.66, 0.42, 0.08, bg)
		"men":
			_circ(ci, c, h, 0.0, -0.44, 0.36, col)
			Draw.poly(ci, _pts(c, h, [-0.8, 0.86, -0.72, 0.26, -0.36, 0.02, 0.36, 0.02, 0.72, 0.26, 0.8, 0.86]), col)
		"shop":
			_rr(ci, c, h, -0.72, -0.2, 0.72, 0.84, 0.04, col)
			Draw.poly(ci, _pts(c, h, [-0.9, -0.2, -0.76, -0.78, 0.76, -0.78, 0.9, -0.2]), col)
			for k in 4:
				_circ(ci, c, h, -0.68 + k * 0.45, -0.2, 0.2, col)
			_rr(ci, c, h, -0.2, 0.3, 0.2, 0.84, 0.02, bg)
		"check":
			ci.draw_polyline(_pts(c, h, [-0.72, 0.02, -0.22, 0.52, 0.78, -0.6]), col, maxf(1.5, 0.2 * h), true)
		"x":
			_line(ci, c, h, -0.6, -0.6, 0.6, 0.6, 0.18, col)
			_line(ci, c, h, 0.6, -0.6, -0.6, 0.6, 0.18, col)
		"pin":
			_circ(ci, c, h, 0.0, -0.32, 0.5, col)
			Draw.poly(ci, _pts(c, h, [-0.42, -0.08, 0.0, 0.92, 0.42, -0.08]), col)
			_circ(ci, c, h, 0.0, -0.32, 0.2, bg)
		"boat":
			Draw.poly(ci, _pts(c, h, [-0.92, -0.1, 0.92, -0.1, 0.62, 0.46, -0.72, 0.46]), col)
			_rr(ci, c, h, -0.36, -0.52, 0.3, -0.1, 0.04, col)
			_line(ci, c, h, 0.1, -0.52, 0.1, -0.86, 0.08, col)
		"heat":
			Draw.poly(ci, _pts(c, h, [0.0, -0.9, 0.44, -0.3, 0.6, 0.2, 0.44, 0.62, 0.0, 0.86, -0.44, 0.62, -0.6, 0.2, -0.36, -0.2, -0.2, 0.06]), col)
			Draw.poly(ci, _pts(c, h, [0.0, -0.1, 0.24, 0.3, 0.2, 0.56, 0.0, 0.66, -0.2, 0.56, -0.24, 0.3]), bg)
		"crown":
			Draw.poly(ci, _pts(c, h, [-0.84, 0.5, -0.84, -0.5, -0.42, 0.0, 0.0, -0.66, 0.42, 0.0, 0.84, -0.5, 0.84, 0.5]), col)
			_rr(ci, c, h, -0.84, 0.56, 0.84, 0.78, 0.04, col)
		"deal":
			_cap(ci, c, h, -0.86, 0.1, -0.1, -0.2, 0.2, col)
			_cap(ci, c, h, 0.86, 0.1, 0.1, -0.2, 0.2, col)
			_rr(ci, c, h, -0.34, -0.36, 0.34, 0.14, 0.2, col)
			for k in 3:
				_line(ci, c, h, -0.2 + k * 0.2, -0.3, -0.2 + k * 0.2, 0.06, 0.05, bg)
		"left", "right", "up", "down":
			var d := {"left": Vector2(-1, 0), "right": Vector2(1, 0), "up": Vector2(0, -1), "down": Vector2(0, 1)}[name] as Vector2
			var o := d.orthogonal()
			Draw.poly(ci, PackedVector2Array([c + d * h * 0.7, c - d * h * 0.45 + o * h * 0.62, c - d * h * 0.45 - o * h * 0.62]), col)
		_:
			_circ(ci, c, h, 0.0, 0.0, 0.5, col)


static func star(ci: CanvasItem, c: Vector2, r: float, col: Color, points: int = 5) -> void:
	var pts := PackedVector2Array()
	for k in points * 2:
		var a := -PI * 0.5 + PI * k / points
		pts.append(c + Vector2(cos(a), sin(a)) * (r if k % 2 == 0 else r * 0.45))
	Draw.poly(ci, pts, col)
