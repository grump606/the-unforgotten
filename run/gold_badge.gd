class_name GoldBadge
extends HBoxContainer
## A small gold coin with the player's gold total beside it (the vendor stall's HUD).

const COIN := Color(0.95, 0.76, 0.28)
const COIN_RIM := Color(0.55, 0.38, 0.12)

var _label: Label


func _init(amount := 0) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 8)
	var icon := Control.new()
	icon.custom_minimum_size = Vector2(30, 30)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.draw.connect(_draw_coin.bind(icon))
	add_child(icon)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 24)
	_label.add_theme_color_override("font_color", MenuStyle.TEXT)
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_label.add_theme_constant_override("shadow_offset_y", 2)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	set_amount(amount)


func set_amount(amount: int) -> void:
	_label.text = str(amount)


func _draw_coin(icon: Control) -> void:
	var c := icon.size * 0.5
	icon.draw_circle(c, 13.0, COIN_RIM)
	icon.draw_circle(c, 11.0, COIN)
	icon.draw_arc(c, 7.0, 0.0, TAU, 20, COIN_RIM, 1.5)
	icon.draw_circle(c - Vector2(3, 3), 2.5, Color(1, 1, 0.85, 0.6))
