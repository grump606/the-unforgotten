class_name RunState
extends RefCounted
## One escape attempt: a fixed line of stops the player passes through, carrying
## HP and the deck from stop to stop. Pure logic with no nodes, so the run screen
## is only a view over it. Combat itself is untouched: a combat stop just builds
## a Combat from this state (see docs/RUN_INTEGRATION.md).
##
## New stop kinds (vendor, cutscene) become new StopType values plus one branch
## in the screen; the stop line and the persistent player/deck stay as they are.

enum StopType { COMBAT, REST, STORY, VENDOR }

const REWARD_CHOICES := 3
## How many of a reward's choices come from the character's own cards (the rest are neutral).
const REWARD_CLASS_CHOICES := 2
## A reward never offers a card the deck already holds this many times.
const COPY_CAP := 2
## Gold paid for skipping a card reward.
const SKIP_GOLD := 10
## HP restored by the reward screen's Heal alternative (never past max HP).
const REWARD_HEAL := 12
## Extra gold for beating the mid-boss, on top of Vendor.gold_for_win.
const MID_BOSS_GOLD_BONUS := 15

## One stop on the line. `enemy_count` only matters for COMBAT stops and
## `beat_index` (into StoryContent) only for STORY stops. A COMBAT stop with
## `boss` set fights StarterContent.boss_encounter() instead of a random pack,
## and winning it ends the run with no gold and no card reward. A COMBAT stop with `mid_boss` set
## fights StarterContent.mid_boss_encounter(); winning it pays gold and offers a card reward like a
## regular fight, and the run goes on.
## `tier` is the 0-based act (0 up to the mid-boss, 1 after it) and `fight` the 0-based number of a
## regular COMBAT stop among the regular fights; both are set by RunState._default_line and
## drive the encounter pools and stat ramp (see StarterContent.varied_encounter).
class Stop:
	var type: StopType
	var enemy_count: int
	var beat_index: int
	var boss: bool
	var mid_boss: bool
	var tier: int
	var fight: int
	## Presentation, set with place(): the destination's name, the painted battle backdrop used there ("" for the
	## default art) and the ambience that plays there ("" for none). Carried on the stop so reordering the line
	## cannot misassign art; the save stores only the stop index.
	var label: String = ""
	var backdrop: StringName = &""
	var ambience: StringName = &""

	func _init(stop_type: StopType, count: int = 0, beat: int = 0, is_boss: bool = false, is_mid_boss: bool = false) -> void:
		type = stop_type
		enemy_count = count
		beat_index = beat
		boss = is_boss
		mid_boss = is_mid_boss
		tier = 0
		fight = 0

	## Sets the presentation fields and returns this stop (for chaining in the line definition).
	func place(destination: String, backdrop_key: StringName = &"", ambience_key: StringName = &"") -> Stop:
		label = destination
		backdrop = backdrop_key
		ambience = ambience_key
		return self

	func describe() -> String:
		match type:
			StopType.COMBAT:
				if boss:
					return "Boss"
				if mid_boss:
					return "Mid-boss"
				return "Combat (%d enem%s)" % [enemy_count, "y" if enemy_count == 1 else "ies"]
			StopType.REST:
				return "Rest"
			StopType.STORY:
				return "Story"
			StopType.VENDOR:
				return "Vendor"
		return "?"

## Who is playing: sets the starting HP and deck and which cards the run can offer.
var character: Character
var player: Combatant
var deck: Array[CardData]
var stops: Array[Stop] = []
var stop_index: int = 0
## Debug launch (run/debug_launch.gd): when non-empty, the next fight uses these enemy ids instead of the stop's encounter.
var debug_encounter: Array[StringName] = []
## Resolves a debug_encounter id that is not shipped content (enemy_by_id returned null) to an EnemyData, or
## null. Injected by the launcher (run.gd sets it to DebugLaunch.prototype_enemy) so this rules class does not
## depend on debug code. Empty by default: unknown ids are then skipped.
var debug_enemy_resolver: Callable = Callable()
## True once the line is finished, by reaching the end or by losing a fight.
var finished: bool = false
## Only meaningful when `finished`: true if the player reached the last stop alive.
var escaped: bool = false
## Earned by winning fights (Vendor.gold_for_win), spent at VENDOR stops. Stored in `_wallet`,
## which the visit's Vendor spends from directly, so this is always current.
var gold: int:
	get:
		return _wallet.gold
	set(value):
		_wallet.gold = maxi(value, 0)
var _wallet := Vendor.Wallet.new()
## Ids of every card shown at a card reward so far this run; later rewards avoid them
## (see _roll_rewards). Saved with the run.
var offered_ids: Array[StringName] = []
## The reward screen's free Remove and Heal alternatives: each may be used once per run.
## Saved with the run.
var reward_remove_used := false
var reward_heal_used := false
## Relics bought from vendors this run, in purchase order. Saved with the run (as ids).
var relics: Array[RelicData] = []

var _vendor: Vendor = null
var _active_combat: Combat = null
var _rng := RandomNumberGenerator.new()
var _reward_choices: Array[CardData] = []
var _reward_pending: bool = false


func _init(rng_seed: int = 0, character_id: StringName = StarterContent.DEFAULT_CHARACTER_ID) -> void:
	_rng.seed = rng_seed
	character = StarterContent.character(character_id)
	if character == null:
		# The cause is logged; an empty character keeps the run constructible, and its first
		# fight then fails cleanly because Combat rejects an empty deck.
		character = Character.new()
	player = Combatant.new(character.display_name, character.max_hp)
	if character.id != &"":
		deck.assign(StarterContent.starter_deck(character.id))
	stops = _default_line()


## The stop the player is at, or null once the run is finished.
func current_stop() -> Stop:
	return null if finished else stops[stop_index]


func reward_pending() -> bool:
	return _reward_pending


## True between stops: nothing is in flight (no fight, reward or vendor visit), so
## the run can be saved and restored exactly (see run/run_save.gd).
func at_stop_boundary() -> bool:
	return not finished and not _reward_pending and _vendor == null and _active_combat == null


## The run RNG's position, for saving. Restoring it makes the future identical.
func rng_state() -> int:
	return _rng.state


func restore_rng_state(state: int) -> void:
	_rng.state = state


## Builds the fight for the current COMBAT stop, or null (after logging why) if
## this is not a combat stop or the content failed to load. Asking again at the
## same stop abandons the previous fight (releasing its link to the player) and
## builds a new one, which re-rolls the encounter.
func start_combat() -> Combat:
	var stop := current_stop()
	if stop == null or stop.type != StopType.COMBAT or _reward_pending:
		push_error("RunState.start_combat: not at a fresh combat stop")
		return null
	if _active_combat != null:
		_active_combat.abandon()
		_active_combat = null
	var enemies: Array[EnemyData]
	if not debug_encounter.is_empty():
		for enemy_id in debug_encounter:
			var enemy := StarterContent.enemy_by_id(enemy_id)
			if enemy == null and debug_enemy_resolver.is_valid():
				enemy = debug_enemy_resolver.call(enemy_id)
			if enemy != null:
				enemies.append(enemy)
	elif stop.boss:
		enemies = StarterContent.boss_encounter()
	elif stop.mid_boss:
		enemies = StarterContent.mid_boss_encounter()
	else:
		enemies = StarterContent.varied_encounter(stop.enemy_count, _rng, stop.tier, stop.fight)
	_active_combat = Combat.create(player, deck, enemies, _rng.randi(), relics)
	return _active_combat


## "Boss" for the final boss fight, "Mid-boss" for the mid-boss, "" for a regular fight. A debug
## encounter is judged by its enemies, so launching the Eraser gets the boss look anywhere.
func boss_label() -> String:
	if not debug_encounter.is_empty():
		if debug_encounter.has(&"the_conductor"):
			return "Boss"
		return "Mid-boss" if debug_encounter.has(&"the_brakeman") else ""
	var stop := current_stop()
	if stop == null:
		return ""
	if stop.boss:
		return "Boss"
	return "Mid-boss" if stop.mid_boss else ""


## Records how the current fight ended. A defeat ends the run; a victory pays
## gold and offers a reward that must be taken or skipped before the line moves
## on. Beating the boss stop is the exception: it pays nothing (no later stop could
## spend it), offers no reward and ends the run as an escape. Only valid at a COMBAT stop that has no reward pending and is not finished
## (anything else is a caller bug: it is logged and changes nothing).
## When the run built the fight (start_combat) and it ended on its own (Combat.outcome), that outcome decides
## the result: a disagreeing `victory` is logged and the fight's outcome wins. A fight with no outcome (still
## in progress, or abandoned) is abandoned if need be and the caller's `victory` decides (the sims record a
## turn-cap stall as a defeat; UI tests use it as a shortcut). With no fight started (tests, debug paths) the
## caller's `victory` is taken as given.
func complete_combat(victory: bool) -> void:
	var stop := current_stop()
	if finished or _reward_pending or stop == null or stop.type != StopType.COMBAT:
		push_error("RunState.complete_combat: not at a combat stop awaiting a result")
		return
	if _active_combat != null:
		_active_combat.abandon() # no-op once ended; releases the player from a fight cut short
		if _active_combat.outcome != Combat.Outcome.NONE:
			var actual := _active_combat.outcome == Combat.Outcome.VICTORY
			if actual != victory:
				push_error("RunState.complete_combat: the caller reported %s but the fight ended in %s" % ["a victory" if victory else "a defeat", "a victory" if actual else "a defeat"])
				victory = actual
	_active_combat = null
	if not victory:
		finished = true
		escaped = false
		return
	if stop.boss:
		# The boss ends the line: no gold (nothing left to spend it on), no card to pick.
		_advance()
		return
	gold += Vendor.gold_for_win(stop.enemy_count) + (MID_BOSS_GOLD_BONUS if stop.mid_boss else 0)
	for relic in relics:
		match relic.kind:
			RelicData.Kind.WIN_GOLD:
				gold += relic.amount
			RelicData.Kind.WIN_HEAL:
				player.heal(relic.amount)
	_roll_rewards()
	_reward_pending = true


## Up to REWARD_CHOICES distinct cards to pick from, stable until the reward is
## taken or skipped. Rolled when the fight is won, so a seed plays out the same
## whether or not the reward screen is shown. Returns a copy.
func reward_choices() -> Array[CardData]:
	var copy: Array[CardData] = []
	copy.assign(_reward_choices)
	return copy


## Adds `card` to the deck and moves to the next stop. Null skips the reward and
## pays SKIP_GOLD instead. Rejects a card that was not offered, or any call once
## the run is finished.
func resolve_reward(card: CardData) -> bool:
	if finished or not _reward_pending:
		return false
	if card != null:
		if not reward_choices().has(card):
			push_error("RunState.resolve_reward: card was not offered")
			return false
		deck.append(card)
	else:
		gold += SKIP_GOLD
	_finish_reward()
	return true


## Whether the free Remove alternative can be taken now: a reward is pending, it is unused,
## and the deck keeps at least one card (the vendor's rule).
func can_reward_remove() -> bool:
	return _reward_pending and not finished and not reward_remove_used and deck.size() > 1


## Whether the free Heal alternative can be taken now: a reward is pending, it is unused
## and the player is hurt.
func can_reward_heal() -> bool:
	return _reward_pending and not finished and not reward_heal_used and player.hp < player.max_hp


## Resolves the reward by removing one copy of `card` from the deck (no card, no skip gold).
## Rejects a card not in the deck, a used alternative or a deck that would be emptied.
func resolve_reward_remove(card: CardData) -> bool:
	if not can_reward_remove():
		return false
	var index := deck.find(card)
	if index == -1:
		push_error("RunState.resolve_reward_remove: card is not in the deck")
		return false
	deck.remove_at(index)
	reward_remove_used = true
	_finish_reward()
	return true


## Resolves the reward by healing REWARD_HEAL HP, capped at max HP (no card, no skip gold).
## Rejects a used alternative or a player at full HP.
func resolve_reward_heal() -> bool:
	if not can_reward_heal():
		return false
	player.heal(REWARD_HEAL)
	reward_heal_used = true
	_finish_reward()
	return true


func _finish_reward() -> void:
	_reward_pending = false
	_reward_choices = []
	_advance()


## Heals to full at a REST stop and moves on. Returns HP restored, or -1 if not at a rest stop.
func rest() -> int:
	var stop := current_stop()
	if stop == null or stop.type != StopType.REST:
		return -1
	var restored := player.heal(player.max_hp - player.hp)
	_advance()
	return restored


## Deck positions of the cards the Remember choice can bring back stronger: those with a remembered
## block that are not yet Remembered. Empty off a rest stop.
func rememberable_indices() -> Array[int]:
	var indices: Array[int] = []
	var stop := current_stop()
	if stop == null or stop.type != StopType.REST:
		return indices
	for i in deck.size():
		if deck[i].can_remember():
			indices.append(i)
	return indices


## The rest stop's second choice: the card at `deck_index` becomes its Remembered form, no heal, and the
## line moves on. False (changing nothing) off a rest stop or for a card that cannot be Remembered.
func remember(deck_index: int) -> bool:
	if not rememberable_indices().has(deck_index):
		return false
	deck[deck_index] = deck[deck_index].remembered_card()
	_advance()
	return true


## HP the rest at this stop will restore (0 off a rest stop).
func rest_heal_amount() -> int:
	var stop := current_stop()
	if stop == null or stop.type != StopType.REST:
		return 0
	return player.max_hp - player.hp


## Which rest of the line this is, counting from 1 (0 off a rest stop).
func rest_number() -> int:
	var stop := current_stop()
	if stop == null or stop.type != StopType.REST:
		return 0
	var count := 0
	for i in stop_index + 1:
		if stops[i].type == StopType.REST:
			count += 1
	return count


## The beat to show at a STORY stop, or null if not at one or it failed to load
## (logged); the stop can still be passed with read_story().
func current_beat() -> StoryBeat:
	var stop := current_stop()
	if stop == null or stop.type != StopType.STORY:
		return null
	return StoryContent.beat(stop.beat_index, character.id)


## Moves past a STORY stop. Returns false if not at one.
func read_story() -> bool:
	var stop := current_stop()
	if stop == null or stop.type != StopType.STORY:
		return false
	_advance()
	return true


## The vendor for the current VENDOR stop (created on first call, so asking again
## does not re-roll the stock), or null if not at a vendor stop.
func vendor() -> Vendor:
	var stop := current_stop()
	if stop == null or stop.type != StopType.VENDOR:
		return null
	if _vendor == null:
		_vendor = Vendor.new(deck, _rng, 0, StarterContent.vendor_pool(character.id), _unowned_relics(), _wallet, StarterContent.rarity_weights(rarity_tier()))
	return _vendor


## Vendor purchases: the Vendor spends from the run's wallet, so `gold` is always current. A
## failed purchase changes nothing; when not at a vendor stop they fail.
func vendor_buy_card(offer_index: int) -> Vendor.Result:
	var v := vendor()
	if v == null:
		return Vendor.Result.fail("not at a vendor")
	return v.buy_card(offer_index)


func vendor_remove_card(deck_index: int) -> Vendor.Result:
	var v := vendor()
	if v == null:
		return Vendor.Result.fail("not at a vendor")
	return v.remove_card(deck_index)


func vendor_buy_heal() -> Vendor.Result:
	var v := vendor()
	if v == null:
		return Vendor.Result.fail("not at a vendor")
	return v.buy_heal(player)


## Buys the visit's relic: it joins `relics` and a MAX_HP relic raises the player's max HP
## (once, here; a restored save already holds the raised max HP).
func vendor_buy_relic() -> Vendor.Result:
	var v := vendor()
	if v == null:
		return Vendor.Result.fail("not at a vendor")
	var result := v.buy_relic(player)
	if result.ok:
		relics.append(result.relic)
	return result


## Leaves the vendor and moves on. False if not at a vendor stop.
func leave_vendor() -> bool:
	if vendor() == null:
		return false
	_vendor = null
	_advance()
	return true


## The character's relic pool minus the relics already owned.
func _unowned_relics() -> Array[RelicData]:
	var left: Array[RelicData] = []
	for relic in StarterContent.relic_pool(character.id):
		if not relics.has(relic):
			left.append(relic)
	return left


func _advance() -> void:
	_vendor = null
	stop_index += 1
	if stop_index >= stops.size():
		finished = true
		escaped = true


## The line, 22 stops in two acts (a train line in the original theme, a memorial city since v0.5.0): four regular fights, the Brakeman (now Bellkeeper) halfway (stop 9), four
## harder fights, then the Conductor (now Eraser). Three vendors, five rests (the last just before the finale) and the four story beats in order.
## Tier (act) and fight number are filled in here; see docs/LEVELS_DESIGN.md.
static func _default_line() -> Array[Stop]:
	var line: Array[Stop] = [
		Stop.new(StopType.STORY, 0, 0).place("Shore of Names", &"", &"coastal"),
		Stop.new(StopType.COMBAT, 1).place("Drowned Street", &"battle_street"),
		Stop.new(StopType.COMBAT, 2).place("Laundry Court", &"battle_street"),
		Stop.new(StopType.REST).place("Lampkeeper's Kitchen"),
		Stop.new(StopType.COMBAT, 2).place("Empty Tenements", &"battle_street"),
		Stop.new(StopType.VENDOR).place("The Lost-Property Stall"),
		Stop.new(StopType.COMBAT, 2).place("Petition Steps", &"battle_street"),
		Stop.new(StopType.STORY, 0, 1).place("The Unanswered Hall"),
		Stop.new(StopType.REST).place("Caretaker's Alcove"),
		Stop.new(StopType.COMBAT, 1, 0, false, true).place("The Bell Court", &"battle_bell_court"),
		Stop.new(StopType.STORY, 0, 2).place("Garden of Unmarked Stones"),
		Stop.new(StopType.REST).place("Glasshouse Shelter"),
		Stop.new(StopType.COMBAT, 2).place("Processional Garden", &"battle_garden"),
		Stop.new(StopType.COMBAT, 3).place("The Listening Marsh", &"battle_garden"),
		Stop.new(StopType.VENDOR).place("The Bone Orchard Market"),
		Stop.new(StopType.REST).place("Candlehouse"),
		Stop.new(StopType.COMBAT, 2).place("The Name Vault", &"battle_archive"),
		Stop.new(StopType.COMBAT, 3).place("The Unwritten Causeway", &"battle_archive"),
		Stop.new(StopType.VENDOR).place("Last Keepsake Stall"),
		Stop.new(StopType.REST).place("The Last Hearth"),
		Stop.new(StopType.STORY, 0, 3).place("The Breathing Door"),
		Stop.new(StopType.COMBAT, 1, 0, true).place("The Threshold", &"battle_threshold"),
	]
	var tier := 0
	var fight := 0
	for stop in line:
		stop.tier = tier
		if stop.type == StopType.COMBAT and not stop.boss and not stop.mid_boss:
			stop.fight = fight
			fight += 1
		if stop.mid_boss:
			tier = 1
	return line


## How far into the run the player is, 0 to 3 (a quarter of the stop line each): picks the rarity odds
## (StarterContent.rarity_weights) for rewards and vendor stock.
func rarity_tier() -> int:
	if stops.is_empty():
		return 0
	return clampi(stop_index * StarterContent.RARITY_WEIGHTS.size() / stops.size(), 0, StarterContent.RARITY_WEIGHTS.size() - 1)


func _roll_rewards() -> void:
	# Mostly the character's own cards, with a neutral one mixed in: up to REWARD_CLASS_CHOICES
	# class cards, then neutral cards to fill, then any class cards left over.
	var class_cards: Array[CardData] = []
	var neutral_cards: Array[CardData] = []
	for card in _reward_candidates(_distinct_cards(StarterContent.reward_pool(character.id))):
		if card.character == &"":
			neutral_cards.append(card)
		else:
			class_cards.append(card)
	# Each slot rolls a rarity first (rarer cards come up more often deeper into the run), then a card of it.
	var weights := StarterContent.rarity_weights(rarity_tier())
	var picks: Array[CardData] = []
	var class_picks := StarterContent.pick_by_rarity(class_cards, REWARD_CLASS_CHOICES, weights, _rng)
	picks.append_array(class_picks)
	picks.append_array(StarterContent.pick_by_rarity(neutral_cards, REWARD_CHOICES - picks.size(), weights, _rng))
	if picks.size() < REWARD_CHOICES:
		var rest: Array[CardData] = []
		for card in class_cards:
			if not class_picks.has(card):
				rest.append(card)
		picks.append_array(StarterContent.pick_by_rarity(rest, REWARD_CHOICES - picks.size(), weights, _rng))
	_reward_choices.assign(picks)
	for card in picks:
		if not offered_ids.has(card.id):
			offered_ids.append(card.id)


## The cards a reward may draw from. Prefers cards not offered before and not at the
## copy cap; if that leaves fewer than REWARD_CHOICES, lets back in the already-offered
## ones, and only then the capped ones, so an offer is as full as the pool allows.
func _reward_candidates(pool: Array[CardData]) -> Array[CardData]:
	var copies := {}
	for card in deck:
		copies[card.id] = int(copies.get(card.id, 0)) + 1
	var fresh: Array[CardData] = []
	var uncapped: Array[CardData] = []
	for card in pool:
		if int(copies.get(card.id, 0)) < COPY_CAP:
			uncapped.append(card)
			if not offered_ids.has(card.id):
				fresh.append(card)
	if fresh.size() >= REWARD_CHOICES:
		return fresh
	if uncapped.size() >= REWARD_CHOICES:
		return uncapped
	return pool


func _distinct_cards(cards: Array[CardData]) -> Array[CardData]:
	var seen := {}
	var distinct: Array[CardData] = []
	for card in cards:
		if not seen.has(card.id):
			seen[card.id] = true
			distinct.append(card)
	return distinct
