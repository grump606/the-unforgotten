extends SceneTree
var folder := ""
func _initialize() -> void:
	folder = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(folder)
	var scene: Control = load("res://run.tscn").instantiate()
	scene.save_path = folder.path_join("scratch_save.json")
	scene.settings_path = folder.path_join("scratch_settings.json")
	var settings := Settings.new()
	settings.update_check_enabled = false
	settings.save(scene.settings_path)
	root.add_child(scene)
	await shot("menu.png")
	scene._start_run(&"medium")
	await shot("story.png")
	scene._run.stop_index = 1
	scene._show_stop()
	await shot("battle.png")
	scene._run.complete_combat(true)
	scene._show_stop()
	await shot("reward.png")
	scene._set_paused(true)
	await shot("pause.png")
	scene._set_paused(false)
	DirAccess.remove_absolute(scene.save_path)
	DirAccess.remove_absolute(scene.settings_path)
	quit()

func shot(name: String) -> void:
	for i in 5:
		await process_frame
	var result := root.get_texture().get_image().save_png(folder.path_join(name))
	assert(result == OK)
