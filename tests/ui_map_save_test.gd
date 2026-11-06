extends SceneTree
## Headless UI test for saving map runs (docs/MAP_DESIGN.md "Phase 3") through the real run.tscn: when the
## autosave happens, what the pause overlay says, Save & Exit, the Continue panel, deleting a finished run,
## the --map debug session (never touches a save; --hp and --gold apply) and the first-stop ambience.
## Scratch save paths only: the developer's real save is never touched. Run via scripts/check.ps1.

var fails := 0
var save_path := "user://ui_map_save_test_%d.json" % OS.get_process_id()
var settings_path := "user://ui_map_save_settings_%d.json" % OS.get_process_id()


func check(c: bool, msg: String) -> void:
	if not c:
		fails += 1
		printerr("FAIL: " + msg)
	else:
		print("ok: " + msg)


func _all_text(node: Node) -> String:
	var text := ""
	if node is Label:
		text += (node as Label).text + "\n"
	for child in node.get_children():
		text += _all_text(child)
	return text


func _find_button(node: Node, prefix: String) -> Button:
	if node is Button and (node as Button).text.begins_with(prefix):
		return node
	for child in node.get_children():
		var found := _find_button(child, prefix)
		if found != null:
			return found
	return null


func _new_scene() -> Control:
	var scene: Control = load("res://run.tscn").instantiate()
	scene.save_path = save_path
	scene.settings_path = settings_path
	root.add_child(scene)
	return scene


func _wipe() -> void:
	RunSave.delete(save_path)
	DirAccess.remove_absolute(settings_path)


## The ambience id now playing, or &"?" when there is no audio manager.
func _ambience() -> StringName:
	var audio := root.get_node_or_null("AudioManager")
	if audio == null or audio.ambience_channel == null:
		return &"?"
	return audio.ambience_channel.current_id


func _initialize() -> void:
	await process_frame
	_wipe()

	# --- The pause text, per situation (static, so no scene is needed) ---
	var line_run := RunState.new(3)
	var line_text := PauseMenu.save_note(line_run)
	check(line_text == "Your journey is saved on arrival at each destination.\nSave & Exit returns you to the start of this destination.", "a line run's pause text is unchanged")
	check(PauseMenu.save_note(null) == line_text, "no run at all gets the line text")
	var map_run := RunState.new(3, &"deserter", true)
	var at_map := PauseMenu.save_note(map_run)
	check(at_map.contains("returns you to this map") and not at_map.contains("start of this"), "a map run at the map says Save & Exit returns to the map")
	map_run.choose_node(map_run.reachable_nodes()[0])
	var in_stop := PauseMenu.save_note(map_run)
	check(in_stop.contains("start of this stop") and not in_stop.contains("returns you to this map"), "a map run inside a stop says Save & Exit returns to the start of the stop")

	# --- A real map run: saves at the map, on arrival, at the next map ---
	var scene := _new_scene()
	await process_frame
	var exits := [0]
	scene.exit_callable = func() -> void: exits[0] += 1
	var run_state := RunState.new(5, &"deserter", true)
	scene._run = run_state
	scene._debug_session = false
	scene._reset_screens()
	scene._show_stop()
	await process_frame
	var loaded := RunSave.load_file(save_path)
	check(loaded.run != null and loaded.run.uses_map() and loaded.run.current_node == -1 and not loaded.run.in_map_stop(), "showing the first map saves the run at the map")
	check(loaded.run != null and loaded.run.reachable_nodes() == run_state.reachable_nodes(), "the saved map offers the same first roads")

	var first: int = run_state.reachable_nodes()[0]
	scene._on_node_chosen(first)
	await process_frame
	loaded = RunSave.load_file(save_path)
	check(loaded.run != null and loaded.run.current_node == first and loaded.run.in_map_stop() and loaded.run.reachable_nodes().is_empty(), "choosing a node saves on arrival at its stop: the other roads cannot be re-chosen after a quit")

	# Pause inside the stop.
	scene._pause_button.pressed.emit()
	await process_frame
	var pause_text := _all_text(scene._pause_box)
	check(pause_text.contains("start of this stop") and not pause_text.contains("returns you to this map"), "the pause overlay inside a stop says the start of this stop")
	scene._set_paused(false)

	# Finish the stop: the map shows and saves again.
	var stop := run_state.current_stop()
	match stop.type:
		RunState.StopType.COMBAT:
			run_state.complete_combat(true)
			if run_state.reward_pending():
				run_state.resolve_reward(null)
		RunState.StopType.REST:
			run_state.rest()
		RunState.StopType.STORY:
			run_state.read_story()
		RunState.StopType.VENDOR:
			run_state.leave_vendor()
	scene._show_stop()
	await process_frame
	loaded = RunSave.load_file(save_path)
	check(loaded.run != null and not loaded.run.in_map_stop() and loaded.run.current_node == first and loaded.run.visited == run_state.visited, "the map shown after a stop is saved: Continue resumes at the map")
	check(loaded.run != null and loaded.run.reachable_nodes() == run_state.reachable_nodes(), "with the same reachable choices")

	scene._pause_button.pressed.emit()
	await process_frame
	pause_text = _all_text(scene._pause_box)
	check(pause_text.contains("returns you to this map") and not pause_text.contains("start of this"), "the pause overlay at the map says Save & Exit returns to this map")
	_find_button(scene._pause_box, "Save & Exit").pressed.emit()
	await process_frame
	loaded = RunSave.load_file(save_path)
	check(exits[0] == 1 and loaded.run != null and not loaded.run.in_map_stop() and loaded.run.current_node == first, "Save & Exit at the map writes the map position and exits")
	scene._set_paused(false)

	# --- The main menu's Continue offers the map run ---
	scene._show_main_menu()
	await process_frame
	var body: Control = scene.get_node("%Body")
	check(_find_button(body, "Continue") != null and _all_text(body).contains("the crossroads"), "the main menu offers Continue and says the run waits at the crossroads")
	_find_button(body, "Continue").pressed.emit()
	await process_frame
	check(scene._run.uses_map() and scene._run.current_node == first and scene._run.current_stop() == null and not scene._debug_session, "Continue restores the map run at the map")
	check(scene._run.reachable_nodes() == run_state.reachable_nodes(), "with the same reachable choices")
	check(body.find_children("*", "MapView", true, false).size() == 1, "and the map is on screen")

	# Continue inside a stop restores the stop.
	var second: int = scene._run.reachable_nodes()[0]
	scene._on_node_chosen(second)
	await process_frame
	scene._show_main_menu()
	await process_frame
	check(_find_button(body, "Continue") != null and not _all_text(body).contains("the crossroads"), "the Continue panel of a run inside a stop names the place, not the crossroads")
	_find_button(body, "Continue").pressed.emit()
	await process_frame
	check(scene._run.in_map_stop() and scene._run.current_node == second and scene._run.reachable_nodes().is_empty(), "Continue inside a stop resumes in that stop with no road to re-choose")

	# --- Finishing a run deletes exactly its save ---
	check(FileAccess.file_exists(save_path), "setup: a save exists before the run ends")
	scene._run.finished = true
	scene._show_stop()
	await process_frame
	check(not FileAccess.file_exists(save_path) and not FileAccess.file_exists(save_path + ".bak") and not FileAccess.file_exists(save_path + ".tmp"), "a finished map run deletes its save")
	scene.queue_free()
	await process_frame

	# --- A line run is as before ---
	_wipe()
	var line_scene := _new_scene()
	await process_frame
	line_scene._run = RunState.new(9)
	line_scene._reset_screens()
	line_scene._show_stop()
	await process_frame
	var line_loaded := RunSave.load_file(save_path)
	check(line_loaded.run != null and not line_loaded.run.uses_map() and int(RunSave.to_dict(line_loaded.run)["version"]) == 4, "a line run still autosaves in format 4")
	line_scene._pause_button.pressed.emit()
	await process_frame
	check(_all_text(line_scene._pause_box).contains("Save & Exit returns you to the start of this destination."), "the line run's pause text is the original")
	line_scene._set_paused(false)
	line_scene.queue_free()
	await process_frame

	# --- The --map debug session never touches a save; --hp and --gold apply ---
	_wipe()
	var legacy := RunState.new(13)
	check(RunSave.save(legacy, save_path) == "", "setup: a player's line save")
	var before := FileAccess.get_file_as_bytes(save_path)
	var debug_scene := _new_scene()
	await process_frame
	var debug_exits := [0]
	debug_scene.exit_callable = func() -> void: debug_exits[0] += 1
	debug_scene.start_debug_map(DebugLaunch.parse(PackedStringArray(["--map", "--hp=7", "--gold=123"]), {}))
	await process_frame
	check(debug_scene._debug_session and debug_scene._run.uses_map(), "--map starts a map run as a debug session")
	check(debug_scene._run.player.hp == 7 and debug_scene._run.gold == 123, "--hp and --gold apply to --map")
	var big_hp := DebugLaunch.parse(PackedStringArray(["--map", "--hp=99999"]), {})
	debug_scene.start_debug_map(big_hp)
	check(debug_scene._run.player.hp == debug_scene._run.player.max_hp, "--hp above max HP is capped for --map")
	debug_scene.start_debug_map(DebugLaunch.parse(PackedStringArray(["--map"]), {}))
	check(debug_scene._run.gold == RunState.new(1, &"deserter", true).gold, "--map without --gold keeps the run's own gold")
	debug_scene._on_node_chosen(debug_scene._run.reachable_nodes()[0])
	await process_frame
	debug_scene._show_stop()
	debug_scene._pause_button.pressed.emit()
	await process_frame
	_find_button(debug_scene._pause_box, "Save & Exit").pressed.emit()
	await process_frame
	check(debug_exits[0] == 1, "Save & Exit in a --map session exits without a save")
	debug_scene._set_paused(false)
	debug_scene._run.finished = true
	debug_scene._show_stop()
	await process_frame
	check(FileAccess.get_file_as_bytes(save_path) == before and RunSave.load_file(save_path).run != null, "a --map session neither writes nor deletes the player's save, even when it ends")
	debug_scene.queue_free()
	await process_frame

	# --- Ambience: the sea only until the first stop is left ---
	_wipe()
	var sea_scene := _new_scene()
	await process_frame
	var sea_run := RunState.new(5, &"deserter", true)
	sea_scene._run = sea_run
	sea_scene._debug_session = true
	sea_scene._reset_screens()
	sea_scene._show_stop()
	await process_frame
	if _ambience() != &"?":
		check(_ambience() == &"coastal", "the sea plays at the map before the first choice")
		sea_scene._on_node_chosen(sea_run.reachable_nodes()[0])
		await process_frame
		check(_ambience() == &"coastal", "and inside the first row's stop")
		var first_stop := sea_run.current_stop()
		match first_stop.type:
			RunState.StopType.COMBAT:
				sea_run.complete_combat(true)
				if sea_run.reward_pending():
					sea_run.resolve_reward(null)
			RunState.StopType.REST:
				sea_run.rest()
			RunState.StopType.STORY:
				sea_run.read_story()
			RunState.StopType.VENDOR:
				sea_run.leave_vendor()
		sea_scene._show_stop()
		await process_frame
		check(sea_run.stop_index == 0 and sea_run.current_stop() == null and _ambience() == &"", "the sea stops once the first stop is left, though the row is still 0")
	else:
		print("skipped: no audio manager in this run")
	sea_scene.queue_free()
	await process_frame

	_wipe()
	print("DONE fails=", fails)
	quit(1 if fails > 0 else 0)
