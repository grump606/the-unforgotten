extends RefCounted
## Phase 4b: the Thief retunes and new cards, played in the real engine. Fixtures build fights in code.
## Registered by run_tests.gd.

var _failures := 0


func run() -> int:
	_failures = 0
	_test_card_data()
	_test_light_fingers_ready()
	_test_find_the_seam()
	_test_filch_and_trinket()
	_test_filch_hand_full()
	_test_trinket_end_of_turn()
	_test_created_cards_are_fight_only()
	_test_borrowed_time()
	_test_many_hands()
	_test_sharpen()
	_test_quick_study()
	_test_cleaned_out()
	_test_sharpen_then_many_hands()
	_test_reward_pools()
	_test_describe_text()
	return _failures


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAIL: " + label)


func _card(id: String) -> CardData:
	return load("res://data/cards/%s.tres" % id) as CardData


func _trinket() -> CardData:
	return load(StarterContent.CREATED_CARD_PATHS[&"trinket"]) as CardData


func _plain(id: String) -> CardData:
	return CardData.make(StringName(id), id, 1, [CardEffect.make(CardEffect.Kind.DAMAGE, 1)] as Array[CardEffect])


func _plains(count: int, prefix: String = "p") -> Array[CardData]:
	var out: Array[CardData] = []
	for i in count:
		out.append(_plain("%s%d" % [prefix, i]))
	return out


func _hits(amount: int) -> Array[CardEffect]:
	var intents: Array[CardEffect] = [CardEffect.make(CardEffect.Kind.DAMAGE, amount)]
	return intents


## A started fight whose hand and draw pile are then set exactly (the first turn's draw is replaced).
func _fight(hand: Array[CardData], draw: Array[CardData] = [], intents: Array[CardEffect] = [], enemy_hp: int = 500, player_hp: int = 500) -> Combat:
	var enemies: Array[EnemyData] = [EnemyData.make("E", enemy_hp, intents)]
	var deck: Array[CardData] = []
	deck.append_array(hand)
	deck.append_array(draw)
	var combat := Combat.new(Combatant.new("p", player_hp), deck, enemies, 1)
	combat.start()
	combat.piles.hand.clear()
	combat.piles.hand.append_array(hand)
	combat.piles.draw_pile.clear()
	combat.piles.draw_pile.append_array(draw)
	combat.piles.discard_pile.clear()
	combat.piles.forgotten.clear()
	return combat


func _count_id(cards: Array[CardData], id: StringName) -> int:
	var total := 0
	for card in cards:
		if card.id == id:
			total += 1
	return total


func _test_card_data() -> void:
	var thief_ids := ["sleight", "mark_the_weak", "lift", "pocket_watch", "spree", "sharpen", "quick_study", "cleaned_out"]
	for id in thief_ids:
		_check(_card(id).character == &"thief", "%s is a Thief card" % id)
	_check(_trinket().character == &"", "the Trinket belongs to no class")
	var costs := {"sleight": 0, "mark_the_weak": 1, "lift": 1, "pocket_watch": 1, "spree": 2, "sharpen": 1, "quick_study": 0, "cleaned_out": 0}
	for id in costs:
		_check(_card(id).cost == costs[id], "%s costs %d" % [id, costs[id]])
	_check(_trinket().cost == 0 and _trinket().fading, "the Trinket costs 0 and is Fading")
	_check(_card("sleight").ready and _card("pocket_watch").forgotten and _card("cleaned_out").surge, "Ready, Forgotten and Surge are set")
	_check(_card("cleaned_out").cost == 0 and _card("cleaned_out").surge, "Cleaned Out is a Surge card")
	_check(_card("cutting_word").describe() == "Deal 3, Expose 1", "Cutting Word is untouched")


func _test_light_fingers_ready() -> void:
	var fingers := _card("sleight")
	var all_ok := true
	for seed_value in 12:
		var deck: Array[CardData] = [fingers]
		deck.append_array(_plains(19))
		var enemies: Array[EnemyData] = [EnemyData.make("E", 50, [] as Array[CardEffect])]
		var combat := Combat.new(Combatant.new("p", 40), deck, enemies, seed_value)
		combat.start()
		if not combat.piles.hand.has(fingers) or combat.piles.hand.size() != Combat.HAND_SIZE:
			all_ok = false
	_check(all_ok, "Light Fingers opens turn 1 in the hand of 5 for every seed")
	var twice: Array[CardData] = [fingers, fingers]
	twice.append_array(_plains(18))
	var enemies2: Array[EnemyData] = [EnemyData.make("E", 50, [] as Array[CardEffect])]
	var both := Combat.new(Combatant.new("p", 40), twice, enemies2, 3)
	both.start()
	_check(_count_id(both.piles.hand, &"sleight") == 2, "both copies of Light Fingers open in hand")


func _test_find_the_seam() -> void:
	var seam := _card("mark_the_weak")
	var combat := _fight([seam], [], _hits(5), 500, 100)
	_check(combat.play_card(0, 0), "Find the Seam plays")
	var enemy := combat.enemies[0]
	_check(combat.energy == Combat.ENERGY_PER_TURN - 1, "Find the Seam costs 1")
	_check(enemy.status_turns(Combatant.Status.EXPOSED) == 2, "Find the Seam exposes for 2 turns")
	_check(enemy.status_turns(Combatant.Status.SHAKEN) == 1, "Find the Seam shakes for 1 turn")
	combat.end_player_turn()
	_check(combat.player.hp == 100 - 3, "a Shaken enemy's attack of 5 deals 3 (3/4 rounded down)")
	_check(enemy.status_turns(Combatant.Status.SHAKEN) == 0, "Shaken wore off after its one attack")


func _test_filch_and_trinket() -> void:
	var filch := _card("lift")
	var combat := _fight([filch], _plains(3))
	_check(combat.play_card(0, 0), "Filch plays")
	_check(combat.enemies[0].hp == 497, "Filch deals 3")
	_check(combat.piles.hand.size() == 1 and combat.piles.hand[0].id == &"trinket", "Filch puts a Trinket in hand")
	_check(combat.piles.draw_pile.size() == 3, "Filch no longer draws")
	_check(combat.play_card(0, 0), "the Trinket plays for 0 energy")
	_check(combat.enemies[0].hp == 497 - 4, "the Trinket deals 4")
	_check(combat.energy == Combat.ENERGY_PER_TURN - 1, "the Trinket is free")


func _test_filch_hand_full() -> void:
	var filch := _card("lift")
	var hand: Array[CardData] = [filch]
	hand.append_array(_plains(Combat.HAND_MAX))
	var combat := _fight(hand)
	_check(combat.play_card(0, 0), "Filch plays from a full hand")
	_check(combat.piles.hand.size() == Combat.HAND_MAX, "the hand is full after Filch leaves it")
	_check(_count_id(combat.piles.hand, &"trinket") == 0, "the Trinket does not fit in a full hand")
	_check(_count_id(combat.piles.discard_pile, &"trinket") == 1, "the Trinket falls back to the discard pile")


func _test_trinket_end_of_turn() -> void:
	var filch := _card("lift")
	var hand: Array[CardData] = [filch]
	hand.append_array(_plains(Combat.HAND_SIZE))
	var combat := _fight(hand)
	combat.play_card(0, 0)
	_check(combat.piles.hand.size() == Combat.HAND_SIZE + 1, "five kept cards plus the Trinket in hand")
	_check(combat.piles.counted_in_hand() == Combat.HAND_SIZE, "the Trinket does not count toward the 5 kept")
	_check(combat.end_player_turn(), "ending the turn needs no discard for the Trinket")
	_check(_count_id(combat.piles.forgotten, &"trinket") == 1, "an unplayed Trinket becomes Forgotten")
	_check(_count_id(combat.piles.hand, &"trinket") == 0, "the Trinket leaves the hand")


func _test_created_cards_are_fight_only() -> void:
	var filch := _card("lift")
	var deck: Array[CardData] = [filch]
	deck.append_array(_plains(9))
	var before := deck.duplicate()
	var enemies: Array[EnemyData] = [EnemyData.make("E", 30, [] as Array[CardEffect])]
	var combat := Combat.new(Combatant.new("p", 40), deck, enemies, 4)
	combat.start()
	var at := combat.piles.hand.find(filch)
	_check(at >= 0, "Filch is in the opening hand")
	combat.play_card(at, 0)
	_check(_count_id(combat.piles.hand, &"trinket") == 1, "Filch made a Trinket in the fight")
	_check(deck == before and _count_id(deck, &"trinket") == 0, "the deck array is unchanged by the fight")
	var next_deck: Array[CardData] = deck
	var fresh := Combat.new(Combatant.new("p", 40), next_deck, enemies, 5)
	fresh.start()
	_check(_count_id(fresh.piles.hand, &"trinket") + _count_id(fresh.piles.draw_pile, &"trinket") == 0, "the next fight starts without the Trinket")


func _test_borrowed_time() -> void:
	var watch := _card("pocket_watch")
	var combat := _fight([watch], _plains(2))
	_check(combat.play_card(0), "Borrowed Time plays")
	_check(combat.energy == Combat.ENERGY_PER_TURN - 1 + 2, "Borrowed Time nets +1 energy")
	_check(combat.piles.hand.is_empty(), "Borrowed Time no longer draws")
	_check(combat.piles.forgotten == ([watch] as Array[CardData]), "a played Borrowed Time is Forgotten")
	_check(combat.piles.discard_pile.is_empty(), "Borrowed Time skips the discard pile")


func _test_many_hands() -> void:
	var hands := _card("spree")
	var combat := _fight([hands])
	combat.play_card(0, 0)
	_check(combat.enemies[0].hp == 500 - 9, "Many Hands deals 3 three times")
	_check(combat.energy == Combat.ENERGY_PER_TURN - 2, "Many Hands costs 2")
	# Three separate hits: Block soaks the first hit only partly, Expose and Malice apply to each.
	var seam := _card("mark_the_weak")
	var sharpen := _card("sharpen")
	var rich := _fight([seam, sharpen, hands])
	rich.energy = 10
	rich.enemies[0].gain_block(2)
	rich.play_card(0, 0)
	rich.play_card(0, 0)
	var after_setup := rich.enemies[0].hp
	rich.play_card(0, 0)
	# Each hit is (3 + 1) x 1.5 = 6; the first loses 2 to Block.
	_check(after_setup - rich.enemies[0].hp == 6 * 3 - 2, "Many Hands: each of the 3 hits takes Malice and Expose, and Block soaks per hit")


func _test_sharpen() -> void:
	var sharpen := _card("sharpen")
	var shove := CardData.make(&"s", "s", 0, [CardEffect.make(CardEffect.Kind.DAMAGE, 6)] as Array[CardEffect])
	var combat := _fight([sharpen, shove, shove], [], [] as Array[CardEffect])
	combat.play_card(0)
	_check(combat.player.stacks(Combatant.Status.MALICE) == 1, "Sharpen gives Malice +1")
	combat.play_card(0, 0)
	_check(combat.enemies[0].hp == 500 - 7, "a hit after Sharpen deals one more")
	combat.end_player_turn()
	_check(combat.player.stacks(Combatant.Status.MALICE) == 1, "Sharpen's Malice lasts into the next turn")
	combat.piles.hand.append(shove)
	combat.play_card(combat.piles.hand.size() - 1, 0)
	_check(combat.enemies[0].hp == 500 - 14, "and still adds to a hit on turn 2")


func _test_quick_study() -> void:
	var study := _card("quick_study")
	var shove := CardData.make(&"s", "s", 0, [CardEffect.make(CardEffect.Kind.DAMAGE, 6)] as Array[CardEffect])
	var combat := _fight([study, shove])
	_check(combat.play_card(0), "Quick Study plays for free")
	_check(combat.energy == Combat.ENERGY_PER_TURN, "Quick Study costs no energy")
	_check(combat.player.stacks(Combatant.Status.MALICE) == 2, "Quick Study gives Malice +2")
	combat.play_card(0, 0)
	_check(combat.enemies[0].hp == 500 - 8, "this turn a hit deals +2")
	combat.end_player_turn()
	_check(combat.player.stacks(Combatant.Status.MALICE) == 0, "Quick Study's Malice expires when the next turn starts")


func _test_cleaned_out() -> void:
	var expected := {0: 0, 1: 3, 3: 9}
	for energy in expected:
		var out := _card("cleaned_out")
		var combat := _fight([out])
		combat.energy = energy
		_check(combat.play_card(0, 0), "Cleaned Out plays with %d energy" % energy)
		_check(combat.energy == 0, "Cleaned Out spends all energy (%d)" % energy)
		_check(combat.enemies[0].hp == 500 - expected[energy], "Cleaned Out with %d energy deals %d" % [energy, expected[energy]])
	# Each point of energy is its own hit: Block soaks per hit, Malice adds per hit.
	var sharpen := _card("sharpen")
	var out2 := _card("cleaned_out")
	var combat2 := _fight([sharpen, out2])
	combat2.play_card(0)
	_check(combat2.energy == 2, "Sharpen left 2 energy")
	combat2.play_card(0, 0)
	_check(combat2.enemies[0].hp == 500 - 8, "Cleaned Out with Malice +1 and 2 energy is two hits of 4")


func _test_sharpen_then_many_hands() -> void:
	var combat := _fight([_card("sharpen"), _card("spree")])
	combat.energy = 3
	combat.play_card(0)
	combat.play_card(0, 0)
	_check(combat.enemies[0].hp == 500 - 12, "Sharpen then Many Hands: three hits of 3 + 1")
	_check(combat.energy == 0, "Sharpen (1) and Many Hands (2) use the 3 energy")


func _test_reward_pools() -> void:
	var ids := ["sharpen", "quick_study", "cleaned_out"]
	var thief_pool := {}
	for card in StarterContent.reward_pool(&"thief"):
		thief_pool[String(card.id)] = true
	for id in ids:
		_check(thief_pool.has(id), "%s is in the Thief reward pool" % id)
	for character in StarterContent.character_ids():
		if character == &"thief":
			continue
		for card in StarterContent.reward_pool(character):
			_check(not ids.has(String(card.id)), "%s is not in the %s reward pool" % [card.id, character])
	_check(not thief_pool.has("trinket"), "the Trinket is not in the Thief reward pool")


func _test_describe_text() -> void:
	var cases := {
		"sleight": ["Expose 1", "Ready"],
		"mark_the_weak": ["Expose 2", "Shaken 1"],
		"lift": ["Deal 3", "Add 1 Trinket to your hand"],
		"pocket_watch": ["Gain 2 energy", "Forgotten"],
		"spree": ["Deal 3 x3"],
		"sharpen": ["Malice +1"],
		"quick_study": ["Malice +2 this turn"],
		"cleaned_out": ["Deal 3 x energy spent", "Surge"],
	}
	for id in cases:
		var card := _card(id)
		var text := card.describe() + " | " + ", ".join(card.keyword_lines())
		print("  %s: %s" % [id, text])
		for want in cases[id]:
			_check(text.contains(want), "%s reads '%s' (got '%s')" % [id, want, text])
	_check("Deal 4" in _trinket().describe() and _trinket().keyword_lines().has("Fading"), "the Trinket reads Deal 4, Fading")
	_check(not _card("lift").describe().contains("Draw"), "Filch no longer mentions Draw")
	_check(not _card("pocket_watch").describe().contains("Draw"), "Borrowed Time no longer mentions Draw")
