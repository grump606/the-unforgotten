class_name BattleKeys
extends RefCounted
## Keyboard input of the battle screen. Number keys play hand cards, E / Enter end the turn or confirm the
## discard step, Backspace goes back, arrows and Tab move the target, D / C / F / W open the piles, and the
## pile viewer, the Glimpse / Recall pick, the boss entrance and the end-of-fight prompt each take the keys
## over while they are up.

## The key that ends the turn (Enter does too); the help text reads it from here.
const END_TURN_KEY := KEY_E

var _battle: Battle


func _init(battle: Battle) -> void:
	_battle = battle


## The pile keys as prose, "D, C, F or W", read from BattleOverlays.PILE_KEYS (tutorial and help text).
static func pile_keys_text() -> String:
	var names: Array[String] = []
	for keycode in BattleOverlays.PILE_KEYS:
		names.append(OS.get_keycode_string(keycode))
	return ", ".join(names.slice(0, -1)) + " or " + names[-1]


## The hand position a number key plays: 1 to 9 (top row or keypad) are cards 1 to 9, 0 is the tenth card (the
## hotkey badge shows it as 0), and any other key, including the colon key that sits after 9 in the key codes,
## is -1.
static func card_index(keycode: Key) -> int:
	var number := -1
	if keycode >= KEY_1 and keycode <= KEY_9:
		number = keycode - KEY_1
	elif keycode >= KEY_KP_1 and keycode <= KEY_KP_9:
		number = keycode - KEY_KP_1
	elif keycode == KEY_0 or keycode == KEY_KP_0:
		number = 9
	return number if number < BattleHand.MAX_HAND_KEYS else -1


## The end-turn key as text, "E".
static func end_turn_key_text() -> String:
	return OS.get_keycode_string(END_TURN_KEY)


## Routes one key press. The contexts are tried in a fixed order and the first one that takes the key ends the
## routing, so an earlier (more modal) context hides every later one:
##   1. Esc cancels a card drag in progress.
##   2. Any key skips the boss entrance while it plays.
##   3. After the fight: N, E and Enter continue (the New Fight / Continue button); other keys do nothing.
##   4. The pile viewer is modal: Esc closes it, the pile keys switch piles, other keys do nothing.
##   5. A Glimpse / Recall pick: number keys mark cards, Enter confirms, Esc is swallowed, the rest do nothing.
##   6. Outside the player's turn and the discard step nothing happens (the same gate as the buttons).
##   7. The pile keys open the viewer.
##   8. Number keys play hand cards.
##   9. Backspace goes back from the discard step.
##  10. End turn (E, Enter) and target cycling (arrows, Tab).
func handle(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or key.ctrl_pressed or key.alt_pressed or key.meta_pressed:
		return
	var combat := _battle.combat()
	var routes: Array[Callable] = [
		_key_drag_cancel, _key_boss_intro, _key_after_fight, _key_pile_viewer, _key_choice,
		_key_outside_player_turn, _key_pile_open, _key_play_card, _key_back, _key_turn,
	]
	for route in routes:
		if route.call(key, combat):
			return


func _key_drag_cancel(key: InputEventKey, _combat: Combat) -> bool:
	if key.keycode == KEY_ESCAPE and _battle.drag().cancel_with_key():
		_handled()
		return true
	return false


func _key_boss_intro(key: InputEventKey, _combat: Combat) -> bool:
	if _is_modifier(key.keycode):
		return false # a bare Shift / Ctrl / Alt / Meta press is not "any key"
	if _battle.fx().skip_intro():
		_handled()
		return true
	return false


func _key_after_fight(key: InputEventKey, _combat: Combat) -> bool:
	if not _battle.new_fight_button().visible:
		return false
	if key.keycode == KEY_N or key.keycode == END_TURN_KEY or key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
		_handled()
		_battle.continue_pressed()
	return true


func _key_pile_viewer(key: InputEventKey, _combat: Combat) -> bool:
	if not _battle.overlays().pile_viewer_open():
		return false
	_handled()
	if key.keycode == KEY_ESCAPE:
		_battle.overlays().close_pile_viewer()
	elif BattleOverlays.PILE_KEYS.has(key.keycode):
		_battle.open_pile_viewer(BattleOverlays.PILE_KEYS.find(key.keycode) as PileViewer.Pile)
	return true


## Esc is swallowed so it cannot fall through to the run's pause menu; the player's turn controls stay locked
## until the pick is resolved.
func _key_choice(key: InputEventKey, combat: Combat) -> bool:
	if combat == null or combat.phase != Combat.Phase.CHOOSING:
		return false
	var overlay := _battle.overlays().choice
	if key.keycode == KEY_ESCAPE or (overlay != null and overlay.handle_key(key.keycode)):
		_handled()
	return true


func _key_outside_player_turn(_key: InputEventKey, combat: Combat) -> bool:
	return combat == null or (combat.phase != Combat.Phase.PLAYER_TURN and combat.phase != Combat.Phase.DISCARDING)


func _key_pile_open(key: InputEventKey, _combat: Combat) -> bool:
	if not BattleOverlays.PILE_KEYS.has(key.keycode):
		return false
	_handled()
	_battle.open_pile_viewer(BattleOverlays.PILE_KEYS.find(key.keycode) as PileViewer.Pile)
	return true


func _key_play_card(key: InputEventKey, _combat: Combat) -> bool:
	var number := card_index(key.keycode)
	if number < 0:
		return false
	_handled()
	_battle.hand().play_card(number)
	return true


func _key_back(key: InputEventKey, _combat: Combat) -> bool:
	if key.keycode != KEY_BACKSPACE:
		return false
	_handled()
	_battle.cancel_discard()
	return true


func _key_turn(key: InputEventKey, _combat: Combat) -> bool:
	match key.keycode:
		END_TURN_KEY, KEY_ENTER, KEY_KP_ENTER:
			_handled()
			_battle.end_turn()
		KEY_RIGHT:
			_handled()
			_battle.cycle_target(1)
		KEY_LEFT:
			_handled()
			_battle.cycle_target(-1)
		KEY_TAB:
			_handled()
			_battle.cycle_target(-1 if key.shift_pressed else 1)
		_:
			return false
	return true


static func _is_modifier(keycode: Key) -> bool:
	return keycode == KEY_SHIFT or keycode == KEY_CTRL or keycode == KEY_ALT or keycode == KEY_META


func _handled() -> void:
	_battle.get_viewport().set_input_as_handled()
