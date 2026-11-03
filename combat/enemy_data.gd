class_name EnemyData
extends Resource
## Static definition of an enemy. It repeats its intents in order, one per turn.

## Stable identifier (the .tres file name). Art and other lookups key on this; display_name is presentation only.
@export var id: StringName = &""
@export var display_name: String
@export var max_hp: int = 20
@export var intents: Array[CardEffect] = []
## Most Haunt stacks this enemy can carry at once (0 = no cap). Haunt applied past it is lost.
@export var max_haunt: int = 0


static func make(enemy_name: String, hp: int, enemy_intents: Array[CardEffect], enemy_id: StringName = &"", haunt_cap: int = 0) -> EnemyData:
	var enemy := EnemyData.new()
	enemy.id = enemy_id
	enemy.display_name = enemy_name
	enemy.max_hp = hp
	enemy.intents = enemy_intents
	enemy.max_haunt = haunt_cap
	return enemy
