class_name Settings
extends RefCounted
## Player preferences kept in user://settings.json, apart from the run save. Today: whether the
## launch-time update check may contact GitHub (docs/UPDATE_CHECK.md). The file is untrusted
## input: it is size-capped and type-checked, and anything wrong falls back to the defaults
## instead of ever failing. Unknown keys are ignored.

const DEFAULT_PATH := "user://settings.json"
const MAX_FILE_BYTES := 4096

## Defaults to on, which is how the game behaved before this setting existed.
var update_check_enabled := true


## Settings from parsed JSON. Anything that is not an object, or a field that is not a real
## boolean, leaves the default in place.
static func from_dict(data: Variant) -> Settings:
	var settings := Settings.new()
	if typeof(data) == TYPE_DICTIONARY:
		var value: Variant = (data as Dictionary).get("update_check_enabled")
		if typeof(value) == TYPE_BOOL:
			settings.update_check_enabled = value
	return settings


static func to_dict(settings: Settings) -> Dictionary:
	return {"update_check_enabled": settings.update_check_enabled}


## Never fails: a missing, unreadable, oversized or damaged file gives the defaults.
static func load_file(path: String = DEFAULT_PATH) -> Settings:
	if not FileAccess.file_exists(path):
		return Settings.new()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return Settings.new()
	if file.get_length() > MAX_FILE_BYTES:
		file.close()
		return Settings.new()
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return Settings.new()
	return from_dict(json.data)


## Returns "" on success, else why it failed. Writes a temp file and renames it into place, so a
## crash mid-write never leaves a half-written settings file.
func save(path: String = DEFAULT_PATH) -> String:
	var tmp := path + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		return "cannot write %s (error %d)" % [tmp, FileAccess.get_open_error()]
	file.store_string(JSON.stringify(to_dict(self)))
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		return "write failed (error %d)" % write_error
	var rename_error := DirAccess.rename_absolute(tmp, path)
	if rename_error != OK:
		return "cannot move settings into place (error %d)" % rename_error
	return ""
