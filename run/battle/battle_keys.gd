class_name BattleKeys
extends RefCounted
## Keyboard input of the battle screen. Number keys play hand cards, E / Enter end the turn or confirm the
## discard step, Backspace goes back, arrows and Tab move the target, D / C / F / W open the piles, and the
## pile viewer, the Glimpse / Recall pick, the boss entrance and the end-of-fight prompt each take the keys
## over while they are up.

var _battle: Battle


func _init(battle: Battle) -> void:
	_battle = battle


func handle(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or key.ctrl_pressed or key.alt_pressed or key.meta_pressed:
		return
	var b := _battle
	var combat := b._combat
	if key.keycode == KEY_ESCAPE and b._drag.cancel_with_key():
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
	var number := key.keycode - KEY_1
	if key.keycode == KEY_0:
		number = 9
	if number >= 0 and number < BattleHand.MAX_HAND_KEYS:
		_handled()
		b._hand.play_card(number)
		return
	if key.keycode == KEY_BACKSPACE:
		_handled()
		b._on_cancel_discard_pressed()
		return
	match key.keycode:
		KEY_E, KEY_ENTER, KEY_KP_ENTER:
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
