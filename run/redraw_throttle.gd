class_name RedrawThrottle
extends RefCounted
## Paces the redraws of a slow ambient animation (backdrops, motes, lanterns) to HZ per second, however fast
## the game runs. The animation clock still advances every frame; only the repaint is shared out. Keeps the
## remainder of each interval so the average rate does not drift, and catches up by at most one interval after a
## long frame. Anything that reacts to the player (hover, drag, a hit) must not use it and redraws at once.

const HZ := 30.0

## Slack on the interval: float sums of 60 Hz frame times land a hair under the step (two frames of 16.66 ms
## against 33.33 ms), and without it the redraws would alternate between 30 and 20 Hz.
const TOLERANCE := 0.0005

var _accum := 0.0


## Adds a frame's `delta`; true when the picture should be repainted now.
func due(delta: float, hz := HZ) -> bool:
	var step := 1.0 / hz
	_accum += delta
	if _accum < step - TOLERANCE:
		return false
	_accum = minf(_accum - step, step)
	return true
