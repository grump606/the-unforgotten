class_name EnemyView
extends Control
## An enemy shown as a bordered panel with a code-drawn portrait (see docs/ENEMY_ART_DESIGN.md):
## name banner, portrait window, status chips, HP bar, Block chip and the intent for its next
## turn. One layout for every enemy; the enemy's name picks the silhouette and the boss gets a
## grander frame. Idle animation only runs while visible, and only through advance(delta), so
## tests can step it deterministically (no global RNG, no wall clock).

## Height of the portrait window; the rows below it move down by PORTRAIT_EXTRA (it was 66 px).
const PORTRAIT_H := 96.0
const PORTRAIT_EXTRA := PORTRAIT_H - 66.0
const BASE := Vector2(220, 164 + PORTRAIT_EXTRA)
const BOSS_BASE := Vector2(300, 164 + PORTRAIT_EXTRA)
## Room above the frame for the target marker.
const MARKER := 9.0
const FLASH_TIME := 0.35
const LUNGE_TIME := 0.5
const FADE_TIME := 0.6
const NOISE_SIZE := 64

## Palette tokens: sooty oxblood and soot grey for everyone, tarnished silver and crimson for the boss.
const PALETTES := {
	&"": {
		"frame": Color(0.52, 0.20, 0.17), "fill": Color(0.15, 0.12, 0.13), "banner": Color(0.33, 0.13, 0.12),
		"banner_ink": Color(0.96, 0.92, 0.88), "ink": Color(0.93, 0.90, 0.88), "window": Color(0.07, 0.06, 0.08),
		"accent": Color(0.84, 0.38, 0.28),
	},
	&"boss": {
		"frame": Color(0.66, 0.67, 0.73), "fill": Color(0.09, 0.07, 0.10), "banner": Color(0.46, 0.08, 0.13),
		"banner_ink": Color(1.0, 0.95, 0.90), "ink": Color(0.96, 0.93, 0.92), "window": Color(0.05, 0.04, 0.07),
		"accent": Color(0.90, 0.20, 0.25),
	},
	## The mid-boss: soot-black oxblood with a brass frame instead of the Conductor's silver.
	&"midboss": {
		"frame": Color(0.78, 0.56, 0.24), "fill": Color(0.11, 0.06, 0.06), "banner": Color(0.38, 0.09, 0.07),
		"banner_ink": Color(1.0, 0.94, 0.84), "ink": Color(0.96, 0.92, 0.88), "window": Color(0.06, 0.04, 0.04),
		"accent": Color(0.92, 0.50, 0.18),
	},
}
const HP_BACK := Color(0.12, 0.05, 0.06)
## Enemy name -> silhouette. Any other name draws the generic ghost.
const ART_KEYS := {
	"Gate Warden": &"warden", "Lost Shade": &"shade", "Skittering Wisp": &"wisp", "Hollow Colossus": &"colossus",
	"Pale Whisperer": &"whisperer", "Cinder Hound": &"hound", "Mourning Crow": &"crow", "The Conductor": &"conductor",
	"The Brakeman": &"brakeman",
}
## Silhouettes that get the wide boss panel and a grander frame (each with its own palette).
const BOSS_KEYS: Array[StringName] = [&"conductor", &"brakeman"]
## Scale that keeps the tallest silhouettes inside the portrait window.
const PORTRAIT_FIT := {&"brakeman": 0.78, &"conductor": 0.88, &"colossus": 0.92, &"whisperer": 0.88, &"warden": 0.95, &"hound": 1.25, &"crow": 1.05, &"shade": 1.08, &"wisp": 1.05}
## Silhouette colour and the glow of eyes, embers and flames.
const ART_COLORS := {
	&"warden": [Color(0.34, 0.33, 0.37), Color(1.0, 0.72, 0.30)],
	&"shade": [Color(0.46, 0.52, 0.64), Color(0.78, 0.92, 1.0)],
	&"wisp": [Color(0.95, 0.55, 0.22), Color(1.0, 0.92, 0.62)],
	&"colossus": [Color(0.36, 0.32, 0.30), Color(0.95, 0.32, 0.20)],
	&"whisperer": [Color(0.80, 0.78, 0.80), Color(0.78, 0.70, 1.0)],
	&"hound": [Color(0.22, 0.17, 0.17), Color(1.0, 0.45, 0.15)],
	&"crow": [Color(0.17, 0.17, 0.24), Color(0.98, 0.86, 0.40)],
	&"conductor": [ConductorFigure.BODY, ConductorFigure.GLOW],
	&"brakeman": [Color(0.34, 0.15, 0.13), Color(1.0, 0.62, 0.22)],
	&"ghost": [Color(0.58, 0.60, 0.68), Color(0.85, 0.90, 1.0)],
}

## Emitted when the panel is clicked while the enemy is alive.
signal pressed

var unit: EnemyUnit
## Silhouette key for the current enemy (see ART_KEYS).
var art_key: StringName = &"ghost"
var is_boss := false
var targeted := false
## Seconds of animation so far; only advance() moves it.
var time := 0.0
## Offsets the idle animation so enemies of one type do not breathe in step.
var phase := 0.0
## 0 while alive, 1 once the defeated fade has finished.
var fade := 0.0

var _flash := 0.0
var _lunge := 0.0
var _last_hp := 0
var _hovered := false
var _noise: Array[float] = []
var _font: Font = ThemeDB.fallback_font


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP # also needed for the status tooltip
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# A local generator with a fixed seed: the look is repeatable and the run's RNG is untouched.
	var rng := RandomNumberGenerator.new()
	rng.seed = 606
	for i in NOISE_SIZE:
		_noise.append(rng.randf())
	custom_minimum_size = BASE


func _ready() -> void:
	visibility_changed.connect(_on_visibility_changed)
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))
	_on_visibility_changed()


func _on_visibility_changed() -> void:
	set_process(is_visible_in_tree()) # no cost while hidden


func _process(delta: float) -> void:
	advance(delta)


## Shows `new_unit` from scratch: picks its art and snaps every animation to its resting state.
func set_enemy(new_unit: EnemyUnit) -> void:
	unit = new_unit
	art_key = art_key_for(new_unit.display_name if new_unit != null else "")
	is_boss = BOSS_KEYS.has(art_key)
	custom_minimum_size = BOSS_BASE if is_boss else BASE
	size = custom_minimum_size
	_last_hp = new_unit.hp if new_unit != null else 0
	_flash = 0.0
	_lunge = 0.0
	fade = 1.0 if is_defeated() else 0.0
	_apply_fade()
	queue_redraw()


## Reads the unit's current state: starts a hit flash when HP dropped.
func refresh() -> void:
	if unit == null:
		return
	if unit.hp < _last_hp:
		_flash = 1.0
	_last_hp = unit.hp
	queue_redraw()


func set_targeted(value: bool) -> void:
	targeted = value
	queue_redraw()


## A short lunge toward the player, for when the enemy acts.
func play_attack() -> void:
	_lunge = 1.0


func is_defeated() -> bool:
	return unit != null and unit.is_dead()


## Steps the animation. Does nothing unless the view is on screen.
func advance(delta: float) -> void:
	if not is_visible_in_tree():
		return
	time += delta
	_flash = maxf(_flash - delta / FLASH_TIME, 0.0)
	_lunge = maxf(_lunge - delta / LUNGE_TIME, 0.0)
	fade = move_toward(fade, 1.0 if is_defeated() else 0.0, delta / FADE_TIME)
	_apply_fade()
	queue_redraw()


func _apply_fade() -> void:
	self_modulate = Color(lerpf(1.0, 0.6, fade), lerpf(1.0, 0.6, fade), lerpf(1.0, 0.6, fade), lerpf(1.0, 0.6, fade))


## Smooth pseudo-random value in 0..1, changing `speed` times a second.
func _wobble(speed: float, offset: int) -> float:
	var x := time * speed
	var i := floori(x)
	var a: float = _noise[(i + offset) % NOISE_SIZE]
	var b: float = _noise[(i + 1 + offset) % NOISE_SIZE]
	return lerpf(a, b, smoothstep(0.0, 1.0, x - i))


## Breathing, -1..1.
func breath() -> float:
	return sin(time * 1.7 + phase)


## Brightness of eyes, embers and flames, 0.6..1.
func glow_level() -> float:
	return lerpf(0.6, 1.0, _wobble(9.0, int(phase * 10.0) % NOISE_SIZE))


## The silhouette key for an enemy name; unknown names get the generic ghost.
static func art_key_for(enemy_name: String) -> StringName:
	return ART_KEYS.get(enemy_name, &"ghost")


## Every EnemyView at or under `node`, in tree order (lets the battle screen and tests find them).
static func find_all(node: Node) -> Array[EnemyView]:
	var out: Array[EnemyView] = []
	if node is EnemyView:
		out.append(node)
	for child in node.get_children():
		out.append_array(find_all(child))
	return out


## The statuses shown as chips, in display order: {kind, value, text, color}. Hold and Thorns count too.
func status_chips() -> Array[Dictionary]:
	var chips: Array[Dictionary] = []
	if unit == null:
		return chips
	var exposed := unit.status_turns(Combatant.Status.EXPOSED)
	if exposed > 0:
		chips.append({"kind": &"exposed", "value": exposed, "text": "Exposed %d" % exposed, "color": CardView.kind_color(CardEffect.Kind.EXPOSE)})
	var haunted := unit.status_turns(Combatant.Status.HAUNTED)
	if haunted > 0:
		chips.append({"kind": &"haunt", "value": haunted, "text": "Haunt %d" % haunted, "color": CardView.kind_color(CardEffect.Kind.HAUNT)})
	if unit.hold > 0:
		chips.append({"kind": &"hold", "value": unit.hold, "text": "Hold %d" % unit.hold, "color": CardView.kind_color(CardEffect.Kind.HOLD)})
	if unit.thorns > 0:
		chips.append({"kind": &"thorns", "value": unit.thorns, "text": "Thorns %d" % unit.thorns, "color": CardView.kind_color(CardEffect.Kind.THORNS)})
	return chips


## Like a Button, a click counts when the mouse is released over a living enemy.
func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.button_index == MOUSE_BUTTON_LEFT and not click.pressed and unit != null and not unit.is_dead() and Rect2(Vector2.ZERO, size).has_point(click.position):
		accept_event()
		pressed.emit()


func _on_hover(inside: bool) -> void:
	_hovered = inside
	queue_redraw()


# --- drawing ---------------------------------------------------------------------------

func _draw() -> void:
	if unit == null:
		return
	var p: Dictionary = PALETTES[(&"midboss" if art_key == &"brakeman" else &"boss") if is_boss else &""].duplicate()
	var dead := unit.is_dead()
	var w := BOSS_BASE.x if is_boss else BASE.x
	var frame: Color = p.frame
	if _hovered and not dead:
		frame = frame.lightened(0.15)
	var ink: Color = p.ink
	var rect := Rect2(0, MARKER, w, BASE.y - MARKER)

	if targeted and not dead:
		_box(rect.grow(3), Color(0, 0, 0, 0), 11, 3, CardView.SELECT_GOLD)
		draw_colored_polygon(PackedVector2Array([Vector2(w / 2.0 - 9, 0), Vector2(w / 2.0 + 9, 0), Vector2(w / 2.0, 8)]), CardView.SELECT_GOLD)
	_box(rect, frame, 8)
	_box(rect.grow(-3), p.fill, 6)
	if is_boss:
		_draw_boss_frame(rect, p)

	# Name banner; a long name shrinks (down to 8 px) to fit.
	var banner := Rect2(7, MARKER + 5, w - 14, 18)
	_box(banner, p.banner, 3)
	var shown := unit.display_name
	_text(shown, banner, _fit_size(shown, banner.size.x - 24, 13, 8), p.banner_ink, true)
	if is_boss:
		for x in [banner.position.x + 8, banner.end.x - 8]:
			_diamond(Vector2(x, banner.get_center().y), 3.5, Color(frame, 0.9))

	_draw_window(window_rect(), p, dead)
	_draw_chips()

	# HP bar on the left, Block chip on the right.
	var row_y := MARKER + 97 + PORTRAIT_EXTRA
	var bar := Rect2(8, row_y, w - 16 - 80, 16)
	_box(bar, HP_BACK, 4, 1, Color(frame, 0.8))
	var ratio := clampf(float(unit.hp) / maxf(float(unit.max_hp), 1.0), 0.0, 1.0)
	if ratio > 0.0:
		_box(Rect2(bar.position + Vector2(1, 1), Vector2(maxf((bar.size.x - 2) * ratio, 4.0), bar.size.y - 2)), CardView.HP_RED, 3)
	_text("HP %d/%d" % [maxi(unit.hp, 0), unit.max_hp], bar, 11, Color.WHITE, true)
	_draw_block_chip(Rect2(bar.end.x + 4, row_y, 76, 16), p)

	# Intent strip.
	var strip := Rect2(8, MARKER + 117 + PORTRAIT_EXTRA, w - 16, 31)
	_draw_intent(strip, p, dead)
	if dead:
		draw_set_transform(Vector2(w / 2.0, MARKER + 60 + PORTRAIT_EXTRA * 0.5), -0.12, Vector2.ONE)
		var stamp := Rect2(-52, -12, 104, 24)
		_box(stamp, Color(0.05, 0.04, 0.06, 0.8), 4, 2, Color(ink, 0.85))
		_text("DEFEATED", stamp, 14, ink, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_boss_frame(rect: Rect2, p: Dictionary) -> void:
	var accent: Color = p.accent
	var frame: Color = p.frame
	# A second, thin crimson line inside the silver, and studs on the corners.
	_box(rect.grow(-5), Color(0, 0, 0, 0), 4, 1, Color(accent, 0.7))
	for pt in [rect.position + Vector2(5, 5), Vector2(rect.end.x - 5, rect.position.y + 5), Vector2(rect.position.x + 5, rect.end.y - 5), rect.end - Vector2(5, 5)]:
		_diamond(pt, 4.0, frame)


func _diamond(c: Vector2, r: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)]), col)


func _box(rect: Rect2, fill: Color, radius: int, border := 0, border_color := Color.WHITE) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(border)
	sb.border_color = border_color
	sb.anti_aliasing = true
	draw_style_box(sb, rect)


## Text inside a rectangle: centered both ways when `centered`, else left aligned and vertically centered.
func _text(txt: String, rect: Rect2, font_size: int, col: Color, centered := false) -> void:
	var y := rect.position.y + rect.size.y / 2.0 + (_font.get_ascent(font_size) - _font.get_descent(font_size)) / 2.0
	var align := HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	draw_string(_font, Vector2(rect.position.x, y), txt, align, rect.size.x, font_size, col)


## Largest font size from max_size down to min_size at which txt fits in `width` (min_size if none).
func _fit_size(txt: String, width: float, max_size: int, min_size: int) -> int:
	var s := max_size
	while s > min_size and _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x > width:
		s -= 1
	return s


# --- window, chips, intent --------------------------------------------------------------

func _draw_window(win: Rect2, p: Dictionary, dead: bool) -> void:
	var accent: Color = p.accent
	var frame: Color = p.frame
	_box(win, p.window, 4, 1, Color(frame, 0.8))
	var layers := PaintedArt.enemy_layers(art_key)
	if not layers.is_empty():
		_draw_painted_portrait(layers, win, frame)
		if _flash > 0.0:
			_box(win, Color(1, 1, 1, _flash * 0.4), 4)
		if dead:
			_box(win, Color(0, 0, 0, 0.45), 4)
		return
	var cx := win.get_center().x
	var ground := win.end.y - 6.0
	# Tunnel ribs, a darker floor with two rails and sleepers.
	for r in [50.0, 80.0, 110.0] if is_boss else [38.0, 58.0]:
		_clipped_arc(Vector2(cx, ground + 20.0), r, win, Color(accent, 0.10))
	draw_rect(Rect2(win.position.x + 1, ground, win.size.x - 2, win.end.y - ground - 1), Color(0, 0, 0, 0.35))
	draw_line(Vector2(win.position.x + 2, ground + 2), Vector2(win.end.x - 2, ground + 2), Color(accent, 0.25), 1.0)
	draw_line(Vector2(win.position.x + 2, ground + 5), Vector2(win.end.x - 2, ground + 5), Color(accent, 0.25), 1.0)
	if is_boss:
		# Passengers that never got off, faint behind the Conductor; dead signal posts behind the Brakeman.
		for side in [-1.0, 1.0]:
			if art_key == &"brakeman":
				draw_line(Vector2(cx + side * 100.0, ground), Vector2(cx + side * 100.0, ground - 50.0), Color(accent, 0.18), 3.0)
				draw_circle(Vector2(cx + side * 100.0, ground - 52.0), 4.0, Color(accent, 0.22))
			else:
				_ghost_shape(Vector2(cx + side * 100.0, ground), 0.65, Color(0.6, 0.65, 0.8, 0.16), 0.0)
	var lunge := sin(_lunge * PI)
	var shake := Vector2(sin(time * 70.0) * 2.5 * _flash, 0.0)
	var squash := 1.0 + breath() * 0.025
	var bob := breath() * 1.2
	# Tall figures are scaled to fit the window; breathing squashes the figure about its feet.
	var fit: float = PORTRAIT_FIT.get(art_key, 1.0)
	draw_set_transform(Vector2(cx, ground + bob + lunge * 7.0) + shake, 0.0, Vector2(fit * (1.0 + lunge * 0.05), fit * (squash + lunge * 0.05)))
	_draw_portrait(art_key)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _flash > 0.0:
		_box(win, Color(1, 1, 1, _flash * 0.4), 4)
	if dead:
		_box(win, Color(0, 0, 0, 0.45), 4)


## Painted layers (back to front) cropped to the window's aspect. Each shifts with a slow idle sway by
## its depth, which gives the 2.5D parallax; the figure also takes the breath, lunge and hit shake.
func _draw_painted_portrait(layers: Array, win: Rect2, frame: Color) -> void:
	var inner := win.grow(-1.0)
	# Crop the 960x320 layers to the window's aspect, leaving room for the sway on every side.
	var margin := 16.0
	var aspect := inner.size.x / inner.size.y
	var src_h := 320.0 - margin * 2.0
	var src_w := minf(src_h * aspect, 960.0 - margin * 2.0)
	src_h = src_w / aspect
	var sway := Vector2(sin(time * 0.7), cos(time * 0.5) * 0.5)
	var lunge := sin(_lunge * PI)
	var shake := Vector2(sin(time * 70.0) * 2.5 * _flash, 0.0)
	var bob := breath() * 1.2
	for i in layers.size():
		var tex: Texture2D = layers[i]
		var depth: float = PaintedArt.ENEMY_DEPTHS[i]
		var off := sway * Vector2(14.0, 5.0) * depth
		if PaintedArt.ENEMY_LAYERS[i] == &"figure":
			# Moving the crop (not the rect) keeps the figure inside the window.
			off -= Vector2(shake.x, bob + lunge * 4.0) * (src_w / inner.size.x)
		var region := Rect2((tex.get_width() - src_w) * 0.5 + off.x, (tex.get_height() - src_h) * 0.5 + off.y, src_w, src_h)
		draw_texture_rect_region(tex, inner, region)
	_box(win, Color(0, 0, 0, 0), 4, 1, Color(frame, 0.8))


## The upper half of a circle, drawn only where it lies inside `win`.
func _clipped_arc(c: Vector2, r: float, win: Rect2, col: Color) -> void:
	var inner := win.grow(-2)
	var prev := Vector2.INF
	for i in 61:
		var pt := c + Vector2.from_angle(PI + PI * i / 60.0) * r
		if prev != Vector2.INF and inner.has_point(pt) and inner.has_point(prev):
			draw_line(prev, pt, col, 1.0, true)
		prev = pt


## The portrait window, in this view's coordinates.
func window_rect() -> Rect2:
	var w := BOSS_BASE.x if is_boss else BASE.x
	return Rect2(8, MARKER + 27, w - 16, PORTRAIT_H)


## The middle of the portrait window where the figure stands; status chips never enter it.
func portrait_subject_rect() -> Rect2:
	var win := window_rect()
	var half := 56.0 if is_boss else 52.0
	return Rect2(win.get_center().x - half, win.position.y, half * 2.0, win.size.y)


## True when every chip fits as a full label ("Exposed 2") beside the portrait subject.
func _chips_wide(chips: Array[Dictionary]) -> bool:
	var side := portrait_subject_rect().position.x - window_rect().position.x - 8.0
	for chip in chips:
		if _font.get_string_size(chip.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 20.0 > side:
			return false
	return true


## Where each status chip is drawn, in the order of status_chips(). They sit in two columns along the
## left and right sides of the portrait window (alternating, so at most two per column), beside the
## figure rather than over it. Full labels when they fit, otherwise icon and number only.
func chip_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var chips := status_chips()
	var win := window_rect()
	var wide := _chips_wide(chips)
	var rows: Array[int] = [0, 0]
	for i in chips.size():
		var chip: Dictionary = chips[i]
		var label: String = chip.text if wide else str(chip.value)
		var width := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + (20.0 if wide else 19.0)
		var col_index := i % 2
		var y: float = win.position.y + 4.0 + rows[col_index] * 17.0
		rows[col_index] += 1
		var x := win.position.x + 4.0 if col_index == 0 else win.end.x - 4.0 - width
		rects.append(Rect2(x, y, width, 15))
	return rects


## Status pills beside the portrait (see chip_rects).
func _draw_chips() -> void:
	var chips := status_chips()
	var rects := chip_rects()
	var wide := _chips_wide(chips)
	for i in chips.size():
		var chip: Dictionary = chips[i]
		var r := rects[i]
		var col: Color = chip.color
		_box(r, Color(0.04, 0.03, 0.05, 0.88), 7, 1, col)
		_chip_icon(chip.kind, Vector2(r.position.x + 8, r.position.y + 7.5), col)
		_text(chip.text if wide else str(chip.value), Rect2(r.position.x + 14, r.position.y, r.size.x - 14, 15), 10, Color(0.97, 0.95, 0.92))


func _chip_icon(kind: StringName, c: Vector2, col: Color) -> void:
	match kind:
		&"exposed":
			draw_arc(c, 3.0, 0, TAU, 14, col, 1.2, true)
			for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				draw_line(c + d * 2.0, c + d * 5.0, col, 1.2)
		&"haunt":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-3.5, 4), c + Vector2(-3.5, -1), c + Vector2(0, -4.5), c + Vector2(3.5, -1), c + Vector2(3.5, 4), c + Vector2(1.5, 2.5), c + Vector2(0, 4), c + Vector2(-1.5, 2.5)]), col)
		&"hold":
			draw_rect(Rect2(c + Vector2(-3, -1), Vector2(6, 5)), col)
			draw_arc(c + Vector2(0, -1), 2.2, PI, TAU, 8, col, 1.2, true)
		_:
			var pts := PackedVector2Array()
			for i in 12:
				pts.append(c + Vector2.from_angle(i * TAU / 12.0 - PI / 2.0) * (4.6 if i % 2 == 0 else 2.0))
			draw_colored_polygon(pts, col)


func _draw_block_chip(r: Rect2, p: Dictionary) -> void:
	var col := CardView.kind_color(CardEffect.Kind.BLOCK)
	var has_block := unit.block > 0
	var alpha := 1.0 if has_block else 0.45
	_box(r, Color(col.darkened(0.7), 0.9 if has_block else 0.5), 4, 1, Color(col, alpha))
	_shield_icon(Vector2(r.position.x + 10, r.get_center().y), 5.5, Color(col, alpha))
	_text("Block %d" % unit.block, Rect2(r.position.x + 19, r.position.y, r.size.x - 19, r.size.y), 11, Color(p.ink, alpha))


func _shield_icon(c: Vector2, r: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([c + Vector2(-0.8, -0.85) * r, c + Vector2(0, -1.0) * r, c + Vector2(0.8, -0.85) * r, c + Vector2(0.8, 0.1) * r, c + Vector2(0.45, 0.65) * r, c + Vector2(0, 1.0) * r, c + Vector2(-0.45, 0.65) * r, c + Vector2(-0.8, 0.1) * r]), col)


func _draw_intent(strip: Rect2, p: Dictionary, dead: bool) -> void:
	var intent := unit.current_intent()
	var kind := -1 if intent == null else int(intent.kind)
	var col := Color(0.7, 0.7, 0.75) if kind < 0 else CardView.kind_color(kind)
	if dead:
		col = Color(0.5, 0.5, 0.55)
	_box(strip, Color(0.05, 0.04, 0.06, 0.9), 5, 1, Color(col, 0.8))
	var c := Vector2(strip.position.x + 17, strip.get_center().y)
	draw_circle(c, 13.5, Color(0, 0, 0, 0.55))
	draw_circle(c, 12.5, col.darkened(0.45))
	draw_arc(c, 12.5, 0, TAU, 28, col, 1.5, true)
	var ink: Color = p.ink
	if dead or intent == null:
		_text("INTENT", Rect2(strip.position.x + 36, strip.position.y + 2, 80, 11), 8, Color(ink, 0.6))
		_text("Defeated" if dead else "-", Rect2(strip.position.x + 36, strip.position.y + 12, strip.size.x - 40, 17), 13, ink)
		return
	_draw_intent_icon(intent.kind, c, col)
	# The number sits next to the badge; the description keeps every detail of the intent.
	var number := str(intent.amount)
	_text("INTENT", Rect2(strip.position.x + 36, strip.position.y + 2, 80, 11), 8, Color(ink, 0.6))
	var num_w := _font.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	_text(number, Rect2(strip.position.x + 36, strip.position.y + 8, num_w + 2, 22), 20, col.lightened(0.25))
	var desc := intent.describe()
	var left := strip.position.x + 36 + num_w + 8
	var room := strip.end.x - left - 5
	_text(desc, Rect2(left, strip.position.y + 10, room, 20), _fit_size(desc, room, 13, 8), ink)


## Attack = blade, Block = shield, Expose = crosshair, anything else = a diamond spark.
func _draw_intent_icon(kind: int, c: Vector2, col: Color) -> void:
	var bright := col.lightened(0.3)
	match kind:
		CardEffect.Kind.DAMAGE, CardEffect.Kind.DAMAGE_PER_BLOCK, CardEffect.Kind.DAMAGE_IF_BLOCK, CardEffect.Kind.DAMAGE_PER_PLAY, CardEffect.Kind.DAMAGE_PER_HAUNT:
			var rot := PI / 4.0
			var blade := PackedVector2Array()
			for u in [Vector2(0, -1.0), Vector2(0.2, -0.75), Vector2(0.2, 0.25), Vector2(-0.2, 0.25), Vector2(-0.2, -0.75)]:
				blade.append(c + (u as Vector2).rotated(rot) * 9.0)
			draw_colored_polygon(blade, bright)
			var guard := PackedVector2Array()
			for u in [Vector2(-0.55, 0.25), Vector2(0.55, 0.25), Vector2(0.55, 0.42), Vector2(-0.55, 0.42)]:
				guard.append(c + (u as Vector2).rotated(rot) * 9.0)
			draw_colored_polygon(guard, col)
		CardEffect.Kind.BLOCK:
			_shield_icon(c, 8.0, bright)
		CardEffect.Kind.EXPOSE:
			draw_arc(c, 5.5, 0, TAU, 20, bright, 1.8, true)
			for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				draw_line(c + d * 3.5, c + d * 9.0, bright, 1.8)
			draw_circle(c, 1.6, bright)
		_:
			_diamond(c, 7.0, bright)


# --- portraits -------------------------------------------------------------------------
# Every silhouette is drawn in pixels around the origin, which is the middle of the ground line
# (up is negative y), facing right where it has a facing. Tallest figures are about 64 px.

func _poly(points: Array, col: Color, outline := true) -> void:
	var pts := PackedVector2Array(points)
	if Geometry2D.triangulate_polygon(pts).is_empty():
		return
	draw_colored_polygon(pts, col)
	if outline:
		var closed := pts.duplicate()
		closed.append(pts[0])
		draw_polyline(closed, Color(0, 0, 0, 0.6), 1.2, true)


func _ball(c: Vector2, r: float, col: Color) -> void:
	draw_circle(c, r, col)
	draw_arc(c, r, 0, TAU, 20, Color(0, 0, 0, 0.6), 1.2, true)


## A glowing eye: a soft halo and a bright core, flickering with glow_level().
func _eye(c: Vector2, r: float, glow: Color) -> void:
	var g := glow_level()
	draw_circle(c, r * 2.2, Color(glow, 0.22 * g))
	draw_circle(c, r, Color(glow, g))


func _ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)


func _rotated(points: Array, pivot: Vector2, angle: float) -> Array:
	var out: Array = []
	for pt in points:
		out.append(pivot + ((pt as Vector2) - pivot).rotated(angle))
	return out


func _draw_portrait(key: StringName) -> void:
	var colors: Array = ART_COLORS.get(key, ART_COLORS[&"ghost"])
	var body: Color = colors[0]
	var glow: Color = colors[1]
	match key:
		&"warden":
			_art_warden(body, glow)
		&"shade":
			_art_shade(body, glow)
		&"wisp":
			_art_wisp(body, glow)
		&"colossus":
			_art_colossus(body, glow)
		&"whisperer":
			_art_whisperer(body, glow)
		&"hound":
			_art_hound(body, glow)
		&"crow":
			_art_crow(body, glow)
		&"conductor":
			_art_conductor(body, glow)
		&"brakeman":
			_art_brakeman(body, glow)
		_:
			_ghost_shape(Vector2(0, 0), 1.0, Color(body, 0.85), phase)
			_eye(Vector2(-5, -40), 2.0, glow)
			_eye(Vector2(5, -40), 2.0, glow)


## A plain ghost: a dome, a ragged wavering hem. Also the passengers behind the Conductor.
func _ghost_shape(origin: Vector2, s: float, col: Color, wave: float) -> void:
	var pts: Array = []
	for i in 13:
		var a := PI + PI * i / 12.0
		pts.append(origin + Vector2(cos(a) * 11.0, -38.0 + sin(a) * 14.0) * s)
	for i in 6:
		var x := 13.0 - i * 5.2
		var lift := 0.0 if i % 2 == 0 else -7.0 + sin(time * 2.0 + wave + i) * 1.5
		pts.append(origin + Vector2(x, lift) * s)
	_poly(pts, col)


func _art_warden(body: Color, glow: Color) -> void:
	var dark := body.darkened(0.5)
	# Halberd planted behind it.
	draw_line(Vector2(25, 0), Vector2(25, -60), dark.lightened(0.15), 2.0)
	_poly([Vector2(25, -61), Vector2(35, -54), Vector2(25, -46)], body.lightened(0.25))
	# Long coat with gate bars across the chest, pauldrons, closed helm.
	_poly([Vector2(-13, 0), Vector2(-17, -30), Vector2(-11, -45), Vector2(11, -45), Vector2(17, -30), Vector2(13, 0)], body)
	for x in [-6.0, 0.0, 6.0]:
		draw_line(Vector2(x, -42), Vector2(x, -20), dark, 1.5)
	_ball(Vector2(-16, -42), 6.0, body.lightened(0.1))
	_ball(Vector2(16, -42), 6.0, body.lightened(0.1))
	_poly([Vector2(-7, -45), Vector2(-8, -55), Vector2(0, -62), Vector2(8, -55), Vector2(7, -45)], body.lightened(0.05))
	draw_rect(Rect2(-5, -54, 10, 2.5), Color(glow, glow_level()))
	# A ring of keys at the belt.
	draw_arc(Vector2(-8, -18), 3.5, 0, TAU, 12, Color(glow, 0.8), 1.4, true)
	draw_line(Vector2(-8, -15), Vector2(-8, -9), Color(glow, 0.8), 1.4)


func _art_shade(body: Color, glow: Color) -> void:
	# Arms reaching out, then the hooded body.
	for side in [-1.0, 1.0]:
		var reach := sin(time * 1.4 + phase) * 2.0
		_poly([Vector2(side * 9, -34), Vector2(side * (27 + reach), -26), Vector2(side * (25 + reach), -21), Vector2(side * 8, -28)], Color(body, 0.8))
		for k in 3:
			draw_line(Vector2(side * (27 + reach), -25.5), Vector2(side * (33 + reach), -30 + k * 4), Color(body, 0.9), 1.2)
	_ghost_shape(Vector2.ZERO, 1.0, Color(body, 0.9), phase)
	for side in [-1.0, 1.0]:
		draw_circle(Vector2(side * 4.5, -41), 3.4, Color(0.02, 0.03, 0.05))
		_eye(Vector2(side * 4.5, -41), 1.2, glow)
	draw_circle(Vector2(0, -33), 2.4, Color(0.02, 0.03, 0.05))


func _art_wisp(body: Color, glow: Color) -> void:
	var g := glow_level()
	var c := Vector2(0, -32 + sin(time * 2.4 + phase) * 3.0)
	var sway := sin(time * 3.1 + phase) * 4.0
	# Skittering legs under the flame.
	for side in [-1.0, 1.0]:
		for i in 3:
			var wiggle := sin(time * 9.0 + i * 1.7 + (0.0 if side < 0 else 1.2)) * 2.5
			var knee := c + Vector2(side * (9 + i * 3), 6 + i * 2)
			draw_polyline(PackedVector2Array([c + Vector2(side * 5, 7), knee, Vector2(side * (14 + i * 5) + wiggle, minf(c.y + 26 + i * 2, -1.0))]), Color(body.darkened(0.2), 0.9), 1.5, true)
	# The flame: a pointed tip, a round belly and a wavering tail.
	_poly([c + Vector2(sway * 0.3, -21), c + Vector2(7, -9), c + Vector2(10, 0), c + Vector2(7, 9), c + Vector2(2, 19), c + Vector2(sway, 27), c + Vector2(-2, 19), c + Vector2(-7, 9), c + Vector2(-10, 0), c + Vector2(-7, -9)], Color(body, 0.95))
	_ellipse(c + Vector2(0, 2), 6.0, 8.0, Color(glow, 0.55 * g + 0.2))
	for side in [-1.0, 1.0]:
		draw_circle(c + Vector2(side * 3.0, -1), 1.6, Color(0.15, 0.04, 0.02))
	# Sparks circling it.
	for k in 3:
		var a := time * 2.6 + k * TAU / 3.0
		var pt := c + Vector2(cos(a) * 19.0, sin(a) * 9.0 - 2.0)
		draw_circle(pt, 3.0, Color(glow, 0.25 * g))
		draw_circle(pt, 1.5, Color(glow, g))


func _art_colossus(body: Color, glow: Color) -> void:
	var dark := body.darkened(0.45)
	# Legs, hanging arms ending in huge fists, a slab torso and a tiny head.
	_poly([Vector2(-17, 0), Vector2(-15, -22), Vector2(-3, -22), Vector2(-3, 0)], dark)
	_poly([Vector2(3, 0), Vector2(3, -22), Vector2(15, -22), Vector2(17, 0)], dark)
	_poly([Vector2(-26, -24), Vector2(-31, -44), Vector2(-25, -46), Vector2(-20, -26)], body.darkened(0.15))
	_poly([Vector2(26, -24), Vector2(31, -44), Vector2(25, -46), Vector2(20, -26)], body.darkened(0.15))
	_ball(Vector2(-27, -13), 8.0, body)
	_ball(Vector2(27, -13), 8.0, body)
	_poly([Vector2(-22, -20), Vector2(-27, -42), Vector2(-15, -54), Vector2(15, -54), Vector2(27, -42), Vector2(22, -20)], body)
	_ball(Vector2(0, -59), 6.0, body.lightened(0.05))
	# The hollow in its chest, with an ember heart that swells as it breathes.
	_ellipse(Vector2(0, -36), 10.0, 12.0, Color(0.03, 0.02, 0.03))
	_ellipse(Vector2(0, -35), 3.0 + breath() * 0.8 + 3.0, 4.0 + breath() + 4.0, Color(glow, 0.35 * glow_level()))
	draw_circle(Vector2(0, -35), 2.6, Color(glow, glow_level()))
	_eye(Vector2(-2.5, -60), 1.1, glow)
	_eye(Vector2(2.5, -60), 1.1, glow)


func _art_whisperer(body: Color, glow: Color) -> void:
	var dark := body.darkened(0.55)
	var hover := sin(time * 1.2 + phase) * 2.0
	# Whispers drifting out from both sides.
	for side in [-1.0, 1.0]:
		for i in 2:
			var t := fposmod(time * 0.6 + i * 0.5 + phase, 1.0)
			draw_arc(Vector2(side * 10, -48 + hover), 14.0 + t * 14.0, -0.5 if side > 0 else PI - 0.5, 0.5 if side > 0 else PI + 0.5, 8, Color(glow, 0.5 * (1.0 - t)), 1.2, true)
	# A thin robe, a dark hood and a pale face.
	_poly([Vector2(-9, -38 + hover), Vector2(-15, -8), Vector2(-8, 0), Vector2(0, -5), Vector2(8, 0), Vector2(15, -8), Vector2(9, -38 + hover)], dark.lightened(0.1))
	_poly([Vector2(-13, -46 + hover), Vector2(-10, -62 + hover), Vector2(0, -67 + hover), Vector2(10, -62 + hover), Vector2(13, -46 + hover), Vector2(11, -37 + hover), Vector2(-11, -37 + hover)], dark)
	_ellipse(Vector2(0, -49 + hover), 9.0, 11.0, body)
	# Long thin fingers at the face.
	for side in [-1.0, 1.0]:
		draw_polyline(PackedVector2Array([Vector2(side * 13, -22 + hover), Vector2(side * 14, -36 + hover), Vector2(side * 9, -46 + hover)]), body.darkened(0.2), 1.5, true)
	# Sunken eyes with a pinprick of light, then the many small mouths, each murmuring on its own beat.
	for side in [-1.0, 1.0]:
		draw_circle(Vector2(side * 4.0, -54 + hover), 2.4, Color(0.05, 0.03, 0.08))
		draw_circle(Vector2(side * 4.0, -54 + hover), 0.9, Color(glow, glow_level()))
	var mouths := [Vector2(0, -47), Vector2(-5, -49), Vector2(5, -48), Vector2(-3, -43), Vector2(4, -43), Vector2(-7, -44), Vector2(7, -52), Vector2(0, -58), Vector2(-6, -57)]
	for i in mouths.size():
		var open := 1.0 + 0.5 * sin(time * 6.0 + i * 1.9 + phase)
		_ellipse(mouths[i] + Vector2(0, hover), 1.3 + (i % 3) * 0.35, 0.9 * open + 0.4, Color(0.10, 0.04, 0.10))


func _art_hound(body: Color, glow: Color) -> void:
	var g := glow_level()
	var dark := body.darkened(0.3)
	var step := sin(time * 3.0 + phase) * 1.5
	# Tail, rear legs, body, front legs, neck and head with ears.
	_poly([Vector2(-24, -24), Vector2(-38, -40), Vector2(-33, -26)], dark)
	_poly([Vector2(-24, -16), Vector2(-14, -16), Vector2(-13 + step, 0), Vector2(-21 + step, 0)], dark)
	_poly([Vector2(-16, -16), Vector2(-8, -16), Vector2(-7 - step, 0), Vector2(-15 - step, 0)], dark.darkened(0.2))
	_poly([Vector2(-27, -22), Vector2(-18, -31), Vector2(2, -33), Vector2(14, -28), Vector2(19, -22), Vector2(12, -13), Vector2(-20, -13)], body)
	_poly([Vector2(8, -17), Vector2(16, -17), Vector2(16 - step, 0), Vector2(8 - step, 0)], dark)
	_poly([Vector2(14, -17), Vector2(21, -18), Vector2(23 + step, 0), Vector2(15 + step, 0)], dark.darkened(0.2))
	_poly([Vector2(12, -29), Vector2(20, -39), Vector2(31, -38), Vector2(41, -30), Vector2(38, -24), Vector2(27, -23), Vector2(19, -17)], body)
	_poly([Vector2(21, -38), Vector2(23, -47), Vector2(29, -37)], dark)
	# A glowing maw, a burning eye and embers glowing through the fur along its back.
	draw_line(Vector2(28, -25), Vector2(39, -26), Color(glow, g), 1.5)
	for i in 4:
		draw_line(Vector2(31 + i * 2.5, -25), Vector2(32 + i * 2.5, -22), Color(0.95, 0.9, 0.8), 1.0)
	_eye(Vector2(30, -33), 1.8, glow)
	for i in 5:
		draw_circle(Vector2(-18 + i * 7, -29 + (i % 2) * 2), 1.6, Color(glow, 0.7 * g))
	for k in 3:
		var t := fposmod(time * 0.7 + k * 0.33 + phase, 1.0)
		draw_circle(Vector2(-14 + k * 12 + sin(time * 3.0 + k) * 2.0, -34 - t * 22), 1.3, Color(glow, 0.9 * (1.0 - t)))


func _art_crow(body: Color, glow: Color) -> void:
	var flap := sin(time * 2.2 + phase) * 0.12
	var dark := body.darkened(0.25)
	var far := _rotated([Vector2(-1, -27), Vector2(-18, -50), Vector2(-26, -45), Vector2(-21, -40), Vector2(-29, -34), Vector2(-21, -30), Vector2(-24, -24), Vector2(-5, -20)], Vector2(-1, -26), -flap)
	_poly(far, dark)
	# Legs, tail and the chest, with the head turned toward the player.
	for x in [-2.0, 5.0]:
		draw_polyline(PackedVector2Array([Vector2(x, -12), Vector2(x + 1, -2), Vector2(x + 4, 0)]), Color(0.45, 0.4, 0.35), 1.5, true)
	_poly([Vector2(-12, -17), Vector2(-32, -10), Vector2(-28, -5), Vector2(-9, -11)], dark)
	_poly([Vector2(-15, -19), Vector2(-9, -31), Vector2(6, -33), Vector2(15, -25), Vector2(11, -14), Vector2(-5, -9)], body)
	var near := _rotated([Vector2(2, -29), Vector2(-14, -56), Vector2(-24, -52), Vector2(-18, -45), Vector2(-27, -40), Vector2(-17, -35), Vector2(-21, -28), Vector2(-4, -20)], Vector2(2, -27), -flap * 1.4)
	_poly(near, body.lightened(0.05))
	_ball(Vector2(12, -37), 6.0, body)
	_poly([Vector2(17, -39), Vector2(28, -34), Vector2(17, -33)], Color(0.55, 0.5, 0.4))
	_eye(Vector2(13, -38), 1.5, glow)
	# A single pale tear, falling and re-forming.
	var t := fposmod(time * 0.8 + phase, 1.0)
	draw_circle(Vector2(13.5, -33 + t * 14), 1.3, Color(0.75, 0.88, 1.0, 1.0 - t))


func _art_conductor(body: Color, glow: Color) -> void:
	ConductorFigure.draw(self, time, glow_level(), phase, body, glow)


## The mid-boss: a hulking brakeman in a sooty apron, a spoked brake wheel raised in one gauntlet and
## a swinging signal lantern in the other, steam venting from his shoulders.
func _art_brakeman(body: Color, glow: Color) -> void:
	var g := glow_level()
	var brass := Color(0.82, 0.60, 0.26)
	var dark := body.darkened(0.45)
	var sway := sin(time * 1.6 + phase)
	# Steam venting from the shoulders.
	for side in [-1.0, 1.0]:
		for i in 2:
			var t := fposmod(time * 0.5 + i * 0.5 + phase, 1.0)
			draw_circle(Vector2(side * 21 + sway * 3.0 * t, -58 - t * 12.0), 2.0 + t * 3.0, Color(0.8, 0.8, 0.85, 0.28 * (1.0 - t)))
	# Thick legs and heavy boots.
	_poly([Vector2(-17, 0), Vector2(-15, -22), Vector2(-3, -22), Vector2(-3, 0)], dark)
	_poly([Vector2(3, 0), Vector2(3, -22), Vector2(15, -22), Vector2(17, 0)], dark)
	draw_rect(Rect2(-19, -4, 17, 4), dark.darkened(0.3))
	draw_rect(Rect2(2, -4, 17, 4), dark.darkened(0.3))
	# The lantern arm: a hanging gauntlet and a signal lantern swinging below it.
	_poly([Vector2(-26, -50), Vector2(-33, -44), Vector2(-35, -30), Vector2(-28, -30), Vector2(-24, -42)], body.darkened(0.1))
	var hook := Vector2(-31, -26)
	var lamp := hook + Vector2(sway * 5.0, 14)
	draw_line(hook, lamp + Vector2(0, -5), Color(brass, 0.9), 1.2)
	draw_circle(lamp, 11.0, Color(glow, 0.14 * g))
	_poly([lamp + Vector2(-4, -4), lamp + Vector2(4, -4), lamp + Vector2(5, 6), lamp + Vector2(-5, 6)], brass.darkened(0.2))
	draw_rect(Rect2(lamp + Vector2(-2.5, -2), Vector2(5, 6)), Color(glow, g))
	_ball(Vector2(-31, -27), 5.5, body.lightened(0.12))
	# Broad torso with a brass-buckled leather apron and big pauldrons.
	_poly([Vector2(-23, -22), Vector2(-29, -44), Vector2(-19, -57), Vector2(19, -57), Vector2(29, -44), Vector2(23, -22)], body)
	_poly([Vector2(-12, -52), Vector2(12, -52), Vector2(14, -22), Vector2(-14, -22)], dark)
	draw_rect(Rect2(-14, -28, 28, 3.5), brass)
	draw_rect(Rect2(-3, -29, 6, 5.5), brass.lightened(0.2))
	for x in [-8.0, 0.0, 8.0]:
		draw_line(Vector2(x, -50), Vector2(x, -32), Color(0, 0, 0, 0.35), 1.2)
	_ball(Vector2(-25, -54), 7.0, body.lightened(0.1))
	_ball(Vector2(25, -54), 7.0, body.lightened(0.1))
	# Small helmeted head with a glowing visor slit and a brass rim.
	_poly([Vector2(-8, -58), Vector2(-9, -68), Vector2(0, -73), Vector2(9, -68), Vector2(8, -58)], body.lightened(0.05))
	draw_rect(Rect2(-9, -65, 18, 2.0), brass)
	draw_rect(Rect2(-5.5, -62, 11, 2.5), Color(glow, g))
	# The raised arm and the brake wheel: a rim, rotating spokes and a hub in the gauntlet.
	_poly([Vector2(22, -56), Vector2(31, -52), Vector2(38, -44), Vector2(32, -41), Vector2(25, -47)], body.darkened(0.1))
	var hub := Vector2(40, -40)
	var spin := time * 0.5 + phase
	for k in 6:
		draw_line(hub, hub + Vector2.from_angle(spin + k * TAU / 6.0) * 13.0, Color(brass, 0.9), 2.0)
	draw_arc(hub, 13.0, 0, TAU, 28, brass, 3.0, true)
	draw_arc(hub, 13.0, 0, TAU, 28, Color(0, 0, 0, 0.5), 0.8, true)
	_ball(hub, 5.5, body.lightened(0.15))
	draw_circle(hub, 1.6, Color(glow, g))
