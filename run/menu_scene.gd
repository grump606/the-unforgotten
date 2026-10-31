class_name MenuScene
extends ScreenScene
## Key art behind the main menu: the painted ghost-train platform (art/layers/screens/menu/bg.png) with a
## slow drift, drifting mist and embers, and the three classes standing on the platform on either side of
## the buttons (their painted stage sprites, breathing slowly). A soft dark column keeps the buttons
## readable. Without the painting it falls back to a plain night gradient with a warm glow.

## id, x as a fraction of the width, height as a fraction of the height, faces right
const HEROES := [
	[&"deserter", 0.13, 0.50, true],
	[&"pickpocket", 0.27, 0.43, true],
	[&"medium", 0.87, 0.48, false],
]
const GROUND := 0.94


func _init() -> void:
	super(3030, 44)


## Breathing of the figures in -1..1; each hero is offset so they do not move in step.
func breath(k: int) -> float:
	return sin(time * 0.9 + k * 1.7)


func _draw_scene(w: float, h: float) -> void:
	if not _draw_painted_bg(&"menu", Rect2(0, 0, w, h), 1.08, 0.45, Color(0.9, 0.9, 0.9)):
		_gradient(Rect2(0, 0, w, h), Color(0.02, 0.025, 0.04), Color(0.06, 0.05, 0.05))
		_halo(Vector2(w * 0.5, h * 0.55), w * 0.4, AMBER, 0.01 * flicker(0), 0.6)
	_draw_mist(w, h)
	for k in HEROES.size():
		_draw_hero(k, w, h)
	_draw_column(w, h)
	_draw_motes(w, h, AMBER, 0.9)
	_draw_scrim(w, h, 0.0)


## Low fog along the platform, rolling slowly.
func _draw_mist(w: float, h: float) -> void:
	for i in 5:
		var y := h * (0.74 + 0.05 * i)
		var drift := sin(time * 0.12 + i * 1.9) * w * 0.03
		var band := Color(0.55, 0.62, 0.72, 0.035 + 0.01 * i)
		_ellipse(Vector2(w * 0.5 + drift, y), w * (0.75 + 0.05 * i), h * 0.07, band, 24)


func _draw_hero(k: int, w: float, h: float) -> void:
	var entry: Array = HEROES[k]
	var fig := PaintedArt.player_figure(entry[0])
	if fig.is_empty():
		return
	var tex: Texture2D = fig.tex
	var height: float = h * entry[2]
	var width := height * tex.get_width() / tex.get_height()
	var feet := Vector2(w * entry[1], h * GROUND)
	# The art faces left as drawn; mirror it for the heroes that face right.
	var flip := -1.0 if entry[3] else 1.0
	_ellipse(feet, width * 0.42, 9.0, Color(0, 0, 0, 0.4), 20)
	draw_set_transform(feet, 0.0, Vector2(flip, 1.0 + breath(k) * 0.012))
	# A little dimmer than the stage so the heroes sit in the platform's dark.
	draw_texture_rect(tex, Rect2(-width / 2.0, -height, width, height), false, Color(0.82, 0.82, 0.86))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A soft dark column down the middle behind the title and buttons.
func _draw_column(w: float, h: float) -> void:
	var half := w * 0.24
	var cx := w * 0.5
	var dark := Color(0.01, 0.01, 0.015, 0.8)
	var clear := Color(dark, 0.0)
	draw_polygon(PackedVector2Array([Vector2(cx - half, 0), Vector2(cx, 0), Vector2(cx, h), Vector2(cx - half, h)]), PackedColorArray([clear, dark, dark, clear]))
	draw_polygon(PackedVector2Array([Vector2(cx, 0), Vector2(cx + half, 0), Vector2(cx + half, h), Vector2(cx, h)]), PackedColorArray([dark, clear, clear, dark]))
