extends SceneTree
## Screenshots the vendor stop: with gold to spare, poor (offers in the NEED n GOLD state), after
## buying one offer (SOLD), the remove picker, and the same stall at two moments to show motion.
## Needs a rendering window (not --headless):
##   godot --path . -s res://tools/vendor_sheet.gd -- <output dir>
## Default output is user://vendor_sheets. The shots use the project's 1152x648 window.

const VENDOR_STOP := 5

var out_dir := "user://vendor_sheets"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	var scene: Control = await _vendor_run(60)
	await _shot(scene, "vendor_rich.png", 2.0)
	await _shot(scene, "vendor_rich_later.png", 5.7)
	scene._buy_card(0)
	await _shot(scene, "vendor_sold.png", 2.0)
	scene._start_removing()
	await _shot(scene, "vendor_remove.png", 2.0)
	scene.queue_free()
	await process_frame
	scene = await _vendor_run(3)
	await _shot(scene, "vendor_poor.png", 2.0)
	DirAccess.remove_absolute(out_dir.path_join("scratch_save.json"))
	quit()


func _vendor_run(gold: int) -> Control:
	var scene: Control = load("res://run.tscn").instantiate()
	scene.save_path = out_dir.path_join("scratch_save.json") # never the real save
	root.add_child(scene)
	await process_frame
	scene._start_run(CharacterIds.DESERTER)
	scene._run.stop_index = VENDOR_STOP
	scene._run.gold = gold
	scene._run.player.hp = scene._run.player.max_hp - 10
	scene._show_stop()
	return scene


func _shot(scene: Control, file: String, seconds: float) -> void:
	for i in 4:
		await process_frame
	var stall: VendorScene = scene.find_children("*", "VendorScene", true, false)[0]
	stall.time = 0.0 # real frames have run; start every shot from the same moment
	stall.advance(seconds)
	await process_frame
	stall.time = seconds
	stall.advance(0.0)
	await process_frame
	var path := out_dir.path_join(file)
	root.get_texture().get_image().save_png(path)
	print("saved ", path)
