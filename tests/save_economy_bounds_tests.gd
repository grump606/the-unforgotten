extends "res://tests/test_base.gd"
## Ties RunSave's bounds to the economy constants: a maximum-gain greedy run (always takes the reward card, never
## skips, buys the relic and every affordable card at every vendor, HP topped up so it goes deep) is saved at every
## stop boundary for all four characters. Every save must load (RunSave bounds accept it) and the deck, gold and
## relic counts must sit within RunSave.max_deck / max_gold / max_relics. If a payout, price or reward changes so a
## legitimate run can out-earn the bounds, this fails instead of a player's save being rejected.

const MAX_STOPS_GUARD := 80


func run() -> int:
	_failures = 0
	for character_id in StarterContent.character_ids():
		for seed_value in 2:
			_check(_play(character_id, seed_value), "%s seed %d: every stop of a maximum-gain run is a loadable save within the bounds" % [character_id, seed_value])
	return _failures


func _play(character_id: StringName, seed_value: int) -> bool:
	var run := RunState.new(seed_value, character_id)
	var guard := 0
	var ok := true
	while not run.finished and guard < MAX_STOPS_GUARD:
		guard += 1
		if not _within_bounds(run):
			ok = false
		var loaded := RunSave.from_dict(JSON.parse_string(JSON.stringify(RunSave.to_dict(run))))
		if loaded.error != "":
			printerr("save economy: %s seed %d stop %d: %s" % [character_id, seed_value, run.stop_index, loaded.error])
			ok = false
		run.player.hp = run.player.max_hp
		match run.current_stop().type:
			RunState.StopType.COMBAT:
				if not _fight(run):
					return false
			RunState.StopType.REST:
				SimPolicy.rest_stop(run, false)
			RunState.StopType.STORY:
				run.read_story()
			RunState.StopType.VENDOR:
				SimPolicy.buy_relic(run)
				var vendor := run.vendor()
				for i in vendor.offers().size():
					if not vendor.offers()[i]["sold"] and vendor.offers()[i]["price"] <= run.gold:
						run.vendor_buy_card(i)
				if not run.leave_vendor():
					return false
	# The run must have gone somewhere: through the whole line, so the bounds were exercised at the late stops too.
	_check(run.finished and guard < MAX_STOPS_GUARD, "%s seed %d: the run reaches its end (stop %d)" % [character_id, seed_value, run.stop_index])
	return ok


func _within_bounds(run: RunState) -> bool:
	var index := run.stop_index
	var good := run.deck.size() <= RunSave.max_deck(run, index) and run.gold <= RunSave.max_gold(run, index, run.relics) and run.relics.size() <= RunSave.max_relics(run, index)
	if not good:
		printerr("save economy: %s stop %d: deck %d/%d gold %d/%d relics %d/%d" % [run.character.id, index, run.deck.size(), RunSave.max_deck(run, index), run.gold, RunSave.max_gold(run, index, run.relics), run.relics.size(), RunSave.max_relics(run, index)])
	return good


func _fight(run: RunState) -> bool:
	var combat := run.start_combat()
	if combat == null:
		return false
	var result := SimPolicy.run_fight(combat)
	if result == SimPolicy.FIGHT_FAILED:
		return false
	if not run.complete_combat(result == 1):
		return false
	if result == 1 and run.reward_pending():
		return run.resolve_reward(run.reward_choices()[0])
	return true
