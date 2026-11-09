class_name ContentRegistry
extends RefCounted
## Loads and caches StarterContent's cards, relics, characters and enemies, and builds the reward and vendor pools.
## StarterContent keeps the path tables and forwards to this class, so callers do not change.


# Content caches. The resources are immutable shared data, so the lists derived from them are built once
# and handed out as copies (callers may reorder or trim what they get). A failed load is never cached, so
# its cause keeps being logged. Tests that swap content call clear_cache().
static var _cards_cache: Array[CardData] = []
static var _relics_cache: Array[RelicData] = []
static var _pool_cache: Dictionary = {}
static var _enemy_paths_by_id: Dictionary = {}
static var _enemy_ids_cache: Array[StringName] = []


## Drops every cached list so the next call rebuilds it from the resources.
static func clear_cache() -> void:
	_cards_cache = []
	_relics_cache = []
	_pool_cache = {}
	_enemy_paths_by_id = {}
	_enemy_ids_cache = []


## Every card that loads, in StarterContent.ALL_CARD_PATHS order. Empty (cause logged) if any fails to load.
static func all_cards() -> Array[CardData]:
	if _cards_cache.is_empty():
		var cards: Array[CardData] = []
		for path in StarterContent.ALL_CARD_PATHS:
			var card := load_card(path)
			if card == null:
				var empty: Array[CardData] = []
				return empty
			cards.append(card)
		_cards_cache = cards
	return _cards_cache.duplicate()


## The distinct cards a character can be offered as rewards: every neutral card plus the cards tagged for
## `character_id`, except the basic cards (Shove, Slip Past), which they start with and can buy but are never
## offered. Empty (cause logged) if any card fails to load.
static func reward_pool(character_id: StringName) -> Array[CardData]:
	var key := "reward:%s" % character_id
	if _pool_cache.has(key):
		return (_pool_cache[key] as Array[CardData]).duplicate()
	var pool: Array[CardData] = []
	for card in all_cards():
		if (card.character == &"" or card.character == character_id) and not card.basic:
			pool.append(card)
	if not pool.is_empty():
		_pool_cache[key] = pool.duplicate()
	return pool


## The cards a vendor may stock for `character_id`: the reward pool plus the basic cards.
static func vendor_pool(character_id: StringName) -> Array[CardData]:
	var key := "vendor:%s" % character_id
	if _pool_cache.has(key):
		return (_pool_cache[key] as Array[CardData]).duplicate()
	var pool: Array[CardData] = []
	for card in all_cards():
		if card.character == &"" or card.character == character_id:
			pool.append(card)
	if not pool.is_empty():
		_pool_cache[key] = pool.duplicate()
	return pool


## Every relic that loads, in StarterContent.RELIC_PATHS order. Empty (cause logged) if any fails to load.
static func all_relics() -> Array[RelicData]:
	if _relics_cache.is_empty():
		var relics: Array[RelicData] = []
		for path in StarterContent.RELIC_PATHS:
			var relic: RelicData = null
			if ResourceLoader.exists(path):
				relic = load(path) as RelicData
			if relic == null:
				Combat.engine_error("StarterContent: missing or non-RelicData resource: %s" % path)
				var empty: Array[RelicData] = []
				return empty
			relics.append(relic)
		_relics_cache = relics
	return _relics_cache.duplicate()


## The relics a vendor may offer `character_id`: every neutral relic plus the ones tagged for them.
static func relic_pool(character_id: StringName) -> Array[RelicData]:
	var key := "relic:%s" % character_id
	if _pool_cache.has(key):
		return (_pool_cache[key] as Array[RelicData]).duplicate()
	var pool: Array[RelicData] = []
	for relic in all_relics():
		if relic.character == &"" or relic.character == character_id:
			pool.append(relic)
	if not pool.is_empty():
		_pool_cache[key] = pool.duplicate()
	return pool


## The character with this id, or null (cause logged) for an unknown id or a resource that fails to load.
static func character(character_id: StringName) -> Character:
	if not StarterContent.CHARACTER_PATHS.has(character_id):
		Combat.engine_error("StarterContent.character: unknown character '%s'" % character_id)
		return null
	var path: String = StarterContent.CHARACTER_PATHS[character_id]
	var loaded: Character = null
	if ResourceLoader.exists(path):
		loaded = load(path) as Character
	if loaded == null:
		Combat.engine_error("StarterContent: missing or non-Character resource: %s" % path)
	return loaded


## A status card by id (`dread` or `murmur`), or null (cause logged) for an unknown id or a bad resource.
static func status_card(id: StringName) -> CardData:
	if not StarterContent.STATUS_CARD_PATHS.has(id):
		Combat.engine_error("StarterContent.status_card: unknown status card id %s" % id)
		return null
	return load_card(StarterContent.STATUS_CARD_PATHS[id])


## A created card by id, or null (cause logged) for an unknown id or a bad resource.
static func created_card(id: StringName) -> CardData:
	if not StarterContent.CREATED_CARD_PATHS.has(id):
		Combat.engine_error("StarterContent.created_card: unknown created card id %s" % id)
		return null
	return load_card(StarterContent.CREATED_CARD_PATHS[id])


## Returns null (after logging an error) if the resource is missing, not a CardData, or has a rarity outside
## CardData.Rarity (the picker would otherwise fail on it). Checked explicitly rather than with assert so
## debug and release builds behave the same.
static func load_card(path: String) -> CardData:
	var card: CardData = null
	if ResourceLoader.exists(path):
		card = load(path) as CardData
	if card == null:
		Combat.engine_error("StarterContent: missing or non-CardData resource: %s" % path)
		return null
	if not has_valid_rarity(card):
		Combat.engine_error("StarterContent: card %s has rarity %d, outside CardData.Rarity: %s" % [card.id, card.rarity, path])
		return null
	return card


## True when the card's rarity is one of CardData.Rarity's values.
static func has_valid_rarity(card: CardData) -> bool:
	return card.rarity >= 0 and card.rarity < CardData.Rarity.size()


## Enemies are deep-copied so each encounter slot owns its data, as before.
## Returns null (after logging an error) if the resource is missing or not an EnemyData.
static func load_enemy(path: String) -> EnemyData:
	var template: EnemyData = null
	if ResourceLoader.exists(path):
		template = load(path) as EnemyData
	if template == null:
		Combat.engine_error("StarterContent: missing or non-EnemyData resource: %s" % path)
		return null
	return template.duplicate(true) as EnemyData


## Every enemy, regular and boss, by EnemyData id (debug launch and tools; encounters use the path lists).
static func enemy_ids() -> Array[StringName]:
	if not _enemy_ids_cache.is_empty():
		return _enemy_ids_cache.duplicate()
	var ids: Array[StringName] = []
	for path in StarterContent.ALL_ENEMY_PATHS + StarterContent.BOSS_ENEMY_PATHS:
		var template := load(path) as EnemyData
		if template != null:
			ids.append(template.id)
			_enemy_paths_by_id[template.id] = path
	_enemy_ids_cache = ids.duplicate()
	return ids


## A fresh copy of the enemy with this id (regular or boss), or null if there is none.
static func enemy_by_id(enemy_id: StringName) -> EnemyData:
	if _enemy_paths_by_id.has(enemy_id):
		var known := load(_enemy_paths_by_id[enemy_id]) as EnemyData
		if known != null and known.id == enemy_id:
			return known.duplicate(true) as EnemyData
	for path in StarterContent.ALL_ENEMY_PATHS + StarterContent.BOSS_ENEMY_PATHS:
		var template := load(path) as EnemyData
		if template != null and template.id == enemy_id:
			_enemy_paths_by_id[enemy_id] = path
			return template.duplicate(true) as EnemyData
	return null
