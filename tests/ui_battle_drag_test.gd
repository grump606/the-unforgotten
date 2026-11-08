extends "res://tests/ui_battle_support.gd"
## Headless UI test for dragging cards on battle.tscn: pickup, targeting, drop and cancel. Run via scripts/check.ps1.

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


func _initialize() -> void:
	var node: Control = await _make_battle()
	_check_drag(node)
	_finish()
