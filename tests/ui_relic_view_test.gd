extends SceneTree
## Headless UI test for relics: every Kind has a glyph and tooltip, RelicView draws in every palette,
## the strip hides when empty, the vendor's relic slot (offer, unaffordable, sold, none), the battle
## screen, the run header, the pause menu and Continue all show the run's relics.
## Run via scripts/check.ps1.

var fails := 0
var test_save := "user://ui_relic_view_test_save_%d.json" % OS.get_process_id()


func check(c: bool, msg: String) -> void:
	if not c:
		fails += 1
		printerr("FAIL: " + msg)
	else:
		print("ok: " + msg)


func _buttons(node: Node, out: Array[Button]) -> void:
	if node is Button and (node as Button).visible:
		out.append(node)
	for child in node.get_children():
		_buttons(child, out)


func _button(node: Node, text: String) -> Button:
	var found: Array[Button] = []
	_buttons(node, found)
	for button in found:
		if button.text == text:
			return button
	return null


func _has_text(node: Node, text: String) -> bool:
	if node is Label and (node as Label).text == text:
		return true
	for child in node.get_children():
		if _has_text(child, text):
			return true
	return false


## A fresh run screen for `character` at the first stop of `type`, holding `owned` and `gold`.
func _run_scene(character: StringName, stop_type: RunState.StopType, owned: Array[RelicData], gold: int) -> Control:
	RunSave.delete(test_save)
	var scene: Control = load("res://run.tscn").instantiate()
	scene.save_path = test_save
	root.add_child(scene)
	await process_frame
	scene._start_run(character)
	var run_state: RunState = scene._run
	for i in run_state.stops.size():
		if run_state.stops[i].type == stop_type:
			run_state.stop_index = i
			break
	run_state.relics = owned.duplicate()
	run_state.gold = gold
	scene._show_stop()
	for i in 3:
		await process_frame
	return scene


func _initialize() -> void:
	var relics := StarterContent.all_relics()
	check(relics.size() == 12, "the twelve relics load")

	# Every Kind has a glyph name; every relic has tooltip text with its name and effect.
	for kind in RelicData.Kind.values():
		check(RelicView.glyph_name(kind) != "", "kind %d has a glyph" % kind)
	check(RelicView.GLYPH_NAMES.size() == RelicData.Kind.size(), "there is exactly one glyph per kind")
	for relic in relics:
		var tip := RelicView.tooltip_for(relic)
		check(tip.contains(relic.display_name) and tip.contains(relic.description) and tip.contains("relic"), "%s has a tooltip with its name, effect and class" % relic.id)
		var view := RelicView.new()
		view.set_relic(relic)
		check(view.tooltip_text == tip and view.mouse_filter == Control.MOUSE_FILTER_PASS, "%s shows its tooltip on hover and does not block clicks" % relic.id)
	check(RelicView.tooltip_for(null) == "", "no relic, no tooltip")
	check(RelicView.palette_id(RelicData.make(&"x", "X", RelicData.Kind.MAX_HP, 1, 1, &"nobody")) == &"", "an unknown class falls back to the neutral palette")

	# Every kind draws in every palette without errors (the check fails on script errors in the output).
	var holder := Control.new()
	holder.size = Vector2(900, 200)
	root.add_child(holder)
	var flow := HFlowContainer.new()
	flow.size = holder.size
	holder.add_child(flow)
	for palette in CardView.PALETTES:
		for kind in RelicData.Kind.values():
			var view := RelicView.new()
			view.view_scale = 1.5
			view.set_relic(RelicData.make(&"t", "T", kind, 1, 1, palette))
			flow.add_child(view)
	var dim_view := RelicView.new()
	dim_view.dimmed = true
	dim_view.set_relic(relics[0])
	flow.add_child(dim_view)
	var empty_view := RelicView.new()
	flow.add_child(empty_view)
	await process_frame
	await process_frame
	check(RelicView.find_all(flow).size() == CardView.PALETTES.size() * RelicData.Kind.size() + 2, "every kind drew in every palette")
	check(is_equal_approx(flow.get_child(0).size.x, RelicView.BASE.x * 1.5), "the badge size follows view_scale")
	holder.queue_free()

	# The strip: hidden when empty, counts its badges, replaces them on set_relics.
	var none: Array[RelicData] = []
	var strip := RelicStrip.create(none)
	root.add_child(strip)
	check(not strip.visible and strip.count() == 0, "an empty strip is hidden")
	var two: Array[RelicData] = [relics[0], relics[3]]
	strip.set_relics(two)
	await process_frame
	check(strip.visible and strip.count() == 2 and RelicView.find_all(strip).size() == 2, "the strip shows both relics")
	check(strip.mouse_filter == Control.MOUSE_FILTER_IGNORE, "the strip itself ignores the mouse")
	strip.set_relics(none)
	await process_frame
	check(not strip.visible and RelicView.find_all(strip).is_empty(), "emptying the strip hides it again")
	strip.queue_free()

	# The vendor's relic slot.
	var scene: Control = await _run_scene(&"deserter", RunState.StopType.VENDOR, none, 200)
	var body: Control = scene.get_node("%Body")
	var run_state: RunState = scene._run
	var offer := run_state.vendor().relic_offer()
	check(not offer.is_empty() and RelicView.find_all(body).size() == 1, "the vendor panel shows one relic slot")
	var slot_relic: RelicData = offer["relic"]
	var slot_view := RelicView.find_all(body)[0]
	check(slot_view.relic == slot_relic and not slot_view.dimmed, "the slot shows the offered relic, undimmed")
	check(_has_text(body, slot_relic.display_name) and _has_text(body, slot_relic.description) and _has_text(body, "%d gold" % slot_relic.price), "the slot shows its name, effect and price")
	var buy := _button(body, "Buy relic")
	check(buy != null and not buy.disabled, "an affordable relic can be bought")
	check(CardView.find_all(body).size() == run_state.vendor().offers().size(), "the card offers are unchanged")
	check(_button(body, "Leave") != null and _button(body, "Remove a card (%d gold)" % Vendor.REMOVE_CARD_PRICE) != null, "the other vendor buttons keep their text")
	var gold_before := run_state.gold
	buy.pressed.emit()
	await process_frame
	check(run_state.relics.size() == 1 and run_state.relics[0] == slot_relic and run_state.gold == gold_before - slot_relic.price, "buying adds the relic and spends its price")
	body = scene.get_node("%Body")
	check(_has_text(body, "Sold") and _button(body, "Buy relic").disabled and RelicView.find_all(body)[0].dimmed, "a sold relic says Sold and cannot be bought again")
	check(scene._header_strip.visible and scene._header_strip.count() == 1, "the header strip shows the new relic")
	check(scene._header.text.contains("Gold %d" % run_state.gold), "the header gold is refreshed")
	scene.queue_free()
	await process_frame

	scene = await _run_scene(&"pickpocket", RunState.StopType.VENDOR, none, 0)
	body = scene.get_node("%Body")
	offer = scene._run.vendor().relic_offer()
	check(RelicView.find_all(body).size() == 1 and _button(body, "Buy relic").disabled and RelicView.find_all(body)[0].dimmed, "an unaffordable relic is dimmed with a disabled Buy button")
	check(_has_text(body, "%d gold" % offer["price"]) and not _has_text(body, "Sold"), "an unaffordable relic still shows its price")
	check(not scene._header_strip.visible, "no relics owned, no header strip")
	scene.queue_free()
	await process_frame

	var all_medium := StarterContent.relic_pool(&"medium")
	scene = await _run_scene(&"medium", RunState.StopType.VENDOR, all_medium, 200)
	body = scene.get_node("%Body")
	check(scene._run.vendor().relic_offer().is_empty(), "owning the whole pool leaves no relic offer")
	check(RelicView.find_all(body).is_empty() and _button(body, "Buy relic") == null, "no relic offer, no relic slot")
	check(CardView.find_all(body).size() == 3 and scene._header_strip.count() == all_medium.size(), "the card offers remain and the header lists every owned relic")
	# The pause menu lists them too.
	scene._set_paused(true)
	check(RelicView.find_all(scene._pause_box).size() == all_medium.size(), "the pause menu shows the relics")
	scene._set_paused(false)
	scene.queue_free()
	await process_frame

	# The battle screen shows the run's relics; the run header leaves them to it during the fight.
	var owned: Array[RelicData] = [relics[3], relics[4]]
	scene = await _run_scene(&"deserter", RunState.StopType.COMBAT, owned, 0)
	body = scene.get_node("%Body")
	var battle: Control = body.get_child(0)
	check(battle.has_method("_attach") and battle._relic_strip.visible and battle._relic_strip.count() == 2, "the battle screen shows the run's two relics")
	check(RelicView.find_all(battle).size() == 2 and battle._relic_strip.get_parent() == battle._stage, "the badges sit in the top corner of the stage")
	check(not scene._header_strip.visible, "the header strip stays hidden during a fight")
	var strip_rect: Rect2 = battle._relic_strip.get_global_rect()
	check(Rect2(Vector2.ZERO, Vector2(scene.size)).encloses(strip_rect), "the battle badges are on screen")
	scene.queue_free()
	await process_frame
	scene = await _run_scene(&"deserter", RunState.StopType.COMBAT, none, 0)
	battle = scene.get_node("%Body").get_child(0)
	check(not battle._relic_strip.visible and battle._relic_strip.count() == 0, "a battle without relics shows no strip")
	scene.queue_free()
	await process_frame
	var standalone: Control = (load("res://battle.tscn") as PackedScene).instantiate()
	root.add_child(standalone)
	await process_frame
	check(not standalone._relic_strip.visible, "the standalone battle shows no relics")
	standalone.queue_free()

	# Save, then Continue: the relics come back in the header.
	scene = await _run_scene(&"deserter", RunState.StopType.REST, owned, 20)
	check(scene._header_strip.visible and scene._header_strip.count() == 2, "a rest stop shows the header relics")
	var error := RunSave.save(scene._run, test_save)
	check(error == "", "the run with relics saves")
	scene.queue_free()
	await process_frame
	var resumed: Control = load("res://run.tscn").instantiate()
	resumed.save_path = test_save
	root.add_child(resumed)
	await process_frame
	check(not resumed._header_strip.visible, "the saved-run prompt shows no relics yet")
	_button(resumed, "Continue").pressed.emit()
	await process_frame
	check(resumed._header_strip.visible and resumed._header_strip.count() == 2 and resumed._run.relics.size() == 2, "Continue shows the saved relics")
	resumed.queue_free()
	RunSave.delete(test_save)
	print("DONE fails=", fails)
	quit(1 if fails > 0 else 0)
