class_name TutorialMarkers
## Numbered gold discs drawn over a picture (or, alone, the number badge beside an explanation).
extends Control

var points: Array = []
## The number on the first disc; the next ones count up.
var first_number := 1

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	for i in points.size():
		var c: Vector2 = points[i]
		draw_circle(c, TutorialOverlay.MARKER_RADIUS + 1.5, Color(0, 0, 0, 0.7))
		draw_circle(c, TutorialOverlay.MARKER_RADIUS, TutorialOverlay.MARKER_FILL)
		var number := str(first_number + i)
		draw_string(font, c + Vector2(-20, 5), number, HORIZONTAL_ALIGNMENT_CENTER, 40, 14, TutorialOverlay.MARKER_INK)
