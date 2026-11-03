class_name AudioChannel
extends Node
## One looping layer (music or ambience) on its own bus. Asking for the track that is already
## playing does nothing; asking for another crossfades, so at most two tracks overlap and only
## while fading. A small pool of players lets rapid requests (scene changes in quick succession)
## fade cleanly without ever leaving a stale track playing.

const SILENT := 0.0
const POOL_SIZE := 3

var fade_time := 1.5
var current_id: StringName = &""

var _players: Array[AudioStreamPlayer] = []
var _tweens := {}  # AudioStreamPlayer -> Tween
var _current: AudioStreamPlayer


func setup(bus: StringName, fade_seconds: float) -> void:
	fade_time = fade_seconds
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = bus
		player.volume_linear = SILENT
		add_child(player)
		_players.append(player)


## Number of players currently producing sound (tests check there is never a third layer).
func playing_count() -> int:
	var count := 0
	for player in _players:
		if player.playing:
			count += 1
	return count


## Plays `stream` as `id`. Returns false (and changes nothing) when `id` is already current.
## With `audible` false (headless runs) the bookkeeping still happens but nothing is played.
func play(id: StringName, stream: AudioStream, audible := true) -> bool:
	if id == current_id and id != &"":
		return false
	_fade_out_current()
	current_id = id
	if id == &"" or stream == null:
		return true
	if not audible:
		return true
	var player := _free_player()
	player.stream = stream
	player.volume_linear = SILENT
	player.play()
	_current = player
	_fade_to(player, 1.0, false)
	return true


## Fades the current track out and leaves the channel empty.
func stop() -> void:
	_fade_out_current()
	current_id = &""


func _fade_out_current() -> void:
	if _current != null:
		_fade_to(_current, SILENT, true)
		_current = null


## A player that is not sounding; when every one is (rapid requests), the quietest is cut.
func _free_player() -> AudioStreamPlayer:
	var quietest: AudioStreamPlayer = _players[0]
	for player in _players:
		if not player.playing:
			return player
		if player.volume_linear < quietest.volume_linear:
			quietest = player
	_kill_tween(quietest)
	quietest.stop()
	return quietest


func _fade_to(player: AudioStreamPlayer, target: float, stop_after: bool) -> void:
	_kill_tween(player)
	if not player.playing:
		return
	var tween := create_tween()  # bound to this node, which keeps running while the game is paused
	_tweens[player] = tween
	tween.tween_property(player, "volume_linear", target, fade_time).set_trans(Tween.TRANS_SINE)
	if stop_after:
		tween.tween_callback(player.stop)


func _kill_tween(player: AudioStreamPlayer) -> void:
	var old: Tween = _tweens.get(player)
	if old != null and old.is_valid():
		old.kill()
	_tweens.erase(player)
