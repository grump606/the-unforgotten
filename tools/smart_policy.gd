class_name SmartPolicy
extends RefCounted
## "Smart" sim policy: a stronger player model than the greedy SimPolicy, used by
## run_sim.gd --policy smart so balance can be judged at more than one skill level.
## Uses only the public Combat, RunState and Vendor APIs.
##
## Combat: before each play every playable (card, target) pair is scored and the
## best score per energy (value / (cost + 1)) is played; the turn ends when
## nothing has positive value. Value of a card is the sum of its effects:
##  - Damage: HP actually removed (after the target's Expose and block), weighted
##    by 1 + the target's threat / its HP, so the enemy that threatens the most
##    damage per HP is focused. A killing blow adds a bonus of 4 + 1.5 x the
##    killed enemy's threat. Overkill is not counted, so a finisher is preferred
##    to a bigger hit that wastes damage. Sweep sums over every living enemy.
##  - Block: 2 per point that cancels incoming damage still unblocked, 0.1 per
##    wasted point ("block exactly").
##  - Draw: 1.5 per card while energy is left to use it, else 0.2 (this is the value of playing it now;
##    scoring a card for the deck or a vendor uses DRAW_VALUE, 2.5 per card).
##  - Expose on an enemy: half the damage of the other affordable damage cards
##    that the Expose multiplier would boost this turn (expose before damage),
##    plus a little for extra turns; 0 if it is already exposed. An Expose that
##    has damage to boost also gets a large ordering bonus so it is played first.
##    Expose on self is penalised.
## The per-energy ratio makes the policy spend its energy on the best total rather
## than the single best card, and free cards (ratio = value) are played early.
##
##  - Malice / Ward gained by the user: +amount on every later damage hit (Block card), valued per
##    hit (per Block effect) it will boost: the other affordable cards in hand this turn, plus, for a
##    stack that lasts the fight, TYPICAL_REMAINING_TURNS more turns of TYPICAL_HITS_PER_TURN hits. A
##    temporary stack counts this turn's cards only. One that boosts a card in hand gets a large ordering
##    bonus (MALICE_FIRST / WARD_FIRST), like Expose. Negative Malice / Ward on an enemy is worth the
##    damage / Block its next intent loses per turn (a stack on an enemy that is temporary is cleared
##    before the enemy acts, so it is worth nothing).
##  - Shaken on an enemy: a quarter of its next attack, for up to SHAKEN_TURNS_CAP turns, 0 if it has no
##    attack, is already Shaken, or the damage in hand kills it. Frayed on an enemy: a quarter of the Block
##    it is about to gain (0 if it is not about to Block). Shaken or Frayed on the player (a SELF card) is
##    a cost, so such a card only plays when its other effects outweigh it.
##
## Rewards and vendor: a card is scored for the deck as it stands, by effect, as
## sum(damage x w_damage, block x w_block, draw x 2.5, expose x 2) divided by
## (cost + 1). w_damage / w_block lean toward whichever of damage and block points
## the deck has less of (target 55% damage), clamped to 0.5..1.5. The offered
## reward is skipped when its score is below the deck's average card score. At
## the vendor it heals first (same rule as greedy), buys any card scoring above
## the deck average (best first, while gold allows), then removes the weakest card
## (once, if gold remains, the deck has more than MIN_DECK cards and the card
## scores below REMOVE_BELOW x the average). At a reward it may instead use the once-per-run
## free Heal or Remove (see take_reward).
##
## Files: this script runs the turn (which play, the open Glimpse / Recall pick, the end-of-turn discard) and is the
## entry point the sims and tests call; SmartPlayValue (tools/smart_play_value.gd) prices a play in a fight,
## SmartCardScore (tools/smart_card_score.gd) scores a card for the deck and holds the tunables both share, and
## SmartRunPicks (tools/smart_run_picks.gd) makes the choices outside a fight (route, events, rewards, Remember,
## vendor). The functions and constants at the end of this script forward to those, so callers name SmartPolicy only.

## Ordering nudge for a Fading card worth playing: it is lost if still in hand at the end of the turn.
const FADING_URGENCY := 2.0
## A Forgotten card played leaves the fight: its play must be worth this much more than nothing, so a
## cheaper option (or a 1-point hit) is preferred to burning it.
const FORGOTTEN_PLAY_COST := 2.0
## How much more readily the bot throws a card with discard effects away at the end of the turn.
const DISCARD_PREFERENCE := 3.0


## Plays cards until nothing is worth playing or the fight ends, then ends the
## turn. Returns false (after logging) if a chosen play is rejected.
static func play_turn(combat: Combat) -> bool:
	while true:
		# An open Glimpse / Recall pick blocks everything else, so it is settled before each decision.
		if not resolve_choices(combat):
			return false
		if combat.phase != Combat.Phase.PLAYER_TURN:
			return true
		var best_hand := -1
		var best_target := -1
		var best_score := 0.0
		var best_surge := false
		# The enemies' next intents do not change while the policy only prices plays, so price them once.
		var incoming := combat.incoming_damage()
		for i in combat.piles.hand.size():
			if not combat.can_play(i):
				continue
			var card: CardData = combat.piles.hand[i]
			if SimPolicy.recycles_itself(combat, card):
				continue
			for target in _targets(combat, card):
				var value := SmartPlayValue.play_value(combat, i, target, incoming)
				if card.fading and value > 0.0:
					value += FADING_URGENCY
				elif card.forgotten and value > 0.0 and not SmartPlayValue.kills(combat, card, target):
					value -= FORGOTTEN_PLAY_COST
				var score := value / (combat.spent_energy(card) + 1)
				# A Surge spends whatever energy is left, so every other card goes first.
				var surge := card.surge
				if score > 0.0 and (best_hand == -1 or (best_surge and not surge) or (best_surge == surge and score > best_score)):
					best_score = score
					best_hand = i
					best_target = target
					best_surge = surge
		if best_hand == -1:
			break
		if not combat.play_card(best_hand, best_target):
			printerr("SmartPolicy: policy chose an unplayable card (index %d)" % best_hand)
			return false
	return combat.end_player_turn(discards_for(combat))


## Resolves every open choice with this policy's picks (see resolve_choice). False only if one is stuck.
static func resolve_choices(combat: Combat) -> bool:
	return SimPolicy.resolve_choices(combat, resolve_choice)


## Picks for the open Glimpse / Recall choice (falls back to Combat.auto_resolve_choice if invalid).
##  - Glimpse: discards every Dormant card and every card whose card_score (deck weights) is below the
##    average card_score of the non-Dormant cards in hand, draw and discard; keeps the rest.
##  - Recall: returns exactly choice_required() Forgotten cards, highest card_score first (earlier wins ties).
static func resolve_choice(combat: Combat) -> bool:
	if not combat.has_choice():
		return true
	var weights := SmartCardScore.combat_weights(combat)
	var cards := combat.choice_cards()
	var picks: Array[int] = []
	if combat.choice_kind() == CardEffect.Kind.GLIMPSE:
		var average := SmartCardScore.average_in_cycle(combat, weights)
		for i in cards.size():
			if SmartCardScore.glimpse_junk(cards[i], weights, average):
				picks.append(i)
	else:
		var scores: Array[float] = []
		for card in cards:
			scores.append(SmartCardScore.card_score(card, weights))
		picks = SimPolicy.best_indices(scores, combat.choice_required())
	return SimPolicy.finish_choice(combat, picks)


## End-of-turn discard: keeps the Combat.HAND_SIZE highest-scoring cards (card_score, weighted by the
## whole deck's damage/block mix) and discards the rest; discards nothing with HAND_SIZE or fewer.
static func discards_for(combat: Combat) -> Array[int]:
	var all: Array[CardData] = []
	all.append_array(combat.piles.hand)
	all.append_array(combat.piles.draw_pile)
	all.append_array(combat.piles.discard_pile)
	var weights := SmartCardScore.deck_weights(all)
	# Anchor and Fading cards do not count toward the five and cannot be discarded: never offer them.
	var candidates: Array[int] = []
	var scores: Array[float] = []
	for i in combat.piles.hand.size():
		if combat.can_discard_card(i):
			candidates.append(i)
			var keep := SmartCardScore.card_score(combat.piles.hand[i], weights)
			if not combat.piles.hand[i].discard_effects.is_empty():
				keep -= DISCARD_PREFERENCE
			scores.append(keep)
	var out: Array[int] = []
	for k in SimPolicy.worst_indices(scores):
		out.append(candidates[k])
	out.sort()
	return out


## Target indexes to consider: every living enemy for single-target cards, else -1.
static func _targets(combat: Combat, card: CardData) -> Array[int]:
	var targets: Array[int] = []
	if card.target_mode == CardData.TargetMode.SINGLE_ENEMY:
		for i in combat.enemies.size():
			if not combat.enemies[i].is_dead():
				targets.append(i)
	else:
		targets.append(-1)
	return targets


# --- Forwarded to the helpers (the names the sims, tests and docs use) ------------------------------------

const TYPICAL_BLOCK := SmartCardScore.TYPICAL_BLOCK
const TYPICAL_SURGE_ENERGY := SmartCardScore.TYPICAL_SURGE_ENERGY
const GLIMPSE_CLASS_SHARE := SmartCardScore.GLIMPSE_CLASS_SHARE
const OATH_FIRING_SHARE := SmartCardScore.OATH_FIRING_SHARE
const MIN_DECK := SmartRunPicks.MIN_DECK
const EVENT_MIN_GOLD := SmartRunPicks.EVENT_MIN_GOLD


## See SmartCardScore.card_score.
static func card_score(card: CardData, weights: Dictionary, depth: int = 0) -> float:
	return SmartCardScore.card_score(card, weights, depth)


## See SmartCardScore.glimpse_junk.
static func glimpse_junk(card: CardData, weights: Dictionary, average: float) -> bool:
	return SmartCardScore.glimpse_junk(card, weights, average)


## See SmartCardScore.deck_weights.
static func _weights(deck: Array[CardData]) -> Dictionary:
	return SmartCardScore.deck_weights(deck)


## See SmartCardScore.nominal_damage.
static func _nominal_damage(effect: CardEffect, forgotten: int = SmartCardScore.TYPICAL_FORGOTTEN) -> float:
	return SmartCardScore.nominal_damage(effect, forgotten)


## See SmartCardScore.average_score.
static func _average_score(deck: Array[CardData], weights: Dictionary) -> float:
	return SmartCardScore.average_score(deck, weights)


## See SmartPlayValue.oath_turns_left.
static func oath_turns_left(combat: Combat) -> int:
	return SmartPlayValue.oath_turns_left(combat)


## See SmartPlayValue.play_value.
static func _play_value(combat: Combat, hand_index: int, target: int, incoming: int = -1) -> float:
	return SmartPlayValue.play_value(combat, hand_index, target, incoming)


## See SmartPlayValue.kills.
static func _kills(combat: Combat, card: CardData, target: int) -> bool:
	return SmartPlayValue.kills(combat, card, target)


## See SmartPlayValue.other_uses.
static func _other_uses(combat: Combat, hand_index: int, energy_left: int, is_malice: bool) -> int:
	return SmartPlayValue.other_uses(combat, hand_index, energy_left, is_malice)


## See SmartPlayValue.other_damage_total.
static func _other_damage_total(combat: Combat, hand_index: int) -> int:
	return SmartPlayValue.other_damage_total(combat, hand_index)


## See SmartPlayValue.other_damage.
static func _other_damage(combat: Combat, hand_index: int, energy_left: int) -> int:
	return SmartPlayValue.other_damage(combat, hand_index, energy_left)


## See SmartRunPicks.event_stop.
static func event_stop(run: RunState) -> bool:
	return SmartRunPicks.event_stop(run)


## See SmartRunPicks.event_score.
static func event_score(run: RunState, effects: Array[EventEffect]) -> float:
	return SmartRunPicks.event_score(run, effects)


## See SmartRunPicks.choose_route.
static func choose_route(run: RunState, route: String = RoutePolicy.SMART) -> int:
	return SmartRunPicks.choose_route(run, route)


## See SmartRunPicks.pick_reward.
static func pick_reward(run: RunState) -> CardData:
	return SmartRunPicks.pick_reward(run)


## See SmartRunPicks.take_reward.
static func take_reward(run: RunState) -> bool:
	return SmartRunPicks.take_reward(run)


## See SmartRunPicks.remember_pick.
static func remember_pick(run: RunState, indices: Array[int] = []) -> int:
	return SmartRunPicks.remember_pick(run, indices)


## See SmartRunPicks.shop.
static func shop(run: RunState) -> bool:
	return SmartRunPicks.shop(run)

