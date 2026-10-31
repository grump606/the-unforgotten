extends Control
## Thin view over Combat: renders state and forwards button presses. All rules
## live in res://combat/.

const PLAYER_START_HP := 40
const MAX_HAND_KEYS := 9
## Hand cards are drawn smaller than full size so a hand fits beside the enemy row and log.
const HAND_CARD_SCALE := 0.85
## Relic badges beside the HP line are drawn a little smaller than full size.
const BADGE_SCALE := 0.85

# Derived from the rules constants so the text cannot drift from them.
const EXPOSED_MULTIPLIER_TEXT := "%.1fx" % (float(Combatant.EXPOSED_NUM) / Combatant.EXPOSED_DEN)
const EXPOSED_TOOLTIP := "Takes " + EXPOSED_MULTIPLIER_TEXT + " damage, rounded down, for %d more turns."

@onready var _backdrop: BattleBackdrop = %Backdrop
@onready var _enemy_row: HBoxContainer = %EnemyRow
@onready var _player_row: HBoxContainer = %PlayerRow
@onready var _player_label: Label = %PlayerLabel
@onready var _energy_label: Label = %EnergyLabel
@onready var _pile_label: Label = %PileLabel
@onready var _hand_box: HFlowContainer = %HandBox
@onready var _end_turn_button: Button = %EndTurnButton
@onready var _result_label: Label = %ResultLabel
@onready var _log_label: RichTextLabel = %LogLabel
@onready var _new_fight_button: Button = %NewFightButton

## Emitted in embedded mode (see external_combat) when the player presses
## Continue after the fight ended.
signal fight_finished(victory: bool)

## Set before adding this scene to the tree to show a fight built by a run layer
## instead of a standalone random one. The screen then ends with a Continue
## button that emits fight_finished rather than starting a new fight.
var external_combat: Combat = null
## Also set before adding to the tree: picks the backdrop look (the Conductor fight, the class tint).
var boss_fight := false
## Shown as the first log line of a boss fight ("Boss" or "Mid-boss"); both use the boss backdrop.
var boss_label := "Boss"
var character_id: StringName = &""
## The run's relics, shown as badges beside the player's HP (the strip hides when there are none).
var relics: Array[RelicData] = []

var _combat: Combat
var _relic_strip: RelicStrip
var _victory := false
var _batch_depth := 0
var _refresh_pending := false
## Number of full refreshes so far (read by tests to check refreshes are coalesced).
var refresh_count := 0
## Index into Combat.enemies that cards will target.
var _target_index: int = 0
## One view per enemy of the current fight, in Combat.enemies order.
var _enemy_views: Array[EnemyView] = []


func _ready() -> void:
	_backdrop.set_variant(boss_fight, character_id)
	_relic_strip = RelicStrip.create(relics, BADGE_SCALE)
	_player_row.add_child(_relic_strip)
	_end_turn_button.pressed.connect(_on_end_turn_pressed)
	_new_fight_button.pressed.connect(_on_continue_pressed)
	# Keys are handled in _unhandled_key_input; focusable buttons would let
	# Tab/Enter/Space move focus or re-press a button instead.
	_end_turn_button.focus_mode = Control.FOCUS_NONE
	_new_fight_button.focus_mode = Control.FOCUS_NONE
	if external_combat != null:
		_new_fight_button.text = "Continue"
		_attach(external_combat)
	else:
		_start_combat()


## Standalone mode (no external_combat): a random balance-test fight with the extended deck. Kept on
## purpose: the UI tests (ui_battle_test, ui_relic_view_test) and a bare F6 of battle.tscn rely on it.
func _start_combat() -> void:
	var player := Combatant.new("Wanderer", PLAYER_START_HP)
	var enemy_count := randi_range(1, Combat.MAX_ENEMIES)
	var encounter_rng := RandomNumberGenerator.new()
	encounter_rng.randomize()
	var combat := Combat.create(player, StarterContent.extended_deck(), StarterContent.varied_encounter(enemy_count, encounter_rng), randi())
	if combat == null:
		_result_label.text = "Could not build this fight (content failed to load). See the Output log."
		_new_fight_button.show()
		return
	_attach(combat)


## Shows and starts `combat`, replacing any previous fight on this screen.
func _attach(combat: Combat) -> void:
	_combat = combat
	_combat.state_changed.connect(_on_state_changed)
	_combat.combat_ended.connect(_on_combat_ended)
	_combat.card_played.connect(_on_card_played)
	_combat.enemy_acted.connect(_on_enemy_acted)
	_target_index = 0
	_result_label.text = ""
	_log_label.clear()
	if boss_fight:
		_log_label.append_text("[b]%s fight[/b]\n" % boss_label)
	_new_fight_button.hide()
	_begin_batch()
	_combat.start()
	_end_batch()


## Combat emits state_changed on every mutation, so one action (a card play, the whole enemy
## phase) can emit dozens. Inside a batch the refresh is deferred and runs once when the batch
## ends; outside a batch (tests or code mutating state directly) it stays immediate.
func _on_state_changed() -> void:
	if _batch_depth > 0:
		_refresh_pending = true
	else:
		_refresh()


func _begin_batch() -> void:
	_batch_depth += 1


func _end_batch() -> void:
	_batch_depth -= 1
	if _batch_depth == 0 and _refresh_pending:
		_refresh()


func _refresh() -> void:
	_refresh_pending = false
	refresh_count += 1
	var player := _combat.player
	_player_label.text = "%s  HP %d/%d  Block %d%s" % [player.display_name, player.hp, player.max_hp, player.block, _status_text(player)]
	_player_label.tooltip_text = _status_tooltip(player)
	_energy_label.text = "Energy %d/%d" % [_combat.energy, Combat.ENERGY_PER_TURN]
	_pile_label.text = "Draw %d | Discard %d" % [_combat.piles.draw_pile.size(), _combat.piles.discard_pile.size()]
	_keep_target_alive()
	_sync_enemies()
	_rebuild_hand()
	_end_turn_button.disabled = _combat.phase != Combat.Phase.PLAYER_TURN


## Moves the selection to the first living enemy if the current one is defeated.
func _keep_target_alive() -> void:
	if _combat.enemies[_target_index].is_dead():
		for i in _combat.enemies.size():
			if not _combat.enemies[i].is_dead():
				_target_index = i
				return


## Keeps one EnemyView per enemy of the current fight (so their animations survive a refresh) and
## updates each from its unit. The row centers them; a dead enemy shows as defeated and cannot be clicked.
func _sync_enemies() -> void:
	var same := _enemy_views.size() == _combat.enemies.size()
	if same:
		for i in _enemy_views.size():
			same = same and _enemy_views[i].unit == _combat.enemies[i]
	if not same:
		for child in _enemy_row.get_children():
			_discard_node(child)
		_enemy_views.clear()
		for i in _combat.enemies.size():
			var view := EnemyView.new()
			view.phase = i * 1.9
			view.set_enemy(_combat.enemies[i])
			view.pressed.connect(_select_target.bind(i))
			_enemy_row.add_child(view)
			_enemy_views.append(view)
	for i in _enemy_views.size():
		var enemy := _combat.enemies[i]
		var view := _enemy_views[i]
		view.set_targeted(i == _target_index and not enemy.is_dead())
		view.tooltip_text = "" if enemy.is_dead() else _status_tooltip(enemy)
		view.refresh()


func _rebuild_hand() -> void:
	for child in _hand_box.get_children():
		_discard_node(child)
	for i in _combat.piles.hand.size():
		var card := _combat.piles.hand[i]
		var view := CardView.new()
		view.view_scale = HAND_CARD_SCALE
		view.auto_hover = true
		view.clickable = true
		view.set_card(card)
		view.hotkey = i + 1 if i < MAX_HAND_KEYS else 0
		view.preview = _damage_preview(card).strip_edges()
		if _combat.can_play(i):
			view.set_state(CardView.State.NORMAL)
		else:
			view.set_state(CardView.State.UNPLAYABLE, _unplayable_note(card))
		view.pressed.connect(_play_hand_card.bind(i))
		_hand_box.add_child(view)
	# The new views start un-hovered; once laid out, light the one under the pointer.
	_restore_hover.call_deferred()


## Why a hand card cannot be played right now, as a short warning for the card ("" when the
## fight is not on the player's turn, where nothing is playable and no card needs a warning).
func _unplayable_note(card: CardData) -> String:
	if _combat.phase != Combat.Phase.PLAYER_TURN:
		return ""
	if card.cost > _combat.energy:
		return "NEED %d ENERGY" % card.cost
	if card.hp_cost() >= _combat.player.hp:
		return "TOO LOW HP"
	return "PLAY LIMIT"


## Removes a stale child immediately (not just queue_free) so it can no longer
## receive a click in the same frame, which would act on an outdated index.
func _discard_node(node: Node) -> void:
	node.get_parent().remove_child(node)
	node.queue_free()


func _play_hand_card(hand_index: int) -> void:
	if _combat == null:
		return
	_begin_batch()
	_combat.play_card(hand_index, _target_index)
	_end_batch()


func _status_tooltip(combatant: Combatant) -> String:
	var lines: Array[String] = []
	var exposed := combatant.status_turns(Combatant.Status.EXPOSED)
	if exposed > 0:
		lines.append(EXPOSED_TOOLTIP % exposed)
	var haunted := combatant.status_turns(Combatant.Status.HAUNTED)
	if haunted > 0:
		lines.append("Haunt %d: takes %d damage at the start of the enemy phase (ignoring Block), then Haunt falls by 1." % [haunted, haunted])
	if combatant.hold > 0:
		lines.append("Hold %d: up to %d of the Block you have left is kept for your next turn." % [combatant.hold, combatant.hold])
	if combatant.thorns > 0:
		lines.append("Thorns %d: each enemy attack on you also deals %d to the attacker this turn." % [combatant.thorns, combatant.thorns])
	return "\n".join(lines)


## DISPLAY-ONLY preview of damage on the selected enemy: Exposed scaling comes
## from Combatant.damage_after_status, then block is subtracted per hit as
## take_damage does. The result of an actual play is authoritative.
func _damage_preview(card: CardData) -> String:
	var damage_effects: Array[CardEffect] = []
	for effect in card.effects:
		if effect.is_damage():
			damage_effects.append(effect)
	if damage_effects.is_empty():
		return ""
	var block: int = _combat.player.block
	# The card being played will count as one more play this turn.
	var plays: int = _combat.plays_this_turn + 1
	if card.target_mode == CardData.TargetMode.ALL_ENEMIES:
		# Haunt differs per enemy, so a per-Haunt hit has no single number.
		var all_base := 0
		for effect in damage_effects:
			if effect.kind == CardEffect.Kind.DAMAGE_PER_HAUNT:
				return ""
			all_base += effect.raw_damage(block, 0, plays)
		return "\nDeals %d (x%d enemies)" % [all_base, _combat.living_enemies().size()]
	var target := _combat.enemies[_target_index]
	if card.target_mode != CardData.TargetMode.SINGLE_ENEMY or target.is_dead():
		return ""
	var base := 0
	var hits: Array[int] = []
	for effect in damage_effects:
		var raw := effect.raw_damage(block, target.status_turns(Combatant.Status.HAUNTED), plays)
		base += raw
		hits.append(raw)
	var exposed := target.status_turns(Combatant.Status.EXPOSED) > 0
	var target_block := target.block
	var dealt := 0
	var lost := 0
	for hit in hits:
		var amount := target.damage_after_status(hit)
		var absorbed := mini(target_block, amount)
		target_block -= absorbed
		dealt += amount
		lost += amount - absorbed
	var text := "\nDeals %d" % dealt
	if exposed:
		text = "\nDeals %d (%d vs Exposed)" % [base, dealt]
	if target.block > 0:
		text += ", %d after Block" % lost
	return text


func _status_text(combatant: Combatant) -> String:
	var text := ""
	var exposed := combatant.status_turns(Combatant.Status.EXPOSED)
	if exposed > 0:
		text += "  Exposed %d" % exposed
	var haunted := combatant.status_turns(Combatant.Status.HAUNTED)
	if haunted > 0:
		text += "  Haunt %d" % haunted
	if combatant.hold > 0:
		text += "  Hold %d" % combatant.hold
	if combatant.thorns > 0:
		text += "  Thorns %d" % combatant.thorns
	return text


func _select_target(index: int) -> void:
	if _combat == null or index < 0 or index >= _combat.enemies.size() or _combat.enemies[index].is_dead():
		return
	_target_index = index
	_refresh()


func _on_end_turn_pressed() -> void:
	if _combat == null:
		return
	_begin_batch()
	_combat.end_player_turn()
	_end_batch()


## Moves the selection to the next living enemy in `direction` (+1 or -1).
func _cycle_target(direction: int) -> void:
	var count := _combat.enemies.size()
	for step in range(1, count):
		var index := posmod(_target_index + direction * step, count)
		if not _combat.enemies[index].is_dead():
			_select_target(index)
			return


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or key.ctrl_pressed or key.alt_pressed or key.meta_pressed:
		return
	if _new_fight_button.visible:
		if key.keycode == KEY_N:
			get_viewport().set_input_as_handled()
			_on_continue_pressed()
		return
	# Same gate as the buttons: nothing happens outside the player's turn.
	if _combat == null or _combat.phase != Combat.Phase.PLAYER_TURN:
		return
	var number := key.keycode - KEY_1
	if number >= 0 and number < MAX_HAND_KEYS:
		get_viewport().set_input_as_handled()
		_play_hand_card(number)
		return
	match key.keycode:
		KEY_E, KEY_ENTER, KEY_KP_ENTER:
			get_viewport().set_input_as_handled()
			_on_end_turn_pressed()
		KEY_RIGHT:
			get_viewport().set_input_as_handled()
			_cycle_target(1)
		KEY_LEFT:
			get_viewport().set_input_as_handled()
			_cycle_target(-1)
		KEY_TAB:
			get_viewport().set_input_as_handled()
			_cycle_target(-1 if key.shift_pressed else 1)


func _on_continue_pressed() -> void:
	if external_combat != null:
		fight_finished.emit(_victory)
	else:
		_start_combat()


func _on_combat_ended(victory: bool) -> void:
	_victory = victory
	_result_label.text = "You slip through the gate." if victory else "You are claimed by the afterlife."
	_log_label.append_text("[b]%s[/b]\n" % ("Victory" if victory else "Defeat"))
	_new_fight_button.show()


func _on_card_played(card: CardData, targets: Array[EnemyUnit]) -> void:
	if targets.is_empty():
		_log_label.append_text("Played %s\n" % card.display_name)
		return
	var names: PackedStringArray = []
	for target in targets:
		names.append(target.display_name)
	_log_label.append_text("Played %s on %s\n" % [card.display_name, ", ".join(names)])


func _on_enemy_acted(enemy: EnemyUnit, intent: CardEffect) -> void:
	_log_label.append_text("%s: %s\n" % [enemy.display_name, intent.describe()])
	var index := _combat.enemies.find(enemy)
	if intent.is_damage() and index >= 0 and index < _enemy_views.size():
		_enemy_views[index].play_attack()


## Re-applies the hover look to the hand card under the pointer after a rebuild (the new views
## get no mouse_entered until the mouse moves). Every other card is cleared, so none sticks.
func _restore_hover(mouse := Vector2(-1.0, -1.0)) -> void:
	if not is_inside_tree():
		return
	if mouse == Vector2(-1.0, -1.0):
		mouse = get_viewport().get_mouse_position()
	var found := false
	for child in _hand_box.get_children():
		var view := child as CardView
		if view == null:
			continue
		var over := not found and view.get_global_rect().has_point(mouse)
		found = found or over
		view.set_hovered(over)
