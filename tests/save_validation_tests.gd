extends "res://tests/test_base.gd"
## RunSave.save refuses to write a run that would not load again, and leaves the existing save and .bak alone.
## Discovered by run_tests.gd.

var _path := "user://save_validation_%d.json" % OS.get_process_id()


func run() -> int:
	_failures = 0
	_test_normal_run_saves()
	_test_invalid_run_refused()
	_test_cost()
	_test_relic_slack_named()
	return _failures


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return "<none>"
	var text := file.get_as_text()
	file.close()
	return text


func _test_normal_run_saves() -> void:
	remove_scratch(_path)
	var state := RunState.new(11, &"deserter")
	_check(RunSave.save(state, _path) == "", "a normal run still saves")
	_check(RunSave.load_file(_path).run != null, "and the saved file loads")
	remove_scratch(_path)


func _test_invalid_run_refused() -> void:
	remove_scratch(_path)
	var good := RunState.new(12, &"deserter")
	_check(RunSave.save(good, _path) == "", "setup: a good save is on disk")
	var second := RunState.new(13, &"deserter")
	_check(RunSave.save(second, _path) == "", "setup: a second good save makes a .bak")
	var main_before := _read_text(_path)
	var bak_before := _read_text(_path + ".bak")
	# Gold far above anything a run could hold at its first stop: from_dict rejects it, so it must not be written.
	var bad := RunState.new(14, &"deserter")
	bad.gold = RunSave.max_gold(bad, bad.stop_index, bad.relics) + 1
	var error := RunSave.save(bad, _path)
	_check(error != "", "an invalid run (gold above max_gold) is refused")
	_check("load" in error, "the error says the run would not load again (got '%s')" % error)
	_check(_read_text(_path) == main_before, "the existing save is untouched")
	_check(_read_text(_path + ".bak") == bak_before, "the .bak is untouched")
	_check(not FileAccess.file_exists(_path + ".tmp"), "no .tmp is left behind")
	# With no save on disk, nothing is created.
	remove_scratch(_path)
	_check(RunSave.save(bad, _path) != "" and not FileAccess.file_exists(_path) and not FileAccess.file_exists(_path + ".tmp"), "a refused first save creates no file")
	remove_scratch(_path)


## The validation adds one from_dict per save; a save happens once per stop, so it must stay far below a frame.
func _test_cost() -> void:
	var state := RunState.new(15, &"deserter")
	var started := Time.get_ticks_usec()
	for i in 20:
		RunSave.from_dict(RunSave.to_dict(state))
	var per_call_ms := float(Time.get_ticks_usec() - started) / 20000.0
	print("save validation cost: %.3f ms per call" % per_call_ms)
	_check(per_call_ms < 16.0, "validating a save costs well under a frame (%.3f ms)" % per_call_ms)


func _test_relic_slack_named() -> void:
	_check(RunSave.RELIC_SLACK == RunSave.DECK_COPY_SLACK, "the relic slack keeps the old value")
	var run_state := RunState.new(16, &"deserter")
	var vendors := 0
	for stop in run_state.stops:
		if stop.type == RunState.StopType.VENDOR:
			vendors += 1
	_check(RunSave.max_relics(run_state, run_state.stops.size() - 1) == RunSave.RELIC_SLACK + vendors, "max_relics is one per vendor plus RELIC_SLACK")
