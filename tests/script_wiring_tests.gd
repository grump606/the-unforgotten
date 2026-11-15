extends "res://tests/test_base.gd"
## Guards the game's own scripts the way test_wiring_tests.gd guards the tests: every `class_name` script under
## combat/, run/ and the project root is used by some other game or tool script (by class name or by path), and
## every script has its .uid file. A half-finished split (a new helper that nothing calls yet, a copy of live code
## left behind) is never loaded by anything, so a parse error in it would not fail any other step: it fails here.

## Folders whose scripts are game code (searched recursively). tools/ scripts count as users but are not checked.
const GAME_DIRS: Array[String] = ["res://combat", "res://run"]
const USER_DIRS: Array[String] = ["res://combat", "res://run", "res://tools"]


func run() -> int:
	_failures = 0
	var game_files: Array[String] = []
	for dir in GAME_DIRS:
		_collect(dir, ".gd", game_files)
	for file_name in DirAccess.get_files_at("res://"):
		if file_name.ends_with(".gd"):
			game_files.append("res://" + file_name)
	var users: Array[String] = game_files.duplicate()
	_collect("res://tools", ".gd", users)
	for dir in USER_DIRS:
		_collect(dir, ".tscn", users)
	for file_name in DirAccess.get_files_at("res://"):
		if file_name.ends_with(".tscn") or file_name == "project.godot":
			users.append("res://" + file_name)
	var sources := {}
	for path in users:
		sources[path] = FileAccess.get_file_as_string(path)
	_check(game_files.size() >= 50, "the game scripts are found (%d)" % game_files.size())
	var class_regex := RegEx.create_from_string("(?m)^class_name\\s+(\\w+)")
	for path in game_files:
		_check(FileAccess.file_exists(path + ".uid"), "%s has its .uid file (open the project once in Godot, or run an import, and commit it)" % path)
		var found := class_regex.search(sources[path])
		if found == null:
			continue
		var class_id := found.get_string(1)
		var word := RegEx.create_from_string("\\b%s\\b" % class_id)
		var used := false
		for other: String in sources:
			if other != path and (word.search(sources[other]) != null or (sources[other] as String).contains(path)):
				used = true
				break
		_check(used, "%s (class %s) is not used by any other game or tool script: wire it in or remove it" % [path, class_id])
	return _failures


func _collect(dir: String, suffix: String, into: Array[String]) -> void:
	for file_name in DirAccess.get_files_at(dir):
		if file_name.ends_with(suffix):
			into.append(dir.path_join(file_name))
	for sub in DirAccess.get_directories_at(dir):
		_collect(dir.path_join(sub), suffix, into)
