class_name HudIcons
extends RefCounted
## Small code-drawn icons and text helpers shared by the battle stage (Fighter, EnergyOrb). Every
## function draws on the CanvasItem it is given, so call them from that item's _draw().


static func diamond(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)]), col)


static func box(ci: CanvasItem, rect: Rect2, fill: Color, radius: int, border := 0, border_color := Color.WHITE) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(border)
	sb.border_color = border_color
	sb.anti_aliasing = true
	ci.draw_style_box(sb, rect)


## Text centered in `rect` both ways (or left aligned and vertically centered), with a dark outline
## so it reads over any painting.
static func text(ci: CanvasItem, txt: String, rect: Rect2, font_size: int, col: Color, centered := true, outline := 0) -> void:
	var font: Font = ThemeDB.fallback_font
	var y := rect.position.y + rect.size.y / 2.0 + (font.get_ascent(font_size) - font.get_descent(font_size)) / 2.0
	var align := HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	if outline > 0:
		ci.draw_string_outline(font, Vector2(rect.position.x, y), txt, align, rect.size.x, font_size, outline, Color(0, 0, 0, 0.85))
	ci.draw_string(font, Vector2(rect.position.x, y), txt, align, rect.size.x, font_size, col)


static func shield(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.8, -0.85) * r, c + Vector2(0, -1.0) * r, c + Vector2(0.8, -0.85) * r, c + Vector2(0.8, 0.1) * r, c + Vector2(0.45, 0.65) * r, c + Vector2(0, 1.0) * r, c + Vector2(-0.45, 0.65) * r, c + Vector2(-0.8, 0.1) * r]), col)


## Attack = blade, Block = shield, Expose = crosshair, anything else = a diamond spark.
static func intent(ci: CanvasItem, kind: int, c: Vector2, col: Color, size := 1.0) -> void:
	var bright := col.lightened(0.3)
	match kind:
		CardEffect.Kind.DAMAGE, CardEffect.Kind.DAMAGE_PER_BLOCK, CardEffect.Kind.DAMAGE_IF_BLOCK, CardEffect.Kind.DAMAGE_PER_PLAY, CardEffect.Kind.DAMAGE_PER_HAUNT:
			var rot := PI / 4.0
			var blade := PackedVector2Array()
			for u in [Vector2(0, -1.0), Vector2(0.2, -0.75), Vector2(0.2, 0.25), Vector2(-0.2, 0.25), Vector2(-0.2, -0.75)]:
				blade.append(c + (u as Vector2).rotated(rot) * 9.0 * size)
			ci.draw_colored_polygon(blade, bright)
			var guard := PackedVector2Array()
			for u in [Vector2(-0.55, 0.25), Vector2(0.55, 0.25), Vector2(0.55, 0.42), Vector2(-0.55, 0.42)]:
				guard.append(c + (u as Vector2).rotated(rot) * 9.0 * size)
			ci.draw_colored_polygon(guard, col)
		CardEffect.Kind.BLOCK:
			shield(ci, c, 8.0 * size, bright)
		CardEffect.Kind.EXPOSE:
			ci.draw_arc(c, 5.5 * size, 0, TAU, 20, bright, 1.8, true)
			for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				ci.draw_line(c + d * 3.5 * size, c + d * 9.0 * size, bright, 1.8)
			ci.draw_circle(c, 1.6 * size, bright)
		_:
			diamond(ci, c, 7.0 * size, bright)


## The small icon of a status pill (exposed, haunt, hold; anything else is a spiky star for thorns).
static func status(ci: CanvasItem, kind: StringName, c: Vector2, col: Color) -> void:
	match kind:
		&"exposed":
			ci.draw_arc(c, 3.0, 0, TAU, 14, col, 1.2, true)
			for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				ci.draw_line(c + d * 2.0, c + d * 5.0, col, 1.2)
		&"haunt":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-3.5, 4), c + Vector2(-3.5, -1), c + Vector2(0, -4.5), c + Vector2(3.5, -1), c + Vector2(3.5, 4), c + Vector2(1.5, 2.5), c + Vector2(0, 4), c + Vector2(-1.5, 2.5)]), col)
		&"hold":
			ci.draw_rect(Rect2(c + Vector2(-3, -1), Vector2(6, 5)), col)
			ci.draw_arc(c + Vector2(0, -1), 2.2, PI, TAU, 8, col, 1.2, true)
		_:
			var pts := PackedVector2Array()
			for i in 12:
				pts.append(c + Vector2.from_angle(i * TAU / 12.0 - PI / 2.0) * (4.6 if i % 2 == 0 else 2.0))
			ci.draw_colored_polygon(pts, col)
