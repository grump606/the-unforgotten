class_name Vendor
extends RefCounted
## One vendor visit: three cards for sale, at most one relic, plus two fixed services
## (remove a card, heal). Pure logic, no nodes, no RunState dependency.
##
## Wiring: `var vendor := Vendor.new(run_deck, run_rng, run_gold)`. The Vendor
## MUTATES `run_deck` (the exact array passed in) on buy_card/remove_card, and
## spends gold from a Wallet. Standalone it makes its own from `starting_gold`; a run passes
## its own wallet, so the run's gold and the vendor's gold are the same number (one owner).
## Every purchase returns a Result (`ok`, `reason`, and what
## changed); a failed purchase changes nothing and gold never goes negative.
## Caller bugs (bad index, null player) also push_error; "cannot afford" and
## "already sold" are normal outcomes and only return a failed Result.

## Gold economy (placeholder numbers for tuning).
## Gold earned per enemy defeated in a won fight.
const GOLD_PER_ENEMY := 8
## Flat bonus for winning a fight, on top of the per-enemy gold.
const GOLD_WIN_BONUS := 5

const STOCK_CARDS := 3
const REMOVE_CARD_PRICE := 15
const HEAL_PRICE := 12
const HEAL_AMOUNT := 12

## Card price tiers (see card_price).
const PRICE_CHEAP := 10
const PRICE_MID := 16
const PRICE_PRICEY := 24
## Card value below MID_FROM is cheap; at or above PRICEY_FROM is pricey; else mid.
const MID_FROM := 6
const PRICEY_FROM := 12
## How much one drawn card adds to a card's value.
const DRAW_VALUE := 4
## How much one point of energy gained adds.
const ENERGY_VALUE := 4
## A per_energy (Surge) effect is valued as if this much energy were spent on it.
const SURGE_TYPICAL_ENERGY := 2
## Keyword adjustments added to a card's value (see card_value). Kept small so a keyword shifts a
## price tier only at the margin; Dormant is large enough to make a card junk whatever its effects.
## Forgotten: the card is gone for the rest of the fight after one play, so it is worth less.
const FORGOTTEN_ADJUST := -3
## Fading: it must be played the turn it is drawn or it is lost, a small drawback.
const FADING_ADJUST := -1
## Ready: it opens the first hand every fight, a small bonus.
const READY_ADJUST := 1
## Anchor: it stays in hand and never costs a kept slot, a small bonus.
const ANCHOR_ADJUST := 1
## Dormant: it cannot be played at all, so it is effectively junk.
const DORMANT_ADJUST := -20
## Surge: takes any energy left over, so it is flexible; a small bonus.
const SURGE_ADJUST := 1
## Shaken and Frayed are worth a little less per turn than Expose (which boosts all damage by half).
const SHAKEN_VALUE_PER_TURN := 2
const FRAYED_VALUE_PER_TURN := 1
## A Malice or Ward stack lasts the fight, so one point is worth several; a temporary stack lasts
## one turn and is worth about a third of that. A negative amount (a debuff on enemies) is valued
## the same way as a positive one.
const MALICE_VALUE_PER_STACK := 6
const WARD_VALUE_PER_STACK := 5
const TEMPORARY_STACK_VALUE_PER_STACK := 2
## Glimpse: each card looked at is a small chance to bin a dud. Recall: a Forgotten card back in hand
## is about a drawn card less the Forgotten cost. Damage per Forgotten card assumes a typical pile of 2.
const GLIMPSE_VALUE_PER_CARD := 1
const RECALL_VALUE_PER_CARD := 3
const TYPICAL_FORGOTTEN := 2
## Scent: a point of it is worth about two points of damage over the hits that follow; a spender assumes a stack of 3.
const SCENT_VALUE_PER_POINT := 2
## A played File card tucks cards away (it is an enemy's tool in the main); worth a little as deck cycling.
const FILE_VALUE_PER_CARD := 1
const TYPICAL_SCENT := 3
## An Oath is worth its effect this many times: about how often a trigger fires in a fight.
const OATH_FIRINGS := 3
## A card's discard effects are worth this fraction (1 over the divisor) of the same effects played.
const DISCARD_VALUE_DIVISOR := 2
## Per point of effect: Expose, Thorns and a Heal per Haunted enemy are worth EXPOSE_VALUE_PER_TURN, THORNS_VALUE_PER_POINT
## and HEAL_PER_HAUNTED_VALUE; damage equal to Block is valued at a typical Block (TYPICAL_BLOCK), damage per Haunt at a
## typical Haunt (TYPICAL_HAUNT), and a per-play bonus at TYPICAL_EARLIER_PLAYS earlier cards.
const EXPOSE_VALUE_PER_TURN := 2
const THORNS_VALUE_PER_POINT := 2
const HEAL_PER_HAUNTED_VALUE := 2
const TYPICAL_BLOCK := 5
const TYPICAL_HAUNT := 4
const TYPICAL_EARLIER_PLAYS := 2


## Gold awarded for winning a fight against `enemy_count` enemies.
## Fails loudly (and awards nothing) for a count below 1.
static func gold_for_win(enemy_count: int) -> int:
	if enemy_count < 1:
		Combat.engine_error("Vendor.gold_for_win: enemy_count must be >= 1, got %d" % enemy_count)
		return 0
	return enemy_count * GOLD_PER_ENEMY + GOLD_WIN_BONUS


## Value of a kind with no valuation; effect_value returns this so the every-kind test can catch it.
const UNVALUED := -999999

## Raw strength of a card: 2 per energy of cost plus the value of each effect (effect_value).
static func card_value(card: CardData, added_depth: int = 0) -> int:
	var value := card.cost * 2
	if card.forgotten:
		value += FORGOTTEN_ADJUST
	if card.fading:
		value += FADING_ADJUST
	if card.ready:
		value += READY_ADJUST
	if card.anchor:
		value += ANCHOR_ADJUST
	if card.dormant:
		value += DORMANT_ADJUST
	if card.surge:
		value += SURGE_ADJUST
	for effect in card.effects:
		var effect_points := effect_value(effect, added_depth)
		if effect_points == UNVALUED:
			Combat.engine_error("Vendor.card_value: no valuation for CardEffect kind %d" % effect.kind)
			continue
		value += effect_points
	# What a card does when thrown away at the end of the turn counts for half: it only fires if it is discarded.
	for effect in card.discard_effects:
		var discard_points := effect_value(effect, added_depth)
		if discard_points != UNVALUED:
			value += discard_points / DISCARD_VALUE_DIVISOR
	# An Oath's effects fire on a trigger for the rest of the fight, so they count several times.
	if card.oath:
		for effect in card.oath_effects:
			var oath_points := effect_value(effect, added_depth)
			if oath_points == UNVALUED:
				Combat.engine_error("Vendor.card_value: no valuation for oath CardEffect kind %d" % effect.kind)
				continue
			value += oath_points * OATH_FIRINGS
	return value


## Deliberate value of one effect, in the same points as damage (1 per point). Scaling
## kinds assume a typical board: about 5 Block held, a card or two played earlier in the
## turn, a Haunt of about 4. Every CardEffect.Kind needs a branch here (a test enforces it).
static func effect_value(effect: CardEffect, added_depth: int = 0) -> int:
	var amount := effect.amount
	# per_energy scales hits on a damage kind and the amount on any other kind, by a typical energy.
	var multiplier := 1
	if effect.per_energy:
		if effect.is_damage():
			multiplier = SURGE_TYPICAL_ENERGY
		else:
			amount *= SURGE_TYPICAL_ENERGY
	var points := _base_effect_value(effect, amount, added_depth)
	if points == UNVALUED:
		return UNVALUED
	if effect.is_damage():
		# Each hit lands separately (hits below 1 count as 1).
		return points * maxi(effect.hits, 1) * multiplier
	return points


static func _base_effect_value(effect: CardEffect, amount: int, added_depth: int) -> int:
	match effect.kind:
		CardEffect.Kind.DAMAGE, CardEffect.Kind.BLOCK, CardEffect.Kind.HOLD:
			return amount
		CardEffect.Kind.EXPOSE:
			return amount * EXPOSE_VALUE_PER_TURN
		CardEffect.Kind.DRAW:
			return amount * DRAW_VALUE
		CardEffect.Kind.DAMAGE_PER_BLOCK:
			return amount * TYPICAL_BLOCK
		CardEffect.Kind.DAMAGE_IF_BLOCK:
			return (amount + effect.bonus) / 2
		CardEffect.Kind.THORNS:
			return amount * THORNS_VALUE_PER_POINT
		CardEffect.Kind.GAIN_ENERGY:
			return amount * ENERGY_VALUE
		CardEffect.Kind.DAMAGE_PER_PLAY:
			return amount + effect.bonus * TYPICAL_EARLIER_PLAYS
		CardEffect.Kind.HAUNT:
			# Total damage over its decay: amount + (amount - 1) + ... + 1.
			return amount * (amount + 1) / 2
		CardEffect.Kind.LOSE_HP:
			return -amount
		CardEffect.Kind.HEAL_PER_HAUNTED:
			return amount * HEAL_PER_HAUNTED_VALUE
		CardEffect.Kind.DAMAGE_PER_HAUNT:
			return amount * TYPICAL_HAUNT
		CardEffect.Kind.SHAKEN:
			return amount * SHAKEN_VALUE_PER_TURN
		CardEffect.Kind.FRAYED:
			return amount * FRAYED_VALUE_PER_TURN
		CardEffect.Kind.MALICE, CardEffect.Kind.WARD:
			if effect.temporary:
				return absi(amount) * TEMPORARY_STACK_VALUE_PER_STACK
			return absi(amount) * (MALICE_VALUE_PER_STACK if effect.kind == CardEffect.Kind.MALICE else WARD_VALUE_PER_STACK)
		CardEffect.Kind.GLIMPSE:
			return amount * GLIMPSE_VALUE_PER_CARD
		CardEffect.Kind.RECALL:
			return amount * RECALL_VALUE_PER_CARD
		CardEffect.Kind.DAMAGE_PER_FORGOTTEN:
			return amount * TYPICAL_FORGOTTEN
		CardEffect.Kind.SCENT:
			return amount * SCENT_VALUE_PER_POINT
		CardEffect.Kind.DAMAGE_PER_SCENT:
			return amount + effect.bonus * TYPICAL_SCENT
		CardEffect.Kind.ADD_CARD:
			return amount * _added_card_value(effect.card, added_depth)
		CardEffect.Kind.FILE:
			return amount * FILE_VALUE_PER_CARD
	return UNVALUED


## Value of one copy of a created card: its own card_value, which is large and negative for a Dormant
## card (junk is a cost for whoever receives it, so a card adding one is worth less) and positive for a
## playable one. 0 for no card. Depth-limited so a card that adds itself cannot recurse forever.
## `added_depth` is how many created-card levels enclose this one (a parameter, so there is no shared state).
static func _added_card_value(card: CardData, added_depth: int) -> int:
	if card == null or added_depth >= 3:
		return 0
	return card_value(card, added_depth + 1)


## The single price rule: value < MID_FROM -> PRICE_CHEAP, value < PRICEY_FROM ->
## PRICE_MID, otherwise PRICE_PRICEY.
static func card_price(card: CardData) -> int:
	var value := card_value(card)
	if value < MID_FROM:
		return PRICE_CHEAP
	if value < PRICEY_FROM:
		return PRICE_MID
	return PRICE_PRICEY


## Outcome of a purchase attempt. On failure `reason` says why and nothing changed.
class Result extends RefCounted:
	var ok := false
	var reason := ""
	var spent := 0
	## buy_card: the card added to the deck. remove_card: the card removed.
	var card: CardData = null
	## buy_heal: HP the player actually regained.
	var healed := 0
	## buy_relic: the relic bought.
	var relic: RelicData = null

	static func fail(why: String) -> Result:
		var result := Result.new()
		result.reason = why
		return result


## A single gold balance that can be shared by reference (RunState and its Vendor).
class Wallet extends RefCounted:
	var gold := 0

	func _init(starting_gold: int = 0) -> void:
		gold = starting_gold


var _wallet: Wallet
## Remaining gold (lives in the wallet); never negative.
var gold: int:
	get:
		return _wallet.gold
	set(value):
		_wallet.gold = maxi(value, 0)
var _deck: Array[CardData]
var _offers: Array[Dictionary] = []  # {card: CardData, price: int, sold: bool}
var _relic_offer: Dictionary = {}  # {relic: RelicData, price: int, sold: bool}, empty when none is stocked
var _removed := false
var _healed := false


## `card_pool` is what the stock is drawn from (a character's pool); empty means every card.
## `relic_pool` is the relics that may be offered (the caller leaves out the ones already
## owned); one is picked after the card stock, and none is offered when it is empty.
func _init(deck: Array[CardData], rng: RandomNumberGenerator, starting_gold: int, card_pool: Array[CardData] = [], relic_pool: Array[RelicData] = [], wallet: Wallet = null, rarity_weights: Array[int] = []) -> void:
	_deck = deck
	if wallet != null:
		_wallet = wallet  # shared: `starting_gold` is ignored
	else:
		if starting_gold < 0:
			Combat.engine_error("Vendor: starting gold must be >= 0, got %d" % starting_gold)
		_wallet = Wallet.new(maxi(starting_gold, 0))
	if rng == null:
		Combat.engine_error("Vendor: rng is required")
		return
	# Distinct card types by id, in deck order, then a seeded Fisher-Yates shuffle.
	var pool: Array[CardData] = []
	var seen := {}
	for card in (card_pool if not card_pool.is_empty() else StarterContent.all_cards()):
		if not seen.has(card.id):
			seen[card.id] = true
			pool.append(card)
	# Each stock slot rolls a rarity, then a card of it (the same odds as a reward at this depth).
	for card in StarterContent.pick_by_rarity(pool, STOCK_CARDS, rarity_weights if not rarity_weights.is_empty() else StarterContent.rarity_weights(0), rng):
		_offers.append({"card": card, "price": card_price(card), "sold": false})
	if _offers.size() < STOCK_CARDS:
		Combat.engine_error("Vendor: could only stock %d of %d cards" % [_offers.size(), STOCK_CARDS])
	# After the card shuffle, so the card stock never depends on whether a relic is offered.
	if not relic_pool.is_empty():
		var relic := relic_pool[rng.randi_range(0, relic_pool.size() - 1)] if relic_pool.size() > 1 else relic_pool[0]
		_relic_offer = {"relic": relic, "price": relic.price, "sold": false}


## Cards for sale: copies of {card: CardData, price: int, sold: bool}, in display order.
func offers() -> Array[Dictionary]:
	var copy: Array[Dictionary] = []
	for offer in _offers:
		copy.append(offer.duplicate())
	return copy


## The relic for sale as a copy of {relic: RelicData, price: int, sold: bool}, or an empty
## dictionary when this visit has none.
func relic_offer() -> Dictionary:
	return _relic_offer.duplicate()


func has_removed() -> bool:
	return _removed


func has_healed() -> bool:
	return _healed


## Buys offer `index`: appends its card (shared immutable resource, like the
## starter deck) to the deck and deducts the price.
func buy_card(index: int) -> Result:
	if index < 0 or index >= _offers.size():
		Combat.engine_error("Vendor.buy_card: bad offer index %d" % index)
		return Result.fail("no such offer")
	var offer := _offers[index]
	if offer["sold"]:
		return Result.fail("already sold")
	var price: int = offer["price"]
	if gold < price:
		return Result.fail("not enough gold")
	gold -= price
	offer["sold"] = true
	_deck.append(offer["card"])
	var result := Result.new()
	result.ok = true
	result.spent = price
	result.card = offer["card"]
	return result


## Buys the relic and deducts its price. A MAX_HP relic raises `player`'s max HP and current
## HP here, once; the caller keeps the relic (Result.relic) for its other effects.
func buy_relic(player: Combatant) -> Result:
	if player == null:
		Combat.engine_error("Vendor.buy_relic: player is required")
		return Result.fail("no player")
	if _relic_offer.is_empty():
		return Result.fail("no relic for sale")
	if _relic_offer["sold"]:
		return Result.fail("already sold")
	var price: int = _relic_offer["price"]
	if gold < price:
		return Result.fail("not enough gold")
	gold -= price
	_relic_offer["sold"] = true
	var relic: RelicData = _relic_offer["relic"]
	if relic.kind == RelicData.Kind.MAX_HP:
		player.max_hp += relic.amount
		player.hp += relic.amount
		player.changed.emit()
	var result := Result.new()
	result.ok = true
	result.spent = price
	result.relic = relic
	return result


## Removes the card at `deck_index` of the deck. Once per visit; the last card
## can never be removed so the deck is never emptied.
func remove_card(deck_index: int) -> Result:
	if deck_index < 0 or deck_index >= _deck.size():
		Combat.engine_error("Vendor.remove_card: bad deck index %d" % deck_index)
		return Result.fail("no such card")
	if _removed:
		return Result.fail("already removed a card")
	if _deck.size() <= 1:
		return Result.fail("deck cannot be emptied")
	if gold < REMOVE_CARD_PRICE:
		return Result.fail("not enough gold")
	gold -= REMOVE_CARD_PRICE
	_removed = true
	var result := Result.new()
	result.ok = true
	result.spent = REMOVE_CARD_PRICE
	result.card = _deck[deck_index]
	_deck.remove_at(deck_index)
	return result


## Heals `player` by up to HEAL_AMOUNT (calls player.heal) and deducts HEAL_PRICE.
## Once per visit; refused at full HP so gold is not wasted. `healed` is the HP
## actually regained.
func buy_heal(player: Combatant) -> Result:
	if player == null:
		Combat.engine_error("Vendor.buy_heal: player is required")
		return Result.fail("no player")
	if _healed:
		return Result.fail("already healed")
	if player.hp >= player.max_hp:
		return Result.fail("already at full HP")
	if gold < HEAL_PRICE:
		return Result.fail("not enough gold")
	gold -= HEAL_PRICE
	_healed = true
	var result := Result.new()
	result.ok = true
	result.spent = HEAL_PRICE
	result.healed = player.heal(HEAL_AMOUNT)
	return result
