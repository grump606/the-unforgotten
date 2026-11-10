class_name FallbackMapScreen
extends RunScreen
## Placeholder map screen: a plain column of buttons, one per reachable node. It is the stand-in for
## MapScreen and has the same contract: `attach(run, body, refresh)`, then `show_map(run)` builds the
## picker into the body and `node_chosen(node_id)` is emitted when the player picks a node. run.gd owns
## one screen of this shape in `_map`; swapping between this and MapScreen is changing that one line.

signal node_chosen(node_id: int)


func show_map(run_state: RunState) -> void:
	run = run_state
	var box := panel("Choose your way")
	for id in run.reachable_nodes():
		add_button(box, describe(run.route.node(id)), func() -> void: node_chosen.emit(id))


## "Fight (2 enemies)", "Rest", "Shop", ... for a node.
static func describe(n: RouteMap.MapNode) -> String:
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
