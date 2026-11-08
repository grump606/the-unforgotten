extends "res://tests/smart_policy_support.gd"
## SmartPolicy in a fight: killing blows, Expose first, keyword plays and discards, queued choices.
## Discovered by run_tests.gd.


func run() -> int:
	_failures = 0
	_test_takes_the_killing_blow()
	_test_exposes_before_damage()
	_test_keyword_discards()
	_test_fading_played_before_end_of_turn()
	_test_dormant_never_played()
	_test_surge_spends_all_energy()
	_test_shaken_timing_and_self_cost()
	_test_glimpse_choice_resolved()
	_test_recall_choice_resolved()
	_test_two_queued_choices()
	_test_dormant_hand_discards()
	_test_add_dread_never_played()
	_test_surge_goes_last()
	return _failures


func _test_takes_the_killing_blow() -> void:
	var small := _card(&"small", 1, CardEffect.Kind.DAMAGE, 4)
	var enemies: Array[EnemyData] = [_enemy(30, 3), _enemy(4, 3)]
	var combat := _combat([small], enemies)
	_check(SmartPolicy.play_turn(combat), "smart policy plays a turn")
	_check(combat.enemies[1].is_dead() and combat.enemies[0].hp == 30, "the killing blow goes to the enemy it kills")


func _test_exposes_before_damage() -> void:
	var mark := _card(&"mark", 1, CardEffect.Kind.EXPOSE, 2)
	var hit := _card(&"hit", 1, CardEffect.Kind.DAMAGE, 8)
	var enemies: Array[EnemyData] = [_enemy(40, 1)]
	var combat := _combat([hit, mark], enemies)
	SmartPolicy.play_turn(combat)
	# Expose first: 8 x 3/2 = 12 damage; damage first would leave the Expose with nothing to boost.
	_check(combat.enemies[0].hp == 28, "expose is played before the damage card (hp %d)" % combat.enemies[0].hp)


func _test_keyword_discards() -> void:
	# Weak anchor and fading cards would be the obvious discards, but they cannot be discarded.
	var hand: Array[CardData] = []
	for i in 6:
		hand.append(_card(StringName("n%d" % i), 2, CardEffect.Kind.DAMAGE, 6))
	var anchor := _keyword_card(&"anchor", "anchor", 3, CardEffect.Kind.BLOCK, 1)
	var fading := _keyword_card(&"fading", "fading", 3, CardEffect.Kind.BLOCK, 1)
	hand.append(anchor)
	hand.append(fading)
	var combat := _combat_with_hand(hand)
	combat.energy = 0
	for use_smart in [false, true]:
		var indices: Array[int] = SmartPolicy.discards_for(combat) if use_smart else SimPolicy.discards_for(combat)
		_check(indices.size() == 1, "one counted card over the limit means one discard (%d)" % indices.size())
		_check(not indices.has(6) and not indices.has(7), "an anchor or fading card is never offered for discard")
		_check(combat.is_valid_discard(indices), "the keyword-aware discard is valid")
	_check(combat.end_player_turn(SmartPolicy.discards_for(combat)), "the turn ends with the discard the policy chose")
	_check(combat.piles.hand.has(anchor), "the anchor card stays in hand")
	# Only anchor and fading cards in hand: nothing to discard.
	var only: Array[CardData] = [anchor, fading]
	var combat2 := _combat_with_hand(only)
	_check(SmartPolicy.discards_for(combat2).is_empty() and SimPolicy.discards_for(combat2).is_empty(), "no counted cards, no discards")


func _test_fading_played_before_end_of_turn() -> void:
	for use_smart in [false, true]:
		var fading := _keyword_card(&"fade", "fading", 1, CardEffect.Kind.DAMAGE, 5)
		var hand: Array[CardData] = [fading]
		var combat := _combat_with_hand(hand)
		_check(_play(combat, use_smart), "turn with a fading card is legal (smart %s)" % use_smart)
		_check(combat.enemies[0].hp == 35, "the fading card is played before the turn ends (smart %s, hp %d)" % [use_smart, combat.enemies[0].hp])
		_check(not combat.piles.forgotten.has(fading), "a played fading card is not forgotten")
	# An unaffordable fading card is simply lost and the turn still ends.
	var costly := _keyword_card(&"costly", "fading", 9, CardEffect.Kind.DAMAGE, 5)
	var hand2: Array[CardData] = [costly]
	var combat2 := _combat_with_hand(hand2)
	_check(SmartPolicy.play_turn(combat2) and combat2.piles.forgotten.has(costly), "an unaffordable fading card is forgotten at turn end")


func _test_dormant_never_played() -> void:
	for use_smart in [false, true]:
		var dormant := _keyword_card(&"dorm", "dormant", 0, CardEffect.Kind.DAMAGE, 9)
		var hand: Array[CardData] = [dormant]
		var combat := _combat_with_hand(hand)
		_check(_play(combat, use_smart), "turn with only a dormant card is legal (smart %s)" % use_smart)
		_check(combat.enemies[0].hp == 40, "a dormant card is never played (smart %s)" % use_smart)
	var weights := {"damage": 1.0, "block": 1.0}
	_check(SmartPolicy.card_score(_keyword_card(&"d", "dormant"), weights) < SmartPolicy.card_score(_card(&"c", 2, CardEffect.Kind.BLOCK, 1), weights), "a dormant card scores below any live card")


func _test_surge_spends_all_energy() -> void:
	for use_smart in [false, true]:
		var hand: Array[CardData] = [_surge_card(3, 1)]
		var combat := _combat_with_hand(hand)
		var spent := combat.energy
		_check(_play(combat, use_smart), "surge turn is legal (smart %s)" % use_smart)
		_check(combat.enemies[0].hp == 40 - 3 * spent, "a surge card is played with all %d energy (smart %s, hp %d)" % [spent, use_smart, combat.enemies[0].hp])
		# At 0 energy a scaling surge does nothing, so it is held back.
		var hand0: Array[CardData] = [_surge_card(3, 1)]
		var combat0 := _combat_with_hand(hand0)
		combat0.energy = 0
		_play(combat0, use_smart)
		_check(combat0.enemies[0].hp == 40, "a surge card is not played at 0 energy (smart %s)" % use_smart)
	# Surge is worth more with more energy.
	var hand3: Array[CardData] = [_surge_card(3, 1)]
	var combat3 := _combat_with_hand(hand3)
	combat3.energy = 1
	var low := SmartPolicy._play_value(combat3, 0, 0)
	combat3.energy = 3
	var high := SmartPolicy._play_value(combat3, 0, 0)
	_check(high > low, "surge value scales with energy (%f vs %f)" % [low, high])


## Shaken on an enemy is played before a big hit but not onto a nearly dead enemy; a self-Shaken is never
## played for nothing.
func _test_shaken_timing_and_self_cost() -> void:
	var shake := _one(CardEffect.Kind.SHAKEN, 2, CardData.TargetMode.SINGLE_ENEMY)
	var enemies: Array[EnemyData] = [_enemy(40, 14)]
	var big := _combat([shake], enemies)
	_check(SmartPolicy._play_value(big, 0, 0) > 0.0, "Shaken is worth playing before a big hit")
	_check(_play(big, true) and big.enemies[0].status_turns(Combatant.Status.SHAKEN) > 0, "the smart bot plays Shaken on a big attacker")
	var big_g := _combat([shake], enemies)
	_check(_play(big_g, false) and big_g.enemies[0].status_turns(Combatant.Status.SHAKEN) > 0, "the greedy bot plays Shaken on a big attacker")
	var hit := _card(&"hit", 1, CardEffect.Kind.DAMAGE, 6)
	var near_dead := _combat_with_hand([shake, hit] as Array[CardData], 5)
	_check(SmartPolicy._play_value(near_dead, 0, 0) == 0.0, "Shaken is worth nothing on an enemy the hand kills")
	_check(_play(near_dead, true) and near_dead.enemies[0].is_dead() and near_dead.enemies[0].status_turns(Combatant.Status.SHAKEN) == 0, "the smart bot kills instead of shaking a nearly dead enemy")
	var block_intent: Array[CardEffect] = [CardEffect.make(CardEffect.Kind.BLOCK, 3)]
	var passive_enemy: Array[EnemyData] = [EnemyData.make("e", 30, block_intent)]
	var passive := _combat([shake], passive_enemy)
	_check(SmartPolicy._play_value(passive, 0, 0) == 0.0, "Shaken is worth nothing on an enemy with no attack")
	# Self-targeted Shaken / Frayed: a pure cost.
	for kind in [CardEffect.Kind.SHAKEN, CardEffect.Kind.FRAYED]:
		var self_cost := _one(kind, 1, CardData.TargetMode.SELF)
		for use_smart in [false, true]:
			var combat := _combat([self_cost], enemies)
			_check(SmartPolicy._play_value(combat, 0, -1) < 0.0, "a self-targeted debuff has negative value")
			_check(_play(combat, use_smart), "turn with only a self-debuff card ends")
			_check(combat.player.status_turns(Combatant.Status.SHAKEN) == 0 and combat.player.status_turns(Combatant.Status.FRAYED) == 0, "the bot never plays a self-debuff for nothing (smart %s)" % use_smart)


func _count_of(combat: Combat, card: CardData) -> int:
	var total := 0
	for pile in [combat.piles.hand, combat.piles.draw_pile, combat.piles.discard_pile, combat.piles.forgotten]:
		total += pile.count(card)
	return total


func _resolve(combat: Combat, use_smart: bool) -> bool:
	return SmartPolicy.resolve_choice(combat) if use_smart else SimPolicy.resolve_choice(combat)


## Both bots answer a Glimpse by binning Dormant cards and below-average ones, keeping the good cards, and
## the fight carries on.
func _test_glimpse_choice_resolved() -> void:
	for use_smart in [false, true]:
		var dread := _dread()
		var good := _strike(9)
		var good2 := _strike(9)
		var glimpse := _custom(0, [_fx(CardEffect.Kind.GLIMPSE, 3)], CardData.TargetMode.SELF)
		var combat := _combat_with_hand([glimpse])
		# Top of the draw pile is the end of the array: Dread is seen first.
		combat.piles.draw_pile.assign([good, good2, dread])
		_check(combat.play_card(0, -1) and combat.has_choice(), "Glimpse opens a choice (smart %s)" % use_smart)
		_check(_resolve(combat, use_smart), "the bot resolves the Glimpse (smart %s)" % use_smart)
		_check(combat.phase == Combat.Phase.PLAYER_TURN and not combat.has_choice(), "the turn resumes after the Glimpse (smart %s)" % use_smart)
		_check(not combat.piles.draw_pile.has(dread) and combat.piles.discard_pile.has(dread), "Dread is discarded from the draw pile (smart %s)" % use_smart)
		_check(combat.piles.draw_pile.size() == 2, "the good cards stay on the draw pile (smart %s)" % use_smart)
		_check(_run_fight(combat, use_smart, 80) and combat.phase == Combat.Phase.ENDED, "the fight continues to the end after a Glimpse (smart %s)" % use_smart)


## Both bots answer a Recall by returning the best Forgotten card.
func _test_recall_choice_resolved() -> void:
	for use_smart in [false, true]:
		var weak := _card(&"weak", 1, CardEffect.Kind.BLOCK, 2)
		var best := _strike(12)
		var other := _card(&"other", 1, CardEffect.Kind.BLOCK, 4)
		var recall := _custom(0, [_fx(CardEffect.Kind.RECALL, 1)], CardData.TargetMode.SELF)
		var combat := _combat_with_hand([recall])
		combat.piles.forgotten.assign([weak, best, other])
		_check(combat.play_card(0, -1) and combat.has_choice(), "Recall opens a choice (smart %s)" % use_smart)
		_check(_resolve(combat, use_smart), "the bot resolves the Recall (smart %s)" % use_smart)
		_check(combat.piles.hand.has(best) and combat.piles.forgotten.size() == 2, "the best Forgotten card is returned (smart %s)" % use_smart)
		_check(_run_fight(combat, use_smart, 80) and combat.phase == Combat.Phase.ENDED, "the fight continues to the end after a Recall (smart %s)" % use_smart)


## A card that queues a Glimpse and a Recall leaves two choices; no bot stalls on them.
func _test_two_queued_choices() -> void:
	for use_smart in [false, true]:
		var both := _custom(0, [_fx(CardEffect.Kind.GLIMPSE, 2), _fx(CardEffect.Kind.RECALL, 1)], CardData.TargetMode.SELF)
		var combat := _combat_with_hand([both])
		combat.piles.draw_pile.assign([_strike(5), _dread()])
		combat.piles.forgotten.assign([_strike(7)])
		_check(combat.play_card(0, -1) and combat.has_choice(), "the first of two choices opens (smart %s)" % use_smart)
		_check(_resolve(combat, use_smart) and combat.has_choice(), "the second choice opens after the first (smart %s)" % use_smart)
		var cleared := SmartPolicy.resolve_choices(combat) if use_smart else SimPolicy.resolve_choices(combat)
		_check(cleared and not combat.has_choice() and combat.phase == Combat.Phase.PLAYER_TURN, "both choices are settled (smart %s)" % use_smart)
		# And through play_turn itself: the choices are met mid-turn and the turn still ends.
		var again := _custom(0, [_fx(CardEffect.Kind.GLIMPSE, 2), _fx(CardEffect.Kind.RECALL, 1)], CardData.TargetMode.SELF)
		var second := _combat_with_hand([again])
		second.piles.draw_pile.assign([_strike(5), _dread()])
		second.piles.forgotten.assign([_strike(7)])
		var turn_before := second.turn
		_check(_play(second, use_smart) and second.turn == turn_before + 1 and not second.has_choice(), "play_turn resolves queued choices and ends the turn (smart %s)" % use_smart)


## A hand of five playable cards and a Dread discards the Dread; a Murmur (Fading, not counted) is never offered.
func _test_dormant_hand_discards() -> void:
	var hand: Array[CardData] = []
	for i in 5:
		hand.append(_strike(6 + i))
	hand.append(_dread())
	hand.append(_murmur())
	var combat := _combat_with_hand(hand)
	var expected: Array[int] = [5]
	_check(SimPolicy.discards_for(combat) == expected, "greedy discards the Dread and not the Murmur")
	_check(SmartPolicy.discards_for(combat) == expected, "smart discards the Dread and not the Murmur")
	_check(not combat.can_discard_card(6), "a Murmur cannot be discarded")
	_check(not combat.can_play(5) and not combat.can_play(6), "Dread and Murmur are never playable")
	for use_smart in [false, true]:
		var fight := _combat_with_hand(hand.duplicate())
		_check(_run_fight(fight, use_smart, 80) and fight.phase == Combat.Phase.ENDED, "a hand with Dormant junk does not stall (smart %s)" % use_smart)


## No bot plays a card whose only effect is to add Dread to its own piles; a real card that adds a good one is worth it.
func _test_add_dread_never_played() -> void:
	var dread := _dread()
	for pile in [CardEffect.Pile.HAND, CardEffect.Pile.DRAW, CardEffect.Pile.DISCARD]:
		var adder := _custom(0, [CardEffect.make(CardEffect.Kind.ADD_CARD, 1, 0, 0, 1, false, false, dread, pile)], CardData.TargetMode.SELF)
		for use_smart in [false, true]:
			var combat := _combat_with_hand([adder], 400)
			combat.piles.draw_pile.clear()
			_check(_play(combat, use_smart), "a turn with an Add-Dread card is legal (smart %s)" % use_smart)
			_check(_count_of(combat, dread) == 0, "Add Dread to pile %d is never played (smart %s)" % [pile, use_smart])
	var gift := _custom(0, [CardEffect.make(CardEffect.Kind.ADD_CARD, 1, 0, 0, 1, false, false, _strike(9), CardEffect.Pile.HAND)], CardData.TargetMode.SELF)
	var combat2 := _combat_with_hand([gift])
	_check(SmartPolicy._play_value(combat2, 0, -1) > 0.0, "adding a good playable card to hand has positive value")
	var costly := _custom(0, [CardEffect.make(CardEffect.Kind.ADD_CARD, 1, 0, 0, 1, false, false, dread, CardEffect.Pile.HAND)], CardData.TargetMode.SELF)
	var combat3 := _combat_with_hand([costly])
	_check(SmartPolicy._play_value(combat3, 0, -1) < 0.0, "adding Dread to yourself has negative value")
	var weights := {"damage": 1.0, "block": 1.0}
	_check(SmartPolicy.card_score(costly, weights) < 0.0 and SmartPolicy.card_score(gift, weights) > 0.0, "card_score prices Add card by what it adds")
	var glimpse := _custom(0, [_fx(CardEffect.Kind.GLIMPSE, 3)], CardData.TargetMode.SELF)
	var empty := _combat_with_hand([glimpse])
	empty.piles.draw_pile.clear()
	_check(SmartPolicy._play_value(empty, 0, -1) == 0.0, "Glimpse with an empty draw pile is worth nothing")
	var recall := _custom(0, [_fx(CardEffect.Kind.RECALL, 1)], CardData.TargetMode.SELF)
	var none := _combat_with_hand([recall])
	_check(SmartPolicy._play_value(none, 0, -1) == 0.0, "Recall with an empty Forgotten pile is worth nothing")
	none.piles.forgotten.assign([_strike(9)])
	_check(SmartPolicy._play_value(none, 0, -1) > 0.0, "Recall with a good Forgotten card is worth something")


## A Surge goes after the cards that need fixed energy, so it spends only what is left.
func _test_surge_goes_last() -> void:
	var surge := _surge_card(4, 1)
	var strike := _strike(6)
	var combat := _combat_with_hand([surge, strike], 100)
	SmartPolicy.play_turn(combat)
	# 3 energy: Strike (1) first, then Surge with the 2 left: 6 + 4 x 2.
	_check(combat.enemies[0].hp == 100 - 6 - 8, "smart plays the Surge after the fixed-cost card (hp %d)" % combat.enemies[0].hp)
