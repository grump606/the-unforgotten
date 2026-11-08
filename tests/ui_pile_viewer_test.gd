extends SceneTree
## Headless test that PileViewer.refresh() updates in place: with nothing changed the card views are the same
## nodes and none is rewritten, a changed list reuses the views it can and adds or drops only the difference,
## and the tabs and counts follow the pile. Run via scripts/check.ps1.

var fails := 0


func check(c: bool, msg: String) -> void:
	if not c:
		fails += 1
		printerr("FAIL: " + msg)
	else:
		print("ok: " + msg)


func _card(id: String) -> CardData:
	return load("res://data/cards/%s.tres" % id) as CardData


func _initialize() -> void:
	var combat := Combat.create(Combatant.new("Wanderer", 40), StarterContent.extended_deck(),
		[load("res://data/enemies/gate_warden.tres") as EnemyData], 7)
	combat.piles.discard_pile.assign([_card("shove"), _card("bash"), _card("brace")])
	var viewer := PileViewer.create(combat, PileViewer.Pile.DISCARD, Vector2(1152, 648))
	root.add_child(viewer)
	await process_frame
	var views := viewer.card_views()
	check(views.size() == 3 and views[0].card == _card("shove"), "the viewer lists the discard pile")
	viewer.refresh()
	viewer.refresh()
	check(viewer.card_views() == views, "a refresh with nothing new keeps the same card views")

	# One more card: the existing views stay, one is added.
	combat.piles.discard_pile.append(_card("sweep"))
	viewer.refresh()
	var grown := viewer.card_views()
	check(grown.size() == 4 and grown.slice(0, 3) == views and grown[3].card == _card("sweep"), "a new card adds one view and keeps the rest")
	check(viewer.tab_buttons[PileViewer.Pile.DISCARD].text == "Discard 4", "the tab count follows the pile")

	# One card gone from the front: the views are reused and rewritten, the extra one is dropped.
	combat.piles.discard_pile.remove_at(0)
	viewer.refresh()
	await process_frame
	var shrunk := viewer.card_views()
	check(shrunk.size() == 3 and shrunk.slice(0, 3) == grown.slice(0, 3), "a removed card drops only the last view")
	check(shrunk[0].card == _card("bash") and shrunk[2].card == _card("sweep"), "the kept views show the new order")

	# Another tab reuses the nodes too.
	combat.piles.forgotten.assign([_card("brace")])
	viewer.show_pile(PileViewer.Pile.FORGOTTEN)
	await process_frame
	var other := viewer.card_views()
	check(other.size() == 1 and other[0] == shrunk[0] and other[0].card == _card("brace"), "switching tab reuses the first view")
	check(viewer.tab_buttons[PileViewer.Pile.FORGOTTEN].button_pressed and not viewer.tab_buttons[PileViewer.Pile.DISCARD].button_pressed, "the open tab is the pressed one")
	combat.piles.forgotten.clear()
	viewer.refresh()
	await process_frame
	check(viewer.card_views().is_empty() and viewer.note_label.text.contains("empty"), "an emptied pile shows no cards and says so")
	quit(1 if fails > 0 else 0)
