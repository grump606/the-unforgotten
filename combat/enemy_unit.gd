class_name EnemyUnit
extends Combatant
## An enemy in a fight: its health plus its position in its own intent cycle.

var data: EnemyData

## 1 normally; 2 once the enemy has crossed its `phase_two_hp_percent` threshold, 3 once it has crossed `phase_three_hp_percent`
## after that (see EnemyData).
var phase: int = 1

var _intent_index: int = 0


func _init(enemy_data: EnemyData) -> void:
	super(enemy_data.display_name, enemy_data.max_hp)
	data = enemy_data
	max_haunt = enemy_data.max_haunt


## The intent cycle for the current phase.
func active_intents() -> Array[CardEffect]:
	match phase:
		2:
			return data.phase_two_intents
		3:
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
	if phase == 1 and not data.phase_two_intents.is_empty() and hp * 100 <= max_hp * data.phase_two_hp_percent:
		phase = 2
		_intent_index = 0
		return true
	if phase == 2 and not data.phase_three_intents.is_empty() and hp * 100 <= max_hp * data.phase_three_hp_percent:
		phase = 3
		_intent_index = 0
		return true
	return false


func advance_intent() -> void:
	_intent_index += 1
