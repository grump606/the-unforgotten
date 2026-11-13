extends SceneTree
## Headless tests. Run: godot --headless --path . -s res://tests/run_tests.gd
## Runs every tests/*_tests.gd that has a run() method, in name order. Adding such a file needs no
## registration here. See tests/README.md.

const TestBase := preload("res://tests/test_base.gd")

var _total_checks := 0


func _initialize() -> void:
	TestBase.sweep_stale_scratch()
	# The older suites play the one-chapter game; the chapter suites set the count they need and put this back.
	Chapters.count_override = 1
	var failures := _run_discovered_files()
	# The floor comes from the committed record (tests/golden/min_checks.txt) minus a tolerance, not from a constant
	# edited by hand: a suite that silently runs less (a method no longer called, a loop gone empty) fails the run.
	var recorded := TestBase.recorded("TOTAL_CHECKS")
	var floor_checks := TestBase.check_floor(recorded)
	if recorded <= 0 or TestBase.below_check_floor(_total_checks, floor_checks):
		printerr("FAIL: %d checks ran; the floor is %d (TOTAL_CHECKS %d in tests/golden/min_checks.txt, minus %s%%): a suite stopped checking something, or the record is missing" % [_total_checks, floor_checks, recorded, str(TestBase.CHECK_TOLERANCE_PERCENT)])
		failures += 1
	elif _total_checks > recorded + recorded / 20:
		print("NOTE: %d checks ran, over 5%% more than the record (%d): raise TOTAL_CHECKS in tests/golden/min_checks.txt" % [_total_checks, recorded])
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
