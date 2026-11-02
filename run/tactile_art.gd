class_name TactileArt
extends RefCounted
static var _orb := {}

class PaintedStyle extends StyleBox:
	var backing: StyleBoxFlat
	var grain: Texture2D

	func _draw(canvas: RID, area: Rect2) -> void:
		backing.draw(canvas, area)
		var inset := area.grow(-3.0)
		if inset.has_area():
			RenderingServer.canvas_item_add_texture_rect(canvas, inset, grain.get_rid(), false, Color(1, 1, 1, 0.10))

static func surface() -> Texture2D:
	return PaintedArt._load("res://art/layers/ui/surface.png")

static func energy_orb() -> Dictionary:
	if not _orb.is_empty():
		return _orb
	var tex := PaintedArt._load("res://art/layers/ui/energy_orb.png")
	if tex != null:
		var image := tex.get_image()
		var used := image.get_used_rect()
		if used.has_area():
			_orb = {"tex": tex, "region": Rect2(used)}
	return _orb

static func draw_grain(item: CanvasItem, area: Rect2, opacity := 0.12) -> void:
	var tex := surface()
	if tex != null and area.has_area():
		item.draw_texture_rect(tex, area, false, Color(1, 1, 1, opacity))

static func textured_style(flat: StyleBoxFlat) -> StyleBox:
	var tex := surface()
	if tex == null:
		return flat
	var painted := PaintedStyle.new()
	painted.backing = flat
	painted.grain = tex
	painted.content_margin_left = flat.get_content_margin(SIDE_LEFT)
	painted.content_margin_top = flat.get_content_margin(SIDE_TOP)
	painted.content_margin_right = flat.get_content_margin(SIDE_RIGHT)
	painted.content_margin_bottom = flat.get_content_margin(SIDE_BOTTOM)
	return painted
