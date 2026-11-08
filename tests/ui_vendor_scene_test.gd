extends SceneTree
## Headless test for VendorScene and its place in the vendor stop: it builds and draws, the
## animation is deterministic and only runs while visible, it ignores the mouse, the till follows
## the gold, and a real run's vendor stop has one stall beneath the offers, which stay clickable.
## Run via scripts/check.ps1.

const TestBase := preload("res://tests/test_base.gd")

var fails := 0
var test_save := "user://ui_vendor_scene_test_save_%d.json" % OS.get_process_id()

func check(c: bool, msg: String) -> void:
	if not c:
		fails += 1
		printerr("FAIL: " + msg)
	else:
		print("ok: " + msg)


func _initialize() -> void:
	var holder := Control.new()
	holder.size = Vector2(1120, 590)
	root.add_child(holder)

	# It builds and draws, without any panel to line up with.
	var a := VendorScene.new()
	a.size = holder.size
	holder.add_child(a)
	a.set_gold(40)
	a.advance(0.7)
	await process_frame
	await process_frame
	check(a.time > 0.0, "the stall builds and draws on its own")

	# Animation: advance moves it, identical steps agree, hidden or detached does not move.
	var b := VendorScene.new()
	b.size = holder.size
	holder.add_child(b)
	b.set_gold(40)
	var t0 := b.time
	var level0 := b.lantern_level(0)
	var breath0 := b.breath()
	b.advance(0.4)
	check(b.time > t0 and b.lantern_level(0) != level0 and b.breath() != breath0, "advance changes the animation state")
	var c := VendorScene.new()
	holder.add_child(c)
	c.advance(0.4)
	c.advance(0.0)
	check(c.time == b.time and c.breath() == b.breath() and c.lantern_level(2) == b.lantern_level(2), "the same steps give the same animation")
	var in_range := true
	var blinked := false
	for i in 80:
		b.advance(0.13)
		in_range = in_range and b.lantern_level(1) >= 0.72 and b.lantern_level(1) <= 1.0
		blinked = blinked or b.blinking()
	check(in_range, "lantern level stays in range")
	check(blinked, "the shopkeeper blinks now and then")
	var twin := VendorScene.new()
	holder.add_child(twin)
	check(twin._motes == b._motes and twin._noise == b._noise and twin._pieces == b._pieces, "the fixed seed gives the same layout every time")
	b.visible = false
	var frozen := b.time
	b.advance(1.0)
	check(b.time == frozen and not b.is_processing(), "a hidden stall does not advance or process")
	b.visible = true
	check(b.is_processing(), "showing it again resumes processing")
	var detached := VendorScene.new()
	detached.advance(1.0)
	check(detached.time == 0.0, "a stall outside the tree does not advance")
	check(a.mouse_filter == Control.MOUSE_FILTER_IGNORE, "the stall ignores the mouse")

	# The till follows the gold, and glows briefly when it changes.
	var till := VendorScene.new()
	holder.add_child(till)
	till.set_gold(0)
	check(till.till_text() == "0" and till.coin_count() == 0 and till.pulse() == 0.0, "an empty till shows 0, no coins and no glow")
	till.set_gold(37)
	check(till.till_text() == "37" and till.coin_count() == 8, "the till shows the gold and stacks coins")
	check(till.pulse() == 1.0, "the till glows when the gold changes")
	till.advance(VendorScene.PULSE_SECONDS + 0.1)
	check(till.pulse() == 0.0, "the glow fades")
	till.set_gold(5000)
	check(till.till_text() == "5000" and till.coin_count() == VendorScene.MAX_COINS, "the coin stack is capped")

	# In a real run: one stall beneath the offers, which can still be clicked.
	RunSave.delete(test_save)
	var scene: Control = load("res://run.tscn").instantiate()
	scene.save_path = test_save
	root.add_child(scene)
	await process_frame
	scene._start_run(&"deserter")
	var run_state: RunState = scene._run
	for i in run_state.stops.size():
		if run_state.stops[i].type == RunState.StopType.VENDOR:
			run_state.stop_index = i
			break
	run_state.gold = 60
	scene._show_stop()
	for i in 3:
		await process_frame
	var body: Control = scene.get_node("%Body")
	var stalls: Array[Node] = scene.find_children("*", "VendorScene", true, false)
	check(stalls.size() == 1, "the vendor stop has exactly one stall")
	var stall: VendorScene = stalls[0]
	var views := CardView.find_all(body)
	check(stall.get_parent() == body and stall.get_index() == 0, "the stall is the lowest child of the body")
	check(views.size() == run_state.vendor().offers().size() and views.size() > 0, "the offers are shown")
	var above := true
	for view in views:
		var top: Node = view
		while top.get_parent() != body:
			top = top.get_parent()
		above = above and top.get_index() > stall.get_index()
	check(above, "the offers are drawn above the stall")
	check(stall.mouse_filter == Control.MOUSE_FILTER_IGNORE, "the vendor stall ignores the mouse")
	check(stall.till_text() == "60" and stall.time > 0.0, "the stall shows the run's gold and animates")
	check(stall.head_anchor != null and stall.counter_anchor != null and stall.service_anchors.size() == 3, "the stall lines up with the panel")
	var clickable := 0
	for view in views:
		if view.is_clickable():
			clickable += 1
	check(clickable > 0, "an affordable offer is still clickable")
	var deck_before := run_state.deck.size()
	for view in views:
		if view.is_clickable():
			view.pressed.emit()
			break
	await process_frame
	check(run_state.deck.size() == deck_before + 1 and run_state.gold < 60, "clicking an offer buys it")
	var rebuilt: Array[Node] = scene.find_children("*", "VendorScene", true, false)
	check(rebuilt.size() == 1 and (rebuilt[0] as VendorScene).till_text() == str(run_state.gold), "the stall is rebuilt with the new gold")
	scene._start_removing()
	await process_frame
	var picker: Array[Node] = scene.find_children("*", "VendorScene", true, false)
	check(picker.size() == 1 and (picker[0] as VendorScene).dimmed and CardView.find_all(body).size() == run_state.deck.size(), "the remove picker shows the deck over a dimmed stall")
	scene._cancel_removing()
	scene._leave_vendor()
	await process_frame
	check(scene.find_children("*", "VendorScene", true, false).is_empty(), "leaving the vendor removes the stall")
	scene.queue_free()
	RunSave.delete(test_save)
	print("DONE fails=", fails)
	TestBase.remove_scratch(test_save)
	quit(1 if fails > 0 else 0)
