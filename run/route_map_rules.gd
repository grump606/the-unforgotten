class_name RouteMapRules
extends RefCounted
## The rules a RouteMap must follow, as checks: `validate(map)` (what RouteMap.validate forwards to) lists every broken
## map rule, and `config_problems` / `config_problem` say what is wrong with a config dictionary (RouteConfig and
## RouteMap.from_dict use them and `is_whole`). Static and read-only: the map is passed in and never changed. Uses only
## RouteMap's public surface (its data fields, layout helpers and `recent_backdrops`).


## Every broken rule, as readable strings; empty when the map is valid. A "line" map is only checked for
## graph shape and enemy counts (it is not meant to follow the generated layout).
static func validate(map: RouteMap) -> Array[String]:
	var v: Array[String] = []
	var nodes := map.nodes
	if map.kind != RouteMap.KIND_GENERATED and map.kind != RouteMap.KIND_LINE:
		v.append("unknown map kind '%s'" % map.kind)
		return v
	if nodes.is_empty():
		v.append("map has no nodes")
		return v
	for i in nodes.size():
		if nodes[i].id != i:
			v.append("node at index %d has id %d" % [i, nodes[i].id])
	if not v.is_empty():
		return v
	var rows := _rows_from_nodes(map, v)
	if not v.is_empty():
		return v
	var preds := _check_graph(map, v, rows)
	if not v.is_empty():
		return v
	if map.kind == RouteMap.KIND_GENERATED:
		_check_layout(map, v, rows)
		if not v.is_empty():
			return v
		_check_edges(map, v, rows)
		_check_types(map, v, rows, preds)
		_check_rest_rules(map, v, rows, preds)
		_check_availability(map, v, rows)
		_check_rest_before_bosses(map, v, rows)
		_check_backdrops(map, v)
	_check_counts(map, v)
	return v


static func _describe(n: RouteMap.MapNode) -> String:
	return "node %d (row %d, col %d)" % [n.id, n.row, n.col]


## Groups the nodes by their `row` field into columns order; reports gaps and column mismatches.
static func _rows_from_nodes(map: RouteMap, v: Array[String]) -> Array:
	var nodes := map.nodes
	var rows: Array = []
	var highest := -1
	for n in nodes:
		if n.row < 0:
			v.append("%s has a negative row" % _describe(n))
			return rows
		highest = maxi(highest, n.row)
	if highest >= nodes.size():
		v.append("a node sits in row %d, but there are only %d nodes" % [highest, nodes.size()])
		return rows
	for r in highest + 1:
		rows.append([])
	for n in nodes:
		rows[n.row].append(n.id)
	for r in rows.size():
		if rows[r].is_empty():
			v.append("row %d is empty" % r)
			continue
		for i in rows[r].size():
			if nodes[rows[r][i]].col != i:
				v.append("row %d: columns are not 0..%d in order" % [r, rows[r].size() - 1])
				break
	return rows


## Graph shape shared by every kind of map. Returns each node's predecessors as derived from `next`.
static func _check_graph(map: RouteMap, v: Array[String], rows: Array) -> Array:
	var nodes := map.nodes
	var preds: Array = []
	for n in nodes:
		preds.append([])
	for n in nodes:
		var seen := {}
		for nxt in n.next:
			if nxt < 0 or nxt >= nodes.size() or nodes[nxt].row != n.row + 1:
				v.append("%s has an edge to %d, which is not in the next row" % [_describe(n), nxt])
				continue
			if seen.has(nxt):
				v.append("%s lists the edge to %d twice" % [_describe(n), nxt])
				continue
			seen[nxt] = true
			preds[nxt].append(n.id)
	if not v.is_empty():
		return preds
	for n in nodes:
		var derived: Array = preds[n.id].duplicate()
		derived.sort()
		var stored: Array = n.prev.duplicate()
		stored.sort()
		if derived != stored:
			v.append("%s has a prev list that does not match the edges" % _describe(n))
		if n.row < rows.size() - 1 and n.next.is_empty():
			v.append("%s has no way forward" % _describe(n))
		if n.row > 0 and preds[n.id].is_empty():
			v.append("%s has no way in" % _describe(n))
	if not v.is_empty():
		return preds
	# Every node must be reachable from the start and reach the end.
	var forward := {}
	var frontier: Array = rows[0].duplicate()
	for id in frontier:
		forward[id] = true
	while not frontier.is_empty():
		var id: int = frontier.pop_back()
		for nxt in nodes[id].next:
			if not forward.has(nxt):
				forward[nxt] = true
				frontier.append(nxt)
	var backward := {}
	frontier = rows[rows.size() - 1].duplicate()
	for id in frontier:
		backward[id] = true
	while not frontier.is_empty():
		var id: int = frontier.pop_back()
		for p in preds[id]:
			if not backward.has(p):
				backward[p] = true
				frontier.append(p)
	for n in nodes:
		if not forward.has(n.id):
			v.append("%s cannot be reached from the start" % _describe(n))
		if not backward.has(n.id):
			v.append("%s cannot reach the final boss" % _describe(n))
	var last: Array = rows[rows.size() - 1]
	if last.size() != 1 or nodes[last[0]].type != RouteMap.NodeType.BOSS:
		v.append("the last row must be a single boss node")
	return preds


static func _check_layout(map: RouteMap, v: Array[String], rows: Array) -> void:
	var nodes := map.nodes
	if rows.size() != RouteMap.ROWS:
		v.append("map has %d rows, expected %d" % [rows.size(), RouteMap.ROWS])
		return
	var widths := map.config.free_widths
	if widths.is_empty():
		v.append("config has no free_widths")
		return
	var min_width: int = widths.min()
	var max_width: int = widths.max()
	for r in RouteMap.ROWS:
		var info := RouteMap.row_info(r)
		var ids: Array = rows[r]
		var row_type: int = info["type"]
		if row_type == RouteMap.FREE_ROW:
			if bool(info["treasure"]):
				for id in ids:
					if nodes[id].type != RouteMap.NodeType.TREASURE:
						v.append("%s is in the forced treasure row and must be a treasure" % _describe(nodes[id]))
			elif bool(info["forced"]):
				for id in ids:
					if nodes[id].type != RouteMap.NodeType.REST:
						v.append("%s is in the forced rest row and must be a rest" % _describe(nodes[id]))
			elif r % RouteMap.ACT_ROWS == RouteMap.FORCED_REST_ROW - 1:
				for id in ids:
					if nodes[id].type == RouteMap.NodeType.REST:
						v.append("%s is in the row before the forced rest row and may not be a rest" % _describe(nodes[id]))
			if ids.size() < min_width or ids.size() > max_width:
				v.append("free row %d has %d nodes, expected %d to %d" % [r, ids.size(), min_width, max_width])
			for id in ids:
				var t := nodes[id].type
				if bool(info["treasure"]):
					if t != RouteMap.NodeType.TREASURE:
						v.append("%s has type %d, but the treasure row holds only treasure" % [_describe(nodes[id]), t])
				elif t != RouteMap.NodeType.FIGHT and t != RouteMap.NodeType.ELITE and t != RouteMap.NodeType.REST and t != RouteMap.NodeType.SHOP and t != RouteMap.NodeType.EVENT:
					v.append("%s has type %d, which does not belong in a free row" % [_describe(nodes[id]), t])
				if nodes[id].act != info["act"]:
					v.append("%s is in the wrong act" % _describe(nodes[id]))
			continue
		if ids.size() != 1:
			v.append("choke row %d has %d nodes, expected 1" % [r, ids.size()])
			continue
		var n := nodes[ids[0]]
		if n.type != row_type:
			v.append("%s should be type %d" % [_describe(n), row_type])
		if n.act != info["act"]:
			v.append("%s is in the wrong act" % _describe(n))
		if row_type == RouteMap.NodeType.STORY and n.beat_index != info["beat"]:
			v.append("%s should be story beat %d, not %d" % [_describe(n), info["beat"], n.beat_index])


static func _check_edges(map: RouteMap, v: Array[String], rows: Array) -> void:
	var nodes := map.nodes
	for r in range(rows.size() - 1):
		var upper: Array = rows[r]
		var lower: Array = rows[r + 1]
		if upper.size() == 1 or lower.size() == 1:
			for id in upper:
				var got: Array = nodes[id].next.duplicate()
				got.sort()
				if got != lower:
					v.append("%s must connect to every node of row %d" % [_describe(nodes[id]), r + 1])
			continue
		var edges: Array[Vector2i] = []
		for id in upper:
			var n := nodes[id]
			if n.next.size() < 1 or n.next.size() > 2:
				v.append("%s has %d exits, expected 1 or 2" % [_describe(n), n.next.size()])
			for nxt in n.next:
				if absi(nodes[nxt].col - n.col) > 1:
					v.append("%s has an edge to column %d, more than one away" % [_describe(n), nodes[nxt].col])
				edges.append(Vector2i(n.col, nodes[nxt].col))
		for i in edges.size():
			for j in range(i + 1, edges.size()):
				if (edges[i].x < edges[j].x and edges[i].y > edges[j].y) or (edges[i].x > edges[j].x and edges[i].y < edges[j].y):
					v.append("rows %d and %d: edges %s and %s cross" % [r, r + 1, edges[i], edges[j]])


static func _check_types(map: RouteMap, v: Array[String], rows: Array, preds: Array) -> void:
	var nodes := map.nodes
	var safe := map.config.safe_rows
	for r in rows.size():
		var info := RouteMap.row_info(r)
		if int(info["type"]) != RouteMap.FREE_ROW or bool(info["forced"]) or bool(info["treasure"]):
			continue
		var plain_fights := 0
		for id in rows[r]:
			var n := nodes[id]
			if n.type == RouteMap.NodeType.FIGHT:
				plain_fights += 1
			if int(info["free"]) < safe and n.type != RouteMap.NodeType.FIGHT:
				v.append("%s is within the first %d free rows of its act and must be a fight" % [_describe(n), safe])
			if n.type == RouteMap.NodeType.REST or n.type == RouteMap.NodeType.SHOP or n.type == RouteMap.NodeType.ELITE or n.type == RouteMap.NodeType.EVENT:
				for p in preds[id]:
					if nodes[p].type == n.type:
						v.append("%s follows a node of the same type (%d)" % [_describe(n), n.type])
						break
		if plain_fights == 0:
			v.append("free row %d has no plain fight" % r)


## The rest rules: no rest right after a shop or a chest, no shop right after a rest, no chest right after a rest,
## and no path with more than RouteMap.MAX_PATH_RESTS ordinary rests in an act.
static func _check_rest_rules(map: RouteMap, v: Array[String], rows: Array, preds: Array) -> void:
	var nodes := map.nodes
	var counts := {}
	for r in rows.size():
		for id in rows[r]:
			var n := nodes[id]
			var before := 0
			if r % RouteMap.ACT_ROWS != 0:
				for p in preds[id]:
					before = maxi(before, counts.get(p, 0))
					var from_type := nodes[p].type
					if n.type == RouteMap.NodeType.REST and (from_type == RouteMap.NodeType.SHOP or from_type == RouteMap.NodeType.TREASURE):
						v.append("%s follows a %s" % [_describe(n), "shop" if from_type == RouteMap.NodeType.SHOP else "chest"])
					elif (n.type == RouteMap.NodeType.SHOP or n.type == RouteMap.NodeType.TREASURE) and from_type == RouteMap.NodeType.REST:
						v.append("%s follows a rest" % _describe(n))
			var own := 1 if n.type == RouteMap.NodeType.REST and not bool(RouteMap.row_info(r)["forced"]) else 0
			counts[id] = before + own
			if before + own > RouteMap.MAX_PATH_RESTS:
				v.append("%s is the %dth ordinary rest on a path in its act (at most %d)" % [_describe(n), before + own, RouteMap.MAX_PATH_RESTS])


static func _check_availability(map: RouteMap, v: Array[String], rows_by_number: Array) -> void:
	var nodes := map.nodes
	var safe := map.config.safe_rows
	for pair in [[RouteMap.NodeType.REST, map.config.rest_window, "rest"], [RouteMap.NodeType.SHOP, map.config.shop_window, "shop"]]:
		var window: int = pair[1]
		if window <= 0:
			continue
		for act in RouteMap.ACTS:
			var rows := RouteMap.window_rows(act)
			for start in range(safe, RouteMap.window_last_index(pair[0], rows.size()) - window + 2):
				var present := false
				for i in range(start, start + window):
					for id in rows_by_number[rows[i]]:
						if nodes[id].type == pair[0]:
							present = true
				if not present:
					v.append("act %d: free rows %d to %d hold no %s" % [act + 1, start, start + window - 1, pair[2]])


## Every path passes a rest between the start (or the previous boss) and each boss. The forced rest row makes
## this true; the check is by path, so it also catches a rest row that some edge routes around.
static func _check_rest_before_bosses(map: RouteMap, v: Array[String], rows: Array) -> void:
	var nodes := map.nodes
	var covered := {}
	for row in rows:
		for id in row:
			var n := nodes[id]
			var all_rest := not n.prev.is_empty()
			for p in n.prev:
				if not covered.get(p, false):
					all_rest = false
					break
			if n.is_boss():
				if not all_rest:
					v.append("%s can be reached on a path with no rest since the start or the last boss" % _describe(n))
				covered[id] = false
			else:
				covered[id] = n.type == RouteMap.NodeType.REST or all_rest


static func _check_counts(map: RouteMap, v: Array[String]) -> void:
	var nodes := map.nodes
	for n in nodes:
		match n.type:
			RouteMap.NodeType.MID_BOSS, RouteMap.NodeType.BOSS:
				if n.enemy_count != 1:
					v.append("%s is a boss and must have 1 enemy, not %d" % [_describe(n), n.enemy_count])
			RouteMap.NodeType.ELITE:
				if n.enemy_count < 2 or n.enemy_count > Combat.MAX_ENEMIES:
					v.append("%s is an elite and needs 2 to %d enemies, not %d" % [_describe(n), Combat.MAX_ENEMIES, n.enemy_count])
			RouteMap.NodeType.FIGHT:
				if n.enemy_count < 1 or n.enemy_count > Combat.MAX_ENEMIES:
					v.append("%s is a fight and needs 1 to %d enemies, not %d" % [_describe(n), Combat.MAX_ENEMIES, n.enemy_count])
			_:
				if n.enemy_count != 0:
					v.append("%s is not a fight and must have 0 enemies, not %d" % [_describe(n), n.enemy_count])


static func _check_backdrops(map: RouteMap, v: Array[String]) -> void:
	var nodes := map.nodes
	var pool := RouteMap.backdrop_pool(map.character_id, map.chapter)
	var memo := {}
	for n in nodes:
		if n.type == RouteMap.NodeType.MID_BOSS:
			if n.backdrop != Chapters.chapter(map.chapter).mid_boss_backdrop:
				v.append("%s must use %s" % [_describe(n), Chapters.chapter(map.chapter).mid_boss_backdrop])
		elif n.type == RouteMap.NodeType.BOSS:
			if n.backdrop != Chapters.chapter(map.chapter).boss_backdrop:
				v.append("%s must use %s" % [_describe(n), Chapters.chapter(map.chapter).boss_backdrop])
		elif n.type == RouteMap.NodeType.FIGHT or n.type == RouteMap.NodeType.ELITE:
			if not pool.has(n.backdrop):
				v.append("%s uses backdrop '%s', which is not in the pool" % [_describe(n), n.backdrop])
				continue
			for p in n.prev:
				if map.recent_backdrops(p, memo).has(n.backdrop):
					v.append("%s repeats backdrop %s from the most recent fight on a path into it" % [_describe(n), n.backdrop])
					break
		elif n.backdrop != &"":
			v.append("%s is not a fight and must have no backdrop" % _describe(n))


# --- Config shape ---------------------------------------------------------------------------------------

## What is wrong with the shape of a config dictionary (empty when `RouteMap.make_config` would use all of it).
## Unknown keys are not a problem; they are ignored.
static func config_problems(overrides: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	for key in overrides:
		var name := str(key)
		if RouteMap.CONFIG.has(name):
			var problem := config_problem(name, overrides[key])
			if problem != "":
				problems.append(problem)
	return problems


static func _is_number(value: Variant) -> bool:
	return value is int or (value is float and is_finite(value))


## True for a finite number with no fractional part between `low` and `high` inclusive.
static func is_whole(value: Variant, low: float, high: float) -> bool:
	return _is_number(value) and float(value) >= low and float(value) <= high and float(value) == floorf(float(value))


static func weight_ok(value: Variant) -> bool:
	return _is_number(value) and float(value) >= 0.0 and float(value) <= 1.0e9


static func config_problem(key: String, value: Variant) -> String:
	match key:
		"type_weights":
			if not value is Dictionary:
				return "type_weights must be a dictionary"
			for type_key in value:
				if not RouteMap.TYPE_KEYS.has(str(type_key)) or not weight_ok(value[type_key]):
					return "type_weights has a bad entry '%s'" % str(type_key)
		"enemy_bands":
			if not value is Array or value.is_empty():
				return "enemy_bands must be a non-empty array"
			for band in value:
				if not band is Dictionary or not is_whole(band.get("max_row"), 0, 1000) or not band.get("weights") is Array or band["weights"].is_empty():
					return "enemy_bands holds a band without a whole max_row and a non-empty weights array"
				for weight in band["weights"]:
					if not weight_ok(weight):
						return "enemy_bands holds a bad weight"
		"free_widths":
			if not value is Array or value.is_empty():
				return "free_widths must be a non-empty array"
			var low := 1000000
			var high := -1
			for width in value:
				if not is_whole(width, 2, RouteMap.MAX_WIDTH):
					return "free_widths entries must be whole numbers from 2 to %d" % RouteMap.MAX_WIDTH
				low = mini(low, int(width))
				high = maxi(high, int(width))
			if high - low > 1:
				return "free_widths must differ by at most 1 so neighbouring rows can connect"
		"safe_rows", "rest_window", "shop_window":
			if not is_whole(value, 0, RouteMap.ACT_ROWS):
				return "%s must be a whole number from 0 to %d" % [key, RouteMap.ACT_ROWS]
		"extra_edge_chance":
			if not _is_number(value) or float(value) < 0.0 or float(value) > 1.0:
				return "extra_edge_chance must be a number from 0 to 1"
	return ""
