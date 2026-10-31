class_name Combat
extends RefCounted
## One fight between the player and 1 to MAX_ENEMIES enemies. Holds rules only:
## no nodes, no scenes. A UI observes the signals; a run layer supplies the
## player's Combatant and deck, and reads the outcome from `combat_ended`.

enum Phase { NOT_STARTED, PLAYER_TURN, ENEMY_TURN, ENDED }

const HAND_SIZE := 5
const ENERGY_PER_TURN := 3
const MAX_ENEMIES := 3
## Safety cap on cards played in one turn. Zero-cost draw cards can recycle
## themselves in a thin deck, so without it a turn could (in principle) never
## end; ordinary play stays far below it. After the cap the player can only end
## the turn.
const MAX_PLAYS_PER_TURN := 50

signal state_changed
## `targets` are the enemies the card hit (empty for SELF cards).
signal card_played(card: CardData, targets: Array[EnemyUnit])
signal enemy_acted(enemy: EnemyUnit, intent: CardEffect)
signal combat_ended(victory: bool)

var player: Combatant
## Fixed order for the whole fight. Defeated enemies stay in the list so
## target indices remain stable; use `living_enemies()` to skip them.
var enemies: Array[EnemyUnit] = []
var piles: CardPiles
var energy: int = 0
var turn: int = 0
var phase: Phase = Phase.NOT_STARTED
## Cards played so far this turn (see MAX_PLAYS_PER_TURN).
var plays_this_turn: int = 0
## The run's relics for this fight (see RelicData); empty changes nothing.
var relics: Array[RelicData] = []

# EXPOSE turns that enemy intents applied to the player this enemy phase. They
# are held back until the player's statuses have ticked, so they start counting
# from the next enemy phase instead of ticking away unused.
var _pending_player_expose: int = 0

# The player outlives this fight, so the connection that forwards its changes to
# state_changed is removed when the fight ends; otherwise every finished fight
# would stay alive and keep re-emitting.
var _player_changed_link: Callable = state_changed.emit


## Builds a fight, or returns null (after logging why) if the enemy list is not
## 1 to MAX_ENEMIES long or the player is already dead. Use this when the inputs
## come from data that could be bad, such as resources that failed to load;
## `new()` only asserts, which release builds skip.
static func create(player_combatant: Combatant, deck: Array[CardData], enemy_datas: Array[EnemyData], rng_seed: int = 0, owned_relics: Array[RelicData] = []) -> Combat:
	if enemy_datas.size() < 1 or enemy_datas.size() > MAX_ENEMIES:
		push_error("Combat.create: needs 1 to %d enemies, got %d" % [MAX_ENEMIES, enemy_datas.size()])
		return null
	if player_combatant.is_dead():
		push_error("Combat.create: the player is already dead")
		return null
	return Combat.new(player_combatant, deck, enemy_datas, rng_seed, owned_relics)


func _init(player_combatant: Combatant, deck: Array[CardData], enemy_datas: Array[EnemyData], rng_seed: int = 0, owned_relics: Array[RelicData] = []) -> void:
	assert(enemy_datas.size() >= 1 and enemy_datas.size() <= MAX_ENEMIES, "Combat needs 1 to %d enemies" % MAX_ENEMIES)
	assert(not player_combatant.is_dead(), "Combat needs a living player")
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	player = player_combatant
	relics = owned_relics.duplicate()
	# The player outlives fights; statuses must not.
	player.clear_statuses()
	piles = CardPiles.new(deck, rng)
	for enemy_data in enemy_datas:
		var enemy := EnemyUnit.new(enemy_data)
		enemy.changed.connect(state_changed.emit)
		enemies.append(enemy)


func start() -> void:
	if phase != Phase.NOT_STARTED:
		# Checked explicitly (not assert) so a release build cannot resurrect an
		# ended or abandoned fight.
		push_error("Combat.start: the fight was already started or has ended")
		return
	# Connected here, not in _init, so a fight that is built and never started holds no listener.
	if not player.changed.is_connected(_player_changed_link):
		player.changed.connect(_player_changed_link)
	_begin_player_turn()


## Gives up on a fight that has not ended (for example a caller's stall cap) so
## the player can be reused: removes the link to the player and ends the fight
## without emitting `combat_ended` or any other signal. No-op once ended.
func abandon() -> void:
	if phase == Phase.ENDED:
		return
	phase = Phase.ENDED
	_disconnect_player()
	player.clear_block()
	player.clear_statuses()


## Safe in every state: an unstarted fight never connected, and an ended one already disconnected.
func _disconnect_player() -> void:
	if player.changed.is_connected(_player_changed_link):
		player.changed.disconnect(_player_changed_link)


func living_enemies() -> Array[EnemyUnit]:
	var living: Array[EnemyUnit] = []
	for enemy in enemies:
		if not enemy.is_dead():
			living.append(enemy)
	return living


func can_play(hand_index: int) -> bool:
	return (
		phase == Phase.PLAYER_TURN
		and hand_index >= 0
		and hand_index < piles.hand.size()
		and piles.hand[hand_index].cost <= energy
		# A card that costs HP cannot be the one that kills the player.
		and piles.hand[hand_index].hp_cost() < player.hp
		and plays_this_turn < MAX_PLAYS_PER_TURN
	)


## Plays a card. For SINGLE_ENEMY cards `target_index` indexes `enemies`:
## -1 picks the first living enemy, and an invalid or defeated target rejects
## the play. ALL_ENEMIES and SELF cards ignore `target_index`. Returns false,
## changing nothing, if the play is not allowed.
func play_card(hand_index: int, target_index: int = -1) -> bool:
	if not can_play(hand_index):
		return false
	var mode := piles.hand[hand_index].target_mode
	var targets: Array[EnemyUnit] = []
	match mode:
		CardData.TargetMode.SINGLE_ENEMY:
			var target := _resolve_target(target_index)
			if target == null:
				return false
			targets.append(target)
		CardData.TargetMode.ALL_ENEMIES:
			targets = living_enemies()
	var card := piles.play(hand_index)
	energy -= card.cost
	plays_this_turn += 1
	for effect in card.effects:
		var reach := effect.reach()
		# SELF cards expose the player; other EXPOSE cards expose their targets.
		if reach == CardEffect.Reach.SELF or (reach == CardEffect.Reach.BOTH and mode == CardData.TargetMode.SELF):
			_apply(effect, player, player)
		if reach != CardEffect.Reach.SELF:
			for target in targets:
				_apply(effect, player, target)
	if not relics.is_empty():
		_apply_play_relics()
	card_played.emit(card, targets)
	if not _check_end():
		state_changed.emit()
	return true


func end_player_turn() -> void:
	if phase != Phase.PLAYER_TURN:
		return
	phase = Phase.ENEMY_TURN
	piles.discard_hand()
	# Haunt hurts first, so an enemy it kills never acts.
	for enemy in living_enemies():
		enemy.lose_hp(enemy.status_turns(Combatant.Status.HAUNTED))
	if _check_end():
		return
	for enemy in living_enemies():
		enemy.clear_block()
		var intent := enemy.current_intent()
		if intent != null:
			_apply(intent, enemy, player)
			enemy_acted.emit(enemy, intent)
		enemy.advance_intent()
		enemy.tick_statuses()
		if _check_end():
			return
	# After the enemies act, so a 1-turn status on the player still covers the
	# enemy phase that follows the turn it was applied in.
	player.tick_statuses()
	# Enemy-applied EXPOSE lands after the tick: amount N exposes the player for
	# the next N enemy phases (not the one that applied it, so even later
	# enemies in that phase hit normally).
	if _pending_player_expose > 0:
		player.apply_status(Combatant.Status.EXPOSED, _pending_player_expose)
		_pending_player_expose = 0
	_begin_player_turn()


func _haunted_count() -> int:
	var count := 0
	for enemy in living_enemies():
		if enemy.status_turns(Combatant.Status.HAUNTED) > 0:
			count += 1
	return count


func _resolve_target(target_index: int) -> EnemyUnit:
	if target_index == -1:
		var living := living_enemies()
		return null if living.is_empty() else living[0]
	if target_index < 0 or target_index >= enemies.size() or enemies[target_index].is_dead():
		return null
	return enemies[target_index]


func _begin_player_turn() -> void:
	turn += 1
	phase = Phase.PLAYER_TURN
	energy = ENERGY_PER_TURN
	plays_this_turn = 0
	player.start_turn_block()
	_apply_turn_start_relics()
	piles.draw(HAND_SIZE)
	state_changed.emit()


## Sum of `amount` over the owned relics of `kind` (0 with none).
func _relic_total(kind: RelicData.Kind) -> int:
	var total := 0
	for relic in relics:
		if relic.kind == kind:
			total += relic.amount
	return total


## Relic effects that fire after a card's own effects: the first play of a turn draws, every
## PLAYS_BLOCK_EVERY-th play gains Block. plays_this_turn already counts the card just played.
func _apply_play_relics() -> void:
	if plays_this_turn == 1 and _relic_total(RelicData.Kind.FIRST_PLAY_DRAW) > 0:
		piles.draw(_relic_total(RelicData.Kind.FIRST_PLAY_DRAW))
	if plays_this_turn % RelicData.PLAYS_BLOCK_EVERY == 0 and _relic_total(RelicData.Kind.PLAYS_BLOCK) > 0:
		player.gain_block(_relic_total(RelicData.Kind.PLAYS_BLOCK))


## Relic effects that fire as a turn begins. Runs after start_turn_block(), which resets Block
## to Hold and Thorns to 0, so these grants are not wiped. Fight-start effects come first on turn 1
## so that a starting Haunt already counts for the turn-start heal.
func _apply_turn_start_relics() -> void:
	if relics.is_empty():
		return
	var block := _relic_total(RelicData.Kind.TURN_START_BLOCK)
	if turn == 1:
		for enemy in enemies:
			enemy.apply_status(Combatant.Status.HAUNTED, _relic_total(RelicData.Kind.FIGHT_START_HAUNT))
		block += _relic_total(RelicData.Kind.FIGHT_START_BLOCK)
		energy += _relic_total(RelicData.Kind.FIRST_TURN_ENERGY)
	if block > 0:
		player.gain_block(block)
	var thorns := _relic_total(RelicData.Kind.TURN_START_THORNS)
	if thorns > 0:
		player.add_thorns(thorns)
	var heal := _relic_total(RelicData.Kind.TURN_START_HEAL_PER_HAUNTED) * _haunted_count()
	if heal > 0:
		player.heal(heal)


## `target` receives damage and statuses; `source` receives block and draws.
## An enemy intent with EXPOSE exposes the player; see `_pending_player_expose`
## for when it takes effect.
func _apply(effect: CardEffect, source: Combatant, target: Combatant) -> void:
	if effect.is_damage():
		# plays_this_turn already counts the card being played.
		target.take_damage(effect.raw_damage(source.block, target.status_turns(Combatant.Status.HAUNTED), plays_this_turn))
		# Thorns: an enemy attack on the player also hurts the attacker.
		if effect.kind == CardEffect.Kind.DAMAGE and target == player and source != player and player.thorns > 0:
			source.take_damage(player.thorns)
		return
	match effect.kind:
		CardEffect.Kind.HOLD:
			source.add_hold(effect.amount)
		CardEffect.Kind.THORNS:
			source.add_thorns(effect.amount)
		CardEffect.Kind.GAIN_ENERGY:
			if source == player:
				energy += maxi(effect.amount, 0)
		CardEffect.Kind.HAUNT:
			if source == player:
				# The Haunt bonus only boosts a Haunt that was going to be applied at all.
				target.apply_status(Combatant.Status.HAUNTED, effect.amount + (_relic_total(RelicData.Kind.HAUNT_BONUS) if effect.amount > 0 else 0))
		CardEffect.Kind.LOSE_HP:
			source.lose_hp(effect.amount)
		CardEffect.Kind.HEAL_PER_HAUNTED:
			source.heal(effect.amount * _haunted_count())
		CardEffect.Kind.BLOCK:
			source.gain_block(effect.amount)
		CardEffect.Kind.DRAW:
			# Only the player has a hand.
			if source == player:
				piles.draw(effect.amount)
		CardEffect.Kind.EXPOSE:
			if source == player:
				target.apply_status(Combatant.Status.EXPOSED, effect.amount)
			elif target == player:
				_pending_player_expose += maxi(effect.amount, 0)
		_:
			push_error("Combat._apply: no handler for CardEffect kind %d" % effect.kind)


func _check_end() -> bool:
	if phase == Phase.ENDED:
		return true
	# Thorns can kill the last enemy on the same enemy action that kills the player; a dead
	# player has lost, so that is a defeat, never a victory.
	var victory := living_enemies().is_empty() and not player.is_dead()
	if not (victory or player.is_dead()):
		return false
	phase = Phase.ENDED
	# Block and statuses are per-fight; clear them so callers between fights do
	# not see them stale.
	player.clear_block()
	player.clear_statuses()
	state_changed.emit()
	combat_ended.emit(victory)
	_disconnect_player()
	return true
