class_name Audio
extends RefCounted
## The one way to reach the AudioManager autoload. It is absent in some tests and headless tools, so callers
## get null and skip the call instead of repeating the node lookup.


static func manager() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("AudioManager") if tree != null else null
