class_name CardPiles
extends RefCounted
## Draw pile, hand and discard pile. Shuffling uses the injected RNG so fights
## are reproducible from a seed.

var draw_pile: Array[CardData] = []
var hand: Array[CardData] = []
var discard_pile: Array[CardData] = []
## Cards removed for the rest of the fight (Forgotten). The deck is never modified, so they are
## back next fight.
var forgotten: Array[CardData] = []
## Oaths played this fight (Sworn), in the order they were sworn. They stay for the fight and, like the
## Forgotten pile, are back in the deck next fight. Sworn twice, a card is listed twice and fires twice.
var sworn: Array[CardData] = []

## Where play() last sent a card. An Oath is Sworn even when it is also Forgotten, so a card's
## `forgotten` flag alone does not say it landed in the Forgotten pile.
enum Destination { DISCARD, FORGOTTEN, SWORN }
var last_play_destination: Destination = Destination.DISCARD

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


## Moves the draw pile's Ready cards into the hand (from the top of the pile down, stopping at
## `hand_limit` cards in hand). Returns how many moved. Meant to run before the normal turn-1 draw.
func draw_ready(hand_limit: int) -> int:
	var moved := 0
	var i := draw_pile.size() - 1
	while i >= 0 and hand.size() < hand_limit:
		if draw_pile[i].ready:
			hand.append(draw_pile[i])
			draw_pile.remove_at(i)
			moved += 1
		i -= 1
	return moved


## Moves the card at `hand_index` to the discard pile (the Forgotten pile for a Forgotten card, the Sworn
## list for an Oath) and returns it.
func play(hand_index: int) -> CardData:
	var card: CardData = hand[hand_index]
	hand.remove_at(hand_index)
	if card.oath:
		sworn.append(card)
		last_play_destination = Destination.SWORN
	elif card.forgotten:
		forgotten.append(card)
		last_play_destination = Destination.FORGOTTEN
	else:
		discard_pile.append(card)
		last_play_destination = Destination.DISCARD
	return card


## Moves every Fading card still in hand to the Forgotten pile. Returns how many moved.
func forget_fading_in_hand() -> int:
	var moved := 0
	for k in range(hand.size() - 1, -1, -1):
		if hand[k].fading:
			forgotten.append(hand[k])
			hand.remove_at(k)
			moved += 1
	return moved


## Hand cards that count toward the 5 kept: everything except Anchor and Fading cards.
func counted_in_hand() -> int:
	var n := 0
	for card in hand:
		if not card.anchor and not card.fading:
			n += 1
	return n


## Moves the hand cards at `hand_indices` (valid, unique) to the discard pile, in hand order.
func discard_cards(hand_indices: Array[int]) -> void:
	var sorted := hand_indices.duplicate()
	sorted.sort()
	for i in sorted:
		discard_pile.append(hand[i])
	for k in range(sorted.size() - 1, -1, -1):
		hand.remove_at(sorted[k])


## Adds a created card (fight-only: the deck array handed to _init is never touched) to `pile` and
## returns where it actually went. HAND falls back to the discard pile when the hand already holds
## `hand_limit` cards (-1 = no limit). DRAW inserts at a random position drawn from the seeded RNG
## (never predictably on top or bottom). A null card changes nothing.
func add_card(card: CardData, pile: CardEffect.Pile, hand_limit: int = -1) -> CardEffect.Pile:
	if card == null:
		return pile
	match pile:
		CardEffect.Pile.HAND:
			if hand_limit >= 0 and hand.size() >= hand_limit:
				discard_pile.append(card)
				return CardEffect.Pile.DISCARD
			hand.append(card)
		CardEffect.Pile.DRAW:
			# Position 0 is the bottom, draw_pile.size() the top.
			draw_pile.insert(_rng.randi_range(0, draw_pile.size()), card)
		CardEffect.Pile.DISCARD:
			discard_pile.append(card)
	return pile


## Files up to `count` cards from the hand: each goes to the BOTTOM of the draw pile (the start of the array) and
## leaves the hand. The most expensive card goes first, the leftmost of equals; an Anchored card is never filed
## (it cannot be discarded either). Returns how many were filed. The draw pile is not reshuffled: a filed card is
## simply a long way from being drawn again.
func file_from_hand(count: int) -> int:
	var filed := 0
	for _n in maxi(count, 0):
		var pick := -1
		for i in hand.size():
			if hand[i].anchor:
				continue
			if pick == -1 or hand[i].cost > hand[pick].cost:
				pick = i
		if pick == -1:
			break
		draw_pile.insert(0, hand[pick])
		hand.remove_at(pick)
		filed += 1
	return filed


## Crosses out up to `count` cards from the hand: each goes to the Forgotten pile, the dearest first (as file_from_hand);
## an Anchored card stays. Returns how many were crossed out.
func cross_out_from_hand(count: int) -> int:
	var crossed := 0
	for _n in maxi(count, 0):
		var pick := -1
		for i in hand.size():
			if hand[i].anchor:
				continue
			if pick == -1 or hand[i].cost > hand[pick].cost:
				pick = i
		if pick == -1:
			break
		forgotten.append(hand[pick])
		hand.remove_at(pick)
		crossed += 1
	return crossed


## The top `n` cards of the draw pile in the order they would be drawn (index 0 is drawn first; the
## top of the pile is the END of the array). Looks only at what is there: never reshuffles.
func top_cards(n: int) -> Array[CardData]:
	var cards: Array[CardData] = []
	var i := draw_pile.size() - 1
	while i >= 0 and cards.size() < n:
		cards.append(draw_pile[i])
		i -= 1
	return cards


## Discards the cards at `indices` of top_cards() (valid, unique) to the discard pile in the order
## given. The cards left on top keep their order.
func discard_from_draw_top(indices: Array[int]) -> void:
	var pile_indices: Array[int] = []
	for i in indices:
		var at := draw_pile.size() - 1 - i
		discard_pile.append(draw_pile[at])
		pile_indices.append(at)
	pile_indices.sort()
	for k in range(pile_indices.size() - 1, -1, -1):
		draw_pile.remove_at(pile_indices[k])


## Moves the Forgotten cards at `indices` (valid, unique) to the hand in the order given, or to the
## discard pile once the hand holds `hand_limit` cards. Returns how many moved.
func recall_from_forgotten(indices: Array[int], hand_limit: int) -> int:
	var moving: Array[CardData] = []
	for i in indices:
		moving.append(forgotten[i])
	var sorted := indices.duplicate()
	sorted.sort()
	for k in range(sorted.size() - 1, -1, -1):
		forgotten.remove_at(sorted[k])
	for card in moving:
		if hand_limit >= 0 and hand.size() >= hand_limit:
			discard_pile.append(card)
		else:
			hand.append(card)
	return moving.size()


func _shuffle(cards: Array[CardData]) -> void:
	for i in range(cards.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp := cards[i]
		cards[i] = cards[j]
		cards[j] = tmp
