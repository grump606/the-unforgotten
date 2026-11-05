extends RefCounted
## The neutral pool split (docs/CLASSES_PLAN.md and docs/MECHANICS_PLAN.md): the basic cards (Shove, Slip Past)
## are starting cards and vendor stock but never reward offers, and eight shared cards join the neutral pool.
## Registered by run_tests.gd.

const SHARED: Array[StringName] = [
	&"steady_hands", &"counter_step", &"second_look", &"downpour", &"hold_fast", &"pull_together", &"lucky_break", &"shake_them",
]

var _failures := 0


func run() -> int:
	_failures = 0
	_test_basics()
	_test_pools()
	_test_rewards_never_offer_basics()
	_test_vendor_can_stock_basics()
	_test_shared_cards()
	_test_sweep()
	return _failures


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAIL: " + label)


func _load(id: StringName) -> CardData:
	return load("res://data/cards/%s.tres" % id) as CardData


func _ids(cards: Array[CardData]) -> Array:
	var ids := []
	for card in cards:
		ids.append(card.id)
	return ids


func _test_basics() -> void:
	var basic_ids := []
	for card in StarterContent.all_cards():
		if card.basic:
			basic_ids.append(card.id)
			_check(card.character == &"", "%s is neutral" % card.id)
	_check(basic_ids.size() == 2 and basic_ids.has(&"shove") and basic_ids.has(&"slip_past"), "exactly Shove and Slip Past are basic: %s" % str(basic_ids))
	for character in StarterContent.character_ids():
		var starting := _ids(StarterContent.starter_deck(character))
		_check(starting.has(&"shove") and starting.has(&"slip_past"), "%s starts with both basics" % character)


func _test_pools() -> void:
	for character in StarterContent.character_ids():
		var rewards := _ids(StarterContent.reward_pool(character))
		var vendor := _ids(StarterContent.vendor_pool(character))
		_check(not rewards.has(&"shove") and not rewards.has(&"slip_past"), "%s: the reward pool leaves out the basics" % character)
		_check(vendor.has(&"shove") and vendor.has(&"slip_past"), "%s: the vendor pool includes them" % character)
		_check(vendor.size() == rewards.size() + 2, "%s: the vendor pool is the reward pool plus the two basics" % character)
		for id in SHARED:
			_check(rewards.has(id), "%s can be offered %s" % [character, id])
		_check(rewards.has(&"sweep") and rewards.has(&"flurry") and rewards.has(&"glimpse_exit") and rewards.has(&"brace"), "%s can still be offered the other original neutral cards" % character)
	var neutral := 0
	for card in StarterContent.reward_pool(&"deserter"):
		if card.character == &"":
			neutral += 1
	_check(neutral == 12, "twelve neutral cards can be offered (%d)" % neutral)


func _test_rewards_never_offer_basics() -> void:
	for character in StarterContent.character_ids():
		var state := RunState.new(3, character)
		state.read_story()
		var rolls := 0
		for roll in 40:
			state._roll_rewards()
			rolls += 1
			for card in state.reward_choices():
				_check(not card.basic, "%s: a reward offer holds a basic card (%s)" % [character, card.id])
	_check(true, "")


func _test_vendor_can_stock_basics() -> void:
	var seen := 0
	for seed_value in 60:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var vendor := Vendor.new(StarterContent.starter_deck(&"thief"), rng, 100, StarterContent.vendor_pool(&"thief"))
		for offer in vendor.offers():
			if offer["card"].basic:
				seen += 1
	_check(seen > 0, "across sixty vendors a basic card is sometimes on sale (%d)" % seen)


func _fight(hand: Array[CardData], enemy_count: int = 1) -> Combat:
	var enemies: Array[EnemyData] = []
	for i in enemy_count:
		enemies.append(EnemyData.make("E%d" % i, 100, [] as Array[CardEffect]))
	var combat := Combat.new(Combatant.new("p", 40), hand, enemies, 1)
	combat.start()
	return combat


func _play(combat: Combat, card: CardData, target: int = 0) -> bool:
	return combat.play_card(combat.piles.hand.find(card), target)


func _test_shared_cards() -> void:
	for id in SHARED:
		var card := _load(id)
		_check(card != null and card.id == id and card.character == &"" and not card.basic, "%s is a plain neutral card" % id)
	var steady := _load(&"steady_hands")
	var deck: Array[CardData] = [steady]
	for i in 6:
		deck.append(_load(&"brace"))
	var c1 := _fight(deck)
	var hand_before := c1.piles.hand.size()
	_play(c1, steady)
	_check(c1.player.block == 6 and c1.piles.hand.size() == hand_before, "Steady Hands: Block 6 and draws 1 (the card left, one came in)")
	var counter := _load(&"counter_step")
	var c2 := _fight([counter])
	_play(c2, counter)
	_check(c2.enemies[0].hp == 95 and c2.player.block == 3, "Counter Step: 5 damage and Block 3")
	var look := _load(&"second_look")
	var many: Array[CardData] = [look]
	for i in 8:
		many.append(_load(&"brace"))
	var c3 := _fight(many)
	var before := c3.piles.hand.size()
	_play(c3, look)
	_check(c3.piles.hand.size() == before + 1 and c3.piles.forgotten.has(look), "Second Look draws 2 and is Forgotten")
	var down := _load(&"downpour")
	var c4 := _fight([down], 3)
	_play(c4, down)
	var hps := [c4.enemies[0].hp, c4.enemies[1].hp, c4.enemies[2].hp]
	var shaken := [c4.enemies[0].status_turns(Combatant.Status.SHAKEN), c4.enemies[1].status_turns(Combatant.Status.SHAKEN), c4.enemies[2].status_turns(Combatant.Status.SHAKEN)]
	_check(hps == [96, 96, 96] and shaken == [1, 1, 1], "Downpour hits all three for 4 and Shakens them (hp %s)" % str(hps))
	var fast := _load(&"hold_fast")
	var c5 := _fight([fast])
	_play(c5, fast)
	_check(c5.player.block == 4 and c5.player.hold == 4, "Hold Fast: Block 4 and Hold 4")
	var pull := _load(&"pull_together")
	var big: Array[CardData] = [pull]
	for i in 8:
		big.append(_load(&"brace"))
	var c6 := _fight(big)
	_play(c6, pull)
	_check(c6.player.block == 3 and c6.has_choice(), "Pull Together: Block 3 and a Glimpse")
	var lucky := _load(&"lucky_break")
	var more: Array[CardData] = [lucky]
	for i in 8:
		more.append(_load(&"brace"))
	var c7 := _fight(more)
	var hand7 := c7.piles.hand.size()
	_play(c7, lucky)
	_check(c7.enemies[0].hp == 97 and c7.piles.hand.size() == hand7 and c7.energy == Combat.ENERGY_PER_TURN, "Lucky Break: 3 damage, draws 1, free")
	var shake := _load(&"shake_them")
	var c8 := _fight([shake], 2)
	_play(c8, shake)
	_check(c8.enemies[0].status_turns(Combatant.Status.SHAKEN) == 2 and c8.enemies[1].status_turns(Combatant.Status.SHAKEN) == 2, "Shake Them Shakens every enemy for 2")


func _test_sweep() -> void:
	var sweep := _load(&"sweep")
	_check(sweep.cost == 1 and sweep.target_mode == CardData.TargetMode.ALL_ENEMIES, "Sweep costs 1 and hits all enemies")
	var combat := _fight([sweep], 3)
	_play(combat, sweep)
	_check(combat.enemies[0].hp == 95 and combat.enemies[1].hp == 95 and combat.enemies[2].hp == 95, "Sweep deals 5 to each of three enemies")
