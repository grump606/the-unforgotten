extends "res://tests/test_base.gd"
## Chapters in a run (docs/CHAPTERS_DESIGN.md, steps 2): the break, the carry-over, and save format 6.


## A map run standing on the chapter's end boss, between stops, with the first road of every row visited.
func _run_at_end_boss(seed_value: int = 7) -> RunState:
	var run := RunState.new(seed_value, &"deserter", true)
	var path: Array[int] = []
	var id := -1
	for row in RouteMap.ROWS:
		id = run.route.starts()[0] if row == 0 else run.route.next_ids(id)[0]
		path.append(id)
	run.restore_map(run.route, id, path, false)
	return run


func run() -> int:
	_failures = 0
	Chapters.count_override = 2
	_test_break_and_next_chapter()
	_test_break_refused()
	_test_boss_reward()
	_test_save_versions()
	_test_save_validation()
	Chapters.count_override = 0
	_test_single_chapter_game()
	return _failures


func _test_break_and_next_chapter() -> void:
	var run := _run_at_end_boss()
	_check(run.can_enter_chapter_break() and run.chapter == 1, "the end boss of chapter 1 can open a break when a chapter 2 exists")
	_check(run.enter_chapter_break() and run.chapter_break, "the break opens")
	_check(not run.enter_chapter_break(), "it cannot open twice")
	var before_seed := run.route.seed_value
	run.player.hp = 10
	run.gold = 77
	var deck_size := run.deck.size()
	var max_hp := run.player.max_hp
	_check(run.start_next_chapter(), "the next chapter starts from the break")
	_check(run.chapter == 2 and not run.chapter_break, "chapter 2, break over")
	_check(run.player.hp == mini(max_hp, 10 + roundi(max_hp * RunState.CHAPTER_BREAK_HEAL_FRACTION)), "the break heals 0.75 of max HP, capped")
	_check(run.player.max_hp == max_hp and run.gold == 77 and run.deck.size() == deck_size, "max HP, gold and deck carry over")
	_check(run.current_node == -1 and run.visited.is_empty() and run.stop_index == 0, "the new chapter starts at its map's start")
	_check(run.route.seed_value == RunState.chapter_map_seed(before_seed, 2) and run.route.seed_value != before_seed, "a derived map seed")
	_check(run.route.validate().is_empty() and not run.reachable_nodes().is_empty(), "the new map is valid and has first choices")
	_check(not run.start_next_chapter(), "no second start outside a break")
	var again := _run_at_end_boss()
	again.enter_chapter_break()
	again.start_next_chapter()
	_check(again.route.to_dict() == run.route.to_dict(), "the same run seed gives the same chapter 2 map")


func _test_boss_reward() -> void:
	var run := _run_at_end_boss()
	run.restore_map(run.route, run.current_node, run.visited, true) # inside the boss's stop
	var gold := run.gold
	var relics := run.relics.size()
	_check(run.complete_combat(true), "the chapter's end boss can be won")
	_check(not run.finished and run.reward_pending() and run.boss_spoils_pending(), "a won end boss waits on its spoils, the run goes on")
	_check(run.gold == gold + RunState.END_BOSS_GOLD, "it pays END_BOSS_GOLD")
	var relic := run.boss_relic()
	_check(relic != null and relic.price >= RunState.BOSS_MIN_RELIC_PRICE, "the relic is a boss-grade one (price floor)")
	_check(run.reward_choices().is_empty(), "no card reward")
	_check(not run.elite_spoils_pending(), "not elite spoils")
	_check(run.take_boss_spoils() and run.relics.size() == relics + 1 and run.relics.has(relic), "taking the spoils grants the relic")
	_check(run.chapter_break and not run.reward_pending() and not run.finished and run.at_stop_boundary(), "then the break opens at a save point")
	_check(not run.take_boss_spoils(), "the spoils are taken once")
	_check(run.start_next_chapter() and run.chapter == 2, "and the next chapter starts")
	# The last chapter's boss still ends the run as before.
	Chapters.count_override = 0
	var last := _run_at_end_boss()
	last.restore_map(last.route, last.current_node, last.visited, true)
	_check(last.complete_combat(true) and last.finished and last.escaped and not last.boss_spoils_pending(), "the last chapter's boss ends the run as before")
	Chapters.count_override = 2
	# With every relic owned the spoils pay gold instead.
	var rich := _run_at_end_boss()
	rich.restore_map(rich.route, rich.current_node, rich.visited, true)
	for r in StarterContent.relic_pool(rich.character.id):
		if not rich.relics.has(r):
			rich.relics.append(r)
	rich.complete_combat(true)
	var before := rich.gold
	_check(rich.boss_relic() == null and rich.boss_spoils_fallback_gold() == RunState.END_BOSS_FALLBACK_GOLD, "no relic left: gold in its place")
	rich.take_boss_spoils()
	_check(rich.gold == before + RunState.END_BOSS_FALLBACK_GOLD and rich.chapter_break, "the fallback gold is paid")


func _test_break_refused() -> void:
	var run := RunState.new(7, &"deserter", true)
	_check(not run.can_enter_chapter_break() and not run.enter_chapter_break(), "no break at the start of a run")
	var line := RunState.new(7, &"deserter")
	_check(not line.enter_chapter_break() and not line.start_next_chapter(), "line runs have no chapters")
	Chapters.count_override = 0
	var last := _run_at_end_boss()
	_check(not last.can_enter_chapter_break(), "the last chapter's boss ends the run instead of opening a break")
	Chapters.count_override = 2


func _test_save_versions() -> void:
	var run := _run_at_end_boss()
	_check(int(RunSave.to_dict(run)["version"]) == RunSave.MAP_VERSION and not RunSave.to_dict(run).has("chapter"), "a chapter 1 run keeps writing v5")
	run.enter_chapter_break()
	var data := RunSave.to_dict(run)
	_check(int(data["version"]) == RunSave.CHAPTER_VERSION and data["chapter"] == 1 and data["chapter_break"] == true, "a break writes v6")
	var back := RunSave.from_dict(JSON.parse_string(JSON.stringify(data)))
	_check(back.error == "" and back.run.chapter == 1 and back.run.chapter_break, "the break save loads and is still a break")
	_check(back.run.start_next_chapter() and back.run.chapter == 2, "and can start chapter 2")
	var later := RunSave.to_dict(back.run)
	_check(int(later["version"]) == RunSave.CHAPTER_VERSION and later["chapter"] == 2 and later["chapter_break"] == false, "chapter 2 writes v6")
	var loaded := RunSave.from_dict(JSON.parse_string(JSON.stringify(later)))
	_check(loaded.error == "" and loaded.run.chapter == 2 and loaded.run.route.to_dict() == back.run.route.to_dict(), "a chapter 2 save round-trips")
	var v5 := RunState.new(7, &"deserter", true)
	v5.choose_node(v5.route.starts()[0])
	var old := RunSave.from_dict(JSON.parse_string(JSON.stringify(RunSave.to_dict(v5))))
	_check(old.error == "" and old.run.chapter == 1 and not old.run.chapter_break, "a v5 save loads as chapter 1")


func _test_save_validation() -> void:
	var run := _run_at_end_boss()
	run.enter_chapter_break()
	var data := RunSave.to_dict(run)
	for case in [["chapter", 0], ["chapter", 3], ["chapter", "2"], ["chapter_break", "yes"], ["version", 7]]:
		var bad := data.duplicate(true)
		bad[case[0]] = case[1]
		_check(RunSave.from_dict(JSON.parse_string(JSON.stringify(bad)))["error"] != "", "rejects %s = %s" % [case[0], str(case[1])])
	var no_chapter := data.duplicate(true)
	no_chapter.erase("chapter")
	_check(RunSave.from_dict(JSON.parse_string(JSON.stringify(no_chapter)))["error"] != "", "a v6 save needs its chapter")
	# A break only makes sense on the end boss with the chapter played.
	var elsewhere := RunSave.to_dict(_run_at_end_boss())
	elsewhere["version"] = RunSave.CHAPTER_VERSION
	elsewhere["chapter"] = 1
	elsewhere["chapter_break"] = true
	elsewhere["current_node"] = -1
	elsewhere["visited"] = []
	elsewhere["stop_index"] = 0
	_check(RunSave.from_dict(JSON.parse_string(JSON.stringify(elsewhere)))["error"] != "", "a break save that has not played the chapter is rejected")
	# A chapter 1 end-boss save without a break is still "past the last row" and unreadable, as before.
	var plain := RunSave.to_dict(_run_at_end_boss())
	_check(RunSave.from_dict(JSON.parse_string(JSON.stringify(plain)))["error"] != "", "an end-boss save with no break is still rejected")


func _test_single_chapter_game() -> void:
	var run := _run_at_end_boss()
	var data := RunSave.to_dict(run)
	data["version"] = RunSave.CHAPTER_VERSION
	data["chapter"] = 1
	data["chapter_break"] = true
	_check(RunSave.from_dict(JSON.parse_string(JSON.stringify(data)))["error"] != "", "with one chapter a break save is rejected")
