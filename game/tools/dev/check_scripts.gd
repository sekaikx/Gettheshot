extends Node
## godot --headless --path game res://tools/dev/check_scripts.tscn
## Loads (compiles) every script under res://scripts and res://tools/test and prints failures.

func _ready() -> void:
	var bad := 0
	var n := 0
	for dir in ["res://scripts", "res://tools/test"]:
		for path in _scripts(dir):
			n += 1
			var s = load(path)
			if s == null or (s is GDScript and not (s as GDScript).can_instantiate() and not path.ends_with("draw.gd")):
				print("CHECK FAIL ", path)
				bad += 1
	print("CHECK %s: %d scripts, %d failed" % ["OK" if bad == 0 else "FAIL", n, bad])
	get_tree().quit()


func _scripts(dir: String) -> Array:
	var out := []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		out.append_array(_scripts(dir.path_join(sub)))
	return out
