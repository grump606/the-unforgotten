class_name EventScreen
extends RunScreen
## An event stop (a "?" node, docs/EVENTS_DESIGN.md): the scene text on a card over a dimmed painting, then one button
## per choice with its printed cost and reward under it (a button the player cannot pay is greyed with the reason).
## Pressing one shows the outcome and, when the choice owes a pick, the same pickers the other stops use (remove a
## card, Remember a card, choose 1 of 3), then "Continue". What happens is decided by RunState; the screen only reads
## `run.event_*` and calls `resolve_event_choice`, the pick completers and `finish_event`, so a redraw at any moment
## shows the same place.

const CARD_WIDTH := 580.0
const BOTTOM_GAP := 14.0
const TITLE_COLOUR := Color("#d7d0bc")
const BODY_COLOUR := Color("#cfd4cb")
const SUMMARY_COLOUR := Color("#93cdc4")
const REASON_COLOUR := Color("#e0a27a")
const OUTCOME_COLOUR := Color("#e8e1d0")


## Nothing is kept between redraws: the state lives in the run.
func reset() -> void:
	pass


func show() -> void:
	var event := run.current_event()
	var scene := EventScene.new()
	if event != null:
		scene.painting = event.scene
	add_backdrop(scene)
	if event == null:
		# Content failed to load (logged): the stop must still be passable.
		var fallback := panel("Something stirs beside the road, and is gone.")
		style_banner(fallback.get_child(0) as Label)
		var leave := add_button(fallback, "Continue", _finish)
		leave.name = "ContinueButton"
		return
	var followup := run.event_followup()
	if followup == &"remove":
		var picker := panel(_prompt("Pick a card to remove from your deck."), true)
		add_remove_picker(picker, _remove_card, Callable(), [], false)
		return
	if followup == &"remember":
		var picker := panel(_prompt("Remember which card? It comes back stronger."), true)
		add_remove_picker(picker, _remember_card, Callable(), run.event_remember_indices(), false)
		return
	if followup == &"pick":
		_show_pick()
		return
	_show_card(event)


## The story card: title, scene or outcome text, then the buttons or Continue.
func _show_card(event: EventData) -> void:
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_bottom", int(BOTTOM_GAP))
	margin.add_theme_constant_override("margin_top", int(BOTTOM_GAP))
	body.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var centre := CenterContainer.new()
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(centre)
	var card := PanelContainer.new()
	card.name = "EventCard"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(MenuStyle.BG, 0.94)
	style.set_border_width_all(2)
	style.border_color = MenuStyle.BORDER
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", TactileArt.textured_style(style))
	centre.add_child(card)
	var scroll := ScrollContainer.new()
	scroll.name = "EventScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	card.add_child(scroll)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	scroll.add_child(box)
	var title := make_label(event.title)
	title.name = "EventTitle"
	MenuStyle.heading(title, 22)
	title.add_theme_color_override("font_color", TITLE_COLOUR)
	box.add_child(title)
	if run.event_resolved():
		var outcome := _add_text(box, run.event_outcome(), 14, OUTCOME_COLOUR)
		outcome.name = "EventOutcome"
		var next := add_button(box, "Continue", _finish)
		next.name = "ContinueButton"
		style_service(next)
		compact_plaque(next, 32.0, 14)
	else:
		var text := _add_text(box, run.event_body(), 14, BODY_COLOUR)
		text.name = "EventBody"
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0, 4)
		box.add_child(gap)
		var choices := run.event_choices()
		for i in choices.size():
			_add_choice(box, i)
	# Fit the scroll area to the content, but never taller than the body: a long scene on a small window scrolls.
	body.get_tree().process_frame.connect(_fit.bind(scroll, box), CONNECT_ONE_SHOT)


func _add_choice(box: VBoxContainer, index: int) -> void:
	var state := run.event_choice_state(index)
	var group := VBoxContainer.new()
	group.name = "Choice%d" % index
	group.add_theme_constant_override("separation", 1)
	box.add_child(group)
	var button := add_button(group, String(state["label"]), _choose.bind(index))
	button.name = "ChoiceButton%d" % index
	style_service(button)
	compact_plaque(button, 30.0, 14)
	button.disabled = not bool(state["enabled"])
	var summary := String(state["summary"])
	if not bool(state["enabled"]):
		var reason := String(state["reason"])
		button.tooltip_text = reason
		if reason != "":
			var why := _add_text(group, reason, 12, REASON_COLOUR)
			why.name = "ChoiceReason%d" % index
	if summary != "":
		var line := _add_text(group, summary, 12, SUMMARY_COLOUR)
		line.name = "ChoiceSummary%d" % index


func _show_pick() -> void:
	var box := panel(_prompt("Choose a card to add to your deck."), true)
	style_banner(box.get_child(0) as Label)
	var row := HBoxContainer.new()
	row.name = "PickRow"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	for card in run.event_pick_choices():
		row.add_child(card_view(card, OFFER_CARD_SCALE, _pick_card.bind(card)))


## A picker's heading: what the choice just did (its outcome text) over the instruction.
func _prompt(instruction: String) -> String:
	var done := run.event_outcome()
	return instruction if done == "" else done + "
" + instruction


static func _add_text(box: VBoxContainer, text: String, font_size: int, colour: Color) -> Label:
	var label := make_label(text)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	box.add_child(label)
	return label


## Sizes the scroll area to its content, capped at the room the body leaves.
func _fit(scroll: ScrollContainer, box: VBoxContainer) -> void:
	if not is_instance_valid(scroll) or not is_instance_valid(box) or not is_instance_valid(body):
		return
	var room := maxf(body.size.y - 2.0 * BOTTOM_GAP - 24.0, 120.0)
	scroll.custom_minimum_size = Vector2(CARD_WIDTH + 8.0, minf(box.get_combined_minimum_size().y + 2.0, room))


func _choose(index: int) -> void:
	run.resolve_event_choice(index)
	refresh.call()


func _remove_card(deck_index: int) -> void:
	run.event_remove_card(deck_index)
	refresh.call()


func _remember_card(deck_index: int) -> void:
	run.event_remember_card(deck_index)
	refresh.call()


func _pick_card(card: CardData) -> void:
	sfx(&"reward")
	run.event_pick_card(card)
	refresh.call()


func _finish() -> void:
	run.finish_event()
	refresh.call()
