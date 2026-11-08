class_name MainMenuScreen
extends RunScreen
## The start screen, shown on every launch: Continue (only when a valid save exists), New Run, Exit.

const BUTTON_WIDTH := 320.0
const BUTTON_HEIGHT := 52.0
## Width of the carved title on a 1152-wide screen.
const TITLE_WIDTH := 600.0

var continue_button: Button
var new_run_button: Button
var exit_button: Button
var updates_button: Button
var sound_button: Button
var how_to_play_button: Button
## The sound page while it replaces the menu's buttons (null otherwise).
var sound_page: VBoxContainer
## Kept alive while the page is open: the sliders call back into it.
var _sound_panel: AudioSettingsPanel


const UPDATE_LABEL := "Update"
## Update button colours: border, text and fill for off, on, and "a newer version is available".
const UPDATE_OFF := [Color("#4a5358"), Color("#81898b"), Color("#141a22")]
const UPDATE_ON := [Color("#78a99b"), Color("#a9cfc2"), Color("#1a2a2a")]
const UPDATE_AVAILABLE := [Color("#e0605a"), Color("#ffe3df"), Color("#5a1d1d")]


## The tooltip of the update button for the current state.
static func update_tooltip(enabled: bool, available: bool) -> String:
	if enabled and available:
		return "A newer version is available. Click to see it."
	return "Update checks are %s. Click to turn them %s." % ["on" if enabled else "off", "off" if enabled else "on"]


## Colours the small update button: grey when checks are off, teal when on, red when checks are on
## and a newer version is available.
static func style_update_button(button: Button, enabled: bool, available: bool) -> void:
	var colours: Array = UPDATE_AVAILABLE if enabled and available else (UPDATE_ON if enabled else UPDATE_OFF)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = (colours[2] as Color).lightened(0.12 if state == "hover" else 0.0)
		box.border_color = colours[0]
		box.set_border_width_all(1)
		box.set_corner_radius_all(3)
		box.content_margin_left = 10
		box.content_margin_right = 10
		box.content_margin_top = 2
		box.content_margin_bottom = 2
		button.add_theme_stylebox_override(state, box)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(key, colours[1])
	button.tooltip_text = update_tooltip(enabled, available)


## `saved` is the run found on disk, or null. `on_continue` is already bound to it by the caller.
## `on_toggle_updates` (when valid) adds the update-check toggle; it is called on each press and
## returns the new setting, which the button label then shows.
func show(saved: RunState, on_continue: Callable, on_new_run: Callable, on_exit: Callable, update_check_on := true, on_toggle_updates := Callable(), update_notice: UpdateNotice = null, on_how_to_play := Callable()) -> void:
	add_backdrop(MenuScene.new())
	var box := panel("The Unforgotten")
	var title := box.get_child(0) as Label
	MenuStyle.heading(title, 64)
	title.add_theme_color_override("font_color", Color("#d7d0bc"))
	title.add_theme_color_override("font_outline_color", Color(0.02, 0.01, 0.02, 0.9))
	title.add_theme_constant_override("outline_size", 3)
	_add_title_art(box, title)
	var subtitle := make_label("Someone still remembers you.")
	subtitle.add_theme_color_override("font_color", Color("#8fb8ab"))
	subtitle.add_theme_font_override("font", MenuStyle.serif_font())
	subtitle.add_theme_font_size_override("font_size", 22)
	box.add_child(subtitle)
	if saved != null:
		# The saved run's details sit in a compact panel of their own.
		var details := PanelContainer.new()
		details.name = "SavedRunDetails"
		var tablet := MenuStyle.tablet_box()
		details.add_theme_stylebox_override("panel", tablet if tablet != null else _compact_panel_style())
		details.custom_minimum_size = Vector2(BUTTON_WIDTH + 140.0, 0)
		details.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var summary := make_label("Your journey waits at %s.\n%s  ·  HP %d/%d  ·  Gold %d  ·  Deck %d" % [
			DestinationArt.label_at(saved.stop_index), saved.player.display_name, saved.player.hp, saved.player.max_hp, saved.gold, saved.deck.size(),
		])
		summary.add_theme_font_override("font", MenuStyle.serif_font())
		summary.add_theme_font_size_override("font_size", 18)
		summary.add_theme_color_override("font_color", MenuStyle.TEXT)
		details.add_child(summary)
		box.add_child(details)
		continue_button = add_button(box, "Continue", on_continue)
	new_run_button = add_button(box, "New Journey", on_new_run)
	new_run_button.theme_type_variation = MenuStyle.PLAQUE
	exit_button = add_button(box, "Exit", on_exit)
	# One clear primary action: Continue when there is a save, otherwise New Journey.
	(continue_button if continue_button != null else new_run_button).theme_type_variation = MenuStyle.PLAQUE_PRIMARY
	exit_button.theme_type_variation = MenuStyle.PLAQUE
	for button in [continue_button, new_run_button, exit_button]:
		if button != null:
			button.custom_minimum_size = Vector2(BUTTON_WIDTH, BUTTON_HEIGHT)
			button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if on_toggle_updates.is_valid():
		# A small button in the bottom-right corner of the screen, out of the way of the main choices.
		updates_button = Button.new()
		updates_button.text = UPDATE_LABEL
		updates_button.add_theme_font_size_override("font_size", 12)
		updates_button.focus_mode = Control.FOCUS_NONE
		body.add_child(updates_button)
		updates_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 10)
		var state := {"enabled": update_check_on}  # a lambda sees plain variables by value, so share a dictionary
		# The notice owns the setting while it exists (Skip can turn it off from the bar).
		var enabled_now := func() -> bool:
			return update_notice.user_enabled if update_notice != null else state.enabled
		var restyle := func() -> void:
			if is_instance_valid(updates_button):
				var available := update_notice != null and update_notice.latest_tag != ""
				style_update_button(updates_button, enabled_now.call(), available)
		restyle.call()
		updates_button.pressed.connect(func() -> void:
			# Red (a newer version is waiting): show it instead of switching the checks off.
			if update_notice != null and enabled_now.call() and update_notice.latest_tag != "":
				update_notice.reveal()
				return
			state.enabled = on_toggle_updates.call()
			restyle.call())
		if update_notice != null:
			# The answer from GitHub can arrive while the menu is showing.
			update_notice.changed.connect(restyle)
			updates_button.tree_exiting.connect(update_notice.changed.disconnect.bind(restyle))
	sound_button = Button.new()
	sound_button.text = "Sound"
	sound_button.theme_type_variation = MenuStyle.PLAQUE
	box.add_child(sound_button)
	sound_button.custom_minimum_size = Vector2(BUTTON_WIDTH, BUTTON_HEIGHT)
	sound_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sound_button.pressed.connect(_open_sound.bind(box))
	if on_how_to_play.is_valid():
		how_to_play_button = Button.new()
		how_to_play_button.text = "How to Play"
		how_to_play_button.theme_type_variation = MenuStyle.PLAQUE
		box.add_child(how_to_play_button)
		how_to_play_button.custom_minimum_size = Vector2(BUTTON_WIDTH, BUTTON_HEIGHT)
		how_to_play_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		how_to_play_button.pressed.connect(on_how_to_play)
	(continue_button if continue_button != null else new_run_button).grab_focus()


## A tighter version of the theme's panel, so the save summary does not dominate the menu.
static func _compact_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(MenuStyle.PANEL, 0.85)
	style.border_color = MenuStyle.BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


## Swaps the menu's buttons for the sound page; Back restores them.
func _open_sound(box: VBoxContainer) -> void:
	var hidden: Array[Control] = []
	if updates_button != null:
		updates_button.visible = false
		hidden.append(updates_button)
	for child in box.get_children():
		if child is Control and (child as Control).visible and child != box.get_child(0):
			(child as Control).visible = false
			hidden.append(child)
	sound_page = VBoxContainer.new()
	sound_page.add_theme_constant_override("separation", 12)
	box.add_child(sound_page)
	_sound_panel = AudioSettingsPanel.new()
	_sound_panel.build(sound_page, func() -> void:
		box.remove_child(sound_page)
		sound_page.queue_free()
		sound_page = null
		_sound_panel = null
		for child in hidden:
			child.visible = true
		sound_button.grab_focus())


## Replaces the title text with the carved lettering and puts the bell divider under it. The text
## label stays in the tree, hidden, so the screen still has its title when the art is missing.
func _add_title_art(box: VBoxContainer, title: Label) -> void:
	var art := PaintedArt.texture(MenuStyle.TITLE_PATH)
	if art == null:
		return
	title.visible = false
	var rect := TextureRect.new()
	rect.name = "TitleArt"
	rect.texture = art
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(TITLE_WIDTH, TITLE_WIDTH * art.get_height() / art.get_width())
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(rect)
	box.move_child(rect, 1)
	var divider_art := PaintedArt.texture(MenuStyle.DIVIDER_PATH)
	if divider_art != null:
		var divider := TextureRect.new()
		divider.name = "TitleDivider"
		divider.texture = divider_art
		divider.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		divider.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		divider.custom_minimum_size = Vector2(TITLE_WIDTH * 0.62, TITLE_WIDTH * 0.62 * divider_art.get_height() / divider_art.get_width())
		divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(divider)
		box.move_child(divider, 2)
