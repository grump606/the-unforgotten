extends "res://tests/test_base.gd"
## Fixes from the second production review: a dead quarry's Scent (Scent rules), later effects of one card
## skipping targets an earlier effect killed, and the later engine helpers. Discovered by run_tests.gd.

const K := CardEffect.Kind
const SCENT := Combatant.Status.SCENT


func run() -> int:
	_failures = 0
	_test_dead_quarry_scent_is_not_absorbed()
	_test_later_effects_skip_dead_single_target()
	_test_surge_hp_cost_is_honest()
	_test_relic_totals_follow_the_list()
	_test_remembered_copies_every_export()
	_test_enum_tables_cover_every_value()
	_test_debug_enemy_resolver_is_injected()
	_test_hit_helpers()
	_test_save_bounds()
	return _failures


func _fx(kind: K, amount: int) -> CardEffect:
	return CardEffect.make(kind, amount)


func _fight(hand: Array[CardData], hps: Array[int]) -> Combat:
	var enemies: Array[EnemyData] = []
	for hp in hps:
		enemies.append(EnemyData.make("E", hp, [] as Array[CardEffect]))
	var combat := Combat.new(Combatant.new("p", 40), hand, enemies, 1)
	combat.start()
	return combat


## Rule: only a LIVING enemy's Scent is merged into a new mark. A dead quarry's stack is left for
## _pass_on_scent (half of it, plus the quarry-kill heal and QUARRY_DIES Oaths), which runs after the card.
func _test_dead_quarry_scent_is_not_absorbed() -> void:
	var mark := CardData.make(&"m", "M", 0, [_fx(K.SCENT, 4)] as Array[CardEffect])
	var pack := CardData.make(&"p", "P", 0, [_fx(K.DAMAGE, 9), _fx(K.SCENT, 1)] as Array[CardEffect], CardData.TargetMode.ALL_ENEMIES)
	var combat := _fight([mark, pack] as Array[CardData], [5, 100] as Array[int])
	combat.play_card(combat.piles.hand.find(mark), 0)
	_check(combat.enemies[0].stacks(SCENT) == 4, "setup: the first enemy is the quarry with 4")
	combat.play_card(combat.piles.hand.find(pack))
	_check(combat.enemies[0].is_dead(), "the quarry died to the damage effect")
	# New mark 1 + half of the dead quarry's 4 = 3 (it used to absorb the whole 4 and read 5).
	_check(combat.enemies[1].stacks(SCENT) == 3, "survivor holds the new mark plus half the dead stack, not all of it (%d)" % combat.enemies[1].stacks(SCENT))
	_check(combat.enemies[0].stacks(SCENT) == 0, "the dead quarry's stack is gone after the pass")


func _test_later_effects_skip_dead_single_target() -> void:
	var card := CardData.make(&"k", "K", 0, [_fx(K.DAMAGE, 20), _fx(K.HAUNT, 3), _fx(K.EXPOSE, 2)] as Array[CardEffect])
	var combat := _fight([card] as Array[CardData], [5, 100] as Array[int])
	combat.play_card(0, 0)
	_check(combat.enemies[0].is_dead(), "the target died")
	_check(combat.enemies[0].status_turns(Combatant.Status.HAUNTED) == 0, "a later HAUNT does not land on the corpse")
	_check(combat.enemies[0].status_turns(Combatant.Status.EXPOSED) == 0, "a later EXPOSE does not land on the corpse")


## A Surge card's LOSE_HP per_energy is multiplied by the energy it would spend, in can_play and in _apply.
func _test_surge_hp_cost_is_honest() -> void:
	var lose := CardEffect.make(K.LOSE_HP, 2, 0, 0, 1, true)
	var card := CardData.make(&"s", "S", 0, [lose] as Array[CardEffect])
	card.surge = true
	_check(card.hp_cost() == 2 and card.hp_cost(3) == 6, "hp_cost scales per_energy LOSE_HP by the energy spent")
	var combat := Combat.new(Combatant.new("p", 40, 6), [card] as Array[CardData], [EnemyData.make("E", 50, [] as Array[CardEffect])] as Array[EnemyData], 1)
	combat.start()
	_check(not combat.can_play(0), "3 energy x 2 HP = 6 would kill a 6 HP player, so the play is refused")
	var safe := Combat.new(Combatant.new("p", 40, 7), [card] as Array[CardData], [EnemyData.make("E", 50, [] as Array[CardEffect])] as Array[EnemyData], 1)
	safe.start()
	_check(safe.can_play(0) and safe.play_card(0) and safe.player.hp == 1, "at 7 HP the Surge play is allowed and costs 6")


func _test_relic_totals_follow_the_list() -> void:
	var small := RelicData.make(&"a", "A", RelicData.Kind.FIGHT_START_BLOCK, 2, 0)
	var big := RelicData.make(&"b", "B", RelicData.Kind.FIGHT_START_BLOCK, 7, 0)
	var strike := CardData.make(&"t", "T", 0, [_fx(K.DAMAGE, 1)] as Array[CardEffect])
	var enemies: Array[EnemyData] = [EnemyData.make("E", 50, [] as Array[CardEffect])]
	var combat := Combat.new(Combatant.new("p", 40), [strike] as Array[CardData], enemies, 1, [small] as Array[RelicData])
	_check(combat._relic_total(RelicData.Kind.FIGHT_START_BLOCK) == 2, "totals are built at construction")
	combat.relics = [big] as Array[RelicData]
	_check(combat._relic_total(RelicData.Kind.FIGHT_START_BLOCK) == 7, "swapping a relic (same list size) updates the totals")
	var copy := combat.relics
	copy.append(small)
	_check(combat._relic_total(RelicData.Kind.FIGHT_START_BLOCK) == 7 and combat.relics.size() == 1, "editing the returned copy changes nothing")


## Every CardData export must survive remembered_card() unless it is in the allowed-to-change list.
func _test_remembered_copies_every_export() -> void:
	var allowed := ["display_name", "cost", "effects", "oath_effects", "remembered", "forgotten", "fading", "ready", "anchor", "dormant", "surge"]
	var checked := 0
	for card in StarterContent.all_cards():
		var variant := card.remembered_card()
		if variant == null:
			continue
		checked += 1
		for prop in CardData.new().get_property_list():
			if not (prop["usage"] & PROPERTY_USAGE_STORAGE) or prop["name"] in ["script", "resource_path", "resource_name", "resource_local_to_scene"]:
				continue
			var prop_name: String = prop["name"]
			if prop_name in allowed:
				continue
			_check(card.get(prop_name) == variant.get(prop_name), "%s: export '%s' is carried into the Remembered variant" % [card.id, prop_name])
		_check(variant.is_remembered and variant.base_card == card and variant.remembered == null, "%s: the variant is marked and has no further block" % card.id)
	_check(checked > 10, "the check covered the shipped Remembered cards")


func _test_enum_tables_cover_every_value() -> void:
	for trigger in CardData.OathTrigger.values():
		_check(CardData.OATH_TRIGGER_TEXT.has(trigger), "oath trigger %d has text" % trigger)
	_check(CardData.OATH_TRIGGER_TEXT.size() == CardData.OathTrigger.size(), "no stray oath trigger text")
	for pile in CardEffect.Pile.values():
		_check(CardEffect.PILE_NAMES.has(pile), "pile %d has a name" % pile)
	_check(CardEffect.PILE_NAMES.size() == CardEffect.Pile.size(), "no stray pile name")

## RunState has no knowledge of DebugLaunch: unknown debug ids resolve only through the injected Callable.
func _test_debug_enemy_resolver_is_injected() -> void:
	var run_state := RunState.new(1, &"deserter")
	for index in run_state.stops.size():
		if run_state.stops[index].type == RunState.StopType.COMBAT:
			run_state.stop_index = index
			break
	_check(not run_state.debug_enemy_resolver.is_valid(), "no resolver by default")
	var resolver := func(enemy_id: StringName) -> EnemyData:
		return EnemyData.make("Stub", 7, [] as Array[CardEffect]) if enemy_id == &"stub_enemy" else null
	run_state.debug_enemy_resolver = resolver
	run_state.debug_encounter.assign([&"stub_enemy"])
	var combat := run_state.start_combat()
	_check(combat != null and combat.enemies.size() == 1 and combat.enemies[0].data.max_hp == 7, "an injected resolver supplies the enemy")
	run_state.debug_encounter.assign([&"the_wisp_that_does_not_exist"])
	run_state.debug_enemy_resolver = Callable()
	_check(run_state.start_combat() == null, "an unknown id with no resolver yields no fight")

## The shared Block-absorption and damage-preview helpers (Combatant.block_split / hits_outcome, Combat.preview_hit).
func _test_hit_helpers() -> void:
	_check(Combatant.block_split(5, 20, 3) == Vector2i(3, 0), "block absorbs a small hit")
	_check(Combatant.block_split(2, 20, 7) == Vector2i(2, 5), "block absorbs part of a bigger hit")
	_check(Combatant.block_split(0, 4, 9) == Vector2i(0, 4), "HP lost is capped at the HP left")
	_check(Combatant.block_split(3, 3, -5) == Vector2i(0, 0), "a negative amount is nothing")
	_check(Combatant.frayed_amount(4) == 3 and Combatant.frayed_amount(1) == 1 and Combatant.frayed_loss(4) == 1 and Combatant.frayed_loss(0) == 0, "the Frayed formula lives on Combatant")
	var player := Combatant.new("p", 40)
	var dummy := Combatant.new("e", 20)
	dummy.gain_block(5)
	var out := Combatant.hits_outcome(player, dummy, 3, 3)
	_check(out["damage"] == 9 and out["absorbed"] == 5 and out["through"] == 4 and out["lost"] == 4 and out["block_left"] == 0, "three hits of 3 against 5 Block: %s" % str(out))
	_check(Combatant.hits_outcome(player, dummy, 3, 99)["lost"] == 20, "overkill is not counted in lost")
	_check(Combatant.hits_outcome(player, dummy, 3, 99)["through"] == 99 * 3 - 5, "through is not capped by HP")
	_check(Combatant.hits_outcome(player, dummy, 3, 1, 0)["lost"] == 3, "a block override replaces the target's Block")
	# preview_hit equals what _apply really does, including Malice, Expose and a multi-hit.
	var strike := CardEffect.make(K.DAMAGE, 3, 0, 0, 2)
	var card := CardData.make(&"x", "X", 0, [strike] as Array[CardEffect])
	var combat := _fight([card] as Array[CardData], [30] as Array[int])
	combat.player.apply_status(Combatant.Status.MALICE, 1)
	combat.enemies[0].apply_status(Combatant.Status.EXPOSED, 1)
	combat.enemies[0].gain_block(3)
	var preview := combat.preview_hit(strike, combat.player, combat.enemies[0], combat.plays_this_turn + 1)
	var hp_before := combat.enemies[0].hp
	combat.play_card(0, 0)
	_check(hp_before - combat.enemies[0].hp == preview["lost"], "preview_hit matches the real HP loss (%s)" % str(preview))
	_check(combat.hit_amount(strike, combat.player, combat.enemies[0], 1) == Combatant.hit_damage(3, combat.player, combat.enemies[0]), "hit_amount is the shared single-hit rule")
	_check(SimPolicy.is_damage_card(CardData.make(&"h", "H", 0, [_fx(K.HAUNT, 2)] as Array[CardEffect])) and SimPolicy.is_damage_card(card) and not SimPolicy.is_damage_card(CardData.make(&"b", "B", 0, [_fx(K.BLOCK, 2)] as Array[CardEffect])), "is_damage_card is is_damage() plus Haunt")

## RunSave bounds: max HP follows the character plus the MAX_HP relics, deck copies are capped, and real runs
## played by the sim policies still save and load at every stop boundary.
func _test_save_bounds() -> void:
	var run := RunState.new(1, &"deserter")
	var saved := RunSave.to_dict(run)
	_check(RunSave.from_dict(saved).error == "", "a fresh save loads")
	var edited := saved.duplicate(true)
	edited["max_hp"] = 9999
	edited["hp"] = 9999
	_check(RunSave.from_dict(edited).error != "", "a hand-edited max_hp of 9999 is rejected")
	var limit := run.character.max_hp + RunSave.MAX_HP_SLACK
	edited["max_hp"] = limit
	edited["hp"] = 1
	_check(RunSave.from_dict(edited).error == "", "max_hp within the documented slack loads")
	edited["max_hp"] = limit + 1
	_check(RunSave.from_dict(edited).error != "", "one above the slack is rejected")
	# A MAX_HP relic raises the allowance by its amount.
	var hp_relic: RelicData = null
	for relic in StarterContent.relic_pool(&"deserter"):
		if relic.kind == RelicData.Kind.MAX_HP:
			hp_relic = relic
	if hp_relic != null:
		edited["stop_index"] = 6 # past the first vendor: a run carries a relic only after a visit
		edited["relics"] = [String(hp_relic.id)]
		edited["max_hp"] = limit + hp_relic.amount
		_check(RunSave.from_dict(edited).error == "", "max_hp covered by a carried MAX_HP relic loads")
		edited["max_hp"] = limit + hp_relic.amount + 1
		_check(RunSave.from_dict(edited).error != "", "max_hp above base + relic + slack is rejected")
	# Deck copies.
	var crowded := saved.duplicate(true)
	var deck: Array = []
	for _i in 60:
		deck.append("shove")
	crowded["deck"] = deck
	_check(RunSave.from_dict(crowded).error != "", "60 copies of one card is rejected")
	_check(RunSave.max_copies(run, &"shove", 0) >= 3, "a card the run starts with can be held at least as often as it starts")
	for character_id in StarterContent.character_ids():
		for seed_value in 2:
			_check(_played_run_round_trips(character_id, seed_value), "a played %s run (seed %d) saves and loads at every stop" % [character_id, seed_value])


func _played_run_round_trips(character_id: StringName, seed_value: int) -> bool:
	var run := RunState.new(seed_value, character_id)
	var guard := 0
	while not run.finished and guard < 60:
		guard += 1
		if run.at_stop_boundary():
			var loaded := RunSave.from_dict(JSON.parse_string(JSON.stringify(RunSave.to_dict(run))))
			if loaded.error != "":
				printerr("round trip failed: ", loaded.error)
				return false
		match run.current_stop().type:
			RunState.StopType.COMBAT:
				var combat := run.start_combat()
				combat.start()
				while SimPolicy.is_acting(combat) and combat.turn < 50:
					if not SmartPolicy.play_turn(combat):
						return false
				var won := combat.phase == Combat.Phase.ENDED and not combat.player.is_dead()
				combat.abandon()
				run.complete_combat(won)
				if won and run.reward_pending():
					SmartPolicy.take_reward(run)
			RunState.StopType.REST:
				SimPolicy.rest_stop(run, true)
			RunState.StopType.STORY:
				run.read_story()
			RunState.StopType.VENDOR:
				SmartPolicy.shop(run)
	return true