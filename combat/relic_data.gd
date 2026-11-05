class_name RelicData
extends Resource
## Static definition of a relic: a permanent run-long bonus sold by vendors. Contains
## no per-run state; Combat and RunState read `kind` and `amount` (see docs/RELICS_DESIGN.md).

## Data-driven like CardEffect.Kind: only ever append, saved .tres files store the numbers.
enum Kind {
	MAX_HP,
	FIGHT_START_BLOCK,
	TURN_START_BLOCK,
	TURN_START_THORNS,
	FIRST_TURN_ENERGY,
	FIRST_PLAY_DRAW,
	PLAYS_BLOCK,
	WIN_GOLD,
	WIN_HEAL,
	FIGHT_START_HAUNT,
	TURN_START_HEAL_PER_HAUNTED,
	HAUNT_BONUS,
	FIGHT_START_GLIMPSE,
	FIGHT_START_MALICE,
	FIGHT_START_WARD,
	FIRST_FORGOTTEN_RETURN,
	ANCHOR_END_BLOCK,
	FIRST_ATTACK_SHAKEN,
}

## PLAYS_BLOCK pays out on every Nth card played in a turn.
const PLAYS_BLOCK_EVERY := 3

@export var id: StringName
@export var display_name: String
@export var description: String
## Which character may be offered this relic; empty means neutral (everyone), like cards.
@export var character: StringName = &""
@export var kind: Kind = Kind.MAX_HP
@export var amount: int = 0
@export var price: int = 0


static func make(relic_id: StringName, relic_name: String, relic_kind: Kind, relic_amount: int, relic_price: int, relic_character: StringName = &"") -> RelicData:
	var relic := RelicData.new()
	relic.id = relic_id
	relic.display_name = relic_name
	relic.kind = relic_kind
	relic.amount = relic_amount
	relic.price = relic_price
	relic.character = relic_character
	return relic
