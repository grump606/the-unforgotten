extends RefCounted
## How the two bots play Oaths (docs/MECHANICS_PLAN.md, phase 6c): swear early, not late, never twice, and only
## when the lasting effect beats the cost. Fixtures are hand-made cards. Registered by run_tests.gd.

const K := CardEffect.Kind

var _failures := 0


func run() -> int:
	_failures = 0
	_test_greedy_swears_early()
	_test_greedy_skips_late_and_duplicates()
	_test_smart_swears_when_it_pays()
	_test_smart_skips_a_bad_trade()
	_test_smart_turns_left()
	_test_deck_scores_are_positive_and_discounted()
	return _failures


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAIL: " + label)


func _oath(cost: int, trigger: CardData.OathTrigger, sworn_effects: Array[CardEffect], now: Array[CardEffect] = []) -> CardData:
	var card := CardData.make(&"oath", "Oath", cost, now, CardData.TargetMode.SELF)
	card.oath = true
	card.oath_trigger = trigger
	card.oath_effects = sworn_effects
	return card


func _fx(kind: K, amount: int) -> CardEffect:
	return CardEffect.make(kind, amount)


func _fight(hand: Array[CardData], turn: int = 1) -> Combat:
	var enemies: Array[EnemyData] = [EnemyData.make("e", 100, [] as Array[CardEffect])]
	var combat := Combat.new(Combatant.new("p", 40), hand, enemies, 1)
	combat.start()
	combat.turn = turn
	return combat


func _block_oath() -> CardData:
	return _oath(1, CardData.OathTrigger.TURN_START, [_fx(K.BLOCK, 4)] as Array[CardEffect])


func _test_greedy_swears_early() -> void:
	var oath := _block_oath()
	var combat := _fight([oath])
	SimPolicy.play_turn(combat)
	_check(combat.piles.sworn == [oath], "greedy swears an Oath on turn 1")
	# It goes before the turn's attacks spend the energy.
	var strike := CardData.make(&"s", "S", 3, [_fx(K.DAMAGE, 9)] as Array[CardEffect])
	var both := _fight([strike, _block_oath()])
	SimPolicy.play_turn(both)
	_check(both.piles.sworn.size() == 1 and both.enemies[0].hp == 100, "an Oath is sworn before the energy goes to an attack it could not afford alongside")


func _test_greedy_skips_late_and_duplicates() -> void:
	var late := _fight([_block_oath()], SimPolicy.OATH_LAST_TURN + 1)
	SimPolicy.play_turn(late)
	_check(late.piles.sworn.is_empty(), "greedy does not swear an Oath after turn %d" % SimPolicy.OATH_LAST_TURN)
	var first := _block_oath()
	var second := _block_oath()
	var twice := _fight([first, second])
	SimPolicy.play_turn(twice)
	_check(twice.piles.sworn.size() == 1, "greedy does not swear a second copy")


func _test_smart_swears_when_it_pays() -> void:
	var oath := _oath(1, CardData.OathTrigger.TURN_START, [_fx(K.BLOCK, 5)] as Array[CardEffect], [_fx(K.LOSE_HP, 2)] as Array[CardEffect])
	var combat := _fight([oath])
	SmartPolicy.play_turn(combat)
	_check(combat.piles.sworn == [oath], "smart swears an Oath whose lasting effect beats its cost")


func _test_smart_skips_a_bad_trade() -> void:
	var weak := _oath(1, CardData.OathTrigger.TURN_START, [_fx(K.BLOCK, 1)] as Array[CardEffect], [_fx(K.LOSE_HP, 12)] as Array[CardEffect])
	var combat := _fight([weak])
	SmartPolicy.play_turn(combat)
	_check(combat.piles.sworn.is_empty(), "smart does not pay 12 HP for Block 1 a turn")
	var late := _fight([_block_oath()], 6)
	SmartPolicy.play_turn(late)
	_check(late.piles.sworn.is_empty(), "smart does not swear an Oath with no turns left to act")


func _test_smart_turns_left() -> void:
	var turns: Array[int] = []
	for t in [1, 2, 3, 4, 8]:
		turns.append(SmartPolicy.oath_turns_left(_fight([_block_oath()], t)))
	_check(turns == [3, 2, 1, 0, 0], "turns left after swearing: %s" % str(turns))


func _test_deck_scores_are_positive_and_discounted() -> void:
	var weights := {"damage": 1.0, "block": 1.0, "forgotten": 3, "recall": 5.0}
	var oath := _oath(1, CardData.OathTrigger.TURN_START, [_fx(K.BLOCK, 4)] as Array[CardEffect])
	var anchor := _oath(1, CardData.OathTrigger.ANCHOR_KEPT, [_fx(K.BLOCK, 4)] as Array[CardEffect])
	var score := SmartPolicy.card_score(oath, weights)
	_check(score > 0.0, "an Oath with a good effect scores above zero")
	_check(SmartPolicy.card_score(anchor, weights) < score, "an Oath that rarely fires scores below one that fires every turn")
	var plain := CardData.make(&"p", "P", 1, [_fx(K.BLOCK, 4)] as Array[CardEffect], CardData.TargetMode.SELF)
	_check(score > SmartPolicy.card_score(plain, weights), "but a lasting effect still beats the same effect once")
