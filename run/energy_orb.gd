class_name EnergyOrb
extends Control
## The player's energy as a glowing orb with "current/max" inside (bottom left of the battle screen).
## It dims when there is no energy left.

const SIZE := 78.0
const ENERGY_COLOR := Color(1.0, 0.72, 0.28)

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
	var col := ENERGY_COLOR if live else Color(0.45, 0.42, 0.45)
	draw_circle(c, r + 3.0, Color(0, 0, 0, 0.55))
	draw_circle(c, r, col.darkened(0.55))
	draw_circle(c, r * 0.78, col.darkened(0.3))
	draw_circle(c - Vector2(r * 0.18, r * 0.2), r * 0.42, Color(col.lightened(0.35), 0.35 if live else 0.12))
	draw_arc(c, r, 0, TAU, 36, col, 3.0, true)
	draw_arc(c, r - 5.0, PI * 1.1, PI * 1.6, 12, Color(1, 1, 1, 0.3 if live else 0.1), 2.0, true)
	HudIcons.text(self, text, Rect2(c - Vector2(r, 14), Vector2(r * 2.0, 28)), 24, Color(1, 0.97, 0.9), true, 4)
