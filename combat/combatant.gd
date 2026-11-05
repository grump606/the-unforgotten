class_name Combatant
extends RefCounted
## Health, block and statuses for one side of a fight. The player's instance is
## owned by the caller so HP can persist between fights.

signal changed

## New statuses are only ever appended (never reorder).
enum Status { EXPOSED, HAUNTED, SHAKEN, FRAYED, MALICE, WARD, SCENT }

## How a status behaves over time (see STATUS_KINDS).
##  DURATION: a count of turns that ticks down (Exposed, Shaken, Frayed).
##  DECAYING: falls by 1 each phase (Haunted); ticks like a duration but is damage over time.
##  STACK: a signed amount that lasts the fight, never ticks and is removed at 0 (Malice, Ward).
enum StatusKind { DURATION, DECAYING, STACK }

## The status table: every status declares its kind here and nowhere else.
const STATUS_KINDS := {
	Status.EXPOSED: StatusKind.DURATION,
	Status.HAUNTED: StatusKind.DECAYING,
	Status.SHAKEN: StatusKind.DURATION,
	Status.FRAYED: StatusKind.DURATION,
	Status.MALICE: StatusKind.STACK,
	Status.WARD: StatusKind.STACK,
	Status.SCENT: StatusKind.STACK,
}

## SCENT (the Stray's mark, only ever on an enemy): a stack of at most SCENT_CAP that adds its size to every
## hit the player's cards land on the holder (see hit_damage). Only one enemy holds it at a time (Combat).
const SCENT_CAP := 8

## SHAKEN: the attacker deals 3/4 of its damage, rounded down, never below 1 for a real hit.
## FRAYED: Block gained from cards is 3/4, rounded down, never below 1 for real Block.
const REDUCED_NUM := 3
const REDUCED_DEN := 4

## EXPOSED multiplies incoming damage by 3/2, rounded down.
const EXPOSED_NUM := 3
const EXPOSED_DEN := 2

var display_name: String
var max_hp: int
var hp: int
var block: int = 0
## Block (up to this much) that survives into the next turn; set by HOLD effects, used and reset when
## the next turn starts.
var hold: int = 0
## Damage each enemy attack on this combatant also deals to the attacker; lasts until the next turn.
var thorns: int = 0
## Most Haunt stacks this combatant can carry (0 = no cap); applied Haunt past it is lost.
var max_haunt: int = 0

# Status -> remaining turns (DURATION, DECAYING) or signed stack (STACK). Never 0: a status at 0 is
# erased. Only STACK statuses can be negative.
var _statuses: Dictionary = {}
# Status (STACK kinds only) -> signed temporary stack, e.g. "+2 Malice this turn". Counted by
# stacks(), cleared by clear_temp_stacks() when the owner's next turn starts. Never 0.
var _temp_stacks: Dictionary = {}


func _init(combatant_name: String, max_health: int, current_health: int = -1) -> void:
	display_name = combatant_name
	max_hp = max_health
	hp = max_health if current_health < 0 else mini(current_health, max_health)


func is_dead() -> bool:
	return hp <= 0


func gain_block(amount: int) -> void:
	block += maxi(amount, 0)
	changed.emit()


func clear_block() -> void:
	block = 0
	changed.emit()


func add_hold(amount: int) -> void:
	hold += maxi(amount, 0)
	changed.emit()


func add_thorns(amount: int) -> void:
	thorns += maxi(amount, 0)
	changed.emit()


## Starts a turn: Block drops to whatever Hold kept (never more than the Block left), and the
## turn-long Hold and Thorns reset.
func start_turn_block() -> void:
	block = mini(hold, block)
	hold = 0
	thorns = 0
	changed.emit()


## Restores up to `amount` HP, never above max HP. Negative amounts are ignored.
## Returns the HP actually restored.
func heal(amount: int) -> int:
	var restored := mini(maxi(amount, 0), max_hp - hp)
	hp += restored
	changed.emit()
	return restored


static func status_kind(status: Status) -> StatusKind:
	return STATUS_KINDS[status]


## Remaining turns of `status`, 0 if absent. For a STACK status this is the permanent signed
## stack (without temporary stacks): use stacks() for the total.
func status_turns(status: Status) -> int:
	return _statuses.get(status, 0)


## The signed total of `status`: the permanent value plus any temporary stacks (0 if absent). For a
## DURATION or DECAYING status this is its turns.
func stacks(status: Status) -> int:
	return _statuses.get(status, 0) + _temp_stacks.get(status, 0)


## DURATION and DECAYING: adds `turns` to the duration; non-positive turns are ignored (Haunt is
## capped by max_haunt). STACK: adds the signed `turns` to the stack; 0 is ignored and a result of
## 0 erases the status.
func apply_status(status: Status, turns: int) -> void:
	if status_kind(status) == StatusKind.STACK:
		if turns == 0:
			return
		var stack: int = status_turns(status) + turns
		if status == Status.SCENT:
			# Scent is never negative and never above the cap.
			stack = clampi(stack, 0, SCENT_CAP)
		if stack == 0:
			_statuses.erase(status)
		else:
			_statuses[status] = stack
		changed.emit()
		return
	if turns <= 0:
		return
	var total := status_turns(status) + turns
	if status == Status.HAUNTED and max_haunt > 0:
		total = mini(total, max_haunt)
	_statuses[status] = total
	changed.emit()


## Removes `status` entirely (a duration, a decaying status or a stack).
func remove_status(status: Status) -> void:
	if _statuses.erase(status):
		changed.emit()


## Adds a signed temporary stack (STACK statuses only; others and 0 are ignored). It counts in
## stacks() until clear_temp_stacks().
func apply_temp_stack(status: Status, amount: int) -> void:
	if amount == 0 or status_kind(status) != StatusKind.STACK:
		return
	var total: int = _temp_stacks.get(status, 0) + amount
	if total == 0:
		_temp_stacks.erase(status)
	else:
		_temp_stacks[status] = total
	changed.emit()


## Drops every temporary stack; Combat calls it as the owner's next turn begins.
func clear_temp_stacks() -> void:
	if _temp_stacks.is_empty():
		return
	_temp_stacks.clear()
	changed.emit()


## Also drops Hold, Thorns and temporary stacks: they are per-fight like statuses.
func clear_statuses() -> void:
	_statuses.clear()
	_temp_stacks.clear()
	hold = 0
	thorns = 0
	changed.emit()


## Counts every duration and decaying status down by one turn; expired ones are removed. Stacks
## (Malice, Ward) never tick.
func tick_statuses() -> void:
	for status in _statuses.keys():
		if status_kind(status) == StatusKind.STACK:
			continue
		var left: int = _statuses[status] - 1
		if left <= 0:
			_statuses.erase(status)
		else:
			_statuses[status] = left
	changed.emit()


## What an incoming hit of `amount` becomes after status effects, before block
## absorbs any of it: EXPOSED scales it (rounded down, never below 1 for a real
## hit). Pure, so a UI can preview a hit without applying it.
func damage_after_status(amount: int) -> int:
	amount = maxi(amount, 0)
	if amount > 0 and status_turns(Status.EXPOSED) > 0:
		amount = maxi(amount * EXPOSED_NUM / EXPOSED_DEN, 1)
	return amount


## The full damage chain for one hit of `raw` from `attacker` on `defender`, before Block. Pure, so
## Combat and any preview share one rule. A raw of 0 or less stays 0. Otherwise: raw plus the
## attacker's Malice plus the defender's Scent (total, floored at 0), then x3/4 if the attacker is Shaken (rounded down, never
## below 1), then the defender's Expose (damage_after_status).
static func hit_damage(raw: int, attacker: Combatant, defender: Combatant) -> int:
	if raw <= 0:
		return 0
	var amount := maxi(raw + attacker.stacks(Status.MALICE) + defender.stacks(Status.SCENT), 0)
	if amount > 0 and attacker.stacks(Status.SHAKEN) > 0:
		amount = maxi(amount * REDUCED_NUM / REDUCED_DEN, 1)
	return defender.damage_after_status(amount)


## Block gained from a card or an enemy Block intent: `amount` plus Ward (total, floored at 0), then
## x3/4 if Frayed (rounded down, never below 1). An amount of 0 or less gives 0. Hold, Barbs and
## relic Block do not use this.
func block_from_card(amount: int) -> int:
	if amount <= 0:
		return 0
	var value := maxi(amount + stacks(Status.WARD), 0)
	if value > 0 and stacks(Status.FRAYED) > 0:
		value = maxi(value * REDUCED_NUM / REDUCED_DEN, 1)
	return value


## Loses HP directly: Block and Expose do not apply. Returns the HP actually lost.
func lose_hp(amount: int) -> int:
	var lost := mini(maxi(amount, 0), hp)
	hp -= lost
	changed.emit()
	return lost


## Applies Expose to `amount`, then Block and HP. Returns the HP actually lost.
func take_damage(amount: int) -> int:
	return take_damage_final(damage_after_status(amount))


## Block and HP absorb an amount that already went through the whole chain (hit_damage), so Expose is
## not applied again. Returns the HP actually lost.
func take_damage_final(amount: int) -> int:
	amount = maxi(amount, 0)
	var absorbed := mini(block, amount)
	block -= absorbed
	var lost := mini(amount - absorbed, hp)
	hp -= lost
	changed.emit()
	return lost
