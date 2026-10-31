extends SceneTree
## Screenshots the battle screen over its backdrop: 1, 2 and 3 enemies for each class and the
## neutral look, the boss fight, and one fight a few seconds later to show the motion. Needs a
## rendering window (not --headless):
##   godot --path . -s res://tools/backdrop_sheet.gd -- <output dir>
## Default output is user://backdrop_sheets. The shots use the project's 1152x648 window.

const PACKS := {
	1: ["res://data/enemies/cinder_hound.tres"],
	2: ["res://data/enemies/pale_whisperer.tres", "res://data/enemies/mourning_crow.tres"],
	3: ["res://data/enemies/skittering_wisp.tres", "res://data/enemies/hollow_colossus.tres", "res://data/enemies/lost_shade.tres"],
	0: ["res://data/enemies/the_conductor.tres"],
}

var out_dir := "user://backdrop_sheets"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	for id in [&"", &"deserter", &"pickpocket", &"medium"]:
		for count in [1, 2, 3]:
			await _shot("%s_%d.png" % [id if id != &"" else &"neutral", count], PACKS[count], false, id, 2.0)
	await _shot("boss.png", PACKS[0], true, &"", 2.0)
	await _shot("boss_later.png", PACKS[0], true, &"", 5.3)
	await _shot("neutral_2_later.png", PACKS[2], false, &"", 5.3)
	quit()


func _shot(file: String, paths: Array, boss: bool, id: StringName, seconds: float) -> void:
	var datas: Array[EnemyData] = []
	for path in paths:
		datas.append(load(path) as EnemyData)
	var combat := Combat.create(Combatant.new("Wanderer", 40), StarterContent.extended_deck(), datas, 606)
	var scene: Control = load("res://battle.tscn").instantiate()
	scene.external_combat = combat
	scene.boss_fight = boss
	scene.character_id = id
	root.add_child(scene)
	for i in 3:
		await process_frame
	combat.enemies[0].gain_block(6)
	scene._select_target(0)
	var backdrop: BattleBackdrop = scene.find_children("*", "BattleBackdrop", true, false)[0]
	backdrop.time = 0.0 # real frames have run; start every shot from the same moment
	backdrop.advance(seconds)
	for view in scene.find_children("*", "Fighter", true, false):
		view.advance(1.1)
	for i in 3:
		await process_frame
	backdrop.time = seconds # the frames above added a little real time
	backdrop.advance(0.0)
	await process_frame
	var path := out_dir.path_join(file)
	root.get_texture().get_image().save_png(path)
	print("saved ", path)
	scene.queue_free()
	await process_frame
