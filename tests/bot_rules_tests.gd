extends "res://tests/test_base.gd"
## The bots read the engine's Surge, hit-count and Block rules instead of copying them: Combat.spent_energy /
## surge_scale / hit_count, CardEffect.scaled_amount / hit_count, a card's damage effects chaining the target's
## Block through Combat.preview_hit, and the greedy bot's HP guard using a Surge card's real HP cost.


func run() -> int:
	_failures = 0
	_surge_helpers()
	_effect_helpers()
	_damage_effects_chain_block()
	_greedy_hp_guard_uses_the_surge_cost()
	return _failures


func _fx(kind: CardEffect.Kind, amount: int, hits: int = 1, per_energy: bool = false) -> CardEffect:
	return CardEffect.make(kind, amount, 0, 0, hits, per_energy)


func _fight(deck: Array[CardData], enemy_hp: int = 100, player_hp: int = 40) -> Combat:
	var enemies: Array[EnemyData] = [EnemyData.make("E", enemy_hp, [] as Array[CardEffect])]
	var combat := Combat.new(Combatant.new("p", 40, player_hp), deck, enemies, 3)
	combat.start()
	return combat


func _surge_card(effects: Array[CardEffect]) -> CardData:
	var card := CardData.make(&"surge", "Surge", 0, effects)
	card.surge = true
	return card


func _surge_helpers() -> void:
	var surge := _surge_card([_fx(CardEffect.Kind.DAMAGE, 2, 2, true)] as Array[CardEffect])
	var plain := CardData.make(&"plain", "Plain", 2, [_fx(CardEffect.Kind.DAMAGE, 2, 2, true)] as Array[CardEffect])
	var combat := _fight([surge, plain] as Array[CardData])
	var energy := combat.energy
	_check(combat.spent_energy(surge) == energy and combat.surge_scale(surge) == energy, "a Surge card spends all the energy and scales by it")
	_check(combat.spent_energy(plain) == 2 and combat.surge_scale(plain) == 1, "any other card spends its cost and scales by 1")
	var effect: CardEffect = surge.effects[0]
	_check(combat.hit_count(surge, effect) == 2 * energy, "a per_energy Surge effect lands hits x energy")
	_check(combat.hit_count(plain, plain.effects[0]) == 2, "a per_energy effect on a non-Surge card lands its own hits")


func _effect_helpers() -> void:
	var scaled := _fx(CardEffect.Kind.BLOCK, 3, 1, true)
	_check(scaled.scaled_amount(4) == 12 and scaled.scaled_amount() == 3, "a per_energy amount is multiplied by the energy scale")
	var flat := _fx(CardEffect.Kind.BLOCK, 3)
	_check(flat.scaled_amount(4) == 3, "a flat amount ignores the energy scale")
	_check(_fx(CardEffect.Kind.DAMAGE, 1, 0).hit_count() == 1 and _fx(CardEffect.Kind.DAMAGE, 1, 3).hit_count(5) == 3 and _fx(CardEffect.Kind.DAMAGE, 1, 3, true).hit_count(5) == 15, "hit_count is at least 1 and scales only per_energy")


## Two damage effects on one card: the first wears the target's Block down and the second meets what is left,
## as the engine plays them. The bot must see the kill the engine makes.
func _damage_effects_chain_block() -> void:
	var card := CardData.make(&"two_hits", "Two Hits", 0, [_fx(CardEffect.Kind.DAMAGE, 5), _fx(CardEffect.Kind.DAMAGE, 5)] as Array[CardEffect])
	var combat := _fight([card] as Array[CardData], 4)
	combat.enemies[0].gain_block(6)
	_check(SmartPolicy._kills(combat, card, 0), "the bot sees that 6 Block absorbs only 6 of 10 damage across the card's two hits, killing a 4 HP enemy")
	_check(combat.play_card(0, 0) and combat.enemies[0].is_dead(), "the engine does kill it")
	var sturdy := _fight([card] as Array[CardData], 5)
	sturdy.enemies[0].gain_block(6)
	_check(not SmartPolicy._kills(sturdy, card, 0), "with 5 HP left over it does not kill: 4 gets through")
	sturdy.play_card(0, 0)
	_check(not sturdy.enemies[0].is_dead() and sturdy.enemies[0].hp == 1, "the engine leaves it at 1 HP")


func _greedy_hp_guard_uses_the_surge_cost() -> void:
	# Lose 2 HP per energy: at 3 energy it costs 6, leaving 14 - 6 = 8, under a quarter of 40.
	var surge := _surge_card([_fx(CardEffect.Kind.LOSE_HP, 2, 1, true), _fx(CardEffect.Kind.DAMAGE, 1)] as Array[CardEffect])
	var combat := _fight([surge] as Array[CardData], 100, 14)
	_check(surge.hp_cost() == 2 and surge.hp_cost(combat.surge_scale(surge)) == 2 * combat.energy, "setup: the card's real cost scales with the energy")
	_check(SimPolicy._too_costly_in_hp(combat, surge), "greedy refuses a Surge card whose scaled HP cost would leave it under a quarter of max HP")
	var healthy := _fight([surge] as Array[CardData], 100, 40)
	_check(not SimPolicy._too_costly_in_hp(healthy, surge), "with plenty of HP the same card is fine")
