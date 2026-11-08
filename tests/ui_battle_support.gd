extends SceneTree
## Shared base for the ui_battle_*_test.gd files: the check/key helpers, a seeded battle screen and the
## fresh-fight setup. Not a test itself (check.ps1 only runs ui_*_test.gd).

const SEED := 7

var fails := 0

func check(c: bool, msg: String) -> void:
	if not c:
		fails += 1
		printerr("FAIL: " + msg)
	else:
		print("ok: " + msg)

func key(node: Node, code: int, shift := false) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	e.shift_pressed = shift
	node._unhandled_key_input(e)

func _mouse_button(view: CardView, pressed: bool, global: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = pressed
	e.global_position = global
	e.position = global - view.get_global_rect().position
	view._gui_input(e)

func _mouse_move(view: CardView, global: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.global_position = global
	e.position = global - view.get_global_rect().position
	view._gui_input(e)

func _proto(id: String) -> CardData:
	return load("res://data/prototype/%s.tres" % id) as CardData

func _card(id: String) -> CardData:
	return load("res://data/cards/%s.tres" % id) as CardData

## A fresh fight with the screen in a known state: energy to spare, tough enemies, no statuses.
func _fresh_fight(node: Control) -> Combat:
	node._start_combat()
	await process_frame
	var c: Combat = node._combat
	c.energy = 9
	c.plays_this_turn = 0
	c.player.clear_block()
	c.player.clear_statuses()
	for e in c.enemies:
		e.clear_statuses()
		e.clear_block()
		e.max_hp = 500
		e.hp = 500
	node._select_target(0)
	return c

func _ids(cards: Array[CardData]) -> Array:
	return cards.map(func(card: CardData) -> StringName: return card.id)


## The battle screen on a reproducible seed (the fight made in _ready was random).
func _make_battle() -> Control:
	var node: Control = (load("res://battle.tscn") as PackedScene).instantiate()
	root.add_child(node)
	await process_frame
	node.seed_override = SEED
	node._start_combat()
	return node


func _finish() -> void:
	print("DONE fails=", fails)
	quit(1 if fails > 0 else 0)
