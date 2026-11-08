extends "res://tests/test_base.gd"
## RunSave's deck, gold and relic bounds follow the run's progress (RunSave.max_deck / max_gold /
## max_relics). They must accept every legitimate save: real runs played by the smart policy, for every
## character and two seeds each, are saved and loaded at every stop boundary, in three play styles that push
## each bound as far as a run can (an ordinary smart run, a run that takes and buys every card it can, and a
## run that skips every reward and never shops, hoarding gold). The player is topped up before each stop so
## the runs get deep instead of ending early.

const STYLE_SMART := 0
const STYLE_COLLECTOR := 1
const STYLE_HOARDER := 2
const STYLES := [STYLE_SMART, STYLE_COLLECTOR, STYLE_HOARDER]


## The furthest stop any style reached, so the test cannot pass by dying at the first fight.
var _deepest := {}


func run() -> int:
	_failures = 0
	_deepest.clear()
	_progress_bounds_grow()
	_bounds_reject_a_fresh_run_with_loot()
	for character_id in StarterContent.character_ids():
		for seed_value in 2:
			for style in STYLES:
				_check(_run_round_trips(character_id, seed_value, style), "a %s run (seed %d, style %d) saves and loads at every stop" % [character_id, seed_value, style])
	for style in STYLES:
		_check(_deepest.get(style, 0) >= 12, "style %d reaches act 2 in some run (deepest stop %d)" % [style, _deepest.get(style, 0)])
	return _failures


func _progress_bounds_grow() -> void:
	var run := RunState.new(1, &"stray")
	var none: Array[RelicData] = []
	var last_deck := 0
	var last_gold := -1
	for stop in run.stops.size():
		var deck := RunSave.max_deck(run, stop)
		var gold := RunSave.max_gold(run, stop, none)
		_check(deck >= last_deck and gold >= last_gold, "the bounds never shrink as the run progresses (stop %d)" % stop)
		last_deck = deck
		last_gold = gold
	_check(RunSave.max_deck(run, 0) < 20 and RunSave.max_gold(run, 0, none) < 100, "a fresh run's bounds are tight, not 200 cards or a million gold")
	_check(RunSave.max_relics(run, 0) == 0 and RunSave.max_relics(run, run.stops.size() - 1) > 0, "relics are allowed only after a vendor visit")


func _bounds_reject_a_fresh_run_with_loot() -> void:
	var state := RunState.new(5, &"thief")
	var data := RunSave.to_dict(state)
	data["gold"] = RunSave.max_gold(state, 0, [] as Array[RelicData]) + 1
	_check(RunSave.from_dict(data).run == null, "gold beyond what stop 0 could have earned is rejected")
	data = RunSave.to_dict(state)
	data["relics"] = [String(StarterContent.relic_pool(&"thief")[0].id)]
	_check(RunSave.from_dict(data).run == null, "a relic at stop 0 is rejected (no vendor visited)")


## One played run, round-tripped through JSON at every stop boundary. True when every save loaded.
func _run_round_trips(character_id: StringName, seed_value: int, style: int) -> bool:
	var run := RunState.new(seed_value, character_id)
	var guard := 0
	while not run.finished and guard < 60:
		guard += 1
		var loaded := RunSave.from_dict(JSON.parse_string(JSON.stringify(RunSave.to_dict(run))))
		if loaded.error != "":
			printerr("save bounds: %s seed %d style %d stop %d: %s" % [character_id, seed_value, style, run.stop_index, loaded.error])
			return false
		_deepest[style] = maxi(_deepest.get(style, 0), run.stop_index)
		if style != STYLE_SMART:
			run.player.hp = run.player.max_hp
		match run.current_stop().type:
			RunState.StopType.COMBAT:
				if not _fight(run, style):
					return false
			RunState.StopType.REST:
				SimPolicy.rest_stop(run, true)
			RunState.StopType.STORY:
				run.read_story()
			RunState.StopType.VENDOR:
				if not _shop(run, style):
					return false
	return true


func _fight(run: RunState, style: int) -> bool:
	var combat := run.start_combat()
	combat.start()
	while SimPolicy.is_acting(combat) and combat.turn < 50:
		if not SmartPolicy.play_turn(combat):
			return false
	var won := combat.phase == Combat.Phase.ENDED and not combat.player.is_dead()
	combat.abandon()
	run.complete_combat(won)
	if won and run.reward_pending():
		return _take_reward(run, style)
	return true


func _take_reward(run: RunState, style: int) -> bool:
	match style:
		STYLE_COLLECTOR:
			return run.resolve_reward(run.reward_choices()[0])
		STYLE_HOARDER:
			return run.resolve_reward(null)
	return SmartPolicy.take_reward(run)


func _shop(run: RunState, style: int) -> bool:
	match style:
		STYLE_COLLECTOR:
			# Buy everything affordable: the relic first, then every card, so deck and relics grow as fast as gold allows.
			SimPolicy.buy_relic(run)
			var vendor := run.vendor()
			for i in vendor.offers().size():
				if not vendor.offers()[i]["sold"] and vendor.offers()[i]["price"] <= run.gold:
					run.vendor_buy_card(i)
			return run.leave_vendor()
		STYLE_HOARDER:
			return run.leave_vendor()
	return SmartPolicy.shop(run)
