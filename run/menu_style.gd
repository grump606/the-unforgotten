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
## Brass trim and warm cream text (update notice border and label, the screen scenes' frame).
const BRASS := Color(0.78, 0.55, 0.24)
## Shared UI palette: ink and parchment, the teal accent, wells and rims. Named here so no screen carries a hex literal.
const PARCHMENT := Color("#d7d0bc")
const PARCHMENT_HOVER := Color("#eee5ce")
const TEAL := Color("#78a99b")
const TEAL_LIGHT := Color("#a9cfc2")
const TEAL_SOFT := Color("#8fb8ab")
const WELL := Color("#101720")
const STONE := Color("#9b9e90")
const MUTED := Color("#81898b")
const DISABLED_FILL := Color("#182026")
const SLATE := Color("#26343d")
const MIST := Color("#bcc5bd")
const BRASS_EDGE := Color("#7d6a45")
const DANGER_TEXT := Color("#f0b3ad")
const INK_DARK := Color("#1a1208")
## The small Update button on the main menu: border, text and fill for off, on, and "a newer version is available".
const UPDATE_OFF := [Color("#4a5358"), MUTED, Color("#141a22")]
const UPDATE_ON := [TEAL, TEAL_LIGHT, Color("#1a2a2a")]
const UPDATE_AVAILABLE := [Color("#e0605a"), Color("#ffe3df"), Color("#5a1d1d")]
const CREAM := Color(1.0, 0.93, 0.78)

## Button theme-type variations: set `button.theme_type_variation` to one of these.
const PRIMARY := &"PrimaryButton"
const QUIET := &"QuietButton"
const DANGER := &"DangerButton"
## About a third smaller than a normal button (the Pause button during a fight).
const SMALL := &"SmallButton"

static func apply(host: Control) -> void:
	host.theme = build_theme()
	var backdrop := ColorRect.new()
	backdrop.name = "MenuGround"
	backdrop.color = PANEL
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(backdrop)
	host.move_child(backdrop, 0)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

## Gives a standalone scene (no run screen above it) the same look as the run.
static func apply_theme_only(host: Control) -> void:
	host.theme = build_theme()

static func _button_states(theme: Theme, type_name: String, border: Color, text: Color, fill_tint := 0.0, size_scale := 1.0) -> void:
	var emphasized := type_name != "Button"
	for state in ["normal", "hover", "pressed", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = PANEL_HOVER if state == "hover" else PANEL
		if state == "pressed":
			box.bg_color = WELL
		box.bg_color = box.bg_color.lerp(border, fill_tint)
		box.bg_color.a = 0.94
		box.border_color = BORDER if state == "disabled" else border
		box.set_border_width_all(2 if emphasized and state != "disabled" else 1)
		box.set_corner_radius_all(3)
		box.content_margin_left = 16 * size_scale
		box.content_margin_right = 16 * size_scale
		box.content_margin_top = 7 * size_scale
		box.content_margin_bottom = 7 * size_scale
		theme.set_stylebox(state, type_name, TactileArt.textured_style(box))
	theme.set_color("font_color", type_name, text)
	theme.set_color("font_hover_color", type_name, text.lightened(0.15))
	theme.set_color("font_pressed_color", type_name, text.darkened(0.1))
	theme.set_color("font_disabled_color", type_name, MUTED)
	if emphasized:
		theme.set_type_variation(type_name, "Button")

static func build_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 16
	theme.set_color("font_color", "Label", PARCHMENT)
	_button_states(theme, "Button", STONE, PARCHMENT)
	theme.set_color("font_hover_color", "Button", PARCHMENT_HOVER)
	theme.set_color("font_pressed_color", "Button", TEAL)
	_button_states(theme, String(PRIMARY), AMBER, AMBER, 0.12)
	_button_states(theme, String(QUIET), BORDER, TEXT_DIM)
	_button_states(theme, String(DANGER), DAMAGE, DANGER_TEXT, 0.1)
	_button_states(theme, String(SMALL), BORDER, TEXT_DIM, 0.0, 0.67)
	theme.set_font_size("font_size", String(SMALL), 11)
	if has_plaques():
		_plaque_states(theme, PLAQUE, SLATE_PLAQUE_PATH, TEXT)
		_plaque_states(theme, PLAQUE_PRIMARY, BRASS_PLAQUE_PATH, PLAQUE_INK)
		_plaque_states(theme, PLAQUE_SMALL, SLATE_PLAQUE_PATH, TEXT, 17, 26.0, 7.0)
	else:
		_button_states(theme, String(PLAQUE), BORDER, TEXT)
		_button_states(theme, String(PLAQUE_PRIMARY), AMBER, AMBER, 0.12)
		_button_states(theme, String(PLAQUE_SMALL), BORDER, TEXT)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = AMBER
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(3)
	theme.set_stylebox("focus", "Button", focus)
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(PANEL, 0.94)
	panel.border_color = BRASS_EDGE
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
	label.add_theme_font_override("font", serif_font())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", PARCHMENT)
	label.add_theme_color_override("font_shadow_color", Color(0.03, 0.04, 0.06, 0.9))
	label.add_theme_constant_override("shadow_offset_y", 2)

# --- Memorial plaque style (painted nine-slice plaques, art/layers/ui/plaque_*.png) -----------

## Button theme-type variations for the title screen and the pause menu: aged slate plaque with bone
## lettering, and the brass primary plaque with dark lettering.
const PLAQUE := &"PlaqueButton"
const PLAQUE_PRIMARY := &"PlaquePrimaryButton"
## The same plaque at a smaller size, for the screens after the title (rewards, vendor, rest, select, story).
const PLAQUE_SMALL := &"PlaqueSmallButton"
const SLATE_PLAQUE_PATH := "res://art/layers/ui/plaque_slate.png"
const BRASS_PLAQUE_PATH := "res://art/layers/ui/plaque_brass.png"
const TABLET_PATH := "res://art/layers/ui/tablet.png"
const DIVIDER_PATH := "res://art/layers/ui/divider_bell.png"
const TITLE_PATH := "res://art/layers/ui/title.png"
## Nine-slice margins in pixels of the plaque art: the clipped ends and rivets (x) and the rim (y).
const PLAQUE_SLICE_X := 34.0
const PLAQUE_SLICE_Y := 22.0
const PLAQUE_FONT_SIZE := 22
## Amber outline that follows the plaque's clipped outline, drawn just outside it for keyboard focus.
const FOCUS_RING_PATH := "res://art/layers/ui/plaque_focus.png"
const FOCUS_PAD := 9.0
const PLAQUE_INK := PANEL

static var _serif: SystemFont


## Georgia/Cambria, shared by the headings and the plaque lettering.
static func serif_font() -> SystemFont:
	if _serif == null:
		_serif = SystemFont.new()
		_serif.font_names = PackedStringArray(["Georgia", "Cambria"])
	return _serif


## True when the plaque art is present (otherwise the plaque variations fall back to flat buttons).
static func has_plaques() -> bool:
	return PaintedArt.texture(SLATE_PLAQUE_PATH) != null and PaintedArt.texture(BRASS_PLAQUE_PATH) != null


## A nine-slice box of `path` tinted by `tint`, or null when the art is missing.
static func plaque_box(path: String, tint := Color.WHITE, margin_x := 40.0, margin_y := 10.0) -> StyleBoxTexture:
	var tex := PaintedArt.texture(path)
	if tex == null:
		return null
	var box := StyleBoxTexture.new()
	box.texture = tex
	box.texture_margin_left = PLAQUE_SLICE_X
	box.texture_margin_right = PLAQUE_SLICE_X
	box.texture_margin_top = PLAQUE_SLICE_Y
	box.texture_margin_bottom = PLAQUE_SLICE_Y
	box.content_margin_left = margin_x
	box.content_margin_right = margin_x
	box.content_margin_top = margin_y
	box.content_margin_bottom = margin_y
	box.modulate_color = tint
	return box


## The engraved slate tablet behind the saved-run summary, or null when the art is missing.
static func tablet_box() -> StyleBoxTexture:
	return plaque_box(TABLET_PATH, Color.WHITE, 46.0, 14.0)


static func _plaque_states(theme: Theme, type_name: StringName, path: String, text: Color, font_size := PLAQUE_FONT_SIZE, margin_x := 40.0, margin_y := 10.0) -> void:
	var tints := {
		"normal": Color.WHITE, "hover": Color(1.16, 1.13, 1.06), "pressed": Color(0.78, 0.78, 0.8), "disabled": Color(0.5, 0.52, 0.56),
	}
	for state in tints:
		var box := plaque_box(path, tints[state], margin_x, margin_y)
		if state == "pressed":
			box.content_margin_top += 2.0
			box.content_margin_bottom -= 2.0
		theme.set_stylebox(state, String(type_name), box)
	theme.set_color("font_color", String(type_name), text)
	theme.set_color("font_hover_color", String(type_name), text.lightened(0.12))
	theme.set_color("font_focus_color", String(type_name), text)
	theme.set_color("font_pressed_color", String(type_name), text.darkened(0.1))
	theme.set_color("font_disabled_color", String(type_name), text.darkened(0.45))
	theme.set_font("font", String(type_name), serif_font())
	theme.set_font_size("font_size", String(type_name), font_size)
	theme.set_type_variation(String(type_name), "Button")
	theme.set_stylebox("focus", String(type_name), _focus_box())


## The keyboard-focus outline: an amber ring that traces the plaque's clipped silhouette (nine-sliced
## like the plaque and drawn just outside it), or a thin rounded line when the art is missing.
static func _focus_box() -> StyleBox:
	var ring := PaintedArt.texture(FOCUS_RING_PATH)
	if ring != null:
		var box := StyleBoxTexture.new()
		box.texture = ring
		box.texture_margin_left = PLAQUE_SLICE_X + FOCUS_PAD
		box.texture_margin_right = PLAQUE_SLICE_X + FOCUS_PAD
		box.texture_margin_top = PLAQUE_SLICE_Y + FOCUS_PAD
		box.texture_margin_bottom = PLAQUE_SLICE_Y + FOCUS_PAD
		box.expand_margin_left = FOCUS_PAD
		box.expand_margin_right = FOCUS_PAD
		box.expand_margin_top = FOCUS_PAD
		box.expand_margin_bottom = FOCUS_PAD
		return box
	var flat := StyleBoxFlat.new()
	flat.draw_center = false
	flat.border_color = AMBER
	flat.set_border_width_all(2)
	flat.set_corner_radius_all(8)
	return flat
