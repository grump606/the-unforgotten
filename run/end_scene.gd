class_name EndScene
extends ScreenScene
## Backdrop of the end card (see docs/SCREEN_ART_DESIGN.md). Escaped: the train slows to a halt
## beside a tunnel mouth that opens on a dawn-pale light. Defeated: the train carries on into the
## dark, its tail lamp shrinking, while a lone platform lamp gutters out.

const DECEL := 0.22 # how quickly the escaping train loses speed
const LAMP_LIFE := 9.0 # seconds the defeat lamp takes to go out
const STEEL := Color(0.16, 0.19, 0.25)

## Picks the variant; may change at any time.
var escaped := true


func _init() -> void:
	super(2041, 24)


## Distance the escaping train has rolled, flattening out as it slows to a stop.
func train_offset() -> float:
	return 520.0 * (1.0 - exp(-time * DECEL))


## 1 while the defeat lamp burns, falling to 0 (with stutters on the way) and staying out.
func lamp_level() -> float:
	var fade := clampf(1.0 - time / LAMP_LIFE, 0.0, 1.0)
	return fade * lerpf(0.55, 1.0, wobble(9.0, 3)) if fade > 0.0 else 0.0


func _draw_scene(w: float, h: float) -> void:
	var painted := _draw_painted_bg(&"end_escape" if escaped else &"end_defeat", Rect2(0, 0, w, h), 1.1, 0.5)
	if painted:
		if not escaped:
			# The lamp going out darkens the picture, as it did the code-drawn scene.
			draw_rect(Rect2(0, 0, w, h), Color(0.01, 0.01, 0.02, 0.55 * (1.0 - lamp_level())))
	elif escaped:
		_draw_escape(w, h)
	else:
		_draw_defeat(w, h)
	_draw_motes(w, h, PALE if escaped else AMBER, 0.6)
	_draw_scrim(w, h, 0.3 if escaped else 0.0)


# --- escaped -------------------------------------------------------------------------------

func _draw_escape(w: float, h: float) -> void:
	var horizon := h * 0.74
	_gradient(Rect2(0, 0, w, horizon), Color(0.20, 0.27, 0.40), Color(0.92, 0.80, 0.72))
	var mouth := Vector2(w * 0.78, horizon)
	_halo(mouth + Vector2(0, -60), 520.0, Color(1.0, 0.93, 0.82), 0.03, 0.55)
	# The tunnel mouth: a rock face with an arched opening full of light, and rays fanning out.
	for i in 7:
		var a := -PI + PI * (i + 0.5) / 7.0
		draw_line(mouth + Vector2(0, -80), mouth + Vector2(0, -80) + Vector2.from_angle(a) * 560.0, Color(1.0, 0.95, 0.85, 0.05), 18.0)
	var rock := PackedVector2Array([Vector2(mouth.x - 430.0, horizon), Vector2(mouth.x - 330.0, horizon - 130.0), Vector2(mouth.x - 190.0, horizon - 215.0), Vector2(mouth.x, horizon - 245.0),
		Vector2(mouth.x + 190.0, horizon - 215.0), Vector2(mouth.x + 330.0, horizon - 130.0), Vector2(mouth.x + 430.0, horizon)])
	draw_colored_polygon(rock, Color(0.09, 0.10, 0.14))
	var arch := PackedVector2Array()
	for i in 17:
		var a := PI + PI * i / 16.0
		arch.append(mouth + Vector2(cos(a) * 150.0, sin(a) * 190.0))
	draw_colored_polygon(arch, Color(1.0, 0.96, 0.88))
	draw_polyline(arch, Color(0.05, 0.05, 0.07), 6.0, true)
	_ellipse(mouth + Vector2(0, -80), 90.0 + 8.0 * sin(time * 0.6), 120.0, Color(1.0, 1.0, 0.97, 0.5), 20)
	# Ground, then the train rolling along the front, slowing to a stop.
	_gradient(Rect2(0, horizon, w, h - horizon), Color(0.14, 0.13, 0.15), Color(0.04, 0.04, 0.06))
	draw_line(Vector2(0, horizon + 22.0), Vector2(w, horizon + 22.0), Color(STEEL, 0.7), 3.0)
	var speed := exp(-time * DECEL)
	var shift := train_offset()
	var floor_y := horizon + 20.0
	for car in 4:
		var x := fposmod(shift + car * 330.0 - 330.0, w + 660.0) - 330.0
		draw_rect(Rect2(x, floor_y - 84.0, 310.0, 80.0), Color(0.07, 0.075, 0.10))
		draw_rect(Rect2(x, floor_y - 84.0, 310.0, 5.0), Color(BRASS, 0.3))
		for i in 4:
			draw_rect(Rect2(x + 22.0 + i * 70.0, floor_y - 66.0, 44.0, 34.0), Color(AMBER, 0.5 + 0.2 * flicker(car + i)))
		draw_rect(Rect2(x, floor_y - 6.0, 310.0, 6.0), Color(0.03, 0.03, 0.04))
	for i in 5: # steam puffing off the roof; thinner as the train stops
		var t := fposmod(time * 0.1 + i * 0.2, 1.0)
		_ellipse(Vector2(w * (0.1 + 0.2 * i) + t * 50.0 * speed, floor_y - 100.0 - t * 70.0), 20.0 + 26.0 * t, 12.0 + 14.0 * t, Color(1.0, 1.0, 1.0, 0.12 * (1.0 - t) * (0.3 + 0.7 * speed)), 14)


# --- defeated ------------------------------------------------------------------------------

func _draw_defeat(w: float, h: float) -> void:
	var vp := Vector2(w * 0.74, h * 0.5)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.015, 0.015, 0.03))
	for i in 8: # ribs of the tunnel streaming past, barely visible
		var t := fposmod(float(i) / 8.0 - time * 0.07, 1.0)
		var half := Vector2(40.0, 55.0).lerp(Vector2(w * 0.7, h * 0.9), t * t)
		draw_rect(Rect2(vp - half, half * 2.0), Color(STEEL, 0.5 * smoothstep(0.0, 0.3, t) * t), false, 1.0 + 3.0 * t * t)
	for side in [-1.0, 1.0]:
		draw_line(vp + Vector2(side * 8.0, 50.0), Vector2(vp.x + side * w * 0.26, h), Color(STEEL, 0.6), 2.0)
	for i in 14: # sleepers sliding toward the viewer
		var t := fposmod(float(i) / 14.0 - time * 0.09, 1.0)
		var y := vp.y + 50.0 + (h - vp.y - 50.0) * t * t
		var half := lerpf(10.0, w * 0.26, t * t)
		draw_line(Vector2(vp.x - half, y), Vector2(vp.x + half, y), Color(STEEL, 0.28 * t), 1.0 + 2.0 * t)
	# The train going away from us: shrinking toward the dark, a tail lamp still showing.
	var shrink := 1.0 / (1.0 + time * 0.12)
	var body := Vector2(150.0, 100.0) * shrink
	var tail := vp + Vector2(0, 52.0 - 52.0 * (1.0 - shrink))
	draw_rect(Rect2(tail - Vector2(body.x * 0.5, body.y), body), Color(0.04, 0.04, 0.06))
	for sx in [-1.0, 1.0]:
		draw_circle(tail + Vector2(sx * body.x * 0.32, -body.y * 0.25), 4.0 * shrink + 1.0, Color(0.85, 0.22, 0.16, 0.85 * lerpf(0.6, 1.0, flicker(1))))
	_halo(tail + Vector2(0, -body.y * 0.25), 60.0 * shrink + 14.0, Color(0.85, 0.22, 0.16), 0.02)
	# The lone lamp on the platform: dims, stutters and goes out, leaving a cooling ember.
	var lamp := Vector2(w * 0.16, h * 0.55)
	var level := lamp_level()
	draw_line(Vector2(lamp.x, h), lamp, Color(0.03, 0.03, 0.05), 5.0)
	draw_line(lamp, lamp + Vector2(18, -6), Color(0.03, 0.03, 0.05), 3.0)
	var head := lamp + Vector2(18, -6)
	if level > 0.0:
		_halo(head, 190.0, AMBER, 0.022 * level, 0.9)
		draw_circle(head, 7.0, Color(1.0, 0.9, 0.6, 0.3 + 0.7 * level))
	else:
		draw_circle(head, 4.0, Color(0.5, 0.2, 0.1, 0.6 * (1.0 - clampf((time - LAMP_LIFE) / 6.0, 0.0, 1.0)) + 0.1))
