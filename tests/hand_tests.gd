extends RefCounted
## The hand rules: keep up to HAND_SIZE cards at end of turn (the rest are chosen for discard),
## draw back up to HAND_SIZE, and never hold more than HAND_MAX. Discovered by run_tests.gd.

var _failures := 0


func run() -> int:
	_failures = 0
	_test_constants()
	_test_first_turn_draws_hand_size()
	_test_draw_back_up_after_keeping_k()
	_test_draw_cap_for_card_effects()
	_test_draw_cap_for_relics()
	_test_invalid_discards_change_nothing()
	_test_discard_more_than_required_and_all()
	_test_kept_cards_survive_the_enemy_phase()
	_test_reshuffle_still_works()
	_test_discard_step_and_cancel()
	_test_confirm_needs_enough_discards()
	_test_play_cap_still_ends_turns()
	_test_zero_cost_draw_loops_terminate()
	_test_bots_finish_a_fight_won_mid_turn()
	_test_bot_discards()
	return _failures


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAIL: " + label)


func _fx(kind: CardEffect.Kind, amount: int) -> CardEffect:
	return CardEffect.make(kind, amount)


## `count` distinct cards (ids c0, c1, ...), each cost 1 for 1 damage.
func _deck(count: int) -> Array[CardData]:
	var deck: Array[CardData] = []
	for i in count:
		deck.append(CardData.make(StringName("c%d" % i), "C%d" % i, 1, [_fx(CardEffect.Kind.DAMAGE, 1)] as Array[CardEffect]))
	return deck


func _fight(deck: Array[CardData], intents: Array[CardEffect] = [], relics: Array[RelicData] = []) -> Combat:
	var enemies: Array[EnemyData] = [EnemyData.make("E", 500, intents)]
	var combat := Combat.new(Combatant.new("p", 500), deck, enemies, 1, relics)
	combat.start()
	return combat


func _ints(values: Array) -> Array[int]:
	var out: Array[int] = []
	out.assign(values)
	return out


func _total(combat: Combat) -> int:
	return combat.piles.hand.size() + combat.piles.draw_pile.size() + combat.piles.discard_pile.size()


## Hand indices other than the first `keep` ones.
func _all_but_first(combat: Combat, keep: int) -> Array[int]:
	var out: Array[int] = []
	for i in range(keep, combat.piles.hand.size()):
		out.append(i)
	return out


## Puts `card` (which must be in the hand or the draw pile) at hand slot 0 by swapping, so a test
## does not depend on the shuffle. Card totals are unchanged.
func _to_hand(combat: Combat, card: CardData) -> void:
	var at := combat.piles.hand.find(card)
	if at >= 0:
		combat.piles.hand[at] = combat.piles.hand[0]
		combat.piles.hand[0] = card
		return
	var j := combat.piles.draw_pile.find(card)
	combat.piles.draw_pile[j] = combat.piles.hand[0]
	combat.piles.hand[0] = card


func _draw_card(amount: int) -> CardData:
	return CardData.make(&"drawer", "Drawer", 0, [_fx(CardEffect.Kind.DRAW, amount)] as Array[CardEffect], CardData.TargetMode.SELF)


## A 7-card hand: a 30-card deck whose Drawer (draw 3, free) has just been played from the hand.
func _seven_card_fight() -> Combat:
	var deck := _deck(29)
	deck.append(_draw_card(3))
	var combat := _fight(deck)
	_to_hand(combat, deck[29])
	combat.play_card(0)
	return combat


func _snapshot(combat: Combat) -> String:
	var ids: PackedStringArray = []
	for card in combat.piles.hand:
		ids.append(String(card.id))
	return "%s|%d|%d|%d|%d|%d|%d" % [",".join(ids), combat.turn, combat.energy, combat.phase, combat.piles.draw_pile.size(), combat.piles.discard_pile.size(), combat.player.hp]


func _test_constants() -> void:
	_check(Combat.HAND_SIZE == 5 and Combat.HAND_MAX == 10, "keep limit 5, hand cap 10")


func _test_first_turn_draws_hand_size() -> void:
	var combat := _fight(_deck(30))
	_check(combat.piles.hand.size() == 5 and combat.turn == 1, "turn 1 draws 5")


func _test_draw_back_up_after_keeping_k() -> void:
	for keep in range(0, 6):
		var combat := _fight(_deck(30))
		var kept: Array[CardData] = []
		kept.append_array(combat.piles.hand.slice(0, keep))
		_check(combat.end_player_turn(_all_but_first(combat, keep)), "keeping %d is a legal end of turn" % keep)
		_check(combat.piles.hand.size() == 5, "after keeping %d the hand is back to 5 (got %d)" % [keep, combat.piles.hand.size()])
		var still := true
		for i in keep:
			still = still and combat.piles.hand[i] == kept[i]
		_check(still, "the %d kept cards are still the first cards of the hand" % keep)
		_check(combat.piles.discard_pile.size() == 5 - keep, "the other %d went to the discard pile" % (5 - keep))
		_check(combat.turn == 2 and combat.phase == Combat.Phase.PLAYER_TURN and combat.energy == Combat.ENERGY_PER_TURN, "the next turn started with full energy")
		_check(_total(combat) == 30, "no card lost or created")


func _test_draw_cap_for_card_effects() -> void:
	var deck := _deck(29)
	deck.append(_draw_card(8))
	var combat := _fight(deck)
	_to_hand(combat, deck[29])
	var draw_before := combat.piles.draw_pile.size()
	var discard_before := combat.piles.discard_pile.size()
	combat.play_card(0)
	_check(combat.piles.hand.size() == Combat.HAND_MAX, "a DRAW 8 from 4 cards stops at the hand cap (hand %d)" % combat.piles.hand.size())
	_check(combat.piles.draw_pile.size() == draw_before - (Combat.HAND_MAX - 4), "cards that did not fit stay in the draw pile")
	_check(combat.piles.discard_pile.size() == discard_before + 1, "the discard pile was not reshuffled or burned into")
	_check(_total(combat) == 30, "no card lost or created by a capped draw")
	# A capped draw does not reshuffle the discard pile for cards that would not fit.
	var tight_deck := _deck(12)
	tight_deck.append(_draw_card(9))
	var tight := _fight(tight_deck)
	_to_hand(tight, tight_deck[12])
	# Only 3 cards in the draw pile: a draw below the cap still reshuffles for the rest (here just the
	# played Drawer, which sits in the discard pile) and stops when no card is left.
	tight.piles.draw_pile.assign(tight.piles.draw_pile.slice(0, 3))
	tight.play_card(0)
	_check(tight.piles.hand.size() == 4 + 3 + 1 and tight.piles.draw_pile.is_empty() and tight.piles.discard_pile.is_empty(), "a draw below the cap still reshuffles the discard pile when the draw pile runs dry")
	# Hand at the cap with cards left in both piles: nothing is drawn and nothing is reshuffled.
	var full_deck := _deck(29)
	full_deck.append(_draw_card(6))
	var full := _fight(full_deck)
	_to_hand(full, full_deck[29])
	full.play_card(0)
	_check(full.piles.hand.size() == 10, "setup: hand at the cap")
	var pile := full.piles.draw_pile.size()
	var discard_pile_size := full.piles.discard_pile.size()
	var direct := full.piles.draw(5, Combat.HAND_MAX)
	_check(direct == 0 and full.piles.draw_pile.size() == pile and full.piles.discard_pile.size() == discard_pile_size, "drawing at the cap draws nothing and reshuffles nothing")


func _test_draw_cap_for_relics() -> void:
	var relics: Array[RelicData] = [RelicData.make(&"r", "R", RelicData.Kind.FIRST_PLAY_DRAW, 9, 10)]
	var combat := _fight(_deck(30), [], relics)
	var pile := combat.piles.draw_pile.size()
	combat.play_card(0)
	_check(combat.piles.hand.size() == Combat.HAND_MAX, "a relic draw stops at the hand cap")
	_check(combat.piles.draw_pile.size() == pile - (Combat.HAND_MAX - 4) and _total(combat) == 30, "undrawn cards stay in the draw pile")
	var small: Array[RelicData] = [RelicData.make(&"r", "R", RelicData.Kind.FIRST_PLAY_DRAW, 2, 10)]
	var under := _fight(_deck(30), [], small)
	under.play_card(0)
	_check(under.piles.hand.size() == 4 + 2, "a relic draw under the cap draws in full")


func _test_invalid_discards_change_nothing() -> void:
	var fight := _seven_card_fight()
	_check(fight.piles.hand.size() == 7, "setup: a 7-card hand")
	var snapshot := _snapshot(fight)
	var bad: Array[Array] = [
		[], # keeps 7
		[0], # keeps 6
		[0, 0, 1], # a duplicate
		[0, 1, 99], # out of range
		[-1, 0, 1], # negative
	]
	for attempt in bad:
		var indices: Array[int] = []
		indices.assign(attempt)
		_check(not fight.end_player_turn(indices), "rejected discard %s" % str(attempt))
		_check(_snapshot(fight) == snapshot, "state unchanged after rejected discard %s" % str(attempt))
	_check(not fight.is_valid_discard([] as Array[int]) and fight.is_valid_discard([0, 1] as Array[int]), "is_valid_discard agrees")
	var ended := _fight(_deck(30))
	ended.abandon()
	_check(not ended.end_player_turn(), "no turn can be ended after the fight ended")
	var plain := _fight(_deck(30))
	_check(plain.end_player_turn(), "a 5-card hand may keep everything with no argument")


func _test_discard_more_than_required_and_all() -> void:
	var combat := _fight(_deck(30))
	combat.end_player_turn([0, 1] as Array[int])
	_check(combat.piles.hand.size() == 5 and combat.piles.discard_pile.size() == 2, "discarding extra from a 5-card hand is allowed")
	var all := _fight(_deck(30))
	var old_hand: Array[CardData] = []
	old_hand.append_array(all.piles.hand)
	all.end_player_turn([0, 1, 2, 3, 4] as Array[int])
	var fresh := true
	for card in all.piles.hand:
		fresh = fresh and not old_hand.has(card)
	_check(all.piles.hand.size() == 5 and all.piles.discard_pile.size() == 5 and fresh, "discarding the whole hand works and the next hand is 5 new cards")


func _test_kept_cards_survive_the_enemy_phase() -> void:
	var intents: Array[CardEffect] = [_fx(CardEffect.Kind.DAMAGE, 3)]
	var combat := _fight(_deck(30), intents)
	var kept: Array[CardData] = []
	kept.append_array(combat.piles.hand)
	combat.end_player_turn([] as Array[int])
	_check(combat.player.hp == 497, "the enemy phase ran")
	_check(combat.piles.hand == kept and combat.piles.discard_pile.is_empty(), "five kept cards are still the same hand after the enemy phase, nothing discarded")


func _test_reshuffle_still_works() -> void:
	var combat := _fight(_deck(8))
	_check(combat.piles.draw_pile.size() == 3, "setup: 3 cards left in the draw pile")
	combat.end_player_turn([0, 1, 2, 3, 4] as Array[int])
	_check(combat.piles.hand.size() == 5 and _total(combat) == 8, "drawing 5 from a 3-card pile reshuffled the discard pile for the rest")
	_check(combat.piles.discard_pile.is_empty() and combat.piles.draw_pile.size() == 3, "the discard pile became the draw pile (3 of 8 cards left to draw)")


func _test_discard_step_and_cancel() -> void:
	var combat := _fight(_deck(30))
	var before := _snapshot(combat)
	_check(not combat.toggle_discard(0) and not combat.confirm_discard() and not combat.cancel_discard(), "discard actions need the discard step")
	_check(combat.begin_discard() and combat.phase == Combat.Phase.DISCARDING, "End Turn enters the discard step")
	_check(not combat.can_play(0) and not combat.play_card(0), "no card can be played during the discard step")
	_check(not combat.begin_discard(), "the discard step cannot be entered twice")
	_check(combat.toggle_discard(2) and combat.discard_marks == _ints([2]), "toggling marks a card")
	_check(combat.toggle_discard(0) and combat.discard_marks == _ints([0, 2]), "marks stay sorted")
	_check(combat.toggle_discard(2) and combat.discard_marks == _ints([0]), "toggling again unmarks")
	_check(not combat.toggle_discard(9) and not combat.toggle_discard(-1), "bad indices are rejected")
	_check(combat.discard_required() == 0 and combat.can_confirm_discard(), "five cards need no discards")
	combat.cancel_discard()
	combat.begin_discard()
	_check(combat.cancel_discard() and combat.phase == Combat.Phase.PLAYER_TURN, "cancel returns to the player's turn")
	_check(_snapshot(combat) == before and combat.discard_marks.is_empty(), "cancel leaves the hand, energy and piles unchanged")
	_check(combat.can_play(0), "cards are playable again after cancel")
	combat.begin_discard()
	combat.toggle_discard(0)
	_check(combat.confirm_discard() and combat.turn == 2 and combat.piles.hand.size() == 5 and combat.piles.discard_pile.size() == 1, "confirm discards the marked card, runs the enemy phase and redraws")


func _test_confirm_needs_enough_discards() -> void:
	var combat := _seven_card_fight()
	var size := combat.piles.hand.size()
	_check(size > Combat.HAND_SIZE, "setup: a hand over the keep limit (%d)" % size)
	combat.begin_discard()
	_check(combat.discard_required() == size - Combat.HAND_SIZE and not combat.can_confirm_discard() and not combat.confirm_discard(), "confirm is refused while too many cards would stay")
	_check(combat.phase == Combat.Phase.DISCARDING and combat.turn == 1, "a refused confirm changes nothing")
	for i in size - Combat.HAND_SIZE:
		combat.toggle_discard(i)
	_check(combat.discard_required() == 0 and combat.can_confirm_discard(), "enough marked cards allows confirming")
	_check(combat.confirm_discard() and combat.piles.hand.size() == 5, "confirming keeps exactly 5 and draws nothing extra")


func _test_play_cap_still_ends_turns() -> void:
	var glimpse := load(StarterContent.GLIMPSE_EXIT_PATH) as CardData
	var deck: Array[CardData] = [glimpse]
	var combat := _fight(deck)
	var plays := 0
	while combat.can_play(0) and plays < Combat.MAX_PLAYS_PER_TURN * 2:
		combat.play_card(0)
		plays += 1
	_check(plays == Combat.MAX_PLAYS_PER_TURN, "the per-turn play cap still binds (%d plays)" % plays)
	_check(combat.begin_discard() and combat.confirm_discard() and combat.turn == 2, "the capped turn ends through the discard step")


func _test_zero_cost_draw_loops_terminate() -> void:
	for path in [StarterContent.POCKET_WATCH_PATH, StarterContent.SEANCE_PATH]:
		var card := load(path) as CardData
		var deck: Array[CardData] = []
		for i in 12:
			deck.append(card)
		var greedy := _fight(deck)
		_check(SimPolicy.play_turn(greedy) and greedy.turn == 2 and greedy.piles.hand.size() <= Combat.HAND_MAX, "greedy ends a turn of %s" % card.id)
		var smart := _fight(deck)
		_check(SmartPolicy.play_turn(smart) and smart.turn == 2 and smart.piles.hand.size() <= Combat.HAND_MAX, "smart ends a turn of %s" % card.id)
		# Brute force: keep playing whatever is playable; the hand never passes the cap and the play cap ends it.
		var brute := _fight(deck)
		var played := true
		var over_cap := false
		while played:
			played = false
			for i in brute.piles.hand.size():
				if brute.can_play(i):
					brute.play_card(i)
					played = true
					break
			over_cap = over_cap or brute.piles.hand.size() > Combat.HAND_MAX
		_check(not over_cap, "hand never exceeds the cap while looping %s" % card.id)
		_check(brute.plays_this_turn <= Combat.MAX_PLAYS_PER_TURN, "the loop with %s stops (%d plays)" % [card.id, brute.plays_this_turn])


func _test_bots_finish_a_fight_won_mid_turn() -> void:
	# The last enemy dies inside the turn, so there is no end of turn to perform; the bots still report success.
	var killer := CardData.make(&"killer", "Killer", 1, [_fx(CardEffect.Kind.DAMAGE, 99)] as Array[CardEffect])
	var deck: Array[CardData] = [killer]
	for policy in [SimPolicy, SmartPolicy]:
		var enemies: Array[EnemyData] = [EnemyData.make("E", 10, [] as Array[CardEffect])]
		var combat := Combat.new(Combatant.new("p", 50), deck, enemies)
		combat.start()
		_check(policy.play_turn(combat) and combat.phase == Combat.Phase.ENDED, "a bot that wins mid-turn is not reported as a failure")


func _test_bot_discards() -> void:
	var combat := _fight(_deck(30))
	_check(SimPolicy.discards_for(combat).is_empty() and SmartPolicy.discards_for(combat).is_empty(), "bots keep a hand of 5 whole")
	var strong := CardData.make(&"strong", "Strong", 1, [_fx(CardEffect.Kind.DAMAGE, 9)] as Array[CardEffect])
	var weak := CardData.make(&"weak", "Weak", 1, [_fx(CardEffect.Kind.DAMAGE, 1)] as Array[CardEffect])
	var hand: Array[CardData] = [weak, weak, strong, strong, strong, strong, strong]
	var fight := _fight(_deck(30))
	# Force a 7-card hand for the scoring helpers.
	fight.piles.hand.assign(hand)
	var greedy := SimPolicy.discards_for(fight)
	var smart := SmartPolicy.discards_for(fight)
	_check(greedy.size() == 2 and fight.is_valid_discard(greedy), "greedy discards exactly the surplus")
	_check(smart == _ints([0, 1]),"smart throws away the weakest cards (got %s)" % str(smart))
