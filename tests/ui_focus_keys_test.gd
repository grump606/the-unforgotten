extends SceneTree
## Headless test that the controls a keyboard-only player needs can take focus: the two check buttons on the
## Sound page (reached with Tab from the first slider, in tree order), the pile viewer's tabs and Close
## button, and the Glimpse / Recall confirm button. Also that the battle's key routing still works with them
## focusable (pile keys, Esc). Run via scripts/check.ps1.

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
	check(scene.open_pile_viewer(PileViewer.Pile.DRAW), "the pile viewer opens")
	var viewer: PileViewer = scene.overlays().pile_viewer
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

	var overlay := ChoiceOverlay.new()
	overlay.cards.assign([load("res://data/cards/bash.tres") as CardData])
	overlay._build(Vector2(1120, 590))
	scene.add_child(overlay)
	check(overlay.confirm_button.focus_mode == Control.FOCUS_ALL, "the Glimpse / Recall confirm button can take focus")
	quit(1 if fails > 0 else 0)
