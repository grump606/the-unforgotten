extends RefCounted
## Deck cycling (Phase 3a): the EffectContext refactor, Glimpse, Add card, Recall, damage per Forgotten
## card, the CHOOSING step, pile helpers and the status cards. Registered by run_tests.gd. Fixtures are
## built in code; only the status cards come from their .tres files (through the loader).

const K := CardEffect.Kind
const P := CardEffect.Pile

var _failures := 0


func run() -> int:
	_failures = 0
	_test_effect_context()
	_test_glimpse_choice()
	_test_glimpse_sees_only_the_draw_pile()
	_test_choosing_blocks_the_turn()
	_test_recall_choice()
	_test_recall_hand_full_and_forgotten_again()
	_test_add_card_piles()
	_test_add_card_draw_position_is_seeded()
	_test_add_card_through_combat()
	_test_enemy_adds_dread()
	_test_murmur_fades()
	_test_damage_per_forgotten()
	_test_queued_choices_resolve_in_order()
	_test_combat_end_clears_choice()
	_test_null_card_add()
	_test_status_cards_content()
	_test_vendor_values()
	return _failures


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAIL: " + label)


func _fx(kind: CardEffect.Kind, amount: int, card: CardData = null, pile: CardEffect.Pile = P.HAND) -> CardEffect:
	return CardEffect.make(kind, amount, 0, 0, 1, false, false, card, pile)


func _blank(id: String) -> CardData:
	var none: Array[CardEffect] = []
	return CardData.make(StringName(id), id, 0, none, CardData.TargetMode.SELF)


## A free self card with these effects.
func _self_card(id: String, effects: Array[CardEffect]) -> CardData:
	return CardData.make(StringName(id), id, 0, effects, CardData.TargetMode.SELF)


func _ints(list: Array) -> Array[int]:
	var out: Array[int] = []
	for i in list:
		out.append(i)
	return out


## A started fight. A deck of 5 or fewer is dealt whole, so tests then set the piles by hand.
func _fight(deck: Array[CardData], intents: Array[CardEffect] = [], enemy_hp: int = 100, rng_seed: int = 0) -> Combat:
	var datas: Array[EnemyData] = [EnemyData.make("E", enemy_hp, intents)]
	var combat := Combat.new(Combatant.new("p", 100), deck, datas, rng_seed)
	combat.start()
	return combat


func _play(combat: Combat, card: CardData, target: int = 0) -> bool:
	return combat.play_card(combat.piles.hand.find(card), target)


func _ids(cards: Array[CardData]) -> Array:
	var out: Array = []
	for card in cards:
		out.append(String(card.id))
	return out


func _test_effect_context() -> void:
	var ctx := EffectContext.make(7, 4, 3, 5)
	_check(ctx.block == 7 and ctx.haunt == 4 and ctx.plays == 3 and ctx.forgotten == 5, "EffectContext.make fills every field")
	_check(EffectContext.make(1, 2, 3).forgotten == 0, "the Forgotten count defaults to 0")
	_check(CardEffect.make(K.DAMAGE, 6).raw_damage(ctx) == 6, "plain damage ignores the context")
	_check(CardEffect.make(K.DAMAGE_PER_BLOCK, 2).raw_damage(ctx) == 14, "damage per Block reads ctx.block")
	_check(CardEffect.make(K.DAMAGE_IF_BLOCK, 3, 9, 8).raw_damage(ctx) == 3, "conditional damage below the threshold")
	_check(CardEffect.make(K.DAMAGE_IF_BLOCK, 3, 9, 7).raw_damage(ctx) == 9, "conditional damage at the threshold")
	_check(CardEffect.make(K.DAMAGE_PER_PLAY, 2, 3).raw_damage(ctx) == 8, "damage per play reads ctx.plays (2 earlier plays)")
	_check(CardEffect.make(K.DAMAGE_PER_HAUNT, 2).raw_damage(ctx) == 8, "damage per Haunt reads ctx.haunt")
	_check(CardEffect.make(K.DAMAGE_PER_FORGOTTEN, 2).raw_damage(ctx) == 10, "damage per Forgotten reads ctx.forgotten")
	_check(CardEffect.make(K.BLOCK, 5).raw_damage(ctx) == 0, "a non-damage kind has no raw damage")
	_check(CardEffect.make(K.DAMAGE_PER_FORGOTTEN, 2).is_damage(), "damage per Forgotten is a damage kind")
	_check(CardEffect.make(K.DAMAGE_PER_FORGOTTEN, 2).reach() == CardEffect.Reach.ENEMIES, "damage per Forgotten reaches enemies")
	for kind in [K.GLIMPSE, K.ADD_CARD, K.RECALL]:
		_check(CardEffect.make(kind, 1).reach() == CardEffect.Reach.SELF, "kind %d acts on the player's piles" % kind)
	var dread := StarterContent.status_card(&"dread")
	_check(_fx(K.GLIMPSE, 3).describe() == "Glimpse 3", "Glimpse text")
	_check(_fx(K.RECALL, 1).describe() == "Recall 1", "Recall text")
	_check(_fx(K.ADD_CARD, 2, dread, P.HAND).describe() == "Add 2 Dread to your hand", "Add card text, hand")
	_check(_fx(K.ADD_CARD, 1, dread, P.DRAW).describe() == "Add 1 Dread to your draw pile", "Add card text, draw pile")
	_check(_fx(K.ADD_CARD, 1, dread, P.DISCARD).describe() == "Add 1 Dread to your discard pile", "Add card text, discard pile")
	_check(_fx(K.ADD_CARD, 2).describe() == "Add 2 cards to your hand", "Add card text with no card does not crash")
	_check(_fx(K.DAMAGE_PER_FORGOTTEN, 1).describe() == "Deal damage equal to the Forgotten pile", "Forgotten damage text x1")
	_check(_fx(K.DAMAGE_PER_FORGOTTEN, 2).describe() == "Deal 2x the Forgotten pile", "Forgotten damage text x2")
	_check(CardEffect.make(K.ADD_CARD, 1).pile == P.HAND, "a new effect adds to the hand by default")
	_check(Combat.Phase.DISCARDING == 4 and Combat.Phase.CHOOSING == 5, "CHOOSING is appended after the older phases")


func _test_glimpse_choice() -> void:
	var a := _blank("a")
	var b := _blank("b")
	var c := _blank("c")
	var d := _blank("d")
	var glimpse := _self_card("g", [_fx(K.GLIMPSE, 3), _fx(K.BLOCK, 4)])
	var deck: Array[CardData] = [glimpse]

	var combat := _fight(deck)
	combat.piles.draw_pile.append_array([a, b, c, d])
	var seen_in_signal := [true]
	combat.card_played.connect(func(_card: CardData, _targets: Array[EnemyUnit]) -> void: seen_in_signal[0] = combat.has_choice())
	_check(_play(combat, glimpse), "the Glimpse card plays")
	_check(not seen_in_signal[0], "the choice is not open while the card is still resolving")
	_check(combat.phase == Combat.Phase.CHOOSING and combat.has_choice(), "the choice opens after the card")
	_check(combat.player.block == 4, "the card's other effects resolved before the choice")
	_check(combat.choice_kind() == K.GLIMPSE and combat.choice_required() == 0 and combat.choice_max() == 3, "Glimpse 3: pick none to three")
	_check(_ids(combat.choice_cards()) == ["d", "c", "b"], "the cards are shown in draw order (top first)")
	_check(not combat.resolve_choice(_ints([0, 0])), "a duplicate pick is rejected")
	_check(not combat.resolve_choice(_ints([3])), "an out-of-range pick is rejected")
	_check(not combat.resolve_choice(_ints([-1])), "a negative pick is rejected")
	_check(combat.phase == Combat.Phase.CHOOSING and combat.piles.draw_pile.size() == 4, "a rejected pick changes nothing")
	_check(combat.resolve_choice(_ints([])), "discarding none is a legal pick")
	_check(combat.phase == Combat.Phase.PLAYER_TURN and not combat.has_choice(), "resolving returns to the player's turn")
	_check(_ids(combat.piles.draw_pile) == ["a", "b", "c", "d"], "discarding none leaves the draw pile untouched")

	# Some: the cards go to discard in the order picked, the rest stay on top in order.
	var some := _fight(deck)
	some.piles.draw_pile.append_array([a, b, c, d])
	_play(some, glimpse)
	_check(some.resolve_choice(_ints([2, 0])), "discarding two of three")
	_check(_ids(some.piles.discard_pile) == ["g", "b", "d"], "discarded cards land in the order chosen")
	_check(_ids(some.piles.draw_pile) == ["a", "c"], "the kept card stays on top, order intact")

	var all := _fight(deck)
	all.piles.draw_pile.append_array([a, b, c, d])
	_play(all, glimpse)
	_check(all.resolve_choice(_ints([0, 1, 2])), "discarding all three")
	_check(_ids(all.piles.draw_pile) == ["a"] and _ids(all.piles.discard_pile) == ["g", "d", "c", "b"], "all three leave the pile")

	# The deck array handed to the fight is never touched.
	_check(deck.size() == 1 and deck[0] == glimpse, "the deck array is unchanged")

	# auto_resolve_choice discards nothing for Glimpse.
	var auto := _fight(deck)
	auto.piles.draw_pile.append_array([a, b])
	_play(auto, glimpse)
	_check(auto.auto_resolve_choice() and auto.piles.draw_pile.size() == 2 and auto.phase == Combat.Phase.PLAYER_TURN, "auto_resolve_choice keeps every card for Glimpse")
	_check(not auto.auto_resolve_choice(), "auto_resolve_choice with no choice is false")


func _test_glimpse_sees_only_the_draw_pile() -> void:
	var a := _blank("a")
	var x := _blank("x")
	var y := _blank("y")
	var glimpse := _self_card("g", [_fx(K.GLIMPSE, 3)])
	var deck: Array[CardData] = [glimpse]

	var thin := _fight(deck)
	thin.piles.draw_pile.append(a)
	thin.piles.discard_pile.append_array([x, y])
	_play(thin, glimpse)
	_check(_ids(thin.choice_cards()) == ["a"], "with one card in the draw pile Glimpse 3 shows only that card")
	_check(thin.choice_max() == 1, "and allows one pick at most")
	thin.auto_resolve_choice()
	_check(_ids(thin.piles.discard_pile) == ["x", "y", "g"], "the discard pile was not reshuffled")

	var empty := _fight(deck)
	empty.piles.discard_pile.append_array([x, y])
	_play(empty, glimpse)
	_check(not empty.has_choice() and empty.phase == Combat.Phase.PLAYER_TURN, "Glimpse on an empty draw pile opens no choice")
	_check(empty.piles.draw_pile.is_empty() and _ids(empty.piles.discard_pile) == ["x", "y", "g"], "and never reshuffles the discard pile")

	# top_cards looks without moving anything.
	var piles := CardPiles.new([a, x, y], RandomNumberGenerator.new())
	var before := _ids(piles.draw_pile)
	var top := piles.top_cards(2)
	_check(top.size() == 2 and top[0] == piles.draw_pile[2] and top[1] == piles.draw_pile[1], "top_cards lists from the end of the array")
	_check(_ids(piles.draw_pile) == before and piles.discard_pile.is_empty(), "top_cards changes nothing")
	_check(piles.top_cards(10).size() == 3 and piles.top_cards(0).is_empty(), "top_cards is bounded by the pile")


func _test_choosing_blocks_the_turn() -> void:
	var glimpse := _self_card("g", [_fx(K.GLIMPSE, 1)])
	var other := _self_card("o", [_fx(K.BLOCK, 2)])
	var deck: Array[CardData] = [glimpse, other]
	var combat := _fight(deck)
	combat.piles.draw_pile.append(_blank("a"))
	_play(combat, glimpse)
	_check(combat.phase == Combat.Phase.CHOOSING, "setup: choosing")
	_check(not combat.can_play(combat.piles.hand.find(other)), "no card can be played while choosing")
	_check(not combat.play_card(combat.piles.hand.find(other)), "play_card is refused while choosing")
	_check(not combat.end_player_turn(), "the turn cannot end while choosing")
	_check(not combat.begin_discard(), "the discard step cannot begin while choosing")
	_check(not combat.toggle_discard(0), "marking a discard is refused while choosing")
	_check(not combat.confirm_discard(), "confirming a discard is refused while choosing")
	_check(combat.phase == Combat.Phase.CHOOSING and combat.energy == 3, "the refused calls changed nothing")
	combat.resolve_choice(_ints([]))
	_check(combat.can_play(combat.piles.hand.find(other)) and combat.begin_discard(), "after resolving, play and the discard step work again")

	# abandon() clears an open choice.
	var abandoned := _fight(deck)
	abandoned.piles.draw_pile.append(_blank("a"))
	_play(abandoned, glimpse)
	abandoned.abandon()
	_check(abandoned.phase == Combat.Phase.ENDED and not abandoned.has_choice(), "abandon() clears the choice")
	_check(not abandoned.resolve_choice(_ints([])), "nothing resolves after abandon")


func _test_recall_choice() -> void:
	var f1 := _blank("f1")
	var f2 := _blank("f2")
	var f3 := _blank("f3")
	var recall := _self_card("r", [_fx(K.RECALL, 2), _fx(K.BLOCK, 3)])
	var deck: Array[CardData] = [recall]

	var combat := _fight(deck)
	combat.piles.forgotten.append_array([f1, f2, f3])
	_play(combat, recall)
	_check(combat.phase == Combat.Phase.CHOOSING and combat.choice_kind() == K.RECALL, "Recall opens a choice")
	_check(combat.player.block == 3, "the Block resolved first")
	_check(combat.choice_required() == 2 and combat.choice_max() == 2, "Recall 2 needs exactly two picks")
	_check(_ids(combat.choice_cards()) == ["f1", "f2", "f3"], "the whole Forgotten pile is on offer")
	_check(not combat.resolve_choice(_ints([])), "no picks is rejected")
	_check(not combat.resolve_choice(_ints([0])), "too few picks is rejected")
	_check(not combat.resolve_choice(_ints([0, 1, 2])), "too many picks is rejected")
	_check(not combat.resolve_choice(_ints([1, 1])), "a duplicate pick is rejected")
	_check(not combat.can_resolve_choice(_ints([0, 3])), "an out-of-range pick is rejected")
	_check(combat.resolve_choice(_ints([2, 0])), "two valid picks resolve")
	_check(_ids(combat.piles.hand) == ["f3", "f1"], "the picked cards join the hand in the order chosen")
	_check(_ids(combat.piles.forgotten) == ["f2"] and combat.phase == Combat.Phase.PLAYER_TURN, "the rest stay Forgotten and the turn resumes")

	# Fewer Forgotten cards than n: exactly min(n, forgotten) picks.
	var short := _fight(deck)
	short.piles.forgotten.append(f1)
	_play(short, recall)
	_check(short.choice_required() == 1 and short.choice_max() == 1, "Recall 2 with one Forgotten card needs one pick")
	_check(short.resolve_choice(_ints([0])) and short.piles.forgotten.is_empty(), "and takes it")

	# Nothing Forgotten: Recall does nothing, no choice.
	var none := _fight(deck)
	_play(none, recall)
	_check(not none.has_choice() and none.phase == Combat.Phase.PLAYER_TURN, "Recall with an empty Forgotten pile opens no choice")

	# auto_resolve_choice recalls the first required cards.
	var auto := _fight(deck)
	auto.piles.forgotten.append_array([f1, f2, f3])
	_play(auto, recall)
	_check(auto.auto_resolve_choice() and _ids(auto.piles.hand) == ["f1", "f2"], "auto_resolve_choice recalls the first required cards")


func _test_recall_hand_full_and_forgotten_again() -> void:
	var f1 := _blank("f1")
	var f2 := _blank("f2")
	var recall := _self_card("r", [_fx(K.RECALL, 2)])
	var deck: Array[CardData] = [recall]
	var combat := _fight(deck)
	for i in 9:
		combat.piles.hand.append(_blank("h%d" % i))
	combat.piles.forgotten.append_array([f1, f2])
	_play(combat, recall)
	_check(combat.resolve_choice(_ints([0, 1])), "recalling into a nearly full hand")
	_check(combat.piles.hand.size() == Combat.HAND_MAX and combat.piles.hand.back() == f1, "the first card fills the hand to the cap")
	_check(combat.piles.discard_pile.back() == f2 and not combat.piles.forgotten.has(f2), "the overflow card goes to the discard pile")

	# A recalled Forgotten card is Forgotten again when played.
	var spent := _self_card("spent", [_fx(K.BLOCK, 1)])
	spent.forgotten = true
	var again := _fight(deck)
	again.piles.forgotten.append(spent)
	_play(again, recall)
	again.resolve_choice(_ints([0]))
	_check(again.piles.hand.has(spent) and again.piles.forgotten.is_empty(), "setup: the card is back in hand")
	_play(again, spent)
	_check(again.piles.forgotten.has(spent) and not again.piles.discard_pile.has(spent), "played again, it is Forgotten again")

	# The helper directly.
	var piles := CardPiles.new([], RandomNumberGenerator.new())
	piles.forgotten.append_array([f1, f2])
	_check(piles.recall_from_forgotten(_ints([1]), 10) == 1 and piles.hand == [f2] and piles.forgotten == [f1], "recall_from_forgotten moves the picked card")


func _test_add_card_piles() -> void:
	var rng := RandomNumberGenerator.new()
	var base: Array[CardData] = [_blank("a"), _blank("b"), _blank("c")]
	var deck: Array[CardData] = base.duplicate()
	var piles := CardPiles.new(deck, rng)
	var dread := StarterContent.status_card(&"dread")
	_check(piles.add_card(dread, P.HAND, 10) == P.HAND and piles.hand == [dread], "ADD to hand")
	_check(piles.add_card(dread, P.DISCARD, 10) == P.DISCARD and piles.discard_pile == [dread], "ADD to discard")
	_check(piles.add_card(dread, P.DRAW, 10) == P.DRAW and piles.draw_pile.size() == 4 and piles.draw_pile.has(dread), "ADD to draw pile")
	for i in 9:
		piles.hand.append(_blank("h"))
	_check(piles.hand.size() == 10, "setup: the hand is full")
	_check(piles.add_card(dread, P.HAND, 10) == P.DISCARD and piles.hand.size() == 10 and piles.discard_pile.size() == 2, "a full hand sends the card to discard and says so")
	_check(piles.add_card(dread, P.HAND) == P.HAND and piles.hand.size() == 11, "no limit given: the hand takes it")
	_check(piles.add_card(null, P.DRAW) == P.DRAW and piles.draw_pile.size() == 4, "a null card changes nothing")
	_check(deck.size() == 3 and deck == base, "the deck array handed to CardPiles is never modified")


func _test_add_card_draw_position_is_seeded() -> void:
	var marker := _blank("marker")
	var distinct := {}
	for rng_seed in range(1, 11):
		var positions: Array[int] = []
		for _run in 2:
			var rng := RandomNumberGenerator.new()
			rng.seed = rng_seed
			var deck: Array[CardData] = []
			for i in 10:
				deck.append(_blank("d%d" % i))
			var piles := CardPiles.new(deck, rng)
			piles.add_card(marker, P.DRAW)
			positions.append(piles.draw_pile.find(marker))
			_check(piles.draw_pile.size() == 11, "the draw pile grew by one (seed %d)" % rng_seed)
		_check(positions[0] == positions[1] and positions[0] >= 0, "the same seed gives the same position (seed %d)" % rng_seed)
		distinct[positions[0]] = true
	_check(distinct.size() >= 3, "the position varies with the seed (%d distinct of 10 seeds)" % distinct.size())


func _test_add_card_through_combat() -> void:
	var dread := StarterContent.status_card(&"dread")
	var add_hand := _self_card("ah", [_fx(K.ADD_CARD, 2, dread, P.HAND)])
	var add_draw := _self_card("ad", [_fx(K.ADD_CARD, 1, dread, P.DRAW)])
	var add_disc := _self_card("ax", [_fx(K.ADD_CARD, 3, dread, P.DISCARD)])
	var deck: Array[CardData] = [add_hand, add_draw, add_disc]
	var combat := _fight(deck)
	_play(combat, add_hand)
	_check(combat.piles.hand.count(dread) == 2, "a card adds copies to the hand")
	_play(combat, add_draw)
	_check(combat.piles.draw_pile.count(dread) == 1, "a card adds a copy to the draw pile")
	_play(combat, add_disc)
	_check(combat.piles.discard_pile.count(dread) == 3, "a card adds copies to the discard pile")
	_check(deck.size() == 3, "created cards never enter the deck array")
	combat.abandon()

	# Hand full: the copies overflow into discard.
	var fuller := _fight([add_hand])
	for i in 9:
		fuller.piles.hand.append(_blank("h%d" % i))
	_play(fuller, add_hand)
	_check(fuller.piles.hand.size() == Combat.HAND_MAX and fuller.piles.hand.count(dread) == 1 and fuller.piles.discard_pile.count(dread) == 1, "a full hand sends the extra copy to discard")

	# per_energy: a Surge card adds one copy per energy spent.
	var surge := _self_card("sg", [CardEffect.make(K.ADD_CARD, 1, 0, 0, 1, true, false, dread, P.HAND)])
	surge.surge = true
	var surged := _fight([surge])
	_play(surged, surge)
	_check(surged.piles.hand.count(dread) == 3, "a Surge ADD_CARD scales with the energy spent")

	# Two fights with one seed and the same plays put the card in the same place.
	var layouts: Array = []
	for _run in 2:
		var seeded := _fight([add_draw], [], 100, 5)
		for i in 12:
			seeded.piles.draw_pile.append(_blank("b%d" % i))
		_play(seeded, add_draw)
		layouts.append(seeded.piles.draw_pile.find(dread))
	_check(layouts[0] == layouts[1], "a seeded fight places a created draw-pile card deterministically")


func _test_enemy_adds_dread() -> void:
	var dread := StarterContent.status_card(&"dread")
	var intent: Array[CardEffect] = [_fx(K.ADD_CARD, 1, dread, P.DRAW)]
	var deck: Array[CardData] = []
	for i in 6:
		deck.append(_blank("c%d" % i))
	var combat := _fight(deck, intent)
	_check(combat.piles.draw_pile.size() == 1, "setup: one card left in the draw pile")
	# Throw the whole hand away so the new turn draws through the draw pile.
	var all := _ints([0, 1, 2, 3, 4])
	_check(combat.end_player_turn(all), "end the turn discarding the hand")
	_check(combat.piles.hand.has(dread), "the shuffled-in Dread is drawn into the next hand")
	_check(deck.size() == 6 and not deck.has(dread), "the deck array is unchanged")
	var at := combat.piles.hand.find(dread)
	_check(not combat.can_play(at), "a Dread cannot be played")
	_check(combat.play_card(at) == false and combat.piles.hand.has(dread), "play_card refuses it and it stays in hand")
	_check(combat.piles.counted_in_hand() == 5 and combat.can_discard_card(at), "it counts toward the 5 kept and may be discarded")
	_check(combat.begin_discard() and combat.discard_required() == 0, "five counted cards need no discard")
	_check(combat.toggle_discard(at) and combat.discard_marks == [at], "it can be marked for discard")
	combat.cancel_discard()
	combat.piles.hand.append(_blank("extra"))
	_check(combat.discard_required() == 1, "with a sixth counted card one must go (Dread included in the count)")
	combat.begin_discard()
	combat.toggle_discard(at)
	_check(combat.discard_required() == 0 and combat.confirm_discard(), "discarding the Dread satisfies the keep-5 rule")
	_check(combat.piles.discard_pile.has(dread), "the discarded Dread sits in the discard pile for now")
	combat.abandon()


func _test_murmur_fades() -> void:
	var murmur := StarterContent.status_card(&"murmur")
	var deck: Array[CardData] = [_blank("a"), _blank("b")]
	var combat := _fight(deck)
	combat.piles.hand.append(murmur)
	_check(combat.piles.counted_in_hand() == 2, "Murmur does not count toward the 5 kept")
	combat.end_player_turn()
	_check(combat.piles.forgotten.has(murmur) and not combat.piles.hand.has(murmur), "an unspent Murmur is Forgotten at end of turn")
	_check(not combat.piles.discard_pile.has(murmur), "and does not reach the discard pile")
	combat.abandon()

	var again := _fight(deck)
	again.piles.hand.append(murmur)
	_check(not again.can_discard_card(again.piles.hand.find(murmur)), "a Fading card cannot be saved by discarding")

	# An enemy adds a Murmur straight to the hand, where it counts as a 6th card without a cost.
	var intent: Array[CardEffect] = [_fx(K.ADD_CARD, 1, murmur, P.HAND)]
	var full: Array[CardData] = []
	for i in 6:
		full.append(_blank("c%d" % i))
	var fight := _fight(full, intent)
	fight.end_player_turn()
	_check(fight.piles.hand.has(murmur) and fight.piles.counted_in_hand() == 5, "an added Murmur sits in hand beside the 5 kept cards")
	_check(fight.begin_discard() and fight.discard_required() == 0, "it asks for no discard")
	fight.abandon()


func _test_damage_per_forgotten() -> void:
	var spent: Array[CardData] = [_blank("f1"), _blank("f2"), _blank("f3")]
	var hit := CardData.make(&"h", "H", 0, [_fx(K.DAMAGE_PER_FORGOTTEN, 2)])
	var deck: Array[CardData] = [hit]

	var cold := _fight(deck)
	_play(cold, hit)
	_check(cold.enemies[0].hp == 100, "with nothing Forgotten it deals nothing")

	var combat := _fight(deck)
	combat.piles.forgotten.append_array(spent)
	_play(combat, hit)
	_check(combat.enemies[0].hp == 94, "it deals 2 x the Forgotten pile (3 cards)")

	var malice := _fight(deck)
	malice.piles.forgotten.append_array(spent)
	malice.player.apply_status(Combatant.Status.MALICE, 2)
	_play(malice, hit)
	_check(malice.enemies[0].hp == 92, "Malice adds to the hit")

	var shaken := _fight(deck)
	shaken.piles.forgotten.append_array(spent)
	shaken.player.apply_status(Combatant.Status.SHAKEN, 2)
	_play(shaken, hit)
	_check(shaken.enemies[0].hp == 96, "Shaken cuts the hit by a quarter (6 -> 4)")

	var expose := _fight(deck)
	expose.piles.forgotten.append_array(spent)
	expose.enemies[0].apply_status(Combatant.Status.EXPOSED, 2)
	_play(expose, hit)
	_check(expose.enemies[0].hp == 91, "Expose raises the hit by half (6 -> 9)")

	# A Forgotten card played earlier in the same turn counts: the count is read at resolution.
	var burn := _self_card("burn", [_fx(K.BLOCK, 1)])
	burn.forgotten = true
	var chain := _fight([burn, hit])
	_play(chain, burn)
	_play(chain, hit)
	_check(chain.enemies[0].hp == 98, "the card it just Forgot counts toward the pile (2 x 1)")


func _test_queued_choices_resolve_in_order() -> void:
	var a := _blank("a")
	var b := _blank("b")
	var f1 := _blank("f1")
	var both := _self_card("both", [_fx(K.GLIMPSE, 2), _fx(K.RECALL, 1), _fx(K.BLOCK, 5)])
	var combat := _fight([both])
	combat.piles.draw_pile.append_array([a, b])
	combat.piles.forgotten.append(f1)
	_play(combat, both)
	_check(combat.phase == Combat.Phase.CHOOSING and combat.choice_kind() == K.GLIMPSE, "the first queued choice (Glimpse) opens first")
	_check(combat.player.block == 5, "later effects of the card still resolved before any choice")
	_check(combat.resolve_choice(_ints([0])), "resolve the Glimpse (discard the top card)")
	_check(combat.phase == Combat.Phase.CHOOSING and combat.choice_kind() == K.RECALL, "the Recall opens next, still choosing")
	_check(not combat.can_play(0) and not combat.end_player_turn(), "the turn is still blocked")
	_check(combat.resolve_choice(_ints([0])), "resolve the Recall")
	_check(combat.phase == Combat.Phase.PLAYER_TURN and not combat.has_choice(), "after the last choice the turn resumes")
	_check(combat.piles.hand.has(f1) and combat.piles.discard_pile.has(b), "both picks were applied")

	# The second Glimpse sees the pile as the first one left it.
	var twice := _self_card("twice", [_fx(K.GLIMPSE, 1), _fx(K.GLIMPSE, 1)])
	var two := _fight([twice])
	two.piles.draw_pile.append_array([a, b])
	_play(two, twice)
	_check(_ids(two.choice_cards()) == ["b"], "first Glimpse shows the top card")
	two.resolve_choice(_ints([0]))
	_check(two.has_choice() and _ids(two.choice_cards()) == ["a"], "the second Glimpse shows the next card down")


func _test_combat_end_clears_choice() -> void:
	var killer := CardData.make(&"k", "K", 0, [CardEffect.make(K.DAMAGE, 500), _fx(K.GLIMPSE, 2), _fx(K.RECALL, 1)])
	var combat := _fight([killer])
	combat.piles.draw_pile.append(_blank("a"))
	combat.piles.forgotten.append(_blank("f"))
	var ended := [false]
	combat.combat_ended.connect(func(_victory: bool) -> void: ended[0] = true)
	_play(combat, killer)
	_check(ended[0] and combat.phase == Combat.Phase.ENDED, "setup: the card won the fight")
	_check(not combat.has_choice() and combat.choice_cards().is_empty(), "winning clears any queued choice")
	_check(not combat.resolve_choice(_ints([])), "nothing resolves after the fight ends")

	# A lost fight holds no choice either.
	var glimpse := _self_card("g", [_fx(K.GLIMPSE, 1)])
	var lethal: Array[CardEffect] = [CardEffect.make(K.DAMAGE, 500)]
	var doomed := _fight([glimpse], lethal)
	doomed.piles.draw_pile.append(_blank("a"))
	_play(doomed, glimpse)
	doomed.resolve_choice(_ints([]))
	doomed.end_player_turn()
	_check(doomed.phase == Combat.Phase.ENDED and not doomed.has_choice(), "a lost fight holds no choice")


func _test_null_card_add() -> void:
	var broken := _self_card("broken", [_fx(K.ADD_CARD, 2, null, P.HAND), _fx(K.BLOCK, 3)])
	var combat := _fight([broken])
	_check(_play(combat, broken), "a null-card ADD_CARD card still plays")
	_check(combat.piles.hand.is_empty() and combat.player.block == 3, "it adds nothing and the rest of the card resolves")
	var intent: Array[CardEffect] = [_fx(K.ADD_CARD, 1, null, P.DRAW)]
	var enemy_side := _fight([_blank("a")], intent)
	_check(enemy_side.end_player_turn(), "a null-card intent does not crash the enemy phase")


func _test_status_cards_content() -> void:
	var dread := StarterContent.status_card(&"dread")
	var murmur := StarterContent.status_card(&"murmur")
	_check(dread != null and murmur != null, "both status cards load")
	if dread == null or murmur == null:
		return
	_check(dread.id == &"dread" and dread.display_name == "Dread" and dread.cost == 0, "Dread: id, name, cost")
	_check(murmur.id == &"murmur" and murmur.display_name == "Murmur" and murmur.cost == 0, "Murmur: id, name, cost")
	_check(dread.dormant and not dread.fading, "Dread is Dormant")
	_check(murmur.dormant and murmur.fading, "Murmur is Dormant and Fading")
	_check(dread.effects.is_empty() and murmur.effects.is_empty(), "status cards have no effects")
	_check(dread.character == &"" and dread.target_mode == CardData.TargetMode.SELF, "Dread is neutral and SELF-targeted")
	_check(StarterContent.status_card(&"dread") == dread, "the loader returns the same shared resource")

	var registry_ids := {}
	for card in StarterContent.all_cards():
		registry_ids[card.id] = true
		for effect in card.effects:
			_check(effect.card == null or effect.card.dormant, "no data/cards card adds a playable status: %s" % card.id)
	_check(not registry_ids.has(&"dread") and not registry_ids.has(&"murmur"), "status cards are not in the card registry")
	for path in StarterContent.ALL_CARD_PATHS:
		_check(not path.begins_with("res://data/status"), "the registry paths never point into data/status")
	for character in StarterContent.CHARACTER_PATHS.keys():
		for card in StarterContent.reward_pool(character):
			_check(card.id != &"dread" and card.id != &"murmur", "status cards are not in the %s reward pool" % character)
	var golden: Dictionary = load("res://tests/vendor_tests.gd").get_script_constant_map()["GOLDEN"]
	_check(not golden.has("dread") and not golden.has("murmur"), "status cards are not in the card price table")
	for card in StarterContent.deck() + StarterContent.extended_deck():
		_check(not card.dormant, "no starting deck holds a Dormant card")


func _test_vendor_values() -> void:
	var dread := StarterContent.status_card(&"dread")
	_check(Vendor.effect_value(_fx(K.GLIMPSE, 3)) == 3 * Vendor.GLIMPSE_VALUE_PER_CARD, "Glimpse is worth a little per card")
	_check(Vendor.effect_value(_fx(K.RECALL, 2)) == 2 * Vendor.RECALL_VALUE_PER_CARD, "Recall is worth a card each")
	_check(Vendor.effect_value(_fx(K.DAMAGE_PER_FORGOTTEN, 2)) == 2 * Vendor.TYPICAL_FORGOTTEN, "damage per Forgotten assumes a typical pile")
	_check(Vendor.effect_value(_fx(K.ADD_CARD, 2, dread)) < 0, "adding a Dormant card is a cost, so negative")
	var strike := CardData.make(&"s", "S", 1, [CardEffect.make(K.DAMAGE, 6)])
	_check(Vendor.effect_value(_fx(K.ADD_CARD, 1, strike)) == Vendor.card_value(strike), "adding a good card is worth that card")
	_check(Vendor.effect_value(_fx(K.ADD_CARD, 1)) == 0, "an ADD_CARD with no card is worth nothing")
