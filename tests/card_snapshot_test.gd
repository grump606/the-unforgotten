extends SceneTree
## Card snapshot test: renders a fixed set of cards (every class style, the status style, a rare, a Remembered card)
## in three states and compares each picture with tests/golden/cards/<name>.png. Catches drawing changes that the
## headless tests cannot see (they check layout and text, not pixels).
##
## Needs a renderer, so it is NOT headless: scripts/check.ps1 runs it windowed on a desktop and skips it in CI (the
## runners have no OpenGL). Run alone:
##   godot --path . -s res://tests/card_snapshot_test.gd             compare with the goldens
##   godot --path . -s res://tests/card_snapshot_test.gd -- --update  rewrite the goldens after an intended change
## A mismatch saves the picture it got to user://card_snapshot_failures/ for a look.
##
## GPUs and drivers anti-alias a little differently, so the comparison is tolerant: a pixel differs only when a
## channel moves by more than CHANNEL_TOLERANCE (of 255), and up to MAX_DIFF_FRACTION of the pixels may differ.

const GOLDEN_DIR := "res://tests/golden/cards"
const FAILURE_DIR := "user://card_snapshot_failures"
const CHANNEL_TOLERANCE := 8
const MAX_DIFF_FRACTION := 0.005
## Card ids from data/cards (or data/status) and a short label for the file name.
const CARDS := [
	["res://data/cards/brace.tres", "neutral"],
	["res://data/cards/bash.tres", "deserter"],
	["res://data/cards/cleaned_out.tres", "thief"],
	["res://data/cards/bleed_the_veil.tres", "medium_rare"],
	["res://data/cards/bring_down.tres", "stray_rare"],
	["res://data/status/dread.tres", "status"],
]
const PAD := 8

var _failures := 0
var _checked := 0


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		print("NOTE: card snapshot skipped: it needs a renderer (run it without --headless)")
		quit(0)
		return
	Motion.reduced = true # no hover lift or tilt animation: every frame is the same picture
	var update := OS.get_cmdline_user_args().has("--update")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(CardView.BASE) + Vector2i(PAD, PAD) * 2
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	if update:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GOLDEN_DIR))
	for entry in _cases():
		var view := CardView.new()
		view.set_card(entry[0])
		view.set_state(entry[1], entry[2])
		view.position = Vector2(PAD, PAD)
		viewport.add_child(view)
		# Let layout, lazily loaded card art and the first draw settle.
		for i in 6:
			await process_frame
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		image.convert(Image.FORMAT_RGBA8)
		if update:
			image.save_png(ProjectSettings.globalize_path("%s/%s.png" % [GOLDEN_DIR, entry[3]]))
		else:
			_compare(image, entry[3])
		view.free()
	print("card snapshots: %d %s, %d failures" % [_checked if not update else _cases().size(), "checked" if not update else "written", _failures])
	print("FAILURES: %d" % _failures)
	quit(1 if _failures > 0 else 0)


## [card, state, note, file name] for every picture.
func _cases() -> Array:
	var out := []
	for entry in CARDS:
		var card := load(entry[0]) as CardData
		if card == null:
			printerr("FAIL: card snapshot: cannot load %s" % entry[0])
			_failures += 1
			continue
		out.append([card, CardView.State.NORMAL, "", "%s_normal" % entry[1]])
		out.append([card, CardView.State.SELECTED, "", "%s_selected" % entry[1]])
		out.append([card, CardView.State.UNPLAYABLE, "Not enough energy", "%s_unplayable" % entry[1]])
	var bash := load("res://data/cards/bash.tres") as CardData
	if bash != null:
		out.append([bash.remembered_card(), CardView.State.NORMAL, "", "deserter_remembered_normal"])
	return out


func _compare(got: Image, file_name: String) -> void:
	_checked += 1
	var path := "%s/%s.png" % [GOLDEN_DIR, file_name]
	if not FileAccess.file_exists(path):
		_fail(got, file_name, "no golden at %s (run with -- --update to create it)" % path)
		return
	var golden := Image.load_from_file(ProjectSettings.globalize_path(path))
	if golden == null:
		_fail(got, file_name, "the golden %s cannot be read" % path)
		return
	golden.convert(Image.FORMAT_RGBA8)
	if golden.get_size() != got.get_size():
		_fail(got, file_name, "size %s, golden %s" % [got.get_size(), golden.get_size()])
		return
	var a := got.get_data()
	var b := golden.get_data()
	var differing := 0
	for i in range(0, a.size(), 4):
		for c in 4:
			if absi(int(a[i + c]) - int(b[i + c])) > CHANNEL_TOLERANCE:
				differing += 1
				break
	var pixels := got.get_width() * got.get_height()
	if differing > int(pixels * MAX_DIFF_FRACTION):
		_fail(got, file_name, "%d of %d pixels differ (allowed %d)" % [differing, pixels, int(pixels * MAX_DIFF_FRACTION)])


func _fail(got: Image, file_name: String, why: String) -> void:
	_failures += 1
	DirAccess.make_dir_recursive_absolute(FAILURE_DIR)
	var saved := "%s/%s.png" % [FAILURE_DIR, file_name]
	got.save_png(saved)
	printerr("FAIL: card snapshot %s: %s (got: %s)" % [file_name, why, ProjectSettings.globalize_path(saved)])
