extends SceneTree
## Headless run simulation: plays many whole seeded runs through RunState and
## reports how winnable a run is (escape rate, where runs die, HP and deck size).
## Run: godot --headless --path . -s res://tools/run_sim.gd -- --runs 300 --seed 1
## Combat uses the shared greedy policy in tools/sim_policy.gd. Reward heuristic:
## never skip; take the offered card that best fills what the deck lacks, scoring
## a damage effect 1/(1+damage cards in deck) and a block effect 1/(1+block cards
## in deck), minus 0.001 per energy cost to prefer cheaper cards; first offered
## wins ties. Uses only the public RunState and Combat APIs.
## --policy smart swaps in tools/smart_policy.gd (lookahead combat scoring, deck-
## composition reward/vendor scoring with skips and card removal); see its header.
## The default, --policy greedy, is the behaviour described above.

const DEFAULT_RUNS := 300
## Run i of base seed S uses seed S * SEED_STRIDE + i, so two base seeds never share a run seed as long as
## --runs stays below SEED_STRIDE (MAX_RUNS enforces it).
const SEED_STRIDE := 1000003
const MAX_RUNS := 1000000
const DEFAULT_SEED := 1
const POLICIES: Array[String] = ["greedy", "smart"]
const USAGE := "Usage: godot --headless --path . -s res://tools/run_sim.gd -- [--runs N] [--seed S] [--policy P] [--character C] [--card-stats] [--help]\n  --runs N    number of whole runs, integer 1 to 1000000 (default 300)\n  --seed S    base random seed, integer (default 1)\n  --policy P  greedy (default) or smart (stronger lookahead player)\n  --card-stats  also print per-card play counts and how many runs held each card\n  --character C  deserter (default), thief, medium or stray\n  --help     print this usage and exit 0"

var _smart := false
var _card_stats := false
var _plays := {} # card id -> times played across all runs
var _held := {} # card id -> runs whose deck held at least one copy when the run ended
var _character: StringName = StarterContent.DEFAULT_CHARACTER_ID


## What the whole simulation counts, filled by _play_all and read by _print_report.
class Stats extends RefCounted:
	var escapes := 0
	var heals_used := 0
	var removes_used := 0
	var stalls := 0
	var runs_with_relics := 0
	var escapes_with_relics := 0
	var relics_bought := {} # relic id -> runs that ended holding it
	var escape_hp := 0
	var escape_deck := 0
	var deaths_at := {} # stop index -> deaths
	var deaths_by_desc := {} # stop description -> deaths
	var entering := {} # stop index -> [runs that reached it, total HP on arrival]
	var stop_desc := {} # stop index -> description
	## Set by _play_run: the run's last fight was abandoned at the turn cap.
	var stalled := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if "--help" in args:
		print(USAGE)
		quit(0)
		return
	var opts := _parse_args(args)
	if opts.is_empty():
		quit(2)
		return
	_smart = opts["policy"] == "smart"
	_character = StringName(opts["character"])
	_card_stats = opts["card_stats"]
	var stats := Stats.new()
	if not _play_all(opts["runs"], opts["seed"], stats):
		quit(1)
		return
	_print_report(opts["runs"], opts["seed"], stats)
	quit(0)


## Plays `runs` whole runs and tallies them. False on an internal failure (already printed).
func _play_all(runs: int, base_seed: int, stats: Stats) -> bool:
	for i in runs:
		var run := RunState.new(base_seed * SEED_STRIDE + i, _character)
		if run.stops.is_empty():
			printerr("run_sim: run has no stops")
			return false
		if not _play_run(run, stats):
			return false
		if SimPolicy.bot_errors > 0:
			printerr("run_sim: the bot logged %d error(s) (run %d); the result would be wrong" % [SimPolicy.bot_errors, i])
			return false
		_tally_run(run, stats)
	return true


## Plays one run to its end, counting arrivals and stalls. False on an internal failure.
func _play_run(run: RunState, stats: Stats) -> bool:
	stats.stalled = false
	while not run.finished:
		var index := run.stop_index
		var stop := run.current_stop()
		stats.stop_desc[index] = stop.describe()
		var tally: Array = stats.entering.get(index, [0, 0])
		tally[0] += 1
		tally[1] += run.player.hp
		stats.entering[index] = tally
		match stop.type:
			RunState.StopType.COMBAT:
				var result := _play_combat(run)
				if result == -2:
					return false
				if result == 0:
					stats.stalls += 1
					stats.stalled = true
					run.complete_combat(false)
				else:
					run.complete_combat(result == 1)
					# A boss win has no reward to take.
					if result == 1 and run.reward_pending() and not _take_reward(run):
						return false
			RunState.StopType.REST:
				if not SimPolicy.rest_stop(run, _smart):
					printerr("run_sim: rest() failed at stop %d" % index)
					return false
			RunState.StopType.STORY:
				if not run.read_story():
					printerr("run_sim: read_story() failed at stop %d" % index)
					return false
			RunState.StopType.VENDOR:
				if not _shop(run):
					return false
			_:
				# RunState has no public way to pass a stop of another type.
				printerr("run_sim: unsupported stop type %d at stop %d (%s)" % [stop.type, index, stop.describe()])
				return false
	return true


## Adds a finished run to the totals.
func _tally_run(run: RunState, stats: Stats) -> void:
	if not run.relics.is_empty():
		stats.runs_with_relics += 1
		if run.escaped:
			stats.escapes_with_relics += 1
	for relic in run.relics:
		stats.relics_bought[relic.id] = stats.relics_bought.get(relic.id, 0) + 1
	var seen := {}
	for card in run.deck:
		if not seen.has(card.id):
			seen[card.id] = true
			_held[card.id] = _held.get(card.id, 0) + 1
	stats.heals_used += 1 if run.reward_heal_used else 0
	stats.removes_used += 1 if run.reward_remove_used else 0
	if run.escaped:
		stats.escapes += 1
		stats.escape_hp += run.player.hp
		stats.escape_deck += run.deck.size()
	elif not stats.stalled:
		stats.deaths_at[run.stop_index] = stats.deaths_at.get(run.stop_index, 0) + 1
		var desc: String = stats.stop_desc[run.stop_index]
		stats.deaths_by_desc[desc] = stats.deaths_by_desc.get(desc, 0) + 1


func _print_report(runs: int, base_seed: int, stats: Stats) -> void:
	var start_hp := StarterContent.character(_character).max_hp
	print("Run sim: %d runs, seed %d, character %s, policy %s, player HP %d, turn cap %d" % [runs, base_seed, _character, "smart" if _smart else "greedy", start_hp, SimPolicy.TURN_CAP])
	print("Escape rate: %d/%d (%.1f%%)" % [stats.escapes, runs, 100.0 * stats.escapes / runs])
	print("Free reward alternatives used: Heal in %d/%d runs, Remove in %d/%d runs" % [stats.heals_used, runs, stats.removes_used, runs])
	print("Runs that bought a relic: %d/%d (escape rate with a relic %s, without %s)" % [stats.runs_with_relics, runs, _rate(stats.escapes_with_relics, stats.runs_with_relics), _rate(stats.escapes - stats.escapes_with_relics, runs - stats.runs_with_relics)])
	var relic_ids: Array = stats.relics_bought.keys()
	# By name: StringName order is by address, which shifts with the order names were first seen.
	relic_ids.sort_custom(func(x: StringName, y: StringName) -> bool: return String(x) < String(y))
	for id: StringName in relic_ids:
		print("  relic %-18s held at the end of %d runs" % [id, stats.relics_bought[id]])
	print("Stalls (fight abandoned at turn cap, run counted lost): %d" % stats.stalls)
	if stats.escapes > 0:
		print("On escapes: avg final HP %.2f, avg deck size %.2f" % [float(stats.escape_hp) / stats.escapes, float(stats.escape_deck) / stats.escapes])
	else:
		print("On escapes: n/a")
	print("")
	print("Per stop (deaths = runs that died there; avg HP is on arrival)")
	print("%-5s %-18s %8s %7s %8s %12s" % ["stop", "description", "reached", "deaths", "loss %", "avg HP in"])
	var indices: Array = stats.entering.keys()
	indices.sort()
	for index: int in indices:
		var tally: Array = stats.entering[index]
		var deaths: int = stats.deaths_at.get(index, 0)
		print("%-5d %-18s %8d %7d %7.1f%% %12.2f" % [index, stats.stop_desc[index], tally[0], deaths, 100.0 * deaths / tally[0], float(tally[1]) / tally[0]])
	print("")
	print("Deaths by stop description")
	var descs: Array = stats.deaths_by_desc.keys()
	descs.sort()
	if descs.is_empty():
		print("none")
	for desc: String in descs:
		print("%-18s %7d (%.1f%% of runs)" % [desc, stats.deaths_by_desc[desc], 100.0 * stats.deaths_by_desc[desc] / runs])
	if _card_stats:
		print("")
		print("Card plays per run (a card never played shows 0.00), share of runs whose final deck held it, plays per run that held it")
		var played: Array = []
		for card in StarterContent.vendor_pool(_character):
			played.append([card.id, _plays.get(card.id, 0)])
		played.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1])
		for entry: Array in played:
			var held: int = _held.get(entry[0], 0)
			print("%-18s %6.2f %7.1f%% %8.2f" % [entry[0], float(entry[1]) / runs, 100.0 * held / runs, float(entry[1]) / maxi(held, 1)])


static func _rate(part: int, whole: int) -> String:
	return "n/a" if whole == 0 else "%.1f%%" % (100.0 * part / whole)


## Returns {runs, seed, policy} or an empty dictionary (after printing usage) on bad input.
func _parse_args(args: PackedStringArray) -> Dictionary:
	var opts := {"runs": DEFAULT_RUNS, "seed": DEFAULT_SEED, "policy": "greedy", "character": String(StarterContent.DEFAULT_CHARACTER_ID), "card_stats": false}
	var i := 0
	while i < args.size():
		var name := args[i]
		if name == "--card-stats":
			opts["card_stats"] = true
			i += 1
			continue
		if name != "--runs" and name != "--seed" and name != "--policy" and name != "--character" and name != "--card-stats":
			printerr("run_sim: unknown argument '%s'\n%s" % [name, USAGE])
			return {}
		if name == "--character":
			if i + 1 >= args.size() or not StarterContent.CHARACTER_PATHS.has(StringName(args[i + 1])):
				printerr("run_sim: --character must be one of %s\n%s" % [", ".join(StarterContent.character_ids()), USAGE])
				return {}
			opts["character"] = args[i + 1]
			i += 2
			continue
		if name == "--policy":
			if i + 1 >= args.size() or not args[i + 1] in POLICIES:
				printerr("run_sim: --policy must be one of %s\n%s" % [", ".join(POLICIES), USAGE])
				return {}
			opts["policy"] = args[i + 1]
			i += 2
			continue
		if i + 1 >= args.size() or not args[i + 1].is_valid_int():
			printerr("run_sim: %s needs an integer value\n%s" % [name, USAGE])
			return {}
		var value := args[i + 1].to_int()
		if name == "--runs":
			if value < 1 or value > MAX_RUNS:
				printerr("run_sim: --runs must be 1 to %d\n%s" % [MAX_RUNS, USAGE])
				return {}
			opts["runs"] = value
		else:
			opts["seed"] = value
		i += 2
	return opts


## Plays the current combat stop. Returns 1 win, -1 loss, 0 stall, -2 internal failure.
func _play_combat(run: RunState) -> int:
	var combat := run.start_combat()
	if combat == null:
		return -2
	var outcome := [0]
	if _card_stats:
		combat.card_played.connect(func(card: CardData, _targets: Array[EnemyUnit]) -> void: _plays[card.id] = _plays.get(card.id, 0) + 1)
	combat.combat_ended.connect(func(victory: bool) -> void: outcome[0] = 1 if victory else -1)
	combat.start()
	while SimPolicy.is_acting(combat):
		if combat.turn > SimPolicy.TURN_CAP:
			combat.abandon()
			return 0
		var played := SmartPolicy.play_turn(combat) if _smart else SimPolicy.play_turn(combat)
		if not played:
			return -2
	return outcome[0]


## Takes the best offered card per the header heuristic. False on a RunState failure.
func _take_reward(run: RunState) -> bool:
	if _smart:
		# A null pick skips the reward; the policy may also use a free Heal or Remove instead.
		if not SmartPolicy.take_reward(run):
			printerr("run_sim: the run rejected the smart policy's reward choice")
			return false
		return true
	var choices := run.reward_choices()
	var best: CardData = null
	var best_score := -INF
	for card in choices:
		var score := _card_score(run, card)
		if score > best_score:
			best_score = score
			best = card
	if best == null:
		printerr("run_sim: no reward choices offered")
		return false
	if not run.resolve_reward(best):
		printerr("run_sim: resolve_reward rejected the chosen card")
		return false
	return true


## How much the deck wants `card`: favours damage or block the deck lacks, with a
## tiny penalty for energy cost. Shared by the reward pick and the vendor.
func _card_score(run: RunState, card: CardData) -> float:
	var damage_cards := 0
	var block_cards := 0
	for owned in run.deck:
		if SimPolicy.is_damage_card(owned):
			damage_cards += 1
		if SimPolicy.is_block_card(owned):
			block_cards += 1
	var score := -0.001 * card.cost
	if SimPolicy.is_damage_card(card):
		score += 1.0 / (1 + damage_cards)
	if SimPolicy.is_block_card(card):
		score += 1.0 / (1 + block_cards)
	return score


## Vendor policy: heal if at least half a heal's worth is missing and it is
## affordable, buy the visit's relic if affordable, then keep buying the best-scoring card it can afford, then leave.
## Never removes cards. False on a RunState failure.
func _shop(run: RunState) -> bool:
	if _smart:
		return SmartPolicy.shop(run)
	if not SimPolicy.shop_basics(run):
		return false
	var vendor := run.vendor()
	while true:
		var best_index := -1
		var best_score := -INF
		var offers := vendor.offers()
		for i in offers.size():
			if offers[i]["sold"] or offers[i]["price"] > run.gold:
				continue
			var score := _card_score(run, offers[i]["card"])
			if score > best_score:
				best_score = score
				best_index = i
		if best_index == -1:
			break
		if not run.vendor_buy_card(best_index).ok:
			printerr("run_sim: vendor refused an affordable card")
			return false
	return run.leave_vendor()
