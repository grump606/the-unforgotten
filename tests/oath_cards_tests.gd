extends RefCounted
## The six shipped Oaths (docs/MECHANICS_PLAN.md, phase 6b): two per class, each valid, readable and playable.
## Numbers are provisional, so these check shape and behaviour, not tuning. Registered by run_tests.gd.

const EXPECTED := {
	&"thief": [&"quick_hands", &"light_step"],
	&"deserter": [&"unbroken_vow", &"standing_guard"],
	&"medium": [&"open_grave", &"quiet_debt"],
}

var _failures := 0


func run() -> int:
	_failures = 0
	_test_each_class_has_two_oaths()
	_test_text()
	_test_costs_are_commitments()
	_test_each_oath_plays_and_fires()
	_test_pile_viewer_lists_sworn()
	_test_not_in_starting_decks()
	return _failures


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAIL: " + label)


func _load(id: StringName) -> CardData:
	return load("res://data/cards/%s.tres" % id) as CardData


func _test_each_class_has_two_oaths() -> void:
	var found := {}
	for card in StarterContent.all_cards():
		if card.oath:
			found[card.character] = int(found.get(card.character, 0)) + 1
			_check(card.is_valid_oath(), "%s is a valid Oath" % card.id)
	for class_id in EXPECTED:
		_check(int(found.get(class_id, 0)) >= 2, "%s has at least its two original Oaths" % class_id)
		for id in EXPECTED[class_id]:
			var card := _load(id)
			_check(card != null and card.oath and card.character == class_id, "%s is a %s Oath" % [id, class_id])
			_check(StarterContent.reward_pool(class_id).has(card), "%s can be offered to %s" % [id, class_id])
	_check(not found.has(&""), "no neutral Oath")


func _test_text() -> void:
	for class_id in EXPECTED:
		for id in EXPECTED[class_id]:
			var card := _load(id)
			_check(card.keyword_lines() == PackedStringArray(["Oath"]), "%s shows the Oath keyword" % id)
			_check(card.describe().contains(card.oath_trigger_text() + ":"), "%s text names its trigger: %s" % [id, card.describe()])
	_check(_load(&"light_step").describe() == "Lose 2 HP. At turn start: Draw 1, Glimpse 2", "Light Step text: %s" % _load(&"light_step").describe())
	_check(_load(&"open_grave").describe() == "Lose 2 HP. When a card is Forgotten: Deal 4", "Open Grave text: %s" % _load(&"open_grave").describe())


## Each Oath has a price to pay when sworn (HP, or a Dread in the draw pile), except Quiet Debt, which costs HP each turn.
func _test_costs_are_commitments() -> void:
	for class_id in EXPECTED:
		for id in EXPECTED[class_id]:
			var card := _load(id)
			var pays := card.hp_cost() > 0
			for effect in card.effects:
				if effect.kind == CardEffect.Kind.ADD_CARD and effect.card != null and effect.card.dormant:
					pays = true
			for effect in card.oath_effects:
				if effect.kind == CardEffect.Kind.LOSE_HP:
					pays = true
			_check(pays, "%s has a downside" % id)
			_check(card.cost >= 1 and card.cost <= 2, "%s costs 1 to 2 energy" % id)


func _fight(card: CardData, enemy_count: int = 2) -> Combat:
	var enemies: Array[EnemyData] = []
	for i in enemy_count:
		enemies.append(EnemyData.make("E%d" % i, 100, []))
	var filler := CardData.make(&"f", "F", 0, [CardEffect.make(CardEffect.Kind.BLOCK, 0)] as Array[CardEffect], CardData.TargetMode.SELF)
	var combat := Combat.new(Combatant.new("p", 40), [card, filler] as Array[CardData], enemies)
	combat.start()
	return combat


func _test_each_oath_plays_and_fires() -> void:
	for class_id in EXPECTED:
		for id in EXPECTED[class_id]:
			var card := _load(id)
			var combat := _fight(card)
			var hp_before := combat.player.hp
			_check(combat.play_card(combat.piles.hand.find(card), 0), "%s can be played" % id)
			_check(combat.piles.sworn == [card], "%s is Sworn" % id)
			_check(combat.player.hp == hp_before - card.hp_cost(), "%s costs its HP" % id)
			var dread := 0
			for pile_card in combat.piles.draw_pile:
				if pile_card.dormant:
					dread += 1
			_check(dread == (1 if id in [&"quick_hands", &"unbroken_vow"] else 0), "%s adds Dread to the draw pile only when it should" % id)
	# Unbroken Vow: Ward +1 every turn, stacking.
	var vow := _fight(_load(&"unbroken_vow"))
	vow.play_card(vow.piles.hand.find(_load(&"unbroken_vow")), 0)
	vow.end_player_turn()
	vow.end_player_turn()
	_check(vow.player.status_turns(Combatant.Status.WARD) == 2, "Unbroken Vow adds Ward each turn")
	# Quiet Debt: Haunt on every enemy and an HP toll, each turn.
	var debt := _fight(_load(&"quiet_debt"))
	var hp := debt.player.hp
	debt.play_card(debt.piles.hand.find(_load(&"quiet_debt")), 0)
	debt.end_player_turn()
	_check(debt.player.hp == hp - 1, "Quiet Debt costs 1 HP at turn start")
	for enemy in debt.enemies:
		_check(enemy.status_turns(Combatant.Status.HAUNTED) > 0, "Quiet Debt Haunts every enemy")
	# Open Grave: a Forgotten card damages all enemies.
	var grave_card := _load(&"open_grave")
	var gone := CardData.make(&"gone", "Gone", 0, [CardEffect.make(CardEffect.Kind.BLOCK, 1)] as Array[CardEffect], CardData.TargetMode.SELF)
	gone.forgotten = true
	var enemies: Array[EnemyData] = [EnemyData.make("A", 100, []), EnemyData.make("B", 100, [])]
	var grave := Combat.new(Combatant.new("p", 40), [grave_card, gone] as Array[CardData], enemies)
	grave.start()
	grave.play_card(grave.piles.hand.find(grave_card), 0)
	grave.play_card(grave.piles.hand.find(gone), 0)
	_check(grave.enemies[0].hp == 96 and grave.enemies[1].hp == 96, "Open Grave deals 4 to every enemy when a card is Forgotten")


func _test_pile_viewer_lists_sworn() -> void:
	_check(PileViewer.PILE_NAMES[PileViewer.Pile.SWORN] == "Sworn", "the pile viewer has a Sworn tab")
	var card := _load(&"light_step")
	var combat := _fight(card, 1)
	combat.play_card(combat.piles.hand.find(card), 0)
	_check(PileViewer.shown_cards(combat.piles, PileViewer.Pile.SWORN) == [card], "the Sworn tab lists the sworn Oaths")


func _test_not_in_starting_decks() -> void:
	for class_id in StarterContent.character_ids():
		for card in StarterContent.starter_deck(class_id):
			_check(not card.oath, "%s does not start with an Oath" % class_id)
