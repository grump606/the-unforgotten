extends SceneTree
## Plays the real streams (on the Dummy audio driver) and checks the manager: buses, no restart on a
## repeated scene, one track per channel once a fade ends, crossfade overlap, effect merging, mute,
## saved preferences, pause ducking, and that the loops are set to repeat.
## Run: godot --headless --audio-driver Dummy --path . -s res://tests/audio_runtime_test.gd

var _failures := 0
var _scratch := "user://audio_runtime_%d.json" % OS.get_process_id()


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAIL: " + label)


func _initialize() -> void:
	_run.call_deferred()


func _music_db() -> float:
	return AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))


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
	await create_timer(0.3).timeout
	_check(audio.music_channel.playing_count() == 1 and audio.ambience_channel.playing_count() == 1, "menu music and ambience start")
	_check(not audio.music_channel.play(&"menu", null, true), "asking for the playing track does nothing")
	audio.set_scene(&"menu", &"coastal")
	await create_timer(0.1).timeout
	_check(audio.music_channel.playing_count() == 1, "repeated scene does not start a second copy")
	var menu_player: AudioStreamPlayer = audio.music_channel._current

	audio.set_scene(&"combat", &"coastal")
	await create_timer(0.4).timeout
	_check(audio.music_channel.playing_count() == 2, "crossfade overlaps exactly two tracks")
	await create_timer(2.0).timeout
	_check(audio.music_channel.playing_count() == 1 and audio.music_channel.current_id == &"combat", "old track stopped after the fade")
	_check(not menu_player.playing, "the menu player was released")
	for i in 12:
		audio.set_scene(&"menu" if i % 2 == 0 else &"combat", &"" if i % 3 == 0 else &"coastal")
		await create_timer(0.05).timeout
	await create_timer(3.0).timeout
	_check(audio.music_channel.playing_count() == 1, "rapid scene changes leave one music track")
	_check(audio.ambience_channel.playing_count() <= 1, "rapid scene changes leave at most one ambience")
	audio.set_scene(&"menu", &"")
	await create_timer(3.0).timeout
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
	await create_timer(0.6).timeout
	_check(_music_db() < normal - 5.0, "pause ducks the music")
	audio.set_paused_duck(false)
	await create_timer(0.6).timeout
	_check(is_equal_approx(_music_db(), normal), "unpausing restores the music level")

	audio.set_music(1.0)
	audio.set_scene(&"combat", &"")
	var peak := -200.0
	for i in 40:
		await create_timer(0.05).timeout
		peak = maxf(peak, AudioServer.get_bus_peak_volume_left_db(master, 0))
	_check(peak > -60.0, "sound reaches the master bus (peak %.1f dB)" % peak)

	for p in [_scratch, _scratch + ".bak", _scratch + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	print("AUDIO RUNTIME %s" % ("FAILED" if _failures > 0 else "OK"))
	quit(1 if _failures > 0 else 0)
