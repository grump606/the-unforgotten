class_name RestScreen
extends RunScreen
## A sheltered rest stop and one Rest button.


func show() -> void:
	var player := run.player
	var scene := RestScene.new()
	scene.character_id = run.character.id if run.character != null else &""
	add_backdrop(scene)
	var box := panel("A little warmth remains.\nHP %d/%d" % [player.hp, player.max_hp])
	style_banner(box.get_child(0) as Label)
	style_service(add_button(box, "Rest (+%d HP)" % RunState.REST_HEAL, _rest))


func _rest() -> void:
	run.rest()
	refresh.call()
