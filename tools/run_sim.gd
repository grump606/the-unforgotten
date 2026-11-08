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

const TURN_CAP := 50 # a fight still running after this many turns is a stall
const DEFAULT_RUNS := 300
const DEFAULT_SEED := 1
const POLICIES: Array[String] = ["greedy", "smart"]
const USAGE := "Usage: godot --headless --path . -s res://tools/run_sim.gd -- [--runs N] [--seed S] [--policy P] [--character C] [--help]\n  --runs N    number of whole runs, integer >= 1 (default 300)\n  --seed S    base random seed, integer (default 1)\n  --policy P  greedy (default) or smart (stronger lookahead player)\n  --character C  deserter (default), thief, medium or stray\n  --help     print this usage and exit 0"

var _smart := false
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
	_character = StringName(opts["character"])
	_card_stats = opts["card_stats"]

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
	for i in runs:
		var run := RunState.new(base_seed * 1000003 + i, _character)
		if run.stops.is_empty():
			printerr("run_sim: run has no stops")
			quit(1)
			return
		var stalled := false
		while not run.finished:
			var index := run.stop_index
			var stop := run.current_stop()
			stop_desc[index] = stop.describe()
			var tally: Array = entering.get(index, [0, 0])
			tally[0] += 1
			tally[1] += run.player.hp
			entering[index] = tally
			match stop.type:
				RunState.StopType.COMBAT:
					var result := _play_combat(run)
					if result == -2:
						quit(1)
						return
					if result == 0:
						stalls += 1
						stalled = true
						run.complete_combat(false)
					else:
						run.complete_combat(result == 1)
						# A boss win has no reward to take.
						if result == 1 and run.reward_pending() and not _take_reward(run):
							quit(1)
							return
				RunState.StopType.REST:
					if not SimPolicy.rest_stop(run, _smart):
						printerr("run_sim: rest() failed at stop %d" % index)
						quit(1)
						return
				RunState.StopType.STORY:
					if not run.read_story():
						printerr("run_sim: read_story() failed at stop %d" % index)
						quit(1)
						return
				RunState.StopType.VENDOR:
					if not _shop(run):
						quit(1)
						return
				_:
					# RunState has no public way to pass a stop of another type.
					printerr("run_sim: unsupported stop type %d at stop %d (%s)" % [stop.type, index, stop.describe()])
					quit(1)
					return
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
		if run.escaped:
			escapes += 1
			escape_hp += run.player.hp
			escape_deck += run.deck.size()
		elif not stalled:
			deaths_at[run.stop_index] = deaths_at.get(run.stop_index, 0) + 1
			var desc: String = stop_desc[run.stop_index]
			deaths_by_desc[desc] = deaths_by_desc.get(desc, 0) + 1

	var start_hp := StarterContent.character(_character).max_hp
	print("Run sim: %d runs, seed %d, character %s, policy %s, player HP %d, turn cap %d" % [runs, base_seed, _character, "smart" if _smart else "greedy", start_hp, TURN_CAP])
	print("Escape rate: %d/%d (%.1f%%)" % [escapes, runs, 100.0 * escapes / runs])
	print("Free reward alternatives used: Heal in %d/%d runs, Remove in %d/%d runs" % [heals_used, runs, removes_used, runs])
	print("Runs that bought a relic: %d/%d (escape rate with a relic %s, without %s)" % [runs_with_relics, runs, _rate(escapes_with_relics, runs_with_relics), _rate(escapes - escapes_with_relics, runs - runs_with_relics)])
	var relic_ids: Array = relics_bought.keys()
	# By name: StringName order is by address, which shifts with the order names were first seen.
	relic_ids.sort_custom(func(x: StringName, y: StringName) -> bool: return String(x) < String(y))
	for id: StringName in relic_ids:
		print("  relic %-18s held at the end of %d runs" % [id, relics_bought[id]])
	print("Stalls (fight abandoned at turn cap, run counted lost): %d" % stalls)
	if escapes > 0:
		print("On escapes: avg final HP %.2f, avg deck size %.2f" % [float(escape_hp) / escapes, float(escape_deck) / escapes])
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
		print("")
		print("Card plays per run (a card never played shows 0.00), share of runs whose final deck held it, plays per run that held it")
		var played: Array = []
		for card in StarterContent.vendor_pool(_character):
			played.append([card.id, _plays.get(card.id, 0)])
		played.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1])
		for entry: Array in played:
			var held: int = _held.get(entry[0], 0)
			print("%-18s %6.2f %7.1f%% %8.2f" % [entry[0], float(entry[1]) / runs, 100.0 * held / runs, float(entry[1]) / maxi(held, 1)])
	quit(0)


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
				printerr("run_sim: --character must be one of %s
%s" % [", ".join(StarterContent.character_ids()), USAGE])
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
			if value < 1:
				printerr("run_sim: --runs must be >= 1\n%s" % USAGE)
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
		if combat.turn > TURN_CAP:
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
	var vendor := run.vendor()
	if vendor == null:
		printerr("run_sim: no vendor at a vendor stop")
		return false
	if run.player.max_hp - run.player.hp >= Vendor.HEAL_AMOUNT / 2:
		run.vendor_buy_heal()
	if not SimPolicy.buy_relic(run):
		return false
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
