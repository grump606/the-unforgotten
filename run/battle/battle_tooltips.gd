class_name BattleTooltips
extends RefCounted
## Tooltip text for the figures on the battle stage: a combatant's statuses and an enemy's Omen. Static and
## free of any scene state, so the wording can be tested on its own.

# Derived from the rules constants so the text cannot drift from them.
const EXPOSED_MULTIPLIER_TEXT := "%.1fx" % (float(Combatant.EXPOSED_NUM) / Combatant.EXPOSED_DEN)
const EXPOSED_TOOLTIP := "Takes " + EXPOSED_MULTIPLIER_TEXT + " damage, rounded down, for %d more turns."
## Shaken and Frayed take 25% off (Combatant.REDUCED_NUM / REDUCED_DEN = 3/4); the tests pin the wording.
const SHAKEN_TOOLTIP := "Shaken %d: deals 25%% less damage (rounded down) for %d more turns."
const FRAYED_TOOLTIP := "Frayed %d: gains 25%% less Block from cards (rounded down) for %d more turns."
const MALICE_TOOLTIP := "Malice %+d: %+d damage on every hit, for the rest of the fight."
const WARD_TOOLTIP := "Ward %+d: %+d Block from every card, for the rest of the fight."
const SCENT_TOOLTIP := "Scent %d: every hit your cards land here deals %d more. Only one enemy holds Scent (up to %d). Marking another enemy moves it."


## Tooltip of an enemy: its Omen (what it will do next), then its statuses.
static func enemy(unit: EnemyUnit, player: Combatant) -> String:
	var lines: Array[String] = [unit.display_name]
	var intent := Fighter.effective_intent(unit, player)
	if intent != null:
		lines.append("Omen: " + intent.describe())
	var status_text := status(unit)
	if status_text != "":
		lines.append(status_text)
	return "\n".join(lines)


## One line per status or stance the combatant has (empty when it has none).
static func status(combatant: Combatant) -> String:
	var lines: Array[String] = []
	var exposed := combatant.status_turns(Combatant.Status.EXPOSED)
	if exposed > 0:
		lines.append(EXPOSED_TOOLTIP % exposed)
	var haunted := combatant.status_turns(Combatant.Status.HAUNTED)
	if haunted > 0:
		lines.append("Haunt %d: takes %d damage at the start of the enemy phase (ignoring Block), then Haunt falls by 1." % [haunted, haunted])
	if combatant.max_haunt > 0:
		lines.append("Haunt capped at %d." % combatant.max_haunt)
	var shaken := combatant.stacks(Combatant.Status.SHAKEN)
	if shaken > 0:
		lines.append(SHAKEN_TOOLTIP % [shaken, shaken])
	var frayed := combatant.stacks(Combatant.Status.FRAYED)
	if frayed > 0:
		lines.append(FRAYED_TOOLTIP % [frayed, frayed])
	var malice := combatant.stacks(Combatant.Status.MALICE)
	if malice != 0:
		lines.append(MALICE_TOOLTIP % [malice, malice])
	var ward := combatant.stacks(Combatant.Status.WARD)
	if ward != 0:
		lines.append(WARD_TOOLTIP % [ward, ward])
	var scent := combatant.stacks(Combatant.Status.SCENT)
	if scent > 0:
		lines.append(SCENT_TOOLTIP % [scent, scent, Combatant.SCENT_CAP])
	if combatant.hold > 0:
		lines.append("Hold %d: up to %d of the Block you have left is kept for your next turn." % [combatant.hold, combatant.hold])
	if combatant.thorns > 0:
		lines.append("Thorns %d: each enemy attack on you also deals %d to the attacker this turn." % [combatant.thorns, combatant.thorns])
	return "\n".join(lines)
