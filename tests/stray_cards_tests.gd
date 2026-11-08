extends "res://tests/test_base.gd"
## The Stray's fifteen cards (docs/CLASSES_PLAN.md, the Stray, phase 3): data shape, pools, text and what each
## one does in a fight. Numbers are provisional, so these pin the rules each card was built on. Registered by
## run_tests.gd.

const SCENT := Combatant.Status.SCENT
const IDS: Array[StringName] = [
	&"catch_the_scent", &"snap", &"bristle", &"run_down", &"worry", &"circle", &"nose_to_the_wind", &"old_wound",
	&"howl", &"pounce", &"savage", &"bring_down", &"hackles", &"tear_loose", &"go_feral",
]
const STARTERS: Array[StringName] = [&"catch_the_scent", &"snap", &"bristle", &"run_down"]


func run() -> int:
	_failures = 0
	_test_data_and_pools()
	_test_text()
	_test_scent_cards()
	_test_attack_cards()
	_test_malice_engine()
	_test_the_two_pillars_combine()
	return _failures


func _load(id: StringName) -> CardData:
	return load("res://data/cards/%s.tres" % id) as CardData


func _fight(hand: Array[CardData], enemy_count: int = 1, enemy_hp: int = 200) -> Combat:
	var enemies: Array[EnemyData] = []
	for i in enemy_count:
		enemies.append(EnemyData.make("E%d" % i, enemy_hp, [] as Array[CardEffect]))
	var combat := Combat.new(Combatant.new("p", 40), hand, enemies, 1)
	combat.start()
	return combat


func _play(combat: Combat, card: CardData, target: int = 0) -> bool:
	return combat.play_card(combat.piles.hand.find(card), target)


func _test_data_and_pools() -> void:
	var pool_ids := []
	for card in StarterContent.reward_pool(&"stray"):
		pool_ids.append(card.id)
	for id in IDS:
		var card := _load(id)
		_check(card != null and card.id == id and card.character == &"stray", "%s is a Stray card" % id)
		_check(card != null and not card.effects.is_empty() and card.cost >= 0 and card.cost <= 3, "%s has effects and a sane cost" % id)
		_check(pool_ids.has(id), "%s can be offered to the Stray" % id)
		for other in [&"deserter", &"thief", &"medium"]:
			var other_ids := []
			for c in StarterContent.reward_pool(other):
				other_ids.append(c.id)
			_check(not other_ids.has(id), "%s is not in the %s pool" % [id, other])
	_check(IDS.size() == 15, "fifteen Stray cards")
	var deck := StarterContent.starter_deck(&"stray")
	var starter_ids := []
	for card in deck:
		starter_ids.append(card.id)
	for id in STARTERS:
		_check(starter_ids.has(id), "the starting deck holds %s" % id)
	_check(deck.size() == 10 and starter_ids.count(&"shove") == 3 and starter_ids.count(&"slip_past") == 2 and starter_ids.count(&"glimpse_exit") == 1, "the starting deck is 3 Shove, 2 Slip Past, 1 Glimpse the Exit and the four starters")
	# Keywords.
	_check(_load(&"nose_to_the_wind").ready, "Nose to the Wind is Ready")
	_check(_load(&"pounce").fading, "Pounce is Fading")
	_check(_load(&"bring_down").forgotten and _load(&"go_feral").forgotten, "Bring Down and Go Feral are Forgotten")
	_check(_load(&"howl").target_mode == CardData.TargetMode.ALL_ENEMIES, "Howl targets every enemy")
	_check(_load(&"bristle").target_mode == CardData.TargetMode.SELF and _load(&"hackles").target_mode == CardData.TargetMode.SELF and _load(&"go_feral").target_mode == CardData.TargetMode.SELF, "the self cards are self-targeted")


func _test_text() -> void:
	_check(_load(&"catch_the_scent").describe() == "Scent 2", "Catch the Scent text: %s" % _load(&"catch_the_scent").describe())
	_check(_load(&"snap").describe() == "Deal 4 x2", "Snap text: %s" % _load(&"snap").describe())
	_check(_load(&"run_down").describe() == "Deal 4, +3 per Scent (spends it)", "Run Down text: %s" % _load(&"run_down").describe())
	_check(_load(&"bristle").describe() == "Block 5, Malice +1 this turn", "Bristle text: %s" % _load(&"bristle").describe())
	_check(_load(&"nose_to_the_wind").keyword_lines() == PackedStringArray(["Ready"]), "Nose to the Wind shows Ready")


func _test_scent_cards() -> void:
	var catch_it := _load(&"catch_the_scent")
	var combat := _fight([catch_it], 2)
	_check(_play(combat, catch_it, 1) and combat.enemies[1].stacks(SCENT) == 2 and combat.energy == Combat.ENERGY_PER_TURN, "Catch the Scent marks the target for 2 and is free")
	var worry := _load(&"worry")
	var c2 := _fight([worry])
	_play(c2, worry)
	_check(c2.enemies[0].hp == 197 and c2.enemies[0].stacks(SCENT) == 1 and c2.enemies[0].status_turns(Combatant.Status.SHAKEN) == 1, "Worry: 3 damage (before its own Scent), Scent 1 and Shaken 1")
	var circle := _load(&"circle")
	var c3 := _fight([circle])
	_play(c3, circle)
	_check(c3.player.block == 6 and c3.enemies[0].stacks(SCENT) == 1, "Circle: Block 6 and Scent 1")
	var nose := _load(&"nose_to_the_wind")
	var deck: Array[CardData] = [nose]
	for i in 8:
		deck.append(_load(&"shove"))
	var c4 := _fight(deck)
	_check(c4.piles.hand.has(nose), "Nose to the Wind is in the opening hand (Ready)")
	_play(c4, nose)
	_check(c4.enemies[0].stacks(SCENT) == 1 and c4.has_choice(), "Nose to the Wind marks and opens a Glimpse")
	var old := _load(&"old_wound")
	var c5 := _fight([old])
	_play(c5, old)
	_check(c5.enemies[0].stacks(SCENT) == 2 and c5.enemies[0].status_turns(Combatant.Status.EXPOSED) == 2, "Old Wound: Scent 2 and Expose 2")
	var howl := _load(&"howl")
	var c6 := _fight([howl], 3)
	_play(c6, howl)
	var held := [c6.enemies[0].stacks(SCENT), c6.enemies[1].stacks(SCENT), c6.enemies[2].stacks(SCENT)]
	var shaken := [c6.enemies[0].status_turns(Combatant.Status.SHAKEN), c6.enemies[1].status_turns(Combatant.Status.SHAKEN), c6.enemies[2].status_turns(Combatant.Status.SHAKEN)]
	_check(held == [2, 0, 0] and shaken == [1, 1, 1], "Howl Shakens everyone and marks one quarry (Scent %s, Shaken %s)" % [str(held), str(shaken)])


func _test_attack_cards() -> void:
	var snap := _load(&"snap")
	var c1 := _fight([snap])
	_play(c1, snap)
	_check(c1.enemies[0].hp == 192, "Snap: 4 twice")
	var savage := _load(&"savage")
	var c2 := _fight([savage])
	_play(c2, savage)
	_check(c2.enemies[0].hp == 188, "Savage: 4 three times")
	var pounce := _load(&"pounce")
	var filler := _load(&"shove")
	var c3 := _fight([pounce, filler])
	_play(c3, pounce)
	_check(c3.enemies[0].hp == 190, "Pounce: 5 twice")
	var c4 := _fight([_load(&"pounce"), _load(&"slip_past")])
	c4.end_player_turn()
	_check(c4.piles.forgotten.size() == 1 and c4.piles.forgotten[0].id == &"pounce", "an unplayed Pounce is Forgotten at the end of the turn")
	var run_down := _load(&"run_down")
	var mark := _load(&"catch_the_scent")
	var c5 := _fight([mark, run_down])
	_play(c5, mark)
	_play(c5, run_down)
	_check(c5.enemies[0].hp == 200 - (4 + 3 * 2 + 2) and c5.enemies[0].stacks(SCENT) == 0, "Run Down with Scent 2: 4 + 6 + the 2 passive, and it spends the Scent (hp %d)" % c5.enemies[0].hp)
	var bring := _load(&"bring_down")
	var marks: Array[CardData] = [_load(&"catch_the_scent"), _load(&"catch_the_scent"), _load(&"catch_the_scent"), bring]
	var c6 := _fight(marks)
	for card in c6.piles.hand.duplicate():
		if card.id == &"catch_the_scent":
			_play(c6, card)
	_play(c6, bring)
	_check(c6.enemies[0].hp == 200 - (6 + 5 * 6 + 6) and c6.piles.forgotten.has(bring), "Bring Down with Scent 6: 6 + 30 + 6 passive, and it is Forgotten (hp %d)" % c6.enemies[0].hp)


func _test_malice_engine() -> void:
	var bristle := _load(&"bristle")
	var shove := _load(&"shove")
	var c1 := _fight([bristle, shove])
	_play(c1, bristle)
	_check(c1.player.block == 5 and c1.player.stacks(Combatant.Status.MALICE) == 1, "Bristle: Block 5 and Malice 1")
	_play(c1, shove)
	_check(c1.enemies[0].hp == 200 - 7, "the temporary Malice adds to the next hit")
	c1.end_player_turn()
	_check(c1.player.stacks(Combatant.Status.MALICE) == 0, "and is gone next turn")
	var hackles := _load(&"hackles")
	var c2 := _fight([hackles, _load(&"shove"), _load(&"shove")])
	_play(c2, hackles)
	c2.end_player_turn()
	_check(c2.player.stacks(Combatant.Status.MALICE) == 1, "Hackles: Malice 1 for the whole fight")
	var tear := _load(&"tear_loose")
	var c3 := _fight([tear])
	_play(c3, tear)
	_check(c3.enemies[0].hp == 194 and c3.player.stacks(Combatant.Status.MALICE) == 1, "Tear Loose: 3 twice, then permanent Malice 1")
	var feral := _load(&"go_feral")
	var c4 := _fight([feral])
	_play(c4, feral)
	_check(c4.player.stacks(Combatant.Status.MALICE) == 2 and c4.piles.forgotten.has(feral), "Go Feral: Malice 2, and the card is Forgotten")


## Malice and Scent each add to every hit, so a multi-hit card feeds both.
func _test_the_two_pillars_combine() -> void:
	var feral := _load(&"go_feral")
	var mark := _load(&"catch_the_scent")
	var savage := _load(&"savage")
	var combat := _fight([feral, mark, savage])
	combat.energy = 5
	_play(combat, feral)
	_play(combat, mark)
	_play(combat, savage)
	_check(combat.enemies[0].hp == 200 - 3 * (4 + 2 + 2), "Savage with Malice 2 and Scent 2: three hits of 8 (hp %d)" % combat.enemies[0].hp)
