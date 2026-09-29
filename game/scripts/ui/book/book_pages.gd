extends RefCounted
## What's written in the family book: one builder per tab. Each returns blocks (a height and a
## draw function) that the book lays out over its pages:
##   {"mode": "spread", "blocks": [...]}             one story across both pages (Family)
##   {"mode": "split", "left": [...], "right": [...]} a story on each page, turned separately
## Buttons only ever ask the host (bk.ask -> Net.to_host). Words: short, plain, second person.

const Art := preload("res://scripts/ui/book/art.gd")
const Icons := preload("res://scripts/ui/book/icons.gd")
const L := 1   # the book's page layer (FamilyBook.L_PAGES)

const EV_NAME := {"witness": "A WITNESS", "street": "STREET TALK", "cop": "A COP'S NOTEBOOK", "weapon": "YOUR GUN",
	"ledger": "THE BOOKS", "body": "A BODY", "informant": "AN INFORMANT", "file": "YOUR BREWERY"}
const EV_HOW := {
	"witness": "Go and see him in his shop. Pay him to forget, or scare him quiet.",
	"street": "Talk on the street. It fades fast. A police captain on your payroll makes it fade faster.",
	"cop": "Put that patrolman on your payroll and his notebook goes missing.",
	"weapon": "Throw the gun in the river, off the end of a pier.",
	"ledger": "Burn the books at the desk in your club.",
	"body": "Send the cleanup crew before the police find it.",
	"informant": "If he testifies, you go down. Reach him inside: a guard, a cook, a cellmate.",
	"file": "A brewery or still you run. Buying the city's police slows the raids. It fades once the plant is gone.",
}

var bk: Control


func _init(book: Control) -> void:
	bk = book


func me() -> int:
	return int(Game.player(Net.my_id()).get("family", -1))


func _b(h: float, fn: Callable, keep: bool = false, brk: bool = false) -> Dictionary:
	return {"h": h, "draw": fn, "keep": keep, "brk": brk}


## Everything a page shows, boiled down: when it changes, the book is rebuilt.
func signature(tab: int) -> int:
	var fid := me()
	var f := Game.fam(fid)
	var parts: Array = [tab, fid, Game.month, Game.families.size()]
	if f.is_empty():
		return hash(parts)
	parts.append([int(f["dirty"]) / 10, int(f["clean"]) / 10, int(f["heat"]), f["income"], f["launder_on"], f["support_jailed"], f["rep"]])
	for e in f["evidence"]:
		parts.append([e["id"], int(float(e["w"]))])
	for c in Game.crew:
		if int(c["family"]) == fid:
			parts.append([c["id"], c["state"], c["task"], c["target"], c["loyalty"], c["wage"], c.get("booze", 0), c["rank"], c["jail_until"], c["name"]])
		else:
			parts.append([c["family"], c["state"]])
	for b in Game.biz:
		parts.append([b["protector"], b["owned_by"], b["speak"], b["stock"], b["envelope"], b["unpaid"], b["closed_until"]])
	for o in Game.families:
		parts.append([o["alive"], o["kept"], o["broken"], o["ai"]])
		if int(o["id"]) != fid:
			var r := Game.rel(fid, int(o["id"]))
			parts.append([r["war"], r["truce_until"]])
		if tab == 4:
			parts.append(Game.legacy(int(o["id"])) / 50)
	for d in Game.deals:
		parts.append([d["id"], d["to"]])
	parts.append(Game.players.size())
	parts.append(Game.nyc_warehouse(fid).is_empty())
	return hash(parts)


func build(tab_id: String, cw: float) -> Dictionary:
	if Game.fam(me()).is_empty():
		return {"mode": "split", "left": [_header("The family book", "You don't have a family yet.", cw)], "right": []}
	match tab_id:
		"family": return _family(cw)
		"rackets": return _rackets(cw)
		"heat": return _heat(cw)
		"rivals": return _rivals(cw)
		"money": return _money(cw)
	return {}


# ------------------------------------------------------------------ shared blocks

func _header(title: String, sub: String, cw: float) -> Dictionary:
	var sub_h := Art.para_h(sub, "fell", 19, cw, 24.0, 3) if sub != "" else 0.0
	var h := 54.0 + sub_h + 20.0
	return _b(h, func(ci: Control, r: Rect2) -> void:
		Art.text(ci, r.position + Vector2(0, 38), title, "serif", 36, Art.INK)
		if sub != "":
			Art.para(ci, r.position + Vector2(0, 52), sub, "fell", 19, Art.INK_SOFT, cw, 24.0, 3)
		Art.rule(ci, Vector2(r.position.x, r.end.y - 14), Vector2(r.end.x, r.end.y - 14), Color(Art.INK_SOFT, 0.75), true), true)


func _section(title: String, note: String = "") -> Dictionary:
	return _b(44.0, func(ci: Control, r: Rect2) -> void:
		Art.text(ci, r.position + Vector2(0, 30), title.to_upper(), "fell_sc", 19, Art.OXBLOOD)
		if note != "":
			Art.text_r(ci, Vector2(r.end.x, r.position.y + 30), note, "fell", 17, Art.INK_SOFT)
		ci.draw_line(Vector2(r.position.x, r.position.y + 38), Vector2(r.end.x, r.position.y + 38), Color(Art.OXBLOOD, 0.35), 1.0), true)


func _note(s: String, cw: float, icon: String = "") -> Dictionary:
	var ix := 34.0 if icon != "" else 0.0
	var h := Art.para_h(s, "fell", 19, cw - ix, 25.0) + 22.0
	return _b(h, func(ci: Control, r: Rect2) -> void:
		if icon != "":
			Icons.draw(ci, icon, r.position + Vector2(12, 18), 22.0, Color(Art.INK_SOFT, 0.8), Art.PAPER)
		Art.para(ci, r.position + Vector2(ix, 4), s, "fell", 19, Art.INK_SOFT, cw - ix, 25.0))


func _gap(h: float) -> Dictionary:
	return _b(h, Callable())


func _button_row(ci: Control, r: Rect2, specs: Array, size: int = 17) -> void:
	## specs: [{id, text, cb, style, on, tip, icon}] laid out across r, widths by their words
	var gap := 8.0
	var natural := 0.0
	for s in specs:
		natural += Art.button_w(String(s["text"]), size, String(s.get("icon", "")) != "")
	var extra := maxf(0.0, (r.size.x - natural - gap * (specs.size() - 1)) / maxf(1, specs.size()))
	var scale := minf(1.0, (r.size.x - gap * (specs.size() - 1)) / maxf(1.0, natural))
	var x := r.position.x
	for s in specs:
		var w := Art.button_w(String(s["text"]), size, String(s.get("icon", "")) != "") * scale + extra
		bk.btn(ci, L, String(s["id"]), Rect2(x, r.position.y, w, r.size.y), String(s["text"]), s["cb"], String(s.get("style", "ink")),
			bool(s.get("on", true)), String(s.get("tip", "")), String(s.get("icon", "")), "", size)
		x += w + gap


func _info(id: String, r: Rect2, tip: String) -> void:
	bk.hits.add(L, id, r, Callable(), false, tip)


func _my_shops(include_club: bool = true) -> Array:
	var fid := me()
	var out := Game.biz.filter(func(b: Dictionary) -> bool:
		return (int(b["protector"]) == fid or int(b["owned_by"]) == fid) and String(b["kind"]) != "precinct" \
			and (include_club or String(b["kind"]) != "club"))
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ka := 0 if int(a.get("hq_of", -1)) == fid else 1
		var kb := 0 if int(b.get("hq_of", -1)) == fid else 1
		if ka != kb:
			return ka < kb
		if String(a["district"]) != String(b["district"]):
			return String(a["district"]) < String(b["district"])
		return String(a["name"]) < String(b["name"]))
	return out


func _first(s: String) -> String:
	return s.split(" ")[0] if s != "" else s


# ------------------------------------------------------------------ Family

func _family(cw: float) -> Dictionary:
	var fid := me()
	var f := Game.fam(fid)
	var free := Game.crew_of(fid)
	var inside := Game.crew.filter(func(c: Dictionary) -> bool: return int(c["family"]) == fid and String(c["state"]) in ["jailed", "rat"])
	var away := Game.crew.filter(func(c: Dictionary) -> bool: return int(c["family"]) == fid and String(c["state"]) == "away")
	var wages := 0
	for c in free:
		wages += int(c["wage"])
	var sub := "%s on the street" % _count(free.size(), "man", "men")
	if not away.is_empty():
		sub += ", %d out of town" % away.size()
	if not inside.is_empty():
		sub += ", %d inside" % inside.size()
	sub += ". Wages: %s a month." % Art.money(wages)
	var left: Array = [_header("Your Men", sub, cw)]
	if free.is_empty():
		left.append(_note("Nobody's on the street for you. Hire muscle at a pool hall: the tough guys by the door want work.", cw, "men"))
	for c in free:
		left.append(_crew_card(c, cw))
	var right: Array = [_family_front(f, free.size(), cw)]
	if not away.is_empty():
		right.append(_section("Out of town", _count(away.size(), "man", "men")))
		for c in away:
			right.append(_small_card(c, cw))
	right.append(_section("In prison", _count(inside.size(), "man", "men") if not inside.is_empty() else ""))
	if inside.is_empty():
		right.append(_note("Nobody's inside. Keep it that way.", cw))
	for c in inside:
		right.append(_small_card(c, cw))
	right.append(_support(f, inside.size(), cw))
	right.append(_section("More men"))
	right.append(_note("Go to a pool hall: the tough guys by the door want work. You pay once to hire a man, then his wage every month.", cw, "fist"))
	return {"mode": "split", "left": left, "right": right}


func _rep_word(rep: int) -> String:
	if rep >= 80:
		return "Feared"
	if rep >= 45:
		return "Respected"
	if rep >= 20:
		return "Known"
	return "Unknown"


## The family's front page: the crest, the don, the numbers that matter.
func _family_front(f: Dictionary, men: int, cw: float) -> Dictionary:
	var fid := int(f["id"])
	var bosses: Array = []
	for k in Game.players:
		if int(Game.players[k]["family"]) == fid:
			bosses.append(String(Game.players[k]["name"]))
	var don := "Don %s" % " & ".join(bosses) if not bosses.is_empty() else "The don"
	var shops := 0
	for b in Game.shops_of(fid):
		if int(b["owned_by"]) != fid:
			shops += 1
	var stats := [["Men", str(men), "men"], ["Rackets", str(shops), "shop"], ["Heat", str(int(round(float(f["heat"])))), "heat"],
		["Reputation", _rep_word(int(f["rep"])), "crown"]]
	return _b(270.0, func(ci: Control, r: Rect2) -> void:
		var c := Vector2(r.get_center().x, r.position.y + 64)
		Art.ornament(ci, Vector2(c.x, c.y), r.size.x * 0.46, Color(Art.INK_SOFT, 0.5))
		Art.crest(ci, c, 110.0, Art.fam_color(fid), Art.initial(fid))
		Art.text_c(ci, Vector2(c.x, r.position.y + 160), "The %s Family" % f["name"], "serif", 32, Art.INK)
		Art.text_c(ci, Vector2(c.x, r.position.y + 186), "%s  ·  New York, since %d" % [don, Game.START_YEAR + int(Game.cfg.get("start_month", 0)) / 12], "fell", 18, Art.INK_SOFT)
		var gap := 10.0
		var w := (r.size.x - gap * 3.0) / 4.0
		for k in 4:
			var st: Array = stats[k]
			var br := Rect2(r.position.x + k * (w + gap), r.position.y + 202, w, 58)
			Art.box(ci, br, Color(Art.PAPER_LIGHT, 0.75), Art.CARD_EDGE, 1, 4)
			Icons.draw(ci, String(st[2]), br.position + Vector2(18, 20), 16.0, Art.INK_SOFT, Art.PAPER_LIGHT)
			Art.text(ci, br.position + Vector2(32, 25), String(st[0]).to_upper(), "fell_sc", 15, Art.INK_SOFT)
			var vs := String(st[1])
			var fs := 24 if vs.length() <= 5 else 19
			Art.text(ci, br.position + Vector2(12, 50), Art.fit(vs, "serif", fs, w - 20.0), "serif", fs, Art.OXBLOOD if k == 2 and int(round(float(f["heat"]))) >= 70 else Art.INK)
		_info("rep", Rect2(r.position.x + 3 * (w + gap), r.position.y + 202, w, 58), "Your name on the street. Deals, wins and favors raise it; broken truces lower it. Shopkeepers listen to a big name."))


func _count(n: int, one: String, many: String) -> String:
	return "%d %s" % [n, one if n == 1 else many]


## What he's doing, in plain words, and the colour of the dot beside it.
func _doing(c: Dictionary) -> Dictionary:
	var task := String(c["task"])
	var b := Game.biz_by_id(int(c["target"]))
	match task:
		"follow":
			return {"text": "With you", "color": Art.GOLD}
		"guard":
			return {"text": "Guarding %s" % b.get("name", "the club") if int(b.get("hq_of", -1)) != me() else "Guarding the club", "color": Art.GREEN_INK}
		"collect":
			return {"text": "Collecting in %s" % b.get("district", "the city"), "color": Art.GREEN_INK}
		"booze":
			return {"text": "Booze run: %d crates a month" % int(c.get("booze", 20)), "color": Art.GREEN_INK}
		"idle":
			return {"text": "At the club", "color": Color("8a7d66")}
		"take":
			return {"text": "Going to take %s" % b.get("name", "a shop"), "color": Art.OXBLOOD}
	if task.begins_with("city:"):
		return {"text": "Running %s for you" % Syndicate.city_def(task.substr(5)).get("name", "a city"), "color": Art.GREEN_INK}
	return {"text": task.capitalize(), "color": Color("8a7d66")}


func _crew_card(c: Dictionary, cw: float) -> Dictionary:
	var id := int(c["id"])
	var fid := me()
	var tr: Dictionary = Rackets.TRAITS.get(String(c.get("trait", "")), {})
	var st := _doing(c)
	return _b(182.0, func(ci: Control, r: Rect2) -> void:
		var x := r.position.x
		var y := r.position.y
		Art.photo(ci, Rect2(x, y + 8, 104, 104), "crew", int(c.get("look", id)), Art.fam_color(fid))
		var tx := x + 124.0
		var tw := r.size.x - 124.0
		# name and rank
		var rank := String(c["rank"]).to_upper()
		var rw := Art.text_w(rank, "fell_sc", 17)
		var name := Art.fit(String(c["name"]), "serif", 26, tw - rw - 14.0)
		Art.text(ci, Vector2(tx, y + 32), name, "serif", 26, Art.INK)
		Art.text(ci, Vector2(tx + Art.text_w(name, "serif", 26) + 12.0, y + 31), rank, "fell_sc", 17, Art.INK_SOFT)
		# what he's doing, and his wage
		var wage := "%s a month" % Art.money(int(c["wage"]))
		var ww := Art.text_w(wage, "cond", 18)
		Draw.circle(ci, Vector2(tx + 5, y + 53), 5.0, st["color"])
		Art.text(ci, Vector2(tx + 17, y + 59), Art.fit(String(st["text"]), "semi", 17, tw - ww - 36.0), "semi", 17, Art.INK)
		Art.text_r(ci, Vector2(r.end.x, y + 59), wage, "cond", 18, Art.INK_SOFT)
		_info("wage_%d" % id, Rect2(r.end.x - ww, y + 42, ww, 24), "His wage comes out of the Stash every month. Unpaid, he gets unhappy.")
		# his specialty, and how loyal he is
		if not tr.is_empty():
			Icons.draw(ci, String(tr["icon"]), Vector2(tx + 10, y + 79), 20.0, Art.OXBLOOD, Art.PAPER)
			Art.text(ci, Vector2(tx + 27, y + 86), String(tr["name"]), "cond", 20, Art.OXBLOOD)
		var lv := float(c["loyalty"])
		Art.text_r(ci, Vector2(r.end.x - 108, y + 86), "Loyalty", "fell_sc", 16, Art.INK_SOFT)
		Art.bar(ci, Rect2(r.end.x - 98, y + 76, 98, 11), lv / 100.0, Art.loyalty_color(lv))
		_info("loy_%d" % id, Rect2(r.end.x - 170, y + 68, 170, 24),
			"Loyalty %d. Pay him on time and he stays. Under 20 he may walk out; in prison, an unhappy man talks." % int(lv))
		if not tr.is_empty():
			Art.para(ci, Vector2(tx, y + 93), String(tr["does"]), "sans", 16, Art.INK_SOFT, tw, 19.0, 2)
		_orders(ci, c, Rect2(x, y + 136, r.size.x, 34))
		ci.draw_line(Vector2(x, r.end.y - 5), Vector2(r.end.x, r.end.y - 5), Color(Art.INK_SOFT, 0.22), 1.0))


func _orders(ci: Control, c: Dictionary, r: Rect2) -> void:
	var id := int(c["id"])
	var fid := me()
	var task := String(c["task"])
	var first := _first(String(c["name"]))
	var has_wh := not Game.nyc_warehouse(fid).is_empty()
	var earner := String(c.get("trait", "")) == "earner"
	var specs := [
		{"id": "o_%d_follow" % id, "text": "Follow me", "style": "active" if task == "follow" else "ink",
			"tip": "%s walks with you and fights at your side." % first,
			"cb": func() -> void: bk.ask("crew_task", [id, "follow", -1])},
		{"id": "o_%d_guard" % id, "text": "Guard a shop…", "style": "active" if task == "guard" else "ink",
			"tip": "%s stands outside one of your shops. Rivals think twice." % first,
			"cb": func() -> void: _pick_guard(c, r)},
		{"id": "o_%d_collect" % id, "text": "Collect…", "style": "active" if task == "collect" else "ink",
			"tip": ("%s picks up the envelopes in a district every month. He keeps nothing: he's an earner." % first) if earner else ("%s picks up the envelopes in a district every month, for a 10%% cut." % first),
			"cb": func() -> void: _pick_collect(c, r)},
		{"id": "o_%d_booze" % id, "text": "Booze run", "style": "active" if task == "booze" else "ink", "on": has_wh,
			"tip": ("%s trucks 20 crates a month from your warehouse on the quay to your speakeasies." % first) if has_wh else "First you need a warehouse on the West St. quay.",
			"cb": func() -> void: bk.ask("crew_task", [id, "booze", 20])},
		{"id": "o_%d_idle" % id, "text": "Back to the club", "style": "active" if task == "idle" else "ink",
			"tip": "%s goes back to the club and waits." % first,
			"cb": func() -> void: bk.ask("crew_task", [id, "idle", -1])},
	]
	_button_row(ci, r, specs, 17)


func _pick_guard(c: Dictionary, near: Rect2) -> void:
	var id := int(c["id"])
	var fid := me()
	var items: Array = []
	for b in _my_shops(true):
		var bid := int(b["id"])
		var club := int(b.get("hq_of", -1)) == fid
		items.append({"text": "Your club" if club else String(b["name"]), "sub": "%s · %s" % [b["address"], b["district"]],
			"icon": String(b["kind"]), "color": Art.ink_of(fid),
			"cb": func() -> void: bk.ask("crew_task", [id, "guard", bid])})
	bk.pick("Guard which shop?", "%s stands outside it and keeps rivals away." % _first(String(c["name"])), items, near)


func _pick_collect(c: Dictionary, near: Rect2) -> void:
	var id := int(c["id"])
	var fid := me()
	var by := {}
	for b in Game.shops_of(fid):
		if int(b["owned_by"]) == fid:
			continue
		var d := String(b["district"])
		if not by.has(d):
			by[d] = {"first": int(b["id"]), "n": 0, "pay": 0}
		by[d]["n"] = int(by[d]["n"]) + 1
		by[d]["pay"] = int(by[d]["pay"]) + int(float(b["rate"]) * Game.econ)
	var items: Array = []
	var ds := by.keys()
	ds.sort()
	for d in ds:
		var e: Dictionary = by[d]
		var target := int(e["first"])
		items.append({"text": String(d), "sub": "%s pay you there · %s a month" % [_count(int(e["n"]), "shop", "shops"), Art.money(int(e["pay"]))],
			"icon": "envelope", "color": Art.ink_of(fid),
			"cb": func() -> void: bk.ask("crew_task", [id, "collect", target])})
	bk.pick("Collect where?", "Every month %s picks up the envelopes there." % _first(String(c["name"])), items, near)


## A man in prison, a rat, or a capo out of town: a smaller entry.
func _small_card(c: Dictionary, cw: float) -> Dictionary:
	var id := int(c["id"])
	var fid := me()
	var state := String(c["state"])
	var tr: Dictionary = Rackets.TRAITS.get(String(c.get("trait", "")), {})
	return _b(100.0, func(ci: Control, r: Rect2) -> void:
		var x := r.position.x
		var y := r.position.y
		Art.photo(ci, Rect2(x, y + 10, 76, 76), "crew", int(c.get("look", id)), Art.fam_color(fid), {}, "", state != "away")
		var tx := x + 96.0
		var tw := r.size.x - 96.0
		var name := Art.fit(String(c["name"]), "serif", 22, tw - 140.0)
		Art.text(ci, Vector2(tx, y + 32), name, "serif", 22, Art.INK)
		Art.text(ci, Vector2(tx + Art.text_w(name, "serif", 22) + 10.0, y + 31), String(c["rank"]).to_upper(), "fell_sc", 16, Art.INK_SOFT)
		var line := ""
		var col := Art.INK
		match state:
			"jailed":
				line = "In prison until %s" % Game.date_text(int(c["jail_until"]))
				col = Art.OXBLOOD
			"rat":
				line = "He's talking to the District Attorney. See Heat."
				col = Art.OXBLOOD
			_:
				line = String(_doing(c)["text"])
		Art.text(ci, Vector2(tx, y + 58), Art.fit(line, "semi", 17, tw), "semi", 17, col)
		if not tr.is_empty():
			Icons.draw(ci, String(tr["icon"]), Vector2(tx + 9, y + 76), 17.0, Art.INK_SOFT, Art.PAPER)
			Art.text(ci, Vector2(tx + 24, y + 82), String(tr["name"]), "cond", 17, Art.INK_SOFT)
		var lv := float(c["loyalty"])
		Art.text_r(ci, Vector2(r.end.x - 108, y + 82), "Loyalty", "fell_sc", 16, Art.INK_SOFT)
		Art.bar(ci, Rect2(r.end.x - 98, y + 72, 98, 11), lv / 100.0, Art.loyalty_color(lv))
		ci.draw_line(Vector2(x, r.end.y - 4), Vector2(r.end.x, r.end.y - 4), Color(Art.INK_SOFT, 0.18), 1.0))


func _support(f: Dictionary, inside: int, cw: float) -> Dictionary:
	var on := bool(f.get("support_jailed", true))
	return _b(96.0, func(ci: Control, r: Rect2) -> void:
		var hr := Rect2(r.position + Vector2(0, 14), Vector2(r.size.x, 62))
		var id := "support"
		bk.hits.add(L, id, hr, func() -> void: bk.ask("toggle", ["support_jailed"]), true,
			"Click to switch it %s." % ("off" if on else "on"))
		var hot: bool = bk.hits.hot(id)
		if hot:
			Art.box(ci, hr.grow(4.0), Color(Art.OXBLOOD, 0.06), Color(Art.OXBLOOD, 0.4), 1, 4)
		Art.switch(ci, Rect2(hr.position + Vector2(0, 8), Vector2(60, 28)), on, hot)
		Art.text(ci, hr.position + Vector2(78, 24), "Look after their families", "semi", 19, Art.INK)
		var s := "%s a month for each man inside%s. Looked after, they stay loyal. The others may talk." % [Art.money(Game.JAIL_SUPPORT),
			(" (%s now)" % Art.money(Game.JAIL_SUPPORT * inside)) if inside > 0 else ""]
		Art.para(ci, hr.position + Vector2(78, 32), s, "sans", 16, Art.INK_SOFT, r.size.x - 78.0, 20.0, 2)
		if bk.hits.keys and bk.hits.focus == id:
			ci.draw_rect(hr.grow(5.0), Color(Art.GOLD, 0.9), false, 2.0))


# ------------------------------------------------------------------ Rackets

func _rackets(cw: float) -> Dictionary:
	var fid := me()
	var shops := _my_shops(true)
	var paying := 0
	var monthly := 0
	var fronts := 0
	var waiting := 0
	for b in shops:
		if int(b["owned_by"]) == fid:
			if String(b["kind"]) != "club":
				fronts += 1
		else:
			paying += 1
			monthly += int(float(b["rate"]) * Game.econ)
			waiting += int(b["envelope"])
	var sub := "%s pay you %s a month." % [_count(paying, "shop", "shops"), Art.money(monthly)]
	if fronts > 0:
		sub += " You own %s." % _count(fronts, "front", "fronts")
	if waiting > 0:
		sub += " %s waits in envelopes." % Art.money(waiting)
	var left: Array = [_header("Your Rackets", sub, cw)]
	if paying + fronts == 0:
		left.append(_note("No shop pays you yet. Walk into a shop and talk to the owner: offer him protection.", cw, "shop"))
	left.append(_columns())
	var district := ""
	for b in shops:
		if int(b.get("hq_of", -1)) != fid and String(b["district"]) != district:
			district = String(b["district"])
			left.append(_district(district))
		left.append(_shop_row(b, cw))
	if shops.size() < 9:
		left.append(_gap(8.0))
		left.append(_note("Want more? Walk into a shop and offer the owner protection. A shop with a \"!\" needs a favor: do it, and he pays you.", cw, "bang"))
	var pay_cops := Game.cops.filter(func(c: Dictionary) -> bool: return int(c["payroll"]) == fid).size()
	var caps: Array = Game.captains.keys().filter(func(d: Variant) -> bool: return int(Game.captains[d]) == fid)
	if pay_cops > 0 or not caps.is_empty():
		var s := "On your payroll: %s" % _count(pay_cops, "patrolman", "patrolmen")
		if not caps.is_empty():
			s += ", and the police captain in %s" % ", ".join(caps)
		left.append(_note(s + ".", cw, "precinct"))
	var right: Array = [_header("Crime Rings", "Get every shop of a trade in the city to pay you. A whole ring gives you a perk.", cw)]
	for rg in Rackets.ring_progress(fid):
		right.append(_ring_row(rg, cw))
	return {"mode": "split", "left": left, "right": right}


func _columns() -> Dictionary:
	return _b(30.0, func(ci: Control, r: Rect2) -> void:
		Art.text(ci, r.position + Vector2(44, 20), "SHOP", "fell_sc", 15, Art.INK_SOFT)
		Art.text_r(ci, Vector2(r.end.x - 112, r.position.y + 20), "EACH MONTH", "fell_sc", 15, Art.INK_SOFT)
		Art.text_r(ci, Vector2(r.end.x, r.position.y + 20), "ENVELOPE", "fell_sc", 15, Art.INK_SOFT)
		_info("col_env", Rect2(r.end.x - 90, r.position.y, 90, 28), "What a shop owes you since the last pickup. Collect it at the shop, or send a man to collect."), true)


func _district(d: String) -> Dictionary:
	return _b(36.0, func(ci: Control, r: Rect2) -> void:
		Art.text(ci, r.position + Vector2(0, 26), d.to_upper(), "fell_sc", 17, Art.OXBLOOD)
		ci.draw_line(Vector2(r.position.x + Art.text_w(d.to_upper(), "fell_sc", 17) + 10, r.position.y + 21), Vector2(r.end.x, r.position.y + 21), Color(Art.OXBLOOD, 0.25), 1.0), true)


func _shop_row(b: Dictionary, cw: float) -> Dictionary:
	var fid := me()
	var owned := int(b["owned_by"]) == fid
	var club := int(b.get("hq_of", -1)) == fid
	var tags: Array = [String(b["address"])]
	var red: Array = []
	if club:
		tags = ["%s · %s" % [b["address"], b["district"]], "Your headquarters"]
	elif owned:
		tags.append("Front: washes %s" % Art.money(int(b["launder"])))
	if bool(b["speak"]):
		tags.append("Speakeasy: %s" % _count(int(b["stock"]), "crate", "crates"))
	if int(b["unpaid"]) > 0 and not owned:
		red.append("Didn't pay")
	if int(b["closed_until"]) >= Game.month:
		red.append("Padlocked")
	return _b(54.0, func(ci: Control, r: Rect2) -> void:
		var x := r.position.x
		var y := r.position.y
		var col := Art.ink_of(fid)
		if club:
			Art.crest(ci, Vector2(x + 16, y + 26), 32.0, Art.fam_color(fid), Art.initial(fid), false)
		else:
			Icons.badge(ci, String(b["kind"]), Vector2(x + 16, y + 26), 15.0, col, col.darkened(0.35), Color("f4ecd6"), false)
		var nx := x + 44.0
		var name := "%s Social Club" % Game.fam(fid).get("name", "") if club else String(b["name"])
		var room := r.size.x - 44.0 - 222.0
		Art.text(ci, Vector2(nx, y + 22), Art.fit(name, "semi", 18, room), "semi", 18, Art.INK)
		var line := "  ·  ".join(tags)
		var rw := 0.0
		for t in red:
			rw += Art.text_w(String(t), "cond", 15) + 18.0
		var lw := minf(Art.text_w(line, "fell", 16), room - rw)
		Art.text(ci, Vector2(nx, y + 43), Art.fit(line, "fell", 16, room - rw), "fell", 16, Art.INK_SOFT)
		var tx := nx + lw + 10.0
		for t in red:
			var tw := Art.text_w(String(t), "cond", 15) + 12.0
			Art.box(ci, Rect2(tx, y + 29, tw, 19), Color(Art.OXBLOOD, 0.12), Art.OXBLOOD, 1, 3)
			Art.text(ci, Vector2(tx + 6, y + 44), String(t), "cond", 15, Art.OXBLOOD)
			tx += tw + 6.0
		# what it brings
		var amt := ""
		var sub := ""
		if owned:
			amt = "+%s" % Art.money(int(float(b["legit"]) * Game.econ))
			sub = "clean"
		else:
			amt = Art.money(int(float(b["rate"]) * Game.econ))
			sub = "protection"
		Art.text_r(ci, Vector2(r.end.x - 112, y + 23), amt, "cond", 20, Art.GREEN_INK if owned else Art.INK)
		Art.text_r(ci, Vector2(r.end.x - 112, y + 42), sub, "fell", 15, Art.INK_SOFT)
		var env := int(b["envelope"])
		if env > 0 and not owned:
			var es := Art.money(env)
			var ew := Art.text_w(es, "cond", 20)
			Icons.draw(ci, "envelope", Vector2(r.end.x - ew - 16, y + 17), 18.0, Art.GOLD, Art.PAPER)
			Art.text_r(ci, Vector2(r.end.x, y + 23), es, "cond", 20, Color("8a6414"))
			Art.text_r(ci, Vector2(r.end.x, y + 42), "waiting", "fell", 15, Art.INK_SOFT)
		else:
			Art.text_r(ci, Vector2(r.end.x, y + 23), "—", "cond", 20, Color(Art.INK_SOFT, 0.4))
		ci.draw_line(Vector2(x, r.end.y - 2), Vector2(r.end.x, r.end.y - 2), Art.RULE, 1.0))


func _ring_row(rg: Dictionary, cw: float) -> Dictionary:
	var fid := me()
	var done := bool(rg["done"])
	var have := int(rg["have"])
	var total := int(rg["total"])
	var kinds: Array = rg["kinds"]
	return _b(60.0, func(ci: Control, r: Rect2) -> void:
		var x := r.position.x
		var y := r.position.y
		if done:
			Art.box(ci, Rect2(x - 8, y + 1, r.size.x + 16, r.size.y - 4), Color(Art.GOLD, 0.15), Color(Art.GOLD, 0.65), 1, 4)
		var col := Art.ink_of(fid) if done else Color("9a8c72")
		var n := kinds.size()
		var x0 := x + 36.0 - (n - 1) * 11.5
		for k in n:
			Icons.badge(ci, String(kinds[k]), Vector2(x0 + k * 23.0, y + 27), 11.5, col, col.darkened(0.3), Color("f7f0dc"), false)
		var tx := x + 80.0
		Art.text(ci, Vector2(tx, y + 21), String(rg["name"]), "serif", 19, Art.INK)
		var cnt := ("All %d: yours" % total) if done else ("%d of %d shops" % [have, total])
		if total == 0:
			cnt = "None in the city"
		var cc := Art.GREEN_INK if done else Art.INK_SOFT
		Art.text_r(ci, Vector2(r.end.x, y + 21), cnt, "cond", 18, cc)
		if done:
			Icons.draw(ci, "check", Vector2(r.end.x - Art.text_w(cnt, "cond", 18) - 14, y + 15), 14.0, Art.GREEN_INK)
		Art.bar(ci, Rect2(tx, y + 28, r.size.x - 80.0, 8), float(have) / maxf(1.0, float(total)), Art.GOLD if done else Art.GREEN_INK)
		Art.text(ci, Vector2(tx, y + 52), Art.fit(String(rg["perk"]), "sans", 16, r.size.x - 80.0), "sans", 16, Art.INK if done else Art.INK_SOFT)
		_info("ring_%s" % rg["id"], Rect2(x, y, r.size.x, r.size.y - 4),
			"%s: %s" % [", ".join(kinds.map(func(k: Variant) -> String: return Icons.trade_name(String(k)))), "every one pays you. The perk is yours." if done else "%d more to go." % (total - have)]))


# ------------------------------------------------------------------ Heat

func _heat(cw: float) -> Dictionary:
	var fid := me()
	var f := Game.fam(fid)
	var heat := float(f["heat"])
	var left: Array = [_header("The Heat", "How much the law has on you, and how to cool it down.", cw)]
	left.append(_gauge(heat, cw))
	left.append(_raid_line(cw))
	var pay_cops := Game.cops.filter(func(c: Dictionary) -> bool: return int(c["payroll"]) == fid).size()
	var captain: bool = Game.captains.values().has(fid)
	left.append(_section("What cools it down"))
	var lines := ["Every month, old evidence fades by itself.",
		"Cops on your payroll look the other way. You pay %s." % _count(pay_cops, "patrolman", "patrolmen") if pay_cops > 0 else "Put cops on your payroll: they look the other way.",
		"A police captain on your payroll makes street talk fade faster." if not captain else "Your police captain makes street talk fade faster.",
		"Or make the evidence go away: the file says how."]
	left.append(_bullets(lines, cw))
	var ev: Array = (f["evidence"] as Array).duplicate()
	ev.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["w"]) > float(b["w"]))
	var right: Array = [_file_head(f, cw - 40.0)]
	if ev.is_empty():
		right.append(_ev_empty(cw))
	for e in ev:
		right.append(_ev_card(e, cw))
	return {"mode": "split", "left": left, "right": right, "bg_r": func(ci: Control, r: Rect2) -> void: _folder(ci, r, fid)}


func _gauge(heat: float, cw: float) -> Dictionary:
	return _b(262.0, func(ci: Control, r: Rect2) -> void:
		var c := Vector2(r.get_center().x, r.position.y + 196)
		var R := minf(172.0, cw * 0.36)
		# the brass bezel and the face
		var face := PackedVector2Array()
		var rim := PackedVector2Array()
		for k in 41:
			var a := PI + PI * k / 40.0
			face.append(c + Vector2(cos(a), sin(a)) * R)
			rim.append(c + Vector2(cos(a), sin(a)) * (R + 14))
		rim.append(c + Vector2(R + 14, 18))
		rim.append(c + Vector2(-R - 14, 18))
		Draw.shadow(ci, rim, Vector2(4, 6), Color(0, 0, 0, 0.2))
		Draw.poly(ci, rim, Art.BRASS.darkened(0.1))
		ci.draw_polyline(Draw.ellipse_points(c, Vector2(R + 11, R + 11), 0.0, 60).slice(30, 60), Color(1, 1, 1, 0.3), 1.5, true)
		face.append(c + Vector2(R, 12))
		face.append(c + Vector2(-R, 12))
		Draw.poly(ci, face, Color("f6f0de"))
		# the danger band from 70 to 100
		ci.draw_arc(c, R - 16, PI + PI * 0.7, TAU, 24, Color(Art.OXBLOOD, 0.85), 16.0, true)
		ci.draw_arc(c, R - 16, PI + PI * 0.4, PI + PI * 0.7, 18, Color("c9a54a", 0.55), 16.0, true)
		for k in 21:
			var a := PI + PI * k / 20.0
			var d := Vector2(cos(a), sin(a))
			var long := k % 2 == 0
			ci.draw_line(c + d * (R - (30.0 if long else 26.0)), c + d * (R - 4.0), Art.INK, 2.0 if long else 1.0, true)
			if k % 4 == 0:
				var s := str(k * 5)
				Art.text_c(ci, c + d * (R - 50.0) + Vector2(0, 7), s, "cond", 18, Art.INK)
		Art.text_c(ci, c + Vector2(0, -R * 0.42), "HEAT", "fell_sc", 20, Art.INK_SOFT)
		# the needle
		var v := clampf(heat / 100.0, 0.0, 1.04)
		var an := PI + PI * v
		var nd := Vector2(cos(an), sin(an))
		var tip := c + nd * (R - 12.0)
		Draw.poly(ci, PackedVector2Array([c + nd.orthogonal() * 6.0 + Vector2(3, 4), tip + Vector2(3, 4), c - nd.orthogonal() * 6.0 + Vector2(3, 4)]), Color(0, 0, 0, 0.2))
		Draw.poly(ci, PackedVector2Array([c + nd.orthogonal() * 6.0, tip, c - nd.orthogonal() * 6.0, c - nd * 22.0]), Art.OXBLOOD.darkened(0.2))
		Draw.circle(ci, c, 13.0, Art.BRASS)
		Draw.circle(ci, c - Vector2(3, 3), 5.0, Color(1, 1, 1, 0.35))
		# the number
		var big := str(int(round(heat)))
		Art.text_c(ci, c + Vector2(0, 58), big, "serif", 44, Art.OXBLOOD if heat >= 70.0 else Art.INK)
		_info("gauge", Rect2(c - Vector2(R, R), Vector2(R * 2.0, R + 60.0)), "Heat %d of 100. Every crime people see adds to it." % int(round(heat))))


func _raid_line(cw: float) -> Dictionary:
	var s := "They take half your Stash, seize your booze and shut your speakeasies."
	var h := 40.0 + Art.para_h(s, "fell", 18, cw, 23.0) + 10.0
	return _b(h, func(ci: Control, r: Rect2) -> void:
		Art.text_c(ci, Vector2(r.get_center().x, r.position.y + 26), "At 100 the feds raid you.", "semi", 22, Art.OXBLOOD)
		var lines := Art.lines_of(s, "fell", 18, cw)
		for k in lines.size():
			Art.text_c(ci, Vector2(r.get_center().x, r.position.y + 54 + k * 23), lines[k], "fell", 18, Art.INK_SOFT))


func _bullets(lines: Array, cw: float) -> Dictionary:
	var h := 8.0
	for l in lines:
		h += Art.para_h(String(l), "sans", 17, cw - 22.0, 22.0) + 6.0
	return _b(h, func(ci: Control, r: Rect2) -> void:
		var y := r.position.y + 6.0
		for l in lines:
			Draw.circle(ci, Vector2(r.position.x + 5, y + 13), 3.0, Art.OXBLOOD)
			y += Art.para(ci, Vector2(r.position.x + 20, y), String(l), "sans", 17, Art.INK, cw - 22.0, 22.0) + 6.0)


## The manila folder the file lives in, laid over the right page.
func _folder(ci: Control, r: Rect2, fid: int) -> void:
	var fr := Rect2(r.position + Vector2(-18, 22), r.size + Vector2(36, -10))
	# the back cover, a little askew
	ci.draw_set_transform(fr.get_center(), 0.012, Vector2.ONE)
	var back := Rect2(-fr.size * 0.5 + Vector2(6, 4), fr.size)
	Art.box(ci, Rect2(back.position + Vector2(4, 6), back.size), Color(0, 0, 0, 0.18), Color(0, 0, 0, 0), 0, 4)
	Art.box(ci, back, Art.MANILA_DARK, Art.MANILA_DARK.darkened(0.2), 1, 4)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# the tab on top
	var tabr := Rect2(fr.position + Vector2(24, -26), Vector2(300, 32))
	Art.box(ci, tabr, Art.MANILA, Art.MANILA_DARK, 1, 6)
	Art.typed(ci, tabr.position + Vector2(16, 22), "BUREAU OF INVESTIGATION", 17, Color("2a1c10"), 3)
	Art.box(ci, Rect2(fr.position + Vector2(3, 5), fr.size), Color(0, 0, 0, 0.2), Color(0, 0, 0, 0), 0, 4)
	Art.box(ci, fr, Art.MANILA, Art.MANILA_DARK, 1, 4)
	var rng := W.rng(fid * 13 + 5)
	for k in 160:
		var p := fr.position + Vector2(rng.randf() * fr.size.x, rng.randf() * fr.size.y)
		ci.draw_rect(Rect2(p, Vector2(rng.randf_range(1, 3), 1)), Color(0.4, 0.28, 0.1, 0.1))
	ci.draw_rect(Rect2(fr.position + Vector2(0, 0), Vector2(fr.size.x, 3)), Color(1, 1, 1, 0.18))


func _file_head(f: Dictionary, w: float) -> Dictionary:
	var fid := int(f["id"])
	var bosses: Array = []
	for k in Game.players:
		if int(Game.players[k]["family"]) == fid:
			bosses.append(String(Game.players[k]["name"]).to_upper())
	return _b(132.0, func(ci: Control, r: Rect2) -> void:
		var x := r.position.x
		var y := r.position.y + 30.0
		Art.typed(ci, Vector2(x, y + 22), "SUBJECT:  THE %s FAMILY" % String(f["name"]).to_upper(), 20, Color("2a1c10"), 11)
		Art.typed(ci, Vector2(x, y + 48), "BOSS:  %s" % (", ".join(bosses) if not bosses.is_empty() else "UNKNOWN"), 18, Color("3a2a18"), 12)
		Art.typed(ci, Vector2(x, y + 72), "FILE No. %d-%04d" % [Game.year() % 100, 1100 + fid * 317], 18, Color("3a2a18"), 13)
		Art.stamp(ci, Vector2(r.end.x - 110, y + 44), "CONFIDENTIAL", Color(0.66, 0.1, 0.08, 0.78), 22, -0.16, fid)
		ci.draw_line(Vector2(x, r.end.y - 12), Vector2(r.end.x, r.end.y - 12), Color(0.3, 0.2, 0.08, 0.35), 1.0))


func _ev_empty(cw: float) -> Dictionary:
	return _b(120.0, func(ci: Control, r: Rect2) -> void:
		var cr := Rect2(r.position + Vector2(0, 8), Vector2(r.size.x, 96))
		_index_card(ci, cr)
		Art.typed(ci, cr.position + Vector2(18, 36), "NOTHING ON FILE.", 20, Color("2a1c10"), 21)
		Art.para(ci, cr.position + Vector2(18, 48), "As far as the Bureau knows, you sell bread.", "fell", 19, Art.INK_SOFT, cr.size.x - 36.0, 24.0))


func _index_card(ci: CanvasItem, r: Rect2) -> void:
	Art.box(ci, Rect2(r.position + Vector2(2, 3), r.size), Color(0, 0, 0, 0.2), Color(0, 0, 0, 0), 0, 2)
	Art.box(ci, r, Art.INDEX_CARD, Color("cfc5ae"), 1, 2)
	ci.draw_line(Vector2(r.position.x + 1, r.position.y + 34), Vector2(r.end.x - 1, r.position.y + 34), Color(0.7, 0.2, 0.2, 0.45), 1.0)
	var y := r.position.y + 56.0
	while y < r.end.y - 4.0:
		ci.draw_line(Vector2(r.position.x + 1, y), Vector2(r.end.x - 1, y), Color(0.35, 0.5, 0.7, 0.16), 1.0)
		y += 22.0


func _ev_card(e: Dictionary, cw: float) -> Dictionary:
	var fid := me()
	var f := Game.fam(fid)
	var kind := String(e["kind"])
	var eid := int(e["id"])
	var w := cw - 36.0
	var txt := String(e["text"])
	var lines := Art.lines_of(txt, "fell", 18, w)
	var how := String(EV_HOW.get(kind, "It fades with time."))
	var button := ""
	var on := true
	var tip := ""
	var cb := Callable()
	if kind == "body":
		var cost := 200 if Rackets.has_ring(fid, "meat") else 400
		var late := Game.month - int(e["month"]) > 2
		button = "Cleanup crew · %s" % Art.money(cost)
		on = not late and int(f["dirty"]) >= cost
		tip = "Too late: the police already have the body. It fades slowly." if late else ("Paid from the Stash." if on else "The cleanup crew wants %s from the Stash." % Art.money(cost))
		if late:
			how = "Too late for the cleanup crew: the police have the body. It fades very slowly."
		cb = func() -> void: bk.ask("cleanup", [eid])
	elif kind == "informant":
		button = "Reach him · $2,000"
		on = int(f["dirty"]) >= 2000
		tip = "Paid from the Stash. It works six times in ten. If it fails, the DA knows you tried." if on else "It costs $2,000 from the Stash."
		cb = func() -> void: bk.ask("reach", [eid])
	var h := 14.0 + 30.0 + lines.size() * 22.0 + 10.0 + Art.para_h(how, "sans", 16, w, 20.0) + (46.0 if button != "" else 6.0) + 12.0
	return _b(h + 12.0, func(ci: Control, r: Rect2) -> void:
		var cr := Rect2(r.position, Vector2(r.size.x, h))
		_index_card(ci, cr)
		var x := cr.position.x + 18.0
		var y := cr.position.y
		Icons.draw(ci, String(Icons.EVIDENCE.get(kind, "bang")), Vector2(x + 9, y + 18), 18.0, Color("3a2a18"), Art.INDEX_CARD)
		Art.typed(ci, Vector2(x + 26, y + 25), String(EV_NAME.get(kind, kind.to_upper())), 19, Color("2a1c10"), eid)
		var wv := int(round(float(e["w"])))
		var ws := "adds %d heat" % wv
		Art.text_r(ci, Vector2(cr.end.x - 16, y + 24), ws, "cond", 17, Art.OXBLOOD if wv >= 15 else Art.INK_SOFT)
		var ty := y + 34.0 + 20.0
		for k in lines.size():
			Art.typed(ci, Vector2(x, ty + k * 22.0), lines[k], 18, Color("2a1c10"), eid * 7 + k)
		var hy := ty + lines.size() * 22.0 - 6.0
		Art.para(ci, Vector2(x, hy), how, "sans", 16, Art.GREEN_INK.darkened(0.1), w, 20.0)
		if button != "":
			var bw := Art.button_w(button, 17) + 10.0
			bk.btn(ci, L, "ev_%d" % eid, Rect2(cr.end.x - bw - 16, cr.end.y - 44, bw, 32), button, cb, "go" if on else "ink", on, tip))


# ------------------------------------------------------------------ Rivals

func _rivals(cw: float) -> Dictionary:
	var fid := me()
	var others := Game.families.filter(func(o: Dictionary) -> bool: return int(o["id"]) != fid)
	others.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if bool(a["alive"]) != bool(b["alive"]):
			return bool(a["alive"])
		return int(a["id"]) < int(b["id"]))
	var left: Array = [_header("The Other Families", "Who they are, and where you stand with them.", cw)]
	if others.is_empty():
		left.append(_note("Nobody else in town. The city is yours.", cw))
	for o in others:
		left.append(_family_card(o, cw))
	var offers := Game.deals.filter(func(d: Dictionary) -> bool: return int(d["to"]) == fid)
	var right: Array = [_header("Sit-downs", "Offers waiting for your answer. They go cold after a month.", cw)]
	if offers.is_empty():
		right.append(_note("No offers on the table. Make one to a family on the left, or talk to a don in person.", cw, "deal"))
	for d in offers:
		right.append(_offer(d, cw))
	right.append(_section("How deals work"))
	right.append(_bullets(["A truce: months of peace. Break it and every family hears about it.",
		"Money talks: pay for peace, or demand a tribute from the weak.",
		"An alliance: the two of you go to war with a third family.",
		"A family that keeps its word gets better deals."], cw))
	return {"mode": "split", "left": left, "right": right}


func _player_of(family: int) -> String:
	for k in Game.players:
		if int(Game.players[k]["family"]) == family:
			return String(Game.players[k]["name"])
	return ""


func _word(o: Dictionary) -> String:
	var kept := int(o["kept"])
	var broke := int(o["broken"])
	if kept == 0 and broke == 0:
		return "No deals with anyone yet"
	var t := "Kept its word %s" % _times(kept)
	if broke > 0:
		t += ", broke it %s" % _times(broke)
	else:
		t += ", never broke it"
	return t


func _times(n: int) -> String:
	match n:
		0: return "never"
		1: return "once"
		2: return "twice"
	return "%d times" % n


func _family_card(o: Dictionary, cw: float) -> Dictionary:
	var fid := me()
	var oid := int(o["id"])
	var alive := bool(o["alive"])
	var rl := Game.rel(fid, oid)
	var truce := Game.has_truce(fid, oid)
	var status := "At war" if bool(rl["war"]) else ("Truce until %s" % Game.date_text(int(rl["truce_until"])) if truce else "No deal")
	var scol := Art.OXBLOOD if bool(rl["war"]) else (Art.GREEN_INK if truce else Color("8a7d66"))
	var who := "Run by the computer" if bool(o["ai"]) else "Played by %s" % _player_of(oid)
	var men := Game.crew_of(oid).size()
	var shops := Game.shops_of(oid).size()
	var name := String(o["name"])
	var h := 170.0 if alive else 120.0
	return _b(h, func(ci: Control, r: Rect2) -> void:
		var x := r.position.x
		var y := r.position.y
		Art.photo(ci, Rect2(x, y + 10, 96, 96), "aiboss" if bool(o["ai"]) else "boss", absi(hash(name)) % 100000, Art.fam_color(oid), {}, "smug" if bool(rl["war"]) else "")
		Art.crest(ci, Vector2(x + 90, y + 98), 34.0, Art.fam_color(oid), name.substr(0, 1))
		var tx := x + 118.0
		var tw := r.size.x - 118.0
		var cw2 := Art.text_w(status, "cond", 16) + 20.0
		Art.text(ci, Vector2(tx, y + 34), Art.fit("The %s Family" % name, "serif", 25, tw - cw2 - 10.0), "serif", 25, Art.INK)
		if alive:
			var chip := Rect2(r.end.x - cw2, y + 14, cw2, 26)
			if status == "No deal":
				Art.box(ci, chip, Color(0, 0, 0, 0), scol, 1, 13)
				Art.text(ci, chip.position + Vector2(10, 19), status, "cond", 16, scol)
			else:
				Art.box(ci, chip, scol, scol.darkened(0.3), 1, 13)
				Art.text(ci, chip.position + Vector2(10, 19), status, "cond", 16, Art.PAPER_LIGHT)
		Art.text(ci, Vector2(tx, y + 60), Art.fit("%s  ·  %s" % [who, _word(o)], "fell", 17, tw), "fell", 17, Art.INK_SOFT)
		Icons.draw(ci, "men", Vector2(tx + 10, y + 80), 18.0, Art.INK, Art.PAPER)
		Art.text(ci, Vector2(tx + 26, y + 87), _count(men, "man", "men"), "cond", 19, Art.INK)
		var sx := tx + 40.0 + Art.text_w(_count(men, "man", "men"), "cond", 19)
		Icons.draw(ci, "shop", Vector2(sx + 10, y + 80), 18.0, Art.INK, Art.PAPER)
		Art.text(ci, Vector2(sx + 26, y + 87), "%s pay them" % _count(shops, "shop", "shops"), "cond", 19, Art.INK)
		if not alive:
			Art.stamp(ci, Vector2(r.get_center().x + 40, y + 62), "FINISHED", Color(0.6, 0.1, 0.08, 0.8), 30, -0.12, oid)
			ci.draw_line(Vector2(x, r.end.y - 6), Vector2(r.end.x, r.end.y - 6), Color(Art.INK_SOFT, 0.22), 1.0)
			return
		var third := Game.families.filter(func(t: Dictionary) -> bool: return bool(t["alive"]) and int(t["id"]) != fid and int(t["id"]) != oid)
		var dirty := int(Game.fam(fid)["dirty"])
		var specs := [
			{"id": "p_%d_truce" % oid, "text": "Offer a truce", "tip": "Six months of peace between you.",
				"cb": func() -> void: bk.ask("propose", [oid, {"kind": "truce", "months": 6, "amount": 0}])},
			{"id": "p_%d_pay" % oid, "text": "Pay $500 for peace", "on": dirty >= 500,
				"tip": "$500 from your Stash buys a year of peace." if dirty >= 500 else "You need $500 in the Stash.",
				"cb": func() -> void: bk.ask("propose", [oid, {"kind": "truce", "months": 12, "amount": 500}])},
			{"id": "p_%d_demand" % oid, "text": "Demand $500", "tip": "They pay you $500 and get six months of peace. Or they say no.",
				"cb": func() -> void: bk.ask("propose", [oid, {"kind": "tribute", "months": 6, "amount": -500}])},
			{"id": "p_%d_ally" % oid, "text": "Team up against…", "on": not third.is_empty(),
				"tip": "The two of you go to war with a third family." if not third.is_empty() else "There's no third family left.",
				"cb": func() -> void: _pick_enemy(oid, third, r)},
		]
		_button_row(ci, Rect2(tx, y + 110, tw, 34), specs, 17)
		ci.draw_line(Vector2(x, r.end.y - 8), Vector2(r.end.x, r.end.y - 8), Color(Art.INK_SOFT, 0.22), 1.0))


func _pick_enemy(oid: int, third: Array, near: Rect2) -> void:
	var items: Array = []
	for t in third:
		var tid := int(t["id"])
		items.append({"text": "The %s family" % t["name"], "sub": "%s · %s pay them" % [_count(Game.crew_of(tid).size(), "man", "men"), _count(Game.shops_of(tid).size(), "shop", "shops")],
			"icon": "crown", "color": Art.fam_color(tid),
			"cb": func() -> void: bk.ask("propose", [oid, {"kind": "alliance", "months": 12, "amount": 0, "against": tid}])})
	bk.pick("Team up against whom?", "You and the %s family go to war with them." % Game.fam(oid).get("name", ""), items, near)


func _offer_text(d: Dictionary) -> String:
	var t: Dictionary = d["terms"]
	var what := "a truce for %d months" % int(t.get("months", 6))
	if String(t.get("kind", "")) == "alliance":
		what = "an alliance against the %s family" % Game.fam(int(t.get("against", -1))).get("name", "?")
	var amt := int(t.get("amount", 0))
	if amt > 0:
		what += ", and they pay you %s" % Art.money(amt)
	elif amt < 0:
		what += ", if you pay them %s" % Art.money(-amt)
	return "The %s family offers %s." % [Game.fam(int(d["from"])).get("name", "?"), what]


func _offer(d: Dictionary, cw: float) -> Dictionary:
	var did := int(d["id"])
	var from := int(d["from"])
	var s := _offer_text(d)
	var th := Art.para_h(s, "serif", 20, cw - 70.0, 26.0)
	var h := 18.0 + th + 30.0 + 44.0 + 14.0
	var amt := int((d["terms"] as Dictionary).get("amount", 0))
	var afford := amt >= 0 or int(Game.fam(me())["dirty"]) >= -amt
	return _b(h, func(ci: Control, r: Rect2) -> void:
		var x := r.position.x
		var y := r.position.y
		Art.box(ci, Rect2(x - 8, y + 6, r.size.x + 16, r.size.y - 12), Color(Art.PAPER_LIGHT, 0.7), Art.CARD_EDGE, 1, 4)
		Art.crest(ci, Vector2(x + 24, y + 42), 44.0, Art.fam_color(from), Art.initial(from))
		Art.para(ci, Vector2(x + 62, y + 16), s, "serif", 20, Art.INK, cw - 70.0, 26.0)
		Art.text(ci, Vector2(x + 62, y + 18 + th + 18), "Answer by the end of %s." % Game.date_text(int(d["expires"])), "fell", 17, Art.INK_SOFT)
		var by := y + 18 + th + 34
		bk.btn(ci, L, "d_%d_yes" % did, Rect2(x + 62, by, 170, 34), "Shake hands", func() -> void: bk.ask("respond", [did, true]), "go", afford,
			"You shake on it." if afford else "You need %s in the Stash." % Art.money(-amt), "deal")
		bk.btn(ci, L, "d_%d_no" % did, Rect2(x + 244, by, 120, 34), "Refuse", func() -> void: bk.ask("respond", [did, false]), "danger", true,
			"They'll remember it."))


# ------------------------------------------------------------------ Money

func _money(cw: float) -> Dictionary:
	var fid := me()
	var f := Game.fam(fid)
	var inc: Dictionary = f.get("income", {})
	var last := Game.date_text(maxi(0, Game.month - 1))
	var left: Array = [_header("The Books", "Last month, %s: what came in and what went out." % last, cw)]
	left.append(_balances(f, cw))
	var ins := [["protection", "Protection money"], ["speakeasy", "Speakeasies"], ["wholesale", "Wholesale booze"], ["legit", "Clean profit from your fronts"]]
	var outs := [["wages", "Wages"], ["payroll", "Cops and captains"], ["support", "Families of men inside"], ["convoys", "Convoys"], ["supply", "The union, brewing, freight"]]
	var top := 1
	var total_in := 0
	var total_out := 0
	for k in ins:
		top = maxi(top, int(inc.get(k[0], 0)))
		if String(k[0]) != "legit":
			total_in += int(inc.get(k[0], 0))
	for k in outs:
		top = maxi(top, int(inc.get(k[0], 0)))
		total_out += int(inc.get(k[0], 0))
	left.append(_section("Money in", Art.money(total_in + int(inc.get("legit", 0)))))
	for k in ins:
		left.append(_flow_row(String(k[1]), int(inc.get(k[0], 0)), top, Art.GREEN_INK, cw))
	left.append(_section("Money out", Art.money(total_out)))
	for k in outs:
		left.append(_flow_row(String(k[1]), int(inc.get(k[0], 0)), top, Art.OXBLOOD, cw))
	left.append(_net_line(total_in - total_out, int(inc.get("laundered", 0)), cw))
	var right: Array = [_header("Washing Money", "Your fronts turn dirty money from the Stash into clean money in the Bank.", cw)]
	right.append(_launder(f, cw))
	right.append(_section("Legacy", "your score"))
	right.append(_note("When Prohibition ends in December 1933, the family with the biggest legacy wins: clean money, what you own, who pays you, your name.", cw))
	var ranks := Game.families.duplicate()
	ranks.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return Game.legacy(int(a["id"])) > Game.legacy(int(b["id"])))
	var best := 1
	for o in ranks:
		best = maxi(best, Game.legacy(int(o["id"])))
	var n := 1
	for o in ranks:
		right.append(_legacy_row(n, o, best, cw))
		n += 1
	return {"mode": "split", "left": left, "right": right}


func _balances(f: Dictionary, cw: float) -> Dictionary:
	var p := Game.player(Net.my_id())
	var items := [["Wallet", int(p.get("wallet", 0)), "cash on you", "money"], ["Stash", int(f["dirty"]), "dirty, at the club", "lock"],
		["Bank", int(f["clean"]), "clean money", "book"]]
	return _b(98.0, func(ci: Control, r: Rect2) -> void:
		var gap := 12.0
		var w := (r.size.x - gap * 2.0) / 3.0
		for k in 3:
			var it: Array = items[k]
			var br := Rect2(r.position.x + k * (w + gap), r.position.y + 6, w, 82)
			Art.box(ci, br, Color(Art.PAPER_LIGHT, 0.8), Art.CARD_EDGE, 1, 4)
			Icons.draw(ci, String(it[3]), br.position + Vector2(22, 24), 20.0, Art.GOLD.darkened(0.2), Art.PAPER_LIGHT)
			Art.text(ci, br.position + Vector2(40, 31), String(it[0]).to_upper(), "fell_sc", 17, Art.INK_SOFT)
			Art.text(ci, br.position + Vector2(14, 60), Art.money(int(it[1])), "serif", 25, Art.INK)
			Art.text(ci, br.position + Vector2(14, 76), String(it[2]), "sans", 15, Art.INK_SOFT)
			_info("bal_%d" % k, br, ["Cash on you. You lose it if you get knocked down or arrested.",
				"The family's dirty money, in the safe at your club. Wages and bribes come out of it.",
				"Clean money. It buys businesses."][k]))


func _flow_row(label: String, v: int, top: int, col: Color, cw: float) -> Dictionary:
	return _b(30.0, func(ci: Control, r: Rect2) -> void:
		var lw := 250.0
		Art.text(ci, r.position + Vector2(0, 20), Art.fit(label, "fell", 18, lw - 10.0), "fell", 18, Art.INK if v > 0 else Art.INK_SOFT)
		var bw := r.size.x - lw - 90.0
		Art.bar(ci, Rect2(r.position.x + lw, r.position.y + 9, bw, 12), float(v) / float(maxi(1, top)), col, Color(0.35, 0.27, 0.16, 0.08))
		Art.text_r(ci, Vector2(r.end.x, r.position.y + 21), Art.money(v) if v > 0 else "—", "cond", 19, Art.INK if v > 0 else Color(Art.INK_SOFT, 0.5))
		ci.draw_line(Vector2(r.position.x, r.end.y - 1), Vector2(r.end.x, r.end.y - 1), Art.RULE, 1.0))


func _net_line(net: int, laundered: int, cw: float) -> Dictionary:
	return _b(92.0, func(ci: Control, r: Rect2) -> void:
		Art.rule(ci, Vector2(r.position.x, r.position.y + 12), Vector2(r.end.x, r.position.y + 12), Color(Art.INK_SOFT, 0.7), true)
		Art.text(ci, r.position + Vector2(0, 46), "The Stash, last month", "semi", 19, Art.INK)
		Art.text_r(ci, Vector2(r.end.x, r.position.y + 47), ("+" if net >= 0 else "") + Art.money(net), "serif", 26, Art.GREEN_INK if net >= 0 else Art.OXBLOOD)
		Art.text(ci, r.position + Vector2(0, 76), "Washed into the Bank: %s" % Art.money(laundered), "fell", 18, Art.INK_SOFT))


func _launder(f: Dictionary, cw: float) -> Dictionary:
	var fid := int(f["id"])
	var on := bool(f.get("launder_on", true))
	var cap := Game.laundering_capacity(fid)
	var fee := 5 if Rackets.has_ring(fid, "laundry") else int(Game.LAUNDER_FEE * 100.0)
	var s := "Your fronts can wash %s a month. The fee is %d%%. You always keep enough for next month's wages." % [Art.money(cap), fee] if cap > 0 \
		else "You own no fronts yet. Buy a shop with money from the Bank, and it starts washing."
	var h := 40.0 + Art.para_h(s, "sans", 16, cw - 78.0, 20.0) + 26.0
	return _b(h, func(ci: Control, r: Rect2) -> void:
		var hr := Rect2(r.position + Vector2(0, 6), Vector2(r.size.x, h - 18.0))
		var id := "launder"
		bk.hits.add(L, id, hr, func() -> void: bk.ask("toggle", ["launder_on"]), true, "Click to switch it %s." % ("off" if on else "on"))
		var hot: bool = bk.hits.hot(id)
		if hot:
			Art.box(ci, hr.grow(4.0), Color(Art.OXBLOOD, 0.06), Color(Art.OXBLOOD, 0.4), 1, 4)
		Art.switch(ci, Rect2(hr.position + Vector2(0, 8), Vector2(60, 28)), on, hot)
		Art.text(ci, hr.position + Vector2(78, 26), "Wash the Stash every month", "semi", 19, Art.INK)
		Art.para(ci, hr.position + Vector2(78, 34), s, "sans", 16, Art.INK_SOFT, r.size.x - 78.0, 20.0)
		if bk.hits.keys and bk.hits.focus == id:
			ci.draw_rect(hr.grow(5.0), Color(Art.GOLD, 0.9), false, 2.0))


func _legacy_row(n: int, o: Dictionary, best: int, cw: float) -> Dictionary:
	var fid := me()
	var oid := int(o["id"])
	var v := Game.legacy(oid)
	var mine := oid == fid
	return _b(46.0, func(ci: Control, r: Rect2) -> void:
		var x := r.position.x
		var y := r.position.y
		if mine:
			Art.box(ci, Rect2(x - 8, y + 2, r.size.x + 16, r.size.y - 4), Color(Art.GOLD, 0.14), Color(Art.GOLD, 0.55), 1, 4)
		Art.text_c(ci, Vector2(x + 14, y + 31), str(n), "serif", 22, Art.INK_SOFT)
		Art.crest(ci, Vector2(x + 50, y + 23), 30.0, Art.fam_color(oid), String(o["name"]).substr(0, 1), false)
		var name := "The %s family%s" % [o["name"], " (you)" if mine else ""]
		var nm := Art.fit(name, "semi", 18, 206.0)
		Art.text(ci, Vector2(x + 74, y + 29), nm, "semi", 18, Art.INK if bool(o["alive"]) else Art.INK_SOFT)
		if not bool(o["alive"]):
			ci.draw_line(Vector2(x + 72, y + 23), Vector2(x + 76 + Art.text_w(nm, "semi", 18), y + 23), Art.OXBLOOD, 1.5)
			_info("leg_%d" % oid, Rect2(x, y, 290, r.size.y), "The %s family is finished." % o["name"])
		var bx := x + 290.0
		var bw := r.size.x - 290.0 - 96.0
		Art.bar(ci, Rect2(bx, y + 17, bw, 12), float(maxi(0, v)) / float(maxi(1, best)), Art.ink_of(oid), Color(0.35, 0.27, 0.16, 0.1))
		Art.text_r(ci, Vector2(r.end.x, y + 30), Art.money(v), "cond", 19, Art.INK if bool(o["alive"]) else Art.INK_SOFT))
