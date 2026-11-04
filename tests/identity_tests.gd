extends RefCounted
## Phase 4e: identity and keyword coverage. Every keyword and every effect kind the mechanics rework
## introduced is used by at least one shipped card, no temporary stack points at an enemy, and each
## class still plays like itself. Uses the real card and enemy resources. Registered by run_tests.gd.

const K := CardEffect.Kind
## Kinds with no shipped card yet. FRAYED waits for phase 5 enemy content (it is an enemy-side status).
const PENDING_KINDS: Array[int] = [K.FRAYED]

var _failures := 0


func run() -> int:
	_failures = 0
	_test_no_temporary_stack_on_enemies()
	_test_keyword_coverage()
	_test_effect_kind_coverage()
	_test_thief_identity()
	_test_deserter_identity()
	_test_medium_identity()
	return _failures


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAIL: " + label)


## Shipped cards plus the status and created cards.
func _every_card() -> Array[CardData]:
	var cards: Array[CardData] = StarterContent.all_cards()
	for id in StarterContent.STATUS_CARD_PATHS:
		cards.append(StarterContent.status_card(id))
	for id in StarterContent.CREATED_CARD_PATHS:
		cards.append(StarterContent.created_card(id))
	return cards


## The cards a class can own: its starter deck and everything tagged with it.
func _class_cards(character_id: StringName) -> Array[CardData]:
	var cards: Array[CardData] = StarterContent.starter_deck(character_id)
	for card in StarterContent.all_cards():
		if card.character == character_id:
			cards.append(card)
	return cards


func _has_kind(cards: Array[CardData], kind: int) -> bool:
	for card in cards:
		for effect in card.effects:
			if effect.kind == kind:
				return true
	return false


func _has_flag(cards: Array[CardData], flag: String) -> bool:
	for card in cards:
		if card.get(flag):
			return true
	return false


func _test_no_temporary_stack_on_enemies() -> void:
	var intents := 0
	for id in StarterContent.enemy_ids():
		var enemy := StarterContent.enemy_by_id(id)
		_check(enemy != null, "enemy %s loads" % id)
		if enemy == null:
			continue
		for intent in enemy.intents + enemy.phase_two_intents:
			intents += 1
			_check(not intent.temporary, "enemy %s intent has no temporary stack" % id)
	_check(intents > 0, "enemy intents were scanned (%d)" % intents)
	var effects := 0
	for card in _every_card():
		for effect in card.effects:
			effects += 1
			if effect.temporary:
				_check(effect.reach() != CardEffect.Reach.ENEMIES, "%s: no temporary stack on enemies" % card.id)
	_check(effects > 0, "card effects were scanned")


func _test_keyword_coverage() -> void:
	var cards := _every_card()
	_check(cards.size() > StarterContent.all_cards().size(), "status and created cards were added")
	for flag in ["forgotten", "fading", "ready", "anchor", "dormant", "surge"]:
		_check(_has_flag(cards, flag), "some shipped card has the %s keyword" % flag)
	var fading_created := false
	for id in StarterContent.CREATED_CARD_PATHS:
		fading_created = fading_created or StarterContent.created_card(id).fading
	_check(fading_created, "a created card (Trinket) is Fading")
	var dormant_status := false
	for id in StarterContent.STATUS_CARD_PATHS:
		dormant_status = dormant_status or StarterContent.status_card(id).dormant
	_check(dormant_status, "a status card is Dormant")


func _test_effect_kind_coverage() -> void:
	var cards := _every_card()
	for kind in [K.GLIMPSE, K.ADD_CARD, K.RECALL, K.DAMAGE_PER_FORGOTTEN, K.SHAKEN, K.MALICE, K.WARD]:
		_check(_has_kind(cards, kind), "some shipped card uses effect kind %d" % kind)
	for kind in PENDING_KINDS:
		_check(not _has_kind(cards, kind), "pending kind %d has no card yet (remove it from PENDING_KINDS once it ships)" % kind)
	var multi_hit := false
	var per_energy := false
	for card in cards:
		for effect in card.effects:
			multi_hit = multi_hit or effect.hits > 1
			per_energy = per_energy or effect.per_energy
	_check(multi_hit, "some shipped card hits more than once")
	_check(per_energy, "some shipped card scales per energy")


func _test_thief_identity() -> void:
	var cards := _class_cards(&"thief")
	_check(_has_flag(cards, "ready"), "Thief uses Ready")
	_check(_has_kind(cards, K.SHAKEN), "Thief uses Shaken")
	_check(_has_kind(cards, K.ADD_CARD), "Thief adds a card (Filch)")
	_check(_has_kind(cards, K.MALICE), "Thief uses Malice")
	var multi_hit := false
	for card in cards:
		for effect in card.effects:
			multi_hit = multi_hit or effect.hits > 1
	_check(multi_hit, "Thief has a multi-hit card")


func _test_deserter_identity() -> void:
	var cards := _class_cards(&"deserter")
	_check(_has_kind(cards, K.HOLD), "Deserter uses Hold")
	_check(_has_kind(cards, K.THORNS), "Deserter uses Barbs (THORNS)")
	_check(_has_kind(cards, K.WARD), "Deserter uses Ward")
	_check(_has_flag(cards, "anchor"), "Deserter uses Anchor")


func _test_medium_identity() -> void:
	var cards := _class_cards(&"medium")
	_check(_has_kind(cards, K.HAUNT), "Medium uses Haunt")
	_check(_has_kind(cards, K.LOSE_HP), "Medium spends HP")
	_check(_has_kind(cards, K.DAMAGE_PER_FORGOTTEN) or _has_kind(cards, K.RECALL), "Medium has a Forgotten payoff")
