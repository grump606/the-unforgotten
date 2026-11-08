extends "res://tests/combat_test_support.gd"
## Expose and the other statuses in combat: multiplier and rounding, durations, blocked hits, enemy intents,
## and that no status leaks between fights. Discovered by run_tests.gd.


func run() -> int:
	_failures = 0
	_test_expose_multiplier_and_rounding()
	_test_expose_duration_enemy()
	_test_expose_duration_player()
	_test_enemy_intent_expose()
	_test_expose_on_blocked_hit()
	_test_no_status_leak_between_fights()
	_test_damage_after_status()
	_test_statuses_cleared_when_fight_ends()
	return _failures


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


func _test_damage_after_status() -> void:
	var c := Combatant.new("c", 50)
	_check(c.damage_after_status(7) == 7 and c.damage_after_status(-4) == 0, "no status: damage unchanged, negatives floor at 0")
	c.apply_status(Combatant.Status.EXPOSED, 1)
	_check(c.damage_after_status(7) == 10 and c.damage_after_status(1) == 1 and c.damage_after_status(0) == 0, "exposed: x1.5 rounded down, a real hit stays at least 1")
	_check(c.take_damage(7) == 10, "take_damage uses the same scaling")


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
