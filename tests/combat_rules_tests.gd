extends "res://tests/test_base.gd"
## Review fixes in the combat layer: the first-Forgotten-return relic with Oath cards, ramp scaling that
## keeps phase two, the shared rule helpers the bots call, and the content cache. Registered by run_tests.gd.


func run() -> int:
	_failures = 0
	_test_forgotten_return_ignores_oaths()
	_test_scaled_keeps_phase_two()
	_test_shared_rule_helpers()
	_test_is_damage_kinds()
	_test_content_cache()
	return _failures


func _fight(card: CardData, relics: Array[RelicData], enemy_intents: Array[CardEffect] = [], enemy_count: int = 1) -> Combat:
	var deck: Array[CardData] = []
	for i in 10:
		deck.append(card)
	var datas: Array[EnemyData] = []
	for i in enemy_count:
		datas.append(EnemyData.make("E%d" % i, 99, enemy_intents))
	var combat := Combat.new(Combatant.new("p", 40), deck, datas, 5, relics)
	combat.start()
	return combat


func _test_forgotten_return_ignores_oaths() -> void:
	var relics: Array[RelicData] = [RelicData.make(&"r", "R", RelicData.Kind.FIRST_FORGOTTEN_RETURN, 1, 10)]
	var plain_effects: Array[CardEffect] = [CardEffect.make(CardEffect.Kind.DAMAGE, 1)]
	var oath := CardData.make(&"o", "O", 0, plain_effects)
	oath.oath = true
	oath.forgotten = true
	var forgotten := CardData.make(&"f", "F", 0, plain_effects)
	forgotten.forgotten = true
	var fight := _fight(oath, relics)
	# An earlier Forgotten card sits in the pile; playing a Forgotten Oath must not recall it.
	fight.piles.forgotten.append(forgotten)
	var hand_before := fight.piles.hand.size()
	_check(fight.play_card(0), "the Forgotten Oath plays")
	_check(fight.piles.sworn.size() == 1 and fight.piles.forgotten.size() == 1, "the Oath is Sworn, the old card stays Forgotten")
	_check(fight.piles.hand.size() == hand_before - 1, "no card returned to hand for an Oath")
	# The relic is still unspent, so the next real Forgotten card comes back.
	fight.piles.hand[0] = forgotten
	var hand_now := fight.piles.hand.size()
	_check(fight.play_card(0), "the Forgotten card plays")
	_check(fight.piles.hand.size() == hand_now and fight.piles.forgotten.size() == 1, "the first real Forgotten card still returns once")
	# An Oath with an empty Forgotten pile used to read index -1.
	var alone := _fight(oath, relics)
	_check(alone.play_card(0) and alone.piles.forgotten.is_empty() and alone.piles.sworn.size() == 1, "a Forgotten Oath with an empty pile plays cleanly")


func _test_scaled_keeps_phase_two() -> void:
	var first: Array[CardEffect] = [CardEffect.make(CardEffect.Kind.DAMAGE, 10), CardEffect.make(CardEffect.Kind.BLOCK, 4)]
	var second: Array[CardEffect] = [CardEffect.make(CardEffect.Kind.DAMAGE, 20, 0, 0, 2)]
	var boss := EnemyData.make("Boss", 100, first, &"boss", 7)
	boss.phase_two_intents = second
	boss.phase_two_hp_percent = 40
	boss.phase_two_title = "Rage"
	var ramped := StarterContent.scaled(boss, 1.5)
	_check(ramped != boss and ramped.max_hp == 150 and ramped.max_haunt == 7 and ramped.id == &"boss", "scaled keeps id and haunt cap and ramps HP")
	_check(ramped.intents[0].amount == 15 and ramped.intents[1].amount == 4, "phase one damage ramps, block does not")
	_check(ramped.phase_two_intents.size() == 1 and ramped.phase_two_intents[0].amount == 30 and ramped.phase_two_intents[0].hits == 2, "phase two intents survive and ramp")
	_check(ramped.phase_two_hp_percent == 40 and ramped.phase_two_title == "Rage", "phase two threshold and title survive")
	_check(boss.intents[0].amount == 10 and boss.phase_two_intents[0].amount == 20, "the source resource is untouched")
	_check(StarterContent.scaled(boss, 1.0) == boss, "factor 1 returns the enemy itself")


func _test_shared_rule_helpers() -> void:
	var swing: Array[CardEffect] = [CardEffect.make(CardEffect.Kind.DAMAGE, 6, 0, 0, 2)]
	var card := CardData.make(&"t", "T", 1, [CardEffect.make(CardEffect.Kind.DAMAGE, 1)] as Array[CardEffect])
	var fight := _fight(card, [] as Array[RelicData], swing, 2)
	_check(fight.incoming_damage() == 24 and fight.intent_hit(fight.enemies[0]) == 12, "incoming damage sums every living enemy's hits")
	_check(fight.haunted_count() == 0 and fight.scent_holder_index() == -1, "nothing Haunted or Scented at the start")
	fight.enemies[1].apply_status(Combatant.Status.HAUNTED, 2)
	fight.enemies[1].apply_status(Combatant.Status.SCENT, 3)
	_check(fight.haunted_count() == 1 and fight.scent_holder_index() == 1 and Combat.holds_scent(fight.enemies[1]), "Haunt and Scent are found on the second enemy")
	fight.enemies[1].lose_hp(99)
	_check(fight.haunted_count() == 0 and fight.scent_holder_index() == -1 and fight.incoming_damage() == 12, "a dead enemy counts for none of them")
	# The bots price a not-yet-played card as play number plays_this_turn + 1.
	var per_play := CardEffect.make(CardEffect.Kind.DAMAGE_PER_PLAY, 2, 3)
	_check(SmartPolicy._effect_damage(fight, per_play, fight.enemies[0]) == 2, "an unplayed per-play card does its base damage")
	fight.plays_this_turn = 2
	_check(SmartPolicy._effect_damage(fight, per_play, fight.enemies[0]) == 8, "each earlier play adds the bonus")
	_check(SimPolicy._incoming_damage(fight) == fight.incoming_damage() and SmartPolicy._haunted_count(fight) == fight.haunted_count(), "the bots read the engine's rules")


func _test_is_damage_kinds() -> void:
	var damaging := [CardEffect.Kind.DAMAGE, CardEffect.Kind.DAMAGE_PER_BLOCK, CardEffect.Kind.DAMAGE_IF_BLOCK, CardEffect.Kind.DAMAGE_PER_PLAY,
		CardEffect.Kind.DAMAGE_PER_HAUNT, CardEffect.Kind.DAMAGE_PER_FORGOTTEN, CardEffect.Kind.DAMAGE_PER_SCENT]
	for kind in CardEffect.Kind.values():
		var effect := CardEffect.make(kind, 1)
		_check(effect.is_damage() == damaging.has(kind), "is_damage for kind %d" % kind)
	_check(CardEffect.make(CardEffect.Kind.HAUNT, 1).reach() == CardEffect.Reach.ENEMIES and CardEffect.make(CardEffect.Kind.DAMAGE, 1).reach() == CardEffect.Reach.ENEMIES, "damage and Haunt reach enemies")
	_check(CardEffect.make(CardEffect.Kind.BLOCK, 1).reach() == CardEffect.Reach.SELF and CardEffect.make(CardEffect.Kind.EXPOSE, 1).reach() == CardEffect.Reach.BOTH, "Block is self, Expose is both")


func _test_content_cache() -> void:
	var first := StarterContent.all_cards()
	var second := StarterContent.all_cards()
	_check(not first.is_empty() and first.size() == second.size() and first[0] == second[0], "all_cards is stable across calls")
	first.clear()
	_check(StarterContent.all_cards().size() == second.size(), "callers cannot empty the cache")
	var pool := StarterContent.vendor_pool(&"deserter")
	pool.pop_back()
	_check(StarterContent.vendor_pool(&"deserter").size() == pool.size() + 1, "pools are handed out as copies")
	StarterContent.clear_cache()
	_check(StarterContent.all_cards().size() == second.size() and StarterContent.relic_pool(&"medium").size() > 0, "clear_cache rebuilds")
	_check(StarterContent.enemy_by_id(&"the_conductor") != null or StarterContent.enemy_ids().size() > 0, "enemy lookups work")
