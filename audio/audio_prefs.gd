class_name AudioPrefs
extends RefCounted
## The player's volume choices. Kept inside user://settings.json under the "audio" key (see
## Settings), never in a run save. Every field is clamped; anything malformed falls back to the default.

const DEFAULT_MASTER := 0.8
const DEFAULT_MUSIC := 0.7
const DEFAULT_AMBIENCE := 0.7
const DEFAULT_SFX := 0.8

## Slider positions, 0.0 to 1.0.
var master := DEFAULT_MASTER
var music := DEFAULT_MUSIC
var ambience := DEFAULT_AMBIENCE
var sfx := DEFAULT_SFX
var muted := false


static func from_dict(data: Variant) -> AudioPrefs:
	var prefs := AudioPrefs.new()
	if typeof(data) != TYPE_DICTIONARY:
		return prefs
	var dict := data as Dictionary
	prefs.master = _level(dict.get("master"), DEFAULT_MASTER)
	prefs.music = _level(dict.get("music"), DEFAULT_MUSIC)
	prefs.ambience = _level(dict.get("ambience"), DEFAULT_AMBIENCE)
	prefs.sfx = _level(dict.get("sfx"), DEFAULT_SFX)
	if typeof(dict.get("muted")) == TYPE_BOOL:
		prefs.muted = dict["muted"]
	return prefs


func to_dict() -> Dictionary:
	return {"master": snappedf(master, 0.01), "music": snappedf(music, 0.01), "ambience": snappedf(ambience, 0.01), "sfx": snappedf(sfx, 0.01), "muted": muted}


static func _level(value: Variant, fallback: float) -> float:
	if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
		return fallback
	var number := float(value)
	if is_nan(number) or is_inf(number):
		return fallback
	return clampf(number, 0.0, 1.0)


## Loads the preferences from a settings file (the defaults when there are none).
static func load_from(path: String) -> AudioPrefs:
	return from_dict(Settings.load_file(path).audio)


## Writes the preferences into the settings file, keeping every other setting as it is.
## Returns "" on success, else why it failed.
func save_to(path: String) -> String:
	var settings := Settings.load_file(path)
	settings.audio = to_dict()
	return settings.save(path)
