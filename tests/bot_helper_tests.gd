extends "res://tests/test_base.gd"
## The smart bot's hand heuristics (_other_damage, _other_damage_total, _other_uses, _nominal_damage) use the
## engine's hit-count and damage-kind rules: a Surge card's hits scale with the energy, and the damage kinds other
## than plain DAMAGE count. Discovered by run_tests.gd.

const K := CardEffect.Kind


func run() -> int:
	_failures = 0
	_test_surge_hits_count()
	_test_other_damage_kinds_count()
	_test_uses_use_engine_hit_count()
	_test_nominal_damage_matches_hit_count()
	return _failures


func _hand(cards: Array[CardData]) -> Combat:
	var enemies: Array[EnemyData] = [EnemyData.make("E", 100, [] as Array[CardEffect])]
	var combat := Combat.new(Combatant.new("p", 40), cards, enemies, 1)
	combat.start()
	return combat


func _surge(amount: int, hits: int = 1) -> CardData:
	var card := CardData.make(&"surge", "Surge", 0, [CardEffect.make(K.DAMAGE, amount, 0, 0, hits, true)] as Array[CardEffect])
	card.surge = true
	return card


func _expose() -> CardData:
	return CardData.make(&"expose", "Expose", 1, [CardEffect.make(K.EXPOSE, 1)] as Array[CardEffect])


func _test_surge_hits_count() -> void:
	var expose := _expose()
	var surge := _surge(4)
	var combat := _hand([expose, surge])
	var energy := combat.energy
	var got := SmartPolicy._other_damage(combat, combat.piles.hand.find(expose), energy)
	_check(got == 4 * energy, "a Surge card's damage is amount x energy (got %d, want %d)" % [got, 4 * energy])
	_check(SmartPolicy._other_damage_total(combat, combat.piles.hand.find(expose)) == 4 * energy, "the total counts Surge hits too")


func _test_other_damage_kinds_count() -> void:
	var expose := _expose()
	var per_block := CardData.make(&"pb", "PerBlock", 1, [CardEffect.make(K.DAMAGE_PER_BLOCK, 1)] as Array[CardEffect])
	var combat := _hand([expose, per_block])
	var got := SmartPolicy._other_damage(combat, combat.piles.hand.find(expose), combat.energy)
	_check(got == SmartPolicy.TYPICAL_BLOCK, "a damage-per-Block card counts its nominal damage (got %d)" % got)
	var total := SmartPolicy._other_damage_total(combat, combat.piles.hand.find(expose))
	_check(total == SmartPolicy.TYPICAL_BLOCK, "and so does the total (got %d)" % total)
	# A card with no damage adds nothing.
	var guard := CardData.make(&"g", "Guard", 1, [CardEffect.make(K.BLOCK, 5)] as Array[CardEffect])
	var combat2 := _hand([expose, guard])
	_check(SmartPolicy._other_damage(combat2, combat2.piles.hand.find(expose), combat2.energy) == 0, "a Block card is not damage")


func _test_uses_use_engine_hit_count() -> void:
	var ward_card := CardData.make(&"w", "W", 1, [CardEffect.make(K.MALICE, 1)] as Array[CardEffect], CardData.TargetMode.SELF)
	var surge := _surge(2)
	var multi := CardData.make(&"m", "M", 1, [CardEffect.make(K.DAMAGE, 2, 0, 0, 3)] as Array[CardEffect])
	var combat := _hand([ward_card, surge, multi])
	var uses := SmartPolicy._other_uses(combat, combat.piles.hand.find(ward_card), combat.energy, true)
	_check(uses == combat.energy + 3, "damage uses are the engine's hit counts: Surge x energy plus 3 hits (got %d)" % uses)


func _test_nominal_damage_matches_hit_count() -> void:
	var effect := CardEffect.make(K.DAMAGE, 4, 0, 0, 2, true)
	var want := 4.0 * effect.hit_count(SmartPolicy.TYPICAL_SURGE_ENERGY)
	_check(is_equal_approx(SmartPolicy._nominal_damage(effect), want), "nominal damage uses CardEffect.hit_count (got %s, want %s)" % [SmartPolicy._nominal_damage(effect), want])
