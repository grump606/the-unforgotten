extends RefCounted
## Debug launch: parsing of --fight / --character / --hp and the run-state side of a debug fight.
## Registered by run_tests.gd.

var _failures := 0


func run() -> int:
	_failures = 0
	_test_nothing_requested()
	_test_single_boss_names()
	_test_combination_and_names()
	_test_character_and_hp()
	_test_env_fallback_and_args_win()
	_test_bad_input()
	_test_list()
	_test_run_state_uses_debug_encounter()
	_test_screens()
	_test_proto()
	_test_proto_statuses()
	_test_proto_cycling()
	_test_map()
	return _failures


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAIL: " + label)


func _test_nothing_requested() -> void:
	var launch := DebugLaunch.parse(PackedStringArray(), {})
	_check(not launch.requested and launch.error == "", "no arguments means no debug fight")


func _test_single_boss_names() -> void:
	for name in ["eraser", "the_conductor", "Eraser", "conductor", "THE CONDUCTOR"]:
		var launch := DebugLaunch.parse(PackedStringArray(["--fight=" + name]), {})
		_check(launch.requested and launch.error == "" and launch.enemy_ids == [&"the_conductor"], "'%s' resolves to the Eraser" % name)
	for name in ["bellkeeper", "brakeman", "the_brakeman"]:
		var launch := DebugLaunch.parse(PackedStringArray(["--fight=" + name]), {})
		_check(launch.enemy_ids == [&"the_brakeman"], "'%s' resolves to the Bellkeeper" % name)


func _test_combination_and_names() -> void:
	var launch := DebugLaunch.parse(PackedStringArray(["--fight=wisp, Keepsake Crow,ash hound"]), {})
	_check(launch.error == "" and launch.enemy_ids == [&"skittering_wisp", &"mourning_crow", &"cinder_hound"], "a trio by alias, display name and spaced name")
	var duplicate := DebugLaunch.parse(PackedStringArray(["--fight=wisp,wisp"]), {})
	_check(duplicate.error == "" and duplicate.enemy_ids.size() == 2, "the same enemy can appear twice")
	var mixed := DebugLaunch.parse(PackedStringArray(["--fight=eraser,wisp"]), {})
	_check(mixed.error == "" and mixed.enemy_ids == [&"the_conductor", &"skittering_wisp"], "a boss can be mixed with others")
	var too_many := DebugLaunch.parse(PackedStringArray(["--fight=wisp,wisp,wisp,wisp"]), {})
	_check(too_many.error != "", "more than %d enemies is rejected" % Combat.MAX_ENEMIES)


func _test_character_and_hp() -> void:
	var launch := DebugLaunch.parse(PackedStringArray(["--fight=eraser", "--character=Medium", "--hp=20"]), {})
	_check(launch.character_id == &"medium" and launch.hp == 20, "character and hp are read")
	var default_launch := DebugLaunch.parse(PackedStringArray(["--fight=eraser"]), {})
	_check(default_launch.character_id == StarterContent.DEFAULT_CHARACTER_ID and default_launch.hp == -1, "defaults: deserter, full hp")


func _test_env_fallback_and_args_win() -> void:
	var env := {DebugLaunch.ENV_FIGHT: "crow", DebugLaunch.ENV_CHARACTER: "thief", DebugLaunch.ENV_HP: "9"}
	var from_env := DebugLaunch.parse(PackedStringArray(), env)
	_check(from_env.enemy_ids == [&"mourning_crow"] and from_env.character_id == &"thief" and from_env.hp == 9, "the environment works without arguments")
	var args_win := DebugLaunch.parse(PackedStringArray(["--fight=eraser"]), env)
	_check(args_win.enemy_ids == [&"the_conductor"], "a command-line fight overrides the environment")


func _test_bad_input() -> void:
	_check(DebugLaunch.parse(PackedStringArray(["--fight=dragon"]), {}).error != "", "an unknown enemy is an error")
	_check(DebugLaunch.parse(PackedStringArray(["--fight=wisp,"]), {}).error != "", "an empty name in the list is an error")
	_check(DebugLaunch.parse(PackedStringArray(["--fight=eraser", "--character=wizard"]), {}).error != "", "an unknown character is an error")
	_check(DebugLaunch.parse(PackedStringArray(["--fight=eraser", "--hp=abc"]), {}).error != "", "a non-numeric hp is an error")
	_check(DebugLaunch.parse(PackedStringArray(["--fight=eraser", "--hp=0"]), {}).error != "", "hp below 1 is an error")


func _test_list() -> void:
	var launch := DebugLaunch.parse(PackedStringArray(["--fight=list"]), {})
	_check(launch.requested and launch.list_only and launch.error == "", "--fight=list asks for the list")
	var text := DebugLaunch.help_text()
	_check(text.contains("the_conductor") and text.contains("skittering_wisp"), "the help text names the enemies")


func _test_run_state_uses_debug_encounter() -> void:
	var run_state := RunState.new(1, &"medium")
	_check(run_state.boss_label() == "", "a regular first stop has no boss label")
	for index in run_state.stops.size():
		if run_state.stops[index].type == RunState.StopType.COMBAT:
			run_state.stop_index = index
			break
	run_state.debug_encounter.assign([&"the_conductor"])
	_check(run_state.boss_label() == "Boss", "a debug Eraser fight gets the boss label")
	var combat := run_state.start_combat()
	_check(combat != null and combat.enemies.size() == 1 and combat.enemies[0].data.id == &"the_conductor", "the run fights the debug encounter at the current stop")
	run_state.debug_encounter.assign([&"the_brakeman"])
	_check(run_state.boss_label() == "Mid-boss", "a debug Bellkeeper fight gets the mid-boss label")
	run_state.debug_encounter.assign([&"skittering_wisp", &"mourning_crow"])
	_check(run_state.boss_label() == "", "a debug pack has no boss label")
	run_state.debug_encounter.clear()
	_check(run_state.boss_label() == "", "cleared, the run is normal again")


## The status prototypes: cards for Shaken, Frayed, Malice and Ward, and the Pest that applies them.
func _test_proto_statuses() -> void:
	# Every card file in the folder is in the explicit list, with a proto_ id, and none is a registry card.
	var listed := {}
	for path in DebugLaunch.PROTO_CARD_PATHS:
		listed[path] = true
		var card := load(path) as CardData
		_check(card != null and String(card.id).begins_with("proto_") and card.display_name.begins_with("Proto: "), "%s loads as a Proto card" % path)
	for file in DirAccess.get_files_at("res://data/prototype"):
		if file.ends_with(".tres"):
			_check(listed.has("res://data/prototype/" + file), "%s is in PROTO_CARD_PATHS" % file)
	# Every status effect has a prototype, including the debuff, temporary and self-targeted cases.
	var kinds := {}
	var has_temporary := false
	var has_debuff := false
	var has_self_cost := false
	for card in DebugLaunch.prototype_deck():
		for effect in card.effects:
			kinds[effect.kind] = true
			has_temporary = has_temporary or (effect.temporary and effect.kind == CardEffect.Kind.MALICE)
			has_debuff = has_debuff or (effect.kind == CardEffect.Kind.MALICE and effect.amount < 0 and card.target_mode == CardData.TargetMode.SINGLE_ENEMY)
			has_self_cost = has_self_cost or (effect.kind == CardEffect.Kind.SHAKEN and card.target_mode == CardData.TargetMode.SELF)
	for kind in [CardEffect.Kind.SHAKEN, CardEffect.Kind.FRAYED, CardEffect.Kind.MALICE, CardEffect.Kind.WARD]:
		_check(kinds.has(kind), "the prototype deck has a card of kind %d" % kind)
	_check(has_temporary and has_debuff and has_self_cost, "prototypes cover a temporary Malice, a Malice debuff and a self-targeted Shaken")
	# The Pest: shakes, frays, gains Malice, attacks; not in the enemy registry or any pool.
	var pest := DebugLaunch.prototype_enemy(&"proto_pest")
	_check(pest != null and pest.id == &"proto_pest" and pest.display_name.begins_with("Proto: "), "the Pest loads")
	if pest != null:
		var order: Array = []
		for intent in pest.intents:
			order.append(intent.kind)
		_check(order == [CardEffect.Kind.SHAKEN, CardEffect.Kind.FRAYED, CardEffect.Kind.MALICE, CardEffect.Kind.DAMAGE], "the Pest cycles Shaken, Frayed, Malice, attack: " + str(order))
		_check(pest.intents[2].amount > 0, "the Pest's Malice intent is a buff for itself")
	_check(StarterContent.enemy_by_id(&"proto_pest") == null and not StarterContent.enemy_ids().has(&"proto_pest"), "the Pest is not in the enemy registry")
	var pooled := false
	for enemy in StarterContent.enemy_pool():
		pooled = pooled or String(enemy.id).begins_with("proto_")
	for boss in StarterContent.boss_encounter() + StarterContent.mid_boss_encounter():
		pooled = pooled or String(boss.id).begins_with("proto_")
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for tier in 3:
		for enemy in StarterContent.varied_encounter(3, rng, tier, 0):
			pooled = pooled or String(enemy.id).begins_with("proto_")
	_check(not pooled, "the Pest is in no encounter pool")
	# --fight= takes it by id, display name and alias, and --proto works with it.
	var launch := DebugLaunch.parse(PackedStringArray(["--proto", "--fight=proto_pest"]), {})
	_check(launch.requested and launch.proto and launch.error == "" and launch.enemy_ids == [&"proto_pest"], "--proto --fight=proto_pest parses")
	_check(DebugLaunch.parse(PackedStringArray(["--fight=Proto: Pest"]), {}).enemy_ids == [&"proto_pest"], "the Pest resolves by display name")
	_check(DebugLaunch.parse(PackedStringArray(["--fight=pest,crow"]), {}).enemy_ids == [&"proto_pest", &"mourning_crow"], "the Pest resolves by alias and mixes with others")
	_check(DebugLaunch.help_text().contains("proto_pest"), "the help lists the Pest")
	# The run builds the fight from it.
	var run_state := RunState.new(1, &"thief")
	for index in run_state.stops.size():
		if run_state.stops[index].type == RunState.StopType.COMBAT:
			run_state.stop_index = index
			break
	run_state.debug_encounter.assign([&"proto_pest"])
	var combat := run_state.start_combat()
	_check(combat != null and combat.enemies.size() == 1 and combat.enemies[0].data.id == &"proto_pest", "the run fights the Pest")


func _test_screens() -> void:
	var vendor := DebugLaunch.parse(PackedStringArray(["--screen=vendor", "--character=medium"]), {})
	_check(vendor.requested and vendor.error == "" and vendor.screen == "vendor" and vendor.screen_index == 1 and vendor.enemy_ids.is_empty(), "--screen=vendor opens the first shop")
	_check(vendor.character_id == &"medium" and vendor.gold == -1 and vendor.hp == -1, "gold and hp default (the game fills them in)")
	var rest := DebugLaunch.parse(PackedStringArray(["--screen=Rest", "--gold=0", "--hp=10"]), {})
	_check(rest.screen == "rest" and rest.gold == 0 and rest.hp == 10, "rest, with gold 0 and hp 10")
	var second := DebugLaunch.parse(PackedStringArray(["--screen=vendor:2"]), {})
	_check(second.error == "" and second.screen_index == 2, "vendor:2 is the second shop")
	var from_env := DebugLaunch.parse(PackedStringArray(), {DebugLaunch.ENV_SCREEN: "rest", DebugLaunch.ENV_GOLD: "40"})
	_check(from_env.screen == "rest" and from_env.gold == 40, "the environment can request a screen")
	_check(DebugLaunch.parse(PackedStringArray(["--screen=castle"]), {}).error != "", "an unknown screen is an error")
	for special in ["select", "end", "defeat"]:
		var launch := DebugLaunch.parse(PackedStringArray(["--screen=" + special]), {})
		_check(launch.error == "" and launch.screen == special, "--screen=%s is accepted" % special)
	_check(DebugLaunch.parse(PackedStringArray(["--screen=select:2"]), {}).error != "", "select takes no number")
	_check(DebugLaunch.parse(PackedStringArray(["--screen=vendor:0"]), {}).error != "", "vendor:0 is an error")
	_check(DebugLaunch.parse(PackedStringArray(["--screen=vendor:99"]), {}).error != "", "a shop number past the end of the line is an error")
	_check(DebugLaunch.parse(PackedStringArray(["--screen=vendor", "--fight=eraser"]), {}).error != "", "a fight and a screen together is an error")
	_check(DebugLaunch.parse(PackedStringArray(["--screen=vendor", "--gold=-5"]), {}).error != "", "negative gold is an error")
	_check(DebugLaunch.screen_count("vendor") == 3 and DebugLaunch.screen_count("rest") >= 3, "the default line has three shops and several rests")
	var chest := DebugLaunch.parse(PackedStringArray(["--screen=treasure", "--character=thief"]), {})
	_check(chest.requested and chest.error == "" and chest.screen == "treasure" and chest.screen_index == 1 and chest.character_id == &"thief", "--screen=treasure opens the first act's chest")
	_check(DebugLaunch.parse(PackedStringArray(["--screen=Treasure:2"]), {}).screen_index == 2, "treasure:2 is the second act's chest")
	_check(DebugLaunch.parse(PackedStringArray(["--screen=treasure:3"]), {}).error != "", "a third act's chest does not exist")
	_check(DebugLaunch.parse(PackedStringArray(["--screen=treasure:0"]), {}).error != "", "treasure:0 is an error")
	_check(DebugLaunch.parse(PackedStringArray([]), {DebugLaunch.ENV_SCREEN: "treasure"}).screen == "treasure", "the environment can request the chest")
	_check(DebugLaunch.parse(PackedStringArray(["--screen=treasure", "--fight=eraser"]), {}).error != "", "a chest and a fight together is an error")
	_check(DebugLaunch.parse(PackedStringArray(["--screen=castle"]), {}).error.contains("treasure"), "the unknown-screen message lists the chest")


func _test_proto() -> void:
	var launch := DebugLaunch.parse(PackedStringArray(["--proto"]), {})
	_check(launch.requested and launch.proto and launch.error == "" and launch.enemy_ids.size() == 1, "--proto alone starts a fight with the prototype deck")
	launch = DebugLaunch.parse(PackedStringArray(["--proto", "--fight=crow"]), {})
	_check(launch.proto and launch.enemy_ids == [&"mourning_crow"], "--proto keeps the chosen enemy")
	_check(not DebugLaunch.parse(PackedStringArray(["--fight=crow"]), {}).proto, "no --proto means the normal deck")
	var deck := DebugLaunch.prototype_deck()
	_check(deck.size() == DebugLaunch.PROTO_CARD_PATHS.size() * DebugLaunch.PROTO_COPIES and not deck.has(null), "the prototype deck holds every prototype card")
	var in_pool := false
	for card in StarterContent.all_cards():
		in_pool = in_pool or String(card.id).begins_with("proto_")
	for character_id in StarterContent.character_ids():
		for card in StarterContent.reward_pool(character_id):
			in_pool = in_pool or String(card.id).begins_with("proto_")
	_check(not in_pool, "prototype cards are not in the card registry or any reward pool")


## The cycling prototypes (Glimpse, Recall, add card, damage per Forgotten) and the Dreadkeeper: launch
## arguments, the deck, what the Dreadkeeper does, and that none of it leaks into a registry or pool.
func _test_proto_cycling() -> void:
	var launch := DebugLaunch.parse(PackedStringArray(["--proto", "--fight=proto_dreadkeeper"]), {})
	_check(launch.requested and launch.proto and launch.error == "" and launch.enemy_ids == [&"proto_dreadkeeper"], "--proto --fight=proto_dreadkeeper parses")
	_check(DebugLaunch.parse(PackedStringArray(["--fight=dreadkeeper"]), {}).enemy_ids == [&"proto_dreadkeeper"], "the Dreadkeeper resolves by alias")
	_check(DebugLaunch.parse(PackedStringArray(["--fight=Proto: Dreadkeeper"]), {}).enemy_ids == [&"proto_dreadkeeper"], "the Dreadkeeper resolves by display name")
	_check(DebugLaunch.help_text().contains("proto_dreadkeeper"), "the help lists the Dreadkeeper")
	var enemy := DebugLaunch.prototype_enemy(&"proto_dreadkeeper")
	_check(enemy != null and enemy.max_hp == 70 and enemy.intents.size() == 4, "the Dreadkeeper has 70 HP and four intents")
	if enemy != null and enemy.intents.size() == 4:
		var first := enemy.intents[0]
		var second := enemy.intents[1]
		_check(first.kind == CardEffect.Kind.ADD_CARD and first.pile == CardEffect.Pile.DRAW and first.card != null and first.card.id == &"dread", "intent 1 shuffles a Dread into the draw pile")
		_check(second.kind == CardEffect.Kind.ADD_CARD and second.pile == CardEffect.Pile.HAND and second.card != null and second.card.id == &"murmur", "intent 2 puts a Murmur in the hand")
		_check(enemy.intents[2].kind == CardEffect.Kind.DAMAGE and enemy.intents[3].kind == CardEffect.Kind.DAMAGE and enemy.intents[3].amount > enemy.intents[2].amount, "intents 3 and 4 are a plain and a heavier attack")
	_check(Fighter.ART_KEYS.has(&"proto_dreadkeeper"), "the Dreadkeeper has a figure")
	var pooled := false
	for e in StarterContent.enemy_pool():
		pooled = pooled or String(e.id).begins_with("proto_")
	for boss in StarterContent.boss_encounter() + StarterContent.mid_boss_encounter():
		pooled = pooled or String(boss.id).begins_with("proto_")
	_check(not pooled and StarterContent.enemy_by_id(&"proto_dreadkeeper") == null, "the Dreadkeeper is in no registry or encounter pool")
	# The deck: one of each, the new kinds present, every card a proto_ card, ids unique, deck of a sensible size.
	var deck := DebugLaunch.prototype_deck()
	var ids := {}
	var kinds := {}
	for card in deck:
		ids[card.id] = true
		_check(String(card.id).begins_with("proto_") and card.display_name.begins_with("Proto: "), "%s is named as a prototype" % card.id)
		for effect in card.effects:
			kinds[effect.kind] = true
	_check(ids.size() == deck.size() and deck.size() <= 24, "the prototype deck has one of each card and stays small (%d)" % deck.size())
	for kind in [CardEffect.Kind.GLIMPSE, CardEffect.Kind.ADD_CARD, CardEffect.Kind.RECALL, CardEffect.Kind.DAMAGE_PER_FORGOTTEN]:
		_check(kinds.has(kind), "the prototype deck tries kind %d" % kind)
	_check(ids.has(&"proto_forgotten_strike"), "the deck still feeds the Forgotten pile")
	# The run builds the fight with the deck and the Dreadkeeper.
	var run_state := RunState.new(1, &"thief")
	for index in run_state.stops.size():
		if run_state.stops[index].type == RunState.StopType.COMBAT:
			run_state.stop_index = index
			break
	run_state.debug_encounter.assign([&"proto_dreadkeeper"])
	run_state.deck = deck
	var combat := run_state.start_combat()
	_check(combat != null and combat.enemies.size() == 1 and combat.enemies[0].data.id == &"proto_dreadkeeper", "the run fights the Dreadkeeper")


func _test_map() -> void:
	var off := DebugLaunch.parse(PackedStringArray(), {})
	_check(not off.map and not off.requested, "map mode is off unless asked for")
	var launch := DebugLaunch.parse(PackedStringArray(["--map"]), {})
	_check(launch.map and launch.requested and launch.error == "" and launch.screen == "" and launch.enemy_ids.is_empty(), "--map alone is a map launch")
	_check(launch.character_id == StarterContent.DEFAULT_CHARACTER_ID, "--map defaults to the Deserter")
	var medium := DebugLaunch.parse(PackedStringArray(["--map", "--character=medium"]), {})
	_check(medium.map and medium.character_id == &"medium" and medium.error == "", "--map takes --character")
	var from_env := DebugLaunch.parse(PackedStringArray(), {DebugLaunch.ENV_MAP: "1"})
	_check(from_env.map and from_env.requested, "THE_UNFORGOTTEN_MAP=1 asks for a map run")
	_check(not DebugLaunch.parse(PackedStringArray(), {DebugLaunch.ENV_MAP: "0"}).map, "THE_UNFORGOTTEN_MAP=0 does not")
	var fight := DebugLaunch.parse(PackedStringArray(["--map", "--fight=eraser"]), {})
	_check(fight.requested and fight.error == "" and fight.enemy_ids == [&"the_conductor"], "--fight still works beside --map")
	var bad := DebugLaunch.parse(PackedStringArray(["--map", "--character=wizard"]), {})
	_check(bad.error != "", "--map with an unknown character is an error")
