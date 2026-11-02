class_name CombatScreen
extends RunScreen
## A combat stop: embeds battle.tscn around a Combat built by the run.

const BATTLE_SCENE := preload("res://battle.tscn")


## `on_finished(victory: bool)` is connected to the battle's fight_finished signal; `on_start_over`
## is offered when the fight could not be built.
func show(on_finished: Callable, on_start_over: Callable) -> void:
	var combat := run.start_combat()
	if combat == null:
		var box := panel("Could not build this fight (content failed to load). See the Output log.")
		add_button(box, "Start over", on_start_over)
		return
	var battle := BATTLE_SCENE.instantiate()
	battle.external_combat = combat
	# The mid-boss and the final boss both get the boss look; only the final one ends the run.
	var stop := run.current_stop()
	battle.boss_fight = stop.boss or stop.mid_boss
	battle.boss_label = "Mid-boss" if stop.mid_boss else "Boss"
	battle.character_id = run.character.id if run.character != null else &""
	battle.destination_key = DestinationArt.battle_key(run.stop_index)
	battle.relics = run.relics
	battle.fight_finished.connect(on_finished)
	body.add_child(battle)
