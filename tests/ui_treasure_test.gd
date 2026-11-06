extends SceneTree
## Headless UI test for the treasure stop (docs/MAP_DESIGN.md "Phase 4b"): the screen through the real run.tscn
## (closed chest, Open the chest, the relic shown with RelicView, Take it, the gold fallback), the debug launch
## `--screen=treasure`, the map glyph and tooltip, the legend and the fallback map list. Scratch save paths only.
## Run via scripts/check.ps1.

var fails := 0
var save_path := "user://ui_treasure_test_%d.json" % OS.get_process_id()
var settings_path := "user://ui_treasure_settings_%d.json" % OS.get_process_id()


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
	if node is Button:
		text += (node as Button).text + "\n"
	for child in node.get_children():
		text += _all_text(child)
	return text


func _find(node: Node, node_name: String) -> Node:
	if node.name == node_name:
		return node
	for child in node.get_children():
		var found := _find(child, node_name)
		if found != null:
			return found
	return null


func _scene() -> Control:
	var scene: Control = load("res://run.tscn").instantiate()
	scene.save_path = save_path
	scene.settings_path = settings_path
	root.add_child(scene)
	return scene


func _press(scene: Control, button_name: String) -> void:
	var button := _find(scene.get_node("%Body"), button_name) as Button
	if button != null:
		button.pressed.emit()


func _initialize() -> void:
	RunSave.delete(save_path)
	await process_frame
	var scene := _scene()
	await process_frame

	# --- The debug launch opens a chest in a throwaway map run ---
	var launch := DebugLaunch.parse(PackedStringArray(["--screen=treasure", "--character=thief"]), {})
	scene.start_debug_screen(launch)
	await process_frame
	var body: Control = scene.get_node("%Body")
	var run_state: RunState = scene._run
	check(run_state.uses_map() and run_state.in_treasure_stop() and run_state.stop_index == 6, "--screen=treasure opens the first act's chest")
	check(run_state.visited.size() == 7 and run_state.route.node(run_state.visited[0]).row == 0, "the run stands on a connected path to it")
	check(not FileAccess.file_exists(save_path), "a debug chest never writes the save")
	check(scene._debug_session, "the launch is a debug session")
	var text := _all_text(body)
	check(text.contains("Open the chest") and not text.contains("Take it"), "the closed chest offers only Open the chest")
	check(_find(body, "TreasureCard") != null and _find(body, "OpenButton") != null and _find(body, "TreasureRelic") == null, "the closed screen has the card and the open button, no relic")
	check(scene._header.text.contains("Treasure"), "the header names the stop")
	var scenes := body.find_children("*", "TreasureScene", true, false)
	check(scenes.size() == 1 and not (scenes[0] as TreasureScene).opened, "a closed chest is drawn")

	# --- Opening reveals the relic with its badge, name and description ---
	_press(scene, "OpenButton")
	await process_frame
	body = scene.get_node("%Body")
	var relic := run_state.treasure_relic()
	check(run_state.treasure_opened() and relic != null, "pressing Open the chest opens it")
	text = _all_text(body)
	check(text.contains(relic.display_name) and text.contains(relic.description) and text.contains("Take it") and not text.contains("Open the chest"), "the opened chest shows the relic and Take it")
	var views := RelicView.find_all(body)
	check(views.size() >= 1 and _find(body, "TreasureRelic") is RelicView and (_find(body, "TreasureRelic") as RelicView).relic == relic, "the relic is drawn with RelicView")
	scenes = body.find_children("*", "TreasureScene", true, false)
	check(scenes.size() == 1 and (scenes[0] as TreasureScene).opened, "an opened chest is drawn")
	check(not run_state.relics.has(relic), "the relic is not yet owned")

	# --- Taking it adds the relic and leaves the stop ---
	_press(scene, "TakeButton")
	await process_frame
	check(run_state.relics.has(relic) and run_state.current_stop() == null and not run_state.treasure_opened(), "Take it adds the relic and leaves the stop")
	check(not _all_text(scene.get_node("%Body")).contains("Take it"), "the screen moved on to the map")

	# --- The second act's chest, and the gold fallback ---
	scene.start_debug_screen(DebugLaunch.parse(PackedStringArray(["--screen=treasure:2"]), {}))
	await process_frame
	run_state = scene._run
	check(run_state.in_treasure_stop() and run_state.stop_index == 22 and run_state.route.node(run_state.current_node).act == 1, "treasure:2 opens the second act's chest")
	run_state.relics.assign(StarterContent.relic_pool(run_state.character.id))
	scene._show_stop()
	await process_frame
	_press(scene, "OpenButton")
	await process_frame
	text = _all_text(scene.get_node("%Body"))
	check(run_state.treasure_relic() == null and text.contains("%d gold" % RunState.TREASURE_FALLBACK_GOLD) and text.contains("Take the gold"), "a character with every relic is offered gold, and told so")
	var gold := run_state.gold
	_press(scene, "TakeButton")
	await process_frame
	check(run_state.gold == gold + RunState.TREASURE_FALLBACK_GOLD and run_state.current_stop() == null, "taking the gold pays it and leaves")

	# --- A real (saved) chest: Continue at the closed chest, open, quit, resume to the same relic ---
	var real := RunState.new(41, &"medium", true)
	while not real.in_treasure_stop():
		real.choose_node(real.reachable_nodes()[0])
		match real.current_stop().type:
			RunState.StopType.COMBAT:
				real.complete_combat(true)
				if real.reward_pending():
					real.resolve_reward(null)
			RunState.StopType.REST:
				real.rest()
			RunState.StopType.STORY:
				real.read_story()
			RunState.StopType.VENDOR:
				real.leave_vendor()
	scene._run = real
	scene._debug_session = false
	scene.exit_callable = func() -> void: pass
	scene._reset_screens()
	scene._show_stop()
	await process_frame
	var saved := RunSave.load_file(save_path)
	check(saved.run != null and saved.run.in_treasure_stop() and not saved.run.treasure_opened(), "arriving at a chest saves the closed chest")
	_press(scene, "OpenButton")
	await process_frame
	var shown := real.treasure_relic()
	check(real.treasure_opened() and not real.at_stop_boundary(), "the opened chest is not a boundary")
	check(scene._save_and_exit() == "", "Save & Exit inside an open chest keeps the arrival save")
	saved = RunSave.load_file(save_path)
	check(saved.run != null and saved.run.in_treasure_stop() and not saved.run.treasure_opened(), "the save on disk is still the closed chest")
	saved.run.open_treasure()
	check(saved.run.treasure_relic() == shown, "resuming and opening shows the same relic")
	scene.queue_free()
	await process_frame

	# --- The map glyph, tooltip, legend and the plain list ---
	var route := RouteMap.generate(5, &"deserter")
	var chest_id := route.row_nodes(6)[0].id
	var view := MapView.new()
	view.size = Vector2(1152, 648)
	root.add_child(view)
	var starts := route.starts()
	view.set_data(route, [] as Array[int], -1, starts, &"deserter")
	await process_frame
	check(view.tooltip_for(chest_id) == "Treasure: a relic", "the chest tooltip is 'Treasure: a relic'")
	check(view._glyph_color(RouteMap.NodeType.TREASURE) != view._glyph_color(RouteMap.NodeType.SHOP) and view._glyph_color(RouteMap.NodeType.TREASURE) != view._glyph_color(RouteMap.NodeType.REST), "the chest glyph colour differs from the coin and the armchair")
	check(FallbackMapScreen.describe(route.node(chest_id)) == "Treasure", "the plain map list names a chest")
	view.queue_free()
	await process_frame
	print("ui treasure test: %d failure(s)" % fails)
	RunSave.delete(save_path)
	DirAccess.remove_absolute(settings_path)
	quit(1 if fails > 0 else 0)
