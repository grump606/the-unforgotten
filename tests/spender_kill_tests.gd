extends "res://tests/test_base.gd"
## A Scent-spending hit (DAMAGE_PER_SCENT) that kills the quarry still counts as the quarry's death: the
## QUARRY_KILL_HEAL relic heals and the QUARRY_DIES Oaths fire, but no Scent is passed on (it was spent, so
## SCENT_HEIR has nothing to carry either). A spender that does not kill, and a plain-damage kill, behave as before.

const K := CardEffect.Kind
const SCENT := Combatant.Status.SCENT


func run() -> int:
	_failures = 0
	_spender_kill_heals()
	_spender_kill_fires_earlier_oath()
	_spender_kill_passes_nothing_even_with_heir()
	_spender_without_kill_changes_nothing()
	_spender_kill_of_unmarked_enemy_is_no_quarry_death()
	_plain_kill_still_passes_half()
	_spender_kill_of_the_last_enemy()
	return _failures


func _fx(kind: K, amount: int, bonus: int = 0) -> CardEffect:
	return CardEffect.make(kind, amount, bonus)


func _card(effects: Array[CardEffect], mode: CardData.TargetMode = CardData.TargetMode.SINGLE_ENEMY) -> CardData:
	return CardData.make(&"t", "T", 0, effects, mode)


func _relic(kind: RelicData.Kind, amount: int) -> RelicData:
	return RelicData.make(&"t_relic", "T", kind, amount, 10)


## Two enemies (A with `a_hp`, B with 100), the player at 20/40 HP, every card of `deck` in hand.
func _fight(deck: Array[CardData], a_hp: int, relics: Array[RelicData] = [] as Array[RelicData], enemies: int = 2) -> Combat:
	var list: Array[EnemyData] = [EnemyData.make("A", a_hp, [] as Array[CardEffect])]
	if enemies == 2:
		list.append(EnemyData.make("B", 100, [] as Array[CardEffect]))
	var combat := Combat.new(Combatant.new("p", 40, 20), deck, list, 1, relics)
	combat.start()
	return combat


func _play(combat: Combat, card: CardData, target: int = 0) -> void:
	var index := combat.piles.hand.find(card)
	_check(index != -1 and combat.play_card(index, target), "the test card is played")


func _heal_relics() -> Array[RelicData]:
	return [_relic(RelicData.Kind.QUARRY_KILL_HEAL, 3)] as Array[RelicData]


func _mark(amount: int) -> CardData:
	return _card([_fx(K.SCENT, amount)] as Array[CardEffect])


func _spender(amount: int) -> CardData:
	return _card([_fx(K.DAMAGE_PER_SCENT, amount, 1)] as Array[CardEffect])


func _spender_kill_heals() -> void:
	var mark := _mark(3)
	var spend := _spender(40)
	var combat := _fight([mark, spend] as Array[CardData], 20, _heal_relics())
	_play(combat, mark)
	_play(combat, spend)
	_check(combat.enemies[0].is_dead(), "the spender killed the quarry")
	_check(combat.player.hp == 23, "a spender kill still pays the quarry-kill heal (hp %d)" % combat.player.hp)
	_check(combat.enemies[1].stacks(SCENT) == 0 and combat.enemies[0].stacks(SCENT) == 0, "no Scent reaches a living enemy: it was spent")


func _spender_kill_fires_earlier_oath() -> void:
	var oath := _card([] as Array[CardEffect], CardData.TargetMode.SELF)
	oath.oath = true
	oath.oath_trigger = CardData.OathTrigger.QUARRY_DIES
	oath.oath_effects = [_fx(K.BLOCK, 3)] as Array[CardEffect]
	var mark := _mark(3)
	var spend := _spender(40)
	var combat := _fight([oath, mark, spend] as Array[CardData], 20)
	_play(combat, oath)
	_play(combat, mark)
	_play(combat, spend)
	_check(combat.enemies[0].is_dead() and combat.player.block == 3, "a spender kill fires a QUARRY_DIES Oath sworn earlier (block %d)" % combat.player.block)
	_check(combat.enemies[1].stacks(SCENT) == 0, "and passes no Scent on")


func _spender_kill_passes_nothing_even_with_heir() -> void:
	var mark := _mark(5)
	var spend := _spender(60)
	var heir: Array[RelicData] = [_relic(RelicData.Kind.SCENT_HEIR, 2)] as Array[RelicData]
	var combat := _fight([mark, spend] as Array[CardData], 20, heir)
	_play(combat, mark)
	_play(combat, spend)
	_check(combat.enemies[0].is_dead() and combat.enemies[1].stacks(SCENT) == 0, "with SCENT_HEIR a spender kill passes no Scent (got %d)" % combat.enemies[1].stacks(SCENT))


func _spender_without_kill_changes_nothing() -> void:
	var oath := _card([] as Array[CardEffect], CardData.TargetMode.SELF)
	oath.oath = true
	oath.oath_trigger = CardData.OathTrigger.QUARRY_DIES
	oath.oath_effects = [_fx(K.BLOCK, 3)] as Array[CardEffect]
	var mark := _mark(3)
	var spend := _spender(2)
	var combat := _fight([oath, mark, spend] as Array[CardData], 100, _heal_relics())
	_play(combat, oath)
	_play(combat, mark)
	_play(combat, spend)
	_check(not combat.enemies[0].is_dead() and combat.enemies[0].stacks(SCENT) == 0, "a spender that does not kill spends the Scent and nothing else")
	_check(combat.player.hp == 20 and combat.player.block == 0, "no heal and no Oath without a death (hp %d, block %d)" % [combat.player.hp, combat.player.block])
	_check(combat.enemies[1].stacks(SCENT) == 0, "no Scent appears elsewhere")


## Killing an enemy that held no Scent with a spender is no quarry's death: no heal.
func _spender_kill_of_unmarked_enemy_is_no_quarry_death() -> void:
	var spend := _spender(60)
	var combat := _fight([spend] as Array[CardData], 20, _heal_relics())
	_play(combat, spend)
	_check(combat.enemies[0].is_dead() and combat.player.hp == 20, "an unmarked enemy killed by a spender is no quarry kill (hp %d)" % combat.player.hp)


func _plain_kill_still_passes_half() -> void:
	var mark := _mark(5)
	var kill := _card([_fx(K.DAMAGE, 200)] as Array[CardEffect])
	var combat := _fight([mark, kill] as Array[CardData], 20, _heal_relics())
	_play(combat, mark)
	_play(combat, kill)
	_check(combat.enemies[0].is_dead() and combat.enemies[1].stacks(SCENT) == 2, "a plain-damage quarry kill passes half the stack (got %d)" % combat.enemies[1].stacks(SCENT))
	_check(combat.player.hp == 23, "and heals once (hp %d)" % combat.player.hp)


func _spender_kill_of_the_last_enemy() -> void:
	var mark := _mark(3)
	var spend := _spender(60)
	var combat := _fight([mark, spend] as Array[CardData], 20, _heal_relics(), 1)
	_play(combat, mark)
	_play(combat, spend)
	_check(combat.outcome == Combat.Outcome.VICTORY and combat.player.hp == 23, "the last quarry killed by a spender still heals (hp %d)" % combat.player.hp)
