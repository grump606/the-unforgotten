extends SceneTree
## Headless test that the tutorial overlay's keyboard trap is robust: a control added behind it while it is open
## cannot take focus, a control whose focus mode is set back while it is open loses focus again, a mode changed by
## someone else is not overwritten on close, and the original modes come back. Run via scripts/check.ps1.

var fails := 0


func check(c: bool, msg: String) -> void:
	if not c:
		fails += 1
		printerr("FAIL: " + msg)
	else:
		print("ok: " + msg)


func _tab() -> void:
	var e := InputEventKey.new()
	e.keycode = KEY_TAB
	e.physical_keycode = KEY_TAB
	e.pressed = true
	root.push_input(e)


func _button(parent: Node, mode: Control.FocusMode) -> Button:
	var b := Button.new()
	b.focus_mode = mode
	parent.add_child(b)
	return b


func _initialize() -> void:
	Motion.reduced = false
	var holder := VBoxContainer.new()
	root.add_child(holder)
	var plain := _button(holder, Control.FOCUS_ALL)
	var clicky := _button(holder, Control.FOCUS_CLICK)
	var none := _button(holder, Control.FOCUS_NONE)
	var changing := _button(holder, Control.FOCUS_ALL)
	await process_frame
	var overlay := TutorialOverlay.new()
	holder.add_child(overlay)
	await process_frame
	check(plain.focus_mode == Control.FOCUS_NONE and clicky.focus_mode == Control.FOCUS_NONE, "controls behind the overlay cannot take focus")
	check(none.focus_mode == Control.FOCUS_NONE, "a control that never took focus stays as it was")

	# Added after the trap: covered too.
	var late := _button(holder, Control.FOCUS_ALL)
	var late_nested := HBoxContainer.new()
	holder.add_child(late_nested)
	var late_child := _button(late_nested, Control.FOCUS_ALL)
	check(late.focus_mode == Control.FOCUS_NONE and late_child.focus_mode == Control.FOCUS_NONE, "controls added behind the overlay while it is open cannot take focus")

	# Set back while open: focus cannot stay there.
	changing.focus_mode = Control.FOCUS_ALL
	changing.grab_focus()
	await process_frame
	check(root.gui_get_focus_owner() != changing and overlay.is_ancestor_of(root.gui_get_focus_owner()), "a control whose mode was set back while open loses focus to the overlay")
	for i in 6:
		_tab()
		await process_frame
		var owner := root.gui_get_focus_owner()
		check(owner == null or overlay.is_ancestor_of(owner), "Tab %d stays inside the overlay" % (i + 1))

	# A mode changed by someone else is kept on close; the rest come back.
	clicky.focus_mode = Control.FOCUS_ALL
	changing.focus_mode = Control.FOCUS_CLICK
	overlay.finish()
	holder.remove_child(overlay)
	overlay.free()
	await process_frame
	check(plain.focus_mode == Control.FOCUS_ALL, "an untouched control gets its mode back")
	check(clicky.focus_mode == Control.FOCUS_ALL, "a mode set to ALL while open is not overwritten with the stale one")
	check(changing.focus_mode == Control.FOCUS_CLICK, "a mode changed to CLICK while open is not overwritten with the stale one")
	check(late.focus_mode == Control.FOCUS_ALL and late_child.focus_mode == Control.FOCUS_ALL, "controls added while open get their mode back")
	check(none.focus_mode == Control.FOCUS_NONE, "a control that was NONE stays NONE")
	plain.grab_focus()
	check(root.gui_get_focus_owner() == plain, "controls can take focus again after the overlay closes")
	quit(1 if fails > 0 else 0)
