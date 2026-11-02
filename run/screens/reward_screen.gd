class_name RewardScreen
extends RunScreen
## The reward after a fight: pick a card, skip, or use the once-per-run Remove or Heal.

## True while the panel shows the pick-a-card-to-remove list.
var removing := false


## Forgets the remove picker (a new or resumed run starts on the card choices).
func reset() -> void:
	removing = false


func show() -> void:
	if removing:
		var picker := panel("Pick a card to remove from your deck.")
		add_remove_picker(picker, _remove_card, _cancel_removing)
		return
	var beat_mid_boss := run.current_stop().mid_boss
	var box := panel("The Bellkeeper falls. The way opens.\nChoose a keepsake for your deck, or skip." if beat_mid_boss else "A memory to carry onward.\nChoose a keepsake for your deck, or skip.")
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	for card in run.reward_choices():
		row.add_child(card_view(card, OFFER_CARD_SCALE, _take.bind(card)))
	add_button(box, "Skip (+%d gold)" % RunState.SKIP_GOLD, _take.bind(null))
	# Once-per-run alternatives: hidden once used (Heal also while at full HP).
	if run.can_reward_remove():
		add_button(box, "Remove a card (free, once)", start_removing)
	if run.can_reward_heal():
		add_button(box, "Heal %d HP (free, once)" % RunState.REWARD_HEAL, _heal)


func start_removing() -> void:
	removing = true
	refresh.call()


func _take(card: CardData) -> void:
	run.resolve_reward(card)
	refresh.call()


func _cancel_removing() -> void:
	removing = false
	refresh.call()


func _remove_card(deck_index: int) -> void:
	removing = false
	run.resolve_reward_remove(run.deck[deck_index])
	refresh.call()


func _heal() -> void:
	run.resolve_reward_heal()
	refresh.call()
