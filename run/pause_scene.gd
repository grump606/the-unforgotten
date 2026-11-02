class_name PauseScene
extends Control
## Animated backdrop for the pause menu, drawn entirely in code: a dark carriage seen from a
## bench, a tunnel sliding past the window, a flickering lamp and a slow sway, plus one small
## per-character detail (see docs/PAUSE_SCREEN_DESIGN.md). It only animates while visible in
## the tree and is driven by advance(delta), so tests can step it deterministically.

const WALL := Color(0.06, 0.06, 0.09)
const WOOD := Color(0.17, 0.11, 0.08)
const WOOD_LIGHT := Color(0.30, 0.20, 0.13)
const LAMP := Color(1.0, 0.78, 0.42)
const PALE := Color(0.72, 0.84, 0.95)
const TUNNEL := Color(0.02, 0.03, 0.05)
const NOISE_SIZE := 64
const LAMP_COUNT := 6
const RING_COUNT := 7

## Seconds of animation so far; only advance() moves it.
var time := 0.0
## One of &"deserter", &"pickpocket", &"medium"; anything else draws the neutral scene.
var variant: StringName = &""

var _noise: Array[float] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS # the tree is paused while this is on screen
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# A local generator with a fixed seed: the look is repeatable and the run's RNG is untouched.
	var rng := RandomNumberGenerator.new()
	rng.seed = 606
	for i in NOISE_SIZE:
		_noise.append(rng.randf())


func _ready() -> void:
	visibility_changed.connect(_on_visibility_changed)
	_on_visibility_changed()


func _on_visibility_changed() -> void:
	set_process(is_visible_in_tree()) # no cost while the menu is closed


func _process(delta: float) -> void:
	advance(delta)


func set_character(id: StringName) -> void:
	variant = id
	queue_redraw()


## Steps the animation. Does nothing unless the scene is on screen.
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


## Lamp brightness in 0.5..1.
func lamp_level() -> float:
	return lerpf(0.5, 1.0, _wobble(14.0, 0))


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 8.0 or h < 8.0:
		return
	var c := size * 0.5
	var lamp := lamp_level()
	# Everything sways about the centre; the overscan keeps the corners covered.
	var sway := sin(time * 0.55)
	draw_set_transform(c + Vector2(sway * 4.0, sin(time * 1.1) * 2.0), sway * 0.006, Vector2.ONE)
	draw_rect(Rect2(-c - Vector2(60, 60), size + Vector2(120, 120)), WALL)
	var painted := PaintedArt.screen_texture(&"pause")
	if painted != null:
		# The painted carriage replaces the wall, window, bench, lamp and foreground; the lamp flicker
		# becomes a brightness wobble. The class props below still draw on top.
		PaintedArt.draw_cover(self, painted, Rect2(-c - Vector2(60, 60), size + Vector2(120, 120)), 1.0, Vector2.ZERO, Color(0.8, 0.8, 0.8))
		draw_rect(Rect2(-c - Vector2(60, 60), size + Vector2(120, 120)), Color(0.01, 0.01, 0.02, (1.0 - lamp) * 0.3))
	else:
		_draw_wall(w, h, c, lamp)
		_draw_window(Rect2(Vector2(w * 0.22, h * 0.10) - c, Vector2(w * 0.56, h * 0.44)))
		_draw_opposite_bench(w, h, c, lamp)
		_draw_lamp(w, h, c, lamp)
		_draw_foreground(w, h, c, lamp)
	# The painting already supplies the shelter and its props.
	if painted == null:
		match variant:
			&"deserter":
				_draw_coat(w, h, c, lamp)
			&"pickpocket":
				_draw_watch(w, h, c, lamp)
			&"medium":
				_draw_figures(w, h, c)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Scrim: a light dim everywhere and a darker soft band behind the menu so the buttons read.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.02, 0.04, 0.1))
	var band := minf(w * 0.9, 680.0)
	for i in 5:
		var half := band * 0.5 + (4 - i) * 24.0
		draw_rect(Rect2(c.x - half, 0, half * 2.0, h), Color(0.02, 0.02, 0.04, 0.17))


func _draw_wall(w: float, h: float, c: Vector2, lamp: float) -> void:
	# Panel seams and a ceiling band; lit faintly from the lamp side.
	for i in 5:
		var x := w * (0.04 + 0.23 * i) - c.x
		draw_line(Vector2(x, -c.y), Vector2(x, h * 0.62 - c.y), Color(0.03, 0.03, 0.05, 0.8), 3.0)
	draw_rect(Rect2(-c.x - 60, -c.y - 60, w + 120, h * 0.06 + 60), Color(0.04, 0.04, 0.06))
	draw_circle(Vector2(w * 0.78, h * 0.12) - c, w * 0.35, Color(LAMP, 0.05 * lamp))


func _draw_window(r: Rect2) -> void:
	draw_rect(r, TUNNEL)
	var vp := r.position + r.size * Vector2(0.56, 0.47) # far end of the tunnel
	var flash := 0.0
	# Tunnel ribs rushing outward, quickening as they near the glass.
	for k in RING_COUNT:
		var p := fposmod(float(k) / RING_COUNT + time * 0.22, 1.0)
		var s := p * p
		var a := vp + (r.position - vp) * s
		var b := vp + (r.end - vp) * s
		draw_rect(Rect2(a, b - a), Color(0.16, 0.20, 0.27, 0.9 * (1.0 - p)), false, 2.0)
	# Wall lamps, alternating sides, drifting out from the vanishing point.
	for k in LAMP_COUNT:
		var p := fposmod(float(k) / LAMP_COUNT + time * 0.17, 1.0)
		var s := p * p
		var side := -1.0 if k % 2 == 0 else 1.0
		var pos := vp + Vector2(side * r.size.x * 0.36, -r.size.y * 0.16) * s
		var fade := clampf((1.0 - p) * 5.0, 0.0, 1.0)
		var rad := lerpf(1.5, r.size.y * 0.05, s)
		draw_circle(pos, rad * 3.0, Color(LAMP, 0.10 * fade))
		draw_circle(pos, rad * 1.6, Color(LAMP, 0.25 * fade))
		draw_circle(pos, rad, Color(1.0, 0.92, 0.7, fade))
		if p > 0.75:
			flash = maxf(flash, (p - 0.75) * 4.0 * fade)
	# The faint pale glow far ahead, breathing slowly.
	var breathe := 0.8 + 0.2 * sin(time * 0.9)
	for i in 4:
		draw_circle(vp, r.size.y * (0.035 + 0.03 * i), Color(PALE, 0.10 * breathe))
	draw_circle(vp, r.size.y * 0.02, Color(PALE, 0.7 * breathe))
	draw_rect(r, Color(LAMP, 0.07 * flash)) # a passing lamp washes the glass
	# Glass reflection, then frame and mullion.
	draw_colored_polygon(PackedVector2Array([
		r.position + Vector2(r.size.x * 0.10, 0), r.position + Vector2(r.size.x * 0.24, 0),
		r.position + Vector2(r.size.x * 0.10, r.size.y), r.position + Vector2(0, r.size.y)]), Color(PALE, 0.04))
	draw_rect(r, WOOD, false, 14.0)
	draw_line(r.position + Vector2(r.size.x * 0.5, 0), r.position + Vector2(r.size.x * 0.5, r.size.y), WOOD, 8.0)
	draw_rect(Rect2(r.position + Vector2(-10, r.size.y + 6), Vector2(r.size.x + 20, 10)), WOOD_LIGHT)


func _draw_opposite_bench(w: float, h: float, c: Vector2, lamp: float) -> void:
	# The seat across the aisle: a back rest and a seat, both in near darkness.
	draw_rect(Rect2(Vector2(w * 0.12, h * 0.58) - c, Vector2(w * 0.76, h * 0.20)), Color(WOOD, 0.9).darkened(0.35))
	draw_rect(Rect2(Vector2(w * 0.12, h * 0.58) - c, Vector2(w * 0.76, 6.0)), Color(WOOD_LIGHT, 0.5 * lamp))
	draw_rect(Rect2(Vector2(w * 0.10, h * 0.78) - c, Vector2(w * 0.80, h * 0.08)), WOOD.darkened(0.2))


func _draw_lamp(w: float, h: float, c: Vector2, lamp: float) -> void:
	var top := Vector2(w * 0.78, 0) - c
	var bulb := Vector2(w * 0.78, h * 0.12) - c
	draw_line(top, bulb + Vector2(0, -16), Color(0.02, 0.02, 0.03), 3.0)
	# Cone of light spreading over the seats.
	draw_colored_polygon(PackedVector2Array([bulb, bulb + Vector2(-w * 0.26, h * 0.8), bulb + Vector2(w * 0.20, h * 0.8)]), Color(LAMP, 0.06 * lamp))
	draw_colored_polygon(PackedVector2Array([bulb + Vector2(-16, -16), bulb + Vector2(16, -16), bulb + Vector2(26, 2), bulb + Vector2(-26, 2)]), Color(0.05, 0.05, 0.06))
	for i in 4:
		draw_circle(bulb + Vector2(0, 8), 14.0 + i * 12.0, Color(LAMP, 0.06 * lamp))
	draw_circle(bulb + Vector2(0, 7), 7.0, Color(1.0, 0.92, 0.7, lamp))


func _draw_foreground(w: float, h: float, c: Vector2, lamp: float) -> void:
	# The bench you sit on: its front edge fills the bottom of the picture.
	draw_rect(Rect2(Vector2(-60, h * 0.88) - c, Vector2(w + 120, h * 0.12 + 60)), WOOD.darkened(0.45))
	draw_rect(Rect2(Vector2(-60, h * 0.88) - c, Vector2(w + 120, 5.0)), Color(WOOD_LIGHT, 0.6 * lamp))


func _draw_coat(w: float, h: float, c: Vector2, lamp: float) -> void:
	# A discarded uniform coat slumped over the seat edge.
	var lit := lerpf(0.6, 1.0, lamp)
	var body := Color(0.19, 0.22, 0.16) * Color(lit, lit, lit)
	var pts := PackedVector2Array([
		Vector2(0.07, 0.89), Vector2(0.10, 0.78), Vector2(0.16, 0.73), Vector2(0.22, 0.76),
		Vector2(0.27, 0.86), Vector2(0.28, 0.90), Vector2(0.21, 0.92), Vector2(0.19, 0.99),
		Vector2(0.13, 0.99), Vector2(0.12, 0.92), Vector2(0.07, 0.92)])
	for i in pts.size():
		pts[i] = Vector2(pts[i].x * w, pts[i].y * h) - c
	draw_colored_polygon(pts, body)
	draw_polyline(PackedVector2Array([pts[1], pts[2], pts[3]]), body.lightened(0.25), 3.0) # collar
	draw_line(Vector2(0.17 * w, 0.76 * h) - c, Vector2(0.16 * w, 0.95 * h) - c, body.darkened(0.4), 2.0) # front seam
	for i in 3:
		draw_circle(Vector2(0.18 * w, (0.80 + 0.04 * i) * h) - c, 3.0, Color(0.85, 0.7, 0.3, lit)) # brass buttons
	draw_rect(Rect2(Vector2(0.095 * w, 0.775 * h) - c, Vector2(0.035 * w, 7.0)), Color(0.55, 0.45, 0.2, 0.8 * lit)) # epaulette


func _draw_watch(w: float, h: float, c: Vector2, lamp: float) -> void:
	# A stray pocket watch on its chain from a ceiling hook, swinging like the carriage rocks it.
	var hook := Vector2(w * 0.12, 0) - c
	var chain := h * 0.26
	var angle := 0.32 * sin(time * 2.0) + 0.05 * sin(time * 5.3)
	var pos := hook + Vector2(sin(angle), cos(angle)) * chain
	draw_line(hook, pos, Color(0.7, 0.6, 0.3, 0.8), 2.0)
	draw_circle(pos, 19.0, Color(0.45, 0.36, 0.14))
	draw_circle(pos, 16.0, Color(0.92, 0.88, 0.75, lerpf(0.55, 0.9, lamp)))
	draw_line(pos, pos + Vector2(0, -10).rotated(time * 0.4), Color(0.1, 0.1, 0.1), 2.0)
	draw_line(pos, pos + Vector2(7, 0).rotated(time * 0.05), Color(0.1, 0.1, 0.1), 2.0)
	var glint := maxf(0.0, sin(time * 2.0 + 1.2)) # catches the light at the end of each swing
	draw_circle(pos + Vector2(-9, -9), 4.0, Color(1, 1, 1, 0.7 * glint))
	draw_circle(pos + Vector2(0, -24), 4.0, Color(0.45, 0.36, 0.14)) # crown


func _draw_figures(w: float, h: float, c: Vector2) -> void:
	# Faint translucent passengers who are not quite there, flickering in and out of the seats.
	for i in 3:
		var a := smoothstep(0.35, 0.75, _wobble(1.4 + i * 0.3, 17 * (i + 1))) * 0.30
		if a < 0.01:
			continue
		var x := w * (0.26 + 0.24 * i)
		var col := Color(PALE.r, PALE.g, PALE.b, a)
		draw_circle(Vector2(x, h * 0.64) - c, w * 0.03, col)
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - w * 0.055, h * 0.79) - c, Vector2(x - w * 0.04, h * 0.69) - c,
			Vector2(x + w * 0.04, h * 0.69) - c, Vector2(x + w * 0.055, h * 0.79) - c]), col)
