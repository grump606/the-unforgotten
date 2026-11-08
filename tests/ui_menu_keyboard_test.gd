extends SceneTree
## Headless UI test for keyboard handling on the menus: the tutorial overlay is modal for the keyboard (Enter on a
## focused button presses that button, the menu behind cannot take focus, focus returns to the primary button on
## close), the pause menu pages focus their first control, and Reduce motion is saved and honoured.
## Run via scripts/check.ps1.

var fails := 0
var settings_path := "user://ui_menu_keyboard_test_settings_%d.json" % OS.get_process_id()


func check(c: bool, msg: String) -> void:
	if not c:
		fails += 1
		printerr("FAIL: " + msg)
	else:
		print("ok: " + msg)


func _enter() -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = KEY_ENTER
	ev.physical_keycode = KEY_ENTER
	ev.pressed = true
	return ev


func _initialize() -> void:
	Motion.reduced = false
	var scene: Control = load("res://run.tscn").instantiate()
	scene.settings_path = settings_path
	scene.save_path = "user://ui_menu_keyboard_test_save_%d.json" % OS.get_process_id()
	root.add_child(scene)
	for i in 3:
		await process_frame
	var primary: Button = scene._main_menu.new_run_button
	check(primary.focus_mode != Control.FOCUS_NONE and primary.has_focus(), "the menu starts with New Journey focused")
	scene._open_tutorial()
	await process_frame
	var overlay: TutorialOverlay = scene._tutorial
	check(not primary.has_focus() and primary.focus_mode == Control.FOCUS_NONE, "the menu behind the tutorial cannot take focus")
	check(overlay.next_button.has_focus(), "the tutorial focuses Next")
	# A focused button answers Enter itself (the overlay leaves the key alone); with none focused Enter means Next.
	overlay.back_button.grab_focus()
	overlay.show_page(1)
	overlay._input(_enter())
	check(overlay.page == 1 and not root.is_input_handled(), "Enter on a focused button is left to that button")
	overlay.next_button.release_focus()
	overlay.back_button.release_focus()
	overlay._input(_enter())
	check(overlay.page == 2, "Enter with no button focused still means Next")
	overlay.next_button.grab_focus()
	var focus_owner := root.gui_get_focus_owner()
	check(focus_owner == null or overlay.is_ancestor_of(focus_owner), "focus stays inside the tutorial")
	overlay.finish()
	await process_frame
	check(scene._tutorial == null and primary.focus_mode != Control.FOCUS_NONE and primary.has_focus(), "closing it gives focus back to the menu's main button")

	# The pause menu pages put focus on their first control.
	var pause: PauseMenu = scene._pause
	pause.set_paused(true)
	await process_frame
	var focused := root.gui_get_focus_owner()
	check(focused is Button and (focused as Button).text == "Continue", "the pause menu focuses Continue")
	pause._show_sound()
	await process_frame
	check(root.gui_get_focus_owner() is HSlider, "the pause sound page focuses its first slider")
	pause._confirm_new_run()
	await process_frame
	focused = root.gui_get_focus_owner()
	check(focused is Button and (focused as Button).text == "Cancel", "the new-journey confirmation focuses Cancel")
	pause.set_paused(false)

	# Reduce motion: persisted only when on, and the animated scenes hold still.
	check(not Settings.load_file(settings_path).reduced_motion, "reduce motion defaults to off")
	var pause_scene := PauseScene.new()
	root.add_child(pause_scene)
	await process_frame
	var before: float = pause_scene.time
	pause_scene.advance(0.5)
	check(pause_scene.time > before, "the pause scene animates normally")
	check(Motion.set_and_save(true, settings_path) == "" and Settings.load_file(settings_path).reduced_motion, "Reduce motion is saved")
	before = pause_scene.time
	pause_scene.advance(0.5)
	check(pause_scene.time == before, "the pause scene holds still under reduced motion")
	var menu_scene := MenuScene.new()
	root.add_child(menu_scene)
	menu_scene.advance(1.0)
	check(menu_scene.time == 0.0, "the menu scene holds still under reduced motion")
	var backdrop := BattleBackdrop.new()
	root.add_child(backdrop)
	backdrop.advance(1.0)
	check(backdrop.time == 0.0, "the battle backdrop holds still under reduced motion")
	Motion.reduced = false
	Motion.load_from(settings_path)
	check(Motion.reduced, "the saved preference is loaded at startup")
	check(Motion.set_and_save(false, settings_path) == "" and not FileAccess.get_file_as_string(settings_path).contains("reduced_motion"), "turning it off removes the key")
	Motion.reduced = false
	scene.queue_free()
	for p in [settings_path, settings_path + ".bak", settings_path + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	print("DONE fails=", fails)
	quit(1 if fails > 0 else 0)
