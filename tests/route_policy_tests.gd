extends RefCounted
## Route strategies for the bots (docs/MAP_DESIGN.md, "Phase 4e"): tools/route_policy.gd and the parallel
## sim harness (tools/run_sim.gd --jobs). Registered by run_tests.gd.

const CHARACTERS: Array[StringName] = [&"deserter", &"thief", &"medium", &"stray"]
const SEEDS := 6
const T := RouteMap.NodeType

var _failures := 0
var _checks := 0
## How often a fixture the checks need actually came up (a check that never fires would prove nothing).
var _seen := {}
## Per-choice checks registered by the _test_ functions and run by _walk_all.
var _handlers: Array[Callable] = []


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FAIL: " + label)


func run() -> int:
	_failures = 0
	_checks = 0
	_seen = {}
	_handlers = []
	_test_every_strategy_is_sound()
	_test_defaults_and_delegation()
	_test_fighter()
	_test_cautious()
	_test_mixed()
	_test_random()
	_walk_all()
	_after_walk()
	_test_whole_runs_finish()
	_test_wilson_and_merge()
	_test_shard_merge_equals_single_process()
	print("route_policy_tests: %d checks" % _checks)
	return _failures


# --- Helpers --------------------------------------------------------------------------------------------

## Passes the current stop the cheap way (no fight is played).
func _resolve(run_state: RunState) -> void:
	var stop := run_state.current_stop()
	match stop.type:
		RunState.StopType.COMBAT:
			run_state.complete_combat(true)
			if run_state.reward_pending():
				run_state.resolve_reward(null)
		RunState.StopType.REST:
			run_state.rest()
		RunState.StopType.STORY:
			run_state.read_story()
		RunState.StopType.VENDOR:
			run_state.leave_vendor()
		RunState.StopType.TREASURE:
			run_state.open_treasure()
			run_state.take_treasure()
		RunState.StopType.EVENT:
			SimPolicy.event_stop(run_state)


func _types(run_state: RunState, options: Array[int]) -> Array:
	var types: Array = []
	for id in options:
		types.append(run_state.route.node(id).type)
	return types


func _has_any(types: Array, wanted: Array) -> bool:
	for type in wanted:
		if types.has(type):
			return true
	return false


## Walks `SEEDS` maps per class with the `random` strategy and calls every registered handler as
## `handler(run, options)` at every choice (one walk for all of them: a walk costs about a second a map).
func _walk_all() -> void:
	for character in CHARACTERS:
		for seed_value in SEEDS:
			var run_state := RunState.new(seed_value * 31 + 7, character, true)
			var guard := 0
			while not run_state.finished and guard < 200:
				guard += 1
				if run_state.current_stop() != null:
					_resolve(run_state)
					continue
				var options := run_state.reachable_nodes()
				for handler in _handlers:
					handler.call(run_state, options)
				run_state.choose_node(RoutePolicy.choose(run_state, RoutePolicy.RANDOM))


func _note(key: String) -> void:
	_seen[key] = _seen.get(key, 0) + 1


## After the walk: every fixture the per-choice checks rely on came up, so none of them passed vacuously.
func _after_walk() -> void:
	_check(_seen.get("single", 0) > 10, "single-exit rows came up")
	_check(_seen.get("fighter_fight_over_other", 0) > 10, "fighter saw fight-versus-rest/shop/event choices")
	_check(_seen.get("fighter_forced", 0) > 0, "fighter met a forced rest")
	for key in ["cautious_rest_over_other", "cautious_shop_over_other", "cautious_event_over_fight", "cautious_small_fight", "mixed_rest_low"]:
		_check(_seen.get(key, 0) > 0, "fixture %s came up" % key)


# --- Tests ----------------------------------------------------------------------------------------------

func _test_every_strategy_is_sound() -> void:
	_handlers.append(func(run_state: RunState, options: Array[int]) -> void:
		for strategy in RoutePolicy.ROUTES:
			var pick := RoutePolicy.choose(run_state, strategy)
			_check(options.has(pick) and pick != -1, "%s picks a reachable node" % strategy)
			_check(RoutePolicy.choose(run_state, strategy) == pick, "%s is deterministic at a fixed position" % strategy)
		if options.size() == 1:
			_note("single")
			for strategy in RoutePolicy.ROUTES:
				_check(RoutePolicy.choose(run_state, strategy) == options[0], "%s takes the only node" % strategy)
	)
	# With a stop open and after the last row nothing is reachable, and every strategy answers -1.
	var run_state := RunState.new(5, &"thief", true)
	run_state.choose_node(run_state.route.starts()[0])
	for strategy in RoutePolicy.ROUTES:
		_check(RoutePolicy.choose(run_state, strategy) == -1, "%s: no pick while a stop is open" % strategy)
	var guard := 0
	while not run_state.finished and guard < 200:
		guard += 1
		if run_state.current_stop() != null:
			_resolve(run_state)
		else:
			run_state.choose_node(RoutePolicy.choose(run_state, RoutePolicy.FIRST))
	_check(run_state.finished, "the walk ended")
	for strategy in RoutePolicy.ROUTES:
		_check(RoutePolicy.choose(run_state, strategy) == -1, "%s: no pick after the last row" % strategy)
	_check(RoutePolicy.choose(RunState.new(5, &"thief", false), RoutePolicy.MIXED) == -1, "no pick in line mode")
	var fresh := RunState.new(5, &"thief", true)
	_check(fresh.route.starts().has(RoutePolicy.choose(fresh, "no_such_strategy")), "an unknown name acts like first")


func _test_defaults_and_delegation() -> void:
	_handlers.append(func(run_state: RunState, options: Array[int]) -> void:
		_check(SimPolicy.choose_route(run_state) == options[0], "greedy default route is the first node")
		_check(SmartPolicy.choose_route(run_state) == SmartPolicy.choose_route(run_state, RoutePolicy.SMART), "smart default route is the smart rules")
		for strategy in RoutePolicy.STRATEGIES:
			_check(SimPolicy.choose_route(run_state, strategy) == RoutePolicy.choose(run_state, strategy), "SimPolicy forwards %s" % strategy)
			_check(SmartPolicy.choose_route(run_state, strategy) == RoutePolicy.choose(run_state, strategy), "SmartPolicy forwards %s" % strategy)
		_check(SimPolicy.choose_route(run_state, RoutePolicy.SMART) == SmartPolicy.choose_route(run_state), "greedy can use the smart rules")
	)


func _test_fighter() -> void:
	_handlers.append(func(run_state: RunState, options: Array[int]) -> void:
		var types := _types(run_state, options)
		var picked := run_state.route.node(RoutePolicy.choose(run_state, RoutePolicy.FIGHTER)).type
		if types.has(T.FIGHT) or types.has(T.ELITE):
			_check(picked == T.FIGHT or picked == T.ELITE, "fighter takes a fight when one is reachable")
			if _has_any(types, [T.REST, T.SHOP, T.EVENT]):
				_note("fighter_fight_over_other")
		else:
			if types.has(T.TREASURE):
				_check(picked == T.TREASURE, "fighter takes a chest")
			if types.has(T.EVENT):
				_check(picked == T.EVENT or picked == T.TREASURE, "fighter takes an event when no fight is reachable")
		if picked == T.REST or picked == T.SHOP:
			_check(not _has_any(types, [T.FIGHT, T.ELITE, T.EVENT, T.TREASURE]), "fighter rests or shops only when forced")
			_note("fighter_forced")
	)


func _test_cautious() -> void:
	_handlers.append(func(run_state: RunState, options: Array[int]) -> void:
		var types := _types(run_state, options)
		var node := run_state.route.node(RoutePolicy.choose(run_state, RoutePolicy.CAUTIOUS))
		if types.has(T.TREASURE):
			_check(node.type == T.TREASURE, "cautious takes a chest")
		elif types.has(T.REST):
			_check(node.type == T.REST, "cautious prefers a rest")
			if _has_any(types, [T.FIGHT, T.SHOP, T.EVENT]):
				_note("cautious_rest_over_other")
		elif types.has(T.SHOP):
			_check(node.type == T.SHOP, "cautious prefers a shop to events and fights")
			if types.has(T.FIGHT) or types.has(T.EVENT):
				_note("cautious_shop_over_other")
		elif types.has(T.EVENT):
			_check(node.type == T.EVENT, "cautious prefers an event to a fight")
			if types.has(T.FIGHT):
				_note("cautious_event_over_fight")
		elif types.has(T.FIGHT):
			_check(node.type == T.FIGHT, "cautious fights before an elite")
			for id in options:
				var other := run_state.route.node(id)
				if other.type == T.FIGHT:
					_check(node.enemy_count <= other.enemy_count, "cautious takes the smallest fight")
					if other.enemy_count != node.enemy_count:
						_note("cautious_small_fight")
	)
	# An elite loses to everything: a synthetic choice (the generator places none yet).
	var run_state := _choice_run(3)
	var starts := run_state.reachable_nodes()
	_check(starts.size() > 1, "the walk reaches a choice")
	if starts.size() > 1:
		var elite := run_state.route.node(starts[0])
		var other := run_state.route.node(starts[1])
		elite.type = T.ELITE
		for extra in starts.slice(2):
			run_state.route.node(extra).type = T.ELITE
		other.type = T.FIGHT
		other.enemy_count = 3
		_check(RoutePolicy.choose(run_state, RoutePolicy.CAUTIOUS) == other.id, "cautious prefers a 3-enemy fight to an elite")
		_check(RoutePolicy.choose(run_state, RoutePolicy.FIGHTER) == elite.id, "fighter prefers an elite to a fight")
		other.type = T.REST
		_check(RoutePolicy.choose(run_state, RoutePolicy.CAUTIOUS) == other.id, "cautious prefers a rest to an elite")


## True when a rest can be reached within `depth` rows from any of `ids` (the look-ahead of the mixed route).
func _rest_ahead(run_state: RunState, ids: Array, depth: int) -> bool:
	if depth <= 0:
		return false
	for id: int in ids:
		for next_id in run_state.route.next_ids(id):
			if run_state.route.node(next_id).type == T.REST or _rest_ahead(run_state, [next_id], depth - 1):
				return true
	return false


func _test_mixed() -> void:
	_handlers.append(func(run_state: RunState, options: Array[int]) -> void:
		var types := _types(run_state, options)
		var max_hp := run_state.player.max_hp
		var hp := run_state.player.hp
		var gold := run_state.gold
		for state: Array in [[1, 0], [max_hp, 0], [max_hp, 500], [int(max_hp * 0.4), 40]]:
			run_state.player.hp = state[0]
			run_state.gold = state[1]
			var node := run_state.route.node(RoutePolicy.choose(run_state, RoutePolicy.MIXED))
			if types.has(T.TREASURE):
				_check(node.type == T.TREASURE, "mixed always takes a chest")
			if state[0] == 1 and types.has(T.REST):
				_check(node.type == T.REST, "mixed rests when badly hurt and a rest is offered (took %d of %s; row %d)" % [node.type, str(types), node.row])
				_note("mixed_rest_low")
			# (An event that leads to a rest within the look-ahead is a fair pick for a hurt player: only check maps where none does.)
			# (At 1 HP a fight would be lethal and an event never takes the last HP, so the event is the better pick there; the rule is for a hurt player who survives a fight.)
			if state[0] == int(max_hp * 0.4) and types.has(T.EVENT) and types.has(T.FIGHT) and not types.has(T.REST) and not _rest_ahead(run_state, options, 3):
				_check(node.type == T.FIGHT, "mixed skips an event while hurt")
				_note("mixed_skip_event")
		run_state.player.hp = hp
		run_state.gold = gold
	)
	# Small fights when hurt: a one-enemy fight beats a three-enemy one.
	var run_state := _choice_run(3)
	var starts := run_state.reachable_nodes()
	if starts.size() > 1:
		var heavy := run_state.route.node(starts[0])
		var light := run_state.route.node(starts[1])
		heavy.type = T.FIGHT
		heavy.enemy_count = 3
		light.type = T.FIGHT
		light.enemy_count = 1
		for extra in starts.slice(2):
			run_state.route.node(extra).type = T.FIGHT
			run_state.route.node(extra).enemy_count = 3
		run_state.player.hp = int(run_state.player.max_hp * 0.4)
		_check(RoutePolicy.choose(run_state, RoutePolicy.MIXED) == light.id, "mixed takes the smaller fight when hurt")
	# Controlled choices (the look-ahead sees nothing past the option, so only the node types decide).
	var types_hp_gold := [
		[[T.FIGHT, T.REST], 1.0, 0, T.FIGHT, "mixed fights rather than rests at full HP"],
		[[T.FIGHT, T.REST], 0.3, 0, T.REST, "mixed rests when hurt"],
		[[T.FIGHT, T.EVENT], 1.0, 0, T.EVENT, "mixed takes an event while healthy"],
		[[T.FIGHT, T.EVENT], 0.3, 0, T.FIGHT, "mixed skips an event while hurt"],
		[[T.FIGHT, T.SHOP], 1.0, 500, T.SHOP, "mixed shops when rich"],
		[[T.FIGHT, T.SHOP], 1.0, 20, T.FIGHT, "mixed skips a shop when poor"],
		[[T.FIGHT, T.TREASURE], 0.3, 0, T.TREASURE, "mixed takes a chest when hurt"],
		[[T.FIGHT, T.TREASURE], 1.0, 0, T.TREASURE, "mixed takes a chest when healthy"],
		[[T.REST, T.TREASURE], 0.3, 0, T.REST, "mixed rests before a chest when badly hurt"],
	]
	for fixture: Array in types_hp_gold:
		var staged := _choice_run(3)
		var ids := staged.reachable_nodes()
		for slot in ids.size():
			var node := staged.route.node(ids[slot])
			node.type = fixture[0][slot % 2]
			node.enemy_count = 2
			node.next.clear()
		staged.player.hp = int(staged.player.max_hp * fixture[1])
		staged.gold = fixture[2]
		_check(staged.route.node(RoutePolicy.choose(staged, RoutePolicy.MIXED)).type == fixture[3], fixture[4])


func _test_random() -> void:
	var routes: Array = []
	for attempt in 2:
		var run_state := RunState.new(77, &"medium", true)
		var path: Array[int] = []
		var guard := 0
		while not run_state.finished and guard < 200:
			guard += 1
			if run_state.current_stop() != null:
				_resolve(run_state)
			else:
				var pick := RoutePolicy.choose(run_state, RoutePolicy.RANDOM)
				path.append(pick)
				run_state.choose_node(pick)
		routes.append(path)
	_check(routes[0] == routes[1] and routes[0].size() == RouteMap.ROWS, "random reproduces a whole route for a fixed seed")
	# Over many maps the picks vary.
	var picked := {}
	for seed_value in 60:
		var run_state := _choice_run(seed_value)
		var options := run_state.reachable_nodes()
		picked[options.find(RoutePolicy.choose(run_state, RoutePolicy.RANDOM))] = true
	_check(picked.size() > 1, "random does not always take the same slot")
	# The strategy does not consume any random stream of the run.
	var a := RunState.new(9, &"deserter", true)
	var b := RunState.new(9, &"deserter", true)
	RoutePolicy.choose(a, RoutePolicy.RANDOM)
	RoutePolicy.choose(a, RoutePolicy.RANDOM)
	_check(a.rng_state() == b.rng_state(), "choosing a route leaves the run's RNG untouched")


func _test_whole_runs_finish() -> void:
	for strategy in RoutePolicy.ROUTES:
		for character in CHARACTERS:
			for seed_value in 1:
				var run_state := RunState.new(seed_value + 100, character, true)
				var guard := 0
				while not run_state.finished and guard < 500:
					guard += 1
					if run_state.current_stop() != null:
						_resolve(run_state)
						continue
					if not run_state.choose_node(RoutePolicy.choose(run_state, strategy)):
						break
				_check(run_state.finished and run_state.escaped, "%s finishes a %s run (seed %d)" % [strategy, character, seed_value])
				_check(run_state.visited.size() == RouteMap.ROWS, "%s visits one node per row" % strategy)


func _test_wilson_and_merge() -> void:
	var sim: GDScript = load("res://tools/run_sim.gd")
	var half: Array = sim.wilson_interval(50, 100)
	_check(absf(half[0] - 0.4038) < 0.001 and absf(half[1] - 0.5962) < 0.001, "Wilson interval of 50/100 is 40.4% to 59.6%")
	var none: Array = sim.wilson_interval(0, 40)
	_check(none[0] == 0.0 and none[1] > 0.05 and none[1] < 0.12, "Wilson interval of 0/40 starts at 0")
	var nothing: Array = sim.wilson_interval(3, 0)
	_check(nothing[0] == 0.0 and nothing[1] == 1.0, "Wilson interval of no trials is everything")
	var into := {"n": 2, "d": {"a": 1}, "arr": [1, 2], "s": "x"}
	sim.merge_tallies(into, {"n": 3, "d": {"a": 4, "b": 5}, "arr": [10, 20], "s": "x", "new": {"k": [1, 1]}})
	_check(into["n"] == 5 and into["d"] == {"a": 5, "b": 5} and into["arr"] == [11, 22] and into["s"] == "x" and into["new"]["k"] == [1, 1], "merge_tallies adds numbers, slots and nested keys")


## Output of one run_sim invocation without the engine banner and shutdown warnings.
func _sim_output(args: Array) -> String:
	var full := PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"), "-s", "res://tools/run_sim.gd", "--"])
	full.append_array(PackedStringArray(args))
	var output: Array = []
	OS.execute(OS.get_executable_path(), full, output, true)
	var lines: PackedStringArray = []
	for line in String(output[0] if not output.is_empty() else "").split("\n"):
		var text := line.strip_edges(false, true)
		if text.begins_with("Godot Engine") or text.begins_with("WARNING:") or text.begins_with("ERROR:") or text.begins_with("   at:"):
			continue
		lines.append(text)
	return "\n".join(lines).strip_edges()


func _test_shard_merge_equals_single_process() -> void:
	var cases: Array = [
		["--runs", "6", "--seed", "3", "--map", "--route", "mixed", "--character", "thief"],
		["--runs", "4", "--seed", "2", "--policy", "smart", "--character", "medium", "--card-stats"],
		["--runs", "2", "--seed", "5", "--map", "--route", "random", "--character", "all"],
		["--runs", "4", "--seed", "4", "--map", "--chapters", "2", "--character", "deserter"],
	]
	var jobs := [2, 3, 2, 2]
	for index in cases.size():
		var single := _sim_output(cases[index])
		var parallel := _sim_output(cases[index] + ["--jobs", str(jobs[index])])
		_check(single.begins_with("Run sim:") and single.contains("Escape rate"), "case %d: the single-process report is a report" % index)
		_check(single == parallel, "case %d: --jobs %d merges to the single-process report" % [index, jobs[index]])
	_check(_sim_output(["--map", "--runs", "2", "--route", "bogus"]).contains("--route must be one of"), "a bad route name is rejected")
	_check(_sim_output(["--runs", "2", "--route", "mixed"]).contains("--route needs --map"), "--route without --map is rejected")
	_check(_sim_output(["--runs", "2", "--chapters", "2"]).contains("--chapters needs --map"), "--chapters without --map is rejected")
	_check(_sim_output(["--map", "--runs", "2", "--chapters", "4"]).contains("--chapters must be 1 to 3"), "--chapters 4 is rejected")
	var two := _sim_output(["--runs", "6", "--seed", "4", "--map", "--chapters", "2"])
	_check(two.contains("Deaths by chapter: chapter 1") and two.contains("Runs that reached the break after: chapter 1"), "a two-chapter run reports deaths by chapter and the break")


## A map-mode run (class deserter) walked with `first` to the first choice of two or more nodes.
func _choice_run(seed_value: int) -> RunState:
	var run_state := RunState.new(seed_value, &"deserter", true)
	var guard := 0
	while not run_state.finished and guard < 50:
		guard += 1
		if run_state.current_stop() != null:
			_resolve(run_state)
		elif run_state.reachable_nodes().size() > 1:
			break
		else:
			run_state.choose_node(run_state.reachable_nodes()[0])
	return run_state
