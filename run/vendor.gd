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


## Gold awarded for winning a fight against `enemy_count` enemies.
## Fails loudly (and awards nothing) for a count below 1.
static func gold_for_win(enemy_count: int) -> int:
	if enemy_count < 1:
		push_error("Vendor.gold_for_win: enemy_count must be >= 1, got %d" % enemy_count)
		return 0
	return enemy_count * GOLD_PER_ENEMY + GOLD_WIN_BONUS


## Value of a kind with no valuation; effect_value returns this so the every-kind test can catch it.
const UNVALUED := -999999

## Raw strength of a card: 2 per energy of cost plus the value of each effect (effect_value).
static func card_value(card: CardData) -> int:
	var value := card.cost * 2
	for effect in card.effects:
		var effect_points := effect_value(effect)
		if effect_points == UNVALUED:
			push_error("Vendor.card_value: no valuation for CardEffect kind %d" % effect.kind)
			continue
		value += effect_points
	return value


## Deliberate value of one effect, in the same points as damage (1 per point). Scaling
## kinds assume a typical board: about 5 Block held, a card or two played earlier in the
## turn, a Haunt of about 4. Every CardEffect.Kind needs a branch here (a test enforces it).
static func effect_value(effect: CardEffect) -> int:
	var amount := effect.amount
	match effect.kind:
		CardEffect.Kind.DAMAGE, CardEffect.Kind.BLOCK, CardEffect.Kind.HOLD:
			return amount
		CardEffect.Kind.EXPOSE:
			return amount * 2
		CardEffect.Kind.DRAW:
			return amount * DRAW_VALUE
		CardEffect.Kind.DAMAGE_PER_BLOCK:
			return amount * 5
		CardEffect.Kind.DAMAGE_IF_BLOCK:
			return (amount + effect.bonus) / 2
		CardEffect.Kind.THORNS:
			return amount * 2
		CardEffect.Kind.GAIN_ENERGY:
			return amount * ENERGY_VALUE
		CardEffect.Kind.DAMAGE_PER_PLAY:
			return amount + effect.bonus * 2
		CardEffect.Kind.HAUNT:
			# Total damage over its decay: amount + (amount - 1) + ... + 1.
			return amount * (amount + 1) / 2
		CardEffect.Kind.LOSE_HP:
			return -amount
		CardEffect.Kind.HEAL_PER_HAUNTED:
			return amount * 2
		CardEffect.Kind.DAMAGE_PER_HAUNT:
			return amount * 4
	return UNVALUED


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
func _init(deck: Array[CardData], rng: RandomNumberGenerator, starting_gold: int, card_pool: Array[CardData] = [], relic_pool: Array[RelicData] = [], wallet: Wallet = null) -> void:
	_deck = deck
	if wallet != null:
		_wallet = wallet  # shared: `starting_gold` is ignored
	else:
		if starting_gold < 0:
			push_error("Vendor: starting gold must be >= 0, got %d" % starting_gold)
		_wallet = Wallet.new(maxi(starting_gold, 0))
	if rng == null:
		push_error("Vendor: rng is required")
		return
	# Distinct card types by id, in deck order, then a seeded Fisher-Yates shuffle.
	var pool: Array[CardData] = []
	var seen := {}
	for card in (card_pool if not card_pool.is_empty() else StarterContent.all_cards()):
		if not seen.has(card.id):
			seen[card.id] = true
			pool.append(card)
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	for i in mini(STOCK_CARDS, pool.size()):
		_offers.append({"card": pool[i], "price": card_price(pool[i]), "sold": false})
	if _offers.size() < STOCK_CARDS:
		push_error("Vendor: could only stock %d of %d cards" % [_offers.size(), STOCK_CARDS])
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
		push_error("Vendor.buy_card: bad offer index %d" % index)
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
		push_error("Vendor.buy_relic: player is required")
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
		push_error("Vendor.remove_card: bad deck index %d" % deck_index)
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
		push_error("Vendor.buy_heal: player is required")
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
