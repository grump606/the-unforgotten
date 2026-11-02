class_name CharacterPanel
extends MarginContainer
## One column of the character select screen: a bordered panel in the class palette (the same
## tokens as the card frames, see CardView.PALETTES) with a code-drawn portrait, the class
## emblem, name, HP, pitch, the compact starting deck and a "Play as ..." button. Lights up
## (brighter border, glow, a slight lift) while hovered or while its button has keyboard focus.
## Built from a Character; an unknown or missing one just gets the neutral palette.

signal play_pressed(character_id: StringName)

const BORDER_WIDTH := 4
const PAD := 5
const PORTRAIT_HEIGHT := 88.0
## The figures are drawn in a box this tall and scaled down to the portrait.
const FIGURE_HEIGHT := 84.0
## The painted portrait shows this top share of the class sprite: head, shoulders and chest.
const PAINTED_CROP := 0.32
## Starting-deck cards: four per row, small enough that three panels sit comfortably across 1152 px
## and the whole group fits the window height without crowding the edges.
const DECK_CARD_SCALE := 0.5
const DECK_COLUMNS := 4
const DECK_GAP := 2
const HOVER_SCALE := 1.02

var character_id: StringName
## Which CardView palette this panel uses: the character's id, or &"" (neutral) when it has none.
var class_id: StringName = &""
var play_button: Button

var _p: Dictionary
var _hovered := false


func _init(character: Character = null) -> void:
	var c := character if character != null else Character.new()
	character_id = c.id
	class_id = c.id if CardView.PALETTES.has(c.id) else &""
	_p = CardView.PALETTES[class_id]
	mouse_filter = Control.MOUSE_FILTER_PASS
	custom_minimum_size = Vector2(deck_width() + 2.0 * (PAD + BORDER_WIDTH), 0)
	for side in ["left", "right", "top", "bottom"]:
		add_theme_constant_override("margin_" + side, PAD + BORDER_WIDTH)
	mouse_entered.connect(set_hovered.bind(true))
	mouse_exited.connect(_on_mouse_exited)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	add_child(box)
	var portrait := Control.new() # the portrait itself is drawn by this panel
	portrait.custom_minimum_size = Vector2(0, PORTRAIT_HEIGHT)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(portrait)
	var title := HBoxContainer.new() # name and HP share a line to save height
	title.alignment = BoxContainer.ALIGNMENT_CENTER
	title.add_theme_constant_override("separation", 10)
	title.add_child(_label(c.display_name, 21, _p.ink))
	title.add_child(_label("%d HP" % c.max_hp, 15, _p.accent))
	box.add_child(title)
	var pitch := _label(c.pitch, 12, Color(_p.ink, 0.85))
	pitch.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pitch.custom_minimum_size = Vector2(0, 2.0 * 15.0) # two lines, so decks line up across panels
	box.add_child(pitch)
	box.add_child(_label("Starting deck:", 12, Color(_p.ink, 0.7)))
	box.add_child(_deck_grid(c.starting_deck))
	play_button = Button.new()
	play_button.text = "Play as %s" % c.display_name
	play_button.custom_minimum_size = Vector2(0, 34)
	_style_button(play_button)
	play_button.pressed.connect(func() -> void: play_pressed.emit(character_id))
	play_button.focus_entered.connect(_refresh)
	play_button.focus_exited.connect(_refresh)
	box.add_child(play_button)


## Width of the starting-deck grid, which sets how wide the panel has to be.
static func deck_width() -> float:
	return DECK_COLUMNS * CardView.BASE.x * DECK_CARD_SCALE + (DECK_COLUMNS - 1) * DECK_GAP


## The panel's frame colour (brighter while lit); tests read it to see the border is there.
func border_color() -> Color:
	var frame: Color = _p.frame
	return frame.lightened(0.25) if is_lit() else frame


## Hover state; the mouse signals call this, and screenshots and tests can too.
func set_hovered(on: bool) -> void:
	_hovered = on
	_refresh()


func _on_mouse_exited() -> void:
	# Moving onto a child control also counts as leaving: only clear when really outside.
	if not Rect2(Vector2.ZERO, size).has_point(get_local_mouse_position()):
		set_hovered(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		pivot_offset = size / 2.0


func is_lit() -> bool:
	return _hovered or (play_button != null and play_button.has_focus())


func _refresh() -> void:
	var lit := is_lit()
	scale = Vector2.ONE * (HOVER_SCALE if lit else 1.0)
	z_index = 1 if lit else 0 # a lifted panel draws over its neighbours
	queue_redraw()


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


## One small card per distinct card in first-seen order, each with a "3 Shove" count label.
func _deck_grid(cards: Array[CardData]) -> GridContainer:
	var counts := {}
	var order: Array[CardData] = []
	for card in cards:
		if not counts.has(card.display_name):
			order.append(card)
		counts[card.display_name] = counts.get(card.display_name, 0) + 1
	var grid := GridContainer.new()
	grid.columns = DECK_COLUMNS
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL # panels share a height: buttons line up
	grid.add_theme_constant_override("h_separation", DECK_GAP)
	grid.add_theme_constant_override("v_separation", DECK_GAP)
	for card in order:
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 0)
		var view := CardView.new()
		view.view_scale = DECK_CARD_SCALE
		view.set_card(card)
		view.tooltip_text = "%s (%d)\n%s" % [card.display_name, card.cost, card.describe()]
		view.mouse_filter = Control.MOUSE_FILTER_PASS # still shows its tooltip
		cell.add_child(view)
		var count := _label("%d %s" % [counts[card.display_name], card.display_name], 11, _p.ink)
		count.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		count.custom_minimum_size = Vector2(CardView.BASE.x * DECK_CARD_SCALE, 0)
		cell.add_child(count)
		grid.add_child(cell)
	return grid


## Banner-coloured button with a thick gold focus ring, so keyboard focus is unmistakable.
func _style_button(button: Button) -> void:
	var banner: Color = _p.banner
	var fills := {"normal": banner, "hover": banner.lightened(0.18), "pressed": banner.darkened(0.2), "disabled": banner.darkened(0.4)}
	for state in fills:
		var sb := StyleBoxFlat.new()
		sb.bg_color = fills[state]
		sb.set_corner_radius_all(5)
		sb.set_border_width_all(2)
		sb.border_color = _p.frame
		button.add_theme_stylebox_override(state, sb)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.set_corner_radius_all(7)
	focus.set_border_width_all(3)
	focus.border_color = CardView.SELECT_GOLD
	focus.set_expand_margin_all(3)
	button.add_theme_stylebox_override("focus", focus)
	for key in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		button.add_theme_color_override(key, _p.banner_ink)


# --- drawing ---------------------------------------------------------------------------

func _box(rect: Rect2, fill: Color, radius: int, border := 0, border_color := Color.WHITE) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(border)
	sb.border_color = border_color
	sb.anti_aliasing = true
	draw_style_box(sb, rect)


func _draw() -> void:
	var lit := is_lit()
	var frame := border_color()
	var whole := Rect2(Vector2.ZERO, size)
	if lit:
		var glow: Color = CardView.SELECT_GOLD if play_button.has_focus() else frame
		_box(whole.grow(3), Color(0, 0, 0, 0), 13, 2, Color(glow, 0.7))
	# Same build as the card frame: a coloured rim round darker panel stock.
	_box(whole, frame, 10)
	var stock: Color = _p.stock
	_box(whole.grow(-BORDER_WIDTH), stock.lerp(CardView.BACKDROP, 0.6), 7)
	_draw_frame_decor(whole)
	var area := Rect2(Vector2.ONE * (PAD + BORDER_WIDTH), Vector2(size.x - 2.0 * (PAD + BORDER_WIDTH), PORTRAIT_HEIGHT))
	draw_set_transform(area.position)
	_draw_portrait(area.position, area.size)
	draw_set_transform(Vector2.ZERO)


## The per-class touch on the frame, echoing the card frames: rivets, brass stitching, a bone line.
func _draw_frame_decor(whole: Rect2) -> void:
	var accent: Color = _p.accent
	match class_id:
		&"deserter":
			for pt in [Vector2(3, 3), Vector2(whole.end.x - 3, 3), Vector2(3, whole.end.y - 3), whole.end - Vector2(3, 3)]:
				draw_circle(pt, 1.8, Color(0.2, 0.1, 0.05))
		&"pickpocket":
			var r := whole.grow(-7)
			var x := r.position.x + 4
			while x < r.end.x - 4:
				draw_line(Vector2(x, r.position.y), Vector2(minf(x + 3, r.end.x - 4), r.position.y), Color(accent, 0.55), 1.0)
				draw_line(Vector2(x, r.end.y), Vector2(minf(x + 3, r.end.x - 4), r.end.y), Color(accent, 0.55), 1.0)
				x += 6
		&"medium":
			_box(whole.grow(-7), Color(0, 0, 0, 0), 4, 1, Color(accent, 0.4))


## Points of a head-and-shoulders silhouette with its base on the bottom of the portrait.
func _bust(cx: float, half: float) -> PackedVector2Array:
	var h := FIGURE_HEIGHT
	return PackedVector2Array([
		Vector2(cx - half, h), Vector2(cx - half + 4, h - 24), Vector2(cx - half * 0.62, h - 36), Vector2(cx - 12, h - 40),
		Vector2(cx + 12, h - 40), Vector2(cx + half * 0.62, h - 36), Vector2(cx + half - 4, h - 24), Vector2(cx + half, h)])


## Lit upper edge of a silhouette.
func _rim(pts: PackedVector2Array, color: Color) -> void:
	draw_polyline(pts.slice(1, pts.size() - 1), color, 1.5, true)


func _draw_portrait(origin: Vector2, sz: Vector2) -> void:
	var accent: Color = _p.accent
	var window: Color = _p.window
	var cx := sz.x / 2.0
	_box(Rect2(Vector2.ZERO, sz), window, 5, 1, Color(_p.frame, 0.8))
	# A lamp glow behind the shoulder and the class motif of the card art window.
	for i in 4:
		draw_circle(Vector2(sz.x * 0.2, 6), 22.0 + i * 16.0, Color(CardView.BADGE, 0.035))
	var motif := Color(accent, 0.10)
	match class_id:
		&"deserter":
			var x := 0.0
			while x < sz.x:
				draw_line(Vector2(x, sz.y), Vector2(minf(x + 44, sz.x), maxf(sz.y - (sz.x - x), 0.0)), motif, 3.0)
				x += 18
		&"pickpocket":
			var y := 6.0
			while y < sz.y - 3:
				draw_line(Vector2(4, y), Vector2(sz.x - 4, y), motif, 1.0)
				y += 6
		&"medium":
			for r in [24.0, 40.0, 56.0]:
				draw_arc(Vector2(cx, sz.y * 0.55), r, 0, TAU, 40, motif, 1.0, true)
		_:
			draw_arc(Vector2(cx, sz.y * 0.5), 30.0, 0, TAU, 40, motif, 1.0, true)
	var painted := _draw_painted_portrait(sz)
	if not painted:
		_draw_figure_code(origin, cx)
	draw_set_transform(origin)
	_draw_emblem(Vector2(17, 17))
	_box(Rect2(Vector2.ZERO, sz), Color(0, 0, 0, 0), 5, 1, Color(_p.frame, 0.8))


## The painted class sprite, cropped to head and shoulders and centred in the window; false when the
## class has no sprite (then the code-drawn bust is used). A lit panel brightens it a little.
func _draw_painted_portrait(sz: Vector2) -> bool:
	var fig := PaintedArt.player_figure(class_id)
	if fig.is_empty():
		return false
	var tex: Texture2D = fig.tex
	var region := Rect2(0.0, 0.0, tex.get_width(), tex.get_height() * PAINTED_CROP)
	var scale_to := (sz.y - 2.0) / region.size.y
	var width := minf(region.size.x * scale_to, sz.x - 2.0)
	var dest := Rect2((sz.x - width) / 2.0, 1.0, width, sz.y - 2.0)
	# If the sprite is wider than the window, crop the sides evenly instead of squashing it.
	region.size.x = width / scale_to
	region.position.x = (tex.get_width() - region.size.x) / 2.0
	var tint := Color(1.12, 1.12, 1.12) if is_lit() else Color(0.9, 0.9, 0.92)
	draw_texture_rect_region(tex, dest, region, tint)
	return true


## The code-drawn bust used when there is no painted sprite.
func _draw_figure_code(origin: Vector2, cx: float) -> void:
	var fit := PORTRAIT_HEIGHT / FIGURE_HEIGHT
	draw_set_transform(origin + Vector2(cx * (1.0 - fit), 0.0), 0.0, Vector2(fit, fit))
	match class_id:
		&"deserter":
			_draw_deserter(cx)
		&"pickpocket":
			_draw_pickpocket(cx)
		&"medium":
			_draw_medium(cx)


func _draw_deserter(cx: float) -> void:
	var h := FIGURE_HEIGHT
	var accent: Color = _p.accent
	var coat := Color(0.16, 0.18, 0.21)
	var body := _bust(cx, 60.0)
	draw_colored_polygon(body, coat)
	_rim(body, Color(accent, 0.55))
	draw_line(Vector2(cx - 38, h - 36), Vector2(cx + 40, h), coat.lightened(0.12), 5.0) # bandolier strap
	draw_rect(Rect2(cx - 5, h - 50, 10, 12), coat.darkened(0.2)) # neck
	draw_circle(Vector2(cx, h - 58), 13.0, coat.lightened(0.04)) # head
	draw_colored_polygon(PackedVector2Array([Vector2(cx - 15, h - 59), Vector2(cx - 13, h - 76), Vector2(cx + 13, h - 76), Vector2(cx + 15, h - 59)]), coat.lightened(0.05)) # cap crown
	draw_line(Vector2(cx - 17, h - 60), Vector2(cx + 17, h - 60), accent.darkened(0.2), 3.0) # cap brim / band
	draw_polyline(PackedVector2Array([Vector2(cx - 14, h - 40), Vector2(cx, h - 22), Vector2(cx + 14, h - 40)]), accent, 2.0, true) # lapels
	for i in 3:
		draw_circle(Vector2(cx, h - 18 + i * 7 - 4), 1.8, Color(0.85, 0.7, 0.3)) # brass buttons
	for side in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([Vector2(cx + side * 56, h - 24), Vector2(cx + side * 36, h - 34), Vector2(cx + side * 34, h - 28), Vector2(cx + side * 54, h - 18)]), Color(accent, 0.8)) # epaulettes


func _draw_pickpocket(cx: float) -> void:
	var h := FIGURE_HEIGHT
	var accent: Color = _p.accent
	var cloak := Color(0.04, 0.10, 0.11)
	var body := _bust(cx, 58.0)
	draw_colored_polygon(body, cloak)
	_rim(body, Color(accent, 0.4))
	var hood := PackedVector2Array([
		Vector2(cx - 34, h - 34), Vector2(cx - 25, h - 58), Vector2(cx - 11, h - 76), Vector2(cx + 6, h - 80), Vector2(cx + 21, h - 64),
		Vector2(cx + 30, h - 44), Vector2(cx + 36, h - 34), Vector2(cx + 14, h - 38), Vector2(cx - 14, h - 38)])
	draw_colored_polygon(hood, cloak.lightened(0.07))
	draw_polyline(hood.slice(0, 7), Color(accent, 0.5), 1.5, true)
	draw_circle(Vector2(cx, h - 52), 12.0, Color(0.01, 0.03, 0.04)) # the shadowed face
	draw_circle(Vector2(cx - 4.5, h - 54), 1.3, Color(accent, 0.9)) # two glints
	draw_circle(Vector2(cx + 4.5, h - 54), 1.3, Color(accent, 0.9))
	# Pocket watch on a chain looped from the waistcoat.
	var from := Vector2(cx + 16, h - 28)
	var watch := Vector2(cx + 46, h - 14)
	var chain := PackedVector2Array()
	for i in 13:
		var t := i / 12.0
		var bend := Vector2(cx + 40, h - 38)
		chain.append(from.lerp(bend, t).lerp(bend.lerp(watch, t), t))
	draw_polyline(chain, Color(accent, 0.9), 1.5, true)
	draw_circle(watch, 9.0, Color(0.55, 0.42, 0.16))
	draw_circle(watch, 7.0, Color(0.92, 0.88, 0.75))
	draw_line(watch, watch + Vector2(0, -5), Color(0.1, 0.1, 0.1), 1.2)
	draw_line(watch, watch + Vector2(3.5, 0), Color(0.1, 0.1, 0.1), 1.2)
	draw_circle(watch + Vector2(0, -11), 2.0, Color(0.55, 0.42, 0.16)) # crown


func _draw_medium(cx: float) -> void:
	var h := FIGURE_HEIGHT
	var accent: Color = _p.accent
	var shawl := Color(0.15, 0.09, 0.20)
	# Faint spectral outlines of passengers who are not quite there.
	for ghost in [[-52.0, 0.30], [54.0, 0.20]]:
		var gx: float = cx + ghost[0]
		var line := Color(0.72, 0.84, 0.95, ghost[1])
		var pts := _bust(gx, 40.0)
		pts.append(pts[0])
		draw_polyline(pts, line, 1.5, true)
		draw_arc(Vector2(gx, h - 52), 11.0, 0, TAU, 20, line, 1.5, true)
	var body := _bust(cx, 52.0)
	draw_colored_polygon(body, shawl)
	_rim(body, Color(accent, 0.45))
	draw_rect(Rect2(cx - 5, h - 48, 10, 10), shawl.darkened(0.2)) # neck
	draw_circle(Vector2(cx, h - 56), 13.0, shawl.lightened(0.04)) # head
	draw_polyline(PackedVector2Array([Vector2(cx - 13, h - 52), Vector2(cx - 15, h - 34), Vector2(cx - 24, h - 30)]), Color(accent, 0.35), 1.5, true) # fall of hair
	draw_polyline(PackedVector2Array([Vector2(cx + 13, h - 52), Vector2(cx + 15, h - 34), Vector2(cx + 24, h - 30)]), Color(accent, 0.35), 1.5, true)
	draw_polyline(PackedVector2Array([Vector2(cx - 12, h - 40), Vector2(cx, h - 24), Vector2(cx + 12, h - 40)]), Color(accent, 0.7), 2.0, true) # shawl edge
	# A candle held up in front of her.
	var wick := Vector2(cx + 30, h - 22)
	for i in 3:
		draw_circle(wick + Vector2(0, -2), 6.0 + i * 5.0, Color(0.98, 0.78, 0.35, 0.06))
	draw_rect(Rect2(wick + Vector2(-3, 4), Vector2(6, 14)), Color(accent, 0.9))
	var flame := PackedVector2Array([wick + Vector2(0, -9)])
	for i in 15:
		flame.append(wick + Vector2(0, -3) + Vector2.from_angle(deg_to_rad(-50.0 + 280.0 * i / 14.0)) * 3.6)
	draw_colored_polygon(flame, Color(0.98, 0.78, 0.35))


## Keepsake emblems match the cards.
func _draw_emblem(c: Vector2) -> void:
	var p: Dictionary = _p
	var frame: Color = p.frame
	var glyph: Color = p.glyph
	draw_circle(c, 13.5, Color(0, 0, 0, 0.5))
	draw_circle(c, 12.5, frame)
	match class_id:
		&"deserter":
			# The soldier's squared forearm guard.
			draw_colored_polygon(PackedVector2Array([c + Vector2(-6, -7), c + Vector2(6, -7), c + Vector2(5, 5), c + Vector2(0, 8), c + Vector2(-5, 5)]), glyph)
			draw_line(c + Vector2(-3, -2), c + Vector2(3, -2), frame, 1.2)
			draw_line(c + Vector2(-3, 2), c + Vector2(3, 2), frame, 1.2)
		&"pickpocket":
			# A keyhole.
			draw_circle(c + Vector2(0, -2.5), 4.0, glyph)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-1.8, 0), c + Vector2(1.8, 0), c + Vector2(3.8, 7.5), c + Vector2(-3.8, 7.5)]), glyph)
		&"medium":
			# Cloudy-glass orb, matching the Medium's current keepsake.
			draw_circle(c, 7.0, glyph)
			draw_arc(c, 5.1, PI * 1.1, PI * 1.7, 14, Color(p.ink, 0.8), 1.3, true)
			draw_arc(c + Vector2(0, 1), 3.5, 0.2, PI, 12, Color(frame, 0.8), 1.5, true)
		_:
			# A pressed leaf, preserving a small ordinary memory.
			draw_colored_polygon(PackedVector2Array([c + Vector2(-6, 5), c + Vector2(-5, -2), c + Vector2(1, -7), c + Vector2(6, -6), c + Vector2(5, 1), c + Vector2(-1, 6)]), glyph)
			draw_line(c + Vector2(-6, 7), c + Vector2(4, -5), frame, 1.2)


