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
## This script is the data model: the constants, the config classes, the layout helpers, the queries and the plain-data
## form. Building is in `run/route_map_generator.gd` (RouteMapGenerator) and the rule checks in `run/route_map_rules.gd`
## (RouteMapRules); `generate`, `from_line`, `validate` and `config_problems` forward there, so callers only use RouteMap.
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

## The type keys of CONFIG["type_weights"], in order, and the NodeType each names.
const TYPE_KEYS := ["fight", "rest", "shop", "elite", "treasure", "event"]
const TYPE_OF_KEY := {"fight": NodeType.FIGHT, "rest": NodeType.REST, "shop": NodeType.SHOP, "elite": NodeType.ELITE, "treasure": NodeType.TREASURE, "event": NodeType.EVENT}


## One enemy-count band of a RouteConfig: the weights for counts 1, 2, 3 ... used up to row `max_row` of the run.
class EnemyBand extends RefCounted:
	var max_row := 0
	var weights: Array[float] = []

	func _init(p_max_row: int = 0, p_weights: Array[float] = []) -> void:
		max_row = p_max_row
		weights = p_weights

	## The plain-data form, as CONFIG writes a band.
	func to_dict() -> Dictionary:
		var plain_weights: Array = []
		for weight in weights:
			plain_weights.append(weight)
		return {"max_row": max_row, "weights": plain_weights}


## The tuning a map is built with: CONFIG with a caller's overrides merged in (see `from_overrides`). A new one has
## every field empty or zero (as a map that was never generated has no config); `from_overrides({})` is the defaults.
class RouteConfig extends RefCounted:
	## Relative weights per free node, by type key (the keys of CONFIG["type_weights"], in that order).
	var type_weights: Dictionary[String, float] = {}
	## Enemy count weights by the node's row in the run; the first band whose max_row is not below the row applies.
	var enemy_bands: Array[EnemyBand] = []
	## Node counts a free row may have.
	var free_widths: Array[int] = []
	## The first free rows of each act that are all fights.
	var safe_rows := 0
	## Availability windows (0 turns one off).
	var rest_window := 0
	var shop_window := 0
	## Chance that a node with a single exit edge gets a second one.
	var extra_edge_chance := 0.0

	## CONFIG with `overrides` merged in, key by key (and `type_weights` entry by entry). Unknown keys and values of
	## the wrong shape or range are ignored, so every field has a usable value; `RouteMapRules.config_problems()` lists
	## what would be ignored. Whole numbers stay ints even when the overrides came back from JSON as floats.
	static func from_overrides(overrides: Dictionary = {}) -> RouteConfig:
		var merged: Dictionary = RouteMap.CONFIG.duplicate(true)
		for key in overrides:
			var name := str(key)
			if not merged.has(name):
				continue
			var value: Variant = overrides[key]
			if name == "type_weights":
				if value is Dictionary:
					for type_key in value:
						if RouteMap.TYPE_KEYS.has(str(type_key)) and RouteMapRules.weight_ok(value[type_key]):
							merged["type_weights"][str(type_key)] = float(value[type_key])
			elif RouteMapRules.config_problem(name, value) == "":
				merged[name] = value.duplicate(true) if value is Array or value is Dictionary else value
		var cfg := RouteConfig.new()
		for type_key in merged["type_weights"]:
			cfg.type_weights[str(type_key)] = float(merged["type_weights"][type_key])
		for band in merged["enemy_bands"]:
			var band_weights: Array[float] = []
			for weight in band["weights"]:
				band_weights.append(float(weight))
			cfg.enemy_bands.append(EnemyBand.new(int(band["max_row"]), band_weights))
		for width in merged["free_widths"]:
			cfg.free_widths.append(int(width))
		cfg.safe_rows = int(merged["safe_rows"])
		cfg.rest_window = int(merged["rest_window"])
		cfg.shop_window = int(merged["shop_window"])
		cfg.extra_edge_chance = float(merged["extra_edge_chance"])
		return cfg

	## A deep copy.
	func copy() -> RouteConfig:
		var cfg := RouteConfig.new()
		cfg.type_weights = type_weights.duplicate()
		for band in enemy_bands:
			cfg.enemy_bands.append(EnemyBand.new(band.max_row, band.weights.duplicate()))
		cfg.free_widths = free_widths.duplicate()
		cfg.safe_rows = safe_rows
		cfg.rest_window = rest_window
		cfg.shop_window = shop_window
		cfg.extra_edge_chance = extra_edge_chance
		return cfg

	## The plain-data form, with CONFIG's keys in CONFIG's order (what `RouteMap.to_dict()` saves).
	func to_dict() -> Dictionary:
		var weights := {}
		for type_key in type_weights:
			weights[type_key] = type_weights[type_key]
		var bands: Array = []
		for band in enemy_bands:
			bands.append(band.to_dict())
		var widths: Array = []
		for width in free_widths:
			widths.append(width)
		return {
			"type_weights": weights, "enemy_bands": bands, "free_widths": widths, "safe_rows": safe_rows,
			"rest_window": rest_window, "shop_window": shop_window, "extra_edge_chance": extra_edge_chance,
		}


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
var config := RouteConfig.new()
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


## `CONFIG` with the caller's overrides merged in, as a RouteConfig (the constant is never changed). Unknown keys
## and values of the wrong shape or range are ignored, so the result always has a usable value for every field;
## `config_problems()` lists what would be ignored. Same as `RouteConfig.from_overrides`.
static func make_config(overrides: Dictionary = {}) -> RouteConfig:
	return RouteConfig.from_overrides(overrides)


## What is wrong with the shape of a config dictionary (empty when `make_config` would use all of it).
## Unknown keys are not a problem; they are ignored. See RouteMapRules.config_problems.
static func config_problems(overrides: Dictionary) -> Array[String]:
	return RouteMapRules.config_problems(overrides)


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

## The chapter this map is for (1 unless it was generated for a later one): its backdrops come from that chapter's ChapterData.
var chapter: int = 1


## The EliteModifiers.Kind of elite node `id`, or -1 for any other node.
func elite_modifier(id: int) -> int:
	var n := node(id)
	if n == null or n.type != NodeType.ELITE or EliteModifiers.forced == EliteModifiers.FORCE_NONE:
		return -1
	return EliteModifiers.for_node(seed_value, id)


## Builds the map for `map_seed`. Same arguments, same map; uses its own RNG only. Config entries of the
## wrong shape fall back to the defaults (see `make_config`). If no attempt validates, the last map is
## returned with an error pushed, so a caller that checks `validate()` sees what is wrong. See RouteMapGenerator.
static func generate(map_seed: int, char_id: StringName, overrides: Dictionary = {}, chapter_number: int = 1) -> RouteMap:
	return RouteMapGenerator.generate(map_seed, char_id, overrides, chapter_number)


## The last window index (a position in `window_rows`) at which a window for `type` may end. The forced rest row
## satisfies the rest need itself, and the row before it holds neither a rest (it would sit next to the forced rest)
## nor a shop (a rest may not follow one), so both windows stop two rows before the end of the list.
static func window_last_index(_type: NodeType, window_count: int) -> int:
	return window_count - 3


## The backdrops of the most recent fight on each path into `id`, counting `id` itself when it is a fight.
## Walks back through rests, shops and story nodes. `memo` caches results; call it only for nodes whose
## ancestors already have their backdrops (the generator's backdrop pass and the backdrop rule use it).
func recent_backdrops(id: int, memo: Dictionary) -> Dictionary:
	if memo.has(id):
		return memo[id]
	var n := nodes[id]
	var result := {}
	if n.is_fight():
		if n.backdrop != &"":
			result[n.backdrop] = true
	else:
		for p in n.prev:
			for key in recent_backdrops(p, memo):
				result[key] = true
	memo[id] = result
	return result


# --- Validation -----------------------------------------------------------------------------------------

## Every broken rule, as readable strings; empty when the map is valid. A "line" map is only checked for
## graph shape and enemy counts (it is not meant to follow the generated layout). See RouteMapRules.
func validate() -> Array[String]:
	return RouteMapRules.validate(self)


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
		"config": config.to_dict(), "nodes": list,
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
	if data.has("seed") and not RouteMapRules.is_whole(data["seed"], -SEED_LIMIT, SEED_LIMIT):
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
		if not RouteMapRules.is_whole(d.get("id", i), i, i) or not RouteMapRules.is_whole(d.get("type"), 0, NodeType.EVENT) or not RouteMapRules.is_whole(d.get("row"), 0, last_row):
			return null
		if not RouteMapRules.is_whole(d.get("col", 0), 0, MAX_COLUMN) or not RouteMapRules.is_whole(d.get("enemy_count", 0), 0, 99):
			return null
		if not RouteMapRules.is_whole(d.get("beat_index", 0), 0, 99) or not RouteMapRules.is_whole(d.get("act", 0), 0, 9):
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
			if not RouteMapRules.is_whole(nxt, 0, raw.size() - 1):
				return null
			n.next.append(int(nxt))
		map.nodes.append(n)
	map.rebuild_rows()
	map.rebuild_links()
	return map


## Rebuilds the node ids by row (in column order) from the nodes' `row` and `col` fields. For code that builds a map.
func rebuild_rows() -> void:
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
## expressible. Fights get the line's destination backdrop where it has one. See RouteMapGenerator.from_line.
static func from_line(stops: Array) -> RouteMap:
	return RouteMapGenerator.from_line(stops)
