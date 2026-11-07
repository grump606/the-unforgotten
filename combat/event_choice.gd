class_name EventChoice
extends Resource
## One button of an event (docs/EVENTS_DESIGN.md): its label, what it does, the text shown after it is pressed and
## which classes see it. The cost and reward line printed under the label is generated from `effects`.

@export var label: String = ""
## Shown after the button is pressed.
@export var outcome: String = ""
## Empty: every class sees the button. Else only that character id does.
@export var only_for: StringName = &""
## Empty: no exception. Else the character id that does NOT see the button (its own variant takes its place).
@export var not_for: StringName = &""
## Character id -> replacement label or outcome text for that class (the numbers never change by class text).
@export var class_label: Dictionary = {}
@export var class_outcome: Dictionary = {}
@export var effects: Array[EventEffect] = []
## Flavour line added to the outcome when a gamble in `effects` is won or lost.
@export var win_outcome: String = ""
@export var lose_outcome: String = ""


## True if a player of `character_id` is shown this button.
func shown_to(character_id: StringName) -> bool:
	if only_for != &"" and only_for != character_id:
		return false
	return not_for == &"" or not_for != character_id


func label_for(character_id: StringName) -> String:
	return String(class_label.get(String(character_id), class_label.get(character_id, label)))


func outcome_for(character_id: StringName) -> String:
	return String(class_outcome.get(String(character_id), class_outcome.get(character_id, outcome)))


## The printed cost and reward line ("Lose 8 HP. Remember a card"), "" for a button that does nothing.
func summary() -> String:
	return EventEffect.describe_all(effects, "")


## Gold the choice asks for up front (the sum of its direct payments).
func gold_cost() -> int:
	var total := 0
	for effect in effects:
		total += effect.gold_cost()
	return total
