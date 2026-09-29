extends Node2D
## A node whose _draw() is a callable: painter.call(self). The shopfronts and roofs use one per
## shop / roof so a change redraws only that piece (queue_redraw() on it).

var painter: Callable


func _draw() -> void:
	if painter.is_valid():
		painter.call(self)
