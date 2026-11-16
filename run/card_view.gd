class_name CardView
extends Control
## A keepsake card framed in worn paper and stitched cloth, drawn entirely in code.
## One layout for every card; the class (CardData.character) picks the palette, the frame
## decoration and the corner emblem, the effect kinds pick the icon. Neutral cards are plain
## faded bone paper. Drawn in a fixed BASE-sized space and scaled by view_scale.
## This script holds the layout, state, input and hover lift; the face itself is drawn by CardFace
## (run/card_face.gd) and the per-class decoration by CardDecor (run/card_decor.gd).

enum State { NORMAL, HOVER, SELECTED, UNPLAYABLE }

const BASE := Vector2(136, 190)
## Extra height so a raised (hover/selected) card has room to lift without moving the layout.
const LIFT := 6.0
## Height of the keyword line at the top of the effect text.
const KEYWORD_H := 11.0
## Opacity of a Fading card.
const FADING_ALPHA := 0.8
## Keyword line colours: on dark class stock and on the pale neutral paper.
const KEYWORD_INK := MenuStyle.AMBER
const KEYWORD_INK_PAPER := Color("#8a4a14")
const BACKDROP := Color(0.05, 0.05, 0.08)
const BADGE := MenuStyle.AMBER
const BADGE_BAD := Color(0.78, 0.18, 0.20)
const WARN := MenuStyle.AMBER
const HP_RED := Color("#a8323a")
const SELECT_GOLD := MenuStyle.AMBER
const PALETTES := CardPalette.PALETTES

const KIND_COLORS := CardIcons.KIND_COLORS
## Tint of a debuff (a negative Malice or Ward) on a status pill.
const STATUS_NEGATIVE := Color(0.95, 0.35, 0.35)
## Live card numbers: green when a status raises the printed number, red when it lowers it.
const NUMBER_RAISED := Color("#5fd16b")
const NUMBER_LOWERED := Color("#ff6a5e")
const NUMBER_RAISED_PAPER := Color("#1f7a2c")
const NUMBER_LOWERED_PAPER := Color("#b3261e")
## Half-size of the up / down triangle beside a live number, as a share of the text size.
const DELTA_MARKER_HALF := 0.3
const KEYWORDS := {
	CardEffect.Kind.EXPOSE: "EXPOSE", CardEffect.Kind.HOLD: "HOLD",
	CardEffect.Kind.THORNS: "THORNS", CardEffect.Kind.HAUNT: "HAUNT",
	CardEffect.Kind.SHAKEN: "SHAKEN", CardEffect.Kind.FRAYED: "FRAYED",
	CardEffect.Kind.MALICE: "MALICE", CardEffect.Kind.WARD: "WARD",
}

## Emitted when a clickable card is clicked (never for an Unplayable one).
signal pressed
## Emitted when the pointer enters or leaves (also via set_hovered), for cards that auto_hover.
signal hover_changed(inside: bool)
## Drag lifecycle of a `draggable` card; positions are in viewport coordinates.
signal drag_started
signal drag_moved(global_pos: Vector2)
signal drag_ended(global_pos: Vector2)
signal drag_cancelled
## Pixels the pointer must travel with the button held before a press counts as a drag, not a click.
const DRAG_THRESHOLD := 8.0

var card: CardData
## Which palette the current card uses: &"" (neutral) or a class id.
var class_id: StringName = &""
var state: State = State.NORMAL
## Short warning replacing the keyword strip (for example "NEED 2 ENERGY"); empty for none.
var note := ""
## A short line near the bottom of the card (for example a damage preview); empty for none.
var preview := "":
	set(value):
		preview = value
		queue_redraw()
## Number shown in a small badge by the cost stamp (a hotkey); 0 for none.
var hotkey := 0:
	set(value):
		hotkey = value
		queue_redraw()
## True while the card is marked to be thrown away at end of turn (dimmed, stamped DISCARD).
var discard_marked := false:
	set(value):
		discard_marked = value
		queue_redraw()
## The player in a fight: when set, Deal and Block numbers on the face show their effective value (see
## body_lines). Null outside a fight, so printed numbers show. The owner rebuilds or redraws the card when
## the player's statuses change.
var live: Combatant = null:
	set(value):
		live = value
		queue_redraw()
var view_scale := 1.0:
	set(value):
		view_scale = value
		_update_size()
## When true the card lifts on mouse hover by itself. Off by default: the owner sets the state.
var auto_hover := false:
	set(value):
		auto_hover = value
		_update_mouse_filter()
## When true a click emits `pressed`, unless the card is Unplayable. Off by default.
var clickable := false:
	set(value):
		clickable = value
		_update_mouse_filter()

## When true (and the card is not Unplayable) the card can be dragged out of the hand. Off by default.
var draggable := false

static var _neutral: Combatant = null
var _pressing := false
var _dragging := false
var _press_global := Vector2.ZERO
var _hovered := false
var _tilt := Vector2.ZERO
## 0 (resting) to 1 (raised); eases over LIFT_TIME unless Motion.reduced (which also stops the tilt).
var _lift := 0.0
## Draws the face (see _draw).
var _face: CardFace

## Seconds for a card to rise or settle on hover.
const LIFT_TIME := 0.12

const TILT_SHADER := preload("res://art/fx/card_tilt.gdshader")


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	set_process(false)
	_face = CardFace.new(self)
	_update_size()


func _ready() -> void:
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))


func set_card(new_card: CardData) -> void:
	card = new_card
	class_id = palette_id(new_card)
	# Hovering explains every mechanic on the card (callers that want the name and text too overwrite this).
	tooltip_text = CardGlossary.text(new_card)
	# A Fading card reads as half there: slightly see-through, with a dashed edge (see CardFace.draw).
	self_modulate = Color(1, 1, 1, FADING_ALPHA) if new_card != null and new_card.fading else Color.WHITE
	queue_redraw()


func set_state(new_state: State, new_note := "") -> void:
	state = new_state
	note = new_note
	_chase_lift()
	queue_redraw()


## True when a click on this card would emit `pressed`.
func is_clickable() -> bool:
	return clickable and state != State.UNPLAYABLE


## Every CardView at or under `node`, in tree order (lets screens and tests find the cards).
static func find_all(node: Node) -> Array[CardView]:
	var out: Array[CardView] = []
	if node is CardView:
		out.append(node)
	for child in node.get_children():
		out.append_array(find_all(child))
	return out


## The palette key for a card: its character when that class has a frame, else neutral.
static func palette_id(c: CardData) -> StringName:
	if is_status_card(c):
		return &"status"
	if c != null and PALETTES.has(c.character) and c.character != &"status":
		return c.character
	return &""


## A status card (Dread, Murmur): Dormant with no effects, so it can only clog the hand.
static func is_status_card(c: CardData) -> bool:
	return c != null and c.dormant and c.effects.is_empty()



func _update_size() -> void:
	custom_minimum_size = Vector2(BASE.x, BASE.y + LIFT) * view_scale
	size = custom_minimum_size


func _update_mouse_filter() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if clickable else (Control.MOUSE_FILTER_PASS if auto_hover else Control.MOUSE_FILTER_IGNORE)


## Like a Button, a click counts when the mouse is released over the card. A draggable card that
## the pointer moves DRAG_THRESHOLD away from while held becomes a drag instead: the owner gets
## drag_started / drag_moved and then drag_ended (or drag_cancelled), and `pressed` does not fire.
func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.button_index == MOUSE_BUTTON_LEFT and click.pressed:
		_pressing = draggable and is_clickable()
		_press_global = click.global_position
		return
	if click != null and click.button_index == MOUSE_BUTTON_RIGHT and click.pressed and _pressing:
		cancel_drag()
		return
	var motion := event as InputEventMouseMotion
	if motion != null and _pressing:
		if not _dragging and motion.global_position.distance_to(_press_global) >= DRAG_THRESHOLD:
			_dragging = true
			drag_started.emit()
		if _dragging:
			drag_moved.emit(motion.global_position)
		return
	if click != null and click.button_index == MOUSE_BUTTON_LEFT and not click.pressed:
		var was_dragging := _dragging
		_pressing = false
		_dragging = false
		if was_dragging:
			accept_event()
			drag_ended.emit(click.global_position)
		elif is_clickable() and Rect2(Vector2.ZERO, size).has_point(click.position):
			accept_event()
			pressed.emit()


## True while a drag that started on this card is in progress.
func is_dragging() -> bool:
	return _dragging


## Abandons a press or drag in progress (Esc, right-click): the release that follows does nothing.
func cancel_drag() -> void:
	var was_dragging := _dragging
	_pressing = false
	_dragging = false
	if was_dragging:
		drag_cancelled.emit()


## Sets the hover look directly (the owner uses this to restore it after rebuilding a view under the pointer).
func set_hovered(inside: bool) -> void:
	_on_hover(inside)


## The card tooltip as a small, wrapped text block (see CardTooltip).
func _make_custom_tooltip(for_text: String) -> Object:
	return CardTooltip.make(for_text)


func _on_hover(inside: bool) -> void:
	if auto_hover:
		_hovered = inside
		# A hovered card in an overlapping hand comes to the front.
		z_index = 1 if inside else 0
		_chase_lift()
		hover_changed.emit(inside)
		if inside:
			set_process(true)
		queue_redraw()


## Eases the card toward the pointer while hovered (perspective tilt with a moving sheen, see
## art/fx/card_tilt.gdshader) and back to flat afterwards; stops processing once it is flat again.
func _process(delta: float) -> void:
	var lift_goal := 1.0 if _raised() else 0.0
	if _lift != lift_goal:
		_lift = move_toward(_lift, lift_goal, delta / LIFT_TIME)
		queue_redraw()
	var goal := Vector2.ZERO
	if _hovered and not Motion.reduced and state != State.UNPLAYABLE and size.x > 0.0 and size.y > 0.0:
		var mouse := get_local_mouse_position()
		if Rect2(Vector2.ZERO, size).has_point(mouse):
			goal = ((mouse / size) - Vector2(0.5, 0.5)) * 2.0
	_tilt = _tilt.lerp(goal, 1.0 - exp(-14.0 * delta))
	if goal == Vector2.ZERO and _tilt.length() < 0.01 and _lift == lift_goal:
		_tilt = Vector2.ZERO
		material = null
		set_process(false)
		return
	if material == null:
		var mat := ShaderMaterial.new()
		mat.shader = TILT_SHADER
		material = mat
	var sm := material as ShaderMaterial
	sm.set_shader_parameter("tilt", _tilt)
	sm.set_shader_parameter("size_px", size)


## Starts easing the lift toward its goal (snaps when the card does not hover by itself).
func _chase_lift() -> void:
	var goal := 1.0 if _raised() else 0.0
	if Motion.reduced or not auto_hover or not is_inside_tree():
		_lift = goal
	elif _lift != goal:
		set_process(true)


func _raised() -> bool:
	return state == State.HOVER or state == State.SELECTED or (_hovered and state == State.NORMAL)


## The face is drawn by CardFace, lifted by the current hover ease.
func _draw() -> void:
	_face.draw(_lift, _raised())


# --- what the face shows ---------------------------------------------------------------

## Gold of a Remembered card's title: bright on a dark banner, a deep gold on a light one.
const REMEMBERED_TITLE := Color("#F2CC5B")
const REMEMBERED_TITLE_ON_PAPER := Color("#7A5500")


## The card name's colour: the palette's banner ink, or gold for a Remembered card.
func title_color(p: Dictionary) -> Color:
	if card == null or not card.is_remembered:
		return p.banner_ink
	return REMEMBERED_TITLE if (p.banner as Color).get_luminance() < 0.5 else REMEMBERED_TITLE_ON_PAPER


## The text of the keyword line ("FORGOTTEN · SURGE"), empty for a card without keywords.
func keyword_text() -> String:
	return " · ".join(card.keyword_lines()).to_upper() if card != null else ""


## What the cost stamp shows: X for a Surge card, else the energy cost.
func cost_text() -> String:
	return "X" if card.surge else str(card.cost)


## Corner points of the delta triangle centred on `center` with half-size `half` (empty for delta 0): the apex is
## above the base for a raised number and below it for a lowered one.
static func delta_marker_points(delta: int, center: Vector2, half: float) -> PackedVector2Array:
	if delta == 0:
		return PackedVector2Array()
	var dir := -1.0 if delta > 0 else 1.0
	return PackedVector2Array([
		center + Vector2(0.0, dir * half),
		center + Vector2(half, -dir * half * 0.7),
		center + Vector2(-half, -dir * half * 0.7),
	])


## The effect lines of the card face as {text, delta}: delta is +1 when the player's statuses raise the
## printed Deal or Block number, -1 when they lower it and 0 otherwise (text is then the printed text).
## Only plain Deal and Block lines change: the number shown is the effective one, from the same engine
## functions Combat uses (Malice and Shaken for Deal, Ward and Frayed for Block). The target's Expose is
## per target, so it stays in the preview line.
func body_lines() -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	for effect in card.effects:
		var effective := live_amount(effect)
		if effective < 0 or effective == effect.amount:
			lines.append({"text": effect.describe(), "delta": 0})
			continue
		var shown := effect.duplicate() as CardEffect
		shown.amount = effective
		lines.append({"text": shown.describe(), "delta": 1 if effective > effect.amount else -1})
	# An Oath's lasting effect: its trigger on one line, what it does on the next.
	if card.oath and not card.oath_effects.is_empty():
		var sworn: PackedStringArray = []
		for effect in card.oath_effects:
			sworn.append(effect.describe())
		lines.append({"text": "%s: %s" % [card.oath_trigger_text(), ", ".join(sworn)], "delta": 0})
	if not card.discard_effects.is_empty():
		var thrown: PackedStringArray = []
		for effect in card.discard_effects:
			thrown.append(effect.describe())
		lines.append({"text": "When discarded: %s" % ", ".join(thrown), "delta": 0})
	return lines


## The effective number of a plain Deal or Block effect for `live` (one hit, or the Block gained), or -1
## when there is no live number: no fight, another kind, or Block that scales with energy spent.
func live_amount(effect: CardEffect) -> int:
	if live == null or effect.amount <= 0 or card.dormant:
		return -1
	match effect.kind:
		CardEffect.Kind.DAMAGE:
			return Combatant.hit_damage(effect.amount, live, _neutral_defender())
		CardEffect.Kind.BLOCK:
			return -1 if effect.per_energy else live.block_from_card(effect.amount)
	return -1


## A defender with no statuses, so only the attacker's side shows on a card face.
static func _neutral_defender() -> Combatant:
	if _neutral == null:
		_neutral = Combatant.new("Neutral", 1)
	return _neutral


## Colour of a rarity gem on the name banner: none for Common, steel blue for Uncommon, gold for Rare.
const RARITY_GEM_COLORS := {CardData.Rarity.UNCOMMON: Color("#7FA8D8"), CardData.Rarity.RARE: MenuStyle.AMBER}


static func rarity_gem_color(rarity: int) -> Color:
	return RARITY_GEM_COLORS.get(rarity, Color(0, 0, 0, 0))


## Colour of an effect kind's icon and chips.
static func kind_color(kind: int) -> Color:
	return CardIcons.kind_color(kind)
