extends "res://tests/test_base.gd"
## The sim tools must fail on the engine's own errors, not only on bot errors: every engine error site goes
## through Combat.engine_error, which counts it (Combat.engine_errors) and SimPolicy.failure_count adds it to the
## bot errors the tools turn into exit 1. Also: RunState.complete_combat reports a rejected call.


func run() -> int:
	_failures = 0
	var before := Combat.engine_errors
	_test_hook_counts()
	_test_real_sites_count()
	_test_complete_combat_result()
	Combat.engine_errors = before
	_check(Combat.engine_errors == before, "the counter is put back for the other suites")
	return _failures


func _fight(effects: Array[CardEffect]) -> Combat:
	var enemies: Array[EnemyData] = [EnemyData.make("E", 50, [] as Array[CardEffect])]
	var deck: Array[CardData] = [CardData.make(&"odd", "Odd", 0, effects)]
	var combat := Combat.new(Combatant.new("p", 40), deck, enemies, 1)
	combat.start()
	return combat


func _test_hook_counts() -> void:
	var n := Combat.engine_errors
	var f := SimPolicy.failure_count()
	Combat.engine_error("sim_engine_error_tests: deliberate engine error (expected in this log)")
	_check(Combat.engine_errors == n + 1, "engine_error counts the problem")
	_check(SimPolicy.failure_count() == f + 1 and SimPolicy.exit_code(SimPolicy.failure_count()) == 1, "and the sims' failure count (exit code 1) sees it")


func _test_real_sites_count() -> void:
	var unknown := CardEffect.make(CardEffect.Kind.DAMAGE, 1)
	unknown.kind = 9999 as CardEffect.Kind
	var n := Combat.engine_errors
	var combat := _fight([unknown] as Array[CardEffect])
	combat.play_card(0, 0)
	_check(Combat.engine_errors > n, "an effect kind with no handler counts as an engine error")
	n = Combat.engine_errors
	var combat2 := _fight([CardEffect.make(CardEffect.Kind.ADD_CARD, 1)] as Array[CardEffect])
	combat2.play_card(0, 0)
	_check(Combat.engine_errors > n, "an ADD_CARD effect with no card counts as an engine error")
	n = Combat.engine_errors
	_check(StarterContent.character(&"no_such_character") == null and Combat.engine_errors > n, "a content-load failure counts as an engine error")


func _test_complete_combat_result() -> void:
	var state := RunState.new(1)
	var n := Combat.engine_errors
	_check(state.complete_combat(true) == false, "complete_combat is rejected (false) at a story stop")
	_check(Combat.engine_errors > n, "and the rejection is counted")
	state.read_story()
	_check(state.complete_combat(true) == true, "complete_combat at a fresh combat stop is accepted (true)")
	_check(state.complete_combat(true) == false, "and a second call (reward now pending) is rejected")
