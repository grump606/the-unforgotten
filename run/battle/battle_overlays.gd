class_name BattleOverlays
extends RefCounted
## The two on-demand overlays of a fight: the Glimpse / Recall pick while Combat is CHOOSING, and the read-only
## pile viewer. Both are created when needed and discarded when the fight or the phase no longer allows them.

## Layer of the choice overlay and the pile viewer (above the figures, below the phase banner).
const Z := 22
## Layers of the screen-wide effects, above the overlays: the phase-change flash and the phase banner.
const PHASE_FLASH_Z := 39
const PHASE_BANNER_Z := 40
## Keys that open the Draw, Discard, Forgotten and Sworn piles (D, C, F and W; the letters are free of the
## other hotkeys).
const PILE_KEYS := [KEY_D, KEY_C, KEY_F, KEY_W]

var choice: ChoiceOverlay
var pile_viewer: PileViewer

var _battle: Battle
## What had keyboard focus when each overlay opened (null when nothing did); closing the overlay gives it back.
var _pile_focus_before: Control
var _choice_focus_before: Control


func _init(battle: Battle) -> void:
	_battle = battle


## Closes both (a new fight on this screen).
func close_all() -> void:
	close_pile_viewer()
	close_choice()


## Shows the Glimpse / Recall overlay exactly while Combat is CHOOSING. A refresh with the same choice
## keeps the overlay (and the player's marks); a new choice (a second queued pick) gets a fresh one.
func sync_choice() -> void:
	var combat := _battle.combat()
	var wanted := combat.phase == Combat.Phase.CHOOSING and combat.has_choice()
	if choice != null and (not wanted or not choice.matches(combat)):
		close_choice()
	if wanted and choice == null:
		close_pile_viewer()
		choice = ChoiceOverlay.create(combat, _battle.stage().size, combat.player)
		choice.z_index = Z
		choice.confirmed.connect(on_choice_confirmed)
		_battle.stage().add_child(choice)
		_choice_focus_before = _focus_owner_outside(choice)
		choice.focus_first()


func close_choice() -> void:
	if choice != null and is_instance_valid(choice):
		_battle.discard_node(choice)
		_restore_focus(_choice_focus_before)
	_choice_focus_before = null
	choice = null


## True while the Glimpse / Recall overlay is up (read by tests).
func choice_visible() -> bool:
	return choice != null and is_instance_valid(choice)


func on_choice_confirmed(indices: Array[int]) -> void:
	var combat := _battle.combat()
	if combat == null or combat.phase != Combat.Phase.CHOOSING:
		return
	close_choice()
	RunScreen.sfx(&"card_select")
	_battle.begin_batch()
	if not combat.resolve_choice(indices):
		_battle.request_refresh() # the overlay was closed above: bring it back
	_battle.end_batch()


## Opens the read-only viewer on a pile. Only during the player's turn and the discard step: not while a
## Glimpse / Recall pick is open, in the enemy phase or after the fight. True when it opened.
func open_pile_viewer(which: PileViewer.Pile) -> bool:
	var combat := _battle.combat()
	if combat == null or combat.phase not in [Combat.Phase.PLAYER_TURN, Combat.Phase.DISCARDING]:
		return false
	if pile_viewer != null:
		pile_viewer.show_pile(which)
		return true
	_battle.hand().hide_preview()
	pile_viewer = PileViewer.create(combat, which, _battle.size, combat.player)
	pile_viewer.z_index = Z
	pile_viewer.closed.connect(close_pile_viewer)
	_battle.add_child(pile_viewer)
	_pile_focus_before = _focus_owner_outside(pile_viewer)
	pile_viewer.focus_active_tab()
	return true


func close_pile_viewer() -> void:
	if pile_viewer != null and is_instance_valid(pile_viewer):
		_battle.discard_node(pile_viewer)
		_restore_focus(_pile_focus_before)
	_pile_focus_before = null
	pile_viewer = null


## True while the pile viewer is open (read by tests).
func pile_viewer_open() -> bool:
	return pile_viewer != null and is_instance_valid(pile_viewer)


## Keeps an open viewer in step with the piles, and closes it when the phase no longer allows one.
func sync_pile_viewer() -> void:
	if pile_viewer == null:
		return
	if _battle.combat().phase not in [Combat.Phase.PLAYER_TURN, Combat.Phase.DISCARDING]:
		close_pile_viewer()
	else:
		pile_viewer.refresh()


## The focused control, unless it is inside `overlay` (a freshly opened overlay may already hold focus).
func _focus_owner_outside(overlay: Control) -> Control:
	var owner := _battle.get_viewport().gui_get_focus_owner()
	return null if owner == null or overlay.is_ancestor_of(owner) else owner


## Gives `target` focus again when it is still on screen, and otherwise just lets go of the closed overlay's focus.
func _restore_focus(target: Control) -> void:
	if target != null and is_instance_valid(target) and target.is_inside_tree() and target.is_visible_in_tree() 			and target.focus_mode != Control.FOCUS_NONE:
		target.grab_focus()
