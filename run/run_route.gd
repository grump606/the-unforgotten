class_name RunRoute
extends RefCounted
## The route of a RunState: the stops it passes through and how the player moves along them. The fixed line (line mode)
## and the map (map mode, docs/MAP_DESIGN.md): the Stop class, building the stop of a map node, choosing a node, moving
## on after a stop, putting a restored run back on its map, entering the chapter break, what a stop shows and fights
## (backdrop, place name, boss label, enemies), the rest, story and vendor stops, and the run's progress (rarity tier).
## Static helpers that take the run, so RunState keeps the public API and delegates here (as with RunChapters). It uses
## only RunState's public surface (`current_stop()`, `map_stop()`, `set_map_stop()`, `in_map_stop()`, `advance_stop()`,
## `vendor()`, `spoils()`, `reset_event()`, `elite_modifier()`); the run RNG is passed in where a stop's enemies are rolled.


## One stop on the line. `enemy_count` only matters for COMBAT stops and
## `beat_index` (into StoryContent) only for STORY stops. A COMBAT stop with
## `boss` set fights Encounters.boss_encounter() instead of a random pack,
## and winning it ends the run with no gold and no card reward. A COMBAT stop with `mid_boss` set
## fights Encounters.mid_boss_encounter(); winning it pays gold and offers a card reward like a
## regular fight, and the run goes on.
## `tier` is the 0-based act (0 up to the mid-boss, 1 after it) and `fight` the 0-based number of a
## regular COMBAT stop among the regular fights; both are set by RunRoute.default_line and
## drive the encounter pools and stat ramp (see Encounters.varied_encounter).
## In map mode `choose_node` builds the stop: `node_id` is the map node (-1 on the line), `backdrop` the
## node's battle screen key (&"" on the line and for non-fights) and `row` its run row (-1 on the line). A map
## fight is built by Encounters.budget_encounter from `enemy_count` and `row` (`tier` and `fight` are line-only).
## RunState.Stop names this class.
class Stop:
	var type: RunState.StopType
	var enemy_count: int
	var beat_index: int
	var boss: bool
	var mid_boss: bool
	## Map mode: an elite fight (tougher pack, relic drop). Set by `stop_for_node`, never on the line.
	var elite: bool = false
	## The finale after the last chapter (RunState.start_finale): a boss stop that is not on the map. Winning it ends the run as an escape.
	var finale: bool = false
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

	func _init(stop_type: RunState.StopType, count: int = 0, beat: int = 0, is_boss: bool = false, is_mid_boss: bool = false) -> void:
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
			RunState.StopType.COMBAT:
				if finale:
					return "Finale"
				if boss:
					return "Boss"
				if mid_boss:
					return "Mid-boss"
				if elite:
					return "Elite (%d enemies)" % enemy_count
				return "Combat (%d enem%s)" % [enemy_count, "y" if enemy_count == 1 else "ies"]
			RunState.StopType.REST:
				return "Rest"
			RunState.StopType.STORY:
				return "Story"
			RunState.StopType.VENDOR:
				return "Vendor"
			RunState.StopType.TREASURE:
				return "Treasure"
			RunState.StopType.EVENT:
				return "Event"
		return "?"


## Map mode has no line: `stops` holds RouteMap.ROWS placeholder entries so `stops.size()` is the journey length.
## Nothing should read their contents; the live stop is `RunState.current_stop()`.
static func placeholder_stops() -> Array[Stop]:
	var placeholders: Array[Stop] = []
	for _row in RouteMap.ROWS:
		placeholders.append(Stop.new(RunState.StopType.COMBAT))
	return placeholders


## See RunState.restore_map.
static func restore_map(run: RunState, map: RouteMap, current: int, path: Array[int], inside_stop: bool) -> void:
	run.route = map
	run.stops.assign(placeholder_stops())
	run.current_node = current
	run.visited.assign(path)
	run.stop_index = map.node(current).row if current >= 0 else 0
	run.set_map_stop(stop_for_node(map.node(current)) if inside_stop and current >= 0 else null)
	run.spoils().reset_treasure()
	run.reset_event()


## See RunState.reachable_nodes.
static func reachable_nodes(run: RunState) -> Array[int]:
	var ids: Array[int] = []
	if run.route == null or run.finished or run.in_map_stop():
		return ids
	if run.current_node == -1:
		return run.route.starts()
	return run.route.next_ids(run.current_node)


## See RunState.choose_node.
static func choose_node(run: RunState, id: int) -> bool:
	if not reachable_nodes(run).has(id):
		return false
	var n := run.route.node(id)
	run.current_node = id
	run.visited.append(id)
	run.stop_index = n.row
	run.set_map_stop(stop_for_node(n))
	return true


## See RunState.can_enter_chapter_break.
static func can_enter_chapter_break(run: RunState) -> bool:
	return run.route != null and not run.finished and not run.chapter_break and run.chapter < Chapters.count() \
			and run.current_node >= 0 and run.route.node(run.current_node).type == RouteMap.NodeType.BOSS and not run.in_map_stop()


## See RunState.enter_chapter_break.
static func enter_chapter_break(run: RunState) -> bool:
	if not can_enter_chapter_break(run):
		return false
	run.chapter_break = true
	return true


## The stop type a map node plays as (bosses and elites are combats).
static func stop_type_for_node(type: RouteMap.NodeType) -> RunState.StopType:
	match type:
		RouteMap.NodeType.REST:
			return RunState.StopType.REST
		RouteMap.NodeType.SHOP:
			return RunState.StopType.VENDOR
		RouteMap.NodeType.STORY:
			return RunState.StopType.STORY
		RouteMap.NodeType.TREASURE:
			return RunState.StopType.TREASURE
		RouteMap.NodeType.EVENT:
			return RunState.StopType.EVENT
	return RunState.StopType.COMBAT


## The stop map node `n` plays as.
static func stop_for_node(n: RouteMap.MapNode) -> Stop:
	var stop: Stop
	match n.type:
		RouteMap.NodeType.REST:
			stop = Stop.new(RunState.StopType.REST)
		RouteMap.NodeType.SHOP:
			stop = Stop.new(RunState.StopType.VENDOR)
		RouteMap.NodeType.STORY:
			stop = Stop.new(RunState.StopType.STORY, 0, n.beat_index)
		RouteMap.NodeType.TREASURE:
			stop = Stop.new(RunState.StopType.TREASURE)
		RouteMap.NodeType.EVENT:
			stop = Stop.new(RunState.StopType.EVENT)
		RouteMap.NodeType.MID_BOSS:
			stop = Stop.new(RunState.StopType.COMBAT, 1, 0, false, true)
		RouteMap.NodeType.BOSS:
			stop = Stop.new(RunState.StopType.COMBAT, 1, 0, true)
		RouteMap.NodeType.ELITE:
			stop = Stop.new(RunState.StopType.COMBAT, maxi(n.enemy_count, Encounters.ELITE_MIN_ENEMIES))
			stop.elite = true
		_:
			stop = Stop.new(RunState.StopType.COMBAT, n.enemy_count)
	stop.tier = n.act
	stop.row = n.row
	stop.node_id = n.id
	stop.backdrop = n.backdrop
	return stop


## Moves on after a stop (RunState.advance_stop has cleared the per-stop state): the next line stop, or back to the map;
## past the final boss the run is won.
static func advance(run: RunState) -> void:
	if run.route != null:
		run.set_map_stop(null)
		if run.route.node(run.current_node).type == RouteMap.NodeType.BOSS:
			run.stop_index = run.stops.size()
			run.finished = true
			run.escaped = true
		return
	run.stop_index += 1
	if run.stop_index >= run.stops.size():
		run.finished = true
		run.escaped = true


## See RunState.battle_backdrop.
static func battle_backdrop(run: RunState) -> StringName:
	if run.route != null:
		return run.map_stop().backdrop if run.map_stop() != null else &""
	return DestinationArt.battle_key(run.stop_index)


## See RunState.destination_label.
static func destination_label(run: RunState) -> String:
	if run.route != null:
		return DestinationArt.label_for_stop(run.map_stop()) if run.map_stop() != null else ""
	return DestinationArt.label_at(run.stop_index)


## See RunState.boss_label.
static func boss_label(run: RunState) -> String:
	if not run.debug_encounter.is_empty():
		var mid := false
		for n in range(1, Chapters.MAX_BUILT + 1):
			var data := Chapters.chapter(n)
			if run.debug_encounter.has(data.end_boss):
				return "Boss"
			mid = mid or run.debug_encounter.has(data.mid_boss)
		return "Mid-boss" if mid else ""
	var stop := run.current_stop()
	if stop == null:
		return ""
	if stop.finale:
		return "Final boss"
	if stop.boss:
		return "Boss"
	return "Mid-boss" if stop.mid_boss else ""


## The enemies of the fight at combat stop `stop` (RunState.start_combat): the debug encounter when one is set, the
## chapter's finale, boss or mid-boss, a map fight from the row's threat budget (rolled with `rng`; an elite's is larger,
## and an Enraged elite's pack is enraged here), or a line fight from the stop's tier and number.
static func stop_enemies(run: RunState, stop: Stop, rng: RandomNumberGenerator) -> Array[EnemyData]:
	var enemies: Array[EnemyData]
	if not run.debug_encounter.is_empty():
		for enemy_id in run.debug_encounter:
			var enemy := StarterContent.enemy_by_id(enemy_id)
			if enemy == null and run.debug_enemy_resolver.is_valid():
				enemy = run.debug_enemy_resolver.call(enemy_id)
			if enemy != null:
				enemies.append(enemy)
	elif stop.finale:
		enemies = Encounters.finale_encounter(run.chapter, run.character.id)
	elif stop.boss:
		enemies = Encounters.boss_encounter(run.chapter, run.character.id)
	elif stop.mid_boss:
		enemies = Encounters.mid_boss_encounter(run.chapter, run.character.id)
	elif run.route != null and stop.row >= 0:
		var difficulty := Encounters.map_class_difficulty(run.character.id, run.chapter)
		if stop.elite:
			difficulty *= RunState.ELITE_BUDGET_MULTIPLIER
		enemies = Encounters.budget_encounter(stop.enemy_count, rng, stop.row, difficulty, stop.elite, run.chapter)
		if run.elite_modifier() == EliteModifiers.Kind.ENRAGED:
			EliteModifiers.enrage(enemies)
	else:
		enemies = Encounters.varied_encounter(stop.enemy_count, rng, stop.tier, stop.fight)
	return enemies


# --- The rest, story and vendor stops ---------------------------------------------------------------------------

## True while the current stop is of type `type` (false once the run is finished and, in map mode, between stops).
static func at_stop(run: RunState, type: RunState.StopType) -> bool:
	var stop := run.current_stop()
	return stop != null and stop.type == type


## See RunState.vendor_buy_card.
static func vendor_buy_card(run: RunState, offer_index: int) -> Vendor.Result:
	var v := run.vendor()
	if v == null:
		return Vendor.Result.fail("not at a vendor")
	return v.buy_card(offer_index)


## See RunState.vendor_remove_card.
static func vendor_remove_card(run: RunState, deck_index: int) -> Vendor.Result:
	var v := run.vendor()
	if v == null:
		return Vendor.Result.fail("not at a vendor")
	return v.remove_card(deck_index)


## See RunState.vendor_buy_heal.
static func vendor_buy_heal(run: RunState) -> Vendor.Result:
	var v := run.vendor()
	if v == null:
		return Vendor.Result.fail("not at a vendor")
	return v.buy_heal(run.player)


## See RunState.vendor_buy_relic.
static func vendor_buy_relic(run: RunState) -> Vendor.Result:
	var v := run.vendor()
	if v == null:
		return Vendor.Result.fail("not at a vendor")
	var result := v.buy_relic(run.player)
	if result.ok:
		run.relics.append(result.relic)
	return result


## See RunState.leave_vendor. RunState.advance_stop closes the visit.
static func leave_vendor(run: RunState) -> bool:
	if run.vendor() == null:
		return false
	run.advance_stop()
	return true


## See RunState.rest.
static func rest(run: RunState) -> int:
	if not at_stop(run, RunState.StopType.REST):
		return -1
	var restored := run.player.heal(run.rest_heal_amount())
	run.advance_stop()
	return restored


## See RunState.rememberable_indices.
static func rememberable_indices(run: RunState) -> Array[int]:
	if not at_stop(run, RunState.StopType.REST):
		var none: Array[int] = []
		return none
	return run.rememberable_deck_indices()


## See RunState.remember.
static func remember(run: RunState, deck_index: int) -> bool:
	if not rememberable_indices(run).has(deck_index):
		return false
	run.deck[deck_index] = run.deck[deck_index].remembered_card()
	run.advance_stop()
	return true


## See RunState.rest_heal_amount: in map mode MAP_REST_HEAL_FRACTION of max HP, on the line back to full.
static func rest_heal_amount(run: RunState) -> int:
	if not at_stop(run, RunState.StopType.REST):
		return 0
	var player := run.player
	if run.route != null:
		return mini(player.max_hp - player.hp, roundi(player.max_hp * RunState.MAP_REST_HEAL_FRACTION))
	return player.max_hp - player.hp


## See RunState.current_beat.
static func current_beat(run: RunState) -> StoryBeat:
	if not at_stop(run, RunState.StopType.STORY):
		return null
	return StoryContent.beat(run.current_stop().beat_index, run.character.id, run.chapter)


## See RunState.read_story.
static func read_story(run: RunState) -> bool:
	if not at_stop(run, RunState.StopType.STORY):
		return false
	run.advance_stop()
	return true


## See RunState.rest_number.
static func rest_number(run: RunState) -> int:
	var stop := run.current_stop()
	if stop == null or stop.type != RunState.StopType.REST:
		return 0
	var count := 0
	if run.route != null:
		for id in run.visited:
			if run.route.node(id).type == RouteMap.NodeType.REST:
				count += 1
		return count
	for i in run.stop_index + 1:
		if run.stops[i].type == RunState.StopType.REST:
			count += 1
	return count


## The line, 22 stops in two acts (a train line in the original theme, a memorial city since v0.5.0): four regular fights, the Brakeman (now Bellkeeper) halfway (stop 9), four
## harder fights, then the Conductor (now Eraser). Three vendors, five rests (the last just before the finale) and the four story beats in order.
## Tier (act) and fight number are filled in here; see docs/LEVELS_DESIGN.md.
static func default_line() -> Array[Stop]:
	var line: Array[Stop] = [
		Stop.new(RunState.StopType.STORY, 0, 0).place("Shore of Names", &"", &"coastal"),
		Stop.new(RunState.StopType.COMBAT, 1).place("Drowned Street", &"battle_street"),
		Stop.new(RunState.StopType.COMBAT, 2).place("Laundry Court", &"battle_street"),
		Stop.new(RunState.StopType.REST).place("Lampkeeper's Kitchen"),
		Stop.new(RunState.StopType.COMBAT, 2).place("Empty Tenements", &"battle_street"),
		Stop.new(RunState.StopType.VENDOR).place("The Lost-Property Stall"),
		Stop.new(RunState.StopType.COMBAT, 2).place("Petition Steps", &"battle_street"),
		Stop.new(RunState.StopType.STORY, 0, 1).place("The Unanswered Hall"),
		Stop.new(RunState.StopType.REST).place("Caretaker's Alcove"),
		Stop.new(RunState.StopType.COMBAT, 1, 0, false, true).place("The Bell Court", &"battle_bell_court"),
		Stop.new(RunState.StopType.STORY, 0, 2).place("Garden of Unmarked Stones"),
		Stop.new(RunState.StopType.REST).place("Glasshouse Shelter"),
		Stop.new(RunState.StopType.COMBAT, 2).place("Processional Garden", &"battle_garden"),
		Stop.new(RunState.StopType.COMBAT, 3).place("The Listening Marsh", &"battle_garden"),
		Stop.new(RunState.StopType.VENDOR).place("The Bone Orchard Market"),
		Stop.new(RunState.StopType.REST).place("Candlehouse"),
		Stop.new(RunState.StopType.COMBAT, 2).place("The Name Vault", &"battle_archive"),
		Stop.new(RunState.StopType.COMBAT, 3).place("The Unwritten Causeway", &"battle_archive"),
		Stop.new(RunState.StopType.VENDOR).place("Last Keepsake Stall"),
		Stop.new(RunState.StopType.REST).place("The Last Hearth"),
		Stop.new(RunState.StopType.STORY, 0, 3).place("The Breathing Door"),
		Stop.new(RunState.StopType.COMBAT, 1, 0, true).place("The Threshold", &"battle_threshold"),
	]
	var tier := 0
	var fight := 0
	for stop in line:
		stop.tier = tier
		if stop.type == RunState.StopType.COMBAT and not stop.boss and not stop.mid_boss:
			stop.fight = fight
			fight += 1
		if stop.mid_boss:
			tier = 1
	return line


## See RunState.rarity_tier: how far into the run the player is, 0 to 3, a quarter of the stop line each.
static func rarity_tier(run: RunState) -> int:
	if run.stops.is_empty():
		return 0
	return clampi(run.stop_index * StarterContent.RARITY_WEIGHTS.size() / run.stops.size(), 0, StarterContent.RARITY_WEIGHTS.size() - 1)
