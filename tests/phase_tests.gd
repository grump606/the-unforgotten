extends "res://tests/test_base.gd"
## Boss phases: the switch to an enemy's second intent cycle. Discovered by run_tests.gd.
## Run on hand-made enemies (100 HP, switch at 50%), so the numbers are the rules, not the tuning.


func run() -> int:
	_failures = 0
	_test_switch_by_card()
	_test_switch_exactly_once()
	_test_threshold_is_inclusive()
	_test_no_phase_two_no_switch()
	_test_switch_by_haunt()
	_test_switch_by_thorns()
	_test_bosses_define_phase_two()
	_test_phase_three()
	return _failures


func _fx(kind: CardEffect.Kind, amount: int) -> CardEffect:
	return CardEffect.make(kind, amount)


func _fxs(list: Array) -> Array[CardEffect]:
	var out: Array[CardEffect] = []
	for item in list:
		out.append(item)
	return out


## One 100 HP enemy; phase one deals 1 and 2, phase two deals 7 then blocks 3.
func _boss(with_phase_two: bool = true) -> EnemyData:
	var data := EnemyData.make("Boss", 100, _fxs([_fx(CardEffect.Kind.DAMAGE, 1), _fx(CardEffect.Kind.DAMAGE, 2)]))
	if with_phase_two:
		data.phase_two_intents = _fxs([_fx(CardEffect.Kind.DAMAGE, 7), _fx(CardEffect.Kind.BLOCK, 3)])
		data.phase_two_hp_percent = 50
		data.phase_two_title = "Louder"
	return data


func _card(effects: Array) -> CardData:
	return CardData.make(&"t", "T", 0, _fxs(effects))


func _fight(data: EnemyData, hand: Array[CardData]) -> Combat:
	var combat := Combat.new(Combatant.new("p", 40), hand, [data] as Array[EnemyData])
	combat.start()
	return combat


func _counter(combat: Combat) -> Array:
	var seen := []
	combat.enemy_phase_changed.connect(func(enemy: EnemyUnit, phase: int) -> void: seen.append([enemy, phase]))
	return seen


func _test_switch_by_card() -> void:
	var small := _card([_fx(CardEffect.Kind.DAMAGE, 20)])
	var big := _card([_fx(CardEffect.Kind.DAMAGE, 30)])
	var combat := _fight(_boss(), [small, big])
	var seen := _counter(combat)
	var boss := combat.enemies[0]
	combat.end_player_turn() # phase one intent 0 acts, index now 1
	combat.play_card(combat.piles.hand.find(small), 0)
	_check(boss.phase == 1 and seen.is_empty(), "80 HP of 100 stays in phase one")
	_check(boss.current_intent().amount == 2, "phase one cycle continues before the threshold")
	combat.play_card(combat.piles.hand.find(big), 0)
	_check(boss.hp == 50 and boss.phase == 2, "a card taking the boss to exactly 50% starts phase two")
	_check(seen.size() == 1 and seen[0][0] == boss and seen[0][1] == 2, "the card-triggered switch emits enemy_phase_changed once, with phase 2")
	_check(boss.current_intent().kind == CardEffect.Kind.DAMAGE and boss.current_intent().amount == 7, "the intent index resets to the first phase two intent")
	_check(boss.active_intents() == boss.data.phase_two_intents, "active_intents is the phase two cycle")


func _test_switch_exactly_once() -> void:
	var hit := _card([_fx(CardEffect.Kind.DAMAGE, 60)])
	var more := _card([_fx(CardEffect.Kind.DAMAGE, 5)])
	var combat := _fight(_boss(), [hit, more])
	var seen := _counter(combat)
	var boss := combat.enemies[0]
	combat.play_card(combat.piles.hand.find(hit), 0)
	combat.play_card(combat.piles.hand.find(more), 0)
	combat.end_player_turn() # phase two intent 0 (damage 7), then index 1
	_check(boss.phase == 2 and seen.size() == 1, "further damage and a turn do not switch phases again")
	_check(boss.current_intent().kind == CardEffect.Kind.BLOCK, "the phase two cycle advances normally after the switch")
	combat.end_player_turn()
	combat.end_player_turn()
	_check(seen.size() == 1, "still one phase change after several turns")


func _test_threshold_is_inclusive() -> void:
	var just_above := _card([_fx(CardEffect.Kind.DAMAGE, 49)])
	var one_more := _card([_fx(CardEffect.Kind.DAMAGE, 1)])
	var combat := _fight(_boss(), [just_above, one_more])
	combat.play_card(combat.piles.hand.find(just_above), 0)
	_check(combat.enemies[0].phase == 1, "51 of 100 HP is above the threshold")
	combat.play_card(combat.piles.hand.find(one_more), 0)
	_check(combat.enemies[0].phase == 2, "50 of 100 HP is at the threshold")


func _test_no_phase_two_no_switch() -> void:
	var hit := _card([_fx(CardEffect.Kind.DAMAGE, 90)])
	var combat := _fight(_boss(false), [hit])
	var seen := _counter(combat)
	combat.play_card(combat.piles.hand.find(hit), 0)
	combat.end_player_turn()
	_check(combat.enemies[0].phase == 1 and seen.is_empty(), "an enemy without phase_two_intents never changes phase")
	_check(combat.enemies[0].active_intents() == combat.enemies[0].data.intents, "it keeps its one cycle")


func _test_switch_by_haunt() -> void:
	var haunt := _card([_fx(CardEffect.Kind.HAUNT, 3)])
	var data := _boss()
	var setup := _card([_fx(CardEffect.Kind.DAMAGE, 48)])
	var combat := _fight(data, [setup, haunt])
	var seen := _counter(combat)
	var boss := combat.enemies[0]
	combat.play_card(combat.piles.hand.find(setup), 0)
	combat.play_card(combat.piles.hand.find(haunt), 0)
	_check(boss.phase == 1 and boss.hp == 52, "setup: 52 HP, Haunted, still phase one")
	combat.end_player_turn() # Haunt takes 3 first (49 HP): phase two before the boss acts
	_check(boss.phase == 2 and seen.size() == 1, "Haunt at enemy turn start crosses the threshold, once")
	_check(combat.player.hp == 40 - 7, "the boss acts straight away with its first phase two intent")
	_check(boss.current_intent().kind == CardEffect.Kind.BLOCK, "and the cycle then moves on to the second phase two intent")


func _test_switch_by_thorns() -> void:
	var stance := _card([_fx(CardEffect.Kind.BLOCK, 20), _fx(CardEffect.Kind.THORNS, 4)])
	var setup := _card([_fx(CardEffect.Kind.DAMAGE, 47)])
	var combat := _fight(_boss(), [setup, stance])
	var seen := _counter(combat)
	var boss := combat.enemies[0]
	combat.play_card(combat.piles.hand.find(setup), 0)
	combat.play_card(combat.piles.hand.find(stance), 0)
	_check(boss.phase == 1 and boss.hp == 53, "setup: 53 HP and thorns up")
	combat.end_player_turn() # phase one intent 0 hits; thorns take it to 49 during its own action
	_check(boss.hp == 49 and boss.phase == 2 and seen.size() == 1, "thorns during the enemy's action trigger phase two once")
	_check(boss.current_intent().amount == 7, "the first phase two intent is next: none was skipped")
	combat.end_player_turn()
	_check(combat.player.hp < 40 and boss.current_intent().kind == CardEffect.Kind.BLOCK, "that first phase two intent then actually plays")
	_check(seen.size() == 1, "no second phase change")


func _test_bosses_define_phase_two() -> void:
	for data in [StarterContent.mid_boss_encounter()[0], StarterContent.boss_encounter()[0]]:
		_check(not data.phase_two_intents.is_empty(), "%s has a phase two" % data.display_name)
		_check(data.phase_two_title.strip_edges() != "", "%s has a phase two title" % data.display_name)
		_check(data.phase_two_hp_percent >= 1 and data.phase_two_hp_percent <= 99, "%s has a sane phase two threshold" % data.display_name)
		for intent in data.phase_two_intents:
			_check(intent.kind in [CardEffect.Kind.DAMAGE, CardEffect.Kind.BLOCK, CardEffect.Kind.EXPOSE, CardEffect.Kind.MALICE, CardEffect.Kind.ADD_CARD], "%s phase two intents use enemy intent kinds" % data.display_name)


## Three phases (the finale boss): 66% and 33%, one switch per threshold, a single hit crossing both announces both.
func _three_phase_boss() -> EnemyData:
	var data := _boss()
	data.phase_two_hp_percent = 66
	data.phase_two_title = "Second"
	data.phase_three_intents = _fxs([_fx(CardEffect.Kind.DAMAGE, 11)])
	data.phase_three_hp_percent = 33
	data.phase_three_title = "Third"
	return data


## Plays the card in hand whose first effect deals `amount` (the hand is shuffled, so a test cannot count on an index).
func _play_damage(combat: Combat, amount: int) -> void:
	for i in combat.piles.hand.size():
		if combat.piles.hand[i].effects[0].amount == amount:
			combat.play_card(i, 0)
			return


func _test_phase_three() -> void:
	var data := _three_phase_boss()
	_check(data.title_for_phase(2) == "Second" and data.title_for_phase(3) == "Third" and data.title_for_phase(1) == "" and data.title_for_phase(4) == "", "each phase has its banner text")
	var combat := _fight(data, [_card([_fx(CardEffect.Kind.DAMAGE, 30)]), _card([_fx(CardEffect.Kind.DAMAGE, 50)]), _card([_fx(CardEffect.Kind.DAMAGE, 40)])] as Array[CardData])
	var phases: Array[int] = []
	combat.enemy_phase_changed.connect(func(_enemy: EnemyUnit, phase: int) -> void: phases.append(phase))
	var boss := combat.enemies[0]
	_play_damage(combat, 30)
	_check(boss.hp == 70 and boss.phase == 1 and phases.is_empty(), "above 66% it is still in phase one")
	_play_damage(combat, 50)
	_check(boss.hp == 20 and boss.phase == 3, "one hit that crosses 66% and 33% takes it to phase three")
	_check(phases.size() == 2 and phases[0] == 2 and phases[1] == 3, "and announces phase two, then phase three")
	_check(boss.current_intent().amount == 11 and boss.active_intents() == data.phase_three_intents, "phase three runs its own cycle from the start")
	# One step at a time.
	var steady := _fight(_three_phase_boss(), [_card([_fx(CardEffect.Kind.DAMAGE, 35)]), _card([_fx(CardEffect.Kind.DAMAGE, 36)])] as Array[CardData])
	var seen: Array[int] = []
	steady.enemy_phase_changed.connect(func(_enemy: EnemyUnit, phase: int) -> void: seen.append(phase))
	_play_damage(steady, 35)
	_check(steady.enemies[0].phase == 2 and seen.size() == 1 and seen[0] == 2, "a hit to 65% is phase two only")
	_play_damage(steady, 36)
	_check(steady.enemies[0].phase == 3 and seen.size() == 2 and seen[1] == 3, "a hit to 30% then reaches phase three")
	# Without a phase two there is no phase three, and phase two alone behaves as before.
	var no_two := _boss(false)
	no_two.phase_three_intents = _fxs([_fx(CardEffect.Kind.DAMAGE, 9)])
	var alone := _fight(no_two, [_card([_fx(CardEffect.Kind.DAMAGE, 90)])] as Array[CardData])
	_play_damage(alone, 90)
	_check(alone.enemies[0].phase == 1, "phase three needs phase two")
	var plain := _fight(_boss(), [_card([_fx(CardEffect.Kind.DAMAGE, 90)])] as Array[CardData])
	_play_damage(plain, 90)
	_check(plain.enemies[0].phase == 2, "a two-phase enemy never reaches phase three")
	# The copies the pack builder and the elite rename make keep it.
	var scaled := Encounters.scaled(data, 1.5)
	_check(scaled.phase_three_intents.size() == 1 and scaled.phase_three_intents[0].amount == 17 and scaled.phase_three_hp_percent == 33 and scaled.phase_three_title == "Third", "a scaled copy keeps phase three, its damage scaled")
	var named := StarterContent.elite_named(data)
	_check(named.phase_three_intents.size() == 1 and named.phase_three_title == "Third", "an elite copy keeps it")
