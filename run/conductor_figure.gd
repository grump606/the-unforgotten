class_name ConductorFigure
extends RefCounted
## The Conductor drawn as a standalone figure, shared by his old enemy portrait and the
## story scene so he looks like the same character everywhere (see docs/STAGE_DESIGN.md).
## Pure drawing: every call takes the CanvasItem to draw on, the animation time and the glow level.

const BODY := Color(0.24, 0.13, 0.19)
const GLOW := Color(0.95, 0.30, 0.30)
## Height of the figure, cap to boots, in its own units.
const HEIGHT := 70.0


## Draws the figure with its feet at the CanvasItem's current origin, facing right, up being
## negative y, about HEIGHT units tall. Callers scale it with draw_set_transform. `glow_level`
## (0.6..1) lights the eyes and baton tip; `phase` offsets the baton swing.
static func draw(ci: CanvasItem, time: float, glow_level: float, phase := 0.0, body := BODY, glow := GLOW) -> void:
	var g := glow_level
	var gold := Color(0.92, 0.74, 0.32)
	var dark := body.darkened(0.35)
	var wave := sin(time * 1.5 + phase)
	# Baton raised in one hand, swinging time.
	var hand := Vector2(21, -38)
	var tip := hand + Vector2(14 + wave * 3.0, -26)
	_poly(ci, [Vector2(13, -44), Vector2(21, -38), Vector2(17, -30), Vector2(10, -34)], body)
	ci.draw_line(hand, tip, Color(0.92, 0.9, 0.85), 2.0)
	ci.draw_circle(tip, 2.2, Color(glow, g))
	# Long coat with split tails and crimson lapels, a skeletal face under a peaked cap.
	_poly(ci, [Vector2(-8, -3), Vector2(-17, -33), Vector2(-13, -50), Vector2(13, -50), Vector2(17, -33), Vector2(10, -3), Vector2(2, -14), Vector2(-2, -14)], body)
	_poly(ci, [Vector2(-13, -50), Vector2(-3, -50), Vector2(0, -30), Vector2(-9, -34)], Color(0.55, 0.08, 0.14))
	_poly(ci, [Vector2(13, -50), Vector2(3, -50), Vector2(0, -30), Vector2(9, -34)], Color(0.55, 0.08, 0.14))
	_poly(ci, [Vector2(-10, 0), Vector2(-8, -3), Vector2(-2, -14), Vector2(-4, 0)], dark)
	_poly(ci, [Vector2(10, 0), Vector2(10, -3), Vector2(2, -14), Vector2(5, 0)], dark)
	for y in [-26.0, -21.0, -16.0]:
		ci.draw_circle(Vector2(0, y), 1.5, gold)
	# Pocket watch on a swag of chain.
	ci.draw_polyline(PackedVector2Array([Vector2(-10, -34), Vector2(-6, -28), Vector2(0, -27)]), Color(gold, 0.9), 1.0, true)
	_ball(ci, Vector2(0, -26), 3.6, gold)
	_ellipse(ci, Vector2(0, -55), 6.0, 7.0, Color(0.82, 0.80, 0.78))
	_poly(ci, [Vector2(-9, -58), Vector2(-8, -69), Vector2(8, -69), Vector2(9, -58)], dark.darkened(0.1))
	ci.draw_rect(Rect2(-9, -61, 18, 2.5), gold)
	_poly(ci, [Vector2(-9, -58), Vector2(12, -58), Vector2(9, -61), Vector2(-9, -61)], Color(0.1, 0.06, 0.09))
	for side in [-1.0, 1.0]:
		ci.draw_circle(Vector2(side * 2.6, -55), 1.8, Color(0.05, 0.02, 0.04))
		_eye(ci, Vector2(side * 2.6, -55), 0.9, glow, g)
	ci.draw_line(Vector2(-2.5, -50), Vector2(2.5, -50), Color(0.1, 0.05, 0.08), 1.2)


static func _poly(ci: CanvasItem, points: Array, col: Color) -> void:
	var pts := PackedVector2Array(points)
	if Geometry2D.triangulate_polygon(pts).is_empty():
		return
	ci.draw_colored_polygon(pts, col)
	var closed := pts.duplicate()
	closed.append(pts[0])
	ci.draw_polyline(closed, Color(0, 0, 0, 0.6), 1.2, true)


static func _ball(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	ci.draw_circle(c, r, col)
	ci.draw_arc(c, r, 0, TAU, 20, Color(0, 0, 0, 0.6), 1.2, true)


static func _eye(ci: CanvasItem, c: Vector2, r: float, glow: Color, g: float) -> void:
	ci.draw_circle(c, r * 2.2, Color(glow, 0.22 * g))
	ci.draw_circle(c, r, Color(glow, g))


static func _ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	ci.draw_colored_polygon(pts, col)
