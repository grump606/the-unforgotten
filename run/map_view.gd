class_name MapView
extends Control
## The route map of one act, drawn in code (docs/MAP_DESIGN.md, "Map screen"): rows run left to right,
## nodes are glyphs (crossed blades, an armchair, coin, book, bell, eye), edges are inked lines. A pure
## presentation component: it is handed a RouteMap and the run's position by `set_data` and knows nothing
## of RunState. Reachable nodes pulse and can be clicked (or chosen with the arrow keys and Enter); the
## view then emits `node_chosen(id)` and leaves the state alone until `set_data` is called again.
## This script holds the data, layout, input and pulse clock; MapPainter (run/map_painter.gd) draws it.

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

## The chapter being shown (its district and boss names); set by MapScreen.
var chapter: int = 1

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
var _painter: MapPainter


func _init() -> void:
	_painter = MapPainter.new(self)
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
	if _pulse_throttle.due(delta):
		queue_redraw() # the ambient pulse: 30 Hz is plenty (RedrawThrottle); hover and set_data redraw at once


## Paces the pulse redraws: the whole map repaints for it, so not every frame.
var _pulse_throttle := RedrawThrottle.new()


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
## The player-facing name of district (act) `act`, 0-based; a number past the list reads "District N".
static func district_name(act: int, chapter_number: int = 1) -> String:
	var names := Chapters.chapter(chapter_number).district_names
	if act >= 0 and act < names.size():
		return names[act]
	return "District %d" % (act + 1)


## The label under a boss node ("" for any other type).
func boss_name(type: RouteMap.NodeType) -> String:
	var data := Chapters.chapter(chapter)
	if type == RouteMap.NodeType.MID_BOSS:
		return data.mid_boss_title
	if type == RouteMap.NodeType.BOSS:
		return data.end_boss_title
	return ""


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


## A plain one-line name for a node: "Fight (2 enemies)", "Rest", "Shop", "Treasure", "Event", ... Used by the tests
## to check the node types are all named.
static func node_label(n: RouteMap.MapNode) -> String:
	match n.type:
		RouteMap.NodeType.FIGHT:
			return "Fight (%d enem%s)" % [n.enemy_count, "y" if n.enemy_count == 1 else "ies"]
		RouteMap.NodeType.ELITE:
			return "Elite fight (%d enemies)" % n.enemy_count
		RouteMap.NodeType.REST:
			return "Rest"
		RouteMap.NodeType.SHOP:
			return "Shop"
		RouteMap.NodeType.STORY:
			return "Story"
		RouteMap.NodeType.MID_BOSS:
			return "Mid-boss"
		RouteMap.NodeType.BOSS:
			return "Boss"
		RouteMap.NodeType.TREASURE:
			return "Treasure"
		RouteMap.NodeType.EVENT:
			return "Event"
	return "?"


## Tooltip words for a node: "Fight: 2 enemies", "Rest", "Shop", "Story: <title>", "Mid-boss", "Final boss".
func tooltip_for(id: int) -> String:
	var n := _route.node(id) if _route != null else null
	if n == null:
		return ""
	match n.type:
		RouteMap.NodeType.FIGHT:
			return "Fight: %d %s" % [maxi(n.enemy_count, 1), "enemy" if n.enemy_count <= 1 else "enemies"]
		RouteMap.NodeType.ELITE:
			var modifier := _route.elite_modifier(id)
			var text := "Elite fight: %d enemies. Drops a relic" % maxi(n.enemy_count, 2)
			if modifier >= 0:
				text += "\n" + EliteModifiers.line(modifier)
			return text
		RouteMap.NodeType.REST:
			return "Rest"
		RouteMap.NodeType.SHOP:
			return "Shop"
		RouteMap.NodeType.STORY:
			var beat := StoryContent.beat(n.beat_index, _character, chapter) if n.beat_index >= 0 and n.beat_index < StoryContent.beat_count(chapter) else null
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

## The legend's entries in order, each [node type, label]; MapPainter shows the ones the act has.
const LEGEND := [[RouteMap.NodeType.FIGHT, "Fight"], [RouteMap.NodeType.ELITE, "Elite"], [RouteMap.NodeType.REST, "Rest"],
		[RouteMap.NodeType.SHOP, "Shop"], [RouteMap.NodeType.TREASURE, "Treasure"], [RouteMap.NodeType.EVENT, "Event"], [RouteMap.NodeType.STORY, "Story"], [RouteMap.NodeType.MID_BOSS, "Mid-boss"],
		[RouteMap.NodeType.BOSS, "Boss"]]


## Everything on screen is drawn by MapPainter (run/map_painter.gd).
func _draw() -> void:
	_ensure_layout()
	_painter.draw()


## The colour of a node type's glyph (the map and its legend both draw it).
func glyph_color(type: RouteMap.NodeType) -> Color:
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

