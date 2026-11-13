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
## Chapter 2 (docs/CHAPTER2_PLAN.md): the Registry's enemies, kept apart from Chapter 1's registry above so Chapter 1 never draws them.
## Names are proposals until the owner confirms them. The Misfiled is Unseen; the bosses are the Archivist (mid) and the Registrar (end).
const LEDGER_CLERK_PATH := "res://data/enemies/chapter2/ledger_clerk.tres"
const DROWNED_PORTER_PATH := "res://data/enemies/chapter2/drowned_porter.tres"
const SHELF_WRAITH_PATH := "res://data/enemies/chapter2/shelf_wraith.tres"
const INDEX_MOTH_PATH := "res://data/enemies/chapter2/index_moth.tres"
const MISFILED_PATH := "res://data/enemies/chapter2/the_misfiled.tres"
const PRESSING_HAND_PATH := "res://data/enemies/chapter2/pressing_hand.tres"
const COPYIST_PATH := "res://data/enemies/chapter2/copyist.tres"
const ARCHIVIST_PATH := "res://data/enemies/chapter2/the_archivist.tres"
const REGISTRAR_PATH := "res://data/enemies/chapter2/the_registrar.tres"
const CHAPTER2_ENEMY_PATHS: Array[String] = [LEDGER_CLERK_PATH, DROWNED_PORTER_PATH, SHELF_WRAITH_PATH, INDEX_MOTH_PATH, MISFILED_PATH, PRESSING_HAND_PATH, COPYIST_PATH]
const CHAPTER2_BIG_PATHS: Array[String] = [DROWNED_PORTER_PATH]
const CHAPTER2_SMALL_PATHS: Array[String] = [LEDGER_CLERK_PATH, SHELF_WRAITH_PATH, INDEX_MOTH_PATH, MISFILED_PATH, PRESSING_HAND_PATH, COPYIST_PATH]
## Left out of trios as Chapter 1's Lost Shade is: the sturdy small enemies. None yet; set from the sims.
const CHAPTER2_TRIO_EXCLUDED_PATHS: Array[String] = []
const CHAPTER2_BOSS_PATHS: Array[String] = [ARCHIVIST_PATH, REGISTRAR_PATH]
## Chapter 3's finale boss (docs/CHAPTER3_PLAN.md): a STUB for now. It is not in an encounter pool; only finale_encounter() builds it.
const SCRIVENER_PATH := "res://data/enemies/chapter3/the_scrivener.tres"
const CHAPTER3_BOSS_PATHS: Array[String] = [SCRIVENER_PATH]
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
	# Chapter 2 (docs/CHAPTER2_PLAN.md): six cards per class, offered from Chapter 2 on (CardData.from_chapter = 2).
	"res://data/cards/chapter2/wall_of_orders.tres",
	"res://data/cards/chapter2/standing_order.tres",
	"res://data/cards/chapter2/hold_the_archive.tres",
	"res://data/cards/chapter2/brace_and_breathe.tres",
	"res://data/cards/chapter2/siege_stance.tres",
	"res://data/cards/chapter2/veterans_resolve.tres",
	"res://data/cards/chapter2/ledger_slip.tres",
	"res://data/cards/chapter2/cut_and_run.tres",
	"res://data/cards/chapter2/filing_error.tres",
	"res://data/cards/chapter2/back_door.tres",
	"res://data/cards/chapter2/master_key.tres",
	"res://data/cards/chapter2/grand_heist.tres",
	"res://data/cards/chapter2/ink_in_the_margin.tres",
	"res://data/cards/chapter2/dead_weight.tres",
	"res://data/cards/chapter2/reading_aloud.tres",
	"res://data/cards/chapter2/dead_letters.tres",
	"res://data/cards/chapter2/every_name.tres",
	"res://data/cards/chapter2/the_long_wake.tres",
	"res://data/cards/chapter2/nose_through_paper.tres",
	"res://data/cards/chapter2/bared_teeth.tres",
	"res://data/cards/chapter2/bloodhound.tres",
	"res://data/cards/chapter2/savage_shake.tres",
	"res://data/cards/chapter2/pack_leader.tres",
	"res://data/cards/chapter2/final_rush.tres",
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
	# Chapter 2: three neutral relics and one per class (RelicData.from_chapter = 2).
	"res://data/relics/chapter2/brass_reading_lamp.tres",
	"res://data/relics/chapter2/waterproof_satchel.tres",
	"res://data/relics/chapter2/clerks_seal.tres",
	"res://data/relics/chapter2/stamped_orders.tres",
	"res://data/relics/chapter2/forged_pass.tres",
	"res://data/relics/chapter2/tide_mark.tres",
	"res://data/relics/chapter2/dust_of_the_stacks.tres",
]
## Every event of the "?" stops (docs/EVENTS_DESIGN.md), in a fixed order. Add an event by putting its .tres in data/events
## and listing it here (a test fails for a file that is not listed).
const EVENT_PATHS: Array[String] = [
	"res://data/events/rain_barrel.tres", "res://data/events/scraped_plaques.tres", "res://data/events/stopped_kitchen.tres",
	"res://data/events/bell_in_the_well.tres", "res://data/events/unsent_letters.tres", "res://data/events/hound_at_the_fence.tres",
	"res://data/events/window_that_is_lit.tres", "res://data/events/empty_sentry_box.tres", "res://data/events/quiet_choir.tres",
	"res://data/events/name_broker.tres", "res://data/events/cracked_bell.tres", "res://data/events/erasers_chalk.tres",
]
## The events of a chapter other than the first, by chapter number (docs/CHAPTER2_PLAN.md). A chapter without an entry plays
## Chapter 1's events (EVENT_PATHS). Their .tres files live in data/events/chapter<N>/.
const CHAPTER_EVENT_PATHS := {
	2: [
		"res://data/events/chapter2/card_catalogue.tres",
		"res://data/events/chapter2/drowned_lamp.tres",
		"res://data/events/chapter2/the_form.tres",
		"res://data/events/chapter2/clerk_who_trades.tres",
		"res://data/events/chapter2/flooded_aisle.tres",
		"res://data/events/chapter2/misdelivered_letter.tres",
		"res://data/events/chapter2/the_stamp.tres",
		"res://data/events/chapter2/silent_patron.tres",
		"res://data/events/chapter2/overdue_notice.tres",
		"res://data/events/chapter2/back_stacks.tres",
	],
}
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


## Rarity odds per run tier; the table lives in RarityPicker.
const RARITY_WEIGHTS: Array[Array] = RarityPicker.RARITY_WEIGHTS


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


## Every event that loads, in EVENT_PATHS order (cached). Empty (cause logged) if any fails to load.
static func all_events() -> Array[EventData]:
	return ContentRegistry.all_events()


## The events a "?" stop of chapter `chapter` draws from: that chapter's own list when it has one, else Chapter 1's.
static func events_for(chapter: int) -> Array[EventData]:
	return ContentRegistry.events_for(chapter)


## Every event of every chapter (what a save's seen-list and the bounds on max HP are checked against).
static func every_event() -> Array[EventData]:
	return ContentRegistry.every_event()


## A card of the normal pools (not a status or created card) by id, or null when there is none.
static func card_by_id(card_id: StringName) -> CardData:
	for card in all_cards():
		if card.id == card_id:
			return card
	return null


## Returns null (after logging an error) if the resource is missing or not an EventData.
static func _load_event(path: String) -> EventData:
	return ContentRegistry.load_event(path)


static func character_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id in CHARACTER_PATHS:
		ids.append(id)
	return ids


static func warden() -> EnemyData:
	return _load_enemy(WARDEN_PATH)


static func lost_shade() -> EnemyData:
	return _load_enemy(LOST_SHADE_PATH)


## Drops every cached list so the next call rebuilds it from the resources.
static func clear_cache() -> void:
	return ContentRegistry.clear_cache()


## Every card that loads, in ALL_CARD_PATHS order. Empty (cause logged) if any fails to load.
static func all_cards() -> Array[CardData]:
	return ContentRegistry.all_cards()


## The distinct cards a character can be offered as rewards: every neutral card plus the cards tagged for
## `character_id`, except the basic cards (Shove, Slip Past), which they start with and can buy but are never
## offered. Empty (cause logged) if any card fails to load.
static func reward_pool(character_id: StringName, chapter: int = ContentRegistry.ALL_CHAPTERS) -> Array[CardData]:
	return ContentRegistry.reward_pool(character_id, chapter)


## The cards a vendor may stock for `character_id`: the reward pool plus the basic cards.
static func vendor_pool(character_id: StringName, chapter: int = ContentRegistry.ALL_CHAPTERS) -> Array[CardData]:
	return ContentRegistry.vendor_pool(character_id, chapter)


## Every relic that loads, in RELIC_PATHS order. Empty (cause logged) if any fails to load.
static func all_relics() -> Array[RelicData]:
	return ContentRegistry.all_relics()


## The relics a vendor may offer `character_id`: every neutral relic plus the ones tagged for them.
static func relic_pool(character_id: StringName, chapter: int = ContentRegistry.ALL_CHAPTERS) -> Array[RelicData]:
	return ContentRegistry.relic_pool(character_id, chapter)


## The character with this id, or null (cause logged) for an unknown id or a resource that fails to load.
static func character(character_id: StringName) -> Character:
	return ContentRegistry.character(character_id)


## A status card by id (`dread` or `murmur`), or null (cause logged) for an unknown id or a bad resource.
static func status_card(id: StringName) -> CardData:
	return ContentRegistry.status_card(id)


## A created card by id, or null (cause logged) for an unknown id or a bad resource.
static func created_card(id: StringName) -> CardData:
	return ContentRegistry.created_card(id)


static func _load_card(path: String) -> CardData:
	return ContentRegistry.load_card(path)


## Enemies are deep-copied so each encounter slot owns its data, as before.
## Returns null (after logging an error) if the resource is missing or not an EnemyData.
static func _load_enemy(path: String) -> EnemyData:
	return ContentRegistry.load_enemy(path)


## Every enemy, regular and boss, by EnemyData id (debug launch and tools; encounters use the path lists).
static func enemy_ids() -> Array[StringName]:
	return ContentRegistry.enemy_ids()


## A fresh copy of the enemy with this id (regular or boss), or null if there is none.
static func enemy_by_id(enemy_id: StringName) -> EnemyData:
	return ContentRegistry.enemy_by_id(enemy_id)


## The weights for `tier` (clamped to the table).
static func rarity_weights(tier: int) -> Array[int]:
	return RarityPicker.rarity_weights(tier)


## Picks up to `count` distinct cards from `pool`, one at a time: roll a rarity from `weights` (only among the
## rarities that still have a card), then a random card of that rarity. Uses `rng`, so a seed repeats the picks.
## The pool is not changed. Fewer than `count` come back only when the pool is smaller.
static func pick_by_rarity(pool: Array[CardData], count: int, weights: Array[int], rng: RandomNumberGenerator) -> Array[CardData]:
	return RarityPicker.pick_by_rarity(pool, count, weights, rng)


## An early-run encounter with `enemy_count` enemies (clamped to 1..MAX_ENEMIES).
## Enemies whose resource fails to load are left out (the cause is logged), so
## the result can be empty; Combat requires at least one enemy.
static func early_encounter(enemy_count: int) -> Array[EnemyData]:
	return Encounters.early_encounter(enemy_count)


## All enemy types in a fixed order: warden, lost shade, wisp, colossus, whisperer, cinder hound, mourning crow.
## Enemies that fail to load are left out (the cause is logged).
static func enemy_pool() -> Array[EnemyData]:
	return Encounters.enemy_pool()


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
	return Encounters.varied_encounter(enemy_count, rng, tier, fight)


# ---- Threat measure and map-mode budget (docs/MAP_DESIGN.md, "Phase 4d") ----

## Threat measure: the player's reference damage output per turn. An enemy that lives HP / THREAT_REF_DPS turns
## and deals D per turn costs about D * HP / THREAT_REF_DPS of the player's HP, so threat reads as "HP lost to
## this enemy alone" for a typical hand.
const THREAT_REF_DPS := 10.0
## Damage-equivalent points one unit of `amount` of a non-damage enemy intent adds to the intent cycle
## (EXPOSE, SHAKEN and FRAYED amounts are turns, MALICE stacks, ADD_CARD cards). Kinds missing here (Block, Draw and
## the rest) add nothing: the regular enemies only use the five below, and a boss is never budgeted.
const THREAT_STATUS_POINTS := {
	CardEffect.Kind.EXPOSE: 5.0,
	CardEffect.Kind.SHAKEN: 2.0,
	CardEffect.Kind.FRAYED: 2.0,
	CardEffect.Kind.MALICE: 3.0,
	CardEffect.Kind.ADD_CARD: 3.0,
	CardEffect.Kind.FILE: 3.0,
}
## Map mode budget curve. A regular fight on run row `row` (0 to RouteMap.ROWS - 1) gets a total pack threat of
## MAP_DIFFICULTY * lerp(start, end, local), where `local` runs 0 to 1 over the act's rows 0 to 14. Index 0 is
## act 1 (rows 0 to 14), index 1 act 2 (rows 15 to 29), so the curve rises smoothly inside an act and jumps at
## the act change like the line's second-act pools. The numbers are a straight-line fit of the line's average pack
## threat per regular fight number (fights 0 to 3 are act 1, 4 to 7 act 2; measured by tools/threat_table.gd).
## MAP_DIFFICULTY is the one knob for the overall difficulty of map fights.
const BUDGET_ACT_START: Array[float] = Chapters.CHAPTER_1_BUDGET_START
const BUDGET_ACT_END: Array[float] = Chapters.CHAPTER_1_BUDGET_END
const MAP_DIFFICULTY := 1.9
## Map mode only: each character's own multiplier on the budget (on top of MAP_DIFFICULTY), because the four
## characters are not equally robust (Stray has the fewest HP). A character that is not listed uses 1.0.
const MAP_CLASS_DIFFICULTY := {&"deserter": 1.03, &"thief": 1.04, &"medium": 1.02, &"stray": 0.9}
## The pack builder multiplies every enemy of a pack by the same HP factor and the same damage factor; each of the
## two stays inside these bounds.
const PACK_SCALE_MIN := 0.6
const PACK_SCALE_MAX := 1.8
## How the builder splits a pack's total multiplier m (HP factor * damage factor, which is what threat follows)
## between HP and damage, by enemy count (index 0 = a single): HP factor = m^share, damage factor = m^(1 - share).
## A lone enemy takes most of it as HP, so a wisp pushed up to a pair's danger gets longer lived and not a
## hit of 28; a trio splits evenly.
const PACK_HP_SHARE: Array[float] = [0.65, 0.55, 0.5]
## How many packs the builder draws (re-picking when a pack cannot meet the budget inside the bounds) before it
## settles for the closest legal one.
const PACK_MAX_ATTEMPTS := 24
## An elite fight has at least this many enemies.
const ELITE_MIN_ENEMIES := 2
## The prefix of an elite enemy's display name ("Elite Gate Warden"); the id, and so the art, stay the same.
const ELITE_NAME_PREFIX := "Elite "


## One enemy's threat: its average damage per turn over its intent cycle (damage intents count amount * hits,
## the statuses in THREAT_STATUS_POINTS their points) times its max HP over THREAT_REF_DPS. Deterministic; a
## second phase is ignored (only bosses have one and they are never budgeted). 0 for an enemy with no intents.
static func enemy_threat(enemy: EnemyData) -> float:
	return _turn_damage(enemy) * float(enemy.max_hp) / THREAT_REF_DPS


## Average damage-equivalent per turn over the enemy's intent cycle.
static func _turn_damage(enemy: EnemyData) -> float:
	if enemy.intents.is_empty():
		return 0.0
	var total := 0.0
	for intent in enemy.intents:
		if intent.kind == CardEffect.Kind.DAMAGE:
			total += float(intent.amount * maxi(intent.hits, 1))
		else:
			total += float(THREAT_STATUS_POINTS.get(intent.kind, 0.0)) * float(intent.amount)
	return total / float(enemy.intents.size())


## A pack's threat: the damage the player takes while killing it one enemy at a time, in the best order (most
## damage per HP first). Each enemy deals its per-turn damage until it dies, so the sum is
## damage_i * (HP of everything killed up to and including i) / THREAT_REF_DPS. One enemy gives its
## enemy_threat; a pair or trio is worth more than the sum of its members because the survivors keep hitting.
static func pack_threat(enemies: Array[EnemyData]) -> float:
	var order: Array[EnemyData] = enemies.duplicate()
	order.sort_custom(func(a: EnemyData, b: EnemyData) -> bool:
		return _turn_damage(a) * float(b.max_hp) > _turn_damage(b) * float(a.max_hp))
	var hp_so_far := 0.0
	var total := 0.0
	for enemy in order:
		hp_so_far += float(enemy.max_hp)
		total += _turn_damage(enemy) * hp_so_far
	return total / THREAT_REF_DPS


## The budget (target pack threat) of a regular fight on row `row` of chapter `chapter` (row clamped to 0..29): see
## ChapterData.budget_start. BUDGET_ACT_START and BUDGET_ACT_END are Chapter 1's curve.
static func fight_budget(row: int, chapter: int = 1) -> float:
	var data := Chapters.chapter(chapter)
	var r := clampi(row, 0, RouteMap.ROWS - 1)
	# An act past the end of the curve arrays reuses the last entry rather than indexing out of range.
	var act := mini(r / RouteMap.ACT_ROWS, mini(data.budget_start.size(), data.budget_end.size()) - 1)
	var local := float(r % RouteMap.ACT_ROWS) / float(RouteMap.ACT_ROWS - 1)
	return MAP_DIFFICULTY * lerpf(data.budget_start[act], data.budget_end[act], local)


## The map-mode budget multiplier of character `character_id` (see MAP_CLASS_DIFFICULTY).
static func map_class_difficulty(character_id: StringName, chapter: int = 1) -> float:
	return float(MAP_CLASS_DIFFICULTY.get(character_id, 1.0)) * float(Chapters.chapter(chapter).class_difficulty.get(character_id, 1.0))


## What the last `budget_encounter` call did, for the measuring tool and tests: `scale` (the total multiplier m),
## `hp_scale` and `damage_scale` (its two parts), `target` (the budget aimed at), `threat` (the pack's threat),
## `bound_hit` (even the closest legal pack missed the budget because of the bounds), `attempts` (packs drawn) and
## `fallback` (every pool enemy failed to load and the pack was built from a known enemy). Every key is always set.
## Not game state; overwritten by every call.
static var last_pack_info := {}


## A pack of `count` enemies (1 to MAX_ENEMIES; an `elite` fight has at least ELITE_MIN_ENEMIES) for a map fight
## on run row `row`, whose total pack_threat equals fight_budget(row) * budget_multiplier within rounding. The
## enemies come from the same pools as varied_encounter (a single from any regular enemy, a pair a big plus a
## small or two small ones, a trio small enemies without the excluded ones; the act picks the big-pair
## chance) and are then scaled together: one HP factor and one damage factor for every enemy (max HP and DAMAGE
## intents; see PACK_HP_SHARE), found by bisection on the real rounded numbers. A factor outside
## PACK_SCALE_MIN..PACK_SCALE_MAX is never used: when the bounds stop a pack reaching the budget a new one is
## drawn from `rng` (up to PACK_MAX_ATTEMPTS); if none fits, the legal pack closest to the budget is used. Only `rng` is consumed, so the same seed, row and count give the same pack.
## Shared resources are never changed (enemies are copies and scaled() makes new ones). Enemies that fail to load
## are left out (cause logged); if none of a pack loads it falls back to a known enemy, so the pack is never empty.
static func budget_encounter(count: int, rng: RandomNumberGenerator, row: int, budget_multiplier: float = 1.0, elite: bool = false, chapter: int = 1) -> Array[EnemyData]:
	var n := clampi(count, ELITE_MIN_ENEMIES if elite else 1, Combat.MAX_ENEMIES)
	var target := fight_budget(row, chapter) * budget_multiplier
	var big_pair_chance := TIER1_BIG_PAIR_CHANCE if row >= RouteMap.ACT_ROWS else BIG_PAIR_CHANCE
	var best: Array[EnemyData] = []
	var best_miss := INF
	var best_info := {}
	for attempt in PACK_MAX_ATTEMPTS:
		var base: Array[EnemyData] = []
		for path in _pack_paths(n, rng, big_pair_chance, chapter):
			var enemy := _budget_enemy(path)
			if enemy != null:
				base.append(enemy)
		if base.is_empty():
			continue
		var fit := _fit_scale(base, target)
		var pack := _scaled_pack(base, fit["scale"])
		var threat := pack_threat(pack)
		var miss := absf(threat - target) / maxf(target, 0.001)
		if miss < best_miss:
			best = pack
			best_miss = miss
			best_info = _pack_info(base.size(), fit, target, threat, attempt + 1, false)
		if not fit["bound_hit"]:
			break
	if best.is_empty():
		# Every attempt lost all its enemies to load failures. A map fight is never zero enemies: log it and build
		# the pack from the first enemy that still loads (or a minimal stand-in).
		Combat.engine_error("StarterContent.budget_encounter: no pool enemy loaded, falling back to a known enemy")
		var stand_in := _fallback_enemy()
		var base: Array[EnemyData] = []
		for i in n:
			base.append(stand_in.duplicate(true) as EnemyData)
		var fit := _fit_scale(base, target)
		best = _scaled_pack(base, fit["scale"])
		best_info = _pack_info(n, fit, target, pack_threat(best), PACK_MAX_ATTEMPTS, true)
	last_pack_info = best_info
	if elite:
		for i in best.size():
			best[i] = elite_named(best[i])
	return best


## A copy of `enemy` whose display name has ELITE_NAME_PREFIX in front (same id, stats, intents and second phase). A new
## EnemyData, so the shared resource is never touched; an already-elite name is left alone.
static func elite_named(enemy: EnemyData) -> EnemyData:
	if enemy.display_name.begins_with(ELITE_NAME_PREFIX):
		return enemy
	var intents: Array[CardEffect] = []
	intents.assign(enemy.intents)
	var named := EnemyData.make(ELITE_NAME_PREFIX + enemy.display_name, enemy.max_hp, intents, enemy.id, enemy.max_haunt)
	named.phase_two_intents = enemy.phase_two_intents
	named.phase_two_hp_percent = enemy.phase_two_hp_percent
	named.phase_two_title = enemy.phase_two_title
	named.phase_three_intents = enemy.phase_three_intents
	named.phase_three_hp_percent = enemy.phase_three_hp_percent
	named.phase_three_title = enemy.phase_three_title
	named.unseen = enemy.unseen
	return named


## The complete last_pack_info dictionary (every key, in every case).
static func _pack_info(count: int, fit: Dictionary, target: float, threat: float, attempts: int, fallback: bool) -> Dictionary:
	var share := _hp_share(count)
	return {"scale": fit["scale"], "hp_scale": pow(fit["scale"], share), "damage_scale": pow(fit["scale"], 1.0 - share), "target": target, "threat": threat, "bound_hit": fit["bound_hit"], "attempts": attempts, "fallback": fallback}


## Test hook: when valid, loads the pack builder's enemies instead of _load_enemy (so a load failure can be provoked).
static var _budget_enemy_loader := Callable()


static func _budget_enemy(path: String) -> EnemyData:
	if _budget_enemy_loader.is_valid():
		return _budget_enemy_loader.call(path) as EnemyData
	return _load_enemy(path)


## A known loadable enemy for the pack builder's last resort, or a minimal hand-built one when none loads.
static func _fallback_enemy() -> EnemyData:
	for path in [LOST_SHADE_PATH, WARDEN_PATH, WISP_PATH]:
		var enemy := _budget_enemy(path)
		if enemy != null and not enemy.intents.is_empty():
			return enemy
	var intents: Array[CardEffect] = [CardEffect.make(CardEffect.Kind.DAMAGE, 6)]
	return EnemyData.make("Lost Shade", 24, intents, &"lost_shade")


## The enemy paths of a pack of `count`, drawn from the pools in the order varied_encounter draws them.
static func _pack_paths(count: int, rng: RandomNumberGenerator, big_pair_chance: float, chapter: int = 1) -> Array[String]:
	var pools := Chapters.chapter(chapter)
	var paths: Array[String] = []
	match count:
		1:
			paths.append(Encounters.pick_path(pools.enemy_paths, rng))
		2:
			if rng.randf() < big_pair_chance:
				paths.append(Encounters.pick_path(pools.big_paths, rng))
				paths.append(Encounters.pick_path(pools.small_paths, rng))
			else:
				paths.append(Encounters.pick_path(pools.small_paths, rng))
				paths.append(Encounters.pick_path(pools.small_paths, rng))
		_:
			var trio := pools.trio_paths()
			for i in count:
				paths.append(Encounters.pick_path(trio, rng))
	return paths


## The HP share of the total multiplier for a pack of `count` (see PACK_HP_SHARE).
static func _hp_share(count: int) -> float:
	return PACK_HP_SHARE[clampi(count, 1, PACK_HP_SHARE.size()) - 1]


## The legal range of the total multiplier m for a pack of `count`: the HP factor m^share and the damage factor
## m^(1 - share) must both lie in PACK_SCALE_MIN..PACK_SCALE_MAX. Returns [m_min, m_max].
static func pack_multiplier_bounds(count: int) -> Array[float]:
	var share := _hp_share(count)
	var low := maxf(pow(PACK_SCALE_MIN, 1.0 / share), pow(PACK_SCALE_MIN, 1.0 / (1.0 - share)))
	var high := minf(pow(PACK_SCALE_MAX, 1.0 / share), pow(PACK_SCALE_MAX, 1.0 / (1.0 - share)))
	return [low, high]


## The total multiplier m, inside pack_multiplier_bounds, that brings the scaled `base` pack's threat closest to
## `target` (threat rises with m, so bisect), and whether the bounds stopped it reaching the target.
static func _fit_scale(base: Array[EnemyData], target: float) -> Dictionary:
	var bounds := pack_multiplier_bounds(base.size())
	var low_threat := pack_threat(_scaled_pack(base, bounds[0]))
	if low_threat >= target:
		return {"scale": bounds[0], "bound_hit": low_threat > target * 1.02}
	var high_threat := pack_threat(_scaled_pack(base, bounds[1]))
	if high_threat <= target:
		return {"scale": bounds[1], "bound_hit": high_threat < target * 0.98}
	var lo: float = bounds[0]
	var hi: float = bounds[1]
	for i in 30:
		var mid := (lo + hi) * 0.5
		if pack_threat(_scaled_pack(base, mid)) < target:
			lo = mid
		else:
			hi = mid
	var lo_miss := target - pack_threat(_scaled_pack(base, lo))
	var hi_miss := pack_threat(_scaled_pack(base, hi)) - target
	return {"scale": lo if lo_miss <= hi_miss else hi, "bound_hit": false}


## `base` with every enemy scaled for the total multiplier `m`: HP by m^share, damage by m^(1 - share).
static func _scaled_pack(base: Array[EnemyData], m: float) -> Array[EnemyData]:
	var share := _hp_share(base.size())
	var pack: Array[EnemyData] = []
	for enemy in base:
		pack.append(scaled(enemy, pow(m, share), pow(m, 1.0 - share)))
	return pack


## The stat multiplier for the regular fight numbered `fight` (0-based; below 0 counts as 0).
static func ramp_factor(fight: int) -> float:
	return Encounters.ramp_factor(fight)


## `enemy` with max HP and DAMAGE intents scaled by `factor` (rounded, never below 1). Returns a new
## EnemyData with new intents, so the shared resource is never touched; factor 1.0 returns `enemy` itself.
## A `damage_factor` of 0 or more scales the DAMAGE intents by that instead (the pack builder splits HP and damage).
static func scaled(enemy: EnemyData, factor: float, damage_factor: float = -1.0) -> EnemyData:
	return Encounters.scaled(enemy, factor, damage_factor)


## The boss fight: the Conductor alone. Empty (cause logged) if it fails to load,
## and Combat needs at least one enemy, so callers must check.
static func boss_encounter(chapter: int = 1, character_id: StringName = &"") -> Array[EnemyData]:
	return Encounters.boss_encounter(chapter, character_id)


## The mid-run boss fight: the Brakeman alone. Empty (cause logged) if it fails to load.
static func mid_boss_encounter(chapter: int = 1, character_id: StringName = &"") -> Array[EnemyData]:
	return Encounters.mid_boss_encounter(chapter, character_id)


## The finale fight of `chapter` (the final boss alone); empty when that chapter has no finale or the boss fails to load.
static func finale_encounter(chapter: int = 3, character_id: StringName = &"") -> Array[EnemyData]:
	return Encounters.finale_encounter(chapter, character_id)
