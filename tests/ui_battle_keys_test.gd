extends "res://tests/ui_battle_support.gd"
## Headless UI test for the number keys (top row and keypad, 0 as the tenth card, the colon key does nothing) and
## for the screen's hold on its Combat: a replaced or removed screen leaves no signal connection behind.
## Run via scripts/check.ps1.


func _initialize() -> void:
	# The key table on its own.
	for n in 9:
		check(BattleKeys.card_index(KEY_1 + n) == n and BattleKeys.card_index(KEY_KP_1 + n) == n, "digit %d and keypad %d play card %d" % [n + 1, n + 1, n + 1])
	check(BattleKeys.card_index(KEY_0) == 9 and BattleKeys.card_index(KEY_KP_0) == 9, "0 and keypad 0 are the tenth card")
	check(BattleKeys.card_index(KEY_COLON) == -1 and BattleKeys.card_index(KEY_SEMICOLON) == -1, "the colon and semicolon keys play nothing")
	check(BattleKeys.card_index(KEY_A) == -1 and BattleKeys.card_index(KEY_KP_ADD) == -1, "other keys play nothing")

	var node: Control = await _make_battle()
	var c: Combat = await _fresh_fight(node)
	var hand: Array[CardData] = []
	for i in 10:
		hand.append(_card("brace"))
	c.piles.hand.assign(hand)
	node._refresh()
	await process_frame
	var played := c.plays_this_turn
	key(node, KEY_COLON)
	key(node, KEY_SEMICOLON, true)
	check(c.plays_this_turn == played and c.piles.hand.size() == 10, "Shift+; and the colon key do not play card 10")
	key(node, KEY_KP_1)
	check(c.plays_this_turn == played + 1 and c.piles.hand.size() == 9, "keypad 1 plays a card")
	key(node, KEY_KP_9)
	check(c.plays_this_turn == played + 2 and c.piles.hand.size() == 8, "keypad 9 plays a card")
	var before := c.piles.hand.size()
	key(node, KEY_0)
	check(c.piles.hand.size() == before, "0 with fewer than ten cards in hand plays nothing")

	# A replaced fight is disconnected from the screen; so is one whose screen leaves the tree.
	var old: Combat = node._combat
	node._start_combat()
	check(not old.state_changed.is_connected(node._on_state_changed) and not old.combat_ended.is_connected(node._on_combat_ended), "a replaced fight no longer reaches the screen")
	check(not old.card_played.is_connected(node._on_card_played) and not old.enemy_acted.is_connected(node._on_enemy_acted) and not old.enemy_phase_changed.is_connected(node._on_enemy_phase_changed), "no card or enemy signal is left connected either")
	var current: Combat = node._combat
	check(current.state_changed.is_connected(node._on_state_changed), "the new fight is connected")
	root.remove_child(node)
	check(not current.state_changed.is_connected(node._on_state_changed) and current.state_changed.get_connections().is_empty(), "a screen that leaves the tree leaves nothing behind")
	node.queue_free()
	_finish()
