class_name CombatScreen
extends RunScreen
## A combat stop: embeds battle.tscn around a Combat built by the run.

const BATTLE_SCENE := preload("res://battle.tscn")

## The embedded fight while this screen is showing (null before the first fight or when it could not be built).
var fight: Node = null


## `on_finished(victory: bool)` is connected to the battle's fight_finished signal; `on_start_over`
## is offered when the fight could not be built.
func show(on_finished: Callable, on_start_over: Callable) -> void:
	fight = null
	var combat := run.start_combat()
	if combat == null:
		var box := panel("Could not build this fight (content failed to load). See the Output log.")
		add_button(box, "Start over", on_start_over)
		return
	var battle := BATTLE_SCENE.instantiate()
	battle.external_combat = combat
	# The mid-boss and the final boss both get the boss look; only the final one ends the run.
	var label := run.boss_label()
	battle.boss_fight = label != ""
	battle.boss_label = label if label != "" else "Boss"
	battle.elite_fight = label == "" and run.in_elite_stop()
	battle.character_id = run.character.id if run.character != null else &""
	battle.destination_key = run.battle_backdrop()
	battle.relics = run.relics
	battle.fight_finished.connect(on_finished)
	body.add_child(battle)
	fight = battle
