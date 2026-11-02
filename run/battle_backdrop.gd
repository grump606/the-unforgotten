class_name BattleBackdrop
extends Control
## Animated backdrop for the battle screen, drawn entirely in code: the inside of a ghost-train
## corridor seen head-on at night, windows and ribs rushing past, swaying lamps, drifting motes
## (see docs/BATTLE_BACKDROP_DESIGN.md). It stays dark and low-contrast so the UI above it reads,
## only animates while visible in the tree and is driven by advance(delta), so tests can step it.

const NIGHT := Color(0.035, 0.04, 0.06)
const STEEL := Color(0.16, 0.19, 0.25)
const AMBER := Color(1.0, 0.78, 0.42)
const RED := Color(0.92, 0.22, 0.16)
const PALE := Color(0.72, 0.84, 0.95)
const OVERSCAN := 48.0 # the sway never shows an uncovered corner
const VANISH := Vector2(0.5, 0.36) # the far end, as a fraction of the screen
const FAR_HALF := Vector2(0.075, 0.10) # half size of the far end, as a fraction of the screen
const RIB_COUNT := 8
const WINDOW_COUNT := 8
const LAMP_COUNT := 6
const MOTE_COUNT := 44
const NOISE_SIZE := 64
## Per-class tint, mixed into the lines, glass, glow and dust only (neutral for anything else).
const TINTS := {
	&"deserter": Color(0.70, 0.34, 0.14),
	&"pickpocket": Color(0.12, 0.60, 0.58),
	&"medium": Color(0.52, 0.30, 0.78),
}
const TINT_AMOUNT := 0.32
## The boss fight keeps its red mood: the class tint is scaled down there.
const BOSS_TINT_SCALE := 0.5
## How much of the class colour the window glass takes, and the strength of the class glow at the far end.
const GLASS_TINT := 0.45
const ACCENT_GLOW := 0.07

## Seconds of animation so far; only advance() moves it.
var time := 0.0
## True for the Conductor fight: redder lamps, a pale glow ahead, stronger sway.
var boss := false
## One of the TINTS keys; anything else (including empty) draws the neutral scene.
var character_id: StringName = &""
## Optional route-selected painting; an empty key retains standalone/class previews.
var destination_key: StringName = &""

var _noise: Array[float] = []
## x, y, speed, phase, size per mote, flattened.
var _motes: Array[float] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# A local generator with a fixed seed: the look is repeatable and the run's RNG is untouched.
	var rng := RandomNumberGenerator.new()
	rng.seed = 1906
	for i in NOISE_SIZE:
		_noise.append(rng.randf())
	for i in MOTE_COUNT:
		_motes.append_array([rng.randf(), rng.randf(), rng.randf_range(0.015, 0.05), rng.randf() * TAU, rng.randf_range(0.8, 1.9)])


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	visibility_changed.connect(_on_visibility_changed)
	_on_visibility_changed()


func _on_visibility_changed() -> void:
	set_process(is_visible_in_tree()) # no cost while hidden


func _process(delta: float) -> void:
	advance(delta)


func set_variant(is_boss: bool, id: StringName, location: StringName = &"") -> void:
	boss = is_boss
	character_id = id
	destination_key = location
	queue_redraw()


## Steps the animation. Does nothing unless the backdrop is on screen.
func advance(delta: float) -> void:
	if not is_visible_in_tree():
		return
	time += delta
	queue_redraw()


## Smooth pseudo-random value in 0..1, changing `speed` times a second; `offset` decorrelates users.
func _wobble(speed: float, offset: int) -> float:
	var x := time * speed
	var i := floori(x)
	var a: float = _noise[(i + offset) % NOISE_SIZE]
	var b: float = _noise[(i + 1 + offset) % NOISE_SIZE]
	return lerpf(a, b, smoothstep(0.0, 1.0, x - i))


## Lamp brightness: gentle in a normal fight, a harsher flicker for the boss.
func lamp_level() -> float:
	return lerpf(0.45 if boss else 0.75, 1.0, _wobble(11.0, 0))


## Side to side sway of the carriage in -1..1.
func sway() -> float:
	return sin(time * (0.9 if boss else 0.5)) + 0.35 * sin(time * 2.3)


## How fast the corridor rushes by, in cycles a second.
func speed() -> float:
	return 0.20 if boss else 0.15


func lamp_color() -> Color:
	return RED if boss else AMBER


## The class tint colour, or white (with no effect) for an unknown class.
func tint() -> Color:
	return TINTS.get(character_id, Color.WHITE)


func _mix(base: Color) -> Color:
	return base.lerp(tint(), tint_amount()) if TINTS.has(character_id) else base


## How strongly the class colour is mixed in: 0 for a neutral scene, less in the boss fight.
func tint_amount() -> float:
	if not TINTS.has(character_id):
		return 0.0
	return TINT_AMOUNT * (BOSS_TINT_SCALE if boss else 1.0)


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 8.0 or h < 8.0:
		return
	var level := lamp_level()
	var sw := sway()
	var painted := PaintedArt.screen_texture(painted_name())
	if painted != null:
		_draw_painted(painted, w, h, level, sw)
		return
	var vp := Vector2(w * VANISH.x + sw * 5.0, h * VANISH.y)
	var far := Vector2(w * FAR_HALF.x, h * FAR_HALF.y)
	# The picture sways about the centre; the overscan keeps the corners covered.
	draw_set_transform(size * 0.5 + Vector2(sw * 3.0, 0.0), sw * (0.012 if boss else 0.006), Vector2.ONE)
	var o := -size * 0.5 # origin shift: everything below is drawn in screen coordinates
	draw_rect(Rect2(o - Vector2(OVERSCAN, OVERSCAN), size + Vector2(OVERSCAN, OVERSCAN) * 2.0), NIGHT)
	_draw_end(o, vp, far)
	_draw_rails(o, vp, far, w, h)
	_draw_ribs(o, vp, far, w, h)
	_draw_windows(o, vp, far, w, h)
	_draw_floor(o, vp, far, w, h, level)
	_draw_lamps(o, vp, far, w, h, level)
	_draw_motes(o, w, h)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_scrim(w, h)


## Key of the painted background for this fight (art/layers/screens/<key>/bg.png).
func painted_name() -> StringName:
	if destination_key != &"" and PaintedArt.screen_texture(destination_key) != null:
		return destination_key
	if boss:
		return &"battle_boss"
	return StringName("battle_" + String(character_id)) if TINTS.has(character_id) else &"battle_neutral"


## The painted corridor: slowly drifting and swaying, dimmed to keep the UI readable, with the lamp
## flicker as a brightness wobble and the drifting motes on top.
func _draw_painted(tex: Texture2D, w: float, h: float, level: float, sw: float) -> void:
	var pan := Vector2(sw * 0.5, sin(time * 0.3) * 0.25)
	PaintedArt.draw_cover(self, tex, Rect2(Vector2.ZERO, size), 1.1, pan, Color(0.72, 0.72, 0.72))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.01, 0.02, (1.0 - level) * 0.25))
	_draw_motes(Vector2.ZERO, w, h)
	_draw_scrim(w, h)


## Point on a corridor wall: side -1 left or 1 right, depth s (0 far, 1 at the viewer), v 0 ceiling to 1 floor.
func _wall(vp: Vector2, far: Vector2, w: float, h: float, side: float, s: float, v: float) -> Vector2:
	var x := vp.x + side * lerpf(far.x, w * 0.5 + OVERSCAN, s)
	var top := lerpf(vp.y - far.y, -OVERSCAN, s)
	var bottom := lerpf(vp.y + far.y, h + OVERSCAN, s)
	return Vector2(x, lerpf(top, bottom, v))


func _draw_end(o: Vector2, vp: Vector2, far: Vector2) -> void:
	# The far end of the carriage: a door frame, with a pale glow behind it in the boss fight.
	var door := Rect2(o + vp - far, far * 2.0)
	var glow := 0.16 if boss else 0.05
	var breathe := 0.85 + 0.15 * sin(time * 0.8)
	var pale := _mix(PALE)
	draw_rect(door, Color(pale, glow * 1.6 * breathe))
	draw_rect(door, _mix(STEEL), false, 2.0)
	for i in 7:
		draw_circle(o + vp, far.y * (1.0 + i * 0.6), Color(pale, glow * 0.25 * breathe))
	draw_line(o + vp + Vector2(0, -far.y), o + vp + Vector2(0, far.y), Color(pale, glow * 3.0 * breathe), 1.5)
	# A class-coloured wash around the doorway, so each class has its own light down the corridor.
	if TINTS.has(character_id):
		var accent := tint() if not boss else _mix(RED)
		for i in 5:
			draw_circle(o + vp, far.y * (1.4 + i * 1.5), Color(accent, ACCENT_GLOW * (tint_amount() / TINT_AMOUNT) * breathe * 0.5))


func _draw_rails(o: Vector2, vp: Vector2, far: Vector2, w: float, h: float) -> void:
	# Where wall, ceiling and floor meet, plus a few seams across the floor and ceiling.
	var line := Color(_mix(STEEL), 0.55)
	for side in [-1.0, 1.0]:
		for v in [0.0, 1.0]:
			draw_line(o + _wall(vp, far, w, h, side, 0.0, v), o + _wall(vp, far, w, h, side, 1.0, v), line, 2.0)
	var seam := Color(_mix(STEEL), 0.28)
	for k in range(1, 5):
		var f := k / 5.0
		for v in [0.0, 1.0]:
			var a := o + _wall(vp, far, w, h, -1.0, 0.0, v).lerp(_wall(vp, far, w, h, 1.0, 0.0, v), f)
			var b := o + _wall(vp, far, w, h, -1.0, 1.0, v).lerp(_wall(vp, far, w, h, 1.0, 1.0, v), f)
			draw_line(a, b, seam, 1.0)


func _draw_ribs(o: Vector2, vp: Vector2, far: Vector2, w: float, h: float) -> void:
	# Frame ribs rushing outward, quickening as they near the viewer.
	for k in RIB_COUNT:
		var p := fposmod(float(k) / RIB_COUNT + time * speed(), 1.0)
		var s := p * p
		var a := o + _wall(vp, far, w, h, -1.0, s, 0.0)
		var b := o + _wall(vp, far, w, h, 1.0, s, 1.0)
		var fade := clampf(p * 6.0, 0.0, 1.0) * clampf((1.0 - p) * 3.0, 0.0, 1.0)
		draw_rect(Rect2(a, b - a), Color(_mix(STEEL), 0.5 * fade), false, 1.0 + 2.0 * s)


func _draw_windows(o: Vector2, vp: Vector2, far: Vector2, w: float, h: float) -> void:
	# Windows on both walls, sliding past; the world outside is a dark blue with distant lights.
	var pale := _mix(PALE)
	var glass := Color(0.10, 0.14, 0.22).lerp(tint(), GLASS_TINT * (tint_amount() / TINT_AMOUNT))
	var light := tint().lerp(Color.WHITE, 0.25) if TINTS.has(character_id) and not boss else lamp_color()
	for k in WINDOW_COUNT:
		var p := fposmod(float(k) / WINDOW_COUNT + time * speed(), 1.0)
		var p2 := minf(p + 0.05, 1.0)
		var fade := clampf(p * 6.0, 0.0, 1.0) * clampf((1.0 - p) * 3.0, 0.0, 1.0)
		for side in [-1.0, 1.0]:
			var n: float = _noise[(k * 2 + (0 if side < 0.0 else 1)) % NOISE_SIZE]
			var a := _wall(vp, far, w, h, side, p * p, 0.22)
			var b := _wall(vp, far, w, h, side, p2 * p2, 0.22)
			var c := _wall(vp, far, w, h, side, p2 * p2, 0.62)
			var d := _wall(vp, far, w, h, side, p * p, 0.62)
			draw_colored_polygon(PackedVector2Array([o + a, o + b, o + c, o + d]), Color(glass, 0.55 * fade))
			# A light in the dark outside, now and then, slides across the glass faster than the frame.
			var lit := smoothstep(0.55, 0.9, n)
			if lit > 0.0:
				var q := p + 0.05 * fposmod(n * 7.0 + time * 0.4, 1.0)
				var m := _wall(vp, far, w, h, side, q * q, 0.34 + 0.1 * n)
				draw_circle(o + m, 1.0 + 4.0 * q * q, Color(light, 0.5 * lit * fade))
			draw_polyline(PackedVector2Array([o + a, o + b, o + c, o + d, o + a]), Color(pale, 0.10 * fade), 1.0)


func _draw_floor(o: Vector2, vp: Vector2, far: Vector2, w: float, h: float, level: float) -> void:
	# A faint sheen down the middle of the floor, and the lamps reflected in it.
	var shine := Color(_mix(PALE), 0.05 + 0.02 * level)
	var clear := Color(shine, 0.0)
	draw_polygon(PackedVector2Array([
		o + Vector2(vp.x - far.x * 0.4, vp.y + far.y), o + Vector2(vp.x + far.x * 0.4, vp.y + far.y),
		o + Vector2(vp.x + w * 0.16, h + OVERSCAN), o + Vector2(vp.x - w * 0.16, h + OVERSCAN)]),
		PackedColorArray([clear, clear, shine, shine]))
	for k in LAMP_COUNT:
		var p := fposmod(float(k) / LAMP_COUNT + time * speed(), 1.0)
		var s := p * p
		var y: float = _wall(vp, far, w, h, 0.0, s, 1.0).y
		var half := lerpf(far.x * 0.5, w * 0.07, s)
		var lane := (1.0 if k % 2 == 0 else -1.0) * lerpf(far.x * 0.7, w * 0.30, s)
		var fade := clampf(p * 6.0, 0.0, 1.0) * clampf((1.0 - p) * 3.0, 0.0, 1.0)
		var col := Color(lamp_color(), 0.09 * level * fade)
		draw_colored_polygon(PackedVector2Array([
			o + Vector2(vp.x + lane - half, y), o + Vector2(vp.x + lane, y - half * 0.12),
			o + Vector2(vp.x + lane + half, y), o + Vector2(vp.x + lane, y + half * 0.12)]), col)


func _draw_lamps(o: Vector2, vp: Vector2, far: Vector2, w: float, h: float, level: float) -> void:
	# Lamps hanging from the ceiling along the middle, each swinging on its own rhythm.
	var amp := 0.35 if boss else 0.18
	for k in LAMP_COUNT:
		var p := fposmod(float(k) / LAMP_COUNT + time * speed(), 1.0)
		var s := p * p
		var fade := clampf(p * 6.0, 0.0, 1.0) * clampf((1.0 - p) * 3.0, 0.0, 1.0)
		var ceiling := _wall(vp, far, w, h, 0.0, s, 0.0) + Vector2((1.0 if k % 2 == 0 else -1.0) * lerpf(far.x * 0.7, w * 0.30, s), 0.0)
		var drop := lerpf(far.y * 0.35, h * 0.12, s)
		var swing := amp * sin(time * 1.25 + k * 2.1) + 0.04 * sin(time * 3.7 + k)
		var bulb := ceiling + Vector2(sin(swing), cos(swing)) * drop
		var lamp := lamp_color()
		var rad := lerpf(1.5, 7.0, s)
		var flicker := level * fade
		draw_line(o + ceiling, o + bulb, Color(0.02, 0.02, 0.03, fade), 1.0 + 1.5 * s)
		for i in 3:
			draw_circle(o + bulb, rad * (1.5 + i * 1.8), Color(lamp, 0.06 * flicker))
		draw_circle(o + bulb, rad, Color(lamp.lerp(Color.WHITE, 0.45), 0.8 * flicker))


func _draw_motes(o: Vector2, w: float, h: float) -> void:
	# Dust, or embers in the boss fight, drifting up and sideways; positions are pure functions of time.
	var col := Color(1.0, 0.55, 0.32) if boss else _mix(Color(0.85, 0.88, 0.95))
	for i in MOTE_COUNT:
		var base := i * 5
		var rise := _motes[base + 2] * (2.0 if boss else 1.0)
		var y := fposmod(_motes[base + 1] - time * rise, 1.0)
		var x := _motes[base] + 0.02 * sin(time * 0.6 + _motes[base + 3])
		var twinkle := 0.5 + 0.5 * sin(time * 1.7 + _motes[base + 3])
		draw_circle(o + Vector2(fposmod(x, 1.0) * w, y * h), _motes[base + 4], Color(col, 0.10 + 0.20 * twinkle))


func _draw_scrim(w: float, h: float) -> void:
	# Keeps the art subordinate: a light dim overall, darker edges and a darker lower third for the hand.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.01, 0.02, 0.2))
	var dark := Color(0.01, 0.01, 0.02, 0.6)
	var clear := Color(dark, 0.0)
	var edge := w * 0.2
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(edge, 0), Vector2(edge, h), Vector2(0, h)]), PackedColorArray([dark, clear, clear, dark]))
	draw_polygon(PackedVector2Array([Vector2(w - edge, 0), Vector2(w, 0), Vector2(w, h), Vector2(w - edge, h)]), PackedColorArray([clear, dark, dark, clear]))
	var rim := h * 0.14
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, rim), Vector2(0, rim)]), PackedColorArray([dark, dark, clear, clear]))
	var floor_zone := h * 0.45
	var shade := Color(0.01, 0.01, 0.02, 0.45)
	draw_polygon(PackedVector2Array([Vector2(0, h - floor_zone), Vector2(w, h - floor_zone), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([Color(shade, 0.0), Color(shade, 0.0), shade, shade]))
