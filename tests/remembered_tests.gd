extends "res://tests/test_base.gd"
## Phase 5a: Remembered (upgraded) cards. The variant model on CardData, the shipped remembered blocks,
## the rest stop's Remember choice in RunState, a Remembered card in a fight, and the vendor. Saves are
## covered in run_save_tests.gd and the rest screen in ui_screen_scenes_test.gd. Discovered by run_tests.gd.


func run() -> int:
	_failures = 0
	_test_variant_model()
	_test_keyword_changes()
	_test_shipped_blocks()
	_test_remember_at_rest()
	_test_remember_rejections()
	_test_combat_uses_remembered()
	_test_vendor_and_rewards()
	return _failures


func _card(card_id: String) -> CardData:
	for card in StarterContent.all_cards():
		if String(card.id) == card_id:
			return card
	return null


func _dmg(amount: int) -> Array[CardEffect]:
	return [CardEffect.make(CardEffect.Kind.DAMAGE, amount)] as Array[CardEffect]


## A run standing at its first rest stop (stop 3), with `character` as the class.
func _at_rest(character: StringName = &"thief") -> RunState:
	var state := RunState.new(5, character)
	state.read_story()
	for i in 2:
		state.complete_combat(true)
		state.resolve_reward(null)
	return state


func _test_variant_model() -> void:
	var base := CardData.make(&"t", "Thing", 2, _dmg(5))
	_check(base.remembered_card() == null and not base.can_remember() and base.base() == base, "a card with no block cannot be Remembered")
	base.remembered = RememberedData.make(_dmg(8), 1)
	var plus := base.remembered_card()
	_check(plus != null and base.can_remember(), "a card with a block builds a variant")
	_check(plus.id == &"t" and plus.display_name == "Thing+" and plus.is_remembered, "the variant keeps the id, adds + to the name and is flagged")
	_check(plus.cost == 1 and plus.effects.size() == 1 and plus.effects[0].amount == 8, "the variant takes the block's cost and effects")
	_check(plus.describe() == "Deal 8" and base.describe() == "Deal 5", "the text describes the upgraded effects; the base is unchanged")
	_check(plus.base() == base and plus.base_card == base, "the variant knows its base")
	_check(plus.remembered_card() == null and not plus.can_remember(), "a Remembered card cannot be Remembered again")
	_check(base.remembered_card() == plus, "the variant is built once, so deck copies share it")
	var keep := CardData.make(&"k", "Keep", 3, _dmg(5))
	keep.remembered = RememberedData.make(_dmg(6))
	_check(keep.remembered_card().cost == 3 and keep.cost == 3, "cost -1 keeps the card's own cost")


func _test_keyword_changes() -> void:
	var base := CardData.make(&"k", "Keep", 1, _dmg(4))
	base.forgotten = true
	base.remembered = RememberedData.make(_dmg(4), -1, PackedStringArray(["ready", "anchor"]), PackedStringArray(["forgotten"]))
	var plus := base.remembered_card()
	_check(plus.ready and plus.anchor and not plus.forgotten, "gain and lose keywords apply to the variant")
	_check(base.forgotten and not base.ready and not base.anchor, "the base card's keywords are untouched")
	_check(plus.keyword_lines() == PackedStringArray(["Ready", "Anchor"]), "the variant's keyword lines follow")


func _test_shipped_blocks() -> void:
	var with_block := 0
	var by_class := {}
	for card in StarterContent.all_cards():
		if card.remembered == null:
			continue
		with_block += 1
		by_class[card.character] = int(by_class.get(card.character, 0)) + 1
		var plus := card.remembered_card()
		var label := String(card.id)
		_check(plus != null and plus.id == card.id, "%s: the block builds a variant with the same id" % label)
		if plus == null:
			continue
		_check(not plus.effects.is_empty() and plus.cost >= 0, "%s: the variant has effects and a valid cost" % label)
		_check(not (plus.fading and plus.anchor), "%s: never Fading together with Anchor" % label)
		var changed := plus.describe() != card.describe() or plus.cost != card.cost or plus.keyword_lines() != card.keyword_lines()
		_check(changed, "%s: the upgrade changes something" % label)
		_check(plus.target_mode == card.target_mode and plus.surge == card.surge and plus.dormant == card.dormant, "%s: the card keeps its identity (target, Surge, Dormant)" % label)
		# card_value counts cost as strength, so a cheaper card scores lower; judge those by effects and cost.
		_check(plus.cost < card.cost or Vendor.card_value(plus) > Vendor.card_value(card), "%s: the upgrade is worth more than the base" % label)
		_check(Vendor.card_value(plus) - Vendor.card_value(card) <= 10, "%s: the upgrade is modest" % label)
		for keyword in card.remembered.gain_keywords + card.remembered.lose_keywords:
			_check(RememberedData.KEYWORDS.has(keyword), "%s: '%s' is a real keyword" % [label, keyword])
	_check(with_block >= 38, "thirty-eight cards ship with a remembered block (%d)" % with_block)
	for class_id in [&"thief", &"deserter", &"medium", &"stray"]:
		_check(int(by_class.get(class_id, 0)) >= 2, "%s has at least two Remembered cards" % class_id)
	_check(int(by_class.get(&"", 0)) >= 2, "a couple of neutral cards can be Remembered")


func _test_remember_at_rest() -> void:
	var state := _at_rest()
	_check(state.current_stop().type == RunState.StopType.REST, "setup: at the rest stop")
	var options := state.rememberable_indices()
	_check(not options.is_empty(), "the Thief's starter deck holds a card that can be Remembered")
	for i in options:
		_check(state.deck[i].can_remember(), "every offered position holds a rememberable card")
	state.player.take_damage(10)
	var hp := state.player.hp
	var size := state.deck.size()
	var pick: int = options[0]
	var base := state.deck[pick]
	_check(state.remember(pick), "remembering a card succeeds")
	_check(state.deck.size() == size and state.deck[pick].is_remembered and state.deck[pick].base() == base, "the card is replaced in place by its Remembered form")
	_check(state.player.hp == hp, "remembering does not heal")
	_check(state.stop_index == 4, "remembering advances the stop")
	_check(state.rememberable_indices().is_empty(), "no choices off a rest stop")
	# A second rest cannot remember the same card again.
	var again := _at_rest()
	var first: int = again.rememberable_indices()[0]
	again.deck[first] = again.deck[first].remembered_card()
	_check(not again.rememberable_indices().has(first), "an already Remembered card is not offered")
	# Resting still heals and leaves the deck alone.
	var rest := _at_rest()
	rest.player.take_damage(10)
	var plain := rest.deck.duplicate()
	_check(rest.rest() == 10 and rest.deck == plain, "Rest still heals to full without touching the deck")


func _test_remember_rejections() -> void:
	var state := RunState.new(5, &"thief")
	_check(not state.remember(0) and state.stop_index == 0, "remember does nothing off a rest stop")
	var rest := _at_rest()
	var stop := rest.stop_index
	_check(not rest.remember(-1) and not rest.remember(rest.deck.size()), "a bad deck position is rejected")
	var plain_index := -1
	for i in rest.deck.size():
		if not rest.deck[i].can_remember():
			plain_index = i
			break
	if plain_index >= 0:
		_check(not rest.remember(plain_index), "a card with no block is rejected")
	_check(rest.stop_index == stop, "a rejected remember changes nothing")
	var done := _at_rest()
	var i: int = done.rememberable_indices()[0]
	done.remember(i)
	_check(not done.remember(i), "the same position cannot be remembered twice")


func _test_combat_uses_remembered() -> void:
	var shove := _card("shove")
	var plus := shove.remembered_card()
	_check(plus != null and plus.effects[0].amount > shove.effects[0].amount, "Shove has a stronger Remembered form")
	var deck: Array[CardData] = [plus]
	var datas: Array[EnemyData] = [EnemyData.make("E", 100, [] as Array[CardEffect])]
	var combat := Combat.new(Combatant.new("p", 40), deck, datas, 1)
	combat.start()
	var hand_card := combat.piles.hand[0]
	_check(hand_card.is_remembered and combat.play_card(0, 0), "a Remembered card plays in a fight")
	_check(combat.enemies[0].hp == 100 - plus.effects[0].amount, "it deals its upgraded damage")
	# Cost and keyword upgrades flow through can_play and Ready.
	var base := CardData.make(&"r", "R", 2, _dmg(3))
	base.remembered = RememberedData.make(_dmg(3), 1, PackedStringArray(["ready"]))
	var filler := CardData.make(&"f", "F", 1, _dmg(1))
	var big: Array[CardData] = []
	for n in 12:
		big.append(filler)
	big.append(base.remembered_card())
	var c2 := Combat.new(Combatant.new("p", 40), big, datas, 2)
	c2.start()
	var in_hand := false
	for card in c2.piles.hand:
		if card.is_remembered:
			in_hand = true
	_check(in_hand, "a Remembered card that gained Ready opens the first hand")


func _test_vendor_and_rewards() -> void:
	var state := _at_rest()
	var pick: int = state.rememberable_indices()[0]
	state.remember(pick)
	var plus := state.deck[pick]
	_check(Vendor.card_price(plus) >= Vendor.card_price(plus.base()), "a Remembered copy is never priced below its base")
	# The vendor removes a Remembered copy by position like any other.
	var vendor_state := RunState.new(5, &"thief")
	vendor_state.deck[0] = vendor_state.deck[0].remembered_card() if vendor_state.deck[0].can_remember() else vendor_state.deck[0]
	var vendor := Vendor.new(vendor_state.deck, RandomNumberGenerator.new(), 100)
	var before := vendor_state.deck.size()
	_check(vendor.remove_card(0).ok and vendor_state.deck.size() == before - 1, "the vendor removes a deck card by position, Remembered or not")
	# Reward copy counting is by id, so a Remembered copy counts toward the cap.
	var copies := RunState.new(5, &"thief")
	for n in RunState.COPY_CAP:
		copies.deck.append(_card("shove").remembered_card())
	var capped := 0
	for card in copies.deck:
		if card.id == &"shove":
			capped += 1
	_check(capped >= RunState.COPY_CAP, "Remembered copies keep the shared id")
