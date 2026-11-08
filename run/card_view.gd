class_name CardView
extends Control
## A keepsake card framed in worn paper and stitched cloth, drawn entirely in code.
## One layout for every card; the class (CardData.character) picks the palette, the frame
## decoration and the corner emblem, the effect kinds pick the icon. Neutral cards are plain
## faded bone paper. Drawn in a fixed BASE-sized space and scaled by view_scale.

enum State { NORMAL, HOVER, SELECTED, UNPLAYABLE }

const BASE := Vector2(136, 190)
## Extra height so a raised (hover/selected) card has room to lift without moving the layout.
const LIFT := 6.0
## Height of the keyword line at the top of the effect text.
const KEYWORD_H := 11.0
## Opacity of a Fading card.
const FADING_ALPHA := 0.8
## Keyword line colours: on dark class stock and on the pale neutral paper.
const KEYWORD_INK := Color("#e8b773")
const KEYWORD_INK_PAPER := Color("#8a4a14")
const BACKDROP := Color(0.05, 0.05, 0.08)
const BADGE := Color("#e8b773")
const BADGE_BAD := Color(0.78, 0.18, 0.20)
const WARN := Color("#e8b773")
const HP_RED := Color("#a8323a")
const SELECT_GOLD := MenuStyle.AMBER
## Palette tokens per class. Empty id is neutral keepsake paper.
const PALETTES := {
	&"": {
		"label": "KEEPSAKE", "stock": Color("#D7D0BC"), "frame": Color("#526979"),
		"ink": Color("#171D28"), "window": Color("#171D28"), "banner": Color("#BBB7A8"),
		"banner_ink": Color("#171D28"), "accent": Color("#526979"), "glyph": Color("#D7D0BC"),
	},
	&"deserter": {
		"label": "DESERTER", "stock": Color("#29313A"), "frame": Color("#A66A50"),
		"ink": Color("#E8E1D0"), "window": Color("#171D28"), "banner": Color("#49545D"),
		"banner_ink": Color("#F0EBDD"), "accent": Color("#A66A50"), "glyph": Color("#171D28"),
	},
	&"thief": {
		"label": "THIEF", "stock": Color("#253D3D"), "frame": Color("#78A99B"),
		"ink": Color("#E8E1D0"), "window": Color("#171D28"), "banner": Color("#41615B"),
		"banner_ink": Color("#F0EBDD"), "accent": Color("#78A99B"), "glyph": Color("#171D28"),
	},
	&"medium": {
		"label": "MEDIUM", "stock": Color("#342F42"), "frame": Color("#9A89AD"),
		"ink": Color("#E8E1D0"), "window": Color("#171D28"), "banner": Color("#5C526B"),
		"banner_ink": Color("#F0EBDD"), "accent": Color("#9A89AD"), "glyph": Color("#171D28"),
	},
	# The Stray: dark cobalt blue. Placeholder colours until the class art is designed (docs/CLASSES_PLAN.md).
	&"stray": {
		"label": "STRAY", "stock": Color("#1F2A3E"), "frame": Color("#6D87B3"),
		"ink": Color("#E8E1D0"), "window": Color("#171D28"), "banner": Color("#3B4F78"),
		"banner_ink": Color("#F0EBDD"), "accent": Color("#6D87B3"), "glyph": Color("#171D28"),
	},
	# Status cards (Dread, Murmur: what enemies shuffle in): a sickly grey-green, so they read as junk.
	&"status": {
		"label": "STATUS", "stock": Color("#333D31"), "frame": Color("#6F8A5C"),
		"ink": Color("#C4CFB6"), "window": Color("#161C15"), "banner": Color("#4A5845"),
		"banner_ink": Color("#DCE5CF"), "accent": Color("#8FAA73"), "glyph": Color("#161C15"),
	},
}

## Primary icon = the first of these that the card has (scaled damage reads before plain damage).
const ICON_PRIORITY: Array[CardEffect.Kind] = [
	CardEffect.Kind.DAMAGE_PER_BLOCK, CardEffect.Kind.DAMAGE_IF_BLOCK, CardEffect.Kind.DAMAGE_PER_PLAY,
	CardEffect.Kind.DAMAGE_PER_HAUNT, CardEffect.Kind.DAMAGE_PER_FORGOTTEN, CardEffect.Kind.DAMAGE_PER_SCENT, CardEffect.Kind.DAMAGE, CardEffect.Kind.HAUNT, CardEffect.Kind.BLOCK,
	CardEffect.Kind.THORNS, CardEffect.Kind.EXPOSE, CardEffect.Kind.HOLD, CardEffect.Kind.GAIN_ENERGY,
	CardEffect.Kind.DRAW, CardEffect.Kind.HEAL_PER_HAUNTED, CardEffect.Kind.LOSE_HP,
	CardEffect.Kind.SHAKEN, CardEffect.Kind.FRAYED, CardEffect.Kind.MALICE, CardEffect.Kind.WARD,
	CardEffect.Kind.GLIMPSE, CardEffect.Kind.ADD_CARD, CardEffect.Kind.RECALL, CardEffect.Kind.SCENT,
]
## Every kind that _draw_icon has a glyph for (a test walks CardEffect.Kind and fails if one is missing, so a
## new kind cannot silently draw nothing).
const ICON_KINDS: Array[CardEffect.Kind] = [
	CardEffect.Kind.DAMAGE, CardEffect.Kind.BLOCK, CardEffect.Kind.DRAW, CardEffect.Kind.EXPOSE, CardEffect.Kind.HOLD,
	CardEffect.Kind.DAMAGE_PER_BLOCK, CardEffect.Kind.DAMAGE_IF_BLOCK, CardEffect.Kind.THORNS, CardEffect.Kind.GAIN_ENERGY,
	CardEffect.Kind.DAMAGE_PER_PLAY, CardEffect.Kind.HAUNT, CardEffect.Kind.LOSE_HP, CardEffect.Kind.HEAL_PER_HAUNTED,
	CardEffect.Kind.DAMAGE_PER_HAUNT, CardEffect.Kind.SHAKEN, CardEffect.Kind.FRAYED, CardEffect.Kind.MALICE, CardEffect.Kind.WARD,
	CardEffect.Kind.GLIMPSE, CardEffect.Kind.ADD_CARD, CardEffect.Kind.RECALL, CardEffect.Kind.DAMAGE_PER_FORGOTTEN,
	CardEffect.Kind.SCENT, CardEffect.Kind.DAMAGE_PER_SCENT,
]
const KIND_COLORS := {
	CardEffect.Kind.DAMAGE: Color("#d96b65"), CardEffect.Kind.BLOCK: Color("#83b4cf"),
	CardEffect.Kind.DRAW: Color(0.88, 0.88, 0.92), CardEffect.Kind.EXPOSE: Color(0.96, 0.80, 0.35),
	CardEffect.Kind.HOLD: Color(0.40, 0.82, 0.80), CardEffect.Kind.THORNS: Color(0.58, 0.86, 0.42),
	CardEffect.Kind.GAIN_ENERGY: Color(1.0, 0.88, 0.30), CardEffect.Kind.HAUNT: Color(0.76, 0.70, 1.0),
	CardEffect.Kind.LOSE_HP: Color(0.92, 0.26, 0.32), CardEffect.Kind.HEAL_PER_HAUNTED: Color(0.96, 0.52, 0.62),
	CardEffect.Kind.SHAKEN: Color(0.97, 0.62, 0.30), CardEffect.Kind.FRAYED: Color(0.78, 0.70, 0.55),
	CardEffect.Kind.MALICE: Color(0.84, 0.45, 0.95), CardEffect.Kind.WARD: Color(0.46, 0.62, 1.0),
	CardEffect.Kind.GLIMPSE: Color(0.55, 0.85, 0.95), CardEffect.Kind.ADD_CARD: Color(0.72, 0.84, 0.60), CardEffect.Kind.RECALL: Color(0.90, 0.78, 0.50),
	CardEffect.Kind.DAMAGE_PER_FORGOTTEN: Color("#d96b65"),
	CardEffect.Kind.SCENT: Color(0.62, 0.74, 0.92), CardEffect.Kind.DAMAGE_PER_SCENT: Color("#d96b65"),
}
## Tint of a debuff (a negative Malice or Ward) on a status pill.
const STATUS_NEGATIVE := Color(0.95, 0.35, 0.35)
## Live card numbers: green when a status raises the printed number, red when it lowers it.
const NUMBER_RAISED := Color("#5fd16b")
const NUMBER_LOWERED := Color("#ff6a5e")
const NUMBER_RAISED_PAPER := Color("#1f7a2c")
const NUMBER_LOWERED_PAPER := Color("#b3261e")
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
## 0 (resting) to 1 (raised); eases over LIFT_TIME unless reduced_motion.
var _lift := 0.0
var _font: Font = ThemeDB.fallback_font

## Skips the hover-lift easing (cards snap) and the confirm pulse when true. No UI sets it yet.
static var reduced_motion := false
## Seconds for a card to rise or settle on hover.
const LIFT_TIME := 0.12

const TILT_SHADER := preload("res://art/fx/card_tilt.gdshader")


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	set_process(false)
	_update_size()


func _ready() -> void:
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))


func set_card(new_card: CardData) -> void:
	card = new_card
	class_id = palette_id(new_card)
	# Hovering explains every mechanic on the card (callers that want the name and text too overwrite this).
	tooltip_text = CardGlossary.text(new_card)
	# A Fading card reads as half there: slightly see-through, with a dashed edge (see _draw).
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


## The effects whose kinds the icons show: the card's own, plus an Oath's lasting effects.
static func icon_effects(c: CardData) -> Array[CardEffect]:
	if not c.oath or c.oath_effects.is_empty():
		return c.effects
	var all: Array[CardEffect] = []
	all.append_array(c.oath_effects)
	all.append_array(c.effects)
	return all


## The effect kind whose icon leads the card, or -1 for a card with no effects.
static func primary_kind(c: CardData) -> int:
	for kind in ICON_PRIORITY:
		for effect in icon_effects(c):
			if effect.kind == kind:
				return kind
	return -1


## Ids that get the fist icon (shoves and body blows), the one per-id exception to the rules below.
const FIST_IDS: Array[StringName] = [&"shove", &"shoulder_charge"]
const HEAVY_DAMAGE := 12
const LIGHT_DAMAGE := 4

## Which weapon icon a card's plain damage shows, from its own data: class (thief needle,
## medium bone), target (all enemies sweep), id (fist), magnitude (axe 12+, dagger up to 4)
## and cost (a free light hit is a flurry); otherwise a sword. Empty when the card has no DAMAGE
## effect, or for kinds that draw their own composite icon (see docs/CARD_ART_DESIGN.md).
static func icon_variant(c: CardData) -> StringName:
	if c == null:
		return &""
	if primary_kind(c) == CardEffect.Kind.DAMAGE_PER_BLOCK:
		return &"hammer"
	var total := 0
	for effect in icon_effects(c):
		if effect.kind == CardEffect.Kind.DAMAGE:
			total += effect.amount
	if total <= 0 or primary_kind(c) != CardEffect.Kind.DAMAGE:
		return &""
	if c.character == &"thief":
		return &"needle"
	if c.character == &"medium":
		return &"bone"
	if c.target_mode == CardData.TargetMode.ALL_ENEMIES:
		return &"sweep"
	if c.id in FIST_IDS:
		return &"fist"
	if total >= HEAVY_DAMAGE:
		return &"axe"
	if total <= LIGHT_DAMAGE:
		return &"flurry" if c.cost == 0 else &"dagger"
	return &"sword"


## Up to three further kinds shown as small glyphs (the primary and its composite parts are skipped).
static func secondary_kinds(c: CardData) -> Array[int]:
	var primary := primary_kind(c)
	var out: Array[int] = []
	for kind in ICON_PRIORITY:
		if kind == primary or out.size() >= 3:
			continue
		if kind == CardEffect.Kind.DAMAGE and primary in [CardEffect.Kind.DAMAGE_PER_BLOCK, CardEffect.Kind.DAMAGE_IF_BLOCK, CardEffect.Kind.DAMAGE_PER_PLAY, CardEffect.Kind.DAMAGE_PER_HAUNT, CardEffect.Kind.DAMAGE_PER_FORGOTTEN, CardEffect.Kind.DAMAGE_PER_SCENT]:
			continue
		for effect in icon_effects(c):
			if effect.kind == kind:
				out.append(kind)
				break
	return out


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


## Tooltip width and text size: a narrow block of small wrapped lines, not one line across the screen.
const TOOLTIP_WIDTH := 230.0
const TOOLTIP_FONT_SIZE := 11


## The card tooltip as a small, wrapped text block (Godot's default tooltip never wraps).
func _make_custom_tooltip(for_text: String) -> Object:
	var label := RichTextLabel.new()
	label.bbcode_enabled = false
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(TOOLTIP_WIDTH, 0)
	label.add_theme_font_size_override("normal_font_size", TOOLTIP_FONT_SIZE)
	label.text = for_text
	return label


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
	if _hovered and state != State.UNPLAYABLE and size.x > 0.0 and size.y > 0.0:
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
	if reduced_motion or not auto_hover or not is_inside_tree():
		_lift = goal
	elif _lift != goal:
		set_process(true)


func _raised() -> bool:
	return state == State.HOVER or state == State.SELECTED or (_hovered and state == State.NORMAL)


# --- drawing ---------------------------------------------------------------------------

func _draw() -> void:
	if card == null:
		return
	# A Dormant card is always muted (it can never be played), even where its state is NORMAL.
	var muted := state == State.UNPLAYABLE or card.dormant
	var p := _palette(class_id, muted, not muted and _raised())
	var top := LIFT * (1.0 - _lift)
	draw_set_transform(Vector2(0, top * view_scale), 0.0, Vector2(view_scale, view_scale))
	var stock: Color = p.stock
	var ink: Color = p.ink
	var frame: Color = p.frame

	if state == State.SELECTED:
		_box(Rect2(-3, -3, BASE.x + 6, BASE.y + 6), Color(0, 0, 0, 0), 11, 3, SELECT_GOLD)
	elif _raised():
		_box(Rect2(-2, -2, BASE.x + 4, BASE.y + 4), Color(0, 0, 0, 0), 10, 2, Color(frame, 0.7))
	_box(Rect2(Vector2.ZERO, BASE), frame, 8)
	_box(Rect2(4, 4, BASE.x - 8, BASE.y - 8), stock, 5)
	_draw_class_frame(p)
	if card.fading:
		_dashed_rect(Rect2(1.5, 1.5, BASE.x - 3, BASE.y - 3), Color(1, 1, 1, 0.75))
	if card.oath:
		# An Oath wears a gold double rule round the stock, so it reads as a vow that stays.
		_box(Rect2(2, 2, BASE.x - 4, BASE.y - 4), Color(0, 0, 0, 0), 7, 2, SELECT_GOLD)
		_box(Rect2(5.5, 5.5, BASE.x - 11, BASE.y - 11), Color(0, 0, 0, 0), 4, 1, Color(SELECT_GOLD, 0.6))

	# Header: price stamp, class label, emblem.
	var header := Rect2(8, 6, BASE.x - 16, 24)
	_box(header, stock.lerp(Color.BLACK if class_id != &"" else frame, 0.22), 4)
	_draw_header_decor(header, p)
	_draw_cost(Vector2(20, 18), muted)
	_draw_emblem(Vector2(BASE.x - 20, 18), p)
	_text(String(p.label), Rect2(36, 6, BASE.x - 72, 24), 10, ink, true)

	# Name banner; a long name shrinks (down to 8 px) to fit.
	var banner := Rect2(6, 33, BASE.x - 12, 20)
	_box(banner, p.banner, 3)
	# A rarity gem sits at the right end of the banner, so the name leaves room for it.
	var name_rect := Rect2(banner.position, Vector2(banner.size.x - (16.0 if RARITY_GEM_COLORS.has(card.rarity) else 0.0), banner.size.y))
	_text(card.display_name, name_rect, _fit_size(card.display_name, name_rect.size.x - 8, 13, 8), title_color(p), true)
	_draw_rarity_gem(Vector2(BASE.x - 14, 43))
	_draw_hotkey(Vector2(9, 30))

	# Art window with the procedural icon.
	var win := Rect2(10, 57, BASE.x - 20, 50)
	_box(win, p.window, 4, 1, Color(frame, 0.8))
	var art := PaintedArt.card_texture(card.id)
	if art != null:
		_draw_painted_window(art, win, p, muted)
	else:
		_draw_window_motif(win, p)
		_draw_card_icons(win, p)
	if card.anchor:
		_draw_anchor(Vector2(win.end.x - 10, win.position.y + 10))

	# Effect text.
	var body := Rect2(9, 110, BASE.x - 18, 56)
	if preview != "":
		# The preview takes the bottom two lines of the text area; the effect text gets the rest.
		var line_h := ceilf(_font.get_multiline_string_size(preview, HORIZONTAL_ALIGNMENT_CENTER, body.size.x - 6, _preview_size(body.size.x - 6)).y) + 4.0
		var line := Rect2(body.position.x, body.end.y - line_h, body.size.x, line_h)
		body.size.y -= line_h + 2
		_draw_preview(line)
	_draw_body(body, ink)

	# A continuous paper fold separates the rules from the target strip.
	draw_line(Vector2(9, 167), Vector2(BASE.x - 9, 167), Color(ink, 0.30), 1.0)
	draw_line(Vector2(9, 168), Vector2(BASE.x - 9, 168), Color(stock.lightened(0.15), 0.45), 1.0)
	_draw_strip(Rect2(8, 170, BASE.x - 16, 16), p)
	if discard_marked:
		_draw_discard_mark()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The class palette adjusted for muted / raised, built once per combination (not per redraw).
static var _derived_palettes: Dictionary = {}


static func _palette(id: StringName, muted: bool, raised: bool) -> Dictionary:
	if not muted and not raised:
		return PALETTES[id]
	var key := "%s|%d" % [id, 1 if muted else 2]
	if not _derived_palettes.has(key):
		var p: Dictionary = PALETTES[id].duplicate()
		if muted:
			for k in ["stock", "frame", "banner", "window", "accent"]:
				p[k] = _mute(p[k])
		else:
			p["frame"] = (p["frame"] as Color).lightened(0.15)
		_derived_palettes[key] = p
	return _derived_palettes[key]


static func _mute(c: Color) -> Color:
	var g := c.get_luminance()
	return Color(g, g, g).lerp(c, 0.45) * Color(0.88, 0.88, 0.88, 1.0)


func _box(rect: Rect2, fill: Color, radius: int, border := 0, border_color := Color.WHITE) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(border)
	sb.border_color = border_color
	sb.anti_aliasing = true
	draw_style_box(sb, rect)
	if fill.a >= 0.5 and rect.size.x > 30.0 and rect.size.y > 15.0:
		TactileArt.draw_grain(self, rect.grow(-3.0), 0.12)


## Draws text inside a rectangle: centered both ways when `centered`, else left aligned and
## vertically centered. Baseline math keeps small caps text visually centered in its band.
func _text(txt: String, rect: Rect2, size: int, col: Color, centered := false) -> void:
	var y := rect.position.y + rect.size.y / 2.0 + (_font.get_ascent(size) - _font.get_descent(size)) / 2.0
	var align := HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	draw_string(_font, Vector2(rect.position.x, y), txt, align, rect.size.x, size, col)


## Largest font size from max_size down to min_size at which txt fits in `width` (min_size if none).
func _fit_size(txt: String, width: float, max_size: int, min_size: int) -> int:
	var size := max_size
	while size > min_size and _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
		size -= 1
	return size


## Dims the card and stamps a red DISCARD band across it (the end-of-turn discard step).
func _draw_discard_mark() -> void:
	_box(Rect2(Vector2.ZERO, BASE), Color(0.02, 0.02, 0.04, 0.62), 8)
	var band := Rect2(0, 78, BASE.x, 34)
	_box(band, Color(0.62, 0.1, 0.14, 0.95), 2, 2, Color(1.0, 0.82, 0.8, 0.9))
	_text("DISCARD", band, 18, Color.WHITE, true)


## A small dark badge with the card's hotkey number (10 shows as 0), tucked under the cost stamp.
func _draw_hotkey(c: Vector2) -> void:
	if hotkey <= 0:
		return
	draw_circle(c, 7.5, Color(0, 0, 0, 0.85))
	draw_arc(c, 6.5, 0, TAU, 20, Color(BADGE, 0.9), 1.0, true)
	_text(str(hotkey % 10),Rect2(c - Vector2(7, 7), Vector2(14, 14)), 10, Color.WHITE, true)


## Font size for the preview: 10 px, shrinking (to 8) only when it would need more than two lines.
func _preview_size(width: float) -> int:
	var size := 11
	while size > 9 and _font.get_multiline_string_size(preview, HORIZONTAL_ALIGNMENT_CENTER, width, size).y > 2.0 * _font.get_height(size):
		size -= 1
	return size


## The preview text in a dark pill, wrapped onto at most two lines.
func _draw_preview(rect: Rect2) -> void:
	_box(rect, Color(0.07, 0.06, 0.06, 0.88), 3)
	var inner := rect.grow_individual(-3, 0, -3, 0)
	var size := _preview_size(inner.size.x)
	var h := _font.get_multiline_string_size(preview, HORIZONTAL_ALIGNMENT_CENTER, inner.size.x, size).y
	var y := rect.position.y + (rect.size.y - h) / 2.0 + _font.get_ascent(size)
	draw_multiline_string(_font, Vector2(inner.position.x, y), preview, HORIZONTAL_ALIGNMENT_CENTER, inner.size.x, size, -1, WARN)


func _draw_cost(c: Vector2, muted: bool) -> void:
	var col := BADGE_BAD if muted else BADGE
	draw_circle(c, 14.5, Color(0, 0, 0, 0.55))
	draw_circle(c, 13.5, col)
	draw_arc(c, 10.5, 0, TAU, 28, Color(0, 0, 0, 0.35), 1.0, true)
	var ink := Color.WHITE if muted else Color(0.14, 0.1, 0.04)
	# A Surge card spends all the energy there is, so its stamp shows X, not a number.
	_text(cost_text(), Rect2(c - Vector2(13, 13), Vector2(26, 26)), 17, ink, true)


# --- class frames, emblems, motifs ------------------------------------------------------

func _draw_class_frame(p: Dictionary) -> void:
	var accent: Color = p.accent
	# Quiet fibers stay in the outer margin, away from the live rules and art.
	for y in range(13, int(BASE.y) - 10, 13):
		var length := 1.0 + float(y % 3)
		draw_line(Vector2(4.5, y), Vector2(4.5 + length, y + 1), Color(p.ink, 0.12), 1.0)
		draw_line(Vector2(BASE.x - 4.5, y + 3), Vector2(BASE.x - 4.5 - length, y + 4), Color(p.ink, 0.12), 1.0)
	match class_id:
		&"deserter":
			# Small repaired cloth corners echo the patched greatcoat.
			for pt in [Vector2(3, 3), Vector2(BASE.x - 3, 3), Vector2(3, BASE.y - 3), Vector2(BASE.x - 3, BASE.y - 3)]:
				draw_line(pt + Vector2(-2, -1), pt + Vector2(2, 1), Color(p.ink, 0.65), 1.0)
				draw_line(pt + Vector2(-2, 1), pt + Vector2(2, -1), Color(p.ink, 0.65), 1.0)
		&"thief":
			# Sea-glass thread stitched round the stock.
			var r := Rect2(7, 7, BASE.x - 14, BASE.y - 14)
			_dashed_rect(r, Color(accent, 0.55))
		&"medium":
			# A thin bone double line.
			_box(Rect2(6, 6, BASE.x - 12, BASE.y - 12), Color(0, 0, 0, 0), 4, 1, Color(accent, 0.4))
		&"status":
			# Torn, mildewed edge: a ragged dashed border and a few creeping blotches in the corners.
			_dashed_rect(Rect2(6, 6, BASE.x - 12, BASE.y - 12), Color(accent, 0.6))
			for pt in [Vector2(9, 9), Vector2(BASE.x - 12, BASE.y - 14), Vector2(BASE.x - 14, 12)]:
				draw_circle(pt + Vector2(2, 2), 2.4, Color(accent, 0.22))
		_:
			_box(Rect2(6, 6, BASE.x - 12, BASE.y - 12), Color(0, 0, 0, 0), 4, 1, Color(accent, 0.25))


func _dashed_rect(r: Rect2, col: Color) -> void:
	var step := 6.0
	var x := r.position.x + 4
	while x < r.end.x - 4:
		draw_line(Vector2(x, r.position.y), Vector2(minf(x + 3, r.end.x - 4), r.position.y), col, 1.0)
		draw_line(Vector2(x, r.end.y), Vector2(minf(x + 3, r.end.x - 4), r.end.y), col, 1.0)
		x += step
	var y := r.position.y + 4
	while y < r.end.y - 4:
		draw_line(Vector2(r.position.x, y), Vector2(r.position.x, minf(y + 3, r.end.y - 4)), col, 1.0)
		draw_line(Vector2(r.end.x, y), Vector2(r.end.x, minf(y + 3, r.end.y - 4)), col, 1.0)
		y += step


func _draw_header_decor(header: Rect2, p: Dictionary) -> void:
	var accent: Color = p.accent
	match class_id:
		&"deserter":
			# A short hand-sewn repair, rather than industrial hazard striping.
			draw_line(Vector2(38, header.end.y - 3), Vector2(98, header.end.y - 3), Color(accent, 0.55), 1.0)
			for x in range(42, 98, 8):
				draw_line(Vector2(x, header.end.y - 5), Vector2(x + 2, header.end.y - 1), Color(p.ink, 0.55), 1.0)
		&"thief":
			draw_line(Vector2(header.position.x + 4, header.end.y - 3), Vector2(header.end.x - 4, header.end.y - 3), Color(accent, 0.7), 1.0)
			for i in 6:
				draw_line(Vector2(header.position.x + 40 + i * 9, header.end.y - 3), Vector2(header.position.x + 44 + i * 9, header.end.y - 1), Color(accent, 0.7), 1.0)
		&"medium":
			for pt in [Vector2(42, 21), Vector2(94, 21), Vector2(60, 25), Vector2(78, 25)]:
				draw_circle(pt + Vector2(0, 0), 0.9, Color(accent, 0.7))
		&"status":
			# A row of drips along the header's lower edge.
			for x in range(42, 98, 9):
				draw_line(Vector2(x, header.end.y - 4), Vector2(x, header.end.y - 1 + float(x % 3)), Color(accent, 0.7), 1.6)
		_:
			draw_line(Vector2(header.position.x + 4, header.end.y - 3), Vector2(header.end.x - 4, header.end.y - 3), Color(p.ink, 0.25), 1.0)


func _draw_emblem(c: Vector2, p: Dictionary) -> void:
	var frame: Color = p.frame
	var glyph: Color = p.glyph
	draw_circle(c, 13.5, Color(0, 0, 0, 0.5))
	draw_circle(c, 12.5, frame)
	match class_id:
		&"deserter":
			# The soldier's squared forearm guard.
			draw_colored_polygon(PackedVector2Array([c + Vector2(-6, -7), c + Vector2(6, -7), c + Vector2(5, 5), c + Vector2(0, 8), c + Vector2(-5, 5)]), glyph)
			draw_line(c + Vector2(-3, -2), c + Vector2(3, -2), frame, 1.2)
			draw_line(c + Vector2(-3, 2), c + Vector2(3, 2), frame, 1.2)
		&"thief":
			# A keyhole.
			draw_circle(c + Vector2(0, -2.5), 4.0, glyph)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-1.8, 0), c + Vector2(1.8, 0), c + Vector2(3.8, 7.5), c + Vector2(-3.8, 7.5)]), glyph)
		&"status":
			# A sickly eye, half shut.
			draw_arc(c + Vector2(0, 1), 6.5, PI * 1.12, PI * 1.88, 12, glyph, 1.6, true)
			draw_arc(c + Vector2(0, -1), 6.5, PI * 0.12, PI * 0.88, 12, glyph, 1.6, true)
			draw_circle(c, 2.2, glyph)
		&"medium":
			# Cloudy-glass orb, matching the Medium's current keepsake.
			draw_circle(c, 7.0, glyph)
			draw_arc(c, 5.1, PI * 1.1, PI * 1.7, 14, Color(p.ink, 0.8), 1.3, true)
			draw_arc(c + Vector2(0, 1), 3.5, 0.2, PI, 12, Color(frame, 0.8), 1.5, true)
		_:
			# A pressed leaf, preserving a small ordinary memory.
			draw_colored_polygon(PackedVector2Array([c + Vector2(-6, 5), c + Vector2(-5, -2), c + Vector2(1, -7), c + Vector2(6, -6), c + Vector2(5, 1), c + Vector2(-1, 6)]), glyph)
			draw_line(c + Vector2(-6, 7), c + Vector2(4, -5), frame, 1.2)


func _draw_window_motif(win: Rect2, p: Dictionary) -> void:
	var accent: Color = p.accent
	var c := win.get_center()
	match class_id:
		&"deserter":
			var x := win.position.x - 40
			while x < win.end.x:
				var a := Vector2(maxf(x, win.position.x), win.end.y)
				var b := Vector2(minf(x + 50, win.end.x), win.position.y)
				if x < win.position.x:
					a = Vector2(win.position.x, win.end.y - (win.position.x - x))
				if x + 50 > win.end.x:
					b = Vector2(win.end.x, win.position.y + (x + 50 - win.end.x))
				draw_line(a, b, Color(accent, 0.12), 3.0)
				x += 14
		&"thief":
			var y := win.position.y + 6
			while y < win.end.y - 3:
				draw_line(Vector2(win.position.x + 4, y), Vector2(win.end.x - 4, y), Color(accent, 0.10), 1.0)
				y += 6
		&"medium":
			for r in [10.0, 18.0, 26.0]:
				draw_arc(c, r, 0, TAU, 32, Color(accent, 0.12), 1.0, true)
		&"status":
			for r in [8.0, 15.0, 22.0]:
				draw_arc(c, r, 0.4 * r, 0.4 * r + 4.2, 20, Color(accent, 0.18), 1.4, true)
		_:
			draw_arc(c, 18.0, 0, TAU, 32, Color(0.9, 0.86, 0.76, 0.1), 1.0, true)
	if card.target_mode == CardData.TargetMode.ALL_ENEMIES:
		for i in 3:
			var pt := Vector2(win.position.x + 11 + i * 9, win.position.y + 9)
			draw_circle(pt, 2.6, Color(0.92, 0.55, 0.5))
			draw_colored_polygon(PackedVector2Array([pt + Vector2(-3.5, 8), pt + Vector2(3.5, 8), pt + Vector2(0, 3)]), Color(0.92, 0.55, 0.5))


## Painted art fills the window; the effect icons shrink into badges so the card still reads at a glance.
func _draw_painted_window(art: Texture2D, win: Rect2, p: Dictionary, muted: bool) -> void:
	var inner := win.grow(-1.0)
	draw_texture_rect(art, inner, false, Color(0.55, 0.55, 0.55, 1.0) if muted else Color.WHITE)
	_box(win, Color(0, 0, 0, 0), 4, 1, Color(p.frame, 0.8))
	var primary := primary_kind(card)
	var badge_col: Color = p.window
	var x := win.position.x + 11.0
	var y := win.end.y - 11.0
	if primary >= 0:
		draw_circle(Vector2(x, y), 9.5, Color(badge_col, 0.82))
		draw_arc(Vector2(x, y), 9.5, 0, TAU, 20, Color(1, 1, 1, 0.4), 1.0, true)
		_draw_icon(primary, Vector2(x, y), 5.6, badge_col, icon_variant(card))
	x = win.end.x - 11.0
	for kind in secondary_kinds(card):
		draw_circle(Vector2(x, y), 9.5, Color(badge_col, 0.82))
		draw_arc(Vector2(x, y), 9.5, 0, TAU, 20, Color(1, 1, 1, 0.4), 1.0, true)
		_draw_icon(kind, Vector2(x, y), 5.4, badge_col)
		x -= 21.0


func _draw_card_icons(win: Rect2, p: Dictionary) -> void:
	var primary := primary_kind(card)
	if primary < 0:
		if is_status_card(card):
			_draw_blot(win.get_center(), 15.0, p.accent)
		return
	var window_col: Color = p.window
	var center := win.get_center() + Vector2(0, -1)
	_draw_icon(primary, center, 20.0, window_col, icon_variant(card))
	var secondary := secondary_kinds(card)
	var x := win.end.x - 12.0
	for kind in secondary:
		var pt := Vector2(x, win.end.y - 12.0)
		draw_circle(pt, 10.0, Color(1, 1, 1, 0.14))
		draw_arc(pt, 10.0, 0, TAU, 20, Color(1, 1, 1, 0.45), 1.0, true)
		_draw_icon(kind, pt, 6.5, window_col)
		x -= 23.0


## A status card's art: a ragged inkblot with a few drips.
func _draw_blot(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 18:
		var a := TAU * i / 18.0
		pts.append(c + Vector2.from_angle(a) * r * (0.62 + 0.38 * absf(sin(a * 2.5 + 0.7))))
	draw_colored_polygon(pts, Color(col, 0.55))
	for dx in [-0.5, 0.1, 0.6]:
		draw_line(c + Vector2(dx, 0.6) * r, c + Vector2(dx, 1.15 + dx * 0.3) * r, Color(col, 0.55), 2.0)
	draw_circle(c + Vector2(-0.3, -0.1) * r, r * 0.12, Color(0, 0, 0, 0.6))
	draw_circle(c + Vector2(0.25, -0.1) * r, r * 0.12, Color(0, 0, 0, 0.6))


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


## A small anchor in a dark disc (the Anchor keyword marker).
func _draw_anchor(c: Vector2) -> void:
	draw_circle(c, 9.0, Color(0, 0, 0, 0.7))
	draw_arc(c, 9.0, 0, TAU, 20, Color(KEYWORD_INK, 0.7), 1.0, true)
	var col := KEYWORD_INK
	draw_arc(c + Vector2(0, -5.2), 1.6, 0, TAU, 10, col, 1.2, true)
	draw_line(c + Vector2(0, -3.6), c + Vector2(0, 4.6), col, 1.3)
	draw_line(c + Vector2(-2.6, -1.4), c + Vector2(2.6, -1.4), col, 1.3)
	draw_arc(c + Vector2(0, 0.6), 4.6, 0.25, PI - 0.25, 10, col, 1.3, true)


## The keyword line (for example "FORGOTTEN · SURGE") in a small accent colour.
func _draw_keywords(rect: Rect2, ink: Color) -> void:
	var txt := keyword_text()
	var col := KEYWORD_INK_PAPER if class_id == &"" else KEYWORD_INK
	_text(txt, rect, _fit_size(txt, rect.size.x, 9, 7), col, true)
	draw_line(Vector2(rect.position.x + 14, rect.end.y), Vector2(rect.end.x - 14, rect.end.y), Color(ink, 0.18), 1.0)


func _draw_body(body: Rect2, ink: Color) -> void:
	if keyword_text() != "":
		var band := Rect2(body.position.x, body.position.y, body.size.x, KEYWORD_H)
		_draw_keywords(band, ink)
		body.position.y += KEYWORD_H + 1
		body.size.y -= KEYWORD_H + 1
	var lines := body_lines()
	var txt := _joined(lines)
	var size := 13
	var h := _font.get_multiline_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, body.size.x, size).y
	# An Oath carries two effects (its price and its lasting effect), so its text may shrink further.
	var smallest := 8 if card.oath else 10
	while size > smallest and h > body.size.y:
		size -= 1
		h = _font.get_multiline_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, body.size.x, size).y
	var y := body.position.y + (body.size.y - h) / 2.0 + _font.get_ascent(size)
	for line in lines:
		var col := ink
		if line.delta != 0:
			col = _number_color(line.delta)
		draw_multiline_string(_font, Vector2(body.position.x, y), line.text, HORIZONTAL_ALIGNMENT_CENTER, body.size.x, size, -1, col)
		y += _font.get_multiline_string_size(line.text, HORIZONTAL_ALIGNMENT_CENTER, body.size.x, size).y


func _joined(lines: Array[Dictionary]) -> String:
	var texts := PackedStringArray()
	for line in lines:
		texts.append(line.text)
	return "\n".join(texts)


func _number_color(delta: int) -> Color:
	var paper := class_id == &""
	if delta > 0:
		return NUMBER_RAISED_PAPER if paper else NUMBER_RAISED
	return NUMBER_LOWERED_PAPER if paper else NUMBER_LOWERED


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


func _draw_strip(strip: Rect2, p: Dictionary) -> void:
	var stock: Color = p.stock
	var ink: Color = p.ink
	_box(strip, stock.lerp(Color.BLACK, 0.25 if class_id != &"" else 0.1), 3)
	var hp := card.hp_cost()
	var right := strip.end.x - 3
	if hp > 0:
		# With a warning note the chip drops its "HP" word so the note has room.
		var chip_w := 46.0 if note == "" else 32.0
		var chip := Rect2(strip.end.x - chip_w - 3, strip.position.y + 2, chip_w, strip.size.y - 4)
		_box(chip, HP_RED, 3, 1, Color(1, 1, 1, 0.7))
		_draw_icon(CardEffect.Kind.HEAL_PER_HAUNTED, chip.position + Vector2(8, chip.size.y / 2.0), 4.0, Color.WHITE)
		_text("-%d HP" % hp if note == "" else "-%d" % hp, Rect2(chip.position + Vector2(13, 0), Vector2(chip.size.x - 13, chip.size.y)), 10, Color.WHITE)
		right = chip.position.x - 4
	var room := right - strip.position.x - 6
	var left := Rect2(strip.position.x + 5, strip.position.y, room, strip.size.y)
	if note != "":
		# A long note shrinks (down to 9 px) rather than being cut off.
		# WARN amber vanishes on the pale neutral paper, so those cards use the darker keyword amber.
		_text(note, left, _fit_size(note, room, 11, 9), WARN if class_id != &"" else KEYWORD_INK_PAPER)
		return
	var parts := PackedStringArray()
	match card.target_mode:
		CardData.TargetMode.ALL_ENEMIES:
			parts.append("ALL ENEMIES" if _font.get_string_size("ALL ENEMIES", HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x <= room else "ALL")
		CardData.TargetMode.SELF:
			parts.append("SELF")
		_:
			parts.append("ONE ENEMY")
	for kind in KEYWORDS:
		for effect in card.effects:
			if effect.kind == kind:
				parts.append(KEYWORDS[kind])
				break
	var txt := " · ".join(parts)
	while parts.size() > 1 and _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x > room:
		parts.remove_at(parts.size() - 1)
		txt = " · ".join(parts)
	_text(txt, left, 10, ink)


# --- icons -----------------------------------------------------------------------------
# Every icon is built from unit-space points (about -1..1) scaled by r around c.

func _pts(unit: Array, c: Vector2, r: float, rot := 0.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	for u in unit:
		out.append(c + (u as Vector2).rotated(rot) * r)
	return out


func _fill(points: PackedVector2Array, col: Color, outline := true) -> void:
	draw_colored_polygon(points, col)
	if outline:
		var closed := points.duplicate()
		closed.append(points[0])
		draw_polyline(closed, Color(0, 0, 0, 0.55), 1.2, true)


func _drop(tip: Vector2, w: float) -> PackedVector2Array:
	# A teardrop whose point is at `tip` and whose belly is w wide.
	var out := PackedVector2Array([tip])
	var center := tip + Vector2(0, w * 1.5)
	for i in range(0, 15):
		var a := deg_to_rad(-50.0 + 280.0 * i / 14.0)
		out.append(center + Vector2.from_angle(a) * w)
	return out


func _heart(c: Vector2, r: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in 24:
		var t := TAU * i / 24.0
		var x := 16.0 * pow(sin(t), 3)
		var y := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		out.append(c + Vector2(x, y + 1.0) / 17.0 * r)
	return out


func _shield_pts(c: Vector2, r: float) -> PackedVector2Array:
	return _pts([Vector2(-0.8, -0.85), Vector2(0, -1.0), Vector2(0.8, -0.85), Vector2(0.8, 0.1), Vector2(0.45, 0.65), Vector2(0, 1.0), Vector2(-0.45, 0.65), Vector2(-0.8, 0.1)], c, r)


func _blade(c: Vector2, r: float, col: Color) -> void:
	var rot := PI / 4.0
	_fill(_pts([Vector2(0, -1.0), Vector2(0.17, -0.78), Vector2(0.17, 0.25), Vector2(-0.17, 0.25), Vector2(-0.17, -0.78)], c, r, rot), col)
	_fill(_pts([Vector2(-0.5, 0.25), Vector2(0.5, 0.25), Vector2(0.5, 0.4), Vector2(-0.5, 0.4)], c, r, rot), col.darkened(0.25))
	_fill(_pts([Vector2(-0.08, 0.4), Vector2(0.08, 0.4), Vector2(0.08, 0.85), Vector2(-0.08, 0.85)], c, r, rot), col.darkened(0.4), false)


## Plain-damage icon for a variant from icon_variant(); unknown or empty is the sword.
func _weapon(variant: StringName, c: Vector2, r: float, col: Color, window_col: Color) -> void:
	var rot := PI / 4.0
	match variant:
		&"dagger":
			# Short, broad blade with a small guard: reads as a light stab.
			_fill(_pts([Vector2(0, -0.8), Vector2(0.26, -0.45), Vector2(0.24, 0.3), Vector2(-0.24, 0.3), Vector2(-0.26, -0.45)], c, r, rot), col)
			_fill(_pts([Vector2(-0.5, 0.3), Vector2(0.5, 0.3), Vector2(0.5, 0.46), Vector2(-0.5, 0.46)], c, r, rot), col.darkened(0.25))
			_fill(_pts([Vector2(-0.1, 0.46), Vector2(0.1, 0.46), Vector2(0.1, 0.85), Vector2(-0.1, 0.85)], c, r, rot), col.darkened(0.4), false)
		&"axe":
			# Long haft with a big crescent head: reads as a heavy chop.
			_fill(_pts([Vector2(-0.09, -0.9), Vector2(0.09, -0.9), Vector2(0.09, 1.0), Vector2(-0.09, 1.0)], c, r * 0.82, rot), col.darkened(0.4), false)
			_fill(_pts([Vector2(0.09, -0.95), Vector2(-0.55, -1.05), Vector2(-0.95, -0.85), Vector2(-0.75, -0.4), Vector2(-0.95, 0.05), Vector2(-0.5, 0.15), Vector2(0.09, -0.05)], c, r * 0.82, rot), col)
		&"fist":
			# Fist from the side with motion lines.
			for i in 3:
				draw_line(c + Vector2(-1.0, -0.4 + 0.45 * i) * r, c + Vector2(-0.55 + 0.1 * i, -0.4 + 0.45 * i) * r, Color(col, 0.7), maxf(1.2, r * 0.1))
			_fill(_pts([Vector2(-0.3, -0.35), Vector2(0.75, -0.35), Vector2(0.9, 0.3), Vector2(0.65, 0.85), Vector2(-0.3, 0.85)], c, r), col)
			for i in 4:
				var f := c + Vector2(-0.18 + 0.28 * i, -0.38) * r
				draw_circle(f, r * 0.19, col)
				draw_arc(f, r * 0.19, PI, TAU, 8, Color(0, 0, 0, 0.5), 1.0, true)
			draw_line(c + Vector2(0.1, 0.1) * r, c + Vector2(0.75, 0.1) * r, window_col, maxf(1.0, r * 0.09))
		&"flurry":
			# Three quick parallel slashes.
			for i in 3:
				var o := (i - 1) * 0.55
				_fill(_pts([Vector2(0.9, -0.9), Vector2(0.15, 0.0), Vector2(-0.8, 0.8), Vector2(-0.15, -0.05)], c + Vector2(o, 0.0) * r, r * 0.8), col if i == 1 else col.lightened(0.15))
		&"needle":
			# A long, bold pin with a ring eye and a short thread: a precise prick.
			_fill(_pts([Vector2(0, -1.15), Vector2(0.1, -0.85), Vector2(0.1, 0.55), Vector2(-0.1, 0.55), Vector2(-0.1, -0.85)], c, r, rot), col.lightened(0.2))
			draw_arc(c + Vector2(-0.53, 0.53) * r, r * 0.17, 0, TAU, 14, col.lightened(0.2), maxf(1.4, r * 0.12), true)
			var thread := PackedVector2Array()
			for i in 8:
				thread.append(c + Vector2(-0.68 - 0.07 * i, 0.62 + 0.05 * i + sin(i * 1.4) * 0.1) * r)
			draw_polyline(thread, Color(col.lightened(0.2), 0.8), maxf(1.2, r * 0.08), true)
		&"bone":
			# A pale bone (shaft with two knobbed ends): a spectral club.
			var bone := col.lerp(Color(0.92, 0.88, 0.80), 0.6)
			_fill(_pts([Vector2(-0.12, -0.75), Vector2(0.12, -0.75), Vector2(0.12, 0.75), Vector2(-0.12, 0.75)], c, r, rot), bone)
			for end in [-0.85, 0.85]:
				for side in [-0.17, 0.17]:
					var kp := c + Vector2(side, end).rotated(rot) * r
					draw_circle(kp, r * 0.2, bone)
					draw_arc(kp, r * 0.2, 0, TAU, 12, Color(0, 0, 0, 0.5), 1.0, true)
		&"sweep":
			# Wide arc slash across the whole window.
			var u: Array = []
			for i in 13:
				var a := deg_to_rad(205.0 + 130.0 * i / 12.0)
				u.append(Vector2(cos(a) * 1.15, 0.7 + sin(a) * 0.95))
			for i in 13:
				var a := deg_to_rad(335.0 - 130.0 * i / 12.0)
				u.append(Vector2(cos(a) * 1.0, 0.75 + sin(a) * 0.55))
			_fill(_pts(u, c + Vector2(0, -0.2) * r, r), col)
		_:
			_blade(c, r, col)


func _hammer(c: Vector2, r: float, col: Color) -> void:
	var rot := PI / 4.0
	_fill(_pts([Vector2(-0.09, -0.6), Vector2(0.09, -0.6), Vector2(0.09, 1.0), Vector2(-0.09, 1.0)], c, r, rot), col.darkened(0.4), false)
	_fill(_pts([Vector2(-0.6, -1.0), Vector2(0.6, -1.0), Vector2(0.6, -0.35), Vector2(-0.6, -0.35)], c, r, rot), col)


func _shield(c: Vector2, r: float, col: Color, window_col: Color) -> void:
	_fill(_shield_pts(c, r), col)
	draw_line(c + Vector2(0, -0.8) * r, c + Vector2(0, 0.8) * r, window_col, maxf(1.0, r * 0.14))
	draw_line(c + Vector2(-0.6, -0.2) * r, c + Vector2(0.6, -0.2) * r, window_col, maxf(1.0, r * 0.14))


func _ghost(c: Vector2, r: float, col: Color, window_col: Color) -> void:
	var u: Array = []
	for i in 13:
		var a := PI + PI * i / 12.0
		u.append(Vector2(cos(a) * 0.7, -0.15 + sin(a) * 0.7))
	u.append_array([Vector2(0.7, 0.9), Vector2(0.35, 0.62), Vector2(0, 0.9), Vector2(-0.35, 0.62), Vector2(-0.7, 0.9)])
	_fill(_pts(u, c, r), col)
	draw_circle(c + Vector2(-0.25, -0.2) * r, maxf(0.9, r * 0.13), window_col)
	draw_circle(c + Vector2(0.25, -0.2) * r, maxf(0.9, r * 0.13), window_col)


## Draws the icon for one effect kind at centre c, radius r. `window_col` cuts details out of it.
func _draw_icon(kind: int, c: Vector2, r: float, window_col: Color, variant := &"") -> void:
	var col: Color = kind_color(kind)
	var w := maxf(1.2, r * 0.16)
	match kind:
		CardEffect.Kind.DAMAGE:
			_weapon(variant, c, r * 1.25, col, window_col)
		CardEffect.Kind.BLOCK:
			_shield(c, r, col, window_col)
		CardEffect.Kind.DRAW:
			_fill(_pts([Vector2(-0.7, -0.85), Vector2(0.3, -0.85), Vector2(0.3, 0.45), Vector2(-0.7, 0.45)], c, r), col.darkened(0.35))
			_fill(_pts([Vector2(-0.3, -0.45), Vector2(0.7, -0.45), Vector2(0.7, 0.85), Vector2(-0.3, 0.85)], c, r), col)
			draw_line(c + Vector2(0.0, 0.0) * r, c + Vector2(0.4, 0.0) * r, window_col, w)
			draw_line(c + Vector2(0.0, 0.3) * r, c + Vector2(0.4, 0.3) * r, window_col, w)
		CardEffect.Kind.EXPOSE:
			draw_arc(c, r * 0.62, 0, TAU, 28, col, w * 1.3, true)
			for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				draw_line(c + d * r * 0.35, c + d * r * 1.0, col, w * 1.3)
			draw_circle(c, r * 0.18, col)
		CardEffect.Kind.HOLD:
			var outline := _shield_pts(c, r)
			outline.append(outline[0])
			draw_polyline(outline, col, w * 1.3, true)
			draw_rect(Rect2(c + Vector2(-0.3, 0.0) * r, Vector2(0.6, 0.5) * r), col)
			draw_arc(c + Vector2(0, 0.0) * r, r * 0.22, PI, TAU, 10, col, w * 1.2, true)
		CardEffect.Kind.THORNS:
			var u: Array = []
			for i in 16:
				u.append(Vector2.from_angle(i * TAU / 16.0 - PI / 2.0) * (1.0 if i % 2 == 0 else 0.45))
			_fill(_pts(u, c, r), col)
		CardEffect.Kind.GAIN_ENERGY:
			_fill(_pts([Vector2(0.2, -1.0), Vector2(-0.55, 0.1), Vector2(-0.05, 0.1), Vector2(-0.3, 1.0), Vector2(0.55, -0.15), Vector2(0.05, -0.15)], c, r), col)
		CardEffect.Kind.HAUNT:
			_ghost(c, r, col, window_col)
		CardEffect.Kind.LOSE_HP:
			_fill(_drop(c + Vector2(0, -r), r * 0.62), col)
		CardEffect.Kind.HEAL_PER_HAUNTED:
			_fill(_heart(c, r), col)
			draw_line(c + Vector2(0, -0.35) * r, c + Vector2(0, 0.45) * r, window_col, w)
			draw_line(c + Vector2(-0.4, 0.05) * r, c + Vector2(0.4, 0.05) * r, window_col, w)
		CardEffect.Kind.SHAKEN:
			var zig := PackedVector2Array()
			for i in 7:
				zig.append(c + Vector2(-0.9 + 0.3 * i, (0.55 if i % 2 == 0 else -0.55)) * r)
			draw_polyline(zig, col, w * 1.5, true)
			draw_arc(c, r * 1.0, deg_to_rad(200), deg_to_rad(340), 10, Color(col, 0.6), w, true)
		CardEffect.Kind.FRAYED:
			_fill(_pts([Vector2(-0.8, -0.8), Vector2(0.8, -0.8), Vector2(0.8, -0.1), Vector2(-0.8, -0.1)], c, r), col)
			for i in 5:
				var x := -0.64 + 0.32 * i
				draw_line(c + Vector2(x, -0.1) * r, c + Vector2(x * 1.35 + 0.1 * (i - 2), 0.9 - 0.12 * (i % 2)) * r, col, w)
		CardEffect.Kind.MALICE:
			_fill(_pts([Vector2(0, -1.0), Vector2(0.85, 0.15), Vector2(0.32, 0.15), Vector2(0.32, 0.95), Vector2(-0.32, 0.95), Vector2(-0.32, 0.15), Vector2(-0.85, 0.15)], c, r), col)
		CardEffect.Kind.WARD:
			_shield(c, r, col, window_col)
			draw_arc(c, r * 1.15, 0, TAU, 24, Color(col, 0.55), w, true)
		CardEffect.Kind.DAMAGE_PER_BLOCK:
			_shield(c + Vector2(-0.15, 0.1) * r, r * 0.85, KIND_COLORS[CardEffect.Kind.BLOCK], window_col)
			_hammer(c + Vector2(0.3, -0.2) * r, r * 0.95, KIND_COLORS[CardEffect.Kind.DAMAGE])
		CardEffect.Kind.DAMAGE_IF_BLOCK:
			_blade(c + Vector2(0.1, -0.1) * r, r * 1.0, KIND_COLORS[CardEffect.Kind.DAMAGE])
			_shield(c + Vector2(-0.55, 0.5) * r, r * 0.5, KIND_COLORS[CardEffect.Kind.BLOCK], window_col)
		CardEffect.Kind.DAMAGE_PER_PLAY:
			_blade(c + Vector2(-0.2, -0.1) * r, r * 0.95, KIND_COLORS[CardEffect.Kind.DAMAGE])
			for i in 3:
				var h := (0.35 + 0.3 * i) * r
				draw_rect(Rect2(c + Vector2(0.45 + 0.28 * i, 0.9) * r - Vector2(0, h), Vector2(0.18 * r, h)), KIND_COLORS[CardEffect.Kind.EXPOSE])
		CardEffect.Kind.DAMAGE_PER_HAUNT:
			_ghost(c + Vector2(-0.15, 0.1) * r, r * 0.85, KIND_COLORS[CardEffect.Kind.HAUNT], window_col)
			_blade(c + Vector2(0.35, -0.25) * r, r * 0.8, KIND_COLORS[CardEffect.Kind.DAMAGE])
		CardEffect.Kind.GLIMPSE:
			# An eye: an almond with an iris and a pupil.
			var almond := PackedVector2Array()
			for i in 9:
				var x := -1.0 + 0.25 * i
				almond.append(c + Vector2(x, -0.62 * (1.0 - x * x)) * r)
			for i in 9:
				var x := 1.0 - 0.25 * i
				almond.append(c + Vector2(x, 0.62 * (1.0 - x * x)) * r)
			_fill(almond, col)
			draw_circle(c, r * 0.4, window_col)
			draw_circle(c, r * 0.2, col)
			draw_circle(c + Vector2(0.08, -0.08) * r, r * 0.07, Color(1, 1, 1, 0.8))
		CardEffect.Kind.ADD_CARD:
			# A card with a plus: a darker card behind, the new one in front.
			_fill(_pts([Vector2(-0.8, -0.85), Vector2(0.2, -0.85), Vector2(0.2, 0.55), Vector2(-0.8, 0.55)], c, r), col.darkened(0.4))
			_fill(_pts([Vector2(-0.3, -0.55), Vector2(0.7, -0.55), Vector2(0.7, 0.85), Vector2(-0.3, 0.85)], c, r), col)
			draw_line(c + Vector2(0.2, -0.1) * r, c + Vector2(0.2, 0.55) * r, window_col, w * 1.3)
			draw_line(c + Vector2(-0.12, 0.22) * r, c + Vector2(0.52, 0.22) * r, window_col, w * 1.3)
		CardEffect.Kind.RECALL:
			# A returning arrow: an open circle whose head curls back in.
			var end_angle := deg_to_rad(215)
			draw_arc(c, r * 0.72, deg_to_rad(-60), end_angle, 20, col, w * 1.7, true)
			var tip := c + Vector2.from_angle(end_angle) * r * 0.72
			var along := Vector2.from_angle(end_angle + PI / 2.0)
			var out := Vector2.from_angle(end_angle)
			_fill(PackedVector2Array([tip + along * r * 0.5, tip + out * r * 0.38, tip - out * r * 0.38]), col)
		CardEffect.Kind.DAMAGE_PER_FORGOTTEN:
			# A pile of cards under a blade: damage that grows with the Forgotten pile.
			for i in 3:
				var o := Vector2(-0.45 + 0.12 * i, 0.55 - 0.2 * i)
				_fill(_pts([Vector2(-0.6, -0.3), Vector2(0.6, -0.3), Vector2(0.6, 0.3), Vector2(-0.6, 0.3)], c + o * r, r * 0.8, -0.12 + 0.12 * i), Color(0.55, 0.52, 0.62).lightened(0.12 * i))
			_blade(c + Vector2(0.3, -0.25) * r, r * 0.9, KIND_COLORS[CardEffect.Kind.DAMAGE])
		CardEffect.Kind.SCENT:
			_scent_trail(c, r, col)
		CardEffect.Kind.DAMAGE_PER_SCENT:
			_scent_trail(c + Vector2(-0.2, 0.2) * r, r * 0.75, KIND_COLORS[CardEffect.Kind.SCENT])
			_blade(c + Vector2(0.35, -0.25) * r, r * 0.8, KIND_COLORS[CardEffect.Kind.DAMAGE])


## Colour of a rarity gem on the name banner: none for Common, steel blue for Uncommon, gold for Rare.
const RARITY_GEM_COLORS := {CardData.Rarity.UNCOMMON: Color("#7FA8D8"), CardData.Rarity.RARE: Color("#E8B773")}


static func rarity_gem_color(rarity: int) -> Color:
	return RARITY_GEM_COLORS.get(rarity, Color(0, 0, 0, 0))


## A small diamond at the right end of the name banner for an Uncommon or Rare card (a Rare is a little larger).
func _draw_rarity_gem(c: Vector2) -> void:
	if card == null or not RARITY_GEM_COLORS.has(card.rarity):
		return
	var col: Color = RARITY_GEM_COLORS[card.rarity]
	var r := 4.5 if card.rarity == CardData.Rarity.RARE else 3.5
	var diamond := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
	draw_colored_polygon(diamond, col)
	draw_polyline(PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]]), Color(0, 0, 0, 0.55), 1.0, true)


## A scent trail: three growing drops along a drifting line (placeholder glyph until the card art is designed).
func _scent_trail(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array([c + Vector2(-0.8, 0.5) * r, c + Vector2(-0.3, 0.1) * r, c + Vector2(0.1, 0.3) * r, c + Vector2(0.55, -0.2) * r])
	draw_polyline(pts, Color(col, 0.55), 1.5, true)
	draw_circle(c + Vector2(-0.6, 0.55) * r, r * 0.12, col)
	draw_circle(c + Vector2(-0.05, 0.2) * r, r * 0.18, col)
	draw_circle(c + Vector2(0.6, -0.25) * r, r * 0.26, col)


static func kind_color(kind: int) -> Color:
	if KIND_COLORS.has(kind):
		return KIND_COLORS[kind]
	return Color(0.95, 0.45, 0.35)
