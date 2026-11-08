class_name Battle
extends Control
## Thin view over Combat: renders state and forwards button presses. All rules live in res://combat/.
## This script is the coordinator (attach, Combat signal handlers, fighter sync, turn flow); the pieces of the
## screen live in helper objects under res://run/battle/, each holding a reference back to this node:
## BattleHand (hand row, preview, play), BattleDrag (drag a card onto an enemy), BattleHud (pile buttons, turn
## controls, journey info), BattleOverlays (Glimpse / Recall pick, pile viewer), BattleFx (boss entrance, phase
## banner, flash, pile cues), BattleKeys (keyboard), BattleDamagePreview and BattleTooltips (display text).

const PLAYER_START_HP := 40
## Relic badges beside the HP line are drawn a little smaller than full size.
const BADGE_SCALE := 0.85

## Gap between enemies on the stage, and the share of the stage width the player stands in.
const ENEMY_GAP := 16.0
const PLAYER_X := 0.19
## The enemies stand in this band of the stage width (as fractions), centered as a group.
const ENEMY_BAND := Vector2(0.40, 0.98)
## Seconds between one enemy's attack and the next in the enemy phase.
const ENEMY_STAGGER := 0.4
## The boss HP bar: its horizontal span (fractions of the stage width) and the gap above it.
const BOSS_BAR_X := Vector2(0.35, 0.65)
const BOSS_BAR_TOP := 6.0

@onready var _backdrop: BattleBackdrop = %Backdrop
@onready var _stage: Control = %Stage
@onready var _left_box: VBoxContainer = %LeftBox
@onready var _pile_box: VBoxContainer = %PileBox
@onready var _hud_panel: PanelContainer = %Hud
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
## Show the ~2 s boss entrance before turn 1. Off by default when running headless so UI tests that drive a boss
## fight are not blocked; the intro tests turn it on.
var show_boss_intro := DisplayServer.get_name() != "headless"
var character_id: StringName = &""
var destination_key: StringName = &""
## The run's relics, shown as badges beside the player's HP (the strip hides when there are none).
var relics: Array[RelicData] = []

## The pieces of the screen (see the header); created in _ready.
var _hand: BattleHand
var _drag: BattleDrag
var _hud: BattleHud
var _overlays: BattleOverlays
var _fx: BattleFx
var _keys: BattleKeys
var _damage: BattleDamagePreview

var _combat: Combat
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
var _boss_bar: BossBar
## Enemy attacks seen in the current batch; each lunges a little after the previous one.
var _attacks_this_batch := 0
## The player's HP when the last enemy attack was handled, so each attack's share of the damage is known.
var _seen_player_hp := 0
## The player's Block at the same moment, so each attack's share absorbed by Block is known.
var _seen_player_block := 0

## The latest floating pile cue's text and how many have been shown (read by tests).
var last_cue_text: String:
	get:
		return _fx.last_cue_text
var cue_count: int:
	get:
		return _fx.cue_count


func _ready() -> void:
	# Embedded in the run screen the theme is inherited; run on its own (F6) it needs its own.
	if get_parent() == get_tree().root:
		MenuStyle.apply_theme_only(self)
	_hand = BattleHand.new(self, _hand_box)
	_drag = BattleDrag.new(self)
	_hud = BattleHud.new(self)
	_overlays = BattleOverlays.new(self)
	_fx = BattleFx.new(self)
	_keys = BattleKeys.new(self)
	_damage = BattleDamagePreview.new(self)
	_left_box.add_theme_constant_override("separation", 2)
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
	_hud.build()
	if external_combat != null:
		_new_fight_button.text = "Continue  [Enter]"
		_attach(external_combat)
	else:
		_new_fight_button.text = "New Fight  [N]"
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


## Stops listening to the current fight (a replaced one, or when this screen leaves the tree), so a Combat that
## outlives the screen holds no connection back to it.
func _detach() -> void:
	if _combat == null:
		return
	for pair in [[_combat.state_changed, _on_state_changed], [_combat.combat_ended, _on_combat_ended],
			[_combat.card_played, _on_card_played], [_combat.enemy_acted, _on_enemy_acted],
			[_combat.enemy_phase_changed, _on_enemy_phase_changed]]:
		var sig: Signal = pair[0]
		var handler: Callable = pair[1]
		if sig.is_connected(handler):
			sig.disconnect(handler)


func _exit_tree() -> void:
	_detach()


## Shows and starts `combat`, replacing any previous fight on this screen.
func _attach(combat: Combat) -> void:
	_detach()
	_combat = combat
	_combat.state_changed.connect(_on_state_changed)
	_combat.combat_ended.connect(_on_combat_ended)
	_combat.card_played.connect(_on_card_played)
	_combat.enemy_acted.connect(_on_enemy_acted)
	_combat.enemy_phase_changed.connect(_on_enemy_phase_changed)
	_target_index = 0
	_overlays.close_all()
	_result_label.text = ""
	_log_label.clear()
	_backdrop.set_harsh(false)
	if boss_fight:
		_log_label.append_text("[b]%s fight[/b]\n" % boss_label)
	_new_fight_button.hide()
	_begin_batch()
	_combat.start()
	_end_batch()
	if boss_fight and show_boss_intro:
		_fx.start_boss_intro()


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
			_seen_player_block = _combat.player.block
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
	_hud.sync_piles()
	_keep_target_alive()
	_sync_enemies()
	_hand.sync()
	_hud.sync_turn_controls()
	_overlays.sync_choice()
	_overlays.sync_pile_viewer()


## Removes a stale child immediately (not just queue_free) so it can no longer
## receive a click in the same frame, which would act on an outdated index.
func _discard_node(node: Node) -> void:
	node.get_parent().remove_child(node)
	node.queue_free()


# --- forwarders for the pieces other scripts and tests call -----------------------------------

## Opens the read-only viewer on a pile (see BattleOverlays). True when it opened.
func open_pile_viewer(which: PileViewer.Pile) -> bool:
	return _overlays.open_pile_viewer(which)


## True while the pile viewer is open (read by tests).
func pile_viewer_open() -> bool:
	return _overlays.pile_viewer_open()


## True while the Glimpse / Recall overlay is up (read by tests).
func choice_overlay_visible() -> bool:
	return _overlays.choice_visible()


## True while the inspection preview is on screen (read by tests).
func preview_visible() -> bool:
	return _hand.preview_visible()


## True while a card is being dragged (read by tests).
func is_dragging_card() -> bool:
	return _drag.is_dragging()


## True while the boss entrance overlay is up (read by tests).
func intro_visible() -> bool:
	return _fx.intro_visible()


## True while the phase banner is showing (read by tests).
func phase_banner_visible() -> bool:
	return _fx.phase_banner_visible()


## Journey info for a fight inside a run (see BattleHud.set_journey). Standalone fights never call this.
func set_journey(stop_title: String, journey: String, character_title: String, deck_size: int) -> void:
	_hud.set_journey(stop_title, journey, character_title, deck_size)


func _unhandled_key_input(event: InputEvent) -> void:
	_keys.handle(event)


# --- target and stage --------------------------------------------------------------------------

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
	_player_view.tooltip_text = "%s\n%s" % [player.display_name, BattleTooltips.status(player)]
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
			view.set_enemy(_combat.enemies[i], boss_fight)
			view.intent_target = _combat.player
			view.pressed.connect(_select_target.bind(i))
			_stage.add_child(view)
			_enemy_views.append(view)
		_sync_boss_bar()
		_layout_stage()
	if _boss_bar != null:
		_boss_bar.refresh()
	for i in _enemy_views.size():
		var enemy := _combat.enemies[i]
		var view := _enemy_views[i]
		view.set_targeted(i == _target_index and not enemy.is_dead())
		view.tooltip_text = "" if enemy.is_dead() else BattleTooltips.enemy(enemy, _combat.player)
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
	if _boss_bar != null:
		_boss_bar.position = Vector2(w * BOSS_BAR_X.x, BOSS_BAR_TOP)
		_boss_bar.size = Vector2(w * (BOSS_BAR_X.y - BOSS_BAR_X.x), BossBar.HEIGHT)
	for view in _enemy_views:
		view.fit_boss(h - BOSS_BAR_TOP - BossBar.HEIGHT - 6.0)
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


## Creates the wide boss HP bar on the stage for a boss fight (once per fight).
func _sync_boss_bar() -> void:
	if _boss_bar != null:
		_discard_node(_boss_bar)
		_boss_bar = null
	if not boss_fight or _combat.enemies.is_empty():
		return
	_boss_bar = BossBar.new()
	_boss_bar.setup(_combat.enemies[0], boss_label)
	_boss_bar.label_text = ("MID-BOSS" if boss_label == "Mid-boss" else "FINAL BOSS")
	_stage.add_child(_boss_bar)


func _select_target(index: int) -> void:
	if _combat == null or index < 0 or index >= _combat.enemies.size() or _combat.enemies[index].is_dead():
		return
	_target_index = index
	_refresh()


## Moves the selection to the next living enemy in `direction` (+1 or -1).
func _cycle_target(direction: int) -> void:
	var count := _combat.enemies.size()
	for step in range(1, count):
		var index := posmod(_target_index + direction * step, count)
		if not _combat.enemies[index].is_dead():
			_select_target(index)
			return


# --- turn flow ---------------------------------------------------------------------------------

func _on_end_turn_pressed() -> void:
	if _combat == null or _combat.phase == Combat.Phase.CHOOSING or _overlays.pile_viewer_open():
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
	if _combat == null or _combat.phase == Combat.Phase.CHOOSING or _overlays.pile_viewer_open():
		return
	_begin_batch()
	_combat.cancel_discard()
	_end_batch()


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
	else:
		var names: PackedStringArray = []
		for target in targets:
			names.append(target.display_name)
		_log_label.append_text("Played %s on %s\n" % [card.display_name, ", ".join(names)])
	for effect in card.effects:
		_announce_added_card(effect, true)


## Tells the player a card was added to their piles: a log line (cards) and a short floating cue by the
## pile counters ("+Dread draw pile"), so it is clear why a pile grew. Enemy intents already have their
## description in the log, so only the cue is added for them.
func _announce_added_card(effect: CardEffect, log_line: bool) -> void:
	if effect.kind != CardEffect.Kind.ADD_CARD or effect.card == null or effect.amount <= 0:
		return
	var where: String = ["your hand", "your draw pile", "your discard pile"][effect.pile]
	var text: String = "+%s%s" % ["%d " % effect.amount if effect.amount > 1 else "", effect.card.display_name]
	if log_line:
		_log_label.append_text("Added %s to %s\n" % [text.trim_prefix("+"), where])
	_fx.show_pile_cue("%s (%s)" % [text, where.trim_prefix("your ")])


func _on_enemy_acted(enemy: EnemyUnit, intent: CardEffect) -> void:
	_log_label.append_text("%s: %s\n" % [enemy.display_name, intent.describe()])
	_announce_added_card(intent, false)
	var index := _combat.enemies.find(enemy)
	if intent.is_damage() and index >= 0 and index < _enemy_views.size():
		var delay := _attacks_this_batch * ENEMY_STAGGER
		_enemy_views[index].play_attack(delay)
		_attacks_this_batch += 1
		# The player flinches when this attack's lunge peaks, not all at once at the end of the phase.
		if _player_view != null:
			_player_view.schedule_hit(maxi(_seen_player_hp - _combat.player.hp, 0), delay + Fighter.LUNGE_TIME * 0.5, maxi(_seen_player_block - _combat.player.block, 0))
	_seen_player_hp = _combat.player.hp
	_seen_player_block = _combat.player.block


## A boss (or any enemy with a phase two) enters its second phase: banner, flash, shake, harsher backdrop
## and an immediate redraw so the new phase's intent shows.
func _on_enemy_phase_changed(enemy: EnemyUnit, _new_phase: int) -> void:
	var title := enemy.data.phase_two_title if enemy.data.phase_two_title != "" else "Enraged"
	_log_label.append_text("[b]%s: %s[/b]\n" % [enemy.display_name, title])
	var index := _combat.enemies.find(enemy)
	if index >= 0 and index < _enemy_views.size():
		_enemy_views[index].shake()
	if boss_fight:
		_backdrop.set_harsh(true)
	_fx.show_phase_banner(title)
	_fx.flash_screen()
	_on_state_changed()
