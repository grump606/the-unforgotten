extends RefCounted
## The five new Oath triggers (end of turn, Block gained, HP paid, each card played, a card discarded) and the
## "when discarded" card effects, plus the five Oaths and three Thief cards that use them (cards step 3).
## Discovered by run_tests.gd.

const K := CardEffect.Kind
const T := CardData.OathTrigger

var _failures := 0


func run() -> int:
	_failures = 0
	_test_enum_is_appended()
	_test_end_of_turn()
	_test_each_play()
	_test_block_gained()
	_test_hp_lost()
	_test_on_discard_oath()
	_test_discard_effects()
	_test_quarry_dies()
	_test_text_and_keyword()
	_test_shipped_cards()
	_test_bots()
	return _failures


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAIL: " + label)


func _fx(kind: K, amount: int) -> CardEffect:
	return CardEffect.make(kind, amount)


func _oath(trigger: T, sworn: Array[CardEffect], now: Array[CardEffect] = [], cost: int = 0) -> CardData:
	var card := CardData.make(&"oath", "Oath", cost, now, CardData.TargetMode.SELF)
	card.oath = true
	card.oath_trigger = trigger
	card.oath_effects = sworn
	return card


func _plain(effects: Array[CardEffect] = [], cost: int = 0) -> CardData:
	return CardData.make(&"plain", "Plain", cost, effects, CardData.TargetMode.SELF)


func _fight(hand: Array[CardData], enemy_count: int = 1) -> Combat:
	var enemies: Array[EnemyData] = []
	for i in enemy_count:
		enemies.append(EnemyData.make("E%d" % i, 100, [] as Array[CardEffect]))
	var combat := Combat.new(Combatant.new("p", 40), hand, enemies, 1)
	combat.start()
	return combat


func _play(combat: Combat, card: CardData, target: int = 0) -> bool:
	return combat.play_card(combat.piles.hand.find(card), target)


func _test_enum_is_appended() -> void:
	_check(T.TURN_START == 0 and T.FIRST_PLAY == 1 and T.ON_FORGOTTEN == 2 and T.ANCHOR_KEPT == 3, "the original triggers keep their numbers")
	_check(T.END_OF_TURN == 4 and T.ON_BLOCK_GAINED == 5 and T.ON_HP_LOST == 6 and T.EACH_PLAY == 7 and T.ON_DISCARD == 8 and T.QUARRY_DIES == 9, "the new triggers are appended in order")
	for trigger in T.values():
		var oath := _oath(trigger, [_fx(K.BLOCK, 1)])
		_check(oath.oath_trigger_text() != "", "trigger %d has text" % trigger)
		_check(float(SmartPolicy.OATH_FIRING_SHARE[trigger]) > 0.0, "the smart bot has a firing share for trigger %d" % trigger)


func _test_end_of_turn() -> void:
	var oath := _oath(T.END_OF_TURN, [_fx(K.BLOCK, 4)])
	var enemies: Array[EnemyData] = [EnemyData.make("E", 100, [_fx(K.DAMAGE, 6)] as Array[CardEffect])]
	var combat := Combat.new(Combatant.new("p", 40), [oath, _plain()] as Array[CardData], enemies, 1)
	combat.start()
	_play(combat, oath)
	combat.end_player_turn()
	_check(combat.player.hp == 38, "end-of-turn Block 4 is up before the enemy hits for 6 (hp %d)" % combat.player.hp)
	var turn_one_block := combat.player.block
	_check(turn_one_block == 0, "and was spent (Block %d)" % turn_one_block)


func _test_each_play() -> void:
	var oath := _oath(T.EACH_PLAY, [_fx(K.DAMAGE, 1)])
	var a := _plain()
	var b := _plain()
	var c := _plain()
	var combat := _fight([oath, a, b, c], 2)
	_play(combat, oath)
	_check(combat.enemies[0].hp == 100, "the Oath does not trigger on its own play")
	_play(combat, a)
	_play(combat, b)
	_play(combat, c)
	_check(combat.enemies[0].hp == 97 and combat.enemies[1].hp == 97, "each of three plays deals 1 to every enemy")


func _test_block_gained() -> void:
	var oath := _oath(T.ON_BLOCK_GAINED, [_fx(K.DAMAGE, 3)])
	var guard := _plain([_fx(K.BLOCK, 5)])
	var other := _plain([_fx(K.DRAW, 1)])
	var combat := _fight([oath, guard, other])
	_play(combat, oath)
	_play(combat, other)
	_check(combat.enemies[0].hp == 100, "a card that gains no Block does not trigger it")
	_play(combat, guard)
	_check(combat.enemies[0].hp == 97, "a card that gains Block deals 3 (hp %d)" % combat.enemies[0].hp)
	var zero_oath := _oath(T.ON_BLOCK_GAINED, [_fx(K.DAMAGE, 3)])
	var zero_card := _plain([_fx(K.BLOCK, 0)])
	var zero := _fight([zero_oath, zero_card])
	_play(zero, zero_oath)
	_play(zero, zero_card)
	_check(zero.enemies[0].hp == 100, "a Block 0 card gains nothing, so it does not trigger it")


func _test_hp_lost() -> void:
	var oath := _oath(T.ON_HP_LOST, [_fx(K.HAUNT, 2)])
	var costly := _plain([_fx(K.LOSE_HP, 3)])
	var free := _plain()
	var combat := _fight([oath, costly, free])
	_play(combat, oath)
	_play(combat, free)
	_check(combat.enemies[0].status_turns(Combatant.Status.HAUNTED) == 0, "a card that costs no HP does not trigger it")
	_play(combat, costly)
	_check(combat.enemies[0].status_turns(Combatant.Status.HAUNTED) == 2 and combat.player.hp == 37, "a card that costs HP Haunts every enemy")
	# The Oath's own HP cost, paid when it is sworn, does not trigger itself.
	var self_cost := _oath(T.ON_HP_LOST, [_fx(K.HAUNT, 2)], [_fx(K.LOSE_HP, 2)])
	var c2 := _fight([self_cost])
	_play(c2, self_cost)
	_check(c2.enemies[0].status_turns(Combatant.Status.HAUNTED) == 0, "an Oath's own cost does not trigger it")


func _test_on_discard_oath() -> void:
	var oath := _oath(T.ON_DISCARD, [_fx(K.DAMAGE, 2)])
	var spare_one := _plain()
	var spare_two := _plain()
	var combat := _fight([oath, spare_one, spare_two])
	_play(combat, oath)
	combat.end_player_turn([0, 1] as Array[int])
	_check(combat.enemies[0].hp == 96, "each discarded card deals 2 (hp %d)" % combat.enemies[0].hp)
	var kept_oath := _oath(T.ON_DISCARD, [_fx(K.DAMAGE, 2)])
	var kept := _fight([kept_oath, _plain()])
	_play(kept, kept_oath)
	kept.end_player_turn()
	_check(kept.enemies[0].hp == 100, "kept cards are not discarded, so nothing fires")


func _test_quarry_dies() -> void:
	var oath := _oath(T.QUARRY_DIES, [_fx(K.SCENT, 2), _fx(K.BLOCK, 3)])
	var mark := CardData.make(&"mark", "Mark", 0, [_fx(K.SCENT, 4)] as Array[CardEffect])
	var kill := CardData.make(&"kill", "Kill", 0, [_fx(K.DAMAGE, 50)] as Array[CardEffect])
	var list: Array[EnemyData] = [EnemyData.make("A", 5, [] as Array[CardEffect]), EnemyData.make("B", 100, [] as Array[CardEffect])]
	var combat := Combat.new(Combatant.new("p", 40), [oath, mark, kill] as Array[CardData], list, 3)
	combat.start()
	_play(combat, oath)
	_play(combat, mark)
	_play(combat, kill)
	# Half of 4 passes on (2) and the Oath adds 2 more; it also gives Block 3.
	_check(combat.enemies[0].is_dead() and combat.enemies[1].stacks(Combatant.Status.SCENT) == 4, "the quarry's death passes Scent 2 and the Oath adds 2 (got %d)" % combat.enemies[1].stacks(Combatant.Status.SCENT))
	_check(combat.player.block == 3, "the Oath's Block 3 lands when the quarry dies")
	# A death with no Scent on the dead enemy fires nothing.
	var oath2 := _oath(T.QUARRY_DIES, [_fx(K.BLOCK, 3)])
	var c2 := Combat.new(Combatant.new("p", 40), [oath2, kill] as Array[CardData], [EnemyData.make("A", 5, [] as Array[CardEffect]), EnemyData.make("B", 100, [] as Array[CardEffect])] as Array[EnemyData], 3)
	c2.start()
	_play(c2, oath2)
	_play(c2, kill)
	_check(c2.player.block == 0, "a death with no Scent on the dead enemy fires nothing")


func _test_discard_effects() -> void:
	var thrown := _plain()
	thrown.discard_effects = [_fx(K.BLOCK, 4)]
	var combat := Combat.new(Combatant.new("p", 40), [thrown, _plain()] as Array[CardData], [EnemyData.make("E", 100, [_fx(K.DAMAGE, 6)] as Array[CardEffect])] as Array[EnemyData], 1)
	combat.start()
	combat.end_player_turn([combat.piles.hand.find(thrown)] as Array[int])
	_check(combat.player.hp == 40 - 2, "a discarded card's Block 4 is up before the enemy hits for 6 (hp %d)" % combat.player.hp)
	# Played, it does nothing special.
	var played := _plain([_fx(K.DRAW, 1)])
	played.discard_effects = [_fx(K.BLOCK, 4)]
	var c2 := _fight([played, _plain()])
	_play(c2, played)
	c2.end_player_turn()
	_check(c2.player.hp == 40 and c2.player.block == 0, "a card that was played does not fire its discard effects")
	# Kept, nothing happens.
	var kept := _plain()
	kept.discard_effects = [_fx(K.DAMAGE, 5)]
	var c3 := _fight([kept])
	c3.end_player_turn()
	_check(c3.enemies[0].hp == 100, "a kept card does not fire its discard effects")
	# Draw: the card drawn at the end of the turn joins the hand, so with five kept cards the next hand has six.
	var hand_sizes := []
	for with_draw in [false, true]:
		var thrown_card := _plain()
		if with_draw:
			thrown_card.discard_effects = [_fx(K.DRAW, 1)]
		var drawing := _plain([_fx(K.DRAW, 1)])
		var deck: Array[CardData] = [drawing, thrown_card]
		for i in 10:
			deck.append(_plain())
		var fight := Combat.new(Combatant.new("p", 40), deck, _enemy_list(1), 3)
		fight.start()
		# Make sure both cards are in the opening hand, then draw one more so six are held.
		fight.piles.hand.assign([drawing, thrown_card, _plain(), _plain(), _plain(), _plain()] as Array[CardData])
		fight.play_card(0, 0)
		fight.end_player_turn([fight.piles.hand.find(thrown_card)] as Array[int])
		hand_sizes.append(fight.piles.hand.size())
	_check(hand_sizes[1] == hand_sizes[0] + 1, "a discarded card's Draw 1 gives a bigger next hand when five are kept (%s)" % str(hand_sizes))
	# A Scent effect marks the quarry (one enemy).
	var marker := _plain()
	marker.discard_effects = [_fx(K.SCENT, 2)]
	var c5 := _fight([marker], 2)
	c5.end_player_turn([0] as Array[int])
	_check(c5.enemies[0].stacks(Combatant.Status.SCENT) == 2 and c5.enemies[1].stacks(Combatant.Status.SCENT) == 0, "a discarded Scent card marks one enemy")


func _enemy_list(count: int) -> Array[EnemyData]:
	var list: Array[EnemyData] = []
	for i in count:
		list.append(EnemyData.make("E%d" % i, 100, [] as Array[CardEffect]))
	return list


func _test_text_and_keyword() -> void:
	var card := _plain([_fx(K.DAMAGE, 3)])
	card.discard_effects = [_fx(K.BLOCK, 4)]
	_check(card.keyword_lines() == PackedStringArray(["Discarded"]), "a card with discard effects shows the Discarded keyword")
	_check(card.describe() == "Deal 3. When discarded: Block 4", "text: %s" % card.describe())
	_check(not _plain().keyword_lines().has("Discarded"), "an ordinary card does not")
	var view_lines := CardView.new()
	view_lines.set_card(card)
	_check(view_lines.keyword_text().contains("DISCARDED"), "the card face shows it")
	view_lines.free()


func _test_shipped_cards() -> void:
	var expected := {
		&"iron_skin": [T.END_OF_TURN, &"deserter"], &"bulwark_vow": [T.ON_BLOCK_GAINED, &"deserter"], &"nick_and_run": [T.EACH_PLAY, &"thief"],
		&"blood_price": [T.ON_HP_LOST, &"medium"], &"pack_instinct": [T.FIRST_PLAY, &"stray"],
	}
	for id in expected:
		var card := load("res://data/cards/%s.tres" % id) as CardData
		_check(card != null and card.oath and card.is_valid_oath() and card.oath_trigger == expected[id][0] and card.character == expected[id][1], "%s is an Oath on the %s trigger" % [id, str(expected[id][0])])
		_check(StarterContent.reward_pool(expected[id][1]).has(card), "%s is in the %s pool" % [id, expected[id][1]])
	for id in [&"loose_change", &"slipped_pocket", &"spare_key"]:
		var card := load("res://data/cards/%s.tres" % id) as CardData
		_check(card != null and not card.discard_effects.is_empty() and card.character == &"thief" and not card.oath, "%s is a Thief discard card" % id)
		_check(card.keyword_lines().has("Discarded"), "%s shows the keyword" % id)
	var nick := load("res://data/cards/nick_and_run.tres") as CardData
	var plain_cards: Array[CardData] = [nick, _plain(), _plain(), _plain()]
	var combat := _fight(plain_cards, 3)
	_play(combat, nick)
	for card in combat.piles.hand.duplicate():
		if not card.oath:
			_play(combat, card)
	var hps := [combat.enemies[0].hp, combat.enemies[1].hp, combat.enemies[2].hp]
	_check(hps == [97, 97, 97], "Nick and Run: three plays deal 1 to each of three enemies (%s)" % str(hps))


func _test_bots() -> void:
	# The greedy bot throws the card with discard effects away rather than a plain card.
	var thrown := _plain([_fx(K.DAMAGE, 3)], 1)
	thrown.discard_effects = [_fx(K.BLOCK, 4)]
	var keep := _plain([_fx(K.DAMAGE, 3)], 1)
	var hand: Array[CardData] = [thrown, keep]
	var combat := _fight(hand)
	_check(SimPolicy.keep_score(combat, thrown) < SimPolicy.keep_score(combat, keep), "greedy would rather discard the card with discard effects")
	var weights := {"damage": 1.0, "block": 1.0, "forgotten": 3, "recall": 5.0}
	_check(SmartPolicy.card_score(thrown, weights) > SmartPolicy.card_score(keep, weights), "the smart deck score counts discard effects")
