class_name Chapters
extends RefCounted
## The chapters of a run. Only Chapter 1 exists; chapter(n) is the one place later chapters are added.
## The Chapter 1 values below are the ones that used to live in RouteMap and StarterContent.

const COUNT := 1
const CHAPTER_1_DISTRICT_NAMES: Array[String] = ["The Quiet Streets", "The Dead Country"]
const CHAPTER_1_BUDGET_START: Array[float] = [34.0, 46.0]
const CHAPTER_1_BUDGET_END: Array[float] = [50.0, 62.0]

## 0 means COUNT. Tests and the debug stub set it to reach a chapter that has no content yet.
static var count_override := 0
static var _cache: Dictionary = {}


## How many chapters a run has.
static func count() -> int:
	return count_override if count_override > 0 else COUNT


## Chapter `number` (1-based), or Chapter 1 when it is out of range.
static func chapter(number: int = 1) -> ChapterData:
	var n := clampi(number, 1, COUNT)  # content exists for COUNT chapters only
	if not _cache.has(n):
		_cache[n] = _build(n)
	return _cache[n]


static func _build(n: int) -> ChapterData:
	var c := ChapterData.new()
	c.number = n
	c.title = "Chapter %d" % n
	c.district_names = CHAPTER_1_DISTRICT_NAMES.duplicate()
	c.budget_start = CHAPTER_1_BUDGET_START.duplicate()
	c.budget_end = CHAPTER_1_BUDGET_END.duplicate()
	c.mid_boss = &"the_brakeman"
	c.end_boss = &"the_conductor"
	return c
