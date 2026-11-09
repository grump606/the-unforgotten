extends SceneTree
## Headless test that every animated class and scene honours Motion.reduced. Two parts: a behaviour check
## per animated class (advance it under reduced motion and see that nothing moves), and a source scan that
## fails when a function under run/, art/fx/, audio/ or battle.gd starts a timer, a tween, an AnimationPlayer or a
## particle node, or is a per-frame callback, without mentioning Motion.reduced (or a `# motion-ok:` marker), so a new
## animation cannot forget the setting. Run via scripts/check.ps1.

const Scan := preload("res://tests/motion_scan_support.gd")

## Scripts that use a timer, a tween or a per-frame callback without it being visual motion, and why they need no
## Motion check at all (every function in them is skipped). A single function that needs no check is better marked
## in the source with `# motion-ok: <reason>`; see tests/motion_scan_support.gd.
const EXEMPT := {
	"res://run.gd": "_process only pumps the background art loader (PaintedArt.pump); no motion",
	"res://run/update_installer.gd": "_process polls the download and fills a progress bar; no decorative motion",
	"res://audio/audio_channel.gd": "tweens a volume (a crossfade), which is sound, not picture",
	"res://audio/audio_manager.gd": "_process steps the music scheduler and a volume duck tween; sound only",
}
const SCAN_DIRS := ["res://run", "res://run/battle", "res://run/screens", "res://art/fx", "res://audio"]

var fails := 0


func check(c: bool, msg: String) -> void:
	if not c:
		fails += 1
		printerr("FAIL: " + msg)
	else:
		print("ok: " + msg)


func _scan_sources() -> void:
	var files: Array[String] = ["res://battle.gd", "res://run.gd"]
	for dir_path in SCAN_DIRS:
		for f in DirAccess.get_files_at(dir_path):
			if f.ends_with(".gd"):
				files.append(dir_path + "/" + f)
	for path in files:
		var sites := Scan.sites(FileAccess.get_file_as_string(path))
		if sites.is_empty() or EXEMPT.has(path):
			continue
		var bad := Scan.unguarded(FileAccess.get_file_as_string(path))
		check(bad.is_empty(), "%s: every function that animates mentions Motion.reduced or carries a motion-ok marker (unguarded: %s)" % [path, ", ".join(bad)])
	for path in EXEMPT:
		var exists := FileAccess.file_exists(path)
		check(exists and not Scan.sites(FileAccess.get_file_as_string(path)).is_empty(),
			"the exemption for %s is not stale (the file exists and still animates or polls)" % path)
		check(String(EXEMPT[path]).length() > 10, "the exemption for %s states a reason" % path)
	_scan_samples()


## Proves the scan on small samples: what it flags and what it accepts.
func _scan_samples() -> void:
	var two_tweens := "func a() -> void:\n\tif Motion.reduced:\n\t\treturn\n\tcreate_tween()\n\nfunc b() -> void:\n\tcreate_tween()\n"
	check(Scan.unguarded(two_tweens) == ["b (line 6)"], "one function's Motion.reduced does not clear another function's tween")
	check(Scan.unguarded("func _process(delta: float) -> void:\n\tpass\n") == ["_process (line 1)"], "an unguarded _process is flagged")
	check(Scan.unguarded("func _process(delta: float) -> void:\n\tif Motion.reduced:\n\t\treturn\n").is_empty(), "a guarded _process passes")
	check(Scan.unguarded("func t() -> void:\n\t# Motion.reduced is not checked here\n\tcreate_timer(1.0)\n") == ["t (line 1)"], "a mention in a comment does not count")
	check(Scan.unguarded("func t() -> void:\n\tcreate_timer(1.0) # Motion.reduced later\n") == ["t (line 1)"], "a trailing comment does not count either")
	check(Scan.unguarded("func t() -> void:\n\t# motion-ok: polls a download, no motion\n\tcreate_timer(1.0)\n").is_empty(), "a motion-ok marker with a reason passes")
	check(Scan.unguarded("func t() -> void:\n\t# motion-ok: x\n\tcreate_timer(1.0)\n") == ["t (line 1)"], "a motion-ok marker without a real reason is flagged")
	check(Scan.unguarded("func p() -> void:\n\tvar a := AnimationPlayer.new()\n") == ["p (line 1)"], "an AnimationPlayer is flagged")
	check(Scan.unguarded("func p() -> void:\n\tvar a := GPUParticles2D.new()\n") == ["p (line 1)"], "GPUParticles are flagged")
	check(Scan.unguarded("func p() -> void:\n\tvar a := CPUParticles2D.new()\n") == ["p (line 1)"], "CPUParticles are flagged")
	check(Scan.unguarded("var _t: Tween\nfunc p() -> void:\n\tpass\n").is_empty(), "a Tween type annotation alone is not an animation")
	check(Scan.unguarded("func p() -> void:\n\tvar f := func() -> void:\n\t\tcreate_tween()\n") == ["p (line 1)"], "a tween in a lambda counts for its enclosing function")
	check(Scan.sites("func a() -> void:\n\tcreate_tween()\n\tcreate_tween()\n")[0].hits == 2, "the sites count every tween in a function")


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
