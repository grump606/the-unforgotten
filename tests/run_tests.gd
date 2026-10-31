extends SceneTree
## Headless tests. Run: godot --headless --path . -s res://tests/run_tests.gd

var _failures := 0


func _initialize() -> void:
	_test_damage_and_block()
	_test_draw_reshuffles_discard()
	_test_play_card_costs_energy()
	_test_rejects_unaffordable_and_invalid_plays()
	_test_enemy_intents_cycle_and_block_clears()
	_test_victory()
	_test_defeat()
	_test_same_seed_same_hand()
	_test_targeting_hits_chosen_enemy()
	_test_dead_or_invalid_target_rejected()
	_test_victory_needs_all_enemies_dead()
	_test_every_living_enemy_acts()
	_test_early_encounter_sizes()
	_test_draw_on_empty_piles()
	_test_block_does_not_outlast_a_turn()
	_test_zero_cost_cards()
	_test_enemy_without_intents()
	_test_multi_effect_card()
	_test_end_turn_after_combat_ended_is_noop()
	_test_constructor_limits()
	_test_target_modes()
	_test_card_played_payload()
	_test_expose_multiplier_and_rounding()
	_test_expose_duration_enemy()
	_test_expose_duration_player()
	_test_expose_on_blocked_hit()
	_test_enemy_intent_expose()
	_test_no_status_leak_between_fights()
	_test_content_loaders_reject_bad_resources()
	_test_heal()
	_test_player_link_removed_when_fight_ends()
	_test_block_cleared_when_fight_ends()
	_test_create_rejects_bad_enemy_counts()
	_test_damage_after_status()
	_test_abandon_releases_player()
	_test_create_rejects_dead_player()
	_test_start_cannot_resurrect_a_fight()
	_test_statuses_cleared_when_fight_ends()
	_test_policy_survives_zero_cost_draw_loop()
	_test_play_cap_ends_a_self_recycling_turn()
	_test_card_costing_exactly_the_energy_is_playable()
	_test_turn_start_resets_energy_and_hand()
	_test_all_enemies_payload_skips_the_dead()
	_test_shuffle_reaches_every_position()
	_failures += load("res://tests/content_tests.gd").new().run()
	_failures += load("res://tests/run_state_tests.gd").new().run()
	_failures += load("res://tests/vendor_tests.gd").new().run()
	_failures += load("res://tests/smart_policy_tests.gd").new().run()
	_failures += load("res://tests/run_save_tests.gd").new().run()
	_failures += load("res://tests/mechanics_tests.gd").new().run()
	_failures += load("res://tests/medium_tests.gd").new().run()
	_failures += load("res://tests/relic_tests.gd").new().run()
	_failures += load("res://tests/update_check_tests.gd").new().run()
	print("FAILURES: %d" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAIL: " + label)


func _dmg(amount: int) -> Array[CardEffect]:
	return [CardEffect.make(CardEffect.Kind.DAMAGE, amount)]


func _card(cost: int, effects: Array[CardEffect]) -> CardData:
	return CardData.make(&"t", "T", cost, effects)


func _deck(count: int, card: CardData) -> Array[CardData]:
	var deck: Array[CardData] = []
	for i in count:
		deck.append(card)
	return deck


func _enemies(count: int, hp: int, intents: Array[CardEffect]) -> Array[EnemyData]:
	var list: Array[EnemyData] = []
	for i in count:
		list.append(EnemyData.make("E%d" % i, hp, intents))
	return list


func _test_damage_and_block() -> void:
	var c := Combatant.new("c", 20)
	c.gain_block(5)
	_check(c.take_damage(8) == 3, "damage returns HP lost after block")
	_check(c.hp == 17 and c.block == 0, "block absorbed then HP reduced")
	c.take_damage(100)
	_check(c.hp == 0 and c.is_dead(), "HP never goes below zero")


func _test_draw_reshuffles_discard() -> void:
	var piles := CardPiles.new(_deck(3, _card(1, _dmg(1))), RandomNumberGenerator.new())
	piles.draw(3)
	piles.discard_hand()
	_check(piles.draw(2) == 2 and piles.hand.size() == 2, "draw reshuffles discard when pile is empty")
	_check(piles.draw(10) == 1, "draw stops when no cards remain")


func _test_play_card_costs_energy() -> void:
	var combat := Combat.new(Combatant.new("p", 20), _deck(10, _card(1, _dmg(4))), _enemies(1, 30, []))
	combat.start()
	_check(combat.energy == Combat.ENERGY_PER_TURN and combat.piles.hand.size() == Combat.HAND_SIZE, "turn start: energy and hand")
	_check(combat.play_card(0), "affordable card plays")
	_check(combat.energy == 2 and combat.enemies[0].hp == 26 and combat.piles.discard_pile.size() == 1, "play spends energy, damages, discards")


func _test_rejects_unaffordable_and_invalid_plays() -> void:
	var combat := Combat.new(Combatant.new("p", 20), _deck(10, _card(4, _dmg(4))), _enemies(1, 30, []))
	combat.start()
	_check(not combat.play_card(0), "cost above energy is rejected")
	_check(not combat.play_card(99) and not combat.play_card(-1), "out-of-range hand index rejected")
	_check(combat.enemies[0].hp == 30 and combat.piles.hand.size() == Combat.HAND_SIZE, "rejected play changes nothing")


func _test_enemy_intents_cycle_and_block_clears() -> void:
	var intents: Array[CardEffect] = [CardEffect.make(CardEffect.Kind.DAMAGE, 5), CardEffect.make(CardEffect.Kind.BLOCK, 7)]
	var combat := Combat.new(Combatant.new("p", 40), _deck(10, _card(1, _dmg(1))), _enemies(1, 30, intents))
	combat.start()
	combat.end_player_turn()
	_check(combat.player.hp == 35 and combat.turn == 2, "first intent hits, next turn begins")
	combat.end_player_turn()
	_check(combat.enemies[0].block == 7, "second intent grants block")
	combat.end_player_turn()
	_check(combat.enemies[0].block == 0 and combat.player.hp == 30, "enemy block clears on its turn; intents wrap")


func _test_victory() -> void:
	var combat := Combat.new(Combatant.new("p", 20), _deck(10, _card(1, _dmg(50))), _enemies(1, 30, []))
	var result: Array = []
	combat.combat_ended.connect(result.append)
	combat.start()
	combat.play_card(0)
	_check(result == [true] and combat.phase == Combat.Phase.ENDED, "killing enemy ends combat in victory")
	_check(not combat.play_card(0), "no plays after combat ends")


func _test_defeat() -> void:
	var intents: Array[CardEffect] = [CardEffect.make(CardEffect.Kind.DAMAGE, 99)]
	var combat := Combat.new(Combatant.new("p", 20), _deck(10, _card(1, _dmg(1))), _enemies(1, 30, intents))
	var result: Array = []
	combat.combat_ended.connect(result.append)
	combat.start()
	combat.end_player_turn()
	_check(result == [false] and combat.phase == Combat.Phase.ENDED, "dying ends combat in defeat")


func _test_same_seed_same_hand() -> void:
	var deck := StarterContent.deck()
	var a := Combat.new(Combatant.new("p", 20), deck, StarterContent.early_encounter(2), 42)
	var b := Combat.new(Combatant.new("p", 20), deck, StarterContent.early_encounter(2), 42)
	a.start()
	b.start()
	var same := true
	for i in a.piles.hand.size():
		same = same and a.piles.hand[i] == b.piles.hand[i]
	_check(same, "same seed gives the same opening hand")


func _test_targeting_hits_chosen_enemy() -> void:
	var combat := Combat.new(Combatant.new("p", 20), _deck(10, _card(1, _dmg(4))), _enemies(3, 30, []))
	combat.start()
	_check(combat.play_card(0, 2), "play on third enemy")
	_check(combat.enemies[2].hp == 26 and combat.enemies[0].hp == 30 and combat.enemies[1].hp == 30, "only the chosen enemy is damaged")
	combat.play_card(0)
	_check(combat.enemies[0].hp == 26, "default target is first living enemy")


func _test_dead_or_invalid_target_rejected() -> void:
	var combat := Combat.new(Combatant.new("p", 20), _deck(10, _card(0, _dmg(50))), _enemies(2, 30, []))
	combat.start()
	combat.play_card(0, 0)
	var hand_size := combat.piles.hand.size()
	_check(not combat.play_card(0, 0), "defeated target rejected")
	_check(not combat.play_card(0, 5) and not combat.play_card(0, -2), "out-of-range target rejected")
	_check(combat.piles.hand.size() == hand_size, "rejected target leaves hand untouched")


func _test_victory_needs_all_enemies_dead() -> void:
	var combat := Combat.new(Combatant.new("p", 20), _deck(10, _card(0, _dmg(50))), _enemies(2, 30, []))
	var result: Array = []
	combat.combat_ended.connect(result.append)
	combat.start()
	combat.play_card(0, 0)
	_check(result.is_empty() and combat.phase == Combat.Phase.PLAYER_TURN, "one enemy left: fight continues")
	combat.play_card(0, 1)
	_check(result == [true], "last enemy down: victory")


func _test_every_living_enemy_acts() -> void:
	var intents: Array[CardEffect] = [CardEffect.make(CardEffect.Kind.DAMAGE, 5)]
	var combat := Combat.new(Combatant.new("p", 40), _deck(10, _card(0, _dmg(50))), _enemies(3, 30, intents))
	combat.start()
	combat.play_card(0, 1)
	combat.end_player_turn()
	_check(combat.player.hp == 30, "two living enemies hit; the defeated one does not")


func _test_early_encounter_sizes() -> void:
	_check(StarterContent.early_encounter(0).size() == 1, "encounter size clamps up to 1")
	_check(StarterContent.early_encounter(2).size() == 2, "encounter of 2")
	_check(StarterContent.early_encounter(9).size() == Combat.MAX_ENEMIES, "encounter size clamps down to max")


func _test_draw_on_empty_piles() -> void:
	var draw_card := _card(0, [CardEffect.make(CardEffect.Kind.DRAW, 3)])
	var empty := CardPiles.new(_deck(0, draw_card), RandomNumberGenerator.new())
	_check(empty.draw(5) == 0 and empty.hand.is_empty(), "drawing from a fully empty deck draws nothing")
	var combat := Combat.new(Combatant.new("p", 20), _deck(1, draw_card), _enemies(1, 30, []))
	combat.start()
	_check(combat.piles.hand.size() == 1 and combat.piles.draw_pile.is_empty(), "short deck: hand holds the whole deck")
	_check(combat.play_card(0), "DRAW card plays with empty piles")
	_check(combat.piles.hand.size() + combat.piles.draw_pile.size() + combat.piles.discard_pile.size() == 1, "no cards created or lost by DRAW on thin piles")


func _test_block_does_not_outlast_a_turn() -> void:
	var block_card := _card(1, [CardEffect.make(CardEffect.Kind.BLOCK, 5)])
	var intents: Array[CardEffect] = [CardEffect.make(CardEffect.Kind.DAMAGE, 8)]
	var combat := Combat.new(Combatant.new("p", 40), _deck(10, block_card), _enemies(1, 30, intents))
	combat.start()
	combat.play_card(0)
	_check(combat.player.block == 5, "block gained on the player's turn")
	combat.end_player_turn()
	_check(combat.player.hp == 37 and combat.player.block == 0, "block absorbs the enemy hit, then clears at the next turn start")
	combat.end_player_turn()
	_check(combat.player.hp == 29, "no block carried into the following enemy turn")


func _test_zero_cost_cards() -> void:
	var combat := Combat.new(Combatant.new("p", 20), _deck(10, _card(0, _dmg(1))), _enemies(1, 30, []))
	combat.start()
	for i in Combat.HAND_SIZE:
		_check(combat.play_card(0), "free card %d plays" % i)
	_check(combat.energy == Combat.ENERGY_PER_TURN and combat.enemies[0].hp == 25, "0-cost cards spend no energy")
	_check(combat.piles.hand.is_empty() and not combat.play_card(0), "empty hand rejects plays")


func _test_enemy_without_intents() -> void:
	var combat := Combat.new(Combatant.new("p", 20), _deck(10, _card(1, _dmg(1))), _enemies(1, 30, []))
	var acted: Array = []
	combat.enemy_acted.connect(func(_e, _i): acted.append(true))
	combat.start()
	combat.end_player_turn()
	combat.end_player_turn()
	_check(acted.is_empty() and combat.player.hp == 20, "enemy with no intents never acts")
	_check(combat.turn == 3 and combat.phase == Combat.Phase.PLAYER_TURN, "turns still advance")
	_check(combat.enemies[0].current_intent() == null, "current_intent is null without intents")


func _test_multi_effect_card() -> void:
	var effects: Array[CardEffect] = [
		CardEffect.make(CardEffect.Kind.DAMAGE, 3),
		CardEffect.make(CardEffect.Kind.BLOCK, 2),
		CardEffect.make(CardEffect.Kind.DRAW, 1),
	]
	var combat := Combat.new(Combatant.new("p", 20), _deck(10, _card(2, effects)), _enemies(1, 30, []))
	combat.start()
	combat.play_card(0)
	_check(combat.enemies[0].hp == 27 and combat.player.block == 2, "damage and block both applied")
	_check(combat.piles.hand.size() == Combat.HAND_SIZE and combat.energy == 1, "draw applied after playing: hand back to full, cost paid once")


func _test_end_turn_after_combat_ended_is_noop() -> void:
	var intents: Array[CardEffect] = [CardEffect.make(CardEffect.Kind.DAMAGE, 5)]
	var combat := Combat.new(Combatant.new("p", 20), _deck(10, _card(1, _dmg(50))), _enemies(1, 30, intents))
	var result: Array = []
	combat.combat_ended.connect(result.append)
	combat.start()
	combat.play_card(0)
	var turn := combat.turn
	var hp := combat.player.hp
	combat.end_player_turn()
	_check(result == [true] and combat.turn == turn and combat.player.hp == hp and combat.phase == Combat.Phase.ENDED, "end_player_turn after the end changes nothing and does not re-emit")
	var fresh := Combat.new(Combatant.new("p", 20), _deck(10, _card(1, _dmg(1))), _enemies(1, 30, []))
	fresh.end_player_turn()
	_check(fresh.phase == Combat.Phase.NOT_STARTED and fresh.turn == 0, "end_player_turn before start is a no-op")


func _test_constructor_limits() -> void:
	var full := Combat.new(Combatant.new("p", 20), _deck(5, _card(1, _dmg(1))), _enemies(Combat.MAX_ENEMIES, 10, []))
	_check(full.enemies.size() == Combat.MAX_ENEMIES, "MAX_ENEMIES enemies accepted")
	var clamped := Combatant.new("p", 20, 50)
	_check(clamped.hp == 20, "starting HP above max is clamped")
	var half := Combatant.new("p", 20, 7)
	_check(half.hp == 7 and half.max_hp == 20, "explicit starting HP honoured")
	half.gain_block(-4)
	_check(half.block == 0, "negative block ignored")
	_check(half.take_damage(-5) == 0 and half.hp == 7, "negative damage ignored")


func _mode_card(mode: CardData.TargetMode, effects: Array[CardEffect], cost: int = 0) -> CardData:
	return CardData.make(&"m", "M", cost, effects, mode)


func _expose(turns: int) -> CardEffect:
	return CardEffect.make(CardEffect.Kind.EXPOSE, turns)


func _test_target_modes() -> void:
	var all_card := _mode_card(CardData.TargetMode.ALL_ENEMIES, [CardEffect.make(CardEffect.Kind.DAMAGE, 4), CardEffect.make(CardEffect.Kind.BLOCK, 2)])
	var combat := Combat.new(Combatant.new("p", 20), _deck(10, all_card), _enemies(3, 30, []))
	combat.start()
	_check(combat.play_card(0, 99), "ALL_ENEMIES ignores an invalid target index")
	_check(combat.enemies[0].hp == 26 and combat.enemies[1].hp == 26 and combat.enemies[2].hp == 26, "ALL_ENEMIES hits every enemy")
	_check(combat.player.block == 2, "BLOCK stays on the player for ALL_ENEMIES")
	combat.enemies[1].take_damage(100)
	_check(combat.play_card(0, 1), "ALL_ENEMIES ignores a defeated target index")
	_check(combat.enemies[0].hp == 22 and combat.enemies[2].hp == 22, "ALL_ENEMIES skips defeated enemies")

	var self_card := _mode_card(CardData.TargetMode.SELF, [CardEffect.make(CardEffect.Kind.BLOCK, 6), CardEffect.make(CardEffect.Kind.DAMAGE, 9)])
	var c2 := Combat.new(Combatant.new("p", 20), _deck(10, self_card), _enemies(2, 30, []))
	c2.start()
	_check(c2.play_card(0, 77) and c2.play_card(0, -2), "SELF ignores the target index")
	_check(c2.player.block == 12 and c2.enemies[0].hp == 30 and c2.enemies[1].hp == 30, "SELF blocks the player and hits no enemy")

	var single := _mode_card(CardData.TargetMode.SINGLE_ENEMY, _dmg(4))
	var c3 := Combat.new(Combatant.new("p", 20), _deck(10, single), _enemies(2, 30, []))
	c3.start()
	_check(not c3.play_card(0, 9) and c3.piles.hand.size() == Combat.HAND_SIZE, "SINGLE_ENEMY still rejects an invalid target")
	_check(_card(1, _dmg(1)).target_mode == CardData.TargetMode.SINGLE_ENEMY, "target mode defaults to SINGLE_ENEMY")


func _test_card_played_payload() -> void:
	var all_card := _mode_card(CardData.TargetMode.ALL_ENEMIES, _dmg(1))
	var self_card := _mode_card(CardData.TargetMode.SELF, [CardEffect.make(CardEffect.Kind.BLOCK, 1)])
	var one_card := _mode_card(CardData.TargetMode.SINGLE_ENEMY, _dmg(1))
	var deck: Array[CardData] = [all_card, self_card, one_card]
	var combat := Combat.new(Combatant.new("p", 20), deck, _enemies(3, 30, []))
	var seen: Array = []
	combat.card_played.connect(func(card: CardData, targets: Array[EnemyUnit]): seen.append([card, targets.duplicate()]))
	combat.start()
	# Hand order is shuffled; find each card by identity.
	for wanted in [all_card, self_card, one_card]:
		combat.play_card(combat.piles.hand.find(wanted), 1)
	_check(seen.size() == 3, "card_played emitted once per play")
	for entry in seen:
		var targets: Array = entry[1]
		if entry[0] == all_card:
			_check(targets == combat.enemies, "ALL_ENEMIES payload lists every living enemy")
		elif entry[0] == self_card:
			_check(targets.is_empty(), "SELF payload is empty")
		else:
			_check(targets == [combat.enemies[1]], "SINGLE_ENEMY payload is the chosen enemy")


func _test_expose_multiplier_and_rounding() -> void:
	var c := Combatant.new("c", 100)
	c.apply_status(Combatant.Status.EXPOSED, 2)
	_check(c.take_damage(10) == 15, "exposed: 10 becomes 15")
	_check(c.take_damage(5) == 7, "exposed: 7.5 rounds down to 7")
	_check(c.take_damage(1) == 1, "exposed: 1 stays at least 1")
	_check(c.take_damage(0) == 0, "exposed: zero damage stays zero")
	_check(c.status_turns(Combatant.Status.EXPOSED) == 2, "damage does not tick the status")
	c.apply_status(Combatant.Status.EXPOSED, 0)
	c.apply_status(Combatant.Status.EXPOSED, -3)
	_check(c.status_turns(Combatant.Status.EXPOSED) == 2, "non-positive durations ignored")
	var fired := [0]
	c.changed.connect(func(): fired[0] += 1)
	c.apply_status(Combatant.Status.EXPOSED, 1)
	_check(fired[0] == 1 and c.status_turns(Combatant.Status.EXPOSED) == 3, "applying a status fires changed and stacks duration")


func _test_expose_duration_enemy() -> void:
	var intents: Array[CardEffect] = [CardEffect.make(CardEffect.Kind.DAMAGE, 1)]
	var card := _mode_card(CardData.TargetMode.SINGLE_ENEMY, [_expose(2)])
	var strike := _card(0, _dmg(10))
	var deck: Array[CardData] = [card, strike, strike, strike, strike, strike]
	var combat := Combat.new(Combatant.new("p", 99), deck, _enemies(2, 100, intents))
	combat.start()
	combat.play_card(combat.piles.hand.find(card), 1)
	_check(combat.enemies[1].status_turns(Combatant.Status.EXPOSED) == 2 and combat.enemies[0].status_turns(Combatant.Status.EXPOSED) == 0, "EXPOSE applies to the chosen enemy only")
	combat.play_card(combat.piles.hand.find(strike), 1)
	_check(combat.enemies[1].hp == 85, "exposed enemy takes 15 from a 10 hit")
	combat.end_player_turn()
	_check(combat.enemies[1].status_turns(Combatant.Status.EXPOSED) == 1, "enemy status ticks after it acts")
	combat.end_player_turn()
	_check(combat.enemies[1].status_turns(Combatant.Status.EXPOSED) == 0, "enemy status expires after its duration")
	var before := combat.enemies[1].hp
	combat.play_card(combat.piles.hand.find(strike), 1)
	_check(before - combat.enemies[1].hp == 10, "damage is normal after expiry")

	var all_expose := _mode_card(CardData.TargetMode.ALL_ENEMIES, [_expose(1)])
	var c2 := Combat.new(Combatant.new("p", 99), _deck(10, all_expose), _enemies(2, 100, []))
	c2.start()
	c2.play_card(0)
	_check(c2.enemies[0].status_turns(Combatant.Status.EXPOSED) == 1 and c2.enemies[1].status_turns(Combatant.Status.EXPOSED) == 1, "EXPOSE hits all enemies with ALL_ENEMIES")
	c2.end_player_turn()
	_check(c2.enemies[0].status_turns(Combatant.Status.EXPOSED) == 0, "1-turn expose expires on the enemy's own turn")

	var self_expose := _mode_card(CardData.TargetMode.SELF, [_expose(1)])
	var c3 := Combat.new(Combatant.new("p", 99), _deck(10, self_expose), _enemies(1, 100, []))
	c3.start()
	c3.play_card(0)
	_check(c3.player.status_turns(Combatant.Status.EXPOSED) == 1 and c3.enemies[0].status_turns(Combatant.Status.EXPOSED) == 0, "SELF EXPOSE exposes the player")


func _test_expose_duration_player() -> void:
	var intents: Array[CardEffect] = [CardEffect.make(CardEffect.Kind.DAMAGE, 10), _expose(5)]
	var player := Combatant.new("p", 100)
	var combat := Combat.new(player, _deck(10, _card(1, _dmg(1))), _enemies(1, 100, intents))
	combat.start()
	player.apply_status(Combatant.Status.EXPOSED, 2)
	combat.end_player_turn()
	_check(player.hp == 85, "exposed player takes 15 from a 10 hit")
	_check(player.status_turns(Combatant.Status.EXPOSED) == 1, "player status ticks at end of its turn cycle")
	combat.end_player_turn()
	_check(player.hp == 85, "second intent (an EXPOSE) does no damage")
	_check(player.status_turns(Combatant.Status.EXPOSED) == 5, "the old status expired; enemy EXPOSE 5 is not ticked in the phase that applied it")


func _test_enemy_intent_expose() -> void:
	# Two enemies each expose for 2: stacks on the player only.
	var intents: Array[CardEffect] = [_expose(2), CardEffect.make(CardEffect.Kind.DAMAGE, 10)]
	var player := Combatant.new("p", 100)
	var combat := Combat.new(player, _deck(10, _card(1, _dmg(1))), _enemies(2, 100, intents))
	combat.start()
	combat.end_player_turn()
	_check(player.status_turns(Combatant.Status.EXPOSED) == 4, "two enemies stack 2+2 turns on the player")
	_check(combat.enemies[0].status_turns(Combatant.Status.EXPOSED) == 0 and combat.enemies[1].status_turns(Combatant.Status.EXPOSED) == 0, "enemy EXPOSE intent never exposes enemies")
	_check(player.hp == 100, "no damage in the applying phase")

	# amount 2: exposed for exactly the next 2 enemy phases.
	var one: Array[CardEffect] = [_expose(2), CardEffect.make(CardEffect.Kind.DAMAGE, 10), CardEffect.make(CardEffect.Kind.DAMAGE, 10), CardEffect.make(CardEffect.Kind.DAMAGE, 10)]
	var p2 := Combatant.new("p", 100)
	var c2 := Combat.new(p2, _deck(10, _card(1, _dmg(1))), _enemies(1, 100, one))
	c2.start()
	c2.end_player_turn()
	_check(p2.status_turns(Combatant.Status.EXPOSED) == 2 and p2.hp == 100, "intent EXPOSE 2 leaves 2 turns for the next phases")
	c2.end_player_turn()
	_check(p2.hp == 85 and p2.status_turns(Combatant.Status.EXPOSED) == 1, "first exposed enemy phase: 10 becomes 15")
	c2.end_player_turn()
	_check(p2.hp == 70 and p2.status_turns(Combatant.Status.EXPOSED) == 0, "second exposed enemy phase: 10 becomes 15")
	c2.end_player_turn()
	_check(p2.hp == 60, "third phase is back to normal damage")

	# A pre-existing status still ticks; the new turns are added on top.
	var p3 := Combatant.new("p", 100)
	var expose3: Array[CardEffect] = [_expose(3)]
	var c3 := Combat.new(p3, _deck(10, _card(1, _dmg(1))), _enemies(1, 100, expose3))
	c3.start()
	p3.apply_status(Combatant.Status.EXPOSED, 2)
	c3.end_player_turn()
	_check(p3.status_turns(Combatant.Status.EXPOSED) == 4, "existing 2 ticks to 1, then intent adds 3")

	# Card-played SELF expose is unchanged: 1 turn covers the same turn's enemy phase.
	var self_expose := _mode_card(CardData.TargetMode.SELF, [_expose(1)])
	var hit: Array[CardEffect] = [CardEffect.make(CardEffect.Kind.DAMAGE, 10)]
	var p4 := Combatant.new("p", 100)
	var c4 := Combat.new(p4, _deck(10, self_expose), _enemies(1, 100, hit))
	c4.start()
	c4.play_card(0)
	c4.end_player_turn()
	_check(p4.hp == 85 and p4.status_turns(Combatant.Status.EXPOSED) == 0, "SELF EXPOSE 1 covers exactly this turn's enemy phase")

	# Intent-applied turns do not leak into the next fight.
	var p5 := Combatant.new("p", 100)
	var c5 := Combat.new(p5, _deck(10, _card(1, _dmg(1))), _enemies(1, 100, expose3))
	c5.start()
	c5.end_player_turn()
	var next := Combat.new(p5, _deck(10, _card(1, _dmg(1))), _enemies(1, 100, hit))
	_check(p5.status_turns(Combatant.Status.EXPOSED) == 0, "intent-applied EXPOSE is cleared by the next fight")
	next.start()
	next.end_player_turn()
	_check(p5.hp == 90, "next fight deals normal damage")


func _test_expose_on_blocked_hit() -> void:
	var c := Combatant.new("c", 50)
	c.apply_status(Combatant.Status.EXPOSED, 1)
	c.gain_block(10)
	_check(c.take_damage(10) == 5 and c.block == 0, "10 exposed to 15; block 10 absorbs, 5 gets through")
	var d := Combatant.new("d", 50)
	d.apply_status(Combatant.Status.EXPOSED, 1)
	d.gain_block(15)
	_check(d.take_damage(10) == 0 and d.block == 0, "multiplier applies before block: 15 fully absorbed by 15 block")


func _test_no_status_leak_between_fights() -> void:
	var player := Combatant.new("p", 50)
	player.apply_status(Combatant.Status.EXPOSED, 3)
	var intents: Array[CardEffect] = [CardEffect.make(CardEffect.Kind.DAMAGE, 10)]
	var next := Combat.new(player, _deck(5, _card(1, _dmg(1))), _enemies(1, 10, intents))
	_check(player.status_turns(Combatant.Status.EXPOSED) == 0, "a new fight clears the player's statuses")
	next.start()
	next.end_player_turn()
	_check(player.hp == 40, "no exposed damage in the new fight")
	var a := EnemyUnit.new(EnemyData.make("a", 10, intents))
	var b := EnemyUnit.new(EnemyData.make("a", 10, intents))
	a.apply_status(Combatant.Status.EXPOSED, 2)
	_check(b.status_turns(Combatant.Status.EXPOSED) == 0, "statuses are per combatant")


# The loaders log an error for each bad path; that output is expected here.
func _test_content_loaders_reject_bad_resources() -> void:
	_check(StarterContent._load_card("res://data/cards/nope.tres") == null, "missing card resource returns null")
	_check(StarterContent._load_enemy("res://data/enemies/nope.tres") == null, "missing enemy resource returns null")
	_check(StarterContent._load_card(StarterContent.WARDEN_PATH) == null, "enemy resource is not accepted as a card")
	_check(StarterContent._load_enemy(StarterContent.SHOVE_PATH) == null, "card resource is not accepted as an enemy")
	_check(StarterContent._load_card(StarterContent.SHOVE_PATH) != null, "valid card resource loads")


func _test_heal() -> void:
	var c := Combatant.new("c", 20, 10)
	_check(c.heal(5) == 5 and c.hp == 15, "heal restores HP")
	_check(c.heal(100) == 5 and c.hp == 20, "heal never exceeds max HP")
	_check(c.heal(-3) == 0 and c.hp == 20, "negative heal is ignored")


# A persistent player must not keep a finished fight alive through signal links.
func _test_player_link_removed_when_fight_ends() -> void:
	var player := Combatant.new("p", 20)
	var combat := Combat.new(player, _deck(10, _card(1, _dmg(50))), _enemies(1, 30, []))
	_check(player.changed.get_connections().size() == 0, "an unstarted fight holds no link to the player")
	combat.start()
	_check(player.changed.get_connections().size() == 1, "player linked to the fight while it runs")
	combat.play_card(0)
	_check(player.changed.get_connections().size() == 0, "player link removed when the fight ends")


func _test_block_cleared_when_fight_ends() -> void:
	var player := Combatant.new("p", 20)
	var combat := Combat.new(player, _deck(10, _card(1, _dmg(50))), _enemies(1, 30, []))
	combat.start()
	player.gain_block(7)
	combat.play_card(0)
	_check(combat.phase == Combat.Phase.ENDED and player.block == 0, "block cleared when the fight ends")


# create() logs an error for each bad count; that output is expected here.
func _test_create_rejects_bad_enemy_counts() -> void:
	var player := Combatant.new("p", 20)
	var deck := _deck(10, _card(1, _dmg(1)))
	_check(Combat.create(player, deck, _enemies(0, 10, [])) == null, "create rejects zero enemies")
	_check(Combat.create(player, deck, _enemies(Combat.MAX_ENEMIES + 1, 10, [])) == null, "create rejects too many enemies")
	_check(Combat.create(player, deck, _enemies(Combat.MAX_ENEMIES, 10, [])) != null, "create accepts the maximum")


func _test_damage_after_status() -> void:
	var c := Combatant.new("c", 50)
	_check(c.damage_after_status(7) == 7 and c.damage_after_status(-4) == 0, "no status: damage unchanged, negatives floor at 0")
	c.apply_status(Combatant.Status.EXPOSED, 1)
	_check(c.damage_after_status(7) == 10 and c.damage_after_status(1) == 1 and c.damage_after_status(0) == 0, "exposed: x1.5 rounded down, a real hit stays at least 1")
	_check(c.take_damage(7) == 10, "take_damage uses the same scaling")


func _test_abandon_releases_player() -> void:
	var player := Combatant.new("p", 20)
	var combat := Combat.new(player, _deck(10, _card(1, _dmg(1))), _enemies(1, 30, []))
	var ended: Array = []
	combat.combat_ended.connect(ended.append)
	combat.start()
	player.gain_block(4)
	combat.abandon()
	_check(player.changed.get_connections().size() == 0, "abandon removes the player link")
	_check(combat.phase == Combat.Phase.ENDED and player.block == 0 and ended.is_empty(), "abandon ends the fight quietly and clears block")
	combat.abandon()
	_check(not combat.play_card(0) and player.changed.get_connections().size() == 0, "abandon twice is safe; no plays after")


# create() logs an error for a dead player; that output is expected here.
func _test_create_rejects_dead_player() -> void:
	var dead := Combatant.new("d", 10, 0)
	_check(Combat.create(dead, _deck(10, _card(1, _dmg(1))), _enemies(1, 10, [])) == null, "create rejects a dead player")


# start() on an ended fight logs an error; that output is expected here.
func _test_start_cannot_resurrect_a_fight() -> void:
	var combat := Combat.new(Combatant.new("p", 20), _deck(10, _card(1, _dmg(50))), _enemies(1, 30, []))
	combat.start()
	combat.play_card(0)
	var turn_at_end := combat.turn
	combat.start()
	_check(combat.phase == Combat.Phase.ENDED and combat.turn == turn_at_end, "start() cannot restart an ended fight")
	var twice := Combat.new(Combatant.new("p", 20), _deck(10, _card(1, _dmg(1))), _enemies(1, 30, []))
	twice.start()
	var hand := twice.piles.hand.size()
	twice.start()
	_check(twice.turn == 1 and twice.piles.hand.size() == hand, "start() twice does not begin another turn")
	var abandoned := Combat.new(Combatant.new("p", 20), _deck(10, _card(1, _dmg(1))), _enemies(1, 30, []))
	abandoned.abandon()
	abandoned.start()
	_check(abandoned.phase == Combat.Phase.ENDED, "start() cannot revive an abandoned fight")


func _test_statuses_cleared_when_fight_ends() -> void:
	var player := Combatant.new("p", 20)
	var combat := Combat.new(player, _deck(10, _card(1, _dmg(50))), _enemies(1, 30, []))
	combat.start()
	player.apply_status(Combatant.Status.EXPOSED, 3)
	combat.play_card(0)
	_check(combat.phase == Combat.Phase.ENDED and player.status_turns(Combatant.Status.EXPOSED) == 0, "player statuses are cleared when the fight ends")
	var quitter := Combatant.new("q", 20)
	var other := Combat.new(quitter, _deck(10, _card(1, _dmg(1))), _enemies(1, 30, []))
	other.start()
	quitter.apply_status(Combatant.Status.EXPOSED, 2)
	other.abandon()
	_check(quitter.status_turns(Combatant.Status.EXPOSED) == 0, "player statuses are cleared when a fight is abandoned")


# A lone zero-cost draw card recycles itself forever; the rules cap must let the policy end the turn.
func _test_policy_survives_zero_cost_draw_loop() -> void:
	var glimpse := load(StarterContent.GLIMPSE_EXIT_PATH) as CardData
	var deck: Array[CardData] = [glimpse]
	var combat := Combat.new(Combatant.new("p", 20), deck, _enemies(1, 30, []))
	combat.start()
	_check(SimPolicy.play_turn(combat), "policy handles a self-recycling zero-cost deck")
	_check(combat.turn == 2, "the capped turn still ended")


func _test_card_costing_exactly_the_energy_is_playable() -> void:
	var combat := Combat.new(Combatant.new("p", 20), _deck(10, _card(Combat.ENERGY_PER_TURN, _dmg(4))), _enemies(1, 30, []))
	combat.start()
	_check(combat.can_play(0) and combat.play_card(0), "a card costing exactly the energy can be played")
	_check(combat.energy == 0, "paying the whole energy leaves 0")
	_check(not combat.can_play(0), "nothing is playable with 0 energy left")


func _test_turn_start_resets_energy_and_hand() -> void:
	var combat := Combat.new(Combatant.new("p", 40), _deck(20, _card(1, _dmg(1))), _enemies(1, 99, []))
	combat.start()
	var first_hand: Array[CardData] = []
	first_hand.append_array(combat.piles.hand)
	combat.end_player_turn()
	_check(combat.energy == Combat.ENERGY_PER_TURN, "unspent energy does not carry into the next turn")
	_check(combat.piles.hand.size() == Combat.HAND_SIZE, "the next hand is exactly the hand size, not the old hand plus new cards")
	_check(combat.piles.discard_pile.size() == first_hand.size(), "the old hand went to the discard pile")
	combat.play_card(0)
	combat.end_player_turn()
	_check(combat.energy == Combat.ENERGY_PER_TURN, "energy is full again after spending some")


func _test_all_enemies_payload_skips_the_dead() -> void:
	var sweep := _mode_card(CardData.TargetMode.ALL_ENEMIES, _dmg(3))
	var hit := _mode_card(CardData.TargetMode.SINGLE_ENEMY, _dmg(99))
	# A two-card deck is fully dealt in the opening hand, so no card is missing by chance.
	var deck: Array[CardData] = [sweep, hit]
	var combat := Combat.new(Combatant.new("p", 40), deck, _enemies(3, 20, []))
	var payloads: Array = []
	combat.card_played.connect(func(_card: CardData, targets: Array[EnemyUnit]) -> void: payloads.append(targets.size()))
	combat.start()
	var hit_index := combat.piles.hand.find(hit)
	_check(hit_index != -1 and combat.piles.hand.has(sweep), "setup: both cards are in the opening hand")
	combat.play_card(hit_index, 0)
	var sweep_index := combat.piles.hand.find(sweep)
	combat.play_card(sweep_index)
	_check(payloads == [1, 2], "an all-enemies card reports only the living enemies it hit (got %s)" % str(payloads))
	_check(combat.enemies[0].is_dead() and combat.enemies[1].hp == 17 and combat.enemies[2].hp == 17, "the dead enemy is skipped and the living take the damage")


# Every card must be able to land in every position, or the shuffle is biased.
func _test_shuffle_reaches_every_position() -> void:
	var cards: Array[CardData] = []
	for i in 3:
		cards.append(CardData.make(StringName("s%d" % i), "S%d" % i, 1, _dmg(1)))
	var seen := {}
	for seed_value in 300:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var piles := CardPiles.new(cards, rng)
		for position in piles.draw_pile.size():
			seen["%d:%s" % [position, piles.draw_pile[position].id]] = true
	_check(seen.size() == 9, "a shuffled 3-card pile puts every card at every position (%d of 9 seen)" % seen.size())


func _test_play_cap_ends_a_self_recycling_turn() -> void:
	var glimpse := load(StarterContent.GLIMPSE_EXIT_PATH) as CardData
	var deck: Array[CardData] = [glimpse]
	var combat := Combat.new(Combatant.new("p", 20), deck, _enemies(1, 30, []))
	combat.start()
	var plays := 0
	while combat.can_play(0) and plays < Combat.MAX_PLAYS_PER_TURN * 2:
		combat.play_card(0)
		plays += 1
	_check(plays == Combat.MAX_PLAYS_PER_TURN and combat.plays_this_turn == Combat.MAX_PLAYS_PER_TURN, "a self-recycling zero-cost card stops at the per-turn play cap (%d plays)" % plays)
	_check(not combat.can_play(0) and not combat.play_card(0), "no card is playable once the cap is hit")
	combat.end_player_turn()
	_check(combat.plays_this_turn == 0 and combat.can_play(0), "the cap resets with the next turn")
	# An ordinary turn is nowhere near the cap.
	var normal := Combat.new(Combatant.new("p", 20), _deck(10, _card(1, _dmg(1))), _enemies(1, 99, []))
	normal.start()
	while normal.can_play(0):
		normal.play_card(0)
	_check(normal.plays_this_turn == Combat.ENERGY_PER_TURN, "an ordinary turn is limited by energy long before the cap")
