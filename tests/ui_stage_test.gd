extends SceneTree
## Headless test for the battle stage: a Fighter builds for every enemy and the player, its animation
## is deterministic and reacts to hits, targeting and defeat follow the fight, and 1 to 3 enemies stand
## on the right with the player on the left and the hand below. Run via scripts/check.ps1.

var fails := 0

func check(c: bool, msg: String) -> void:
	if not c:
		fails += 1
		printerr("FAIL: " + msg)
	else:
		print("ok: " + msg)


func _unit(path: String) -> EnemyUnit:
	return EnemyUnit.new(load(path) as EnemyData)


func _combat_of(paths: Array) -> Combat:
	var datas: Array[EnemyData] = []
	for path in paths:
		datas.append(load(path) as EnemyData)
	return Combat.create(Combatant.new("Wanderer", 40), StarterContent.extended_deck(), datas, 7)


func _battle(paths: Array) -> Control:
	var scene: Control = (load("res://battle.tscn") as PackedScene).instantiate()
	scene.external_combat = _combat_of(paths)
	root.add_child(scene)
	return scene


func _initialize() -> void:
	var holder := Control.new()
	root.add_child(holder)
	await process_frame
	await process_frame

	# Every enemy and every class builds a fighter with a sensible size.
	var all_paths: Array[String] = []
	for file in DirAccess.get_files_at("res://data/enemies"):
		if file.ends_with(".tres"):
			all_paths.append("res://data/enemies/" + file)
	for path in all_paths:
		var unit := _unit(path)
		var fighter := Fighter.new()
		holder.add_child(fighter)
		fighter.set_enemy(unit)
		check(fighter.art_key != &"ghost" and is_equal_approx(fighter.figure_height, Fighter.HEIGHTS[fighter.art_key] * Fighter.HEIGHT_SCALE), "%s has its own figure height" % unit.display_name)
		check(fighter.size.x >= Fighter.MIN_WIDTH and fighter.size.y == Fighter.OVERHEAD + fighter.figure_height + Fighter.UNDER, "%s fighter size" % unit.display_name)
		check(fighter.facing < 0.0 and fighter.figure_rect().size.x > 20.0, "%s faces the player" % unit.display_name)
		fighter.queue_free()
	for id in [&"deserter", &"pickpocket", &"medium", &""]:
		var f := Fighter.new()
		holder.add_child(f)
		f.set_player(Combatant.new("Wanderer", 40), id)
		check(f.facing > 0.0 and f.figure_rect().size.x > 20.0, "player %s faces right" % id)
		f.queue_free()

	# Animation: deterministic, only while visible, reacts to damage, block and healing.
	var enemy := _unit("res://data/enemies/gate_warden.tres")
	var a := Fighter.new()
	var b := Fighter.new()
	holder.add_child(a)
	holder.add_child(b)
	a.set_enemy(enemy)
	b.set_enemy(enemy)
	a.phase = 0.7
	b.phase = 0.7
	for i in 10:
		a.advance(0.1)
		b.advance(0.1)
	check(is_equal_approx(a.breath(), b.breath()) and a.time > 0.99, "the idle animation is deterministic")
	a.hide()
	var t := a.time
	a.advance(1.0)
	check(a.time == t, "a hidden fighter does not animate")
	a.show()
	var hp := enemy.hp
	enemy.take_damage(5)
	a.refresh()
	check(a.float_count() == 1 and a._flash > 0.9 and a._recoil > 0.9, "a hit flashes, recoils and floats its damage")
	a.advance(Fighter.FLOAT_TIME + 0.1)
	check(a.float_count() == 0, "floating numbers expire")
	enemy.gain_block(6)
	a.refresh()
	check(a._pop > 0.9, "gaining Block pops the shield")
	enemy.take_damage(4)
	a.refresh()
	check(a.float_count() == 1 and enemy.hp == hp - 5, "a hit soaked by Block floats 'Blocked' and costs no HP")
	a.play_attack(0.5)
	a.advance(0.3)
	check(a.lunge_amount() == 0.0, "a delayed lunge waits for its turn")
	a.advance(0.4)
	check(a.lunge_amount() > 0.0, "then the lunge starts")
	for i in 20:
		a.advance(0.1)
	check(a.lunge_amount() == 0.0, "and the fighter settles back")
	enemy.take_damage(9999)
	a.refresh()
	for i in 20:
		a.advance(0.1)
	check(a.is_defeated() and a.fade == 1.0, "a defeated fighter fades out")
	var clicked := [0]
	a.pressed.connect(func() -> void: clicked[0] += 1)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = Vector2(5, 5)
	a._gui_input(release)
	check(clicked[0] == 0, "a defeated fighter cannot be clicked")
	var live := Fighter.new()
	holder.add_child(live)
	live.set_enemy(_unit("res://data/enemies/lost_shade.tres"))
	live._gui_input(release)
	check(clicked[0] == 0 and live.size.x > 0.0, "setup: a live fighter exists")
	live.pressed.connect(func() -> void: clicked[0] += 1)
	live._gui_input(release)
	check(clicked[0] == 1, "a live enemy fighter can be clicked")
	live.set_player(Combatant.new("Wanderer", 40), &"deserter")
	live._gui_input(release)
	check(clicked[0] == 1, "the player cannot be clicked")

	# Status pills sit under the HP bar, inside the control, without overlapping.
	var chip_unit := _unit("res://data/enemies/gate_warden.tres")
	var chipped := Fighter.new()
	holder.add_child(chipped)
	chipped.set_enemy(chip_unit)
	for count in 5:
		chip_unit.hold = 0
		chip_unit.thorns = 0
		chip_unit.clear_statuses()
		if count >= 1:
			chip_unit.apply_status(Combatant.Status.EXPOSED, 2)
		if count >= 2:
			chip_unit.apply_status(Combatant.Status.HAUNTED, 3)
		if count >= 3:
			chip_unit.hold = 4
		if count >= 4:
			chip_unit.thorns = 12
		var rects := chipped.chip_rects()
		var ok := rects.size() == count and chipped.status_chips().size() == count
		for i in rects.size():
			ok = ok and rects[i].position.y >= chipped.bar_rect().end.y and Rect2(Vector2.ZERO, chipped.size).encloses(rects[i])
			for j in i:
				ok = ok and not rects[i].intersects(rects[j])
		check(ok, "%d status pill(s): under the HP bar, inside the fighter, not overlapping" % count)

	# In the battle screen: the marker follows the target, the dead are skipped, clicks select.
	var trio: Array[String] = ["res://data/enemies/skittering_wisp.tres", "res://data/enemies/pale_whisperer.tres", "res://data/enemies/mourning_crow.tres"]
	var battle := _battle(trio)
	await process_frame
	await process_frame
	var views: Array[Fighter] = battle._enemy_views
	check(views.size() == 3 and battle._player_view != null, "one fighter per enemy and one for the player")
	for i in views.size():
		check(views[i].unit == battle._combat.enemies[i], "fighter %d shows its enemy" % i)
	check(views[0].targeted and not views[1].targeted and not views[2].targeted, "the first enemy starts targeted")
	battle._select_target(2)
	check(views[2].targeted and not views[0].targeted, "targeted follows _select_target")
	views[1].pressed.emit()
	check(battle._target_index == 1 and views[1].targeted and not views[2].targeted, "clicking a fighter targets that enemy")
	battle._combat.enemies[1].apply_status(Combatant.Status.EXPOSED, 2)
	battle._refresh()
	check(views[1].tooltip_text.contains("2 more turns") and views[1].tooltip_text.contains("Next: ") and not views[0].tooltip_text.contains("more turns"), "the tooltip shows the next move and statuses")
	check(battle._enemy_views[1] == views[1], "a refresh keeps the same fighters")
	battle._combat.enemies[1].take_damage(9999)
	battle._refresh()
	check(views[1].is_defeated() and not views[1].targeted and views[1].tooltip_text == "", "a defeated enemy is shown defeated, not targeted")
	check(battle._target_index != 1 and views[battle._target_index].targeted, "the target moved to a living enemy")
	var target_before: int = battle._target_index
	views[1].pressed.emit()
	check(battle._target_index == target_before, "a defeated fighter cannot be selected")
	battle.queue_free()
	await process_frame

	# Layout at the project's 1152x648: the player left, 1 to 3 enemies right of the middle, all on one
	# ground line above the hand, nothing off screen.
	var enemies_by_count := [
		["res://data/enemies/the_conductor.tres"],
		["res://data/enemies/gate_warden.tres", "res://data/enemies/lost_shade.tres"],
		trio,
		["res://data/enemies/the_brakeman.tres"],
	]
	for paths in enemies_by_count:
		var scene := _battle(paths)
		for i in 3:
			await process_frame
		var stage: Control = scene._stage
		var player: Fighter = scene._player_view
		var shown: Array[Fighter] = scene._enemy_views
		var n: int = paths.size()
		var screen := Rect2(Vector2.ZERO, Vector2(scene.size))
		var stage_rect := stage.get_global_rect()
		var ok: bool = shown.size() == n and stage_rect.encloses(player.get_global_rect())
		var ground := player.get_global_rect().end.y
		var prev_right := player.get_global_rect().end.x
		for v in shown:
			var r := v.get_global_rect()
			ok = ok and stage_rect.encloses(r) and is_equal_approx(r.end.y, ground) and r.position.x >= prev_right
			prev_right = r.end.x
		check(ok, "%d enemies: the player stands left, enemies right of them, one ground line, all inside the stage" % n)
		var hand_rect: Rect2 = scene._hand_box.get_global_rect()
		var hand_views := CardView.find_all(scene._hand_box)
		check(not hand_views.is_empty() and stage_rect.end.y <= hand_rect.position.y + 1.0, "%d enemies: the stage sits above the hand" % n)
		var all_on_screen := true
		for card in hand_views:
			all_on_screen = all_on_screen and screen.encloses(card.get_global_rect())
		check(all_on_screen and screen.encloses(scene._end_turn_button.get_global_rect()) and screen.encloses(scene._energy_orb.get_global_rect()), "%d enemies: the hand, End Turn and energy fit on screen" % n)
		scene.queue_free()
		await process_frame

	# Attacks: a played damage card lunges the player; the enemy phase lunges enemies one after another.
	var duel := _battle(["res://data/enemies/gate_warden.tres", "res://data/enemies/lost_shade.tres"])
	for i in 3:
		await process_frame
	var combat: Combat = duel._combat
	var player_view: Fighter = duel._player_view
	for i in combat.piles.hand.size():
		var card := combat.piles.hand[i]
		if combat.can_play(i) and card.effects.any(func(e: CardEffect) -> bool: return e.is_damage()):
			duel._play_hand_card(i)
			break
	check(player_view.lunge_amount() >= 0.0 and player_view._lunge > 0.9, "playing an attack lunges the player")
	duel._on_end_turn_pressed()
	var delays: Array[float] = []
	for v in duel._enemy_views:
		delays.append(v._lunge_delay)
	check(duel._enemy_views[0]._lunge > 0.0 or duel._enemy_views[1]._lunge > 0.0, "the enemy phase lunges the attackers")
	var staggered := false
	for i in delays.size():
		for j in i:
			staggered = staggered or not is_equal_approx(delays[i], delays[j])
	check(staggered or delays.filter(func(d: float) -> bool: return d > 0.0).is_empty() or delays.size() < 2, "enemy attacks are staggered")
	duel.queue_free()
	await process_frame

	print("DONE fails=", fails)
	quit(1 if fails > 0 else 0)
