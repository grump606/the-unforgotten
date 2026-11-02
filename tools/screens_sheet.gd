extends SceneTree
## Screenshots the rest stop (each class), the four story beats (Deserter, plus the Medium's
## boarding beat and the empty-platform beat of the Pickpocket and the Medium), both end cards, and the same rest stop and end card at two moments to show motion.
## Needs a rendering window (not --headless):
##   godot --path . -s res://tools/screens_sheet.gd -- <output dir>
## Default output is user://screen_sheets. The shots use the project's 1152x648 window.

var out_dir := "user://screen_sheets"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	for id in [&"deserter", &"pickpocket", &"medium"]:
		var scene: Control = await _run(id)
		_go_to(scene, RunState.StopType.REST, 0)
		await _shot(scene, "rest_%s.png" % id, 3.0)
		if id == &"deserter":
			await _shot(scene, "rest_%s_later.png" % id, 6.4)
		if id == &"medium":
			_go_to(scene, RunState.StopType.STORY, 0)
			await _shot(scene, "story_boarding_medium.png", 2.0)
		if id != &"deserter": # the deserter's beat 2 is story_2.png below
			_go_to(scene, RunState.StopType.STORY, 2)
			await _shot(scene, "story_platform_%s.png" % id, 2.0)
		scene.queue_free()
		await process_frame
	var scene: Control = await _run(&"deserter")
	for beat in 4:
		_go_to(scene, RunState.StopType.STORY, beat)
		await _shot(scene, "story_%d.png" % beat, 3.0)
	scene._run.player.hp = 12
	for escaped in [true, false]:
		scene._run.stop_index = scene._run.stops.size() if escaped else 19
		scene._run.finished = true
		scene._run.escaped = escaped
		scene._show_stop()
		var name := "escape" if escaped else "defeat"
		await _shot(scene, "end_%s.png" % name, 1.0)
		await _shot(scene, "end_%s_later.png" % name, 7.0)
	DirAccess.remove_absolute(out_dir.path_join("scratch_save.json"))
	quit()


func _run(id: StringName) -> Control:
	var scene: Control = load("res://run.tscn").instantiate()
	scene.save_path = out_dir.path_join("scratch_save.json") # never the real save
	root.add_child(scene)
	await process_frame
	scene._start_run(id)
	return scene


## Jumps to the first stop of `type` (for STORY, the one with this beat index).
func _go_to(scene: Control, type: int, beat: int) -> void:
	var run: RunState = scene._run
	for i in run.stops.size():
		if run.stops[i].type == type:
			if type == RunState.StopType.STORY:
				if run.stops[i].beat_index == beat:
					run.stop_index = i
					break
			else:
				run.stop_index = i
				break
	run.player.hp = run.player.max_hp - 18
	scene._show_stop()


func _shot(scene: Control, file: String, seconds: float) -> void:
	for i in 4:
		await process_frame
	var backdrop: ScreenScene = scene.find_children("*", "ScreenScene", true, false)[0]
	backdrop.time = seconds
	backdrop.advance(0.0)
	await process_frame
	backdrop.time = seconds
	backdrop.advance(0.0)
	await process_frame
	var path := out_dir.path_join(file)
	root.get_texture().get_image().save_png(path)
	print("saved ", path)
