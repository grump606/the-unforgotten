class_name StoryScene
extends ScreenScene
## Painted destination windows. Legacy mood keys retain existing resource paths.

const BAR := 34.0
var beat_index := 0

func _init() -> void:
	super(2033, 28)

func mood() -> StringName:
	match beat_index:
		0:
			return &"boarding"
		1:
			return &"conductor"
		2:
			return &"platform"
		3:
			return &"last_light"
	return &"tunnel"

func _draw_scene(w: float, h: float) -> void:
	var win := Rect2(0, BAR, w, h - 2.0 * BAR)
	var mood_name := mood()
	var key := &"story_generic" if mood_name == &"tunnel" else StringName("story_" + String(mood_name))
	if not _draw_painted_bg(key, win, 1.08, 0.4):
		_draw_destination(win)
	draw_rect(Rect2(0, 0, w, BAR), Color.BLACK)
	draw_rect(Rect2(0, h - BAR, w, BAR), Color.BLACK)
	draw_line(Vector2(0, BAR), Vector2(w, BAR), Color(PALE, 0.35), 1.0)
	draw_line(Vector2(0, h - BAR), Vector2(w, h - BAR), Color(PALE, 0.35), 1.0)
	_draw_motes(w, h, PALE, 0.45)
	_draw_scrim(w, h, 0.12)

func _draw_destination(win: Rect2) -> void:
	# Quiet stone architecture remains coherent if an optional painting is missing.
	var horizon := win.position.y + win.size.y * 0.72
	_gradient(win, Color(0.12, 0.17, 0.22), NIGHT)
	draw_rect(Rect2(win.position.x, horizon, win.size.x, win.end.y - horizon), Color(0.08, 0.10, 0.12))
	match beat_index:
		0:
			for i in 8:
				var x := win.size.x * i / 7.0
				var height := 50.0 + _noise[i] * 110.0
				draw_rect(Rect2(x, horizon - height, win.size.x * 0.09, height), Color(0.09, 0.12, 0.15))
			draw_rect(Rect2(win.size.x * 0.25, horizon - 72, 32, 72), Color(PALE, 0.25))
		1:
			for i in 7:
				var x := win.size.x * (0.08 + i * 0.13)
				draw_rect(Rect2(x, win.position.y + 45, 32, 100), Color(PALE, 0.12))
				draw_line(Vector2(x + 5, win.position.y + 96), Vector2(x + 27, win.position.y + 96), Color(NIGHT, 0.8), 2.0)
		2:
			for i in 10:
				var x := win.size.x * (0.04 + i * 0.10)
				var y := horizon + 12 + _noise[i] * 45.0
				draw_rect(Rect2(x, y - 45, 24, 45), Color(PALE, 0.22))
		3:
			var door := Rect2(win.size.x * 0.65, win.position.y + win.size.y * 0.16, win.size.x * 0.12, win.size.y * 0.56)
			_halo(door.get_center(), 160, PALE, 0.012 * (0.9 + 0.1 * sin(time)))
			draw_rect(door, Color(PALE, 0.55))
		_:
			draw_line(Vector2(0, horizon), Vector2(win.size.x, horizon), Color(PALE, 0.2), 2)
