class_name VendorScene
extends Control
## Animated stall behind the vendor panel, drawn entirely in code: a ghostly shopkeeper under a
## hood behind a lantern-lit counter in a baggage car, shelves of old luggage, hanging lanterns,
## a till that shows the player's gold and a little prop beside each service button (see
## docs/VENDOR_ART_DESIGN.md). It ignores the mouse, only animates while visible in the tree and
## is driven by advance(delta), so tests can step it.

const NIGHT := Color(0.045, 0.036, 0.04)
const WALL := Color(0.085, 0.06, 0.05)
const WOOD := Color(0.22, 0.13, 0.075)
const WOOD_DARK := Color(0.105, 0.065, 0.045)
const BRASS := Color(0.78, 0.55, 0.24)
const AMBER := Color(1.0, 0.78, 0.42)
const CLOAK := Color(0.035, 0.03, 0.045)
const PALE := Color(0.72, 0.84, 0.95)
const COIN := Color(0.95, 0.76, 0.28)
const LEATHER: Array[Color] = [Color(0.34, 0.20, 0.11), Color(0.25, 0.15, 0.10), Color(0.30, 0.26, 0.16), Color(0.18, 0.14, 0.12)]
## x as a fraction of the width, how far the chain drops, and the size, per hanging lantern.
const LANTERNS: Array[Vector3] = [Vector3(0.20, 100.0, 1.0), Vector3(0.33, 40.0, 0.6), Vector3(0.67, 40.0, 0.6), Vector3(0.80, 100.0, 1.0)]
const SHELF_WIDTH := 176.0
const SHELF_MARGIN := 14.0
const MOTE_COUNT := 36
const NOISE_SIZE := 64
const PULSE_SECONDS := 0.8
const COINS_PER_GOLD := 0.2 # one coin per five gold, at most MAX_COINS
const MAX_COINS := 15

## Seconds of animation so far; only advance() moves it.
var time := 0.0
## The player's gold, shown on the till (see set_gold).
var gold := 0
## Darkens the whole stall, used while a card picker is open over it.
var dimmed := false
## Controls of the vendor panel the art lines up with; all optional (a default layout is used
## without them). The head sits at the centre of the first, the counter edge cuts through the
## second (the row of offers) and each service button gets its prop on its left.
var head_anchor: Control
var counter_anchor: Control
var service_anchors: Array[Control] = []

var _noise: Array[float] = []
## x, y, speed, phase, size per mote, flattened.
var _motes: Array[float] = []
## side, tier, x, width, height, kind, tone per piece of luggage on the shelves, flattened.
var _pieces: Array[float] = []
var _gold_seen := false
var _gold_changed_at := -10.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# A local generator with a fixed seed: the look is repeatable and the run's RNG is untouched.
	var rng := RandomNumberGenerator.new()
	rng.seed = 1913
	for i in NOISE_SIZE:
		_noise.append(rng.randf())
	for i in MOTE_COUNT:
		_motes.append_array([rng.randf(), rng.randf(), rng.randf_range(0.01, 0.035), rng.randf() * TAU, rng.randf_range(0.8, 1.8)])
	for side in 2:
		for tier in 2:
			var x := 0.0
			while true:
				var kind := rng.randi_range(0, 3)
				var wd := rng.randf_range(34.0, 62.0) if kind != 2 else 14.0
				var ht := rng.randf_range(26.0, 46.0) if kind != 2 else rng.randf_range(24.0, 34.0)
				if kind == 1:
					ht = wd * 0.8
				if x + wd > SHELF_WIDTH:
					break
				_pieces.append_array([side, tier, x, wd, ht, kind, rng.randi_range(0, LEATHER.size() - 1)])
				x += wd + rng.randf_range(4.0, 12.0)


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


## Sets the gold on the till. A change after the first call makes the till glow briefly.
func set_gold(value: int) -> void:
	if _gold_seen and value != gold:
		_gold_changed_at = time
	gold = value
	_gold_seen = true
	queue_redraw()


## The number on the till display.
func till_text() -> String:
	return str(gold)


## How many coins are stacked beside the till: one per five gold, rounded up, up to 15.
func coin_count() -> int:
	return clampi(ceili(gold * COINS_PER_GOLD), 0, MAX_COINS)


## 1 right after the gold changes, fading to 0.
func pulse() -> float:
	return clampf(1.0 - (time - _gold_changed_at) / PULSE_SECONDS, 0.0, 1.0)


## Smooth pseudo-random value in 0..1, changing `speed` times a second; `offset` decorrelates users.
func _wobble(speed: float, offset: int) -> float:
	var x := time * speed
	var i := floori(x)
	var a: float = _noise[(i + offset) % NOISE_SIZE]
	var b: float = _noise[(i + 1 + offset) % NOISE_SIZE]
	return lerpf(a, b, smoothstep(0.0, 1.0, x - i))


## Brightness of lantern `k`: a steady glow with a small flicker.
func lantern_level(k: int) -> float:
	return lerpf(0.72, 1.0, _wobble(8.0 + k, k * 13))


## Breathing of the shopkeeper in -1..1.
func breath() -> float:
	return sin(time * 1.1)


## True during the short blink the shopkeeper makes every few seconds.
func blinking() -> bool:
	return fposmod(time + 1.3, 4.7) < 0.14


func _anchor_rect(c: Control) -> Rect2:
	if c == null or not is_instance_valid(c) or not c.is_inside_tree():
		return Rect2()
	return Rect2(c.global_position - global_position, c.size)


## Where the art sits: the head centre, the top edge of the counter and the bottom of its surface.
func _stage() -> Dictionary:
	var head := Vector2(size.x * 0.5, size.y * 0.12)
	var edge := size.y * 0.66
	var base := edge + 106.0
	var head_rect := _anchor_rect(head_anchor)
	if head_rect.size != Vector2.ZERO:
		head = head_rect.get_center()
	var row := _anchor_rect(counter_anchor)
	if row.size != Vector2.ZERO:
		edge = row.position.y + row.size.y * 0.62
		base = row.end.y + 10.0
	return {"head": head, "edge": edge, "base": base}


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 64.0 or h < 64.0:
		return
	var stage := _stage()
	var head: Vector2 = stage["head"]
	var edge: float = stage["edge"]
	var base: float = stage["base"]
	_draw_wall(w, h)
	_draw_glow(head, edge)
	_draw_shelves(w, edge)
	_draw_lanterns(w)
	_draw_shopkeeper(head, edge)
	_draw_counter(w, h, edge, base)
	_draw_till(w * 0.12, base - 10.0)
	_draw_luggage(w * 0.88, base - 12.0)
	_draw_bell(w * 0.78, base - 12.0)
	_draw_service_props()
	_draw_motes(w, h)
	_draw_scrim(w, h)


# --- helpers ---------------------------------------------------------------------------

func _ellipse(c: Vector2, rx: float, ry: float, col: Color, n := 14) -> void:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)


## A colour dimmed to the light it receives, 0..1.
func _lit(c: Color, light: float) -> Color:
	return Color(c.r * light, c.g * light, c.b * light, c.a)


func _draw_wall(w: float, h: float) -> void:
	var painted := PaintedArt.screen_texture(&"vendor")
	if painted != null:
		PaintedArt.draw_cover(self, painted, Rect2(0, 0, w, h), 1.05, Vector2(sin(Time.get_ticks_msec() * 0.0001), 0.0) * 0.3, Color(0.8, 0.8, 0.8))
		return
	# Dark planks, warmer in the middle where the lanterns reach.
	var top := Color(WALL.r * 0.5, WALL.g * 0.5, WALL.b * 0.5)
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]), PackedColorArray([top, top, WALL, WALL]))
	var seam := Color(NIGHT, 0.55)
	var x := 0.0
	while x < w:
		draw_line(Vector2(x, 0), Vector2(x, h), seam, 1.0)
		x += 56.0
	draw_line(Vector2(0, 14), Vector2(w, 14), Color(BRASS, 0.18), 2.0) # the rail the lanterns hang from


func _draw_glow(head: Vector2, edge: float) -> void:
	# The warm pool of light the shopkeeper sits in.
	var level := (lantern_level(1) + lantern_level(2)) * 0.5
	var c := Vector2(head.x, (head.y + edge) * 0.5)
	for i in 10:
		_ellipse(c, 130.0 + i * 36.0, 95.0 + i * 26.0, Color(AMBER, 0.014 * level), 22)


# --- shelves and luggage ---------------------------------------------------------------

func _draw_shelves(w: float, edge: float) -> void:
	for side in 2:
		var x0 := SHELF_MARGIN if side == 0 else w - SHELF_MARGIN - SHELF_WIDTH
		var light := 0.62 + 0.38 * lantern_level(0 if side == 0 else 3)
		for tier in 2:
			var board := edge - 170.0 + tier * 100.0
			draw_rect(Rect2(x0 - 4.0, board, SHELF_WIDTH + 8.0, 5.0), _lit(WOOD, light))
			draw_line(Vector2(x0 - 4.0, board), Vector2(x0 + SHELF_WIDTH + 4.0, board), Color(AMBER, 0.22 * light), 1.0)
			draw_rect(Rect2(x0 + 8.0, board + 5.0, 4.0, 12.0), _lit(WOOD_DARK, light))
			draw_rect(Rect2(x0 + SHELF_WIDTH - 12.0, board + 5.0, 4.0, 12.0), _lit(WOOD_DARK, light))
	for i in range(0, _pieces.size(), 7):
		var side := int(_pieces[i])
		var tier := int(_pieces[i + 1])
		var x := (SHELF_MARGIN if side == 0 else w - SHELF_MARGIN - SHELF_WIDTH) + _pieces[i + 2]
		var light := 0.62 + 0.38 * lantern_level(0 if side == 0 else 3)
		var bottom := edge - 170.0 + tier * 100.0
		_draw_piece(int(_pieces[i + 5]), Vector2(x, bottom), _pieces[i + 3], _pieces[i + 4], LEATHER[int(_pieces[i + 6])], light)


func _draw_piece(kind: int, foot: Vector2, wd: float, ht: float, tone: Color, light: float) -> void:
	var c := _lit(tone, light)
	match kind:
		1: # a hatbox
			var r := Rect2(foot.x, foot.y - ht, wd, ht)
			draw_rect(r, c)
			draw_rect(Rect2(foot.x - 2.0, foot.y - ht, wd + 4.0, 5.0), c.lightened(0.15))
			draw_rect(Rect2(foot.x, foot.y - ht * 0.45, wd, 3.0), _lit(BRASS, light * 0.8))
			draw_rect(r, c.darkened(0.5), false, 1.0)
		2: # a jar with something amber in it
			var r := Rect2(foot.x, foot.y - ht, wd, ht)
			draw_rect(r, Color(PALE, 0.16 * light + 0.04))
			draw_rect(Rect2(foot.x + 1.0, foot.y - ht * 0.6, wd - 2.0, ht * 0.6 - 1.0), Color(AMBER, 0.35 * light))
			draw_rect(Rect2(foot.x + 2.0, foot.y - ht - 4.0, wd - 4.0, 4.0), _lit(WOOD, light))
			draw_rect(r, Color(PALE, 0.3 * light), false, 1.0)
		3: # two cases, one on the other
			_draw_piece(0, foot, wd, ht * 0.55, tone, light)
			_draw_piece(0, foot - Vector2(0, ht * 0.55), wd * 0.78, ht * 0.5, LEATHER[(LEATHER.find(tone) + 1) % LEATHER.size()], light)
		_: # a suitcase: straps, a clasp, a handle
			var r := Rect2(foot.x, foot.y - ht, wd, ht)
			draw_rect(r, c)
			draw_rect(Rect2(foot.x + wd * 0.2, foot.y - ht, 3.0, ht), c.darkened(0.3))
			draw_rect(Rect2(foot.x + wd * 0.75, foot.y - ht, 3.0, ht), c.darkened(0.3))
			draw_rect(Rect2(foot.x + wd * 0.5 - 3.0, foot.y - ht * 0.55, 6.0, 5.0), _lit(BRASS, light))
			draw_rect(Rect2(foot.x + wd * 0.5 - 7.0, foot.y - ht - 4.0, 14.0, 4.0), c.darkened(0.4), false, 1.5)
			draw_line(Vector2(foot.x, foot.y - ht + 1.0), Vector2(foot.x + wd, foot.y - ht + 1.0), Color(AMBER, 0.25 * light), 1.0)
			draw_rect(r, c.darkened(0.5), false, 1.0)


# --- lanterns --------------------------------------------------------------------------

func _draw_lanterns(w: float) -> void:
	for k in LANTERNS.size():
		var spec := LANTERNS[k]
		var level := lantern_level(k)
		var s := spec.z
		var ceiling := Vector2(w * spec.x, 14.0)
		var swing := 0.07 * sin(time * 1.1 + k * 1.7) + 0.02 * sin(time * 3.1 + k)
		var bulb := ceiling + Vector2(sin(swing), cos(swing)) * spec.y
		draw_line(ceiling, bulb - Vector2(0, 14.0 * s), Color(0.02, 0.015, 0.02), 1.5)
		for i in 12: # many faint rings, so the halo fades smoothly instead of banding
			var ring := (18.0 + i * 7.0) * s
			_ellipse(bulb, ring, ring, Color(AMBER, 0.016 * level), 18)
		# The lantern: a cap, a glass body and a foot, with a bright flame inside.
		var hw := 11.0 * s
		var hh := 15.0 * s
		draw_colored_polygon(PackedVector2Array([bulb + Vector2(-hw, -hh * 0.6), bulb + Vector2(0, -hh), bulb + Vector2(hw, -hh * 0.6)]), WOOD_DARK)
		draw_rect(Rect2(bulb + Vector2(-hw, -hh * 0.6), Vector2(hw * 2.0, hh * 1.5)), Color(AMBER, 0.45 + 0.4 * level))
		draw_rect(Rect2(bulb + Vector2(-hw * 0.4, -hh * 0.3), Vector2(hw * 0.8, hh * 0.9)), Color(1.0, 0.95, 0.75, 0.6 + 0.4 * level))
		draw_line(bulb + Vector2(0, -hh * 0.6), bulb + Vector2(0, hh * 0.9), Color(NIGHT, 0.7), 1.0)
		draw_rect(Rect2(bulb + Vector2(-hw, -hh * 0.6), Vector2(hw * 2.0, hh * 1.5)), Color(BRASS.r * 0.6, BRASS.g * 0.6, BRASS.b * 0.6), false, 1.5)
		draw_rect(Rect2(bulb + Vector2(-hw - 2.0, hh * 0.9), Vector2(hw * 2.0 + 4.0, 3.0 * s + 1.0)), WOOD_DARK)


# --- shopkeeper ------------------------------------------------------------------------

func _draw_shopkeeper(c: Vector2, edge: float) -> void:
	var drop := maxf(edge - c.y, 40.0)
	var b := breath() * 2.2
	var level := (lantern_level(1) + lantern_level(2)) * 0.5
	# The cloak, hood to counter, in one outline mirrored about the centre line.
	var half: Array[Vector2] = [
		Vector2(0, -58), Vector2(18, -52), Vector2(32, -34), Vector2(38, -8), Vector2(46, 12),
		Vector2(72, 30), Vector2(120, 46), Vector2(170, 66), Vector2(215, 110), Vector2(250, drop)]
	var pts := PackedVector2Array()
	for p in half:
		pts.append(c + Vector2(p.x, minf(p.y, drop) + (b if p.y > 20.0 else b * 0.4)))
	for i in range(half.size() - 2, 0, -1):
		var p := half[i]
		pts.append(c + Vector2(-p.x, minf(p.y, drop) + (b if p.y > 20.0 else b * 0.4)))
	draw_colored_polygon(pts, CLOAK)
	# Folds and the rim of lantern light along both shoulders.
	var fold := Color(0.075, 0.065, 0.09)
	for x in [-60.0, -20.0, 20.0, 60.0]:
		draw_line(c + Vector2(x, 50.0 + b), c + Vector2(x * 1.9, drop), fold, 2.0)
	var rim := Color(AMBER, 0.38 * level)
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in range(1, 9):
		var p := half[i]
		right.append(c + Vector2(p.x, p.y + (b if p.y > 20.0 else b * 0.4)))
		left.append(c + Vector2(-p.x, p.y + (b if p.y > 20.0 else b * 0.4)))
	draw_polyline(right, rim, 1.5)
	draw_polyline(left, rim, 1.5)
	# The face under the hood: only a dark void, a veil and two eyes.
	var face := c + Vector2(0, -6.0 + b * 0.5)
	_ellipse(face, 23.0, 28.0, Color(0.01, 0.008, 0.012), 18)
	_ellipse(face + Vector2(0, 14.0), 20.0, 13.0, Color(PALE, 0.12), 14)
	draw_line(face + Vector2(-16, 8), face + Vector2(16, 8), Color(PALE, 0.25), 1.0)
	draw_line(face + Vector2(-12, 17), face + Vector2(12, 17), Color(PALE, 0.15), 1.0)
	for sx in [-8.0, 8.0]:
		var eye := face + Vector2(sx, -9.0)
		if blinking():
			draw_line(eye + Vector2(-3, 0), eye + Vector2(3, 0), Color(AMBER, 0.7), 1.5)
		else:
			_ellipse(eye, 7.0, 7.0, Color(AMBER, 0.10), 10)
			_ellipse(eye, 2.8, 2.2, Color(1.0, 0.9, 0.6), 8)


# --- counter, till and props -----------------------------------------------------------

func _draw_counter(w: float, h: float, edge: float, base: float) -> void:
	# The top (seen from slightly above) with the lanterns' light pooled on it, then the front.
	var warm := WOOD
	var far := Color(WOOD.r * 0.7, WOOD.g * 0.7, WOOD.b * 0.7)
	draw_polygon(PackedVector2Array([Vector2(0, edge), Vector2(w, edge), Vector2(w, base), Vector2(0, base)]), PackedColorArray([far, far, warm, warm]))
	for k in LANTERNS.size():
		var level := lantern_level(k)
		_ellipse(Vector2(w * LANTERNS[k].x, (edge + base) * 0.5), 110.0 * LANTERNS[k].z + 30.0, (base - edge) * 0.4, Color(AMBER, 0.07 * level), 18)
	for i in 4:
		var y := edge + (base - edge) * (0.2 + i * 0.2)
		draw_line(Vector2(0, y), Vector2(w, y), Color(NIGHT, 0.22), 1.0)
	draw_line(Vector2(0, edge), Vector2(w, edge), Color(AMBER, 0.55 * lantern_level(1)), 2.0)
	draw_rect(Rect2(0, base, w, h - base), WOOD_DARK)
	draw_rect(Rect2(0, base, w, 4.0), Color(BRASS.r * 0.7, BRASS.g * 0.7, BRASS.b * 0.7))
	draw_line(Vector2(0, base + 5.0), Vector2(w, base + 5.0), Color(AMBER, 0.2), 1.0)
	var x := 0.0
	while x < w:
		draw_line(Vector2(x, base + 6.0), Vector2(x, h), Color(NIGHT, 0.5), 1.0)
		draw_rect(Rect2(x + 10.0, base + 16.0, 124.0, maxf(h - base - 26.0, 0.0)), Color(NIGHT, 0.25), false, 1.0)
		x += 144.0


func _draw_till(cx: float, foot: float) -> void:
	# A brass till whose display reads the player's gold, with its coins stacked alongside.
	var glow := pulse()
	var body := Rect2(cx - 58.0, foot - 66.0, 116.0, 66.0)
	if glow > 0.0:
		_ellipse(body.get_center(), 100.0, 70.0, Color(COIN, 0.16 * glow), 20)
	draw_rect(body, Color(0.30, 0.20, 0.10))
	draw_rect(body, BRASS, false, 2.0)
	draw_rect(Rect2(body.position.x + 8.0, body.position.y + 6.0, 100.0, 28.0), Color(0.02, 0.05, 0.035))
	draw_rect(Rect2(body.position.x + 8.0, body.position.y + 6.0, 100.0, 28.0), Color(BRASS, 0.8), false, 1.0)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(body.position.x + 12.0, body.position.y + 17.0), "GOLD", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(AMBER, 0.75))
	draw_string(font, Vector2(body.position.x + 12.0, body.position.y + 31.0), till_text(), HORIZONTAL_ALIGNMENT_RIGHT, 92.0, 17, Color(1.0, 0.9, 0.55))
	for row in 2:
		for col in 5:
			draw_rect(Rect2(body.position.x + 10.0 + col * 20.0, body.position.y + 40.0 + row * 11.0, 16.0, 8.0), Color(0.16, 0.10, 0.06))
			draw_rect(Rect2(body.position.x + 10.0 + col * 20.0, body.position.y + 40.0 + row * 11.0, 16.0, 1.0), Color(AMBER, 0.4))
	# Coins in stacks of five, nearest the till first.
	var coins := coin_count()
	for i in coins:
		var stack := i / 5
		var layer := i % 5
		var x := cx + 70.0 + stack * 22.0
		var y := foot - 5.0 - layer * 5.0
		draw_rect(Rect2(x, y, 18.0, 4.0), COIN.darkened(0.25))
		draw_rect(Rect2(x, y, 18.0, 2.0), COIN)
		draw_line(Vector2(x, y), Vector2(x + 18.0, y), Color(1.0, 0.95, 0.7, 0.8), 1.0)


func _draw_luggage(cx: float, foot: float) -> void:
	# An old case lying on the counter with a luggage tag that stirs.
	var light := 0.75 + 0.25 * lantern_level(3)
	var r := Rect2(cx - 52.0, foot - 54.0, 104.0, 54.0)
	var c := _lit(LEATHER[0], light)
	draw_rect(r, c)
	draw_rect(r, c.darkened(0.5), false, 1.5)
	draw_rect(Rect2(r.position.x + 22.0, r.position.y, 5.0, r.size.y), c.darkened(0.3))
	draw_rect(Rect2(r.end.x - 27.0, r.position.y, 5.0, r.size.y), c.darkened(0.3))
	draw_rect(Rect2(cx - 5.0, r.position.y + 18.0, 10.0, 8.0), _lit(BRASS, light))
	draw_rect(Rect2(cx - 16.0, r.position.y - 7.0, 32.0, 7.0), c.darkened(0.45), false, 2.0)
	for corner in [r.position, Vector2(r.end.x - 7.0, r.position.y), Vector2(r.position.x, r.end.y - 7.0), r.end - Vector2(7, 7)]:
		draw_rect(Rect2(corner, Vector2(7, 7)), _lit(BRASS, light * 0.85))
	var sway := sin(time * 1.6) * 2.0
	var tag := Vector2(r.end.x - 14.0, r.position.y + 6.0)
	draw_line(tag, tag + Vector2(8.0 + sway, 14.0), Color(PALE, 0.5), 1.0)
	draw_colored_polygon(PackedVector2Array([tag + Vector2(4 + sway, 14), tag + Vector2(16 + sway, 14), tag + Vector2(16 + sway, 30), tag + Vector2(8 + sway, 34), tag + Vector2(2 + sway, 30)]), Color(0.78, 0.7, 0.5, 0.9))


func _draw_bell(cx: float, foot: float) -> void:
	# A brass service bell beside the case.
	var light := 0.75 + 0.25 * lantern_level(2)
	var brass := _lit(BRASS, light)
	draw_rect(Rect2(cx - 16.0, foot - 5.0, 32.0, 5.0), brass.darkened(0.4))
	var dome := PackedVector2Array()
	for i in 11:
		var a := PI * i / 10.0
		dome.append(Vector2(cx - cos(a) * 15.0, foot - 5.0 - sin(a) * 17.0))
	draw_colored_polygon(dome, brass)
	draw_circle(Vector2(cx, foot - 25.0), 2.5, brass.lightened(0.3))
	draw_line(Vector2(cx - 8.0, foot - 12.0), Vector2(cx - 4.0, foot - 19.0), Color(1.0, 0.9, 0.6, 0.5), 1.5)


func _draw_service_props() -> void:
	# One prop to the left of each service button: a ticket-punch, a medicine bottle, a small case.
	for i in service_anchors.size():
		var r := _anchor_rect(service_anchors[i])
		if r.size == Vector2.ZERO:
			continue
		var dim := 0.4 if (service_anchors[i] is BaseButton and (service_anchors[i] as BaseButton).disabled) else 1.0
		var c := Vector2(r.position.x - 26.0, r.get_center().y)
		match i:
			0:
				_draw_punch(c, dim)
			1:
				_draw_bottle(c, dim)
			_:
				_draw_case(c, dim)


func _draw_punch(c: Vector2, dim: float) -> void:
	var brass := Color(BRASS, dim)
	draw_line(c + Vector2(-13, 9), c + Vector2(12, -2), Color(brass, dim), 5.0) # lower jaw
	draw_line(c + Vector2(-13, 2), c + Vector2(12, -9), brass.lightened(0.15), 5.0) # upper jaw
	draw_circle(c + Vector2(12, -9), 2.0, Color(NIGHT, dim))
	draw_arc(c + Vector2(-14, 8), 5.0, 0.0, TAU, 12, Color(brass, dim), 2.0) # the ring handle
	draw_rect(Rect2(c + Vector2(4, 4), Vector2(14, 9)), Color(PALE, 0.85 * dim)) # a punched ticket
	draw_circle(c + Vector2(11, 8.5), 2.0, Color(NIGHT, dim))


func _draw_bottle(c: Vector2, dim: float) -> void:
	var glow := 0.65 + 0.35 * sin(time * 2.0)
	draw_rect(Rect2(c + Vector2(-8, -4), Vector2(16, 17)), Color(0.55, 0.85, 0.7, 0.28 * dim))
	draw_rect(Rect2(c + Vector2(-7, 2), Vector2(14, 10)), Color(0.45, 0.95, 0.65, (0.45 + 0.3 * glow) * dim))
	draw_rect(Rect2(c + Vector2(-3, -11), Vector2(6, 8)), Color(PALE, 0.4 * dim))
	draw_rect(Rect2(c + Vector2(-4, -14), Vector2(8, 4)), Color(0.45, 0.3, 0.18, dim))
	draw_rect(Rect2(c + Vector2(-8, -4), Vector2(16, 17)), Color(PALE, 0.5 * dim), false, 1.0)
	draw_line(c + Vector2(0, 4), c + Vector2(0, 10), Color(1, 1, 1, 0.8 * dim), 1.5) # a plus on the label
	draw_line(c + Vector2(-3, 7), c + Vector2(3, 7), Color(1, 1, 1, 0.8 * dim), 1.5)


func _draw_case(c: Vector2, dim: float) -> void:
	var tone := LEATHER[2]
	draw_rect(Rect2(c + Vector2(-13, -6), Vector2(26, 18)), Color(tone, dim))
	draw_rect(Rect2(c + Vector2(-13, -6), Vector2(26, 18)), Color(tone.darkened(0.5), dim), false, 1.0)
	draw_rect(Rect2(c + Vector2(-5, -10), Vector2(10, 4)), Color(tone.darkened(0.4), dim), false, 1.5)
	draw_rect(Rect2(c + Vector2(-3, 0), Vector2(6, 4)), Color(BRASS, dim))


# --- air -------------------------------------------------------------------------------

func _draw_motes(w: float, h: float) -> void:
	# Dust in the lamplight, drifting up; positions are pure functions of time.
	for i in MOTE_COUNT:
		var base := i * 5
		var y := fposmod(_motes[base + 1] - time * _motes[base + 2], 1.0)
		var x := _motes[base] + 0.015 * sin(time * 0.5 + _motes[base + 3])
		var twinkle := 0.5 + 0.5 * sin(time * 1.3 + _motes[base + 3])
		draw_circle(Vector2(fposmod(x, 1.0) * w, y * h), _motes[base + 4], Color(AMBER, 0.08 + 0.17 * twinkle))


func _draw_scrim(w: float, h: float) -> void:
	# Keeps the art subordinate: a darker top, darker sides, and more dimming when asked.
	var dark := Color(0.01, 0.008, 0.012, 0.6)
	var clear := Color(dark, 0.0)
	var edge := w * 0.1
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(edge, 0), Vector2(edge, h), Vector2(0, h)]), PackedColorArray([dark, clear, clear, dark]))
	draw_polygon(PackedVector2Array([Vector2(w - edge, 0), Vector2(w, 0), Vector2(w, h), Vector2(w - edge, h)]), PackedColorArray([clear, dark, dark, clear]))
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, 50), Vector2(0, 50)]), PackedColorArray([dark, dark, clear, clear]))
	if dimmed:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.008, 0.012, 0.6))
