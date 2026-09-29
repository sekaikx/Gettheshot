extends Node
## Solo only: while a menu, a map, the family book or a conversation is open, the city stops
## (the clock, the people, the cars). With friends online nothing stops.

var world: Node


func _process(_delta: float) -> void:
	if world == null or world.hud == null:
		return
	var want: bool = Net.is_solo and Game.players.size() <= 1 and world.hud.is_modal() \
		and (not "--autotest" in OS.get_cmdline_user_args() or "--pausetest" in OS.get_cmdline_user_args())
	if get_tree().paused != want:
		get_tree().paused = want


func _exit_tree() -> void:
	if get_tree():
		get_tree().paused = false
