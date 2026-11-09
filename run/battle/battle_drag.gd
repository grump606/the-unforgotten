class_name BattleDrag
extends RefCounted
## Dragging a card onto an enemy. The card is lifted out of the hand as a ghost that follows the pointer; the
## enemy under it lights up with what the card would do to THAT enemy (the same "Deals 15 (6 vs Exposed), 2
## after Block" line the card face shows for the selected one). Releasing over a living enemy plays the card on
## it, leaving the selected target alone; releasing anywhere else, Esc or right-click cancels. Clicking still
## plays on the selected enemy.

## The card ghost that follows the pointer: a little smaller than the hand card and see-through, with the
## hovered enemy's result label drawn above it (Fighter.DROP_LABEL_Z).
const GHOST_SCALE := 0.85
const GHOST_ALPHA := 0.7
const GHOST_Z := 20

## The dragged hand card, the ghost that follows the pointer, and the enemy index under it (-1 for none).
var view: CardView
var ghost: CardView
var hover := -1

var _battle: Battle


func _init(battle: Battle) -> void:
	_battle = battle


func started(source: CardView) -> void:
	end()
	var combat := _battle.combat()
	if combat == null or combat.phase != Combat.Phase.PLAYER_TURN:
		source.cancel_drag()
		return
	_battle.hand().hide_preview()
	view = source
	source.modulate.a = 0.35
	ghost = CardView.new()
	ghost.view_scale = source.view_scale * GHOST_SCALE
	ghost.modulate.a = GHOST_ALPHA
	ghost.z_index = GHOST_Z
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.live = combat.player
	ghost.set_card(source.card)
	ghost.set_state(CardView.State.NORMAL)
	ghost.preview = source.preview
	ghost.hotkey = source.hotkey
	_battle.add_child(ghost)
	moved(source.get_global_rect().get_center())


func moved(pos: Vector2) -> void:
	if ghost == null or view == null:
		return
	ghost.global_position = pos - ghost.size / 2.0
	var index := enemy_at(pos)
	if index != hover:
		_clear_hover()
		hover = index
	if index >= 0:
		var info := _battle.damage_preview().for_target(view.card, _battle.combat().enemies[index])
		_battle.enemy_views()[index].set_drop_hover(true, info.get("text", ""), info.get("lost", -1))
		# A boss has no HP bar of its own, so its ghost goes on the wide bar at the top.
		var bar := _battle.boss_bar()
		if bar != null and bar.unit == _battle.combat().enemies[index]:
			bar.set_drop_lost(info.get("lost", -1))


func ended(pos: Vector2, hand_index: int) -> void:
	var index := enemy_at(pos)
	end()
	var combat := _battle.combat()
	if index < 0 or combat == null:
		return
	_battle.begin_batch()
	if not combat.play_card(hand_index, index):
		RunScreen.sfx(&"unavailable")
	_battle.end_batch()


## Index of the living enemy whose figure is under `pos` (viewport coordinates), or -1.
func enemy_at(pos: Vector2) -> int:
	var combat := _battle.combat()
	if combat == null:
		return -1
	var views := _battle.enemy_views()
	for i in views.size():
		if i < combat.enemies.size() and not combat.enemies[i].is_dead() and views[i].get_global_rect().has_point(pos):
			return i
	return -1


func _clear_hover() -> void:
	var views := _battle.enemy_views()
	if hover >= 0 and hover < views.size():
		views[hover].set_drop_hover(false)
	if _battle.boss_bar() != null:
		_battle.boss_bar().set_drop_lost(-1)
	hover = -1


## Puts everything a drag changed back: the ghost, the enemy highlight and the dimmed hand card.
func end() -> void:
	_clear_hover()
	if ghost != null:
		ghost.queue_free()
		ghost = null
	if view != null and is_instance_valid(view):
		view.modulate.a = 1.0
	view = null


## True while a card is being dragged (read by tests).
func is_dragging() -> bool:
	return view != null


## Esc while dragging: abandons the drag. True when there was one to cancel.
func cancel_with_key() -> bool:
	if view == null or not is_instance_valid(view):
		return false
	view.cancel_drag()
	return true
