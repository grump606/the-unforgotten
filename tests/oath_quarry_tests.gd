extends "res://tests/test_base.gd"
## An Oath reacts only to plays made after it was Sworn, never to the card that swears it. That holds for
## the QUARRY_DIES trigger too, even when the Oath card's own play kills the quarry.

const K := CardEffect.Kind
const T := CardData.OathTrigger


func run() -> int:
	_failures = 0
	_oath_does_not_react_to_its_own_kill()
	_earlier_oath_reacts_to_the_kill()
	_shipped_quarry_oath_deals_no_damage()
	return _failures


func _fx(kind: K, amount: int) -> CardEffect:
	return CardEffect.make(kind, amount)


func _quarry_oath(now: Array[CardEffect]) -> CardData:
	var card := CardData.make(&"quarry_oath", "Quarry Oath", 0, now, CardData.TargetMode.SINGLE_ENEMY)
	card.oath = true
	card.oath_trigger = T.QUARRY_DIES
	card.oath_effects = [_fx(K.BLOCK, 3)] as Array[CardEffect]
	return card


func _fight(deck: Array[CardData]) -> Combat:
	var list: Array[EnemyData] = [EnemyData.make("A", 5, [] as Array[CardEffect]), EnemyData.make("B", 100, [] as Array[CardEffect])]
	var combat := Combat.new(Combatant.new("p", 40), deck, list, 3)
	combat.start()
	return combat


func _play(combat: Combat, card: CardData, target: int = 0) -> bool:
	return combat.play_card(combat.piles.hand.find(card), target)


func _oath_does_not_react_to_its_own_kill() -> void:
	var mark := CardData.make(&"mark", "Mark", 0, [_fx(K.SCENT, 4)] as Array[CardEffect])
	var oath := _quarry_oath([_fx(K.DAMAGE, 50)] as Array[CardEffect])
	var combat := _fight([mark, oath] as Array[CardData])
	_check(_play(combat, mark), "the quarry is marked")
	_check(_play(combat, oath), "the Oath card is played")
	_check(combat.enemies[0].is_dead() and combat.piles.sworn.has(oath), "the Oath's own play killed the quarry and swore the Oath")
	_check(combat.player.block == 0, "the Oath does not react to the kill its own play caused (block %d)" % combat.player.block)


func _earlier_oath_reacts_to_the_kill() -> void:
	var mark := CardData.make(&"mark", "Mark", 0, [_fx(K.SCENT, 4)] as Array[CardEffect])
	var kill := CardData.make(&"kill", "Kill", 0, [_fx(K.DAMAGE, 50)] as Array[CardEffect])
	var oath := _quarry_oath([] as Array[CardEffect])
	oath.target_mode = CardData.TargetMode.SELF
	var combat := _fight([oath, mark, kill] as Array[CardData])
	_play(combat, oath)
	_play(combat, mark)
	_play(combat, kill)
	_check(combat.player.block == 3, "an Oath sworn earlier still reacts to the quarry's death (block %d)" % combat.player.block)


## Today no shipped Quarry Oath kills anything when played, so the rule above changes no shipped card.
func _shipped_quarry_oath_deals_no_damage() -> void:
	for path in StarterContent.ALL_CARD_PATHS:
		var card := load(path) as CardData
		if card == null or not card.oath or card.oath_trigger != T.QUARRY_DIES:
			continue
		for effect in card.effects:
			_check(not effect.is_damage(), "%s: a Quarry Oath's own play deals no damage" % card.id)
