class_name RestScene
extends ScreenScene
## Quiet carriage behind the rest stop: a hanging lamp, dim windows, a bench with the player's
## class seated on it and a stove with a steaming kettle and rising embers (see
## docs/SCREEN_ART_DESIGN.md). The figure is a seated silhouette tinted with the class palette
## (CardView.PALETTES); an unknown id gets the neutral one.

const WALL := Color(0.075, 0.055, 0.05)
const STEAM_PUFFS := 6
const EMBERS := 12

## A CardView.PALETTES key; anything else (including empty) draws the neutral figure.
var character_id: StringName = &""


func _init() -> void:
	super(2025, 26)


## Breathing of the seated figure in -1..1.
func breath() -> float:
	return sin(time * 0.9)


func _draw_scene(w: float, h: float) -> void:
	var floor_y := h * 0.88
	var stove := Vector2(w * 0.74, floor_y)
	var seat_y := floor_y - 44.0
	if not _draw_painted_bg(&"rest", Rect2(0, 0, w, h), 1.08, 0.4, Color(0.8, 0.8, 0.8)):
		_draw_wall(w, h, floor_y)
		_draw_windows(w, h)
	_halo(Vector2(w * 0.5, 96.0), 330.0, AMBER, 0.012 * flicker(0), 0.8)
	_draw_lantern(Vector2(w * 0.5, 0.0), 82.0, 0, 1.0, 0.5)
	_draw_bench(w * 0.08, w * 0.56, seat_y, floor_y)
	_halo(stove + Vector2(0, -50), 280.0, Color(1.0, 0.55, 0.2), 0.016 * flicker(2), 0.7)
	_draw_figure(Vector2(w * 0.30, seat_y), floor_y)
	_draw_stove(stove)
	_draw_steam(stove + Vector2(-31, -97))
	_draw_embers(stove + Vector2(0, -62))
	_draw_motes(w, h, AMBER, 0.8)
	_draw_scrim(w, h)


func _draw_wall(w: float, h: float, floor_y: float) -> void:
	_gradient(Rect2(0, 0, w, floor_y), Color(WALL.r * 0.5, WALL.g * 0.5, WALL.b * 0.5), WALL)
	var seam := Color(NIGHT, 0.5)
	var x := 0.0
	while x < w:
		draw_line(Vector2(x, 0), Vector2(x, floor_y), seam, 1.0)
		x += 72.0
	draw_line(Vector2(0, floor_y - 150.0), Vector2(w, floor_y - 150.0), Color(BRASS, 0.14), 2.0) # panelling rail
	_gradient(Rect2(0, floor_y, w, h - floor_y), Color(0.09, 0.06, 0.045), Color(0.04, 0.03, 0.03))
	draw_line(Vector2(0, floor_y), Vector2(w, floor_y), Color(AMBER, 0.14), 1.0)
	var y := floor_y + 14.0
	while y < h:
		draw_line(Vector2(0, y), Vector2(w, y), Color(NIGHT, 0.4), 1.0)
		y += 22.0


func _draw_windows(w: float, h: float) -> void:
	# Four small windows on the night outside; a far platform lamp glows in each, a little dimmer.
	for i in 4:
		var x: float = w * [0.07, 0.23, 0.69, 0.85][i]
		var r := Rect2(x, h * 0.10, 110.0, 96.0)
		draw_rect(r, Color(0.02, 0.03, 0.055))
		var glow := 0.5 + 0.5 * wobble(3.0, 20 + i)
		draw_circle(r.position + Vector2(30 + i * 15, 54), 2.5, Color(AMBER, 0.35 + 0.2 * glow))
		draw_line(r.position + Vector2(0, 70), r.end - Vector2(0, 26), Color(PALE, 0.06), 1.0)
		draw_line(r.position + Vector2(55, 0), r.position + Vector2(55, 96), Color(WOOD, 0.8), 3.0)
		draw_rect(r, Color(BRASS.r * 0.5, BRASS.g * 0.5, BRASS.b * 0.5), false, 2.0)
		draw_line(r.position + Vector2(8, 10), r.position + Vector2(40, 4), Color(PALE, 0.07), 1.0) # a hint of frost


func _draw_bench(x0: float, x1: float, seat_y: float, floor_y: float) -> void:
	var light := 0.7 + 0.3 * flicker(2)
	var wood := _lit(WOOD, light)
	draw_rect(Rect2(x0, seat_y - 96.0, x1 - x0, 7.0), wood.darkened(0.25)) # back rail
	for x in [x0 + 12.0, x1 - 20.0]:
		draw_rect(Rect2(x, seat_y - 96.0, 8.0, 96.0), wood.darkened(0.35))
		draw_rect(Rect2(x, seat_y, 8.0, floor_y - seat_y), wood.darkened(0.3))
	draw_rect(Rect2(x0 - 6.0, seat_y, x1 - x0 + 12.0, 9.0), wood)
	draw_line(Vector2(x0 - 6.0, seat_y), Vector2(x1 + 6.0, seat_y), Color(AMBER, 0.3 * light), 1.0)


func _draw_figure(hip: Vector2, floor_y: float) -> void:
	var p: Dictionary = CardView.PALETTES[character_id if CardView.PALETTES.has(character_id) else &""]
	var accent: Color = p.accent
	var cloth: Color = (p.stock as Color).darkened(0.15) if character_id != &"" else Color(0.14, 0.14, 0.16)
	var b := breath() * 1.2
	var warm := Color(1.0, 0.62, 0.3, 0.45 * flicker(2))
	var up := Vector2(0, b * 0.5)
	# Legs: thigh forward along the seat, shin down to the floor; then the torso leaning in.
	var knee := hip + Vector2(46, -4)
	draw_line(hip + Vector2(0, -8), knee + Vector2(0, -8), cloth, 17.0)
	draw_line(knee + Vector2(0, -6), Vector2(knee.x + 4, floor_y - 6.0), cloth, 14.0)
	draw_rect(Rect2(knee.x - 6, floor_y - 8.0, 26, 8), cloth.darkened(0.3)) # a boot
	_poly([hip + Vector2(-16, -2), hip + Vector2(-14, -66) + up, hip + Vector2(4, -72) + up, hip + Vector2(16, -64) + up, hip + Vector2(18, -2)], cloth)
	draw_line(hip + Vector2(10, -60) + up, hip + Vector2(58, -36), cloth.lightened(0.05), 8.0) # arms out to the warmth
	draw_circle(hip + Vector2(60, -35), 4.5, cloth.lightened(0.18))
	var head := hip + Vector2(2, -88) + up
	draw_circle(head, 13.0, cloth.lightened(0.06))
	match character_id:
		&"deserter": # peaked cap and a shoulder strap
			_poly([head + Vector2(-14, -4), head + Vector2(-12, -19), head + Vector2(12, -19), head + Vector2(16, -4)], cloth.lightened(0.1))
			draw_line(head + Vector2(-15, -5), head + Vector2(22, -4), accent.darkened(0.2), 3.0)
			draw_line(hip + Vector2(-12, -62) + up, hip + Vector2(14, -18), cloth.lightened(0.14), 4.0)
		&"pickpocket": # a deep hood
			_poly([head + Vector2(-17, 14), head + Vector2(-16, -8), head + Vector2(-4, -22), head + Vector2(10, -18), head + Vector2(18, 4), head + Vector2(12, 16)], cloth.lightened(0.08))
			draw_circle(head + Vector2(7, 1), 9.0, Color(0.01, 0.03, 0.04))
			draw_circle(head + Vector2(10, -1), 1.2, Color(accent, 0.9))
		&"medium": # long hair and a shawl
			draw_polyline(PackedVector2Array([head + Vector2(-12, -2), head + Vector2(-16, 18), head + Vector2(-20, 34)]), cloth.lightened(0.14), 5.0, true)
			draw_polyline(PackedVector2Array([hip + Vector2(-14, -60) + up, hip + Vector2(4, -30), hip + Vector2(18, -56) + up]), Color(accent, 0.55), 2.0, true)
	# Warm rim light on the side facing the stove.
	draw_arc(head, 13.0, -1.2, 1.2, 10, warm, 1.5, true)
	draw_polyline(PackedVector2Array([hip + Vector2(16, -64) + up, hip + Vector2(18, -2)]), warm, 1.5, true)
	draw_line(hip + Vector2(0, -16), knee + Vector2(0, -16), warm, 1.0)


func _draw_stove(c: Vector2) -> void:
	var glow := flicker(2)
	var iron := Color(0.07, 0.06, 0.065)
	for x in [-26.0, 20.0]:
		draw_rect(Rect2(c + Vector2(x, -16), Vector2(6, 16)), iron) # legs
	draw_rect(Rect2(c + Vector2(-36, -62), Vector2(72, 48)), iron)
	draw_rect(Rect2(c + Vector2(-36, -62), Vector2(72, 48)), Color(BRASS, 0.3), false, 1.5)
	draw_rect(Rect2(c + Vector2(-24, -46), Vector2(48, 22)), Color(1.0, 0.45, 0.12, 0.35 + 0.5 * glow)) # the grate shows the fire
	for i in 3:
		draw_line(c + Vector2(-24 + i * 16, -46), c + Vector2(-24 + i * 16, -24), Color(iron, 0.9), 2.0)
	draw_rect(Rect2(c + Vector2(-40, -68), Vector2(80, 8)), iron.lightened(0.05))
	draw_line(c + Vector2(-40, -68), c + Vector2(40, -68), Color(AMBER, 0.3 * glow), 1.0)
	# The kettle on top: body, lid, spout and a handle.
	var body := c + Vector2(-8, -84)
	_ellipse(body, 22.0, 17.0, iron.lightened(0.08), 18)
	draw_arc(body, 22.0, PI + 0.5, TAU - 0.5, 10, Color(AMBER, 0.28 * glow), 1.5, true)
	draw_rect(Rect2(body + Vector2(-8, -22), Vector2(16, 6)), iron.lightened(0.12))
	_poly([body + Vector2(-18, -4), body + Vector2(-31, -14), body + Vector2(-33, -12), body + Vector2(-19, 6)], iron.lightened(0.08))
	draw_arc(body + Vector2(0, -4), 20.0, PI + 0.3, TAU - 0.3, 10, iron.lightened(0.2), 2.0, true)


func _draw_steam(spout: Vector2) -> void:
	# Soft puffs lifting off the spout, widening and fading as they rise and drift.
	for i in STEAM_PUFFS:
		var t := fposmod(time * 0.22 + i / float(STEAM_PUFFS), 1.0)
		var p := spout + Vector2(sin(time * 0.8 + i * 1.9) * 7.0 * t - 10.0 * t, -t * 80.0)
		_ellipse(p, 4.0 + t * 13.0, 4.0 + t * 11.0, Color(PALE, 0.16 * (1.0 - t)), 12)


func _draw_embers(origin: Vector2) -> void:
	for i in EMBERS:
		var base := i * 5
		var t := fposmod(_motes[base + 1] + time * _motes[base + 2] * 6.0, 1.0)
		var x := origin.x + (_motes[base] - 0.5) * 60.0 + sin(time * 1.3 + _motes[base + 3]) * 8.0 * t
		draw_circle(Vector2(x, origin.y - t * 130.0), _motes[base + 4] * 0.9, Color(1.0, 0.6, 0.2, 0.7 * (1.0 - t)))
