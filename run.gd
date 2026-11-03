extends Control
## Thin coordinator over RunState: routes to the current stop's screen, keeps the header line,
## autosaves and wires the pause menu. Each screen is built by a script under res://run/screens/
## (see docs/RUN_SCREEN_STRUCTURE.md); all run rules live in res://run/run_state.gd.

@onready var _layout: VBoxContainer = $Layout
@onready var _header_row: HBoxContainer = %HeaderRow
@onready var _header: Label = %HeaderLabel
@onready var _body: Control = %Body

var _run: RunState
## The run's relics beside the header line (hidden when there are none, on the select screens and
## during a fight, where the battle screen shows them itself).
var _header_strip: RelicStrip
## Where the in-progress run is saved; tests point this at a scratch file.
var save_path := RunSave.DEFAULT_PATH
## Where the player's settings (the update-check opt-out) are kept; tests point this at a scratch file.
var settings_path := Settings.DEFAULT_PATH
## One-off message shown above the header line: a bad save on launch, or a save/delete failure.
var _notice := ""
var _notice_shown := false
## What "Save & Exit" calls once the save is safe; tests replace it so they do not quit.
var exit_callable: Callable = func() -> void: get_tree().quit()

## Pause menu: a button in the corner and an overlay that freezes the scene tree (tests read these).
var _pause: PauseMenu
var _pause_button: Button
var _pause_overlay: Control
var _pause_box: VBoxContainer
var _pause_scene: PauseScene
## "Update available" bar over the first screens (character select, Continue prompt); tests read it.
var _update_notice: UpdateNotice

## The screens. The vendor and reward screens keep their own view state between redraws.
var _select := SelectScreen.new()
var _main_menu := MainMenuScreen.new()
var _combat := CombatScreen.new()
var _reward := RewardScreen.new()
var _story := StoryScreen.new()
var _vendor := VendorScreen.new()
var _rest := RestScreen.new()
var _end := EndScreen.new()
## True while a debug-launched fight is on screen (see start_debug_fight): nothing is saved or deleted.
var _debug_fight := false
## The header's two parts, kept so a fight can show them in its own layout (see _dock_combat_hud).
var _stop_title := ""
var _journey_text := ""


func _ready() -> void:
	get_window().title = "The Unforgotten"
	MenuStyle.apply(self)
	_header.add_theme_font_size_override("font_size", 14)
	_header_row.custom_minimum_size.y = 48
	_header_strip = RelicStrip.create([] as Array[RelicData])
	_header_row.add_child(_header_strip)
	_build_pause_menu()
	_update_notice = UpdateNotice.new()
	_update_notice.user_enabled = Settings.load_file(settings_path).update_check_enabled
	add_child(_update_notice)
	_update_notice.start() # asynchronous and silent on any failure; skipped headless (docs/UPDATE_CHECK.md)
	_body.resized.connect(_select.recenter)
	resized.connect(_select.recenter)
	_show_main_menu()
	_maybe_start_debug_fight()


## Points a screen at the current run and the body before it is shown.
func _open(screen: RunScreen) -> void:
	screen.attach(_run, _body, _show_stop)


## The start screen, shown on every launch and by Back from the select screen: nothing starts until
## the player picks Continue (offered only when a valid save exists), New Run or Exit.
func _show_main_menu() -> void:
	_set_audio(&"menu", &"coastal")
	_pause_button.visible = false
	_update_notice.set_allowed(true)
	_header_strip.set_relics([] as Array[RelicData])
	_clear_body()
	var loaded := RunSave.load_file(save_path)
	if loaded.run == null and not loaded.missing:
		_notice = "Saved run could not be loaded (%s)." % loaded.error
		push_warning(_notice)
	elif loaded.recovered_from != "":
		# The newest checkpoint was unreadable and an older one was loaded; say so instead of
		# letting the player wonder why a stop is missing.
		_notice = "Your latest checkpoint could not be read, so the one before it was loaded."
		push_warning("Save recovered from %s." % loaded.recovered_from)
	var prefix := _notice + "\n" if _notice != "" else ""
	_header.text = prefix + "A voice beyond the quiet"
	_notice_shown = _notice != ""
	_main_menu.attach(loaded.run, _body, _show_stop)
	_main_menu.show(loaded.run, _continue_run.bind(loaded.run), _new_run.bind(_show_main_menu), func() -> void: exit_callable.call(),
		_update_notice.user_enabled, _toggle_update_check, _update_notice)


## The main menu's update-check toggle: flips the saved setting and returns the new value. Turning it
## off cancels any request in flight and hides a shown notice; turning it on asks right away.
func _toggle_update_check() -> bool:
	var enabled := not _update_notice.user_enabled
	_update_notice.user_enabled = enabled
	var settings := Settings.load_file(settings_path)  # keep every other field as it is
	settings.update_check_enabled = enabled
	var error := settings.save(settings_path)
	if error != "":
		push_warning("Could not save settings (%s)." % error)
	if enabled:
		_update_notice.start()
	else:
		_update_notice.stop()
	return enabled


func _continue_run(saved: RunState) -> void:
	_play_sfx(&"confirm")
	_run = saved
	_reset_screens()
	_clear_body()
	_show_stop()


## Every route to a new run goes through here: pick who boards the train, then `_start_run`.
## `back`, when valid, adds a Back button that returns to the screen the player came from; there is
## none when the select screen is the first screen (no save, or a save that failed to load).
func _new_run(back := Callable()) -> void:
	_set_audio(&"menu", &"coastal")
	_pause_button.visible = false
	_update_notice.set_allowed(true)
	_header_strip.set_relics([] as Array[RelicData])
	_clear_body()
	var prefix := _notice + "\n" if _notice != "" else ""
	_header.text = prefix + "Choose who answers the voice"
	_notice_shown = _notice != ""
	_select.attach(null, _body, _show_stop)
	_select.show(self, _start_run, back)


func _start_run(character_id: StringName) -> void:
	_play_sfx(&"confirm")
	_run = RunState.new(randi(), character_id)
	_reset_screens()
	_show_stop()


func _reset_screens() -> void:
	_vendor.reset()
	_reward.reset()


func _show_stop() -> void:
	# A notice lives for one redraw past the one that first showed it.
	if _notice_shown:
		_notice = ""
	_update_notice.set_allowed(false) # only the first screens carry it, never a run in progress
	_set_stop_audio()
	_clear_body()
	if _run.finished:
		_delete_save()
		_update_header()
		_end.attach(_run, _body, _show_stop)
		_end.show(_new_run.bind(_show_stop), _show_main_menu)
	elif _run.reward_pending():
		_update_header()
		_open(_reward)
		_reward.show()
	else:
		_autosave()
		_update_header()
		match _run.current_stop().type:
			RunState.StopType.COMBAT:
				_open(_combat)
				_combat.show(_on_fight_finished, _new_run)
				_dock_combat_hud()
			RunState.StopType.STORY:
				_open(_story)
				_story.show()
			RunState.StopType.VENDOR:
				_open(_vendor)
				_vendor.show()
			_:
				_open(_rest)
				_rest.show()
		_warm_next_stop()


## Music and ambience for the current stop: the fight music only during a fight, the quiet track
## everywhere else, and the sea only at the first destination (Shore of Names).
func _set_stop_audio() -> void:
	var fighting := not _run.finished and not _run.reward_pending() and _run.current_stop().type == RunState.StopType.COMBAT
	var shore := not _run.finished and _run.stop_index == 0
	_set_audio(&"combat" if fighting else &"menu", &"coastal" if shore else &"")


func _set_audio(music: StringName, ambience: StringName) -> void:
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.set_scene(music, ambience)


func _play_sfx(id: StringName) -> void:
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.sfx(id)


func _update_header() -> void:
	var player := _run.player
	var position := mini(_run.stop_index + 1, _run.stops.size())
	var prefix := _notice + "\n" if _notice != "" else ""
	var stop_text := _run.current_stop().describe() if not _run.finished else "Journey's end"
	if not _run.finished:
		var destination := DestinationArt.label_at(_run.stop_index)
		if destination != "":
			stop_text = destination + " — " + stop_text
	if _run.reward_pending():
		stop_text = "Reward"
	_header.text = prefix + "%s\nJourney %d/%d  ·  %s  ·  HP %d/%d  ·  Gold %d  ·  Deck %d" % [
		stop_text, position, _run.stops.size(), player.display_name, player.hp, player.max_hp, _run.gold, _run.deck.size(),
	]
	_notice_shown = _notice != ""
	_stop_title = stop_text
	_journey_text = "Journey %d/%d" % [position, _run.stops.size()]
	_pause_button.visible = not _run.finished
	var fighting := not _run.finished and not _run.reward_pending() and _run.current_stop().type == RunState.StopType.COMBAT
	_header_strip.set_relics([] as Array[RelicData] if fighting else _run.relics)


func _clear_body() -> void:
	# Every screen but a fight has the top header and the framed margin; a fight turns both off again
	# in _dock_combat_hud. The Pause button must leave the fight before the fight is freed.
	_undock_pause_button()
	_header_row.visible = true
	_set_edge_margin(EDGE_MARGIN)
	for child in _body.get_children():
		# Removed at once (not just queued) so a stale button cannot be clicked this frame.
		_body.remove_child(child)
		child.queue_free()


func _on_fight_finished(victory: bool) -> void:
	if _debug_fight:
		# A debug fight is not part of a real run: no rewards, no save; back to the menu.
		_debug_fight = false
		_run.debug_encounter.clear()
		_show_main_menu()
		return
	_run.complete_combat(victory)
	_show_stop()


# --- Debug launch (run/debug_launch.gd) -----------------------------------------------------

## Starts straight in the fight asked for on the command line or in the environment, with the
## chosen character's real deck. Does nothing when no fight was asked for. A malformed request is
## reported in the menu notice and the log, and the menu is shown as usual.
func _maybe_start_debug_fight() -> void:
	var launch := DebugLaunch.from_environment()
	if not launch.requested:
		return
	if launch.list_only:
		print(DebugLaunch.help_text())
		return
	if launch.error != "":
		push_warning("Debug launch: %s" % launch.error)
		_notice = launch.error
		_show_main_menu()
		return
	start_debug_fight(launch)


## Builds a throwaway run for the character and opens a combat stop that fights `launch.enemy_ids`.
## The stop is the line's boss or mid-boss stop for those bosses (so the backdrop matches), else the
## first regular fight. Autosaving is off until the fight ends, so a real save is never replaced.
func start_debug_fight(launch: DebugLaunch) -> void:
	_run = RunState.new(randi(), launch.character_id)
	for index in _run.stops.size():
		var stop := _run.stops[index]
		if stop.type != RunState.StopType.COMBAT:
			continue
		var matches := stop.boss if launch.enemy_ids.has(&"the_conductor") else (stop.mid_boss if launch.enemy_ids.has(&"the_brakeman") else not (stop.boss or stop.mid_boss))
		if matches:
			_run.stop_index = index
			break
	_run.debug_encounter.assign(launch.enemy_ids)
	if launch.hp > 0:
		_run.player.hp = mini(launch.hp, _run.player.max_hp)
	_debug_fight = true
	_reset_screens()
	_show_stop()


# --- Vendor entry points (the vendor screen owns the logic; tests and tools call these) ------

## The vendor screen, pointed at the current run (these entry points work even when another
## screen is showing, as they did when the logic lived here).
func _vendor_for_run() -> VendorScreen:
	_open(_vendor)
	return _vendor


func _buy_card(offer_index: int) -> void:
	_vendor_for_run().buy_card(offer_index)


func _buy_relic() -> void:
	_vendor_for_run().buy_relic()


func _start_removing() -> void:
	_vendor_for_run().start_removing()


func _cancel_removing() -> void:
	_vendor_for_run().cancel_removing()


func _leave_vendor() -> void:
	_vendor_for_run().leave_vendor()


# --- Saving ---------------------------------------------------------------------------------

## Saves the run at the start of a stop (never mid-fight). A failure is shown, not fatal.
func _autosave() -> void:
	if _debug_fight:
		return
	if not _run.at_stop_boundary():
		return
	var error := RunSave.save(_run, save_path)
	if error != "":
		_notice = "Could not save the run: %s" % error
		push_warning(_notice)


## A finished run has nothing to resume.
func _delete_save() -> void:
	if _debug_fight:
		return
	var error := RunSave.delete(save_path)
	if error != "":
		_notice = error
		push_warning(_notice)


# --- Pause menu -----------------------------------------------------------------------------

func _build_pause_menu() -> void:
	# This screen keeps running while the tree is paused (the overlay buttons and the Escape key
	# need to), so only the run body, which holds the fight, is made pausable.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_body.process_mode = Node.PROCESS_MODE_PAUSABLE
	_pause = PauseMenu.new(self, func() -> RunState: return _run, _save_and_exit, _new_run.bind(_show_main_menu))
	_pause.build()
	_pause_button = _pause.button
	_pause_overlay = _pause.overlay
	_pause_box = _pause.box
	_pause_scene = _pause.backdrop


func _unhandled_key_input(event: InputEvent) -> void:
	_pause.handle_key(event)


func _set_paused(on: bool) -> void:
	_pause.set_paused(on)


## The run is saved at the start of each stop, so mid-fight the existing save is already the
## resume point; only at a stop boundary is there anything new to write. Never exits unless
## a save exists to come back to. Returns "" once the exit is requested, else why it did not.
func _save_and_exit() -> String:
	if _run.at_stop_boundary():
		var error := RunSave.save(_run, save_path)
		if error != "":
			return "Could not save: %s" % error
	elif not FileAccess.file_exists(save_path):
		return "No save to resume from, so not exiting."
	exit_callable.call()
	return ""


## Decodes the art of the stop after this one while the player is busy with the current stop, so
## the next screen does not stutter on first use (PaintedArt.warm_for_stop).
func _warm_next_stop() -> void:
	var next_index := _run.stop_index + 1
	if next_index >= _run.stops.size():
		return
	PaintedArt.warm_for_stop(int(_run.stops[next_index].type), _run.character.id)
	var backdrop := DestinationArt.battle_key(next_index)
	if backdrop != &"":
		PaintedArt.preload_screen(backdrop)


# --- Fight HUD -------------------------------------------------------------------------------
# During a fight the top header and the framed margin go away. The fight shows the stop title and
# journey number itself (battle.gd `set_journey`), and the Pause button shrinks into the top-right corner.

## Screen margin around every non-fight screen.
const EDGE_MARGIN := 16.0

func _set_edge_margin(margin: float) -> void:
	_layout.offset_left = margin
	_layout.offset_top = margin
	_layout.offset_right = -margin
	_layout.offset_bottom = -margin


## Hands the header info to the fight on screen and makes the Pause button small. Does nothing when the
## fight could not be built (the "Start over" panel keeps the normal header).
func _dock_combat_hud() -> void:
	var battle := _combat.fight
	if battle == null or not is_instance_valid(battle):
		return
	_header_row.visible = false
	_set_edge_margin(0.0)
	battle.set_journey(_stop_title, _journey_text, _run.player.display_name, _run.deck.size())
	_place_pause_button(MenuStyle.SMALL, 8)


## Restores the Pause button's normal size after a fight.
func _undock_pause_button() -> void:
	if _pause_button != null and _pause_button.theme_type_variation != &"":
		_place_pause_button(&"", 12)


func _place_pause_button(variation: StringName, margin: int) -> void:
	_pause_button.theme_type_variation = variation
	_pause_button.reset_size()
	_pause_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, margin)
