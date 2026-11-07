class_name EventScene
extends ScreenScene
## The scene behind an event stop (docs/EVENTS_DESIGN.md): one of the painted screens, dimmed and cooled so the
## story card in front reads over it, with a few drifting motes. `painting` is set by EventScreen from the event's
## `scene` field before the scene is shown; a missing picture leaves a plain dark gradient.

const TINT := Color(0.40, 0.43, 0.50)

var painting: StringName = &"battle_street"


func _init() -> void:
	super(6131, 26)


func _draw_scene(w: float, h: float) -> void:
	if not _draw_painted_bg(painting, Rect2(0, 0, w, h), 1.08, 0.3, TINT):
		_gradient(Rect2(0, 0, w, h), Color(0.05, 0.07, 0.10), Color(0.10, 0.09, 0.12))
	draw_rect(Rect2(0, 0, w, h), Color(0.02, 0.02, 0.04, 0.42))
	# A cold teal-violet wash from above, the colour of the "?" stops on the map.
	_gradient(Rect2(0, 0, w, h * 0.5), Color(0.30, 0.34, 0.55, 0.16), Color(0.30, 0.34, 0.55, 0.0))
	_draw_motes(w, h, PALE, 0.4)
	_draw_scrim(w, h)
