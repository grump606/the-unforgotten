extends "res://tests/test_base.gd"
## PaintedArt: background decoding gives the same texture as a direct load, a missing file stays a cached null,
## and entries not used for two stops are evicted while recently used ones stay.


func run() -> int:
	_failures = 0
	PaintedArt._cache.clear()
	PaintedArt._last_used.clear()
	PaintedArt._pending.clear()
	PaintedArt._stop_serial = 0
	PaintedArt.warm_screen_async(&"vendor")
	_check(PaintedArt.has_pending() or PaintedArt._cache.has(PaintedArt.SCREEN_DIR % &"vendor"), "a warm-up is queued or already done")
	var tex := PaintedArt.screen_texture(&"vendor")
	_check(tex != null, "asking for a warming texture gives it at once without blocking on the worker")
	var direct := PaintedArt._store("test:direct", PaintedArt._decode(PaintedArt.SCREEN_DIR % &"vendor"))
	_check(direct != null and direct.get_size() == tex.get_size(), "the threaded decode matches a direct decode")
	PaintedArt.warm_screen_async(&"nope")
	_check(not PaintedArt._pending.has(PaintedArt.SCREEN_DIR % &"nope") and PaintedArt.screen_texture(&"nope") == null, "a missing file is not queued and loads as null")
	PaintedArt.warm_for_stop(RunState.StopType.STORY, &"deserter", 0)
	_check(PaintedArt.has_pending() or PaintedArt._cache.has(PaintedArt.SCREEN_DIR % StoryScene.key_for_beat(0)), "a story stop warms its own beat's painting")
	_check(PaintedArt.poll() >= 0, "poll returns the number still decoding")
	PaintedArt._pending.clear() # workers still running are ignored by this test (the game drains them in poll)
	# Eviction: vendor is used again each stop, rest is not.
	PaintedArt.screen_texture(&"rest")
	PaintedArt.advance_stop()
	PaintedArt.screen_texture(&"vendor")
	_check(PaintedArt._cache.has(PaintedArt.SCREEN_DIR % &"rest"), "an entry unused for one stop stays")
	var dropped := PaintedArt.advance_stop()
	PaintedArt.screen_texture(&"vendor")
	_check(dropped >= 1 and not PaintedArt._cache.has(PaintedArt.SCREEN_DIR % &"rest"), "an entry unused for two stops is evicted")
	_check(PaintedArt._cache.has(PaintedArt.SCREEN_DIR % &"vendor"), "an entry used every stop stays")
	_check(PaintedArt.screen_texture(&"rest") != null, "an evicted entry loads again when needed")
	PaintedArt._cache.clear()
	PaintedArt._last_used.clear()
	return _failures
