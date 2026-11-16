class_name CombatChoices
extends RefCounted
## The Glimpse / Recall pick steps of a fight (owned by Combat, which keeps the public API: has_choice, choice_cards,
## resolve_choice and the rest delegate here, and Combat owns the phase). A played card queues its picks in effect
## order; they open one after another once the whole card has resolved. A Draw that comes after a pick on the same
## card waits in the same queue, so it draws what the pick left on top (Glimpse 3, Draw 1 draws the leftmost kept card).


## The open pick step while Combat.phase == CHOOSING. Built when it opens, so a second GLIMPSE sees the draw pile as
## the first one left it.
class Choice extends RefCounted:
	## CardEffect.Kind.GLIMPSE or CardEffect.Kind.RECALL.
	var kind: CardEffect.Kind = CardEffect.Kind.GLIMPSE
	## What may be picked. GLIMPSE: the top cards of the draw pile in draw order (indices match
	## CardPiles.top_cards). RECALL: the whole Forgotten pile (indices match CardPiles.forgotten).
	var cards: Array[CardData] = []
	## Fewest picks that resolve it (0 for GLIMPSE; min(n, Forgotten size) for RECALL) and the most.
	var required := 0
	var max_picks := 0


## A pick step queued by the card being played, not yet opened (it becomes a Choice when it opens), or a
## Draw that came after one and waits for it (DRAW: it draws when its turn in the queue comes).
class PendingChoice extends RefCounted:
	## CardEffect.Kind.GLIMPSE, CardEffect.Kind.RECALL or CardEffect.Kind.DRAW.
	var kind: CardEffect.Kind = CardEffect.Kind.GLIMPSE
	## The effect's amount: cards to look at (GLIMPSE), to pick (RECALL) or to draw (DRAW).
	var amount := 0

	func _init(p_kind: CardEffect.Kind, p_amount: int) -> void:
		kind = p_kind
		amount = p_amount


var _queue: Array[PendingChoice] = []
var _open: Choice = null


## Forgets every queued and open step (the fight ended or was abandoned).
func clear() -> void:
	_queue.clear()
	_open = null


## Queues a GLIMPSE or RECALL of `amount` (it opens after the card resolves).
func queue_pick(kind: CardEffect.Kind, amount: int) -> void:
	_queue.append(PendingChoice.new(kind, amount))


## A Draw of `amount`: queued behind a pick of the same card if one is waiting (true), else false and the caller draws now.
func queue_draw_if_waiting(amount: int) -> bool:
	if _queue.is_empty():
		return false
	_queue.append(PendingChoice.new(CardEffect.Kind.DRAW, amount))
	return true


## Opens the next queued step that has something to pick (GLIMPSE needs a non-empty draw pile, RECALL a non-empty
## Forgotten pile; otherwise it is skipped) and returns true; queued Draws on the way draw from `piles`. False if
## nothing opened (the queue is empty).
func open_next(piles: CardPiles, hand_max: int) -> bool:
	while not _queue.is_empty():
		var entry: PendingChoice = _queue.pop_front()
		if entry.kind == CardEffect.Kind.DRAW:
			piles.draw(entry.amount, hand_max)
			continue
		var choice := Choice.new()
		choice.kind = entry.kind
		if choice.kind == CardEffect.Kind.GLIMPSE:
			choice.cards = piles.top_cards(entry.amount)
			choice.required = 0
		else:
			choice.cards = piles.forgotten.duplicate()
			choice.required = mini(entry.amount, choice.cards.size())
		choice.max_picks = choice.cards.size() if choice.kind == CardEffect.Kind.GLIMPSE else choice.required
		if choice.cards.is_empty():
			continue
		_open = choice
		return true
	return false


## True while a pick is open.
func is_open() -> bool:
	return _open != null


func cards() -> Array[CardData]:
	return _open.cards if _open != null else []


func kind() -> CardEffect.Kind:
	return _open.kind if _open != null else CardEffect.Kind.GLIMPSE


func required() -> int:
	return _open.required if _open != null else 0


func max_picks() -> int:
	return _open.max_picks if _open != null else 0


## True if `indices` are unique, in range of cards(), and between required() and max_picks().
func can_resolve(indices: Array[int]) -> bool:
	if _open == null:
		return false
	if indices.size() < _open.required or indices.size() > _open.max_picks:
		return false
	var seen := {}
	for i in indices:
		if i < 0 or i >= _open.cards.size() or seen.has(i):
			return false
		seen[i] = true
	return true


## Applies valid picks to `piles` and closes the open step: Glimpse discards the picked cards (in the order given)
## from the draw pile top; Recall moves the picked Forgotten cards to the hand (to discard if it is full).
func resolve(indices: Array[int], piles: CardPiles, hand_max: int) -> void:
	if _open.kind == CardEffect.Kind.GLIMPSE:
		piles.discard_from_draw_top(indices)
	else:
		piles.recall_from_forgotten(indices, hand_max)
	_open = null


## The least-effort legal picks for the open step (Glimpse discards nothing; Recall takes the first required cards).
func default_picks() -> Array[int]:
	var picks: Array[int] = []
	if _open != null and _open.kind == CardEffect.Kind.RECALL:
		for i in _open.required:
			picks.append(i)
	return picks
