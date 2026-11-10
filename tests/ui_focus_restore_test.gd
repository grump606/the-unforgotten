extends SceneTree
## Headless test that the pause menu gives keyboard focus back: after Esc and Esc (or Continue) the control that had
## focus on the reward, rest and vendor screens has it again, and when that control is gone the first focusable
## control of the screen takes it. Uses real key events through the viewport. Run via scripts/check.ps1.

var fails := 0
var test_save := "user://ui_focus_restore_test_save_%d.json" % OS.get_process_id()


func check(c: bool, msg: String) -> void:
	if not c:
		fails += 1
		printerr("FAIL: " + msg)
	else:
		print("ok: " + msg)


func _esc() -> void:
	var e := InputEventKey.new()
	e.keycode = KEY_ESCAPE
	e.physical_keycode = KEY_ESCAPE
	e.pressed = true
	root.push_input(e)


func _focusables(node: Node, out: Array[Control]) -> void:
	var control := node as Control
	if control != null and control.visible and control.focus_mode == Control.FOCUS_ALL:
		out.append(control)
	for child in node.get_children():
		_focusables(child, out)


func _go_to(scene: Control, type: int) -> void:
	var run_state: RunState = scene._run
	run_state.finished = false
	for i in run_state.stops.size():
		if run_state.stops[i].type == type:
			run_state.stop_index = i
			break
	scene._show_stop()


func _find_button(node: Node, prefix: String) -> Button:
	if node is Button and (node as Button).text.begins_with(prefix):
		return node
	for child in node.get_children():
		var found := _find_button(child, prefix)
		if found != null:
			return found
	return null


## Pauses with Esc, resumes with Esc or the Continue button, and checks where focus lands.
func _round_trip(scene: Control, label: String, use_button: bool) -> void:
	var body: Control = scene.get_node("%Body")
	var list: Array[Control] = []
	_focusables(body, list)
	check(list.size() >= 1, "%s: the screen has focusable controls" % label)
	var target: Control = list[list.size() - 1]
	target.grab_focus()
	check(root.gui_get_focus_owner() == target, "%s: a control has focus before the pause" % label)
	_esc()
	await process_frame
	check(paused and scene._pause.overlay.visible, "%s: Esc pauses" % label)
	if use_button:
		_find_button(scene._pause.box, "Continue").pressed.emit()
	else:
		_esc()
	await process_frame
	check(not paused and not scene._pause.overlay.visible, "%s: the menu closes" % label)
	check(root.gui_get_focus_owner() == target, "%s: focus is back on the control that had it" % label)


func _initialize() -> void:
	Motion.reduced = false
	RunSave.delete(test_save)
	var scene: Control = load("res://run.tscn").instantiate()
	scene.new_runs_use_map = false
	scene.save_path = test_save
	scene.settings_path = "user://ui_focus_restore_test_settings_%d.json" % OS.get_process_id()
	root.add_child(scene)
	await process_frame
	scene._start_run(&"medium")
	var run_state: RunState = scene._run

	_go_to(scene, RunState.StopType.REST)
	await process_frame
	await _round_trip(scene, "rest", false)
	await _round_trip(scene, "rest (Continue button)", true)

	_go_to(scene, RunState.StopType.VENDOR)
	await process_frame
	await _round_trip(scene, "vendor", false)

	run_state._roll_rewards()
	run_state._reward_pending = true
	scene._show_stop()
	await process_frame
	await _round_trip(scene, "reward", false)

	# The control is gone when the menu closes: the first focusable control of the screen takes focus.
	var body: Control = scene.get_node("%Body")
	var list: Array[Control] = []
	_focusables(body, list)
	list[list.size() - 1].grab_focus()
	_esc()
	await process_frame
	var stale := Button.new()
	body.add_child(stale)
	scene._pause._focus_before = stale
	body.remove_child(stale)
	stale.free()
	_esc()
	await process_frame
	var first: Array[Control] = []
	_focusables(body, first)
	check(not paused and first.size() > 0 and root.gui_get_focus_owner() == first[0], "a vanished control falls back to the screen's first focusable control")

	RunSave.delete(test_save)
	quit(1 if fails > 0 else 0)
