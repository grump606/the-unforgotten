extends "res://tests/test_base.gd"
## ON_BLOCK_GAINED ("When you gain Block from a card") counts only Block the played card's OWN effects gave.
## Block from a relic (PLAYS_BLOCK) or from an Oath effect of the same play never triggers it.
## Discovered by run_tests.gd.

const K := CardEffect.Kind
const T := CardData.OathTrigger


func run() -> int:
	_failures = 0
	_test_block_card_triggers()
	_test_relic_block_does_not_trigger()
	_test_oath_block_does_not_trigger()
	_test_oath_block_never_chains()
	_test_shipped_bulwark_vow()
	return _failures


func _fx(kind: K, amount: int) -> CardEffect:
	return CardEffect.make(kind, amount)


func _oath(trigger: T, sworn: Array[CardEffect]) -> CardData:
	var card := CardData.make(&"oath", "Oath", 0, [] as Array[CardEffect], CardData.TargetMode.SELF)
	card.oath = true
	card.oath_trigger = trigger
	card.oath_effects = sworn
	return card


func _plain(effects: Array[CardEffect]) -> CardData:
	return CardData.make(&"plain", "Plain", 0, effects, CardData.TargetMode.SELF)


func _fight(hand: Array[CardData], relics: Array[RelicData] = []) -> Combat:
	var enemies: Array[EnemyData] = [EnemyData.make("E", 100, [] as Array[CardEffect])]
	var combat := Combat.new(Combatant.new("p", 40), hand, enemies, 1, relics)
	combat.start()
	return combat


func _play(combat: Combat, card: CardData) -> bool:
	return combat.play_card(combat.piles.hand.find(card), 0)


func _plays_block_relic() -> Array[RelicData]:
	return [RelicData.make(&"t_relic", "T", RelicData.Kind.PLAYS_BLOCK, 4, 10)]


func _test_block_card_triggers() -> void:
	var vow := _oath(T.ON_BLOCK_GAINED, [_fx(K.DAMAGE, 3)])
	var guard := _plain([_fx(K.BLOCK, 5)])
	var combat := _fight([vow, guard])
	_play(combat, vow)
	_play(combat, guard)
	_check(combat.enemies[0].hp == 97, "a card that gains Block triggers the Oath (hp %d)" % combat.enemies[0].hp)


func _test_relic_block_does_not_trigger() -> void:
	# Plays 1 and 2 are the Oath and a filler; play 3 is a 0-Block card, and the relic gives the Block.
	var vow := _oath(T.ON_BLOCK_GAINED, [_fx(K.DAMAGE, 3)])
	var filler := _plain([] as Array[CardEffect])
	var no_block := _plain([] as Array[CardEffect])
	var combat := _fight([vow, filler, no_block], _plays_block_relic())
	_play(combat, vow)
	_play(combat, filler)
	_play(combat, no_block)
	_check(combat.player.block == 4, "the relic gave the 3rd play its Block (got %d)" % combat.player.block)
	_check(combat.enemies[0].hp == 100, "Block from the relic does not trigger the Oath (hp %d)" % combat.enemies[0].hp)
	# The same Nth play with a card that itself gains Block still triggers.
	var vow2 := _oath(T.ON_BLOCK_GAINED, [_fx(K.DAMAGE, 3)])
	var guard := _plain([_fx(K.BLOCK, 2)])
	var combat2 := _fight([vow2, filler, guard], _plays_block_relic())
	_play(combat2, vow2)
	_play(combat2, filler)
	_play(combat2, guard)
	_check(combat2.enemies[0].hp == 97, "a Block card on the relic's play still triggers (hp %d)" % combat2.enemies[0].hp)


func _test_oath_block_does_not_trigger() -> void:
	var vow := _oath(T.ON_BLOCK_GAINED, [_fx(K.DAMAGE, 3)])
	var shield_each := _oath(T.EACH_PLAY, [_fx(K.BLOCK, 2)])
	var no_block := _plain([] as Array[CardEffect])
	var combat := _fight([vow, shield_each, no_block])
	_play(combat, vow)
	_play(combat, shield_each)
	_play(combat, no_block)
	_check(combat.player.block == 2, "the EACH_PLAY Oath gave Block (got %d)" % combat.player.block)
	_check(combat.enemies[0].hp == 100, "Block from another Oath does not trigger the Oath (hp %d)" % combat.enemies[0].hp)
	# FIRST_PLAY Oaths are the same.
	var vow2 := _oath(T.ON_BLOCK_GAINED, [_fx(K.DAMAGE, 3)])
	var shield_first := _oath(T.FIRST_PLAY, [_fx(K.BLOCK, 2)])
	var no_block2 := _plain([] as Array[CardEffect])
	var combat2 := _fight([vow2, shield_first, no_block2])
	_play(combat2, vow2)
	_play(combat2, shield_first)
	combat2.end_player_turn()
	_play(combat2, no_block2)
	_check(combat2.enemies[0].hp == 100, "Block from a FIRST_PLAY Oath does not trigger it (hp %d)" % combat2.enemies[0].hp)


func _test_oath_block_never_chains() -> void:
	# A Block-giving ON_BLOCK_GAINED Oath and a second one: a Block card fires each exactly once.
	var shield := _oath(T.ON_BLOCK_GAINED, [_fx(K.BLOCK, 2)])
	var strike := _oath(T.ON_BLOCK_GAINED, [_fx(K.DAMAGE, 3)])
	var guard := _plain([_fx(K.BLOCK, 5)])
	var combat := _fight([shield, strike, guard])
	_play(combat, shield)
	_play(combat, strike)
	_play(combat, guard)
	_check(combat.player.block == 7, "the Block Oath fired once (got %d)" % combat.player.block)
	_check(combat.enemies[0].hp == 97, "the Oath's own Block did not re-trigger the other Oath (hp %d)" % combat.enemies[0].hp)
	# A card with no Block, with an EACH_PLAY Oath giving Block: nothing chains into the ON_BLOCK_GAINED Oath.
	var each := _oath(T.EACH_PLAY, [_fx(K.BLOCK, 2)])
	var strike2 := _oath(T.ON_BLOCK_GAINED, [_fx(K.DAMAGE, 3)])
	var plain := _plain([] as Array[CardEffect])
	var combat2 := _fight([each, strike2, plain])
	_play(combat2, each)
	_play(combat2, strike2)
	_play(combat2, plain)
	_check(combat2.enemies[0].hp == 100, "an EACH_PLAY Oath's Block never chains into an ON_BLOCK_GAINED Oath")


func _test_shipped_bulwark_vow() -> void:
	var vow := load(StarterContent.BULWARK_VOW_PATH) as CardData
	_check(vow != null and vow.oath_trigger == T.ON_BLOCK_GAINED, "Bulwark Vow is the shipped ON_BLOCK_GAINED Oath")
	if vow == null:
		return
	var guard := _plain([_fx(K.BLOCK, 5)])
	var combat := _fight([vow, guard])
	combat.energy = 10
	_play(combat, vow)
	var before := combat.enemies[0].hp
	_play(combat, guard)
	_check(combat.enemies[0].hp < before, "a Block card triggers the shipped Bulwark Vow")
