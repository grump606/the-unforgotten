extends SceneTree
## Headless test for the boss presentation: the entrance overlay (shown for a boss fight, skippable, absent
## for a normal one), the larger boss figure with the wide HP bar, and the phase-two banner. Run via scripts/check.ps1.

var fails := 0

func check(c: bool, msg: String) -> void:
	if not c:
		fails += 1
		printerr("FAIL: " + msg)
	else:
		print("ok: " + msg)


func _boss_data() -> EnemyData:
	var hits: Array[CardEffect] = [CardEffect.make(CardEffect.Kind.DAMAGE, 5)]
	var data := EnemyData.make("The Test Boss", 100, hits, &"the_brakeman")
	var enraged: Array[CardEffect] = [CardEffect.make(CardEffect.Kind.DAMAGE, 9)]
	data.phase_two_intents = enraged
	data.phase_two_hp_percent = 50
	data.phase_two_title = "Tolling Louder"
	return data


func _battle(data: EnemyData, boss: bool, intro: bool) -> Control:
	var datas: Array[EnemyData] = [data]
	var scene: Control = (load("res://battle.tscn") as PackedScene).instantiate()
	scene.external_combat = Combat.create(Combatant.new("Wanderer", 40), StarterContent.extended_deck(), datas, 7)
	scene.boss_fight = boss
	scene.show_boss_intro = intro
	root.add_child(scene)
	return scene


func _key(node: Node, code: int) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	node._unhandled_key_input(e)


func _initialize() -> void:
	await process_frame
	Motion.reduced = false

	# Intro: shown for a boss fight, skipped by a key, never for a normal fight.
	var boss := _battle(_boss_data(), true, true)
	await process_frame
	check(boss.intro_visible(), "a boss fight starts with the entrance overlay")
	var intro: BossIntro = boss._fx.intro
	check(intro.label.text == "FINAL BOSS" and intro.name_label.text == "The Test Boss", "the plate shows the label and the boss name")
	_key(boss, KEY_SPACE)
	check(not boss.intro_visible(), "any key skips the intro")
	await process_frame
	check(boss._enemy_views[0].entrance == 1.0, "the boss sprite is at full scale after the intro")
	boss.queue_free()

	var mid := _battle(_boss_data(), true, true)
	mid.boss_label = "Mid-boss"
	await process_frame
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	mid._fx.intro._gui_input(click)
	check(not mid.intro_visible(), "a click skips the intro")
	mid.queue_free()

	var normal := _battle(_boss_data(), false, true)
	await process_frame
	check(not normal.intro_visible(), "a normal fight has no intro")
	var headless_default := _battle(_boss_data(), true, DisplayServer.get_name() != "headless")
	await process_frame
	check(not headless_default.intro_visible(), "the intro is off by default when running headless")
	headless_default.queue_free()

	# Scale and HUD: the boss figure is larger than the same enemy as a regular one, and the bar is wide.
	var regular: Fighter = normal._enemy_views[0]
	var big := Fighter.new()
	big.set_enemy(EnemyUnit.new(_boss_data()), true)
	var plain := Fighter.new()
	plain.set_enemy(EnemyUnit.new(_boss_data()), false)
	check(is_equal_approx(big.figure_height, plain.figure_height * Fighter.BOSS_SCALE), "a boss figure is BOSS_SCALE times a regular one")
	var boss2 := _battle(_boss_data(), true, false)
	await process_frame
	await process_frame
	var bview: Fighter = boss2._enemy_views[0]
	check(bview.is_boss and bview.figure_height > regular.figure_height, "the boss figure on stage is larger than a regular enemy")
	var bar: BossBar = boss2._boss_bar
	check(bar != null and bar.size.x > 300.0 and normal._boss_bar == null, "a boss fight has a wide HP bar and a normal one does not")
	check(bar.has_marker() and is_equal_approx(bar.marker_ratio(), 0.5), "the bar marks the phase threshold")

	# Phase change: banner with the title, shake, harsher backdrop, new intent shown.
	var unit: EnemyUnit = boss2._combat.enemies[0]
	check(not boss2.phase_banner_visible() and not boss2._backdrop.harsh, "no banner or harsh mood before phase two")
	unit.hp = 40
	unit.phase = 2
	boss2._combat.enemy_phase_changed.emit(unit, 2)
	check(boss2.phase_banner_visible() and boss2._fx.banner.text == "TOLLING LOUDER", "the phase banner shows the phase two title")
	check(bview.shake_amount() > 0.0 and boss2._backdrop.harsh, "the boss shakes and the backdrop turns harsh")
	check(unit.current_intent().amount == 9, "the new phase's intent is the current one")
	var data2 := _boss_data()
	data2.phase_two_title = ""
	var boss3 := _battle(data2, true, false)
	await process_frame
	boss3._combat.enemy_phase_changed.emit(boss3._combat.enemies[0], 2)
	check(boss3._fx.banner.text == "ENRAGED", "an empty title falls back to Enraged")

	# Reduced motion: no flash, a short intro.
	Motion.reduced = true
	var calm := _battle(_boss_data(), true, true)
	await process_frame
	calm._combat.enemy_phase_changed.emit(calm._combat.enemies[0], 2)
	check(calm._fx.flash == null and calm.intro_visible(), "reduced motion skips the flash but keeps the intro")
	Motion.reduced = false
	print("DONE fails=", fails)
	quit(1 if fails > 0 else 0)
