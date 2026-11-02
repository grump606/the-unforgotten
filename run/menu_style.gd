class_name MenuStyle
extends RefCounted
## Shared menu presentation; gameplay text and input behavior are unchanged.
static func apply(host: Control) -> void:
	var theme := Theme.new()
	theme.default_font_size = 16
	theme.set_color("font_color", "Label", Color("#d7d0bc"))
	for state in ["normal", "hover", "pressed", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color("#171d28") if state != "hover" else Color("#33444d")
		if state == "pressed":
			box.bg_color = Color("#101720")
		box.bg_color.a = 0.94
		box.border_color = Color("#526979") if state == "disabled" else Color("#9b9e90")
		box.set_border_width_all(1)
		box.set_corner_radius_all(3)
		box.content_margin_left = 16
		box.content_margin_right = 16
		box.content_margin_top = 7
		box.content_margin_bottom = 7
		theme.set_stylebox(state, "Button", box)
	theme.set_color("font_color", "Button", Color("#d7d0bc"))
	theme.set_color("font_hover_color", "Button", Color("#eee5ce"))
	theme.set_color("font_pressed_color", "Button", Color("#78a99b"))
	theme.set_color("font_disabled_color", "Button", Color("#81898b"))
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = Color("#e8b773")
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(3)
	theme.set_stylebox("focus", "Button", focus)
	host.theme = theme
	var backdrop := ColorRect.new()
	backdrop.name = "MenuGround"
	backdrop.color = Color("#171d28")
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(backdrop)
	host.move_child(backdrop, 0)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

static func heading(label: Label, font_size := 32) -> void:
	var serif := SystemFont.new()
	serif.font_names = PackedStringArray(["Georgia", "Cambria"])
	label.add_theme_font_override("font", serif)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("#d7d0bc"))
	label.add_theme_color_override("font_shadow_color", Color(0.03, 0.04, 0.06, 0.9))
	label.add_theme_constant_override("shadow_offset_y", 2)
