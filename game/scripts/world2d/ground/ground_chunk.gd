class_name GroundChunk
extends Node2D
## One piece of the static ground art (a block, a street segment, or one layer of it). It draws
## once: `paint` is called with this node as the canvas item. Godot culls it by the rect of what
## it drew, so the city is split into many of these.

var paint: Callable


func _draw() -> void:
	if paint.is_valid():
		paint.call(self)
