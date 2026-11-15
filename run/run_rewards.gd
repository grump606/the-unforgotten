class_name RunRewards
extends RefCounted
## Card-reward rolling for RunState: which cards a won fight offers. Static helpers that take the run, so
## RunState keeps only the reward flags and the public reward API. Every draw uses the run RNG in the same order as before.
## Of RunState's internals it uses only the run RNG (`run._rng`).


## Rolls a won fight's reward choices (up to REWARD_CHOICES distinct cards) and records them in `run.offered_ids`.
static func roll(run: RunState) -> Array[CardData]:
	# Mostly the character's own cards, with a neutral one mixed in: up to REWARD_CLASS_CHOICES
	# class cards, then neutral cards to fill, then any class cards left over.
	var class_cards: Array[CardData] = []
	var neutral_cards: Array[CardData] = []
	for card in candidates(run, distinct_cards(StarterContent.reward_pool(run.character.id, run.chapter))):
		if card.character == &"":
			neutral_cards.append(card)
		else:
			class_cards.append(card)
	# Each slot rolls a rarity first (rarer cards come up more often deeper into the run), then a card of it.
	var weights := StarterContent.rarity_weights(run.rarity_tier())
	var picks: Array[CardData] = []
	var class_picks := StarterContent.pick_by_rarity(class_cards, RunState.REWARD_CLASS_CHOICES, weights, run._rng)
	picks.append_array(class_picks)
	picks.append_array(StarterContent.pick_by_rarity(neutral_cards, RunState.REWARD_CHOICES - picks.size(), weights, run._rng))
	if picks.size() < RunState.REWARD_CHOICES:
		var rest: Array[CardData] = []
		for card in class_cards:
			if not class_picks.has(card):
				rest.append(card)
		picks.append_array(StarterContent.pick_by_rarity(rest, RunState.REWARD_CHOICES - picks.size(), weights, run._rng))
	for card in picks:
		if not run.offered_ids.has(card.id):
			run.offered_ids.append(card.id)
	return picks


## The cards a reward may draw from. Prefers cards not offered before and not at the
## copy cap; if that leaves fewer than REWARD_CHOICES, lets back in the already-offered
## ones, and only then the capped ones, so an offer is as full as the pool allows.
static func candidates(run: RunState, pool: Array[CardData]) -> Array[CardData]:
	var copies := {}
	for card in run.deck:
		copies[card.id] = int(copies.get(card.id, 0)) + 1
	var fresh: Array[CardData] = []
	var uncapped: Array[CardData] = []
	for card in pool:
		if int(copies.get(card.id, 0)) < RunState.COPY_CAP:
			uncapped.append(card)
			if not run.offered_ids.has(card.id):
				fresh.append(card)
	if fresh.size() >= RunState.REWARD_CHOICES:
		return fresh
	if uncapped.size() >= RunState.REWARD_CHOICES:
		return uncapped
	return pool


static func distinct_cards(cards: Array[CardData]) -> Array[CardData]:
	var seen := {}
	var distinct: Array[CardData] = []
	for card in cards:
		if not seen.has(card.id):
			seen[card.id] = true
			distinct.append(card)
	return distinct
