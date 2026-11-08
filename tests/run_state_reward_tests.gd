extends "res://tests/run_state_support.gd"
## RunState rewards, gold and rests: offers, memory, alternatives, skip gold, rest and Remember.
## Discovered by run_tests.gd.


func run() -> int:
	_failures = 0
	_test_reward_flow()
	_test_reward_memory_and_skip_gold()
	_test_reward_alternatives()
	_test_rest()
	_test_gold_from_wins()
	_test_rewards_rolled_eagerly_and_copied()
	return _failures


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
	var missing := state.player.max_hp - hp_before
	_check(state.rest_heal_amount() == missing and state.rest_number() == 1, "the first rest says what it will heal")
	_check(state.rest() == missing and state.player.hp == state.player.max_hp, "rest heals to full and reports HP restored")
	_check(state.stop_index == 4, "rest moves to the next stop")

	var full := _at_first_fight(6)
	_win_and_skip(full)
	_win_and_skip(full)
	_check(full.rest() == 0 and full.player.hp == full.player.max_hp, "rest at full HP restores nothing and never overheals")


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
			same = same and fight_shown.enemies[i].data.id == fight_skipped.enemies[i].data.id
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
