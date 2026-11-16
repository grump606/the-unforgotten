class_name CardDecor
extends RefCounted
## The per-class decoration of a card face (frame treatment, header trim, corner emblem, art-window motif), split
## out of CardFace. Each palette id picks its four draw methods from one table, ClassStyle.of. It draws onto the
## CardView it was made for, during that view's _draw.

const BASE := CardView.BASE

var _cv: CardView


func _init(view: CardView) -> void:
	_cv = view


## How one palette (a class id, &"status", or &"" for the plain keepsake look) decorates a card: the CardDecor method
## that draws each of its four parts, on top of what every card shares. Adding a character's look is one entry in
## `of()` plus its four draw methods; an id with no entry (the Stray for now) gets the plain keepsake look.
class ClassStyle extends RefCounted:
	## CardDecor method names: frame(p), header(header, p), emblem(c, p) and motif(win, p), `p` the card's palette.
	var frame: StringName
	var header: StringName
	var emblem: StringName
	var motif: StringName

	static var _by_id: Dictionary = {}

	func _init(p_frame: StringName, p_header: StringName, p_emblem: StringName, p_motif: StringName) -> void:
		frame = p_frame
		header = p_header
		emblem = p_emblem
		motif = p_motif

	## The style of palette id `id` (see CardView.palette_id).
	static func of(id: StringName) -> ClassStyle:
		if _by_id.is_empty():
			_by_id = {
				CharacterIds.DESERTER: ClassStyle.new(&"_frame_deserter", &"_header_deserter", &"_emblem_deserter", &"_motif_deserter"),
				CharacterIds.THIEF: ClassStyle.new(&"_frame_thief", &"_header_thief", &"_emblem_thief", &"_motif_thief"),
				CharacterIds.MEDIUM: ClassStyle.new(&"_frame_medium", &"_header_medium", &"_emblem_medium", &"_motif_medium"),
				&"status": ClassStyle.new(&"_frame_status", &"_header_status", &"_emblem_status", &"_motif_status"),
				&"": ClassStyle.new(&"_frame_plain", &"_header_plain", &"_emblem_plain", &"_motif_plain"),
			}
		return _by_id.get(id, _by_id[&""])


## A dashed rectangle outline on `ci` (a Fading card's edge, the thread and mildew frames).
static func dashed_rect(ci: CanvasItem, r: Rect2, col: Color) -> void:
	var step := 6.0
	var x := r.position.x + 4
	while x < r.end.x - 4:
		ci.draw_line(Vector2(x, r.position.y), Vector2(minf(x + 3, r.end.x - 4), r.position.y), col, 1.0)
		ci.draw_line(Vector2(x, r.end.y), Vector2(minf(x + 3, r.end.x - 4), r.end.y), col, 1.0)
		x += step
	var y := r.position.y + 4
	while y < r.end.y - 4:
		ci.draw_line(Vector2(r.position.x, y), Vector2(r.position.x, minf(y + 3, r.end.y - 4)), col, 1.0)
		ci.draw_line(Vector2(r.end.x, y), Vector2(r.end.x, minf(y + 3, r.end.y - 4)), col, 1.0)
		y += step


# --- frames ------------------------------------------------------------------------------

func draw_frame(p: Dictionary) -> void:
	# Quiet fibers stay in the outer margin, away from the live rules and art.
	for y in range(13, int(BASE.y) - 10, 13):
		var length := 1.0 + float(y % 3)
		_cv.draw_line(Vector2(4.5, y), Vector2(4.5 + length, y + 1), Color(p.ink, 0.12), 1.0)
		_cv.draw_line(Vector2(BASE.x - 4.5, y + 3), Vector2(BASE.x - 4.5 - length, y + 4), Color(p.ink, 0.12), 1.0)
	call(ClassStyle.of(_cv.class_id).frame, p)


func _frame_deserter(p: Dictionary) -> void:
	# Small repaired cloth corners echo the patched greatcoat.
	for pt in [Vector2(3, 3), Vector2(BASE.x - 3, 3), Vector2(3, BASE.y - 3), Vector2(BASE.x - 3, BASE.y - 3)]:
		_cv.draw_line(pt + Vector2(-2, -1), pt + Vector2(2, 1), Color(p.ink, 0.65), 1.0)
		_cv.draw_line(pt + Vector2(-2, 1), pt + Vector2(2, -1), Color(p.ink, 0.65), 1.0)


func _frame_thief(p: Dictionary) -> void:
	# Sea-glass thread stitched round the stock.
	var r := Rect2(7, 7, BASE.x - 14, BASE.y - 14)
	dashed_rect(_cv, r, Color(p.accent, 0.55))


func _frame_medium(p: Dictionary) -> void:
	# A thin bone double line.
	CardFace.box(_cv, Rect2(6, 6, BASE.x - 12, BASE.y - 12), Color(0, 0, 0, 0), 4, 1, Color(p.accent, 0.4))


func _frame_status(p: Dictionary) -> void:
	# Torn, mildewed edge: a ragged dashed border and a few creeping blotches in the corners.
	var accent: Color = p.accent
	dashed_rect(_cv, Rect2(6, 6, BASE.x - 12, BASE.y - 12), Color(accent, 0.6))
	for pt in [Vector2(9, 9), Vector2(BASE.x - 12, BASE.y - 14), Vector2(BASE.x - 14, 12)]:
		_cv.draw_circle(pt + Vector2(2, 2), 2.4, Color(accent, 0.22))


func _frame_plain(p: Dictionary) -> void:
	CardFace.box(_cv, Rect2(6, 6, BASE.x - 12, BASE.y - 12), Color(0, 0, 0, 0), 4, 1, Color(p.accent, 0.25))


# --- header trim -------------------------------------------------------------------------

func draw_header(rect: Rect2, p: Dictionary) -> void:
	call(ClassStyle.of(_cv.class_id).header, rect, p)


func _header_deserter(header: Rect2, p: Dictionary) -> void:
	# A short hand-sewn repair, rather than industrial hazard striping.
	_cv.draw_line(Vector2(38, header.end.y - 3), Vector2(98, header.end.y - 3), Color(p.accent, 0.55), 1.0)
	for x in range(42, 98, 8):
		_cv.draw_line(Vector2(x, header.end.y - 5), Vector2(x + 2, header.end.y - 1), Color(p.ink, 0.55), 1.0)


func _header_thief(header: Rect2, p: Dictionary) -> void:
	var accent: Color = p.accent
	_cv.draw_line(Vector2(header.position.x + 4, header.end.y - 3), Vector2(header.end.x - 4, header.end.y - 3), Color(accent, 0.7), 1.0)
	for i in 6:
		_cv.draw_line(Vector2(header.position.x + 40 + i * 9, header.end.y - 3), Vector2(header.position.x + 44 + i * 9, header.end.y - 1), Color(accent, 0.7), 1.0)


func _header_medium(_header: Rect2, p: Dictionary) -> void:
	for pt in [Vector2(42, 21), Vector2(94, 21), Vector2(60, 25), Vector2(78, 25)]:
		_cv.draw_circle(pt + Vector2(0, 0), 0.9, Color(p.accent, 0.7))


func _header_status(header: Rect2, p: Dictionary) -> void:
	# A row of drips along the header's lower edge.
	for x in range(42, 98, 9):
		_cv.draw_line(Vector2(x, header.end.y - 4), Vector2(x, header.end.y - 1 + float(x % 3)), Color(p.accent, 0.7), 1.6)


func _header_plain(header: Rect2, p: Dictionary) -> void:
	_cv.draw_line(Vector2(header.position.x + 4, header.end.y - 3), Vector2(header.end.x - 4, header.end.y - 3), Color(p.ink, 0.25), 1.0)


# --- corner emblems ----------------------------------------------------------------------

func draw_emblem(c: Vector2, p: Dictionary) -> void:
	_cv.draw_circle(c, 13.5, Color(0, 0, 0, 0.5))
	_cv.draw_circle(c, 12.5, p.frame)
	call(ClassStyle.of(_cv.class_id).emblem, c, p)


func _emblem_deserter(c: Vector2, p: Dictionary) -> void:
	# The soldier's squared forearm guard.
	var frame_col: Color = p.frame
	_cv.draw_colored_polygon(PackedVector2Array([c + Vector2(-6, -7), c + Vector2(6, -7), c + Vector2(5, 5), c + Vector2(0, 8), c + Vector2(-5, 5)]), p.glyph)
	_cv.draw_line(c + Vector2(-3, -2), c + Vector2(3, -2), frame_col, 1.2)
	_cv.draw_line(c + Vector2(-3, 2), c + Vector2(3, 2), frame_col, 1.2)


func _emblem_thief(c: Vector2, p: Dictionary) -> void:
	# A keyhole.
	var glyph: Color = p.glyph
	_cv.draw_circle(c + Vector2(0, -2.5), 4.0, glyph)
	_cv.draw_colored_polygon(PackedVector2Array([c + Vector2(-1.8, 0), c + Vector2(1.8, 0), c + Vector2(3.8, 7.5), c + Vector2(-3.8, 7.5)]), glyph)


func _emblem_medium(c: Vector2, p: Dictionary) -> void:
	# Cloudy-glass orb, matching the Medium's current keepsake.
	_cv.draw_circle(c, 7.0, p.glyph)
	_cv.draw_arc(c, 5.1, PI * 1.1, PI * 1.7, 14, Color(p.ink, 0.8), 1.3, true)
	_cv.draw_arc(c + Vector2(0, 1), 3.5, 0.2, PI, 12, Color(p.frame, 0.8), 1.5, true)


func _emblem_status(c: Vector2, p: Dictionary) -> void:
	# A sickly eye, half shut.
	var glyph: Color = p.glyph
	_cv.draw_arc(c + Vector2(0, 1), 6.5, PI * 1.12, PI * 1.88, 12, glyph, 1.6, true)
	_cv.draw_arc(c + Vector2(0, -1), 6.5, PI * 0.12, PI * 0.88, 12, glyph, 1.6, true)
	_cv.draw_circle(c, 2.2, glyph)


func _emblem_plain(c: Vector2, p: Dictionary) -> void:
	# A pressed leaf, preserving a small ordinary memory.
	_cv.draw_colored_polygon(PackedVector2Array([c + Vector2(-6, 5), c + Vector2(-5, -2), c + Vector2(1, -7), c + Vector2(6, -6), c + Vector2(5, 1), c + Vector2(-1, 6)]), p.glyph)
	_cv.draw_line(c + Vector2(-6, 7), c + Vector2(4, -5), p.frame, 1.2)


# --- art-window motifs -------------------------------------------------------------------

## The class motif behind the code-drawn icons, plus three enemy pips top left on an all-enemies card.
func draw_motif(win: Rect2, p: Dictionary) -> void:
	call(ClassStyle.of(_cv.class_id).motif, win, p)
	if _cv.card.target_mode == CardData.TargetMode.ALL_ENEMIES:
		for i in 3:
			var pt := Vector2(win.position.x + 11 + i * 9, win.position.y + 9)
			_cv.draw_circle(pt, 2.6, Color(0.92, 0.55, 0.5))
			_cv.draw_colored_polygon(PackedVector2Array([pt + Vector2(-3.5, 8), pt + Vector2(3.5, 8), pt + Vector2(0, 3)]), Color(0.92, 0.55, 0.5))


func _motif_deserter(win: Rect2, p: Dictionary) -> void:
	var accent: Color = p.accent
	var x := win.position.x - 40
	while x < win.end.x:
		var a := Vector2(maxf(x, win.position.x), win.end.y)
		var b := Vector2(minf(x + 50, win.end.x), win.position.y)
		if x < win.position.x:
			a = Vector2(win.position.x, win.end.y - (win.position.x - x))
		if x + 50 > win.end.x:
			b = Vector2(win.end.x, win.position.y + (x + 50 - win.end.x))
		_cv.draw_line(a, b, Color(accent, 0.12), 3.0)
		x += 14


func _motif_thief(win: Rect2, p: Dictionary) -> void:
	var accent: Color = p.accent
	var y := win.position.y + 6
	while y < win.end.y - 3:
		_cv.draw_line(Vector2(win.position.x + 4, y), Vector2(win.end.x - 4, y), Color(accent, 0.10), 1.0)
		y += 6


func _motif_medium(win: Rect2, p: Dictionary) -> void:
	var accent: Color = p.accent
	var c := win.get_center()
	for r in [10.0, 18.0, 26.0]:
		_cv.draw_arc(c, r, 0, TAU, 32, Color(accent, 0.12), 1.0, true)


func _motif_status(win: Rect2, p: Dictionary) -> void:
	var accent: Color = p.accent
	var c := win.get_center()
	for r in [8.0, 15.0, 22.0]:
		_cv.draw_arc(c, r, 0.4 * r, 0.4 * r + 4.2, 20, Color(accent, 0.18), 1.4, true)


func _motif_plain(win: Rect2, _p: Dictionary) -> void:
	_cv.draw_arc(win.get_center(), 18.0, 0, TAU, 32, Color(0.9, 0.86, 0.76, 0.1), 1.0, true)
