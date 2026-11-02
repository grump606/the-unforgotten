extends SceneTree
## Headless test for the rest, story and end-card scenes: each builds and draws, the animation is
## deterministic and only runs while visible, they ignore the mouse, every story beat index (and an
## unknown one) and both end variants build, and in a real run each stop type has exactly one scene
## beneath its panel with the buttons still working. Run via scripts/check.ps1.

var fails := 0
var test_save := "user://ui_screen_scenes_test_save_%d.json" % OS.get_process_id()

func check(c: bool, msg: String) -> void:
	if not c:
		fails += 1
		printerr("FAIL: " + msg)
	else:
		print("ok: " + msg)


func _make(kind: int) -> ScreenScene:
	match kind:
		0:
			return RestScene.new()
		1:
			return StoryScene.new()
	return EndScene.new()


func _find_button(node: Node, prefix: String) -> Button:
	if node is Button and (node as Button).text.begins_with(prefix):
		return node
	for child in node.get_children():
		var found := _find_button(child, prefix)
		if found != null:
			return found
	return null


func _initialize() -> void:
	var holder := Control.new()
	holder.size = Vector2(1120, 590)
	root.add_child(holder)
	var names := ["rest", "story", "end"]

	for kind in 3:
		var label: String = names[kind]
		var a := _make(kind)
		a.size = holder.size
		holder.add_child(a)
		a.advance(0.7)
		await process_frame
		await process_frame
		check(a.time > 0.0, "the %s scene builds and draws" % label)
		check(a.mouse_filter == Control.MOUSE_FILTER_IGNORE, "the %s scene ignores the mouse" % label)

		var b := _make(kind)
		b.size = holder.size
		holder.add_child(b)
		var flicker0 := b.flicker(0)
		b.advance(0.4)
		check(b.time == 0.4 and b.flicker(0) != flicker0, "advance changes the %s animation state" % label)
		var c := _make(kind)
		holder.add_child(c)
		c.advance(0.4)
		c.advance(0.0)
		check(c.time == b.time and c.flicker(3) == b.flicker(3) and c.wobble(2.0, 5) == b.wobble(2.0, 5), "the same steps give the same %s animation" % label)
		var twin := _make(kind)
		check(twin._motes == b._motes and twin._noise == b._noise, "the fixed seed gives the same %s layout every time" % label)
		var in_range := true
		for i in 60:
			b.advance(0.17)
			in_range = in_range and b.flicker(1) >= 0.72 and b.flicker(1) <= 1.0
		check(in_range, "the %s flicker stays in range" % label)
		b.visible = false
		var frozen := b.time
		b.advance(1.0)
		check(b.time == frozen and not b.is_processing(), "a hidden %s scene does not advance or process" % label)
		b.visible = true
		check(b.is_processing(), "showing the %s scene again resumes processing" % label)
		var detached := _make(kind)
		detached.advance(1.0)
		check(detached.time == 0.0, "a %s scene outside the tree does not advance" % label)

	# Rest: every class, a missing class, and the breathing moves.
	for id in [&"deserter", &"pickpocket", &"medium", &"", &"nobody"]:
		var rest := RestScene.new()
		rest.character_id = id
		rest.size = holder.size
		holder.add_child(rest)
		var breath0 := rest.breath()
		rest.advance(0.5)
		await process_frame
		check(rest.breath() != breath0, "the rest scene draws for class '%s'" % id)

	# Story: each beat index and an unknown one build and draw, with their own mood.
	var moods := {}
	for index in [0, 1, 2, 3, 4, -1, 99]:
		var story := StoryScene.new()
		story.beat_index = index
		story.size = holder.size
		holder.add_child(story)
		story.advance(1.3)
		await process_frame
		moods[story.mood()] = true
		check(story.time > 0.0, "the story scene draws for beat %d (%s)" % [index, story.mood()])
	check(moods.size() == 5, "four distinct beat moods plus a generic tunnel")

	# End: both variants build and draw; the train slows, the defeat lamp goes out.
	for escaped in [true, false]:
		var end := EndScene.new()
		end.escaped = escaped
		end.size = holder.size
		holder.add_child(end)
		end.advance(2.0)
		await process_frame
		check(end.time > 0.0, "the %s end scene draws" % ("escape" if escaped else "defeat"))
	var timing := EndScene.new()
	holder.add_child(timing)
	timing.advance(1.0)
	var slow_1 := timing.train_offset()
	timing.advance(10.0)
	var slow_2 := timing.train_offset()
	timing.advance(1.0)
	check(slow_2 > slow_1 and timing.train_offset() - slow_2 < slow_1, "the escaping train slows down")
	var lamp := EndScene.new()
	holder.add_child(lamp)
	lamp.advance(0.1)
	check(lamp.lamp_level() > 0.0, "the defeat lamp burns at first")
	lamp.advance(EndScene.LAMP_LIFE + 1.0)
	check(lamp.lamp_level() == 0.0, "the defeat lamp goes out")

	# In a real run: one scene beneath each stop's panel, buttons still working.
	RunSave.delete(test_save)
	var scene: Control = load("res://run.tscn").instantiate()
	scene.save_path = test_save
	root.add_child(scene)
	await process_frame
	scene._start_run(&"medium")
	var run_state: RunState = scene._run
	var body: Control = scene.get_node("%Body")

	_go_to(scene, RunState.StopType.REST)
	await process_frame
	await process_frame
	var rests: Array[Node] = scene.find_children("*", "ScreenScene", true, false)
	check(rests.size() == 1 and rests[0] is RestScene, "the rest stop has exactly one rest scene")
	check(_beneath_panel(body, rests[0]), "the rest scene is the lowest child of the body, beneath the panel")
	check((rests[0] as RestScene).character_id == &"medium" and rests[0].time > 0.0, "the rest scene shows the player's class and animates")
	var rest_button := _find_button(body, "Rest (+")
	check(rest_button != null and rest_button.text == "Rest (+%d HP)" % RunState.REST_HEAL, "the Rest button keeps its text")
	run_state.player.hp = run_state.player.max_hp - 30
	scene._show_stop()
	var hp_before := run_state.player.hp
	var index_before := run_state.stop_index
	_find_button(body, "Rest (+").pressed.emit()
	await process_frame
	check(run_state.player.hp > hp_before and run_state.stop_index == index_before + 1, "the Rest button still heals and moves on")

	for beat in 4:
		_go_to(scene, RunState.StopType.STORY)
		run_state.stops[run_state.stop_index].beat_index = beat
		scene._show_stop()
		await process_frame
		var stories: Array[Node] = scene.find_children("*", "ScreenScene", true, false)
		check(stories.size() == 1 and stories[0] is StoryScene and (stories[0] as StoryScene).beat_index == beat, "story beat %d has exactly one story scene" % beat)
		check(_beneath_panel(body, stories[0]), "the story scene for beat %d is beneath the card" % beat)
		var expected := StoryContent.beat(beat, &"medium")
		var button := _find_button(body, expected.button_text)
		check(button != null and _has_text(body, expected.text) and _has_text(body, expected.title), "beat %d keeps its title, text and button" % beat)
	var story_index := run_state.stop_index
	_find_button(body, StoryContent.beat(3, &"medium").button_text).pressed.emit()
	await process_frame
	check(run_state.stop_index == story_index + 1, "the story button still moves the train on")

	run_state.finished = true
	for escaped in [true, false]:
		run_state.escaped = escaped
		scene._show_stop()
		await process_frame
		var ends: Array[Node] = scene.find_children("*", "ScreenScene", true, false)
		check(ends.size() == 1 and ends[0] is EndScene and (ends[0] as EndScene).escaped == escaped, "the %s end card has exactly one end scene" % ("escape" if escaped else "defeat"))
		check(_beneath_panel(body, ends[0]), "the end scene is beneath the summary")
		check(_has_text(body, "Outcome: %s" % ("Escaped" if escaped else "Defeated")) and _has_text(body, "Stops cleared:") and _has_text(body, "Gold:"), "the end summary text is kept")
	var new_run := _find_button(body, "New Journey")
	check(new_run != null, "the End card still offers New Run")
	new_run.pressed.emit()
	await process_frame
	var select_scenes: Array[Node] = scene.find_children("*", "ScreenScene", true, false)
	check(select_scenes.size() == 1 and select_scenes[0] is SelectScene and _find_button(body, "Play as") != null, "New Run opens the select screen with only its own backdrop")
	scene.queue_free()
	RunSave.delete(test_save)
	print("DONE fails=", fails)
	quit(1 if fails > 0 else 0)


func _go_to(scene: Control, type: int) -> void:
	var run_state: RunState = scene._run
	run_state.finished = false
	for i in run_state.stops.size():
		if run_state.stops[i].type == type:
			run_state.stop_index = i
			break
	scene._show_stop()


## True when `node` is a direct child of the body below which every other child is added later.
func _beneath_panel(body: Control, node: Node) -> bool:
	return node.get_parent() == body and node.get_index() == 0 and body.get_child_count() > 1


func _has_text(node: Node, text: String) -> bool:
	if node is Label and (node as Label).text.contains(text):
		return true
	for child in node.get_children():
		if _has_text(child, text):
			return true
	return false
