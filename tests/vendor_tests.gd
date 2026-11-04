extends RefCounted
## Tests for the vendor module.
## run() returns the failure count and prints a "FAIL: ..." line per failure.

var _failures := 0


func run() -> int:
	_failures = 0
	_test_stock()
	_test_prices()
	_test_payoff_pricing()
	_test_existing_card_prices_unchanged()
	_test_hits_multiply_value()
	_test_keyword_adjustments()
	_test_per_energy_value()
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
	_check(Vendor.card_price(second_wind) > Vendor.card_price(brace), "Borrowed Breath (free block + draw) costs more than Brace (free block)")
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
	_check(Vendor.card_price(spree) > Vendor.PRICE_CHEAP, "Many Hands prices above the cheap tier")
	_check(Vendor.card_price(reckoning) > Vendor.PRICE_CHEAP, "Reckoning prices above the cheap tier")
	_check(Vendor.card_price(last_pocket) > Vendor.PRICE_CHEAP, "Last Keepsake prices above the cheap tier")
	_check(Vendor.card_value(reckoning) > Vendor.card_value(spree), "Reckoning (2 energy, x2 Haunt) is worth more than Many Hands")
	var plain_two := CardData.make(&"t_plain2", "Plain", 2, [CardEffect.make(CardEffect.Kind.DAMAGE, 2)] as Array[CardEffect])
	_check(Vendor.card_value(spree) > Vendor.card_value(plain_two), "Many Hands is worth more than its base damage alone")
	var free_energy := CardData.make(&"t_energy", "Energy", 0, [CardEffect.make(CardEffect.Kind.GAIN_ENERGY, 1)] as Array[CardEffect])
	_check(Vendor.card_price(free_energy) > Vendor.PRICE_CHEAP - 1 and Vendor.card_value(free_energy) == Vendor.ENERGY_VALUE, "gained energy has a deliberate value")
	var costly := CardData.make(&"t_hpcost", "HP", 1, [CardEffect.make(CardEffect.Kind.DAMAGE, 8), CardEffect.make(CardEffect.Kind.LOSE_HP, 4)] as Array[CardEffect])
	var free_hit := CardData.make(&"t_hit", "Hit", 1, [CardEffect.make(CardEffect.Kind.DAMAGE, 8)] as Array[CardEffect])
	_check(Vendor.card_value(costly) < Vendor.card_value(free_hit), "paying HP lowers a card's value")


## Golden table of id -> [value, price] for every data/cards card, taken before the keyword and
## multi-hit valuation existed. Update it on purpose whenever a card is retuned (Flurry and Glimpse the
## Exit changed in Phase 4a); a new card is added with its computed value and price.
const GOLDEN := {
	"bash": [7, 16],
	"bleed_the_veil": [34, 24],
	"brace": [2, 10],
	"cold_steel": [9, 16],
	"cold_whisper": [3, 10],
	"confess": [10, 16],
	"counter_stance": [20, 24],
	"cutting_word": [7, 16],
	"dig_in": [4, 10],
	"flurry": [4, 10],
	"glimpse_exit": [7, 16],
	"grave_chill": [16, 24],
	"guarded_strike": [8, 16],
	"hamstring": [14, 24],
	"heavy_blow": [18, 24],
	"hold_the_line": [9, 16],
	"iron_resolve": [12, 24],
	"last_pocket": [12, 24],
	"last_stand": [30, 24],
	"lift": [9, 16],
	"lingering_dread": [12, 24],
	"mark_the_weak": [6, 16],
	"penance": [8, 16],
	"pocket_watch": [10, 16],
	"reckoning": [12, 24],
	"seance": [15, 24],
	"second_wind": [6, 16],
	"shoulder_charge": [17, 24],
	"shove": [8, 16],
	"sleight": [2, 10],
	"slip_past": [7, 16],
	"spirit_tithe": [8, 16],
	"spree": [10, 16],
	"steady_breath": [9, 16],
	"sweep": [9, 16]
}


func _test_existing_card_prices_unchanged() -> void:
	var dir := DirAccess.open("res://data/cards")
	var seen := 0
	for file in dir.get_files():
		if not file.ends_with(".tres"):
			continue
		var card := load("res://data/cards/" + file) as CardData
		seen += 1
		if not GOLDEN.has(String(card.id)):
			_check(false, "card %s is missing from the golden price table" % card.id)
			continue
		var want: Array = GOLDEN[String(card.id)]
		_check(Vendor.card_value(card) == want[0], "value of %s is unchanged (%d)" % [card.id, Vendor.card_value(card)])
		_check(Vendor.card_price(card) == want[1], "price of %s is unchanged (%d)" % [card.id, Vendor.card_price(card)])
	_check(seen == GOLDEN.size(), "golden table covers every card (%d of %d)" % [seen, GOLDEN.size()])


func _card(cost: int, effects: Array[CardEffect]) -> CardData:
	return CardData.make(&"t_card", "T", cost, effects)


func _test_hits_multiply_value() -> void:
	var single := _card(1, [CardEffect.make(CardEffect.Kind.DAMAGE, 3)] as Array[CardEffect])
	var triple := _card(1, [CardEffect.make(CardEffect.Kind.DAMAGE, 3, 0, 0, 3)] as Array[CardEffect])
	var zero := _card(1, [CardEffect.make(CardEffect.Kind.DAMAGE, 3, 0, 0, 0)] as Array[CardEffect])
	_check(Vendor.card_value(triple) == 2 + 9, "three hits of 3 are worth 9")
	_check(Vendor.card_value(zero) == Vendor.card_value(single), "hits below 1 count as 1")
	var block := _card(1, [CardEffect.make(CardEffect.Kind.BLOCK, 3, 0, 0, 3)] as Array[CardEffect])
	_check(Vendor.card_value(block) == 2 + 3, "hits do not multiply a non-damage effect")


func _test_keyword_adjustments() -> void:
	var base := _card(1, [CardEffect.make(CardEffect.Kind.DAMAGE, 6)] as Array[CardEffect])
	var base_value := Vendor.card_value(base)
	var cases := {
		"forgotten": -1, "fading": -1, "ready": 1, "anchor": 1, "dormant": -1, "surge": 1,
	}
	for key in cases:
		var card := _card(1, [CardEffect.make(CardEffect.Kind.DAMAGE, 6)] as Array[CardEffect])
		card.set(key, true)
		var delta := Vendor.card_value(card) - base_value
		_check(signi(delta) == cases[key], "%s moves value in its documented direction (%d)" % [key, delta])
	var dormant := _card(1, [CardEffect.make(CardEffect.Kind.DAMAGE, 6)] as Array[CardEffect])
	dormant.dormant = true
	_check(Vendor.card_price(dormant) == Vendor.PRICE_CHEAP, "a dormant card is priced as junk")
	var ready_card := _card(1, [CardEffect.make(CardEffect.Kind.DAMAGE, 6)] as Array[CardEffect])
	ready_card.ready = true
	_check(Vendor.card_value(ready_card) == base_value + Vendor.READY_ADJUST, "ready adds READY_ADJUST")


func _test_per_energy_value() -> void:
	var surge_hits := _card(0, [CardEffect.make(CardEffect.Kind.DAMAGE, 3, 0, 0, 1, true)] as Array[CardEffect])
	surge_hits.surge = true
	_check(Vendor.card_value(surge_hits) == 3 * Vendor.SURGE_TYPICAL_ENERGY + Vendor.SURGE_ADJUST, "per_energy damage is valued at the typical energy in hits")
	var surge_block := _card(0, [CardEffect.make(CardEffect.Kind.BLOCK, 4, 0, 0, 1, true)] as Array[CardEffect])
	surge_block.surge = true
	_check(Vendor.card_value(surge_block) == 4 * Vendor.SURGE_TYPICAL_ENERGY + Vendor.SURGE_ADJUST, "per_energy block is valued at the typical energy in amount")
