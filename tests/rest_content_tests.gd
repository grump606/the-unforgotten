extends RefCounted
## Rules-level checks for the rest stop's story card (run/rest_content.gd).

var failures := 0


func _check(condition: bool, message: String) -> void:
	if condition:
		print("ok: ", message)
	else:
		failures += 1
		print("FAIL: ", message)


func run() -> int:
	_check(RestContent.beat_count() == 4, "there is one card per rest on the line")
	var rests := 0
	for stop in RunState.new(1).stops:
		if stop.type == RunState.StopType.REST:
			rests += 1
	_check(rests == RestContent.beat_count(), "the line has as many rests as there are cards")
	var texts := {}
	for number in range(1, RestContent.beat_count() + 1):
		var shared := RestContent.beat(number)
		_check(shared.title != "" and shared.text != "" and shared.button_text == RestContent.BUTTON, "rest %d has a title, text and the button" % number)
		texts[shared.text] = true
		for id in [&"deserter", &"thief", &"medium"]:
			var own := RestContent.beat(number, id)
			_check(own.text.begins_with(shared.text) and own.text.length() > shared.text.length(), "rest %d adds a line for %s" % [number, id])
		_check(RestContent.beat(number, &"nobody").text == shared.text, "rest %d uses the shared passage for an unknown character" % number)
	_check(texts.size() == RestContent.beat_count(), "every rest reads differently")
	_check(RestContent.beat(0).title == RestContent.beat(1).title and RestContent.beat(9).title == RestContent.beat(4).title, "out-of-range rest numbers use the nearest card")
	return failures
