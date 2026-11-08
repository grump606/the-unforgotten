extends SceneTree
## Headless test that every animated class and scene honours Motion.reduced. Two parts: a behaviour check
## per animated class (advance it under reduced motion and see that nothing moves), and a source scan that
## fails when a script under run/ or battle.gd animates (a _process, a tween) without mentioning
## Motion.reduced, so a new animation cannot forget the setting. Run via scripts/check.ps1.

## Scripts that animate (or poll) without being presentation motion, and why they need no Motion check.
const EXEMPT := {
	"res://run.gd": "polls the background art loader; no motion",
	"res://run/update_installer.gd": "polls a download and shows a progress bar; no decorative motion",
}
const SCAN_DIRS := ["res://run", "res://run/battle", "res://run/screens"]

var fails := 0


func check(c: bool, msg: String) -> void:
	if not c:
		fails += 1
		printerr("FAIL: " + msg)
	else:
		print("ok: " + msg)


func _scan_sources() -> void:
	var files: Array[String] = ["res://battle.gd"]
	for dir_path in SCAN_DIRS:
		for f in DirAccess.get_files_at(dir_path):
			if f.ends_with(".gd"):
				files.append(dir_path + "/" + f)
	for path in files:
		var src := FileAccess.get_file_as_string(path)
		var animates := src.contains("func _process(") or src.contains("create_tween(") or src.contains(".tween_")
		if not animates:
			continue
		var honours := src.contains("Motion.reduced")
		check(honours or EXEMPT.has(path), "%s animates and mentions Motion.reduced (or is exempt)" % path)
	for path in EXEMPT:
		check(FileAccess.file_exists(path), "the exemption for %s is not stale" % path)


func _frozen_scene(node: Control, holder: Control, label: String) -> void:
	node.size = holder.size
	holder.add_child(node)
	var t0: float = node.time
	node.advance(2.0)
	check(node.time == t0, "%s holds still under reduced motion" % label)


func _initialize() -> void:
	_scan_sources()
	Motion.reduced = true
	var holder := Control.new()
	holder.size = Vector2(1120, 590)
	root.add_child(holder)
	await process_frame
	await process_frame

	# Scenes and backdrops driven by advance(delta).
	_frozen_scene(VendorScene.new(), holder, "the vendor scene")
	_frozen_scene(PauseScene.new(), holder, "the pause scene")
	_frozen_scene(BattleBackdrop.new(), holder, "the battle backdrop")
	_frozen_scene(MenuScene.new(), holder, "the menu scene")
	_frozen_scene(StoryScene.new(), holder, "the story scene")
	_frozen_scene(RestScene.new(), holder, "the rest scene")
	_frozen_scene(SelectScene.new(), holder, "the select scene")
	var ending := EndScene.new()
	_frozen_scene(ending, holder, "the end scene")
	check(ending.train_offset() > 500.0 and ending.lamp_level() == 0.0, "the end scene shows its settled state under reduced motion")
	var vendor := VendorScene.new()
	vendor.size = holder.size
	holder.add_child(vendor)
	vendor.set_gold(10)
	vendor.set_gold(30)
	check(vendor.pulse() == 0.0, "a gold change does not pulse the till under reduced motion")

	# The fighter: nothing swings, flashes or fades; damage numbers still appear, in place.
	var enemy := EnemyUnit.new(load("res://data/enemies/gate_warden.tres") as EnemyData)
	var f := Fighter.new()
	holder.add_child(f)
	f.set_enemy(enemy)
	var t0 := f.time
	var breath0 := f.breath()
	f.play_attack()
	f.shake()
	enemy.take_damage(5)
	f.refresh()
	enemy.gain_block(4)
	f.refresh()
	check(f._lunge == 0.0 and f._shake == 0.0 and f._flash == 0.0 and f._recoil == 0.0 and f._pop == 0.0, "no lunge, shake, flash, recoil or shield pop")
	check(f.float_count() == 1, "the damage number still appears")
	f.advance(0.5)
	check(f.time == t0 and f.breath() == breath0 and f.lunge_amount() == 0.0, "no breathing or weight shift")
	f.advance(Fighter.FLOAT_TIME + 0.1)
	check(f.float_count() == 0, "the damage number still expires")
	enemy.take_damage(1000)
	f.refresh()
	f.advance(0.01)
	check(f.fade == 1.0, "the defeat fade is instant")

	# The battle's pile cue.
	var scene: Control = (load("res://battle.tscn") as PackedScene).instantiate()
	scene.external_combat = Combat.create(Combatant.new("Wanderer", 40), StarterContent.extended_deck(),
		[load("res://data/enemies/gate_warden.tres") as EnemyData], 7)
	root.add_child(scene)
	await process_frame
	await process_frame
	scene._fx.show_pile_cue("+1 card")
	var cue: Label = null
	for child in scene.get_children():
		if child is Label and child.text == "+1 card":
			cue = child
	check(cue != null, "the pile cue appears")
	if cue != null:
		var y := cue.position.y
		await create_timer(0.3).timeout
		check(cue.position.y == y and cue.modulate.a == 1.0, "the pile cue neither rises nor fades under reduced motion")
	Motion.reduced = false
	quit(1 if fails > 0 else 0)
