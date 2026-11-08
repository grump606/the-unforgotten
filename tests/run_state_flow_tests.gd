extends "res://tests/run_state_support.gd"
## RunState basics: a fresh state, characters, the default line, combat hand-off, defeat, determinism, a full run.
## Discovered by run_tests.gd.


func run() -> int:
	_failures = 0
	_test_stop_type_values_match_painted_art()
	_test_fresh_state()
	_test_default_line()
	_test_start_combat_builds_fight_with_persistent_player()
	_test_start_combat_rejected_off_combat_stop()
	_test_defeat_ends_run()
	_test_full_run_escapes()
	_test_seed_determinism()
	_test_complete_combat_preconditions()
	_test_start_combat_twice_releases_first()
	_test_survivors_from_mutation_audit()
	_test_progressive_difficulty()
	_test_characters()
	return _failures


## PaintedArt.warm_for_stop matches on bare ints (no RunState dependency); pin them here.
func _test_stop_type_values_match_painted_art() -> void:
	_check(RunState.StopType.COMBAT == 0 and RunState.StopType.REST == 1 and RunState.StopType.STORY == 2 and RunState.StopType.VENDOR == 3, "StopType values match what PaintedArt.warm_for_stop assumes")


func _test_fresh_state() -> void:
	var state := RunState.new(1)
	_check(state.player.hp == state.character.max_hp and state.player.max_hp == state.character.max_hp, "run starts at full HP")
	_check(state.character.id == StarterContent.DEFAULT_CHARACTER_ID and state.deck.size() == state.character.starting_deck.size(), "run starts with the default character's deck")
	_check(not state.finished and state.stop_index == 0 and not state.reward_pending(), "run starts unfinished at stop 0")


func _test_default_line() -> void:
	var state := RunState.new(1)
	_check(state.stops.size() == 22, "default line has 22 stops")
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
			same_enemies = same_enemies and fight_a.enemies[i].data.id == fight_b.enemies[i].data.id
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

	# Rest heals to full, whatever is missing.
	var resting := _at_first_fight(43)
	_win_and_skip(resting)
	_win_and_skip(resting)
	resting.player.take_damage(10)
	_check(resting.rest() == 10 and resting.player.hp == resting.player.max_hp, "rest heals a small wound to full")
	var deep := _at_first_fight(44)
	_win_and_skip(deep)
	_win_and_skip(deep)
	deep.player.take_damage(deep.player.max_hp - 1)
	_check(deep.rest() == deep.player.max_hp - 1 and deep.player.hp == deep.player.max_hp, "rest heals a near-fatal wound to full")
	_check(deep.rest_heal_amount() == 0 and deep.rest_number() == 0, "off a rest stop there is nothing to heal")

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
		[vendor, 0, 0, false, false, 1], [rest, 0, 0, false, false, 1], [story, 0, 3, false, false, 1],
		[combat, 1, 0, true, false, 1],
	]
	_check(shape == want, "the default line has the documented shape: %s" % str(shape))


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
	var frayed_before: int = template.intents[0].amount
	var scaled := StarterContent.scaled(template.duplicate(true) as EnemyData, 1.5)
	_check(scaled.max_hp == roundi(hp_before * 1.5) and scaled.intents[1].amount == roundi(damage_before * 1.5), "scaled multiplies HP and damage, rounded")
	_check(scaled.intents[0].kind == CardEffect.Kind.FRAYED and scaled.intents[0].amount == frayed_before, "scaled leaves a status alone")
	_check(template.max_hp == hp_before and template.intents[1].amount == damage_before, "scaling leaves the shared resource unchanged")
	var conductor := load(StarterContent.CONDUCTOR_PATH) as EnemyData
	var triple_index := -1
	for i in conductor.intents.size():
		if conductor.intents[i].hits == 3:
			triple_index = i
	_check(triple_index >= 0 and StarterContent.scaled(conductor.duplicate(true) as EnemyData, 1.5).intents[triple_index].hits == 3, "scaling keeps a multi-hit attack's hit count")
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
			same = same and fa.enemies[i].max_hp == fb.enemies[i].max_hp and fa.enemies[i].data.id == fb.enemies[i].data.id
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
