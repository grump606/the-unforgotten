class_name RunSave
extends RefCounted
## Save and restore of an in-progress run, kept apart from RunState so the rules
## class stays pure. A save is written only at a stop boundary (RunState.
## at_stop_boundary: no fight, reward or vendor visit in flight), so it holds
## just the player, deck, gold, stop index and the run RNG position. A map run (RunState.uses_map,
## docs/MAP_DESIGN.md "Phase 3") also stores its route and where the player stands on it.
## A save file is untrusted input: from_dict / load_file validate every field and
## return a Result with an error message instead of ever failing.

## The newest format this game reads and writes. Line runs keep writing LINE_VERSION so a v4 reader
## (every release before map saves) can still load them; only a map run writes MAP_VERSION. A save
## above VERSION is rejected, a v2 to v4 save loads as a line run exactly as before.
const VERSION := 5
const LINE_VERSION := 4
const MAP_VERSION := 5
## The oldest format migrate() can upgrade. Anything older is rejected.
const MIN_VERSION := 2
## The Thief's id before it was renamed (releases up to 0.7.3); accepted on load and mapped to "thief".
const LEGACY_PICKPOCKET_ID := "pickpocket"
## A deck entry for a Remembered card is its id plus this suffix ("sleight+"); v4 and later.
const REMEMBERED_SUFFIX := "+"
const DEFAULT_PATH := "user://run_save.json"
const MAX_FILE_BYTES := 1048576
const MAX_HP := 10000
## Map saves only: events and chests pay amounts a fixed line cannot bound, so a map run's gold is capped here.
const MAX_GOLD := 1000000
## Max HP can only rise through a MAX_HP relic (Vendor.buy_relic; a rest stop heals but never raises it), so a
## genuine save holds the character's base HP plus the MAX_HP relics it carries. The slack lets a save made
## before a character's base HP was retuned still load; a hand-edited 9999 does not.
const MAX_HP_SLACK := 20
## The deck, gold and relic bounds below grow with how far the run has got (stop_index): what a genuine run
## could have collected by then, never what it happens to hold. They are tamper-resistance against absurd or
## hand-edited saves (a deck of 200 cards, a million gold), not security: anyone can still edit a save to the
## largest legitimate state for its stop.
## Slack on the card bounds for a retuned starting deck. Remembered copies count as the same card.
const DECK_COPY_SLACK := 2
## Slack on the relic bound, so a hand-built fixture or a retuned line still loads.
const RELIC_SLACK := 2
## Slack on the gold bound for a retuned economy (a save made before a payout changed must still load).
const GOLD_SLACK := 50
## Map saves only: the most cards an event can add in one row, on top of a shop's stock.
const MAP_ROW_EXTRA_CARDS := 2


class Result extends RefCounted:
	var run: RunState = null
	## Empty when `run` is valid.
	var error := ""
	## True when there was simply no save file (not worth a warning).
	var missing := false
	## The fallback file (path.tmp or path.bak) the run came from, "" when the main file loaded.
	## Set means the newest checkpoint could not be read and an older one is in use.
	var recovered_from := ""

	static func fail(why: String) -> Result:
		var result := Result.new()
		result.error = why
		return result


## The shape of the stop line, so a save made before the line changed is rejected instead of
## pointing stop_index at a different stop.
static func line_signature(run: RunState) -> String:
	var parts: Array[String] = []
	for stop in run.stops:
		parts.append("%d:%d:%d:%d:%d:%d" % [stop.type, stop.enemy_count, stop.beat_index, 1 if stop.boss else 0, 1 if stop.mid_boss else 0, stop.tier])
	return ",".join(parts)


static func to_dict(run: RunState) -> Dictionary:
	var ids: Array = []
	for card in run.deck:
		ids.append(String(card.id) + (REMEMBERED_SUFFIX if card.is_remembered else ""))
	var offered: Array = []
	for id in run.offered_ids:
		offered.append(String(id))
	var relic_ids: Array = []
	for relic in run.relics:
		relic_ids.append(String(relic.id))
	var data := {
		"version": MAP_VERSION if run.uses_map() else LINE_VERSION,
		"character": String(run.character.id),
		"hp": run.player.hp,
		"max_hp": run.player.max_hp,
		"gold": run.gold,
		"stop_index": run.stop_index,
		"line": line_signature(run),
		"deck": ids,
		"offered": offered,
		"reward_remove_used": run.reward_remove_used,
		"reward_heal_used": run.reward_heal_used,
		"relics": relic_ids,
		# A string: JSON numbers are doubles and would round a 64-bit state.
		"rng_state": str(run.rng_state()),
	}
	if run.uses_map():
		# The whole route, not its seed, so tuning the generator later never changes a saved run.
		data["map"] = run.route.to_dict()
		data["current_node"] = run.current_node
		data["visited"] = run.visited.duplicate()
		# True when the player is inside the current node's stop (saved on arrival), false at the map.
		data["at_node"] = run.in_map_stop()
		# The events shown so far (docs/EVENTS_DESIGN.md). An older v5 save has no such key and loads as empty.
		var seen_ids: Array = []
		for id in run.events_seen:
			seen_ids.append(String(id))
		data["events_seen"] = seen_ids
		data.erase("line") # the stop line does not exist in map mode (stops are placeholders)
	return data


## What the validators accepted, field by field. Typed so a misspelt field fails at parse time instead of
## reading a missing dictionary key; `known_cards` (the id -> card table) is the one the deck check hands on.
class Accepted extends RefCounted:
	var max_hp := 0
	var hp := 0
	var gold := 0
	var stop_index := 0
	var rng_state := ""
	var deck: Array[CardData] = []
	var offered: Array[StringName] = []
	var relics: Array[RelicData] = []
	var known_cards := {}
	## True for a map save (version >= MAP_VERSION); then the fields below are set by _check_map / _check_events_seen.
	var is_map := false
	var route: RouteMap = null
	var current_node := -1
	var visited: Array[int] = []
	var at_node := false
	var events_seen: Array[StringName] = []


static func from_dict(data: Variant) -> Result:
	if typeof(data) != TYPE_DICTIONARY:
		return Result.fail("save is not an object")
	var d: Dictionary = data
	var error := _check_header(d)
	if error != "":
		return Result.fail(error)
	d = migrate(d, _int(d, "version", 0, 1000000))
	var character_id: Variant = d.get("character")
	# Saves from releases up to 0.7.3 name the Thief by its old id. Same format, so no version bump.
	if typeof(character_id) == TYPE_STRING and character_id == LEGACY_PICKPOCKET_ID:
		character_id = "thief"
	error = _check_character(character_id)
	if error != "":
		return Result.fail(error)
	var run := RunState.new(0, StringName(character_id))
	if run.character.id != StringName(character_id):
		return Result.fail("character content failed to load")
	# Each validator stores what it accepts in `got` and returns why a field was rejected ("" if fine).
	# The order matters: the deck check leaves the card table the offered check needs.
	var got := Accepted.new()
	got.is_map = _int(d, "version", 0, 1000000) >= MAP_VERSION
	var checks: Array[Callable] = [_check_line_and_stop]
	if got.is_map:
		checks.append(_check_map)
	for later in [_check_relics, _check_numbers, _check_rng_state, _check_deck, _check_offered, _check_events_seen]:
		checks.append(later)
	for check in checks:
		error = check.call(d, run, got)
		if error != "":
			return Result.fail(error)
	run.relics = got.relics
	run.events_seen.assign(got.events_seen)
	run.offered_ids = got.offered
	run.reward_remove_used = d["reward_remove_used"]
	run.reward_heal_used = d["reward_heal_used"]
	run.player = Combatant.new(run.character.display_name, got.max_hp, got.hp)
	run.deck = got.deck
	run.gold = got.gold
	run.stop_index = got.stop_index
	if got.is_map:
		run.restore_map(got.route, got.current_node, got.visited, got.at_node)
	run.restore_rng_state(got.rng_state.to_int())
	return _ok(run)


## Version gate. Returns "" when the save's format can be read (after migrate()).
static func _check_header(d: Dictionary) -> String:
	var version: Variant = _int(d, "version", 0, 1000000)
	if version == null:
		return "save has no valid version"
	if version > VERSION:
		return "this save was made by a newer version of the game (save format %d, this game reads up to %d)" % [version, VERSION]
	if version < MIN_VERSION:
		return "this save was made by an older version of the game that can no longer be read (save format %d, this game reads %d to %d)" % [version, MIN_VERSION, VERSION]
	return ""


static func _check_character(character_id: Variant) -> String:
	if typeof(character_id) != TYPE_STRING or not StarterContent.CHARACTER_PATHS.has(StringName(character_id)):
		return "this save names a character that no longer exists"
	return ""


## The largest max HP a genuine save of `run`'s character can hold on reaching `stop_index`: its base HP, the MAX_HP
## relics it carries and the most max HP the events it could have met by then can give (see `event_max_hp_gain`).
static func max_hp_allowed(run: RunState, relics: Array[RelicData], stop_index: int = 0, is_map: bool = false) -> int:
	var total := run.character.max_hp + MAX_HP_SLACK
	for relic in relics:
		if relic.kind == RelicData.Kind.MAX_HP:
			total += relic.amount
	total += event_max_hp_gain(_events_before(run, stop_index, is_map))
	return mini(total, MAX_HP)


## How many event stops a run could have settled before `stop_index`: on a map any row may hold one (the row of the
## save is the arrival at a node, not yet settled); on a line, the EVENT stops before it.
static func _events_before(run: RunState, stop_index: int, is_map: bool) -> int:
	if is_map:
		return maxi(stop_index, 0)
	var count := 0
	for i in mini(stop_index, run.stops.size()):
		if run.stops[i].type == RunState.StopType.EVENT:
			count += 1
	return count


## The most max HP `visits` event stops can give, read from the event data: each event gives at most the best of its
## buttons (a gamble counts its better branch), and an event is not shown again until every other one was seen, so the
## visits take the richest events first, a full round of all of them at a time.
static func event_max_hp_gain(visits: int) -> int:
	if visits <= 0:
		return 0
	var gains: Array[int] = []
	for event in StarterContent.all_events():
		var best := 0
		for choice in event.choices:
			best = maxi(best, _max_hp_rise(choice.effects))
		gains.append(best)
	if gains.is_empty():
		return 0
	gains.sort()
	gains.reverse()
	var total := 0
	for i in visits:
		total += gains[i % gains.size()]
	return total


static func _max_hp_rise(effects: Array[EventEffect]) -> int:
	var rise := 0
	for effect in effects:
		if effect.kind == EventEffect.Kind.MAX_HP and effect.amount > 0:
			rise += effect.amount
		elif effect.kind == EventEffect.Kind.GAMBLE:
			rise += maxi(_max_hp_rise(effect.win), _max_hp_rise(effect.lose))
	return rise


## Cards a genuine run can have gained before `stop_index`: one reward pick per fight won (a boss win ends the
## run, so no save follows it) and the vendor's whole stock for every vendor visited.
static func _cards_gained_before(run: RunState, stop_index: int, is_map: bool = false) -> int:
	if is_map:
		# A map run has no fixed line: any row may hold a shop (the whole stock) or an event, so allow the most
		# any one row can add.
		return (stop_index + 1) * (Vendor.STOCK_CARDS + MAP_ROW_EXTRA_CARDS)
	var total := 0
	for i in mini(stop_index, run.stops.size()):
		var stop := run.stops[i]
		if stop.type == RunState.StopType.COMBAT:
			total += 1
		elif stop.type == RunState.StopType.VENDOR:
			total += Vendor.STOCK_CARDS
	return total


## The most cards a genuine run of `run`'s line could hold on reaching `stop_index` (see DECK_COPY_SLACK).
static func max_deck(run: RunState, stop_index: int, is_map: bool = false) -> int:
	return StarterContent.starter_deck(run.character.id).size() + _cards_gained_before(run, stop_index, is_map) + DECK_COPY_SLACK


## The most copies of one card a genuine run of `run`'s line could hold on reaching `stop_index`: the starting
## copies plus every card it could have gained (see DECK_COPY_SLACK).
static func max_copies(run: RunState, card_id: StringName, stop_index: int, is_map: bool = false) -> int:
	var total := DECK_COPY_SLACK + _cards_gained_before(run, stop_index, is_map)
	for card in StarterContent.starter_deck(run.character.id):
		if card.id == card_id:
			total += 1
	return total


## The most gold a genuine run could hold on reaching `stop_index` if it never spent any: each fight won pays
## its gold (plus the mid-boss bonus and any win-gold relic carried) and a skipped reward pays SKIP_GOLD.
static func max_gold(run: RunState, stop_index: int, relics: Array[RelicData], is_map: bool = false) -> int:
	if is_map:
		return MAX_GOLD # events and chests pay in amounts a fixed line cannot bound
	var per_win := 0
	for relic in relics:
		if relic.kind == RelicData.Kind.WIN_GOLD:
			per_win += relic.amount
	var total := GOLD_SLACK
	for i in mini(stop_index, run.stops.size()):
		var stop := run.stops[i]
		if stop.type == RunState.StopType.COMBAT and not stop.boss:
			total += Vendor.gold_for_win(stop.enemy_count) + (RunState.MID_BOSS_GOLD_BONUS if stop.mid_boss else 0) + per_win + RunState.SKIP_GOLD
	return total


## Relics a genuine run can carry on reaching `stop_index`: a vendor offers at most one per visit (plus RELIC_SLACK).
static func max_relics(run: RunState, stop_index: int, is_map: bool = false) -> int:
	if is_map:
		return stop_index + 1 + RELIC_SLACK # at most one relic per row (a shop offer, a chest or an event)
	var visits := RELIC_SLACK
	for i in mini(stop_index, run.stops.size()):
		if run.stops[i].type == RunState.StopType.VENDOR:
			visits += 1
	return visits


## The stop line and stop_index, first because the relic, gold and deck bounds all depend on how far the run got.
static func _check_line_and_stop(d: Dictionary, run: RunState, got: Accepted) -> String:
	if not got.is_map:
		var line: Variant = d.get("line")
		if typeof(line) != TYPE_STRING or line != line_signature(run):
			return "this save is from an older version of the game's route and cannot be continued"
	var stop_index: Variant = _int(d, "stop_index", 0, (RouteMap.ROWS if got.is_map else run.stops.size()) - 1)
	if stop_index == null:
		return "bad stop_index"
	got.stop_index = stop_index
	return ""


## max_hp, hp and gold. hp is bounded by max_hp, so that order stays. Needs the relics (max_hp and gold are
## bounded by them) and the stop_index, so _check_relics and _check_line_and_stop run first.
static func _check_numbers(d: Dictionary, run: RunState, got: Accepted) -> String:
	var max_hp: Variant = _int(d, "max_hp", 1, max_hp_allowed(run, got.relics, got.stop_index, got.is_map))
	if max_hp == null:
		return "bad max_hp"
	var hp: Variant = _int(d, "hp", 1, max_hp)
	if hp == null:
		return "bad hp"
	var gold: Variant = _int(d, "gold", 0, max_gold(run, got.stop_index, got.relics, got.is_map))
	if gold == null:
		return "bad gold"
	got.max_hp = max_hp
	got.hp = hp
	got.gold = gold
	return ""


## A map save's route and position (v5). The route must be a well-formed, valid generated map for this
## character; the player's place must be consistent with it: no node yet (nothing visited, row 0), or a
## current node reached by a connected path of one node per row from the first row, with stop_index its
## row. Between stops (`at_node` false) the current node must have somewhere to go; a run past its last
## row is finished and is never saved.
static func _check_map(d: Dictionary, run: RunState, got: Accepted) -> String:
	var raw_map: Variant = d.get("map")
	if typeof(raw_map) != TYPE_DICTIONARY:
		return "this save has no route map"
	var route := RouteMap.from_dict(raw_map)
	if route == null:
		return "the saved route map is damaged"
	if route.kind != RouteMap.KIND_GENERATED or route.row_count() != RouteMap.ROWS:
		return "the saved route map is not a full journey"
	if route.character_id != run.character.id:
		return "the saved route map belongs to a different character"
	var problems := route.validate()
	if not problems.is_empty():
		return "the saved route map is invalid (%s)" % problems[0]
	var current: Variant = _int(d, "current_node", -1, route.node_count() - 1)
	if current == null:
		return "bad current_node"
	var raw_visited: Variant = d.get("visited")
	if typeof(raw_visited) != TYPE_ARRAY or (raw_visited as Array).size() > RouteMap.ROWS:
		return "bad visited list"
	var visited: Array[int] = []
	for entry in raw_visited:
		var id: Variant = _int({"id": entry}, "id", 0, route.node_count() - 1)
		if id == null:
			return "visited list names a node that is not on the map"
		visited.append(id)
	if typeof(d.get("at_node")) != TYPE_BOOL:
		return "bad at_node"
	var at_node: bool = d["at_node"]
	if current == -1:
		if not visited.is_empty() or at_node or got.stop_index != 0:
			return "this save has not chosen a node yet but records progress"
	else:
		var row: int = route.node(current).row
		if visited.size() != row + 1 or visited[visited.size() - 1] != current or got.stop_index != row:
			return "the visited path does not end at the current node"
		for i in visited.size():
			if route.node(visited[i]).row != i:
				return "the visited path skips or repeats a row"
			if i == 0:
				if not route.starts().has(visited[0]):
					return "the visited path does not begin on the first row"
			elif not route.next_ids(visited[i - 1]).has(visited[i]):
				return "the visited path uses a road that is not on the map"
		if not at_node and route.next_ids(current).is_empty():
			return "this save is past the last row of the map"
	got.route = route
	got.current_node = current
	got.visited = visited
	got.at_node = at_node
	return ""


## True only for the exact text str() gives an int64: no padding, no plus sign, nothing outside
## int64. Anything else would silently become a different state through to_int().
static func _is_canonical_int64_text(text: String) -> bool:
	var max_length := 20 if text.begins_with("-") else 19
	return text.length() <= max_length and str(text.to_int()) == text


static func _check_rng_state(d: Dictionary, _run: RunState, got: Accepted) -> String:
	var rng_text: Variant = d.get("rng_state")
	if typeof(rng_text) != TYPE_STRING or not _is_canonical_int64_text(rng_text):
		return "bad rng_state"
	got.rng_state = rng_text
	return ""


## Also leaves the id -> card table in `got` for the offered check.
static func _check_deck(d: Dictionary, run: RunState, got: Accepted) -> String:
	var raw_deck: Variant = d.get("deck")
	if typeof(raw_deck) != TYPE_ARRAY or (raw_deck as Array).is_empty() or (raw_deck as Array).size() > max_deck(run, got.stop_index, got.is_map):
		return "bad deck"
	var known := {}
	for card in StarterContent.vendor_pool(run.character.id):
		known[String(card.id)] = card
	if known.is_empty():
		return "card content failed to load"
	# The deck may also hold a status card (Dread, Murmur) an event put there as a curse. It is not in any pool, so
	# it is kept apart from `known` (the offered list is checked against the pool only).
	var deck_cards := known.duplicate()
	for status_id in StarterContent.STATUS_CARD_PATHS:
		var status := StarterContent.status_card(status_id)
		if status == null:
			return "card content failed to load"
		deck_cards[String(status_id)] = status
	var deck: Array[CardData] = []
	var copies := {}
	for entry in raw_deck:
		if typeof(entry) != TYPE_STRING:
			return "this save contains a card that no longer exists"
		var entry_id: String = entry
		var upgraded := entry_id.ends_with(REMEMBERED_SUFFIX)
		if upgraded:
			entry_id = entry_id.trim_suffix(REMEMBERED_SUFFIX)
		if not deck_cards.has(entry_id):
			return "this save contains a card that no longer exists"
		var card: CardData = deck_cards[entry_id]
		if upgraded:
			var variant := card.remembered_card()
			if variant == null:
				return "this save marks a card as Remembered that cannot be"
			card = variant
		deck.append(card)
		copies[entry_id] = copies.get(entry_id, 0) + 1
		if copies[entry_id] > max_copies(run, card.id, got.stop_index, got.is_map):
			return "this save holds more copies of a card than a run can collect"
	got.known_cards = known
	got.deck = deck
	return ""


## The offered list and the two reward flags. These are required in v3 (migrate() supplies them
## for v2 saves).
static func _check_offered(d: Dictionary, _run: RunState, got: Accepted) -> String:
	var known: Dictionary = got.known_cards
	var offered: Array[StringName] = []
	var raw_offered: Variant = d.get("offered")
	if typeof(raw_offered) != TYPE_ARRAY or (raw_offered as Array).size() > known.size():
		return "bad offered list"
	for entry in raw_offered:
		if typeof(entry) != TYPE_STRING or not known.has(entry) or offered.has(StringName(entry)):
			return "offered list has an unknown or repeated card"
		offered.append(StringName(entry))
	for key in ["reward_remove_used", "reward_heal_used"]:
		if typeof(d.get(key)) != TYPE_BOOL:
			return "bad %s" % key
	got.offered = offered
	return ""


## The events already shown (map saves). Absent in a save from before events: empty. Entries must be strings; ones that
## are not a known event id are dropped and repeats are kept once, so retiring an event never invalidates a save.
static func _check_events_seen(d: Dictionary, _run: RunState, got: Accepted) -> String:
	var seen: Array[StringName] = []
	if got.is_map and d.has("events_seen"):
		var raw: Variant = d["events_seen"]
		if typeof(raw) != TYPE_ARRAY or (raw as Array).size() > 200:
			return "bad events_seen list"
		var known_ids := {}
		for event in StarterContent.all_events():
			known_ids[String(event.id)] = true
		for entry in raw:
			if typeof(entry) != TYPE_STRING:
				return "bad events_seen list"
			if known_ids.has(entry) and not seen.has(StringName(entry)):
				seen.append(StringName(entry))
	got.events_seen = seen
	return ""


## The saved max HP already includes any MAX_HP relic, so restoring the relic list must not apply
## it again.
static func _check_relics(d: Dictionary, run: RunState, got: Accepted) -> String:
	var relics: Array[RelicData] = []
	var raw_relics: Variant = d.get("relics")
	var known_relics := {}
	for relic in StarterContent.relic_pool(run.character.id):
		known_relics[String(relic.id)] = relic
	if typeof(raw_relics) != TYPE_ARRAY or (raw_relics as Array).size() > mini(known_relics.size(), max_relics(run, got.stop_index, got.is_map)):
		return "bad relics list"
	for entry in raw_relics:
		if typeof(entry) != TYPE_STRING or not known_relics.has(entry) or relics.has(known_relics[entry]):
			return "this save contains a relic that no longer exists, or the same relic twice"
		relics.append(known_relics[entry])
	got.relics = relics
	return ""


## Upgrades a save dict of `version` to the current format, returning a copy. A v2 save may lack
## the fields v3 requires; a run that lacks them had seen no rewards, used neither reward
## alternative and bought no relics. Fields that are present are left for validation to judge.
## A v5 save (a map run) needs no upgrade.
static func migrate(data: Dictionary, version: int) -> Dictionary:
	var d := data.duplicate()
	if version < 3:
		for key in ["offered", "relics"]:
			if not d.has(key):
				d[key] = []
		for key in ["reward_remove_used", "reward_heal_used"]:
			if not d.has(key):
				d[key] = false
		d["version"] = 3
	if version < 4:
		# v4 only adds the "+" suffix on Remembered deck entries; a v3 deck has none and reads as is.
		d["version"] = 4
	return d


## Returns "" on success, else why the save failed. Validates the run through from_dict first and writes nothing
## when it would not load again. Writes a complete temp file, keeps the previous
## good save as path.bak, then moves the temp into place. Windows removes the destination before
## renaming, so a crash in between leaves path.tmp and path.bak, which load_file recovers.
static func save(run: RunState, path: String = DEFAULT_PATH) -> String:
	if not run.at_stop_boundary():
		return "run is not at a stop boundary"
	# Refuse a run that would not load again, before touching the file, the .tmp or the .bak: the player keeps the
	# last save that works instead of a newer one that does not.
	var data := to_dict(run)
	var check := from_dict(data)
	if check.run == null:
		return "run would not load again: %s" % check.error
	var tmp := path + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		return "cannot write %s (error %d)" % [tmp, FileAccess.get_open_error()]
	file.store_string(JSON.stringify(data))
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		DirAccess.remove_absolute(tmp)
		return "write failed (error %d)" % write_error
	# Only a valid current save becomes the backup, so a damaged file never replaces a good .bak.
	if FileAccess.file_exists(path) and _read(path).run != null:
		var bak := path + ".bak"
		# A failed refresh must not block the new save; an older .bak (if any) stays usable.
		if FileAccess.file_exists(bak):
			var remove_error := DirAccess.remove_absolute(bak)
			if remove_error != OK:
				push_warning("RunSave: could not remove old backup %s (error %d)" % [bak, remove_error])
		var copy_error := DirAccess.copy_absolute(path, bak)
		if copy_error != OK:
			push_warning("RunSave: could not refresh backup %s (error %d)" % [bak, copy_error])
	var rename_error := DirAccess.rename_absolute(tmp, path)
	if rename_error != OK:
		return "cannot move save into place (error %d)" % rename_error
	return ""


## Loads the save, falling back to a complete path.tmp and then path.bak when the main file is
## missing or damaged. Every candidate passes the same validation.
static func load_file(path: String = DEFAULT_PATH) -> Result:
	var main := _read(path)
	if main.run != null:
		return main
	var report := main
	for suffix in [".tmp", ".bak"]:
		var candidate: String = path + suffix
		if not FileAccess.file_exists(candidate):
			continue
		var fallback := _read(candidate)
		if fallback.run != null:
			fallback.recovered_from = candidate
			return fallback
		if report.missing:
			report = fallback
	return report


## Reads and validates one file.
static func _read(path: String) -> Result:
	if not FileAccess.file_exists(path):
		var none := Result.new()
		none.missing = true
		none.error = "no save"
		return none
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return Result.fail("cannot read save (error %d)" % FileAccess.get_open_error())
	if file.get_length() > MAX_FILE_BYTES:
		return Result.fail("save file is too large")
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return Result.fail("the save file is damaged (not valid JSON)")
	return from_dict(json.data)


## Returns "" on success (or when there was nothing to delete), else why it failed. Also removes
## path.tmp and path.bak so a finished run cannot be recovered from them.
static func delete(path: String = DEFAULT_PATH) -> String:
	var failure := ""
	for candidate in [path, path + ".tmp", path + ".bak"]:
		if FileAccess.file_exists(candidate):
			var error := DirAccess.remove_absolute(candidate)
			if error != OK and failure == "":
				failure = "cannot delete save (error %d)" % error
	return failure


## The integer at `key` within [low, high], or null. JSON numbers arrive as floats.
static func _int(d: Dictionary, key: String, low: int, high: int) -> Variant:
	var value: Variant = d.get(key)
	if typeof(value) == TYPE_FLOAT:
		var f: float = value
		if f != floorf(f) or absf(f) > 1.0e15:
			return null
		value = int(f)
	if typeof(value) != TYPE_INT:
		return null
	if value < low or value > high:
		return null
	return value


static func _ok(run: RunState) -> Result:
	var result := Result.new()
	result.run = run
	return result
