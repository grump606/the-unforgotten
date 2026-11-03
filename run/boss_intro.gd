class_name BossIntro
extends Control
## Full-screen boss entrance: the stage dims and a name plate slides in (label above, name large in the serif
## heading font). A click ends it early; the battle also ends it on any key. Emits finished once.

signal finished

const DURATION := 2.0
const REDUCED_DURATION := 0.8
const DIM := Color(0.02, 0.0, 0.01, 0.62)

var _done := false
var _plate: VBoxContainer
var _center: CenterContainer
var _tween: Tween
var label: Label
var name_label: Label


## `label_text` is shown above the name ("MID-BOSS", "FINAL BOSS").
func setup(label_text: String, boss_name: String) -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 50
	var dim := ColorRect.new()
	dim.color = DIM
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	_center = center
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_plate = VBoxContainer.new()
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(_plate)
	label = Label.new()
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", MenuStyle.AMBER)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("outline_size", 4)
	_plate.add_child(label)
	name_label = Label.new()
	name_label.text = boss_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	MenuStyle.heading(name_label, 64)
	name_label.add_theme_color_override("font_color", MenuStyle.TEXT)
	_plate.add_child(name_label)
	var rule := ColorRect.new()
	rule.color = Color(MenuStyle.DAMAGE, 0.85)
	rule.custom_minimum_size = Vector2(0, 2)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.add_child(rule)
	_plate.modulate.a = 0.0


func _ready() -> void:
	var reduced := CardView.reduced_motion
	var total := REDUCED_DURATION if reduced else DURATION
	_tween = create_tween()
	_tween.tween_property(_plate, "modulate:a", 1.0, 0.3 if not reduced else 0.1)
	if not reduced:
		# The plate drifts in from the left over the fade, then rests.
		_center.position.x -= 60.0
		_tween.parallel().tween_property(_center, "position:x", _center.position.x + 60.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(total - 0.7)
	_tween.tween_property(self, "modulate:a", 0.0, 0.4 if not reduced else 0.2)
	_tween.tween_callback(skip)


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed:
		accept_event()
		skip()


## Ends the intro now (once).
func skip() -> void:
	if _done:
		return
	_done = true
	if _tween != null:
		_tween.kill()
	finished.emit()
	queue_free()


func is_done() -> bool:
	return _done
