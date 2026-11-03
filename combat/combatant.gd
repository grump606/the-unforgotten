class_name Combatant
extends RefCounted
## Health, block and statuses for one side of a fight. The player's instance is
## owned by the caller so HP can persist between fights.

signal changed

enum Status { EXPOSED, HAUNTED }

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

var _statuses: Dictionary = {}  # Status -> remaining turns (always > 0)


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


## Remaining turns of `status`, 0 if absent.
func status_turns(status: Status) -> int:
	return _statuses.get(status, 0)


## Adds `turns` to the status duration. Non-positive turns are ignored.
func apply_status(status: Status, turns: int) -> void:
	if turns <= 0:
		return
	var total := status_turns(status) + turns
	if status == Status.HAUNTED and max_haunt > 0:
		total = mini(total, max_haunt)
	_statuses[status] = total
	changed.emit()


## Also drops Hold and Thorns: they are per-fight like statuses.
func clear_statuses() -> void:
	_statuses.clear()
	hold = 0
	thorns = 0
	changed.emit()


## Counts every status down by one turn; expired ones are removed.
func tick_statuses() -> void:
	for status in _statuses.keys():
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


## Loses HP directly: Block and Expose do not apply. Returns the HP actually lost.
func lose_hp(amount: int) -> int:
	var lost := mini(maxi(amount, 0), hp)
	hp -= lost
	changed.emit()
	return lost


## Returns the HP actually lost.
func take_damage(amount: int) -> int:
	amount = damage_after_status(amount)
	var absorbed := mini(block, amount)
	block -= absorbed
	var lost := mini(amount - absorbed, hp)
	hp -= lost
	changed.emit()
	return lost
