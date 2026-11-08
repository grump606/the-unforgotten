extends "res://tests/test_base.gd"
## Shared builders for the smart_policy_*_tests.gd files (cards, enemies, combats, hands). Not a test itself.


func _card(id: StringName, cost: int, kind: CardEffect.Kind, amount: int) -> CardData:
	var effects: Array[CardEffect] = [CardEffect.make(kind, amount)]
	return CardData.make(id, String(id), cost, effects)


func _enemy(hp: int, damage: int) -> EnemyData:
	var intents: Array[CardEffect] = [CardEffect.make(CardEffect.Kind.DAMAGE, damage)]
	return EnemyData.make("e", hp, intents)


func _combat(hand_cards: Array[CardData], enemies: Array[EnemyData]) -> Combat:
	# A deck of at most HAND_SIZE cards is drawn whole into the opening hand.
	var combat := Combat.new(Combatant.new("p", 40), hand_cards, enemies, 1)
	combat.start()
	return combat


func _fx(kind: CardEffect.Kind, amount: int, bonus: int = 0, threshold: int = 0) -> CardEffect:
	return CardEffect.make(kind, amount, bonus, threshold)


func _custom(cost: int, effects: Array[CardEffect], mode: CardData.TargetMode = CardData.TargetMode.SINGLE_ENEMY) -> CardData:
	return CardData.make(&"c", "C", cost, effects, mode)


func _keyword_card(id: StringName, keyword: String, cost: int = 1, kind: CardEffect.Kind = CardEffect.Kind.DAMAGE, amount: int = 3) -> CardData:
	var card := _card(id, cost, kind, amount)
	if keyword != "":
		card.set(keyword, true)
	return card


func _surge_card(amount: int, hits: int) -> CardData:
	var effects: Array[CardEffect] = [CardEffect.make(CardEffect.Kind.DAMAGE, amount, 0, 0, hits, true)]
	var card := CardData.make(&"surge", "Surge", 0, effects)
	card.surge = true
	return card


## A started combat holding `hand_cards` exactly (set directly, bypassing the draw rules).
func _combat_with_hand(hand_cards: Array[CardData], enemy_hp: int = 40) -> Combat:
	var starter: Array[CardData] = [_card(&"starter", 9, CardEffect.Kind.BLOCK, 1)]
	var enemies: Array[EnemyData] = [_enemy(enemy_hp, 1)]
	var combat := _combat(starter, enemies)
	combat.piles.hand.clear()
	combat.piles.hand.append_array(hand_cards)
	return combat


func _play(combat: Combat, use_smart: bool) -> bool:
	return SmartPolicy.play_turn(combat) if use_smart else SimPolicy.play_turn(combat)


## A card of one effect on the given target mode (cost 1 unless given).
func _one(kind: CardEffect.Kind, amount: int, mode: CardData.TargetMode, temporary: bool = false, cost: int = 1) -> CardData:
	var effects: Array[CardEffect] = [CardEffect.make(kind, amount, 0, 0, 1, false, temporary)]
	return CardData.make(&"one", "One", cost, effects, mode)


func _dread() -> CardData:
	return StarterContent.status_card(&"dread")


func _murmur() -> CardData:
	return StarterContent.status_card(&"murmur")


func _strike(damage: int) -> CardData:
	return _card(&"strike", 1, CardEffect.Kind.DAMAGE, damage)


## Plays turns with the chosen policy until the fight ends or `turn_cap` turns pass; false on an illegal move.
func _run_fight(combat: Combat, use_smart: bool, turn_cap: int) -> bool:
	var turns := 0
	while SimPolicy.is_acting(combat) and turns < turn_cap:
		if not _play(combat, use_smart):
			return false
		turns += 1
	return true
