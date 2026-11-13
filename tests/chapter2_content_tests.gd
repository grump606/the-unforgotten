extends "res://tests/test_base.gd"
## Chapter 2's written content (docs/CHAPTER2_WRITING.md): the five story beats in five versions and the ten events.

const CHARACTERS: Array[StringName] = [&"deserter", &"thief", &"medium", &"stray"]


func run() -> int:
	_failures = 0
	_test_beats()
	_test_events()
	return _failures


func _words(text: String) -> int:
	return text.split(" ", false).size()


func _test_beats() -> void:
	var chapter_beats := StoryContent.paths_for(2)
	_check(chapter_beats.size() == 4, "four map beats in chapter 2")
	var all_titles := {}
	for index in chapter_beats.size():
		var neutral := StoryContent.beat(index, &"", 2)
		_check(neutral != null and neutral.title != "" and neutral.button_text != "", "chapter 2 beat %d loads with a title and a button" % index)
		all_titles[neutral.title] = true
		for character in CHARACTERS:
			var own := StoryContent.beat(index, character, 2)
			_check(own != null and own.text != neutral.text and own.title == neutral.title, "%s has its own version of beat %d" % [character, index])
			_check(_words(own.text) >= 60 and _words(own.text) <= 150, "beat %d for %s is a sane length (%d words)" % [index, character, _words(own.text)])
			_check(not own.text.contains("*") and not own.text.contains(" - "), "no stray markup or dashes: beat %d for %s" % [index, character])
	for chapter in [1, 2]:
		var neutral := StoryContent.break_beat(chapter)
		_check(neutral != null and neutral.title != "", "chapter %d has a closing beat" % chapter)
		for character in CHARACTERS:
			var own := StoryContent.break_beat(chapter, character)
			_check(own != null and own.text != neutral.text, "%s has their own closing beat for chapter %d" % [character, chapter])
	_check(StoryContent.break_beat(4) == null, "no closing beat for a chapter that has none")
	_check(all_titles.size() == 4, "the four map beats have different titles")


func _test_events() -> void:
	var events := StarterContent.events_for(2)
	_check(events.size() == 10, "ten chapter 2 events")
	var ids := {}
	for event in StarterContent.EVENT_PATHS:
		ids[(load(event) as EventData).id] = true
	for event in events:
		_check(not ids.has(event.id), "id is new: %s" % event.id)
		ids[event.id] = true
		_check(event.title != "" and event.body != "" and event.choices.size() >= 3, "%s has a title, text and at least three buttons" % event.id)
		for character in CHARACTERS:
			var shown := event.choices_for(character)
			_check(shown.size() >= 3 and shown.size() <= 4, "%s shows %s three or four buttons" % [event.id, character])
			for choice in shown:
				_check(choice.label != "" and choice.outcome_for(character) != "", "%s / %s: a button has a label and an outcome" % [event.id, character])
				_check(not choice.label.contains("0") and not choice.label.contains("1"), "button labels carry no numbers: %s" % choice.label)
	# That every event has a free button at 0 gold and 1 HP, for every class, is checked over every chapter's events by event_tests.gd.
