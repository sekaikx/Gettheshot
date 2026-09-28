class_name Interiors
extends RefCounted
## Floor plans for every business you can walk into. Pure data, deterministic from the lot, so
## every machine builds the same rooms. The World uses the walls and solid items for collision,
## the spots for where people stand, the breakables for shakedowns; InteriorArt draws it all.
##
## Contract (docs/REBUILD_2D.md, "Interiors"). Everything in WORLD PIXELS.
##   layout(lot, kind) -> {
##     "rect": Rect2               the whole lot
##     "front": Vector2            unit vector out of the front door, toward the street
##     "side": Vector2             unit vector along the front (front.orthogonal())
##     "walls": Array              [[Vector2 a, Vector2 b], ...] wall centre lines, W.WALL thick; door gaps left open
##     "doors": Array              [{"pos": Vector2, "dir": Vector2 (pointing out of the room), "kind": "front"|"back"|"office"|"cell"}]
##     "shop": Rect2               the public room
##     "back": Rect2               the back room (storeroom / kitchen / office / the speakeasy), Rect2() if none
##     "owner_spot": Vector2       where the owner stands (behind the counter)
##     "owner_rot": float          which way he faces (radians, 0 = +x)
##     "items": Array              [{"id": int, "type": String, "rect": Rect2, "rot": float, "solid": bool,
##                                   "breakable": bool, "value": int, "room": "shop"|"back"}]
##       types used by the game: "window" (front glass, breakable), "counter", "register" (breakable, can
##       be robbed), "display" (glass case, breakable), "shelf" (breakable), "table", "chair", "safe",
##       "desk", "map_table", "phone", "bar", "stool", "pool_table", "crates", "cell", "bench",
##       "piano", "oven", "rack", "barber_chair", "mirror", "tub", "press", "icebox", "stove", "sink"
##       (art may add more; unknown types are just drawn)
##     "spots": Dictionary         named places: "register", "safe", "desk", "map", "phone", "bar",
##                                  "stools": [..], "tables": [..], "patrons": [..], "guards": [..],
##                                  "recruits": [..], "cells": [Rect2..], "stock": Rect2 (warehouse pallets),
##                                  "sergeant", "captain", "dealer", "mentor"
##   }

const DOOR_W := 1.5      # metres


static func layout(lot: Dictionary, kind: String) -> Dictionary:
	var r := W.lot_rect(lot)
	var f := W.front_dir(float(lot["yaw"]))
	var l := f.orthogonal()
	var depth := absf((r.size).dot(f))
	var width := absf((r.size).dot(l))
	var fc := r.get_center() + f * depth * 0.5
	var M := W.M
	var wt := W.WALL * M
	var to := func(u: float, v: float) -> Vector2: return fc + l * u - f * v
	var rect_uv := func(u0: float, v0: float, u1: float, v1: float) -> Rect2:
		var a: Vector2 = to.call(u0, v0)
		var b: Vector2 = to.call(u1, v1)
		return Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (a - b).abs())
	var hw := width * 0.5 - wt * 0.5
	var fv := wt * 0.5
	var bv := depth - wt * 0.5
	var dw := DOOR_W * M * 0.5
	var split := depth * (0.62 if kind not in ["warehouse", "poolhall"] else 0.8)
	var walls := []
	# front wall with the door in the middle
	walls.append([to.call(-hw, fv), to.call(-dw, fv)])
	walls.append([to.call(dw, fv), to.call(hw, fv)])
	# sides and back
	walls.append([to.call(-hw, fv), to.call(-hw, bv)])
	walls.append([to.call(hw, fv), to.call(hw, bv)])
	walls.append([to.call(-hw, bv), to.call(hw, bv)])
	# the back room, door near one side
	var bd := hw - 1.2 * M
	walls.append([to.call(-hw, split), to.call(bd - dw * 0.8, split)])
	walls.append([to.call(bd + dw * 0.8, split), to.call(hw, split)])
	var items := []
	var add := func(type: String, rc: Rect2, solid: bool, breakable: bool, value: int, room: String) -> void:
		items.append({"id": items.size(), "type": type, "rect": rc, "rot": 0.0, "solid": solid,
			"breakable": breakable, "value": value, "room": room})
	# display windows either side of the door
	add.call("window", rect_uv.call(-hw + wt, 0.0, -dw - 0.2 * M, wt), false, true, 20, "shop")
	add.call("window", rect_uv.call(dw + 0.2 * M, 0.0, hw - wt, wt), false, true, 20, "shop")
	var cv := split - 1.6 * M
	var owner_v := split - 0.9 * M
	var spots := {}
	match kind:
		"club":
			add.call("bar", rect_uv.call(-hw + wt, 1.2 * M, -hw + 1.0 * M, split - 1.0 * M), true, false, 0, "shop")
			add.call("table", rect_uv.call(0.2 * M, 2.0 * M, 1.4 * M, 3.2 * M), true, false, 0, "shop")
			add.call("desk", rect_uv.call(-1.2 * M, depth - 1.8 * M, 0.6 * M, depth - 1.0 * M), true, false, 0, "back")
			add.call("safe", rect_uv.call(-hw + wt, depth - 1.2 * M, -hw + 0.9 * M, depth - wt), true, false, 0, "back")
			add.call("map_table", rect_uv.call(0.9 * M, split + 0.6 * M, hw - 0.6 * M, split + 1.8 * M), true, false, 0, "back")
			spots["desk"] = to.call(-0.3 * M, depth - 2.3 * M)
			spots["safe"] = to.call(-hw + 1.3 * M, depth - 0.8 * M)
			spots["map"] = to.call((0.9 * M + hw - 0.6 * M) * 0.5, split + 2.3 * M)
			spots["phone"] = to.call(hw - 0.6 * M, depth - 0.8 * M)
			spots["mentor"] = to.call(0.8 * M, 1.4 * M)
			spots["guards"] = [to.call(-dw - 0.5 * M, 0.9 * M), to.call(dw + 0.5 * M, 0.9 * M)]
			owner_v = 1.5 * M
		"precinct":
			add.call("counter", rect_uv.call(-hw + wt, cv, hw - 2.0 * M, cv + 0.6 * M), true, false, 0, "shop")
			add.call("cell", rect_uv.call(-hw + wt, split + wt, 0.0, depth - wt), false, false, 0, "back")
			spots["sergeant"] = to.call(0.0, owner_v)
			spots["cells"] = [rect_uv.call(-hw + wt, split + wt, 0.0, depth - wt)]
		"warehouse":
			spots["stock"] = rect_uv.call(-hw + 1.0 * M, 2.0 * M, hw - 1.0 * M, split - 1.0 * M)
			add.call("crates", rect_uv.call(-hw + 1.0 * M, 3.0 * M, -hw + 3.0 * M, 5.0 * M), true, false, 0, "shop")
		"poolhall":
			add.call("pool_table", rect_uv.call(-1.3 * M, 2.0 * M, 1.3 * M, 3.4 * M), true, false, 0, "shop")
			add.call("bar", rect_uv.call(-hw + wt, cv, hw - 2.0 * M, cv + 0.6 * M), true, false, 0, "shop")
			spots["recruits"] = [to.call(-hw + 1.2 * M, 1.2 * M), to.call(hw - 1.2 * M, 1.4 * M)]
		_:
			add.call("counter", rect_uv.call(-hw + wt, cv, hw - 1.8 * M, cv + 0.6 * M), true, false, 0, "shop")
			add.call("register", rect_uv.call(-0.3 * M, cv, 0.3 * M, cv + 0.45 * M), false, true, 25, "shop")
			add.call("display", rect_uv.call(-hw + 0.5 * M, 1.2 * M, -hw + 1.3 * M, 3.0 * M), true, true, 30, "shop")
			add.call("shelf", rect_uv.call(hw - 0.9 * M, 1.2 * M, hw - wt, cv - 0.4 * M), true, true, 20, "shop")
			spots["register"] = to.call(0.0, cv - 0.4 * M)
	if not spots.has("register"):
		spots["register"] = to.call(0.0, cv - 0.4 * M)
	return {"rect": r, "front": f, "side": l, "walls": walls,
		"doors": [{"pos": to.call(0.0, 0.0), "dir": f, "kind": "front"}, {"pos": to.call(bd, split), "dir": f, "kind": "back"}],
		"shop": rect_uv.call(-hw, fv, hw, split), "back": rect_uv.call(-hw, split, hw, bv),
		"owner_spot": to.call(0.0, owner_v), "owner_rot": f.angle(), "items": items, "spots": spots}


## Is a point (px) inside this layout's walls?
static func contains(lay: Dictionary, p: Vector2) -> bool:
	return (lay["rect"] as Rect2).has_point(p)
