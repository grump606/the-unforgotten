extends SceneTree
## SceneNoise must reproduce, value for value, what each code-drawn scene used to generate inline
## (same seed, same call order on the generator), so the visuals and determinism tests stay put.
## Also checks the PaintedArt warm-up API. Run via scripts/check.ps1.

var fails := 0


func check(c: bool, msg: String) -> void:
	if not c:
		fails += 1
		printerr("FAIL: " + msg)
	else:
		print("ok: " + msg)


## The pre-refactor generation, copied verbatim: noise first, then the motes, from one generator.
func _old(seed_value: int, noise_size: int, mote_count: int, lo: float, hi: float, size_lo: float, size_hi: float) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var noise: Array[float] = []
	for i in noise_size:
		noise.append(rng.randf())
	var motes: Array[float] = []
	for i in mote_count:
		motes.append_array([rng.randf(), rng.randf(), rng.randf_range(lo, hi), rng.randf() * TAU, rng.randf_range(size_lo, size_hi)])
	return [noise, motes]


func _initialize() -> void:
	var backdrop := BattleBackdrop.new()
	var want := _old(1906, 64, 44, 0.015, 0.05, 0.8, 1.9)
	check(backdrop._noise == want[0] and backdrop._motes == want[1], "battle backdrop noise and motes are unchanged")
	backdrop.free()

	var vendor := VendorScene.new()
	want = _old(1913, 64, 36, 0.01, 0.035, 0.8, 1.8)
	check(vendor._noise == want[0] and vendor._motes == want[1], "vendor noise and motes are unchanged")
	vendor.free()

	var pause := PauseScene.new()
	want = _old(606, 64, 0, 0.0, 1.0, 0.0, 1.0)
	check(pause._noise == want[0], "pause noise is unchanged")
	pause.free()

	for params in [[1, 30], [7, 12], [4242, 40]]:
		var scene := ScreenScene.new(params[0], params[1])
		want = _old(params[0], 64, params[1], 0.012, 0.04, 0.8, 1.8)
		check(scene._noise == want[0] and scene._motes == want[1], "screen scene seed %d noise and motes are unchanged" % params[0])
		scene.free()

	# The vendor keeps drawing from the same generator after the motes, so the helper must leave it
	# exactly where the inline loops did.
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 1913
	SceneNoise.noise(rng_a, 64)
	SceneNoise.motes(rng_a, 36, 0.01, 0.035, 0.8, 1.8)
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 1913
	for i in 64:
		rng_b.randf()
	for i in 36:
		rng_b.randf(); rng_b.randf(); rng_b.randf_range(0.01, 0.035); rng_b.randf(); rng_b.randf_range(0.8, 1.8)
	check(rng_a.randi() == rng_b.randi(), "the generator is left in the same state")

	# Warm-up: caches present and missing files, and is idempotent.
	PaintedArt.preload_screen(&"vendor")
	check(PaintedArt._cache.has("res://art/layers/screens/vendor/bg.png"), "preload_screen caches the texture")
	var tex := PaintedArt.screen_texture(&"vendor")
	PaintedArt.preload_screen(&"vendor")
	check(PaintedArt.screen_texture(&"vendor") == tex, "preloading twice returns the same texture")
	PaintedArt.preload_paths(["res://art/layers/screens/nope/bg.png"])
	check(PaintedArt._cache.has("res://art/layers/screens/nope/bg.png") and PaintedArt.screen_texture(&"nope") == null, "a missing file stays a cached null")
	for stop_type in 4:
		PaintedArt.warm_for_stop(stop_type, &"deserter")
	check(PaintedArt.screen_texture(&"rest") == PaintedArt.screen_texture(&"rest"), "warm_for_stop runs for every stop type")

	print("scene noise test: %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)
