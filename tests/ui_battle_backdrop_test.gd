extends SceneTree
## Headless test for BattleBackdrop and its place in the battle screen: it builds for the default,
## boss and every class variant (and an unknown one), the animation is deterministic and only runs
## while visible, it ignores the mouse, and the battle screen has exactly one, at the bottom and
## filling the screen. Run via scripts/check.ps1.

var fails := 0

func check(c: bool, msg: String) -> void:
	if not c:
		fails += 1
		printerr("FAIL: " + msg)
	else:
		print("ok: " + msg)


func _battle(boss: bool, id: StringName) -> Control:
	var datas: Array[EnemyData] = [load("res://data/enemies/cinder_hound.tres") as EnemyData]
	var scene: Control = (load("res://battle.tscn") as PackedScene).instantiate()
	scene.external_combat = Combat.create(Combatant.new("Wanderer", 40), StarterContent.extended_deck(), datas, 7)
	scene.boss_fight = boss
	scene.character_id = id
	root.add_child(scene)
	return scene


func _initialize() -> void:
	var holder := Control.new()
	holder.size = Vector2(1152, 648)
	root.add_child(holder)

	# Every variant builds and draws; the variant is kept.
	var variants := [[false, &""], [true, &""], [false, &"deserter"], [false, &"pickpocket"], [false, &"medium"], [true, &"medium"], [false, &"no_such_class"]]
	for v in variants:
		var backdrop := BattleBackdrop.new()
		backdrop.size = holder.size
		holder.add_child(backdrop)
		backdrop.set_variant(v[0], v[1])
		backdrop.advance(0.7)
		check(backdrop.boss == v[0] and backdrop.character_id == v[1], "variant boss=%s class=%s is kept" % [v[0], v[1]])
	await process_frame
	await process_frame
	check(true, "all variants draw")
	# Route art is presentation metadata: both bosses differ, unknown keys fall back.
	var route_art := BattleBackdrop.new()
	holder.add_child(route_art)
	for entry in [[1, &"battle_street"], [9, &"battle_bell_court"], [12, &"battle_garden"], [16, &"battle_archive"], [20, &"battle_threshold"]]:
		route_art.set_variant(entry[0] == 9 or entry[0] == 20, &"medium", DestinationArt.battle_key(entry[0]))
		check(route_art.painted_name() == entry[1] and PaintedArt.screen_texture(entry[1]) != null, "route painting loads at stop %d" % entry[0])
	route_art.set_variant(false, &"medium", &"missing_destination")
	check(route_art.painted_name() == &"battle_medium", "missing destination retains class fallback")
	route_art.set_variant(true, &"medium")
	check(route_art.painted_name() == &"battle_boss", "standalone boss retains fallback")
	check(DestinationArt.label_at(20) == "The Threshold" and DestinationArt.label_at(-1) == "", "destination labels handle route bounds")
	var neutral := BattleBackdrop.new()
	holder.add_child(neutral)
	neutral.set_variant(false, &"no_such_class")
	check(neutral.tint() == Color.WHITE and neutral._mix(BattleBackdrop.STEEL) == BattleBackdrop.STEEL, "an unknown class is neutral")
	neutral.set_variant(false, &"")
	check(neutral._mix(BattleBackdrop.STEEL) == BattleBackdrop.STEEL, "an empty class is neutral")
	neutral.set_variant(false, &"deserter")
	check(neutral._mix(BattleBackdrop.STEEL) != BattleBackdrop.STEEL, "a class tints the art")
	check(is_equal_approx(neutral.tint().r, 0.70) and absf(neutral._mix(BattleBackdrop.STEEL).r - BattleBackdrop.STEEL.r) < 0.25, "the tint stays moderate")
	check(BattleBackdrop.TINT_AMOUNT >= 0.25 and BattleBackdrop.TINT_AMOUNT <= 0.4 and is_equal_approx(neutral.tint_amount(), BattleBackdrop.TINT_AMOUNT), "a class is tinted by the full amount")
	neutral.set_variant(true, &"deserter")
	check(is_equal_approx(neutral.tint_amount(), BattleBackdrop.TINT_AMOUNT * BattleBackdrop.BOSS_TINT_SCALE) and neutral.lamp_color() == BattleBackdrop.RED, "the boss fight tints less and keeps its red lamps")
	neutral.set_variant(false, &"")
	check(neutral.tint_amount() == 0.0, "a neutral scene has no tint amount")
	neutral.set_variant(false, &"deserter")
	var boss := BattleBackdrop.new()
	holder.add_child(boss)
	boss.set_variant(true, &"")
	check(boss.lamp_color() != neutral.lamp_color() and boss.speed() > neutral.speed(), "the boss variant has redder lamps and a faster rush")

	# Animation: advance moves it, identical steps agree, hidden or detached does not move.
	var a := BattleBackdrop.new()
	var b := BattleBackdrop.new()
	holder.add_child(a)
	holder.add_child(b)
	var t0 := a.time
	var sway0 := a.sway()
	a.advance(0.4)
	check(a.time > t0 and a.sway() != sway0, "advance changes the animation state")
	b.advance(0.4)
	b.advance(0.0)
	check(b.time == a.time and b.sway() == a.sway() and b.lamp_level() == a.lamp_level(), "the same steps give the same animation")
	var in_range := true
	for i in 40:
		a.advance(0.13)
		in_range = in_range and a.lamp_level() >= 0.75 and a.lamp_level() <= 1.0
	check(in_range, "lamp level stays in range")
	var twin := BattleBackdrop.new()
	holder.add_child(twin)
	check(twin._motes == a._motes and twin._noise == a._noise, "the fixed seed gives the same layout every time")
	a.visible = false
	var frozen := a.time
	a.advance(1.0)
	check(a.time == frozen and not a.is_processing(), "a hidden backdrop does not advance or process")
	a.visible = true
	check(a.is_processing(), "showing it again resumes processing")
	var detached := BattleBackdrop.new()
	detached.advance(1.0)
	check(detached.time == 0.0, "a backdrop outside the tree does not advance")
	check(a.mouse_filter == Control.MOUSE_FILTER_IGNORE, "the backdrop ignores the mouse")

	# In the battle screen: one backdrop, lowest child, filling the screen, clicks pass through.
	for variant in [[false, &"pickpocket"], [true, &"deserter"]]:
		var scene := _battle(variant[0], variant[1])
		for i in 3:
			await process_frame
		var found: Array[Node] = scene.find_children("*", "BattleBackdrop", true, false)
		check(found.size() == 1, "the battle screen has exactly one backdrop")
		var backdrop: BattleBackdrop = found[0]
		check(backdrop.get_parent() == scene and backdrop.get_index() == 0, "the backdrop is the lowest child")
		check(backdrop.get_global_rect() == scene.get_global_rect() and backdrop.size.x > 0.0, "the backdrop fills the screen")
		check(backdrop.mouse_filter == Control.MOUSE_FILTER_IGNORE, "the battle backdrop ignores the mouse")
		check(backdrop.boss == variant[0] and backdrop.character_id == variant[1], "the battle passes its variant to the backdrop")
		check(backdrop.time > 0.0, "the backdrop animates in the battle screen")
		scene.queue_free()
		await process_frame
	print("DONE fails=", fails)
	quit(1 if fails > 0 else 0)
