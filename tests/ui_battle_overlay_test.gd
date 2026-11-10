extends "res://tests/ui_battle_support.gd"
## Headless UI test for battle.tscn overlays: the Glimpse/Recall choice overlay, the pile viewer and the
## add-card cue. Run via scripts/check.ps1.

## Glimpse and Recall on screen: the overlay opens, marks, Keep all vs Discard N, exact picks for Recall,
## queued choices, and nothing playable behind it.
func _check_choice_overlay(node: Control) -> void:
	var c: Combat = await _fresh_fight(node)
	# Draw pile top-to-bottom: shove, brace, bash, heavy_blow, sweep (the END of the array is the top).
	var draw_order: Array[CardData] = [_card("sweep"), _card("heavy_blow"), _card("bash"), _card("brace"), _card("shove")]
	c.piles.draw_pile.assign(draw_order)
	c.piles.hand.assign([_proto("glimpse_3"), _card("cold_steel")])
	node._refresh()
	check(not node.choice_overlay_visible(), "no overlay before a Glimpse is played")
	node._hand.play_card(0)
	check(c.phase == Combat.Phase.CHOOSING and node.choice_overlay_visible(), "playing Glimpse 3 opens the overlay")
	var overlay: ChoiceOverlay = node._overlays.choice
	check(_ids(overlay.cards) == [&"shove", &"brace", &"bash"], "the overlay lists the top 3 cards in draw order")
	check(overlay.heading_label.text.begins_with("Glimpse") and overlay.confirm_button.text == "Keep all" and not overlay.confirm_button.disabled, "Glimpse: heading, and zero picks allowed (Keep all)")
	check(CardView.find_all(overlay).size() == 3, "one card view per offered card")
	# Nothing behind it works.
	var hand_views := CardView.find_all(node._hand_box)
	check(hand_views.size() == 1 and not hand_views[0].is_clickable(), "hand cards are not clickable while the overlay is up")
	var hand_before := c.piles.hand.size()
	node._hand.play_card(0)
	key(node, KEY_E)
	node._on_end_turn_pressed()
	check(c.phase == Combat.Phase.CHOOSING and c.piles.hand.size() == hand_before and node._end_turn_button.disabled, "hand cards and End Turn do nothing, and the button is disabled, behind the overlay")
	check(node.open_pile_viewer(PileViewer.Pile.DRAW) == false and not node.pile_viewer_open(), "the pile viewer does not open during a pick")
	key(node, KEY_ESCAPE)
	check(c.phase == Combat.Phase.CHOOSING and node.choice_overlay_visible(), "Esc does not cancel the pick")
	# Marking.
	overlay.toggle(0)
	overlay.toggle(2)
	check(overlay.confirm_button.text == "Discard 2" and overlay.marks == ([0, 2] as Array[int]), "marking two cards: Discard 2")
	var views := CardView.find_all(overlay)
	check(views[0].discard_marked and not views[1].discard_marked and views[2].discard_marked, "marked cards are dimmed and stamped for discard")
	overlay.toggle(0)
	check(overlay.confirm_button.text == "Discard 1" and not CardView.find_all(overlay)[0].discard_marked, "unmarking a card takes the stamp off")
	key(node, KEY_1)
	check(overlay.marks == ([0, 2] as Array[int]), "number key 1 marks the first card")
	overlay.confirm_button.pressed.emit()
	check(c.phase == Combat.Phase.PLAYER_TURN and not node.choice_overlay_visible(), "confirming closes the overlay and returns to the turn")
	check(_ids(c.piles.discard_pile) == [&"proto_glimpse_3", &"shove", &"bash"], "the picked cards (and the played card) are in the discard pile")
	check(_ids(c.piles.draw_pile) == [&"sweep", &"heavy_blow", &"brace"], "the unpicked cards stay on top, in order")
	check(not node._end_turn_button.disabled and CardView.find_all(node._hand_box)[0].is_clickable(), "the turn controls come back")

	# Keep all: confirm with nothing marked leaves the pile alone.
	c = await _fresh_fight(node)
	c.piles.draw_pile.assign(draw_order)
	c.piles.hand.assign([_proto("glimpse_3")])
	node._refresh()
	node._hand.play_card(0)
	key(node, KEY_ENTER)
	check(c.phase == Combat.Phase.PLAYER_TURN and c.piles.draw_pile == draw_order and c.piles.discard_pile.size() == 1, "Enter with nothing marked keeps everything (Keep all)")

	# Recall: exactly the required number of picks.
	c = await _fresh_fight(node)
	c.piles.forgotten.assign([_card("shove"), _card("brace"), _card("bash")])
	c.piles.hand.assign([_proto("recall_2")])
	node._refresh()
	node._hand.play_card(0)
	check(c.phase == Combat.Phase.CHOOSING and node.choice_overlay_visible(), "playing Recall 2 opens the overlay")
	overlay = node._overlays.choice
	check(overlay.heading_label.text == "Recall: choose 2 to return to your hand" and _ids(overlay.cards) == [&"shove", &"brace", &"bash"], "Recall: heading and the whole Forgotten pile")
	check(overlay.confirm_button.disabled and overlay.confirm_button.text == "Recall 0 of 2", "Recall: the button is disabled with no picks")
	overlay.confirm_button.pressed.emit()
	key(node, KEY_ENTER)
	check(c.phase == Combat.Phase.CHOOSING, "confirming a Recall with too few picks does nothing")
	overlay.toggle(0)
	check(overlay.confirm_button.disabled and overlay.confirm_button.text == "Recall 1 of 2", "Recall: one of two picked is not enough")
	check(CardView.find_all(overlay)[0].state == CardView.State.SELECTED, "a Recall pick is shown selected")
	overlay.toggle(1)
	overlay.toggle(2)
	check(overlay.marks == ([0, 1] as Array[int]), "a third pick is ignored when two are allowed")
	overlay.toggle(1)
	overlay.toggle(2)
	check(not overlay.confirm_button.disabled and overlay.confirm_button.text == "Recall 2 of 2", "Recall: two of two enables the button")
	overlay.confirm_button.pressed.emit()
	check(c.phase == Combat.Phase.PLAYER_TURN and _ids(c.piles.hand) == [&"shove", &"bash"] and _ids(c.piles.forgotten) == [&"brace"], "the picked Forgotten cards return to the hand")
	check(CardView.find_all(node._hand_box).size() == 2, "the screen shows the recalled cards in hand")

	# A Recall that takes one swaps its pick; a big Forgotten pile wraps and still fits the stage.
	c = await _fresh_fight(node)
	var big: Array[CardData] = []
	for i in 12:
		big.append(_card("shove") if i % 2 == 0 else _card("brace"))
	c.piles.forgotten.assign(big)
	c.piles.hand.assign([_proto("recall_1")]) # itself Forgotten, so it joins the pile it recalls from
	node._refresh()
	node._hand.play_card(0)
	overlay = node._overlays.choice
	check(overlay != null and overlay.cards.size() == 13, "Recall 1 can pick from 13 cards (the played card joined the Forgotten pile)")
	overlay.toggle(0)
	overlay.toggle(5)
	check(overlay.marks == ([5] as Array[int]) and not overlay.confirm_button.disabled, "a one-pick Recall swaps the pick instead of ignoring it")
	await process_frame
	await process_frame
	var panel_rect: Rect2 = (overlay.get_child(1) as Control).get_global_rect()
	var stage_rect: Rect2 = node._stage.get_global_rect()
	check(panel_rect.size.x > 0.0 and stage_rect.encloses(panel_rect.grow(-1.0)), "the overlay panel stays inside the stage with 13 cards (%s in %s)" % [panel_rect, stage_rect])
	check(panel_rect.end.y <= stage_rect.end.y - 40.0, "the overlay leaves the enemy HP bars along the bottom of the stage uncovered")
	check(overlay.card_scale <= 0.9 and overlay.card_scale >= ChoiceOverlay.SCALES[-1], "thirteen cards wrap onto rows that fit (scale %.2f)" % overlay.card_scale)
	check(ChoiceOverlay.fit_scale(5, 1000.0, 300.0) == 0.9 and ChoiceOverlay.fit_scale(30, 1000.0, 300.0) < 0.9 and ChoiceOverlay.fit_scale(200, 1000.0, 300.0) == ChoiceOverlay.SCALES[-1], "cards shrink as the pile grows, down to a floor (then the list scrolls)")
	overlay.confirm()
	check(c.phase == Combat.Phase.PLAYER_TURN and c.piles.hand.size() == 1 and c.piles.forgotten.size() == 12, "the swapped pick returned")

	# Two queued choices open one after the other, each with a fresh overlay.
	c = await _fresh_fight(node)
	c.piles.draw_pile.assign(draw_order)
	c.piles.forgotten.assign([_card("shove"), _card("brace")])
	var both := CardData.make(&"both", "Both", 0, [CardEffect.make(CardEffect.Kind.GLIMPSE, 2), CardEffect.make(CardEffect.Kind.RECALL, 1)] as Array[CardEffect], CardData.TargetMode.SELF)
	c.piles.hand.assign([both])
	node._refresh()
	node._hand.play_card(0)
	var first: ChoiceOverlay = node._overlays.choice
	check(c.phase == Combat.Phase.CHOOSING and first.is_glimpse() and first.cards.size() == 2, "the first queued choice (Glimpse) opens first")
	first.toggle(1)
	first.confirm()
	check(c.phase == Combat.Phase.CHOOSING and node.choice_overlay_visible() and node._overlays.choice != first and not node._overlays.choice.is_glimpse(), "resolving it opens the second (Recall) in a fresh overlay")
	check(_ids(c.piles.discard_pile).has(&"brace") and node._overlays.choice.marks.is_empty(), "the first pick was applied and the new overlay starts unmarked")
	node._overlays.choice.toggle(0)
	node._overlays.choice.confirm()
	check(c.phase == Combat.Phase.PLAYER_TURN and not node.choice_overlay_visible() and _ids(c.piles.hand).has(&"shove"), "after the second choice the turn resumes")

	# A refresh while choosing keeps the marks.
	c = await _fresh_fight(node)
	c.piles.draw_pile.assign(draw_order)
	c.piles.hand.assign([_proto("glimpse_3")])
	node._refresh()
	node._hand.play_card(0)
	overlay = node._overlays.choice
	overlay.toggle(1)
	node._refresh()
	check(node._overlays.choice == overlay and overlay.marks == ([1] as Array[int]), "an unrelated refresh keeps the overlay and its marks")


## The pile viewer: opens for each pile from the counters, the Draw list is sorted rather than in draw
## order, closes with Esc, the button and a click outside, and only opens in the player's turn or discard step.
func _check_pile_viewer(node: Control) -> void:
	var c: Combat = await _fresh_fight(node)
	var names := ["shove", "bash", "sweep", "brace", "heavy_blow", "cold_steel"]
	var draw: Array[CardData] = []
	for n in names:
		draw.append(_card(n))
	c.piles.draw_pile.assign(draw)
	c.piles.discard_pile.assign([_card("spree"), _card("flurry")])
	c.piles.forgotten.assign([_proto("forgotten_strike")])
	node._refresh()
	await process_frame
	check(node._hud.pile_buttons.size() == 4, "there is one button per pile")
	check(node._hud.pile_buttons[0].mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND and node._hud.pile_buttons[0].text == "Draw 6", "the pile counters are buttons with a hand cursor")
	check(node._hud.pile_buttons[3].tooltip_text.contains("W") and node._hud.pile_buttons[0].tooltip_text.contains("D"), "each pile button names its key")
	node._hud.pile_buttons[0].pressed.emit()
	check(node.pile_viewer_open() and node._overlays.pile_viewer.pile == PileViewer.Pile.DRAW, "clicking the Draw button opens the Draw pile")
	var viewer: PileViewer = node._overlays.pile_viewer
	var shown: Array = viewer.card_views().map(func(v: CardView) -> StringName: return v.card.id)
	var expected: Array = draw.duplicate()
	expected.sort_custom(func(a: CardData, b: CardData) -> bool: return a.cost < b.cost or (a.cost == b.cost and a.display_name < b.display_name))
	expected = expected.map(func(card: CardData) -> StringName: return card.id)
	var in_draw_order: Array = c.piles.top_cards(6).map(func(card: CardData) -> StringName: return card.id)
	check(shown == expected and shown != in_draw_order, "the Draw pile is listed sorted, not in draw order: %s" % str(shown))
	check(viewer.note_label.text.contains("no particular order"), "the Draw pile says it is in no particular order")
	check(viewer.tab_buttons[0].text == "Draw 6" and viewer.tab_buttons[1].text == "Discard 2" and viewer.tab_buttons[2].text == "Forgotten 1", "the tabs show the counts")
	viewer.tab_buttons[1].pressed.emit()
	check(viewer.pile == PileViewer.Pile.DISCARD and viewer.card_views().size() == 2 and viewer.card_views()[0].card.id == &"spree", "the Discard tab lists the discard pile")
	viewer.tab_buttons[2].pressed.emit()
	check(viewer.card_views().size() == 1 and viewer.card_views()[0].card.id == &"proto_forgotten_strike", "the Forgotten tab lists the Forgotten pile")
	check(c.piles.draw_pile == draw and c.phase == Combat.Phase.PLAYER_TURN, "looking changes nothing")
	# Modal: keys and clicks do nothing behind it; Esc closes.
	var hand_n := c.piles.hand.size()
	node._hand.play_card(0)
	key(node, KEY_E)
	key(node, KEY_1)
	check(c.piles.hand.size() == hand_n and c.phase == Combat.Phase.PLAYER_TURN and node.pile_viewer_open(), "keys do nothing behind the pile viewer")
	key(node, KEY_ESCAPE)
	check(not node.pile_viewer_open(), "Esc closes the pile viewer")
	# Each pile by name, the Close button, and a click outside the panel.
	for which in [PileViewer.Pile.DISCARD, PileViewer.Pile.FORGOTTEN, PileViewer.Pile.DRAW]:
		check(node.open_pile_viewer(which) and node._overlays.pile_viewer.pile == which, "the viewer opens on pile %d" % which)
		node._overlays.close_pile_viewer()
	node.open_pile_viewer(PileViewer.Pile.DRAW)
	node._overlays.pile_viewer.close_button.pressed.emit()
	check(not node.pile_viewer_open(), "the Close button closes the viewer")
	node.open_pile_viewer(PileViewer.Pile.DRAW)
	var outside := InputEventMouseButton.new()
	outside.button_index = MOUSE_BUTTON_LEFT
	outside.pressed = true
	node._overlays.pile_viewer._gui_input(outside)
	check(not node.pile_viewer_open(), "a click outside the panel closes the viewer")
	# It works in the discard step, not in the enemy phase.
	node._on_end_turn_pressed()
	check(c.phase == Combat.Phase.DISCARDING and node.open_pile_viewer(PileViewer.Pile.DISCARD), "the viewer opens during the discard step")
	node._overlays.close_pile_viewer()
	c.phase = Combat.Phase.ENEMY_TURN
	check(not node.open_pile_viewer(PileViewer.Pile.DRAW), "the viewer does not open in the enemy phase")
	c.phase = Combat.Phase.PLAYER_TURN


## Cards an enemy or a card adds to the player's piles are announced: a log line and a floating cue.
func _check_add_cue(node: Control) -> void:
	var enemy := DebugLaunch.prototype_enemy(&"proto_dreadkeeper")
	var enemies: Array[EnemyData] = [enemy]
	node._start_with(Combatant.new("Wanderer", 60), enemies, 5)
	await process_frame
	var c: Combat = node._combat
	var before := c.piles.hand.size() + c.piles.draw_pile.size() + c.piles.discard_pile.size() + c.piles.forgotten.size()
	var cues: int = node.cue_count
	node._on_end_turn_pressed()
	node._on_end_turn_pressed() # confirm the discard step: the enemy phase runs
	var after := c.piles.hand.size() + c.piles.draw_pile.size() + c.piles.discard_pile.size() + c.piles.forgotten.size()
	check(after == before + 1, "the Dreadkeeper's first move added one Dread to the player's cards (%d -> %d)" % [before, after])
	check(node.cue_count == cues + 1 and node.last_cue_text.contains("Dread") and node.last_cue_text.contains("draw pile"), "a floating cue names the card and the pile: '%s'" % node.last_cue_text)
	check(node._log_label.get_parsed_text().contains("Dread"), "the battle log mentions the Dread")
	await process_frame
	# A card that adds a card to hand logs it and shows the cue.
	c.energy = 9
	c.piles.hand.assign([load("res://data/prototype/add_gift.tres") as CardData])
	node._refresh()
	var cue_before: int = node.cue_count
	node._hand.play_card(0)
	check(node.cue_count == cue_before + 1 and node.last_cue_text.contains("Heavy Blow") and node.last_cue_text.contains("hand"), "playing a card that adds a card shows a cue: '%s'" % node.last_cue_text)
	check(node._log_label.get_parsed_text().contains("Added Heavy Blow to your hand") and c.piles.hand.size() == 1, "and logs it, and the card is in hand")
	await process_frame


## The real Glimpse the Exit (Glimpse 3, then Draw 1; Draw 2 when Remembered) on screen: the draw happens when the card
## is played, before the pick, and the drawn card is in the hand and on screen behind the overlay. The played card leaves
## the hand, so the base card keeps the hand the same size and the Remembered one grows it by one.
func _check_glimpse_exit(node: Control) -> void:
	var base := _card("glimpse_exit")
	for variant in [base, base.remembered_card()]:
		var draws: int = 1 if variant == base else 2
		var c: Combat = await _fresh_fight(node)
		var draw_order: Array[CardData] = [_card("sweep"), _card("heavy_blow"), _card("bash"), _card("brace"), _card("shove")]
		c.piles.draw_pile.assign(draw_order) # the END is the top: shove, brace, bash, heavy_blow, sweep
		c.piles.hand.assign([variant, _card("cold_steel")])
		node._refresh()
		var label: String = variant.display_name
		check(CardView.find_all(node._hand_box).size() == 2, "%s: two cards in the hand before playing" % label)
		node._hand.play_card(0)
		check(c.phase == Combat.Phase.CHOOSING and node.choice_overlay_visible(), "%s: playing it opens the Glimpse pick" % label)
		check(c.piles.hand.size() == 1 + draws, "%s: it drew %d card(s) before the pick (hand %d)" % [label, draws, c.piles.hand.size()])
		check(_ids(c.piles.hand).slice(1) == _ids([_card("shove"), _card("brace")]).slice(0, draws), "%s: the drawn cards are the top of the draw pile" % label)
		check(CardView.find_all(node._hand_box).size() == 1 + draws, "%s: the hand on screen shows the drawn card(s) behind the overlay" % label)
		var overlay: ChoiceOverlay = node._overlays.choice
		var left := _ids(draw_order.slice(0, 5 - draws)) # what the draw pile holds after the draw, top last
		var expected_top: Array = left.slice(-3)
		expected_top.reverse() # the pick lists the top card first
		check(_ids(overlay.cards) == expected_top, "%s: the pick shows the next 3 cards, after the draw" % label)
		overlay.confirm_button.pressed.emit()
		check(c.phase == Combat.Phase.PLAYER_TURN and CardView.find_all(node._hand_box).size() == 1 + draws, "%s: after Keep all the drawn card(s) are still in the hand on screen" % label)
		check(c.piles.discard_pile.size() == 1 and c.piles.discard_pile[0].id == &"glimpse_exit", "%s: the played card is in the discard pile" % label)
	await process_frame


func _initialize() -> void:
	var node: Control = await _make_battle()
	await _check_choice_overlay(node)
	await _check_pile_viewer(node)
	await _check_add_cue(node)
	await _check_glimpse_exit(node)
	_finish()
