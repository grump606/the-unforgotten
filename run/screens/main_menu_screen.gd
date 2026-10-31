class_name MainMenuScreen
extends RunScreen
## The start screen, shown on every launch: Continue (only when a valid save exists), New Run, Exit.

const BUTTON_WIDTH := 220.0

var continue_button: Button
var new_run_button: Button
var exit_button: Button
var updates_button: Button


## The label of the update-check toggle for the current setting.
static func update_toggle_text(enabled: bool) -> String:
	return "Check for updates: %s" % ("On" if enabled else "Off")


## `saved` is the run found on disk, or null. `on_continue` is already bound to it by the caller.
## `on_toggle_updates` (when valid) adds the update-check toggle; it is called on each press and
## returns the new setting, which the button label then shows.
func show(saved: RunState, on_continue: Callable, on_new_run: Callable, on_exit: Callable, update_check_on := true, on_toggle_updates := Callable()) -> void:
	add_backdrop(MenuScene.new())
	var box := panel("Card Battle Prototype")
	var title := box.get_child(0) as Label
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.6))
	title.add_theme_color_override("font_outline_color", Color(0.02, 0.01, 0.02, 0.9))
	title.add_theme_constant_override("outline_size", 8)
	if saved != null:
		box.add_child(make_label("Saved run: stop %d/%d, %s, HP %d/%d, Gold %d, Deck %d" % [
			saved.stop_index + 1, saved.stops.size(), saved.player.display_name, saved.player.hp, saved.player.max_hp, saved.gold, saved.deck.size(),
		]))
		continue_button = add_button(box, "Continue", on_continue)
	new_run_button = add_button(box, "New Run", on_new_run)
	exit_button = add_button(box, "Exit", on_exit)
	for button in [continue_button, new_run_button, exit_button]:
		if button != null:
			button.custom_minimum_size = Vector2(BUTTON_WIDTH, 36)
			button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if on_toggle_updates.is_valid():
		updates_button = Button.new()
		updates_button.text = update_toggle_text(update_check_on)
		box.add_child(updates_button)
		updates_button.tooltip_text = "Whether the game asks GitHub for a newer release at launch"
		updates_button.custom_minimum_size = Vector2(BUTTON_WIDTH, 30)
		updates_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		updates_button.pressed.connect(func() -> void: updates_button.text = update_toggle_text(on_toggle_updates.call()))
	(continue_button if continue_button != null else new_run_button).grab_focus()
