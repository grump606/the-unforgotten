extends SceneTree
## Headless test for the small correctness fixes of the fifth pass: the pile viewer scrolls back to the top on a
## tab change, a bare modifier key does not skip the boss entrance, the vendor scene's redraw accumulator keeps
## its remainder, and a fighter that went idle under Reduce motion wakes up when the setting is switched off at
## runtime (and settles again when it is switched on). Run via scripts/check.ps1.

var fails := 0


func check(c: bool, msg: String) -> void:
	if not c:
		fails += 1
		printerr("FAIL: " + msg)
	else:
		print("ok: " + msg)


func _key(node: Node, code: int) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	node._unhandled_key_input(e)


func _initialize() -> void:
	Motion.reduced = false
	var data := load("res://data/enemies/gate_warden.tres") as EnemyData
	var datas: Array[EnemyData] = [data]
	var scene: Control = (load("res://battle.tscn") as PackedScene).instantiate()
	scene.external_combat = Combat.create(Combatant.new("Wanderer", 40), StarterContent.extended_deck(), datas, 7)
	scene.boss_fight = true
	scene.show_boss_intro = true
	root.add_child(scene)
	await process_frame
	await process_frame

	var views: Array[Fighter] = scene.enemy_views()
	var count := views.size()
	views.clear()
	check(count > 0 and scene.enemy_views().size() == count, "enemy_views() hands out a copy of the list")

	# A bare modifier key is not "any key".
	check(scene.intro_visible(), "the boss entrance is up")
	for modifier in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]:
		_key(scene, modifier)
	check(scene.intro_visible(), "a bare Shift, Ctrl, Alt or Meta press leaves the entrance up")
	_key(scene, KEY_SPACE)
	check(not scene.intro_visible(), "a real key still skips it")

	# The pile viewer scrolls back to the top on a tab change but keeps the place on a refresh.
	var combat: Combat = scene.combat()
	var many: Array[CardData] = []
	for i in 80:
		many.append(combat.piles.draw_pile[0])
	combat.piles.discard_pile.assign(many)
	scene.open_pile_viewer(PileViewer.Pile.DISCARD)
	await process_frame
	await process_frame
	var viewer: PileViewer = scene.overlays().pile_viewer
	var scroll: ScrollContainer = viewer._scroll
	scroll.scroll_vertical = 120
	await process_frame
	check(scroll.scroll_vertical > 0, "the long Discard list scrolls (offset %d)" % scroll.scroll_vertical)
	viewer.refresh()
	check(scroll.scroll_vertical > 0, "a refresh keeps the scroll position")
	viewer.show_pile(PileViewer.Pile.DRAW)
	check(scroll.scroll_vertical == 0, "switching tab scrolls back to the top")
	scene.queue_free()
	await process_frame

	# The redraw throttle (vendor scene, backdrops) keeps the remainder of its interval.
	var throttle := RedrawThrottle.new()
	var step := 1.0 / RedrawThrottle.HZ
	check(not throttle.due(step * 0.6) and throttle.due(step * 0.6), "the throttle fires once the interval has built up")
	var fired := 0
	for i in 600:
		if throttle.due(1.0 / 144.0):
			fired += 1
	check(absi(fired - 125) <= 2, "at 144 fps it repaints about 30 times a second, no drift (%d of 600 frames)" % fired)
	var late := RedrawThrottle.new()
	check(late.due(1.0) and late.due(0.0) and not late.due(0.0), "a long frame catches up by at most one extra repaint")

	# A fighter that went idle under reduced motion follows the setting when it flips.
	Motion.reduced = true
	var fighter := Fighter.new()
	root.add_child(fighter)
	fighter.size = Vector2(200, 300)
	fighter.set_enemy(EnemyUnit.new(data))
	fighter.advance(0.1)
	check(not fighter.is_processing(), "under reduced motion the fighter stops processing")
	Motion.set_reduced(false)
	check(fighter.is_processing(), "switching Reduce motion off wakes the fighter")
	var t0 := fighter.time
	fighter.advance(0.5)
	check(fighter.time > t0, "and its breathing clock runs again")
	Motion.set_reduced(true)
	fighter.advance(0.1)
	check(not fighter.is_processing(), "switching it on lets the fighter settle again")
	Motion.reduced = false
	quit(1 if fails > 0 else 0)
