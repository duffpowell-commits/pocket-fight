extends SceneTree
## Parse-checks every .gd file WITH the autoloads loaded (plain --check-only doesn't know
## autoloads like Settings, so it reports false errors). A parse error makes a scene hang
## instead of failing, so CI runs this first. Prints "SCRIPTS OK" or "SCRIPTS FAIL <files>".

func _initialize() -> void:
	var bad: Array[String] = []
	for path in _all("res://"):
		var s: GDScript = load(path)
		if s == null or not s.can_instantiate():
			bad.append(path)
	print("SCRIPTS FAIL " + ", ".join(bad) if bad.size() > 0 else "SCRIPTS OK")
	quit(1 if bad.size() > 0 else 0)


func _all(dir: String) -> Array[String]:
	var out: Array[String] = []
	for d in DirAccess.get_directories_at(dir):
		if not d.begins_with("."):
			out.append_array(_all(dir.path_join(d)))
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	return out
