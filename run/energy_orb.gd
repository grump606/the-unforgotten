class_name EnergyOrb
extends Control
## The player's energy as a glowing orb with "current/max" inside (bottom left of the battle screen).
## It dims when there is no energy left.

const SIZE := 78.0
const ENERGY_COLOR := Color("#e8b773")

var current := 0
var maximum := 0
## "2/3": what the orb shows (read by tests).
var text := ""


func _init() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	mouse_filter = Control.MOUSE_FILTER_PASS
	tooltip_text = "Energy: each card costs energy to play. It refills every turn."


func set_energy(value: int, max_value: int) -> void:
	current = value
	maximum = max_value
	text = "%d/%d" % [current, maximum]
	queue_redraw()


func _draw() -> void:
	var c := size / 2.0
	var r := minf(size.x, size.y) / 2.0 - 3.0
	var live := current > 0
	var col := ENERGY_COLOR if live else Color("#526979")
	draw_circle(c, r + 3.0, Color(0, 0, 0, 0.55))
	# A weathered keepsake setting around dark, cloudy glass.
	draw_circle(c, r, Color("#526979"))
	draw_circle(c, r - 2.5, Color("#171d28"))
	draw_circle(c, r * 0.83, Color("#26343d"))
	for i in 8:
		var a := TAU * i / 8.0 + 0.12
		draw_arc(c, r - 1.0, a, a + 0.35, 6, Color("#d7d0bc") * Color(1, 1, 1, 0.45), 1.1, true)
	# The preserved ember sits behind the live numeral; no number is baked into art.
	var ember := c + Vector2(0, r * 0.25)
	if live:
		for i in 5:
			draw_circle(ember, r * (0.70 - i * 0.10), Color(col, 0.045 + i * 0.018))
		var flame := PackedVector2Array([
			ember + Vector2(-r * 0.27, r * 0.15),
			ember + Vector2(-r * 0.21, -r * 0.20),
			ember + Vector2(-r * 0.04, -r * 0.43),
			ember + Vector2(r * 0.07, -r * 0.20),
			ember + Vector2(r * 0.25, -r * 0.34),
			ember + Vector2(r * 0.29, r * 0.15),
		])
		draw_colored_polygon(flame, Color(col, 0.38))
	else:
		draw_arc(ember, r * 0.24, 0, PI, 14, Color(col, 0.55), 2.0, true)
	draw_arc(c, r * 0.80, PI * 1.06, PI * 1.56, 18, Color("#d7d0bc") * Color(1, 1, 1, 0.5 if live else 0.25), 1.6, true)
	draw_arc(c + Vector2(r * 0.08, 0), r * 0.60, 0.10, 0.65, 12, Color("#78a99b") * Color(1, 1, 1, 0.18), 1.0, true)
	HudIcons.text(self, text, Rect2(c - Vector2(r, 14), Vector2(r * 2.0, 28)), 24, Color(1, 0.97, 0.9), true, 4)
