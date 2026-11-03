class_name SelectScreen
extends RunScreen
## The character select screen: one panel per passenger, plus a Back button along the bottom edge.

const HEADING := "Choose who answers the voice"
const BACK_SIZE := Vector2(160, 44)
const BACK_MARGIN := 18.0

## The container holding the character panels (re-centred as the layout moves).
var _center: CenterContainer
var _host: Control


## `host` is the whole run screen: the group is centred in it rather than in the body, which sits
## below the header line. `on_play` receives the chosen character id; a valid `back` adds a Back button.
func show(host: Control, on_play: Callable, back := Callable()) -> void:
	_host = host
	add_backdrop(SelectScene.new())
	var heading := Label.new()
	heading.text = HEADING
	MenuStyle.heading(heading, 30)
	body.add_child(heading)
	heading.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 18)
	_center = CenterContainer.new()
	body.add_child(_center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	_center.add_child(column)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	column.add_child(row)
	if back.is_valid():
		# Pinned to the bottom edge, outside the centred group, so the panels stay centred.
		var back_button := Button.new()
		back_button.text = "Back"
		back_button.pressed.connect(back)
		body.add_child(back_button)
		back_button.theme_type_variation = MenuStyle.PLAQUE_SMALL
		back_button.custom_minimum_size = Vector2(BACK_SIZE)
		# Centred exactly on the bottom edge: both horizontal anchors at the middle with symmetric offsets
		# (the size-based presets drifted off-centre once the plaque theme changed the button's size).
		back_button.anchor_left = 0.5
		back_button.anchor_right = 0.5
		back_button.anchor_top = 1.0
		back_button.anchor_bottom = 1.0
		back_button.offset_left = -BACK_SIZE.x / 2.0
		back_button.offset_right = BACK_SIZE.x / 2.0
		back_button.offset_top = -BACK_SIZE.y - BACK_MARGIN
		back_button.offset_bottom = -BACK_MARGIN
		back_button.grow_horizontal = Control.GROW_DIRECTION_BOTH
		back_button.grow_vertical = Control.GROW_DIRECTION_BEGIN
	for id in StarterContent.character_ids():
		var character := StarterContent.character(id)
		if character != null:
			var character_panel := CharacterPanel.new(character)
			character_panel.play_pressed.connect(on_play)
			row.add_child(character_panel)
	if row.get_child_count() == 0:
		row.add_child(make_label("No characters could be loaded (content failed to load). See the Output log."))
	else:
		(row.get_child(0) as CharacterPanel).play_button.grab_focus() # keyboard: arrows move between panels
	recenter()
	recenter.call_deferred() # the layout settles after this frame


## Keeps the group centred in the whole window rather than in the body.
func recenter() -> void:
	if is_instance_valid(_center) and is_instance_valid(_host):
		_center.position = -(body.global_position - _host.global_position)
		_center.size = _host.size
