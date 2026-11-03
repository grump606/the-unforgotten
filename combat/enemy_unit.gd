class_name EnemyUnit
extends Combatant
## An enemy in a fight: its health plus its position in its own intent cycle.

var data: EnemyData

var _intent_index: int = 0


func _init(enemy_data: EnemyData) -> void:
	super(enemy_data.display_name, enemy_data.max_hp)
	data = enemy_data
	max_haunt = enemy_data.max_haunt


## What this enemy will do on its next turn, or null if it has no intents.
func current_intent() -> CardEffect:
	if data.intents.is_empty():
		return null
	return data.intents[_intent_index % data.intents.size()]


func advance_intent() -> void:
	_intent_index += 1
