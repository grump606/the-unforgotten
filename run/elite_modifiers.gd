class_name EliteModifiers
extends RefCounted
## One modifier per elite fight (docs/CHAPTER2_PLAN.md, "Elite modifiers"; the ideas are in docs/MAP_DESIGN.md). It is a pure
## function of the map's seed and the node's id, so it needs no saving (an old save gets one too) and drawing it never touches
## the map generator's random numbers (maps stay identical).
##  - Plated: every elite enemy starts the fight with Block.
##  - Enraged: every elite enemy grows more dangerous at half HP (a second phase with harder attacks).
##  - Marked: you begin the fight Shaken (you deal less damage on the first turn). Exposed was tried first and was far too
##    harsh in the sims (elite lethality 25% against 17% for the other two), so it is the milder Shaken.
## Append-only: the order is the hash's modulo.
enum Kind { PLATED, ENRAGED, MARKED }

const NAMES := {Kind.PLATED: "Plated", Kind.ENRAGED: "Enraged", Kind.MARKED: "Marked"}
## One line for the map tooltip and the battle log.
const SHORT := {
	Kind.PLATED: "starts with Block",
	Kind.ENRAGED: "grows fiercer at half HP",
	Kind.MARKED: "you start Shaken",
}
## Opening Block of every Plated elite enemy, per district (act): the first, then the second.
const PLATED_BLOCK: Array[int] = [6, 10]
## An Enraged enemy's second phase hits this much harder than its first (rounded, never below the first's amount).
const ENRAGE_DAMAGE_FACTOR := 1.3
const ENRAGE_TITLE := "Enraged"
## Turns of Shaken a Marked fight starts the player with (it covers the first player turn).
const MARKED_SHAKEN_TURNS := 1


## Measuring hook (tools/run_sim.gd --elite-modifier): FORCE_NONE turns modifiers off, a Kind value makes every elite use it, -1 is normal.
const FORCE_NONE := -2
static var forced := -1


## The modifier of elite node `node_id` on a map with `map_seed`.
static func for_node(map_seed: int, node_id: int) -> Kind:
	if forced >= 0:
		return forced as Kind
	return (absi(hash([map_seed, node_id, "elite"])) % 3) as Kind


static func display_name(kind: int) -> String:
	return String(NAMES.get(kind, ""))


static func short_text(kind: int) -> String:
	return String(SHORT.get(kind, ""))


## "Plated: starts with Block" (or "" for an unknown kind).
static func line(kind: int) -> String:
	return "" if not NAMES.has(kind) else "%s: %s" % [NAMES[kind], SHORT[kind]]


## Enraged: gives every enemy of `pack` (new copies made by the pack builder, never shared resources) a second phase at half HP, its
## attacks ENRAGE_DAMAGE_FACTOR times the first phase's. An enemy that already has a second phase is left alone.
static func enrage(pack: Array[EnemyData]) -> void:
	for enemy in pack:
		if enemy == null or not enemy.phase_two_intents.is_empty():
			continue
		var harder: Array[CardEffect] = []
		for intent in enemy.intents:
			if intent.kind == CardEffect.Kind.DAMAGE:
				harder.append(CardEffect.make(intent.kind, maxi(roundi(intent.amount * ENRAGE_DAMAGE_FACTOR), intent.amount + 1), intent.bonus, intent.threshold, intent.hits))
			else:
				harder.append(intent)
		enemy.phase_two_intents = harder
		enemy.phase_two_hp_percent = 50
		enemy.phase_two_title = ENRAGE_TITLE


## Plated and Marked act on the fight itself. `act` is the district (0 or 1) of the elite's row.
static func apply_to_combat(combat: Combat, kind: int, act: int) -> void:
	if combat == null:
		return
	match kind:
		Kind.PLATED:
			var block := PLATED_BLOCK[clampi(act, 0, PLATED_BLOCK.size() - 1)]
			for enemy in combat.enemies:
				enemy.gain_block(block)
		Kind.MARKED:
			combat.player.apply_status(Combatant.Status.SHAKEN, MARKED_SHAKEN_TURNS)
