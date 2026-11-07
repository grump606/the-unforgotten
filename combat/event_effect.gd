class_name EventEffect
extends Resource
## One thing an event choice does (docs/EVENTS_DESIGN.md). Pure data: RunState applies it and the screen prints
## `describe()`, so the numbers a player reads are always the numbers in the .tres file.

## Data-driven like CardEffect.Kind: only ever append, saved .tres files store the numbers.
##  HEAL_PERCENT: heal `amount` percent of max HP (rounded). HEAL_FLAT: heal `amount` HP.
##  LOSE_HP: lose `amount` HP, never below 1. LOSE_HP_PERCENT: the same as a percent of max HP.
##  GOLD: gain `amount` gold, or pay it when negative (a payment must be affordable; inside a gamble gold stops at 0).
##  MAX_HP: change max HP by `amount`; HP follows a rise and is capped by a fall.
##  ADD_CARD: add the card `card_id` (any card of the pool the character can meet) `count` times.
##  ADD_RANDOM_CARD: add `count` random cards of `rarity` (-1 = any) from `pool`, optionally only cards with a `has_effect` kind.
##  PICK_CARD: the player picks 1 of `count` cards of `rarity` from the character's own cards.
##  REMOVE_CARD: the player picks a card to remove. REMEMBER_CARD: the player picks a card to Remember.
##  GAIN_RELIC: a random relic the player does not own, from `pool`.
##  ADD_CURSE: put `count` copies of the status card `card_id` (dread or murmur) into the persistent deck.
##  GAMBLE: `amount` percent chance of the `win` effects, otherwise the `lose` effects.
##  REMOVE_RANDOM_CARD: remove `count` random cards from the deck (never the last card).
enum Kind {
	HEAL_PERCENT,
	HEAL_FLAT,
	LOSE_HP,
	GOLD,
	MAX_HP,
	ADD_CARD,
	ADD_RANDOM_CARD,
	PICK_CARD,
	REMOVE_CARD,
	REMEMBER_CARD,
	GAIN_RELIC,
	ADD_CURSE,
	GAMBLE,
	REMOVE_RANDOM_CARD,
	LOSE_HP_PERCENT,
}

## Where a random card or relic comes from. NEUTRAL: cards or relics with no character. CLASS: the player's own.
## ANY: both (relics only; the card kinds treat it as the neutral and class cards together).
enum Pool { NEUTRAL, CLASS, ANY }

@export var kind: Kind = Kind.GOLD
@export var amount: int = 0
@export var card_id: StringName = &""
## CardData.Rarity as a number, -1 for any rarity.
@export var rarity: int = -1
@export var pool: Pool = Pool.NEUTRAL
@export var count: int = 1
## ADD_RANDOM_CARD only: -1 for any card, else a CardEffect.Kind the card must have.
@export var has_effect: int = -1
@export var win: Array[EventEffect] = []
@export var lose: Array[EventEffect] = []


static func make(effect_kind: Kind, effect_amount: int = 0) -> EventEffect:
	var effect := EventEffect.new()
	effect.kind = effect_kind
	effect.amount = effect_amount
	return effect


## True for the kinds that need the player to pick a card (a follow-up screen).
func needs_pick() -> bool:
	return kind == Kind.PICK_CARD or kind == Kind.REMOVE_CARD or kind == Kind.REMEMBER_CARD


## Gold the player must hold for this effect to be pressed (only a direct payment counts).
func gold_cost() -> int:
	return -amount if kind == Kind.GOLD and amount < 0 else 0


## The printed summary of this one effect ("Lose 8 HP", "Pay 30 gold").
func describe() -> String:
	match kind:
		Kind.HEAL_PERCENT:
			return "Heal %d%% max HP" % amount
		Kind.HEAL_FLAT:
			return "Heal %d HP" % amount
		Kind.LOSE_HP:
			return "Lose %d HP" % amount
		Kind.LOSE_HP_PERCENT:
			return "Lose %d%% max HP" % amount
		Kind.GOLD:
			return "Gain %d gold" % amount if amount >= 0 else "Pay %d gold" % -amount
		Kind.MAX_HP:
			return "Gain %d max HP" % amount if amount >= 0 else "Lose %d max HP" % -amount
		Kind.ADD_CARD:
			return "Add %d %s to your deck" % [count, card_name(card_id)]
		Kind.ADD_RANDOM_CARD:
			return "Add %s to your deck" % (("a " + _random_card_words()) if count == 1 else "%d %ss" % [count, _random_card_words()])
		Kind.PICK_CARD:
			return "Choose 1 of %d %s cards of your own" % [count, _rarity_word()] if rarity >= 0 else "Choose 1 of %d cards of your own" % count
		Kind.REMOVE_CARD:
			return "Remove a card from your deck"
		Kind.REMEMBER_CARD:
			return "Remember a card"
		Kind.GAIN_RELIC:
			return "Gain a random %srelic" % ("neutral " if pool == Pool.NEUTRAL else ("class " if pool == Pool.CLASS else ""))
		Kind.ADD_CURSE:
			return "Add %d %s to your deck" % [count, card_name(card_id)]
		Kind.GAMBLE:
			return "%d%%: %s. Otherwise: %s" % [amount, describe_all(win, "nothing"), describe_all(lose, "nothing")]
		Kind.REMOVE_RANDOM_CARD:
			return "Remove %s from your deck" % ("a random card" if count == 1 else "%d random cards" % count)
	return "?"


## The summaries of a list of effects joined into sentences ("Lose 8 HP. Remember a card"); `empty` when the list is.
static func describe_all(effects: Array[EventEffect], empty := "Nothing") -> String:
	if effects.is_empty():
		return empty
	var parts: Array[String] = []
	for effect in effects:
		parts.append(effect.describe())
	return ". ".join(parts)


func _rarity_word() -> String:
	return ["common", "uncommon", "rare"][clampi(rarity, 0, 2)]


func _random_card_words() -> String:
	var words := "random "
	if pool == Pool.NEUTRAL:
		words += "neutral "
	if rarity >= 0:
		words += _rarity_word() + " "
	if has_effect == CardEffect.Kind.BLOCK:
		words += "Block "
	return words + "card"


## The display name of the card with this id (status cards and every card), or the id itself when there is none.
static func card_name(id: StringName) -> String:
	var card := StarterContent.status_card(id) if StarterContent.STATUS_CARD_PATHS.has(id) else StarterContent.card_by_id(id)
	return card.display_name if card != null else String(id)
