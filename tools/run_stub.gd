extends SceneTree
## Throwaway stand-in for the future run layer. Chains 3 fights (1, 2, 3 enemies)
## around one persistent player Combatant and a growing deck, to prove the seam
## described in docs/RUN_INTEGRATION.md. Uses only the public Combat API.
## Run: godot --headless --path . -s res://tools/run_stub.gd -- --seed 1

const USAGE := "Usage: godot --headless --path . -s res://tools/run_stub.gd -- [--seed S] [--character ID]\n  --seed S        run seed, integer (default 1)\n  --character ID  max HP and starting deck come from this character: deserter, thief, medium or stray (default deserter)"

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
	var deck := StarterContent.starter_deck(character.id)
	if deck.is_empty():
		printerr("run_stub: the character's starting deck failed to load")
		return 1
	# Reward pool: one entry per distinct card type in the starting deck.
	var reward_pool: Array[CardData] = []
	var seen: Dictionary = {}
	for card in deck:
		if not seen.has(card.id):
			seen[card.id] = true
			reward_pool.append(card.base() if card.is_remembered else card)

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
		var deck_before := deck.duplicate()
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
		# Cards a fight creates (Add card effects, enemy status cards) live in its piles only; the deck is untouched.
		if deck != deck_before:
			printerr("run_stub: fight %d changed the deck (a created card leaked)" % fight_no)
			return 1
		var result := "WIN" if _outcome == 1 else ("LOSS" if _outcome == -1 else "STALL")
		var line := "Fight %d [%s] HP %d -> %d, %d turns, %s" % [fight_no, ", ".join(names), hp_before, player.hp, combat.turn, result]
		if _outcome != 1:
			print(line)
			print("Run result: DEFEAT in fight %d" % fight_no)
			return 0
		var reward := reward_pool[rng.randi_range(0, reward_pool.size() - 1)]
		deck.append(reward)
		var rested := rest_or_remember(player, deck)
		print("%s | reward %s (deck %d), %s -> HP %d" % [line, reward.display_name, deck.size(), rested, player.hp])
	print("Run result: VICTORY, final HP %d/%d, deck %d" % [player.hp, player.max_hp, deck.size()])
	return 0


## The stub's rest stop, like the real one: Rest (heal to full, as RunState.rest does) while HP is under
## SimPolicy.REST_BELOW of max or no card can be Remembered, else Remember the first card that can be (its slot takes the Remembered variant: same id,
## `is_remembered`). Returns a short description of what happened.
static func rest_or_remember(player: Combatant, deck: Array[CardData]) -> String:
	var pick := -1
	for i in deck.size():
		if deck[i].can_remember():
			pick = i
			break
	if not SimPolicy.prefers_rest(player, pick != -1):
		var name := deck[pick].display_name
		deck[pick] = deck[pick].remembered_card()
		return "remembered %s" % name
	return "rest +%d" % player.heal(player.max_hp - player.hp)


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
	while SimPolicy.is_acting(combat):
		if combat.turn > SimPolicy.TURN_CAP:
			combat.abandon() # release the persistent player from the stalled fight
			return true
		if not SimPolicy.resolve_choices(combat):
			return false
		if combat.phase != Combat.Phase.PLAYER_TURN:
			continue
		var hand_index := _first_affordable(combat)
		while hand_index != -1:
			if not combat.play_card(hand_index, -1):
				printerr("run_stub: play_card rejected affordable card at index %d" % hand_index)
				return false
			if not SimPolicy.resolve_choices(combat):
				return false
			if combat.phase != Combat.Phase.PLAYER_TURN:
				break
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
