class_name StoryScreen
extends RunScreen
## A story stop: the beat on a paper card over the destination window.


func show() -> void:
	var beat := run.current_beat()
	# The destination painting sits behind the panel.
	var story := StoryScene.new()
	story.beat_index = run.current_stop().beat_index
	add_backdrop(story)
	if beat == null:
		# Load failure is logged by the run; the stop must still be passable.
		var fallback := panel("Somewhere beyond the quiet streets, a voice still calls.")
		style_banner(fallback.get_child(0) as Label)
		add_button(fallback, "Continue", _read)
		return
	var box := panel(beat.title)
	var text := Label.new()
	text.text = beat.text
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(480, 0)
	box.add_child(text)
	add_button(box, beat.button_text, _read)
	# Dark ink on memento paper keeps the words readable over the art.
	var ink := Color(0.14, 0.10, 0.07)
	MenuStyle.heading(box.get_child(0) as Label, 22)
	box.get_child(0).add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
	for label in [box.get_child(0), text]:
		label.add_theme_color_override("font_color", ink)
	box.get_child(0).add_theme_font_size_override("font_size", 22)
	var card := PanelContainer.new()
	var paper := StyleBoxTexture.new()
	paper.texture = load("res://art/layers/ui/surface.png") as Texture2D
	paper.texture_margin_left = 16
	paper.texture_margin_top = 16
	paper.texture_margin_right = 16
	paper.texture_margin_bottom = 16
	paper.set_content_margin_all(22)
	card.add_theme_stylebox_override("panel", paper)
	var center := box.get_parent()
	center.remove_child(box)
	center.add_child(card)
	card.add_child(box)


func _read() -> void:
	run.read_story()
	refresh.call()
