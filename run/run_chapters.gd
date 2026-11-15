class_name RunChapters
extends RefCounted
## The chapter transitions of a map RunState: the break after an end boss, the finale and the start of the next chapter.
## Static helpers that take the run, so RunState keeps the public API and the chapter flags.
## Of RunState's internals it uses the per-stop state a transition clears: `_map_stop`, `_reward_pending`, `_spoils` and
## `_reset_event()`.


## Takes the boss relic (or the fallback gold) and opens the chapter break (see RunState.take_boss_spoils).
static func take_boss_spoils(run: RunState) -> bool:
	if not run.boss_spoils_pending():
		return false
	var spoils := run._spoils
	if spoils.boss_relic != null:
		run.grant_relic(spoils.boss_relic)
	else:
		run.gold += RunState.END_BOSS_FALLBACK_GOLD
	spoils.boss_pending = false
	spoils.boss_relic = null
	run._reward_pending = false
	run._map_stop = null
	if run.chapter < Chapters.count() or Chapters.has_finale():
		run.chapter_break = true # (after the last chapter of a complete game the break leads to the finale)
	else:
		# The last chapter that exists: the journey stops here for now.
		run.finished = true
		run.escaped = false
		run.to_be_continued = true
	return true


## Heals the player CHAPTER_BREAK_HEAL_FRACTION of max HP (the break's rest).
static func _break_heal(run: RunState) -> void:
	run.player.hp = mini(run.player.max_hp, run.player.hp + roundi(run.player.max_hp * RunState.CHAPTER_BREAK_HEAL_FRACTION))


## See RunState.start_finale.
static func start_finale(run: RunState) -> bool:
	if not run.can_start_finale():
		return false
	_break_heal(run)
	run.chapter_break = false
	run.finale = true
	run._map_stop = finale_stop(run)
	return true


## The finale's stop: a boss combat on the chapter's finale backdrop, on the same row as the end boss it follows.
static func finale_stop(run: RunState) -> RunState.Stop:
	var stop := RunState.Stop.new(RunState.StopType.COMBAT, 1, 0, true)
	stop.finale = true
	stop.row = RouteMap.ROWS - 1
	stop.node_id = run.current_node
	stop.backdrop = Chapters.chapter(run.chapter).finale_backdrop
	return stop


## See RunState.start_next_chapter.
static func start_next_chapter(run: RunState) -> bool:
	if not run.chapter_break or run.route == null or run.chapter >= Chapters.count():
		return false
	_break_heal(run)
	run.chapter += 1
	run.chapter_break = false
	run.route = RouteMap.generate(RunState.chapter_map_seed(run.route.seed_value, run.chapter), run.character.id, {}, run.chapter)
	run.current_node = -1
	run.visited.clear()
	run.stop_index = 0
	run._map_stop = null
	run.reward_remove_used = false
	run.reward_heal_used = false
	run.map_win_heal = 0
	run.elite_bonus_gold = 0
	run._spoils.reset_treasure()
	run._reset_event()
	return true
