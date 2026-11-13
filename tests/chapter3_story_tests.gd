extends "res://tests/test_base.gd"
## Chapter 3's story texts (docs/CHAPTER3_WRITING.md): four map beats, the closing beat and the finale's two texts, each in five versions.

const CHARACTERS: Array[StringName] = [&"deserter", &"thief", &"medium", &"stray"]


func run() -> int:
	_failures = 0
	_test_map_beats()
	_test_break_and_finale()
	return _failures


func _words(text: String) -> int:
	return text.split(" ", false).size()


func _check_version(beat: StoryBeat, neutral: StoryBeat, label: String) -> void:
	_check(beat != null and beat.title != "" and beat.button_text != "", "%s loads with a title and a button" % label)
	if beat == null:
		return
	if neutral != null and beat != neutral:
		_check(beat.text != neutral.text and beat.title == neutral.title, "%s differs from the neutral text and keeps its title" % label)
	_check(_words(beat.text) >= 60 and _words(beat.text) <= 150, "%s is a sane length (%d words)" % [label, _words(beat.text)])
	_check(not beat.text.contains("*") and not beat.text.contains(" - ") and not beat.text.contains("—"), "%s has no stray markup or dashes" % label)


func _test_map_beats() -> void:
	_check(StoryContent.beat_count(3) == 4, "four map beats in chapter 3")
	var titles := {}
	for index in StoryContent.beat_count(3):
		var neutral := StoryContent.beat(index, &"", 3)
		_check_version(neutral, null, "chapter 3 beat %d" % index)
		if neutral != null:
			titles[neutral.title] = true
		for character in CHARACTERS:
			_check_version(StoryContent.beat(index, character, 3), neutral, "chapter 3 beat %d for %s" % [index, character])
	_check(titles.size() == 4, "the four chapter 3 map beats have different titles")


func _test_break_and_finale() -> void:
	var neutral := StoryContent.break_beat(3)
	_check_version(neutral, null, "chapter 3 closing beat")
	for character in CHARACTERS:
		_check_version(StoryContent.break_beat(3, character), neutral, "chapter 3 closing beat for %s" % character)
	for which in ["before", "after"]:
		var base := StoryContent.finale_beat(3, which)
		_check_version(base, null, "finale %s" % which)
		for character in CHARACTERS:
			_check_version(StoryContent.finale_beat(3, which, character), base, "finale %s for %s" % [which, character])
	_check(StoryContent.finale_beat(2, "before") == null and StoryContent.finale_beat(3, "middle") == null, "a chapter or text that does not exist is null")
