extends "res://tests/test_base.gd"
## The intentional content and balance numbers, in ONE place. Other suites compare against the registries
## (StarterContent.ALL_CARD_PATHS, RELIC_PATHS, ALL_ENEMY_PATHS, character_ids()) so that adding a card or relic
## needs no edit there; when you add content on purpose, update the numbers below and the matching line in
## docs/GAME_FACTS.md. A failure here means "the content totals changed": confirm that was intended.
##
## Card-text pins such as describe() == "Deal 16" live in the per-class card suites and are labelled there as
## balance pins; they change only when a card is rebalanced.

const CARD_COUNT := 112
const RELIC_COUNT := 21
const ENEMY_POOL_COUNT := 7
const BOSS_COUNT := 2
const CHARACTER_COUNT := 4
const STARTER_DECK_SIZE := 10
const EXTENDED_DECK_SIZE := 14
## Class-tagged cards per character (docs/GAME_FACTS.md); the Stray list in stray_cards_tests.gd is only its 15 non-starter-pool extras.
const CLASS_CARDS := {&"deserter": 24, &"thief": 26, &"medium": 23, &"stray": 25}
const MAX_HP := {&"deserter": 52, &"thief": 36, &"medium": 56, &"stray": 37}


func run() -> int:
	_failures = 0
	_test_content_totals()
	_test_starting_numbers()
	_test_every_registered_file_is_counted()
	return _failures


func _test_content_totals() -> void:
	_check(StarterContent.ALL_CARD_PATHS.size() == CARD_COUNT, "balance pin: %d cards (got %d)" % [CARD_COUNT, StarterContent.ALL_CARD_PATHS.size()])
	_check(StarterContent.RELIC_PATHS.size() == RELIC_COUNT, "balance pin: %d relics (got %d)" % [RELIC_COUNT, StarterContent.RELIC_PATHS.size()])
	_check(StarterContent.ALL_ENEMY_PATHS.size() == ENEMY_POOL_COUNT, "balance pin: %d regular enemies (got %d)" % [ENEMY_POOL_COUNT, StarterContent.ALL_ENEMY_PATHS.size()])
	_check(StarterContent.BOSS_ENEMY_PATHS.size() == BOSS_COUNT, "balance pin: %d bosses" % BOSS_COUNT)
	_check(StarterContent.character_ids().size() == CHARACTER_COUNT, "balance pin: %d characters" % CHARACTER_COUNT)
	var per_class := {}
	for card in StarterContent.all_cards():
		if card.character != &"":
			per_class[card.character] = int(per_class.get(card.character, 0)) + 1
	_check(per_class == CLASS_CARDS, "balance pin: class cards per character %s" % str(CLASS_CARDS))


func _test_starting_numbers() -> void:
	_check(StarterContent.deck().size() == STARTER_DECK_SIZE, "balance pin: the neutral starter deck has %d cards" % STARTER_DECK_SIZE)
	_check(StarterContent.EXTENDED_DECK_SIZE == EXTENDED_DECK_SIZE and StarterContent.extended_deck().size() == EXTENDED_DECK_SIZE, "balance pin: the extended deck has %d cards" % EXTENDED_DECK_SIZE)
	for id in StarterContent.character_ids():
		_check(StarterContent.starter_deck(id).size() == STARTER_DECK_SIZE, "balance pin: %s starts with %d cards" % [id, STARTER_DECK_SIZE])
		var character := StarterContent.character(id)
		_check(MAX_HP.has(id) and character.max_hp == MAX_HP[id], "balance pin: %s starts at %s HP" % [id, str(MAX_HP.get(id))])


## The registries must list every data file: otherwise a total above could pass while a card sits unregistered.
func _test_every_registered_file_is_counted() -> void:
	_check(_count_tres("res://data/cards") == StarterContent.ALL_CARD_PATHS.size(), "every data/cards/*.tres is registered (%d files)" % _count_tres("res://data/cards"))
	_check(_count_tres("res://data/relics") == StarterContent.RELIC_PATHS.size(), "every data/relics/*.tres is registered (%d files)" % _count_tres("res://data/relics"))
	_check(_count_tres("res://data/enemies") == StarterContent.ALL_ENEMY_PATHS.size() + StarterContent.BOSS_ENEMY_PATHS.size(), "every data/enemies/*.tres is a regular enemy or a boss (%d files)" % _count_tres("res://data/enemies"))


func _count_tres(dir_path: String) -> int:
	var count := 0
	for file_name in DirAccess.get_files_at(dir_path):
		if file_name.ends_with(".tres") or file_name.ends_with(".tres.remap"):
			count += 1
	return count
