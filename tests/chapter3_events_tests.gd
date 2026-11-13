extends "res://tests/test_base.gd"
## Chapter 3's events (docs/CHAPTER3_WRITING.md): ten, each with a free button, printed numbers and class twists.

const CHARACTERS: Array[StringName] = [&"deserter", &"thief", &"medium", &"stray"]


func run() -> int:
	_failures = 0
	_test_events()
	return _failures


func _test_events() -> void:
	var events := StarterContent.events_for(3)
	_check(events.size() == 10, "ten chapter 3 events")
	var ids := {}
	for path in StarterContent.EVENT_PATHS:
		ids[(load(path) as EventData).id] = true
	for event in StarterContent.events_for(2):
		ids[event.id] = true
	for event in events:
		_check(not ids.has(event.id), "id is new: %s" % event.id)
		ids[event.id] = true
		_check(event.title != "" and event.body != "" and event.choices.size() >= 3, "%s has a title, text and at least three buttons" % event.id)
		for character in CHARACTERS:
			var shown := event.choices_for(character)
			_check(shown.size() >= 3 and shown.size() <= 4, "%s shows %s three or four buttons" % [event.id, character])
			var free := 0
			for choice in shown:
				_check(choice.label != "" and choice.outcome_for(character) != "", "%s / %s: a button has a label and an outcome" % [event.id, character])
				_check(not choice.label.contains("0") and not choice.label.contains("1"), "button labels carry no numbers: %s" % choice.label)
				_check(not choice.outcome_for(character).contains("*") and not choice.outcome_for(character).contains(" - "), "no stray markup or dashes: %s" % choice.label)
				if choice.effects.is_empty():
					free += 1
				else:
					_check(choice.summary() != "", "%s: a button with effects prints its numbers" % choice.label)
			_check(free >= 1, "%s has a button that costs nothing for %s" % [event.id, character])

