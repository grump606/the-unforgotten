extends "res://tests/test_base.gd"
## The tutorial and the card glossary build their rule numbers from the real constants, so changing a rule
## changes the text (and breaks this test if a number were hard-coded again).


func _all_tutorial_text() -> String:
	var text := ""
	for page in TutorialContent.pages():
		text += str(page.lead) + "\n"
		for item in page.items:
			text += (item if item is String else str(item.get("text", ""))) + "\n"
	return text


func run() -> int:
	_failures = 0
	var tutorial := _all_tutorial_text()
	_check(tutorial.contains("%d stops" % RunState._default_line().size()), "the tutorial names the line's real stop count")
	_check(tutorial.contains("keep up to %d cards" % Combat.HAND_SIZE), "the tutorial names the real hand size")
	_check(tutorial.contains("(%d at most)" % Combat.HAND_MAX), "the tutorial names the real hand maximum")
	var expose := "%.1fx" % (float(Combatant.EXPOSED_NUM) / Combatant.EXPOSED_DEN)
	var reduced := "%d%%" % (100 - 100 * Combatant.REDUCED_NUM / Combatant.REDUCED_DEN)
	_check(tutorial.contains("Takes %s damage" % expose), "the Exposed pill uses the real multiplier")
	_check(tutorial.contains("Deals %s less damage" % reduced) and tutorial.contains("Gains %s less Block" % reduced), "Shaken and Frayed use the real percentage")
	_check(CardGlossary.EFFECT_TEXT[CardEffect.Kind.EXPOSE][1].contains(expose), "the Expose glossary entry uses the real multiplier")
	_check(CardGlossary.EFFECT_TEXT[CardEffect.Kind.SHAKEN][1].contains(reduced), "the Shaken glossary entry uses the real percentage")
	_check(CardGlossary.EFFECT_TEXT[CardEffect.Kind.FRAYED][1].contains(reduced), "the Frayed glossary entry uses the real percentage")
	_check(CardGlossary.EFFECT_TEXT[CardEffect.Kind.DRAW][1].contains("(%d max)" % Combat.HAND_MAX), "the Draw glossary entry uses the real hand maximum")
	_check(CardGlossary.KEYWORD_TEXT["Anchor"].contains("%d kept" % Combat.HAND_SIZE), "the Anchor entry uses the real hand size")
	return _failures
