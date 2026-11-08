extends "res://tests/test_base.gd"
## The check-count floor of run_tests.gd: a run with fewer checks than MIN_CHECKS must fail.

const RunTests := preload("res://tests/run_tests.gd")


func run() -> int:
	_failures = 0
	_check(below_check_floor(0, 15150), "no checks at all is below the floor")
	_check(below_check_floor(15149, 15150), "one check under the floor fails")
	_check(not below_check_floor(15150, 15150), "exactly the floor passes")
	_check(not below_check_floor(20000, 15150), "more than the floor passes")
	_check(RunTests.MIN_CHECKS >= 15000, "MIN_CHECKS has not been lowered below the recorded 15000")
	return _failures
