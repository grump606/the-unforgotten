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
## The Remembered (upgraded) form, or null when the card cannot be Remembered (docs/MECHANICS_PLAN.md,
## phase 5a). Appended last: older .tres files simply lack it.
@export var remembered: RememberedData

## Runtime only (never in a .tres): true on a Remembered variant built by remembered_card(), which keeps the
## base card's id so art, prices and pools key on it unchanged.
var is_remembered: bool = false
## On a Remembered variant, the card it was built from (null otherwise).
var base_card: CardData = null
var _remembered_variant: CardData = null


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


## The Remembered variant of this card: same id, name plus "+", the block's effects, cost and keywords.
## Built once per base card, so deck entries of the same card share one instance (as base cards do).
## Null when the card has no remembered block or is already Remembered.
func remembered_card() -> CardData:
	if remembered == null or is_remembered:
		return null
	if _remembered_variant == null:
		var variant := CardData.new()
		variant.id = id
		variant.display_name = display_name + "+"
		variant.cost = cost if remembered.cost < 0 else remembered.cost
		variant.effects = remembered.effects
		variant.target_mode = target_mode
		variant.character = character
		variant.forgotten = forgotten
		variant.fading = fading
		variant.ready = ready
		variant.anchor = anchor
		variant.dormant = dormant
		variant.surge = surge
		for keyword in remembered.gain_keywords:
			variant.set_keyword(keyword, true)
		for keyword in remembered.lose_keywords:
			variant.set_keyword(keyword, false)
		variant.is_remembered = true
		variant.base_card = self
		_remembered_variant = variant
	return _remembered_variant


## True if this card can be Remembered (has a block and is not already Remembered).
func can_remember() -> bool:
	return remembered != null and not is_remembered


## The unupgraded card: this card itself, or a Remembered variant's base.
func base() -> CardData:
	return base_card if is_remembered and base_card != null else self


func set_keyword(keyword: String, value: bool) -> void:
	match keyword:
		"forgotten":
			forgotten = value
		"fading":
			fading = value
		"ready":
			ready = value
		"anchor":
			anchor = value
		"dormant":
			dormant = value
		"surge":
			surge = value


func describe() -> String:
	var parts: PackedStringArray = []
	for effect in effects:
		parts.append(effect.describe())
	return ", ".join(parts)
