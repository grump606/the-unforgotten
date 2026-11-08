class_name CardTooltip
extends RefCounted
## The tooltip shown when hovering a card: a small, wrapped text block (Godot's default tooltip never wraps).

## Tooltip width and text size: a narrow block of small wrapped lines, not one line across the screen.
const WIDTH := 230.0
const FONT_SIZE := 13


static func make(for_text: String) -> Object:
	var label := RichTextLabel.new()
	label.bbcode_enabled = false
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(WIDTH, 0)
	label.add_theme_font_size_override("normal_font_size", FONT_SIZE)
	label.text = for_text
	return label
