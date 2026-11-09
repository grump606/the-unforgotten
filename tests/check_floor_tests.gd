extends "res://tests/test_base.gd"
## The floors of the check: run_tests.gd fails a run with fewer checks than the committed record
## (tests/golden/min_checks.txt) minus the tolerance, and scripts/check.ps1 fails with fewer ui_*_test.gd steps.


func run() -> int:
	_failures = 0
	_check(below_check_floor(0, 15000), "no checks at all is below the floor")
	_check(below_check_floor(14999, 15000), "one check under the floor fails")
	_check(not below_check_floor(15000, 15000), "exactly the floor passes")
	_check(not below_check_floor(20000, 15000), "more than the floor passes")

	# The floor is the record minus the tolerance, rounded down.
	_check(check_floor(1000, 1.5) == 985, "1.5% under 1000 is 985")
	_check(check_floor(15487, 1.5) == 15254, "1.5% under 15487 is 15254")
	_check(check_floor(1000, 0.0) == 1000, "no tolerance keeps the record")
	_check(CHECK_TOLERANCE_PERCENT > 0.0 and CHECK_TOLERANCE_PERCENT <= 2.0, "the tolerance stays small (at most 2%)")
	_check(below_check_floor(check_floor(15487) - 1, check_floor(15487)) and not below_check_floor(check_floor(15487), check_floor(15487)), "the boundary is exact")

	# The record file format.
	var parsed := parse_record("# a comment\n\nTOTAL_CHECKS=100\n UI_STEPS = 7 \nBAD=x\nnot a line\n")
	_check(parsed.size() == 2 and parsed["TOTAL_CHECKS"] == 100 and parsed["UI_STEPS"] == 7, "the parser reads KEY=number lines and skips comments and junk")

	# The committed record is present and sane, and the folder still holds the recorded number of UI test files.
	var total := recorded("TOTAL_CHECKS")
	var ui_steps := recorded("UI_STEPS")
	_check(total >= 15000, "tests/golden/min_checks.txt records a TOTAL_CHECKS of at least 15000")
	_check(ui_steps >= 20, "tests/golden/min_checks.txt records a UI_STEPS of at least 20")
	var ui_files := 0
	for file_name in DirAccess.get_files_at(TESTS_DIR):
		if file_name.begins_with("ui_") and file_name.ends_with("_test.gd"):
			ui_files += 1
	_check(ui_files >= ui_steps, "tests/ holds at least the recorded %d ui_*_test.gd files (found %d): a UI test was removed" % [ui_steps, ui_files])
	return _failures
