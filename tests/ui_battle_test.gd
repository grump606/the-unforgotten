extends SceneTree
## Headless UI test for battle.tscn: pile labels, tooltips, damage preview, keyboard
## control, target cycling and the New Fight flow. Run via scripts/check.ps1.

var fails := 0

func check(c: bool, msg: String) -> void:
	if not c:
		fails += 1
		printerr("FAIL: " + msg)
	else:
		print("ok: " + msg)

func key(node: Node, code: int, shift := false) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	e.shift_pressed = shift
	node._unhandled_key_input(e)

## For each card with a state-dependent hit, the hand-button preview must equal the
## damage the real play deals, across plain, Blocked and Exposed targets.
func _check_preview_matches_damage(node: Control, combat: Combat) -> void:
	node._select_target(0)
	var cards := ["bash", "cold_steel", "last_pocket", "spree", "reckoning"]
	# [player block, plays already made this turn, target haunt, target block, exposed]
	var setups := [[0, 0, 0, 0, false], [4, 2, 3, 0, false], [12, 3, 5, 0, false], [12, 3, 5, 3, false], [4, 2, 3, 0, true]]
	for id in cards:
		for setup in setups:
			var card: CardData = load("res://data/cards/%s.tres" % id)
			var label := "%s %s" % [id, str(setup)]
			combat.player.clear_block()
			combat.player.gain_block(setup[0])
			combat.plays_this_turn = setup[1]
			combat.energy = 9
			var target: EnemyUnit = combat.enemies[0]
			target.clear_statuses()
			target.clear_block()
			target.max_hp = 500
			target.hp = 500
			if setup[2] > 0:
				target.apply_status(Combatant.Status.HAUNTED, setup[2])
			target.gain_block(setup[3])
			if setup[4]:
				target.apply_status(Combatant.Status.EXPOSED, 2)
			combat.piles.hand.clear()
			combat.piles.hand.append(card)
			node._rebuild_hand()
			var text: String = (node._hand_box.get_child(0) as CardView).preview
			var dealt_to_block := target.block
			combat.play_card(0, 0)
			var lost: int = 500 - target.hp
			var expected := "%d after Block" % lost if dealt_to_block > 0 else ("(%d vs Exposed)" % lost if setup[4] else "Deals %d" % lost)
			check(text.contains(expected), "preview matches damage: %s lost %d in %s" % [label, lost, text.replace("\n", " | ")])
			combat.piles.hand.clear()


func _mouse_button(view: CardView, pressed: bool, global: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = pressed
	e.global_position = global
	e.position = global - view.get_global_rect().position
	view._gui_input(e)


func _mouse_move(view: CardView, global: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.global_position = global
	e.position = global - view.get_global_rect().position
	view._gui_input(e)


## Dragging an enemy-targeting card: the click still works, only enemy-targeting cards drag, the enemy under
## the pointer shows what the card would do to IT, and a drop plays on that enemy whatever is selected.
func _check_drag(node: Control) -> void:
	# CardView alone: a short wiggle is still a click, a long pull is a drag and never a click.
	var lone := CardView.new()
	lone.clickable = true
	lone.draggable = true
	lone.set_card(load("res://data/cards/bash.tres"))
	node.add_child(lone)
	var log := {"clicks": 0, "drags": 0, "ended": 0}
	lone.pressed.connect(func() -> void: log.clicks += 1)
	lone.drag_started.connect(func() -> void: log.drags += 1)
	lone.drag_ended.connect(func(_p: Vector2) -> void: log.ended += 1)
	var origin := lone.get_global_rect().position + Vector2(20, 20)
	_mouse_button(lone, true, origin)
	_mouse_move(lone, origin + Vector2(3, 0))
	_mouse_button(lone, false, origin + Vector2(3, 0))
	check(log.clicks == 1 and log.drags == 0, "a press that barely moves is still a click")
	_mouse_button(lone, true, origin)
	_mouse_move(lone, origin + Vector2(60, 0))
	_mouse_button(lone, false, origin + Vector2(500, 0))
	check(log.clicks == 1 and log.drags == 1 and log.ended == 1, "a long pull is a drag, released anywhere, and not a click")
	lone.draggable = false
	_mouse_button(lone, true, origin)
	_mouse_move(lone, origin + Vector2(60, 0))
	check(not lone.is_dragging(), "a card that is not draggable never starts a drag")
	lone.queue_free()

	var datas: Array[EnemyData] = []
	for id in ["lost_shade", "cinder_hound", "skittering_wisp"]:
		datas.append(load("res://data/enemies/%s.tres" % id) as EnemyData)
	node._start_with(Combatant.new("Wanderer", 40), datas, 1)
	node._refresh()
	var c: Combat = node._combat
	check(c.enemies.size() == 3, "setup: three enemies for the drag checks")
	c.energy = 9
	c.player.clear_block()
	c.plays_this_turn = 0
	for e in c.enemies:
		e.clear_statuses()
		e.clear_block()
		e.max_hp = 100
		e.hp = 100
	c.enemies[0].gain_block(4)
	c.enemies[1].apply_status(Combatant.Status.EXPOSED, 2)
	c.piles.hand.clear()
	for id in ["shove", "sweep", "brace"]:
		c.piles.hand.append(load("res://data/cards/%s.tres" % id))
	node._select_target(0)
	node._refresh()
	var enemy_views: Array[Fighter] = node._enemy_views
	for i in enemy_views.size():
		enemy_views[i].position = Vector2(i * 400.0, 0.0)
	var centers: Array[Vector2] = []
	for v in enemy_views:
		centers.append(v.get_global_rect().get_center())
	var nowhere := Vector2(-900, -900)
	var views := CardView.find_all(node._hand_box)
	check(views[0].draggable and views[1].draggable and not views[2].draggable, "single and all-enemies cards drag, a self card does not")

	# Dragging Shove (6 damage) across the enemies: each shows its own result and the selection stays put.
	var pick := views[0].get_global_rect().get_center()
	_mouse_button(views[0], true, pick)
	_mouse_move(views[0], centers[1])
	check(node.is_dragging_card() and node._drag_ghost != null and views[0].modulate.a < 1.0, "pulling a card lifts a ghost out of the hand")
	check(enemy_views[1].drop_hover and enemy_views[1].drop_text.contains("vs Exposed") and not enemy_views[0].drop_hover, "the enemy under the card shows the Exposed numbers")
	var expect1: Dictionary = node._target_preview(c.piles.hand[0], c.enemies[1])
	check(expect1.lost == 9 and enemy_views[1].drop_lost == 9, "the exposed enemy ghosts the 9 HP (6 x 1.5) it would lose, got %d" % enemy_views[1].drop_lost)
	_mouse_move(views[0], centers[0])
	check(enemy_views[0].drop_hover and enemy_views[0].drop_text.contains("after Block") and not enemy_views[1].drop_hover, "moving to the blocked enemy shows damage after its Block and clears the last one")
	_mouse_move(views[0], nowhere)
	check(not enemy_views[0].drop_hover and not enemy_views[1].drop_hover and not enemy_views[2].drop_hover, "no enemy is lit when the card is over empty space")
	_mouse_move(views[0], centers[1])
	_mouse_button(views[0], false, centers[1])
	check(not node.is_dragging_card() and not enemy_views[1].drop_hover, "dropping ends the drag and the highlight")
	check(c.enemies[1].hp == 100 - expect1.lost and c.enemies[0].hp == 100 and c.enemies[2].hp == 100, "the drop hit the dragged-to enemy, for what the preview said")
	check(node._target_index == 0, "a drop leaves the selected target alone")

	# An all-enemies card shows only the hovered enemy's numbers; a drop on any enemy plays it on all.
	c.enemies[0].clear_block()
	c.enemies[1].hp = 100
	node._refresh()
	views = CardView.find_all(node._hand_box)
	var sweep_index := -1
	for i in c.piles.hand.size():
		if c.piles.hand[i].target_mode == CardData.TargetMode.ALL_ENEMIES:
			sweep_index = i
	check(sweep_index >= 0, "setup: Sweep is still in hand")
	_mouse_button(views[sweep_index], true, views[sweep_index].get_global_rect().get_center())
	_mouse_move(views[sweep_index], centers[1])
	check(enemy_views[1].drop_text.contains("vs Exposed") and not enemy_views[2].drop_hover, "an all-enemies card previews just the hovered enemy")
	_mouse_move(views[sweep_index], centers[2])
	check(not enemy_views[2].drop_text.contains("Exposed") and enemy_views[2].drop_text.begins_with("Deals"), "its next enemy shows its own, unexposed, numbers")
	_mouse_move(views[sweep_index], nowhere)
	_mouse_button(views[sweep_index], false, nowhere)
	check(not node.is_dragging_card(), "releasing over empty space ends the drag")
	var hand_before := c.piles.hand.size()
	var energy_before := c.energy
	check(c.enemies[2].hp == 100, "releasing over empty space cancels: nothing was played")
	_mouse_button(views[sweep_index], true, views[sweep_index].get_global_rect().get_center())
	_mouse_move(views[sweep_index], centers[2])
	_mouse_button(views[sweep_index], false, centers[2])
	check(c.enemies[2].hp < 100 and c.enemies[0].hp < 100 and c.enemies[1].hp < 100, "dropping an all-enemies card on one enemy hits them all")
	check(c.piles.hand.size() == hand_before - 1 and c.energy < energy_before, "the drop played and paid for the card")

	# Esc abandons a drag; the release afterwards does nothing.
	c.energy = 9
	c.piles.hand.append(load("res://data/cards/shove.tres"))
	node._refresh()
	views = CardView.find_all(node._hand_box)
	var shove_view := views[views.size() - 1]
	var hp_before := c.enemies[2].hp
	_mouse_button(shove_view, true, shove_view.get_global_rect().get_center())
	_mouse_move(shove_view, centers[2])
	check(node.is_dragging_card(), "setup: dragging again")
	key(node, KEY_ESCAPE)
	check(not node.is_dragging_card() and not enemy_views[2].drop_hover and shove_view.modulate.a == 1.0, "Esc cancels the drag and puts the card back")
	_mouse_button(shove_view, false, centers[2])
	check(c.enemies[2].hp == hp_before, "the release after Esc plays nothing")
	# A boss has no HP bar of its own: the ghost goes on the wide bar at the top, and clears with the drag.
	node.boss_fight = true
	node.show_boss_intro = false
	var boss_datas: Array[EnemyData] = [load("res://data/enemies/the_brakeman.tres") as EnemyData]
	node._start_with(Combatant.new("Wanderer", 40), boss_datas, 1)
	node._refresh()
	var bc: Combat = node._combat
	bc.energy = 9
	bc.enemies[0].clear_block()
	bc.piles.hand.clear()
	bc.piles.hand.append(load("res://data/cards/shove.tres"))
	node._refresh()
	var boss_view: Fighter = node._enemy_views[0]
	var boss_card := CardView.find_all(node._hand_box)[0]
	check(node._boss_bar != null and node._boss_bar.drop_lost == -1, "setup: a boss fight with an idle boss bar")
	_mouse_button(boss_card, true, boss_card.get_global_rect().get_center())
	_mouse_move(boss_card, boss_view.get_global_rect().get_center())
	check(node._boss_bar.drop_lost == 6 and boss_view.drop_hover, "dragging over the boss ghosts the HP it would lose on the boss bar")
	_mouse_move(boss_card, Vector2(-900, -900))
	check(node._boss_bar.drop_lost == -1, "moving off the boss clears the boss bar ghost")
	_mouse_move(boss_card, boss_view.get_global_rect().get_center())
	key(node, KEY_ESCAPE)
	check(node._boss_bar.drop_lost == -1, "cancelling the drag clears the boss bar ghost")
	node.boss_fight = false


## The full-size inspection preview shows for a hovered hand card, ignores the mouse, and hides again.
func _check_preview(node: Control) -> void:
	node._start_combat()
	node._refresh()
	check(not node.preview_visible(), "no preview before any card is hovered")
	var views := CardView.find_all(node._hand_box)
	views[0].set_hovered(true)
	check(node.preview_visible(), "hovering a hand card shows the preview")
	check(node._preview.mouse_filter == Control.MOUSE_FILTER_IGNORE, "the preview does not block input")
	check(node._preview.card == views[0].card and node._preview.view_scale >= 1.5, "the preview is a larger copy of the hovered card")
	views[0].set_hovered(false)
	check(not node.preview_visible(), "the preview hides when the pointer leaves")
	views[0].set_hovered(true)
	node._refresh()
	check(not node.preview_visible(), "a hand rebuild hides a stale preview")
	CardView.reduced_motion = true
	var v := CardView.find_all(node._hand_box)[0]
	v.set_hovered(true)
	check(v._lift == 1.0, "reduced motion snaps the hover lift")
	CardView.reduced_motion = false


## The end-of-turn discard step on screen: marking, the confirm button's wording, Back, and a full
## 10-card hand fitting on one row of the 1152x648 window.
func _check_discard_ui(node: Control) -> void:
	node._start_combat()
	await process_frame
	var c: Combat = node._combat
	var screen := Rect2(Vector2.ZERO, Vector2(node.size))
	# Ten distinct cards in hand (the hand is set directly, as other tests here do).
	c.piles.hand.clear()
	for id in ["bash", "cold_steel", "last_pocket", "spree", "reckoning", "bash", "cold_steel", "last_pocket", "spree", "reckoning"]:
		c.piles.hand.append(load("res://data/cards/%s.tres" % id))
	node._refresh()
	for i in 3:
		await process_frame
	var views := CardView.find_all(node._hand_box)
	check(views.size() == 10, "ten hand cards are shown")
	var row_y := views[0].get_global_rect().position.y
	var one_row := true
	var inside := true
	for v in views:
		one_row = one_row and is_equal_approx(v.get_global_rect().position.y, row_y)
		inside = inside and screen.encloses(v.get_global_rect())
	check(one_row and inside, "a 10-card hand sits on one row inside the window")
	var hand_rect: Rect2 = node._hand_box.get_global_rect()
	var within_box := true
	for v in views:
		within_box = within_box and v.get_global_rect().position.x >= hand_rect.position.x - 1.0 and v.get_global_rect().end.x <= hand_rect.end.x + 1.0
	check(within_box, "the 10 cards stay inside the hand area")
	var visible_ok := true
	for i in views.size() - 1:
		# The left part of each card (cost stamp and hotkey) stays uncovered by its right neighbour.
		visible_ok = visible_ok and views[i + 1].get_global_rect().position.x - views[i].get_global_rect().position.x >= 40.0
	check(visible_ok, "each overlapped card still shows at least its left 40 px")
	check(views[9].hotkey == 10, "the tenth card has hotkey 10 (shown as 0)")
	# Over the keep limit: the confirm button counts down.
	node._on_end_turn_pressed()
	check(c.phase == Combat.Phase.DISCARDING and node._end_turn_button.disabled and node._end_turn_button.text == "Discard 5 more", "a 10-card hand must discard 5: the button is disabled and says so")
	check(node._result_label.text.contains("Choose cards to discard"), "the discard step shows a hint")
	views = CardView.find_all(node._hand_box)
	check(views.all(func(v: CardView) -> bool: return v.is_clickable() and not v.discard_marked), "in the discard step every card is clickable and none is marked yet")
	for i in 4:
		views[i].pressed.emit()
	views = CardView.find_all(node._hand_box)
	check(views[0].discard_marked and views[3].discard_marked and not views[4].discard_marked, "clicked cards show the DISCARD mark")
	check(node._end_turn_button.disabled and node._end_turn_button.text == "Discard 1 more", "one more to go")
	key(node, KEY_0) # the tenth card
	check(c.discard_marks == ([0, 1, 2, 3, 9] as Array[int]) and not node._end_turn_button.disabled and node._end_turn_button.text == "Discard 5", "key 0 marks the tenth card and enables Discard 5")
	key(node, KEY_1)
	check(c.discard_marks.size() == 4 and node._end_turn_button.disabled, "pressing the key again unmarks")
	node._cancel_button.pressed.emit()
	check(c.phase == Combat.Phase.PLAYER_TURN and c.piles.hand.size() == 10 and c.discard_marks.is_empty(), "Back returns to the turn with the hand unchanged")
	check(not node._end_turn_button.disabled and node._end_turn_button.text == "End Turn" and not node._result_label.text.contains("Choose"), "the End Turn button and hint are restored")
	# A small hand: Keep all, then marking changes the wording.
	c.piles.hand.assign(c.piles.hand.slice(0, 4))
	node._refresh()
	node._on_end_turn_pressed()
	check(node._end_turn_button.text == "Keep all" and not node._end_turn_button.disabled, "a hand of 4 can simply be kept")
	CardView.find_all(node._hand_box)[1].pressed.emit()
	check(node._end_turn_button.text == "Discard 1", "marking a card changes the button to Discard 1")
	var turn: int = c.turn
	node._on_end_turn_pressed()
	check(c.turn == turn + 1 and c.piles.hand.size() == 5, "confirming discards the marked card and draws back to 5")


func _proto(id: String) -> CardData:
	return load("res://data/prototype/%s.tres" % id) as CardData


## Keyword cards on screen: keyword line and X cost on the face, Dormant cannot be played, Anchor and Fading
## cards cannot be marked for discard and do not count toward the 5, the Forgotten count, and multi-hit
## and Surge previews.
func _check_keywords(node: Control) -> void:
	node._start_combat()
	await process_frame
	var c: Combat = node._combat
	c.player.clear_block()
	c.plays_this_turn = 0
	c.energy = 3
	for e in c.enemies:
		e.clear_statuses()
		e.clear_block()
		e.max_hp = 500
		e.hp = 500
	node._select_target(0)

	# Card face: keyword line, X cost, markers.
	var face := CardView.new()
	face.set_card(_proto("surge_slash"))
	check(face.keyword_text() == "SURGE" and face.cost_text() == "X", "a Surge card shows the SURGE keyword line and an X cost")
	face.set_card(_proto("forgotten_strike"))
	check(face.keyword_text() == "FORGOTTEN" and face.cost_text() == "1", "a Forgotten card shows its keyword line and a numeric cost")
	face.set_card(load("res://data/cards/bash.tres"))
	check(face.keyword_text() == "" and face.cost_text() == "1", "a plain card has no keyword line")
	face.set_card(_proto("fading_jab"))
	check(face.self_modulate.a < 1.0, "a Fading card is drawn semi-transparent")
	face.free()

	# Dormant: not clickable, not draggable, not playable, no preview.
	c.piles.hand.assign([_proto("dormant_burden"), _proto("double_strike")])
	node._refresh()
	await process_frame
	var views := CardView.find_all(node._hand_box)
	check(views[0].state == CardView.State.UNPLAYABLE and not views[0].is_clickable() and views[0].note == "DORMANT", "a Dormant card is unplayable and says so")
	check(views[0].preview == "", "a Dormant card shows no damage preview")
	var hand_n := c.piles.hand.size()
	var origin := views[0].get_global_rect().position + Vector2(20, 20)
	_mouse_button(views[0], true, origin)
	_mouse_move(views[0], origin + Vector2(80, 0))
	check(not node.is_dragging_card() and not views[0].is_dragging(), "a Dormant card cannot be dragged")
	_mouse_button(views[0], false, origin + Vector2(80, 0))
	_mouse_button(views[0], true, origin)
	_mouse_button(views[0], false, origin)
	node._play_hand_card(0)
	check(c.piles.hand.size() == hand_n and c.energy == 3, "clicking a Dormant card plays nothing")
	check(node._target_preview(_proto("dormant_burden"), c.enemies[0]).is_empty(), "a Dormant card has no target preview")

	# Multi-hit preview: 3 x2 against 4 Block, then also Exposed (3 -> 4 per hit, rounded down).
	var dbl := _proto("double_strike")
	c.enemies[0].gain_block(4)
	var info: Dictionary = node._target_preview(dbl, c.enemies[0])
	check(info.dealt == 6 and info.lost == 2, "3 x2 against 4 Block deals 6 and loses 2 HP (%s)" % str(info))
	check(info.text.contains("Deals 6 (3 x2)") and info.text.contains("2 after Block"), "multi-hit text: " + info.text.replace("
", " | "))
	c.enemies[0].apply_status(Combatant.Status.EXPOSED, 2)
	info = node._target_preview(dbl, c.enemies[0])
	check(info.dealt == 8 and info.lost == 4, "3 x2 against 4 Block and Exposed deals 8 and loses 4 HP (%s)" % str(info))
	var hp_before: int = c.enemies[0].hp
	c.piles.hand.assign([dbl])
	node._refresh()
	c.energy = 3
	c.play_card(0, 0)
	check(hp_before - c.enemies[0].hp == info.lost, "the multi-hit preview matches the real damage")
	c.enemies[0].clear_statuses()
	c.enemies[0].clear_block()

	# Surge preview scales with the energy that would be spent; clicking plays it for all the energy.
	var slash := _proto("surge_slash")
	c.energy = 4
	info = node._target_preview(slash, c.enemies[0])
	check(info.dealt == 12 and info.text.contains("Deals 12 (3 x4)"), "Surge Slash at 4 energy previews 12: " + info.text.replace("
", " | "))
	c.energy = 2
	check(node._target_preview(slash, c.enemies[0]).dealt == 6, "at 2 energy the Surge preview is 6")
	c.energy = 0
	check(node._target_preview(slash, c.enemies[0]).dealt == 0, "at 0 energy the Surge preview is 0")
	c.energy = 3
	c.piles.hand.assign([slash])
	node._refresh()
	views = CardView.find_all(node._hand_box)
	check(views[0].is_clickable() and views[0].cost_text() == "X" and views[0].preview.contains("Deals 9"), "a Surge card is playable and previews with the current energy: " + views[0].preview.replace("
", " | "))
	hp_before = c.enemies[0].hp
	views[0].pressed.emit()
	check(c.energy == 0 and hp_before - c.enemies[0].hp == 9, "clicking a Surge card spends all energy and hits once per energy")
	c.energy = 0
	c.piles.hand.assign([slash])
	node._refresh()
	check(CardView.find_all(node._hand_box)[0].is_clickable(), "a Surge card stays playable at 0 energy")

	# Pile label shows the Forgotten count.
	check(node._pile_label.text.contains("Forgotten 0"), "the pile label lists Forgotten: " + node._pile_label.text.replace("
", " | "))
	c.energy = 3
	var discarded_before := c.piles.discard_pile.size()
	c.piles.hand.assign([_proto("forgotten_strike")])
	node._refresh()
	c.play_card(0, 0)
	check(node._pile_label.text.contains("Forgotten 1") and node._pile_label.text.contains("Discard %d
" % discarded_before), "a played Forgotten card is counted under Forgotten, not Discard: " + node._pile_label.text.replace("
", " | "))

	# Discard step: Anchor and Fading cards cannot be marked and do not count toward the 5.
	var plain := load("res://data/cards/bash.tres") as CardData
	c.piles.hand.assign([plain, plain, plain, plain, plain, plain, plain, _proto("anchor_ward"), _proto("fading_jab")])
	node._refresh()
	node._on_end_turn_pressed()
	check(c.phase == Combat.Phase.DISCARDING and node._end_turn_button.text == "Discard 2 more", "7 counted cards plus Anchor and Fading must discard 2: " + node._end_turn_button.text)
	check(node._result_label.text.contains("keep 7 of up to 5") and node._result_label.text.contains("Fading cards left in hand will be Forgotten"), "the prompt counts only normal cards and warns about Fading: " + node._result_label.text)
	views = CardView.find_all(node._hand_box)
	check(views[7].note == "ANCHOR: STAYS" and views[8].note == "FORGOTTEN AT END", "Anchor and Fading cards say what happens to them in the discard step")
	views[7].pressed.emit()
	views[8].pressed.emit()
	check(c.discard_marks.is_empty() and not CardView.find_all(node._hand_box)[7].discard_marked, "Anchor and Fading cards cannot be marked")
	views[0].pressed.emit()
	views[1].pressed.emit()
	check(not node._end_turn_button.disabled and node._end_turn_button.text == "Discard 2", "marking two normal cards is enough")
	node._on_end_turn_pressed()
	check(c.piles.forgotten.size() == 2 and c.piles.hand.has(_proto("anchor_ward")), "confirming forgets the Fading card and keeps the Anchor card in hand")


func _chip_labels(view: Fighter) -> Dictionary:
	var out := {}
	for chip in view.status_chips():
		out[chip.kind] = chip.label
	return out


## Phase 2b: status badges on both sides, live card numbers, previews and intents through the shared pipeline.
func _check_statuses(node: Control) -> void:
	var datas: Array[EnemyData] = []
	for id in ["lost_shade", "cinder_hound"]:
		datas.append(load("res://data/enemies/%s.tres" % id) as EnemyData)
	node._start_with(Combatant.new("Wanderer", 60), datas, 1)
	node._refresh()
	await process_frame
	var c: Combat = node._combat
	c.energy = 9
	c.player.clear_block()
	c.plays_this_turn = 0
	for e in c.enemies:
		e.clear_statuses()
		e.clear_block()
		e.max_hp = 500
		e.hp = 500
	node._select_target(0)
	var enemy: EnemyUnit = c.enemies[0]
	var enemy_view: Fighter = node._enemy_views[0]
	var player_view: Fighter = node._player_view

	# Badges: every status shows with its number (turns, or the signed stack), on enemy and player alike.
	for pair in [[enemy, enemy_view], [c.player, player_view]]:
		var unit: Combatant = pair[0]
		var view: Fighter = pair[1]
		unit.clear_statuses()
		node._refresh()
		check(_chip_labels(view).is_empty(), "%s: no badges without statuses" % unit.display_name)
		unit.apply_status(Combatant.Status.SHAKEN, 2)
		unit.apply_status(Combatant.Status.FRAYED, 3)
		unit.apply_status(Combatant.Status.MALICE, 2)
		unit.apply_status(Combatant.Status.WARD, -1)
		node._refresh()
		var labels := _chip_labels(view)
		check(labels.get(&"shaken") == "2" and labels.get(&"frayed") == "3" and labels.get(&"malice") == "+2" and labels.get(&"ward") == "-1", "%s: badges show turns and signed stacks: %s" % [unit.display_name, str(labels)])
		var chips := view.status_chips()
		var ward_chip: Dictionary = chips[chips.size() - 1]
		var malice_chip: Dictionary = chips[chips.size() - 2]
		check(ward_chip.color == CardView.STATUS_NEGATIVE and malice_chip.color == CardView.kind_color(CardEffect.Kind.MALICE), "%s: a debuff badge is tinted red, a buff keeps its colour" % unit.display_name)
		# Temporary stacks count, and a stack that cancels to 0 has no badge.
		unit.apply_temp_stack(Combatant.Status.MALICE, 3)
		unit.apply_status(Combatant.Status.WARD, 1)
		node._refresh()
		labels = _chip_labels(view)
		check(labels.get(&"malice") == "+5" and not labels.has(&"ward"), "%s: temporary stacks show and a stack at 0 has no badge: %s" % [unit.display_name, str(labels)])
		# Everything at once: pills wrap into rows that stay inside the figure and never overlap.
		unit.apply_status(Combatant.Status.WARD, 4)
		unit.apply_status(Combatant.Status.EXPOSED, 2)
		unit.apply_status(Combatant.Status.HAUNTED, 3)
		unit.hold = 4
		unit.thorns = 12
		node._refresh()
		var rects := view.chip_rects()
		var ok := rects.size() == 8 and view.status_chips().size() == 8
		for i in rects.size():
			ok = ok and Rect2(Vector2.ZERO, view.size).encloses(rects[i])
			for j in range(i + 1, rects.size()):
				ok = ok and not rects[i].intersects(rects[j])
		check(ok, "%s: eight badges fit inside the figure without overlap" % unit.display_name)
		unit.clear_statuses()
	node._refresh()

	# Tooltips explain each rule in one line.
	c.player.apply_status(Combatant.Status.SHAKEN, 2)
	c.player.apply_status(Combatant.Status.FRAYED, 1)
	c.player.apply_status(Combatant.Status.MALICE, -2)
	c.player.apply_status(Combatant.Status.WARD, 3)
	node._refresh()
	var tip: String = player_view.tooltip_text
	check(tip.contains("Shaken 2: deals 25% less damage") and tip.contains("Frayed 1: gains 25% less Block") and tip.contains("Malice -2: -2 damage on every hit") and tip.contains("Ward +3: +3 Block from every card"), "the player tooltip explains each status: " + tip.replace("\n", " | "))
	c.player.clear_statuses()

	# Live card numbers: printed with no modifier, green when raised, red when lowered, equal when they cancel.
	var strike := _proto("strike")
	var guard := _proto("guard")
	var face_view := CardView.new()
	node.add_child(face_view)
	face_view.set_card(strike)
	check(face_view.body_lines()[0].text == "Deal 6" and face_view.body_lines()[0].delta == 0, "outside a fight a card shows its printed numbers")
	face_view.live = c.player
	check(face_view.body_lines()[0].text == "Deal 6" and face_view.body_lines()[0].delta == 0, "with no modifier the live number equals the printed one")
	c.player.apply_status(Combatant.Status.MALICE, 2)
	check(face_view.body_lines()[0].text == "Deal 8" and face_view.body_lines()[0].delta == 1, "Malice +2 raises Deal 6 to 8 (green)")
	c.player.apply_temp_stack(Combatant.Status.MALICE, -1)
	check(face_view.body_lines()[0].text == "Deal 7" and face_view.body_lines()[0].delta == 1, "a temporary stack counts in the live number")
	c.player.clear_statuses()
	c.player.apply_status(Combatant.Status.SHAKEN, 2)
	check(face_view.body_lines()[0].text == "Deal 4" and face_view.body_lines()[0].delta == -1, "Shaken lowers Deal 6 to 4 (red)")
	c.player.apply_status(Combatant.Status.MALICE, -9)
	check(face_view.body_lines()[0].text == "Deal 0" and face_view.body_lines()[0].delta == -1, "heavy negative Malice shows Deal 0")
	face_view.set_card(guard)
	c.player.clear_statuses()
	c.player.apply_status(Combatant.Status.FRAYED, 2)
	check(face_view.body_lines()[0].text == "Block 4" and face_view.body_lines()[0].delta == -1, "Frayed lowers Block 6 to 4 (red)")
	c.player.apply_status(Combatant.Status.WARD, 2)
	check(face_view.body_lines()[0].text == "Block 6" and face_view.body_lines()[0].delta == 0, "Ward +2 and Frayed cancel: Block 6 equals the printed number")
	c.player.apply_status(Combatant.Status.WARD, 4)
	check(face_view.body_lines()[0].text == "Block 9" and face_view.body_lines()[0].delta == 1, "Ward +6 then Frayed raises Block 6 to 9 (green): " + face_view.body_lines()[0].text)
	check(face_view.body_lines()[0].text == "Block %d" % c.player.block_from_card(6), "the live Block is the engine's block_from_card")
	c.player.clear_statuses()
	c.player.apply_status(Combatant.Status.MALICE, 1)
	face_view.set_card(_proto("double_strike"))
	check(face_view.body_lines()[0].text == "Deal 4 x2" and face_view.body_lines()[0].delta == 1, "a multi-hit shows the per-hit number: " + face_view.body_lines()[0].text)
	face_view.set_card(_proto("surge_slash"))
	check(face_view.body_lines()[0].text == "Deal 4 x energy spent", "a Surge hit shows the per-hit number: " + face_view.body_lines()[0].text)
	face_view.set_card(_proto("surge_guard"))
	c.player.apply_status(Combatant.Status.WARD, 2)
	check(face_view.body_lines()[0].delta == 0 and face_view.body_lines()[0].text == "Block 4 per energy spent", "Block that scales with energy keeps its printed text")
	face_view.set_card(_proto("shake_foe"))
	check(face_view.body_lines()[0].delta == 0 and face_view.body_lines()[0].text == "Shaken 2", "a status effect line is never rewritten")
	face_view.set_card(_proto("dormant_burden"))
	check(face_view.body_lines()[0].delta == 0, "a Dormant card is unaffected")
	face_view.queue_free()
	# Hand cards are bound to the player, so they follow its statuses.
	c.player.clear_statuses()
	c.player.apply_status(Combatant.Status.MALICE, 3)
	c.piles.hand.assign([strike, guard])
	node._refresh()
	var hand := CardView.find_all(node._hand_box)
	check(hand[0].live == c.player and hand[0].body_lines()[0].text == "Deal 9", "a hand card shows the live number")

	# The drag preview and card-face preview go through hit_damage: they must equal the damage really dealt.
	var dbl := _proto("double_strike")
	var setups := [[0, 0, false, 0], [3, 0, false, 0], [3, 2, false, 0], [3, 2, true, 0], [-2, 0, true, 5], [-9, 2, false, 0], [2, 2, true, 7], [0, 3, false, 4]]
	for card in [strike, dbl]:
		for setup in setups:
			var label := "%s malice %d shaken %d exposed %s block %d" % [card.id, setup[0], setup[1], str(setup[2]), setup[3]]
			c.player.clear_statuses()
			enemy.clear_statuses()
			enemy.clear_block()
			enemy.hp = 500
			c.energy = 9
			if setup[0] != 0:
				c.player.apply_status(Combatant.Status.MALICE, setup[0])
			if setup[1] > 0:
				c.player.apply_status(Combatant.Status.SHAKEN, setup[1])
			if setup[2]:
				enemy.apply_status(Combatant.Status.EXPOSED, 2)
			enemy.gain_block(setup[3])
			c.piles.hand.assign([card])
			node._refresh()
			var info: Dictionary = node._target_preview(card, enemy)
			var views := CardView.find_all(node._hand_box)
			var face: String = views[0].preview
			# Drag it over the enemy: the figure's drop label is the same preview.
			node._on_drag_started(views[0])
			node._on_drag_moved(enemy_view.get_global_rect().get_center())
			var drop_text: String = enemy_view.drop_text
			node._end_drag()
			var before := enemy.hp
			check(c.play_card(0, 0), "%s: played" % label)
			var lost := before - enemy.hp
			check(info.get("lost", -1) == lost, "%s: the preview says %s, the hit lost %d" % [label, str(info), lost])
			check(face.strip_edges() == info.text.strip_edges() and drop_text == info.text.strip_edges(), "%s: the card face and the drag label show the same preview (%s | %s)" % [label, face.replace("\n", " "), drop_text])
	# The all-enemies line also uses the player's Malice.
	c.player.clear_statuses()
	c.player.apply_status(Combatant.Status.MALICE, 2)
	c.energy = 9
	var sweep := load("res://data/cards/sweep.tres") as CardData
	c.piles.hand.assign([sweep])
	node._refresh()
	var sweep_text: String = (CardView.find_all(node._hand_box)[0] as CardView).preview
	check(sweep_text.contains("Deals %d" % (sweep.effects[0].amount + 2)), "the all-enemies preview includes Malice: " + sweep_text.replace("\n", " "))
	c.player.clear_statuses()

	# Enemy Omen: the damage shown to the player includes the enemy's Malice and Shaken, then the player's Expose.
	var attack := CardEffect.make(CardEffect.Kind.DAMAGE, 8)
	var plain := EnemyData.make("Dummy", 30, [attack] as Array[CardEffect], &"dummy")
	var dummy := EnemyUnit.new(plain)
	for setup in [[0, 0, 0], [3, 0, 0], [3, 2, 0], [-2, 0, 0], [3, 2, 2], [-9, 0, 0]]:
		dummy.clear_statuses()
		c.player.clear_statuses()
		if setup[0] != 0:
			dummy.apply_status(Combatant.Status.MALICE, setup[0])
		if setup[1] > 0:
			dummy.apply_status(Combatant.Status.SHAKEN, setup[1])
		if setup[2] > 0:
			c.player.apply_status(Combatant.Status.EXPOSED, setup[2])
		var shown := Fighter.effective_intent(dummy, c.player)
		# What a real hit does to a copy of the player in the same state.
		var probe := Combatant.new("Probe", 500)
		if setup[2] > 0:
			probe.apply_status(Combatant.Status.EXPOSED, setup[2])
		probe.take_damage_final(Combatant.hit_damage(8, dummy, probe))
		var real := 500 - probe.hp
		check(shown.amount == real, "enemy intent %s: shown %d, dealt %d" % [str(setup), shown.amount, real])
	# On the real fighter: the badge number and the tooltip line.
	c.player.clear_statuses()
	enemy.clear_statuses()
	var enemy_intent := enemy.current_intent()
	if enemy_intent != null and enemy_intent.kind == CardEffect.Kind.DAMAGE:
		enemy.apply_status(Combatant.Status.MALICE, 4)
		enemy.apply_status(Combatant.Status.SHAKEN, 2)
		node._refresh()
		var want := Combatant.hit_damage(enemy_intent.amount, enemy, c.player)
		check(Fighter.effective_intent(enemy, c.player).amount == want and want != enemy_intent.amount and node._enemy_tooltip(enemy).contains("Next: Deal %d" % want), "the enemy tooltip shows the damage after its Malice and Shaken: " + node._enemy_tooltip(enemy).replace("\n", " | "))
	check(enemy_view.intent_target == c.player, "the enemy figure aims its Omen at the player")
	enemy.clear_statuses()
	# Intents that apply the new statuses are shown as printed, and every intent kind draws.
	for kind in [CardEffect.Kind.SHAKEN, CardEffect.Kind.FRAYED, CardEffect.Kind.MALICE, CardEffect.Kind.WARD]:
		var eff := CardEffect.make(kind, -2 if kind == CardEffect.Kind.WARD else 2)
		var unit := EnemyUnit.new(EnemyData.make("Caster", 10, [eff] as Array[CardEffect], &"caster"))
		var fighter := Fighter.new()
		node.add_child(fighter)
		fighter.set_enemy(unit)
		fighter.intent_target = c.player
		await process_frame
		check(Fighter.effective_intent(unit, c.player) == eff, "an intent of kind %d is shown as printed" % kind)
		fighter.queue_free()


func _card(id: String) -> CardData:
	return load("res://data/cards/%s.tres" % id) as CardData


## A fresh fight with the screen in a known state: energy to spare, tough enemies, no statuses.
func _fresh_fight(node: Control) -> Combat:
	node._start_combat()
	await process_frame
	var c: Combat = node._combat
	c.energy = 9
	c.plays_this_turn = 0
	c.player.clear_block()
	c.player.clear_statuses()
	for e in c.enemies:
		e.clear_statuses()
		e.clear_block()
		e.max_hp = 500
		e.hp = 500
	node._select_target(0)
	return c


func _ids(cards: Array[CardData]) -> Array:
	return cards.map(func(card: CardData) -> StringName: return card.id)


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
	node._play_hand_card(0)
	check(c.phase == Combat.Phase.CHOOSING and node.choice_overlay_visible(), "playing Glimpse 3 opens the overlay")
	var overlay: ChoiceOverlay = node._choice_overlay
	check(_ids(overlay.cards) == [&"shove", &"brace", &"bash"], "the overlay lists the top 3 cards in draw order")
	check(overlay.heading_label.text.begins_with("Glimpse") and overlay.confirm_button.text == "Keep all" and not overlay.confirm_button.disabled, "Glimpse: heading, and zero picks allowed (Keep all)")
	check(CardView.find_all(overlay).size() == 3, "one card view per offered card")
	# Nothing behind it works.
	var hand_views := CardView.find_all(node._hand_box)
	check(hand_views.size() == 1 and not hand_views[0].is_clickable(), "hand cards are not clickable while the overlay is up")
	var hand_before := c.piles.hand.size()
	node._play_hand_card(0)
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
	node._play_hand_card(0)
	key(node, KEY_ENTER)
	check(c.phase == Combat.Phase.PLAYER_TURN and c.piles.draw_pile == draw_order and c.piles.discard_pile.size() == 1, "Enter with nothing marked keeps everything (Keep all)")

	# Recall: exactly the required number of picks.
	c = await _fresh_fight(node)
	c.piles.forgotten.assign([_card("shove"), _card("brace"), _card("bash")])
	c.piles.hand.assign([_proto("recall_2")])
	node._refresh()
	node._play_hand_card(0)
	check(c.phase == Combat.Phase.CHOOSING and node.choice_overlay_visible(), "playing Recall 2 opens the overlay")
	overlay = node._choice_overlay
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
	node._play_hand_card(0)
	overlay = node._choice_overlay
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
	node._play_hand_card(0)
	var first: ChoiceOverlay = node._choice_overlay
	check(c.phase == Combat.Phase.CHOOSING and first.is_glimpse() and first.cards.size() == 2, "the first queued choice (Glimpse) opens first")
	first.toggle(1)
	first.confirm()
	check(c.phase == Combat.Phase.CHOOSING and node.choice_overlay_visible() and node._choice_overlay != first and not node._choice_overlay.is_glimpse(), "resolving it opens the second (Recall) in a fresh overlay")
	check(_ids(c.piles.discard_pile).has(&"brace") and node._choice_overlay.marks.is_empty(), "the first pick was applied and the new overlay starts unmarked")
	node._choice_overlay.toggle(0)
	node._choice_overlay.confirm()
	check(c.phase == Combat.Phase.PLAYER_TURN and not node.choice_overlay_visible() and _ids(c.piles.hand).has(&"shove"), "after the second choice the turn resumes")

	# A refresh while choosing keeps the marks.
	c = await _fresh_fight(node)
	c.piles.draw_pile.assign(draw_order)
	c.piles.hand.assign([_proto("glimpse_3")])
	node._refresh()
	node._play_hand_card(0)
	overlay = node._choice_overlay
	overlay.toggle(1)
	node._refresh()
	check(node._choice_overlay == overlay and overlay.marks == ([1] as Array[int]), "an unrelated refresh keeps the overlay and its marks")


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
	check(node._pile_label.mouse_filter == Control.MOUSE_FILTER_STOP and node._pile_label.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND, "the pile counters take clicks and show a hand cursor")
	node._set_pile_hover(true)
	check(node._pile_label.modulate != Color.WHITE, "the pile counters tint on hover")
	node._set_pile_hover(false)
	check(node._pile_label.modulate == Color.WHITE, "and clear the tint")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	var h: float = maxf(node._pile_label.size.y, 3.0)
	press.position = Vector2(4, h * 0.2)
	node._on_pile_label_input(press)
	check(node.pile_viewer_open() and node._pile_viewer.pile == PileViewer.Pile.DRAW, "clicking the Draw line opens the Draw pile")
	var viewer: PileViewer = node._pile_viewer
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
	node._play_hand_card(0)
	key(node, KEY_E)
	key(node, KEY_1)
	check(c.piles.hand.size() == hand_n and c.phase == Combat.Phase.PLAYER_TURN and node.pile_viewer_open(), "keys do nothing behind the pile viewer")
	key(node, KEY_ESCAPE)
	check(not node.pile_viewer_open(), "Esc closes the pile viewer")
	# Each pile by name, the Close button, and a click outside the panel.
	for which in [PileViewer.Pile.DISCARD, PileViewer.Pile.FORGOTTEN, PileViewer.Pile.DRAW]:
		check(node.open_pile_viewer(which) and node._pile_viewer.pile == which, "the viewer opens on pile %d" % which)
		node._close_pile_viewer()
	node.open_pile_viewer(PileViewer.Pile.DRAW)
	node._pile_viewer.close_button.pressed.emit()
	check(not node.pile_viewer_open(), "the Close button closes the viewer")
	node.open_pile_viewer(PileViewer.Pile.DRAW)
	var outside := InputEventMouseButton.new()
	outside.button_index = MOUSE_BUTTON_LEFT
	outside.pressed = true
	node._pile_viewer._gui_input(outside)
	check(not node.pile_viewer_open(), "a click outside the panel closes the viewer")
	# It works in the discard step, not in the enemy phase.
	node._on_end_turn_pressed()
	check(c.phase == Combat.Phase.DISCARDING and node.open_pile_viewer(PileViewer.Pile.DISCARD), "the viewer opens during the discard step")
	node._close_pile_viewer()
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
	node._play_hand_card(0)
	check(node.cue_count == cue_before + 1 and node.last_cue_text.contains("Heavy Blow") and node.last_cue_text.contains("hand"), "playing a card that adds a card shows a cue: '%s'" % node.last_cue_text)
	check(node._log_label.get_parsed_text().contains("Added Heavy Blow to your hand") and c.piles.hand.size() == 1, "and logs it, and the card is in hand")
	await process_frame


## Damage per Forgotten on screen: the preview grows with the Forgotten pile and equals the damage dealt.
func _check_forgotten_damage(node: Control) -> void:
	var c: Combat
	var strike := _proto("pile_strike")
	var seen := {}
	for setup in [[0, 0], [2, 0], [5, 0], [5, 3]]:
		var forgotten_count: int = setup[0]
		var malice: int = setup[1]
		c = await _fresh_fight(node)
		var pile: Array[CardData] = []
		for i in forgotten_count:
			pile.append(_card("shove"))
		c.piles.forgotten.assign(pile)
		if malice != 0:
			c.player.apply_status(Combatant.Status.MALICE, malice)
		c.piles.hand.assign([strike])
		node._refresh()
		var text: String = (node._hand_box.get_child(0) as CardView).preview
		c.play_card(0, 0)
		var lost: int = 500 - c.enemies[0].hp
		check(text.contains("Deals %d" % lost), "Forgotten damage preview matches the hit with %d Forgotten, Malice %d: '%s' vs %d" % [forgotten_count, malice, text.replace("\n", " "), lost])
		seen[text] = true
	check(seen.size() == 4, "the preview changes as the Forgotten pile and Malice change")
	# The drag preview and the all-enemies line use the Forgotten count too.
	c = await _fresh_fight(node)
	var many: Array[CardData] = []
	for i in 4:
		many.append(_card("shove"))
	c.piles.forgotten.assign(many)
	var all_effects: Array[CardEffect] = [CardEffect.make(CardEffect.Kind.DAMAGE_PER_FORGOTTEN, 2)]
	var sweep_all := CardData.make(&"sweep_forgotten", "Sweep", 1, all_effects, CardData.TargetMode.ALL_ENEMIES)
	check(node._target_preview(strike, c.enemies[0]).get("dealt", -1) == 8, "the drag preview of Pile Strike with 4 Forgotten is 8")
	check(node._damage_preview(sweep_all).contains("Deals 8 (x%d enemies)" % c.living_enemies().size()), "the all-enemies preview uses the Forgotten count: " + node._damage_preview(sweep_all))
	c.piles.forgotten.append(_card("brace"))
	check(node._target_preview(strike, c.enemies[0]).get("dealt", -1) == 10, "the preview grows when the Forgotten pile does")


func _initialize() -> void:
	var node: Control = (load("res://battle.tscn") as PackedScene).instantiate()
	root.add_child(node)
	await process_frame
	node.seed_override = 7 # a reproducible encounter and hand; the checks below must hold for any draw
	var tries := 0
	while node._combat.enemies.size() < 3 and tries < 100:
		node._start_combat()
		tries += 1
	check(node._combat.enemies.size() == 3, "3 enemies")
	var c: Combat = node._combat
	var before: String = node._pile_label.text
	check(before.begins_with("Draw "), "pile label " + before)
	var idx := -1
	for i in c.piles.hand.size():
		if c.can_play(i):
			idx = i
			break
	var hand_n := c.piles.hand.size()
	var views := CardView.find_all(node._hand_box)
	check(views.size() == hand_n, "one card view per hand card")
	for i in views.size():
		check(views[i].card == c.piles.hand[i] and views[i].hotkey == i + 1, "hand card %d shows its card and hotkey" % (i + 1))
		check(views[i].is_clickable() == c.can_play(i) and (views[i].state == CardView.State.UNPLAYABLE) == not c.can_play(i), "hand card %d is clickable exactly when playable" % (i + 1))
	var disc := c.piles.discard_pile.size()
	key(node, KEY_1 + idx)
	check(c.piles.discard_pile.size() == disc + 1, "number key played (discard grew)")
	check(node._pile_label.text != before, "pile label changed: " + node._pile_label.text)
	node._select_target(0)
	# The card played above may itself have exposed the target, so start from a clean slate.
	c.enemies[0].clear_statuses()
	c.player.clear_statuses()
	c.enemies[0].apply_status(Combatant.Status.EXPOSED, 2)
	c.player.apply_status(Combatant.Status.EXPOSED, 3)
	check(node._player_view.tooltip_text.contains("Takes 1.5x damage, rounded down, for 3 more turns."), "player tooltip: " + node._player_view.tooltip_text)
	var enemy_views: Array[Fighter] = node._enemy_views
	check(enemy_views.size() == 3 and enemy_views[0].tooltip_text.contains("2 more turns"), "enemy tooltip")
	check(not enemy_views[1].tooltip_text.contains("more turns"), "no status tooltip unexposed")
	c.enemies[0].max_haunt = 5
	c.enemies[0].apply_status(Combatant.Status.HAUNTED, 9)
	check(node._enemy_tooltip(c.enemies[0]).contains("Haunt capped at 5"), "capped enemy tooltip shows the cap")
	check(not node._enemy_tooltip(c.enemies[1]).contains("capped"), "uncapped enemy tooltip has no cap line")
	c.enemies[0].clear_statuses()
	c.enemies[0].max_haunt = 0
	c.enemies[0].apply_status(Combatant.Status.EXPOSED, 2)
	var all_txt := ""
	for b in node._hand_box.get_children():
		all_txt += (b as CardView).preview + "\n---\n"
	print(all_txt)
	var dmg_cards := 0
	for card in c.piles.hand:
		if card.target_mode == CardData.TargetMode.SINGLE_ENEMY and card.describe().contains("Deal"):
			dmg_cards += 1
	check(all_txt.contains("vs Exposed") or dmg_cards == 0, "exposed preview present")
	if dmg_cards > 0:
		node._select_target(1)
		var t2 := ""
		for b in node._hand_box.get_children():
			t2 += (b as CardView).preview
		check(not t2.contains("vs Exposed"), "no exposed preview on unexposed target")
		node._select_target(0)
	c.enemies[1].take_damage(9999)
	node._select_target(0)
	key(node, KEY_RIGHT)
	check(node._target_index == 2, "right skips defeated")
	key(node, KEY_RIGHT)
	check(node._target_index == 0, "right wraps")
	key(node, KEY_TAB, true)
	check(node._target_index == 2, "shift-tab back skips defeated")
	key(node, KEY_LEFT)
	check(node._target_index == 0, "left")
	# The card played above may have drawn extra cards (Borrowed Breath, Steady Breath), leaving more than
	# HAND_SIZE in hand; then the discard step rightly asks to "Discard N more" instead of "Keep all".
	# Trim to a keepable hand so the Keep all / E, E steps below do not depend on the random draw.
	while c.piles.hand.size() > Combat.HAND_SIZE:
		c.piles.hand.pop_back()
	node._refresh()
	var turn: int = c.turn
	key(node, KEY_E)
	check(c.phase == Combat.Phase.DISCARDING and c.turn == turn, "E opens the discard step instead of ending the turn")
	check(node._cancel_button.visible and node._end_turn_button.text == "Keep all" and not node._end_turn_button.disabled, "the discard step offers Keep all and Back")
	key(node, KEY_BACKSPACE)
	check(c.phase == Combat.Phase.PLAYER_TURN and not node._cancel_button.visible and node._end_turn_button.text == "End Turn", "Backspace goes back to playing cards")
	key(node, KEY_E)
	key(node, KEY_E)
	check(c.turn == turn + 1 or c.phase == Combat.Phase.ENDED, "E, E ends turn")
	for i in 10:
		key(node, KEY_1)
	check(c.energy >= 0, "no negative energy after rapid presses")
	if c.phase == Combat.Phase.PLAYER_TURN:
		for e in c.enemies:
			e.take_damage(9999)
		c._check_end()
	check(c.phase == Combat.Phase.ENDED, "ended")
	check(node._new_fight_button.visible, "new fight visible")
	var t: int = c.turn
	key(node, KEY_1)
	key(node, KEY_E)
	key(node, KEY_RIGHT)
	key(node, KEY_ENTER)
	check(c.turn == t and c.phase == Combat.Phase.ENDED, "keys no-op after end")
	node._on_end_turn_pressed()
	node._play_hand_card(0)
	node._select_target(0)
	check(true, "handlers no error after end")
	key(node, KEY_N)
	check(node._combat != c and node._combat.phase == Combat.Phase.PLAYER_TURN and not node._new_fight_button.visible, "N new fight")
	var c2: Combat = node._combat
	# Clicking a card view plays it, like the old buttons did; an unplayable one does nothing.
	var click_views := CardView.find_all(node._hand_box)
	var clicked := -1
	for i in click_views.size():
		if c2.can_play(i):
			clicked = i
			break
	check(clicked >= 0, "the new fight has a playable card")
	var discard_before := c2.piles.discard_pile.size()
	click_views[clicked].pressed.emit()
	check(c2.piles.discard_pile.size() == discard_before + 1, "clicking a card view plays it")
	c2.energy = 0
	node._refresh()
	var dimmed := CardView.find_all(node._hand_box)
	var any_costly := false
	for i in dimmed.size():
		if c2.piles.hand[i].cost > 0:
			any_costly = true
			check(dimmed[i].state == CardView.State.UNPLAYABLE and dimmed[i].note == "NEED %d ENERGY" % c2.piles.hand[i].cost and not dimmed[i].is_clickable(), "a card that costs too much shows how much energy it needs")
	check(any_costly or dimmed.is_empty(), "setup: the hand has a card that costs energy")
	_check_preview_matches_damage(node, c2)
	# Hover survives a hand rebuild: the card under the pointer is raised again, no other one is.
	c2.energy = Combat.ENERGY_PER_TURN
	c2.piles.hand.clear()
	for id in ["bash", "cold_steel", "last_pocket"]:
		c2.piles.hand.append(load("res://data/cards/%s.tres" % id))
	node._refresh()
	await process_frame
	var hv := CardView.find_all(node._hand_box)
	check(hv.size() >= 2, "setup: a hand of two or more for the hover checks")
	var over := hv[1].get_global_rect().get_center()
	hv[1].set_hovered(true)
	node._refresh() # rebuilds every view, all un-hovered
	await process_frame
	var nv := CardView.find_all(node._hand_box)
	check(nv[1] != hv[1] and not nv[1]._hovered, "a rebuilt card starts un-hovered")
	node._restore_hover(over)
	var hovered_count := 0
	for v in nv:
		hovered_count += 1 if v._hovered else 0
	check(nv[1]._hovered and hovered_count == 1, "after a rebuild only the card under the pointer is hovered")
	check(nv[1].hotkey == 2 and nv[1].preview == node._damage_preview(c2.piles.hand[1]).strip_edges(), "restoring hover keeps the hotkey badge and damage preview")
	node._restore_hover(Vector2(-500.0, -500.0))
	hovered_count = 0
	for v in nv:
		hovered_count += 1 if v._hovered else 0
	check(hovered_count == 0, "no card stays hovered when the pointer is elsewhere")
	node._restore_hover(nv[0].get_global_rect().get_center())
	check(nv[0]._hovered and not nv[1]._hovered, "hover moves to the card now under the pointer")
	# An end-turn (enemy phase) emits many state_changed signals but renders once.
	c2.player.hp = c2.player.max_hp
	var emitted := [0]
	c2.state_changed.connect(func() -> void: emitted[0] += 1)
	node._on_end_turn_pressed() # opens the discard step
	var refreshes_before: int = node.refresh_count
	node._on_end_turn_pressed() # confirms it
	var refreshes: int = node.refresh_count - refreshes_before
	check(emitted[0] > 1, "setup: the enemy phase emits several state changes (%d)" % emitted[0])
	check(refreshes == 1, "an end turn refreshes the screen once, not per mutation (%d refreshes for %d changes)" % [refreshes, emitted[0]])
	check(node._energy_orb.text == "%d/%d" % [c2.energy, Combat.ENERGY_PER_TURN], "the screen shows the final state after the end turn")
	c2.phase = Combat.Phase.ENEMY_TURN
	var h :=c2.piles.hand.size()
	key(node, KEY_1)
	key(node, KEY_E)
	check(c2.piles.hand.size() == h, "enemy phase ignored")
	await _check_discard_ui(node)
	_check_preview(node)
	_check_drag(node)
	await _check_keywords(node)
	await _check_statuses(node)
	await _check_choice_overlay(node)
	await _check_pile_viewer(node)
	await _check_add_cue(node)
	await _check_forgotten_damage(node)
	print("DONE fails=", fails)
	quit(1 if fails > 0 else 0)
