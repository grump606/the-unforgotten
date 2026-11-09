extends SceneTree
## Headless test that the controls a keyboard-only player needs can take focus: the two check buttons on the
## Sound page (reached with Tab from the first slider, in tree order), the pile viewer's tabs and Close
## button, and the Glimpse / Recall confirm button. Also that the battle's key routing still works with them
## focusable (pile keys, Esc), that opening the pile viewer or the Glimpse / Recall pick moves focus into it, and that
## closing either gives focus back to what had it (all with real key events). Run via scripts/check.ps1.

var fails := 0


func check(c: bool, msg: String) -> void:
	if not c:
		fails += 1
		printerr("FAIL: " + msg)
	else:
		print("ok: " + msg)


func _tab(shift := false) -> void:
	var e := InputEventKey.new()
	e.keycode = KEY_TAB
	e.physical_keycode = KEY_TAB
	e.shift_pressed = shift
	e.pressed = true
	root.push_input(e)


func _key_event(code: int) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	root.push_input(e)


func _key(node: Node, code: int) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	node._unhandled_key_input(e)


func _initialize() -> void:
	Motion.reduced = false
	var holder := VBoxContainer.new()
	root.add_child(holder)
	var panel := AudioSettingsPanel.new()
	panel.build(holder, func() -> void: pass)
	await process_frame
	await process_frame
	(panel.sliders["master"] as HSlider).grab_focus()
	check(root.gui_get_focus_owner() == panel.sliders["master"], "the first slider takes focus")
	check(panel.mute_button.focus_mode == Control.FOCUS_ALL and panel.reduce_button.focus_mode == Control.FOCUS_ALL,
		"both check buttons can take focus")
	var seen: Array[Control] = []
	for i in 12:
		_tab()
		await process_frame
		var owner := root.gui_get_focus_owner()
		if owner != null and not seen.has(owner):
			seen.append(owner)
	check(seen.has(panel.mute_button), "Tab reaches 'Mute all sound'")
	check(seen.has(panel.reduce_button), "Tab reaches 'Reduce motion'")
	var order := seen.find(panel.mute_button) < seen.find(panel.credits_button) and seen.find(panel.credits_button) < seen.find(panel.reduce_button)
	check(order, "Tab order follows the page: mute, credits, reduce motion")
	check(seen.any(func(c: Control) -> bool: return c is Button and (c as Button).text == "Back"), "Tab reaches Back")
	check(panel.mute_button.get_theme_stylebox("focus") is StyleBoxFlat, "the check button draws a focus outline")
	holder.queue_free()
	await process_frame

	# Battle: pile viewer and confirm button.
	var scene: Control = (load("res://battle.tscn") as PackedScene).instantiate()
	scene.external_combat = Combat.create(Combatant.new("Wanderer", 40), StarterContent.extended_deck(),
		[load("res://data/enemies/gate_warden.tres") as EnemyData], 7)
	root.add_child(scene)
	await process_frame
	await process_frame
	var previous := Button.new()
	previous.focus_mode = Control.FOCUS_ALL
	scene.add_child(previous)
	previous.grab_focus()
	check(root.gui_get_focus_owner() == previous, "a control has focus before the viewer opens")
	check(scene.open_pile_viewer(PileViewer.Pile.DRAW), "the pile viewer opens")
	var viewer: PileViewer = scene.overlays().pile_viewer
	check(root.gui_get_focus_owner() == viewer.tab_buttons[PileViewer.Pile.DRAW], "opening the viewer focuses the open pile's tab without a Tab press")
	_key_event(KEY_C)
	await process_frame
	check(viewer.pile == PileViewer.Pile.DISCARD and scene.pile_viewer_open(), "a real C press with a tab focused switches piles")
	_key_event(KEY_ESCAPE)
	await process_frame
	check(not scene.pile_viewer_open() and root.gui_get_focus_owner() == previous, "a real Esc press closes the viewer and focus returns to the previous owner")
	previous.release_focus()
	check(scene.open_pile_viewer(PileViewer.Pile.DRAW), "the pile viewer opens again")
	viewer = scene.overlays().pile_viewer
	for tab in viewer.tab_buttons:
		check(tab.focus_mode == Control.FOCUS_ALL, "a pile tab can take focus")
	check(viewer.close_button.focus_mode == Control.FOCUS_ALL, "the viewer's Close button can take focus")
	_tab()
	await process_frame
	var focused := root.gui_get_focus_owner()
	check(focused != null and viewer.is_ancestor_of(focused), "Tab moves focus into the open viewer")
	_key(scene, KEY_C)
	check(viewer.pile == PileViewer.Pile.DISCARD, "a pile key still switches piles with a tab focused")
	_key(scene, KEY_ESCAPE)
	check(not scene.pile_viewer_open(), "Esc still closes the viewer with a tab focused")

	var lone := ChoiceOverlay.new()
	lone.cards.assign([load("res://data/cards/bash.tres") as CardData])
	lone._build(Vector2(1120, 590))
	scene.add_child(lone)
	check(lone.confirm_button.focus_mode == Control.FOCUS_ALL, "the Glimpse / Recall confirm button can take focus")
	scene.remove_child(lone)
	lone.free()

	# A real Glimpse pick: focus goes to the confirm button, Enter confirms it once, focus goes back.
	var c: Combat = scene.combat()
	c.energy = 9
	previous.grab_focus()
	c.piles.hand.assign([load("res://data/prototype/glimpse_3.tres") as CardData])
	scene._refresh()
	scene.hand().play_card(0)
	await process_frame
	check(c.phase == Combat.Phase.CHOOSING and scene.overlays().choice_visible(), "playing Glimpse opens the pick")
	var pick: ChoiceOverlay = scene.overlays().choice
	check(root.gui_get_focus_owner() == pick.confirm_button, "the pick focuses its confirm button without a Tab press")
	_key_event(KEY_ENTER)
	await process_frame
	check(c.phase == Combat.Phase.PLAYER_TURN and not scene.overlays().choice_visible(), "a real Enter press confirms the pick once and closes it")
	check(root.gui_get_focus_owner() == previous, "closing the pick gives focus back to the previous owner")
	quit(1 if fails > 0 else 0)
