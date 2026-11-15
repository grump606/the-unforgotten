class_name RouteMapGenerator
extends RefCounted
## Builds RouteMaps: `generate` (the seeded map of docs/MAP_DESIGN.md) and `from_line` (the old stop line as a map).
## RouteMap.generate and RouteMap.from_line forward here; callers keep using those. One generator instance builds one
## attempt: it holds the map being filled and its node ids by row while the passes run, then the map rebuilds its own
## rows. Uses only RouteMap's public surface (its data fields, layout helpers, `recent_backdrops` and `rebuild_rows`);
## RouteMap depends on this script only through those two forwarding calls.

## The map being built and the parts of it every pass reads (the same arrays and config the map holds).
var map: RouteMap
var nodes: Array[RouteMap.MapNode]
var config: RouteMap.RouteConfig
var chapter: int
var character_id: StringName
## Node ids by row, in column order, as the passes create them.
var _rows: Array = []


func _init(p_map: RouteMap) -> void:
	map = p_map
	nodes = p_map.nodes
	config = p_map.config
	chapter = p_map.chapter
	character_id = p_map.character_id


## See RouteMap.generate: same arguments, same map; uses its own RNG only. If no attempt validates, the last map is
## returned with an engine error, so a caller that checks `validate()` sees what is wrong.
static func generate(map_seed: int, char_id: StringName, overrides: Dictionary = {}, chapter_number: int = 1) -> RouteMap:
	var cfg := RouteMap.make_config(overrides)
	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed
	var map: RouteMap = null
	var problems: Array[String] = []
	for attempt in RouteMap.MAX_ATTEMPTS:
		map = _build(rng, map_seed, char_id, cfg, chapter_number)
		problems = map.validate()
		if problems.is_empty():
			return map
	# engine_error, not push_error: the sim tools count these and exit non-zero (a broken map must not pass silently).
	Combat.engine_error("RouteMap.generate: seed %d (%s) still breaks %d rule(s) after %d attempts, first: %s" % [map_seed, char_id, problems.size(), RouteMap.MAX_ATTEMPTS, problems[0]])
	return map


static func _build(rng: RandomNumberGenerator, map_seed: int, char_id: StringName, cfg: RouteMap.RouteConfig, chapter_number: int = 1) -> RouteMap:
	var map := RouteMap.new()
	map.chapter = chapter_number
	map.seed_value = map_seed
	map.character_id = char_id
	map.kind = RouteMap.KIND_GENERATED
	map.config = cfg.copy()
	var gen := RouteMapGenerator.new(map)
	gen._make_nodes(rng)
	gen._make_edges(rng)
	gen._assign_types(rng)
	gen._assign_counts(rng)
	gen._assign_backdrops(rng)
	map.rebuild_rows()
	return map


func _make_nodes(rng: RandomNumberGenerator) -> void:
	var widths := config.free_widths
	for row in RouteMap.ROWS:
		var info := RouteMap.row_info(row)
		var row_type: int = info["type"]
		var width := 1
		if row_type == RouteMap.FREE_ROW:
			width = int(widths[rng.randi_range(0, widths.size() - 1)])
		var ids: Array[int] = []
		for col in width:
			var n := RouteMap.MapNode.new(nodes.size(), row, col, RouteMap.NodeType.FIGHT if row_type == RouteMap.FREE_ROW else row_type as RouteMap.NodeType)
			n.act = info["act"]
			if row_type == RouteMap.NodeType.STORY:
				n.beat_index = info["beat"]
			elif row_type == RouteMap.NodeType.MID_BOSS:
				n.enemy_count = 1
				n.backdrop = Chapters.chapter(chapter).mid_boss_backdrop
			elif row_type == RouteMap.NodeType.BOSS:
				n.enemy_count = 1
				n.backdrop = Chapters.chapter(chapter).boss_backdrop
			nodes.append(n)
			ids.append(n.id)
		_rows.append(ids)


func _link(from_id: int, to_id: int) -> void:
	nodes[from_id].next.append(to_id)
	nodes[to_id].prev.append(from_id)


func _make_edges(rng: RandomNumberGenerator) -> void:
	var extra_chance := config.extra_edge_chance
	for row in range(RouteMap.ROWS - 1):
		var upper: Array = _rows[row]
		var lower: Array = _rows[row + 1]
		if upper.size() == 1 or lower.size() == 1:
			for from_id in upper:
				for to_id in lower:
					_link(from_id, to_id)
		else:
			for edge in _free_edges(rng, extra_chance, upper.size(), lower.size()):
				_link(upper[edge.x], lower[edge.y])
	for n in nodes:
		n.next.sort()
		n.prev.sort()


## Edges between two free rows of `a` and `b` nodes as (upper column, lower column) pairs: a random
## monotone staircase from the first columns to the last (so nothing crosses, every node has an edge each
## way and columns stay within one), then second exits added at random.
static func _free_edges(rng: RandomNumberGenerator, extra_chance: float, a: int, b: int) -> Array[Vector2i]:
	var diagonal := Vector2i(1, 1)
	var moves: Array[Vector2i] = [diagonal, diagonal, Vector2i(1, 0), Vector2i(0, 1)]
	var edges: Array[Vector2i] = []
	for attempt in 50:
		edges = [Vector2i(0, 0)]
		var at := Vector2i(0, 0)
		var last := diagonal
		var stuck := false
		while at != Vector2i(a - 1, b - 1):
			var options: Array[Vector2i] = []
			for move in moves:
				var to := at + move
				# A repeated single-axis move would give a node a third exit or entrance.
				if to.x <= a - 1 and to.y <= b - 1 and absi(to.x - to.y) <= 1 and (move == diagonal or move != last):
					options.append(move)
			if options.is_empty():
				stuck = true
				break
			var step := options[rng.randi_range(0, options.size() - 1)]
			at += step
			last = step
			edges.append(at)
		if not stuck:
			break
		edges = []
	if edges.is_empty():
		# Unreachable for rows whose widths differ by at most one, but never leave a map unlinked.
		var at := Vector2i(0, 0)
		edges.append(at)
		while at != Vector2i(a - 1, b - 1):
			at += Vector2i(1 if at.x < a - 1 else 0, 1 if at.y < b - 1 else 0)
			edges.append(at)
	var out_degree := PackedInt32Array()
	var in_degree := PackedInt32Array()
	out_degree.resize(a)
	in_degree.resize(b)
	for edge in edges:
		out_degree[edge.x] += 1
		in_degree[edge.y] += 1
	for col in a:
		if out_degree[col] != 1 or rng.randf() >= extra_chance:
			continue
		var candidates: Array[Vector2i] = []
		for target in range(maxi(col - 1, 0), mini(col + 1, b - 1) + 1):
			var candidate := Vector2i(col, target)
			if edges.has(candidate) or in_degree[target] >= 2:
				continue
			var crosses := false
			for edge in edges:
				if (candidate.x < edge.x and candidate.y > edge.y) or (candidate.x > edge.x and candidate.y < edge.y):
					crosses = true
					break
			if not crosses:
				candidates.append(candidate)
		if not candidates.is_empty():
			var added := candidates[rng.randi_range(0, candidates.size() - 1)]
			edges.append(added)
			out_degree[added.x] += 1
			in_degree[added.y] += 1
	return edges


## Index of a weighted random pick, or -1 when no weight is positive.
static func _pick_weighted(rng: RandomNumberGenerator, weights: Array) -> int:
	var total := 0.0
	for weight in weights:
		total += maxf(float(weight), 0.0)
	if total <= 0.0:
		return -1
	var roll := rng.randf() * total
	for i in weights.size():
		roll -= maxf(float(weights[i]), 0.0)
		if roll < 0.0:
			return i
	# Rounding at the very top of the range: take the last positive weight.
	for i in range(weights.size() - 1, -1, -1):
		if float(weights[i]) > 0.0:
			return i
	return -1


func _neighbour_has(n: RouteMap.MapNode, type: RouteMap.NodeType, use_prev: bool, use_next: bool) -> bool:
	if use_prev:
		for id in n.prev:
			if nodes[id].type == type:
				return true
	if use_next:
		for id in n.next:
			if nodes[id].type == type:
				return true
	return false


## True if the row after `row` is the act's forced treasure row (every node in it is a chest).
func _next_row_is_treasure(row: int) -> bool:
	return row + 1 < RouteMap.ROWS and bool(RouteMap.row_info(row + 1)["treasure"])


## The most ordinary rests (see RouteMap.MAX_PATH_RESTS) on any path from the start of the act up to and including node
## `id`. The forced rest row does not count. Looks only at nodes already typed, so call it for incoming
## neighbours while generating.
func _path_rests(id: int, memo: Dictionary = {}) -> int:
	if memo.has(id):
		return memo[id]
	var n := nodes[id]
	var before := 0
	if n.row % RouteMap.ACT_ROWS != 0:
		for p in n.prev:
			before = maxi(before, _path_rests(p, memo))
	var own := 1 if n.type == RouteMap.NodeType.REST and not bool(RouteMap.row_info(n.row)["forced"]) else 0
	memo[id] = before + own
	return before + own


## Whether node `n`, whose incoming neighbours are already typed, may become `type` (the later rows are not rolled yet,
## so only what comes before it and what is fixed after it counts). A rest, shop, event or elite may not follow a
## node of its own type. A rest may not follow a shop or a chest, nor sit in the row before the forced rest row or
## before the chest row; a shop may not follow a rest nor sit in the row before the forced rest row; and no path may
## pass more than RouteMap.MAX_PATH_RESTS ordinary rests in an act.
func _type_allowed(n: RouteMap.MapNode, type: RouteMap.NodeType) -> bool:
	var local := n.row % RouteMap.ACT_ROWS
	match type:
		RouteMap.NodeType.REST:
			if local == RouteMap.FORCED_REST_ROW - 1 or _next_row_is_treasure(n.row):
				return false
			if _neighbour_has(n, RouteMap.NodeType.REST, true, false) or _neighbour_has(n, RouteMap.NodeType.SHOP, true, false) or _neighbour_has(n, RouteMap.NodeType.TREASURE, true, false):
				return false
			var memo := {}
			for p in n.prev:
				if local != 0 and _path_rests(p, memo) >= RouteMap.MAX_PATH_RESTS:
					return false
		RouteMap.NodeType.SHOP:
			if local == RouteMap.FORCED_REST_ROW - 1:
				return false
			if _neighbour_has(n, RouteMap.NodeType.SHOP, true, false) or _neighbour_has(n, RouteMap.NodeType.REST, true, false):
				return false
		_:
			if _neighbour_has(n, type, true, false):
				return false
	return true


func _fights_in_row(row: int) -> int:
	var count := 0
	for id in _rows[row]:
		if nodes[id].type == RouteMap.NodeType.FIGHT:
			count += 1
	return count


## Fills the free rows' types: the forced treasure row is all chests; the forced rest row is all rests; the first `safe_rows` free rows of an act are
## fights; the row before the forced one holds no rest; later nodes roll once by
## weight over the types still allowed for them (a rest, shop or elite is not allowed after a node of the same
## type on an incoming edge, and the fight weight is always allowed, so the blocked weight is spread over the
## rest in proportion); every free row keeps at least one plain fight (a rest or shop takes a fight's place, it
## does not replace the row).
func _assign_types(rng: RandomNumberGenerator) -> void:
	var weights := config.type_weights
	var safe := config.safe_rows
	for row in RouteMap.ROWS:
		var info := RouteMap.row_info(row)
		if int(info["type"]) != RouteMap.FREE_ROW:
			continue
		var free_index: int = info["free"]
		if bool(info["treasure"]):
			for id in _rows[row]:
				nodes[id].type = RouteMap.NodeType.TREASURE
			continue
		if bool(info["forced"]):
			for id in _rows[row]:
				nodes[id].type = RouteMap.NodeType.REST
			continue
		for id in _rows[row]:
			var n := nodes[id]
			n.type = RouteMap.NodeType.FIGHT
			if free_index < safe:
				continue
			var options: Array[int] = []
			var rolls: Array[float] = []
			for key in RouteMap.TYPE_KEYS:
				var type: int = RouteMap.TYPE_OF_KEY[key]
				if type == RouteMap.NodeType.TREASURE:
					continue # chests only fill the forced treasure row
				var weight: float = weights.get(key, 0.0)
				if type != RouteMap.NodeType.FIGHT and not _type_allowed(n, type as RouteMap.NodeType):
					weight = 0.0
				options.append(type)
				rolls.append(weight)
			var pick := _pick_weighted(rng, rolls)
			if pick != -1:
				n.type = options[pick] as RouteMap.NodeType
		if _fights_in_row(row) == 0:
			var ids: Array = _rows[row]
			nodes[ids[rng.randi_range(0, ids.size() - 1)]].type = RouteMap.NodeType.FIGHT
		var act_rows := RouteMap.window_rows(int(info["act"]))
		var window_index := act_rows.find(row)
		_ensure_in_window(rng, act_rows, window_index, RouteMap.NodeType.REST, RouteMap.NodeType.SHOP)
		_ensure_in_window(rng, act_rows, window_index, RouteMap.NodeType.SHOP, RouteMap.NodeType.REST)


func _window_of(type: RouteMap.NodeType) -> int:
	return config.rest_window if type == RouteMap.NodeType.REST else config.shop_window


## True if the `window` window rows ending at `free_index` (never reaching back into the safe rows) hold a node
## of `type`, ignoring the node `skip_id`.
func _window_holds(act_rows: Array[int], free_index: int, window: int, type: RouteMap.NodeType, skip_id: int) -> bool:
	for i in range(maxi(free_index - window + 1, 0), free_index + 1):
		for id in _rows[act_rows[i]]:
			if id != skip_id and nodes[id].type == type:
				return true
	return false


## Map-level availability, applied as each free row is finished: if the window of free rows ending at
## `free_index` holds no node of `target`, one node of this row becomes one. A window only spans free rows at
## or after `safe_rows` and ends before the forced rest row (see `window_last_index`). Only the row just assigned can need
## it (the window's earlier rows are done), so its incoming neighbours are known to be free of `target` and no
## later row has been rolled yet; later rows then avoid the adjacency themselves. The converted node is never
## in a safe row and never the last plain fight of its row. Preferred: a plain fight (if the row has a spare
## one), then an elite, then a node of the `other` special type, but only one whose loss leaves the other
## type's window ending here still satisfied (so a repair never breaks the other window). If nothing
## qualifies the generator's validate-and-retry loop is the backstop.
func _ensure_in_window(rng: RandomNumberGenerator, act_rows: Array[int], free_index: int, target: RouteMap.NodeType, other: RouteMap.NodeType) -> void:
	var window := _window_of(target)
	var safe := config.safe_rows
	if window <= 0 or free_index < safe or free_index - window + 1 < safe or free_index > RouteMap.window_last_index(target, act_rows.size()):
		return
	if _window_holds(act_rows, free_index, window, target, -1):
		return
	var other_window := _window_of(other)
	var other_applies := other_window > 0 and free_index - other_window + 1 >= safe and free_index <= RouteMap.window_last_index(other, act_rows.size())
	var fights := _fights_in_row(act_rows[free_index])
	var tiers: Array = [[], [], []]
	for id in _rows[act_rows[free_index]]:
		var n := nodes[id]
		if not _type_allowed(n, target):
			continue
		if n.type == RouteMap.NodeType.FIGHT and fights >= 2:
			tiers[0].append(id)
		elif n.type == RouteMap.NodeType.ELITE:
			tiers[1].append(id)
		elif n.type == other and (not other_applies or _window_holds(act_rows, free_index, other_window, other, id)):
			tiers[2].append(id)
	for tier in tiers:
		if not tier.is_empty():
			nodes[tier[rng.randi_range(0, tier.size() - 1)]].type = target
			return


func _enemy_weights(row: int) -> Array:
	for band in config.enemy_bands:
		if row <= band.max_row:
			return band.weights
	return config.enemy_bands[config.enemy_bands.size() - 1].weights


func _assign_counts(rng: RandomNumberGenerator) -> void:
	for n in nodes:
		if n.type != RouteMap.NodeType.FIGHT and n.type != RouteMap.NodeType.ELITE:
			continue
		var weights: Array = _enemy_weights(n.row).slice(0, Combat.MAX_ENEMIES)
		if n.type == RouteMap.NodeType.ELITE and not weights.is_empty():
			weights[0] = 0.0
		var pick := _pick_weighted(rng, weights)
		n.enemy_count = pick + 1 if pick != -1 else (2 if n.type == RouteMap.NodeType.ELITE else 1)


## Assigns every regular fight a backdrop. A greedy pass can paint itself into a corner (a story node
## after a 4-wide row forbids up to 4 keys on every path through it, and a rest beside a fight adds a
## fifth), so a dead end re-rolls the pass; only the last try falls back to a repeat.
func _assign_backdrops(rng: RandomNumberGenerator) -> void:
	for attempt in RouteMap.BACKDROP_ATTEMPTS:
		if _try_backdrops(rng, attempt == RouteMap.BACKDROP_ATTEMPTS - 1):
			return


func _try_backdrops(rng: RandomNumberGenerator, allow_repeat: bool) -> bool:
	var pool := RouteMap.backdrop_pool(character_id, chapter)
	var memo := {}
	var last_used := {}
	for key in pool:
		last_used[key] = -1
	for n in nodes:
		if n.type != RouteMap.NodeType.FIGHT and n.type != RouteMap.NodeType.ELITE:
			continue
		n.backdrop = &""
		var forbidden := {}
		for p in n.prev:
			for key in map.recent_backdrops(p, memo):
				forbidden[key] = true
		var legal: Array[StringName] = []
		for key in pool:
			if not forbidden.has(key):
				legal.append(key)
		if legal.is_empty():
			if not allow_repeat:
				return false
			# Last resort: the least recently used key (validate() reports the repeat).
			var oldest: StringName = pool[0]
			for key in pool:
				if int(last_used[key]) < int(last_used[oldest]):
					oldest = key
			legal.append(oldest)
		n.backdrop = legal[rng.randi_range(0, legal.size() - 1)]
		last_used[n.backdrop] = n.row
	return true


## Today's stop line (an array of RunState.Stop) as a map with one node per row, so the old layout stays
## expressible. Fights get the line's destination backdrop where it has one.
static func from_line(stops: Array) -> RouteMap:
	var map := RouteMap.new()
	map.kind = RouteMap.KIND_LINE
	map.config = RouteMap.make_config()
	for i in stops.size():
		var stop: RunState.Stop = stops[i]
		var type := RouteMap.NodeType.FIGHT
		match stop.type:
			RunState.StopType.REST:
				type = RouteMap.NodeType.REST
			RunState.StopType.VENDOR:
				type = RouteMap.NodeType.SHOP
			RunState.StopType.STORY:
				type = RouteMap.NodeType.STORY
			_:
				if stop.boss:
					type = RouteMap.NodeType.BOSS
				elif stop.mid_boss:
					type = RouteMap.NodeType.MID_BOSS
		var n := RouteMap.MapNode.new(i, i, 0, type)
		n.act = stop.tier
		if type == RouteMap.NodeType.STORY:
			n.beat_index = stop.beat_index
		elif n.is_fight():
			n.enemy_count = 1 if n.is_boss() else stop.enemy_count
			n.backdrop = DestinationArt.battle_key(i)
		if i > 0:
			n.prev.append(i - 1)
			map.nodes[i - 1].next.append(i)
		map.nodes.append(n)
	map.rebuild_rows()
	return map
