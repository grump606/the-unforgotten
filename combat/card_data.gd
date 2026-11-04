class_name CardData
extends Resource
## Static definition of a card. Contains no per-combat state.

enum TargetMode { SINGLE_ENEMY, ALL_ENEMIES, SELF }

@export var id: StringName
@export var display_name: String
@export var cost: int = 1
@export var effects: Array[CardEffect] = []
## SINGLE_ENEMY: the chosen enemy. ALL_ENEMIES: every living enemy. SELF: no enemy
## is targeted. BLOCK and DRAW always affect the player.
@export var target_mode: TargetMode = TargetMode.SINGLE_ENEMY
## Which character this card belongs to; empty means neutral (every character can take it).
@export var character: StringName = &""
## Keywords (see docs/MECHANICS_PLAN.md). All default to false, so existing cards are unchanged.
## forgotten: once played, goes to the Forgotten pile instead of the discard pile.
## fading: still in hand at end of turn means it becomes Forgotten; it never counts toward the 5 kept.
## ready: moves into the opening hand on turn 1.
## anchor: cannot be discarded and does not count toward the 5 kept.
## dormant: cannot be played.
## surge: costs no fixed energy; playing it spends all current energy (see CardEffect.per_energy).
@export var forgotten: bool = false
@export var fading: bool = false
@export var ready: bool = false
@export var anchor: bool = false
@export var dormant: bool = false
@export var surge: bool = false


static func make(card_id: StringName, card_name: String, card_cost: int, card_effects: Array[CardEffect], card_target_mode: TargetMode = TargetMode.SINGLE_ENEMY) -> CardData:
	var card := CardData.new()
	card.id = card_id
	card.display_name = card_name
	card.cost = card_cost
	card.effects = card_effects
	card.target_mode = card_target_mode
	return card


## HP the card costs to play (the sum of its LOSE_HP effects).
func hp_cost() -> int:
	var total := 0
	for effect in effects:
		if effect.kind == CardEffect.Kind.LOSE_HP:
			total += maxi(effect.amount, 0)
	return total


## Display text of the keywords this card has, in a fixed order (empty for a plain card).
func keyword_lines() -> PackedStringArray:
	var lines: PackedStringArray = []
	if forgotten:
		lines.append("Forgotten")
	if fading:
		lines.append("Fading")
	if ready:
		lines.append("Ready")
	if anchor:
		lines.append("Anchor")
	if dormant:
		lines.append("Dormant")
	if surge:
		lines.append("Surge")
	return lines


func describe() -> String:
	var parts: PackedStringArray = []
	for effect in effects:
		parts.append(effect.describe())
	return ", ".join(parts)
