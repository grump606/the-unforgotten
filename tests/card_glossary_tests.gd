extends "res://tests/test_base.gd"
## CardGlossary: every effect kind and keyword has an explanation, and a card lists each term once.
## Discovered by run_tests.gd.


func run() -> int:
	_failures = 0
	_test_every_kind_and_keyword_explained()
	_test_card_entries()
	return _failures


func _test_every_kind_and_keyword_explained() -> void:
	for kind in CardEffect.Kind.values():
		_check(CardGlossary.EFFECT_TEXT.has(kind), "glossary explains effect kind %s" % CardEffect.Kind.find_key(kind))
	var card := CardData.new()
	card.forgotten = true
	card.fading = true
	card.ready = true
	card.anchor = true
	card.dormant = true
	card.surge = true
	card.oath = true
	card.discard_effects = [CardEffect.make(CardEffect.Kind.BLOCK, 1)]
	for keyword in card.keyword_lines():
		_check(CardGlossary.KEYWORD_TEXT.has(keyword), "glossary explains keyword %s" % keyword)


func _test_card_entries() -> void:
	var plain := CardData.make(&"t", "T", 1, [CardEffect.make(CardEffect.Kind.DAMAGE, 5), CardEffect.make(CardEffect.Kind.DAMAGE, 3)])
	var terms: Array = CardGlossary.entries(plain).map(func(pair): return pair[0])
	_check(terms == ["Deal"], "a card lists a repeated effect once: %s" % str(terms))
	var forgotten := CardData.make(&"f", "F", 1, [CardEffect.make(CardEffect.Kind.HAUNT, 2)])
	forgotten.forgotten = true
	var text := CardGlossary.text(forgotten)
	_check(text.begins_with("Forgotten: ") and text.contains("\nHaunt: "), "keywords come first, then effects: " + text)
	_check(CardGlossary.text(null) == "" and CardGlossary.entries(null).is_empty(), "no card, no entries")
	_check(CardGlossary.full_text(forgotten).begins_with("F (1)\n"), "full text leads with name and cost")
