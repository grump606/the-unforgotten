extends "res://tests/smart_policy_support.gd"
## SmartPolicy over whole fights and runs: no illegal moves, fights finish, rest and vendor choices.
## Discovered by run_tests.gd.


func run() -> int:
	_failures = 0
	_test_plays_whole_runs_without_illegal_moves()
	_test_keyword_hand_finishes_a_fight()
	_test_every_new_kind_fight_finishes()
	_test_run_stub_leak_check()
	_test_cycling_deck_fight_finishes()
	_test_rest_stop_remembers_or_rests()
	_test_run_stub_rest_or_remember()
	_test_relics_are_bought_and_fights_finish()
	return _failures


func _test_plays_whole_runs_without_illegal_moves() -> void:
	# Every character from the registry (not a hard-coded three), two seeds each, so each class's
	# effects get played through.
	var cases: Array = []
	for character in StarterContent.character_ids():
		for seed_value in 2:
			cases.append([character, seed_value])
	_check(cases.size() >= 2 * StarterContent.character_ids().size(), "every character is played")
	for case in cases:
		var character: StringName = case[0]
		var seed_value: int = case[1]
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
					_check(SimPolicy.rest_stop(run, true), "smart rest stop is accepted")
				RunState.StopType.STORY:
					run.read_story()
				RunState.StopType.VENDOR:
					_check(SmartPolicy.shop(run), "smart vendor visit succeeds")
		_check(run.finished, "run finished (seed %d)" % seed_value)


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


## A seeded fight with every new kind in the deck against an enemy that shuffles Dread and Murmur in each
## turn finishes for both policies, and the deck is untouched.
func _test_cycling_deck_fight_finishes() -> void:
	for use_smart in [false, true]:
		var deck: Array[CardData] = []
		for i in 4:
			var spent := _strike(5)
			spent.forgotten = true
			deck.append(spent)
		deck.append(_strike(6))
		deck.append(_card(&"guard", 1, CardEffect.Kind.BLOCK, 5))
		deck.append(_custom(0, [_fx(CardEffect.Kind.GLIMPSE, 3)], CardData.TargetMode.SELF))
		deck.append(_custom(1, [_fx(CardEffect.Kind.RECALL, 1)], CardData.TargetMode.SELF))
		deck.append(_custom(1, [CardEffect.make(CardEffect.Kind.ADD_CARD, 1, 0, 0, 1, false, false, _strike(4), CardEffect.Pile.HAND)], CardData.TargetMode.SELF))
		deck.append(_custom(1, [_fx(CardEffect.Kind.DAMAGE_PER_FORGOTTEN, 2)]))
		var intents: Array[CardEffect] = [
			CardEffect.make(CardEffect.Kind.ADD_CARD, 2, 0, 0, 1, false, false, _dread(), CardEffect.Pile.DRAW),
			CardEffect.make(CardEffect.Kind.ADD_CARD, 1, 0, 0, 1, false, false, _murmur(), CardEffect.Pile.HAND),
			CardEffect.make(CardEffect.Kind.DAMAGE, 3),
		]
		var enemies: Array[EnemyData] = [EnemyData.make("shuffler", 70, intents)]
		var before := deck.duplicate()
		var combat := Combat.new(Combatant.new("p", 60), deck, enemies, 5)
		combat.start()
		var ok := _run_fight(combat, use_smart, 200)
		_check(ok, "the cycling fight has no illegal move (smart %s)" % use_smart)
		_check(combat.phase == Combat.Phase.ENDED, "the cycling fight finishes without a stall (smart %s, turn %d)" % [use_smart, combat.turn])
		_check(deck == before, "created cards never enter the deck (smart %s)" % use_smart)


func _rest_run(character: StringName) -> RunState:
	var run := RunState.new(5, character)
	while run.current_stop().type != RunState.StopType.REST:
		match run.current_stop().type:
			RunState.StopType.COMBAT:
				run.complete_combat(true)
				if run.reward_pending():
					run.resolve_reward(null)
			RunState.StopType.STORY:
				run.read_story()
			RunState.StopType.VENDOR:
				run.leave_vendor()
	return run


## At a rest stop the bots Rest under 60% HP and Remember a card above it; the Remembered card is a variant
## with the same id.
func _test_rest_stop_remembers_or_rests() -> void:
	for use_smart in [false, true]:
		var low := _rest_run(&"thief")
		low.player.hp = int(low.player.max_hp * 0.4)
		var deck_before := low.deck.duplicate()
		_check(SimPolicy.rest_stop(low, use_smart) and low.player.hp == low.player.max_hp and low.deck == deck_before, "low HP: the bot rests (smart %s)" % use_smart)
		var high := _rest_run(&"thief")
		high.player.hp = int(high.player.max_hp * 0.8)
		var hp := high.player.hp
		var ids_before: Array[StringName] = []
		for card in high.deck:
			ids_before.append(card.id)
		_check(SimPolicy.rest_stop(high, use_smart), "high HP: the rest stop is accepted (smart %s)" % use_smart)
		var remembered := 0
		for i in high.deck.size():
			_check(high.deck[i].id == ids_before[i], "a Remembered card keeps its id (smart %s)" % use_smart)
			if high.deck[i].is_remembered:
				remembered += 1
		_check(remembered == 1 and high.player.hp == hp, "high HP: one card is Remembered and nothing is healed (smart %s)" % use_smart)
	var run := _rest_run(&"thief")
	var pick := SmartPolicy.remember_pick(run)
	_check(pick >= 0 and run.deck[pick].can_remember(), "smart names a card that can be Remembered")


func _test_run_stub_rest_or_remember() -> void:
	var stub: Script = load("res://tools/run_stub.gd")
	var deck := StarterContent.starter_deck(&"thief")
	var player := Combatant.new("p", 40)
	_check(stub.rest_or_remember(player, deck).begins_with("remembered"), "the run stub Remembers at high HP")
	var remembered := 0
	for card in deck:
		if card.is_remembered:
			remembered += 1
	_check(remembered == 1, "the run stub Remembered exactly one card")
	player.hp = 10
	_check(stub.rest_or_remember(player, deck).begins_with("rest") and player.hp > 10, "the run stub rests at low HP")


## Every relic (the six keyword relics included) lets both bots finish a fight, and the vendor step buys the relic on offer.
func _test_relics_are_bought_and_fights_finish() -> void:
	for relic in StarterContent.all_relics():
		for use_smart in [false, true]:
			var deck := StarterContent.starter_deck(&"medium")
			var enemies: Array[EnemyData] = [StarterContent.warden()]
			var relics: Array[RelicData] = [relic]
			var combat := Combat.create(Combatant.new("p", 60), deck, enemies, 3, relics)
			combat.start()
			var ok := _run_fight(combat, use_smart, 80)
			_check(ok and combat.phase == Combat.Phase.ENDED, "a fight with relic %s finishes (smart %s)" % [relic.id, use_smart])
	var run := RunState.new(3, &"thief")
	while run.current_stop().type != RunState.StopType.VENDOR:
		match run.current_stop().type:
			RunState.StopType.COMBAT:
				run.complete_combat(true)
				if run.reward_pending():
					run.resolve_reward(null)
			RunState.StopType.STORY:
				run.read_story()
			RunState.StopType.REST:
				run.rest()
	run.gold = 500
	var offered := run.vendor().relic_offer()
	_check(not offered.is_empty() and SimPolicy.buy_relic(run) and run.relics.size() == 1, "the bot buys the vendor's relic")
