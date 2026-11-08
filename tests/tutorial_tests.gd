extends RefCounted
## The tutorial's content and first-launch rules (run/tutorial_content.gd, Settings.tutorial_seen). The drawing
## is checked in ui_tutorial_test.gd. Uses scratch paths only. Returns the failure count.

var _failures := 0
var _path := "user://tutorial_tests_%d.json" % OS.get_process_id()


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAIL: " + label)


func run() -> int:
	_failures = 0
	_test_launch_rule()
	_test_seen_setting()
	_test_content()
	for p in [_path, _path + ".tmp", _path + ".bak"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	return _failures


func _test_launch_rule() -> void:
	_check(TutorialContent.should_show_on_launch("windows", "", false), "a first real launch shows the tutorial")
	_check(not TutorialContent.should_show_on_launch("windows", "", true), "a launch after it was seen does not")
	_check(not TutorialContent.should_show_on_launch("headless", "", false), "headless runs never show it")
	_check(not TutorialContent.should_show_on_launch("windows", "1", false), "the opt-out variable hides it")


func _test_seen_setting() -> void:
	_check(not Settings.new().tutorial_seen, "the tutorial is unseen by default")
	_check(not Settings.load_file(_path).tutorial_seen, "a missing settings file means unseen")
	var settings := Settings.new()
	settings.update_check_enabled = false
	settings.tutorial_seen = true
	_check(settings.save(_path) == "", "settings with the flag save")
	var loaded := Settings.load_file(_path)
	_check(loaded.tutorial_seen and not loaded.update_check_enabled, "the flag round-trips and keeps the other fields")
	_check(not Settings.from_dict({"tutorial_seen": "yes"}).tutorial_seen, "a non-boolean flag is ignored")
	_check(not Settings.from_dict({"tutorial_seen": true}).extras.has("tutorial_seen"), "the flag is not treated as an unknown key")
	_check(not Settings.to_dict(Settings.new()).has("tutorial_seen"), "an unseen tutorial is not written, so old files stay unchanged")


func _test_content() -> void:
	var pages := TutorialContent.pages()
	_check(pages.size() == TutorialContent.page_count() and pages.size() >= 5, "the tutorial has its pages")
	var seen_titles := {}
	for page in pages:
		_check(String(page.title) != "" and not seen_titles.has(page.title), "page %s has its own title" % page.title)
		seen_titles[page.title] = true
		if page.kind == TutorialContent.Kind.TEXT:
			_check(not (page.items as Array).is_empty(), "text page %s has lines" % page.title)
		if page.kind == TutorialContent.Kind.BATTLE:
			for item in page.items:
				var at: Vector2 = item.at
				_check(at.x >= 0 and at.y >= 0 and at.x <= TutorialContent.BATTLE_IMAGE_SIZE.x and at.y <= TutorialContent.BATTLE_IMAGE_SIZE.y, "battle marker %s is inside the picture" % String(item.text).left(20))
				_check(String(item.text) != "", "battle marker has text")
		if page.kind == TutorialContent.Kind.CARD:
			for item in page.items:
				var at: Vector2 = item.at
				_check(at.x >= 0 and at.y >= 0 and at.x <= CardView.BASE.x and at.y <= CardView.BASE.y, "card marker %s is on the card" % String(item.text).left(20))
		if page.kind == TutorialContent.Kind.ICONS:
			for item in page.items:
				_check(String(item.name) != "" and String(item.text) != "", "icon %s has a name and text" % item.name)
	_check(ResourceLoader.exists(TutorialContent.BATTLE_IMAGE), "the fight screen picture is in the project")
	_check(ResourceLoader.exists("res://data/cards/heavy_blow.tres"), "the demo card exists")
	var terms: Array = TutorialContent.keyword_rows().map(func(row): return row[0])
	for keyword in CardGlossary.KEYWORD_TEXT:
		_check(keyword in terms, "the keywords page lists %s" % keyword)
