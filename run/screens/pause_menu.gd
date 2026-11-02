class_name PauseMenu
extends RefCounted
## The pause menu: a Pause button in the corner and a full-screen overlay that freezes the scene
## tree. Owned by run.gd, which supplies the run and the save-and-exit behaviour as callables.

## The corner button, the overlay, the column of options inside it and the animated backdrop.
var button: Button
var overlay: Control
var box: VBoxContainer
var backdrop: PauseScene

var _host: Control
## Returns the current RunState (null before a run starts).
var _get_run: Callable
## Saves and exits; returns "" when the exit was requested, else the reason it did not happen.
var _save_and_exit: Callable
## Called after the player confirms abandoning the run (the menu is already closed).
var _on_new_run: Callable


func _init(host: Control, get_run: Callable, save_and_exit: Callable, on_new_run: Callable) -> void:
	_host = host
	_get_run = get_run
	_save_and_exit = save_and_exit
	_on_new_run = on_new_run


## Builds the button and overlay as children of the host.
func build() -> void:
	# The host keeps running while the tree is paused (the overlay buttons and the Escape key
	# need to); run.gd makes only the run body, which holds the fight, pausable.
	button = Button.new()
	button.text = "Pause"
	button.visible = false
	button.focus_mode = Control.FOCUS_NONE # keys belong to the battle screen
	button.pressed.connect(set_paused.bind(true))
	_host.add_child(button)
	button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 12)

	overlay = Control.new()
	overlay.visible = false
	_host.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	# Opaque, so the pause is a full screen of its own rather than a veil over the fight.
	dim.color = Color(0.04, 0.04, 0.07)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP # nothing underneath can be clicked
	overlay.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop = PauseScene.new() # animated backdrop; only runs while the overlay is visible
	overlay.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)


## Escape toggles the menu while it is open or the Pause button is available.
func handle_key(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo or event.keycode != KEY_ESCAPE:
		return
	if overlay.visible or button.visible:
		set_paused(not overlay.visible)
		_host.get_viewport().set_input_as_handled()


func set_paused(on: bool) -> void:
	_host.get_tree().paused = on
	overlay.visible = on
	if on:
		var run: RunState = _get_run.call()
		backdrop.set_character(run.character.id if run != null and run.character != null else &"")
		show_options("")


func show_options(message: String) -> void:
	_clear()
	_add_label("A moment of quiet", 36)
	_add_label("Your journey is paused.")
	if message != "":
		_add_label(message)
	var run: RunState = _get_run.call()
	if run != null and not run.relics.is_empty():
		_add_label("Relics")
		var strip := RelicStrip.create(run.relics)
		strip.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_child(strip)
	RunScreen.add_button(box, "Continue", set_paused.bind(false))
	RunScreen.add_button(box, "Save & Exit", _try_save_and_exit)
	RunScreen.add_button(box, "New Journey", _confirm_new_run)
	_add_label("Your journey is saved on arrival at each destination.\nSave & Exit returns you to the start of this destination.")


func _confirm_new_run() -> void:
	_clear()
	_add_label("Leave this journey behind?", 36)
	_add_label("Your current journey will be replaced.")
	RunScreen.add_button(box, "Begin a new journey", _start_new_run)
	RunScreen.add_button(box, "Cancel", show_options.bind(""))


func _start_new_run() -> void:
	set_paused(false)
	_on_new_run.call()


func _try_save_and_exit() -> void:
	var problem: String = _save_and_exit.call()
	if problem != "":
		show_options(problem)


func _clear() -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()


func _add_label(text: String, font_size: int = 0) -> void:
	var label := Label.new()
	label.text = text
	if font_size > 0:
		MenuStyle.heading(label, font_size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(label)
