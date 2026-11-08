extends "res://tests/test_base.gd"
## Guards the test wiring: every tests/*.gd file is either discovered by run_tests.gd
## (*_tests.gd with run()), run by check.ps1's ui_*_test.gd glob, a named standalone step in
## check.ps1, or plain support code. A file that looks like a test but is none of these fails here,
## so a new test cannot silently never run.

## Standalone SceneTree scripts that scripts/check.ps1 runs by name (each needs its own process).
const STANDALONE_STEPS: Array[String] = [
	"smoke_main.gd",
	"battle_seed_test.gd",
	"audio_runtime_test.gd",
	"reskin_presentation_test.gd",
]
## Infrastructure that is neither a suite nor a step. Files named *_support.gd are shared helpers for
## a split suite and are skipped too.
const INFRASTRUCTURE: Array[String] = ["run_tests.gd", "test_base.gd"]


func run() -> int:
	_failures = 0
	_test_every_test_file_is_wired()
	_test_discovery_is_sane()
	_test_scratch_names()
	return _failures


func _test_every_test_file_is_wired() -> void:
	var discovered := discover_unit_test_files()
	var check_script := FileAccess.get_file_as_string("res://scripts/check.ps1")
	for file_name in list_test_files():
		if INFRASTRUCTURE.has(file_name) or file_name.ends_with("_support.gd"):
			continue  # shared helpers for split suites; never run on their own
		var source := FileAccess.get_file_as_string("res://tests/" + file_name)
		var looks_like_test := source.contains("extends SceneTree") or source.contains("func run(") or file_name.ends_with("_test.gd") or file_name.ends_with("_tests.gd")
		if not looks_like_test:
			continue
		if file_name.ends_with("_tests.gd"):
			_check(discovered.has(file_name), "%s has no run() method, so run_tests.gd would skip it" % file_name)
		elif file_name.begins_with("ui_") and file_name.ends_with("_test.gd"):
			_check(source.contains("extends SceneTree") or source.contains("_support.gd\""), "%s must extend SceneTree (directly or through a *_support.gd) to be run by check.ps1" % file_name)
		elif STANDALONE_STEPS.has(file_name):
			if check_script != "":
				_check(check_script.contains(file_name), "%s is listed as a standalone step but scripts/check.ps1 does not run it" % file_name)
		else:
			_check(false, "%s looks like a test but is not wired: name it *_tests.gd with run(), or ui_*_test.gd, or add it to STANDALONE_STEPS here and to check.ps1" % file_name)
	for file_name in STANDALONE_STEPS:
		_check(FileAccess.file_exists("res://tests/" + file_name), "standalone step %s exists" % file_name)


func _test_discovery_is_sane() -> void:
	var discovered := discover_unit_test_files()
	_check(discovered.has("test_wiring_tests.gd"), "this file is discovered")
	_check(not discovered.has("run_tests.gd"), "run_tests.gd does not run itself")
	_check(discovered.size() >= 30, "discovery finds the suites (%d)" % discovered.size())
	var seen := {}
	for file_name in discovered:
		_check(not seen.has(file_name), "%s is discovered once" % file_name)
		seen[file_name] = true


func _test_scratch_names() -> void:
	for scratch in ["settings_tests_1234.json", "run_save_test_77.json.tmp", "update_installer_test_9", "ui_flow_test_save_5.json.bak", "migration_test_31"]:
		_check(is_scratch_name(scratch), "%s is a scratch name" % scratch)
	for real in ["settings.json", "run_save.json", "run_save.json.bak", "settings.json.tmp", "logs", "audio_prefs.json", "keep_123abc.json"]:
		_check(not is_scratch_name(real), "%s is never swept" % real)
