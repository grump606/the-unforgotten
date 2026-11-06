class_name StarterContent
extends RefCounted
## Placeholder content for the afterlife-escape theme. Card and enemy numbers
## live in .tres resources under res://data/ so they can be tuned in the editor;
## only the starting deck composition is defined here. Numbers are untuned.

const SHOVE_PATH := "res://data/cards/shove.tres"
const SLIP_PAST_PATH := "res://data/cards/slip_past.tres"
const GLIMPSE_EXIT_PATH := "res://data/cards/glimpse_exit.tres"
const WARDEN_PATH := "res://data/enemies/gate_warden.tres"
const LOST_SHADE_PATH := "res://data/enemies/lost_shade.tres"
const HEAVY_BLOW_PATH := "res://data/cards/heavy_blow.tres"
const BRACE_PATH := "res://data/cards/brace.tres"
const STEADY_BREATH_PATH := "res://data/cards/steady_breath.tres"
const SHOULDER_CHARGE_PATH := "res://data/cards/shoulder_charge.tres"
const MARK_THE_WEAK_PATH := "res://data/cards/mark_the_weak.tres"
const SWEEP_PATH := "res://data/cards/sweep.tres"
const CUTTING_WORD_PATH := "res://data/cards/cutting_word.tres"
const SECOND_WIND_PATH := "res://data/cards/second_wind.tres"
const HAMSTRING_PATH := "res://data/cards/hamstring.tres"
const IRON_RESOLVE_PATH := "res://data/cards/iron_resolve.tres"
const FLURRY_PATH := "res://data/cards/flurry.tres"
const GUARDED_STRIKE_PATH := "res://data/cards/guarded_strike.tres"
const HOLD_THE_LINE_PATH := "res://data/cards/hold_the_line.tres"
const BASH_PATH := "res://data/cards/bash.tres"
const DIG_IN_PATH := "res://data/cards/dig_in.tres"
const COLD_STEEL_PATH := "res://data/cards/cold_steel.tres"
const COUNTER_STANCE_PATH := "res://data/cards/counter_stance.tres"
const LAST_STAND_PATH := "res://data/cards/last_stand.tres"
# Phase 4c (Deserter) new cards.
const DIG_DEEP_PATH := "res://data/cards/dig_deep.tres"
const LIFT_PATH := "res://data/cards/lift.tres"
const SLEIGHT_PATH := "res://data/cards/sleight.tres"
const POCKET_WATCH_PATH := "res://data/cards/pocket_watch.tres"
const LAST_POCKET_PATH := "res://data/cards/last_pocket.tres"
const SPREE_PATH := "res://data/cards/spree.tres"
## Phase 4b Thief cards.
const SHARPEN_PATH := "res://data/cards/sharpen.tres"
const QUICK_STUDY_PATH := "res://data/cards/quick_study.tres"
const CLEANED_OUT_PATH := "res://data/cards/cleaned_out.tres"
const CONFESS_PATH := "res://data/cards/confess.tres"
const LINGERING_DREAD_PATH := "res://data/cards/lingering_dread.tres"
const COLD_WHISPER_PATH := "res://data/cards/cold_whisper.tres"
const PENANCE_PATH := "res://data/cards/penance.tres"
const GRAVE_CHILL_PATH := "res://data/cards/grave_chill.tres"
const SPIRIT_TITHE_PATH := "res://data/cards/spirit_tithe.tres"
const SEANCE_PATH := "res://data/cards/seance.tres"
const BLEED_THE_VEIL_PATH := "res://data/cards/bleed_the_veil.tres"
const RECKONING_PATH := "res://data/cards/reckoning.tres"
# Phase 4d: Medium cards that feed on the Forgotten pile.
const REMEMBER_PATH := "res://data/cards/remember.tres"
const CHORUS_OF_THE_LOST_PATH := "res://data/cards/chorus_of_the_lost.tres"
const HOLLOW_BARGAIN_PATH := "res://data/cards/hollow_bargain.tres"
# Phase 6b: Oaths (two per class; the Stray's come with the Stray).
const QUICK_HANDS_PATH := "res://data/cards/quick_hands.tres"
const LIGHT_STEP_PATH := "res://data/cards/light_step.tres"
const UNBROKEN_VOW_PATH := "res://data/cards/unbroken_vow.tres"
const STANDING_GUARD_PATH := "res://data/cards/standing_guard.tres"
const OPEN_GRAVE_PATH := "res://data/cards/open_grave.tres"
const QUIET_DEBT_PATH := "res://data/cards/quiet_debt.tres"
# The Stray (docs/CLASSES_PLAN.md).
const CATCH_THE_SCENT_PATH := "res://data/cards/catch_the_scent.tres"
const SNAP_PATH := "res://data/cards/snap.tres"
const BRISTLE_PATH := "res://data/cards/bristle.tres"
const RUN_DOWN_PATH := "res://data/cards/run_down.tres"
const WORRY_PATH := "res://data/cards/worry.tres"
const CIRCLE_PATH := "res://data/cards/circle.tres"
const NOSE_TO_THE_WIND_PATH := "res://data/cards/nose_to_the_wind.tres"
const OLD_WOUND_PATH := "res://data/cards/old_wound.tres"
const HOWL_PATH := "res://data/cards/howl.tres"
const POUNCE_PATH := "res://data/cards/pounce.tres"
const SAVAGE_PATH := "res://data/cards/savage.tres"
const BRING_DOWN_PATH := "res://data/cards/bring_down.tres"
const HACKLES_PATH := "res://data/cards/hackles.tres"
const TEAR_LOOSE_PATH := "res://data/cards/tear_loose.tres"
const GO_FERAL_PATH := "res://data/cards/go_feral.tres"
# Neutral pool (cards-1): shared cards for rewards and vendors.
const STEADY_HANDS_PATH := "res://data/cards/steady_hands.tres"
const COUNTER_STEP_PATH := "res://data/cards/counter_step.tres"
const SECOND_LOOK_PATH := "res://data/cards/second_look.tres"
const DOWNPOUR_PATH := "res://data/cards/downpour.tres"
const HOLD_FAST_PATH := "res://data/cards/hold_fast.tres"
const PULL_TOGETHER_PATH := "res://data/cards/pull_together.tres"
const LUCKY_BREAK_PATH := "res://data/cards/lucky_break.tres"
const SHAKE_THEM_PATH := "res://data/cards/shake_them.tres"
# Cards step 3: Oaths on the new triggers and the Thief's discard cards.
const IRON_SKIN_PATH := "res://data/cards/iron_skin.tres"
const BULWARK_VOW_PATH := "res://data/cards/bulwark_vow.tres"
const NICK_AND_RUN_PATH := "res://data/cards/nick_and_run.tres"
const BLOOD_PRICE_PATH := "res://data/cards/blood_price.tres"
const PACK_INSTINCT_PATH := "res://data/cards/pack_instinct.tres"
const LOOSE_CHANGE_PATH := "res://data/cards/loose_change.tres"
const SLIPPED_POCKET_PATH := "res://data/cards/slipped_pocket.tres"
const SPARE_KEY_PATH := "res://data/cards/spare_key.tres"
# Cards step 4: wider class pools.
const CLEAVE_PATH := "res://data/cards/cleave.tres"
const CATCH_BREATH_PATH := "res://data/cards/catch_breath.tres"
const TAUNT_PATH := "res://data/cards/taunt.tres"
const BRACE_FOR_IMPACT_PATH := "res://data/cards/brace_for_impact.tres"
const SHIELD_BASH_PATH := "res://data/cards/shield_bash.tres"
const IRON_WILL_PATH := "res://data/cards/iron_will.tres"
const EARTHSHAKER_PATH := "res://data/cards/earthshaker.tres"
const FORTIFY_PATH := "res://data/cards/fortify.tres"
const PICKPOCKET_PATH := "res://data/cards/pickpocket.tres"
const SHIV_FLURRY_PATH := "res://data/cards/shiv_flurry.tres"
const SMOKE_BOMB_PATH := "res://data/cards/smoke_bomb.tres"
const TRIPWIRE_PATH := "res://data/cards/tripwire.tres"
const SECOND_STORY_PATH := "res://data/cards/second_story.tres"
const VANISH_PATH := "res://data/cards/vanish.tres"
const STEADY_AIM_PATH := "res://data/cards/steady_aim.tres"
const THE_BIG_SCORE_PATH := "res://data/cards/the_big_score.tres"
const WHISPER_CAMPAIGN_PATH := "res://data/cards/whisper_campaign.tres"
const HEX_PATH := "res://data/cards/hex.tres"
const DRAIN_PATH := "res://data/cards/drain.tres"
const MOURNERS_PATH := "res://data/cards/mourners.tres"
const DARK_PACT_PATH := "res://data/cards/dark_pact.tres"
const VEIL_WALK_PATH := "res://data/cards/veil_walk.tres"
const WAIL_PATH := "res://data/cards/wail.tres"
const FRIGHTFUL_VISAGE_PATH := "res://data/cards/frightful_visage.tres"
const LUNGE_PATH := "res://data/cards/lunge.tres"
const GNASH_PATH := "res://data/cards/gnash.tres"
const PROWL_PATH := "res://data/cards/prowl.tres"
const MAUL_PATH := "res://data/cards/maul.tres"
const PACK_HUNT_PATH := "res://data/cards/pack_hunt.tres"
const STALK_PATH := "res://data/cards/stalk.tres"
const CRIPPLE_PATH := "res://data/cards/cripple.tres"
const WILD_HUNT_PATH := "res://data/cards/wild_hunt.tres"
const KEEP_THE_TRAIL_PATH := "res://data/cards/keep_the_trail.tres"
const CINDER_HOUND_PATH := "res://data/enemies/cinder_hound.tres"
const MOURNING_CROW_PATH := "res://data/enemies/mourning_crow.tres"
const WISP_PATH := "res://data/enemies/skittering_wisp.tres"
const COLOSSUS_PATH := "res://data/enemies/hollow_colossus.tres"
const WHISPERER_PATH := "res://data/enemies/pale_whisperer.tres"
## The run's boss. Deliberately not in ALL_ENEMY_PATHS: it only appears via boss_encounter().
const CONDUCTOR_PATH := "res://data/enemies/the_conductor.tres"
## The mid-run boss, halfway down the line. Also not in ALL_ENEMY_PATHS: see mid_boss_encounter().
const BRAKEMAN_PATH := "res://data/enemies/the_brakeman.tres"
const EXTENDED_DECK_SIZE := 14
## The bosses, which only appear through boss_encounter() and mid_boss_encounter().
const BOSS_ENEMY_PATHS: Array[String] = [CONDUCTOR_PATH, BRAKEMAN_PATH]
## Regular enemies that never join a pair or trio (they only appear as a single).
const SOLO_ONLY_ENEMY_PATHS: Array[String] = [COLOSSUS_PATH]
## Every card, in a fixed order. A card's `character` tag says who may take it (empty = everyone).
const ALL_CARD_PATHS: Array[String] = [
	SHOVE_PATH, SLIP_PAST_PATH, GLIMPSE_EXIT_PATH, BRACE_PATH, FLURRY_PATH, SWEEP_PATH,
	HEAVY_BLOW_PATH, STEADY_BREATH_PATH, SHOULDER_CHARGE_PATH, IRON_RESOLVE_PATH, GUARDED_STRIKE_PATH,
	HOLD_THE_LINE_PATH, BASH_PATH, DIG_IN_PATH, COLD_STEEL_PATH, COUNTER_STANCE_PATH, LAST_STAND_PATH,
	LIFT_PATH, SLEIGHT_PATH, POCKET_WATCH_PATH, LAST_POCKET_PATH, SPREE_PATH,
	CONFESS_PATH, LINGERING_DREAD_PATH, COLD_WHISPER_PATH, PENANCE_PATH, GRAVE_CHILL_PATH,
	SPIRIT_TITHE_PATH, SEANCE_PATH, BLEED_THE_VEIL_PATH, RECKONING_PATH,
	MARK_THE_WEAK_PATH, CUTTING_WORD_PATH, HAMSTRING_PATH, SECOND_WIND_PATH,
	# Phase 4b Thief cards.
	SHARPEN_PATH, QUICK_STUDY_PATH, CLEANED_OUT_PATH,
	# Phase 4c (Deserter).
	DIG_DEEP_PATH,
	# Phase 4d: Medium
	REMEMBER_PATH, CHORUS_OF_THE_LOST_PATH, HOLLOW_BARGAIN_PATH,
	# Phase 6b: Oaths
	QUICK_HANDS_PATH, LIGHT_STEP_PATH, UNBROKEN_VOW_PATH, STANDING_GUARD_PATH, OPEN_GRAVE_PATH, QUIET_DEBT_PATH,
	# Neutral pool
	STEADY_HANDS_PATH, COUNTER_STEP_PATH, SECOND_LOOK_PATH, DOWNPOUR_PATH, HOLD_FAST_PATH, PULL_TOGETHER_PATH, LUCKY_BREAK_PATH, SHAKE_THEM_PATH,
	# Cards step 4
	KEEP_THE_TRAIL_PATH,
	CLEAVE_PATH, CATCH_BREATH_PATH, TAUNT_PATH, BRACE_FOR_IMPACT_PATH, SHIELD_BASH_PATH, IRON_WILL_PATH, EARTHSHAKER_PATH, FORTIFY_PATH, PICKPOCKET_PATH, SHIV_FLURRY_PATH, SMOKE_BOMB_PATH, TRIPWIRE_PATH, SECOND_STORY_PATH, VANISH_PATH, STEADY_AIM_PATH, THE_BIG_SCORE_PATH, WHISPER_CAMPAIGN_PATH, HEX_PATH, DRAIN_PATH, MOURNERS_PATH, DARK_PACT_PATH, VEIL_WALK_PATH, WAIL_PATH, FRIGHTFUL_VISAGE_PATH, LUNGE_PATH, GNASH_PATH, PROWL_PATH, MAUL_PATH, PACK_HUNT_PATH, STALK_PATH, CRIPPLE_PATH, WILD_HUNT_PATH,
	# Cards step 3
	IRON_SKIN_PATH, BULWARK_VOW_PATH, NICK_AND_RUN_PATH, BLOOD_PRICE_PATH, PACK_INSTINCT_PATH, LOOSE_CHANGE_PATH, SLIPPED_POCKET_PATH, SPARE_KEY_PATH,
	# The Stray
	CATCH_THE_SCENT_PATH, SNAP_PATH, BRISTLE_PATH, RUN_DOWN_PATH, WORRY_PATH, CIRCLE_PATH, NOSE_TO_THE_WIND_PATH, OLD_WOUND_PATH, HOWL_PATH, POUNCE_PATH, SAVAGE_PATH, BRING_DOWN_PATH, HACKLES_PATH, TEAR_LOOSE_PATH, GO_FERAL_PATH,
]
## Status cards: Dormant cards that enemies add to the player's piles mid-fight (Dread: Dormant; Murmur:
## Dormant and Fading). An explicit id -> path table, kept OUT of ALL_CARD_PATHS, the reward pools,
## vendors and starting decks; data/status is never scanned.
const STATUS_CARD_PATHS := {
	&"dread": "res://data/status/dread.tres",
	&"murmur": "res://data/status/murmur.tres",
}
## Created cards: playable cards that exist only inside a fight, made by other cards (the Thief's Trinket
## comes from Filch). An explicit id -> path table, kept OUT of ALL_CARD_PATHS, the reward pools, vendors,
## the price table and every starting deck; data/created is never scanned. Add a created card by putting
## its .tres in data/created and listing it here, and nowhere else.
const CREATED_CARD_PATHS := {
	&"trinket": "res://data/created/trinket.tres",
}
## Every relic, in a fixed order. A relic's `character` tag says who may be offered it (empty = everyone).
const RELIC_PATHS: Array[String] = [
	"res://data/relics/travelling_flask.tres", "res://data/relics/brass_token_purse.tres", "res://data/relics/ticket_stub_charm.tres",
	"res://data/relics/regulation_dog_tags.tres", "res://data/relics/barbed_greatcoat.tres", "res://data/relics/field_ration_tin.tres",
	"res://data/relics/silk_gloves.tres", "res://data/relics/skeleton_key.tres", "res://data/relics/marked_deck.tres",
	"res://data/relics/grave_dirt.tres", "res://data/relics/planchette.tres", "res://data/relics/bone_rosary.tres",
	"res://data/relics/cracked_lorgnette.tres", "res://data/relics/hushing_veil.tres", "res://data/relics/mourners_armband.tres",
	"res://data/relics/iron_stakes.tres", "res://data/relics/pressed_flower.tres", "res://data/relics/candle_stub.tres",
	"res://data/relics/hunters_whistle.tres", "res://data/relics/wolf_fang.tres", "res://data/relics/bloody_muzzle.tres",
]
## Playable characters, in the order a selection screen lists them.
const CHARACTER_PATHS := {
	&"deserter": "res://data/characters/deserter.tres",
	&"thief": "res://data/characters/thief.tres",
	&"medium": "res://data/characters/medium.tres",
	&"stray": "res://data/characters/stray.tres",
}
const DEFAULT_CHARACTER_ID := &"deserter"
## The regular enemy types in a fixed order (the boss is separate, see CONDUCTOR_PATH): warden,
## lost shade, wisp, colossus, whisperer, cinder hound, mourning crow. The colossus is a solo-only
## elite (it was unwinnable next to a second enemy in the balance sim); the
## warden can share a pair; small enemies are what packs are made of.
const ALL_ENEMY_PATHS: Array[String] = [WARDEN_PATH, LOST_SHADE_PATH, WISP_PATH, COLOSSUS_PATH, WHISPERER_PATH, CINDER_HOUND_PATH, MOURNING_CROW_PATH]
const PAIR_BIG_ENEMY_PATHS: Array[String] = [WARDEN_PATH]
const SMALL_ENEMY_PATHS: Array[String] = [LOST_SHADE_PATH, WISP_PATH, WHISPERER_PATH, CINDER_HOUND_PATH, MOURNING_CROW_PATH]
## Chance that a two-enemy encounter is a big plus a small enemy rather than two small ones.
const BIG_PAIR_CHANCE := 0.15
## Trios leave out the Lost Shade (the sturdiest small enemy): three of them out-damaged the
## run mid-line, and the fragile wisps and whisperers keep a three-way fight winnable.
const TRIO_EXCLUDED_PATHS: Array[String] = [LOST_SHADE_PATH]
## Stat ramp: a regular fight's enemies get max HP and attack damage multiplied by
## 1 + RAMP_PER_FIGHT * fight, where `fight` is the 0-based number of the regular fight on the line
## (bosses are hand-tuned and never ramped). Block and statuses are not scaled.
const RAMP_PER_FIGHT := 0.012
## Tier 1 (after the mid-boss) leans on the bigger enemies: a bigger chance of a big-plus-small pair
## (the stop line has no single-enemy fight after the mid-boss, so singles use one pool at every tier).
const TIER1_BIG_PAIR_CHANCE := 0.2


## The neutral 10-card deck (5 Shove, 4 Slip Past, 1 Glimpse the Exit) for standalone battles and tests with
## no character; runs use starter_deck(character_id).
## Card definitions are immutable data, so deck slots of the same card share one instance.
## Returns an empty deck (and logs the cause) if any card resource fails to load.
static func deck() -> Array[CardData]:
	var cards: Array[CardData] = []
	var shove := _load_card(SHOVE_PATH)
	var slip_past := _load_card(SLIP_PAST_PATH)
	var glimpse_exit := _load_card(GLIMPSE_EXIT_PATH)
	if shove == null or slip_past == null or glimpse_exit == null:
		return cards
	for i in 5:
		cards.append(shove)
	for i in 4:
		cards.append(slip_past)
	cards.append(glimpse_exit)
	return cards


## The deck a run of this character starts with: a fresh array of the shared card instances from the
## character's resource (data/characters), which owns the composition.
## An id with no character falls back to deck(), the neutral deck; that is for standalone battles and tests
## that have no character, and runs always pass a real character id.
static func starter_deck(character_id: StringName) -> Array[CardData]:
	if not CHARACTER_PATHS.has(character_id):
		return deck()
	var loaded := character(character_id)
	if loaded == null or loaded.starting_deck.is_empty():
		return deck()
	var cards: Array[CardData] = []
	cards.assign(loaded.starting_deck)
	return cards


## Balance-testing deck of EXTENDED_DECK_SIZE (14) cards: 3 Shove, 2 Slip Past,
## 1 Glimpse the Exit, 1 Heavy Blow, 1 Brace, 1 Steady Breath, 1 Shoulder Charge,
## 1 Find the Seam, 1 Sweep, 1 Cutting Word, 1 Borrowed Breath.
## Returns an empty deck (and logs the cause) if any card resource fails to load.
static func extended_deck() -> Array[CardData]:
	var cards: Array[CardData] = []
	var plan: Array = [
		[SHOVE_PATH, 3], [SLIP_PAST_PATH, 2], [GLIMPSE_EXIT_PATH, 1],
		[HEAVY_BLOW_PATH, 1], [BRACE_PATH, 1], [STEADY_BREATH_PATH, 1], [SHOULDER_CHARGE_PATH, 1],
		[MARK_THE_WEAK_PATH, 1], [SWEEP_PATH, 1], [CUTTING_WORD_PATH, 1], [SECOND_WIND_PATH, 1],
	]
	for entry in plan:
		var card := _load_card(entry[0] as String)
		if card == null:
			var empty: Array[CardData] = []
			return empty
		for i in (entry[1] as int):
			cards.append(card)
	return cards


## Every card that loads, in ALL_CARD_PATHS order. Empty (cause logged) if any fails to load.
static func all_cards() -> Array[CardData]:
	var cards: Array[CardData] = []
	for path in ALL_CARD_PATHS:
		var card := _load_card(path)
		if card == null:
			var empty: Array[CardData] = []
			return empty
		cards.append(card)
	return cards


## The distinct cards a character can be offered as rewards: every neutral card plus the cards tagged for
## `character_id`, except the basic cards (Shove, Slip Past), which they start with and can buy but are never
## offered. Empty (cause logged) if any card fails to load.
static func reward_pool(character_id: StringName) -> Array[CardData]:
	var pool: Array[CardData] = []
	for card in all_cards():
		if (card.character == &"" or card.character == character_id) and not card.basic:
			pool.append(card)
	return pool


## Odds (Common, Uncommon, Rare, in percent) of each card slot in a reward or vendor stock, by how far into the
## run it is: four tiers, from the first quarter of the stop line to the last.
const RARITY_WEIGHTS: Array[Array] = [[70, 27, 3], [62, 32, 6], [52, 38, 10], [42, 42, 16]]


## The weights for `tier` (clamped to the table).
static func rarity_weights(tier: int) -> Array[int]:
	var row: Array = RARITY_WEIGHTS[clampi(tier, 0, RARITY_WEIGHTS.size() - 1)]
	var weights: Array[int] = []
	weights.assign(row)
	return weights


## Picks up to `count` distinct cards from `pool`, one at a time: roll a rarity from `weights` (only among the
## rarities that still have a card), then a random card of that rarity. Uses `rng`, so a seed repeats the picks.
## The pool is not changed. Fewer than `count` come back only when the pool is smaller.
static func pick_by_rarity(pool: Array[CardData], count: int, weights: Array[int], rng: RandomNumberGenerator) -> Array[CardData]:
	var left: Array[CardData] = pool.duplicate()
	var picks: Array[CardData] = []
	while picks.size() < count and not left.is_empty():
		var total := 0
		for rarity in 3:
			if _has_rarity(left, rarity):
				total += maxi(weights[rarity], 1)
		var roll := rng.randi_range(0, total - 1)
		var chosen := CardData.Rarity.COMMON
		for rarity in 3:
			if not _has_rarity(left, rarity):
				continue
			var share := maxi(weights[rarity], 1)
			if roll < share:
				chosen = rarity as CardData.Rarity
				break
			roll -= share
		var of_rarity: Array[CardData] = []
		for card in left:
			if card.rarity == chosen:
				of_rarity.append(card)
		var card: CardData = of_rarity[rng.randi_range(0, of_rarity.size() - 1)]
		picks.append(card)
		left.erase(card)
	return picks


static func _has_rarity(cards: Array[CardData], rarity: int) -> bool:
	for card in cards:
		if card.rarity == rarity:
			return true
	return false


## The cards a vendor may stock for `character_id`: the reward pool plus the basic cards.
static func vendor_pool(character_id: StringName) -> Array[CardData]:
	var pool: Array[CardData] = []
	for card in all_cards():
		if card.character == &"" or card.character == character_id:
			pool.append(card)
	return pool


## Every relic that loads, in RELIC_PATHS order. Empty (cause logged) if any fails to load.
static func all_relics() -> Array[RelicData]:
	var relics: Array[RelicData] = []
	for path in RELIC_PATHS:
		var relic: RelicData = null
		if ResourceLoader.exists(path):
			relic = load(path) as RelicData
		if relic == null:
			push_error("StarterContent: missing or non-RelicData resource: %s" % path)
			var empty: Array[RelicData] = []
			return empty
		relics.append(relic)
	return relics


## The relics a vendor may offer `character_id`: every neutral relic plus the ones tagged for them.
static func relic_pool(character_id: StringName) -> Array[RelicData]:
	var pool: Array[RelicData] = []
	for relic in all_relics():
		if relic.character == &"" or relic.character == character_id:
			pool.append(relic)
	return pool


static func character_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id in CHARACTER_PATHS:
		ids.append(id)
	return ids


## The character with this id, or null (cause logged) for an unknown id or a resource that fails to load.
static func character(character_id: StringName) -> Character:
	if not CHARACTER_PATHS.has(character_id):
		push_error("StarterContent.character: unknown character '%s'" % character_id)
		return null
	var path: String = CHARACTER_PATHS[character_id]
	var loaded: Character = null
	if ResourceLoader.exists(path):
		loaded = load(path) as Character
	if loaded == null:
		push_error("StarterContent: missing or non-Character resource: %s" % path)
	return loaded


static func warden() -> EnemyData:
	return _load_enemy(WARDEN_PATH)


static func lost_shade() -> EnemyData:
	return _load_enemy(LOST_SHADE_PATH)


## An early-run encounter with `enemy_count` enemies (clamped to 1..MAX_ENEMIES).
## Enemies whose resource fails to load are left out (the cause is logged), so
## the result can be empty; Combat requires at least one enemy.
static func early_encounter(enemy_count: int) -> Array[EnemyData]:
	var count := clampi(enemy_count, 1, Combat.MAX_ENEMIES)
	var enemies: Array[EnemyData] = []
	for i in count:
		var enemy := warden() if count == 1 else lost_shade()
		if enemy != null:
			enemies.append(enemy)
	return enemies


## All enemy types in a fixed order: warden, lost shade, wisp, colossus, whisperer, cinder hound, mourning crow.
## Enemies that fail to load are left out (the cause is logged).
static func enemy_pool() -> Array[EnemyData]:
	var pool: Array[EnemyData] = []
	for path in ALL_ENEMY_PATHS:
		var enemy := _load_enemy(path)
		if enemy != null:
			pool.append(enemy)
	return pool


## An encounter of `enemy_count` (clamped to 1..MAX_ENEMIES) enemies, chosen
## with `rng` so a seeded rng reproduces it. Composition keeps danger roughly
## level as the count grows: a lone enemy can be any type, a pair is either the
## warden plus a small enemy or two small ones, and a trio is all small enemies.
## Enemies whose resource fails to load are left out (the cause is logged), so
## the result can be smaller than requested or empty.
##
## `tier` (0 = before the mid-boss, 1 = after) picks the pools (see TIER1_*), and `fight` is the
## regular fight's 0-based number, which sets the stat ramp (see RAMP_PER_FIGHT). The defaults give
## the unramped tier 0 encounter; tier and fight draw nothing extra from `rng`.
static func varied_encounter(enemy_count: int, rng: RandomNumberGenerator, tier: int = 0, fight: int = 0) -> Array[EnemyData]:
	var count := clampi(enemy_count, 1, Combat.MAX_ENEMIES)
	var paths: Array[String] = []
	var big_pair_chance := TIER1_BIG_PAIR_CHANCE if tier >= 1 else BIG_PAIR_CHANCE
	match count:
		1:
			paths.append(_pick_path(ALL_ENEMY_PATHS, rng))
		2:
			if rng.randf() < big_pair_chance:
				paths.append(_pick_path(PAIR_BIG_ENEMY_PATHS, rng))
				paths.append(_pick_path(SMALL_ENEMY_PATHS, rng))
			else:
				paths.append(_pick_path(SMALL_ENEMY_PATHS, rng))
				paths.append(_pick_path(SMALL_ENEMY_PATHS, rng))
		_:
			for i in count:
				paths.append(_pick_path(_trio_paths(), rng))
	var factor := ramp_factor(fight)
	var enemies: Array[EnemyData] = []
	for path in paths:
		var enemy := _load_enemy(path)
		if enemy != null:
			enemies.append(scaled(enemy, factor))
	return enemies


## The stat multiplier for the regular fight numbered `fight` (0-based; below 0 counts as 0).
static func ramp_factor(fight: int) -> float:
	return 1.0 + RAMP_PER_FIGHT * maxi(fight, 0)


## `enemy` with max HP and DAMAGE intents scaled by `factor` (rounded, never below 1). Returns a new
## EnemyData with new intents, so the shared resource is never touched; factor 1.0 returns `enemy` itself.
static func scaled(enemy: EnemyData, factor: float) -> EnemyData:
	if is_equal_approx(factor, 1.0):
		return enemy
	var intents: Array[CardEffect] = []
	for intent in enemy.intents:
		if intent.kind == CardEffect.Kind.DAMAGE:
			intents.append(CardEffect.make(intent.kind, maxi(roundi(intent.amount * factor), 1), intent.bonus, intent.threshold, intent.hits))
		else:
			intents.append(intent)
	return EnemyData.make(enemy.display_name, maxi(roundi(enemy.max_hp * factor), 1), intents, enemy.id, enemy.max_haunt)


## SMALL_ENEMY_PATHS minus TRIO_EXCLUDED_PATHS, so a new small enemy joins trios by default.
static func _trio_paths() -> Array[String]:
	var paths: Array[String] = []
	for path in SMALL_ENEMY_PATHS:
		if not TRIO_EXCLUDED_PATHS.has(path):
			paths.append(path)
	return paths


## The boss fight: the Conductor alone. Empty (cause logged) if it fails to load,
## and Combat needs at least one enemy, so callers must check.
static func boss_encounter() -> Array[EnemyData]:
	var enemies: Array[EnemyData] = []
	var boss := _load_enemy(CONDUCTOR_PATH)
	if boss != null:
		enemies.append(boss)
	return enemies


## The mid-run boss fight: the Brakeman alone. Empty (cause logged) if it fails to load.
static func mid_boss_encounter() -> Array[EnemyData]:
	var enemies: Array[EnemyData] = []
	var boss := _load_enemy(BRAKEMAN_PATH)
	if boss != null:
		enemies.append(boss)
	return enemies


static func _pick_path(paths: Array[String], rng: RandomNumberGenerator) -> String:
	return paths[rng.randi_range(0, paths.size() - 1)]


## Returns null (after logging an error) if the resource is missing or not a
## CardData. Checked explicitly rather than with assert so debug and release
## builds behave the same.
## A status card by id (`dread` or `murmur`), or null (cause logged) for an unknown id or a bad resource.
static func status_card(id: StringName) -> CardData:
	if not STATUS_CARD_PATHS.has(id):
		push_error("StarterContent.status_card: unknown status card id %s" % id)
		return null
	return _load_card(STATUS_CARD_PATHS[id])


## A created card by id, or null (cause logged) for an unknown id or a bad resource.
static func created_card(id: StringName) -> CardData:
	if not CREATED_CARD_PATHS.has(id):
		push_error("StarterContent.created_card: unknown created card id %s" % id)
		return null
	return _load_card(CREATED_CARD_PATHS[id])


static func _load_card(path: String) -> CardData:
	var card: CardData = null
	if ResourceLoader.exists(path):
		card = load(path) as CardData
	if card == null:
		push_error("StarterContent: missing or non-CardData resource: %s" % path)
	return card


## Enemies are deep-copied so each encounter slot owns its data, as before.
## Returns null (after logging an error) if the resource is missing or not an EnemyData.
static func _load_enemy(path: String) -> EnemyData:
	var template: EnemyData = null
	if ResourceLoader.exists(path):
		template = load(path) as EnemyData
	if template == null:
		push_error("StarterContent: missing or non-EnemyData resource: %s" % path)
		return null
	return template.duplicate(true) as EnemyData


## Every enemy, regular and boss, by EnemyData id (debug launch and tools; encounters use the path lists).
static func enemy_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for path in ALL_ENEMY_PATHS + BOSS_ENEMY_PATHS:
		var template := load(path) as EnemyData
		if template != null:
			ids.append(template.id)
	return ids


## A fresh copy of the enemy with this id (regular or boss), or null if there is none.
static func enemy_by_id(enemy_id: StringName) -> EnemyData:
	for path in ALL_ENEMY_PATHS + BOSS_ENEMY_PATHS:
		var template := load(path) as EnemyData
		if template != null and template.id == enemy_id:
			return template.duplicate(true) as EnemyData
	return null
