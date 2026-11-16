class_name SmartCardScore
extends RefCounted
## The smart bot's deck-scoring half (see SmartPolicy's header, "Rewards and vendor"): what a card is worth to the
## deck as it stands, by effect, divided by (cost + 1), with damage and block weights leaning toward what the deck
## lacks. Rewards, the vendor, Remember, Glimpse, Recall and the end-of-turn discard all rank cards with it, and a
## fight prices an Oath's effects and a card landing in a pile from it. Also holds the tunables the fight scoring
## (SmartPlayValue) shares with it. Pure functions of their arguments: nothing here touches a Combat or RunState.

const DAMAGE_SHARE := 0.55
## The damage and block reward weights move this much per unit of damage share away from DAMAGE_SHARE, kept within
## WEIGHT_MIN to WEIGHT_MAX (see deck_weights).
const WEIGHT_SWING := 2.0
const WEIGHT_MIN := 0.5
const WEIGHT_MAX := 1.5
## A damage-per-play card is valued at its amount plus this many plays' worth of its bonus.
const PER_PLAY_TYPICAL_PLAYS := 2
const DRAW_VALUE := 2.5
const EXPOSE_VALUE := 2.0
const HAUNT_VALUE := 0.7 # per point of Haunt damage (it lands later, so worth less than a hit)
const HEAL_VALUE := 1.5 # per HP healed
## What a typical Block is worth when a card's damage scales with it (Bash, Cold Steel, Reckoning).
const TYPICAL_BLOCK := 6
const TYPICAL_HAUNT := 4
## A typical enemy attack, for scoring a Shaken card outside a fight.
const TYPICAL_ENEMY_HIT := 8
## Energy a Surge is assumed to spend when a card is scored outside a fight (rewards, vendor, discards).
const TYPICAL_SURGE_ENERGY := 2
## Player turns still to come in a fight when a Malice / Ward stack that lasts the fight is played now.
const TYPICAL_REMAINING_TURNS := 3
## A typical Scent stack when a spender is played, and what a point of applied Scent is worth in a deck score.
const TYPICAL_SCENT := 3
const SCENT_SCORE_PER_POINT := 1.5
## How often an Oath's trigger fires, as a share of the turns left: every turn for TURN_START and FIRST_PLAY,
## about every other turn for a Forgotten card, about one turn in three for a kept Anchor card.
## An Oath scores less in a deck than its effects add up to: it spends a turn's energy before it pays back, and
## its Dread or HP cost drags on every later draw.
const OATH_DECK_DISCOUNT := 0.6
## A card with discard effects: what its deck score counts of them (it only fires when thrown away).
const DISCARD_EFFECT_SHARE := 0.5
const OATH_FIRING_SHARE := {
	CardData.OathTrigger.TURN_START: 1.0,
	CardData.OathTrigger.FIRST_PLAY: 1.0,
	CardData.OathTrigger.ON_FORGOTTEN: 0.5,
	CardData.OathTrigger.ANCHOR_KEPT: 0.3,
	CardData.OathTrigger.END_OF_TURN: 1.0,
	CardData.OathTrigger.ON_BLOCK_GAINED: 0.7,
	CardData.OathTrigger.ON_HP_LOST: 0.3,
	CardData.OathTrigger.EACH_PLAY: 2.5,
	CardData.OathTrigger.ON_DISCARD: 1.0,
	CardData.OathTrigger.QUARRY_DIES: 0.5,
}
## Damage hits (and Block effects) the player lands per turn, for the same estimate.
const TYPICAL_HITS_PER_TURN := 2
const FORGOTTEN_WEIGHT_MIN := 3
const FORGOTTEN_WEIGHT_MAX := 5
const MALICE_CUT_FACTOR := 2.0 # a Malice cut counts double what a Ward cut does
const DEBUFF_HIT_SHARE := 0.25 # a Shaken / Frayed turn is worth this share of a typical hit (or Block)
const SHAKEN_PREVENTED_FACTOR := 2.0
const FRAYED_BLOCK_FACTOR := 0.5
## Value per extra damage point of Malice, per Block point of Ward (half a useful Block point: it can be wasted).
const MALICE_VALUE := 1.0
const WARD_VALUE := 1.0
## Turns of Shaken counted for an enemy (its intents beyond that are unknown), and the value per point of
## damage prevented once Block already covers the incoming damage (SmartPlayValue.PREVENTED_VALUE while it does not).
const SHAKEN_TURNS_CAP := 2
const PREVENTED_VALUE_COVERED := 0.5
## Value per point of Block an enemy loses to Frayed / negative Ward.
const ENEMY_BLOCK_VALUE := 0.7
## Cost per turn of a Shaken / Frayed the player puts on itself.
const SELF_SHAKEN_COST := 4.0
const SELF_FRAYED_COST := 3.0
## Recall / Add card: share of a card's full value (card_score x (cost + 1)) counted when the card lands
## in hand and can be paid for this turn, in the draw pile (it comes round again), and in the discard pile
## (only after a reshuffle); SmartPlayValue.HAND_UNPLAYABLE_SHARE covers a hand card that cannot be paid for.
const HAND_PLAYABLE_SHARE := 0.5
const DRAW_ADD_SHARE := 0.3
const DISCARD_ADD_SHARE := 0.1
## Cost of adding a Dormant card to the player's own piles, per card (it clogs the cycle or a draw slot).
const DORMANT_ADD_COST := 2.0
## Forgotten pile size assumed when a card is scored outside a fight (damage per Forgotten).
const TYPICAL_FORGOTTEN := 3
## card_score of one Glimpse card (a typical junk card seen, not always there to bin).
const GLIMPSE_SCORE_PER_CARD := 0.5
## card_score of one File card (tucking a card away is rarely wanted: a small positive for cycling).
const FILE_SCORE_PER_CARD := 0.5
## card_score of one Recall pick: about a typical card, discounted since the Forgotten pile may be empty.
const RECALL_SCORE_PER_CARD := 4.0
## A class card is binned by Glimpse only below this share of the cycle's average card score (neutral cards: below the average).
const GLIMPSE_CLASS_SHARE := 0.85
## Share of a Forgotten card's full value that a Recall pick is worth (it is played once more, maybe).
const RECALL_VALUE_SHARE := 0.5
## card_score of a Dormant card: it can never be played, so it ranks below everything.
const DORMANT_SCORE := -1.0
## In a deck score, per point: Hold, Thorns, Gain energy, and Lose HP (a cost). A card hitting every enemy counts
## ALL_ENEMIES_SPREAD times its damage.
const DECK_HOLD_VALUE := 0.8
const DECK_THORNS_VALUE := 1.5
const DECK_ENERGY_VALUE := 3.0
const DECK_LOSE_HP_COST := 1.3
const ALL_ENEMIES_SPREAD := 1.3


## True if Glimpse should bin `card`: Dormant, or a card scoring below the average card of the cycle. A
## class card is given the benefit of the doubt (it is binned only below GLIMPSE_CLASS_SHARE of the
## average): card_score undervalues what the class is built around (HP costs, Haunt, Forgotten payoffs).
static func glimpse_junk(card: CardData, weights: Dictionary, average: float) -> bool:
	if card.dormant:
		return true
	var share := 1.0 if card.character == &"" else GLIMPSE_CLASS_SHARE
	return card_score(card, weights) < share * average


## Damage / block weights of every card the fight has (hand, draw, discard and Forgotten piles).
static func combat_weights(combat: Combat) -> Dictionary:
	var all: Array[CardData] = []
	all.append_array(combat.piles.hand)
	all.append_array(combat.piles.draw_pile)
	all.append_array(combat.piles.discard_pile)
	all.append_array(combat.piles.forgotten)
	return deck_weights(all)


## Average card_score of the non-Dormant cards in hand, draw and discard piles; 0 with none.
static func average_in_cycle(combat: Combat, weights: Dictionary) -> float:
	var total := 0.0
	var count := 0
	for pile in [combat.piles.hand, combat.piles.draw_pile, combat.piles.discard_pile]:
		for card: CardData in pile:
			if not card.dormant:
				total += card_score(card, weights)
				count += 1
	return total / count if count > 0 else 0.0


## Damage and block weights {damage, block} leaning toward what the deck lacks.
static func deck_weights(deck: Array[CardData]) -> Dictionary:
	var damage := 0.0
	var block := 0
	for card in deck:
		for effect in card.effects:
			damage += nominal_damage(effect)
			if effect.kind == CardEffect.Kind.BLOCK:
				block += effect.amount
	var share := DAMAGE_SHARE if damage + block == 0 else float(damage) / (damage + block)
	var weights := {
		"damage": clampf(1.0 + (DAMAGE_SHARE - share) * WEIGHT_SWING, WEIGHT_MIN, WEIGHT_MAX),
		"block": clampf(1.0 + (share - DAMAGE_SHARE) * WEIGHT_SWING, WEIGHT_MIN, WEIGHT_MAX),
	}
	# Forgotten cards in the deck decide what a Forgotten payoff (Chorus of the Lost) and a Recall are worth.
	var lost: Array[CardData] = []
	for card in deck:
		if (card.forgotten or card.fading) and not card.dormant:
			lost.append(card)
	weights["forgotten"] = clampi(lost.size(), FORGOTTEN_WEIGHT_MIN, FORGOTTEN_WEIGHT_MAX)
	var total := 0.0
	for card in lost:
		total += maxf(card_score(card, weights), 0.0) * (card.cost + 1)
	weights["recall"] = maxf(RECALL_VALUE_SHARE * total / lost.size(), RECALL_SCORE_PER_CARD + 1.0) if not lost.is_empty() else RECALL_SCORE_PER_CARD + 1.0
	return weights


## `depth` stops an Add card effect whose card adds itself from scoring forever.
static func card_score(card: CardData, weights: Dictionary, depth: int = 0) -> float:
	if card.dormant:
		return DORMANT_SCORE
	var total := 0.0
	var forgotten: int = weights.get("forgotten", TYPICAL_FORGOTTEN)
	for effect in card.effects:
		total += effect_score(card, effect, weights, forgotten, depth)
	# An Oath's effects keep firing for the rest of the fight: a typical number of turns' worth.
	if card.oath:
		for effect in card.oath_effects:
			total += effect_score(card, effect, weights, forgotten, depth) * (TYPICAL_REMAINING_TURNS + 1) * float(OATH_FIRING_SHARE[card.oath_trigger]) * OATH_DECK_DISCOUNT
	for effect in card.discard_effects:
		total += effect_score(card, effect, weights, forgotten, depth) * DISCARD_EFFECT_SHARE
	# A Surge spends all its energy, so it is divided by a typical amount rather than its cost of 0.
	return total / ((TYPICAL_SURGE_ENERGY if card.surge else card.cost) + 1)


## Deck-scoring value of one effect of `card` (before the card's cost divides the total).
static func effect_score(card: CardData, effect: CardEffect, weights: Dictionary, forgotten: int, depth: int) -> float:
	var total := 0.0
	var nominal := nominal_damage(effect, forgotten)
	if nominal > 0.0:
		var spread := ALL_ENEMIES_SPREAD if card.target_mode == CardData.TargetMode.ALL_ENEMIES else 1.0
		return nominal * weights["damage"] * spread
	var amount := effect.amount
	if effect.per_energy:
		amount *= TYPICAL_SURGE_ENERGY
	match effect.kind:
		CardEffect.Kind.BLOCK:
			total += amount * weights["block"]
		CardEffect.Kind.DRAW:
			total += amount * DRAW_VALUE
		CardEffect.Kind.EXPOSE:
			total += amount * EXPOSE_VALUE
		CardEffect.Kind.HOLD:
			total += amount * DECK_HOLD_VALUE
		CardEffect.Kind.THORNS:
			total += amount * DECK_THORNS_VALUE
		CardEffect.Kind.GAIN_ENERGY:
			total += amount * DECK_ENERGY_VALUE
		CardEffect.Kind.LOSE_HP:
			total -= amount * DECK_LOSE_HP_COST
		CardEffect.Kind.HEAL_PER_HAUNTED:
			total += amount * HEAL_VALUE
		CardEffect.Kind.MALICE, CardEffect.Kind.WARD:
			total += _stack_score(card, effect, weights)
		CardEffect.Kind.SHAKEN, CardEffect.Kind.FRAYED:
			total += _debuff_score(card, effect)
		CardEffect.Kind.GLIMPSE:
			total += amount * GLIMPSE_SCORE_PER_CARD
		CardEffect.Kind.SCENT:
			total += amount * SCENT_SCORE_PER_POINT
		CardEffect.Kind.RECALL:
			total += amount * float(weights.get("recall", RECALL_SCORE_PER_CARD))
		CardEffect.Kind.ADD_CARD:
			total += _added_score(effect, weights, depth)
		CardEffect.Kind.FILE:
			total += amount * FILE_SCORE_PER_CARD
		CardEffect.Kind.CROSS_OUT:
			total -= amount * FILE_SCORE_PER_CARD * 2.0 # an enemy's tool: losing a card is worse than filing it
		_:
			# Damage kinds (and Haunt) were priced above by nominal_damage; a zero-damage one lands here.
			if not effect.is_damage() and effect.kind != CardEffect.Kind.HAUNT:
				SimPolicy.bot_error("SmartCardScore.effect_score: no valuation for CardEffect.Kind %d" % effect.kind)
	return total


## Deck-scoring value of an Add card effect: a Dormant card is a cost, any other card a share of its
## value by pile (the same shares as in a fight; a card added to hand counts as playable).
static func _added_score(effect: CardEffect, weights: Dictionary, depth: int) -> float:
	if effect.card == null or depth > 0:
		return 0.0
	if effect.card.dormant:
		return -DORMANT_ADD_COST * effect.amount
	var share := DISCARD_ADD_SHARE
	match effect.pile:
		CardEffect.Pile.HAND:
			share = HAND_PLAYABLE_SHARE
		CardEffect.Pile.DRAW:
			share = DRAW_ADD_SHARE
	var inner := maxf(card_score(effect.card, weights, depth + 1), 0.0) * (effect.card.cost + 1) * share
	return effect.amount * inner


## Deck-scoring value of a Malice / Ward effect: a positive stack for the user is worth its amount on
## TYPICAL_HITS_PER_TURN hits (or Block effects) a turn, for this turn only when temporary, else the
## fight's typical remaining turns too; a negative one on an enemy is worth the damage it cuts from one
## attack a turn (Malice) or half that (Ward, only matters against Block), and nothing when temporary.
static func _stack_score(card: CardData, effect: CardEffect, weights: Dictionary) -> float:
	var is_malice := effect.kind == CardEffect.Kind.MALICE
	if effect.amount >= 0:
		var turns := 1 if effect.temporary else TYPICAL_REMAINING_TURNS + 1
		var weight: float = weights["damage"] if is_malice else weights["block"]
		return effect.amount * TYPICAL_HITS_PER_TURN * turns * (MALICE_VALUE if is_malice else WARD_VALUE) * weight
	if effect.temporary:
		return 0.0
	var cut := float(-effect.amount) * (TYPICAL_REMAINING_TURNS + 1)
	return cut * PREVENTED_VALUE_COVERED * (MALICE_CUT_FACTOR if is_malice else 1.0)


## Deck-scoring value of a Shaken / Frayed effect: on enemies, SHAKEN_TURNS_CAP turns of a quarter of a
## typical TYPICAL_ENEMY_HIT (Frayed: of a typical Block); on the player a cost.
static func _debuff_score(card: CardData, effect: CardEffect) -> float:
	var shaken := effect.kind == CardEffect.Kind.SHAKEN
	if card.target_mode == CardData.TargetMode.SELF:
		return -(SELF_SHAKEN_COST if shaken else SELF_FRAYED_COST) * effect.amount
	var turns := mini(effect.amount, SHAKEN_TURNS_CAP)
	if shaken:
		return turns * DEBUFF_HIT_SHARE * TYPICAL_ENEMY_HIT * PREVENTED_VALUE_COVERED * SHAKEN_PREVENTED_FACTOR
	return turns * DEBUFF_HIT_SHARE * TYPICAL_BLOCK * ENEMY_BLOCK_VALUE * FRAYED_BLOCK_FACTOR


## Rough damage an effect is worth in a deck-scoring context (a typical Block, Haunt or number of
## earlier plays stands in for the state a real fight would supply). 0 for non-damage effects.
static func nominal_damage(effect: CardEffect, forgotten: int = TYPICAL_FORGOTTEN) -> float:
	return nominal_damage_once(effect, forgotten) * float(effect.hit_count(TYPICAL_SURGE_ENERGY))


static func nominal_damage_once(effect: CardEffect, forgotten: int) -> float:
	match effect.kind:
		CardEffect.Kind.DAMAGE:
			return float(effect.amount)
		CardEffect.Kind.DAMAGE_PER_BLOCK:
			return float(TYPICAL_BLOCK * effect.amount)
		CardEffect.Kind.DAMAGE_IF_BLOCK:
			return (effect.amount + effect.bonus) / 2.0
		CardEffect.Kind.DAMAGE_PER_PLAY:
			return float(effect.amount + PER_PLAY_TYPICAL_PLAYS * effect.bonus)
		CardEffect.Kind.DAMAGE_PER_HAUNT:
			return float(TYPICAL_HAUNT * effect.amount)
		CardEffect.Kind.DAMAGE_PER_FORGOTTEN:
			return float(forgotten * effect.amount)
		CardEffect.Kind.DAMAGE_PER_SCENT:
			return float(effect.amount + effect.bonus * TYPICAL_SCENT)
		CardEffect.Kind.HAUNT:
			return HAUNT_VALUE * haunt_total(effect.amount)
	# Every other kind is no damage at all; a new damage kind must be priced above.
	if effect.is_damage():
		SimPolicy.bot_error("SmartCardScore.nominal_damage_once: no estimate for damage CardEffect.Kind %d" % effect.kind)
	return 0.0


## Total damage of a Haunt of `amount` over its life: amount + (amount - 1) + ... + 1.
static func haunt_total(amount: int) -> int:
	return maxi(amount, 0) * (maxi(amount, 0) + 1) / 2


static func average_score(deck: Array[CardData], weights: Dictionary) -> float:
	if deck.is_empty():
		return 0.0
	var total := 0.0
	for card in deck:
		total += card_score(card, weights)
	return total / deck.size()
