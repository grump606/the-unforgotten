extends RefCounted
## Phase 4a groundwork: the fight-only created-card loader, per-class starter decks, the saves of runs
## started with an older deck, and the retuned neutral cards (Glimpse the Exit, Flurry). Registered by
## run_tests.gd. Fixtures are built in code; cards come through StarterContent.

const SIGNATURE := {&"thief": &"sleight", &"deserter": &"dig_in", &"medium": &"cold_whisper"}

var _failures := 0


func run() -> int:
	_failures = 0
	_test_created_cards_are_isolated()
	_test_created_card_loader()
	_test_starter_decks()
	_test_starter_deck_fallback()
	_test_runs_start_with_the_starter_deck()
	_test_legacy_shared_deck_save_loads()
	_test_new_run_save_round_trips()
	_test_flurry_is_two_hits()
	_test_glimpse_exit_order()
	return _failures


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAIL: " + label)


func _ids(cards: Array) -> Array:
	var out: Array = []
	for card in cards:
		out.append(String(card.id))
	return out


func _counts(cards: Array) -> Dictionary:
	var counts := {}
	for card in cards:
		counts[card.id] = counts.get(card.id, 0) + 1
	return counts


func _fight(deck: Array[CardData], enemy_hp: int = 100) -> Combat:
	var datas: Array[EnemyData] = [EnemyData.make("E", enemy_hp, [] as Array[CardEffect])]
	var combat := Combat.new(Combatant.new("p", 100), deck, datas, 0)
	combat.start()
	return combat


func _blank(id: String) -> CardData:
	var none: Array[CardEffect] = []
	return CardData.make(StringName(id), id, 0, none, CardData.TargetMode.SELF)


## Created cards are never in a registry, a pool, the price table or a starting deck. The list is empty
## until the first one ships, so every loop below also holds for an empty list.
func _test_created_cards_are_isolated() -> void:
	var registry_ids := {}
	for card in StarterContent.all_cards():
		registry_ids[card.id] = true
	for path in StarterContent.ALL_CARD_PATHS:
		_check(not path.begins_with("res://data/created"), "the registry paths never point into data/created")
	var golden: Dictionary = load("res://tests/vendor_tests.gd").get_script_constant_map()["GOLDEN"]
	for id in StarterContent.CREATED_CARD_PATHS:
		var path: String = StarterContent.CREATED_CARD_PATHS[id]
		_check(path.begins_with("res://data/created/"), "created card %s lives in data/created" % id)
		_check(not StarterContent.ALL_CARD_PATHS.has(path), "created card %s is not in ALL_CARD_PATHS" % id)
		_check(not registry_ids.has(id), "created card %s is not in the card registry" % id)
		_check(not golden.has(String(id)), "created card %s is not in the price table" % id)
		for character in StarterContent.character_ids():
			_check(not _ids(StarterContent.reward_pool(character)).has(String(id)), "created card %s is not in the %s reward pool" % [id, character])
			_check(not _ids(StarterContent.starter_deck(character)).has(String(id)), "created card %s is not in the %s starter deck" % [id, character])
		_check(not _ids(StarterContent.deck() + StarterContent.extended_deck()).has(String(id)), "created card %s is not in a neutral deck" % id)
	# Nothing in data/created is missing from the list either.
	var dir := DirAccess.open("res://data/created")
	_check(dir != null, "the data/created folder exists")
	if dir == null:
		return
	var listed := {}
	for id in StarterContent.CREATED_CARD_PATHS:
		listed[StarterContent.CREATED_CARD_PATHS[id]] = true
	for file in dir.get_files():
		if file.ends_with(".tres"):
			_check(listed.has("res://data/created/" + file), "data/created/%s is listed in CREATED_CARD_PATHS" % file)


func _test_created_card_loader() -> void:
	for id in StarterContent.CREATED_CARD_PATHS:
		var card := StarterContent.created_card(id)
		_check(card != null and card.id == id, "created card %s loads under its own id" % id)
		_check(card == null or StarterContent.created_card(id) == card, "the created-card loader returns the shared resource for %s" % id)
	_check(StarterContent.created_card(&"no_such_card") == null, "an unknown created card id is null (and logs an error)")
	# A status card is not a created card, and a created id is not a status card.
	_check(StarterContent.created_card(&"dread") == null, "the created loader does not serve status cards")
	for id in StarterContent.CREATED_CARD_PATHS:
		_check(not StarterContent.STATUS_CARD_PATHS.has(id), "created card %s is not also a status card" % id)


func _test_starter_decks() -> void:
	for id in StarterContent.character_ids():
		var deck := StarterContent.starter_deck(id)
		_check(deck.size() == 10, "%s starter deck has 10 cards" % id)
		var want := {&"shove": 5, &"slip_past": 3, &"glimpse_exit": 1, SIGNATURE[id]: 1}
		_check(_counts(deck) == want, "%s starter deck is 5 Shove, 3 Slip Past, Glimpse the Exit and %s: %s" % [id, SIGNATURE[id], str(_counts(deck))])
		for card in deck:
			_check(card.character == &"" or card.character == id, "%s starter deck holds no other class's card (%s)" % [id, card.id])
		var signature_cards: Array[CardData] = []
		for card in deck:
			if card.character == id:
				signature_cards.append(card)
		_check(signature_cards.size() == 1 and signature_cards[0].id == SIGNATURE[id], "%s starts with exactly its signature card" % id)
		var pool_ids := _ids(StarterContent.reward_pool(id))
		for card in deck:
			_check(pool_ids.has(String(card.id)), "%s can be offered every card it starts with (%s)" % [id, card.id])
		_check(deck == StarterContent.character(id).starting_deck, "%s starter deck matches the character resource" % id)
		deck.append(deck[0])
		_check(StarterContent.starter_deck(id).size() == 10, "%s: editing a returned starter deck leaves the next one alone" % id)


func _test_starter_deck_fallback() -> void:
	var neutral := StarterContent.deck()
	_check(neutral.size() == 10, "the neutral deck is still 10 cards")
	_check(_counts(StarterContent.starter_deck(&"nobody")) == _counts(neutral), "an unknown character falls back to the neutral deck")
	_check(_counts(StarterContent.starter_deck(&"")) == _counts(neutral), "an empty character id falls back to the neutral deck")


func _test_runs_start_with_the_starter_deck() -> void:
	for id in StarterContent.character_ids():
		var state := RunState.new(5, id)
		_check(state.deck == StarterContent.starter_deck(id), "a %s run starts with the %s starter deck" % [id, id])


## A save made before the starter decks changed holds card ids, so it still loads: every id is in the
## character's pool. These are the 10-card decks the three characters used to start with.
func _test_legacy_shared_deck_save_loads() -> void:
	var old_decks := {
		&"thief": ["shove", "shove", "shove", "slip_past", "slip_past", "glimpse_exit", "mark_the_weak", "lift", "sleight", "last_pocket"],
		&"deserter": ["shove", "shove", "shove", "slip_past", "slip_past", "glimpse_exit", "shoulder_charge", "iron_resolve", "hold_the_line", "bash"],
		&"medium": ["shove", "shove", "shove", "slip_past", "slip_past", "glimpse_exit", "confess", "lingering_dread", "penance", "cold_whisper"],
	}
	for id in old_decks:
		var data := RunSave.to_dict(RunState.new(9, id))
		data["deck"] = old_decks[id]
		var loaded := RunSave.from_dict(data)
		_check(loaded.run != null, "%s: a save of a run started with the old deck still loads" % id)
		if loaded.run != null:
			_check(_ids(loaded.run.deck) == old_decks[id], "%s: the old deck comes back card for card" % id)
	# The old neutral 10-card deck (4 Slip Past) also loads for every class.
	for id in StarterContent.character_ids():
		var data := RunSave.to_dict(RunState.new(9, id))
		data["deck"] = _ids(StarterContent.deck())
		_check(RunSave.from_dict(data).run != null, "%s: the neutral deck loads from a save" % id)


func _test_new_run_save_round_trips() -> void:
	for id in StarterContent.character_ids():
		var state := RunState.new(9, id)
		var loaded := RunSave.from_dict(RunSave.to_dict(state))
		_check(loaded.run != null and _ids(loaded.run.deck) == _ids(state.deck), "%s: a fresh run's starter deck round-trips through a save" % id)


func _test_flurry_is_two_hits() -> void:
	var flurry := load("res://data/cards/flurry.tres") as CardData
	_check(flurry.cost == 0 and flurry.effects.size() == 1, "Flurry costs 0 and has one effect")
	var effect := flurry.effects[0]
	_check(effect.kind == CardEffect.Kind.DAMAGE and effect.amount == 2 and effect.hits == 2, "Flurry is Deal 2 with two hits")
	_check(effect.describe() == "Deal 2 x2", "Flurry reads Deal 2 x2 (got %s)" % effect.describe())
	var open := _fight([flurry] as Array[CardData])
	_check(open.play_card(0), "Flurry plays")
	_check(open.enemies[0].hp == 100 - 4, "two hits of 2 against no Block deal 4")
	var blocked := _fight([flurry] as Array[CardData])
	blocked.enemies[0].block = 3
	blocked.play_card(0)
	_check(blocked.enemies[0].block == 0 and blocked.enemies[0].hp == 100 - 1, "two hits of 2 against 3 Block: the first leaves 1 Block, the second loses 1 Block and deals 1")


## The choice opens only after the whole card has resolved, so Draw 1 happens first and Glimpse then
## looks at what is now on top of the draw pile.
func _test_glimpse_exit_order() -> void:
	var glimpse_exit := load("res://data/cards/glimpse_exit.tres") as CardData
	_check(glimpse_exit.cost == 0 and glimpse_exit.effects.size() == 2, "Glimpse the Exit costs 0 and has two effects")
	_check(glimpse_exit.effects[0].kind == CardEffect.Kind.GLIMPSE and glimpse_exit.effects[0].amount == 3, "its first effect is Glimpse 3")
	_check(glimpse_exit.effects[1].kind == CardEffect.Kind.DRAW and glimpse_exit.effects[1].amount == 1, "its second effect is Draw 1")
	# The top of the draw pile is the END of the array, so Draw 1 takes d and the Glimpse sees c, b, a.
	var a := _blank("a")
	var b := _blank("b")
	var c := _blank("c")
	var d := _blank("d")
	var combat := _fight([glimpse_exit] as Array[CardData])
	combat.piles.draw_pile.append_array([a, b, c, d])
	_check(combat.play_card(combat.piles.hand.find(glimpse_exit)), "Glimpse the Exit plays")
	_check(combat.piles.hand.has(d) and combat.piles.hand.size() == 1, "Draw 1 resolved first: the top card is in hand")
	_check(combat.phase == Combat.Phase.CHOOSING and combat.choice_kind() == CardEffect.Kind.GLIMPSE, "then a Glimpse choice opens")
	var seen: Array = []
	for card in combat.choice_cards():
		seen.append(String(card.id))
	_check(seen == ["c", "b", "a"], "the Glimpse looks at the three cards left under the drawn one (got %s)" % str(seen))
	_check(combat.resolve_choice([0] as Array[int]), "pick one to discard")
	_check(combat.piles.discard_pile.has(c) and combat.piles.draw_pile.size() == 2 and combat.phase == Combat.Phase.PLAYER_TURN, "the pick is discarded and play resumes")
