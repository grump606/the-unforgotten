extends SceneTree
## Screenshots the event stop through the real run scene (the engine's own viewport capture): several events as the
## player first sees them (one with a greyed button and its reason, one with four buttons and long text, a class-only
## button), an outcome card, a pick, and the same at 800x450. Needs a rendering window (not --headless):
##   godot --path . -s res://tools/event_sheet.gd -- <output dir>
## Default output is user://event_sheets.

var out_dir := "user://event_sheets"

## [launch spec, extra arguments, file name] for each first-sight shot.
const SHOTS := [
	["event:rain_barrel", ["--character=deserter"], "rain_barrel_deserter"],
	["event:name_broker", ["--character=thief", "--gold=10"], "name_broker_greyed"],
	["event:stopped_kitchen", ["--character=deserter", "--gold=12"], "stopped_kitchen_four_buttons"],
	["event:hound_at_the_fence", ["--character=stray"], "hound_stray_class_button"],
	["event:erasers_chalk", ["--character=medium"], "chalk_medium_gamble"],
	["event:bell_in_the_well", ["--character=thief"], "well_thief_odds"],
	["event:unsent_letters", ["--character=medium"], "letters_medium"],
]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	var scene: Control = load("res://run.tscn").instantiate()
	scene.save_path = "user://event_sheet_save.json"
	root.add_child(scene)
	for i in 8:
		await process_frame
	for size in [Vector2i(1152, 648), Vector2i(800, 450)]:
		DisplayServer.window_set_size(size)
		root.size = size
		for i in 4:
			await process_frame
		for shot in SHOTS:
			var launch_args := PackedStringArray(["--screen=" + String(shot[0])])
			launch_args.append_array(PackedStringArray(shot[1]))
			scene.start_debug_screen(DebugLaunch.parse(launch_args, {}))
			await _settle()
			await _shot("%s_%d" % [shot[2], size.x])
		# An outcome card, and a pick.
		scene.start_debug_screen(DebugLaunch.parse(PackedStringArray(["--screen=event:rain_barrel", "--character=stray"]), {}))
		await _settle()
		scene._run.resolve_event_choice(0)
		scene._show_stop()
		await _settle()
		await _shot("outcome_stray_%d" % size.x)
		scene.start_debug_screen(DebugLaunch.parse(PackedStringArray(["--screen=event:quiet_choir", "--character=medium"]), {}))
		await _settle()
		scene._run.resolve_event_choice(0)
		scene._show_stop()
		await _settle()
		await _shot("pick_rare_medium_%d" % size.x)
		scene.start_debug_screen(DebugLaunch.parse(PackedStringArray(["--screen=event:scraped_plaques", "--character=deserter"]), {}))
		await _settle()
		scene._run.deck.append(StarterContent.status_card(&"dread"))
		scene._run.resolve_event_choice(0)
		scene._show_stop()
		await _settle()
		await _shot("remove_with_curse_%d" % size.x)
	quit()


func _settle() -> void:
	for i in 8:
		await process_frame


func _shot(file: String) -> void:
	var path := out_dir.path_join(file + ".png")
	root.get_texture().get_image().save_png(path)
	print("saved ", path)
