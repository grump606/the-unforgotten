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


## Reads the saved preference into `reduced`.
static func load_from(settings_path: String) -> void:
	reduced = Settings.load_file(settings_path).reduced_motion


## Sets `reduced` and saves it, keeping every other setting as it is. Returns "" or why saving failed.
static func set_and_save(on: bool, settings_path: String) -> String:
	reduced = on
	var settings := Settings.load_file(settings_path)
	if settings.reduced_motion == on:
		return ""
	settings.reduced_motion = on
	return settings.save(settings_path)
