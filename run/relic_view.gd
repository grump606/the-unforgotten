class_name RelicView
extends Control
## A relic drawn as a worn keepsake badge, entirely in code. The
## relic's Kind picks the glyph, its class (RelicData.character) picks the frame palette from
## CardView.PALETTES (neutral relics are faded bone paper). Drawn in a fixed BASE-sized space
## and scaled by view_scale. Hovering shows the engine tooltip (name, effect, class), which the
## window keeps on screen at every edge.

const BASE := Vector2(36, 36)
## Dark disc laid over a sold or unaffordable badge.
const DIM := Color(0.04, 0.04, 0.07, 0.55)
## One glyph per RelicData.Kind (kept in step with the enum by tests/ui_relic_view_test.gd).
const GLYPH_NAMES := {
	RelicData.Kind.MAX_HP: "flask",
	RelicData.Kind.WIN_GOLD: "purse",
	RelicData.Kind.WIN_HEAL: "folded farewell",
	RelicData.Kind.FIGHT_START_BLOCK: "dog tag",
	RelicData.Kind.TURN_START_THORNS: "barbed wire",
	RelicData.Kind.TURN_START_BLOCK: "tin",
	RelicData.Kind.FIRST_PLAY_DRAW: "glove",
	RelicData.Kind.FIRST_TURN_ENERGY: "key",
	RelicData.Kind.PLAYS_BLOCK: "cards",
	RelicData.Kind.FIGHT_START_HAUNT: "grave mound",
	RelicData.Kind.TURN_START_HEAL_PER_HAUNTED: "planchette",
	RelicData.Kind.HAUNT_BONUS: "rosary",
}

var relic: RelicData
## Which palette the current relic uses: &"" (neutral) or a class id.
var class_id: StringName = &""
var view_scale := 1.0:
	set(value):
		view_scale = value
		_update_size()
## Darkens the badge (a sold or unaffordable offer).
var dimmed := false:
	set(value):
		dimmed = value
		queue_redraw()

var _hovered := false


func _init() -> void:
	# PASS, not IGNORE: the badge must receive the mouse to show its tooltip, but never eats a click.
	mouse_filter = Control.MOUSE_FILTER_PASS
	_update_size()


func _ready() -> void:
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))


func set_relic(new_relic: RelicData) -> void:
	relic = new_relic
	class_id = palette_id(new_relic)
	tooltip_text = tooltip_for(new_relic)
	queue_redraw()


## The palette key for a relic: its character when that class has a frame, else neutral.
static func palette_id(r: RelicData) -> StringName:
	if r != null and CardView.PALETTES.has(r.character):
		return r.character
	return &""


## Tooltip text: name, effect, then whose relic it is.
static func tooltip_for(r: RelicData) -> String:
	if r == null:
		return ""
	var owner_text := "Neutral relic" if palette_id(r) == &"" else "%s relic" % String(palette_id(r)).capitalize()
	return "%s\n%s\n(%s)" % [r.display_name, r.description, owner_text]


## The glyph name for a Kind, or "" when it has none.
static func glyph_name(kind: RelicData.Kind) -> String:
	return GLYPH_NAMES.get(kind, "")


## Every RelicView at or under `node`, in tree order.
static func find_all(node: Node) -> Array[RelicView]:
	var out: Array[RelicView] = []
	if node is RelicView:
		out.append(node)
	for child in node.get_children():
		out.append_array(find_all(child))
	return out


func _update_size() -> void:
	custom_minimum_size = BASE * view_scale
	size = custom_minimum_size


func _on_hover(on: bool) -> void:
	_hovered = on
	queue_redraw()


func _draw() -> void:
	if relic == null:
		return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(view_scale, view_scale))
	var palette: Dictionary = CardView.PALETTES[class_id]
	var stock: Color = palette["stock"]
	var accent: Color = palette["accent"]
	var ink: Color = palette["ink"]
	var center := BASE * 0.5
	# An uneven bound edge suggests worn paper or cloth while keeping the glyph quiet.
	var edge := PackedVector2Array()
	for i in 32:
		var radius := 17.0 + (0.45 if i % 3 == 0 else 0.0)
		edge.append(center + Vector2.from_angle(i * TAU / 32.0) * radius)
	draw_colored_polygon(edge, palette["frame"])
	draw_circle(center, 15.5, stock)
	draw_arc(center, 14.6, 0.0, TAU, 40, Color(accent, 0.4), 1.0, true)
	for angle in [0.25, 0.75, 2.4, 2.9, 3.7, 4.3, 5.1, 5.8]:
		var inner := center + Vector2.from_angle(angle) * 15.2
		var outer := center + Vector2.from_angle(angle + 0.04) * 16.8
		draw_line(inner, outer, Color(ink, 0.38), 0.8, true)
	_draw_glyph(relic.kind, ink, accent, stock)
	if _hovered:
		draw_circle(center, 15.5, Color(1, 1, 1, 0.14))
	if dimmed:
		draw_circle(center, 17.5, DIM)


## `ink` is the main glyph colour, `accent` the detail, `bg` the badge face (for cut-outs).
func _draw_glyph(kind: RelicData.Kind, ink: Color, accent: Color, bg: Color) -> void:
	match kind:
		RelicData.Kind.MAX_HP: # a travelling flask
			draw_rect(Rect2(15, 8, 6, 6), ink)
			draw_rect(Rect2(14, 6.5, 8, 2.5), accent)
			draw_colored_polygon(PackedVector2Array([Vector2(15, 14), Vector2(21, 14), Vector2(27, 27), Vector2(9, 27)]), ink)
			draw_colored_polygon(PackedVector2Array([Vector2(11.8, 21), Vector2(24.2, 21), Vector2(27, 27), Vector2(9, 27)]), accent)
		RelicData.Kind.WIN_GOLD: # a tied coin purse with a coin on it
			draw_circle(Vector2(18, 21), 8.5, ink)
			draw_colored_polygon(PackedVector2Array([Vector2(14, 13), Vector2(22, 13), Vector2(25.5, 19), Vector2(10.5, 19)]), ink)
			draw_rect(Rect2(13, 11.5, 10, 2.5), accent)
			draw_line(Vector2(14, 11.5), Vector2(11.5, 8.5), accent, 1.6)
			draw_line(Vector2(22, 11.5), Vector2(24.5, 8.5), accent, 1.6)
			draw_circle(Vector2(18, 22), 3.8, accent)
			draw_arc(Vector2(18, 22), 2.2, 0.0, TAU, 14, bg, 1.0, true)
		RelicData.Kind.WIN_HEAL: # a folded farewell note, sealed with a small keepsake cross
			draw_colored_polygon(PackedVector2Array([
				Vector2(8, 11), Vector2(24, 10), Vector2(28, 14),
				Vector2(28, 26), Vector2(9, 27),
			]), ink)
			draw_colored_polygon(PackedVector2Array([Vector2(24, 10), Vector2(24, 15), Vector2(28, 14)]), accent)
			draw_line(Vector2(10, 13), Vector2(18, 20), Color(bg, 0.7), 1.0, true)
			draw_line(Vector2(18, 20), Vector2(26, 15), Color(bg, 0.7), 1.0, true)
			draw_rect(Rect2(17, 18, 2, 7), accent)
			draw_rect(Rect2(14.5, 20.5, 7, 2), accent)
		RelicData.Kind.FIGHT_START_BLOCK: # a stamped dog tag on its chain
			draw_arc(Vector2(18, 12), 5.0, PI, TAU, 14, accent, 1.6, true)
			draw_colored_polygon(PackedVector2Array([
				Vector2(14, 12), Vector2(22, 12), Vector2(25, 15), Vector2(25, 25), Vector2(22, 28),
				Vector2(14, 28), Vector2(11, 25), Vector2(11, 15),
			]), ink)
			draw_circle(Vector2(18, 15.5), 1.6, bg)
			for row in 3:
				draw_rect(Rect2(14, 19.5 + row * 3.0, 8, 1.4), bg)
		RelicData.Kind.TURN_START_THORNS: # two twisted wires with barbs
			var upper := PackedVector2Array()
			var lower := PackedVector2Array()
			for step in 25:
				var x := 6.0 + step
				var wave := 3.4 * sin((x - 6.0) / 16.0 * TAU)
				upper.append(Vector2(x, 18.0 + wave))
				lower.append(Vector2(x, 18.0 - wave))
			draw_polyline(upper, ink, 2.0, true)
			draw_polyline(lower, ink, 2.0, true)
			for x in [14.0, 22.0]:
				draw_line(Vector2(x - 4.6, 12.6), Vector2(x + 4.6, 23.4), accent, 2.0, true)
				draw_line(Vector2(x - 4.6, 23.4), Vector2(x + 4.6, 12.6), accent, 2.0, true)
		RelicData.Kind.TURN_START_BLOCK: # a ration tin
			draw_rect(Rect2(10, 13, 16, 13), ink)
			draw_rect(Rect2(9, 11.5, 18, 3.5), accent)
			draw_arc(Vector2(18, 11.5), 2.6, PI, TAU, 10, accent, 1.5, true)
			draw_rect(Rect2(10, 18, 16, 5), bg)
			draw_rect(Rect2(10, 19.8, 16, 1.4), accent)
		RelicData.Kind.FIRST_PLAY_DRAW: # a glove, fingers up
			var tops := [9.5, 8.0, 8.5, 10.5]
			for i in 4:
				draw_rect(Rect2(11.0 + i * 3.6, tops[i], 3.1, 19.0 - tops[i]), ink)
			draw_rect(Rect2(11, 18, 14, 8.5), ink)
			_rotated_rect(Vector2(9.2, 19.5), Vector2(1.9, 4.5), 0.8, ink)
			draw_rect(Rect2(10, 26.5, 16, 3), accent)
		RelicData.Kind.FIRST_TURN_ENERGY: # a skeleton key
			draw_line(Vector2(15.5, 15.5), Vector2(27, 27), ink, 3.0, true)
			draw_circle(Vector2(12.5, 12.5), 5.8, ink)
			draw_circle(Vector2(12.5, 12.5), 2.4, bg)
			draw_line(Vector2(22.5, 22.5), Vector2(26.5, 18.5), accent, 2.2, true)
			draw_line(Vector2(25.5, 25.5), Vector2(29, 22), accent, 2.2, true)
		RelicData.Kind.PLAYS_BLOCK: # a fan of three marked cards
			_fan_card(-0.5, accent.darkened(0.15), bg)
			_fan_card(0.5, accent, bg)
			_fan_card(0.0, ink, bg)
			_rotated_rect(Vector2(18, 17.5), Vector2(2.0, 2.0), PI / 4.0, bg)
		RelicData.Kind.FIGHT_START_HAUNT: # a mound of grave dirt with a spade and a wisp
			var mound := PackedVector2Array()
			for step in 13:
				var angle := PI + PI * step / 12.0
				mound.append(Vector2(18.0 + 9.5 * cos(angle), 27.0 + 9.0 * sin(angle)))
			draw_colored_polygon(mound, ink)
			draw_line(Vector2(24.5, 8.5), Vector2(21.4, 17.5), accent, 2.0, true)
			_rotated_rect(Vector2(20.3, 20.5), Vector2(2.6, 3.6), 0.32, accent)
			var wisp := PackedVector2Array()
			for step in 9:
				wisp.append(Vector2(11.0 + 1.8 * sin(step * 1.1), 8.0 + step * 1.2))
			draw_polyline(wisp, Color(accent, 0.8), 1.6, true)
		RelicData.Kind.TURN_START_HEAL_PER_HAUNTED: # a planchette with its window
			draw_circle(Vector2(18, 16), 8.0, ink)
			draw_colored_polygon(PackedVector2Array([Vector2(10.4, 18.5), Vector2(25.6, 18.5), Vector2(18, 29)]), ink)
			draw_circle(Vector2(18, 16), 3.8, bg)
			draw_arc(Vector2(18, 16), 3.8, 0.0, TAU, 16, accent, 1.2, true)
			draw_circle(Vector2(18, 16), 1.2, accent)
			for foot in [Vector2(12.5, 21), Vector2(23.5, 21), Vector2(18, 26.5)]:
				draw_circle(foot, 1.3, accent)
		RelicData.Kind.HAUNT_BONUS: # a rosary: a loop of beads with a cross
			var loop := Vector2(18, 14.5)
			var beads := PackedVector2Array()
			for k in 9:
				var angle := PI / 2.0 + 0.55 + k * (TAU - 1.1) / 8.0
				beads.append(loop + Vector2(cos(angle), sin(angle)) * 7.0)
			draw_polyline(beads, accent, 1.0, true)
			for bead in beads:
				draw_circle(bead, 1.9, ink)
			draw_line(Vector2(18, 21.5), Vector2(18, 25), accent, 1.2)
			draw_rect(Rect2(17, 24.5, 2, 5.5), ink)
			draw_rect(Rect2(15.2, 26.2, 5.6, 2), ink)


## A rectangle of half-size `half` around `center`, turned by `angle` radians.
func _rotated_rect(center: Vector2, half: Vector2, angle: float, color: Color) -> void:
	var points := PackedVector2Array()
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		points.append(center + (corner * half).rotated(angle))
	draw_colored_polygon(points, color)


## One card of the fan, hinged at the bottom middle and outlined in the face colour.
func _fan_card(angle: float, color: Color, outline: Color) -> void:
	var hinge := Vector2(18, 28)
	var middle := hinge + Vector2(0, -8.5).rotated(angle)
	_rotated_rect(middle, Vector2(6.0, 9.5), angle, outline)
	_rotated_rect(middle, Vector2(5.0, 8.5), angle, color)
