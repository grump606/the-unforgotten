extends "res://tests/combat_test_support.gd"
## Effects added for the later chapters (docs/CHAPTER2_PLAN.md): File (an intent that tucks the cards you kept to the bottom
## of your draw pile) and Unseen (an enemy that cannot be targeted while another enemy lives).


func run() -> int:
	_failures = 0
	_test_file_from_hand()
	_test_file_intent()
	_test_file_text()
	_test_unseen_targeting()
	_test_unseen_all_enemies_and_alone()
	_test_unseen_survives_scaling()
	return _failures


func _no_intents() -> Array[CardEffect]:
	return []


func _intent_list(effect: CardEffect) -> Array[CardEffect]:
	return [effect]


## True when `cards` holds exactly `expected`, in order.
func _same(cards: Array[CardData], expected: Array) -> bool:
	if cards.size() != expected.size():
		return false
	for i in cards.size():
		if cards[i] != expected[i]:
			return false
	return true


func _test_file_from_hand() -> void:
	var one := _card(1, _dmg(1))
	var three := _card(3, _dmg(3))
	var two := _card(2, _dmg(2))
	var anchored := _card(5, _dmg(5))
	anchored.anchor = true
	var piles := CardPiles.new(_deck(1, one), RandomNumberGenerator.new())
	piles.hand.assign([one, three, two, anchored])
	var drawn_before := piles.draw_pile.size()
	_check(piles.file_from_hand(2) == 2, "File 2 files two cards")
	_check(_same(piles.hand, [one, anchored]), "the dearest cards go first and an Anchored card stays")
	_check(piles.draw_pile.size() == drawn_before + 2 and piles.draw_pile[0] == two and piles.draw_pile[1] == three, "they go to the bottom of the draw pile, the last filed lowest")
	_check(piles.file_from_hand(5) == 1 and _same(piles.hand, [anchored]), "it files only what can be filed")
	_check(piles.file_from_hand(1) == 0 and piles.file_from_hand(0) == 0 and piles.file_from_hand(-3) == 0, "nothing left to file, or a non-positive count, files nothing")


func _test_file_intent() -> void:
	var intents: Array[CardEffect] = [CardEffect.make(CardEffect.Kind.FILE, 1)]
	var combat := Combat.new(Combatant.new("p", 40), _deck(20, _card(1, _dmg(1))), _enemies(1, 99, intents))
	combat.start()
	_check(combat.piles.hand.size() == Combat.HAND_SIZE, "a full hand to start")
	var keep_all: Array[int] = []
	var draw_before := combat.piles.draw_pile.size()
	combat.end_player_turn(keep_all)
	# The enemy filed one of the five kept cards to the bottom of the draw pile; the next hand draws back up to the hand size.
	_check(combat.piles.hand.size() == Combat.HAND_SIZE, "the next hand is back to the hand size")
	_check(combat.piles.discard_pile.is_empty(), "the filed card did not go to the discard pile")
	_check(combat.piles.draw_pile.size() == draw_before, "the filed card went under the draw pile and one card was drawn to refill the hand")
	combat.abandon()
	# A player card with File works on the player's own hand too.
	var filing := _card(0, [CardEffect.make(CardEffect.Kind.FILE, 2)])
	var deck: Array[CardData] = [filing]
	deck.append_array(_deck(11, _card(1, _dmg(1))))
	var own := Combat.new(Combatant.new("p", 40), deck, _enemies(1, 99, []))
	own.start()
	var index := own.piles.hand.find(filing)
	if index == -1:
		own.piles.hand.append(filing)
		index = own.piles.hand.size() - 1
	var hand_before := own.piles.hand.size()
	_check(own.play_card(index, 0), "a File card plays")
	_check(own.piles.hand.size() == hand_before - 1 - 2, "and files two more cards from the hand")
	own.abandon()


func _test_file_text() -> void:
	var effect := CardEffect.make(CardEffect.Kind.FILE, 2)
	_check(effect.describe() == "File 2" and CardGlossary.EFFECT_TEXT.has(CardEffect.Kind.FILE), "File has a line and a glossary entry")
	_check(StarterContent.enemy_threat(EnemyData.make("t", 20, _intent_list(effect), &"t")) > 0.0, "an enemy that only files still has a threat value")


func _unseen_pair(unseen_first: bool) -> Combat:
	var seen := EnemyData.make("Seen", 30, _no_intents(), &"seen")
	var hidden := EnemyData.make("Hidden", 30, _no_intents(), &"hidden")
	hidden.unseen = true
	var list: Array[EnemyData] = []
	list.append(hidden if unseen_first else seen)
	list.append(seen if unseen_first else hidden)
	var combat := Combat.new(Combatant.new("p", 40), _deck(20, _card(0, _dmg(5))), list)
	combat.start()
	return combat


func _test_unseen_targeting() -> void:
	var combat := _unseen_pair(true) # the Unseen enemy is index 0
	_check(combat.is_shielded(combat.enemies[0]) and not combat.is_shielded(combat.enemies[1]), "the Unseen enemy is shielded while another lives")
	_check(combat.play_card(0, 0), "aiming at the Unseen enemy is allowed...")
	_check(combat.enemies[0].hp == 30 and combat.enemies[1].hp == 25, "...but the hit lands on the enemy that can be targeted")
	_check(combat.play_card(0, -1) and combat.enemies[1].hp == 20 and combat.enemies[0].hp == 30, "the default target skips the Unseen enemy")
	combat.abandon()


func _test_unseen_all_enemies_and_alone() -> void:
	var sweep := _mode_card(CardData.TargetMode.ALL_ENEMIES, _dmg(4), 0)
	var hidden := EnemyData.make("Hidden", 30, _no_intents(), &"hidden")
	hidden.unseen = true
	var seen := EnemyData.make("Seen", 4, _no_intents(), &"seen")
	var list: Array[EnemyData] = [hidden, seen]
	var deck: Array[CardData] = [sweep, _card(0, _dmg(5)), _card(0, _dmg(5)), _card(0, _dmg(5)), _card(0, _dmg(5)), _card(0, _dmg(5))]
	var combat := Combat.new(Combatant.new("p", 40), deck, list)
	combat.start()
	var index := combat.piles.hand.find(sweep)
	_check(index != -1 and combat.play_card(index), "an all-enemies card plays")
	_check(combat.enemies[0].hp == 26 and combat.enemies[1].is_dead(), "it reaches the Unseen enemy too")
	_check(not combat.is_shielded(combat.enemies[0]), "with nothing else alive the Unseen enemy can be targeted")
	var next := combat.piles.hand.size() - 1
	_check(combat.play_card(next, 0) and combat.enemies[0].hp < 26, "and a targeted card hits it")
	combat.abandon()
	# Two Unseen enemies shield nothing from each other.
	var a := EnemyData.make("A", 30, _no_intents(), &"a")
	var b := EnemyData.make("B", 30, _no_intents(), &"b")
	a.unseen = true
	b.unseen = true
	var pair: Array[EnemyData] = [a, b]
	var both := Combat.new(Combatant.new("p", 40), _deck(20, _card(0, _dmg(5))), pair)
	both.start()
	_check(not both.is_shielded(both.enemies[0]) and not both.is_shielded(both.enemies[1]), "enemies that are all Unseen can be targeted")
	both.abandon()


func _test_unseen_survives_scaling() -> void:
	var base := EnemyData.make("Hidden", 30, _intent_list(CardEffect.make(CardEffect.Kind.DAMAGE, 5)), &"hidden")
	base.unseen = true
	_check(Encounters.scaled(base, 1.5).unseen, "a scaled copy stays Unseen")
	_check(StarterContent.elite_named(base).unseen, "an elite copy stays Unseen")
