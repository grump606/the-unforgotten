extends RefCounted
## Route map phase 2 (docs/MAP_DESIGN.md): RunState in map mode. Legacy mode stays untouched, the map API
## (reachable_nodes, choose_node), every node type's stop, the budget packs of map fights, the backdrop plumbing, whole
## runs and determinism. Registered by run_tests.gd.

const CHARACTERS: Array[StringName] = [&"deserter", &"thief", &"medium", &"stray"]

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
	_test_legacy_untouched()
	_test_start_state()
	_test_choose_rejections()
	_test_reachable_follows_edges()
	_test_fight_node()
	_test_win_heal()
	_test_rest_shop_story()
	_test_mid_boss_and_boss()
	_test_defeat()
	_test_elite()
	_test_ramp()
	_test_backdrops()
	_test_whole_runs()
	_test_determinism()
	_test_save_allowed()
	_test_route_choice_policies()
	_test_treasure()
	_test_events_in_runs()
	print("run_state_map_tests: %d checks" % _checks)
	return _failures


# --- Helpers --------------------------------------------------------------------------------------------

## Passes the current stop the cheap way: a won fight, the reward skipped, a rest, a story beat, a vendor left.
func _resolve(run_state: RunState, victory := true) -> void:
	var stop := run_state.current_stop()
	match stop.type:
		RunState.StopType.COMBAT:
			run_state.complete_combat(victory)
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


## Chooses nodes (preferring `type` when offered) and resolves them until the run is at a node of `type`
## (returns true, the stop still open) or the run ends or 100 steps pass (returns false).
func _walk_to(run_state: RunState, type: RouteMap.NodeType) -> bool:
	for _step in 100:
		if run_state.finished:
			return false
		var options := run_state.reachable_nodes()
		var pick: int = options[0]
		for id in options:
			if run_state.route.node(id).type == type:
				pick = id
				break
		run_state.choose_node(pick)
		if run_state.route.node(pick).type == type:
			return true
		_resolve(run_state)
	return false


# --- Tests ----------------------------------------------------------------------------------------------

func _test_legacy_untouched() -> void:
	var legacy := RunState.new(5)
	var explicit := RunState.new(5, StarterContent.DEFAULT_CHARACTER_ID, false)
	_check(not legacy.uses_map() and legacy.route == null, "map mode is off by default")
	_check(legacy.stops.size() == 22 and legacy.current_stop() == legacy.stops[0], "the default line is the 22-stop line")
	_check(RunSave.line_signature(legacy) == RunSave.line_signature(explicit), "an explicit false gives the same line")
	_check(legacy.reachable_nodes().is_empty() and not legacy.choose_node(0), "no map API effect in line mode")
	_check(legacy.current_node == -1 and legacy.visited.is_empty(), "line mode records no visited nodes")
	_check(legacy.battle_backdrop() == DestinationArt.battle_key(0) and legacy.destination_label() == DestinationArt.label_at(0), "line mode keeps its backdrop and label by stop index")
	var mapped := RunState.new(5, StarterContent.DEFAULT_CHARACTER_ID, true)
	_check(mapped.rng_state() == legacy.rng_state(), "building the map does not touch the run RNG")
	# A legacy run plays as before: the first fight and the reward use the stop's own count and the run RNG.
	var run_state := RunState.new(7)
	run_state.read_story()
	var combat := run_state.start_combat()
	_check(combat != null and combat.enemies.size() == 1 and run_state.stop_index == 1, "legacy fight 1 is one enemy at stop 1")
	run_state.complete_combat(true)
	_check(run_state.reward_pending() and run_state.resolve_reward(null) and run_state.stop_index == 2, "legacy stop_index still advances by one")


func _test_start_state() -> void:
	for character in CHARACTERS:
		var run_state := RunState.new(11, character, true)
		_check(run_state.uses_map() and run_state.route != null, "%s: map mode builds a route" % character)
		_check(run_state.route.validate().is_empty(), "%s: the route is valid" % character)
		_check(run_state.route.seed_value == 11 and run_state.route.character_id == character, "%s: the route comes from the run seed and character" % character)
		_check(run_state.current_node == -1 and run_state.visited.is_empty() and run_state.stop_index == 0, "%s: no node chosen yet" % character)
		_check(run_state.stops.size() == RouteMap.ROWS and RouteMap.ROWS == 30, "%s: the journey is 30 stops long" % character)
		_check(run_state.current_stop() == null and not run_state.finished, "%s: no stop before the first choice" % character)
		_check(run_state.reachable_nodes() == run_state.route.starts(), "%s: the start nodes are reachable" % character)
		_check(run_state.at_stop_boundary(), "%s: between stops counts as a stop boundary" % character)
		_check(run_state.player.hp == run_state.player.max_hp and not run_state.deck.is_empty(), "%s: the run starts with a deck and full HP" % character)


func _test_choose_rejections() -> void:
	var run_state := RunState.new(21, &"deserter", true)
	var starts := run_state.route.starts()
	_check(not run_state.choose_node(-1) and not run_state.choose_node(run_state.route.node_count()), "ids outside the map are rejected")
	var deep := run_state.route.row_nodes(5)[0].id
	_check(not run_state.choose_node(deep), "a node beyond the first row is rejected")
	_check(run_state.current_node == -1 and run_state.visited.is_empty() and run_state.current_stop() == null, "rejections change nothing")
	_check(run_state.choose_node(starts[0]), "a start node is accepted")
	_check(run_state.current_node == starts[0] and run_state.visited == [starts[0]], "the choice is recorded")
	_check(run_state.reachable_nodes().is_empty(), "nothing is reachable while a stop is in progress")
	var next_id: int = run_state.route.next_ids(starts[0])[0]
	_check(not run_state.choose_node(next_id), "a choice mid-stop is rejected")
	_check(not run_state.choose_node(starts[0]), "the same node cannot be chosen twice")
	_resolve(run_state)
	_check(not run_state.choose_node(starts[0]), "a visited node is not reachable again")
	_check(not run_state.choose_node(run_state.route.row_nodes(4)[0].id), "a node three rows ahead is rejected")
	_check(run_state.choose_node(next_id), "the successor is accepted after the stop")
	# Reachable is empty while a reward is pending, too.
	var fight := RunState.new(21, &"deserter", true)
	_walk_to(fight, RouteMap.NodeType.FIGHT)
	fight.complete_combat(true)
	_check(fight.reward_pending() and fight.reachable_nodes().is_empty(), "nothing is reachable while a reward is pending")
	_check(fight.resolve_reward(null) and not fight.reachable_nodes().is_empty(), "the reward ends the stop and opens the map")


func _test_reachable_follows_edges() -> void:
	for seed_value in 6:
		var run_state := RunState.new(seed_value, &"medium", true)
		var picker := RandomNumberGenerator.new()
		picker.seed = seed_value
		var steps := 0
		while not run_state.finished and steps < 60:
			var options := run_state.reachable_nodes()
			if run_state.current_node == -1:
				_check(options == run_state.route.starts(), "seed %d: the start" % seed_value)
			else:
				_check(options == run_state.route.next_ids(run_state.current_node), "seed %d: reachable nodes are the current node's successors" % seed_value)
			run_state.choose_node(options[picker.randi_range(0, options.size() - 1)])
			_check(run_state.stop_index == run_state.route.node(run_state.current_node).row, "seed %d: stop_index is the row of the current node" % seed_value)
			_resolve(run_state)
			steps += 1
		_check(run_state.finished and run_state.escaped and run_state.visited.size() == RouteMap.ROWS, "seed %d: a path of 30 nodes escapes" % seed_value)
		_check(run_state.stop_index == run_state.stops.size() and run_state.reachable_nodes().is_empty() and run_state.current_stop() == null, "seed %d: the end state" % seed_value)


func _test_fight_node() -> void:
	var run_state := RunState.new(31, &"thief", true)
	var seen_counts := {}
	for _i in 30:
		if run_state.finished or not _walk_to(run_state, RouteMap.NodeType.FIGHT):
			break
		var n := run_state.route.node(run_state.current_node)
		var stop := run_state.current_stop()
		if n.type != RouteMap.NodeType.FIGHT:
			break
		_check(stop.type == RunState.StopType.COMBAT and not stop.boss and not stop.mid_boss, "a fight node is a regular combat stop")
		_check(stop.enemy_count == n.enemy_count and stop.backdrop == n.backdrop and stop.node_id == n.id, "the stop carries the node's count, backdrop and id")
		_check(stop.tier == n.act and stop.beat_index == 0, "the stop's tier is the node's act")
		var combat := run_state.start_combat()
		_check(combat != null and combat.enemies.size() == n.enemy_count, "the fight has the node's %d enemies" % n.enemy_count)
		seen_counts[n.enemy_count] = true
		var gold := run_state.gold
		run_state.complete_combat(true)
		_check(run_state.gold == gold + RunState.map_win_gold(n.enemy_count), "a win pays for the node's enemy count (map-mode share)")
		_check(run_state.reward_pending() and run_state.reward_choices().size() > 0, "a won fight offers a reward")
		run_state.resolve_reward(run_state.reward_choices()[0])
		if run_state.visited.size() >= 12:
			break
	_check(seen_counts.size() >= 2, "fights with different pack sizes were played (%d kinds)" % seen_counts.size())


## The map-mode win heal: a share of max HP plus a share of the missing HP after a regular win, only in map mode,
## never above max HP, none after the final boss or a defeat.
func _test_win_heal() -> void:
	var run_state := RunState.new(31, &"thief", true)
	_check(_walk_to(run_state, RouteMap.NodeType.FIGHT), "a fight node is found for the win heal")
	run_state.start_combat()
	var max_hp := run_state.player.max_hp
	run_state.player.hp = 10
	var expected := roundi(max_hp * RunState.MAP_FIGHT_HEAL_FRACTION + (max_hp - 10) * RunState.MAP_FIGHT_HEAL_MISSING_FRACTION)
	run_state.complete_combat(true)
	_check(expected > 0 and run_state.player.hp == 10 + expected and run_state.map_win_heal == expected, "a won map fight heals %d HP (flat share plus a share of the missing HP)" % expected)
	run_state.resolve_reward(null)
	_check(run_state.player.hp == 10 + expected and run_state.map_win_heal == expected, "taking the reward heals nothing more")
	# Hurt players recover more than healthy ones, and nobody goes past max HP.
	var healthy := RunState.new(31, &"thief", true)
	_walk_to(healthy, RouteMap.NodeType.FIGHT)
	healthy.start_combat()
	healthy.complete_combat(true)
	_check(healthy.player.hp == healthy.player.max_hp and healthy.map_win_heal == 0, "a full-HP player is not healed past max HP")
	var nearly := RunState.new(31, &"thief", true)
	_walk_to(nearly, RouteMap.NodeType.FIGHT)
	nearly.start_combat()
	nearly.player.hp = max_hp - 1
	nearly.complete_combat(true)
	_check(nearly.player.hp == max_hp and nearly.map_win_heal == 1, "a heal larger than the wound stops at max HP")
	# A defeat heals nothing; the line never heals.
	var lost := RunState.new(31, &"thief", true)
	_walk_to(lost, RouteMap.NodeType.FIGHT)
	lost.start_combat()
	lost.player.hp = 7
	lost.complete_combat(false)
	_check(lost.finished and lost.player.hp == 7 and lost.map_win_heal == 0, "a lost fight heals nothing")
	var line := RunState.new(31, &"thief")
	line.read_story()
	line.start_combat()
	line.player.hp = 7
	line.complete_combat(true)
	_check(line.player.hp == 7 and line.map_win_heal == 0 and line.gold == Vendor.gold_for_win(1), "line mode: no win heal and the full gold")
	# The final boss ends the run with no heal.
	var boss := RunState.new(51, &"deserter", true)
	_walk_to(boss, RouteMap.NodeType.BOSS)
	boss.start_combat()
	boss.player.hp = 9
	boss.complete_combat(true)
	_check(boss.escaped and boss.player.hp == 9 and boss.map_win_heal == 0, "the final boss gives no heal")


func _test_rest_shop_story() -> void:
	# Rest: heals, ends the stop, counts in rest_number.
	var run_state := RunState.new(41, &"deserter", true)
	_check(_walk_to(run_state, RouteMap.NodeType.REST), "a rest node is found on the way")
	var stop := run_state.current_stop()
	_check(stop.type == RunState.StopType.REST and run_state.rest_number() >= 1, "a rest node is a REST stop")
	run_state.player.hp = 10
	var rest_amount := roundi(run_state.player.max_hp * RunState.MAP_REST_HEAL_FRACTION)
	_check(run_state.rest_heal_amount() == mini(rest_amount, run_state.player.max_hp - 10), "the map rest heals its share of max HP (capped at what is missing)")
	_check(run_state.rest() == rest_amount and run_state.player.hp == 10 + rest_amount, "resting in map mode heals MAP_REST_HEAL_FRACTION of max HP, not all of it")
	var wound := RunState.new(41, &"deserter", true)
	_walk_to(wound, RouteMap.NodeType.REST)
	wound.player.hp = wound.player.max_hp - 3
	_check(wound.rest_heal_amount() == 3 and wound.rest() == 3 and wound.player.hp == wound.player.max_hp, "a small wound is healed fully and never past max HP")
	_check(run_state.current_stop() == null and not run_state.reachable_nodes().is_empty() and not run_state.finished, "after a rest the map is open")
	# Remember is the other rest choice and also ends the stop.
	var other := RunState.new(41, &"deserter", true)
	_walk_to(other, RouteMap.NodeType.REST)
	var indices := other.rememberable_indices()
	_check(not indices.is_empty() and other.remember(indices[0]) and other.current_stop() == null, "Remember ends a rest stop")
	# Shop.
	var shop_run: RunState = null
	for seed_value in 30:
		var candidate := RunState.new(seed_value, &"medium", true)
		if _walk_to(candidate, RouteMap.NodeType.SHOP):
			shop_run = candidate
			break
	_check(shop_run != null, "a shop node is found on some route")
	if shop_run != null:
		_check(shop_run.current_stop().type == RunState.StopType.VENDOR and shop_run.vendor() != null, "a shop node is a VENDOR stop")
		_check(shop_run.leave_vendor() and shop_run.current_stop() == null and not shop_run.reachable_nodes().is_empty(), "leaving the shop opens the map")
	# Story beats in order along a whole path.
	var story_run := RunState.new(43, &"stray", true)
	var beats: Array[int] = []
	while not story_run.finished:
		story_run.choose_node(story_run.reachable_nodes()[0])
		var current := story_run.current_stop()
		if current.type == RunState.StopType.STORY:
			beats.append(current.beat_index)
			_check(story_run.current_beat() != null, "story beat %d loads" % current.beat_index)
		_resolve(story_run)
	_check(beats == [0, 1, 2, 3], "the four story beats come in order (got %s)" % [beats])


func _test_mid_boss_and_boss() -> void:
	var run_state := RunState.new(51, &"deserter", true)
	_check(_walk_to(run_state, RouteMap.NodeType.MID_BOSS), "the mid-boss is on the way")
	var stop := run_state.current_stop()
	_check(stop.type == RunState.StopType.COMBAT and stop.mid_boss and not stop.boss and stop.enemy_count == 1, "the mid-boss stop")
	_check(run_state.boss_label() == "Mid-boss" and run_state.stop_index == 14, "the mid-boss is labelled and sits on row 14")
	var combat := run_state.start_combat()
	_check(combat != null and combat.enemies.size() == 1 and combat.enemies[0].data.id == StarterContent.mid_boss_encounter()[0].id, "the mid-boss fight is the mid-boss encounter")
	var gold := run_state.gold
	run_state.player.hp = 5
	# A relic found on the way (a chest, an event) may heal or pay on a win too; this check is about the map's own heal and gold.
	run_state.relics.clear()
	run_state.complete_combat(true)
	_check(run_state.gold == gold + RunState.map_win_gold(1) + RunState.MID_BOSS_GOLD_BONUS, "the mid-boss pays gold and its bonus")
	_check(run_state.player.hp == mini(run_state.player.max_hp, 5 + roundi(run_state.player.max_hp * RunState.MAP_MID_BOSS_HEAL_FRACTION)) and run_state.map_win_heal == run_state.player.hp - 5, "the mid-boss heals MAP_MID_BOSS_HEAL_FRACTION of max HP")
	_check(run_state.reward_pending() and not run_state.finished, "the mid-boss offers a reward and the run goes on")
	run_state.resolve_reward(null)
	_check(not run_state.finished and run_state.reachable_nodes().size() >= 1 and run_state.route.node(run_state.reachable_nodes()[0]).act == 1, "after the mid-boss the second act opens")
	_check(_walk_to(run_state, RouteMap.NodeType.BOSS), "the final boss is on the way")
	var boss := run_state.current_stop()
	_check(boss.boss and not boss.mid_boss and run_state.boss_label() == "Boss" and run_state.stop_index == 29, "the final boss stop on row 29")
	var boss_combat := run_state.start_combat()
	_check(boss_combat != null and boss_combat.enemies[0].data.id == StarterContent.boss_encounter()[0].id, "the final boss fight is the boss encounter")
	var gold_before := run_state.gold
	run_state.complete_combat(true)
	_check(run_state.finished and run_state.escaped and not run_state.reward_pending() and run_state.gold == gold_before, "beating the final boss ends the run as an escape with no reward")
	_check(run_state.stop_index == run_state.stops.size() and run_state.current_stop() == null and run_state.reachable_nodes().is_empty(), "the finished map run has no stop and nothing reachable")


func _test_defeat() -> void:
	var run_state := RunState.new(61, &"thief", true)
	_walk_to(run_state, RouteMap.NodeType.FIGHT)
	var row := run_state.stop_index
	var successor: int = run_state.route.next_ids(run_state.current_node)[0]
	run_state.start_combat()
	run_state.complete_combat(false)
	_check(run_state.finished and not run_state.escaped and run_state.stop_index == row, "a defeat ends the run where it happened")
	_check(run_state.reachable_nodes().is_empty() and run_state.current_stop() == null and not run_state.choose_node(successor), "nothing can be chosen after a defeat")


func _test_elite() -> void:
	var run_state := RunState.new(71, &"deserter", true)
	var elite_id := -1
	for _i in 20:
		var options := run_state.reachable_nodes()
		for id in options:
			if run_state.route.node(id).type == RouteMap.NodeType.FIGHT:
				elite_id = id
		if elite_id != -1:
			break
		run_state.choose_node(options[0])
		_resolve(run_state)
	_check(elite_id != -1, "a fight node to turn into an elite")
	var n := run_state.route.node(elite_id)
	n.type = RouteMap.NodeType.ELITE
	n.enemy_count = 1
	run_state.choose_node(elite_id)
	var stop := run_state.current_stop()
	_check(stop.type == RunState.StopType.COMBAT and stop.enemy_count >= 2 and stop.elite and not stop.boss and not stop.mid_boss, "an elite fights a flagged pack of at least two")
	var rng_state := run_state.rng_state()
	var combat := run_state.start_combat()
	_check(combat != null and combat.enemies.size() >= 2, "the elite pack has at least two enemies")
	_check(stop.row == n.row, "the elite stop carries its row")
	# The pack is the budget pack at ELITE_BUDGET_MULTIPLIER times the regular difficulty (replay the RNG to check).
	var replay := RandomNumberGenerator.new()
	replay.state = rng_state
	var expected := StarterContent.budget_encounter(stop.enemy_count, replay, stop.row, StarterContent.map_class_difficulty(&"deserter") * RunState.ELITE_BUDGET_MULTIPLIER, true)
	var same := expected.size() == combat.enemies.size()
	for i in expected.size() if same else 0:
		same = same and expected[i].max_hp == combat.enemies[i].max_hp
	_check(same, "the elite pack is built at the elite budget")
	var plain_threat := StarterContent.pack_threat(StarterContent.budget_encounter(stop.enemy_count, RandomNumberGenerator.new(), stop.row, StarterContent.map_class_difficulty(&"deserter")))
	_check(StarterContent.pack_threat(expected) > plain_threat, "an elite pack is tougher than a regular one on the same row")
	# Winning: extra gold, a relic that joins the run at once, shown on the reward and cleared when it is taken.
	var gold := run_state.gold
	var relics_before := run_state.relics.size()
	run_state.complete_combat(true)
	_check(run_state.gold == gold + RunState.map_win_gold(stop.enemy_count) + RunState.ELITE_GOLD_BONUS, "an elite win pays the regular gold plus the elite bonus")
	_check(run_state.elite_relic != null and run_state.relics.size() == relics_before + 1 and run_state.relics.has(run_state.elite_relic), "an elite drops a relic that joins the run")
	_check(run_state.elite_relic.price >= RunState.TREASURE_MIN_RELIC_PRICE, "the elite relic is not from the cheapest tier")
	run_state.resolve_reward(null)
	_check(run_state.elite_relic == null and run_state.elite_fallback_gold == 0, "taking the reward clears the elite drop")
	# A character that owns every relic gets gold instead.
	var full := RunState.new(72, &"deserter", true)
	full.relics.assign(StarterContent.relic_pool(&"deserter"))
	_check(_walk_to_elite(full), "an elite node for the full-relics case")
	full.start_combat()
	var full_gold := full.gold
	var win_gold_relics := 0 # relics that pay on every win; the full pool holds them all
	for relic in full.relics:
		if relic.kind == RelicData.Kind.WIN_GOLD:
			win_gold_relics += relic.amount
	full.complete_combat(true)
	_check(full.elite_relic == null and full.elite_fallback_gold == RunState.ELITE_RELIC_FALLBACK_GOLD and full.gold == full_gold + RunState.map_win_gold(full.current_stop().enemy_count) + win_gold_relics + RunState.ELITE_GOLD_BONUS + RunState.ELITE_RELIC_FALLBACK_GOLD, "with every relic owned an elite drops gold instead")
	# A regular fight drops nothing extra.
	var plain := RunState.new(31, &"thief", true)
	_walk_to(plain, RouteMap.NodeType.FIGHT)
	plain.start_combat()
	plain.complete_combat(true)
	_check(plain.elite_relic == null and plain.elite_fallback_gold == 0 and not plain.current_stop().elite, "a regular fight is not an elite and drops no relic")


## Walks until a fight is reachable, turns it into an elite and enters it.
func _walk_to_elite(run_state: RunState) -> bool:
	for _i in 20:
		var options := run_state.reachable_nodes()
		for id in options:
			if run_state.route.node(id).type == RouteMap.NodeType.FIGHT:
				var n := run_state.route.node(id)
				n.type = RouteMap.NodeType.ELITE
				n.enemy_count = 2
				return run_state.choose_node(id)
		run_state.choose_node(options[0])
		_resolve(run_state)
	return false


func _test_ramp() -> void:
	# Every map fight is built by budget_encounter from the node's count and row: replaying the run RNG from just
	# before start_combat reproduces the pack, and the stop carries the node's row.
	for seed_value in 4:
		var run_state := RunState.new(seed_value, &"deserter", true)
		while not run_state.finished:
			var options := run_state.reachable_nodes()
			run_state.choose_node(options[seed_value % options.size()])
			var stop := run_state.current_stop()
			var n := run_state.route.node(run_state.current_node)
			_check(stop.row == n.row, "seed %d: the stop knows its row %d" % [seed_value, n.row])
			if stop.type == RunState.StopType.COMBAT and not stop.boss and not stop.mid_boss:
				var state := run_state.rng_state()
				var combat := run_state.start_combat()
				var replay := RandomNumberGenerator.new()
				replay.state = state
				var expected := StarterContent.budget_encounter(stop.enemy_count, replay, n.row, StarterContent.map_class_difficulty(run_state.character.id))
				var same := combat != null and combat.enemies.size() == expected.size()
				if same:
					for i in expected.size():
						same = same and combat.enemies[i].max_hp == expected[i].max_hp and combat.enemies[i].display_name == expected[i].display_name
				_check(same, "seed %d: the fight on row %d is the budget pack" % [seed_value, n.row])
				combat.abandon()
				run_state.restore_rng_state(state)
			_resolve(run_state)


func _test_backdrops() -> void:
	var run_state := RunState.new(81, &"medium", true)
	var checked_pool := false
	while not run_state.finished:
		run_state.choose_node(run_state.reachable_nodes()[0])
		var n := run_state.route.node(run_state.current_node)
		var stop := run_state.current_stop()
		if stop.type == RunState.StopType.COMBAT:
			_check(run_state.battle_backdrop() == n.backdrop and n.backdrop != &"", "the fight at row %d uses its node's backdrop" % n.row)
			if n.type == RouteMap.NodeType.FIGHT:
				checked_pool = checked_pool or RouteMap.backdrop_pool(&"medium").has(n.backdrop)
		if n.type == RouteMap.NodeType.MID_BOSS:
			_check(run_state.battle_backdrop() == &"battle_bell_court" and run_state.destination_label() == "The Bell Court", "the mid-boss backdrop and label")
		if n.type == RouteMap.NodeType.BOSS:
			_check(run_state.battle_backdrop() == &"battle_threshold" and run_state.destination_label() == "The Threshold", "the boss backdrop and label")
		if n.type == RouteMap.NodeType.STORY:
			_check(run_state.destination_label() != "", "story beat %d has a place name" % stop.beat_index)
		if n.type == RouteMap.NodeType.REST or n.type == RouteMap.NodeType.SHOP:
			_check(run_state.battle_backdrop() == &"" and run_state.destination_label() != "", "rest and shop have a place name and no battle backdrop")
		_resolve(run_state)
	_check(checked_pool, "regular fights draw their backdrop from the character's pool")
	_check(run_state.battle_backdrop() == &"", "no backdrop once the run is over")


func _test_whole_runs() -> void:
	var escapes := 0
	var defeats := 0
	for seed_value in 80:
		var character: StringName = CHARACTERS[seed_value % CHARACTERS.size()]
		var run_state := RunState.new(seed_value, character, true)
		var chooser := RandomNumberGenerator.new()
		chooser.seed = seed_value
		var steps := 0
		while not run_state.finished and steps < 200:
			var options := run_state.reachable_nodes()
			if options.is_empty():
				break
			var before := run_state.visited.size()
			run_state.choose_node(options[chooser.randi_range(0, options.size() - 1)])
			# Lose about one fight in a hundred, so some runs end early.
			var wins := not (run_state.current_stop().type == RunState.StopType.COMBAT and chooser.randi_range(0, 99) < 1)
			_resolve(run_state, wins)
			steps += 1
			_check(run_state.visited.size() == before + 1, "seed %d: each step visits one node" % seed_value)
		_check(run_state.finished, "seed %d (%s): the run finishes without stalling" % [seed_value, character])
		if run_state.escaped:
			escapes += 1
			_check(run_state.visited.size() == RouteMap.ROWS, "seed %d: an escaped run took 30 nodes" % seed_value)
		else:
			defeats += 1
		for i in run_state.visited.size():
			_check(run_state.route.node(run_state.visited[i]).row == i, "seed %d: visited node %d is in row %d" % [seed_value, i, i])
	_check(escapes > 0 and defeats > 0, "the bot saw both escapes (%d) and defeats (%d)" % [escapes, defeats])


func _test_determinism() -> void:
	for seed_value in [3, 17]:
		var a := RunState.new(seed_value, &"deserter", true)
		var b := RunState.new(seed_value, &"deserter", true)
		_check(a.route.to_dict() == b.route.to_dict(), "seed %d: same seed, same map" % seed_value)
		var different := RunState.new(seed_value + 1, &"deserter", true)
		_check(a.route.to_dict() != different.route.to_dict(), "seed %d: a different seed gives a different map" % seed_value)
		var names_a := _encounter_names(a)
		var names_b := _encounter_names(b)
		_check(names_a == names_b and not names_a.is_empty(), "seed %d: same seed, same encounters" % seed_value)
		_check(a.rng_state() == b.rng_state() and a.visited == b.visited, "seed %d: same seed, same run state" % seed_value)


## Plays the first-node route with real encounters built (not fought) and lists every enemy id.
func _encounter_names(run_state: RunState) -> Array[String]:
	var names: Array[String] = []
	var guard := 0
	while not run_state.finished and guard < 40:
		guard += 1
		run_state.choose_node(run_state.reachable_nodes()[0])
		if run_state.current_stop().type == RunState.StopType.COMBAT:
			var combat := run_state.start_combat()
			for enemy in combat.enemies:
				names.append(String(enemy.data.id))
		_resolve(run_state)
	return names


func _test_save_allowed() -> void:
	var run_state := RunState.new(1, &"deserter", true)
	var path := "user://map_run_test_save.json"
	_check(RunSave.save(run_state, path) == "" and FileAccess.file_exists(path), "a map run can be saved (format 5, see run_save_map_tests.gd)")
	RunSave.delete(path)


func _test_route_choice_policies() -> void:
	var run_state := RunState.new(91, &"deserter", true)
	_check(SimPolicy.choose_route(run_state) == run_state.route.starts()[0] and SmartPolicy.choose_route(run_state) == run_state.route.starts()[0], "both bots take a start node first")
	_check(run_state.choose_node(SimPolicy.choose_route(run_state)), "the bot's pick is accepted")
	_check(SimPolicy.choose_route(run_state) == -1 and SmartPolicy.choose_route(run_state) == -1, "no pick while a stop is open")
	# Smart: rest when hurt, shop when rich, else a fight.
	for seed_value in 40:
		var r := RunState.new(seed_value, &"deserter", true)
		var guard := 0
		while not r.finished and guard < 80:
			guard += 1
			if r.current_stop() != null:
				_resolve(r)
				continue
			var options := r.reachable_nodes()
			var types: Array = []
			for id in options:
				types.append(r.route.node(id).type)
			var hp := r.player.hp
			var gold := r.gold
			r.player.hp = r.player.max_hp
			r.gold = 0
			var plain := SmartPolicy.choose_route(r)
			if types.has(RouteMap.NodeType.EVENT):
				_check(r.route.node(plain).type == RouteMap.NodeType.EVENT, "smart takes an event over a fight while healthy")
			elif types.has(RouteMap.NodeType.FIGHT):
				_check(r.route.node(plain).type == RouteMap.NodeType.FIGHT, "smart takes a fight by default")
			r.player.hp = 1
			var hurt := SmartPolicy.choose_route(r)
			if types.has(RouteMap.NodeType.EVENT) and types.has(RouteMap.NodeType.FIGHT) and not types.has(RouteMap.NodeType.REST):
				_check(r.route.node(hurt).type == RouteMap.NodeType.FIGHT, "smart leaves an event alone while hurt")
			if types.has(RouteMap.NodeType.REST):
				_check(r.route.node(hurt).type == RouteMap.NodeType.REST, "smart rests when hurt")
			r.player.hp = r.player.max_hp
			r.gold = 500
			var rich := SmartPolicy.choose_route(r)
			if types.has(RouteMap.NodeType.SHOP):
				_check(r.route.node(rich).type == RouteMap.NodeType.SHOP, "smart shops when rich")
			_check(options.has(plain) and options.has(hurt) and options.has(rich), "smart always picks a reachable node")
			r.player.hp = hp
			r.gold = gold
			r.choose_node(plain)


# --- Treasure (phase 4b) ----------------------------------------------------------------------------------

func _chest_run(seed_value: int, character: StringName) -> RunState:
	var run_state := RunState.new(seed_value, character, true)
	_check(_walk_to(run_state, RouteMap.NodeType.TREASURE), "%s seed %d: the treasure row is on the way" % [character, seed_value])
	return run_state


func _test_treasure() -> void:
	_check(RunState.stop_type_for_node(RouteMap.NodeType.TREASURE) == RunState.StopType.TREASURE and int(RunState.StopType.TREASURE) == 4, "a treasure node plays as the appended TREASURE stop")
	var run_state := _chest_run(7, &"deserter")
	var stop := run_state.current_stop()
	_check(stop.type == RunState.StopType.TREASURE and stop.describe() == "Treasure" and run_state.stop_index == 6, "a treasure node is a TREASURE stop on row 6")
	_check(run_state.in_treasure_stop() and not run_state.treasure_opened() and run_state.treasure_relic() == null and run_state.treasure_gold() == 0, "the chest starts closed")
	_check(run_state.destination_label() != "" and run_state.at_stop_boundary() and run_state.reachable_nodes().is_empty(), "a closed chest is a boundary with a place name and no other road")
	_check(not run_state.take_treasure() and run_state.current_stop() == stop, "nothing can be taken from a closed chest")
	_check(not run_state.vendor_buy_relic().ok and run_state.rest() == -1 and not run_state.read_story(), "other stop actions fail at a chest")
	var rng_before := run_state.rng_state()
	var relics_before := run_state.relics.size()
	_check(run_state.open_treasure() and run_state.treasure_opened(), "the chest opens")
	var relic := run_state.treasure_relic()
	_check(relic != null and relic.price >= RunState.TREASURE_MIN_RELIC_PRICE and StarterContent.relic_pool(&"deserter").has(relic), "the relic is from the pool and not in the cheapest tier")
	_check(run_state.rng_state() != rng_before and not run_state.at_stop_boundary(), "opening rolls with the run RNG and the open chest is not a boundary")
	var rng_open := run_state.rng_state()
	_check(run_state.open_treasure() and run_state.treasure_relic() == relic and run_state.rng_state() == rng_open, "opening again changes nothing")
	_check(run_state.relics.size() == relics_before, "an open chest has not yet given the relic")
	var max_hp := run_state.player.max_hp
	_check(run_state.take_treasure() and run_state.relics.has(relic) and run_state.relics.size() == relics_before + 1, "taking adds the relic")
	_check(run_state.current_stop() == null and not run_state.reachable_nodes().is_empty() and run_state.at_stop_boundary(), "taking leaves the stop for the map")
	_check(not run_state.treasure_opened() and run_state.treasure_relic() == null and not run_state.take_treasure() and not run_state.open_treasure(), "a taken chest is gone")
	_check(run_state.player.max_hp == max_hp + (relic.amount if relic.kind == RelicData.Kind.MAX_HP else 0), "a max-HP relic raises max HP, others do not")
	# A max-HP relic from a chest raises max HP and HP once, here.
	var flask: RelicData = null
	for candidate in StarterContent.relic_pool(&"deserter"):
		if candidate.kind == RelicData.Kind.MAX_HP:
			flask = candidate
	var owned := _chest_run(9, &"deserter")
	for candidate in StarterContent.relic_pool(&"deserter"):
		if candidate != flask:
			owned.relics.append(candidate)
	var hp_before := owned.player.hp
	var max_before := owned.player.max_hp
	owned.open_treasure()
	_check(flask != null and flask.price < RunState.TREASURE_MIN_RELIC_PRICE or owned.treasure_relic() == flask, "the last relic left is the one the chest holds")
	_check(owned.treasure_relic() == flask and owned.take_treasure() and owned.player.max_hp == max_before + flask.amount and owned.player.hp == hp_before + flask.amount, "a max-HP relic raises max HP and HP once")
	# Rules per character: never a duplicate, never from outside the pool, whatever is already owned.
	for character in CHARACTERS:
		var seen := {}
		var held := _chest_run(3, character)
		var guard := 0
		while guard < 40:
			guard += 1
			held.open_treasure()
			var got := held.treasure_relic()
			if got == null:
				_check(held.treasure_gold() == RunState.TREASURE_FALLBACK_GOLD, "%s: with every relic owned the chest holds gold" % character)
				break
			_check(not seen.has(got.id) and StarterContent.relic_pool(character).has(got), "%s: chest %d gives a new relic from the pool (%s)" % [character, guard, got.id])
			seen[got.id] = true
			held.take_treasure()
			# A fresh chest: put the run back inside the same stop.
			held.restore_map(held.route, held.current_node, held.visited, true)
		_check(seen.size() == StarterContent.relic_pool(character).size(), "%s: repeated chests hand out the whole pool once (%d relics)" % [character, seen.size()])
	# Gold fallback.
	var rich := _chest_run(5, &"thief")
	rich.relics.assign(StarterContent.relic_pool(&"thief"))
	var gold_before := rich.gold
	rich.open_treasure()
	_check(rich.treasure_relic() == null and rich.treasure_gold() == RunState.TREASURE_FALLBACK_GOLD and rich.treasure_opened(), "a character with every relic finds gold")
	_check(rich.take_treasure() and rich.gold == gold_before + RunState.TREASURE_FALLBACK_GOLD and rich.relics.size() == StarterContent.relic_pool(&"thief").size(), "taking the gold pays it and adds no relic")
	# The price floor yields when nothing dearer is left.
	var cheap := _chest_run(5, &"medium")
	var pricey := 0
	for candidate in StarterContent.relic_pool(&"medium"):
		if candidate.price >= RunState.TREASURE_MIN_RELIC_PRICE:
			cheap.relics.append(candidate)
			pricey += 1
	cheap.open_treasure()
	_check(pricey > 0 and cheap.treasure_relic() != null and cheap.treasure_relic().price < RunState.TREASURE_MIN_RELIC_PRICE, "with only cheap relics left the chest gives one of those")
	# Determinism: the same seed finds the same relic; a run reloaded from the arrival save finds it too.
	for character in CHARACTERS:
		var a := _chest_run(31, character)
		var b := _chest_run(31, character)
		var saved := RunSave.to_dict(a)
		a.open_treasure()
		b.open_treasure()
		_check(a.treasure_relic() == b.treasure_relic() and a.rng_state() == b.rng_state(), "%s: the same seed finds the same relic" % character)
		var json := JSON.new()
		json.parse(JSON.stringify(saved))
		var resumed := RunSave.from_dict(json.data).run
		_check(resumed != null and resumed.in_treasure_stop() and not resumed.treasure_opened(), "%s: the arrival save resumes at the closed chest" % character)
		resumed.open_treasure()
		_check(resumed.treasure_relic() == a.treasure_relic(), "%s: a resumed chest holds the same relic" % character)
	# Whole runs cross exactly two chests each (one per act).
	for seed_value in 12:
		var full := RunState.new(seed_value, CHARACTERS[seed_value % 4], true)
		var chests := 0
		while not full.finished:
			full.choose_node(SimPolicy.choose_route(full))
			if full.current_stop().type == RunState.StopType.TREASURE:
				chests += 1
				_check(SimPolicy.treasure_stop(full), "seed %d: the bot opens and takes the chest" % seed_value)
			else:
				_resolve(full)
		_check(chests == 2 and full.escaped and full.relics.size() == 2, "seed %d: a run passes two chests and ends with their two relics (%d, %d)" % [seed_value, chests, full.relics.size()])
	# Route choice: a chest is taken ahead of a fight.
	var router := RunState.new(13, &"deserter", true)
	var chest_row := router.route.row_nodes(6)
	_check(SmartPolicy.choose_route(router) != -1 and chest_row[0].type == RouteMap.NodeType.TREASURE, "smart picks a node, and the map has its chest row")
	var line := RunState.new(1)
	var line_chests := 0
	for line_stop in line.stops:
		line_chests += 1 if line_stop.type == RunState.StopType.TREASURE else 0
	_check(line_chests == 0 and not line.open_treasure(), "the old line has no chest")


## Whole runs that seek out every event they are offered: events never stall a run, a run never meets an event twice
## before it has met all twelve, bots of both kinds settle every pick, and HP, gold and the deck stay sane.
func _test_events_in_runs() -> void:
	var played := 0
	var most_in_a_run := 0
	for seed_value in 8:
		var character: StringName = CHARACTERS[seed_value % CHARACTERS.size()]
		var smart := seed_value % 2 == 1
		var run_state := RunState.new(seed_value + 400, character, true)
		var chooser := RandomNumberGenerator.new()
		chooser.seed = seed_value
		var ids: Array[StringName] = []
		var steps := 0
		while not run_state.finished and steps < 200:
			var options := run_state.reachable_nodes()
			var pick: int = options[chooser.randi_range(0, options.size() - 1)]
			for id in options:
				if run_state.route.node(id).type == RouteMap.NodeType.EVENT:
					pick = id
					break
			run_state.choose_node(pick)
			steps += 1
			if run_state.current_stop().type == RunState.StopType.EVENT:
				ids.append(run_state.current_event().id)
				_check(SmartPolicy.event_stop(run_state) if smart else SimPolicy.event_stop(run_state), "seed %d: the bot settles event %d" % [seed_value, ids.size()])
				played += 1
				_check(run_state.player.hp >= 1 and run_state.player.hp <= run_state.player.max_hp and run_state.gold >= 0 and run_state.deck.size() >= 1, "seed %d: HP, gold and the deck are sane after an event" % seed_value)
				_check(run_state.at_stop_boundary() and run_state.current_stop() == null, "seed %d: an event leaves the run at the map" % seed_value)
			else:
				_resolve(run_state, chooser.randi_range(0, 99) >= 4)
		_check(run_state.finished, "seed %d (%s, %s): a run full of events finishes" % [seed_value, character, "smart" if smart else "greedy"])
		var distinct := {}
		for id in ids:
			distinct[id] = true
		_check(distinct.size() == mini(ids.size(), 12) or ids.size() > 12, "seed %d: no event repeats within a run (%d events, %d distinct)" % [seed_value, ids.size(), distinct.size()])
		most_in_a_run = maxi(most_in_a_run, ids.size())
	_check(played >= 10 and most_in_a_run >= 3, "the runs played many events (%d, at most %d in one run)" % [played, most_in_a_run])
