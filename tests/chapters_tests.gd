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
	_test_events_and_story_by_chapter()
	_test_pools_by_chapter()
	_test_chapter_2_art_and_maps()
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
		_check(Fighter.art_key_for(enemy.id) == enemy.id and Fighter.HEIGHTS.has(enemy.id) and PaintedArt.enemy_figure(enemy.id).has("tex"), "it has an art key, a height and a painted sprite: %s" % enemy.id)
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


## Events and story beats are chosen by chapter; a chapter without its own plays Chapter 1's.
func _test_events_and_story_by_chapter() -> void:
	var first := StarterContent.EVENT_PATHS[0]
	var second := StarterContent.EVENT_PATHS[1]
	_check(StarterContent.events_for(1).size() == StarterContent.EVENT_PATHS.size() and StarterContent.events_for(4).size() == StarterContent.EVENT_PATHS.size(), "a chapter with no events of its own draws Chapter 1's")
	_check(StarterContent.events_for(2).size() == StarterContent.CHAPTER_EVENT_PATHS[2].size() and StarterContent.every_event().size() == StarterContent.EVENT_PATHS.size() + StarterContent.CHAPTER_EVENT_PATHS[2].size() + StarterContent.CHAPTER_EVENT_PATHS[3].size(), "chapter 2 draws its own events, and every_event is the union")
	ContentRegistry.chapter_event_paths_override = {2: [first, second]}
	ContentRegistry.clear_cache()
	var own := StarterContent.events_for(2)
	_check(own.size() == 2 and own[0].id == load(first).id, "chapter 2 draws only its own events when it has a list")
	_check(StarterContent.events_for(1).size() == StarterContent.EVENT_PATHS.size() and StarterContent.events_for(3).size() == StarterContent.EVENT_PATHS.size(), "other chapters are unaffected")
	_check(StarterContent.every_event().size() == StarterContent.EVENT_PATHS.size() + 2 or StarterContent.every_event().size() >= StarterContent.EVENT_PATHS.size(), "every_event still holds Chapter 1's")
	var run_state := RunState.new(3, &"deserter", true)
	run_state.chapter = 2
	var event_node := -1
	for id in run_state.route.node_count():
		if run_state.route.node(id).type == RouteMap.NodeType.EVENT:
			event_node = id
			break
	if event_node != -1:
		run_state.restore_map(run_state.route, event_node, [] as Array[int], true)
		run_state.chapter = 2
		var picked := run_state.current_event()
		_check(picked != null and (picked.id == load(first).id or picked.id == load(second).id), "a chapter 2 event stop draws from chapter 2's list")
	ContentRegistry.chapter_event_paths_override = {}
	ContentRegistry.clear_cache()
	_check(StoryContent.paths_for(1) == StoryContent.BEAT_PATHS and StoryContent.paths_for(4) == StoryContent.BEAT_PATHS and StoryContent.beat_count(4) == StoryContent.beat_count(1), "a chapter without its own beats plays Chapter 1's")
	_check(StoryContent.beat(0, &"deserter", 4) != null and StoryContent.beat(0, &"", 4).title == StoryContent.beat(0, &"", 1).title, "and reads the same beat")
	_check(StoryContent.paths_for(2) != StoryContent.BEAT_PATHS and StoryContent.beat_count(2) == RouteMap.STORY_LOCAL_ROWS[0].size() + RouteMap.STORY_LOCAL_ROWS[1].size(), "chapter 2 has a beat for each of its map's story rows")


## A card or relic with from_chapter 2 is offered from Chapter 2 on and never before; everything else is unchanged.
func _test_pools_by_chapter() -> void:
	var before_cards := StarterContent.reward_pool(&"deserter", 1).size()
	var before_vendor := StarterContent.vendor_pool(&"deserter", 1).size()
	var before_relics := StarterContent.relic_pool(&"deserter", 1).size()
	var all_cards := StarterContent.reward_pool(&"deserter").size()
	var all_relics := StarterContent.relic_pool(&"deserter").size()
	_check(all_cards == StarterContent.reward_pool(&"deserter", 3).size() and all_relics == StarterContent.relic_pool(&"deserter", 3).size(), "chapter 3 offers everything there is")
	_check(StarterContent.reward_pool(&"deserter", 2).size() == all_cards - 6 and StarterContent.relic_pool(&"deserter", 2).size() == all_relics - 4, "chapter 3 adds six deserter cards and four relics (three neutral, one class) to what chapter 2 offers")
	_check(before_cards == all_cards - 12 and before_relics == all_relics - 8, "chapters 2 and 3 add twelve deserter cards and eight relics to what chapter 1 offers")
	for card in StarterContent.reward_pool(&"deserter", 1):
		_check(card.from_chapter == 1, "chapter 1 never offers a chapter 2 card: %s" % card.id)
	for relic in StarterContent.relic_pool(&"deserter", 1):
		_check(relic.from_chapter == 1, "chapter 1 never offers a chapter 2 relic: %s" % relic.id)
	# Tagging an old card or relic as chapter 2 removes it from chapter 1's pools and only there.
	var card: CardData = StarterContent.reward_pool(&"deserter", 1)[0]
	var relic: RelicData = StarterContent.relic_pool(&"deserter", 1)[0]
	card.from_chapter = 2
	relic.from_chapter = 2
	ContentRegistry.clear_cache()
	_check(StarterContent.reward_pool(&"deserter", 1).size() == before_cards - 1 and not StarterContent.reward_pool(&"deserter", 1).has(card), "a chapter 2 card is not rewarded in chapter 1")
	_check(StarterContent.vendor_pool(&"deserter", 1).size() == before_vendor - 1 and StarterContent.relic_pool(&"deserter", 1).size() == before_relics - 1, "nor sold, nor is a chapter 2 relic")
	_check(StarterContent.reward_pool(&"deserter", 2).size() == all_cards - 6 and StarterContent.relic_pool(&"deserter", 2).size() == all_relics - 4, "chapter 2 offers old and new")
	_check(StarterContent.reward_pool(&"deserter").has(card) and StarterContent.vendor_pool(&"deserter").has(card), "the unrestricted pool (a save's deck check) has every card")
	var run_state := RunState.new(1, &"deserter", true)
	_check(not run_state._unowned_relics().has(relic), "a chapter 1 run does not roll a chapter 2 relic")
	run_state.chapter = 2
	_check(run_state._unowned_relics().has(relic), "a chapter 2 run does")
	card.from_chapter = 1
	relic.from_chapter = 1
	ContentRegistry.clear_cache()
	_check(StarterContent.reward_pool(&"deserter", 1).size() == before_cards, "restored")


## Chapter 2's paintings exist and its maps use them; Chapter 1's maps (and saves of them) are untouched.
func _test_chapter_2_art_and_maps() -> void:
	var two := Chapters.chapter(2)
	var keys: Array[StringName] = []
	keys.append_array(two.shared_backdrops)
	keys.append(two.mid_boss_backdrop)
	keys.append(two.boss_backdrop)
	for mood in two.story_moods:
		keys.append(StringName("story_" + String(mood)))
	for key in keys:
		_check(ResourceLoader.exists(PaintedArt.SCREEN_DIR % key), "the painting exists: %s" % key)
	_check(two.story_moods.size() == StoryContent.beat_count(2) and StoryScene.key_for_beat(2, 2) == &"story_reading_room" and StoryScene.key_for_beat(2, 1) == &"story_platform", "story beats pick their chapter's window painting")
	var map := RouteMap.generate(21, &"stray", {}, 2)
	_check(map.chapter == 2 and map.validate().is_empty(), "a chapter 2 map is valid")
	var pool := RouteMap.backdrop_pool(&"stray", 2)
	var boss_ok := true
	var mid_ok := true
	var fights_ok := true
	for n in map.nodes:
		if n.type == RouteMap.NodeType.BOSS:
			boss_ok = n.backdrop == two.boss_backdrop
		elif n.type == RouteMap.NodeType.MID_BOSS:
			mid_ok = n.backdrop == two.mid_boss_backdrop
		elif n.type == RouteMap.NodeType.FIGHT or n.type == RouteMap.NodeType.ELITE:
			fights_ok = fights_ok and pool.has(n.backdrop) and two.shared_backdrops.size() == 4
	_check(boss_ok and mid_ok and fights_ok, "its bosses and fights use chapter 2's backdrops")
	var back := RouteMap.from_dict(map.to_dict())
	_check(back != null and back.chapter == 2 and back.validate().is_empty() and back.to_dict() == map.to_dict(), "a chapter 2 map round-trips with its chapter")
	var first := RouteMap.generate(21, &"stray")
	_check(not first.to_dict().has("chapter") and first.chapter == 1 and RouteMap.from_dict(first.to_dict()).chapter == 1, "a chapter 1 map is written exactly as before")
	_check(first.to_dict() == RouteMap.generate(21, &"stray", {}, 1).to_dict(), "and generating it with an explicit chapter 1 changes nothing")
	for seed_value in 30:
		_check(RouteMap.generate(seed_value, &"deserter", {}, 2).validate().is_empty(), "chapter 2 map seed %d is valid" % seed_value)
