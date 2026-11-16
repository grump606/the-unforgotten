class_name CardFace
extends RefCounted
## Draws a CardView's face, split out of CardView so the view keeps its layout, state, input and hover lift:
## the frame and stock, header with the cost stamp, name banner and rarity gem, art window, effect text with the
## keyword line and live numbers, the target strip, and the hotkey, preview and DISCARD overlays. The per-class
## decoration (frame, header, emblem, window motif) is CardDecor. It draws onto the view during its _draw.

## Styles shared by every card, keyed by fill, radius and border: a card face draws a dozen boxes per redraw.
static var _box_styles := {}
const BOX_STYLE_CAP := 256
const BASE := CardView.BASE

var _cv: CardView
var _decor: CardDecor
var _font: Font = ThemeDB.fallback_font


func _init(view: CardView) -> void:
	_cv = view
	_decor = CardDecor.new(view)


## The whole face: `lift` is the view's 0 (resting) to 1 (raised) ease and `raised` whether it is raised.
func draw(lift: float, raised: bool) -> void:
	var card := _cv.card
	if card == null:
		return
	var state := _cv.state
	var class_id := _cv.class_id
	var view_scale := _cv.view_scale
	# A Dormant card is always muted (it can never be played), even where its state is NORMAL.
	var muted := state == CardView.State.UNPLAYABLE or card.dormant
	var p := CardPalette.get_palette(class_id, muted, not muted and raised)
	var top := CardView.LIFT * (1.0 - lift)
	_cv.draw_set_transform(Vector2(0, top * view_scale), 0.0, Vector2(view_scale, view_scale))
	var stock: Color = p.stock
	var ink: Color = p.ink
	var frame: Color = p.frame

	if state == CardView.State.SELECTED:
		box(_cv, Rect2(-3, -3, BASE.x + 6, BASE.y + 6), Color(0, 0, 0, 0), 11, 3, CardView.SELECT_GOLD)
	elif raised:
		box(_cv, Rect2(-2, -2, BASE.x + 4, BASE.y + 4), Color(0, 0, 0, 0), 10, 2, Color(frame, 0.7))
	box(_cv, Rect2(Vector2.ZERO, BASE), frame, 8)
	box(_cv, Rect2(4, 4, BASE.x - 8, BASE.y - 8), stock, 5)
	_decor.draw_frame(p)
	if card.fading:
		CardDecor.dashed_rect(_cv, Rect2(1.5, 1.5, BASE.x - 3, BASE.y - 3), Color(1, 1, 1, 0.75))
	if card.oath:
		# An Oath wears a gold double rule round the stock, so it reads as a vow that stays.
		box(_cv, Rect2(2, 2, BASE.x - 4, BASE.y - 4), Color(0, 0, 0, 0), 7, 2, CardView.SELECT_GOLD)
		box(_cv, Rect2(5.5, 5.5, BASE.x - 11, BASE.y - 11), Color(0, 0, 0, 0), 4, 1, Color(CardView.SELECT_GOLD, 0.6))

	# Header: price stamp, class label, emblem.
	var header := Rect2(8, 6, BASE.x - 16, 24)
	box(_cv, header, stock.lerp(Color.BLACK if class_id != &"" else frame, 0.22), 4)
	_decor.draw_header(header, p)
	_draw_cost(Vector2(20, 18), muted)
	_decor.draw_emblem(Vector2(BASE.x - 20, 18), p)
	_text(String(p.label), Rect2(36, 6, BASE.x - 72, 24), 10, ink, true)

	# Name banner; a long name shrinks (down to 8 px) to fit.
	var banner := Rect2(6, 33, BASE.x - 12, 20)
	box(_cv, banner, p.banner, 3)
	# A rarity gem sits at the right end of the banner, so the name leaves room for it.
	var name_rect := Rect2(banner.position, Vector2(banner.size.x - (16.0 if CardView.RARITY_GEM_COLORS.has(card.rarity) else 0.0), banner.size.y))
	_text(card.display_name, name_rect, _fit_size(card.display_name, name_rect.size.x - 8, 13, 8), _cv.title_color(p), true)
	_draw_rarity_gem(Vector2(BASE.x - 14, 43))
	_draw_hotkey(Vector2(9, 30))

	# Art window with the procedural icon.
	var win := Rect2(10, 57, BASE.x - 20, 50)
	box(_cv, win, p.window, 4, 1, Color(frame, 0.8))
	var art := PaintedArt.card_texture(card.id)
	if art != null:
		_draw_painted_window(art, win, p, muted)
	else:
		_decor.draw_motif(win, p)
		CardIcons.draw_card_icons(_cv, card, win, p, CardView.is_status_card(card))
	if card.anchor:
		_draw_anchor(Vector2(win.end.x - 10, win.position.y + 10))

	# Effect text.
	var body := Rect2(9, 110, BASE.x - 18, 56)
	var preview := _cv.preview
	if preview != "":
		# The preview takes the bottom two lines of the text area; the effect text gets the rest.
		var line_h := ceilf(_font.get_multiline_string_size(preview, HORIZONTAL_ALIGNMENT_CENTER, body.size.x - 6, _preview_size(body.size.x - 6)).y) + 4.0
		var line := Rect2(body.position.x, body.end.y - line_h, body.size.x, line_h)
		body.size.y -= line_h + 2
		_draw_preview(line)
	_draw_body(body, ink)

	# A continuous paper fold separates the rules from the target strip.
	_cv.draw_line(Vector2(9, 167), Vector2(BASE.x - 9, 167), Color(ink, 0.30), 1.0)
	_cv.draw_line(Vector2(9, 168), Vector2(BASE.x - 9, 168), Color(stock.lightened(0.15), 0.45), 1.0)
	_draw_strip(Rect2(8, 170, BASE.x - 16, 16), p)
	if _cv.discard_marked:
		_draw_discard_mark()
	_cv.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _box_style(fill: Color, radius: int, border: int, border_color: Color) -> StyleBoxFlat:
	var key := [fill, radius, border, border_color]
	var cached: StyleBoxFlat = _box_styles.get(key)
	if cached != null:
		return cached
	if _box_styles.size() >= BOX_STYLE_CAP:
		_box_styles.clear()
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(border)
	sb.border_color = border_color
	sb.anti_aliasing = true
	_box_styles[key] = sb
	return sb


## A rounded box on `ci`; a large enough opaque one gets the paper grain.
static func box(ci: CanvasItem, rect: Rect2, fill: Color, radius: int, border := 0, border_color := Color.WHITE) -> void:
	ci.draw_style_box(_box_style(fill, radius, border, border_color), rect)
	if fill.a >= 0.5 and rect.size.x > 30.0 and rect.size.y > 15.0:
		TactileArt.draw_grain(ci, rect.grow(-3.0), 0.12)


## Draws text inside a rectangle: centered both ways when `centered`, else left aligned and
## vertically centered. Baseline math keeps small caps text visually centered in its band.
func _text(txt: String, rect: Rect2, size: int, col: Color, centered := false) -> void:
	var y := rect.position.y + rect.size.y / 2.0 + (_font.get_ascent(size) - _font.get_descent(size)) / 2.0
	var align := HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	_cv.draw_string(_font, Vector2(rect.position.x, y), txt, align, rect.size.x, size, col)


## Largest font size from max_size down to min_size at which txt fits in `width` (min_size if none).
func _fit_size(txt: String, width: float, max_size: int, min_size: int) -> int:
	var size := max_size
	while size > min_size and _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
		size -= 1
	return size


## Dims the card and stamps a red DISCARD band across it (the end-of-turn discard step).
func _draw_discard_mark() -> void:
	box(_cv, Rect2(Vector2.ZERO, BASE), Color(0.02, 0.02, 0.04, 0.62), 8)
	var band := Rect2(0, 78, BASE.x, 34)
	box(_cv, band, Color(0.62, 0.1, 0.14, 0.95), 2, 2, Color(1.0, 0.82, 0.8, 0.9))
	_text("DISCARD", band, 18, Color.WHITE, true)


## A small dark badge with the card's hotkey number (10 shows as 0), tucked under the cost stamp.
func _draw_hotkey(c: Vector2) -> void:
	var hotkey := _cv.hotkey
	if hotkey <= 0:
		return
	_cv.draw_circle(c, 7.5, Color(0, 0, 0, 0.85))
	_cv.draw_arc(c, 6.5, 0, TAU, 20, Color(CardView.BADGE, 0.9), 1.0, true)
	_text(str(hotkey % 10),Rect2(c - Vector2(7, 7), Vector2(14, 14)), 10, Color.WHITE, true)


## Font size for the preview: 10 px, shrinking (to 8) only when it would need more than two lines.
func _preview_size(width: float) -> int:
	var size := 11
	while size > 9 and _font.get_multiline_string_size(_cv.preview, HORIZONTAL_ALIGNMENT_CENTER, width, size).y > 2.0 * _font.get_height(size):
		size -= 1
	return size


## The preview text in a dark pill, wrapped onto at most two lines.
func _draw_preview(rect: Rect2) -> void:
	var preview := _cv.preview
	box(_cv, rect, Color(0.07, 0.06, 0.06, 0.88), 3)
	var inner := rect.grow_individual(-3, 0, -3, 0)
	var size := _preview_size(inner.size.x)
	var h := _font.get_multiline_string_size(preview, HORIZONTAL_ALIGNMENT_CENTER, inner.size.x, size).y
	var y := rect.position.y + (rect.size.y - h) / 2.0 + _font.get_ascent(size)
	_cv.draw_multiline_string(_font, Vector2(inner.position.x, y), preview, HORIZONTAL_ALIGNMENT_CENTER, inner.size.x, size, -1, CardView.WARN)


func _draw_cost(c: Vector2, muted: bool) -> void:
	var col := CardView.BADGE_BAD if muted else CardView.BADGE
	_cv.draw_circle(c, 14.5, Color(0, 0, 0, 0.55))
	_cv.draw_circle(c, 13.5, col)
	_cv.draw_arc(c, 10.5, 0, TAU, 28, Color(0, 0, 0, 0.35), 1.0, true)
	var ink := Color.WHITE if muted else Color(0.14, 0.1, 0.04)
	# A Surge card spends all the energy there is, so its stamp shows X, not a number.
	_text(_cv.cost_text(), Rect2(c - Vector2(13, 13), Vector2(26, 26)), 17, ink, true)


## Painted art fills the window; the effect icons shrink into badges so the card still reads at a glance.
func _draw_painted_window(art: Texture2D, win: Rect2, p: Dictionary, muted: bool) -> void:
	var card := _cv.card
	var inner := win.grow(-1.0)
	_cv.draw_texture_rect(art, inner, false, Color(0.55, 0.55, 0.55, 1.0) if muted else Color.WHITE)
	box(_cv, win, Color(0, 0, 0, 0), 4, 1, Color(p.frame, 0.8))
	var primary := CardIcons.primary_kind(card)
	var badge_col: Color = p.window
	var x := win.position.x + 11.0
	var y := win.end.y - 11.0
	if primary >= 0:
		_cv.draw_circle(Vector2(x, y), 9.5, Color(badge_col, 0.82))
		_cv.draw_arc(Vector2(x, y), 9.5, 0, TAU, 20, Color(1, 1, 1, 0.4), 1.0, true)
		CardIcons.draw_icon(_cv, primary, Vector2(x, y), 5.6, badge_col, CardIcons.icon_variant(card))
	x = win.end.x - 11.0
	for kind in CardIcons.secondary_kinds(card):
		_cv.draw_circle(Vector2(x, y), 9.5, Color(badge_col, 0.82))
		_cv.draw_arc(Vector2(x, y), 9.5, 0, TAU, 20, Color(1, 1, 1, 0.4), 1.0, true)
		CardIcons.draw_icon(_cv, kind, Vector2(x, y), 5.4, badge_col)
		x -= 21.0


## A small anchor in a dark disc (the Anchor keyword marker).
func _draw_anchor(c: Vector2) -> void:
	_cv.draw_circle(c, 9.0, Color(0, 0, 0, 0.7))
	_cv.draw_arc(c, 9.0, 0, TAU, 20, Color(CardView.KEYWORD_INK, 0.7), 1.0, true)
	var col := CardView.KEYWORD_INK
	_cv.draw_arc(c + Vector2(0, -5.2), 1.6, 0, TAU, 10, col, 1.2, true)
	_cv.draw_line(c + Vector2(0, -3.6), c + Vector2(0, 4.6), col, 1.3)
	_cv.draw_line(c + Vector2(-2.6, -1.4), c + Vector2(2.6, -1.4), col, 1.3)
	_cv.draw_arc(c + Vector2(0, 0.6), 4.6, 0.25, PI - 0.25, 10, col, 1.3, true)


## The keyword line (for example "FORGOTTEN · SURGE") in a small accent colour.
func _draw_keywords(rect: Rect2, ink: Color) -> void:
	var txt := _cv.keyword_text()
	var col := CardView.KEYWORD_INK_PAPER if _cv.class_id == &"" else CardView.KEYWORD_INK
	_text(txt, rect, _fit_size(txt, rect.size.x, 9, 7), col, true)
	_cv.draw_line(Vector2(rect.position.x + 14, rect.end.y), Vector2(rect.end.x - 14, rect.end.y), Color(ink, 0.18), 1.0)


func _draw_body(body: Rect2, ink: Color) -> void:
	if _cv.keyword_text() != "":
		var band := Rect2(body.position.x, body.position.y, body.size.x, CardView.KEYWORD_H)
		_draw_keywords(band, ink)
		body.position.y += CardView.KEYWORD_H + 1
		body.size.y -= CardView.KEYWORD_H + 1
	var lines := _cv.body_lines()
	var txt := _joined(lines)
	var size := 13
	var h := _font.get_multiline_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, body.size.x, size).y
	# An Oath carries two effects (its price and its lasting effect), so its text may shrink further.
	var smallest := 8 if _cv.card.oath else 10
	while size > smallest and h > body.size.y:
		size -= 1
		h = _font.get_multiline_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, body.size.x, size).y
	var y := body.position.y + (body.size.y - h) / 2.0 + _font.get_ascent(size)
	for line in lines:
		var col := ink
		if line.delta != 0:
			col = _number_color(line.delta)
		_cv.draw_multiline_string(_font, Vector2(body.position.x, y), line.text, HORIZONTAL_ALIGNMENT_CENTER, body.size.x, size, -1, col)
		if line.delta != 0:
			_draw_delta_marker(line.delta, body, y, size, line.text, col)
		y += _font.get_multiline_string_size(line.text, HORIZONTAL_ALIGNMENT_CENTER, body.size.x, size).y


## A small filled triangle just left of a live line whose number a status changed: pointing up when raised, down when
## lowered. A second cue beside the green / red colour, drawn with a polygon (not a font glyph) and placed in the
## margin of the centered text so the layout does not move. `baseline` is the first row's baseline.
func _draw_delta_marker(delta: int, body: Rect2, baseline: float, font_size: int, text: String, col: Color) -> void:
	var half := font_size * CardView.DELTA_MARKER_HALF
	var text_w := _font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, body.size.x, font_size).x
	var left := body.position.x + (body.size.x - text_w) / 2.0
	var center := Vector2(maxf(left - half - 2.0, body.position.x + half), baseline - _font.get_ascent(font_size) * 0.45)
	_cv.draw_colored_polygon(CardView.delta_marker_points(delta, center, half), col)


func _joined(lines: Array[Dictionary]) -> String:
	var texts := PackedStringArray()
	for line in lines:
		texts.append(line.text)
	return "\n".join(texts)


func _number_color(delta: int) -> Color:
	var paper := _cv.class_id == &""
	if delta > 0:
		return CardView.NUMBER_RAISED_PAPER if paper else CardView.NUMBER_RAISED
	return CardView.NUMBER_LOWERED_PAPER if paper else CardView.NUMBER_LOWERED


func _draw_strip(strip: Rect2, p: Dictionary) -> void:
	var card := _cv.card
	var note := _cv.note
	var class_id := _cv.class_id
	var stock: Color = p.stock
	var ink: Color = p.ink
	box(_cv, strip, stock.lerp(Color.BLACK, 0.25 if class_id != &"" else 0.1), 3)
	var hp := card.hp_cost()
	var right := strip.end.x - 3
	if hp > 0:
		# With a warning note the chip drops its "HP" word so the note has room.
		var chip_w := 46.0 if note == "" else 32.0
		var chip := Rect2(strip.end.x - chip_w - 3, strip.position.y + 2, chip_w, strip.size.y - 4)
		box(_cv, chip, CardView.HP_RED, 3, 1, Color(1, 1, 1, 0.7))
		CardIcons.draw_icon(_cv, CardEffect.Kind.HEAL_PER_HAUNTED, chip.position + Vector2(8, chip.size.y / 2.0), 4.0, Color.WHITE)
		_text("-%d HP" % hp if note == "" else "-%d" % hp, Rect2(chip.position + Vector2(13, 0), Vector2(chip.size.x - 13, chip.size.y)), 10, Color.WHITE)
		right = chip.position.x - 4
	var room := right - strip.position.x - 6
	var left := Rect2(strip.position.x + 5, strip.position.y, room, strip.size.y)
	if note != "":
		# A long note shrinks (down to 9 px) rather than being cut off.
		# WARN amber vanishes on the pale neutral paper, so those cards use the darker keyword amber.
		_text(note, left, _fit_size(note, room, 11, 9), CardView.WARN if class_id != &"" else CardView.KEYWORD_INK_PAPER)
		return
	var parts := PackedStringArray()
	match card.target_mode:
		CardData.TargetMode.ALL_ENEMIES:
			parts.append("ALL ENEMIES" if _font.get_string_size("ALL ENEMIES", HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x <= room else "ALL")
		CardData.TargetMode.SELF:
			parts.append("SELF")
		_:
			parts.append("ONE ENEMY")
	for kind in CardView.KEYWORDS:
		for effect in card.effects:
			if effect.kind == kind:
				parts.append(CardView.KEYWORDS[kind])
				break
	var txt := " · ".join(parts)
	while parts.size() > 1 and _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x > room:
		parts.remove_at(parts.size() - 1)
		txt = " · ".join(parts)
	_text(txt, left, 10, ink)


## A small diamond at the right end of the name banner for an Uncommon or Rare card (a Rare is a little larger).
func _draw_rarity_gem(c: Vector2) -> void:
	var card := _cv.card
	if card == null or not CardView.RARITY_GEM_COLORS.has(card.rarity):
		return
	var col: Color = CardView.RARITY_GEM_COLORS[card.rarity]
	var r := 4.5 if card.rarity == CardData.Rarity.RARE else 3.5
	var diamond := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
	_cv.draw_colored_polygon(diamond, col)
	_cv.draw_polyline(PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]]), Color(0, 0, 0, 0.55), 1.0, true)
