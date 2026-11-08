extends SceneTree
## Headless UI test for the tutorial overlay: every page builds, Back / Next / Skip behave, Done and Skip fire
## `closed` once, and the main menu's How to Play button opens it and records it as seen.
## Run via scripts/check.ps1.

var fails := 0
var _closed := 0
var settings_path := "user://ui_tutorial_test_settings_%d.json" % OS.get_process_id()


func check(c: bool, msg: String) -> void:
	if not c:
		fails += 1
		printerr("FAIL: " + msg)
	else:
		print("ok: " + msg)


func _find_button(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text == text and (node as Button).is_visible_in_tree():
		return node
	for child in node.get_children():
		var found := _find_button(child, text)
		if found != null:
			return found
	return null


func _initialize() -> void:
	var overlay := TutorialOverlay.new()
	overlay.closed.connect(func() -> void: _closed += 1)
	root.add_child(overlay)
	await process_frame
	await process_frame
	var pages := TutorialContent.page_count()
	check(overlay.page == 0 and overlay.title_label.text == "Welcome", "it opens on the first page")
	check(overlay.back_button.disabled and overlay.skip_button.visible and overlay.next_button.text == "Next", "page 1: Back off, Skip and Next shown")
	for i in pages:
		overlay.show_page(i)
		await process_frame
		check(overlay.counter_label.text == "%d / %d" % [i + 1, pages] and overlay.title_label.text != "", "page %d builds and is counted" % (i + 1))
	check(overlay.next_button.text == "Done" and not overlay.skip_button.visible and not overlay.back_button.disabled, "the last page offers Done and no Skip")
	overlay.show_page(1)
	await process_frame
	var pictures := overlay.find_children("*", "TextureRect", true, false)
	check(pictures.size() >= 1 and (pictures[0] as TextureRect).texture != null, "the fight screen picture loads")
	overlay.show_page(2)
	await process_frame
	check(CardView.find_all(overlay).size() == 1, "the card page shows one card")
	overlay.show_page(0)
	overlay.next()
	check(overlay.page == 1, "Next goes forward")
	overlay.back()
	check(overlay.page == 0, "Back goes back")
	overlay.back()
	check(overlay.page == 0, "Back on page 1 stays put")
	overlay.skip_button.pressed.emit()
	check(_closed == 1, "Skip closes it")
	overlay.finish()
	check(_closed == 1, "closing twice fires once")
	overlay.queue_free()

	# Finishing on the last page.
	var again := TutorialOverlay.new()
	again.closed.connect(func() -> void: _closed += 1)
	root.add_child(again)
	await process_frame
	again.show_page(pages - 1)
	again.next()
	check(_closed == 2, "Done on the last page closes it")
	again.queue_free()

	# The main menu: How to Play opens the tutorial, and closing it records it as seen.
	var scene: Control = load("res://run.tscn").instantiate()
	scene.settings_path = settings_path
	scene.save_path = "user://ui_tutorial_test_save_%d.json" % OS.get_process_id()
	root.add_child(scene)
	for i in 3:
		await process_frame
	check(scene._tutorial == null, "headless launches do not show the tutorial by themselves")
	var button := _find_button(scene, "How to Play")
	check(button != null, "the main menu has a How to Play button")
	if button != null:
		button.pressed.emit()
		await process_frame
		check(scene._tutorial != null and scene._tutorial.get_parent() == scene, "How to Play opens the tutorial over the menu")
		check(not Settings.load_file(settings_path).tutorial_seen, "it is not marked seen until it is closed")
		scene._tutorial.finish()
		await process_frame
		check(scene._tutorial == null and Settings.load_file(settings_path).tutorial_seen, "closing it records it as seen")
	scene.queue_free()
	for p in [settings_path, settings_path + ".bak", settings_path + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	print("DONE fails=", fails)
	quit(1 if fails > 0 else 0)
