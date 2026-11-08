extends RefCounted
## The Medium's mechanics: paying HP, Haunt, healing per Haunted enemy and damage from Haunt,
## then the real Medium cards. Registered by run_tests.gd. Tiny hand-made cards test the rules;
## the last test loads the shipped cards.

var _failures := 0


func run() -> int:
	_failures = 0
	_test_lose_hp()
	_test_haunt()
	_test_haunt_cap()
	_test_heal_and_haunt_damage()
	_test_medium_cards()
	return _failures


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAIL: " + label)


func _fx(kind: CardEffect.Kind, amount: int) -> CardEffect:
	return CardEffect.make(kind, amount)


func _self_card(cost: int, effects: Array[CardEffect]) -> CardData:
	return CardData.make(&"t", "T", cost, effects, CardData.TargetMode.SELF)


func _attack_card(cost: int, effects: Array[CardEffect]) -> CardData:
	return CardData.make(&"t", "T", cost, effects)


func _haunt_card(amount: int, mode: CardData.TargetMode = CardData.TargetMode.SINGLE_ENEMY) -> CardData:
	return CardData.make(&"h", "H", 0, [_fx(CardEffect.Kind.HAUNT, amount)], mode)


func _enemies(count: int, hp: int, intents: Array[CardEffect]) -> Array[EnemyData]:
	var list: Array[EnemyData] = []
	for i in count:
		list.append(EnemyData.make("E%d" % i, hp, intents))
	return list


## A started fight whose opening hand is `hand` (a deck no bigger than the hand size is dealt whole).
func _fight(hand: Array[CardData], enemy_hp: int = 100, intents: Array[CardEffect] = [], enemy_count: int = 1, player_hp: int = 40) -> Combat:
	var combat := Combat.new(Combatant.new("p", 40, player_hp), hand, _enemies(enemy_count, enemy_hp, intents))
	combat.start()
	return combat


func _play(combat: Combat, card: CardData, target: int = 0) -> bool:
	return combat.play_card(combat.piles.hand.find(card), target)


func _test_lose_hp() -> void:
	var c := Combatant.new("c", 20)
	c.gain_block(10)
	c.apply_status(Combatant.Status.EXPOSED, 2)
	_check(c.lose_hp(4) == 4 and c.hp == 16 and c.block == 10, "lose_hp ignores Block and Expose and leaves Block alone")
	_check(c.lose_hp(99) == 16 and c.hp == 0, "lose_hp cannot go below zero and reports what was lost")
	_check(c.lose_hp(-5) == 0, "a negative amount loses nothing")

	var confess := _attack_card(1, [_fx(CardEffect.Kind.LOSE_HP, 4), _fx(CardEffect.Kind.DAMAGE, 12)])
	_check(confess.hp_cost() == 4, "hp_cost sums the LOSE_HP effects")
	var combat := _fight([confess])
	_play(combat, confess)
	_check(combat.player.hp == 36 and combat.enemies[0].hp == 88, "paying 4 HP deals 12")

	var armored := _fight([confess])
	armored.player.gain_block(20)
	_play(armored, confess)
	_check(armored.player.hp == 36 and armored.player.block == 20, "Block does not pay the HP cost")

	# A card cannot be the one that kills you.
	var low := _fight([confess], 100, [], 1, 4)
	_check(not low.can_play(0) and not low.play_card(0, 0), "a 4 HP cost is refused at 4 HP")
	_check(low.player.hp == 4 and low.energy == Combat.ENERGY_PER_TURN and low.enemies[0].hp == 100, "a refused card changes nothing")
	var five := _fight([confess], 100, [], 1, 5)
	_check(five.can_play(0) and five.play_card(0, 0) and five.player.hp == 1, "the same card is allowed at 5 HP and leaves 1")
	var plain := _attack_card(0, [_fx(CardEffect.Kind.DAMAGE, 1)])
	var one_hp := _fight([plain], 100, [], 1, 1)
	_check(one_hp.can_play(0), "a card with no HP cost is playable at 1 HP")


func _test_haunt() -> void:
	var dread := _haunt_card(4)
	var combat := _fight([dread], 100, [_fx(CardEffect.Kind.BLOCK, 1)])
	_play(combat, dread)
	_check(combat.enemies[0].status_turns(Combatant.Status.HAUNTED) == 4 and combat.enemies[0].hp == 100, "Haunt does nothing until the enemy phase")
	var damage_taken: Array[int] = []
	var last_hp := combat.enemies[0].hp
	for i in 5:
		combat.end_player_turn()
		damage_taken.append(last_hp - combat.enemies[0].hp)
		last_hp = combat.enemies[0].hp
	_check(damage_taken == [4, 3, 2, 1, 0], "Haunt 4 deals 4, 3, 2, 1 over the next enemy phases (got %s)" % str(damage_taken))

	var second := _haunt_card(2)
	var stacked := _fight([dread, second])
	_play(stacked, dread)
	_play(stacked, second)
	_check(stacked.enemies[0].status_turns(Combatant.Status.HAUNTED) == 6, "Haunt stacks")

	# Block and Expose do not change Haunt damage.
	var expose := _attack_card(0, [_fx(CardEffect.Kind.EXPOSE, 3)])
	var shielded := _fight([dread, expose], 100, [_fx(CardEffect.Kind.BLOCK, 50)])
	_play(shielded, dread)
	_play(shielded, expose)
	shielded.end_player_turn()
	_check(shielded.enemies[0].hp == 96, "Haunt ignores the enemy's Block and Exposed (4, not 6)")

	# It happens before the enemy acts: a Haunt kill means no attack.
	var fragile := _fight([dread], 3, [_fx(CardEffect.Kind.DAMAGE, 20)], 2)
	_play(fragile, dread, 0)
	fragile.end_player_turn()
	_check(fragile.enemies[0].is_dead() and fragile.player.hp == 20, "an enemy killed by Haunt never acts (only the second enemy hit for 20)")

	var finisher := _fight([dread], 4, [_fx(CardEffect.Kind.DAMAGE, 20)])
	var won := [false]
	finisher.combat_ended.connect(func(victory: bool) -> void: won[0] = victory)
	_play(finisher, dread)
	finisher.end_player_turn()
	_check(won[0] and finisher.player.hp == 40 and finisher.phase == Combat.Phase.ENDED, "Haunt killing the last enemy wins before anyone attacks")

	var wave := _haunt_card(8, CardData.TargetMode.ALL_ENEMIES)
	var spread := _fight([wave], 100, [], 3)
	_play(spread, wave)
	var all_haunted := true
	for enemy in spread.enemies:
		all_haunted = all_haunted and enemy.status_turns(Combatant.Status.HAUNTED) == 8
	_check(all_haunted and spread.player.status_turns(Combatant.Status.HAUNTED) == 0, "Haunt to all lands on every enemy and not on the player")

	var odd := _fight([dread], 50, [_fx(CardEffect.Kind.HAUNT, 5)])
	odd.end_player_turn()
	_check(odd.player.status_turns(Combatant.Status.HAUNTED) == 0 and odd.player.hp == 40, "an enemy intent with HAUNT does nothing to the player")


func _capped(cap: int, count: int = 1) -> Array[EnemyData]:
	var list: Array[EnemyData] = []
	for i in count:
		list.append(EnemyData.make("C%d" % i, 100, [], &"", cap))
	return list


func _test_haunt_cap() -> void:
	var big := _haunt_card(8)
	var fight := Combat.new(Combatant.new("p", 40), [big, _haunt_card(2), _haunt_card(2), _haunt_card(2)] as Array[CardData], _capped(5))
	fight.start()
	_play(fight, big)
	_check(fight.enemies[0].status_turns(Combatant.Status.HAUNTED) == 5, "Haunt over the cap clamps to it")
	var adds := Combat.new(Combatant.new("p", 40), [_haunt_card(2), _haunt_card(2), _haunt_card(2)] as Array[CardData], _capped(5))
	adds.start()
	for card in adds.piles.hand.duplicate():
		_play(adds, card)
		var got: int = adds.enemies[0].status_turns(Combatant.Status.HAUNTED)
		_check(got <= 5, "stacks never pass the cap (got %d)" % got)
	_check(adds.enemies[0].status_turns(Combatant.Status.HAUNTED) == 5, "stacks add up to the cap, 2+2+2 gives 5")
	adds.end_player_turn()
	_check(adds.enemies[0].hp == 95 and adds.enemies[0].status_turns(Combatant.Status.HAUNTED) == 4, "a capped enemy still takes its Haunt and decays by 1")
	var free := _fight([big])
	_play(free, big)
	_check(free.enemies[0].status_turns(Combatant.Status.HAUNTED) == 8, "an uncapped enemy keeps all 8 Haunt")
	var sweep := _haunt_card(8, CardData.TargetMode.ALL_ENEMIES)
	var mixed_list := _capped(5, 1)
	mixed_list.append(EnemyData.make("U", 100, []))
	var mixed := Combat.new(Combatant.new("p", 40), [sweep] as Array[CardData], mixed_list)
	mixed.start()
	_play(mixed, sweep)
	_check(mixed.enemies[0].status_turns(Combatant.Status.HAUNTED) == 5 and mixed.enemies[1].status_turns(Combatant.Status.HAUNTED) == 8, "Haunt to all caps only the capped enemy")
	var scaled := StarterContent.scaled(_capped(5)[0], 1.5)
	_check(scaled.max_haunt == 5, "scaling an enemy keeps its Haunt cap")
	var direct := EnemyUnit.new(_capped(3)[0])
	direct.apply_status(Combatant.Status.HAUNTED, 9)
	direct.apply_status(Combatant.Status.EXPOSED, 9)
	_check(direct.status_turns(Combatant.Status.HAUNTED) == 3 and direct.status_turns(Combatant.Status.EXPOSED) == 9, "the cap applies to Haunt only")


func _test_heal_and_haunt_damage() -> void:
	var tithe := _self_card(0, [_fx(CardEffect.Kind.HEAL_PER_HAUNTED, 3)])
	var dread := _haunt_card(4)
	var wave := _haunt_card(1, CardData.TargetMode.ALL_ENEMIES)
	var hurt := _fight([tithe], 100, [], 3, 20)
	_play(hurt, tithe)
	_check(hurt.player.hp == 20, "with no Haunted enemies it heals nothing")

	var two := _fight([dread, dread, tithe], 100, [], 3, 20)
	two.play_card(two.piles.hand.find(dread), 0)
	two.play_card(two.piles.hand.find(dread), 1)
	two.play_card(two.piles.hand.find(tithe))
	_check(two.player.hp == 26, "it heals 3 for each of the 2 Haunted enemies")

	var capped := _fight([wave, tithe], 100, [], 3, 38)
	_play(capped, wave)
	_play(capped, tithe)
	_check(capped.player.hp == 40, "healing never goes above max HP")

	var reckoning := _attack_card(0, [_fx(CardEffect.Kind.DAMAGE_PER_HAUNT, 2)])
	var none := _fight([reckoning])
	_play(none, reckoning)
	_check(none.enemies[0].hp == 100, "Reckoning on an un-Haunted target deals nothing")
	var marked := _fight([dread, reckoning])
	_play(marked, dread)
	_play(marked, reckoning)
	_check(marked.enemies[0].hp == 92 and marked.enemies[0].status_turns(Combatant.Status.HAUNTED) == 4, "Reckoning deals double the target's Haunt and leaves the Haunt in place")
	var elsewhere := _fight([dread, reckoning], 100, [], 2)
	elsewhere.play_card(elsewhere.piles.hand.find(dread), 1)
	elsewhere.play_card(elsewhere.piles.hand.find(reckoning), 0)
	_check(elsewhere.enemies[0].hp == 100 and elsewhere.enemies[1].hp == 100, "only the target's own Haunt counts")


func _test_medium_cards() -> void:
	var cards := {}
	for path in StarterContent.ALL_CARD_PATHS:
		var card := load(path) as CardData
		cards[card.id] = card
	for id in [&"confess", &"lingering_dread", &"cold_whisper", &"penance", &"grave_chill", &"spirit_tithe", &"seance", &"bleed_the_veil", &"reckoning"]:
		_check(cards.has(id) and (cards[id] as CardData).character == &"medium", "%s is a Medium card" % id)
	_check(cards[&"confess"].describe() == "Lose 4 HP, Deal 12" and cards[&"confess"].hp_cost() == 4, "Confess text and HP cost")
	_check(cards[&"seance"].describe() == "Lose 3 HP, Draw 3, Gain 1 energy", "Seance text")
	_check(cards[&"spirit_tithe"].describe() == "Heal 4 per Haunted enemy", "Spirit Tithe text")
	_check(cards[&"reckoning"].describe() == "Deal 3x the target's Haunt", "Reckoning text")
	_check(cards[&"bleed_the_veil"].target_mode == CardData.TargetMode.ALL_ENEMIES and cards[&"bleed_the_veil"].hp_cost() == 6, "Bleed the Veil hits all enemies and costs 6 HP")

	var bleed: CardData = cards[&"bleed_the_veil"]
	var fight := _fight([bleed], 100, [], 3)
	fight.play_card(0)
	var every := true
	for enemy in fight.enemies:
		every = every and enemy.status_turns(Combatant.Status.HAUNTED) == 6
	_check(every and fight.player.hp == 34, "Bleed the Veil costs 6 HP and Haunts all three enemies for 6")

	# Seance: pay 3 HP, draw 3 more cards, energy unchanged (cost 1, gains 1). Deal a hand with
	# nothing else in the way by giving it a big deck and finding the card in the opening hand.
	var seance: CardData = cards[&"seance"]
	var deck: Array[CardData] = [seance]
	for i in 12:
		deck.append(_self_card(1, [_fx(CardEffect.Kind.BLOCK, 1)]))
	var draw_fight: Combat = null
	for seed_value in 200:
		var candidate := Combat.new(Combatant.new("p", 40), deck, _enemies(1, 100, []), seed_value)
		candidate.start()
		if candidate.piles.hand.has(seance):
			draw_fight = candidate
			break
	_check(draw_fight != null, "setup: found a seed that deals Seance in the opening hand")
	if draw_fight != null:
		var hand_before := draw_fight.piles.hand.size()
		draw_fight.play_card(draw_fight.piles.hand.find(seance))
		_check(draw_fight.player.hp == 37 and draw_fight.piles.hand.size() == hand_before - 1 + 3 and draw_fight.energy == Combat.ENERGY_PER_TURN, "Seance: -3 HP, +3 cards, net energy unchanged")

	# A short chain: Lingering Dread then Reckoning deals triple the Haunt.
	var dread: CardData = cards[&"lingering_dread"]
	var reckoning: CardData = cards[&"reckoning"]
	var chain := _fight([dread, reckoning], 100)
	_play(chain, dread)
	_play(chain, reckoning)
	_check(chain.enemies[0].hp == 88, "Lingering Dread then Reckoning deals 12")
