class_name SimPolicy
extends RefCounted
## Greedy, Expose-aware card policy shared by balance_sim.gd and run_sim.gd.
## Uses only the public Combat API.


## A fight still running after this many turns is a stall; every sim tool (balance_sim, run_sim, run_stub) uses this one cap.
const TURN_CAP := 50

## Most choices one call settles (a card queues a handful at most); the cap only guards a stuck engine.
const MAX_CHOICES_PER_CALL := 32


## Plays cards until the policy passes or the fight ends, then ends the turn.
## Combat.MAX_PLAYS_PER_TURN stops a self-recycling zero-cost deck (no card is
## playable once it is hit), so this always terminates. Returns false (after
## logging) if the policy picked an unplayable card.
static func play_turn(combat: Combat) -> bool:
	while true:
		# An open Glimpse / Recall pick blocks everything else, so it is settled before each decision.
		if not resolve_choices(combat):
			return false
		if combat.phase != Combat.Phase.PLAYER_TURN:
			return true
		var pick := _pick_card(combat)
		if pick == -1:
			break
		if not combat.play_card(pick, _target_for(combat, combat.piles.hand[pick])):
			printerr("SimPolicy: policy chose an unplayable card (index %d)" % pick)
			return false
	return combat.end_player_turn(discards_for(combat))


## Rest stop for both bots: Rest (heal to full) while HP is under REST_BELOW of max or nothing can be
## Remembered, else Remember a card (no heal). `smart` picks the card by score gain (SmartPolicy.remember_pick),
## greedy takes the first attack that can be Remembered, else the first card. False on a RunState failure.
const REST_BELOW := 0.6


## The rest-stop rule every sim tool shares: Rest while HP is under REST_BELOW of max or no card can be Remembered.
static func prefers_rest(player: Combatant, can_remember_any: bool) -> bool:
	return not can_remember_any or player.hp < REST_BELOW * player.max_hp


static func rest_stop(run: RunState, smart: bool) -> bool:
	var indices := run.rememberable_indices()
	if prefers_rest(run.player, not indices.is_empty()):
		return run.rest() >= 0
	var pick := SmartPolicy.remember_pick(run) if smart else indices[0]
	if not smart:
		for i in indices:
			if is_damage_card(run.deck[i]):
				pick = i
				break
	return run.remember(pick)


## True while the player still has something to do in the fight: a turn to play or a choice to settle.
## The loops that drive a fight use it so a pick left open can never end them as if the fight had stalled.
static func is_acting(combat: Combat) -> bool:
	return combat.phase == Combat.Phase.PLAYER_TURN or combat.phase == Combat.Phase.CHOOSING


## Resolves every open Glimpse / Recall pick (a card can queue several). False, after logging, only if
## a choice could not be closed at all, which would otherwise stall the fight.
## `resolver` settles one choice (default: this policy's resolve_choice; SmartPolicy passes its own).
static func resolve_choices(combat: Combat, resolver: Callable = Callable()) -> bool:
	var resolve := resolver if resolver.is_valid() else resolve_choice
	var guard := 0
	while combat.has_choice():
		guard += 1
		if guard > MAX_CHOICES_PER_CALL or not resolve.call(combat):
			printerr("SimPolicy: could not resolve the open choice")
			return false
	return true


## Greedy picks for the open choice, falling back to Combat.auto_resolve_choice when they are invalid.
##  - Glimpse: discards every Dormant card (Dread, Murmur) and every card whose glimpse_score is below
##    the average of the non-Dormant cards in hand, draw and discard; keeps the rest. May discard nothing.
##  - Recall: returns exactly choice_required() Forgotten cards, the highest keep_score first (earlier
##    cards win ties).
static func resolve_choice(combat: Combat) -> bool:
	if not combat.has_choice():
		return true
	var cards := combat.choice_cards()
	var picks: Array[int] = []
	if combat.choice_kind() == CardEffect.Kind.GLIMPSE:
		var average := _average_glimpse_score(combat)
		for i in cards.size():
			var junk: bool = cards[i].dormant or (cards[i].character == &"" and glimpse_score(cards[i]) < average)
			if junk:
				picks.append(i)
	else:
		var scores: Array[float] = []
		for card in cards:
			scores.append(keep_score(combat, card))
		picks = best_indices(scores, combat.choice_required())
	return finish_choice(combat, picks)


## Applies `picks` to the open choice, or the engine's default resolution if they are not legal.
static func finish_choice(combat: Combat, picks: Array[int]) -> bool:
	if combat.can_resolve_choice(picks):
		return combat.resolve_choice(picks)
	return combat.auto_resolve_choice()


## Indices (sorted) of the `count` highest `scores`; earlier cards win ties.
static func best_indices(scores: Array[float], count: int) -> Array[int]:
	var order: Array[int] = []
	for i in scores.size():
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool: return scores[a] > scores[b] or (scores[a] == scores[b] and a < b))
	var out: Array[int] = []
	for k in mini(count, order.size()):
		out.append(order[k])
	out.sort()
	return out


## Average glimpse_score of the non-Dormant cards in hand, draw pile and discard pile (the cycle the
## cards on offer belong to); 0 with none.
static func _average_glimpse_score(combat: Combat) -> float:
	var total := 0.0
	var count := 0
	for pile in [combat.piles.hand, combat.piles.draw_pile, combat.piles.discard_pile]:
		for card: CardData in pile:
			if not card.dormant:
				total += glimpse_score(card)
				count += 1
	return total / count if count > 0 else 0.0


## keep_score without this moment's state (pointless now, too costly in HP): how good the card is in
## the deck, which is what matters for a card that would only be drawn later.
static func glimpse_score(card: CardData) -> float:
	return _base_tier(card) * 10.0 - card.cost


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
	var tier := _base_tier(card)
	if _is_pointless(combat, card) or _too_costly_in_hp(combat, card) or card.dormant:
		tier = 0.0
	# A card with discard effects is worth more thrown away than kept.
	if not card.discard_effects.is_empty():
		tier -= DISCARD_EFFECT_TIER_PENALTY
	return tier * KEEP_TIER_WEIGHT - card.cost


## Keep tiers (see keep_score): attack or permanent buff, defence, everything else; a Dormant card is 0.
const TIER_ATTACK := 3.0
const TIER_DEFENCE := 2.0
const TIER_OTHER := 1.0
## One tier is worth this many energy in keep_score, so cost only breaks ties within a tier.
const KEEP_TIER_WEIGHT := 10.0
## Tiers a card with discard effects loses: it is worth more thrown away than kept.
const DISCARD_EFFECT_TIER_PENALTY := 1.5


## TIER_ATTACK for an attack or a permanent buff, TIER_DEFENCE for defence, TIER_OTHER for the rest, 0 for a Dormant card.
static func _base_tier(card: CardData) -> float:
	if card.dormant:
		return 0.0
	if is_damage_card(card) or _is_permanent_buff(card) or _has_effect(card, CardEffect.Kind.SCENT):
		return TIER_ATTACK
	if is_block_card(card):
		return TIER_DEFENCE
	return TIER_OTHER


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
		elif card.oath:
			# An Oath acts from the next turn on, so swear it before spending the turn's energy elsewhere.
			rank = -1.5
		elif _has_effect(card, CardEffect.Kind.SCENT):
			# Mark the quarry before the attacks that use it, so it is cheap and goes early.
			rank = -0.9
		elif _has_effect(card, CardEffect.Kind.DAMAGE_PER_SCENT):
			# A spender goes after the ordinary attacks, which gain from the Scent it will use up.
			rank = 2.5
		elif _expose_sets_up_damage(combat, i) or _buff_sets_up(combat, card):
			rank = -1
		elif _has_effect(card, CardEffect.Kind.GLIMPSE):
			# Sets up the draws, so it goes early (pointless ones were skipped above).
			rank = -0.75
		elif _has_effect(card, CardEffect.Kind.RECALL):
			# Early when it returns a card playable this turn; otherwise it can wait until last.
			rank = -0.25 if _recall_returns_playable(combat, card) else 3.0
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


## Last player turn on which the greedy bot still swears an Oath: sworn later, it would fire too few times to
## repay its cost. It also never swears a second copy of an Oath it already has Sworn.
const OATH_LAST_TURN := 2


static func oath_worth_swearing(combat: Combat, card: CardData) -> bool:
	if combat.turn > OATH_LAST_TURN:
		return false
	for sworn in combat.piles.sworn:
		if sworn.id == card.id:
			return false
	return true


## True if playing the card now would do nothing: Spirit Tithe with no Haunted enemy or no HP to
## heal, Reckoning with no Haunted enemy to hit.
static func _is_pointless(combat: Combat, card: CardData) -> bool:
	if recycles_itself(combat, card):
		return true
	# An Oath is judged on what it does for the rest of the fight, not on its play cost (a Dread, lost HP).
	if card.oath:
		return not oath_worth_swearing(combat, card)
	# A card whose only job is Scent does nothing at the cap; a spender waits for a stack worth spending.
	if _has_effect(card, CardEffect.Kind.SCENT) and _scent_total(combat) >= Combatant.SCENT_CAP and not _has_other_value(card, CardEffect.Kind.SCENT):
		return true
	if _has_effect(card, CardEffect.Kind.DAMAGE_PER_SCENT) and not _spender_ready(combat, card):
		# Build the stack first when a card in hand can; otherwise spend what there is.
		return _has_affordable_scent_card(combat)
	if _has_effect(card, CardEffect.Kind.GLIMPSE) and combat.piles.draw_pile.is_empty():
		return not _has_other_value(card, CardEffect.Kind.GLIMPSE)
	if _has_effect(card, CardEffect.Kind.RECALL) and not _forgotten_worth_recalling(combat):
		return not _has_other_value(card, CardEffect.Kind.RECALL)
	if _has_effect(card, CardEffect.Kind.DAMAGE_PER_FORGOTTEN) and combat.piles.forgotten.is_empty():
		return not _has_other_value(card, CardEffect.Kind.DAMAGE_PER_FORGOTTEN)
	if _adds_only_dormant(card):
		return true
	if _has_effect(card, CardEffect.Kind.HEAL_PER_HAUNTED):
		return _haunted_target(combat) == -1 or combat.player.hp >= combat.player.max_hp
	if _has_effect(card, CardEffect.Kind.DAMAGE_PER_HAUNT):
		return _haunted_target(combat) == -1
	return _is_pointless_status(combat, card)


## True if the Forgotten pile holds an attack or a defence card (the only ones the greedy bot would play).
static func _forgotten_worth_recalling(combat: Combat) -> bool:
	for card in combat.piles.forgotten:
		if _base_tier(card) >= 2.0:
			return true
	return false


## True if a Forgotten card that is not Dormant costs no more than the energy left once `card` is paid.
static func _recall_returns_playable(combat: Combat, card: CardData) -> bool:
	for other in combat.piles.forgotten:
		if not other.dormant and other.cost <= combat.energy - card.cost:
			return true
	return false


## True if the card has an effect other than `kind` that does something on its own (damage, Block, Draw,
## energy...), so a pointless `kind` effect does not make the whole card pointless.
static func _has_other_value(card: CardData, kind: CardEffect.Kind) -> bool:
	for effect in card.effects:
		if effect.kind != kind and effect.kind not in [CardEffect.Kind.GLIMPSE, CardEffect.Kind.ADD_CARD, CardEffect.Kind.RECALL]:
			return true
	return false


## True for a card whose only job is to add a Dormant card (Dread, Murmur) to the player's own piles:
## it can only clog the cycle, so the greedy bot never plays it. (Any other effect on the card is valued
## as usual.)
static func _adds_only_dormant(card: CardData) -> bool:
	var adds := false
	for effect in card.effects:
		if effect.kind == CardEffect.Kind.ADD_CARD and effect.card != null and effect.card.dormant:
			adds = true
	return adds and not _has_other_value(card, CardEffect.Kind.ADD_CARD)


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
	# Hunt one target: every single-target card goes to the enemy that holds Scent, if there is one.
	var quarry := _scent_target(combat)
	if quarry != -1:
		return quarry
	return _lowest_hp_target(combat)


## Index of the living enemy holding Scent, or -1 if none does.
static func _scent_target(combat: Combat) -> int:
	return combat.scent_holder_index()


## Scent on the board, whichever enemy holds it.
static func _scent_total(combat: Combat) -> int:
	var total := 0
	for enemy in combat.enemies:
		total += enemy.stacks(Combatant.Status.SCENT)
	return total


## True if a card in hand can add Scent now (affordable, and the stack is below the cap).
static func _has_affordable_scent_card(combat: Combat) -> bool:
	if _scent_total(combat) >= Combatant.SCENT_CAP:
		return false
	for card in combat.piles.hand:
		if not card.dormant and card.cost <= combat.energy and _has_effect(card, CardEffect.Kind.SCENT):
			return true
	return false


## A Scent spender (damage per Scent) is held until the stack is worth spending: 2 plus its cost, so a cheap one
## goes at 3 and Bring Down at 5. Spending also ends the stack, so it goes when it would kill (not judged here).
static func _spender_ready(combat: Combat, card: CardData) -> bool:
	return _scent_total(combat) >= 2 + card.cost


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


## The start of every bot's vendor visit: buy a Heal when at least half of one is missing, then the relic. False,
## after logging, when there is no vendor or the run refuses an affordable relic.
static func shop_basics(run: RunState) -> bool:
	if run.vendor() == null:
		printerr("SimPolicy: no vendor at a vendor stop")
		return false
	if run.player.max_hp - run.player.hp >= Vendor.HEAL_AMOUNT / 2:
		run.vendor_buy_heal()
	return buy_relic(run)


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
		if effect.is_damage() or effect.kind == CardEffect.Kind.HAUNT:
			return true
	return false


## A card the policy treats as defence: Block, or the Hold and Thorns that go with it.
static func is_block_card(card: CardData) -> bool:
	for effect in card.effects:
		match effect.kind:
			CardEffect.Kind.BLOCK, CardEffect.Kind.HOLD, CardEffect.Kind.THORNS:
				return true
	return false


## Greedy never pays HP that would leave it under a quarter of its max HP. The HP cost is the one the engine
## charges (a Surge card's per_energy HP loss scales with the energy it would spend, as in Combat.can_play).
static func _too_costly_in_hp(combat: Combat, card: CardData) -> bool:
	var cost := card.hp_cost(combat.surge_scale(card))
	return cost > 0 and combat.player.hp - cost < combat.player.max_hp / 4


static func _has_effect(card: CardData, kind: CardEffect.Kind) -> bool:
	for effect in card.effects:
		if effect.kind == kind:
			return true
	return false


## HP-before-Block the player would take from the living enemies' next intents, through the shared
## damage pipeline (enemy Malice and Shaken, then the player's Expose).
static func _incoming_damage(combat: Combat) -> int:
	return combat.incoming_damage()


## Damage `enemy`'s next intent deals the player (all its hits, before Block), 0 for a non-damage intent.
static func intent_hit(combat: Combat, enemy: EnemyUnit) -> int:
	return combat.intent_hit(enemy)


## Index into combat.enemies of the living enemy with the least HP (first on ties).
static func _lowest_hp_target(combat: Combat) -> int:
	var best := -1
	for i in combat.enemies.size():
		var enemy := combat.enemies[i]
		if not enemy.is_dead() and (best == -1 or enemy.hp < combat.enemies[best].hp):
			best = i
	return best
