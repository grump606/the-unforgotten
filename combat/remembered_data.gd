class_name RememberedData
extends Resource
## The Remembered (upgraded) form of a card: what the card becomes when the player Remembers it at a
## rest stop (docs/MECHANICS_PLAN.md, phase 5a). Lives inside the card's own .tres as CardData.remembered;
## there is no second card id. CardData.remembered_card() builds the runtime card from it.

## Replaces the card's effects entirely (write the full upgraded list, not a diff).
@export var effects: Array[CardEffect] = []
## The new energy cost, or -1 to keep the card's own cost.
@export var cost: int = -1
## Keywords the Remembered card gains / loses, by lower-case name (see KEYWORDS).
@export var gain_keywords: PackedStringArray = []
@export var lose_keywords: PackedStringArray = []
## On an Oath: replaces its oath_effects when not empty (otherwise the base card's carry over).
@export var oath_effects: Array[CardEffect] = []

const KEYWORDS := ["forgotten", "fading", "ready", "anchor", "dormant", "surge"]


static func make(new_effects: Array[CardEffect], new_cost: int = -1, gain: PackedStringArray = [], lose: PackedStringArray = []) -> RememberedData:
	var data := RememberedData.new()
	data.effects = new_effects
	data.cost = new_cost
	data.gain_keywords = gain
	data.lose_keywords = lose
	return data
