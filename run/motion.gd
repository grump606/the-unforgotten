class_name Motion
extends RefCounted
## The one switch for animation: when `reduced` is true the menu and pause scenes, the battle backdrop, the
## card tilt and lift, the phase-two flash and the boss entrance hold still or are much shorter. The value
## comes from Settings.reduced_motion (loaded at startup, toggled on the Sound page); tests set it directly.
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
