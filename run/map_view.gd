class_name MapView
extends Control
## The route map of one act, drawn in code (docs/MAP_DESIGN.md, "Map screen"): rows run left to right,
## nodes are glyphs (crossed blades, an armchair, coin, book, bell, eye), edges are inked lines. A pure
## presentation component: it is handed a RouteMap and the run's position by `set_data` and knows nothing
## of RunState. Reachable nodes pulse and can be clicked (or chosen with the arrow keys and Enter); the
## view then emits `node_chosen(id)` and leaves the state alone until `set_data` is called again.

signal node_chosen(node_id: int)

## The window the layout was drawn for; everything scales from it.
const DESIGN := Vector2(1152, 648)
## The painted screen laid dimly behind the graph (a missing file leaves the plain dark panel).
const BACKDROP_SCREEN := &"menu"
const BACKDROP_TINT := Color(0.34, 0.36, 0.42, 1.0)

const INK := Color("#10151d")
const DISC := Color(0.065, 0.085, 0.115, 0.94)
const BRASS := Color("#b08a4e")
const BONE := Color("#e8e1d0")
const BONE_DIM := Color("#a6b9b5")
const AMBER := Color("#e8b773")
const BLOOD := Color("#d96b65")
const COIN := Color("#e6c25a")
const PAPER := Color("#83b4cf")
const EDGE_FAINT := Color(0.60, 0.66, 0.68, 0.24)
const EDGE_TAKEN := Color("#e8b773")

## The warm amber of the rest armchair.
const HEARTH := Color("#e8c07a")
## The event glyph: a cream question mark with a violet diamond behind it and a teal dot.
const EVENT_CREAM := Color("#efe6d0")
const EVENT_VIOLET := Color("#8d96e6")
const EVENT_TEAL := Color("#6fd0c4")

const BOSS_NAMES := {RouteMap.NodeType.MID_BOSS: "The Bellkeeper", RouteMap.NodeType.BOSS: "The Eraser"}

## Node states, as `state_of` reports them.
const VISITED := &"visited"
const CURRENT := &"current"
const REACHABLE := &"reachable"
const FUTURE := &"future"

## Seconds on the pulse clock; the screenshot tool sets it to freeze a frame.
var time := 0.0

var _route: RouteMap
var _visited: Array[int] = []
var _current := -1
var _reachable: Array[int] = []
var _character: StringName = &""
var _status := ""
var _act := 0
var _ids: Array[int] = []
var _pos := {}
var _radius := {}
var _taken := {}
var _row_min := 0
var _row_max := 0
var _layout_size := Vector2(-1, -1)
var _hover := -1
var _selected := -1
var _scale := 1.0


func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(640, 360)
	clip_contents = true


func _ready() -> void:
	set_process(not _reachable.is_empty())
	resized.connect(_invalidate)


func _process(delta: float) -> void:
	if Motion.reduced:
		return # the pulse on the reachable nodes holds still; set_data and hover still redraw
	time += delta
	queue_redraw()


# --- Data ------------------------------------------------------------------------------------------------

## Hands the view the map and the run's place on it. `current` is -1 before the first choice; `reachable`
## is what the player may pick now. The act shown is the one the next choice (else the current node) is in.
func set_data(route: RouteMap, visited: Array[int], current: int, reachable: Array[int], character_id: StringName) -> void:
	_route = route
	_visited = visited.duplicate()
	_current = current
	_reachable.assign(reachable.filter(func(id: int) -> bool: return _route != null and _route.node(id) != null))
	_reachable.sort_custom(_by_place)
	_character = character_id
	_act = _pick_act()
	_hover = -1
	if not _reachable.has(_selected):
		_selected = _reachable[0] if not _reachable.is_empty() else -1
	_taken.clear()
	var trail: Array[int] = _visited.duplicate()
	if _current >= 0 and not trail.has(_current):
		trail.append(_current)
	for i in range(1, trail.size()):
		_taken[Vector2i(trail[i - 1], trail[i])] = true
	_invalidate()
	set_process(is_inside_tree() and not _reachable.is_empty())


## A line shown at the right of the header strip (the screen puts the character, HP, gold and deck there).
func set_status(text: String) -> void:
	_status = text
	queue_redraw()


func _by_place(a: int, b: int) -> bool:
	var na := _route.node(a) if _route != null else null
	var nb := _route.node(b) if _route != null else null
	if na == null or nb == null:
		return a < b
	if na.col != nb.col:
		return na.col < nb.col
	return na.row < nb.row


func _pick_act() -> int:
	if _route == null:
		return 0
	var anchor := _route.node(_reachable[0]) if not _reachable.is_empty() else _route.node(_current)
	return anchor.act if anchor != null else 0


func _invalidate() -> void:
	_layout_size = Vector2(-1, -1)
	queue_redraw()


## The act number shown, from 0.
func shown_act() -> int:
	_ensure_layout()
	return _act


## The ids drawn, in node order.
func shown_ids() -> Array[int]:
	_ensure_layout()
	return _ids.duplicate()


## "Row 7/15": the row of the next choice (else of the current node) within the shown act.
func progress_text() -> String:
	_ensure_layout()
	var total := _row_max - _row_min + 1
	var anchor := _route.node(_reachable[0]) if (_route != null and not _reachable.is_empty()) else (_route.node(_current) if _route != null else null)
	var row := (anchor.row - _row_min + 1) if anchor != null else 0
	return "Row %d/%d" % [clampi(row, 0, maxi(total, 0)), maxi(total, 0)]


## visited, current, reachable or future (&"" for an id the view does not show).
func state_of(id: int) -> StringName:
	_ensure_layout()
	if not _pos.has(id):
		return &""
	if id == _current:
		return CURRENT
	if _visited.has(id):
		return VISITED
	if _reachable.has(id):
		return REACHABLE
	return FUTURE


## Tooltip words for a node: "Fight: 2 enemies", "Rest", "Shop", "Story: <title>", "Mid-boss", "Final boss".
func tooltip_for(id: int) -> String:
	var n := _route.node(id) if _route != null else null
	if n == null:
		return ""
	match n.type:
		RouteMap.NodeType.FIGHT:
			return "Fight: %d %s" % [maxi(n.enemy_count, 1), "enemy" if n.enemy_count <= 1 else "enemies"]
		RouteMap.NodeType.ELITE:
			return "Elite fight: %d enemies" % maxi(n.enemy_count, 2)
		RouteMap.NodeType.REST:
			return "Rest"
		RouteMap.NodeType.SHOP:
			return "Shop"
		RouteMap.NodeType.STORY:
			var beat := StoryContent.beat(n.beat_index, _character) if n.beat_index >= 0 and n.beat_index < StoryContent.beat_count() else null
			if beat != null and beat.title != "":
				return "Story: " + beat.title
			return "Story"
		RouteMap.NodeType.MID_BOSS:
			return "Mid-boss"
		RouteMap.NodeType.BOSS:
			return "Final boss"
		RouteMap.NodeType.TREASURE:
			return "Treasure: a relic"
		RouteMap.NodeType.EVENT:
			return "Event: something unexpected"
	return ""


# --- Layout ----------------------------------------------------------------------------------------------

func _ensure_layout() -> void:
	if _layout_size == size:
		return
	_layout_size = size
	_ids.clear()
	_pos.clear()
	_radius.clear()
	_row_min = 0
	_row_max = -1
	if _route == null:
		return
	_row_min = 1 << 30
	_row_max = -1
	for n in _route.nodes:
		if n.act == _act:
			_ids.append(n.id)
			_row_min = mini(_row_min, n.row)
			_row_max = maxi(_row_max, n.row)
	if _ids.is_empty():
		_row_min = 0
		return
	_scale = clampf(minf(size.x / DESIGN.x, size.y / DESIGN.y), 0.4, 3.0)
	var span := _row_max - _row_min + 1
	var left := 64.0 * _scale
	var right := size.x - 70.0 * _scale
	var dx := (right - left) / maxf(span - 1, 1.0)
	var widest := 1
	for row in range(_row_min, _row_max + 1):
		widest = maxi(widest, _route.row_nodes(row).size())
	var top := 96.0 * _scale
	var bottom := size.y - 72.0 * _scale
	var base := minf(dx * 0.31, 25.0 * _scale)
	var dy := minf((bottom - top - 2.0 * base) / maxf(widest - 1, 1.0), 118.0 * _scale)
	var mid := (top + bottom) * 0.5
	for row in range(_row_min, _row_max + 1):
		var members := _route.row_nodes(row)
		for i in members.size():
			var n := members[i]
			if n.act != _act:
				continue
			var jitter := Vector2(_hash(n.id * 3 + 1) * dx * 0.06, _hash(n.id * 3 + 2) * dy * 0.07)
			if members.size() == 1:
				jitter.y = 0.0
			_pos[n.id] = Vector2(left + (row - _row_min) * dx, mid + (i - (members.size() - 1) * 0.5) * dy) + jitter
			var r := base
			if n.type == RouteMap.NodeType.MID_BOSS or n.type == RouteMap.NodeType.BOSS:
				r = base * 1.55
			elif n.type == RouteMap.NodeType.ELITE:
				r = base * 1.12
			_radius[n.id] = r


func _hash(i: int) -> float:
	return fposmod(sin(float(i) * 12.9898) * 43758.5453, 1.0) * 2.0 - 1.0


## Where the node sits in this view's coordinates (Vector2.ZERO for an id that is not shown).
func node_position(id: int) -> Vector2:
	_ensure_layout()
	return _pos.get(id, Vector2.ZERO)


## The node under `at`, or -1.
func node_at(at: Vector2) -> int:
	_ensure_layout()
	var best := -1
	var best_d := INF
	for id in _ids:
		var d: float = (_pos[id] as Vector2).distance_to(at)
		if d <= _radius[id] + 5.0 * _scale and d < best_d:
			best = id
			best_d = d
	return best


## Emits node_chosen when `id` is reachable; returns whether it did.
func choose(id: int) -> bool:
	if not _reachable.has(id):
		return false
	node_chosen.emit(id)
	return true


## The node the keyboard has selected (-1 when nothing can be chosen).
func selected_node() -> int:
	return _selected


## Shows the hover label as if the mouse were on `id` (the screenshot tool uses it).
func set_hover(id: int) -> void:
	_hover = id
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var over := node_at((event as InputEventMouseMotion).position)
		if over != _hover:
			_hover = over
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if _reachable.has(over) else Control.CURSOR_ARROW
			queue_redraw()
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT and button.pressed:
			var hit := node_at(button.position)
			if hit >= 0 and choose(hit):
				accept_event()
		return
	if _reachable.is_empty():
		return
	var step := 0
	if event.is_action_pressed(&"ui_right") or event.is_action_pressed(&"ui_down"):
		step = 1
	elif event.is_action_pressed(&"ui_left") or event.is_action_pressed(&"ui_up"):
		step = -1
	if step != 0:
		var at := _reachable.find(_selected)
		_selected = _reachable[posmod(at + step, _reachable.size())]
		accept_event()
		queue_redraw()
	elif event.is_action_pressed(&"ui_accept"):
		accept_event()
		choose(_selected)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and _hover != -1:
		_hover = -1
		queue_redraw()
	elif what == NOTIFICATION_FOCUS_ENTER or what == NOTIFICATION_FOCUS_EXIT:
		queue_redraw()


# --- Drawing ---------------------------------------------------------------------------------------------

func _draw() -> void:
	_ensure_layout()
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, INK)
	var tex := PaintedArt.screen_texture(BACKDROP_SCREEN)
	if tex != null:
		PaintedArt.draw_cover(self, tex, rect, 1.0, Vector2.ZERO, BACKDROP_TINT)
	draw_rect(rect, Color(0.03, 0.04, 0.06, 0.55))
	_draw_header()
	if _route == null or _ids.is_empty():
		_text("The road is blank.", size * 0.5 - Vector2(70, 0) * _scale, int(18 * _scale), BONE_DIM)
		return
	for id in _ids:
		for to in _route.node(id).next:
			if _pos.has(to):
				_draw_edge(id, to)
	var order := _ids.duplicate()
	order.sort_custom(func(a: int, b: int) -> bool: return int(a == _hover) < int(b == _hover))
	for id in order:
		_draw_node(id)
	_draw_legend()
	if _hover >= 0 and _pos.has(_hover):
		_draw_bubble(_hover)


func _pulse() -> float:
	return 0.5 + 0.5 * sin(time * 3.2)


func _font() -> Font:
	return MenuStyle.serif_font()


func _text(text: String, at: Vector2, font_size: int, color: Color, width := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var font := _font()
	draw_string(font, at + Vector2(0, 1.5), text, align, width, font_size, Color(0.02, 0.03, 0.05, 0.9))
	draw_string(font, at, text, align, width, font_size, color)


func _draw_header() -> void:
	var s := _scale
	var strip := Rect2(0, 0, size.x, 64.0 * s)
	draw_rect(strip, Color(0.04, 0.05, 0.08, 0.72))
	draw_line(Vector2(0, strip.size.y), Vector2(size.x, strip.size.y), Color(BRASS, 0.7), 2.0)
	var title := "Act %d" % (_act + 1)
	_text(title, Vector2(28.0 * s, 42.0 * s), int(30 * s), Color("#d7d0bc"))
	var title_w := _font().get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, int(30 * s)).x
	_text(progress_text(), Vector2(28.0 * s + title_w + 18.0 * s, 41.0 * s), int(17 * s), BONE_DIM)
	if _status != "":
		_text(_status, Vector2(0, 40.0 * s), int(15 * s), BONE, size.x - 28.0 * s, HORIZONTAL_ALIGNMENT_RIGHT)


func _edge_points(a: int, b: int) -> PackedVector2Array:
	var p0: Vector2 = _pos[a]
	var p1: Vector2 = _pos[b]
	var dir := (p1 - p0).normalized()
	p0 += dir * (_radius[a] + 2.0 * _scale)
	p1 -= dir * (_radius[b] + 2.0 * _scale)
	var bow := _hash(a * 131 + b) * 7.0 * _scale
	var ctrl := (p0 + p1) * 0.5 + Vector2(-dir.y, dir.x) * bow
	var pts := PackedVector2Array()
	for i in 11:
		var t := i / 10.0
		pts.append(p0.lerp(ctrl, t).lerp(ctrl.lerp(p1, t), t))
	return pts


func _draw_edge(a: int, b: int) -> void:
	var pts := _edge_points(a, b)
	var s := _scale
	if _taken.has(Vector2i(a, b)):
		draw_polyline(pts, Color(0.0, 0.0, 0.0, 0.55), 6.0 * s, true)
		draw_polyline(pts, EDGE_TAKEN, 3.0 * s, true)
	elif a == _current and _reachable.has(b):
		var glow := 0.65 + 0.35 * _pulse()
		draw_polyline(pts, Color(0.0, 0.0, 0.0, 0.55), 6.0 * s, true)
		draw_polyline(pts, Color(AMBER, glow), 3.0 * s, true)
	else:
		var faint := EDGE_FAINT
		if _visited.has(a) or a == _current:
			faint.a = 0.16 # a road not taken
		draw_polyline(pts, Color(0, 0, 0, 0.35), 4.0 * s, true)
		draw_polyline(pts, faint, 2.0 * s, true)


func _draw_node(id: int) -> void:
	var n := _route.node(id)
	var state := state_of(id)
	var r: float = _radius[id]
	var c: Vector2 = _pos[id]
	var s := _scale
	var hovered := id == _hover
	var chosen := (state == REACHABLE and hovered)
	if chosen:
		r *= 1.12
	var alpha := 1.0
	var k := 1.0
	var rim := Color(BRASS, 0.75)
	match state:
		VISITED:
			alpha = 0.55
			k = 0.7
			rim = Color(BRASS, 0.5)
		FUTURE:
			alpha = 0.8
			k = 0.82
			rim = Color("#526979")
		REACHABLE:
			rim = AMBER
		CURRENT:
			rim = Color("#fff1c9")
	var pulse := _pulse()
	if state == REACHABLE:
		draw_circle(c, r + (5.0 + 3.0 * pulse) * s, Color(AMBER, 0.10 + 0.12 * pulse))
		draw_circle(c, r + 2.5 * s, Color(AMBER, 0.14))
	elif state == CURRENT:
		draw_circle(c, r + 7.0 * s, Color("#fff1c9", 0.12 + 0.06 * pulse))
	if n.type == RouteMap.NodeType.ELITE:
		_ring_flames(c, r, alpha, k)
	draw_circle(c + Vector2(0, 2.5 * s), r + 1.0, Color(0, 0, 0, 0.5 * alpha))
	draw_circle(c, r, Color(DISC, DISC.a * alpha))
	draw_arc(c, r, 0.0, TAU, 48, Color(rim, rim.a * alpha), 2.6 * s, true)
	draw_arc(c, r - 3.4 * s, 0.0, TAU, 40, Color(rim, 0.22 * alpha), 1.0, true)
	if state == CURRENT:
		draw_arc(c, r + 3.6 * s, 0.0, TAU, 48, Color("#fff1c9", 0.55 + 0.3 * pulse), 1.8 * s, true)
	if has_focus() and id == _selected and state == REACHABLE:
		draw_arc(c, r + 9.0 * s, 0.0, TAU, 48, BONE, 1.6 * s, true)
	var col := _glyph_color(n.type)
	col = Color(col.r * k, col.g * k, col.b * k, alpha)
	_draw_glyph(n.type, c, r * 0.66, col)
	if state == VISITED:
		_draw_tick(c + Vector2(r * 0.62, -r * 0.62), r * 0.3)
	if n.type == RouteMap.NodeType.FIGHT or n.type == RouteMap.NodeType.ELITE:
		var count := clampi(n.enemy_count, 1, Combat.MAX_ENEMIES)
		var gap := 9.0 * s
		var y := c.y + r + 8.0 * s
		for i in count:
			var px := c.x + (i - (count - 1) * 0.5) * gap
			draw_circle(Vector2(px, y), 3.7 * s, Color(0, 0, 0, 0.7 * alpha))
			draw_circle(Vector2(px, y), 3.0 * s, Color(BONE.r * k, BONE.g * k, BONE.b * k, alpha))
	elif BOSS_NAMES.has(n.type):
		_text(BOSS_NAMES[n.type], Vector2(c.x - 70.0 * s, c.y + r + 17.0 * s), int(13 * s), Color(BONE, alpha), 140.0 * s, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_tick(at: Vector2, g: float) -> void:
	draw_circle(at, g * 1.25, Color(0.03, 0.04, 0.06, 0.9))
	var pts := PackedVector2Array([at + Vector2(-g * 0.7, 0.0), at + Vector2(-g * 0.2, g * 0.55), at + Vector2(g * 0.75, -g * 0.55)])
	draw_polyline(pts, Color(EDGE_TAKEN, 0.9), maxf(1.6, g * 0.4), true)


func _glyph_color(type: RouteMap.NodeType) -> Color:
	match type:
		RouteMap.NodeType.FIGHT:
			return Color("#e07a70")
		RouteMap.NodeType.ELITE:
			return Color("#ffa629") # fire: amber blades under orange flames
		RouteMap.NodeType.REST:
			return HEARTH
		RouteMap.NodeType.SHOP:
			return COIN
		RouteMap.NodeType.STORY:
			return Color("#a9cfe3")
		RouteMap.NodeType.MID_BOSS:
			return Color("#e6c25a")
		RouteMap.NodeType.TREASURE:
			return Color("#f6d98e")
		RouteMap.NodeType.EVENT:
			return EVENT_CREAM
	return Color("#f4eee0")


func _draw_glyph(type: RouteMap.NodeType, c: Vector2, g: float, col: Color) -> void:
	match type:
		RouteMap.NodeType.FIGHT:
			_glyph_blades(c, g, col)
		RouteMap.NodeType.ELITE:
			_glyph_blades(c, g, col) # an elite's flames burn on the node's rim, see _ring_flames
		RouteMap.NodeType.REST:
			_glyph_armchair(c, g, col)
		RouteMap.NodeType.SHOP:
			_glyph_coin(c, g, col)
		RouteMap.NodeType.STORY:
			_glyph_book(c, g, col)
		RouteMap.NodeType.MID_BOSS:
			_glyph_bell(c, g, col)
		RouteMap.NodeType.BOSS:
			_glyph_eye(c, g, col)
		RouteMap.NodeType.TREASURE:
			_glyph_chest(c, g, col)
		RouteMap.NodeType.EVENT:
			_glyph_question(c, g, col)


func _glyph_blades(c: Vector2, g: float, col: Color) -> void:
	var w := maxf(2.0, g * 0.22)
	for m in [-1.0, 1.0]:
		var hilt := c + Vector2(-m * g, g)
		var tip := c + Vector2(m * g, -g)
		draw_line(hilt, tip, col, w, true)
		var guard_at := hilt.lerp(tip, 0.3)
		var perp := Vector2(m, 1.0).normalized() * g * 0.38
		draw_line(guard_at - perp, guard_at + perp, col, w * 0.8, true)
		draw_circle(hilt, w * 0.85, col)


## An elite's flames: tongues around the outside of a node's ring (centre `c`, ring radius `r`), an orange outer flame with a
## pale yellow core, swaying and flickering with `time` (still under reduced motion, where `time` stops). The ones on top
## are the tallest and the ones underneath stay low, clear of the enemy pips. Drawn before the disc, which hides their bases.
func _ring_flames(c: Vector2, r: float, alpha: float, k: float) -> void:
	var outer := Color("#ff5a1a")
	var core := Color("#ffe58a")
	outer = Color(outer.r * k, outer.g * k, outer.b * k, alpha)
	core = Color(core.r * k, core.g * k, core.b * k, alpha)
	var count := 12
	for i in count:
		var angle := TAU * float(i) / count - PI * 0.5 # from the top, clockwise
		var dir := Vector2.from_angle(angle)
		var tangent := Vector2(-dir.y, dir.x)
		var up := clampf(0.5 + 0.5 * -dir.y, 0.0, 1.0)
		var flicker := 1.0 + 0.18 * sin(time * 8.0 + i * 2.3)
		var sway := 0.22 * r * sin(time * 5.0 + i * 1.7)
		var h := r * (0.3 + 0.55 * up) * flicker
		var half := r * 0.2
		for layer in 2:
			var kk := 1.0 if layer == 0 else 0.55
			var base := c + dir * (r - 2.0)
			var pts := PackedVector2Array([
				base - tangent * half * kk,
				base + dir * h * 0.5 * kk - tangent * half * 0.85 * kk + tangent * sway * 0.4,
				base + dir * h * kk + tangent * sway * kk,
				base + dir * h * 0.5 * kk + tangent * half * 0.85 * kk + tangent * sway * 0.4,
				base + tangent * half * kk,
			])
			draw_colored_polygon(pts, outer if layer == 0 else core)


func _glyph_coin(c: Vector2, g: float, col: Color) -> void:
	var dark := Color(col.r * 0.35, col.g * 0.3, col.b * 0.15, col.a)
	draw_circle(c, g * 0.95, col)
	draw_arc(c, g * 0.68, 0.0, TAU, 28, dark, maxf(1.5, g * 0.14), true)
	draw_line(c + Vector2(0, -g * 0.36), c + Vector2(0, g * 0.36), dark, maxf(2.0, g * 0.2), true)
	draw_line(c + Vector2(-g * 0.2, -g * 0.12), c + Vector2(g * 0.2, -g * 0.12), dark, maxf(1.5, g * 0.14), true)


func _glyph_book(c: Vector2, g: float, col: Color) -> void:
	var dark := Color(col.r * 0.3, col.g * 0.35, col.b * 0.4, col.a)
	for m in [-1.0, 1.0]:
		var page := _scaled([Vector2(m * 0.06, -0.38), Vector2(m * 0.5, -0.7), Vector2(m * 1.0, -0.52), Vector2(m * 1.0, 0.6), Vector2(m * 0.5, 0.78), Vector2(m * 0.06, 0.55)], c, g)
		if m < 0.0:
			page.reverse() # keep the winding the same on both sides
		draw_colored_polygon(page, col)
		for i in 3:
			var y := -0.3 + i * 0.3
			draw_line(c + Vector2(m * 0.2, y + 0.03) * g, c + Vector2(m * 0.82, y - 0.02) * g, dark, maxf(1.2, g * 0.09), true)
	draw_line(c + Vector2(0, -0.4) * g, c + Vector2(0, 0.58) * g, dark, maxf(1.5, g * 0.12), true)


func _glyph_bell(c: Vector2, g: float, col: Color) -> void:
	var pts: Array[Vector2] = [Vector2(-0.98, 0.62), Vector2(-0.72, 0.4), Vector2(-0.56, -0.05)]
	for i in 9:
		var a := PI + PI * i / 8.0
		pts.append(Vector2(cos(a) * 0.56, -0.2 + sin(a) * 0.68))
	pts.append_array([Vector2(0.56, -0.05), Vector2(0.72, 0.4), Vector2(0.98, 0.62)])
	draw_colored_polygon(_scaled(pts, c, g), col)
	draw_circle(c + Vector2(0, 0.86) * g, g * 0.17, col)
	draw_arc(c + Vector2(0, -0.92) * g, g * 0.17, 0.0, TAU, 12, col, maxf(1.5, g * 0.12), true)
	var dark := Color(col.r * 0.4, col.g * 0.35, col.b * 0.2, col.a)
	draw_line(c + Vector2(-0.4, 0.2) * g, c + Vector2(-0.3, -0.3) * g, dark, maxf(1.5, g * 0.1), true)


func _glyph_eye(c: Vector2, g: float, col: Color) -> void:
	var lens: Array[Vector2] = []
	for i in 13:
		var x := -1.15 + 2.3 * i / 12.0
		lens.append(Vector2(x, -0.62 * (1.0 - pow(x / 1.15, 2.0))))
	for i in range(11, 0, -1):
		var x := -1.15 + 2.3 * i / 12.0
		lens.append(Vector2(x, 0.62 * (1.0 - pow(x / 1.15, 2.0))))
	var poly := _scaled(lens, c, g)
	draw_colored_polygon(poly, Color(col.r * 0.9, col.g * 0.85, col.b * 0.8, col.a))
	draw_polyline(poly + PackedVector2Array([poly[0]]), Color(1.0, 0.9, 0.8, col.a), maxf(1.5, g * 0.1), true)
	draw_circle(c, g * 0.46, Color(0.55, 0.12, 0.12, col.a))
	draw_line(c + Vector2(0, -0.46) * g, c + Vector2(0, 0.46) * g, Color(0.04, 0.02, 0.03, col.a), maxf(2.0, g * 0.16), true)
	draw_line(c + Vector2(-0.95, 0.85) * g, c + Vector2(0.95, -0.85) * g, Color(0.04, 0.02, 0.03, col.a * 0.9), maxf(2.0, g * 0.14), true)


## A high-backed armchair seen from the front: arched back, two armrests, a cushion and short legs.
func _glyph_armchair(c: Vector2, g: float, col: Color) -> void:
	var w := maxf(2.0, g * 0.2)
	var cream := Color(minf(col.r * 1.12, 1.0), minf(col.g * 1.12, 1.0), minf(col.b * 1.2, 1.0), col.a)
	var dark := Color(col.r * 0.35, col.g * 0.3, col.b * 0.2, col.a)
	for x in [-0.72, 0.72]:
		draw_line(c + Vector2(x, 0.6) * g, c + Vector2(x, 1.0) * g, col, w, true)
	var back: Array[Vector2] = [Vector2(-0.52, 0.45), Vector2(-0.58, -0.55)]
	for i in 9:
		var a := PI + PI * i / 8.0
		back.append(Vector2(cos(a) * 0.58, -0.55 + sin(a) * 0.5))
	back.append_array([Vector2(0.58, -0.55), Vector2(0.52, 0.45)])
	draw_colored_polygon(_scaled(back, c, g), col)
	draw_arc(c + Vector2(0.0, -0.55) * g, g * 0.34, PI * 1.05, PI * 1.95, 8, dark, maxf(1.4, g * 0.1), true)
	for m in [-1.0, 1.0]:
		var arm := _scaled([Vector2(m * 0.45, -0.05), Vector2(m * 0.82, -0.12), Vector2(m * 1.04, 0.0), Vector2(m * 1.04, 0.66), Vector2(m * 0.45, 0.66)], c, g)
		if m < 0.0:
			arm.reverse()
		draw_colored_polygon(arm, col)
		draw_line(c + Vector2(m * 0.48, 0.04) * g, c + Vector2(m * 0.48, 0.64) * g, dark, maxf(1.4, g * 0.1), true)
	var seat := _scaled([Vector2(-0.5, 0.18), Vector2(0.5, 0.18), Vector2(0.56, 0.58), Vector2(-0.56, 0.58)], c, g)
	draw_colored_polygon(seat, cream)


## A treasure chest: a domed lid on a box, two straps and a lock plate. A wide dome-on-box silhouette, unlike the
## round coin and the high-backed armchair.
func _glyph_chest(c: Vector2, g: float, col: Color) -> void:
	var dark := Color(col.r * 0.32, col.g * 0.26, col.b * 0.14, col.a)
	var cream := Color(minf(col.r * 1.1, 1.0), minf(col.g * 1.1, 1.0), minf(col.b * 1.25, 1.0), col.a)
	var hinge_y := -0.02
	var shape: Array[Vector2] = [Vector2(-1.04, 0.84), Vector2(-1.04, hinge_y)]
	for i in 11:
		var a := PI + PI * i / 10.0
		shape.append(Vector2(cos(a) * 1.04, hinge_y + sin(a) * 0.82))
	shape.append_array([Vector2(1.04, hinge_y), Vector2(1.04, 0.84)])
	draw_colored_polygon(_scaled(shape, c, g), col)
	var w := maxf(1.5, g * 0.13)
	draw_line(c + Vector2(-1.04, hinge_y) * g, c + Vector2(1.04, hinge_y) * g, dark, w, true)
	for x in [-0.62, 0.62]:
		var top := hinge_y - 0.82 * sqrt(maxf(1.0 - pow(x / 1.04, 2.0), 0.0))
		draw_line(c + Vector2(x, top) * g, c + Vector2(x, 0.84) * g, dark, w, true)
	draw_line(c + Vector2(-1.04, 0.84) * g, c + Vector2(1.04, 0.84) * g, dark, w, true)
	var plate := _scaled([Vector2(-0.24, -0.14), Vector2(0.24, -0.14), Vector2(0.24, 0.3), Vector2(-0.24, 0.3)], c, g)
	draw_colored_polygon(plate, cream)
	draw_circle(c + Vector2(0, 0.06) * g, g * 0.07, dark)
	draw_line(c + Vector2(0, 0.06) * g, c + Vector2(0, 0.2) * g, dark, maxf(1.2, g * 0.08), true)


## An event: a question mark inside a tilted violet diamond (a tall hooked line and a dot, unlike the wide chest, the
## round coin and the high-backed armchair). The mark keeps `col`; the diamond and the dot take their own accent
## colours at the same brightness and opacity as the rest of the node.
func _glyph_question(c: Vector2, g: float, col: Color) -> void:
	var w := maxf(2.6, g * 0.34)
	var shade := Color(col.r / EVENT_CREAM.r, col.g / EVENT_CREAM.g, col.b / EVENT_CREAM.b, col.a)
	var violet := Color(EVENT_VIOLET.r * minf(shade.r, 1.0), EVENT_VIOLET.g * minf(shade.g, 1.0), EVENT_VIOLET.b * minf(shade.b, 1.0), col.a)
	var teal := Color(EVENT_TEAL.r * minf(shade.r, 1.0), EVENT_TEAL.g * minf(shade.g, 1.0), EVENT_TEAL.b * minf(shade.b, 1.0), col.a)
	var diamond := _scaled([Vector2(0, -1.12), Vector2(1.12, 0), Vector2(0, 1.12), Vector2(-1.12, 0), Vector2(0, -1.12)], c, g)
	draw_polyline(diamond, Color(violet, violet.a * 0.95), maxf(1.8, g * 0.17), true)
	var hook := c + Vector2(0.0, -0.38) * g
	draw_arc(hook, g * 0.5, PI * 0.92, PI * 2.45, 18, col, w, true)
	draw_line(c + Vector2(0.08, 0.1) * g, c + Vector2(0.0, 0.36) * g, col, w, true)
	draw_circle(c + Vector2(0.0, 0.76) * g, g * 0.2, teal)


func _scaled(points: Array, c: Vector2, g: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(c + (p as Vector2) * g)
	return out


func _draw_legend() -> void:
	var s := _scale
	var present := {}
	for id in _ids:
		present[_route.node(id).type] = true
	var items: Array = []
	for pair in [[RouteMap.NodeType.FIGHT, "Fight"], [RouteMap.NodeType.ELITE, "Elite"], [RouteMap.NodeType.REST, "Rest"],
			[RouteMap.NodeType.SHOP, "Shop"], [RouteMap.NodeType.TREASURE, "Treasure"], [RouteMap.NodeType.EVENT, "Event"], [RouteMap.NodeType.STORY, "Story"], [RouteMap.NodeType.MID_BOSS, "Mid-boss"],
			[RouteMap.NodeType.BOSS, "Boss"]]:
		if present.has(pair[0]):
			items.append(pair)
	var fs := int(13 * s)
	var gw := 22.0 * s
	var widths: Array[float] = []
	var total := 0.0
	for it in items:
		var w := gw + _font().get_string_size(it[1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 26.0 * s
		widths.append(w)
		total += w
	var pips_w := 70.0 * s + _font().get_string_size("enemies", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	total += pips_w
	var y := size.y - 28.0 * s
	draw_rect(Rect2(0, y - 24.0 * s, size.x, 52.0 * s), Color(0.04, 0.05, 0.08, 0.62))
	var x := (size.x - total) * 0.5
	for i in items.size():
		var type: RouteMap.NodeType = items[i][0]
		var col := _glyph_color(type)
		if type == RouteMap.NodeType.ELITE:
			_ring_flames(Vector2(x + gw * 0.5, y - 3.0 * s), 7.5 * s, 1.0, 1.0)
		_draw_glyph(type, Vector2(x + gw * 0.5, y - 3.0 * s), 7.5 * s, Color(col, 0.9))
		_text(items[i][1], Vector2(x + gw + (6.0 if type == RouteMap.NodeType.ELITE else 2.0) * s, y + 1.0 * s), fs, BONE_DIM)
		x += widths[i]
	for i in 3:
		draw_circle(Vector2(x + (6.0 + i * 8.0) * s, y - 3.0 * s), 2.3 * s, BONE_DIM)
	_text("enemies", Vector2(x + 36.0 * s, y + 1.0 * s), fs, BONE_DIM)


func _draw_bubble(id: int) -> void:
	var s := _scale
	var text := tooltip_for(id)
	if text == "":
		return
	var fs := int(15 * s)
	var tw := _font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var box := Vector2(tw + 22.0 * s, 28.0 * s)
	var c: Vector2 = _pos[id]
	var r: float = _radius[id]
	var at := Vector2(c.x - box.x * 0.5, c.y - r - box.y - 12.0 * s)
	if at.y < 70.0 * s:
		at.y = c.y + r + 22.0 * s
	at.x = clampf(at.x, 6.0 * s, size.x - box.x - 6.0 * s)
	draw_rect(Rect2(at + Vector2(2, 3) * s, box), Color(0, 0, 0, 0.45))
	draw_rect(Rect2(at, box), Color(0.05, 0.065, 0.09, 0.96))
	draw_rect(Rect2(at, box), BRASS, false, 1.8 * s)
	_text(text, at + Vector2(0, box.y * 0.5 + fs * 0.35), fs, BONE, box.x, HORIZONTAL_ALIGNMENT_CENTER)
