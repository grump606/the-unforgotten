extends SceneTree
## Lays out every card in data/cards as a CardView, grouped by class, plus a sheet of the
## card states, and saves PNGs. Needs a rendering window (not --headless):
##   godot --path . -s res://tools/card_sheet.gd -- <output dir> [scale]
## Default output is user://card_sheets; scale defaults to 1.

const GROUPS := [[&"", "Neutral"], [&"deserter", "Deserter"], [&"thief", "Thief"], [&"medium", "Medium"], [&"stray", "Stray"]]
const GAP := 10
const COLUMNS := 8
const STATE_ROWS := ["brace", "bash", "confess", "last_pocket"]

var out_dir := "user://card_sheets"
var scale := 1.0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	if args.size() > 1:
		scale = float(args[1])
	DirAccess.make_dir_recursive_absolute(out_dir)
	await _save_sheet(_all_cards_sheet(), "cards_all.png")
	await _save_sheet(_states_sheet(), "cards_states.png")
	quit()


func _load_cards() -> Array[CardData]:
	var cards: Array[CardData] = []
	for file in DirAccess.get_files_at("res://data/cards"):
		if file.ends_with(".tres"):
			cards.append(load("res://data/cards/" + file) as CardData)
	cards.sort_custom(func(a: CardData, b: CardData) -> bool: return a.display_name < b.display_name)
	return cards


func _label(text: String, size := 18) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	return label


func _all_cards_sheet() -> Control:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	var cards := _load_cards()
	for group in GROUPS:
		root.add_child(_label(group[1]))
		var grid := GridContainer.new()
		grid.columns = COLUMNS
		grid.add_theme_constant_override("h_separation", GAP)
		grid.add_theme_constant_override("v_separation", GAP)
		for c in cards:
			if c.character == group[0]:
				grid.add_child(_view(c, CardView.State.NORMAL))
		root.add_child(grid)
	return root


func _view(c: CardData, state: CardView.State, note := "") -> CardView:
	var view := CardView.new()
	view.view_scale = scale
	view.set_card(c)
	view.set_state(state, note)
	return view


func _states_sheet() -> Control:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	var heads := HBoxContainer.new()
	heads.add_theme_constant_override("separation", GAP)
	for name in ["Normal", "Hover", "Selected", "Unplayable", "Unplayable + note"]:
		var label := _label(name, 14)
		label.custom_minimum_size = Vector2(CardView.BASE.x * scale, 0)
		heads.add_child(label)
	root.add_child(heads)
	for id in STATE_ROWS:
		var c: CardData = load("res://data/cards/%s.tres" % id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", GAP)
		row.add_child(_view(c, CardView.State.NORMAL))
		row.add_child(_view(c, CardView.State.HOVER))
		row.add_child(_view(c, CardView.State.SELECTED))
		row.add_child(_view(c, CardView.State.UNPLAYABLE))
		row.add_child(_view(c, CardView.State.UNPLAYABLE, "NEED 2 ENERGY" if c.hp_cost() == 0 else "TOO LOW HP"))
		root.add_child(row)
	return root


func _save_sheet(content: Control, file: String) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(int(1180 * scale), int(1700 * scale))
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var bg := ColorRect.new()
	bg.color = CardView.BACKDROP
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(bg)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_child(content)
	viewport.add_child(margin)
	root.add_child(viewport)
	await process_frame
	await process_frame
	await process_frame
	var image := viewport.get_texture().get_image()
	# Trim the empty bottom so the PNG fits its content.
	var used := int(margin.get_combined_minimum_size().y) + 24
	image = image.get_region(Rect2i(0, 0, image.get_width(), mini(used, image.get_height())))
	image.save_png(out_dir.path_join(file))
	print("saved ", out_dir.path_join(file))
	viewport.queue_free()
