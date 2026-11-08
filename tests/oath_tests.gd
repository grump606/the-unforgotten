extends RefCounted
## Oaths (docs/MECHANICS_PLAN.md, phase 6a): a card played once that stays Sworn for the fight and fires
## its oath_effects on a trigger. Fixtures are hand-made cards, so these are the rules, not card tuning.
## Discovered by run_tests.gd.

const K := CardEffect.Kind
const T := CardData.OathTrigger

var _failures := 0


func run() -> int:
	_failures = 0
	_test_play_goes_to_sworn()
	_test_sworn_is_per_fight()
	_test_play_effects_still_happen()
	_test_turn_start()
	_test_stacks_when_sworn_twice()
	_test_first_play_each_turn()
	_test_forgotten_trigger()
	_test_fading_counts_as_forgotten()
	_test_anchor_kept()
	_test_reach_of_oath_effects()
	_test_turn_start_hp_loss_can_end_the_fight()
	_test_turn_start_glimpse_opens_a_choice()
	_test_text_and_variant()
	_test_validity()
	return _failures


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAIL: " + label)


func _fx(kind: K, amount: int) -> CardEffect:
	return CardEffect.make(kind, amount)


func _oath(trigger: T, sworn_effects: Array[CardEffect], now: Array[CardEffect] = [], cost: int = 1) -> CardData:
	var card := CardData.make(&"oath", "Oath", cost, now, CardData.TargetMode.SELF)
	card.oath = true
	card.oath_trigger = trigger
	card.oath_effects = sworn_effects
	return card


func _filler(effects: Array[CardEffect] = []) -> CardData:
	return CardData.make(&"filler", "Filler", 0, effects, CardData.TargetMode.SELF)


func _enemy_list(count: int, hp: int) -> Array[EnemyData]:
	var list: Array[EnemyData] = []
	for i in count:
		list.append(EnemyData.make("E%d" % i, hp, []))
	return list


func _fight(deck: Array[CardData], enemy_count: int = 1, enemy_hp: int = 100, player_hp: int = 40) -> Combat:
	var combat := Combat.new(Combatant.new("p", player_hp), deck, _enemy_list(enemy_count, enemy_hp))
	combat.start()
	return combat


func _play(combat: Combat, card: CardData, target: int = 0) -> bool:
	return combat.play_card(combat.piles.hand.find(card), target)


func _test_play_goes_to_sworn() -> void:
	var oath := _oath(T.TURN_START, [_fx(K.BLOCK, 3)])
	var combat := _fight([oath, _filler()])
	_check(_play(combat, oath), "an Oath can be played")
	_check(combat.piles.sworn == [oath], "it is Sworn")
	_check(not combat.piles.discard_pile.has(oath) and not combat.piles.forgotten.has(oath) and not combat.piles.hand.has(oath), "and in no other pile")
	_check(combat.energy == Combat.ENERGY_PER_TURN - 1, "it cost its energy")
	# A Forgotten Oath still goes to Sworn.
	var both := _oath(T.TURN_START, [_fx(K.BLOCK, 1)])
	both.forgotten = true
	var c2 := _fight([both])
	_play(c2, both)
	_check(c2.piles.sworn == [both] and c2.piles.forgotten.is_empty(), "an Oath is Sworn even when it is also marked Forgotten")


func _test_sworn_is_per_fight() -> void:
	var oath := _oath(T.TURN_START, [_fx(K.BLOCK, 3)])
	var deck: Array[CardData] = [oath]
	var first := _fight(deck)
	_play(first, oath)
	_check(deck == [oath], "the deck array is untouched")
	var second := _fight(deck)
	_check(second.piles.sworn.is_empty() and second.piles.hand.has(oath), "next fight starts with nothing Sworn and the Oath back in the deck")


func _test_play_effects_still_happen() -> void:
	var oath := _oath(T.TURN_START, [_fx(K.BLOCK, 3)], [_fx(K.LOSE_HP, 4)])
	var combat := _fight([oath])
	_play(combat, oath)
	_check(combat.player.hp == 36, "the Oath's own effects (its cost) happen when it is played")
	_check(combat.player.block == 0, "its oath effects do not")


func _test_turn_start() -> void:
	var oath := _oath(T.TURN_START, [_fx(K.BLOCK, 3), _fx(K.MALICE, 1)])
	var combat := _fight([oath, _filler()])
	_play(combat, oath)
	_check(combat.player.block == 0, "nothing fires on the turn it was sworn")
	combat.end_player_turn()
	_check(combat.player.block == 3, "at the next turn start it gives Block 3 (after Block resets)")
	_check(combat.player.status_turns(Combatant.Status.MALICE) == 1, "and Malice 1")
	combat.end_player_turn()
	_check(combat.player.block == 3 and combat.player.status_turns(Combatant.Status.MALICE) == 2, "and again every turn, Malice stacking")


func _test_stacks_when_sworn_twice() -> void:
	var a := _oath(T.TURN_START, [_fx(K.BLOCK, 2)], [], 0)
	var b := _oath(T.TURN_START, [_fx(K.BLOCK, 2)], [], 0)
	var combat := _fight([a, b, _filler()])
	_play(combat, a)
	_play(combat, b)
	combat.end_player_turn()
	_check(combat.piles.sworn.size() == 2 and combat.player.block == 4, "two copies sworn fire twice")


func _test_first_play_each_turn() -> void:
	var oath := _oath(T.FIRST_PLAY, [_fx(K.BLOCK, 2)], [], 0)
	var f1 := _filler()
	var f2 := _filler()
	var combat := _fight([oath, f1, f2])
	_play(combat, oath)
	_check(combat.player.block == 0, "the Oath does not trigger on its own play")
	_play(combat, f1)
	_check(combat.player.block == 0, "it is not the first play of the turn any more")
	combat.end_player_turn()
	_play(combat, combat.piles.hand[0])
	_check(combat.player.block == 2, "the first card played next turn triggers it")
	_play(combat, combat.piles.hand[0])
	_check(combat.player.block == 2, "the second card does not")


func _test_forgotten_trigger() -> void:
	var oath := _oath(T.ON_FORGOTTEN, [_fx(K.DAMAGE, 2)], [], 0)
	var gone := _filler()
	gone.forgotten = true
	var plain := _filler()
	var combat := _fight([oath, gone, plain], 2)
	_play(combat, oath)
	_play(combat, plain)
	_check(combat.enemies[0].hp == 100 and combat.enemies[1].hp == 100, "a card that is not Forgotten does not fire it")
	_play(combat, gone)
	_check(combat.enemies[0].hp == 98 and combat.enemies[1].hp == 98, "a Forgotten card deals 2 to every enemy")


func _test_fading_counts_as_forgotten() -> void:
	var oath := _oath(T.ON_FORGOTTEN, [_fx(K.DAMAGE, 1)], [], 0)
	var f1 := _filler()
	f1.fading = true
	var f2 := _filler()
	f2.fading = true
	var combat := _fight([oath, f1, f2])
	_play(combat, oath)
	combat.end_player_turn()
	_check(combat.piles.forgotten.size() == 2, "setup: two Fading cards were lost")
	_check(combat.enemies[0].hp == 98, "each Fading card lost at end of turn fires it once")


func _test_anchor_kept() -> void:
	var oath := _oath(T.ANCHOR_KEPT, [_fx(K.DAMAGE, 3)], [], 0)
	var held1 := _filler()
	held1.anchor = true
	var held2 := _filler()
	held2.anchor = true
	var plain := _filler()
	var combat := _fight([oath, held1, held2, plain])
	_play(combat, oath)
	combat.end_player_turn()
	_check(combat.enemies[0].hp == 94, "each Anchor card kept fires it once (3 x 2)")


func _test_reach_of_oath_effects() -> void:
	var oath := _oath(T.TURN_START, [_fx(K.HAUNT, 2), _fx(K.SHAKEN, 1), _fx(K.MALICE, 1)], [], 0)
	var combat := _fight([oath, _filler()], 2)
	_play(combat, oath)
	combat.end_player_turn()
	for enemy in combat.enemies:
		_check(enemy.status_turns(Combatant.Status.HAUNTED) == 2 and enemy.status_turns(Combatant.Status.SHAKEN) == 1, "enemy-reaching effects land on every living enemy")
		_check(enemy.status_turns(Combatant.Status.MALICE) == 0, "a self effect never lands on an enemy")
	_check(combat.player.status_turns(Combatant.Status.MALICE) == 1, "a self effect lands on the player")
	# Oath damage can win the fight at turn start.
	var killer := _oath(T.TURN_START, [_fx(K.DAMAGE, 50)], [], 0)
	var one_shot := _fight([killer, _filler()], 2, 30)
	_play(one_shot, killer)
	one_shot.end_player_turn()
	_check(one_shot.phase == Combat.Phase.ENDED and one_shot.living_enemies().is_empty(), "oath damage can win the fight at turn start")


func _test_turn_start_hp_loss_can_end_the_fight() -> void:
	var oath := _oath(T.TURN_START, [_fx(K.LOSE_HP, 5)], [], 0)
	var combat := _fight([oath, _filler()], 1, 100, 11)
	var result := {"victory": true, "fired": false}
	combat.combat_ended.connect(func(victory: bool) -> void:
		result["victory"] = victory
		result["fired"] = true)
	_play(combat, oath)
	combat.end_player_turn()
	combat.end_player_turn()
	_check(combat.player.hp == 1 and combat.phase == Combat.Phase.PLAYER_TURN, "two turns of 5 HP lost leave the player at 1")
	combat.end_player_turn()
	_check(combat.phase == Combat.Phase.ENDED and bool(result["fired"]) and not bool(result["victory"]), "losing the last HP at turn start is a defeat")


func _test_turn_start_glimpse_opens_a_choice() -> void:
	var oath := _oath(T.TURN_START, [_fx(K.GLIMPSE, 2)], [], 0)
	var deck: Array[CardData] = [oath]
	for i in 8:
		deck.append(_filler())
	var combat := _fight(deck)
	_play(combat, oath)
	combat.end_player_turn(_discard_all(combat))
	_check(combat.has_choice() and combat.phase == Combat.Phase.CHOOSING, "a Glimpse from an Oath opens its pick after the hand is dealt")
	_check(combat.auto_resolve_choice() and combat.phase == Combat.Phase.PLAYER_TURN, "and resolves back to the turn")


func _discard_all(combat: Combat) -> Array[int]:
	var picks: Array[int] = []
	for i in combat.piles.hand.size():
		if combat.can_discard_card(i):
			picks.append(i)
	return picks


func _test_text_and_variant() -> void:
	var oath := _oath(T.TURN_START, [_fx(K.BLOCK, 3)], [_fx(K.LOSE_HP, 4)])
	_check(oath.keyword_lines() == PackedStringArray(["Oath"]), "an Oath has the Oath keyword line")
	_check(oath.describe() == "Lose 4 HP. At turn start: Block 3", "describe() reads the play effects then the trigger")
	var quiet := _oath(T.ON_FORGOTTEN, [_fx(K.DAMAGE, 2)])
	_check(quiet.describe() == "When a card is Forgotten: Deal 2", "an Oath with no play effects reads only the trigger")
	oath.remembered = RememberedData.make([_fx(K.LOSE_HP, 2)], -1)
	var plus := oath.remembered_card()
	_check(plus.oath and plus.oath_trigger == T.TURN_START and plus.oath_effects == oath.oath_effects, "a Remembered Oath keeps its oath and effects by default")
	var other := _oath(T.TURN_START, [_fx(K.BLOCK, 3)], [_fx(K.LOSE_HP, 4)])
	other.remembered = RememberedData.make([_fx(K.LOSE_HP, 2)], -1)
	other.remembered.oath_effects = [_fx(K.BLOCK, 5)]
	var stronger := other.remembered_card()
	_check(stronger.oath_effects[0].amount == 5 and other.oath_effects[0].amount == 3, "the Remembered block can replace the oath effects without touching the base")


func _test_validity() -> void:
	var good := _oath(T.TURN_START, [_fx(K.BLOCK, 1)])
	_check(good.is_valid_oath(), "a plain Oath with effects is valid")
	good.fading = true
	_check(not good.is_valid_oath(), "a Fading Oath is not")
	good.fading = false
	good.dormant = true
	_check(not good.is_valid_oath(), "a Dormant Oath is not")
	_check(not _oath(T.TURN_START, []).is_valid_oath(), "an Oath that does nothing is not")
	_check(not _filler().is_valid_oath(), "a non-Oath is not an Oath")
	for card in StarterContent.all_cards():
		_check(not card.oath or card.is_valid_oath(), "%s: a shipped Oath is valid" % card.id)
