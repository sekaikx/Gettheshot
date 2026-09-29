extends RefCounted
## Click areas for screens drawn by hand (the family book, Don's View). Each layer registers its
## buttons while it draws; the screen asks what's under the mouse, and moves a keyboard
## selection between them (arrow keys pick the nearest button in that direction).
## Our buttons never take Godot focus, so Tab, M and Esc always reach the HUD.

var items: Array = []        # {id, rect: Rect2, layer: int, cb: Callable, on: bool, tip: String}
var hover := ""              # under the mouse
var focus := ""              # the keyboard selection
var keys := false            # the last input came from the keyboard: show the selection
var modal := -1              # when >= 0, only this layer's buttons answer (a picker is open)
var pressed := ""


func clear(layer: int) -> void:
	var keep: Array = []
	for h in items:
		if int(h["layer"]) != layer:
			keep.append(h)
	items = keep


func add(layer: int, id: String, rect: Rect2, cb: Callable, on: bool = true, tip: String = "") -> void:
	items.append({"id": id, "rect": rect, "layer": layer, "cb": cb, "on": on, "tip": tip})


func find(id: String) -> Dictionary:
	for h in items:
		if h["id"] == id:
			return h
	return {}


func live() -> Array:
	if modal < 0:
		return items
	return items.filter(func(h: Dictionary) -> bool: return int(h["layer"]) == modal)


## The button under a point (the last one drawn wins: it's on top).
func at(p: Vector2) -> Dictionary:
	var l := live()
	for k in range(l.size() - 1, -1, -1):
		var h: Dictionary = l[k]
		if (h["rect"] as Rect2).has_point(p):
			return h
	return {}


## Is this button lit (under the mouse, or selected with the keyboard)?
func hot(id: String) -> bool:
	return id == hover or (keys and id == focus)


func press(id: String) -> bool:
	var h := find(id)
	if h.is_empty() or not bool(h["on"]):
		return false
	var cb: Callable = h["cb"]
	if cb.is_valid():
		cb.call()
	return true


## Moves the keyboard selection toward `dir`. Returns false if there's nothing that way.
func nav(dir: Vector2) -> bool:
	var l := live().filter(func(h: Dictionary) -> bool: return (h["cb"] as Callable).is_valid())
	if l.is_empty():
		return false
	var cur := find(focus)
	if cur.is_empty() or (modal >= 0 and int(cur["layer"]) != modal):
		focus = String(l[0]["id"])
		keys = true
		return true
	var from: Vector2 = (cur["rect"] as Rect2).get_center()
	var best := ""
	var bd := INF
	for h in l:
		if h["id"] == cur["id"]:
			continue
		var r: Rect2 = h["rect"]
		var to := r.get_center()
		var d := to - from
		var along := d.dot(dir)
		if along <= 4.0:
			continue
		var across := absf(d.dot(dir.orthogonal()))
		# prefer things in line; rows first when moving up and down
		var score := along + across * (2.5 if dir.y != 0.0 else 1.6)
		if score < bd:
			bd = score
			best = String(h["id"])
	if best == "":
		return false
	focus = best
	keys = true
	return true


func tip_of(id: String) -> String:
	var h := find(id)
	return String(h.get("tip", "")) if not h.is_empty() else ""
