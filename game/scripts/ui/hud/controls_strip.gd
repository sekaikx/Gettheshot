extends Control
## Bottom-left: the keys that matter right now, as typewriter key caps. Always there (switch it off
## in Settings), but it only lists what you can do at this moment: talk/punch when someone is in
## reach, shoot when you carry a gun, send men when you have men, drop when you carry a crate,
## car when one is next to you. Family / map / country / help are always listed.

const UI := preload("res://scripts/ui/hud/hud_ui.gd")
const H := 36.0
const FS := 16

var hold := false
var world: Node
var marks: Control          # the HUD's world_marks (to know if there is something to use)
var _a := 1.0
var _items: Array = []
var _sig := ""
var _check := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(900, H)
	_scan()


## Show it again (after "How to play" closes). It never fades away on its own now.
func remind() -> void:
	_a = maxf(_a, 0.0)


func strip_height() -> float:
	return H * _a


func strip_width() -> float:
	return _measure(_items)


func _measure(items: Array) -> float:
	var sans := UI.font("sans")
	var x := 12.0
	for k in items:
		x += UI.keycap_w(String(k[0]), 24.0) + 6.0 + UI.tw(sans, String(k[1]), FS) + 16.0
	return x - 4.0


## What can I do now? Pairs of [key, what it does].
func _scan() -> void:
	var items: Array = []
	var la: Variant = null
	if world:
		la = world.get("local_actor")
	var near_prompt := marks != null and String(marks.get("prompt_text")) != ""
	if near_prompt:
		items.append(["E", "talk / use"])
		items.append(["F", "punch"])
	var fam := Game.fam(UI.my_family())
	var ars: Dictionary = fam.get("arsenal", {}) if not fam.is_empty() else {}
	if int(ars.get("pistol", 0)) + int(ars.get("tommy", 0)) > 0 and int(ars.get("ammo", 0)) > 0:
		items.append(["G", "shoot"])
	if not fam.is_empty() and Game.crew_of(int(fam["id"])).size() > 0:
		items.append(["R", "send men"])
	if la is Actor and is_instance_valid(la):
		var me := la as Actor
		if me.carrying:
			items.append(["Q", "drop crate"])
		if me.hidden_in_car:
			items.append(["V", "get out"])
		elif world:
			for v in (world.get("vehicles") as Dictionary).values():
				if is_instance_valid(v) and (v as Node2D).position.distance_to(me.position) < 3.5 * W.M:
					items.append(["V", "car"])
					break
	items.append(["Tab", "family"])
	items.append(["M", "map"])
	items.append(["J", "country"])
	items.append(["H", "help"])
	var sig := str(items)
	if sig != _sig:
		_sig = sig
		_items = items
		queue_redraw()


func _process(delta: float) -> void:
	_check -= delta
	if _check <= 0.0:
		_check = 0.2
		_scan()
	var want := 1.0 if (not hold and bool(Settings.get_value("show_controls", true))) else 0.0
	var old := _a
	_a = move_toward(_a, want, delta * 4.0)
	if absf(_a - old) > 0.0001:
		queue_redraw()


func _draw() -> void:
	if _a <= 0.01:
		return
	var sans := UI.font("sans")
	var r := Rect2(Vector2.ZERO, Vector2(_measure(_items), H))
	Draw.rrect(self, r, 8.0, Color(0.06, 0.045, 0.035, 0.82 * _a))
	UI.rrect_line(self, r, 8.0, UI.with_a(UI.BRASS_DK, 0.9 * _a), 1.0)
	var x := 12.0
	for k in _items:
		var kw := UI.keycap_w(String(k[0]), 24.0)
		UI.keycap(self, Rect2(Vector2(x, 6), Vector2(24, 24)), String(k[0]), _a)
		x += kw + 6.0
		UI.text(self, Vector2(x, UI.mid(sans, FS, H * 0.5)), String(k[1]), sans, FS, UI.with_a(UI.INK, 0.95 * _a))
		x += UI.tw(sans, String(k[1]), FS) + 16.0
