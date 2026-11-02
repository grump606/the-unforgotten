extends SceneTree
## Headless test of the run screen glue (run.gd + the battle embedded by it): it
## plays whole runs through the real run.tscn buttons, with every enemy set to 1 HP
## so a run can finish, and checks that each hand-off actually happens. Catches
## a view that forgets to call into RunState (the rules tests cannot see that).
## Run via scripts/check.ps1.

## Scratch save path: the developer's real user://run_save.json must never be touched.
var test_save := "user://ui_flow_test_save_%d.json" % OS.get_process_id()

var _failures := 0


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAIL: " + label)


func _buttons(node: Node, out: Array) -> void:
	if node is Button and (node as Button).visible:
		out.append(node)
	for child in node.get_children():
		_buttons(child, out)


func _all_text(node: Node) -> String:
	var text := ""
	if node is Label:
		text += (node as Label).text + "\n"
	for child in node.get_children():
		text += _all_text(child)
	return text


## Children of the body that are panels: the art scenes drawn behind a panel (ScreenScene) do not count.
func _panel_count(body: Node) -> int:
	var count := 0
	for child in body.get_children():
		if not child is ScreenScene:
			count += 1
	return count


func _find_panels(node: Node, out: Array[CharacterPanel]) -> void:
	if node is CharacterPanel:
		out.append(node)
	for child in node.get_children():
		_find_panels(child, out)


func _first_scroll(node: Node) -> ScrollContainer:
	if node is ScrollContainer:
		return node
	for child in node.get_children():
		var found := _first_scroll(child)
		if found != null:
			return found
	return null


func _first_enabled(body: Node) -> Button:
	var found: Array = []
	_buttons(body, found)
	for button in found:
		if not (button as Button).disabled:
			return button
	return null


## The first card view that a click would act on (the card equivalent of an enabled button).
func _first_card(body: Node) -> CardView:
	for view in CardView.find_all(body):
		if view.is_clickable():
			return view
	return null


func _find(body: Node, prefix: String) -> Button:
	var found: Array = []
	_buttons(body, found)
	for button in found:
		if (button as Button).text.begins_with(prefix) and not (button as Button).disabled:
			return button
	return null


func _initialize() -> void:
	RunSave.delete(test_save)
	var scene: Control = load("res://run.tscn").instantiate()
	scene.save_path = test_save
	root.add_child(scene)
	await process_frame
	var body: Control = scene.get_node("%Body")
	var header: Label = scene.get_node("%HeaderLabel")

	# Launch opens the main menu: New Run and Exit, and no Continue without a save.
	_check(scene._run == null and header.text.contains("A voice beyond the quiet"), "launch opens the main menu")
	_check(not scene._pause_button.visible, "no Pause button on the main menu")
	_check(_find(body, "New Journey") != null and _find(body, "Exit") != null and _find(body, "Continue") == null, "the main menu offers New Run and Exit, and no Continue without a save")
	_check(_count_buttons(body, "Play as") == 0, "the main menu does not show the characters yet")
	var exits_fresh := [0]
	scene.exit_callable = func() -> void: exits_fresh[0] += 1
	_find(body, "Exit").pressed.emit()
	_check(exits_fresh[0] == 1, "Exit leaves the game")
	_find(body, "New Journey").pressed.emit()
	await process_frame
	_check(scene._run == null and header.text.contains("Choose who answers the voice"), "New Run opens the character select screen")
	_check(not scene._pause_button.visible, "no Pause button on the select screen")
	_check(_count_buttons(body, "Play as") == 3, "the select screen offers three characters")
	_check(_find(body, "Back") != null, "the select screen has a Back button")
	_find(body, "Back").pressed.emit()
	await process_frame
	_check(header.text.contains("A voice beyond the quiet") and _find(body, "New Journey") != null and _count_buttons(body, "Play as") == 0, "Back returns to the main menu")
	_find(body, "New Journey").pressed.emit()
	await process_frame
	var select_text := _all_text(body)
	for id in StarterContent.character_ids():
		var character := StarterContent.character(id)
		_check(select_text.contains(character.display_name) and select_text.contains("%d HP" % character.max_hp) and select_text.contains(character.pitch), "the select screen shows %s with HP and pitch" % id)
	_check(select_text.contains("3 Shove") and select_text.contains("Starting deck"), "the select screen shows each starting deck")
	# One bordered panel per character, the group centred in the window, a focusable Play button each.
	await process_frame
	var panels: Array[CharacterPanel] = []
	_find_panels(body, panels)
	_check(panels.size() == StarterContent.character_ids().size(), "the select screen has one panel per character")
	var group := Rect2()
	for i in panels.size():
		var panel := panels[i]
		_check(panel.character_id == StarterContent.character_ids()[i], "panel %d is %s, in selection order" % [i, StarterContent.character_ids()[i]])
		_check(panel.border_color().a > 0.0 and CharacterPanel.BORDER_WIDTH > 0 and panel.class_id == panel.character_id, "%s has a border in its class palette" % panel.character_id)
		_check(panel.play_button.focus_mode == Control.FOCUS_ALL and panel.play_button.text == "Play as %s" % StarterContent.character(panel.character_id).display_name, "%s has a keyboard-focusable Play button" % panel.character_id)
		group = panel.get_global_rect() if i == 0 else group.merge(panel.get_global_rect())
	var window := scene.get_global_rect()
	_check(absf(group.get_center().x - window.get_center().x) <= 3.0 and absf(group.get_center().y - window.get_center().y) <= 3.0, "the panels are centred in the window (group %s, window %s)" % [group, window])
	_check(group.position.x >= 0.0 and group.end.x <= window.end.x and group.position.y >= 0.0 and group.end.y <= window.end.y, "the panels fit inside the window")
	if window.size.is_equal_approx(Vector2(1152, 648)):
		_check(group.end.y <= 602.0, "the panels leave the bottom strip (Back, update notice) clear at 1152x648 (ends at %s)" % group.end.y)
	_check(panels[0].play_button.has_focus(), "the first Play button has keyboard focus on opening")
	panels[1].set_hovered(true)
	_check(panels[1].is_lit() and panels[1].scale.x > 1.0 and panels[1].border_color() != panels[0].border_color(), "a hovered panel lights up")
	panels[1].set_hovered(false)
	_check(not panels[1].is_lit() and panels[1].scale == Vector2.ONE, "an un-hovered panel settles back")
	# A panel built for an unknown, empty or missing character does not error and stays usable.
	var odd := Character.new()
	odd.id = &"nobody"
	for stray in [CharacterPanel.new(odd), CharacterPanel.new(Character.new()), CharacterPanel.new(null)]:
		root.add_child(stray)
		await process_frame
		stray.set_hovered(true)
		await process_frame
		_check(stray.class_id == &"" and stray.size.x > 0.0 and stray.play_button != null, "a panel for an unknown or empty character builds with the neutral palette")
		stray.queue_free()
	_find(body, "Play as The Deserter").pressed.emit()
	await process_frame
	_check(scene._run != null and scene._run.character.id == &"deserter" and scene._run.stop_index == 0, "picking the Deserter starts a Deserter run")
	var run_state: RunState = scene._run
	# What the line holds, so the totals below follow its length instead of a fixed number.
	var line := {"fights": 0, "vendors": 0, "rests": 0, "stories": 0, "mid_bosses": 0}
	for stop in run_state.stops:
		match stop.type:
			RunState.StopType.COMBAT:
				line.fights += 1
				line.mid_bosses += 1 if stop.mid_boss else 0
			RunState.StopType.VENDOR:
				line.vendors += 1
			RunState.StopType.REST:
				line.rests += 1
			_:
				line.stories += 1
	_check(line.fights >= 9 and line.mid_bosses == 1 and run_state.stops.size() >= 20, "the line has a mid-boss and at least eight regular fights (%d fights, %d stops)" % [line.fights, run_state.stops.size()])
	var mid_boss_fought := false
	var mid_boss_continued := false

	var fights_ended := 0
	var rewards := 0
	var vendor_visits := 0
	var stories := 0
	var rests := 0
	var guard := 0
	var last_stop := -1
	var stuck := 0
	while not run_state.finished and guard < 4000:
		guard += 1
		await process_frame
		run_state = scene._run
		# Frames spent at one stop, whatever the panel: a fight takes a few dozen,
		# so hundreds means a hand-off is not happening and the loop would spin.
		if run_state.stop_index == last_stop:
			stuck += 1
		else:
			stuck = 0
		last_stop = run_state.stop_index
		var battle: Node = body.get_child(0) if body.get_child_count() > 0 else null
		if battle != null and battle.has_method("_attach"):
			var combat: Combat = battle._combat
			if combat == null:
				continue
			if combat.turn == 1 and combat.phase == Combat.Phase.PLAYER_TURN:
				var fight_stop := run_state.current_stop()
				if fight_stop.mid_boss:
					mid_boss_fought = true
					_check(combat.enemies.size() == 1 and combat.enemies[0].display_name == "Bellkeeper", "the mid-boss stop fights The Brakeman alone")
					_check(battle.boss_fight and battle._backdrop.boss and header.text.contains("Mid-boss"), "the mid-boss fight has the boss backdrop and says Mid-boss in the header")
				elif fight_stop.boss:
					_check(battle.boss_fight and battle._backdrop.boss and header.text.contains("Boss") and not header.text.contains("Mid-boss"), "the final boss fight has the boss backdrop and says Boss in the header")
				else:
					_check(not battle.boss_fight and not battle._backdrop.boss, "a regular fight has the normal backdrop")
				for enemy in combat.enemies:
					enemy.hp = 1
			if combat.phase == Combat.Phase.PLAYER_TURN:
				# The longer line has tougher fights and the run seed is random: keep the player alive so the
				# run always reaches the end (what is tested here is the hand-offs, not the difficulty).
				combat.player.hp = combat.player.max_hp + 500 # trimmed back when the fight ends
				for enemy in combat.enemies:
					enemy.hp = mini(enemy.hp, 1)
				var played := false
				for i in combat.piles.hand.size():
					if combat.can_play(i):
						battle._play_hand_card(i)
						played = true
						break
				if not played:
					battle._on_end_turn_pressed()
			elif combat.phase == Combat.Phase.ENDED:
				fights_ended += 1
				combat.player.hp = mini(combat.player.hp, combat.player.max_hp)
				var continue_button: Button = battle._new_fight_button
				_check(continue_button.visible and continue_button.text == "Continue", "a finished embedded fight shows Continue")
				_check(battle._result_label.text != "", "a finished fight shows its result")
				var stop_before := run_state.stop_index
				var was_mid_boss := run_state.current_stop().mid_boss
				continue_button.pressed.emit()
				await process_frame
				_check(scene._run.reward_pending() or scene._run.stop_index > stop_before or scene._run.finished, "Continue hands the result to the run")
				if was_mid_boss:
					# Unlike the final boss, the mid-boss pays out and the run goes on.
					mid_boss_continued = true
					_check(scene._run.reward_pending() and not scene._run.finished and scene._run.stop_index == stop_before, "beating the mid-boss goes to the reward screen and the run is not finished")
					_check(header.text.contains("Reward") and not CardView.find_all(body).is_empty() and CardView.find_all(body).size() == scene._run.reward_choices().size(), "the reward screen after the mid-boss offers cards")
			continue
		var stop_type: int = run_state.current_stop().type
		if run_state.reward_pending():
			rewards += 1
			_check(header.text.contains("Reward"), "the header says Reward while a reward is pending")
			var deck_before := run_state.deck.size()
			var reward_buttons: Array = []
			_buttons(body, reward_buttons)
			var skip_label := "Skip (+%d gold)" % RunState.SKIP_GOLD
			var has_skip := false
			for button in reward_buttons:
				has_skip = has_skip or (button as Button).text == skip_label
			_check(has_skip, "the reward panel's Skip button shows its gold")
			var pick_card := _first_card(body)
			var pick_button := _first_enabled(body)  # Skip, when no card is offered
			_check(pick_card != null or pick_button != null, "the reward panel offers a choice")
			_check(CardView.find_all(body).size() == run_state.reward_choices().size(), "the reward panel shows every offered card")
			if pick_card != null:
				pick_card.pressed.emit()
			else:
				pick_button.pressed.emit()
			await process_frame
			_check(scene._run.deck.size() == deck_before + 1 or pick_card == null, "picking a reward adds the card")
		elif stop_type == RunState.StopType.VENDOR:
			vendor_visits += 1
			_check(header.text.contains("Gold %d" % run_state.gold), "the header shows the run's gold")
			var gold_before := run_state.gold
			var offers := run_state.vendor().offers()
			var offer_views := CardView.find_all(body)
			_check(offer_views.size() == offers.size(), "the vendor panel shows every offered card")
			for i in mini(offers.size(), offer_views.size()):
				var can_buy: bool = not offers[i]["sold"] and run_state.gold >= offers[i]["price"]
				_check(offer_views[i].is_clickable() == can_buy, "a vendor card is clickable exactly when it can be bought")
				_check(can_buy or offer_views[i].note == ("SOLD" if offers[i]["sold"] else "NEED %d GOLD" % offers[i]["price"]), "an unbuyable vendor card says why")
			# An offer card the player can afford (clickable); unaffordable and sold ones are dimmed.
			var buy := _first_card(body)
			if buy != null:
				var deck_size := run_state.deck.size()
				buy.pressed.emit()
				await process_frame
				_check(scene._run.deck.size() == deck_size + 1 and scene._run.gold < gold_before, "buying at the vendor panel adds a card and spends gold")
			_find(body, "Leave").pressed.emit()
		elif stop_type == RunState.StopType.REST:
			rests += 1
			var hp_before := run_state.player.hp
			_first_enabled(body).pressed.emit()
			await process_frame
			_check(scene._run.player.hp >= hp_before and scene._run.stop_index > 0, "the rest button rests")
		else:
			stories += 1
			_first_enabled(body).pressed.emit()
		if stuck > 400:
			break

	run_state = scene._run
	_check(guard < 4000 and stuck <= 400, "the run never got stuck at one stop")
	_check(run_state.finished and run_state.escaped, "the run finished with an escape")
	_check(run_state.stop_index == run_state.stops.size(), "every stop was passed")
	_check(fights_ended == line.fights and rewards == line.fights - 1, "every fight ended and every reward but the final boss's was resolved (%d fights, %d rewards, line has %d)" % [fights_ended, rewards, line.fights])
	_check(mid_boss_fought and mid_boss_continued, "the mid-boss stop was reached, fought and followed by the reward screen")
	_check(vendor_visits == line.vendors and rests == line.rests and stories == line.stories, "every vendor, rest and story stop was visited (%d, %d, %d of %d, %d, %d)" % [vendor_visits, rests, stories, line.vendors, line.rests, line.stories])
	_check(_find(body, "New Journey") != null, "the end card offers New Run")
	_check(not FileAccess.file_exists(test_save), "the save is deleted when the run ends")
	var win_text := _all_text(body)
	_check(win_text.contains("Outcome: Escaped") and win_text.contains("Stops cleared: %d/%d" % [run_state.stops.size(), run_state.stops.size()]), "the win summary shows outcome and stops cleared")
	_check(win_text.contains("Final HP: %d/%d" % [run_state.player.hp, run_state.player.max_hp]), "the win summary shows final HP")
	_check(win_text.contains("Deck: %d cards" % run_state.deck.size()) and win_text.contains("Gold: %d" % run_state.gold), "the win summary shows deck size and gold")
	_find(body, "New Journey").pressed.emit()
	await process_frame
	_check(_count_buttons(body, "Play as") == 3 and header.text.contains("Choose who answers the voice"), "New Run on the end card opens the select screen")
	_check(_find(body, "Back") != null, "the select screen reached from the end card has a Back button")
	_find(body, "Back").pressed.emit()
	await process_frame
	_check(_all_text(body).contains("Outcome: Escaped") and _find(body, "Back") == null, "Back on the select screen returns to the end card")
	_find(body, "New Journey").pressed.emit()
	await process_frame
	_check(_count_buttons(body, "Play as") == 3, "New Run still opens the select screen after going Back")
	_find(body, "Play as The Pickpocket").pressed.emit()
	await process_frame
	_check(scene._run.character.id == &"pickpocket" and scene._run.player.max_hp == StarterContent.character(&"pickpocket").max_hp and scene._run.player.display_name == "The Pickpocket", "picking the Pickpocket starts a Pickpocket run")
	_check(scene._run.stop_index == 0 and not scene._run.finished and scene._run.gold == 0, "a character pick starts a fresh run")
	_check(_panel_count(body) == 1, "New Run leaves exactly one panel in the body")
	_check(FileAccess.file_exists(test_save), "a new run is saved at its first stop")

	# Defeat summary.
	var lost := RunState.new(2)
	lost.read_story()
	lost.gold = 21
	lost.player.hp = 0
	lost.finished = true
	scene._run = lost
	scene._show_stop()
	await process_frame
	var loss_text := _all_text(body)
	_check(loss_text.contains("Outcome: Defeated") and loss_text.contains("Stops cleared: 1/%d" % lost.stops.size()) and loss_text.contains("Final HP: 0/%d" % lost.player.max_hp) and loss_text.contains("Gold: 21"), "the loss summary shows the right data")
	_check(not FileAccess.file_exists(test_save), "the save is deleted after a defeat")
	scene.queue_free()
	await process_frame

	# Continue: a valid save is offered, and Continue resumes exactly that run.
	var saved := RunState.new(77)
	saved.read_story()
	saved.gold = 9
	saved.player.hp = 30
	_check(RunSave.save(saved, test_save) == "", "the test run could be saved")
	var resumed_scene: Control = load("res://run.tscn").instantiate()
	resumed_scene.save_path = test_save
	root.add_child(resumed_scene)
	await process_frame
	var resumed_body: Control = resumed_scene.get_node("%Body")
	_check(resumed_scene._run == null and _find(resumed_body, "Continue") != null and _find(resumed_body, "New Journey") != null, "a valid save offers Continue and New Run without starting")
	_find(resumed_body, "New Journey").pressed.emit()
	await process_frame
	_check(_count_buttons(resumed_body, "Play as") == 3 and _find(resumed_body, "Back") != null, "New Run from the Continue prompt shows the select screen with Back")
	_find(resumed_body, "Back").pressed.emit()
	await process_frame
	_check(_find(resumed_body, "Continue") != null and _find(resumed_body, "New Journey") != null and _find(resumed_body, "Back") == null, "Back returns to the Continue prompt")
	_find(resumed_body, "Continue").pressed.emit()
	await process_frame
	var resumed: RunState = resumed_scene._run
	_check(resumed != null and resumed.stop_index == 1 and resumed.gold == 9 and resumed.player.hp == 30, "Continue resumes the saved run")
	_check(_panel_count(resumed_body) == 1, "Continue shows exactly one panel")
	resumed_scene.queue_free()
	await process_frame

	# Every character can be picked, and the header then shows who is playing.
	for id in StarterContent.character_ids():
		var character := StarterContent.character(id)
		RunSave.delete(test_save)
		var pick_scene: Control = load("res://run.tscn").instantiate()
		pick_scene.save_path = test_save
		root.add_child(pick_scene)
		await process_frame
		_find(pick_scene.get_node("%Body"), "New Journey").pressed.emit()
		await process_frame
		_find(pick_scene.get_node("%Body"), "Play as %s" % character.display_name).pressed.emit()
		await process_frame
		var shown := (pick_scene.get_node("%HeaderLabel") as Label).text
		_check(shown.contains(character.display_name) and shown.contains("HP %d/%d" % [character.max_hp, character.max_hp]), "the header shows %s and its HP" % id)
		_check(pick_scene._run.deck.size() == 10 and _panel_count(pick_scene.get_node("%Body")) == 1, "%s starts a run with a ten-card deck and one panel" % id)
		pick_scene.queue_free()
		await process_frame

	# A corrupt save falls back to a new run with a visible message.
	var bad := FileAccess.open(test_save, FileAccess.WRITE)
	bad.store_string("{ not json")
	bad.close()
	var bad_scene: Control = load("res://run.tscn").instantiate()
	bad_scene.save_path = test_save
	root.add_child(bad_scene)
	await process_frame
	var bad_body: Control = bad_scene.get_node("%Body")
	_check(bad_scene._run == null and _find(bad_body, "New Journey") != null and _find(bad_body, "Continue") == null, "a corrupt save shows the main menu without Continue")
	_check((bad_scene.get_node("%HeaderLabel") as Label).text.contains("could not be loaded"), "a corrupt save shows a message")
	_find(bad_body, "New Journey").pressed.emit()
	await process_frame
	_check(_count_buttons(bad_body, "Play as") == 3, "New Run after a corrupt save opens the select screen")
	bad_scene.queue_free()
	await process_frame

	# Pause menu: opens over a fight, freezes it, and offers Continue, Save & Exit and New Run.
	RunSave.delete(test_save)
	var pause_scene: Control = load("res://run.tscn").instantiate()
	pause_scene.save_path = test_save
	var exits := [0]
	pause_scene.exit_callable = func() -> void: exits[0] += 1
	root.add_child(pause_scene)
	await process_frame
	_find(pause_scene.get_node("%Body"), "New Journey").pressed.emit()
	await process_frame
	_find(pause_scene.get_node("%Body"), "Play as The Medium").pressed.emit()
	await process_frame
	_check(pause_scene._run.character.id == &"medium", "setup: playing as the Medium")
	var pause_button: Button = pause_scene._pause_button
	var overlay: Control = pause_scene._pause_overlay
	_check(pause_button.visible and not overlay.visible, "a running run shows the Pause button and a closed menu")
	pause_scene._run.read_story()
	pause_scene._show_stop()
	await process_frame
	_check(pause_scene._run.current_stop().type == RunState.StopType.COMBAT, "setup: standing at a fight")
	var fight: Node = pause_scene.get_node("%Body").get_child(0)
	var energy_before: int = fight._combat.energy
	pause_button.pressed.emit()
	await process_frame
	_check(overlay.visible and pause_scene.get_tree().paused, "Pause opens the menu and pauses the tree")
	_check(_find(pause_scene._pause_box, "Continue") != null and _find(pause_scene._pause_box, "Save & Exit") != null and _find(pause_scene._pause_box, "New Journey") != null, "the pause menu offers Continue, Save & Exit and New Run")
	_find(pause_scene._pause_box, "Continue").pressed.emit()
	await process_frame
	_check(not overlay.visible and not pause_scene.get_tree().paused, "Continue closes the menu and unpauses")
	_check(fight._combat.energy == energy_before, "the fight is untouched by pausing")

	# Escape toggles the menu.
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	pause_scene._unhandled_key_input(esc)
	_check(overlay.visible and pause_scene.get_tree().paused, "Escape opens the menu")
	pause_scene._unhandled_key_input(esc)
	_check(not overlay.visible and not pause_scene.get_tree().paused, "Escape closes it again")

	# Save & Exit mid-fight keeps the stop-start save and exits; it refuses with no save.
	pause_button.pressed.emit()
	await process_frame
	RunSave.delete(test_save)
	_find(pause_scene._pause_box, "Save & Exit").pressed.emit()
	await process_frame
	_check(exits[0] == 0 and _all_text(pause_scene._pause_box).contains("No save to resume"), "Save & Exit refuses to exit when there is no save to resume from")
	_set_paused_off(pause_scene)
	pause_scene._run.complete_combat(true)
	pause_scene._run.resolve_reward(null)
	pause_scene._show_stop()
	await process_frame
	var at_next: int = pause_scene._run.stop_index
	pause_button.pressed.emit()
	await process_frame
	_find(pause_scene._pause_box, "Save & Exit").pressed.emit()
	await process_frame
	var after_exit := RunSave.load_file(test_save)
	_check(exits[0] == 1 and after_exit.run != null and after_exit.run.stop_index == at_next, "Save & Exit writes the save and exits")
	_set_paused_off(pause_scene)

	# New Run asks first, and Cancel backs out.
	pause_button.pressed.emit()
	await process_frame
	var stop_before_new: int = pause_scene._run.stop_index
	_find(pause_scene._pause_box, "New Journey").pressed.emit()
	await process_frame
	_check(_all_text(pause_scene._pause_box).contains("Leave this journey behind") and pause_scene._run.stop_index == stop_before_new, "New Run asks for confirmation first")
	_find(pause_scene._pause_box, "Cancel").pressed.emit()
	await process_frame
	_check(_find(pause_scene._pause_box, "Continue") != null and pause_scene._run.stop_index == stop_before_new, "Cancel returns to the pause menu with the run intact")
	_find(pause_scene._pause_box, "New Journey").pressed.emit()
	await process_frame
	_find(pause_scene._pause_box, "Begin a new journey").pressed.emit()
	await process_frame
	_check(not overlay.visible and not pause_scene.get_tree().paused and _count_buttons(pause_scene.get_node("%Body"), "Play as") == 3, "confirming closes the menu and opens the select screen")
	_check(_find(pause_scene.get_node("%Body"), "Back") != null, "the select screen reached from the pause menu has a Back button")
	_find(pause_scene.get_node("%Body"), "Play as The Deserter").pressed.emit()
	await process_frame
	_check(pause_scene._run.stop_index == 0 and pause_scene._run.character.id == &"deserter", "picking a character after abandoning starts a fresh run")

	# The reward screen's once-per-run Remove and Heal buttons.
	var alt := RunState.new(9)
	alt.read_story()
	alt.complete_combat(true)
	pause_scene._run = alt
	pause_scene._show_stop()
	await process_frame
	var alt_body: Control = pause_scene.get_node("%Body")
	_check(_find(alt_body, "Remove a card") != null and _find(alt_body, "Heal") == null, "a reward at full HP offers Remove but not Heal")
	alt.player.hp = alt.player.max_hp - 20
	pause_scene._show_stop()
	await process_frame
	_check(_find(alt_body, "Heal %d HP" % RunState.REWARD_HEAL) != null, "a hurt player's reward offers Heal")
	_find(alt_body, "Remove a card").pressed.emit()
	await process_frame
	_check(alt.reward_pending() and _find(alt_body, "Cancel") != null and _find(alt_body, "Skip") == null, "Remove opens the deck picker")
	_find(alt_body, "Cancel").pressed.emit()
	await process_frame
	_check(alt.reward_pending() and _find(alt_body, "Skip") != null, "Cancel returns to the reward")
	# A small deck's picker shows every card with no need to scroll; a 60-card deck scrolls.
	_find(alt_body, "Remove a card").pressed.emit()
	await process_frame
	await process_frame
	var small_scroll: ScrollContainer = _first_scroll(alt_body)
	_check(small_scroll != null and CardView.find_all(small_scroll).size() == alt.deck.size(), "the remove picker holds every card of a normal deck in a scroll container")
	_check(small_scroll.get_v_scroll_bar().max_value <= small_scroll.size.y + 1.0, "a normal deck's picker needs no scrolling")
	_find(alt_body, "Cancel").pressed.emit()
	await process_frame
	root.size = Vector2i(1152, 648) # the real window; a headless one can be taller
	var real_deck := alt.deck.duplicate()
	var big_deck: Array[CardData] = []
	for i in 60:
		big_deck.append(real_deck[i % real_deck.size()])
	alt.deck = big_deck
	_find(alt_body, "Remove a card").pressed.emit()
	await process_frame
	await process_frame
	var big_scroll: ScrollContainer = _first_scroll(alt_body)
	var cancel := _find(alt_body, "Cancel")
	var screen_rect := pause_scene.get_global_rect()
	_check(big_scroll != null and CardView.find_all(big_scroll).size() == 60, "the 60-card picker holds all 60 cards in the scroll container")
	_check(big_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED and big_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO, "the picker scrolls vertically only")
	_check(big_scroll.get_v_scroll_bar().max_value > big_scroll.size.y + 1.0, "the 60-card grid is taller than the scroll viewport")
	_check(big_scroll.get_global_rect().end.y <= screen_rect.end.y and big_scroll.get_global_rect().position.y >= screen_rect.position.y, "the scroll area is inside the window")
	_check(cancel != null and not big_scroll.is_ancestor_of(cancel) and screen_rect.encloses(cancel.get_global_rect()), "Cancel stays outside the scrolled content and inside the window")
	big_scroll.scroll_vertical = 100000 # to the bottom: the last row is reachable
	await process_frame
	var last_view := CardView.find_all(big_scroll).back() as CardView
	_check(big_scroll.get_global_rect().grow(2).encloses(last_view.get_global_rect()), "scrolled down, the last card of a big deck is in view")
	_find(alt_body, "Cancel").pressed.emit()
	await process_frame
	alt.deck.assign(real_deck)
	_find(alt_body, "Remove a card").pressed.emit()
	await process_frame
	var alt_deck := alt.deck.size()
	_first_card(alt_body).pressed.emit()
	await process_frame
	_check(alt.deck.size() == alt_deck - 1 and alt.reward_remove_used and not alt.reward_pending() and alt.stop_index == 2, "picking a card removes it and resolves the reward")
	alt.complete_combat(true)
	pause_scene._show_stop()
	await process_frame
	_check(_find(alt_body, "Remove a card") == null and _find(alt_body, "Heal") != null, "Remove is gone once used; Heal remains")
	var hp_before_heal := alt.player.hp
	_find(alt_body, "Heal").pressed.emit()
	await process_frame
	_check(alt.player.hp == hp_before_heal + RunState.REWARD_HEAL and alt.reward_heal_used and not alt.reward_pending(), "Heal restores HP and resolves the reward")
	alt.stop_index = 4  # a combat stop; a reward again
	alt.complete_combat(true)
	pause_scene._show_stop()
	await process_frame
	_check(_find(alt_body, "Remove a card") == null and _find(alt_body, "Heal") == null, "neither button shows once both are used")

	# No Pause button once the run is over.
	var done := RunState.new(4)
	done.finished = true
	pause_scene._run = done
	pause_scene._show_stop()
	await process_frame
	_check(not pause_button.visible, "the Pause button is hidden on the end card")

	# The pause backdrop: built for every character, animated only while shown, even with the tree paused.
	var backdrop: PauseScene = pause_scene._pause_scene
	_check(backdrop != null and not backdrop.is_processing() and not backdrop.is_visible_in_tree(), "the pause backdrop idles while the menu is closed")
	var before := backdrop.time
	backdrop.advance(1.0)
	_check(backdrop.time == before, "advance does nothing while the backdrop is hidden")
	for id in [&"deserter", &"pickpocket", &"medium"]:
		pause_scene._run = RunState.new(5, id)
		pause_scene._set_paused(true)
		await process_frame
		_check(backdrop.variant == id and backdrop.visible and backdrop.is_processing(), "pausing as %s shows the matching backdrop" % id)
		_check(pause_scene.get_tree().paused, "the tree is paused while the backdrop shows")
		var t := backdrop.time
		await process_frame
		_check(backdrop.time > t, "the backdrop keeps animating on its own while the tree is paused (%s)" % id)
		var level := backdrop.lamp_level()
		backdrop.advance(0.37)
		_check(backdrop.time > t and backdrop.lamp_level() != level, "advance(delta) moves the animation state (%s)" % id)
		pause_scene._set_paused(false)
		await process_frame
		_check(not backdrop.is_visible_in_tree() and not backdrop.is_processing(), "Continue hides the backdrop and stops its updates (%s)" % id)
	var stopped := backdrop.time
	await process_frame
	_check(backdrop.time == stopped, "a hidden backdrop does not advance")
	for odd_id in [&"", &"nobody"]:
		pause_scene._set_paused(true)
		backdrop.set_character(odd_id)
		backdrop.advance(0.2)
		await process_frame
		_check(backdrop.variant == odd_id and backdrop.time > stopped, "an unknown character id draws the neutral scene (%s)" % odd_id)
		pause_scene._set_paused(false)
	pause_scene.queue_free()
	await process_frame

	RunSave.delete(test_save)

	print("UI FLOW FAILURES: %d" % _failures)
	quit(1 if _failures > 0 else 0)


func _set_paused_off(scene: Control) -> void:
	scene._set_paused(false)


func _count_buttons(node: Node, prefix: String) -> int:
	var found: Array = []
	_buttons(node, found)
	var count := 0
	for button in found:
		if (button as Button).text.begins_with(prefix):
			count += 1
	return count
