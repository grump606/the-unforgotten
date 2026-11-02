class_name SceneNoise
extends RefCounted
## The seeded noise table and mote field shared by the code-drawn scenes. Both take the caller's
## generator and draw from it in a fixed order, so a scene that seeds one generator and calls
## noise() then motes() (then keeps drawing its own values) gets exactly the numbers it always had.


## `size` uniform values in 0..1.
static func noise(rng: RandomNumberGenerator, size: int) -> Array[float]:
	var out: Array[float] = []
	for i in size:
		out.append(rng.randf())
	return out


## x, y, speed, phase, size per mote, flattened. Speed and size are drawn from the given ranges.
static func motes(rng: RandomNumberGenerator, count: int, speed_min: float, speed_max: float, size_min: float, size_max: float) -> Array[float]:
	var out: Array[float] = []
	for i in count:
		out.append_array([rng.randf(), rng.randf(), rng.randf_range(speed_min, speed_max), rng.randf() * TAU, rng.randf_range(size_min, size_max)])
	return out
