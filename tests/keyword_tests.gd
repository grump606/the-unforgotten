extends "res://tests/test_base.gd"
## Keyword rules: Forgotten, Fading, Ready, Anchor, Dormant, Surge and multi-hit.
## Fixtures build CardData in code. Discovered by run_tests.gd.


func run() -> int:
	_failures = 0
	_test_keyword_lines_and_describe()
	_test_forgotten_goes_to_forgotten_pile()
	_test_forgotten_returns_next_fight()
	_test_fading_not_counted_or_markable()
	_test_fading_forgotten_at_end_of_turn()
	_test_fading_with_full_kept_hand_needs_no_discard()
	_test_fading_played_is_not_forgotten_twice()
	_test_anchor_not_counted_or_markable()
	_test_anchor_stays_and_refill_math()
	_test_anchor_respects_hand_max()
	_test_ready_counts()
	_test_ready_only_on_turn_one()
	_test_dormant_unplayable()
	_test_surge_energy()
	_test_surge_scales_hits_and_block()
	_test_surge_other_kinds_and_non_surge_ignores_scale()
	_test_multi_hit_block_and_expose()
	_test_multi_hit_defaults()
	_test_enemy_multi_hit_barbs()
	_test_dead_attacker_stops_hitting()
	return _failures


func _dmg(amount: int, hits: int = 1, per_energy: bool = false) -> CardEffect:
	return CardEffect.make(CardEffect.Kind.DAMAGE, amount, 0, 0, hits, per_energy)


func _card(id: String, cost: int, effects: Array[CardEffect], mode: CardData.TargetMode = CardData.TargetMode.SINGLE_ENEMY) -> CardData:
	return CardData.make(StringName(id), id, cost, effects, mode)


## A plain card: cost 1, 1 damage.
func _plain(id: String) -> CardData:
	return _card(id, 1, [_dmg(1)] as Array[CardEffect])


func _plains(count: int, prefix: String = "p") -> Array[CardData]:
	var out: Array[CardData] = []
	for i in count:
		out.append(_plain("%s%d" % [prefix, i]))
	return out


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


func _ints(values: Array) -> Array[int]:
	var out: Array[int] = []
	out.assign(values)
	return out


func _test_keyword_lines_and_describe() -> void:
	var plain := _plain("a")
	_check(plain.keyword_lines().is_empty(), "a plain card has no keyword lines")
	_check(plain.describe() == "Deal 1", "describe is unchanged for a plain card")
	var all := _plain("b")
	all.surge = true
	all.dormant = true
	all.anchor = true
	all.ready = true
	all.fading = true
	all.forgotten = true
	_check(all.keyword_lines() == PackedStringArray(["Forgotten", "Fading", "Ready", "Anchor", "Dormant", "Surge"]), "keyword lines come in a fixed order")
	_check(_dmg(3, 2).describe() == "Deal 3 x2", "multi-hit damage describes as 'Deal 3 x2'")
	_check(_dmg(3).describe() == "Deal 3", "a single hit has no suffix")
	_check(_dmg(3, 1, true).describe() == "Deal 3 x energy spent", "per_energy damage describes its scaling")
	_check(CardEffect.make(CardEffect.Kind.BLOCK, 4, 0, 0, 1, true).describe() == "Block 4 per energy spent", "per_energy block describes its scaling")


func _test_forgotten_goes_to_forgotten_pile() -> void:
	var gone := _plain("gone")
	gone.forgotten = true
	var keep := _plain("keep")
	var combat := _fight([gone, keep])
	var deck_before: Array[CardData] = [gone, keep]
	_check(combat.play_card(0), "a Forgotten card plays")
	_check(combat.piles.forgotten == ([gone] as Array[CardData]), "a played Forgotten card goes to the Forgotten pile")
	_check(combat.piles.discard_pile.is_empty(), "a Forgotten card skips the discard pile")
	_check(combat.play_card(0), "a plain card plays")
	_check(combat.piles.discard_pile == ([keep] as Array[CardData]), "a plain card still goes to discard")
	_check(deck_before == ([gone, keep] as Array[CardData]), "the deck array is not modified")


func _test_forgotten_returns_next_fight() -> void:
	var gone := _plain("gone")
	gone.forgotten = true
	var deck: Array[CardData] = [gone]
	var enemies: Array[EnemyData] = [EnemyData.make("E", 500, [] as Array[CardEffect])]
	var first := Combat.new(Combatant.new("p", 50), deck, enemies, 1)
	first.start()
	first.play_card(0)
	_check(first.piles.forgotten.size() == 1 and deck.size() == 1, "the deck keeps the Forgotten card")
	var second := Combat.new(Combatant.new("p", 50), deck, enemies, 1)
	second.start()
	_check(second.piles.hand.size() == 1 and second.piles.hand[0] == gone and second.piles.forgotten.is_empty(), "the next fight starts with the card back")


func _fading(id: String) -> CardData:
	var card := _plain(id)
	card.fading = true
	return card


func _anchored(id: String) -> CardData:
	var card := _plain(id)
	card.anchor = true
	return card


func _test_fading_not_counted_or_markable() -> void:
	# 5 plain + 2 Fading: only the 5 count, so nothing has to be discarded.
	var hand := _plains(5)
	hand.append(_fading("f0"))
	hand.append(_fading("f1"))
	var combat := _fight(hand)
	combat.begin_discard()
	_check(combat.discard_required() == 0, "Fading cards do not count toward the 5 kept")
	_check(not combat.toggle_discard(5), "a Fading card cannot be marked for discard")
	_check(combat.discard_marks.is_empty(), "a rejected mark leaves no mark")
	_check(not combat.is_valid_discard(_ints([5])), "a discard list with a Fading card is invalid")
	_check(combat.toggle_discard(0) and combat.discard_marks == _ints([0]), "plain cards can still be marked")
	# 6 plain + 1 Fading: one discard needed.
	var hand2 := _plains(6)
	hand2.append(_fading("f"))
	var combat2 := _fight(hand2)
	combat2.begin_discard()
	_check(combat2.discard_required() == 1, "6 counted cards need 1 discard even with a Fading card")


func _test_fading_forgotten_at_end_of_turn() -> void:
	var fade := _fading("fade")
	var hand := _plains(3)
	hand.append(fade)
	var combat := _fight(hand, _plains(5, "d"))
	_check(combat.end_player_turn(), "the turn ends")
	_check(combat.piles.forgotten == ([fade] as Array[CardData]), "an unplayed Fading card is forgotten at end of turn")
	_check(not combat.piles.hand.has(fade) and not combat.piles.discard_pile.has(fade), "it is neither in hand nor discard")
	_check(combat.piles.counted_in_hand() == Combat.HAND_SIZE, "the refill brings the counted hand back to 5")


func _test_fading_with_full_kept_hand_needs_no_discard() -> void:
	var hand := _plains(5)
	hand.append(_fading("f"))
	var combat := _fight(hand, _plains(5, "d"))
	_check(combat.is_valid_discard(_ints([])), "5 kept plus a Fading card needs no discard")
	_check(combat.end_player_turn(), "end_player_turn with no argument is valid")
	_check(combat.piles.forgotten.size() == 1, "the Fading card was forgotten")
	_check(combat.piles.hand.size() == 5, "the 5 kept cards stay and nothing more is drawn")


func _test_fading_played_is_not_forgotten_twice() -> void:
	var fade := _fading("fade")
	var combat := _fight([fade], _plains(5, "d"))
	combat.play_card(0)
	_check(combat.piles.discard_pile == ([fade] as Array[CardData]) and combat.piles.forgotten.is_empty(), "a played Fading card goes to discard, not Forgotten")
	combat.end_player_turn()
	_check(combat.piles.forgotten.is_empty(), "nothing is forgotten at end of turn when the Fading card was played")


func _test_anchor_not_counted_or_markable() -> void:
	var hand := _plains(5)
	hand.append(_anchored("a0"))
	hand.append(_anchored("a1"))
	var combat := _fight(hand)
	combat.begin_discard()
	_check(combat.discard_required() == 0, "Anchored cards do not count toward the 5 kept")
	_check(not combat.toggle_discard(5) and not combat.toggle_discard(6), "Anchored cards cannot be marked")
	_check(not combat.is_valid_discard(_ints([6])), "a discard list with an Anchored card is invalid")
	_check(combat.can_confirm_discard(), "the discard can be confirmed with 5 counted cards")


func _test_anchor_stays_and_refill_math() -> void:
	var anchor := _anchored("a")
	var hand := _plains(3)
	hand.append(anchor)
	var combat := _fight(hand, _plains(10, "d"))
	_check(combat.end_player_turn(), "the turn ends keeping 3 plain cards and an Anchor")
	_check(combat.piles.hand.has(anchor), "the Anchored card stays in hand across turns")
	_check(combat.piles.counted_in_hand() == 5, "the refill draws up to 5 non-Anchored cards")
	_check(combat.piles.hand.size() == 6, "the Anchored card sits on top of the 5")
	# Discard everything discardable: the Anchored card still stays.
	combat.begin_discard()
	for i in combat.piles.hand.size():
		combat.toggle_discard(i)
	_check(combat.discard_marks.size() == 5 and combat.confirm_discard(), "all 5 discardable cards can be discarded")
	_check(combat.piles.hand.has(anchor), "the Anchored card survives a full discard")
	_check(combat.piles.counted_in_hand() == 5, "and the next turn refills 5 again")


func _test_anchor_respects_hand_max() -> void:
	var hand: Array[CardData] = []
	for i in 6:
		hand.append(_anchored("a%d" % i))
	hand.append_array(_plains(4))
	var combat := _fight(hand, _plains(10, "d"))
	combat.end_player_turn()
	_check(combat.piles.hand.size() == Combat.HAND_MAX, "the refill stops at the hand cap with many Anchored cards")


func _ready_card(id: String) -> CardData:
	var card := _plain(id)
	card.ready = true
	return card


func _start(deck: Array[CardData]) -> Combat:
	var enemies: Array[EnemyData] = [EnemyData.make("E", 500, [] as Array[CardEffect])]
	var combat := Combat.new(Combatant.new("p", 500), deck, enemies, 3)
	combat.start()
	return combat


func _ready_in_hand(combat: Combat) -> int:
	var n := 0
	for card in combat.piles.hand:
		if card.ready:
			n += 1
	return n


func _test_ready_counts() -> void:
	var none := _start(_plains(12))
	_check(none.piles.hand.size() == 5, "no Ready cards: a normal opening hand")
	var deck1 := _plains(12)
	deck1.append(_ready_card("r0"))
	var one := _start(deck1)
	_check(_ready_in_hand(one) == 1 and one.piles.hand.size() == 5, "1 Ready card is in the opening hand, which is still 5")
	var deck3 := _plains(12)
	for i in 3:
		deck3.append(_ready_card("r%d" % i))
	var three := _start(deck3)
	_check(_ready_in_hand(three) == 3 and three.piles.hand.size() == 5, "3 Ready cards use 3 of the 5 slots")
	var deck7 := _plains(12)
	for i in 7:
		deck7.append(_ready_card("r%d" % i))
	var seven := _start(deck7)
	_check(_ready_in_hand(seven) == 7 and seven.piles.hand.size() == 7, "7 Ready cards give a 7-card opening hand (no refill)")
	var deck12 := _plains(5)
	for i in 12:
		deck12.append(_ready_card("r%d" % i))
	var twelve := _start(deck12)
	_check(twelve.piles.hand.size() == Combat.HAND_MAX and _ready_in_hand(twelve) == Combat.HAND_MAX, "Ready cards stop at the hand cap of 10")
	_check(twelve.piles.draw_pile.size() == deck12.size() - Combat.HAND_MAX, "the rest stay in the draw pile")


func _test_ready_only_on_turn_one() -> void:
	var extra := _ready_card("extra")
	var draw: Array[CardData] = [extra]
	draw.append_array(_plains(8, "x"))
	var combat := _fight(_plains(5), draw)
	_check(combat.end_player_turn(_ints([0, 1, 2])), "the turn ends")
	_check(combat.turn == 2, "turn 2 began")
	# The draw pile pops from the back, so `extra` stays buried unless Ready pulled it.
	_check(not combat.piles.hand.has(extra), "Ready does not pull cards on later turns")
	_check(combat.piles.hand.size() == 5, "turn 2 refills normally")


func _test_dormant_unplayable() -> void:
	var dead := _plain("dead")
	dead.dormant = true
	var combat := _fight([dead, _plain("ok")])
	_check(not combat.can_play(0), "a Dormant card cannot be played")
	_check(not combat.play_card(0), "play_card rejects a Dormant card")
	_check(combat.piles.hand.size() == 2 and combat.energy == Combat.ENERGY_PER_TURN, "a rejected play changes nothing")
	_check(combat.can_play(1), "other cards are unaffected")
	# It takes hand space and is discarded normally.
	combat.begin_discard()
	_check(combat.discard_required() == 0 and combat.toggle_discard(0), "a Dormant card can be marked for discard")
	combat.piles.draw_pile.append_array(_plains(6, "d"))
	_check(combat.confirm_discard() and combat.piles.discard_pile.has(dead), "a Dormant card is discarded normally")


func _surge_card(effects: Array[CardEffect]) -> CardData:
	var card := _card("surge", 0, effects)
	card.surge = true
	return card


func _test_surge_energy() -> void:
	var attack: Array[CardEffect] = [_dmg(2, 1, true)]
	for spend in [0, 1, 3]:
		var combat := _fight([_surge_card(attack)])
		combat.energy = spend
		_check(combat.can_play(0), "a Surge card is playable at %d energy" % spend)
		_check(combat.play_card(0), "a Surge card plays at %d energy" % spend)
		_check(combat.energy == 0, "a Surge card spends all energy (from %d)" % spend)
		_check(combat.enemies[0].hp == 500 - 2 * spend, "Surge damage scales with the %d energy spent" % spend)
	# Energy gained mid-turn counts.
	var combat2 := _fight([_surge_card(attack)])
	combat2.energy = 5
	combat2.play_card(0)
	_check(combat2.enemies[0].hp == 490, "energy above the per-turn amount is spent too")


func _test_surge_scales_hits_and_block() -> void:
	var block: Array[CardEffect] = [CardEffect.make(CardEffect.Kind.BLOCK, 4, 0, 0, 1, true)]
	var card := _surge_card(block)
	card.target_mode = CardData.TargetMode.SELF
	var combat := _fight([card])
	combat.play_card(0)
	_check(combat.player.block == 12, "Surge block scales: 4 x 3 energy")
	# Multi-hit and per_energy together multiply: 2 hits x 3 energy = 6 hits.
	var both: Array[CardEffect] = [_dmg(1, 2, true)]
	var combat2 := _fight([_surge_card(both)])
	combat2.play_card(0)
	_check(combat2.enemies[0].hp == 500 - 6, "hits and per_energy multiply (2 x 3 hits)")
	# Block absorbs across the scaled hits.
	var combat3 := _fight([_surge_card([_dmg(3, 1, true)] as Array[CardEffect])], [], [] as Array[CardEffect], 100)
	combat3.enemies[0].gain_block(4)
	combat3.play_card(0)
	_check(combat3.enemies[0].hp == 100 - 5 and combat3.enemies[0].block == 0, "3 hits of 3 against 4 Block leaves 5 damage")


func _test_surge_other_kinds_and_non_surge_ignores_scale() -> void:
	var draw: Array[CardEffect] = [CardEffect.make(CardEffect.Kind.DRAW, 1, 0, 0, 1, true)]
	var card := _surge_card(draw)
	card.target_mode = CardData.TargetMode.SELF
	var combat := _fight([card], _plains(6, "d"))
	combat.play_card(0)
	_check(combat.piles.hand.size() == 3, "Surge draw scales with energy spent")
	var haunt: Array[CardEffect] = [CardEffect.make(CardEffect.Kind.HAUNT, 2, 0, 0, 1, true)]
	var combat2 := _fight([_surge_card(haunt)])
	combat2.energy = 2
	combat2.play_card(0)
	_check(combat2.enemies[0].status_turns(Combatant.Status.HAUNTED) == 4, "Surge haunt scales with energy spent")
	var expose: Array[CardEffect] = [CardEffect.make(CardEffect.Kind.EXPOSE, 1, 0, 0, 1, true)]
	var combat3 := _fight([_surge_card(expose)])
	combat3.play_card(0)
	_check(combat3.enemies[0].status_turns(Combatant.Status.EXPOSED) == 3, "Surge expose scales with energy spent")
	# A non-Surge card with per_energy is not scaled and pays its normal cost.
	var plain := _card("plain", 1, [_dmg(2, 1, true)] as Array[CardEffect])
	var combat4 := _fight([plain])
	combat4.play_card(0)
	_check(combat4.enemies[0].hp == 498 and combat4.energy == 2, "per_energy without Surge does not scale")


func _test_multi_hit_block_and_expose() -> void:
	# 3 x2 against 4 Block: 3 absorbed, then 1 absorbed + 2 through.
	var combat := _fight([_card("hit", 1, [_dmg(3, 2)] as Array[CardEffect])], [], [] as Array[CardEffect], 100)
	combat.enemies[0].gain_block(4)
	combat.play_card(0)
	_check(combat.enemies[0].hp == 98 and combat.enemies[0].block == 0, "3 x2 vs 4 Block: 2 gets through")
	# With Expose (x1.5 rounded down) per hit: 3 -> 4, so 4 x2 vs 4 Block leaves 4.
	var combat2 := _fight([_card("hit", 1, [_dmg(3, 2)] as Array[CardEffect])], [], [] as Array[CardEffect], 100)
	combat2.enemies[0].apply_status(Combatant.Status.EXPOSED, 2)
	combat2.enemies[0].gain_block(4)
	combat2.play_card(0)
	_check(combat2.enemies[0].hp == 96, "Expose applies per hit: 4 + 4 vs 4 Block")
	# Rounding is per hit: 1 x3 Exposed is 1 per hit (floor 1.5), not 4 total.
	var combat3 := _fight([_card("hit", 1, [_dmg(1, 3)] as Array[CardEffect])], [], [] as Array[CardEffect], 100)
	combat3.enemies[0].apply_status(Combatant.Status.EXPOSED, 2)
	combat3.play_card(0)
	_check(combat3.enemies[0].hp == 97, "Expose rounds each hit separately")
	# ALL_ENEMIES: each target takes every hit.
	var enemies: Array[EnemyData] = [EnemyData.make("A", 50, [] as Array[CardEffect]), EnemyData.make("B", 50, [] as Array[CardEffect])]
	var sweep := _card("sweep", 1, [_dmg(2, 3)] as Array[CardEffect], CardData.TargetMode.ALL_ENEMIES)
	var combat4 := Combat.new(Combatant.new("p", 50), [sweep] as Array[CardData], enemies, 1)
	combat4.start()
	combat4.play_card(0)
	_check(combat4.enemies[0].hp == 44 and combat4.enemies[1].hp == 44, "each enemy takes all hits of an all-enemies card")


func _test_multi_hit_defaults() -> void:
	var zero := _card("zero", 1, [_dmg(3, 0)] as Array[CardEffect])
	var combat := _fight([zero])
	combat.play_card(0)
	_check(combat.enemies[0].hp == 497, "hits of 0 count as 1")
	var neg := _card("neg", 1, [_dmg(3, -4)] as Array[CardEffect])
	var combat2 := _fight([neg])
	combat2.play_card(0)
	_check(combat2.enemies[0].hp == 497, "negative hits count as 1")
	_check(CardEffect.make(CardEffect.Kind.DAMAGE, 3).hits == 1 and not CardEffect.make(CardEffect.Kind.DAMAGE, 3).per_energy, "make defaults to a single hit")


func _test_enemy_multi_hit_barbs() -> void:
	# The enemy hits twice for 3; the player has 4 Block and 2 Barbs.
	var intents: Array[CardEffect] = [_dmg(3, 2)]
	var barbs := _card("barbs", 1, [CardEffect.make(CardEffect.Kind.THORNS, 2), CardEffect.make(CardEffect.Kind.BLOCK, 4)] as Array[CardEffect], CardData.TargetMode.SELF)
	var combat := _fight([barbs], [], intents, 100, 50)
	combat.play_card(0)
	combat.end_player_turn()
	_check(combat.enemies[0].hp == 96, "Barbs trigger once per enemy hit (2 x 2 damage)")
	_check(combat.player.hp == 50 - 2, "Block absorbs across the enemy's hits (6 damage vs 4 Block)")
	# Without Block, the player takes both hits.
	var combat2 := _fight([_plain("x")], [], intents, 100, 50)
	combat2.end_player_turn()
	_check(combat2.player.hp == 44, "an unblocked 3 x2 enemy attack deals 6")


## Thorns that kill a multi-hit attacker part-way must stop its remaining hits (they used to land and could kill
## the player after the enemy was already dead).
func _test_dead_attacker_stops_hitting() -> void:
	var intents: Array[CardEffect] = [_dmg(4, 3)]
	var barbs := _card("barbs", 1, [CardEffect.make(CardEffect.Kind.THORNS, 5)] as Array[CardEffect], CardData.TargetMode.SELF)
	var combat := _fight([barbs], [], intents, 3, 10)
	combat.play_card(0)
	combat.end_player_turn()
	_check(combat.enemies[0].is_dead(), "Thorns kill the 3 HP attacker on its first hit")
	_check(combat.player.hp == 6, "the dead attacker's other two hits never land (player %d, not 2 or dead)" % combat.player.hp)
	_check(combat.phase == Combat.Phase.ENDED and not combat.player.is_dead(), "the fight ends as a victory")
