extends SceneTree
## Headless UI test for the chapter break (docs/CHAPTERS_DESIGN.md): a won end boss shows its spoils (a boss relic and gold,
## no card choice), taking them opens the End of Chapter screen, and Begin Chapter 2 starts the next map. Scratch save
## paths only. Run via scripts/check.ps1.

var fails := 0
var save_path := "user://ui_chapter_break_test_%d.json" % OS.get_process_id()
var settings_path := "user://ui_chapter_break_settings_%d.json" % OS.get_process_id()


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


func _press(scene: Control, button_name: String) -> void:
	var button := _find(scene.get_node("%Body"), button_name) as Button
	if button != null:
		button.pressed.emit()


func _initialize() -> void:
	RunSave.delete(save_path)
	Chapters.count_override = 2
	await process_frame
	var scene: Control = load("res://run.tscn").instantiate()
	scene.save_path = save_path
	scene.settings_path = settings_path
	root.add_child(scene)
	await process_frame
	scene.start_debug_screen(DebugLaunch.parse(PackedStringArray(["--screen=elite", "--character=deserter"]), {}))
	await process_frame
	await process_frame
	var run_state: RunState = scene._run
	# Stand inside the end boss's stop, the first road of every row visited.
	var path: Array[int] = []
	var id := -1
	for row in RouteMap.ROWS:
		id = run_state.route.starts()[0] if row == 0 else run_state.route.next_ids(id)[0]
		path.append(id)
	run_state.restore_map(run_state.route, id, path, true)
	check(run_state.current_stop().boss, "standing in the end boss's stop")
	var gold := run_state.gold
	run_state.complete_combat(true)
	scene._show_stop()
	await process_frame
	var body: Control = scene.get_node("%Body")
	var text := _all_text(body)
	check(text.contains("Chapter 1 complete") and text.contains("+%d gold" % RunState.END_BOSS_GOLD), "the spoils panel names the chapter and the gold")
	var relic := run_state.boss_relic()
	check(relic != null and text.contains(relic.display_name) and text.contains("Take it"), "it offers the boss relic")
	check(CardView.find_all(body).is_empty() and not text.contains("Skip"), "no card choice")
	check(run_state.gold == gold + RunState.END_BOSS_GOLD, "the gold is paid on the win")
	_press(scene, "TakeSpoilsButton")
	await process_frame
	body = scene.get_node("%Body")
	text = _all_text(body)
	check(run_state.relics.has(relic) and run_state.chapter_break, "taking it grants the relic and opens the break")
	check(text.contains("End of Chapter 1") and text.contains("Begin Chapter 2"), "the break screen names both chapters")
	check(_find(body, "BreakSummary") != null and text.contains("Deck: %d cards" % run_state.deck.size()), "it shows a run summary")
	run_state.player.hp = 5
	var max_hp := run_state.player.max_hp
	_press(scene, "BeginChapterButton")
	await process_frame
	await process_frame
	check(run_state.chapter == 2 and not run_state.chapter_break and run_state.current_node == -1, "Begin Chapter 2 starts the new map")
	check(run_state.player.hp == mini(max_hp, 5 + roundi(max_hp * RunState.CHAPTER_BREAK_HEAL_FRACTION)), "with the break heal")
	check(scene._header.text.contains("Chapter 2"), "the header names the chapter")
	check(not run_state.reachable_nodes().is_empty(), "the map offers first choices")

	print("ui chapter break test: %d failure(s)" % fails)
	Chapters.count_override = 0
	RunSave.delete(save_path)
	DirAccess.remove_absolute(settings_path)
	quit(1 if fails > 0 else 0)
