class_name RewardScreen
extends RunScreen
## The reward after a fight: pick a card, skip, or use the once-per-run Remove or Heal.

const ELITE_BADGE_SCALE := 2.2
const ELITE_PANEL_WIDTH := 360.0

## True while the panel shows the pick-a-card-to-remove list.
var removing := false


## Forgets the remove picker (a new or resumed run starts on the card choices).
func reset() -> void:
	removing = false


func show() -> void:
	# Keep the destination visible after combat; this screen does not advance the route.
	var backdrop := BattleBackdrop.new()
	var stop := run.current_stop()
	backdrop.set_variant(stop.boss or stop.mid_boss, run.character.id, run.battle_backdrop())
	add_backdrop(backdrop)
	if run.elite_spoils_pending() and not removing:
		_show_spoils()
		return
	if removing:
		var picker := panel("Pick a card to remove from your deck.", true)
		add_remove_picker(picker, _remove_card, _cancel_removing)
		return
	var beat_mid_boss := run.current_stop().mid_boss
	var heal_note := "\nYou recover %d HP." % run.map_win_heal if run.map_win_heal > 0 else ""
	var box := panel(("The Bellkeeper falls. The way opens.\nChoose a keepsake for your deck, or skip." if beat_mid_boss else "A memory to carry onward.\nChoose a keepsake for your deck, or skip.") + heal_note, true)
	style_banner(box.get_child(0) as Label)
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


## The first half of an elite's reward: the relic (or the fallback gold) with "Take it", then the usual card choice.
func _show_spoils() -> void:
	var gold_line := "\n+%d gold" % run.elite_bonus_gold if run.elite_bonus_gold > 0 else ""
	var box := panel("Elite spoils" + gold_line, true)
	box.name = "EliteSpoils"
	style_banner(box.get_child(0) as Label)
	var relic := run.elite_relic()
	if relic == null:
		var note := make_label("You already carry every keepsake it could have held.")
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.custom_minimum_size = Vector2(ELITE_PANEL_WIDTH, 0)
		box.add_child(note)
		var gold := make_label("%d gold" % run.elite_spoils_gold())
		gold.name = "SpoilsGold"
		gold.add_theme_font_size_override("font_size", 18)
		gold.add_theme_color_override("font_color", MenuStyle.AMBER)
		box.add_child(gold)
		add_button(box, "Take the gold", _take_spoils).name = "TakeSpoilsButton"
		return
	var view := RelicView.new()
	view.name = "SpoilsRelic"
	view.view_scale = ELITE_BADGE_SCALE
	view.set_relic(relic)
	view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(view)
	var title := make_label(relic.display_name)
	title.name = "RelicName"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color("#D7D0BC"))
	box.add_child(title)
	var effect := make_label(relic.description)
	effect.name = "RelicText"
	effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect.custom_minimum_size = Vector2(ELITE_PANEL_WIDTH, 0)
	effect.add_theme_font_size_override("font_size", 13)
	effect.add_theme_color_override("font_color", Color("#bcc5bd"))
	box.add_child(effect)
	add_button(box, "Take it", _take_spoils).name = "TakeSpoilsButton"


func _take_spoils() -> void:
	sfx(&"reward")
	run.take_elite_spoils()
	refresh.call()


func start_removing() -> void:
	removing = true
	refresh.call()


func _take(card: CardData) -> void:
	if card != null:
		sfx(&"reward")
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
