class_name SmartPlayValue
extends RefCounted
## The smart bot's fight scoring (see SmartPolicy's header, "Combat"): what playing a hand card on a target is worth
## right now, effect by effect (damage weighted by threat with a kill bonus, Block against what is still unblocked,
## Draw, Expose, Malice / Ward, Shaken / Frayed, Scent, Haunt, Glimpse, Recall, added cards, an Oath's later firings),
## plus the hand-wide estimates those values lean on. SmartPolicy.play_turn picks plays from it. Reads the Combat
## only (its previews included); deck-style scores come from SmartCardScore.

const EXPOSE_FIRST := 8.0 # ordering bonus for an Expose that has damage to boost
const THORNS_VALUE := 0.8 # per thorns point per enemy that attacks this turn
## A point of Scent is worth a point of damage per later hit. Share of a typical fight's remaining hits that count
## (the quarry may die first), the ordering bonus for marking before the attacks that use it, and a small preference
## for marking the enemy that already holds Scent.
const SCENT_HIT_VALUE := 1.0
const SCENT_FUTURE_SHARE := 0.8
const SCENT_FIRST := 6.0
const SCENT_FOCUS := 1.0
const SCENT_TARGET_HP_COST := 0.01 # per HP the Scent target has left: a weaker target is the better quarry
const UNWANTED_BLOCK_SHARE := 0.25 # share of a Malice/Ward still worth it when no Block is needed this turn
## Ordering bonuses so a buff that boosts a card in hand is played before it (cf. EXPOSE_FIRST).
const MALICE_FIRST := 8.0
const WARD_FIRST := 8.0
## Value per point of damage prevented while Block is short of the incoming damage (once it covers it:
## SmartCardScore.PREVENTED_VALUE_COVERED).
const PREVENTED_VALUE := 2.0
## Glimpse: value of each of the top n cards that is junk (Dormant, or scoring below the average card).
const GLIMPSE_JUNK_VALUE := 1.0
## Recall / Add card: share of a card's full value counted when it lands in hand but cannot be paid for this turn
## (the other shares are SmartCardScore's).
const HAND_UNPLAYABLE_SHARE := 0.15
## Block that cancels incoming damage is worth this per point, Block beyond what is needed this per point.
const BLOCK_USEFUL_VALUE := 2.0
const BLOCK_WASTED_VALUE := 0.1
## A killing blow adds KILL_BONUS plus KILL_THREAT_WEIGHT x the killed enemy's threat.
const KILL_BONUS := 4.0
const KILL_THREAT_WEIGHT := 1.5
## Hold (Block kept for next turn) is worth about a third of useful Block, per point.
const HOLD_VALUE := 0.8
## Gain energy, per point: dear while energy is what stops me playing cards (under GAIN_ENERGY_SCARCE_BELOW left), cheap after.
const GAIN_ENERGY_SCARCE_VALUE := 2.0
const GAIN_ENERGY_SPARE_VALUE := 0.4
const GAIN_ENERGY_SCARCE_BELOW := 2
## Lose HP costs the amount times 1 + LOSE_HP_LOW_HP_WEIGHT / the HP left after paying: dearer the lower the player is.
const LOSE_HP_LOW_HP_WEIGHT := 12.0
## Draw, per card: DRAW_PLAYABLE_VALUE while energy is left to use it, else DRAW_SPARE_VALUE.
const DRAW_PLAYABLE_VALUE := 1.5
const DRAW_SPARE_VALUE := 0.2
## Expose: a self-targeted one costs EXPOSE_SELF_COST; on an enemy it is worth EXPOSE_BOOST_SHARE of the damage it
## would boost plus EXPOSE_TURN_VALUE per turn.
const EXPOSE_SELF_COST := 5.0
const EXPOSE_BOOST_SHARE := 0.5
const EXPOSE_TURN_VALUE := 0.3


## True if playing `card` on `target` kills that enemy (so a Forgotten card is not wasted).
static func kills(combat: Combat, card: CardData, target: int) -> bool:
	if target < 0 or target >= combat.enemies.size():
		return false
	var enemy := combat.enemies[target]
	var lost := 0
	var block := enemy.block
	for effect in card.effects:
		if effect.is_damage():
			var outcome := _damage_outcome(combat, card, effect, enemy, block)
			block = outcome.block_left
			lost += outcome.lost
	return lost >= enemy.hp


## Value of playing the hand card `hand_index` on `target` now. incoming is the enemies' incoming damage
## (Combat.incoming_damage); -1 works it out.
static func play_value(combat: Combat, hand_index: int, target: int, incoming: int = -1) -> float:
	var card: CardData = combat.piles.hand[hand_index]
	var hit: Array[EnemyUnit] = []
	if card.target_mode == CardData.TargetMode.SINGLE_ENEMY:
		hit.append(combat.enemies[target])
	elif card.target_mode == CardData.TargetMode.ALL_ENEMIES:
		hit = combat.living_enemies()
	if incoming < 0:
		incoming = combat.incoming_damage()
	var unblocked := maxi(incoming - combat.player.block, 0)
	var energy_left := combat.energy - combat.spent_energy(card) + _energy_gain(card)
	var value := 0.0
	# Each target's Block as the card's damage effects wear it down, in order (the engine's order too).
	var blocks := {}
	for effect in card.effects:
		# Block is the one effect that spends the running `unblocked` total, so it is priced here.
		if effect.kind == CardEffect.Kind.BLOCK:
			var gained := combat.player.block_from_card(effect.scaled_amount(combat.surge_scale(card)))
			var useful := mini(gained, unblocked)
			unblocked -= useful
			value += BLOCK_USEFUL_VALUE * useful + BLOCK_WASTED_VALUE * (gained - useful)
			continue
		value = _effect_value(combat, card, hand_index, effect, hit, incoming, energy_left, value, blocks)
	if card.oath:
		value += _oath_value(combat, card)
	return value


## `value` plus what one non-Block effect of `card` is worth when played now (see play_value). Takes and
## returns the running total so the floating-point additions keep their order. `blocks` maps each enemy to
## the Block left after the card's earlier damage effects (absent: its current Block); damage updates it.
static func _effect_value(combat: Combat, card: CardData, hand_index: int, effect: CardEffect, hit: Array[EnemyUnit], incoming: int, energy_left: int, value: float, blocks: Dictionary) -> float:
	var amount := effect.scaled_amount(combat.surge_scale(card))
	if effect.is_damage():
		for enemy in hit:
			var outcome := _damage_outcome(combat, card, effect, enemy, blocks.get(enemy, enemy.block))
			blocks[enemy] = outcome.block_left
			var lost: int = outcome.lost
			var threat := combat.intent_hit(enemy)
			value += lost * (1.0 + float(threat) / maxi(enemy.hp, 1))
			if lost >= enemy.hp:
				value += KILL_BONUS + KILL_THREAT_WEIGHT * threat
			elif effect.kind == CardEffect.Kind.DAMAGE_PER_SCENT:
				value -= _spend_cost(combat, hand_index, enemy, energy_left)
		return value
	match effect.kind:
		CardEffect.Kind.HOLD:
			# Block kept for next turn: worth about a third of useful Block.
			value += HOLD_VALUE * amount
		CardEffect.Kind.THORNS:
			value += THORNS_VALUE * amount * _attackers(combat)
		CardEffect.Kind.GAIN_ENERGY:
			# Energy only matters while it is what stops me playing cards.
			value += (GAIN_ENERGY_SCARCE_VALUE if energy_left < GAIN_ENERGY_SCARCE_BELOW else GAIN_ENERGY_SPARE_VALUE) * amount
		CardEffect.Kind.HAUNT:
			for enemy in hit:
				value += SmartCardScore.HAUNT_VALUE * mini(SmartCardScore.haunt_total(amount), enemy.hp)
		CardEffect.Kind.LOSE_HP:
			# Dearer the lower the player already is.
			value -= amount * (1.0 + LOSE_HP_LOW_HP_WEIGHT / maxi(combat.player.hp - amount, 1))
		CardEffect.Kind.HEAL_PER_HAUNTED:
			var healed := mini(amount * combat.haunted_count(), combat.player.max_hp - combat.player.hp)
			value += SmartCardScore.HEAL_VALUE * healed
		CardEffect.Kind.DRAW:
			value += (DRAW_PLAYABLE_VALUE if energy_left > 0 else DRAW_SPARE_VALUE) * amount
		CardEffect.Kind.EXPOSE:
			if card.target_mode == CardData.TargetMode.SELF:
				value -= EXPOSE_SELF_COST
			else:
				for enemy in hit:
					if enemy.status_turns(Combatant.Status.EXPOSED) == 0:
						var boosted := other_damage(combat, hand_index, energy_left)
						value += EXPOSE_BOOST_SHARE * boosted + EXPOSE_TURN_VALUE * amount
						if boosted > 0:
							# It only pays if played before the damage, so rank it first.
							value += EXPOSE_FIRST
		CardEffect.Kind.SCENT:
			value += _scent_value(combat, hand_index, effect, hit, energy_left)
		CardEffect.Kind.MALICE, CardEffect.Kind.WARD:
			value += _stack_value(combat, hand_index, effect, hit, energy_left, incoming)
		CardEffect.Kind.SHAKEN, CardEffect.Kind.FRAYED:
			value += _debuff_value(combat, card, hand_index, effect, hit, incoming)
		CardEffect.Kind.GLIMPSE:
			value += _glimpse_value(combat, effect)
		CardEffect.Kind.RECALL:
			value += _recall_value(combat, effect, energy_left)
		CardEffect.Kind.ADD_CARD:
			value += _added_value(combat, effect, energy_left)
		CardEffect.Kind.FILE, CardEffect.Kind.CROSS_OUT:
			pass # an enemy's tool; a File card of ours is never worth playing for its own sake
		_:
			# BLOCK is priced by play_value and never reaches here, so any kind landing here is new.
			SimPolicy.bot_error("SmartPlayValue._effect_value: no valuation for CardEffect.Kind %d" % effect.kind)
	return value


## Turns an Oath sworn now will still act on: it first fires on the next turn, so the turns left in a typical
## fight (TYPICAL_REMAINING_TURNS + 1 on turn 1, one fewer each turn) minus this one, never below 0.
static func oath_turns_left(combat: Combat) -> int:
	return maxi(SmartCardScore.TYPICAL_REMAINING_TURNS + 2 - combat.turn, 1) - 1


## Value of swearing `card` now: one firing of its oath effects (scored like a deck card's effects, so Block,
## Malice, Haunt, Glimpse and HP loss all count) times the firings left in the fight.
static func _oath_value(combat: Combat, card: CardData) -> float:
	var weights := SmartCardScore.combat_weights(combat)
	var forgotten: int = weights.get("forgotten", SmartCardScore.TYPICAL_FORGOTTEN)
	var once := 0.0
	for effect in card.oath_effects:
		once += SmartCardScore.effect_score(card, effect, weights, forgotten, 0)
	return once * oath_turns_left(combat) * float(SmartCardScore.OATH_FIRING_SHARE[card.oath_trigger])


## Value of a Glimpse: GLIMPSE_JUNK_VALUE for each of the top cards of the draw pile (up to the effect's
## amount) that is Dormant or scores below the average card; 0 when none is junk or the pile is empty.
static func _glimpse_value(combat: Combat, effect: CardEffect) -> float:
	var weights := SmartCardScore.combat_weights(combat)
	var average := SmartCardScore.average_in_cycle(combat, weights)
	var junk := 0
	for card in combat.piles.top_cards(effect.amount):
		if SmartCardScore.glimpse_junk(card, weights, average):
			junk += 1
	return GLIMPSE_JUNK_VALUE * junk


## Value of a Recall: the best `amount` Forgotten cards it could return, each worth HAND_PLAYABLE_SHARE of
## its full value when payable this turn, else HAND_UNPLAYABLE_SHARE; 0 with an empty Forgotten pile.
static func _recall_value(combat: Combat, effect: CardEffect, energy_left: int) -> float:
	var weights := SmartCardScore.combat_weights(combat)
	var values: Array[float] = []
	for card in combat.piles.forgotten:
		values.append(_landed_value(card, weights, SmartCardScore.HAND_PLAYABLE_SHARE if card.cost <= energy_left else HAND_UNPLAYABLE_SHARE))
	values.sort()
	values.reverse()
	var total := 0.0
	for k in mini(effect.amount, values.size()):
		total += values[k]
	return total


## Value of an Add card effect for the player's own piles: a Dormant card is a cost (DORMANT_ADD_COST each),
## any other card is worth a share of its full value that depends on where it lands.
static func _added_value(combat: Combat, effect: CardEffect, energy_left: int) -> float:
	if effect.card == null:
		return 0.0
	if effect.card.dormant:
		return -SmartCardScore.DORMANT_ADD_COST * effect.amount
	var share := SmartCardScore.DISCARD_ADD_SHARE
	match effect.pile:
		CardEffect.Pile.HAND:
			share = SmartCardScore.HAND_PLAYABLE_SHARE if effect.card.cost <= energy_left else HAND_UNPLAYABLE_SHARE
		CardEffect.Pile.DRAW:
			share = SmartCardScore.DRAW_ADD_SHARE
	return effect.amount * _landed_value(effect.card, SmartCardScore.combat_weights(combat), share)


## `share` of a card's whole value (card_score is per energy + 1, so it is scaled back up), never below 0.
static func _landed_value(card: CardData, weights: Dictionary, share: float) -> float:
	return maxf(SmartCardScore.card_score(card, weights), 0.0) * (card.cost + 1) * share


## Value of a Scent effect: each point added to the quarry is +1 on every later hit it takes. That is the other
## affordable damage cards' hits this turn, plus a share of a typical fight's remaining hits (the stack lasts
## until spent, but it can be lost with the quarry). A stack already at the cap adds nothing. A card aimed at
## several enemies marks the current quarry if it is among them, else the first (as Combat does). Marking the
## current quarry is slightly preferred, so the bot focuses one enemy.
static func _scent_value(combat: Combat, hand_index: int, effect: CardEffect, hit: Array[EnemyUnit], energy_left: int) -> float:
	var target: EnemyUnit = null
	for enemy in hit:
		if enemy.stacks(Combatant.Status.SCENT) > 0:
			target = enemy
			break
	if target == null and not hit.is_empty():
		target = hit[0]
	if target == null:
		return 0.0
	var held := 0
	for enemy in combat.enemies:
		held += enemy.stacks(Combatant.Status.SCENT)
	var applied := mini(effect.amount, Combatant.SCENT_CAP - held)
	if applied <= 0:
		return 0.0
	var uses_now := other_uses(combat, hand_index, energy_left, true)
	var future := float(SmartCardScore.TYPICAL_REMAINING_TURNS * SmartCardScore.TYPICAL_HITS_PER_TURN) * SCENT_FUTURE_SHARE
	var total := float(applied) * (uses_now + future) * SCENT_HIT_VALUE
	if uses_now > 0:
		total += SCENT_FIRST
	if target.stacks(Combatant.Status.SCENT) > 0:
		total += SCENT_FOCUS
	return total - SCENT_TARGET_HP_COST * target.hp


## What spending `enemy`'s Scent costs: the extra damage that stack would still have added, on the other cards
## in hand this turn and on later hits. Zero when the spend kills (the caller skips this then).
static func _spend_cost(combat: Combat, hand_index: int, enemy: EnemyUnit, energy_left: int) -> float:
	var stack := enemy.stacks(Combatant.Status.SCENT)
	if stack <= 0:
		return 0.0
	var uses_now := other_uses(combat, hand_index, energy_left, true)
	var future := float(SmartCardScore.TYPICAL_REMAINING_TURNS * SmartCardScore.TYPICAL_HITS_PER_TURN) * SCENT_FUTURE_SHARE
	return float(stack) * (uses_now + future) * SCENT_HIT_VALUE


## Value of a Malice or Ward effect (see SmartPolicy's header): a positive stack for the user, a negative one on `hit`.
static func _stack_value(combat: Combat, hand_index: int, effect: CardEffect, hit: Array[EnemyUnit], energy_left: int, incoming: int) -> float:
	var is_malice := effect.kind == CardEffect.Kind.MALICE
	if effect.amount >= 0:
		var uses_now := other_uses(combat, hand_index, energy_left, is_malice)
		var future := 0 if effect.temporary else SmartCardScore.TYPICAL_REMAINING_TURNS * SmartCardScore.TYPICAL_HITS_PER_TURN
		var total := float(effect.amount) * (uses_now + future) * (SmartCardScore.MALICE_VALUE if is_malice else SmartCardScore.WARD_VALUE)
		var wanted_now := is_malice or incoming > combat.player.block
		if not wanted_now:
			total *= UNWANTED_BLOCK_SHARE # no Block is needed this turn, so only the later uses count for much
		if uses_now > 0 and wanted_now:
			total += MALICE_FIRST if is_malice else WARD_FIRST
		return total
	# Negative: a debuff on the enemies, valued from what their next intent loses each turn. A temporary
	# stack on an enemy is cleared before it acts (Combat), so it never helps.
	if effect.temporary:
		return 0.0
	var total := 0.0
	var turns := float(SmartCardScore.TYPICAL_REMAINING_TURNS + 1)
	for enemy in hit:
		var intent := enemy.current_intent()
		if intent == null:
			continue
		if is_malice and intent.kind == CardEffect.Kind.DAMAGE:
			var after := Combatant.hit_damage(intent.amount, _with_stack(enemy, effect), combat.player) * maxi(intent.hits, 1)
			total += (combat.intent_hit(enemy) - after) * turns * PREVENTED_VALUE
		elif not is_malice and intent.kind == CardEffect.Kind.BLOCK:
			total += mini(-effect.amount, intent.amount) * SmartCardScore.ENEMY_BLOCK_VALUE * turns
	return total


## Value of a Shaken or Frayed effect: on enemies a debuff, on the player (a SELF card) a cost.
static func _debuff_value(combat: Combat, card: CardData, hand_index: int, effect: CardEffect, hit: Array[EnemyUnit], incoming: int) -> float:
	var shaken := effect.kind == CardEffect.Kind.SHAKEN
	if card.target_mode == CardData.TargetMode.SELF:
		return -(SmartCardScore.SELF_SHAKEN_COST if shaken else SmartCardScore.SELF_FRAYED_COST) * effect.amount
	var total := 0.0
	var per_point := PREVENTED_VALUE if incoming > combat.player.block else SmartCardScore.PREVENTED_VALUE_COVERED
	var turns := mini(effect.amount, SmartCardScore.SHAKEN_TURNS_CAP)
	for enemy in hit:
		var intent := enemy.current_intent()
		if intent == null:
			continue
		if shaken:
			if intent.kind != CardEffect.Kind.DAMAGE or enemy.status_turns(Combatant.Status.SHAKEN) > 0:
				continue
			if other_damage_total(combat, hand_index) >= enemy.hp + enemy.block:
				continue # about to die: nothing left to prevent
			var after := Combatant.hit_damage(intent.amount, _with_stack(enemy, effect), combat.player) * maxi(intent.hits, 1)
			total += (combat.intent_hit(enemy) - after) * turns * per_point
		elif intent.kind == CardEffect.Kind.BLOCK and enemy.stacks(Combatant.Status.FRAYED) == 0:
			total += Combatant.frayed_loss(intent.amount) * SmartCardScore.ENEMY_BLOCK_VALUE * turns
	return total


## A stand-in for `enemy` as an attacker with `effect` added (extra Malice, or Shaken), so the shared
## pipeline prices the hit it would then deal. The real enemy is never touched.
static func _with_stack(enemy: EnemyUnit, effect: CardEffect) -> Combatant:
	var dummy := Combatant.new("tmp", 1)
	var malice := enemy.stacks(Combatant.Status.MALICE)
	if effect.kind == CardEffect.Kind.MALICE:
		malice += effect.amount
	dummy.apply_temp_stack(Combatant.Status.MALICE, malice)
	if effect.kind == CardEffect.Kind.SHAKEN or enemy.stacks(Combatant.Status.SHAKEN) > 0:
		dummy.apply_status(Combatant.Status.SHAKEN, 1)
	return dummy


## Damage hits (is_malice) or Block effects of the other cards in hand that `energy_left` can pay for.
static func other_uses(combat: Combat, hand_index: int, energy_left: int, is_malice: bool) -> int:
	var total := 0
	for j in combat.piles.hand.size():
		var other: CardData = combat.piles.hand[j]
		if j == hand_index or other.cost > energy_left:
			continue
		for effect in other.effects:
			if is_malice and effect.is_damage():
				total += combat.hit_count(other, effect)
			elif not is_malice and effect.kind == CardEffect.Kind.BLOCK:
				total += 1
	return total


## Rough damage of the other cards in hand (affordable or not): a rough "will the enemy die anyway" check.
static func other_damage_total(combat: Combat, hand_index: int) -> int:
	var total := 0.0
	for j in combat.piles.hand.size():
		if j == hand_index:
			continue
		var other: CardData = combat.piles.hand[j]
		for effect in other.effects:
			total += _hand_damage(combat, other, effect)
	return roundi(total)


## Rough damage that `effect` of the hand card `card` would deal if played now: its per-hit estimate (exact for plain
## DAMAGE, nominal for the scaling kinds) times the engine's hit count (multi-hit, and Surge energy for per_energy).
## 0 for an effect that is not damage.
static func _hand_damage(combat: Combat, card: CardData, effect: CardEffect) -> float:
	if not effect.is_damage():
		return 0.0
	return SmartCardScore.nominal_damage_once(effect, combat.piles.forgotten.size()) * combat.hit_count(card, effect)


## Energy a card gives back when played (Borrowed Time, Seance).
static func _energy_gain(card: CardData) -> int:
	var gained := 0
	for effect in card.effects:
		if effect.kind == CardEffect.Kind.GAIN_ENERGY:
			gained += effect.amount
	return gained


## What a card really costs in energy once its own refund is counted (0 for an energy-neutral card).
static func _net_cost(card: CardData) -> int:
	return maxi(card.cost - _energy_gain(card), 0)


## What damage `effect` of `card` would do to `enemy` if the card were played now (the engine's own preview:
## Malice, Shaken, Expose, every hit, Block wearing down across the hits), with the enemy's Block taken as
## `block` so the card's several damage effects can chain it. The card is not played yet, so it would be play
## number plays_this_turn + 1.
static func _damage_outcome(combat: Combat, card: CardData, effect: CardEffect, enemy: EnemyUnit, block: int) -> Combatant.HitsOutcome:
	return combat.preview_hit(effect, combat.player, enemy, combat.plays_this_turn + 1, combat.hit_count(card, effect), block)


static func _attackers(combat: Combat) -> int:
	var count := 0
	for enemy in combat.living_enemies():
		if combat.intent_hit(enemy) > 0:
			count += 1
	return count


## Sum of damage amounts of the other cards in hand that `energy_left` can pay for
## (each counted once; a rough measure of what an Expose would boost).
static func other_damage(combat: Combat, hand_index: int, energy_left: int) -> int:
	var total := 0.0
	for j in combat.piles.hand.size():
		var other: CardData = combat.piles.hand[j]
		if j == hand_index or other.cost > energy_left:
			continue
		for effect in other.effects:
			total += _hand_damage(combat, other, effect)
	return roundi(total)
