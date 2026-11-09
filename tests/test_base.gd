extends RefCounted
## Shared base for unit-test files (see tests/README.md). Usage:
##
##   extends "res://tests/test_base.gd"
##
##   func run() -> int:
##       _failures = 0
##       _check(1 + 1 == 2, "arithmetic works")
##       return _failures
##
## A failed check prints "FAIL: <label> [<file>]" so the log says which file it came from. This is
## deliberately not a global class (no class_name), so it needs no import step to be found.

const TESTS_DIR := "res://tests"
const STALE_SECONDS := 86400
## Files in tests/ that are never unit-test suites even though their name ends in _tests.gd.
const NOT_SUITES: Array[String] = ["run_tests.gd"]
## Scratch files that belong to the player, never to a test.
const PROTECTED_USER_FILES: Array[String] = ["settings.json", "run_save.json"]

var _failures := 0
## How many checks ran (passed or failed); run_tests.gd prints the total so a lost check shows up.
var _checks := 0


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FAIL: %s [%s]" % [label, _source_name()])


func _source_name() -> String:
	var script: Script = get_script()
	return script.resource_path.get_file() if script != null else "?"


const MIN_CHECKS_FILE := "res://tests/golden/min_checks.txt"
## How far below the recorded total a run may fall before it fails (percent of the record).
const CHECK_TOLERANCE_PERCENT := 1.5


## True when a run executed fewer checks than the floor (see check_floor).
static func below_check_floor(checks: int, minimum: int) -> bool:
	return checks < minimum


## The floor for a recorded total: the record minus the tolerance, rounded down.
static func check_floor(recorded: int, tolerance_percent: float = CHECK_TOLERANCE_PERCENT) -> int:
	return int(floor(float(recorded) * (1.0 - tolerance_percent / 100.0)))


## KEY=number lines of a record file as {key: int}; blank lines and # comments are skipped, and so are lines
## that are not KEY=<digits>.
static func parse_record(text: String) -> Dictionary:
	var values := {}
	for raw in text.split("\n"):
		var line := raw.strip_edges()
		if line == "" or line.begins_with("#") or not "=" in line:
			continue
		var parts := line.split("=", true, 1)
		if parts[1].strip_edges().is_valid_int():
			values[parts[0].strip_edges()] = int(parts[1].strip_edges())
	return values


## One recorded number from tests/golden/min_checks.txt (0 if the file or key is missing, which makes the floor
## useless, so check_floor_tests.gd requires both to be there).
static func recorded(key: String) -> int:
	var file := FileAccess.open(MIN_CHECKS_FILE, FileAccess.READ)
	if file == null:
		return 0
	return int(parse_record(file.get_as_text()).get(key, 0))


## Names of the tests/*_tests.gd files that run_tests.gd runs: every such file with a run() method,
## minus NOT_SUITES, in name order.
static func discover_unit_test_files() -> Array[String]:
	var found: Array[String] = []
	for file_name in _list_tests_dir():
		if file_name.ends_with("_tests.gd") and not NOT_SUITES.has(file_name) and has_run_method(file_name):
			found.append(file_name)
	return found


static func has_run_method(file_name: String) -> bool:
	var script := load(TESTS_DIR + "/" + file_name) as Script
	if script == null:
		return false
	for method in script.get_script_method_list():
		if method.name == "run":
			return true
	return false


## Every .gd file directly under tests/, sorted.
static func _list_tests_dir() -> Array[String]:
	var names: Array[String] = []
	var dir := DirAccess.open(TESTS_DIR)
	if dir == null:
		return names
	for file_name in dir.get_files():
		if file_name.ends_with(".gd"):
			names.append(file_name)
	names.sort()
	return names


static func list_test_files() -> Array[String]:
	return _list_tests_dir()


## True for the scratch names tests create: "<anything>_<process id>" with an optional extension
## chain such as .json, .json.tmp or .json.bak. Never true for the player's own files.
static func is_scratch_name(file_name: String) -> bool:
	if PROTECTED_USER_FILES.has(file_name):
		return false
	var pattern := RegEx.new()
	pattern.compile("^[A-Za-z][A-Za-z0-9_]*_[0-9]+(\\.[A-Za-z0-9]+)*$")
	return pattern.search(file_name) != null


## Deletes a scratch file together with the .tmp and .bak companions that saves leave behind.
static func remove_scratch(path: String) -> void:
	for candidate in [path, path + ".tmp", path + ".bak"]:
		if FileAccess.file_exists(candidate):
			DirAccess.remove_absolute(candidate)


## Removes scratch files and folders left in user:// by crashed or failed runs, when older than
## STALE_SECONDS. A running test's own files are new, so they are never touched. Returns the
## number removed.
static func sweep_stale_scratch(max_age_seconds: int = STALE_SECONDS) -> int:
	var dir := DirAccess.open("user://")
	if dir == null:
		return 0
	var now := Time.get_unix_time_from_system()
	var removed := 0
	var entries: Array[String] = []
	entries.append_array(dir.get_files())
	entries.append_array(dir.get_directories())
	for entry in entries:
		if not is_scratch_name(entry):
			continue
		var path := "user://" + entry
		var modified := FileAccess.get_modified_time(path)
		if modified <= 0 or now - float(modified) < float(max_age_seconds):
			continue
		if DirAccess.dir_exists_absolute(path):
			_remove_tree(path)
		else:
			DirAccess.remove_absolute(path)
		removed += 1
	return removed


static func _remove_tree(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for file_name in dir.get_files():
		DirAccess.remove_absolute(path + "/" + file_name)
	for sub in dir.get_directories():
		_remove_tree(path + "/" + sub)
	DirAccess.remove_absolute(path)
