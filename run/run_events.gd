class_name RunEvents
extends RefCounted
## The state and rules of the "?" event stops (docs/EVENTS_DESIGN.md), owned by one RunState. The run is passed
## into each call rather than held, so there is no reference cycle. RunState keeps the public event API and delegates here.
## It uses only RunState's public surface (`advance_stop()` when leaving the stop). It rolls with the run RNG, which
## RunState hands over at construction (`_rng`, held here; the RNG holds nothing back, so still no cycle).

## A pick the player still owes after a choice: a REMOVE_CARD, REMEMBER_CARD or PICK_CARD effect.
class PendingPick extends RefCounted:
	var kind: EventEffect.Kind = EventEffect.Kind.REMOVE_CARD
	## PICK_CARD only: the cards on offer (stable until one is taken).
	var cards: Array[CardData] = []

	func _init(p_kind: EventEffect.Kind, p_cards: Array[CardData] = []) -> void:
		kind = p_kind
		cards = p_cards

## How an event button looks now (see `event_choice_state`).
class ChoiceState extends RefCounted:
	var label := ""
	## The printed cost and reward line made from the effects.
	var summary := ""
	var enabled := true
	## Why it is disabled ("" when enabled).
	var reason := ""

	func _init(p_label: String, p_summary: String, p_enabled: bool, p_reason: String) -> void:
		label = p_label
		summary = p_summary
		enabled = p_enabled
		reason = p_reason

	## Turns it off with a reason.
	func disable(why: String) -> void:
		enabled = false
		reason = why

## What pressing an event button did: the outcome text to show (the scene's reply plus a line per thing that
## happened) and the pick the player now owes, if any (see `event_followup`). RunState.EventResult names this class.
class EventResult:
	var ok := false
	var text := ""
	var followup: StringName = &""

	static func fail(why: String) -> EventResult:
		var result := EventResult.new()
		result.text = why
		return result

## The event of the current EVENT stop, rolled by `current_event` the first time it is asked for (null before that, off an
## event stop and when event content failed to load). Once rolled the stop is open: not a stop boundary.
var open_event: EventData = null
## Set once a choice of the open event was pressed: the outcome text, and the picks still owed to the player.
var resolved := false
var outcome := ""
var pending: Array[PendingPick] = []
## The run RNG (RunState's own, not a copy): every event roll draws from it, in the same order as the run's other draws.
var _rng: RandomNumberGenerator


func _init(rng: RandomNumberGenerator) -> void:
	_rng = rng


## The event of the current EVENT stop (null elsewhere, or if event content failed to load: the stop can then be
## passed with `finish_event`). It is rolled the first time it is asked for, from the run RNG, among the events not
## yet in `run.events_seen` (all of them again once every event was seen), so a run resumed from the save made on
## arrival rolls the same event. Asking again returns the same one. Rolling opens the stop: it is no longer a boundary.
func current_event(run: RunState) -> EventData:
	if not run.in_event_stop():
		return null
	if open_event != null:
		return open_event
	var all := StarterContent.events_for(run.chapter)
	if all.is_empty():
		return null
	var unseen: Array[EventData] = []
	for event in all:
		if not run.events_seen.has(event.id):
			unseen.append(event)
	if unseen.is_empty():
		run.events_seen.clear()
		unseen = all
	open_event = unseen[_rng.randi_range(0, unseen.size() - 1)]
	run.events_seen.append(open_event.id)
	return open_event


## The scene text of the open event for this character.
func event_body(run: RunState) -> String:
	var event := current_event(run)
	return event.body_for(run.character.id) if event != null else ""


## The buttons of the open event this character sees, in order (empty off an event stop).
func event_choices(run: RunState) -> Array[EventChoice]:
	var event := current_event(run)
	if event == null:
		var none: Array[EventChoice] = []
		return none
	return event.choices_for(run.character.id)


## How button `index` (a position in `event_choices(run)`) looks now (a ChoiceState). A gold payment the player cannot
## make, a card pick the deck cannot supply and a relic nothing is left to give each disable it; an HP cost never does
## (HP stops at 1). Everything is disabled once a choice was made.
func event_choice_state(run: RunState, index: int) -> ChoiceState:
	var choices := event_choices(run)
	if index < 0 or index >= choices.size():
		return ChoiceState.new("", "", false, "no such choice")
	var choice := choices[index]
	var state := ChoiceState.new(choice.label_for(run.character.id), _event_summary_with_fallback(run, choice.summary()), true, "")
	if resolved:
		state.disable("Already chosen.")
		return state
	if choice.gold_cost() > run.gold:
		state.disable("Needs %d gold (you have %d)." % [choice.gold_cost(), run.gold])
		return state
	for effect in choice.effects:
		var why := _event_blocked(run, effect)
		if why != "":
			state.disable(why)
			break
	return state


## A button's printed summary, with every relic gain whose pool has nothing left to give reworded to the gold it pays instead
## (RunState.EVENT_RELIC_FALLBACK_GOLD), so the text keeps promising exactly what the button does.
func _event_summary_with_fallback(run: RunState, summary: String) -> String:
	for pool in [EventEffect.Pool.NEUTRAL, EventEffect.Pool.CLASS, EventEffect.Pool.ANY]:
		if relic_candidates(run, pool).is_empty():
			summary = summary.replace(EventEffect.relic_text(pool), "Gain %d gold (no relics left to find)" % RunState.EVENT_RELIC_FALLBACK_GOLD)
	return summary


## Why a top-level effect cannot be done now ("" when it can).
func _event_blocked(run: RunState, effect: EventEffect) -> String:
	match effect.kind:
		EventEffect.Kind.REMOVE_CARD:
			if run.deck.size() <= 1:
				return "Your deck has only one card."
		EventEffect.Kind.REMEMBER_CARD:
			if run.rememberable_deck_indices().is_empty():
				return "No card in your deck can be remembered yet."
	return ""


## Presses button `index`: applies its effects (a gamble is rolled here with the run RNG) and returns what happened.
## Fails, changing nothing, off an event stop, for a bad index, a disabled button, or once a choice was made. Picks
## the effects owe (remove, Remember, choose a card) are queued: see `event_followup`.
func resolve_event_choice(run: RunState, index: int) -> EventResult:
	if current_event(run) == null:
		return EventResult.fail("no event")
	var state := event_choice_state(run, index)
	if not state.enabled:
		return EventResult.fail(state.reason)
	var choice := event_choices(run)[index]
	var lines: Array[String] = []
	var gambles: Array[bool] = []
	pending.clear()
	_apply_event_effects(run, choice.effects, lines, gambles)
	var text := choice.outcome_for(run.character.id)
	if not gambles.is_empty():
		var flavour := choice.win_outcome if gambles[0] else choice.lose_outcome
		if flavour != "":
			text += " " + flavour
	for line in lines:
		text += " " + line
	resolved = true
	outcome = text
	var result := EventResult.new()
	result.ok = true
	result.text = text
	result.followup = event_followup(run)
	return result


## Whether a button was pressed at the open event.
func event_resolved() -> bool:
	return resolved


## The outcome text of the choice made ("" before one is).
func event_outcome() -> String:
	return outcome


## The pick the player owes now: &"remove", &"remember" or &"pick" (choose 1 of the offered cards), or &"" when none.
func event_followup(run: RunState) -> StringName:
	_prune_event_pending(run)
	if pending.is_empty():
		return &""
	match pending[0].kind:
		EventEffect.Kind.REMOVE_CARD:
			return &"remove"
		EventEffect.Kind.REMEMBER_CARD:
			return &"remember"
	return &"pick"


## Drops every owed pick that can no longer be completed. The pick screens have no Cancel, so a pick nothing can
## satisfy (a removal when only one card is left, a Remember when no card can be remembered, as a second removal
## after the deck shrank or a nested removal can leave) would trap the player in a stop that is not a save boundary.
## A removal needs a card to spare, so only run.deck.size() - 1 removals stay owed.
func _prune_event_pending(run: RunState) -> void:
	var removals_left := run.deck.size() - 1
	var kept: Array[PendingPick] = []
	for entry in pending:
		match entry.kind:
			EventEffect.Kind.REMOVE_CARD:
				if removals_left <= 0:
					continue
				removals_left -= 1
			EventEffect.Kind.REMEMBER_CARD:
				if run.rememberable_deck_indices().is_empty():
					continue
		kept.append(entry)
	pending = kept


## The cards on offer for a pending &"pick" (stable until one is taken; empty otherwise).
func event_pick_choices(run: RunState) -> Array[CardData]:
	var offered: Array[CardData] = []
	if event_followup(run) == &"pick":
		offered.assign(pending[0].cards)
	return offered


## Deck positions the pending &"remember" may pick (empty otherwise).
func event_remember_indices(run: RunState) -> Array[int]:
	if event_followup(run) != &"remember":
		var none: Array[int] = []
		return none
	return run.rememberable_deck_indices()


## Completes the pending &"remove": the card at `deck_index` leaves the deck. False, changing nothing, if none is
## pending, the index is bad or the deck would be emptied.
func event_remove_card(run: RunState, deck_index: int) -> bool:
	if event_followup(run) != &"remove" or deck_index < 0 or deck_index >= run.deck.size() or run.deck.size() <= 1:
		return false
	run.deck.remove_at(deck_index)
	pending.remove_at(0)
	return true


## Completes the pending &"remember": the card at `deck_index` becomes its Remembered form.
func event_remember_card(run: RunState, deck_index: int) -> bool:
	if not event_remember_indices(run).has(deck_index):
		return false
	run.deck[deck_index] = run.deck[deck_index].remembered_card()
	pending.remove_at(0)
	return true


## Completes the pending &"pick": `card` (one of `event_pick_choices(run)`) joins the deck.
func event_pick_card(run: RunState, card: CardData) -> bool:
	if not event_pick_choices(run).has(card):
		return false
	run.deck.append(card)
	pending.remove_at(0)
	return true


## Leaves the event and moves on. Needs a choice made and no pick owed (an event whose content failed to load can be
## left at once). False, changing nothing, otherwise.
func finish_event(run: RunState) -> bool:
	if not run.in_event_stop():
		return false
	if open_event == null:
		# Nothing was shown yet: only a stop whose content failed to load may be passed.
		if not StarterContent.events_for(run.chapter).is_empty():
			return false
	elif not resolved or not pending.is_empty():
		return false
	run.advance_stop()
	return true


func reset() -> void:
	open_event = null
	resolved = false
	outcome = ""
	pending.clear()


## The relics an event may hand out from `pool`: the unowned ones of exactly that pool (the button's printed text names
## it, so a NEUTRAL pool never widens to class relics). Empty means the button is greyed or a gamble pays gold.
static func relic_candidates(run: RunState, pool: EventEffect.Pool) -> Array[RelicData]:
	var found: Array[RelicData] = []
	var unowned := run.unowned_relics()
	for relic in unowned:
		var neutral: bool = relic.character == &""
		if pool == EventEffect.Pool.ANY or (pool == EventEffect.Pool.NEUTRAL and neutral) or (pool == EventEffect.Pool.CLASS and not neutral):
			found.append(relic)
	return found


## Applies a list of effects. `lines` collects what happened, `gambles` the result of each gamble rolled (true = won).
func _apply_event_effects(run: RunState, effects: Array[EventEffect], lines: Array[String], gambles: Array[bool]) -> void:
	for effect in effects:
		_apply_event_effect(run, effect, lines, gambles)


func _apply_event_effect(run: RunState, effect: EventEffect, lines: Array[String], gambles: Array[bool]) -> void:
	match effect.kind:
		EventEffect.Kind.HEAL_PERCENT, EventEffect.Kind.HEAL_FLAT:
			var wanted: int = roundi(run.player.max_hp * effect.amount / 100.0) if effect.kind == EventEffect.Kind.HEAL_PERCENT else effect.amount
			var healed := run.player.heal(wanted)
			if healed > 0:
				lines.append("You recover %d HP." % healed)
		EventEffect.Kind.LOSE_HP, EventEffect.Kind.LOSE_HP_PERCENT:
			var cost: int = roundi(run.player.max_hp * effect.amount / 100.0) if effect.kind == EventEffect.Kind.LOSE_HP_PERCENT else effect.amount
			var lost := clampi(cost, 0, run.player.hp - 1)
			run.player.hp -= lost
			run.player.changed.emit()
			if lost > 0:
				lines.append("You lose %d HP." % lost)
		EventEffect.Kind.GOLD:
			if effect.amount >= 0:
				run.gold += effect.amount
				if effect.amount > 0:
					lines.append("You gain %d gold." % effect.amount)
			else:
				var paid := mini(-effect.amount, run.gold)
				run.gold -= paid
				if paid > 0:
					lines.append("You pay %d gold." % paid)
		EventEffect.Kind.MAX_HP:
			if effect.amount >= 0:
				run.player.max_hp += effect.amount
				run.player.hp += effect.amount
			else:
				run.player.max_hp = maxi(run.player.max_hp + effect.amount, 1)
				run.player.hp = clampi(run.player.hp, 1, run.player.max_hp)
			run.player.changed.emit()
			lines.append("Your max HP %s by %d." % ["rises" if effect.amount >= 0 else "falls", absi(effect.amount)])
		EventEffect.Kind.ADD_CARD:
			var card := StarterContent.card_by_id(effect.card_id)
			if card != null:
				for _i in maxi(effect.count, 1):
					run.deck.append(card)
				lines.append("%s joins your deck." % card.display_name)
		EventEffect.Kind.ADD_CURSE:
			var curse := StarterContent.status_card(effect.card_id)
			if curse != null:
				for _i in maxi(effect.count, 1):
					run.deck.append(curse)
				lines.append("%s joins your deck." % ("A " + curse.display_name if effect.count <= 1 else "%d x %s" % [effect.count, curse.display_name]))
		EventEffect.Kind.ADD_RANDOM_CARD:
			var candidates := _event_card_candidates(run, effect)
			for _i in maxi(effect.count, 1):
				if candidates.is_empty():
					break
				var picked: CardData = candidates[_rng.randi_range(0, candidates.size() - 1)]
				run.deck.append(picked)
				lines.append("%s joins your deck." % picked.display_name)
		EventEffect.Kind.PICK_CARD:
			var offered := _event_draw_distinct(run, _event_card_candidates(run, effect), effect.count)
			if not offered.is_empty():
				pending.append(PendingPick.new(effect.kind, offered))
		EventEffect.Kind.REMOVE_CARD:
			pending.append(PendingPick.new(effect.kind))
		EventEffect.Kind.REMEMBER_CARD:
			if not run.rememberable_deck_indices().is_empty():
				pending.append(PendingPick.new(effect.kind))
		EventEffect.Kind.REMOVE_RANDOM_CARD:
			for _i in maxi(effect.count, 1):
				var owed := 0
				for entry in pending:
					if entry.kind == EventEffect.Kind.REMOVE_CARD:
						owed += 1
				if run.deck.size() - owed <= 1:
					break
				var gone := run.deck[_rng.randi_range(0, run.deck.size() - 1)]
				run.deck.erase(gone) # drops the first copy, which is as good as any: copies are the same card
				lines.append("%s is erased from your deck." % gone.display_name)
		EventEffect.Kind.GAIN_RELIC:
			var relics_left := relic_candidates(run, effect.pool)
			if relics_left.is_empty():
				run.gold += RunState.EVENT_RELIC_FALLBACK_GOLD
				lines.append("There is nothing left to give you but %d gold." % RunState.EVENT_RELIC_FALLBACK_GOLD)
			else:
				var relic: RelicData = relics_left[_rng.randi_range(0, relics_left.size() - 1)] if relics_left.size() > 1 else relics_left[0]
				run.grant_relic(relic)
				lines.append("You gain the %s." % relic.display_name)
		EventEffect.Kind.GAMBLE:
			var won := _rng.randi_range(1, 100) <= effect.amount
			gambles.append(won)
			_apply_event_effects(run, effect.win if won else effect.lose, lines, gambles)


## The cards an ADD_RANDOM_CARD or PICK_CARD draws from: the non-basic reward pool of this character, restricted by
## pool (neutral, own class or both), rarity and an optional effect kind. PICK_CARD only ever offers the class's own.
func _event_card_candidates(run: RunState, effect: EventEffect) -> Array[CardData]:
	var found: Array[CardData] = []
	var wanted_pool: EventEffect.Pool = EventEffect.Pool.CLASS if effect.kind == EventEffect.Kind.PICK_CARD else effect.pool
	for card in RunRewards.distinct_cards(StarterContent.reward_pool(run.character.id, run.chapter)):
		var neutral: bool = card.character == &""
		if wanted_pool == EventEffect.Pool.NEUTRAL and not neutral:
			continue
		if wanted_pool == EventEffect.Pool.CLASS and neutral:
			continue
		if effect.rarity >= 0 and int(card.rarity) != effect.rarity:
			continue
		if effect.has_effect >= 0:
			var has := false
			for card_effect in card.effects:
				if int(card_effect.kind) == effect.has_effect:
					has = true
			if not has:
				continue
		found.append(card)
	return found


## Up to `count` distinct cards out of `pool` drawn with the run RNG, preferring cards the deck holds fewer than
## RunState.COPY_CAP times when enough of those remain.
func _event_draw_distinct(run: RunState, pool: Array[CardData], count: int) -> Array[CardData]:
	var copies := {}
	for card in run.deck:
		copies[card.id] = int(copies.get(card.id, 0)) + 1
	var fresh: Array[CardData] = []
	for card in pool:
		if int(copies.get(card.id, 0)) < RunState.COPY_CAP:
			fresh.append(card)
	var source: Array[CardData] = fresh if fresh.size() >= count else pool.duplicate()
	var picks: Array[CardData] = []
	while picks.size() < count and not source.is_empty():
		var at := _rng.randi_range(0, source.size() - 1)
		picks.append(source[at])
		source.remove_at(at)
	return picks
