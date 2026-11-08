extends "res://tests/test_base.gd"
## PaintedArt's frame-by-frame warm-up queue: queued paths are not decoded until pump() runs, a pump decodes a
## bounded amount and a queue drains over several calls, and a direct request for a queued path still decodes at once.


func run() -> int:
	_failures = 0
	PaintedArt._cache.clear()
	PaintedArt._last_used.clear()
	PaintedArt._queue.clear()
	var vendor_key: String = PaintedArt.SCREEN_DIR % &"vendor"
	var rest_key: String = PaintedArt.SCREEN_DIR % &"rest"
	var keeper_key := "res://art/layers/screens/vendor/keeper.png"
	PaintedArt.queue_for_stop(RunState.StopType.VENDOR)
	_check(PaintedArt.pending() == 2 and not PaintedArt._cache.has(vendor_key), "queueing a stop's art decodes nothing yet")
	PaintedArt.queue_for_stop(RunState.StopType.VENDOR)
	_check(PaintedArt.pending() == 2, "queueing the same art again adds nothing")
	# A draw that needs a queued path decodes it immediately, exactly as before.
	var tex := PaintedArt.screen_texture(&"vendor")
	_check(tex != null and PaintedArt._cache.has(vendor_key), "an immediate request decodes a queued path at once")
	# Pumping with no budget decodes one file per call (the first always runs), skipping what is cached already.
	var left := PaintedArt.pump(0.0)
	_check(left == 1 and PaintedArt._cache.has(vendor_key), "the already-decoded path is skipped, one call, one file")
	_check(PaintedArt.pump(0.0) == 0 and PaintedArt._cache.has(keeper_key), "the queue drains over successive calls")
	_check(PaintedArt.pump(0.0) == 0, "pumping an empty queue does nothing")
	PaintedArt.queue_paths([rest_key, "res://art/layers/screens/nope/bg.png", vendor_key])
	_check(PaintedArt.pending() == 2, "an already cached path is not queued")
	var steps := 0
	while PaintedArt.pending() > 0 and steps < 10:
		PaintedArt.pump(0.0)
		steps += 1
	_check(steps == 2, "two queued files take two single-file pumps")
	_check(PaintedArt._cache.has(rest_key) and PaintedArt._cache.has("res://art/layers/screens/nope/bg.png"), "queued files, even a missing one, end up cached")
	_check(PaintedArt.screen_texture(&"nope") == null, "a missing queued file stays a cached null")
	# The synchronous warm-up still decodes at once, and eviction is unchanged.
	PaintedArt._cache.clear()
	PaintedArt.warm_for_stop(RunState.StopType.REST, &"")
	_check(PaintedArt._cache.has(rest_key), "warm_for_stop still fills the cache immediately")
	_check(PaintedArt.paths_for_stop(RunState.StopType.STORY, &"", -1).is_empty(), "a story stop with no beat has no art to warm")
	PaintedArt._cache.clear()
	PaintedArt._last_used.clear()
	PaintedArt._queue.clear()
	return _failures
