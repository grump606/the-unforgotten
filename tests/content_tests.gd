extends RefCounted
## Content tests for the extra balance-testing cards and enemies.
## run() returns the failure count and prints a "FAIL: ..." line per failure.

var _failures := 0


func run() -> int:
	_failures = 0
	_test_new_cards_load()
	_test_new_enemies_load()
	_test_small_enemies_in_trios()
	_test_extended_deck()
	_test_existing_content_unchanged()
	_test_varied_encounter()
	_test_encounter_composition()
	_test_colossus_never_in_pairs_or_trios()
	_test_boss_encounter()
	_test_mid_boss_encounter()
	_test_registries_complete()
	_test_registry_entries_load()
	_test_enemy_registry_wiring()
	return _failures


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAIL: " + label)


func _test_new_cards_load() -> void:
	var expected := {
		StarterContent.HEAVY_BLOW_PATH: [2, [CardEffect.Kind.DAMAGE]],
		StarterContent.BRACE_PATH: [0, [CardEffect.Kind.BLOCK]],
		StarterContent.STEADY_BREATH_PATH: [1, [CardEffect.Kind.DRAW, CardEffect.Kind.BLOCK]],
		StarterContent.SHOULDER_CHARGE_PATH: [2, [CardEffect.Kind.DAMAGE, CardEffect.Kind.BLOCK]],
		StarterContent.HAMSTRING_PATH: [2, [CardEffect.Kind.DAMAGE, CardEffect.Kind.EXPOSE]],
		StarterContent.IRON_RESOLVE_PATH: [2, [CardEffect.Kind.BLOCK]],
		StarterContent.FLURRY_PATH: [0, [CardEffect.Kind.DAMAGE]],
		StarterContent.GUARDED_STRIKE_PATH: [1, [CardEffect.Kind.DAMAGE, CardEffect.Kind.BLOCK]],
	}
	var ids := {}
	for path in [StarterContent.HAMSTRING_PATH, StarterContent.IRON_RESOLVE_PATH, StarterContent.FLURRY_PATH, StarterContent.GUARDED_STRIKE_PATH]:
		var added := load(path) as CardData
		if added != null:
			_check(not ids.has(added.id), "new card id unique: %s" % path)
			ids[added.id] = true
			var price := Vendor.card_price(added)
			_check(price == Vendor.PRICE_CHEAP or price == Vendor.PRICE_MID or price == Vendor.PRICE_PRICEY, "vendor prices new card: %s" % path)
	for path in expected:
		var card := load(path) as CardData
		_check(card != null, "card loads as CardData: %s" % path)
		if card == null:
			continue
		_check(card.cost == expected[path][0], "card cost: %s" % path)
		var kinds: Array = expected[path][1]
		_check(card.effects.size() == kinds.size(), "card effect count: %s" % path)
		if card.effects.size() == kinds.size():
			for i in kinds.size():
				_check(card.effects[i].kind == kinds[i] and card.effects[i].amount > 0, "card effect %d: %s" % [i, path])


func _test_new_enemies_load() -> void:
	for path in [StarterContent.WISP_PATH, StarterContent.COLOSSUS_PATH, StarterContent.CINDER_HOUND_PATH, StarterContent.MOURNING_CROW_PATH]:
		var enemy := load(path) as EnemyData
		_check(enemy != null, "enemy loads as EnemyData: %s" % path)
		if enemy != null:
			_check(enemy.max_hp > 0 and not enemy.intents.is_empty(), "enemy has hp and intents: %s" % path)
	var wisp := StarterContent._load_enemy(StarterContent.WISP_PATH)
	var colossus := StarterContent._load_enemy(StarterContent.COLOSSUS_PATH)
	var shade := StarterContent.lost_shade()
	var warden := StarterContent.warden()
	_check(wisp != null and colossus != null and shade != null and warden != null, "all four enemies used for the role checks loaded")
	if wisp != null and colossus != null and shade != null and warden != null:
		# Relative, so retuning numbers does not break the test; the roles must hold.
		_check(wisp.max_hp < shade.max_hp, "wisp is the most fragile small enemy")
		_check(colossus.max_hp > warden.max_hp, "colossus is tankier than the warden")
		_check(wisp.intents.size() != colossus.intents.size(), "distinct intent cycle lengths")


func _test_small_enemies_in_trios() -> void:
	var small: Array[String] = [StarterContent.CINDER_HOUND_PATH, StarterContent.MOURNING_CROW_PATH]
	for path in small:
		_check(StarterContent.SMALL_ENEMY_PATHS.has(path) and StarterContent.ALL_ENEMY_PATHS.has(path), "new small enemy is registered: %s" % path)
		_check(StarterContent._trio_paths().has(path), "new small enemy may appear in trios: %s" % path)
	var hound := StarterContent._load_enemy(StarterContent.CINDER_HOUND_PATH)
	var crow := StarterContent._load_enemy(StarterContent.MOURNING_CROW_PATH)
	if hound != null and crow != null:
		_check(hound.max_hp != crow.max_hp and hound.intents.size() != crow.intents.size(), "new enemies are distinct")
		_check(hound.max_hp >= 16 and hound.max_hp <= 24 and crow.max_hp >= 16 and crow.max_hp <= 24, "new enemies are small")


func _test_extended_deck() -> void:
	var deck := StarterContent.extended_deck()
	_check(deck.size() == StarterContent.EXTENDED_DECK_SIZE and deck.size() == 14, "extended deck has 14 cards")
	var counts := {}
	for card in deck:
		counts[card.id] = counts.get(card.id, 0) + 1
		_check(card.cost >= 0 and card.cost <= 3, "extended card playable: %s" % card.id)
	var want := {&"shove": 3, &"slip_past": 2, &"glimpse_exit": 1, &"heavy_blow": 1, &"brace": 1, &"steady_breath": 1, &"shoulder_charge": 1, &"mark_the_weak": 1, &"sweep": 1, &"cutting_word": 1, &"second_wind": 1}
	_check(counts == want, "extended deck composition: %s" % str(counts))

	_test_characters_and_pools()


func _test_existing_content_unchanged() -> void:
	var deck := StarterContent.deck()
	_check(deck.size() == 10, "starter deck still 10 cards")
	_check(StarterContent.warden().display_name == "Threshold Keeper", "warden unchanged")
	_check(StarterContent.lost_shade().display_name == "The Unnamed", "lost shade unchanged")
	_check(StarterContent.early_encounter(1)[0].display_name == "Threshold Keeper", "early_encounter(1) unchanged")
	_check(StarterContent.early_encounter(3).size() == 3, "early_encounter(3) unchanged")


func _names(enemies: Array[EnemyData]) -> Array:
	var names: Array = []
	for enemy in enemies:
		names.append(enemy.display_name)
	return names


func _test_varied_encounter() -> void:
	_check(StarterContent.enemy_pool().size() == 7, "enemy pool has 7 enemies")
	var seen := {}
	for seed_value in 60:
		for requested in [-2, 0, 1, 2, 3, 9]:
			var a := RandomNumberGenerator.new()
			a.seed = seed_value
			var b := RandomNumberGenerator.new()
			b.seed = seed_value
			var first := StarterContent.varied_encounter(requested, a)
			var second := StarterContent.varied_encounter(requested, b)
			var expected_count := clampi(requested, 1, Combat.MAX_ENEMIES)
			_check(first.size() == expected_count, "varied_encounter(%d) size %d" % [requested, first.size()])
			_check(_names(first) == _names(second), "varied_encounter deterministic for seed %d" % seed_value)
			for enemy in first:
				seen[enemy.display_name] = true
	for expected_name in ["Threshold Keeper", "The Unnamed", "Stray Recollection", "Memorial Giant", "The Husher", "Ash Hound", "Keepsake Crow"]:
		_check(seen.has(expected_name), "varied_encounter uses enemy: %s" % expected_name)
	var one_rng := RandomNumberGenerator.new()
	one_rng.seed = 1
	var duplicate_check := StarterContent.varied_encounter(3, one_rng)
	for i in duplicate_check.size():
		for j in range(i + 1, duplicate_check.size()):
			_check(duplicate_check[i] != duplicate_check[j], "encounter slots own separate EnemyData")


## Packs must stay survivable: trios are all small enemies, pairs have at most one big one.
func _test_encounter_composition() -> void:
	var big_names := [StarterContent.warden().display_name, (StarterContent._load_enemy(StarterContent.COLOSSUS_PATH)).display_name]
	var saw_big_pair := false
	var saw_small_pair := false
	for seed_value in 100:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var trio := StarterContent.varied_encounter(3, rng)
		for enemy in trio:
			_check(not big_names.has(enemy.display_name), "trio has no big enemy (seed %d)" % seed_value)
			_check(enemy.display_name != StarterContent.lost_shade().display_name, "trio has no Lost Shade (seed %d)" % seed_value)
		var pair := StarterContent.varied_encounter(2, rng)
		var big_count := 0
		for enemy in pair:
			if big_names.has(enemy.display_name):
				big_count += 1
		_check(big_count <= 1, "pair has at most one big enemy (seed %d)" % seed_value)
		saw_big_pair = saw_big_pair or big_count == 1
		saw_small_pair = saw_small_pair or big_count == 0
	_check(saw_big_pair and saw_small_pair, "both pair compositions occur across seeds")


## The Colossus is a solo-only elite: it was unwinnable beside another enemy in the sim.
func _test_colossus_never_in_pairs_or_trios() -> void:
	var colossus_name: String = StarterContent._load_enemy(StarterContent.COLOSSUS_PATH).display_name
	var solo_seen := false
	for seed_value in 300:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		for count in [2, 3]:
			for enemy in StarterContent.varied_encounter(count, rng):
				_check(enemy.display_name != colossus_name, "the colossus never shares a fight (seed %d, %d enemies)" % [seed_value, count])
		for enemy in StarterContent.varied_encounter(1, rng):
			solo_seen = solo_seen or enemy.display_name == colossus_name
	_check(solo_seen, "the colossus does appear as a solo fight")


func _test_boss_encounter() -> void:
	var boss := StarterContent.boss_encounter()
	_check(boss.size() == 1 and boss[0].display_name == "Eraser", "boss_encounter is the Conductor alone")
	_check(boss[0] != StarterContent.boss_encounter()[0], "each boss encounter owns its own copy of the data")
	var pool_names := []
	for enemy in StarterContent.enemy_pool():
		pool_names.append(enemy.display_name)
	_check(not pool_names.has("Eraser"), "the boss is not in the random enemy pool")
	for seed_value in 100:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		for count in [1, 2, 3]:
			for enemy in StarterContent.varied_encounter(count, rng):
				_check(enemy.display_name != "Eraser", "the boss never appears in a random encounter (seed %d)" % seed_value)


func _test_mid_boss_encounter() -> void:
	var mid := StarterContent.mid_boss_encounter()
	_check(mid.size() == 1 and mid[0].display_name == "Bellkeeper", "mid_boss_encounter is the Brakeman alone")
	_check(mid[0] != StarterContent.mid_boss_encounter()[0], "each mid-boss encounter owns its own copy of the data")
	var boss := StarterContent.boss_encounter()[0]
	var tougher_than_all := true
	for enemy in StarterContent.enemy_pool():
		tougher_than_all = tougher_than_all and mid[0].max_hp > enemy.max_hp
	_check(tougher_than_all and mid[0].max_hp < boss.max_hp + 1, "the Brakeman has more HP than any regular enemy and no more than the Conductor")
	var kinds := {}
	for intent in mid[0].intents:
		kinds[intent.kind] = true
	_check(kinds.has(CardEffect.Kind.DAMAGE) and kinds.has(CardEffect.Kind.BLOCK) and kinds.has(CardEffect.Kind.EXPOSE), "the Brakeman mixes attacks, block and a status")
	var pool_names := []
	for enemy in StarterContent.enemy_pool():
		pool_names.append(enemy.display_name)
	_check(not pool_names.has("Bellkeeper"), "the mid-boss is not in the random enemy pool")
	for seed_value in 60:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		for tier in [0, 1]:
			for count in [1, 2, 3]:
				for enemy in StarterContent.varied_encounter(count, rng, tier, seed_value % 8):
					_check(enemy.display_name != "Bellkeeper" and enemy.display_name != "Eraser", "no boss appears in a random encounter")
	# Tier 1 draws the same number of random values as tier 0, so the run RNG stays in step.
	for count in [1, 2, 3]:
		var a := RandomNumberGenerator.new()
		a.seed = 9
		var b := RandomNumberGenerator.new()
		b.seed = 9
		StarterContent.varied_encounter(count, a, 0, 0)
		StarterContent.varied_encounter(count, b, 1, 5)
		_check(a.randi() == b.randi(), "tier and fight draw nothing extra from the rng (count %d)" % count)
	# Tier 1 pairs include a big enemy more often than tier 0.
	var big_t0 := 0
	var big_t1 := 0
	for seed_value in 400:
		var r0 := RandomNumberGenerator.new()
		r0.seed = seed_value
		var r1 := RandomNumberGenerator.new()
		r1.seed = seed_value
		for enemy in StarterContent.varied_encounter(2, r0, 0, 0):
			big_t0 += 1 if enemy.display_name == "Threshold Keeper" else 0
		for enemy in StarterContent.varied_encounter(2, r1, 1, 0):
			big_t1 += 1 if enemy.display_name == "Threshold Keeper" else 0
	_check(big_t1 > big_t0, "tier 1 pairs field the Gate Warden more often (%d vs %d of 400)" % [big_t1, big_t0])


## Characters own their starting decks and class cards; neutral cards are shared.
func _test_characters_and_pools() -> void:
	var all := StarterContent.all_cards()
	_check(all.size() == StarterContent.ALL_CARD_PATHS.size() and all.size() == 35, "all_cards loads all 35 cards")
	var ids := {}
	for card in all:
		_check(not ids.has(card.id), "card id is unique: %s" % card.id)
		ids[card.id] = true
		_check(card.character == &"" or StarterContent.CHARACTER_PATHS.has(card.character), "card %s is neutral or tagged for a known character" % card.id)
	var neutral_ids: Array = []
	for card in all:
		if card.character == &"":
			neutral_ids.append(String(card.id))
	neutral_ids.sort()
	_check(neutral_ids == ["brace", "flurry", "glimpse_exit", "shove", "slip_past", "sweep"], "the neutral pool is Brace, Flurry, Glimpse the Exit, Shove, Slip Past and Sweep")

	_check(StarterContent.character_ids() == [&"deserter", &"pickpocket", &"medium"], "three characters, in selection order")
	_check(StarterContent.character(&"nobody") == null, "an unknown character is null")
	var max_hp := {&"deserter": 52, &"pickpocket": 36, &"medium": 60}
	for id in StarterContent.character_ids():
		var character := StarterContent.character(id)
		_check(character != null and character.id == id and character.display_name != "" and character.pitch != "", "character %s loads with a name and pitch" % id)
		if character == null:
			continue
		_check(character.max_hp == max_hp[id], "character %s starts at %d HP" % [id, max_hp[id]])
		_check(character.starting_deck.size() == 10, "character %s starts with 10 cards" % id)
		for card in character.starting_deck:
			_check(card.character == &"" or card.character == id, "%s starting deck holds only neutral or own cards (%s)" % [id, card.id])
		var pool := StarterContent.reward_pool(id)
		var pool_ids := {}
		for card in pool:
			_check(not pool_ids.has(card.id), "%s pool card is distinct: %s" % [id, card.id])
			pool_ids[card.id] = true
			_check(card.character == &"" or card.character == id, "%s pool holds only neutral or own cards (%s)" % [id, card.id])
		for card in character.starting_deck:
			_check(pool_ids.has(card.id), "%s can be offered every card it starts with (%s)" % [id, card.id])
		_check(pool.size() >= 6, "%s pool can fill a three-card offer" % id)
	var deserter_ids := {}
	for card in StarterContent.reward_pool(&"deserter"):
		deserter_ids[card.id] = true
	_check(deserter_ids.has(&"heavy_blow") and not deserter_ids.has(&"hamstring"), "the Deserter can take Heavy Blow but not the Pickpocket's Hamstring")


## Registry guard: every .tres file in `dir` that is not in `registered` (or in `excluded`) fails,
## so adding a data file without listing it in StarterContent cannot go unnoticed.
func _check_registry_complete(dir: String, registered: Array, excluded: Array, label: String) -> void:
	var seen := {}
	for path in registered:
		_check(not seen.has(path), "%s registry has no duplicate: %s" % [label, path])
		seen[path] = true
		_check(ResourceLoader.exists(path), "%s registry path exists: %s" % [label, path])
	var files := DirAccess.get_files_at(dir)
	_check(not files.is_empty(), "%s directory scan found files in %s" % [label, dir])
	for file in files:
		if not file.ends_with(".tres"):
			continue
		var path := dir.path_join(file)
		_check(seen.has(path) or excluded.has(path), "%s file is missing from StarterContent: %s (see docs/ADDING_CONTENT.md)" % [label, path])


func _test_registries_complete() -> void:
	_check_registry_complete("res://data/cards", StarterContent.ALL_CARD_PATHS, [], "card")
	_check_registry_complete("res://data/relics", StarterContent.RELIC_PATHS, [], "relic")
	var characters: Array = StarterContent.CHARACTER_PATHS.values()
	_check_registry_complete("res://data/characters", characters, [], "character")
	# Bosses are deliberately outside ALL_ENEMY_PATHS (they only appear via their own encounters).
	var enemies: Array = StarterContent.ALL_ENEMY_PATHS.duplicate()
	enemies.append_array(StarterContent.BOSS_ENEMY_PATHS)
	_check_registry_complete("res://data/enemies", enemies, [], "enemy")


func _test_registry_entries_load() -> void:
	var card_ids := {}
	for path in StarterContent.ALL_CARD_PATHS:
		var card := load(path) as CardData
		_check(card != null, "card registry entry loads as CardData: %s" % path)
		if card != null:
			_check(not card_ids.has(card.id), "card id is unique: %s" % card.id)
			card_ids[card.id] = true
	var relic_ids := {}
	for path in StarterContent.RELIC_PATHS:
		var relic := load(path) as RelicData
		_check(relic != null, "relic registry entry loads as RelicData: %s" % path)
		if relic != null:
			_check(not relic_ids.has(relic.id), "relic id is unique: %s" % relic.id)
			relic_ids[relic.id] = true
	for id in StarterContent.CHARACTER_PATHS:
		var character := StarterContent.character(id)
		_check(character != null and character.id == id, "character registry key matches the resource id: %s" % id)
	_check(StarterContent.CHARACTER_PATHS.has(StarterContent.DEFAULT_CHARACTER_ID), "the default character is registered")
	_check(StarterContent.all_cards().size() == StarterContent.ALL_CARD_PATHS.size(), "all_cards loads the whole registry")
	_check(StarterContent.all_relics().size() == StarterContent.RELIC_PATHS.size(), "all_relics loads the whole registry")


## Every regular enemy must be placed in an encounter pool (or be a documented solo-only enemy), and
## every enemy (regular or boss) needs stage art keyed by its display name in Fighter.ART_KEYS.
func _test_enemy_registry_wiring() -> void:
	for path in StarterContent.ALL_ENEMY_PATHS:
		var placed: bool = StarterContent.SMALL_ENEMY_PATHS.has(path) or StarterContent.PAIR_BIG_ENEMY_PATHS.has(path) or StarterContent.SOLO_ONLY_ENEMY_PATHS.has(path)
		_check(placed, "regular enemy is in a pair/trio pool or SOLO_ONLY_ENEMY_PATHS: %s" % path)
	for pool in [StarterContent.SMALL_ENEMY_PATHS, StarterContent.PAIR_BIG_ENEMY_PATHS, StarterContent.SOLO_ONLY_ENEMY_PATHS,StarterContent.TRIO_EXCLUDED_PATHS]:
		for path in pool:
			_check(StarterContent.ALL_ENEMY_PATHS.has(path), "encounter pool entry is a registered regular enemy: %s" % path)
	var every: Array = StarterContent.ALL_ENEMY_PATHS.duplicate()
	every.append_array(StarterContent.BOSS_ENEMY_PATHS)
	var names := {}
	for path in every:
		var enemy := load(path) as EnemyData
		_check(enemy != null, "enemy registry entry loads as EnemyData: %s" % path)
		if enemy == null:
			continue
		_check(not names.has(enemy.display_name), "enemy display name is unique: %s" % enemy.display_name)
		names[enemy.display_name] = true
		_check(Fighter.ART_KEYS.has(enemy.display_name), "Fighter.ART_KEYS has an entry for '%s' (see docs/ADDING_CONTENT.md)" % enemy.display_name)
		if Fighter.ART_KEYS.has(enemy.display_name):
			_check(Fighter.HEIGHTS.has(Fighter.ART_KEYS[enemy.display_name]), "Fighter.HEIGHTS has a figure height for '%s'" % enemy.display_name)
