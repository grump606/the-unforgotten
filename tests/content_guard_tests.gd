extends "res://tests/test_base.gd"
## Small guards on shared content: Encounters.trio_paths() hands out copies, a card with a rarity outside
## CardData.Rarity is refused at load (and ignored by the picker), and the shared sim rest rule.


func run() -> int:
	_failures = 0
	_trio_paths_is_a_copy()
	_bad_rarity_is_refused()
	_picker_ignores_a_bad_rarity()
	_rest_rule()
	return _failures


func _trio_paths_is_a_copy() -> void:
	var first := Encounters.trio_paths()
	var size := first.size()
	_check(size > 0, "setup: there are trio paths")
	first.clear()
	_check(Encounters.trio_paths().size() == size, "clearing the returned array does not change the next call")


func _bad_rarity_is_refused() -> void:
	var card := CardData.make(&"odd", "Odd", 1, [CardEffect.make(CardEffect.Kind.DAMAGE, 1)] as Array[CardEffect])
	_check(ContentRegistry.has_valid_rarity(card), "a Common card is valid")
	card.rarity = CardData.Rarity.RARE
	_check(ContentRegistry.has_valid_rarity(card), "a Rare card is valid")
	card.rarity = 7 as CardData.Rarity
	_check(not ContentRegistry.has_valid_rarity(card), "rarity 7 is refused")
	card.rarity = -1 as CardData.Rarity
	_check(not ContentRegistry.has_valid_rarity(card), "rarity -1 is refused")
	for path in StarterContent.ALL_CARD_PATHS:
		_check(StarterContent._load_card(path) != null, "%s loads with a valid rarity" % path)


func _picker_ignores_a_bad_rarity() -> void:
	var good := CardData.make(&"good", "Good", 1, [CardEffect.make(CardEffect.Kind.DAMAGE, 1)] as Array[CardEffect])
	var bad := CardData.make(&"bad", "Bad", 1, [CardEffect.make(CardEffect.Kind.DAMAGE, 1)] as Array[CardEffect])
	bad.rarity = 9 as CardData.Rarity
	var pool: Array[CardData] = [bad, good]
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var picks := RarityPicker.pick_by_rarity(pool, 2, RarityPicker.rarity_weights(0), rng)
	_check(picks.size() == 1 and picks[0] == good, "a card with an impossible rarity is never picked, and the pick does not fail")
	var only_bad := RarityPicker.pick_by_rarity([bad] as Array[CardData], 1, RarityPicker.rarity_weights(0), rng)
	_check(only_bad.is_empty(), "a pool of only bad-rarity cards yields no picks")


func _rest_rule() -> void:
	var player := Combatant.new("p", 40)
	_check(SimPolicy.prefers_rest(player, false), "with nothing to Remember, rest")
	_check(not SimPolicy.prefers_rest(player, true), "at full HP with a card to Remember, remember")
	player.hp = int(SimPolicy.REST_BELOW * 40) - 1
	_check(SimPolicy.prefers_rest(player, true), "under the threshold, rest even with a card to Remember")
