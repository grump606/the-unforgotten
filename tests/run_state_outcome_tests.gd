extends "res://tests/run_state_support.gd"
## complete_combat (the game's path) records the outcome of the run's own fight and refuses anything else (no fight,
## or one that has not ended). force_combat_result (sims, tests, debug tools) still lets an ended fight decide, so a
## caller cannot report a victory for a lost fight (or the reverse); with no ended fight it takes the caller's word.


func run() -> int:
	_failures = 0
	_complete_combat_uses_the_fights_outcome()
	_complete_combat_needs_an_ended_fight()
	_won_fight_ignores_a_false_claim()
	_lost_fight_ignores_a_true_claim()
	_abandoned_fight_takes_the_callers_word()
	_fight_in_flight_is_cut_short()
	_without_a_fight_the_caller_is_trusted()
	_second_start_replaces_the_fight()
	return _failures


## Plays the run's current combat stop to its end with the smart policy; returns the finished Combat.
func _play_out(state: RunState) -> Combat:
	var combat := state.start_combat()
	combat.start()
	var guard := 0
	while SimPolicy.is_acting(combat) and guard < 80:
		SmartPolicy.play_turn(combat)
		guard += 1
	return combat


func _complete_combat_uses_the_fights_outcome() -> void:
	var state := _at_first_fight(7)
	var combat := _play_out(state)
	_check(combat.outcome == Combat.Outcome.VICTORY, "the first fight is won")
	_check(state.complete_combat() and state.reward_pending() and not state.finished, "complete_combat records the fight's victory")
	_check(not state.complete_combat(), "a second call is rejected (a reward is pending)")


## No fight, or a fight still running: the game's path refuses, and the run is unchanged.
func _complete_combat_needs_an_ended_fight() -> void:
	var state := _at_first_fight(7)
	_check(not state.complete_combat() and not state.reward_pending() and not state.finished, "complete_combat with no fight started is rejected")
	var combat := state.start_combat()
	combat.start()
	_check(not state.complete_combat() and combat.phase != Combat.Phase.ENDED and not state.reward_pending(), "complete_combat during the fight is rejected and the fight goes on")


func _won_fight_ignores_a_false_claim() -> void:
	var state := _at_first_fight(7)
	var combat := _play_out(state)
	_check(combat.phase == Combat.Phase.ENDED and combat.living_enemies().is_empty(), "the first fight is won")
	state.force_combat_result(false)
	_check(not state.finished and state.reward_pending(), "a won fight is a victory whatever the caller says")


func _lost_fight_ignores_a_true_claim() -> void:
	var state := _at_first_fight(7)
	state.player.hp = 1
	var combat := state.start_combat()
	combat.start()
	var guard := 0
	while SimPolicy.is_acting(combat) and guard < 100:
		combat.end_player_turn(SimPolicy.discards_for(combat))
		guard += 1
	_check(combat.outcome == Combat.Outcome.DEFEAT, "the fight is lost")
	state.force_combat_result(true)
	_check(state.finished and not state.escaped and not state.reward_pending(), "a lost fight is a defeat whatever the caller says")


## An abandoned fight has no outcome of its own, so the caller decides (a sim's stall is a defeat).
func _abandoned_fight_takes_the_callers_word() -> void:
	var state := _at_first_fight(7)
	var combat := state.start_combat()
	combat.start()
	combat.abandon()
	_check(combat.outcome == Combat.Outcome.NONE, "an abandoned fight has no outcome")
	state.force_combat_result(false)
	_check(state.finished and not state.escaped, "an abandoned fight reported as a defeat ends the run")
	var other := _at_first_fight(7)
	other.start_combat().abandon()
	other.force_combat_result(true)
	_check(other.reward_pending(), "an abandoned fight reported as a victory is taken as one")


## A fight still running has no outcome: it is abandoned and the caller's word is taken (UI tests rely on it).
func _fight_in_flight_is_cut_short() -> void:
	var state := _at_first_fight(7)
	var combat := state.start_combat()
	combat.start()
	state.force_combat_result(true)
	_check(combat.phase == Combat.Phase.ENDED and state.reward_pending(), "a fight in progress is abandoned and the caller's victory is taken")


func _without_a_fight_the_caller_is_trusted() -> void:
	var state := _at_first_fight(7)
	state.force_combat_result(true)
	_check(state.reward_pending(), "no fight started: the caller's victory is taken (tests, debug paths)")
	var loser := _at_first_fight(7)
	loser.force_combat_result(false)
	_check(loser.finished and not loser.escaped, "no fight started: the caller's defeat is taken")


## Documented behaviour: asking again at one stop abandons the first fight and builds a new one.
func _second_start_replaces_the_fight() -> void:
	var state := _at_first_fight(7)
	var first := state.start_combat()
	first.start()
	var second := state.start_combat()
	_check(second != first and first.phase == Combat.Phase.ENDED, "a second start_combat abandons the first fight")
	_check(state.player.block == 0, "the abandoned fight leaves nothing on the player")
