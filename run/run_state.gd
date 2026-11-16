class_name RunState
extends RefCounted
## One escape attempt: the stops the player passes through, carrying HP, the deck, gold and relics from stop to
## stop. Pure logic with no nodes, so the run screen is only a view over it. Combat itself is untouched: a combat
## stop just builds a Combat from this state (see docs/RUN_INTEGRATION.md).
##
## Two shapes: map mode, what New Journey plays (run.gd `new_runs_use_map`): the run follows a RouteMap the player
## picks a path through, chapter by chapter (docs/MAP_DESIGN.md). Line mode, a RunState's own default (`uses_map()`
## false), walks a fixed line of stops; the older tests and the line sims use it. Everything that is not about the
## map behaves the same in both. New stop kinds become new StopType values plus one branch in the screen.

enum StopType { COMBAT, REST, STORY, VENDOR, TREASURE, EVENT }

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
## Map mode only (docs/MAP_DESIGN.md "Phase 4f"): HP recovered, as a share of max HP, after every won regular fight,
## so a route with no rests still has some sustain. The line never uses it. 0 turns it off.
const MAP_FIGHT_HEAL_FRACTION := 0.05
## Map mode only: on top of that, the share of the HP the player is missing that comes back after every won regular
## fight, so a player who is hurt recovers more than one who is not (this is what flattens the gap between routes).
const MAP_FIGHT_HEAL_MISSING_FRACTION := 0.6
## Map mode only: a rest stop's Rest choice heals this share of max HP (capped at max HP). The line's rest heals to full
## and keeps doing so. Below 1.0 a route full of rests is worth less, which narrows the gap between routes.
const MAP_REST_HEAL_FRACTION := 0.5
## Map mode only: HP recovered, as a share of max HP, on beating the mid-boss (the act-1 boss), on top of the line's gold and card.
const MAP_MID_BOSS_HEAL_FRACTION := 0.75
## HP recovered, as a share of max HP, when a new chapter begins (docs/CHAPTERS_DESIGN.md, section 1).
const CHAPTER_BREAK_HEAL_FRACTION := 0.75
## A chapter's end boss pays this much gold and a boss relic: one priced at least BOSS_MIN_RELIC_PRICE when the character
## has any left (else any relic, else END_BOSS_FALLBACK_GOLD in its place). No card reward (docs/CHAPTERS_DESIGN.md, 2a).
const END_BOSS_GOLD := 60
const BOSS_MIN_RELIC_PRICE := 70
const END_BOSS_FALLBACK_GOLD := 100
## Map mode only: the share of the line's gold per won regular fight (Vendor.gold_for_win) that a map fight pays. A map run
## has about 11 fights against the line's 8, so the same pay per fight would leave a lot of gold unspent. The mid-boss bonus,
## the skip gold and relic gold are not scaled.
const MAP_GOLD_FACTOR := 0.65
## A treasure chest holds a relic priced at least this much at a vendor (the cheapest tier, 50 and 55, is left out),
## so a chest beats a shop's cheapest item. If every relic left to this character is cheaper, one of those is given.
const TREASURE_MIN_RELIC_PRICE := 65
## Gold a chest gives instead when the character owns every relic of its pool.
const TREASURE_FALLBACK_GOLD := 100
## Elite fights (map mode, docs/MAP_DESIGN.md "Phase 5a"): the pack's threat budget is the row's budget times this (on top of the
## class difficulty), the win pays this much extra gold, and its spoils always hold a relic (see ELITE_RELIC_FALLBACK_GOLD).
const ELITE_BUDGET_MULTIPLIER := 1.1
const ELITE_GOLD_BONUS := 20
## Gold an elite drops instead of a relic when the character owns every relic of its pool.
const ELITE_RELIC_FALLBACK_GOLD := 60
## Gold an event gives instead of a relic it cannot give because the character owns every relic it could draw.
const EVENT_RELIC_FALLBACK_GOLD := 40

## One stop on the line or one map node's stop (the class and its fields are documented in RunRoute).
const Stop = RunRoute.Stop

## Who is playing: sets the starting HP and deck and which cards the run can offer.
var character: Character
var player: Combatant
var deck: Array[CardData]
var stops: Array[Stop] = []
## Line mode: the index into `stops`. Map mode: the row (0 to 29) of the current node, 0 before the first
## choice, and `stops.size()` once the final boss is beaten. Progress text ("Journey n/30") reads it as is.
var stop_index: int = 0
## Map mode only (null in line mode): the generated map, from RouteMap.generate(seed, character id) with
## its own RNG, so it never touches `_rng`.
var route: RouteMap = null
## Map mode: the id of the node the player is at, -1 before the first choice.
var current_node: int = -1
## The chapter being played (1 to Chapters.count()). Each chapter is a fresh map; deck, relics and gold carry over.
var chapter: int = 1
## True while the finale is being played (after the last chapter's break; `_map_stop` is the finale stop). Saved with a run.
var finale := false
## True once the last chapter that exists is won while more are planned (Chapters.open_ended): the run is over, with "To be continued".
var to_be_continued := false
## True between a chapter's end boss and the next chapter (the break). The map then sits on its last node.
var chapter_break := false
## Map mode: the ids of the nodes taken so far, in order.
var visited: Array[int] = []
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
## Map mode: HP the last won fight restored (0 otherwise). Display only, not saved.
var map_win_heal := 0
## The relic spoils waiting to be taken: an elite's, a chapter end boss's and an open chest's (see RunSpoils). Never saved:
## they only exist inside a stop, and the save is made on arrival.
var _spoils := RunSpoils.new()
## Map mode: the bonus gold the last won elite fight paid. Display only, not saved.
var elite_bonus_gold := 0
## Relics bought from vendors this run, in purchase order. Saved with the run (as ids).
var relics: Array[RelicData] = []

var _vendor: Vendor = null
## Ids of the events this run has shown at "?" stops (a draw without replacement: the pool is reshuffled once all
## twelve were seen). Saved with a map run; an older save lacks it and starts empty.
var events_seen: Array[StringName] = []
## The run RNG (seeded in `_init`; declared before `_events`, which holds it).
var _rng := RandomNumberGenerator.new()
## The open event of the current EVENT stop and what was chosen there (see RunEvents). Once an event is rolled the stop
## is open: not a stop boundary. It rolls with the run RNG, handed over here.
var _events := RunEvents.new(_rng)
var _active_combat: Combat = null
var _reward_choices: Array[CardData] = []
var _reward_pending: bool = false
## Map mode: the stop of the current node, null between stops.
var _map_stop: Stop = null


## `use_map` turns on map mode. Off (the default) the run is the fixed line, untouched.
func _init(rng_seed: int = 0, character_id: StringName = StarterContent.DEFAULT_CHARACTER_ID, use_map: bool = false) -> void:
	_rng.seed = rng_seed
	character = StarterContent.character(character_id)
	if character == null:
		# The cause is logged; an empty character keeps the run constructible, and its first
		# fight then fails cleanly because Combat rejects an empty deck.
		character = Character.new()
	player = Combatant.new(character.display_name, character.max_hp)
	if character.id != &"":
		deck.assign(StarterContent.starter_deck(character.id))
	if use_map:
		route = RouteMap.generate(rng_seed, character.id)
		stops.assign(RunRoute.placeholder_stops()) # no line in map mode (see RunRoute.placeholder_stops)
	else:
		stops = RunRoute.default_line()


## The stop the player is at, or null once the run is finished (and, in map mode, between stops).
func current_stop() -> Stop:
	if finished:
		return null
	return _map_stop if route != null else stops[stop_index]


func uses_map() -> bool:
	return route != null


## Map mode: true while the player is inside the current node's stop (from choosing it until it is
## resolved), false at the map.
func in_map_stop() -> bool:
	return route != null and _map_stop != null


## Map mode: the stop of the current node, kept once the run is finished (null between stops and in line mode).
func map_stop() -> Stop:
	return _map_stop


## Map mode: puts a run built in line mode at a saved place on `map` (RunSave has validated all of it).
## `current` is the node id (-1 before the first choice), `path` the visited ids, `inside_stop` whether
## the player is in that node's stop rather than at the map. Replaces the line with the map's
## placeholder stops, like `_init` does with use_map.
func restore_map(map: RouteMap, current: int, path: Array[int], inside_stop: bool) -> void:
	RunRoute.restore_map(self, map, current, path, inside_stop)


## Map mode: the node ids the player may pick next. The start nodes before any choice, else the successors
## of the current node. Empty while a stop is in progress (fight, reward, vendor, rest or story), when the
## run is finished, and in line mode.
func reachable_nodes() -> Array[int]:
	return RunRoute.reachable_nodes(self)


## Map mode: moves to node `id` and opens its stop (see `current_stop()`). False, changing nothing, unless
## the node is currently reachable.
func choose_node(id: int) -> bool:
	return RunRoute.choose_node(self, id)


## Map mode: the player stands at the end of chapter `chapter` and a further chapter exists.
func can_enter_chapter_break() -> bool:
	return RunRoute.can_enter_chapter_break(self)


## Starts the break after the chapter's end boss. False, changing nothing, unless `can_enter_chapter_break()`.
func enter_chapter_break() -> bool:
	return RunRoute.enter_chapter_break(self)


## True from winning a chapter's end boss until its relic is taken.
func boss_spoils_pending() -> bool:
	return _spoils.boss_pending and _reward_pending


## The relic waiting after a chapter's end boss, or null when none is pending or the character owned every relic.
func boss_relic() -> RelicData:
	return _spoils.boss_relic if boss_spoils_pending() else null


## The gold the spoils hold instead of a relic (END_BOSS_FALLBACK_GOLD when every relic is owned, else 0).
func boss_spoils_fallback_gold() -> int:
	return END_BOSS_FALLBACK_GOLD if boss_spoils_pending() and _spoils.boss_relic == null else 0


## Takes the boss relic (or the fallback gold) and opens the chapter break (or, after the last chapter that exists, ends
## the run with "To be continued"). False, changing nothing, when none waits.
func take_boss_spoils() -> bool:
	return RunChapters.take_boss_spoils(self)


## True at the break after the last chapter of a complete game (Chapters.has_finale): the next step is the finale, not a chapter.
func can_start_finale() -> bool:
	return chapter_break and route != null and chapter == Chapters.count() and Chapters.has_finale()


## From that break: heals CHAPTER_BREAK_HEAL_FRACTION of max HP and opens the finale, a boss fight with no map. Deck, relics and gold are as they
## were. False, changing nothing, anywhere else.
func start_finale() -> bool:
	return RunChapters.start_finale(self)


## RunSave: puts a run restored at the end boss into the finale (the save was made on its arrival).
func restore_finale() -> void:
	finale = true
	chapter_break = false
	_map_stop = RunChapters.finale_stop(self)


## The seed of chapter `n`'s map, derived from the previous chapter's map seed (Chapter 1 uses the run's own), so it does
## not depend on how much of the run RNG the earlier chapters used.
static func chapter_map_seed(previous_seed: int, n: int) -> int:
	return hash([previous_seed, n])


## From the break: heals CHAPTER_BREAK_HEAL_FRACTION of max HP, generates the next chapter's map and stands at its start.
## Deck, relics, gold and max HP carry over; per-stop state is cleared. False, changing nothing, outside a break.
func start_next_chapter() -> bool:
	return RunChapters.start_next_chapter(self)


## The stop type a map node plays as (bosses and elites are combats).
static func stop_type_for_node(type: RouteMap.NodeType) -> StopType:
	return RunRoute.stop_type_for_node(type)


## The battle backdrop screen key for the current fight: the node's in map mode, the stop's place on the
## line otherwise (&"" when it has none and the character's own is used).
func battle_backdrop() -> StringName:
	return RunRoute.battle_backdrop(self)


## The place name for the current stop ("" when it has none).
func destination_label() -> String:
	return RunRoute.destination_label(self)


func reward_pending() -> bool:
	return _reward_pending


## True between stops: nothing is in flight (no fight, reward, vendor visit or opened chest), so
## the run can be saved and restored exactly (see run/run_save.gd). An opened event counts as in flight too.
func at_stop_boundary() -> bool:
	return not finished and not _reward_pending and _vendor == null and _active_combat == null and not _spoils.treasure_opened and _events.open_event == null


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
		Combat.engine_error("RunState.start_combat: not at a fresh combat stop")
		return null
	if _active_combat != null:
		_active_combat.abandon()
		_active_combat = null
	var enemies := RunRoute.stop_enemies(self, stop, _rng)
	_active_combat = Combat.create(player, deck, enemies, _rng.randi(), relics)
	if _active_combat != null and debug_encounter.is_empty() and elite_modifier() >= 0:
		EliteModifiers.apply_to_combat(_active_combat, elite_modifier(), stop.row / RouteMap.ACT_ROWS)
	return _active_combat


## The EliteModifiers.Kind of the elite fight the player is at, or -1 (not at an elite, or in line mode).
func elite_modifier() -> int:
	if route == null or current_node < 0 or not in_elite_stop():
		return -1
	return route.elite_modifier(current_node)


## "Boss" for the final boss fight, "Mid-boss" for the mid-boss, "" for a regular fight. A debug
## encounter is judged by its enemies (any built chapter's end boss or mid-boss), so launching a boss gets the boss look anywhere.
func boss_label() -> String:
	return RunRoute.boss_label(self)


## Records how the fight the run started (start_combat) ended, from its own outcome (Combat.outcome): the game's path
## (run.gd, once the battle screen reports the fight over). A defeat ends the run; a victory pays gold and offers a
## reward that must be taken or skipped before the line moves on. Beating the boss stop is the exception: it pays
## nothing (no later stop could spend it), offers no reward and ends the run as an escape. Only valid at a COMBAT stop
## that has no reward pending and is not finished, with a started fight that has ENDED: anything else is a caller bug
## (logged, nothing changes). Returns false when the call was rejected, true when the result was recorded.
func complete_combat() -> bool:
	if _active_combat == null or _active_combat.outcome == Combat.Outcome.NONE:
		Combat.engine_error("RunState.complete_combat: no fight started by the run has ended")
		return false
	return _record_combat_result(_active_combat.outcome == Combat.Outcome.VICTORY, "complete_combat")


## Sims, tests and debug tools only: records `victory` as the current fight's result without the fight having to be
## played out (the sims record a turn-cap stall as a defeat; UI tests skip fights with it). A fight the run started
## that has ended on its own still decides (a disagreeing `victory` is logged and the outcome wins); one still in
## progress is abandoned. With no fight started the result is taken as given. Same rules and return as complete_combat.
func force_combat_result(victory: bool) -> bool:
	return _record_combat_result(victory, "force_combat_result")


func _record_combat_result(victory: bool, caller: String) -> bool:
	var stop := current_stop()
	if finished or _reward_pending or stop == null or stop.type != StopType.COMBAT:
		Combat.engine_error("RunState.%s: not at a combat stop awaiting a result" % caller)
		return false
	if _active_combat != null:
		_active_combat.abandon() # no-op once ended; releases the player from a fight cut short
		if _active_combat.outcome != Combat.Outcome.NONE:
			var actual := _active_combat.outcome == Combat.Outcome.VICTORY
			if actual != victory:
				Combat.engine_error("RunState.%s: the caller reported %s but the fight ended in %s" % [caller, "a victory" if victory else "a defeat", "a victory" if actual else "a defeat"])
				victory = actual
	_active_combat = null
	if not victory:
		finished = true
		escaped = false
		return true
	if stop.boss:
		if route != null and not stop.finale and (chapter < Chapters.count() or (chapter == Chapters.count() and (Chapters.open_ended() or Chapters.has_finale()))):
			# A chapter's end boss, with more chapters to come (or still to be written): gold and a boss relic, then the break
			# (or, after the last chapter that exists, "To be continued").
			gold += END_BOSS_GOLD
			_spoils.boss_relic = RunSpoils.roll_relic(self, _rng, BOSS_MIN_RELIC_PRICE)
			_spoils.boss_pending = true
			_reward_pending = true
			_reward_choices.clear()
			return true
		# The last boss ends the run: no gold (nothing left to spend it on), no card to pick.
		advance_stop()
		return true
	var win_gold := map_win_gold(stop.enemy_count) if route != null else Vendor.gold_for_win(stop.enemy_count)
	gold += win_gold + (MID_BOSS_GOLD_BONUS if stop.mid_boss else 0)
	for relic in relics:
		match relic.kind:
			RelicData.Kind.WIN_GOLD:
				gold += relic.amount
			RelicData.Kind.WIN_HEAL:
				player.heal(relic.amount)
	map_win_heal = player.heal(_map_win_heal_amount(stop)) if route != null else 0
	elite_bonus_gold = 0
	_spoils.reset_elite()
	if stop.elite and route != null:
		elite_bonus_gold = ELITE_GOLD_BONUS
		gold += elite_bonus_gold
		_spoils.elite_relic = RunSpoils.roll_relic(self, _rng, TREASURE_MIN_RELIC_PRICE)
		_spoils.elite_pending = true
	_roll_rewards()
	_reward_pending = true
	return true


## Map mode: the gold a won regular fight against `enemy_count` enemies pays (Vendor.gold_for_win times MAP_GOLD_FACTOR, rounded).
static func map_win_gold(enemy_count: int) -> int:
	return roundi(Vendor.gold_for_win(enemy_count) * MAP_GOLD_FACTOR)


## Map mode: HP the player recovers for winning the fight at `stop` (see MAP_FIGHT_HEAL_FRACTION and
## MAP_MID_BOSS_HEAL_FRACTION). Never negative; the heal itself is capped at max HP.
func _map_win_heal_amount(stop: Stop) -> int:
	if stop.mid_boss:
		return roundi(player.max_hp * MAP_MID_BOSS_HEAL_FRACTION)
	var missing := player.max_hp - player.hp
	return roundi(player.max_hp * MAP_FIGHT_HEAL_FRACTION + missing * MAP_FIGHT_HEAL_MISSING_FRACTION)


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
			Combat.engine_error("RunState.resolve_reward: card was not offered")
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
		Combat.engine_error("RunState.resolve_reward_remove: card is not in the deck")
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
	take_elite_spoils() # an elite's relic is never lost by skipping straight to the card
	_reward_pending = false
	_reward_choices = []
	advance_stop()


## Heals to full at a REST stop and moves on. Returns HP restored, or -1 if not at a rest stop.
func rest() -> int:
	return RunRoute.rest(self)


## Deck positions of the cards the Remember choice can bring back stronger: those with a remembered
## block that are not yet Remembered. Empty off a rest stop.
func rememberable_indices() -> Array[int]:
	return RunRoute.rememberable_indices(self)


## Deck positions of the cards that can be Remembered, at any stop (the events use it too).
func rememberable_deck_indices() -> Array[int]:
	var indices: Array[int] = []
	for i in deck.size():
		if deck[i].can_remember():
			indices.append(i)
	return indices


## The rest stop's second choice: the card at `deck_index` becomes its Remembered form, no heal, and the
## line moves on. False (changing nothing) off a rest stop or for a card that cannot be Remembered.
func remember(deck_index: int) -> bool:
	return RunRoute.remember(self, deck_index)


## HP the rest at this stop will restore (0 off a rest stop).
func rest_heal_amount() -> int:
	return RunRoute.rest_heal_amount(self)


## Which rest of the line this is, counting from 1 (0 off a rest stop).
func rest_number() -> int:
	return RunRoute.rest_number(self)


## The beat to show at a STORY stop, or null if not at one or it failed to load
## (logged); the stop can still be passed with read_story().
func current_beat() -> StoryBeat:
	return RunRoute.current_beat(self)


## Moves past a STORY stop. Returns false if not at one.
func read_story() -> bool:
	return RunRoute.read_story(self)


## The vendor for the current VENDOR stop (created on first call, so asking again
## does not re-roll the stock), or null if not at a vendor stop.
func vendor() -> Vendor:
	if not RunRoute.at_stop(self, StopType.VENDOR):
		return null
	if _vendor == null:
		_vendor = Vendor.new(deck, _rng, 0, StarterContent.vendor_pool(character.id, chapter), unowned_relics(), _wallet, StarterContent.rarity_weights(rarity_tier()))
	return _vendor


## Vendor purchases: the Vendor spends from the run's wallet, so `gold` is always current. A
## failed purchase changes nothing; when not at a vendor stop they fail.
func vendor_buy_card(offer_index: int) -> Vendor.Result:
	return RunRoute.vendor_buy_card(self, offer_index)


func vendor_remove_card(deck_index: int) -> Vendor.Result:
	return RunRoute.vendor_remove_card(self, deck_index)


func vendor_buy_heal() -> Vendor.Result:
	return RunRoute.vendor_buy_heal(self)


## Buys the visit's relic: it joins `relics` and a MAX_HP relic raises the player's max HP
## (once, here; a restored save already holds the raised max HP).
func vendor_buy_relic() -> Vendor.Result:
	return RunRoute.vendor_buy_relic(self)


## Leaves the vendor and moves on (advance_stop closes the visit). False if not at a vendor stop.
func leave_vendor() -> bool:
	return RunRoute.leave_vendor(self)


## Whether the chest of the current TREASURE stop has been opened (false off a treasure stop).
func treasure_opened() -> bool:
	return _spoils.treasure_opened and in_treasure_stop()


## True while the current stop is a TREASURE stop.
func in_treasure_stop() -> bool:
	return RunRoute.at_stop(self, StopType.TREASURE)


## Opens the chest of the current TREASURE stop and returns true (again, harmlessly, if it is already open); false
## elsewhere. Opening rolls the relic with the run RNG, so a run resumed from the save made when the stop was
## entered rolls the same relic. The relic is chosen from the character's pool minus the relics owned: only those
## priced at least TREASURE_MIN_RELIC_PRICE when there are any, else any of them. If none is left the chest holds
## TREASURE_FALLBACK_GOLD instead (`treasure_relic()` stays null, `treasure_gold()` says so). A chest that is open
## is not a stop boundary (the arrival save is the resume point, as for a vendor visit), so it is never saved open.
func open_treasure() -> bool:
	return _spoils.open_treasure(self, _rng)


# --- Elite spoils (docs/MAP_DESIGN.md, "Phase 5a") -----------------------------------------------------------

## True while the current stop is an elite fight (before, during and after the fight).
func in_elite_stop() -> bool:
	return RunRoute.at_stop(self, StopType.COMBAT) and current_stop().elite


## True from winning an elite fight until its spoils are taken (`take_elite_spoils`, or by settling the card reward,
## which takes them first).
func elite_spoils_pending() -> bool:
	return _spoils.elite_pending and _reward_pending


## The relic waiting in an elite's spoils, or null when none is pending or the character owned every relic.
func elite_relic() -> RelicData:
	return _spoils.elite_relic if elite_spoils_pending() else null


## The gold the spoils hold instead of a relic (ELITE_RELIC_FALLBACK_GOLD when every relic is owned, else 0).
func elite_spoils_gold() -> int:
	return ELITE_RELIC_FALLBACK_GOLD if elite_spoils_pending() and _spoils.elite_relic == null else 0


## Takes the spoils: the relic (a MAX_HP relic raises max HP and HP once, here), or the fallback gold. The card reward
## stays pending. False, changing nothing, when no spoils wait.
func take_elite_spoils() -> bool:
	return _spoils.take_elite(self)


## The relic in the open chest, or null while it is closed, off a treasure stop and when the chest holds gold.
func treasure_relic() -> RelicData:
	return _spoils.treasure_relic if treasure_opened() else null


## The gold the open chest holds instead of a relic (0 while closed or when it holds a relic).
func treasure_gold() -> int:
	return TREASURE_FALLBACK_GOLD if treasure_opened() and _spoils.treasure_relic == null else 0


## Takes what the open chest holds (its relic, a MAX_HP relic raising max HP and HP once, here, like a purchase;
## or the fallback gold) and moves on. False, changing nothing, unless the chest is open.
func take_treasure() -> bool:
	return _spoils.take_treasure(self)


## Adds `relic` to the run; a MAX_HP relic raises max HP and HP once, here (a restored save already holds the raised max HP).
## Used by the spoils and the events; a vendor purchase goes through vendor_buy_relic.
func grant_relic(relic: RelicData) -> void:
	relics.append(relic)
	if relic.kind == RelicData.Kind.MAX_HP:
		player.max_hp += relic.amount
		player.hp += relic.amount


## The character's relic pool for this chapter minus the relics already owned.
func unowned_relics() -> Array[RelicData]:
	var left: Array[RelicData] = []
	for relic in StarterContent.relic_pool(character.id, chapter):
		if not relics.has(relic):
			left.append(relic)
	return left


# --- Event stops ("?" nodes, docs/EVENTS_DESIGN.md; the rules are in RunEvents) -----------------------------

## What pressing an event button did: the outcome text to show (the scene's reply plus a line per thing that
## happened) and the pick the player now owes, if any (see `event_followup`). The class is RunEvents.EventResult.
const EventResult = RunEvents.EventResult


## True while the current stop is an EVENT stop.
func in_event_stop() -> bool:
	return RunRoute.at_stop(self, StopType.EVENT)


## The event of the current EVENT stop (null elsewhere, or if event content failed to load: the stop can then be
## passed with `finish_event`). It is rolled the first time it is asked for, from the run RNG, among the events not
## yet in `events_seen` (all of them again once every event was seen), so a run resumed from the save made on
## arrival rolls the same event. Asking again returns the same one. Rolling opens the stop: it is no longer a boundary.
func current_event() -> EventData:
	return _events.current_event(self)


## The scene text of the open event for this character.
func event_body() -> String:
	return _events.event_body(self)


## The buttons of the open event this character sees, in order (empty off an event stop).
func event_choices() -> Array[EventChoice]:
	return _events.event_choices(self)


## How button `index` (a position in `event_choices()`) looks now: its label, summary (the printed cost and reward line
## made from the effects), whether it is enabled and the reason why not ("" when enabled). A gold payment the player
## cannot make, a card pick the deck cannot supply and a relic nothing is left to give each disable it; an HP cost never
## does (HP stops at 1). Everything is disabled once a choice was made.
func event_choice_state(index: int) -> RunEvents.ChoiceState:
	return _events.event_choice_state(self, index)


## Presses button `index`: applies its effects (a gamble is rolled here with the run RNG) and returns what happened.
## Fails, changing nothing, off an event stop, for a bad index, a disabled button, or once a choice was made. Picks
## the effects owe (remove, Remember, choose a card) are queued: see `event_followup`.
func resolve_event_choice(index: int) -> EventResult:
	return _events.resolve_event_choice(self, index)


## Whether a button was pressed at the open event.
func event_resolved() -> bool:
	return _events.event_resolved()


## The outcome text of the choice made ("" before one is).
func event_outcome() -> String:
	return _events.event_outcome()


## The pick the player owes now: &"remove", &"remember" or &"pick" (choose 1 of the offered cards), or &"" when none.
func event_followup() -> StringName:
	return _events.event_followup(self)


## The cards on offer for a pending &"pick" (stable until one is taken; empty otherwise).
func event_pick_choices() -> Array[CardData]:
	return _events.event_pick_choices(self)


## Deck positions the pending &"remember" may pick (empty otherwise).
func event_remember_indices() -> Array[int]:
	return _events.event_remember_indices(self)


## Completes the pending &"remove": the card at `deck_index` leaves the deck. False, changing nothing, if none is
## pending, the index is bad or the deck would be emptied.
func event_remove_card(deck_index: int) -> bool:
	return _events.event_remove_card(self, deck_index)


## Completes the pending &"remember": the card at `deck_index` becomes its Remembered form.
func event_remember_card(deck_index: int) -> bool:
	return _events.event_remember_card(self, deck_index)


## Completes the pending &"pick": `card` (one of `event_pick_choices()`) joins the deck.
func event_pick_card(card: CardData) -> bool:
	return _events.event_pick_card(self, card)


## Leaves the event and moves on. Needs a choice made and no pick owed (an event whose content failed to load can be
## left at once). False, changing nothing, otherwise.
func finish_event() -> bool:
	return _events.finish_event(self)


## Closes the open event (if any) and forgets what was chosen there.
func reset_event() -> void:
	_events.reset()


## The relic spoils of the run (see RunSpoils), for the helpers that take or clear them.
func spoils() -> RunSpoils:
	return _spoils


## Map mode: sets the stop the player is in (null: at the map, between stops). For the chapter transitions (RunChapters).
func set_map_stop(stop: Stop) -> void:
	_map_stop = stop


## Drops the pending reward once what it held was taken (a chapter end boss's spoils, which carry no card).
func clear_reward_pending() -> void:
	_reward_pending = false


## Leaves the current stop and moves on (the next line stop, or back to the map; past the final boss the run is won).
## Clears the per-stop state (vendor, chest, elite spoils, event). Used by the helpers that close a stop.
func advance_stop() -> void:
	_vendor = null
	_spoils.reset_treasure()
	_spoils.reset_elite()
	reset_event()
	RunRoute.advance(self)


## How many stops a journey has (the length of the default line, RunRoute.default_line), for text that names it.
static func default_line_size() -> int:
	return RunRoute.default_line().size()


## How far into the run the player is, 0 to 3 (a quarter of the stop line each): picks the rarity odds
## (StarterContent.rarity_weights) for rewards and vendor stock.
func rarity_tier() -> int:
	return RunRoute.rarity_tier(self)


## Rolls the card reward of a won fight (see RunRewards.roll).
func _roll_rewards() -> void:
	_reward_choices.assign(RunRewards.roll(self, _rng))
