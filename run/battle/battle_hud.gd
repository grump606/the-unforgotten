class_name BattleHud
extends RefCounted
## The bottom bar and the stage text of the battle screen: the HUD panel styling, the four pile counters (each a
## button that opens its pile), the deck line, the End Turn / discard-step controls with their confirm pulse, and
## the journey info a run adds with set_journey.

## Seconds per beat of the amber pulse (two beats) when the discard-step confirm button becomes available.
const CONFIRM_PULSE_TIME := 0.35
## Font sizes of the stop title and journey lines, and where the relic badges sit under them.
const STAGE_TITLE_FONT := 20
const STAGE_JOURNEY_FONT := 14
const RELIC_STRIP_X := 4.0
const RELIC_STRIP_GAP := 14.0

## The four pile counters (Draw, Discard, Forgotten, Sworn) and the deck line.
var pile_buttons: Array[Button] = []
var deck_label: Label
## "Back" button shown during the end-of-turn discard step (created in code).
var cancel_button: Button

var _battle: Battle
var _hint_shown := false
var _confirm_ready := false
var _confirm_tween: Tween
## Journey info (see set_journey): top-left stage text, the character title above the orb, the deck count.
var _stage_info: VBoxContainer
var _stage_title: Label
var _stage_journey: Label
var _character_label: Label
var _deck_size := -1


func _init(battle: Battle) -> void:
	_battle = battle


## One-time setup from Battle._ready: the bar's look, the pile buttons and the Back button.
func build() -> void:
	_style_bar()
	_build_pile_buttons()
	_build_cancel_button()


## A dark bar flush with the bottom and side edges, with a thin amber line along its top.
func _style_bar() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(MenuStyle.BG, 0.93)
	box.border_color = Color(MenuStyle.AMBER, 0.55)
	box.border_width_top = 1
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 6
	box.content_margin_bottom = 8
	box.shadow_color = Color(0, 0, 0, 0.45)
	box.shadow_size = 8
	_battle.hud_panel().add_theme_stylebox_override("panel", box)


## One small button per pile, so each has its own target, hover and key (see BattleOverlays.PILE_KEYS).
func _build_pile_buttons() -> void:
	for which in PileViewer.PILE_NAMES.size():
		var button := Button.new()
		button.theme_type_variation = MenuStyle.QUIET
		button.add_theme_font_size_override("font_size", 13)
		button.custom_minimum_size = Vector2(0, 22)
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.tooltip_text = "Look at your %s pile (key %s)" % [String(PileViewer.PILE_NAMES[which]).to_lower(), OS.get_keycode_string(BattleOverlays.PILE_KEYS[which])]
		button.pressed.connect(_battle.open_pile_viewer.bind(which as PileViewer.Pile))
		_battle.pile_box().add_child(button)
		pile_buttons.append(button)
	deck_label = Label.new()
	deck_label.add_theme_font_size_override("font_size", 13)
	deck_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	deck_label.visible = false
	_battle.pile_box().add_child(deck_label)


func _build_cancel_button() -> void:
	var end_turn := _battle.end_turn_button()
	cancel_button = Button.new()
	cancel_button.text = "Back"
	cancel_button.theme_type_variation = MenuStyle.QUIET
	cancel_button.tooltip_text = "Back to playing cards (Backspace)"
	cancel_button.custom_minimum_size = Vector2(0, 36)
	cancel_button.focus_mode = Control.FOCUS_NONE
	cancel_button.visible = false
	cancel_button.pressed.connect(_battle.cancel_discard)
	end_turn.get_parent().add_child(cancel_button)
	end_turn.get_parent().move_child(cancel_button, end_turn.get_index() + 1)


## End Turn / discard-step controls. In the discard step the main button confirms ("Keep all" when
## nothing is marked and at most Combat.HAND_SIZE cards are held, "Discard N" otherwise, or a disabled
## "Discard N more" while too many would stay) and Back returns to playing cards.
func sync_turn_controls() -> void:
	var combat := _battle.combat()
	var end_turn := _battle.end_turn_button()
	var phase := combat.phase
	var discarding := phase == Combat.Phase.DISCARDING
	cancel_button.visible = discarding
	if discarding:
		var marked := combat.discard_marks.size()
		var need := combat.discard_required()
		end_turn.disabled = need > 0
		_pulse_confirm(need == 0)
		if need > 0:
			end_turn.text = "Discard %d more" % need
		elif marked == 0:
			end_turn.text = "Keep all"
		else:
			end_turn.text = "Discard %d" % marked
		# Anchor and Fading cards are not part of the 5: they cannot be marked and are not counted.
		var keep := combat.piles.counted_in_hand() - marked
		var text := "Choose cards to discard. You keep %d of up to %d." % [keep, Combat.HAND_SIZE]
		if combat.piles.hand.any(func(c: CardData) -> bool: return c.anchor):
			text += " Anchor cards stay."
		if combat.piles.hand.any(func(c: CardData) -> bool: return c.fading):
			text += " Fading cards left in hand will be Forgotten."
		_battle.result_label().text = text
		_hint_shown = true
		return
	_pulse_confirm(false)
	end_turn.text = "End Turn"
	end_turn.disabled = phase != Combat.Phase.PLAYER_TURN
	if _hint_shown and phase != Combat.Phase.ENDED:
		_battle.result_label().text = ""
	_hint_shown = false


## When the discard step's confirm button first becomes available, pulses it amber twice (skipped
## under Motion.reduced). Becoming unavailable again clears any pulse.
func _pulse_confirm(available: bool) -> void:
	if available == _confirm_ready:
		return
	_confirm_ready = available
	if _confirm_tween != null:
		_confirm_tween.kill()
		_confirm_tween = null
	var end_turn := _battle.end_turn_button()
	end_turn.modulate = Color.WHITE
	if not available or Motion.reduced or not _battle.is_inside_tree():
		return
	var amber := Color(1.0, 0.82, 0.4)
	_confirm_tween = _battle.create_tween()
	for beat in 2:
		_confirm_tween.tween_property(end_turn, "modulate", amber, CONFIRM_PULSE_TIME * 0.5)
		_confirm_tween.tween_property(end_turn, "modulate", Color.WHITE, CONFIRM_PULSE_TIME * 0.5)


## Updates the four counters (and the deck line when the run supplied one).
func sync_piles() -> void:
	var piles := _battle.combat().piles
	var counts := [piles.draw_pile.size(), piles.discard_pile.size(), piles.forgotten.size(), piles.sworn.size()]
	for i in pile_buttons.size():
		pile_buttons[i].text = "%s %d" % [PileViewer.PILE_NAMES[i], counts[i]]
	deck_label.visible = _deck_size >= 0
	deck_label.text = "Deck %d" % _deck_size


## The counters as plain lines, one per pile (read by tests).
func pile_text() -> String:
	var lines: Array[String] = []
	for button in pile_buttons:
		lines.append(button.text)
	if _deck_size >= 0:
		lines.append(deck_label.text)
	return "\n".join(lines)


## Journey info for a fight inside a run: the stop title and journey number at the top left of the
## stage (the relic badges move below them), the character's title above the energy orb, and the
## deck count under the draw and discard counts. Standalone fights never call this.
func set_journey(stop_title: String, journey: String, character_title: String, deck_size: int) -> void:
	if _stage_info == null:
		_stage_info = VBoxContainer.new()
		_stage_info.position = MenuStyle.STAGE_INFO_POS
		_stage_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stage_info.add_theme_constant_override("separation", 0)
		_stage_title = Label.new()
		_stage_title.add_theme_font_size_override("font_size", STAGE_TITLE_FONT)
		_stage_title.add_theme_color_override("font_color", MenuStyle.TEXT)
		_stage_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
		_stage_title.add_theme_constant_override("shadow_offset_y", 2)
		_stage_info.add_child(_stage_title)
		_stage_journey = Label.new()
		_stage_journey.add_theme_font_size_override("font_size", STAGE_JOURNEY_FONT)
		_stage_journey.add_theme_color_override("font_color", MenuStyle.TEXT_DIM)
		_stage_journey.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
		_stage_journey.add_theme_constant_override("shadow_offset_y", 1)
		_stage_info.add_child(_stage_journey)
		for label in [_stage_title, _stage_journey]:
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_battle.stage().add_child(_stage_info)
		_character_label = Label.new()
		_character_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_character_label.add_theme_font_size_override("font_size", 12)
		_character_label.add_theme_color_override("font_color", MenuStyle.TEXT_DIM)
		_battle.left_box().add_child(_character_label)
		_battle.left_box().move_child(_character_label, 0)
	_stage_title.text = stop_title
	_stage_journey.text = journey
	_character_label.text = character_title
	_deck_size = deck_size
	# Below the two lines of text, the relic badges keep the left edge.
	_battle.relic_strip().position = Vector2(RELIC_STRIP_X, _stage_info.position.y + STAGE_TITLE_FONT + STAGE_JOURNEY_FONT + RELIC_STRIP_GAP)
	if _battle.combat() != null:
		sync_piles()
