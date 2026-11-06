extends SceneTree
## Screenshots the route map screen: act 1 at the first choice, mid-run with a visited path, at the forced rest row before
## the boss, act 2 (also at its forced rest row), for two characters, and a map with elites. Needs a rendering window (not --headless):
##   godot --path . -s res://tools/map_sheet.gd -- <output dir>
## Default output is user://map_sheets. The shots use the project's 1152x648 window.

var out_dir := "user://map_sheets"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED # the view scales itself from the real window size
	DirAccess.make_dir_recursive_absolute(out_dir)
	for i in 8: # let the window settle at its final size before the first capture
		await process_frame
	for id in [&"deserter", &"medium"]:
		var route := RouteMap.generate(7, id)
		await _shot(route, id, 0, "act1_start_%s" % id)
		await _shot(route, id, 6, "act1_mid_%s" % id, true)
		await _shot(route, id, 12, "act1_forced_rest_%s" % id)
		await _shot(route, id, 15 + 12, "act2_forced_rest_%s" % id)
		await _shot(route, id, 15 + 5, "act2_%s" % id, true)
	var elites := RouteMap.generate(11, &"thief", {"type_weights": {"elite": 14.0}})
	await _shot(elites, &"thief", 5, "act1_elites_thief", true)
	await _shot(elites, &"thief", 15 + 10, "act2_elites_thief")
	quit()


## Walks `steps` rows along a fixed path, then draws the map there. With `hover`, shows the hover label of the
## last reachable choice.
func _shot(route: RouteMap, id: StringName, steps: int, file: String, hover := false) -> void:
	var visited: Array[int] = []
	var current := -1
	var reachable: Array[int] = route.starts()
	for i in steps:
		var pick := reachable[(i * 2 + 1) % reachable.size()]
		visited.append(pick)
		current = pick
		reachable = route.next_ids(pick)
	var view := MapView.new()
	view.size = root.size
	root.add_child(view)
	view.set_status("%s  ·  HP 31/42  ·  Gold 87  ·  Deck 14" % String(id).capitalize())
	view.set_data(route, visited, current, reachable, id)
	view.time = 0.9
	view.set_process(false)
	if hover and not reachable.is_empty():
		view.set_hover(reachable[reachable.size() - 1])
	for i in 3:
		await process_frame
	var path := out_dir.path_join(file + ".png")
	root.get_texture().get_image().save_png(path)
	print("saved ", path)
	view.queue_free()
	await process_frame
