extends RefCounted
## Event stops (docs/EVENTS_DESIGN.md): the twelve events as data, every effect kind, gambles, class variants, the draw
## without replacement, determinism and resume, and the persistent curses (Dread and Murmur in the deck). Registered by
## run_tests.gd.

const CHARACTERS: Array[StringName] = [&"deserter", &"thief", &"medium", &"stray"]
const K := EventEffect.Kind

var _failures := 0
var _checks := 0
var _path := "user://event_tests_%d.json" % OS.get_process_id()


## The event with this id from the cached registry, or null.
func _event_by_id(event_id: StringName) -> EventData:
	for event in StarterContent.all_events():
		if event.id == event_id:
			return event
	return null


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FAIL: " + label)


func run() -> int:
	_failures = 0
	_checks = 0
	_test_data()
	_test_loaders()
	_test_summaries()
	_test_class_variants()
	_test_free_exit()
	_test_stop_basics()
	_test_effects()
	_test_costs_and_states()
	_test_picks()
	_test_relics()
	_test_gambles()
	_test_smart_bot_fallback()
	_test_impossible_picks()
	_test_save_after_max_hp_events()
	_test_no_repeats()
	_test_resume()
	_test_saves()
	_test_curses()
	_test_every_event_every_class()
	DirAccess.remove_absolute(_path)
	print("event_tests: %d checks" % _checks)
	return _failures


# --- Helpers --------------------------------------------------------------------------------------------

## A map run standing inside an event stop (the arrival state: boundary, nothing rolled yet). The map and the way to its
## first event node are built once per (seed, character) and shared, so a test can make a run in a millisecond.
var _event_places := {}


func _event_run(map_seed := 1, character: StringName = &"deserter") -> RunState:
	var key := "%d/%s" % [map_seed, character]
	if not _event_places.has(key):
		var found := RunState.new(map_seed, character, true)
		var guard := 0
		while guard < 50:
			var target: RouteMap.MapNode = null
			for n in found.route.nodes:
				if n.type == RouteMap.NodeType.EVENT:
					target = n
					break
			if target != null:
				var path: Array[int] = [target.id]
				while found.route.node(path[0]).row > 0:
					path.push_front(found.route.node(path[0]).prev[0])
				_event_places[key] = {"route": found.route, "node": target.id, "path": path}
				break
			guard += 1
			found = RunState.new(map_seed + 1000 * guard, character, true)
	var place: Dictionary = _event_places[key]
	var run_state := RunState.new(map_seed, character)
	run_state.restore_map(place["route"], place["node"], place["path"], true)
	return run_state


## An event with one button per effect list, opened on a fresh run (the event is installed directly).
func _custom(effect_lists: Array, character: StringName = &"deserter", map_seed := 1) -> RunState:
	var event := EventData.new()
	event.id = &"custom"
	event.title = "Custom"
	event.body = "Body."
	for effects in effect_lists:
		var choice := EventChoice.new()
		choice.label = "Do it"
		choice.outcome = "Done."
		var typed: Array[EventEffect] = []
		typed.assign(effects)
		choice.effects = typed
		event.choices.append(choice)
	var run_state := _event_run(map_seed, character)
	run_state._event = event
	return run_state


func _eff(kind: EventEffect.Kind, amount := 0) -> EventEffect:
	return EventEffect.make(kind, amount)


func _gamble(chance: int, win: Array, lose: Array = []) -> EventEffect:
	var effect := EventEffect.make(K.GAMBLE, chance)
	effect.win.assign(win)
	effect.lose.assign(lose)
	return effect


func _all_text(event: EventData) -> Array[String]:
	var texts: Array[String] = [event.title, event.body]
	for value in event.class_body.values():
		texts.append(String(value))
	for choice in event.choices:
		texts.append_array([choice.label, choice.outcome, choice.win_outcome, choice.lose_outcome])
		for value in choice.class_label.values():
			texts.append(String(value))
		for value in choice.class_outcome.values():
			texts.append(String(value))
	return texts


# --- Data -----------------------------------------------------------------------------------------------

func _test_data() -> void:
	var events := StarterContent.all_events()
	_check(events.size() == 12 and StarterContent.EVENT_PATHS.size() == 12, "there are twelve events")
	var ids := {}
	for event in events:
		_check(not ids.has(event.id) and event.id != &"", "%s: the id is unique" % event.id)
		ids[event.id] = true
		_check(StarterContent.EVENT_PATHS.has("res://data/events/%s.tres" % event.id), "%s: the file is named after the id" % event.id)
		_check(event.title != "" and event.body != "" and event.choices.size() >= 2, "%s: a title, a scene and choices" % event.id)
		_check(PaintedArt.screen_texture(event.scene) != null, "%s: its painted scene %s exists" % [event.id, event.scene])
		for text in _all_text(event):
			_check(not text.contains("—") and not text.contains("–") and not text.contains("--"), "%s: no dashes in the text (%s)" % [event.id, text.left(30)])
		for key in event.class_body:
			_check(StarterContent.CHARACTER_PATHS.has(StringName(key)), "%s: class_body names a real character (%s)" % [event.id, key])
		for choice in event.choices:
			_check(choice.label != "" and choice.outcome != "", "%s: '%s' has a label and an outcome" % [event.id, choice.label])
			for filter in [choice.only_for, choice.not_for]:
				_check(filter == &"" or StarterContent.CHARACTER_PATHS.has(filter), "%s: '%s' filters on a real character" % [event.id, choice.label])
			for key in choice.class_label:
				_check(StarterContent.CHARACTER_PATHS.has(StringName(key)), "%s: class_label names a real character" % event.id)
			for key in choice.class_outcome:
				_check(StarterContent.CHARACTER_PATHS.has(StringName(key)), "%s: class_outcome names a real character" % event.id)
			_check_effect_bounds(event.id, choice.effects, false)


func _check_effect_bounds(event_id: StringName, effects: Array[EventEffect], nested: bool) -> void:
	for effect in effects:
		var where := "%s: %s" % [event_id, EventEffect.Kind.keys()[effect.kind]]
		match effect.kind:
			K.HEAL_PERCENT:
				# Phase 4f: map fights heal the player, so no event heals more than 30% of max HP.
				_check(effect.amount >= 1 and effect.amount <= 30, "%s %d is a sane percent (at most 30 since phase 4f)" % [where, effect.amount])
			K.HEAL_FLAT:
				_check(effect.amount >= 1 and effect.amount <= 40, "%s %d is sane" % [where, effect.amount])
			K.LOSE_HP:
				_check(effect.amount >= 1 and effect.amount <= 20, "%s %d is sane" % [where, effect.amount])
			K.LOSE_HP_PERCENT:
				_check(effect.amount >= 1 and effect.amount <= 40, "%s %d is sane" % [where, effect.amount])
			K.GOLD:
				_check(effect.amount != 0 and absi(effect.amount) <= 100, "%s %d is sane" % [where, effect.amount])
			K.MAX_HP:
				_check(effect.amount != 0 and absi(effect.amount) <= 8, "%s %d is sane" % [where, effect.amount])
			K.ADD_CARD:
				_check(StarterContent.card_by_id(effect.card_id) != null and effect.count >= 1 and effect.count <= 3, "%s names a real card" % where)
			K.ADD_CURSE:
				_check(StarterContent.STATUS_CARD_PATHS.has(effect.card_id) and effect.count >= 1 and effect.count <= 3, "%s names a real status card" % where)
			K.PICK_CARD:
				_check(effect.count >= 2 and effect.count <= 5 and effect.rarity >= 0 and effect.rarity <= 2, "%s offers 2 to 5 cards of a real rarity" % where)
			K.ADD_RANDOM_CARD:
				_check(effect.count >= 1 and effect.count <= 3, "%s adds a few cards" % where)
			K.GAMBLE:
				_check(not nested, "%s is not nested in another gamble" % where)
				_check(effect.amount >= 1 and effect.amount <= 99, "%s has real odds (%d%%)" % [where, effect.amount])
				_check(not effect.win.is_empty() or not effect.lose.is_empty(), "%s does something" % where)
				_check_effect_bounds(event_id, effect.win, true)
				_check_effect_bounds(event_id, effect.lose, true)


func _test_loaders() -> void:
	_check(StarterContent._load_event("res://data/events/nope.tres") == null, "a missing event resource returns null")
	_check(StarterContent._load_event(StarterContent.SHOVE_PATH) == null, "a card resource is not accepted as an event")
	_check(StarterContent._load_event("res://data/events/rain_barrel.tres") != null, "a valid event resource loads")
	_check(_event_by_id(&"cracked_bell") != null and _event_by_id(&"cracked_bell").title == "The Cracked Bell", "an event is found by id")
	# The events are cached like the other content: the same resources come back until clear_cache().
	var first := StarterContent.all_events()
	var again := StarterContent.all_events()
	_check(first.size() == StarterContent.EVENT_PATHS.size() and again.size() == first.size() and again[0] == first[0], "all_events is served from the cache")
	again.clear()
	_check(StarterContent.all_events().size() == first.size(), "a caller trimming its copy does not touch the cache")
	StarterContent.clear_cache()
	_check(StarterContent.all_events().size() == first.size(), "clear_cache rebuilds the events")
	# The registry lists every file in data/events.
	var listed := {}
	for path in StarterContent.EVENT_PATHS:
		listed[path] = true
		_check(ResourceLoader.exists(path), "event registry path exists: %s" % path)
	for file in DirAccess.get_files_at("res://data/events"):
		if file.ends_with(".tres"):
			_check(listed.has("res://data/events/" + file), "event file is listed in StarterContent: %s (see docs/ADDING_CONTENT.md)" % file)
	_check(StarterContent.card_by_id(&"brace") != null and StarterContent.card_by_id(&"dread") == null, "card_by_id finds pool cards, not status cards")


## The printed line is made from the data, so a changed number shows at once.
func _test_summaries() -> void:
	var broker := _event_by_id(&"name_broker")
	var buy := broker.choices[0]
	_check(buy.summary() == "Pay 70 gold. Gain a random neutral relic", "the broker's buy line: %s" % buy.summary())
	_check(broker.choices[1].summary() == "Gain 45 gold. Lose 4 max HP", "the broker pays 45 gold for 4 max HP (%s)" % broker.choices[1].summary())
	_check(broker.choices[2].summary() == "", "a choice with no effects prints no cost line")
	var copy := buy.duplicate(true) as EventChoice
	copy.effects[0].amount = -75
	_check(copy.summary().begins_with("Pay 75 gold"), "changing the data changes the printed number")
	var well := _event_by_id(&"bell_in_the_well")
	_check(well.choices[0].summary() == "Pay 30 gold. 40%: Gain a random relic. Otherwise: nothing", "a gamble prints its odds: %s" % well.choices[0].summary())
	_check(well.choices[2].summary() == "50%: Gain 45 gold. Otherwise: Lose 10 HP", "a two-sided gamble prints both: %s" % well.choices[2].summary())
	var chalk := _event_by_id(&"erasers_chalk")
	_check(chalk.choices[0].summary() == "Remove a card from your deck. 30%: Remove a random card from your deck. Otherwise: nothing", "the chalk prints its second removal: %s" % chalk.choices[0].summary())
	var choir := _event_by_id(&"quiet_choir")
	_check(choir.choices[0].summary() == "Add 1 Dread to your deck. Choose 1 of 3 rare cards of your own", "the choir prints its curse and its pick: %s" % choir.choices[0].summary())
	var sentry := _event_by_id(&"empty_sentry_box")
	_check(sentry.choices[1].summary() == "Add a random neutral Block card to your deck. Gain 10 gold", "the coat prints a random Block card: %s" % sentry.choices[1].summary())
	for kind in EventEffect.Kind.values():
		var probe := EventEffect.make(kind, 5)
		probe.card_id = &"dread"
		_check(probe.describe() != "?" and probe.describe() != "", "every effect kind has a printed line (%s)" % EventEffect.Kind.keys()[kind])
	_check(int(EventEffect.Kind.HEAL_PERCENT) == 0 and int(EventEffect.Kind.GAMBLE) == 12 and int(EventEffect.Kind.LOSE_HP_PERCENT) == 14, "the effect kinds are append-only")


func _test_class_variants() -> void:
	var hound := _event_by_id(&"hound_at_the_fence")
	for character in CHARACTERS:
		var labels: Array[String] = []
		for choice in hound.choices_for(character):
			labels.append(choice.label_for(character))
		_check(labels.has("Press your nose to its nose") == (character == &"stray"), "%s: only the Stray sees the nose button" % character)
		_check(hound.body_for(character).begins_with("It smells of your own kennel") == (character == &"stray"), "%s: only the Stray reads the kennel opening" % character)
	var letters := _event_by_id(&"unsent_letters")
	_check(letters.choices_for(&"medium").size() == 4 and letters.choices_for(&"thief").size() == 3, "only the Medium answers the writers")
	var sentry := _event_by_id(&"empty_sentry_box")
	_check(sentry.choices_for(&"deserter").size() == 4 and sentry.choices_for(&"stray").size() == 3, "only the Deserter can report in")
	_check(sentry.choices_for(&"deserter")[0].outcome_for(&"deserter").begins_with("You stand the watch you walked away from") and not sentry.choices_for(&"thief")[0].outcome_for(&"thief").contains("walked away"), "the Deserter's watch reads differently")
	var well := _event_by_id(&"bell_in_the_well")
	_check(well.choices_for(&"thief")[0].gold_cost() == 25 and well.choices_for(&"deserter")[0].gold_cost() == 30 and well.choices_for(&"medium")[0].gold_cost() == 30, "the Thief pays 25 for the well, the others 30")
	_check(well.body_for(&"medium").contains("The dead do not like it rung") and not well.body_for(&"stray").contains("The dead"), "the Medium reads the well differently")
	var window := _event_by_id(&"window_that_is_lit")
	_check(window.choices_for(&"thief")[0].effects[0].amount == 80 and window.choices_for(&"stray")[0].effects[0].amount == 60, "the Thief picks the latch at 80%, others at 60%")
	var chalk := _event_by_id(&"erasers_chalk")
	var stray_first := chalk.choices_for(&"stray")[0]
	var other_first := chalk.choices_for(&"deserter")[0]
	_check(stray_first.effects.size() == 1 and other_first.effects.size() == 2, "the Stray's chalk has no second removal")
	var bell := _event_by_id(&"cracked_bell")
	_check(bell.body_for(&"deserter") != bell.body_for(&"thief") and bell.body_for(&"medium") != bell.body_for(&"thief") and bell.body_for(&"stray") == bell.body, "the cracked bell has Deserter and Medium scenes only")
	var plaques := _event_by_id(&"scraped_plaques")
	_check(plaques.choices_for(&"thief")[1].label_for(&"thief") == "Work the plaque loose" and plaques.choices_for(&"medium")[1].label_for(&"medium") == "Pry the plaque loose", "the Thief works the plaque loose")
	_check(plaques.choices_for(&"medium")[0].outcome_for(&"medium") != plaques.choices_for(&"thief")[0].outcome_for(&"thief"), "the Medium reads the half-line as a whispered name")
	var choir := _event_by_id(&"quiet_choir")
	_check(choir.choices[0].outcome_for(&"medium").begins_with("They make room for you") and choir.choices[0].outcome_for(&"stray").begins_with("The silence"), "the Medium is made room for at the choir")
	var kitchen := _event_by_id(&"stopped_kitchen")
	_check(kitchen.choices[0].outcome_for(&"deserter").contains("A mess table") and not kitchen.choices[0].outcome_for(&"medium").contains("mess table"), "the Deserter eats at a mess table")
	var barrel := _event_by_id(&"rain_barrel")
	_check(barrel.choices[0].outcome_for(&"stray").begins_with("You lap from the rim") and barrel.choices[0].outcome_for(&"thief").begins_with("The water tastes"), "the Stray laps the barrel")
	for event in StarterContent.all_events():
		for character in CHARACTERS:
			var shown := event.choices_for(character)
			_check(shown.size() >= 2 and shown.size() <= 4, "%s / %s: two to four buttons (%d)" % [event.id, character, shown.size()])


## No matter the class, the HP, the gold or the deck, an event always has a button that costs nothing.
func _test_free_exit() -> void:
	for event in StarterContent.all_events():
		for character in CHARACTERS:
			var run_state := _event_run(2, character)
			run_state.gold = 0
			run_state.player.hp = 1
			run_state._event = event
			var free := 0
			for i in run_state.event_choices().size():
				var state := run_state.event_choice_state(i)
				var choice := run_state.event_choices()[i]
				var costs := SimPolicy.event_costs(choice.effects)
				if bool(state["enabled"]) and costs["hp"] == 0 and costs["gold"] == 0 and costs["max_hp"] == 0 and costs["curses"] == 0 and not costs["gamble"]:
					free += 1
			_check(free >= 1, "%s / %s: a free enabled button exists at 0 gold and 1 HP" % [event.id, character])


# --- The stop -------------------------------------------------------------------------------------------

func _test_stop_basics() -> void:
	_check(int(RunState.StopType.EVENT) == 5 and RunState.stop_type_for_node(RouteMap.NodeType.EVENT) == RunState.StopType.EVENT, "an event node plays as the appended EVENT stop")
	var run_state := _event_run(3, &"medium")
	var stop := run_state.current_stop()
	_check(stop.type == RunState.StopType.EVENT and stop.describe() == "Event" and run_state.in_event_stop(), "an event node opens an EVENT stop")
	_check(run_state.destination_label() == "A Place Along the Way", "the place name of an event stop")
	_check(run_state.at_stop_boundary() and run_state.events_seen.is_empty(), "the arrival is a boundary with nothing rolled")
	_check(not run_state.finish_event() and not run_state.read_story() and run_state.rest() == -1, "an event cannot be left before a choice, and other stop actions fail")
	var rng_before := run_state.rng_state()
	var event := run_state.current_event()
	_check(event != null and run_state.rng_state() != rng_before, "asking for the event rolls it from the run RNG")
	_check(run_state.events_seen == [event.id] and not run_state.at_stop_boundary(), "the rolled event is recorded and the open event is not a boundary")
	var rng_open := run_state.rng_state()
	_check(run_state.current_event() == event and run_state.rng_state() == rng_open, "asking again returns the same event")
	_check(run_state.event_body() == event.body_for(&"medium") and run_state.event_choices().size() == event.choices_for(&"medium").size(), "the body and buttons are the class's own")
	var other := RunState.new(5, &"deserter", true)
	_check(other.current_event() == null and other.event_choices().is_empty() and not other.resolve_event_choice(0).ok and not other.finish_event(), "off an event stop nothing works")
	# Leaving: swap in an event with a plain leave button, then finish.
	var barrel := _event_by_id(&"rain_barrel")
	run_state._event = barrel
	run_state.events_seen.assign([barrel.id])
	event = barrel
	var leave := -1
	for i in run_state.event_choices().size():
		if run_state.event_choices()[i].effects.is_empty():
			leave = i
	_check(leave >= 0, "this event has a plain leave button")
	var result := run_state.resolve_event_choice(leave)
	_check(result.ok and result.text != "" and result.followup == &"" and run_state.event_resolved() and run_state.event_outcome() == result.text, "a free button gives its outcome and nothing owed")
	_check(not run_state.resolve_event_choice(leave).ok and not bool(run_state.event_choice_state(0)["enabled"]), "a second choice is refused and every button is disabled")
	_check(run_state.finish_event() and run_state.current_stop() == null and not run_state.reachable_nodes().is_empty() and run_state.at_stop_boundary(), "finishing leaves for the map")
	_check(not run_state.in_event_stop() and run_state.current_event() == null and not run_state.finish_event(), "the finished event is gone")
	_check(run_state.events_seen == [event.id], "the seen list keeps the event")
	_check(not run_state.resolve_event_choice(99).ok, "a bad index is refused")


func _test_effects() -> void:
	# Heal percent and flat, capped at max HP.
	var run_state := _custom([[_eff(K.HEAL_PERCENT, 25)], [_eff(K.HEAL_FLAT, 7)], [_eff(K.HEAL_PERCENT, 90)]])
	run_state.player.hp = 10
	var max_hp := run_state.player.max_hp
	_check(run_state.resolve_event_choice(0).ok and run_state.player.hp == 10 + roundi(max_hp * 0.25), "heal percent restores a share of max HP")
	run_state = _custom([[_eff(K.HEAL_FLAT, 7)]])
	run_state.player.hp = 10
	run_state.resolve_event_choice(0)
	_check(run_state.player.hp == 17, "heal flat restores HP")
	run_state = _custom([[_eff(K.HEAL_PERCENT, 90)]])
	run_state.player.hp = run_state.player.max_hp - 3
	run_state.resolve_event_choice(0)
	_check(run_state.player.hp == run_state.player.max_hp, "healing never passes max HP")
	# Losing HP stops at 1.
	run_state = _custom([[_eff(K.LOSE_HP, 10)]])
	run_state.player.hp = 25
	_check(bool(run_state.event_choice_state(0)["enabled"]) and run_state.resolve_event_choice(0).ok and run_state.player.hp == 15, "losing HP takes the HP")
	run_state = _custom([[_eff(K.LOSE_HP, 10)]])
	run_state.player.hp = 5
	_check(bool(run_state.event_choice_state(0)["enabled"]), "an HP cost stays enabled at low HP")
	run_state.resolve_event_choice(0)
	_check(run_state.player.hp == 1 and not run_state.player.is_dead(), "HP never drops below 1")
	run_state = _custom([[_eff(K.LOSE_HP_PERCENT, 50)]])
	run_state.player.hp = 20
	run_state.resolve_event_choice(0)
	_check(run_state.player.hp == maxi(20 - roundi(run_state.player.max_hp * 0.5), 1), "losing a percent of max HP is floored at 1 HP")
	# Gold.
	run_state = _custom([[_eff(K.GOLD, 30)], [_eff(K.GOLD, -20)]])
	run_state.gold = 50
	run_state.resolve_event_choice(0)
	_check(run_state.gold == 80, "gold is gained")
	run_state = _custom([[_eff(K.GOLD, -20)]])
	run_state.gold = 50
	run_state.resolve_event_choice(0)
	_check(run_state.gold == 30, "gold is paid")
	# Max HP: a rise carries HP with it, a fall caps HP.
	run_state = _custom([[_eff(K.MAX_HP, 4)]])
	run_state.player.hp = 10
	max_hp = run_state.player.max_hp
	run_state.resolve_event_choice(0)
	_check(run_state.player.max_hp == max_hp + 4 and run_state.player.hp == 14, "max HP rises and HP follows")
	run_state = _custom([[_eff(K.MAX_HP, -4)]])
	max_hp = run_state.player.max_hp
	run_state.resolve_event_choice(0)
	_check(run_state.player.max_hp == max_hp - 4 and run_state.player.hp == max_hp - 4, "max HP falls and HP is capped by it")
	run_state = _custom([[_eff(K.MAX_HP, -4)]])
	run_state.player.hp = 12
	run_state.resolve_event_choice(0)
	_check(run_state.player.hp == 12, "a fall in max HP leaves lower HP alone")
	# Add a specific card and a curse.
	var card_effect := _eff(K.ADD_CARD)
	card_effect.card_id = &"brace"
	card_effect.count = 2
	run_state = _custom([[card_effect]])
	var deck_size := run_state.deck.size()
	run_state.resolve_event_choice(0)
	_check(run_state.deck.size() == deck_size + 2 and run_state.deck[-1].id == &"brace", "ADD_CARD adds the card as many times as asked")
	var curse_effect := _eff(K.ADD_CURSE)
	curse_effect.card_id = &"dread"
	run_state = _custom([[curse_effect]])
	deck_size = run_state.deck.size()
	var result := run_state.resolve_event_choice(0)
	_check(run_state.deck.size() == deck_size + 1 and run_state.deck[-1].id == &"dread" and run_state.deck[-1].dormant and result.text.contains("Dread"), "ADD_CURSE puts a Dread in the deck")
	curse_effect.card_id = &"murmur"
	run_state = _custom([[curse_effect]])
	run_state.resolve_event_choice(0)
	_check(run_state.deck[-1].id == &"murmur" and run_state.deck[-1].fading, "ADD_CURSE can put a Murmur in the deck")
	# Random cards.
	for character in CHARACTERS:
		var neutral_block := _eff(K.ADD_RANDOM_CARD)
		neutral_block.pool = EventEffect.Pool.NEUTRAL
		neutral_block.has_effect = CardEffect.Kind.BLOCK
		var class_rare := _eff(K.ADD_RANDOM_CARD)
		class_rare.pool = EventEffect.Pool.CLASS
		class_rare.rarity = 2
		run_state = _custom([[neutral_block], [class_rare]], character)
		deck_size = run_state.deck.size()
		run_state.resolve_event_choice(0)
		var got := run_state.deck[-1]
		var has_block := false
		for effect in got.effects:
			has_block = has_block or effect.kind == CardEffect.Kind.BLOCK
		_check(run_state.deck.size() == deck_size + 1 and got.character == &"" and has_block and not got.basic, "%s: a random neutral Block card is neutral, Block and not basic (%s)" % [character, got.id])
		run_state = _custom([[class_rare]], character)
		run_state.resolve_event_choice(0)
		_check(run_state.deck[-1].character == character and run_state.deck[-1].rarity == CardData.Rarity.RARE, "%s: a random class rare is the class's own rare (%s)" % [character, run_state.deck[-1].id])


func _test_costs_and_states() -> void:
	var run_state := _custom([[_eff(K.GOLD, -30)], [_eff(K.GOLD, 10)]])
	run_state.gold = 12
	var state := run_state.event_choice_state(0)
	_check(not bool(state["enabled"]) and String(state["reason"]).contains("30") and String(state["reason"]).contains("12"), "a gold cost the player cannot pay is disabled with the reason: %s" % state["reason"])
	var gold := run_state.gold
	var hp := run_state.player.hp
	_check(not run_state.resolve_event_choice(0).ok and run_state.gold == gold and run_state.player.hp == hp and not run_state.event_resolved(), "pressing a disabled button changes nothing")
	_check(bool(run_state.event_choice_state(1)["enabled"]) and String(run_state.event_choice_state(1)["reason"]) == "", "an affordable button has no reason")
	run_state.gold = 30
	_check(bool(run_state.event_choice_state(0)["enabled"]), "exactly enough gold is enough")
	_check(String(run_state.event_choice_state(1)["summary"]) == "Gain 10 gold" and String(run_state.event_choice_state(0)["label"]) == "Do it", "a state carries the label and the printed line")
	_check(not bool(run_state.event_choice_state(7)["enabled"]), "a bad index is disabled")
	# Removal needs a second card; Remember needs a card that can be.
	var remove := _custom([[_eff(K.REMOVE_CARD)]])
	remove.deck.assign([remove.deck[0]])
	_check(not bool(remove.event_choice_state(0)["enabled"]) and String(remove.event_choice_state(0)["reason"]).contains("only one card"), "removal is disabled with a one-card deck")
	var remember := _custom([[_eff(K.REMEMBER_CARD)]])
	remember.deck.assign([StarterContent.status_card(&"dread"), StarterContent.status_card(&"murmur")])
	_check(not bool(remember.event_choice_state(0)["enabled"]) and String(remember.event_choice_state(0)["reason"]).contains("remembered"), "Remember is disabled when no card can be")


func _test_picks() -> void:
	# Choose 1 of 3.
	for character in CHARACTERS:
		var pick := _eff(K.PICK_CARD)
		pick.rarity = 1
		pick.count = 3
		var run_state := _custom([[pick, _eff(K.LOSE_HP, 4)]], character)
		var hp := run_state.player.hp
		var deck_size := run_state.deck.size()
		var result := run_state.resolve_event_choice(0)
		_check(result.ok and result.followup == &"pick" and run_state.event_followup() == &"pick", "%s: choosing a card is owed" % character)
		var offered := run_state.event_pick_choices()
		var ids := {}
		for card in offered:
			ids[card.id] = true
			_check(card.character == character and card.rarity == CardData.Rarity.UNCOMMON and not card.basic, "%s: offered %s is an uncommon of the class" % [character, card.id])
		_check(offered.size() == 3 and ids.size() == 3, "%s: three distinct cards are offered" % character)
		_check(run_state.event_pick_choices() == offered, "%s: the offer is stable" % character)
		_check(not run_state.finish_event() and not run_state.event_pick_card(StarterContent.status_card(&"dread")) and not run_state.event_remove_card(0), "%s: the event cannot be left or answered wrongly while a pick is owed" % character)
		_check(run_state.player.hp == hp - 4, "%s: the cost was paid before the pick" % character)
		_check(run_state.event_pick_card(offered[1]) and run_state.deck.size() == deck_size + 1 and run_state.deck[-1] == offered[1] and run_state.event_followup() == &"", "%s: picking adds the card and clears the debt" % character)
		_check(run_state.finish_event(), "%s: the event can be left after the pick" % character)
	# Remove.
	var run_state := _custom([[_eff(K.REMOVE_CARD), _eff(K.LOSE_HP, 6)]])
	var deck_size := run_state.deck.size()
	var result := run_state.resolve_event_choice(0)
	_check(result.followup == &"remove" and run_state.event_followup() == &"remove", "removal is owed")
	_check(not run_state.event_remove_card(-1) and not run_state.event_remove_card(deck_size) and not run_state.event_remember_card(0), "a bad removal index is refused")
	var gone := run_state.deck[3]
	_check(run_state.event_remove_card(3) and run_state.deck.size() == deck_size - 1 and run_state.event_followup() == &"" and run_state.finish_event(), "removing takes the card out")
	_check(gone != null, "the removed card existed")
	# Remember.
	for character in CHARACTERS:
		run_state = _custom([[_eff(K.REMEMBER_CARD)]], character)
		var rememberable: Array[int] = []
		for i in run_state.deck.size():
			if run_state.deck[i].can_remember():
				rememberable.append(i)
		_check(not rememberable.is_empty() and bool(run_state.event_choice_state(0)["enabled"]), "%s: the starting deck has a card to remember" % character)
		result = run_state.resolve_event_choice(0)
		_check(result.followup == &"remember" and run_state.event_remember_indices() == rememberable, "%s: Remember offers the cards that can be" % character)
		var plain_index := -1
		for i in run_state.deck.size():
			if not run_state.deck[i].can_remember():
				plain_index = i
		if plain_index != -1:
			_check(not run_state.event_remember_card(plain_index), "%s: a card that cannot be remembered is refused" % character)
		var target := rememberable[0]
		var before := run_state.deck[target]
		_check(run_state.event_remember_card(target) and run_state.deck[target].is_remembered and run_state.deck[target].base() == before, "%s: the card comes back Remembered" % character)
		_check(run_state.finish_event(), "%s: leaving after Remember" % character)
	# Several picks owed in order (the Medium's answer: Remember, and a Murmur stays).
	var letters := _event_by_id(&"unsent_letters")
	run_state = _event_run(4, &"medium")
	run_state._event = letters
	var answer := -1
	for i in run_state.event_choices().size():
		if run_state.event_choices()[i].label == "Answer the writers":
			answer = i
	var deck_before := run_state.deck.size()
	var hp_before := run_state.player.hp
	result = run_state.resolve_event_choice(answer)
	_check(result.ok and result.followup == &"remember" and run_state.deck.size() == deck_before + 1 and run_state.deck[-1].id == &"murmur" and run_state.player.hp == hp_before - 4, "the Medium's answer costs 4 HP, adds a Murmur and owes a Remember")


func _test_relics() -> void:
	for character in CHARACTERS:
		var relic_effect := _eff(K.GAIN_RELIC)
		relic_effect.pool = EventEffect.Pool.NEUTRAL
		var run_state := _custom([[relic_effect]], character)
		var result := run_state.resolve_event_choice(0)
		_check(result.ok and run_state.relics.size() == 1 and run_state.relics[0].character == &"" and StarterContent.relic_pool(character).has(run_state.relics[0]), "%s: a neutral relic from the pool is given" % character)
		_check(result.text.contains(run_state.relics[0].display_name), "%s: the outcome names the relic" % character)
	# The pool shrinks: a neutral pool with nothing neutral left never widens to the character's own relics.
	var any := _eff(K.GAIN_RELIC)
	any.pool = EventEffect.Pool.NEUTRAL
	var run_state := _custom([[any]], &"thief")
	for relic in StarterContent.relic_pool(&"thief"):
		if relic.character == &"":
			run_state.relics.append(relic)
	var neutral_state := run_state.event_choice_state(0)
	_check(bool(neutral_state["enabled"]) and run_state._event_relic_candidates(EventEffect.Pool.NEUTRAL).is_empty(), "with every neutral relic owned, a neutral relic button stays enabled")
	_check(String(neutral_state["summary"]).contains("%d gold" % RunState.EVENT_RELIC_FALLBACK_GOLD) and not String(neutral_state["summary"]).contains("relic."), "and its printed text says it pays gold now: %s" % neutral_state["summary"])
	var owned_count := run_state.relics.size()
	var plain_gold := run_state.gold
	var result := run_state.resolve_event_choice(0)
	_check(result.ok and run_state.relics.size() == owned_count and run_state.gold == plain_gold + RunState.EVENT_RELIC_FALLBACK_GOLD, "pressing it pays the fallback gold and gives no class relic")
	var full_pool := _custom([[any]], &"thief")
	_check(String(full_pool.event_choice_state(0)["summary"]).contains("neutral relic"), "with a neutral relic left the text still names the relic")
	var neutral_win := _gamble(100, [any])
	run_state = _custom([[neutral_win]], &"thief")
	for relic in StarterContent.relic_pool(&"thief"):
		if relic.character == &"":
			run_state.relics.append(relic)
	var gold_before := run_state.gold
	result = run_state.resolve_event_choice(0)
	_check(result.ok and run_state.gold == gold_before + RunState.EVENT_RELIC_FALLBACK_GOLD and run_state.relics.size() == owned_count, "a won neutral relic gamble with none left pays gold, not a class relic")
	# Never a duplicate, never past the pool; at the end the button is disabled and a gamble pays gold instead.
	run_state = _custom([[any]], &"stray")
	run_state.relics.assign(StarterContent.relic_pool(&"stray"))
	var state := run_state.event_choice_state(0)
	_check(bool(state["enabled"]) and String(state["summary"]).contains("gold"), "a relic button pays gold when nothing is left: %s" % state["summary"])
	var win := _gamble(100, [any])
	run_state = _custom([[win]], &"stray")
	run_state.relics.assign(StarterContent.relic_pool(&"stray"))
	var gold := run_state.gold
	result = run_state.resolve_event_choice(0)
	_check(result.ok and run_state.gold == gold + RunState.EVENT_RELIC_FALLBACK_GOLD and run_state.relics.size() == StarterContent.relic_pool(&"stray").size(), "a won relic gamble with nothing left pays gold instead")
	# A max-HP relic raises max HP and HP once, as in a shop.
	var flask: RelicData = null
	for candidate in StarterContent.relic_pool(&"deserter"):
		if candidate.kind == RelicData.Kind.MAX_HP:
			flask = candidate
	var any_pool := _eff(K.GAIN_RELIC)
	any_pool.pool = EventEffect.Pool.ANY
	run_state = _custom([[any_pool]], &"deserter")
	for relic in StarterContent.relic_pool(&"deserter"):
		if relic != flask:
			run_state.relics.append(relic)
	var max_before := run_state.player.max_hp
	var hp_before := run_state.player.hp
	run_state.resolve_event_choice(0)
	_check(run_state.relics.has(flask) and run_state.player.max_hp == max_before + flask.amount and run_state.player.hp == hp_before + flask.amount, "a max-HP relic from an event raises max HP and HP once")
	# Pool CLASS and ANY.
	var class_only := _eff(K.GAIN_RELIC)
	class_only.pool = EventEffect.Pool.CLASS
	run_state = _custom([[class_only]], &"medium")
	run_state.resolve_event_choice(0)
	_check(run_state.relics[0].character == &"medium", "a class pool gives the class's relic")


func _test_gambles() -> void:
	# Success and failure effects.
	var run_state := _custom([[_gamble(100, [_eff(K.GOLD, 10)], [_eff(K.LOSE_HP, 5)])], [_gamble(0, [_eff(K.GOLD, 10)], [_eff(K.LOSE_HP, 5)])]])
	var gold := run_state.gold
	var hp := run_state.player.hp
	run_state.resolve_event_choice(0)
	_check(run_state.gold == gold + 10 and run_state.player.hp == hp, "a sure gamble applies its win effects only")
	run_state = _custom([[_gamble(0, [_eff(K.GOLD, 10)], [_eff(K.LOSE_HP, 5)])]])
	gold = run_state.gold
	hp = run_state.player.hp
	run_state.resolve_event_choice(0)
	_check(run_state.gold == gold and run_state.player.hp == hp - 5, "an impossible gamble applies its lose effects only")
	# The flavour line of the choice follows the result.
	var well := _event_by_id(&"bell_in_the_well")
	var ring: EventChoice = well.choices[2]
	for chance_result in [true, false]:
		var flavoured := _event_run(6, &"stray")
		flavoured._event = well
		var index := 1
		var found := false
		for trial in 200:
			flavoured._event_resolved = false
			flavoured._event_pending.clear()
			flavoured.player.hp = flavoured.player.max_hp
			var before := flavoured.gold
			var outcome := flavoured.resolve_event_choice(index)
			var won := flavoured.gold > before
			if won == chance_result:
				_check(outcome.text.contains(ring.win_outcome if won else ring.lose_outcome), "the %s flavour is shown" % ("win" if won else "loss"))
				found = true
				break
		_check(found, "both results of the ring gamble occur")
	# Odds: the share of wins is near the printed chance (a fresh run per seed, then the rest of the stream).
	for chance in [30, 50, 60]:
		var wins := 0
		var trials := 2400
		var source := _custom([[_gamble(chance, [_eff(K.GOLD, 1)])]])
		for seed_value in trials:
			source.restore_rng_state(seed_value * 7919 + 13)
			source.gold = 0
			source._event_resolved = false
			source._event_pending.clear()
			source.resolve_event_choice(0)
			wins += source.gold
		var share := float(wins) / trials
		_check(absf(share - chance / 100.0) < 0.045, "a %d%% gamble wins about %d%% of the time over %d seeds (%.3f)" % [chance, chance, trials, share])
	# The printed odds on the buttons that gamble match their data.
	for event in StarterContent.all_events():
		for choice in event.choices:
			for effect in choice.effects:
				if effect.kind == K.GAMBLE:
					_check(choice.summary().contains("%d%%" % effect.amount), "%s: '%s' prints its %d%% odds" % [event.id, choice.label, effect.amount])
	# Gold lost inside a gamble stops at zero rather than failing.
	run_state = _custom([[_gamble(0, [], [_eff(K.GOLD, -15)])]])
	run_state.gold = 4
	_check(bool(run_state.event_choice_state(0)["enabled"]) and run_state.resolve_event_choice(0).ok and run_state.gold == 0, "gold lost in a gamble stops at 0 and the button stays enabled")
	# The second removal of the chalk never empties the deck.
	var chalk := _event_by_id(&"erasers_chalk")
	var deck_cards: Array[CardData] = [StarterContent.card_by_id(&"shove"), StarterContent.card_by_id(&"slip_past")]
	for trial in 30:
		run_state = _event_run(7, &"deserter")
		run_state._event = chalk
		run_state.deck.assign(deck_cards)
		run_state.restore_rng_state(trial * 31 + 5)
		run_state.resolve_event_choice(0)
		_check(run_state.deck.size() >= 1, "the chalk never takes the last card")
		if run_state.event_followup() == &"remove" and run_state.deck.size() > 1:
			run_state.event_remove_card(0)
		_check(run_state.deck.size() >= 1, "removing after the chalk leaves a card")


func _test_no_repeats() -> void:
	for character in CHARACTERS:
		var run_state := _event_run(8, character)
		var seen := {}
		for i in 12:
			var event := run_state.current_event()
			_check(event != null and not seen.has(event.id), "%s: event %d of 12 is new (%s)" % [character, i + 1, event.id if event != null else "?"])
			seen[event.id] = true
			# Back to the stop's start (the next "?" stop would be a different node but the same rules).
			run_state._reset_event()
		_check(seen.size() == 12 and run_state.events_seen.size() == 12, "%s: twelve stops show twelve different events" % character)
		var again := run_state.current_event()
		_check(again != null and run_state.events_seen == [again.id], "%s: after all twelve the pool is reshuffled" % character)
	# Seen events are skipped even when the list came from a save.
	var run_state := _event_run(9, &"thief")
	for event in StarterContent.all_events():
		if event.id != &"name_broker":
			run_state.events_seen.append(event.id)
	_check(run_state.current_event().id == &"name_broker", "the one event left unseen is the one drawn")
	# Over many seeds every event shows up (the draw is not stuck).
	var counts := {}
	for seed_value in 120:
		var probe := _event_run(seed_value, CHARACTERS[seed_value % 4])
		counts[probe.current_event().id] = true
	_check(counts.size() == 12, "every event is drawn first by some seed (%d)" % counts.size())


# --- Determinism, resume and saves ----------------------------------------------------------------------

func _test_resume() -> void:
	for character in CHARACTERS:
		var run_state := _event_run(10, character)
		run_state.events_seen.append(&"rain_barrel")
		_check(RunSave.save(run_state, _path) == "", "%s: the arrival save is written" % character)
		var loaded := RunSave.load_file(_path).run
		_check(loaded != null and loaded.in_event_stop() and loaded.events_seen == run_state.events_seen, "%s: the arrival save restores the stop and the seen list" % character)
		var first := run_state.current_event()
		var second := loaded.current_event()
		_check(first == second and loaded.rng_state() == run_state.rng_state(), "%s: a resumed event stop shows the same event (%s)" % [character, first.id])
		# The open event cannot be saved over the arrival save.
		_check(not run_state.at_stop_boundary() and RunSave.save(run_state, _path) != "", "%s: an open event cannot be saved" % character)
		var still := RunSave.load_file(_path).run
		var still_boundary := still != null and still.at_stop_boundary()
		_check(still_boundary and still.current_event() == first, "%s: the file still holds the arrival save" % character)
		# The same choice from the same state has the same result, gamble included.
		var well := _event_by_id(&"bell_in_the_well")
		for pick in [0, 1]:
			var a := _event_run(11, character)
			var b := _clone(a)
			a._event = well
			b._event = well
			a.gold = 90
			b.gold = 90
			var index: int = pick
			var ra := a.resolve_event_choice(index)
			var rb := b.resolve_event_choice(index)
			_check(ra.ok and rb.ok and ra.text == rb.text and a.gold == b.gold and a.relics == b.relics and a.rng_state() == b.rng_state(), "%s: the same gamble gives the same result from the same state (button %d)" % [character, index])
	# A whole stream of random events and choices repeats exactly.
	var logs: Array = []
	for pass_index in 2:
		var sim := _event_run(12, &"stray")
		var log: Array = []
		for step in 8:
			var event := sim.current_event()
			log.append(String(event.id))
			SmartPolicy.event_stop(sim)
			log.append([sim.player.hp, sim.player.max_hp, sim.gold, sim.deck.size(), sim.relics.size()])
			var path_node := sim.current_node
			sim.restore_map(sim.route, path_node, sim.visited, true)
		logs.append(log)
	_check(logs[0] == logs[1] and logs[0].size() == 16, "a bot's run of events repeats exactly")


## A smart bot that finds every enabled button scored "never" still presses the least costly one instead of aborting.
func _test_smart_bot_fallback() -> void:
	var dear := _eff(K.GOLD, -30)
	var dearer := _eff(K.GOLD, -45)
	var run_state := _custom([[dearer], [dear]])
	run_state.gold = 50 # affordable, but under SmartPolicy.EVENT_MIN_GOLD, so both score -INF
	_check(SmartPolicy.event_score(run_state, [dear] as Array[EventEffect]) == -INF and SmartPolicy.event_score(run_state, [dearer] as Array[EventEffect]) == -INF, "both payments score never at 50 gold")
	_check(SmartPolicy.event_stop(run_state), "the smart bot settles an event whose buttons all score never")
	_check(run_state.gold == 20, "it paid the cheaper button")


## Events raise max HP outside the relic path, so a map save made after them must still load, while a max HP
## above what the events could have given is still rejected.
func _test_save_after_max_hp_events() -> void:
	var one := RunSave.event_max_hp_gain(1)
	_check(one >= 6 and RunSave.event_max_hp_gain(0) == 0 and RunSave.event_max_hp_gain(2) > one, "the event bound is read from the data: the hound's +6 is the best single gain (%d)" % one)
	for event in StarterContent.all_events():
		for character in CHARACTERS:
			for i in event.choices_for(character).size():
				var sim := _event_run(3, character)
				sim._event = event
				if not bool(sim.event_choice_state(i)["enabled"]):
					continue
				sim.resolve_event_choice(i)
				var from_relics := 0 # a relic's own max HP is counted by the relic allowance, not the event one
				for relic in sim.relics:
					if relic.kind == RelicData.Kind.MAX_HP:
						from_relics += relic.amount
				_check(sim.player.max_hp - sim.character.max_hp - from_relics <= one, "%s/%s/%d: one event gives at most the bound" % [event.id, character, i])
	# The hound's best button, taken at the event's own row, loads again.
	var hound := _event_by_id(&"hound_at_the_fence")
	var best := -1
	for i in hound.choices.size():
		if RunSave._max_hp_rise(hound.choices[i].effects) == 6:
			best = i
	var run_state := _event_run(5, &"deserter")
	_check(run_state.stop_index >= 1, "the test event sits past row 0")
	run_state._event = hound
	var base := run_state.player.max_hp
	_check(best >= 0 and run_state.resolve_event_choice(best).ok, "the hound's max HP button resolves")
	var saved := RunSave.to_dict(run_state)
	_check(int(saved["max_hp"]) >= base, "the max HP is in the save")
	var loaded := RunSave.from_dict(saved)
	_check(loaded.error == "" or int(saved["max_hp"]) == base, "a map save after the hound loads: %s" % loaded.error)
	# Several events in a row: the allowance grows with the rows, and one above it is rejected.
	var fresh := RunState.new(5, &"deserter", true)
	var no_relics: Array[RelicData] = []
	var floor_hp := RunSave.max_hp_allowed(fresh, no_relics, 0, true)
	_check(floor_hp == fresh.character.max_hp + RunSave.MAX_HP_SLACK, "no rows, no event allowance")
	var tamper := RunSave.to_dict(run_state)
	var allowed := RunSave.max_hp_allowed(run_state, no_relics, run_state.stop_index, true)
	_check(allowed == floor_hp + RunSave.event_max_hp_gain(run_state.stop_index), "the allowance adds the event gain for the rows so far")
	tamper["max_hp"] = allowed
	tamper["hp"] = 1
	_check(RunSave.from_dict(tamper).error == "", "max HP at the allowance loads")
	tamper["max_hp"] = allowed + 1
	_check(RunSave.from_dict(tamper).error != "", "max HP one above the allowance is rejected")


## Picks that nothing can complete are dropped: the pick screens have no Cancel.
func _test_impossible_picks() -> void:
	var remove := _eff(K.REMOVE_CARD)
	# A removal nested in a gamble is not covered by the button's own guard: a one-card deck owes nothing.
	var run_state := _custom([[_gamble(100, [remove])]])
	var only: CardData = run_state.deck[0]
	run_state.deck.assign([only])
	_check(run_state.resolve_event_choice(0).ok and run_state.event_followup() == &"" and run_state.finish_event(), "a nested removal with one card left owes no pick and the stop can be left")
	# Two removals on a two-card deck: only one can be made, the second is dropped.
	run_state = _custom([[remove, _eff(K.REMOVE_CARD)]])
	run_state.deck.assign([run_state.deck[0], run_state.deck[1]])
	var result := run_state.resolve_event_choice(0)
	_check(result.ok and result.followup == &"remove" and run_state.event_remove_card(0) and run_state.event_followup() == &"" and run_state.finish_event() and run_state.deck.size() == 1, "two removals on two cards owe one pick, then the stop can be left")
	# A removal that shrinks the deck cancels a Remember that nothing can satisfy any more.
	run_state = _custom([[remove, _eff(K.REMEMBER_CARD)]])
	var plain: Array[CardData] = []
	for card in run_state.deck:
		if card.can_remember() and plain.size() < 1:
			plain.append(card)
	var extra: Array[CardData] = []
	for card in run_state.deck:
		if not card.can_remember():
			extra.append(card)
	run_state.deck.assign(plain + extra.slice(0, 1) if not extra.is_empty() else plain)
	if run_state.deck.size() >= 2 and run_state.deck[0].can_remember() and not run_state.deck[1].can_remember():
		run_state.resolve_event_choice(0)
		_check(run_state.event_followup() == &"remove" and run_state.event_remove_card(0) and run_state.event_followup() == &"", "removing the only rememberable card drops the owed Remember")
		_check(run_state.finish_event(), "the stop can then be left")


func _clone(run_state: RunState) -> RunState:
	var json := JSON.new()
	json.parse(JSON.stringify(RunSave.to_dict(run_state)))
	return RunSave.from_dict(json.data).run


func _test_saves() -> void:
	var run_state := _event_run(13, &"medium")
	run_state.events_seen.assign([&"rain_barrel", &"quiet_choir"])
	var data := RunSave.to_dict(run_state)
	_check(data["events_seen"] == ["rain_barrel", "quiet_choir"] and int(data["version"]) == RunSave.MAP_VERSION, "a map save writes events_seen in v5")
	var back := _clone(run_state)
	_check(back != null and back.events_seen == run_state.events_seen, "events_seen round-trips through JSON")
	# An older v5 save lacks the key and loads with nothing seen.
	var old := data.duplicate(true)
	old.erase("events_seen")
	var json := JSON.new()
	json.parse(JSON.stringify(old))
	var loaded := RunSave.from_dict(json.data)
	_check(loaded.run != null and loaded.run.events_seen.is_empty() and loaded.run.in_event_stop(), "a v5 save without events_seen loads as empty")
	# Bad shapes are refused, unknown ids dropped, repeats merged.
	var bad := data.duplicate(true)
	bad["events_seen"] = "rain_barrel"
	_check(RunSave.from_dict(bad).run == null, "events_seen must be a list")
	bad["events_seen"] = [5]
	_check(RunSave.from_dict(bad).run == null, "events_seen holds ids")
	var odd := data.duplicate(true)
	odd["events_seen"] = ["rain_barrel", "rain_barrel", "retired_event"]
	var odd_run := RunSave.from_dict(odd).run
	_check(odd_run != null and odd_run.events_seen == [&"rain_barrel"], "an unknown id is dropped and a repeat kept once")
	# A saved map with an event where the rules forbid one is refused as invalid; one that is allowed loads.
	var safe_row_node := -1
	for entry in data["map"]["nodes"]:
		if int(entry["row"]) == 2:
			safe_row_node = int(entry["id"])
	var forbidden := data.duplicate(true)
	forbidden["map"]["nodes"][safe_row_node]["type"] = int(RouteMap.NodeType.EVENT)
	var refused := RunSave.from_dict(forbidden)
	_check(refused.run == null and refused.error.contains("invalid"), "a saved map with an event in a safe row is refused (%s)" % refused.error)
	var too_far := data.duplicate(true)
	too_far["map"]["nodes"][safe_row_node]["type"] = int(RouteMap.NodeType.EVENT) + 1
	_check(RunSave.from_dict(too_far).run == null, "a saved map with a node type past the event type is refused")
	# A line save never carries the key and still loads.
	var line := RunState.new(3, &"thief")
	_check(not RunSave.to_dict(line).has("events_seen") and int(RunSave.to_dict(line)["version"]) == RunSave.LINE_VERSION, "a line save is unchanged: version 4 and no events_seen")


# --- Curses in the persistent deck ----------------------------------------------------------------------

func _curse_deck(character: StringName) -> Array[CardData]:
	var deck := StarterContent.starter_deck(character)
	deck.append(StarterContent.status_card(&"dread"))
	deck.append(StarterContent.status_card(&"murmur"))
	deck.append(StarterContent.status_card(&"dread"))
	return deck


func _test_curses() -> void:
	for character in CHARACTERS:
		# Saves: map and line formats round-trip a deck with Dread and Murmur.
		var map_run := _event_run(14, character)
		map_run.deck.assign(_curse_deck(character))
		map_run.deck[1] = map_run.deck[1].remembered_card() if map_run.deck[1].can_remember() else map_run.deck[1]
		var map_back := _clone(map_run)
		_check(map_back != null and map_back.deck.size() == map_run.deck.size(), "%s: a map save with curses loads" % character)
		var same := map_back != null
		if same:
			for i in map_run.deck.size():
				same = same and map_back.deck[i].id == map_run.deck[i].id and map_back.deck[i].is_remembered == map_run.deck[i].is_remembered
		_check(same, "%s: the map deck keeps its order, curses and upgrades" % character)
		var line_run := RunState.new(15, character)
		# A line run never meets an event, so the save's deck bound allows only a little over the starting deck;
		# two curses fit, which is enough to show the line format reads status cards.
		var line_deck := StarterContent.starter_deck(character)
		line_deck.append(StarterContent.status_card(&"murmur"))
		line_deck.append(StarterContent.status_card(&"dread"))
		line_run.deck.assign(line_deck)
		var line_back := _clone(line_run)
		_check(line_back != null and line_back.deck.size() == line_run.deck.size() and line_back.deck[-1].id == &"dread" and line_back.deck[-2].id == &"murmur", "%s: a line save with curses loads" % character)
		# A Remembered mark on a curse is refused.
		var tampered := RunSave.to_dict(map_run)
		tampered["deck"][tampered["deck"].size() - 1] = "dread+"
		_check(RunSave.from_dict(tampered).run == null, "%s: a Remembered Dread is refused" % character)
		# Combat: the curses are shuffled in, stay Dormant and survive the fight in the deck.
		var combat_run := _event_run(16, character)
		combat_run.deck.assign(_curse_deck(character))
		combat_run.restore_map(combat_run.route, combat_run.current_node, combat_run.visited, false)
		var player := combat_run.player
		var enemies: Array[EnemyData] = [StarterContent.lost_shade()]
		var combat := Combat.create(player, combat_run.deck, enemies, 77, combat_run.relics)
		var piles := combat.piles
		var total := piles.draw_pile.size() + piles.hand.size() + piles.discard_pile.size() + piles.forgotten.size()
		_check(total == combat_run.deck.size(), "%s: every card of the deck, curses included, enters the fight once (%d of %d)" % [character, total, combat_run.deck.size()])
		combat.start()
		for turn in 6:
			if combat.phase != Combat.Phase.PLAYER_TURN:
				break
			for i in combat.piles.hand.size():
				if combat.piles.hand[i].dormant:
					_check(not combat.play_card(i, 0), "%s: a curse in hand cannot be played" % character)
					break
			SimPolicy.play_turn(combat)
		_check(combat_run.deck.size() == StarterContent.starter_deck(character).size() + 3 and combat_run.deck[-1].id == &"dread", "%s: the fight neither strips nor duplicates the curses in the deck" % character)
	# A hand of nothing but curses: nothing is playable, and the turn ends.
	var all_curses: Array[CardData] = []
	for i in 12:
		all_curses.append(StarterContent.status_card(&"dread"))
	var stuck := Combat.create(Combatant.new("p", 30), all_curses, [StarterContent.lost_shade()] as Array[EnemyData], 1)
	stuck.start()
	var played := false
	for i in stuck.piles.hand.size():
		played = played or stuck.play_card(i, 0)
	_check(not played and stuck.end_player_turn(SimPolicy.discards_for(stuck)), "a hand of Dread cannot be played and the turn can still end")
	# A Murmur in hand at the end of the turn is Forgotten for the fight, as when an enemy adds it.
	var murmurs: Array[CardData] = []
	for i in 12:
		murmurs.append(StarterContent.status_card(&"murmur"))
	var fading := Combat.create(Combatant.new("p", 30), murmurs, [StarterContent.lost_shade()] as Array[EnemyData], 2)
	fading.start()
	var hand_before := fading.piles.hand.size()
	fading.end_player_turn(SimPolicy.discards_for(fading))
	_check(hand_before > 0 and fading.piles.forgotten.size() >= 1, "a Murmur left in hand is Forgotten at the end of the turn")
	# Removal: the vendor takes a curse out like any card, and events remove it too.
	var shop_deck := _curse_deck(&"deserter")
	var vendor := Vendor.new(shop_deck, RandomNumberGenerator.new(), 50)
	var size_before := shop_deck.size()
	var removed := vendor.remove_card(shop_deck.size() - 1)
	_check(removed.ok and removed.card.id == &"dread" and shop_deck.size() == size_before - 1, "the vendor removes a Dread for the usual price")
	var remover := _custom([[_eff(K.REMOVE_CARD)]])
	remover.deck.assign(_curse_deck(&"deserter"))
	remover.resolve_event_choice(0)
	var dread_index := remover.deck.size() - 1
	_check(remover.event_remove_card(dread_index) and remover.deck.size() == StarterContent.starter_deck(&"deserter").size() + 2, "an event removes a curse")
	# The bots clear a curse before anything else.
	var cleaner := _custom([[_eff(K.REMOVE_CARD)]])
	cleaner.deck.assign(_curse_deck(&"thief"))
	_check(SimPolicy.event_remove_pick(cleaner, false) == cleaner.deck.size() - 3 or cleaner.deck[SimPolicy.event_remove_pick(cleaner, false)].dormant, "the greedy bot removes a curse first")
	_check(cleaner.deck[SimPolicy.event_remove_pick(cleaner, true)].dormant, "the smart bot removes a curse first")


## Every event, every class, every button: pressing it never errors, leaves a consistent state and can be finished.
func _test_every_event_every_class() -> void:
	for event in StarterContent.all_events():
		for character in CHARACTERS:
			var buttons := event.choices_for(character).size()
			for pick in buttons:
				var run_state := _event_run(20 + pick, character)
				run_state._event = event
				run_state.gold = 100
				run_state.player.hp = maxi(run_state.player.max_hp / 2, 2)
				var state := run_state.event_choice_state(pick)
				if not bool(state["enabled"]):
					continue
				var result := run_state.resolve_event_choice(pick)
				_check(result.ok and result.text != "", "%s / %s / button %d: pressed" % [event.id, character, pick])
				var guard := 0
				while run_state.event_followup() != &"" and guard < 6:
					guard += 1
					match run_state.event_followup():
						&"remove":
							run_state.event_remove_card(0)
						&"remember":
							run_state.event_remember_card(run_state.event_remember_indices()[0])
						_:
							run_state.event_pick_card(run_state.event_pick_choices()[0])
				_check(run_state.finish_event() and run_state.player.hp >= 1 and run_state.player.hp <= run_state.player.max_hp and run_state.gold >= 0, "%s / %s / button %d: finished with sane HP and gold" % [event.id, character, pick])
				_check(run_state.deck.size() >= 1, "%s / %s / button %d: the deck is never empty" % [event.id, character, pick])
