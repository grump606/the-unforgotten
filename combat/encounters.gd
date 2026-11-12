class_name Encounters
extends RefCounted
## Builds enemy encounters (pairs, trios, bosses) and the per-fight stat ramp. StarterContent holds the path
## tables and forwards here.


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
## regular fight's 0-based number, which sets the stat ramp (see StarterContent.RAMP_PER_FIGHT). The defaults give
## the unramped tier 0 encounter; tier and fight draw nothing extra from `rng`.
static func varied_encounter(enemy_count: int, rng: RandomNumberGenerator, tier: int = 0, fight: int = 0) -> Array[EnemyData]:
	var count := clampi(enemy_count, 1, Combat.MAX_ENEMIES)
	var paths: Array[String] = []
	var big_pair_chance := StarterContent.TIER1_BIG_PAIR_CHANCE if tier >= 1 else StarterContent.BIG_PAIR_CHANCE
	match count:
		1:
			paths.append(pick_path(StarterContent.ALL_ENEMY_PATHS, rng))
		2:
			if rng.randf() < big_pair_chance:
				paths.append(pick_path(StarterContent.PAIR_BIG_ENEMY_PATHS, rng))
				paths.append(pick_path(StarterContent.SMALL_ENEMY_PATHS, rng))
			else:
				paths.append(pick_path(StarterContent.SMALL_ENEMY_PATHS, rng))
				paths.append(pick_path(StarterContent.SMALL_ENEMY_PATHS, rng))
		_:
			for i in count:
				paths.append(pick_path(trio_paths(), rng))
	var factor := ramp_factor(fight)
	var enemies: Array[EnemyData] = []
	for path in paths:
		var enemy := ContentRegistry.load_enemy(path)
		if enemy != null:
			enemies.append(scaled(enemy, factor))
	return enemies


## The stat multiplier for the regular fight numbered `fight` (0-based; below 0 counts as 0).
static func ramp_factor(fight: int) -> float:
	return 1.0 + StarterContent.RAMP_PER_FIGHT * maxi(fight, 0)


## `enemy` with max HP and DAMAGE intents scaled by `factor` (rounded, never below 1). Returns a new
## EnemyData with new intents, so the shared resource is never touched; factor 1.0 returns `enemy` itself.
## A `damage_factor` of 0 or more scales the DAMAGE intents by that instead (the pack builder splits HP and damage).
static func scaled(enemy: EnemyData, factor: float, damage_factor: float = -1.0) -> EnemyData:
	var damage_scale := factor if damage_factor < 0.0 else damage_factor
	if is_equal_approx(factor, 1.0) and is_equal_approx(damage_scale, 1.0):
		return enemy
	var scaled_enemy := EnemyData.make(enemy.display_name, maxi(roundi(enemy.max_hp * factor), 1), _scaled_intents(enemy.intents, damage_scale), enemy.id, enemy.max_haunt)
	# The second phase (its intents, threshold and banner) comes along; its attacks ramp like the first phase's.
	scaled_enemy.phase_two_intents = _scaled_intents(enemy.phase_two_intents, damage_scale)
	scaled_enemy.phase_two_hp_percent = enemy.phase_two_hp_percent
	scaled_enemy.phase_two_title = enemy.phase_two_title
	scaled_enemy.unseen = enemy.unseen
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
static func boss_encounter(chapter: int = 1) -> Array[EnemyData]:
	var enemies: Array[EnemyData] = []
	var boss := ContentRegistry.load_enemy(Chapters.chapter(chapter).end_boss_path)
	if boss != null:
		enemies.append(boss)
	return enemies


## The mid-run boss fight: the Brakeman alone. Empty (cause logged) if it fails to load.
static func mid_boss_encounter(chapter: int = 1) -> Array[EnemyData]:
	var enemies: Array[EnemyData] = []
	var boss := ContentRegistry.load_enemy(Chapters.chapter(chapter).mid_boss_path)
	if boss != null:
		enemies.append(boss)
	return enemies


static func pick_path(paths: Array[String], rng: RandomNumberGenerator) -> String:
	return paths[rng.randi_range(0, paths.size() - 1)]
