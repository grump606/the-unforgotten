class_name Chapters
extends RefCounted
## The chapters of a run. Only Chapter 1 exists; chapter(n) is the one place later chapters are added.
## The Chapter 1 values below are the ones that used to live in RouteMap and StarterContent.

const COUNT := 1
const CHAPTER_1_DISTRICT_NAMES: Array[String] = ["The Quiet Streets", "The Dead Country"]
const CHAPTER_1_BUDGET_START: Array[float] = [34.0, 46.0]
const CHAPTER_1_BUDGET_END: Array[float] = [50.0, 62.0]
## The most chapters that can be built (Chapter 1 and the stubs after it).
const MAX_BUILT := 3
## The stub chapters' budget curves, [start per district, end per district], before MAP_DIFFICULTY: the plan's first guess
## (docs/CHAPTER2_PLAN.md, "Difficulty"), to be tuned with the sim.
const STUB_CURVES := {
	2: [[66.0, 74.0], [74.0, 82.0]],
	3: [[84.0, 92.0], [92.0, 100.0]],
}

## 0 means COUNT. Tests and the debug stub set it to reach a chapter that has no content yet.
static var count_override := 0
static var _cache: Dictionary = {}


## How many chapters a run has.
static func count() -> int:
	return count_override if count_override > 0 else COUNT


## Chapter `number` (1-based), clamped to 1..MAX_BUILT. Chapters past COUNT are development stubs (see _build).
static func chapter(number: int = 1) -> ChapterData:
	var n := clampi(number, 1, MAX_BUILT)
	if not _cache.has(n):
		_cache[n] = _build(n)
	return _cache[n]


## Chapter 1 is the shipped content. Chapters 2 and 3 are STUBS until their content exists (docs/CHAPTER2_PLAN.md): they
## reuse Chapter 1's enemies, bosses and names, with their own difficulty curve, so the whole path can be built and sim-tested
## before any new enemy or art exists. They are reachable only through count_override (a development build or a test).
static func _build(n: int) -> ChapterData:
	var c := ChapterData.new()
	c.number = n
	c.title = "Chapter %d" % n
	c.district_names = CHAPTER_1_DISTRICT_NAMES.duplicate()
	var curve: Array = STUB_CURVES.get(n, [CHAPTER_1_BUDGET_START, CHAPTER_1_BUDGET_END])
	c.budget_start.assign(curve[0])
	c.budget_end.assign(curve[1])
	c.mid_boss = &"the_brakeman"
	c.end_boss = &"the_conductor"
	c.mid_boss_path = StarterContent.BRAKEMAN_PATH
	c.end_boss_path = StarterContent.CONDUCTOR_PATH
	c.enemy_paths.assign(StarterContent.ALL_ENEMY_PATHS)
	c.big_paths.assign(StarterContent.PAIR_BIG_ENEMY_PATHS)
	c.small_paths.assign(StarterContent.SMALL_ENEMY_PATHS)
	c.trio_excluded_paths.assign(StarterContent.TRIO_EXCLUDED_PATHS)
	return c
