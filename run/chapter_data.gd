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
## Enemy ids of the chapter's two bosses.
var mid_boss: StringName = &""
var end_boss: StringName = &""
