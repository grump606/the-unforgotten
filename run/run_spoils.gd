class_name RunSpoils
extends RefCounted
## The relic spoils of a RunState: an elite fight's relic, a chapter end boss's relic and the chest of a TREASURE stop.
## Holds the state; the run is passed into each call (no reference cycle). RunState keeps the public API and delegates.
## It uses only RunState's public surface (`advance_stop()` when leaving a chest); the run RNG is passed in where it rolls.

## The spoils of a won elite fight: `elite_pending` while they wait to be taken, with the relic in `elite_relic`
## (null when the character owned every relic and gold is given instead). Rolled from the run RNG when the fight is won,
## so a save made on arrival (before the fight) always yields the same relic.
var elite_pending := false
var elite_relic: RelicData = null
## A chapter's end boss: `boss_pending` while the relic waits to be taken, `boss_relic` null when none is left (gold instead).
var boss_pending := false
var boss_relic: RelicData = null
## The open chest of a TREASURE stop: `treasure_opened` once rolled, `treasure_relic` its relic (null when the
## character owned every relic and the chest holds gold instead).
var treasure_opened := false
var treasure_relic: RelicData = null


func reset_treasure() -> void:
	treasure_opened = false
	treasure_relic = null


func reset_elite() -> void:
	elite_pending = false
	elite_relic = null


## A relic from the character's pool minus the relics owned, drawn with `rng` (the run RNG): among those priced at least
## `min_price` when there are any, else among all of them; null when none is left.
static func roll_relic(run: RunState, rng: RandomNumberGenerator, min_price: int) -> RelicData:
	var unowned := run.unowned_relics()
	var choices: Array[RelicData] = []
	for relic in unowned:
		if relic.price >= min_price:
			choices.append(relic)
	if choices.is_empty():
		choices = unowned
	if choices.is_empty():
		return null
	return choices[rng.randi_range(0, choices.size() - 1)] if choices.size() > 1 else choices[0]


## Opens the chest (see RunState.open_treasure): rolls its relic with `rng` (the run RNG) once.
func open_treasure(run: RunState, rng: RandomNumberGenerator) -> bool:
	if not run.in_treasure_stop():
		return false
	if treasure_opened:
		return true
	treasure_relic = roll_relic(run, rng, RunState.TREASURE_MIN_RELIC_PRICE)
	treasure_opened = true
	return true


## Takes what the open chest holds and moves the run on (see RunState.take_treasure).
func take_treasure(run: RunState) -> bool:
	if not run.treasure_opened():
		return false
	if treasure_relic != null:
		run.grant_relic(treasure_relic)
	else:
		run.gold += RunState.TREASURE_FALLBACK_GOLD
	run.advance_stop()
	return true


## Takes an elite's spoils (see RunState.take_elite_spoils).
func take_elite(run: RunState) -> bool:
	if not run.elite_spoils_pending():
		return false
	if elite_relic != null:
		run.grant_relic(elite_relic)
	else:
		run.gold += RunState.ELITE_RELIC_FALLBACK_GOLD
	reset_elite()
	return true
