extends RefCounted
## Scent, the Stray's mark (docs/CLASSES_PLAN.md, the Stray, phase 2): a stack of at most 8 on one enemy that
## adds to every hit the player's cards land on it. Fixtures are hand-made cards. Discovered by run_tests.gd.

const K := CardEffect.Kind
const SCENT := Combatant.Status.SCENT

var _failures := 0


func run() -> int:
	_failures = 0
	_test_status_rules()
	_test_hit_bonus()
	_test_bonus_on_every_hit()
	_test_enemies_are_unaffected()
	_test_one_quarry()
	_test_multi_target_card_marks_one()
	_test_spender()
	_test_quarry_death_passes_half_on()
	_test_quarry_death_to_haunt_and_oath()
	_test_intents_cannot_apply_scent()
	_test_text_and_values()
	_test_preview_context()
	return _failures


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAIL: " + label)


func _fx(kind: K, amount: int, bonus: int = 0, hits: int = 1) -> CardEffect:
	return CardEffect.make(kind, amount, bonus, 0, hits)


func _card(cost: int, effects: Array[CardEffect], mode: CardData.TargetMode = CardData.TargetMode.SINGLE_ENEMY) -> CardData:
	return CardData.make(&"t", "T", cost, effects, mode)


func _fight(hand: Array[CardData], enemy_count: int = 1, enemy_hp: int = 100, seed_value: int = 1) -> Combat:
	var enemies: Array[EnemyData] = []
	for i in enemy_count:
		enemies.append(EnemyData.make("E%d" % i, enemy_hp, [] as Array[CardEffect]))
	var combat := Combat.new(Combatant.new("p", 40), hand, enemies, seed_value)
	combat.start()
	return combat


func _play(combat: Combat, card: CardData, target: int = 0) -> bool:
	return combat.play_card(combat.piles.hand.find(card), target)


func _test_status_rules() -> void:
	_check(Combatant.status_kind(SCENT) == Combatant.StatusKind.STACK, "Scent is a stack status")
	var enemy := Combatant.new("e", 10)
	enemy.apply_status(SCENT, 3)
	enemy.apply_status(SCENT, 4)
	_check(enemy.stacks(SCENT) == 7, "Scent stacks")
	enemy.apply_status(SCENT, 5)
	_check(enemy.stacks(SCENT) == Combatant.SCENT_CAP and Combatant.SCENT_CAP == 8, "Scent stops at the cap of 8")
	enemy.tick_statuses()
	_check(enemy.stacks(SCENT) == 8, "Scent never ticks down")
	enemy.apply_status(SCENT, -20)
	_check(enemy.stacks(SCENT) == 0, "Scent is never negative")
	enemy.apply_status(SCENT, 2)
	enemy.remove_status(SCENT)
	_check(enemy.stacks(SCENT) == 0, "remove_status clears it")
	enemy.apply_status(SCENT, 2)
	enemy.clear_statuses()
	_check(enemy.stacks(SCENT) == 0, "clear_statuses clears it")


func _test_hit_bonus() -> void:
	var player := Combatant.new("p", 40)
	var enemy := Combatant.new("e", 100)
	_check(Combatant.hit_damage(5, player, enemy) == 5, "no Scent, no bonus")
	enemy.apply_status(SCENT, 3)
	_check(Combatant.hit_damage(5, player, enemy) == 8, "Scent 3 adds 3 to a hit of 5")
	_check(Combatant.hit_damage(0, player, enemy) == 0, "a hit of 0 stays 0")
	player.apply_status(Combatant.Status.MALICE, 2)
	_check(Combatant.hit_damage(5, player, enemy) == 10, "Malice and Scent both add: 5 + 2 + 3")
	player.apply_status(Combatant.Status.SHAKEN, 1)
	_check(Combatant.hit_damage(5, player, enemy) == 7, "Shaken then cuts the sum: (5 + 2 + 3) x 3/4")
	enemy.apply_status(Combatant.Status.EXPOSED, 1)
	_check(Combatant.hit_damage(5, player, enemy) == 10, "Expose comes last: 7 x 3/2")


func _test_bonus_on_every_hit() -> void:
	var flurry := _card(1, [_fx(K.DAMAGE, 4, 0, 3)] as Array[CardEffect])
	var mark := _card(0, [_fx(K.SCENT, 2)] as Array[CardEffect])
	var combat := _fight([mark, flurry])
	_play(combat, mark)
	_play(combat, flurry)
	_check(combat.enemies[0].hp == 100 - 3 * (4 + 2), "each of three hits gets the +2: 18 damage (hp %d)" % combat.enemies[0].hp)
	_check(combat.enemies[0].stacks(SCENT) == 2, "an ordinary attack does not use the Scent up")


func _test_enemies_are_unaffected() -> void:
	var enemy_hits: Array[CardEffect] = [_fx(K.DAMAGE, 6)]
	var enemies: Array[EnemyData] = [EnemyData.make("E", 100, enemy_hits)]
	var mark := _card(0, [_fx(K.SCENT, 5)] as Array[CardEffect])
	var combat := Combat.new(Combatant.new("p", 40), [mark] as Array[CardData], enemies, 1)
	combat.start()
	_play(combat, mark)
	combat.end_player_turn()
	_check(combat.player.hp == 34, "enemy attacks do not get the Scent bonus (hp %d)" % combat.player.hp)


func _test_one_quarry() -> void:
	var mark_a := _card(0, [_fx(K.SCENT, 3)] as Array[CardEffect])
	var mark_b := _card(0, [_fx(K.SCENT, 2)] as Array[CardEffect])
	var combat := _fight([mark_a, mark_b], 2)
	_play(combat, mark_a, 0)
	_check(combat.enemies[0].stacks(SCENT) == 3 and combat.enemies[1].stacks(SCENT) == 0, "the first card marks enemy 0")
	_play(combat, mark_b, 1)
	_check(combat.enemies[0].stacks(SCENT) == 0 and combat.enemies[1].stacks(SCENT) == 5, "marking enemy 1 moves the whole stack: 3 + 2")
	var cap_a := _card(0, [_fx(K.SCENT, 6)] as Array[CardEffect])
	var cap_b := _card(0, [_fx(K.SCENT, 6)] as Array[CardEffect])
	var cap := _fight([cap_a, cap_b], 2)
	_play(cap, cap_a, 0)
	_play(cap, cap_b, 1)
	_check(cap.enemies[1].stacks(SCENT) == 8 and cap.enemies[0].stacks(SCENT) == 0, "a moved stack is still capped at 8")


func _test_multi_target_card_marks_one() -> void:
	var howl := _card(0, [_fx(K.SCENT, 2)] as Array[CardEffect], CardData.TargetMode.ALL_ENEMIES)
	var combat := _fight([howl], 3)
	_play(combat, howl)
	_check(combat.enemies[0].stacks(SCENT) == 2 and combat.enemies[1].stacks(SCENT) == 0 and combat.enemies[2].stacks(SCENT) == 0, "an all-enemies Scent card marks only the first living enemy")
	var again := _card(0, [_fx(K.SCENT, 1)] as Array[CardEffect], CardData.TargetMode.ALL_ENEMIES)
	var first_mark := _card(0, [_fx(K.SCENT, 3)] as Array[CardEffect])
	var combat2 := _fight([first_mark, again], 3)
	_play(combat2, first_mark, 2)
	_play(combat2, again)
	_check(combat2.enemies[2].stacks(SCENT) == 4 and combat2.enemies[0].stacks(SCENT) == 0, "and it adds to the current quarry when that is among the targets")


func _test_spender() -> void:
	var mark := _card(0, [_fx(K.SCENT, 3)] as Array[CardEffect])
	var run_down := _card(1, [_fx(K.DAMAGE_PER_SCENT, 4, 3)] as Array[CardEffect])
	var combat := _fight([mark, run_down])
	_play(combat, mark)
	_play(combat, run_down)
	# raw 4 + 3x3 = 13, plus the +3 passive bonus, all in one hit; then the Scent is gone.
	_check(combat.enemies[0].hp == 100 - 16, "a spender deals amount + bonus x Scent plus the passive bonus (hp %d)" % combat.enemies[0].hp)
	_check(combat.enemies[0].stacks(SCENT) == 0, "and uses the Scent up")
	var multi := _card(1, [_fx(K.DAMAGE_PER_SCENT, 2, 1, 2)] as Array[CardEffect])
	var mark2 := _card(0, [_fx(K.SCENT, 4)] as Array[CardEffect])
	var c2 := _fight([mark2, multi])
	_play(c2, mark2)
	_play(c2, multi)
	# each hit: 2 + 1x4 = 6, plus 4 passive = 10; two hits both see the full Scent.
	_check(c2.enemies[0].hp == 100 - 20 and c2.enemies[0].stacks(SCENT) == 0, "a multi-hit spender gives every hit the full Scent, then spends it (hp %d)" % c2.enemies[0].hp)
	var bare_card := _card(1, [_fx(K.DAMAGE_PER_SCENT, 4, 3)] as Array[CardEffect])
	var bare := _fight([bare_card])
	_play(bare, bare_card, 0)
	_check(bare.enemies[0].hp == 96, "a spender with no Scent is just its base damage")


func _test_quarry_death_passes_half_on() -> void:
	# Killed by a card: Scent 5 passes 2 to the only other enemy.
	var kill := _card(0, [_fx(K.DAMAGE, 9)] as Array[CardEffect])
	var mark := _card(0, [_fx(K.SCENT, 5)] as Array[CardEffect])
	var enemies: Array[EnemyData] = [EnemyData.make("A", 5, [] as Array[CardEffect]), EnemyData.make("B", 100, [] as Array[CardEffect])]
	var combat := Combat.new(Combatant.new("p", 40), [mark, kill] as Array[CardData], enemies, 1)
	combat.start()
	_play(combat, mark, 0)
	_play(combat, kill, 0)
	_check(combat.enemies[0].is_dead() and combat.enemies[0].stacks(SCENT) == 0, "the dead quarry holds no Scent")
	_check(combat.enemies[1].stacks(SCENT) == 2, "half of 5, rounded down, passes to the survivor (%d)" % combat.enemies[1].stacks(SCENT))
	# A stack of 1 is lost.
	var one_mark := _card(0, [_fx(K.SCENT, 1)] as Array[CardEffect])
	var one_kill := _card(0, [_fx(K.DAMAGE, 20)] as Array[CardEffect])
	var c1 := Combat.new(Combatant.new("p", 40), [one_mark, one_kill] as Array[CardData], [EnemyData.make("A", 5, [] as Array[CardEffect]), EnemyData.make("B", 100, [] as Array[CardEffect])] as Array[EnemyData], 1)
	c1.start()
	_play(c1, one_mark, 0)
	_play(c1, one_kill, 0)
	_check(c1.enemies[1].stacks(SCENT) == 0, "a stack of 1 halves to 0 and is lost")
	# With two survivors the heir is one of them, and the same seed picks the same one.
	var heirs := []
	for run_index in 2:
		var three_enemies: Array[EnemyData] = [EnemyData.make("A", 5, [] as Array[CardEffect]), EnemyData.make("B", 100, [] as Array[CardEffect]), EnemyData.make("C", 100, [] as Array[CardEffect])]
		var big_mark := _card(0, [_fx(K.SCENT, 8)] as Array[CardEffect])
		var big_kill := _card(0, [_fx(K.DAMAGE, 20)] as Array[CardEffect])
		var c3 := Combat.new(Combatant.new("p", 40), [big_mark, big_kill] as Array[CardData], three_enemies, 7)
		c3.start()
		_play(c3, big_mark, 0)
		_play(c3, big_kill, 0)
		var held := [c3.enemies[1].stacks(SCENT), c3.enemies[2].stacks(SCENT)]
		_check(held in [[4, 0], [0, 4]], "with two survivors exactly one gets the 4 (%s)" % str(held))
		heirs.append(held)
	_check(heirs[0] == heirs[1], "the heir comes from the seeded RNG, so the same seed picks the same enemy")
	# No survivor: the fight is simply won.
	var last_mark := _card(0, [_fx(K.SCENT, 4)] as Array[CardEffect])
	var last_kill := _card(0, [_fx(K.DAMAGE, 200)] as Array[CardEffect])
	var last := _fight([last_mark, last_kill], 1, 10)
	_play(last, last_mark, 0)
	_play(last, last_kill, 0)
	_check(last.phase == Combat.Phase.ENDED, "killing the last enemy ends the fight with no error")


func _test_quarry_death_to_haunt_and_oath() -> void:
	# Haunt kills the quarry at the start of the enemy phase.
	var mark := _card(0, [_fx(K.SCENT, 6)] as Array[CardEffect])
	var haunt := _card(0, [_fx(K.HAUNT, 9)] as Array[CardEffect])
	var enemies: Array[EnemyData] = [EnemyData.make("A", 5, [] as Array[CardEffect]), EnemyData.make("B", 100, [] as Array[CardEffect])]
	var combat := Combat.new(Combatant.new("p", 40), [mark, haunt] as Array[CardData], enemies, 1)
	combat.start()
	_play(combat, mark, 0)
	_play(combat, haunt, 0)
	combat.end_player_turn()
	_check(combat.enemies[0].is_dead() and combat.enemies[1].stacks(SCENT) == 3, "a Haunt kill passes half on too (%d)" % combat.enemies[1].stacks(SCENT))
	# An oath can mark the quarry each turn: it does not scatter Scent across enemies.
	var oath := CardData.make(&"o", "O", 0, [] as Array[CardEffect], CardData.TargetMode.SELF)
	oath.oath = true
	oath.oath_trigger = CardData.OathTrigger.TURN_START
	oath.oath_effects = [_fx(K.SCENT, 1)] as Array[CardEffect]
	var combat2 := _fight([oath, _card(0, [_fx(K.BLOCK, 0)] as Array[CardEffect])], 2)
	_play(combat2, oath)
	combat2.end_player_turn()
	combat2.end_player_turn()
	var held := [combat2.enemies[0].stacks(SCENT), combat2.enemies[1].stacks(SCENT)]
	_check(held == [2, 0], "an Oath's Scent keeps marking the same quarry (%s)" % str(held))


func _test_intents_cannot_apply_scent() -> void:
	var intents: Array[CardEffect] = [_fx(K.SCENT, 5)]
	var enemies: Array[EnemyData] = [EnemyData.make("E", 100, intents)]
	var combat := Combat.new(Combatant.new("p", 40), [_card(0, [_fx(K.BLOCK, 1)] as Array[CardEffect])] as Array[CardData], enemies, 1)
	combat.start()
	combat.end_player_turn()
	_check(combat.player.stacks(SCENT) == 0 and combat.enemies[0].stacks(SCENT) == 0, "an enemy intent with Scent does nothing")


func _test_text_and_values() -> void:
	_check(_fx(K.SCENT, 2).describe() == "Scent 2", "Scent text")
	_check(_fx(K.DAMAGE_PER_SCENT, 4, 3).describe() == "Deal 4, +3 per Scent (spends it)", "spender text")
	_check(_fx(K.SCENT, 2).reach() == CardEffect.Reach.ENEMIES, "Scent reaches enemies")
	_check(_fx(K.DAMAGE_PER_SCENT, 4, 3).is_damage(), "the spender is a damage kind")
	_check(Vendor.effect_value(_fx(K.SCENT, 2)) > 0 and Vendor.effect_value(_fx(K.DAMAGE_PER_SCENT, 4, 3)) > 4, "Scent and the spender have a vendor value")
	_check(Combatant.Status.SCENT == 6, "Scent is appended after Ward")


func _test_preview_context() -> void:
	var ctx := EffectContext.make(0, 0, 1, 0, 5)
	_check(ctx.scent == 5 and EffectContext.make(0, 0, 1).scent == 0, "EffectContext carries the target's Scent (default 0)")
	_check(_fx(K.DAMAGE_PER_SCENT, 4, 3).raw_damage(ctx) == 19, "raw damage of a spender reads it: 4 + 3 x 5")
