extends SceneTree
## Ties the tutorial's fight-screen picture to the live layout: the battle screen is laid out at the base window size
## and each of the eight markers of the picture must lie on, or within MARGIN of, the part of the screen it explains.
## If this fails after a layout change, retake art/tutorial/battle_layout.png and move the markers (see the notes at
## the top of run/tutorial_content.gd). Run via scripts/check.ps1.

## How far a marker may sit from the rectangle it describes. The picture was taken inside a run, whose frame shifts a
## few controls by a few pixels, so this is a loose bound: it catches a control that moved by a screen region.
const MARGIN := 64.0

var fails := 0


func check(c: bool, msg: String) -> void:
	if not c:
		fails += 1
		printerr("FAIL: " + msg)
	else:
		print("ok: " + msg)


func _near(rect: Rect2, point: Vector2) -> bool:
	return rect.grow(MARGIN).has_point(point)


func _initialize() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(MenuStyle.BASE_SIZE)
	root.add_child(viewport)
	var scene: Control = (load("res://battle.tscn") as PackedScene).instantiate()
	scene.seed_override = 7
	viewport.add_child(scene)
	for i in 6:
		await process_frame
	check(scene.size == MenuStyle.BASE_SIZE, "the battle screen fills the base window")

	var enemies := Rect2()
	for view in scene.enemy_views():
		var r: Rect2 = view.get_global_rect()
		enemies = r if enemies.size == Vector2.ZERO else enemies.merge(r)
	var player: Rect2 = scene._player_view.get_global_rect()
	# One entry per marker of the fight-screen page, in order: the rectangle that marker should be on.
	var targets: Array[Rect2] = [
		player,
		enemies,
		enemies,
		enemies,
		scene._energy_orb.get_global_rect(),
		scene._pile_box.get_global_rect(),
		scene._hand_box.get_global_rect(),
		scene._end_turn_button.get_global_rect(),
	]
	var items: Array = TutorialContent.pages()[1].items
	check(items.size() == targets.size(), "there is one target for each of the %d markers" % items.size())
	for i in mini(items.size(), targets.size()):
		var at: Vector2 = items[i].at
		check(_near(targets[i], at), "marker %d at %s is on its part of the live layout %s" % [i + 1, str(at), str(targets[i])])
	quit(1 if fails > 0 else 0)
