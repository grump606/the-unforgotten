extends SceneTree
## Headless test that LayeredArt only processes while it is on screen and motion is allowed: hidden or under
## Reduce motion it does not tick, and it wakes again when shown or when Reduce motion is switched off.
## Run via scripts/check.ps1.

var fails := 0


func check(c: bool, msg: String) -> void:
	if not c:
		fails += 1
		printerr("FAIL: " + msg)
	else:
		print("ok: " + msg)


func _initialize() -> void:
	Motion.reduced = false
	var art := LayeredArt.new()
	art.size = Vector2(400, 300)
	root.add_child(art)
	await process_frame
	check(art.is_processing(), "visible art with motion allowed processes")
	art.visible = false
	check(not art.is_processing(), "hidden art does not process")
	art.visible = true
	check(art.is_processing(), "showing it again resumes processing")
	Motion.set_reduced(true)
	check(not art.is_processing(), "under Reduce motion it stops processing")
	art.visible = false
	art.visible = true
	check(not art.is_processing(), "showing it under Reduce motion does not restart processing")
	Motion.set_reduced(false)
	check(art.is_processing(), "switching Reduce motion off wakes it")
	art.queue_free()
	var reduced_first := LayeredArt.new()
	Motion.reduced = true
	root.add_child(reduced_first)
	await process_frame
	check(not reduced_first.is_processing(), "art created under Reduce motion never processes")
	Motion.reduced = false
	quit(1 if fails > 0 else 0)
