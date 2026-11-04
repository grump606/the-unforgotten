extends RefCounted
## Tests for tools/smart_policy.gd (the run sim's --policy smart player).
## run() returns the failure count and prints a "FAIL: ..." line per failure.

var _failures := 0


func run() -> int:
	_failures = 0
	_test_values_new_effects()
	_test_greedy_card_kinds()
	_test_class_cards_are_played()
	_test_takes_the_killing_blow()
	_test_exposes_before_damage()
	_test_plays_whole_runs_without_illegal_moves()
	_test_card_scoring_order()
	_test_reward_alternatives()
	_test_keyword_discards()
	_test_fading_played_before_end_of_turn()
	_test_dormant_never_played()
	_test_surge_spends_all_energy()
	_test_multi_hit_scoring()
	_test_keyword_hand_finishes_a_fight()
	_test_estimates_use_the_pipeline()
	_test_buffs_played_before_what_they_boost()
	_test_shaken_timing_and_self_cost()
	_test_every_new_kind_fight_finishes()
	_test_run_stub_leak_check()
	return _failures


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAIL: " + label)


func _card(id: StringName, cost: int, kind: CardEffect.Kind, amount: int) -> CardData:
	var effects: Array[CardEffect] = [CardEffect.make(kind, amount)]
	return CardData.make(id, String(id), cost, effects)


func _enemy(hp: int, damage: int) -> EnemyData:
	var intents: Array[CardEffect] = [CardEffect.make(CardEffect.Kind.DAMAGE, damage)]
	return EnemyData.make("e", hp, intents)


func _combat(hand_cards: Array[CardData], enemies: Array[EnemyData]) -> Combat:
	# A deck of at most HAND_SIZE cards is drawn whole into the opening hand.
	var combat := Combat.new(Combatant.new("p", 40), hand_cards, enemies, 1)
	combat.start()
	return combat


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


func _test_plays_whole_runs_without_illegal_moves() -> void:
	for seed_value in 6:
		# Every character, so each class's new effects get played through.
		var character: StringName = StarterContent.character_ids()[seed_value % 3]
		var run := RunState.new(seed_value, character)
		while not run.finished:
			match run.current_stop().type:
				RunState.StopType.COMBAT:
					var combat := run.start_combat()
					combat.start()
					var guard := 0
					while combat.phase == Combat.Phase.PLAYER_TURN and guard < 60:
						_check(SmartPolicy.play_turn(combat), "smart turn is legal (seed %d)" % seed_value)
						guard += 1
					run.complete_combat(combat.living_enemies().is_empty())
					if run.reward_pending():
						_check(run.resolve_reward(SmartPolicy.pick_reward(run)), "smart reward pick is accepted")
				RunState.StopType.REST:
					run.rest()
				RunState.StopType.STORY:
					run.read_story()
				RunState.StopType.VENDOR:
					_check(SmartPolicy.shop(run), "smart vendor visit succeeds")
		_check(run.finished, "run finished (seed %d)" % seed_value)


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


func _fx(kind: CardEffect.Kind, amount: int, bonus: int = 0, threshold: int = 0) -> CardEffect:
	return CardEffect.make(kind, amount, bonus, threshold)


func _custom(cost: int, effects: Array[CardEffect], mode: CardData.TargetMode = CardData.TargetMode.SINGLE_ENEMY) -> CardData:
	return CardData.make(&"c", "C", cost, effects, mode)


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


func _keyword_card(id: StringName, keyword: String, cost: int = 1, kind: CardEffect.Kind = CardEffect.Kind.DAMAGE, amount: int = 3) -> CardData:
	var card := _card(id, cost, kind, amount)
	if keyword != "":
		card.set(keyword, true)
	return card


func _surge_card(amount: int, hits: int) -> CardData:
	var effects: Array[CardEffect] = [CardEffect.make(CardEffect.Kind.DAMAGE, amount, 0, 0, hits, true)]
	var card := CardData.make(&"surge", "Surge", 0, effects)
	card.surge = true
	return card


## A started combat holding `hand_cards` exactly (set directly, bypassing the draw rules).
func _combat_with_hand(hand_cards: Array[CardData], enemy_hp: int = 40) -> Combat:
	var starter: Array[CardData] = [_card(&"starter", 9, CardEffect.Kind.BLOCK, 1)]
	var enemies: Array[EnemyData] = [_enemy(enemy_hp, 1)]
	var combat := _combat(starter, enemies)
	combat.piles.hand.clear()
	combat.piles.hand.append_array(hand_cards)
	return combat


func _play(combat: Combat, use_smart: bool) -> bool:
	return SmartPolicy.play_turn(combat) if use_smart else SimPolicy.play_turn(combat)


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


func _test_keyword_hand_finishes_a_fight() -> void:
	for use_smart in [false, true]:
		var deck: Array[CardData] = []
		for i in 3:
			deck.append(_card(StringName("hit%d" % i), 1, CardEffect.Kind.DAMAGE, 4))
		deck.append(_card(&"guard", 1, CardEffect.Kind.BLOCK, 5))
		deck.append(_keyword_card(&"anc", "anchor", 1, CardEffect.Kind.BLOCK, 3))
		deck.append(_keyword_card(&"fad", "fading", 1, CardEffect.Kind.DAMAGE, 5))
		deck.append(_keyword_card(&"frg", "forgotten", 1, CardEffect.Kind.DAMAGE, 8))
		deck.append(_keyword_card(&"rdy", "ready", 1, CardEffect.Kind.DAMAGE, 4))
		deck.append(_keyword_card(&"drm", "dormant", 0, CardEffect.Kind.DAMAGE, 20))
		deck.append(_surge_card(2, 1))
		var enemies: Array[EnemyData] = [_enemy(40, 2)]
		var combat := Combat.new(Combatant.new("p", 60), deck, enemies, 3)
		combat.start()
		var guard := 0
		while combat.phase == Combat.Phase.PLAYER_TURN and guard < 40:
			var ok := _play(combat, use_smart)
			_check(ok, "keyword hand turn is legal (smart %s)" % use_smart)
			if not ok:
				break
			guard += 1
		_check(combat.phase == Combat.Phase.ENDED and combat.enemies[0].is_dead(), "the bot wins a fight with keyword cards without stalling (smart %s, turns %d)" % [use_smart, guard])


## A card of one effect on the given target mode (cost 1 unless given).
func _one(kind: CardEffect.Kind, amount: int, mode: CardData.TargetMode, temporary: bool = false, cost: int = 1) -> CardData:
	var effects: Array[CardEffect] = [CardEffect.make(kind, amount, 0, 0, 1, false, temporary)]
	return CardData.make(&"one", "One", cost, effects, mode)


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


## A seeded fight whose deck holds every new kind (both signs, temporary and not, self and enemy targets)
## finishes for both bots with no stall and no illegal move.
func _test_every_new_kind_fight_finishes() -> void:
	var enemy_intents: Array[CardEffect] = [
		CardEffect.make(CardEffect.Kind.DAMAGE, 6),
		CardEffect.make(CardEffect.Kind.BLOCK, 6),
		CardEffect.make(CardEffect.Kind.SHAKEN, 1),
		CardEffect.make(CardEffect.Kind.MALICE, 1),
		CardEffect.make(CardEffect.Kind.DAMAGE, 5),
	]
	for use_smart in [false, true]:
		var deck: Array[CardData] = [
			_card(&"a", 1, CardEffect.Kind.DAMAGE, 5),
			_card(&"b", 1, CardEffect.Kind.DAMAGE, 6),
			_card(&"c", 1, CardEffect.Kind.BLOCK, 5),
			_one(CardEffect.Kind.MALICE, 2, CardData.TargetMode.SELF),
			_one(CardEffect.Kind.MALICE, 3, CardData.TargetMode.SELF, true),
			_one(CardEffect.Kind.WARD, 2, CardData.TargetMode.SELF),
			_one(CardEffect.Kind.WARD, 2, CardData.TargetMode.SELF, true),
			_one(CardEffect.Kind.SHAKEN, 2, CardData.TargetMode.SINGLE_ENEMY),
			_one(CardEffect.Kind.FRAYED, 2, CardData.TargetMode.SINGLE_ENEMY),
			_one(CardEffect.Kind.MALICE, -2, CardData.TargetMode.SINGLE_ENEMY),
			_one(CardEffect.Kind.WARD, -2, CardData.TargetMode.SINGLE_ENEMY),
			_one(CardEffect.Kind.SHAKEN, 1, CardData.TargetMode.SELF),
			_one(CardEffect.Kind.FRAYED, 1, CardData.TargetMode.SELF),
		]
		var enemies: Array[EnemyData] = [EnemyData.make("e", 60, enemy_intents)]
		var combat := Combat.new(Combatant.new("p", 80), deck, enemies, 11)
		combat.start()
		var turns := 0
		while combat.phase == Combat.Phase.PLAYER_TURN and turns < 60:
			var ok := _play(combat, use_smart)
			_check(ok, "every-kind turn is legal (smart %s)" % use_smart)
			if not ok:
				break
			turns += 1
		_check(combat.phase == Combat.Phase.ENDED, "the every-kind fight finishes without a stall (smart %s, turns %d)" % [use_smart, turns])
		# The card scorers handle every kind (finite numbers).
		var weights := {"damage": 1.0, "block": 1.0}
		for card in deck:
			var score := SmartPolicy.card_score(card, weights)
			_check(not is_nan(score) and not is_inf(score), "card_score is finite for every kind")


## run_stub's leak check sees leftover Shaken, Frayed, Malice and Ward, temporary stacks included.
func _test_run_stub_leak_check() -> void:
	var stub: GDScript = load("res://tools/run_stub.gd")
	var player := Combatant.new("p", 40)
	_check(stub.leaked_state(player) == "", "a clean player leaks nothing")
	for status in [Combatant.Status.SHAKEN, Combatant.Status.FRAYED, Combatant.Status.MALICE, Combatant.Status.WARD, Combatant.Status.EXPOSED]:
		var dirty := Combatant.new("p", 40)
		dirty.apply_status(status, 1)
		_check(stub.leaked_state(dirty) != "", "leftover status %d is caught" % status)
	for status in [Combatant.Status.MALICE, Combatant.Status.WARD]:
		var temp := Combatant.new("p", 40)
		temp.apply_temp_stack(status, 2)
		_check(stub.leaked_state(temp) != "", "a leftover temporary stack of status %d is caught" % status)
	var blocked := Combatant.new("p", 40)
	blocked.block = 3
	_check(stub.leaked_state(blocked) != "", "leftover Block is caught")
