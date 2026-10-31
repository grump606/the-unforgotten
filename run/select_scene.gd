class_name SelectScene
extends ScreenScene
## Backdrop of the character select screen: the painted station platform (art/layers/screens/select/bg.png)
## drifting slowly under mist and embers, darkened so the three panels stay the focus. Without the painting
## it falls back to a plain night gradient.


func _init() -> void:
	super(4040, 36)


func _draw_scene(w: float, h: float) -> void:
	if not _draw_painted_bg(&"select", Rect2(0, 0, w, h), 1.08, 0.4, Color(0.62, 0.62, 0.66)):
		_gradient(Rect2(0, 0, w, h), Color(0.02, 0.025, 0.04), Color(0.06, 0.05, 0.05))
	for i in 4:
		var y := h * (0.70 + 0.07 * i)
		var drift := sin(time * 0.12 + i * 1.9) * w * 0.03
		_ellipse(Vector2(w * 0.5 + drift, y), w * (0.8 + 0.05 * i), h * 0.07, Color(0.55, 0.62, 0.72, 0.03 + 0.008 * i), 24)
	_draw_motes(w, h, AMBER, 0.9)
	_draw_scrim(w, h, 0.0)
