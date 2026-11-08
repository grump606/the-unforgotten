class_name CardGlossary
extends RefCounted
## Plain-language explanations of every mechanic a card uses, shown in the card's tooltip. One entry per term,
## in a fixed order (keywords first, then effects in the order the card uses them), so a card never repeats a term.
## Numbers in the effect entries match the status tooltips in battle.gd; keep the two in step.

const KEYWORD_TEXT := {
	"Forgotten": "Once played, goes to the Forgotten pile for the rest of the fight instead of the discard pile. It returns to your deck after the fight.",
	"Fading": "If still in your hand when the turn ends, it becomes Forgotten. It does not count toward the 5 cards you keep.",
	"Ready": "Starts the fight in your opening hand.",
	"Anchor": "Stays in your hand: it cannot be discarded and does not count toward the 5 you keep.",
	"Dormant": "Cannot be played. Enemies shuffle these into your piles.",
	"Surge": "Playing it spends all your remaining energy, and its effect grows with the energy spent.",
	"Oath": "Played once, then it stays Sworn for the rest of the fight. Its Oath effect happens every time its trigger fires.",
	"Discarded": "Has an effect when thrown away at the end-of-turn discard (not when played).",
	"Remembered": "Upgraded at a rest stop. It stays Remembered for the rest of the run.",
}

const EFFECT_TEXT := {
	CardEffect.Kind.DAMAGE: ["Deal", "Damage to the target. Block absorbs it first."],
	CardEffect.Kind.BLOCK: ["Block", "Absorbs damage until your next turn starts."],
	CardEffect.Kind.DRAW: ["Draw", "Take cards from your draw pile into your hand (up to 10 in hand)."],
	CardEffect.Kind.EXPOSE: ["Expose", "The target takes 1.5x damage, rounded down, for that many turns."],
	CardEffect.Kind.HOLD: ["Hold", "Up to that much of the Block you have left is kept for your next turn."],
	CardEffect.Kind.DAMAGE_PER_BLOCK: ["Your Block", "This card's damage is based on the Block you have now."],
	CardEffect.Kind.DAMAGE_IF_BLOCK: ["Block bonus", "Deals the higher number while you have at least that much Block."],
	CardEffect.Kind.THORNS: ["Thorns", "Each enemy attack on you also deals that much to the attacker this turn."],
	CardEffect.Kind.GAIN_ENERGY: ["Energy", "Energy pays for cards. You gain it now, on top of this turn's energy."],
	CardEffect.Kind.DAMAGE_PER_PLAY: ["Combo", "Deals more damage for each card you played earlier this turn."],
	CardEffect.Kind.HAUNT: ["Haunt", "The target takes that much damage at the start of the enemy phase, ignoring Block, then Haunt falls by 1."],
	CardEffect.Kind.LOSE_HP: ["Lose HP", "You pay this much of your own HP to play the card."],
	CardEffect.Kind.HEAL_PER_HAUNTED: ["Heal per Haunted", "You heal for each enemy that currently has Haunt."],
	CardEffect.Kind.DAMAGE_PER_HAUNT: ["Haunt damage", "Deals damage based on the target's current Haunt."],
	CardEffect.Kind.SHAKEN: ["Shaken", "The target deals 25% less damage, rounded down, for that many turns."],
	CardEffect.Kind.FRAYED: ["Frayed", "Gains 25% less Block from cards, rounded down, for that many turns."],
	CardEffect.Kind.MALICE: ["Malice", "A flat bonus to every hit you deal. Stacks, and lasts the fight (one turn if the card says \"this turn\")."],
	CardEffect.Kind.WARD: ["Ward", "A flat bonus to Block gained from cards (not Hold, Thorns or relic Block). Stacks, and lasts the fight."],
	CardEffect.Kind.GLIMPSE: ["Glimpse", "Look at that many cards from the top of your draw pile and discard any of them."],
	CardEffect.Kind.ADD_CARD: ["Add", "Puts new copies of a card into the pile named."],
	CardEffect.Kind.RECALL: ["Recall", "Choose that many cards from the Forgotten pile and return them to your hand."],
	CardEffect.Kind.DAMAGE_PER_FORGOTTEN: ["Forgotten damage", "Deals damage based on how many cards are in the Forgotten pile."],
	CardEffect.Kind.SCENT: ["Scent", "Marks one enemy as your quarry: every hit your cards land on it deals more. Only one enemy holds Scent (up to 8); marking another moves it."],
	CardEffect.Kind.DAMAGE_PER_SCENT: ["Scent damage", "Deals extra damage for each Scent on the target, then spends all of it."],
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
		return "%s Trigger on this card: %s." % [KEYWORD_TEXT["Oath"], card.oath_trigger_text().to_lower()]
	return KEYWORD_TEXT.get(keyword, "")


static func _add(out: Array, seen: Dictionary, term: String, explanation: String) -> void:
	if explanation == "" or seen.has(term):
		return
	seen[term] = true
	out.append([term, explanation])
