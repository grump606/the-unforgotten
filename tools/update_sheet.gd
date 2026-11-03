extends SceneTree
## Screenshots the character select screen and the saved-run Continue prompt with a fake
## "update available" notice (no network). Needs a rendering window (not --headless):
##   godot --path . -s res://tools/update_sheet.gd -- <output dir> [width height]
## Default output is user://update_sheets and the window size is the project's 1152x648.

var out_dir := "user://update_sheets"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	if args.size() > 2:
		DisplayServer.window_set_size(Vector2i(int(args[1]), int(args[2])))
	DirAccess.make_dir_recursive_absolute(out_dir)
	var save_path := out_dir.path_join("scratch_save.json") # never the real save
	var suffix := "_%sx%s" % [args[1], args[2]] if args.size() > 2 else ""
	await _shoot(save_path, "update_select%s.png" % suffix)
	RunSave.save(RunState.new(7, &"deserter"), save_path)
	await _shoot(save_path, "update_continue%s.png" % suffix)
	RunSave.delete(save_path)
	quit()


func _shoot(save_path: String, file: String) -> void:
	var scene: Control = load("res://run.tscn").instantiate()
	scene.save_path = save_path
	root.add_child(scene)
	await _frames()
	var notice: UpdateNotice = scene._update_notice
	notice.current_version = "0.3.0"
	notice.handle_response(200, JSON.stringify({"tag_name": "v0.3.1"}).to_utf8_buffer())
	notice.reveal() # the bar only shows once the red Update button is clicked
	await _frames()
	var path := out_dir.path_join(file)
	root.get_texture().get_image().save_png(path)
	print("saved ", path)
	scene.queue_free()
	await _frames()


func _frames() -> void:
	for i in 4:
		await process_frame
