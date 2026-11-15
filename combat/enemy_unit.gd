class_name EnemyUnit
extends Combatant
## An enemy in a fight: its health plus its position in its own intent cycle.

## The phase numbers `phase` takes. Phase three needs phase two: an enemy defines phase_three_intents only together with
## phase_two_intents (tests/phase_tests.gd checks every shipped enemy), and check_phase never skips a phase.
const PHASE_ONE := 1
const PHASE_TWO := 2
const PHASE_THREE := 3

var data: EnemyData

## PHASE_ONE normally; PHASE_TWO once the enemy has crossed its `phase_two_hp_percent` threshold, PHASE_THREE once it has
## crossed `phase_three_hp_percent` after that (see EnemyData).
var phase: int = PHASE_ONE

var _intent_index: int = 0


func _init(enemy_data: EnemyData) -> void:
	super(enemy_data.display_name, enemy_data.max_hp)
	data = enemy_data
	max_haunt = enemy_data.max_haunt


## The intent cycle for the current phase.
func active_intents() -> Array[CardEffect]:
	match phase:
		PHASE_TWO:
			return data.phase_two_intents
		PHASE_THREE:
			return data.phase_three_intents
	return data.intents


## What this enemy will do on its next turn, or null if it has no intents.
func current_intent() -> CardEffect:
	var intents := active_intents()
	if intents.is_empty():
		return null
	return intents[_intent_index % intents.size()]


## Moves to the next phase, once per call, when a living enemy that has one is at or below that phase's HP threshold (phase two, then
## phase three). The new cycle starts from its first intent. Returns true only when it switches; a hit that crosses both thresholds
## needs two calls, which Combat makes.
func check_phase() -> bool:
	if is_dead():
		return false
	if phase == PHASE_ONE and not data.phase_two_intents.is_empty() and hp * 100 <= max_hp * data.phase_two_hp_percent:
		phase = PHASE_TWO
		_intent_index = 0
		return true
	if phase == PHASE_TWO and not data.phase_three_intents.is_empty() and hp * 100 <= max_hp * data.phase_three_hp_percent:
		phase = PHASE_THREE
		_intent_index = 0
		return true
	return false


func advance_intent() -> void:
	_intent_index += 1
