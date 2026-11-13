class_name RouteMap
extends RefCounted
## The selectable route map (docs/MAP_DESIGN.md): a layered graph of nodes, one node per row on any path.
## Pure data and logic with no nodes and no link to RunState; the game does not use it yet (phase 1).
##
## `generate(seed, character_id, config)` builds a map with its own seeded RandomNumberGenerator, so the same
## arguments always give the same map and the run's RNG is never touched. `validate()` lists every broken
## rule; `to_dict()` / `from_dict()` keep the map as plain data; `from_line()` expresses today's 21-stop line
## as a one-node-per-row map.
##
## NodeType is append-only (it is stored as ints in the plain-data form).

enum NodeType { FIGHT, ELITE, REST, SHOP, STORY, MID_BOSS, BOSS, TREASURE, EVENT }

const KIND_GENERATED := &"generated"
const KIND_LINE := &"line"

const ACTS := 2
## What the player calls each of the ACTS halves of the map ("districts"; the code keeps the word act). The first ends at the
## Bellkeeper's court, the second at the Breathing Door; both names come from the story beats.
const DISTRICT_NAMES: Array[String] = Chapters.CHAPTER_1_DISTRICT_NAMES
const ACT_ROWS := 15
const ROWS := ACTS * ACT_ROWS
## The last row of each act is its boss (the mid-boss in act 1, the final boss in act 2).
const BOSS_LOCAL_ROW := 14
## Local rows (within an act) holding a story beat. Beat indices run 0 to 3 in order across the acts.
const STORY_LOCAL_ROWS := [[0, 13], [3, 13]]
## The local row of the forced rest row: the free row just before the story beat that precedes the boss. Every
## node in it is a rest, so every path rests before each boss. The row before it (local row 11) holds no rest.
const FORCED_REST_ROW := 12
## The most ordinary rests (not the forced one before the boss) any one path may meet in an act. The generator
## never rolls a rest past it and validate() rejects a map where some path does.
const MAX_PATH_RESTS := 2
## The local row of each act's forced treasure row (indexed by act): a free row in the middle of the act whose
## nodes are all TREASURE, so every path passes one chest per act. Act 1 has free rows 1 to 12 (the chest at
## free index 5), act 2 has its story beat at row 3 (the chest at free index 6). Neither is next to the forced
## rest row or to the other forced row, and both sit after the first safe rows.
const TREASURE_LOCAL_ROWS := [6, 7]
## `row_info()["type"]` for a free row (a row that holds fights, rests and shops, or the forced rest row).
const FREE_ROW := -1

const MID_BOSS_BACKDROP := &"battle_bell_court"
const BOSS_BACKDROP := &"battle_threshold"
const SHARED_BACKDROPS: Array[StringName] = [&"battle_street", &"battle_garden", &"battle_archive"]
const NEUTRAL_BACKDROP := &"battle_neutral"

## The generator re-rolls (from the same RNG stream, so still deterministic) if a built map fails validate().
const MAX_ATTEMPTS := 20
## How many times the backdrop pass may re-roll before it accepts a repeat (see _assign_backdrops).
const BACKDROP_ATTEMPTS := 60

## Limits `from_dict` and `make_config` enforce on data they did not build themselves.
const MAX_NODES := 1000
const MAX_COLUMN := 15
const MAX_EXITS := 8
const MAX_WIDTH := 5
const SEED_LIMIT := 9.0e18

## Tuning values in one place. Weights are relative (they need not add up to 100). `generate` merges the
## caller's config over this, key by key (and `type_weights` entry by entry).
const CONFIG := {
	# Per free node (the forced rest row is all rests and the forced treasure row all chests whatever these are).
	# Elite is about 8% of the free nodes (docs/MAP_DESIGN.md "Phase 5b"); 0 turns elites off. "treasure" is a reserved key:
	# chests only ever appear in the forced treasure row, so the generator does not roll it. An event takes the
	# place of a fight like a rest or shop does (docs/EVENTS_DESIGN.md); the weights are not shares, see
	# docs/MAP_DESIGN.md "Phase 4c" for what they give per random path (about 2 events, 2.4 rests, 0.85 shops after phase 4f).
	"type_weights": {"fight": 36.0, "rest": 31.0, "shop": 3.5, "elite": 5.5, "treasure": 0.0, "event": 6.5},
	# Enemy count weights (for counts 1, 2, 3 ...) by the node's row in the run; the first band whose
	# max_row is not below the row applies.
	"enemy_bands": [
		{"max_row": 7, "weights": [50.0, 40.0, 10.0]},
		{"max_row": 21, "weights": [25.0, 50.0, 25.0]},
		{"max_row": 29, "weights": [10.0, 40.0, 50.0]},
	],
	# Node counts a free row may have; they must differ by at most 1 so neighbouring rows can connect.
	"free_widths": [3, 4],
	# The first free rows of each act are all fights (no rest, shop, event or elite).
	"safe_rows": 1,
	# Map-level availability: every run of this many consecutive free rows (within an act, counting only
	# rows at or after safe_rows) holds one. 0 turns a window off.
	"rest_window": 6,
	"shop_window": 6,
	# Chance that a node with a single exit edge gets a second one.
	"extra_edge_chance": 0.5,
}

const _TYPE_KEYS := ["fight", "rest", "shop", "elite", "treasure", "event"]
const _TYPE_OF_KEY := {"fight": NodeType.FIGHT, "rest": NodeType.REST, "shop": NodeType.SHOP, "elite": NodeType.ELITE, "treasure": NodeType.TREASURE, "event": NodeType.EVENT}


## One node. `enemy_count` is 0 for non-fights and 1 for bosses; `backdrop` is "" for non-fights;
## `beat_index` matters for STORY nodes only.
class MapNode:
	var id: int
	var row: int
	var col: int
	var type: NodeType
	var enemy_count: int = 0
	var backdrop: StringName = &""
	var beat_index: int = 0
	var act: int = 0
	var next: Array[int] = []
	var prev: Array[int] = []

	func _init(node_id: int, node_row: int, node_col: int, node_type: NodeType) -> void:
		id = node_id
		row = node_row
		col = node_col
		type = node_type

	## Fights of every kind: they have an enemy pack and a backdrop.
	func is_fight() -> bool:
		return type == NodeType.FIGHT or type == NodeType.ELITE or type == NodeType.MID_BOSS or type == NodeType.BOSS

	func is_boss() -> bool:
		return type == NodeType.MID_BOSS or type == NodeType.BOSS


var seed_value: int = 0
var character_id: StringName = &""
var kind: StringName = KIND_GENERATED
var config: Dictionary = {}
var nodes: Array[MapNode] = []
## Node ids by row, in column order.
var _rows: Array = []


# --- Layout ---------------------------------------------------------------------------------------------

## What row `row` (0 to 29) holds: {"act", "type", "free", "beat", "forced", "treasure"}. `type` is a NodeType for a
## choke row (story, mid-boss, boss) or FREE_ROW; `free` is the index among the act's free rows (-1 for choke rows);
## `beat` the story beat of a story row (-1 otherwise); `forced` is true for the forced rest row and `treasure` for
## the forced treasure row (both are free rows).
@warning_ignore("integer_division")
static func row_info(row: int) -> Dictionary:
	var act := row / ACT_ROWS
	var local := row % ACT_ROWS
	if local == BOSS_LOCAL_ROW:
		return {"act": act, "type": NodeType.MID_BOSS if act == 0 else NodeType.BOSS, "free": -1, "beat": -1, "forced": false, "treasure": false}
	var stories: Array = STORY_LOCAL_ROWS[act]
	var story_at := stories.find(local)
	if story_at != -1:
		return {"act": act, "type": NodeType.STORY, "free": -1, "beat": act * 2 + story_at, "forced": false, "treasure": false}
	var before := 0
	for story_row in stories:
		if story_row < local:
			before += 1
	return {"act": act, "type": FREE_ROW, "free": local - before, "beat": -1, "forced": local == FORCED_REST_ROW, "treasure": local == TREASURE_LOCAL_ROWS[act]}


## The row numbers of act `act`'s free rows, in order.
static func free_rows(act: int) -> Array[int]:
	var result: Array[int] = []
	for row in range(act * ACT_ROWS, (act + 1) * ACT_ROWS):
		if int(row_info(row)["type"]) == FREE_ROW:
			result.append(row)
	return result


## The rows the rest and shop availability windows count: the act's free rows without the treasure row (a chest row
## offers neither a rest nor a shop and is not a choice between them), ending with the forced rest row. Window
## indices (`_ensure_in_window`, `window_last_index`, the availability check) are positions in this list.
static func window_rows(act: int) -> Array[int]:
	var result: Array[int] = []
	for row in free_rows(act):
		if not bool(row_info(row)["treasure"]):
			result.append(row)
	return result


## `CONFIG` with the caller's overrides merged in (a deep copy; the constant is never changed). Unknown keys
## and values of the wrong shape or range are ignored, so the result always has a usable value for every key;
## `config_problems()` lists what would be ignored.
static func make_config(overrides: Dictionary = {}) -> Dictionary:
	var merged: Dictionary = CONFIG.duplicate(true)
	for key in overrides:
		var name := str(key)
		if not merged.has(name):
			continue
		var value: Variant = overrides[key]
		if name == "type_weights":
			if value is Dictionary:
				for type_key in value:
					if _TYPE_KEYS.has(str(type_key)) and _weight_ok(value[type_key]):
						merged["type_weights"][str(type_key)] = float(value[type_key])
		elif _config_problem(name, value) == "":
			merged[name] = value.duplicate(true) if value is Array or value is Dictionary else value
	# Whole numbers stay ints even when the config came back from JSON as floats.
	for key in ["safe_rows", "rest_window", "shop_window"]:
		merged[key] = int(merged[key])
	merged["extra_edge_chance"] = float(merged["extra_edge_chance"])
	var widths: Array = []
	for width in merged["free_widths"]:
		widths.append(int(width))
	merged["free_widths"] = widths
	for band in merged["enemy_bands"]:
		band["max_row"] = int(band["max_row"])
		var band_weights: Array = []
		for weight in band["weights"]:
			band_weights.append(float(weight))
		band["weights"] = band_weights
	return merged


## What is wrong with the shape of a config dictionary (empty when `make_config` would use all of it).
## Unknown keys are not a problem; they are ignored.
static func config_problems(overrides: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	for key in overrides:
		var name := str(key)
		if CONFIG.has(name):
			var problem := _config_problem(name, overrides[key])
			if problem != "":
				problems.append(problem)
	return problems


static func _is_number(value: Variant) -> bool:
	return value is int or (value is float and is_finite(value))


## True for a finite number with no fractional part between `low` and `high` inclusive.
static func _is_whole(value: Variant, low: float, high: float) -> bool:
	return _is_number(value) and float(value) >= low and float(value) <= high and float(value) == floorf(float(value))


static func _weight_ok(value: Variant) -> bool:
	return _is_number(value) and float(value) >= 0.0 and float(value) <= 1.0e9


static func _config_problem(key: String, value: Variant) -> String:
	match key:
		"type_weights":
			if not value is Dictionary:
				return "type_weights must be a dictionary"
			for type_key in value:
				if not _TYPE_KEYS.has(str(type_key)) or not _weight_ok(value[type_key]):
					return "type_weights has a bad entry '%s'" % str(type_key)
		"enemy_bands":
			if not value is Array or value.is_empty():
				return "enemy_bands must be a non-empty array"
			for band in value:
				if not band is Dictionary or not _is_whole(band.get("max_row"), 0, 1000) or not band.get("weights") is Array or band["weights"].is_empty():
					return "enemy_bands holds a band without a whole max_row and a non-empty weights array"
				for weight in band["weights"]:
					if not _weight_ok(weight):
						return "enemy_bands holds a bad weight"
		"free_widths":
			if not value is Array or value.is_empty():
				return "free_widths must be a non-empty array"
			var low := 1000000
			var high := -1
			for width in value:
				if not _is_whole(width, 2, MAX_WIDTH):
					return "free_widths entries must be whole numbers from 2 to %d" % MAX_WIDTH
				low = mini(low, int(width))
				high = maxi(high, int(width))
			if high - low > 1:
				return "free_widths must differ by at most 1 so neighbouring rows can connect"
		"safe_rows", "rest_window", "shop_window":
			if not _is_whole(value, 0, ACT_ROWS):
				return "%s must be a whole number from 0 to %d" % [key, ACT_ROWS]
		"extra_edge_chance":
			if not _is_number(value) or float(value) < 0.0 or float(value) > 1.0:
				return "extra_edge_chance must be a number from 0 to 1"
	return ""


# --- Queries --------------------------------------------------------------------------------------------

func node(id: int) -> MapNode:
	return nodes[id] if id >= 0 and id < nodes.size() else null


func node_count() -> int:
	return nodes.size()


func row_count() -> int:
	return _rows.size()


func next_ids(id: int) -> Array[int]:
	var found := node(id)
	var ids: Array[int] = []
	if found != null:
		ids.assign(found.next)
	return ids


func previous_ids(id: int) -> Array[int]:
	var found := node(id)
	var ids: Array[int] = []
	if found != null:
		ids.assign(found.prev)
	return ids


## The nodes of row `row`, in column order.
func row_nodes(row: int) -> Array[MapNode]:
	var result: Array[MapNode] = []
	if row >= 0 and row < _rows.size():
		for id in _rows[row]:
			result.append(nodes[id])
	return result


## Ids of the first row, where the player starts.
func starts() -> Array[int]:
	var ids: Array[int] = []
	if not _rows.is_empty():
		ids.assign(_rows[0])
	return ids


## Ids of the last row (the final boss).
func finals() -> Array[int]:
	var ids: Array[int] = []
	if not _rows.is_empty():
		ids.assign(_rows[_rows.size() - 1])
	return ids


func count_of(type: NodeType) -> int:
	var count := 0
	for n in nodes:
		if n.type == type:
			count += 1
	return count


## The number of distinct start-to-end paths.
func path_count() -> int:
	var ways := {}
	for id in starts():
		ways[id] = 1
	for row in range(_rows.size() - 1):
		for id in _rows[row]:
			var here: int = ways.get(id, 0)
			for nxt in nodes[id].next:
				ways[nxt] = int(ways.get(nxt, 0)) + here
	var total := 0
	for id in finals():
		total += int(ways.get(id, 0))
	return total


## Every start-to-end path as an array of node ids, one per row; stops collecting at `limit` paths.
func all_paths(limit: int = 100000) -> Array[PackedInt32Array]:
	var found: Array[PackedInt32Array] = []
	var trail := PackedInt32Array()
	for id in starts():
		_walk(id, trail, found, limit)
	return found


func _walk(id: int, trail: PackedInt32Array, found: Array[PackedInt32Array], limit: int) -> void:
	if found.size() >= limit:
		return
	trail.append(id)
	if nodes[id].row == _rows.size() - 1:
		found.append(trail.duplicate())
	else:
		for nxt in nodes[id].next:
			_walk(nxt, trail, found, limit)
	trail.remove_at(trail.size() - 1)


## Rebuilds each node's `prev` list from the `next` lists. For code that edits edges by hand.
func rebuild_links() -> void:
	for n in nodes:
		n.prev = []
	for n in nodes:
		for nxt in n.next:
			if nxt >= 0 and nxt < nodes.size() and not nodes[nxt].prev.has(n.id):
				nodes[nxt].prev.append(n.id)
	for n in nodes:
		n.prev.sort()


## The battle backdrops a regular fight may use for a character: the three shared keys, the character's own
## (only for a known character, i.e. a key of BattleBackdrop.TINTS) and the neutral key. An unknown or empty
## id gives the four keys without one. The two boss keys are never in the pool.
static func backdrop_pool(char_id: StringName, chapter_number: int = 1) -> Array[StringName]:
	var pool: Array[StringName] = []
	pool.assign(SHARED_BACKDROPS if chapter_number <= 1 else Chapters.chapter(chapter_number).shared_backdrops)
	if BattleBackdrop.TINTS.has(char_id):
		var own := StringName("battle_" + String(char_id))
		if not pool.has(own):
			pool.append(own)
	if not pool.has(NEUTRAL_BACKDROP):
		pool.append(NEUTRAL_BACKDROP)
	return pool


# --- Generation -----------------------------------------------------------------------------------------

## Builds the map for `map_seed`. Same arguments, same map; uses its own RNG only. Config entries of the
## wrong shape fall back to the defaults (see `make_config`). If no attempt validates, the last map is
## returned with an error pushed, so a caller that checks `validate()` sees what is wrong.
## The chapter this map is for (1 unless it was generated for a later one): its backdrops come from that chapter's ChapterData.
var chapter: int = 1


## The EliteModifiers.Kind of elite node `id`, or -1 for any other node.
func elite_modifier(id: int) -> int:
	var n := node(id)
	if n == null or n.type != NodeType.ELITE or EliteModifiers.forced == EliteModifiers.FORCE_NONE:
		return -1
	return EliteModifiers.for_node(seed_value, id)


static func generate(map_seed: int, char_id: StringName, overrides: Dictionary = {}, chapter_number: int = 1) -> RouteMap:
	var cfg := make_config(overrides)
	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed
	var map: RouteMap = null
	var problems: Array[String] = []
	for attempt in MAX_ATTEMPTS:
		map = _build(rng, map_seed, char_id, cfg, chapter_number)
		problems = map.validate()
		if problems.is_empty():
			return map
	push_error("RouteMap.generate: seed %d (%s) still breaks %d rule(s) after %d attempts, first: %s" % [map_seed, char_id, problems.size(), MAX_ATTEMPTS, problems[0]])
	return map


static func _build(rng: RandomNumberGenerator, map_seed: int, char_id: StringName, cfg: Dictionary, chapter_number: int = 1) -> RouteMap:
	var map := RouteMap.new()
	map.chapter = chapter_number
	map.seed_value = map_seed
	map.character_id = char_id
	map.kind = KIND_GENERATED
	map.config = cfg.duplicate(true)
	map._make_nodes(rng)
	map._make_edges(rng)
	map._assign_types(rng)
	map._assign_counts(rng)
	map._assign_backdrops(rng)
	return map


func _make_nodes(rng: RandomNumberGenerator) -> void:
	var widths: Array = config["free_widths"]
	for row in ROWS:
		var info := row_info(row)
		var row_type: int = info["type"]
		var width := 1
		if row_type == FREE_ROW:
			width = int(widths[rng.randi_range(0, widths.size() - 1)])
		var ids: Array[int] = []
		for col in width:
			var n := MapNode.new(nodes.size(), row, col, NodeType.FIGHT if row_type == FREE_ROW else row_type as NodeType)
			n.act = info["act"]
			if row_type == NodeType.STORY:
				n.beat_index = info["beat"]
			elif row_type == NodeType.MID_BOSS:
				n.enemy_count = 1
				n.backdrop = Chapters.chapter(chapter).mid_boss_backdrop
			elif row_type == NodeType.BOSS:
				n.enemy_count = 1
				n.backdrop = Chapters.chapter(chapter).boss_backdrop
			nodes.append(n)
			ids.append(n.id)
		_rows.append(ids)


func _link(from_id: int, to_id: int) -> void:
	nodes[from_id].next.append(to_id)
	nodes[to_id].prev.append(from_id)


func _make_edges(rng: RandomNumberGenerator) -> void:
	var extra_chance := float(config["extra_edge_chance"])
	for row in range(ROWS - 1):
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


func _neighbour_has(n: MapNode, type: NodeType, use_prev: bool, use_next: bool) -> bool:
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
	return row + 1 < ROWS and bool(row_info(row + 1)["treasure"])


## The most ordinary rests (see MAX_PATH_RESTS) on any path from the start of the act up to and including node
## `id`. The forced rest row does not count. Looks only at nodes already typed, so call it for incoming
## neighbours while generating.
func _path_rests(id: int, memo: Dictionary = {}) -> int:
	if memo.has(id):
		return memo[id]
	var n := nodes[id]
	var before := 0
	if n.row % ACT_ROWS != 0:
		for p in n.prev:
			before = maxi(before, _path_rests(p, memo))
	var own := 1 if n.type == NodeType.REST and not bool(row_info(n.row)["forced"]) else 0
	memo[id] = before + own
	return before + own


## Whether node `n`, whose incoming neighbours are already typed, may become `type` (the later rows are not rolled yet,
## so only what comes before it and what is fixed after it counts). A rest, shop, event or elite may not follow a
## node of its own type. A rest may not follow a shop or a chest, nor sit in the row before the forced rest row or
## before the chest row; a shop may not follow a rest nor sit in the row before the forced rest row; and no path may
## pass more than MAX_PATH_RESTS ordinary rests in an act.
func _type_allowed(n: MapNode, type: NodeType) -> bool:
	var local := n.row % ACT_ROWS
	match type:
		NodeType.REST:
			if local == FORCED_REST_ROW - 1 or _next_row_is_treasure(n.row):
				return false
			if _neighbour_has(n, NodeType.REST, true, false) or _neighbour_has(n, NodeType.SHOP, true, false) or _neighbour_has(n, NodeType.TREASURE, true, false):
				return false
			var memo := {}
			for p in n.prev:
				if local != 0 and _path_rests(p, memo) >= MAX_PATH_RESTS:
					return false
		NodeType.SHOP:
			if local == FORCED_REST_ROW - 1:
				return false
			if _neighbour_has(n, NodeType.SHOP, true, false) or _neighbour_has(n, NodeType.REST, true, false):
				return false
		_:
			if _neighbour_has(n, type, true, false):
				return false
	return true


func _fights_in_row(row: int) -> int:
	var count := 0
	for id in _rows[row]:
		if nodes[id].type == NodeType.FIGHT:
			count += 1
	return count


## Fills the free rows' types: the forced treasure row is all chests; the forced rest row is all rests; the first `safe_rows` free rows of an act are
## fights; the row before the forced one holds no rest; later nodes roll once by
## weight over the types still allowed for them (a rest, shop or elite is not allowed after a node of the same
## type on an incoming edge, and the fight weight is always allowed, so the blocked weight is spread over the
## rest in proportion); every free row keeps at least one plain fight (a rest or shop takes a fight's place, it
## does not replace the row).
func _assign_types(rng: RandomNumberGenerator) -> void:
	var weights: Dictionary = config["type_weights"]
	var safe := int(config["safe_rows"])
	for row in ROWS:
		var info := row_info(row)
		if int(info["type"]) != FREE_ROW:
			continue
		var free_index: int = info["free"]
		if bool(info["treasure"]):
			for id in _rows[row]:
				nodes[id].type = NodeType.TREASURE
			continue
		if bool(info["forced"]):
			for id in _rows[row]:
				nodes[id].type = NodeType.REST
			continue
		for id in _rows[row]:
			var n := nodes[id]
			n.type = NodeType.FIGHT
			if free_index < safe:
				continue
			var options: Array[int] = []
			var rolls: Array[float] = []
			for key in _TYPE_KEYS:
				var type: int = _TYPE_OF_KEY[key]
				if type == NodeType.TREASURE:
					continue # chests only fill the forced treasure row
				var weight := float(weights.get(key, 0.0))
				if type != NodeType.FIGHT and not _type_allowed(n, type as NodeType):
					weight = 0.0
				options.append(type)
				rolls.append(weight)
			var pick := _pick_weighted(rng, rolls)
			if pick != -1:
				n.type = options[pick] as NodeType
		if _fights_in_row(row) == 0:
			var ids: Array = _rows[row]
			nodes[ids[rng.randi_range(0, ids.size() - 1)]].type = NodeType.FIGHT
		var act_rows := window_rows(int(info["act"]))
		var window_index := act_rows.find(row)
		_ensure_in_window(rng, act_rows, window_index, NodeType.REST, NodeType.SHOP)
		_ensure_in_window(rng, act_rows, window_index, NodeType.SHOP, NodeType.REST)


func _window_of(type: NodeType) -> int:
	return int(config["rest_window"]) if type == NodeType.REST else int(config["shop_window"])


## The last window index (a position in `window_rows`) at which a window for `type` may end. The forced rest row
## satisfies the rest need itself, and the row before it holds neither a rest (it would sit next to the forced rest)
## nor a shop (a rest may not follow one), so both windows stop two rows before the end of the list.
static func window_last_index(_type: NodeType, window_count: int) -> int:
	return window_count - 3


## True if the `window` window rows ending at `free_index` (never reaching back into the safe rows) hold a node
## of `type`, ignoring the node `skip_id`.
func _window_holds(act_rows: Array[int], free_index: int, window: int, type: NodeType, skip_id: int) -> bool:
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
func _ensure_in_window(rng: RandomNumberGenerator, act_rows: Array[int], free_index: int, target: NodeType, other: NodeType) -> void:
	var window := _window_of(target)
	var safe := int(config["safe_rows"])
	if window <= 0 or free_index < safe or free_index - window + 1 < safe or free_index > window_last_index(target, act_rows.size()):
		return
	if _window_holds(act_rows, free_index, window, target, -1):
		return
	var other_window := _window_of(other)
	var other_applies := other_window > 0 and free_index - other_window + 1 >= safe and free_index <= window_last_index(other, act_rows.size())
	var fights := _fights_in_row(act_rows[free_index])
	var tiers: Array = [[], [], []]
	for id in _rows[act_rows[free_index]]:
		var n := nodes[id]
		if not _type_allowed(n, target):
			continue
		if n.type == NodeType.FIGHT and fights >= 2:
			tiers[0].append(id)
		elif n.type == NodeType.ELITE:
			tiers[1].append(id)
		elif n.type == other and (not other_applies or _window_holds(act_rows, free_index, other_window, other, id)):
			tiers[2].append(id)
	for tier in tiers:
		if not tier.is_empty():
			nodes[tier[rng.randi_range(0, tier.size() - 1)]].type = target
			return


func _enemy_weights(row: int) -> Array:
	for band in config["enemy_bands"]:
		if row <= int(band["max_row"]):
			return band["weights"]
	var bands: Array = config["enemy_bands"]
	return bands[bands.size() - 1]["weights"]


func _assign_counts(rng: RandomNumberGenerator) -> void:
	for n in nodes:
		if n.type != NodeType.FIGHT and n.type != NodeType.ELITE:
			continue
		var weights: Array = _enemy_weights(n.row).slice(0, Combat.MAX_ENEMIES)
		if n.type == NodeType.ELITE and not weights.is_empty():
			weights[0] = 0.0
		var pick := _pick_weighted(rng, weights)
		n.enemy_count = pick + 1 if pick != -1 else (2 if n.type == NodeType.ELITE else 1)


## The backdrops of the most recent fight on each path into `id`, counting `id` itself when it is a fight.
## Walks back through rests, shops and story nodes. `memo` caches results; call it only for nodes whose
## ancestors already have their backdrops.
func _recent_backdrops(id: int, memo: Dictionary) -> Dictionary:
	if memo.has(id):
		return memo[id]
	var n := nodes[id]
	var result := {}
	if n.is_fight():
		if n.backdrop != &"":
			result[n.backdrop] = true
	else:
		for p in n.prev:
			for key in _recent_backdrops(p, memo):
				result[key] = true
	memo[id] = result
	return result


## Assigns every regular fight a backdrop. A greedy pass can paint itself into a corner (a story node
## after a 4-wide row forbids up to 4 keys on every path through it, and a rest beside a fight adds a
## fifth), so a dead end re-rolls the pass; only the last try falls back to a repeat.
func _assign_backdrops(rng: RandomNumberGenerator) -> void:
	for attempt in BACKDROP_ATTEMPTS:
		if _try_backdrops(rng, attempt == BACKDROP_ATTEMPTS - 1):
			return


func _try_backdrops(rng: RandomNumberGenerator, allow_repeat: bool) -> bool:
	var pool := backdrop_pool(character_id, chapter)
	var memo := {}
	var last_used := {}
	for key in pool:
		last_used[key] = -1
	for n in nodes:
		if n.type != NodeType.FIGHT and n.type != NodeType.ELITE:
			continue
		n.backdrop = &""
		var forbidden := {}
		for p in n.prev:
			for key in _recent_backdrops(p, memo):
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


# --- Validation -----------------------------------------------------------------------------------------

## Every broken rule, as readable strings; empty when the map is valid. A "line" map is only checked for
## graph shape and enemy counts (it is not meant to follow the generated layout).
func validate() -> Array[String]:
	var v: Array[String] = []
	if kind != KIND_GENERATED and kind != KIND_LINE:
		v.append("unknown map kind '%s'" % kind)
		return v
	if nodes.is_empty():
		v.append("map has no nodes")
		return v
	for i in nodes.size():
		if nodes[i].id != i:
			v.append("node at index %d has id %d" % [i, nodes[i].id])
	if not v.is_empty():
		return v
	var rows := _rows_from_nodes(v)
	if not v.is_empty():
		return v
	var preds := _check_graph(v, rows)
	if not v.is_empty():
		return v
	if kind == KIND_GENERATED:
		_check_layout(v, rows)
		if not v.is_empty():
			return v
		_check_edges(v, rows)
		_check_types(v, rows, preds)
		_check_rest_rules(v, rows, preds)
		_check_availability(v, rows)
		_check_rest_before_bosses(v, rows)
		_check_backdrops(v)
	_check_counts(v)
	return v


func _describe(n: MapNode) -> String:
	return "node %d (row %d, col %d)" % [n.id, n.row, n.col]


## Groups the nodes by their `row` field into columns order; reports gaps and column mismatches.
func _rows_from_nodes(v: Array[String]) -> Array:
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
func _check_graph(v: Array[String], rows: Array) -> Array:
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
	if last.size() != 1 or nodes[last[0]].type != NodeType.BOSS:
		v.append("the last row must be a single boss node")
	return preds


func _check_layout(v: Array[String], rows: Array) -> void:
	if rows.size() != ROWS:
		v.append("map has %d rows, expected %d" % [rows.size(), ROWS])
		return
	var widths: Array = config["free_widths"] if config.get("free_widths") is Array else []
	if widths.is_empty():
		v.append("config has no free_widths")
		return
	var min_width: int = widths.min()
	var max_width: int = widths.max()
	for r in ROWS:
		var info := row_info(r)
		var ids: Array = rows[r]
		var row_type: int = info["type"]
		if row_type == FREE_ROW:
			if bool(info["treasure"]):
				for id in ids:
					if nodes[id].type != NodeType.TREASURE:
						v.append("%s is in the forced treasure row and must be a treasure" % _describe(nodes[id]))
			elif bool(info["forced"]):
				for id in ids:
					if nodes[id].type != NodeType.REST:
						v.append("%s is in the forced rest row and must be a rest" % _describe(nodes[id]))
			elif r % ACT_ROWS == FORCED_REST_ROW - 1:
				for id in ids:
					if nodes[id].type == NodeType.REST:
						v.append("%s is in the row before the forced rest row and may not be a rest" % _describe(nodes[id]))
			if ids.size() < min_width or ids.size() > max_width:
				v.append("free row %d has %d nodes, expected %d to %d" % [r, ids.size(), min_width, max_width])
			for id in ids:
				var t := nodes[id].type
				if bool(info["treasure"]):
					if t != NodeType.TREASURE:
						v.append("%s has type %d, but the treasure row holds only treasure" % [_describe(nodes[id]), t])
				elif t != NodeType.FIGHT and t != NodeType.ELITE and t != NodeType.REST and t != NodeType.SHOP and t != NodeType.EVENT:
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
		if row_type == NodeType.STORY and n.beat_index != info["beat"]:
			v.append("%s should be story beat %d, not %d" % [_describe(n), info["beat"], n.beat_index])


func _check_edges(v: Array[String], rows: Array) -> void:
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


func _check_types(v: Array[String], rows: Array, preds: Array) -> void:
	var safe := int(config["safe_rows"])
	for r in rows.size():
		var info := row_info(r)
		if int(info["type"]) != FREE_ROW or bool(info["forced"]) or bool(info["treasure"]):
			continue
		var plain_fights := 0
		for id in rows[r]:
			var n := nodes[id]
			if n.type == NodeType.FIGHT:
				plain_fights += 1
			if int(info["free"]) < safe and n.type != NodeType.FIGHT:
				v.append("%s is within the first %d free rows of its act and must be a fight" % [_describe(n), safe])
			if n.type == NodeType.REST or n.type == NodeType.SHOP or n.type == NodeType.ELITE or n.type == NodeType.EVENT:
				for p in preds[id]:
					if nodes[p].type == n.type:
						v.append("%s follows a node of the same type (%d)" % [_describe(n), n.type])
						break
		if plain_fights == 0:
			v.append("free row %d has no plain fight" % r)


## The rest rules: no rest right after a shop or a chest, no shop right after a rest, no chest right after a rest,
## and no path with more than MAX_PATH_RESTS ordinary rests in an act.
func _check_rest_rules(v: Array[String], rows: Array, preds: Array) -> void:
	var counts := {}
	for r in rows.size():
		for id in rows[r]:
			var n := nodes[id]
			var before := 0
			if r % ACT_ROWS != 0:
				for p in preds[id]:
					before = maxi(before, counts.get(p, 0))
					var from_type := nodes[p].type
					if n.type == NodeType.REST and (from_type == NodeType.SHOP or from_type == NodeType.TREASURE):
						v.append("%s follows a %s" % [_describe(n), "shop" if from_type == NodeType.SHOP else "chest"])
					elif (n.type == NodeType.SHOP or n.type == NodeType.TREASURE) and from_type == NodeType.REST:
						v.append("%s follows a rest" % _describe(n))
			var own := 1 if n.type == NodeType.REST and not bool(row_info(r)["forced"]) else 0
			counts[id] = before + own
			if before + own > MAX_PATH_RESTS:
				v.append("%s is the %dth ordinary rest on a path in its act (at most %d)" % [_describe(n), before + own, MAX_PATH_RESTS])


func _check_availability(v: Array[String], rows_by_number: Array) -> void:
	var safe := int(config["safe_rows"])
	for pair in [[NodeType.REST, int(config["rest_window"]), "rest"], [NodeType.SHOP, int(config["shop_window"]), "shop"]]:
		var window: int = pair[1]
		if window <= 0:
			continue
		for act in ACTS:
			var rows := window_rows(act)
			for start in range(safe, window_last_index(pair[0], rows.size()) - window + 2):
				var present := false
				for i in range(start, start + window):
					for id in rows_by_number[rows[i]]:
						if nodes[id].type == pair[0]:
							present = true
				if not present:
					v.append("act %d: free rows %d to %d hold no %s" % [act + 1, start, start + window - 1, pair[2]])


## Every path passes a rest between the start (or the previous boss) and each boss. The forced rest row makes
## this true; the check is by path, so it also catches a rest row that some edge routes around.
func _check_rest_before_bosses(v: Array[String], rows: Array) -> void:
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
				covered[id] = n.type == NodeType.REST or all_rest


func _check_counts(v: Array[String]) -> void:
	for n in nodes:
		match n.type:
			NodeType.MID_BOSS, NodeType.BOSS:
				if n.enemy_count != 1:
					v.append("%s is a boss and must have 1 enemy, not %d" % [_describe(n), n.enemy_count])
			NodeType.ELITE:
				if n.enemy_count < 2 or n.enemy_count > Combat.MAX_ENEMIES:
					v.append("%s is an elite and needs 2 to %d enemies, not %d" % [_describe(n), Combat.MAX_ENEMIES, n.enemy_count])
			NodeType.FIGHT:
				if n.enemy_count < 1 or n.enemy_count > Combat.MAX_ENEMIES:
					v.append("%s is a fight and needs 1 to %d enemies, not %d" % [_describe(n), Combat.MAX_ENEMIES, n.enemy_count])
			_:
				if n.enemy_count != 0:
					v.append("%s is not a fight and must have 0 enemies, not %d" % [_describe(n), n.enemy_count])


func _check_backdrops(v: Array[String]) -> void:
	var pool := backdrop_pool(character_id, chapter)
	var memo := {}
	for n in nodes:
		if n.type == NodeType.MID_BOSS:
			if n.backdrop != Chapters.chapter(chapter).mid_boss_backdrop:
				v.append("%s must use %s" % [_describe(n), Chapters.chapter(chapter).mid_boss_backdrop])
		elif n.type == NodeType.BOSS:
			if n.backdrop != Chapters.chapter(chapter).boss_backdrop:
				v.append("%s must use %s" % [_describe(n), Chapters.chapter(chapter).boss_backdrop])
		elif n.type == NodeType.FIGHT or n.type == NodeType.ELITE:
			if not pool.has(n.backdrop):
				v.append("%s uses backdrop '%s', which is not in the pool" % [_describe(n), n.backdrop])
				continue
			for p in n.prev:
				if _recent_backdrops(p, memo).has(n.backdrop):
					v.append("%s repeats backdrop %s from the most recent fight on a path into it" % [_describe(n), n.backdrop])
					break
		elif n.backdrop != &"":
			v.append("%s is not a fight and must have no backdrop" % _describe(n))


# --- Plain data -----------------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var list: Array = []
	for n in nodes:
		list.append({
			"id": n.id, "row": n.row, "col": n.col, "type": int(n.type), "enemy_count": n.enemy_count,
			"backdrop": String(n.backdrop), "beat_index": n.beat_index, "act": n.act, "next": n.next.duplicate(),
		})
	var data := {
		"version": 1, "kind": String(kind), "seed": seed_value, "character_id": String(character_id),
		"config": config.duplicate(true), "nodes": list,
	}
	if chapter > 1:
		data["chapter"] = chapter # only a later chapter writes it, so a Chapter 1 map is saved exactly as before
	return data


## Rebuilds a map from `to_dict()` output (also after a JSON round trip). Null if the data is malformed:
## wrong types, an unknown kind or node type, a row, column, edge or node count out of range, or a config of
## the wrong shape. (Rule breaks inside well-formed data are for `validate()` to report.)
static func from_dict(data: Dictionary) -> RouteMap:
	if not data.get("nodes") is Array:
		return null
	var raw: Array = data["nodes"]
	if raw.size() > MAX_NODES:
		return null
	var kind_value: Variant = data.get("kind", String(KIND_GENERATED))
	if not (kind_value is String or kind_value is StringName):
		return null
	var map_kind := StringName(kind_value)
	if map_kind != KIND_GENERATED and map_kind != KIND_LINE:
		return null
	if data.has("seed") and not _is_whole(data["seed"], -SEED_LIMIT, SEED_LIMIT):
		return null
	var char_value: Variant = data.get("character_id", "")
	if not (char_value is String or char_value is StringName) or String(char_value).length() > 64:
		return null
	var raw_config: Variant = data.get("config", {})
	if not raw_config is Dictionary or not config_problems(raw_config).is_empty():
		return null
	var map := RouteMap.new()
	map.seed_value = int(data.get("seed", 0))
	map.character_id = StringName(char_value)
	map.kind = map_kind
	map.chapter = clampi(int(data.get("chapter", 1)), 1, Chapters.MAX_BUILT)
	map.config = make_config(raw_config)
	var last_row := (ROWS if map_kind == KIND_GENERATED else raw.size()) - 1
	for i in raw.size():
		if not raw[i] is Dictionary:
			return null
		var d: Dictionary = raw[i]
		if not _is_whole(d.get("id", i), i, i) or not _is_whole(d.get("type"), 0, NodeType.EVENT) or not _is_whole(d.get("row"), 0, last_row):
			return null
		if not _is_whole(d.get("col", 0), 0, MAX_COLUMN) or not _is_whole(d.get("enemy_count", 0), 0, 99):
			return null
		if not _is_whole(d.get("beat_index", 0), 0, 99) or not _is_whole(d.get("act", 0), 0, 9):
			return null
		var backdrop: Variant = d.get("backdrop", "")
		if not (backdrop is String or backdrop is StringName) or String(backdrop).length() > 64:
			return null
		var exits: Variant = d.get("next", [])
		if not exits is Array or exits.size() > MAX_EXITS:
			return null
		var n := MapNode.new(i, int(d["row"]), int(d.get("col", 0)), int(d["type"]) as NodeType)
		n.enemy_count = int(d.get("enemy_count", 0))
		n.backdrop = StringName(backdrop)
		n.beat_index = int(d.get("beat_index", 0))
		n.act = int(d.get("act", 0))
		for nxt in exits:
			if not _is_whole(nxt, 0, raw.size() - 1):
				return null
			n.next.append(int(nxt))
		map.nodes.append(n)
	map._rebuild_rows()
	map.rebuild_links()
	return map


func _rebuild_rows() -> void:
	_rows = []
	var highest := -1
	for n in nodes:
		highest = maxi(highest, n.row)
	if highest >= nodes.size():
		return
	for r in highest + 1:
		_rows.append([])
	for n in nodes:
		_rows[n.row].append(n.id)
	for ids in _rows:
		ids.sort_custom(func(a: int, b: int) -> bool: return nodes[a].col < nodes[b].col)


## Today's stop line (an array of RunState.Stop) as a map with one node per row, so the old layout stays
## expressible. Fights get the line's destination backdrop where it has one.
static func from_line(stops: Array) -> RouteMap:
	var map := RouteMap.new()
	map.kind = KIND_LINE
	map.config = make_config()
	for i in stops.size():
		var stop: RunState.Stop = stops[i]
		var type := NodeType.FIGHT
		match stop.type:
			RunState.StopType.REST:
				type = NodeType.REST
			RunState.StopType.VENDOR:
				type = NodeType.SHOP
			RunState.StopType.STORY:
				type = NodeType.STORY
			_:
				if stop.boss:
					type = NodeType.BOSS
				elif stop.mid_boss:
					type = NodeType.MID_BOSS
		var n := MapNode.new(i, i, 0, type)
		n.act = stop.tier
		if type == NodeType.STORY:
			n.beat_index = stop.beat_index
		elif n.is_fight():
			n.enemy_count = 1 if n.is_boss() else stop.enemy_count
			n.backdrop = DestinationArt.battle_key(i)
		if i > 0:
			n.prev.append(i - 1)
			map.nodes[i - 1].next.append(i)
		map.nodes.append(n)
	map._rebuild_rows()
	return map
