class_name RunScreen
extends RefCounted
## Base for the run screens (the stop panels built by run.gd). A screen is given the run, the body
## container to build into and `refresh`, a callable that redraws the current stop (run.gd's
## `_show_stop`). It owns no navigation: run.gd decides which screen is shown.
## The shared widget helpers are static so any screen (or the pause menu) can use them.

## Card sizes: reward and vendor offers are drawn larger than a hand card, deck pickers and
## the character select screen use small cards (their names are also in tooltips and labels).
const OFFER_CARD_SCALE := 1.2
const PICKER_CARD_SCALE := 0.7
const PICKER_COLUMNS := 10
## Window height kept free around the picker's scroll area: header line, prompt, Cancel, spacing.
const PICKER_RESERVED_HEIGHT := 190.0

var run: RunState
var body: Control
var refresh: Callable


## Hands the screen what it builds from. Called by run.gd before each `show`.
func attach(run_state: RunState, body_container: Control, refresh_callable: Callable) -> void:
	run = run_state
	body = body_container
	refresh = refresh_callable


## Adds a centred column to the body and returns it; the first line is `title`.
func panel(title: String) -> VBoxContainer:
	var center := CenterContainer.new()
	body.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)
	var label := Label.new()
	label.text = title
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(label)
	return box


## Adds a scene behind the panel that follows it (the panel is added after, so it sits on top).
func add_backdrop(scene: Control) -> void:
	body.add_child(scene)
	scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## The pick-a-card-to-remove list shared by the reward and vendor screens. The cards sit in a
## vertical ScrollContainer (a big deck scrolls instead of running off the window); the Cancel
## button is outside it, so it is always visible. Returns the scroll container.
func add_remove_picker(box: VBoxContainer, on_pick: Callable, on_cancel: Callable) -> ScrollContainer:
	var grid := GridContainer.new()
	grid.columns = PICKER_COLUMNS
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	for i in run.deck.size():
		grid.add_child(card_view(run.deck[i], PICKER_CARD_SCALE, on_pick.bind(i)))
	var scroll := ScrollContainer.new()
	scroll.name = "PickerScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.follow_focus = true # arrow-key focus scrolls the focused card into view
	scroll.add_child(grid)
	# Tall enough for the whole deck, but never more than the window leaves after the title and Cancel.
	# (Computed from the card size: a grid's own minimum size is not settled until it is in the tree.)
	var cell := Vector2(CardView.BASE.x, CardView.BASE.y + CardView.LIFT) * PICKER_CARD_SCALE
	var columns := mini(PICKER_COLUMNS, maxi(run.deck.size(), 1))
	var rows := ceili(float(run.deck.size()) / PICKER_COLUMNS)
	var content := Vector2(columns * cell.x + (columns - 1) * 6.0, rows * cell.y + maxi(rows - 1, 0) * 6.0)
	var window_height := body.get_viewport_rect().size.y if body.is_inside_tree() else 648.0
	scroll.custom_minimum_size = Vector2(content.x, minf(content.y + 2.0, maxf(window_height - PICKER_RESERVED_HEIGHT, 120.0)))
	box.add_child(scroll)
	add_button(box, "Cancel", on_cancel)
	return scroll


static func add_button(box: Container, text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(on_pressed)
	box.add_child(button)
	return button


static func make_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


## A card drawn as a CardView. With `on_pressed` it is clickable and lifts on hover, like a
## button; the tooltip repeats the card's name, cost and text for small sizes.
static func card_view(card: CardData, view_scale: float, on_pressed := Callable()) -> CardView:
	var view := CardView.new()
	view.view_scale = view_scale
	view.set_card(card)
	view.tooltip_text = "%s (%d)\n%s" % [card.display_name, card.cost, card.describe()]
	if on_pressed.is_valid():
		view.clickable = true
		view.auto_hover = true
		view.pressed.connect(on_pressed)
	else:
		view.mouse_filter = Control.MOUSE_FILTER_PASS # still shows its tooltip
	return view


## A dark ribbon with a brass edge, so the words read over the art.
static func style_banner(label: Label) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.11, 0.16, 0.94)
	style.set_border_width_all(2)
	style.border_color = Color("#526979")
	style.set_corner_radius_all(6)
	style.set_content_margin_all(5)
	label.add_theme_stylebox_override("normal", style)
	label.add_theme_color_override("font_color", Color("#d7d0bc"))


## A brass-edged counter button; the stock focus outline is kept visible for the keyboard.
static func style_service(button: Button) -> void:
	var states := {"normal": Color("#171d28"), "hover": Color("#33444d"), "pressed": Color("#101720"), "disabled": Color("#182026")}
	for state in states:
		var style := StyleBoxFlat.new()
		style.bg_color = states[state]
		style.set_border_width_all(2)
		style.border_color = Color("#526979") if state == "disabled" else Color("#9b9e90")
		style.set_corner_radius_all(5)
		style.content_margin_left = 14
		style.content_margin_right = 14
		style.content_margin_top = 6
		style.content_margin_bottom = 6
		button.add_theme_stylebox_override(state, style)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.set_border_width_all(2)
	focus.border_color = Color("#e8b773")
	focus.set_corner_radius_all(5)
	focus.set_expand_margin_all(2)
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_color_override("font_color", Color("#d7d0bc"))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.9))
	button.add_theme_color_override("font_disabled_color", Color(0.62, 0.57, 0.52))
