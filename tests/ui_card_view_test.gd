extends SceneTree
## Headless test for CardView: every card in data/cards builds and draws without errors, the
## frame follows card.character, and each effect kind gets an icon. Run via scripts/check.ps1.

var fails := 0

func check(c: bool, msg: String) -> void:
	if not c:
		fails += 1
		printerr("FAIL: " + msg)
	else:
		print("ok: " + msg)


func _card(id: String) -> CardData:
	return load("res://data/cards/%s.tres" % id) as CardData


## Plain-damage cards must not all share one icon: the variant comes from the card's own data.
func _check_damage_variants() -> void:
	var variants := {}
	for file in DirAccess.get_files_at("res://data/cards"):
		if not file.ends_with(".tres"):
			continue
		var card := load("res://data/cards/" + file) as CardData
		var variant := CardView.icon_variant(card)
		if CardView.primary_kind(card) == CardEffect.Kind.DAMAGE:
			check(variant != &"", "%s (damage) has an icon variant" % card.id)
			variants[variant] = true
		else:
			check(variant == &"" or variant == &"hammer", "%s (not plain damage) has no weapon variant" % card.id)
	check(variants.size() >= 6, "damage cards use at least 6 distinct icon variants (%d)" % variants.size())
	var shove := CardView.icon_variant(_card("shove"))
	var heavy := CardView.icon_variant(_card("heavy_blow"))
	var flurry := CardView.icon_variant(_card("flurry"))
	check(shove != heavy and heavy != flurry and shove != flurry, "Shove, Heavy Blow and Flurry have different icons")
	check(CardView.icon_variant(_card("bash")) == &"hammer", "Bash (damage from Block) is a hammer")
	check(CardView.icon_variant(_card("cutting_word")) == &"needle", "thief damage is a needle")
	check(CardView.icon_variant(_card("sweep")) == &"sweep", "all-enemies damage is a sweep")
	check(CardView.icon_variant(null) == &"", "no card has no variant")


func _initialize() -> void:
	var holder := Control.new()
	root.add_child(holder)
	var count := 0
	var classes := {}
	for file in DirAccess.get_files_at("res://data/cards"):
		if not file.ends_with(".tres"):
			continue
		var card := load("res://data/cards/" + file) as CardData
		var view := CardView.new()
		holder.add_child(view)
		view.set_card(card)
		check(view.class_id == (card.character if card.character != &"" else &""), "%s uses the %s frame" % [card.id, card.character if card.character != &"" else "neutral"])
		check(CardView.primary_kind(card) >= 0, "%s has a primary icon" % card.id)
		classes[view.class_id] = true
		for state in [CardView.State.NORMAL, CardView.State.HOVER, CardView.State.SELECTED, CardView.State.UNPLAYABLE]:
			view.set_state(state, "NEED 1 ENERGY" if state == CardView.State.UNPLAYABLE else "")
		count += 1
	await process_frame
	await process_frame
	check(count >= 35, "built a view for all %d cards" % count)
	check(classes.size() == 4, "neutral and three class frames are all in use")
	check(CardView.palette_id(null) == &"" and CardView.PALETTES.has(&"medium"), "palette lookup")
	var unknown := CardData.make(&"x", "X", 1, [] as Array[CardEffect])
	unknown.character = &"nobody"
	check(CardView.palette_id(unknown) == &"" and CardView.primary_kind(unknown) == -1, "unknown class falls back to neutral")
	for kind in CardEffect.Kind.values():
		check(CardView.ICON_PRIORITY.has(kind), "kind %d has an icon" % kind)
	for kind in CardEffect.Kind.values():
		# The scaled damage kinds share the damage colour through kind_color's fallback; every other kind has its own.
		var damage_family := CardEffect.make(kind, 1).is_damage()
		check(CardView.KIND_COLORS.has(kind) or damage_family, "kind %d has a KIND_COLORS entry (or is a damage kind)" % kind)
		check(CardView.kind_color(kind) is Color, "kind %d has a colour" % kind)
	# A card whose primary kind is a status kind builds, draws in every state and has a glyph.
	for kind in [CardEffect.Kind.SHAKEN, CardEffect.Kind.FRAYED, CardEffect.Kind.MALICE, CardEffect.Kind.WARD]:
		var status_card := CardData.make(&"status_card", "Status", 1, [CardEffect.make(kind, 2)] as Array[CardEffect])
		var status_view := CardView.new()
		holder.add_child(status_view)
		status_view.set_card(status_card)
		for state in [CardView.State.NORMAL, CardView.State.HOVER, CardView.State.SELECTED, CardView.State.UNPLAYABLE]:
			status_view.set_state(state)
		check(CardView.primary_kind(status_card) == kind and status_view.body_lines()[0].delta == 0, "a card led by kind %d draws" % kind)
	# Every kind has a glyph, and a card led by each kind (the new cycling kinds included) builds and draws.
	for kind in CardEffect.Kind.values():
		check(CardView.ICON_KINDS.has(kind), "kind %d has a drawn glyph" % kind)
		var effect := CardEffect.make(kind, 2, 1, 1, 1, false, false, StarterContent.status_card(&"dread") if kind == CardEffect.Kind.ADD_CARD else null)
		var kind_card := CardData.make(&"kind_card", "Kind Card", 1, [effect] as Array[CardEffect])
		var kind_view := CardView.new()
		holder.add_child(kind_view)
		kind_view.set_card(kind_card)
		kind_view.live = Combatant.new("Player", 10)
		for state in [CardView.State.NORMAL, CardView.State.HOVER, CardView.State.SELECTED, CardView.State.UNPLAYABLE]:
			kind_view.set_state(state)
		kind_view.discard_marked = true
		check(CardView.primary_kind(kind_card) == kind, "a card with only kind %d is led by that icon" % kind)
		check(kind_view.body_lines().size() == 1 and kind_view.body_lines()[0].text != "", "kind %d has effect text on its face" % kind)
	# Status cards (Dread, Murmur) get the junk frame, no effect text, and draw in every state at hand size.
	for status_id in [&"dread", &"murmur"]:
		var junk := StarterContent.status_card(status_id)
		var junk_view := CardView.new()
		holder.add_child(junk_view)
		junk_view.view_scale = 0.7
		junk_view.set_card(junk)
		for state in [CardView.State.NORMAL, CardView.State.HOVER, CardView.State.UNPLAYABLE]:
			junk_view.set_state(state)
		check(CardView.is_status_card(junk) and junk_view.class_id == &"status", "%s uses the status frame" % status_id)
		check(junk_view.body_lines().is_empty(), "%s has no effect text" % status_id)
		check(junk_view.keyword_text().contains("DORMANT"), "%s shows DORMANT" % status_id)
	check(not CardView.is_status_card(_card("bash")) and not CardView.is_status_card(load("res://data/prototype/dormant_burden.tres") as CardData), "ordinary and Dormant-with-effects cards are not status cards")
	var strip_text := ""
	for kind in [CardEffect.Kind.SHAKEN, CardEffect.Kind.FRAYED, CardEffect.Kind.MALICE, CardEffect.Kind.WARD]:
		strip_text += str(CardView.KEYWORDS.get(kind, "")) + " "
	check(strip_text == "SHAKEN FRAYED MALICE WARD ", "the strip legend names the four status kinds")
	# Prototype keyword cards build and draw in every state.
	for file in DirAccess.get_files_at("res://data/prototype"):
		if not file.ends_with(".tres"):
			continue
		var proto := load("res://data/prototype/" + file) as CardData
		var proto_view := CardView.new()
		holder.add_child(proto_view)
		proto_view.set_card(proto)
		for state in [CardView.State.NORMAL, CardView.State.HOVER, CardView.State.SELECTED, CardView.State.UNPLAYABLE]:
			proto_view.set_state(state)
		proto_view.discard_marked = true
		check(proto_view.cost_text() == ("X" if proto.surge else str(proto.cost)) and (proto_view.keyword_text() != "") == (not proto.keyword_lines().is_empty()), "%s shows the right cost stamp and keyword line" % proto.id)
	await process_frame
	_check_damage_variants()
	print("DONE fails=", fails)
	quit(1 if fails > 0 else 0)
