extends SceneTree
var failures := 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + label)

func _initialize() -> void:
	for id in StarterContent.character_ids():
		for index in [6, 7, 8, 9, 10, 18, 19, 20]:
			var state := RunState.new(811, id)
			state.stop_index = index
			var snapshot := RunSave.to_dict(state)
			var loaded := RunSave.from_dict(snapshot)
			check(loaded.run != null, "restore %s at stop %d" % [id, index])
			if loaded.run == null:
				continue
			check(RunSave.to_dict(loaded.run) == snapshot, "save roundtrip preserves all fields")
			check(DestinationArt.label_at(loaded.run.stop_index) == DestinationArt.label_at(index), "restored destination")
			if state.current_stop().type != RunState.StopType.COMBAT:
				continue
			var body := Control.new()
			body.size = Vector2(1152, 648)
			root.add_child(body)
			var screen := CombatScreen.new()
			screen.attach(loaded.run, body, func() -> void: pass)
			screen.show(func(_victory: bool) -> void: pass, func() -> void: pass)
			await process_frame
			check(body.get_child_count() == 1, "restored fight creates one battle")
			var backdrop := body.find_children("*", "BattleBackdrop", true, false)
			check(backdrop.size() == 1 and backdrop[0].painted_name() == DestinationArt.battle_key(index), "restored fight selects destination painting")
			var battle: Control = body.get_child(0)
			for enemy in battle._combat.enemies:
				check(Fighter.ART_KEYS.has(enemy.display_name), "renamed enemy has art alias")
			battle._combat.abandon()
			body.queue_free()
			await process_frame
	print("RESKIN PRESENTATION FAILURES: ", failures)
	quit(1 if failures else 0)
