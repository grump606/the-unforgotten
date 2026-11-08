class_name CardEffect
extends Resource
## One atomic outcome of a card play or an enemy intent.
## EXPOSE (`amount` = turns): on a card it exposes its targets (the player for
## SELF cards); on an enemy intent it exposes the player for the next `amount`
## enemy phases.

## New kinds are only ever appended: .tres files store the kind as its integer value.
## HOLD: keep up to `amount` of your remaining Block into your next turn.
## DAMAGE_PER_BLOCK: damage equal to your current Block times `amount`.
## DAMAGE_IF_BLOCK: `bonus` damage if your Block is at least `threshold`, else `amount`.
## THORNS: until your next turn, each enemy attack on you also deals `amount` to that attacker.
## GAIN_ENERGY: gain `amount` energy now (it can lift energy above the per-turn amount).
## DAMAGE_PER_PLAY: `amount` plus `bonus` for each card played earlier this turn.
## HAUNT: the targets take `amount` damage at the start of each enemy phase, which then falls by 1
## each phase. Stacks add. Haunt damage ignores Block and Expose.
## LOSE_HP: the player pays `amount` HP, ignoring Block (a card with this cannot be played if it would
## kill the player: see CardData.hp_cost).
## HEAL_PER_HAUNTED: heal `amount` for each living enemy that is Haunted.
## DAMAGE_PER_HAUNT: damage equal to the target's Haunt times `amount`.
## SHAKEN / FRAYED (`amount` = turns): like EXPOSE. The attacker deals / the user gains 25% less.
## MALICE / WARD (`amount`, signed): a stacking bonus to each hit dealt / each Block gained from cards,
## lasting the fight (or this turn only with `temporary`). A positive amount buffs the user; a negative
## amount debuffs the targets (an enemy intent: positive buffs the enemy, negative debuffs the player).
## GLIMPSE: look at the top `amount` cards of the draw pile and discard any of them (a choice that opens
## after the whole card has resolved; it never reshuffles the discard pile).
## ADD_CARD: add `amount` copies of `card` to the player's `pile`. On a card that is the player's own
## piles; as an enemy intent it still lands in the player's piles (intents conventionally use Pile.DRAW).
## Created cards last for the fight only.
## RECALL: pick `amount` cards from the Forgotten pile and return them to hand (a choice, like GLIMPSE).
## DAMAGE_PER_FORGOTTEN: damage equal to the size of the Forgotten pile times `amount`.
## SCENT: the card's target becomes the quarry and gains `amount` Scent (max 8). Only one enemy holds Scent: a
## new holder takes the old holder's whole stack too. A card that targets several enemies marks the current
## quarry if it is among them, else the first. Enemy intents cannot apply it.
## DAMAGE_PER_SCENT: `amount` plus `bonus` per Scent on the target, after which that Scent is spent (removed).
## ADDING A KIND: append it to Kind (never reorder), then touch only: is_damage()/reach() and
## describe() here, the handler in Combat._apply, and Vendor.effect_value. tests/mechanics_tests.gd
## walks every Kind and fails if any of those is missing.
enum Kind { DAMAGE, BLOCK, DRAW, EXPOSE, HOLD, DAMAGE_PER_BLOCK, DAMAGE_IF_BLOCK, THORNS, GAIN_ENERGY, DAMAGE_PER_PLAY, HAUNT, LOSE_HP, HEAL_PER_HAUNTED, DAMAGE_PER_HAUNT, SHAKEN, FRAYED, MALICE, WARD, GLIMPSE, ADD_CARD, RECALL, DAMAGE_PER_FORGOTTEN, SCENT, DAMAGE_PER_SCENT }

@export var kind: Kind = Kind.DAMAGE
@export var amount: int = 0
## Second number for kinds that need one (see DAMAGE_IF_BLOCK); 0 otherwise.
@export var bonus: int = 0
@export var threshold: int = 0
## Multi-hit: a damage effect applies this many times (each hit is separate for Block, Expose and
## Barbs). Values below 1 count as 1.
@export var hits: int = 1
## Surge scaling: on a Surge card the energy spent multiplies `hits` (damage kinds) or `amount`
## (every other kind). Ignored on a card without Surge and on enemy intents.
@export var per_energy: bool = false
## MALICE and WARD only: the stacks are temporary and expire when the owner's next turn starts.
@export var temporary: bool = false
## ADD_CARD only: the card created.
@export var card: CardData
## Where ADD_CARD puts it. Hand falls back to discard when the hand is full; Draw inserts at a random
## position. New effects default to HAND; enemy intents conventionally use DRAW.
enum Pile { HAND, DRAW, DISCARD }
@export var pile: Pile = Pile.HAND
## Display name per pile, keyed by enum value so appending a Pile cannot index out of range.
const PILE_NAMES := {Pile.HAND: "hand", Pile.DRAW: "draw pile", Pile.DISCARD: "discard pile"}


static func make(effect_kind: Kind, effect_amount: int, effect_bonus: int = 0, effect_threshold: int = 0, effect_hits: int = 1, effect_per_energy: bool = false, effect_temporary: bool = false, effect_card: CardData = null, effect_pile: Pile = Pile.HAND) -> CardEffect:
	var effect := CardEffect.new()
	effect.kind = effect_kind
	effect.amount = effect_amount
	effect.bonus = effect_bonus
	effect.threshold = effect_threshold
	effect.hits = effect_hits
	effect.per_energy = effect_per_energy
	effect.temporary = effect_temporary
	effect.card = effect_card
	effect.pile = effect_pile
	return effect


## Who a card effect lands on when played (see reach()).
enum Reach { SELF, ENEMIES, BOTH }


## True for the kinds that hit a target for `raw_damage`.
func is_damage() -> bool:
	match kind:
		Kind.DAMAGE, Kind.DAMAGE_PER_BLOCK, Kind.DAMAGE_IF_BLOCK, Kind.DAMAGE_PER_PLAY, Kind.DAMAGE_PER_HAUNT, Kind.DAMAGE_PER_FORGOTTEN, Kind.DAMAGE_PER_SCENT:
			return true
	return false


## Where a played card applies this effect: the card's chosen enemies (ENEMIES), the player
## (SELF), or both (BOTH: EXPOSE, SHAKEN and FRAYED, which on a SELF-targeted card exposes the player and on
## any other card exposes its targets). MALICE and WARD are SELF when positive and ENEMIES when
## negative. Enemy intents ignore this and always act on the player.
func reach() -> Reach:
	match kind:
		Kind.HAUNT, Kind.SCENT:
			return Reach.ENEMIES
		Kind.EXPOSE, Kind.SHAKEN, Kind.FRAYED:
			return Reach.BOTH
		Kind.MALICE, Kind.WARD:
			return Reach.SELF if amount >= 0 else Reach.ENEMIES
	return Reach.ENEMIES if is_damage() else Reach.SELF


## Damage of one hit before Expose and Block (0 for a non-damage kind). Pure, so the
## battle preview and Combat share one rule. `plays_including_this` counts the card
## being played, as Combat.plays_this_turn does during resolution (see EffectContext).
func raw_damage(ctx: EffectContext) -> int:
	match kind:
		Kind.DAMAGE:
			return amount
		Kind.DAMAGE_PER_BLOCK:
			return ctx.block * amount
		Kind.DAMAGE_IF_BLOCK:
			return bonus if ctx.block >= threshold else amount
		Kind.DAMAGE_PER_PLAY:
			return amount + bonus * maxi(ctx.plays - 1, 0)
		Kind.DAMAGE_PER_HAUNT:
			return ctx.haunt * amount
		Kind.DAMAGE_PER_FORGOTTEN:
			return ctx.forgotten * amount
		Kind.DAMAGE_PER_SCENT:
			return amount + bonus * ctx.scent
	return 0


## Text of the effect. Suffix wording: multi-hit damage appends " x2" ("Deal 3 x2"); per_energy
## damage reads "Deal 3 x energy spent" (its hits scale with the energy) and any other per_energy
## effect appends " per energy spent" ("Block 4 per energy spent").
func describe() -> String:
	var text := _describe_base()
	if temporary and kind in [Kind.MALICE, Kind.WARD]:
		text += " this turn"
	if is_damage():
		if per_energy:
			return "%s x energy spent" % text
		if hits > 1:
			return "%s x%d" % [text, hits]
		return text
	if per_energy:
		return "%s per energy spent" % text
	return text


func _describe_base() -> String:
	match kind:
		Kind.DAMAGE:
			return "Deal %d" % amount
		Kind.BLOCK:
			return "Block %d" % amount
		Kind.DRAW:
			return "Draw %d" % amount
		Kind.EXPOSE:
			return "Expose %d" % amount
		Kind.HOLD:
			return "Hold %d" % amount
		Kind.DAMAGE_PER_BLOCK:
			return "Deal damage equal to your Block" if amount == 1 else "Deal %dx your Block" % amount
		Kind.DAMAGE_IF_BLOCK:
			return "Deal %d (%d with %d+ Block)" % [amount, bonus, threshold]
		Kind.THORNS:
			return "Thorns %d" % amount
		Kind.GAIN_ENERGY:
			return "Gain %d energy" % amount
		Kind.DAMAGE_PER_PLAY:
			return "Deal %d, +%d for each card played earlier this turn" % [amount, bonus]
		Kind.HAUNT:
			return "Haunt %d" % amount
		Kind.LOSE_HP:
			return "Lose %d HP" % amount
		Kind.HEAL_PER_HAUNTED:
			return "Heal %d per Haunted enemy" % amount
		Kind.DAMAGE_PER_HAUNT:
			return "Deal damage equal to the target's Haunt" if amount == 1 else "Deal %dx the target's Haunt" % amount
		Kind.SHAKEN:
			return "Shaken %d" % amount
		Kind.FRAYED:
			return "Frayed %d" % amount
		Kind.MALICE:
			return "Malice %+d" % amount
		Kind.WARD:
			return "Ward %+d" % amount
		Kind.GLIMPSE:
			return "Glimpse %d" % amount
		Kind.ADD_CARD:
			var what := "%d %s" % [amount, card.display_name] if card != null else "%d cards" % amount
			return "Add %s to your %s" % [what, PILE_NAMES.get(pile, "hand")]
		Kind.RECALL:
			return "Recall %d" % amount
		Kind.DAMAGE_PER_FORGOTTEN:
			return "Deal damage equal to the Forgotten pile" if amount == 1 else "Deal %dx the Forgotten pile" % amount
		Kind.SCENT:
			return "Scent %d" % amount
		Kind.DAMAGE_PER_SCENT:
			return "Deal %d, +%d per Scent (spends it)" % [amount, bonus]
	return ""
