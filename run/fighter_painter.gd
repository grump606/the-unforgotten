class_name FighterPainter
extends RefCounted
## Draws a Fighter, split out of Fighter so that script keeps the state, layout and animation clock: the target
## ring and marker, the ground shadow, the figure (painted, elite or the code-drawn stand-in) with its lunge,
## recoil, flash and defeat fade, the Omen badge, the HP bar with Block, the status pills, the floating numbers
## and the drag-and-drop ring and label. It only reads the fighter (its animation values included) and draws onto
## it, or onto its drop label layer, during their draw.

## Width of an Omen number at the badge's font size; measured once per distinct text.
static var _number_widths := {}

var _f: Fighter


func _init(fighter: Fighter) -> void:
	_f = fighter


func draw() -> void:
	if _f.unit == null:
		return
	var alive := _f.fade < 1.0
	var a := 1.0 - _f.fade
	var ground := _f.feet()
	if _f.targeted and not _f.is_defeated():
		_draw_target_ring(ground)
	_f.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	ellipse_shadow(ground, _f.figure_width() * 0.42 * (1.0 - _f.fade * 0.5), Color(Fighter.SHADOW, Fighter.SHADOW.a * a))
	_draw_figure(ground, a)
	if alive:
		if not _f.is_player:
			_draw_intent(a)
		if not _f.is_boss:
			_draw_bar(a)
		_draw_chips(a)
	if _f.targeted and not _f.is_defeated():
		var mx := _f.size.x / 2.0
		var my := 4.0 + sin(_f.time * 4.0) * 2.0
		_f.draw_colored_polygon(PackedVector2Array([Vector2(mx - 9, my), Vector2(mx + 9, my), Vector2(mx, my + 9)]), MenuStyle.AMBER)
	if _f.drop_hover and not _f.is_defeated():
		_draw_drop_hover(ground)
	_draw_floats()


## The drag target look: a bright ring at the feet (the label is draw_drop_label).
func _draw_drop_hover(ground: Vector2) -> void:
	var rx := _f.figure_width() * 0.5 + 10.0
	var pts := PackedVector2Array()
	for i in 33:
		var ang := TAU * i / 32.0
		pts.append(ground + Vector2(cos(ang) * rx, sin(ang) * rx * 0.16))
	_f.draw_polyline(pts, Color(1, 1, 1, 0.95), 3.0, true)


## The card's result in a pill over the figure (one line per clause, so it stays narrow); drawn on
## the layer above the drag ghost.
func draw_drop_label() -> void:
	if not _f.drop_hover or _f.is_defeated() or _f.drop_text == "":
		return
	var layer := _f._drop_layer
	var lines := _f.drop_text.split(", ")
	var line_h := 20.0
	var width := 0.0
	for line in lines:
		width = maxf(width, line.length() * 7.5 + 18.0)
	var box := Rect2(Vector2(_f.size.x / 2.0 - width / 2.0, Fighter.OVERHEAD + _f.figure_height * 0.4), Vector2(width, line_h * lines.size() + 6.0))
	HudIcons.box(layer, box, Color(0.04, 0.03, 0.05, 0.92), 8, 2, MenuStyle.AMBER)
	for i in lines.size():
		HudIcons.text(layer, lines[i], Rect2(box.position + Vector2(0, 3.0 + line_h * i), Vector2(width, line_h)), 13, Color(0.97, 0.95, 0.92), true, 3)


## A flat ellipse of radius `rx` (a sixth as tall) centred on `c`: the shadow on the ground.
func ellipse_shadow(c: Vector2, rx: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var ang := TAU * i / 24.0
		pts.append(c + Vector2(cos(ang) * rx, sin(ang) * rx * 0.16))
	_f.draw_colored_polygon(pts, col)


func _draw_target_ring(ground: Vector2) -> void:
	var rx := _f.figure_width() * 0.5 + 8.0
	var pts := PackedVector2Array()
	for i in 33:
		var ang := TAU * i / 32.0
		pts.append(ground + Vector2(cos(ang) * rx, sin(ang) * rx * 0.16))
	_f.draw_polyline(pts, Color(MenuStyle.AMBER, 0.85), 2.0, true)


## The figure standing on its feet with the idle breath, the lunge toward the opponent, the recoil from
## a hit, the hit flash and the defeat fade (it sinks and goes see-through).
func _draw_figure(ground: Vector2, a: float) -> void:
	var f := _f
	var lunge := f.lunge_amount()
	var stance := f.stance_motion()
	var dx := f.facing * (lunge * 46.0) - f.facing * sin(f._recoil * PI) * 16.0
	var shake := sin(f.time * 70.0) * 2.5 * f._flash + sin(f.time * 55.0) * 9.0 * f._shake
	var squash := 1.0 + f.breath() * 0.008 - stance.z + lunge * 0.04
	var stretch := 1.0 + lunge * 0.04
	var sink := f.fade * 18.0
	var tint := Color(1, 1, 1, a)
	if f._flash > 0.0:
		tint = Color(1.0, 1.0 - f._flash * 0.6, 1.0 - f._flash * 0.6, a)
	elif f._hovered and not f.is_defeated() and not f.is_player:
		tint = Color(1.12, 1.12, 1.12, a)
	var flip := 1.0 if is_equal_approx(f.facing, f._art_facing) else -1.0
	f.draw_set_transform(ground + Vector2(dx + shake + stance.x, sink), stance.y, Vector2(stretch * flip, squash) * (1.0 if Motion.reduced else f.entrance))
	if f._elite_tex != null:
		# The elite canvas is the plain sprite plus padding for the flames: scale it like the sprite and keep the feet where
		# they were (the padding is the same on both sides, so the mirroring above is harmless).
		var scale := f.figure_height / f._region.size.y
		var tex_size := f._elite_tex.get_size() * scale
		var origin := Vector2(-f.figure_width() / 2.0 - f._elite_pads.x * scale, -f.figure_height - f._elite_pads.y * scale)
		f.draw_texture_rect(f._elite_tex, Rect2(origin, tex_size), false, tint)
	elif f._tex != null:
		var w := f.figure_width()
		f.draw_texture_rect_region(f._tex, Rect2(-w / 2.0, -f.figure_height, w, f.figure_height), f._region, tint)
	else:
		_draw_stand_in(tint)
	f.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The code-drawn figure used when there is no painted one: a cloaked silhouette in the class colours
## (facing right, so the transform in _draw_figure mirrors it for enemies).
func _draw_stand_in(tint: Color) -> void:
	var f := _f
	var colors: Array = Fighter.CLASS_COLORS.get(f.class_id, [Color(0.36, 0.38, 0.44), Color(0.85, 0.90, 1.0)])
	var cloak: Color = (colors[0] as Color) * tint
	var accent: Color = colors[1]
	var h := f.figure_height
	var body := PackedVector2Array([
		Vector2(-0.20, 0.0) * h, Vector2(0.20, 0.0) * h, Vector2(0.17, -0.50) * h, Vector2(0.10, -0.74) * h,
		Vector2(-0.08, -0.74) * h, Vector2(-0.19, -0.50) * h,
	])
	f.draw_colored_polygon(body, cloak)
	f.draw_polyline(body + PackedVector2Array([body[0]]), Color(0, 0, 0, 0.6 * tint.a), 1.5, true)
	# A lighter cloak edge on the side toward the opponent, so the shape reads as lit from the front.
	f.draw_colored_polygon(PackedVector2Array([Vector2(0.10, -0.74) * h, Vector2(0.17, -0.50) * h, Vector2(0.20, 0.0) * h, Vector2(0.12, 0.0) * h, Vector2(0.10, -0.50) * h]), Color(accent, 0.18 * tint.a))
	var head := Vector2(0.03, -0.83) * h
	f.draw_circle(head, 0.095 * h, cloak.darkened(0.25))
	f.draw_arc(head, 0.095 * h, 0, TAU, 24, Color(0, 0, 0, 0.6 * tint.a), 1.5, true)
	var eye := head + Vector2(0.05, 0.0) * h
	f.draw_circle(eye, 0.03 * h, Color(accent, 0.25 * tint.a))
	f.draw_circle(eye, 0.012 * h, Color(accent, tint.a))
	var prop := Color(accent, tint.a)
	match f.class_id:
		CharacterIds.DESERTER: # a sword held low in front
			f.draw_line(Vector2(0.18, -0.30) * h, Vector2(0.42, -0.62) * h, prop.darkened(0.2), 4.0, true)
			f.draw_line(Vector2(0.15, -0.34) * h, Vector2(0.24, -0.26) * h, prop, 3.0, true)
		CharacterIds.THIEF: # a dagger and a coin
			f.draw_line(Vector2(0.18, -0.34) * h, Vector2(0.34, -0.50) * h, prop.darkened(0.2), 3.0, true)
			f.draw_circle(Vector2(0.24, -0.20) * h, 0.03 * h, prop)
		CharacterIds.MEDIUM: # a lantern with a pale flame
			f.draw_line(Vector2(0.17, -0.40) * h, Vector2(0.30, -0.50) * h, prop.darkened(0.3), 2.5, true)
			f.draw_circle(Vector2(0.32, -0.40) * h, 0.07 * h, Color(accent, 0.22 * tint.a))
			f.draw_circle(Vector2(0.32, -0.40) * h, 0.03 * h, prop.lightened(0.3))
		_:
			pass


static func _number_width(number: String) -> float:
	if not _number_widths.has(number):
		_number_widths[number] = ThemeDB.fallback_font.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	return _number_widths[number]


## The intent floating above the head: a round badge with the action's icon and its amount beside it.
## (The full description is in the figure's tooltip.)
func _draw_intent(a: float) -> void:
	var enemy := _f.unit as EnemyUnit
	var intent := Fighter.effective_intent(enemy, _f.intent_target)
	if intent == null:
		return
	var col := CardView.kind_color(int(intent.kind))
	if intent.kind in [CardEffect.Kind.MALICE, CardEffect.Kind.WARD] and intent.amount < 0:
		col = CardView.STATUS_NEGATIVE
	var c := _f.intent_center()
	var number := Fighter.omen_text(intent)
	var nw := _number_width(number)
	var total := 30.0 + 5.0 + nw
	var cx := c.x - total / 2.0 + 15.0
	var badge := Vector2(cx, c.y)
	_f.draw_circle(badge, 16.0, Color(0, 0, 0, 0.6 * a))
	_f.draw_circle(badge, 14.5, Color(col.darkened(0.5), 0.95 * a))
	_f.draw_arc(badge, 14.5, 0, TAU, 28, Color(col, a), 1.8, true)
	HudIcons.intent(_f, int(intent.kind), badge, Color(col, a), 1.0)
	HudIcons.text(_f, number, Rect2(cx + 19.0, c.y - 14.0, nw + 4.0, 28.0), 22, Color(col.lightened(0.35), a), false, 4)


## The HP bar under the feet with its numbers. Block shows as a blue frame and a shield badge on the left end.
func _draw_bar(a: float) -> void:
	var unit := _f.unit
	var bar := _f.bar_rect()
	var has_block := unit.block > 0
	var frame := CardView.kind_color(CardEffect.Kind.BLOCK) if has_block else Color(0.55, 0.22, 0.2)
	HudIcons.box(_f, bar, Color(Fighter.HP_BACK, a), 4, 2 if has_block else 1, Color(frame, a))
	var ratio := clampf(float(unit.hp) / maxf(float(unit.max_hp), 1.0), 0.0, 1.0)
	if ratio > 0.0:
		HudIcons.box(_f, Rect2(bar.position + Vector2(1, 1), Vector2(maxf((bar.size.x - 2) * ratio, 4.0), bar.size.y - 2)), Color(CardView.HP_RED, a), 3)
	if _f.drop_hover and _f.drop_lost > 0:
		# The HP the card would take, ghosted in gold between what would remain and what is there now.
		var inner := bar.size.x - 2.0
		var left := clampf(float(unit.hp - _f.drop_lost) / maxf(float(unit.max_hp), 1.0), 0.0, 1.0) * inner
		var right := ratio * inner
		if right > left:
			HudIcons.box(_f, Rect2(bar.position + Vector2(1.0 + left, 1.0), Vector2(right - left, bar.size.y - 2.0)), Color(MenuStyle.AMBER, 0.9 * a), 3)
	HudIcons.text(_f, "%d/%d" % [maxi(unit.hp, 0), unit.max_hp], bar, 12, Color(1, 1, 1, a), true, 3)
	if has_block:
		var pop := 1.0 + sin(_f._pop * PI) * 0.35
		var c := Vector2(bar.position.x - 2.0, bar.get_center().y)
		var col := CardView.kind_color(CardEffect.Kind.BLOCK)
		HudIcons.shield(_f, c, 15.0 * pop, Color(0, 0, 0, 0.6 * a))
		HudIcons.shield(_f, c, 13.0 * pop, Color(col.darkened(0.25), a))
		HudIcons.text(_f, str(unit.block), Rect2(c - Vector2(14, 12), Vector2(28, 24)), 14, Color(1, 1, 1, a), true, 3)


func _draw_chips(a: float) -> void:
	var chips := _f.status_chips()
	var rects := _f.chip_rects()
	for i in chips.size():
		var chip: Dictionary = chips[i]
		var r := rects[i]
		var col: Color = chip.color
		HudIcons.box(_f, r, Color(0.04, 0.03, 0.05, 0.9 * a), 8, 1, Color(col, a))
		HudIcons.status(_f, chip.kind, Vector2(r.position.x + 9, r.position.y + 8), Color(col, a))
		HudIcons.text(_f, chip.label, Rect2(r.position.x + 16, r.position.y, r.size.x - 18, r.size.y), 11, Color(0.97, 0.95, 0.92, a), false)


func _draw_floats() -> void:
	var origin := Vector2(_f.size.x / 2.0, Fighter.OVERHEAD + _f.figure_height * 0.35)
	for f in _f._floats:
		var t: float = f.age / Fighter.FLOAT_TIME
		var rise := 1.0 - pow(1.0 - t, 2.0)
		var alpha := 1.0 - smoothstep(0.55, 1.0, t)
		var pop := 1.0 + sin(minf(t * 5.0, 1.0) * PI) * 0.25
		if Motion.reduced: # shown in place at full strength for the same time, then gone
			rise = 0.5
			alpha = 1.0
			pop = 1.0
		var fs := int(26.0 * pop)
		var col: Color = f.color
		HudIcons.text(_f, f.text, Rect2(origin + Vector2(f.drift - 60.0, -rise * 60.0 - 14.0), Vector2(120, 28)), fs, Color(col, alpha), true, 5)
