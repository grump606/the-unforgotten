extends SceneTree
## Throwaway stand-in for the future run layer. Chains 3 fights (1, 2, 3 enemies)
## around one persistent player Combatant and a growing deck, to prove the seam
## described in docs/RUN_INTEGRATION.md. Uses only the public Combat API.
## Run: godot --headless --path . -s res://tools/run_stub.gd -- --seed 1

const PLAYER_START_HP: int = preload("res://battle.gd").PLAYER_START_HP # single source: battle.gd
const REST_HEAL := 8
const TURN_CAP := 50 # a fight still running after this many turns is a stall (treated as a loss)
const USAGE := "Usage: godot --headless --path . -s res://tools/run_stub.gd -- [--seed S] [--character ID]\n  --seed S        run seed, integer (default 1)\n  --character ID  max HP and starting deck come from this character: deserter, thief or medium (default deserter)"

var _outcome := 0 # 0 running, 1 victory, -1 defeat


func _initialize() -> void:
	var opts := _parse_args(OS.get_cmdline_user_args())
	if opts.is_empty():
		quit(2)
		return
	quit(_run(opts["seed"], StringName(opts["character"])))


## Returns {seed, character} or an empty dictionary (after printing usage) on bad input.
func _parse_args(args: PackedStringArray) -> Dictionary:
	var opts := {"seed": 1, "character": String(StarterContent.DEFAULT_CHARACTER_ID)}
	var i := 0
	while i < args.size():
		var name := args[i]
		if (name != "--seed" and name != "--character") or i + 1 >= args.size():
			printerr("run_stub: unexpected or incomplete argument '%s'\n%s" % [name, USAGE])
			return {}
		var value := args[i + 1]
		if name == "--seed":
			if not value.is_valid_int():
				printerr("run_stub: --seed needs an integer value\n%s" % USAGE)
				return {}
			opts["seed"] = value.to_int()
		else:
			if not StarterContent.CHARACTER_PATHS.has(StringName(value)):
				printerr("run_stub: --character must be one of %s\n%s" % [", ".join(StarterContent.character_ids()), USAGE])
				return {}
			opts["character"] = value
		i += 2
	return opts


## Returns the process exit code: 0 run finished (won or lost), 1 internal failure.
func _run(run_seed: int, character_id: StringName) -> int:
	var character := StarterContent.character(character_id)
	if character == null:
		return 1
	var deck: Array[CardData] = []
	deck.assign(character.starting_deck)
	if deck.is_empty():
		printerr("run_stub: extended deck failed to load")
		return 1
	# Reward pool: one entry per distinct card type in the extended deck.
	var reward_pool: Array[CardData] = []
	var seen: Dictionary = {}
	for card in deck:
		if not seen.has(card.id):
			seen[card.id] = true
			reward_pool.append(card)

	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed
	var player := Combatant.new(character.display_name, character.max_hp)
	print("Run stub: seed %d, character %s, player HP %d, deck %d" % [run_seed, character_id, player.hp, deck.size()])

	for fight_no in range(1, Combat.MAX_ENEMIES + 1):
		var enemy_datas := StarterContent.varied_encounter(fight_no, rng)
		if enemy_datas.size() != fight_no:
			printerr("run_stub: encounter of %d enemies failed to load" % fight_no)
			return 1
		var names: PackedStringArray = []
		for data in enemy_datas:
			names.append(data.display_name)
		var hp_before := player.hp
		var combat := Combat.new(player, deck, enemy_datas, rng.randi())
		combat.combat_ended.connect(func(victory: bool) -> void: _outcome = 1 if victory else -1)
		_outcome = 0
		combat.start()
		# Per-fight state must start clean even though the Combatant is reused.
		var leaked := leaked_state(player)
		if leaked != "":
			printerr("run_stub: state leaked into fight %d (%s)" % [fight_no, leaked])
			return 1
		if not _play(combat):
			return 1
		var result := "WIN" if _outcome == 1 else ("LOSS" if _outcome == -1 else "STALL")
		var line := "Fight %d [%s] HP %d -> %d, %d turns, %s" % [fight_no, ", ".join(names), hp_before, player.hp, combat.turn, result]
		if _outcome != 1:
			print(line)
			print("Run result: DEFEAT in fight %d" % fight_no)
			return 0
		var reward := reward_pool[rng.randi_range(0, reward_pool.size() - 1)]
		deck.append(reward)
		var healed := player.heal(REST_HEAL)
		print("%s | reward %s (deck %d), rest +%d -> HP %d" % [line, reward.display_name, deck.size(), healed, player.hp])
	print("Run result: VICTORY, final HP %d/%d, deck %d" % [player.hp, player.max_hp, deck.size()])
	return 0


## Describes the per-fight state still on `player` (Block, any status or stack, temporary stacks
## included), "" when clean: a fight must start clean even though the Combatant is reused between fights.
static func leaked_state(player: Combatant) -> String:
	var parts: PackedStringArray = []
	if player.block != 0:
		parts.append("block %d" % player.block)
	for status in Combatant.Status.values():
		if player.status_turns(status) != 0 or player.stacks(status) != 0:
			parts.append("%s %d (temp %d)" % [str(Combatant.Status.keys()[status]).to_lower(), player.status_turns(status), player.stacks(status) - player.status_turns(status)])
	return ", ".join(parts)


## Plays the fight to its end with the trivial policy. Returns false on an internal failure.
func _play(combat: Combat) -> bool:
	while combat.phase == Combat.Phase.PLAYER_TURN:
		if combat.turn > TURN_CAP:
			combat.abandon() # release the persistent player from the stalled fight
			return true
		var hand_index := _first_affordable(combat)
		while hand_index != -1:
			if not combat.play_card(hand_index, -1):
				printerr("run_stub: play_card rejected affordable card at index %d" % hand_index)
				return false
			if combat.phase != Combat.Phase.PLAYER_TURN:
				return true
			hand_index = _first_affordable(combat)
		if combat.phase == Combat.Phase.PLAYER_TURN and not combat.end_player_turn(SimPolicy.discards_for(combat)):
			printerr("run_stub: end_player_turn rejected the discard")
			return false
	return true


func _first_affordable(combat: Combat) -> int:
	for i in combat.piles.hand.size():
		if combat.can_play(i):
			return i
	return -1
