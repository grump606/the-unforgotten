class_name EnemyData
extends Resource
## Static definition of an enemy. It repeats its intents in order, one per turn.

## Stable identifier (the .tres file name). Art and other lookups key on this; display_name is presentation only.
@export var id: StringName = &""
@export var display_name: String
@export var max_hp: int = 20
@export var intents: Array[CardEffect] = []


static func make(enemy_name: String, hp: int, enemy_intents: Array[CardEffect], enemy_id: StringName = &"") -> EnemyData:
	var enemy := EnemyData.new()
	enemy.id = enemy_id
	enemy.display_name = enemy_name
	enemy.max_hp = hp
	enemy.intents = enemy_intents
	return enemy
