class_name TutorialOverlay
extends Control
## The how-to-play pages (words in run/tutorial_content.gd): a dimmed full-window panel with Back, Next and
## Skip. It is shown by itself on the first launch and from the main menu's How to Play button. `closed` fires
## once when the player finishes or skips; the owner then frees it and records that it was seen.

signal closed

const PANEL_SIZE := Vector2(1060, 590)
const BATTLE_SCALE := 0.54
const CARD_SCALE := 1.85
const MARKER_RADIUS := 10.0
const MARKER_FILL := Color("#e8b773")
const MARKER_INK := Color("#1a1208")
const TERM_COLOR := Color("#e8b773")
const TEXT_SIZE := 17
const LEGEND_SIZE := 14

var page := 0
var back_button: Button
var next_button: Button
var skip_button: Button
var title_label: Label
var counter_label: Label

var _content: Control
var _pages: Array[Dictionary]
var _finished := false


func _init() -> void:
	name = "TutorialOverlay"
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pages = TutorialContent.pages()


func _ready() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.84)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backing := PanelContainer.new()
	backing.custom_minimum_size = PANEL_SIZE
	center.add_child(backing)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	backing.add_child(column)
	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	MenuStyle.heading(title_label, 30)
	column.add_child(title_label)
	_content = MarginContainer.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_content)
	column.add_child(_footer())
	show_page(0)
	_trap_focus()
	next_button.grab_focus()


func _footer() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	skip_button = _button("Skip", finish)
	row.add_child(skip_button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	counter_label = Label.new()
	counter_label.add_theme_color_override("font_color", MenuStyle.TEXT)
	row.add_child(counter_label)
	back_button = _button("Back", back)
	row.add_child(back_button)
	next_button = _button("Next", next)
	next_button.theme_type_variation = MenuStyle.PLAQUE_PRIMARY
	row.add_child(next_button)
	return row


func _button(text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.theme_type_variation = MenuStyle.PLAQUE_SMALL
	button.custom_minimum_size = Vector2(110, 44)
	button.pressed.connect(on_pressed)
	button.pressed.connect(RunScreen.sfx.bind(&"click"))
	return button


func page_count() -> int:
	return _pages.size()


func next() -> void:
	if page >= _pages.size() - 1:
		finish()
	else:
		show_page(page + 1)


func back() -> void:
	show_page(maxi(page - 1, 0))


## Closes the tutorial (Done on the last page, or Skip / Escape on any page). Fires `closed` once.
func finish() -> void:
	if _finished:
		return
	_finished = true
	release_focus_trap()
	closed.emit()


func show_page(index: int) -> void:
	page = clampi(index, 0, _pages.size() - 1)
	var entry: Dictionary = _pages[page]
	title_label.text = entry.title
	counter_label.text = "%d / %d" % [page + 1, _pages.size()]
	back_button.disabled = page == 0
	next_button.text = "Done" if page == _pages.size() - 1 else "Next"
	skip_button.visible = page < _pages.size() - 1
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	var built: Control
	match entry.kind:
		TutorialContent.Kind.BATTLE:
			built = _battle_page(entry)
		TutorialContent.Kind.CARD:
			built = _card_page(entry)
		TutorialContent.Kind.ICONS:
			built = _icons_page(entry)
		TutorialContent.Kind.KEYWORDS:
			built = _keywords_page(entry)
		_:
			built = _text_page(entry)
	_content.add_child(built)


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match (event as InputEventKey).keycode:
		KEY_RIGHT:
			next()
		KEY_ENTER, KEY_KP_ENTER:
			# A focused button (Skip, Back, Next) answers Enter itself; anywhere else Enter means Next.
			var owner_control := get_viewport().gui_get_focus_owner()
			if owner_control is Button and is_ancestor_of(owner_control):
				return
			next()
		KEY_LEFT:
			back()
		KEY_ESCAPE:
			finish()
		_:
			return
	get_viewport().set_input_as_handled()


## Controls outside the overlay that were focusable when it opened, with the mode to give back.
var _trapped: Dictionary = {}


## Makes the overlay modal for the keyboard: nothing behind it can take Tab, Space or Enter while it is open.
func _trap_focus() -> void:
	var anchor: Node = get_parent()
	if anchor == null:
		return
	var behind := get_viewport().gui_get_focus_owner()
	if behind != null and not is_ancestor_of(behind):
		behind.release_focus()
	var stack: Array[Node] = [anchor]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node == self:
			continue
		if node is Control and (node as Control).focus_mode != Control.FOCUS_NONE:
			_trapped[node] = (node as Control).focus_mode
			(node as Control).focus_mode = Control.FOCUS_NONE
		stack.append_array(node.get_children())


## Gives back the focus modes taken by _trap_focus (also done when the overlay leaves the tree).
func release_focus_trap() -> void:
	for node in _trapped:
		if is_instance_valid(node):
			(node as Control).focus_mode = _trapped[node]
	_trapped.clear()


func _exit_tree() -> void:
	release_focus_trap()


# --- page builders -----------------------------------------------------------------------------

func _label(text: String, size: int, color := MenuStyle.TEXT) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _text_page(entry: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if entry.lead != "":
		box.add_child(_label(entry.lead, TEXT_SIZE + 3, Color("#d7d0bc")))
	for line in entry.items:
		var text: String = line
		box.add_child(_label(text if text.substr(0, 1).is_valid_int() else "•  " + text, TEXT_SIZE))
	return box


## Picture on the left with numbered markers on it, the numbered explanations on the right.
func _legend_page(picture: Control, points: Array, items: Array) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	var holder := Control.new()
	holder.custom_minimum_size = picture.custom_minimum_size
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	holder.add_child(picture)
	var markers := TutorialMarkers.new()
	markers.points = points
	markers.size = picture.custom_minimum_size
	markers.custom_minimum_size = picture.custom_minimum_size
	holder.add_child(markers)
	row.add_child(holder)
	var legend := VBoxContainer.new()
	legend.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	legend.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	legend.add_theme_constant_override("separation", 7)
	for i in items.size():
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 8)
		var badge := TutorialMarkers.new()
		badge.points = [Vector2(MARKER_RADIUS + 1, MARKER_RADIUS + 1)]
		badge.first_number = i + 1
		badge.custom_minimum_size = Vector2.ONE * (MARKER_RADIUS * 2 + 2)
		badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		line.add_child(badge)
		var text := _label(items[i].text, LEGEND_SIZE)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(text)
		legend.add_child(line)
	row.add_child(legend)
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return row


func _battle_page(entry: Dictionary) -> Control:
	var picture := TextureRect.new()
	picture.texture = PaintedArt.texture(TutorialContent.BATTLE_IMAGE)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_SCALE
	picture.custom_minimum_size = TutorialContent.BATTLE_IMAGE_SIZE * BATTLE_SCALE
	picture.size = picture.custom_minimum_size
	var points: Array = []
	for item in entry.items:
		points.append((item.at as Vector2) * BATTLE_SCALE)
	return _legend_page(picture, points, entry.items)


func _card_page(entry: Dictionary) -> Control:
	var card := load("res://data/cards/heavy_blow.tres") as CardData
	var view := CardView.new()
	view.view_scale = CARD_SCALE
	view.set_card(card)
	view.hotkey = 1
	view.tooltip_text = ""
	view.custom_minimum_size = Vector2(CardView.BASE.x, CardView.BASE.y + CardView.LIFT) * CARD_SCALE
	var points: Array = []
	for item in entry.items:
		points.append(((item.at as Vector2) + Vector2(0, CardView.LIFT)) * CARD_SCALE)
	return _legend_page(view, points, entry.items)


func _icons_page(entry: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.add_child(_label(entry.lead, TEXT_SIZE))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 26)
	grid.add_theme_constant_override("v_separation", 9)
	for item in entry.items:
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 10)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var icon := TutorialIcon.new()
		icon.icon = item.icon
		icon.color_kind = item.color_kind
		cell.add_child(icon)
		cell.add_child(_term_text(item.name, item.text))
		grid.add_child(cell)
	box.add_child(grid)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return box


func _keywords_page(entry: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.add_child(_label(entry.lead, TEXT_SIZE))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 26)
	grid.add_theme_constant_override("v_separation", 10)
	for row in TutorialContent.keyword_rows():
		var cell := _term_text(row[0], row[1])
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(cell)
	box.add_child(grid)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return box


## A term in gold over its explanation.
func _term_text(term: String, text: String) -> Control:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 1)
	column.add_child(_label(term, LEGEND_SIZE + 1, TERM_COLOR))
	column.add_child(_label(text, LEGEND_SIZE))
	return column


## Numbered gold discs drawn over a picture (or, alone, the number badge beside an explanation).
class TutorialMarkers:
	extends Control

	var points: Array = []
	## The number on the first disc; the next ones count up.
	var first_number := 1

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var font: Font = ThemeDB.fallback_font
		for i in points.size():
			var c: Vector2 = points[i]
			draw_circle(c, MARKER_RADIUS + 1.5, Color(0, 0, 0, 0.7))
			draw_circle(c, MARKER_RADIUS, MARKER_FILL)
			var number := str(first_number + i)
			draw_string(font, c + Vector2(-20, 5), number, HORIZONTAL_ALIGNMENT_CENTER, 40, 14, MARKER_INK)


## An Omen badge or status pill icon, drawn with the same code the fight screen uses.
class TutorialIcon:
	extends Control

	var icon: StringName = &"intent"
	var color_kind: int = CardEffect.Kind.DAMAGE

	func _init() -> void:
		custom_minimum_size = Vector2(34, 34)
		size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var col := CardView.kind_color(color_kind)
		var c := size / 2.0
		draw_circle(c, 16.0, Color(0, 0, 0, 0.6))
		draw_circle(c, 14.5, Color(col.darkened(0.5), 0.95))
		draw_arc(c, 14.5, 0, TAU, 28, col, 1.8, true)
		if icon == &"intent":
			HudIcons.intent(self, color_kind, c, col)
		else:
			HudIcons.status(self, icon, c, col.lightened(0.3), 2.2)
