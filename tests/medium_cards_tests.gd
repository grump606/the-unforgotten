extends RefCounted
## Phase 4d: the Medium's Forgotten-pile cards. Seance and Bleed the Veil became Forgotten; Remember,
## Chorus of the Lost and Hollow Bargain are new. Registered by run_tests.gd. Fixtures are built in
## code; the cards under test come from their shipped .tres files.

var _failures := 0


func run() -> int:
	_failures = 0
	_test_pool_and_text()
	_test_retuned_cards_go_forgotten()
	_test_remember()
	_test_chorus_of_the_lost()
	_test_hollow_bargain()
	_test_synergy()
	return _failures


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAIL: " + label)


func _card(path: String) -> CardData:
	return load(path) as CardData


func _blank(id: String, forgotten: bool = false) -> CardData:
	var none: Array[CardEffect] = []
	var card := CardData.make(StringName(id), id, 0, none, CardData.TargetMode.SELF)
	card.forgotten = forgotten
	return card


func _ints(list: Array) -> Array[int]:
	var out: Array[int] = []
	for i in list:
		out.append(i)
	return out


func _ids(cards: Array[CardData]) -> Array:
	var out: Array = []
	for card in cards:
		out.append(String(card.id))
	return out


## A started fight against one dummy enemy. A deck of 5 or fewer is dealt whole.
func _fight(deck: Array[CardData], rng_seed: int = 0, enemy_hp: int = 100) -> Combat:
	var datas: Array[EnemyData] = [EnemyData.make("E", enemy_hp, [] as Array[CardEffect])]
	var combat := Combat.new(Combatant.new("p", 40), deck, datas, rng_seed)
	combat.start()
	return combat


func _play(combat: Combat, card: CardData, target: int = 0) -> bool:
	return combat.play_card(combat.piles.hand.find(card), target)


func _test_pool_and_text() -> void:
	var remember := _card(StarterContent.REMEMBER_PATH)
	var chorus := _card(StarterContent.CHORUS_OF_THE_LOST_PATH)
	var bargain := _card(StarterContent.HOLLOW_BARGAIN_PATH)
	var fresh := [remember, chorus, bargain]
	var medium_ids: Array = []
	for card in StarterContent.reward_pool(&"medium"):
		medium_ids.append(String(card.id))
	for card: CardData in fresh:
		_check(card.character == &"medium", "%s is tagged medium" % card.id)
		_check(medium_ids.has(String(card.id)), "%s is in the medium reward pool" % card.id)
		for other in [&"deserter", &"thief"]:
			var leaked := false
			for pooled in StarterContent.reward_pool(other):
				leaked = leaked or pooled.id == card.id
			_check(not leaked, "%s is not in the %s reward pool" % [card.id, other])

	_check(remember.cost == 1 and remember.target_mode == CardData.TargetMode.SELF and remember.describe() == "Recall 1", "Remember: cost 1, self, Recall 1")
	_check(chorus.cost == 1 and chorus.target_mode == CardData.TargetMode.SINGLE_ENEMY and chorus.describe() == "Deal 2x the Forgotten pile", "Chorus of the Lost: cost 1, single enemy, damage 2x the Forgotten pile")
	_check(bargain.cost == 0 and bargain.target_mode == CardData.TargetMode.SELF and bargain.describe() == "Add 1 Dread to your draw pile, Draw 2", "Hollow Bargain: cost 0, self, adds a Dread then draws 2")
	_check(not remember.forgotten and not chorus.forgotten and not bargain.forgotten, "the new cards are not Forgotten themselves")


func _test_retuned_cards_go_forgotten() -> void:
	var seance := _card(StarterContent.SEANCE_PATH)
	var bleed := _card(StarterContent.BLEED_THE_VEIL_PATH)
	_check(seance.forgotten and seance.cost == 1 and seance.hp_cost() == 3, "Seance is Forgotten, cost 1, Lose 3 HP")
	_check(bleed.forgotten and bleed.cost == 2 and bleed.hp_cost() == 6, "Bleed the Veil is Forgotten, cost 2, Lose 6 HP")
	_check(seance.character == &"medium" and bleed.character == &"medium", "both stay Medium cards")

	for card: CardData in [seance, bleed]:
		var deck: Array[CardData] = [card]
		var combat := _fight(deck)
		_check(_play(combat, card), "%s plays" % card.id)
		_check(combat.piles.forgotten == [card] and not combat.piles.discard_pile.has(card), "%s goes to the Forgotten pile, not the discard pile" % card.id)
		# The next fight starts from the deck array again, which still holds the card.
		_check(deck.size() == 1 and deck[0] == card, "%s is still in the deck array" % card.id)
		var next := _fight(deck)
		_check(next.piles.hand.has(card) and next.piles.forgotten.is_empty(), "%s is back in the next fight's opening hand" % card.id)


func _test_remember() -> void:
	var remember := _card(StarterContent.REMEMBER_PATH)
	var seance := _card(StarterContent.SEANCE_PATH)
	var other := _blank("other", true)
	var deck: Array[CardData] = [remember]

	var combat := _fight(deck)
	combat.piles.forgotten.append_array([other, seance])
	_check(_play(combat, remember), "Remember plays")
	_check(combat.phase == Combat.Phase.CHOOSING and combat.choice_kind() == CardEffect.Kind.RECALL, "Remember opens a Recall choice after resolving")
	_check(combat.choice_required() == 1 and combat.choice_max() == 1, "the choice is for exactly one card")
	_check(_ids(combat.choice_cards()) == ["other", "seance"], "the whole Forgotten pile is on offer")
	_check(combat.piles.discard_pile.has(remember), "Remember itself is spent (discarded) as normal")
	_check(combat.resolve_choice(_ints([1])), "pick Seance")
	_check(combat.piles.hand == [seance] and combat.piles.forgotten == [other], "the picked card returns to hand, the other stays Forgotten")
	_check(combat.phase == Combat.Phase.PLAYER_TURN, "the turn resumes")

	var empty := _fight(deck)
	_check(_play(empty, remember), "Remember plays with nothing Forgotten")
	_check(not empty.has_choice() and empty.phase == Combat.Phase.PLAYER_TURN, "and opens no choice")
	_check(empty.piles.hand.is_empty(), "and returns nothing")


func _test_chorus_of_the_lost() -> void:
	var chorus := _card(StarterContent.CHORUS_OF_THE_LOST_PATH)
	var deck: Array[CardData] = [chorus]
	var spent: Array[CardData] = [_blank("a"), _blank("b"), _blank("c")]

	var none := _fight(deck)
	_play(none, chorus)
	_check(none.enemies[0].hp == 100, "an empty Forgotten pile deals nothing")

	# Grows with the pile: 2 x size.
	for size in [1, 2, 3]:
		var combat := _fight(deck)
		combat.piles.forgotten.append_array(spent.slice(0, size))
		_play(combat, chorus)
		_check(combat.enemies[0].hp == 100 - 2 * size, "Forgotten pile of %d deals %d" % [size, 2 * size])

	var malice := _fight(deck)
	malice.piles.forgotten.append_array(spent.slice(0, 2))
	malice.player.apply_status(Combatant.Status.MALICE, 2)
	_play(malice, chorus)
	_check(malice.enemies[0].hp == 94, "Malice adds to the hit (4 + 2)")

	var shaken := _fight(deck)
	shaken.piles.forgotten.append_array(spent.slice(0, 2))
	shaken.player.apply_status(Combatant.Status.SHAKEN, 2)
	_play(shaken, chorus)
	_check(shaken.enemies[0].hp == 97, "Shaken cuts the hit by a quarter (4 -> 3)")

	var expose := _fight(deck)
	expose.piles.forgotten.append_array(spent.slice(0, 2))
	expose.enemies[0].apply_status(Combatant.Status.EXPOSED, 2)
	_play(expose, chorus)
	_check(expose.enemies[0].hp == 94, "Expose raises the hit by half (4 -> 6)")

	var blocked := _fight(deck)
	blocked.piles.forgotten.append_array(spent)
	blocked.enemies[0].gain_block(4)
	_play(blocked, chorus)
	_check(blocked.enemies[0].block == 0 and blocked.enemies[0].hp == 98, "enemy Block absorbs the hit first (6 - 4 = 2 through)")


func _test_hollow_bargain() -> void:
	var bargain := _card(StarterContent.HOLLOW_BARGAIN_PATH)
	var deck: Array[CardData] = [bargain]
	for i in 11:
		deck.append(_blank("f%d" % i))
	var dread := StarterContent.status_card(&"dread")

	var drawn_at_once := 0
	var buried := 0
	for rng_seed in 40:
		var combat := _fight(deck, rng_seed)
		if not combat.piles.hand.has(bargain):
			continue
		var hand_before := combat.piles.hand.size()
		var draw_before := combat.piles.draw_pile.size()
		_play(combat, bargain)
		var in_hand := combat.piles.hand.has(dread)
		var in_draw := combat.piles.draw_pile.has(dread)
		_check(in_hand != in_draw, "seed %d: the Dread is in exactly one of hand and draw pile" % rng_seed)
		_check(combat.piles.hand.size() == hand_before - 1 + 2, "seed %d: drew 2 cards" % rng_seed)
		_check(combat.piles.draw_pile.size() == draw_before + 1 - 2,"seed %d: the draw pile gained the Dread and lost two cards" % rng_seed)
		_check(combat.energy == Combat.ENERGY_PER_TURN, "seed %d: it costs nothing" % rng_seed)
		_check(deck.size() == 12 and not deck.has(dread), "seed %d: the deck array is unchanged" % rng_seed)
		if in_hand:
			drawn_at_once += 1
		else:
			buried += 1
		# Same seed, same placement.
		var again := _fight(deck, rng_seed)
		_play(again, bargain)
		_check(_ids(again.piles.draw_pile) == _ids(combat.piles.draw_pile), "seed %d: the Dread lands in the same place every time" % rng_seed)
	_check(drawn_at_once > 0 and buried > 0, "the Dread's position varies with the seed (sometimes drawn at once, sometimes buried)")

	# A drawn Dread is Dormant: unplayable, counted toward the 5 kept, discardable.
	var held: Combat = null
	for rng_seed in 200:
		var candidate := _fight(deck, rng_seed)
		if not candidate.piles.hand.has(bargain):
			continue
		_play(candidate, bargain)
		if candidate.piles.hand.has(dread):
			held = candidate
			break
	_check(held != null, "setup: found a seed where the Dread is drawn")
	if held != null:
		var at := held.piles.hand.find(dread)
		_check(not held.can_play(at) and not held.play_card(at) and held.piles.hand.has(dread), "the drawn Dread cannot be played")
		var counted_other := 0
		for card in held.piles.hand:
			if not card.dormant:
				counted_other += 1
		_check(held.piles.counted_in_hand() == counted_other + 1, "it counts toward the 5 kept")
		_check(held.can_discard_card(at), "and it can be discarded")


func _test_synergy() -> void:
	var seance := _card(StarterContent.SEANCE_PATH)
	var remember := _card(StarterContent.REMEMBER_PATH)
	var chorus := _card(StarterContent.CHORUS_OF_THE_LOST_PATH)
	var echo := _blank("echo", true)
	var deck: Array[CardData] = [seance, remember, chorus, echo]
	var combat := _fight(deck)
	for i in 8:
		combat.piles.draw_pile.append(_blank("pad%d" % i))

	_play(combat, seance)
	_check(combat.piles.forgotten == [seance] and combat.player.hp == 37, "Seance is Forgotten and costs 3 HP")
	_play(combat, remember)
	_check(combat.has_choice() and combat.choice_cards() == [seance], "Remember offers the Forgotten Seance")
	combat.resolve_choice(_ints([0]))
	_check(combat.piles.hand.has(seance) and combat.piles.forgotten.is_empty(), "Seance is recalled to hand")
	_play(combat, seance)
	_check(combat.piles.forgotten == [seance] and combat.player.hp == 34, "played again, Seance is Forgotten again (and costs another 3 HP)")
	_play(combat, echo)
	_check(combat.piles.forgotten.size() == 2, "two cards are Forgotten")
	_play(combat, chorus)
	_check(combat.enemies[0].hp == 96, "Chorus of the Lost after two Forgotten cards deals 4")
	_check(combat.energy == 1, "energy: Seance and Seance are free (gain 1), Remember and Chorus cost 1 each")
	combat.abandon()
