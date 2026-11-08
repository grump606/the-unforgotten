extends SceneTree
## Headless tests. Run: godot --headless --path . -s res://tests/run_tests.gd
## Runs every tests/*_tests.gd that has a run() method, in name order. Adding such a file needs no
## registration here. See tests/README.md.

const TestBase := preload("res://tests/test_base.gd")


func _initialize() -> void:
	TestBase.sweep_stale_scratch()
	var failures := _run_discovered_files()
	print("FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)


## Runs every discovered tests/*_tests.gd once and returns the total failure count. Each file is
## announced on stdout so a log shows exactly which files ran.
func _run_discovered_files() -> int:
	var total := 0
	for file_name in TestBase.discover_unit_test_files():
		print("TEST FILE: ", file_name)
		var suite: Object = load("res://tests/" + file_name).new()
		total += int(suite.run())
	return total
