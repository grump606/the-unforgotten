extends SceneTree
## Headless UI test for event stops (docs/EVENTS_DESIGN.md): the screen through the real run.tscn (scene text, buttons with
## their printed cost lines, a greyed button with its reason, the outcome and Continue), the pick flows (remove, Remember,
## choose 1 of 3), curses in a picker, the debug launch `--screen=event`, a save resumed inside an event, the map glyph,
## tooltip and legend, and the fit at 800x450. Scratch save paths only. Run via scripts/check.ps1.

var fails := 0
var save_path := "user://ui_event_test_%d.json" % OS.get_process_id()
var settings_path := "user://ui_event_settings_%d.json" % OS.get_process_id()


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


func _open(scene: Control, spec: String, extra: Array[String] = []) -> RunState:
	var args := PackedStringArray(["--screen=" + spec])
	args.append_array(extra)
	scene.start_debug_screen(DebugLaunch.parse(args, {}))
	await process_frame
	await process_frame
	return scene._run


func _initialize() -> void:
	RunSave.delete(save_path)
	await process_frame
	var scene := _scene()
	await process_frame
	var body: Control = scene.get_node("%Body")

	# --- The debug launch opens a named event in a throwaway map run ---
	var run_state := await _open(scene, "event:rain_barrel", ["--character=deserter"])
	body = scene.get_node("%Body")
	check(run_state.uses_map() and run_state.in_event_stop() and run_state.current_event().id == &"rain_barrel", "--screen=event:rain_barrel opens that event")
	check(run_state.visited.size() == run_state.stop_index + 1 and run_state.route.node(run_state.visited[0]).row == 0, "the run stands on a connected path to the event node")
	check(not FileAccess.file_exists(save_path) and scene._debug_session, "a debug event never writes the save")
	check(scene._header.text.contains("A Place Along the Way"), "the header names the stop")
	var text := _all_text(body)
	check(text.contains("The Rain Barrel") and text.contains("A barrel stands under a broken gutter"), "the title and the scene text are shown")
	check(text.contains("Drink") and text.contains("Reach for the bright thing") and text.contains("Walk on"), "all three buttons are shown")
	check(text.contains("Heal 25% max HP") and text.contains("Gain 20 gold. Lose 3 HP"), "each button prints its cost and reward")
	check(_find(body, "EventCard") != null and body.find_children("*", "EventScene", true, false).size() == 1, "the card sits over the dimmed scene")
	check(not text.contains("Continue"), "no Continue before a choice")

	# --- Pressing a button shows the outcome and Continue ---
	var hp := run_state.player.hp
	_press(scene, "ChoiceButton0")
	await process_frame
	await process_frame
	body = scene.get_node("%Body")
	text = _all_text(body)
	check(run_state.player.hp > hp and run_state.event_resolved(), "Drink heals")
	check(text.contains("The water tastes of stone and old iron") and text.contains("You recover"), "the outcome text and the result line are shown")
	check(not text.contains("Walk on") and _find(body, "ContinueButton") != null, "the buttons give way to Continue")
	_press(scene, "ContinueButton")
	await process_frame
	check(run_state.current_stop() == null and run_state.at_stop_boundary(), "Continue leaves for the map")
	check(_find(scene.get_node("%Body"), "MapView") != null, "the map is shown after an event")

	# --- A greyed button with its reason ---
	run_state = await _open(scene, "event:name_broker", ["--gold=10"])
	body = scene.get_node("%Body")
	var buy := _find(body, "ChoiceButton0") as Button
	check(buy != null and buy.disabled, "Buy a keepsake is greyed at 10 gold")
	var reason := _find(body, "ChoiceReason0") as Label
	check(reason != null and reason.text.contains("70") and reason.text.contains("10"), "the reason is printed under it")
	check(_find(body, "ChoiceSummary0") != null and (_find(body, "ChoiceSummary0") as Label).text == "Pay 70 gold. Gain a random neutral relic", "its cost line is still shown")
	check(not (_find(body, "ChoiceButton1") as Button).disabled and not (_find(body, "ChoiceButton2") as Button).disabled, "the others stay enabled")
	_press(scene, "ChoiceButton0")
	await process_frame
	check(not run_state.event_resolved() and run_state.gold == 10, "pressing the greyed button does nothing")
	_press(scene, "ChoiceButton2")
	await process_frame
	await process_frame
	check(run_state.event_resolved() and _find(scene.get_node("%Body"), "ContinueButton") != null, "walking away is always possible")

	# --- Gamble odds are printed ---
	run_state = await _open(scene, "event:bell_in_the_well", ["--character=thief"])
	text = _all_text(scene.get_node("%Body"))
	check(text.contains("40%") and text.contains("Pay 25 gold") and text.contains("50%"), "a gamble prints its odds, and the Thief sees her own price")

	# --- Choose 1 of 3 ---
	run_state = await _open(scene, "event:hound_at_the_fence", ["--character=stray"])
	text = _all_text(scene.get_node("%Body"))
	check(text.contains("It smells of your own kennel") and text.contains("Press your nose to its nose"), "the Stray sees her own opening and her own button")
	var deck_before := run_state.deck.size()
	_press(scene, "ChoiceButton1")
	await process_frame
	await process_frame
	body = scene.get_node("%Body")
	var offers := body.find_children("*", "CardView", true, false)
	check(run_state.event_followup() == &"pick" and offers.size() == 3 and _find(body, "PickRow") != null, "cutting the wire offers three cards")
	check(not _all_text(body).contains("Continue"), "no Continue while a card is owed")
	(offers[0] as CardView).pressed.emit()
	await process_frame
	await process_frame
	check(run_state.deck.size() == deck_before + 1 and run_state.event_followup() == &"" and _find(scene.get_node("%Body"), "ContinueButton") != null, "taking a card adds it and shows Continue")

	# --- Remove, with a curse among the cards ---
	run_state = await _open(scene, "event:scraped_plaques", ["--character=medium"])
	run_state.deck.append(StarterContent.status_card(&"dread"))
	run_state.deck.append(StarterContent.status_card(&"murmur"))
	scene._show_stop()
	await process_frame
	_press(scene, "ChoiceButton0")
	await process_frame
	await process_frame
	body = scene.get_node("%Body")
	var cards := body.find_children("*", "CardView", true, false)
	check(run_state.event_followup() == &"remove" and cards.size() == run_state.deck.size() and _find(body, "PickerScroll") != null, "removal shows the whole deck, curses included (%d cards)" % cards.size())
	var picker_text := _all_text(body)
	check(not picker_text.contains("Cancel"), "the picker has no Cancel once the price is paid")
	var deck_size := run_state.deck.size()
	(cards[cards.size() - 2] as CardView).pressed.emit() # the Dread
	await process_frame
	await process_frame
	check(run_state.deck.size() == deck_size - 1 and not run_state.deck.any(func(c: CardData) -> bool: return c.id == &"dread"), "the Dread is removed from the deck")
	_press(scene, "ContinueButton")
	await process_frame

	# --- Remember ---
	run_state = await _open(scene, "event:unsent_letters", ["--character=medium"])
	text = _all_text(scene.get_node("%Body"))
	check(text.contains("Answer the writers"), "the Medium can answer the writers")
	_press(scene, "ChoiceButton0")
	await process_frame
	await process_frame
	body = scene.get_node("%Body")
	var remember_cards := body.find_children("*", "CardView", true, false)
	check(run_state.event_followup() == &"remember" and remember_cards.size() == run_state.event_remember_indices().size() and remember_cards.size() > 0, "Remember offers the cards that can be")
	(remember_cards[0] as CardView).pressed.emit()
	await process_frame
	await process_frame
	var upgraded := false
	for card in run_state.deck:
		upgraded = upgraded or card.is_remembered
	check(upgraded and run_state.event_followup() == &"", "the card came back Remembered")
	_press(scene, "ContinueButton")
	await process_frame

	# --- A random event ---
	run_state = await _open(scene, "event")
	check(run_state.in_event_stop() and run_state.current_event() != null and _find(scene.get_node("%Body"), "EventTitle") != null, "--screen=event opens some event")

	# --- A real (saved) event: resume shows the same event ---
	var real := RunState.new(41, &"thief", true)
	var guard := 0
	while not real.in_event_stop() and guard < 60:
		guard += 1
		var options := real.reachable_nodes()
		var pick: int = options[0]
		for id in options:
			if real.route.node(id).type == RouteMap.NodeType.EVENT:
				pick = id
		real.choose_node(pick)
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
			RunState.StopType.TREASURE:
				real.open_treasure()
				real.take_treasure()
	check(real.in_event_stop(), "a real run reached an event")
	scene.exit_callable = func() -> void: pass
	scene._run = real
	scene._debug_session = false
	scene._reset_screens()
	scene._show_stop()
	await process_frame
	await process_frame
	var saved := RunSave.load_file(save_path)
	check(saved.run != null and saved.run.in_event_stop() and saved.run.at_stop_boundary(), "arriving at an event saves the unopened stop")
	var shown := real.current_event()
	check(_all_text(scene.get_node("%Body")).contains(shown.title), "the screen shows the rolled event")
	check(not real.at_stop_boundary(), "an open event is not a boundary")
	check(scene._save_and_exit() == "", "Save & Exit inside an event keeps the arrival save")
	var again := RunSave.load_file(save_path)
	check(again.run != null and again.run.in_event_stop() and again.run.events_seen.is_empty(), "the save on disk is still the arrival save")
	scene._continue_run(again.run)
	await process_frame
	await process_frame
	check(again.run.current_event() == shown and _all_text(scene.get_node("%Body")).contains(shown.title), "Continue shows the same event")
	scene.queue_free()
	await process_frame

	# --- The map glyph, tooltip, legend and the plain list ---
	var route := RouteMap.generate(5, &"deserter")
	var event_id := -1
	for n in route.nodes:
		if n.type == RouteMap.NodeType.EVENT and n.act == 0:
			event_id = n.id
			break
	var view := MapView.new()
	view.size = Vector2(1152, 648)
	root.add_child(view)
	view.set_data(route, [] as Array[int], -1, route.starts(), &"deserter")
	await process_frame
	check(event_id >= 0 and view.tooltip_for(event_id) == "Event: something unexpected", "the event tooltip is 'Event: something unexpected'")
	var glyph_colours := {}
	for type in [RouteMap.NodeType.FIGHT, RouteMap.NodeType.REST, RouteMap.NodeType.SHOP, RouteMap.NodeType.TREASURE, RouteMap.NodeType.STORY]:
		glyph_colours[view._glyph_color(type).to_html()] = true
	check(not glyph_colours.has(view._glyph_color(RouteMap.NodeType.EVENT).to_html()), "the event glyph colour differs from every other node's")
	check(event_id >= 0 and FallbackMapScreen.describe(route.node(event_id)) == "Event", "the plain map list names an event")
	var legend_has_event := false
	for pair in [[RouteMap.NodeType.EVENT, "Event"]]:
		legend_has_event = FileAccess.get_file_as_string("res://run/map_view.gd").contains('[RouteMap.NodeType.EVENT, "Event"]')
	check(legend_has_event, "the legend lists Event")
	view.queue_free()
	await process_frame

	# --- The card fits a small window, long text and four buttons included ---
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var small := _scene()
	await process_frame
	root.size = Vector2i(800, 450)
	await process_frame
	await process_frame
	small.start_debug_screen(DebugLaunch.parse(PackedStringArray(["--screen=event:stopped_kitchen", "--character=deserter", "--gold=3"]), {}))
	for i in 4:
		await process_frame
	var small_body: Control = small.get_node("%Body")
	var card := _find(small_body, "EventCard") as Control
	check(card != null and small_body.get_global_rect().grow(2.0).encloses(card.get_global_rect()), "the card stays inside the body at 800x450 (card %s, body %s)" % [card.get_global_rect() if card != null else "none", small_body.get_global_rect()])
	check(_find(small_body, "EventScroll") != null, "the card scrolls if it cannot fit")
	small.queue_free()
	await process_frame
	print("ui event test: %d failure(s)" % fails)
	RunSave.delete(save_path)
	DirAccess.remove_absolute(settings_path)
	quit(1 if fails > 0 else 0)
