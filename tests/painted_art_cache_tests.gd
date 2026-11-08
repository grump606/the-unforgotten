extends "res://tests/test_base.gd"
## PaintedArt: warming fills the cache on the main thread, a missing file stays a cached null, a story stop
## warms its own beat's painting, and entries not used for two stops are evicted while recently used ones stay.
## (Decoding is deliberately not threaded: see PaintedArt.warm_for_stop.)


func run() -> int:
	_failures = 0
	PaintedArt._cache.clear()
	PaintedArt._last_used.clear()
	PaintedArt._stop_serial = 0
	var vendor_key: String = PaintedArt.SCREEN_DIR % &"vendor"
	PaintedArt.preload_screen(&"vendor")
	_check(PaintedArt._cache.has(vendor_key), "warming a screen fills the cache at once")
	var tex := PaintedArt.screen_texture(&"vendor")
	_check(tex != null and PaintedArt.screen_texture(&"vendor") == tex, "the warmed texture is the one drawn")
	var direct := PaintedArt._store("test:direct", PaintedArt._decode(vendor_key))
	_check(direct != null and direct.get_size() == tex.get_size(), "a direct decode matches the cached texture")
	PaintedArt.preload_screen(&"nope")
	_check(PaintedArt._cache.has(PaintedArt.SCREEN_DIR % &"nope") and PaintedArt.screen_texture(&"nope") == null, "a missing file stays a cached null")
	PaintedArt.warm_for_stop(RunState.StopType.STORY, &"deserter", 0)
	_check(PaintedArt._cache.has(PaintedArt.SCREEN_DIR % StoryScene.key_for_beat(0)), "a story stop warms its own beat's painting")
	# Eviction: vendor is used again each stop, rest is not.
	PaintedArt.screen_texture(&"rest")
	PaintedArt.advance_stop()
	PaintedArt.screen_texture(&"vendor")
	_check(PaintedArt._cache.has(PaintedArt.SCREEN_DIR % &"rest"), "an entry unused for one stop stays")
	var dropped := PaintedArt.advance_stop()
	PaintedArt.screen_texture(&"vendor")
	_check(dropped >= 1 and not PaintedArt._cache.has(PaintedArt.SCREEN_DIR % &"rest"), "an entry unused for two stops is evicted")
	_check(PaintedArt._cache.has(vendor_key), "an entry used every stop stays")
	_check(PaintedArt.screen_texture(&"rest") != null, "an evicted entry loads again when needed")
	PaintedArt._cache.clear()
	PaintedArt._last_used.clear()
	return _failures
