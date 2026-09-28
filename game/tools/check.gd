extends SceneTree
## godot --headless --script res://tools/check.gd : compile every script, print failures.
func _init() -> void:
	var bad := 0
	for f in _scan("res://scripts"):
		if f.ends_with(".gd"):
			var s := ResourceLoader.load(f, "", ResourceLoader.CACHE_MODE_IGNORE) as GDScript
			if s == null or not s.can_instantiate():
				print("FAIL ", f)
				bad += 1
	print("checked, failures: ", bad)
	quit()
func _scan(d: String) -> Array:
	var out := []
	var da := DirAccess.open(d)
	for f in da.get_files():
		out.append(d + "/" + f)
	for s in da.get_directories():
		out.append_array(_scan(d + "/" + s))
	return out
