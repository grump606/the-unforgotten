extends RefCounted
## Tests for relics (combat/relic_data.gd and its hooks in Combat, Vendor, RunState and
## RunSave). Returns the failure count; the suite in run_tests.gd adds it to its own.

var _failures := 0


func run() -> int:
	_failures = 0
	_test_content()
	_test_no_relics_changes_nothing()
	_test_fight_start_block()
	_test_turn_start_block_survives_turn_reset()
	_test_turn_start_thorns()
	_test_first_turn_energy()
	_test_first_play_draw()
	_test_plays_block()
	_test_fight_start_haunt()
	_test_turn_start_heal_per_haunted()
	_test_haunt_bonus()
	_test_relics_stack()
	_test_vendor_relic_offer()
	_test_vendor_buy_relic()
	_test_run_state_relics()
	_test_win_rewards()
	_test_save_round_trip()
	_test_save_rejects_bad_relics()
	return _failures


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAIL: " + label)


func _relic(kind: RelicData.Kind, amount: int) -> RelicData:
	return RelicData.make(&"t_relic", "T", kind, amount, 10)


func _relics(list: Array) -> Array[RelicData]:
	var typed: Array[RelicData] = []
	typed.assign(list)
	return typed


func _card(cost: int, effects: Array[CardEffect]) -> CardData:
	return CardData.make(&"t", "T", cost, effects)


func _deck(count: int, card: CardData) -> Array[CardData]:
	var deck: Array[CardData] = []
	for i in count:
		deck.append(card)
	return deck


func _enemies(count: int, hp: int, intents: Array[CardEffect]) -> Array[EnemyData]:
	var list: Array[EnemyData] = []
	for i in count:
		list.append(EnemyData.make("E%d" % i, hp, intents))
	return list


func _dmg(amount: int) -> Array[CardEffect]:
	return [CardEffect.make(CardEffect.Kind.DAMAGE, amount)]


## A fight with a 10-card deck of `card`, one 99 HP enemy that never acts, and `relics`.
func _fight(relics: Array, card: CardData = null, player_hp: int = 40, enemy_count: int = 1) -> Combat:
	var deck_card := card if card != null else _card(1, _dmg(1))
	var combat := Combat.new(Combatant.new("p", 40, player_hp), _deck(10, deck_card), _enemies(enemy_count, 99, []), 5, _relics(relics))
	combat.start()
	return combat


func _test_content() -> void:
	var relics := StarterContent.all_relics()
	_check(relics.size() == 12, "twelve relics load (got %d)" % relics.size())
	var ids := {}
	var kinds := {}
	for relic in relics:
		ids[relic.id] = true
		kinds[relic.kind] = true
		_check(relic.amount > 0 and relic.price > 0 and relic.display_name != "" and relic.description != "", "%s has an amount, a price, a name and a description" % relic.id)
	_check(ids.size() == 12, "relic ids are unique")
	_check(kinds.size() == RelicData.Kind.size(), "every relic kind is used by exactly one relic")
	for character_id in StarterContent.character_ids():
		var pool := StarterContent.relic_pool(character_id)
		var own := 0
		var neutral := 0
		for relic in pool:
			if relic.character == character_id:
				own += 1
			elif relic.character == &"":
				neutral += 1
		_check(own == 3 and neutral == 3 and pool.size() == 6, "%s: relic pool is 3 class plus 3 neutral relics" % character_id)
	# Append-only enum: the saved numbers must keep their meaning.
	_check(RelicData.Kind.MAX_HP == 0 and RelicData.Kind.HAUNT_BONUS == 11, "relic kind numbering is unchanged")


func _test_no_relics_changes_nothing() -> void:
	var deck := StarterContent.deck()
	var plain := Combat.new(Combatant.new("p", 20), deck, StarterContent.early_encounter(2), 42)
	var with_empty := Combat.create(Combatant.new("p", 20), deck, StarterContent.early_encounter(2), 42, [])
	plain.start()
	with_empty.start()
	var same := plain.energy == with_empty.energy and plain.player.block == with_empty.player.block and plain.player.thorns == with_empty.player.thorns
	for i in plain.piles.hand.size():
		same = same and plain.piles.hand[i] == with_empty.piles.hand[i]
	_check(same and with_empty.relics.is_empty(), "an empty relic list changes nothing")
	_check(plain.energy == Combat.ENERGY_PER_TURN and plain.player.block == 0 and plain.enemies[0].status_turns(Combatant.Status.HAUNTED) == 0, "no relics: plain start of fight")


func _test_fight_start_block() -> void:
	var combat := _fight([_relic(RelicData.Kind.FIGHT_START_BLOCK, 8)])
	_check(combat.player.block == 8, "FIGHT_START_BLOCK gives Block on turn 1")
	combat.end_player_turn()
	_check(combat.turn == 2 and combat.player.block == 0, "FIGHT_START_BLOCK is not repeated on later turns")
	var next := _fight([_relic(RelicData.Kind.FIGHT_START_BLOCK, 8)])
	_check(next.player.block == 8, "FIGHT_START_BLOCK applies again in the next fight")


func _test_turn_start_block_survives_turn_reset() -> void:
	var combat := _fight([_relic(RelicData.Kind.TURN_START_BLOCK, 3)])
	_check(combat.player.block == 3, "TURN_START_BLOCK gives Block on turn 1")
	combat.end_player_turn()
	_check(combat.turn == 2 and combat.player.block == 3, "TURN_START_BLOCK is granted after the turn reset, not wiped by it")
	combat.end_player_turn()
	_check(combat.player.block == 3, "TURN_START_BLOCK does not stack across turns")
	# Held Block carries over and the grant is added on top.
	var hold := _card(0, [CardEffect.make(CardEffect.Kind.BLOCK, 5), CardEffect.make(CardEffect.Kind.HOLD, 4)])
	var held := _fight([_relic(RelicData.Kind.TURN_START_BLOCK, 3)], hold)
	held.play_card(0)
	held.end_player_turn()
	_check(held.player.block == 4 + 3, "kept Block and the per-turn grant add up (got %d)" % held.player.block)


func _test_turn_start_thorns() -> void:
	var intents: Array[CardEffect] = [CardEffect.make(CardEffect.Kind.DAMAGE, 5)]
	var combat := Combat.new(Combatant.new("p", 40), _deck(10, _card(1, _dmg(1))), _enemies(1, 99, intents), 0, _relics([_relic(RelicData.Kind.TURN_START_THORNS, 3)]))
	combat.start()
	_check(combat.player.thorns == 3, "TURN_START_THORNS gives Thorns on turn 1")
	combat.end_player_turn()
	_check(combat.enemies[0].hp == 96, "the enemy hit the player and took the Thorns")
	_check(combat.turn == 2 and combat.player.thorns == 3, "TURN_START_THORNS is granted again after the turn reset")
	combat.end_player_turn()
	_check(combat.enemies[0].hp == 93, "Thorns work every turn")


func _test_first_turn_energy() -> void:
	var combat := _fight([_relic(RelicData.Kind.FIRST_TURN_ENERGY, 1)])
	_check(combat.energy == Combat.ENERGY_PER_TURN + 1, "FIRST_TURN_ENERGY adds energy on turn 1")
	combat.end_player_turn()
	_check(combat.energy == Combat.ENERGY_PER_TURN, "FIRST_TURN_ENERGY is for turn 1 only")
	var next := _fight([_relic(RelicData.Kind.FIRST_TURN_ENERGY, 1)])
	_check(next.energy == Combat.ENERGY_PER_TURN + 1, "FIRST_TURN_ENERGY applies again in the next fight")


func _test_first_play_draw() -> void:
	var combat := _fight([_relic(RelicData.Kind.FIRST_PLAY_DRAW, 1)])
	_check(combat.piles.hand.size() == Combat.HAND_SIZE, "setup: full opening hand")
	combat.play_card(0)
	_check(combat.piles.hand.size() == Combat.HAND_SIZE, "the first card played also draws one (hand back to full)")
	combat.play_card(0)
	_check(combat.piles.hand.size() == Combat.HAND_SIZE - 1, "FIRST_PLAY_DRAW draws only once per turn")
	combat.end_player_turn()
	combat.play_card(0)
	_check(combat.piles.hand.size() == Combat.HAND_SIZE, "FIRST_PLAY_DRAW triggers again next turn")
	# A rejected play does not count as the first play.
	var costly := _fight([_relic(RelicData.Kind.FIRST_PLAY_DRAW, 1)], _card(Combat.ENERGY_PER_TURN + 1, _dmg(1)))
	_check(not costly.play_card(0) and costly.piles.hand.size() == Combat.HAND_SIZE, "a rejected play draws nothing")


func _test_plays_block() -> void:
	# Each card draws a replacement so the hand outlasts six plays.
	var cycler := _card(0, [CardEffect.make(CardEffect.Kind.DAMAGE, 1), CardEffect.make(CardEffect.Kind.DRAW, 1)])
	var combat := _fight([_relic(RelicData.Kind.PLAYS_BLOCK, 4)], cycler)
	var blocks: Array[int] = []
	for i in 6:
		combat.play_card(0)
		blocks.append(combat.player.block)
	_check(str(blocks) == "[0, 0, 4, 4, 4, 8]","PLAYS_BLOCK pays on the 3rd and 6th play (got %s)" % str(blocks))
	combat.end_player_turn()
	combat.play_card(0)
	combat.play_card(0)
	_check(combat.player.block == 0, "the play count resets each turn")
	combat.play_card(0)
	_check(combat.player.block == 4, "PLAYS_BLOCK counts again from the new turn's 3rd play")


func _test_fight_start_haunt() -> void:
	var combat := _fight([_relic(RelicData.Kind.FIGHT_START_HAUNT, 2)], null, 40, 3)
	for enemy in combat.enemies:
		_check(enemy.status_turns(Combatant.Status.HAUNTED) == 2, "every enemy starts the fight Haunted")
	combat.end_player_turn()
	_check(combat.enemies[0].hp == 97 and combat.enemies[0].status_turns(Combatant.Status.HAUNTED) == 1, "the starting Haunt works as a normal Haunt")
	combat.end_player_turn()
	_check(combat.enemies[0].hp == 96 and combat.enemies[0].status_turns(Combatant.Status.HAUNTED) == 0, "the starting Haunt is not reapplied on turn 2")


func _test_turn_start_heal_per_haunted() -> void:
	var data := _enemies(3, 99, [])
	var combat := Combat.new(Combatant.new("p", 40, 10), _deck(10, _card(1, _dmg(1))), data, 0, _relics([_relic(RelicData.Kind.TURN_START_HEAL_PER_HAUNTED, 2)]))
	combat.enemies[0].apply_status(Combatant.Status.HAUNTED, 3)
	combat.enemies[1].apply_status(Combatant.Status.HAUNTED, 1)
	combat.start()
	_check(combat.player.hp == 14, "heals 2 per Haunted living enemy at the start of turn 1 (got %d)" % combat.player.hp)
	combat.end_player_turn()
	# The 1-turn Haunt expired during the enemy phase, leaving one Haunted enemy.
	_check(combat.player.hp == 16, "only enemies still Haunted heal (got %d)" % combat.player.hp)
	var plain := Combat.new(Combatant.new("p", 40, 10), _deck(10, _card(1, _dmg(1))), _enemies(1, 99, []), 0, _relics([_relic(RelicData.Kind.TURN_START_HEAL_PER_HAUNTED, 2)]))
	plain.start()
	_check(plain.player.hp == 10, "no Haunted enemy, no heal")
	# Grave Dirt's starting Haunt counts for the very first heal.
	var both := Combat.new(Combatant.new("p", 40, 10), _deck(10, _card(1, _dmg(1))), _enemies(2, 99, []), 0, _relics([_relic(RelicData.Kind.FIGHT_START_HAUNT, 1), _relic(RelicData.Kind.TURN_START_HEAL_PER_HAUNTED, 2)]))
	both.start()
	_check(both.player.hp == 14, "starting Haunt is applied before the turn-start heal (got %d)" % both.player.hp)


func _test_haunt_bonus() -> void:
	var haunt := _card(0, [CardEffect.make(CardEffect.Kind.HAUNT, 3)])
	var combat := _fight([_relic(RelicData.Kind.HAUNT_BONUS, 1)], haunt)
	combat.play_card(0)
	_check(combat.enemies[0].status_turns(Combatant.Status.HAUNTED) == 4, "HAUNT_BONUS adds to a Haunt effect")
	var plain := _fight([], haunt)
	plain.play_card(0)
	_check(plain.enemies[0].status_turns(Combatant.Status.HAUNTED) == 3, "without the relic Haunt is unchanged")
	var damage := _fight([_relic(RelicData.Kind.HAUNT_BONUS, 1)], _card(0, _dmg(4)))
	damage.play_card(0)
	_check(damage.enemies[0].hp == 95 and damage.enemies[0].status_turns(Combatant.Status.HAUNTED) == 0, "HAUNT_BONUS leaves non-Haunt cards alone")
	var sweep := CardData.make(&"sw", "Sw", 0, [CardEffect.make(CardEffect.Kind.HAUNT, 2)] as Array[CardEffect], CardData.TargetMode.ALL_ENEMIES)
	var all := _fight([_relic(RelicData.Kind.HAUNT_BONUS, 1)], sweep, 40, 2)
	all.play_card(0)
	_check(all.enemies[0].status_turns(Combatant.Status.HAUNTED) == 3 and all.enemies[1].status_turns(Combatant.Status.HAUNTED) == 3, "HAUNT_BONUS applies to every target of an all-enemies Haunt")


func _test_relics_stack() -> void:
	var combat := _fight([_relic(RelicData.Kind.TURN_START_BLOCK, 3), _relic(RelicData.Kind.TURN_START_BLOCK, 2), _relic(RelicData.Kind.FIGHT_START_BLOCK, 8)])
	_check(combat.player.block == 13, "block relics add up on turn 1 (got %d)" % combat.player.block)
	combat.end_player_turn()
	_check(combat.player.block == 5, "only the per-turn ones repeat (got %d)" % combat.player.block)
	_check(combat.relics.size() == 3, "the combat keeps its relic list")


## The vendor wiring below needs a pool; these use the real content.
func _vendor(seed_value: int, gold: int, deck: Array[CardData], relic_pool: Array[RelicData]) -> Vendor:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return Vendor.new(deck, rng, gold, [], relic_pool)


func _card_ids(vendor: Vendor) -> Array:
	var ids: Array = []
	for offer in vendor.offers():
		ids.append((offer["card"] as CardData).id)
	return ids


func _test_vendor_relic_offer() -> void:
	var pool := StarterContent.relic_pool(&"medium")
	var deck: Array[CardData] = []
	var none := _vendor(4, 0, deck, [])
	_check(none.relic_offer().is_empty(), "an empty relic pool leaves no relic offer")
	var seen := {}
	for seed_value in 40:
		var vendor := _vendor(seed_value, 0, deck, pool)
		var offer := vendor.relic_offer()
		_check(not offer.is_empty() and not offer["sold"] and offer["price"] == (offer["relic"] as RelicData).price, "the offer carries the relic, its price and is unsold")
		_check(pool.has(offer["relic"]), "the offered relic comes from the given pool")
		_check((_vendor(seed_value, 0, deck, pool).relic_offer()["relic"]) == offer["relic"], "the relic pick is deterministic for seed %d" % seed_value)
		_check(_card_ids(vendor) == _card_ids(_vendor(seed_value, 0, deck, [])), "the card stock is the same with or without a relic offer (seed %d)" % seed_value)
		seen[(offer["relic"] as RelicData).id] = true
	_check(seen.size() > 1, "different seeds offer different relics")
	var only: Array[RelicData] = [pool[0]]
	_check(_vendor(1, 0, deck, only).relic_offer()["relic"] == pool[0], "a one-relic pool offers that relic")
	var copy := _vendor(1, 0, deck, pool).relic_offer()
	copy["sold"] = true
	_check(not _vendor(1, 0, deck, pool).relic_offer()["sold"], "relic_offer returns a copy")


func _test_vendor_buy_relic() -> void:
	var flask := StarterContent.all_relics().filter(func(r: RelicData) -> bool: return r.kind == RelicData.Kind.MAX_HP)[0] as RelicData
	var pool: Array[RelicData] = [flask]
	var deck: Array[CardData] = []
	var player := Combatant.new("p", 40, 30)
	var vendor := _vendor(1, flask.price + 5, deck, pool)
	var result := vendor.buy_relic(player)
	_check(result.ok and result.relic == flask and result.spent == flask.price, "buy_relic succeeds")
	_check(vendor.gold == 5, "buy_relic deducts the price")
	_check(player.max_hp == 48 and player.hp == 38, "MAX_HP raises max HP and current HP once on purchase")
	_check(vendor.relic_offer()["sold"], "the offer is marked sold")
	var again := vendor.buy_relic(player)
	_check(not again.ok and vendor.gold == 5 and player.max_hp == 48, "buying the relic twice is refused and changes nothing")
	var poor := _vendor(1, flask.price - 1, deck, pool)
	var refused := poor.buy_relic(player)
	_check(not refused.ok and poor.gold == flask.price - 1 and player.max_hp == 48 and not poor.relic_offer()["sold"], "an unaffordable relic changes nothing")
	var exact := _vendor(1, flask.price, deck, pool)
	_check(exact.buy_relic(Combatant.new("p", 40)).ok and exact.gold == 0, "exact gold buys the relic")
	var empty := _vendor(1, 999, deck, [])
	_check(not empty.buy_relic(player).ok and empty.gold == 999, "no relic for sale: purchase refused")
	_check(not _vendor(1, 999, deck, pool).buy_relic(null).ok, "a null player is refused")


## Moves a run to the first VENDOR stop, winning and skipping on the way.
func _at_vendor(rng_seed: int, character: StringName = &"deserter") -> RunState:
	var state := RunState.new(rng_seed, character)
	var guard := 0
	while state.current_stop().type != RunState.StopType.VENDOR and guard < 50:
		guard += 1
		match state.current_stop().type:
			RunState.StopType.COMBAT:
				state.complete_combat(true)
				state.resolve_reward(null)
			RunState.StopType.STORY:
				state.read_story()
			_:
				state.rest()
	return state


func _test_run_state_relics() -> void:
	var state := RunState.new(3)
	_check(state.relics.is_empty() and not state.vendor_buy_relic().ok, "a fresh run has no relics and cannot buy one off a vendor stop")
	state = _at_vendor(8, &"pickpocket")
	state.gold = 500
	var offer := state.vendor().relic_offer()
	_check(not offer.is_empty(), "the vendor stocks a relic")
	var relic: RelicData = offer["relic"]
	_check(relic.character == &"" or relic.character == &"pickpocket", "the offer is neutral or the character's own")
	var max_before := state.player.max_hp
	var bought := state.vendor_buy_relic()
	_check(bought.ok and state.relics == [relic] and state.gold == 500 - relic.price, "vendor_buy_relic records the relic and syncs gold")
	if relic.kind == RelicData.Kind.MAX_HP:
		_check(state.player.max_hp == max_before + relic.amount, "a bought MAX_HP relic raises the run's max HP")
	_check(not state.vendor_buy_relic().ok and state.relics.size() == 1, "one relic per visit")
	state.leave_vendor()
	# A relic already owned is never offered again.
	for seed_value in 30:
		var run := _at_vendor(seed_value, &"medium")
		run.relics.assign(StarterContent.relic_pool(&"medium").slice(0, 5))
		var left := run.vendor().relic_offer()
		_check(not left.is_empty() and not run.relics.has(left["relic"]), "an owned relic is not offered again (seed %d)" % seed_value)
	var full := _at_vendor(2, &"medium")
	full.relics.assign(StarterContent.relic_pool(&"medium"))
	_check(full.vendor().relic_offer().is_empty() and not full.vendor_buy_relic().ok, "no offer once the whole pool is owned")
	# Combats built by the run carry its relics.
	var fighter := RunState.new(5)
	fighter.read_story()
	fighter.relics.assign(StarterContent.relic_pool(&"deserter").slice(0, 2))
	var combat := fighter.start_combat()
	_check(combat != null and combat.relics == fighter.relics, "start_combat gives the fight the run's relics")


func _test_win_rewards() -> void:
	var gold_relic := _relic(RelicData.Kind.WIN_GOLD, 4)
	var heal_relic := _relic(RelicData.Kind.WIN_HEAL, 3)
	var plain := RunState.new(11)
	plain.read_story()
	plain.complete_combat(true)
	var base_gold := plain.gold
	var state := RunState.new(11)
	state.read_story()
	state.relics.assign([gold_relic, heal_relic])
	state.player.take_damage(10)
	var hp_before := state.player.hp
	state.complete_combat(true)
	_check(state.gold == base_gold + 4, "WIN_GOLD adds to the gold of a won fight")
	_check(state.player.hp == hp_before + 3, "WIN_HEAL heals after a won fight")
	state.resolve_reward(null)
	var loser := RunState.new(11)
	loser.read_story()
	loser.relics.assign([gold_relic, heal_relic])
	loser.complete_combat(false)
	_check(loser.gold == 0, "a lost fight pays no WIN_GOLD")
	# The heal never passes max HP.
	var healthy := RunState.new(11)
	healthy.read_story()
	healthy.relics.assign([heal_relic])
	healthy.complete_combat(true)
	_check(healthy.player.hp == healthy.player.max_hp, "WIN_HEAL never exceeds max HP")
	# The boss pays no gold, relic or not.
	var boss := RunState.new(11)
	boss.stop_index = boss.stops.size() - 1
	boss.relics.assign([gold_relic])
	boss.complete_combat(true)
	_check(boss.finished and boss.escaped and boss.gold == 0, "WIN_GOLD is not paid for the boss")


func _test_save_round_trip() -> void:
	var state := _at_vendor(9, &"medium")
	state.gold = 300
	var offer := state.vendor().relic_offer()
	state.vendor_buy_relic()
	state.leave_vendor()
	var dict := RunSave.to_dict(state)
	_check(dict["relics"] == [String((offer["relic"] as RelicData).id)], "to_dict lists the relic ids")
	var json := JSON.new()
	json.parse(JSON.stringify(dict))
	var loaded := RunSave.from_dict(json.data)
	_check(loaded.run != null and loaded.run.relics == state.relics, "relics survive a save round trip")
	if loaded.run != null:
		_check(RunSave.to_dict(loaded.run) == dict, "the restored run saves back identically")
		_check(loaded.run.player.max_hp == state.player.max_hp and loaded.run.player.hp == state.player.hp, "a MAX_HP relic is not applied a second time on restore")
	var flask := StarterContent.all_relics().filter(func(r: RelicData) -> bool: return r.kind == RelicData.Kind.MAX_HP)[0] as RelicData
	var tough := RunState.new(1)
	tough.player.max_hp += flask.amount
	tough.player.hp += flask.amount
	tough.relics.assign([flask])
	var restored := RunSave.from_dict(RunSave.to_dict(tough)).run
	_check(restored != null and restored.player.max_hp == tough.player.max_hp, "restored max HP equals the saved max HP")
	var old := RunSave.to_dict(RunState.new(3))
	old["version"] = 2 # v3 requires the relics field; a v2 save without it is migrated
	old.erase("relics")
	var legacy := RunSave.from_dict(old)
	_check(legacy.run != null and legacy.run.relics.is_empty(), "a save without relics loads with none")


func _test_save_rejects_bad_relics() -> void:
	var own := String(StarterContent.relic_pool(&"deserter")[3].id)
	var other := String(StarterContent.relic_pool(&"pickpocket")[3].id)
	var good := RunSave.to_dict(RunState.new(3, &"deserter"))
	good["relics"] = [own]
	_check(RunSave.from_dict(good).run != null, "a valid relic id loads")
	for bad in ["x", 5, null, ["no_such_relic"], [5], [own, own], [other], [own, ""], {"a": 1}, [[own]]]:
		var data := RunSave.to_dict(RunState.new(3, &"deserter"))
		data["relics"] = bad
		_check(RunSave.from_dict(data).run == null, "relics = %s is rejected" % JSON.stringify(bad))
	var many: Array = []
	for i in 40:
		many.append(own)
	var data := RunSave.to_dict(RunState.new(3, &"deserter"))
	data["relics"] = many
	_check(RunSave.from_dict(data).run == null, "an oversized relic list is rejected")
