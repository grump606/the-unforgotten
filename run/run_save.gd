class_name RunSave
extends RefCounted
## Save and restore of an in-progress run, kept apart from RunState so the rules
## class stays pure. A save is written only at a stop boundary (RunState.
## at_stop_boundary: no fight, reward or vendor visit in flight), so it holds
## just the player, deck, gold, stop index and the run RNG position.
## A save file is untrusted input: from_dict / load_file validate every field and
## return a Result with an error message instead of ever failing.

const VERSION := 3
## The oldest format migrate() can upgrade. Anything older is rejected.
const MIN_VERSION := 2
const DEFAULT_PATH := "user://run_save.json"
const MAX_FILE_BYTES := 1048576
const MAX_DECK := 200
const MAX_GOLD := 1000000
const MAX_HP := 10000


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
		ids.append(String(card.id))
	var offered: Array = []
	for id in run.offered_ids:
		offered.append(String(id))
	var relic_ids: Array = []
	for relic in run.relics:
		relic_ids.append(String(relic.id))
	return {
		"version": VERSION,
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


static func from_dict(data: Variant) -> Result:
	if typeof(data) != TYPE_DICTIONARY:
		return Result.fail("save is not an object")
	var d: Dictionary = data
	var error := _check_header(d)
	if error != "":
		return Result.fail(error)
	d = migrate(d, _int(d, "version", 0, 1000000))
	var character_id: Variant = d.get("character")
	error = _check_character(character_id)
	if error != "":
		return Result.fail(error)
	var run := RunState.new(0, StringName(character_id))
	if run.character.id != StringName(character_id):
		return Result.fail("character content failed to load")
	# Each validator stores what it accepts in `got` and returns why a field was rejected ("" if fine).
	# The order matters: the deck check leaves the card table the offered check needs.
	var got := {}
	for check in [_check_numbers, _check_rng_state, _check_deck, _check_offered, _check_relics]:
		error = check.call(d, run, got)
		if error != "":
			return Result.fail(error)
	run.relics = got["relics"]
	run.offered_ids = got["offered"]
	run.reward_remove_used = d["reward_remove_used"]
	run.reward_heal_used = d["reward_heal_used"]
	run.player = Combatant.new(run.character.display_name, got["max_hp"], got["hp"])
	run.deck = got["deck"]
	run.gold = got["gold"]
	run.stop_index = got["stop_index"]
	run.restore_rng_state((got["rng_state"] as String).to_int())
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


## max_hp, hp, gold, the stop line and stop_index. hp is bounded by max_hp, so that order stays.
static func _check_numbers(d: Dictionary, run: RunState, got: Dictionary) -> String:
	var max_hp: Variant = _int(d, "max_hp", 1, MAX_HP)
	if max_hp == null:
		return "bad max_hp"
	var hp: Variant = _int(d, "hp", 1, max_hp)
	if hp == null:
		return "bad hp"
	var gold: Variant = _int(d, "gold", 0, MAX_GOLD)
	if gold == null:
		return "bad gold"
	var line: Variant = d.get("line")
	if typeof(line) != TYPE_STRING or line != line_signature(run):
		return "this save is from an older version of the game's route and cannot be continued"
	var stop_index: Variant = _int(d, "stop_index", 0, run.stops.size() - 1)
	if stop_index == null:
		return "bad stop_index"
	got["max_hp"] = max_hp
	got["hp"] = hp
	got["gold"] = gold
	got["stop_index"] = stop_index
	return ""


## True only for the exact text str() gives an int64: no padding, no plus sign, nothing outside
## int64. Anything else would silently become a different state through to_int().
static func _is_canonical_int64_text(text: String) -> bool:
	var max_length := 20 if text.begins_with("-") else 19
	return text.length() <= max_length and str(text.to_int()) == text


static func _check_rng_state(d: Dictionary, _run: RunState, got: Dictionary) -> String:
	var rng_text: Variant = d.get("rng_state")
	if typeof(rng_text) != TYPE_STRING or not _is_canonical_int64_text(rng_text):
		return "bad rng_state"
	got["rng_state"] = rng_text
	return ""


## Also leaves the id -> card table in `got` for the offered check.
static func _check_deck(d: Dictionary, run: RunState, got: Dictionary) -> String:
	var raw_deck: Variant = d.get("deck")
	if typeof(raw_deck) != TYPE_ARRAY or (raw_deck as Array).is_empty() or (raw_deck as Array).size() > MAX_DECK:
		return "bad deck"
	var known := {}
	for card in StarterContent.reward_pool(run.character.id):
		known[String(card.id)] = card
	if known.is_empty():
		return "card content failed to load"
	var deck: Array[CardData] = []
	for entry in raw_deck:
		if typeof(entry) != TYPE_STRING or not known.has(entry):
			return "this save contains a card that no longer exists"
		deck.append(known[entry])
	got["known_cards"] = known
	got["deck"] = deck
	return ""


## The offered list and the two reward flags. These are required in v3 (migrate() supplies them
## for v2 saves).
static func _check_offered(d: Dictionary, _run: RunState, got: Dictionary) -> String:
	var known: Dictionary = got["known_cards"]
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
	got["offered"] = offered
	return ""


## The saved max HP already includes any MAX_HP relic, so restoring the relic list must not apply
## it again.
static func _check_relics(d: Dictionary, run: RunState, got: Dictionary) -> String:
	var relics: Array[RelicData] = []
	var raw_relics: Variant = d.get("relics")
	var known_relics := {}
	for relic in StarterContent.relic_pool(run.character.id):
		known_relics[String(relic.id)] = relic
	if typeof(raw_relics) != TYPE_ARRAY or (raw_relics as Array).size() > known_relics.size():
		return "bad relics list"
	for entry in raw_relics:
		if typeof(entry) != TYPE_STRING or not known_relics.has(entry) or relics.has(known_relics[entry]):
			return "this save contains a relic that no longer exists, or the same relic twice"
		relics.append(known_relics[entry])
	got["relics"] = relics
	return ""


## Upgrades a save dict of `version` to the current format, returning a copy. A v2 save may lack
## the fields v3 requires; a run that lacks them had seen no rewards, used neither reward
## alternative and bought no relics. Fields that are present are left for validation to judge.
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
	return d


## Returns "" on success, else why the save failed. Writes a complete temp file, keeps the previous
## good save as path.bak, then moves the temp into place. Windows removes the destination before
## renaming, so a crash in between leaves path.tmp and path.bak, which load_file recovers.
static func save(run: RunState, path: String = DEFAULT_PATH) -> String:
	if not run.at_stop_boundary():
		return "run is not at a stop boundary"
	var tmp := path + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		return "cannot write %s (error %d)" % [tmp, FileAccess.get_open_error()]
	file.store_string(JSON.stringify(to_dict(run)))
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
