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
	# A play can end the fight (the last enemy died); there is then no turn left to end.
	if combat.phase != Combat.Phase.PLAYER_TURN:
		return true
	return combat.end_player_turn(discards_for(combat))


## End-of-turn discard: keeps the Combat.HAND_SIZE best counted cards by keep_score and discards the rest.
## Anchor and Fading cards do not count toward the five and can never be discarded, so they are never
## offered. With HAND_SIZE or fewer counted cards in hand it discards nothing (never pointlessly).
static func discards_for(combat: Combat) -> Array[int]:
	var candidates: Array[int] = []
	var scores: Array[float] = []
	for i in combat.piles.hand.size():
		if combat.can_discard_card(i):
			candidates.append(i)
			scores.append(keep_score(combat, combat.piles.hand[i]))
	var out: Array[int] = []
	for k in worst_indices(scores):
		out.append(candidates[k])
	out.sort()
	return out


## Indices (sorted) of the cards to throw away so that Combat.HAND_SIZE of the highest `scores`
## remain; earlier cards win ties. Empty when no more than HAND_SIZE cards are held.
static func worst_indices(scores: Array[float]) -> Array[int]:
	var order: Array[int] = []
	for i in scores.size():
		order.append(i)
	# Stable order: higher score first, then lower index.
	order.sort_custom(func(a: int, b: int) -> bool: return scores[a] > scores[b] or (scores[a] == scores[b] and a < b))
	var out: Array[int] = []
	for k in range(Combat.HAND_SIZE, order.size()):
		out.append(order[k])
	out.sort()
	return out


## How much the greedy bot wants to keep a card it could not play this turn: attacks, then defence,
## then the rest, cheaper first (easier to afford next turn); a card it would refuse to play anyway
## (pointless now, or too costly in HP) ranks last.
static func keep_score(combat: Combat, card: CardData) -> float:
	var tier := 1.0
	if is_damage_card(card) or _is_permanent_buff(card):
		tier = 3.0
	elif is_block_card(card):
		tier = 2.0
	if _is_pointless(combat, card) or _too_costly_in_hp(combat, card) or card.dormant:
		tier = 0.0
	return tier * 10.0 - card.cost


## Hand index to play next, or -1 to end the turn. Priority: an Expose card
## when it can set up another affordable damage card this turn, then 0-cost
## cards, then block if the enemies' intents out-damage current block, then
## damage, then anything else affordable. Energy-neutral setup (a card that refunds its own cost, like
## Borrowed Time and Seance) ranks with the 0-cost cards, since it only adds cards to play. Reckoning
## waits until the Haunt cards are played, and it and Spirit Tithe are skipped while they would do
## nothing. (Holding Many Hands and Last Keepsake back until last was tried: it starved them of energy, and
## Last Keepsake's plays fell from 10 to 4 per run.)
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
		if card.surge:
			# A Surge spends every point of energy left, so it goes last; at 0 energy a scaling
			# one does nothing (and playing it would only burn a play).
			if combat.energy == 0 and _scales_with_energy(card):
				continue
			rank = 4.0
		elif _expose_sets_up_damage(combat, i) or _buff_sets_up(combat, card):
			rank = -1
		elif card.fading:
			# It is lost at the end of the turn, so play it before the ordinary cards.
			rank = -0.5
		elif card.cost == 0 or _refunds_cost(card):
			rank = 0
		elif _is_permanent_buff(card):
			# A stack for the whole fight is worth more the earlier it is played.
			rank = 0.5
		elif need_block and (is_block_card(card) or _has_effect(card, CardEffect.Kind.SHAKEN)):
			# Shaken on an attacker cuts the hit like Block does.
			rank = 1
		elif _has_effect(card, CardEffect.Kind.DAMAGE_PER_HAUNT):
			rank = 2.5
		elif is_damage_card(card):
			rank = 2
		if rank < best_rank:
			best_rank = rank
			best = i
	return best


## True if any effect of the card scales with the energy a Surge spends.
static func _scales_with_energy(card: CardData) -> bool:
	for effect in card.effects:
		if effect.per_energy:
			return true
	return false


## True if the card gives back at least the energy it costs (Borrowed Time, Seance).
static func _refunds_cost(card: CardData) -> bool:
	var gained := 0
	for effect in card.effects:
		if effect.kind == CardEffect.Kind.GAIN_ENERGY:
			gained += effect.amount
	return gained > 0 and gained >= card.cost


## True for an energy-refunding draw card (Borrowed Time, Seance) while the draw pile holds fewer cards
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
	return _is_pointless_status(combat, card)


## True if a card of the Malice / Ward / Shaken / Frayed family would do nothing useful now (the greedy
## bot's rule; SmartPolicy prices them instead): a self-targeted Shaken or Frayed is a pure cost, Shaken
## needs an enemy that attacks and is not already Shaken, Frayed or a negative Ward needs an enemy about
## to Block, a negative Malice needs an attacker, and a temporary buff needs a card it would boost.
static func _is_pointless_status(combat: Combat, card: CardData) -> bool:
	var energy_left := combat.energy - card.cost
	for effect in card.effects:
		match effect.kind:
			CardEffect.Kind.SHAKEN, CardEffect.Kind.FRAYED:
				if card.target_mode == CardData.TargetMode.SELF:
					return true
				var found := false
				for enemy in combat.living_enemies():
					if effect.kind == CardEffect.Kind.SHAKEN:
						found = found or (intent_hit(combat, enemy) > 0 and enemy.status_turns(Combatant.Status.SHAKEN) == 0)
					else:
						found = found or _blocks_next(enemy)
				if not found:
					return true
			CardEffect.Kind.MALICE, CardEffect.Kind.WARD:
				if effect.amount < 0:
					var found := false
					for enemy in combat.living_enemies():
						found = found or (_blocks_next(enemy) if effect.kind == CardEffect.Kind.WARD else intent_hit(combat, enemy) > 0)
					# A temporary stack on an enemy is cleared before it acts (Combat), so it never helps.
					if not found or effect.temporary:
						return true
				elif effect.temporary and not buff_has_target(combat, card, effect, energy_left):
					return true
	return false


## True if `enemy`'s next intent is a Block.
static func _blocks_next(enemy: EnemyUnit) -> bool:
	var intent := enemy.current_intent()
	return intent != null and intent.kind == CardEffect.Kind.BLOCK


## True if another affordable card in hand would use a positive Malice (damage) or Ward (Block) from `card`.
static func buff_has_target(combat: Combat, card: CardData, effect: CardEffect, energy_left: int) -> bool:
	for other in combat.piles.hand:
		if other == card or other.cost > energy_left:
			continue
		if (is_damage_card(other) if effect.kind == CardEffect.Kind.MALICE else _has_effect(other, CardEffect.Kind.BLOCK)):
			return true
	return false


## True for a positive Malice or Ward the user keeps (a stack for the rest of the fight): worth playing early.
static func _is_permanent_buff(card: CardData) -> bool:
	for effect in card.effects:
		if effect.kind in [CardEffect.Kind.MALICE, CardEffect.Kind.WARD] and effect.amount > 0 and not effect.temporary:
			return true
	return false


## True if the card gives a positive Malice or Ward that another card in hand would use this turn.
static func _buff_sets_up(combat: Combat, card: CardData) -> bool:
	for effect in card.effects:
		var is_buff: bool = effect.kind in [CardEffect.Kind.MALICE, CardEffect.Kind.WARD] and effect.amount > 0
		if is_buff and buff_has_target(combat, card, effect, combat.energy - card.cost):
			return true
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


## HP-before-Block the player would take from the living enemies' next intents, through the shared
## damage pipeline (enemy Malice and Shaken, then the player's Expose).
static func _incoming_damage(combat: Combat) -> int:
	var total := 0
	for enemy in combat.living_enemies():
		total += intent_hit(combat, enemy)
	return total


## Damage `enemy`'s next intent deals the player (all its hits, before Block), 0 for a non-damage intent.
static func intent_hit(combat: Combat, enemy: EnemyUnit) -> int:
	var intent := enemy.current_intent()
	if intent == null or intent.kind != CardEffect.Kind.DAMAGE:
		return 0
	return Combatant.hit_damage(intent.amount, enemy, combat.player) * maxi(intent.hits, 1)


## Index into combat.enemies of the living enemy with the least HP (first on ties).
static func _lowest_hp_target(combat: Combat) -> int:
	var best := -1
	for i in combat.enemies.size():
		var enemy := combat.enemies[i]
		if not enemy.is_dead() and (best == -1 or enemy.hp < combat.enemies[best].hp):
			best = i
	return best
