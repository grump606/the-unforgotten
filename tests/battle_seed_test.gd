extends SceneTree
## Standalone battle seeding: the same seed_override gives the same encounter and the same first hand,
## and different seeds are not all alike. Run via scripts/check.ps1.

var fails := 0

func check(c: bool, msg: String) -> void:
	if not c:
		fails += 1
		printerr("FAIL: " + msg)
	else:
		print("ok: " + msg)


## Opens a standalone battle with `seed_value` and returns {enemies: ids, hand: card ids}.
func _snapshot(seed_value: int) -> Dictionary:
	var node: Control = (load("res://battle.tscn") as PackedScene).instantiate()
	node.seed_override = seed_value
	root.add_child(node)
	await process_frame
	var combat: Combat = node._combat
	var enemies: Array[StringName] = []
	for e in combat.enemies:
		enemies.append(e.data.id)
	var hand: Array[StringName] = []
	for card in combat.piles.hand:
		hand.append(card.id)
	node.queue_free()
	await process_frame
	return {"enemies": enemies, "hand": hand}


func _initialize() -> void:
	var a: Dictionary = await _snapshot(1234)
	var b: Dictionary = await _snapshot(1234)
	check(not a.enemies.is_empty() and not a.hand.is_empty(), "seeded battle has enemies and a hand")
	check(a.enemies == b.enemies, "same seed gives the same encounter")
	check(a.hand == b.hand, "same seed gives the same first hand")
	var differs := false
	for s in range(1, 12):
		var other: Dictionary = await _snapshot(s)
		if other.enemies != a.enemies or other.hand != a.hand:
			differs = true
	check(differs, "different seeds give different fights")
	quit(1 if fails else 0)
