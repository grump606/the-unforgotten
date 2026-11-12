extends "res://tests/test_base.gd"
## Chapter data (docs/CHAPTERS_DESIGN.md): Chapter 1 carries exactly the values that used to be constants.


func run() -> int:
	_failures = 0
	var c := Chapters.chapter(1)
	_check(c.number == 1 and c.title == "Chapter 1", "chapter 1 is numbered and titled")
	_check(c.district_names.size() == RouteMap.ACTS and c.budget_start.size() == RouteMap.ACTS and c.budget_end.size() == RouteMap.ACTS, "one name and one budget pair per district")
	_check(c.district_names == RouteMap.DISTRICT_NAMES, "the map's district names come from the chapter")
	_check(c.mid_boss == &"the_brakeman" and c.end_boss == &"the_conductor", "chapter 1 bosses are the Bellkeeper and the Eraser")
	_check(Chapters.chapter(0) == c and Chapters.chapter(99) == c, "an out-of-range chapter falls back to chapter 1")
	for row in RouteMap.ROWS:
		_check(is_equal_approx(StarterContent.fight_budget(row), StarterContent.fight_budget(row, 1)), "fight_budget defaults to chapter 1 (row %d)" % row)
	return _failures
