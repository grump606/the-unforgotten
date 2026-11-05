class_name RestScreen
extends RunScreen
## A rest stop: arriving heals you to full (shown in the header as "HP 36/36  Healed (+12)"; the
## heal itself is applied when you move on, so a save taken here replays the same screen). A
## small story card continues the voice from the opening beat (run/rest_content.gd) and its one
## button, "Follow the voice", leaves the stop.

const CARD_WIDTH := 320.0
const CARD_FONT_SIZE := 13
const CARD_MARGIN := 10.0
const BOTTOM_GAP := 22.0
const SIDE_GAP := 26.0


## True while the panel shows the pick-a-card-to-Remember list.
var remembering := false


## Forgets the picker (a new or resumed run starts clean).
func reset() -> void:
	remembering = false


func show() -> void:
	var scene := RestScene.new()
	scene.character_id = run.character.id if run.character != null else &""
	add_backdrop(scene)
	if remembering:
		var picker := panel("Remember which card? It comes back stronger, and you do not heal.", true)
		add_remove_picker(picker, _remember_card, _cancel_remembering, run.rememberable_indices())
		return
	var beat := RestContent.beat(run.rest_number(), scene.character_id)
	# The card sits on the empty floor at the bottom right of the painting, clear of the character.
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_bottom", int(BOTTOM_GAP))
	margin.add_theme_constant_override("margin_right", int(SIDE_GAP))
	body.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var card := PanelContainer.new()
	card.name = "RestCard"
	card.size_flags_horizontal = Control.SIZE_SHRINK_END
	card.size_flags_vertical = Control.SIZE_SHRINK_END
	var paper := paper_style()
	paper.set_content_margin_all(CARD_MARGIN)
	card.add_theme_stylebox_override("panel", paper)
	margin.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)
	# Dark ink on memento paper keeps the words readable over the art.
	var ink := Color(0.14, 0.10, 0.07)
	var title := make_label(beat.title)
	MenuStyle.heading(title, 16)
	title.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
	title.add_theme_color_override("font_color", ink)
	box.add_child(title)
	var text := Label.new()
	text.text = beat.text
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	text.add_theme_font_size_override("font_size", CARD_FONT_SIZE)
	text.add_theme_color_override("font_color", ink)
	box.add_child(text)
	var button := add_button(box, beat.button_text, _continue)
	style_service(button)
	compact_plaque(button, 30.0, 13)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# The second choice: instead of the heal, bring one card back stronger.
	var remember := add_button(box, "Remember a card (no heal)", start_remembering)
	remember.name = "RememberButton"
	style_service(remember)
	compact_plaque(remember, 30.0, 13)
	remember.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var candidates := run.rememberable_indices().size()
	remember.disabled = candidates == 0
	remember.tooltip_text = "Pick one of your cards and bring it back stronger. You skip the heal." if candidates > 0 else "No card in your deck can be remembered yet."


func start_remembering() -> void:
	remembering = true
	refresh.call()


func _cancel_remembering() -> void:
	remembering = false
	refresh.call()


func _remember_card(deck_index: int) -> void:
	remembering = false
	run.remember(deck_index)
	refresh.call()


func _continue() -> void:
	remembering = false
	run.rest()
	refresh.call()
