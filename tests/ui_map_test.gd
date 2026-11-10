extends SceneTree
## Headless UI test for the map screen: MapView builds for generated maps of every character, the
## act's nodes and states, clicks and keys choose only reachable nodes, tooltips, act 2, elites, the line
## map and empty or odd routes, and MapScreen builds the view into a container and re-emits the pick.
## Run via scripts/check.ps1.

var fails := 0
var chosen: Array[int] = []


func check(c: bool, msg: String) -> void:
	if not c:
		fails += 1
		printerr("FAIL: " + msg)
	else:
		print("ok: " + msg)


func _on_chosen(id: int) -> void:
	chosen.append(id)


func _view(route: RouteMap, visited: Array[int], current: int, reachable: Array[int], character: StringName) -> MapView:
	var view := MapView.new()
	view.size = Vector2(1152, 648)
	view.node_chosen.connect(_on_chosen)
	root.add_child(view)
	view.set_data(route, visited, current, reachable, character)
	return view


func _click(view: MapView, at: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = at
	view._gui_input(event)


func _key(view: MapView, action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	view._gui_input(event)


## Walks `steps` rows along the first edges, returning {visited, current, reachable}.
func _walk(route: RouteMap, steps: int) -> Dictionary:
	var visited: Array[int] = []
	var current := -1
	var reachable: Array[int] = route.starts()
	for i in steps:
		current = reachable[i % reachable.size()]
		visited.append(current)
		reachable = route.next_ids(current)
	return {"visited": visited, "current": current, "reachable": reachable}


func _initialize() -> void:
	for id in [&"deserter", &"thief", &"medium", &"stray"]:
		var made := RouteMap.generate(5, id)
		var start := made.starts()
		var first_view := _view(made, [] as Array[int], -1, start, id)
		await process_frame
		check(first_view.shown_act() == 0 and first_view.shown_ids().size() > 15, "%s: act 1 builds with %d nodes" % [id, first_view.shown_ids().size()])
		check(first_view.progress_text() == "Row 1/15", "%s: first choice reads Row 1/15" % id)
		var wrong := 0
		var empty := 0
		for node_id in first_view.shown_ids():
			var want := &"reachable" if start.has(node_id) else &"future"
			if first_view.state_of(node_id) != want:
				wrong += 1
			if first_view.tooltip_for(node_id) == "":
				empty += 1
		check(wrong == 0, "%s: only the first row is reachable" % id)
		check(empty == 0, "%s: every node has a tooltip" % id)
		first_view.queue_free()

	# rest nodes (the armchair) and the legend draw
	var rest_view := _view(RouteMap.generate(5, &"deserter"), [] as Array[int], -1, RouteMap.generate(5, &"deserter").starts(), &"deserter")
	await process_frame
	rest_view.queue_redraw()
	await process_frame
	var rest_count := 0
	for node_id in rest_view.shown_ids():
		if RouteMap.generate(5, &"deserter").node(node_id).type == RouteMap.NodeType.REST:
			rest_count += 1
	check(rest_count > 0 and rest_view.shown_ids().size() > 15, "rest nodes and the legend build and draw")
	rest_view.queue_free()

	var route := RouteMap.generate(5, &"deserter")
	var walked := _walk(route, 4)
	var visited: Array[int] = walked.visited
	var current: int = walked.current
	var reachable: Array[int] = walked.reachable
	var view := _view(route, visited, current, reachable, &"deserter")
	await process_frame
	check(view.state_of(current) == &"current", "the current node is marked current")
	check(view.state_of(visited[0]) == &"visited", "an earlier node is visited")
	check(view.progress_text() == "Row 5/15", "after four picks the next choice is Row 5/15")
	check(reachable.has(view.selected_node()), "a reachable node starts selected")

	# Clicks: a reachable node chooses, an unreachable or visited one does not.
	chosen.clear()
	var other := -1
	for id in view.shown_ids():
		if view.state_of(id) == &"future":
			other = id
			break
	_click(view, view.node_position(other))
	_click(view, view.node_position(visited[0]))
	_click(view, view.node_position(current))
	_click(view, Vector2(5, 300))
	check(chosen.is_empty(), "unreachable, visited, current and empty clicks choose nothing")
	for id in reachable:
		_click(view, view.node_position(id))
	check(chosen == reachable, "clicking each reachable node emits it (%s)" % str(chosen))
	check(view.node_at(view.node_position(reachable[0])) == reachable[0], "node_at finds a node at its position")
	check(not view.choose(other) and view.choose(reachable[0]), "choose() only accepts reachable ids")

	# Keyboard: arrows cycle the reachable choices, accept chooses the selected one.
	chosen.clear()
	var first := view.selected_node()
	_key(view, &"ui_right")
	var second := view.selected_node()
	check(reachable.has(second) and (reachable.size() < 2 or first != second), "ui_right moves the selection among reachable nodes")
	_key(view, &"ui_left")
	check(view.selected_node() == first, "ui_left moves back")
	_key(view, &"ui_accept")
	check(chosen == ([first] as Array[int]), "ui_accept chooses the selected node")

	# Tooltip wording.
	var seen := {}
	for id in view.shown_ids():
		var n := route.node(id)
		var tip := view.tooltip_for(id)
		match n.type:
			RouteMap.NodeType.FIGHT:
				seen["fight"] = tip == "Fight: %d %s" % [n.enemy_count, "enemy" if n.enemy_count == 1 else "enemies"]
			RouteMap.NodeType.REST:
				seen["rest"] = tip == "Rest"
			RouteMap.NodeType.SHOP:
				seen["shop"] = tip == "Shop"
			RouteMap.NodeType.STORY:
				seen["story"] = tip.begins_with("Story")
			RouteMap.NodeType.MID_BOSS:
				seen["mid"] = tip == "Mid-boss"
	check(seen.get("fight", false) and seen.get("rest", false) and seen.get("shop", false), "fight, rest and shop tooltips")
	check(seen.get("story", false) and seen.get("mid", false), "story and mid-boss tooltips")
	view.queue_free()

	# Nothing reachable: no keyboard action, no click.
	chosen.clear()
	var idle := _view(route, visited, current, [] as Array[int], &"deserter")
	_key(idle, &"ui_accept")
	_click(idle, idle.node_position(current))
	check(chosen.is_empty() and idle.selected_node() == -1, "with nothing reachable nothing can be chosen")
	idle.queue_free()

	# Act 2 and the end of act 1.
	var act2 := _walk(route, 17)
	var view2 := _view(route, act2.visited, act2.current, act2.reachable, &"medium")
	await process_frame
	check(view2.shown_act() == 1 and view2.progress_text() == "Row 3/15", "act 2 is shown with its own row count (%s)" % view2.progress_text())
	view2.queue_free()
	var act1_end := _walk(route, 14)
	var view3 := _view(route, act1_end.visited, act1_end.current, act1_end.reachable, &"medium")
	check(view3.shown_act() == 0 and view3.progress_text() == "Row 15/15", "the mid-boss choice is Row 15/15 of act 1")
	view3.queue_free()
	var over := _walk(route, 15)
	var view4 := _view(route, over.visited, over.current, over.reachable, &"medium")
	check(view4.shown_act() == 1 and view4.progress_text() == "Row 1/15", "after the mid-boss the choice is act 2, Row 1/15")
	view4.queue_free()

	# Elites.
	var elites := RouteMap.generate(11, &"thief", {"type_weights": {"elite": 14.0}})
	check(elites.count_of(RouteMap.NodeType.ELITE) > 0, "the elite config yields elite nodes")
	var elite_view := _view(elites, [] as Array[int], -1, elites.starts(), &"thief")
	await process_frame
	var tips := 0
	for id in elite_view.shown_ids():
		if elites.node(id).type == RouteMap.NodeType.ELITE and elite_view.tooltip_for(id).begins_with("Elite fight"):
			tips += 1
	check(tips > 0, "elite nodes get an elite tooltip")
	elite_view.queue_free()

	# The legacy line and odd routes.
	var line := RouteMap.from_line(RunState.new(1, &"deserter").stops)
	var line_view := _view(line, [] as Array[int], -1, line.starts(), &"deserter")
	await process_frame
	check(line_view.shown_ids().size() > 0 and line_view.state_of(0) == &"reachable", "the line map builds")
	line_view.queue_free()
	var empty_view := _view(RouteMap.new(), [] as Array[int], -1, [] as Array[int], &"")
	var null_view := _view(null, [] as Array[int], -1, [] as Array[int], &"")
	var junk_view := _view(route, [999, -4] as Array[int], 777, [500] as Array[int], &"nobody")
	await process_frame
	check(empty_view.shown_ids().is_empty() and null_view.shown_ids().is_empty(), "empty and null routes build without errors")
	chosen.clear()
	_click(junk_view, Vector2(100, 100))
	_key(junk_view, &"ui_accept")
	check(chosen.is_empty() and is_instance_valid(junk_view), "junk data survives input and chooses nothing")
	for v in [empty_view, null_view, junk_view]:
		v.queue_free()

	# Other window sizes keep every node inside the view.
	for window in [Vector2(800, 450), Vector2(1920, 1080)]:
		var sized := MapView.new()
		sized.size = window
		root.add_child(sized)
		sized.set_data(route, [] as Array[int], -1, route.starts(), &"deserter")
		var inside := true
		for id in sized.shown_ids():
			inside = inside and Rect2(Vector2.ZERO, window).has_point(sized.node_position(id))
		check(inside, "all nodes lie inside a %dx%d view" % [window.x, window.y])
		sized.queue_free()

	# MapScreen builds the view into its body and re-emits the pick.
	var body := Control.new()
	body.size = Vector2(1152, 648)
	root.add_child(body)
	var screen := MapScreen.new()
	screen.attach(null, body, Callable())
	chosen.clear()
	screen.node_chosen.connect(_on_chosen)
	var mv := screen.present(route, visited, current, reachable, &"deserter", "Deserter  ·  HP 30/40")
	await process_frame
	check(mv.get_parent() == body and screen.view == mv, "the screen puts its view in the body")
	_click(mv, mv.node_position(reachable[0]))
	check(chosen == ([reachable[0]] as Array[int]), "the screen re-emits node_chosen")
	body.queue_free()

	# The real run flow: the map shows after every stop, run.gd's header is the only status line (the view
	# draws none) and its journey number counts the row being chosen, like the view's "Row n/15".
	var scene: Control = load("res://run.tscn").instantiate()
	scene.save_path = "user://ui_map_test_save_%d.json" % OS.get_process_id()
	root.add_child(scene)
	await process_frame
	scene.start_debug_map(DebugLaunch.parse(PackedStringArray(["--map"]), {}))
	var header: Label = scene.get_node("%HeaderLabel")
	var run_body: Control = scene.get_node("%Body")
	for step in 4:
		await process_frame
		var views := run_body.find_children("*", "MapView", true, false)
		check(views.size() == 1, "step %d: the run shows one map" % step)
		var run_state: RunState = scene._run
		var next_row: int = run_state.route.node(run_state.reachable_nodes()[0]).row
		check(header.text.contains("Journey %d/30" % (next_row + 1)), "step %d: the header counts the row being chosen (%s)" % [step, header.text.replace("
", " | ")])
		check(views.size() == 1 and (views[0] as MapView).progress_text() == "Row %d/15" % (next_row + 1), "step %d: the view and the header agree on the row" % step)
		scene._on_node_chosen(run_state.reachable_nodes()[0])
		check(run_body.find_children("*", "MapView", true, false).is_empty() and run_state.current_stop() != null, "step %d: choosing a node leaves the map for its stop" % step)
		if run_state.reward_pending() or run_state.current_stop().type == RunState.StopType.COMBAT:
			run_state.complete_combat(true)
			run_state.resolve_reward(null)
		elif run_state.current_stop().type == RunState.StopType.STORY:
			run_state.read_story()
		scene._show_stop()
	scene.queue_free()

	print("DONE fails=", fails)
	quit(1 if fails > 0 else 0)
