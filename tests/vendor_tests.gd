extends RefCounted
## Tests for the vendor module.
## run() returns the failure count and prints a "FAIL: ..." line per failure.

var _failures := 0


func run() -> int:
	_failures = 0
	_test_stock()
	_test_prices()
	_test_payoff_pricing()
	_test_buy_card()
	_test_remove_card()
	_test_buy_heal()
	_test_failed_purchases_change_nothing()
	_test_gold_for_win()
	_test_exact_gold_and_price_boundaries()
	_test_relic_offer_is_optional()
	return _failures


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAIL: " + label)


func _vendor(seed_value: int, gold: int, deck: Array[CardData] = []) -> Vendor:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return Vendor.new(deck, rng, gold)


func _ids(vendor: Vendor) -> Array:
	var ids: Array = []
	for offer in vendor.offers():
		ids.append((offer["card"] as CardData).id)
	return ids


## A vendor built without a relic pool sells no relic and its relic purchase fails cleanly.
func _test_relic_offer_is_optional() -> void:
	var vendor := _vendor(5, 500)
	_check(vendor.relic_offer().is_empty(), "no relic pool: no relic offer")
	var result := vendor.buy_relic(Combatant.new("p", 20))
	_check(not result.ok and result.relic == null and vendor.gold == 500, "no relic pool: buy_relic fails and changes nothing")


func _test_stock() -> void:
	var seen := {}
	for seed_value in 40:
		var ids := _ids(_vendor(seed_value, 0))
		_check(ids.size() == Vendor.STOCK_CARDS, "stock size for seed %d" % seed_value)
		var distinct := {}
		for id in ids:
			distinct[id] = true
			seen[id] = true
		_check(distinct.size() == ids.size(), "stock distinct for seed %d" % seed_value)
		_check(ids == _ids(_vendor(seed_value, 0)), "stock deterministic for seed %d" % seed_value)
	_check(seen.size() > Vendor.STOCK_CARDS, "different seeds give varied stock")
	for offer in _vendor(1, 0).offers():
		_check(not offer["sold"] and offer["price"] > 0, "fresh offer unsold with a price")


func _test_prices() -> void:
	var cheap := CardData.make(&"t_cheap", "Cheap", 0, [CardEffect.make(CardEffect.Kind.BLOCK, 2)] as Array[CardEffect])
	var mid := CardData.make(&"t_mid", "Mid", 1, [CardEffect.make(CardEffect.Kind.DAMAGE, 6)] as Array[CardEffect])
	var big := CardData.make(&"t_big", "Big", 2, [CardEffect.make(CardEffect.Kind.DAMAGE, 14)] as Array[CardEffect])
	var draw := CardData.make(&"t_draw", "Draw", 0, [CardEffect.make(CardEffect.Kind.DRAW, 2)] as Array[CardEffect])
	_check(Vendor.card_price(cheap) == Vendor.PRICE_CHEAP, "block 2 cost 0 is cheap")
	_check(Vendor.card_price(mid) == Vendor.PRICE_MID, "damage 6 cost 1 is mid")
	_check(Vendor.card_price(big) == Vendor.PRICE_PRICEY, "damage 14 cost 2 is pricey")
	_check(Vendor.card_value(draw) == 2 * Vendor.DRAW_VALUE and Vendor.card_price(draw) == Vendor.PRICE_MID, "a drawn card adds DRAW_VALUE to a card's value")
	# The free cycling cards must not sit in the cheapest tier next to plain block.
	var second_wind := load(StarterContent.SECOND_WIND_PATH) as CardData
	var brace := load(StarterContent.BRACE_PATH) as CardData
	_check(Vendor.card_price(second_wind) > Vendor.card_price(brace), "Second Wind (free block + draw) costs more than Brace (free block)")
	_check(Vendor.PRICE_CHEAP < Vendor.PRICE_MID and Vendor.PRICE_MID < Vendor.PRICE_PRICEY, "tiers ascend")


func _test_buy_card() -> void:
	var deck := StarterContent.deck()
	var before := deck.size()
	var vendor := _vendor(3, 100, deck)
	var offer := vendor.offers()[0]
	var result := vendor.buy_card(0)
	_check(result.ok and result.spent == offer["price"] and result.card == offer["card"], "buy_card succeeds")
	_check(vendor.gold == 100 - offer["price"], "buy_card deducts gold")
	_check(deck.size() == before + 1 and deck[deck.size() - 1] == offer["card"], "buy_card appends to the passed deck")
	_check(vendor.offers()[0]["sold"], "offer marked sold")
	var gold_after := vendor.gold
	var again := vendor.buy_card(0)
	_check(not again.ok and again.reason != "", "double buy refused with a reason")
	_check(vendor.gold == gold_after and deck.size() == before + 1, "double buy changes nothing")
	_check(vendor.buy_card(1).ok, "other offer still buyable")


func _test_remove_card() -> void:
	var deck := StarterContent.deck()
	var first := deck[0]
	var vendor := _vendor(3, 100, deck)
	var result := vendor.remove_card(0)
	_check(result.ok and result.card == first and result.spent == Vendor.REMOVE_CARD_PRICE, "remove_card succeeds")
	_check(deck.size() == 9, "remove_card shrinks the passed deck")
	_check(vendor.gold == 100 - Vendor.REMOVE_CARD_PRICE and vendor.has_removed(), "remove_card deducts gold once")
	var again := vendor.remove_card(0)
	_check(not again.ok and deck.size() == 9 and vendor.gold == 100 - Vendor.REMOVE_CARD_PRICE, "double remove refused, nothing changed")
	var fresh := _vendor(3, 100, deck)
	_check(not fresh.remove_card(-1).ok and not fresh.remove_card(deck.size()).ok, "bad indices refused")
	_check(deck.size() == 9 and fresh.gold == 100 and not fresh.has_removed(), "bad index changes nothing")
	var single: Array[CardData] = [first]
	var lone := _vendor(3, 100, single)
	_check(not lone.remove_card(0).ok and single.size() == 1 and lone.gold == 100, "deck of 1 cannot be emptied")
	# Removal targets the chosen index, not just the first card.
	var pair: Array[CardData] = [first, StarterContent.deck()[9]]
	var keep := pair[1]
	var chosen := _vendor(3, 100, pair).remove_card(0)
	_check(chosen.ok and pair.size() == 1 and pair[0] == keep, "remove_card removes the chosen index")


func _test_buy_heal() -> void:
	var player := Combatant.new("Soul", 40, 20)
	var vendor := _vendor(3, 50)
	var result := vendor.buy_heal(player)
	_check(result.ok and result.healed == Vendor.HEAL_AMOUNT and player.hp == 20 + Vendor.HEAL_AMOUNT, "heal restores HEAL_AMOUNT")
	_check(vendor.gold == 50 - Vendor.HEAL_PRICE and vendor.has_healed(), "heal deducts gold")
	var hp_after := player.hp
	var again := vendor.buy_heal(player)
	_check(not again.ok and vendor.gold == 50 - Vendor.HEAL_PRICE and player.hp == hp_after, "double heal refused, nothing changed")
	var near := Combatant.new("Soul", 40, 38)
	var capped := _vendor(3, 50).buy_heal(near)
	_check(capped.ok and capped.healed == 2 and near.hp == 40, "heal reports HP actually regained")
	var full := Combatant.new("Soul", 40)
	var full_vendor := _vendor(3, 50)
	_check(not full_vendor.buy_heal(full).ok and full_vendor.gold == 50 and not full_vendor.has_healed(), "heal at full HP refused, gold kept")
	var hurt := Combatant.new("Soul", 40, 10)
	var poor := _vendor(3, Vendor.HEAL_PRICE - 1)
	_check(not poor.buy_heal(hurt).ok and hurt.hp == 10 and poor.gold == Vendor.HEAL_PRICE - 1, "heal without gold refused")


func _test_failed_purchases_change_nothing() -> void:
	var deck := StarterContent.deck()
	var snapshot := deck.duplicate()
	var vendor := _vendor(5, 1, deck)
	var hurt := Combatant.new("Soul", 40, 10)
	_check(not vendor.buy_card(0).ok and not vendor.remove_card(0).ok and not vendor.buy_heal(hurt).ok, "all purchases refused with 1 gold")
	_check(vendor.gold == 1 and deck == snapshot and hurt.hp == 10, "failed purchases change nothing")
	_check(not vendor.has_removed() and not vendor.has_healed() and not vendor.offers()[0]["sold"], "failed purchases set no flags")
	_check(not vendor.buy_card(-1).ok and not vendor.buy_card(Vendor.STOCK_CARDS).ok, "bad offer index refused")
	# Spend everything available: gold must match the spending exactly and never go negative.
	var rich := _vendor(5, 40, deck)
	var spent := 0
	for i in Vendor.STOCK_CARDS:
		var bought := rich.buy_card(i)
		if bought.ok:
			spent += bought.spent
		_check(rich.gold >= 0 and rich.gold == 40 - spent, "gold exactly 40 minus spending after buy %d" % i)
	var removed := rich.remove_card(0)
	if removed.ok:
		spent += removed.spent
	var healed := rich.buy_heal(hurt)
	if healed.ok:
		spent += healed.spent
	_check(rich.gold >= 0 and rich.gold == 40 - spent, "gold exactly 40 minus spending after services")


func _test_gold_for_win() -> void:
	_check(Vendor.gold_for_win(1) == Vendor.GOLD_PER_ENEMY + Vendor.GOLD_WIN_BONUS, "gold_for_win(1)")
	_check(Vendor.gold_for_win(3) == 3 * Vendor.GOLD_PER_ENEMY + Vendor.GOLD_WIN_BONUS, "gold_for_win(3)")
	_check(Vendor.gold_for_win(2) > Vendor.gold_for_win(1), "more enemies pay more")
	_check(Vendor.gold_for_win(0) == 0, "gold_for_win(0) awards nothing")


# Spending exactly the gold you have must work, and tier boundaries must sit where documented.
func _test_exact_gold_and_price_boundaries() -> void:
	var deck := StarterContent.deck()
	var probe := _vendor(7, 0, deck)
	var price: int = probe.offers()[0]["price"]
	var exact := _vendor(7, price, deck)
	var bought := exact.buy_card(0)
	_check(bought.ok and exact.gold == 0, "a card can be bought with exactly its price in gold")
	var one_short := _vendor(7, price - 1, deck)
	_check(not one_short.buy_card(0).ok and one_short.gold == price - 1, "one gold short is refused")

	var hurt := Combatant.new("Soul", 40, 10)
	var heal_exact := _vendor(7, Vendor.HEAL_PRICE, deck)
	_check(heal_exact.buy_heal(hurt).ok and heal_exact.gold == 0, "a heal can be bought with exactly its price in gold")
	var remove_exact := _vendor(7, Vendor.REMOVE_CARD_PRICE, deck)
	_check(remove_exact.remove_card(0).ok and remove_exact.gold == 0, "a removal can be bought with exactly its price in gold")

	# card_value = 2*cost + damage + block + 2*expose + 3*draw; tiers switch AT MID_FROM and PRICEY_FROM.
	var at_mid := CardData.make(&"t_at_mid", "AtMid", 0, [CardEffect.make(CardEffect.Kind.DAMAGE, Vendor.MID_FROM)] as Array[CardEffect])
	var below_mid := CardData.make(&"t_below_mid", "BelowMid", 0, [CardEffect.make(CardEffect.Kind.DAMAGE, Vendor.MID_FROM - 1)] as Array[CardEffect])
	var at_pricey := CardData.make(&"t_at_pricey", "AtPricey", 0, [CardEffect.make(CardEffect.Kind.DAMAGE, Vendor.PRICEY_FROM)] as Array[CardEffect])
	var below_pricey := CardData.make(&"t_below_pricey", "BelowPricey", 0, [CardEffect.make(CardEffect.Kind.DAMAGE, Vendor.PRICEY_FROM - 1)] as Array[CardEffect])
	_check(Vendor.card_price(below_mid) == Vendor.PRICE_CHEAP and Vendor.card_price(at_mid) == Vendor.PRICE_MID, "the cheap/mid tier switches exactly at MID_FROM")
	_check(Vendor.card_price(below_pricey) == Vendor.PRICE_MID and Vendor.card_price(at_pricey) == Vendor.PRICE_PRICEY, "the mid/pricey tier switches exactly at PRICEY_FROM")

	# push_error is expected for a negative starting amount.
	var broke := _vendor(7, -5, deck)
	_check(broke.gold == 0, "negative starting gold is clamped to 0")


## Class payoff cards used to price as if their scaling effects were worth nothing.
func _test_payoff_pricing() -> void:
	var spree := load("res://data/cards/spree.tres") as CardData
	var reckoning := load("res://data/cards/reckoning.tres") as CardData
	var last_pocket := load("res://data/cards/last_pocket.tres") as CardData
	_check(Vendor.card_price(spree) > Vendor.PRICE_CHEAP, "Spree prices above the cheap tier")
	_check(Vendor.card_price(reckoning) > Vendor.PRICE_CHEAP, "Reckoning prices above the cheap tier")
	_check(Vendor.card_price(last_pocket) > Vendor.PRICE_CHEAP, "Last Pocket prices above the cheap tier")
	_check(Vendor.card_value(reckoning) > Vendor.card_value(spree), "Reckoning (2 energy, x2 Haunt) is worth more than Spree")
	var plain_two := CardData.make(&"t_plain2", "Plain", 2, [CardEffect.make(CardEffect.Kind.DAMAGE, 2)] as Array[CardEffect])
	_check(Vendor.card_value(spree) > Vendor.card_value(plain_two), "Spree is worth more than its base damage alone")
	var free_energy := CardData.make(&"t_energy", "Energy", 0, [CardEffect.make(CardEffect.Kind.GAIN_ENERGY, 1)] as Array[CardEffect])
	_check(Vendor.card_price(free_energy) > Vendor.PRICE_CHEAP - 1 and Vendor.card_value(free_energy) == Vendor.ENERGY_VALUE, "gained energy has a deliberate value")
	var costly := CardData.make(&"t_hpcost", "HP", 1, [CardEffect.make(CardEffect.Kind.DAMAGE, 8), CardEffect.make(CardEffect.Kind.LOSE_HP, 4)] as Array[CardEffect])
	var free_hit := CardData.make(&"t_hit", "Hit", 1, [CardEffect.make(CardEffect.Kind.DAMAGE, 8)] as Array[CardEffect])
	_check(Vendor.card_value(costly) < Vendor.card_value(free_hit), "paying HP lowers a card's value")
