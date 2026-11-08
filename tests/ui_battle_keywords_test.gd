extends "res://tests/ui_battle_support.gd"
## Headless UI test for battle.tscn keyword cards and status display: card keyword badges, status chips and
## tooltips, and Forgotten-pile damage. Run via scripts/check.ps1.

## Keyword cards on screen: keyword line and X cost on the face, Dormant cannot be played, Anchor and Fading
## cards cannot be marked for discard and do not count toward the 5, the Forgotten count, and multi-hit
## and Surge previews.
func _check_keywords(node: Control) -> void:
	node._start_combat()
	await process_frame
	var c: Combat = node._combat
	c.player.clear_block()
	c.plays_this_turn = 0
	c.energy = 3
	for e in c.enemies:
		e.clear_statuses()
		e.clear_block()
		e.max_hp = 500
		e.hp = 500
	node._select_target(0)

	# Card face: keyword line, X cost, markers.
	var face := CardView.new()
	face.set_card(_proto("surge_slash"))
	check(face.keyword_text() == "SURGE" and face.cost_text() == "X", "a Surge card shows the SURGE keyword line and an X cost")
	face.set_card(_proto("forgotten_strike"))
	check(face.keyword_text() == "FORGOTTEN" and face.cost_text() == "1", "a Forgotten card shows its keyword line and a numeric cost")
	face.set_card(load("res://data/cards/bash.tres"))
	check(face.keyword_text() == "" and face.cost_text() == "1", "a plain card has no keyword line")
	face.set_card(_proto("fading_jab"))
	check(face.self_modulate.a < 1.0, "a Fading card is drawn semi-transparent")
	face.free()

	# Dormant: not clickable, not draggable, not playable, no preview.
	c.piles.hand.assign([_proto("dormant_burden"), _proto("double_strike")])
	node._refresh()
	await process_frame
	var views := CardView.find_all(node._hand_box)
	check(views[0].state == CardView.State.UNPLAYABLE and not views[0].is_clickable() and views[0].note == "DORMANT", "a Dormant card is unplayable and says so")
	check(views[0].preview == "", "a Dormant card shows no damage preview")
	var hand_n := c.piles.hand.size()
	var origin := views[0].get_global_rect().position + Vector2(20, 20)
	_mouse_button(views[0], true, origin)
	_mouse_move(views[0], origin + Vector2(80, 0))
	check(not node.is_dragging_card() and not views[0].is_dragging(), "a Dormant card cannot be dragged")
	_mouse_button(views[0], false, origin + Vector2(80, 0))
	_mouse_button(views[0], true, origin)
	_mouse_button(views[0], false, origin)
	node._play_hand_card(0)
	check(c.piles.hand.size() == hand_n and c.energy == 3, "clicking a Dormant card plays nothing")
	check(node._target_preview(_proto("dormant_burden"), c.enemies[0]).is_empty(), "a Dormant card has no target preview")

	# Multi-hit preview: 3 x2 against 4 Block, then also Exposed (3 -> 4 per hit, rounded down).
	var dbl := _proto("double_strike")
	c.enemies[0].gain_block(4)
	var info: Dictionary = node._target_preview(dbl, c.enemies[0])
	check(info.dealt == 6 and info.lost == 2, "3 x2 against 4 Block deals 6 and loses 2 HP (%s)" % str(info))
	check(info.text.contains("Deals 6 (3 x2)") and info.text.contains("2 after Block"), "multi-hit text: " + info.text.replace("
", " | "))
	c.enemies[0].apply_status(Combatant.Status.EXPOSED, 2)
	info = node._target_preview(dbl, c.enemies[0])
	check(info.dealt == 8 and info.lost == 4, "3 x2 against 4 Block and Exposed deals 8 and loses 4 HP (%s)" % str(info))
	var hp_before: int = c.enemies[0].hp
	c.piles.hand.assign([dbl])
	node._refresh()
	c.energy = 3
	c.play_card(0, 0)
	check(hp_before - c.enemies[0].hp == info.lost, "the multi-hit preview matches the real damage")
	c.enemies[0].clear_statuses()
	c.enemies[0].clear_block()

	# Surge preview scales with the energy that would be spent; clicking plays it for all the energy.
	var slash := _proto("surge_slash")
	c.energy = 4
	info = node._target_preview(slash, c.enemies[0])
	check(info.dealt == 12 and info.text.contains("Deals 12 (3 x4)"), "Surge Slash at 4 energy previews 12: " + info.text.replace("
", " | "))
	c.energy = 2
	check(node._target_preview(slash, c.enemies[0]).dealt == 6, "at 2 energy the Surge preview is 6")
	c.energy = 0
	check(node._target_preview(slash, c.enemies[0]).dealt == 0, "at 0 energy the Surge preview is 0")
	c.energy = 3
	c.piles.hand.assign([slash])
	node._refresh()
	views = CardView.find_all(node._hand_box)
	check(views[0].is_clickable() and views[0].cost_text() == "X" and views[0].preview.contains("Deals 9"), "a Surge card is playable and previews with the current energy: " + views[0].preview.replace("
", " | "))
	hp_before = c.enemies[0].hp
	views[0].pressed.emit()
	check(c.energy == 0 and hp_before - c.enemies[0].hp == 9, "clicking a Surge card spends all energy and hits once per energy")
	c.energy = 0
	c.piles.hand.assign([slash])
	node._refresh()
	check(CardView.find_all(node._hand_box)[0].is_clickable(), "a Surge card stays playable at 0 energy")

	# Pile label shows the Forgotten count.
	check(node._pile_text().contains("Forgotten 0"), "the pile label lists Forgotten: " + node._pile_text().replace("
", " | "))
	c.energy = 3
	var discarded_before := c.piles.discard_pile.size()
	c.piles.hand.assign([_proto("forgotten_strike")])
	node._refresh()
	c.play_card(0, 0)
	check(node._pile_text().contains("Forgotten 1") and node._pile_text().contains("Discard %d
" % discarded_before), "a played Forgotten card is counted under Forgotten, not Discard (discard was %d): " % discarded_before + node._pile_text().replace("
", " | "))

	# Discard step: Anchor and Fading cards cannot be marked and do not count toward the 5.
	var plain := load("res://data/cards/bash.tres") as CardData
	c.piles.hand.assign([plain, plain, plain, plain, plain, plain, plain, _proto("anchor_ward"), _proto("fading_jab")])
	node._refresh()
	node._on_end_turn_pressed()
	check(c.phase == Combat.Phase.DISCARDING and node._end_turn_button.text == "Discard 2 more", "7 counted cards plus Anchor and Fading must discard 2: " + node._end_turn_button.text)
	check(node._result_label.text.contains("keep 7 of up to 5") and node._result_label.text.contains("Fading cards left in hand will be Forgotten"), "the prompt counts only normal cards and warns about Fading: " + node._result_label.text)
	views = CardView.find_all(node._hand_box)
	check(views[7].note == "ANCHOR: STAYS" and views[8].note == "FORGOTTEN AT END", "Anchor and Fading cards say what happens to them in the discard step")
	views[7].pressed.emit()
	views[8].pressed.emit()
	check(c.discard_marks.is_empty() and not CardView.find_all(node._hand_box)[7].discard_marked, "Anchor and Fading cards cannot be marked")
	views[0].pressed.emit()
	views[1].pressed.emit()
	check(not node._end_turn_button.disabled and node._end_turn_button.text == "Discard 2", "marking two normal cards is enough")
	node._on_end_turn_pressed()
	check(c.piles.forgotten.size() == 2 and c.piles.hand.has(_proto("anchor_ward")), "confirming forgets the Fading card and keeps the Anchor card in hand")


func _chip_labels(view: Fighter) -> Dictionary:
	var out := {}
	for chip in view.status_chips():
		out[chip.kind] = chip.label
	return out


## Phase 2b: status badges on both sides, live card numbers, previews and intents through the shared pipeline.
func _check_statuses(node: Control) -> void:
	var datas: Array[EnemyData] = []
	for id in ["lost_shade", "cinder_hound"]:
		datas.append(load("res://data/enemies/%s.tres" % id) as EnemyData)
	node._start_with(Combatant.new("Wanderer", 60), datas, 1)
	node._refresh()
	await process_frame
	var c: Combat = node._combat
	c.energy = 9
	c.player.clear_block()
	c.plays_this_turn = 0
	for e in c.enemies:
		e.clear_statuses()
		e.clear_block()
		e.max_hp = 500
		e.hp = 500
	node._select_target(0)
	var enemy: EnemyUnit = c.enemies[0]
	var enemy_view: Fighter = node._enemy_views[0]
	var player_view: Fighter = node._player_view

	# Badges: every status shows with its number (turns, or the signed stack), on enemy and player alike.
	for pair in [[enemy, enemy_view], [c.player, player_view]]:
		var unit: Combatant = pair[0]
		var view: Fighter = pair[1]
		unit.clear_statuses()
		node._refresh()
		check(_chip_labels(view).is_empty(), "%s: no badges without statuses" % unit.display_name)
		unit.apply_status(Combatant.Status.SHAKEN, 2)
		unit.apply_status(Combatant.Status.FRAYED, 3)
		unit.apply_status(Combatant.Status.MALICE, 2)
		unit.apply_status(Combatant.Status.WARD, -1)
		node._refresh()
		var labels := _chip_labels(view)
		check(labels.get(&"shaken") == "2" and labels.get(&"frayed") == "3" and labels.get(&"malice") == "+2" and labels.get(&"ward") == "-1", "%s: badges show turns and signed stacks: %s" % [unit.display_name, str(labels)])
		var chips := view.status_chips()
		var ward_chip: Dictionary = chips[chips.size() - 1]
		var malice_chip: Dictionary = chips[chips.size() - 2]
		check(ward_chip.color == CardView.STATUS_NEGATIVE and malice_chip.color == CardView.kind_color(CardEffect.Kind.MALICE), "%s: a debuff badge is tinted red, a buff keeps its colour" % unit.display_name)
		# Temporary stacks count, and a stack that cancels to 0 has no badge.
		unit.apply_temp_stack(Combatant.Status.MALICE, 3)
		unit.apply_status(Combatant.Status.WARD, 1)
		node._refresh()
		labels = _chip_labels(view)
		check(labels.get(&"malice") == "+5" and not labels.has(&"ward"), "%s: temporary stacks show and a stack at 0 has no badge: %s" % [unit.display_name, str(labels)])
		# Scent shows a badge with its stack, and goes again when removed.
		unit.apply_status(Combatant.Status.SCENT, 3)
		node._refresh()
		check(_chip_labels(view).get(&"scent") == "3", "%s: a Scent badge shows its stack: %s" % [unit.display_name, str(_chip_labels(view))])
		check(node._status_tooltip(unit).contains("Scent 3"), "%s: the status tooltip explains Scent" % unit.display_name)
		unit.remove_status(Combatant.Status.SCENT)
		node._refresh()
		check(not _chip_labels(view).has(&"scent"), "%s: no Scent badge without Scent" % unit.display_name)
		# Everything at once: pills wrap into rows that stay inside the figure and never overlap.
		unit.apply_status(Combatant.Status.WARD, 4)
		unit.apply_status(Combatant.Status.EXPOSED, 2)
		unit.apply_status(Combatant.Status.HAUNTED, 3)
		unit.hold = 4
		unit.thorns = 12
		node._refresh()
		var rects := view.chip_rects()
		var ok := rects.size() == 8 and view.status_chips().size() == 8
		for i in rects.size():
			ok = ok and Rect2(Vector2.ZERO, view.size).encloses(rects[i])
			for j in range(i + 1, rects.size()):
				ok = ok and not rects[i].intersects(rects[j])
		check(ok, "%s: eight badges fit inside the figure without overlap" % unit.display_name)
		unit.clear_statuses()
	node._refresh()

	# Tooltips explain each rule in one line.
	c.player.apply_status(Combatant.Status.SHAKEN, 2)
	c.player.apply_status(Combatant.Status.FRAYED, 1)
	c.player.apply_status(Combatant.Status.MALICE, -2)
	c.player.apply_status(Combatant.Status.WARD, 3)
	node._refresh()
	var tip: String = player_view.tooltip_text
	check(tip.contains("Shaken 2: deals 25% less damage") and tip.contains("Frayed 1: gains 25% less Block") and tip.contains("Malice -2: -2 damage on every hit") and tip.contains("Ward +3: +3 Block from every card"), "the player tooltip explains each status: " + tip.replace("\n", " | "))
	c.player.clear_statuses()

	# Live card numbers: printed with no modifier, green when raised, red when lowered, equal when they cancel.
	var strike := _proto("strike")
	var guard := _proto("guard")
	var face_view := CardView.new()
	node.add_child(face_view)
	face_view.set_card(strike)
	check(face_view.body_lines()[0].text == "Deal 6" and face_view.body_lines()[0].delta == 0, "outside a fight a card shows its printed numbers")
	face_view.live = c.player
	check(face_view.body_lines()[0].text == "Deal 6" and face_view.body_lines()[0].delta == 0, "with no modifier the live number equals the printed one")
	c.player.apply_status(Combatant.Status.MALICE, 2)
	check(face_view.body_lines()[0].text == "Deal 8" and face_view.body_lines()[0].delta == 1, "Malice +2 raises Deal 6 to 8 (green)")
	c.player.apply_temp_stack(Combatant.Status.MALICE, -1)
	check(face_view.body_lines()[0].text == "Deal 7" and face_view.body_lines()[0].delta == 1, "a temporary stack counts in the live number")
	c.player.clear_statuses()
	c.player.apply_status(Combatant.Status.SHAKEN, 2)
	check(face_view.body_lines()[0].text == "Deal 4" and face_view.body_lines()[0].delta == -1, "Shaken lowers Deal 6 to 4 (red)")
	c.player.apply_status(Combatant.Status.MALICE, -9)
	check(face_view.body_lines()[0].text == "Deal 0" and face_view.body_lines()[0].delta == -1, "heavy negative Malice shows Deal 0")
	face_view.set_card(guard)
	c.player.clear_statuses()
	c.player.apply_status(Combatant.Status.FRAYED, 2)
	check(face_view.body_lines()[0].text == "Block 4" and face_view.body_lines()[0].delta == -1, "Frayed lowers Block 6 to 4 (red)")
	c.player.apply_status(Combatant.Status.WARD, 2)
	check(face_view.body_lines()[0].text == "Block 6" and face_view.body_lines()[0].delta == 0, "Ward +2 and Frayed cancel: Block 6 equals the printed number")
	c.player.apply_status(Combatant.Status.WARD, 4)
	check(face_view.body_lines()[0].text == "Block 9" and face_view.body_lines()[0].delta == 1, "Ward +6 then Frayed raises Block 6 to 9 (green): " + face_view.body_lines()[0].text)
	check(face_view.body_lines()[0].text == "Block %d" % c.player.block_from_card(6), "the live Block is the engine's block_from_card")
	c.player.clear_statuses()
	c.player.apply_status(Combatant.Status.MALICE, 1)
	face_view.set_card(_proto("double_strike"))
	check(face_view.body_lines()[0].text == "Deal 4 x2" and face_view.body_lines()[0].delta == 1, "a multi-hit shows the per-hit number: " + face_view.body_lines()[0].text)
	face_view.set_card(_proto("surge_slash"))
	check(face_view.body_lines()[0].text == "Deal 4 x energy spent", "a Surge hit shows the per-hit number: " + face_view.body_lines()[0].text)
	face_view.set_card(_proto("surge_guard"))
	c.player.apply_status(Combatant.Status.WARD, 2)
	check(face_view.body_lines()[0].delta == 0 and face_view.body_lines()[0].text == "Block 4 per energy spent", "Block that scales with energy keeps its printed text")
	face_view.set_card(_proto("shake_foe"))
	check(face_view.body_lines()[0].delta == 0 and face_view.body_lines()[0].text == "Shaken 2", "a status effect line is never rewritten")
	face_view.set_card(_proto("dormant_burden"))
	check(face_view.body_lines()[0].delta == 0, "a Dormant card is unaffected")
	face_view.queue_free()
	# Hand cards are bound to the player, so they follow its statuses.
	c.player.clear_statuses()
	c.player.apply_status(Combatant.Status.MALICE, 3)
	c.piles.hand.assign([strike, guard])
	node._refresh()
	var hand := CardView.find_all(node._hand_box)
	check(hand[0].live == c.player and hand[0].body_lines()[0].text == "Deal 9", "a hand card shows the live number")

	# The drag preview and card-face preview go through hit_damage: they must equal the damage really dealt.
	var dbl := _proto("double_strike")
	var setups := [[0, 0, false, 0], [3, 0, false, 0], [3, 2, false, 0], [3, 2, true, 0], [-2, 0, true, 5], [-9, 2, false, 0], [2, 2, true, 7], [0, 3, false, 4]]
	for card in [strike, dbl]:
		for setup in setups:
			var label := "%s malice %d shaken %d exposed %s block %d" % [card.id, setup[0], setup[1], str(setup[2]), setup[3]]
			c.player.clear_statuses()
			enemy.clear_statuses()
			enemy.clear_block()
			enemy.hp = 500
			c.energy = 9
			if setup[0] != 0:
				c.player.apply_status(Combatant.Status.MALICE, setup[0])
			if setup[1] > 0:
				c.player.apply_status(Combatant.Status.SHAKEN, setup[1])
			if setup[2]:
				enemy.apply_status(Combatant.Status.EXPOSED, 2)
			enemy.gain_block(setup[3])
			c.piles.hand.assign([card])
			node._refresh()
			var info: Dictionary = node._target_preview(card, enemy)
			var views := CardView.find_all(node._hand_box)
			var face: String = views[0].preview
			# Drag it over the enemy: the figure's drop label is the same preview.
			node._on_drag_started(views[0])
			node._on_drag_moved(enemy_view.get_global_rect().get_center())
			var drop_text: String = enemy_view.drop_text
			node._end_drag()
			var before := enemy.hp
			check(c.play_card(0, 0), "%s: played" % label)
			var lost := before - enemy.hp
			check(info.get("lost", -1) == lost, "%s: the preview says %s, the hit lost %d" % [label, str(info), lost])
			check(face.strip_edges() == info.text.strip_edges() and drop_text == info.text.strip_edges(), "%s: the card face and the drag label show the same preview (%s | %s)" % [label, face.replace("\n", " "), drop_text])
	# The all-enemies line also uses the player's Malice.
	c.player.clear_statuses()
	c.player.apply_status(Combatant.Status.MALICE, 2)
	c.energy = 9
	var sweep := load("res://data/cards/sweep.tres") as CardData
	c.piles.hand.assign([sweep])
	node._refresh()
	var sweep_text: String = (CardView.find_all(node._hand_box)[0] as CardView).preview
	check(sweep_text.contains("Deals %d" % (sweep.effects[0].amount + 2)), "the all-enemies preview includes Malice: " + sweep_text.replace("\n", " "))
	c.player.clear_statuses()

	# Enemy Omen: the damage shown to the player includes the enemy's Malice and Shaken, then the player's Expose.
	var attack := CardEffect.make(CardEffect.Kind.DAMAGE, 8)
	var plain := EnemyData.make("Dummy", 30, [attack] as Array[CardEffect], &"dummy")
	var dummy := EnemyUnit.new(plain)
	for setup in [[0, 0, 0], [3, 0, 0], [3, 2, 0], [-2, 0, 0], [3, 2, 2], [-9, 0, 0]]:
		dummy.clear_statuses()
		c.player.clear_statuses()
		if setup[0] != 0:
			dummy.apply_status(Combatant.Status.MALICE, setup[0])
		if setup[1] > 0:
			dummy.apply_status(Combatant.Status.SHAKEN, setup[1])
		if setup[2] > 0:
			c.player.apply_status(Combatant.Status.EXPOSED, setup[2])
		var shown := Fighter.effective_intent(dummy, c.player)
		# What a real hit does to a copy of the player in the same state.
		var probe := Combatant.new("Probe", 500)
		if setup[2] > 0:
			probe.apply_status(Combatant.Status.EXPOSED, setup[2])
		probe.take_damage_final(Combatant.hit_damage(8, dummy, probe))
		var real := 500 - probe.hp
		check(shown.amount == real, "enemy intent %s: shown %d, dealt %d" % [str(setup), shown.amount, real])
	# On the real fighter: the badge number and the tooltip line.
	c.player.clear_statuses()
	enemy.clear_statuses()
	var enemy_intent := enemy.current_intent()
	if enemy_intent != null and enemy_intent.kind == CardEffect.Kind.DAMAGE:
		enemy.apply_status(Combatant.Status.MALICE, 6)
		enemy.apply_status(Combatant.Status.SHAKEN, 2)
		node._refresh()
		var want := Combatant.hit_damage(enemy_intent.amount, enemy, c.player)
		check(Fighter.effective_intent(enemy, c.player).amount == want and want != enemy_intent.amount and node._enemy_tooltip(enemy).contains("Omen: Deal %d" % want), "the enemy tooltip shows the damage after its Malice and Shaken: " + node._enemy_tooltip(enemy).replace("\n", " | "))
	check(enemy_view.intent_target == c.player, "the enemy figure aims its Omen at the player")
	# The badge text names the exact effect: stacks, hit count, and the card an enemy adds.
	var dread := load("res://data/status/dread.tres") as CardData
	check(Fighter.omen_text(CardEffect.make(CardEffect.Kind.DAMAGE, 6, 0, 0, 3)) == "6x3", "a multi-hit Omen reads 6x3")
	check(Fighter.omen_text(CardEffect.make(CardEffect.Kind.DAMAGE, 6)) == "6", "a single hit reads its damage")
	check(Fighter.omen_text(CardEffect.make(CardEffect.Kind.SHAKEN, 2)) == "2" and Fighter.omen_text(CardEffect.make(CardEffect.Kind.FRAYED, 1)) == "1", "Shaken and Frayed Omens read their turns")
	check(Fighter.omen_text(CardEffect.make(CardEffect.Kind.MALICE, 2)) == "+2", "a Malice Omen reads +2")
	check(Fighter.omen_text(CardEffect.make(CardEffect.Kind.ADD_CARD, 1, 0, 0, 1, false, false, dread, CardEffect.Pile.DRAW)) == "Dread", "an add-card Omen names the card")
	var tip_unit := EnemyUnit.new(EnemyData.make("Adder", 10, [CardEffect.make(CardEffect.Kind.ADD_CARD, 1, 0, 0, 1, false, false, dread, CardEffect.Pile.DRAW)] as Array[CardEffect], &"adder"))
	var tip_view := Fighter.new()
	node.add_child(tip_view)
	tip_view.set_enemy(tip_unit)
	tip_view.intent_target = c.player
	await process_frame
	check(node._enemy_tooltip(tip_unit).contains("Omen: Add 1 Dread to your draw pile"), "the tooltip spells out the added card: " + node._enemy_tooltip(tip_unit).replace("
", " | "))
	tip_view.queue_free()
	enemy.clear_statuses()
	# Intents that apply the new statuses are shown as printed, and every intent kind draws.
	for kind in [CardEffect.Kind.SHAKEN, CardEffect.Kind.FRAYED, CardEffect.Kind.MALICE, CardEffect.Kind.WARD]:
		var eff := CardEffect.make(kind, -2 if kind == CardEffect.Kind.WARD else 2)
		var unit := EnemyUnit.new(EnemyData.make("Caster", 10, [eff] as Array[CardEffect], &"caster"))
		var fighter := Fighter.new()
		node.add_child(fighter)
		fighter.set_enemy(unit)
		fighter.intent_target = c.player
		await process_frame
		check(Fighter.effective_intent(unit, c.player) == eff, "an intent of kind %d is shown as printed" % kind)
		fighter.queue_free()


## Damage per Forgotten on screen: the preview grows with the Forgotten pile and equals the damage dealt.
func _check_forgotten_damage(node: Control) -> void:
	var c: Combat
	var strike := _proto("pile_strike")
	var seen := {}
	for setup in [[0, 0], [2, 0], [5, 0], [5, 3]]:
		var forgotten_count: int = setup[0]
		var malice: int = setup[1]
		c = await _fresh_fight(node)
		var pile: Array[CardData] = []
		for i in forgotten_count:
			pile.append(_card("shove"))
		c.piles.forgotten.assign(pile)
		if malice != 0:
			c.player.apply_status(Combatant.Status.MALICE, malice)
		c.piles.hand.assign([strike])
		node._refresh()
		var text: String = (node._hand_box.get_child(0) as CardView).preview
		c.play_card(0, 0)
		var lost: int = 500 - c.enemies[0].hp
		check(text.contains("Deals %d" % lost), "Forgotten damage preview matches the hit with %d Forgotten, Malice %d: '%s' vs %d" % [forgotten_count, malice, text.replace("\n", " "), lost])
		seen[text] = true
	check(seen.size() == 4, "the preview changes as the Forgotten pile and Malice change")
	# The drag preview and the all-enemies line use the Forgotten count too.
	c = await _fresh_fight(node)
	var many: Array[CardData] = []
	for i in 4:
		many.append(_card("shove"))
	c.piles.forgotten.assign(many)
	var all_effects: Array[CardEffect] = [CardEffect.make(CardEffect.Kind.DAMAGE_PER_FORGOTTEN, 2)]
	var sweep_all := CardData.make(&"sweep_forgotten", "Sweep", 1, all_effects, CardData.TargetMode.ALL_ENEMIES)
	check(node._target_preview(strike, c.enemies[0]).get("dealt", -1) == 8, "the drag preview of Pile Strike with 4 Forgotten is 8")
	check(node._damage_preview(sweep_all).contains("Deals 8 (x%d enemies)" % c.living_enemies().size()), "the all-enemies preview uses the Forgotten count: " + node._damage_preview(sweep_all))
	c.piles.forgotten.append(_card("brace"))
	check(node._target_preview(strike, c.enemies[0]).get("dealt", -1) == 10, "the preview grows when the Forgotten pile does")


func _initialize() -> void:
	var node: Control = await _make_battle()
	await _check_keywords(node)
	await _check_statuses(node)
	await _check_forgotten_damage(node)
	_finish()
