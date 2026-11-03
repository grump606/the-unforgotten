class_name MenuStyle
extends RefCounted
## Shared menu presentation; gameplay text and input behavior are unchanged.

## Shared palette (styling pass). Use these instead of ad-hoc colors.
const BG := Color("#10151d")
const PANEL := Color("#171d28")
const PANEL_HOVER := Color("#33444d")
const BORDER := Color("#526979")
const TEXT := Color("#e8e1d0")
const TEXT_DIM := Color("#a6b9b5")
const AMBER := Color("#e8b773")
const DAMAGE := Color("#d96b65")
const BLOCK := Color("#83b4cf")

## Button theme-type variations: set `button.theme_type_variation` to one of these.
const PRIMARY := &"PrimaryButton"
const QUIET := &"QuietButton"
const DANGER := &"DangerButton"

static func apply(host: Control) -> void:
	host.theme = build_theme()
	var backdrop := ColorRect.new()
	backdrop.name = "MenuGround"
	backdrop.color = Color("#171d28")
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(backdrop)
	host.move_child(backdrop, 0)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

## Gives a standalone scene (no run screen above it) the same look as the run.
static func apply_theme_only(host: Control) -> void:
	host.theme = build_theme()

static func _button_states(theme: Theme, type_name: String, border: Color, text: Color, fill_tint := 0.0) -> void:
	var emphasized := type_name != "Button"
	for state in ["normal", "hover", "pressed", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = PANEL_HOVER if state == "hover" else PANEL
		if state == "pressed":
			box.bg_color = Color("#101720")
		box.bg_color = box.bg_color.lerp(border, fill_tint)
		box.bg_color.a = 0.94
		box.border_color = BORDER if state == "disabled" else border
		box.set_border_width_all(2 if emphasized and state != "disabled" else 1)
		box.set_corner_radius_all(3)
		box.content_margin_left = 16
		box.content_margin_right = 16
		box.content_margin_top = 7
		box.content_margin_bottom = 7
		theme.set_stylebox(state, type_name, TactileArt.textured_style(box))
	theme.set_color("font_color", type_name, text)
	theme.set_color("font_hover_color", type_name, text.lightened(0.15))
	theme.set_color("font_pressed_color", type_name, text.darkened(0.1))
	theme.set_color("font_disabled_color", type_name, Color("#81898b"))
	if emphasized:
		theme.set_type_variation(type_name, "Button")

static func build_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 16
	theme.set_color("font_color", "Label", Color("#d7d0bc"))
	_button_states(theme, "Button", Color("#9b9e90"), Color("#d7d0bc"))
	theme.set_color("font_hover_color", "Button", Color("#eee5ce"))
	theme.set_color("font_pressed_color", "Button", Color("#78a99b"))
	_button_states(theme, String(PRIMARY), AMBER, AMBER, 0.12)
	_button_states(theme, String(QUIET), BORDER, TEXT_DIM)
	_button_states(theme, String(DANGER), DAMAGE, Color("#f0b3ad"), 0.1)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = AMBER
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(3)
	theme.set_stylebox("focus", "Button", focus)
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(PANEL, 0.94)
	panel.border_color = BORDER
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(4)
	panel.set_content_margin_all(20)
	panel.shadow_color = Color(0, 0, 0, 0.35)
	panel.shadow_size = 6
	theme.set_stylebox("panel", "PanelContainer", panel)
	var tip := panel.duplicate() as StyleBoxFlat
	tip.set_content_margin_all(8)
	tip.shadow_size = 3
	theme.set_stylebox("panel", "TooltipPanel", tip)
	theme.set_color("font_color", "TooltipLabel", TEXT)
	return theme

static func heading(label: Label, font_size := 32) -> void:
	var serif := SystemFont.new()
	serif.font_names = PackedStringArray(["Georgia", "Cambria"])
	label.add_theme_font_override("font", serif)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("#d7d0bc"))
	label.add_theme_color_override("font_shadow_color", Color(0.03, 0.04, 0.06, 0.9))
	label.add_theme_constant_override("shadow_offset_y", 2)
