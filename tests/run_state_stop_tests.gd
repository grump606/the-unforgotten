extends "res://tests/run_state_support.gd"
## RunState stops: story beats, vendors, the mid-boss and the final boss.
## Discovered by run_tests.gd.


func run() -> int:
	_failures = 0
	_test_story_flow()
	_test_story_stop_with_missing_beat_is_passable()
	_test_story_content_loaders()
	_test_vendor_flow()
	_test_vendor_gold_and_stale_state()
	_test_boss_stop()
	_test_mid_boss_stop()
	return _failures


func _test_story_flow() -> void:
	var state := RunState.new(8)
	var beat := state.current_beat()
	_check(beat != null and not beat.title.is_empty() and not beat.text.is_empty(), "the opening story stop has a beat to show")
	_check(state.rest() == -1 and state.stop_index == 0, "rest does nothing at a story stop")
	_check(state.read_story() and state.stop_index == 1 and not state.finished, "reading the story advances to the next stop")
	_check(state.current_beat() == null, "no beat off a story stop")
	var index_before := state.stop_index
	_check(not state.read_story() and state.stop_index == index_before, "read_story is rejected off a story stop")
	state.complete_combat(true)
	_check(not state.read_story() and state.reward_pending(), "read_story is rejected while a reward is pending")
	# The final story stop sits before the last fight.
	var late := RunState.new(8)
	late.stop_index = late.stops.size() - 2
	_check(late.current_beat() != null and late.read_story() and late.stop_index == late.stops.size() - 1 and late.current_stop().boss, "the late story stop reads and leads to the boss")


# The missing beat logs push_error on purpose; that output is expected here.
func _test_story_stop_with_missing_beat_is_passable() -> void:
	var state := RunState.new(9)
	state.stops[0].beat_index = 999
	_check(state.current_beat() == null, "a missing beat reads as null")
	_check(state.read_story() and state.stop_index == 1, "a story stop with a missing beat is still passable")
	var last := RunState.new(9)
	last.stops = [RunState.Stop.new(RunState.StopType.STORY, 0, -1)]
	_check(last.read_story() and last.finished and last.escaped, "a missing-beat story stop at the end still finishes the run")


func _test_story_content_loaders() -> void:
	_check(StoryContent.beat_count() > 0, "there are story beats")
	for i in StoryContent.beat_count():
		var beat := StoryContent.beat(i)
		_check(beat != null and beat is StoryBeat and not beat.title.is_empty() and not beat.text.is_empty() and not beat.button_text.is_empty(), "story beat %d loads typed with title, text and button" % i)
	_check(StoryContent.beat(-1) == null, "negative beat index returns null")
	_check(StoryContent.beat(StoryContent.beat_count()) == null, "out-of-range beat index returns null")
	for character_id in [&"deserter", &"thief", &"medium", &"stray"]:
		for i in StoryContent.beat_count():
			var own := StoryContent.beat(i, character_id)
			_check(own != null and not own.text.is_empty(), "%s beat %d loads" % [character_id, i])
		_check(StoryContent.beat(0, character_id).text != StoryContent.beat(0).text, "%s has their own boarding beat" % character_id)
		for i in StoryContent.beat_count():
			_check(StoryContent.beat(i, character_id).text.length() <= StoryContent.beat(i).text.length() + 120, "%s beat %d stays about the neutral length (text card fit)" % [character_id, i])
		_check(StoryContent.beat(2, character_id).text != StoryContent.beat(2).text, "%s has their own empty-platform beat" % character_id)
		_check(StoryContent.beat(2, character_id).title == StoryContent.beat(2).title and not StoryContent.beat(2, character_id).button_text.is_empty(), "%s keeps the station title and has a button" % character_id)
	_check(StoryContent.beat(0, &"nobody").text == StoryContent.beat(0).text, "an unknown character falls back to the neutral beat")
	_check(StoryContent.beat(2, &"nobody").text == StoryContent.beat(2).text, "an unknown character falls back to the neutral station beat")
	var medium_run := RunState.new(8, &"medium")
	_check(medium_run.current_beat().text == StoryContent.beat(0, &"medium").text, "a run shows their character's beat")
	_check(StoryBeat.new().button_text == "Continue", "beat button text defaults to Continue")


func _test_vendor_flow() -> void:
	var state := RunState.new(12)
	_check(state.vendor() == null and not state.leave_vendor(), "no vendor off a vendor stop")
	_check(not state.vendor_buy_card(0).ok and not state.vendor_buy_heal().ok and not state.vendor_remove_card(0).ok, "vendor purchases fail off a vendor stop")

	state = _at_vendor(12)
	_check(state.current_stop().type == RunState.StopType.VENDOR, "setup: at the vendor stop")
	var vendor := state.vendor()
	_check(vendor != null and state.vendor() == vendor, "asking for the vendor again does not re-roll it")
	_check(vendor.gold == state.gold, "the vendor starts with the run's gold")

	# Gold is set before the vendor is first asked for, because the vendor takes it at creation.
	state = _at_vendor(12)
	state.gold = 100
	_check(state.vendor() != null and state.vendor().gold == 100, "setup: fresh vendor with 100 gold")
	var deck_before := state.deck.size()
	var bought := state.vendor_buy_card(0)
	_check(bought.ok and state.deck.size() == deck_before + 1 and state.gold == 100 - bought.spent, "buying a card adds it to the run's deck and syncs gold")
	_check(not state.vendor_buy_card(0).ok and state.gold == 100 - bought.spent and state.deck.size() == deck_before + 1, "buying the same offer twice is refused and changes nothing")

	var removed := state.vendor_remove_card(0)
	_check(removed.ok and state.deck.size() == deck_before and state.gold == 100 - bought.spent - removed.spent, "removing a card shrinks the run's deck and syncs gold")

	state.player.take_damage(30)
	var hp_before := state.player.hp
	var healed := state.vendor_buy_heal()
	_check(healed.ok and state.player.hp == hp_before + healed.healed and healed.healed > 0, "healing restores the run's player")

	var stop_before := state.stop_index
	_check(state.leave_vendor() and state.stop_index == stop_before + 1, "leaving moves to the next stop")
	_check(state.vendor() == null, "no vendor after leaving")

	var poor := _at_vendor(13)
	poor.gold = 0
	_check(poor.vendor() != null and not poor.vendor_buy_card(0).ok and poor.gold == 0, "with no gold every purchase is refused, gold stays at 0")
	_check(not poor.vendor_buy_relic().ok and poor.gold == 0 and poor.relics.is_empty(), "with no gold the relic is refused too")
	_check(not poor.vendor().relic_offer().is_empty(), "every vendor visit stocks a relic")


func _test_vendor_gold_and_stale_state() -> void:
	var state := _at_vendor(26)
	var vendor := state.vendor()
	state.gold = 100  # changed after the vendor already exists
	var bought := state.vendor_buy_card(0)
	_check(bought.ok and state.gold == 100 - bought.spent, "gold changed while a vendor exists is honoured, not overwritten")
	_check(vendor.gold == state.gold, "one source of truth: the vendor's gold is the run's gold after a purchase")
	state.gold = 7  # below every price: each purchase must be refused and change nothing
	_check(vendor.gold == 7, "setting the run's gold is seen by the existing vendor at once")
	var deck_snapshot := state.deck.duplicate()
	var hp_before := state.player.hp
	state.player.hp = maxi(1, state.player.max_hp - 5)
	var hp_hurt := state.player.hp
	var relics_before := state.relics.size()
	var refused := [state.vendor_buy_card(1), state.vendor_remove_card(0), state.vendor_buy_heal(), state.vendor_buy_relic()]
	for r in refused:
		_check(not r.ok and r.spent == 0, "a purchase without gold is refused")
	_check(state.gold == 7 and vendor.gold == 7 and state.deck == deck_snapshot and state.player.hp == hp_hurt and state.relics.size() == relics_before, "failed purchases change nothing (gold, deck, HP, relics)")
	state.player.hp = hp_before
	vendor.gold = 3  # writing through the vendor is writing the run's gold
	_check(state.gold == 3, "the run's gold follows the vendor's")
	state.leave_vendor()
	_check(state.vendor() == null, "the vendor is gone after leaving")
	_check(state.gold == 3, "leaving the vendor keeps the gold")
	_check(vendor != null and state.stop_index == 6, "setup: moved past the vendor stop")


## Walks a run to the boss stop (winning and skipping rewards, resting, reading, leaving vendors).
func _at_boss(rng_seed: int) -> RunState:
	var state := RunState.new(rng_seed)
	var guard := 0
	while not state.finished and not state.current_stop().boss and guard < 60:
		guard += 1
		match state.current_stop().type:
			RunState.StopType.COMBAT:
				_win_and_skip(state)
			RunState.StopType.STORY:
				state.read_story()
			RunState.StopType.VENDOR:
				state.leave_vendor()
			_:
				state.rest()
	return state


func _test_boss_stop() -> void:
	var state := _at_boss(51)
	_check(not state.finished and state.current_stop().boss, "setup: standing at the boss stop")
	var fight := state.start_combat()
	_check(fight != null and fight.enemies.size() == 1 and fight.enemies[0].data.id == &"the_conductor", "the boss stop fights the Conductor alone")
	if fight != null:
		fight.abandon()

	var gold_before := state.gold
	state.complete_combat(true)
	_check(state.gold == gold_before, "beating the boss pays no gold (nothing left to spend it on)")
	_check(not state.reward_pending() and state.reward_choices().is_empty(), "beating the boss offers no card reward")
	_check(state.finished and state.escaped, "beating the boss escapes the line")

	var beaten := _at_boss(52)
	beaten.complete_combat(false)
	_check(beaten.finished and not beaten.escaped, "losing to the boss ends the run without escape")


## Walks a run to the mid-boss stop the same way.
func _at_mid_boss(rng_seed: int) -> RunState:
	var state := RunState.new(rng_seed)
	var guard := 0
	while not state.finished and not state.current_stop().mid_boss and guard < 60:
		guard += 1
		match state.current_stop().type:
			RunState.StopType.COMBAT:
				_win_and_skip(state)
			RunState.StopType.STORY:
				state.read_story()
			RunState.StopType.VENDOR:
				state.leave_vendor()
			_:
				state.rest()
	return state


func _test_mid_boss_stop() -> void:
	var state := _at_mid_boss(61)
	_check(not state.finished and state.stop_index == 9 and state.current_stop().mid_boss, "setup: standing at the mid-boss stop")
	var fight := state.start_combat()
	_check(fight != null and fight.enemies.size() == 1 and fight.enemies[0].data.id == &"the_brakeman", "the mid-boss stop fights the Brakeman alone")
	if fight != null:
		_check(fight.enemies[0].max_hp == StarterContent.mid_boss_encounter()[0].max_hp, "the mid-boss is not stat-ramped")
		fight.abandon()
	var gold_before := state.gold
	state.complete_combat(true)
	_check(state.gold == gold_before + Vendor.gold_for_win(1) + RunState.MID_BOSS_GOLD_BONUS, "beating the mid-boss pays gold with its bonus")
	_check(state.reward_pending() and state.reward_choices().size() == RunState.REWARD_CHOICES, "beating the mid-boss offers a card reward")
	_check(not state.finished and not state.escaped, "beating the mid-boss does not end the run")
	var deck_before := state.deck.size()
	_check(state.resolve_reward(state.reward_choices()[0]) and state.deck.size() == deck_before + 1, "the mid-boss reward can be taken")
	_check(not state.finished and state.stop_index == 10 and state.current_stop().type == RunState.StopType.STORY, "the run continues past the mid-boss to the story beat")

	var beaten := _at_mid_boss(62)
	beaten.complete_combat(false)
	_check(beaten.finished and not beaten.escaped, "losing to the mid-boss ends the run without escape")

	# Relics pay out on the mid-boss like any fight (only the final boss is exempt).
	var relic_run := _at_mid_boss(63)
	var purse := load("res://data/relics/brass_token_purse.tres") as RelicData
	relic_run.relics.assign([purse])
	var relic_gold := relic_run.gold
	relic_run.complete_combat(true)
	_check(relic_run.gold == relic_gold + Vendor.gold_for_win(1) + RunState.MID_BOSS_GOLD_BONUS + purse.amount, "a WIN_GOLD relic pays on the mid-boss")
