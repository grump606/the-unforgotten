class_name Combat
extends RefCounted
## One fight between the player and 1 to MAX_ENEMIES enemies. Holds rules only:
## no nodes, no scenes. A UI observes the signals; a run layer supplies the
## player's Combatant and deck, and reads the outcome from `combat_ended`.

## DISCARDING is the end-of-turn step where the player picks cards to throw away (see begin_discard);
## it is appended last so the older phases keep their numeric values. CHOOSING is the pick step after a
## card with GLIMPSE or RECALL (see has_choice / resolve_choice); nothing else can happen until it resolves.
enum Phase { NOT_STARTED, PLAYER_TURN, ENEMY_TURN, ENDED, DISCARDING, CHOOSING }
## How the fight ended: NONE until it does, and still NONE after abandon() (an abandoned fight has no result).
enum Outcome { NONE, VICTORY, DEFEAT }

## Hand rules (easy to change here):
##  - HAND_SIZE: the most cards you may KEEP at end of turn, and the hand each turn starts back up
##    to (draw max(0, HAND_SIZE - kept)). Turn 1 therefore draws HAND_SIZE.
##  - HAND_MAX: the most cards the hand can hold during the turn. Draws (card DRAW effects, relics)
##    stop at the cap and the rest stay in the draw pile.
const HAND_SIZE := 5
const HAND_MAX := 10
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
## An enemy crossed an HP threshold and began phase 2 or 3 (`enemy.phase`; its next intent is already the new one).
signal enemy_phase_changed(enemy: EnemyUnit, phase: int)
signal combat_ended(victory: bool)

var player: Combatant
## Fixed order for the whole fight. Defeated enemies stay in the list so
## target indices remain stable; use `living_enemies()` to skip them.
var enemies: Array[EnemyUnit] = []
var piles: CardPiles
var energy: int = 0
var turn: int = 0
var phase: Phase = Phase.NOT_STARTED
var outcome: Outcome = Outcome.NONE
## Cards played so far this turn (see MAX_PLAYS_PER_TURN).
var plays_this_turn: int = 0
## Hand indices marked for discard while phase == DISCARDING (sorted, no duplicates).
var discard_marks: Array[int] = []
## The run's relics for this fight (see RelicData); empty changes nothing. Read-only from outside: the
## getter hands out a copy, and assigning the property replaces the list and rebuilds the per-kind totals,
## so the cached totals can never go stale. In-place edits of the returned copy do nothing.
var relics: Array[RelicData]:
	get:
		return _relics.duplicate()
	set(value):
		_relics = value.duplicate()
		_rebuild_totals()
var _relics: Array[RelicData] = []
# Relic amounts summed per kind (see _relic_total); rebuilt whenever the list is assigned.
var _totals: Dictionary = {}
# Once-per-fight relic triggers already spent (FIRST_FORGOTTEN_RETURN, FIRST_ATTACK_SHAKEN).
var _forgotten_return_used := false
## While a played card resolves: how many Oaths were Sworn before it, so the Oaths it swears do not
## react to what it does (a quarry its own play kills). -1 outside a play: every Sworn Oath may react.
var _play_oath_limit := -1
## Quarries a Scent-spending hit killed this play: they died holding Scent that was spent, so they count as a
## quarry's death (kill heal, QUARRY_DIES Oaths) but pass no Scent on. Drained by _pass_on_scent.
var _spent_quarries: Array[EnemyUnit] = []
var _first_attack_used := false
## The fight's seeded RNG (the same one the piles shuffle with); Scent uses it to pick an heir.
var _rng: RandomNumberGenerator

## The open pick step while phase == CHOOSING (see has_choice). Built when it opens, so a second
## GLIMPSE sees the draw pile as the first one left it.
class Choice extends RefCounted:
	## CardEffect.Kind.GLIMPSE or CardEffect.Kind.RECALL.
	var kind: CardEffect.Kind = CardEffect.Kind.GLIMPSE
	## What may be picked. GLIMPSE: the top cards of the draw pile in draw order (indices match
	## CardPiles.top_cards). RECALL: the whole Forgotten pile (indices match CardPiles.forgotten).
	var cards: Array[CardData] = []
	## Fewest picks that resolve it (0 for GLIMPSE; min(n, Forgotten size) for RECALL) and the most.
	var required := 0
	var max_picks := 0

# Choices queued by the card being played ({kind, amount} Dictionaries, in effect order). They open one
# after another once the whole card has resolved; `_choice` is the one currently open.
var _choice_queue: Array[Dictionary] = []
var _choice: Choice = null
# A null-card ADD_CARD logs once per fight, not once per play.
var _warned_null_card := false

## How many engine errors (Combat.engine_error) this process has logged. The sim tools exit 1 when it is not zero:
## an engine fault would otherwise only be a line in the log next to a quiet, wrong result.
static var engine_errors := 0


## The engine's own error sites (here, in StarterContent, RunState and Vendor) log through this: it is push_error
## plus a count the sim tools read.
static func engine_error(message: String) -> void:
	engine_errors += 1
	push_error(message)


# Duration statuses (EXPOSED, SHAKEN, FRAYED: Status -> turns) that enemy intents applied to the
# player this enemy phase. They are held back until the player's statuses have ticked, so they start
# counting from the next enemy phase instead of ticking away unused.
var _pending_player_statuses: Dictionary = {}

# The player outlives this fight, so the connection that forwards its changes to
# state_changed is removed when the fight ends; otherwise every finished fight
# would stay alive and keep re-emitting.
var _player_changed_link: Callable = state_changed.emit


## Builds a fight, or returns null (after logging why) if the enemy list is not
## 1 to MAX_ENEMIES long, holds a null entry, the deck is empty or the player is already dead. Use this when the inputs
## come from data that could be bad, such as resources that failed to load;
## `new()` only asserts, which release builds skip.
static func create(player_combatant: Combatant, deck: Array[CardData], enemy_datas: Array[EnemyData], rng_seed: int = 0, owned_relics: Array[RelicData] = []) -> Combat:
	if enemy_datas.size() < 1 or enemy_datas.size() > MAX_ENEMIES:
		Combat.engine_error("Combat.create: needs 1 to %d enemies, got %d" % [MAX_ENEMIES, enemy_datas.size()])
		return null
	if player_combatant.is_dead():
		Combat.engine_error("Combat.create: the player is already dead")
		return null
	if deck.is_empty():
		Combat.engine_error("Combat.create: the deck is empty")
		return null
	for enemy_data in enemy_datas:
		if enemy_data == null:
			Combat.engine_error("Combat.create: an enemy entry is null (its data failed to load)")
			return null
	return Combat.new(player_combatant, deck, enemy_datas, rng_seed, owned_relics)


func _init(player_combatant: Combatant, deck: Array[CardData], enemy_datas: Array[EnemyData], rng_seed: int = 0, owned_relics: Array[RelicData] = []) -> void:
	assert(enemy_datas.size() >= 1 and enemy_datas.size() <= MAX_ENEMIES, "Combat needs 1 to %d enemies" % MAX_ENEMIES)
	assert(not player_combatant.is_dead(), "Combat needs a living player")
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	player = player_combatant
	relics = owned_relics
	# The player outlives fights; statuses must not.
	player.clear_statuses()
	piles = CardPiles.new(deck, rng)
	_rng = rng
	for enemy_data in enemy_datas:
		var enemy := EnemyUnit.new(enemy_data)
		enemy.changed.connect(state_changed.emit)
		enemies.append(enemy)


func start() -> void:
	if phase != Phase.NOT_STARTED:
		# Checked explicitly (not assert) so a release build cannot resurrect an
		# ended or abandoned fight.
		Combat.engine_error("Combat.start: the fight was already started or has ended")
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
	_spent_quarries.clear()
	_clear_choices()
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
		and not piles.hand[hand_index].dormant
		and (piles.hand[hand_index].surge or piles.hand[hand_index].cost <= energy)
		# A card that costs HP cannot be the one that kills the player.
		# A Surge card's HP cost scales with the energy it would spend, as _apply multiplies LOSE_HP per_energy.
		and piles.hand[hand_index].hp_cost(surge_scale(piles.hand[hand_index])) < player.hp
		and plays_this_turn < MAX_PLAYS_PER_TURN
	)


## The per_energy multiplier `card` would get if played now: all the energy for a Surge card, else 1.
func surge_scale(card: CardData) -> int:
	return energy if card.surge else 1


## Energy playing `card` now spends: its cost, or everything there is for a Surge card.
func spent_energy(card: CardData) -> int:
	return energy if card.surge else card.cost


## How many hits damage `effect` of `card` would land if the card were played now (see CardEffect.hit_count).
func hit_count(card: CardData, effect: CardEffect) -> int:
	return effect.hit_count(surge_scale(card))


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
	# Only Oaths already Sworn react to this play, never the card being played.
	var sworn_before := piles.sworn.size()
	_play_oath_limit = sworn_before
	var block_before := player.block
	var card := piles.play(hand_index)
	# Surge spends all the energy there is; other cards spend their cost.
	var spent := spent_energy(card)
	var scale := surge_scale(card)
	energy -= spent
	plays_this_turn += 1
	_resolve_effects(card, targets, mode, scale)
	# Measured here, before any relic or Oath effect of this play, so only Block the card's OWN effects
	# gave counts for "When you gain Block from a card".
	var card_gave_block := player.block > block_before
	if not _relics.is_empty():
		_apply_play_relics(card, targets)
	_fire_play_oaths(card, scale, sworn_before, card_gave_block)
	card_played.emit(card, targets)
	_check_phases()
	_play_oath_limit = -1
	if not _check_end():
		# Queued Glimpse / Recall picks open only now, after everything else the card did.
		_open_next_choice()
		state_changed.emit()
	return true


## Applies a played card's effects in order. A SELF-reach effect lands on the player; Scent marks one quarry
## among the targets; any other effect lands on each target still alive (an earlier effect of this same card
## may have killed one, and later effects skip the corpse).
func _resolve_effects(card: CardData, targets: Array[EnemyUnit], mode: CardData.TargetMode, scale: int) -> void:
	for effect in card.effects:
		var reach := effect.reach()
		# SELF cards expose the player; other EXPOSE cards expose their targets.
		if reach == CardEffect.Reach.SELF or (reach == CardEffect.Reach.BOTH and mode == CardData.TargetMode.SELF):
			_apply(effect, player, player, scale)
		if effect.kind == CardEffect.Kind.SCENT:
			# One quarry: a card aimed at several enemies marks only one of them.
			var quarry := _scent_target(targets)
			if quarry != null:
				_apply(effect, player, quarry, scale)
		elif reach != CardEffect.Reach.SELF:
			for target in targets:
				if target.is_dead():
					continue
				_apply(effect, player, target, scale)


## The Oaths already Sworn (the first `sworn_before` of them) that react to the card just played.
## `card_gave_block` is true when the played card's own effects raised the player's Block; Block from a relic or
## from an Oath effect of the same play never triggers ON_BLOCK_GAINED (and so never chains into another Oath).
func _fire_play_oaths(card: CardData, scale: int, sworn_before: int, card_gave_block: bool) -> void:
	if plays_this_turn == 1:
		_fire_oaths(CardData.OathTrigger.FIRST_PLAY, sworn_before)
	_fire_oaths(CardData.OathTrigger.EACH_PLAY, sworn_before)
	if card_gave_block:
		_fire_oaths(CardData.OathTrigger.ON_BLOCK_GAINED, sworn_before)
	if card.hp_cost(scale) > 0:
		_fire_oaths(CardData.OathTrigger.ON_HP_LOST, sworn_before)
	if card.forgotten and not card.oath:
		_fire_oaths(CardData.OathTrigger.ON_FORGOTTEN, sworn_before)

func _clear_choices() -> void:
	_choice_queue.clear()
	_choice = null


## Opens the next queued choice that has something to pick (GLIMPSE needs a non-empty draw pile, RECALL
## a non-empty Forgotten pile; otherwise it is skipped) and enters Phase.CHOOSING. No-op if none.
func _open_next_choice() -> void:
	while not _choice_queue.is_empty():
		var entry: Dictionary = _choice_queue.pop_front()
		var choice := Choice.new()
		choice.kind = entry["kind"]
		var n: int = entry["amount"]
		if choice.kind == CardEffect.Kind.GLIMPSE:
			choice.cards = piles.top_cards(n)
			choice.required = 0
		else:
			choice.cards = piles.forgotten.duplicate()
			choice.required = mini(n, choice.cards.size())
		choice.max_picks = choice.cards.size() if choice.kind == CardEffect.Kind.GLIMPSE else choice.required
		if choice.cards.is_empty():
			continue
		_choice = choice
		phase = Phase.CHOOSING
		return


## True while a Glimpse or Recall pick is open (phase == CHOOSING).
func has_choice() -> bool:
	return _choice != null


## The cards on offer, in the order the indices of resolve_choice refer to (empty with no choice).
func choice_cards() -> Array[CardData]:
	return _choice.cards if _choice != null else []


## CardEffect.Kind.GLIMPSE (the picks are DISCARDED from the draw pile top) or CardEffect.Kind.RECALL
## (the picks are returned to hand). Meaningless with no choice open (returns GLIMPSE).
func choice_kind() -> CardEffect.Kind:
	return _choice.kind if _choice != null else CardEffect.Kind.GLIMPSE


## Fewest picks that resolve the choice: 0 for Glimpse, min(n, Forgotten size) for Recall.
func choice_required() -> int:
	return _choice.required if _choice != null else 0


## Most picks allowed: every card for Glimpse, the required number for Recall.
func choice_max() -> int:
	return _choice.max_picks if _choice != null else 0


## True if `indices` are unique, in range of choice_cards(), and between choice_required() and choice_max().
func can_resolve_choice(indices: Array[int]) -> bool:
	if _choice == null or phase != Phase.CHOOSING:
		return false
	if indices.size() < _choice.required or indices.size() > _choice.max_picks:
		return false
	var seen := {}
	for i in indices:
		if i < 0 or i >= _choice.cards.size() or seen.has(i):
			return false
		seen[i] = true
	return true


## Applies the picks and closes the choice: Glimpse discards the picked cards (in the order given) from
## the draw pile top; Recall moves the picked Forgotten cards to the hand (to discard if it is full).
## Then the next queued choice opens, or the phase returns to PLAYER_TURN. False, changing nothing, if
## can_resolve_choice(indices) is false.
func resolve_choice(indices: Array[int]) -> bool:
	if not can_resolve_choice(indices):
		return false
	if _choice.kind == CardEffect.Kind.GLIMPSE:
		piles.discard_from_draw_top(indices)
	else:
		piles.recall_from_forgotten(indices, HAND_MAX)
	_choice = null
	phase = Phase.PLAYER_TURN
	_open_next_choice()
	state_changed.emit()
	return true


## Headless / bot default: resolves the open choice with the least-effort legal picks (Glimpse discards
## nothing; Recall takes the first required Forgotten cards). Tools make smarter picks. False if no choice.
func auto_resolve_choice() -> bool:
	if _choice == null:
		return false
	var picks: Array[int] = []
	if _choice.kind == CardEffect.Kind.RECALL:
		for i in _choice.required:
			picks.append(i)
	return resolve_choice(picks)


## True if hand card `hand_index` may be discarded at end of turn: Anchor and Fading cards may not.
func can_discard_card(hand_index: int) -> bool:
	if hand_index < 0 or hand_index >= piles.hand.size():
		return false
	var card := piles.hand[hand_index]
	return not card.anchor and not card.fading


## True if `discard_indices` are valid, unique, discardable hand indices and no more than HAND_SIZE
## counted cards (not Anchor, not Fading) would stay in hand. Discarding more than required (or
## every discardable card) is allowed.
func is_valid_discard(discard_indices: Array[int]) -> bool:
	var seen := {}
	for i in discard_indices:
		if not can_discard_card(i) or seen.has(i):
			return false
		seen[i] = true
	return piles.counted_in_hand() - discard_indices.size() <= HAND_SIZE


## How many more cards must be marked before the discard can be confirmed (0 when it can).
func discard_required() -> int:
	return maxi(piles.counted_in_hand() - discard_marks.size() - HAND_SIZE, 0)


func can_confirm_discard() -> bool:
	return phase == Phase.DISCARDING and discard_required() == 0


## Enters the end-of-turn discard step (the player pressed End Turn). Nothing is marked yet.
## False, changing nothing, outside the player's turn.
func begin_discard() -> bool:
	if phase != Phase.PLAYER_TURN:
		return false
	phase = Phase.DISCARDING
	discard_marks.clear()
	state_changed.emit()
	return true


## Backs out of the discard step to the player's turn; hand and energy are unchanged.
func cancel_discard() -> bool:
	if phase != Phase.DISCARDING:
		return false
	phase = Phase.PLAYER_TURN
	discard_marks.clear()
	state_changed.emit()
	return true


## Marks or unmarks hand card `hand_index` for discard. False (nothing changes) outside the
## discard step, for a bad index, or for an Anchor or Fading card (see can_discard_card).
func toggle_discard(hand_index: int) -> bool:
	if phase != Phase.DISCARDING or not can_discard_card(hand_index):
		return false
	var at := discard_marks.find(hand_index)
	if at >= 0:
		discard_marks.remove_at(at)
	else:
		discard_marks.append(hand_index)
		discard_marks.sort()
	state_changed.emit()
	return true


## Ends the discard step with the marked cards. False (nothing changes) while too many would stay.
func confirm_discard() -> bool:
	if not can_confirm_discard():
		return false
	return end_player_turn(discard_marks.duplicate())


## Ends the player's turn: discards the hand cards at `discard_indices` (the rest stay in hand) and
## runs the enemy phase. Works from the player's turn or the discard step. Returns false, changing
## nothing, if the phase is wrong or the discard is invalid (see is_valid_discard). With no argument
## nothing is discarded, which is only valid for a hand of HAND_SIZE or fewer.
func end_player_turn(discard_indices: Array[int] = []) -> bool:
	if phase != Phase.PLAYER_TURN and phase != Phase.DISCARDING:
		return false
	if not is_valid_discard(discard_indices):
		return false
	phase = Phase.ENEMY_TURN
	discard_marks.clear()
	_throw_away(discard_indices)
	_end_of_turn_effects()
	# Haunt hurts first, so an enemy it kills never acts.
	for enemy in enemies:
		if not enemy.is_dead():
			enemy.lose_hp(enemy.status_turns(Combatant.Status.HAUNTED))
	_check_phases()
	if _check_end():
		return true
	if _run_enemy_actions():
		return true
	_close_enemy_phase()
	return true


## Thrown-away cards: each one's own "when discarded" effects, then the Oaths that watch discards.
func _throw_away(discard_indices: Array[int]) -> void:
	var thrown: Array[CardData] = []
	for i in discard_indices:
		thrown.append(piles.hand[i])
	piles.discard_cards(discard_indices)
	for card in thrown:
		for effect in card.discard_effects:
			_apply_lasting(effect)
		_fire_oaths(CardData.OathTrigger.ON_DISCARD)


## What happens between the discard and the enemy phase: Fading cards are lost, kept Anchors shield the
## player, and the Oaths that watch the end of the turn fire.
func _end_of_turn_effects() -> void:
	# Fading cards that were not played are lost before the enemies act; each one is a Forgotten card for
	# the Oaths that care. A Glimpse or Recall from here opens at the start of the next turn.
	var faded := piles.forget_fading_in_hand()
	for _faded in faded:
		_fire_oaths(CardData.OathTrigger.ON_FORGOTTEN)
	# Kept Anchor cards shield the player through the enemy phase.
	var anchor_block := _relic_total(RelicData.Kind.ANCHOR_END_BLOCK)
	if anchor_block > 0:
		var anchored := 0
		for held in piles.hand:
			if held.anchor:
				anchored += 1
		if anchored > 0:
			player.gain_block(anchor_block * anchored)
	for held in piles.hand:
		if held.anchor:
			_fire_oaths(CardData.OathTrigger.ANCHOR_KEPT)
	# Last, so Block it gives is not spent before the enemies act.
	_fire_oaths(CardData.OathTrigger.END_OF_TURN)


## Each living enemy acts in order. True if the fight ended during the phase.
func _run_enemy_actions() -> bool:
	for enemy in living_enemies():
		enemy.clear_block()
		# Temporary stacks last until the owner's next turn, which for an enemy is its next action.
		enemy.clear_temp_stacks()
		var intent := enemy.current_intent()
		if intent != null:
			_apply(intent, enemy, player)
			enemy_acted.emit(enemy, intent)
		enemy.advance_intent()
		enemy.tick_statuses()
		_check_phases()
		if _check_end():
			return true
	return false


## After the enemies act: the player's statuses tick, held-back statuses land, and the next turn begins.
func _close_enemy_phase() -> void:
	# After the enemies act, so a 1-turn status on the player still covers the
	# enemy phase that follows the turn it was applied in.
	player.tick_statuses()
	# Enemy-applied EXPOSE, SHAKEN and FRAYED land after the tick: amount N covers the next N
	# enemy phases (not the one that applied it, so even later enemies in that phase hit normally).
	for status in _pending_player_statuses:
		player.apply_status(status, _pending_player_statuses[status])
	_pending_player_statuses.clear()
	_begin_player_turn()


## How many living enemies are Haunted. The engine and the bot policies share this one rule.
func haunted_count() -> int:
	var count := 0
	for enemy in enemies:
		if not enemy.is_dead() and enemy.status_turns(Combatant.Status.HAUNTED) > 0:
			count += 1
	return count


func _resolve_target(target_index: int) -> EnemyUnit:
	if target_index == -1:
		return _first_living()
	if target_index < 0 or target_index >= enemies.size() or enemies[target_index].is_dead():
		return null
	# A card aimed at an Unseen enemy lands on the first enemy that can be targeted instead.
	if is_shielded(enemies[target_index]):
		return _first_living()
	return enemies[target_index]


## True for a living Unseen enemy while another enemy that is not Unseen is alive: it cannot be targeted
## (see EnemyData.unseen). False for every other enemy, and for an Unseen one once no other kind is left.
func is_shielded(enemy: EnemyUnit) -> bool:
	if enemy == null or enemy.is_dead() or enemy.data == null or not enemy.data.unseen:
		return false
	for other in enemies:
		if not other.is_dead() and not (other.data != null and other.data.unseen):
			return true
	return false


## The first enemy still alive that can be targeted, or null.
func _first_living() -> EnemyUnit:
	for enemy in enemies:
		if not enemy.is_dead() and not is_shielded(enemy):
			return enemy
	return null


func _begin_player_turn() -> void:
	turn += 1
	phase = Phase.PLAYER_TURN
	energy = ENERGY_PER_TURN
	plays_this_turn = 0
	player.start_turn_block()
	player.clear_temp_stacks()
	_apply_turn_start_relics()
	# Ready cards join the opening hand first.
	if turn == 1:
		piles.draw_ready(HAND_MAX)
	# Kept cards count toward the starting hand: draw back up to HAND_SIZE (nothing if 5 were kept).
	# Anchor and Fading cards in hand do not count, so they do not shrink the refill.
	piles.draw(maxi(HAND_SIZE - piles.counted_in_hand(), 0), HAND_MAX)
	# The fight-start Glimpse looks at the draw pile after the opening hand is dealt.
	if turn == 1 and _relic_total(RelicData.Kind.FIGHT_START_GLIMPSE) > 0:
		_choice_queue.append({"kind": CardEffect.Kind.GLIMPSE, "amount": _relic_total(RelicData.Kind.FIGHT_START_GLIMPSE)})
	# Sworn Oaths act once the hand is dealt. An Oath that costs HP can end the fight here.
	_fire_oaths(CardData.OathTrigger.TURN_START)
	_check_phases()
	if _check_end():
		return
	_open_next_choice()
	state_changed.emit()


## Fires every Sworn Oath whose trigger is `trigger`: each of its oath_effects once. Only the first `limit`
## Sworn cards are considered when `limit` >= 0 (so a card being played does not trigger itself). An effect
## whose reach is SELF lands on the player; any other lands on every enemy still alive when it resolves.
func _fire_oaths(trigger: CardData.OathTrigger, limit: int = -1) -> void:
	var count := piles.sworn.size() if limit < 0 else mini(limit, piles.sworn.size())
	for i in count:
		var oath: CardData = piles.sworn[i]
		if oath.oath_trigger != trigger:
			continue
		for effect in oath.oath_effects:
			_apply_lasting(effect)


## Applies one effect of an Oath or of a discarded card: Scent to the quarry (the current one, else the first
## living enemy), a SELF-reach effect to the player, any other to every enemy still alive.
func _apply_lasting(effect: CardEffect) -> void:
	if effect.kind == CardEffect.Kind.SCENT:
		var quarry := _scent_target(enemies)
		if quarry != null:
			_apply(effect, player, quarry)
	elif effect.reach() == CardEffect.Reach.SELF:
		_apply(effect, player, player)
	else:
		for enemy in enemies:
			# Dead before the effect lands (an enemy only dies from its own damage, never another's).
			if not enemy.is_dead():
				_apply(effect, player, enemy)


## Sum of `amount` over the owned relics of `kind` (0 with none).
func _relic_total(kind: RelicData.Kind) -> int:
	return _totals.get(kind, 0)


func _rebuild_totals() -> void:
	_totals.clear()
	for relic in _relics:
		_totals[relic.kind] = _totals.get(relic.kind, 0) + relic.amount


## Relic effects that fire after a card's own effects: the first play of a turn draws, every
## PLAYS_BLOCK_EVERY-th play gains Block. plays_this_turn already counts the card just played.
func _apply_play_relics(card: CardData, targets: Array[EnemyUnit]) -> void:
	if plays_this_turn == 1 and _relic_total(RelicData.Kind.FIRST_PLAY_DRAW) > 0:
		piles.draw(_relic_total(RelicData.Kind.FIRST_PLAY_DRAW), HAND_MAX)
	if plays_this_turn % RelicData.PLAYS_BLOCK_EVERY == 0 and _relic_total(RelicData.Kind.PLAYS_BLOCK) > 0:
		player.gain_block(_relic_total(RelicData.Kind.PLAYS_BLOCK))
	# The first Forgotten card played this fight comes straight back from the Forgotten pile.
	# Only a card that really landed in the pile counts: an Oath goes to the Sworn list instead.
	if piles.last_play_destination == CardPiles.Destination.FORGOTTEN and not piles.forgotten.is_empty() \
			and not _forgotten_return_used and _relic_total(RelicData.Kind.FIRST_FORGOTTEN_RETURN) > 0:
		_forgotten_return_used = true
		var last: Array[int] = [piles.forgotten.size() - 1]
		piles.recall_from_forgotten(last, HAND_MAX)
	# The first attack (a card that deals damage) this fight Shakes the enemies it was played on.
	if not _first_attack_used and _relic_total(RelicData.Kind.FIRST_ATTACK_SHAKEN) > 0:
		for effect in card.effects:
			if effect.is_damage():
				_first_attack_used = true
				for target in targets:
					target.apply_status(Combatant.Status.SHAKEN, _relic_total(RelicData.Kind.FIRST_ATTACK_SHAKEN))
				break


## Relic effects that fire as a turn begins. Runs after start_turn_block(), which resets Block
## to Hold and Thorns to 0, so these grants are not wiped. Fight-start effects come first on turn 1
## so that a starting Haunt already counts for the turn-start heal.
func _apply_turn_start_relics() -> void:
	if _relics.is_empty():
		return
	var block := _relic_total(RelicData.Kind.TURN_START_BLOCK)
	if turn == 1:
		for enemy in enemies:
			enemy.apply_status(Combatant.Status.HAUNTED, _relic_total(RelicData.Kind.FIGHT_START_HAUNT))
		block += _relic_total(RelicData.Kind.FIGHT_START_BLOCK)
		energy += _relic_total(RelicData.Kind.FIRST_TURN_ENERGY)
		# Malice and Ward from relics last the whole fight (cleared with the statuses at fight end).
		var malice := _relic_total(RelicData.Kind.FIGHT_START_MALICE)
		if malice > 0:
			player.apply_status(Combatant.Status.MALICE, malice)
		# The first living enemy becomes the quarry from the first turn.
		var scent := _relic_total(RelicData.Kind.FIGHT_START_SCENT)
		if scent > 0 and _first_living() != null:
			_give_scent(_first_living(), scent)
		var ward := _relic_total(RelicData.Kind.FIGHT_START_WARD)
		if ward > 0:
			player.apply_status(Combatant.Status.WARD, ward)
	if block > 0:
		player.gain_block(block)
	var thorns := _relic_total(RelicData.Kind.TURN_START_THORNS)
	if thorns > 0:
		player.add_thorns(thorns)
	var heal := _relic_total(RelicData.Kind.TURN_START_HEAL_PER_HAUNTED) * haunted_count()
	if heal > 0:
		player.heal(heal)


## `target` receives damage and statuses; `source` receives block and draws.
## An enemy intent with EXPOSE, SHAKEN or FRAYED affects the player; see `_pending_player_statuses`
## for when it takes effect. MALICE and WARD go to `source` when positive and `target` when negative.
## `energy_scale` is the energy a Surge card spent (1 otherwise); it multiplies per_energy effects.
func _apply(effect: CardEffect, source: Combatant, target: Combatant, energy_scale: int = 1) -> void:
	if effect.is_damage():
		_apply_damage(effect, source, target, energy_scale)
		return
	var amount := effect.scaled_amount(energy_scale)
	match effect.kind:
		CardEffect.Kind.HOLD:
			source.add_hold(amount)
		CardEffect.Kind.THORNS:
			source.add_thorns(amount)
		CardEffect.Kind.GAIN_ENERGY:
			if source == player:
				energy += maxi(amount, 0)
		CardEffect.Kind.LOSE_HP:
			source.lose_hp(amount)
		CardEffect.Kind.HEAL_PER_HAUNTED:
			source.heal(amount * haunted_count())
		CardEffect.Kind.BLOCK:
			source.gain_block(source.block_from_card(amount))
		CardEffect.Kind.SCENT, CardEffect.Kind.HAUNT, CardEffect.Kind.EXPOSE, CardEffect.Kind.SHAKEN, \
		CardEffect.Kind.FRAYED, CardEffect.Kind.MALICE, CardEffect.Kind.WARD:
			_apply_status_effect(effect, source, target, amount)
		CardEffect.Kind.DRAW, CardEffect.Kind.GLIMPSE, CardEffect.Kind.RECALL, CardEffect.Kind.ADD_CARD, CardEffect.Kind.FILE:
			_apply_pile_effect(effect, source, amount)
		_:
			Combat.engine_error("Combat._apply: no handler for CardEffect kind %d" % effect.kind)


## Damage family: every hit goes through hit_amount (the shared pipeline), then Block and HP. The hit
## amount is the same for every hit of one effect, so it is worked out once.
func _apply_damage(effect: CardEffect, source: Combatant, target: Combatant, energy_scale: int) -> void:
	# plays_this_turn already counts the card being played.
	var dealt := hit_amount(effect, source, target, plays_this_turn)
	for _hit in effect.hit_count(energy_scale):
		# An attacker killed part-way (by Thorns) stops there: a dead enemy must not finish its attack.
		if source.is_dead():
			break
		target.take_damage_final(dealt)
		# Thorns: an enemy attack on the player also hurts the attacker, once per hit.
		if effect.kind == CardEffect.Kind.DAMAGE and target == player and source != player and player.thorns > 0:
			source.take_damage(player.thorns)
	# A spender uses up the Scent it hit with, after every hit of the effect. If it killed a quarry that held
	# Scent, the death is remembered (the Scent itself is gone: there is nothing to pass on).
	if effect.kind == CardEffect.Kind.DAMAGE_PER_SCENT:
		var quarry := target as EnemyUnit
		if quarry != null and quarry.is_dead() and quarry.stacks(Combatant.Status.SCENT) > 0:
			_spent_quarries.append(quarry)
		target.remove_status(Combatant.Status.SCENT)


## Status family. `target` receives statuses; `source` receives Malice and Ward when positive (target when
## negative). An enemy intent with EXPOSE, SHAKEN or FRAYED affects the player, held back until the player's
## statuses have ticked (see _pending_player_statuses).
func _apply_status_effect(effect: CardEffect, source: Combatant, target: Combatant, amount: int) -> void:
	match effect.kind:
		CardEffect.Kind.SCENT:
			# Only the player's cards mark a quarry; an enemy intent with SCENT does nothing.
			if source == player and target != player:
				_give_scent(target, amount)
		CardEffect.Kind.HAUNT:
			if source == player:
				# The Haunt bonus only boosts a Haunt that was going to be applied at all.
				target.apply_status(Combatant.Status.HAUNTED, amount + (_relic_total(RelicData.Kind.HAUNT_BONUS) if amount > 0 else 0))
		CardEffect.Kind.EXPOSE, CardEffect.Kind.SHAKEN, CardEffect.Kind.FRAYED:
			var status := _duration_status(effect.kind)
			if source == player:
				target.apply_status(status, amount)
			elif target == player:
				_pending_player_statuses[status] = _pending_player_statuses.get(status, 0) + maxi(amount, 0)
		CardEffect.Kind.MALICE, CardEffect.Kind.WARD:
			var stack_status := Combatant.Status.MALICE if effect.kind == CardEffect.Kind.MALICE else Combatant.Status.WARD
			var recipient := source if amount > 0 else target
			if effect.temporary:
				recipient.apply_temp_stack(stack_status, amount)
			else:
				recipient.apply_status(stack_status, amount)


## Pile family: draws, the Glimpse / Recall picks and cards added to the player's piles.
func _apply_pile_effect(effect: CardEffect, source: Combatant, amount: int) -> void:
	match effect.kind:
		CardEffect.Kind.DRAW:
			# Only the player has a hand.
			if source == player:
				piles.draw(amount, HAND_MAX)
		CardEffect.Kind.GLIMPSE, CardEffect.Kind.RECALL:
			# Only the player has piles to pick from; the pick opens after the card resolves.
			if source == player and amount > 0:
				_choice_queue.append({"kind": effect.kind, "amount": amount})
		CardEffect.Kind.FILE:
			# Acts on the player's hand whoever it comes from: an enemy intent files the cards you kept.
			piles.file_from_hand(amount)
		CardEffect.Kind.ADD_CARD:
			# A card's copies and an enemy intent's both land in the player's piles.
			if effect.card == null:
				if not _warned_null_card:
					_warned_null_card = true
					Combat.engine_error("Combat._apply: ADD_CARD effect has no card")
			else:
				for _copy in maxi(amount, 0):
					piles.add_card(effect.card, effect.pile, HAND_MAX)


## One hit of damage `effect` from `source` onto `target` after the whole pipeline and before Block: the
## raw damage (reading Block, Haunt, plays, the Forgotten pile and Scent), the source's Malice and Shaken,
## the target's Scent and Expose. `plays_including_this` counts the card being played (a bot pricing a card
## not yet played passes plays_this_turn + 1). The engine's _apply and every preview use this one rule.
func hit_amount(effect: CardEffect, source: Combatant, target: Combatant, plays_including_this: int) -> int:
	return Combatant.hit_damage(effect.raw_damage(damage_context(source, target, plays_including_this)), source, target)


## What `hits` hits (default: the effect's own `hits`; a Surge card's per_energy scaling is the caller's to
## pass) of damage `effect` would do to `target`, without changing anything: {damage, absorbed, through,
## lost, block_left}. `damage` is the total after Malice/Shaken/Expose, `absorbed` what Block took,
## `through` the rest (not capped by HP), `lost` the HP the target would really lose (capped), and
## `block_left` its Block afterwards. `block` overrides the target's current Block (pass the previous
## effect's block_left to chain several effects of one card); -1 uses the target's own.
func preview_hit(effect: CardEffect, source: Combatant, target: Combatant, plays_including_this: int, hits: int = -1, block: int = -1) -> Dictionary:
	var raw := effect.raw_damage(damage_context(source, target, plays_including_this))
	return Combatant.hits_outcome(source, target, raw, maxi(effect.hits, 1) if hits < 0 else hits, block)


## The fight numbers a damage effect from `source` onto `target` reads (see CardEffect.raw_damage).
## `plays_including_this` counts the card being played; a bot pricing a card not yet played passes
## plays_this_turn + 1. The engine and the bot policies share this one rule.
func damage_context(source: Combatant, target: Combatant, plays_including_this: int) -> EffectContext:
	return EffectContext.make(source.block, target.status_turns(Combatant.Status.HAUNTED), plays_including_this, piles.forgotten.size(), target.stacks(Combatant.Status.SCENT))


## Damage `enemy`'s next intent deals the player (all its hits, before Block), 0 for a non-damage intent.
func intent_hit(enemy: EnemyUnit) -> int:
	var intent := enemy.current_intent()
	if intent == null or intent.kind != CardEffect.Kind.DAMAGE:
		return 0
	return Combatant.hit_damage(intent.amount, enemy, player) * maxi(intent.hits, 1)


## HP-before-Block the player would take from the living enemies' next intents, through the shared
## damage pipeline (enemy Malice and Shaken, then the player's Expose).
func incoming_damage() -> int:
	var total := 0
	for enemy in enemies:
		if not enemy.is_dead():
			total += intent_hit(enemy)
	return total


func _duration_status(kind: CardEffect.Kind) -> Combatant.Status:
	match kind:
		CardEffect.Kind.SHAKEN:
			return Combatant.Status.SHAKEN
		CardEffect.Kind.FRAYED:
			return Combatant.Status.FRAYED
	return Combatant.Status.EXPOSED


func _check_end() -> bool:
	if phase == Phase.ENDED:
		return true
	# Thorns can kill the last enemy on the same enemy action that kills the player; a dead
	# player has lost, so that is a defeat, never a victory.
	var victory := _first_living() == null and not player.is_dead()
	if not (victory or player.is_dead()):
		return false
	phase = Phase.ENDED
	outcome = Outcome.VICTORY if victory else Outcome.DEFEAT
	_clear_choices()
	# Block and statuses are per-fight; clear them so callers between fights do
	# not see them stale.
	player.clear_block()
	player.clear_statuses()
	state_changed.emit()
	combat_ended.emit(victory)
	_disconnect_player()
	return true


## The enemy among `candidates` (living ones only) that a Scent effect marks: the one already holding Scent
## if it is there, else the first. Null when none is alive.
func _scent_target(candidates: Array[EnemyUnit]) -> EnemyUnit:
	var first: EnemyUnit = null
	for enemy in candidates:
		if enemy.is_dead():
			continue
		if holds_scent(enemy):
			return enemy
		if first == null:
			first = enemy
	return first


## True for a living enemy holding Scent: the one rule for "this is the quarry".
static func holds_scent(enemy: EnemyUnit) -> bool:
	return not enemy.is_dead() and enemy.stacks(Combatant.Status.SCENT) > 0


## Index into `enemies` of the living enemy holding Scent, or -1 if none does.
func scent_holder_index() -> int:
	for i in enemies.size():
		if holds_scent(enemies[i]):
			return i
	return -1


## Makes `quarry` the one enemy holding Scent: any Scent held by a LIVING enemy elsewhere moves to it,
## `amount` is added, and the total is capped (Combatant.SCENT_CAP). A non-positive amount with nothing to
## move changes nothing. A DEAD holder's stack is deliberately left alone: it belongs to _pass_on_scent
## (half the stack, the quarry-kill heal and the QUARRY_DIES Oaths), which runs after the card, so a card
## that kills the quarry and then marks another enemy cannot absorb the whole dead stack.
func _give_scent(quarry: EnemyUnit, amount: int) -> void:
	var total := quarry.stacks(Combatant.Status.SCENT) + maxi(amount, 0)
	for enemy in enemies:
		if enemy != quarry and not enemy.is_dead() and enemy.stacks(Combatant.Status.SCENT) > 0:
			total += enemy.stacks(Combatant.Status.SCENT)
			enemy.remove_status(Combatant.Status.SCENT)
	quarry.remove_status(Combatant.Status.SCENT)
	quarry.apply_status(Combatant.Status.SCENT, total)


## When the quarry has died, half its Scent (rounded down) passes to a random living enemy (the fight's
## seeded RNG; no draw is made when only one is left). With nobody left, or a stack of 1, it is lost.
func _pass_on_scent() -> void:
	for enemy in enemies:
		if not enemy.is_dead() or enemy.stacks(Combatant.Status.SCENT) <= 0:
			continue
		var held := enemy.stacks(Combatant.Status.SCENT)
		var carried := held / 2
		if carried > 0 or _relic_total(RelicData.Kind.SCENT_HEIR) > 0:
			carried = mini(held, carried + _relic_total(RelicData.Kind.SCENT_HEIR))
		enemy.remove_status(Combatant.Status.SCENT)
		_quarry_died(carried)
	# A quarry killed by a Scent spender: the same death effects, with nothing to pass on.
	var spent := _spent_quarries.size()
	_spent_quarries.clear()
	for _i in spent:
		_quarry_died(0)


## The quarry has died: the kill heal, then `carried` Scent to a random living enemy (the fight's seeded RNG;
## no draw when only one is left; lost with nobody left), then the QUARRY_DIES Oaths while any enemy lives.
func _quarry_died(carried: int) -> void:
	player.heal(_relic_total(RelicData.Kind.QUARRY_KILL_HEAL))
	var living := living_enemies()
	if carried > 0 and not living.is_empty():
		var heir := living[0] if living.size() == 1 else living[_rng.randi_range(0, living.size() - 1)]
		_give_scent(heir, carried)
	if not living.is_empty():
		_fire_oaths(CardData.OathTrigger.QUARRY_DIES, _play_oath_limit)


## Moves any enemy that has just crossed its phase threshold into phase two and announces it. Also passes
## a dead quarry's Scent on: every way an enemy can die is followed by this check.
func _check_phases() -> void:
	_pass_on_scent()
	for enemy in enemies:
		# A hit that crosses two thresholds announces each phase in turn.
		while not enemy.is_dead() and enemy.check_phase():
			enemy_phase_changed.emit(enemy, enemy.phase)
