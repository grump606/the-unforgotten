extends SceneTree
## Headless UI test for the Remember preview: picking a card to Remember (at a rest and in an event) first shows the card
## as it is now beside the card it becomes, and nothing changes until "Remember it" is pressed; "Choose another card"
## goes back to the picker. Scratch save paths only. Run via scripts/check.ps1.

var fails := 0
var save_path := "user://ui_remember_preview_%d.json" % OS.get_process_id()
var settings_path := "user://ui_remember_preview_settings_%d.json" % OS.get_process_id()


func check(c: bool, msg: String) -> void:
	if not c:
		fails += 1
		printerr("FAIL: " + msg)
	else:
		print("ok: " + msg)


func _find(node: Node, node_name: String) -> Node:
	if node.name == node_name:
		return node
	for child in node.get_children():
		var found := _find(child, node_name)
		if found != null:
			return found
	return null


func _button_with(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text.contains(text):
		return node as Button
	for child in node.get_children():
		var found := _button_with(child, text)
		if found != null:
			return found
	return null


func _remembered_count(run_state: RunState) -> int:
	var n := 0
	for card in run_state.deck:
		n += 1 if card.is_remembered else 0
	return n


func _open(scene: Control, spec: String) -> RunState:
	scene.start_debug_screen(DebugLaunch.parse(PackedStringArray(["--screen=" + spec, "--character=deserter"]), {}))
	await process_frame
	await process_frame
	return scene._run


## Picks the first card of the open picker, checks the preview, goes back, picks again and confirms.
func _flow(scene: Control, run_state: RunState, label: String) -> void:
	var body: Control = scene.get_node("%Body")
	var picker_cards := CardView.find_all(body)
	check(picker_cards.size() > 0 and _find(body, "RememberPreview") == null, "%s: the picker lists cards and no preview is showing" % label)
	var before := _remembered_count(run_state)
	var hp := run_state.player.hp
	picker_cards[0].pressed.emit()
	await process_frame
	body = scene.get_node("%Body")
	var preview := _find(body, "RememberPreview")
	check(preview != null and _find(body, "ConfirmRememberButton") != null, "%s: picking a card opens the preview with a confirm button" % label)
	var now_views := CardView.find_all(_find(body, "PreviewNow"))
	var after_views := CardView.find_all(_find(body, "PreviewRemembered"))
	check(now_views.size() == 1 and after_views.size() == 1, "%s: the preview shows the card now and the card it becomes" % label)
	if now_views.size() == 1 and after_views.size() == 1:
		var current: CardData = now_views[0].card
		var upgraded: CardData = after_views[0].card
		check(not current.is_remembered and upgraded.is_remembered and upgraded.base() == current, "%s: the second card is the first one Remembered" % label)
		check(run_state.deck.has(current), "%s: the first card is the one in the deck" % label)
	check(_remembered_count(run_state) == before and run_state.player.hp == hp, "%s: nothing has changed before the confirmation" % label)
	# Back to the picker: still nothing changed.
	(_find(body, "BackRememberButton") as Button).pressed.emit()
	await process_frame
	body = scene.get_node("%Body")
	check(_find(body, "RememberPreview") == null and CardView.find_all(body).size() > 0, "%s: Choose another card returns to the picker" % label)
	check(_remembered_count(run_state) == before, "%s: going back changed nothing" % label)
	# Pick again and confirm.
	CardView.find_all(body)[0].pressed.emit()
	await process_frame
	body = scene.get_node("%Body")
	(_find(body, "ConfirmRememberButton") as Button).pressed.emit()
	await process_frame
	await process_frame
	check(_remembered_count(run_state) == before + 1, "%s: Remember it Remembers the card" % label)


func _initialize() -> void:
	RunSave.delete(save_path)
	await process_frame
	var scene: Control = load("res://run.tscn").instantiate()
	scene.save_path = save_path
	scene.settings_path = settings_path
	root.add_child(scene)
	await process_frame

	# --- At a rest ---
	var run_state := await _open(scene, "rest")
	var body: Control = scene.get_node("%Body")
	var hp := run_state.player.hp
	var button := _find(body, "RememberButton") as Button
	check(button != null and not button.disabled, "rest: the Remember button is available")
	button.pressed.emit()
	await process_frame
	await _flow(scene, run_state, "rest")
	check(run_state.player.hp == hp, "rest: Remembering does not heal")

	# --- In an event (the Deserter's "Report in" at the sentry box) ---
	run_state = await _open(scene, "event:empty_sentry_box")
	body = scene.get_node("%Body")
	var report := _button_with(body, "Report in")
	check(report != null and not report.disabled, "event: the Deserter has a Remember button")
	if report != null and not report.disabled:
		report.pressed.emit()
		await process_frame
		await _flow(scene, run_state, "event")

	print("ui remember preview test: %d failure(s)" % fails)
	RunSave.delete(save_path)
	DirAccess.remove_absolute(settings_path)
	quit(1 if fails > 0 else 0)
