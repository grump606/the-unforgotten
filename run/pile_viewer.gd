class_name PileViewer
extends Control
## Read-only look at the Draw, Discard or Forgotten pile, opened from the pile counters on the battle
## screen. The Draw pile is listed SORTED (cost, then name) so it never reveals the draw order. Closes with
## Esc, the Close button, or a click outside the panel. It changes nothing in the fight.

signal closed

enum Pile { DRAW, DISCARD, FORGOTTEN, SWORN }

const PILE_NAMES := ["Draw", "Discard", "Forgotten", "Sworn"]
const NOTES := [
	"In no particular order.",
	"Most recently discarded last.",
	"Cards that were Forgotten this fight.",
	"Oath cards you have sworn this fight.",
]
const SCALES: Array[float] = [0.8, 0.7, 0.6, 0.5]
const GAP := 6.0
## Layer of the viewer when used on its own (the battle sets its own, BattleOverlays.Z).
const Z := 25

var pile: Pile = Pile.DRAW
var tab_buttons: Array[Button] = []
var note_label: Label
var close_button: Button

var _combat: Combat
var _flow: HFlowContainer
var _scroll: ScrollContainer
var _area := MenuStyle.BASE_SIZE
var _live: Combatant = null


static func create(combat: Combat, which: Pile, area: Vector2, live_player: Combatant = null) -> PileViewer:
	var viewer := PileViewer.new()
	viewer._combat = combat
	viewer.pile = which
	viewer._live = live_player
	if area.x >= 300.0 and area.y >= 200.0:
		viewer._area = area
	viewer._build()
	return viewer


## The cards shown for `which`, in display order: Draw sorted by cost then name, the others as they lie.
static func shown_cards(piles: CardPiles, which: Pile) -> Array[CardData]:
	var cards: Array[CardData] = []
	match which:
		Pile.DRAW:
			cards.assign(piles.draw_pile)
			cards.sort_custom(func(a: CardData, b: CardData) -> bool:
				if a.cost != b.cost:
					return a.cost < b.cost
				if a.display_name != b.display_name:
					return a.display_name < b.display_name
				return String(a.id) < String(b.id))
		Pile.DISCARD:
			cards.assign(piles.discard_pile)
		Pile.FORGOTTEN:
			cards.assign(piles.forgotten)
		Pile.SWORN:
			cards.assign(piles.sworn)
	return cards


## Cards on screen right now (read by tests).
func card_views() -> Array[CardView]:
	return CardView.find_all(_flow)


func show_pile(which: Pile) -> void:
	pile = which
	_fill()


## Re-reads the pile (the counts on the tabs and the cards), keeping the open tab.
func refresh() -> void:
	_fill()


func _build() -> void:
	name = "PileViewer"
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = Z
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.05, 0.62)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := _build_panel()
	_build_tabs(column)
	note_label = Label.new()
	note_label.add_theme_font_size_override("font_size", 13)
	note_label.add_theme_color_override("font_color", MenuStyle.TEXT_DIM)
	column.add_child(note_label)
	_build_card_area(column)
	_fill()


## The bordered panel, centred and a little above the middle; returns its column.
func _build_panel() -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var box := StyleBoxFlat.new()
	box.bg_color = Color(MenuStyle.BG, 0.97)
	box.border_color = MenuStyle.BORDER
	box.set_border_width_all(2)
	box.set_corner_radius_all(8)
	box.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", box)
	add_child(panel)
	var width := minf(_area.x - 80.0, 980.0)
	var height := minf(_area.y - 90.0, 470.0)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -width / 2.0
	panel.offset_right = width / 2.0
	panel.offset_top = -height / 2.0 - 20.0
	panel.offset_bottom = height / 2.0 - 20.0
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	return column


## One toggle tab per pile, a spacer, and the Close button.
func _build_tabs(column: VBoxContainer) -> void:
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	column.add_child(tabs)
	for i in PILE_NAMES.size():
		var tab := Button.new()
		tab.toggle_mode = true
		tab.focus_mode = Control.FOCUS_ALL # Tab reaches the tabs; the pile keys still work (see BattleKeys)
		tab.theme_type_variation = MenuStyle.QUIET
		tab.custom_minimum_size = Vector2(130, 34)
		tab.pressed.connect(show_pile.bind(i as Pile))
		tabs.add_child(tab)
		tab_buttons.append(tab)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_child(spacer)
	close_button = Button.new()
	close_button.text = "Close (Esc)"
	close_button.focus_mode = Control.FOCUS_ALL
	close_button.custom_minimum_size = Vector2(110, 34)
	close_button.pressed.connect(close)
	tabs.add_child(close_button)


## The scrolling flow the card views are put in (filled by _fill).
func _build_card_area(column: VBoxContainer) -> void:
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_scroll)
	_flow = HFlowContainer.new()
	_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_flow.add_theme_constant_override("h_separation", int(GAP))
	_flow.add_theme_constant_override("v_separation", int(GAP))
	_scroll.add_child(_flow)


## Brings the tabs, the note and the card views up to date. The card views already on screen are reused in place
## (like BattleHand.sync): a view is rewritten only when its card or the scale differs, views are added or removed
## only when the card count changes, so a refresh with nothing new does no work and a switch of tab keeps the nodes.
func _fill() -> void:
	var cards := shown_cards(_combat.piles, pile)
	for i in tab_buttons.size():
		var count := shown_cards(_combat.piles, i as Pile).size()
		tab_buttons[i].text = "%s %d" % [PILE_NAMES[i], count]
		tab_buttons[i].button_pressed = i == pile
	note_label.text = NOTES[pile] if not cards.is_empty() else "%s This pile is empty." % NOTES[pile]
	var width := minf(_area.x - 80.0, 980.0) - 50.0
	var height := minf(_area.y - 90.0, 470.0) - 110.0
	var scale := SCALES[SCALES.size() - 1]
	for s in SCALES:
		var per_row := maxi(int(floorf((width + GAP) / (CardView.BASE.x * s + GAP))), 1)
		var rows := ceili(float(cards.size()) / per_row)
		if rows * (CardView.BASE.y + CardView.LIFT) * s + (rows - 1) * GAP <= height:
			scale = s
			break
	var views := card_views()
	for i in cards.size():
		var view: CardView
		if i < views.size():
			view = views[i]
		else:
			view = CardView.new()
			view.live = _live
			view.set_state(CardView.State.NORMAL)
			_flow.add_child(view)
		if view.view_scale != scale:
			view.view_scale = scale
		if view.card != cards[i]:
			view.set_card(cards[i])
	for i in range(cards.size(), views.size()):
		_flow.remove_child(views[i])
		views[i].queue_free()


func close() -> void:
	closed.emit()


func _gui_input(event: InputEvent) -> void:
	# Only reached by clicks outside the panel (the panel itself stops the mouse).
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		close()
