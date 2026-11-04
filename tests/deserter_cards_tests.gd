extends RefCounted
## Phase 4c: the Deserter retunes (Last Stand, Heavy Blow, Iron Resolve) and Dig Deep, played through the
## real engine from the shipped data files. Registered by run_tests.gd.

const S := Combatant.Status

var _failures := 0


func run() -> int:
	_failures = 0
	_test_data()
	_test_last_stand_anchor()
	_test_heavy_blow_forgotten()
	_test_iron_resolve_ward()
	_test_dig_deep_surge()
	_test_synergy()
	_test_reward_pool()
	_test_describe()
	return _failures


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAIL: " + label)


func _load(id: String) -> CardData:
	return load("res://data/cards/%s.tres" % id) as CardData


func _plain(id: String) -> CardData:
	return CardData.make(StringName(id), id, 1, [CardEffect.make(CardEffect.Kind.DAMAGE, 1)] as Array[CardEffect])


func _self_card(id: String, cost: int, effects: Array[CardEffect]) -> CardData:
	return CardData.make(StringName(id), id, cost, effects, CardData.TargetMode.SELF)


func _ints(values: Array) -> Array[int]:
	var out: Array[int] = []
	out.assign(values)
	return out


## A started fight whose hand and draw pile are set exactly.
func _fight(hand: Array[CardData], draw: Array[CardData] = [], relics: Array[RelicData] = []) -> Combat:
	var enemies: Array[EnemyData] = [EnemyData.make("E", 500, [] as Array[CardEffect])]
	var deck: Array[CardData] = []
	deck.append_array(hand)
	deck.append_array(draw)
	var combat := Combat.new(Combatant.new("p", 500), deck, enemies, 1, relics)
	combat.start()
	combat.piles.hand.clear()
	combat.piles.hand.append_array(hand)
	combat.piles.draw_pile.clear()
	combat.piles.draw_pile.append_array(draw)
	combat.piles.discard_pile.clear()
	combat.piles.forgotten.clear()
	return combat


func _test_data() -> void:
	var last_stand := _load("last_stand")
	_check(last_stand.cost == 3 and last_stand.anchor and not last_stand.forgotten and last_stand.character == &"deserter", "Last Stand: cost 3, Anchor, deserter")
	var heavy := _load("heavy_blow")
	_check(heavy.cost == 2 and heavy.forgotten and heavy.effects.size() == 1 and heavy.effects[0].amount == 16, "Heavy Blow: cost 2, Deal 16, Forgotten")
	var iron := _load("iron_resolve")
	_check(iron.cost == 2 and iron.effects.size() == 2 and iron.effects[0].amount == 6, "Iron Resolve: cost 2, Block 6 first")
	var ward_effect: CardEffect = iron.effects[1]
	_check(ward_effect.kind == CardEffect.Kind.WARD and ward_effect.amount == 1 and not ward_effect.temporary, "Iron Resolve then a permanent Ward +1")
	var deep := _load("dig_deep")
	_check(deep != null and deep.id == &"dig_deep" and deep.display_name == "Dig Deep" and deep.cost == 0, "Dig Deep: id, name, cost 0")
	_check(deep.surge and deep.target_mode == CardData.TargetMode.SELF and deep.character == &"deserter", "Dig Deep: Surge, self, deserter")
	var deep_effect: CardEffect = deep.effects[0]
	_check(deep.effects.size() == 1 and deep_effect.kind == CardEffect.Kind.BLOCK and deep_effect.amount == 5 and deep_effect.per_energy, "Dig Deep: Block 5 per energy")


func _test_last_stand_anchor() -> void:
	var last_stand := _load("last_stand")
	var hand: Array[CardData] = [last_stand]
	for i in 5:
		hand.append(_plain("p%d" % i))
	var draw: Array[CardData] = []
	for i in 10:
		draw.append(_plain("d%d" % i))
	var combat := _fight(hand, draw)
	combat.begin_discard()
	_check(combat.discard_required() == 0, "Last Stand plus 5 others needs no discard")
	_check(not combat.toggle_discard(0) and not combat.is_valid_discard(_ints([0])), "Last Stand cannot be marked for discard")
	_check(combat.end_player_turn(), "the turn ends with no discard")
	_check(combat.piles.hand.has(last_stand), "Last Stand is still in hand next turn")
	_check(combat.piles.counted_in_hand() == 5, "the refill still gives 5 counted cards")
	combat.begin_discard()
	for i in combat.piles.hand.size():
		combat.toggle_discard(i)
	var confirmed := combat.confirm_discard()
	_check(confirmed and combat.piles.hand.has(last_stand), "discarding every discardable card keeps Last Stand")
	combat.energy = 3
	var index := combat.piles.hand.find(last_stand)
	var played := combat.play_card(index)
	_check(played and combat.player.block == 12 and combat.player.hold == 10, "affordable later, it gives Block 12 and Hold 10")


func _test_heavy_blow_forgotten() -> void:
	var heavy := _load("heavy_blow")
	var deck: Array[CardData] = [heavy]
	var enemies: Array[EnemyData] = [EnemyData.make("E", 100, [] as Array[CardEffect])]
	var first := Combat.new(Combatant.new("p", 50), deck, enemies, 1)
	first.start()
	_check(first.play_card(0), "Heavy Blow plays")
	_check(first.enemies[0].hp == 84, "Heavy Blow deals 16")
	_check(first.piles.forgotten == ([heavy] as Array[CardData]) and first.piles.discard_pile.is_empty(), "it goes to the Forgotten pile, not discard")
	_check(deck == ([heavy] as Array[CardData]), "the deck array is unchanged")
	var second := Combat.new(Combatant.new("p", 50), deck, enemies, 1)
	second.start()
	_check(second.piles.hand == ([heavy] as Array[CardData]) and second.piles.forgotten.is_empty(), "Heavy Blow is back for the next fight")


func _test_iron_resolve_ward() -> void:
	var iron := _load("iron_resolve")
	var next_block := _self_card("b", 0, [CardEffect.make(CardEffect.Kind.BLOCK, 5)] as Array[CardEffect])
	var combat := _fight([iron, next_block])
	_check(combat.play_card(0), "Iron Resolve plays")
	_check(combat.player.block == 6 and combat.player.stacks(S.WARD) == 1, "Iron Resolve gives Block 6 and Ward +1")
	combat.play_card(0)
	_check(combat.player.block == 6 + 6, "the next Block card gets +1")
	# Ward only touches card Block.
	var hold := _self_card("h", 0, [CardEffect.make(CardEffect.Kind.HOLD, 4), CardEffect.make(CardEffect.Kind.THORNS, 4)] as Array[CardEffect])
	var relic := RelicData.make(&"r", "R", RelicData.Kind.TURN_START_BLOCK, 4, 0)
	var fight2 := _fight([iron, hold], [], [relic] as Array[RelicData])
	var relic_block := fight2.player.block
	fight2.play_card(0)
	fight2.play_card(0)
	_check(fight2.player.block == relic_block + 6, "Ward leaves relic Block alone")
	_check(fight2.player.hold == 4 and fight2.player.thorns == 4, "Ward leaves Hold and Barbs alone")
	# Frayed reduces it afterwards: (5 + 1) x 3/4 = 4, and never to 0.
	var fray := _self_card("f", 0, [CardEffect.make(CardEffect.Kind.FRAYED, 1)] as Array[CardEffect])
	var tiny := _self_card("t", 0, [CardEffect.make(CardEffect.Kind.BLOCK, 2)] as Array[CardEffect])
	var fight3 := _fight([iron, fray, next_block, tiny])
	fight3.play_card(0)
	fight3.play_card(0)
	var before := fight3.player.block
	fight3.play_card(0)
	_check(fight3.player.block - before == 4, "Frayed trims Ward-boosted Block after the Ward: 6 becomes 4")
	var before_tiny := fight3.player.block
	fight3.play_card(0)
	_check(fight3.player.block - before_tiny == 2, "Block 2 plus Ward 1 under Frayed is 2 (3 x 3/4)")
	var fight4 := _fight([_load("dig_deep")])
	fight4.player.apply_status(S.FRAYED, 1)
	fight4.energy = 1
	fight4.play_card(0)
	_check(fight4.player.block == 3, "Frayed Block 5 becomes 3, not 0")


func _test_dig_deep_surge() -> void:
	for spend in [0, 1, 3]:
		var combat := _fight([_load("dig_deep")])
		combat.energy = spend
		_check(combat.can_play(0) and combat.play_card(0), "Dig Deep plays at %d energy" % spend)
		_check(combat.energy == 0, "Dig Deep spends all energy (from %d)" % spend)
		_check(combat.player.block == 5 * spend, "Dig Deep gives Block 5 per energy at %d" % spend)
	var warded := _fight([_load("dig_deep")])
	warded.player.apply_status(S.WARD, 2)
	warded.energy = 3
	warded.play_card(0)
	_check(warded.player.block == 17, "Ward applies once to the whole Block: 15 + 2")
	var empty := _fight([_load("dig_deep")])
	empty.player.apply_status(S.WARD, 2)
	empty.energy = 0
	empty.play_card(0)
	_check(empty.player.block == 0, "Dig Deep at 0 energy gives nothing, even with Ward")


func _test_synergy() -> void:
	var combat := _fight([_load("iron_resolve"), _load("dig_deep")])
	combat.energy = 4
	combat.play_card(0)
	_check(combat.energy == 2, "Iron Resolve leaves 2 energy")
	combat.play_card(0)
	_check(combat.energy == 0 and combat.player.block == 6 + 5 * 2 + 1, "Dig Deep at 2 energy after Iron Resolve: 10 + 1 Ward, 17 total")


func _test_reward_pool() -> void:
	var in_deserter := false
	for card in StarterContent.reward_pool(&"deserter"):
		in_deserter = in_deserter or card.id == &"dig_deep"
	_check(in_deserter, "Dig Deep is in the Deserter reward pool")
	for id in [&"thief", &"medium"]:
		for card in StarterContent.reward_pool(id):
			_check(card.id != &"dig_deep", "Dig Deep is not in the %s pool" % id)
	_check(StarterContent.ALL_CARD_PATHS.has(StarterContent.DIG_DEEP_PATH), "Dig Deep is registered")


func _test_describe() -> void:
	_check(_load("heavy_blow").describe() == "Deal 16", "Heavy Blow text: %s" % _load("heavy_blow").describe())
	_check(_load("iron_resolve").describe() == "Block 6, Ward +1", "Iron Resolve text: %s" % _load("iron_resolve").describe())
	_check(_load("dig_deep").describe() == "Block 5 per energy spent", "Dig Deep text: %s" % _load("dig_deep").describe())
	_check(_load("last_stand").keyword_lines() == PackedStringArray(["Anchor"]), "Last Stand shows Anchor")
	_check(_load("heavy_blow").keyword_lines() == PackedStringArray(["Forgotten"]), "Heavy Blow shows Forgotten")
	_check(_load("dig_deep").keyword_lines() == PackedStringArray(["Surge"]), "Dig Deep shows Surge")
