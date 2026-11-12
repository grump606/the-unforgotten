class_name ChapterData
extends RefCounted
## One chapter of a run, as data (docs/CHAPTERS_DESIGN.md, section 3). Every chapter has the same shape
## (RouteMap.ACTS districts of RouteMap.ACT_ROWS rows), so the map geometry stays in RouteMap; a chapter
## supplies the names, the difficulty curve and the bosses. Built by Chapters.

var number: int = 1
var title: String = ""
## What the player calls each district, one per act (RouteMap.ACTS entries).
var district_names: Array[String] = []
## Regular-fight budget at the first and the last row of each district, before MAP_DIFFICULTY
## (see StarterContent.fight_budget). One entry per act each.
var budget_start: Array[float] = []
var budget_end: Array[float] = []
## A multiplier on the fight budget per character id, on top of StarterContent.MAP_CLASS_DIFFICULTY (a class that is not
## listed uses 1.0): the four classes do not carry their decks into a later chapter equally well (docs/CHAPTER2_PLAN.md).
var class_difficulty: Dictionary = {}
## Enemy ids of the chapter's two bosses, and their resource paths (what boss fights load).
var mid_boss: StringName = &""
var end_boss: StringName = &""
var mid_boss_path := ""
var end_boss_path := ""
## What the map labels the two boss nodes ("The Bellkeeper") and the reward screen calls the mid-boss when it falls.
var mid_boss_title := ""
var end_boss_title := ""
## The regular enemy pools of the chapter's packs, as resource paths (the same roles as StarterContent's
## ALL_ENEMY_PATHS, PAIR_BIG_ENEMY_PATHS, SMALL_ENEMY_PATHS and TRIO_EXCLUDED_PATHS): a lone enemy comes from
## `enemy_paths`, a pair is a `big_paths` plus a `small_paths` enemy or two small ones, a trio is small ones
## that are not in `trio_excluded_paths`.
var enemy_paths: Array[String] = []
var big_paths: Array[String] = []
var small_paths: Array[String] = []
var trio_excluded_paths: Array[String] = []


## `small_paths` minus `trio_excluded_paths`: the enemies a trio is made of.
func trio_paths() -> Array[String]:
	var paths: Array[String] = []
	for path in small_paths:
		if not trio_excluded_paths.has(path):
			paths.append(path)
	return paths
