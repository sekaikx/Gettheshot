class_name PersonLook
extends RefCounted
## Turns (kind, look seed, family colour, extra) into a description of a person: skin, hair,
## hat, clothes, build, props. Person2D (from above) and Portrait (front view) both draw from
## this, so the man on the street and the face in the dialog are the same man.
##
## The face (skin, hair colour, age, moustache) comes from the look seed alone, so a recruit who
## joins your crew keeps his face and only changes his clothes. Everything is deterministic.

const NONE := Color(0, 0, 0, 0)

# cloth and hair, all shades of the Pal colours
const WHITE := Color("f1ebdd")                # shirts, aprons, baker's whites
const CREAM := Color("e3d8c0")
const SHIRT_BLUE := Color("b9c4c8")
const SHIRT_STRIPE := Color("c9bda4")
const STRAW := Color("d8c088")
const KHAKI := Color("a8946e")                # trench coats
const NAVY := Color("27304c")                 # NYPD tunic
const NAVY_PEA := Color("252a38")
const LEATHER := Color("6a4228")
const CANVAS := Color("8a7858")
const RUBBER := Color("2e3a32")
const TWEEDS := [Color("5a4a3a"), Color("6a5a48"), Color("4a4a44"), Color("5e5040"), Color("45403a")]
const FELTS := [Color("3a3834"), Color("4a4640"), Color("5a4c3e"), Color("68645e"), Color("7a7268"), Color("4a3e34"), Color("5e584e")]
const DRESS := [Color("7a2e2a"), Color("2e4a3a"), Color("2a3a5a"), Color("8a6a2a"), Color("5a3a5a"), Color("3a5a5a"), Color("6a3a40"), Color("8a7a60")]
const HAIR := [Color("1c1714"), Color("2b1f17"), Color("3e2c1e"), Color("5a3e26"), Color("7a5a36"), Color("b09062")]
const HAIR_GREY := Color("a8a39a")
const HAIR_RED := Color("b0502a")
const SHOES := [Color("1a1614"), Color("2e1e14"), Color("3a2618")]
const BRASS := Color("c9a54a")

const KINDS := ["boss", "aiboss", "crew", "cop", "fed", "ped", "woman", "kid", "newsboy", "shop", "recruit",
	"smuggler", "dealer", "docker", "unionboss", "consigliere", "bartender", "patron"]
const TRADES := ["bakery", "butcher", "grocer", "tailor", "barber", "cobbler", "pawnshop", "laundry",
	"restaurant", "cafe", "candy", "hardware", "drugstore", "cigar", "fish", "warehouse", "poolhall", "club"]

static var _cache := {}


## Is it summer (straw hats, shirtsleeves)? `extra.summer` wins, else the campaign month.
static func is_summer(extra: Dictionary) -> bool:
	if extra.has("summer"):
		return bool(extra["summer"])
	return (Game.month % 12) in [5, 6, 7]


static func decode(kind: String, look: int, fam: Color = NONE, extra: Dictionary = {}) -> Dictionary:
	var summer := is_summer(extra)
	var key := "%s|%d|%s|%s|%s" % [kind, look, fam.to_html(), str(extra), summer]
	if _cache.has(key):
		return _cache[key]
	var d := _build(kind, look, fam, extra, summer)
	if _cache.size() > 600:
		_cache.clear()
	_cache[key] = d
	return d


static func _pick(r: RandomNumberGenerator, arr: Array) -> Variant:
	return arr[r.randi() % arr.size()]


static func _skin(r: RandomNumberGenerator) -> Color:
	var x := r.randf()
	var i := 0 if x < 0.26 else (1 if x < 0.58 else (2 if x < 0.82 else (3 if x < 0.94 else 4)))
	return Pal.SKIN[i]


static func _build(kind: String, look: int, fam: Color, extra: Dictionary, summer: bool) -> Dictionary:
	# the face: seed only
	var fr := W.rng(look * 2654435761 + 97)
	var skin := _skin(fr)
	var hair: Color = _pick(fr, HAIR)
	var age := fr.randi_range(0, 2)
	var must_roll := fr.randf()
	var face_w := fr.randf_range(-1.0, 1.0)       # narrow .. broad face
	var nose := fr.randf_range(-1.0, 1.0)
	var brow_h := fr.randf_range(-1.0, 1.0)
	var stubble_roll := fr.randf()
	var freck := fr.randf() < 0.18
	var eye_col: Color = _pick(fr, [Color("3a2618"), Color("4a3422"), Color("2a1e14"), Color("4a5a6a"), Color("5a6a4a")])
	var build_roll := fr.randf()
	# finer features for the portrait (rolled last, so the earlier ones never change)
	var feat := {"eye_gap": fr.randf_range(-1.0, 1.0), "eye_size": fr.randf_range(-1.0, 1.0),
		"mouth_w": fr.randf_range(-1.0, 1.0), "jaw": fr.randf_range(-1.0, 1.0), "brow_w": fr.randf_range(-1.0, 1.0),
		"long": fr.randf_range(-1.0, 1.0), "nose_l": fr.randf_range(-1.0, 1.0), "lips": fr.randf_range(-1.0, 1.0)}
	# clothes: seed and kind
	var r := W.rng(look * 40503 + kind.hash() * 7 + 13)
	var has_fam := fam.a > 0.01
	var d := {
		"kind": kind, "female": false, "skin": skin, "hair": hair, "hair_style": "short", "age": age,
		"eye": eye_col, "face_w": face_w, "nose": nose, "brow_h": brow_h,
		"hat": "fedora", "hat_col": _pick(r, FELTS), "band": NONE, "hat_bow": true,
		"coat": "suit", "coat_col": _pick(r, Pal.SUITS), "coat_col2": NONE, "pattern": "",
		"shirt": WHITE if r.randf() < 0.6 else _pick(r, [CREAM, SHIRT_BLUE, SHIRT_STRIPE]),
		"tie": "tie", "tie_col": _pick(r, [Color("5a2a26"), Color("2a3448"), Color("3a3a36"), Color("5a4a2a"), Color("4a2a3e")]),
		"vest": NONE, "braces": NONE, "apron": "", "armband": NONE, "scarf": NONE, "flower": NONE,
		"sleeves": "long", "trousers": NONE, "shoes": _pick(r, SHOES),
		"w": 1.0, "d": 1.0, "scale": 1.0, "head": 1.0,
		"glasses": false, "mustache": "", "stubble": false, "freckles": freck, "scar": false,
		"props": [], "fur": NONE, "family": fam, "trade": String(extra.get("trade", "")),
		"lipstick": NONE, "earrings": false, "pearls": false, "feather": NONE,
	}
	d.merge(feat)
	# build
	if build_roll < 0.22:
		d["w"] = 0.9; d["d"] = 0.92
	elif build_roll < 0.72:
		pass
	elif build_roll < 0.92:
		d["w"] = 1.07; d["d"] = 1.08
	else:
		d["w"] = 1.15; d["d"] = 1.16
	# moustaches: common on older men
	if must_roll < 0.12 + age * 0.12:
		d["mustache"] = _pick(r, ["full", "full", "pencil", "walrus"])
	d["stubble"] = stubble_roll < 0.15
	if age == 2 and fr.randf() < 0.55:
		d["hair"] = hair.lerp(HAIR_GREY, 0.55)
	match kind:
		"boss":
			d["age"] = mini(age, 1)
			d["coat"] = "three"
			d["coat_col"] = _pick(r, [Pal.SUITS[0], Pal.SUITS[4], Pal.SUITS[1], Color("1f2024")])
			d["hat"] = "fedora"
			d["hat_col"] = _pick(r, [Color("2e2d2b"), Color("3a3834"), Color("46423c"), Color("3e3a36")])
			d["band"] = fam if has_fam else Color("1a1816")
			d["tie_col"] = fam.darkened(0.2) if has_fam else Color("5a2a26")
			d["shirt"] = WHITE
			# the white silk scarf marks the boss; some wear a carnation too
			d["scarf"] = WHITE
			if r.randf() < 0.45:
				d["flower"] = Color("c83a3a") if r.randf() < 0.7 else WHITE
			d["w"] = maxf(float(d["w"]), 1.0)
			d["shoes"] = Color("141210")
			d["stubble"] = false
		"aiboss":
			d["age"] = 2
			d["hair"] = hair.lerp(HAIR_GREY, 0.7)
			d["coat"] = "overcoat"
			d["coat_col"] = _pick(r, [Pal.SUITS[0], Pal.SUITS[1], Color("2a2622"), Pal.SUITS[4]])
			d["fur"] = _pick(r, [Color("3a2e24"), Color("1e1a18"), Color("4a3a2c")])
			d["hat"] = "homburg"
			d["hat_col"] = _pick(r, [Color("26252a"), Color("3a3632"), Color("4a443c")])
			d["band"] = fam if has_fam else Color("141312")
			d["tie_col"] = fam.darkened(0.25) if has_fam else Color("3a2a2a")
			d["w"] = 1.15; d["d"] = 1.18
			d["props"] = ["cigar"]
			if d["mustache"] == "" and r.randf() < 0.5:
				d["mustache"] = "full"
			d["stubble"] = false
		"crew":
			d["age"] = mini(age, 1)
			if r.randf() < 0.5 and not summer:
				d["coat"] = "suit"
				d["coat_col"] = _pick(r, Pal.SUITS)
				d["hat"] = "fedora"
				d["band"] = fam if has_fam else Color("1a1816")
				d["tie_col"] = fam.darkened(0.15) if has_fam else d["tie_col"]
			else:
				d["coat"] = "shirt"
				d["shirt"] = _pick(r, [WHITE, CREAM, SHIRT_BLUE, SHIRT_STRIPE])
				d["braces"] = _pick(r, [Color("2a2420"), Color("4a3a2a"), Color("3a3a40")])
				d["vest"] = _pick(r, [NONE, NONE, Pal.SUITS[0], Pal.SUITS[3]])
				d["sleeves"] = "rolled" if r.randf() < 0.6 else "long"
				d["hat"] = _pick(r, ["newsboy", "flat", "fedora"])
				d["hat_col"] = _pick(r, TWEEDS) if d["hat"] != "fedora" else _pick(r, FELTS)
				d["band"] = fam if (has_fam and d["hat"] == "fedora") else Color("1a1816")
				d["tie_col"] = fam.darkened(0.15) if has_fam else d["tie_col"]
				if has_fam:
					d["armband"] = fam
			if summer and d["hat"] == "fedora" and r.randf() < 0.4:
				d["hat"] = "boater"; d["hat_col"] = STRAW
		"cop":
			d["coat"] = "tunic"
			d["coat_col"] = NAVY
			d["hat"] = "police"
			d["hat_col"] = NAVY
			d["tie"] = ""
			d["shoes"] = Color("121110")
			d["props"] = ["nightstick", "badge"]
			d["w"] = maxf(float(d["w"]), 1.0)
			if d["mustache"] == "" and r.randf() < 0.3:
				d["mustache"] = "full"
			d["stubble"] = false
		"fed":
			d["coat"] = "trench"
			d["coat_col"] = _pick(r, [KHAKI, KHAKI.darkened(0.1), Color("9a8a68"), Color("8e8062")])
			d["hat"] = "fedora"
			d["hat_col"] = _pick(r, [Color("6a6660"), Color("5a5750"), Color("7a766e")])
			d["band"] = Color("2a2826")
			d["tie_col"] = Color("2a2e3a")
			d["stubble"] = false
			d["mustache"] = "" if r.randf() < 0.7 else "pencil"
		"ped":
			var style := r.randi_range(0, 5)
			match style:
				0:
					d["coat"] = "overcoat"; d["hat"] = "fedora"
				1:
					d["coat"] = "suit"; d["hat"] = "bowler"; d["hat_col"] = _pick(r, [Color("1e1c1a"), Color("3a2e24")])
				2:
					d["coat"] = "jacket"; d["coat_col"] = _pick(r, TWEEDS); d["hat"] = "newsboy"; d["hat_col"] = _pick(r, TWEEDS); d["tie"] = ""
				3:
					d["coat"] = "shirt"; d["braces"] = _pick(r, [Color("2a2420"), Color("4a3a2a")]); d["hat"] = "flat"
					d["hat_col"] = _pick(r, TWEEDS); d["sleeves"] = "rolled" if r.randf() < 0.5 else "long"; d["tie"] = ""
				4:
					d["coat"] = "suit"; d["hat"] = "fedora"
				_:
					d["coat"] = "jacket"; d["coat_col"] = _pick(r, TWEEDS); d["hat"] = "flat"; d["hat_col"] = _pick(r, TWEEDS)
			if d["coat"] != "jacket" and d["coat"] != "shirt":
				d["coat_col"] = _pick(r, Pal.SUITS)
			if summer:
				if d["hat"] in ["fedora", "bowler"] and r.randf() < 0.6:
					d["hat"] = "boater"; d["hat_col"] = STRAW
				if d["coat"] == "overcoat":
					d["coat"] = "suit"
			if r.randf() < 0.1:
				d["hat"] = ""
				d["hair_style"] = _pick(r, ["short", "part", "slick"])
			if not summer and r.randf() < 0.14:
				d["scarf"] = _pick(r, [Color("7a2e2a"), Color("5a5048"), Color("8a7a60"), Color("2a3a5a")])
		"woman", "patron":
			d["female"] = true
			d["mustache"] = ""; d["stubble"] = false
			d["w"] = 0.86; d["d"] = 0.9
			d["hair_style"] = _pick(r, ["bob", "bob", "bun", "curly"])
			d["lipstick"] = Color("9a2a2e").lerp(Color("c2464a"), r.randf())
			d["earrings"] = r.randf() < 0.5
			d["tie"] = ""
			d["shoes"] = _pick(r, [Color("1a1614"), Color("5a2a26"), Color("3a2a1e")])
			if kind == "patron" and r.randf() < 0.45:
				# a man in evening dress
				d["female"] = false
				d["w"] = 1.0; d["d"] = 1.0
				d["coat"] = "tux"; d["coat_col"] = Color("161618"); d["shirt"] = WHITE
				d["tie"] = "bow"; d["tie_col"] = Color("0e0e10")
				d["hat"] = "" if r.randf() < 0.6 else "top"
				d["hat_col"] = Color("121214")
				d["hair_style"] = "slick"
				d["lipstick"] = NONE; d["earrings"] = false
				if r.randf() < 0.3:
					d["mustache"] = "pencil"
			elif kind == "patron":
				d["coat"] = "flapper"
				d["coat_col"] = _pick(r, [Color("1a1a1c"), Color("7a2e2a"), Color("c9b48a"), Color("2e4a3a"), Color("5a3a5a"), Color("c8c0b0")])
				d["hat"] = "headband" if r.randf() < 0.7 else ""
				d["hat_col"] = _pick(r, [Color("1a1a1c"), BRASS, Color("c8c0b0")])
				d["feather"] = _pick(r, [WHITE, Color("1a1a1c"), Color("c83a3a"), BRASS]) if d["hat"] == "headband" else NONE
				d["pearls"] = r.randf() < 0.7
				d["sleeves"] = "bare"
				d["hair_style"] = "bob"
				d["hair"] = _pick(r, [Color("1c1714"), Color("2b1f17"), Color("5a3e26"), Color("b09062")])
			else:
				d["hat"] = "cloche"
				d["hat_col"] = _pick(r, [Color("5a2a30"), Color("2e4a42"), Color("3a3446"), Color("6a5a40"), Color("4a4a4e"), Color("7a4a2e"), Color("2a3a5a")])
				d["band"] = _pick(r, [Color("1a1614"), CREAM, Color("7a2e2a"), Color("c9a54a")])
				if summer or r.randf() < 0.35:
					d["coat"] = "dress"
					d["coat_col"] = _pick(r, DRESS).lightened(0.08)
					d["sleeves"] = "bare" if summer else "long"
				else:
					d["coat"] = "coat_w"
					d["coat_col"] = _pick(r, [Color("8a7258"), Color("5a2a30"), Color("4a4a4e"), Color("2e3e38"), Color("6a5a48"), Color("3a3446")])
					if r.randf() < 0.55:
						d["fur"] = _pick(r, [Color("3a2e24"), Color("5a4432"), Color("2a2420"), Color("7a6a58")])
				d["pearls"] = r.randf() < 0.3
				if age == 2:
					d["hair"] = hair.lerp(HAIR_GREY, 0.6)
		"kid", "newsboy":
			d["age"] = -1
			d["scale"] = 0.72; d["head"] = 0.86
			d["w"] = 0.92; d["d"] = 0.94
			d["mustache"] = ""; d["stubble"] = false
			d["hair"] = _pick(r, HAIR)
			d["coat"] = _pick(r, ["jacket", "sweater", "shirt"])
			d["coat_col"] = _pick(r, TWEEDS) if d["coat"] != "shirt" else CREAM
			if d["coat"] == "shirt":
				d["braces"] = Color("3a2e24")
			d["tie"] = ""
			d["hat"] = "newsboy" if (kind == "newsboy" or r.randf() < 0.75) else ""
			d["hat_col"] = _pick(r, TWEEDS)
			d["hair_style"] = "crop"
			d["trousers"] = _pick(r, TWEEDS).darkened(0.1)
			d["freckles"] = r.randf() < 0.4
			if kind == "newsboy":
				d["props"] = ["papers"]
		"shop":
			_trade(d, r, String(extra.get("trade", "")), summer)
		"recruit":
			d["age"] = mini(age, 1)
			d["coat"] = "shirt"
			d["shirt"] = _pick(r, [CREAM, WHITE.darkened(0.08), SHIRT_STRIPE, Color("8a8070")])
			d["sleeves"] = "rolled"
			d["braces"] = _pick(r, [Color("2a2420"), Color("4a3a2a"), NONE])
			d["vest"] = _pick(r, [NONE, Pal.SUITS[1], Pal.SUITS[5]])
			d["tie"] = ""
			d["hat"] = "flat" if r.randf() < 0.6 else "newsboy"
			d["hat_col"] = _pick(r, TWEEDS)
			d["w"] = maxf(float(d["w"]), 1.07); d["d"] = maxf(float(d["d"]), 1.05)
			d["stubble"] = r.randf() < 0.5
			d["scar"] = r.randf() < 0.35
		"smuggler":
			d["coat"] = "peacoat"
			d["coat_col"] = _pick(r, [NAVY_PEA, Color("2a2a2c"), Color("30323a")])
			d["hat"] = "watch"
			d["hat_col"] = _pick(r, [Color("2a2e3a"), Color("3a3a3a"), Color("5a2a26"), Color("4a4a3a")])
			d["tie"] = ""
			d["stubble"] = true
			d["w"] = maxf(float(d["w"]), 1.05)
		"dealer":
			d["coat"] = "suit"
			d["pattern"] = "check"
			d["coat_col"] = Color("a08a5e")
			d["coat_col2"] = Color("6a3a2a")
			d["hat"] = "boater" if summer else "fedora"
			d["hat_col"] = STRAW if summer else Color("8a7a60")
			d["band"] = Color("c83a3a")
			d["tie"] = "bow"; d["tie_col"] = Color("c83a3a")
			d["shirt"] = CREAM
			d["mustache"] = "pencil"
			d["flower"] = Color("e8d24a")
			d["w"] = 1.07; d["d"] = 1.1
			d["props"] = ["cigar"]
		"docker":
			d["coat"] = _pick(r, ["jacket", "shirt"])
			d["coat_col"] = _pick(r, [CANVAS, Color("5a5040"), Color("4a4a44"), Color("3e4650")])
			d["shirt"] = _pick(r, [Color("7a8288"), CREAM, Color("8a7a60")])
			d["sleeves"] = "rolled"
			d["braces"] = Color("3a2e24") if d["coat"] == "shirt" else NONE
			d["tie"] = "neckerchief"
			d["tie_col"] = _pick(r, [Color("7a2e2a"), Color("2a3a5a"), Color("5a5048")])
			d["hat"] = _pick(r, ["flat", "newsboy", "watch"])
			d["hat_col"] = _pick(r, TWEEDS)
			d["props"] = ["hook"]
			d["stubble"] = r.randf() < 0.6
			d["w"] = maxf(float(d["w"]), 1.05); d["d"] = maxf(float(d["d"]), 1.05)
		"unionboss":
			d["age"] = 1
			d["hair"] = HAIR_RED
			d["hair_style"] = "red"
			d["hat"] = ""
			d["coat"] = "shirt"
			d["shirt"] = Color("d8ccb4")
			d["vest"] = Color("4a4034")
			d["braces"] = NONE
			d["sleeves"] = "rolled"
			d["tie"] = "tie"; d["tie_col"] = Color("2a4a32")
			d["w"] = 1.22; d["d"] = 1.22
			d["freckles"] = true
			d["mustache"] = "walrus"
			d["eye"] = Color("4a6a7a")
			d["skin"] = Pal.SKIN[0]
		"consigliere":
			d["age"] = 2
			d["hair"] = HAIR_GREY.lightened(0.1)
			d["hair_style"] = "bald"
			d["hat"] = ""
			d["glasses"] = true
			if r.randf() < 0.5:
				d["coat"] = "cardigan"
				d["coat_col"] = _pick(r, [Color("5a3a34"), Color("5a5a4a"), Color("4a4a52"), Color("6a5a44")])
				d["tie_col"] = Color("2a2e3a")
			else:
				d["coat"] = "three"
				d["coat_col"] = Pal.SUITS[0]
				d["tie_col"] = fam.darkened(0.3) if has_fam else Color("3a2a2a")
			d["w"] = 0.94; d["d"] = 0.96
			d["mustache"] = "full" if r.randf() < 0.5 else ""
			d["stubble"] = false
		"bartender":
			d["coat"] = "vest"
			d["shirt"] = WHITE
			d["vest"] = _pick(r, [Color("26252a"), Color("3a2a24"), Color("5a2a26")])
			d["tie"] = "bow"; d["tie_col"] = Color("121214")
			d["hat"] = ""
			d["hair_style"] = "part"
			d["props"] = ["garters"]
			if d["mustache"] == "" and r.randf() < 0.5:
				d["mustache"] = "full"
			d["stubble"] = false
		_:
			pass
	# story characters can pin a hat: extra = {"hat": "bowler", "hat_col": Color(...)}
	if extra.has("hat"):
		d["hat"] = String(extra["hat"])
		var own: Dictionary = {"boater": STRAW, "toque": WHITE, "paper": WHITE, "police": NAVY, "visor": Color("3a6a4a"),
			"headband": BRASS, "cloche": Color("5a2a30"), "top": Color("121214"), "watch": Color("2a2e3a")}
		if own.has(d["hat"]):
			d["hat_col"] = own[d["hat"]]
		if d["hat"] == "headband" and d["feather"] == NONE:
			d["feather"] = WHITE
	if extra.has("hat_col"):
		d["hat_col"] = extra["hat_col"]
	if d["trousers"] == NONE:
		d["trousers"] = (d["coat_col"] as Color).darkened(0.12) if d["coat"] in ["suit", "three", "tux", "overcoat", "tunic", "trench", "peacoat"] else _pick(r, [Pal.SUITS[1], Pal.SUITS[3], Pal.SUITS[5], Color("3a3630")])
	if d["hat"] == "" and d["hair_style"] == "short" and not d["female"]:
		d["hair_style"] = _pick(r, ["short", "part", "slick"])
	if d["band"] == NONE and d["hat"] in ["fedora", "homburg", "bowler", "top"]:
		d["band"] = (d["hat_col"] as Color).darkened(0.55)
	if d["hat"] == "boater" and d["band"] == NONE:
		d["band"] = _pick(r, [Color("2a3448"), Color("7a2e2a"), Color("1a1816")])
	return d


static func _trade(d: Dictionary, r: RandomNumberGenerator, trade: String, summer: bool) -> void:
	d["coat"] = "shirt"
	d["shirt"] = _pick(r, [WHITE, CREAM, SHIRT_BLUE])
	d["sleeves"] = "rolled" if r.randf() < 0.5 else "long"
	d["tie"] = "tie" if r.randf() < 0.5 else ""
	d["hat"] = ""
	d["hair_style"] = _pick(r, ["short", "part", "slick", "bald"]) if d["age"] == 2 else _pick(r, ["short", "part", "slick"])
	d["apron"] = "white"
	match trade:
		"bakery":
			d["hat"] = "toque"; d["hat_col"] = WHITE
			d["shirt"] = WHITE; d["tie"] = ""
			d["w"] = maxf(float(d["w"]), 1.07); d["d"] = maxf(float(d["d"]), 1.1)
		"butcher":
			d["apron"] = "striped"
			d["hat"] = "boater"; d["hat_col"] = STRAW; d["band"] = Color("2a3448")
			d["shirt"] = WHITE; d["sleeves"] = "rolled"
			d["w"] = maxf(float(d["w"]), 1.07); d["d"] = maxf(float(d["d"]), 1.08)
		"barber":
			d["coat"] = "whitejacket"; d["coat_col"] = WHITE
			d["apron"] = ""
			d["hair_style"] = "slick"
			d["mustache"] = "full" if r.randf() < 0.6 else "pencil"
			d["props"] = ["comb"]
		"tailor":
			d["coat"] = "vest"; d["vest"] = _pick(r, [Pal.SUITS[0], Pal.SUITS[3], Color("3a3448")])
			d["apron"] = ""
			d["glasses"] = r.randf() < 0.6
			d["props"] = ["tape", "pins"]
			d["sleeves"] = "long"
		"grocer":
			d["hat"] = "flat" if r.randf() < 0.5 else ""
			d["hat_col"] = _pick(r, TWEEDS)
			d["props"] = ["garters", "pencil"]
		"cobbler":
			d["apron"] = "leather"
			d["hat"] = "flat" if r.randf() < 0.4 else ""
			d["hat_col"] = _pick(r, TWEEDS)
			d["glasses"] = r.randf() < 0.5
		"pawnshop":
			d["coat"] = "vest"; d["vest"] = _pick(r, [Pal.SUITS[1], Pal.SUITS[3]])
			d["apron"] = ""
			d["hat"] = "visor"; d["hat_col"] = Color("3a6a4a")
			d["props"] = ["garters"]
			d["glasses"] = r.randf() < 0.4
		"laundry":
			d["apron"] = "canvas"
			d["sleeves"] = "rolled"
			d["tie"] = ""
		"restaurant":
			d["coat"] = "vest"; d["vest"] = Pal.SUITS[0]
			d["tie"] = "bow"; d["tie_col"] = Color("121214")
			d["apron"] = "white"
			d["mustache"] = "full" if r.randf() < 0.6 else d["mustache"]
			d["w"] = maxf(float(d["w"]), 1.1); d["d"] = maxf(float(d["d"]), 1.14)
		"cafe":
			d["coat"] = "vest"; d["vest"] = _pick(r, [Pal.SUITS[1], Color("3a2a24")])
			d["tie"] = "bow"; d["tie_col"] = Color("5a2a26")
			d["apron"] = "white"
		"candy":
			d["shirt"] = Color("e8d8d0")
			d["hat"] = "paper"; d["hat_col"] = WHITE
			d["tie"] = "bow"; d["tie_col"] = Color("9a2a2e")
			d["apron"] = "white"
		"hardware":
			d["coat"] = "jacket"; d["coat_col"] = Color("7a6448")
			d["apron"] = ""
			d["hat"] = "flat" if r.randf() < 0.5 else ""
			d["hat_col"] = _pick(r, TWEEDS)
			d["props"] = ["pencil"]
		"drugstore":
			d["coat"] = "whitejacket"; d["coat_col"] = WHITE
			d["apron"] = ""
			d["glasses"] = true
		"cigar":
			d["coat"] = "vest"; d["vest"] = _pick(r, [Pal.SUITS[3], Pal.SUITS[1]])
			d["apron"] = ""
			d["hat"] = "bowler" if r.randf() < 0.4 else ""
			d["hat_col"] = Color("2a2622")
			d["props"] = ["cigar"]
		"fish":
			d["apron"] = "rubber"
			d["hat"] = "flat"; d["hat_col"] = _pick(r, TWEEDS)
			d["sleeves"] = "rolled"
			d["tie"] = ""
		_:
			d["apron"] = "canvas" if r.randf() < 0.5 else "white"
			d["hat"] = "flat" if r.randf() < 0.5 else ""
			d["hat_col"] = _pick(r, TWEEDS)
	if summer and d["hat"] == "flat" and r.randf() < 0.4:
		d["hat"] = "boater"; d["hat_col"] = STRAW; d["band"] = Color("2a3448")
