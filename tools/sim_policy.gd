class_name SimPolicy
extends RefCounted
## Greedy, Expose-aware card policy shared by balance_sim.gd and run_sim.gd.
## Uses only the public Combat API.


## Plays cards until the policy passes or the fight ends, then ends the turn.
## Combat.MAX_PLAYS_PER_TURN stops a self-recycling zero-cost deck (no card is
## playable once it is hit), so this always terminates. Returns false (after
## logging) if the policy picked an unplayable card.
static func play_turn(combat: Combat) -> bool:
	while true:
		var pick := _pick_card(combat)
		if pick == -1:
			break
		if not combat.play_card(pick, _target_for(combat, combat.piles.hand[pick])):
			printerr("SimPolicy: policy chose an unplayable card (index %d)" % pick)
			return false
		if combat.phase != Combat.Phase.PLAYER_TURN:
			break
	combat.end_player_turn()
	return true


## Hand index to play next, or -1 to end the turn. Priority: an Expose card
## when it can set up another affordable damage card this turn, then 0-cost
## cards, then block if the enemies' intents out-damage current block, then
## damage, then anything else affordable. Energy-neutral setup (a card that refunds its own cost, like
## Pocket Watch and Seance) ranks with the 0-cost cards, since it only adds cards to play. Reckoning
## waits until the Haunt cards are played, and it and Spirit Tithe are skipped while they would do
## nothing. (Holding Spree and Last Pocket back until last was tried: it starved them of energy, and
## Last Pocket's plays fell from 10 to 4 per run.)
static func _pick_card(combat: Combat) -> int:
	var need_block := _incoming_damage(combat) > combat.player.block
	var best := -1
	var best_rank := 99.0
	for i in combat.piles.hand.size():
		if not combat.can_play(i):
			continue
		var card: CardData = combat.piles.hand[i]
		if _too_costly_in_hp(combat, card) or _is_pointless(combat, card):
			continue
		var rank := 3.0
		if _expose_sets_up_damage(combat, i):
			rank = -1
		elif card.cost == 0 or _refunds_cost(card):
			rank = 0
		elif need_block and is_block_card(card):
			rank = 1
		elif _has_effect(card, CardEffect.Kind.DAMAGE_PER_HAUNT):
			rank = 2.5
		elif is_damage_card(card):
			rank = 2
		if rank < best_rank:
			best_rank = rank
			best = i
	return best


## True if the card gives back at least the energy it costs (Pocket Watch, Seance).
static func _refunds_cost(card: CardData) -> bool:
	var gained := 0
	for effect in card.effects:
		if effect.kind == CardEffect.Kind.GAIN_ENERGY:
			gained += effect.amount
	return gained > 0 and gained >= card.cost


## True for an energy-refunding draw card (Pocket Watch, Seance) while the draw pile holds fewer cards
## than it draws: it would reshuffle the discard and mostly draw itself back, so the bot would replay it
## up to the per-turn cap for nothing. Both policies skip it then.
static func recycles_itself(combat: Combat, card: CardData) -> bool:
	if not _refunds_cost(card):
		return false
	var drawn := 0
	for effect in card.effects:
		if effect.kind == CardEffect.Kind.DRAW:
			drawn += effect.amount
	return drawn > combat.piles.draw_pile.size()


## True if playing the card now would do nothing: Spirit Tithe with no Haunted enemy or no HP to
## heal, Reckoning with no Haunted enemy to hit.
static func _is_pointless(combat: Combat, card: CardData) -> bool:
	if recycles_itself(combat, card):
		return true
	if _has_effect(card, CardEffect.Kind.HEAL_PER_HAUNTED):
		return _haunted_target(combat) == -1 or combat.player.hp >= combat.player.max_hp
	if _has_effect(card, CardEffect.Kind.DAMAGE_PER_HAUNT):
		return _haunted_target(combat) == -1
	return false


## Target for `card`: the most Haunted enemy for a Haunt-scaled hit (Reckoning), else the lowest-HP enemy.
static func _target_for(combat: Combat, card: CardData) -> int:
	if _has_effect(card, CardEffect.Kind.DAMAGE_PER_HAUNT):
		var haunted := _haunted_target(combat)
		if haunted != -1:
			return haunted
	return _lowest_hp_target(combat)


## Index of the living enemy with the most Haunt (first on ties), or -1 if none is Haunted.
static func _haunted_target(combat: Combat) -> int:
	var best := -1
	var best_turns := 0
	for i in combat.enemies.size():
		var enemy := combat.enemies[i]
		var turns := enemy.status_turns(Combatant.Status.HAUNTED)
		if not enemy.is_dead() and turns > best_turns:
			best = i
			best_turns = turns
	return best


## True if hand card `index` exposes a target that is not exposed yet and the
## rest of the hand holds another affordable damage card (after paying for this
## one) to benefit. Targets match play_card's: the lowest-HP enemy for single
## target cards, every living enemy for all-enemies cards.
static func _expose_sets_up_damage(combat: Combat, index: int) -> bool:
	var card: CardData = combat.piles.hand[index]
	if card.target_mode == CardData.TargetMode.SELF or not _has_effect(card, CardEffect.Kind.EXPOSE):
		return false
	var all_exposed := true
	if card.target_mode == CardData.TargetMode.ALL_ENEMIES:
		for enemy in combat.living_enemies():
			if enemy.status_turns(Combatant.Status.EXPOSED) == 0:
				all_exposed = false
	else:
		var target := _lowest_hp_target(combat)
		all_exposed = target == -1 or combat.enemies[target].status_turns(Combatant.Status.EXPOSED) > 0
	if all_exposed:
		return false
	for j in combat.piles.hand.size():
		if j != index and is_damage_card(combat.piles.hand[j]) and combat.piles.hand[j].cost <= combat.energy - card.cost:
			return true
	return false


## Vendor step shared by both bots: buys the visit's relic when it is affordable (the vendor stocks at
## most one, so cheapest-eligible is that one), before any gold goes on cards. False only if the run
## refuses an affordable relic.
static func buy_relic(run: RunState) -> bool:
	var offer := run.vendor().relic_offer()
	if offer.is_empty() or offer["sold"] or offer["price"] > run.gold:
		return true
	if not run.vendor_buy_relic().ok:
		printerr("SimPolicy: vendor refused an affordable relic")
		return false
	return true


## A card the policy treats as an attack: plain or scaled damage, or Haunt (damage over time).
static func is_damage_card(card: CardData) -> bool:
	for effect in card.effects:
		match effect.kind:
			CardEffect.Kind.DAMAGE, CardEffect.Kind.DAMAGE_PER_BLOCK, CardEffect.Kind.DAMAGE_IF_BLOCK, CardEffect.Kind.DAMAGE_PER_PLAY, CardEffect.Kind.DAMAGE_PER_HAUNT, CardEffect.Kind.HAUNT:
				return true
	return false


## A card the policy treats as defence: Block, or the Hold and Thorns that go with it.
static func is_block_card(card: CardData) -> bool:
	for effect in card.effects:
		match effect.kind:
			CardEffect.Kind.BLOCK, CardEffect.Kind.HOLD, CardEffect.Kind.THORNS:
				return true
	return false


## Greedy never pays HP that would leave it under a quarter of its max HP.
static func _too_costly_in_hp(combat: Combat, card: CardData) -> bool:
	return card.hp_cost() > 0 and combat.player.hp - card.hp_cost() < combat.player.max_hp / 4


static func _has_effect(card: CardData, kind: CardEffect.Kind) -> bool:
	for effect in card.effects:
		if effect.kind == kind:
			return true
	return false


static func _incoming_damage(combat: Combat) -> int:
	var total := 0
	for enemy in combat.living_enemies():
		var intent := enemy.current_intent()
		if intent != null and intent.kind == CardEffect.Kind.DAMAGE:
			total += combat.player.damage_after_status(intent.amount)
	return total


## Index into combat.enemies of the living enemy with the least HP (first on ties).
static func _lowest_hp_target(combat: Combat) -> int:
	var best := -1
	for i in combat.enemies.size():
		var enemy := combat.enemies[i]
		if not enemy.is_dead() and (best == -1 or enemy.hp < combat.enemies[best].hp):
			best = i
	return best
