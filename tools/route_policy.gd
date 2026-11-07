class_name RoutePolicy
extends RefCounted
## Map mode route strategies for the bots (docs/MAP_DESIGN.md, "Phase 4e"). A strategy only answers "which
## reachable node next"; combat, cards, shops and events stay with SimPolicy / SmartPolicy, so any combat policy
## pairs with any route. SimPolicy.choose_route and SmartPolicy.choose_route call `choose`.
##
## Strategies (STRATEGIES):
##   first     the first reachable node (the greedy bot's original behaviour).
##   fighter   the most fight-heavy route: elite, then fight, over everything else; chests are taken; an event
##             only when no fight is reachable; a shop or rest only when nothing else is (the forced rest row).
##   cautious  the safest route: chest, rest, shop, event, then fights from fewest enemies up, elites last.
##   mixed     a human-like route with look-ahead: it scores every path of up to LOOKAHEAD rows from each option on
##             projected HP, gold, chests and events, so it rests when hurt, shops when it has the gold, favours
##             small fights when hurt, always takes chests, takes events while healthy, else fights.
##   random    uniform over the reachable nodes. Seeded from the map's seed and the position on it, so a run's
##             route is reproducible and independent of every other random stream.
##   smart     SmartPolicy's original rules (the smart bot's default): a rest under half HP, a shop from 120 gold,
##             a chest, an event while healthy, else a fight. Lives in SmartPolicy.choose_route; `choose` forwards.
## Every strategy returns -1 only when nothing is reachable, and never an unreachable id.

const FIRST := "first"
const FIGHTER := "fighter"
const CAUTIOUS := "cautious"
const MIXED := "mixed"
const RANDOM := "random"
const SMART := "smart"
## The strategies this class implements itself; `smart` is SmartPolicy's own (see ROUTES).
const STRATEGIES: Array[String] = [FIRST, FIGHTER, CAUTIOUS, MIXED, RANDOM]
## Every name `--route` accepts.
const ROUTES: Array[String] = [FIRST, FIGHTER, CAUTIOUS, MIXED, RANDOM, SMART]

## How many rows `mixed` looks at: the option itself plus the rows after it.
const LOOKAHEAD := 3
## `mixed` rests when HP is below this share of max, shops from this much gold, takes events from this HP share.
const MIXED_REST_BELOW := 0.55
const MIXED_SHOP_GOLD := 100
const MIXED_EVENT_FROM := 0.6
## Rough per-node effects the `mixed` projection uses: share of max HP a rest heals, a fight costs per enemy,
## an elite costs, and the gold a shop spends.
const _REST_HEAL := 0.3
const _FIGHT_LOSS_PER_ENEMY := 0.05
const _ELITE_LOSS := 0.25
const _SHOP_SPEND := 80
## Weight of each later row against the one before it, so an immediate rest beats the same rest a row later.
const _DISCOUNT := 0.85


## The node to take next under `strategy`, or -1 when none is reachable. An unknown name behaves like `first`.
static func choose(run: RunState, strategy: String) -> int:
	var options := run.reachable_nodes()
	if options.is_empty():
		return -1
	match strategy:
		FIGHTER:
			return _by_rank(run, options, _fighter_rank)
		CAUTIOUS:
			return _by_rank(run, options, _cautious_rank)
		MIXED:
			return _mixed(run, options)
		RANDOM:
			return _random(run, options)
		SMART:
			return SmartPolicy.choose_route(run, SMART)
	return options[0]


# --- fighter and cautious: a rank per node, lower is better ------------------------------------------------

static func _fighter_rank(node: RouteMap.MapNode) -> int:
	match node.type:
		RouteMap.NodeType.ELITE:
			return 0
		RouteMap.NodeType.FIGHT:
			return 1
		RouteMap.NodeType.TREASURE:
			return 2
		RouteMap.NodeType.EVENT:
			return 4
		RouteMap.NodeType.SHOP:
			return 5
		RouteMap.NodeType.REST:
			return 6
	return 3 # story beat and bosses: never competing with anything, the row is forced


static func _cautious_rank(node: RouteMap.MapNode) -> int:
	match node.type:
		RouteMap.NodeType.TREASURE:
			return 0
		RouteMap.NodeType.REST:
			return 1
		RouteMap.NodeType.SHOP:
			return 2
		RouteMap.NodeType.EVENT:
			return 3
		RouteMap.NodeType.FIGHT:
			return 4 + clampi(node.enemy_count, 1, 3) # 1, 2 or 3 enemies: 5, 6, 7
		RouteMap.NodeType.ELITE:
			return 9
	return 4 # story beat and bosses: the row is forced


## The option with the lowest rank. Ties go to the one whose best path of the next LOOKAHEAD rows has the lowest
## rank sum (so a fighter keeps heading into fights and a cautious route towards rests), then to the first.
static func _by_rank(run: RunState, options: Array[int], rank: Callable) -> int:
	var best := options[0]
	var best_rank := 1000000
	var best_tail := 1000000
	for id in options:
		var node := run.route.node(id)
		var here: int = rank.call(node)
		if here > best_rank:
			continue
		var tail := _best_tail(run, id, LOOKAHEAD - 1, rank)
		if here < best_rank or tail < best_tail:
			best = id
			best_rank = here
			best_tail = tail
	return best


## The lowest rank sum over the paths of up to `depth` rows below node `id` (0 when it has no exits).
static func _best_tail(run: RunState, id: int, depth: int, rank: Callable) -> int:
	if depth <= 0:
		return 0
	var best := -1
	for next_id in run.route.next_ids(id):
		var total: int = rank.call(run.route.node(next_id)) + _best_tail(run, next_id, depth - 1, rank)
		if best == -1 or total < best:
			best = total
	return maxi(best, 0)


# --- mixed: scored look-ahead -------------------------------------------------------------------------------

static func _mixed(run: RunState, options: Array[int]) -> int:
	var max_hp := maxf(float(run.player.max_hp), 1.0)
	var hp := float(run.player.hp) / max_hp
	var best := options[0]
	var best_score := -INF
	for id in options:
		var score := _path_score(run, id, hp, run.gold, LOOKAHEAD)
		if score > best_score + 0.000001:
			best_score = score
			best = id
	return best


## The best total score over the paths that start at node `id`, given the HP share and gold on arrival.
static func _path_score(run: RunState, id: int, hp: float, gold: int, depth: int) -> float:
	var node := run.route.node(id)
	var gain := 0.0
	var next_hp := hp
	var next_gold := gold
	match node.type:
		RouteMap.NodeType.TREASURE:
			gain = 3.0 # a free relic: always worth it
		RouteMap.NodeType.REST:
			var heal := minf(_REST_HEAL, 1.0 - hp)
			next_hp = hp + heal
			gain = heal * (10.0 if hp < MIXED_REST_BELOW else 2.0) + (3.0 if hp < MIXED_REST_BELOW else 0.0)
		RouteMap.NodeType.SHOP:
			if gold >= MIXED_SHOP_GOLD:
				gain = 3.0
				next_gold = gold - _SHOP_SPEND
			else:
				gain = -0.2 # a visit with nothing to buy
		RouteMap.NodeType.EVENT:
			gain = 2.0 if hp >= MIXED_EVENT_FROM else -1.5
		RouteMap.NodeType.ELITE:
			var loss := _ELITE_LOSS
			next_hp = hp - loss
			gain = 1.5 - loss * (12.0 if hp < MIXED_REST_BELOW else 3.0)
		RouteMap.NodeType.FIGHT:
			var loss := _FIGHT_LOSS_PER_ENEMY * maxi(node.enemy_count, 1)
			next_hp = hp - loss
			gain = 0.8 - loss * (12.0 if hp < MIXED_REST_BELOW else 3.0)
		_:
			pass # story beat and bosses: forced rows, no choice to score
	next_hp = clampf(next_hp, 0.0, 1.0)
	var tail := 0.0
	if depth > 1 and not node.next.is_empty():
		tail = -INF
		for next_id in node.next:
			tail = maxf(tail, _path_score(run, next_id, next_hp, next_gold, depth - 1))
	else:
		# The end of the look-ahead: arriving hurt is a debt the rest of the run pays.
		tail = -5.0 * maxf(0.0, 0.4 - next_hp)
	return gain + _DISCOUNT * tail


# --- random --------------------------------------------------------------------------------------------------

## Uniform over the options. The generator is re-seeded from the map seed and the position on the map every
## call, so the pick depends on nothing else (not on how the run got here, nor on any other stream).
static func _random(run: RunState, options: Array[int]) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = run.route.seed_value * 7919 + run.current_node * 104729 + run.visited.size() * 1299709 + 17
	return options[rng.randi_range(0, options.size() - 1)]
