class_name ScreenScene
extends Control
## Shared base of the code-drawn scenes behind the rest stop, story beats and end card (see
## docs/SCREEN_ART_DESIGN.md): one accumulator `time`, a seeded noise table and mote field built
## from a local generator, advance(delta) that only runs while visible in the tree, and a few
## drawing helpers. Subclasses implement _draw_scene(). It ignores the mouse.

const NIGHT := Color(0.03, 0.03, 0.045)
const AMBER := Color(1.0, 0.78, 0.42)
const BRASS := Color(0.78, 0.55, 0.24)
const PALE := Color(0.72, 0.84, 0.95)
const WOOD := Color(0.20, 0.12, 0.07)
const NOISE_SIZE := 64

## Seconds of animation so far; only advance() moves it.
var time := 0.0

var _noise: Array[float] = []
## x, y, speed, phase, size per mote, flattened.
var _motes: Array[float] = []
var _mote_count := 0


func _init(seed_value := 1, mote_count := 30) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	clip_contents = true # lines and halos that run past the edge stay inside the body
	# A local generator with a fixed seed: the look is repeatable and the run's RNG is untouched.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in NOISE_SIZE:
		_noise.append(rng.randf())
	_mote_count = mote_count
	for i in mote_count:
		_motes.append_array([rng.randf(), rng.randf(), rng.randf_range(0.012, 0.04), rng.randf() * TAU, rng.randf_range(0.8, 1.8)])


func _ready() -> void:
	visibility_changed.connect(_on_visibility_changed)
	_on_visibility_changed()


func _on_visibility_changed() -> void:
	set_process(is_visible_in_tree()) # no cost while hidden


func _process(delta: float) -> void:
	advance(delta)


## Steps the animation. Does nothing unless the scene is on screen.
func advance(delta: float) -> void:
	if not is_visible_in_tree():
		return
	time += delta
	queue_redraw()


## Smooth pseudo-random value in 0..1, changing `speed` times a second; `offset` decorrelates users.
func wobble(speed: float, offset: int) -> float:
	var x := time * speed
	var i := floori(x)
	var a: float = _noise[(i + offset) % NOISE_SIZE]
	var b: float = _noise[(i + 1 + offset) % NOISE_SIZE]
	return lerpf(a, b, smoothstep(0.0, 1.0, x - i))


## Brightness of light `k` in 0.72..1: a steady glow with a small flicker.
func flicker(k: int) -> float:
	return lerpf(0.72, 1.0, wobble(7.0 + k, k * 13))


func _draw() -> void:
	if size.x < 64.0 or size.y < 64.0:
		return
	_draw_scene(size.x, size.y)


func _draw_scene(_w: float, _h: float) -> void:
	pass


## Draws the painted background `bg_name` (art/layers/screens/<bg_name>/bg.png) over `rect` with a slow
## drifting pan. Returns false, drawing nothing, when that picture is not there (draw the code art instead).
func _draw_painted_bg(bg_name: StringName, rect: Rect2, zoom := 1.08, drift := 0.4, tint := Color.WHITE) -> bool:
	var tex := PaintedArt.screen_texture(bg_name)
	if tex == null:
		return false
	var pan := Vector2(sin(time * 0.17), cos(time * 0.11) * 0.5) * drift
	PaintedArt.draw_cover(self, tex, rect, zoom, pan, tint)
	return true


# --- helpers ---------------------------------------------------------------------------

func _ellipse(c: Vector2, rx: float, ry: float, col: Color, n := 16) -> void:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)


## A soft pool of light: many faint rings so it fades smoothly instead of banding.
func _halo(c: Vector2, radius: float, col: Color, alpha: float, squash := 1.0) -> void:
	for i in 10:
		var r := radius * (1.0 - i / 10.0)
		_ellipse(c, r, r * squash, Color(col, alpha), 18)


func _lit(c: Color, light: float) -> Color:
	return Color(c.r * light, c.g * light, c.b * light, c.a)


func _poly(points: Array, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array(points), col)


## A vertical colour ramp over a rectangle.
func _gradient(rect: Rect2, top: Color, bottom: Color) -> void:
	draw_polygon(PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]),
		PackedColorArray([top, top, bottom, bottom]))


## Dust or ash drifting up across the whole scene; positions are pure functions of time.
func _draw_motes(w: float, h: float, col: Color, strength := 1.0) -> void:
	for i in _mote_count:
		var base := i * 5
		var y := fposmod(_motes[base + 1] - time * _motes[base + 2], 1.0)
		var x := _motes[base] + 0.015 * sin(time * 0.5 + _motes[base + 3])
		var twinkle := 0.5 + 0.5 * sin(time * 1.3 + _motes[base + 3])
		draw_circle(Vector2(fposmod(x, 1.0) * w, y * h), _motes[base + 4], Color(col, (0.07 + 0.15 * twinkle) * strength))


## Darker sides and top so the art stays subordinate to the panel; `extra` dims everything.
func _draw_scrim(w: float, h: float, extra := 0.0) -> void:
	var dark := Color(0.01, 0.01, 0.015, 0.6)
	var clear := Color(dark, 0.0)
	var edge := w * 0.1
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(edge, 0), Vector2(edge, h), Vector2(0, h)]), PackedColorArray([dark, clear, clear, dark]))
	draw_polygon(PackedVector2Array([Vector2(w - edge, 0), Vector2(w, 0), Vector2(w, h), Vector2(w - edge, h)]), PackedColorArray([clear, dark, dark, clear]))
	if extra > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.01, 0.015, extra))


## A hanging lantern: chain, cap, glass with a bright flame, and a halo of the given strength.
func _draw_lantern(ceiling: Vector2, drop: float, k: int, scale_factor := 1.0, halo := 1.0) -> void:
	var level := flicker(k)
	var swing := 0.05 * sin(time * 0.9 + k * 1.7)
	var bulb := ceiling + Vector2(sin(swing), cos(swing)) * drop
	draw_line(ceiling, bulb - Vector2(0, 14.0 * scale_factor), Color(0.02, 0.015, 0.02), 1.5)
	_halo(bulb, 150.0 * scale_factor, AMBER, 0.018 * level * halo)
	var hw := 11.0 * scale_factor
	var hh := 15.0 * scale_factor
	_poly([bulb + Vector2(-hw, -hh * 0.6), bulb + Vector2(0, -hh), bulb + Vector2(hw, -hh * 0.6)], Color(0.1, 0.065, 0.045))
	draw_rect(Rect2(bulb + Vector2(-hw, -hh * 0.6), Vector2(hw * 2.0, hh * 1.5)), Color(AMBER, 0.45 + 0.4 * level))
	draw_rect(Rect2(bulb + Vector2(-hw * 0.4, -hh * 0.3), Vector2(hw * 0.8, hh * 0.9)), Color(1.0, 0.95, 0.75, 0.6 + 0.4 * level))
	draw_rect(Rect2(bulb + Vector2(-hw, -hh * 0.6), Vector2(hw * 2.0, hh * 1.5)), Color(BRASS.r * 0.6, BRASS.g * 0.6, BRASS.b * 0.6), false, 1.5)
