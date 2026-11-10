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
## --map plays the route map; --route picks the route strategy (tools/route_policy.gd), orthogonal to --policy,
## and --map adds summary lines (confidence interval, deaths by act and row band, visits, HP at the bosses).
## --character all plays the four classes in one invocation. --jobs N splits the runs over N child processes
## (each plays the runs whose index mod N is its shard, `--shard i/N`, and writes its raw tallies to --shard-out;
## the parent merges them, so the report equals the single-process one for the same seed).

const DEFAULT_RUNS := 300
## Run i of base seed S uses seed S * SEED_STRIDE + i, so two base seeds never share a run seed as long as
## --runs stays below SEED_STRIDE (MAX_RUNS enforces it).
const SEED_STRIDE := 1000003
const MAX_RUNS := 1000000
const DEFAULT_SEED := 1
const POLICIES: Array[String] = ["greedy", "smart"]
const ALL_CHARACTERS := "all"
## Row bands of the death summary (a map has 30 rows).
const BAND_ROWS := 5
const USAGE := "Usage: godot --headless --path . -s res://tools/run_sim.gd -- [--runs N] [--seed S] [--policy P] [--character C] [--map] [--route R] [--jobs N] [--card-stats] [--help]\n  --runs N    number of whole runs, integer 1 to 1000000 (default 300)\n  --seed S    base random seed, integer (default 1)\n  --policy P  greedy (default) or smart (stronger lookahead player)\n  --character C  deserter (default), thief, medium, stray, or all (the four classes, one report each)\n  --map      play runs in map mode (default route: first node for greedy; the smart rules for smart) and print extra summary lines\n  --route R  map mode route strategy: first, fighter, cautious, mixed, random or smart (needs --map)\n  --jobs N   run the sim in N parallel processes and merge the results (default 1)\n  --card-stats  also print how often each card was played and held\n  --help     print this usage and exit 0"

var _smart := false
var _map := false
var _route := ""
var _card_stats := false
var _plays := {} # card id -> times played across all runs
var _held := {} # card id -> runs whose deck held at least one copy when the run ended
var _character: StringName = StarterContent.DEFAULT_CHARACTER_ID


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
	var runs: int = opts["runs"]
	var base_seed: int = opts["seed"]
	_smart = opts["policy"] == "smart"
	_map = opts["map"]
	_route = opts["route"] if opts["route"] != "" else (RoutePolicy.SMART if _smart else RoutePolicy.FIRST)
	_card_stats = opts["card_stats"]
	var characters: Array[StringName] = []
	if opts["character"] == ALL_CHARACTERS:
		characters = StarterContent.character_ids()
	else:
		characters.append(StringName(opts["character"]))

	if opts["shard_count"] > 0:
		# A child of --jobs: play this shard's runs and write the raw tallies for the parent to merge.
		_character = characters[0]
		var shard_stats := _simulate(runs, base_seed, opts["shard_index"], opts["shard_count"])
		if shard_stats.is_empty():
			quit(1)
			return
		var file := FileAccess.open(opts["shard_out"], FileAccess.WRITE)
		if file == null:
			printerr("run_sim: cannot write the shard file %s" % opts["shard_out"])
			quit(1)
			return
		file.store_string(var_to_str(shard_stats))
		file.close()
		quit(0)
		return

	var merged := {}
	if opts["jobs"] > 1:
		merged = _run_parallel(opts, characters)
		if merged.is_empty():
			quit(1)
			return
	for index in characters.size():
		_character = characters[index]
		var stats: Dictionary
		if opts["jobs"] > 1:
			stats = merged[_character]
		else:
			stats = _simulate(runs, base_seed, 0, 1)
			if stats.is_empty():
				quit(1)
				return
		if index > 0:
			print("")
		_report(stats, runs, base_seed)
	quit(0)


## Plays the runs whose index mod `shard_count` is `shard_index` for `_character` and returns the raw tallies
## (everything the report needs, as sums, so shards add up). An empty dictionary after printing why on failure.
func _simulate(runs: int, base_seed: int, shard_index: int, shard_count: int) -> Dictionary:
	_plays = {}
	_held = {}
	var events_played := 0
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
	var visits := {} # node type name -> nodes of that type visited, over all runs (map mode)
	var fights := 0 # fight and elite nodes visited (map mode)
	var enemies := 0 # enemies in those fights
	var runs_with_elite := 0 # runs that fought at least one elite (map mode)
	var escapes_with_elite := 0 # of those, the runs that escaped
	var gold_end := 0
	var relics_end := 0
	var runs_played := 0
	for i in runs:
		if i % shard_count != shard_index:
			continue
		runs_played += 1
		var run := RunState.new(base_seed * SEED_STRIDE + i, _character, _map)
		if run.stops.is_empty():
			printerr("run_sim: run has no stops")
			return {}
		var stalled := false
		var last_desc := ""
		while not run.finished:
			var index := run.stop_index
			var stop := run.current_stop()
			if stop == null:
				# Map mode between stops: pick the next node.
				var pick := SmartPolicy.choose_route(run, _route) if _smart else SimPolicy.choose_route(run, _route)
				if not run.choose_node(pick):
					printerr("run_sim: no reachable node to choose after row %d" % index)
					return {}
				continue
			last_desc = stop.describe()
			stop_desc[index] = "(by route)" if _map else last_desc
			var tally: Array = entering.get(index, [0, 0])
			tally[0] += 1
			tally[1] += run.player.hp
			entering[index] = tally
			match stop.type:
				RunState.StopType.COMBAT:
					var result := _play_combat(run)
					if result == SimPolicy.FIGHT_FAILED:
						return {}
					if result == 0:
						stalls += 1
						stalled = true
					# A rejected result would leave the run at this stop forever.
					if not run.complete_combat(result == 1):
						printerr("run_sim: complete_combat rejected the result at stop %d" % index)
						return {}
					# A boss win has no reward to take.
					if result == 1 and run.reward_pending() and not _take_reward(run):
						return {}
				RunState.StopType.REST:
					if not SimPolicy.rest_stop(run, _smart):
						printerr("run_sim: rest() failed at stop %d" % index)
						return {}
				RunState.StopType.STORY:
					if not run.read_story():
						printerr("run_sim: read_story() failed at stop %d" % index)
						return {}
				RunState.StopType.VENDOR:
					if not _shop(run):
						return {}
				RunState.StopType.TREASURE:
					if not SimPolicy.treasure_stop(run):
						printerr("run_sim: the chest could not be opened and taken at stop %d" % index)
						return {}
				RunState.StopType.EVENT:
					if not (SmartPolicy.event_stop(run) if _smart else SimPolicy.event_stop(run)):
						printerr("run_sim: the event could not be settled at stop %d" % index)
						return {}
					events_played += 1
				_:
					# RunState has no public way to pass a stop of another type.
					printerr("run_sim: unsupported stop type %d at stop %d (%s)" % [stop.type, index, stop.describe()])
					return {}
		if SimPolicy.failure_count() > 0:
			printerr("run_sim: %d bot error(s) and %d engine error(s) were logged (run %d); the result would be wrong" % [SimPolicy.bot_errors, Combat.engine_errors, i])
			return {}
		if not run.relics.is_empty():
			runs_with_relics += 1
			if run.escaped:
				escapes_with_relics += 1
		for relic in run.relics:
			relics_bought[relic.id] = relics_bought.get(relic.id, 0) + 1
		var seen := {}
		for card in run.deck:
			if not seen.has(card.id):
				seen[card.id] = true
				_held[card.id] = _held.get(card.id, 0) + 1
		heals_used += 1 if run.reward_heal_used else 0
		removes_used += 1 if run.reward_remove_used else 0
		gold_end += run.gold
		relics_end += run.relics.size()
		if _map:
			var met_elite := false
			for id in run.visited:
				var node := run.route.node(id)
				var type_name: String = RouteMap.NodeType.keys()[node.type]
				visits[type_name] = visits.get(type_name, 0) + 1
				met_elite = met_elite or node.type == RouteMap.NodeType.ELITE
				if node.type == RouteMap.NodeType.FIGHT or node.type == RouteMap.NodeType.ELITE:
					fights += 1
					enemies += node.enemy_count
					var count_key := "FIGHT_%d" % node.enemy_count
					visits[count_key] = visits.get(count_key, 0) + 1
			if met_elite:
				runs_with_elite += 1
				escapes_with_elite += 1 if run.escaped else 0
		if run.escaped:
			escapes += 1
			escape_hp += run.player.hp
			escape_deck += run.deck.size()
		elif not stalled:
			deaths_at[run.stop_index] = deaths_at.get(run.stop_index, 0) + 1
			var desc: String = last_desc
			deaths_by_desc[desc] = deaths_by_desc.get(desc, 0) + 1
	return {
		"runs": runs_played, "events_played": events_played, "escapes": escapes, "heals_used": heals_used,
		"removes_used": removes_used, "stalls": stalls, "runs_with_relics": runs_with_relics,
		"escapes_with_relics": escapes_with_relics, "relics_bought": relics_bought, "escape_hp": escape_hp,
		"escape_deck": escape_deck, "deaths_at": deaths_at, "deaths_by_desc": deaths_by_desc,
		"entering": entering, "stop_desc": stop_desc, "visits": visits, "fights": fights, "enemies": enemies,
		"runs_with_elite": runs_with_elite, "escapes_with_elite": escapes_with_elite, "gold_end": gold_end, "relics_end": relics_end, "plays": _plays, "held": _held,
	}


## Prints the report for `_character` from the (merged) tallies of `runs` runs. The first block is the legacy
## report line for line; --map appends its extra summary after it.
func _report(stats: Dictionary, runs: int, base_seed: int) -> void:
	var escapes: int = stats["escapes"]
	var escapes_with_relics: int = stats["escapes_with_relics"]
	var runs_with_relics: int = stats["runs_with_relics"]
	var relics_bought: Dictionary = stats["relics_bought"]
	var deaths_at: Dictionary = stats["deaths_at"]
	var deaths_by_desc: Dictionary = stats["deaths_by_desc"]
	var entering: Dictionary = stats["entering"]
	var stop_desc: Dictionary = stats["stop_desc"]
	var start_hp := StarterContent.character(_character).max_hp
	print("Run sim: %d runs, seed %d, character %s, policy %s, player HP %d, turn cap %d%s" % [runs, base_seed, _character, "smart" if _smart else "greedy", start_hp, SimPolicy.TURN_CAP, ", map mode" if _map else ""])
	print("Escape rate: %d/%d (%.1f%%)" % [escapes, runs, 100.0 * escapes / runs])
	print("Free reward alternatives used: Heal in %d/%d runs, Remove in %d/%d runs" % [stats["heals_used"], runs, stats["removes_used"], runs])
	print("Runs that bought a relic: %d/%d (escape rate with a relic %s, without %s)" % [runs_with_relics, runs, _rate(escapes_with_relics, runs_with_relics), _rate(escapes - escapes_with_relics, runs - runs_with_relics)])
	# Sorted as text: StringName keys sort by internal id, which differs from one process to the next.
	var relic_ids: Array[String] = []
	for id: StringName in relics_bought:
		relic_ids.append(String(id))
	relic_ids.sort()
	for id in relic_ids:
		print("  relic %-18s held at the end of %d runs" % [id, relics_bought[StringName(id)]])
	print("Stalls (fight abandoned at turn cap, run counted lost): %d" % stats["stalls"])
	if _map:
		print("Events played: %d (%.2f per run)" % [stats["events_played"], float(stats["events_played"]) / runs])
	if escapes > 0:
		print("On escapes: avg final HP %.2f, avg deck size %.2f" % [float(stats["escape_hp"]) / escapes, float(stats["escape_deck"]) / escapes])
	else:
		print("On escapes: n/a")
	print("")
	print("Per stop (deaths = runs that died there; avg HP is on arrival)")
	print("%-5s %-18s %8s %7s %8s %12s" % ["stop", "description", "reached", "deaths", "loss %", "avg HP in"])
	var indices: Array = entering.keys()
	indices.sort()
	for index: int in indices:
		var tally: Array = entering[index]
		var deaths: int = deaths_at.get(index, 0)
		print("%-5d %-18s %8d %7d %7.1f%% %12.2f" % [index, stop_desc[index], tally[0], deaths, 100.0 * deaths / tally[0], float(tally[1]) / tally[0]])
	print("")
	print("Deaths by stop description")
	var descs: Array = deaths_by_desc.keys()
	descs.sort()
	if descs.is_empty():
		print("none")
	for desc: String in descs:
		print("%-18s %7d (%.1f%% of runs)" % [desc, deaths_by_desc[desc], 100.0 * deaths_by_desc[desc] / runs])
	if _card_stats:
		var plays: Dictionary = stats["plays"]
		var held_runs: Dictionary = stats["held"]
		print("")
		print("Card plays per run (a card never played shows 0.00), share of runs whose final deck held it, plays per run that held it")
		var played: Array = []
		for card in StarterContent.vendor_pool(_character):
			played.append([card.id, plays.get(card.id, 0)])
		played.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1])
		for entry: Array in played:
			var held: int = held_runs.get(entry[0], 0)
			print("%-18s %6.2f %7.1f%% %8.2f" % [entry[0], float(entry[1]) / runs, 100.0 * held / runs, float(entry[1]) / maxi(held, 1)])
	if _map:
		_report_map(stats, runs)


## Elite lines of the --map block: how lethal an elite visit is against a regular fight visit, the share of all deaths
## that happen on an elite, and the escape rate of the runs that fought an elite against the runs that did not.
func _report_elites(stats: Dictionary, runs: int) -> void:
	var visits: Dictionary = stats["visits"]
	var by_desc: Dictionary = stats["deaths_by_desc"]
	var elite_deaths := 0
	var fight_deaths := 0
	var all_deaths := 0
	for desc: String in by_desc:
		all_deaths += by_desc[desc]
		if desc.begins_with("Elite"):
			elite_deaths += by_desc[desc]
		elif desc.begins_with("Combat"):
			fight_deaths += by_desc[desc]
	var elite_visits: int = visits.get("ELITE", 0)
	var fight_visits: int = visits.get("FIGHT", 0)
	print("Elite lethality: %s of elite visits end the run, %s of regular fight visits; %s of all deaths happen on an elite" % [
		_rate(elite_deaths, elite_visits), _rate(fight_deaths, fight_visits), _rate(elite_deaths, all_deaths)])
	var with_elite: int = stats.get("runs_with_elite", 0)
	var esc_with: int = stats.get("escapes_with_elite", 0)
	print("Runs that fought an elite: %d/%d (escape rate %s, runs that fought none %s)" % [with_elite, runs, _rate(esc_with, with_elite), _rate(stats["escapes"] - esc_with, runs - with_elite)])


## The extra --map block: route strategy, escape-rate interval, deaths by act and row band, HP at the bosses,
## visits per run, what the run holds at the end and the size of the fights.
func _report_map(stats: Dictionary, runs: int) -> void:
	var deaths_at: Dictionary = stats["deaths_at"]
	var entering: Dictionary = stats["entering"]
	var visits: Dictionary = stats["visits"]
	var interval := wilson_interval(stats["escapes"], runs)
	print("")
	print("Map summary (route strategy %s)" % _route)
	print("Escape rate 95%% CI (Wilson): %.1f%% to %.1f%%" % [100.0 * interval[0], 100.0 * interval[1]])
	var by_act: Array[int] = []
	by_act.resize(RouteMap.ACTS)
	by_act.fill(0)
	var band_count := RouteMap.ROWS / BAND_ROWS
	var by_band: Array[int] = []
	by_band.resize(band_count)
	by_band.fill(0)
	for row: int in deaths_at:
		by_act[clampi(row / RouteMap.ACT_ROWS, 0, RouteMap.ACTS - 1)] += deaths_at[row]
		by_band[clampi(row / BAND_ROWS, 0, band_count - 1)] += deaths_at[row]
	var acts: PackedStringArray = []
	for act in RouteMap.ACTS:
		acts.append("act %d %d (%.1f%%)" % [act + 1, by_act[act], 100.0 * by_act[act] / runs])
	print("Deaths by act: %s" % ", ".join(acts))
	var bands: PackedStringArray = []
	for band in band_count:
		bands.append("rows %d-%d %d" % [band * BAND_ROWS, band * BAND_ROWS + BAND_ROWS - 1, by_band[band]])
	print("Deaths by row band: %s" % ", ".join(bands))
	var mid_row := RouteMap.BOSS_LOCAL_ROW
	var final_row := RouteMap.ROWS - 1
	print("Mean HP on arrival at the mid-boss: %s (%d runs reached it), at the final boss: %s (%d runs reached it)" % [_mean_hp(entering, mid_row), _reached(entering, mid_row), _mean_hp(entering, final_row), _reached(entering, final_row)])
	print("Visits per run: fights %.2f, elites %.2f, rests %.2f, shops %.2f, chests %.2f, events %.2f" % [
		float(visits.get("FIGHT", 0)) / runs, float(visits.get("ELITE", 0)) / runs, float(visits.get("REST", 0)) / runs,
		float(visits.get("SHOP", 0)) / runs, float(visits.get("TREASURE", 0)) / runs, float(visits.get("EVENT", 0)) / runs])
	print("Held at the end: gold %.2f, relics %.2f (averages per run)" % [float(stats["gold_end"]) / runs, float(stats["relics_end"]) / runs])
	_report_elites(stats, runs)
	print("Enemies per fight: %s (over fights and elites visited)" % ("n/a" if stats["fights"] == 0 else "%.2f" % (float(stats["enemies"]) / stats["fights"])))
	print("Fights visited by enemy count: 1 enemy %d, 2 enemies %d, 3 enemies %d (the last one of a lost run included)" % [visits.get("FIGHT_1", 0), visits.get("FIGHT_2", 0), visits.get("FIGHT_3", 0)])


## The 95% Wilson score interval [low, high] (shares, 0 to 1) of `successes` out of `trials`.
static func wilson_interval(successes: int, trials: int) -> Array[float]:
	var result: Array[float] = [0.0, 1.0]
	if trials <= 0:
		return result
	var z := 1.96
	var n := float(trials)
	var p := successes / n
	var denom := 1.0 + z * z / n
	var centre := (p + z * z / (2.0 * n)) / denom
	var half := z * sqrt(p * (1.0 - p) / n + z * z / (4.0 * n * n)) / denom
	result[0] = maxf(0.0, centre - half)
	result[1] = minf(1.0, centre + half)
	return result


static func _reached(entering: Dictionary, row: int) -> int:
	return int(entering[row][0]) if entering.has(row) else 0


static func _mean_hp(entering: Dictionary, row: int) -> String:
	if not entering.has(row):
		return "n/a"
	return "%.2f" % (float(entering[row][1]) / entering[row][0])


static func _rate(part: int, whole: int) -> String:
	return "n/a" if whole == 0 else "%.1f%%" % (100.0 * part / whole)


# --- Parallel runs ------------------------------------------------------------------------------------------

## Runs every character's shards in child processes, at most opts["jobs"] at a time, and returns
## {character id: merged tallies}. An empty dictionary after printing why on failure.
func _run_parallel(opts: Dictionary, characters: Array[StringName]) -> Dictionary:
	var jobs: int = opts["jobs"]
	var shards := mini(jobs, opts["runs"])
	var dir := OS.get_user_data_dir().path_join("sim_shards")
	DirAccess.make_dir_recursive_absolute(dir)
	var token := "%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	var queue: Array[Dictionary] = []
	for character in characters:
		for shard in shards:
			queue.append({"character": character, "shard": shard, "file": dir.path_join("%s_%s_%d.txt" % [token, character, shard]), "pid": -1})
	var running: Array[Dictionary] = []
	var next := 0
	while next < queue.size() or not running.is_empty():
		while next < queue.size() and running.size() < jobs:
			var job := queue[next]
			next += 1
			var child_args := PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"), "-s", "res://tools/run_sim.gd", "--",
				"--runs", str(opts["runs"]), "--seed", str(opts["seed"]), "--policy", opts["policy"], "--character", str(job["character"]),
				"--shard", "%d/%d" % [job["shard"], shards], "--shard-out", job["file"]])
			if opts["map"]:
				child_args.append("--map")
				child_args.append_array(["--route", _route])
			if opts["card_stats"]:
				child_args.append("--card-stats")
			job["pid"] = OS.create_process(OS.get_executable_path(), child_args)
			if job["pid"] <= 0:
				printerr("run_sim: could not start a child process")
				return {}
			running.append(job)
		OS.delay_msec(50)
		for job in running.duplicate():
			if not OS.is_process_running(job["pid"]):
				running.erase(job)
	var merged := {}
	for job in queue:
		if not FileAccess.file_exists(job["file"]):
			printerr("run_sim: shard %d of %s produced no result (rerun without --jobs to see the error)" % [job["shard"], job["character"]])
			return {}
		var part: Variant = str_to_var(FileAccess.get_file_as_string(job["file"]))
		DirAccess.remove_absolute(job["file"])
		if not part is Dictionary:
			printerr("run_sim: shard %d of %s wrote an unreadable result" % [job["shard"], job["character"]])
			return {}
		if not merged.has(job["character"]):
			merged[job["character"]] = part
		else:
			merge_tallies(merged[job["character"]], part)
	return merged


## Adds the tallies `other` into `into`: numbers and array slots add, dictionaries merge key by key, text stays.
static func merge_tallies(into: Dictionary, other: Dictionary) -> void:
	for key in other:
		var value: Variant = other[key]
		if not into.has(key):
			into[key] = value.duplicate(true) if value is Dictionary or value is Array else value
		elif value is Dictionary:
			merge_tallies(into[key], value)
		elif value is Array:
			for slot in value.size():
				into[key][slot] += value[slot]
		elif value is int or value is float:
			into[key] += value


## Returns the options (every key of the usage text) or an empty dictionary (after printing why) on bad input.
func _parse_args(args: PackedStringArray) -> Dictionary:
	var opts := {"runs": DEFAULT_RUNS, "seed": DEFAULT_SEED, "policy": "greedy", "character": String(StarterContent.DEFAULT_CHARACTER_ID), "card_stats": false, "map": false, "route": "", "jobs": 1, "shard_index": 0, "shard_count": 0, "shard_out": ""}
	var i := 0
	while i < args.size():
		var name := args[i]
		if name == "--card-stats":
			opts["card_stats"] = true
			i += 1
			continue
		if name == "--map":
			opts["map"] = true
			i += 1
			continue
		if name != "--runs" and name != "--seed" and name != "--policy" and name != "--character" and name != "--route" and name != "--jobs" and name != "--shard" and name != "--shard-out":
			printerr("run_sim: unknown argument '%s'\n%s" % [name, USAGE])
			return {}
		if name == "--character":
			if i + 1 >= args.size() or not (args[i + 1] == ALL_CHARACTERS or StarterContent.CHARACTER_PATHS.has(StringName(args[i + 1]))):
				printerr("run_sim: --character must be one of %s, %s\n%s" % [", ".join(StarterContent.character_ids()), ALL_CHARACTERS, USAGE])
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
		if name == "--route":
			if i + 1 >= args.size() or not args[i + 1] in RoutePolicy.ROUTES:
				printerr("run_sim: --route must be one of %s\n%s" % [", ".join(RoutePolicy.ROUTES), USAGE])
				return {}
			opts["route"] = args[i + 1]
			i += 2
			continue
		if name == "--shard":
			var parts := args[i + 1].split("/") if i + 1 < args.size() else PackedStringArray()
			if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int() or parts[1].to_int() < 1 or parts[0].to_int() < 0 or parts[0].to_int() >= parts[1].to_int():
				printerr("run_sim: --shard needs i/N with 0 <= i < N\n%s" % USAGE)
				return {}
			opts["shard_index"] = parts[0].to_int()
			opts["shard_count"] = parts[1].to_int()
			i += 2
			continue
		if name == "--shard-out":
			if i + 1 >= args.size():
				printerr("run_sim: --shard-out needs a file path\n%s" % USAGE)
				return {}
			opts["shard_out"] = args[i + 1]
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
		elif name == "--jobs":
			if value < 1:
				printerr("run_sim: --jobs must be >= 1\n%s" % USAGE)
				return {}
			opts["jobs"] = value
		else:
			opts["seed"] = value
		i += 2
	if opts["route"] != "" and not opts["map"]:
		printerr("run_sim: --route needs --map\n%s" % USAGE)
		return {}
	if opts["shard_count"] > 0 and (opts["shard_out"] == "" or opts["character"] == ALL_CHARACTERS):
		printerr("run_sim: --shard needs --shard-out and a single --character\n%s" % USAGE)
		return {}
	return opts


## Plays the current combat stop with SimPolicy.run_fight. Returns 1 win, -1 loss, 0 stall or SimPolicy.FIGHT_FAILED.
func _play_combat(run: RunState) -> int:
	var combat := run.start_combat()
	if combat == null:
		return SimPolicy.FIGHT_FAILED
	if _card_stats:
		combat.card_played.connect(func(card: CardData, _targets: Array[EnemyUnit]) -> void: _plays[card.id] = _plays.get(card.id, 0) + 1)
	return SimPolicy.run_fight(combat, SmartPolicy.play_turn if _smart else SimPolicy.play_turn)


## Takes the best offered card per the header heuristic. False on a RunState failure.
func _take_reward(run: RunState) -> bool:
	if _smart:
		# A null pick skips the reward; the policy may also use a free Heal or Remove instead.
		if not SmartPolicy.take_reward(run):
			printerr("run_sim: the run rejected the smart policy's reward choice")
			return false
		return true
	if not SimPolicy.take_elite_spoils(run):
		printerr("run_sim: the elite spoils could not be taken")
		return false
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
