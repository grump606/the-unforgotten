extends "res://tests/test_base.gd"
## PaintedArt's frame-by-frame warm-up queue: queued paths are not decoded until pump() runs, a pump starts worker
## decodes (at most MAX_DECODING at a time) and turns the finished ones into textures, the queue drains over several
## calls, and a direct request for a queued or decoding path still decodes it at once (taking over its own task).

## Most pump() calls a queue may take to drain (the decodes run on worker threads, so a call can find none done yet).
const MAX_PUMPS := 20000


func run() -> int:
	_failures = 0
	_reset()
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
	# The first pump starts the decodes (the cached vendor screen is skipped).
	PaintedArt.pump(0.0)
	_check(PaintedArt._queue.is_empty() and (PaintedArt._decoding.has(keeper_key) or PaintedArt._cache.has(keeper_key)), "the cached path is skipped and the other is decoding on a worker")
	_check(_drain() and PaintedArt._cache.has(keeper_key) and PaintedArt._cache[keeper_key] != null, "the queue drains over successive calls")
	_check(PaintedArt.pump(0.0) == 0, "pumping an empty queue does nothing")
	# The worker decode makes the same texture and painted box as the main-thread decode.
	var direct := PaintedArt._decode(keeper_key)
	_check(direct != null and (PaintedArt._cache[keeper_key] as Texture2D).get_size() == Vector2(direct.get_size()), "the worker-decoded texture has the image's size")
	_check(PaintedArt._used_rects.get(keeper_key, Rect2i()) == direct.get_used_rect(), "and the painted box measured on the worker")
	# At most MAX_DECODING decodes at a time; the rest wait in the queue.
	PaintedArt._cache.clear()
	var many: Array = [rest_key, vendor_key, keeper_key, PaintedArt.SCREEN_DIR % &"select"]
	PaintedArt.queue_paths(many)
	PaintedArt.pump(0.0)
	_check(PaintedArt._decoding.size() <= PaintedArt.MAX_DECODING, "no more than MAX_DECODING decodes run at once")
	# A path that is decoding is taken over by a direct request: no second decode, and the pump forgets it.
	if not PaintedArt._decoding.is_empty():
		var decoding: String = PaintedArt._decoding.keys()[0]
		_check(PaintedArt.texture(decoding) != null and not PaintedArt._decoding.has(decoding) and PaintedArt._cache.has(decoding), "a direct request takes over a path that is decoding")
	_check(_drain(), "the rest still drains")
	for path in many:
		_check(PaintedArt._cache.has(path) and PaintedArt._cache[path] != null, "%s ends up cached" % path)
	# A missing file ends up a cached null; an already cached path is not queued.
	PaintedArt.queue_paths([rest_key, "res://art/layers/screens/nope/bg.png"])
	_check(PaintedArt.pending() == 1, "an already cached path is not queued")
	_check(_drain() and PaintedArt._cache.has("res://art/layers/screens/nope/bg.png") and PaintedArt.screen_texture(&"nope") == null, "a missing queued file ends up a cached null")
	# What a stop's art is: a rest with no class warms the neutral rest backdrop.
	PaintedArt._cache.clear()
	PaintedArt.queue_for_stop(RunState.StopType.REST, &"")
	_check(_drain() and PaintedArt._cache.has(rest_key), "a queued rest stop's art ends up cached")
	_check(PaintedArt.paths_for_stop(RunState.StopType.STORY, &"", -1).is_empty(), "a story stop with no beat has no art to warm")
	_test_queue_touches_cached_paths(vendor_key)
	_test_churn()
	_reset()
	return _failures


## Fast screen changes: a seeded random mix of queueing stops' art, pumping, drawing a path at once (often one that is
## still decoding), changing stop (eviction) and dropping the queue, the way a player clicking through screens drives it.
## Every texture handed out must be the real one, and nothing may be left decoding once the churn stops.
func _test_churn() -> void:
	_reset()
	var paths: Array[String] = []
	for dir_name in DirAccess.get_directories_at("res://art/layers/screens"):
		paths.append(PaintedArt.SCREEN_DIR % dir_name)
	for dir_name in DirAccess.get_directories_at("res://art/layers/cards").slice(0, 40):
		paths.append(PaintedArt.CARD_DIR % dir_name)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var wrong := 0
	var draws := 0
	var takeovers := 0
	for step in 600:
		var roll := rng.randi_range(0, 99)
		if roll < 40:
			var batch: Array = []
			for i in rng.randi_range(1, 4):
				batch.append(paths[rng.randi_range(0, paths.size() - 1)])
			PaintedArt.queue_paths(batch)
		elif roll < 75:
			PaintedArt.pump(0.0)
		elif roll < 93:
			var path: String = paths[rng.randi_range(0, paths.size() - 1)]
			if not PaintedArt._decoding.is_empty() and rng.randi_range(0, 1) == 0:
				path = PaintedArt._decoding.keys()[0]
				takeovers += 1
			var tex := PaintedArt.texture(path)
			draws += 1
			if tex == null or tex.get_size().x <= 0:
				wrong += 1
		elif roll < 98:
			PaintedArt.advance_stop()
		else:
			PaintedArt.reset_queue()
	_check(draws > 50 and takeovers > 5, "the churn drew %d textures, %d of them taken over mid-decode" % [draws, takeovers])
	_check(wrong == 0, "every texture handed out during the churn is real (%d wrong)" % wrong)
	_check(_drain() and PaintedArt._decoding.is_empty(), "after the churn the queue drains and nothing is left decoding")


func _reset() -> void:
	PaintedArt.reset_queue()
	PaintedArt._cache.clear()
	PaintedArt._last_used.clear()


## Pumps until nothing is pending (what the run does over several frames). False if it did not drain.
func _drain() -> bool:
	var pumps := 0
	while PaintedArt.pending() > 0 and pumps < MAX_PUMPS:
		PaintedArt.pump(0.0)
		OS.delay_usec(100)
		pumps += 1
	return PaintedArt.pending() == 0


## A path cached two stops ago and queued again must survive the next advance_stop() (its screen is about to draw).
func _test_queue_touches_cached_paths(key: String) -> void:
	_reset()
	var serial := PaintedArt._stop_serial
	PaintedArt._cache[key] = null
	PaintedArt._last_used[key] = serial - (PaintedArt.EVICT_AFTER_STOPS - 1) # one stop from being evicted
	PaintedArt.queue_paths([key])
	_check(PaintedArt.pending() == 0, "a cached path is not queued")
	PaintedArt.advance_stop()
	_check(PaintedArt._cache.has(key), "queueing a cached path keeps it through the next stop's eviction")
