extends SceneTree
## Screenshots the relic UI: every relic badge in each class palette, the twelve real relics next to a
## mock of their tooltip (the engine tooltip does not render into a screenshot), and, for each class,
## the vendor stop with a relic offer (plus a sold and a poor variant for the first class) and the
## battle screen with two relics. Needs a rendering window (not --headless):
##   godot --path . -s res://tools/relic_sheet.gd -- <output dir>
## Default output is user://relic_sheets. The run shots use the project's 1152x648 window.

const PALETTE_GROUPS := [[&"", "Neutral"], [&"deserter", "Deserter"], [&"thief", "Thief"], [&"medium", "Medium"]]
const VENDOR_STOP := 5
const COMBAT_STOP := -1
const GAP := 14

var out_dir := "user://relic_sheets"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	await _save_sheet(_palette_sheet(), "relics_palettes.png", Vector2i(1200, 640))
	await _save_sheet(_tooltip_sheet(), "relics_tooltips.png", Vector2i(1400, 700))
	var relics := StarterContent.all_relics()
	for id in [&"deserter", &"thief", &"medium"]:
		var owned: Array[RelicData] = []
		for relic in relics:
			if relic.character == id:
				owned.append(relic)
		var two: Array[RelicData] = [owned[0], owned[1]]
		var scene: Control = await _run_scene(id, two, VENDOR_STOP, 200)
		await _shot(scene, "vendor_%s.png" % id)
		if id == &"deserter":
			scene._buy_relic()
			await _shot(scene, "vendor_%s_sold.png" % id)
			scene.queue_free()
			await process_frame
			scene = await _run_scene(id, two, VENDOR_STOP, 3)
			await _shot(scene, "vendor_%s_poor.png" % id)
		scene.queue_free()
		await process_frame
		scene = await _run_scene(id, two, COMBAT_STOP, 0)
		await _shot(scene, "battle_%s.png" % id)
		scene.queue_free()
		await process_frame
	DirAccess.remove_absolute(out_dir.path_join("scratch_save.json"))
	quit()


func _label(text: String, size := 14, color := Color(0.85, 0.85, 0.9)) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


## All twelve glyphs in each palette at 2x, so shapes and contrast can be checked per class.
func _palette_sheet() -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	for group in PALETTE_GROUPS:
		column.add_child(_label(group[1], 18))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", GAP)
		for kind in RelicData.Kind.values():
			var cell := VBoxContainer.new()
			var relic := RelicData.make(&"sheet", "x", kind, 1, 1, group[0])
			var view := RelicView.new()
			view.view_scale = 2.0
			view.set_relic(relic)
			cell.add_child(view)
			var name := _label(RelicView.glyph_name(kind), 11)
			name.custom_minimum_size = Vector2(72, 0)
			cell.add_child(name)
			row.add_child(cell)
		column.add_child(row)
	return column


## The real relics, each beside a mock tooltip panel (name, effect, class) as the engine would show it.
func _tooltip_sheet() -> Control:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 14)
	for relic in StarterContent.all_relics():
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 8)
		var view := RelicView.new()
		view.view_scale = 1.5
		view.set_relic(relic)
		cell.add_child(view)
		var panel := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.1, 0.13, 0.96)
		style.set_border_width_all(1)
		style.border_color = Color(0.4, 0.4, 0.5)
		style.set_content_margin_all(6)
		panel.add_theme_stylebox_override("panel", style)
		panel.add_child(_label(RelicView.tooltip_for(relic), 13, Color(0.92, 0.92, 0.95)))
		cell.add_child(panel)
		grid.add_child(cell)
	return grid


func _save_sheet(content: Control, file: String, size: Vector2i) -> void:
	var viewport := SubViewport.new()
	viewport.size = size
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
	for i in 3:
		await process_frame
	var image := viewport.get_texture().get_image()
	var used := int(margin.get_combined_minimum_size().y) + 24
	image = image.get_region(Rect2i(0, 0, image.get_width(), mini(used, image.get_height())))
	image.save_png(out_dir.path_join(file))
	print("saved ", out_dir.path_join(file))
	viewport.queue_free()


## A run screen for `character` standing at `stop` with the given relics and gold.
func _run_scene(character: StringName, owned: Array[RelicData], stop: int, gold: int) -> Control:
	var scene: Control = load("res://run.tscn").instantiate()
	scene.save_path = out_dir.path_join("scratch_save.json") # never the real save
	root.add_child(scene)
	await process_frame
	scene._start_run(character)
	scene._run.stop_index = stop
	if stop < 0: # the first fight
		for i in scene._run.stops.size():
			if scene._run.stops[i].type == RunState.StopType.COMBAT:
				scene._run.stop_index = i
				break
	scene._run.gold = gold
	scene._run.relics = owned.duplicate()
	scene._run.player.hp = scene._run.player.max_hp - 10
	scene._show_stop()
	return scene


func _shot(_scene: Control, file: String) -> void:
	for i in 6:
		await process_frame
	var path := out_dir.path_join(file)
	root.get_texture().get_image().save_png(path)
	print("saved ", path)
