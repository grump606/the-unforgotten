extends SceneTree
## Measures what the painted art costs: time to load every picture, and the CPU/GPU render time of a
## three-enemy battle with the painted backdrop (needs a window, not --headless):
##   godot --path . -s res://art/tools/perf.gd

func _initialize() -> void:
	var t := Time.get_ticks_msec()
	var cards := 0
	for f in DirAccess.get_directories_at("res://art/layers/cards"):
		PaintedArt.card_texture(StringName(f))
		cards += 1
	var t_cards := Time.get_ticks_msec() - t
	t = Time.get_ticks_msec()
	for key in [&"warden", &"shade", &"wisp", &"colossus", &"whisperer", &"hound", &"crow", &"conductor", &"brakeman"]:
		PaintedArt.enemy_layers(key)
	var t_enemy := Time.get_ticks_msec() - t
	t = Time.get_ticks_msec()
	var screens := 0
	for f in DirAccess.get_directories_at("res://art/layers/screens"):
		PaintedArt.screen_texture(StringName(f))
		screens += 1
	var t_screens := Time.get_ticks_msec() - t
	print("PERF load: %d cards %d ms, 9 enemies %d ms, %d screens %d ms" % [cards, t_cards, t_enemy, screens, t_screens])

	var datas: Array[EnemyData] = []
	for p in ["skittering_wisp", "hollow_colossus", "lost_shade"]:
		datas.append(load("res://data/enemies/%s.tres" % p) as EnemyData)
	var combat := Combat.create(Combatant.new("Wanderer", 40), StarterContent.extended_deck(), datas, 606)
	var scene: Control = load("res://battle.tscn").instantiate()
	scene.external_combat = combat
	root.add_child(scene)
	var vp := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	for i in 30:
		await process_frame
	var cpu := 0.0
	var gpu := 0.0
	var n := 120
	var start := Time.get_ticks_usec()
	for i in n:
		await process_frame
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp)
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
	var wall := (Time.get_ticks_usec() - start) / 1000.0 / n
	print("PERF frame: wall %.2f ms, render cpu %.2f ms, gpu %.2f ms (avg of %d)" % [wall, cpu / n, gpu / n, n])
	print("PERF memory: textures %.0f MB, static %.0f MB" % [Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0, Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0])
	quit()
