extends RefCounted
## The damage and Block pipeline and the status table (Phase 2a): Malice, Ward, Shaken, Frayed,
## temporary stacks and enemy-applied statuses. Registered by run_tests.gd. Fixtures are built in code.

const K := CardEffect.Kind
const S := Combatant.Status

var _failures := 0


func run() -> int:
	_failures = 0
	_test_status_table()
	_test_stack_application()
	_test_temp_stack_api()
	_test_hit_damage()
	_test_take_damage_final()
	_test_block_from_card()
	_test_effect_data()
	_test_card_malice_and_ward()
	_test_card_block_uses_ward_and_frayed()
	_test_bypasses()
	_test_barbs_flat()
	_test_multi_hit_malice()
	_test_shaken_frayed_cards()
	_test_intent_shaken_frayed_on_player()
	_test_intent_malice()
	_test_enemy_pipeline()
	_test_temp_stack_expiry()
	return _failures


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAIL: " + label)


func _fx(kind: CardEffect.Kind, amount: int, bonus: int = 0, threshold: int = 0, hits: int = 1, per_energy: bool = false, temporary: bool = false) -> CardEffect:
	return CardEffect.make(kind, amount, bonus, threshold, hits, per_energy, temporary)


func _card(cost: int, effects: Array[CardEffect], mode: CardData.TargetMode = CardData.TargetMode.SINGLE_ENEMY) -> CardData:
	return CardData.make(&"t", "T", cost, effects, mode)


func _fight(hand: Array[CardData], intents: Array[CardEffect] = [], enemy_count: int = 1, enemy_hp: int = 100, relics: Array[RelicData] = []) -> Combat:
	var datas: Array[EnemyData] = []
	for i in enemy_count:
		datas.append(EnemyData.make("E%d" % i, enemy_hp, intents))
	var combat := Combat.new(Combatant.new("p", 100), hand, datas, 0, relics)
	combat.start()
	return combat


func _play(combat: Combat, card: CardData, target: int = 0) -> bool:
	return combat.play_card(combat.piles.hand.find(card), target)


func _pair() -> Array[Combatant]:
	var pair: Array[Combatant] = [Combatant.new("a", 50), Combatant.new("d", 50)]
	return pair


func _test_status_table() -> void:
	_check(S.EXPOSED == 0 and S.HAUNTED == 1 and S.SHAKEN == 2 and S.FRAYED == 3 and S.MALICE == 4 and S.WARD == 5, "statuses are only appended")
	_check(Combatant.status_kind(S.EXPOSED) == Combatant.StatusKind.DURATION, "Exposed is a duration")
	_check(Combatant.status_kind(S.SHAKEN) == Combatant.StatusKind.DURATION and Combatant.status_kind(S.FRAYED) == Combatant.StatusKind.DURATION, "Shaken and Frayed are durations")
	_check(Combatant.status_kind(S.HAUNTED) == Combatant.StatusKind.DECAYING, "Haunted decays")
	_check(Combatant.status_kind(S.MALICE) == Combatant.StatusKind.STACK and Combatant.status_kind(S.WARD) == Combatant.StatusKind.STACK, "Malice and Ward are stacks")
	for status in S.values():
		_check(Combatant.STATUS_KINDS.has(status), "status %d is in the table" % status)
	var c := Combatant.new("c", 10)
	c.apply_status(S.MALICE, 3)
	c.apply_status(S.WARD, -2)
	c.apply_status(S.EXPOSED, 2)
	c.apply_status(S.SHAKEN, 1)
	c.apply_status(S.HAUNTED, 3)
	c.tick_statuses()
	_check(c.stacks(S.MALICE) == 3 and c.stacks(S.WARD) == -2, "stacks never tick")
	_check(c.status_turns(S.EXPOSED) == 1 and c.status_turns(S.SHAKEN) == 0, "durations tick down and expire")
	_check(c.status_turns(S.HAUNTED) == 2, "Haunt falls by 1 per phase as before")
	c.tick_statuses()
	c.tick_statuses()
	c.tick_statuses()
	_check(c.stacks(S.MALICE) == 3 and c.stacks(S.WARD) == -2 and c.status_turns(S.EXPOSED) == 0 and c.status_turns(S.HAUNTED) == 0, "many ticks: stacks stay, the rest are gone")
	c.clear_statuses()
	_check(c.stacks(S.MALICE) == 0 and c.stacks(S.WARD) == 0, "clear_statuses removes stacks")


func _test_stack_application() -> void:
	var c := Combatant.new("c", 10)
	var fired := [0]
	c.changed.connect(func() -> void: fired[0] += 1)
	c.apply_status(S.MALICE, 0)
	_check(c.stacks(S.MALICE) == 0 and fired[0] == 0, "a zero stack change is ignored")
	c.apply_status(S.MALICE, -3)
	_check(c.stacks(S.MALICE) == -3 and c.status_turns(S.MALICE) == -3, "stacks can go negative")
	c.apply_status(S.MALICE, 5)
	_check(c.stacks(S.MALICE) == 2, "stacks add with sign")
	c.apply_status(S.MALICE, -2)
	_check(c.stacks(S.MALICE) == 0 and not c._statuses.has(S.MALICE), "a stack that reaches 0 is erased")
	c.apply_status(S.SHAKEN, 0)
	c.apply_status(S.SHAKEN, -2)
	c.apply_status(S.FRAYED, -1)
	_check(c.status_turns(S.SHAKEN) == 0 and c.status_turns(S.FRAYED) == 0, "durations still ignore non-positive amounts")
	c.apply_status(S.SHAKEN, 2)
	c.apply_status(S.SHAKEN, 1)
	_check(c.status_turns(S.SHAKEN) == 3 and c.stacks(S.SHAKEN) == 3, "durations add")
	var capped := Combatant.new("capped", 10)
	capped.max_haunt = 3
	capped.apply_status(S.HAUNTED, 5)
	capped.apply_status(S.MALICE, 5)
	_check(capped.status_turns(S.HAUNTED) == 3 and capped.stacks(S.MALICE) == 5, "the Haunt cap applies to Haunt only")


func _test_temp_stack_api() -> void:
	var c := Combatant.new("c", 10)
	c.apply_status(S.MALICE, 2)
	c.apply_temp_stack(S.MALICE, 3)
	_check(c.stacks(S.MALICE) == 5 and c.status_turns(S.MALICE) == 2, "temporary stacks count in stacks() but not status_turns()")
	c.apply_temp_stack(S.MALICE, 0)
	c.apply_temp_stack(S.EXPOSED, 2)
	_check(c.stacks(S.EXPOSED) == 0 and c.stacks(S.MALICE) == 5, "zero and non-stack temporary changes are ignored")
	c.tick_statuses()
	_check(c.stacks(S.MALICE) == 5, "temporary stacks do not tick")
	c.apply_temp_stack(S.WARD, -4)
	_check(c.stacks(S.WARD) == -4, "temporary stacks can be negative")
	c.clear_temp_stacks()
	_check(c.stacks(S.MALICE) == 2 and c.stacks(S.WARD) == 0, "clear_temp_stacks keeps permanent stacks")
	c.apply_temp_stack(S.WARD, 2)
	c.clear_statuses()
	_check(c.stacks(S.WARD) == 0, "clear_statuses clears temporary stacks")


func _test_hit_damage() -> void:
	var pair := _pair()
	var a := pair[0]
	var d := pair[1]
	_check(Combatant.hit_damage(6, a, d) == 6, "no statuses: the raw damage")
	_check(Combatant.hit_damage(0, a, d) == 0 and Combatant.hit_damage(-3, a, d) == 0, "a raw of 0 or less stays 0")
	a.apply_status(S.MALICE, 3)
	_check(Combatant.hit_damage(0, a, d) == 0, "Malice does not turn a 0 hit into damage")
	_check(Combatant.hit_damage(6, a, d) == 9, "Malice adds to the hit")
	a.apply_temp_stack(S.MALICE, 2)
	_check(Combatant.hit_damage(6, a, d) == 11, "temporary Malice counts too")
	a.clear_statuses()
	a.apply_status(S.MALICE, -10)
	_check(Combatant.hit_damage(3, a, d) == 0, "negative Malice floors the hit at 0")
	a.clear_statuses()
	a.apply_status(S.MALICE, 2)
	a.apply_status(S.SHAKEN, 1)
	_check(Combatant.hit_damage(3, a, d) == 3, "Malice first, then Shaken: (3 + 2) x 3/4 = 3 (not 3 x 3/4 + 2 = 4)")
	_check(Combatant.hit_damage(10, a, d) == 9, "(10 + 2) x 3/4 = 9")
	a.clear_statuses()
	a.apply_status(S.SHAKEN, 1)
	_check(Combatant.hit_damage(1, a, d) == 1, "Shaken never takes a 1 hit to 0")
	_check(Combatant.hit_damage(2, a, d) == 1 and Combatant.hit_damage(4, a, d) == 3, "Shaken rounds down")
	_check(Combatant.hit_damage(0, a, d) == 0, "Shaken leaves 0 at 0")
	d.apply_status(S.EXPOSED, 1)
	_check(Combatant.hit_damage(5, a, d) == 4, "Shaken before Expose: 5 -> 3 -> 4 (not 5 x 3/2 = 7 -> 5)")
	_check(Combatant.hit_damage(1, a, d) == 1, "Shaken then Expose keeps a 1 hit at 1")
	a.clear_statuses()
	_check(Combatant.hit_damage(1, a, d) == 1 and Combatant.hit_damage(7, a, d) == 10 and Combatant.hit_damage(0, a, d) == 0, "Expose: x3/2 down, at least 1, 0 stays 0")
	a.apply_status(S.MALICE, 2)
	a.apply_status(S.SHAKEN, 1)
	_check(Combatant.hit_damage(6, a, d) == 9, "all three: (6 + 2) x 3/4 = 6, x 3/2 = 9")
	# The attacker's own Expose and the defender's Shaken/Malice play no part.
	var other := _pair()
	other[0].apply_status(S.EXPOSED, 2)
	other[1].apply_status(S.SHAKEN, 2)
	other[1].apply_status(S.MALICE, 9)
	_check(Combatant.hit_damage(8, other[0], other[1]) == 8, "only the attacker's Malice/Shaken and the defender's Expose matter")
	_check(d.damage_after_status(7) == 10, "damage_after_status is still the Expose step")


func _test_take_damage_final() -> void:
	var d := Combatant.new("d", 50)
	d.apply_status(S.EXPOSED, 2)
	d.gain_block(4)
	_check(d.take_damage_final(10) == 6 and d.block == 0 and d.hp == 44, "take_damage_final absorbs Block without applying Expose again")
	_check(d.take_damage(10) == 15, "take_damage still applies Expose itself")
	_check(d.take_damage_final(-5) == 0, "take_damage_final ignores negatives")


func _test_block_from_card() -> void:
	var c := Combatant.new("c", 10)
	_check(c.block_from_card(5) == 5 and c.block_from_card(0) == 0 and c.block_from_card(-2) == 0, "no statuses: the amount, never negative")
	c.apply_status(S.WARD, 2)
	_check(c.block_from_card(5) == 7, "Ward adds to the Block")
	_check(c.block_from_card(0) == 0, "Ward does not make 0 Block into Block")
	c.apply_temp_stack(S.WARD, 1)
	_check(c.block_from_card(5) == 8, "temporary Ward counts")
	c.clear_statuses()
	c.apply_status(S.WARD, -10)
	_check(c.block_from_card(4) == 0, "negative Ward floors Block at 0")
	c.clear_statuses()
	c.apply_status(S.WARD, 2)
	c.apply_status(S.FRAYED, 1)
	_check(c.block_from_card(3) == 3, "Ward first, then Frayed: (3 + 2) x 3/4 = 3 (not 3 x 3/4 + 2 = 4)")
	_check(c.block_from_card(10) == 9, "(10 + 2) x 3/4 = 9")
	c.clear_statuses()
	c.apply_status(S.FRAYED, 1)
	_check(c.block_from_card(1) == 1, "Frayed never takes 1 Block to 0")
	_check(c.block_from_card(5) == 3 and c.block_from_card(8) == 6, "Frayed rounds down")


func _test_effect_data() -> void:
	_check(_fx(K.SHAKEN, 2).reach() == CardEffect.Reach.BOTH and _fx(K.FRAYED, 2).reach() == CardEffect.Reach.BOTH, "Shaken and Frayed reach both")
	_check(_fx(K.MALICE, 2).reach() == CardEffect.Reach.SELF and _fx(K.WARD, 0).reach() == CardEffect.Reach.SELF, "non-negative Malice and Ward reach the user")
	_check(_fx(K.MALICE, -2).reach() == CardEffect.Reach.ENEMIES and _fx(K.WARD, -1).reach() == CardEffect.Reach.ENEMIES, "negative Malice and Ward reach the enemies")
	_check(not _fx(K.MALICE, 2).is_damage() and not _fx(K.SHAKEN, 2).is_damage(), "the new kinds are not damage")
	_check(_fx(K.SHAKEN, 2).describe() == "Shaken 2" and _fx(K.FRAYED, 3).describe() == "Frayed 3", "Shaken and Frayed text")
	_check(_fx(K.MALICE, 2).describe() == "Malice +2" and _fx(K.MALICE, -2).describe() == "Malice -2", "Malice text is signed")
	_check(_fx(K.WARD, 3).describe() == "Ward +3" and _fx(K.WARD, -1).describe() == "Ward -1", "Ward text is signed")
	_check(_fx(K.MALICE, 2, 0, 0, 1, false, true).describe() == "Malice +2 this turn", "a temporary stack says so")
	_check(not CardEffect.make(K.MALICE, 1).temporary, "temporary defaults to false")
	_check(K.DAMAGE_PER_HAUNT == 13 and K.SHAKEN == 14 and K.FRAYED == 15 and K.MALICE == 16 and K.WARD == 17, "the new kinds are appended")
	_check(Vendor.effect_value(_fx(K.MALICE, 2)) > Vendor.effect_value(_fx(K.MALICE, 2, 0, 0, 1, false, true)), "a temporary stack is worth less than a permanent one")
	_check(Vendor.effect_value(_fx(K.MALICE, -2)) == Vendor.effect_value(_fx(K.MALICE, 2)), "a debuff stack is valued like a buff")


func _test_card_malice_and_ward() -> void:
	# A positive Malice on a card that targets all enemies lands once, on the player.
	var all := _card(0, [_fx(K.MALICE, 2), _fx(K.DAMAGE, 3)], CardData.TargetMode.ALL_ENEMIES)
	var combat := _fight([all], [], 2)
	_play(combat, all)
	_check(combat.player.stacks(S.MALICE) == 2, "positive Malice on an ALL_ENEMIES card applies once to the player")
	_check(combat.enemies[0].stacks(S.MALICE) == 0 and combat.enemies[1].stacks(S.MALICE) == 0, "and not to the enemies")
	_check(combat.enemies[0].hp == 95 and combat.enemies[1].hp == 95, "the damage after it gets the Malice: 3 + 2 on each enemy")
	var single := _card(0, [_fx(K.MALICE, 2), _fx(K.WARD, 3)])
	var c2 := _fight([single], [], 2)
	_play(c2, single, 1)
	_check(c2.player.stacks(S.MALICE) == 2 and c2.player.stacks(S.WARD) == 3 and c2.enemies[1].stacks(S.MALICE) == 0, "positive Malice and Ward on a SINGLE_ENEMY card land on the player")
	# A negative one lands on each target.
	var debuff := _card(0, [_fx(K.MALICE, -2), _fx(K.WARD, -1)], CardData.TargetMode.ALL_ENEMIES)
	var c3 := _fight([debuff], [], 2)
	_play(c3, debuff)
	_check(c3.enemies[0].stacks(S.MALICE) == -2 and c3.enemies[1].stacks(S.MALICE) == -2 and c3.enemies[0].stacks(S.WARD) == -1, "negative Malice and Ward land on each target")
	_check(c3.player.stacks(S.MALICE) == 0 and c3.player.stacks(S.WARD) == 0, "and not on the player")
	var one := _card(0, [_fx(K.MALICE, -3)])
	var c4 := _fight([one], [], 2)
	_play(c4, one, 1)
	_check(c4.enemies[1].stacks(S.MALICE) == -3 and c4.enemies[0].stacks(S.MALICE) == 0, "a negative Malice on a SINGLE_ENEMY card hits only the chosen enemy")
	# A SELF card with a positive stack.
	var selfcard := _card(0, [_fx(K.WARD, 4)], CardData.TargetMode.SELF)
	var c5 := _fight([selfcard])
	_play(c5, selfcard)
	_check(c5.player.stacks(S.WARD) == 4, "a SELF card gives the player Ward")
	# Surge scaling keeps the sign.
	var surge := _card(0, [_fx(K.MALICE, 1, 0, 0, 1, true)], CardData.TargetMode.SELF)
	surge.surge = true
	var c6 := _fight([surge])
	_play(c6, surge)
	_check(c6.player.stacks(S.MALICE) == Combat.ENERGY_PER_TURN, "a per_energy Malice scales with the energy spent")
	# A negative Malice weakens the enemy's next attack, down to 0 damage.
	var atk: Array[CardEffect] = [_fx(K.DAMAGE, 1)]
	var c7 := _fight([debuff], atk)
	_play(c7, debuff)
	c7.end_player_turn()
	_check(c7.player.hp == 100, "an enemy with -2 Malice hits for 0 from a raw 1")


func _test_card_block_uses_ward_and_frayed() -> void:
	var ward := _card(0, [_fx(K.WARD, 2)], CardData.TargetMode.SELF)
	var block := _card(0, [_fx(K.BLOCK, 5)], CardData.TargetMode.SELF)
	var combat := _fight([ward, block])
	_play(combat, ward)
	_play(combat, block)
	_check(combat.player.block == 7, "a Block card gains Ward")
	var fray := _card(0, [_fx(K.FRAYED, 1)], CardData.TargetMode.SELF)
	var c2 := _fight([fray, block])
	_play(c2, fray)
	_play(c2, block)
	_check(c2.player.status_turns(S.FRAYED) == 1 and c2.player.block == 3, "a self-targeted Frayed card frays the player: Block 5 becomes 3")


## Hold, Barbs and relic Block do not use Ward or Frayed.
func _test_bypasses() -> void:
	var ward := _card(0, [_fx(K.WARD, 3)], CardData.TargetMode.SELF)
	var hold := _card(0, [_fx(K.BLOCK, 4), _fx(K.HOLD, 4), _fx(K.THORNS, 4)], CardData.TargetMode.SELF)
	var fray := _card(0, [_fx(K.FRAYED, 3)], CardData.TargetMode.SELF)
	var relic := RelicData.make(&"r", "R", RelicData.Kind.TURN_START_BLOCK, 4, 0)
	var combat := _fight([ward, fray, hold], [], 1, 100, [relic] as Array[RelicData])
	_play(combat, ward)
	_play(combat, fray)
	_play(combat, hold)
	_check(combat.player.block == 4 + 5, "the relic's flat 4 plus the card Block with Ward and Frayed: (4 + 3) x 3/4 = 5")
	_check(combat.player.hold == 4, "Hold is not changed by Ward or Frayed")
	_check(combat.player.thorns == 4, "Barbs are not changed by Ward or Frayed")
	combat.end_player_turn()
	_check(combat.player.stacks(S.WARD) == 3 and combat.player.status_turns(S.FRAYED) == 2, "Ward stays and Frayed ticked")
	_check(combat.player.block == 4 + 4, "next turn: the 4 held Block plus the relic's flat 4 (Ward and Frayed ignored)")
	var direct := Combatant.new("d", 10)
	direct.apply_status(S.WARD, 5)
	direct.apply_status(S.FRAYED, 1)
	direct.gain_block(4)
	direct.add_hold(4)
	direct.add_thorns(4)
	_check(direct.block == 4 and direct.hold == 4 and direct.thorns == 4, "gain_block, add_hold and add_thorns are flat")


func _test_barbs_flat() -> void:
	var barbs := _card(0, [_fx(K.THORNS, 4)], CardData.TargetMode.SELF)
	var intents: Array[CardEffect] = [_fx(K.DAMAGE, 5)]
	var combat := _fight([barbs], intents)
	combat.enemies[0].apply_status(S.MALICE, 5)
	combat.enemies[0].apply_status(S.SHAKEN, 3)
	_play(combat, barbs)
	combat.end_player_turn()
	# The enemy's hit: (5 + 5) x 3/4 = 7. Its Barbs damage stays 4: no Malice, no Shaken.
	_check(combat.player.hp == 100 - 7, "the enemy's hit used its Malice and Shaken")
	_check(combat.enemies[0].hp == 100 - 4, "Barbs damage is flat, unaffected by the attacker's Malice and Shaken")
	var c2 := _fight([barbs], intents)
	c2.enemies[0].apply_status(S.EXPOSED, 3)
	_play(c2, barbs)
	c2.end_player_turn()
	_check(c2.enemies[0].hp == 100 - 6, "the target's Expose still applies to Barbs damage: 4 x 3/2 = 6")
	# The player's Malice does not boost Barbs either.
	var c3 := _fight([barbs], intents)
	c3.player.apply_status(S.MALICE, 9)
	c3.player.apply_status(S.SHAKEN, 5)
	_play(c3, barbs)
	c3.end_player_turn()
	_check(c3.enemies[0].hp == 100 - 4, "the player's own Malice and Shaken do not touch Barbs")


func _test_multi_hit_malice() -> void:
	var multi := _card(0, [_fx(K.DAMAGE, 3, 0, 0, 2)])
	var combat := _fight([multi])
	combat.player.apply_status(S.MALICE, 2)
	_play(combat, multi)
	_check(combat.enemies[0].hp == 100 - 10, "Malice applies to each hit: 2 hits of 3 + 2")
	var c2 := _fight([multi])
	c2.player.apply_status(S.MALICE, -2)
	_play(c2, multi)
	_check(c2.enemies[0].hp == 100 - 2, "negative Malice applies per hit: 2 hits of 1")
	var c3 := _fight([multi])
	c3.player.apply_status(S.SHAKEN, 1)
	c3.enemies[0].apply_status(S.EXPOSED, 1)
	c3.enemies[0].gain_block(5)
	_play(c3, multi)
	# Each hit: 3 x 3/4 = 2, Exposed x 3/2 = 3. Block 5 absorbs 3 then 2; the last 1 gets through.
	_check(c3.enemies[0].block == 0 and c3.enemies[0].hp == 99,"Shaken and Expose per hit, Block absorbing across hits")
	var c4 := _fight([_card(0, [_fx(K.DAMAGE, 3, 0, 0, 1, true)])])
	c4.player.apply_status(S.MALICE, 1)
	c4.piles.hand[0].surge = true
	c4.play_card(0, 0)
	_check(c4.enemies[0].hp == 100 - 4 * Combat.ENERGY_PER_TURN, "a Surge multi-hit applies Malice to each hit")


func _test_shaken_frayed_cards() -> void:
	var shake := _card(0, [_fx(K.SHAKEN, 2)])
	var combat := _fight([shake], [], 2)
	_play(combat, shake, 1)
	_check(combat.enemies[1].status_turns(S.SHAKEN) == 2 and combat.enemies[0].status_turns(S.SHAKEN) == 0 and combat.player.status_turns(S.SHAKEN) == 0, "Shaken on a single-enemy card shakes the chosen enemy")
	var fray_all := _card(0, [_fx(K.FRAYED, 1)], CardData.TargetMode.ALL_ENEMIES)
	var c2 := _fight([fray_all], [], 2)
	_play(c2, fray_all)
	_check(c2.enemies[0].status_turns(S.FRAYED) == 1 and c2.enemies[1].status_turns(S.FRAYED) == 1 and c2.player.status_turns(S.FRAYED) == 0, "Frayed on an ALL_ENEMIES card frays every enemy")
	var self_shake := _card(0, [_fx(K.SHAKEN, 2), _fx(K.FRAYED, 3)], CardData.TargetMode.SELF)
	var c3 := _fight([self_shake])
	_play(c3, self_shake)
	_check(c3.player.status_turns(S.SHAKEN) == 2 and c3.player.status_turns(S.FRAYED) == 3 and c3.enemies[0].status_turns(S.SHAKEN) == 0, "a SELF card shakes and frays the player")
	# A shaken enemy's turn count ticks as it acts, and the shaken hit is weaker while it lasts.
	var intents: Array[CardEffect] = [_fx(K.DAMAGE, 8)]
	var c4 := _fight([shake], intents)
	_play(c4, shake)
	c4.end_player_turn()
	_check(c4.player.hp == 100 - 6 and c4.enemies[0].status_turns(S.SHAKEN) == 1, "a Shaken enemy hits for 8 x 3/4 = 6")
	c4.end_player_turn()
	_check(c4.player.hp == 100 - 12 and c4.enemies[0].status_turns(S.SHAKEN) == 0, "and for 6 again on its second turn")
	c4.end_player_turn()
	_check(c4.player.hp == 100 - 12 - 8, "then back to 8")
	# Frayed enemy: its Block intent is reduced.
	var block_intent: Array[CardEffect] = [_fx(K.BLOCK, 8)]
	var c5 := _fight([_card(0, [_fx(K.FRAYED, 2)])], block_intent)
	c5.play_card(0, 0)
	c5.end_player_turn()
	_check(c5.enemies[0].block == 6, "a Frayed enemy gains 8 x 3/4 = 6 Block from its intent")


func _test_intent_shaken_frayed_on_player() -> void:
	var intents: Array[CardEffect] = [_fx(K.SHAKEN, 2), _fx(K.FRAYED, 2), _fx(K.BLOCK, 1)]
	var attack := _card(0, [_fx(K.DAMAGE, 8)])
	var combat := _fight([attack, attack.duplicate(), attack.duplicate()] as Array[CardData], intents)
	_check(combat.player.status_turns(S.SHAKEN) == 0, "nothing yet")
	combat.end_player_turn()
	_check(combat.player.status_turns(S.SHAKEN) == 2, "an intent's Shaken 2 lands after the tick: 2 turns, not ticked away")
	_check(combat.player.status_turns(S.FRAYED) == 0, "the next intent has not acted yet")
	# Turn 2: the player is Shaken, so an 8 hit does 6.
	var hand_attack: CardData = combat.piles.hand[0]
	var before := combat.enemies[0].hp
	combat.play_card(0, 0)
	_check(before - combat.enemies[0].hp == 6, "the Shaken player hits for 8 x 3/4 = 6")
	combat.end_player_turn()
	_check(combat.player.status_turns(S.SHAKEN) == 1 and combat.player.status_turns(S.FRAYED) == 2, "Shaken ticked to 1; Frayed 2 landed after the tick")
	var block := _card(0, [_fx(K.BLOCK, 10)], CardData.TargetMode.SELF)
	combat.piles.hand.append(block)
	_play(combat, block)
	_check(combat.player.block == 7, "the Frayed player gains 10 x 3/4 = 7 Block")
	combat.end_player_turn()
	_check(combat.player.status_turns(S.SHAKEN) == 0 and combat.player.status_turns(S.FRAYED) == 1, "Shaken has now covered exactly 2 player turns")
	combat.end_player_turn()
	_check(combat.player.status_turns(S.FRAYED) == 0, "Frayed has covered exactly 2 player turns")
	_check(hand_attack != null, "fixture sanity")
	# Two enemies stack on the player.
	var two := _fight([attack], [_fx(K.SHAKEN, 1)] as Array[CardEffect], 2)
	two.end_player_turn()
	_check(two.player.status_turns(S.SHAKEN) == 2, "two enemies' Shaken stack on the player")
	# A fight's end clears pending and applied statuses.
	var cleared := _fight([attack], [_fx(K.FRAYED, 3)] as Array[CardEffect])
	cleared.end_player_turn()
	cleared.abandon()
	_check(cleared.player.status_turns(S.FRAYED) == 0, "statuses are cleared with the fight")


func _test_intent_malice() -> void:
	var intents: Array[CardEffect] = [_fx(K.MALICE, 2), _fx(K.DAMAGE, 5)]
	var combat := _fight([_card(0, [_fx(K.BLOCK, 1)], CardData.TargetMode.SELF)], intents)
	combat.end_player_turn()
	_check(combat.enemies[0].stacks(S.MALICE) == 2 and combat.player.stacks(S.MALICE) == 0, "an intent's positive Malice buffs the enemy")
	combat.end_player_turn()
	_check(combat.player.hp == 100 - 7, "the buffed enemy hits for 5 + 2")
	_check(combat.enemies[0].stacks(S.MALICE) == 2, "Malice lasts: it did not tick")
	# A negative intent debuffs the player, immediately and for the fight.
	var debuff: Array[CardEffect] = [_fx(K.MALICE, -2)]
	var c2 := _fight([_card(0, [_fx(K.DAMAGE, 5)])], debuff)
	c2.end_player_turn()
	_check(c2.player.stacks(S.MALICE) == -2 and c2.enemies[0].stacks(S.MALICE) == 0, "an intent's negative Malice debuffs the player")
	c2.end_player_turn()
	_check(c2.player.stacks(S.MALICE) == -4, "and keeps stacking")
	var ward_intent: Array[CardEffect] = [_fx(K.WARD, 2), _fx(K.BLOCK, 4)]
	var c3 := _fight([_card(0, [_fx(K.BLOCK, 1)], CardData.TargetMode.SELF)], ward_intent)
	c3.end_player_turn()
	_check(c3.enemies[0].stacks(S.WARD) == 2, "an intent's Ward buffs the enemy")
	c3.end_player_turn()
	_check(c3.enemies[0].block == 6, "an enemy Block intent gains its Ward: 4 + 2")


func _test_enemy_pipeline() -> void:
	var intents: Array[CardEffect] = [_fx(K.DAMAGE, 5)]
	var combat := _fight([_card(0, [_fx(K.BLOCK, 1)], CardData.TargetMode.SELF)], intents)
	combat.enemies[0].apply_status(S.MALICE, 3)
	combat.player.apply_status(S.EXPOSED, 2)
	combat.end_player_turn()
	_check(combat.player.hp == 100 - 12, "an enemy with Malice 3 hits an Exposed player for (5 + 3) x 3/2 = 12")
	var weak: Array[CardEffect] = [_fx(K.DAMAGE, 6)]
	var c2 := _fight([_card(0, [_fx(K.BLOCK, 1)], CardData.TargetMode.SELF)], weak)
	c2.enemies[0].apply_status(S.MALICE, -9)
	c2.end_player_turn()
	_check(c2.player.hp == 100, "an enemy with negative Malice can be reduced to 0 damage")
	# Block on the player is applied after the whole chain.
	var c3 := _fight([_card(0, [_fx(K.BLOCK, 1)], CardData.TargetMode.SELF)], intents)
	c3.enemies[0].apply_status(S.MALICE, 3)
	c3.player.gain_block(6)
	c3.end_player_turn()
	_check(c3.player.hp == 100 - 2, "Block comes after Malice: 8 damage, 6 absorbed")


func _test_temp_stack_expiry() -> void:
	# The player's temporary stacks last the turn they are played and are gone when the next begins.
	var temp := _card(0, [_fx(K.MALICE, 3, 0, 0, 1, false, true), _fx(K.WARD, 2, 0, 0, 1, false, true)], CardData.TargetMode.SELF)
	var hit := _card(0, [_fx(K.DAMAGE, 4)])
	var block := _card(0, [_fx(K.BLOCK, 4)], CardData.TargetMode.SELF)
	var intents: Array[CardEffect] = [_fx(K.BLOCK, 1)]
	var combat := _fight([temp, hit, block], intents)
	_play(combat, temp)
	_check(combat.player.stacks(S.MALICE) == 3 and combat.player.status_turns(S.MALICE) == 0, "temporary Malice is a stack, not a permanent one")
	_play(combat, hit)
	_check(combat.enemies[0].hp == 100 - 7, "temporary Malice boosts the hit this turn")
	_play(combat, block)
	_check(combat.player.block == 6, "temporary Ward boosts Block this turn")
	combat.end_player_turn()
	_check(combat.player.stacks(S.MALICE) == 0 and combat.player.stacks(S.WARD) == 0, "temporary stacks are gone when the next player turn starts")
	# A permanent stack survives alongside.
	var both := _fight([_card(0, [_fx(K.MALICE, 1)], CardData.TargetMode.SELF), _card(0, [_fx(K.MALICE, 2, 0, 0, 1, false, true)], CardData.TargetMode.SELF)])
	both.play_card(0)
	both.play_card(0)
	_check(both.player.stacks(S.MALICE) == 3, "permanent and temporary add")
	both.end_player_turn()
	_check(both.player.stacks(S.MALICE) == 1, "only the temporary part expires")
	# An enemy's temporary stacks last until its next action.
	var buff: Array[CardEffect] = [_fx(K.MALICE, 3, 0, 0, 1, false, true), _fx(K.DAMAGE, 5), _fx(K.DAMAGE, 5)]
	var c2 := _fight([_card(0, [_fx(K.BLOCK, 1)], CardData.TargetMode.SELF)], buff)
	c2.end_player_turn()
	_check(c2.enemies[0].stacks(S.MALICE) == 3, "an enemy's temporary Malice is on during the player's turn")
	c2.end_player_turn()
	_check(c2.player.hp == 100 - 5 and c2.enemies[0].stacks(S.MALICE) == 0, "and is gone before the enemy's next action (the hit is a plain 5)")
