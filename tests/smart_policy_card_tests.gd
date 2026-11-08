extends "res://tests/smart_policy_support.gd"
## SmartPolicy card valuation: what each effect kind and class card is worth, reward ranking, estimates.
## Discovered by run_tests.gd.


func run() -> int:
	_failures = 0
	_test_card_scoring_order()
	_test_reward_alternatives()
	_test_values_new_effects()
	_test_class_cards_are_played()
	_test_greedy_card_kinds()
	_test_multi_hit_scoring()
	_test_estimates_use_the_pipeline()
	_test_buffs_played_before_what_they_boost()
	_test_damage_per_forgotten_estimates()
	_test_glimpse_values_class_cards()
	_test_recall_judgement()
	_test_forgotten_not_wasted()
	_test_new_cards_are_scored_and_taken()
	return _failures


func _test_card_scoring_order() -> void:
	var run := RunState.new(1)
	var weak := _card(&"weak", 2, CardEffect.Kind.DAMAGE, 1)
	var strong := _card(&"strong", 1, CardEffect.Kind.DAMAGE, 30)
	var weights := SmartPolicy._weights(run.deck)
	_check(SmartPolicy.card_score(weak, weights) < SmartPolicy.card_score(strong, weights), "scoring ranks a stronger card higher")


## The smart bot heals when under half HP and removes its weakest card instead of skipping, once each.
func _test_reward_alternatives() -> void:
	var low := RunState.new(21)
	low.read_story()
	low.complete_combat(true)
	low.player.hp = low.player.max_hp / 2 - 1
	_check(SmartPolicy.take_reward(low) and low.reward_heal_used and not low.reward_remove_used and low.deck.size() == low.character.starting_deck.size(), "smart heals below half HP instead of taking a card")
	low.complete_combat(true)
	low.player.hp = 1
	_check(SmartPolicy.take_reward(low) and low.player.hp == 1, "smart does not heal twice")

	# Remove: a deck of strong cards plus one dud, offered nothing better than the average.
	var run := RunState.new(22)
	run.read_story()
	run.complete_combat(true)
	var strong := _card(&"strong", 1, CardEffect.Kind.DAMAGE, 30)
	var dud := _card(&"dud", 2, CardEffect.Kind.DAMAGE, 1)
	var deck: Array[CardData] = []
	for i in SmartPolicy.MIN_DECK:
		deck.append(strong)
	deck.append(dud)
	run.deck = deck
	run._reward_choices.assign([dud, dud, dud])
	_check(SmartPolicy.take_reward(run), "smart resolves the reward")
	_check(run.reward_remove_used and not run.reward_heal_used and not run.deck.has(dud) and run.deck.size() == SmartPolicy.MIN_DECK, "smart removes its weakest card when nothing offered beats the average")
	run.complete_combat(true)
	run.deck.append(dud)
	run._reward_choices.assign([dud, dud, dud])
	var gold := run.gold
	_check(SmartPolicy.take_reward(run) and run.deck.has(dud) and run.gold == gold + RunState.SKIP_GOLD, "with Remove spent it falls back to skipping")


func _combat_with_hp(hand_cards: Array[CardData], enemies: Array[EnemyData], player_hp: int) -> Combat:
	var combat := Combat.new(Combatant.new("p", 40, player_hp), hand_cards, enemies, 1)
	combat.start()
	return combat


## The smart policy values the Block-scaled, Haunt and HP-cost effects instead of ignoring them.
func _test_values_new_effects() -> void:
	# Block first, then the Block-scaled hit: it deals the Block it just gained.
	var block := _custom(1, [_fx(CardEffect.Kind.BLOCK, 8)], CardData.TargetMode.SELF)
	var bash := _custom(1, [_fx(CardEffect.Kind.DAMAGE_PER_BLOCK, 1)])
	var enemies: Array[EnemyData] = [_enemy(40, 1)]
	var combat := _combat([block, bash], enemies)
	SmartPolicy.play_turn(combat)
	_check(combat.enemies[0].hp == 32, "smart plays Block before a damage-from-Block card (hp %d)" % combat.enemies[0].hp)

	# Haunt is worth playing on a healthy target.
	var dread := _custom(1, [_fx(CardEffect.Kind.HAUNT, 4)])
	var haunt_fight := _combat([dread], [_enemy(40, 1)] as Array[EnemyData])
	SmartPolicy.play_turn(haunt_fight)
	_check(haunt_fight.enemies[0].hp == 36 and haunt_fight.enemies[0].status_turns(Combatant.Status.HAUNTED) == 3, "smart plays a Haunt card: 4 damage landed at the enemy phase and Haunt fell to 3 (hp %d)" % haunt_fight.enemies[0].hp)

	# A card that costs HP is not played when the cost is not worth it at low HP.
	var confess := _custom(1, [_fx(CardEffect.Kind.LOSE_HP, 4), _fx(CardEffect.Kind.DAMAGE, 12)])
	var low := _combat_with_hp([confess], [_enemy(100, 1)] as Array[EnemyData], 6)
	SmartPolicy.play_turn(low)
	_check(low.player.hp > 0 and low.enemies[0].hp == 100, "smart does not pay 4 of its last 6 HP for 12 damage")
	var healthy := _combat_with_hp([confess], [_enemy(100, 1)] as Array[EnemyData], 40)
	SmartPolicy.play_turn(healthy)
	_check(healthy.enemies[0].hp == 88, "smart pays 4 HP for 12 damage when healthy")

	# Energy gain is used: Borrowed Time's refund lets a three-cost card follow it.
	var watch := _custom(1, [_fx(CardEffect.Kind.GAIN_ENERGY, 1), _fx(CardEffect.Kind.DRAW, 1)], CardData.TargetMode.SELF)
	var big := _custom(3, [_fx(CardEffect.Kind.DAMAGE, 20)])
	var chained := _combat([watch, big], [_enemy(100, 1)] as Array[EnemyData])
	SmartPolicy.play_turn(chained)
	_check(chained.enemies[0].hp == 80, "smart plays the energy card and then the three-cost attack it pays for (hp %d)" % chained.enemies[0].hp)

	# Scoring covers the new kinds: every card a character can be offered has a finite, positive
	# score for that character's deck.
	for id in StarterContent.character_ids():
		var weights := SmartPolicy._weights(StarterContent.character(id).starting_deck)
		for card in StarterContent.reward_pool(id):
			var score := SmartPolicy.card_score(card, weights)
			_check(is_finite(score) and score > 0.0, "%s's card %s has a finite positive score (%s)" % [id, card.id, str(score)])


## The greedy policy classes the new damage, defence and HP-cost cards sensibly.
## Seance, Borrowed Time, Spirit Tithe and Reckoning get played sensibly by both policies.
func _test_class_cards_are_played() -> void:
	var seance: CardData = load(StarterContent.SEANCE_PATH)
	var watch: CardData = load(StarterContent.POCKET_WATCH_PATH)
	var tithe: CardData = load(StarterContent.SPIRIT_TITHE_PATH)
	var reckoning: CardData = load(StarterContent.RECKONING_PATH)
	var shove := _card(&"shove", 1, CardEffect.Kind.DAMAGE, 6)
	var foes: Array[EnemyData] = [_enemy(200, 1)]

	# Energy-neutral setup is played once, even with attacks in hand that would use all the energy, and
	# the energy it refunds still buys three Shoves. With an empty draw pile it is left alone (it would
	# only draw itself back and be replayed to the per-turn cap).
	for smart in [false, true]:
		for setup: CardData in [seance, watch]:
			var deck: Array[CardData] = [setup]
			for i in 11:
				deck.append(shove)
			var combat := Combat.new(Combatant.new("p", 40), deck, foes, 1)
			combat.start()
			if not combat.piles.hand.has(setup):
				continue
			var plays: Array[StringName] = []
			combat.card_played.connect(func(card: CardData, _targets: Array[EnemyUnit]) -> void: plays.append(card.id))
			if smart:
				SmartPolicy.play_turn(combat)
			else:
				SimPolicy.play_turn(combat)
			_check(plays.count(setup.id) == 1 and plays.count(&"shove") >= 3, "%s is played once and still leaves 3 Shoves (smart %s, plays %s)" % [setup.id, smart, plays])
			var empty: Array[CardData] = [setup, shove, shove, shove, shove]
			var drained := Combat.new(Combatant.new("p", 40), empty, foes, 1)
			drained.start()
			var drained_plays: Array[StringName] = []
			drained.card_played.connect(func(card: CardData, _targets: Array[EnemyUnit]) -> void: drained_plays.append(card.id))
			if smart:
				SmartPolicy.play_turn(drained)
			else:
				SimPolicy.play_turn(drained)
			_check(not drained_plays.has(setup.id) and drained_plays.count(&"shove") == 3, "%s is not replayed with an empty draw pile (smart %s, plays %s)" % [setup.id, smart, drained_plays])

	# Spirit Tithe is held back with no Haunted enemy.
	var cold := _combat([tithe, reckoning], foes)
	var played: Array[StringName] = []
	cold.card_played.connect(func(card: CardData, _targets: Array[EnemyUnit]) -> void: played.append(card.id))
	cold.player.hp = 20
	SimPolicy.play_turn(cold)
	_check(played.is_empty(), "greedy plays neither Spirit Tithe nor Reckoning with no Haunted enemy")

	# Reckoning hits the most Haunted enemy, not the lowest-HP one.
	var pair: Array[EnemyData] = [_enemy(100, 1), _enemy(60, 1)]
	var haunted := _combat([reckoning], pair)
	haunted.enemies[0].apply_status(Combatant.Status.HAUNTED, 5)
	haunted.enemies[1].apply_status(Combatant.Status.HAUNTED, 1)
	SimPolicy.play_turn(haunted)
	_check(haunted.enemies[0].hp < 100 and haunted.enemies[1].hp >= 59, "greedy aims Reckoning at the most Haunted enemy")


func _test_greedy_card_kinds() -> void:
	for kind in [CardEffect.Kind.DAMAGE, CardEffect.Kind.DAMAGE_PER_BLOCK, CardEffect.Kind.DAMAGE_IF_BLOCK, CardEffect.Kind.DAMAGE_PER_PLAY, CardEffect.Kind.DAMAGE_PER_HAUNT, CardEffect.Kind.HAUNT]:
		_check(SimPolicy.is_damage_card(_custom(1, [_fx(kind, 1)])), "greedy counts kind %d as damage" % kind)
	for kind in [CardEffect.Kind.BLOCK, CardEffect.Kind.HOLD, CardEffect.Kind.THORNS]:
		_check(SimPolicy.is_block_card(_custom(1, [_fx(kind, 1)], CardData.TargetMode.SELF)), "greedy counts kind %d as defence" % kind)
	_check(not SimPolicy.is_damage_card(_custom(1, [_fx(CardEffect.Kind.BLOCK, 5)])), "Block is not damage")

	# It will not pay HP that leaves it under a quarter of its max HP.
	var confess := _custom(1, [_fx(CardEffect.Kind.LOSE_HP, 4), _fx(CardEffect.Kind.DAMAGE, 12)])
	var weak := _combat_with_hp([confess], [_enemy(100, 1)] as Array[EnemyData], 12)
	SimPolicy.play_turn(weak)
	_check(weak.player.hp == 12 or weak.player.hp == 11, "greedy keeps its HP above a quarter of max instead of paying for Confess at 12 HP")
	var fit := _combat_with_hp([confess], [_enemy(100, 1)] as Array[EnemyData], 30)
	SimPolicy.play_turn(fit)
	_check(fit.enemies[0].hp == 88, "greedy pays the HP cost when it can afford it")


func _test_multi_hit_scoring() -> void:
	var single: Array[CardData] = [_card(&"x", 1, CardEffect.Kind.DAMAGE, 3)]
	var combat := _combat_with_hand(single)
	var enemy := combat.enemies[0]
	_check(SmartPolicy._hits_hp_lost(combat.player, enemy, 3, 3) == 9, "three hits of 3 remove 9 HP")
	enemy.block = 4
	_check(SmartPolicy._hits_hp_lost(combat.player, enemy, 3, 3) == 5, "block absorbs across the hits (5 of 9 get through)")
	enemy.block = 0
	_check(SmartPolicy._hits_hp_lost(combat.player, enemy, 3, 99) == enemy.hp, "overkill is not counted")
	var effects: Array[CardEffect] = [CardEffect.make(CardEffect.Kind.DAMAGE, 3, 0, 0, 3)]
	var multi := CardData.make(&"multi", "Multi", 1, effects)
	var hand: Array[CardData] = [multi]
	var combat2 := _combat_with_hand(hand)
	_check(SmartPolicy.play_turn(combat2) and combat2.enemies[0].hp == 31, "a multi-hit card is played for all its hits")
	var weights := {"damage": 1.0, "block": 1.0}
	_check(SmartPolicy.card_score(multi, weights) > SmartPolicy.card_score(_card(&"one", 1, CardEffect.Kind.DAMAGE, 3), weights), "multi-hit scores above a single hit")


## Both bots' incoming and outgoing estimates go through Combatant.hit_damage / block_from_card.
func _test_estimates_use_the_pipeline() -> void:
	var hand: Array[CardData] = [_card(&"x", 1, CardEffect.Kind.DAMAGE, 3)]
	var combat := _combat_with_hand(hand)
	var enemy := combat.enemies[0]
	var enemies: Array[EnemyData] = [_enemy(30, 8)]
	var fight := _combat([_card(&"y", 1, CardEffect.Kind.BLOCK, 4)], enemies)
	var foe := fight.enemies[0]
	_check(SimPolicy._incoming_damage(fight) == 8 and SmartPolicy._incoming_damage(fight) == 8, "baseline incoming damage is the intent")
	foe.apply_status(Combatant.Status.MALICE, 2)
	_check(SimPolicy._incoming_damage(fight) == 10 and SmartPolicy._incoming_damage(fight) == 10, "incoming damage includes enemy Malice")
	foe.apply_status(Combatant.Status.SHAKEN, 1)
	_check(SimPolicy._incoming_damage(fight) == 7 and SmartPolicy._incoming_damage(fight) == 7, "incoming damage includes enemy Shaken (10 x3/4 = 7)")
	fight.player.apply_status(Combatant.Status.EXPOSED, 1)
	var expected := Combatant.hit_damage(8, foe, fight.player)
	_check(expected > 7 and SimPolicy._incoming_damage(fight) == expected and SmartPolicy._incoming_damage(fight) == expected, "incoming damage includes the player's Expose after Malice and Shaken")
	# Outgoing: the player's Malice and Shaken, then the enemy's Expose.
	_check(SmartPolicy._hits_hp_lost(combat.player, enemy, 3, 1) == 3, "baseline card damage")
	combat.player.apply_status(Combatant.Status.MALICE, 2)
	_check(SmartPolicy._hits_hp_lost(combat.player, enemy, 3, 2) == 10, "card damage includes player Malice per hit")
	combat.player.apply_status(Combatant.Status.SHAKEN, 1)
	_check(SmartPolicy._hits_hp_lost(combat.player, enemy, 3, 1) == 3, "card damage includes player Shaken ((3+2) x3/4 = 3)")
	enemy.apply_status(Combatant.Status.EXPOSED, 1)
	_check(SmartPolicy._hits_hp_lost(combat.player, enemy, 3, 1) == Combatant.hit_damage(3, combat.player, enemy), "card damage includes the enemy's Expose")
	# Block: Ward adds, Frayed cuts.
	var guard := _card(&"g", 1, CardEffect.Kind.BLOCK, 4)
	var g_hand: Array[CardData] = [guard]
	var blocking := _combat_with_hand(g_hand)
	blocking.enemies[0].apply_status(Combatant.Status.MALICE, 20)
	var plain := SmartPolicy._play_value(blocking, 0, -1)
	blocking.player.apply_status(Combatant.Status.WARD, 2)
	var warded := SmartPolicy._play_value(blocking, 0, -1)
	_check(warded > plain, "a Block card is worth more with Ward (%f vs %f)" % [warded, plain])
	blocking.player.apply_status(Combatant.Status.WARD, -2)
	blocking.player.apply_status(Combatant.Status.FRAYED, 1)
	var frayed := SmartPolicy._play_value(blocking, 0, -1)
	_check(frayed < plain, "a Block card is worth less when Frayed (%f vs %f)" % [frayed, plain])


## Malice is gained before the attacks it boosts, and Ward before the Block cards.
func _test_buffs_played_before_what_they_boost() -> void:
	for use_smart in [false, true]:
		var gain := _one(CardEffect.Kind.MALICE, 2, CardData.TargetMode.SELF)
		var hit := _card(&"hit", 1, CardEffect.Kind.DAMAGE, 5)
		var hand: Array[CardData] = [hit, gain]
		var combat := _combat_with_hand(hand, 40)
		_check(_play(combat, use_smart), "Malice hand plays a turn (smart %s)" % use_smart)
		_check(combat.enemies[0].hp == 40 - 7, "Malice is gained before the hit: 5 + 2 damage (smart %s, hp %d)" % [use_smart, combat.enemies[0].hp])
	var ward := _one(CardEffect.Kind.WARD, 2, CardData.TargetMode.SELF)
	var guard := _card(&"g", 1, CardEffect.Kind.BLOCK, 4)
	var hand2: Array[CardData] = [guard, ward]
	var combat2 := _combat_with_hand(hand2, 40)
	_check(SimPolicy._pick_card(combat2) == 1, "greedy gains Ward before the Block card")
	_check(SmartPolicy._play_value(combat2, 1, -1) > SmartPolicy._play_value(combat2, 0, -1), "smart values Ward above the Block card it boosts")
	# A temporary Malice is worth something only with a card to boost.
	var temp := _one(CardEffect.Kind.MALICE, 2, CardData.TargetMode.SELF, true)
	var with_hit: Array[CardData] = [_card(&"hit", 1, CardEffect.Kind.DAMAGE, 5), temp]
	var c := _combat_with_hand(with_hit, 40)
	var alone: Array[CardData] = [temp]
	var c_alone := _combat_with_hand(alone, 40)
	_check(SmartPolicy._play_value(c, 1, -1) > 0.0 and SmartPolicy._play_value(c_alone, 0, -1) == 0.0, "temporary Malice is worth something only with a card to boost")
	_check(SimPolicy._pick_card(c_alone) == -1, "greedy skips a temporary Malice with nothing to boost")


## Damage per Forgotten grows with the Forgotten pile, in both the play estimate and the greedy bot's use of it.
func _test_damage_per_forgotten_estimates() -> void:
	var dpf := _custom(1, [_fx(CardEffect.Kind.DAMAGE_PER_FORGOTTEN, 3)])
	var previous := -1.0
	for count in [0, 2, 4]:
		var combat := _combat_with_hand([dpf])
		for i in count:
			combat.piles.forgotten.append(_strike(1))
		var value := SmartPolicy._play_value(combat, 0, 0)
		_check(value > previous, "the estimate grows with the Forgotten count (%d)" % count)
		previous = value
	var weights := {"damage": 1.0, "block": 1.0}
	_check(SmartPolicy.card_score(dpf, weights) > 0.0, "card_score gives damage per Forgotten a nominal value")
	for use_smart in [false, true]:
		var idle := _combat_with_hand([dpf])
		_play(idle, use_smart)
		_check(idle.enemies[0].hp == 40, "damage per Forgotten with an empty Forgotten pile is not played (smart %s)" % use_smart)
		var loaded := _combat_with_hand([dpf])
		for i in 3:
			loaded.piles.forgotten.append(_strike(1))
		_play(loaded, use_smart)
		_check(loaded.enemies[0].hp == 40 - 9, "damage per Forgotten hits for 3 x the Forgotten pile (smart %s)" % use_smart)


func _real(id: StringName) -> CardData:
	for card in StarterContent.all_cards():
		if card.id == id:
			return card
	return null


## Glimpse bins a neutral card below the average and a Dormant card, but a class card only far below it:
## a Medium Haunt / HP-cost card is not binned just because card_score undervalues it.
func _test_glimpse_values_class_cards() -> void:
	var deck := StarterContent.starter_deck(&"medium")
	var weights := SmartPolicy._weights(deck)
	var average := SmartPolicy._average_score(deck, weights)
	var neutral_dud := _card(&"dud", 2, CardEffect.Kind.DAMAGE, 1)
	_check(SmartPolicy.glimpse_junk(neutral_dud, weights, average), "a weak neutral card is binned")
	_check(SmartPolicy.glimpse_junk(_dread(), weights, average), "Dormant is binned")
	# The same card, as a class card and as a neutral one, against an average a little above its score.
	var kept := _card(&"kept", 0, CardEffect.Kind.DAMAGE, 1)
	kept.character = &"medium"
	var neutral_same := _card(&"same", 0, CardEffect.Kind.DAMAGE, 1)
	var score := SmartPolicy.card_score(kept, weights)
	var mid_average := score / ((SmartPolicy.GLIMPSE_CLASS_SHARE + 1.0) / 2.0)
	_check(not SmartPolicy.glimpse_junk(kept, weights, mid_average), "a class card between the class share and the average is kept")
	_check(SmartPolicy.glimpse_junk(neutral_same, weights, mid_average), "the same neutral card at that average is binned")
	_check(SmartPolicy.glimpse_junk(kept, weights, score / (SmartPolicy.GLIMPSE_CLASS_SHARE * 0.5)), "a class card far below the average is binned")


## Recall is worth something only when the Forgotten pile holds a card worth returning; greedy skips it
## when only Dormant or non-attack/defence cards are there.
func _test_recall_judgement() -> void:
	var recall := _custom(1, [_fx(CardEffect.Kind.RECALL, 1)], CardData.TargetMode.SELF)
	var empty := _combat_with_hand([recall])
	_check(SmartPolicy._play_value(empty, 0, -1) == 0.0, "smart: Recall with an empty Forgotten pile is worth nothing")
	_check(SimPolicy._pick_card(empty) == -1, "greedy: Recall with an empty Forgotten pile is not played")
	var junk_only := _combat_with_hand([recall])
	junk_only.piles.forgotten.assign([_dread()])
	_check(SimPolicy._pick_card(junk_only) == -1, "greedy: Recall is not played for a Dormant card")
	var worthwhile := _combat_with_hand([recall])
	worthwhile.piles.forgotten.assign([_strike(14)])
	_check(SmartPolicy._play_value(worthwhile, 0, -1) > 0.0, "smart: Recall with a good Forgotten card is worth playing")
	_check(SimPolicy._pick_card(worthwhile) == 0, "greedy: Recall is played for a good Forgotten card")


## A Forgotten card is not burned for a trivial hit when it kills nothing, but is played for the kill.
func _test_forgotten_not_wasted() -> void:
	var tiny := _strike(1)
	tiny.forgotten = true
	var combat := _combat_with_hand([tiny], 40)
	SmartPolicy.play_turn(combat)
	_check(combat.piles.forgotten.is_empty() and combat.enemies[0].hp == 40, "smart does not burn a Forgotten card on a 1-damage hit")
	var kill := _strike(9)
	kill.forgotten = true
	var finish := _combat_with_hand([kill], 5)
	SmartPolicy.play_turn(finish)
	_check(finish.enemies[0].is_dead(), "smart plays a Forgotten card for the killing blow")


## The cards the sim used to ignore score above zero, and Forgotten payoffs grow with Forgotten cards in the deck.
func _test_new_cards_are_scored_and_taken() -> void:
	for id in [&"remember", &"chorus_of_the_lost", &"hollow_bargain", &"sharpen", &"quick_study", &"cleaned_out", &"dig_deep"]:
		var card := _real(id)
		_check(card != null, "%s exists" % id)
		if card == null:
			continue
		var deck := StarterContent.starter_deck(card.character if card.character != &"" else &"medium")
		var weights := SmartPolicy._weights(deck)
		_check(SmartPolicy.card_score(card, weights) > 0.0, "%s scores above zero" % id)
	var plain := StarterContent.starter_deck(&"medium")
	var rich: Array[CardData] = plain.duplicate()
	for i in 6:
		rich.append(_real(&"bleed_the_veil"))
	for id in [&"remember", &"chorus_of_the_lost"]:
		var card := _real(id)
		_check(SmartPolicy.card_score(card, SmartPolicy._weights(rich)) >= SmartPolicy.card_score(card, SmartPolicy._weights(plain)), "%s is not worth less in a deck full of Forgotten cards" % id)
