class_name AudioSettingsPanel
extends RefCounted
## The sound page: Master, Music, Ambience and Effects sliders, a mute toggle and the audio credits.
## Built into a VBoxContainer by the main menu and the pause menu; the numbers live in AudioManager.

const SLIDER_WIDTH := 220.0
const ROWS := [
	["Master", "master"],
	["Music", "music"],
	["Ambience", "ambience"],
	["Effects", "sfx"],
]

## The sliders by key ("master", "music", "ambience", "sfx"), the mute toggle and the credits box
## (tests read these).
var sliders := {}
var mute_button: CheckButton
var credits_label: Label
var credits_scroll: ScrollContainer
var credits_button: Button


## Fills `box` with the sound page. `on_back` is called by the Back button.
func build(box: Container, on_back: Callable) -> void:
	var audio := _audio()
	var title := Label.new()
	title.text = "Sound"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	MenuStyle.heading(title, 36)
	box.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 10)
	box.add_child(grid)
	for row in ROWS:
		var key: String = row[1]
		var name_label := Label.new()
		name_label.text = row[0]
		grid.add_child(name_label)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.01
		slider.value = _level(audio, key)
		slider.custom_minimum_size = Vector2(SLIDER_WIDTH, 24)
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slider.name = "%sSlider" % row[0]
		_style_slider(slider)
		grid.add_child(slider)
		var percent := Label.new()
		percent.custom_minimum_size.x = 48
		percent.text = _percent(slider.value)
		grid.add_child(percent)
		slider.value_changed.connect(_on_slider.bind(key, percent))
		slider.drag_ended.connect(_on_drag_ended)
		sliders[key] = slider
	mute_button = CheckButton.new()
	mute_button.text = "Mute all sound"
	mute_button.button_pressed = audio != null and audio.prefs.muted
	mute_button.toggled.connect(_on_mute)
	mute_button.focus_mode = Control.FOCUS_NONE
	box.add_child(mute_button)
	credits_button = Button.new()
	credits_button.text = "Audio credits"
	credits_button.theme_type_variation = MenuStyle.PLAQUE_SMALL
	credits_button.pressed.connect(_toggle_credits)
	box.add_child(credits_button)
	credits_scroll = ScrollContainer.new()
	credits_scroll.custom_minimum_size = Vector2(560, 180)
	credits_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	credits_scroll.visible = false
	credits_label = Label.new()
	credits_label.text = audio.credits_text() if audio != null else ""
	credits_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	credits_label.custom_minimum_size.x = 540
	credits_label.add_theme_font_size_override("font_size", 13)
	credits_scroll.add_child(credits_label)
	box.add_child(credits_scroll)
	RunScreen.add_button(box, "Back", func() -> void:
		_save()
		on_back.call())


static func _audio() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("AudioManager") if tree != null else null


static func _level(audio: Node, key: String) -> float:
	if audio == null:
		return 1.0
	return float(audio.prefs.get(key))


static func _percent(value: float) -> String:
	return "%d%%" % roundi(value * 100.0)


func _on_slider(value: float, key: String, percent: Label) -> void:
	percent.text = _percent(value)
	var audio := _audio()
	if audio != null:
		audio.call("set_" + key, value)


func _on_drag_ended(_changed: bool) -> void:
	_save()


func _on_mute(on: bool) -> void:
	var audio := _audio()
	if audio != null:
		audio.set_muted(on)


func _toggle_credits() -> void:
	credits_scroll.visible = not credits_scroll.visible
	credits_button.text = "Hide credits" if credits_scroll.visible else "Audio credits"


static func _save() -> void:
	var audio := _audio()
	if audio != null:
		audio.save_now()


## Dark track, brass-edged knob: the same colours as the buttons around it.
static func _style_slider(slider: HSlider) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color("#101720")
	track.border_color = Color("#526979")
	track.set_border_width_all(1)
	track.set_corner_radius_all(3)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	slider.add_theme_stylebox_override("slider", track)
	var filled := StyleBoxFlat.new()
	filled.bg_color = Color("#78a99b")
	filled.set_corner_radius_all(3)
	slider.add_theme_stylebox_override("grabber_area", filled)
	slider.add_theme_stylebox_override("grabber_area_highlight", filled)
	var knob := _knob(Color("#d7d0bc"))
	var knob_hot := _knob(Color("#e8b773"))
	slider.add_theme_icon_override("grabber", knob)
	slider.add_theme_icon_override("grabber_highlight", knob_hot)
	slider.add_theme_icon_override("grabber_disabled", knob)


static func _knob(color: Color) -> Texture2D:
	var size := 16
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var centre := (size - 1) / 2.0
	for y in size:
		for x in size:
			var d := Vector2(x, y).distance_to(Vector2(centre, centre))
			if d <= 7.5:
				image.set_pixel(x, y, Color("#171d28") if d > 5.5 else color)
	return ImageTexture.create_from_image(image)
