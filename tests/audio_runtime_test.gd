extends SceneTree
## Plays the real streams (on the Dummy audio driver) and checks the manager: buses, no restart on a
## repeated scene, one track per channel once a fade ends, crossfade overlap, effect merging, mute,
## saved preferences, pause ducking, and that the loops are set to repeat.
## Run: godot --headless --audio-driver Dummy --path . -s res://tests/audio_runtime_test.gd

const TestBase := preload("res://tests/test_base.gd")

var _failures := 0
var _scratch := "user://audio_runtime_%d.json" % OS.get_process_id()


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAIL: " + label)


func _initialize() -> void:
	TestBase.remove_scratch(_scratch)
	_run.call_deferred()


func _music_db() -> float:
	return AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))


## Waits frame by frame until `condition` is true (a state to reach, not a time to sit through), so a slow or
## loaded machine just takes longer. `max_seconds` only bounds a hang: reaching it is a failure of the check that follows.
func _wait_until(condition: Callable, max_seconds := 30.0) -> bool:
	var started := Time.get_ticks_msec()
	while not condition.call():
		if Time.get_ticks_msec() - started > int(max_seconds * 1000.0):
			return false
		await process_frame
	return true


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _run() -> void:
	var audio := root.get_node_or_null("AudioManager")
	_check(audio != null, "AudioManager autoload exists")
	if audio == null:
		quit(1)
		return
	audio.settings_path = _scratch
	audio.playback_enabled = true
	for bus in ["Music", "Ambience", "SFX"]:
		var index := AudioServer.get_bus_index(bus)
		_check(index != -1 and AudioServer.get_bus_send(index) == &"Master", "%s bus feeds Master" % bus)
	for path in audio.MUSIC.values() + audio.AMBIENCE.values():
		var stream := load(path) as AudioStreamOggVorbis
		_check(stream != null and stream.loop and stream.get_length() > 30.0, "%s loads and loops" % path)
	for id in audio.SFX:
		_check(load(audio.SFX[id][0]) is AudioStream, "effect %s loads" % id)
	var credits: String = audio.credits_text()
	_check(credits.contains("Pixabay") and credits.contains("Kenney") and credits.contains("AI generated"), "credits file is readable")

	audio.set_scene(&"menu", &"coastal")
	await _wait_until(func() -> bool: return audio.music_channel.playing_count() == 1 and audio.ambience_channel.playing_count() == 1)
	_check(audio.music_channel.playing_count() == 1 and audio.ambience_channel.playing_count() == 1, "menu music and ambience start")
	_check(not audio.music_channel.play(&"menu", null, true), "asking for the playing track does nothing")
	audio.set_scene(&"menu", &"coastal")
	await _frames(10)
	_check(audio.music_channel.playing_count() == 1, "repeated scene does not start a second copy")
	var menu_player: AudioStreamPlayer = audio.music_channel._current

	audio.set_scene(&"combat", &"coastal")
	await _wait_until(func() -> bool: return audio.music_channel.playing_count() == 2, 5.0)
	_check(audio.music_channel.playing_count() == 2, "crossfade overlaps exactly two tracks")
	await _wait_until(func() -> bool: return audio.music_channel.playing_count() == 1 and audio.music_channel.current_id == &"combat")
	_check(audio.music_channel.playing_count() == 1 and audio.music_channel.current_id == &"combat", "old track stopped after the fade")
	_check(not menu_player.playing, "the menu player was released")
	for i in 12:
		audio.set_scene(&"menu" if i % 2 == 0 else &"combat", &"" if i % 3 == 0 else &"coastal")
		await _frames(3)
	await _wait_until(func() -> bool: return audio.music_channel.playing_count() == 1 and audio.ambience_channel.playing_count() <= 1)
	_check(audio.music_channel.playing_count() == 1, "rapid scene changes leave one music track")
	_check(audio.ambience_channel.playing_count() <= 1, "rapid scene changes leave at most one ambience")
	audio.set_scene(&"menu", &"")
	await _wait_until(func() -> bool: return audio.ambience_channel.playing_count() == 0)
	_check(audio.ambience_channel.playing_count() == 0, "ambience fades out when a scene has none")

	audio.sfx_log.clear()
	audio.sfx(&"click")
	audio.sfx(&"reward")
	audio.sfx(&"click")
	audio.flush()
	_check(audio.sfx_log == [&"reward"], "one effect per frame, highest priority wins")
	audio.sfx(&"reward")
	audio.flush()
	_check(audio.sfx_log.size() == 1, "an immediate repeat is dropped")
	audio.sfx(&"nonsense")
	audio.flush()
	_check(audio.sfx_log.size() == 1, "unknown effect ids are ignored")

	var master := AudioServer.get_bus_index("Master")
	audio.set_music(0.0)
	_check(_music_db() <= -79.0 + audio.MUSIC_TRIM_DB, "music slider at zero is silent")
	audio.set_music(0.4)
	audio.set_muted(true)
	_check(AudioServer.is_bus_mute(master), "mute mutes the master bus")
	audio.set_muted(false)
	_check(not AudioServer.is_bus_mute(master), "unmute restores it")
	audio.save_now()
	var saved := AudioPrefs.load_from(_scratch)
	_check(is_equal_approx(saved.music, 0.4) and not saved.muted, "volume choice reached the settings file")
	var normal := _music_db()
	audio.set_paused_duck(true)
	await _wait_until(func() -> bool: return _music_db() < normal - 5.0)
	_check(_music_db() < normal - 5.0, "pause ducks the music")
	audio.set_paused_duck(false)
	await _wait_until(func() -> bool: return is_equal_approx(_music_db(), normal))
	_check(is_equal_approx(_music_db(), normal), "unpausing restores the music level")

	audio.set_music(1.0)
	audio.set_scene(&"combat", &"")
	var peak := [-200.0]  # an array: a lambda copies plain numbers, but shares an array
	var hears_sound := func() -> bool:
		peak[0] = maxf(peak[0], AudioServer.get_bus_peak_volume_left_db(master, 0))
		return peak[0] > -60.0
	await _wait_until(hears_sound, 10.0)
	_check(peak[0] > -60.0, "sound reaches the master bus (peak %.1f dB)" % peak[0])

	# Flush any pending prefs save first: the manager would otherwise write the scratch file again
	# when it is freed at exit, after the cleanup below, and leave an orphan behind.
	audio.save_now()
	TestBase.remove_scratch(_scratch)
	print("AUDIO RUNTIME %s" % ("FAILED" if _failures > 0 else "OK"))
	quit(1 if _failures > 0 else 0)
