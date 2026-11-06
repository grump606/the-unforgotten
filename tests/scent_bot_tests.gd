extends RefCounted
## How the two bots play Scent (docs/CLASSES_PLAN.md, the Stray, phase 4a): mark the quarry before the attacks
## that use it, keep every attack on that one enemy, spend a stack after the other attacks and not too early,
## and never waste a mark at the cap. Hand-made cards; registered by run_tests.gd.

const K := CardEffect.Kind
const SCENT := Combatant.Status.SCENT

var _failures := 0


func run() -> int:
	_failures = 0
	_test_greedy_marks_first()
	_test_greedy_focuses_the_quarry()
	_test_greedy_spender_timing()
	_test_greedy_does_not_mark_at_the_cap()
	_test_smart_marks_first()
	_test_smart_spends_after_the_other_attacks()
	_test_smart_focuses_the_quarry()
	_test_smart_skips_a_wasted_mark()
	_test_the_real_starting_deck_is_played()
	return _failures


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAIL: " + label)


func _fx(kind: K, amount: int, bonus: int = 0, hits: int = 1) -> CardEffect:
	return CardEffect.make(kind, amount, bonus, 0, hits)


func _mark(cost: int = 0, amount: int = 2) -> CardData:
	return CardData.make(&"mark", "Mark", cost, [_fx(K.SCENT, amount)] as Array[CardEffect])


func _attack(cost: int = 1, amount: int = 4, hits: int = 2) -> CardData:
	return CardData.make(&"attack", "Attack", cost, [_fx(K.DAMAGE, amount, 0, hits)] as Array[CardEffect])


func _spender(cost: int = 1) -> CardData:
	return CardData.make(&"spender", "Spender", cost, [_fx(K.DAMAGE_PER_SCENT, 4, 3)] as Array[CardEffect])


func _fight(hand: Array[CardData], enemy_hps: Array[int] = [200] as Array[int]) -> Combat:
	var enemies: Array[EnemyData] = []
	for hp in enemy_hps:
		enemies.append(EnemyData.make("E", hp, [] as Array[CardEffect]))
	var combat := Combat.new(Combatant.new("p", 40), hand, enemies, 1)
	combat.start()
	return combat


func _test_greedy_marks_first() -> void:
	var attack := _attack()
	var mark := _mark()
	var combat := _fight([attack, mark])
	SimPolicy.play_turn(combat)
	# Marked for 2 first, then 2 hits of 4 + 2: 12. Attacking first would deal only 8.
	_check(combat.enemies[0].hp == 200 - 12, "greedy marks before it attacks (hp %d)" % combat.enemies[0].hp)


func _test_greedy_focuses_the_quarry() -> void:
	var combat := _fight([_attack(), _attack()], [200, 30] as Array[int])
	combat.enemies[0].apply_status(SCENT, 3)
	SimPolicy.play_turn(combat)
	_check(combat.enemies[0].hp < 200 and combat.enemies[1].hp == 30, "greedy attacks the Scent holder even when another enemy has less HP")


func _test_greedy_spender_timing() -> void:
	# A stack of 2 is below the threshold (2 + cost 1 = 3) and a Scent card is in hand: build first.
	var spender := _spender()
	var mark := _mark(0, 1)
	var low := _fight([spender, mark])
	low.enemies[0].apply_status(SCENT, 2)
	SimPolicy.play_turn(low)
	_check(low.enemies[0].stacks(SCENT) == 3 or low.enemies[0].hp < 200 - 4, "greedy builds first, then spends once the stack is ready (Scent %d, hp %d)" % [low.enemies[0].stacks(SCENT), low.enemies[0].hp])
	# At the threshold it spends.
	var ready := _fight([_spender()])
	ready.enemies[0].apply_status(SCENT, 3)
	SimPolicy.play_turn(ready)
	_check(ready.enemies[0].stacks(SCENT) == 0 and ready.enemies[0].hp == 200 - (4 + 9 + 3), "greedy spends a stack of 3 (hp %d)" % ready.enemies[0].hp)
	# With no way to build, a small stack is still spent rather than held forever.
	var small := _fight([_spender()])
	small.enemies[0].apply_status(SCENT, 1)
	SimPolicy.play_turn(small)
	_check(small.enemies[0].stacks(SCENT) == 0, "greedy spends a small stack when no card can add to it")


func _test_greedy_does_not_mark_at_the_cap() -> void:
	var mark := _mark()
	var combat := _fight([mark])
	combat.enemies[0].apply_status(SCENT, Combatant.SCENT_CAP)
	SimPolicy.play_turn(combat)
	_check(combat.piles.hand.has(mark), "greedy keeps a pure Scent card when the stack is at the cap")


func _test_smart_marks_first() -> void:
	var attack := _attack()
	var mark := _mark()
	var combat := _fight([attack, mark])
	SmartPolicy.play_turn(combat)
	_check(combat.enemies[0].hp == 200 - 12, "smart marks before it attacks (hp %d)" % combat.enemies[0].hp)


func _test_smart_spends_after_the_other_attacks() -> void:
	var attack := _attack()
	var spender := _spender()
	var combat := _fight([attack, spender])
	combat.enemies[0].apply_status(SCENT, 3)
	SmartPolicy.play_turn(combat)
	# Attack first (2 hits of 4 + 3 = 14), then the spender (4 + 9 + 3 = 16): 30. The other order deals 24.
	_check(combat.enemies[0].hp == 200 - 30, "smart plays the attack, then spends the Scent (hp %d)" % combat.enemies[0].hp)


func _test_smart_focuses_the_quarry() -> void:
	var combat := _fight([_mark(0, 1), _attack()], [200, 150] as Array[int])
	combat.enemies[1].apply_status(SCENT, 2)
	SmartPolicy.play_turn(combat)
	_check(combat.enemies[1].stacks(SCENT) >= 3 and combat.enemies[0].stacks(SCENT) == 0, "smart keeps marking the enemy that already holds Scent")
	_check(combat.enemies[0].hp == 200, "and attacks it too")


func _test_smart_skips_a_wasted_mark() -> void:
	var mark := _mark()
	var combat := _fight([mark])
	combat.enemies[0].apply_status(SCENT, Combatant.SCENT_CAP)
	SmartPolicy.play_turn(combat)
	_check(combat.piles.hand.has(mark), "smart does not spend a card marking a full stack")


## The Stray's own starting deck: over a few fights both bots must actually mark and spend Scent.
func _test_the_real_starting_deck_is_played() -> void:
	for policy in ["greedy", "smart"]:
		var counts := {"marked": 0, "spent": 0}
		for fight_seed in 6:
			var enemies: Array[EnemyData] = [EnemyData.make("E", 60, [CardEffect.make(K.DAMAGE, 3)] as Array[CardEffect])]
			var combat := Combat.new(Combatant.new("p", 60), StarterContent.starter_deck(&"stray"), enemies, fight_seed + 1)
			combat.card_played.connect(func(card: CardData, _targets: Array[EnemyUnit]) -> void:
				if card.id == &"catch_the_scent":
					counts["marked"] += 1
				if card.id == &"run_down":
					counts["spent"] += 1)
			combat.start()
			var turns := 0
			while combat.phase != Combat.Phase.ENDED and turns < 20:
				if policy == "greedy":
					SimPolicy.play_turn(combat)
				else:
					SmartPolicy.play_turn(combat)
				turns += 1
		_check(counts["marked"] > 0 and counts["spent"] > 0, "%s plays Catch the Scent (%d) and Run Down (%d) from the real starting deck" % [policy, counts["marked"], counts["spent"]])
