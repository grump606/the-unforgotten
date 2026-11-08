extends "res://tests/test_base.gd"
## Shared helpers for the run_state_*_tests.gd files (stepping a run to a stop). Not a test itself.


## Wins the current combat stop and skips the reward, moving the run on.
func _win_and_skip(state: RunState) -> void:
	state.complete_combat(true)
	state.resolve_reward(null)


## A run that has read the boarding beat and stands at the first fight (stop index 1).
func _at_first_fight(rng_seed: int) -> RunState:
	var state := RunState.new(rng_seed)
	state.read_story()
	return state


## Moves a run to the first VENDOR stop (index 5) by winning/skipping and resting on the way.
func _at_vendor(rng_seed: int) -> RunState:
	var state := _at_first_fight(rng_seed)
	var guard := 0
	while state.current_stop().type != RunState.StopType.VENDOR and guard < 50:
		guard += 1
		match state.current_stop().type:
			RunState.StopType.COMBAT:
				_win_and_skip(state)
			RunState.StopType.STORY:
				state.read_story()
			_:
				state.rest()
	return state
