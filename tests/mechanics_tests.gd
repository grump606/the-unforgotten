extends RefCounted
## Card mechanics beyond plain damage and block: Hold, damage from Block, thorns.
## Registered by run_tests.gd. Each test builds tiny hand-made cards so the numbers
## checked here are the rules themselves, not the tuning of any real card.

var _failures := 0


func run() -> int:
	_failures = 0
	_test_hold_carries_block()
	_test_damage_from_block()
	_test_conditional_damage_from_block()
	_test_thorns()
	_test_gain_energy()
	_test_damage_per_play()
	_test_describe()
	_test_real_cards()
	_test_pickpocket_cards()
	_test_every_kind_is_covered()
	_test_player_listener_lifecycle()
	return _failures


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAIL: " + label)


func _fx(kind: CardEffect.Kind, amount: int, bonus: int = 0, threshold: int = 0) -> CardEffect:
	return CardEffect.make(kind, amount, bonus, threshold)


func _self_card(cost: int, effects: Array[CardEffect]) -> CardData:
	return CardData.make(&"t", "T", cost, effects, CardData.TargetMode.SELF)


func _attack_card(cost: int, effects: Array[CardEffect]) -> CardData:
	return CardData.make(&"t", "T", cost, effects)


func _enemies(count: int, hp: int, intents: Array[CardEffect]) -> Array[EnemyData]:
	var list: Array[EnemyData] = []
	for i in count:
		list.append(EnemyData.make("E%d" % i, hp, intents))
	return list


## A started fight whose opening hand is `hand` (a deck no bigger than the hand size is dealt whole).
func _fight(hand: Array[CardData], enemy_hp: int = 100, intents: Array[CardEffect] = [], enemy_count: int = 1) -> Combat:
	var combat := Combat.new(Combatant.new("p", 40), hand, _enemies(enemy_count, enemy_hp, intents))
	combat.start()
	return combat


func _play(combat: Combat, card: CardData, target: int = 0) -> bool:
	return combat.play_card(combat.piles.hand.find(card), target)


func _test_hold_carries_block() -> void:
	var hold_card := _self_card(0, [_fx(CardEffect.Kind.BLOCK, 6), _fx(CardEffect.Kind.HOLD, 3)])
	var combat := _fight([hold_card])
	_play(combat, hold_card)
	_check(combat.player.block == 6 and combat.player.hold == 3, "Hold is recorded alongside the Block")
	combat.end_player_turn()
	_check(combat.player.block == 3 and combat.player.hold == 0, "only the held 3 of 6 Block carries into the next turn, and Hold resets")

	var other := _self_card(0, [_fx(CardEffect.Kind.BLOCK, 6), _fx(CardEffect.Kind.HOLD, 3)])
	var two := _fight([hold_card, other])
	_play(two, hold_card)
	_play(two, other)
	two.end_player_turn()
	_check(two.player.block == 6, "two Hold cards keep 3 + 3 = 6 Block")

	# An attack eats Block first: 6 Block less 4 damage leaves 2, so only 2 of the Hold 3 survives.
	var hit := _fight([hold_card], 100, [_fx(CardEffect.Kind.DAMAGE, 4)])
	_play(hit, hold_card)
	hit.end_player_turn()
	_check(hit.player.block == 2 and hit.player.hp == 40, "Hold keeps at most the Block that survived the enemy phase")

	var crushed := _fight([hold_card], 100, [_fx(CardEffect.Kind.DAMAGE, 20)])
	_play(crushed, hold_card)
	crushed.end_player_turn()
	_check(crushed.player.block == 0, "when the attack breaks through, nothing is left to hold")

	var big_hold := _self_card(0, [_fx(CardEffect.Kind.BLOCK, 2), _fx(CardEffect.Kind.HOLD, 9)])
	var capped := _fight([big_hold])
	_play(capped, big_hold)
	capped.end_player_turn()
	_check(capped.player.block == 2, "Hold never keeps more Block than there is")

	var plain := _self_card(0, [_fx(CardEffect.Kind.BLOCK, 5)])
	var reset := _fight([plain])
	_play(reset, plain)
	reset.end_player_turn()
	_check(reset.player.block == 0, "Block without Hold still resets each turn")

	var once := _fight([hold_card])
	_play(once, hold_card)
	once.end_player_turn()
	once.end_player_turn()
	_check(once.player.block == 0, "held Block is kept for one turn, not forever")

	var ending := _fight([hold_card], 1)
	_play(ending, hold_card)
	_check(ending.player.hold == 3, "setup: Hold is pending mid-fight")
	ending.abandon()
	_check(ending.player.hold == 0 and ending.player.thorns == 0, "abandoning a fight clears Hold and Thorns")


func _test_damage_from_block() -> void:
	var block_card := _self_card(0, [_fx(CardEffect.Kind.BLOCK, 7)])
	var bash := _attack_card(0, [_fx(CardEffect.Kind.DAMAGE_PER_BLOCK, 1)])
	var cold := _fight([bash])
	_play(cold, bash)
	_check(cold.enemies[0].hp == 100, "with no Block it deals nothing")

	var combat := _fight([block_card, bash])
	_play(combat, block_card)
	_play(combat, bash)
	_check(combat.enemies[0].hp == 93 and combat.player.block == 7, "it deals damage equal to current Block and spends none of it")

	var doubled := _attack_card(0, [_fx(CardEffect.Kind.DAMAGE_PER_BLOCK, 2)])
	var twice := _fight([block_card, doubled])
	_play(twice, block_card)
	_play(twice, doubled)
	_check(twice.enemies[0].hp == 86, "a multiplier of 2 doubles the Block into damage")

	# It hits every target of an all-enemies card.
	var sweep := CardData.make(&"s", "S", 0, [_fx(CardEffect.Kind.DAMAGE_PER_BLOCK, 1)], CardData.TargetMode.ALL_ENEMIES)
	var spread := _fight([block_card, sweep], 100, [], 2)
	_play(spread, block_card)
	_play(spread, sweep)
	_check(spread.enemies[0].hp == 93 and spread.enemies[1].hp == 93, "an all-enemies Block-damage card hits each enemy")


func _test_conditional_damage_from_block() -> void:
	var steel := _attack_card(0, [_fx(CardEffect.Kind.DAMAGE_IF_BLOCK, 5, 10, 10)])
	var below := _fight([steel])
	_play(below, steel)
	_check(below.enemies[0].hp == 95, "below the threshold the base damage applies")

	var ten := _self_card(0, [_fx(CardEffect.Kind.BLOCK, 10)])
	var at := _fight([ten, steel])
	_play(at, ten)
	_play(at, steel)
	_check(at.enemies[0].hp == 90, "at exactly the threshold the bonus damage applies")

	var nine := _self_card(0, [_fx(CardEffect.Kind.BLOCK, 9)])
	var under := _fight([nine, steel])
	_play(under, nine)
	_play(under, steel)
	_check(under.enemies[0].hp == 95, "one short of the threshold still deals the base damage")


func _test_thorns() -> void:
	var stance := _self_card(0, [_fx(CardEffect.Kind.BLOCK, 8), _fx(CardEffect.Kind.THORNS, 4)])
	var attack := [_fx(CardEffect.Kind.DAMAGE, 5)] as Array[CardEffect]

	var combat := _fight([stance], 50, attack)
	_play(combat, stance)
	combat.end_player_turn()
	_check(combat.enemies[0].hp == 46 and combat.player.hp == 40, "a fully blocked attack still triggers thorns")
	_check(combat.player.thorns == 0, "thorns end with the enemy phase")

	var multi := _fight([stance], 50, [_fx(CardEffect.Kind.DAMAGE, 1)], 3)
	_play(multi, stance)
	multi.end_player_turn()
	var all_hit := true
	for enemy in multi.enemies:
		all_hit = all_hit and enemy.hp == 46
	_check(all_hit, "each attacker takes the thorns damage")

	var other := _self_card(0, [_fx(CardEffect.Kind.BLOCK, 8), _fx(CardEffect.Kind.THORNS, 4)])
	var stacked := _fight([stance, other], 50, [_fx(CardEffect.Kind.DAMAGE, 1)])
	_play(stacked, stance)
	_play(stacked, other)
	stacked.end_player_turn()
	_check(stacked.enemies[0].hp == 42, "two thorns cards stack: 4 + 4")

	var finishing := _fight([stance], 4, [_fx(CardEffect.Kind.DAMAGE, 1)])
	var won := [false]
	finishing.combat_ended.connect(func(victory: bool) -> void: won[0] = victory)
	_play(finishing, stance)
	finishing.end_player_turn()
	_check(won[0] and finishing.phase == Combat.Phase.ENDED, "thorns that kill the last enemy win the fight")

	# A hit that kills the player while the thorns kill the last enemy is a defeat, not a win.
	var mutual := _fight([stance], 3, [_fx(CardEffect.Kind.DAMAGE, 50)])
	var outcome := [null]
	mutual.combat_ended.connect(func(victory: bool) -> void: outcome[0] = victory)
	_play(mutual, stance)
	mutual.player.hp = 1
	mutual.player.block = 0
	mutual.end_player_turn()
	_check(mutual.enemies[0].is_dead() and mutual.player.is_dead(), "setup: the thorns and the hit kill both sides")
	_check(outcome[0] == false and mutual.phase == Combat.Phase.ENDED, "when the player and the last enemy die together it is a defeat")

	var passive := _fight([stance], 50, [_fx(CardEffect.Kind.BLOCK, 3)])
	_play(passive, stance)
	passive.end_player_turn()
	_check(passive.enemies[0].hp == 50, "an enemy that does not attack takes no thorns damage")

	var none := _fight([stance], 50, [_fx(CardEffect.Kind.DAMAGE, 1)])
	none.end_player_turn()
	_check(none.enemies[0].hp == 50, "no thorns played, no thorns damage")

	# Exposed attackers take thorns damage like any other hit.
	var expose := _attack_card(0, [_fx(CardEffect.Kind.EXPOSE, 2)])
	var exposed := _fight([stance, expose], 50, [_fx(CardEffect.Kind.DAMAGE, 1)])
	_play(exposed, expose)
	_play(exposed, stance)
	exposed.end_player_turn()
	_check(exposed.enemies[0].hp == 44, "thorns damage on an Exposed attacker is scaled like any hit (4 x 1.5 = 6)")


func _test_describe() -> void:
	_check(_fx(CardEffect.Kind.HOLD, 3).describe() == "Hold 3", "Hold describes itself")
	_check(_fx(CardEffect.Kind.THORNS, 4).describe() == "Thorns 4", "Thorns describes itself")
	_check(_fx(CardEffect.Kind.DAMAGE_PER_BLOCK, 1).describe() == "Deal damage equal to your Block", "Block damage describes itself")
	_check(_fx(CardEffect.Kind.DAMAGE_PER_BLOCK, 2).describe() == "Deal 2x your Block", "a multiplied Block damage describes the multiplier")
	_check(_fx(CardEffect.Kind.DAMAGE_IF_BLOCK, 5, 10, 10).describe() == "Deal 5 (10 with 10+ Block)", "conditional damage describes both numbers")
	# The pre-existing kinds keep their stored integer values (.tres files hold the number).
	_check(CardEffect.Kind.DAMAGE == 0 and CardEffect.Kind.BLOCK == 1 and CardEffect.Kind.DRAW == 2 and CardEffect.Kind.EXPOSE == 3, "existing effect kinds keep their integer values")


## The real Deserter cards, loaded from data, do what their text says.
func _test_real_cards() -> void:
	var cards := {}
	for path in StarterContent.ALL_CARD_PATHS:
		var card := load(path) as CardData
		cards[card.id] = card
	for id in [&"hold_the_line", &"bash", &"dig_in", &"cold_steel", &"counter_stance", &"last_stand"]:
		_check(cards.has(id) and (cards[id] as CardData).character == &"deserter", "%s is a Deserter card" % id)
	_check(cards[&"hold_the_line"].describe() == "Block 5, Hold 2", "Hold the Line text")
	_check(cards[&"last_stand"].cost == 3 and cards[&"last_stand"].describe() == "Block 14, Hold 10", "Last Stand text")
	_check(cards[&"counter_stance"].describe() == "Block 8, Thorns 4", "Counter-Stance text")
	_check(cards[&"cold_steel"].describe() == "Deal 5 (10 with 10+ Block)", "Cold Steel text")

	# Last Stand: Block 14, of which 10 is held through an empty enemy phase.
	var last_stand: CardData = cards[&"last_stand"]
	var fight := Combat.new(Combatant.new("p", 40), [last_stand] as Array[CardData], _enemies(1, 100, []))
	fight.start()
	fight.play_card(0)
	fight.end_player_turn()
	_check(fight.player.block == 10, "Last Stand carries the 10 it holds")

	# Bash after Hold the Line: 5 Block, 5 damage.
	var hold_line: CardData = cards[&"hold_the_line"]
	var bash: CardData = cards[&"bash"]
	var combo := Combat.new(Combatant.new("p", 40), [hold_line, bash] as Array[CardData], _enemies(1, 100, []))
	combo.start()
	combo.play_card(combo.piles.hand.find(hold_line))
	combo.play_card(combo.piles.hand.find(bash), 0)
	_check(combo.enemies[0].hp == 95, "Hold the Line then Bash deals 5")


# --- Pickpocket mechanics: gaining energy, damage per card played -------------

func _test_gain_energy() -> void:
	var surge := _self_card(0, [_fx(CardEffect.Kind.GAIN_ENERGY, 2)])
	var big := _attack_card(3, [_fx(CardEffect.Kind.DAMAGE, 9)])
	var combat := _fight([surge, big])
	_play(combat, surge)
	_check(combat.energy == Combat.ENERGY_PER_TURN + 2, "gaining energy lifts it above the per-turn amount")
	_check(_play(combat, big) and combat.energy == 2, "the gained energy pays for a card")
	combat.end_player_turn()
	_check(combat.energy == Combat.ENERGY_PER_TURN, "gained energy does not carry into the next turn")

	# Paying a card's cost before its effects means a cost-1 gain-1 card is energy-neutral.
	var watch := _self_card(1, [_fx(CardEffect.Kind.GAIN_ENERGY, 1), _fx(CardEffect.Kind.DRAW, 1)])
	var neutral := _fight([watch])
	_play(neutral, watch)
	_check(neutral.energy == Combat.ENERGY_PER_TURN, "a card that costs 1 and gains 1 leaves energy unchanged")

	# A card that costs more than the energy left is still unplayable even if a later card would refund it.
	var spare := _fight([_attack_card(3, [_fx(CardEffect.Kind.DAMAGE, 1)])])
	_check(spare.can_play(0), "setup: a cost-3 card is playable with 3 energy")

	# An enemy intent cannot hand the player energy.
	# Energy is reset when the next turn starts, so look at it as the enemy acts.
	var odd_intent := _fight([surge], 50, [_fx(CardEffect.Kind.GAIN_ENERGY, 5)])
	var seen_energy := []
	odd_intent.enemy_acted.connect(func(_enemy: EnemyUnit, _intent: CardEffect) -> void: seen_energy.append(odd_intent.energy))
	odd_intent.end_player_turn()
	_check(seen_energy == [Combat.ENERGY_PER_TURN], "an enemy intent with GAIN_ENERGY does nothing to the player (saw %s)" % str(seen_energy))


func _test_damage_per_play() -> void:
	var last_pocket := _attack_card(0, [_fx(CardEffect.Kind.DAMAGE_PER_PLAY, 4, 3)])
	var first := _fight([last_pocket])
	_play(first, last_pocket)
	_check(first.enemies[0].hp == 96, "played first, it deals only its base damage")

	var filler_a := _self_card(0, [_fx(CardEffect.Kind.BLOCK, 1)])
	var filler_b := _self_card(0, [_fx(CardEffect.Kind.BLOCK, 1)])
	var third := _fight([filler_a, filler_b, last_pocket])
	_play(third, filler_a)
	_play(third, filler_b)
	_play(third, last_pocket)
	_check(third.enemies[0].hp == 90, "after two earlier cards it deals 4 + 3 x 2 = 10")

	var next_turn := _fight([last_pocket, filler_a])
	_play(next_turn, filler_a)
	_play(next_turn, last_pocket)
	_check(next_turn.enemies[0].hp == 93, "one earlier card: 4 + 3 = 7")

	# The count restarts every turn.
	var many: Array[CardData] = []
	for i in 3:
		many.append(_self_card(0, [_fx(CardEffect.Kind.BLOCK, 1)]))
	many.append(last_pocket)
	var again := _fight(many)
	for i in 3:
		_play(again, many[i])
	again.end_player_turn()
	# A deck of four cards is redrawn whole, so Last Pocket is in the new hand.
	_play(again, last_pocket)
	_check(again.enemies[0].hp == 96, "the count resets with the new turn (a first play deals the base 4)")

	# Spree: 2 per card played, counting itself.
	var spree := _attack_card(0, [_fx(CardEffect.Kind.DAMAGE_PER_PLAY, 2, 2)])
	var alone := _fight([spree])
	_play(alone, spree)
	_check(alone.enemies[0].hp == 98, "Spree alone deals 2")
	var after_two := _fight([filler_a, filler_b, spree])
	_play(after_two, filler_a)
	_play(after_two, filler_b)
	_play(after_two, spree)
	_check(after_two.enemies[0].hp == 94, "Spree as the third card deals 2 x 3 = 6")

	# Every target of an all-enemies card takes the same scaled damage.
	var sweep := CardData.make(&"s", "S", 0, [_fx(CardEffect.Kind.DAMAGE_PER_PLAY, 1, 1)], CardData.TargetMode.ALL_ENEMIES)
	var spread := _fight([filler_a, sweep], 100, [], 2)
	_play(spread, filler_a)
	_play(spread, sweep)
	_check(spread.enemies[0].hp == 98 and spread.enemies[1].hp == 98, "an all-enemies per-play card hits each enemy for the scaled amount")

	# Exposed targets take the scaled damage x 1.5 like any hit.
	var expose := _attack_card(0, [_fx(CardEffect.Kind.EXPOSE, 2)])
	var marked := _fight([expose, last_pocket])
	_play(marked, expose)
	_play(marked, last_pocket)
	_check(marked.enemies[0].hp == 90, "the scaled damage is increased by Expose: (4 + 3) x 1.5 = 10")


func _test_pickpocket_cards() -> void:
	var cards := {}
	for path in StarterContent.ALL_CARD_PATHS:
		var card := load(path) as CardData
		cards[card.id] = card
	for id in [&"lift", &"sleight", &"pocket_watch", &"last_pocket", &"spree"]:
		_check(cards.has(id) and (cards[id] as CardData).character == &"pickpocket", "%s is a Pickpocket card" % id)
	_check(cards[&"lift"].describe() == "Deal 3, Draw 1", "Lift text")
	_check(cards[&"pocket_watch"].describe() == "Gain 1 energy, Draw 1", "Pocket Watch text")
	_check(cards[&"last_pocket"].describe() == "Deal 4, +3 for each card played earlier this turn", "Last Pocket text")
	_check(cards[&"sleight"].cost == 0 and cards[&"lift"].cost == 1 and cards[&"spree"].cost == 2, "costs: Sleight 0, Lift 1, Spree 2")

	# A real chain: Sleight (0) exposes, Pocket Watch (net 0 energy), Last Pocket (third card).
	var sleight: CardData = cards[&"sleight"]
	var watch: CardData = cards[&"pocket_watch"]
	var last_pocket: CardData = cards[&"last_pocket"]
	var chain := Combat.new(Combatant.new("p", 40), [sleight, watch, last_pocket] as Array[CardData], _enemies(1, 100, []))
	chain.start()
	chain.play_card(chain.piles.hand.find(sleight), 0)
	chain.play_card(chain.piles.hand.find(watch))
	_check(chain.energy == Combat.ENERGY_PER_TURN, "Sleight and Pocket Watch together cost no energy")
	chain.play_card(chain.piles.hand.find(last_pocket), 0)
	_check(chain.enemies[0].hp == 100 - (4 + 3 * 2) * 3 / 2, "Last Pocket as the third card on an Exposed target deals (4 + 6) x 1.5 = 15")


## Every CardEffect.Kind must have a describe text, a vendor valuation and a Combat handler. Adding a
## kind without all three fails here, naming the kind.
func _test_every_kind_is_covered() -> void:
	for kind_name in CardEffect.Kind.keys():
		var kind: CardEffect.Kind = CardEffect.Kind[kind_name]
		var effect := _fx(kind, 2, 5, 3)
		_check(effect.describe() != "", "describe text exists for %s" % kind_name)
		_check(Vendor.effect_value(effect) != Vendor.UNVALUED, "vendor valuation exists for %s" % kind_name)
		_check(effect.reach() in [CardEffect.Reach.SELF, CardEffect.Reach.ENEMIES, CardEffect.Reach.BOTH], "reach exists for %s" % kind_name)
		# Handler: playing the effect must change something observable.
		var filler: Array[CardData] = []
		for i in 12:
			filler.append(_self_card(0, [_fx(CardEffect.Kind.BLOCK, 1)]))
		var combat := Combat.new(Combatant.new("p", 40, 30), filler, _enemies(1, 100, []))
		combat.start()
		combat.player.gain_block(5)
		combat.enemies[0].apply_status(Combatant.Status.HAUNTED, 3)
		var card := _attack_card(0, [effect])
		combat.piles.hand.append(card)
		var before := _snapshot(combat)
		_check(_play(combat, card), "%s card plays" % kind_name)
		_check(_snapshot(combat) != before, "Combat has a handler for %s" % kind_name)
		combat.abandon()


func _snapshot(combat: Combat) -> Array:
	var enemy := combat.enemies[0]
	return [
		combat.player.hp, combat.player.block, combat.player.hold, combat.player.thorns,
		combat.energy, combat.piles.hand.size(),
		combat.player.status_turns(Combatant.Status.EXPOSED),
		enemy.hp, enemy.block, enemy.status_turns(Combatant.Status.HAUNTED), enemy.status_turns(Combatant.Status.EXPOSED),
	]


## The player link is made by start() and removed on every way a fight can finish, so a fight that
## is built and dropped (or abandoned before starting) leaves the long-lived player untouched.
func _test_player_listener_lifecycle() -> void:
	var player := Combatant.new("p", 40)
	var deck: Array[CardData] = [_self_card(0, [_fx(CardEffect.Kind.BLOCK, 1)])]
	var base := player.changed.get_connections().size()
	var unstarted := Combat.new(player, deck, _enemies(1, 10, []))
	_check(player.changed.get_connections().size() == base, "an unstarted Combat leaves no listener on the player")
	unstarted.abandon()
	_check(unstarted.phase == Combat.Phase.ENDED and player.changed.get_connections().size() == base, "abandon() before start is safe and leaves no listener")
	var started := Combat.new(player, deck, _enemies(1, 10, []))
	started.start()
	_check(player.changed.get_connections().size() == base + 1, "start() connects exactly one listener")
	var emitted := [0]
	started.state_changed.connect(func() -> void: emitted[0] += 1)
	player.gain_block(1)
	_check(emitted[0] > 0, "a started Combat forwards player changes to state_changed")
	started.abandon()
	_check(player.changed.get_connections().size() == base, "abandon() after start removes the listener")
	started.abandon()
	var ended := Combat.new(player, [_attack_card(0, [_fx(CardEffect.Kind.DAMAGE, 9)])], _enemies(1, 5, []))
	ended.start()
	_check(ended.play_card(0, 0) and ended.phase == Combat.Phase.ENDED, "the fight ends on lethal damage")
	_check(player.changed.get_connections().size() == base, "a fight that ends normally removes its listener")
	ended.abandon()
	var before_start := Combat.new(player, deck, _enemies(1, 10, []))
	before_start.abandon()
	before_start.start()
	_check(before_start.phase == Combat.Phase.ENDED and player.changed.get_connections().size() == base, "start() after abandon() is refused and connects nothing")
