extends "res://tests/test_base.gd"
## The smart bot must price every CardEffect.Kind: a new kind it does not know would otherwise score 0 and
## be silently ignored (it also logs an error from the fallthrough branches). Companion to the every-kind
## walk in mechanics_tests.gd.


func run() -> int:
	_failures = 0
	_every_kind_has_a_deck_score()
	_every_kind_has_a_nominal_damage_or_is_not_damage()
	return _failures


func _card_with(kind: CardEffect.Kind) -> CardData:
	var filler := CardData.make(&"filler", "Filler", 1, [CardEffect.make(CardEffect.Kind.BLOCK, 1)] as Array[CardEffect])
	var effect := CardEffect.make(kind, 2, 5, 3)
	effect.card = filler
	return CardData.make(&"probe", "Probe", 1, [effect] as Array[CardEffect])


func _every_kind_has_a_deck_score() -> void:
	var weights := SmartPolicy._weights([] as Array[CardData])
	for kind_name in CardEffect.Kind.keys():
		var kind: CardEffect.Kind = CardEffect.Kind[kind_name]
		var card := _card_with(kind)
		_check(SmartPolicy.card_score(card, weights) != 0.0, "the smart bot scores a deck card with %s" % kind_name)


func _every_kind_has_a_nominal_damage_or_is_not_damage() -> void:
	for kind_name in CardEffect.Kind.keys():
		var kind: CardEffect.Kind = CardEffect.Kind[kind_name]
		var effect := CardEffect.make(kind, 2, 5, 3)
		if effect.is_damage():
			_check(SmartPolicy._nominal_damage(effect) > 0.0, "the smart bot estimates damage for %s" % kind_name)
