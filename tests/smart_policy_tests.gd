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

	# Energy gain is used: Pocket Watch's refund lets a three-cost card follow it.
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
## Seance, Pocket Watch, Spirit Tithe and Reckoning get played sensibly by both policies.
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
