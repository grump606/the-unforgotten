extends "res://tests/test_base.gd"
## Shared builders for the combat rules test files (combat_core_tests.gd, combat_status_tests.gd):
## cards, decks and enemies with just the fields a test cares about. Not a test itself.


func _dmg(amount: int) -> Array[CardEffect]:
	return [CardEffect.make(CardEffect.Kind.DAMAGE, amount)]


func _card(cost: int, effects: Array[CardEffect]) -> CardData:
	return CardData.make(&"t", "T", cost, effects)


func _deck(count: int, card: CardData) -> Array[CardData]:
	var deck: Array[CardData] = []
	for i in count:
		deck.append(card)
	return deck


func _enemies(count: int, hp: int, intents: Array[CardEffect]) -> Array[EnemyData]:
	var list: Array[EnemyData] = []
	for i in count:
		list.append(EnemyData.make("E%d" % i, hp, intents))
	return list


func _mode_card(mode: CardData.TargetMode, effects: Array[CardEffect], cost: int = 0) -> CardData:
	return CardData.make(&"m", "M", cost, effects, mode)


func _expose(turns: int) -> CardEffect:
	return CardEffect.make(CardEffect.Kind.EXPOSE, turns)
