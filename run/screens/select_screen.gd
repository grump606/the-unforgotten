class_name SelectScreen
extends RunScreen
## The character select screen: one panel per passenger, plus a Back button along the bottom edge.

## The container holding the character panels (re-centred as the layout moves).
var _center: CenterContainer
var _host: Control


## `host` is the whole run screen: the group is centred in it rather than in the body, which sits
## below the header line. `on_play` receives the chosen character id; a valid `back` adds a Back button.
func show(host: Control, on_play: Callable, back := Callable()) -> void:
	_host = host
	add_backdrop(SelectScene.new())
	_center = CenterContainer.new()
	body.add_child(_center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	_center.add_child(column)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	column.add_child(row)
	if back.is_valid():
		# Pinned to the bottom edge, outside the centred group, so the panels stay centred.
		var back_button := Button.new()
		back_button.text = "Back"
		back_button.pressed.connect(back)
		body.add_child(back_button)
		back_button.custom_minimum_size = Vector2(140, 34)
		back_button.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 14)
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
