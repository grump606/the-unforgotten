extends SceneTree
## Screenshots the treasure stop through the real run scene (the engine's own viewport capture): the closed chest, the
## opened chest with its relic and the gold fallback, at the project size and at 800x450. Needs a rendering window
## (not --headless):
##   godot --path . -s res://tools/treasure_sheet.gd -- <output dir>
## Default output is user://treasure_sheets.

var out_dir := "user://treasure_sheets"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	var scene: Control = load("res://run.tscn").instantiate()
	scene.save_path = "user://treasure_sheet_save.json"
	root.add_child(scene)
	for i in 8:
		await process_frame
	for size in [Vector2i(1152, 648), Vector2i(800, 450)]:
		root.size = size
		for character in [&"deserter", &"stray"]:
			scene.start_debug_screen(DebugLaunch.parse(PackedStringArray(["--screen=treasure", "--character=%s" % character]), {}))
			await _settle()
			await _shot("closed_%s_%d" % [character, size.x])
			scene._run.open_treasure()
			scene._show_stop()
			await _settle()
			await _shot("opened_%s_%d" % [character, size.x])
		scene.start_debug_screen(DebugLaunch.parse(PackedStringArray(["--screen=treasure:2"]), {}))
		await _settle()
		scene._run.relics.assign(StarterContent.relic_pool(scene._run.character.id))
		scene._run.open_treasure()
		scene._show_stop()
		await _settle()
		await _shot("gold_%d" % size.x)
	quit()


func _settle() -> void:
	for i in 6:
		await process_frame


func _shot(file: String) -> void:
	var path := out_dir.path_join(file + ".png")
	root.get_texture().get_image().save_png(path)
	print("saved ", path)
