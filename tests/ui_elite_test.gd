extends SceneTree
## Headless UI test for elite fights (docs/MAP_DESIGN.md "Phase 5a"): the debug launch `--screen=elite`, the battle
## screen (the "Elite fight" log line, enemies drawn larger and named Elite ...), and the reward screen's two halves
## (the spoils panel with the relic and Take it, then the usual card choice), plus the gold fallback. Scratch save paths
## only. Run via scripts/check.ps1.

var fails := 0
var save_path := "user://ui_elite_test_%d.json" % OS.get_process_id()
var settings_path := "user://ui_elite_settings_%d.json" % OS.get_process_id()


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

	# --- The debug launch puts a throwaway map run at an elite fight ---
	scene.start_debug_screen(DebugLaunch.parse(PackedStringArray(["--screen=elite", "--character=deserter"]), {}))
	await process_frame
	await process_frame
	var run_state: RunState = scene._run
	check(run_state.uses_map() and run_state.in_elite_stop() and run_state.current_stop().type == RunState.StopType.COMBAT, "--screen=elite opens an elite fight")
	check(run_state.route.node(run_state.current_node).act == 0, "the first act's elite")
	check(not FileAccess.file_exists(save_path) and scene._debug_session, "a debug elite never writes the save")

	# --- The battle: the log line, larger and renamed enemies ---
	var body: Control = scene.get_node("%Body")
	var battle: Control = body.get_child(0)
	check(battle.elite_fight and not battle.boss_fight, "the battle knows it is an elite fight")
	check(battle._log_label.get_parsed_text().contains("Elite fight"), "the log opens with 'Elite fight'")
	var combat: Combat = battle._combat
	var views: Array[Fighter] = battle.enemy_views()
	check(views.size() == combat.enemies.size() and views.size() >= 2, "an elite fight has two or more enemies on stage")
	var all_elite := true
	var all_named := true
	for i in views.size():
		all_elite = all_elite and views[i].is_elite and is_equal_approx(views[i].figure_height, views[i].base_height * Fighter.ELITE_SCALE)
		all_named = all_named and combat.enemies[i].data.display_name.begins_with(StarterContent.ELITE_NAME_PREFIX)
	check(all_elite, "every elite enemy is drawn ELITE_SCALE larger")
	check(all_named, "every elite enemy is named Elite ...")
	var regular := Fighter.new()
	regular.set_enemy(combat.enemies[0], false, false)
	check(views[0].figure_height > regular.figure_height, "an elite figure is taller than the same enemy as a regular one")
	regular.free()

	# --- A regular fight is unchanged ---
	var plain := RunState.new(5, &"deserter", true)
	check(not plain.in_elite_stop(), "a fresh map run is not at an elite")

	# --- Winning: the spoils panel first, then the card choice ---
	var gold_before := run_state.gold
	var relics_before := run_state.relics.size()
	run_state.complete_combat(true)
	scene._show_stop()
	await process_frame
	body = scene.get_node("%Body")
	var text := _all_text(body)
	check(run_state.elite_spoils_pending() and text.contains("Elite spoils") and text.contains("+%d gold" % RunState.ELITE_GOLD_BONUS), "the reward opens on the elite spoils with the bonus gold")
	var relic := run_state.elite_relic()
	check(relic != null and text.contains(relic.display_name) and text.contains(relic.description) and text.contains("Take it"), "the spoils name the relic and offer Take it")
	check(_find(body, "SpoilsRelic") is RelicView and (_find(body, "SpoilsRelic") as RelicView).relic == relic, "the relic is drawn with RelicView")
	check(CardView.find_all(body).is_empty() and not text.contains("Skip"), "no card choice yet")
	check(run_state.gold >= gold_before + RunState.ELITE_GOLD_BONUS and run_state.relics.size() == relics_before, "the relic is not owned until it is taken")
	_press(scene, "TakeSpoilsButton")
	await process_frame
	body = scene.get_node("%Body")
	text = _all_text(body)
	check(run_state.relics.has(relic) and not run_state.elite_spoils_pending(), "Take it adds the relic")
	check(run_state.reward_pending() and not CardView.find_all(body).is_empty() and text.contains("Skip"), "the usual card choice follows")
	check(not text.contains("Elite spoils"), "the spoils panel is gone")

	# --- The gold fallback: every relic already owned ---
	scene.start_debug_screen(DebugLaunch.parse(PackedStringArray(["--screen=elite:2", "--character=thief"]), {}))
	await process_frame
	await process_frame
	run_state = scene._run
	check(run_state.in_elite_stop() and run_state.route.node(run_state.current_node).act == 1, "--screen=elite:2 opens the second act's elite")
	run_state.relics.assign(StarterContent.relic_pool(&"thief"))
	var gold := run_state.gold
	run_state.complete_combat(true)
	scene._show_stop()
	await process_frame
	body = scene.get_node("%Body")
	text = _all_text(body)
	check(text.contains("every keepsake") and text.contains("%d gold" % RunState.ELITE_RELIC_FALLBACK_GOLD) and text.contains("Take the gold"), "with every relic owned the spoils offer gold")
	check(_find(body, "SpoilsRelic") == null, "no relic is drawn")
	var gold_mid := run_state.gold
	_press(scene, "TakeSpoilsButton")
	await process_frame
	check(run_state.gold == gold_mid + RunState.ELITE_RELIC_FALLBACK_GOLD and gold_mid > gold, "Take the gold pays the fallback")

	print("ui elite test: %d failure(s)" % fails)
	RunSave.delete(save_path)
	DirAccess.remove_absolute(settings_path)
	quit(1 if fails > 0 else 0)
