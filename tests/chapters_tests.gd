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
	return _failures
