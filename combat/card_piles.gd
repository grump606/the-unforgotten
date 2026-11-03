class_name CardPiles
extends RefCounted
## Draw pile, hand and discard pile. Shuffling uses the injected RNG so fights
## are reproducible from a seed.

var draw_pile: Array[CardData] = []
var hand: Array[CardData] = []
var discard_pile: Array[CardData] = []

var _rng: RandomNumberGenerator


func _init(deck: Array[CardData], rng: RandomNumberGenerator) -> void:
	_rng = rng
	draw_pile.append_array(deck)
	_shuffle(draw_pile)


## Draws up to `count` cards, reshuffling the discard pile when needed. With `hand_limit` >= 0 it
## stops once the hand holds that many cards (the rest stay in the draw pile, and the discard pile
## is not reshuffled for cards that would not fit). Returns how many were actually drawn.
func draw(count: int, hand_limit: int = -1) -> int:
	var drawn := 0
	while drawn < count:
		if hand_limit >= 0 and hand.size() >= hand_limit:
			break
		if draw_pile.is_empty():
			if discard_pile.is_empty():
				break
			draw_pile.append_array(discard_pile)
			discard_pile.clear()
			_shuffle(draw_pile)
		hand.append(draw_pile.pop_back())
		drawn += 1
	return drawn


## Moves the card at `hand_index` to the discard pile and returns it.
func play(hand_index: int) -> CardData:
	var card: CardData = hand[hand_index]
	hand.remove_at(hand_index)
	discard_pile.append(card)
	return card


## Moves the hand cards at `hand_indices` (valid, unique) to the discard pile, in hand order.
func discard_cards(hand_indices: Array[int]) -> void:
	var sorted := hand_indices.duplicate()
	sorted.sort()
	for i in sorted:
		discard_pile.append(hand[i])
	for k in range(sorted.size() - 1, -1, -1):
		hand.remove_at(sorted[k])


func discard_hand() -> void:
	discard_pile.append_array(hand)
	hand.clear()


func _shuffle(cards: Array[CardData]) -> void:
	for i in range(cards.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp := cards[i]
		cards[i] = cards[j]
		cards[j] = tmp
