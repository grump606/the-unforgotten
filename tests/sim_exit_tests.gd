extends "res://tests/test_base.gd"
## The sim tools must fail (exit 1) on a policy failure or a bot error, and must not mistake a stall for one.
## Last pass balance_sim recorded a failure flag nothing read and always quit(0); these tests read the same pieces
## the tool now uses (SimPolicy.run_fight, bot_errors, exit_code). tools/balance_sim.gd was also run end to end
## against a deliberately broken policy in a scratch copy and exited 1. Discovered by run_tests.gd.


func run() -> int:
	_failures = 0
	_test_exit_code()
	_test_failed_policy_is_not_a_stall()
	_test_stall_is_not_a_failure()
	_test_normal_fight_still_ends()
	_test_bot_errors_are_counted()
	_test_seed_strides()
	return _failures


func _fight() -> Combat:
	var enemies: Array[EnemyData] = [EnemyData.make("E", 5, [] as Array[CardEffect])]
	var deck: Array[CardData] = []
	for i in 10:
		deck.append(CardData.make(&"hit", "Hit", 1, [CardEffect.make(CardEffect.Kind.DAMAGE, 3)] as Array[CardEffect]))
	return Combat.new(Combatant.new("p", 40), deck, enemies, 1)


func _test_exit_code() -> void:
	_check(SimPolicy.exit_code(0) == 0, "no failures exits 0")
	_check(SimPolicy.exit_code(1) == 1 and SimPolicy.exit_code(7) == 1, "any failure exits 1")


func _test_failed_policy_is_not_a_stall() -> void:
	var broken := func(_combat: Combat) -> bool: return false
	var result := SimPolicy.run_fight(_fight(), broken)
	_check(result == SimPolicy.FIGHT_FAILED, "a policy that cannot play reports FIGHT_FAILED (got %d)" % result)
	_check(result != 0, "and it is not counted as a stall (0)")


func _test_stall_is_not_a_failure() -> void:
	# Ends every turn without playing a card against an enemy that never attacks: nothing ever ends the fight.
	var passive := func(combat: Combat) -> bool: return combat.end_player_turn()
	var result := SimPolicy.run_fight(_fight(), passive)
	_check(result == 0, "a fight that hits the turn cap is a stall (got %d)" % result)
	_check(SimPolicy.exit_code(0) == 0, "stalls alone leave the exit code at 0")


func _test_normal_fight_still_ends() -> void:
	var result := SimPolicy.run_fight(_fight())
	_check(result == 1, "the default policy wins the easy fight (got %d)" % result)


## balance_sim's fight seeds stay distinct: --fights is capped at the per-size stride and every size fits below the base stride.
func _test_seed_strides() -> void:
	var constants: Dictionary = (load("res://tools/balance_sim.gd") as Script).get_script_constant_map()
	var size_stride: int = constants["SIZE_STRIDE"]
	var seed_stride: int = constants["SEED_STRIDE"]
	var max_fights: int = constants["MAX_FIGHTS"]
	_check(size_stride == 100003 and seed_stride == 1000003, "the strides keep their old values, so seeds for the default fight counts are unchanged")
	_check(max_fights <= size_stride, "--fights cannot run past one size's block of seeds")
	_check(Combat.MAX_ENEMIES * size_stride + max_fights < seed_stride, "the biggest size's seeds stay below the next base seed's")


func _test_bot_errors_are_counted() -> void:
	var before := SimPolicy.bot_errors
	SimPolicy.bot_error("sim_exit_tests: deliberate bot error (expected in this log)")
	_check(SimPolicy.bot_errors == before + 1, "bot_error counts the problem")
	# The real call sites: an effect kind the smart bot has no valuation for raises the counter.
	var unknown := CardEffect.make(CardEffect.Kind.DAMAGE, 1)
	unknown.kind = 9999 as CardEffect.Kind
	var card := CardData.make(&"odd", "Odd", 1, [unknown] as Array[CardEffect])
	var count := SimPolicy.bot_errors
	SmartPolicy.card_score(card, SmartPolicy._weights([] as Array[CardData]))
	_check(SimPolicy.bot_errors > count, "SmartPolicy counts an unknown CardEffect.Kind through bot_error")
	SimPolicy.bot_errors = before
	_check(SimPolicy.exit_code(SimPolicy.bot_errors) == 0, "the counter is reset for the other suites")
