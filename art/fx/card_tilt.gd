class_name CardTilt
extends RefCounted
## Tilts any Control toward the mouse while hovered and eases back on exit.
##   CardTilt.attach(card_control)

const SHADER := preload("res://art/fx/card_tilt.gdshader")


static func attach(target: Control) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	target.material = mat
	var state := {"tilt": Vector2.ZERO}
	var tick := Timer.new()
	tick.wait_time = 1.0 / 60.0
	tick.autostart = true
	tick.timeout.connect(func():
		var goal := Vector2.ZERO
		if Rect2(Vector2.ZERO, target.size).has_point(target.get_local_mouse_position()):
			goal = ((target.get_local_mouse_position() / target.size) - Vector2(0.5, 0.5)) * 2.0
		state.tilt = state.tilt.lerp(goal, 0.2)
		mat.set_shader_parameter("tilt", state.tilt)
		mat.set_shader_parameter("size_px", target.size))
	target.add_child(tick)
