extends SceneTree
## Headless test for the debug screen launch (run/debug_launch.gd, run.gd start_debug_screen): a shop and a
## rest stop open with gold in hand and the player hurt, and a debug session never writes or removes a save.
## Run via scripts/check.ps1.

var fails := 0
var test_save := "user://ui_debug_screen_test_save_%d.json" % OS.get_process_id()


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


func _scene() -> Control:
	var scene: Control = load("res://run.tscn").instantiate()
	scene.save_path = test_save
	root.add_child(scene)
	return scene


func _initialize() -> void:
	RunSave.delete(test_save)
	var scene := _scene()
	await process_frame

	var vendor := DebugLaunch.parse(PackedStringArray(["--screen=vendor", "--character=medium"]), {})
	scene.start_debug_screen(vendor)
	await process_frame
	var body: Control = scene.get_node("%Body")
	check(scene._run.current_stop().type == RunState.StopType.VENDOR, "the shop stop is open")
	check(scene._run.gold == DebugLaunch.DEFAULT_GOLD, "the shop starts with the default gold")
	check(scene._run.player.hp < scene._run.player.max_hp and scene._run.player.hp > 0, "the player starts hurt")
	var text := _all_text(body)
	check(text.contains("Heal") and text.contains("Remove a card") and text.contains("Leave"), "the shop shows its services")
	check(not FileAccess.file_exists(test_save), "a debug shop never writes the save")

	var rest := DebugLaunch.parse(PackedStringArray(["--screen=rest", "--gold=7", "--hp=5", "--character=deserter"]), {})
	scene.start_debug_screen(rest)
	await process_frame
	check(scene._run.current_stop().type == RunState.StopType.REST, "the rest stop is open")
	check(scene._run.gold == 7 and scene._run.player.hp == 5, "explicit gold and hp are used")
	check(_all_text(scene.get_node("%Body")).contains("Rest"), "the rest screen offers resting")
	check(not FileAccess.file_exists(test_save), "a debug rest never writes the save")

	var second := DebugLaunch.parse(PackedStringArray(["--screen=vendor:2"]), {})
	scene.start_debug_screen(second)
	await process_frame
	var first_index := 0
	for index in scene._run.stops.size():
		if scene._run.stops[index].type == RunState.StopType.VENDOR:
			first_index = index
			break
	check(scene._run.stop_index > first_index and scene._run.current_stop().type == RunState.StopType.VENDOR, "vendor:2 opens a later shop")

	# The character select and the end card open directly too.
	scene.start_debug_screen(DebugLaunch.parse(PackedStringArray(["--screen=select"]), {}))
	await process_frame
	check(_all_text(scene.get_node("%Body")).contains("Play as"), "--screen=select shows the character select")
	scene.start_debug_screen(DebugLaunch.parse(PackedStringArray(["--screen=end"]), {}))
	await process_frame
	check(_all_text(scene.get_node("%Body")).contains("Escaped") and not FileAccess.file_exists(test_save), "--screen=end shows the escaped end card and writes no save")
	scene.start_debug_screen(DebugLaunch.parse(PackedStringArray(["--screen=defeat"]), {}))
	await process_frame
	check(_all_text(scene.get_node("%Body")).contains("Defeated"), "--screen=defeat shows the defeat card")

	# Pause > Save & Exit in a debug session leaves without writing a save.
	var exits := [0]
	scene.exit_callable = func() -> void: exits[0] += 1
	scene._save_and_exit()
	check(exits[0] == 1 and not FileAccess.file_exists(test_save), "Save & Exit in a debug session exits and writes nothing")

	# Back at the main menu the session is over: a real run saves again.
	scene._show_main_menu()
	check(not scene._debug_session, "the menu ends the debug session")

	RunSave.delete(test_save)
	print("\nFAILURES: %d" % fails)
	quit(1 if fails > 0 else 0)
