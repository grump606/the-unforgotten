class_name RestScene
extends ScreenScene
## Quiet shelter. The painting supplies its own furniture and figures.
var character_id: StringName = &""

func _init() -> void:
	super(2025, 26)

func breath() -> float:
	return sin(time * 0.9)

func _draw_scene(w: float, h: float) -> void:
	if not _draw_painted_bg(&"rest", Rect2(0, 0, w, h), 1.08, 0.4, Color(0.8, 0.8, 0.8)):
		_draw_shelter(w, h)
	_draw_motes(w, h, AMBER, 0.35)
	_draw_scrim(w, h)

func _draw_shelter(w: float, h: float) -> void:
	var floor_y := h * 0.82
	_gradient(Rect2(0, 0, w, floor_y), Color(0.10, 0.12, 0.14), Color(0.17, 0.15, 0.13))
	draw_rect(Rect2(0, floor_y, w, h - floor_y), Color(0.08, 0.07, 0.07))
	for row in 6:
		var y := row * floor_y / 6.0
		draw_line(Vector2(0, y), Vector2(w, y), Color(NIGHT, 0.35), 1.5)
		for col in 8:
			var x := (col + 0.5 * (row % 2)) * w / 7.0
			draw_line(Vector2(x, y), Vector2(x, y + floor_y / 6.0), Color(NIGHT, 0.3), 1.0)
	var table := Vector2(w * 0.72, floor_y - 58.0)
	draw_rect(Rect2(table - Vector2(110, 0), Vector2(220, 9)), WOOD)
	for x in [-95.0, 85.0]:
		draw_rect(Rect2(table + Vector2(x, 9), Vector2(8, 49)), WOOD.darkened(0.25))
	_halo(table + Vector2(0, -26), 170, AMBER, 0.014 * flicker(2))
	draw_rect(Rect2(table + Vector2(-4, -39), Vector2(8, 36)), Color(PALE, 0.7))
	_ellipse(table + Vector2(0, -44), 3, 7, Color(AMBER, flicker(2)), 12)
	# A folded blanket and cup suggest shelter without a class-specific silhouette.
	draw_rect(Rect2(table + Vector2(30, -16), Vector2(55, 16)), Color(0.30, 0.29, 0.34))
	draw_rect(Rect2(table + Vector2(-56, -15), Vector2(19, 15)), Color(PALE, 0.55))
