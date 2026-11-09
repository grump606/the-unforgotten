class_name BattleHand
extends RefCounted
## The hand row of the battle screen: keeping one CardView per hand card in step with the fight, fitting the row
## to the available width, the hover look, the full-size inspection preview and playing a card by index.

## Keys 1-9 pick hand cards 1-9 and 0 picks the 10th.
const MAX_HAND_KEYS := 10
## Layer of the enlarged copy of the hovered card, above the hand and the stage.
const PREVIEW_Z := 10
## Hand cards are drawn smaller than full size so a hand fits beside the enemy row and log.
const CARD_SCALE := 0.7
## A hand too wide for one row first shrinks its cards down to this scale, then overlaps them
## (the left edge with the cost stamp and hotkey stays visible; a hovered card comes to the front).
const CARD_SCALE_MIN := 0.6
## Gap between hand cards when they do not need to overlap.
const GAP := 4
## Used for the fit calculation before the hand box has been laid out (headless / first frame).
const WIDTH_FALLBACK := 820.0
## Most the cards may overlap, as a share of one card's width (with 10 cards this never binds at 1152 px).
const MAX_OVERLAP := 0.55
## Scale of the inspection preview shown above the hand for the hovered card.
const PREVIEW_SCALE := 1.6

## Full-size look at the hovered hand card (created on first use), and the hand card it shows.
var preview: CardView
var preview_source: CardView

var _battle: Battle
var _box: HFlowContainer


func _init(battle: Battle, box: HFlowContainer) -> void:
	_battle = battle
	_box = box


## Brings the hand row up to date after a state change. The views are kept (so hover, drag, the tooltip and the
## preview survive) and only their state, note, preview and marks are updated; the row is rebuilt from scratch
## only when the hand size or a card at some index changed.
func sync() -> void:
	var combat := _battle.combat()
	var hand := combat.piles.hand
	var views := views_in_order()
	var same := views.size() == hand.size()
	if same:
		for i in views.size():
			if views[i].card != hand[i]:
				same = false
				break
	if not same:
		rebuild()
		return
	var discarding := combat.phase == Combat.Phase.DISCARDING
	var hand_scale := fit()
	for i in views.size():
		_apply_view(views[i], i, discarding, hand_scale)
	if preview != null and preview.visible and preview_source != null and is_instance_valid(preview_source) and views.has(preview_source):
		show_preview(preview_source)


## The hand row's card views in order.
func views_in_order() -> Array[CardView]:
	var out: Array[CardView] = []
	for child in _box.get_children():
		var view := child as CardView
		if view != null:
			out.append(view)
	return out


func rebuild() -> void:
	_battle.drag().end()
	hide_preview()
	for child in _box.get_children():
		_battle.discard_node(child)
	var combat := _battle.combat()
	var discarding := combat.phase == Combat.Phase.DISCARDING
	var hand_scale := fit()
	for i in combat.piles.hand.size():
		var view := CardView.new()
		view.auto_hover = true
		view.clickable = true
		view.live = combat.player
		# The handlers look the index up when they fire (the view's place in the row), so they stay right
		# however the row changes around the view.
		view.pressed.connect(func() -> void: play_card(view.get_index()))
		view.drag_started.connect(_battle.drag().started.bind(view))
		view.drag_moved.connect(_battle.drag().moved)
		view.drag_ended.connect(func(pos: Vector2) -> void: _battle.drag().ended(pos, view.get_index()))
		view.drag_cancelled.connect(_battle.drag().end)
		view.hover_changed.connect(_on_card_hover.bind(view))
		_apply_view(view, i, discarding, hand_scale)
		_box.add_child(view)
	# The new views start un-hovered; once laid out, light the one under the pointer.
	restore_hover.call_deferred()


## Sets everything about hand view `i` that follows from the fight: its card, size, state and note, damage
## preview, discard mark and hotkey. Writes only what differs, so an unchanged card is not redrawn.
func _apply_view(view: CardView, i: int, discarding: bool, hand_scale: float) -> void:
	var combat := _battle.combat()
	var card := combat.piles.hand[i]
	if view.card != card:
		view.set_card(card)
	if view.view_scale != hand_scale:
		view.view_scale = hand_scale
	var hotkey := i + 1 if i < MAX_HAND_KEYS else 0
	if view.hotkey != hotkey:
		view.hotkey = hotkey
	var damage_line := _battle.damage_preview().line_for(card, _battle.target_index()).strip_edges() if not discarding else ""
	if view.preview != damage_line:
		view.preview = damage_line
	var marked := discarding and combat.discard_marks.has(i)
	if view.discard_marked != marked:
		view.discard_marked = marked
	var new_state := CardView.State.NORMAL
	var note := ""
	if discarding:
		# Cards that can be discarded toggle; marked ones are dimmed and stamped. Anchor and Fading
		# cards cannot be marked, and say what happens to them instead.
		note = "" if combat.can_discard_card(i) else _undiscardable_note(card)
	elif not combat.can_play(i):
		new_state = CardView.State.UNPLAYABLE
		note = _unplayable_note(card)
	if view.state != new_state or view.note != note:
		view.set_state(new_state, note)
	# Only cards that target enemies can be dragged (to an enemy, whether or not it is selected).
	view.draggable = not discarding and card.target_mode != CardData.TargetMode.SELF


## Sizes the hand row so every card fits on one line: normal scale and gap when it fits, then
## smaller cards, then overlap. Sets the box's horizontal separation and returns the card scale.
func fit() -> float:
	var count := _battle.combat().piles.hand.size()
	var avail := _box.size.x if _box.size.x > 100.0 else WIDTH_FALLBACK
	var scale := CARD_SCALE
	var gap := float(GAP)
	if count > 1:
		var width := CardView.BASE.x * scale
		if count * width + (count - 1) * gap > avail:
			scale = clampf((avail - (count - 1) * gap) / (count * CardView.BASE.x), CARD_SCALE_MIN, CARD_SCALE)
			width = CardView.BASE.x * scale
			if count * width + (count - 1) * gap > avail:
				gap = maxf((avail - count * width) / (count - 1), -MAX_OVERLAP * width)
	_box.add_theme_constant_override("h_separation", int(floorf(gap)))
	return scale


## What happens to a card the discard step will not let the player mark.
func _undiscardable_note(card: CardData) -> String:
	return "FORGOTTEN AT END" if card.fading else "ANCHOR: STAYS"


## Why a hand card cannot be played right now, as a short warning for the card ("" when the
## fight is not on the player's turn, where nothing is playable and no card needs a warning).
func _unplayable_note(card: CardData) -> String:
	var combat := _battle.combat()
	if combat.phase != Combat.Phase.PLAYER_TURN:
		return ""
	if card.dormant:
		return "DORMANT"
	if card.cost > combat.energy:
		return "NEED %d ENERGY" % card.cost
	if card.hp_cost(combat.surge_scale(card)) >= combat.player.hp:
		return "TOO LOW HP"
	return "PLAY LIMIT"


## Plays (or, in the discard step, marks) the hand card at `hand_index` on the selected enemy.
func play_card(hand_index: int) -> void:
	var combat := _battle.combat()
	if combat == null or combat.phase == Combat.Phase.CHOOSING or _battle.overlays().pile_viewer_open():
		return # a Glimpse / Recall pick must be finished first; the pile viewer sits over the hand
	_battle.begin_batch()
	if combat.phase == Combat.Phase.DISCARDING:
		if combat.toggle_discard(hand_index):
			RunScreen.sfx(&"card_select")
	elif not combat.play_card(hand_index, _battle.target_index()) and combat.phase == Combat.Phase.PLAYER_TURN and hand_index < combat.piles.hand.size():
		RunScreen.sfx(&"unavailable")  # a card that cannot be played right now
	_battle.end_batch()


## Re-applies the hover look to the hand card under the pointer after a rebuild (the new views
## get no mouse_entered until the mouse moves). Every other card is cleared, so none sticks.
func restore_hover(mouse := Vector2(-1.0, -1.0)) -> void:
	if not is_instance_valid(_battle) or not _battle.is_inside_tree(): # a deferred call can outlive the screen
		return
	if mouse == Vector2(-1.0, -1.0):
		mouse = _battle.get_viewport().get_mouse_position()
	var found := false
	for child in _box.get_children():
		var view := child as CardView
		if view == null:
			continue
		var over := not found and view.get_global_rect().has_point(mouse)
		found = found or over
		view.set_hovered(over)


func _on_card_hover(inside: bool, view: CardView) -> void:
	if inside:
		show_preview(view)
	elif preview != null and preview.card == view.card and preview.visible:
		hide_preview()


## Shows a full-size copy of a hand card above the hand. It ignores the mouse, so it never blocks a click.
func show_preview(view: CardView) -> void:
	if view.card == null:
		return
	preview_source = view
	if preview == null:
		preview = CardView.new()
		preview.view_scale = PREVIEW_SCALE
		preview.z_index = PREVIEW_Z
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_battle.add_child(preview)
	preview.live = view.live
	preview.set_card(view.card)
	preview.set_state(CardView.State.UNPLAYABLE if view.state == CardView.State.UNPLAYABLE else CardView.State.NORMAL, view.note)
	preview.hotkey = view.hotkey
	preview.preview = view.preview
	preview.discard_marked = view.discard_marked
	var card_rect := view.get_global_rect()
	var width := CardView.BASE.x * PREVIEW_SCALE
	var height := (CardView.BASE.y + CardView.LIFT) * PREVIEW_SCALE
	var hand_top := _box.get_global_rect().position.y
	var x := clampf(card_rect.get_center().x - width / 2.0, 4.0, maxf(_battle.size.x - width - 4.0, 4.0))
	preview.global_position = Vector2(x, maxf(hand_top - height - 6.0, 4.0))
	preview.show()


func hide_preview() -> void:
	if preview != null:
		preview.hide()


## True while the inspection preview is on screen (read by tests).
func preview_visible() -> bool:
	return preview != null and preview.visible
