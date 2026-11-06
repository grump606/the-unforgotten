extends RefCounted
## Rarity (Common, Uncommon, Rare): every card has one, rewards and vendor stock roll a rarity first with odds that
## shift towards the rarer cards deeper into the run. Registered by run_tests.gd.

var _failures := 0


func run() -> int:
	_failures = 0
	_test_assignments()
	_test_weights()
	_test_pick_by_rarity()
	_test_rare_share_by_tier()
	_test_rewards_by_depth()
	_test_vendor_stock()
	_test_variant_and_gem()
	return _failures


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAIL: " + label)


func _test_assignments() -> void:
	var by_class := {}
	var totals := [0, 0, 0]
	for card in StarterContent.all_cards():
		totals[card.rarity] += 1
		var key: StringName = card.character
		if not by_class.has(key):
			by_class[key] = [0, 0, 0]
		by_class[key][card.rarity] += 1
		if card.basic:
			_check(card.rarity == CardData.Rarity.COMMON, "%s: a basic card is Common" % card.id)
	_check(totals[0] + totals[1] + totals[2] == 111, "every card has a rarity (%s)" % str(totals))
	_check(totals[0] > totals[1] and totals[1] > totals[2] and totals[2] >= 6, "Common outnumbers Uncommon, which outnumbers Rare, and there are Rares (%s)" % str(totals))
	for class_id in [&"deserter", &"thief", &"medium", &"stray"]:
		var counts: Array = by_class[class_id]
		_check(counts[0] >= 4 and counts[1] >= 3 and counts[2] >= 1, "%s has Common, Uncommon and Rare cards (%s)" % [class_id, str(counts)])
	_check(by_class[&""][1] >= 3, "the neutral pool has Uncommon cards")
	# The cards a character starts with are all Common.
	for character in StarterContent.character_ids():
		for card in StarterContent.starter_deck(character):
			_check(card.rarity == CardData.Rarity.COMMON, "%s starts with a Common %s" % [character, card.id])


func _test_weights() -> void:
	var rare_share := []
	for tier in StarterContent.RARITY_WEIGHTS.size():
		var weights := StarterContent.rarity_weights(tier)
		_check(weights[0] + weights[1] + weights[2] == 100, "tier %d weights sum to 100" % tier)
		rare_share.append(weights[2])
	_check(rare_share == [3, 6, 10, 16], "the Rare share grows each tier: %s" % str(rare_share))
	_check(StarterContent.rarity_weights(-5) == StarterContent.rarity_weights(0) and StarterContent.rarity_weights(99) == StarterContent.rarity_weights(3), "out-of-range tiers clamp")


func _pool() -> Array[CardData]:
	return StarterContent.reward_pool(&"medium")


func _test_pick_by_rarity() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var picks := StarterContent.pick_by_rarity(_pool(), 3, StarterContent.rarity_weights(1), rng)
	var ids := []
	for card in picks:
		ids.append(card.id)
	_check(picks.size() == 3 and ids.size() == _unique(ids).size(), "three distinct cards come back")
	var again := RandomNumberGenerator.new()
	again.seed = 5
	var repeat := StarterContent.pick_by_rarity(_pool(), 3, StarterContent.rarity_weights(1), again)
	_check(repeat == picks, "the same seed repeats the picks")
	_check(StarterContent.pick_by_rarity(_pool(), 500, StarterContent.rarity_weights(0), rng).size() == _pool().size(), "asking for more than the pool holds returns the whole pool")
	_check(StarterContent.pick_by_rarity([] as Array[CardData], 3, StarterContent.rarity_weights(0), rng).is_empty(), "an empty pool gives nothing")
	# A pool with no Rare card never errors and never returns one.
	var commons: Array[CardData] = []
	for card in _pool():
		if card.rarity == CardData.Rarity.COMMON:
			commons.append(card)
	var only := StarterContent.pick_by_rarity(commons, 3, StarterContent.rarity_weights(3), rng)
	_check(only.size() == 3, "a pool of Commons still fills the offer at the deepest tier")
	var pool := _pool()
	var before := pool.size()
	StarterContent.pick_by_rarity(pool, 3, StarterContent.rarity_weights(2), rng)
	_check(pool.size() == before, "the pool passed in is not changed")


func _unique(items: Array) -> Array:
	var seen := {}
	for item in items:
		seen[item] = true
	return seen.keys()


func _test_rare_share_by_tier() -> void:
	var shares := []
	for tier in [0, 3]:
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		var rares := 0
		var rolls := 4000
		var pool := _pool()
		for i in rolls:
			var pick := StarterContent.pick_by_rarity(pool, 1, StarterContent.rarity_weights(tier), rng)
			if pick[0].rarity == CardData.Rarity.RARE:
				rares += 1
		shares.append(float(rares) / rolls)
	_check(shares[0] > 0.01 and shares[0] < 0.07, "tier 0 offers a Rare about 3%% of the time (%.3f)" % shares[0])
	_check(shares[1] > 0.11 and shares[1] < 0.22, "tier 3 offers a Rare about 16%% of the time (%.3f)" % shares[1])


func _test_rewards_by_depth() -> void:
	var shares := []
	for depth_name in ["early", "late"]:
		var rares := 0
		var cards := 0
		for seed_value in 80:
			var state := RunState.new(seed_value, &"medium")
			state.read_story()
			state.stop_index = 0 if depth_name == "early" else state.stops.size() - 2
			_check(state.rarity_tier() == (0 if depth_name == "early" else 3), "%s: the tier at stop %d is right" % [depth_name, state.stop_index])
			state._roll_rewards()
			for card in state.reward_choices():
				cards += 1
				if card.rarity == CardData.Rarity.RARE:
					rares += 1
		shares.append(float(rares) / cards)
	_check(shares[1] > shares[0], "rewards hold more Rares late in the run than early (%.3f vs %.3f)" % [shares[1], shares[0]])
	var state := RunState.new(1, &"stray")
	state.stops = state.stops
	for index in [0, 5, 10, 15, 20]:
		state.stop_index = index
		_check(state.rarity_tier() == index * 4 / state.stops.size(), "rarity_tier at stop %d" % index)


func _test_vendor_stock() -> void:
	var early := 0
	var late := 0
	var vendor_cards := StarterContent.vendor_pool(&"thief")
	var starter := StarterContent.starter_deck(&"thief")
	for seed_value in 300:
		for tier in [0, 3]:
			var rng := RandomNumberGenerator.new()
			rng.seed = seed_value
			var vendor := Vendor.new(starter, rng, 100, vendor_cards, [] as Array[RelicData], null, StarterContent.rarity_weights(tier))
			var ids := []
			for offer in vendor.offers():
				ids.append(offer["card"].id)
				if offer["card"].rarity == CardData.Rarity.RARE:
					if tier == 0:
						early += 1
					else:
						late += 1
			_check(ids.size() == Vendor.STOCK_CARDS and _unique(ids).size() == ids.size(), "vendor stock is full and distinct (tier %d, seed %d)" % [tier, seed_value])
	_check(late > early, "a deep vendor stocks more Rares than an early one (%d vs %d)" % [late, early])


func _test_variant_and_gem() -> void:
	var base := CardData.make(&"t", "T", 1, [CardEffect.make(CardEffect.Kind.DAMAGE, 4)] as Array[CardEffect])
	base.rarity = CardData.Rarity.RARE
	base.remembered = RememberedData.make([CardEffect.make(CardEffect.Kind.DAMAGE, 6)] as Array[CardEffect])
	_check(base.remembered_card().rarity == CardData.Rarity.RARE, "a Remembered card keeps its rarity")
	_check(CardView.rarity_gem_color(CardData.Rarity.COMMON).a == 0.0, "a Common card shows no gem")
	_check(CardView.rarity_gem_color(CardData.Rarity.UNCOMMON).a > 0.0 and CardView.rarity_gem_color(CardData.Rarity.RARE).a > 0.0, "Uncommon and Rare cards show a gem")
	_check(CardView.rarity_gem_color(CardData.Rarity.UNCOMMON) != CardView.rarity_gem_color(CardData.Rarity.RARE), "and the two gems differ")
