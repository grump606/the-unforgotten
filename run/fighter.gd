class_name Fighter
extends Control
## One combatant on the battle stage, seen from the side (Slay the Spire style): the figure standing on
## the ground line, the enemy's intent floating above its head, an HP bar with Block beneath its feet and
## status pills under that. The player stands on the left facing right; enemies face left.
##
## Animation (idle breath, lunge, hit recoil and flash, shield pop, floating numbers, defeat fade) runs
## only through advance(delta), so tests can step it deterministically (no global RNG, no wall clock).
## The figure is the enemy's painted figure layer when there is one, else a code-drawn stand-in.

const OVERHEAD := 58.0 ## room above the figure for the intent and the target marker
const UNDER := 50.0 ## room below the feet for the HP bar and status pills
const MIN_WIDTH := 150.0
const LUNGE_TIME := 0.45
const FLASH_TIME := 0.35
const RECOIL_TIME := 0.3
const POP_TIME := 0.35
const FADE_TIME := 0.7
const FLOAT_TIME := 1.1
const BAR_H := 16.0

## Enemy display name -> art key (sprite files, figure height). Any other name uses the generic ghost.
const ART_KEYS := {
	"Gate Warden": &"warden", "Lost Shade": &"shade", "Skittering Wisp": &"wisp", "Hollow Colossus": &"colossus",
	"Pale Whisperer": &"whisperer", "Cinder Hound": &"hound", "Mourning Crow": &"crow", "The Conductor": &"conductor",
	"The Brakeman": &"brakeman",
	"Threshold Keeper": &"warden", "The Unnamed": &"shade", "Stray Recollection": &"wisp",
	"Memorial Giant": &"colossus", "The Husher": &"whisperer", "Ash Hound": &"hound",
	"Keepsake Crow": &"crow", "Bellkeeper": &"brakeman", "Eraser": &"conductor",
}
## Figure height in pixels per enemy (the player and unknown names use DEFAULT_HEIGHT).
const HEIGHTS := {
	&"warden": 170.0, &"shade": 150.0, &"wisp": 100.0, &"colossus": 200.0, &"whisperer": 175.0,
	&"hound": 115.0, &"crow": 105.0, &"conductor": 210.0, &"brakeman": 215.0, &"ghost": 140.0,
}
const DEFAULT_HEIGHT := 170.0
## The stage is roomy, so every figure is drawn this much larger than the table above.
const HEIGHT_SCALE := 1.2
## The player figure height before HEIGHT_SCALE.
const PLAYER_HEIGHT := 205.0
## Class colours of the code-drawn player stand-in: cloak, accent.
const CLASS_COLORS := {
	&"deserter": [Color(0.40, 0.30, 0.24), Color(0.92, 0.55, 0.22)],
	&"pickpocket": [Color(0.16, 0.30, 0.31), Color(0.30, 0.85, 0.80)],
	&"medium": [Color(0.30, 0.22, 0.42), Color(0.72, 0.52, 1.0)],
}
## Which way each painted class figure faces as drawn (+1 right, -1 left); the stage mirrors it to face right.
const PLAYER_ART_FACING := {&"deserter": 1.0, &"pickpocket": 1.0, &"medium": 1.0}
## Painted enemy sprites that face right as drawn (everything else faces left); the stage mirrors them.
const SPRITE_FACES_RIGHT: Array[StringName] = []
const HP_BACK := Color(0.10, 0.04, 0.05)
const SHADOW := Color(0, 0, 0, 0.38)

## Emitted when the figure is clicked while alive (an enemy; the player is not clickable).
signal pressed

var unit: Combatant
var is_player := false
## Which way the fighter faces: +1 right (the player), -1 left (enemies).
var facing := -1.0
var art_key: StringName = &"ghost"
var class_id: StringName = &""
var figure_height := DEFAULT_HEIGHT
var targeted := false
## Seconds of animation so far; only advance() moves it.
var time := 0.0
## Offsets the idle breath so fighters of one type do not breathe in step.
var phase := 0.0
## 0 while alive, 1 once the defeat fade has finished.
var fade := 0.0

var _tex: Texture2D
var _region := Rect2()
## Which way the painted figure faces as drawn (the enemy art looks left).
var _art_facing := -1.0
var _flash := 0.0
var _lunge := 0.0
var _lunge_delay := 0.0
var _recoil := 0.0
var _pop := 0.0
var _hovered := false
var _last_hp := 0
var _last_block := 0
## {text, color, age, drift} entries rising from the figure.
var _floats: Array[Dictionary] = []
## Seconds to wait before the next refresh() plays the reactions it detects (the battle sets it so a hit
## lands when the attacker's lunge does). refresh() resets it.
var react_delay := 0.0
## Reactions waiting for their moment: {t, amount} (amount 0 is a fully blocked hit, below 0 a heal).
var _reactions: Array[Dictionary] = []
## HP the battle already scheduled hits for, so refresh() does not react to the same loss twice.
var _scheduled_loss := 0
var _scheduled_block := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP # also needed for the status tooltip
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func _ready() -> void:
	visibility_changed.connect(_on_visibility_changed)
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))
	_on_visibility_changed()


func _on_visibility_changed() -> void:
	set_process(is_visible_in_tree()) # no cost while hidden


func _process(delta: float) -> void:
	advance(delta)


## Shows an enemy from scratch: picks its figure and snaps every animation to its resting state.
func set_enemy(enemy: EnemyUnit) -> void:
	is_player = false
	facing = -1.0
	_art_facing = -1.0
	unit = enemy
	art_key = art_key_for(enemy.display_name)
	figure_height = float(HEIGHTS.get(art_key, DEFAULT_HEIGHT)) * HEIGHT_SCALE
	_tex = null
	var fig := PaintedArt.enemy_figure(art_key)
	if not fig.is_empty():
		_tex = fig.tex
		_region = fig.region
		_art_facing = 1.0 if fig.get("sprite", false) and SPRITE_FACES_RIGHT.has(art_key) else -1.0
	_reset()


## Shows the player from scratch. `id` is the character id (picks the stand-in colours).
func set_player(player: Combatant, id: StringName) -> void:
	is_player = true
	facing = 1.0
	unit = player
	class_id = id
	figure_height = PLAYER_HEIGHT * HEIGHT_SCALE
	_tex = null
	_art_facing = PLAYER_ART_FACING.get(id, 1.0)
	var fig := PaintedArt.player_figure(id)
	if not fig.is_empty():
		_tex = fig.tex
		_region = fig.region
	_reset()


func _reset() -> void:
	_last_hp = unit.hp
	_last_block = unit.block
	_flash = 0.0
	_lunge = 0.0
	_lunge_delay = 0.0
	_recoil = 0.0
	_pop = 0.0
	_floats.clear()
	fade = 1.0 if is_defeated() else 0.0
	custom_minimum_size = Vector2(maxf(figure_width() + 20.0, MIN_WIDTH), OVERHEAD + figure_height + UNDER)
	size = custom_minimum_size
	queue_redraw()


## The art key for an enemy name; unknown names get the generic ghost.
static func art_key_for(enemy_name: String) -> StringName:
	return ART_KEYS.get(enemy_name, &"ghost")


## Width of the figure as drawn.
func figure_width() -> float:
	if _tex != null:
		return figure_height * _region.size.x / _region.size.y
	return figure_height * 0.55


## Where the feet touch the ground, in this control's coordinates.
func feet() -> Vector2:
	return Vector2(size.x / 2.0, OVERHEAD + figure_height)


## The figure's box (painted pixels), in this control's coordinates.
func figure_rect() -> Rect2:
	var w := figure_width()
	return Rect2(feet() - Vector2(w / 2.0, figure_height), Vector2(w, figure_height))


## The HP bar, in this control's coordinates.
func bar_rect() -> Rect2:
	var w := maxf(figure_width() * 0.8, 110.0)
	return Rect2(size.x / 2.0 - w / 2.0, feet().y + 10.0, w, BAR_H)


func is_defeated() -> bool:
	return unit != null and unit.is_dead()


func set_targeted(value: bool) -> void:
	targeted = value
	queue_redraw()


## Reads the unit's current state and starts the reactions to what changed: a hit flashes and recoils
## and floats the damage, Block gained pops the shield, Block that soaked a hit says so, healing floats.
func refresh() -> void:
	if unit == null:
		return
	if unit.hp < _last_hp:
		var extra := maxi(_last_hp - unit.hp - _scheduled_loss, 0)
		if extra > 0:
			_react(extra, react_delay)
	elif unit.hp > _last_hp:
		_react(_last_hp - unit.hp, react_delay)
	if unit.block > _last_block:
		_pop = 1.0
	elif unit.block < _last_block and unit.hp >= _last_hp and not _scheduled_block:
		_react(0, react_delay)
	_last_hp = unit.hp
	_last_block = unit.block
	_scheduled_loss = 0
	_scheduled_block = false
	react_delay = 0.0
	queue_redraw()


## Plays a hit (or, with 0, a fully blocked hit) after `delay` seconds, and tells the next refresh() not to
## react to it again. The battle uses it so each enemy's hit on the player lands with that enemy's lunge.
func schedule_hit(amount: int, delay: float) -> void:
	_scheduled_loss += amount
	if amount == 0:
		_scheduled_block = true
	_react(amount, delay)


func _react(amount: int, delay: float) -> void:
	if delay <= 0.0:
		_play_reaction(amount)
	else:
		_reactions.append({"t": delay, "amount": amount})


func _play_reaction(amount: int) -> void:
	if amount > 0:
		_flash = 1.0
		_recoil = 1.0
		_float("-%d" % amount, Color(1.0, 0.42, 0.38))
	elif amount < 0:
		_float("+%d" % -amount, Color(0.55, 1.0, 0.55))
	else:
		_float("Blocked", CardView.kind_color(CardEffect.Kind.BLOCK).lightened(0.3))


## A lunge toward the opponent, starting after `delay` seconds (so a row of enemies attack one by one).
func play_attack(delay := 0.0) -> void:
	_lunge = 1.0
	_lunge_delay = delay


func _float(txt: String, col: Color) -> void:
	_floats.append({"text": txt, "color": col, "age": 0.0, "drift": float(_floats.size() % 3 - 1) * 14.0})


## Number of floating numbers still on screen (read by tests).
func float_count() -> int:
	return _floats.size()


## Steps the animation. Does nothing unless the view is on screen.
func advance(delta: float) -> void:
	if not is_visible_in_tree():
		return
	time += delta
	if _lunge_delay > 0.0:
		_lunge_delay -= delta
	else:
		_lunge = maxf(_lunge - delta / LUNGE_TIME, 0.0)
	_flash = maxf(_flash - delta / FLASH_TIME, 0.0)
	_recoil = maxf(_recoil - delta / RECOIL_TIME, 0.0)
	_pop = maxf(_pop - delta / POP_TIME, 0.0)
	for r in _reactions:
		r.t -= delta
	for r in _reactions.filter(func(r: Dictionary) -> bool: return r.t <= 0.0):
		_play_reaction(r.amount)
	_reactions = _reactions.filter(func(r: Dictionary) -> bool: return r.t > 0.0)
	fade = move_toward(fade, 1.0 if is_defeated() else 0.0, delta / FADE_TIME)
	for f in _floats:
		f.age += delta
	_floats = _floats.filter(func(f: Dictionary) -> bool: return f.age < FLOAT_TIME)
	queue_redraw()


## Breathing, -1..1.
func breath() -> float:
	return sin(time * 1.7 + phase)


## Combat-ready weight shifts, anchored at the feet. Uses presentation time only.
## Reactions take priority and defeated fighters stop shifting their weight.
func stance_motion() -> Vector3:
	if is_defeated():
		return Vector3.ZERO
	var speed := 2.1
	var strength := 1.0
	if is_player:
		match class_id:
			&"deserter":
				speed = 1.8
				strength = 0.8
			&"pickpocket":
				speed = 2.8
				strength = 1.15
			&"medium":
				speed = 1.5
				strength = 0.55
	elif art_key in [&"wisp", &"crow"]:
		speed = 3.0
		strength = 0.6
	elif art_key in [&"colossus", &"brakeman"]:
		speed = 1.4
		strength = 0.65
	var readiness := 1.0 - maxf(lunge_amount(), _recoil)
	var cycle := time * speed + phase
	var weight := sin(cycle) * strength * readiness
	# x: a small lateral shift; y: forward guard lean; z: knee/torso compression.
	return Vector3(weight * 1.4, -facing * (0.012 + weight * 0.009) * readiness,
		(0.5 + 0.5 * cos(cycle * 2.0)) * 0.012 * strength * readiness)


## How far into its lunge the fighter is (0 idle, 1 at the top of the strike), for tests and the draw.
func lunge_amount() -> float:
	return 0.0 if _lunge_delay > 0.0 else sin(_lunge * PI)


## The statuses shown as pills, in display order: {kind, value, text, color}. Hold and Thorns count too.
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


## Where each status pill is drawn, in the order of status_chips(): a centered row under the HP bar.
func chip_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var chips := status_chips()
	var font: Font = ThemeDB.fallback_font
	var widths: Array[float] = []
	var total := 0.0
	for chip in chips:
		var w := font.get_string_size(str(chip.value), HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 22.0
		widths.append(w)
		total += w + 4.0
	var x := size.x / 2.0 - (total - 4.0) / 2.0
	var y := bar_rect().end.y + 5.0
	for w in widths:
		rects.append(Rect2(x, y, w, 16))
		x += w + 4.0
	return rects


## Where the intent badge sits (above the head), in this control's coordinates.
func intent_center() -> Vector2:
	return Vector2(size.x / 2.0, 30.0 + breath() * 1.5)


## Like a Button, a click counts when the mouse is released over a living enemy.
func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.button_index == MOUSE_BUTTON_LEFT and not click.pressed and not is_player and unit != null and not unit.is_dead() and Rect2(Vector2.ZERO, size).has_point(click.position):
		accept_event()
		pressed.emit()


func _on_hover(inside: bool) -> void:
	_hovered = inside
	queue_redraw()


# --- drawing ---------------------------------------------------------------------------

func _draw() -> void:
	if unit == null:
		return
	var alive := fade < 1.0
	var a := 1.0 - fade
	var ground := feet()
	if targeted and not is_defeated():
		_draw_target_ring(ground)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_ellipse_shadow(ground, figure_width() * 0.42 * (1.0 - fade * 0.5), Color(SHADOW, SHADOW.a * a))
	_draw_figure(ground, a)
	if alive:
		if not is_player:
			_draw_intent(a)
		_draw_bar(a)
		_draw_chips(a)
	if targeted and not is_defeated():
		var mx := size.x / 2.0
		var my := 4.0 + sin(time * 4.0) * 2.0
		draw_colored_polygon(PackedVector2Array([Vector2(mx - 9, my), Vector2(mx + 9, my), Vector2(mx, my + 9)]), CardView.SELECT_GOLD)
	_draw_floats()


func draw_ellipse_shadow(c: Vector2, rx: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var ang := TAU * i / 24.0
		pts.append(c + Vector2(cos(ang) * rx, sin(ang) * rx * 0.16))
	draw_colored_polygon(pts, col)


func _draw_target_ring(ground: Vector2) -> void:
	var rx := figure_width() * 0.5 + 8.0
	var pts := PackedVector2Array()
	for i in 33:
		var ang := TAU * i / 32.0
		pts.append(ground + Vector2(cos(ang) * rx, sin(ang) * rx * 0.16))
	draw_polyline(pts, Color(CardView.SELECT_GOLD, 0.85), 2.0, true)


## The figure standing on its feet with the idle breath, the lunge toward the opponent, the recoil from
## a hit, the hit flash and the defeat fade (it sinks and goes see-through).
func _draw_figure(ground: Vector2, a: float) -> void:
	var lunge := lunge_amount()
	var stance := stance_motion()
	var dx := facing * (lunge * 46.0) - facing * sin(_recoil * PI) * 16.0
	var shake := sin(time * 70.0) * 2.5 * _flash
	var squash := 1.0 + breath() * 0.008 - stance.z + lunge * 0.04
	var stretch := 1.0 + lunge * 0.04
	var sink := fade * 18.0
	var tint := Color(1, 1, 1, a)
	if _flash > 0.0:
		tint = Color(1.0, 1.0 - _flash * 0.6, 1.0 - _flash * 0.6, a)
	elif _hovered and not is_defeated() and not is_player:
		tint = Color(1.12, 1.12, 1.12, a)
	var flip := 1.0 if is_equal_approx(facing, _art_facing) else -1.0
	draw_set_transform(ground + Vector2(dx + shake + stance.x, sink), stance.y, Vector2(stretch * flip, squash))
	if _tex != null:
		var w := figure_width()
		draw_texture_rect_region(_tex, Rect2(-w / 2.0, -figure_height, w, figure_height), _region, tint)
	else:
		_draw_stand_in(tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The code-drawn figure used when there is no painted one: a cloaked silhouette in the class colours
## (facing right, so the transform in _draw_figure mirrors it for enemies).
func _draw_stand_in(tint: Color) -> void:
	var colors: Array = CLASS_COLORS.get(class_id, [Color(0.36, 0.38, 0.44), Color(0.85, 0.90, 1.0)])
	var cloak: Color = (colors[0] as Color) * tint
	var accent: Color = colors[1]
	var h := figure_height
	var body := PackedVector2Array([
		Vector2(-0.20, 0.0) * h, Vector2(0.20, 0.0) * h, Vector2(0.17, -0.50) * h, Vector2(0.10, -0.74) * h,
		Vector2(-0.08, -0.74) * h, Vector2(-0.19, -0.50) * h,
	])
	draw_colored_polygon(body, cloak)
	draw_polyline(body + PackedVector2Array([body[0]]), Color(0, 0, 0, 0.6 * tint.a), 1.5, true)
	# A lighter cloak edge on the side toward the opponent, so the shape reads as lit from the front.
	draw_colored_polygon(PackedVector2Array([Vector2(0.10, -0.74) * h, Vector2(0.17, -0.50) * h, Vector2(0.20, 0.0) * h, Vector2(0.12, 0.0) * h, Vector2(0.10, -0.50) * h]), Color(accent, 0.18 * tint.a))
	var head := Vector2(0.03, -0.83) * h
	draw_circle(head, 0.095 * h, cloak.darkened(0.25))
	draw_arc(head, 0.095 * h, 0, TAU, 24, Color(0, 0, 0, 0.6 * tint.a), 1.5, true)
	var eye := head + Vector2(0.05, 0.0) * h
	draw_circle(eye, 0.03 * h, Color(accent, 0.25 * tint.a))
	draw_circle(eye, 0.012 * h, Color(accent, tint.a))
	var prop := Color(accent, tint.a)
	match class_id:
		&"deserter": # a sword held low in front
			draw_line(Vector2(0.18, -0.30) * h, Vector2(0.42, -0.62) * h, prop.darkened(0.2), 4.0, true)
			draw_line(Vector2(0.15, -0.34) * h, Vector2(0.24, -0.26) * h, prop, 3.0, true)
		&"pickpocket": # a dagger and a coin
			draw_line(Vector2(0.18, -0.34) * h, Vector2(0.34, -0.50) * h, prop.darkened(0.2), 3.0, true)
			draw_circle(Vector2(0.24, -0.20) * h, 0.03 * h, prop)
		&"medium": # a lantern with a pale flame
			draw_line(Vector2(0.17, -0.40) * h, Vector2(0.30, -0.50) * h, prop.darkened(0.3), 2.5, true)
			draw_circle(Vector2(0.32, -0.40) * h, 0.07 * h, Color(accent, 0.22 * tint.a))
			draw_circle(Vector2(0.32, -0.40) * h, 0.03 * h, prop.lightened(0.3))
		_:
			pass


## The intent floating above the head: a round badge with the action's icon and its amount beside it.
## (The full description is in the figure's tooltip.)
func _draw_intent(a: float) -> void:
	var enemy := unit as EnemyUnit
	var intent := enemy.current_intent() if enemy != null else null
	if intent == null:
		return
	var col := CardView.kind_color(int(intent.kind))
	var c := intent_center()
	var number := str(intent.amount)
	var nw := ThemeDB.fallback_font.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	var total := 30.0 + 5.0 + nw
	var cx := c.x - total / 2.0 + 15.0
	var badge := Vector2(cx, c.y)
	draw_circle(badge, 16.0, Color(0, 0, 0, 0.6 * a))
	draw_circle(badge, 14.5, Color(col.darkened(0.5), 0.95 * a))
	draw_arc(badge, 14.5, 0, TAU, 28, Color(col, a), 1.8, true)
	HudIcons.intent(self, int(intent.kind), badge, Color(col, a), 1.0)
	HudIcons.text(self, number, Rect2(cx + 19.0, c.y - 14.0, nw + 4.0, 28.0), 22, Color(col.lightened(0.35), a), false, 4)


## The HP bar under the feet with its numbers. Block shows as a blue frame and a shield badge on the left end.
func _draw_bar(a: float) -> void:
	var bar := bar_rect()
	var has_block := unit.block > 0
	var frame := CardView.kind_color(CardEffect.Kind.BLOCK) if has_block else Color(0.55, 0.22, 0.2)
	HudIcons.box(self, bar, Color(HP_BACK, a), 4, 2 if has_block else 1, Color(frame, a))
	var ratio := clampf(float(unit.hp) / maxf(float(unit.max_hp), 1.0), 0.0, 1.0)
	if ratio > 0.0:
		HudIcons.box(self, Rect2(bar.position + Vector2(1, 1), Vector2(maxf((bar.size.x - 2) * ratio, 4.0), bar.size.y - 2)), Color(CardView.HP_RED, a), 3)
	HudIcons.text(self, "%d/%d" % [maxi(unit.hp, 0), unit.max_hp], bar, 12, Color(1, 1, 1, a), true, 3)
	if has_block:
		var pop := 1.0 + sin(_pop * PI) * 0.35
		var c := Vector2(bar.position.x - 2.0, bar.get_center().y)
		var col := CardView.kind_color(CardEffect.Kind.BLOCK)
		HudIcons.shield(self, c, 15.0 * pop, Color(0, 0, 0, 0.6 * a))
		HudIcons.shield(self, c, 13.0 * pop, Color(col.darkened(0.25), a))
		HudIcons.text(self, str(unit.block), Rect2(c - Vector2(14, 12), Vector2(28, 24)), 14, Color(1, 1, 1, a), true, 3)


func _draw_chips(a: float) -> void:
	var chips := status_chips()
	var rects := chip_rects()
	for i in chips.size():
		var chip: Dictionary = chips[i]
		var r := rects[i]
		var col: Color = chip.color
		HudIcons.box(self, r, Color(0.04, 0.03, 0.05, 0.9 * a), 8, 1, Color(col, a))
		HudIcons.status(self, chip.kind, Vector2(r.position.x + 9, r.position.y + 8), Color(col, a))
		HudIcons.text(self, str(chip.value), Rect2(r.position.x + 16, r.position.y, r.size.x - 18, r.size.y), 11, Color(0.97, 0.95, 0.92, a), false)


func _draw_floats() -> void:
	var origin := Vector2(size.x / 2.0, OVERHEAD + figure_height * 0.35)
	for f in _floats:
		var t: float = f.age / FLOAT_TIME
		var rise := 1.0 - pow(1.0 - t, 2.0)
		var alpha := 1.0 - smoothstep(0.55, 1.0, t)
		var pop := 1.0 + sin(minf(t * 5.0, 1.0) * PI) * 0.25
		var fs := int(26.0 * pop)
		var col: Color = f.color
		HudIcons.text(self, f.text, Rect2(origin + Vector2(f.drift - 60.0, -rise * 60.0 - 14.0), Vector2(120, 28)), fs, Color(col, alpha), true, 5)

