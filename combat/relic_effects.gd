class_name RelicEffects
extends RefCounted
## What the run's relics do inside one fight, by hook: after a card is played, as a turn begins, at the end of
## the turn. Combat owns one and delegates; it holds the per-kind amount totals and the once-per-fight triggers
## already spent. The hooks take the Combat as an argument (no back-reference is stored, so nothing leaks).
## Effects inside a hook run in the order they are written; they draw no random numbers.

# Relic amounts summed per kind (see total); rebuilt whenever the list is assigned.
var _totals: Dictionary = {}
var _has_relics := false
# Once-per-fight triggers already spent (FIRST_FORGOTTEN_RETURN, FIRST_ATTACK_SHAKEN).
var forgotten_return_used := false
var first_attack_used := false


## Replaces the owned relics: the totals are rebuilt from them (the spent triggers are kept).
func set_relics(relics: Array[RelicData]) -> void:
	_totals.clear()
	_has_relics = not relics.is_empty()
	for relic in relics:
		_totals[relic.kind] = _totals.get(relic.kind, 0) + relic.amount


## True when at least one relic is owned.
func has_relics() -> bool:
	return _has_relics


## Sum of `amount` over the owned relics of `kind` (0 with none).
func total(kind: RelicData.Kind) -> int:
	return _totals.get(kind, 0)


## Hook after a card's own effects: the first play of a turn draws, every PLAYS_BLOCK_EVERY-th play gains Block,
## the first Forgotten card comes back, the first attack Shakes. combat.plays_this_turn already counts the card
## just played.
func after_play(combat: Combat, card: CardData, targets: Array[EnemyUnit]) -> void:
	var piles := combat.piles
	if combat.plays_this_turn == 1 and total(RelicData.Kind.FIRST_PLAY_DRAW) > 0:
		piles.draw(total(RelicData.Kind.FIRST_PLAY_DRAW), Combat.HAND_MAX)
	if combat.plays_this_turn % RelicData.PLAYS_BLOCK_EVERY == 0 and total(RelicData.Kind.PLAYS_BLOCK) > 0:
		combat.player.gain_block(total(RelicData.Kind.PLAYS_BLOCK))
	# The first Forgotten card played this fight comes straight back from the Forgotten pile.
	# Only a card that really landed in the pile counts: an Oath goes to the Sworn list instead.
	if _forgotten_return_ready(piles):
		forgotten_return_used = true
		var last: Array[int] = [piles.forgotten.size() - 1]
		piles.recall_from_forgotten(last, Combat.HAND_MAX)
	# The first attack (a card that deals damage) this fight Shakes the enemies it was played on.
	if not first_attack_used and total(RelicData.Kind.FIRST_ATTACK_SHAKEN) > 0:
		for effect in card.effects:
			if effect.is_damage():
				first_attack_used = true
				for target in targets:
					target.apply_status(Combatant.Status.SHAKEN, total(RelicData.Kind.FIRST_ATTACK_SHAKEN))
				break


func _forgotten_return_ready(piles: CardPiles) -> bool:
	return (
		piles.last_play_destination == CardPiles.Destination.FORGOTTEN
		and not piles.forgotten.is_empty()
		and not forgotten_return_used
		and total(RelicData.Kind.FIRST_FORGOTTEN_RETURN) > 0
	)


## Hook as a turn begins. Runs after start_turn_block(), which resets Block to Hold and Thorns to 0, so these
## grants are not wiped. Fight-start effects come first on turn 1 so that a starting Haunt already counts for
## the turn-start heal.
func turn_start(combat: Combat) -> void:
	if not _has_relics:
		return
	var player := combat.player
	var block := total(RelicData.Kind.TURN_START_BLOCK)
	if combat.turn == 1:
		for enemy in combat.enemies:
			enemy.apply_status(Combatant.Status.HAUNTED, total(RelicData.Kind.FIGHT_START_HAUNT))
		block += total(RelicData.Kind.FIGHT_START_BLOCK)
		combat.energy += total(RelicData.Kind.FIRST_TURN_ENERGY)
		# Malice and Ward from relics last the whole fight (cleared with the statuses at fight end).
		var malice := total(RelicData.Kind.FIGHT_START_MALICE)
		if malice > 0:
			player.apply_status(Combatant.Status.MALICE, malice)
		# The first living enemy becomes the quarry from the first turn.
		var scent := total(RelicData.Kind.FIGHT_START_SCENT)
		if scent > 0 and combat.first_living() != null:
			ScentRules.give(combat.enemies, combat.first_living(), scent)
		var ward := total(RelicData.Kind.FIGHT_START_WARD)
		if ward > 0:
			player.apply_status(Combatant.Status.WARD, ward)
	if block > 0:
		player.gain_block(block)
	var thorns := total(RelicData.Kind.TURN_START_THORNS)
	if thorns > 0:
		player.add_thorns(thorns)
	var heal := total(RelicData.Kind.TURN_START_HEAL_PER_HAUNTED) * combat.haunted_count()
	if heal > 0:
		player.heal(heal)


## Hook at the end of the turn, after Fading cards are lost: kept Anchor cards shield the player through the
## enemy phase.
func end_of_turn(combat: Combat) -> void:
	var anchor_block := total(RelicData.Kind.ANCHOR_END_BLOCK)
	if anchor_block <= 0:
		return
	var anchored := 0
	for held in combat.piles.hand:
		if held.anchor:
			anchored += 1
	if anchored > 0:
		combat.player.gain_block(anchor_block * anchored)
