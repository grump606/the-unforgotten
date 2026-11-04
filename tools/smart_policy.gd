class_name SmartPolicy
extends RefCounted
## "Smart" sim policy: a stronger player model than the greedy SimPolicy, used by
## run_sim.gd --policy smart so balance can be judged at more than one skill level.
## Uses only the public Combat, RunState and Vendor APIs.
##
## Combat: before each play every playable (card, target) pair is scored and the
## best score per energy (value / (cost + 1)) is played; the turn ends when
## nothing has positive value. Value of a card is the sum of its effects:
##  - Damage: HP actually removed (after the target's Expose and block), weighted
##    by 1 + the target's threat / its HP, so the enemy that threatens the most
##    damage per HP is focused. A killing blow adds a bonus of 4 + 1.5 x the
##    killed enemy's threat. Overkill is not counted, so a finisher is preferred
##    to a bigger hit that wastes damage. Sweep sums over every living enemy.
##  - Block: 2 per point that cancels incoming damage still unblocked, 0.1 per
##    wasted point ("block exactly").
##  - Draw: 1.5 per card while energy is left to use it, else 0.2.
##  - Expose on an enemy: half the damage of the other affordable damage cards
##    that the Expose multiplier would boost this turn (expose before damage),
##    plus a little for extra turns; 0 if it is already exposed. An Expose that
##    has damage to boost also gets a large ordering bonus so it is played first.
##    Expose on self is penalised.
## The per-energy ratio makes the policy spend its energy on the best total rather
## than the single best card, and free cards (ratio = value) are played early.
##
##  - Malice / Ward gained by the user: +amount on every later damage hit (Block card), valued per
##    hit (per Block effect) it will boost: the other affordable cards in hand this turn, plus, for a
##    stack that lasts the fight, TYPICAL_REMAINING_TURNS more turns of TYPICAL_HITS_PER_TURN hits. A
##    temporary stack counts this turn's cards only. One that boosts a card in hand gets a large ordering
##    bonus (MALICE_FIRST / WARD_FIRST), like Expose. Negative Malice / Ward on an enemy is worth the
##    damage / Block its next intent loses per turn (a stack on an enemy that is temporary is cleared
##    before the enemy acts, so it is worth nothing).
##  - Shaken on an enemy: a quarter of its next attack, for up to SHAKEN_TURNS_CAP turns, 0 if it has no
##    attack, is already Shaken, or the damage in hand kills it. Frayed on an enemy: a quarter of the Block
##    it is about to gain (0 if it is not about to Block). Shaken or Frayed on the player (a SELF card) is
##    a cost, so such a card only plays when its other effects outweigh it.
##
## Rewards and vendor: a card is scored for the deck as it stands, by effect, as
## sum(damage x w_damage, block x w_block, draw x 2.5, expose x 2) divided by
## (cost + 1). w_damage / w_block lean toward whichever of damage and block points
## the deck has less of (target 55% damage), clamped to 0.5..1.5. The offered
## reward is skipped when its score is below the deck's average card score. At
## the vendor it heals first (same rule as greedy), buys any card scoring above
## the deck average (best first, while gold allows), then removes the weakest card
## (once, if gold remains, the deck has more than MIN_DECK cards and the card
## scores below REMOVE_BELOW x the average). At a reward it may instead use the once-per-run
## free Heal or Remove (see take_reward).

const DAMAGE_SHARE := 0.55
const DRAW_VALUE := 2.5
const EXPOSE_VALUE := 2.0
const EXPOSE_FIRST := 8.0 # ordering bonus for an Expose that has damage to boost
const MIN_DECK := 8
const REMOVE_BELOW := 0.8
## The free reward Heal is used while HP is below this share of max HP.
const HEAL_BELOW := 0.5
const THORNS_VALUE := 0.8 # per thorns point per enemy that attacks this turn
const HAUNT_VALUE := 0.7 # per point of Haunt damage (it lands later, so worth less than a hit)
const HEAL_VALUE := 1.5 # per HP healed
## What a typical Block is worth when a card's damage scales with it (Bash, Cold Steel, Reckoning).
const TYPICAL_BLOCK := 6
const TYPICAL_HAUNT := 4
## A typical enemy attack, for scoring a Shaken card outside a fight.
const TYPICAL_ENEMY_HIT := 8
## Energy a Surge is assumed to spend when a card is scored outside a fight (rewards, vendor, discards).
const TYPICAL_SURGE_ENERGY := 2
## Ordering nudge for a Fading card worth playing: it is lost if still in hand at the end of the turn.
const FADING_URGENCY := 2.0
## Player turns still to come in a fight when a Malice / Ward stack that lasts the fight is played now.
const TYPICAL_REMAINING_TURNS := 3
## Damage hits (and Block effects) the player lands per turn, for the same estimate.
const TYPICAL_HITS_PER_TURN := 2
## Value per extra damage point of Malice, per Block point of Ward (half a useful Block point: it can be wasted).
const MALICE_VALUE := 1.0
const WARD_VALUE := 1.0
## Ordering bonuses so a buff that boosts a card in hand is played before it (cf. EXPOSE_FIRST).
const MALICE_FIRST := 8.0
const WARD_FIRST := 8.0
## Turns of Shaken counted for an enemy (its intents beyond that are unknown), and the value per point of
## damage prevented (high while Block is short of the incoming damage, low once Block already covers it).
const SHAKEN_TURNS_CAP := 2
const PREVENTED_VALUE := 2.0
const PREVENTED_VALUE_COVERED := 0.5
## Value per point of Block an enemy loses to Frayed / negative Ward.
const ENEMY_BLOCK_VALUE := 0.7
## Cost per turn of a Shaken / Frayed the player puts on itself.
const SELF_SHAKEN_COST := 4.0
const SELF_FRAYED_COST := 3.0
## card_score of a Dormant card: it can never be played, so it ranks below everything.
const DORMANT_SCORE := -1.0


## Plays cards until nothing is worth playing or the fight ends, then ends the
## turn. Returns false (after logging) if a chosen play is rejected.
static func play_turn(combat: Combat) -> bool:
	while true:
		var best_hand := -1
		var best_target := -1
		var best_score := 0.0
		for i in combat.piles.hand.size():
			if not combat.can_play(i):
				continue
			var card: CardData = combat.piles.hand[i]
			if SimPolicy.recycles_itself(combat, card):
				continue
			for target in _targets(combat, card):
				var value := _play_value(combat, i, target)
				if card.fading and value > 0.0:
					value += FADING_URGENCY
				var score := value / (_spent_energy(combat, card) + 1)
				if score > best_score:
					best_score = score
					best_hand = i
					best_target = target
		if best_hand == -1:
			break
		if not combat.play_card(best_hand, best_target):
			printerr("SmartPolicy: policy chose an unplayable card (index %d)" % best_hand)
			return false
		if combat.phase != Combat.Phase.PLAYER_TURN:
			return true
	if combat.phase != Combat.Phase.PLAYER_TURN:
		return true
	return combat.end_player_turn(discards_for(combat))


## End-of-turn discard: keeps the Combat.HAND_SIZE highest-scoring cards (card_score, weighted by the
## whole deck's damage/block mix) and discards the rest; discards nothing with HAND_SIZE or fewer.
static func discards_for(combat: Combat) -> Array[int]:
	var all: Array[CardData] = []
	all.append_array(combat.piles.hand)
	all.append_array(combat.piles.draw_pile)
	all.append_array(combat.piles.discard_pile)
	var weights := _weights(all)
	# Anchor and Fading cards do not count toward the five and cannot be discarded: never offer them.
	var candidates: Array[int] = []
	var scores: Array[float] = []
	for i in combat.piles.hand.size():
		if combat.can_discard_card(i):
			candidates.append(i)
			scores.append(card_score(combat.piles.hand[i], weights))
	var out: Array[int] = []
	for k in SimPolicy.worst_indices(scores):
		out.append(candidates[k])
	out.sort()
	return out


## Target indexes to consider: every living enemy for single-target cards, else -1.
static func _targets(combat: Combat, card: CardData) -> Array[int]:
	var targets: Array[int] = []
	if card.target_mode == CardData.TargetMode.SINGLE_ENEMY:
		for i in combat.enemies.size():
			if not combat.enemies[i].is_dead():
				targets.append(i)
	else:
		targets.append(-1)
	return targets


static func _play_value(combat: Combat, hand_index: int, target: int) -> float:
	var card: CardData = combat.piles.hand[hand_index]
	var hit: Array[EnemyUnit] = []
	if card.target_mode == CardData.TargetMode.SINGLE_ENEMY:
		hit.append(combat.enemies[target])
	elif card.target_mode == CardData.TargetMode.ALL_ENEMIES:
		hit = combat.living_enemies()
	var incoming := _incoming_damage(combat)
	var unblocked := maxi(incoming - combat.player.block, 0)
	var energy_left := combat.energy - _spent_energy(combat, card) + _energy_gain(card)
	var value := 0.0
	for effect in card.effects:
		var amount := _scaled_amount(combat, card, effect)
		match effect.kind:
			CardEffect.Kind.DAMAGE, CardEffect.Kind.DAMAGE_PER_BLOCK, CardEffect.Kind.DAMAGE_IF_BLOCK, \
			CardEffect.Kind.DAMAGE_PER_PLAY, CardEffect.Kind.DAMAGE_PER_HAUNT:
				for enemy in hit:
					var lost := _hits_hp_lost(combat.player, enemy, _effect_damage(combat, effect, enemy), _hit_count(combat, card, effect))
					var threat := _threat(combat, enemy)
					value += lost * (1.0 + float(threat) / maxi(enemy.hp, 1))
					if lost >= enemy.hp:
						value += 4.0 + 1.5 * threat
			CardEffect.Kind.HOLD:
				# Block kept for next turn: worth about a third of useful Block.
				value += 0.8 * amount
			CardEffect.Kind.THORNS:
				value += THORNS_VALUE * amount * _attackers(combat)
			CardEffect.Kind.GAIN_ENERGY:
				# Energy only matters while it is what stops me playing cards.
				value += (2.0 if energy_left < 2 else 0.4) * amount
			CardEffect.Kind.HAUNT:
				for enemy in hit:
					value += HAUNT_VALUE * mini(_haunt_total(amount), enemy.hp)
			CardEffect.Kind.LOSE_HP:
				# Dearer the lower the player already is.
				value -= amount * (1.0 + 12.0 / maxi(combat.player.hp - amount, 1))
			CardEffect.Kind.HEAL_PER_HAUNTED:
				var healed := mini(amount * _haunted_count(combat), combat.player.max_hp - combat.player.hp)
				value += HEAL_VALUE * healed
			CardEffect.Kind.BLOCK:
				var gained := combat.player.block_from_card(amount)
				var useful := mini(gained, unblocked)
				unblocked -= useful
				value += 2.0 * useful + 0.1 * (gained - useful)
			CardEffect.Kind.DRAW:
				value += (1.5 if energy_left > 0 else 0.2) * amount
			CardEffect.Kind.EXPOSE:
				if card.target_mode == CardData.TargetMode.SELF:
					value -= 5.0
				else:
					for enemy in hit:
						if enemy.status_turns(Combatant.Status.EXPOSED) == 0:
							var boosted := _other_damage(combat, hand_index, energy_left)
							value += 0.5 * boosted + 0.3 * amount
							if boosted > 0:
								# It only pays if played before the damage, so rank it first.
								value += EXPOSE_FIRST
			CardEffect.Kind.MALICE, CardEffect.Kind.WARD:
				value += _stack_value(combat, hand_index, effect, hit, energy_left, incoming)
			CardEffect.Kind.SHAKEN, CardEffect.Kind.FRAYED:
				value += _debuff_value(combat, card, hand_index, effect, hit, incoming)
	return value


## Value of a Malice or Ward effect (see the header): a positive stack for the user, a negative one on `hit`.
static func _stack_value(combat: Combat, hand_index: int, effect: CardEffect, hit: Array[EnemyUnit], energy_left: int, incoming: int) -> float:
	var is_malice := effect.kind == CardEffect.Kind.MALICE
	if effect.amount >= 0:
		var uses_now := _other_uses(combat, hand_index, energy_left, is_malice)
		var future := 0 if effect.temporary else TYPICAL_REMAINING_TURNS * TYPICAL_HITS_PER_TURN
		var total := float(effect.amount) * (uses_now + future) * (MALICE_VALUE if is_malice else WARD_VALUE)
		var wanted_now := is_malice or incoming > combat.player.block
		if not wanted_now:
			total *= 0.25 # no Block is needed this turn, so only the later uses count for much
		if uses_now > 0 and wanted_now:
			total += MALICE_FIRST if is_malice else WARD_FIRST
		return total
	# Negative: a debuff on the enemies, valued from what their next intent loses each turn. A temporary
	# stack on an enemy is cleared before it acts (Combat), so it never helps.
	if effect.temporary:
		return 0.0
	var total := 0.0
	var turns := float(TYPICAL_REMAINING_TURNS + 1)
	for enemy in hit:
		var intent := enemy.current_intent()
		if intent == null:
			continue
		if is_malice and intent.kind == CardEffect.Kind.DAMAGE:
			var after := Combatant.hit_damage(intent.amount, _with_stack(enemy, effect), combat.player) * maxi(intent.hits, 1)
			total += (_threat(combat, enemy) - after) * turns * PREVENTED_VALUE
		elif not is_malice and intent.kind == CardEffect.Kind.BLOCK:
			total += mini(-effect.amount, intent.amount) * ENEMY_BLOCK_VALUE * turns
	return total


## Value of a Shaken or Frayed effect: on enemies a debuff, on the player (a SELF card) a cost.
static func _debuff_value(combat: Combat, card: CardData, hand_index: int, effect: CardEffect, hit: Array[EnemyUnit], incoming: int) -> float:
	var shaken := effect.kind == CardEffect.Kind.SHAKEN
	if card.target_mode == CardData.TargetMode.SELF:
		return -(SELF_SHAKEN_COST if shaken else SELF_FRAYED_COST) * effect.amount
	var total := 0.0
	var per_point := PREVENTED_VALUE if incoming > combat.player.block else PREVENTED_VALUE_COVERED
	var turns := mini(effect.amount, SHAKEN_TURNS_CAP)
	for enemy in hit:
		var intent := enemy.current_intent()
		if intent == null:
			continue
		if shaken:
			if intent.kind != CardEffect.Kind.DAMAGE or enemy.status_turns(Combatant.Status.SHAKEN) > 0:
				continue
			if _other_damage_total(combat, hand_index) >= enemy.hp + enemy.block:
				continue # about to die: nothing left to prevent
			var after := Combatant.hit_damage(intent.amount, _with_stack(enemy, effect), combat.player) * maxi(intent.hits, 1)
			total += (_threat(combat, enemy) - after) * turns * per_point
		elif intent.kind == CardEffect.Kind.BLOCK and enemy.stacks(Combatant.Status.FRAYED) == 0:
			total += _frayed_loss(intent.amount) * ENEMY_BLOCK_VALUE * turns
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


## Block points a Block of `amount` loses to Frayed (3/4, rounded down, never below 1).
static func _frayed_loss(amount: int) -> int:
	return 0 if amount <= 0 else amount - maxi(amount * Combatant.REDUCED_NUM / Combatant.REDUCED_DEN, 1)


## Damage hits (is_malice) or Block effects of the other cards in hand that `energy_left` can pay for.
static func _other_uses(combat: Combat, hand_index: int, energy_left: int, is_malice: bool) -> int:
	var total := 0
	for j in combat.piles.hand.size():
		var other: CardData = combat.piles.hand[j]
		if j == hand_index or other.cost > energy_left:
			continue
		for effect in other.effects:
			if is_malice and effect.is_damage():
				total += maxi(effect.hits, 1)
			elif not is_malice and effect.kind == CardEffect.Kind.BLOCK:
				total += 1
	return total


## Raw damage of the other cards in hand (affordable or not): a rough "will the enemy die anyway" check.
static func _other_damage_total(combat: Combat, hand_index: int) -> int:
	var total := 0
	for j in combat.piles.hand.size():
		if j == hand_index:
			continue
		for effect in combat.piles.hand[j].effects:
			if effect.kind == CardEffect.Kind.DAMAGE:
				total += effect.amount * maxi(effect.hits, 1)
	return total


## Energy playing `card` now spends: its cost, or everything there is for a Surge.
static func _spent_energy(combat: Combat, card: CardData) -> int:
	return combat.energy if card.surge else card.cost


## `effect.amount` as it would apply now: a per_energy effect on a Surge card is multiplied by the energy
## spent (damage kinds scale their hits instead, see _hit_count).
static func _scaled_amount(combat: Combat, card: CardData, effect: CardEffect) -> int:
	if card.surge and effect.per_energy and not effect.is_damage():
		return effect.amount * combat.energy
	return effect.amount


## Hits `effect` would land now: its hits (at least 1), times the energy spent for a per_energy Surge.
static func _hit_count(combat: Combat, card: CardData, effect: CardEffect) -> int:
	var hits := maxi(effect.hits, 1)
	if card.surge and effect.per_energy:
		hits *= combat.energy
	return hits


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


## The damage `effect` would deal to `enemy` if its card were played now (before Expose and Block).
static func _effect_damage(combat: Combat, effect: CardEffect, enemy: EnemyUnit) -> int:
	match effect.kind:
		CardEffect.Kind.DAMAGE_PER_BLOCK:
			return combat.player.block * effect.amount
		CardEffect.Kind.DAMAGE_IF_BLOCK:
			return effect.bonus if combat.player.block >= effect.threshold else effect.amount
		CardEffect.Kind.DAMAGE_PER_PLAY:
			# plays_this_turn counts the cards already played, which is what the bonus scales with.
			return effect.amount + effect.bonus * combat.plays_this_turn
		CardEffect.Kind.DAMAGE_PER_HAUNT:
			return enemy.status_turns(Combatant.Status.HAUNTED) * effect.amount
	return effect.amount


## Total damage of a Haunt of `amount` over its life: amount + (amount - 1) + ... + 1.
static func _haunt_total(amount: int) -> int:
	return maxi(amount, 0) * (maxi(amount, 0) + 1) / 2


static func _attackers(combat: Combat) -> int:
	var count := 0
	for enemy in combat.living_enemies():
		if _threat(combat, enemy) > 0:
			count += 1
	return count


static func _haunted_count(combat: Combat) -> int:
	var count := 0
	for enemy in combat.living_enemies():
		if enemy.status_turns(Combatant.Status.HAUNTED) > 0:
			count += 1
	return count


## HP `enemy` would lose to `hits` hits of raw damage `amount` each from `attacker`: every hit goes through
## the shared pipeline (attacker Malice and Shaken, then the enemy's Expose) and Block absorbs across the hits.
static func _hits_hp_lost(attacker: Combatant, enemy: EnemyUnit, amount: int, hits: int) -> int:
	var block := enemy.block
	var hp := enemy.hp
	var total := 0
	for _h in hits:
		var dealt := Combatant.hit_damage(amount, attacker, enemy)
		var absorbed := mini(block, dealt)
		block -= absorbed
		var lost := mini(dealt - absorbed, hp)
		hp -= lost
		total += lost
	return total


## Damage the enemy's next intent would deal to the player (shared pipeline), 0 for other intents.
static func _threat(combat: Combat, enemy: EnemyUnit) -> int:
	return SimPolicy.intent_hit(combat, enemy)


static func _incoming_damage(combat: Combat) -> int:
	return SimPolicy._incoming_damage(combat)


## Sum of damage amounts of the other cards in hand that `energy_left` can pay for
## (each counted once; a rough measure of what an Expose would boost).
static func _other_damage(combat: Combat, hand_index: int, energy_left: int) -> int:
	var total := 0
	for j in combat.piles.hand.size():
		var other: CardData = combat.piles.hand[j]
		if j == hand_index or other.cost > energy_left:
			continue
		for effect in other.effects:
			if effect.kind == CardEffect.Kind.DAMAGE:
				total += effect.amount * maxi(effect.hits, 1)
	return total


## Reward pick: the best-scoring offered card, or null (skip) if even that is
## below the deck's average card score.
static func pick_reward(run: RunState) -> CardData:
	var weights := _weights(run.deck)
	var best: CardData = null
	var best_score := -INF
	for card in run.reward_choices():
		var score := card_score(card, weights)
		if score > best_score:
			best_score = score
			best = card
	if best == null or best_score < _average_score(run.deck, weights):
		return null
	return best


## Resolves the pending reward: the free Heal when HP is under HEAL_BELOW of max, else the
## free Remove (on the weakest deck card) when even the best offered card scores below the
## deck average, else pick_reward. Each alternative is used only while unused. False if rejected.
static func take_reward(run: RunState) -> bool:
	if run.can_reward_heal() and run.player.hp < HEAL_BELOW * run.player.max_hp:
		return run.resolve_reward_heal()
	if run.can_reward_remove() and run.deck.size() > MIN_DECK and pick_reward(run) == null:
		var weights := _weights(run.deck)
		var weakest: CardData = run.deck[0]
		for card in run.deck:
			if card_score(card, weights) < card_score(weakest, weights):
				weakest = card
		return run.resolve_reward_remove(weakest)
	return run.resolve_reward(pick_reward(run))


## Vendor visit per the header. False on a RunState failure.
static func shop(run: RunState) -> bool:
	var vendor := run.vendor()
	if vendor == null:
		printerr("SmartPolicy: no vendor at a vendor stop")
		return false
	if run.player.max_hp - run.player.hp >= Vendor.HEAL_AMOUNT / 2:
		run.vendor_buy_heal()
	if not SimPolicy.buy_relic(run):
		return false
	while true:
		var weights := _weights(run.deck)
		var average := _average_score(run.deck, weights)
		var best_index := -1
		var best_score := average
		var offers := vendor.offers()
		for i in offers.size():
			if offers[i]["sold"] or offers[i]["price"] > run.gold:
				continue
			var score := card_score(offers[i]["card"], weights)
			if score > best_score:
				best_score = score
				best_index = i
		if best_index == -1:
			break
		if not run.vendor_buy_card(best_index).ok:
			printerr("SmartPolicy: vendor refused an affordable card")
			return false
	if run.gold >= Vendor.REMOVE_CARD_PRICE and run.deck.size() > MIN_DECK:
		var weights := _weights(run.deck)
		var weakest := -1
		var weakest_score := INF
		for i in run.deck.size():
			var score := card_score(run.deck[i], weights)
			if score < weakest_score:
				weakest_score = score
				weakest = i
		if weakest_score < REMOVE_BELOW * _average_score(run.deck, weights):
			if not run.vendor_remove_card(weakest).ok:
				printerr("SmartPolicy: vendor refused a removal")
				return false
	return run.leave_vendor()


## Damage and block weights {damage, block} leaning toward what the deck lacks.
static func _weights(deck: Array[CardData]) -> Dictionary:
	var damage := 0.0
	var block := 0
	for card in deck:
		for effect in card.effects:
			damage += _nominal_damage(effect)
			if effect.kind == CardEffect.Kind.BLOCK:
				block += effect.amount
	var share := DAMAGE_SHARE if damage + block == 0 else float(damage) / (damage + block)
	return {
		"damage": clampf(1.0 + (DAMAGE_SHARE - share) * 2.0, 0.5, 1.5),
		"block": clampf(1.0 + (share - DAMAGE_SHARE) * 2.0, 0.5, 1.5),
	}


static func card_score(card: CardData, weights: Dictionary) -> float:
	if card.dormant:
		return DORMANT_SCORE
	var total := 0.0
	for effect in card.effects:
		var nominal := _nominal_damage(effect)
		if nominal > 0.0:
			var spread := 1.3 if card.target_mode == CardData.TargetMode.ALL_ENEMIES else 1.0
			total += nominal * weights["damage"] * spread
			continue
		var amount := effect.amount
		if effect.per_energy:
			amount *= TYPICAL_SURGE_ENERGY
		match effect.kind:
			CardEffect.Kind.BLOCK:
				total += amount * weights["block"]
			CardEffect.Kind.DRAW:
				total += amount * DRAW_VALUE
			CardEffect.Kind.EXPOSE:
				total += amount * EXPOSE_VALUE
			CardEffect.Kind.HOLD:
				total += amount * 0.8
			CardEffect.Kind.THORNS:
				total += amount * 1.5
			CardEffect.Kind.GAIN_ENERGY:
				total += amount * 3.0
			CardEffect.Kind.LOSE_HP:
				total -= amount * 1.3
			CardEffect.Kind.HEAL_PER_HAUNTED:
				total += amount * HEAL_VALUE
			CardEffect.Kind.MALICE, CardEffect.Kind.WARD:
				total += _stack_score(card, effect, weights)
			CardEffect.Kind.SHAKEN, CardEffect.Kind.FRAYED:
				total += _debuff_score(card, effect)
	# A Surge spends all its energy, so it is divided by a typical amount rather than its cost of 0.
	return total / ((TYPICAL_SURGE_ENERGY if card.surge else card.cost) + 1)


## Deck-scoring value of a Malice / Ward effect: a positive stack for the user is worth its amount on
## TYPICAL_HITS_PER_TURN hits (or Block effects) a turn, for this turn only when temporary, else the
## fight's typical remaining turns too; a negative one on an enemy is worth the damage it cuts from one
## attack a turn (Malice) or half that (Ward, only matters against Block), and nothing when temporary.
static func _stack_score(card: CardData, effect: CardEffect, weights: Dictionary) -> float:
	var is_malice := effect.kind == CardEffect.Kind.MALICE
	if effect.amount >= 0:
		var turns := 1 if effect.temporary else TYPICAL_REMAINING_TURNS + 1
		var weight: float = weights["damage"] if is_malice else weights["block"]
		return effect.amount * TYPICAL_HITS_PER_TURN * turns * (MALICE_VALUE if is_malice else WARD_VALUE) * weight
	if effect.temporary:
		return 0.0
	var cut := float(-effect.amount) * (TYPICAL_REMAINING_TURNS + 1)
	return cut * PREVENTED_VALUE_COVERED * (2.0 if is_malice else 1.0)


## Deck-scoring value of a Shaken / Frayed effect: on enemies, SHAKEN_TURNS_CAP turns of a quarter of a
## typical TYPICAL_ENEMY_HIT (Frayed: of a typical Block); on the player a cost.
static func _debuff_score(card: CardData, effect: CardEffect) -> float:
	var shaken := effect.kind == CardEffect.Kind.SHAKEN
	if card.target_mode == CardData.TargetMode.SELF:
		return -(SELF_SHAKEN_COST if shaken else SELF_FRAYED_COST) * effect.amount
	var turns := mini(effect.amount, SHAKEN_TURNS_CAP)
	if shaken:
		return turns * 0.25 * TYPICAL_ENEMY_HIT * PREVENTED_VALUE_COVERED * 2.0
	return turns * 0.25 * TYPICAL_BLOCK * ENEMY_BLOCK_VALUE * 0.5


## Rough damage an effect is worth in a deck-scoring context (a typical Block, Haunt or number of
## earlier plays stands in for the state a real fight would supply). 0 for non-damage effects.
static func _nominal_damage(effect: CardEffect) -> float:
	var multiplier := float(maxi(effect.hits, 1))
	if effect.per_energy:
		multiplier *= TYPICAL_SURGE_ENERGY
	return _nominal_damage_once(effect) * multiplier


static func _nominal_damage_once(effect: CardEffect) -> float:
	match effect.kind:
		CardEffect.Kind.DAMAGE:
			return float(effect.amount)
		CardEffect.Kind.DAMAGE_PER_BLOCK:
			return float(TYPICAL_BLOCK * effect.amount)
		CardEffect.Kind.DAMAGE_IF_BLOCK:
			return (effect.amount + effect.bonus) / 2.0
		CardEffect.Kind.DAMAGE_PER_PLAY:
			return float(effect.amount + 2 * effect.bonus)
		CardEffect.Kind.DAMAGE_PER_HAUNT:
			return float(TYPICAL_HAUNT * effect.amount)
		CardEffect.Kind.HAUNT:
			return HAUNT_VALUE * _haunt_total(effect.amount)
	return 0.0


static func _average_score(deck: Array[CardData], weights: Dictionary) -> float:
	if deck.is_empty():
		return 0.0
	var total := 0.0
	for card in deck:
		total += card_score(card, weights)
	return total / deck.size()
