class_name CardGlossary
extends RefCounted
## Plain-language explanations of every mechanic a card uses, shown in the card's tooltip. One entry per term,
## in a fixed order (keywords first, then effects in the order the card uses them), so a card never repeats a term.
## Numbers in the effect entries match the status tooltips in run/battle/battle_tooltips.gd; keep the two in step.

## Rule numbers, built from the combat constants so a rule change reaches every tooltip and tutorial page.
const EXPOSED_X := "%.1f" % (float(Combatant.EXPOSED_NUM) / Combatant.EXPOSED_DEN)
const REDUCED_PERCENT := "%d%%" % (100 - 100 * Combatant.REDUCED_NUM / Combatant.REDUCED_DEN)
## How Haunt decays each enemy phase (Combatant.StatusKind.DECAYING); the one wording used by the glossary,
## the status tooltip and the tutorial.
const HAUNT_FALLS := "Haunt falls by 1"

const KEYWORD_TEXT := {
	"Forgotten": "Once played, leaves the fight for good (returns after).",
	"Fading": "Still in hand at end of turn: becomes Forgotten. Not kept.",
	"Ready": "Starts the fight in your opening hand.",
	"Anchor": "Can't be discarded. Doesn't count toward the %d kept." % Combat.HAND_SIZE,
	"Dormant": "Can't be played. Enemies shuffle these in.",
	"Surge": "Spends all your energy. Effect grows with it.",
	"Oath": "Played once, then Sworn for the fight. Its Oath effect fires on its trigger.",
	"Discarded": "Has an effect when thrown away at end of turn.",
	"Remembered": "Upgraded at a rest stop, for the rest of the run.",
}

const EFFECT_TEXT := {
	CardEffect.Kind.DAMAGE: ["Deal", "Damage to the target. Block absorbs it first."],
	CardEffect.Kind.BLOCK: ["Block", "Absorbs damage until your next turn."],
	CardEffect.Kind.DRAW: ["Draw", "Take cards into your hand (%d max)." % Combat.HAND_MAX],
	CardEffect.Kind.EXPOSE: ["Expose", "Target takes " + EXPOSED_X + "x damage for N turns."],
	CardEffect.Kind.HOLD: ["Hold", "Keep up to N leftover Block next turn."],
	CardEffect.Kind.DAMAGE_PER_BLOCK: ["Your Block", "Damage scales with your current Block."],
	CardEffect.Kind.DAMAGE_IF_BLOCK: ["Block bonus", "Deals the higher number with enough Block."],
	CardEffect.Kind.THORNS: ["Thorns", "Attackers take N damage this turn."],
	CardEffect.Kind.GAIN_ENERGY: ["Energy", "Gain energy now, on top of the turn's."],
	CardEffect.Kind.DAMAGE_PER_PLAY: ["Combo", "More damage per card played earlier this turn."],
	CardEffect.Kind.HAUNT: ["Haunt", "Target takes N at enemy phase (ignores Block), then " + HAUNT_FALLS + "."],
	CardEffect.Kind.LOSE_HP: ["Lose HP", "You pay this much HP to play it."],
	CardEffect.Kind.HEAL_PER_HAUNTED: ["Heal per Haunted", "Heal for each Haunted enemy."],
	CardEffect.Kind.DAMAGE_PER_HAUNT: ["Haunt damage", "Damage scales with the target's Haunt."],
	CardEffect.Kind.SHAKEN: ["Shaken", "Target deals " + REDUCED_PERCENT + " less damage for N turns."],
	CardEffect.Kind.FRAYED: ["Frayed", "Gains " + REDUCED_PERCENT + " less Block for N turns."],
	CardEffect.Kind.MALICE: ["Malice", "Flat bonus to each hit you deal. Stacks; lasts the fight."],
	CardEffect.Kind.WARD: ["Ward", "Flat bonus to Block from cards. Stacks; lasts the fight."],
	CardEffect.Kind.GLIMPSE: ["Glimpse", "Look at the top N cards of your draw pile; discard any."],
	CardEffect.Kind.ADD_CARD: ["Add", "Puts copies of a card into the pile named."],
	CardEffect.Kind.RECALL: ["Recall", "Return N Forgotten cards to your hand."],
	CardEffect.Kind.DAMAGE_PER_FORGOTTEN: ["Forgotten damage", "Damage scales with the Forgotten pile."],
	CardEffect.Kind.SCENT: ["Scent", "Marks your quarry: your hits on it deal more. One enemy at a time (max 8)."],
	CardEffect.Kind.DAMAGE_PER_SCENT: ["Scent damage", "Extra damage per Scent on the target, then spends it."],
}


## The [term, explanation] pairs for a card, in display order, no term twice. Empty for null.
static func entries(card: CardData) -> Array:
	var out: Array = []
	if card == null:
		return out
	var seen := {}
	for keyword in card.keyword_lines():
		_add(out, seen, keyword, _keyword_text(card, keyword))
	if card.is_remembered:
		_add(out, seen, "Remembered", KEYWORD_TEXT["Remembered"])
	var groups: Array = [card.effects, card.oath_effects, card.discard_effects]
	for group in groups:
		for effect in group:
			if EFFECT_TEXT.has(effect.kind):
				var pair: Array = EFFECT_TEXT[effect.kind]
				_add(out, seen, pair[0], pair[1])
	return out


## All of a card's explanations as tooltip text, one "Term: explanation" line each; "" for a plain card.
static func text(card: CardData) -> String:
	var lines: PackedStringArray = []
	for pair in entries(card):
		lines.append("%s: %s" % pair)
	return "\n".join(lines)


## The card's name, cost and text, then the glossary (the tooltip for deck lists, rewards and shops).
static func full_text(card: CardData) -> String:
	var head := "%s (%d)\n%s" % [card.display_name, card.cost, card.describe()]
	var glossary := text(card)
	return head if glossary == "" else "%s\n\n%s" % [head, glossary]


static func _keyword_text(card: CardData, keyword: String) -> String:
	if keyword == "Oath" and not card.oath_effects.is_empty():
		return "%s Trigger: %s." % [KEYWORD_TEXT["Oath"], card.oath_trigger_text().to_lower()]
	return KEYWORD_TEXT.get(keyword, "")


static func _add(out: Array, seen: Dictionary, term: String, explanation: String) -> void:
	if explanation == "" or seen.has(term):
		return
	seen[term] = true
	out.append([term, explanation])
