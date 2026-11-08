extends "res://tests/test_base.gd"
## Edge cases for the two untrusted player files, RunSave (run/run_save.gd) and Settings (run/settings.gd):
## numeric caps, wrong types, NaN and Inf, huge floats, a stale line signature with a bad stop_index,
## duplicate keys, deep nesting, a UTF-8 BOM and leftover .tmp/.bak files. The contract under test: a bad
## file never crashes the game and never produces a half-valid object; it yields an error (RunSave) or the
## defaults (Settings). Scratch paths only, never the real files.

var _save_path := "user://save_edge_run_%d.json" % OS.get_process_id()
var _settings_path := "user://save_edge_settings_%d.json" % OS.get_process_id()


func run() -> int:
	_failures = 0
	_clean()
	_test_run_save_caps()
	_test_run_save_numbers()
	_test_run_save_line_and_stop_index()
	_test_run_save_json_shapes()
	_test_run_save_leftovers()
	_test_settings_types()
	_test_settings_json_shapes()
	_test_settings_leftovers()
	_test_settings_user_dir()
	_clean()
	return _failures


func _clean() -> void:
	for base in [_save_path, _settings_path]:
		remove_scratch(base)


## A valid save dictionary for a fresh run of `character`, ready to be damaged.
func _base(character: StringName = &"thief") -> Dictionary:
	return RunSave.to_dict(RunState.new(7, character))


func _loads(d: Dictionary) -> RunSave.Result:
	return RunSave.from_dict(d)


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _write_bytes(path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()


func _test_run_save_caps() -> void:
	var d := _base()
	_check(_loads(d).run != null, "setup: the fresh save loads")
	# Gold is bounded by what the run could have earned by its stop (RunSave.max_gold), so a fresh run holds almost none.
	var fresh_run := RunState.new(7, &"thief")
	var gold_cap := RunSave.max_gold(fresh_run, 0, [] as Array[RelicData])
	d["gold"] = gold_cap
	_check(_loads(d).run != null and _loads(d).run.gold == gold_cap, "gold at the run's cap is accepted")
	d["gold"] = gold_cap + 1
	_check(_loads(d).run == null, "gold above the run's cap is rejected")
	d["gold"] = 1000000
	_check(_loads(d).run == null, "a million gold on a fresh run is rejected")
	_check(RunSave.max_gold(fresh_run, 3, [] as Array[RelicData]) > gold_cap, "the gold cap rises as the run progresses")
	d["gold"] = -1
	_check(_loads(d).run == null, "negative gold is rejected")
	d["gold"] = 0
	_check(_loads(d).run != null, "zero gold is accepted")

	# Max HP is bounded by the character's base HP plus MAX_HP relics plus a small slack (RunSave.max_hp_allowed).
	d = _base()
	var fresh := RunState.new(7, &"thief")
	var no_relics: Array[RelicData] = []
	var allowed := RunSave.max_hp_allowed(fresh, no_relics)
	d["max_hp"] = allowed
	d["hp"] = allowed
	var loaded := _loads(d)
	_check(loaded.run != null and loaded.run.player.max_hp == allowed and loaded.run.player.hp == allowed, "max_hp and hp at the allowed limit are accepted")
	d["max_hp"] = allowed + 1
	d["hp"] = 1
	_check(_loads(d).run == null, "max_hp one above the allowed limit is rejected")
	d["max_hp"] = RunSave.MAX_HP
	d["hp"] = RunSave.MAX_HP
	_check(_loads(d).run == null, "a hand-edited max_hp of MAX_HP is rejected for a fresh run")
	d = _base()
	d["hp"] = int(d["max_hp"]) + 1
	_check(_loads(d).run == null, "hp above max_hp is rejected")
	d["hp"] = d["max_hp"]
	_check(_loads(d).run != null, "hp equal to max_hp is accepted")
	d["hp"] = 0
	_check(_loads(d).run == null, "hp 0 (a dead run) is rejected")
	d["hp"] = -5
	_check(_loads(d).run == null, "negative hp is rejected")
	d["max_hp"] = 0
	d["hp"] = 0
	_check(_loads(d).run == null, "max_hp 0 is rejected")

	d = _base()
	var deck: Array = []
	for i in RunSave.max_deck(fresh, 0) + 1:
		deck.append("shove")
	d["deck"] = deck
	_check(_loads(d).run == null, "a deck above the size the run's stop allows is rejected")
	# A deck is also bounded per card: a genuine run can only collect so many copies (RunSave.max_copies).
	deck.resize(RunSave.max_deck(fresh, 0))
	d["deck"] = deck
	_check(_loads(d).run == null, "a full-size deck of one card is rejected: more copies than a run can collect")
	var copy_limit := RunSave.max_copies(fresh, &"shove", 0)
	deck.resize(copy_limit)
	d["deck"] = deck
	_check(_loads(d).run != null, "a deck with exactly the most copies of a card a run can hold is accepted")
	deck.append("shove")
	d["deck"] = deck
	_check(_loads(d).run == null, "one copy more than a run can hold is rejected")
	d["deck"] = []
	_check(_loads(d).run == null, "an empty deck is rejected")


func _test_run_save_numbers() -> void:
	var d := _base()
	var hp_ok: int = d["max_hp"]
	d["hp"] = float(hp_ok)
	_check(_loads(d).run != null, "a whole float (JSON gives doubles) is accepted as an int")
	d["hp"] = hp_ok - 0.5
	_check(_loads(d).run == null, "a fractional hp is rejected")
	for bad in [1.0e15, 1.0e15 + 2.0, 1.0e16, -1.0e15, 1.0e300, INF, -INF, NAN]:
		for key in ["hp", "max_hp", "gold", "stop_index"]:
			d = _base()
			d[key] = bad
			_check(_loads(d).run == null, "%s = %s is rejected without crashing" % [key, str(bad)])
	# 1e15 exactly is inside the float guard but far above every cap, so the cap rejects it.
	d = _base()
	d["gold"] = 1.0e15
	_check(_loads(d).run == null, "gold 1e15 is rejected by the cap")
	# Wrong types.
	for bad in ["12", true, null, [1], {"a": 1}]:
		d = _base()
		d["gold"] = bad
		_check(_loads(d).run == null, "gold of type %d is rejected" % typeof(bad))
	# rng_state must be the exact int64 text.
	for bad in ["", " 5", "+5", "05", "99999999999999999999", "1.5", "abc", 5]:
		d = _base()
		d["rng_state"] = bad
		_check(_loads(d).run == null, "rng_state %s is rejected" % str(bad))
	d = _base()
	d["rng_state"] = "-9223372036854775808"
	_check(_loads(d).run != null, "the smallest int64 text is a valid rng_state")
	# A missing key.
	for key in _base().keys():
		d = _base()
		d.erase(key)
		_check(_loads(d).run == null, "a save without '%s' is rejected" % key)
	# Version edge values.
	for bad in [0, 1, RunSave.VERSION + 1, -1, 1.5, "4", null, NAN]:
		d = _base()
		d["version"] = bad
		_check(_loads(d).run == null, "version %s is rejected" % str(bad))


## The line signature is checked before stop_index, so a stale route reports the route, whatever stop_index says.
func _test_run_save_line_and_stop_index() -> void:
	var d := _base()
	d["line"] = "0:1:0:0:0:0"
	d["stop_index"] = 9999
	var result := _loads(d)
	_check(result.run == null and result.error.contains("route"), "a stale line is reported before a bad stop_index (%s)" % result.error)
	d = _base()
	d["stop_index"] = 9999
	result = _loads(d)
	_check(result.run == null and result.error == "bad stop_index", "a good line with a bad stop_index is rejected as bad stop_index")
	var stops := RunState.new(0).stops.size()
	for bad in [-1, stops]:
		d = _base()
		d["stop_index"] = bad
		_check(_loads(d).run == null, "stop_index %d is out of range" % bad)
	d = _base()
	d["stop_index"] = stops - 1
	_check(_loads(d).run != null, "the last stop index is in range")
	for bad in [null, 5, [], "", "garbage"]:
		d = _base()
		d["line"] = bad
		_check(_loads(d).run == null, "line %s is rejected" % str(bad))


func _test_run_save_json_shapes() -> void:
	var text := JSON.stringify(_base())
	_write(_save_path, text)
	_check(RunSave.load_file(_save_path).run != null, "setup: the file loads")
	# Duplicate keys: the parser keeps the last one, and the validators judge that value.
	var dup := text.replace("\"gold\":", "\"gold\":5,\"gold\":")
	_write(_save_path, dup)
	_check(RunSave.load_file(_save_path).run != null, "a duplicate key resolves to its last value (still a valid save)")
	dup = text.replace("\"gold\":", "\"gold\":5,\"gold\":99999999999,\"x\":")
	_write(_save_path, dup)
	_check(RunSave.load_file(_save_path).run == null or RunSave.load_file(_save_path).run.gold <= RunSave.max_gold(RunState.new(7, &"thief"), 0, [] as Array[RelicData]), "a duplicate key can never smuggle a value past the caps")
	# Deep nesting: must come back as an error, not a crash or a hang.
	_write(_save_path, "[".repeat(50000) + "]".repeat(50000))
	var deep := RunSave.load_file(_save_path)
	_check(deep.run == null and deep.error != "", "deeply nested JSON is rejected with an error")
	var nested := _base()
	var cursor: Array = []
	nested["deck"] = [cursor]
	for i in 200:
		var inner: Array = []
		cursor.append(inner)
		cursor = inner
	_check(_loads(nested).run == null, "a deck entry that is a nested array is rejected")
	# Non-object roots.
	for root_text in ["[]", "null", "42", "\"x\"", "true", ""]:
		_write(_save_path, root_text)
		_check(RunSave.load_file(_save_path).run == null, "root '%s' is rejected" % root_text)
	# UTF-8 BOM: the file must either load or be reported as damaged, never crash.
	var bom := PackedByteArray([0xEF, 0xBB, 0xBF])
	bom.append_array(text.to_utf8_buffer())
	_write_bytes(_save_path, bom)
	var with_bom := RunSave.load_file(_save_path)
	_check(with_bom.run != null, "a save with a UTF-8 BOM (Notepad, some editors) loads (error '%s')" % with_bom.error)
	# Invalid UTF-8 bytes.
	var junk := text.to_utf8_buffer()
	junk[10] = 0xFF
	_write_bytes(_save_path, junk)
	var bad_bytes := RunSave.load_file(_save_path)
	_check(bad_bytes.run != null or bad_bytes.error != "", "invalid UTF-8 loads or reports an error")
	# Oversized.
	_write(_save_path, " ".repeat(RunSave.MAX_FILE_BYTES + 1))
	_check(RunSave.load_file(_save_path).error == "save file is too large", "a file over MAX_FILE_BYTES is refused")
	# Extra unknown keys are ignored.
	var extra := _base()
	extra["from_the_future"] = {"a": [1, 2, 3]}
	_check(_loads(extra).run != null, "unknown keys are ignored")


func _test_run_save_leftovers() -> void:
	var run_state := RunState.new(7, &"thief")
	_clean()
	# Only a complete .tmp (the crash window between removing the old file and renaming).
	_write(_save_path + ".tmp", JSON.stringify(RunSave.to_dict(run_state)))
	var from_tmp := RunSave.load_file(_save_path)
	_check(from_tmp.run != null and from_tmp.recovered_from == _save_path + ".tmp", "a complete .tmp with no main file is recovered")
	# A truncated .tmp (the crash was mid-write) with a good .bak falls through to the .bak.
	_write(_save_path + ".tmp", JSON.stringify(RunSave.to_dict(run_state)).substr(0, 40))
	_write(_save_path + ".bak", JSON.stringify(RunSave.to_dict(run_state)))
	var from_bak := RunSave.load_file(_save_path)
	_check(from_bak.run != null and from_bak.recovered_from == _save_path + ".bak", "a truncated .tmp falls through to the .bak")
	# Everything damaged: an error, and not 'missing'.
	_write(_save_path + ".bak", "{")
	var none := RunSave.load_file(_save_path)
	_check(none.run == null and none.error != "", "main absent and every fallback damaged is an error")
	# A good main wins over any leftovers.
	_write(_save_path, JSON.stringify(RunSave.to_dict(run_state)))
	_write(_save_path + ".tmp", "garbage")
	var main := RunSave.load_file(_save_path)
	_check(main.run != null and main.recovered_from == "", "a good main file is used and the junk .tmp ignored")
	# Saving over a stale .tmp replaces it and leaves none behind; the old good main becomes the .bak.
	_check(RunSave.save(run_state, _save_path) == "" and not FileAccess.file_exists(_save_path + ".tmp") and FileAccess.file_exists(_save_path + ".bak"), "save() over a stale .tmp leaves no .tmp and refreshes the .bak")
	_check(RunSave.load_file(_save_path).run != null, "and the new file loads")
	# Delete removes all three.
	_write(_save_path + ".tmp", "x")
	_check(RunSave.delete(_save_path) == "" and not FileAccess.file_exists(_save_path) and not FileAccess.file_exists(_save_path + ".tmp") and not FileAccess.file_exists(_save_path + ".bak"), "delete() removes main, .tmp and .bak")
	# A directory where the file should be: an error, not a crash.
	DirAccess.make_dir_absolute(_save_path)
	var blocked := RunSave.load_file(_save_path)
	_check(blocked.run == null, "a directory in place of the save loads as nothing")
	DirAccess.remove_absolute(_save_path)


func _test_settings_types() -> void:
	for bad in ["true", "false", 1, 0, 1.0, null, [true], {"a": true}, "yes"]:
		var settings := Settings.from_dict({"tutorial_seen": bad, "update_check_enabled": bad})
		_check(not settings.tutorial_seen and settings.update_check_enabled, "tutorial_seen / update_check_enabled of type %d keep their defaults" % typeof(bad))
	_check(Settings.from_dict({"tutorial_seen": true}).tutorial_seen, "a real true tutorial_seen is read")
	_check(not Settings.from_dict({"tutorial_seen": false}).tutorial_seen, "a real false tutorial_seen is read")
	# tutorial_seen is written only when true, and survives a round trip.
	var seen := Settings.new()
	seen.tutorial_seen = true
	_check(seen.save(_settings_path) == "" and Settings.load_file(_settings_path).tutorial_seen, "tutorial_seen round-trips")
	_check(not Settings.to_dict(Settings.new()).has("tutorial_seen"), "a false tutorial_seen is not written")
	# audio of the wrong type is ignored; numbers that are not finite do not break the size check.
	for bad in ["x", 5, [1], null]:
		_check(Settings.from_dict({"audio": bad}).audio.is_empty(), "audio of type %d is ignored" % typeof(bad))
	var wild := Settings.from_dict({"audio": {"master": INF, "music": NAN, "big": 1.0e300}, "future": {"n": -INF}})
	_check(typeof(wild.audio) == TYPE_DICTIONARY and wild.update_check_enabled, "non-finite numbers in audio/extras do not crash the loader")
	# A known key is never copied into extras.
	var keyed := Settings.from_dict({"update_check_enabled": false, "tutorial_seen": true, "audio": {}, "other": 1})
	_check(keyed.extras == {"other": 1}, "known keys stay out of extras")
	# The size caps sit exactly at their limits.
	var at_cap := {}
	var pad := 1
	while JSON.stringify({"k": "x".repeat(pad)}).to_utf8_buffer().size() < Settings.MAX_AUDIO_BYTES:
		pad += 1
	at_cap["k"] = "x".repeat(pad)
	_check(JSON.stringify(at_cap).to_utf8_buffer().size() >= Settings.MAX_AUDIO_BYTES, "setup: audio is at its cap")
	var small := {"k": "x".repeat(pad - 10)}
	_check(not Settings.from_dict({"audio": small}).audio.is_empty(), "audio just under its cap is kept")
	_check(Settings.from_dict({"audio": {"k": "x".repeat(pad + 10)}}).audio.is_empty(), "audio over its cap is dropped")


func _test_settings_json_shapes() -> void:
	remove_scratch(_settings_path)
	# Duplicate keys: the last wins.
	_write(_settings_path, "{\"update_check_enabled\": true, \"update_check_enabled\": false}")
	_check(not Settings.load_file(_settings_path).update_check_enabled, "a duplicate key resolves to its last value")
	# Deep nesting inside an unknown key is kept or dropped, never fatal.
	_write(_settings_path, "{\"update_check_enabled\": false, \"deep\": " + "[".repeat(300) + "]".repeat(300) + "}")
	_check(typeof(Settings.load_file(_settings_path).update_check_enabled) == TYPE_BOOL, "deep nesting under a key does not crash the loader")
	# Pathological depth at the root is just damaged JSON.
	_write(_settings_path, "[".repeat(2000) + "]".repeat(2000))
	_check(Settings.load_file(_settings_path).update_check_enabled, "deeply nested root falls back to the defaults")
	# A UTF-8 BOM before the JSON: loads or falls back to the defaults, never crashes.
	var bom := PackedByteArray([0xEF, 0xBB, 0xBF])
	bom.append_array("{\"update_check_enabled\": false}".to_utf8_buffer())
	_write_bytes(_settings_path, bom)
	var with_bom := Settings.load_file(_settings_path)
	_check(not with_bom.update_check_enabled, "a BOM-prefixed settings file is read, not reset to the defaults")
	# Invalid UTF-8.
	_write_bytes(_settings_path, PackedByteArray([0x7B, 0xFF, 0xFE, 0x7D]))
	_check(Settings.load_file(_settings_path).update_check_enabled, "invalid UTF-8 falls back to the defaults")
	# Exactly at and over the file cap.
	var body := "{\"update_check_enabled\": false, \"pad\": \"%s\"}"
	var overhead := (body % "").to_utf8_buffer().size()
	_write(_settings_path, body % "x".repeat(Settings.MAX_FILE_BYTES - overhead))
	_check(not Settings.load_file(_settings_path).update_check_enabled, "a file of exactly MAX_FILE_BYTES is still read")
	_write(_settings_path, body % "x".repeat(Settings.MAX_FILE_BYTES - overhead + 1))
	_check(Settings.load_file(_settings_path).update_check_enabled, "a file one byte over MAX_FILE_BYTES falls back to the defaults")
	# Huge numbers in an unknown key survive as numbers (they are not interpreted).
	_write(_settings_path, "{\"update_check_enabled\": false, \"n\": 1e300}")
	_check(Settings.load_file(_settings_path).extras.has("n"), "a huge number in an unknown key is kept")


func _test_settings_leftovers() -> void:
	remove_scratch(_settings_path)
	# A stray .tmp is not a recovery source for settings (unlike run saves): it is ignored, and a save replaces it.
	_write(_settings_path + ".tmp", "{\"update_check_enabled\": false}")
	_check(Settings.load_file(_settings_path).update_check_enabled, "a lone .tmp is ignored (the defaults apply)")
	var off := Settings.new()
	off.update_check_enabled = false
	_check(off.save(_settings_path) == "" and not FileAccess.file_exists(_settings_path + ".tmp"), "save() replaces a stale .tmp and leaves none")
	_check(not Settings.load_file(_settings_path).update_check_enabled, "and the saved file loads")
	# A good .bak next to a missing main is used; a good main beats a different .bak.
	DirAccess.remove_absolute(_settings_path)
	_write(_settings_path + ".bak", "{\"update_check_enabled\": false}")
	_check(not Settings.load_file(_settings_path).update_check_enabled, "a good .bak with no main file is used")
	_write(_settings_path, "{\"update_check_enabled\": true}")
	_check(Settings.load_file(_settings_path).update_check_enabled, "a good main beats the .bak")
	remove_scratch(_settings_path)


## The save folder is the project's name unless application/config/custom_user_dir_name says otherwise.
## Saves from every earlier version live under "The Unforgotten", so this pins the setting, not the machine's path.
func _test_settings_user_dir() -> void:
	var custom := bool(ProjectSettings.get_setting("application/config/use_custom_user_dir", false))
	var name := str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")) if custom else str(ProjectSettings.get_setting("application/config/name", ""))
	_check(name == "The Unforgotten", "the user data folder name resolves to 'The Unforgotten' (got '%s'): changing it would orphan every save" % name)
