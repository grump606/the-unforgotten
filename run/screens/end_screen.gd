class_name EndScreen
extends RunScreen
## The end card after the last stop or a defeat: outcome, a summary and New Run.


## `on_new_run` is bound by the caller so the select screen's Back button returns here.
func show(on_new_run: Callable) -> void:
	var title := "Someone speaks your name. This time, you answer." if run.escaped else "They return you to the quiet. Somewhere, a voice still calls."
	var scene := EndScene.new()
	scene.escaped = run.escaped
	add_backdrop(scene)
	var box := panel("%s\nOutcome: %s" % [title, "Escaped" if run.escaped else "Defeated"])
	style_banner(box.get_child(0) as Label)
	var summary := Label.new()
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary.text = "Stops cleared: %d/%d\nFinal HP: %d/%d\nDeck: %d cards\nGold: %d" % [
		run.stop_index, run.stops.size(), run.player.hp, run.player.max_hp, run.deck.size(), run.gold,
	]
	style_banner(summary)
	box.add_child(summary)
	style_service(add_button(box, "New Journey", on_new_run))
