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
	var status := "%s  ·  HP %d/%d  ·  Gold %d  ·  Deck %d" % [run.player.display_name, run.player.hp, run.player.max_hp, run.gold, run.deck.size()]
	present(run.route, visited, run.current_node, reachable, character_id, status)


## Builds the view from plain data (the part of `show` that needs no RunState) and returns it.
func present(route: RouteMap, visited: Array[int], current: int, reachable: Array[int], character_id: StringName, status := "") -> MapView:
	view = MapView.new()
	view.name = "MapView"
	view.set_status(status)
	view.set_data(route, visited, current, reachable, character_id)
	view.node_chosen.connect(_on_chosen)
	body.add_child(view)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.grab_focus.call_deferred()
	return view


func _on_chosen(id: int) -> void:
	node_chosen.emit(id)
