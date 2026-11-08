class_name BattleFx
extends RefCounted
## Presentation effects of the battle screen: the boss entrance, the phase banner and screen flash, and the
## floating "+Dread" cues by the pile counters. Each owns its overlay node and tween, created on first use.

## Seconds the phase banner stays up in total, and the boss entrance scale-in start.
const PHASE_BANNER_TIME := 1.8
const ENTRANCE_START_SCALE := 0.8
## The floating cue when cards are added to the player's piles: how long it takes and how far it rises.
const CUE_TIME := 1.4
const CUE_RISE := 46.0

## Boss entrance overlay (null outside a boss fight's intro).
var intro: BossIntro
var banner: Label
var flash: ColorRect
## The text of the latest pile cue (read by tests) and how many were shown.
var last_cue_text := ""
var cue_count := 0

var _battle: Battle
var _entrance_tween: Tween
var _banner_tween: Tween
var _flash_tween: Tween
## Floating cues showing now (they stack a little apart).
var _live_cues := 0


func _init(battle: Battle) -> void:
	_battle = battle


## True while the boss entrance overlay is up (read by tests).
func intro_visible() -> bool:
	return intro != null and is_instance_valid(intro) and not intro.is_done()


## Skips a running boss entrance; false when there is none.
func skip_intro() -> bool:
	if not intro_visible():
		return false
	intro.skip()
	return true


func start_boss_intro() -> void:
	var combat := _battle._combat
	if combat.enemies.is_empty():
		return
	var boss := combat.enemies[0]
	intro = BossIntro.new()
	intro.setup("MID-BOSS" if _battle.boss_label == "Mid-boss" else "FINAL BOSS", boss.display_name)
	intro.finished.connect(_on_intro_finished)
	_battle.add_child(intro)
	var views := _battle._enemy_views
	if not Motion.reduced and not views.is_empty():
		var view := views[0]
		view.entrance = ENTRANCE_START_SCALE
		_entrance_tween = _battle.create_tween()
		_entrance_tween.tween_property(view, "entrance", 1.0, BossIntro.DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _on_intro_finished() -> void:
	if _entrance_tween != null:
		_entrance_tween.kill()
	for view in _battle._enemy_views:
		view.entrance = 1.0
	intro = null


## True while the phase banner is showing (read by tests).
func phase_banner_visible() -> bool:
	return banner != null and banner.visible


func show_phase_banner(title: String) -> void:
	if banner == null:
		banner = Label.new()
		banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		banner.z_index = 40
		MenuStyle.heading(banner, 52)
		banner.add_theme_color_override("font_color", MenuStyle.DAMAGE)
		banner.add_theme_color_override("font_outline_color", Color(0.05, 0.0, 0.0, 0.9))
		banner.add_theme_constant_override("outline_size", 8)
		_battle.add_child(banner)
	banner.text = title.to_upper()
	banner.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	banner.offset_top = 120.0
	banner.offset_bottom = 200.0
	banner.modulate.a = 1.0
	banner.show()
	if _banner_tween != null:
		_banner_tween.kill()
	if not _battle.is_inside_tree():
		return
	var reduced := Motion.reduced
	_banner_tween = _battle.create_tween()
	if not reduced:
		banner.modulate.a = 0.0
		_banner_tween.tween_property(banner, "modulate:a", 1.0, 0.2)
	_banner_tween.tween_interval(PHASE_BANNER_TIME * (0.4 if reduced else 1.0) - 0.5)
	_banner_tween.tween_property(banner, "modulate:a", 0.0, 0.3)
	_banner_tween.tween_callback(banner.hide)


## A quick red flash over the whole screen (skipped under reduced motion).
func flash_screen() -> void:
	if Motion.reduced or not _battle.is_inside_tree():
		return
	if flash == null:
		flash = ColorRect.new()
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flash.z_index = 39
		_battle.add_child(flash)
		flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if _flash_tween != null:
		_flash_tween.kill()
	flash.color = Color(MenuStyle.DAMAGE, 0.45)
	_flash_tween = _battle.create_tween()
	_flash_tween.tween_property(flash, "color:a", 0.0, 0.5)


## A small label that rises from the pile counters and fades. Several at once are stacked a little apart.
func show_pile_cue(text: String) -> void:
	last_cue_text = text
	cue_count += 1
	if not _battle.is_inside_tree():
		return
	var cue := Label.new()
	cue.text = text
	cue.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cue.z_index = BattleOverlays.Z + 2
	cue.add_theme_font_size_override("font_size", 17)
	cue.add_theme_color_override("font_color", CardView.kind_color(CardEffect.Kind.ADD_CARD).lightened(0.2))
	cue.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	cue.add_theme_constant_override("outline_size", 5)
	_battle.add_child(cue)
	# Above the energy orb, over the stage, so it never sits on top of the counters it is about.
	var origin := _battle._energy_orb.get_global_rect().position - _battle.get_global_rect().position
	cue.position = Vector2(_battle._pile_box.get_global_rect().position.x - _battle.get_global_rect().position.x, origin.y - 30.0 - 22.0 * _live_cues)
	_live_cues += 1
	var tween := _battle.create_tween()
	tween.set_parallel(true)
	tween.tween_property(cue, "position:y", cue.position.y - CUE_RISE, CUE_TIME)
	tween.tween_property(cue, "modulate:a", 0.0, CUE_TIME).set_delay(CUE_TIME * 0.5)
	tween.chain().tween_callback(_end_pile_cue.bind(cue))


func _end_pile_cue(cue: Label) -> void:
	_live_cues = maxi(_live_cues - 1, 0)
	if is_instance_valid(cue):
		cue.queue_free()
