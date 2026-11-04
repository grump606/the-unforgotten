class_name ChoiceOverlay
extends Control
## The Glimpse / Recall pick, drawn over the stage while Combat is in Phase.CHOOSING. It lists
## Combat.choice_cards() as card views in the order the engine gives them (for Glimpse the next card
## drawn is first), lets the player mark cards, and emits `confirmed` with the marked indices. It never
## talks to Combat itself: the battle screen owns the call to resolve_choice, so the overlay cannot be
## used to skip the rules. A choice cannot be backed out of, so there is no cancel.
##
## Glimpse: marked cards are DISCARDED (dimmed and stamped like the discard step); marking none is allowed
## ("Keep all"). Recall: exactly `required` cards must be marked (gold frame) before the button works.

signal confirmed(indices: Array[int])

## Card scales tried from largest to smallest; below the last one the card list scrolls.
const SCALES: Array[float] = [0.9, 0.8, 0.7, 0.6, 0.55]
const GAP := 6.0
## Room kept clear: the enemy HP bars along the bottom of the stage, and the top strip with the prompt.
const MARGIN_BOTTOM := 74.0
const MARGIN_TOP := 36.0
const MARGIN_SIDE := 28.0
## Heading, hint and button row take about this much of the panel's height besides the cards.
const CHROME_H := 120.0
const DIM := Color(0.02, 0.03, 0.05, 0.5)

var kind: CardEffect.Kind = CardEffect.Kind.GLIMPSE
var cards: Array[CardData] = []
var required := 0
var max_picks := 0
## Indices into `cards` that are marked, ascending.
var marks: Array[int] = []
var heading_label: Label
var hint_label: Label
var confirm_button: Button
var card_scale := 0.9

var _views: Array[CardView] = []
var _flow: HFlowContainer
var _live: Combatant = null


## Builds the overlay for the open choice of `combat`. `area` is the stage size (cards are scaled to fit).
static func create(combat: Combat, area: Vector2, live_player: Combatant = null) -> ChoiceOverlay:
	var overlay := ChoiceOverlay.new()
	overlay.kind = combat.choice_kind()
	overlay.cards = combat.choice_cards().duplicate()
	overlay.required = combat.choice_required()
	overlay.max_picks = combat.choice_max()
	overlay._live = live_player
	overlay._build(area)
	return overlay


## The largest card scale at which `count` cards fit `width` x `height` (wrapping onto rows).
static func fit_scale(count: int, width: float, height: float) -> float:
	for s in SCALES:
		var card_w := CardView.BASE.x * s
		var per_row := maxi(int(floorf((width + GAP) / (card_w + GAP))), 1)
		var rows := ceili(float(count) / per_row)
		if rows * (CardView.BASE.y + CardView.LIFT) * s + (rows - 1) * GAP <= height:
			return s
	return SCALES[SCALES.size() - 1]


## True when the choice is a Glimpse (picks are discarded), false for a Recall (picks return to hand).
func is_glimpse() -> bool:
	return kind == CardEffect.Kind.GLIMPSE


## True when the cards and kind match this overlay (so a refresh keeps the player's marks).
func matches(combat: Combat) -> bool:
	if combat.choice_kind() != kind or combat.choice_required() != required:
		return false
	var other := combat.choice_cards()
	if other.size() != cards.size():
		return false
	for i in cards.size():
		if other[i] != cards[i]:
			return false
	return true


## Marks or unmarks card `index`. A Recall that allows one pick swaps to the new card; one that allows
## several ignores a mark past the limit. False when nothing changed.
func toggle(index: int) -> bool:
	if index < 0 or index >= cards.size():
		return false
	if marks.has(index):
		marks.erase(index)
	else:
		if marks.size() >= max_picks:
			if max_picks != 1:
				return false
			marks.clear()
		marks.append(index)
		marks.sort()
	_sync()
	return true


## True when the marks satisfy the choice (Glimpse: always; Recall: exactly `required`).
func can_confirm() -> bool:
	return marks.size() >= required and marks.size() <= max_picks


## Emits `confirmed` with the marks when they are valid. False when the button is not available.
func confirm() -> bool:
	if not can_confirm():
		return false
	confirmed.emit(marks.duplicate())
	return true


## Number keys 1-9 and 0 toggle cards 1-10, Enter confirms. True when the key was used.
func handle_key(keycode: int) -> bool:
	var number := keycode - KEY_1
	if keycode == KEY_0:
		number = 9
	if number >= 0 and number < _views.size() and number < 10:
		toggle(number)
		return true
	if keycode == KEY_ENTER or keycode == KEY_KP_ENTER:
		confirm()
		return true
	return false


func _build(area: Vector2) -> void:
	name = "ChoiceOverlay"
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = DIM
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if area.x < 200.0 or area.y < 100.0:
		area = Vector2(1152, 420)
	var inner_w := area.x - 2.0 * MARGIN_SIDE - 40.0
	var cards_h := maxf(area.y - MARGIN_TOP - MARGIN_BOTTOM - CHROME_H, 120.0)
	card_scale = fit_scale(cards.size(), inner_w, cards_h)
	var rows := ceili(float(cards.size()) / maxi(int(floorf((inner_w + GAP) / (CardView.BASE.x * card_scale + GAP))), 1))
	var list_h := minf(rows * (CardView.BASE.y + CardView.LIFT) * card_scale + (rows - 1) * GAP + 6.0, cards_h)

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var box := StyleBoxFlat.new()
	box.bg_color = Color(MenuStyle.BG, 0.96)
	box.border_color = MenuStyle.AMBER
	box.set_border_width_all(2)
	box.set_corner_radius_all(8)
	box.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", box)
	add_child(panel)
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = MARGIN_SIDE
	panel.offset_right = -MARGIN_SIDE
	panel.offset_bottom = -MARGIN_BOTTOM
	panel.offset_top = -MARGIN_BOTTOM - (list_h + CHROME_H)
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	heading_label = Label.new()
	heading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading_label.add_theme_font_size_override("font_size", 22)
	heading_label.add_theme_color_override("font_color", MenuStyle.AMBER)
	column.add_child(heading_label)
	hint_label = Label.new()
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 13)
	hint_label.add_theme_color_override("font_color", MenuStyle.TEXT_DIM)
	column.add_child(hint_label)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, list_h)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	_flow = HFlowContainer.new()
	_flow.alignment = FlowContainer.ALIGNMENT_CENTER
	_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_flow.add_theme_constant_override("h_separation", int(GAP))
	_flow.add_theme_constant_override("v_separation", int(GAP))
	scroll.add_child(_flow)
	for i in cards.size():
		var view := CardView.new()
		view.view_scale = card_scale
		view.auto_hover = true
		view.clickable = true
		view.live = _live
		view.set_card(cards[i])
		view.hotkey = i + 1 if i < 10 else 0
		view.pressed.connect(toggle.bind(i))
		_flow.add_child(view)
		_views.append(view)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(row)
	confirm_button = Button.new()
	confirm_button.theme_type_variation = MenuStyle.PRIMARY
	confirm_button.custom_minimum_size = Vector2(190, 40)
	confirm_button.focus_mode = Control.FOCUS_NONE
	confirm_button.pressed.connect(confirm)
	row.add_child(confirm_button)
	_sync()


## Redraws the marks, the heading and the confirm button from `marks`.
func _sync() -> void:
	if is_glimpse():
		heading_label.text = "Glimpse: tap cards to discard"
		hint_label.text = "The top of your draw pile, next card first. Unmarked cards stay on top in this order."
		confirm_button.text = "Keep all" if marks.is_empty() else "Discard %d" % marks.size()
	else:
		heading_label.text = "Recall: choose %d to return to your hand" % required
		hint_label.text = "From the Forgotten pile. A recalled card is Forgotten again if you play it."
		confirm_button.text = "Recall %d of %d" % [marks.size(), required]
	confirm_button.disabled = not can_confirm()
	for i in _views.size():
		var marked := marks.has(i)
		_views[i].discard_marked = marked and is_glimpse()
		_views[i].set_state(CardView.State.SELECTED if marked and not is_glimpse() else CardView.State.NORMAL)
