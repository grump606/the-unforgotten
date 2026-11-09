class_name Motion
extends RefCounted
## The one switch for animation. When `reduced` is true all non-essential motion holds still or is instant:
## the menu, pause, story, rest, select, end and vendor scenes (drifts, sways, flames, motes, the till pulse;
## the end card shows its settled state), the battle backdrop, the fighters (idle breathing and weight shift,
## lunge, recoil, hit flash, shield pop, phase shake, entrance scale-in; the defeat fade is instant), the card
## tilt and lift, and the tweened cues (phase banner, screen flash, pile cue, confirm pulse, boss intro).
## Essential feedback stays but is not animated: damage and healing numbers appear in place, and HP and
## Block change at once. tests/ui_reduced_motion_test.gd checks each of these and scans the sources, so a new
## animation must mention `Motion.reduced` (or be listed there with a reason). The value comes from
## Settings.reduced_motion (loaded at startup, toggled on the Sound page); tests set it directly.
## Godot 4.7 exposes no operating-system "reduce motion" preference, so only the in-game setting is read.

static var reduced := false
## Nodes that stop processing when they have nothing to animate (the fighters) join this group and get
## `_on_motion_changed()` when the setting flips at runtime.
const FOLLOWERS := &"motion_followers"


## Reads the saved preference into `reduced`.
static func load_from(settings_path: String) -> void:
	reduced = Settings.load_file(settings_path).reduced_motion


## Sets `reduced` and tells the followers to pick the new setting up (a fighter that went idle under reduced
## motion starts breathing again; one that is breathing stops on its next frame). Tests may still assign
## `reduced` directly.
static func set_reduced(on: bool) -> void:
	if reduced == on:
		return
	reduced = on
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		tree.call_group(FOLLOWERS, "_on_motion_changed")


## Sets `reduced` and saves it, keeping every other setting as it is. Returns "" or why saving failed.
static func set_and_save(on: bool, settings_path: String) -> String:
	set_reduced(on)
	var settings := Settings.load_file(settings_path)
	if settings.reduced_motion == on:
		return ""
	settings.reduced_motion = on
	return settings.save(settings_path)
