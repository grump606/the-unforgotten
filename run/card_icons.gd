class_name CardIcons
extends RefCounted
## The effect-kind icons on a card face: which icon leads a card, which weapon variant a plain Deal shows,
## and the drawing of every glyph. Everything is static and draws onto the CanvasItem it is handed (a CardView
## during its _draw), so the card keeps layout and state and this file keeps the art.

## Primary icon = the first of these that the card has (scaled damage reads before plain damage).
const ICON_PRIORITY: Array[CardEffect.Kind] = [
	CardEffect.Kind.DAMAGE_PER_BLOCK, CardEffect.Kind.DAMAGE_IF_BLOCK, CardEffect.Kind.DAMAGE_PER_PLAY,
	CardEffect.Kind.DAMAGE_PER_HAUNT, CardEffect.Kind.DAMAGE_PER_FORGOTTEN, CardEffect.Kind.DAMAGE_PER_SCENT, CardEffect.Kind.DAMAGE, CardEffect.Kind.HAUNT, CardEffect.Kind.BLOCK,
	CardEffect.Kind.THORNS, CardEffect.Kind.EXPOSE, CardEffect.Kind.HOLD, CardEffect.Kind.GAIN_ENERGY,
	CardEffect.Kind.DRAW, CardEffect.Kind.HEAL_PER_HAUNTED, CardEffect.Kind.LOSE_HP,
	CardEffect.Kind.SHAKEN, CardEffect.Kind.FRAYED, CardEffect.Kind.MALICE, CardEffect.Kind.WARD,
	CardEffect.Kind.GLIMPSE, CardEffect.Kind.ADD_CARD, CardEffect.Kind.RECALL, CardEffect.Kind.SCENT,
]
## Every kind that draw_icon has a glyph for (a test walks CardEffect.Kind and fails if one is missing, so a
## new kind cannot silently draw nothing).
const ICON_KINDS: Array[CardEffect.Kind] = [
	CardEffect.Kind.DAMAGE, CardEffect.Kind.BLOCK, CardEffect.Kind.DRAW, CardEffect.Kind.EXPOSE, CardEffect.Kind.HOLD,
	CardEffect.Kind.DAMAGE_PER_BLOCK, CardEffect.Kind.DAMAGE_IF_BLOCK, CardEffect.Kind.THORNS, CardEffect.Kind.GAIN_ENERGY,
	CardEffect.Kind.DAMAGE_PER_PLAY, CardEffect.Kind.HAUNT, CardEffect.Kind.LOSE_HP, CardEffect.Kind.HEAL_PER_HAUNTED,
	CardEffect.Kind.DAMAGE_PER_HAUNT, CardEffect.Kind.SHAKEN, CardEffect.Kind.FRAYED, CardEffect.Kind.MALICE, CardEffect.Kind.WARD,
	CardEffect.Kind.GLIMPSE, CardEffect.Kind.ADD_CARD, CardEffect.Kind.RECALL, CardEffect.Kind.DAMAGE_PER_FORGOTTEN,
	CardEffect.Kind.SCENT, CardEffect.Kind.DAMAGE_PER_SCENT,
]
const KIND_COLORS := {
	CardEffect.Kind.DAMAGE: Color("#d96b65"), CardEffect.Kind.BLOCK: Color("#83b4cf"),
	CardEffect.Kind.DRAW: Color(0.88, 0.88, 0.92), CardEffect.Kind.EXPOSE: Color(0.96, 0.80, 0.35),
	CardEffect.Kind.HOLD: Color(0.40, 0.82, 0.80), CardEffect.Kind.THORNS: Color(0.58, 0.86, 0.42),
	CardEffect.Kind.GAIN_ENERGY: Color(1.0, 0.88, 0.30), CardEffect.Kind.HAUNT: Color(0.76, 0.70, 1.0),
	CardEffect.Kind.LOSE_HP: Color(0.92, 0.26, 0.32), CardEffect.Kind.HEAL_PER_HAUNTED: Color(0.96, 0.52, 0.62),
	CardEffect.Kind.SHAKEN: Color(0.97, 0.62, 0.30), CardEffect.Kind.FRAYED: Color(0.78, 0.70, 0.55),
	CardEffect.Kind.MALICE: Color(0.84, 0.45, 0.95), CardEffect.Kind.WARD: Color(0.46, 0.62, 1.0),
	CardEffect.Kind.GLIMPSE: Color(0.55, 0.85, 0.95), CardEffect.Kind.ADD_CARD: Color(0.72, 0.84, 0.60), CardEffect.Kind.RECALL: Color(0.90, 0.78, 0.50),
	CardEffect.Kind.DAMAGE_PER_FORGOTTEN: Color("#d96b65"),
	CardEffect.Kind.SCENT: Color(0.62, 0.74, 0.92), CardEffect.Kind.DAMAGE_PER_SCENT: Color("#d96b65"),
}
## Ids that get the fist icon (shoves and body blows), the one per-id exception to the rules below.
const FIST_IDS: Array[StringName] = [&"shove", &"shoulder_charge"]
const HEAVY_DAMAGE := 12
const LIGHT_DAMAGE := 4
## Kinds whose icon already contains a blade, so a plain Deal is not repeated as a secondary glyph.
const DAMAGE_COMPOSITES: Array[int] = [
	CardEffect.Kind.DAMAGE_PER_BLOCK, CardEffect.Kind.DAMAGE_IF_BLOCK, CardEffect.Kind.DAMAGE_PER_PLAY,
	CardEffect.Kind.DAMAGE_PER_HAUNT, CardEffect.Kind.DAMAGE_PER_FORGOTTEN, CardEffect.Kind.DAMAGE_PER_SCENT,
]


static func kind_color(kind: int) -> Color:
	if KIND_COLORS.has(kind):
		return KIND_COLORS[kind]
	return Color(0.95, 0.45, 0.35)


# --- which icon a card shows -------------------------------------------------------------

## The effects whose kinds the icons show: the card's own, plus an Oath's lasting effects.
static func icon_effects(c: CardData) -> Array[CardEffect]:
	if not c.oath or c.oath_effects.is_empty():
		return c.effects
	var all: Array[CardEffect] = []
	all.append_array(c.oath_effects)
	all.append_array(c.effects)
	return all


## The effect kind whose icon leads the card, or -1 for a card with no effects.
static func primary_kind(c: CardData) -> int:
	for kind in ICON_PRIORITY:
		for effect in icon_effects(c):
			if effect.kind == kind:
				return kind
	return -1


## Which weapon icon a card's plain damage shows, from its own data: class (thief needle,
## medium bone), target (all enemies sweep), id (fist), magnitude (axe 12+, dagger up to 4)
## and cost (a free light hit is a flurry); otherwise a sword. Empty when the card has no DAMAGE
## effect, or for kinds that draw their own composite icon (see docs/CARD_ART_DESIGN.md).
static func icon_variant(c: CardData) -> StringName:
	if c == null:
		return &""
	if primary_kind(c) == CardEffect.Kind.DAMAGE_PER_BLOCK:
		return &"hammer"
	var total := 0
	for effect in icon_effects(c):
		if effect.kind == CardEffect.Kind.DAMAGE:
			total += effect.amount
	if total <= 0 or primary_kind(c) != CardEffect.Kind.DAMAGE:
		return &""
	if c.character == &"thief":
		return &"needle"
	if c.character == &"medium":
		return &"bone"
	if c.target_mode == CardData.TargetMode.ALL_ENEMIES:
		return &"sweep"
	if c.id in FIST_IDS:
		return &"fist"
	if total >= HEAVY_DAMAGE:
		return &"axe"
	if total <= LIGHT_DAMAGE:
		return &"flurry" if c.cost == 0 else &"dagger"
	return &"sword"


## Up to three further kinds shown as small glyphs (the primary and its composite parts are skipped).
static func secondary_kinds(c: CardData) -> Array[int]:
	var primary := primary_kind(c)
	var out: Array[int] = []
	for kind in ICON_PRIORITY:
		if kind == primary or out.size() >= 3:
			continue
		if kind == CardEffect.Kind.DAMAGE and primary in DAMAGE_COMPOSITES:
			continue
		for effect in icon_effects(c):
			if effect.kind == kind:
				out.append(kind)
				break
	return out


# --- the art window ----------------------------------------------------------------------

## The big icon (and secondary glyphs) in a card's art window when it has no painted art. `status_card` draws the
## inkblot for a card with no effects at all.
static func draw_card_icons(ci: CanvasItem, card: CardData, win: Rect2, p: Dictionary, status_card: bool) -> void:
	var primary := primary_kind(card)
	if primary < 0:
		if status_card:
			draw_blot(ci, win.get_center(), 15.0, p.accent)
		return
	var window_col: Color = p.window
	var center := win.get_center() + Vector2(0, -1)
	draw_icon(ci, primary, center, 20.0, window_col, icon_variant(card))
	var x := win.end.x - 12.0
	for kind in secondary_kinds(card):
		var pt := Vector2(x, win.end.y - 12.0)
		ci.draw_circle(pt, 10.0, Color(1, 1, 1, 0.14))
		ci.draw_arc(pt, 10.0, 0, TAU, 20, Color(1, 1, 1, 0.45), 1.0, true)
		draw_icon(ci, kind, pt, 6.5, window_col)
		x -= 23.0


## A status card's art: a ragged inkblot with a few drips.
static func draw_blot(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 18:
		var a := TAU * i / 18.0
		pts.append(c + Vector2.from_angle(a) * r * (0.62 + 0.38 * absf(sin(a * 2.5 + 0.7))))
	ci.draw_colored_polygon(pts, Color(col, 0.55))
	for dx in [-0.5, 0.1, 0.6]:
		ci.draw_line(c + Vector2(dx, 0.6) * r, c + Vector2(dx, 1.15 + dx * 0.3) * r, Color(col, 0.55), 2.0)
	ci.draw_circle(c + Vector2(-0.3, -0.1) * r, r * 0.12, Color(0, 0, 0, 0.6))
	ci.draw_circle(c + Vector2(0.25, -0.1) * r, r * 0.12, Color(0, 0, 0, 0.6))


# --- shape helpers -----------------------------------------------------------------------
# Every icon is built from unit-space points (about -1..1) scaled by r around c.

static func _pts(unit: Array, c: Vector2, r: float, rot := 0.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	for u in unit:
		out.append(c + (u as Vector2).rotated(rot) * r)
	return out


static func _fill(ci: CanvasItem, points: PackedVector2Array, col: Color, outline := true) -> void:
	ci.draw_colored_polygon(points, col)
	if outline:
		var closed := points.duplicate()
		closed.append(points[0])
		ci.draw_polyline(closed, Color(0, 0, 0, 0.55), 1.2, true)


static func _drop(tip: Vector2, w: float) -> PackedVector2Array:
	# A teardrop whose point is at `tip` and whose belly is w wide.
	var out := PackedVector2Array([tip])
	var center := tip + Vector2(0, w * 1.5)
	for i in range(0, 15):
		var a := deg_to_rad(-50.0 + 280.0 * i / 14.0)
		out.append(center + Vector2.from_angle(a) * w)
	return out


static func _heart(c: Vector2, r: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in 24:
		var t := TAU * i / 24.0
		var x := 16.0 * pow(sin(t), 3)
		var y := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		out.append(c + Vector2(x, y + 1.0) / 17.0 * r)
	return out


static func _shield_pts(c: Vector2, r: float) -> PackedVector2Array:
	return _pts([Vector2(-0.8, -0.85), Vector2(0, -1.0), Vector2(0.8, -0.85), Vector2(0.8, 0.1), Vector2(0.45, 0.65), Vector2(0, 1.0), Vector2(-0.45, 0.65), Vector2(-0.8, 0.1)], c, r)


# --- parts: blade, hammer, shield, ghost, scent trail ----------------------------------------

static func _blade(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var rot := PI / 4.0
	_fill(ci, _pts([Vector2(0, -1.0), Vector2(0.17, -0.78), Vector2(0.17, 0.25), Vector2(-0.17, 0.25), Vector2(-0.17, -0.78)], c, r, rot), col)
	_fill(ci, _pts([Vector2(-0.5, 0.25), Vector2(0.5, 0.25), Vector2(0.5, 0.4), Vector2(-0.5, 0.4)], c, r, rot), col.darkened(0.25))
	_fill(ci, _pts([Vector2(-0.08, 0.4), Vector2(0.08, 0.4), Vector2(0.08, 0.85), Vector2(-0.08, 0.85)], c, r, rot), col.darkened(0.4), false)


static func _hammer(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var rot := PI / 4.0
	_fill(ci, _pts([Vector2(-0.09, -0.6), Vector2(0.09, -0.6), Vector2(0.09, 1.0), Vector2(-0.09, 1.0)], c, r, rot), col.darkened(0.4), false)
	_fill(ci, _pts([Vector2(-0.6, -1.0), Vector2(0.6, -1.0), Vector2(0.6, -0.35), Vector2(-0.6, -0.35)], c, r, rot), col)


static func _shield(ci: CanvasItem, c: Vector2, r: float, col: Color, window_col: Color) -> void:
	_fill(ci, _shield_pts(c, r), col)
	ci.draw_line(c + Vector2(0, -0.8) * r, c + Vector2(0, 0.8) * r, window_col, maxf(1.0, r * 0.14))
	ci.draw_line(c + Vector2(-0.6, -0.2) * r, c + Vector2(0.6, -0.2) * r, window_col, maxf(1.0, r * 0.14))


static func _ghost(ci: CanvasItem, c: Vector2, r: float, col: Color, window_col: Color) -> void:
	var u: Array = []
	for i in 13:
		var a := PI + PI * i / 12.0
		u.append(Vector2(cos(a) * 0.7, -0.15 + sin(a) * 0.7))
	u.append_array([Vector2(0.7, 0.9), Vector2(0.35, 0.62), Vector2(0, 0.9), Vector2(-0.35, 0.62), Vector2(-0.7, 0.9)])
	_fill(ci, _pts(u, c, r), col)
	ci.draw_circle(c + Vector2(-0.25, -0.2) * r, maxf(0.9, r * 0.13), window_col)
	ci.draw_circle(c + Vector2(0.25, -0.2) * r, maxf(0.9, r * 0.13), window_col)


## A scent trail: three growing drops along a drifting line (placeholder glyph until the card art is designed).
static func _scent_trail(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array([c + Vector2(-0.8, 0.5) * r, c + Vector2(-0.3, 0.1) * r, c + Vector2(0.1, 0.3) * r, c + Vector2(0.55, -0.2) * r])
	ci.draw_polyline(pts, Color(col, 0.55), 1.5, true)
	ci.draw_circle(c + Vector2(-0.6, 0.55) * r, r * 0.12, col)
	ci.draw_circle(c + Vector2(-0.05, 0.2) * r, r * 0.18, col)
	ci.draw_circle(c + Vector2(0.6, -0.25) * r, r * 0.26, col)


## Plain-damage icon for a variant from icon_variant(); unknown or empty is the sword.
static func _weapon(ci: CanvasItem, variant: StringName, c: Vector2, r: float, col: Color, window_col: Color) -> void:
	var rot := PI / 4.0
	match variant:
		&"dagger":
			# Short, broad blade with a small guard: reads as a light stab.
			_fill(ci, _pts([Vector2(0, -0.8), Vector2(0.26, -0.45), Vector2(0.24, 0.3), Vector2(-0.24, 0.3), Vector2(-0.26, -0.45)], c, r, rot), col)
			_fill(ci, _pts([Vector2(-0.5, 0.3), Vector2(0.5, 0.3), Vector2(0.5, 0.46), Vector2(-0.5, 0.46)], c, r, rot), col.darkened(0.25))
			_fill(ci, _pts([Vector2(-0.1, 0.46), Vector2(0.1, 0.46), Vector2(0.1, 0.85), Vector2(-0.1, 0.85)], c, r, rot), col.darkened(0.4), false)
		&"axe":
			# Long haft with a big crescent head: reads as a heavy chop.
			_fill(ci, _pts([Vector2(-0.09, -0.9), Vector2(0.09, -0.9), Vector2(0.09, 1.0), Vector2(-0.09, 1.0)], c, r * 0.82, rot), col.darkened(0.4), false)
			_fill(ci, _pts([Vector2(0.09, -0.95), Vector2(-0.55, -1.05), Vector2(-0.95, -0.85), Vector2(-0.75, -0.4), Vector2(-0.95, 0.05), Vector2(-0.5, 0.15), Vector2(0.09, -0.05)], c, r * 0.82, rot), col)
		&"fist":
			# Fist from the side with motion lines.
			for i in 3:
				ci.draw_line(c + Vector2(-1.0, -0.4 + 0.45 * i) * r, c + Vector2(-0.55 + 0.1 * i, -0.4 + 0.45 * i) * r, Color(col, 0.7), maxf(1.2, r * 0.1))
			_fill(ci, _pts([Vector2(-0.3, -0.35), Vector2(0.75, -0.35), Vector2(0.9, 0.3), Vector2(0.65, 0.85), Vector2(-0.3, 0.85)], c, r), col)
			for i in 4:
				var f := c + Vector2(-0.18 + 0.28 * i, -0.38) * r
				ci.draw_circle(f, r * 0.19, col)
				ci.draw_arc(f, r * 0.19, PI, TAU, 8, Color(0, 0, 0, 0.5), 1.0, true)
			ci.draw_line(c + Vector2(0.1, 0.1) * r, c + Vector2(0.75, 0.1) * r, window_col, maxf(1.0, r * 0.09))
		&"flurry":
			# Three quick parallel slashes.
			for i in 3:
				var o := (i - 1) * 0.55
				_fill(ci, _pts([Vector2(0.9, -0.9), Vector2(0.15, 0.0), Vector2(-0.8, 0.8), Vector2(-0.15, -0.05)], c + Vector2(o, 0.0) * r, r * 0.8), col if i == 1 else col.lightened(0.15))
		&"needle":
			# A long, bold pin with a ring eye and a short thread: a precise prick.
			_fill(ci, _pts([Vector2(0, -1.15), Vector2(0.1, -0.85), Vector2(0.1, 0.55), Vector2(-0.1, 0.55), Vector2(-0.1, -0.85)], c, r, rot), col.lightened(0.2))
			ci.draw_arc(c + Vector2(-0.53, 0.53) * r, r * 0.17, 0, TAU, 14, col.lightened(0.2), maxf(1.4, r * 0.12), true)
			var thread := PackedVector2Array()
			for i in 8:
				thread.append(c + Vector2(-0.68 - 0.07 * i, 0.62 + 0.05 * i + sin(i * 1.4) * 0.1) * r)
			ci.draw_polyline(thread, Color(col.lightened(0.2), 0.8), maxf(1.2, r * 0.08), true)
		&"bone":
			# A pale bone (shaft with two knobbed ends): a spectral club.
			var bone := col.lerp(Color(0.92, 0.88, 0.80), 0.6)
			_fill(ci, _pts([Vector2(-0.12, -0.75), Vector2(0.12, -0.75), Vector2(0.12, 0.75), Vector2(-0.12, 0.75)], c, r, rot), bone)
			for end in [-0.85, 0.85]:
				for side in [-0.17, 0.17]:
					var kp := c + Vector2(side, end).rotated(rot) * r
					ci.draw_circle(kp, r * 0.2, bone)
					ci.draw_arc(kp, r * 0.2, 0, TAU, 12, Color(0, 0, 0, 0.5), 1.0, true)
		&"sweep":
			# Wide arc slash across the whole window.
			var u: Array = []
			for i in 13:
				var a := deg_to_rad(205.0 + 130.0 * i / 12.0)
				u.append(Vector2(cos(a) * 1.15, 0.7 + sin(a) * 0.95))
			for i in 13:
				var a := deg_to_rad(335.0 - 130.0 * i / 12.0)
				u.append(Vector2(cos(a) * 1.0, 0.75 + sin(a) * 0.55))
			_fill(ci, _pts(u, c + Vector2(0, -0.2) * r, r), col)
		_:
			_blade(ci, c, r, col)


# --- one icon per effect kind ------------------------------------------------------------

## Draws the icon for one effect kind at centre c, radius r. `window_col` cuts details out of it.
static func draw_icon(ci: CanvasItem, kind: int, c: Vector2, r: float, window_col: Color, variant := &"") -> void:
	var col := kind_color(kind)
	match kind:
		CardEffect.Kind.DAMAGE, CardEffect.Kind.DAMAGE_PER_BLOCK, CardEffect.Kind.DAMAGE_IF_BLOCK, \
		CardEffect.Kind.DAMAGE_PER_PLAY, CardEffect.Kind.DAMAGE_PER_HAUNT, CardEffect.Kind.DAMAGE_PER_FORGOTTEN, \
		CardEffect.Kind.DAMAGE_PER_SCENT:
			_draw_damage_icon(ci, kind, c, r, col, window_col, variant)
		CardEffect.Kind.BLOCK, CardEffect.Kind.WARD, CardEffect.Kind.HOLD, CardEffect.Kind.THORNS:
			_draw_defence_icon(ci, kind, c, r, col, window_col)
		CardEffect.Kind.EXPOSE, CardEffect.Kind.HAUNT, CardEffect.Kind.SHAKEN, CardEffect.Kind.FRAYED, \
		CardEffect.Kind.MALICE, CardEffect.Kind.SCENT:
			_draw_status_icon(ci, kind, c, r, col, window_col)
		_:
			_draw_resource_icon(ci, kind, c, r, col, window_col)


## Deal and the damage-scaling kinds: a weapon, or a blade combined with the thing the damage scales with.
static func _draw_damage_icon(ci: CanvasItem, kind: int, c: Vector2, r: float, col: Color, window_col: Color, variant: StringName) -> void:
	var damage: Color = KIND_COLORS[CardEffect.Kind.DAMAGE]
	match kind:
		CardEffect.Kind.DAMAGE:
			_weapon(ci, variant, c, r * 1.25, col, window_col)
		CardEffect.Kind.DAMAGE_PER_BLOCK:
			_shield(ci, c + Vector2(-0.15, 0.1) * r, r * 0.85, KIND_COLORS[CardEffect.Kind.BLOCK], window_col)
			_hammer(ci, c + Vector2(0.3, -0.2) * r, r * 0.95, damage)
		CardEffect.Kind.DAMAGE_IF_BLOCK:
			_blade(ci, c + Vector2(0.1, -0.1) * r, r * 1.0, damage)
			_shield(ci, c + Vector2(-0.55, 0.5) * r, r * 0.5, KIND_COLORS[CardEffect.Kind.BLOCK], window_col)
		CardEffect.Kind.DAMAGE_PER_PLAY:
			_blade(ci, c + Vector2(-0.2, -0.1) * r, r * 0.95, damage)
			for i in 3:
				var h := (0.35 + 0.3 * i) * r
				ci.draw_rect(Rect2(c + Vector2(0.45 + 0.28 * i, 0.9) * r - Vector2(0, h), Vector2(0.18 * r, h)), KIND_COLORS[CardEffect.Kind.EXPOSE])
		CardEffect.Kind.DAMAGE_PER_HAUNT:
			_ghost(ci, c + Vector2(-0.15, 0.1) * r, r * 0.85, KIND_COLORS[CardEffect.Kind.HAUNT], window_col)
			_blade(ci, c + Vector2(0.35, -0.25) * r, r * 0.8, damage)
		CardEffect.Kind.DAMAGE_PER_FORGOTTEN:
			# A pile of cards under a blade: damage that grows with the Forgotten pile.
			for i in 3:
				var o := Vector2(-0.45 + 0.12 * i, 0.55 - 0.2 * i)
				_fill(ci, _pts([Vector2(-0.6, -0.3), Vector2(0.6, -0.3), Vector2(0.6, 0.3), Vector2(-0.6, 0.3)], c + o * r, r * 0.8, -0.12 + 0.12 * i), Color(0.55, 0.52, 0.62).lightened(0.12 * i))
			_blade(ci, c + Vector2(0.3, -0.25) * r, r * 0.9, damage)
		CardEffect.Kind.DAMAGE_PER_SCENT:
			_scent_trail(ci, c + Vector2(-0.2, 0.2) * r, r * 0.75, KIND_COLORS[CardEffect.Kind.SCENT])
			_blade(ci, c + Vector2(0.35, -0.25) * r, r * 0.8, damage)


## Block, Ward, Hold and Thorns: shields and spikes.
static func _draw_defence_icon(ci: CanvasItem, kind: int, c: Vector2, r: float, col: Color, window_col: Color) -> void:
	var w := maxf(1.2, r * 0.16)
	match kind:
		CardEffect.Kind.BLOCK:
			_shield(ci, c, r, col, window_col)
		CardEffect.Kind.WARD:
			_shield(ci, c, r, col, window_col)
			ci.draw_arc(c, r * 1.15, 0, TAU, 24, Color(col, 0.55), w, true)
		CardEffect.Kind.HOLD:
			var outline := _shield_pts(c, r)
			outline.append(outline[0])
			ci.draw_polyline(outline, col, w * 1.3, true)
			ci.draw_rect(Rect2(c + Vector2(-0.3, 0.0) * r, Vector2(0.6, 0.5) * r), col)
			ci.draw_arc(c + Vector2(0, 0.0) * r, r * 0.22, PI, TAU, 10, col, w * 1.2, true)
		CardEffect.Kind.THORNS:
			var u: Array = []
			for i in 16:
				u.append(Vector2.from_angle(i * TAU / 16.0 - PI / 2.0) * (1.0 if i % 2 == 0 else 0.45))
			_fill(ci, _pts(u, c, r), col)


## Expose, Haunt, Shaken, Frayed, Malice and Scent: the statuses a card applies.
static func _draw_status_icon(ci: CanvasItem, kind: int, c: Vector2, r: float, col: Color, window_col: Color) -> void:
	var w := maxf(1.2, r * 0.16)
	match kind:
		CardEffect.Kind.EXPOSE:
			ci.draw_arc(c, r * 0.62, 0, TAU, 28, col, w * 1.3, true)
			for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				ci.draw_line(c + d * r * 0.35, c + d * r * 1.0, col, w * 1.3)
			ci.draw_circle(c, r * 0.18, col)
		CardEffect.Kind.HAUNT:
			_ghost(ci, c, r, col, window_col)
		CardEffect.Kind.SHAKEN:
			var zig := PackedVector2Array()
			for i in 7:
				zig.append(c + Vector2(-0.9 + 0.3 * i, (0.55 if i % 2 == 0 else -0.55)) * r)
			ci.draw_polyline(zig, col, w * 1.5, true)
			ci.draw_arc(c, r * 1.0, deg_to_rad(200), deg_to_rad(340), 10, Color(col, 0.6), w, true)
		CardEffect.Kind.FRAYED:
			_fill(ci, _pts([Vector2(-0.8, -0.8), Vector2(0.8, -0.8), Vector2(0.8, -0.1), Vector2(-0.8, -0.1)], c, r), col)
			for i in 5:
				var x := -0.64 + 0.32 * i
				ci.draw_line(c + Vector2(x, -0.1) * r, c + Vector2(x * 1.35 + 0.1 * (i - 2), 0.9 - 0.12 * (i % 2)) * r, col, w)
		CardEffect.Kind.MALICE:
			_fill(ci, _pts([Vector2(0, -1.0), Vector2(0.85, 0.15), Vector2(0.32, 0.15), Vector2(0.32, 0.95), Vector2(-0.32, 0.95), Vector2(-0.32, 0.15), Vector2(-0.85, 0.15)], c, r), col)
		CardEffect.Kind.SCENT:
			_scent_trail(ci, c, r, col)


## Draw, energy, HP, healing, Glimpse, Add Card and Recall: what a card does to the player's resources and piles.
static func _draw_resource_icon(ci: CanvasItem, kind: int, c: Vector2, r: float, col: Color, window_col: Color) -> void:
	var w := maxf(1.2, r * 0.16)
	match kind:
		CardEffect.Kind.DRAW:
			_fill(ci, _pts([Vector2(-0.7, -0.85), Vector2(0.3, -0.85), Vector2(0.3, 0.45), Vector2(-0.7, 0.45)], c, r), col.darkened(0.35))
			_fill(ci, _pts([Vector2(-0.3, -0.45), Vector2(0.7, -0.45), Vector2(0.7, 0.85), Vector2(-0.3, 0.85)], c, r), col)
			ci.draw_line(c + Vector2(0.0, 0.0) * r, c + Vector2(0.4, 0.0) * r, window_col, w)
			ci.draw_line(c + Vector2(0.0, 0.3) * r, c + Vector2(0.4, 0.3) * r, window_col, w)
		CardEffect.Kind.GAIN_ENERGY:
			_fill(ci, _pts([Vector2(0.2, -1.0), Vector2(-0.55, 0.1), Vector2(-0.05, 0.1), Vector2(-0.3, 1.0), Vector2(0.55, -0.15), Vector2(0.05, -0.15)], c, r), col)
		CardEffect.Kind.LOSE_HP:
			_fill(ci, _drop(c + Vector2(0, -r), r * 0.62), col)
		CardEffect.Kind.HEAL_PER_HAUNTED:
			_fill(ci, _heart(c, r), col)
			ci.draw_line(c + Vector2(0, -0.35) * r, c + Vector2(0, 0.45) * r, window_col, w)
			ci.draw_line(c + Vector2(-0.4, 0.05) * r, c + Vector2(0.4, 0.05) * r, window_col, w)
		CardEffect.Kind.GLIMPSE:
			# An eye: an almond with an iris and a pupil.
			var almond := PackedVector2Array()
			for i in 9:
				var x := -1.0 + 0.25 * i
				almond.append(c + Vector2(x, -0.62 * (1.0 - x * x)) * r)
			for i in 9:
				var x := 1.0 - 0.25 * i
				almond.append(c + Vector2(x, 0.62 * (1.0 - x * x)) * r)
			_fill(ci, almond, col)
			ci.draw_circle(c, r * 0.4, window_col)
			ci.draw_circle(c, r * 0.2, col)
			ci.draw_circle(c + Vector2(0.08, -0.08) * r, r * 0.07, Color(1, 1, 1, 0.8))
		CardEffect.Kind.ADD_CARD:
			# A card with a plus: a darker card behind, the new one in front.
			_fill(ci, _pts([Vector2(-0.8, -0.85), Vector2(0.2, -0.85), Vector2(0.2, 0.55), Vector2(-0.8, 0.55)], c, r), col.darkened(0.4))
			_fill(ci, _pts([Vector2(-0.3, -0.55), Vector2(0.7, -0.55), Vector2(0.7, 0.85), Vector2(-0.3, 0.85)], c, r), col)
			ci.draw_line(c + Vector2(0.2, -0.1) * r, c + Vector2(0.2, 0.55) * r, window_col, w * 1.3)
			ci.draw_line(c + Vector2(-0.12, 0.22) * r, c + Vector2(0.52, 0.22) * r, window_col, w * 1.3)
		CardEffect.Kind.RECALL:
			# A returning arrow: an open circle whose head curls back in.
			var end_angle := deg_to_rad(215)
			ci.draw_arc(c, r * 0.72, deg_to_rad(-60), end_angle, 20, col, w * 1.7, true)
			var tip := c + Vector2.from_angle(end_angle) * r * 0.72
			var along := Vector2.from_angle(end_angle + PI / 2.0)
			var out := Vector2.from_angle(end_angle)
			_fill(ci, PackedVector2Array([tip + along * r * 0.5, tip + out * r * 0.38, tip - out * r * 0.38]), col)
