extends SceneTree
## Saves a screenshot of a hovered, tilted card (needs a window, not --headless):
##   godot --path . -s res://art/tools/shot_card_tilt.gd -- <out.png>

func _initialize() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.07, 0.08)
	bg.size = Vector2(1152, 648)
	root.add_child(bg)
	var views: Array[CardView] = []
	for i in 3:
		var v := CardView.new()
		v.card = load("res://data/cards/%s.tres" % ["bash", "seance", "lift"][i])
		v.class_id = [&"deserter", &"medium", &"pickpocket"][i]
		v.view_scale = 2.0
		v.auto_hover = true
		v.position = Vector2(80 + i * 360, 60)
		root.add_child(v)
		views.append(v)
	await create_timer(0.3).timeout
	var target := views[1]
	var p := target.global_position + Vector2(target.size.x * 0.85, target.size.y * 0.2)
	Input.warp_mouse(p)
	var ev := InputEventMouseMotion.new()
	ev.position = p
	ev.global_position = p
	Input.parse_input_event(ev)
	target.set_hovered(true)
	await create_timer(0.8).timeout
	root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	quit()
