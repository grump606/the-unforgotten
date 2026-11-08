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