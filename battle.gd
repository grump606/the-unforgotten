extends Control
## Thin view over Combat: renders state and forwards button presses. All rules
## live in res://combat/.

const PLAYER_START_HP := 40
## Keys 1-9 pick hand cards 1-9 and 0 picks the 10th.
const MAX_HAND_KEYS := 10
## Hand cards are drawn smaller than full size so a hand fits beside the enemy row and log.
const HAND_CARD_SCALE := 0.85
## A hand too wide for one row first shrinks its cards down to this scale, then overlaps them
## (the left edge with the cost stamp and hotkey stays visible; a hovered card comes to the front).
const HAND_CARD_SCALE_MIN := 0.72
## Gap between hand cards when they do not need to overlap.
const HAND_GAP := 4
## Used for the fit calculation before the hand box has been laid out (headless / first frame).
const HAND_WIDTH_FALLBACK := 820.0
## Most the cards may overlap, as a share of one card's width (with 10 cards this never binds at 1152 px).
const HAND_MAX_OVERLAP := 0.55
## Relic badges beside the HP line are drawn a little smaller than full size.
const BADGE_SCALE := 0.85

# Derived from the rules constants so the text cannot drift from them.
const EXPOSED_MULTIPLIER_TEXT := "%.1fx" % (float(Combatant.EXPOSED_NUM) / Combatant.EXPOSED_DEN)
const EXPOSED_TOOLTIP := "Takes " + EXPOSED_MULTIPLIER_TEXT + " damage, rounded down, for %d more turns."

## Gap between enemies on the stage, and the share of the stage width the player stands in.
const ENEMY_GAP := 16.0
const PLAYER_X := 0.19
## The enemies stand in this band of the stage width (as fractions), centered as a group.
const ENEMY_BAND := Vector2(0.40, 0.98)
## Seconds between one enemy's attack and the next in the enemy phase.
const ENEMY_STAGGER := 0.4

@onready var _backdrop: BattleBackdrop = %Backdrop
@onready var _stage: Control = %Stage
@onready var _left_box: VBoxContainer = %LeftBox
@onready var _pile_label: Label = %PileLabel
@onready var _hand_box: HFlowContainer = %HandBox
@onready var _end_turn_button: Button = %EndTurnButton
@onready var _result_label: Label = %ResultLabel
@onready var _log_panel: PanelContainer = %LogPanel
@onready var _log_label: RichTextLabel = %LogLabel
@onready var _log_button: Button = %LogButton
@onready var _new_fight_button: Button = %NewFightButton

## Emitted in embedded mode (see external_combat) when the player presses
## Continue after the fight ended.
signal fight_finished(victory: bool)

## Set before adding this scene to the tree to show a fight built by a run layer
## instead of a standalone random one. The screen then ends with a Continue
## button that emits fight_finished rather than starting a new fight.
var external_combat: Combat = null
## Standalone fights only, set before adding to the tree: a value >= 0 replays the same encounter and combat
## (the THE_UNFORGOTTEN_SEED environment variable does the same). -1 keeps the fight random.
var seed_override: int = -1
## Also set before adding to the tree: picks the backdrop look (the Conductor fight, the class tint).
var boss_fight := false
## Shown as the first log line of a boss fight ("Boss" or "Mid-boss"); both use the boss backdrop.
var boss_label := "Boss"
var character_id: StringName = &""
var destination_key: StringName = &""
## The run's relics, shown as badges beside the player's HP (the strip hides when there are none).
var relics: Array[RelicData] = []

var _combat: Combat
## "Back" button shown during the end-of-turn discard step (created in code).
var _cancel_button: Button
var _hint_shown := false
var _relic_strip: RelicStrip
var _victory := false
var _batch_depth := 0
var _refresh_pending := false
## Number of full refreshes so far (read by tests to check refreshes are coalesced).
var refresh_count := 0
## Index into Combat.enemies that cards will target.
var _target_index: int = 0
## One figure per enemy of the current fight, in Combat.enemies order, standing on the stage.
var _enemy_views: Array[Fighter] = []
var _player_view: Fighter
var _energy_orb: EnergyOrb
## Enemy attacks seen in the current batch; each lunges a little after the previous one.
var _attacks_this_batch := 0
## The player's HP when the last enemy attack was handled, so each attack's share of the damage is known.
var _seen_player_hp := 0


func _ready() -> void:
	# Embedded in the run screen the theme is inherited; run on its own (F6) it needs its own.
	if get_parent() == get_tree().root:
		MenuStyle.apply_theme_only(self)
	_end_turn_button.theme_type_variation = MenuStyle.PRIMARY
	_log_button.theme_type_variation = MenuStyle.QUIET
	_backdrop.set_variant(boss_fight, character_id, destination_key)
	_relic_strip = RelicStrip.create(relics, BADGE_SCALE)
	_relic_strip.position = Vector2(4, 4)
	_stage.add_child(_relic_strip)
	_energy_orb = EnergyOrb.new()
	_left_box.add_child(_energy_orb)
	_left_box.move_child(_energy_orb, 0)
	_stage.resized.connect(_layout_stage)
	_log_button.pressed.connect(_toggle_log)
	_log_button.focus_mode = Control.FOCUS_NONE
	_log_panel.hide()
	_end_turn_button.pressed.connect(_on_end_turn_pressed)
	_new_fight_button.pressed.connect(_on_continue_pressed)
	# Keys are handled in _unhandled_key_input; focusable buttons would let
	# Tab/Enter/Space move focus or re-press a button instead.
	_end_turn_button.focus_mode = Control.FOCUS_NONE
	_new_fight_button.focus_mode = Control.FOCUS_NONE
	_cancel_button = Button.new()
	_cancel_button.text = "Back"
	_cancel_button.theme_type_variation = MenuStyle.QUIET
	_cancel_button.tooltip_text = "Back to playing cards (Backspace)"
	_cancel_button.custom_minimum_size = Vector2(0, 36)
	_cancel_button.focus_mode = Control.FOCUS_NONE
	_cancel_button.visible = false
	_cancel_button.pressed.connect(_on_cancel_discard_pressed)
	_end_turn_button.get_parent().add_child(_cancel_button)
	_end_turn_button.get_parent().move_child(_cancel_button, _end_turn_button.get_index() + 1)
	if external_combat != null:
		_new_fight_button.text = "Continue"
		_attach(external_combat)
	else:
		_start_combat()


## Standalone mode (no external_combat): a random balance-test fight with the extended deck. Kept on
## purpose: the UI tests (ui_battle_test, ui_relic_view_test) and a bare F6 of battle.tscn rely on it.
## With a seed (seed_override, or THE_UNFORGOTTEN_SEED) the encounter and the combat replay exactly.
func _start_combat() -> void:
	var player := Combatant.new("Wanderer", PLAYER_START_HP)
	var encounter_rng := RandomNumberGenerator.new()
	var combat_seed: int
	var chosen_seed := _standalone_seed()
	if chosen_seed >= 0:
		# One seeded stream decides the enemy count, the encounter and the combat seed, in a fixed order.
		encounter_rng.seed = chosen_seed
		var seeded_count := encounter_rng.randi_range(1, Combat.MAX_ENEMIES)
		var seeded_enemies := StarterContent.varied_encounter(seeded_count, encounter_rng)
		combat_seed = encounter_rng.randi()
		# New Fight then plays the next seed rather than repeating this one.
		seed_override = chosen_seed + 1
		_start_with(player, seeded_enemies, combat_seed)
		return
	var enemy_count := randi_range(1, Combat.MAX_ENEMIES)
	encounter_rng.randomize()
	_start_with(player, StarterContent.varied_encounter(enemy_count, encounter_rng), randi())


## The seed for a standalone fight, or -1 for a random one: seed_override first, then the
## THE_UNFORGOTTEN_SEED environment variable (read only here, so runs never see it).
func _standalone_seed() -> int:
	if seed_override >= 0:
		return seed_override
	var text := OS.get_environment("THE_UNFORGOTTEN_SEED")
	return int(text) if text.is_valid_int() and int(text) >= 0 else -1


func _start_with(player: Combatant, enemies: Array[EnemyData], combat_seed: int) -> void:
	var combat := Combat.create(player, StarterContent.extended_deck(), enemies, combat_seed)
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
	if _batch_depth == 0:
		_attacks_this_batch = 0
		if _combat != null:
			_seen_player_hp = _combat.player.hp
	_batch_depth += 1


func _end_batch() -> void:
	_batch_depth -= 1
	if _batch_depth == 0 and _refresh_pending:
		_refresh()


func _refresh() -> void:
	_refresh_pending = false
	refresh_count += 1
	_sync_player()
	_energy_orb.set_energy(_combat.energy, Combat.ENERGY_PER_TURN)
	_pile_label.text = "Draw %d\nDiscard %d" % [_combat.piles.draw_pile.size(), _combat.piles.discard_pile.size()]
	_keep_target_alive()
	_sync_enemies()
	_rebuild_hand()
	_sync_turn_controls()


## End Turn / discard-step controls. In the discard step the main button confirms ("Keep all" when
## nothing is marked and at most Combat.HAND_SIZE cards are held, "Discard N" otherwise, or a disabled
## "Discard N more" while too many would stay) and Back returns to playing cards.
func _sync_turn_controls() -> void:
	var phase := _combat.phase
	var discarding := phase == Combat.Phase.DISCARDING
	_cancel_button.visible = discarding
	if discarding:
		var marked := _combat.discard_marks.size()
		var need := _combat.discard_required()
		_end_turn_button.disabled = need > 0
		if need > 0:
			_end_turn_button.text = "Discard %d more" % need
		elif marked == 0:
			_end_turn_button.text = "Keep all"
		else:
			_end_turn_button.text = "Discard %d" % marked
		var keep := _combat.piles.hand.size() - marked
		_result_label.text = "Choose cards to discard. You keep %d of up to %d." % [keep, Combat.HAND_SIZE]
		_hint_shown = true
		return
	_end_turn_button.text = "End Turn"
	_end_turn_button.disabled = phase != Combat.Phase.PLAYER_TURN
	if _hint_shown and phase != Combat.Phase.ENDED:
		_result_label.text = ""
	_hint_shown = false


## Moves the selection to the first living enemy if the current one is defeated.
func _keep_target_alive() -> void:
	if _combat.enemies[_target_index].is_dead():
		for i in _combat.enemies.size():
			if not _combat.enemies[i].is_dead():
				_target_index = i
				return


## Keeps the player's figure for the current fight (so its animations survive a refresh) and updates it.
func _sync_player() -> void:
	var player := _combat.player
	if _player_view == null or _player_view.unit != player:
		if _player_view != null:
			_discard_node(_player_view)
		_player_view = Fighter.new()
		_player_view.set_player(player, character_id)
		_stage.add_child(_player_view)
		_layout_stage()
	_player_view.tooltip_text = "%s\n%s" % [player.display_name, _status_tooltip(player)]
	_player_view.refresh()


## Keeps one Fighter per enemy of the current fight (so their animations survive a refresh) and
## updates each from its unit. A dead enemy fades out and cannot be clicked.
func _sync_enemies() -> void:
	var same := _enemy_views.size() == _combat.enemies.size()
	if same:
		for i in _enemy_views.size():
			same = same and _enemy_views[i].unit == _combat.enemies[i]
	if not same:
		for view in _enemy_views:
			_discard_node(view)
		_enemy_views.clear()
		for i in _combat.enemies.size():
			var view := Fighter.new()
			view.phase = i * 1.9
			view.set_enemy(_combat.enemies[i])
			view.pressed.connect(_select_target.bind(i))
			_stage.add_child(view)
			_enemy_views.append(view)
		_layout_stage()
	for i in _enemy_views.size():
		var enemy := _combat.enemies[i]
		var view := _enemy_views[i]
		view.set_targeted(i == _target_index and not enemy.is_dead())
		view.tooltip_text = "" if enemy.is_dead() else _enemy_tooltip(enemy)
		view.refresh()


## Stands the player on the left and the enemies in a group on the right, all on one ground line along
## the bottom of the stage (enemy 0 nearest the player).
func _layout_stage() -> void:
	var w := _stage.size.x
	var h := _stage.size.y
	if _player_view != null:
		_player_view.position = Vector2(w * PLAYER_X - _player_view.size.x / 2.0, h - _player_view.size.y)
	if _enemy_views.is_empty():
		return
	var total := ENEMY_GAP * (_enemy_views.size() - 1)
	for view in _enemy_views:
		total += view.size.x
	var band_center := w * (ENEMY_BAND.x + ENEMY_BAND.y) / 2.0
	var x := minf(band_center - total / 2.0, w - total - 8.0)
	for view in _enemy_views:
		view.position = Vector2(x, h - view.size.y)
		x += view.size.x + ENEMY_GAP
	_log_panel.position = Vector2(w - _log_panel.size.x, 0)


func _toggle_log() -> void:
	_log_panel.visible = not _log_panel.visible


## Tooltip of an enemy: what it will do next, then its statuses.
func _enemy_tooltip(enemy: EnemyUnit) -> String:
	var lines: Array[String] = [enemy.display_name]
	var intent := enemy.current_intent()
	if intent != null:
		lines.append("Next: " + intent.describe())
	var status := _status_tooltip(enemy)
	if status != "":
		lines.append(status)
	return "\n".join(lines)


func _rebuild_hand() -> void:
	for child in _hand_box.get_children():
		_discard_node(child)
	var discarding := _combat.phase == Combat.Phase.DISCARDING
	var hand_scale := _fit_hand()
	for i in _combat.piles.hand.size():
		var card := _combat.piles.hand[i]
		var view := CardView.new()
		view.view_scale = hand_scale
		view.auto_hover = true
		view.clickable = true
		view.set_card(card)
		view.hotkey = i + 1 if i < MAX_HAND_KEYS else 0
		view.preview = _damage_preview(card).strip_edges() if not discarding else ""
		if discarding:
			# Every card can be toggled; marked ones are dimmed and stamped.
			view.set_state(CardView.State.NORMAL)
			view.discard_marked = _combat.discard_marks.has(i)
		elif _combat.can_play(i):
			view.set_state(CardView.State.NORMAL)
		else:
			view.set_state(CardView.State.UNPLAYABLE, _unplayable_note(card))
		view.pressed.connect(_play_hand_card.bind(i))
		_hand_box.add_child(view)
	# The new views start un-hovered; once laid out, light the one under the pointer.
	_restore_hover.call_deferred()


## Sizes the hand row so every card fits on one line: normal scale and gap when it fits, then
## smaller cards, then overlap. Sets the box's horizontal separation and returns the card scale.
func _fit_hand() -> float:
	var count := _combat.piles.hand.size()
	var avail := _hand_box.size.x if _hand_box.size.x > 100.0 else HAND_WIDTH_FALLBACK
	var scale := HAND_CARD_SCALE
	var gap := float(HAND_GAP)
	if count > 1:
		var width := CardView.BASE.x * scale
		if count * width + (count - 1) * gap > avail:
			scale = clampf((avail - (count - 1) * gap) / (count * CardView.BASE.x), HAND_CARD_SCALE_MIN, HAND_CARD_SCALE)
			width = CardView.BASE.x * scale
			if count * width + (count - 1) * gap > avail:
				gap = maxf((avail - count * width) / (count - 1), -HAND_MAX_OVERLAP * width)
	_hand_box.add_theme_constant_override("h_separation", int(floorf(gap)))
	return scale


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
	if _combat.phase == Combat.Phase.DISCARDING:
		if _combat.toggle_discard(hand_index):
			RunScreen.sfx(&"card_select")
	elif not _combat.play_card(hand_index, _target_index) and _combat.phase == Combat.Phase.PLAYER_TURN and hand_index < _combat.piles.hand.size():
		RunScreen.sfx(&"unavailable")  # a card that cannot be played right now
	_end_batch()


func _status_tooltip(combatant: Combatant) -> String:
	var lines: Array[String] = []
	var exposed := combatant.status_turns(Combatant.Status.EXPOSED)
	if exposed > 0:
		lines.append(EXPOSED_TOOLTIP % exposed)
	var haunted := combatant.status_turns(Combatant.Status.HAUNTED)
	if haunted > 0:
		lines.append("Haunt %d: takes %d damage at the start of the enemy phase (ignoring Block), then Haunt falls by 1." % [haunted, haunted])
	if combatant.max_haunt > 0:
		lines.append("Haunt capped at %d." % combatant.max_haunt)
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


func _select_target(index: int) -> void:
	if _combat == null or index < 0 or index >= _combat.enemies.size() or _combat.enemies[index].is_dead():
		return
	_target_index = index
	_refresh()


func _on_end_turn_pressed() -> void:
	if _combat == null:
		return
	RunScreen.sfx(&"click")
	_begin_batch()
	match _combat.phase:
		Combat.Phase.PLAYER_TURN:
			# End Turn opens the discard step; with an empty hand there is nothing to choose.
			if _combat.piles.hand.is_empty():
				_combat.end_player_turn()
			else:
				_combat.begin_discard()
		Combat.Phase.DISCARDING:
			_combat.confirm_discard()
	_end_batch()


func _on_cancel_discard_pressed() -> void:
	if _combat == null:
		return
	_begin_batch()
	_combat.cancel_discard()
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
	if _combat == null or (_combat.phase != Combat.Phase.PLAYER_TURN and _combat.phase != Combat.Phase.DISCARDING):
		return
	var number := key.keycode - KEY_1
	if key.keycode == KEY_0:
		number = 9
	if number >= 0 and number < MAX_HAND_KEYS:
		get_viewport().set_input_as_handled()
		_play_hand_card(number)
		return
	if key.keycode == KEY_BACKSPACE:
		get_viewport().set_input_as_handled()
		_on_cancel_discard_pressed()
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
	RunScreen.sfx(&"card_play")
	if _player_view != null and not targets.is_empty() and card.effects.any(func(e: CardEffect) -> bool: return e.is_damage()):
		_player_view.play_attack()
		# The hit lands at the top of the lunge, not the moment the card is played.
		for target in targets:
			var at := _combat.enemies.find(target)
			if at >= 0 and at < _enemy_views.size():
				_enemy_views[at].react_delay = Fighter.LUNGE_TIME * 0.5
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
		var delay := _attacks_this_batch * ENEMY_STAGGER
		_enemy_views[index].play_attack(delay)
		_attacks_this_batch += 1
		# The player flinches when this attack's lunge peaks, not all at once at the end of the phase.
		if _player_view != null:
			_player_view.schedule_hit(maxi(_seen_player_hp - _combat.player.hp, 0), delay + Fighter.LUNGE_TIME * 0.5)
	_seen_player_hp = _combat.player.hp


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
