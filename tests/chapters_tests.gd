extends "res://tests/test_base.gd"
## Chapter data (docs/CHAPTERS_DESIGN.md): Chapter 1 carries exactly the values that used to be constants.


func run() -> int:
	_failures = 0
	var c := Chapters.chapter(1)
	_check(c.number == 1 and c.title == "Chapter 1", "chapter 1 is numbered and titled")
	_check(c.district_names.size() == RouteMap.ACTS and c.budget_start.size() == RouteMap.ACTS and c.budget_end.size() == RouteMap.ACTS, "one name and one budget pair per district")
	_check(c.district_names == RouteMap.DISTRICT_NAMES, "the map's district names come from the chapter")
	_check(c.mid_boss == &"the_brakeman" and c.end_boss == &"the_conductor", "chapter 1 bosses are the Bellkeeper and the Eraser")
	_check(Chapters.chapter(0) == c and Chapters.chapter(99) == Chapters.chapter(Chapters.MAX_BUILT), "an out-of-range chapter is clamped")
	_check(c.enemy_paths == StarterContent.ALL_ENEMY_PATHS and c.big_paths == StarterContent.PAIR_BIG_ENEMY_PATHS and c.small_paths == StarterContent.SMALL_ENEMY_PATHS, "chapter 1's pools are the registry's")
	_check(c.trio_paths() == Encounters.trio_paths(), "chapter 1's trio pool is the registry's")
	_check(c.mid_boss_path == StarterContent.BRAKEMAN_PATH and c.end_boss_path == StarterContent.CONDUCTOR_PATH, "chapter 1's boss paths")
	# Pack building: chapter 1 is the default and unchanged; a later chapter draws from its own pools and budget.
	for row in [0, 7, 14, 15, 22, 29]:
		for count in [1, 2, 3]:
			var a := RandomNumberGenerator.new()
			a.seed = row * 10 + count
			var b := RandomNumberGenerator.new()
			b.seed = row * 10 + count
			var default_pack := StarterContent.budget_encounter(count, a, row)
			var explicit_pack := StarterContent.budget_encounter(count, b, row, 1.0, false, 1)
			var same := default_pack.size() == explicit_pack.size()
			for i in mini(default_pack.size(), explicit_pack.size()):
				same = same and default_pack[i].id == explicit_pack[i].id and default_pack[i].max_hp == explicit_pack[i].max_hp
			_check(same, "chapter 1 is the default pack (row %d, %d enemies)" % [row, count])
	var later := Chapters.chapter(2)
	_check(later.number == 2 and later != c, "chapter 2 exists as a stub")
	_check(later.budget_start[0] > c.budget_end[1], "the stub's budget starts above where chapter 1 ends")
	_check(StarterContent.fight_budget(0, 2) > StarterContent.fight_budget(29, 1) and StarterContent.fight_budget(29, 2) > StarterContent.fight_budget(0, 2), "chapter 2's curve starts above chapter 1's end and rises")
	_check(StarterContent.fight_budget(0, 3) > StarterContent.fight_budget(29, 2), "chapter 3 starts above chapter 2's end")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var pack := StarterContent.budget_encounter(2, rng, 3, 1.0, false, 2)
	_check(not pack.is_empty() and absf(StarterContent.pack_threat(pack) - StarterContent.fight_budget(3, 2)) / StarterContent.fight_budget(3, 2) < 0.2, "a chapter 2 pack aims at chapter 2's budget")
	_check(StarterContent.boss_encounter(2).size() == 1 and StarterContent.mid_boss_encounter(2).size() == 1, "later chapters load their bosses")
	for row in RouteMap.ROWS:
		_check(is_equal_approx(StarterContent.fight_budget(row), StarterContent.fight_budget(row, 1)), "fight_budget defaults to chapter 1 (row %d)" % row)
	_test_chapter_2_content()
	return _failures


## Chapter 2's enemies and bosses (data only; docs/CHAPTER2_PLAN.md): registered, loadable, distinct from Chapter 1's, sane, and
## good enough for the pack builder to fill its budget.
func _test_chapter_2_content() -> void:
	var two := Chapters.chapter(2)
	_check(two.district_names.size() == RouteMap.ACTS and two.district_names[0] == "The Flooded Stacks" and two.district_names[1] == "The Reading Rooms", "chapter 2 has its district names")
	_check(two.mid_boss_title == "The Archivist" and two.end_boss_title == "The Registrar" and Chapters.chapter(1).mid_boss_title == "The Bellkeeper", "boss titles per chapter")
	_check(MapView.district_name(0, 2) == two.district_names[0] and MapView.district_name(0) == Chapters.chapter(1).district_names[0], "the map names the districts of its chapter")
	_check(StarterContent.CHAPTER2_ENEMY_PATHS.size() == 7 and StarterContent.CHAPTER2_BOSS_PATHS.size() == 2, "seven regular enemies and two bosses")
	var ids := {}
	var every: Array[String] = []
	every.append_array(StarterContent.CHAPTER2_ENEMY_PATHS)
	every.append_array(StarterContent.CHAPTER2_BOSS_PATHS)
	for path in every:
		var enemy := load(path) as EnemyData
		_check(enemy != null, "chapter 2 enemy loads: %s" % path)
		if enemy == null:
			continue
		_check(not ids.has(enemy.id) and path.get_file().trim_suffix(".tres") == String(enemy.id), "id is unique and is the file name: %s" % enemy.id)
		ids[enemy.id] = true
		_check(enemy.max_hp > 0 and not enemy.intents.is_empty() and enemy.display_name != "", "has HP, intents and a name: %s" % enemy.id)
		_check(Fighter.art_key_for(enemy.id) == &"ghost", "no art key yet, so it draws as the generic ghost (placeholder): %s" % enemy.id)
		_check(StarterContent.enemy_by_id(enemy.id) != null, "enemy_by_id finds it: %s" % enemy.id)
		_check(not Chapters.chapter(1).enemy_paths.has(path) and not StarterContent.ALL_ENEMY_PATHS.has(path), "Chapter 1 never draws it: %s" % enemy.id)
	for path in StarterContent.CHAPTER2_BOSS_PATHS:
		var boss := load(path) as EnemyData
		_check(boss != null and not boss.phase_two_intents.is_empty() and boss.phase_two_title != "", "a boss has a second phase and a banner: %s" % path)
	var misfiled := load(StarterContent.MISFILED_PATH) as EnemyData
	_check(misfiled != null and misfiled.unseen, "The Misfiled is Unseen")
	for path in every:
		var enemy := load(path) as EnemyData
		_check(enemy == null or enemy.id == &"the_misfiled" or not enemy.unseen, "only The Misfiled is Unseen")
	_check(two.mid_boss_path == StarterContent.ARCHIVIST_PATH and two.end_boss_path == StarterContent.REGISTRAR_PATH, "chapter 2's bosses")
	_check(StarterContent.boss_encounter(2)[0].id == &"the_registrar" and StarterContent.mid_boss_encounter(2)[0].id == &"the_archivist", "chapter 2 fights its own bosses")
	_check(StarterContent.boss_encounter(1)[0].id == &"the_conductor", "chapter 1 still fights the Eraser")
	# The pack builder fills chapter 2's budget over many rows and sizes, without falling back.
	var misses := 0
	var packs := 0
	for row in RouteMap.ROWS:
		for count in [1, 2, 3]:
			var rng := RandomNumberGenerator.new()
			rng.seed = row * 100 + count
			var pack := StarterContent.budget_encounter(count, rng, row, 1.0, false, 2)
			packs += 1
			var ok: bool = not pack.is_empty() and not StarterContent.last_pack_info["fallback"]
			for enemy in pack:
				ok = ok and not Chapters.chapter(1).enemy_paths.any(func(p: String) -> bool: return (load(p) as EnemyData).id == enemy.id)
			if not ok:
				misses += 1
	_check(misses == 0, "every chapter 2 pack (%d) is built from chapter 2's own enemies" % packs)
