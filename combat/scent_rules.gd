class_name ScentRules
extends RefCounted
## The Scent and quarry rules (see docs/RULES.md): who holds Scent, who a Scent effect marks, how Scent moves to
## a new quarry, and how a dead quarry's Scent is passed on. The stateless rules are static; an instance only
## remembers the quarries a Scent-spending hit killed this play. Combat owns one and runs the death effects.

## Quarries a Scent-spending hit killed this play: they died holding Scent that was spent, so they count as a
## quarry's death (kill heal, QUARRY_DIES Oaths) but pass no Scent on. Drained by pass_on.
var _spent_quarries: Array[EnemyUnit] = []


## True for a living enemy holding Scent: the one rule for "this is the quarry".
static func holds_scent(enemy: EnemyUnit) -> bool:
	return not enemy.is_dead() and enemy.stacks(Combatant.Status.SCENT) > 0


## Index into `enemies` of the living enemy holding Scent, or -1 if none does.
static func holder_index(enemies: Array[EnemyUnit]) -> int:
	for i in enemies.size():
		if holds_scent(enemies[i]):
			return i
	return -1


## The enemy among `candidates` (living ones only) that a Scent effect marks: the one already holding Scent
## if it is there, else the first. Null when none is alive.
static func target(candidates: Array[EnemyUnit]) -> EnemyUnit:
	var first: EnemyUnit = null
	for enemy in candidates:
		if enemy.is_dead():
			continue
		if holds_scent(enemy):
			return enemy
		if first == null:
			first = enemy
	return first


## Makes `quarry` the one enemy holding Scent: any Scent held by a LIVING enemy of `enemies` elsewhere moves to
## it, `amount` is added, and the total is capped (Combatant.SCENT_CAP). A non-positive amount with nothing to
## move changes nothing. A DEAD holder's stack is deliberately left alone: it belongs to pass_on (half the
## stack, the quarry-kill heal and the QUARRY_DIES Oaths), which runs after the card, so a card that kills the
## quarry and then marks another enemy cannot absorb the whole dead stack.
static func give(enemies: Array[EnemyUnit], quarry: EnemyUnit, amount: int) -> void:
	var total := quarry.stacks(Combatant.Status.SCENT) + maxi(amount, 0)
	for enemy in enemies:
		if enemy != quarry and not enemy.is_dead() and enemy.stacks(Combatant.Status.SCENT) > 0:
			total += enemy.stacks(Combatant.Status.SCENT)
			enemy.remove_status(Combatant.Status.SCENT)
	quarry.remove_status(Combatant.Status.SCENT)
	quarry.apply_status(Combatant.Status.SCENT, total)


## Remembers `quarry` if a Scent spender just killed it while it held Scent (the Scent itself is spent: there is
## nothing to pass on). Call before the spender removes the Scent.
func note_spent_kill(quarry: EnemyUnit) -> void:
	if quarry != null and quarry.is_dead() and quarry.stacks(Combatant.Status.SCENT) > 0:
		_spent_quarries.append(quarry)


## Forgets the remembered spent quarries (the fight is over or abandoned).
func clear() -> void:
	_spent_quarries.clear()


## Runs `on_death.call(carried)` for each quarry that has died, in enemy order, each one as soon as it is found
## (so what one death does is seen by the next): a dead enemy still holding Scent loses it and carries half
## (rounded down) plus `heir_bonus`, never more than it held (a bonus applies even to a stack of 1); then each
## quarry a spender killed, carrying 0.
func pass_on(enemies: Array[EnemyUnit], heir_bonus: int, on_death: Callable) -> void:
	for enemy in enemies:
		if not enemy.is_dead() or enemy.stacks(Combatant.Status.SCENT) <= 0:
			continue
		var held := enemy.stacks(Combatant.Status.SCENT)
		var carried := held / 2
		if carried > 0 or heir_bonus > 0:
			carried = mini(held, carried + heir_bonus)
		enemy.remove_status(Combatant.Status.SCENT)
		on_death.call(carried)
	# A quarry killed by a Scent spender: the same death effects, with nothing to pass on.
	var spent := _spent_quarries.size()
	_spent_quarries.clear()
	for _i in spent:
		on_death.call(0)
