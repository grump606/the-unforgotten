class_name EventData
extends Resource
## Static definition of an event stop (a "?" node, docs/EVENTS_DESIGN.md): a short scene and two to five buttons.
## All numbers live in the choices' effects, so tuning an event is a data edit.

@export var id: StringName
@export var title: String = ""
@export var body: String = ""
## Character id -> replacement scene text for that class.
@export var class_body: Dictionary = {}
@export var choices: Array[EventChoice] = []
## The painted screen drawn dimmed behind the event (a folder name under art/layers/screens).
@export var scene: StringName = &"battle_street"


func body_for(character_id: StringName) -> String:
	return String(class_body.get(String(character_id), class_body.get(character_id, body)))


## The choices a player of `character_id` sees, in order.
func choices_for(character_id: StringName) -> Array[EventChoice]:
	var shown: Array[EventChoice] = []
	for choice in choices:
		if choice.shown_to(character_id):
			shown.append(choice)
	return shown
