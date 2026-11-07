extends SceneTree
## Prints the threat measure's numbers: every regular enemy's threat, the legacy line's average pack threat per
## regular fight (what the map budget curve is calibrated against), the budget curve, and for each run row and
## enemy count the distribution of pack threat from StarterContent.budget_encounter (how close it lands to the
## budget, how often the scale bounds bite, the scale factors, and which enemies show up).
## Run: godot --headless --path . -s res://tools/threat_table.gd -- [--seeds N] [--section enemies|legacy|budget|packs]
## --seeds N is the number of seeded packs per row and count (default 300, and 600 for the legacy average).

const LEGACY_COUNTS: Array[int] = [1, 2, 2, 2, 2, 3, 2, 3]
const LEGACY_TIERS: Array[int] = [0, 0, 0, 0, 1, 1, 1, 1]


func _initialize() -> void:
	var seeds := 300
	var section := "all"
	var args := OS.get_cmdline_user_args()
	var i := 0
	while i < args.size():
		if args[i] == "--seeds" and i + 1 < args.size():
			seeds = maxi(int(args[i + 1]), 1)
			i += 1
		elif args[i] == "--section" and i + 1 < args.size():
			section = args[i + 1]
			i += 1
		i += 1
	if section in ["all", "enemies"]:
		_print_enemies()
	if section in ["all", "legacy"]:
		_print_legacy(seeds * 2)
	if section in ["all", "budget"]:
		_print_budget()
	if section in ["all", "packs"]:
		_print_packs(seeds)
	quit(0)


func _print_enemies() -> void:
	print("Enemy threat (turn damage = average per turn over the intent cycle incl. status points; threat = turn damage * HP / %.0f)" % StarterContent.THREAT_REF_DPS)
	print("%-18s %-24s %4s %10s %8s" % ["id", "name", "HP", "turn dmg", "threat"])
	for enemy in StarterContent.enemy_pool():
		print("%-18s %-24s %4d %10.2f %8.2f" % [enemy.id, enemy.display_name, enemy.max_hp, StarterContent._turn_damage(enemy), StarterContent.enemy_threat(enemy)])
	print("")


func _print_legacy(samples: int) -> void:
	print("Legacy line: average pack threat per regular fight number (%d seeds each)" % samples)
	print("%-6s %-6s %-5s %8s %8s %8s" % ["fight", "count", "tier", "mean", "min", "max"])
	for fight in LEGACY_COUNTS.size():
		var total := 0.0
		var lowest := INF
		var highest := 0.0
		for s in samples:
			var rng := RandomNumberGenerator.new()
			rng.seed = 1000 + s
			var threat := StarterContent.pack_threat(StarterContent.varied_encounter(LEGACY_COUNTS[fight], rng, LEGACY_TIERS[fight], fight))
			total += threat
			lowest = minf(lowest, threat)
			highest = maxf(highest, threat)
		print("%-6d %-6d %-5d %8.2f %8.2f %8.2f" % [fight, LEGACY_COUNTS[fight], LEGACY_TIERS[fight], total / samples, lowest, highest])
	print("")


func _print_budget() -> void:
	print("Budget curve (MAP_DIFFICULTY %.2f)" % StarterContent.MAP_DIFFICULTY)
	var line := ""
	for row in RouteMap.ROWS:
		line += "r%d=%.1f  " % [row, StarterContent.fight_budget(row)]
		if row % 5 == 4:
			print(line)
			line = ""
	print("")


func _print_packs(seeds: int) -> void:
	print("Packs from budget_encounter, %d seeds per row and count (hpSc/dmgSc = mean HP and damage factor; hp = enemy max HP range; hit = largest single hit)" % seeds)
	print("%-4s %-5s %7s %7s %7s %7s %8s %7s %6s %6s %7s %7s" % ["row", "count", "budget", "min", "mean", "max", "max|err|", "bound%", "hpSc", "dmgSc", "hp", "hit"])
	var seen := {}
	var worst_error := 0.0
	var bound_total := 0
	var pack_total := 0
	var attempts_total := 0
	var hp_scales: Array[float] = []
	var dmg_scales: Array[float] = []
	for row in RouteMap.ROWS:
		if row == 14 or row == 29:
			continue # boss rows have no budgeted fight
		for count in range(1, 4):
			var target := StarterContent.fight_budget(row)
			var lowest := INF
			var highest := 0.0
			var total := 0.0
			var max_err := 0.0
			var bounds := 0
			var hp_sc := 0.0
			var dmg_sc := 0.0
			var hp_min := 9999
			var hp_max := 0
			var hit_max := 0
			for s in seeds:
				var rng := RandomNumberGenerator.new()
				rng.seed = 7000 + s * 31 + row
				var pack := StarterContent.budget_encounter(count, rng, row)
				var info := StarterContent.last_pack_info
				var threat := StarterContent.pack_threat(pack)
				lowest = minf(lowest, threat)
				highest = maxf(highest, threat)
				total += threat
				max_err = maxf(max_err, absf(threat - target) / target)
				if info["bound_hit"]:
					bounds += 1
				hp_sc += info["hp_scale"]
				dmg_sc += info["damage_scale"]
				hp_scales.append(info["hp_scale"])
				dmg_scales.append(info["damage_scale"])
				attempts_total += info["attempts"]
				for enemy in pack:
					seen[enemy.id] = seen.get(enemy.id, 0) + 1
					hp_min = mini(hp_min, enemy.max_hp)
					hp_max = maxi(hp_max, enemy.max_hp)
					for intent in enemy.intents:
						if intent.kind == CardEffect.Kind.DAMAGE:
							hit_max = maxi(hit_max, intent.amount)
			worst_error = maxf(worst_error, max_err)
			bound_total += bounds
			pack_total += seeds
			print("%-4d %-5d %7.1f %7.1f %7.1f %7.1f %7.1f%% %6.1f%% %6.2f %6.2f %3d-%-3d %7d" % [row, count, target, lowest, total / seeds, highest, 100.0 * max_err, 100.0 * bounds / seeds, hp_sc / seeds, dmg_sc / seeds, hp_min, hp_max, hit_max])
	print("")
	print("Worst relative error anywhere: %.1f%%; packs where a bound was hit: %d of %d (%.2f%%); mean packs drawn per fight %.2f" % [100.0 * worst_error, bound_total, pack_total, 100.0 * bound_total / maxf(pack_total, 1), float(attempts_total) / maxf(pack_total, 1)])
	print("HP factor mean %.3f sd %.3f; damage factor mean %.3f sd %.3f" % [_mean(hp_scales), _sd(hp_scales), _mean(dmg_scales), _sd(dmg_scales)])
	print("Enemies seen: %s" % [seen])


func _mean(values: Array[float]) -> float:
	var total := 0.0
	for v in values:
		total += v
	return total / maxf(values.size(), 1)


func _sd(values: Array[float]) -> float:
	var m := _mean(values)
	var total := 0.0
	for v in values:
		total += (v - m) * (v - m)
	return sqrt(total / maxf(values.size(), 1))
