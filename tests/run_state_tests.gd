extends RefCounted
## Tests for the run layer (run/run_state.gd). Returns the failure count; the
## suite in run_tests.gd adds it to its own.

var _failures := 0


func run() -> int:
	_failures = 0
	_test_fresh_state()
	_test_characters()
	_test_default_line()
	_test_start_combat_builds_fight_with_persistent_player()
	_test_start_combat_rejected_off_combat_stop()
	_test_defeat_ends_run()
	_test_reward_flow()
	_test_rest()
	_test_story_flow()
	_test_story_stop_with_missing_beat_is_passable()
	_test_story_content_loaders()
	_test_full_run_escapes()
	_test_seed_determinism()
	_test_gold_from_wins()
	_test_vendor_flow()
	_test_complete_combat_preconditions()
	_test_vendor_gold_and_stale_state()
	_test_start_combat_twice_releases_first()
	_test_rewards_rolled_eagerly_and_copied()
	_test_survivors_from_mutation_audit()
	_test_boss_stop()
	_test_mid_boss_stop()
	_test_progressive_difficulty()
	_test_reward_memory_and_skip_gold()
	_test_reward_alternatives()
	return _failures


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAIL: " + label)


## Wins the current combat stop and skips the reward, moving the run on.
func _win_and_skip(state: RunState) -> void:
	state.complete_combat(true)
	state.resolve_reward(null)


## A run that has read the boarding beat and stands at the first fight (stop index 1).
func _at_first_fight(rng_seed: int) -> RunState:
	var state := RunState.new(rng_seed)
	state.read_story()
	return state


func _test_fresh_state() -> void:
	var state := RunState.new(1)
	_check(state.player.hp == state.character.max_hp and state.player.max_hp == state.character.max_hp, "run starts at full HP")
	_check(state.character.id == StarterContent.DEFAULT_CHARACTER_ID and state.deck.size() == state.character.starting_deck.size(), "run starts with the default character's deck")
	_check(not state.finished and state.stop_index == 0 and not state.reward_pending(), "run starts unfinished at stop 0")


func _test_default_line() -> void:
	var state := RunState.new(1)
	_check(state.stops.size() == 21, "default line has 21 stops")
	_check(state.stops[0].type == RunState.StopType.STORY and state.stops[0].describe() == "Story", "the line opens with a story beat")
	_check(state.stops[1].type == RunState.StopType.COMBAT and state.stops[1].enemy_count == 1, "first fight is a solo fight")
	var regular := 0
	var vendors := 0
	var beats: Array[int] = []
	var bosses := 0
	var mid_bosses := 0
	for stop in state.stops:
		if stop.type == RunState.StopType.COMBAT and not stop.boss and not stop.mid_boss:
			regular += 1
		if stop.type == RunState.StopType.VENDOR:
			vendors += 1
		if stop.type == RunState.StopType.STORY:
			beats.append(stop.beat_index)
		bosses += 1 if stop.boss else 0
		mid_bosses += 1 if stop.mid_boss else 0
	_check(regular == 8, "the line has eight regular fights (twice the old four)")
	_check(vendors == 3 and bosses == 1 and mid_bosses == 1, "three vendors, one mid-boss and one final boss")
	_check(beats == [0, 1, 2, 3], "the four story beats come in order: %s" % str(beats))
	var mid := state.stops[9]
	_check(mid.type == RunState.StopType.COMBAT and mid.mid_boss and not mid.boss and mid.describe() == "Mid-boss", "stop 9 is the mid-boss")
	var before := 0
	for i in 9:
		if state.stops[i].type == RunState.StopType.COMBAT:
			before += 1
	_check(before == 4, "the mid-boss comes after the fourth regular fight, halfway")
	var last := state.stops[state.stops.size() - 1]
	_check(last.type == RunState.StopType.COMBAT and last.boss and not last.mid_boss and last.describe() == "Boss", "the final stop is the boss fight")
	_check(state.stops[10].type == RunState.StopType.STORY and state.stops[10].beat_index == 2, "the empty-platform beat follows the mid-boss")
	var tiers_ok := true
	var fights_ok := true
	var want_fight := 0
	for i in state.stops.size():
		var stop: RunState.Stop = state.stops[i]
		tiers_ok = tiers_ok and stop.tier == (0 if i <= 9 else 1)
		if stop.type == RunState.StopType.COMBAT and not stop.boss and not stop.mid_boss:
			fights_ok = fights_ok and stop.fight == want_fight
			want_fight += 1
	_check(tiers_ok, "stops up to the mid-boss are tier 0, later ones tier 1")
	_check(fights_ok, "regular fights are numbered 0 to 7 in order")


func _test_start_combat_builds_fight_with_persistent_player() -> void:
	var state := _at_first_fight(2)
	state.player.take_damage(15)
	var combat := state.start_combat()
	_check(combat != null, "combat stop builds a fight")
	if combat == null:
		return
	_check(combat.player == state.player and combat.player.hp == state.character.max_hp - 15, "fight uses the run's player with carried-over HP")
	_check(combat.enemies.size() == 1, "first fight has the stop's enemy count")
	_check(combat.piles.draw_pile.size() + combat.piles.hand.size() == state.deck.size() or combat.phase == Combat.Phase.NOT_STARTED, "fight is built from the run's deck")
	combat.abandon()


# These push_error on purpose; that output is expected here.
func _test_start_combat_rejected_off_combat_stop() -> void:
	var state := _at_first_fight(3)
	_win_and_skip(state)
	_win_and_skip(state)
	_check(state.current_stop().type == RunState.StopType.REST, "setup: now at the rest stop")
	_check(state.start_combat() == null, "no fight can start at a rest stop")
	var other := _at_first_fight(3)
	other.complete_combat(true)
	_check(other.reward_pending() and other.start_combat() == null, "no fight can start while a reward is pending")
	var story := RunState.new(3)
	_check(story.start_combat() == null, "no fight can start at a story stop")


func _test_defeat_ends_run() -> void:
	var state := _at_first_fight(4)
	state.complete_combat(false)
	_check(state.finished and not state.escaped, "defeat ends the run without escape")
	_check(state.current_stop() == null and not state.reward_pending(), "no stop or reward after defeat")


func _test_reward_flow() -> void:
	var state := _at_first_fight(5)
	state.complete_combat(true)
	var choices := state.reward_choices()
	_check(state.reward_pending() and choices.size() == RunState.REWARD_CHOICES, "victory offers %d reward cards" % RunState.REWARD_CHOICES)
	var ids := {}
	for card in choices:
		ids[card.id] = true
	_check(ids.size() == choices.size(), "reward cards are distinct")
	_check(state.reward_choices() == choices, "asking again does not re-roll the choices")
	var deck_before := state.deck.size()
	var stranger := CardData.make(&"not_offered", "Nope", 1, [CardEffect.make(CardEffect.Kind.DAMAGE, 1)])
	_check(not state.resolve_reward(stranger), "a card that was not offered is rejected")
	_check(state.reward_pending() and state.deck.size() == deck_before and state.stop_index == 1, "rejected reward changes nothing")
	_check(state.resolve_reward(choices[0]), "an offered card is accepted")
	_check(state.deck.size() == deck_before + 1 and state.deck.back() == choices[0], "taken reward is added to the deck")
	_check(not state.reward_pending() and state.stop_index == 2, "taking the reward moves to the next stop")
	_check(not state.resolve_reward(null), "no reward to resolve when none is pending")

	var skipper := _at_first_fight(5)
	skipper.complete_combat(true)
	var size := skipper.deck.size()
	_check(skipper.resolve_reward(null) and skipper.deck.size() == size and skipper.stop_index == 2, "skipping adds nothing and moves on")


## Rolls a reward on a fresh run's pending state and returns the offered ids.
func _offer_ids(state: RunState) -> Array:
	var ids: Array = []
	for card in state.reward_choices():
		ids.append(card.id)
	return ids


func _test_reward_memory_and_skip_gold() -> void:
	# No card repeats across successive rewards while the pool can supply fresh ones, and the
	# whole sequence is the same for the same seed.
	for id in StarterContent.character_ids():
		var state := RunState.new(77, id)
		var seen := {}
		var repeats := 0
		var sequence: Array = []
		for roll in 3:
			state._roll_rewards()
			var offer := _offer_ids(state)
			sequence.append(offer)
			for card_id in offer:
				if seen.has(card_id):
					repeats += 1
				seen[card_id] = true
		_check(repeats == 0, "%s: three successive rewards share no card" % id)
		_check(state.offered_ids.size() == seen.size(), "%s: every shown card is remembered" % id)
		var again := RunState.new(77, id)
		var again_sequence: Array = []
		for roll in 3:
			again._roll_rewards()
			again_sequence.append(_offer_ids(again))
		_check(sequence == again_sequence, "%s: the reward sequence is deterministic per seed" % id)

	# A card held COPY_CAP times is not offered while others are available.
	var capped := RunState.new(5)
	var pool := StarterContent.reward_pool(capped.character.id)
	var held: CardData = null
	for card in pool:
		if card.character != &"":
			held = card
			break
	for i in RunState.COPY_CAP:
		capped.deck.append(held)
	var cap_ok := true
	for roll in 12:
		capped.offered_ids.clear()
		capped._roll_rewards()
		cap_ok = cap_ok and not _offer_ids(capped).has(held.id)
	_check(cap_ok, "a card held COPY_CAP times is never offered")

	# Small pool: everything already offered is let back in, then the copy cap is relaxed,
	# and the offer is never empty.
	var small := RunState.new(9)
	for card in StarterContent.reward_pool(small.character.id):
		small.offered_ids.append(card.id)
	small._roll_rewards()
	_check(small.reward_choices().size() == RunState.REWARD_CHOICES, "when every card was offered before, the offer is still full")
	var tight := RunState.new(9)
	var distinct := {}
	for card in StarterContent.reward_pool(tight.character.id):
		distinct[card.id] = card
	for card_id in distinct:
		tight.offered_ids.append(card_id)
		for i in RunState.COPY_CAP:
			tight.deck.append(distinct[card_id])
	tight._roll_rewards()
	_check(tight.reward_choices().size() == RunState.REWARD_CHOICES, "when every card is also at the copy cap, the offer is still full")

	# Skipping pays SKIP_GOLD on top of the win gold, adds nothing and advances; taking pays none.
	var skipper := _at_first_fight(5)
	skipper.complete_combat(true)
	var gold_before := skipper.gold
	var size := skipper.deck.size()
	_check(skipper.resolve_reward(null), "skip is accepted")
	_check(skipper.gold == gold_before + RunState.SKIP_GOLD and skipper.deck.size() == size and skipper.stop_index == 2, "skipping pays SKIP_GOLD, adds nothing and advances")
	var taker := _at_first_fight(5)
	taker.complete_combat(true)
	var taker_gold := taker.gold
	taker.resolve_reward(taker.reward_choices()[0])
	_check(taker.gold == taker_gold, "taking a card pays no skip gold")
	_check(not skipper.resolve_reward(null) and skipper.gold == gold_before + RunState.SKIP_GOLD, "a second skip pays nothing")


## The once-per-run free Heal and Remove at a reward: effects, rejections, no skip gold, advance.
func _test_reward_alternatives() -> void:
	# Nothing pending: both rejected and nothing changes.
	var idle := _at_first_fight(11)
	idle.player.hp = 10
	var idle_deck := idle.deck.size()
	_check(not idle.resolve_reward_heal() and not idle.resolve_reward_remove(idle.deck[0]), "alternatives are rejected with no reward pending")
	_check(idle.player.hp == 10 and idle.deck.size() == idle_deck and not idle.reward_heal_used and not idle.reward_remove_used, "a rejected alternative changes nothing")

	# Heal: restores REWARD_HEAL, pays no skip gold, advances, once only.
	var healer := _at_first_fight(11)
	healer.complete_combat(true)
	healer.player.hp = healer.player.max_hp - 20
	var gold := healer.gold
	var offered := healer.offered_ids.size()
	_check(healer.resolve_reward_heal(), "heal is accepted")
	_check(healer.player.hp == healer.player.max_hp - 20 + RunState.REWARD_HEAL, "heal restores REWARD_HEAL HP")
	_check(healer.gold == gold and healer.stop_index == 2 and not healer.reward_pending() and healer.deck.size() == idle_deck, "heal pays no skip gold, adds no card and advances")
	_check(healer.reward_heal_used and healer.offered_ids.size() == offered, "heal is marked used")
	healer.complete_combat(true)  # stop 2 is a combat stop too
	healer.player.hp = 5
	_check(not healer.resolve_reward_heal() and healer.player.hp == 5 and healer.reward_pending(), "a second heal is rejected and the reward stays pending")
	_check(healer.resolve_reward(null), "the pending reward can still be resolved normally")

	# Heal never overheals and is rejected at full HP (the reward stays pending).
	var capped := _at_first_fight(12)
	capped.complete_combat(true)
	capped.player.hp = capped.player.max_hp - 5
	capped.resolve_reward_heal()
	_check(capped.player.hp == capped.player.max_hp, "heal is capped at max HP")
	var full := _at_first_fight(12)
	full.complete_combat(true)
	_check(not full.resolve_reward_heal() and full.reward_pending() and not full.reward_heal_used, "heal is rejected at full HP and stays unused")

	# Remove: deletes exactly one copy, pays no skip gold, advances, once only.
	var remover := _at_first_fight(13)
	remover.complete_combat(true)
	var target := remover.deck[0]
	var copies := remover.deck.count(target)
	gold = remover.gold
	var stranger := CardData.make(&"not_in_deck", "Nope", 1, [CardEffect.make(CardEffect.Kind.DAMAGE, 1)])
	_check(not remover.resolve_reward_remove(stranger) and remover.reward_pending() and not remover.reward_remove_used, "removing a card that is not in the deck is rejected")
	var size := remover.deck.size()
	_check(remover.resolve_reward_remove(target), "remove is accepted")
	_check(remover.deck.size() == size - 1 and remover.deck.count(target) == copies - 1, "remove deletes exactly one copy")
	_check(remover.gold == gold and remover.stop_index == 2 and not remover.reward_pending() and remover.reward_remove_used, "remove pays no skip gold, advances and is marked used")
	remover.complete_combat(true)
	_check(not remover.resolve_reward_remove(remover.deck[0]) and remover.deck.size() == size - 1 and remover.reward_pending(), "a second remove is rejected")

	# The deck is never emptied (the vendor's rule).
	var lone := _at_first_fight(14)
	lone.complete_combat(true)
	lone.deck.assign([lone.deck[0]])
	_check(not lone.resolve_reward_remove(lone.deck[0]) and lone.deck.size() == 1 and lone.reward_pending(), "the last card cannot be removed")

	# After the run ends, neither works.
	var dead := _at_first_fight(15)
	dead.complete_combat(false)
	_check(not dead.resolve_reward_heal() and not dead.resolve_reward_remove(dead.deck[0]), "no alternative after the run finished")


func _test_rest() -> void:
	var state := _at_first_fight(6)
	_check(state.rest() == -1 and state.stop_index == 1, "rest does nothing at a combat stop")
	_win_and_skip(state)
	_win_and_skip(state)
	state.player.take_damage(40)
	var hp_before := state.player.hp
	_check(state.rest() == RunState.REST_HEAL and state.player.hp == hp_before + RunState.REST_HEAL, "rest heals and reports HP restored")
	_check(state.stop_index == 4, "rest moves to the next stop")

	var full := _at_first_fight(6)
	_win_and_skip(full)
	_win_and_skip(full)
	_check(full.rest() == 0 and full.player.hp == full.player.max_hp, "rest at full HP restores nothing and never overheals")


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
	for character_id in [&"deserter", &"pickpocket", &"medium"]:
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


func _test_full_run_escapes() -> void:
	var state := RunState.new(7)
	var guard := 0
	while not state.finished and guard < 50:
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
	_check(state.finished and state.escaped and state.stop_index == state.stops.size(), "winning every fight reaches the end and escapes")
	_check(state.current_stop() == null, "no current stop after the run is finished")


func _test_seed_determinism() -> void:
	var a := _at_first_fight(99)
	var b := _at_first_fight(99)
	var fight_a := a.start_combat()
	var fight_b := b.start_combat()
	var same_enemies := fight_a != null and fight_b != null and fight_a.enemies.size() == fight_b.enemies.size()
	if same_enemies:
		for i in fight_a.enemies.size():
			same_enemies = same_enemies and fight_a.enemies[i].display_name == fight_b.enemies[i].display_name
	_check(same_enemies, "same seed builds the same first fight")
	if fight_a != null:
		fight_a.abandon()
	if fight_b != null:
		fight_b.abandon()
	a.complete_combat(true)
	b.complete_combat(true)
	var ids_a: Array = a.reward_choices().map(func(c: CardData) -> StringName: return c.id)
	var ids_b: Array = b.reward_choices().map(func(c: CardData) -> StringName: return c.id)
	_check(ids_a == ids_b, "same seed offers the same rewards")


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


func _test_gold_from_wins() -> void:
	var state := _at_first_fight(11)
	_check(state.gold == 0, "a run starts with no gold")
	state.complete_combat(true)
	_check(state.gold == Vendor.gold_for_win(1), "a won solo fight pays its gold")
	state.resolve_reward(null)
	state.complete_combat(true)
	_check(state.gold == Vendor.gold_for_win(1) + RunState.SKIP_GOLD + Vendor.gold_for_win(2), "gold accumulates across wins (the skip in between paid SKIP_GOLD)")
	var loser := _at_first_fight(11)
	loser.complete_combat(false)
	_check(loser.gold == 0, "a lost fight pays nothing")


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


# These misuse the API on purpose; the push_error output is expected here.
func _test_complete_combat_preconditions() -> void:
	var state := _at_first_fight(21)
	state.complete_combat(true)
	var gold := state.gold
	state.complete_combat(true)
	_check(state.gold == gold, "a second victory while the reward is pending pays nothing")
	state.complete_combat(false)
	_check(not state.finished and state.reward_pending(), "a defeat cannot be recorded while a reward is pending")

	var story := RunState.new(22)
	story.complete_combat(true)
	_check(story.gold == 0 and not story.reward_pending() and story.stop_index == 0, "complete_combat at a story stop changes nothing")

	var rest_stop := _at_first_fight(23)
	_win_and_skip(rest_stop)
	_win_and_skip(rest_stop)
	var hp := rest_stop.player.hp
	var gold_at_rest := rest_stop.gold
	_check(rest_stop.current_stop().type == RunState.StopType.REST, "setup: at the rest stop")
	rest_stop.complete_combat(true)
	_check(rest_stop.gold == gold_at_rest and not rest_stop.reward_pending() and rest_stop.stop_index == 3, "a victory cannot be recorded at a rest stop (the rest cannot be skipped)")
	_check(rest_stop.player.hp == hp, "rest stop untouched")

	var dead := _at_first_fight(24)
	dead.complete_combat(false)
	dead.complete_combat(true)
	_check(dead.finished and not dead.escaped and not dead.reward_pending() and dead.gold == 0, "nothing can be recorded after a defeat")
	_check(not dead.resolve_reward(null), "no reward can be resolved after a defeat")

	var winner := RunState.new(25)
	var guard := 0
	while not winner.finished and guard < 50:
		guard += 1
		match winner.current_stop().type:
			RunState.StopType.COMBAT:
				_win_and_skip(winner)
			RunState.StopType.STORY:
				winner.read_story()
			RunState.StopType.VENDOR:
				winner.leave_vendor()
			_:
				winner.rest()
	var gold_done := winner.gold
	_check(winner.finished and winner.escaped, "setup: an escaped run")
	winner.complete_combat(false)
	winner.complete_combat(true)
	_check(winner.escaped and winner.gold == gold_done and winner.stop_index == winner.stops.size() and not winner.reward_pending(), "a finished run cannot be rewritten or pushed past the line")
	_check(not winner.resolve_reward(null), "no reward after the run finished")


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


func _test_start_combat_twice_releases_first() -> void:
	var state := _at_first_fight(27)
	var first := state.start_combat()
	_check(state.player.changed.get_connections().is_empty(), "an unstarted fight holds no link to the player")
	first.start()
	_check(state.player.changed.get_connections().size() == 1, "setup: the started fight is linked to the player")
	var second := state.start_combat()
	_check(first != null and second != null and first != second, "asking again builds a new fight")
	_check(first.phase == Combat.Phase.ENDED, "the previous fight is abandoned")
	_check(state.player.changed.get_connections().is_empty(), "the abandoned fight released its link and the new one is not started yet")
	second.start()
	_check(state.player.changed.get_connections().size() == 1, "only the current started fight stays linked to the player")
	second.abandon()
	_check(state.player.changed.get_connections().is_empty(), "abandoning the current fight releases the link")


func _test_rewards_rolled_eagerly_and_copied() -> void:
	var shown := _at_first_fight(31)
	var skipped := _at_first_fight(31)
	shown.complete_combat(true)
	shown.reward_choices()
	shown.resolve_reward(null)
	skipped.complete_combat(true)
	skipped.resolve_reward(null)
	var fight_shown := shown.start_combat()
	var fight_skipped := skipped.start_combat()
	var same := fight_shown != null and fight_skipped != null and fight_shown.enemies.size() == fight_skipped.enemies.size()
	if same:
		for i in fight_shown.enemies.size():
			same = same and fight_shown.enemies[i].display_name == fight_skipped.enemies[i].display_name
	_check(same, "a seed plays out the same whether or not the reward screen was shown")
	if fight_shown != null:
		fight_shown.abandon()
	if fight_skipped != null:
		fight_skipped.abandon()

	var state := _at_first_fight(32)
	state.complete_combat(true)
	var choices := state.reward_choices()
	choices.clear()
	_check(state.reward_choices().size() == RunState.REWARD_CHOICES, "mutating the returned choices does not change the offer")


func _test_survivors_from_mutation_audit() -> void:
	# The reward offer is cleared once resolved, so the next victory cannot show stale cards.
	var rewards := _at_first_fight(41)
	rewards.complete_combat(true)
	var first := rewards.reward_choices()
	_check(first.size() == RunState.REWARD_CHOICES, "setup: a reward was offered")
	rewards.resolve_reward(first[0])
	_check(rewards.reward_choices().is_empty(), "no reward choices are left after resolving")
	rewards.complete_combat(true)
	_check(rewards.reward_choices().size() == RunState.REWARD_CHOICES, "the next victory offers a fresh set")

	# A vendor heal spends exactly its price from the run's gold.
	var shop := _at_vendor(42)
	shop.gold = 100
	shop.player.take_damage(30)
	var healed := shop.vendor_buy_heal()
	_check(healed.ok and shop.gold == 100 - Vendor.HEAL_PRICE, "a vendor heal costs exactly HEAL_PRICE of the run's gold")

	# Rest heals min(REST_HEAL, missing HP), exactly.
	var resting := _at_first_fight(43)
	_win_and_skip(resting)
	_win_and_skip(resting)
	resting.player.take_damage(10)
	_check(resting.rest() == 10, "rest heals only the missing HP when that is less than REST_HEAL")
	var deep := _at_first_fight(44)
	_win_and_skip(deep)
	_win_and_skip(deep)
	deep.player.take_damage(RunState.REST_HEAL + 10)
	_check(deep.rest() == RunState.REST_HEAL, "rest heals exactly REST_HEAL when more is missing")

	# The line's exact shape, so a silent edit to it is noticed.
	var shape := []
	for stop in RunState.new(1).stops:
		shape.append([stop.type, stop.enemy_count, stop.beat_index, stop.boss, stop.mid_boss, stop.tier])
	var story := RunState.StopType.STORY
	var combat := RunState.StopType.COMBAT
	var rest := RunState.StopType.REST
	var vendor := RunState.StopType.VENDOR
	var want := [
		[story, 0, 0, false, false, 0], [combat, 1, 0, false, false, 0], [combat, 2, 0, false, false, 0],
		[rest, 0, 0, false, false, 0], [combat, 2, 0, false, false, 0], [vendor, 0, 0, false, false, 0],
		[combat, 2, 0, false, false, 0], [story, 0, 1, false, false, 0], [rest, 0, 0, false, false, 0],
		[combat, 1, 0, false, true, 0], [story, 0, 2, false, false, 1], [rest, 0, 0, false, false, 1],
		[combat, 2, 0, false, false, 1], [combat, 3, 0, false, false, 1], [vendor, 0, 0, false, false, 1],
		[rest, 0, 0, false, false, 1], [combat, 2, 0, false, false, 1], [combat, 3, 0, false, false, 1],
		[vendor, 0, 0, false, false, 1], [story, 0, 3, false, false, 1], [combat, 1, 0, true, false, 1],
	]
	_check(shape == want, "the default line has the documented shape: %s" % str(shape))


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
	_check(fight != null and fight.enemies.size() == 1 and fight.enemies[0].display_name == "Eraser", "the boss stop fights the Conductor alone")
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
	_check(fight != null and fight.enemies.size() == 1 and fight.enemies[0].display_name == "Bellkeeper", "the mid-boss stop fights the Brakeman alone")
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


func _test_progressive_difficulty() -> void:
	# The ramp is exact and deterministic.
	_check(is_equal_approx(StarterContent.ramp_factor(0), 1.0), "fight 0 is unramped")
	_check(StarterContent.ramp_factor(7) > StarterContent.ramp_factor(3) and StarterContent.ramp_factor(3) > 1.0, "the ramp grows with the fight number")
	_check(is_equal_approx(StarterContent.ramp_factor(-4), 1.0), "a negative fight number counts as 0")
	# A later stop's pack has at least the HP and attack of an earlier one for the same seed.
	var early_hp := 0
	var late_hp := 0
	var early_hit := 0
	var late_hit := 0
	for rng_seed in 40:
		var a := RandomNumberGenerator.new()
		a.seed = rng_seed
		var b := RandomNumberGenerator.new()
		b.seed = rng_seed
		for enemy in StarterContent.varied_encounter(3, a, 0, 0):
			early_hp += enemy.max_hp
			for intent in enemy.intents:
				early_hit += intent.amount if intent.kind == CardEffect.Kind.DAMAGE else 0
		for enemy in StarterContent.varied_encounter(3, b, 0, 7):
			late_hp += enemy.max_hp
			for intent in enemy.intents:
				late_hit += intent.amount if intent.kind == CardEffect.Kind.DAMAGE else 0
	_check(late_hp > early_hp and late_hit > early_hit, "fight 7 enemies have more HP and hit harder than fight 0 for the same seeds")
	# The shared resources are never touched by scaling.
	var template := load(StarterContent.COLOSSUS_PATH) as EnemyData
	var hp_before := template.max_hp
	var damage_before: int = template.intents[1].amount
	var scaled := StarterContent.scaled(template.duplicate(true) as EnemyData, 1.5)
	_check(scaled.max_hp == roundi(hp_before * 1.5) and scaled.intents[1].amount == roundi(damage_before * 1.5), "scaled multiplies HP and damage, rounded")
	_check(scaled.intents[0].kind == CardEffect.Kind.BLOCK and scaled.intents[0].amount == template.intents[0].amount, "scaled leaves Block alone")
	_check(template.max_hp == hp_before and template.intents[1].amount == damage_before, "scaling leaves the shared resource unchanged")
	# The stop numbers feed the encounter: the same seed at the same stop gives the same ramped pack.
	var run_a := RunState.new(5)
	var run_b := RunState.new(5)
	run_a.stop_index = 16
	run_b.stop_index = 16
	var fa := run_a.start_combat()
	var fb := run_b.start_combat()
	var same := fa != null and fb != null and fa.enemies.size() == fb.enemies.size()
	if same:
		for i in fa.enemies.size():
			same = same and fa.enemies[i].max_hp == fb.enemies[i].max_hp and fa.enemies[i].display_name == fb.enemies[i].display_name
	_check(same, "a seeded late fight is reproducible")


## Each character starts with its own HP, name and deck, and is offered only neutral and own cards.
func _test_characters() -> void:
	for id in StarterContent.character_ids():
		var state := RunState.new(7, id)
		var character := StarterContent.character(id)
		_check(state.character.id == id, "%s: the run knows its character" % id)
		_check(state.player.max_hp == character.max_hp and state.player.hp == character.max_hp, "%s starts at its own full HP" % id)
		_check(state.player.display_name == character.display_name, "%s: the player is named after the character" % id)
		_check(state.deck.size() == 10, "%s starts with 10 cards" % id)
		state.deck.append(character.starting_deck[0])
		_check(character.starting_deck.size() == 10, "%s: editing the run deck leaves the character resource alone" % id)
		# Every reward offer, over many seeds and wins, holds only neutral or own cards.
		var class_seen := 0
		for seed_value in 40:
			var run := RunState.new(seed_value, id)
			run.read_story()
			run.start_combat().abandon()
			run.complete_combat(true)
			var choices := run.reward_choices()
			_check(choices.size() == RunState.REWARD_CHOICES, "%s: a reward offers %d cards" % [id, RunState.REWARD_CHOICES])
			var distinct := {}
			var own := 0
			for card in choices:
				distinct[card.id] = true
				_check(card.character == &"" or card.character == id, "%s: reward %s is neutral or its own" % [id, card.id])
				if card.character == id:
					own += 1
			_check(distinct.size() == choices.size(), "%s: a reward offers distinct cards" % id)
			_check(own == mini(RunState.REWARD_CLASS_CHOICES, _class_card_count(id)), "%s: a reward holds %d of its own cards" % [id, mini(RunState.REWARD_CLASS_CHOICES, _class_card_count(id))])
			class_seen += own
		_check((class_seen > 0) == (_class_card_count(id) > 0), "%s: class cards are offered exactly when the class has some" % id)
	# An unknown character falls back to a constructible run (the cause is logged).
	var fallback := RunState.new(1, &"nobody")
	_check(fallback.character != null and not fallback.finished, "an unknown character still builds a run")


func _class_card_count(id: StringName) -> int:
	var count := 0
	for card in StarterContent.reward_pool(id):
		if card.character == id:
			count += 1
	return count
