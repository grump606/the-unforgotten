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


func _initialize() -> void:
	var node: Control = (load("res://battle.tscn") as PackedScene).instantiate()
	root.add_child(node)
	await process_frame
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
	check(node._player_label.tooltip_text == "Takes 1.5x damage, rounded down, for 3 more turns.", "player tooltip: " + node._player_label.tooltip_text)
	var enemy_views := EnemyView.find_all(node._enemy_row)
	check(enemy_views.size() == 3 and enemy_views[0].tooltip_text.contains("2 more turns"), "enemy tooltip")
	check(enemy_views[1].tooltip_text == "", "no tooltip unexposed")
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
	var turn: int = c.turn
	key(node, KEY_E)
	check(c.turn == turn + 1 or c.phase == Combat.Phase.ENDED, "E ends turn")
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
	var refreshes_before: int = node.refresh_count
	node._on_end_turn_pressed()
	var refreshes: int = node.refresh_count - refreshes_before
	check(emitted[0] > 1, "setup: the enemy phase emits several state changes (%d)" % emitted[0])
	check(refreshes == 1, "an end turn refreshes the screen once, not per mutation (%d refreshes for %d changes)" % [refreshes, emitted[0]])
	check(node._energy_label.text == "Energy %d/%d" % [c2.energy, Combat.ENERGY_PER_TURN], "the screen shows the final state after the end turn")
	c2.phase = Combat.Phase.ENEMY_TURN
	var h :=c2.piles.hand.size()
	key(node, KEY_1)
	key(node, KEY_E)
	check(c2.piles.hand.size() == h, "enemy phase ignored")
	print("DONE fails=", fails)
	quit(1 if fails > 0 else 0)
