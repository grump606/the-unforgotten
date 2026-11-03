extends RefCounted
## Debug launch: parsing of --fight / --character / --hp and the run-state side of a debug fight.
## Registered by run_tests.gd.

var _failures := 0


func run() -> int:
	_failures = 0
	_test_nothing_requested()
	_test_single_boss_names()
	_test_combination_and_names()
	_test_character_and_hp()
	_test_env_fallback_and_args_win()
	_test_bad_input()
	_test_list()
	_test_run_state_uses_debug_encounter()
	return _failures


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAIL: " + label)


func _test_nothing_requested() -> void:
	var launch := DebugLaunch.parse(PackedStringArray(), {})
	_check(not launch.requested and launch.error == "", "no arguments means no debug fight")


func _test_single_boss_names() -> void:
	for name in ["eraser", "the_conductor", "Eraser", "conductor", "THE CONDUCTOR"]:
		var launch := DebugLaunch.parse(PackedStringArray(["--fight=" + name]), {})
		_check(launch.requested and launch.error == "" and launch.enemy_ids == [&"the_conductor"], "'%s' resolves to the Eraser" % name)
	for name in ["bellkeeper", "brakeman", "the_brakeman"]:
		var launch := DebugLaunch.parse(PackedStringArray(["--fight=" + name]), {})
		_check(launch.enemy_ids == [&"the_brakeman"], "'%s' resolves to the Bellkeeper" % name)


func _test_combination_and_names() -> void:
	var launch := DebugLaunch.parse(PackedStringArray(["--fight=wisp, Keepsake Crow,ash hound"]), {})
	_check(launch.error == "" and launch.enemy_ids == [&"skittering_wisp", &"mourning_crow", &"cinder_hound"], "a trio by alias, display name and spaced name")
	var duplicate := DebugLaunch.parse(PackedStringArray(["--fight=wisp,wisp"]), {})
	_check(duplicate.error == "" and duplicate.enemy_ids.size() == 2, "the same enemy can appear twice")
	var mixed := DebugLaunch.parse(PackedStringArray(["--fight=eraser,wisp"]), {})
	_check(mixed.error == "" and mixed.enemy_ids == [&"the_conductor", &"skittering_wisp"], "a boss can be mixed with others")
	var too_many := DebugLaunch.parse(PackedStringArray(["--fight=wisp,wisp,wisp,wisp"]), {})
	_check(too_many.error != "", "more than %d enemies is rejected" % Combat.MAX_ENEMIES)


func _test_character_and_hp() -> void:
	var launch := DebugLaunch.parse(PackedStringArray(["--fight=eraser", "--character=Medium", "--hp=20"]), {})
	_check(launch.character_id == &"medium" and launch.hp == 20, "character and hp are read")
	var default_launch := DebugLaunch.parse(PackedStringArray(["--fight=eraser"]), {})
	_check(default_launch.character_id == StarterContent.DEFAULT_CHARACTER_ID and default_launch.hp == -1, "defaults: deserter, full hp")


func _test_env_fallback_and_args_win() -> void:
	var env := {DebugLaunch.ENV_FIGHT: "crow", DebugLaunch.ENV_CHARACTER: "pickpocket", DebugLaunch.ENV_HP: "9"}
	var from_env := DebugLaunch.parse(PackedStringArray(), env)
	_check(from_env.enemy_ids == [&"mourning_crow"] and from_env.character_id == &"pickpocket" and from_env.hp == 9, "the environment works without arguments")
	var args_win := DebugLaunch.parse(PackedStringArray(["--fight=eraser"]), env)
	_check(args_win.enemy_ids == [&"the_conductor"], "a command-line fight overrides the environment")


func _test_bad_input() -> void:
	_check(DebugLaunch.parse(PackedStringArray(["--fight=dragon"]), {}).error != "", "an unknown enemy is an error")
	_check(DebugLaunch.parse(PackedStringArray(["--fight=wisp,"]), {}).error != "", "an empty name in the list is an error")
	_check(DebugLaunch.parse(PackedStringArray(["--fight=eraser", "--character=wizard"]), {}).error != "", "an unknown character is an error")
	_check(DebugLaunch.parse(PackedStringArray(["--fight=eraser", "--hp=abc"]), {}).error != "", "a non-numeric hp is an error")
	_check(DebugLaunch.parse(PackedStringArray(["--fight=eraser", "--hp=0"]), {}).error != "", "hp below 1 is an error")


func _test_list() -> void:
	var launch := DebugLaunch.parse(PackedStringArray(["--fight=list"]), {})
	_check(launch.requested and launch.list_only and launch.error == "", "--fight=list asks for the list")
	var text := DebugLaunch.help_text()
	_check(text.contains("the_conductor") and text.contains("skittering_wisp"), "the help text names the enemies")


func _test_run_state_uses_debug_encounter() -> void:
	var run_state := RunState.new(1, &"medium")
	_check(run_state.boss_label() == "", "a regular first stop has no boss label")
	for index in run_state.stops.size():
		if run_state.stops[index].type == RunState.StopType.COMBAT:
			run_state.stop_index = index
			break
	run_state.debug_encounter.assign([&"the_conductor"])
	_check(run_state.boss_label() == "Boss", "a debug Eraser fight gets the boss label")
	var combat := run_state.start_combat()
	_check(combat != null and combat.enemies.size() == 1 and combat.enemies[0].data.id == &"the_conductor", "the run fights the debug encounter at the current stop")
	run_state.debug_encounter.assign([&"the_brakeman"])
	_check(run_state.boss_label() == "Mid-boss", "a debug Bellkeeper fight gets the mid-boss label")
	run_state.debug_encounter.assign([&"skittering_wisp", &"mourning_crow"])
	_check(run_state.boss_label() == "", "a debug pack has no boss label")
	run_state.debug_encounter.clear()
	_check(run_state.boss_label() == "", "cleared, the run is normal again")
