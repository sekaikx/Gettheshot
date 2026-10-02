extends Control
## Top-right: the date, a sun-and-moon dial for the time of day (Game.clock: 0 dawn, 0.25 noon,
## 0.5 dusk, 0.75 midnight) over a little skyline, the weather, and a red badge when other families
## want a sit-down (Game.deals to you): use the telephone at your club, or open the family book.

signal badge_clicked

const UI := preload("res://scripts/ui/hud/hud_ui.gd")
const W_PANEL := 300.0
const H_PANEL := 74.0
const H_BADGE := 50.0

var world: Node
var _deals := 0
var _weather := "clear"
var _blink := 0.0
var _hover := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	size = Vector2(W_PANEL, H_PANEL + 8 + H_BADGE)
	mouse_exited.connect(func() -> void:
		_hover = false
		queue_redraw())


## Height used on screen (the toasts stack under it).
func used_height() -> float:
	return H_PANEL + ((8.0 + H_BADGE) if _deals > 0 else 0.0)


func read_game() -> void:
	var me := UI.my_family()
	var n := 0
	for d in Game.deals:
		if int(d.get("to", -1)) == me and me >= 0:
			n += 1
	if n > _deals:
		_blink = 2.0
	_deals = n
	if world and is_instance_valid(world):
		_weather = String(world.get("weather")) if world.get("weather") != null else "clear"
	queue_redraw()


func _badge_rect() -> Rect2:
	return Rect2(Vector2(0, H_PANEL + 8), Vector2(W_PANEL, H_BADGE))


func _has_point(p: Vector2) -> bool:
	return _deals > 0 and _badge_rect().has_point(p)


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		var h := _has_point((e as InputEventMouseMotion).position)
		if h != _hover:
			_hover = h
			queue_redraw()
	if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if _has_point((e as InputEventMouseButton).position):
			accept_event()
			badge_clicked.emit()


func _process(delta: float) -> void:
	if _blink > 0.0:
		_blink = maxf(0.0, _blink - delta)
	queue_redraw()


static func time_word(c: float) -> String:
	if c < 0.05 or c >= 0.96:
		return "Dawn"
	if c < 0.19:
		return "Morning"
	if c < 0.31:
		return "Noon"
	if c < 0.44:
		return "Afternoon"
	if c < 0.56:
		return "Evening"
	return "Night"


static func weather_word(w: String) -> String:
	match w:
		"rain": return "Rain"
		"fog": return "Fog"
	return "Clear"


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, Vector2(W_PANEL, H_PANEL))
	UI.panel(self, r)
	var c := Vector2(42, 37)
	_dial(c, 26.0)
	var serif := UI.font("serif")
	var sans := UI.font("sans")
	UI.text(self, Vector2(84, 33), Game.date_text(), serif, 22, UI.INK)
	var night := Game.clock >= 0.56 and Game.clock < 0.96
	var wicon := "rain" if _weather == "rain" else ("fog" if _weather == "fog" else ("moon" if night else "sun"))
	UI.icon(self, wicon, Vector2(94, 53), 17.0, UI.GOLD2 if wicon in ["sun", "moon"] else Color("b8c4d0"), UI.WOOD_BOT)
	UI.text(self, Vector2(108, 59), "%s · %s" % [time_word(Game.clock), weather_word(_weather)], sans, 16, UI.MUTE)
	if _deals > 0:
		_draw_badge(_badge_rect())


## The time-of-day dial: sky colour, the sun or moon riding an arc, a skyline on the horizon.
func _dial(c: Vector2, rad: float) -> void:
	var t := Game.clock
	var ang := t * TAU
	var elev := sin(ang)
	var day := Color("8fb6d6")
	var warm := Color("e89a5a")
	var night := Color("1b2447")
	var sky: Color
	if elev > 0.25:
		sky = day
	elif elev > 0.0:
		sky = warm.lerp(day, elev / 0.25)
	elif elev > -0.25:
		sky = night.lerp(warm, (elev + 0.25) / 0.25)
	else:
		sky = night
	Draw.circle(self, c + Vector2(1.5, 2.5), rad + 3.0, Color(0, 0, 0, 0.45))
	Draw.circle(self, c, rad + 3.0, UI.BRASS_DK)
	Draw.circle(self, c, rad + 1.5, UI.BRASS)
	Draw.circle(self, c, rad, sky.darkened(0.12))
	Draw.circle(self, c + Vector2(0, -rad * 0.25), rad * 0.72, sky)
	var horizon := c.y + 7.0
	# stars at night
	if elev < 0.0:
		var sa := clampf(-elev * 3.0, 0.0, 1.0)
		for k in 9:
			var sp := c + Vector2(Draw.hash01(k, 3, 7) * 34.0 - 17.0, Draw.hash01(k, 9, 2) * -20.0 - 1.0)
			if sp.y < horizon - 3.0:
				Draw.circle(self, sp, 0.9, Color(1, 1, 0.9, 0.8 * sa))
	# the sun and the moon on opposite sides of the arc
	var arc := rad * 0.66
	var sun := Vector2(c.x - cos(ang) * arc, horizon - sin(ang) * arc)
	var moon := Vector2(c.x + cos(ang) * arc, horizon + sin(ang) * arc)
	if sun.y < horizon + 4.0:
		Draw.circle(self, sun, 8.0, Color(1.0, 0.85, 0.45, 0.28))
		Draw.circle(self, sun, 5.5, Color("ffd66e"))
	if moon.y < horizon + 4.0:
		Draw.circle(self, moon, 5.0, Color("e8e4d4"))
		Draw.circle(self, moon + Vector2(2.4, -1.6), 4.2, sky.darkened(0.05))
	# the ground: the circle below the horizon, a skyline standing on it
	var pts := PackedVector2Array()
	var dy := horizon - c.y
	var a0 := asin(clampf(dy / rad, -1.0, 1.0))
	for k in 21:
		var a := lerpf(a0, PI - a0, float(k) / 20.0)
		pts.append(c + Vector2(cos(a), sin(a)) * rad)
	var ground := Color("1e1814") if elev < 0.0 else Color("3a2e26")
	Draw.poly(self, pts, ground)
	var bx := c.x - 19.0
	var hs := [6.0, 10.0, 7.0, 13.0, 8.0, 5.0, 11.0, 7.0]
	var ws := [5.0, 4.0, 6.0, 4.0, 5.0, 4.0, 5.0, 5.0]
	for k in hs.size():
		var w: float = ws[k]
		var h: float = hs[k]
		Draw.rect(self, Rect2(Vector2(bx, horizon - h), Vector2(w, h + 1.0)), ground)
		if elev < 0.05 and k % 2 == 0:
			Draw.rect(self, Rect2(Vector2(bx + 1.5, horizon - h + 3.0), Vector2(1.2, 1.2)), Color("ffd48a"))
		bx += w
	ci_ring(c, rad)


func ci_ring(c: Vector2, rad: float) -> void:
	draw_arc(c, rad, 0, TAU, 48, UI.BRASS_DK, 1.5, true)
	for k in 4:
		var d := Vector2.from_angle(TAU * k / 4.0 - PI * 0.5)
		draw_line(c + d * (rad + 0.5), c + d * (rad + 3.0), UI.BRASS_HI, 1.5, true)


func _draw_badge(r: Rect2) -> void:
	var blink := clampf(_blink / 2.0, 0.0, 1.0)
	UI.soft_shadow(self, r, 7.0)
	UI.grad_rrect(self, r, 7.0, UI.OXBLOOD.lightened(0.08 + (0.1 if _hover else 0.0)), UI.OXBLOOD.darkened(0.45))
	UI.rrect_line(self, r, 7.0, UI.BRASS_DK, 2.0)
	UI.rrect_line(self, r.grow(-4), 4.0, UI.with_a(UI.BRASS, 0.5 + 0.5 * blink), 1.0)
	var ic := Vector2(r.position.x + 26, r.get_center().y)
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 260.0)
	Draw.circle(self, ic, 16.0, Color(0, 0, 0, 0.3))
	UI.icon(self, "phone", ic, 22.0, UI.GOLD2.lerp(Color.WHITE, 0.3 * pulse), UI.OXBLOOD.darkened(0.4))
	var semi := UI.font("semi")
	var sans := UI.font("sans")
	var t1 := "%d sit-down offer%s waiting" % [_deals, "" if _deals == 1 else "s"]
	UI.text(self, Vector2(r.position.x + 50, r.position.y + 22), t1, semi, 16, UI.INK)
	UI.text(self, Vector2(r.position.x + 50, r.position.y + 40), UI.fit(sans, "Use your club's phone · or press Tab", 15, r.size.x - 60), sans, 15, Color("e0c8b0"))
