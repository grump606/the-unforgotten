extends RefCounted
## Tests for run/settings.gd: defaults, round trip, and an untrusted settings file that must never
## fail. Uses scratch paths only, never the real user://settings.json. Returns the failure count.

var _failures := 0
var _path := "user://settings_tests_%d.json" % OS.get_process_id()


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAIL: " + label)


func _write(text: String) -> void:
	var file := FileAccess.open(_path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _cleanup() -> void:
	for p in [_path, _path + ".tmp", _path + ".bak"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


func run() -> int:
	_failures = 0
	_cleanup()
	_check(Settings.new().update_check_enabled, "update check defaults to on")
	_check(Settings.load_file(_path).update_check_enabled, "a missing file gives the defaults")

	var off := Settings.new()
	off.update_check_enabled = false
	_check(off.save(_path) == "", "settings save")
	_check(not FileAccess.file_exists(_path + ".tmp"), "no temp file is left behind")
	_check(not Settings.load_file(_path).update_check_enabled, "an off setting round-trips")
	var on := Settings.new()
	_check(on.save(_path) == "" and Settings.load_file(_path).update_check_enabled, "an on setting round-trips")

	# The saves above left a .bak, which would rescue a damaged main; these cases test the defaults.
	DirAccess.remove_absolute(_path + ".bak")
	for text in ["", "not json", "{", "[]", "null", "42", "\"x\"", "{}", "{\"update_check_enabled\": \"false\"}", "{\"update_check_enabled\": 0}",
		"{\"update_check_enabled\": null}", "{\"update_check_enabled\": [false]}", "{\"other\": false}"]:
		_write(text)
		_check(Settings.load_file(_path).update_check_enabled, "bad content '%s' falls back to on" % text)
	_write("{\"update_check_enabled\": false, \"extra\": 1}")
	_check(not Settings.load_file(_path).update_check_enabled, "unknown keys are ignored")
	_write("{\"update_check_enabled\": false, \"pad\": \"%s\"}" % "x".repeat(Settings.MAX_FILE_BYTES))
	_check(Settings.load_file(_path).update_check_enabled, "an oversized file falls back to the defaults")
	_check(Settings.from_dict(null).update_check_enabled and Settings.from_dict([]).update_check_enabled, "non-object data gives the defaults")

	_check(Settings.load_file("user://no_such_dir_xyz/settings.json").update_check_enabled, "an unreadable path gives the defaults")
	_check(off.save("user://no_such_dir_xyz/settings.json") != "", "saving to a bad path reports an error")
	_check(not FileAccess.file_exists("user://no_such_dir_xyz/settings.json.tmp"), "a failed write leaves no temp file")

	# A failed rename (the destination is a directory) removes the temp file.
	_cleanup()
	var blocked := _path + "_dir"
	DirAccess.make_dir_absolute(blocked)
	_check(off.save(blocked) != "" and not FileAccess.file_exists(blocked + ".tmp"), "a failed rename leaves no temp file")
	DirAccess.remove_absolute(blocked)

	# One-generation backup, taken only from a file that parses.
	_cleanup()
	_check(off.save(_path) == "" and not FileAccess.file_exists(_path + ".bak"), "the first save has no backup")
	_check(on.save(_path) == "" and FileAccess.file_exists(_path + ".bak"), "the second save keeps the first as .bak")
	_check(not Settings.load_file(_path + ".bak").update_check_enabled, ".bak holds the previous settings")
	_write("{ not json")
	_check(not Settings.load_file(_path).update_check_enabled, "a damaged main falls back to the .bak")
	_check(on.save(_path) == "" and not Settings.load_file(_path + ".bak").update_check_enabled, "a damaged main does not replace the good .bak")
	_check(Settings.load_file(_path).update_check_enabled, "the new save loads")
	_write("garbage")
	_write_to(_path + ".bak", "garbage")
	_check(Settings.load_file(_path).update_check_enabled, "main and .bak both damaged give the defaults")
	_cleanup()
	return _failures


func _write_to(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
