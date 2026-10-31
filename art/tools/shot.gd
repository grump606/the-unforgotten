extends SceneTree
## Saves a screenshot of the preview scene (needs a window, not --headless):
##   godot --path . -s res://art/tools/shot.gd -- <out.png>

func _initialize() -> void:
	var out := "user://art_preview.png"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	var scene: Node = load("res://art/preview.tscn").instantiate()
	root.add_child(scene)
	await create_timer(0.6).timeout
	root.get_texture().get_image().save_png(out)
	quit()
