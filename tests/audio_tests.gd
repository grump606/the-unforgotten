extends RefCounted
## Tests for audio/audio_prefs.gd and the audio part of run/settings.gd. Scratch paths only.
## Returns the failure count.

var _failures := 0
var _path := "user://audio_tests_%d.json" % OS.get_process_id()


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAIL: " + label)


func _cleanup() -> void:
	for p in [_path, _path + ".tmp", _path + ".bak"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


func run() -> int:
	_failures = 0
	_cleanup()
	var d := AudioPrefs.new()
	_check(is_equal_approx(d.master, AudioPrefs.DEFAULT_MASTER) and not d.muted, "defaults")
	_check(AudioPrefs.from_dict(null).music == AudioPrefs.DEFAULT_MUSIC, "non-object gives defaults")
	var odd := AudioPrefs.from_dict({"master": 7, "music": -3, "ambience": "loud", "sfx": null, "muted": "yes"})
	_check(odd.master == 1.0 and odd.music == 0.0, "levels are clamped")
	_check(odd.ambience == AudioPrefs.DEFAULT_AMBIENCE and odd.sfx == AudioPrefs.DEFAULT_SFX and not odd.muted, "wrong types fall back to defaults")
	_check(AudioPrefs.from_dict({"master": NAN}).master == AudioPrefs.DEFAULT_MASTER, "NaN falls back")

	# Settings: a file from before audio existed gains no audio key, and neither side clobbers the other.
	_check(Settings.to_dict(Settings.new()).size() == 1, "no audio key until a volume is chosen")
	var f := FileAccess.open(_path, FileAccess.WRITE)
	f.store_string("{\"update_check_enabled\": false, \"future\": [1]}")
	f.close()
	var mine := AudioPrefs.new()
	mine.music = 0.25
	mine.muted = true
	_check(mine.save_to(_path) == "", "audio prefs save")
	var after := Settings.load_file(_path)
	_check(not after.update_check_enabled and after.extras.has("future"), "audio save keeps the update setting and unknown keys")
	var back := AudioPrefs.load_from(_path)
	_check(is_equal_approx(back.music, 0.25) and back.muted and is_equal_approx(back.master, AudioPrefs.DEFAULT_MASTER), "prefs round-trip")
	after.update_check_enabled = true  # what the update toggle does: load, change, save
	_check(after.save(_path) == "", "settings save after audio")
	_check(is_equal_approx(AudioPrefs.load_from(_path).music, 0.25), "the update toggle keeps the audio prefs")
	_cleanup()
	return _failures
