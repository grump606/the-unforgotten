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


func handle(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or key.ctrl_pressed or key.alt_pressed or key.meta_pressed:
		return
	var b := _battle
	var combat := b.combat()
	if key.keycode == KEY_ESCAPE and b.drag().cancel_with_key():
		_handled()
		return
	if b._fx.skip_intro():
		_handled()
		return
	if b._new_fight_button.visible:
		if key.keycode == KEY_N or key.keycode == KEY_E or key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
			_handled()
			b._on_continue_pressed()
		return
	# The pile viewer is read-only and modal: Esc closes it, the pile keys switch piles, other keys do nothing.
	if b._overlays.pile_viewer_open():
		_handled()
		if key.keycode == KEY_ESCAPE:
			b._overlays.close_pile_viewer()
		elif BattleOverlays.PILE_KEYS.has(key.keycode):
			b.open_pile_viewer(BattleOverlays.PILE_KEYS.find(key.keycode) as PileViewer.Pile)
		return
	# A Glimpse / Recall pick: number keys mark cards, Enter confirms, and every other key does nothing.
	# Esc is swallowed here so it cannot fall through to the run's pause menu; the player's turn controls
	# stay locked until the pick is resolved.
	if combat != null and combat.phase == Combat.Phase.CHOOSING:
		var overlay := b._overlays.choice
		if key.keycode == KEY_ESCAPE or (overlay != null and overlay.handle_key(key.keycode)):
			_handled()
		return
	# Same gate as the buttons: nothing happens outside the player's turn.
	if combat == null or (combat.phase != Combat.Phase.PLAYER_TURN and combat.phase != Combat.Phase.DISCARDING):
		return
	if BattleOverlays.PILE_KEYS.has(key.keycode):
		_handled()
		b.open_pile_viewer(BattleOverlays.PILE_KEYS.find(key.keycode) as PileViewer.Pile)
		return
	var number := card_index(key.keycode)
	if number >= 0:
		_handled()
		b._hand.play_card(number)
		return
	if key.keycode == KEY_BACKSPACE:
		_handled()
		b._on_cancel_discard_pressed()
		return
	match key.keycode:
		END_TURN_KEY, KEY_ENTER, KEY_KP_ENTER:
			_handled()
			b._on_end_turn_pressed()
		KEY_RIGHT:
			_handled()
			b._cycle_target(1)
		KEY_LEFT:
			_handled()
			b._cycle_target(-1)
		KEY_TAB:
			_handled()
			b._cycle_target(-1 if key.shift_pressed else 1)


func _handled() -> void:
	_battle.get_viewport().set_input_as_handled()
