class_name TreasureScreen
extends RunScreen
## A treasure stop: a closed strongbox and one button, "Open the chest". Opening shows the relic inside (a
## RelicView badge with its name and effect) and "Take it", which adds it to the run and leaves the stop. If the
## character already owns every relic the chest holds gold instead and says so. What the chest holds is rolled by
## RunState.open_treasure, never here.

const BADGE_SCALE := 2.2
const PANEL_WIDTH := 360.0
const BOTTOM_GAP := 20.0


## Nothing is kept between redraws: the open state lives in the run.
func reset() -> void:
	pass


func show() -> void:
	var opened := run.treasure_opened()
	var scene := TreasureScene.new()
	scene.opened = opened
	add_backdrop(scene)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_bottom", int(BOTTOM_GAP))
	body.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var card := PanelContainer.new()
	card.name = "TreasureCard"
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.size_flags_vertical = Control.SIZE_SHRINK_END
	var style := StyleBoxFlat.new()
	style.bg_color = Color(MenuStyle.BG, 0.94)
	style.set_border_width_all(2)
	style.border_color = MenuStyle.BORDER
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", TactileArt.textured_style(style))
	margin.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	card.add_child(box)
	if not opened:
		_add_text(box, "A strongbox, shut for a long time. The lock has rusted through.", 15, MenuStyle.TEXT)
		var open := add_button(box, "Open the chest", _open_chest)
		open.name = "OpenButton"
		style_service(open)
		compact_plaque(open, 34.0, 14)
		return
	var relic := run.treasure_relic()
	if relic == null:
		_add_text(box, "The chest is empty of keepsakes. You already carry everything it could hold.", 15, MenuStyle.TEXT)
		var gold := make_label("%d gold" % run.treasure_gold())
		gold.name = "TreasureGold"
		gold.add_theme_font_size_override("font_size", 18)
		gold.add_theme_color_override("font_color", MenuStyle.AMBER)
		box.add_child(gold)
		var take_gold := add_button(box, "Take the gold", _take)
		take_gold.name = "TakeButton"
		style_service(take_gold)
		compact_plaque(take_gold, 34.0, 14)
		return
	var view := RelicView.new()
	view.name = "TreasureRelic"
	view.view_scale = BADGE_SCALE
	view.set_relic(relic)
	view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(view)
	var title := _add_text(box, relic.display_name, 18, Color("#D7D0BC"))
	title.name = "RelicName"
	var effect := _add_text(box, relic.description, 13, Color("#bcc5bd"))
	effect.name = "RelicText"
	var take := add_button(box, "Take it", _take)
	take.name = "TakeButton"
	style_service(take)
	compact_plaque(take, 34.0, 14)


static func _add_text(box: VBoxContainer, text: String, font_size: int, colour: Color) -> Label:
	var label := make_label(text)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	box.add_child(label)
	return label


func _open_chest() -> void:
	run.open_treasure()
	refresh.call()


func _take() -> void:
	run.take_treasure()
	sfx(&"reward")
	refresh.call()
