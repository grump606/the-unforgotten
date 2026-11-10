class_name MapScreen
extends RunScreen
## The route map stop: a MapView filling the body, fed from the run's route, visited nodes, current node
## and reachable choices. Attached like the other screens (`attach(run, body, refresh)`), and run.gd calls
## `show_map(run)`. It owns no navigation: it re-emits the view's pick as `node_chosen(node_id)` and run.gd
## calls `run.choose_node(id)` and redraws.

signal node_chosen(node_id: int)

## The view built by the last show (null before the first).
var view: MapView


## Builds the map for `run_state` into the attached body.
func show_map(run_state: RunState) -> void:
	run = run_state
	show()


func show() -> void:
	var visited: Array[int] = []
	visited.assign(run.visited)
	var reachable: Array[int] = run.reachable_nodes()
	var character_id: StringName = run.character.id if run.character != null else &""
	# No status line: run.gd's header above the map already shows the character, HP, gold and deck.
	present(run.route, visited, run.current_node, reachable, character_id)


## Builds the view from plain data (the part of `show` that needs no RunState) and returns it.
func present(route: RouteMap, visited: Array[int], current: int, reachable: Array[int], character_id: StringName, status := "") -> MapView:
	view = MapView.new()
	view.name = "MapView"
	view.set_status(status)
	view.set_data(route, visited, current, reachable, character_id)
	view.node_chosen.connect(_on_chosen)
	body.add_child(view)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_focus.call_deferred(view)
	return view


## Keyboard focus for the view, unless the screen was redrawn (view freed or removed) before this ran.
func _focus(target: MapView) -> void:
	if is_instance_valid(target) and target.is_inside_tree():
		target.grab_focus()


func _on_chosen(id: int) -> void:
	node_chosen.emit(id)
