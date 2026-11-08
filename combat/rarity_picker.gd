class_name RarityPicker
extends RefCounted
## The rarity odds per run tier and the weighted pick of reward / vendor cards (StarterContent forwards here).


## Odds (Common, Uncommon, Rare, in percent) of each card slot in a reward or vendor stock, by how far into the
## run it is: four tiers, from the first quarter of the stop line to the last.
const RARITY_WEIGHTS: Array[Array] = [[70, 27, 3], [62, 32, 6], [52, 38, 10], [42, 42, 16]]


## The weights for `tier` (clamped to the table).
static func rarity_weights(tier: int) -> Array[int]:
	var row: Array = RARITY_WEIGHTS[clampi(tier, 0, RARITY_WEIGHTS.size() - 1)]
	var weights: Array[int] = []
	weights.assign(row)
	return weights


## Picks up to `count` distinct cards from `pool`, one at a time: roll a rarity from `weights` (only among the
## rarities that still have a card), then a random card of that rarity. Uses `rng`, so a seed repeats the picks.
## The pool is not changed. Fewer than `count` come back only when the pool is smaller.
static func pick_by_rarity(pool: Array[CardData], count: int, weights: Array[int], rng: RandomNumberGenerator) -> Array[CardData]:
	# A card whose rarity is outside CardData.Rarity can never be rolled (ContentRegistry refuses to load one).
	var left: Array[CardData] = []
	for card in pool:
		if ContentRegistry.has_valid_rarity(card):
			left.append(card)
	var picks: Array[CardData] = []
	while picks.size() < count and not left.is_empty():
		var total := 0
		for rarity in 3:
			if _has_rarity(left, rarity):
				total += maxi(weights[rarity], 1)
		var roll := rng.randi_range(0, total - 1)
		var chosen := CardData.Rarity.COMMON
		for rarity in 3:
			if not _has_rarity(left, rarity):
				continue
			var share := maxi(weights[rarity], 1)
			if roll < share:
				chosen = rarity as CardData.Rarity
				break
			roll -= share
		var of_rarity: Array[CardData] = []
		for card in left:
			if card.rarity == chosen:
				of_rarity.append(card)
		var card: CardData = of_rarity[rng.randi_range(0, of_rarity.size() - 1)]
		picks.append(card)
		left.erase(card)
	return picks


static func _has_rarity(cards: Array[CardData], rarity: int) -> bool:
	for card in cards:
		if card.rarity == rarity:
			return true
	return false
