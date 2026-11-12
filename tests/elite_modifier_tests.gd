extends "res://tests/combat_test_support.gd"
## Elite modifiers (docs/CHAPTER2_PLAN.md): Plated, Enraged and Marked, drawn per elite node from the map seed.


func run() -> int:
	_failures = 0
	_test_draw()
	_test_enrage()
	_test_plated_and_marked()
	_test_in_a_run()
	return _failures


func _test_draw() -> void:
	var counts := [0, 0, 0]
	for seed_value in 50:
		for id in 20:
			var kind := EliteModifiers.for_node(seed_value, id)
			counts[kind] += 1
			_check(kind == EliteModifiers.for_node(seed_value, id), "the draw is repeatable")
	_check(counts[0] > 200 and counts[1] > 200 and counts[2] > 200, "each modifier turns up about a third of the time: %s" % str(counts))
	var map := RouteMap.generate(11, &"deserter")
	var elites := 0
	for id in map.node_count():
		var n := map.node(id)
		if n.type == RouteMap.NodeType.ELITE:
			elites += 1
			_check(map.elite_modifier(id) == EliteModifiers.for_node(map.seed_value, id), "an elite node has its modifier")
		else:
			_check(map.elite_modifier(id) == -1, "any other node has none")
	_check(elites > 0, "the map has elites to test with")
	_check(map.elite_modifier(-5) == -1 and map.elite_modifier(100000) == -1, "an unknown node has none")
	for kind in EliteModifiers.Kind.values():
		_check(EliteModifiers.line(kind) != "" and EliteModifiers.display_name(kind) != "", "every modifier has a name and a line")
	_check(EliteModifiers.line(-1) == "" and EliteModifiers.line(99) == "", "no line for no modifier")


func _test_enrage() -> void:
	var intents: Array[CardEffect] = [CardEffect.make(CardEffect.Kind.DAMAGE, 10), CardEffect.make(CardEffect.Kind.FRAYED, 2), CardEffect.make(CardEffect.Kind.DAMAGE, 6, 0, 0, 3)]
	var enemy := EnemyData.make("E", 40, intents, &"e")
	var pack: Array[EnemyData] = [enemy]
	EliteModifiers.enrage(pack)
	_check(enemy.phase_two_hp_percent == 50 and enemy.phase_two_title == EliteModifiers.ENRAGE_TITLE and enemy.phase_two_intents.size() == 3, "an enraged enemy gets a second phase at half HP")
	_check(enemy.phase_two_intents[0].amount == 13 and enemy.phase_two_intents[2].amount == 8 and enemy.phase_two_intents[2].hits == 3, "its attacks are 1.3x, hits kept")
	_check(enemy.phase_two_intents[1].kind == CardEffect.Kind.FRAYED and enemy.intents[0].amount == 10, "other intents stay and the first phase is untouched")
	var boss := EnemyData.make("B", 50, intents, &"b")
	var strong: Array[CardEffect] = [CardEffect.make(CardEffect.Kind.DAMAGE, 99)]
	boss.phase_two_intents = strong
	var bosses: Array[EnemyData] = [boss]
	EliteModifiers.enrage(bosses)
	_check(boss.phase_two_intents[0].amount == 99, "an enemy that already has a second phase keeps it")
	var weak := EnemyData.make("W", 10, [CardEffect.make(CardEffect.Kind.DAMAGE, 1)] as Array[CardEffect], &"w")
	var weak_pack: Array[EnemyData] = [weak]
	EliteModifiers.enrage(weak_pack)
	_check(weak.phase_two_intents[0].amount > 1, "a 1-damage attack still grows")
	# It switches phase in a fight.
	var low := EnemyData.make("L", 40, [CardEffect.make(CardEffect.Kind.DAMAGE, 10)] as Array[CardEffect], &"l")
	var low_pack: Array[EnemyData] = [low]
	EliteModifiers.enrage(low_pack)
	var combat := Combat.new(Combatant.new("p", 99), _deck(20, _card(0, _dmg(30))), low_pack)
	combat.start()
	combat.play_card(0, 0)
	_check(combat.enemies[0].phase == 2, "the enraged enemy enters its second phase at half HP")
	combat.abandon()


func _test_plated_and_marked() -> void:
	var two: Array[EnemyData] = [EnemyData.make("A", 30, [] as Array[CardEffect], &"a"), EnemyData.make("B", 30, [] as Array[CardEffect], &"b")]
	var combat := Combat.new(Combatant.new("p", 40), _deck(10, _card(1, _dmg(1))), two)
	combat.start()
	EliteModifiers.apply_to_combat(combat, EliteModifiers.Kind.PLATED, 0)
	_check(combat.enemies[0].block == 6 and combat.enemies[1].block == 6, "Plated: 6 Block in the first district")
	combat.abandon()
	var second := Combat.new(Combatant.new("p", 40), _deck(10, _card(1, _dmg(1))), [EnemyData.make("A", 30, [] as Array[CardEffect], &"a")] as Array[EnemyData])
	second.start()
	EliteModifiers.apply_to_combat(second, EliteModifiers.Kind.PLATED, 1)
	_check(second.enemies[0].block == 10, "Plated: 10 Block in the second")
	second.abandon()
	var marked := Combat.new(Combatant.new("p", 99), _deck(10, _card(0, _dmg(10))), [EnemyData.make("H", 99, [] as Array[CardEffect], &"h")] as Array[EnemyData])
	marked.start()
	EliteModifiers.apply_to_combat(marked, EliteModifiers.Kind.MARKED, 0)
	_check(marked.player.status_turns(Combatant.Status.SHAKEN) == 1, "Marked: the player starts Shaken")
	marked.play_card(0, 0)
	_check(marked.enemies[0].hp > 99 - 10, "a Shaken player deals less damage on the first turn")
	marked.end_player_turn()
	_check(marked.player.status_turns(Combatant.Status.SHAKEN) == 0, "and the mark wears off after that turn")
	marked.abandon()
	EliteModifiers.apply_to_combat(null, EliteModifiers.Kind.PLATED, 0)
	_check(true, "a null combat is ignored")


func _test_in_a_run() -> void:
	var seen := {}
	for seed_value in range(1, 60):
		var run_state := RunState.new(seed_value, &"deserter", true)
		var elite_id := -1
		for id in run_state.route.node_count():
			if run_state.route.node(id).type == RouteMap.NodeType.ELITE:
				elite_id = id
				break
		if elite_id == -1:
			continue
		var path: Array[int] = []
		var row := run_state.route.node(elite_id).row
		# Stand inside the elite's stop (the visited path is not needed to start its combat).
		run_state.restore_map(run_state.route, elite_id, path, true)
		var kind := run_state.elite_modifier()
		_check(kind == run_state.route.elite_modifier(elite_id), "the run reads the node's modifier")
		var combat := run_state.start_combat()
		if combat == null:
			continue
		seen[kind] = true
		match kind:
			EliteModifiers.Kind.PLATED:
				_check(combat.enemies[0].block == EliteModifiers.PLATED_BLOCK[row / RouteMap.ACT_ROWS], "a Plated elite fight starts with Block")
			EliteModifiers.Kind.ENRAGED:
				_check(not combat.enemies[0].data.phase_two_intents.is_empty(), "an Enraged elite fight has second phases")
			EliteModifiers.Kind.MARKED:
				_check(combat.player.status_turns(Combatant.Status.SHAKEN) == 1, "a Marked elite fight starts Shaken")
		_check(Chapters.chapter(1).enemy_paths.size() > 0, "content loaded")
		combat.abandon()
	_check(seen.size() == 3, "all three modifiers were met in runs: %s" % str(seen.keys()))
	var plain_fight := RunState.new(5, &"deserter", true)
	_check(plain_fight.elite_modifier() == -1, "no elite, no modifier")
