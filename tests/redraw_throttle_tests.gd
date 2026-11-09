extends "res://tests/test_base.gd"
## The redraw throttle keeps an even rate on a 60 Hz display: two frames a hair under 16.67 ms must still reach the
## 33.3 ms boundary, or the repaints alternate between 30 and 20 Hz.


func _count(delta: float, frames: int, hz := RedrawThrottle.HZ) -> int:
	var throttle := RedrawThrottle.new()
	var fired := 0
	for i in frames:
		if throttle.due(delta, hz):
			fired += 1
	return fired


func _longest_gap(delta: float, frames: int) -> int:
	var throttle := RedrawThrottle.new()
	var gap := 0
	var longest := 0
	for i in frames:
		gap += 1
		if throttle.due(delta):
			longest = maxi(longest, gap)
			gap = 0
	return longest


func run() -> int:
	_failures = 0
	# Frames slightly under 1/60 s (a display that runs 59.99 Hz, or a frame timer that rounds down).
	var under := 0.016665
	_check(absi(_count(under, 600) - 300) <= 1, "60 Hz frames just under 16.67 ms repaint about 300 times in 600 frames (got %d)" % _count(under, 600))
	_check(_longest_gap(under, 100) == 2, "the first 100 such frames repaint every second frame, no gap of three (longest %d)" % _longest_gap(under, 100))
	var first := RedrawThrottle.new()
	var frames_to_first := 0
	while frames_to_first < 10:
		frames_to_first += 1
		if first.due(under):
			break
	_check(frames_to_first == 2, "the first repaint comes on the second frame (frame %d)" % frames_to_first)
	_check(_count(1.0 / 60.0, 600) == 300, "exact 60 Hz frames repaint 300 times in 600 frames")
	_check(absi(_count(1.0 / 144.0, 1440) - 300) <= 2, "144 Hz still averages 30 repaints per second")
	_check(_count(0.05, 20) == 20, "frames longer than the interval repaint every time")
	var slow := RedrawThrottle.new()
	_check(not slow.due(0.010) and not slow.due(0.010), "well under the interval it does not fire")
	return _failures
