class_name BossBar
extends Control
## The boss's name plate and wide HP bar across the top of the battle stage, in a dark red / ember palette.
## A tick marks the HP percent where phase two begins, so the player sees it coming. Drawing only; the battle
## calls refresh() when the fight state changes.

const HEIGHT := 36.0
const BAR_H := 12.0
const BACK := Color(0.08, 0.025, 0.03, 0.92)
const FILL := Color(0.55, 0.10, 0.08)
const FILL_ENRAGED := Color(0.86, 0.26, 0.10)
const EMBER := Color(1.0, 0.55, 0.32)
const FRAME := Color(0.45, 0.16, 0.12)

var unit: EnemyUnit
var label_text := "BOSS"
## HP a dragged card would take (see set_drop_lost); -1 for none.
var drop_lost := -1
var _font: SystemFont


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, HEIGHT)
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Georgia", "Cambria"])


func setup(enemy: EnemyUnit, label: String) -> void:
	unit = enemy
	label_text = label.to_upper()
	queue_redraw()


func refresh() -> void:
	queue_redraw()


## While a card is dragged over the boss: ghosts the `lost` HP it would take in gold (-1 clears it).
func set_drop_lost(lost: int) -> void:
	drop_lost = lost
	queue_redraw()


## Whether the bar shows a phase marker (the enemy has a phase two).
func has_marker() -> bool:
	return unit != null and not unit.data.phase_two_intents.is_empty()


## Where the phase-two tick sits along the bar, 0..1 of its width.
func marker_ratio() -> float:
	return float(unit.data.phase_two_hp_percent) / 100.0 if has_marker() else 0.0


func bar_rect() -> Rect2:
	return Rect2(0.0, HEIGHT - BAR_H - 2.0, size.x, BAR_H)


func _draw() -> void:
	if unit == null:
		return
	var enraged := unit.phase == 2
	var bar := bar_rect()
	draw_string(_font, Vector2(0, 17.0), unit.display_name, HORIZONTAL_ALIGNMENT_LEFT, size.x, 19, MenuStyle.TEXT)
	var has_block := unit.block > 0
	var frame := MenuStyle.BLOCK if has_block else (MenuStyle.DAMAGE if enraged else FRAME)
	HudIcons.box(self, bar, BACK, 3, 2 if has_block else 1, frame)
	var ratio := clampf(float(unit.hp) / maxf(float(unit.max_hp), 1.0), 0.0, 1.0)
	if ratio > 0.0:
		var fill := FILL_ENRAGED if enraged else FILL
		var inner := Rect2(bar.position + Vector2(1, 1), Vector2(maxf((bar.size.x - 2.0) * ratio, 4.0), bar.size.y - 2.0))
		HudIcons.box(self, inner, fill, 2)
		draw_rect(Rect2(inner.position, Vector2(inner.size.x, inner.size.y * 0.35)), Color(EMBER, 0.18))
	if drop_lost > 0:
		# The HP the card would take, ghosted in gold between what would remain and what is there now.
		var width := bar.size.x - 2.0
		var left := clampf(float(unit.hp - drop_lost) / maxf(float(unit.max_hp), 1.0), 0.0, 1.0) * width
		var right := ratio * width
		if right > left:
			HudIcons.box(self, Rect2(bar.position + Vector2(1.0 + left, 1.0), Vector2(right - left, bar.size.y - 2.0)), Color(MenuStyle.AMBER, 0.9), 2)
	if has_marker():
		var x := bar.position.x + bar.size.x * marker_ratio()
		var crossed := enraged
		var col := Color(MenuStyle.AMBER, 0.45 if crossed else 0.95)
		draw_line(Vector2(x, bar.position.y - 3.0), Vector2(x, bar.end.y + 3.0), col, 2.0)
		draw_colored_polygon(PackedVector2Array([Vector2(x - 4, bar.position.y - 6.0), Vector2(x + 4, bar.position.y - 6.0), Vector2(x, bar.position.y - 1.0)]), col)
	HudIcons.text(self, "%d/%d" % [maxi(unit.hp, 0), unit.max_hp], bar, 10, Color(1, 1, 1), true, 2)
	if has_block:
		var c := Vector2(bar.end.x + 12.0, bar.get_center().y)
		HudIcons.shield(self, c, 11.0, Color(0, 0, 0, 0.6))
		HudIcons.shield(self, c, 9.5, Color(MenuStyle.BLOCK.darkened(0.3)))
		HudIcons.text(self, str(unit.block), Rect2(c - Vector2(10, 9), Vector2(20, 18)), 11, Color(1, 1, 1), true, 2)
