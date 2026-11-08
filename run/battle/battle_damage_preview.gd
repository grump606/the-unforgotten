class_name BattleDamagePreview
extends RefCounted
## DISPLAY-ONLY damage previews for the battle screen: the line on a hand card for the selected enemy, and
## what a card would do to one specific enemy (for a drag). Nothing here changes the fight; the result of an
## actual play is authoritative.

## A defender with no statuses: hit_damage against it is the player's side of a hit only (Malice, Shaken).
static var _NEUTRAL := Combatant.new("Neutral", 1)

var _battle: Battle
## The fight on screen (read through the battle, so a new fight is picked up).
var _combat: Combat:
	get:
		return _battle._combat


func _init(battle: Battle) -> void:
	_battle = battle


## The preview line for `card` against the selected enemy: every hit goes through Combatant.hit_damage (the
## player's Malice and Shaken, then the target's Exposed), then block is subtracted per hit as take_damage_final
## does. "" when the card deals no damage or has no single target to show.
func line_for(card: CardData, target_index: int) -> String:
	var damage_effects: Array[CardEffect] = []
	for effect in card.effects:
		if effect.is_damage():
			damage_effects.append(effect)
	if damage_effects.is_empty() or card.dormant:
		return ""
	# The card being played will count as one more play this turn.
	var plays: int = _combat.plays_this_turn + 1
	if card.target_mode == CardData.TargetMode.ALL_ENEMIES:
		# Haunt differs per enemy, so a per-Haunt hit has no single number.
		var all_base := 0
		for effect in damage_effects:
			if effect.kind == CardEffect.Kind.DAMAGE_PER_HAUNT or effect.kind == CardEffect.Kind.DAMAGE_PER_SCENT:
				return ""
			all_base += _combat.hit_amount(effect, _combat.player, _NEUTRAL, plays) * _hit_count(card, effect)
		return "\nDeals %d (x%d enemies)" % [all_base, _combat.living_enemies().size()]
	var target := _combat.enemies[target_index]
	if card.target_mode != CardData.TargetMode.SINGLE_ENEMY or target.is_dead():
		return ""
	return for_target(card, target).get("text", "")


## How many times `effect` of `card` would hit if played now. A Surge card's per_energy damage hits
## once per point of the energy it WOULD spend (all the current energy).
func _hit_count(card: CardData, effect: CardEffect) -> int:
	var count := maxi(effect.hits, 1)
	if card.surge and effect.per_energy:
		count *= _combat.energy
	return count


## What `card` would do to this one enemy (works for single-target and all-enemies cards alike, so a drag can
## compare enemies). Returns {} when the card deals no damage, is Dormant, or the enemy is dead, else
## {text, dealt, lost}: `dealt` is the damage after Exposed summed over every hit, `lost` what is left after
## Block (hit by hit), and `text` is the card-face line ("\nDeals 15 (10 vs Exposed), 6 after Block", or
## "\nDeals 12 (3 x4)" for a multi-hit).
func for_target(card: CardData, target: EnemyUnit) -> Dictionary:
	if target == null or target.is_dead() or card.dormant or not _has_damage(card):
		return {}
	# The card being played will count as one more play this turn. Raw damage per hit comes from the engine's
	# own context rule; Block absorption and Expose from the shared hit helpers (Combatant.hits_outcome).
	var context := _combat.damage_context(_combat.player, target, _combat.plays_this_turn + 1)
	var hits: Array[int] = []
	for effect in card.effects:
		if effect.is_damage():
			var raw := effect.raw_damage(context)
			for _h in _hit_count(card, effect):
				hits.append(raw)
	var exposed := target.status_turns(Combatant.Status.EXPOSED) > 0
	var block_left := target.block
	var base := 0
	var dealt := 0
	var lost := 0
	for hit in hits:
		base += Combatant.hit_damage(hit, _combat.player, _NEUTRAL)
		var outcome := Combatant.hits_outcome(_combat.player, target, hit, 1, block_left)
		block_left = outcome["block_left"]
		dealt += outcome["damage"]
		lost += outcome["through"]
	var text := "\nDeals %d" % dealt
	if exposed:
		text = "\nDeals %d (%d vs Exposed)" % [base, dealt]
	elif hits.size() > 1 and _uniform(hits):
		text = "\nDeals %d (%d x%d)" % [dealt, Combatant.hit_damage(hits[0], _combat.player, _NEUTRAL), hits.size()]
	if target.block > 0:
		text += ", %d after Block" % lost
	return {"text": text, "dealt": dealt, "lost": mini(lost, target.hp)}


func _has_damage(card: CardData) -> bool:
	for effect in card.effects:
		if effect.is_damage():
			return true
	return false


## True when every hit in `hits` is the same size.
func _uniform(hits: Array[int]) -> bool:
	for hit in hits:
		if hit != hits[0]:
			return false
	return true
