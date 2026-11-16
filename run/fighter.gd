class_name Fighter
extends Control
## One combatant on the battle stage, seen from the side: the figure standing on
## the ground line, the enemy's intent floating above its head, an HP bar with Block beneath its feet and
## status pills under that. The player stands on the left facing right; enemies face left.
##
## Animation (idle breath, lunge, hit recoil and flash, shield pop, floating numbers, defeat fade) runs
## only through advance(delta), so tests can step it deterministically (no global RNG, no wall clock).
## Under Motion.reduced the figure holds still: no breathing or weight shift, no lunge, recoil, hit flash,
## shield pop or entrance scale-in, and the defeat fade is instant. Damage and healing numbers still
## appear (and HP and Block still change) but do not rise, pop or fade.
## The figure is the enemy's painted figure layer when there is one, else a code-drawn stand-in.
## This script holds the state, layout and animation; FighterPainter (run/fighter_painter.gd) draws it.

const OVERHEAD := 58.0 ## room above the figure for the intent and the target marker
const UNDER := 68.0 ## room below the feet for the HP bar and up to two rows of status pills
const CHIP_H := 16.0
const CHIP_GAP := 4.0
const MIN_WIDTH := 150.0
const LUNGE_TIME := 0.45
const FLASH_TIME := 0.35
const RECOIL_TIME := 0.3
const POP_TIME := 0.35
const FADE_TIME := 0.7
const FLOAT_TIME := 1.1
const BAR_H := 16.0
## z_index of the drop label layer: above the dragged card's ghost (battle_drag.gd GHOST_Z), so the
## result is never covered by the card.
const DROP_LABEL_Z := 30

## Enemy id (EnemyData.id) -> art key (sprite files, figure height). Keyed by id, never by display name, so
## renaming an enemy cannot break its art. Any other id uses the generic ghost.
const ART_KEYS := {
	&"gate_warden": &"warden", &"lost_shade": &"shade", &"skittering_wisp": &"wisp", &"hollow_colossus": &"colossus",
	&"pale_whisperer": &"whisperer", &"cinder_hound": &"hound", &"mourning_crow": &"crow",
	&"the_conductor": &"conductor", &"the_brakeman": &"brakeman",
	# Chapter 2 (the Registry): each uses its own id as the art key.
	&"ledger_clerk": &"ledger_clerk", &"drowned_porter": &"drowned_porter", &"shelf_wraith": &"shelf_wraith", &"index_moth": &"index_moth",
	&"the_misfiled": &"the_misfiled", &"pressing_hand": &"pressing_hand", &"copyist": &"copyist",
	&"the_archivist": &"the_archivist", &"the_registrar": &"the_registrar",
	# Chapter 3 (the Scriptorium): each uses its own id as the art key.
	&"inkwell_imp": &"inkwell_imp", &"pen_knight": &"pen_knight", &"smudge": &"smudge", &"penwiper": &"penwiper",
	&"scroll_mother": &"scroll_mother", &"the_unfinished": &"the_unfinished", &"ledger_wolf": &"ledger_wolf",
	&"the_blotter": &"the_blotter", &"the_warden_of_the_inkwell": &"the_warden_of_the_inkwell", &"the_scrivener": &"the_scrivener",
	&"proto_pest": &"hound", # the debug-only prototype enemy borrows the hound's figure
	&"proto_dreadkeeper": &"whisperer", # likewise the Dreadkeeper borrows the whisperer's
}
## Figure height in pixels per enemy (the player and unknown ids use DEFAULT_HEIGHT).
const HEIGHTS := {
	&"warden": 195.0, &"shade": 150.0, &"wisp": 100.0, &"colossus": 200.0, &"whisperer": 175.0,
	&"hound": 115.0, &"crow": 105.0, &"conductor": 210.0, &"brakeman": 215.0, &"ghost": 140.0,
	&"ledger_clerk": 150.0, &"drowned_porter": 200.0, &"shelf_wraith": 110.0, &"index_moth": 100.0, &"the_misfiled": 135.0,
	&"pressing_hand": 115.0, &"copyist": 170.0, &"the_archivist": 215.0, &"the_registrar": 220.0,
	&"inkwell_imp": 105.0, &"pen_knight": 200.0, &"smudge": 165.0, &"penwiper": 130.0, &"scroll_mother": 190.0,
	&"the_unfinished": 175.0, &"ledger_wolf": 115.0, &"the_blotter": 215.0, &"the_warden_of_the_inkwell": 220.0, &"the_scrivener": 225.0,
}
const DEFAULT_HEIGHT := 170.0
## Boss figures are drawn this much larger than a regular enemy (shrunk only if the stage is too short).
const BOSS_SCALE := 1.5
## An elite enemy (map mode, docs/MAP_DESIGN.md "Phase 5") is drawn this much larger than a regular one.
const ELITE_SCALE := 1.1
## A boss is never fitted below this multiple of the regular figure height.
const BOSS_MIN_SCALE := 1.1
const SHAKE_TIME := 0.5
## The stage is roomy, so every figure is drawn this much larger than the table above.
const HEIGHT_SCALE := 1.2
## The player figure height before HEIGHT_SCALE.
const PLAYER_HEIGHT := 205.0
## Per-class size of the player figure (a multiple of PLAYER_HEIGHT); the Stray is a broad four-legged mastiff, so it is drawn smaller to stand as tall as the others look.
const PLAYER_HEIGHT_FACTOR := {CharacterIds.STRAY: 0.72}
## Class colours of the code-drawn player stand-in: cloak, accent.
const CLASS_COLORS := {
	CharacterIds.DESERTER: [Color(0.40, 0.30, 0.24), Color(0.92, 0.55, 0.22)],
	CharacterIds.THIEF: [Color(0.16, 0.30, 0.31), Color(0.30, 0.85, 0.80)],
	CharacterIds.MEDIUM: [Color(0.30, 0.22, 0.42), Color(0.72, 0.52, 1.0)],
	CharacterIds.STRAY: [Color(0.14, 0.20, 0.32), Color(0.43, 0.56, 0.76)],
}
## Which way each painted class figure faces as drawn (+1 right, -1 left); the stage mirrors it to face right.
const PLAYER_ART_FACING := {CharacterIds.DESERTER: 1.0, CharacterIds.THIEF: 1.0, CharacterIds.MEDIUM: 1.0, CharacterIds.STRAY: 1.0}
## Painted enemy sprites that face right as drawn (everything else faces left); the stage mirrors them.
const SPRITE_FACES_RIGHT: Array[StringName] = []
const HP_BACK := Color(0.10, 0.04, 0.05)
const SHADOW := Color(0, 0, 0, 0.38)

## Emitted when the figure is clicked while alive (an enemy; the player is not clickable).
signal pressed

var unit: Combatant
## Who an enemy's Omen is aimed at (the player), so its damage shows the number the hit really deals: the
## enemy's Malice and Shaken, then the target's Expose. Null shows the printed number.
var intent_target: Combatant = null
var is_player := false
## Which way the fighter faces: +1 right (the player), -1 left (enemies).
var facing := -1.0
var art_key: StringName = &"ghost"
var class_id: StringName = &""
var figure_height := DEFAULT_HEIGHT
var targeted := false
## Drag-and-drop feedback, see set_drop_hover.
var drop_hover := false
var drop_text := ""
var drop_lost := -1
## A boss is drawn BOSS_SCALE larger and has no per-figure HP bar (the battle shows a wide one on top).
var is_boss := false
## An elite is drawn ELITE_SCALE larger (it keeps its HP bar).
var is_elite := false
## Extra scale of the drawn figure (the boss entrance tweens it up to 1).
var entrance := 1.0
## The figure height of a regular enemy of this kind, before any boss scaling.
var base_height := DEFAULT_HEIGHT
## Seconds of animation so far; only advance() moves it.
var time := 0.0
## Offsets the idle breath so fighters of one type do not breathe in step.
var phase := 0.0
## 0 while alive, 1 once the defeat fade has finished.
var fade := 0.0

var _tex: Texture2D
var _region := Rect2()
## An elite's art (the sprite with its flame aura behind it, on a padded canvas; PaintedArt.ELITE_PADS), or null.
var _elite_tex: Texture2D = null
var _elite_pads := Vector3i.ZERO
## Which way the painted figure faces as drawn (the enemy art looks left).
var _art_facing := -1.0
## Floating number for damage the Block absorbed (blue, against the red of HP lost).
const BLOCKED_COLOR := Color(0.55, 0.78, 1.0)

## Child control above the drag ghost that draws the drop label (see set_drop_hover).
var _drop_layer: Control
## Draws the fighter and its drop label (see _draw); it reads the animation values below.
var _painter: FighterPainter
var _flash := 0.0
var _shake := 0.0
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
## Scratch list of the reactions due this frame, reused so _process allocates nothing.
var _due: Array[Dictionary] = []
## HP the battle already scheduled hits for, so refresh() does not react to the same loss twice.
var _scheduled_loss := 0
var _scheduled_block := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP # also needed for the status tooltip
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_painter = FighterPainter.new(self)


func _ready() -> void:
	add_to_group(Motion.FOLLOWERS)
	_drop_layer = Control.new()
	_drop_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drop_layer.z_index = DROP_LABEL_Z
	_drop_layer.size = size
	_drop_layer.draw.connect(_painter.draw_drop_label)
	add_child(_drop_layer)
	visibility_changed.connect(_on_visibility_changed)
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))
	_on_visibility_changed()


func _on_visibility_changed() -> void:
	set_process(is_visible_in_tree()) # no cost while hidden


## The Reduce motion setting flipped while this fighter is on screen: wake it so it follows the new value
## (breathing comes back, or advance() sees there is nothing left to animate and stops it again).
func _on_motion_changed() -> void:
	_idle_accum = 0.0
	_wake()


## Turns the per-frame animation back on after the fighter went idle (see _is_idle).
func _wake() -> void:
	if is_inside_tree():
		set_process(is_visible_in_tree())
	queue_redraw()


## True when nothing on this fighter can change its picture any more: it is fully faded out (defeated) and has no
## reaction, floating number or flash left. A living fighter always breathes, so it is never idle.
func _is_idle() -> bool:
	return unit != null and (Motion.reduced or (fade >= 1.0 and is_defeated())) and _floats.is_empty() and _reactions.is_empty() \
		and _flash <= 0.0 and _shake <= 0.0 and _recoil <= 0.0 and _pop <= 0.0 and _lunge <= 0.0


## Redraws per second while a living fighter only breathes.
const IDLE_REDRAW_HZ := 30.0
var _idle_accum := 0.0


## True while something faster than breathing is animating, so the picture must redraw on every frame.
func _is_busy() -> bool:
	return _lunge > 0.0 or _lunge_delay > 0.0 or _flash > 0.0 or _shake > 0.0 or _recoil > 0.0 or _pop > 0.0 \
		or not _reactions.is_empty() or not _floats.is_empty() or entrance < 1.0 \
		or fade != (1.0 if is_defeated() else 0.0)


func _process(delta: float) -> void:
	# motion-ok: advance() holds still under Motion.reduced (ui_reduced_motion_test checks it)
	advance(delta)


## Shows an enemy from scratch: picks its figure and snaps every animation to its resting state.
func set_enemy(enemy: EnemyUnit, boss := false, elite := false) -> void:
	is_boss = boss
	is_elite = elite
	entrance = 1.0
	is_player = false
	facing = -1.0
	_art_facing = -1.0
	unit = enemy
	art_key = art_key_for(enemy.data.id)
	base_height = float(HEIGHTS.get(art_key, DEFAULT_HEIGHT)) * HEIGHT_SCALE
	figure_height = base_height * (BOSS_SCALE if boss else (ELITE_SCALE if elite else 1.0))
	_tex = null
	_elite_tex = null
	var fig := PaintedArt.enemy_figure(art_key)
	if not fig.is_empty():
		_tex = fig.tex
		_region = fig.region
		_art_facing = 1.0 if fig.get("sprite", false) and SPRITE_FACES_RIGHT.has(art_key) else -1.0
		if elite and not boss and fig.get("sprite", false):
			var elite_fig := PaintedArt.enemy_elite_figure(art_key)
			if not elite_fig.is_empty():
				_elite_tex = elite_fig.tex
				_elite_pads = elite_fig.pads
	_reset()


## Shows the player from scratch. `id` is the character id (picks the stand-in colours).
func set_player(player: Combatant, id: StringName) -> void:
	is_player = true
	facing = 1.0
	unit = player
	class_id = id
	figure_height = PLAYER_HEIGHT * float(PLAYER_HEIGHT_FACTOR.get(id, 1.0)) * HEIGHT_SCALE
	_tex = null
	_elite_tex = null
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
	_shake = 0.0
	_lunge = 0.0
	_lunge_delay = 0.0
	_recoil = 0.0
	_pop = 0.0
	_floats.clear()
	fade = 1.0 if is_defeated() else 0.0
	_resize()
	_wake()


func _resize() -> void:
	custom_minimum_size = Vector2(maxf(figure_width() + 20.0, MIN_WIDTH), OVERHEAD + figure_height + UNDER)
	size = custom_minimum_size
	if _drop_layer != null:
		_drop_layer.size = size
	queue_redraw()


## Boss only: shrinks the figure so the whole control (intent above, bar room below) is at most `max_total`
## tall, but never below BOSS_MIN_SCALE times a regular figure. Restores the full boss size when it fits.
func fit_boss(max_total: float) -> void:
	if not is_boss:
		return
	var room := max_total - OVERHEAD - UNDER
	figure_height = clampf(room, base_height * BOSS_MIN_SCALE, base_height * BOSS_SCALE)
	_resize()


## A short sideways shake of the whole figure (a boss changing phase).
func shake() -> void:
	if Motion.reduced:
		return
	_shake = 1.0
	_wake()


## Current shake strength, 1 down to 0 (read by tests).
func shake_amount() -> float:
	return _shake


## The art key for an enemy id; unknown ids get the generic ghost.
static func art_key_for(enemy_id: StringName) -> StringName:
	return ART_KEYS.get(enemy_id, &"ghost")


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
	_wake()


## While a card is dragged over this enemy: ring it, show the card's result on it as a label
## (`text` such as "Deals 15 (6 vs Exposed), 2 after Block") and ghost the HP it would take
## (`lost`, -1 for none) on the bar. set_drop_hover(false) clears all three.
func set_drop_hover(on: bool, text := "", lost := -1) -> void:
	drop_hover = on
	drop_text = text.strip_edges() if on else ""
	drop_lost = lost if on else -1
	_drop_layer.queue_redraw()
	queue_redraw()


## Reads the unit's current state and starts the reactions to what changed: a hit flashes and recoils
## and floats the damage, Block gained pops the shield, Block that soaked a hit says so, healing floats.
func refresh() -> void:
	if unit == null:
		return
	if unit.hp < _last_hp:
		var extra := maxi(_last_hp - unit.hp - _scheduled_loss, 0)
		if extra > 0:
			_react(extra, react_delay, maxi(_last_block - unit.block, 0))
	elif unit.hp > _last_hp:
		_react(_last_hp - unit.hp, react_delay)
	if unit.block > _last_block:
		_pop = 0.0 if Motion.reduced else 1.0
	elif unit.block < _last_block and unit.hp >= _last_hp and not _scheduled_block:
		_react(0, react_delay)
	_last_hp = unit.hp
	_last_block = unit.block
	_scheduled_loss = 0
	_scheduled_block = false
	react_delay = 0.0
	_wake()


## Plays a hit (or, with 0, a fully blocked hit) after `delay` seconds, and tells the next refresh() not to
## react to it again. The battle uses it so each enemy's hit on the player lands with that enemy's lunge.
func schedule_hit(amount: int, delay: float, blocked := 0) -> void:
	_scheduled_loss += amount
	_wake()
	if amount == 0:
		_scheduled_block = true
	_react(amount, delay, blocked)


func _react(amount: int, delay: float, blocked := 0) -> void:
	if delay <= 0.0:
		_play_reaction(amount, blocked)
	else:
		_reactions.append({"t": delay, "amount": amount, "blocked": blocked})


func _play_reaction(amount: int, blocked := 0) -> void:
	if amount > 0:
		if not Motion.reduced:
			_flash = 1.0
			_recoil = 1.0
		_float("-%d" % amount, Color(1.0, 0.42, 0.38))
		if blocked > 0:
			_float("%d blocked" % blocked, BLOCKED_COLOR)
	elif amount < 0:
		_float("+%d" % -amount, Color(0.55, 1.0, 0.55))
	else:
		_float("Blocked", BLOCKED_COLOR)


## A lunge toward the opponent, starting after `delay` seconds (so a row of enemies attack one by one).
func play_attack(delay := 0.0) -> void:
	if Motion.reduced:
		return
	_lunge = 1.0
	_lunge_delay = delay
	_wake()


func _float(txt: String, col: Color) -> void:
	_floats.append({"text": txt, "color": col, "age": 0.0, "drift": float(_floats.size() % 3 - 1) * 14.0})


## Number of floating numbers still on screen (read by tests).
func float_count() -> int:
	return _floats.size()


## Steps the animation. Does nothing unless the view is on screen.
func advance(delta: float) -> void:
	if not is_visible_in_tree():
		return
	if not Motion.reduced:
		time += delta # breathing, weight shifts and the target marker's bob all run off this clock
	if _lunge_delay > 0.0:
		_lunge_delay -= delta
	else:
		_lunge = maxf(_lunge - delta / LUNGE_TIME, 0.0)
	_flash = maxf(_flash - delta / FLASH_TIME, 0.0)
	_shake = maxf(_shake - delta / SHAKE_TIME, 0.0)
	_recoil = maxf(_recoil - delta / RECOIL_TIME, 0.0)
	_pop = maxf(_pop - delta / POP_TIME, 0.0)
	# Age the reactions and play the ones that are due, compacting the array in place (no per-frame allocation).
	var kept := 0
	_due.clear()
	for r in _reactions:
		r.t -= delta
		if r.t <= 0.0:
			_due.append(r)
		else:
			_reactions[kept] = r
			kept += 1
	if not _due.is_empty():
		_reactions.resize(kept)
		for r in _due:
			_play_reaction(r.amount, r.get("blocked", 0))
	fade = move_toward(fade, 1.0 if is_defeated() else 0.0, 1.0 if Motion.reduced else delta / FADE_TIME)
	var live := 0
	for f in _floats:
		f.age += delta
		if f.age < FLOAT_TIME:
			_floats[live] = f
			live += 1
	if live < _floats.size():
		_floats.resize(live)
	# Only the slow idle breathing is throttled (to IDLE_REDRAW_HZ); any attack, hit, flash or float redraws every frame.
	_idle_accum += delta
	if _is_busy() or _idle_accum >= 1.0 / IDLE_REDRAW_HZ:
		_idle_accum = 0.0
		queue_redraw()
	if _is_idle():
		set_process(false) # one last redraw above; refresh()/set_*()/play_attack() wake it again


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
			CharacterIds.DESERTER:
				speed = 1.8
				strength = 0.8
			CharacterIds.THIEF:
				speed = 2.8
				strength = 1.15
			CharacterIds.MEDIUM:
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


## The statuses shown as pills, in display order: {kind, value, label, text, color}. `label` is what the
## pill shows next to its glyph: the turns for Exposed, Haunt, Shaken and Frayed, the signed stack for
## Malice and Ward (a debuff is tinted red), the amount for Hold and Thorns.
func status_chips() -> Array[Dictionary]:
	var chips: Array[Dictionary] = []
	if unit == null:
		return chips
	var exposed := unit.status_turns(Combatant.Status.EXPOSED)
	if exposed > 0:
		chips.append(_chip(&"exposed", exposed, "Exposed %d" % exposed, CardView.kind_color(CardEffect.Kind.EXPOSE)))
	var haunted := unit.status_turns(Combatant.Status.HAUNTED)
	if haunted > 0:
		chips.append(_chip(&"haunt", haunted, "Haunt %d" % haunted, CardView.kind_color(CardEffect.Kind.HAUNT)))
	var shaken := unit.stacks(Combatant.Status.SHAKEN)
	if shaken > 0:
		chips.append(_chip(&"shaken", shaken, "Shaken %d" % shaken, CardView.kind_color(CardEffect.Kind.SHAKEN)))
	var frayed := unit.stacks(Combatant.Status.FRAYED)
	if frayed > 0:
		chips.append(_chip(&"frayed", frayed, "Frayed %d" % frayed, CardView.kind_color(CardEffect.Kind.FRAYED)))
	var malice := unit.stacks(Combatant.Status.MALICE)
	if malice != 0:
		chips.append(_chip(&"malice", malice, "Malice %+d" % malice, CardView.kind_color(CardEffect.Kind.MALICE) if malice > 0 else CardView.STATUS_NEGATIVE, "%+d" % malice))
	var ward := unit.stacks(Combatant.Status.WARD)
	if ward != 0:
		chips.append(_chip(&"ward", ward, "Ward %+d" % ward, CardView.kind_color(CardEffect.Kind.WARD) if ward > 0 else CardView.STATUS_NEGATIVE, "%+d" % ward))
	var scent := unit.stacks(Combatant.Status.SCENT)
	if scent > 0:
		chips.append(_chip(&"scent", scent, "Scent %d" % scent, CardView.kind_color(CardEffect.Kind.SCENT)))
	if unit.hold > 0:
		chips.append(_chip(&"hold", unit.hold, "Hold %d" % unit.hold, CardView.kind_color(CardEffect.Kind.HOLD)))
	if unit.thorns > 0:
		chips.append(_chip(&"thorns", unit.thorns, "Thorns %d" % unit.thorns, CardView.kind_color(CardEffect.Kind.THORNS)))
	var enemy := unit as EnemyUnit
	if enemy != null and enemy.data != null and enemy.data.unseen:
		chips.append(_chip(&"unseen", 1, "Unseen: cannot be targeted while another enemy is alive", Color(0.66, 0.70, 0.84), "?"))
	return chips


static func _chip(kind: StringName, value: int, text: String, color: Color, label := "") -> Dictionary:
	return {"kind": kind, "value": value, "text": text, "color": color, "label": label if label != "" else str(value)}


## Where each status pill is drawn, in the order of status_chips(): centered rows under the HP bar. A row
## holds as many pills as fit the figure's width; the rest wrap onto the next row.
func chip_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var chips := status_chips()
	var font: Font = ThemeDB.fallback_font
	var widths: Array[float] = []
	for chip in chips:
		widths.append(font.get_string_size(chip.label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 19.0)
	var room := maxf(size.x - 4.0, 60.0)
	var y := bar_rect().end.y + 5.0
	var start := 0
	while start < widths.size():
		var end := start
		var total := 0.0
		while end < widths.size() and (end == start or total + CHIP_GAP + widths[end] <= room):
			total += widths[end] + (CHIP_GAP if end > start else 0.0)
			end += 1
		var x := size.x / 2.0 - total / 2.0
		for i in range(start, end):
			rects.append(Rect2(x, y, widths[i], CHIP_H))
			x += widths[i] + CHIP_GAP
		y += CHIP_H + 2.0
		start = end
	return rects


## The Omen of `enemy` as it will really land on `target`: a damage intent carries the number after the
## enemy's Malice and Shaken and the target's Expose (Combatant.hit_damage), a Block intent the number
## after the enemy's Ward and Frayed. Any other intent, or no target, is returned as printed.
static func effective_intent(enemy: EnemyUnit, target: Combatant) -> CardEffect:
	var intent := enemy.current_intent() if enemy != null else null
	if intent == null or target == null:
		return intent
	var effective := intent.amount
	if intent.kind == CardEffect.Kind.DAMAGE:
		effective = Combatant.hit_damage(intent.amount, enemy, target)
	elif intent.kind == CardEffect.Kind.BLOCK:
		effective = enemy.block_from_card(intent.amount)
	if effective == intent.amount:
		return intent
	var shown := intent.duplicate() as CardEffect
	shown.amount = effective
	return shown


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

## Everything on screen is drawn by FighterPainter (run/fighter_painter.gd).
func _draw() -> void:
	_painter.draw()


## A flat ellipse of radius `rx` (a sixth as tall) centred on `c`; only valid while this control draws.
func draw_ellipse_shadow(c: Vector2, rx: float, col: Color) -> void:
	_painter.ellipse_shadow(c, rx, col)


## The short text beside the Omen badge: the amount (signed for Malice and Ward, "3x3" for a multi-hit
## attack) or, for a card an enemy adds, the card's name ("Dread"), so the exact effect is readable.
static func omen_text(intent: CardEffect) -> String:
	if intent.kind in [CardEffect.Kind.MALICE, CardEffect.Kind.WARD]:
		return "%+d" % intent.amount
	if intent.kind == CardEffect.Kind.ADD_CARD and intent.card != null:
		return intent.card.display_name if intent.amount <= 1 else "%dx %s" % [intent.amount, intent.card.display_name]
	if intent.is_damage() and intent.hits > 1:
		return "%dx%d" % [intent.amount, intent.hits]
	return str(intent.amount)

