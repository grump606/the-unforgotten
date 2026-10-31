extends Control
## Preview of the 2.5D pipeline: a layered enemy portrait and a tilting card, no game code needed.
##   godot --path . res://art/preview.tscn

const LAYERS := ["bg", "mid", "figure", "fg"]
const DEPTHS := [0.1, 0.4, 0.8, 1.6]


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.07, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var art := LayeredArt.new()
	art.position = Vector2(40, 40)
	art.size = Vector2(720, 240)
	add_child(art)
	var paths: Array = []
	for n in LAYERS:
		paths.append("res://art/layers/warden/%s.png" % n)
	art.set_layers(paths, DEPTHS)
	var card := ColorRect.new()
	card.color = Color(0.27, 0.29, 0.32)
	card.position = Vector2(820, 40)
	card.size = Vector2(240, 336)
	add_child(card)
	var label := Label.new()
	label.text = "BASH"
	label.position = Vector2(90, 150)
	card.add_child(label)
	CardTilt.attach(card)
