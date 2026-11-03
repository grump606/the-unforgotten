extends Node
## Autoload "AudioManager": the one place sound is decided. Three buses (Music, Ambience, SFX) feed
## Master; two looping channels (music, ambience) crossfade between scenes; short effects go through
## a small pool. Screens only say what is happening (`set_scene`, `sfx`); levels, mute and the
## settings file live here. Credits and licences: res://audio/CREDITS.txt.
##
## Headless runs (the automated tests) track everything but stay silent, unless a test sets
## `playback_enabled` itself.

const BUS_MASTER := &"Master"
const BUS_MUSIC := &"Music"
const BUS_AMBIENCE := &"Ambience"
const BUS_SFX := &"SFX"
const CREDITS_PATH := "res://audio/CREDITS.txt"

## Bus trims in dB at slider 100%: the music is mastered fairly hot, the sea sits well beneath it,
## and effects are clear but gentle.
const MUSIC_TRIM_DB := -8.0
const AMBIENCE_TRIM_DB := -22.0
const SFX_TRIM_DB := -4.0
## Music and ambience duck by this much while the pause menu is open.
const PAUSE_DUCK_DB := -6.0

const MUSIC := {
	&"menu": "res://audio/music/menu_loop.ogg",
	&"combat": "res://audio/music/combat_loop.ogg",
}
const AMBIENCE := {
	&"coastal": "res://audio/ambience/coastal_loop.ogg",
}
## path, extra dB, priority (when several effects are asked for in one frame only the highest plays).
const SFX := {
	&"click": ["res://audio/sfx/select_001.wav", -3.0, 1],
	&"card_select": ["res://audio/sfx/click_001.wav", -4.0, 1],
	&"card_play": ["res://audio/sfx/drop_001.wav", -3.0, 2],
	&"confirm": ["res://audio/sfx/confirmation_001.wav", -9.0, 2],
	&"unavailable": ["res://audio/sfx/error_001.wav", -11.0, 2],
	&"reward": ["res://audio/sfx/glass_001.wav", -6.0, 3],
}
const SFX_VOICES := 6
## The same effect is not repeated within this many seconds (key repeat, double clicks).
const SFX_MIN_GAP := 0.06

var prefs := AudioPrefs.new()
## Where preferences are kept; tests point this at a scratch file.
var settings_path := Settings.DEFAULT_PATH
## False in headless runs so automated tests make no sound.
var playback_enabled := DisplayServer.get_name() != "headless"
## Recent effect ids actually triggered (newest last), for tests and diagnostics.
var sfx_log: Array[StringName] = []

var music_channel: AudioChannel
var ambience_channel: AudioChannel

var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _streams := {}
var _pending: Array[StringName] = []
var _last_played := {}  # effect id -> msec
var _duck := 0.0  # 0 normal .. 1 ducked
var _duck_tween: Tween
var _focus_lost := false
var _save_pending := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # keep fading, and keep playing, while the tree is paused
	_ensure_buses()
	prefs = AudioPrefs.load_from(settings_path)
	music_channel = AudioChannel.new()
	music_channel.name = "Music"
	add_child(music_channel)
	music_channel.setup(BUS_MUSIC, 1.6)
	ambience_channel = AudioChannel.new()
	ambience_channel.name = "Ambience"
	add_child(ambience_channel)
	ambience_channel.setup(BUS_AMBIENCE, 2.5)
	for i in SFX_VOICES:
		var voice := AudioStreamPlayer.new()
		voice.bus = BUS_SFX
		add_child(voice)
		_voices.append(voice)
	apply_levels()


## Creates the three buses (once) under Master. Done in code so the project needs no bus layout file.
func _ensure_buses() -> void:
	for bus in [BUS_MUSIC, BUS_AMBIENCE, BUS_SFX]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus)
			AudioServer.set_bus_send(index, BUS_MASTER)


# --- Levels -----------------------------------------------------------------------------------

## A slider position (0..1) as decibels; the bottom of the slider is silence.
static func slider_to_db(level: float) -> float:
	return -80.0 if level <= 0.001 else linear_to_db(level)


func apply_levels() -> void:
	_set_bus(BUS_MASTER, slider_to_db(prefs.master), prefs.muted or _focus_lost)
	_set_bus(BUS_MUSIC, slider_to_db(prefs.music) + MUSIC_TRIM_DB + PAUSE_DUCK_DB * _duck, false)
	_set_bus(BUS_AMBIENCE, slider_to_db(prefs.ambience) + AMBIENCE_TRIM_DB + PAUSE_DUCK_DB * _duck, false)
	_set_bus(BUS_SFX, slider_to_db(prefs.sfx) + SFX_TRIM_DB, false)


func _set_bus(bus: StringName, db: float, mute: bool) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index == -1:
		return
	AudioServer.set_bus_volume_db(index, db)
	AudioServer.set_bus_mute(index, mute)


## Setters used by the settings panel. The file is written by `save_now` once the player lets go.
func set_master(level: float) -> void:
	prefs.master = clampf(level, 0.0, 1.0)
	_changed()


func set_music(level: float) -> void:
	prefs.music = clampf(level, 0.0, 1.0)
	_changed()


func set_ambience(level: float) -> void:
	prefs.ambience = clampf(level, 0.0, 1.0)
	_changed()


func set_sfx(level: float) -> void:
	prefs.sfx = clampf(level, 0.0, 1.0)
	_changed()


func set_muted(on: bool) -> void:
	prefs.muted = on
	_changed()
	save_now()


func _changed() -> void:
	apply_levels()
	_save_pending = true


## Writes the preferences if they changed (a slider was released, mute was toggled, the game closes).
func save_now() -> void:
	if not _save_pending:
		return
	_save_pending = false
	var error := prefs.save_to(settings_path)
	if error != "":
		push_warning("Could not save audio settings (%s)." % error)


# --- Scenes -----------------------------------------------------------------------------------

## Music and ambience for what the player is looking at. Ids are keys of MUSIC and AMBIENCE, or
## &"" for silence. Repeating the current ids changes nothing, so screens may call this freely.
func set_scene(music_id: StringName, ambience_id: StringName = &"") -> void:
	if music_channel == null:
		return
	music_channel.play(music_id, _stream(MUSIC.get(music_id, "")), playback_enabled)
	ambience_channel.play(ambience_id, _stream(AMBIENCE.get(ambience_id, "")), playback_enabled)


## Dips music and ambience while the pause menu is open.
func set_paused_duck(on: bool) -> void:
	if _duck_tween != null and _duck_tween.is_valid():
		_duck_tween.kill()
	_duck_tween = create_tween()
	_duck_tween.tween_method(_set_duck, _duck, 1.0 if on else 0.0, 0.35)


func _set_duck(value: float) -> void:
	_duck = value
	apply_levels()


func _stream(path: String) -> AudioStream:
	if path == "":
		return null
	if not _streams.has(path):
		var stream := load(path) as AudioStream
		if stream == null:
			push_warning("Audio file missing: %s" % path)
		_streams[path] = stream
	return _streams[path]


# --- Effects ----------------------------------------------------------------------------------

## Asks for an effect. Requests made in the same frame are merged into the highest-priority one in
## `flush`, so a button that also confirms something sounds once.
func sfx(id: StringName) -> void:
	if SFX.has(id):
		_pending.append(id)


func _process(_delta: float) -> void:
	flush()


func flush() -> void:
	if _pending.is_empty():
		return
	var best: StringName = _pending[0]
	for id in _pending:
		if int(SFX[id][2]) > int(SFX[best][2]):
			best = id
	_pending.clear()
	var now := Time.get_ticks_msec()
	if now - int(_last_played.get(best, -10000)) < int(SFX_MIN_GAP * 1000.0):
		return
	_last_played[best] = now
	sfx_log.append(best)
	if sfx_log.size() > 64:
		sfx_log.remove_at(0)
	if not playback_enabled:
		return
	var stream := _stream(SFX[best][0])
	if stream == null:
		return
	var voice := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % SFX_VOICES
	voice.stream = stream
	voice.volume_db = float(SFX[best][1])
	voice.play()


# --- Focus and exit ---------------------------------------------------------------------------

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			_focus_lost = true
			apply_levels()
		NOTIFICATION_APPLICATION_FOCUS_IN:
			_focus_lost = false
			apply_levels()
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_PREDELETE:
			save_now()


## The credits text shipped with the game ("" if the file is missing).
static func credits_text() -> String:
	return FileAccess.get_file_as_string(CREDITS_PATH)
