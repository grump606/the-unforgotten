extends RefCounted
## Phase 4d (docs/MAP_DESIGN.md): the enemy threat measure, the map fight budget curve and the budget pack builder,
## plus a golden check that the line's encounters did not change. Registered by run_tests.gd.

var _failures := 0
var _checks := 0


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FAIL: " + label)


func run() -> int:
	_failures = 0
	_checks = 0
	_test_enemy_threat()
	_test_pack_threat()
	_test_budget_curve()
	_test_calibration_against_the_line()
	_test_pack_builder_meets_budget()
	_test_class_difficulty()
	_test_pack_builder_bounds()
	_test_pack_builder_deterministic()
	_test_pack_builder_does_not_mutate()
	_test_counts_are_comparable()
	_test_pack_shape_by_count()
	_test_every_enemy_appears()
	_test_elite_and_multiplier()
	_test_split_scaling()
	_test_line_encounters_unchanged()
	_test_run_state_uses_it()
	print("threat tests: %d checks, %d failures" % [_checks, _failures])
	return _failures


func _enemy(hp: int, damage: int, hits: int = 1) -> EnemyData:
	var intents: Array[CardEffect] = [CardEffect.make(CardEffect.Kind.DAMAGE, damage, 0, 0, hits)]
	return EnemyData.make("T", hp, intents, &"t")


func _test_enemy_threat() -> void:
	var base := _enemy(20, 5)
	_check(is_equal_approx(StarterContent.enemy_threat(base), 5.0 * 20.0 / StarterContent.THREAT_REF_DPS), "threat is turn damage times HP over the reference output")
	_check(StarterContent.enemy_threat(_enemy(30, 5)) > StarterContent.enemy_threat(base), "more HP is more threat")
	_check(StarterContent.enemy_threat(_enemy(20, 8)) > StarterContent.enemy_threat(base), "more damage is more threat")
	_check(StarterContent.enemy_threat(_enemy(20, 5, 3)) > StarterContent.enemy_threat(base), "a multi-hit counts every hit")
	_check(is_equal_approx(StarterContent.enemy_threat(_enemy(20, 5, 3)), StarterContent.enemy_threat(_enemy(20, 15))), "three hits of 5 equal one hit of 15")
	var previous := 0.0
	for hp in range(1, 60):
		var t := StarterContent.enemy_threat(_enemy(hp, 7))
		_check(t > previous, "threat rises with HP (%d)" % hp)
		previous = t
	# Status intents add their points to the cycle.
	var with_status: Array[CardEffect] = [CardEffect.make(CardEffect.Kind.DAMAGE, 6), CardEffect.make(CardEffect.Kind.EXPOSE, 2)]
	var plain: Array[CardEffect] = [CardEffect.make(CardEffect.Kind.DAMAGE, 6), CardEffect.make(CardEffect.Kind.BLOCK, 9)]
	_check(StarterContent.enemy_threat(EnemyData.make("S", 20, with_status)) > StarterContent.enemy_threat(EnemyData.make("P", 20, plain)), "a debuff adds threat and a Block adds none")
	_check(is_equal_approx(StarterContent._turn_damage(EnemyData.make("S", 20, with_status)), (6.0 + 2.0 * StarterContent.THREAT_STATUS_POINTS[CardEffect.Kind.EXPOSE]) / 2.0), "the status weight is read from the table")
	_check(StarterContent.enemy_threat(EnemyData.make("N", 20, [] as Array[CardEffect])) == 0.0, "an enemy with no intents has no threat")
	# Every regular enemy has a positive threat, and the table matches the documented order of magnitude.
	var colossus := StarterContent.enemy_by_id(&"hollow_colossus")
	var crow := StarterContent.enemy_by_id(&"mourning_crow")
	_check(StarterContent.enemy_threat(colossus) > StarterContent.enemy_threat(crow) * 5.0, "the colossus is far more dangerous than the crow")
	for enemy in StarterContent.enemy_pool():
		_check(StarterContent.enemy_threat(enemy) > 0.0, "%s has a positive threat" % enemy.id)


func _test_pack_threat() -> void:
	var a := _enemy(20, 6)
	var b := _enemy(30, 4)
	var solo: Array[EnemyData] = [a]
	_check(is_equal_approx(StarterContent.pack_threat(solo), StarterContent.enemy_threat(a)), "a pack of one is that enemy's threat")
	var pair: Array[EnemyData] = [a, b]
	var swapped: Array[EnemyData] = [b, a]
	_check(is_equal_approx(StarterContent.pack_threat(pair), StarterContent.pack_threat(swapped)), "pack threat ignores the listed order")
	_check(StarterContent.pack_threat(pair) > StarterContent.enemy_threat(a) + StarterContent.enemy_threat(b), "a pair is worth more than the sum: the survivor keeps hitting")
	var bigger: Array[EnemyData] = [a, _enemy(30, 6)]
	_check(StarterContent.pack_threat(bigger) > StarterContent.pack_threat(pair), "a stronger member makes a stronger pack")
	var trio: Array[EnemyData] = [a, b, _enemy(10, 3)]
	_check(StarterContent.pack_threat(trio) > StarterContent.pack_threat(pair), "adding an enemy adds threat")
	var none: Array[EnemyData] = []
	_check(StarterContent.pack_threat(none) == 0.0, "an empty pack has no threat")


func _test_budget_curve() -> void:
	for row in range(0, StarterContent.MAP_ACT_ROWS - 1):
		_check(StarterContent.fight_budget(row + 1) >= StarterContent.fight_budget(row), "act 1 budget never drops (row %d)" % row)
	for row in range(StarterContent.MAP_ACT_ROWS, StarterContent.MAP_ACT_ROWS * 2 - 1):
		_check(StarterContent.fight_budget(row + 1) >= StarterContent.fight_budget(row), "act 2 budget never drops (row %d)" % row)
	var act_step := StarterContent.fight_budget(15) / StarterContent.fight_budget(14)
	_check(act_step > 0.9 and act_step < 1.1, "the act change is not a wall: act 2 starts within 10%% of where act 1 ends (%.2f)" % act_step)
	_check(StarterContent.fight_budget(15) > StarterContent.fight_budget(0) * 1.3, "act 2 starts clearly above the first fight")
	_check(StarterContent.fight_budget(29) > StarterContent.fight_budget(15) * 1.2, "act 2 keeps rising to the final boss")
	_check(StarterContent.fight_budget(-5) == StarterContent.fight_budget(0) and StarterContent.fight_budget(400) == StarterContent.fight_budget(29), "the curve clamps its row")
	_check(StarterContent.fight_budget(0) > 0.0, "every budget is positive")
	_check(is_equal_approx(StarterContent.fight_budget(0), StarterContent.MAP_DIFFICULTY * StarterContent.BUDGET_ACT_START[0]), "row 0 is the act 1 start times the difficulty")
	_check(is_equal_approx(StarterContent.fight_budget(29), StarterContent.MAP_DIFFICULTY * StarterContent.BUDGET_ACT_END[1]), "row 29 is the act 2 end times the difficulty")


## The budget shape started as a fit of the line's average pack threat per fight number, and phase 4f flattened act 2 (a
## smaller start-of-act-2 step, a lower end): act 1's mean stays within 10% of the line's, act 2's within 20%.
func _test_calibration_against_the_line() -> void:
	var counts: Array[int] = [1, 2, 2, 2, 2, 3, 2, 3]
	var act_mean: Array[float] = [0.0, 0.0]
	var samples := 120
	for fight in counts.size():
		var tier := 0 if fight < 4 else 1
		for s in samples:
			var rng := RandomNumberGenerator.new()
			rng.seed = 5000 + s
			act_mean[tier] += StarterContent.pack_threat(StarterContent.varied_encounter(counts[fight], rng, tier, fight)) / float(samples * 4)
	for act in 2:
		var budget_mean := 0.0
		for local in StarterContent.MAP_ACT_ROWS - 1:
			budget_mean += StarterContent.fight_budget(act * StarterContent.MAP_ACT_ROWS + local) / float(StarterContent.MAP_ACT_ROWS - 1)
		var tolerance := 0.1 if act == 0 else 0.2
		_check(absf(budget_mean / StarterContent.MAP_DIFFICULTY - act_mean[act]) < act_mean[act] * tolerance, "act %d mean budget (%.1f) is within %d%% of the line's mean pack threat (%.1f)" % [act + 1, budget_mean / StarterContent.MAP_DIFFICULTY, tolerance * 100.0, act_mean[act]])


func _pack(count: int, seed_value: int, row: int, multiplier: float = 1.0, elite: bool = false) -> Array[EnemyData]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return StarterContent.budget_encounter(count, rng, row, multiplier, elite)


func _test_pack_builder_meets_budget() -> void:
	var packs := 0
	var bound_hits := 0
	for row in 29:
		for count in range(1, 4):
			for s in 25:
				var pack := _pack(count, 900 + s * 7 + row, row)
				var info := StarterContent.last_pack_info
				packs += 1
				_check(pack.size() == count, "row %d: a pack of %d has %d enemies" % [row, count, pack.size()])
				var target := StarterContent.fight_budget(row)
				if info["bound_hit"]:
					bound_hits += 1
					continue
				_check(absf(StarterContent.pack_threat(pack) - target) <= target * 0.08, "row %d count %d seed %d: threat %.1f within 8%% of the budget %.1f" % [row, count, s, StarterContent.pack_threat(pack), target])
	_check(bound_hits * 100 <= packs, "the scale bounds bite in at most 1%% of packs (%d of %d)" % [bound_hits, packs])


## Phase 4f: every character has a map-mode budget multiplier (a character that is not listed uses 1).
func _test_class_difficulty() -> void:
	for id in [&"deserter", &"thief", &"medium", &"stray"]:
		var factor := StarterContent.map_class_difficulty(id)
		_check(factor >= 0.7 and factor <= 1.3, "%s: the class multiplier %.2f is a modest correction" % [id, factor])
	_check(StarterContent.map_class_difficulty(&"nobody") == 1.0 and StarterContent.map_class_difficulty(&"") == 1.0, "an unlisted character uses 1.0")
	# The multiplier scales the pack the run builds: the same seed, row and count at a bigger multiplier is a harder pack.
	var easy := StarterContent.pack_threat(_pack(2, 41, 10, 0.8))
	var hard := StarterContent.pack_threat(_pack(2, 41, 10, 1.2))
	_check(hard > easy * 1.3, "a bigger class multiplier builds a tougher pack (%.1f against %.1f)" % [hard, easy])


func _test_pack_builder_bounds() -> void:
	for count in range(1, 4):
		var m_bounds := StarterContent.pack_multiplier_bounds(count)
		_check(m_bounds[0] < 1.0 and m_bounds[1] > 1.0, "count %d: the multiplier bounds straddle 1" % count)
	for row in [0, 7, 14, 15, 22, 28]:
		for count in range(1, 4):
			for s in 30:
				_pack(count, 33 + s, row)
				var info := StarterContent.last_pack_info
				_check(info["hp_scale"] >= StarterContent.PACK_SCALE_MIN - 0.0001 and info["hp_scale"] <= StarterContent.PACK_SCALE_MAX + 0.0001, "row %d count %d: HP factor %.3f in bounds" % [row, count, info["hp_scale"]])
				_check(info["damage_scale"] >= StarterContent.PACK_SCALE_MIN - 0.0001 and info["damage_scale"] <= StarterContent.PACK_SCALE_MAX + 0.0001, "row %d count %d: damage factor %.3f in bounds" % [row, count, info["damage_scale"]])
	# An impossible budget is never met by leaving the bounds: the pack stays at the nearest legal factor.
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var huge := StarterContent.budget_encounter(3, rng, 10, 50.0)
	var info := StarterContent.last_pack_info
	_check(info["bound_hit"] and info["hp_scale"] <= StarterContent.PACK_SCALE_MAX + 0.0001 and info["damage_scale"] <= StarterContent.PACK_SCALE_MAX + 0.0001, "an impossible budget settles for the legal maximum")
	_check(huge.size() == 3, "an impossible budget still gives a full pack")
	var rng_small := RandomNumberGenerator.new()
	rng_small.seed = 3
	StarterContent.budget_encounter(3, rng_small, 10, 0.01)
	_check(StarterContent.last_pack_info["hp_scale"] >= StarterContent.PACK_SCALE_MIN - 0.0001, "a trivial budget settles for the legal minimum")


func _fingerprint(pack: Array[EnemyData]) -> String:
	var parts: Array[String] = []
	for enemy in pack:
		var hits: Array[String] = []
		for intent in enemy.intents:
			hits.append("%d.%d.%d" % [int(intent.kind), intent.amount, intent.hits])
		parts.append("%s:%d:%s" % [enemy.id, enemy.max_hp, "/".join(hits)])
	return ",".join(parts)


func _test_pack_builder_deterministic() -> void:
	for count in range(1, 4):
		for row in [0, 9, 20]:
			_check(_fingerprint(_pack(count, 77, row)) == _fingerprint(_pack(count, 77, row)), "same seed, row %d and count %d give the same pack" % [row, count])
	var seen := {}
	for s in 20:
		seen[_fingerprint(_pack(2, s, 9))] = true
	_check(seen.size() > 5, "different seeds give different packs")
	# The builder draws only from the rng it is given: the next number after a pack is the same each time.
	var a := RandomNumberGenerator.new()
	a.seed = 12
	StarterContent.budget_encounter(2, a, 4)
	var b := RandomNumberGenerator.new()
	b.seed = 12
	StarterContent.budget_encounter(2, b, 4)
	_check(a.randi() == b.randi(), "the rng ends in the same state")


func _test_pack_builder_does_not_mutate() -> void:
	var before := {}
	for path in StarterContent.ALL_ENEMY_PATHS:
		before[path] = _fingerprint([load(path) as EnemyData] as Array[EnemyData])
	for row in [0, 10, 25]:
		for count in range(1, 4):
			for s in 10:
				_pack(count, s, row)
	for path in StarterContent.ALL_ENEMY_PATHS:
		_check(_fingerprint([load(path) as EnemyData] as Array[EnemyData]) == before[path], "%s resource is untouched by the builder" % path)
	var pack := _pack(3, 5, 12)
	var other := _pack(3, 5, 12)
	_check(pack[0] != other[0], "every pack owns its enemies")


func _mean_threat(count: int, row: int) -> float:
	var total := 0.0
	for s in 40:
		total += StarterContent.pack_threat(_pack(count, 2000 + s, row))
	return total / 40.0


func _test_counts_are_comparable() -> void:
	for row in [0, 5, 13, 15, 22, 28]:
		var one := _mean_threat(1, row)
		var two := _mean_threat(2, row)
		var three := _mean_threat(3, row)
		var target := StarterContent.fight_budget(row)
		_check(absf(one - three) < target * 0.1, "row %d: singles (%.1f) and trios (%.1f) have a comparable threat" % [row, one, three])
		_check(absf(two - three) < target * 0.1 and absf(two - target) < target * 0.1, "row %d: pairs sit on the budget too" % row)


func _test_pack_shape_by_count() -> void:
	for row in [3, 12, 20, 27]:
		var single_hp := 0.0
		var trio_hp := 0.0
		var trio_hit := 0
		var single_hit := 0
		for s in 30:
			for enemy in _pack(1, 400 + s, row):
				single_hp += enemy.max_hp / 30.0
				for intent in enemy.intents:
					single_hit = maxi(single_hit, intent.amount if intent.kind == CardEffect.Kind.DAMAGE else 0)
			for enemy in _pack(3, 400 + s, row):
				trio_hp += enemy.max_hp / 90.0
				for intent in enemy.intents:
					trio_hit = maxi(trio_hit, intent.amount if intent.kind == CardEffect.Kind.DAMAGE else 0)
		_check(single_hp > 30.0, "row %d: a lone enemy is a real one (mean HP %.1f)" % [row, single_hp])
		_check(trio_hp < 30.0, "row %d: a trio member is not a giant (mean HP %.1f)" % [row, trio_hp])
		_check(single_hp > trio_hp * 1.5, "row %d: a single has well over a trio member's HP" % row)
		_check(single_hit <= 24 and trio_hit <= 24, "row %d: no single hit is absurd (%d, %d)" % [row, single_hit, trio_hit])


func _test_every_enemy_appears() -> void:
	var seen := {}
	for row in [0, 8, 16, 24]:
		for count in range(1, 4):
			for s in 120:
				for enemy in _pack(count, 600 + s, row):
					seen[enemy.id] = true
	for enemy in StarterContent.enemy_pool():
		_check(seen.has(enemy.id), "%s shows up in budget packs" % enemy.id)


func _test_elite_and_multiplier() -> void:
	for s in 20:
		_check(_pack(1, s, 8, 1.0, true).size() == StarterContent.ELITE_MIN_ENEMIES, "an elite has at least two enemies")
		_check(_pack(3, s, 8, 1.0, true).size() == 3, "an elite can have three")
	_check(_pack(0, 1, 8).size() == 1 and _pack(9, 1, 8).size() == Combat.MAX_ENEMIES, "the count is clamped to 1..MAX_ENEMIES")
	var base := 0.0
	var tougher := 0.0
	for s in 30:
		base += StarterContent.pack_threat(_pack(2, 300 + s, 10, 1.0, true))
		tougher += StarterContent.pack_threat(_pack(2, 300 + s, 10, 1.4, true))
	_check(absf(tougher / base - 1.4) < 0.08, "the budget multiplier scales the pack's threat (x%.2f for 1.4)" % (tougher / base))


func _test_split_scaling() -> void:
	var shade := StarterContent.lost_shade()
	var same := StarterContent.scaled(shade, 1.5)
	var split := StarterContent.scaled(shade, 1.5, 1.0)
	_check(split.max_hp == same.max_hp, "the split scaling keeps the HP factor")
	_check(split.intents[0].amount == shade.intents[0].amount and same.intents[0].amount > shade.intents[0].amount, "a damage factor of its own replaces the HP factor for damage")
	_check(StarterContent.scaled(shade, 1.0, 1.0) == shade and StarterContent.scaled(shade, 1.0) == shade, "factor 1.0 still returns the enemy itself")
	_check(StarterContent.scaled(shade, 1.0, 1.5) != shade, "a damage-only factor builds a new enemy")


## The line's encounters are the values they have always been (captured from main before this phase).
func _test_line_encounters_unchanged() -> void:
	var golden := {
		"1,11,0,0": "mourning_crow:17:3/3/10|1402821896",
		"2,12,0,1": "lost_shade:28:9/11,skittering_wisp:16:4/4/16|1502192",
		"3,13,0,3": "mourning_crow:18:3/3/10,cinder_hound:23:5/9,pale_whisperer:19:6/9|3076890047",
		"2,14,1,4": "lost_shade:29:9/12,lost_shade:29:9/12|1552759863",
		"3,15,1,5": "skittering_wisp:17:4/4/17,cinder_hound:23:5/10,cinder_hound:23:5/10|614368737",
		"1,16,1,7": "mourning_crow:18:3/3/11|91301382",
		"2,17,1,7": "skittering_wisp:17:4/4/17,mourning_crow:18:3/3/11|2096993072",
		"3,18,0,2": "skittering_wisp:16:4/4/16,cinder_hound:23:5/9,cinder_hound:23:5/9|258863540",
	}
	for key in golden:
		var p: PackedStringArray = key.split(",")
		var rng := RandomNumberGenerator.new()
		rng.seed = int(p[1])
		var parts: Array[String] = []
		for enemy in StarterContent.varied_encounter(int(p[0]), rng, int(p[2]), int(p[3])):
			var damage: Array[String] = []
			for intent in enemy.intents:
				if intent.kind == CardEffect.Kind.DAMAGE:
					damage.append(str(intent.amount))
			parts.append("%s:%d:%s" % [enemy.id, enemy.max_hp, "/".join(damage)])
		_check("%s|%d" % [",".join(parts), rng.randi()] == golden[key], "line encounter %s is unchanged" % key)
	var line := RunState.new(5, &"deserter")
	for stop in line.stops:
		_check(stop.row == -1, "line stops have no row")
	_check(not line.uses_map(), "a line run is not a map run")


func _test_run_state_uses_it() -> void:
	var run_state := RunState.new(21, &"thief", true)
	var fights := 0
	for _step in 80:
		if run_state.finished:
			break
		var options := run_state.reachable_nodes()
		run_state.choose_node(options[0])
		var stop := run_state.current_stop()
		if stop.type == RunState.StopType.COMBAT and not stop.boss and not stop.mid_boss:
			var state := run_state.rng_state()
			var combat := run_state.start_combat()
			var replay := RandomNumberGenerator.new()
			replay.state = state
			var expected := StarterContent.budget_encounter(stop.enemy_count, replay, stop.row, StarterContent.map_class_difficulty(run_state.character.id))
			var hp_now: Array[int] = []
			for unit in combat.enemies:
				hp_now.append(unit.max_hp)
			var hp_expected: Array[int] = []
			for enemy in expected:
				hp_expected.append(enemy.max_hp)
			_check(hp_now == hp_expected, "map fight on row %d uses budget_encounter" % stop.row)
			fights += 1
			combat.abandon()
			run_state.restore_rng_state(state)
		match stop.type:
			RunState.StopType.COMBAT:
				run_state.complete_combat(true)
				if run_state.reward_pending():
					run_state.resolve_reward(null)
			RunState.StopType.REST:
				run_state.rest()
			RunState.StopType.STORY:
				run_state.read_story()
			RunState.StopType.VENDOR:
				run_state.leave_vendor()
			RunState.StopType.TREASURE:
				run_state.open_treasure()
				run_state.take_treasure()
			RunState.StopType.EVENT:
				SimPolicy.event_stop(run_state)
	_check(fights >= 8, "a map run has plenty of budget fights (%d)" % fights)
