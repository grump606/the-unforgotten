class_name Settings
extends RefCounted
## Player preferences kept in user://settings.json, apart from the run save. Today: whether the
## launch-time update check may contact GitHub (docs/UPDATE_CHECK.md). The file is untrusted
## input: it is size-capped and type-checked, and anything wrong falls back to the defaults
## instead of ever failing. Unknown keys are not interpreted but are kept in `extras` and written
## back by save, so a file written by a newer game version keeps its fields when this one saves.

const DEFAULT_PATH := "user://settings.json"
const MAX_FILE_BYTES := 4096
## Caps on the free-form parts, so that audio + extras + the known fields always fit MAX_FILE_BYTES: a larger
## section in a loaded file is dropped (the defaults apply) instead of making the next save unreadable.
const MAX_AUDIO_BYTES := 1024
const MAX_EXTRAS_BYTES := 2048

## Defaults to on, which is how the game behaved before this setting existed.
var update_check_enabled := true

## Volume preferences (see audio/audio_prefs.gd): the raw "audio" object from the file, empty until the
## player first changes a volume. It is only written back when non-empty, so a settings file from before
## audio existed is unchanged by a save that does not touch audio.
var audio := {}

## True once the first-launch tutorial has been shown (finished or skipped); it then only opens from the
## main menu's How to Play button.
var tutorial_seen := false

## Keys this version does not know, carried through load and save untouched.
var extras := {}


## Settings from parsed JSON. Anything that is not an object, or a field that is not a real
## boolean, leaves the default in place.
static func from_dict(data: Variant) -> Settings:
	var settings := Settings.new()
	if typeof(data) == TYPE_DICTIONARY:
		var dict := data as Dictionary
		var value: Variant = dict.get("update_check_enabled")
		if typeof(value) == TYPE_BOOL:
			settings.update_check_enabled = value
		if typeof(dict.get("tutorial_seen")) == TYPE_BOOL:
			settings.tutorial_seen = dict["tutorial_seen"]
		if typeof(dict.get("audio")) == TYPE_DICTIONARY:
			settings.audio = (dict["audio"] as Dictionary).duplicate(true)
			if _json_size(settings.audio) > MAX_AUDIO_BYTES:
				settings.audio = {}
		for key in dict:
			if key != "update_check_enabled" and key != "audio" and key != "tutorial_seen":
				settings.extras[key] = dict[key]
		if _json_size(settings.extras) > MAX_EXTRAS_BYTES:
			settings.extras = {}
	return settings


static func _json_size(value: Variant) -> int:
	return JSON.stringify(value).to_utf8_buffer().size()


static func to_dict(settings: Settings) -> Dictionary:
	var data := settings.extras.duplicate(true)
	data["update_check_enabled"] = settings.update_check_enabled
	if settings.tutorial_seen:
		data["tutorial_seen"] = true
	if not settings.audio.is_empty():
		data["audio"] = settings.audio
	return data


## Never fails: a missing, unreadable, oversized or damaged file falls back to path.bak, then to
## the defaults.
static func load_file(path: String = DEFAULT_PATH) -> Settings:
	var main := _read(path)
	if main != null:
		return main
	var backup := _read(path + ".bak")
	return backup if backup != null else Settings.new()


## The settings in one file, or null when it is missing, unreadable, oversized or not JSON.
static func _read(path: String) -> Settings:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	if file.get_length() > MAX_FILE_BYTES:
		file.close()
		return null
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return null
	return from_dict(json.data)


## Returns "" on success, else why it failed. Writes a temp file and renames it into place, so a
## crash mid-write never leaves a half-written settings file. The temp file is removed on every
## failure, and a file that currently parses is kept as path.bak (a damaged one never replaces it).
func save(path: String = DEFAULT_PATH) -> String:
	var text := JSON.stringify(to_dict(self))
	var text_bytes := text.to_utf8_buffer().size()
	if text_bytes > MAX_FILE_BYTES:
		# load_file would reject a file this big and silently reset every setting.
		return "settings too large to save (%d bytes, limit %d)" % [text_bytes, MAX_FILE_BYTES]
	var tmp := path + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		return "cannot write %s (error %d)" % [tmp, FileAccess.get_open_error()]
	file.store_string(text)
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		DirAccess.remove_absolute(tmp)
		return "write failed (error %d)" % write_error
	if Settings._read(path) != null:
		var bak := path + ".bak"
		if FileAccess.file_exists(bak):
			DirAccess.remove_absolute(bak)
		DirAccess.copy_absolute(path, bak)
	var rename_error := DirAccess.rename_absolute(tmp, path)
	if rename_error != OK:
		DirAccess.remove_absolute(tmp)
		return "cannot move settings into place (error %d)" % rename_error
	return ""
