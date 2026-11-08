extends "res://tests/ui_battle_support.gd"
## Headless UI test for the hand row and the pile keys: a refresh keeps the same card views (so hover, drag and
## the tooltip survive), a target change touches only previews, handlers use the live index, and D / C / F / W open
## the piles. Also the after-fight keys. Run via scripts/check.ps1.


func _initialize() -> void:
	var node: Control = await _make_battle()
	var c: Combat = await _fresh_fight(node)
	c.piles.hand.assign([_card("shove"), _card("bash"), _card("brace"), _card("sweep")])
	node._refresh()
	await process_frame
	var views: Array[CardView] = node._hand_views()
	check(views.size() == 4, "the hand shows four views")
	node._refresh()
	node._refresh()
	check(node._hand_views() == views, "a refresh keeps the same view instances")
	# Hover a card, then change the target: the same view stays hovered with its tooltip and the preview survives.
	var hovered: CardView = views[1]
	hovered.set_hovered(true)
	check(node.preview_visible(), "hovering a hand card shows the preview")
	var tip := hovered.tooltip_text
	node._select_target(1)
	check(node._hand_views() == views and hovered.tooltip_text == tip and hovered.tooltip_text != "", "a target change keeps the views and the hovered tooltip")
	check(node.preview_visible() and node._preview.card == hovered.card, "the preview survives a target change")
	hovered.set_hovered(false)
	# A preview follows the target.
	c.enemies[0].apply_status(Combatant.Status.EXPOSED, 2)
	node._select_target(0)
	var exposed_preview: String = (views[0] as CardView).preview
	node._select_target(1)
	check((views[0] as CardView).preview != exposed_preview or exposed_preview == "", "previews follow the selected target")
	# Playing a card changes the hand, so the row is rebuilt, and the index handlers stay right.
	var before_ids := _ids(c.piles.hand)
	c.energy = 9
	views[0].pressed.emit()
	check(c.piles.hand.size() == 3 and _ids(c.piles.hand) == before_ids.slice(1), "pressing the first view plays the first card")
	var after: Array[CardView] = node._hand_views()
	after[0].pressed.emit()
	check(c.piles.hand.size() == 2 and c.piles.hand[0].id == &"brace", "the rebuilt first view plays the new first card")
	# Energy loss updates the surviving views in place.
	c.piles.hand.assign([_card("bash"), _card("brace")])
	node._refresh()
	var kept: Array[CardView] = node._hand_views()
	c.energy = 0
	node._refresh()
	check(node._hand_views() == kept and kept[0].state == CardView.State.UNPLAYABLE, "losing energy updates the same views in place")

	# Pile keys.
	c.energy = 9
	key(node, KEY_D)
	check(node.pile_viewer_open() and node._pile_viewer.pile == PileViewer.Pile.DRAW, "D opens the Draw pile")
	key(node, KEY_C)
	check(node._pile_viewer.pile == PileViewer.Pile.DISCARD, "C switches to the Discard pile")
	key(node, KEY_F)
	check(node._pile_viewer.pile == PileViewer.Pile.FORGOTTEN, "F switches to the Forgotten pile")
	key(node, KEY_W)
	check(node._pile_viewer.pile == PileViewer.Pile.SWORN, "W switches to the Sworn pile")
	key(node, KEY_ESCAPE)
	check(not node.pile_viewer_open(), "Esc closes it")
	check(node._pile_text().begins_with("Draw "), "the counters read Draw, Discard, Forgotten, Sworn")

	# After the fight: Enter, E and N all continue.
	for code in [KEY_ENTER, KEY_E, KEY_N]:
		node._new_fight_button.show()
		var seen := [0]
		node.fight_finished.connect(func(_v: bool) -> void: seen[0] += 1, CONNECT_ONE_SHOT)
		node.external_combat = c
		key(node, code)
		check(seen[0] == 1, "key %s continues after the fight" % OS.get_keycode_string(code))
		node.external_combat = null
		node._start_combat()
		await process_frame
		c = node._combat
	check(node._new_fight_button.text.contains("N"), "the New Fight button shows its key: " + node._new_fight_button.text)
	_finish()
