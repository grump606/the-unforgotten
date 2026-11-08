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
	var viewer: PileViewer = scene._overlays.pile_viewer
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

	# The vendor scene keeps the remainder of its redraw interval.
	var vendor := VendorScene.new()
	vendor.size = Vector2(1120, 590)
	root.add_child(vendor)
	await process_frame
	vendor._redraw_accum = 0.0
	vendor.advance(0.05)
	check(is_equal_approx(vendor._redraw_accum, 0.05 - 1.0 / VendorScene.ANIMATION_HZ), "a redraw subtracts the interval instead of zeroing the accumulator")
	vendor._redraw_accum = 0.0
	vendor.advance(1.0)
	check(vendor._redraw_accum <= 1.0 / VendorScene.ANIMATION_HZ, "a long frame catches up by at most one interval")
	vendor.queue_free()

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
