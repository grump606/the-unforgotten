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
	_check(tutorial.contains("%d stops" % RunState.default_line_size()), "the tutorial names the line's real stop count")
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
	_test_derived_text(tutorial, reduced)
	return _failures


## Key lists and rule wording are read from the live constants, so changing a key or a rule changes the text.
func _test_derived_text(tutorial: String, reduced: String) -> void:
	var piles: Array[String] = []
	for keycode in BattleOverlays.PILE_KEYS:
		piles.append(OS.get_keycode_string(keycode))
	var pile_text := ", ".join(piles.slice(0, -1)) + " or " + piles[-1]
	_check(pile_text == BattleKeys.pile_keys_text() and pile_text == "D, C, F or W", "the pile key text lists PILE_KEYS")
	_check(tutorial.contains("press " + pile_text) or tutorial.contains("Press " + pile_text), "the tutorial names the real pile keys")
	_check(tutorial.contains("press " + OS.get_keycode_string(BattleKeys.END_TURN_KEY) + ")"), "the tutorial names the real end-turn key")
	_check(tutorial.contains("(or " + OS.get_keycode_string(BattleKeys.END_TURN_KEY) + ")"), "the turn page names the real end-turn key")
	_check(BattleKeys.log_key_text() == OS.get_keycode_string(BattleKeys.LOG_KEY) and BattleKeys.log_key_text() == "L", "the log key text reads LOG_KEY")
	_check(tutorial.contains("Log (or press " + BattleKeys.log_key_text() + ")"), "the tutorial names the real combat-log key")
	# The status tooltips take their numbers from the same constants.
	var shaken := Combatant.new("Shaken", 10)
	shaken.apply_status(Combatant.Status.SHAKEN, 2)
	_check(BattleTooltips.status(shaken).contains("deals %s less damage" % reduced), "the Shaken tooltip uses the real percentage")
	var frayed := Combatant.new("Frayed", 10)
	frayed.apply_status(Combatant.Status.FRAYED, 2)
	_check(BattleTooltips.status(frayed).contains("gains %s less Block" % reduced), "the Frayed tooltip uses the real percentage")
	var exposed := Combatant.new("Exposed", 10)
	exposed.apply_status(Combatant.Status.EXPOSED, 2)
	_check(BattleTooltips.status(exposed).contains("Takes %.1fx damage" % (float(Combatant.EXPOSED_NUM) / Combatant.EXPOSED_DEN)), "the Exposed tooltip uses the real multiplier")
	var haunted := Combatant.new("Haunted", 10)
	haunted.apply_status(Combatant.Status.HAUNTED, 3)
	_check(BattleTooltips.status(haunted).contains(CardGlossary.HAUNT_FALLS), "the Haunt tooltip uses the shared decay wording")
	_check(tutorial.contains(CardGlossary.HAUNT_FALLS), "the tutorial uses the shared Haunt decay wording")
	_check(CardGlossary.EFFECT_TEXT[CardEffect.Kind.HAUNT][1].contains(CardGlossary.HAUNT_FALLS), "the glossary uses the shared Haunt decay wording")
	_check(not BattleTooltips.SHAKEN_TOOLTIP.contains("25") and not BattleTooltips.FRAYED_TOOLTIP.contains("25"), "no hand-copied 25% is left in the tooltips")

