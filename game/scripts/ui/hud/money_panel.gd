extends Control
## Top-left: who you are and what you have. The family crest, the family name, your Wallet (big),
## the Stash and the Bank, your men, guns and bullets, and the Heat as a five-step police badge meter
## that pulses when it rises. Numbers roll to their new value and a "+$500" floats up when they change.

const UI := preload("res://scripts/ui/hud/hud_ui.gd")
const W_PANEL := 430.0
const H_PANEL := 164.0

var _fam := {}
var _wallet := 0
var _stash := 0
var _bank := 0
var _shown := Vector3.ZERO      # rolling wallet, stash, bank
var _men := 0
var _guns := 0
var _ammo := 0
var _heat := 0.0
var _heat_shown := 0.0
var _pulse := 0.0
var _floaters: Array = []       # {text, color, t, slot}
var _ready_once := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(W_PANEL, H_PANEL)


func read_game() -> void:
	var p := Game.player(Net.my_id())
	var f := Game.fam(int(p.get("family", -1)))
	if f.is_empty():
		_fam = {}
		queue_redraw()
		return
	_fam = f
	var wallet := int(p.get("wallet", 0))
	var stash := int(f.get("dirty", 0))
	var bank := int(f.get("clean", 0))
	if _ready_once:
		_float_delta(wallet - _wallet, 0)
		_float_delta(stash - _stash, 1)
		_float_delta(bank - _bank, 2)
	else:
		_shown = Vector3(wallet, stash, bank)
	_wallet = wallet
	_stash = stash
	_bank = bank
	_men = Game.crew_of(int(f["id"])).size()
	var ars: Dictionary = f.get("arsenal", {})
	_guns = int(ars.get("pistol", 0)) + int(ars.get("tommy", 0))
	_ammo = int(ars.get("ammo", 0))
	var heat := float(f.get("heat", 0.0))
	if _ready_once and _segments(heat) > _segments(_heat):
		_pulse = 1.6
	elif _ready_once and heat > _heat + 1.5:
		_pulse = maxf(_pulse, 0.8)
	_heat = heat
	if not _ready_once:
		_heat_shown = heat
	_ready_once = true
	queue_redraw()


func _float_delta(d: int, slot: int) -> void:
	if d == 0:
		return
	# one floater per slot: a new change replaces the old one
	_floaters = _floaters.filter(func(fl: Dictionary) -> bool: return int(fl["slot"]) != slot)
	_floaters.append({"text": ("+$" if d > 0 else "−$") + W.money(absi(d)), "color": UI.GREEN if d > 0 else UI.RED, "t": 0.0, "slot": slot})


## Lit segments of the badge: one per 20 Heat (a trace under 3 doesn't count).
static func _segments(heat: float) -> int:
	return 0 if heat < 3.0 else clampi(ceili(heat / 20.0 - 0.001), 0, 5)


## One word per step, so the word and the badge always agree. At 100 the feds raid.
static func heat_word(heat: float) -> String:
	if heat >= 100.0:
		return "RAID"
	return ["Clean", "Noticed", "Watched", "Wanted", "Hot", "Raid soon"][_segments(heat)]


func _process(delta: float) -> void:
	var busy := false
	var target := Vector3(_wallet, _stash, _bank)
	if not _shown.is_equal_approx(target):
		_shown = _shown.lerp(target, clampf(delta * 7.0, 0.0, 1.0))
		if (_shown - target).length() < 0.6:
			_shown = target
		busy = true
	if absf(_heat_shown - _heat) > 0.05:
		_heat_shown = lerpf(_heat_shown, _heat, clampf(delta * 4.0, 0.0, 1.0))
		busy = true
	if _pulse > 0.0 or _heat >= 80.0:
		_pulse = maxf(0.0, _pulse - delta)
		busy = true
	for fl in _floaters:
		fl["t"] = float(fl["t"]) + delta
	if not _floaters.is_empty():
		_floaters = _floaters.filter(func(fl: Dictionary) -> bool: return float(fl["t"]) < 1.8)
		busy = true
	if busy:
		queue_redraw()


func _draw() -> void:
	if _fam.is_empty():
		return
	var r := Rect2(Vector2.ZERO, Vector2(W_PANEL, H_PANEL))
	UI.panel(self, r)
	var fam_col := Color(String(_fam["color"]))
	var fname := String(_fam["name"])
	# the crest
	UI.crest(self, Vector2(60, 62), 40.0, fam_col, fname.left(1).to_upper())
	var x0 := 118.0
	var cond := UI.font("cond")
	var serif := UI.font("serif")
	var semi := UI.font("semi")
	var sans := UI.font("sans")
	UI.text(self, Vector2(x0, 33), "THE %s FAMILY" % fname.to_upper(), cond, 16, UI.GOLD2)
	# the wallet, big
	UI.icon(self, "wallet", Vector2(x0 + 13, 63), 25.0, UI.GOLD2, UI.WOOD_BOT)
	var wtxt := "$" + W.money(int(roundf(_shown.x)))
	UI.text(self, Vector2(x0 + 33, 76), wtxt, serif, 34, UI.INK)
	var wx := x0 + 33 + UI.tw(serif, wtxt, 34) + 8
	UI.text(self, Vector2(wx, 75), "Wallet", sans, 16, UI.MUTE)
	# stash and bank
	var sx := x0 + 2
	UI.icon(self, "safe", Vector2(sx + 8, 99), 17.0, UI.BRASS, UI.WOOD_BOT)
	var stxt := "$" + W.money(int(roundf(_shown.y)))
	UI.text(self, Vector2(sx + 22, 105), stxt, semi, 18, UI.INK)
	var sw := UI.tw(semi, stxt, 18)
	UI.text(self, Vector2(sx + 27 + sw, 105), "Stash", sans, 15, UI.MUTE)
	var bx := maxf(sx + 150.0, sx + 27 + sw + UI.tw(sans, "Stash", 15) + 22)
	UI.icon(self, "bank", Vector2(bx + 8, 99), 17.0, UI.BRASS, UI.WOOD_BOT)
	var btxt := "$" + W.money(int(roundf(_shown.z)))
	UI.text(self, Vector2(bx + 22, 105), btxt, semi, 18, UI.INK)
	UI.text(self, Vector2(bx + 27 + UI.tw(semi, btxt, 18), 105), "Bank", sans, 15, UI.MUTE)
	# the rule
	UI.rule(self, Vector2(14, 122), Vector2(W_PANEL - 14, 122), UI.with_a(UI.BRASS, 0.45), false)
	# men, guns, bullets
	var y := 146.0
	var gx := 18.0
	for it in [["crew", str(_men), "men" if _men != 1 else "man"], ["gun", str(_guns), "guns" if _guns != 1 else "gun"], ["ammo", str(_ammo), "ammo"]]:
		UI.icon(self, String(it[0]), Vector2(gx + 9, y - 6), 19.0, UI.INK, UI.WOOD_BOT)
		UI.text(self, Vector2(gx + 23, y), String(it[1]), semi, 18, UI.INK)
		var nw := UI.tw(semi, String(it[1]), 18)
		UI.text(self, Vector2(gx + 26 + nw, y), String(it[2]), sans, 15, UI.MUTE)
		gx += 26 + nw + UI.tw(sans, String(it[2]), 15) + 13
	_draw_heat(Vector2(W_PANEL - 146, y))
	# floaters: "+$500" rising from the number that changed
	for fl in _floaters:
		var t := float(fl["t"])
		var a := clampf(1.0 - (t - 0.9) / 0.9, 0.0, 1.0) * clampf(t * 6.0, 0.0, 1.0)
		var slot := int(fl["slot"])
		var at := Vector2(wx + UI.tw(sans, "Wallet", 16) + 10, 72) if slot == 0 else (Vector2(sx + 22, 92) if slot == 1 else Vector2(bx + 22, 92))
		at.y -= t * 16.0
		UI.text_sh(self, at, String(fl["text"]), UI.font("cond"), 17 if slot == 0 else 15, UI.with_a(fl["color"], a))


func _draw_heat(at: Vector2) -> void:
	var segs := _segments(_heat_shown)
	var hot := _heat >= 80.0
	var pulse := clampf(_pulse / 1.6, 0.0, 1.0)
	if hot:
		pulse = maxf(pulse, 0.35 + 0.35 * sin(Time.get_ticks_msec() / 180.0))
	var lvl_col := _seg_color(maxi(segs, 1))
	var badge_c := at + Vector2(10, -6)
	if pulse > 0.0:
		Draw.circle(self, badge_c, 14.0 + pulse * 6.0, UI.with_a(lvl_col, 0.25 * pulse))
	UI.icon(self, "badge", badge_c, 22.0 + pulse * 3.0, lvl_col if segs > 0 else UI.MUTE, UI.WOOD_BOT)
	var cond := UI.font("cond")
	var x := at.x + 26
	UI.text(self, Vector2(x, at.y - 10), "HEAT", cond, 14, UI.MUTE)
	UI.text(self, Vector2(x + UI.tw(cond, "HEAT ", 14) + 2, at.y - 10), heat_word(_heat).to_upper(), cond, 14, lvl_col if segs > 0 else UI.INK)
	for k in 5:
		var r := Rect2(Vector2(x + k * 21.0, at.y - 4), Vector2(18, 8))
		Draw.rrect(self, r.grow(1.0), 2.5, Color(0, 0, 0, 0.55))
		if k < segs:
			var c := _seg_color(k + 1)
			if pulse > 0.0 and k == segs - 1:
				c = c.lerp(Color.WHITE, pulse * 0.5)
			Draw.rrect(self, r, 2.0, c)
			Draw.rect(self, Rect2(r.position + Vector2(2, 1), Vector2(r.size.x - 4, 2)), UI.with_a(Color.WHITE, 0.25))
		else:
			Draw.rrect(self, r, 2.0, Color(1, 1, 1, 0.07))


static func _seg_color(k: int) -> Color:
	match k:
		1, 2: return Color("e8b04a")
		3, 4: return Color("f07a3a")
	return Color("ff4a3a")
