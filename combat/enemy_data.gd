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
## Optional second phase: once HP is at or below this percent of max, the enemy switches to `phase_two_intents`
## (starting from the first) for the rest of the fight. Empty = the enemy has one phase.
@export var phase_two_intents: Array[CardEffect] = []
@export_range(1, 99) var phase_two_hp_percent: int = 50
## Banner text shown by the UI when phase two begins (presentation only).
@export var phase_two_title: String = ""
## Optional third phase (the finale boss): once HP is at or below this percent of max, and the enemy is already in phase two,
## it switches to `phase_three_intents`. It needs a phase two, and its threshold is below phase two's.
@export var phase_three_intents: Array[CardEffect] = []
@export_range(1, 98) var phase_three_hp_percent: int = 33
@export var phase_three_title: String = ""


## The banner text of phase `phase` (2 or 3); "" for any other, or when the data names none.
func title_for_phase(phase: int) -> String:
	match phase:
		2:
			return phase_two_title
		3:
			return phase_three_title
	return ""
## Unseen: while another enemy that is not Unseen is alive, this one cannot be targeted. A card aimed at it
## lands on the first enemy that can be (and the battle screen will not select it); an all-enemies card still
## reaches it. Once it is the only kind left, it can be targeted normally. See Combat.is_shielded().
@export var unseen: bool = false


static func make(enemy_name: String, hp: int, enemy_intents: Array[CardEffect], enemy_id: StringName = &"", haunt_cap: int = 0) -> EnemyData:
	var enemy := EnemyData.new()
	enemy.id = enemy_id
	enemy.display_name = enemy_name
	enemy.max_hp = hp
	enemy.intents = enemy_intents
	enemy.max_haunt = haunt_cap
	return enemy
