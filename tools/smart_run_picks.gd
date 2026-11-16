class_name SmartRunPicks
extends RefCounted
## The smart bot's choices outside a fight (see SmartPolicy's header, "Rewards and vendor"): the map route, event
## buttons, the card reward (with the free Heal or Remove), Remember, and the vendor. SmartPolicy's functions of the
## same names forward here. Cards are ranked by SmartCardScore. Uses only the public RunState and Vendor APIs.

const MIN_DECK := 8
const REMOVE_BELOW := 0.8
## The free reward Heal is used while HP is below this share of max HP.
const HEAL_BELOW := 0.5
const READY_GAIN_BONUS := 0.5 # Remembering a card that makes it playable right away
const REMEMBER_TIE_EPSILON := 0.0001 # a Remember choice must beat the best gain by more than this
## The reward is taken when its score reaches this share of the deck's average card score.
const REWARD_SKIP_SHARE := 1.0


## Event stop for the smart bot. Each enabled button is scored by what it does for a run in this state: healing is
## worth a lot below EVENT_HURT_BELOW of max HP and little above it, HP spent costs more when hurt, a relic or a card
## pick is the main prize for a healthy player, a curse or lost max HP is a real cost, a payment of gold is never made
## below EVENT_MIN_GOLD (and never when it cannot be afforded), and a gamble that can cost HP is not taken while
## hurt. The best score wins; ties go to the earlier button. When every enabled button scores -INF (never) the least costly
## one is pressed anyway, as the greedy bot does, so the stop still settles. False on a RunState failure.
const EVENT_HURT_BELOW := 0.6
const EVENT_MIN_GOLD := 60


static func event_stop(run: RunState) -> bool:
	var choices := run.event_choices()
	var best := -1
	var best_score := -INF
	var fallback := -1
	var fallback_price := INF
	for i in choices.size():
		if not run.event_choice_state(i).enabled:
			continue
		var costs := SimPolicy.event_costs(choices[i].effects)
		var price: float = costs["hp"] + costs["gold"] + 4.0 * costs["max_hp"] + 8.0 * costs["curses"]
		if price < fallback_price:
			fallback_price = price
			fallback = i
		var score := event_score(run, choices[i].effects)
		if score > best_score + 0.0001:
			best_score = score
			best = i
	if best == -1:
		best = fallback
	if best == -1 and run.current_event() != null:
		printerr("SmartPolicy: an event offered no usable button")
		return false
	return SimPolicy.finish_event_picks(run, true, best)


## The value of a list of event effects for the current run state (see `event_stop`); -INF means never.
static func event_score(run: RunState, effects: Array[EventEffect]) -> float:
	var hurt := run.player.hp < EVENT_HURT_BELOW * run.player.max_hp
	var score := 0.0
	for effect in effects:
		match effect.kind:
			EventEffect.Kind.HEAL_PERCENT, EventEffect.Kind.HEAL_FLAT:
				var wanted: float = run.player.max_hp * effect.amount / 100.0 if effect.kind == EventEffect.Kind.HEAL_PERCENT else float(effect.amount)
				score += minf(wanted, run.player.max_hp - run.player.hp) * (2.0 if hurt else 0.3)
			EventEffect.Kind.LOSE_HP, EventEffect.Kind.LOSE_HP_PERCENT:
				var cost: float = run.player.max_hp * effect.amount / 100.0 if effect.kind == EventEffect.Kind.LOSE_HP_PERCENT else float(effect.amount)
				score -= cost * (2.5 if hurt else 0.5)
				if run.player.hp - cost < 0.3 * run.player.max_hp:
					score -= 20.0
			EventEffect.Kind.GOLD:
				if effect.amount < 0:
					if run.gold < EVENT_MIN_GOLD or run.gold + effect.amount < 0:
						return -INF
					score += effect.amount * 0.4
				else:
					score += effect.amount * 0.3
			EventEffect.Kind.MAX_HP:
				score += effect.amount * 4.0
			EventEffect.Kind.GAIN_RELIC:
				score += 10.0 if hurt else 26.0
			EventEffect.Kind.PICK_CARD:
				score += 12.0 + 6.0 * maxf(effect.rarity, 0)
			EventEffect.Kind.ADD_RANDOM_CARD, EventEffect.Kind.ADD_CARD:
				score += 6.0
			EventEffect.Kind.REMOVE_CARD:
				score += 10.0 if run.deck.size() > MIN_DECK else 2.0
			EventEffect.Kind.REMEMBER_CARD:
				score += 12.0
			EventEffect.Kind.ADD_CURSE:
				score -= 9.0 * maxi(effect.count, 1)
			EventEffect.Kind.REMOVE_RANDOM_CARD:
				score -= 6.0
			EventEffect.Kind.GAMBLE:
				var win := event_score(run, effect.win)
				var lose := event_score(run, effect.lose)
				var costs := SimPolicy.event_costs(effect.lose)
				if hurt and (costs["hp"] > 0 or costs["gold"] > 0):
					return -INF
				if win == -INF and lose == -INF:
					return -INF
				var p := effect.amount / 100.0
				score += p * (win if win != -INF else -50.0) + (1.0 - p) * (lose if lose != -INF else -50.0)
	return score


## Map mode route choice. `route` `smart` (the default): a rest when HP is under half, a shop when gold is at least
## ROUTE_SHOP_GOLD, a chest, an event while healthy, else the first plain fight, else the first node. Any other
## name is a RoutePolicy strategy. Returns -1 when none is reachable.
const ROUTE_REST_BELOW := 0.5
const ROUTE_SHOP_GOLD := 120
const ROUTE_EVENT_ABOVE := 0.7


static func choose_route(run: RunState, route: String = RoutePolicy.SMART) -> int:
	if route != RoutePolicy.SMART:
		return RoutePolicy.choose(run, route)
	var options := run.reachable_nodes()
	if options.is_empty():
		return -1
	var wanted: Array[RouteMap.NodeType] = []
	if run.player.hp < ROUTE_REST_BELOW * run.player.max_hp:
		wanted.append(RouteMap.NodeType.REST)
	if run.gold >= ROUTE_SHOP_GOLD:
		wanted.append(RouteMap.NodeType.SHOP)
	# A chest is free (a relic for nothing) and the forced treasure row is unavoidable, so it is taken
	# whenever it is offered, ahead of a plain fight.
	wanted.append(RouteMap.NodeType.TREASURE)
	# An event is a gamble on a story: worth the detour only while the player is healthy.
	if run.player.hp >= ROUTE_EVENT_ABOVE * run.player.max_hp:
		wanted.append(RouteMap.NodeType.EVENT)
	wanted.append(RouteMap.NodeType.FIGHT)
	for type in wanted:
		for id in options:
			if run.route.node(id).type == type:
				return id
	# This rule set never seeks an elite: with nothing else it still prefers any other node to one.
	for id in options:
		if run.route.node(id).type != RouteMap.NodeType.ELITE:
			return id
	return options[0]


## Reward pick: the best-scoring offered card, or null (skip) if even that is
## below the deck's average card score.
static func pick_reward(run: RunState) -> CardData:
	var weights := SmartCardScore.deck_weights(run.deck)
	var best: CardData = null
	var best_score := -INF
	for card in run.reward_choices():
		var score := SmartCardScore.card_score(card, weights)
		if score > best_score:
			best_score = score
			best = card
	if best == null or best_score < REWARD_SKIP_SHARE * SmartCardScore.average_score(run.deck, weights):
		return null
	return best


## Resolves the pending reward: the free Heal when HP is under HEAL_BELOW of max, else the
## free Remove (on the weakest deck card) when even the best offered card scores below the
## deck average, else pick_reward. Each alternative is used only while unused. False if rejected.
static func take_reward(run: RunState) -> bool:
	if not SimPolicy.take_elite_spoils(run):
		return false
	if run.can_reward_heal() and run.player.hp < HEAL_BELOW * run.player.max_hp:
		return run.resolve_reward_heal()
	if run.can_reward_remove() and run.deck.size() > MIN_DECK and pick_reward(run) == null:
		var weights := SmartCardScore.deck_weights(run.deck)
		var weakest: CardData = run.deck[0]
		for card in run.deck:
			if SmartCardScore.card_score(card, weights) < SmartCardScore.card_score(weakest, weights):
				weakest = card
		return run.resolve_reward_remove(weakest)
	return run.resolve_reward(pick_reward(run))


## Deck index of the card worth Remembering most: the biggest card_score gain of its Remembered form (Ready
## and a refunded Glimpse count a little); ties go to the earlier card. -1 when nothing can be Remembered.
static func remember_pick(run: RunState, indices: Array[int] = []) -> int:
	var weights := SmartCardScore.deck_weights(run.deck)
	var best := -1
	var best_gain := -INF
	for i in (indices if not indices.is_empty() else run.rememberable_indices()):
		var card := run.deck[i]
		var upgraded := card.remembered_card()
		var gain := SmartCardScore.card_score(upgraded, weights) - SmartCardScore.card_score(card, weights)
		if upgraded.ready and not card.ready:
			gain += READY_GAIN_BONUS
		if gain > best_gain + REMEMBER_TIE_EPSILON:
			best_gain = gain
			best = i
	return best


## Vendor visit per SmartPolicy's header. False on a RunState failure.
static func shop(run: RunState) -> bool:
	if not SimPolicy.shop_basics(run):
		return false
	var vendor := run.vendor()
	while true:
		var weights := SmartCardScore.deck_weights(run.deck)
		var average := SmartCardScore.average_score(run.deck, weights)
		var best_index := -1
		var best_score := average
		var offers := vendor.offers()
		for i in offers.size():
			if offers[i]["sold"] or offers[i]["price"] > run.gold:
				continue
			var score := SmartCardScore.card_score(offers[i]["card"], weights)
			if score > best_score:
				best_score = score
				best_index = i
		if best_index == -1:
			break
		if not run.vendor_buy_card(best_index).ok:
			printerr("SmartPolicy: vendor refused an affordable card")
			return false
	if run.gold >= Vendor.REMOVE_CARD_PRICE and run.deck.size() > MIN_DECK:
		var weights := SmartCardScore.deck_weights(run.deck)
		var weakest := -1
		var weakest_score := INF
		for i in run.deck.size():
			var score := SmartCardScore.card_score(run.deck[i], weights)
			if score < weakest_score:
				weakest_score = score
				weakest = i
		if weakest_score < REMOVE_BELOW * SmartCardScore.average_score(run.deck, weights):
			if not run.vendor_remove_card(weakest).ok:
				printerr("SmartPolicy: vendor refused a removal")
				return false
	return run.leave_vendor()
