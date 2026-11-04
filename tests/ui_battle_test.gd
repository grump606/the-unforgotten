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
	# The card played above may have drawn extra cards (Second Wind, Steady Breath), leaving more than
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
	print("DONE fails=", fails)
	quit(1 if fails > 0 else 0)
