class_name TutorialIcon
## An Omen badge or status pill icon, drawn with the same code the fight screen uses.
extends Control

var icon: StringName = &"intent"
var color_kind: int = CardEffect.Kind.DAMAGE

func _init() -> void:
	custom_minimum_size = Vector2(34, 34)
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var col := CardView.kind_color(color_kind)
	var c := size / 2.0
	draw_circle(c, 16.0, Color(0, 0, 0, 0.6))
	draw_circle(c, 14.5, Color(col.darkened(0.5), 0.95))
	draw_arc(c, 14.5, 0, TAU, 28, col, 1.8, true)
	if icon == &"intent":
		HudIcons.intent(self, color_kind, c, col)
	else:
		HudIcons.status(self, icon, c, col.lightened(0.3), 2.2)
