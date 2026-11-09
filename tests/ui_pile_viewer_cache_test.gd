extends SceneTree
## Headless test that an open PileViewer sorts the Draw pile once and keeps the result while the pile is unchanged
## (state_changed refreshes it on every change), and sorts again when the pile does change. Run via scripts/check.ps1.

var fails := 0


func check(c: bool, msg: String) -> void:
	if not c:
		fails += 1
		printerr("FAIL: " + msg)
	else:
		print("ok: " + msg)


func _initialize() -> void:
	var combat := Combat.create(Combatant.new("Wanderer", 40), StarterContent.extended_deck(),
		[load("res://data/enemies/gate_warden.tres") as EnemyData], 7)
	var viewer := PileViewer.create(combat, PileViewer.Pile.DRAW, Vector2(1152, 648))
	root.add_child(viewer)
	await process_frame
	check(viewer.sort_count == 1, "opening the viewer sorts the Draw pile once")
	for i in 5:
		viewer.refresh()
	viewer.show_pile(PileViewer.Pile.DISCARD)
	viewer.show_pile(PileViewer.Pile.DRAW)
	check(viewer.sort_count == 1, "refreshes and tab switches with an unchanged pile do not sort again")
	var sorted_ok := true
	var shown := viewer.card_views()
	for i in range(1, shown.size()):
		sorted_ok = sorted_ok and shown[i - 1].card.cost <= shown[i].card.cost
	check(shown.size() == combat.piles.draw_pile.size() and sorted_ok, "the cached list is still sorted by cost")
	combat.piles.draw_pile.pop_back()
	viewer.refresh()
	check(viewer.sort_count == 2 and viewer.card_views().size() == combat.piles.draw_pile.size(), "a changed pile is sorted again")
	combat.piles.draw_pile.reverse()
	viewer.refresh()
	check(viewer.sort_count == 3, "a reordered pile is sorted again")
	viewer.queue_free()
	quit(1 if fails > 0 else 0)
