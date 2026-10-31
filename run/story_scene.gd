class_name StoryScene
extends ScreenScene
## Cinematic window behind a story beat: a letterboxed view with a distinct mood per beat index
## (0 boarding at dusk, 1 the conductor in the aisle, 2 an empty platform, 3 the last light at the
## end of the tunnel; anything else is a generic tunnel). See docs/SCREEN_ART_DESIGN.md.

const BAR := 34.0
const RIBS := 9
const STEEL := Color(0.16, 0.19, 0.25)
## On-screen height of the Conductor (see ConductorFigure) in the aisle.
const CONDUCTOR_HEIGHT := 210.0

## Which StoryContent beat this backs; see mood().
var beat_index := 0


func _init() -> void:
	super(2033, 28)


## Name of the mood drawn for `beat_index`.
func mood() -> StringName:
	match beat_index:
		0:
			return &"boarding"
		1:
			return &"conductor"
		2:
			return &"platform"
		3:
			return &"last_light"
	return &"tunnel"


func _draw_scene(w: float, h: float) -> void:
	var win := Rect2(0, BAR, w, h - 2.0 * BAR)
	var mood_name := mood()
	var key := &"story_generic" if mood_name == &"tunnel" else StringName("story_" + String(mood_name))
	if _draw_painted_bg(key, win, 1.08, 0.4):
		if mood_name == &"conductor":
			_draw_conductor_figure(win)
	else:
		match mood_name:
			&"boarding":
				_draw_boarding(win)
			&"conductor":
				_draw_conductor(win)
			&"platform":
				_draw_platform(win)
			&"last_light":
				_draw_last_light(win)
			_:
				_draw_generic(win)
	# The letterbox bars cover anything that spilled over the window.
	draw_rect(Rect2(0, 0, w, BAR), Color.BLACK)
	draw_rect(Rect2(0, h - BAR, w, BAR), Color.BLACK)
	draw_line(Vector2(0, BAR), Vector2(w, BAR), Color(BRASS, 0.35), 1.0)
	draw_line(Vector2(0, h - BAR), Vector2(w, h - BAR), Color(BRASS, 0.35), 1.0)
	_draw_motes(w, h, AMBER if mood() != &"last_light" else PALE, 0.7)
	_draw_scrim(w, h, 0.12)


# --- shared pieces -----------------------------------------------------------------------

## A tunnel in perspective: ribs rushing toward the viewer, rails and wall lines to a far end.
func _draw_tunnel(win: Rect2, vp: Vector2, speed: float, tint: Color, rib_strength: float) -> void:
	draw_rect(win, Color(NIGHT.r, NIGHT.g, NIGHT.b))
	var far := Vector2(win.size.x * 0.05, win.size.y * 0.1)
	var big := Vector2(win.size.x * 0.75, win.size.y * 0.95)
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		draw_line(vp + far * corner, vp + big * corner, Color(STEEL, 0.35), 1.0)
	for i in RIBS:
		var t := fposmod(float(i) / RIBS - time * speed, 1.0)
		var s := t * t
		var half := far.lerp(big, s)
		draw_rect(Rect2(vp - half, half * 2.0), Color(tint, rib_strength * smoothstep(0.0, 0.25, t) * (0.3 + 0.7 * s)), false, 1.0 + 3.0 * s)
	for side in [-1.0, 1.0]: # rails
		draw_line(vp + Vector2(side * 10.0, far.y), Vector2(vp.x + side * win.size.x * 0.22, win.end.y), Color(STEEL, 0.5), 2.0)


## A hollow coat-and-cap figure standing at `feet`, `height` px tall, facing front.
func _draw_coat_figure(feet: Vector2, height: float, coat: Color, rim: Color, hollow: bool, cap: bool) -> void:
	var k := height / 100.0
	draw_set_transform(feet, 0.0, Vector2(k, k))
	_poly([Vector2(-14, 0), Vector2(-19, -38), Vector2(-15, -66), Vector2(15, -66), Vector2(19, -38), Vector2(14, 0), Vector2(2, -12), Vector2(-2, -12)], coat)
	draw_polyline(PackedVector2Array([Vector2(-15, -66), Vector2(-19, -38), Vector2(-14, 0)]), rim, 1.5 / k, true)
	draw_polyline(PackedVector2Array([Vector2(15, -66), Vector2(19, -38), Vector2(14, 0)]), rim, 1.5 / k, true)
	var head := Vector2(0, -76)
	_ellipse(head, 8.5, 10.0, Color(0.01, 0.01, 0.02) if hollow else coat.lightened(0.08), 14)
	if cap:
		_poly([Vector2(-11, -81), Vector2(-9, -94), Vector2(9, -94), Vector2(11, -81)], coat.lightened(0.05))
		draw_rect(Rect2(-11, -84, 22, 3.5), Color(BRASS, 0.8))
		draw_line(Vector2(-11, -81), Vector2(14, -81), Color(0.02, 0.02, 0.03), 2.5 / k)
	if hollow:
		for sx in [-3.5, 3.5]:
			draw_circle(Vector2(sx, -77), 1.3, Color(PALE, 0.7))
	draw_set_transform(Vector2.ZERO)


# --- 0: boarding -------------------------------------------------------------------------

func _draw_boarding(win: Rect2) -> void:
	var horizon := win.position.y + win.size.y * 0.56
	_gradient(Rect2(win.position.x, win.position.y, win.size.x, horizon - win.position.y), Color(0.05, 0.06, 0.15), Color(0.50, 0.28, 0.24))
	_halo(Vector2(win.size.x * 0.34, horizon), 360.0, Color(1.0, 0.58, 0.32), 0.012, 0.35) # the last of the sun
	# A ragged skyline of far roofs and chimneys, from the noise table.
	var roofs := PackedVector2Array([Vector2(0, horizon)])
	for i in 24:
		var x := win.size.x * i / 23.0
		roofs.append(Vector2(x, horizon - 8.0 - 38.0 * _noise[i] * (1.0 if i % 3 != 0 else 1.7)))
	roofs.append(Vector2(win.size.x, horizon))
	_poly(roofs, Color(0.05, 0.04, 0.07))
	# Platform: planks running toward the horizon, a pale edge line.
	_gradient(Rect2(win.position.x, horizon, win.size.x, win.end.y - horizon), Color(0.09, 0.07, 0.08), Color(0.03, 0.025, 0.035))
	for i in 12:
		var x := win.size.x * (i / 11.0)
		draw_line(Vector2(win.size.x * 0.5 + (x - win.size.x * 0.5) * 0.15, horizon), Vector2(x * 1.4 - win.size.x * 0.2, win.end.y), Color(NIGHT, 0.7), 1.0)
	draw_line(Vector2(0, horizon + 1.0), Vector2(win.size.x, horizon + 1.0), Color(1.0, 0.7, 0.45, 0.25), 1.0)
	# The train at the right: a carriage with lit windows and an open door spilling light.
	var car := Rect2(win.size.x * 0.72, win.position.y + win.size.y * 0.16, win.size.x * 0.34, horizon - win.position.y - win.size.y * 0.16 + 46.0)
	draw_rect(car, Color(0.065, 0.07, 0.09))
	draw_rect(Rect2(car.position.x, car.position.y, car.size.x, 6.0), Color(BRASS, 0.3))
	for i in 3:
		draw_rect(Rect2(car.position.x + 150.0 + i * 52.0, car.position.y + 40.0, 36.0, 44.0), Color(AMBER, 0.28 + 0.2 * flicker(i)))
	var door := Rect2(car.position.x + 28.0, car.position.y + 26.0, 74.0, car.size.y - 26.0)
	var glow := flicker(5)
	draw_rect(door, Color(1.0, 0.82, 0.5, 0.42 + 0.2 * glow))
	_poly([Vector2(door.position.x, door.end.y), Vector2(door.end.x, door.end.y), Vector2(door.end.x - 150.0, win.end.y), Vector2(door.position.x - 190.0, win.end.y)], Color(AMBER, 0.07 * glow))
	draw_rect(Rect2(door.position.x - 8.0, door.position.y, 8.0, door.size.y), Color(0.04, 0.04, 0.06)) # the slid-back door leaf
	draw_rect(Rect2(door.end.x, door.position.y, 8.0, door.size.y), Color(0.04, 0.04, 0.06))
	draw_rect(Rect2(door.position.x - 6.0, door.end.y, door.size.x + 12.0, 6.0), Color(0.12, 0.1, 0.1)) # step
	# Lamp posts on the platform.
	for i in 2:
		var x := win.size.x * (0.08 + 0.2 * i)
		var top := Vector2(x, win.position.y + win.size.y * (0.2 + 0.1 * i))
		draw_line(Vector2(x, horizon + 30.0), top, Color(0.03, 0.03, 0.05), 4.0)
		_halo(top, 130.0, AMBER, 0.02 * flicker(i))
		draw_circle(top, 6.0, Color(1.0, 0.9, 0.6, 0.6 + 0.4 * flicker(i)))
	# Steam creeping along the platform from the train.
	for i in 4:
		var t := fposmod(time * 0.03 + i * 0.25, 1.0)
		_ellipse(Vector2(win.size.x * (1.0 - t * 0.8), horizon + 22.0 + i * 8.0), 70.0 + 40.0 * t, 8.0, Color(PALE, 0.06 * (1.0 - t)), 16)


# --- 1: the conductor --------------------------------------------------------------------

func _draw_conductor(win: Rect2) -> void:
	var vp := Vector2(win.size.x * 0.5, win.position.y + win.size.y * 0.42)
	_draw_tunnel(win, vp, 0.04, Color(AMBER, 0.6), 0.5)
	_halo(vp, 280.0, AMBER, 0.012, 0.8)
	# Rows of seat backs along both sides, bigger toward the viewer.
	for side in [-1.0, 1.0]:
		for r in 4:
			var s := pow((r + 1) / 4.0, 1.8)
			var wd := lerpf(24.0, 90.0, s)
			var ht := lerpf(36.0, 170.0, s)
			var x: float = win.size.x * 0.5 + side * lerpf(win.size.x * 0.17, win.size.x * 0.46, s)
			var floor_y := vp.y + lerpf(60.0, win.size.y * 0.5, s)
			draw_rect(Rect2(x - wd * 0.5, floor_y - ht, wd, ht), Color(0.075, 0.05, 0.05, 0.95))
			draw_rect(Rect2(x - wd * 0.5, floor_y - ht, wd, 4.0 + 3.0 * s), Color(AMBER, 0.12))
	_draw_lantern(Vector2(win.size.x * 0.2, win.position.y), 40.0, 1, 0.8, 0.8)
	_draw_lantern(Vector2(win.size.x * 0.8, win.position.y), 40.0, 2, 0.8, 0.8)
	_draw_conductor_figure(win)


## The Conductor (also drawn over the painted carriage) in his own pool of light, baton swinging time,
## with drifting tickets.
func _draw_conductor_figure(win: Rect2) -> void:
	var feet := Vector2(win.size.x * 0.83, win.end.y - 18.0)
	_halo(feet + Vector2(0, -90), 190.0, AMBER, 0.02 * flicker(2), 0.8)
	# The same figure as his enemy portrait, mirrored to face the card and raised to the aisle's scale.
	var k := CONDUCTOR_HEIGHT / ConductorFigure.HEIGHT
	draw_set_transform(feet, 0.0, Vector2(-k, k))
	ConductorFigure.draw(self, time, flicker(2))
	draw_set_transform(Vector2.ZERO)
	for i in 5:
		var t := fposmod(time * 0.05 + i * 0.2, 1.0)
		var p := Vector2(win.size.x * (0.72 + 0.2 * _noise[i]) + sin(time + i) * 10.0, win.end.y - 40.0 - t * win.size.y * 0.7)
		draw_rect(Rect2(p, Vector2(9, 5)), Color(PALE, 0.35 * sin(t * PI)))


# --- 2: the empty platform ---------------------------------------------------------------

func _draw_platform(win: Rect2) -> void:
	var horizon := win.position.y + win.size.y * 0.6
	_gradient(Rect2(win.position.x, win.position.y, win.size.x, horizon - win.position.y), Color(0.02, 0.025, 0.05), Color(0.06, 0.07, 0.11))
	_gradient(Rect2(win.position.x, horizon, win.size.x, win.end.y - horizon), Color(0.07, 0.07, 0.09), Color(0.025, 0.025, 0.035))
	draw_line(Vector2(0, horizon), Vector2(win.size.x, horizon), Color(PALE, 0.12), 1.0)
	# Rails and sleepers along the bottom, past the platform edge.
	var rail := win.end.y - 26.0
	draw_line(Vector2(0, rail), Vector2(win.size.x, rail), Color(STEEL, 0.7), 3.0)
	draw_line(Vector2(0, rail + 14.0), Vector2(win.size.x, rail + 14.0), Color(STEEL, 0.5), 3.0)
	# The one lamp, its cone of light on the ground.
	var lamp := Vector2(win.size.x * 0.2, win.position.y + 30.0)
	var level := flicker(0)
	draw_line(Vector2(lamp.x, horizon + 40.0), lamp, Color(0.03, 0.03, 0.04), 5.0)
	_poly([lamp, Vector2(lamp.x - 190.0, horizon + 60.0), Vector2(lamp.x + 190.0, horizon + 60.0)], Color(AMBER, 0.045 * level))
	_halo(lamp, 220.0, AMBER, 0.022 * level)
	draw_circle(lamp, 7.0, Color(1.0, 0.92, 0.65, 0.6 + 0.4 * level))
	# Still shapes waiting under it: hollow coats with no faces, hardly breathing.
	for i in 5:
		var x := lamp.x - 120.0 + i * 62.0 + _noise[i] * 12.0
		var near := 1.0 - clampf(absf(x - lamp.x) / 220.0, 0.0, 1.0)
		var breathe := sin(time * 0.6 + i * 1.3) * 1.0
		var coat := Color(0.03 + 0.05 * near, 0.03 + 0.05 * near, 0.045 + 0.06 * near)
		_draw_coat_figure(Vector2(x, horizon + 52.0 + breathe), 120.0 + 14.0 * _noise[i + 5], coat, Color(AMBER, 0.35 * near * level), true, i % 2 == 0)
	# A far lamp that stays dark, and a bench nobody sits on.
	var far := Vector2(win.size.x * 0.9, horizon - 70.0)
	draw_line(Vector2(far.x, horizon + 10.0), far, Color(0.04, 0.04, 0.06), 3.0)
	draw_circle(far, 4.0, Color(PALE, 0.07))
	draw_rect(Rect2(win.size.x * 0.76, horizon + 30.0, 90.0, 6.0), Color(0.06, 0.05, 0.05))
	draw_rect(Rect2(win.size.x * 0.76 + 8.0, horizon + 36.0, 5.0, 22.0), Color(0.05, 0.04, 0.045))
	draw_rect(Rect2(win.size.x * 0.76 + 77.0, horizon + 36.0, 5.0, 22.0), Color(0.05, 0.04, 0.045))
	# Low fog sliding along the ground.
	for i in 3:
		var t := fposmod(time * 0.012 + i / 3.0, 1.0)
		_ellipse(Vector2(win.size.x * (t * 1.4 - 0.2), horizon + 44.0 + i * 12.0), 200.0, 14.0, Color(PALE, 0.05), 18)


# --- 3: the last light -------------------------------------------------------------------

func _draw_last_light(win: Rect2) -> void:
	var vp := Vector2(win.size.x * 0.5, win.position.y + win.size.y * 0.17)
	var pulse := 0.5 + 0.5 * sin(time * 0.7)
	_draw_tunnel(win, vp, 0.09, Color(PALE, 0.5), 0.6)
	# The tunnel thins into a pale glow: rays, a wide halo and a bright core that breathes.
	for i in 9:
		var a := -PI + PI * (i + 0.5) / 9.0 + 0.04 * sin(time * 0.4 + i)
		draw_line(vp, vp + Vector2.from_angle(a) * 520.0, Color(PALE, 0.045), 14.0)
	_halo(vp, 560.0, PALE, 0.026 + 0.008 * pulse, 0.85)
	_ellipse(vp, 34.0 + 6.0 * pulse, 42.0 + 6.0 * pulse, Color(0.95, 0.98, 1.0, 0.9), 20)
	_ellipse(vp, 60.0, 72.0, Color(PALE, 0.18), 20)


# --- anything else -----------------------------------------------------------------------

func _draw_generic(win: Rect2) -> void:
	var vp := Vector2(win.size.x * 0.5, win.position.y + win.size.y * 0.45)
	_draw_tunnel(win, vp, 0.03, Color(AMBER, 0.5), 0.4)
	_halo(vp, 240.0, AMBER, 0.01, 0.8)
	_draw_lantern(Vector2(win.size.x * 0.5, win.position.y), 60.0, 0, 1.0, 0.7)
