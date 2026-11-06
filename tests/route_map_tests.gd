extends RefCounted
## Route map phase 1 (docs/MAP_DESIGN.md): the graph, the seeded generator, the validator, plain-data round
## trips and the straight-line adapter. Registered by run_tests.gd.

const CHARACTERS: Array[StringName] = [&"deserter", &"thief", &"medium", &"stray"]
const FIGHT := RouteMap.NodeType.FIGHT
const ELITE := RouteMap.NodeType.ELITE
const REST := RouteMap.NodeType.REST
const SHOP := RouteMap.NodeType.SHOP
const STORY := RouteMap.NodeType.STORY
const MID_BOSS := RouteMap.NodeType.MID_BOSS
const BOSS := RouteMap.NodeType.BOSS

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
	_test_determinism()
	_test_own_rng()
	_test_structure()
	_test_paths()
	_test_type_rules()
	_test_availability()
	_test_enemy_counts()
	_test_backdrops()
	_test_unknown_characters()
	_test_validate_accepts_generated()
	_test_validate_catches_corruption()
	_test_round_trip()
	_test_from_line()
	_test_elite_config()
	_test_config_merge()
	_test_config_shapes()
	_test_hostile_data()
	_test_node_mix()
	print("route_map_tests: %d checks" % _checks)
	return _failures


func _fights_back(map: RouteMap, id: int) -> Dictionary:
	# Independent of RouteMap's own walk: the backdrops of the most recent fight on each path into `id`.
	var found := {}
	var seen := {}
	var stack: Array[int] = []
	stack.assign(map.previous_ids(id))
	while not stack.is_empty():
		var p: int = stack.pop_back()
		if seen.has(p):
			continue
		seen[p] = true
		var n := map.node(p)
		if n.type == FIGHT or n.type == ELITE or n.type == MID_BOSS or n.type == BOSS:
			found[n.backdrop] = true
		else:
			stack.append_array(map.previous_ids(p))
	return found


func _any_violation(map: RouteMap, fragment: String) -> bool:
	for message in map.validate():
		if message.contains(fragment):
			return true
	return false


func _copy(map: RouteMap) -> RouteMap:
	return RouteMap.from_dict(map.to_dict())


func _test_determinism() -> void:
	var a := JSON.stringify(RouteMap.generate(1234, &"medium").to_dict())
	var b := JSON.stringify(RouteMap.generate(1234, &"medium").to_dict())
	_check(a == b, "same seed, character and config give an identical map")
	var elite := {"type_weights": {"elite": 10.0}}
	_check(JSON.stringify(RouteMap.generate(55, &"thief", elite).to_dict()) == JSON.stringify(RouteMap.generate(55, &"thief", elite).to_dict()), "same arguments with a config give an identical map")
	var distinct := {}
	for s in 20:
		distinct[JSON.stringify(RouteMap.generate(s, &"deserter").to_dict())] = true
	_check(distinct.size() == 20, "twenty seeds give twenty different maps (%d)" % distinct.size())
	_check(JSON.stringify(RouteMap.generate(7, &"deserter").to_dict()) != JSON.stringify(RouteMap.generate(7, &"stray").to_dict()), "the character changes the backdrops")
	_check(JSON.stringify(RouteMap.generate(7, &"deserter").to_dict()) != JSON.stringify(RouteMap.generate(7, &"deserter", elite).to_dict()), "the config changes the map")


func _test_own_rng() -> void:
	seed(99)
	var expected := randi()
	seed(99)
	RouteMap.generate(5, &"deserter")
	_check(randi() == expected, "generation leaves the global random stream alone")


func _test_structure() -> void:
	for map_seed in 80:
		var map := RouteMap.generate(map_seed, CHARACTERS[map_seed % 4])
		_check(map.row_count() == 30, "seed %d: 30 rows" % map_seed)
		var total := 0
		for row in 30:
			var count := map.row_nodes(row).size()
			total += count
			var local := row % 15
			var choke := local == 14 or (row < 15 and (local == 0 or local == 13)) or (row >= 15 and (local == 3 or local == 13))
			if choke:
				_check(count == 1, "seed %d: row %d is a choke row with one node" % [map_seed, row])
			else:
				_check(count == 3 or count == 4, "seed %d: free row %d has 3 or 4 nodes (%d)" % [map_seed, row, count])
		_check(total == map.node_count(), "seed %d: node count matches" % map_seed)
		var free := 0
		for row in 30:
			if map.row_nodes(row).size() > 1:
				free += 1
		_check(free == 24, "seed %d: 24 free rows (%d)" % [map_seed, free])
		_check(map.starts().size() == 1 and map.finals().size() == 1, "seed %d: one start and one final boss" % map_seed)
		_check(map.node(map.starts()[0]).type == STORY and map.node(map.starts()[0]).beat_index == 0, "seed %d: the run opens with story beat 0" % map_seed)
		var last := map.node(map.finals()[0])
		_check(last.type == BOSS and last.row == 29, "seed %d: the run ends with the boss on row 29" % map_seed)
		_check(map.node(map.row_nodes(14)[0].id).type == MID_BOSS, "seed %d: the mid-boss is on row 14" % map_seed)
		var beats: Array[Vector2i] = [Vector2i(0, 0), Vector2i(13, 1), Vector2i(18, 2), Vector2i(28, 3)]
		for beat in beats:
			var story := map.row_nodes(beat.x)[0]
			_check(story.type == STORY and story.beat_index == beat.y, "seed %d: story beat %d on row %d" % [map_seed, beat.y, beat.x])
		for n in map.nodes:
			_check(n.row < 15 and n.act == 0 or n.row >= 15 and n.act == 1, "seed %d: node %d is in the right act" % [map_seed, n.id])
			for nxt in n.next:
				_check(map.node(nxt).row == n.row + 1 and map.previous_ids(nxt).has(n.id), "seed %d: edge %d to %d goes one row down and is mirrored" % [map_seed, n.id, nxt])
			if n.row < 29:
				_check(not n.next.is_empty(), "seed %d: node %d has an exit" % [map_seed, n.id])
			if n.row > 0:
				_check(not n.prev.is_empty(), "seed %d: node %d has an entrance" % [map_seed, n.id])
		# Edges between free rows: 1 or 2 exits, columns within one, no crossing; chokes link to everything.
		for row in 29:
			var upper := map.row_nodes(row)
			var lower := map.row_nodes(row + 1)
			if upper.size() == 1 or lower.size() == 1:
				for n in upper:
					_check(n.next.size() == lower.size(), "seed %d: choke row edges at row %d are complete" % [map_seed, row])
				continue
			var edges: Array[Vector2i] = []
			for n in upper:
				_check(n.next.size() >= 1 and n.next.size() <= 2, "seed %d: node %d has 1 or 2 exits" % [map_seed, n.id])
				for nxt in n.next:
					_check(absi(map.node(nxt).col - n.col) <= 1, "seed %d: edge %d to %d stays within one column" % [map_seed, n.id, nxt])
					edges.append(Vector2i(n.col, map.node(nxt).col))
			for i in edges.size():
				for j in range(i + 1, edges.size()):
					_check(not ((edges[i].x < edges[j].x and edges[i].y > edges[j].y) or (edges[i].x > edges[j].x and edges[i].y < edges[j].y)), "seed %d: edges %s and %s do not cross" % [map_seed, edges[i], edges[j]])


func _test_paths() -> void:
	for map_seed in 60:
		var map := RouteMap.generate(map_seed, &"deserter")
		# Walk every row once, tracking the fewest and most story beats and bosses on any path into each node.
		var low := {}
		var high := {}
		for id in map.starts():
			var n := map.node(id)
			var weight := _beat_weight(n)
			low[id] = weight
			high[id] = weight
		for row in range(1, 30):
			for n in map.row_nodes(row):
				var lo := 1000000
				var hi := -1
				for p in n.prev:
					lo = mini(lo, low[p])
					hi = maxi(hi, high[p])
				low[n.id] = lo + _beat_weight(n)
				high[n.id] = hi + _beat_weight(n)
		var end := map.finals()[0]
		# Story beats count 1, bosses count 100: every path carries exactly 4 beats and 2 bosses.
		_check(low[end] == 204 and high[end] == 204, "seed %d: every path has 4 story beats and 2 bosses (%d to %d)" % [map_seed, low[end], high[end]])
		_check(map.path_count() >= 2, "seed %d: the map really branches" % map_seed)
		if map.path_count() <= 3000:
			var paths := map.all_paths()
			_check(paths.size() == map.path_count(), "seed %d: all_paths agrees with path_count" % map_seed)
			var distinct := {}
			var well_formed := true
			for path in paths:
				distinct[path] = true
				well_formed = well_formed and path.size() == 30 and map.node(path[0]).row == 0
				for i in range(1, path.size()):
					well_formed = well_formed and map.next_ids(path[i - 1]).has(path[i])
			_check(well_formed, "seed %d: every path takes one node per row and follows edges" % map_seed)
			_check(distinct.size() == paths.size(), "seed %d: no path is listed twice" % map_seed)


func _beat_weight(n: RouteMap.MapNode) -> int:
	if n.type == STORY:
		return 1
	return 100 if n.type == MID_BOSS or n.type == BOSS else 0


func _test_type_rules() -> void:
	var types_seen := {}
	for map_seed in 120:
		var map := RouteMap.generate(map_seed, CHARACTERS[map_seed % 4])
		for act in 2:
			var rows := RouteMap.free_rows(act)
			_check(rows.size() == 12, "seed %d: act %d has 12 free rows" % [map_seed, act + 1])
			for i in rows.size():
				var fights := 0
				for n in map.row_nodes(rows[i]):
					types_seen[n.type] = true
					if n.type == FIGHT:
						fights += 1
					if i < 3:
						_check(n.type == FIGHT, "seed %d: free row %d of act %d is all fights" % [map_seed, i, act + 1])
					_check(n.type != ELITE, "seed %d: no elites with the default weights" % map_seed)
					if n.type == REST or n.type == SHOP:
						for p in n.prev:
							_check(map.node(p).type != n.type, "seed %d: %d does not follow its own type" % [map_seed, n.id])
				_check(fights >= 1, "seed %d: free row %d of act %d keeps a plain fight" % [map_seed, i, act + 1])
	_check(types_seen.has(FIGHT) and types_seen.has(REST) and types_seen.has(SHOP), "fights, rests and shops all occur")


func _window_has(map: RouteMap, rows: Array[int], start: int, window: int, type: RouteMap.NodeType) -> bool:
	for i in range(start, start + window):
		for n in map.row_nodes(rows[i]):
			if n.type == type:
				return true
	return false


func _test_availability() -> void:
	var rest_density := 0
	var shop_density := 0
	for map_seed in 320:
		var map := RouteMap.generate(map_seed, CHARACTERS[map_seed % 4])
		for act in 2:
			var rows := RouteMap.free_rows(act)
			# Windows only count free rows at or after the 3 safe rows.
			for start in range(3, rows.size() - 3):
				_check(_window_has(map, rows, start, 4, REST), "seed %d act %d: a rest within free rows %d to %d" % [map_seed, act + 1, start, start + 3])
			for start in range(3, rows.size() - 7):
				_check(_window_has(map, rows, start, 8, SHOP), "seed %d act %d: a shop within free rows %d to %d" % [map_seed, act + 1, start, start + 7])
		rest_density += map.count_of(REST)
		shop_density += map.count_of(SHOP)
		# The repair never forces a path: the rest or shop nodes are a minority of every row.
		for row in 30:
			var special := 0
			for n in map.row_nodes(row):
				if n.type == REST or n.type == SHOP:
					special += 1
			_check(special < map.row_nodes(row).size() or map.row_nodes(row).size() == 1 and map.row_nodes(row)[0].type != REST, "seed %d row %d: not every node is a rest or shop" % [map_seed, row])
	var rests_per_map := float(rest_density) / 320.0
	var shops_per_map := float(shop_density) / 320.0
	_check(rests_per_map > 14.0 and rests_per_map < 26.0, "rests per map in a sane range (%.1f)" % rests_per_map)
	_check(shops_per_map > 7.0 and shops_per_map < 16.0, "shops per map in a sane range (%.1f)" % shops_per_map)
	# Tight windows and few rolled rests and shops make the repair do the work; it must not undo the other window.
	var stress := {"type_weights": {"fight": 80.0, "rest": 3.0, "shop": 3.0}, "rest_window": 3, "shop_window": 3}
	var stress_bad := 0
	for map_seed in 150:
		if not RouteMap.generate(map_seed, CHARACTERS[map_seed % 4], stress).validate().is_empty():
			stress_bad += 1
	_check(stress_bad == 0, "tight windows that the repair has to fill all validate (%d bad)" % stress_bad)


func _test_enemy_counts() -> void:
	var bands := [[0, 7, 0.50, 0.40, 0.10], [8, 21, 0.25, 0.50, 0.25], [22, 29, 0.10, 0.40, 0.50]]
	var tallies: Array = [[0, 0, 0], [0, 0, 0], [0, 0, 0]]
	for map_seed in 300:
		var map := RouteMap.generate(map_seed, CHARACTERS[map_seed % 4])
		for n in map.nodes:
			match n.type:
				MID_BOSS, BOSS:
					_check(n.enemy_count == 1, "seed %d: a boss has 1 enemy" % map_seed)
				FIGHT:
					_check(n.enemy_count >= 1 and n.enemy_count <= Combat.MAX_ENEMIES, "seed %d: fight count in range" % map_seed)
					for b in bands.size():
						if n.row >= bands[b][0] and n.row <= bands[b][1]:
							tallies[b][n.enemy_count - 1] += 1
				_:
					_check(n.enemy_count == 0, "seed %d: a non-fight has 0 enemies" % map_seed)
	for b in bands.size():
		var total: int = tallies[b][0] + tallies[b][1] + tallies[b][2]
		_check(total > 2000, "band %d has plenty of samples (%d)" % [b, total])
		for c in 3:
			var share := float(tallies[b][c]) / float(maxi(total, 1))
			_check(absf(share - float(bands[b][2 + c])) < 0.04, "band %d: share of %d-enemy fights is %.3f, expected %.2f" % [b, c + 1, share, bands[b][2 + c]])


func _test_backdrops() -> void:
	var pool_keys := {}
	for map_seed in 500:
		for character in CHARACTERS:
			var map := RouteMap.generate(map_seed, character)
			var pool := RouteMap.backdrop_pool(character)
			if map_seed == 0:
				_check(pool.size() == 5 and pool.has(StringName("battle_" + String(character))) and pool.has(&"battle_neutral"), "%s pool: three shared keys, its own and neutral" % character)
				_check(not pool.has(&"battle_bell_court") and not pool.has(&"battle_threshold"), "%s pool excludes the boss backdrops" % character)
			var clean := true
			for n in map.nodes:
				if n.type == FIGHT or n.type == ELITE:
					pool_keys[n.backdrop] = true
					if not pool.has(n.backdrop) or n.backdrop == &"battle_bell_court" or n.backdrop == &"battle_threshold":
						clean = false
					if _fights_back(map, n.id).has(n.backdrop):
						clean = false
				elif n.type == MID_BOSS:
					clean = clean and n.backdrop == &"battle_bell_court"
				elif n.type == BOSS:
					clean = clean and n.backdrop == &"battle_threshold"
				else:
					clean = clean and n.backdrop == &""
			_check(clean, "seed %d %s: backdrops follow the no-repeat and pool rules" % [map_seed, character])
	_check(pool_keys.size() == 8, "every key of the three shared, four character and neutral backdrops gets used (%d)" % pool_keys.size())


func _test_unknown_characters() -> void:
	for odd in [&"", &"nobody", &"bell_court", &"threshold", &"Medium"]:
		var pool := RouteMap.backdrop_pool(odd)
		_check(pool.size() == 4 and pool.has(&"battle_neutral") and not pool.has(&"battle_bell_court") and not pool.has(&"battle_threshold"), "'%s' gets the four-key pool without a boss key" % odd)
		_check(not pool.has(StringName("battle_" + String(odd))) or odd == &"", "'%s' adds no key of its own" % odd)
		var bad := 0
		for map_seed in 120:
			var map := RouteMap.generate(map_seed, odd)
			if not map.validate().is_empty():
				bad += 1
		_check(bad == 0, "maps for the unknown character '%s' validate (%d bad)" % [odd, bad])


func _test_validate_accepts_generated() -> void:
	var bad := 0
	for map_seed in 200:
		var map := RouteMap.generate(map_seed, CHARACTERS[map_seed % 4], {"type_weights": {"elite": 10.0 if map_seed % 2 == 0 else 0.0}})
		if not map.validate().is_empty():
			bad += 1
	_check(bad == 0, "validate() is empty for generated maps (%d bad)" % bad)


func _test_validate_catches_corruption() -> void:
	var elite_config := {"type_weights": {"elite": 15.0}}
	var map := RouteMap.generate(3, &"deserter", elite_config)
	_check(map.validate().is_empty(), "the sample map is valid")
	var found_elite := false
	for n in map.nodes:
		found_elite = found_elite or n.type == ELITE
	_check(found_elite, "the sample map holds an elite")

	# A crossing: swap the exits of two neighbours until their edges cross.
	var crossed := _copy(map)
	var did_cross := false
	for row in range(4, 11):
		var left := crossed.row_nodes(row)[0]
		var right := crossed.row_nodes(row)[1]
		if left.next[0] < right.next[right.next.size() - 1]:
			var first: int = left.next[0]
			left.next = [right.next[right.next.size() - 1]]
			right.next = [first]
			did_cross = true
			break
	crossed.rebuild_links()
	_check(did_cross and _any_violation(crossed, "cross"), "a crossing edge is reported")

	var dead_end := _copy(map)
	dead_end.row_nodes(6)[0].next = []
	dead_end.rebuild_links()
	_check(_any_violation(dead_end, "no way forward"), "a dead end is reported")

	var orphan := _copy(map)
	var victim := orphan.row_nodes(7)[0]
	for n in orphan.row_nodes(6):
		n.next.erase(victim.id)
		if n.next.is_empty():
			n.next.append(orphan.row_nodes(7)[1].id)
	orphan.rebuild_links()
	_check(_any_violation(orphan, "no way in"), "a node nothing leads to is reported")

	var stale := _copy(map)
	stale.row_nodes(6)[0].prev = [9999]
	_check(_any_violation(stale, "prev list"), "a stale prev list is reported")

	var wide := _copy(map)
	var far := wide.row_nodes(8)[2].id
	wide.row_nodes(7)[0].next = [far]
	wide.rebuild_links()
	_check(_any_violation(wide, "more than one away"), "an edge more than one column away is reported")

	var three_exits := _copy(map)
	var hub := three_exits.row_nodes(9)[1]
	hub.next = [three_exits.row_nodes(10)[0].id, three_exits.row_nodes(10)[1].id, three_exits.row_nodes(10)[2].id]
	three_exits.rebuild_links()
	_check(_any_violation(three_exits, "exits, expected 1 or 2"), "three exits are reported")

	var partial_choke := _copy(map)
	partial_choke.row_nodes(13)[0].next.pop_back()
	partial_choke.rebuild_links()
	_check(not partial_choke.validate().is_empty(), "a choke row that skips a node is reported")

	var twin := _copy(map)
	var twin_id := -1
	for n in twin.nodes:
		if n.type == REST and not n.prev.is_empty() and twin.node(n.prev[0]).type == FIGHT:
			twin_id = n.prev[0]
			break
	_check(twin_id != -1, "setup: a rest with a fight in front")
	if twin_id != -1:
		twin.node(twin_id).type = REST
		_check(_any_violation(twin, "same type"), "a rest after a rest is reported")

	var early := _copy(map)
	early.row_nodes(2)[0].type = REST
	_check(_any_violation(early, "must be a fight"), "a rest in the first free rows is reported")

	var early_elite := _copy(map)
	early_elite.row_nodes(1)[0].type = ELITE
	early_elite.row_nodes(1)[0].enemy_count = 2
	_check(_any_violation(early_elite, "must be a fight"), "an elite in the first free rows is reported")

	var no_story := _copy(map)
	no_story.row_nodes(0)[0].type = FIGHT
	_check(_any_violation(no_story, "should be type"), "a missing story node is reported")

	var wrong_beat := _copy(map)
	wrong_beat.row_nodes(13)[0].beat_index = 3
	_check(_any_violation(wrong_beat, "story beat"), "a wrong story beat is reported")

	var second_boss := _copy(map)
	second_boss.row_nodes(14)[0].enemy_count = 2
	_check(_any_violation(second_boss, "must have 1 enemy"), "a boss with two enemies is reported")

	var ghost := _copy(map)
	for n in ghost.nodes:
		if n.type == STORY:
			n.enemy_count = 1
			break
	_check(_any_violation(ghost, "must have 0 enemies"), "enemies on a non-fight are reported")

	var lone_elite := _copy(map)
	for n in lone_elite.nodes:
		if n.type == ELITE:
			n.enemy_count = 1
			break
	_check(_any_violation(lone_elite, "elite"), "a lone elite is reported")

	var oversized := _copy(map)
	for n in oversized.nodes:
		if n.type == FIGHT:
			n.enemy_count = Combat.MAX_ENEMIES + 1
			break
	_check(_any_violation(oversized, "needs 1 to"), "too many enemies are reported")

	var no_rests := _copy(map)
	for n in no_rests.nodes:
		if n.type == REST and n.act == 0:
			n.type = FIGHT
	_check(_any_violation(no_rests, "hold no rest"), "an act without rests is reported")

	var no_shops := _copy(map)
	for n in no_shops.nodes:
		if n.type == SHOP:
			n.type = FIGHT
	_check(_any_violation(no_shops, "hold no shop"), "a map without shops is reported")

	var all_rest := _copy(map)
	for n in all_rest.row_nodes(10):
		n.type = REST
	_check(_any_violation(all_rest, "no plain fight"), "a row with no fight is reported")

	var repeat := _copy(map)
	var repeated := false
	for n in repeat.nodes:
		if n.type == FIGHT and not n.prev.is_empty() and repeat.node(n.prev[0]).type == FIGHT:
			n.backdrop = repeat.node(n.prev[0]).backdrop
			repeated = true
			break
	_check(repeated and _any_violation(repeat, "repeats backdrop"), "a repeated backdrop is reported")

	var through_rest := _copy(map)
	var walked := false
	for n in through_rest.nodes:
		if n.type != FIGHT:
			continue
		for p in n.prev:
			var rest_node := through_rest.node(p)
			if rest_node.type == REST:
				for q in rest_node.prev:
					if through_rest.node(q).type == FIGHT:
						n.backdrop = through_rest.node(q).backdrop
						walked = true
						break
			if walked:
				break
		if walked:
			break
	_check(walked and _any_violation(through_rest, "repeats backdrop"), "a backdrop repeated across a rest is reported")

	var boss_art := _copy(map)
	for n in boss_art.nodes:
		if n.type == FIGHT:
			n.backdrop = &"battle_bell_court"
			break
	_check(_any_violation(boss_art, "not in the pool"), "a boss backdrop in a regular fight is reported")

	var blank := _copy(map)
	for n in blank.nodes:
		if n.type == FIGHT:
			n.backdrop = &""
			break
	_check(_any_violation(blank, "not in the pool"), "a fight with no backdrop is reported")

	var wrong_mid := _copy(map)
	wrong_mid.row_nodes(14)[0].backdrop = &"battle_street"
	_check(_any_violation(wrong_mid, "must use"), "the mid-boss on the wrong backdrop is reported")

	var scenery := _copy(map)
	for n in scenery.nodes:
		if n.type == REST:
			n.backdrop = &"battle_street"
			break
	_check(_any_violation(scenery, "no backdrop"), "a backdrop on a rest is reported")

	var twice := _copy(map)
	var doubled := twice.row_nodes(6)[0]
	doubled.next.append(doubled.next[0])
	_check(_any_violation(twice, "twice"), "a duplicate edge in next is reported")

	var merged := _copy(map)
	var merge_hit := false
	for n in merged.nodes:
		if n.type != FIGHT or n.prev.size() < 2:
			continue
		var all_fights := true
		for p in n.prev:
			all_fights = all_fights and merged.node(p).type == FIGHT
		if all_fights:
			n.backdrop = merged.node(n.prev[n.prev.size() - 1]).backdrop
			merge_hit = true
			break
	_check(merge_hit and _any_violation(merged, "repeats backdrop"), "a repeat of the last of several predecessors' backdrops is reported")

	var choke := _copy(map)
	var choke_hit := false
	for n in choke.nodes:
		if n.type != STORY or n.row == 0 or n.row == 13:
			continue
		for before_id in n.prev:
			for after_id in n.next:
				var before := choke.node(before_id)
				var after := choke.node(after_id)
				if not choke_hit and before.type == FIGHT and after.type == FIGHT:
					after.backdrop = before.backdrop
					choke_hit = true
	_check(choke_hit and _any_violation(choke, "repeats backdrop"), "a backdrop repeated across the story row is reported")

	var alien := _copy(map)
	alien.kind = &"weird"
	_check(_any_violation(alien, "unknown map kind"), "an unknown kind is reported")

	var no_widths := _copy(map)
	no_widths.config["free_widths"] = []
	_check(_any_violation(no_widths, "free_widths"), "a config without free_widths is reported, not a crash")

	var tall := _copy(map)
	tall.nodes[5].row = 2000000000
	_check(not tall.validate().is_empty(), "an absurd row is reported without allocating rows")

	var empty := RouteMap.new()
	_check(not empty.validate().is_empty(), "an empty map is reported")


func _test_round_trip() -> void:
	for map_seed in 40:
		var map := RouteMap.generate(map_seed, CHARACTERS[map_seed % 4], {"type_weights": {"elite": 8.0}} if map_seed % 3 == 0 else {})
		var back := RouteMap.from_dict(map.to_dict())
		_check(back != null and JSON.stringify(back.to_dict()) == JSON.stringify(map.to_dict()), "seed %d: to_dict / from_dict round trip" % map_seed)
		var through_json := RouteMap.from_dict(JSON.parse_string(JSON.stringify(map.to_dict())))
		_check(through_json != null and JSON.stringify(through_json.to_dict()) == JSON.stringify(map.to_dict()), "seed %d: round trip through JSON" % map_seed)
		_check(through_json != null and through_json.validate().is_empty() and through_json.path_count() == map.path_count(), "seed %d: a restored map is valid and has the same paths" % map_seed)
		_check(through_json != null and through_json.character_id == map.character_id and through_json.seed_value == map.seed_value, "seed %d: seed and character survive" % map_seed)
	_check(RouteMap.from_dict({}) == null and RouteMap.from_dict({"nodes": [1]}) == null, "malformed data gives null")
	_check(RouteMap.from_dict({"nodes": [{"id": 0, "row": 0, "type": 99}]}) == null, "an unknown node type gives null")
	_check(RouteMap.from_dict({"nodes": [{"id": 0, "row": 0, "type": 0, "next": [5]}]}) == null, "an edge to a missing node gives null")


func _test_hostile_data() -> void:
	var good := RouteMap.generate(2, &"medium").to_dict()
	_check(RouteMap.from_dict(good) != null, "setup: the good data loads")
	_check(RouteMap.from_dict({"nodes": [{"id": 0, "row": 2000000000, "type": 0}]}) == null, "a huge row gives null")
	_check(RouteMap.from_dict({"kind": "line", "nodes": [{"id": 0, "row": 2000000000, "type": 0}]}) == null, "a huge row in a line map gives null")
	_check(RouteMap.from_dict({"nodes": [{"id": 0, "row": 30, "type": 0}]}) == null, "a row past the last of a generated map gives null")
	_check(RouteMap.from_dict({"nodes": [{"id": 0, "row": -1, "type": 0}]}) == null, "a negative row gives null")
	_check(RouteMap.from_dict({"nodes": [{"id": 0, "row": 0, "col": 99, "type": 0}]}) == null, "a huge column gives null")
	_check(RouteMap.from_dict({"nodes": [{"id": 0, "row": 0, "col": -1, "type": 0}]}) == null, "a negative column gives null")
	_check(RouteMap.from_dict({"nodes": [{"id": 0, "row": 0, "type": 0, "next": "1"}, {"id": 1, "row": 1, "type": 0}]}) == null, "a string next gives null")
	_check(RouteMap.from_dict({"nodes": [{"id": 0, "row": 0, "type": 0, "next": [0.5]}]}) == null, "a fractional edge gives null")
	_check(RouteMap.from_dict({"nodes": [{"id": 0, "row": 0, "type": "fight"}]}) == null, "a non-numeric type gives null")
	_check(RouteMap.from_dict({"nodes": [{"id": 0, "row": "0", "type": 0}]}) == null, "a string row gives null")
	_check(RouteMap.from_dict({"nodes": [{"id": "0", "row": 0, "type": 0}]}) == null, "a string id gives null")
	_check(RouteMap.from_dict({"nodes": [{"id": 0, "row": 0, "type": 0.5}]}) == null, "a fractional type gives null")
	_check(RouteMap.from_dict({"nodes": [{"id": 0, "row": 0, "type": true}]}) == null, "a boolean type gives null")
	var weird_kind: Dictionary = good.duplicate(true)
	weird_kind["kind"] = "weird"
	_check(RouteMap.from_dict(weird_kind) == null, "an unknown kind gives null")
	weird_kind["kind"] = 3
	_check(RouteMap.from_dict(weird_kind) == null, "a non-string kind gives null")
	var no_widths: Dictionary = good.duplicate(true)
	no_widths["config"]["free_widths"] = []
	_check(RouteMap.from_dict(no_widths) == null, "empty free_widths in the data gives null")
	var bad_weights: Dictionary = good.duplicate(true)
	bad_weights["config"]["type_weights"] = [1, 2]
	_check(RouteMap.from_dict(bad_weights) == null, "array type_weights in the data gives null")
	var bad_bands: Dictionary = good.duplicate(true)
	bad_bands["config"]["enemy_bands"] = {"a": 1}
	_check(RouteMap.from_dict(bad_bands) == null, "dictionary enemy_bands in the data gives null")
	var many := {"nodes": []}
	for i in RouteMap.MAX_NODES + 1:
		many["nodes"].append({"id": i, "row": 0, "type": 0})
	_check(RouteMap.from_dict(many) == null, "too many nodes give null")
	var twice: Dictionary = good.duplicate(true)
	twice["nodes"][3]["next"] = [twice["nodes"][3]["next"][0], twice["nodes"][3]["next"][0]]
	var doubled := RouteMap.from_dict(twice)
	_check(doubled != null and _any_violation(doubled, "twice"), "a duplicate edge loads but validate reports it")


func _test_from_line() -> void:
	var stops := RunState.new(1, &"deserter").stops
	var map := RouteMap.from_line(stops)
	_check(map.kind == RouteMap.KIND_LINE, "from_line makes a line map")
	_check(map.row_count() == 21 and map.node_count() == 21, "the line has 21 rows of one node")
	_check(map.validate().is_empty(), "the line map is valid (%s)" % str(map.validate()))
	_check(map.path_count() == 1 and map.all_paths().size() == 1, "the line has exactly one path")
	_check(map.starts() == [0] and map.finals() == [20], "the line starts at 0 and ends at 20")
	for i in stops.size():
		var stop: RunState.Stop = stops[i]
		var n := map.node(i)
		var expected: RouteMap.NodeType = FIGHT
		match stop.type:
			RunState.StopType.REST:
				expected = REST
			RunState.StopType.VENDOR:
				expected = SHOP
			RunState.StopType.STORY:
				expected = STORY
			_:
				expected = BOSS if stop.boss else (MID_BOSS if stop.mid_boss else FIGHT)
		_check(n.type == expected and n.row == i and n.col == 0, "stop %d keeps its type and row" % i)
		_check(n.enemy_count == (stop.enemy_count if stop.type == RunState.StopType.COMBAT else 0), "stop %d keeps its enemy count" % i)
		_check(n.act == stop.tier, "stop %d keeps its act" % i)
		if stop.type == RunState.StopType.STORY:
			_check(n.beat_index == stop.beat_index, "stop %d keeps its story beat" % i)
		_check(n.next == ([i + 1] if i < 20 else []) and n.prev == ([i - 1] if i > 0 else []), "stop %d links to its neighbours" % i)
	_check(map.count_of(STORY) == 4 and map.count_of(BOSS) == 1 and map.count_of(MID_BOSS) == 1, "the line has four beats and two bosses")
	_check(map.node(9).backdrop == &"battle_bell_court" and map.node(20).backdrop == &"battle_threshold" and map.node(1).backdrop == &"battle_street", "the line keeps its destination backdrops")
	var back := RouteMap.from_dict(map.to_dict())
	_check(back != null and back.kind == RouteMap.KIND_LINE and JSON.stringify(back.to_dict()) == JSON.stringify(map.to_dict()), "a line map survives the round trip")
	var broken := RouteMap.from_dict(map.to_dict())
	broken.node(20).enemy_count = 3
	_check(not broken.validate().is_empty(), "a broken line map is reported")


func _test_elite_config() -> void:
	var config := {"type_weights": {"elite": 12.0}}
	var elites := 0
	var elites_by_count := {}
	for map_seed in 150:
		var map := RouteMap.generate(map_seed, CHARACTERS[map_seed % 4], config)
		_check(map.validate().is_empty(), "seed %d: an elite map validates" % map_seed)
		for act in 2:
			var rows := RouteMap.free_rows(act)
			for i in rows.size():
				for n in map.row_nodes(rows[i]):
					if n.type != ELITE:
						continue
					elites += 1
					elites_by_count[n.enemy_count] = int(elites_by_count.get(n.enemy_count, 0)) + 1
					_check(i >= 3, "seed %d: an elite is never in the first 3 free rows" % map_seed)
					_check(n.enemy_count >= 2 and n.enemy_count <= Combat.MAX_ENEMIES, "seed %d: an elite has 2 or more enemies" % map_seed)
					_check(n.backdrop != &"" and n.backdrop != &"battle_bell_court", "seed %d: an elite has a regular backdrop" % map_seed)
					for p in n.prev:
						_check(map.node(p).type != ELITE, "seed %d: an elite does not follow an elite" % map_seed)
	_check(elites > 150, "elites turn up when weighted (%d)" % elites)
	_check(not elites_by_count.has(1) and elites_by_count.has(2) and elites_by_count.has(3), "elite sizes are 2 and 3 only")
	var plain := RouteMap.generate(4, &"deserter")
	_check(plain.count_of(ELITE) == 0, "no elites with the default weights")


func _test_config_merge() -> void:
	var cfg := RouteMap.make_config({"type_weights": {"elite": 5.0}, "rest_window": 5})
	_check(float(cfg["type_weights"]["elite"]) == 5.0 and float(cfg["type_weights"]["fight"]) == 26.0 and int(cfg["rest_window"]) == 5, "make_config merges over the defaults")
	_check(float(RouteMap.CONFIG["type_weights"]["elite"]) == 0.0, "the CONFIG constant is not changed by a merge")
	var loose := RouteMap.generate(11, &"thief", {"rest_window": 5, "shop_window": 8})
	_check(loose.validate().is_empty(), "a looser availability window still validates")
	var rows := RouteMap.free_rows(0)
	var ok := true
	for start in range(0, rows.size() - 4):
		ok = ok and _window_has(loose, rows, start, 5, REST)
	_check(ok, "a rest window of 5 is honoured")


func _test_config_shapes() -> void:
	var defaults := JSON.stringify(RouteMap.generate(9, &"thief").to_dict())
	for bad in [
		{"free_widths": []}, {"free_widths": "34"}, {"free_widths": [3, 6]}, {"free_widths": [1]}, {"free_widths": [3.5]},
		{"type_weights": [1, 2]}, {"type_weights": "x"}, {"type_weights": {"fight": "a"}}, {"type_weights": {"rest": -4}},
		{"enemy_bands": {"max_row": 3}}, {"enemy_bands": []}, {"enemy_bands": [{"max_row": 5}]}, {"enemy_bands": [3]},
		{"safe_rows": -1}, {"safe_rows": "3"}, {"rest_window": 99}, {"extra_edge_chance": 2.0}, {"extra_edge_chance": null},
	]:
		var map := RouteMap.generate(9, &"thief", bad)
		_check(map.validate().is_empty(), "a malformed config %s does not break generation" % str(bad))
		_check(JSON.stringify(map.to_dict()) == defaults, "a malformed config %s falls back to the defaults" % str(bad))
		_check(not RouteMap.config_problems(bad).is_empty(), "config_problems flags %s" % str(bad))
	_check(RouteMap.config_problems({"free_widths": [4, 5], "rest_window": 5}).is_empty(), "good overrides raise no config problem")
	var wide := RouteMap.generate(4, &"stray", {"free_widths": [4, 5]})
	_check(wide.validate().is_empty() and wide.row_nodes(1).size() >= 4, "a wider layout is honoured and valid")
	var narrow := RouteMap.generate(4, &"stray", {"free_widths": [2, 3]})
	_check(narrow.validate().is_empty(), "a narrower layout is valid")


## The node mix over the free nodes of many maps, with the default weights: about 63% fights, 24% rests and
## 13% shops (docs/MAP_DESIGN.md has the measured numbers). A random path takes about 15 fights, 5 rests, 3 shops.
func _test_node_mix() -> void:
	var counts := {FIGHT: 0, REST: 0, SHOP: 0, ELITE: 0}
	var free_total := 0
	var path_rests := 0
	var path_shops := 0
	var path_fights := 0
	var walks := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for map_seed in 400:
		var map := RouteMap.generate(map_seed, CHARACTERS[map_seed % 4])
		for n in map.nodes:
			if n.type in counts and RouteMap.row_info(n.row)["type"] == RouteMap.FREE_ROW:
				counts[n.type] += 1
				free_total += 1
		var id: int = map.starts()[0]
		while true:
			var here := map.node(id)
			path_fights += 1 if here.type == FIGHT else 0
			path_rests += 1 if here.type == REST else 0
			path_shops += 1 if here.type == SHOP else 0
			if here.next.is_empty():
				break
			id = here.next[rng.randi_range(0, here.next.size() - 1)]
		walks += 1
	var fight_share := float(counts[FIGHT]) / free_total
	var rest_share := float(counts[REST]) / free_total
	var shop_share := float(counts[SHOP]) / free_total
	_check(fight_share > 0.58 and fight_share < 0.68, "fights are about 63%% of free nodes (%.3f)" % fight_share)
	_check(rest_share > 0.20 and rest_share < 0.28, "rests are about 24%% of free nodes (%.3f)" % rest_share)
	_check(shop_share > 0.10 and shop_share < 0.16, "shops are about 13%% of free nodes (%.3f)" % shop_share)
	_check(counts[ELITE] == 0, "no elites by default")
	var fights_per_path := float(path_fights) / walks
	var rests_per_path := float(path_rests) / walks
	var shops_per_path := float(path_shops) / walks
	_check(fights_per_path > 13.5 and fights_per_path < 17.5, "a random path has about 15 fights (%.2f)" % fights_per_path)
	_check(rests_per_path > 4.0 and rests_per_path < 7.0, "a random path has about 5 rests (%.2f)" % rests_per_path)
	_check(shops_per_path > 2.0 and shops_per_path < 4.2, "a random path has about 3 shops (%.2f)" % shops_per_path)
