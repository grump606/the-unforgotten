extends SceneTree
## Headless tests. Run: godot --headless --path . -s res://tests/run_tests.gd
## Runs every tests/*_tests.gd that has a run() method, in name order. Adding such a file needs no
## registration here. See tests/README.md.

const TestBase := preload("res://tests/test_base.gd")
## The fewest checks a full run may execute (the total printed as "CHECKS: n"). A suite that silently runs less,
## because a method stopped being called or a loop became empty, fails the run instead of passing. It is recorded
## here only. Raise it, to a little under the current total, whenever tests are added; never lower it to make a
## run pass (a lower total means checks went missing). Last set at 15150 for a total of 15160+.
const MIN_CHECKS := 15450


var _total_checks := 0


func _initialize() -> void:
	TestBase.sweep_stale_scratch()
	var failures := _run_discovered_files()
	if TestBase.below_check_floor(_total_checks, MIN_CHECKS):
		printerr("FAIL: only %d checks ran, fewer than MIN_CHECKS (%d) in tests/run_tests.gd: a suite stopped checking something" % [_total_checks, MIN_CHECKS])
		failures += 1
	print("FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)


## Runs every discovered tests/*_tests.gd once and returns the total failure count. Each file is
## announced on stdout so a log shows exactly which files ran.
func _run_discovered_files() -> int:
	var total := 0
	var checks := 0
	for file_name in TestBase.discover_unit_test_files():
		print("TEST FILE: ", file_name)
		var suite: Object = load("res://tests/" + file_name).new()
		total += int(suite.run())
		checks += int(suite.get("_checks")) if suite.get("_checks") != null else 0
	_total_checks = checks
	print("CHECKS: %d" % checks)
	return total
