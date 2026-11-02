extends SceneTree
## Screenshots the character select screen: as it opens, then with each panel hovered.
## Needs a rendering window (not --headless):
##   godot --path . -s res://tools/select_sheet.gd -- <output dir> [width height]
## Default output is user://select_sheets and the window size is the project's 1152x648.

var out_dir := "user://select_sheets"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	if args.size() > 2:
		DisplayServer.window_set_size(Vector2i(int(args[1]), int(args[2])))
	DirAccess.make_dir_recursive_absolute(out_dir)
	var scene: Control = load("res://run.tscn").instantiate()
	scene.save_path = out_dir.path_join("scratch_save.json") # never the real save
	root.add_child(scene)
	await _frames()
	_save("menu.png")
	for button in scene.find_children("*", "Button", true, false):
		if (button as Button).text == "New Journey":
			(button as Button).pressed.emit()
	await _frames()
	var suffix := "_%sx%s" % [args[1], args[2]] if args.size() > 2 else ""
	_save("select_default%s.png" % suffix)
	var panels: Array[CharacterPanel] = []
	_find_panels(scene, panels)
	for panel in panels:
		(panel.play_button as Button).release_focus()
	for panel in panels:
		panel.set_hovered(true)
		await _frames()
		_save("select_hover_%s%s.png" % [panel.character_id, suffix])
		panel.set_hovered(false)
	DirAccess.remove_absolute(out_dir.path_join("scratch_save.json"))
	quit()


func _frames() -> void:
	for i in 4:
		await process_frame


func _find_panels(node: Node, out: Array[CharacterPanel]) -> void:
	if node is CharacterPanel:
		out.append(node)
	for child in node.get_children():
		_find_panels(child, out)


func _save(file: String) -> void:
	var path := out_dir.path_join(file)
	root.get_texture().get_image().save_png(path)
	print("saved ", path)
