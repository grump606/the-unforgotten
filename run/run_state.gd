class_name RunState
extends RefCounted
## One escape attempt: a fixed line of stops the player passes through, carrying
## HP and the deck from stop to stop. Pure logic with no nodes, so the run screen
## is only a view over it. Combat itself is untouched: a combat stop just builds
## a Combat from this state (see docs/RUN_INTEGRATION.md).
##
## New stop kinds (vendor, cutscene) become new StopType values plus one branch
## in the screen; the stop line and the persistent player/deck stay as they are.
##
## Map mode (off by default, see docs/MAP_DESIGN.md "Phase 2"): the run follows a RouteMap the player
## picks a path through instead of the fixed line. Everything below that is not about the map behaves
## exactly as in line mode; `uses_map()` tells them apart.

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
const MAP_MID_BOSS_HEAL_FRACTION := 1.0
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
const ELITE_BUDGET_MULTIPLIER := 1.2
const ELITE_GOLD_BONUS := 20
## Gold an elite drops instead of a relic when the character owns every relic of its pool.
const ELITE_RELIC_FALLBACK_GOLD := 60
## Gold an event gives instead of a relic it cannot give because the character owns every relic it could draw.
const EVENT_RELIC_FALLBACK_GOLD := 40

## One stop on the line. `enemy_count` only matters for COMBAT stops and
## `beat_index` (into StoryContent) only for STORY stops. A COMBAT stop with
## `boss` set fights StarterContent.boss_encounter() instead of a random pack,
## and winning it ends the run with no gold and no card reward. A COMBAT stop with `mid_boss` set
## fights StarterContent.mid_boss_encounter(); winning it pays gold and offers a card reward like a
## regular fight, and the run goes on.
## `tier` is the 0-based act (0 up to the mid-boss, 1 after it) and `fight` the 0-based number of a
## regular COMBAT stop among the regular fights; both are set by RunState._default_line and
## drive the encounter pools and stat ramp (see StarterContent.varied_encounter).
## In map mode `choose_node` builds the stop: `node_id` is the map node (-1 on the line), `backdrop` the
## node's battle screen key (&"" on the line and for non-fights) and `row` its run row (-1 on the line). A map
## fight is built by StarterContent.budget_encounter from `enemy_count` and `row` (`tier` and `fight` are line-only).
class Stop:
	var type: StopType
	var enemy_count: int
	var beat_index: int
	var boss: bool
	var mid_boss: bool
	## Map mode: an elite fight (tougher pack, relic drop). Set by `_stop_for_node`, never on the line.
	var elite: bool = false
	var tier: int
	var fight: int
	## Map mode only: the stop's row and node id in the route (-1 on a line stop).
	var row: int = -1
	var node_id: int = -1
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
				if elite:
					return "Elite (%d enemies)" % enemy_count
				return "Combat (%d enem%s)" % [enemy_count, "y" if enemy_count == 1 else "ies"]
			StopType.REST:
				return "Rest"
			StopType.STORY:
				return "Story"
			StopType.VENDOR:
				return "Vendor"
			StopType.TREASURE:
				return "Treasure"
			StopType.EVENT:
				return "Event"
		return "?"

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
## The spoils of a won elite fight (see `complete_combat`): `_elite_spoils` while they wait to be taken, with the relic in
## `_elite_relic` (null when the character owned every relic and gold is given instead). Rolled from the run RNG when the
## fight is won, so a save made on arrival (before the fight) always yields the same relic.
var _elite_spoils := false
var _elite_relic: RelicData = null
## Map mode: the bonus gold the last won elite fight paid. Display only, not saved.
var elite_bonus_gold := 0
## Relics bought from vendors this run, in purchase order. Saved with the run (as ids).
var relics: Array[RelicData] = []

var _vendor: Vendor = null
## The open chest of a TREASURE stop (see open_treasure): `_treasure_opened` once rolled, `_treasure_relic` its
## relic (null when the character owned every relic and the chest holds gold instead).
var _treasure_opened := false
var _treasure_relic: RelicData = null
## Ids of the events this run has shown at "?" stops (a draw without replacement: the pool is reshuffled once all
## twelve were seen). Saved with a map run; an older save lacks it and starts empty.
var events_seen: Array[StringName] = []
## The event of the current EVENT stop, rolled by `current_event()` the first time it is asked for (null before that,
## off an event stop and when event content failed to load). Once rolled the stop is open: not a stop boundary.
var _event: EventData = null
## Set once a choice of the open event was pressed: the outcome text, and the picks still owed to the player.
var _event_resolved := false
var _event_outcome := ""
var _event_pending: Array[Dictionary] = []
var _active_combat: Combat = null
var _rng := RandomNumberGenerator.new()
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
		# No line in map mode: `stops` holds RouteMap.ROWS placeholder entries so `stops.size()` is the
		# journey length. Nothing should read their contents; the live stop is `current_stop()`.
		for _row in RouteMap.ROWS:
			stops.append(Stop.new(StopType.COMBAT))
	else:
		stops = _default_line()


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


## Map mode: puts a run built in line mode at a saved place on `map` (RunSave has validated all of it).
## `current` is the node id (-1 before the first choice), `path` the visited ids, `inside_stop` whether
## the player is in that node's stop rather than at the map. Replaces the line with the map's
## placeholder stops, like `_init` does with use_map.
func restore_map(map: RouteMap, current: int, path: Array[int], inside_stop: bool) -> void:
	route = map
	stops.clear()
	for _row in RouteMap.ROWS:
		stops.append(Stop.new(StopType.COMBAT))
	current_node = current
	visited.assign(path)
	stop_index = map.node(current).row if current >= 0 else 0
	_map_stop = _stop_for_node(map.node(current)) if inside_stop and current >= 0 else null
	_treasure_opened = false
	_treasure_relic = null
	_reset_event()


## Map mode: the node ids the player may pick next. The start nodes before any choice, else the successors
## of the current node. Empty while a stop is in progress (fight, reward, vendor, rest or story), when the
## run is finished, and in line mode.
func reachable_nodes() -> Array[int]:
	var ids: Array[int] = []
	if route == null or finished or _map_stop != null:
		return ids
	if current_node == -1:
		return route.starts()
	return route.next_ids(current_node)


## Map mode: moves to node `id` and opens its stop (see `current_stop()`). False, changing nothing, unless
## the node is currently reachable.
func choose_node(id: int) -> bool:
	if not reachable_nodes().has(id):
		return false
	var n := route.node(id)
	current_node = id
	visited.append(id)
	stop_index = n.row
	_map_stop = _stop_for_node(n)
	return true


## The stop type a map node plays as (bosses and elites are combats).
static func stop_type_for_node(type: RouteMap.NodeType) -> StopType:
	match type:
		RouteMap.NodeType.REST:
			return StopType.REST
		RouteMap.NodeType.SHOP:
			return StopType.VENDOR
		RouteMap.NodeType.STORY:
			return StopType.STORY
		RouteMap.NodeType.TREASURE:
			return StopType.TREASURE
		RouteMap.NodeType.EVENT:
			return StopType.EVENT
	return StopType.COMBAT


## The battle backdrop screen key for the current fight: the node's in map mode, the stop's place on the
## line otherwise (&"" when it has none and the character's own is used).
func battle_backdrop() -> StringName:
	if route != null:
		return _map_stop.backdrop if _map_stop != null else &""
	return DestinationArt.battle_key(stop_index)


## The place name for the current stop ("" when it has none).
func destination_label() -> String:
	if route != null:
		return DestinationArt.label_for_stop(_map_stop) if _map_stop != null else ""
	return DestinationArt.label_at(stop_index)


func _stop_for_node(n: RouteMap.MapNode) -> Stop:
	var stop: Stop
	match n.type:
		RouteMap.NodeType.REST:
			stop = Stop.new(StopType.REST)
		RouteMap.NodeType.SHOP:
			stop = Stop.new(StopType.VENDOR)
		RouteMap.NodeType.STORY:
			stop = Stop.new(StopType.STORY, 0, n.beat_index)
		RouteMap.NodeType.TREASURE:
			stop = Stop.new(StopType.TREASURE)
		RouteMap.NodeType.EVENT:
			stop = Stop.new(StopType.EVENT)
		RouteMap.NodeType.MID_BOSS:
			stop = Stop.new(StopType.COMBAT, 1, 0, false, true)
		RouteMap.NodeType.BOSS:
			stop = Stop.new(StopType.COMBAT, 1, 0, true)
		RouteMap.NodeType.ELITE:
			stop = Stop.new(StopType.COMBAT, maxi(n.enemy_count, StarterContent.ELITE_MIN_ENEMIES))
			stop.elite = true
		_:
			stop = Stop.new(StopType.COMBAT, n.enemy_count)
	stop.tier = n.act
	stop.row = n.row
	stop.node_id = n.id
	stop.backdrop = n.backdrop
	return stop


func reward_pending() -> bool:
	return _reward_pending


## True between stops: nothing is in flight (no fight, reward, vendor visit or opened chest), so
## the run can be saved and restored exactly (see run/run_save.gd). An opened event counts as in flight too.
func at_stop_boundary() -> bool:
	return not finished and not _reward_pending and _vendor == null and _active_combat == null and not _treasure_opened and _event == null


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
	elif route != null and stop.row >= 0:
		var difficulty := StarterContent.map_class_difficulty(character.id)
		if stop.elite:
			difficulty *= ELITE_BUDGET_MULTIPLIER
		enemies = StarterContent.budget_encounter(stop.enemy_count, _rng, stop.row, difficulty, stop.elite)
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
## Returns false (changing nothing) when the call was rejected, true when the result was recorded.
func complete_combat(victory: bool) -> bool:
	var stop := current_stop()
	if finished or _reward_pending or stop == null or stop.type != StopType.COMBAT:
		Combat.engine_error("RunState.complete_combat: not at a combat stop awaiting a result")
		return false
	if _active_combat != null:
		_active_combat.abandon() # no-op once ended; releases the player from a fight cut short
		if _active_combat.outcome != Combat.Outcome.NONE:
			var actual := _active_combat.outcome == Combat.Outcome.VICTORY
			if actual != victory:
				Combat.engine_error("RunState.complete_combat: the caller reported %s but the fight ended in %s" % ["a victory" if victory else "a defeat", "a victory" if actual else "a defeat"])
				victory = actual
	_active_combat = null
	if not victory:
		finished = true
		escaped = false
		return true
	if stop.boss:
		# The boss ends the line: no gold (nothing left to spend it on), no card to pick.
		_advance()
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
	_elite_spoils = false
	_elite_relic = null
	if stop.elite and route != null:
		elite_bonus_gold = ELITE_GOLD_BONUS
		gold += elite_bonus_gold
		_elite_relic = _roll_relic(TREASURE_MIN_RELIC_PRICE)
		_elite_spoils = true
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
	_advance()


## Heals to full at a REST stop and moves on. Returns HP restored, or -1 if not at a rest stop.
func rest() -> int:
	var stop := current_stop()
	if stop == null or stop.type != StopType.REST:
		return -1
	var restored := player.heal(rest_heal_amount())
	_advance()
	return restored


## Deck positions of the cards the Remember choice can bring back stronger: those with a remembered
## block that are not yet Remembered. Empty off a rest stop.
func rememberable_indices() -> Array[int]:
	var stop := current_stop()
	if stop == null or stop.type != StopType.REST:
		var none: Array[int] = []
		return none
	return _rememberable_deck_indices()


## Deck positions of the cards that can be Remembered, at any stop.
func _rememberable_deck_indices() -> Array[int]:
	var indices: Array[int] = []
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
	if route != null:
		return mini(player.max_hp - player.hp, roundi(player.max_hp * MAP_REST_HEAL_FRACTION))
	return player.max_hp - player.hp


## Which rest of the line this is, counting from 1 (0 off a rest stop).
func rest_number() -> int:
	var stop := current_stop()
	if stop == null or stop.type != StopType.REST:
		return 0
	var count := 0
	if route != null:
		for id in visited:
			if route.node(id).type == RouteMap.NodeType.REST:
				count += 1
		return count
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


## Whether the chest of the current TREASURE stop has been opened (false off a treasure stop).
func treasure_opened() -> bool:
	return _treasure_opened and in_treasure_stop()


## True while the current stop is a TREASURE stop.
func in_treasure_stop() -> bool:
	var stop := current_stop()
	return stop != null and stop.type == StopType.TREASURE


## Opens the chest of the current TREASURE stop and returns true (again, harmlessly, if it is already open); false
## elsewhere. Opening rolls the relic with the run RNG, so a run resumed from the save made when the stop was
## entered rolls the same relic. The relic is chosen from the character's pool minus the relics owned: only those
## priced at least TREASURE_MIN_RELIC_PRICE when there are any, else any of them. If none is left the chest holds
## TREASURE_FALLBACK_GOLD instead (`treasure_relic()` stays null, `treasure_gold()` says so). A chest that is open
## is not a stop boundary (the arrival save is the resume point, as for a vendor visit), so it is never saved open.
func open_treasure() -> bool:
	if not in_treasure_stop():
		return false
	if _treasure_opened:
		return true
	_treasure_relic = _roll_relic(TREASURE_MIN_RELIC_PRICE)
	_treasure_opened = true
	return true


# --- Elite spoils (docs/MAP_DESIGN.md, "Phase 5a") -----------------------------------------------------------

## True while the current stop is an elite fight (before, during and after the fight).
func in_elite_stop() -> bool:
	var stop := current_stop()
	return stop != null and stop.type == StopType.COMBAT and stop.elite


## True from winning an elite fight until its spoils are taken (`take_elite_spoils`, or by settling the card reward,
## which takes them first).
func elite_spoils_pending() -> bool:
	return _elite_spoils and _reward_pending


## The relic waiting in an elite's spoils, or null when none is pending or the character owned every relic.
func elite_relic() -> RelicData:
	return _elite_relic if elite_spoils_pending() else null


## The gold the spoils hold instead of a relic (ELITE_RELIC_FALLBACK_GOLD when every relic is owned, else 0).
func elite_spoils_gold() -> int:
	return ELITE_RELIC_FALLBACK_GOLD if elite_spoils_pending() and _elite_relic == null else 0


## Takes the spoils: the relic (a MAX_HP relic raises max HP and HP once, here), or the fallback gold. The card reward
## stays pending. False, changing nothing, when no spoils wait.
func take_elite_spoils() -> bool:
	if not elite_spoils_pending():
		return false
	if _elite_relic != null:
		_grant_relic(_elite_relic)
	else:
		gold += ELITE_RELIC_FALLBACK_GOLD
	_elite_spoils = false
	_elite_relic = null
	return true


## A relic from the character's pool minus the relics owned, drawn with the run RNG: among those priced at least
## `min_price` when there are any, else among all of them; null when none is left.
func _roll_relic(min_price: int) -> RelicData:
	var unowned := _unowned_relics()
	var choices: Array[RelicData] = []
	for relic in unowned:
		if relic.price >= min_price:
			choices.append(relic)
	if choices.is_empty():
		choices = unowned
	if choices.is_empty():
		return null
	return choices[_rng.randi_range(0, choices.size() - 1)] if choices.size() > 1 else choices[0]


## The relic in the open chest, or null while it is closed, off a treasure stop and when the chest holds gold.
func treasure_relic() -> RelicData:
	return _treasure_relic if treasure_opened() else null


## The gold the open chest holds instead of a relic (0 while closed or when it holds a relic).
func treasure_gold() -> int:
	return TREASURE_FALLBACK_GOLD if treasure_opened() and _treasure_relic == null else 0


## Takes what the open chest holds (its relic, a MAX_HP relic raising max HP and HP once, here, like a purchase;
## or the fallback gold) and moves on. False, changing nothing, unless the chest is open.
func take_treasure() -> bool:
	if not treasure_opened():
		return false
	if _treasure_relic != null:
		_grant_relic(_treasure_relic)
	else:
		gold += TREASURE_FALLBACK_GOLD
	_advance()
	return true


## Adds `relic` to the run; a MAX_HP relic raises max HP and HP once, here (a restored save already holds the raised max HP).
func _grant_relic(relic: RelicData) -> void:
	relics.append(relic)
	if relic.kind == RelicData.Kind.MAX_HP:
		player.max_hp += relic.amount
		player.hp += relic.amount


## The character's relic pool minus the relics already owned.
func _unowned_relics() -> Array[RelicData]:
	var left: Array[RelicData] = []
	for relic in StarterContent.relic_pool(character.id):
		if not relics.has(relic):
			left.append(relic)
	return left


# --- Event stops ("?" nodes, docs/EVENTS_DESIGN.md) ---------------------------------------------------------

## What pressing an event button did: the outcome text to show (the scene's reply plus a line per thing that
## happened) and the pick the player now owes, if any (see `event_followup`).
class EventResult:
	var ok := false
	var text := ""
	var followup: StringName = &""

	static func fail(why: String) -> EventResult:
		var result := EventResult.new()
		result.text = why
		return result


## True while the current stop is an EVENT stop.
func in_event_stop() -> bool:
	var stop := current_stop()
	return stop != null and stop.type == StopType.EVENT


## The event of the current EVENT stop (null elsewhere, or if event content failed to load: the stop can then be
## passed with `finish_event`). It is rolled the first time it is asked for, from the run RNG, among the events not
## yet in `events_seen` (all of them again once every event was seen), so a run resumed from the save made on
## arrival rolls the same event. Asking again returns the same one. Rolling opens the stop: it is no longer a boundary.
func current_event() -> EventData:
	if not in_event_stop():
		return null
	if _event != null:
		return _event
	var all := StarterContent.all_events()
	if all.is_empty():
		return null
	var unseen: Array[EventData] = []
	for event in all:
		if not events_seen.has(event.id):
			unseen.append(event)
	if unseen.is_empty():
		events_seen.clear()
		unseen = all
	_event = unseen[_rng.randi_range(0, unseen.size() - 1)]
	events_seen.append(_event.id)
	return _event


## The scene text of the open event for this character.
func event_body() -> String:
	var event := current_event()
	return event.body_for(character.id) if event != null else ""


## The buttons of the open event this character sees, in order (empty off an event stop).
func event_choices() -> Array[EventChoice]:
	var event := current_event()
	if event == null:
		var none: Array[EventChoice] = []
		return none
	return event.choices_for(character.id)


## How button `index` (a position in `event_choices()`) looks now: {"label", "summary" (the printed cost and reward line
## made from the effects), "enabled", "reason" (why not, "" when enabled)}. A gold payment the player cannot make, a
## card pick the deck cannot supply and a relic nothing is left to give each disable it; an HP cost never does (HP
## stops at 1). Everything is disabled once a choice was made.
func event_choice_state(index: int) -> Dictionary:
	var choices := event_choices()
	if index < 0 or index >= choices.size():
		return {"label": "", "summary": "", "enabled": false, "reason": "no such choice"}
	var choice := choices[index]
	var state := {"label": choice.label_for(character.id), "summary": _event_summary_with_fallback(choice.summary()), "enabled": true, "reason": ""}
	if _event_resolved:
		state["enabled"] = false
		state["reason"] = "Already chosen."
		return state
	if choice.gold_cost() > gold:
		state["enabled"] = false
		state["reason"] = "Needs %d gold (you have %d)." % [choice.gold_cost(), gold]
		return state
	for effect in choice.effects:
		var why := _event_blocked(effect)
		if why != "":
			state["enabled"] = false
			state["reason"] = why
			break
	return state


## A button's printed summary, with every relic gain whose pool has nothing left to give reworded to the gold it pays instead
## (EVENT_RELIC_FALLBACK_GOLD), so the text keeps promising exactly what the button does.
func _event_summary_with_fallback(summary: String) -> String:
	for pool in [EventEffect.Pool.NEUTRAL, EventEffect.Pool.CLASS, EventEffect.Pool.ANY]:
		if _event_relic_candidates(pool).is_empty():
			summary = summary.replace(EventEffect.relic_text(pool), "Gain %d gold (no relics left to find)" % EVENT_RELIC_FALLBACK_GOLD)
	return summary


## Why a top-level effect cannot be done now ("" when it can).
func _event_blocked(effect: EventEffect) -> String:
	match effect.kind:
		EventEffect.Kind.REMOVE_CARD:
			if deck.size() <= 1:
				return "Your deck has only one card."
		EventEffect.Kind.REMEMBER_CARD:
			if _rememberable_deck_indices().is_empty():
				return "No card in your deck can be remembered yet."
	return ""


## Presses button `index`: applies its effects (a gamble is rolled here with the run RNG) and returns what happened.
## Fails, changing nothing, off an event stop, for a bad index, a disabled button, or once a choice was made. Picks
## the effects owe (remove, Remember, choose a card) are queued: see `event_followup`.
func resolve_event_choice(index: int) -> EventResult:
	if current_event() == null:
		return EventResult.fail("no event")
	var state := event_choice_state(index)
	if not bool(state["enabled"]):
		return EventResult.fail(String(state["reason"]))
	var choice := event_choices()[index]
	var lines: Array[String] = []
	var gambles: Array[bool] = []
	_event_pending.clear()
	_apply_event_effects(choice.effects, lines, gambles)
	var text := choice.outcome_for(character.id)
	if not gambles.is_empty():
		var flavour := choice.win_outcome if gambles[0] else choice.lose_outcome
		if flavour != "":
			text += " " + flavour
	for line in lines:
		text += " " + line
	_event_resolved = true
	_event_outcome = text
	var result := EventResult.new()
	result.ok = true
	result.text = text
	result.followup = event_followup()
	return result


## Whether a button was pressed at the open event.
func event_resolved() -> bool:
	return _event_resolved


## The outcome text of the choice made ("" before one is).
func event_outcome() -> String:
	return _event_outcome


## The pick the player owes now: &"remove", &"remember" or &"pick" (choose 1 of the offered cards), or &"" when none.
func event_followup() -> StringName:
	_prune_event_pending()
	if _event_pending.is_empty():
		return &""
	match int(_event_pending[0]["kind"]):
		EventEffect.Kind.REMOVE_CARD:
			return &"remove"
		EventEffect.Kind.REMEMBER_CARD:
			return &"remember"
	return &"pick"


## Drops every owed pick that can no longer be completed. The pick screens have no Cancel, so a pick nothing can
## satisfy (a removal when only one card is left, a Remember when no card can be remembered, as a second removal
## after the deck shrank or a nested removal can leave) would trap the player in a stop that is not a save boundary.
## A removal needs a card to spare, so only deck.size() - 1 removals stay owed.
func _prune_event_pending() -> void:
	var removals_left := deck.size() - 1
	var kept: Array[Dictionary] = []
	for entry in _event_pending:
		match int(entry["kind"]):
			EventEffect.Kind.REMOVE_CARD:
				if removals_left <= 0:
					continue
				removals_left -= 1
			EventEffect.Kind.REMEMBER_CARD:
				if _rememberable_deck_indices().is_empty():
					continue
		kept.append(entry)
	_event_pending = kept


## The cards on offer for a pending &"pick" (stable until one is taken; empty otherwise).
func event_pick_choices() -> Array[CardData]:
	var offered: Array[CardData] = []
	if event_followup() == &"pick":
		offered.assign(_event_pending[0]["cards"])
	return offered


## Deck positions the pending &"remember" may pick (empty otherwise).
func event_remember_indices() -> Array[int]:
	if event_followup() != &"remember":
		var none: Array[int] = []
		return none
	return _rememberable_deck_indices()


## Completes the pending &"remove": the card at `deck_index` leaves the deck. False, changing nothing, if none is
## pending, the index is bad or the deck would be emptied.
func event_remove_card(deck_index: int) -> bool:
	if event_followup() != &"remove" or deck_index < 0 or deck_index >= deck.size() or deck.size() <= 1:
		return false
	deck.remove_at(deck_index)
	_event_pending.remove_at(0)
	return true


## Completes the pending &"remember": the card at `deck_index` becomes its Remembered form.
func event_remember_card(deck_index: int) -> bool:
	if not event_remember_indices().has(deck_index):
		return false
	deck[deck_index] = deck[deck_index].remembered_card()
	_event_pending.remove_at(0)
	return true


## Completes the pending &"pick": `card` (one of `event_pick_choices()`) joins the deck.
func event_pick_card(card: CardData) -> bool:
	if not event_pick_choices().has(card):
		return false
	deck.append(card)
	_event_pending.remove_at(0)
	return true


## Leaves the event and moves on. Needs a choice made and no pick owed (an event whose content failed to load can be
## left at once). False, changing nothing, otherwise.
func finish_event() -> bool:
	if not in_event_stop():
		return false
	if _event == null:
		# Nothing was shown yet: only a stop whose content failed to load may be passed.
		if not StarterContent.all_events().is_empty():
			return false
	elif not _event_resolved or not _event_pending.is_empty():
		return false
	_advance()
	return true


func _reset_event() -> void:
	_event = null
	_event_resolved = false
	_event_outcome = ""
	_event_pending.clear()


## The relics an event may hand out from `pool`: the unowned ones of exactly that pool (the button's printed text names
## it, so a NEUTRAL pool never widens to class relics). Empty means the button is greyed or a gamble pays gold.
func _event_relic_candidates(pool: EventEffect.Pool) -> Array[RelicData]:
	var found: Array[RelicData] = []
	var unowned := _unowned_relics()
	for relic in unowned:
		var neutral: bool = relic.character == &""
		if pool == EventEffect.Pool.ANY or (pool == EventEffect.Pool.NEUTRAL and neutral) or (pool == EventEffect.Pool.CLASS and not neutral):
			found.append(relic)
	return found


## Applies a list of effects. `lines` collects what happened, `gambles` the result of each gamble rolled (true = won).
func _apply_event_effects(effects: Array[EventEffect], lines: Array[String], gambles: Array[bool]) -> void:
	for effect in effects:
		_apply_event_effect(effect, lines, gambles)


func _apply_event_effect(effect: EventEffect, lines: Array[String], gambles: Array[bool]) -> void:
	match effect.kind:
		EventEffect.Kind.HEAL_PERCENT, EventEffect.Kind.HEAL_FLAT:
			var wanted: int = roundi(player.max_hp * effect.amount / 100.0) if effect.kind == EventEffect.Kind.HEAL_PERCENT else effect.amount
			var healed := player.heal(wanted)
			if healed > 0:
				lines.append("You recover %d HP." % healed)
		EventEffect.Kind.LOSE_HP, EventEffect.Kind.LOSE_HP_PERCENT:
			var cost: int = roundi(player.max_hp * effect.amount / 100.0) if effect.kind == EventEffect.Kind.LOSE_HP_PERCENT else effect.amount
			var lost := clampi(cost, 0, player.hp - 1)
			player.hp -= lost
			player.changed.emit()
			if lost > 0:
				lines.append("You lose %d HP." % lost)
		EventEffect.Kind.GOLD:
			if effect.amount >= 0:
				gold += effect.amount
				if effect.amount > 0:
					lines.append("You gain %d gold." % effect.amount)
			else:
				var paid := mini(-effect.amount, gold)
				gold -= paid
				if paid > 0:
					lines.append("You pay %d gold." % paid)
		EventEffect.Kind.MAX_HP:
			if effect.amount >= 0:
				player.max_hp += effect.amount
				player.hp += effect.amount
			else:
				player.max_hp = maxi(player.max_hp + effect.amount, 1)
				player.hp = clampi(player.hp, 1, player.max_hp)
			player.changed.emit()
			lines.append("Your max HP %s by %d." % ["rises" if effect.amount >= 0 else "falls", absi(effect.amount)])
		EventEffect.Kind.ADD_CARD:
			var card := StarterContent.card_by_id(effect.card_id)
			if card != null:
				for _i in maxi(effect.count, 1):
					deck.append(card)
				lines.append("%s joins your deck." % card.display_name)
		EventEffect.Kind.ADD_CURSE:
			var curse := StarterContent.status_card(effect.card_id)
			if curse != null:
				for _i in maxi(effect.count, 1):
					deck.append(curse)
				lines.append("%s joins your deck." % ("A " + curse.display_name if effect.count <= 1 else "%d x %s" % [effect.count, curse.display_name]))
		EventEffect.Kind.ADD_RANDOM_CARD:
			var candidates := _event_card_candidates(effect)
			for _i in maxi(effect.count, 1):
				if candidates.is_empty():
					break
				var picked: CardData = candidates[_rng.randi_range(0, candidates.size() - 1)]
				deck.append(picked)
				lines.append("%s joins your deck." % picked.display_name)
		EventEffect.Kind.PICK_CARD:
			var offered := _event_draw_distinct(_event_card_candidates(effect), effect.count)
			if not offered.is_empty():
				_event_pending.append({"kind": effect.kind, "cards": offered})
		EventEffect.Kind.REMOVE_CARD:
			_event_pending.append({"kind": effect.kind})
		EventEffect.Kind.REMEMBER_CARD:
			if not _rememberable_deck_indices().is_empty():
				_event_pending.append({"kind": effect.kind})
		EventEffect.Kind.REMOVE_RANDOM_CARD:
			for _i in maxi(effect.count, 1):
				var owed := 0
				for entry in _event_pending:
					if int(entry["kind"]) == EventEffect.Kind.REMOVE_CARD:
						owed += 1
				if deck.size() - owed <= 1:
					break
				var gone := deck[_rng.randi_range(0, deck.size() - 1)]
				deck.erase(gone) # drops the first copy, which is as good as any: copies are the same card
				lines.append("%s is erased from your deck." % gone.display_name)
		EventEffect.Kind.GAIN_RELIC:
			var relics_left := _event_relic_candidates(effect.pool)
			if relics_left.is_empty():
				gold += EVENT_RELIC_FALLBACK_GOLD
				lines.append("There is nothing left to give you but %d gold." % EVENT_RELIC_FALLBACK_GOLD)
			else:
				var relic: RelicData = relics_left[_rng.randi_range(0, relics_left.size() - 1)] if relics_left.size() > 1 else relics_left[0]
				_grant_relic(relic)
				lines.append("You gain the %s." % relic.display_name)
		EventEffect.Kind.GAMBLE:
			var won := _rng.randi_range(1, 100) <= effect.amount
			gambles.append(won)
			_apply_event_effects(effect.win if won else effect.lose, lines, gambles)


## The cards an ADD_RANDOM_CARD or PICK_CARD draws from: the non-basic reward pool of this character, restricted by
## pool (neutral, own class or both), rarity and an optional effect kind. PICK_CARD only ever offers the class's own.
func _event_card_candidates(effect: EventEffect) -> Array[CardData]:
	var found: Array[CardData] = []
	var wanted_pool: EventEffect.Pool = EventEffect.Pool.CLASS if effect.kind == EventEffect.Kind.PICK_CARD else effect.pool
	for card in _distinct_cards(StarterContent.reward_pool(character.id)):
		var neutral: bool = card.character == &""
		if wanted_pool == EventEffect.Pool.NEUTRAL and not neutral:
			continue
		if wanted_pool == EventEffect.Pool.CLASS and neutral:
			continue
		if effect.rarity >= 0 and int(card.rarity) != effect.rarity:
			continue
		if effect.has_effect >= 0:
			var has := false
			for card_effect in card.effects:
				if int(card_effect.kind) == effect.has_effect:
					has = true
			if not has:
				continue
		found.append(card)
	return found


## Up to `count` distinct cards out of `pool` drawn with the run RNG, preferring cards the deck holds fewer than
## COPY_CAP times when enough of those remain.
func _event_draw_distinct(pool: Array[CardData], count: int) -> Array[CardData]:
	var copies := {}
	for card in deck:
		copies[card.id] = int(copies.get(card.id, 0)) + 1
	var fresh: Array[CardData] = []
	for card in pool:
		if int(copies.get(card.id, 0)) < COPY_CAP:
			fresh.append(card)
	var source: Array[CardData] = fresh if fresh.size() >= count else pool.duplicate()
	var picks: Array[CardData] = []
	while picks.size() < count and not source.is_empty():
		var at := _rng.randi_range(0, source.size() - 1)
		picks.append(source[at])
		source.remove_at(at)
	return picks


func _advance() -> void:
	_vendor = null
	_treasure_opened = false
	_treasure_relic = null
	_elite_spoils = false
	_elite_relic = null
	_reset_event()
	if route != null:
		_map_stop = null
		if route.node(current_node).type == RouteMap.NodeType.BOSS:
			stop_index = stops.size()
			finished = true
			escaped = true
		return
	stop_index += 1
	if stop_index >= stops.size():
		finished = true
		escaped = true


## How many stops a journey has (the length of the default line), for text that names it.
static func default_line_size() -> int:
	return _default_line().size()


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
