extends RefCounted
## Route map phase 3 (docs/MAP_DESIGN.md): saving and restoring map runs, in RunSave format 5. Round trips
## at every kind of place on the map, determinism after resuming, the line formats (v2 to v4) unchanged,
## and every validation of a tampered map block. Files go to a scratch path under user://. Registered by
## run_tests.gd; returns the failure count.

const CHARACTERS: Array[StringName] = [&"deserter", &"thief", &"medium", &"stray"]

## A v4 save written by the release before map saves (a Deserter at its 13th line stop, a fight, with a
## Remembered card and a relic), to prove line saves still load, and serialise back, exactly as they did.
const V4_FIXTURE := '{"character":"deserter","deck":["shove+","shove+","shove+","slip_past","slip_past","glimpse_exit","shoulder_charge","iron_resolve","hold_the_line","bash","shield_bash","taunt","steady_breath","catch_breath","bulwark_vow"],"gold":479,"hp":45,"line":"2:0:0:0:0:0,0:1:0:0:0:0,0:2:0:0:0:0,1:0:0:0:0:0,0:2:0:0:0:0,3:0:0:0:0:0,0:2:0:0:0:0,2:0:1:0:0:0,1:0:0:0:0:0,0:1:0:0:1:0,2:0:2:0:0:1,1:0:0:0:0:1,0:2:0:0:0:1,0:3:0:0:0:1,3:0:0:0:0:1,1:0:0:0:0:1,0:2:0:0:0:1,0:3:0:0:0:1,3:0:0:0:0:1,2:0:3:0:0:1,0:1:0:1:0:1","max_hp":52,"offered":["shield_bash","cold_steel","shake_them","taunt","cleave","lucky_break","steady_breath","iron_resolve","counter_step","catch_breath","standing_guard","sweep","bulwark_vow","shoulder_charge","hold_fast"],"relics":["ticket_stub_charm"],"reward_heal_used":false,"reward_remove_used":false,"rng_state":"3280759149698690558","stop_index":12,"version":4}'

var test_path := "user://run_save_map_test_%d.json" % OS.get_process_id()

var _failures := 0
var _checks := 0


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FAIL: " + label)


func run() -> int:
	_failures = 0
	_checks = 0
	_test_format_rules()
	_test_round_trip_every_place()
	_test_files_and_recovery()
	_test_determinism_after_resume()
	_test_line_saves_unchanged()
	_test_version_gate()
	_test_tampered_map_block()
	_test_tampered_position()
	_test_v5_shape()
	_test_corrupted_never_crashes()
	_test_cannot_rechoose()
	_cleanup()
	print("run_save_map_tests: %d checks" % _checks)
	return _failures


# --- Helpers --------------------------------------------------------------------------------------------

func _cleanup() -> void:
	RunSave.delete(test_path)


## Everything a resumed run must have equal: the dict the save writes (route, position, player, deck, relics,
## reward flags, RNG), plus what the dict does not spell out.
func _snapshot(run_state: RunState) -> Dictionary:
	return {
		"dict": JSON.stringify(RunSave.to_dict(run_state)),
		"reachable": run_state.reachable_nodes(),
		"stop_index": run_state.stop_index,
		"current": run_state.current_node,
		"visited": run_state.visited.duplicate(),
		"in_stop": run_state.in_map_stop(),
		"stop_type": -1 if run_state.current_stop() == null else int(run_state.current_stop().type),
		"label": run_state.destination_label(),
		"backdrop": run_state.battle_backdrop(),
		"hp": run_state.player.hp, "max_hp": run_state.player.max_hp, "gold": run_state.gold,
		"deck": run_state.deck.size(), "relics": run_state.relics.size(), "rng": run_state.rng_state(),
		"boundary": run_state.at_stop_boundary(),
	}


## A save and load through JSON text, as a real file does. Null when the load fails.
func _clone(run_state: RunState) -> RunState:
	var json := JSON.new()
	if json.parse(JSON.stringify(RunSave.to_dict(run_state))) != OK:
		return null
	return RunSave.from_dict(json.data).run


## Does the next thing at a map run: resolves the open stop, or picks a node (the `step`-th rotation through the
## choices, so runs wander over the whole map). Returns a log of what was random.
func _advance(run_state: RunState, step: int) -> Array:
	var log: Array = []
	var stop := run_state.current_stop()
	if stop == null:
		var options := run_state.reachable_nodes()
		var pick: int = options[step % options.size()]
		run_state.choose_node(pick)
		log.append(["chose", pick])
		return log
	match stop.type:
		RunState.StopType.COMBAT:
			var combat := run_state.start_combat()
			combat.start()
			var names: Array = []
			for enemy in combat.enemies:
				names.append(enemy.display_name)
			var hand: Array = []
			for card in combat.piles.hand:
				hand.append(String(card.id))
			log.append([names, hand])
			combat.abandon()
			run_state.complete_combat(true)
			if run_state.reward_pending():
				var ids: Array = []
				for card in run_state.reward_choices():
					ids.append(String(card.id))
				log.append(ids)
				run_state.resolve_reward(run_state.reward_choices()[0])
		RunState.StopType.VENDOR:
			var offers: Array = []
			for offer in run_state.vendor().offers():
				offers.append([String(offer["card"].id), offer["price"]])
			log.append(offers)
			run_state.vendor_buy_card(0)
			run_state.leave_vendor()
		RunState.StopType.REST:
			var spots := run_state.rememberable_indices()
			if step % 2 == 0 and not spots.is_empty():
				run_state.remember(spots[0])
			else:
				run_state.rest()
		_:
			run_state.read_story()
	return log


## A run `steps` actions in (each choice of a node and each resolved stop is one action).
func _run_at(seed_value: int, character: StringName, steps: int) -> RunState:
	var run_state := RunState.new(seed_value, character, true)
	for step in steps:
		if run_state.finished:
			break
		_advance(run_state, step)
	return run_state


func _dict_at(steps: int, seed_value := 11, character: StringName = &"deserter") -> Dictionary:
	return RunSave.to_dict(_run_at(seed_value, character, steps))


func _json_copy(data: Dictionary) -> Dictionary:
	var json := JSON.new()
	json.parse(JSON.stringify(data))
	return json.data


## Loads a dict through JSON, as a file does.
func _load(data: Dictionary) -> RunSave.Result:
	return RunSave.from_dict(_json_copy(data))


func _rejects(data: Dictionary, label: String, expected := "") -> void:
	var result := _load(data)
	var ok := result.run == null and result.error != ""
	if expected != "":
		ok = ok and result.error.contains(expected)
	_check(ok, "%s is rejected (%s)" % [label, result.error])


# --- Tests ----------------------------------------------------------------------------------------------

func _test_format_rules() -> void:
	_check(RunSave.VERSION == 5 and RunSave.MIN_VERSION == 2, "the format reads 2 to 5")
	var line := RunSave.to_dict(RunState.new(3))
	_check(line["version"] == 4 and not line.has("map") and not line.has("current_node"), "a line run still writes version 4 with no map fields")
	var map_run := RunState.new(3, &"deserter", true)
	var data := RunSave.to_dict(map_run)
	_check(data["version"] == 5 and data["map"] is Dictionary and data["current_node"] == -1 and data["visited"] == [] and data["at_node"] == false, "a map run writes version 5 with its route and position")
	_check(not data.has("line"), "a map save has no stop line")
	_check(data["map"] == map_run.route.to_dict(), "the route is stored whole, not as a seed")
	_cleanup()
	_check(RunSave.save(map_run, test_path) == "" and FileAccess.file_exists(test_path), "a map run at the first choice can be saved")
	_cleanup()
	# A reward in flight is not a boundary, for a map run as for a line run.
	var busy := RunState.new(3, &"deserter", true)
	var guard := 0
	while not busy.reward_pending() and guard < 40:
		guard += 1
		if busy.current_stop() == null:
			busy.choose_node(busy.reachable_nodes()[0])
		elif busy.current_stop().type == RunState.StopType.COMBAT:
			busy.complete_combat(true)
		else:
			_advance(busy, 0)
	_check(busy.reward_pending(), "setup: a map run with a reward pending")
	_check(RunSave.save(busy, test_path) != "" and not FileAccess.file_exists(test_path), "a map run with a reward in flight is not saved")
	_cleanup()


func _test_round_trip_every_place() -> void:
	var seen_types := {}
	var after_mid_boss := false
	var at_last_row := false
	var before_last_row := false
	for character in CHARACTERS:
		var run_state := RunState.new(21, character, true)
		var step := 0
		while not run_state.finished and step < 300:
			if run_state.at_stop_boundary():
				var copy := _clone(run_state)
				_check(copy != null and copy.uses_map(), "%s step %d: the save loads" % [character, step])
				if copy == null:
					return
				_check(_snapshot(copy) == _snapshot(run_state), "%s step %d: equal state after load (row %d, %s)" % [character, step, run_state.stop_index, "in stop" if run_state.in_map_stop() else "at map"])
				_check(copy.route.to_dict() == run_state.route.to_dict() and copy.visited == run_state.visited and copy.reachable_nodes() == run_state.reachable_nodes(), "%s step %d: route, visited and choices equal" % [character, step])
				_check(copy.deck == run_state.deck and copy.relics == run_state.relics, "%s step %d: deck and relics equal" % [character, step])
				if run_state.in_map_stop():
					seen_types[run_state.route.node(run_state.current_node).type] = true
					at_last_row = at_last_row or run_state.stop_index == RouteMap.ROWS - 1
				else:
					var mid_row := RouteMap.ACT_ROWS - 1
					after_mid_boss = after_mid_boss or (run_state.current_node >= 0 and run_state.stop_index == mid_row and run_state.route.node(run_state.current_node).type == RouteMap.NodeType.MID_BOSS)
					before_last_row = before_last_row or run_state.stop_index == RouteMap.ROWS - 2
			_advance(run_state, step)
			step += 1
		_check(run_state.finished, "%s: the walk reached the end" % character)
	for type in [RouteMap.NodeType.FIGHT, RouteMap.NodeType.REST, RouteMap.NodeType.SHOP, RouteMap.NodeType.STORY, RouteMap.NodeType.MID_BOSS, RouteMap.NodeType.BOSS]:
		_check(seen_types.has(type), "a save was round-tripped inside a node of type %d" % type)
	_check(after_mid_boss, "a save was round-tripped at the map right after the mid-boss")
	_check(at_last_row, "a save was round-tripped inside the final row")
	_check(before_last_row, "a save was round-tripped at the map before the final row")


func _test_files_and_recovery() -> void:
	_cleanup()
	var run_state := _run_at(5, &"medium", 7)
	_check(RunSave.save(run_state, test_path) == "", "a map run saves to a file")
	var loaded := RunSave.load_file(test_path)
	_check(loaded.run != null and _snapshot(loaded.run) == _snapshot(run_state), "the file loads back to the same state")
	_advance(run_state, 7)
	_check(RunSave.save(run_state, test_path) == "" and FileAccess.file_exists(test_path + ".bak"), "the next save keeps the previous as .bak")
	var bak := RunSave.load_file(test_path + ".bak")
	_check(bak.run != null and bak.run.uses_map(), "the .bak of a map run loads as a map run")
	var file := FileAccess.open(test_path, FileAccess.WRITE)
	file.store_string("{\"version\": 5, \"map\": ")
	file.close()
	var recovered := RunSave.load_file(test_path)
	_check(recovered.run != null and recovered.recovered_from == test_path + ".bak", "a damaged map save falls back to the .bak")
	_check(RunSave.delete(test_path) == "" and not FileAccess.file_exists(test_path) and not FileAccess.file_exists(test_path + ".bak"), "delete removes a map save and its backup")


func _test_determinism_after_resume() -> void:
	for character in [&"deserter", &"stray"]:
		var plain := RunState.new(77, character, true)
		var plain_log: Array = []
		var resumed := RunState.new(77, character, true)
		var resumed_log: Array = []
		var step := 0
		while not plain.finished and step < 300:
			plain_log.append(_advance(plain, step))
			# The resumed run is reloaded from its save before every action, wherever it is.
			resumed = _clone(resumed)
			resumed_log.append(_advance(resumed, step))
			step += 1
		_check(plain_log == resumed_log and plain.finished and resumed.finished, "%s: a run saved and reloaded before every action sees the same encounters, rewards and stock" % character)
		_check(plain.escaped == resumed.escaped and plain.visited == resumed.visited and plain.gold == resumed.gold and plain.deck == resumed.deck and plain.rng_state() == resumed.rng_state(), "%s: the same end state" % character)


func _test_line_saves_unchanged() -> void:
	var fixture := JSON.new()
	_check(fixture.parse(V4_FIXTURE) == OK, "the v4 fixture parses")
	var result := RunSave.from_dict(fixture.data)
	_check(result.run != null and not result.run.uses_map() and result.run.stop_index == 12, "a v4 save loads as a line run, as before")
	if result.run != null:
		_check(result.run.player.hp == 45 and result.run.gold == 479 and result.run.relics.size() == 1 and result.run.deck.size() == 15, "its HP, gold, relic and deck are restored")
		var again := JSON.new()
		again.parse(JSON.stringify(RunSave.to_dict(result.run)))
		_check(again.data == fixture.data, "a loaded v4 save serialises back to exactly the same dict")
		_check(result.run.current_stop().type == RunState.StopType.COMBAT and result.run.route == null and result.run.visited.is_empty(), "it stands at its line stop with no map")
	# A v4 save with stray map keys (nothing writes them) is still a plain line run.
	var extra: Dictionary = fixture.data.duplicate()
	extra["map"] = {"nodes": 5}
	extra["current_node"] = 3
	var extra_result := RunSave.from_dict(extra)
	_check(extra_result.run != null and not extra_result.run.uses_map(), "map keys in a v4 save are ignored")
	# v2 and v3 saves go through the same migration as before.
	for old_version in [2, 3]:
		var old: Dictionary = fixture.data.duplicate()
		old["version"] = old_version
		var plain_deck: Array = []
		for id in old["deck"]:
			plain_deck.append(String(id).trim_suffix("+"))
		old["deck"] = plain_deck
		if old_version == 2:
			for key in ["offered", "relics", "reward_remove_used", "reward_heal_used"]:
				old.erase(key)
		var old_result := RunSave.from_dict(old)
		_check(old_result.run != null and not old_result.run.uses_map() and old_result.run.stop_index == 12, "a v%d save still loads as a line run" % old_version)
		if old_result.run != null:
			_check(int(RunSave.to_dict(old_result.run)["version"]) == 4, "and is written back as v4")
	# The first version too old to read is still too old.
	var v1: Dictionary = fixture.data.duplicate()
	v1["version"] = 1
	_check(RunSave.from_dict(v1).run == null, "version 1 is still rejected")
	# A line save written now has exactly the keys the previous release wrote.
	var line := RunSave.to_dict(RunState.new(7))
	var old_keys := ["character", "deck", "gold", "hp", "line", "max_hp", "offered", "relics", "reward_heal_used", "reward_remove_used", "rng_state", "stop_index", "version"]
	var keys := line.keys()
	keys.sort()
	_check(keys == old_keys, "a line save has exactly the keys it had before")


func _test_version_gate() -> void:
	var data := _dict_at(4)
	var newer := _json_copy(data)
	newer["version"] = RunSave.VERSION + 1
	var result := RunSave.from_dict(newer)
	_check(result.run == null and result.error.contains("newer version") and result.error.contains("save format 6") and result.error.contains("up to 5"), "a save above the newest format says so accurately: %s" % result.error)
	_cleanup()
	var file := FileAccess.open(test_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(newer))
	file.close()
	var loaded := RunSave.load_file(test_path)
	_check(loaded.run == null and not loaded.missing and loaded.error.contains("newer"), "a newer map save file is reported, not treated as missing")
	_cleanup()
	for bad in ["5", 5.5, null, -1, [], {}]:
		var weird := _json_copy(data)
		weird["version"] = bad
		_check(RunSave.from_dict(weird).run == null, "a version of %s is rejected" % str(bad))


func _test_v5_shape() -> void:
	var data := _dict_at(4)
	var no_map := _json_copy(data)
	no_map.erase("map")
	_rejects(no_map, "a v5 save with no map", "no route map")
	var line_v5 := RunSave.to_dict(RunState.new(3))
	line_v5["version"] = 5
	_rejects(line_v5, "a line run labelled v5")
	var map_as_v4 := _json_copy(data)
	map_as_v4["version"] = 4
	map_as_v4["line"] = RunSave.line_signature(RunState.new(0))
	map_as_v4["stop_index"] = 0
	var as_line := RunSave.from_dict(map_as_v4)
	_check(as_line.run != null and not as_line.run.uses_map(), "a map block under version 4 is not read as a map (v4 never had one)")
	for key in ["current_node", "visited", "at_node"]:
		var missing := _json_copy(data)
		missing.erase(key)
		_rejects(missing, "a save without %s" % key)
	_check(_load(data).run != null, "the unmodified save used by these cases loads")


func _test_tampered_map_block() -> void:
	var data := _dict_at(6)
	_check(_load(data).run != null, "setup: the base map save loads")
	for bad_map in ["text", 5, [], null, {}, {"nodes": 5}, {"nodes": []}, {"nodes": [5]}, {"nodes": [{}]}]:
		var d := _json_copy(data)
		d["map"] = bad_map
		_rejects(d, "a map block of %s" % str(bad_map).left(30))
	var line_kind := _json_copy(data)
	line_kind["map"]["kind"] = "line"
	_rejects(line_kind, "a map of kind line", "journey")
	var bogus_kind := _json_copy(data)
	bogus_kind["map"]["kind"] = "bogus"
	_rejects(bogus_kind, "a map of an unknown kind", "damaged")
	var huge := _json_copy(data)
	var filler: Array = huge["map"]["nodes"]
	for i in 1200:
		filler.append(filler[0])
	_rejects(huge, "a map with over a thousand nodes", "damaged")
	var short := _json_copy(data)
	(short["map"]["nodes"] as Array).resize(20)
	_rejects(short, "a map cut short")
	var other := _json_copy(data)
	other["map"]["character_id"] = "medium"
	_rejects(other, "a map made for another character", "different character")
	var cut_edge := _json_copy(data)
	for n in cut_edge["map"]["nodes"]:
		if n["row"] == 3:
			n["next"] = []
	_rejects(cut_edge, "a map with its edges removed", "invalid")
	var bad_type := _json_copy(data)
	bad_type["map"]["nodes"][0]["type"] = 99
	_rejects(bad_type, "a map with an unknown node type")
	var bad_type_text := _json_copy(data)
	bad_type_text["map"]["nodes"][1]["type"] = "boss"
	_rejects(bad_type_text, "a map whose node type is text")
	var bad_row := _json_copy(data)
	bad_row["map"]["nodes"][2]["row"] = 500
	_rejects(bad_row, "a map with a row off the end")
	var cycle := _json_copy(data)
	cycle["map"]["nodes"][0]["next"] = [0]
	_rejects(cycle, "a map with an edge back to itself")
	var bad_config := _json_copy(data)
	bad_config["map"]["config"] = {"safe_rows": "wide"}
	_rejects(bad_config, "a map with a malformed config")
	var flipped_boss := _json_copy(data)
	for n in flipped_boss["map"]["nodes"]:
		if n["type"] == int(RouteMap.NodeType.BOSS):
			n["type"] = int(RouteMap.NodeType.FIGHT)
	_rejects(flipped_boss, "a map without its final boss", "invalid")


func _test_tampered_position() -> void:
	# One save at the map after four actions (row 1 just done), another inside a stop.
	var at_map := _dict_at(4)
	var in_stop := _dict_at(5)
	_check(at_map["at_node"] == false and in_stop["at_node"] == true and at_map["current_node"] >= 0, "setup: one save at the map, one inside a stop")
	for base in [at_map, in_stop]:
		var tag: String = "(at map)" if base["at_node"] == false else "(in stop)"
		var route := RouteMap.from_dict(base["map"])
		var current: int = base["current_node"]
		for bad in [-2, route.node_count(), 99999, "3", 1.5, null, [], true]:
			var d := _json_copy(base)
			d["current_node"] = bad
			_rejects(d, "current_node %s %s" % [str(bad), tag])
		var other_row := _json_copy(base)
		other_row["current_node"] = route.starts()[0] if route.node(current).row != 0 else route.finals()[0]
		_rejects(other_row, "a current node on a row that disagrees with the path %s" % tag)
		var elsewhere := _json_copy(base)
		for n in route.row_nodes(route.node(current).row):
			if n.id != current:
				elsewhere["current_node"] = n.id
		if elsewhere["current_node"] != current:
			_rejects(elsewhere, "a current node that is not the end of the path %s" % tag)
		for bad_visited in ["x", 7, {}, null, [0, "a"], [99999], [-1], [1.5]]:
			var d := _json_copy(base)
			d["visited"] = bad_visited
			_rejects(d, "visited %s %s" % [str(bad_visited), tag])
		var too_long := _json_copy(base)
		too_long["visited"] = []
		for i in RouteMap.ROWS + 1:
			too_long["visited"].append(0)
		_rejects(too_long, "a visited list longer than the journey %s" % tag)
		var empty := _json_copy(base)
		empty["visited"] = []
		_rejects(empty, "an empty visited list with a current node %s" % tag)
		var truncated := _json_copy(base)
		(truncated["visited"] as Array).remove_at(0)
		_rejects(truncated, "a visited path missing its first node %s" % tag)
		var beyond := _json_copy(base)
		beyond["visited"].append(route.next_ids(current)[0])
		_rejects(beyond, "a visited row beyond the current node %s" % tag)
		var reversed := _json_copy(base)
		(reversed["visited"] as Array).reverse()
		_rejects(reversed, "a visited path in the wrong order %s" % tag)
		var repeated := _json_copy(base)
		repeated["visited"][1] = repeated["visited"][0]
		_rejects(repeated, "a visited path that repeats a node %s" % tag)
		# A path with a road that is not on the map: swap a middle node for one the previous node does not reach.
		var broken := _json_copy(base)
		var swapped := false
		for i in range(1, (broken["visited"] as Array).size() - 1):
			if swapped:
				break
			var prev_id: int = broken["visited"][i - 1]
			for sibling in route.row_nodes(i):
				if sibling.id != broken["visited"][i] and not route.next_ids(prev_id).has(sibling.id):
					broken["visited"][i] = sibling.id
					swapped = true
					break
		if swapped:
			_rejects(broken, "a visited path with a road that is not on the map %s" % tag)
		for bad_index in [base["stop_index"] + 1, base["stop_index"] - 1, -1, RouteMap.ROWS, RouteMap.ROWS + 5, "3", null]:
			var d := _json_copy(base)
			d["stop_index"] = bad_index
			_rejects(d, "stop_index %s %s" % [str(bad_index), tag])
		var flag := _json_copy(base)
		flag["at_node"] = "yes"
		_rejects(flag, "an at_node that is not a boolean %s" % tag)
	# Before the first choice.
	var fresh := RunSave.to_dict(RunState.new(11, &"deserter", true))
	_check(_load(fresh).run != null, "a fresh map run's save loads")
	var with_path := _json_copy(fresh)
	with_path["visited"] = [0]
	_rejects(with_path, "progress recorded before any node was chosen")
	var with_stop := _json_copy(fresh)
	with_stop["at_node"] = true
	_rejects(with_stop, "a stop recorded before any node was chosen")
	var with_row := _json_copy(fresh)
	with_row["stop_index"] = 4
	_rejects(with_row, "a row recorded before any node was chosen")
	# At the map past the last row: a finished run is never a save.
	var last := RunState.new(11, &"deserter", true)
	var step := 0
	while not (last.in_map_stop() and last.stop_index == RouteMap.ROWS - 1) and step < 300:
		_advance(last, step)
		step += 1
	_check(last.in_map_stop() and last.stop_index == RouteMap.ROWS - 1, "setup: standing in the final boss's stop")
	var past := _json_copy(RunSave.to_dict(last))
	_check(_load(past).run != null, "the final boss's stop is a valid save")
	past["at_node"] = false
	_rejects(past, "a save at the map after the last row", "past the last row")


func _test_corrupted_never_crashes() -> void:
	var data := _dict_at(8, 5, &"thief")
	var junk: Array = [null, true, -1, 0, 3.7, 1.0e30, "", "x", [], [1, 2, 3], {}, {"a": 1}, "9999999999999999999"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var rejected := 0
	for round_number in 400:
		var d := _json_copy(data)
		var path: Array = []
		var target: Variant = d
		for depth in rng.randi_range(1, 4):
			if target is Dictionary and not (target as Dictionary).is_empty():
				var keys: Array = (target as Dictionary).keys()
				var key: Variant = keys[rng.randi() % keys.size()]
				path.append(key)
				target = (target as Dictionary)[key]
			elif target is Array and not (target as Array).is_empty():
				var index := rng.randi() % (target as Array).size()
				path.append(index)
				target = (target as Array)[index]
			else:
				break
		if path.is_empty():
			continue
		var parent: Variant = d
		for i in path.size() - 1:
			parent = parent[path[i]]
		var last_key: Variant = path[path.size() - 1]
		var choice := rng.randi() % (junk.size() + 1)
		if choice == junk.size():
			if parent is Dictionary:
				(parent as Dictionary).erase(last_key)
		else:
			parent[last_key] = junk[choice]
		var result := RunSave.from_dict(d)
		_check(result.run != null or result.error != "", "a corrupted save (round %d) is judged, never crashes" % round_number)
		if result.run != null:
			_check(result.run.uses_map() and result.run.route.validate().is_empty(), "a corrupted save that still loads is a valid map run (round %d)" % round_number)
		else:
			rejected += 1
	_check(rejected > 100, "most random corruptions are rejected (%d of 400)" % rejected)
	for text in ["{\"version\": 5, \"map\": [1,2", "[]", "null", "{\"version\":5,\"map\":{\"nodes\":[[[[[[]]]]]]}}", "\u0001\u0002"]:
		_cleanup()
		var file := FileAccess.open(test_path, FileAccess.WRITE)
		file.store_string(text)
		file.close()
		var loaded := RunSave.load_file(test_path)
		_check(loaded.run == null and loaded.error != "", "a damaged file is reported, not crashed on")
	_cleanup()


func _test_cannot_rechoose() -> void:
	# The save written on arrival at a stop holds the chosen node, so quitting and Continuing cannot offer the
	# other roads again: the player is inside the stop with no choices.
	var run_state := RunState.new(31, &"deserter", true)
	var options := run_state.reachable_nodes()
	_check(options.size() >= 1, "setup: there are roads to choose from")
	run_state.choose_node(options[0])
	var resumed := _clone(run_state)
	_check(resumed != null and resumed.in_map_stop() and resumed.current_node == options[0] and resumed.reachable_nodes().is_empty(), "a save made after choosing a node resumes inside that node's stop with no other road offered")
	_check(resumed.current_stop().node_id == options[0] and resumed.rng_state() == run_state.rng_state(), "the stop is the same one, with the same RNG")
	# The save made at the map, before choosing, offers the same roads after loading.
	var before := RunState.new(31, &"deserter", true)
	var copy := _clone(before)
	_check(copy.reachable_nodes() == before.reachable_nodes() and copy.current_stop() == null, "a save made at the map resumes at the map with the same roads")
