class_name Encounters
extends RefCounted
## Builds enemy encounters (pairs, trios, bosses), the per-fight stat ramp, and the map mode's threat measure
## and budgeted pack builder. StarterContent holds the content (the enemy path tables); this class holds how
## encounters are put together from it, so the dependency runs one way: Encounters -> StarterContent.

## Chance that a two-enemy encounter is a big plus a small enemy rather than two small ones.
const BIG_PAIR_CHANCE := 0.15
## Stat ramp: a regular fight's enemies get max HP and attack damage multiplied by
## 1 + RAMP_PER_FIGHT * fight, where `fight` is the 0-based number of the regular fight on the line
## (bosses are hand-tuned and never ramped). Block and statuses are not scaled.
const RAMP_PER_FIGHT := 0.012
## Tier 1 (after the mid-boss) leans on the bigger enemies: a bigger chance of a big-plus-small pair
## (the stop line has no single-enemy fight after the mid-boss, so singles use one pool at every tier).
const TIER1_BIG_PAIR_CHANCE := 0.2


## An early-run encounter with `enemy_count` enemies (clamped to 1..MAX_ENEMIES).
## Enemies whose resource fails to load are left out (the cause is logged), so
## the result can be empty; Combat requires at least one enemy.
static func early_encounter(enemy_count: int) -> Array[EnemyData]:
	var count := clampi(enemy_count, 1, Combat.MAX_ENEMIES)
	var enemies: Array[EnemyData] = []
	for i in count:
		var enemy := StarterContent.warden() if count == 1 else StarterContent.lost_shade()
		if enemy != null:
			enemies.append(enemy)
	return enemies


## All enemy types in a fixed order: warden, lost shade, wisp, colossus, whisperer, cinder hound, mourning crow.
## Enemies that fail to load are left out (the cause is logged).
static func enemy_pool() -> Array[EnemyData]:
	var pool: Array[EnemyData] = []
	for path in StarterContent.ALL_ENEMY_PATHS:
		var enemy := ContentRegistry.load_enemy(path)
		if enemy != null:
			pool.append(enemy)
	return pool


## An encounter of `enemy_count` (clamped to 1..MAX_ENEMIES) enemies, chosen
## with `rng` so a seeded rng reproduces it. Composition keeps danger roughly
## level as the count grows: a lone enemy can be any type, a pair is either the
## warden plus a small enemy or two small ones, and a trio is all small enemies.
## Enemies whose resource fails to load are left out (the cause is logged), so
## the result can be smaller than requested or empty.
##
## `tier` (0 = before the mid-boss, 1 = after) picks the pools (see TIER1_*), and `fight` is the
## regular fight's 0-based number, which sets the stat ramp (see RAMP_PER_FIGHT). The defaults give
## the unramped tier 0 encounter; tier and fight draw nothing extra from `rng`.
static func varied_encounter(enemy_count: int, rng: RandomNumberGenerator, tier: int = 0, fight: int = 0) -> Array[EnemyData]:
	var count := clampi(enemy_count, 1, Combat.MAX_ENEMIES)
	var big_pair_chance := TIER1_BIG_PAIR_CHANCE if tier >= 1 else BIG_PAIR_CHANCE
	var paths := pack_paths(count, rng, big_pair_chance, StarterContent.ALL_ENEMY_PATHS, StarterContent.PAIR_BIG_ENEMY_PATHS, StarterContent.SMALL_ENEMY_PATHS, trio_paths())
	var factor := ramp_factor(fight)
	var enemies: Array[EnemyData] = []
	for path in paths:
		var enemy := ContentRegistry.load_enemy(path)
		if enemy != null:
			enemies.append(scaled(enemy, factor))
	return enemies


## The stat multiplier for the regular fight numbered `fight` (0-based; below 0 counts as 0).
static func ramp_factor(fight: int) -> float:
	return 1.0 + RAMP_PER_FIGHT * maxi(fight, 0)


## `enemy` with max HP and DAMAGE intents scaled by `factor` (rounded, never below 1). Returns a new
## EnemyData with new intents, so the shared resource is never touched; factor 1.0 returns `enemy` itself.
## A `damage_factor` of 0 or more scales the DAMAGE intents by that instead (the pack builder splits HP and damage).
static func scaled(enemy: EnemyData, factor: float, damage_factor: float = -1.0) -> EnemyData:
	var damage_scale := factor if damage_factor < 0.0 else damage_factor
	if is_equal_approx(factor, 1.0) and is_equal_approx(damage_scale, 1.0):
		return enemy
	# A copy keeps every field (a new @export comes along by itself); only HP and the intents of each phase change,
	# and later phases' attacks ramp like the first phase's.
	var scaled_enemy := enemy.duplicate() as EnemyData
	scaled_enemy.max_hp = maxi(roundi(enemy.max_hp * factor), 1)
	scaled_enemy.intents = _scaled_intents(enemy.intents, damage_scale)
	scaled_enemy.phase_two_intents = _scaled_intents(enemy.phase_two_intents, damage_scale)
	scaled_enemy.phase_three_intents = _scaled_intents(enemy.phase_three_intents, damage_scale)
	return scaled_enemy


static func _scaled_intents(source: Array[CardEffect], factor: float) -> Array[CardEffect]:
	var intents: Array[CardEffect] = []
	for intent in source:
		if intent.kind == CardEffect.Kind.DAMAGE:
			intents.append(CardEffect.make(intent.kind, maxi(roundi(intent.amount * factor), 1), intent.bonus, intent.threshold, intent.hits))
		else:
			intents.append(intent)
	return intents


## StarterContent.SMALL_ENEMY_PATHS minus StarterContent.TRIO_EXCLUDED_PATHS, so a new small enemy joins trios by default.
## Built once (the path tables are constants); each call returns a copy, so a caller cannot change the cache.
static var _trio_cache: Array[String] = []


static func trio_paths() -> Array[String]:
	if _trio_cache.is_empty():
		for path in StarterContent.SMALL_ENEMY_PATHS:
			if not StarterContent.TRIO_EXCLUDED_PATHS.has(path):
				_trio_cache.append(path)
	return _trio_cache.duplicate()


## The chapter's end boss fight (Chapter 1: the Conductor) alone. Empty (cause logged) if it fails to load,
## and Combat needs at least one enemy, so callers must check.
static func boss_encounter(chapter: int = 1, character_id: StringName = &"") -> Array[EnemyData]:
	var enemies: Array[EnemyData] = []
	var boss := ContentRegistry.load_enemy(Chapters.chapter(chapter).end_boss_path)
	if boss != null:
		enemies.append(_for_class(boss, chapter, character_id))
	return enemies


## The mid-run boss fight: the Brakeman alone. Empty (cause logged) if it fails to load.
static func mid_boss_encounter(chapter: int = 1, character_id: StringName = &"") -> Array[EnemyData]:
	var enemies: Array[EnemyData] = []
	var boss := ContentRegistry.load_enemy(Chapters.chapter(chapter).mid_boss_path)
	if boss != null:
		enemies.append(_for_class(boss, chapter, character_id))
	return enemies


## The finale: the final boss alone, scaled for the class like the other bosses of its chapter.
static func finale_encounter(chapter: int = 3, character_id: StringName = &"") -> Array[EnemyData]:
	var enemies: Array[EnemyData] = []
	var path := Chapters.chapter(chapter).finale_boss_path
	if path == "":
		return enemies
	var boss := ContentRegistry.load_enemy(path)
	if boss != null:
		enemies.append(_for_class(boss, chapter, character_id))
	return enemies


## A boss of chapter 2 or later for `character_id`: HP and attacks each scaled by the square root of the chapter's class factor
## (ChapterData.boss_class_factor), so the boss's threat follows the factor the way a pack's budget does. Chapter 1's bosses are never
## scaled (their numbers are shipped), and neither is a boss for no class or a class without a factor.
static func _for_class(boss: EnemyData, chapter: int, character_id: StringName) -> EnemyData:
	if chapter < 2 or character_id == &"":
		return boss
	var factor := float(Chapters.chapter(chapter).boss_class_factor.get(character_id, 1.0))
	return scaled(boss, sqrt(factor), sqrt(factor)) if not is_equal_approx(factor, 1.0) else boss


## The enemy paths of a pack of `count`, drawn from the given pools: a single from `any_paths`; a pair that is
## a `big_paths` plus a `small_paths` enemy with chance `big_pair_chance` (one randf) or else two small ones;
## a trio (or any larger count) from `trio`. This is the one place the draw order lives: varied_encounter and
## StarterContent's budget pack builder both call it, so a seed gives the same paths in either.
static func pack_paths(count: int, rng: RandomNumberGenerator, big_pair_chance: float, any_paths: Array[String], big_paths: Array[String], small_paths: Array[String], trio: Array[String]) -> Array[String]:
	var paths: Array[String] = []
	match count:
		1:
			paths.append(pick_path(any_paths, rng))
		2:
			if rng.randf() < big_pair_chance:
				paths.append(pick_path(big_paths, rng))
				paths.append(pick_path(small_paths, rng))
			else:
				paths.append(pick_path(small_paths, rng))
				paths.append(pick_path(small_paths, rng))
		_:
			for i in count:
				paths.append(pick_path(trio, rng))
	return paths


static func pick_path(paths: Array[String], rng: RandomNumberGenerator) -> String:
	return paths[rng.randi_range(0, paths.size() - 1)]


# ---- Threat measure and map-mode budget (docs/MAP_DESIGN.md, "Phase 4d") ----

## Threat measure: the player's reference damage output per turn. An enemy that lives HP / THREAT_REF_DPS turns
## and deals D per turn costs about D * HP / THREAT_REF_DPS of the player's HP, so threat reads as "HP lost to
## this enemy alone" for a typical hand.
const THREAT_REF_DPS := 10.0
## Damage-equivalent points one unit of `amount` of a non-damage enemy intent adds to the intent cycle
## (EXPOSE, SHAKEN and FRAYED amounts are turns, MALICE stacks, ADD_CARD cards). Kinds missing here (Block, Draw and
## the rest) add nothing: the regular enemies only use the five below, and a boss is never budgeted.
const THREAT_STATUS_POINTS := {
	CardEffect.Kind.EXPOSE: 5.0,
	CardEffect.Kind.SHAKEN: 2.0,
	CardEffect.Kind.FRAYED: 2.0,
	CardEffect.Kind.MALICE: 3.0,
	CardEffect.Kind.ADD_CARD: 3.0,
	CardEffect.Kind.FILE: 3.0,
	CardEffect.Kind.CROSS_OUT: 6.0,
}
## Map mode budget curve. A regular fight on run row `row` (0 to RouteMap.ROWS - 1) gets a total pack threat of
## MAP_DIFFICULTY * lerp(start, end, local), where `local` runs 0 to 1 over the act's rows 0 to 14. Index 0 is
## act 1 (rows 0 to 14), index 1 act 2 (rows 15 to 29), so the curve rises smoothly inside an act and jumps at
## the act change like the line's second-act pools. The numbers are a straight-line fit of the line's average pack
## threat per regular fight number (fights 0 to 3 are act 1, 4 to 7 act 2; measured by tools/threat_table.gd).
## MAP_DIFFICULTY is the one knob for the overall difficulty of map fights.
const BUDGET_ACT_START: Array[float] = Chapters.CHAPTER_1_BUDGET_START
const BUDGET_ACT_END: Array[float] = Chapters.CHAPTER_1_BUDGET_END
const MAP_DIFFICULTY := 1.9
## Map mode only: each character's own multiplier on the budget (on top of MAP_DIFFICULTY), because the four
## characters are not equally robust (Stray has the fewest HP). A character that is not listed uses 1.0.
const MAP_CLASS_DIFFICULTY := {CharacterIds.DESERTER: 1.03, CharacterIds.THIEF: 1.04, CharacterIds.MEDIUM: 1.02, CharacterIds.STRAY: 0.9}
## The pack builder multiplies every enemy of a pack by the same HP factor and the same damage factor; each of the
## two stays inside these bounds.
const PACK_SCALE_MIN := 0.6
const PACK_SCALE_MAX := 1.8
## How the builder splits a pack's total multiplier m (HP factor * damage factor, which is what threat follows)
## between HP and damage, by enemy count (index 0 = a single): HP factor = m^share, damage factor = m^(1 - share).
## A lone enemy takes most of it as HP, so a wisp pushed up to a pair's danger gets longer lived and not a
## hit of 28; a trio splits evenly.
const PACK_HP_SHARE: Array[float] = [0.65, 0.55, 0.5]
## How many packs the builder draws (re-picking when a pack cannot meet the budget inside the bounds) before it
## settles for the closest legal one.
const PACK_MAX_ATTEMPTS := 24
## An elite fight has at least this many enemies.
const ELITE_MIN_ENEMIES := 2
## The prefix of an elite enemy's display name ("Elite Gate Warden"); the id, and so the art, stay the same.
const ELITE_NAME_PREFIX := "Elite "


## One enemy's threat: its average damage per turn over its intent cycle (damage intents count amount * hits,
## the statuses in THREAT_STATUS_POINTS their points) times its max HP over THREAT_REF_DPS. Deterministic; a
## second phase is ignored (only bosses have one and they are never budgeted). 0 for an enemy with no intents.
static func enemy_threat(enemy: EnemyData) -> float:
	return _turn_damage(enemy) * float(enemy.max_hp) / THREAT_REF_DPS


## Average damage-equivalent per turn over the enemy's intent cycle.
static func _turn_damage(enemy: EnemyData) -> float:
	if enemy.intents.is_empty():
		return 0.0
	var total := 0.0
	for intent in enemy.intents:
		if intent.kind == CardEffect.Kind.DAMAGE:
			total += float(intent.amount * maxi(intent.hits, 1))
		else:
			total += float(THREAT_STATUS_POINTS.get(intent.kind, 0.0)) * float(intent.amount)
	return total / float(enemy.intents.size())


## A pack's threat: the damage the player takes while killing it one enemy at a time, in the best order (most
## damage per HP first). Each enemy deals its per-turn damage until it dies, so the sum is
## damage_i * (HP of everything killed up to and including i) / THREAT_REF_DPS. One enemy gives its
## enemy_threat; a pair or trio is worth more than the sum of its members because the survivors keep hitting.
static func pack_threat(enemies: Array[EnemyData]) -> float:
	var order: Array[EnemyData] = enemies.duplicate()
	order.sort_custom(func(a: EnemyData, b: EnemyData) -> bool:
		return _turn_damage(a) * float(b.max_hp) > _turn_damage(b) * float(a.max_hp))
	var hp_so_far := 0.0
	var total := 0.0
	for enemy in order:
		hp_so_far += float(enemy.max_hp)
		total += _turn_damage(enemy) * hp_so_far
	return total / THREAT_REF_DPS


## The budget (target pack threat) of a regular fight on row `row` of chapter `chapter` (row clamped to 0..29): see
## ChapterData.budget_start. BUDGET_ACT_START and BUDGET_ACT_END are Chapter 1's curve.
static func fight_budget(row: int, chapter: int = 1) -> float:
	var data := Chapters.chapter(chapter)
	var r := clampi(row, 0, RouteMap.ROWS - 1)
	# An act past the end of the curve arrays reuses the last entry rather than indexing out of range.
	var act := mini(r / RouteMap.ACT_ROWS, mini(data.budget_start.size(), data.budget_end.size()) - 1)
	var local := float(r % RouteMap.ACT_ROWS) / float(RouteMap.ACT_ROWS - 1)
	return MAP_DIFFICULTY * lerpf(data.budget_start[act], data.budget_end[act], local)


## The map-mode budget multiplier of character `character_id` (see MAP_CLASS_DIFFICULTY).
static func map_class_difficulty(character_id: StringName, chapter: int = 1) -> float:
	return float(MAP_CLASS_DIFFICULTY.get(character_id, 1.0)) * float(Chapters.chapter(chapter).class_difficulty.get(character_id, 1.0))


## How a budgeted pack was built (budget_pack), for the measuring tool and tests.
class PackInfo extends RefCounted:
	## The total multiplier m, and its HP and damage parts (m^share and m^(1 - share)).
	var scale := 1.0
	var hp_scale := 1.0
	var damage_scale := 1.0
	## The budget aimed at, and the built pack's threat.
	var target := 0.0
	var threat := 0.0
	## Even the closest legal pack missed the budget because of the scale bounds.
	var bound_hit := false
	## Packs drawn.
	var attempts := 0
	## Every pool enemy failed to load and the pack was built from a known enemy.
	var fallback := false


## A budgeted pack's enemies and how they were built.
class BudgetPack extends RefCounted:
	var enemies: Array[EnemyData] = []
	var info := PackInfo.new()


## A multiplier fitted by _fit_scale: the total multiplier and whether the bounds stopped it reaching the target.
class Fit extends RefCounted:
	var scale := 1.0
	var bound_hit := false

	func _init(p_scale: float, p_bound_hit: bool) -> void:
		scale = p_scale
		bound_hit = p_bound_hit


## A pack of `count` enemies (1 to MAX_ENEMIES; an `elite` fight has at least ELITE_MIN_ENEMIES) for a map fight
## on run row `row`, whose total pack_threat equals fight_budget(row) * budget_multiplier within rounding. The
## enemies come from the same pools as varied_encounter (a single from any regular enemy, a pair a big plus a
## small or two small ones, a trio small enemies without the excluded ones; the act picks the big-pair
## chance) and are then scaled together: one HP factor and one damage factor for every enemy (max HP and DAMAGE
## intents; see PACK_HP_SHARE), found by bisection on the real rounded numbers. A factor outside
## PACK_SCALE_MIN..PACK_SCALE_MAX is never used: when the bounds stop a pack reaching the budget a new one is
## drawn from `rng` (up to PACK_MAX_ATTEMPTS); if none fits, the legal pack closest to the budget is used. Only `rng` is consumed, so the same seed, row and count give the same pack.
## Shared resources are never changed (enemies are copies and scaled() makes new ones). Enemies that fail to load
## are left out (cause logged); if none of a pack loads it falls back to a known enemy, so the pack is never empty.
static func budget_encounter(count: int, rng: RandomNumberGenerator, row: int, budget_multiplier: float = 1.0, elite: bool = false, chapter: int = 1) -> Array[EnemyData]:
	return budget_pack(count, rng, row, budget_multiplier, elite, chapter).enemies


## budget_encounter with how the pack was built (PackInfo): the same enemies from the same `rng` draws.
static func budget_pack(count: int, rng: RandomNumberGenerator, row: int, budget_multiplier: float = 1.0, elite: bool = false, chapter: int = 1) -> BudgetPack:
	var n := clampi(count, ELITE_MIN_ENEMIES if elite else 1, Combat.MAX_ENEMIES)
	var target := fight_budget(row, chapter) * budget_multiplier
	var big_pair_chance := TIER1_BIG_PAIR_CHANCE if row >= RouteMap.ACT_ROWS else BIG_PAIR_CHANCE
	var best: Array[EnemyData] = []
	var best_miss := INF
	var best_info := PackInfo.new()
	for attempt in PACK_MAX_ATTEMPTS:
		var base: Array[EnemyData] = []
		for path in _pack_paths(n, rng, big_pair_chance, chapter):
			var enemy := _budget_enemy(path)
			if enemy != null:
				base.append(enemy)
		if base.is_empty():
			continue
		var fit := _fit_scale(base, target, chapter)
		var pack := _scaled_pack(base, fit.scale)
		var threat := pack_threat(pack)
		var miss := absf(threat - target) / maxf(target, 0.001)
		if miss < best_miss:
			best = pack
			best_miss = miss
			best_info = _pack_info(base.size(), fit, target, threat, attempt + 1, false)
		if not fit.bound_hit:
			break
	if best.is_empty():
		# Every attempt lost all its enemies to load failures. A map fight is never zero enemies: log it and build
		# the pack from the first enemy that still loads (or a minimal stand-in).
		Combat.engine_error("Encounters.budget_encounter: no pool enemy loaded, falling back to a known enemy")
		var stand_in := _fallback_enemy()
		var base: Array[EnemyData] = []
		for i in n:
			base.append(stand_in.duplicate(true) as EnemyData)
		var fit := _fit_scale(base, target, chapter)
		best = _scaled_pack(base, fit.scale)
		best_info = _pack_info(n, fit, target, pack_threat(best), PACK_MAX_ATTEMPTS, true)
	if elite:
		for i in best.size():
			best[i] = elite_named(best[i])
	var result := BudgetPack.new()
	result.enemies = best
	result.info = best_info
	return result


## A copy of `enemy` whose display name has ELITE_NAME_PREFIX in front (same id, stats, intents and second phase). A new
## EnemyData, so the shared resource is never touched; an already-elite name is left alone.
static func elite_named(enemy: EnemyData) -> EnemyData:
	if enemy.display_name.begins_with(ELITE_NAME_PREFIX):
		return enemy
	# A whole copy, so every field (a new @export too) comes along; only the name changes.
	var named := enemy.duplicate() as EnemyData
	named.intents = enemy.intents.duplicate()
	named.display_name = ELITE_NAME_PREFIX + enemy.display_name
	return named


## The PackInfo of a pack of `count` built with `fit`.
static func _pack_info(count: int, fit: Fit, target: float, threat: float, attempts: int, fallback: bool) -> PackInfo:
	var share := _hp_share(count)
	var info := PackInfo.new()
	info.scale = fit.scale
	info.hp_scale = pow(fit.scale, share)
	info.damage_scale = pow(fit.scale, 1.0 - share)
	info.target = target
	info.threat = threat
	info.bound_hit = fit.bound_hit
	info.attempts = attempts
	info.fallback = fallback
	return info


## The pack builder's enemy at `path`: ContentRegistry.load_enemy, or the test hook TestHooks.budget_enemy_loader when that
## is set (so a load failure can be provoked).
static func _budget_enemy(path: String) -> EnemyData:
	if TestHooks.budget_enemy_loader.is_valid():
		return TestHooks.budget_enemy_loader.call(path) as EnemyData
	return ContentRegistry.load_enemy(path)


## The pack builder's last resort (see _fallback_enemy): the first of these paths that loads, else a hand-built
## stand-in with these numbers.
const FALLBACK_ENEMY_PATHS: Array[String] = [StarterContent.LOST_SHADE_PATH, StarterContent.WARDEN_PATH, StarterContent.WISP_PATH]
const FALLBACK_ENEMY_NAME := "Lost Shade"
const FALLBACK_ENEMY_ID := &"lost_shade"
const FALLBACK_ENEMY_HP := 24
const FALLBACK_ENEMY_DAMAGE := 6


## A known loadable enemy for the pack builder's last resort, or a minimal hand-built one when none loads.
static func _fallback_enemy() -> EnemyData:
	for path in FALLBACK_ENEMY_PATHS:
		var enemy := _budget_enemy(path)
		if enemy != null and not enemy.intents.is_empty():
			return enemy
	var intents: Array[CardEffect] = [CardEffect.make(CardEffect.Kind.DAMAGE, FALLBACK_ENEMY_DAMAGE)]
	return EnemyData.make(FALLBACK_ENEMY_NAME, FALLBACK_ENEMY_HP, intents, FALLBACK_ENEMY_ID)


## The enemy paths of a pack of `count`, drawn from the pools in the order varied_encounter draws them.
static func _pack_paths(count: int, rng: RandomNumberGenerator, big_pair_chance: float, chapter: int = 1) -> Array[String]:
	var pools := Chapters.chapter(chapter)
	return pack_paths(count, rng, big_pair_chance, pools.enemy_paths, pools.big_paths, pools.small_paths, pools.trio_paths())


## The HP share of the total multiplier for a pack of `count` (see PACK_HP_SHARE).
static func _hp_share(count: int) -> float:
	return PACK_HP_SHARE[clampi(count, 1, PACK_HP_SHARE.size()) - 1]


## The legal range of the total multiplier m for a pack of `count`: the HP factor m^share and the damage factor
## m^(1 - share) must both lie in PACK_SCALE_MIN..PACK_SCALE_MAX. Returns [m_min, m_max].
static func pack_multiplier_bounds(count: int, chapter: int = 1) -> Array[float]:
	var share := _hp_share(count)
	var scale_max := maxf(PACK_SCALE_MAX, Chapters.chapter(chapter).pack_scale_max)
	var low := maxf(pow(PACK_SCALE_MIN, 1.0 / share), pow(PACK_SCALE_MIN, 1.0 / (1.0 - share)))
	var high := minf(pow(scale_max, 1.0 / share), pow(scale_max, 1.0 / (1.0 - share)))
	return [low, high]


## The total multiplier m, inside pack_multiplier_bounds, that brings the scaled `base` pack's threat closest to
## `target` (threat rises with m, so bisect), and whether the bounds stopped it reaching the target.
static func _fit_scale(base: Array[EnemyData], target: float, chapter: int = 1) -> Fit:
	var bounds := pack_multiplier_bounds(base.size(), chapter)
	var low_threat := pack_threat(_scaled_pack(base, bounds[0]))
	if low_threat >= target:
		return Fit.new(bounds[0], low_threat > target * 1.02)
	var high_threat := pack_threat(_scaled_pack(base, bounds[1]))
	if high_threat <= target:
		return Fit.new(bounds[1], high_threat < target * 0.98)
	var lo: float = bounds[0]
	var hi: float = bounds[1]
	for i in 30:
		var mid := (lo + hi) * 0.5
		if pack_threat(_scaled_pack(base, mid)) < target:
			lo = mid
		else:
			hi = mid
	var lo_miss := target - pack_threat(_scaled_pack(base, lo))
	var hi_miss := pack_threat(_scaled_pack(base, hi)) - target
	return Fit.new(lo if lo_miss <= hi_miss else hi, false)


## `base` with every enemy scaled for the total multiplier `m`: HP by m^share, damage by m^(1 - share).
static func _scaled_pack(base: Array[EnemyData], m: float) -> Array[EnemyData]:
	var share := _hp_share(base.size())
	var pack: Array[EnemyData] = []
	for enemy in base:
		pack.append(scaled(enemy, pow(m, share), pow(m, 1.0 - share)))
	return pack
