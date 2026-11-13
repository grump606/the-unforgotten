class_name EndScreen
extends RunScreen
## The end card after the last stop or a defeat: outcome, a summary, Continue (back to the main
## menu) and New Journey.


## `on_new_run` is bound by the caller so the select screen's Back button returns here.
## `on_continue` (when valid) adds a Continue button that returns to the main menu.
func show(on_new_run: Callable, on_continue := Callable()) -> void:
	var title := "Someone speaks your name. This time, you answer." if run.escaped else "They return you to the quiet. Somewhere, a voice still calls."
	if run.to_be_continued:
		var beat := StoryContent.break_beat(run.chapter, run.character.id if run.character != null else &"")
		title = ("%s

%s" % [beat.title, beat.text]) if beat != null else "The way down opens, and the voice is closer."

	if run.escaped and run.finale:
		# Winning the finale: the escape text written for it, when the chapter has one.
		var after := StoryContent.finale_beat(run.chapter, "after", run.character.id if run.character != null else &"")
		if after != null:
			title = "%s

%s" % [after.title, after.text]

	var scene := EndScene.new()
	scene.escaped = run.escaped
	add_backdrop(scene)
	var outcome := "Escaped" if run.escaped else ("To be continued" if run.to_be_continued else "Defeated")
	var box := panel("%s\nOutcome: %s" % [title, outcome], true)
	style_banner(box.get_child(0) as Label)
	var summary := Label.new()
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary.text = "Stops cleared: %d/%d\nFinal HP: %d/%d\nDeck: %d cards\nGold: %d" % [
		run.stop_index, run.stops.size(), run.player.hp, run.player.max_hp, run.deck.size(), run.gold,
	]
	style_banner(summary)
	box.add_child(summary)
	if on_continue.is_valid():
		style_service(add_button(box, "Continue", on_continue))
	style_service(add_button(box, "New Journey", on_new_run))
