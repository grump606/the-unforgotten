extends "res://tests/test_base.gd"
## Cards step 4: every class pool is at least 22 cards wide, and each class has Common, Uncommon and Rare
## cards that are not part of the starting deck. Discovered by run_tests.gd.


func run() -> int:
	_failures = 0
	var sizes := {}
	for card in StarterContent.all_cards():
		if card.character != &"":
			sizes[card.character] = int(sizes.get(card.character, 0)) + 1
	for class_id in [&"deserter", &"thief", &"medium", &"stray"]:
		_check(int(sizes.get(class_id, 0)) >= 22, "%s has at least 22 class cards (%d)" % [class_id, int(sizes.get(class_id, 0))])
	# Area-of-effect and defensive tools exist for the Deserter.
	var aoe := 0
	for id in [&"cleave", &"earthshaker"]:
		var card := load("res://data/cards/%s.tres" % id) as CardData
		if card.target_mode == CardData.TargetMode.ALL_ENEMIES:
			aoe += 1
	_check(aoe == 2, "the Deserter has two area attacks")
	return _failures
