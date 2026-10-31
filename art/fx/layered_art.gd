class_name LayeredArt
extends Control
## Stacks painted layers (back to front) and shifts each one by its depth so the picture reads
## as 2.5D. Depth 0 stays put; higher depths move more. Offset follows the mouse over the
## control and idles with a slow sway otherwise.
##   var art := LayeredArt.new(); art.set_layers(["bg.png", "mid.png", ...], [0.0, 0.3, 0.6, 1.2])

@export var strength := 14.0  ## pixels of shift for depth 1.0
@export var sway := 0.35  ## idle sway amount, 0 turns it off

var _rects: Array[TextureRect] = []
var _depths: Array[float] = []
var _target := Vector2.ZERO
var _offset := Vector2.ZERO
var _time := 0.0


func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_PASS


func set_layers(paths: Array, depths: Array) -> void:
	for r in _rects:
		r.queue_free()
	_rects.clear()
	_depths.clear()
	for i in paths.size():
		var tr := TextureRect.new()
		tr.texture = load(paths[i])
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(tr)
		_rects.append(tr)
		_depths.append(depths[i])
	_layout()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


func _margin() -> Vector2:
	return Vector2.ONE * strength * 1.5


func _layout() -> void:
	for tr in _rects:
		tr.position = -_margin()
		tr.size = size + _margin() * 2.0


func _process(delta: float) -> void:
	_time += delta
	var mouse := get_local_mouse_position()
	if Rect2(Vector2.ZERO, size).has_point(mouse):
		_target = ((mouse / size) - Vector2(0.5, 0.5)) * -2.0
	else:
		_target = Vector2(sin(_time * 0.7), cos(_time * 0.5) * 0.5) * sway
	_offset = _offset.lerp(_target, 1.0 - exp(-6.0 * delta))
	for i in _rects.size():
		_rects[i].position = -_margin() + _offset * strength * _depths[i]
