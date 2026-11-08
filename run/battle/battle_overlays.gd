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
		choice = ChoiceOverlay.create(combat, _battle._stage.size, combat.player)
		choice.z_index = Z
		choice.confirmed.connect(on_choice_confirmed)
		_battle._stage.add_child(choice)


func close_choice() -> void:
	if choice != null and is_instance_valid(choice):
		_battle._discard_node(choice)
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
	_battle._begin_batch()
	if not combat.resolve_choice(indices):
		_battle.request_refresh() # the overlay was closed above: bring it back
	_battle._end_batch()


## Opens the read-only viewer on a pile. Only during the player's turn and the discard step: not while a
## Glimpse / Recall pick is open, in the enemy phase or after the fight. True when it opened.
func open_pile_viewer(which: PileViewer.Pile) -> bool:
	var combat := _battle.combat()
	if combat == null or combat.phase not in [Combat.Phase.PLAYER_TURN, Combat.Phase.DISCARDING]:
		return false
	if pile_viewer != null:
		pile_viewer.show_pile(which)
		return true
	_battle._hand.hide_preview()
	pile_viewer = PileViewer.create(combat, which, _battle.size, combat.player)
	pile_viewer.z_index = Z
	pile_viewer.closed.connect(close_pile_viewer)
	_battle.add_child(pile_viewer)
	return true


func close_pile_viewer() -> void:
	if pile_viewer != null and is_instance_valid(pile_viewer):
		_battle._discard_node(pile_viewer)
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
