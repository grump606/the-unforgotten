extends SceneTree
func _initialize() -> void:
	var scene: Node = load("res://art/preview.tscn").instantiate()
	root.add_child(scene)
	await create_timer(0.3).timeout
	Input.warp_mouse(Vector2(1030, 80))
	var ev := InputEventMouseMotion.new()
	ev.position = Vector2(1030, 80)
	ev.global_position = ev.position
	Input.parse_input_event(ev)
	await create_timer(0.8).timeout
	root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	quit()
