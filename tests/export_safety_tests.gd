extends "res://tests/test_base.gd"
## Source patterns the export's text-to-binary conversion mishandles. An exported packed array declared with `= []`
## lost its value in the export (v0.10.0: Find the Seam+ had no Ready), while every test run from the project passed.
## Declare it with `= PackedStringArray()` (or the matching packed constructor). tools/export_integrity.gd checks the
## real export when the installer is built.

const CODE_DIRS: Array[String] = ["res://combat", "res://run", "res://tools"]


func run() -> int:
	_failures = 0
	var pattern := RegEx.create_from_string("(?m)^\\s*@export\\b.*\\bvar\\s+(\\w+)\\s*:\\s*(Packed\\w+Array)\\s*=\\s*\\[")
	var files: Array[String] = []
	for dir in CODE_DIRS:
		_collect(dir, files)
	for file_name in DirAccess.get_files_at("res://"):
		if file_name.ends_with(".gd"):
			files.append("res://" + file_name)
	_check(files.size() >= 50, "the scripts are found (%d)" % files.size())
	for path in files:
		for found in pattern.search_all(FileAccess.get_file_as_string(path)):
			_check(false, "%s: @export var %s: %s = [...] loses its value in the export; write = %s() instead" % [path, found.get_string(1), found.get_string(2), found.get_string(2)])
	# The card that shipped without its keyword: Remembered, it must gain Ready.
	var seam := load("res://data/cards/mark_the_weak.tres") as CardData
	_check(seam != null and seam.remembered_card().ready, "Find the Seam+ is Ready")
	_check(seam != null and seam.remembered_card().keyword_lines().has("Ready"), "Find the Seam+ shows Ready on its face")
	return _failures


func _collect(dir: String, into: Array[String]) -> void:
	for file_name in DirAccess.get_files_at(dir):
		if file_name.ends_with(".gd"):
			into.append(dir.path_join(file_name))
	for sub in DirAccess.get_directories_at(dir):
		_collect(dir.path_join(sub), into)
