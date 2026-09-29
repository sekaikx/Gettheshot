extends RefCounted
## The street face of one business, for Shopfronts. `plan_shop()` lays it out once (deterministic
## from the lot); `refresh()` reads what changes (who protects it, padlocked, speakeasy, season,
## night); the painters draw into three nodes per shop:
##   paint_ground  what stands on the sidewalk (stands, tables, steps, shadows), W.Z_FURNITURE
##   paint_over    what hangs above people (awning, canopy, bracket signs, parasols), W.Z_AWNING
##   paint_lit     the lit part of a neon sign or a bulb marquee (animated at night)
##
## Everything is drawn in the shop's local frame (px): origin = the middle of the front wall,
## +x ("u") along the street in reading direction, +y ("v") out of the building toward the curb.
## For shops facing north the frame is a mirror image; text is flipped back with S["sgn"].
##
## Sidewalk zoning (metres from the front wall): 0..1.6 the shop's frontage (the roof's cornice
## covers 0..0.42), 1.6..2.6 the walking lane (only the awning overhead), 2.6..3.5 the curb
## furniture (CityGround). A 1.8 m path straight to the door stays clear.

const FX := preload("res://scripts/world2d/fronts/fx.gd")
const Items := preload("res://scripts/world2d/fronts/front_items.gd")

const CORN := 0.42          # the roof's cornice hides the sidewalk up to here
const CANVAS := 1.15        # the sloped canvas, from the wall
const BAR := 1.22           # the front roll bar
const VAL := 1.62           # the valance hangs down to here
const SCALLOP := 0.1
const FRONT := 1.6          # end of the frontage zone
const DOOR_HALF := 0.9      # the path to the door: |u| < this stays clear
const AWNING_H := 2.7       # awning height, for its shadow
const SLOT_V0 := 0.46
const SLOT_V1 := 1.56
const CANOPY_HALF := 0.95
const CANOPY_LEN := 2.5
const GLOBE := Color(0.72, 0.84, 1.0)

## What each trade puts out: item on side a, item on side b, a bracket sign over side b, the width
## the items need (m), the lettering font, a lit sign over the awning.
const KINDS := {
	"grocer": {"a": "produce", "b": "produce", "side": 1.9, "font": "cond"},
	"bakery": {"a": "bread_rack", "b": "baguette_barrel", "side": 1.6, "font": "serif"},
	"butcher": {"a": "meat_rail", "b": "chop_block", "side": 1.6, "font": "cond"},
	"fish": {"a": "fish_ice", "b": "oyster_barrel", "side": 1.8, "font": "cond"},
	"cafe": {"a": "cafe_table", "b": "cafe_table", "side": 1.7, "font": "deco"},
	"restaurant": {"a": "rest_table", "b": "rest_table", "side": 1.8, "font": "serif", "neon": "EAT"},
	"barber": {"a": "barber_pole", "b": "bench", "side": 1.5, "font": "cond"},
	"tailor": {"a": "dummy", "b": "suit_rack", "side": 1.5, "font": "serif"},
	"cobbler": {"a": "shoeshine", "b": "crates", "over": "boot_sign", "side": 1.5, "font": "cond"},
	"pawnshop": {"a": "junk_crate", "b": "planter", "over": "pawn_balls", "side": 1.5, "font": "serif"},
	"laundry": {"a": "laundry_cart", "b": "bundles", "side": 1.6, "font": "cond"},
	"cigar": {"a": "news_rack", "b": "ash_urn", "over": "cigar_sign", "side": 1.5, "font": "serif", "neon": "CIGARS"},
	"hardware": {"a": "brooms", "b": "pails", "side": 1.7, "font": "cond"},
	"candy": {"a": "gumball", "b": "soda_crates", "side": 1.5, "font": "deco", "neon": "SODA"},
	"drugstore": {"a": "penny_scale", "b": "planter", "over": "mortar_sign", "side": 1.5, "font": "serif", "neon": "DRUGS"},
	"poolhall": {"a": "bench", "b": "ash_urn", "side": 1.4, "font": "cond", "marquee": "BILLIARDS"},
	"club": {"a": "planter", "b": "planter", "side": 1.2, "font": "deco"},
}
const SOLID_ITEMS := ["produce", "bread_rack", "baguette_barrel", "meat_rail", "chop_block", "fish_ice",
	"oyster_barrel", "cafe_table", "rest_table", "barber_pole", "bench", "dummy", "suit_rack", "shoeshine",
	"junk_crate", "laundry_cart", "bundles", "news_rack", "brooms", "pails", "gumball", "soda_crates",
	"penny_scale", "ash_urn", "planter", "crates"]


static func M(v: float) -> float:
	return v * W.M


# ------------------------------------------------------------------ layout

static func plan_shop(b: Dictionary, lot: Dictionary) -> Dictionary:
	var S := {}
	var kind := String(b["kind"])
	var r := W.lot_rect(lot)
	var f := W.front_dir(float(lot["yaw"]))
	var ax := Vector2(1, 0) if absf(f.y) > 0.5 else Vector2(0, -f.x)
	var depth := absf(r.size.dot(f))
	var origin := r.get_center() + f * depth * 0.5
	var w := float(lot["size"][0])
	var half := w * 0.5
	var rng := W.rng(int(lot["id"]) * 7717 + 3)
	S["id"] = int(b["id"])
	S["lot"] = int(lot["id"])
	S["kind"] = kind
	S["name"] = String(b["name"])
	S["ax"] = ax
	S["f"] = f
	S["xf"] = Transform2D(ax, f, origin)
	S["sgn"] = signf(ax.cross(f))
	S["w"] = w
	S["half"] = half
	S["seed"] = rng.randi()
	var spec: Dictionary = KINDS.get(kind, {"a": "crates", "b": "planter", "side": 1.4, "font": "cond"})
	S["font"] = String(spec.get("font", "cond"))
	S["awning"] = "stripe"
	if kind == "club":
		S["awning"] = "canopy"
	elif kind == "poolhall":
		S["awning"] = "solid"
	elif kind == "precinct":
		S["awning"] = "none"
	elif kind == "warehouse":
		S["awning"] = "dock"
	S["stripe"] = [0.36, 0.42, 0.3][rng.randi_range(0, 2)]
	S["scallop"] = rng.randf() < 0.62
	var side := clampf(float(spec.get("side", 1.4)), 1.1, maxf(1.1, half - 2.0))
	S["aw_half"] = half - side
	S["neon"] = ""
	if spec.has("neon") and rng.randf() < 0.65:
		S["neon"] = String(spec["neon"])
	S["marquee"] = String(spec.get("marquee", ""))
	# which side gets the main display; the speakeasy stairs take the other
	var sa := 1.0 if rng.randf() < 0.5 else -1.0
	S["sa"] = sa
	var u0 := half - side + 0.12
	var u1 := half - 0.18
	var items := []
	if kind in ["precinct", "warehouse"]:
		pass
	else:
		for k in 2:
			var s := sa if k == 0 else -sa
			var t := String(spec.get("a" if k == 0 else "b", ""))
			var rr := Rect2(Vector2(minf(s * u0, s * u1), SLOT_V0) * W.M, Vector2(u1 - u0, SLOT_V1 - SLOT_V0) * W.M)
			items.append({"t": t, "rect": rr, "s": s, "slot": "a" if k == 0 else "b"})
	S["items"] = items
	S["over"] = String(spec.get("over", ""))
	S["solids"] = _solids_local(S)
	S["aw_rect"] = _aw_rect_local(S)
	return S


## Re-read the business: colours, padlock, speakeasy, the season, the night.
static func refresh(S: Dictionary, b: Dictionary, night_on: bool, wet: float) -> void:
	var fam := int(b["owned_by"]) if int(b["owned_by"]) >= 0 else int(b["protector"])
	var col := W.fam_color(fam) if fam >= 0 else W.FAMILY_NONE
	S["fam"] = fam if col.a > 0.0 else -1
	S["owned"] = int(b["owned_by"]) >= 0 and col.a > 0.0
	if col.a <= 0.0:
		col = Pal.AWNING_COLORS[int(S["lot"]) % Pal.AWNING_COLORS.size()]
	else:
		# canvas takes dye a little duller than paint
		col = col.lerp(Color(col.get_luminance(), col.get_luminance(), col.get_luminance()), 0.12).darkened(0.06)
	S["col"] = col
	S["closed"] = int(b["closed_until"]) >= Game.month
	S["speak"] = bool(b.get("speak", false))
	var m := Game.month % 12
	S["summer"] = m >= 4 and m <= 8
	S["night_on"] = night_on
	S["wet"] = wet
	S["hq"] = int(b.get("hq_of", -1))


static func state_key(b: Dictionary) -> String:
	var fam := int(b["owned_by"]) if int(b["owned_by"]) >= 0 else int(b["protector"])
	var m := Game.month % 12
	return "%d/%s/%d/%d/%d/%d" % [fam, W.fam_color(fam).to_html() if fam >= 0 else "-", int(int(b["owned_by"]) >= 0),
		int(int(b["closed_until"]) >= Game.month), int(bool(b.get("speak", false))), int(m >= 4 and m <= 8)]


static func _solids_local(S: Dictionary) -> Array:
	var out := []
	var kind := String(S["kind"])
	var half := float(S["half"])
	if kind == "precinct":
		for s: float in [-1.0, 1.0]:
			out.append(Rect2(Vector2(minf(s * 1.72, s * 2.3), 0.0) * W.M, Vector2(0.58, 1.52) * W.M))
		return out
	if kind == "warehouse":
		for s: float in [-1.0, 1.0]:
			out.append(Rect2(Vector2(minf(s * 2.2, s * (half * 0.55 - 1.7)), 0.3) * W.M, Vector2(absf(half * 0.55 - 1.7 - 2.2), 0.9) * W.M))
		return out
	for it in S["items"]:
		if String(it["t"]) in SOLID_ITEMS:
			var rr: Rect2 = it["rect"]
			var solid := Rect2(Vector2(rr.position.x, 0.0), Vector2(rr.size.x, rr.end.y - M(0.06)))
			out.append(solid)
	if kind == "club":
		for s: float in [-1.0, 1.0]:
			out.append(Rect2(Vector2(s * (CANOPY_HALF + 0.45) - 0.24, 0.82) * W.M, Vector2(0.48, 0.48) * W.M))
	return out


static func _aw_rect_local(S: Dictionary) -> Rect2:
	match String(S["awning"]):
		"canopy":
			return Rect2(Vector2(-float(S["half"]), 0.0) * W.M, Vector2(float(S["w"]), CANOPY_LEN) * W.M)
		"stripe", "solid":
			var a := float(S["aw_half"])
			return Rect2(Vector2(-a, 0.0) * W.M, Vector2(a * 2.0, VAL + SCALLOP) * W.M)
	return Rect2()


## Local rect -> world rect (the frame only turns by right angles, so it stays a rect).
static func to_world(S: Dictionary, r: Rect2) -> Rect2:
	var xf: Transform2D = S["xf"]
	var a := xf * r.position
	var b := xf * r.end
	return Rect2(a.min(b), (a - b).abs())


static func solids_world(S: Dictionary) -> Array:
	var out := []
	for r in S["solids"]:
		out.append(to_world(S, r))
	return out


## Where the awning or canopy hangs, in world px (Rect2() when there's none).
static func awning_world(S: Dictionary) -> Rect2:
	var r: Rect2 = S["aw_rect"]
	return to_world(S, r) if r.size != Vector2.ZERO else Rect2()


## Lights for the lightmap, world px.
static func lights(S: Dictionary) -> Array:
	var out := []
	var xf: Transform2D = S["xf"]
	var kind := String(S["kind"])
	if bool(S["closed"]):
		return out
	match kind:
		"precinct":
			for s: float in [-1.0, 1.0]:
				out.append({"pos": xf * Vector2(s * 2.0, 1.2) * W.M, "r": 2.8 * W.M, "color": GLOBE, "e": 0.9, "shape": "round"})
			out.append({"pos": xf * Vector2(0.0, 1.4) * W.M, "r": 2.2 * W.M, "color": Pal.WINDOW_WARM, "e": 0.45, "shape": "round"})
			return out
		"warehouse":
			out.append({"pos": xf * Vector2(0.0, 0.8) * W.M, "r": 4.0 * W.M, "color": Pal.LAMP, "e": 0.8, "shape": "round"})
			return out
		"club":
			out.append({"pos": xf * Vector2(0.0, 1.7) * W.M, "r": 2.8 * W.M, "color": Pal.LAMP, "e": 0.75, "shape": "round"})
	var aw := float(S["aw_half"]) if String(S["awning"]) in ["stripe", "solid"] else float(S["half"]) - 0.4
	for s: float in [-1.0, 1.0]:
		var r := Rect2(Vector2(minf(s * 0.95, s * (aw - 0.1)), 0.9) * W.M, Vector2(absf(aw - 1.05), 2.2) * W.M)
		var wr := to_world(S, r)
		out.append({"pos": wr.get_center(), "size": wr.size, "r": wr.size.x, "color": Pal.WINDOW_WARM, "e": 0.55, "shape": "rect"})
	out.append({"pos": xf * Vector2(0.0, 1.1) * W.M, "r": 1.6 * W.M, "color": Pal.WINDOW_WARM, "e": 0.3, "shape": "round"})
	if String(S["neon"]) != "":
		out.append({"pos": xf * Vector2(0.0, 1.4) * W.M, "r": 2.6 * W.M, "color": Pal.NEON_RED, "e": 0.55, "shape": "round", "flicker": true})
	if String(S["marquee"]) != "":
		out.append({"pos": xf * Vector2(0.0, 1.2) * W.M, "r": 3.0 * W.M, "color": Pal.LAMP, "e": 0.7, "shape": "round"})
	if bool(S["speak"]):
		for it in S["items"]:
			if it["slot"] == "b":
				var c: Vector2 = (it["rect"] as Rect2).get_center()
				out.append({"pos": xf * c, "r": 1.3 * W.M, "color": Pal.NEON_RED, "e": 0.5, "shape": "round"})
	return out


# ------------------------------------------------------------------ text

## Text centred on `c` (caps centred), upright in the world whatever the frame.
static func text(ci: CanvasItem, S: Dictionary, c: Vector2, s: String, size: int, col: Color, font: Font,
		drop: Color = Color(0, 0, 0, 0), outline: int = 0, outline_col: Color = Color(0, 0, 0, 0)) -> void:
	if size <= 0 or s == "":
		return
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var at := Vector2(-w * 0.5, float(size) * FX.CAP * 0.5)
	ci.draw_set_transform(c, 0.0, Vector2(1.0, float(S["sgn"])))
	if outline > 0:
		ci.draw_string_outline(font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, outline_col)
	if drop.a > 0.0:
		ci.draw_string(font, at + Vector2(0.0, maxf(1.0, size * 0.07)), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, drop)
	ci.draw_string(font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _font(S: Dictionary) -> Font:
	return W.font(String(S["font"]))


static func _ink_for(bg: Color) -> Color:
	return Pal.SIGN_BLACK if bg.get_luminance() > 0.55 else Pal.AWNING_CREAM


# ------------------------------------------------------------------ ground

static func paint_ground(ci: CanvasItem, S: Dictionary) -> void:
	var kind := String(S["kind"])
	var rng := W.rng(int(S["seed"]))
	if kind == "precinct":
		_precinct_ground(ci, S)
		return
	if kind == "warehouse":
		_dock_ground(ci, S, rng)
		return
	var closed := bool(S["closed"])
	_threshold(ci, S)
	var aw := String(S["awning"])
	if not closed and aw in ["stripe", "solid"]:
		var a := M(float(S["aw_half"]))
		var r := Rect2(Vector2(-a, 0.0), Vector2(a * 2.0, M(VAL)))
		FX.soft_poly(ci, FX.hull_shift(FX.rect_pts(r), Items.sh(S, AWNING_H)), 0.2, 3.0)
	if kind == "club":
		_club_ground(ci, S, rng)
	if closed:
		_closed_ground(ci, S, rng)
		return
	for it in S["items"]:
		var rr: Rect2 = it["rect"]
		if it["slot"] == "b" and bool(S["speak"]):
			Items.cellar_stairs(ci, S, rr, bool(S["night_on"]))
			continue
		var t := String(it["t"])
		if kind == "club":
			rr = Rect2(Vector2(signf(float(it["s"])) * (float(S["half"]) - 0.5) * W.M - M(0.3), M(0.5)), Vector2(M(0.6), M(0.6)))
		Items.paint(ci, S, t, rr, W.rng(int(S["seed"]) + (1 if it["slot"] == "a" else 2)))
		if bool(S["summer"]) and t in ["cafe_table", "rest_table"]:
			var c := rr.get_center()
			var rad := minf(M(1.0), rr.size.x * 0.5 + M(0.25))
			FX.soft_circle(ci, c + Items.sh(S, 2.2), rad, 0.2)


## The tiled entry step in front of the door, the shop's initial set in mosaic.
static func _threshold(ci: CanvasItem, S: Dictionary) -> void:
	var r := Rect2(Vector2(-0.8, CORN - 0.05) * W.M, Vector2(1.6, 0.4) * W.M)
	Draw.rect(ci, r.grow(1.0), Color("8a8478"))
	Draw.rect(ci, r, Color("d8d0c0"))
	var n := 16
	var q := r.size.x / n
	for j in int(r.size.y / q):
		for i in n:
			if (i + j) % 2 == 0 or i == 0 or i == n - 1:
				Draw.rect(ci, Rect2(r.position + Vector2(i * q, j * q), Vector2(q - 0.5, q - 0.5)), Color("c8beac") if i > 0 and i < n - 1 else Color("5a3a2e"))
	var init := String(S["name"]).substr(0, 1).to_upper()
	text(ci, S, r.get_center() + Vector2(0, M(0.04)), init, 14, Color("5a3a2e"), W.font("serif"))


static func _closed_ground(ci: CanvasItem, S: Dictionary, rng: RandomNumberGenerator) -> void:
	# a chain and padlock across the door, litter blown against the step
	var y := M(CORN + 0.12)
	var pts := PackedVector2Array()
	for k in 13:
		var t := float(k) / 12.0
		pts.append(Vector2(lerpf(-M(0.78), M(0.78), t), y + sin(t * PI) * M(0.1)))
	ci.draw_polyline(pts, Color("5a5856"), 2.5, true)
	ci.draw_polyline(pts, Color("9a9892"), 1.0, true)
	var lock := Vector2(0, y + M(0.11))
	ci.draw_arc(lock + Vector2(0, -3), 3.5, PI, TAU, 8, Color("8a8a86"), 1.8, true)
	Draw.rrect(ci, Rect2(lock - Vector2(5, 2), Vector2(10, 9)), 2.0, Color("b89a4a"))
	for k in 9:
		var p := Vector2(rng.randf_range(-1.6, 1.6), rng.randf_range(CORN + 0.1, 1.5)) * W.M
		if absf(p.x) < M(0.5) and p.y < M(0.8):
			continue
		var d := Vector2.from_angle(rng.randf() * TAU)
		var col := Color("d8cdb4") if k % 3 != 0 else Color("8a6a3a")
		Draw.poly(ci, PackedVector2Array([p, p + d * 6.0, p + d * 6.0 + d.orthogonal() * 4.0, p + d.orthogonal() * 5.0]), col)
	# a police sawhorse beside the door
	var s := float(S["sa"])
	var bx := Rect2(Vector2(minf(s * 1.05, s * 2.35), 1.05) * W.M, Vector2(1.3, 0.16) * W.M)
	Items.shadow_rect(ci, S, bx, 0.9, 0.25)
	for x in [bx.position.x + 4.0, bx.end.x - 4.0]:
		ci.draw_line(Vector2(x, bx.position.y - 5.0), Vector2(x, bx.end.y + 5.0), Color("4a3a2a"), 3.0, true)
	Draw.rect(ci, bx, Color("ece6d6"))
	var k := 0
	var x0 := bx.position.x
	while x0 < bx.end.x:
		if k % 2 == 0:
			Draw.rect(ci, Rect2(Vector2(x0, bx.position.y), Vector2(minf(M(0.16), bx.end.x - x0), bx.size.y)), Color("1c1916"))
		x0 += M(0.16)
		k += 1


static func _club_ground(ci: CanvasItem, S: Dictionary, _rng: RandomNumberGenerator) -> void:
	# a strip of carpet under the canopy, the canopy's shadow and its poles'
	var cw := M(CANOPY_HALF)
	var carpet := Rect2(Vector2(-M(0.62), M(CORN)), Vector2(M(1.24), M(CANOPY_LEN - CORN - 0.1)))
	var col: Color = S["col"]
	Draw.rect(ci, carpet, col.darkened(0.45))
	Draw.rect(ci, carpet.grow(-3.0), col.darkened(0.3))
	ci.draw_rect(carpet.grow(-5.0), Pal.SIGN_GOLD.darkened(0.25), false, 1.0)
	var r := Rect2(Vector2(-cw, 0.0), Vector2(cw * 2.0, M(CANOPY_LEN)))
	FX.soft_poly(ci, FX.hull_shift(FX.rect_pts(r), Items.sh(S, 2.6)), 0.2, 3.0)
	for s: float in [-1.0, 1.0]:
		Items.shadow_pole(ci, S, Vector2(s * cw, M(CANOPY_LEN - 0.05)), 2.5, 3.0)
	if bool(S["closed"]):
		return
	# two chairs out front, looking at the street
	for s: float in [-1.0, 1.0]:
		Items.chair(ci, S, Vector2(s * M(CANOPY_HALF + 0.45), M(1.06)), Vector2(0, 1), Color("3a2418"))


static func _precinct_ground(ci: CanvasItem, S: Dictionary) -> void:
	var half := float(S["half"])
	# the granite landing with the precinct's name in brass letters
	var land := Rect2(Vector2(-(half - 0.3), CORN) * W.M, Vector2((half - 0.3) * 2.0, 0.56) * W.M)
	Draw.rect(ci, land.grow(1.0), Color("3e3c3a"))
	Draw.vgrad(ci, land, Color("5c5a56"), Color("6e6b66"))
	ci.draw_rect(land.grow(-3.0), Color("8a8478"), false, 1.0)
	var name := String(S["name"]).to_upper()
	var font := W.font("serif")
	var size := FX.fit(font, name, land.size.x - M(0.8), 20, 9)
	text(ci, S, land.get_center() + Vector2(0, M(0.04)), name, size, Pal.SIGN_GOLD, font, Color(0, 0, 0, 0.6))
	# the steps up to the door: three treads, each a little lighter toward the street
	var sw := 1.7
	var v0 := CORN + 0.56
	var v1 := 1.56
	var n := 3
	for k in n:
		var y0 := v0 + (v1 - v0) * k / n
		var y1 := v0 + (v1 - v0) * (k + 1) / n
		var tr := Rect2(Vector2(-sw, y0) * W.M, Vector2(sw * 2.0, y1 - y0) * W.M)
		Draw.rect(ci, tr, Pal.PARAPET_STONE.lightened(0.05 + k * 0.06))
		ci.draw_line(Vector2(tr.position.x, tr.end.y - 1.0), Vector2(tr.end.x, tr.end.y - 1.0), Color(0, 0, 0, 0.28), 2.0)
		ci.draw_line(Vector2(tr.position.x, tr.position.y + 1.0), Vector2(tr.end.x, tr.position.y + 1.0), Color(1, 1, 1, 0.18), 1.0)
	Items.shadow_rect(ci, S, Rect2(Vector2(-sw, v1 - 0.02) * W.M, Vector2(sw * 2.0, 0.02) * W.M), 0.3, 0.2)
	# the cheek walls either side, with the lamp posts on them
	for s: float in [-1.0, 1.0]:
		var cw := Rect2(Vector2(minf(s * 1.72, s * 2.3), CORN - 0.02) * W.M, Vector2(0.58, v1 - CORN + 0.02) * W.M)
		Items.shadow_rect(ci, S, cw, 1.0, 0.3)
		Draw.rect(ci, cw, Pal.PARAPET_STONE.darkened(0.1))
		Draw.rect(ci, cw.grow(-2.5), Pal.PARAPET_STONE.lightened(0.08))
		ci.draw_line(Vector2(cw.position.x, cw.position.y + cw.size.y * 0.5), Vector2(cw.end.x, cw.position.y + cw.size.y * 0.5), Color(0, 0, 0, 0.15), 1.0)
		Items.shadow_pole(ci, S, Vector2(s * 2.0, 1.2) * W.M, 2.8, 4.0)
	# a bicycle rack and the patrolmen's bikes would be too cute: a plain iron railing instead
	for s: float in [-1.0, 1.0]:
		var a := Vector2(s * 2.35, 1.5) * W.M
		var b := Vector2(s * (half - 0.35), 1.5) * W.M
		Items.shadow_pole(ci, S, a, 0.9, 1.5, 0.18)
		ci.draw_line(a + Items.sh(S, 0.9), b + Items.sh(S, 0.9), Color(FX.SHADE, 0.16), 2.0, true)
		ci.draw_line(a, b, Items.IRON, 2.5, true)
		ci.draw_line(a + Vector2(0, -0.8), b + Vector2(0, -0.8), Items.IRON_HI, 0.8, true)
		var k := 0.0
		while k <= 1.001:
			Draw.circle(ci, a.lerp(b, k), 2.0, Items.IRON)
			k += 0.2


static func _dock_ground(ci: CanvasItem, S: Dictionary, rng: RandomNumberGenerator) -> void:
	var half := float(S["half"])
	var dock := Rect2(Vector2(-(half - 0.2), 0.0) * W.M, Vector2((half - 0.2) * 2.0, 1.25) * W.M)
	# the raised loading dock: its drop to the quay casts a shadow
	Items.shadow_rect(ci, S, dock, 1.1, 0.34)
	Draw.rect(ci, dock, Color("8a847a"))
	Draw.vgrad(ci, dock.grow(-2.0), Color("7e786e"), Color("969086"))
	for k in int(dock.size.x / M(1.5)):
		var x := dock.position.x + M(1.5) * (k + 1)
		ci.draw_line(Vector2(x, dock.position.y), Vector2(x, dock.end.y), Color(0, 0, 0, 0.15), 1.0)
	for k in 30:
		var p := dock.position + Vector2(rng.randf() * dock.size.x, rng.randf() * dock.size.y)
		Draw.circle(ci, p, rng.randf_range(1.0, 3.0), Color(0, 0, 0, 0.08))
	# steel edge and timber bumpers along the front
	ci.draw_line(Vector2(dock.position.x, dock.end.y), dock.end, Color("4a4642"), 3.0)
	var x := dock.position.x + M(0.5)
	while x < dock.end.x - M(0.3):
		if absf(x) > M(1.2):
			Draw.rect(ci, Rect2(Vector2(x - M(0.15), dock.end.y - M(0.04)), Vector2(M(0.3), M(0.16))), Color("2a2622"))
		x += M(1.3)
	# the ramp down to the quay at the door
	var ramp := Rect2(Vector2(-1.05, 1.25) * W.M, Vector2(2.1, 0.7) * W.M)
	Draw.vgrad(ci, ramp, Color("7a6a58"), Color("5e5042"))
	for k in 7:
		var y := ramp.position.y + ramp.size.y * (k + 0.5) / 7.0
		ci.draw_line(Vector2(ramp.position.x, y), Vector2(ramp.end.x, y), Color(0, 0, 0, 0.25), 1.0)
	for s: float in [-1.0, 1.0]:
		ci.draw_line(Vector2(s * M(1.05), ramp.position.y), Vector2(s * M(1.05), ramp.end.y), Color("3a3430"), 2.5)
	# the two loading bays: sliding doors on their track, the bay number painted on the dock
	var font := W.font("cond")
	for s: float in [-1.0, 1.0]:
		var bc := s * half * 0.55
		var track := Rect2(Vector2(bc - 1.7, 0.0) * W.M, Vector2(3.4, 0.14) * W.M)
		Draw.rect(ci, track, Color("3a3634"))
		Draw.rect(ci, Rect2(track.position + Vector2(0, 2), Vector2(track.size.x * 0.5 - 1, track.size.y - 3)), Pal.RUST.darkened(0.1))
		Draw.rect(ci, Rect2(track.position + Vector2(track.size.x * 0.5 + 1, 2), Vector2(track.size.x * 0.5 - 1, track.size.y - 3)), Pal.RUST.darkened(0.2))
		text(ci, S, Vector2(bc, 0.62) * W.M, "BAY %d" % (1 if s < 0 else 2), 20, Color(0.95, 0.92, 0.8, 0.55), font)
		ci.draw_rect(Rect2(Vector2(bc - 1.6, 0.2) * W.M, Vector2(3.2, 1.0) * W.M), Color(0.95, 0.9, 0.7, 0.35), false, 2.0)
	# crates and barrels stacked between the bays and the door
	for s: float in [-1.0, 1.0]:
		var a := 2.2
		var b := half * 0.55 - 1.7
		var area := Rect2(Vector2(minf(s * a, s * b), 0.3) * W.M, Vector2(absf(b - a), 0.9) * W.M)
		var cx := area.position.x + 2.0
		var k := 0
		while cx < area.end.x - M(0.5):
			if k % 3 == 2:
				Items.barrel(ci, S, Vector2(cx + M(0.3), area.get_center().y), M(0.3))
				cx += M(0.66)
			else:
				var cr := Rect2(Vector2(cx, area.position.y + M(0.05)), Vector2(M(0.62), M(0.8)))
				Items.shadow_rect(ci, S, cr, 0.9 if k % 2 == 0 else 0.6, 0.3)
				Items.crate(ci, S, cr, Items.CRATE if k % 2 == 0 else Items.CRATE.darkened(0.15))
				Draw.rect(ci, Rect2(cr.get_center() - Vector2(M(0.12), M(0.05)), Vector2(M(0.24), M(0.1))), Color(0.1, 0.08, 0.06, 0.5))
				cx += M(0.68)
			k += 1
	# a hand truck by the ramp
	var ht := Vector2(1.6, 1.0) * W.M
	Items.shadow_rect(ci, S, Rect2(ht - Vector2(M(0.2), M(0.35)), Vector2(M(0.4), M(0.6))), 0.5, 0.2)
	ci.draw_line(ht + Vector2(-M(0.15), -M(0.35)), ht + Vector2(-M(0.15), M(0.2)), Items.IRON, 2.5, true)
	ci.draw_line(ht + Vector2(M(0.15), -M(0.35)), ht + Vector2(M(0.15), M(0.2)), Items.IRON, 2.5, true)
	ci.draw_line(ht + Vector2(-M(0.2), M(0.2)), ht + Vector2(M(0.2), M(0.2)), Items.IRON, 3.0, true)
	for s: float in [-1.0, 1.0]:
		Draw.rect(ci, Rect2(ht + Vector2(s * M(0.24) - 3.0, M(0.02)), Vector2(6.0, M(0.2))), Color("1a1a1a"))


# ------------------------------------------------------------------ overhead

static func paint_over(ci: CanvasItem, S: Dictionary) -> void:
	var kind := String(S["kind"])
	var rng := W.rng(int(S["seed"]) + 9)
	match String(S["awning"]):
		"stripe", "solid":
			if bool(S["closed"]):
				_rolled_awning(ci, S)
			else:
				_awning(ci, S)
		"canopy":
			_canopy(ci, S)
		"none":
			if kind == "precinct":
				_precinct_over(ci, S)
		"dock":
			_dock_over(ci, S)
	if bool(S["closed"]):
		_notice(ci, S)
		return
	var over := String(S["over"])
	if over != "":
		for it in S["items"]:
			if it["slot"] == "b":
				_bracket_sign(ci, S, over, it["rect"], rng)
	if bool(S["summer"]):
		for it in S["items"]:
			if String(it["t"]) in ["cafe_table", "rest_table"]:
				if it["slot"] == "b" and bool(S["speak"]):
					continue
				_parasol(ci, S, it["rect"], it["slot"] == "a")
	if String(S["neon"]) != "" or String(S["marquee"]) != "":
		_sign_board(ci, S)


static func _awning(ci: CanvasItem, S: Dictionary) -> void:
	var a := M(float(S["aw_half"]))
	var col: Color = S["col"]
	col = col.darkened(0.1 * float(S["wet"]))
	var cream := Pal.AWNING_CREAM.darkened(0.08 * float(S["wet"]))
	var solid := String(S["awning"]) == "solid"
	var sw := M(float(S["stripe"]))
	var n := maxi(3, int(round(a * 2.0 / sw)))
	if n % 2 == 0:
		n += 1
	sw = a * 2.0 / n
	var y1 := M(CANVAS)
	# the canvas: stripes running out from the wall, in shade near the wall, sunlit at the front
	for i in n:
		var x0 := -a + i * sw
		var c := col if (i % 2 == 0 or solid) else cream
		FX.quad(ci, Vector2(x0, 0.0), Vector2(x0 + sw, 0.0), Vector2(x0 + sw, y1), Vector2(x0, y1),
			c.darkened(0.42), c.darkened(0.42), c.darkened(0.02), c.darkened(0.02))
	if solid:
		for s: float in [-1.0, 1.0]:
			var x := s * (a - M(0.16))
			FX.quad(ci, Vector2(x - 1.5, 0.0), Vector2(x + 1.5, 0.0), Vector2(x + 1.5, y1), Vector2(x - 1.5, y1),
				cream.darkened(0.4), cream.darkened(0.4), cream, cream)
	# the frame arms under the canvas show as faint ridges; the canvas sags a little between them
	var arms := [-a + 2.0, a - 2.0]
	if a > M(2.6):
		arms.append(0.0)
	for x in arms:
		ci.draw_line(Vector2(x, M(0.2)), Vector2(x, y1), Color(1, 1, 1, 0.1), 2.0)
		ci.draw_line(Vector2(x + 1.5, M(0.2)), Vector2(x + 1.5, y1), Color(0, 0, 0, 0.12), 1.0)
	# light catches the canvas where it rolls over the front bar
	FX.quad(ci, Vector2(-a, y1 - M(0.16)), Vector2(a, y1 - M(0.16)), Vector2(a, y1), Vector2(-a, y1),
		Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.16), Color(1, 1, 1, 0.16))
	# side flaps
	for s: float in [-1.0, 1.0]:
		Draw.poly(ci, PackedVector2Array([Vector2(s * a, M(0.1)), Vector2(s * a, M(BAR)), Vector2(s * (a + 3.0), M(BAR))]), col.darkened(0.45))
	# the roll bar
	var bar := Rect2(Vector2(-a - 2.0, y1), Vector2(a * 2.0 + 4.0, M(BAR - CANVAS)))
	Draw.rect(ci, bar, Color("2a2622"))
	ci.draw_line(bar.position + Vector2(0, 1.0), bar.position + Vector2(bar.size.x, 1.0), Color("7a7066"), 1.0)
	for s: float in [-1.0, 1.0]:
		Draw.circle(ci, Vector2(s * (a + 2.0), bar.get_center().y), 2.6, Pal.BRASS.darkened(0.2))
	# the valance, lettered with the shop's name
	var vr := Rect2(Vector2(-a, M(BAR)), Vector2(a * 2.0, M(VAL - BAR)))
	var vc := col.darkened(0.16) if not solid else col.darkened(0.08)
	Draw.rect(ci, vr, vc)
	FX.quad(ci, vr.position, vr.position + Vector2(vr.size.x, 0), vr.position + Vector2(vr.size.x, 5.0), vr.position + Vector2(0, 5.0),
		Color(0, 0, 0, 0.3), Color(0, 0, 0, 0.3), Color(0, 0, 0, 0), Color(0, 0, 0, 0))
	var ink := _ink_for(vc)
	ci.draw_line(Vector2(-a + 3.0, vr.position.y + 3.0), Vector2(a - 3.0, vr.position.y + 3.0), Color(ink, 0.55), 1.0)
	ci.draw_line(Vector2(-a + 3.0, vr.end.y - 3.0), Vector2(a - 3.0, vr.end.y - 3.0), Color(ink, 0.55), 1.0)
	if bool(S["scallop"]):
		for i in n:
			var x0 := -a + i * sw
			var c := col if (i % 2 == 0 or solid) else cream
			if solid:
				c = vc
			var pts := PackedVector2Array()
			pts.append(Vector2(x0, vr.end.y - 0.5))
			for k in 9:
				var t := PI * k / 8.0
				pts.append(Vector2(x0 + sw * 0.5 - cos(t) * sw * 0.5, vr.end.y + sin(t) * M(SCALLOP)))
			Draw.poly(ci, pts, c.darkened(0.12))
	else:
		# a straight edge with a short fringe
		var x := -a + 1.5
		while x < a - 1.0:
			ci.draw_line(Vector2(x, vr.end.y), Vector2(x, vr.end.y + 3.0), vc.darkened(0.3), 1.0)
			x += 3.0
	# the family's rosettes at the ends of the valance: someone looks after this shop
	var room := a * 2.0
	if int(S["fam"]) >= 0:
		var fam_col := W.fam_color(int(S["fam"]))
		for s: float in [-1.0, 1.0]:
			var c := Vector2(s * (a - M(0.26)), vr.get_center().y)
			Draw.circle(ci, c, M(0.14), Pal.SIGN_GOLD if bool(S["owned"]) else Pal.AWNING_CREAM)
			Draw.circle(ci, c, M(0.1), fam_col)
			Draw.circle(ci, c + Vector2(-1.2, -1.2), M(0.04), fam_col.lightened(0.35))
		room -= M(0.7)
	var name := String(S["name"]).to_upper()
	var font := _font(S)
	var max_size := int(M(VAL - BAR) * 0.9)
	var size := FX.fit(font, name, room - M(0.4), max_size, 9)
	if size == 0:
		size = FX.fit(W.font("cond"), name, room - M(0.3), max_size, 7)
		font = W.font("cond")
	text(ci, S, vr.get_center() + Vector2(0, 0.5), name, size, ink, font, Color(0, 0, 0, 0.35) if ink != Pal.SIGN_BLACK else Color(0, 0, 0, 0))


## A padlocked shop's awning, cranked up tight against the wall.
static func _rolled_awning(ci: CanvasItem, S: Dictionary) -> void:
	var a := M(float(S["aw_half"]))
	var col: Color = S["col"]
	var r := Rect2(Vector2(-a, M(CORN - 0.02)), Vector2(a * 2.0, M(0.2)))
	Items.shadow_rect(ci, S, r, 0.5, 0.25)
	var sw := M(float(S["stripe"]))
	var x := -a
	var k := 0
	while x < a:
		var c := col if k % 2 == 0 else Pal.AWNING_CREAM
		var seg := Rect2(Vector2(x, r.position.y), Vector2(minf(sw, a - x), r.size.y))
		FX.quad(ci, seg.position, seg.position + Vector2(seg.size.x, 0), seg.end, seg.position + Vector2(0, seg.size.y),
			c.darkened(0.3), c.darkened(0.3), c.darkened(0.05), c.darkened(0.05))
		x += sw
		k += 1
	ci.draw_line(Vector2(-a, r.get_center().y - 1.0), Vector2(a, r.get_center().y - 1.0), Color(1, 1, 1, 0.2), 2.0)
	ci.draw_rect(r, Color(0, 0, 0, 0.35), false, 1.0)


## The notice pasted over the door of a padlocked shop.
static func _notice(ci: CanvasItem, S: Dictionary) -> void:
	var r := Rect2(Vector2(-0.82, CORN + 0.2) * W.M, Vector2(1.64, 0.82) * W.M)
	if String(S["kind"]) == "club":
		r.position.y = M(0.95)
	Items.shadow_rect(ci, S, r, 0.3, 0.3)
	var paper := Color("efe8d6")
	Draw.rect(ci, r, paper)
	ci.draw_rect(r.grow(-2.5), Color("8a2a22"), false, 1.5)
	var cond := W.font("cond")
	var serif := W.font("serif")
	text(ci, S, r.position + Vector2(r.size.x * 0.5, r.size.y * 0.32), "CLOSED", FX.fit(cond, "CLOSED", r.size.x - 10.0, 20, 9), Color("8a2a22"), cond)
	text(ci, S, r.position + Vector2(r.size.x * 0.5, r.size.y * 0.62), "BY ORDER", FX.fit(cond, "BY ORDER", r.size.x - 14.0, 13, 8), Pal.SIGN_BLACK, cond)
	text(ci, S, r.position + Vector2(r.size.x * 0.5, r.size.y * 0.84), "U.S. Prohibition Agent", FX.fit(serif, "U.S. Prohibition Agent", r.size.x - 12.0, 8, 6), Color(0.2, 0.18, 0.15, 0.8), serif)
	# a red wax seal and the tape at the corners
	Draw.circle(ci, r.position + Vector2(r.size.x - 8.0, r.size.y - 8.0), 4.0, Color("a8281e"))
	for c in [r.position, r.position + Vector2(r.size.x, 0)]:
		Draw.poly(ci, PackedVector2Array([c + Vector2(-5, 2), c + Vector2(5, -2), c + Vector2(6, 2), c + Vector2(-4, 6)]), Color(0.9, 0.88, 0.8, 0.8))


static func _canopy(ci: CanvasItem, S: Dictionary) -> void:
	var col: Color = S["col"]
	var cream := Pal.AWNING_CREAM
	var cw := M(CANOPY_HALF)
	var len := M(CANOPY_LEN)
	var y0 := M(0.9)
	# the fabric, a hoop frame under it every half metre
	FX.quad(ci, Vector2(-cw, y0), Vector2(cw, y0), Vector2(cw, len), Vector2(-cw, len), col.darkened(0.35), col.darkened(0.35), col.darkened(0.05), col.darkened(0.05))
	FX.quad(ci, Vector2(-cw, y0), Vector2(-cw * 0.45, y0), Vector2(-cw * 0.45, len), Vector2(-cw, len), Color(1, 1, 1, 0.1), Color(1, 1, 1, 0), Color(1, 1, 1, 0), Color(1, 1, 1, 0.1))
	FX.quad(ci, Vector2(cw * 0.45, y0), Vector2(cw, y0), Vector2(cw, len), Vector2(cw * 0.45, len), Color(0, 0, 0, 0), Color(0, 0, 0, 0.18), Color(0, 0, 0, 0.18), Color(0, 0, 0, 0))
	var y := y0 + M(0.4)
	while y < len - M(0.2):
		ci.draw_line(Vector2(-cw, y), Vector2(cw, y), Color(0, 0, 0, 0.14), 2.0)
		ci.draw_line(Vector2(-cw, y - 1.5), Vector2(cw, y - 1.5), Color(1, 1, 1, 0.1), 1.0)
		y += M(0.45)
	for s: float in [-1.0, 1.0]:
		ci.draw_line(Vector2(s * (cw - 4.0), y0), Vector2(s * (cw - 4.0), len), cream, 2.0)
		ci.draw_line(Vector2(s * (cw - 8.0), y0), Vector2(s * (cw - 8.0), len), Color(cream, 0.7), 1.0)
	# the front valance with a gold fringe
	var val := Rect2(Vector2(-cw, len - M(0.16)), Vector2(cw * 2.0, M(0.16)))
	Draw.rect(ci, val, col.darkened(0.25))
	var x := -cw + 1.5
	while x < cw:
		ci.draw_line(Vector2(x, val.end.y), Vector2(x, val.end.y + 3.0), Pal.SIGN_GOLD, 1.0)
		x += 2.5
	ci.draw_line(val.position + Vector2(2, 2), val.position + Vector2(val.size.x - 2, 2), Color(Pal.SIGN_GOLD, 0.8), 1.0)
	# brass poles at the curb end
	for s: float in [-1.0, 1.0]:
		var p := Vector2(s * cw, len - M(0.05))
		Draw.circle(ci, p, 3.6, Pal.BRASS.darkened(0.35))
		Draw.circle(ci, p + Vector2(-0.6, -0.6), 2.6, Pal.BRASS)
		Draw.circle(ci, p + Vector2(-1.0, -1.0), 1.0, Pal.GOLD2)
	# the monogram
	var mc := Vector2(0, (y0 + len) * 0.5 + M(0.1))
	Draw.circle(ci, mc, M(0.34), Pal.SIGN_GOLD.darkened(0.2))
	Draw.circle(ci, mc, M(0.31), cream)
	Draw.circle(ci, mc, M(0.26), col)
	var init := String(S["name"]).substr(0, 1).to_upper()
	text(ci, S, mc, init, 20, cream, W.font("deco"))
	# the club's name on a lacquered board across the front, over the canopy's root
	var half := float(S["half"])
	var board := Rect2(Vector2(-(half - 0.3), CORN - 0.02) * W.M, Vector2((half - 0.3) * 2.0, 0.5) * W.M)
	Items.shadow_rect(ci, S, board, 0.3, 0.3)
	Draw.rect(ci, board, Pal.SIGN_BLACK)
	ci.draw_rect(board.grow(-3.0), Pal.SIGN_GOLD.darkened(0.15), false, 1.2)
	for s: float in [-1.0, 1.0]:
		# Deco chevrons at the ends
		var ex := s * (board.size.x * 0.5 - M(0.22))
		var cy := board.get_center().y
		for k in 3:
			var d := M(0.05) * k
			Draw.poly(ci, PackedVector2Array([Vector2(ex - s * d, cy - M(0.12)), Vector2(ex - s * (d + M(0.05)), cy), Vector2(ex - s * d, cy + M(0.12)), Vector2(ex - s * (d + 2.0), cy)]), Pal.SIGN_GOLD.darkened(0.1 * k))
	var name := String(S["name"]).to_upper()
	var font := W.font("deco")
	var size := FX.fit(font, name, board.size.x - M(1.0), 18, 8)
	text(ci, S, board.get_center() + Vector2(0, 0.5), name, size, Pal.SIGN_GOLD, font, Color(0, 0, 0, 0.6))


static func _precinct_over(ci: CanvasItem, S: Dictionary) -> void:
	var lit := bool(S["night_on"])
	for s: float in [-1.0, 1.0]:
		var c := Vector2(s * 2.0, 1.2) * W.M
		Items.shadow_circle(ci, S, c, M(0.22), 2.8, 0.2)
		Draw.circle(ci, c, M(0.08), Items.IRON)
		if lit:
			Draw.circle(ci, c, M(0.42), Color(GLOBE, 0.18))
			Draw.circle(ci, c, M(0.3), Color(GLOBE, 0.3))
		var glass := GLOBE.lightened(0.25) if lit else Color("5a7aa0")
		Draw.circle(ci, c, M(0.22), glass.darkened(0.2))
		Draw.circle(ci, c + Items.lit(S) * 1.5, M(0.19), glass)
		Draw.circle(ci, c + Items.lit(S) * M(0.09), M(0.06), Color(1, 1, 1, 0.75 if lit else 0.45))
		Draw.circle(ci, c, M(0.05), Items.IRON)
		Draw.circle(ci, c, M(0.03), Pal.BRASS)


static func _dock_over(ci: CanvasItem, S: Dictionary) -> void:
	# a sign board over the door with the company's name, a caged lamp under it
	var name := String(S["name"]).to_upper()
	var font := W.font("cond")
	var bw := minf(7.4, float(S["w"]) * 0.42)
	var board := Rect2(Vector2(-bw * 0.5, 0.02) * W.M, Vector2(bw, 0.46) * W.M)
	Items.shadow_rect(ci, S, board, 0.4, 0.3)
	Draw.rect(ci, board, Color("2e3a34"))
	ci.draw_rect(board.grow(-2.5), Color("d8cdb4", 0.7), false, 1.0)
	text(ci, S, board.get_center(), name, FX.fit(font, name, board.size.x - M(0.4), 17, 8), Color("e8dfc8"), font)
	var lamp := Vector2(0, 0.62) * W.M
	var lit := bool(S["night_on"])
	ci.draw_line(Vector2(0, board.end.y), lamp, Items.IRON, 2.0)
	if lit:
		Draw.circle(ci, lamp, M(0.3), Color(Pal.LAMP, 0.25))
	Draw.circle(ci, lamp, M(0.1), Color("fff0c0") if lit else Color("8a8270"))
	for k in 4:
		var a := TAU * k / 4.0 + 0.4
		ci.draw_line(lamp + Vector2.from_angle(a) * M(0.04), lamp + Vector2.from_angle(a) * M(0.11), Items.IRON, 1.0)
	ci.draw_arc(lamp, M(0.11), 0.0, TAU, 16, Items.IRON, 1.2, true)


## A sign hanging from an iron arm that sticks out of the wall over the side slot.
static func _bracket_sign(ci: CanvasItem, S: Dictionary, t: String, slot: Rect2, _rng: RandomNumberGenerator) -> void:
	var x := slot.get_center().x
	var base := Vector2(x, M(0.3))
	var tip := Vector2(x, M(1.3))
	var o := Items.sh(S, 3.0)
	ci.draw_line(base + o, tip + o, Color(FX.SHADE, 0.18), 3.0, true)
	ci.draw_line(base, tip, Items.IRON, 3.0, true)
	ci.draw_line(base + Vector2(-1, 0), tip + Vector2(-1, 0), Items.IRON_HI, 0.8, true)
	# a scroll under the arm
	ci.draw_arc(Vector2(x + M(0.08), M(0.62)), M(0.08), PI * 0.5, PI * 2.2, 10, Items.IRON, 1.5, true)
	var c := Vector2(x, M(1.02))
	match t:
		"pawn_balls":
			ci.draw_line(Vector2(x - M(0.3), M(1.12)), Vector2(x + M(0.3), M(1.12)), Items.IRON, 2.5, true)
			var balls := [Vector2(x - M(0.24), M(1.3)), Vector2(x + M(0.24), M(1.3)), Vector2(x, M(0.94))]
			for p in balls:
				Items.shadow_circle(ci, S, p, M(0.19), 2.6, 0.18)
			for p in balls:
				ci.draw_line(p, Vector2(p.x, M(1.12)), Items.IRON, 1.5)
				Draw.circle(ci, p, M(0.19), Pal.BRASS.darkened(0.5))
				Draw.circle(ci, p + Items.lit(S) * 1.5, M(0.17), Pal.BRASS)
				Draw.circle(ci, p + Items.lit(S) * M(0.07), M(0.08), Pal.GOLD2)
				Draw.circle(ci, p + Items.lit(S) * M(0.1), M(0.025), Color(1, 1, 1, 0.9))
		"boot_sign":
			var s := M(0.85)
			var pts := PackedVector2Array([c + Vector2(-0.3, -0.55) * s, c + Vector2(0.15, -0.55) * s, c + Vector2(0.15, 0.1) * s,
				c + Vector2(0.62, 0.2) * s, c + Vector2(0.7, 0.45) * s, c + Vector2(-0.35, 0.45) * s, c + Vector2(-0.35, 0.25) * s])
			var shp := PackedVector2Array()
			for q in pts:
				shp.append(q + Items.sh(S, 2.6))
			Draw.poly(ci, shp, Color(FX.SHADE, 0.18))
			Draw.poly(ci, pts, Pal.SIGN_GOLD.darkened(0.3))
			var inner := Geometry2D.offset_polygon(pts, -2.0)
			if not inner.is_empty():
				Draw.poly(ci, inner[0], Color("2a1a12"))
			ci.draw_line(c + Vector2(-0.3, 0.3) * s, c + Vector2(0.6, 0.32) * s, Pal.SIGN_GOLD, 1.2)
			ci.draw_line(c + Vector2(-0.22, -0.45) * s, c + Vector2(-0.22, 0.2) * s, Color(1, 1, 1, 0.2), 1.0)
		"cigar_sign":
			var a := c + Vector2(-M(0.14), -M(0.4))
			var b := c + Vector2(M(0.14), M(0.4))
			Draw.capsule(ci, a + Items.sh(S, 2.6), b + Items.sh(S, 2.6), M(0.14), Color(FX.SHADE, 0.18))
			Draw.capsule(ci, a, b, M(0.14), Color("5a3620"))
			Draw.capsule(ci, a + Vector2(-1.5, -1.5), b + Vector2(-1.5, -1.5), M(0.1), Color("8a5a34"))
			var band := a.lerp(b, 0.25)
			ci.draw_line(band + (b - a).orthogonal().normalized() * M(0.14), band - (b - a).orthogonal().normalized() * M(0.14), Color("c8282a"), 6.0)
			ci.draw_line(band + (b - a).orthogonal().normalized() * M(0.14), band - (b - a).orthogonal().normalized() * M(0.14), Pal.SIGN_GOLD, 2.0)
			Draw.circle(ci, b, M(0.11), Color("9a9690"))
			Draw.circle(ci, b + (b - a).normalized() * 3.0, M(0.06), Color("e8702a"))
		"mortar_sign":
			var bowl := PackedVector2Array()
			for k in 13:
				var ang := PI * k / 12.0
				bowl.append(c + Vector2(cos(ang) * M(0.4), sin(ang) * M(0.34)))
			bowl.append(c + Vector2(-M(0.4), -M(0.05)))
			bowl.append(c + Vector2(M(0.4), -M(0.05)))
			var shp := PackedVector2Array()
			for q in bowl:
				shp.append(q + Items.sh(S, 2.6))
			Draw.poly(ci, Geometry2D.convex_hull(shp), Color(FX.SHADE, 0.18))
			Draw.poly(ci, Geometry2D.convex_hull(bowl), Pal.BRASS.darkened(0.2))
			Draw.rect(ci, Rect2(c + Vector2(-M(0.44), -M(0.1)), Vector2(M(0.88), M(0.09))), Pal.BRASS)
			Draw.capsule(ci, c + Vector2(M(0.05), -M(0.06)), c + Vector2(M(0.36), -M(0.5)), M(0.065), Pal.BRASS.lightened(0.1))
			Draw.circle(ci, c + Vector2(0, M(0.13)), M(0.12), Pal.SIGN_BLACK)
			text(ci, S, c + Vector2(0, M(0.13)), "Rx", 12, Pal.GOLD2, W.font("serif"))


## A café parasol in summer: eight gores of canvas, cream and the awning colour.
static func _parasol(ci: CanvasItem, S: Dictionary, slot: Rect2, first: bool) -> void:
	var c := slot.get_center()
	var rad := minf(M(1.0), slot.size.x * 0.5 + M(0.25))
	var col: Color = S["col"]
	var L := Items.lit(S)
	var n := 8
	var rot := 0.2 if first else 0.6
	for k in n:
		var a0 := TAU * k / n + rot
		var a1 := TAU * (k + 1) / n + rot
		var mid := Vector2.from_angle((a0 + a1) * 0.5)
		var shade := 1.0 + mid.dot(L) * 0.14
		var cc := col if k % 2 == 0 else Pal.AWNING_CREAM
		cc = Color(cc.r * shade, cc.g * shade, cc.b * shade, 1.0)
		Draw.poly(ci, PackedVector2Array([c, c + Vector2.from_angle(a0) * rad, c + Vector2.from_angle(a1) * rad]), cc)
		ci.draw_line(c, c + Vector2.from_angle(a0) * rad, Color(0, 0, 0, 0.18), 1.0, true)
	ci.draw_arc(c, rad - 1.0, 0.0, TAU, 32, Color(0, 0, 0, 0.2), 1.5, true)
	Draw.circle(ci, c, 3.5, Pal.BRASS.darkened(0.2))
	Draw.circle(ci, c + L, 2.0, Pal.GOLD2)


## The board on the canvas that holds a neon word or the pool hall's bulb marquee.
static func sign_rect(S: Dictionary) -> Rect2:
	var word := String(S["marquee"]) if String(S["marquee"]) != "" else String(S["neon"])
	var font := W.font("cond") if String(S["marquee"]) != "" else W.font("deco")
	var size := 18 if String(S["marquee"]) != "" else 16
	var tw := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var w := minf(tw + M(0.55), M(float(S["aw_half"])) * 2.0 - M(0.5))
	return Rect2(Vector2(-w * 0.5, M(0.44)), Vector2(w, M(0.46)))


static func _sign_board(ci: CanvasItem, S: Dictionary) -> void:
	var r := sign_rect(S)
	Items.shadow_rect(ci, S, r, 0.35, 0.35)
	Draw.rrect(ci, r, 3.0, Color("121010"))
	ci.draw_rect(r.grow(-1.5), Color("3a3430"), false, 1.0)


## The lit part of the sign: neon tubes, or the marquee's bulbs. `t` seconds, for the flicker.
static func paint_lit(ci: CanvasItem, S: Dictionary, t: float) -> void:
	if bool(S["closed"]) or (String(S["neon"]) == "" and String(S["marquee"]) == ""):
		return
	var r := sign_rect(S)
	var on := bool(S["night_on"])
	var ph := float(int(S["id"]) % 7)
	if String(S["marquee"]) != "":
		var word := String(S["marquee"])
		var font := W.font("cond")
		# bulbs all round the board, chasing at night
		var step := M(0.13)
		var pts := []
		var x := r.position.x + step * 0.5
		while x < r.end.x - step * 0.3:
			pts.append(Vector2(x, r.position.y + 3.0))
			pts.append(Vector2(x, r.end.y - 3.0))
			x += step
		var k := 0
		for p in pts:
			var lit := on and (int(t * 6.0) + k / 2) % 3 != 0
			if lit:
				Draw.circle(ci, p, 3.2, Color(Pal.LAMP, 0.3))
			Draw.circle(ci, p, 1.7, Color("fff2c8") if lit else Color("8a8070"))
			k += 1
		var col := Color("fff0c0") if on else Pal.SIGN_GOLD
		if on:
			text(ci, S, r.get_center(), word, 18, Color(Pal.LAMP, 0.35), font, Color(0, 0, 0, 0), 5, Color(Pal.LAMP, 0.25))
		text(ci, S, r.get_center(), word, 18, col, font)
		return
	var word := String(S["neon"])
	var font := W.font("deco")
	if on:
		var k := 0.85 + 0.15 * sin(t * 9.0 + ph) * sin(t * 23.0 + ph * 2.0)
		if Draw.hash01(int(t * 6.0), int(S["id"])) > 0.96:
			k = 0.25
		var glow := Color(Pal.NEON_RED.r, Pal.NEON_RED.g, Pal.NEON_RED.b, 0.35 * k)
		text(ci, S, r.get_center(), word, 16, glow, font, Color(0, 0, 0, 0), 7, Color(Pal.NEON_RED, 0.22 * k))
		text(ci, S, r.get_center(), word, 16, Color(1.0, 0.55 + 0.3 * k, 0.5 + 0.3 * k), font, Color(0, 0, 0, 0), 2, Color(Pal.NEON_RED, 0.9 * k))
	else:
		text(ci, S, r.get_center(), word, 16, Color("8a5a56"), font, Color(0, 0, 0, 0), 1, Color("4a2a28"))
