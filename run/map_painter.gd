class_name MapPainter
extends RefCounted
## Draws a MapView, split out of MapView so that script keeps the data, layout, input and pulse clock: the dimmed
## backdrop, the header strip (district, "Row 7/15", the status line), the inked edges, the node discs with their
## glyphs, elite flames, ticks and enemy pips, the legend and the hover bubble. It only reads the view (its layout,
## palette and `time` included) and draws onto it during its _draw.

var _v: MapView


func _init(view: MapView) -> void:
	_v = view


## The whole map; the view has laid itself out first.
func draw() -> void:
	var size := _v.size
	var rect := Rect2(Vector2.ZERO, size)
	_v.draw_rect(rect, MapView.INK)
	var tex := PaintedArt.screen_texture(MapView.BACKDROP_SCREEN)
	if tex != null:
		PaintedArt.draw_cover(_v, tex, rect, 1.0, Vector2.ZERO, MapView.BACKDROP_TINT)
	_v.draw_rect(rect, Color(0.03, 0.04, 0.06, 0.55))
	_draw_header()
	if _v._route == null or _v._ids.is_empty():
		_text("The road is blank.", size * 0.5 - Vector2(70, 0) * _v._scale, int(18 * _v._scale), MapView.BONE_DIM)
		return
	for id in _v._ids:
		for to in _v._route.node(id).next:
			if _v._pos.has(to):
				_draw_edge(id, to)
	# The hovered node is drawn last so it sits on top (no per-frame copy and sort).
	var hover := _v._hover
	for id in _v._ids:
		if id != hover:
			_draw_node(id)
	if _v._ids.has(hover):
		_draw_node(hover)
	_draw_legend()
	if hover >= 0 and _v._pos.has(hover):
		_draw_bubble(hover)


func _pulse() -> float:
	return 0.5 + 0.5 * sin(_v.time * 3.2)


func _font() -> Font:
	return MenuStyle.serif_font()


func _text(text: String, at: Vector2, font_size: int, color: Color, width := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var font := _font()
	_v.draw_string(font, at + Vector2(0, 1.5), text, align, width, font_size, Color(0.02, 0.03, 0.05, 0.9))
	_v.draw_string(font, at, text, align, width, font_size, color)


func _draw_header() -> void:
	var s := _v._scale
	var size := _v.size
	var strip := Rect2(0, 0, size.x, 64.0 * s)
	_v.draw_rect(strip, Color(0.04, 0.05, 0.08, 0.72))
	_v.draw_line(Vector2(0, strip.size.y), Vector2(size.x, strip.size.y), Color(MapView.BRASS, 0.7), 2.0)
	var title := MapView.district_name(_v._act, _v.chapter)
	_text(title, Vector2(28.0 * s, 42.0 * s), int(30 * s), Color("#d7d0bc"))
	var title_w := _font().get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, int(30 * s)).x
	_text(_v.progress_text(), Vector2(28.0 * s + title_w + 18.0 * s, 41.0 * s), int(17 * s), MapView.BONE_DIM)
	if _v._status != "":
		_text(_v._status, Vector2(0, 40.0 * s), int(15 * s), MapView.BONE, size.x - 28.0 * s, HORIZONTAL_ALIGNMENT_RIGHT)


func _edge_points(a: int, b: int) -> PackedVector2Array:
	var p0: Vector2 = _v._pos[a]
	var p1: Vector2 = _v._pos[b]
	var dir := (p1 - p0).normalized()
	p0 += dir * (_v._radius[a] + 2.0 * _v._scale)
	p1 -= dir * (_v._radius[b] + 2.0 * _v._scale)
	var bow := _v._hash(a * 131 + b) * 7.0 * _v._scale
	var ctrl := (p0 + p1) * 0.5 + Vector2(-dir.y, dir.x) * bow
	var pts := PackedVector2Array()
	for i in 11:
		var t := i / 10.0
		pts.append(p0.lerp(ctrl, t).lerp(ctrl.lerp(p1, t), t))
	return pts


func _draw_edge(a: int, b: int) -> void:
	var pts := _edge_points(a, b)
	var s := _v._scale
	if _v._taken.has(Vector2i(a, b)):
		_v.draw_polyline(pts, Color(0.0, 0.0, 0.0, 0.55), 6.0 * s, true)
		_v.draw_polyline(pts, MapView.EDGE_TAKEN, 3.0 * s, true)
	elif a == _v._current and _v._reachable.has(b):
		var glow := 0.65 + 0.35 * _pulse()
		_v.draw_polyline(pts, Color(0.0, 0.0, 0.0, 0.55), 6.0 * s, true)
		_v.draw_polyline(pts, Color(MapView.AMBER, glow), 3.0 * s, true)
	else:
		var faint := MapView.EDGE_FAINT
		if _v._visited.has(a) or a == _v._current:
			faint.a = 0.16 # a road not taken
		_v.draw_polyline(pts, Color(0, 0, 0, 0.35), 4.0 * s, true)
		_v.draw_polyline(pts, faint, 2.0 * s, true)


func _draw_node(id: int) -> void:
	var n := _v._route.node(id)
	var state := _v.state_of(id)
	var r: float = _v._radius[id]
	var c: Vector2 = _v._pos[id]
	var s := _v._scale
	var hovered := id == _v._hover
	var chosen := (state == MapView.REACHABLE and hovered)
	if chosen:
		r *= 1.12
	var alpha := 1.0
	var k := 1.0
	var rim := Color(MapView.BRASS, 0.75)
	match state:
		MapView.VISITED:
			alpha = 0.55
			k = 0.7
			rim = Color(MapView.BRASS, 0.5)
		MapView.FUTURE:
			alpha = 0.8
			k = 0.82
			rim = Color("#526979")
		MapView.REACHABLE:
			rim = MapView.AMBER
		MapView.CURRENT:
			rim = Color("#fff1c9")
	var pulse := _pulse()
	if state == MapView.REACHABLE:
		_v.draw_circle(c, r + (5.0 + 3.0 * pulse) * s, Color(MapView.AMBER, 0.10 + 0.12 * pulse))
		_v.draw_circle(c, r + 2.5 * s, Color(MapView.AMBER, 0.14))
	elif state == MapView.CURRENT:
		_v.draw_circle(c, r + 7.0 * s, Color("#fff1c9", 0.12 + 0.06 * pulse))
	if n.type == RouteMap.NodeType.ELITE:
		_ring_flames(c, r, alpha, k)
	_v.draw_circle(c + Vector2(0, 2.5 * s), r + 1.0, Color(0, 0, 0, 0.5 * alpha))
	_v.draw_circle(c, r, Color(MapView.DISC, MapView.DISC.a * alpha))
	_v.draw_arc(c, r, 0.0, TAU, 48, Color(rim, rim.a * alpha), 2.6 * s, true)
	_v.draw_arc(c, r - 3.4 * s, 0.0, TAU, 40, Color(rim, 0.22 * alpha), 1.0, true)
	if state == MapView.CURRENT:
		_v.draw_arc(c, r + 3.6 * s, 0.0, TAU, 48, Color("#fff1c9", 0.55 + 0.3 * pulse), 1.8 * s, true)
	if _v.has_focus() and id == _v._selected and state == MapView.REACHABLE:
		_v.draw_arc(c, r + 9.0 * s, 0.0, TAU, 48, MapView.BONE, 1.6 * s, true)
	var col := _v._glyph_color(n.type)
	col = Color(col.r * k, col.g * k, col.b * k, alpha)
	_draw_glyph(n.type, c, r * 0.66, col)
	if state == MapView.VISITED:
		_draw_tick(c + Vector2(r * 0.62, -r * 0.62), r * 0.3)
	if n.type == RouteMap.NodeType.FIGHT or n.type == RouteMap.NodeType.ELITE:
		var count := clampi(n.enemy_count, 1, Combat.MAX_ENEMIES)
		var gap := 9.0 * s
		var y := c.y + r + 8.0 * s
		for i in count:
			var px := c.x + (i - (count - 1) * 0.5) * gap
			_v.draw_circle(Vector2(px, y), 3.7 * s, Color(0, 0, 0, 0.7 * alpha))
			_v.draw_circle(Vector2(px, y), 3.0 * s, Color(MapView.BONE.r * k, MapView.BONE.g * k, MapView.BONE.b * k, alpha))
	elif _v.boss_name(n.type) != "":
		_text(_v.boss_name(n.type), Vector2(c.x - 70.0 * s, c.y + r + 17.0 * s), int(13 * s), Color(MapView.BONE, alpha), 140.0 * s, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_tick(at: Vector2, g: float) -> void:
	_v.draw_circle(at, g * 1.25, Color(0.03, 0.04, 0.06, 0.9))
	var pts := PackedVector2Array([at + Vector2(-g * 0.7, 0.0), at + Vector2(-g * 0.2, g * 0.55), at + Vector2(g * 0.75, -g * 0.55)])
	_v.draw_polyline(pts, Color(MapView.EDGE_TAKEN, 0.9), maxf(1.6, g * 0.4), true)


func _draw_glyph(type: RouteMap.NodeType, c: Vector2, g: float, col: Color) -> void:
	match type:
		RouteMap.NodeType.FIGHT:
			_glyph_blades(c, g, col)
		RouteMap.NodeType.ELITE:
			_glyph_blades(c, g, col) # an elite's flames burn on the node's rim, see _ring_flames
		RouteMap.NodeType.REST:
			_glyph_armchair(c, g, col)
		RouteMap.NodeType.SHOP:
			_glyph_coin(c, g, col)
		RouteMap.NodeType.STORY:
			_glyph_book(c, g, col)
		RouteMap.NodeType.MID_BOSS:
			_glyph_bell(c, g, col)
		RouteMap.NodeType.BOSS:
			_glyph_eye(c, g, col)
		RouteMap.NodeType.TREASURE:
			_glyph_chest(c, g, col)
		RouteMap.NodeType.EVENT:
			_glyph_question(c, g, col)


func _glyph_blades(c: Vector2, g: float, col: Color) -> void:
	var w := maxf(2.0, g * 0.22)
	for m in [-1.0, 1.0]:
		var hilt := c + Vector2(-m * g, g)
		var tip := c + Vector2(m * g, -g)
		_v.draw_line(hilt, tip, col, w, true)
		var guard_at := hilt.lerp(tip, 0.3)
		var perp := Vector2(m, 1.0).normalized() * g * 0.38
		_v.draw_line(guard_at - perp, guard_at + perp, col, w * 0.8, true)
		_v.draw_circle(hilt, w * 0.85, col)


## An elite's flames: tongues around the outside of a node's ring (centre `c`, ring radius `r`), an orange outer flame with a
## pale yellow core, swaying and flickering with the view's `time` (still under reduced motion, where `time` stops). The ones
## on top are the tallest and the ones underneath stay low, clear of the enemy pips. Drawn before the disc, which hides their bases.
func _ring_flames(c: Vector2, r: float, alpha: float, k: float) -> void:
	var time := _v.time
	var outer := Color("#ff5a1a")
	var core := Color("#ffe58a")
	outer = Color(outer.r * k, outer.g * k, outer.b * k, alpha)
	core = Color(core.r * k, core.g * k, core.b * k, alpha)
	var count := 12
	for i in count:
		var angle := TAU * float(i) / count - PI * 0.5 # from the top, clockwise
		var dir := Vector2.from_angle(angle)
		var tangent := Vector2(-dir.y, dir.x)
		var up := clampf(0.5 + 0.5 * -dir.y, 0.0, 1.0)
		var flicker := 1.0 + 0.18 * sin(time * 8.0 + i * 2.3)
		var sway := 0.22 * r * sin(time * 5.0 + i * 1.7)
		var h := r * (0.3 + 0.55 * up) * flicker
		var half := r * 0.2
		for layer in 2:
			var kk := 1.0 if layer == 0 else 0.55
			var base := c + dir * (r - 2.0)
			var pts := PackedVector2Array([
				base - tangent * half * kk,
				base + dir * h * 0.5 * kk - tangent * half * 0.85 * kk + tangent * sway * 0.4,
				base + dir * h * kk + tangent * sway * kk,
				base + dir * h * 0.5 * kk + tangent * half * 0.85 * kk + tangent * sway * 0.4,
				base + tangent * half * kk,
			])
			_v.draw_colored_polygon(pts, outer if layer == 0 else core)


func _glyph_coin(c: Vector2, g: float, col: Color) -> void:
	var dark := Color(col.r * 0.35, col.g * 0.3, col.b * 0.15, col.a)
	_v.draw_circle(c, g * 0.95, col)
	_v.draw_arc(c, g * 0.68, 0.0, TAU, 28, dark, maxf(1.5, g * 0.14), true)
	_v.draw_line(c + Vector2(0, -g * 0.36), c + Vector2(0, g * 0.36), dark, maxf(2.0, g * 0.2), true)
	_v.draw_line(c + Vector2(-g * 0.2, -g * 0.12), c + Vector2(g * 0.2, -g * 0.12), dark, maxf(1.5, g * 0.14), true)


func _glyph_book(c: Vector2, g: float, col: Color) -> void:
	var dark := Color(col.r * 0.3, col.g * 0.35, col.b * 0.4, col.a)
	for m in [-1.0, 1.0]:
		var page := _scaled([Vector2(m * 0.06, -0.38), Vector2(m * 0.5, -0.7), Vector2(m * 1.0, -0.52), Vector2(m * 1.0, 0.6), Vector2(m * 0.5, 0.78), Vector2(m * 0.06, 0.55)], c, g)
		if m < 0.0:
			page.reverse() # keep the winding the same on both sides
		_v.draw_colored_polygon(page, col)
		for i in 3:
			var y := -0.3 + i * 0.3
			_v.draw_line(c + Vector2(m * 0.2, y + 0.03) * g, c + Vector2(m * 0.82, y - 0.02) * g, dark, maxf(1.2, g * 0.09), true)
	_v.draw_line(c + Vector2(0, -0.4) * g, c + Vector2(0, 0.58) * g, dark, maxf(1.5, g * 0.12), true)


func _glyph_bell(c: Vector2, g: float, col: Color) -> void:
	var pts: Array[Vector2] = [Vector2(-0.98, 0.62), Vector2(-0.72, 0.4), Vector2(-0.56, -0.05)]
	for i in 9:
		var a := PI + PI * i / 8.0
		pts.append(Vector2(cos(a) * 0.56, -0.2 + sin(a) * 0.68))
	pts.append_array([Vector2(0.56, -0.05), Vector2(0.72, 0.4), Vector2(0.98, 0.62)])
	_v.draw_colored_polygon(_scaled(pts, c, g), col)
	_v.draw_circle(c + Vector2(0, 0.86) * g, g * 0.17, col)
	_v.draw_arc(c + Vector2(0, -0.92) * g, g * 0.17, 0.0, TAU, 12, col, maxf(1.5, g * 0.12), true)
	var dark := Color(col.r * 0.4, col.g * 0.35, col.b * 0.2, col.a)
	_v.draw_line(c + Vector2(-0.4, 0.2) * g, c + Vector2(-0.3, -0.3) * g, dark, maxf(1.5, g * 0.1), true)


func _glyph_eye(c: Vector2, g: float, col: Color) -> void:
	var lens: Array[Vector2] = []
	for i in 13:
		var x := -1.15 + 2.3 * i / 12.0
		lens.append(Vector2(x, -0.62 * (1.0 - pow(x / 1.15, 2.0))))
	for i in range(11, 0, -1):
		var x := -1.15 + 2.3 * i / 12.0
		lens.append(Vector2(x, 0.62 * (1.0 - pow(x / 1.15, 2.0))))
	var poly := _scaled(lens, c, g)
	_v.draw_colored_polygon(poly, Color(col.r * 0.9, col.g * 0.85, col.b * 0.8, col.a))
	_v.draw_polyline(poly + PackedVector2Array([poly[0]]), Color(1.0, 0.9, 0.8, col.a), maxf(1.5, g * 0.1), true)
	_v.draw_circle(c, g * 0.46, Color(0.55, 0.12, 0.12, col.a))
	_v.draw_line(c + Vector2(0, -0.46) * g, c + Vector2(0, 0.46) * g, Color(0.04, 0.02, 0.03, col.a), maxf(2.0, g * 0.16), true)
	_v.draw_line(c + Vector2(-0.95, 0.85) * g, c + Vector2(0.95, -0.85) * g, Color(0.04, 0.02, 0.03, col.a * 0.9), maxf(2.0, g * 0.14), true)


## A high-backed armchair seen from the front: arched back, two armrests, a cushion and short legs.
func _glyph_armchair(c: Vector2, g: float, col: Color) -> void:
	var w := maxf(2.0, g * 0.2)
	var cream := Color(minf(col.r * 1.12, 1.0), minf(col.g * 1.12, 1.0), minf(col.b * 1.2, 1.0), col.a)
	var dark := Color(col.r * 0.35, col.g * 0.3, col.b * 0.2, col.a)
	for x in [-0.72, 0.72]:
		_v.draw_line(c + Vector2(x, 0.6) * g, c + Vector2(x, 1.0) * g, col, w, true)
	var back: Array[Vector2] = [Vector2(-0.52, 0.45), Vector2(-0.58, -0.55)]
	for i in 9:
		var a := PI + PI * i / 8.0
		back.append(Vector2(cos(a) * 0.58, -0.55 + sin(a) * 0.5))
	back.append_array([Vector2(0.58, -0.55), Vector2(0.52, 0.45)])
	_v.draw_colored_polygon(_scaled(back, c, g), col)
	_v.draw_arc(c + Vector2(0.0, -0.55) * g, g * 0.34, PI * 1.05, PI * 1.95, 8, dark, maxf(1.4, g * 0.1), true)
	for m in [-1.0, 1.0]:
		var arm := _scaled([Vector2(m * 0.45, -0.05), Vector2(m * 0.82, -0.12), Vector2(m * 1.04, 0.0), Vector2(m * 1.04, 0.66), Vector2(m * 0.45, 0.66)], c, g)
		if m < 0.0:
			arm.reverse()
		_v.draw_colored_polygon(arm, col)
		_v.draw_line(c + Vector2(m * 0.48, 0.04) * g, c + Vector2(m * 0.48, 0.64) * g, dark, maxf(1.4, g * 0.1), true)
	var seat := _scaled([Vector2(-0.5, 0.18), Vector2(0.5, 0.18), Vector2(0.56, 0.58), Vector2(-0.56, 0.58)], c, g)
	_v.draw_colored_polygon(seat, cream)


## A treasure chest: a domed lid on a box, two straps and a lock plate. A wide dome-on-box silhouette, unlike the
## round coin and the high-backed armchair.
func _glyph_chest(c: Vector2, g: float, col: Color) -> void:
	var dark := Color(col.r * 0.32, col.g * 0.26, col.b * 0.14, col.a)
	var cream := Color(minf(col.r * 1.1, 1.0), minf(col.g * 1.1, 1.0), minf(col.b * 1.25, 1.0), col.a)
	var hinge_y := -0.02
	var shape: Array[Vector2] = [Vector2(-1.04, 0.84), Vector2(-1.04, hinge_y)]
	for i in 11:
		var a := PI + PI * i / 10.0
		shape.append(Vector2(cos(a) * 1.04, hinge_y + sin(a) * 0.82))
	shape.append_array([Vector2(1.04, hinge_y), Vector2(1.04, 0.84)])
	_v.draw_colored_polygon(_scaled(shape, c, g), col)
	var w := maxf(1.5, g * 0.13)
	_v.draw_line(c + Vector2(-1.04, hinge_y) * g, c + Vector2(1.04, hinge_y) * g, dark, w, true)
	for x in [-0.62, 0.62]:
		var top := hinge_y - 0.82 * sqrt(maxf(1.0 - pow(x / 1.04, 2.0), 0.0))
		_v.draw_line(c + Vector2(x, top) * g, c + Vector2(x, 0.84) * g, dark, w, true)
	_v.draw_line(c + Vector2(-1.04, 0.84) * g, c + Vector2(1.04, 0.84) * g, dark, w, true)
	var plate := _scaled([Vector2(-0.24, -0.14), Vector2(0.24, -0.14), Vector2(0.24, 0.3), Vector2(-0.24, 0.3)], c, g)
	_v.draw_colored_polygon(plate, cream)
	_v.draw_circle(c + Vector2(0, 0.06) * g, g * 0.07, dark)
	_v.draw_line(c + Vector2(0, 0.06) * g, c + Vector2(0, 0.2) * g, dark, maxf(1.2, g * 0.08), true)


## An event: a question mark inside a tilted violet diamond (a tall hooked line and a dot, unlike the wide chest, the
## round coin and the high-backed armchair). The mark keeps `col`; the diamond and the dot take their own accent
## colours at the same brightness and opacity as the rest of the node.
func _glyph_question(c: Vector2, g: float, col: Color) -> void:
	var w := maxf(2.6, g * 0.34)
	var cream := MapView.EVENT_CREAM
	var shade := Color(col.r / cream.r, col.g / cream.g, col.b / cream.b, col.a)
	var violet := Color(MapView.EVENT_VIOLET.r * minf(shade.r, 1.0), MapView.EVENT_VIOLET.g * minf(shade.g, 1.0), MapView.EVENT_VIOLET.b * minf(shade.b, 1.0), col.a)
	var teal := Color(MapView.EVENT_TEAL.r * minf(shade.r, 1.0), MapView.EVENT_TEAL.g * minf(shade.g, 1.0), MapView.EVENT_TEAL.b * minf(shade.b, 1.0), col.a)
	var diamond := _scaled([Vector2(0, -1.12), Vector2(1.12, 0), Vector2(0, 1.12), Vector2(-1.12, 0), Vector2(0, -1.12)], c, g)
	_v.draw_polyline(diamond, Color(violet, violet.a * 0.95), maxf(1.8, g * 0.17), true)
	var hook := c + Vector2(0.0, -0.38) * g
	_v.draw_arc(hook, g * 0.5, PI * 0.92, PI * 2.45, 18, col, w, true)
	_v.draw_line(c + Vector2(0.08, 0.1) * g, c + Vector2(0.0, 0.36) * g, col, w, true)
	_v.draw_circle(c + Vector2(0.0, 0.76) * g, g * 0.2, teal)


func _scaled(points: Array, c: Vector2, g: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(c + (p as Vector2) * g)
	return out


## The key along the bottom: one entry per node type the act shows (in MapView.LEGEND order), then the enemy pips.
func _draw_legend() -> void:
	var s := _v._scale
	var size := _v.size
	var present := {}
	for id in _v._ids:
		present[_v._route.node(id).type] = true
	var items: Array = []
	for pair in MapView.LEGEND:
		if present.has(pair[0]):
			items.append(pair)
	var fs := int(13 * s)
	var gw := 22.0 * s
	var widths: Array[float] = []
	var total := 0.0
	for it in items:
		var w := gw + _font().get_string_size(it[1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 26.0 * s
		widths.append(w)
		total += w
	var pips_w := 70.0 * s + _font().get_string_size("enemies", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	total += pips_w
	var y := size.y - 28.0 * s
	_v.draw_rect(Rect2(0, y - 24.0 * s, size.x, 52.0 * s), Color(0.04, 0.05, 0.08, 0.62))
	var x := (size.x - total) * 0.5
	for i in items.size():
		var type: RouteMap.NodeType = items[i][0]
		var col := _v._glyph_color(type)
		if type == RouteMap.NodeType.ELITE:
			_ring_flames(Vector2(x + gw * 0.5, y - 3.0 * s), 7.5 * s, 1.0, 1.0)
		_draw_glyph(type, Vector2(x + gw * 0.5, y - 3.0 * s), 7.5 * s, Color(col, 0.9))
		_text(items[i][1], Vector2(x + gw + (6.0 if type == RouteMap.NodeType.ELITE else 2.0) * s, y + 1.0 * s), fs, MapView.BONE_DIM)
		x += widths[i]
	for i in 3:
		_v.draw_circle(Vector2(x + (6.0 + i * 8.0) * s, y - 3.0 * s), 2.3 * s, MapView.BONE_DIM)
	_text("enemies", Vector2(x + 36.0 * s, y + 1.0 * s), fs, MapView.BONE_DIM)


func _draw_bubble(id: int) -> void:
	var s := _v._scale
	var text := _v.tooltip_for(id)
	if text == "":
		return
	var fs := int(15 * s)
	var tw := _font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var box := Vector2(tw + 22.0 * s, 28.0 * s)
	var c: Vector2 = _v._pos[id]
	var r: float = _v._radius[id]
	var at := Vector2(c.x - box.x * 0.5, c.y - r - box.y - 12.0 * s)
	if at.y < 70.0 * s:
		at.y = c.y + r + 22.0 * s
	at.x = clampf(at.x, 6.0 * s, _v.size.x - box.x - 6.0 * s)
	_v.draw_rect(Rect2(at + Vector2(2, 3) * s, box), Color(0, 0, 0, 0.45))
	_v.draw_rect(Rect2(at, box), Color(0.05, 0.065, 0.09, 0.96))
	_v.draw_rect(Rect2(at, box), MapView.BRASS, false, 1.8 * s)
	_text(text, at + Vector2(0, box.y * 0.5 + fs * 0.35), fs, MapView.BONE, box.x, HORIZONTAL_ALIGNMENT_CENTER)
