class_name EnemyUnit
extends Combatant
## An enemy in a fight: its health plus its position in its own intent cycle.

var data: EnemyData

## 1 normally; 2 once the enemy has crossed its `phase_two_hp_percent` threshold (see EnemyData).
var phase: int = 1

var _intent_index: int = 0


func _init(enemy_data: EnemyData) -> void:
	super(enemy_data.display_name, enemy_data.max_hp)
	data = enemy_data
	max_haunt = enemy_data.max_haunt


## The intent cycle for the current phase.
func active_intents() -> Array[CardEffect]:
	return data.phase_two_intents if phase == 2 else data.intents


## What this enemy will do on its next turn, or null if it has no intents.
func current_intent() -> CardEffect:
	var intents := active_intents()
	if intents.is_empty():
		return null
	return intents[_intent_index % intents.size()]


## Switches to phase two, once, when a living enemy with a phase two is at or below its HP threshold.
## The new cycle starts from its first intent. Returns true only on the turn it switches.
func check_phase() -> bool:
	if phase != 1 or data.phase_two_intents.is_empty() or is_dead():
		return false
	if hp * 100 > max_hp * data.phase_two_hp_percent:
		return false
	phase = 2
	_intent_index = 0
	return true


func advance_intent() -> void:
	_intent_index += 1
